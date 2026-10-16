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
func _run() -> void:
	root.size = Vector2i(1280, 720)
	var existed := FileAccess.file_exists(Settings.SETTINGS_PATH)
	var previous := FileAccess.get_file_as_bytes(Settings.SETTINGS_PATH) if existed else PackedByteArray()
	var original_map: bool = Settings.map_visible
	var original_goals: bool = Settings.goals_visible
	var original_scale: float = Settings.ui_scale
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	game.network_map.visible = true
	game.objective_panel.visible = true
	game._toggle_network_map()
	game._toggle_objective_panel()
	check(not Settings.map_visible and not Settings.goals_visible, "toggles update player preferences")
	check(not game.map_button.button_pressed and not game.goals_button.button_pressed, "toggle buttons match actual visibility")
	Settings.map_visible = true
	Settings.goals_visible = true
	Settings.load_settings()
	check(not Settings.map_visible and not Settings.goals_visible, "hidden panels persist on disk")
	var fresh = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(fresh)
	await process_frame
	fresh.set_process(false)
	fresh.paused = true
	check(not fresh.network_map.visible and not fresh.objective_panel.visible and not fresh.map_button.button_pressed and not fresh.goals_button.button_pressed, "new game restores hidden panels and buttons")
	fresh._save_game(2)
	fresh._load_slot(2)
	check(not fresh.network_map.visible and not fresh.objective_panel.visible, "loading another slot does not override shared panel preferences")
	for station in [fresh.STATION_A, fresh.FOREST_SITE, fresh.CARGO_TERMINAL]:
		fresh._inspect_station_at(station)
		check(not fresh.station_summary.text.is_empty() and not fresh.station_details.visible, "every facility has an overview above initially collapsed details")
		fresh.station_details_toggle.button_pressed = true
		check(fresh.station_details.visible and fresh.station_details_toggle.text == "Hide details", "details expand without removing facility controls")
		fresh.station_details_toggle.button_pressed = false
	check(fresh.freight_rule_option.visible and not fresh.amenity_buttons.shelter.visible, "industry controls retain freight rule and hide passenger amenities")
	fresh._inspect_station_at(fresh.STATION_A)
	check(not fresh.freight_rule_option.visible and fresh.amenity_buttons.shelter.visible, "passenger station controls retain amenities")
	var position_before: Vector2 = fresh.train_position
	var tick_before: int = fresh.sim_clock.tick
	for scale_value in [1.0, 1.5, 2.0]:
		Settings.ui_scale = scale_value
		fresh._apply_settings()
		await process_frame
		await process_frame
		fresh._layout_header()
		check(fresh.get_viewport_rect().encloses(fresh.station_panel.get_global_rect()), "station sidebar remains inside viewport at %s%%" % (scale_value * 100))
		var close: Button = fresh.station_panel.find_child("CloseInspector", true, false)
		check(fresh.station_panel.get_global_rect().encloses(close.get_global_rect()), "Close stays visible outside scrolling details")
		fresh.loans_dialog.open_dialog()
		await process_frame
		await process_frame
		check(float(fresh.loans_dialog.size.y) <= fresh.get_viewport_rect().size.y + 1, "Bank fits viewport at %s%%" % (scale_value * 100))
		check(Rect2(Vector2.ZERO, Vector2(fresh.loans_dialog.size)).encloses(fresh.loans_dialog.get_ok_button().get_global_rect()), "Bank Close remains accessible")
		fresh.loans_dialog.hide()
	check(fresh.sim_clock.tick == tick_before and fresh.train_position == position_before, "inspector layout cannot advance simulation or teleport train")
	Settings.ui_scale = original_scale
	Settings.map_visible = original_map
	Settings.goals_visible = original_goals
	if existed:
		var file := FileAccess.open(Settings.SETTINGS_PATH, FileAccess.WRITE)
		file.store_buffer(previous)
		file.close()
	else: DirAccess.remove_absolute(Settings.SETTINGS_PATH)
	game.queue_free()
	fresh.queue_free()
	await process_frame
	print("Panel preferences: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
