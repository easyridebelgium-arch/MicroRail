extends SceneTree
const Services = preload("res://scripts/service_routes.gd")
const Runtime = preload("res://scripts/core/runtime_routes.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	_run.call_deferred()
func tick(game: Node) -> void:
	game.sim_clock.begin_tick()
	game._simulation_step(1.0 / 60.0)
func advance_until(game: Node, predicate: Callable, limit: int = 4000) -> void:
	for step in range(limit):
		if predicate.call(): return
		tick(game)
	check(false, "Timed out waiting for loop movement")
func _run() -> void:
	# Use a desktop window size; headless defaults to 64x64.
	root.size = Vector2i(1280, 720)
	var defaults := Services.defaults()
	check(defaults.passenger.mode == "shuttle" and Services.is_valid(defaults), "Existing routes default to Shuttle")
	for mode in ["unknown", 2, null]:
		var invalid := defaults.duplicate(true)
		invalid.passenger.mode = mode
		check(not Services.is_valid(invalid), "Invalid route modes rejected")
	var invalid := defaults.duplicate(true)
	invalid.freight.mode = "loop"
	check(not Services.is_valid(invalid), "Freight retains its load/unload shuttle")
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.set_process(false)
	game.paused = true
	root.add_child(game)
	game.sim_rng.set_seed(12345)
	await process_frame
	game.set_process(false)
	game.paused = true
	for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
	# Bypass B on the A → C leg; keep the straight mainline for C → B → A.
	game.tracks[Vector2i(16, 8)] = "junction_6_2_4"
	game.tracks[Vector2i(24, 8)] = "junction_2_6_4"
	for y in [9, 10]:
		game.tracks[Vector2i(16, y)] = true
		game.tracks[Vector2i(24, y)] = true
	game.tracks[Vector2i(16, 11)] = Geometry.from_ports(Vector2i.UP, Vector2i.RIGHT)
	game.tracks[Vector2i(24, 11)] = Geometry.from_ports(Vector2i.UP, Vector2i.LEFT)
	for x in range(17, 24): game.tracks[Vector2i(x, 11)] = false
	game._check_route()
	var two_stop := Services.build(game.tracks, ["a", "b"], 32, {}, "loop")
	check(two_stop.distances.size() == 3 and not Runtime.passenger_path(two_stop.cells, ["a", "b"], 32, {}, "loop").is_empty(), "Two-stop Loop builds and restores its closing leg")
	# A real old-format Shuttle snapshot must load without changing its journey.
	game._save_game()
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	old.version = 20
	for service in ["passenger", "freight"]: old.services[service].erase("mode")
	var old_file := FileAccess.open("user://v20_shuttle.json", FileAccess.WRITE)
	old_file.store_string(JSON.stringify(old))
	old_file.close()
	var original: Vector2 = game.train_position
	tick(game)
	game._load_game("user://v20_shuttle.json")
	check(game.services.passenger.mode == "shuttle" and game.train_position == original and game.route_connected, "v20 Shuttle loads at the same physical position")
	game._open_routes_editor()
	await process_frame
	var editor = game.route_editor
	editor.station_choice.select(2)
	editor.add_button.pressed.emit()
	editor.stop_list.select(2)
	editor.up_button.pressed.emit()
	editor.route_mode.select(1)
	editor.route_mode.item_selected.emit(1)
	check(editor.draft.passenger.stops == ["a", "c", "b"] and editor.heading.text == "Stop sequence: A → C → B → A", "Mode selector previews requested itinerary")
	check(editor.waypoint_leg.item_count == 3 and editor.waypoint_leg.get_item_metadata(2) == "b>a", "Closing leg gets its own waypoint controls")
	editor.waypoint_x.value = 20
	editor.waypoint_y.value = 11
	editor.waypoint_add.pressed.emit()
	var before: Vector2 = game.train_position
	editor.confirmed.emit()
	check(game.services.passenger.mode == "loop" and game.train_position == before, "Apply changes mode at origin without relocation")
	check(game.stop_distances.size() == 4 and game.route_cells[0] == game.route_cells[-1], "Loop includes a complete last-to-first leg")
	var first_leg: Array[Vector2i] = game.route_cells.slice(0, game.route_cells.find(game.STATION_C) + 1)
	check(first_leg.has(Vector2i(20, 11)) and not first_leg.has(game.STATION_B), "A → C directive bypasses B")
	var rebuilt := Runtime.passenger_path(game.route_cells, game.services.passenger.stops, 32, game.services.passenger.waypoints, "loop")
	check(rebuilt.distances == game.stop_distances, "Saved loop geometry reconstructs every stopping distance")
	editor.hide()
	game.waiting_at_a = 5
	game.waiting_at_b = 5
	game.waiting_at_c = 5
	var visits: Array[int] = []
	var index: int = game.passenger_stop_index
	var largest_step := 0.0
	for step in range(4600):
		before = game.train_position
		tick(game)
		largest_step = maxf(largest_step, before.distance_to(game.train_position))
		if game.passenger_stop_index != index:
			index = game.passenger_stop_index
			visits.append(index)
			if visits.size() == 6: break
	check(visits == [1, 2, 0, 1, 2, 0], "Loop repeatedly visits C, B, A with no extra C return stop")
	check(largest_step < 2, "Lap wrap never jumps the physical train")
	check(game.route_distance == 0 and game.travelling_to_b and game.wait_remaining > 0, "Lap finishes with normal dwell at A")
	game._save_game()
	game._load_game()
	check(game.services.passenger.mode == "loop" and game.route_distance == 0 and game.route_connected, "Dwell at the wrapped origin survives save/load")
	# Save on the closing leg, which has no extra station index in the service list.
	advance_until(game, func() -> bool: return game.passenger_stop_index == 2 and game.route_distance > game.stop_distances[2] + 100)
	before = game.train_position
	var onboard: int = game.passengers_on_train
	game._save_game()
	tick(game)
	game._load_game()
	check(game.train_position == before and game.passengers_on_train == onboard and game._next_passenger_stop() == 0, "Closing-leg save resumes toward A with its load")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	var legacy := saved.duplicate(true)
	legacy.version = 20
	for service in ["passenger", "freight"]: legacy.services[service].erase("mode")
	var migrated: Dictionary = game.SaveMigrations.migrate(legacy)
	check(migrated.ok and migrated.data.services.passenger.mode == "shuttle" and not legacy.services.passenger.has("mode"), "v20 migration defaults to Shuttle without mutating input")
	var bad := saved.duplicate(true)
	bad.state.travelling_to_b = false
	var file := FileAccess.open("user://bad_loop.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(bad))
	file.close()
	game._load_game("user://bad_loop.json")
	check(game.train_position == before and game.travelling_to_b, "Invalid loop direction load is rejected atomically")
	var changed: Dictionary = game.services.duplicate(true)
	changed.passenger.mode = "shuttle"
	check(game.apply_service_routes(changed).contains("first stop") and game.train_position == before, "Mid-trip mode change cannot reset a train")
	# Test the physical reversal action with a confirmed cycle fixture. Detection
	# itself is exercised by test_deadlock_integration.gd.
	game.deadlocks.cycles = [[1, 2]]
	check(game.reverse_deadlocked_train(1).contains("reversed in place") and game.train_position == before, "Closing-leg reversal changes direction at the same location")
	check(game.passenger_returning and game._next_passenger_stop() == 2 and not game.travelling_to_b, "Reversal returns to departure B, not C or origin A")
	game._save_game()
	tick(game)
	game._load_game()
	check(game.train_position == before and game.passenger_returning and not game.travelling_to_b, "Unfinished closing-leg reversal restores exactly")
	advance_until(game, func() -> bool: return game.passenger_held)
	check(game.train_position.distance_to(game._cell_center(game.STATION_B)) < 0.1 and game.travelling_to_b and not game.passenger_returning, "Recovery parks at B ready to resume the loop")
	game._save_game()
	game._load_game()
	check(game.passenger_held and game.passenger_stop_index == 2, "Recovered closing-leg hold survives save/load")
	game.passenger_held = false
	game.passenger_service_enabled = true
	advance_until(game, func() -> bool: return game.route_distance > game.stop_distances[2] + 300)
	# Remove track behind while travelling west on B → A.
	game.tracks.erase(Vector2i(14, 8))
	game._check_route()
	check(game.route_connected, "Broken track behind does not stop closing-leg delivery")
	game.passenger_service_enabled = false
	advance_until(game, func() -> bool: return game.passenger_stop_index == 0)
	check(not game.route_connected and game.train_position == game._cell_center(game.STATION_A), "Next lap notices the gap ahead only after arriving at A")
	game.tracks[Vector2i(14, 8)] = false
	game._check_route()
	# Older C-bound riders may now beat newer A-bound riders at B. Withdrawal
	# must finish those accepted through journeys after the track is repaired.
	advance_until(game, func() -> bool: return not game._passenger_service_is_active())
	check(game.route_distance == 0 and game.passengers_on_train == 0, "Withdrawal completes accepted journeys and parks empty at A")
	game._open_routes_editor()
	await process_frame
	editor.waypoint_leg.select(2)
	editor.waypoint_x.value = 10
	editor.waypoint_y.value = 8
	editor.waypoint_add.pressed.emit()
	check(editor.draft.passenger.waypoints["b>a"] == [[10, 8]], "Closing-leg waypoint is editable independently")
	editor.confirmed.emit()
	check(game.services.passenger.waypoints["b>a"] == [[10, 8]] and game.route_connected, "Closing-leg directive builds a valid loop")
	editor.route_mode.item_selected.emit(0)
	check(editor.waypoint_leg.item_count == 2 and not editor.draft.passenger.waypoints.has("b>a"), "Shuttle mode discards obsolete closing-leg directives in draft")
	editor.hide()
	check(game.services.passenger.mode == "loop", "Cancel leaves the live route mode intact")
	var old_scale: float = Settings.ui_scale
	Settings.ui_scale = 2
	game._apply_settings()
	game._open_routes_editor()
	await process_frame
	await process_frame
	check(editor.size.x <= root.get_visible_rect().size.x and editor.size.y <= root.get_visible_rect().size.y and editor.get_ok_button().get_global_rect().end.y <= editor.size.y, "Loop editor and Apply fit at 200% scale")
	Settings.ui_scale = old_scale
	game._apply_settings()
	editor.hide()
	game.queue_free()
	await process_frame
	# Full simulation, including events and money, must be independent of FPS.
	var reference: Array = []
	for fps in [30, 60, 120]:
		game = load("res://scenes/main/main.tscn").instantiate()
		game.set_process(false)
		game.paused = true
		root.add_child(game)
		game.sim_rng.set_seed(12345)
		await process_frame
		game.set_process(false)
		game.paused = true
		for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
		game._check_route()
		var config := Services.defaults()
		config.passenger.stops = ["a", "c", "b"]
		config.passenger.mode = "loop"
		game.apply_service_routes(config)
		game.event_log.clear()
		game.sim_clock.reset()
		game.passenger_timer = 0
		game.operating_timer = 0
		game.log_production_timer = 0
		game.sim_clock.speed = 10
		game.paused = false
		for frame in range(fps * 4): game._process(1.0 / fps)
		var snapshot: Array = [game.sim_clock.tick, game.route_distance, game.passenger_stop_index, game.passengers_on_train, game.waiting_at_a, game.waiting_at_b, game.waiting_at_c, game.money, game.event_log.save_state(), game.reservations.owners]
		check(game.sim_clock.tick == 2400, "10× loop clock runs 40 simulated seconds")
		if reference.is_empty(): reference = snapshot
		check(snapshot == reference, "Loop movement, reservations and events match at %d FPS" % fps)
		game.queue_free()
		await process_frame
	print("Loop routes: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
