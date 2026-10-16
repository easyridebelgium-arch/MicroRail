extends SceneTree
const Geometry = preload("res://scripts/track_geometry.gd")
const Services = preload("res://scripts/service_routes.gd")
const Runtime = preload("res://scripts/core/runtime_routes.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	# Pure rules first.
	check(Services.stop_cell({}, "b") == Vector2i(20, 8), "platform 1 is the station tile")
	check(Services.stop_cell({"b": 2}, "b") == Vector2i(20, 9) and Services.stop_cell({"b": 3}, "b") == Vector2i(20, 7), "platforms 2 and 3 are the rows below and above")
	check(Services.is_stop_cell(Vector2i(20, 9)) and not Services.is_stop_cell(Vector2i(20, 10)), "only platform stop tiles count")
	var base := Services.defaults()
	base.passenger["platforms"] = {"b": 2}
	check(Services.is_valid(base), "a platform choice for an included stop is valid")
	base.passenger["platforms"] = {"c": 2}
	check(not Services.is_valid(base), "a platform for a stop that is not on the route is rejected")
	base.passenger["platforms"] = {"b": 4}
	check(not Services.is_valid(base), "an unknown platform number is rejected")
	base.passenger["platforms"] = {"b": 1.5}
	check(not Services.is_valid(base), "a fractional platform number is rejected")
	base.passenger["platforms"] = {"b": 2.0}
	check(Services.from_save(base).passenger.platforms["b"] == 2 and typeof(Services.from_save(base).passenger.platforms["b"]) == TYPE_INT, "JSON numbers load as integers")
	check(Services.from_save(Services.defaults()).passenger.platforms == {}, "services without the field gain an empty choice")

	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	for x in range(4, 22): game.tracks[Vector2i(x, 8)] = false
	# Siding beside station B, branching off the main line at 15,8.
	game.tracks[Vector2i(15, 8)] = "junction_6_2_3"
	game.tracks[Vector2i(16, 9)] = Geometry.from_ports(Vector2i(-1, -1), Vector2i(1, 0))
	for x in range(17, 21): game.tracks[Vector2i(x, 9)] = false
	game._check_route()
	check(game.route_connected and game.route_cells.back() == Vector2i(20, 8), "the default route still ends on the station tile")
	var configuration: Dictionary = game.services.duplicate(true)
	configuration.passenger["platforms"] = {"b": 2}
	var message: String = game.apply_service_routes(configuration)
	check(message.begins_with("Routes applied") and game.route_connected, "a siding platform route applies: " + message)
	check(game.route_cells.back() == Vector2i(20, 9) and game.route_cells.has(Vector2i(16, 9)), "the route now ends on the siding via its switch")
	check(game.services.passenger.platforms == {"b": 2}, "the choice is stored with the service")
	var first: Dictionary = game.services.duplicate(true)
	first.passenger["platforms"] = {"a": 2, "b": 2}
	check(game.apply_service_routes(first).begins_with("The first stop's platform"), "the first stop's platform cannot change under the train")
	var bad: Dictionary = game.services.duplicate(true)
	bad.passenger["platforms"] = {"b": 4}
	check(game.apply_service_routes(bad).begins_with("Use a name"), "an invalid platform is refused")
	# Save and load keep the choice and the physical route.
	game._save_game()
	game._load_game()
	check(game.services.passenger.platforms == {"b": 2} and game.route_cells.back() == Vector2i(20, 9), "load preserves the platform and route")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	var tampered: Dictionary = saved.duplicate(true)
	tampered.services.passenger["platforms"] = {"b": 1}
	check(not game._is_valid_save(tampered), "a saved route that ends on the wrong platform is rejected")
	# The train really drives to the siding and loads there.
	game.paused = false
	var arrived := false
	for step in range(60 * 40):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
		if game.train_position.distance_to(game._cell_center(Vector2i(20, 9))) < 1.0:
			arrived = true
			break
	check(arrived, "the train reaches the siding platform")
	game.paused = true
	# A missing siding refuses the edit and keeps the old route.
	game.tracks.erase(Vector2i(18, 9))
	var before: Array = game.route_cells.duplicate()
	var broken: Dictionary = game.services.duplicate(true)
	broken.passenger["platforms"] = {"b": 3}
	check(not game.apply_service_routes(broken).begins_with("Routes applied"), "a missing platform track is refused")
	check(game.route_cells == before and game.services.passenger.platforms == {"b": 2}, "a refused edit changes nothing")
	# The Routes editor offers the choice per selected stop.
	var editor = game.route_editor
	editor.open_editor()
	await process_frame
	check(editor.platform_choice.disabled, "no stop selected, no platform choice")
	editor.stop_list.select(1)
	editor._show_platform(1)
	check(not editor.platform_choice.disabled and editor.platform_choice.selected == 1, "the selected stop shows its stored platform")
	editor.platform_choice.select(0)
	editor._select_platform(0)
	check(not editor.draft.passenger.platforms.has("b") and not editor.stop_list.get_item_text(1).contains("platform"), "choosing platform 1 clears the override")
	editor.platform_choice.select(2)
	editor._select_platform(2)
	check(editor.draft.passenger.platforms == {"b": 3} and editor.stop_list.get_item_text(1).contains("platform 3"), "the draft and list show platform 3")
	editor.station_choice.select(2)
	editor._add_stop()
	editor.stop_list.select(2)
	editor._show_platform(2)
	editor.platform_choice.select(1)
	editor._select_platform(1)
	check(editor.draft.passenger.platforms == {"b": 3, "c": 2}, "each stop keeps its own platform")
	editor.stop_list.select(2)
	editor._remove_stop()
	check(editor.draft.passenger.stops.size() == 2 and editor.draft.passenger.platforms == {"b": 3}, "removing a stop drops its platform choice")
	editor.hide()
	print("Platform routes: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
