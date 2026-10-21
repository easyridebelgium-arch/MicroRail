extends SceneTree
const Events = preload("res://scripts/core/event_log.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	_run.call_deferred()
func buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child in node.get_children():
		if child is Button: result.append(child)
		result.append_array(buttons(child))
	return result
func _run() -> void:
	var snapshots: Array = []
	for fps in [30, 60, 120]:
		var game = load("res://scenes/main/main.tscn").instantiate()
		root.add_child(game)
		await process_frame
		game.set_process(false)
		game.paused = true
		for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
		for x in range(8, 29): game.tracks[Vector2i(x, 24)] = false
		game._check_route()
		game.route_distance = 96
		game.passengers_on_train = 4
		game.train_needs_boarding = false
		game._update_train_transform()
		game._use_signal_tool(Vector2i(10, 8))
		check(game.track_signals.get(Vector2i(10, 8)) == "auto", "first tool click creates automatic signal")
		game._use_signal_tool(Vector2i(10, 8))
		check(game.track_signals.get(Vector2i(10, 8)) == "stop", "second click sets manual stop")
		game._use_signal_tool(game.STATION_A)
		check(not game.track_signals.has(game.STATION_A), "platform signal placement rejected")
		game.paused = false
		game.sim_clock.reset()
		game.event_log.clear()
		game.passenger_timer = 0.0
		game.log_production_timer = 0.0
		game.operating_timer = 0.0
		game.money = 5000
		for frame in range(fps * 4):
			for step in game.sim_clock.advance(1.0 / fps):
				game.sim_clock.begin_tick()
				game._simulation_step(1.0 / 60.0)
		check(game.route_distance > 96 and game.route_distance < 192, "train approaches and stops before signal")
		check(game._passenger_service_status().contains("Manual stop signal"), "waiting reason explains manual stop")
		check(game.event_log.query(Events.TRAIN_WAITING).size() == 1, "signal wait logged once")
		snapshots.append([game.route_distance, game.money, game.sim_clock.tick, game.event_log.save_state()])
		game._open_traffic_dialog()
		await process_frame
		var position: Vector2 = game.train_position
		for button in buttons(game.traffic_dialog):
			if button.text == "Hold selected train": button.pressed.emit()
		check(game.passenger_held and game.train_position == position, "actual Hold button preserves position")
		game._save_game()
		game.passenger_held = false
		game.track_signals.clear()
		game._load_game()
		check(game.passenger_held and game.track_signals.get(Vector2i(10, 8)) == "stop" and game.train_position == position, "save restores dispatcher hold and signal mode")
		for button in buttons(game.traffic_dialog):
			if button.text == "Resume selected train": button.pressed.emit()
		check(not game.passenger_held and game.passenger_service_enabled, "actual Resume button releases selected train")
		game.traffic_dialog.hide()
		game._use_signal_tool(Vector2i(10, 8))
		check(game.track_signals.get(Vector2i(10, 8)) == "oneway_2", "third click creates eastbound signal")
		game._use_signal_tool(Vector2i(10, 8))
		check(game.track_signals.get(Vector2i(10, 8)) == "oneway_6", "fourth click creates westbound signal")
		game._use_signal_tool(Vector2i(10, 8))
		check(not game.track_signals.has(Vector2i(10, 8)), "fifth click removes signal")
		game.paused = false
		for step in range(120):
			game.sim_clock.begin_tick()
			game._simulation_step(1.0 / 60.0)
		check(game.train_position != position, "released train resumes after manual stop removed")
		game.paused = true
		game._use_signal_tool(Vector2i(14, 8))
		game._save_game()
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
		var malformed: Dictionary = saved.duplicate(true)
		malformed.signals.append([14, 8, "auto"])
		check(not game._is_valid_save(malformed), "duplicate signal entries rejected")
		malformed = saved.duplicate(true)
		malformed.runtime.passenger_cells[1] = [70, 40]
		check(not game._is_valid_save(malformed), "noncontiguous retained path rejected")
		var legacy: Dictionary = saved.duplicate(true)
		legacy.version = 18
		legacy.erase("signals")
		legacy.erase("runtime")
		var migration: Dictionary = game.SaveMigrations.migrate(legacy)
		check(migration.ok and game._is_valid_save(migration.data), "v18 migrates with empty signal and runtime defaults")
		game.queue_free()
		await process_frame
	check(snapshots[0] == snapshots[1] and snapshots[1] == snapshots[2], "signal positions, money and events match at 30/60/120 FPS")
	print("Signal integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
