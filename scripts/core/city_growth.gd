extends RefCounted
## Deterministic population response to newly resolved outcomes. Accepted unfinished
## journeys never become failures; no timetable target or passenger expiry is used.
const World = preload("res://scripts/core/world_catalog.gd")
const Service = preload("res://scripts/core/city_service.gd")
const Timetable = preload("res://scripts/core/timetable.gd")
const PERIOD := 21600 # Six game hours.
const GRACE := 86400 # One game day; protects decline, not positive growth.
const MIN_DELIVERIES := 5
const HISTORY := 16
const RATES := ["normal", "slow", "off"]
const RATE_NAMES := ["Normal", "Slower (quarter rate)", "Frozen (no population changes)"]
const REASONS := ["new", "rules_changed", "off", "tracking", "unknown", "pending", "grace", "low", "quiet", "warning", "growth", "decline", "slow_growth", "slow_decline", "floor", "cap"]
var state: Dictionary = {"schema_version": 1, "rate": "off", "started_tick": 0, "last_tick": 0, "cities": {}}

static func safe_count(value: Variant) -> int:
	return int(value) if World.whole(value, 0, Service.MAX_COUNT) else 0

static func rejected(totals: Dictionary) -> int:
	var result := 0
	for field in ["no_station", "no_service", "no_express", "full"]: result += safe_count(totals.get(field, 0))
	return result

static func defaults(world: Dictionary, demand: Dictionary, service: Dictionary, tick: int = 0, rate: String = "normal") -> Dictionary:
	var result := {"schema_version": 1, "rate": rate if rate in RATES else "normal", "started_tick": tick, "last_tick": tick, "cities": {}}
	var towns: Variant = world.get("settlements", [])
	if not towns is Array: return result
	var populations: Variant = demand.get("cities")
	var measurements_by_city: Variant = service.get("cities")
	if not populations is Dictionary or not measurements_by_city is Dictionary: return result
	for town in towns:
		if not town is Dictionary or not town.get("id") is String: continue
		var row: Variant = populations.get(town.id)
		var measurements: Variant = measurements_by_city.get(town.id)
		if not row is Dictionary or not measurements is Dictionary or not measurements.get("totals") is Dictionary: continue
		var totals: Dictionary = measurements.totals
		result.cities[town.id] = {"initial": int(row.population) if World.whole(row.get("population"), 1, 1000000) else 1, "delivered": safe_count(totals.get("delivered", 0)), "rejected": rejected(totals), "bad_periods": 0, "carry": 0, "direction": 0, "reason": "off" if rate == "off" else "new", "history": []}
	if result.cities.is_empty(): result.rate = "off"
	return result

func initialize(world: Dictionary, demand: Dictionary, service: Dictionary, tick: int = 0, rate: String = "normal") -> void:
	state = defaults(world, demand, service, tick, rate)
func save_state() -> Dictionary: return state.duplicate(true)
func restore_state(value: Dictionary) -> void:
	state = value.duplicate(true)
	for field in ["schema_version", "started_tick", "last_tick"]: state[field] = int(state[field])
	for city in state.cities.values():
		for field in ["initial", "delivered", "rejected", "bad_periods", "carry", "direction"]: city[field] = int(city[field])
		for sample in city.history:
			for field in ["tick", "population", "delta", "delivered", "rejected", "pending"]: sample[field] = int(sample[field])

static func floor_population(initial: int) -> int: return maxi(1, int(initial / 2.0))
static func cap_population(initial: int) -> int: return mini(1000000, initial * 3)

## The main command handler calls this at a fixed tick (or as a paused edit).
func set_rate(rate: String, tick: int, service: RefCounted) -> bool:
	if rate not in RATES or state.cities.is_empty() or tick < int(state.last_tick) or tick > Service.MAX_COUNT: return false
	if rate == state.rate: return true
	state.rate = rate
	state.last_tick = tick
	for id in state.cities:
		var city: Dictionary = state.cities[id]
		city.delivered = int(service.state.cities[id].totals.delivered)
		city.rejected = rejected(service.state.cities[id].totals)
		city.bad_periods = 0
		city.carry = 0
		city.direction = 0
		city.reason = "off" if rate == "off" else "rules_changed"
	return true

## Includes pre-baseline accepted journeys. Unknown origins conservatively stop
## decline, instead of treating migrated passengers as lost/unserved requests.
static func pending_passengers(stations: Dictionary, queues: Dictionary, aboard: Dictionary) -> Dictionary:
	var result := {"cities": {}, "unknown": false}
	for collection in [queues, aboard]:
		for rows in collection.values():
			for row in rows:
				if not row.get("known", false) or not stations.has(row.get("origin")):
					result.unknown = true
					continue
				var id: String = str(stations[row.origin].get("settlement_id", ""))
				result.cities[id] = int(result.cities.get(id, 0)) + int(row.count)
	return result

func advance(tick: int, demand: RefCounted, service: RefCounted, pending: Dictionary) -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	if state.cities.is_empty() or tick - int(state.last_tick) < PERIOD: return changes
	state.last_tick = tick
	var ids: Array = state.cities.keys()
	ids.sort()
	for id in ids:
		var city: Dictionary = state.cities[id]
		var totals: Dictionary = service.state.cities[id].totals
		var delivered := maxi(0, int(totals.delivered) - int(city.delivered))
		var unmet := maxi(0, rejected(totals) - int(city.rejected))
		var waiting := int(pending.cities.get(id, 0))
		city.delivered = int(totals.delivered)
		city.rejected = rejected(totals)
		var population: int = demand.state.cities[id].population
		var direction := 0
		var reason := "quiet"
		if state.rate == "off": reason = "off"
		elif int(totals.untracked_requests) > 0: reason = "tracking"
		elif delivered >= MIN_DELIVERIES:
			direction = 1
			reason = "growth"
		elif delivered > 0: reason = "low"
		elif waiting > 0: reason = "pending"
		elif bool(pending.get("unknown", false)): reason = "unknown"
		elif tick - int(state.started_tick) <= GRACE: reason = "grace"
		elif unmet > 0:
			city.bad_periods = mini(2, int(city.bad_periods) + 1)
			reason = "warning"
			if city.bad_periods >= 2:
				direction = -1
				reason = "decline"
		if reason not in ["warning", "decline"]: city.bad_periods = 0
		var delta := 0
		if direction != 0:
			if city.direction != direction: city.carry = 0
			var denominator := (100 if direction > 0 else 200) * (4 if state.rate == "slow" else 1)
			var numerator := population + int(city.carry)
			delta = int(floor(float(numerator) / denominator)) * direction
			city.carry = numerator % denominator
			city.direction = direction
			var target := clampi(population + delta, floor_population(city.initial), cap_population(city.initial))
			delta = target - population
			if target == cap_population(city.initial) and direction > 0:
				reason = "cap"
				city.carry = 0
			elif target == floor_population(city.initial) and direction < 0:
				reason = "floor"
				city.carry = 0
			elif delta == 0: reason = "slow_growth" if direction > 0 else "slow_decline"
			demand.state.cities[id].population = target
		else:
			city.carry = 0
			city.direction = 0
		city.reason = reason
		city.history.append({"tick": tick, "population": population + delta, "delta": delta, "delivered": delivered, "rejected": unmet, "pending": waiting, "reason": reason})
		if city.history.size() > HISTORY: city.history.pop_front()
		if delta != 0: changes.append({"city": id, "population": population + delta, "delta": delta, "reason": reason})
	return changes

static func reason_text(reason: String) -> String:
	return {"new": "New-city grace period; completed journeys may already support growth.", "rules_changed": "Rule changed; a fresh assessment interval has started.", "off": "Population frozen by this game's rule.", "tracking": "Measurement limit reached; population held stable rather than scoring incomplete data.", "unknown": "Some accepted journeys have unknown origins; decline is suspended.", "pending": "Accepted journeys are still unfinished; they are not failures.", "grace": "New-city grace period protects against decline.", "low": "Some final journeys completed, below the five needed for growth; population stable.", "quiet": "No new resolved demand to assess; population stable.", "warning": "Unmet requests and no deliveries; one more such interval is needed before decline.", "growth": "At least five newly completed final journeys support growth.", "decline": "Sustained unmet requests, no final deliveries and no unfinished journeys.", "slow_growth": "Slow growth is accumulating a fraction of a resident.", "slow_decline": "Slow decline is accumulating a fraction of a resident.", "floor": "Minimum population reached; city access and infrastructure stay intact.", "cap": "Population cap reached; continued service still earns ordinary fares."}.get(reason, "")

func describe(id: String, _tick: int, population: int) -> String:
	if not state.cities.has(id): return ""
	var city: Dictionary = state.cities[id]
	var latest: Dictionary = city.history.back() if not city.history.is_empty() else {}
	var result := "City response — %s\nPopulation %d (floor %d; cap %d).\n%s\nNext assessment: %s. Decline grace ends: %s." % [RATE_NAMES[RATES.find(state.rate)], population, floor_population(city.initial), cap_population(city.initial), reason_text(city.reason), Timetable.clock_text(Timetable.absolute_minute(int(state.last_tick) + PERIOD)), Timetable.clock_text(Timetable.absolute_minute(int(state.started_tick) + GRACE))]
	if not latest.is_empty():
		result += "\nLast assessment: %+d residents; %d newly completed final journeys, %d newly unmet requests, %d unfinished journeys (excluded from failures)." % [latest.delta, latest.delivered, latest.rejected, latest.pending]
	result += "\nEvery six game hours: five final deliveries can support 1% growth; decline is 0.5% after grace and two failed-service intervals. Slower uses quarter rates. No journey deadline, transfer bonus or land expansion."
	return result

static func valid(value: Variant, world: Dictionary, demand: Dictionary, service: Dictionary, tick: int) -> bool:
	if not value is Dictionary or value.size() != 5 or not World.whole(value.get("schema_version"), 1, 1) or value.get("rate") not in RATES or not World.whole(value.get("started_tick"), 0, tick) or not World.whole(value.get("last_tick"), int(value.started_tick), tick) or not value.get("cities") is Dictionary: return false
	var towns: Variant = world.get("settlements", [])
	if not towns is Array: return false
	var expected := defaults(world, demand, service, int(value.started_tick), value.rate)
	if expected.cities.size() != towns.size() or value.cities.size() != expected.cities.size() or (value.cities.is_empty() and value.rate != "off"): return false
	for id in expected.cities:
		var city: Variant = value.cities.get(id)
		if not city is Dictionary or city.size() != 8 or not World.whole(city.get("initial"), 1, 1000000) or not World.whole(city.get("delivered"), 0, int(service.cities[id].totals.delivered)) or not World.whole(city.get("rejected"), 0, rejected(service.cities[id].totals)): return false
		if not World.whole(city.get("bad_periods"), 0, 2) or not World.whole(city.get("carry"), 0, 799) or not World.whole(city.get("direction"), -1, 1) or city.get("reason") not in REASONS or not city.get("history") is Array or city.history.size() > HISTORY: return false
		var denominator := (100 if int(city.direction) > 0 else 200) * (4 if value.rate == "slow" else 1)
		if int(city.direction) == 0 and int(city.carry) != 0: return false
		if int(city.direction) != 0 and int(city.carry) >= denominator: return false
		if value.rate == "off" and (city.reason != "off" or int(city.direction) != 0 or int(city.bad_periods) != 0): return false
		var population: Variant = demand.cities[id].population
		if not World.whole(population, floor_population(city.initial), cap_population(city.initial)): return false
		var previous := int(value.started_tick)
		var previous_population := -1
		var observed_deliveries := 0
		var observed_rejections := 0
		for sample in city.history:
			if not sample is Dictionary or sample.size() != 7 or not World.whole(sample.get("tick"), previous + 1, int(value.last_tick)) or not World.whole(sample.get("population"), floor_population(city.initial), cap_population(city.initial)) or not World.whole(sample.get("delta"), -1000000, 1000000) or sample.get("reason") not in REASONS: return false
			for field in ["delivered", "rejected", "pending"]:
				if not World.whole(sample.get(field), 0, Service.MAX_COUNT): return false
			var before := int(sample.population) - int(sample.delta)
			if before < floor_population(city.initial) or before > cap_population(city.initial): return false
			if previous_population >= 0 and before != previous_population: return false
			if previous_population < 0 and city.history.size() < HISTORY and before != int(city.initial): return false
			previous_population = int(sample.population)
			if int(sample.delta) > 0:
				if sample.reason not in ["growth", "cap"] or int(sample.delivered) < MIN_DELIVERIES or int(sample.delta) > ceili(float(before) / 100.0): return false
			elif int(sample.delta) < 0:
				if sample.reason not in ["decline", "floor"] or int(sample.delivered) != 0 or int(sample.pending) != 0 or int(sample.rejected) <= 0 or int(sample.tick) - int(value.started_tick) <= GRACE or -int(sample.delta) > ceili(float(before) / 200.0): return false
			observed_deliveries += int(sample.delivered)
			observed_rejections += int(sample.rejected)
			previous = int(sample.tick)
		if observed_deliveries > int(city.delivered) or observed_rejections > int(city.rejected): return false
		if city.history.is_empty():
			if city.reason not in ["new", "rules_changed", "off"]: return false
			if int(population) != int(city.initial): return false
		elif int(city.history.back().population) != int(population): return false
	return true
