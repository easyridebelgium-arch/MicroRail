extends SceneTree
const Settings = preload("res://scripts/core/game_settings.gd")
var checks := 0
var failures := 0

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func settle() -> void:
	for frame in range(4): await process_frame

func _run() -> void:
	var existed := FileAccess.file_exists(Settings.SETTINGS_PATH)
	var previous := FileAccess.get_file_as_bytes(Settings.SETTINGS_PATH) if existed else PackedByteArray()
	if existed: DirAccess.remove_absolute(Settings.SETTINGS_PATH)
	Settings.ui_scale = 1.0
	Settings.compact_header = false
	Settings.map_visible = false
	Settings.goals_visible = false
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.paused = true
	game._check_route()
	await settle()
	check(not game.network_map.visible and not game.objective_panel.visible, "fresh preferences keep the starting stations clear of Map and Goals")
	check(game.problem_rows().is_empty(), "unbuilt tutorial routes are objectives, not opening incidents")
	check(not game.notice.contains("stopped") and not game.alert_banner.visible, "fresh tutorial has no stopped-train notice or alert")
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		game._on_viewport_size_changed()
		await settle()
		game._layout_header()
		game._reset_camera()
		if dimensions.x == 1280:
			var row_y := -1.0
			for child in game.header_toolbar.get_children():
				if child is Button and child.visible:
					if row_y < 0: row_y = child.position.y
					check(is_equal_approx(row_y, child.position.y), "all tutorial ribbon buttons fit one row at 1280x720")
			check(game.header_background.size.y < 190, "720p header leaves most of the viewport for the map")
		for station in [game.STATION_A, game.STATION_B, game.STATION_C]:
			var label_position: Vector2 = game.get_global_transform_with_canvas() * (game._cell_center(station) + Vector2(0, -54))
			check(label_position.y > game.header_background.get_global_rect().end.y and game.get_viewport_rect().has_point(label_position), "starting station name is visible below the header")
			var rail_position: Vector2 = game.get_global_transform_with_canvas() * game._cell_center(station)
			check(game.get_viewport_rect().has_point(rail_position), "starting platform remains inside the playable viewport")
	game.network_map.show()
	game.objective_panel.show()
	game._layout_header()
	game._reset_camera()
	for station in [game.STATION_A, game.STATION_B, game.STATION_C]:
		var rail_position: Vector2 = game.get_global_transform_with_canvas() * game._cell_center(station)
		check(rail_position.x > game.objective_panel.get_global_rect().end.x, "Home also keeps starting rails clear when existing panel preferences are open")
	game.network_map.hide()
	game.objective_panel.hide()
	game.drag_start = game.STATION_A
	game.drag_pointer_start = game._cell_center(game.STATION_A)
	game.is_dragging = true
	game._refresh_build_plan(game.STATION_B, true)
	check(game.build_plan.error.is_empty() and game._build_plan_cost() == 150, "first A-B drag costs exactly 15 new tiles / £150")
	game._finish_track_drag(game.STATION_B)
	check(game.route_connected, "first drag connects the existing tutorial passenger service")
	check(game.platform_connection_points().has(game.STATION_A), "tutorial loading tile has a visible connection marker")
	game.scenario_goals.current_index = 2
	check(game.problem_rows().any(func(row: Dictionary) -> bool: return row.id == int(game.Fleet.assigned(game.fleet, "freight").id)), "freight route problems become visible at the freight objective")
	game.tracks.erase(Vector2i(12, 8))
	game._check_route()
	check(game.problem_rows().any(func(row: Dictionary) -> bool: return row.id == 1 and row.title.contains("Route incomplete")), "damaging an established passenger route remains actionable")
	game.queue_free()
	await settle()
	var city = load("res://scenes/main/main.tscn").instantiate()
	city.startup_city_seed = "42"
	root.size = Vector2i(1280, 720)
	root.add_child(city)
	city.set_process(false)
	await settle()
	var row_y := -1.0
	for child in city.header_toolbar.get_children():
		if child is Button and child.visible:
			if row_y < 0: row_y = child.position.y
			check(is_equal_approx(row_y, child.position.y), "city Station tool also fits the single 720p ribbon row")
	check(city._starter_route_pending("freight") == false, "tutorial suppression never applies to sandbox games")
	var candidates: Array = city.CityBuildTool.Generator.planning(city.world.save_state()).station_candidates
	var stop := Vector2i(candidates[0].cell[0], candidates[0].cell[1])
	city.city_builder.submit(stop)
	var ends: Array[Vector2i] = city.platform_connection_points()
	check(ends.has(stop + Vector2i(-2, 0)) and ends.has(stop + Vector2i(2, 0)) and not ends.has(stop), "city platform marks both actual rail ends rather than its middle tile")
	city.drag_start = stop + Vector2i(2, 0)
	city.drag_pointer_start = city._cell_center(city.drag_start)
	city.is_dragging = true
	city._refresh_build_plan(city.drag_start + Vector2i(1, 0), true)
	check(city.build_plan.error.is_empty() and city._build_plan_cost() == 10, "horizontal city-platform extension remains a single £10 tile")
	var illegal: Array[Vector2i] = [stop + Vector2i(0, 1), stop, stop + Vector2i(0, -1)]
	var fixed: Array[Vector2i] = city.CityBuildTool.Construction.platform_cells(stop)
	var bad: Dictionary = city.TrackBuilder.plan(illegal, city.tracks, Vector2i(80, 50), func(_cell: Vector2i) -> bool: return false, fixed)
	check(bad.error.contains("highlighted platform end") and bad.error.contains("left or right"), "a wrong-side platform connection explains exactly where to drag instead")
	city.queue_free()
	await settle()
	if existed:
		var file := FileAccess.open(Settings.SETTINGS_PATH, FileAccess.WRITE)
		file.store_buffer(previous)
		file.close()
	else: DirAccess.remove_absolute(Settings.SETTINGS_PATH)
	print("First session: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
