extends SceneTree
const Demand = preload("res://scripts/core/passenger_demand.gd")
const Rng = preload("res://scripts/core/sim_rng.gd")
const Migrations = preload("res://scripts/core/save_migrations.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var demand := Demand.new()
	check(demand.queues.a == {"b": 4, "c": 4} and demand.waiting("a") == 8, "initial demand is split between other stations")
	check(Demand.future_stops(["a", "b", "c"], 1, true, "shuttle") == ["c"] and Demand.future_stops(["a", "b", "c"], 1, false, "shuttle") == ["a"], "Shuttle only boards in the current direction")
	check(Demand.future_stops(["a", "b", "c"], 2, true, "loop") == ["a", "b"], "Loop includes destinations beyond its closing stop")
	demand.queues.a = {"b": 3, "c": 5}
	var manifest: Dictionary = {}
	check(demand.board("a", ["b", "c"], 4, manifest) == 4 and manifest == {"b": 3, "c": 1}, "capacity is shared between destinations in upcoming-stop order")
	check(Demand.alight(manifest, "b") == 3 and manifest == {"c": 1}, "through passengers stay aboard at intermediate stops")
	demand.queues.b = {"a": 4, "c": 2}
	check(demand.board("b", ["c"], 4, manifest) == 2 and manifest == {"c": 3} and demand.queues.b == {"a": 4}, "opposite-direction passengers remain in the queue")
	demand.return_to("b", manifest)
	check(manifest.is_empty() and demand.queues.b == {"a": 4, "c": 3}, "recovery returns each unfinished destination without loss")
	demand.queues.a = {"c": 10}
	check(demand.board("a", ["b"], 20, manifest) == 0 and demand.waiting("a") == 10, "unserved destinations are not boarded or discarded")
	demand.reset_total("a", 105)
	var rng := Rng.new(12345)
	var state := rng.save_state()
	check(demand.generate("a", 3, 100, rng) == 0 and demand.waiting("a") == 105 and rng.save_state() == state, "queue cap preserves recovery overflow and consumes no unnecessary RNG")
	var first := Demand.new()
	var second := Demand.new()
	var rng2 := Rng.new(12345)
	first.generate("a", 3, 100, rng)
	second.generate("a", 3, 100, rng2)
	check(first.queues == second.queues and first.waiting("a") == 11, "generation uses the owned seeded RNG")
	check(not Demand.valid_counts({"b": -1}, ["b"]) and not Demand.valid_counts({"b": 1.5}, ["b"]) and not Demand.valid_counts({"d": 1}, ["b"]), "invalid destination counts are rejected")
	var legacy := {"version": 24, "state": {"waiting_at_a": 9, "waiting_at_b": 0, "waiting_at_c": 3, "passengers_on_train": 7, "passenger_stop_index": 0, "travelling_to_b": true}, "services": {"passenger": {"stops": ["a", "b"]}}, "runtime": {}, "passenger_services": {}}
	var migrated := Migrations.migrate(legacy)
	check(migrated.ok and Demand.total(migrated.data.demand.queues.a) == 9 and migrated.data.demand.primary == {"b": 7} and not legacy.has("demand"), "legacy queues preserve totals and aboard riders keep their next destination")
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	var configuration: Dictionary = game.services.duplicate(true)
	configuration.passenger.stops = ["a", "b", "c"]
	check(game.apply_service_routes(configuration).begins_with("Routes applied"), "three-stop service is available")
	for station in Demand.STATIONS: game.passenger_demand.queues[station] = {}
	game.passenger_demand.queues.a = {"b": 3, "c": 5}
	game.passenger_demand.queues.b = {"a": 2, "c": 4}
	var initial: int = game.waiting_at_a + game.waiting_at_b
	var reached_b := false
	for step in range(600):
		game._rebuild_reservations(true)
		game._move_train(1.0 / 60.0)
		if game.passenger_stop_index == 1:
			reached_b = true
			break
	check(reached_b and game.passengers_delivered == 3 and game.passenger_destinations == {"c": 5}, "A-C passengers remain on the actual train at B")
	game._save_game()
	var position: Vector2 = game.train_position
	var payload: Dictionary = game.passenger_destinations.duplicate(true)
	game.passenger_destinations.clear()
	game._load_game()
	check(game.train_position == position and game.passenger_destinations == payload, "save/load keeps through passengers at their physical stop")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	var bad: Dictionary = saved.duplicate(true)
	bad.demand.primary.c += 1
	check(not game._is_valid_save(bad), "manifest/aggregate mismatch is rejected")
	bad = saved.duplicate(true)
	bad.demand.queues.a["a"] = 1
	check(not game._is_valid_save(bad), "same-origin destination queue is rejected")
	for step in range(1200):
		game._rebuild_reservations(true)
		game._move_train(1.0 / 60.0)
		if game.passenger_stop_index == 2: break
	check(game.passengers_delivered == 12 and game.passengers_on_train == 0 and game.waiting_at_b == 2, "C receives its through and newly boarded passengers; B-A demand stays waiting")
	check(game.passengers_delivered + game.waiting_at_a + game.waiting_at_b + game.waiting_at_c + game.passengers_on_train == initial, "passenger conservation holds across destinations")
	game.selected_station = game.STATION_B
	game.station_panel.show()
	game._update_station_inspector()
	check(game.station_details.text.contains("To Station A: 2") and game.station_details.text.contains("Waiting capacity"), "station inspector explains destination demand and queue capacity")
	game.queue_free()
	await process_frame
	# Additional services retain the same destination manifests through stops.
	game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	game.passenger_held = true
	game.money = 100000
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	var purchase: Dictionary = game.buy_fleet_train("passenger_standard")
	game.start_passenger_service(int(purchase.id), "b")
	var key: String = game.Fleet.find(game.fleet, int(purchase.id)).service
	configuration = game.services.duplicate(true)
	configuration[key].stops = ["b", "c", "a"]
	check(game.apply_service_routes(configuration).begins_with("Routes applied"), "additional service can visit C before A")
	for station in Demand.STATIONS: game.passenger_demand.queues[station] = {}
	game.passenger_demand.queues.b = {"c": 3, "a": 5}
	game.paused = false
	for step in range(600):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
		if game.passenger_services[key].stop_index == 1: break
	check(game.passengers_delivered == 3 and game.passenger_services[key].passenger_destinations == {"a": 5}, "additional service delivers C passengers and keeps A passengers aboard")
	game._save_game()
	position = game.passenger_services[key].position
	game.passenger_services[key].passenger_destinations.clear()
	game._load_game()
	check(game.passenger_services[key].passenger_destinations == {"a": 5} and game.passenger_services[key].position == position, "additional through-passenger manifest and position survive loading")
	game.queue_free()
	await process_frame
	print("Passenger demand: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
