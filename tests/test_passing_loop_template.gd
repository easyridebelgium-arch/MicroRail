extends "res://tests/test_city_scene.gd"
const Template = preload("res://scripts/core/passing_loop_template.gd")
const Blueprints = preload("res://scripts/core/track_blueprints.gd")
func run() -> void:
	check(Blueprints.valid(Template.design()), "template is valid exportable blueprint geometry")
	game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	game.money = 10000
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	check(not game._draft_passing_loop(Vector2i(8, 8)), "helper cannot bypass draft mode")
	game.inspection_panel.plan_toggle.button_pressed = true
	game.inspection_panel.place_passing_loop.emit()
	check(game.corridor_pick == 6 and game.paused, "UI arms placement while paused")
	var balance: int = game.money
	game._pick_corridor_cell(Vector2i(8, 8))
	check(game.corridor_pick == 0 and not game.tracks.has(Vector2i(12, 11)) and game.money == balance, "map click stages preview without purchase or live edit")
	check(game.inspection_panel.blueprint_status.text.contains("12,11") and game.inspection_panel.blueprint_status.text.contains("whole train"), "guidance gives exact loop waypoint and fit limitation")
	check(game.construction_plan.quote().net == 330, "matching mainline reused; 13 new rails and two switch upgrades priced normally")
	var draft: Dictionary = game.construction_plan.changes.duplicate()
	check(not game._draft_passing_loop(Vector2i(76, 48)) and game.construction_plan.changes == draft, "out of bounds placement leaves previous draft intact")
	check(not game._draft_passing_loop(game.STATION_A) and game.construction_plan.changes == draft, "protected platform refuses without partial edits")
	game.tracks[Vector2i(45, 18)] = true
	check(not game._draft_passing_loop(Vector2i(45, 18)) and game.construction_plan.changes == draft, "incompatible vertical track is not silently replaced")
	check(game._apply_draft() and game.money == balance - 330 and game.track_signals.size() == 4, "apply atomically buys geometry and four automatic signals")
	game._undo_construction()
	check(game.money == balance and not game.tracks.has(Vector2i(12, 11)) and game.track_signals.is_empty(), "single undo restores previous mainline and balance")
	game._redo_construction()
	check(game.track_signals.size() == 4 and game.tracks.has(Vector2i(12, 11)), "single redo restores full template")
	var direct: Array = game.WaypointRouter.find_route(game.tracks, game.STATION_A, game.STATION_B, [])
	var detour: Array = game.WaypointRouter.find_route(game.tracks, game.STATION_B, game.STATION_A, [[12, 11]])
	check(not direct.is_empty() and not direct.has(Vector2i(12, 11)) and detour.has(Vector2i(12, 11)), "authoritative graph supports both through and waypoint loop routes")
	check(game._draft_passing_loop(Vector2i(8, 8)) and game.construction_plan.is_empty(), "restamping matching template has no duplicate cost")
	var purchase: Dictionary = game.buy_fleet_train("passenger_standard")
	check(purchase.ok and game.start_passenger_service(purchase.id, "b").contains("started"), "opposing service starts at B")
	var key: String = game.Fleet.find(game.fleet, purchase.id).service
	var configuration: Dictionary = game.services.duplicate(true)
	configuration[key].waypoints = {"b>a": [[12, 11]]}
	check(game.apply_service_routes(configuration).begins_with("Routes applied"), "normal route editor accepts suggested waypoint")
	game.inspection_panel.plan_toggle.button_pressed = false
	var overlap := false
	var used_loop := false
	for tick in range(12000):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
		if tick % 30 == 0:
			used_loop = used_loop or game.passenger_services[key].position.y > game._cell_center(Vector2i(12, 10)).y
			var seen: Dictionary = {}
			for train in game.reservation_trains.values():
				for cell in game.reservations.footprint(train.path, train.distance, 32, train.length):
					if seen.has(cell) and seen[cell] != train.id: overlap = true
					seen[cell] = train.id
	check(not overlap and game.deadlocks.cycles.is_empty(), "two opposing trains safely use template without body overlap or deadlock")
	check(game.passengers_delivered > 40 and used_loop, "both services keep delivering through generated loop")
	check(game._save_game(2) and game._load_slot(2) and game.track_signals.size() == 4, "applied loop and service waypoint survive save/load")
	game.queue_free()
	await process_frame
	print("Passing loop template: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
