extends "res://tests/test_platform_reroute.gd"
func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.money = 100000
	layout(game)
	game._check_route()
	game.paused = true
	var configuration: Dictionary = game.services.duplicate(true)
	configuration.passenger.platforms = {"b": 0}
	check(game.apply_service_routes(configuration).begins_with("Routes applied"), "Auto route applies")
	var bought: Dictionary = game.buy_fleet_train("passenger_standard")
	check(game.start_passenger_service(bought.id, "b").contains("started"), "blocker stands at destination")
	game.passenger_services[game.Fleet.find(game.fleet, bought.id).service].held = true
	game.route_distance = 64.0
	game.wait_remaining = 0.0
	game.train_needs_boarding = false
	game._update_train_transform()
	var position: Vector2 = game.train_position
	var before: Dictionary = game.seeded_challenge.save_state()
	game._rebuild_reservations()
	game.paused = false
	game.section_claims[1] = {"corridor": {Vector2i(10, 8): Vector2i.RIGHT}, "target": game.stop_distances[1]}
	game._maybe_reroute_platform("passenger")
	check(game.services.passenger.platforms.get("b", 1) == 1, "a committed single-track section keeps its platform until arrival")
	game.section_claims.clear()
	game._maybe_reroute_platform("passenger")
	check(game.services.passenger.platforms.get("b", 1) == 2, "approaching train chooses free siding")
	check(game.route_distance == 64.0 and game.route_path.sample_baked(game.route_distance).distance_to(position) < 0.001, "route replacement preserves physical position and travelled distance")
	check(game.seeded_challenge.save_state() == before, "platform choice grants no scenario progress")
	game.paused = true
	check(game._save_game(4) and game._load_slot(4), "approach-time platform route survives save/load")
	game._execute_set_signal({"x": 5, "y": 8, "mode": "oneway_2"})
	var retained_position: Vector2 = game.train_position
	check(game.reverse_train_reason(1).contains("one-way signal"), "reverse preflight identifies opposing one-way signal")
	check(game.reverse_train(1).contains("one-way signal") and game.train_position == retained_position and not game.passenger_returning, "refused reversal changes no physical state")
	check(game._save_game(4) and game._load_slot(4) and game.track_signals.get(Vector2i(5, 8)) == "oneway_2", "directional signal mode survives schema54 roundtrip")
	var path: Curve2D = game.route_path
	check(game.Platforms.safe_rebase(path, path, game.route_distance, 0, 0, 140, true, 96), "unchanged route preserves long body and authority")
	var shifted := Curve2D.new()
	shifted.add_point(Vector2.ZERO)
	shifted.add_point(Vector2(400, 400))
	check(not game.Platforms.safe_rebase(path, shifted, game.route_distance, 0, 0, 140, true, 96), "divergence under body or lookahead refuses rebase")
	var old_scale: float = game.GameSettings.ui_scale
	game.GameSettings.ui_scale = 2.0
	game._apply_settings()
	game.route_editor.open_editor()
	for frame in range(4): await process_frame
	check(game.route_editor.size.x <= root.get_visible_rect().size.x and game.route_editor.size.y <= root.get_visible_rect().size.y, "routing controls fit at 200 percent UI scale")
	game.route_editor.independent_return.pressed.emit()
	check(game.route_editor.draft.passenger.mode == "loop" and game.services.passenger.mode == "shuttle" and game.route_editor.waypoint_leg.get_selected_metadata() == "b>a", "independent-return shortcut edits only the closing-leg draft")
	game.route_editor.hide()
	game.GameSettings.ui_scale = old_scale
	game._apply_settings()
	game.queue_free()
	await process_frame
	print("Platform arrival: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
