extends SceneTree
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
func _run() -> void:
	# Use a desktop window size; headless defaults to 64x64.
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.paused = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
	for x in range(8, 29): game.tracks[Vector2i(x, 24)] = false
	game._check_route()
	check(game.train_diagnostics(1).blocks.is_empty(), "an unsignalled network must not present graph components as signal authority")
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	game.route_distance = 96
	game.train_needs_boarding = false
	game._update_train_transform()
	game._use_signal_tool(Vector2i(10, 8))
	game._use_signal_tool(Vector2i(10, 8))
	for step in range(160): tick(game)
	var snapshot: Dictionary = game.train_diagnostics(1)
	check(snapshot.state == "Traffic wait" and snapshot.wait_seconds > 0.0, "manual stop must show a measured traffic wait")
	check(snapshot.advice.contains("manual stop") and not snapshot.advice.contains("passing loop"), "manual stop recommendation must match the cause")
	check(snapshot.blocker == -1 and snapshot.cell == Vector2i(10, 8), "manual stop must locate the signal without inventing a blocking train")
	game.inspect_train(1)
	check(game.train_inspector.authority.text.contains("Dispatch request position") and game.train_inspector.authority.text.contains("First choice rotates"), "inspector exposes the actual dispatch order alongside authority")
	game.route_distance = 160.3
	game._update_train_transform()
	tick(game)
	var approach: Dictionary = game.train_diagnostics(1)
	check(approach.state == "Approaching restriction" and approach.cell == Vector2i(10, 8) and approach.advice.contains("manual stop"), "a partial movement must explain the approaching signal without accruing stopped time")
	tick(game)
	snapshot = game.train_diagnostics(1)
	var grants: Dictionary = game.reservations.owners.duplicate()
	var events: Dictionary = game.event_log.save_state()
	var tick_before: int = game.sim_clock.tick
	var money_before: int = game.money
	var position_before: Vector2 = game.train_position
	game.paused = false
	check(game.inspect_train(1) and game.paused and game._management_window_is_open(), "inspector must open paused and suppress gameplay input")
	check(game.reservations.owners == grants and game.event_log.save_state() == events and game.sim_clock.tick == tick_before and game.money == money_before and game.train_position == position_before, "inspection must preserve allocation, events, ticks, money and physical position")
	check(game.train_inspector.authority.text.contains("Physical body now") and game.train_inspector.authority.text.contains("Last allocation") and game.train_inspector.authority.text.contains("Attempted tile requests"), "occupancy and requests/grants must be explained separately")
	check(game.train_inspector.buttons.blocker.disabled and not game.train_inspector.buttons.conflict.disabled, "manual stop navigation must enable only meaningful targets")
	game.train_inspector_action("conflict", snapshot)
	check(game.camera.position == game._cell_center(Vector2i(10, 8)) and not game.train_inspector.visible, "locate conflict must jump to the actual signal")
	game.inspect_train(1)
	game.train_inspector_action("route", snapshot)
	check(game.inspection_panel.routes and game.inspection_panel.blocks and game.inspection_panel.block_toggle.button_pressed and game.reservation_button.button_pressed, "show authority must synchronize all overlay controls")
	game.inspect_train(1)
	game.train_inspector_action("traffic", snapshot)
	check(int(game.traffic_dialog.train_choice.get_selected_metadata()) == 1, "Traffic navigation must select the inspected permanent train ID")
	game.traffic_dialog.hide()
	game.passenger_held = true
	check(game.train_diagnostics(1).state == "Dispatcher hold", "intentional hold must take precedence over a previous traffic wait")
	game.passenger_held = false
	game.route_connected = false
	check(game.train_diagnostics(1).state == "Route incomplete", "incomplete routes must not appear as signal congestion")
	game.tracks.erase(Vector2i(15, 8))
	var broken: Dictionary = game.train_diagnostics(1)
	check(broken.reason.contains("Track missing") and broken.cell == Vector2i(15, 8), "incomplete route diagnostics must locate the missing track ahead")
	game.tracks[Vector2i(15, 8)] = false
	game.route_connected = true
	game.wait_remaining = 1
	check(game.train_diagnostics(1).state == "Station dwell", "station dwell must be classified separately")
	game.wait_remaining = 0
	var freight: Dictionary = game.train_diagnostics(2)
	check(freight.state == "Loading" and freight.advice.contains("departure rule") and freight.wait_seconds == 0.0, "freight waiting for cargo must explain loading rather than traffic")
	game.fleet.trains.append(game.Fleet.make_train(3, "passenger_standard"))
	game.fleet.next_id = 4
	check(game.train_diagnostics(3).state == "Stored" and game.train_diagnostics(3).occupied.is_empty(), "stored vehicles must have no physical occupancy")
	game.inspect_train(3)
	check(game.train_inspector.buttons.route.disabled and game.train_inspector.buttons.traffic.disabled, "stored vehicle navigation must not claim a route or traffic position")
	game.train_inspector.hide()
	game.wait_remaining = 0
	game._open_problems()
	game.problems_dialog.source.select(0)
	game.problems_dialog.refresh()
	game.problems_dialog._inspect()
	check(game.train_inspector.visible and not game.problems_dialog.visible and game.train_inspector.selected_id == 1, "Problems must open current train inspection")
	game.train_inspector.hide()
	game.object_browser.open_dialog()
	game.object_browser.search.text = "#3"
	game.object_browser.refresh()
	game.object_browser.inspect()
	check(game.train_inspector.visible and game.train_inspector.selected_id == 3, "Find must inspect even a stored train")
	game.train_inspector.hide()
	check(game._inspect_train_at(Vector2i((game.train_position / game.TILE_SIZE).floor())) and game.train_inspector.selected_id == 1, "map inspection must hit the current physical train footprint")
	var Settings = game.GameSettings
	Settings.ui_scale = 2.0
	game._apply_settings()
	game.train_inspector.open_train(1)
	await process_frame
	await process_frame
	check(float(game.train_inspector.size.y) <= game.get_viewport_rect().size.y + 1.0, "inspector must fit the logical viewport at 200% scale")
	check(Rect2(Vector2.ZERO, Vector2(game.train_inspector.size)).encloses(game.train_inspector.get_ok_button().get_global_rect()), "Close must remain accessible at 200% scale")
	game.train_inspector.hide()
	Settings.ui_scale = 1.0
	game._apply_settings()
	# An upcoming automatic block request is authority, not physical occupancy.
	game.track_signals[Vector2i(10, 8)] = "auto"
	game.route_distance = 100
	game._update_train_transform()
	game._rebuild_reservations(true)
	var auto: Dictionary = game.train_diagnostics(1)
	check(auto.state == "Awaiting movement sample" and auto.advice.contains("previous waiting cause"), "a paused allocation change must not misrepresent an old manual stop as a current cause")
	var found := false
	for block in auto.blocks:
		if block.requested and block.authorities.has(1) and block.occupants.is_empty(): found = true
	check(found, "a granted downstream block must remain distinguishable from occupied space")
	game.freight_train.route_cells = game.route_cells.duplicate()
	game.freight_train.route_path = game.route_path
	game.freight_train.distance_along_route = 400.0
	game.freight_train.held = true
	game.freight_train._update_transform()
	for step in range(160): tick(game)
	var blocked: Dictionary = game.train_diagnostics(1)
	check(blocked.state == "Traffic wait" and blocked.blocker == 2 and blocked.reason.contains("block B"), "actual block refusal must identify the blocking permanent train and block")
	check(blocked.advice.contains("automatic signals") and not blocked.advice.contains("manual stop"), "automatic block advice must differ from manual signal advice")
	game.inspect_train(1)
	check(game.train_inspector.authority.text.contains("#2 Log Hauler 2 / Timber Service") and not game.train_inspector.buttons.blocker.disabled, "inspector must show blocker name/service and offer navigation")
	game.train_inspector_action("blocker", blocked)
	check(game.camera.position == game.freight_train.position, "blocker navigation must follow its actual current position")
	game.deadlocks.cycles = [[1, 2]]
	check(game.train_diagnostics(1).cycle == [1, 2] and game.train_diagnostics(1).state == "Confirmed deadlock", "deadlock diagnosis must name the full involved cycle")
	game.deadlocks.reset()
	game.queue_free()
	await process_frame
	print("Train inspector: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
