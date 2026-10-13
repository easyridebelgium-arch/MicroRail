extends RefCounted
## Destination counts are authoritative. Aggregate counters remain views for UI
## and legacy fixtures. Direct journeys only; transfers and satisfaction follow.
const STATIONS: Array[String] = ["a", "b", "c"]
var queues: Dictionary = {}

func _init() -> void:
	for station in STATIONS: queues[station] = distribute(station, 8)

static func total(counts: Dictionary) -> int:
	var result := 0
	for count in counts.values(): result += int(count)
	return result

static func distribute(origin: String, count: int) -> Dictionary:
	var destinations := STATIONS.duplicate()
	destinations.erase(origin)
	var result: Dictionary = {}
	for index in range(destinations.size()):
		var share := int(floor(float(count) / destinations.size())) + (1 if index < count % destinations.size() else 0)
		if share > 0: result[destinations[index]] = share
	return result

func waiting(station: String) -> int: return total(queues.get(station, {}))
func reset_total(station: String, count: int) -> void:
	if count != waiting(station): queues[station] = distribute(station, maxi(0, count))

func generate(station: String, batch: int, capacity: int, rng: RefCounted) -> int:
	var room := maxi(0, mini(batch, capacity - waiting(station)))
	var choices := STATIONS.duplicate()
	choices.erase(station)
	for _passenger in range(room):
		var destination: String = choices[rng.randi_range(0, choices.size() - 1)]
		queues[station][destination] = int(queues[station].get(destination, 0)) + 1
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

func board(station: String, destinations: Array, capacity: int, manifest: Dictionary) -> int:
	var room := maxi(0, capacity - total(manifest))
	var count := 0
	for destination in destinations:
		var take := mini(room, int(queues[station].get(destination, 0)))
		if take <= 0: continue
		queues[station][destination] -= take
		if queues[station][destination] == 0: queues[station].erase(destination)
		manifest[destination] = int(manifest.get(destination, 0)) + take
		count += take
		room -= take
	return count

static func alight(manifest: Dictionary, station: String) -> int:
	var count := int(manifest.get(station, 0))
	manifest.erase(station)
	return count

func return_to(station: String, manifest: Dictionary) -> void:
	for destination in manifest:
		# Recovery returns an unfinished journey to its leg's departure queue.
		if destination != station:
			queues[station][destination] = int(queues[station].get(destination, 0)) + int(manifest[destination])
	manifest.clear()

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

static func valid_state(value: Variant, state: Dictionary, service: Dictionary) -> bool:
	if not value is Dictionary or not value.get("queues") is Dictionary or value.queues.size() != STATIONS.size(): return false
	for station in STATIONS:
		var allowed := STATIONS.duplicate()
		allowed.erase(station)
		if not valid_counts(value.queues.get(station), allowed) or total(value.queues[station]) != state.get("waiting_at_" + station): return false
	return valid_counts(value.get("primary"), service.stops) and total(value.primary) == state.get("passengers_on_train")

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
