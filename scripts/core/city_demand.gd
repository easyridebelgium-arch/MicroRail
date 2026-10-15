extends RefCounted
## Cities own trip supply; stations are exclusive access points, not demand sources.
const World = preload("res://scripts/core/world_catalog.gd")
const Construction = preload("res://scripts/core/station_construction.gd")
const Journeys = preload("res://scripts/core/passenger_journeys.gd")
const Classes = preload("res://scripts/core/passenger_classes.gd")
const WINDOW := 12
const PEOPLE_PER_TRIP := 400
const MAX_REQUESTS := 32
const OUTCOMES := ["queued", "no_station", "no_service", "no_express", "full"]
var state: Dictionary = {"schema_version": 1, "cities": {}}

static func defaults(world: Dictionary) -> Dictionary:
	var result := {"schema_version": 1, "cities": {}}
	var ids: Array = []
	if not world.get("settlements", []) is Array: return result
	for town in world.get("settlements", []):
		if not town is Dictionary or not town.get("id") is String: return result
		if not ids.has(town.id): ids.append(town.id)
	ids.sort()
	for index in range(ids.size()):
		result.cities[ids[index]] = {"population": 800 + index * 100, "carry": 0, "express_progress": 0, "history": []}
	return result

func initialize(world: Dictionary) -> void: state = defaults(world)
func save_state() -> Dictionary: return state.duplicate(true)
func restore_state(value: Dictionary) -> void:
	state = value.duplicate(true)
	state.schema_version = int(state.schema_version)
	for row in state.cities.values():
		for field in ["population", "carry", "express_progress"]: row[field] = int(row[field])
		for sample in row.history:
			for field in sample: sample[field] = int(sample[field])

## Existing amenity/response modifiers are optional; they never create station-owned trips.
func generate(world: Dictionary, queues: RefCounted, configurations: Dictionary, rng: RefCounted, tick: int, limits: Dictionary = {}, adjust_amount: Callable = Callable()) -> void:
	var ids: Array = state.cities.keys()
	ids.sort()
	var catchments := Construction.catchments(world)
	var network := Journeys.graph(configurations, queues.station_ids)
	for id in ids:
		var row: Dictionary = state.cities[id]
		var pool: int = int(row.population) + int(row.carry)
		var count := mini(MAX_REQUESTS, floori(float(pool) / PEOPLE_PER_TRIP))
		row.carry = pool % PEOPLE_PER_TRIP
		var origin: String = catchments[id]
		if not origin.is_empty() and adjust_amount.is_valid(): count = clampi(int(adjust_amount.call(origin, count, network)), 0, MAX_REQUESTS)
		var sample := {"tick": tick, "requested": count, "queued": 0, "no_station": 0, "no_service": 0, "no_express": 0, "full": 0}
		for _request in range(count):
			var destination_city := choose_destination(id, ids, rng)
			var destination: String = catchments.get(destination_city, "")
			var outcome := "no_station"
			if not origin.is_empty() and not destination.is_empty():
				var kind := Classes.LOCAL
				if Classes.distant(origin, destination, queues.station_catalog):
					row.express_progress = (int(row.express_progress) + 1) % 4
					if int(row.express_progress) == 0: kind = Classes.EXPRESS
				if Journeys.plan(network, origin, destination).is_empty(): outcome = "no_service"
				elif kind == Classes.EXPRESS and not direct_service(configurations, origin, destination): outcome = "no_express"
				elif queues.enqueue_trip(origin, destination, int(limits.get(origin, 100)), tick, kind): outcome = "queued"
				else: outcome = "full"
			sample[outcome] += 1
		row.history.append(sample)
		if row.history.size() > WINDOW: row.history.pop_front()

func choose_destination(origin: String, ids: Array, rng: RefCounted) -> String:
	var total := 0
	for id in ids:
		if id != origin: total += int(state.cities[id].population)
	if total == 0: return ""
	var draw: int = rng.randi_range(1, total)
	for id in ids:
		if id == origin: continue
		draw -= int(state.cities[id].population)
		if draw <= 0: return id
	return ""

static func direct_service(configurations: Dictionary, origin: String, destination: String) -> bool:
	for config in configurations.values():
		if Classes.service_can_carry(config, origin, destination): return true
	return false

func summary(id: String) -> Dictionary:
	var result := {"requested": 0, "queued": 0, "no_station": 0, "no_service": 0, "no_express": 0, "full": 0}
	for sample in state.cities.get(id, {}).get("history", []):
		for field in result: result[field] += int(sample[field])
	return result

func describe(id: String) -> String:
	if not state.cities.has(id): return ""
	var totals := summary(id)
	return "Population: %d (fixed for now)\nRecent city trip requests: %d | Joined station queues: %d\nNot queued: missing origin/destination station %d; no usable service %d; Express needs a direct service %d; origin queue full %d.\nLast %d arrival intervals (at most 60 simulation seconds of arrivals). Queued does not mean delivered. Requests not queued are counted here, not added to another station. Growth/decline is not active yet." % [state.cities[id].population, totals.requested, totals.queued, totals.no_station, totals.no_service, totals.no_express, totals.full, state.cities[id].history.size()]

static func valid(value: Variant, world: Dictionary, tick: int) -> bool:
	var expected := defaults(world)
	if not value is Dictionary or value.size() != 2 or not World.whole(value.get("schema_version"), 1, 1) or not value.get("cities") is Dictionary or value.cities.size() != expected.cities.size(): return false
	for id in expected.cities:
		var row: Variant = value.cities.get(id)
		if not row is Dictionary or row.size() != 4: return false
		if not World.whole(row.get("population"), 1, 1000000) or not World.whole(row.get("carry"), 0, PEOPLE_PER_TRIP - 1) or not World.whole(row.get("express_progress"), 0, 3): return false
		if not row.get("history") is Array or row.history.size() > WINDOW: return false
		var previous := 0
		for sample in row.history:
			if not sample is Dictionary or sample.size() != 7 or not World.whole(sample.get("tick"), previous, tick) or not World.whole(sample.get("requested"), 0, MAX_REQUESTS): return false
			previous = int(sample.tick)
			var accounted := 0
			for field in OUTCOMES:
				if not World.whole(sample.get(field), 0, MAX_REQUESTS): return false
				accounted += int(sample[field])
			if accounted != int(sample.requested): return false
	return true
