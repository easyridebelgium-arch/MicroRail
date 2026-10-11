extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: _run.call_deferred()
func drag(game: Node, from: Vector2i, to: Vector2i) -> void:
	game.is_dragging = true
	game.drag_start = from
	game.build_stroke.assign([from])
	game._finish_track_drag(to)
func _run() -> void:
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.paused = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.money = 10000
	game.inspection_button.button_pressed = true
	game.inspection_panel.plan_toggle.button_pressed = true
	var balance: int = game.money
	drag(game, Vector2i(40, 15), Vector2i(44, 15))
	drag(game, Vector2i(44, 15), Vector2i(48, 15))
	check(not game.tracks.has(Vector2i(40, 15)) and game.money == balance, "draft strokes must not change real tracks or money")
	check(game.construction_plan.quote().cost == 90, "shared endpoint must be charged once across multiple strokes")
	check(game._apply_draft() and game.tracks.has(Vector2i(48, 15)) and game.money == balance - 90, "apply must commit the entire valid plan")
	check(game.construction_undo.size() == 1, "whole plan must create one undo entry")
	game._undo_construction()
	check(not game.tracks.has(Vector2i(40, 15)) and game.money == balance, "undo must remove every stroke and restore money")
	game._redo_construction()
	check(game.tracks.has(Vector2i(48, 15)) and game.money == balance - 90, "redo must restore the whole plan")
	game.construction_plan.stage({Vector2i(45, 15): null}, game.tracks)
	game._discard_draft()
	check(game.tracks.has(Vector2i(45, 15)), "discarding draft demolition must leave live track in place")
	game.construction_plan.stage({Vector2i(50, 15): false}, game.tracks)
	game.money = 0
	check(not game._apply_draft() and not game.tracks.has(Vector2i(50, 15)) and not game.construction_plan.changes.is_empty(), "failed funding must keep whole draft without partial construction")
	game.money = 10000
	game.tracks[Vector2i(50, 15)] = true
	check(not game._apply_draft(), "a changed target must not be overwritten by applying a stale plan")
	game._discard_draft()
	for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	game.construction_plan.stage({Vector2i(4, 8): null, Vector2i(60, 15): false}, game.tracks)
	var before: Dictionary = game.tracks.duplicate()
	check(not game._apply_draft() and game.tracks == before, "protected platform must reject every edit in the transaction")
	game._discard_draft()
	game.route_distance = 32.0
	game._update_train_transform()
	game.construction_plan.stage({Vector2i(5, 8): null, Vector2i(60, 15): false}, game.tracks)
	check(not game._apply_draft() and game.tracks == before, "occupied/reserved tile must prevent all partial edits")
	game._discard_draft()
	game.track_signals[Vector2i(45, 15)] = "auto"
	game.construction_plan.stage({Vector2i(45, 15): null}, game.tracks)
	check(game._apply_draft() and not game.track_signals.has(Vector2i(45, 15)), "plan demolition must remove an attached signal")
	game._undo_construction()
	check(game.tracks.has(Vector2i(45, 15)) and game.track_signals.get(Vector2i(45, 15)) == "auto", "grouped undo must restore removed signal with its track")
	game._redo_construction()
	check(not game.track_signals.has(Vector2i(45, 15)), "grouped redo must remove the signal again")
	var position: Vector2 = game.train_position
	game.construction_plan.stage({Vector2i(18, 8): null}, game.tracks)
	check(game._apply_draft() and game.train_position == position and not game.route_connected, "applying a planned gap ahead must stop the train in place")
	game._undo_construction()
	check(game.route_connected and game.train_position == position, "undoing a planned gap must restore connectivity without teleportation")
	game._update_inspection()
	await process_frame
	check(game.inspection_panel.plan_controls.visible and game.inspection_panel.plan_summary.text.contains("Draft"), "draft cost and apply/discard controls must be visible in inspection")
	game.construction_plan.stage({Vector2i(60, 15): false}, game.tracks)
	game.inspection_panel.plan_toggle.button_pressed = false
	check(game.planning_mode and game.inspection_panel.plan_toggle.button_pressed, "leaving planning with uncommitted edits must keep the draft visible")
	game._save_game()
	check(game.notice.contains("draft before saving"), "save must not silently lose unapplied draft")
	game._discard_draft()
	game.inspection_panel.plan_toggle.button_pressed = false
	check(not game.planning_mode, "empty draft can leave planning mode")
	game.queue_free()
	await process_frame
	print("Planning integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
