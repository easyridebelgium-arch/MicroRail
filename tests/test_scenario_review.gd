extends "res://tests/test_city_scene.gd"
const Review = preload("res://scripts/core/scenario_review.gd")
func run() -> void:
	var values := {"delivered": 45, "fares": 225, "freight": 80, "running": 100, "cash": 1200}
	var snapshot := Review.capture(values, 40, 2)
	values.cash = 9999
	check(snapshot.cash == 1200, "completion capture owns an immutable copy")
	var summary := Review.describe({"id": "first_connection", "completed_tick": 3600, "review": snapshot}, {"name": "First Connection", "deliveries": 40, "served": 2}, values)
	check(summary.contains("1.0 game hours") and summary.contains("Operating contribution: £205") and summary.contains("Cash balance: £1200"), "review uses game time and separates operating contribution from cash")
	game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	game.startup_city_seed = "42"
	game.startup_city_count = 3
	game.startup_challenge = "first_connection"
	root.size = Vector2i(1280, 720)
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	game._update_objective_panel()
	check(not game.results_button.visible, "unfinished scenario does not advertise completed results")
	game.open_scenario_results()
	check(not game.scenario_review_dialog.visible, "unfinished scenario cannot open completion review")
	var towns: Array = game.world.state.settlements
	var a := Vector2i(towns[0].cell[0], towns[0].cell[1] + 4)
	var b := Vector2i(towns[1].cell[0], towns[1].cell[1] + 4)
	game.city_builder.submit(a)
	game.city_builder.submit(b)
	check(connect_stations(a, b), "ordinary track connects generated cities")
	var train: Dictionary = game.buy_fleet_train("passenger_standard")
	check(train.ok and game.start_passenger_service(train.id, game.world.station_key(a), game.world.station_key(b)).contains("started"), "ordinary first service starts")
	for batch in range(300):
		for tick in range(60):
			game.sim_clock.begin_tick()
			game._simulation_step(1.0 / 60.0)
		if game.seeded_challenge.state.completed_tick >= 0: break
	check(game.seeded_challenge.state.completed_tick >= 0 and not game.seeded_challenge.state.review.is_empty(), "actual final deliveries capture a completion snapshot")
	check(not game.scenario_review_dialog.visible, "completion notice never forces a popup")
	var recorded: Dictionary = game.seeded_challenge.state.review.duplicate(true)
	for tick in range(120):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
	check(game.seeded_challenge.state.review == recorded, "continued play does not rewrite historical result")
	game._update_objective_panel()
	game.paused = false
	game.results_button.pressed.emit()
	check(game.results_button.visible and game.scenario_review_dialog.visible and game.paused and game._modal_open(), "Results opens paused and participates in modal input handling")
	check(game.scenario_review_dialog.details.text.contains("Saved company totals at completion"), "new results identify their historical scope")
	var dialog = game.scenario_review_dialog
	var exported: String = dialog.summary
	check(exported.contains("Map seed: 42") and exported.contains("Scenario ID: first_connection") and exported.contains("generator:") and exported.contains("content:") and exported.contains("loans: allowed"), "share summary includes reproducibility metadata and scenario rules")
	check(exported.contains(dialog.details.text) and not exported.contains("user://") and not exported.contains("/workspace"), "share summary uses displayed historical figures without local file paths")
	var tick_before: int = game.sim_clock.tick
	dialog.export_button.pressed.emit()
	check(dialog.export_picker.visible and dialog.export_picker.file_mode == FileDialog.FILE_MODE_SAVE_FILE and dialog.export_picker.current_file == "microrail-first_connection-results.txt", "export action opens a save picker with a safe suggested filename")
	dialog.export_picker.hide()
	check(dialog.visible and game.paused, "cancelling export keeps the review open and company paused")
	var report_path := "user://scenario-result-test.txt"
	dialog._export(report_path)
	check(FileAccess.get_file_as_string(report_path) == exported and dialog.export_status.text.begins_with("Summary saved"), "export writes exact UTF-8 report including pound symbols")
	dialog._export("user://missing-export-directory/report.txt")
	check(dialog.export_status.text.begins_with("Could not save") and dialog.visible, "write failure is actionable and leaves results available")
	check(game.sim_clock.tick == tick_before and game.seeded_challenge.state.review == recorded, "sharing does not advance simulation or modify historical results")
	check(Review.write_summary(report_path, "") == ERR_INVALID_DATA and FileAccess.get_file_as_string(report_path) == exported, "empty unfinished report cannot overwrite an existing export")
	DirAccess.remove_absolute(report_path)
	game.scenario_review_dialog.hide()
	check(game._save_game(3) and game._load_slot(3) and game.seeded_challenge.state.review == recorded, "historical results survive actual save/load")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(3)))
	var invalid := saved.duplicate(true)
	invalid.seeded_challenge.review.fares = 1_000_000
	check(not game._is_valid_save(invalid), "claimed completion income cannot exceed actual company receipts")
	invalid = saved.duplicate(true)
	invalid.seeded_challenge.review.primary = 0
	check(not game._is_valid_save(invalid), "result cannot claim a completed goal below its threshold")
	var legacy := saved.duplicate(true)
	legacy.version = 52
	legacy.seeded_challenge.erase("review")
	var migrated: Dictionary = game.SaveMigrations.migrate(legacy).data
	check(migrated.version == 53 and migrated.seeded_challenge.review.is_empty() and migrated.state == legacy.state and migrated.sim == legacy.sim and game._is_valid_save(migrated), "v52 migration preserves old completion without inventing historical finances")
	game.seeded_challenge.restore_state(migrated.seeded_challenge)
	game.open_scenario_results()
	check(game.scenario_review_dialog.details.text.contains("CURRENT company totals") and game.scenario_review_dialog.details.text.contains("older completion"), "older completion clearly labels current-only financial fallback")
	check(game.scenario_review_dialog.summary.contains("CURRENT company totals") and game.scenario_review_dialog.summary.contains("older completion"), "legacy export preserves current-only disclaimer")
	game.scenario_review_dialog.hide()
	game.seeded_challenge.restore_state(saved.seeded_challenge)
	var old_scale: float = game.GameSettings.ui_scale
	game.GameSettings.ui_scale = 2.0
	game._apply_settings()
	game.open_scenario_results()
	for frame in range(3): await process_frame
	check(game.results_button.get_global_rect().end.x <= game.get_viewport_rect().size.x, "Results button remains reachable at 200 percent scale")
	check(game.scenario_review_dialog.size.x <= root.get_visible_rect().size.x and game.scenario_review_dialog.size.y <= root.get_visible_rect().size.y, "review dialog fits at 200 percent scale")
	check(game.scenario_review_dialog.get_ok_button().get_global_rect().end.y <= game.scenario_review_dialog.size.y, "Close remains reachable at 200 percent scale")
	var export_rect: Rect2 = game.scenario_review_dialog.export_button.get_global_rect()
	check(export_rect.end.x <= game.scenario_review_dialog.size.x and export_rect.end.y <= game.scenario_review_dialog.size.y, "Export control remains reachable at 200 percent scale")
	game.scenario_review_dialog.export_button.pressed.emit()
	for frame in range(2): await process_frame
	check(game.scenario_review_dialog.export_picker.size.x <= root.get_visible_rect().size.x and game.scenario_review_dialog.export_picker.size.y <= root.get_visible_rect().size.y, "export picker fits at 200 percent scale")
	game.scenario_review_dialog.hide()
	check(not game.scenario_review_dialog.export_picker.visible, "closing review hides its child export picker")
	game.GameSettings.ui_scale = old_scale
	game._apply_settings()
	game.queue_free()
	await process_frame
	print("Scenario review: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
