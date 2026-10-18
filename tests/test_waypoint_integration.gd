extends SceneTree
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
func add_loop(game: Node, left: int, right: int, row: int) -> void:
	game.tracks[Vector2i(left, row)] = "junction_6_2_4"
	game.tracks[Vector2i(right, row)] = "junction_2_6_4"
	for y in range(row + 1, row + 3):
		game.tracks[Vector2i(left, y)] = true
		game.tracks[Vector2i(right, y)] = true
	game.tracks[Vector2i(left, row + 3)] = Geometry.from_ports(Vector2i.UP, Vector2i.RIGHT)
	game.tracks[Vector2i(right, row + 3)] = Geometry.from_ports(Vector2i.UP, Vector2i.LEFT)
	for x in range(left + 1, right): game.tracks[Vector2i(x, row + 3)] = false
func _run() -> void:
	# Use a desktop window size; headless defaults to 64x64.
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.set_process(false)
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
	for x in range(8, 29): game.tracks[Vector2i(x, 24)] = false
	add_loop(game, 8, 16, 8)
	add_loop(game, 12, 24, 24)
	game._check_route()
	var passenger_position: Vector2 = game.train_position
	var freight_position: Vector2 = game.freight_train.position
	game._use_waypoint_tool(Vector2i(12, 11))
	await process_frame
	var editor = game.route_editor
	check(game.paused and editor.visible and editor.waypoint_x.value == 12 and editor.waypoint_y.value == 11, "map tool opens paused Routes with selected coordinates")
	editor.waypoint_add.pressed.emit()
	check(editor.draft.passenger.waypoints["a>b"] == [[12, 11]] and game.services.passenger.waypoints.is_empty(), "Add changes draft only")
	editor.service_choice.item_selected.emit(1)
	editor.waypoint_x.value = 18
	editor.waypoint_y.value = 27
	editor.waypoint_add.pressed.emit()
	editor.confirmed.emit()
	check(game.route_cells.has(Vector2i(12, 11)) and game.freight_train.route_cells.has(Vector2i(18, 27)), "both services adopt chosen bypasses")
	check(game.train_position == passenger_position and game.freight_train.position == freight_position, "applying at physical origins does not teleport")
	check(game.stop_distances.size() == 2, "waypoint creates no passenger station stop")
	editor.hide()
	game.waiting_at_a = 4
	game.forest_stock = 8
	game.paused = false
	var waypoint_passed := false
	for tick in range(450):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
		if game.train_position.y > game._cell_center(Vector2i(12, 11)).y - 1:
			waypoint_passed = true
			check(game.wait_remaining == 0 and game.passenger_stop_index == 0, "passing waypoint has no dwell or stop-index change")
	check(waypoint_passed, "train physically uses bypass")
	game.paused = true
	var position: Vector2 = game.train_position
	var configuration: Dictionary = game.services.duplicate(true)
	configuration.passenger.waypoints = {}
	check(game.apply_service_routes(configuration).contains("first stop") and game.train_position == position, "mid-trip directive edit rejected without position change")
	game._save_game()
	game.services.passenger.waypoints = {}
	game._load_game()
	check(game.services.passenger.waypoints["a>b"] == [[12, 11]] and game.train_position == position, "load preserves directives and exact bypass position")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	var malformed: Dictionary = saved.duplicate(true)
	malformed.services.passenger.waypoints = {"a>b": [[12, 40]]}
	check(not game._is_valid_save(malformed), "saved runtime route must satisfy its directives")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.version = 19
	for service in ["passenger", "freight"]: legacy.services[service].erase("waypoints")
	var migration: Dictionary = game.SaveMigrations.migrate(legacy)
	check(migration.ok and migration.data.services.passenger.waypoints.is_empty(), "v19 gets empty directives during migration")
	# Existing waypoint route survives a gap behind until its destination.
	game.tracks.erase(Vector2i(6, 8))
	game._check_route()
	check(game.route_connected, "direction-aware checks apply to waypoint routes")
	var old_scale: float = Settings.ui_scale
	Settings.ui_scale = 2
	game._apply_settings()
	game._open_routes_editor()
	await process_frame
	await process_frame
	check(editor.size.x <= root.get_visible_rect().size.x and editor.size.y <= root.get_visible_rect().size.y, "waypoint editor fits at 200%")
	check(editor.get_ok_button().get_global_rect().end.y <= editor.size.y, "Apply remains accessible at 200%")
	editor.hide()
	Settings.ui_scale = old_scale
	game._apply_settings()
	game.queue_free()
	await process_frame
	print("Waypoint integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
