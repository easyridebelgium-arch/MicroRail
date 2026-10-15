extends SceneTree
const Slots = preload("res://scripts/core/save_slots.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
const Actions = preload("res://scripts/core/input_actions.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func settle() -> void:
	for frame in range(4): await process_frame
func cancel_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = Actions.CANCEL
	event.pressed = true
	return event
func fixture() -> Node:
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.active_save_slot = 4
	root.add_child(game)
	game.set_process(false)
	current_scene = game
	return game

func run() -> void:
	root.size = Vector2i(1280, 720)
	var originals: Dictionary = {}
	for kind in ["save", "backup", "temp"]:
		var path := Slots.path(4, kind)
		originals[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	var game = fixture()
	await settle()
	game.paused = false
	game.sim_clock.speed = 5
	var tick_before: int = game.sim_clock.tick
	var position_before: Vector2 = game.train_position
	game._unhandled_input(cancel_event())
	check(game.game_menu.visible and game.paused and game._modal_open(), "idle Escape opens a modal paused game menu")
	game._process(1.0)
	check(game.sim_clock.tick == tick_before and game.train_position == position_before, "menu prevents simulation ticks and train movement")
	game.game_menu.window_input.emit(cancel_event())
	check(not game.game_menu.active and not game.paused and game.sim_clock.speed == 5, "Escape resumes the previous running state and speed")
	game.paused = true
	game._open_game_menu()
	game.game_menu.confirmed.emit()
	check(game.paused and not game.game_menu.active, "Resume preserves an already paused game")
	game.signal_tool_mode = true
	game._unhandled_input(cancel_event())
	check(not game.signal_tool_mode and not game.game_menu.active, "Escape cancels an active map tool before opening the menu")
	game._unhandled_input(cancel_event())
	check(game.game_menu.visible, "a second Escape opens the menu after tool cancellation")
	game.game_menu.settings_button.pressed.emit()
	check(game.settings_dialog.visible and not game.game_menu.visible and game.game_menu.active, "Settings opens from the menu without releasing pause")
	game.settings_dialog.hide()
	await settle()
	check(game.game_menu.visible and game.paused, "closing Settings returns to the paused game menu")
	game.game_menu.return_button.pressed.emit()
	check(game.game_menu.leave_dialog.visible and game.game_menu.returning and game.paused, "returning to Main Menu offers explicit save or discard choices")
	game.game_menu.leave_dialog.canceled.emit()
	check(game.game_menu.visible and not game.game_menu.returning and current_scene == game, "cancelling return preserves the current game")
	game.construction_plan.stage({Vector2i(10, 10): false}, game.tracks)
	game.game_menu.request_return()
	game.game_menu.leave_dialog.confirmed.emit()
	check(current_scene == game and game.game_menu.visible and game.game_menu.status.text.contains("construction draft"), "a failed save never leaves the game and explains how to recover")
	check(not game.construction_plan.is_empty(), "opening and cancelling the menu preserve construction drafts")
	game.construction_plan.clear()
	game.money = 1234
	game.game_menu.save_button.pressed.emit()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(Slots.path(4)))
	check(saved is Dictionary and saved.state.money == 1234 and game.game_menu.status.text.contains("Slot 4"), "Save writes the active slot and confirms success inside the menu")
	var original_scale: float = Settings.ui_scale
	Settings.ui_scale = 2
	game._apply_settings()
	game.game_menu.hide()
	game.game_menu.popup_centered_clamped(Vector2i(420, 340), 0.95)
	await settle()
	check(game.game_menu.size.y <= root.get_visible_rect().size.y and game.game_menu.size.x <= root.get_visible_rect().size.x, "game menu fits 200 percent UI scaling")
	game.game_menu.request_return()
	await settle()
	check(game.game_menu.leave_dialog.size.y <= root.get_visible_rect().size.y and game.game_menu.leave_dialog.size.x <= root.get_visible_rect().size.x, "save/discard confirmation fits 200 percent UI scaling: %s vs %s" % [game.game_menu.leave_dialog.size, root.get_visible_rect().size])
	game.game_menu._cancel_return()
	Settings.ui_scale = original_scale
	game._apply_settings()
	var previous_save := FileAccess.get_file_as_bytes(Slots.path(4))
	game.money = 4321
	game.game_menu.request_return()
	game.game_menu.discard_button.pressed.emit()
	await settle()
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/ui/title.tscn", "Return Without Saving opens the actual title scene")
	check(FileAccess.get_file_as_bytes(Slots.path(4)) == previous_save, "Return Without Saving leaves the saved company unchanged")
	current_scene.queue_free()
	current_scene = null
	await settle()
	game = fixture()
	await settle()
	game.paused = true
	game.money = 2468
	# The existing Settings entry must use the same protected exit flow.
	game.settings_dialog.main_menu_requested.emit()
	check(game.game_menu.leave_dialog.visible, "Settings Return to Main Menu uses the same save/discard confirmation")
	game.game_menu.leave_dialog.confirmed.emit()
	await settle()
	saved = JSON.parse_string(FileAccess.get_file_as_string(Slots.path(4)))
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/ui/title.tscn" and saved.state.money == 2468, "Save and Return writes progress before opening the title scene")
	current_scene.queue_free()
	current_scene = null
	await settle()
	for path in originals:
		if originals[path] == null:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(originals[path])
			file.close()
	print("Game menu: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
