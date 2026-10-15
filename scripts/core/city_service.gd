extends RefCounted
## Request cohorts retain their original station/start/destination/class identity
## across transfers and recovery. Pending journeys have no implicit deadline.
const World = preload("res://scripts/core/world_catalog.gd")
const Demand = preload("res://scripts/core/city_demand.gd")
const Timetable = preload("res://scripts/core/timetable.gd")
const Classes = preload("res://scripts/core/passenger_classes.gd")
const RECENT_TICKS := 36000 # Ten game hours; 600 simulation seconds.
const MAX_COHORTS := 4096 # Per city; pending cohorts take precedence over history.
const MAX_COUNT := 1000000000000
const FIELDS := ["requested", "queued", "no_station", "no_service", "no_express", "full", "delivered", "legs", "unmeasured", "untracked_requests"]
var state: Dictionary = {"schema_version": 1, "started_tick": 0, "cities": {}}

static func counts() -> Dictionary:
	var result: Dictionary = {}
	for field in FIELDS: result[field] = 0
	return result

static func defaults(world: Dictionary, tick: int = 0) -> Dictionary:
	var result := {"schema_version": 1, "started_tick": tick, "cities": {}}
	var towns: Variant = world.get("settlements", [])
	if not towns is Array: return result
	for town in towns:
		if town is Dictionary and town.get("id") is String:
			result.cities[town.id] = {"totals": counts(), "retired": counts(), "cohorts": [], "last_tick": tick - 1, "unmatched": 0}
	return result

func initialize(world: Dictionary, tick: int = 0) -> void: state = defaults(world, tick)
func save_state() -> Dictionary: return state.duplicate(true)
func restore_state(value: Dictionary) -> void:
	state = value.duplicate(true)
	state.schema_version = int(state.schema_version)
	state.started_tick = int(state.started_tick)
	for city in state.cities.values():
		city.last_tick = int(city.last_tick)
		city.unmatched = int(city.unmatched)
		for collection in [city.totals, city.retired]:
			for field in FIELDS: collection[field] = int(collection[field])
		for cohort in city.cohorts:
			cohort.tick = int(cohort.tick)
			for field in FIELDS: cohort.counts[field] = int(cohort.counts[field])
			for group in cohort.groups:
				group.queued = int(group.queued)
				group.delivered = int(group.delivered)

static func add(target: Dictionary, source: Dictionary) -> void:
	for field in FIELDS: target[field] += int(source[field])

static func pending(collection: Dictionary) -> int:
	return int(collection.queued) - int(collection.delivered) - int(collection.unmeasured)

func _prune(city: Dictionary, tick: int) -> void:
	var retained: Array = []
	for cohort in city.cohorts:
		if int(cohort.tick) > tick - RECENT_TICKS or pending(cohort.counts) > 0: retained.append(cohort)
		else: add(city.retired, cohort.counts)
	city.cohorts = retained

## Called after the city generator admits its requests; never rerolls demand.
func record_requests(city_id: String, sample: Dictionary, origin: String, admissions: Array) -> void:
	if not state.cities.has(city_id): return
	var city: Dictionary = state.cities[city_id]
	var tick := int(sample.tick)
	if tick <= int(city.last_tick): return
	city.last_tick = tick
	_prune(city, tick)
	var values := counts()
	for field in ["requested"] + Demand.OUTCOMES: values[field] = int(sample[field])
	var groups: Array = []
	for admission in admissions:
		var matched := false
		for group in groups:
			if group.destination == admission.destination and group.get("class") == admission.get("class"):
				group.queued += 1
				matched = true
				break
		if not matched: groups.append({"destination": admission.destination, "class": admission.get("class", Classes.LOCAL), "queued": 1, "delivered": 0})
	if city.cohorts.size() >= MAX_COHORTS:
		# Measurement saturation never rejects a real passenger or labels them a failure.
		values.unmeasured = values.queued
		values.untracked_requests = values.requested
		add(city.retired, values)
	else:
		city.cohorts.append({"tick": tick, "origin": origin, "counts": values, "groups": groups})
	add(city.totals, values)

## A leg ends only at an actual transfer or final arrival, never at boarding.
func record_arrivals(rows: Array, final: bool, stations: Dictionary) -> void:
	for row in rows:
		if not row.get("known", false) or not stations.has(row.get("origin")): continue
		var city_id: String = str(stations[row.origin].get("settlement_id", ""))
		if not state.cities.has(city_id): continue
		var city: Dictionary = state.cities[city_id]
		var found := false
		for cohort in city.cohorts:
			if cohort.origin != row.origin or int(cohort.tick) != int(row.start): continue
			for group in cohort.groups:
				if group.destination != row.destination or group.get("class") != row.get("class", Classes.LOCAL): continue
				found = true
				var number := mini(int(row.count), int(group.queued) - int(group.delivered))
				cohort.counts.legs += number
				city.totals.legs += number
				if final:
					group.delivered += number
					cohort.counts.delivered += number
					city.totals.delivered += number
				break
			break
		if final and not found: city.unmatched += int(row.count)

func summary(id: String, tick: int) -> Dictionary:
	var city: Dictionary = state.cities.get(id, {"totals": counts(), "cohorts": [], "unmatched": 0})
	var recent := counts()
	for cohort in city.cohorts:
		if int(cohort.tick) > tick - RECENT_TICKS: add(recent, cohort.counts)
	return {"totals": city.totals.duplicate(true), "recent": recent, "pending": pending(city.totals), "older_pending": pending(city.totals) - pending(recent), "unmatched": int(city.unmatched)}

func describe(id: String, tick: int, display_name: String = "") -> String:
	if not state.cities.has(id): return ""
	var report := summary(id, tick)
	var totals: Dictionary = report.totals
	var recent: Dictionary = report.recent
	return "Useful service — %s\nMeasured since %s\nCity requests %d | Queued %d | Final deliveries matched %d\nUnfinished measured journeys %d (including %d older than ten game hours). Unfinished is not failed.\nArrived transport legs %d: transfers plus final arrivals; each final journey counts once. Boarding/recovery alone adds no leg.\nTracked requests made in the last ten game hours: %d requested; %d queued; %d delivered; %d still unfinished.\nNot queued, since measurement began: no station %d; no service %d; no direct Express %d; full queue %d.\nOlder/untracked final deliveries %d; requests beyond the measurement limit %d (including %d queued without tracking). Excluded from measured completion accounting. Measurement does not add journey deadlines or change fares." % [display_name if not display_name.is_empty() else id, Timetable.clock_text(Timetable.absolute_minute(int(state.started_tick))), totals.requested, totals.queued, totals.delivered, report.pending, report.older_pending, totals.legs, recent.requested, recent.queued, recent.delivered, pending(recent), totals.no_station, totals.no_service, totals.no_express, totals.full, report.unmatched, totals.untracked_requests, totals.unmeasured]

static func valid_counts(value: Variant) -> bool:
	if not value is Dictionary or value.size() != FIELDS.size(): return false
	for field in FIELDS:
		if not World.whole(value.get(field), 0, MAX_COUNT): return false
	var outcomes := 0
	for field in Demand.OUTCOMES: outcomes += int(value[field])
	return outcomes == int(value.requested) and int(value.delivered) + int(value.unmeasured) <= int(value.queued) and int(value.legs) >= int(value.delivered) and int(value.unmeasured) <= int(value.untracked_requests) and int(value.untracked_requests) <= int(value.requested)

## Cross-check outstanding measured groups against actual queues and train manifests.
static func live_groups(data: Dictionary) -> Array:
	var result: Array = []
	var demand: Variant = data.get("demand")
	var journeys: Variant = data.get("journeys")
	if not demand is Dictionary or not demand.get("batches") is Dictionary or not journeys is Dictionary or not journeys.get("aboard") is Dictionary: return result
	for collections in [demand.batches, journeys.aboard]:
		for rows in collections.values():
			if rows is Array:
				for row in rows:
					if row is Dictionary and row.get("known") == true and World.whole(row.get("count"), 1, MAX_COUNT): result.append(row)
	return result

static func valid(value: Variant, world: Dictionary, tick: int, data: Dictionary, stations: Dictionary) -> bool:
	if not value is Dictionary or value.size() != 3 or not World.whole(value.get("schema_version"), 1, 1) or not World.whole(value.get("started_tick"), 0, tick) or not value.get("cities") is Dictionary: return false
	var expected := defaults(world, int(value.started_tick))
	if value.cities.size() != expected.cities.size(): return false
	var live := live_groups(data)
	var delivered := 0
	var unmatched := 0
	for id in expected.cities:
		var city: Variant = value.cities.get(id)
		if not city is Dictionary or city.size() != 5 or not valid_counts(city.get("totals")) or not valid_counts(city.get("retired")): return false
		if pending(city.retired) != 0: return false
		if not World.whole(city.get("last_tick"), int(value.started_tick) - 1, tick) or not World.whole(city.get("unmatched"), 0, MAX_COUNT) or not city.get("cohorts") is Array or city.cohorts.size() > MAX_COHORTS: return false
		var accounted: Dictionary = city.retired.duplicate(true)
		var previous := int(value.started_tick) - 1
		for cohort in city.cohorts:
			if not cohort is Dictionary or cohort.size() != 4 or not World.whole(cohort.get("tick"), previous + 1, int(city.last_tick)) or not cohort.get("origin") is String or not valid_counts(cohort.get("counts")): return false
			previous = int(cohort.tick)
			if not cohort.get("groups") is Array or cohort.groups.size() > Demand.MAX_REQUESTS or int(cohort.counts.unmeasured) != 0 or int(cohort.counts.untracked_requests) != 0 or int(cohort.counts.requested) > Demand.MAX_REQUESTS: return false
			if cohort.origin != "" and (not stations.has(cohort.origin) or stations[cohort.origin].get("settlement_id") != id): return false
			var queued := 0
			var finished := 0
			var seen: Dictionary = {}
			for group in cohort.groups:
				if not group is Dictionary or group.size() != 4 or not stations.has(group.get("destination")) or group.destination == cohort.origin or group.get("class") not in [Classes.LOCAL, Classes.EXPRESS]: return false
				if not World.whole(group.get("queued"), 1, Demand.MAX_REQUESTS) or not World.whole(group.get("delivered"), 0, int(group.queued)): return false
				var identity: String = str(group.destination) + ":" + str(group.get("class"))
				if seen.has(identity) or cohort.origin.is_empty(): return false
				seen[identity] = true
				queued += int(group.queued)
				finished += int(group.delivered)
				var physical := 0
				for row in live:
					if row.get("origin") == cohort.origin and row.get("start") == cohort.tick and row.get("destination") == group.destination and row.get("class", Classes.LOCAL) == group.get("class"): physical += int(row.count)
				if physical != int(group.queued) - int(group.delivered): return false
			if queued != int(cohort.counts.queued) or finished != int(cohort.counts.delivered): return false
			add(accounted, cohort.counts)
		for field in FIELDS:
			if int(accounted[field]) != int(city.totals[field]): return false
		delivered += int(city.totals.delivered)
		unmatched += int(city.unmatched)
	var saved_company: Variant = data.get("state")
	if not saved_company is Dictionary: return false
	var company_total: Variant = saved_company.get("passengers_delivered")
	return World.whole(company_total, delivered + unmatched, MAX_COUNT)
