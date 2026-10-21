extends "res://tests/test_city_scene.gd"
func choose_service(editor: Node, key: String) -> void:
	for index in range(editor.service_choice.item_count):
		if editor.service_choice.get_item_metadata(index) == key:
			editor.service_choice.select(index)
			editor._select_service(index)
			return
func run() -> void:
	game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	game.money = 10000
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	game.inspection_panel.plan_toggle.button_pressed = true
	game.inspection_button.button_pressed = true
	game._draft_passing_loop(Vector2i(8, 8))
	check(game.inspection_panel.loop_routes.disabled, "unbuilt loop cannot open route shortcut")
	game._open_loop_waypoint_routes()
	check(not game.route_editor.visible and not game.construction_plan.is_empty(), "shortcut never applies construction or route automatically")
	check(game._apply_draft() and not game.inspection_panel.loop_routes.disabled, "built layout retains a ready handoff after fit snapshot clears")
	game._undo_construction()
	game._update_loop_waypoint_controls()
	check(game.inspection_panel.loop_routes.disabled, "undo invalidates shortcut against missing track")
	game._redo_construction()
	game._update_loop_waypoint_controls()
	check(not game.inspection_panel.loop_routes.disabled, "redo restores valid built-layout handoff")
	var purchase: Dictionary = game.buy_fleet_train("passenger_standard")
	check(purchase.ok and game.start_passenger_service(purchase.id, "b").contains("started"), "second service available for explicit selection")
	var key: String = game.Fleet.find(game.fleet, purchase.id).service
	var live: Dictionary = game.services.duplicate(true)
	var position: Vector2 = game.train_position
	var other_position: Vector2 = game.passenger_services[key].position
	var cash: int = game.money
	game.inspection_panel.use_loop_waypoint.emit()
	var editor: Node = game.route_editor
	check(editor.visible and game.paused and editor.waypoint_x.value == 12 and editor.waypoint_y.value == 11, "shortcut opens paused Routes with correct loop coordinates")
	check(editor.waypoint_hint.visible and editor.waypoint_hint.text.contains("Nothing has been added automatically"), "persistent hint explains select/add/review workflow")
	var initial_draft: Dictionary = editor.draft.duplicate(true)
	check(game.services == live and editor.draft[key].waypoints == live[key].waypoints and editor.draft.passenger.waypoints == live.passenger.waypoints, "opening handoff neither edits route nor inserts a draft waypoint")
	choose_service(editor, key)
	check(editor.waypoint_hint.visible and editor.waypoint_x.value == 12 and editor.waypoint_y.value == 11, "coordinates and hint survive selecting another service")
	editor._add_waypoint()
	check(editor.draft[key].waypoints["b>a"] == [[12, 11]] and editor.draft.passenger.waypoints.is_empty() and game.services == live, "Add changes only chosen service and leg in draft")
	editor._add_waypoint()
	check(editor.draft[key].waypoints["b>a"].size() == 1, "existing duplicate guard still applies")
	var draft: Dictionary = editor.draft.duplicate(true)
	game._open_loop_waypoint_routes()
	check(editor.draft == draft, "repeated shortcut cannot overwrite an open unsaved route draft")
	editor.hide()
	game._open_loop_waypoint_routes()
	check(editor.draft == initial_draft and editor.waypoint_list.item_count == 0, "closing discards waypoint edit and reopening starts from live services")
	choose_service(editor, key)
	editor._add_waypoint()
	editor._apply()
	check(editor.status.text.begins_with("Routes applied") and game.services[key].waypoints["b>a"] == [[12, 11]], "explicit Apply commits validated chosen route")
	check(game.services.passenger.waypoints.is_empty() and game.money == cash and game.train_position == position and game.passenger_services[key].position == other_position, "handoff does not edit other services, spend or teleport")
	editor.hide()
	for tick in range(240):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
		if game.passenger_services[key].distance > 32: break
	game.paused = true
	check(game.passenger_services[key].distance > 32, "chosen service has actually left its first stop for running-edit test")
	var moving_position: Vector2 = game.passenger_services[key].position
	var running_routes: Dictionary = game.services.duplicate(true)
	game._open_loop_waypoint_routes()
	choose_service(editor, key)
	editor.waypoint_x.value = 10
	editor.waypoint_y.value = 11
	editor._add_waypoint()
	editor._apply()
	check(editor.status.text.contains("empty train at its first stop") and game.services == running_routes and game.passenger_services[key].position == moving_position, "handoff keeps normal first-stop edit restrictions and cannot move a running train")
	editor.hide()
	game._open_routes_editor()
	check(not editor.waypoint_hint.visible, "ordinary Routes does not retain old loop hint")
	editor.hide()
	game._draft_passing_loop(Vector2i(8, 8))
	game.construction_plan.stage({Vector2i(40, 12): false}, game.tracks)
	game._update_loop_waypoint_controls()
	check(game.inspection_panel.loop_routes.disabled, "unrelated pending construction must be resolved before handoff")
	game._discard_draft()
	game._draft_passing_loop(Vector2i(8, 8))
	game._open_loop_waypoint_routes()
	check(editor.visible, "identical already-built template permits no-cost handoff without Apply")
	editor.hide()
	check(game._save_game(2) and game._load_slot(2) and game.passing_loop_handoff.is_empty() and game.passing_loop_preview.is_empty(), "load clears temporary handoff while retaining applied route")
	check(game.services[key].waypoints["b>a"] == [[12, 11]], "ordinary saved waypoint persists independently of shortcut")
	game.queue_free()
	await process_frame
	print("Loop waypoint handoff: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
