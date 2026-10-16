extends SceneTree
const Start = preload("res://scripts/core/sandbox_start.gd")
const Generator = preload("res://scripts/core/world_generator.gd")
const Fleet = preload("res://scripts/fleet.gd")
const Services = preload("res://scripts/service_routes.gd")
const Demand = preload("res://scripts/core/passenger_demand.gd")
const Amenities = preload("res://scripts/core/amenities.gd")
const Satisfaction = preload("res://scripts/core/passenger_satisfaction.gd")
const Response = preload("res://scripts/core/demand_response.gd")
const Classes = preload("res://scripts/core/passenger_classes.gd")
const Rng = preload("res://scripts/core/sim_rng.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Fleet.is_valid(Fleet.defaults()) and Services.is_valid(Services.defaults()), "tutorial validators retain their defaults")
	check(not Fleet.is_valid(Fleet.empty()) and Fleet.is_valid(Fleet.empty(), false), "empty fleet requires explicit startup policy")
	check(not Services.is_valid({}, {}) and Services.is_valid({}, {}, {}, false), "no-station/no-service startup is explicit, never a relaxed default save")
	var single := {"next_id": 2, "trains": [Fleet.make_train(1, "passenger_standard")]}
	check(Fleet.is_valid(single, false) and not Fleet.is_valid(single), "first purchased but unassigned train is valid only under the new policy")
	var invalid: Dictionary = single.duplicate(true)
	invalid.trains[0].service = "freight"
	check(not Fleet.is_valid(invalid, false), "relaxed startup still rejects mismatched train/service kinds")
	invalid = single.duplicate(true)
	invalid.trains.append(invalid.trains[0].duplicate(true))
	check(not Fleet.is_valid(invalid, false), "relaxed startup still rejects duplicate IDs")
	invalid = {"freight": Services.defaults().freight}
	check(Services.is_valid(invalid, {}, {}, false) and not Services.is_valid(invalid), "freight-only operation needs no passenger stations under the explicit policy")
	check(not Services.is_valid({"passenger": Services.defaults().passenger}, {}, {}, false), "a passenger service cannot invent stations")
	var excessive: Dictionary = {}
	for index in range(9): excessive["passenger_%d" % (index + 1)] = Services.defaults().passenger.duplicate(true)
	check(not Services.is_valid(excessive, Services.STATIONS, {}, false), "eight-passenger-service limit also holds when freight is absent")
	var start := Start.new()
	check(not start.station_preview(Vector2i(1, 1)).ok and not start.commit_station({}, {}, {}).ok, "uninitialized startup cannot build")
	check(not start.initialize("invalid").ok and not start.initialized and start.world == null and start.money == 0, "invalid seed leaves startup untouched")
	check(start.initialize("42", 8).ok, "valid seeded startup initializes")
	var generated := Generator.generate("42", 8)
	check(start.world.save_state() == generated.world and start.world.stations().is_empty(), "startup adopts generated geometry without tutorial stations")
	check(start.tracks.is_empty() and start.services.is_empty() and start.fleet == Fleet.empty(), "no platform rail, services or train IDs are preassigned")
	check(start.demand.station_ids.is_empty() and start.demand.queues.is_empty() and start.demand.batches.is_empty(), "cities without stations have no phantom station queues")
	check(start.amenities.owned.is_empty() and start.satisfaction.history.is_empty() and start.demand_response.state.is_empty() and start.journey_ledger.aboard.is_empty(), "all station-owned state starts empty")
	check(start.money == 5000 and start.total_construction_cost == 0 and start.sim_clock.tick == 0 and start.command_queue.is_empty(), "fresh provisional sandbox funds and fixed clock, with no queued tutorial commands")
	check(start.sim_rng.save_state() == generated.rng_state, "startup continues generation RNG rather than reseeding")
	var mirror := Start.new()
	mirror.initialize("42", 8)
	check(start.world.save_state() == mirror.world.save_state() and start.sim_rng.save_state() == mirror.sim_rng.save_state(), "two starts reproduce geometry and random stream")
	var candidates: Array = generated.planning.station_candidates
	var first := Vector2i(candidates[0].cell[0], candidates[0].cell[1])
	var far_index := 1
	for index in range(1, candidates.size()):
		var candidate := Vector2i(candidates[index].cell[0], candidates[index].cell[1])
		if (candidate - first).length_squared() >= 32 * 32:
			far_index = index
			break
	var second := Vector2i(candidates[far_index].cell[0], candidates[far_index].cell[1])
	var rng_before: Dictionary = start.sim_rng.save_state()
	check(start.commit_station(start.station_draft(first), {}, {}).ok, "first station adopts construction snapshots")
	var first_id: String = start.world.station_key(first)
	check(start.demand.station_ids == [first_id] and start.demand.waiting(first_id) == 0, "first station has no impossible destinations or free tutorial passengers")
	check(start.commit_station(start.station_draft(second), {}, {}).ok, "second station extends state")
	var second_id: String = start.world.station_key(second)
	check(start.demand.waiting(first_id) == 0 and start.demand.waiting(second_id) == 0, "adding a destination does not manufacture starter queues")
	check(Classes.distant(first_id, second_id, start.world.stations()) and start.demand.class_progress.has(first_id), "new distant pair gets class-progress slots without generating arrivals")
	check(start.tracks.size() == 10 and start.money == 4400 and start.total_construction_cost == 600, "two stations account for platform rail and station costs once")
	check(start.fleet.trains.is_empty() and start.services.is_empty() and start.sim_rng.save_state() == rng_before, "station purchases neither spawn services nor consume RNG")
	check(mirror.world.stations().is_empty() and mirror.tracks.is_empty() and mirror.money == 5000, "separate starts do not share mutable catalogs or funds")
	start.sim_clock.tick = 900
	start.demand.reset_total(first_id, 7, 120)
	start.amenities.owned[first_id].append("shelter")
	start.amenities.carry[first_id] = 37
	start.satisfaction.history[first_id].append({"count": 2, "tick": 700, "wait": 30, "comfort": 3})
	start.demand_response.state[first_id] = {"factor": 103, "carry": 23}
	start.demand.class_progress[first_id] = 3
	start.journey_ledger.aboard["fixture_service"] = [{"destination": second_id, "origin": first_id, "start": 100, "known": true, "count": 2, "class": "local"}]
	start.journey_ledger.completed.append({"destination": second_id, "origin": first_id, "start": 100, "end": 500, "known": true, "count": 3, "class": "local"})
	start.journey_ledger.unknown_completed = 4
	var old_demand: RefCounted = start.demand
	var old_queue: Dictionary = start.demand.queues[first_id].duplicate(true)
	var old_batches: Array = start.demand.batches[first_id].duplicate(true)
	var old_aboard: Dictionary = start.journey_ledger.aboard.duplicate(true)
	var old_completed: Array = start.journey_ledger.completed.duplicate(true)
	var third_index := 1 if far_index != 1 else 2
	var third := Vector2i(candidates[third_index].cell[0], candidates[third_index].cell[1])
	check(start.commit_station(start.station_draft(third), {}, {}).ok, "third station can be added after station-owned state has accumulated")
	var third_id: String = start.world.station_key(third)
	check(start.demand.queues[first_id] == old_queue and start.demand.batches[first_id] == old_batches and start.demand.waiting(third_id) == 0, "existing queue ages/origins/counts persist; new station is empty")
	check(start.demand.class_progress[first_id] == 3 and Classes.valid_progress(start.demand.class_progress, start.world.stations()), "existing class counters survive expanded eligibility")
	check(start.amenities.owned[first_id] == ["shelter"] and start.amenities.carry[first_id] == 37 and start.amenities.owned[third_id].is_empty(), "amenities and fractional arrival carry survive; new station defaults independently")
	check(start.satisfaction.history[first_id].size() == 1 and start.satisfaction.history[third_id].is_empty() and Satisfaction.valid_state(start.satisfaction.save_state(), 900, start.world.stations().keys()), "measured waiting history is preserved and remains valid")
	check(start.demand_response.state[first_id] == {"factor": 103, "carry": 23} and start.demand_response.state[third_id] == {"factor": 100, "carry": 0}, "existing response state survives; new station starts neutral")
	check(start.journey_ledger.aboard == old_aboard and start.journey_ledger.completed == old_completed and start.journey_ledger.unknown_completed == 4 and start.journey_ledger.station_ids.size() == 3, "unfinished journey clocks, completed history and prior counts survive station expansion")
	check(start.sim_clock.tick == 900 and start.sim_rng.save_state() == rng_before, "building does not advance time or the RNG")
	old_demand.queues[first_id].clear()
	check(start.demand.queues[first_id] == old_queue, "expanded station models do not alias superseded state")
	var ids: Array = start.world.stations().keys()
	check(Demand.valid_state(start.demand.save_state({}, 900), {"passengers_on_train": 0}, {}, 900, ids, start.world.stations()) and Amenities.valid_save(start.amenities.to_save(), ids) and Response.valid_state(start.demand_response.save_state(), ids), "expanded state validates using the new catalog")
	var fourth_index := 0
	while fourth_index in [0, far_index, third_index]: fourth_index += 1
	var fourth := Vector2i(candidates[fourth_index].cell[0], candidates[fourth_index].cell[1])
	var pending := start.station_draft(fourth)
	var previous_world: Dictionary = start.world.save_state()
	var previous_demand: RefCounted = start.demand
	var previous_money: int = start.money
	var previous_cost: int = start.total_construction_cost
	check(not start.commit_station(pending, {}, {fourth: 77}).ok, "a train claim arriving after preview prevents the purchase")
	check(start.world.save_state() == previous_world and start.demand == previous_demand and start.money == previous_money and start.total_construction_cost == previous_cost, "rejected purchase cannot partially replace catalog, metrics or funds")
	check(not start.initialize("99", 3).ok and start.world.save_state() == previous_world, "reinitialization cannot discard an existing construction session")
	check(Demand.new().waiting("a") == 8, "tutorial retains its original starter queues")
	var continued := Rng.new()
	continued.restore_state(JSON.parse_string(JSON.stringify(rng_before)))
	check(continued.randi() == start.sim_rng.randi(), "continuation remains JSON-safe after startup and purchases")
	print("Sandbox start: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
