extends SceneTree
const Actions = preload("res://scripts/core/input_actions.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
class MouseGame:
	extends "res://scripts/main.gd"
	var pointer := Vector2.ZERO
	var over_ui := false
	func _pointer_world() -> Vector2: return pointer
	func _mouse_is_over_interface() -> bool: return over_ui
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func mouse_event(button: MouseButton, pressed: bool = true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event
func key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event
func right(game: Node, cell: Vector2i, pressed: bool) -> void:
	game.pointer = game._cell_center(cell)
	game._input(mouse_event(MOUSE_BUTTON_RIGHT, pressed))
func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.set_script(MouseGame)
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	var cell := Vector2i(40, 20)
	game.tracks[cell] = false
	game.tracks[cell + Vector2i.RIGHT] = false
	game.tracks[cell + Vector2i.RIGHT * 2] = false
	var original: Dictionary = game.tracks.duplicate()
	var funds: int = game.money
	var tick: int = game.sim_clock.tick
	for fps in [30, 60, 120]:
		for speed in [1, 10]:
			game.sim_clock.speed = speed
			game.signal_tool_mode = true
			right(game, cell, true)
			for frame in range(roundi(fps * 0.3)): game._advance_right_gesture(1.0 / fps)
			check(not game.right_removing and game.tracks == original, "short click does not remove at any FPS or simulation speed")
			right(game, cell, false)
			check(not game.signal_tool_mode and not game.draw_track_mode and game.money == funds, "short release resets tool without charging")
			right(game, cell, true)
			for frame in range(roundi(fps * 0.5)): game._advance_right_gesture(1.0 / fps)
			check(game.right_removing and game.demolition_cells.has(cell) and game.tracks == original, "hold previews removal before release at any FPS/speed")
			right(game, cell, false)
			check(not game.tracks.has(cell) and game.money == funds + game.TRACK_REFUND, "long right release removes exactly the held tile")
			check(not game.draw_track_mode and not game.demolition_mode and not game.right_pending, "completed right gesture returns to laying")
			game._undo_construction()
			check(game.tracks == original and game.money == funds, "hold removal is one undoable edit")
	check(game.paused and game.sim_clock.tick == tick, "gesture clock does not advance or resume simulation")
	# Small jitter and the timing boundary must remain safe to cancel.
	right(game, cell, true)
	game.pointer += Vector2(5, 0) / (game.camera.zoom.x * game.applied_ui_scale)
	game._advance_right_gesture(game.RIGHT_HOLD_SECONDS - 0.001)
	check(not game.right_removing, "five-pixel jitter below hold threshold remains a click")
	game._input(mouse_event(MOUSE_BUTTON_RIGHT, false))
	check(game.tracks == original and game.money == funds, "near-threshold click leaves tracks intact")
	# A fast right drag activates immediately and fills every crossed cell.
	right(game, cell, true)
	game.pointer = game._cell_center(cell + Vector2i.RIGHT * 2)
	game._input(InputEventMouseMotion.new())
	check(game.right_removing and game.right_elapsed == 0 and game.demolition_cells.size() == 3, "fast right drag needs no hold delay and interpolates crossed tiles")
	right(game, cell + Vector2i.RIGHT * 2, false)
	check(not game.tracks.has(cell) and not game.tracks.has(cell + Vector2i.RIGHT * 2) and game.money == funds + 3 * game.TRACK_REFUND, "right drag removes the complete length")
	game._undo_construction()
	check(game.tracks == original and game.money == funds, "one undo restores right-drag length")
	# UI scale must not change the physical movement threshold.
	var original_scale: float = Settings.ui_scale
	for scale_value in [1.0, 2.0]:
		Settings.ui_scale = scale_value
		game._apply_settings()
		right(game, cell, true)
		game.pointer += Vector2(6, 0) / (game.camera.zoom.x * game.applied_ui_scale)
		game._input(InputEventMouseMotion.new())
		check(game.right_removing, "six screen pixels activates at both UI scales")
		game._unhandled_input(key_event(KEY_ESCAPE))
		game._input(mouse_event(MOUSE_BUTTON_RIGHT, false))
		check(game.tracks == original, "Escape cancels activated deletion without modifying tracks")
	Settings.ui_scale = original_scale
	game._apply_settings()
	# Presses over a toolbar/dialog cannot delete the map underneath it.
	game.over_ui = true
	right(game, cell, true)
	game._advance_right_gesture(1.0)
	game.over_ui = false
	right(game, cell, false)
	check(game.tracks == original, "a hold starting over UI never deletes map tiles")
	game._open_traffic_dialog()
	game.traffic_dialog.window_input.emit(mouse_event(MOUSE_BUTTON_RIGHT))
	game._advance_right_gesture(1.0)
	check(not game.right_removing and game.traffic_dialog.visible, "Traffic hold never becomes map demolition")
	game.traffic_dialog.window_input.emit(mouse_event(MOUSE_BUTTON_RIGHT, false))
	check(not game.traffic_dialog.visible and game.tracks == original and game.paused, "Traffic right release closes without deleting or resuming")
	right(game, cell, true)
	game._advance_right_gesture(0.5)
	game.over_ui = true
	game._input(InputEventMouseMotion.new())
	game.over_ui = false
	right(game, cell, false)
	check(game.tracks == original and not game.right_pending, "dragging onto a toolbar cancels removal")
	right(game, cell, true)
	game._advance_right_gesture(0.5)
	root.focus_exited.emit()
	right(game, cell, false)
	check(game.tracks == original and not game.demolition_mode, "loss of window focus cancels a held deletion")
	right(game, cell, true)
	game._advance_right_gesture(0.5)
	game._unhandled_input(key_event(KEY_HOME))
	right(game, cell, false)
	check(game.tracks == original and not game.right_pending, "resetting the camera cancels held deletion instead of moving its target")
	right(game, cell, true)
	game._advance_right_gesture(0.5)
	game._on_viewport_size_changed()
	right(game, cell, false)
	check(game.tracks == original and not game.right_pending, "resizing/fullscreen cancels held deletion safely")
	right(game, cell, true)
	game._advance_right_gesture(0.5)
	game._input(mouse_event(MOUSE_BUTTON_LEFT))
	right(game, cell, false)
	check(game.tracks == original, "left press cancels a pending right deletion")
	# Draft gestures use normal grouped validation/application.
	game._set_planning_mode(true)
	right(game, cell, true)
	game._advance_right_gesture(0.5)
	right(game, cell, false)
	check(game.tracks == original and game.construction_plan.changes.get(cell, true) == null, "held right removal stages a draft without touching live track")
	check(game._apply_draft() and not game.tracks.has(cell), "draft removal applies through the normal transaction")
	game._undo_construction()
	game._set_planning_mode(false)
	check(game.tracks == original and game.money == funds, "draft undo restores track and balance")
	# R selects removal, respects typing/modal focus, and can be remapped.
	game._unhandled_input(key_event(KEY_R))
	check(game.demolition_mode and game.remove_button.button_pressed, "R selects Remove without rotation")
	game._reset_track_tools()
	var entry := LineEdit.new()
	root.add_child(entry)
	entry.grab_focus()
	game._unhandled_input(key_event(KEY_R))
	check(not game.demolition_mode, "typing R never selects removal")
	entry.release_focus()
	entry.queue_free()
	game._open_traffic_dialog()
	game._unhandled_input(key_event(KEY_R))
	check(not game.demolition_mode and game.traffic_dialog.visible, "R does not operate through Traffic")
	game.traffic_dialog.hide()
	Actions.apply_bindings({str(Actions.SELECT_REMOVE): [KEY_T]})
	game._unhandled_input(key_event(KEY_R))
	check(not game.demolition_mode, "old removal key stops working after remap")
	game._unhandled_input(key_event(KEY_T))
	game._refresh_shortcut_tooltips()
	check(game.demolition_mode and game.remove_button.tooltip_text.contains("T"), "remapped removal key and tooltip work")
	Actions.register_defaults()
	game._reset_track_tools()
	# Reservation protection remains in force for held right removal.
	for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	game.route_distance = 96.0
	game._update_train_transform()
	game._rebuild_reservations()
	var occupied := Vector2i(7, 8)
	check(game.reservations.owners.has(occupied), "held-removal safety fixture is occupied")
	right(game, occupied, true)
	game._advance_right_gesture(0.5)
	right(game, occupied, false)
	check(game.tracks.has(occupied) and game.money == funds, "long right click cannot remove occupied track")
	game.queue_free()
	await process_frame
	print("Right mouse gestures: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
