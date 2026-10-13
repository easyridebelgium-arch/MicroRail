extends SceneTree
const Tables = preload("res://scripts/core/timetable.gd")
const Services = preload("res://scripts/service_routes.gd")
const Migrations = preload("res://scripts/core/save_migrations.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: _run.call_deferred()
func tick(game: Node) -> void:
	game.sim_clock.begin_tick()
	game._simulation_step(1.0 / 60.0)
func fixture() -> Node:
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	game.sim_rng.set_seed(12345)
	game.set_process(false)
	game.paused = true
	game.money = 100000
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	return game
func config(game: Node) -> Dictionary:
	var result: Dictionary = game.services.duplicate(true)
	result.passenger.stops = ["a", "b", "c"]
	result.passenger.timetable = [360]
	result.passenger.stop_timetables = {"b>c": [375], "c>b": [390], "b>a": [405]}
	return result
func _run() -> void:
	check(Tables.departure_legs(["a", "b", "c"], "shuttle") == ["a>b", "b>c", "c>b", "b>a"], "Shuttle offers separate outbound and return directions")
	check(Tables.departure_legs(["a", "c", "b"], "loop") == ["a>c", "c>b", "b>a"], "Loop offers its actual closing departure")
	var base := Services.defaults()
	base.passenger.stop_timetables = {"b>a": [380]}
	check(Services.is_valid(base), "return departure timetable is valid")
	for invalid in [{"a>b": [380]}, {"c>a": [380]}, {"b>a": [380, 370]}, {"b>a": [380.5]}, {"b>a": "06:20"}]:
		base.passenger.stop_timetables = invalid
		check(not Services.is_valid(base), "malformed or duplicate first-leg schedule is refused")
	base.passenger.stop_timetables = {"b>a": [380.0]}
	check(typeof(Services.from_save(base).passenger.stop_timetables["b>a"][0]) == TYPE_INT, "JSON departure times normalize to integers")
	var migrated := Migrations.migrate({"version": 23})
	check(migrated.ok and migrated.data.dispatch == {"headways": {}, "timetables": {}}, "old saves gain empty dispatch progress")
	root.size = Vector2i(1280, 720)
	var reference: Array = []
	for fps in [30, 60, 120]:
		var game := fixture()
		check(game.apply_service_routes(config(game)).begins_with("Routes applied"), "direction-specific times apply")
		game.paused = false
		for frame in range(45 * fps): game._process(1.0 / fps)
		var measured: Array = [game.route_distance, game.passenger_stop_index, game.passengers_delivered, game.timetable_state.duplicate(true), game.headway_log.duplicate(true)]
		if reference.is_empty(): reference = measured
		check(measured == reference, "timed departures and demand agree across rendering FPS")
		for entry in [["passenger", 360], ["passenger:b>c", 375], ["passenger:c>b", 390], ["passenger:b>a", 405]]:
			var state: Dictionary = game.timetable_state[entry[0]]
			check(state.served == 1 and state.last == entry[1] and state.delays == [0], "train departs each direction exactly on time")
		check(game.timetable_report("passenger").contains("B → A") and game.headway_log.passenger.size() == 1, "report shows later stops without counting them as origin headways")
		game.queue_free()
		await process_frame
	# Save at B before its B->C time, then load into a later simulation.
	var game := fixture()
	game.apply_service_routes(config(game))
	game.paused = false
	for i in range(60 * 10): tick(game)
	check(game.passenger_stop_index == 1 and game.train_position == game._cell_center(game.STATION_B), "train waits physically at B rather than leaving early")
	check(game.train_diagnostics(1).state == "Scheduled departure hold" and game.traffic_metrics.statistics(1).continuous_seconds == 0.0, "inspector distinguishes timetable hold from traffic wait")
	check(not game.reservation_trains[1].moving, "timetable hold does not request movement authority ahead")
	var editor = game.route_editor
	game.paused = true
	editor.open_editor()
	check(editor.timetable_leg.item_count == 4, "editor lists all Shuttle directions")
	editor.timetable_leg.select(1)
	editor.timetable_leg.item_selected.emit(1)
	check(editor.timetable_field.text == "06:15", "editor shows selected later-stop times")
	editor.timetable_field.text = "06:16, 06:30"
	check(editor._set_timetable() and editor.draft.passenger.stop_timetables["b>c"] == [376, 390], "later times edit independently in draft")
	editor.hide()
	game.paused = false
	game._save_game()
	var before: Dictionary = game.timetable_state.duplicate(true)
	var position: Vector2 = game.train_position
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	for i in range(60 * 20): tick(game)
	game._load_game()
	check(game.timetable_state == before and game.train_position == position and game.headway_log.passenger.size() == 1, "load restores timetable cursors, origin headways and physical position: %s, %s / %s" % [game.notice, str(game.timetable_state), str(before)])
	for i in range(60 * 5 + 1): tick(game)
	check(game.timetable_state["passenger:b>c"].served == 1 and game.timetable_state.passenger.served == 1, "load does not reuse the earlier origin slot")
	var bad: Dictionary = saved.duplicate(true)
	bad.dispatch.timetables.passenger.last = 999999999
	check(not game._is_valid_save(bad), "future dispatch cursor is rejected")
	bad = saved.duplicate(true)
	bad.dispatch.headways.passenger = [1.5]
	check(not game._is_valid_save(bad), "fractional departure ticks are rejected")
	# An occupied destination platform holds this train at its departure stop.
	game.queue_free()
	await process_frame
	game = fixture()
	game.tracks[Vector2i(8, 8)] = "junction_6_2_4"
	game.tracks[Vector2i(16, 8)] = "junction_2_6_4"
	game._check_route()
	var blocked: Dictionary = game.services.duplicate(true)
	blocked.passenger.timetable = [360, 361, 362]
	game.apply_service_routes(blocked)
	var purchased: Dictionary = game.buy_fleet_train("passenger_standard")
	game.start_passenger_service(int(purchased.id), "b")
	var blocking_service: String = game.Fleet.find(game.fleet, int(purchased.id)).service
	var parked: Dictionary = game.services.duplicate(true)
	parked[blocking_service].stops = ["b", "c"]
	game.apply_service_routes(parked)
	game.passenger_services[blocking_service].enabled = false
	game.paused = false
	for i in range(60 * 3): tick(game)
	check(game.route_distance == 0 and game.timetable_state.passenger.served == 0 and not game.headway_log.has("passenger"), "blocked nose at origin does not consume any timetable slot: %s, distance %.2f" % [str(game.timetable_state), game.route_distance])
	game.paused = true
	check(game.remove_passenger_service(int(purchased.id)).begins_with("Service removed"), "parked blocker is stored through the normal Fleet operation")
	game.paused = false
	tick(game)
	check(game.timetable_state.passenger.served == 1 and game.timetable_state.passenger.missed == 2 and game.timetable_state.passenger.delays == [1], "late physical departure records latest due slot and missed predecessors")
	# Source-only schedules are shared once by linked services.
	var linked := config(game)
	linked["passenger_3"] = linked.passenger.duplicate(true)
	linked.passenger_3.link = "passenger"
	check(Tables.schedule_map(linked).size() == 4, "linked trains share directional timetable cursors")
	game.queue_free()
	await process_frame
	# An independently created passenger service uses the same later-stop hooks.
	game = fixture()
	var independent: Dictionary = game.services.duplicate(true)
	independent.passenger.timetable = [480]
	game.apply_service_routes(independent)
	purchased = game.buy_fleet_train("passenger_standard")
	game.start_passenger_service(int(purchased.id), "b")
	var extra_key: String = game.Fleet.find(game.fleet, int(purchased.id)).service
	independent = game.services.duplicate(true)
	independent[extra_key].stops = ["b", "c"]
	independent[extra_key].timetable = [360]
	independent[extra_key].stop_timetables = {"c>b": [375]}
	check(game.apply_service_routes(independent).begins_with("Routes applied"), "extra service accepts its own directional timetable")
	game.paused = false
	for i in range(60 * 10): tick(game)
	check(game.passenger_services[extra_key].stop_index == 1 and game.passenger_services[extra_key].position == game._cell_center(game.STATION_C) and game.train_diagnostics(int(purchased.id)).state == "Scheduled departure hold", "extra service waits at C for its return departure")
	for i in range(60 * 5 + 1): tick(game)
	check(game.timetable_state[extra_key + ":c>b"].served == 1, "extra service physically departs on its later-stop schedule")
	game.queue_free()
	await process_frame
	print("Stop timetables: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
