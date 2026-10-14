extends RefCounted
## Destination counts are authoritative. Aggregate counters remain views for UI
## and legacy fixtures. Final destinations persist across transfers.
const Classes = preload("res://scripts/core/passenger_classes.gd")
var class_progress: Dictionary = {}
var station_catalog: Dictionary = Classes.DEFAULT_CATALOG
const STATIONS: Array[String] = ["a", "b", "c"]
var station_ids: Array[String] = []
var queues: Dictionary = {}
var batches: Dictionary = {}
var last_boarding: Array = []
var last_journeys: Array = []

func _init(ids: Array = STATIONS, catalog: Dictionary = Classes.DEFAULT_CATALOG) -> void:
	station_catalog = catalog.duplicate(true)
	class_progress = Classes.progress_defaults(station_catalog)
	station_ids.assign(ids)
	station_ids.sort()
	for station in station_ids:
		queues[station] = distribute(station, 8, station_ids)
		batches[station] = make_batches(queues[station], 0, station, true, station_ids)

static func total(counts: Dictionary) -> int:
	var result := 0
	for count in counts.values(): result += int(count)
	return result

static func distribute(origin: String, count: int, ids: Array = STATIONS) -> Dictionary:
	var destinations := ids.duplicate()
	destinations.sort()
	destinations.erase(origin)
	var result: Dictionary = {}
	if destinations.is_empty(): return result
	for index in range(destinations.size()):
		var share := int(floor(float(count) / destinations.size())) + (1 if index < count % destinations.size() else 0)
		if share > 0: result[destinations[index]] = share
	return result

func waiting(station: String) -> int: return total(queues.get(station, {}))
func reset_total(station: String, count: int, tick: int = 0) -> void:
	if count != waiting(station):
		queues[station] = distribute(station, maxi(0, count), station_ids)
		batches[station] = make_batches(queues[station], tick, station, false, station_ids)

func generate(station: String, batch: int, capacity: int, rng: RefCounted, tick: int = 0, classify: bool = false) -> int:
	if not station_ids.has(station) or station_ids.size() < 2: return 0
	_sync_batches(station, tick)
	var room := maxi(0, mini(batch, capacity - waiting(station)))
	var choices := station_ids.duplicate()
	choices.erase(station)
	for _passenger in range(room):
		var destination: String = choices[rng.randi_range(0, choices.size() - 1)]
		queues[station][destination] = int(queues[station].get(destination, 0)) + 1
		var kind := Classes.LOCAL
		if classify and Classes.distant(station, destination, station_catalog):
			class_progress[station] = (int(class_progress[station]) + 1) % 4
			if class_progress[station] == 0: kind = Classes.EXPRESS
		_add_batch(station, destination, 1, tick, "", -1, true, kind)
	return room

static func future_stops(stops: Array, index: int, forward: bool, mode: String) -> Array:
	var result: Array = []
	if mode == "loop":
		for offset in range(1, stops.size()): result.append(stops[(index + offset) % stops.size()])
	elif forward:
		result = stops.slice(index + 1)
	else:
		result = stops.slice(0, index)
		result.reverse()
	return result

func board(station: String, destinations: Array, capacity: int, manifest: Dictionary, tick: int = 0, express_destinations: Array = []) -> int:
	last_boarding.clear()
	last_journeys.clear()
	var boarding_groups: Dictionary = {}
	_sync_batches(station, tick)
	var room := maxi(0, capacity - total(manifest))
	var candidates: Array = []
	for batch in batches[station]:
		if Classes.eligible(batch, destinations, express_destinations, station_catalog): candidates.append(batch)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.tick != b.tick: return a.tick < b.tick
		if a.destination != b.destination: return destinations.find(a.destination) < destinations.find(b.destination)
		if a.start != b.start: return a.start < b.start
		if a.origin != b.origin: return str(a.origin) < str(b.origin)
		return a.get("class", Classes.LOCAL) == Classes.LOCAL and b.get("class", Classes.LOCAL) != Classes.LOCAL
	)
	var count := 0
	for batch in candidates:
		var take := mini(room, int(batch.count))
		if take == 0: break
		var destination: String = batch.destination
		var identity := destination + ":" + str(batch.tick)
		if boarding_groups.has(identity): last_boarding[boarding_groups[identity]].count += take
		else:
			boarding_groups[identity] = last_boarding.size()
			last_boarding.append({"count": take, "wait": maxi(0, tick - int(batch.tick))})
		last_journeys.append({"destination": destination, "origin": batch.origin, "start": int(batch.start), "known": batch.known, "class": batch.get("class", Classes.LOCAL), "count": take})
		batch.count -= take
		queues[station][destination] -= take
		if queues[station][destination] == 0: queues[station].erase(destination)
		manifest[destination] = int(manifest.get(destination, 0)) + take
		count += take
		room -= take
	batches[station] = batches[station].filter(func(batch: Dictionary) -> bool: return batch.count > 0)
	return count

func eligible_waiting(station: String, destinations: Array, express_destinations: Array, tick: int) -> int:
	var count := 0
	for row in waiting_groups(station, tick):
		if Classes.eligible(row, destinations, express_destinations, station_catalog): count += int(row.count)
	return count

static func alight(manifest: Dictionary, station: String) -> int:
	var count := int(manifest.get(station, 0))
	manifest.erase(station)
	return count

func return_to(station: String, manifest: Dictionary, tick: int = 0, journeys: Array = []) -> void:
	_sync_batches(station, tick)
	for destination in manifest:
		# Recovery returns an unfinished journey to its leg's departure queue.
		if destination != station:
			queues[station][destination] = int(queues[station].get(destination, 0)) + int(manifest[destination])
			_returned_groups(station, destination, int(manifest[destination]), tick, journeys)
	manifest.clear()

func interchange(station: String, served_stops: Array, manifest: Dictionary, tick: int = 0, journeys: Array = []) -> int:
	_sync_batches(station, tick)
	var changed := 0
	for destination in manifest.keys():
		if served_stops.has(destination): continue
		var count := int(manifest[destination])
		queues[station][destination] = int(queues[station].get(destination, 0)) + count
		_returned_groups(station, destination, count, tick, journeys)
		manifest.erase(destination)
		changed += count
	return changed

static func valid_counts(value: Variant, allowed: Array) -> bool:
	if not value is Dictionary: return false
	for destination in value:
		if not destination is String or not allowed.has(destination): return false
		var count: Variant = value[destination]
		if typeof(count) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(count)) or float(count) != floor(float(count)) or count < 0 or count > 1000000000: return false
	return total(value) <= 1000000000

static func normalize(counts: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for destination in counts:
		if int(counts[destination]) > 0: result[destination] = int(counts[destination])
	return result

static func valid_state(value: Variant, state: Dictionary, _service: Dictionary, tick: int = 0, ids: Array = STATIONS, catalog: Dictionary = Classes.DEFAULT_CATALOG) -> bool:
	if not valid_ids(ids): return false
	if not value is Dictionary or not value.get("queues") is Dictionary or value.queues.size() != ids.size(): return false
	for station in ids:
		var allowed := ids.duplicate()
		allowed.erase(station)
		if not valid_counts(value.queues.get(station), allowed): return false
		var legacy_key := "waiting_at_" + str(station)
		if (STATIONS.has(station) or state.has(legacy_key)) and total(value.queues[station]) != state.get(legacy_key): return false
	if not valid_batches(value.get("batches"), value.queues, tick, ids, catalog): return false
	return valid_counts(value.get("primary"), ids) and total(value.primary) == state.get("passengers_on_train")
static func legacy_manifest(count: int, config: Dictionary, index: int, forward: bool, returning: bool) -> Dictionary:
	if count <= 0 or not config.get("stops") is Array or config.stops.size() < 2: return {}
	var original_forward := not forward if returning else forward
	var next: int = (index + 1) % config.stops.size() if config.get("mode", "shuttle") == "loop" else clampi(index + (1 if original_forward else -1), 0, config.stops.size() - 1)
	return {config.stops[next]: count}

static func migrate(data: Dictionary) -> Dictionary:
	var result := {"queues": {}, "primary": {}}
	var state: Variant = data.get("state")
	var services: Variant = data.get("services")
	if not state is Dictionary or not services is Dictionary: return result
	for station in STATIONS: result.queues[station] = distribute(station, int(state.get("waiting_at_" + station, 0)))
	var runtime: Variant = data.get("runtime", {})
	var returning: bool = bool(runtime.get("passenger_returning", false)) if runtime is Dictionary else false
	if services.get("passenger") is Dictionary:
		result.primary = legacy_manifest(int(state.get("passengers_on_train", 0)), services.passenger, int(state.get("passenger_stop_index", 0)), bool(state.get("travelling_to_b", true)), returning)
	if data.get("passenger_services") is Dictionary:
		for key in data.passenger_services:
			var running: Variant = data.passenger_services[key]
			if running is Dictionary and services.get(key) is Dictionary:
				running["passenger_destinations"] = legacy_manifest(int(running.get("passengers", 0)), services[key], int(running.get("stop_index", 0)), bool(running.get("forward", true)), bool(running.get("returning", false)))
	return result

static func make_batches(counts: Dictionary, tick: int, origin: String = "unknown", known: bool = false, ids: Array = STATIONS) -> Array:
	var result: Array = []
	for destination in ids:
		if int(counts.get(destination, 0)) > 0: result.append({"destination": destination, "count": int(counts[destination]), "tick": tick, "origin": origin, "start": tick, "known": known, "class": Classes.LOCAL})
	return result

func waiting_groups(station: String, tick: int) -> Array:
	# Aggregate setters/legacy fixtures have no arrival times: initialize only
	# changed queues at the supplied tick. Normal gameplay always updates both.
	var counts: Dictionary = {}
	for batch in batches.get(station, []): counts[batch.destination] = int(counts.get(batch.destination, 0)) + int(batch.count)
	if normalize(counts) != normalize(queues[station]): return make_batches(queues[station], tick, station, false, station_ids)
	return batches[station]

func _sync_batches(station: String, tick: int) -> void:
	batches[station] = waiting_groups(station, tick)

func _add_batch(station: String, destination: String, count: int, tick: int, origin: String = "", start: int = -1, known: bool = true, kind: String = Classes.LOCAL) -> void:
	if count <= 0: return
	if origin.is_empty(): origin = station
	if start < 0: start = tick
	for batch in batches[station]:
		if batch.destination == destination and batch.tick == tick and batch.origin == origin and batch.start == start and batch.known == known and batch.get("class", Classes.LOCAL) == kind:
			batch.count += count
			return
	batches[station].append({"destination": destination, "count": count, "tick": tick, "origin": origin, "start": start, "known": known, "class": kind})

func oldest_seconds(station: String, tick: int, destination: String = "") -> float:
	if waiting(station) == 0 or (not destination.is_empty() and int(queues[station].get(destination, 0)) == 0): return 0.0
	var oldest := tick
	for batch in batches.get(station, []):
		if destination.is_empty() or batch.destination == destination: oldest = mini(oldest, int(batch.tick))
	return maxf(0, float(tick - oldest) / 60.0)

func save_state(primary: Dictionary, tick: int) -> Dictionary:
	for station in station_ids: _sync_batches(station, tick)
	return {"queues": queues.duplicate(true), "primary": primary.duplicate(true), "batches": batches.duplicate(true), "class_progress": class_progress.duplicate()}

func restore_state(data: Dictionary, ids: Array = STATIONS, catalog: Dictionary = Classes.DEFAULT_CATALOG) -> void:
	station_catalog = catalog.duplicate(true)
	station_ids.assign(ids)
	station_ids.sort()
	queues.clear()
	batches.clear()
	class_progress.clear()
	var progress: Dictionary = data.get("class_progress", Classes.progress_defaults(station_catalog))
	for station in progress: class_progress[station] = int(progress[station])
	for station in station_ids:
		queues[station] = normalize(data.queues[station])
		batches[station] = []
		for batch in data.batches[station]: batches[station].append({"destination": batch.destination, "tick": int(batch.tick), "count": int(batch.count), "origin": batch.origin, "start": int(batch.start), "known": batch.known, "class": batch.get("class", Classes.LOCAL)})
static func valid_batches(value: Variant, saved_queues: Dictionary, tick: int, ids: Array = STATIONS, catalog: Dictionary = Classes.DEFAULT_CATALOG) -> bool:
	if not valid_ids(ids) or saved_queues.size() != ids.size(): return false
	for station in ids:
		if not valid_counts(saved_queues.get(station), ids): return false
	if not value is Dictionary or value.size() != ids.size(): return false
	for station in ids:
		var rows: Variant = value.get(station)
		if not rows is Array or rows.size() > total(saved_queues[station]): return false
		var counts: Dictionary = {}
		var seen: Dictionary = {}
		for batch in rows:
			if not batch is Dictionary or not batch.get("destination") is String or not Classes.valid(batch, catalog): return false
			if batch.get("class", Classes.LOCAL) == Classes.EXPRESS and batch.get("origin") != station: return false
			var destination: String = batch.destination
			if destination == station or not ids.has(destination): return false
			if not valid_counts({destination: batch.get("count")}, ids) or int(batch.count) <= 0: return false
			var time: Variant = batch.get("tick")
			if typeof(time) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(time)) or float(time) != floor(float(time)) or float(time) < 0 or float(time) > tick: return false
			if not batch.get("known") is bool or not batch.get("origin") is String: return false
			var birth: Variant = batch.get("start")
			if typeof(birth) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(birth)) or float(birth) != floor(float(birth)) or float(birth) < 0 or float(birth) > float(time): return false
			if batch.known:
				if not ids.has(batch.origin) or batch.origin == destination: return false
			elif batch.origin != "unknown" and not ids.has(batch.origin): return false
			var key: String = destination + ":" + str(int(time)) + ":" + batch.origin + ":" + str(int(birth)) + ":" + str(batch.known) + ":" + str(batch.get("class", Classes.LOCAL))
			if seen.has(key): return false
			seen[key] = true
			counts[destination] = int(counts.get(destination, 0)) + int(batch.count)
		if normalize(counts) != normalize(saved_queues[station]): return false
	return true
static func migrate_ages(data: Dictionary) -> void:
	if not data.get("demand") is Dictionary: return
	var tick := 0
	if data.get("sim") is Dictionary and data.sim.get("clock") is Dictionary:
		var saved_tick: Variant = data.sim.clock.get("tick", 0)
		if typeof(saved_tick) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(saved_tick)) and float(saved_tick) >= 0 and float(saved_tick) <= 1000000000000: tick = int(saved_tick)
	data.demand["batches"] = {}
	for station in STATIONS:
		var saved_queues: Variant = data.demand.get("queues")
		var counts: Variant = saved_queues.get(station, {}) if saved_queues is Dictionary else {}
		data.demand.batches[station] = make_batches(counts, tick) if counts is Dictionary and valid_counts(counts, STATIONS) else []

func _returned_groups(station: String, destination: String, count: int, tick: int, journeys: Array) -> void:
	var matched: Array = journeys.filter(func(row: Dictionary) -> bool: return row.destination == destination)
	var sum := 0
	for row in matched: sum += int(row.count)
	if sum != count:
		_add_batch(station, destination, count, tick, "unknown", tick, false)
		return
	for row in matched: _add_batch(station, destination, int(row.count), tick, row.origin, int(row.start), row.known, str(row.get("class", Classes.LOCAL)))

static func valid_ids(ids: Array) -> bool:
	if ids.size() > 64: return false
	var seen: Dictionary = {}
	for id in ids:
		if not id is String or id.is_empty() or id.length() > 64 or seen.has(id): return false
		seen[id] = true
	return true
