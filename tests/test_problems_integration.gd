extends SceneTree
const Events = preload("res://scripts/core/event_log.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
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
	var results: Array = []
	for fps in [30, 60, 120]:
		var game = load("res://scenes/main/main.tscn").instantiate()
		game.paused = true
		root.add_child(game)
		await process_frame
		game.set_process(false)
		for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
		for x in range(8, 29): game.tracks[Vector2i(x, 24)] = false
		game._check_route()
		game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
		game.route_distance = 96
		game.train_needs_boarding = false
		game.passengers_on_train = 4
		game._update_train_transform()
		game._use_signal_tool(Vector2i(10, 8))
		game._use_signal_tool(Vector2i(10, 8))
		for frame in range(fps * 4):
			for step in game.sim_clock.advance(1.0 / fps): tick(game)
		var stats: Dictionary = game.traffic_metrics.statistics(1)
		check(stats.continuous_seconds > 0.0 and stats.total_seconds < 4.0, "count only stopped time after approaching the signal")
		check(game.traffic_metrics.statistics(2).total_seconds == 0.0, "waiting for freight loading must not count as traffic congestion")
		results.append([game.route_distance, stats, game.traffic_metrics.window_cells.duplicate()])
		var problems: Array = game.problem_rows()
		check(problems.size() == 1 and problems[0].details.contains("Manual stop signal"), "current problems must explain the actual signal wait")
		game.inspection_panel.show()
		game.inspection_panel.congestion = true
		game.hovered_cell = game.traffic_metrics.records[1].cell
		game._update_inspection()
		game.queue_redraw()
		await process_frame
		check(game.inspection_panel.summary.text.contains("train-seconds"), "waiting overlay must expose measured conflict-cell data")
		var history: Array = game.incident_rows()
		check(history.size() == 1 and history[0].details.contains("Historical incident"), "deduplicated wait event must appear as history")
		game._open_problems()
		await process_frame
		var dialog = game.problems_dialog
		check(game.paused and game._management_window_is_open(), "problem browsing must pause and prevent map-building shortcuts")
		dialog.search.text = "manual stop"
		dialog.refresh()
		check(dialog.items.item_count == 1, "search must match waiting reason")
		game.rename_fleet_train(1, "Red Comet")
		dialog.search.text = "red comet"
		dialog.refresh()
		check(dialog.items.item_count == 1, "search must also match custom train names")
		dialog.search.text = "no such train"
		dialog.refresh()
		check(dialog.items.item_count == 0 and dialog.get_ok_button().disabled, "empty search must disable jump")
		dialog.search.text = "#1"
		dialog.severity.select(1)
		dialog.refresh()
		check(dialog.items.item_count == 0, "urgent filter must exclude an ordinary signal wait")
		dialog.severity.select(2)
		dialog.refresh()
		check(dialog.items.item_count == 1, "warning filter must retain the signal wait")
		var position: Vector2 = game.train_position
		dialog.confirmed.emit()
		check(not dialog.visible and game.camera.position == position and game.paused, "locate centers the active train, closes browsing and leaves pause unchanged")
		game._open_problems()
		dialog.search.text = ""
		dialog.source.select(1)
		dialog.severity.select(0)
		dialog.refresh()
		check(dialog.items.item_count == 1 and dialog.details.text.contains("Historical"), "historical view must be explicitly separate from active problems")
		dialog.hide()
		var ticks_before: int = game.traffic_metrics.records[1].total_ticks
		game.passenger_held = true
		for step in range(60): tick(game)
		check(game.traffic_metrics.records[1].total_ticks == ticks_before and game.traffic_metrics.statistics(1).continuous_seconds == 0, "dispatcher hold must not inflate measured traffic waiting")
		check(game.problem_rows()[0].severity == "Info", "intentional hold should be informational")
		game._save_game()
		game._load_game()
		check(game.traffic_metrics.records.is_empty(), "load must start a new diagnostic measurement window")
		check(not game.incident_rows().is_empty(), "existing saved event history must survive loading")
		game.passenger_held = false
		game._use_signal_tool(Vector2i(10, 8))
		for step in range(120): tick(game)
		check(game.problem_rows().is_empty(), "clearing the signal should remove current wait problems")
		check(not game.incident_rows().is_empty(), "cleared problems must remain in historical events")
		game.money = 10000
		var purchase: Dictionary = game.buy_fleet_train("passenger_standard")
		game.start_passenger_service(purchase.id, "b")
		var extra_key: String = "passenger_%d" % purchase.id
		check(game.passenger_services.has(extra_key), "extra-service diagnostic fixture must start at clear B platform")
		if game.passenger_services.has(extra_key):
			game.passenger_services[extra_key].held = true
			var extra_rows: Array = game.problem_rows().filter(func(row: Dictionary) -> bool: return row.id == purchase.id)
			check(extra_rows.size() == 1 and extra_rows[0].severity == "Info", "independent trains must have their own held problem and permanent ID")
			game.locate_problem(extra_rows[0])
			check(game.camera.position == game.passenger_services[extra_key].position, "locate must follow an independent service's actual position")
			game.passenger_services[extra_key].enabled = false
			game.remove_passenger_service(purchase.id)
			check(game.problem_rows().filter(func(row: Dictionary) -> bool: return row.id == purchase.id).is_empty(), "removed services must disappear from current problems")
		game.tracks.erase(Vector2i(18, 8))
		game._check_route()
		check(game.problem_rows()[0].title.contains("Route incomplete"), "broken track ahead must appear as a separate actionable problem")
		check(not game.can_locate_problem({"id": 9999, "cell": Vector2i(-1, -1)}), "removed historical train with no location cannot be located")
		check(game.locate_problem({"id": 9999, "cell": Vector2i(10, 8)}) and game.camera.position == game._cell_center(Vector2i(10, 8)), "historical location should remain useful after a train is removed")
		if fps == 30:
			var old_scale: float = Settings.ui_scale
			for scale in [1.0, 2.0]:
				Settings.ui_scale = scale
				game._apply_settings()
				game._open_problems()
				await process_frame
				await process_frame
				check(dialog.size.y <= game.get_viewport_rect().size.y + 1, "problems dialog must fit height at %d%% scale" % (scale * 100))
				dialog.hide()
			Settings.ui_scale = old_scale
			game._apply_settings()
		game.queue_free()
		await process_frame
	check(results[0] == results[1] and results[1] == results[2], "measured waiting and location totals must match at 30, 60 and 120 FPS")
	var blocked = load("res://scenes/main/main.tscn").instantiate()
	blocked.paused = true
	root.add_child(blocked)
	await process_frame
	blocked.set_process(false)
	for x in range(4, 21): blocked.tracks[Vector2i(x, 8)] = false
	blocked._check_route()
	blocked.money = 10000
	blocked.scenario_goals.current_index = blocked.ScenarioGoals.OBJECTIVES.size()
	var opposing: Dictionary = blocked.buy_fleet_train("passenger_standard")
	blocked.start_passenger_service(opposing.id, "b")
	blocked.train_needs_boarding = false
	blocked.passengers_on_train = 4
	var opposing_key: String = "passenger_%d" % opposing.id
	blocked.passenger_services[opposing_key].boarding = false
	blocked.passenger_services[opposing_key].passengers = 4
	for step in range(600): tick(blocked)
	check(not blocked.deadlocks.cycles.is_empty(), "opposing passenger trains must create a real confirmed deadlock fixture")
	var urgent: Array = blocked.problem_rows().filter(func(row: Dictionary) -> bool: return row.severity == "Urgent")
	check(urgent.size() == 2 and urgent[0].details.contains("signal boundaries"), "confirmed deadlock problems must be urgent and explain layout recovery")
	blocked.queue_free()
	await process_frame
	print("Problems integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
