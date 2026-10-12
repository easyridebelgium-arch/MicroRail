extends SceneTree
class MouseGame:
	extends "res://scripts/main.gd"
	var pointer := Vector2.ZERO
	func _pointer_world() -> Vector2: return pointer
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: _run.call_deferred()
func mouse(game: Node, at: Vector2, down: bool) -> void:
	game.pointer = at
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	game._unhandled_input(event)
func _run() -> void:
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.set_script(MouseGame)
	game.paused = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var balance: int = game.money
	var commands: Dictionary = game.command_queue.save_state().duplicate(true)
	# The bottom platform edge is outside the train sprite on occupied Station A.
	var platform: Vector2 = Vector2(game.STATION_A) * 32 + Vector2(16, 30)
	mouse(game, platform, true)
	check(not game.station_panel.visible, "inspection must wait for release so a station press can become a drag")
	mouse(game, platform, false)
	check(game.station_panel.visible and game.selected_station == game.STATION_A and not game.inspect_mode, "plain platform click must inspect the station without I")
	check(game.money == balance and game.command_queue.save_state() == commands, "station inspection must not spend money")
	game.station_panel.hide()
	mouse(game, game.train_position, true)
	mouse(game, game.train_position, false)
	check(game.train_inspector.visible and game.train_inspector.selected_id == 1, "plain train-body click must open the existing train popup")
	game.train_inspector.hide()
	var start: Vector2 = game._cell_center(game.STATION_A)
	mouse(game, start, true)
	game.pointer = game._cell_center(Vector2i(8, 8))
	var motion := InputEventMouseMotion.new()
	game._unhandled_input(motion)
	mouse(game, game.pointer, false)
	check(not game.train_inspector.visible and not game.station_panel.visible and game.tracks.has(Vector2i(7, 8)), "dragging from an occupied station must build track and suppress inspection")
	check(game.money == balance - 40, "station drag must charge only newly built track")
	game._close_station_inspector()
	mouse(game, game._cell_center(Vector2i(40, 18)), true)
	check(game.is_dragging and game.direct_inspect_train < 0, "empty-map press must retain the ordinary construction gesture")
	mouse(game, game._cell_center(Vector2i(44, 18)), false)
	check(game.tracks.has(Vector2i(40, 18)) and game.tracks.has(Vector2i(43, 18)) and not game.tracks.has(Vector2i(44, 18)) and not game.train_inspector.visible, "four-cell empty-map drag must build four pieces without an extra endpoint")
	check(game.money == balance - 80, "empty-map drag charges four pieces in addition to the prior station extension")
	game.signal_tool_mode = true
	mouse(game, game._cell_center(Vector2i(7, 8)), true)
	mouse(game, game.pointer, false)
	check(game.track_signals.get(Vector2i(7, 8)) == "auto" and not game.station_panel.visible, "active signal tool must retain click priority")
	game.signal_tool_mode = false
	game.inspection_panel.plan_toggle.button_pressed = true
	mouse(game, platform, true)
	mouse(game, platform, false)
	check(not game.station_panel.visible and not game.train_inspector.visible, "draft construction must keep its tool interactions")
	game._discard_draft()
	game.inspection_panel.plan_toggle.button_pressed = false
	mouse(game, platform, true)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._unhandled_input(escape)
	mouse(game, platform, false)
	check(not game.station_panel.visible, "Escape must cancel pending click inspection")
	mouse(game, platform, true)
	game.pointer = game._cell_center(Vector2i(6, 8))
	game._unhandled_input(motion)
	mouse(game, platform, false)
	check(not game.station_panel.visible, "a drag returning to its starting cell must not become an inspection click")
	# Direct building-ground clicks should work even though building is forbidden there.
	var building: Vector2 = game._cell_center(game.STATION_A + Vector2i(0, -1))
	mouse(game, building, true)
	mouse(game, building, false)
	check(game.station_panel.visible and game.selected_station == game.STATION_A, "station building click must inspect without starting construction")
	game._close_station_inspector()
	mouse(game, game.freight_train.position, true)
	mouse(game, game.freight_train.position, false)
	check(game.train_inspector.visible and game.train_inspector.selected_id == 2, "freight bodies must also support direct inspection")
	game.train_inspector.hide()
	game.queue_free()
	await process_frame
	print("Direct inspection: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
