extends SceneTree
const Art = preload("res://scripts/ui/toolbar_art.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	game._update_toolbar()
	var buttons := 0
	for child in game.header_toolbar.get_children():
		if not child is Button or not child.visible or child is OptionButton: continue
		buttons += 1
		check(child.has_meta("toolbar_action") and child.icon != null and child.icon.get_size() == Vector2(24, 24), "every visible toolbar action has a normalized icon")
		check(not child.tooltip_text.is_empty() and not child.accessibility_name.is_empty() and child.focus_mode == Control.FOCUS_ALL, "icon action retains meaning and keyboard focus")
		check(child.get_theme_stylebox("normal") is StyleBoxTexture and child.get_theme_stylebox("disabled") is StyleBoxTexture and child.get_theme_stylebox("focus") is StyleBoxFlat, "action exposes textured states and visible focus")
	check(buttons == 20, "all twenty toolbar actions are styled")
	check(game.pause_button.icon == Art.texture("icons/play.png", Vector2i(24, 24), true), "paused control offers Play")
	game.pause_button.pressed.emit()
	check(not game.paused and game.pause_button.icon == Art.texture("icons/pause.png", Vector2i(24, 24), true), "Play still resumes and becomes Pause")
	game.pause_button.pressed.emit()
	check(game.paused, "Pause still stops simulation")
	game.curve_button.pressed.emit()
	check(game.draw_track_mode and game.curve_button.button_pressed and not game.straight_button.button_pressed, "draw tool retains selected state")
	check(game.curve_button.get_theme_stylebox("pressed") == Art.style("selected"), "toggle uses selected artwork")
	game.curve_button.grab_focus()
	var space := InputEventKey.new()
	space.pressed = true
	space.keycode = KEY_SPACE
	game._input(space)
	check(not game.paused and game.draw_track_mode, "Space pauses/resumes rather than reactivating the focused tool")
	game._input(space)
	check(game.paused, "focused pause shortcut toggles back")
	game.curve_button.release_focus()
	game._reset_track_tools()
	check(not game.draw_track_mode and game.straight_button.button_pressed, "reset retains Connect default")
	game.is_dragging = true
	game._update_toolbar()
	check(game.save_button.disabled and game.load_button.disabled and game.backup_button.disabled, "save actions retain drag safety")
	game.is_dragging = false
	game._update_toolbar()
	game._update_instructions()
	check(game.problems_button.text == str(game.problem_rows().size()), "Problems keeps a live numeric count")
	check(game.speed_selector.get_theme_icon("arrow").get_size() == Vector2(8, 8), "speed menu uses supplied arrow")
	check(game.undo_button.icon != null and game.redo_button.icon != null, "construction history uses supplied icons")
	var pressed := Art.style("pressed").texture.get_image()
	check(pressed.get_pixel(0, 0).a == 0.0 and pressed.get_pixel(32, 32).a > 0.9, "white pressed surround is removed without losing opaque centre")
	var original_scale: float = Settings.ui_scale
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		for scale_value in [1.0, 2.0]:
			Settings.ui_scale = scale_value
			game._apply_settings()
			await process_frame
			await process_frame
			var bounds := Rect2(Vector2.ZERO, game.header_toolbar.size)
			for child in game.header_toolbar.get_children():
				if child is Control and child.visible:
					check(bounds.grow(1).encloses(Rect2(child.position, child.size)), "flow keeps controls inside toolbar at both scales and window sizes")
			check(game.header_background.size.y < game.get_viewport_rect().size.y, "toolbar leaves visible map space")
	Settings.ui_scale = original_scale
	game._apply_settings()
	game.queue_free()
	await process_frame
	print("Toolbar art: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
