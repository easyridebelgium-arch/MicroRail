extends SceneTree
const Start = preload("res://scripts/core/sandbox_start.gd")
const Model = preload("res://scripts/core/city_demand.gd")
const Generator = preload("res://scripts/core/world_generator.gd")
const Demand = preload("res://scripts/core/passenger_demand.gd")
const Classes = preload("res://scripts/core/passenger_classes.gd")
const SimRng = preload("res://scripts/core/sim_rng.gd")
class LastDestination extends RefCounted:
	func randi_range(_low: int, high: int) -> int: return high
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var boot := Start.new()
	boot.initialize("42", 3)
	var world: Dictionary = boot.world.save_state()
	for index in range(3): world.settlements[index].cell = [[10, 8], [30, 8], [55, 8]][index]
	boot.world.restore_state(world)
	var model: RefCounted = boot.city_demand
	var rng := SimRng.new(123)
	check(Model.valid(model.save_state(), world, 0) and model.state.cities["town:01"].population == 800, "stable initial population without consuming RNG")
	for index in range(20): model.generate(world, boot.demand, {}, rng, index * 300)
	check(boot.demand.queues.is_empty(), "unserved cities do not generate phantom station queues")
	var report: Dictionary = model.summary("town:01")
	check(report.requested == report.no_station and report.queued == 0 and model.state.cities["town:01"].history.size() == 12, "bounded missing-station accounting conserves city requests")
	check(Model.valid(model.save_state(), world, 6000), "bounded city history validates")
	var planning: Array = Generator.planning(world).station_candidates
	for candidate in planning:
		var result := boot.commit_station(boot.station_draft(Vector2i(candidate.cell[0], candidate.cell[1])), {}, {})
		check(result.ok, "build exclusive city station")
	world = boot.world.save_state()
	check(model == boot.city_demand and model.summary("town:01").no_station == report.no_station, "station construction keeps population and unmet history")
	model.initialize(world)
	var ids: Array = boot.demand.station_ids
	var a: String = ids[0]
	var b: String = ids[1]
	var c: String = ids[2]
	var fixed := LastDestination.new()
	var configurations := {"passenger_1": {"stops": [a, b], "mode": "shuttle"}, "passenger_2": {"stops": [b, c], "mode": "shuttle"}}
	model.generate(world, boot.demand, {}, fixed, 6000)
	check(model.summary("town:01").no_service == 2 and boot.demand.waiting(a) == 0, "track/stations alone do not count as a useful passenger service")
	model.initialize(world)
	model.generate(world, boot.demand, configurations, fixed, 6300)
	model.generate(world, boot.demand, configurations, fixed, 6600)
	report = model.summary("town:01")
	check(report.queued == 3 and report.no_express == 1 and boot.demand.queues[a].get(c) == 3, "Local trips accept transfers; every fourth distant request needs direct Express service")
	check(boot.demand.waiting_groups(a, 6600).all(func(row: Dictionary) -> bool: return row.origin == a and row.destination == c and row.known), "city catchment maps to stable final station destination and original queue clock")
	configurations.passenger_3 = {"stops": [a, c], "mode": "shuttle"}
	model.generate(world, boot.demand, configurations, fixed, 6900)
	model.generate(world, boot.demand, configurations, fixed, 7200)
	check(Classes.counts(boot.demand.batches[a]).express == 1 and boot.demand.waiting(a) == 7, "direct service admits Express requests without duplicating old waiting passengers")
	var before: int = boot.demand.waiting(a)
	model.generate(world, boot.demand, configurations, fixed, 7500, {a: before})
	check(boot.demand.waiting(a) == before and model.summary("town:01").full == 2, "full origin queue counts unmet requests without rerouting or removing passengers")
	# Removing a destination's catchment never reroutes trips into another station.
	var without_destination := world.duplicate(true)
	for site in without_destination.facilities:
		if site.stop_id == c: site.enabled = false
	model.generate(without_destination, boot.demand, configurations, fixed, 7800)
	check(boot.demand.waiting(a) == before and model.summary("town:01").no_station == 2, "unbuilt/unavailable destination catchment records unmet demand")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(model.save_state()))
	check(Model.valid(saved, world, 7800), "JSON state validates by value")
	var restored := Model.new()
	restored.restore_state(saved)
	check(restored.save_state() == model.save_state(), "population, carry, Express progress and history normalize exactly")
	for field in ["carry", "population", "express_progress"]:
		var bad := saved.duplicate(true)
		bad.cities["town:01"][field] = -1
		check(not Model.valid(bad, world, 7800), "reject invalid city field: " + field)
	var bad := saved.duplicate(true)
	bad.cities["town:01"].history[-1].queued += 1
	check(not Model.valid(bad, world, 7800), "reject requests counted twice")
	bad = saved.duplicate(true)
	bad.cities["town:01"].history[-1].tick = 7801
	check(not Model.valid(bad, world, 7800), "reject future history")
	bad = saved.duplicate(true)
	bad.cities["town:missing"] = bad.cities["town:01"]
	check(not Model.valid(bad, world, 7800), "reject phantom city")
	bad = saved.duplicate(true)
	bad.cities.erase("town:02")
	check(not Model.valid(bad, world, 7800), "reject missing city state")
	# Seeded weighted choices and saved remainders continue exactly after JSON.
	var reference := Model.new()
	reference.restore_state(saved)
	var queues := Demand.new(ids, boot.world.stations(), 0)
	var queues_copy := Demand.new(ids, boot.world.stations(), 0)
	var saved_rng := rng.save_state()
	var resumed_rng := SimRng.new()
	resumed_rng.restore_state(JSON.parse_string(JSON.stringify(saved_rng)))
	model.generate(world, queues, configurations, rng, 8100)
	reference.generate(world, queues_copy, configurations, resumed_rng, 8100)
	check(model.save_state() == reference.save_state() and queues.save_state({}, 8100) == queues_copy.save_state({}, 8100) and rng.save_state() == resumed_rng.save_state(), "weighted city trips and class intent continue deterministically after save/load")
	check(Model.defaults({"settlements": null}).cities.is_empty() and Model.defaults({"settlements": [null]}).cities.is_empty(), "migration defaults tolerate malformed input until validation rejects it")
	print("City demand: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
