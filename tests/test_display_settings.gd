extends SceneTree
## Resize the real root viewport and exercise settings, shortcuts and key capture.
const Settings = preload("res://scripts/core/game_settings.gd")
const Actions = preload("res://scripts/core/input_actions.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func key_event(code: Key, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	return event

func _run() -> void:
	var existed := FileAccess.file_exists(Settings.SETTINGS_PATH)
	var previous := FileAccess.get_file_as_bytes(Settings.SETTINGS_PATH) if existed else PackedByteArray()
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	Settings.fullscreen = false
	root.mode = Window.MODE_WINDOWED
	var position_before: Vector2 = game.train_position
	var tick_before: int = game.sim_clock.tick

	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(1920, 1200)]:
		root.size = dimensions
		for scale_value in [1.0, 2.0]:
			Settings.ui_scale = scale_value
			game._apply_settings()
			await process_frame
			await process_frame
			var expected: Vector2 = Vector2(dimensions) / scale_value
			check(root.get_visible_rect().size.is_equal_approx(expected), "whole window is playable at %s / %s%%" % [dimensions, scale_value * 100])
			check(is_equal_approx(game.camera.zoom.x * scale_value, 1.0), "resizing preserves map pixel scale")
			check(is_equal_approx(game.header_background.size.x, expected.x), "header stretches to full viewport width")
			check(is_equal_approx(game.header_box.size.x, expected.x - 48.0), "toolbar layout follows window width")
			game.settings_dialog.open_dialog()
			await process_frame
			await process_frame
			var dialog: ConfirmationDialog = game.settings_dialog
			check(float(dialog.size.y) <= expected.y + 1.0, "settings fits window at selected UI scale")
			check(Rect2(Vector2.ZERO, Vector2(dialog.size)).encloses(dialog.get_ok_button().get_global_rect()), "Apply button remains reachable")
			dialog.hide()

	game._unhandled_input(key_event(KEY_F11))
	check(Settings.fullscreen, "F11 requests fullscreen")
	check(game.paused and game.sim_clock.tick == tick_before and game.train_position == position_before, "display change preserves simulation state")
	Settings.fullscreen = false
	Settings.load_settings()
	check(Settings.fullscreen, "shortcut persists fullscreen preference")
	game._unhandled_input(key_event(KEY_F11, true))
	check(Settings.fullscreen, "held key does not repeatedly toggle")
	game._unhandled_input(key_event(KEY_F11))
	check(not Settings.fullscreen, "F11 leaves fullscreen")
	# Headless DisplayServer reports the live desktop window as minimized.
	# Use an unattached Window to verify actual mode transitions/restoration.
	var window := Window.new()
	for original_mode in [Window.MODE_WINDOWED, Window.MODE_MAXIMIZED]:
		window.mode = original_mode
		Settings.fullscreen = true
		Settings.apply_fullscreen(window)
		check(window.mode == Window.MODE_FULLSCREEN, "fullscreen applies to window")
		Settings.fullscreen = false
		Settings.apply_fullscreen(window)
		check(window.mode == original_mode, "fullscreen exit restores previous mode")
	Settings.apply(window)
	check(window.mode == Window.MODE_MAXIMIZED, "other settings do not force a window mode change")
	window.free()

	game.settings_dialog.open_dialog()
	game.settings_dialog.fullscreen_check.button_pressed = true
	game.settings_dialog._apply()
	check(Settings.fullscreen, "Settings Apply enables fullscreen")
	game.settings_dialog._input(key_event(KEY_F11))
	check(not Settings.fullscreen and not game.settings_dialog.fullscreen_check.button_pressed, "shortcut inside Settings updates the checkbox")
	game.settings_dialog._begin_capture(Actions.TOGGLE_FULLSCREEN)
	game.settings_dialog._input(key_event(KEY_F11))
	check(not Settings.fullscreen and game.settings_dialog.capturing_action == &"", "remapping captures F11 without changing display")
	game.settings_dialog.hide()

	Actions.apply_bindings({str(Actions.TOGGLE_FULLSCREEN): [KEY_F6]})
	game._unhandled_input(key_event(KEY_F11))
	check(not Settings.fullscreen, "old shortcut stops working after remap")
	game._unhandled_input(key_event(KEY_F6))
	check(Settings.fullscreen, "remapped fullscreen shortcut works")
	game._unhandled_input(key_event(KEY_F6))
	var entry := LineEdit.new()
	root.add_child(entry)
	entry.grab_focus()
	game._unhandled_input(key_event(KEY_F6))
	check(not Settings.fullscreen, "typing does not activate remapped shortcut")
	entry.queue_free()

	# Older player settings still load; game save schema is untouched.
	var legacy := ConfigFile.new()
	legacy.set_value("display", "ui_scale", 1.25)
	legacy.save(Settings.SETTINGS_PATH)
	Settings.fullscreen = true
	Settings.load_settings()
	check(not Settings.fullscreen and Settings.ui_scale == 1.25, "missing fullscreen preference defaults safely")
	if existed:
		var file := FileAccess.open(Settings.SETTINGS_PATH, FileAccess.WRITE)
		file.store_buffer(previous)
		file.close()
	else:
		DirAccess.remove_absolute(Settings.SETTINGS_PATH)
	game.queue_free()
	await process_frame
	print("Display settings tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
