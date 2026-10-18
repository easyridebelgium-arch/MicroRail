extends SceneTree
const Preview = preload("res://scripts/core/save_preview.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
const Title = preload("res://scripts/title_screen.gd")
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	var geometry: Dictionary = game._saved_runtime_routes()
	var money: int = game.money
	var tick: int = game.sim_clock.tick
	check(game.set_route_identity("passenger", "EXP", 3).begins_with("Route appearance"), "route identity can be changed separately")
	check(game.route_identity("passenger").label == "EXP" and game.route_colour("passenger") == Color(game.Presentation.COLOURS[3]), "chosen identity drives label/colour")
	check(game._saved_runtime_routes() == geometry and game.money == money and game.sim_clock.tick == tick, "appearance cannot alter routes/cash/clock")
	check(game.set_route_identity("passenger", "TOO-LONG", 0).begins_with("Use"), "invalid label rejected")
	var linked: Dictionary = game.services.duplicate(true)
	linked["passenger_3"] = {"link": "passenger"}
	check(game.Presentation.identity(linked, game.presentation, "passenger_3").label == "EXP", "linked trains share source identity")
	game._open_routes_editor()
	check(game.route_editor.style_label.text == "EXP" and game.route_editor.style_colour.selected == 3, "route editor displays saved identity")
	game.route_editor.hide()
	var cell := Vector2i(10, 8)
	game.track_signals[cell] = "auto"
	check(game.signal_cue(cell) == "A", "idle automatic cue is not a false green")
	game.reservations.owners[cell] = 1
	check(game.signal_cue(cell) == "R", "reserved signal tile has a distinct cue")
	game.movement_conflicts[1] = {"cell": cell, "revision": game.authority_revision}
	check(game.signal_cue(cell) == "H", "current denied movement has holding cue")
	game.authority_revision += 1
	check(game.signal_cue(cell) == "R", "stale denial does not imply a current stop")
	game.track_signals[cell] = "stop"
	check(game.signal_cue(cell) == "S", "manual stop has separate square/S cue")
	game.track_signals.clear()
	game.reservations.owners.erase(cell)
	game.movement_conflicts.clear()
	game.deadlocks.cycles = [[1, 2]]
	game.alert_banner.refresh()
	check(game.alert_banner.visible and game.alert_banner.selected.severity == "Urgent", "deadlock has a persistent actionable banner")
	game.alert_banner.acknowledge_button.pressed.emit()
	check(not game.alert_banner.visible and game.problem_rows()[0].acknowledged and game.deadlocks.cycles == [[1, 2]], "acknowledgement hides banner without resolving or hiding problem")
	check(game._save_game(1), "appearance and acknowledgement save")
	var saved := JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH)) as Dictionary
	check(int(saved.version) >= 28 and game._is_valid_save(saved), "presentation save validates")
	var before: Dictionary = game.presentation.duplicate(true)
	game.presentation = game.Presentation.defaults()
	check(game._load_game() and game.presentation == before, "appearance and acknowledgement survive load")
	game.deadlocks.cycles.clear()
	game._clear_resolved_acknowledgements()
	check(game.presentation.acknowledged.is_empty(), "resolved conditions rearm future alerts")
	var corrupt := saved.duplicate(true)
	corrupt.presentation.routes.passenger.colour = 3.5
	check(not game._is_valid_save(corrupt), "invalid palette index rejected atomically")
	var old := saved.duplicate(true)
	old.version = 27
	old.erase("presentation")
	var migration: Dictionary = game.SaveMigrations.migrate(old)
	check(migration.ok and migration.data.presentation == game.Presentation.defaults() and game._is_valid_save(migration.data), "v27 migration adds appearance defaults without changing simulation")
	var snapshot := Preview.read(game.SAVE_PATH)
	check(snapshot.available and snapshot.cash == game.money and snapshot.text.contains(game.game_clock_text()), "preview reads real cash/time")
	game.save_slots_dialog.open_dialog("load")
	check(game.save_slots_dialog.thumbnail.snapshot.available and game.save_slots_dialog.preview_label.text.contains("Balance"), "slot chooser shows map/time/balance")
	game.save_slots_dialog.hide()
	var bad_path := "user://broken_preview.json"
	var file := FileAccess.open(bad_path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check(not Preview.read(bad_path).available and Preview.read(bad_path).text.contains("Load will validate"), "bad preview does not crash or claim save validity")
	var prior_speed: float = game.sim_clock.speed
	var prior_slow: bool = Settings.slow_on_incident
	Settings.slow_on_incident = true
	game.paused = false
	game.sim_clock.speed = 10
	game._record_event(game.EventLog.DEADLOCK_DETECTED, "1", {"trains": [1, 2]})
	check(game.sim_clock.speed == 1 and not game.paused, "optional incident slowdown is 1x, not an unsolicited pause")
	Settings.slow_on_incident = prior_slow
	game.sim_clock.speed = prior_speed
	game.paused = true
	var prior_scale: float = Settings.ui_scale
	for scale_value in [1.0, 2.0]:
		Settings.ui_scale = scale_value
		game._apply_settings()
		game.save_slots_dialog.open_dialog("load")
		await process_frame
		await process_frame
		check(float(game.save_slots_dialog.size.y) <= game.get_viewport_rect().size.y + 1, "preview chooser fits selected scale")
		check(Rect2(Vector2.ZERO, Vector2(game.save_slots_dialog.size)).encloses(game.save_slots_dialog.get_ok_button().get_global_rect()), "chooser action remains accessible")
		game.save_slots_dialog.hide()
		var title := Title.new()
		root.add_child(title)
		await process_frame
		check(title.continue_button.disabled == false and not title.progress.visible and not title.busy, "branded menu has Continue with no fake loading bar")
		check(title.menu.get_parent().get_parent() is ScrollContainer, "title actions can scroll at enlarged scale")
		title.queue_free()
		await process_frame
	Settings.ui_scale = prior_scale
	game._apply_settings()
	game.queue_free()
	await process_frame
	# Failed Continue keeps title usable; successful load restores exact saved state.
	var title := Title.new()
	root.add_child(title)
	current_scene = title
	await process_frame
	title.pending_slot = 4
	title.pending_load = true
	title._finish(load("res://scenes/main/main.tscn"))
	check(current_scene == title and title.status.text.begins_with("Load failed"), "failed Continue/load never replaces title with broken gameplay")
	title.pending_slot = 1
	title._finish(load("res://scenes/main/main.tscn"))
	var loaded = current_scene
	loaded.set_process(false)
	check(loaded != title and loaded.presentation.routes.passenger.label == "EXP", "successful title load restores full game and identity")
	loaded.queue_free()
	current_scene = null
	await process_frame
	print("Stage UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
