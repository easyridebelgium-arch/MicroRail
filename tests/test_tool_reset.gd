extends SceneTree
const Actions = preload("res://scripts/core/input_actions.gd")
class MouseGame:
	extends "res://scripts/main.gd"
	var pointer := Vector2.ZERO
	func _pointer_world() -> Vector2: return pointer
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func event(button: MouseButton, down: bool = true) -> InputEventMouseButton:
	var value := InputEventMouseButton.new()
	value.button_index = button
	value.pressed = down
	return value
func mouse(game: Node, cell: Vector2i, down: bool) -> void:
	game.pointer = game._cell_center(cell)
	game._unhandled_input(event(MOUSE_BUTTON_LEFT, down))
func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.set_script(MouseGame)
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	var original: Dictionary = game.tracks.duplicate()
	var funds: int = game.money
	for tool in ["signal_tool_mode", "switch_tool_mode", "waypoint_tool_mode", "inspect_mode", "demolition_mode"]:
		game.set(tool, true)
		game.is_dragging = true
		game.build_plan = {"changes": {Vector2i(40, 20): false}}
		game.demolition_cells = {game.STATION_A: true}
		game.corridor_pick = 2
		game._input(event(MOUSE_BUTTON_RIGHT))
		game._input(event(MOUSE_BUTTON_RIGHT, false))
		check(not game.get(tool) and not game.draw_track_mode and not game.is_dragging and game.corridor_pick == 0 and game.build_plan.is_empty() and game.demolition_cells.is_empty(), "right click releases the active tool and gesture")
		check(game.straight_button.button_pressed and not game.curve_button.button_pressed, "right reset selects Connect, not Draw, in the toolbar")
		check(game.tracks == original and game.money == funds and game.paused, "reset neither edits infrastructure nor resumes the game")
		game._unhandled_input(event(MOUSE_BUTTON_RIGHT, false))
		check(not game.is_dragging, "right release cannot start demolition")
	# Test the actual signal installed on the exclusive Traffic window.
	game._open_traffic_dialog()
	check(game.traffic_dialog.visible, "Traffic fixture opens")
	game.traffic_dialog.window_input.emit(event(MOUSE_BUTTON_RIGHT))
	game.traffic_dialog.window_input.emit(event(MOUSE_BUTTON_RIGHT, false))
	check(not game.traffic_dialog.visible and not game.draw_track_mode and game.paused, "right click inside Traffic closes it and returns to laying")
	# Drafts survive tool changes; only the current gesture is cancelled.
	game._set_planning_mode(true)
	game.construction_plan.stage({Vector2i(40, 20): false}, game.tracks)
	game.signal_tool_mode = true
	game._unhandled_input(event(MOUSE_BUTTON_RIGHT))
	game._unhandled_input(event(MOUSE_BUTTON_RIGHT, false))
	check(game.planning_mode and not game.construction_plan.is_empty() and not game.signal_tool_mode, "right reset retains unapplied construction drafts")
	game._discard_draft()
	game._set_planning_mode(false)
	# Removal is still reachable, with left-drag from the Remove toolbar.
	var cell := Vector2i(40, 20)
	game.tracks[cell] = false
	game.tracks[cell + Vector2i.RIGHT] = false
	game.remove_button.pressed.emit()
	check(game.demolition_mode and game.remove_button.button_pressed and not game.curve_button.button_pressed, "Remove toolbar selects the removal tool")
	mouse(game, cell, true)
	mouse(game, cell + Vector2i.RIGHT, false)
	check(not game.tracks.has(cell) and not game.tracks.has(cell + Vector2i.RIGHT) and game.money == funds + 2 * game.TRACK_REFUND, "left drag removes both pieces and refunds them")
	game._undo_construction()
	check(game.tracks.has(cell) and game.tracks.has(cell + Vector2i.RIGHT) and game.money == funds, "removal remains undoable")
	mouse(game, cell, true)
	game._input(event(MOUSE_BUTTON_RIGHT))
	game._input(event(MOUSE_BUTTON_RIGHT, false))
	mouse(game, cell + Vector2i.RIGHT, false)
	check(game.tracks.has(cell) and game.tracks.has(cell + Vector2i.RIGHT), "right reset cancels a removal without committing it")
	# The next left gesture builds normally after resetting a signal tool.
	game.signal_tool_mode = true
	game._input(event(MOUSE_BUTTON_RIGHT))
	game._input(event(MOUSE_BUTTON_RIGHT, false))
	mouse(game, Vector2i(45, 20), true)
	mouse(game, Vector2i(46, 20), false)
	check(game.tracks.has(Vector2i(45, 20)) and not game.track_signals.has(Vector2i(45, 20)) and game.money == funds - game.TRACK_BUILD_COST, "next left drag lays one piece instead of operating the old tool")
	Actions.apply_mouse_bindings({"demolish": [MOUSE_BUTTON_XBUTTON1]})
	check(event(MOUSE_BUTTON_XBUTTON1).is_action_pressed(Actions.RESET_TOOL), "legacy right-mouse remapping migrates to reset")
	Actions.register_defaults()
	game.queue_free()
	await process_frame
	print("Tool reset: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
