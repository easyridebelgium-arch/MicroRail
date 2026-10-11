extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.paused = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for x in range(40, 61): game.tracks[Vector2i(x, 15)] = false
	game.inspection_button.button_pressed = true
	game.inspection_panel.plan_toggle.button_pressed = true
	game.corridor_pick = 1
	game._pick_corridor_cell(Vector2i(40, 15))
	game.corridor_pick = 2
	game._pick_corridor_cell(Vector2i(60, 15))
	check(game.corridor_cells.size() == 21, "UI endpoint picking must select the connected route")
	check(game._draft_corridor_signals() and game.track_signals.is_empty(), "batch preview must leave actual signal network unchanged")
	var balance: int = game.money
	check(game._apply_draft() and game.track_signals.size() == 5 and game.money == balance, "batch apply must commit all prototype signals without charge")
	check(game.construction_undo.size() == 1, "signal batch must have a single undo entry")
	game._undo_construction()
	check(game.track_signals.is_empty(), "undo must remove all batch signals together")
	game._redo_construction()
	check(game.track_signals.size() == 5, "redo must restore every signal")
	game.track_signals[Vector2i(45, 15)] = "stop"
	game._undo_construction()
	check(game.track_signals.size() == 5, "undo must not overwrite a subsequent individual signal edit")
	game.track_signals[Vector2i(45, 15)] = "auto"
	game.inspection_panel.corridor_mode.select(2)
	check(game._draft_corridor_signals() and game._apply_draft() and game.track_signals.is_empty(), "remove mode must remove every signal in selected corridor")
	game._undo_construction()
	check(game.track_signals.size() == 5, "undo must restore the whole removed signal batch")
	game._discard_draft()
	game._use_signal_tool(Vector2i(42, 15))
	check(game.construction_plan.signal_changes.get(Vector2i(42, 15)) == "auto" and not game.track_signals.has(Vector2i(42, 15)), "point signal tool must stage while planning")
	check(game._apply_draft(), "point signal draft should commit through shared validation")
	game._save_game()
	game.track_signals.clear()
	game._load_game()
	check(game.track_signals.size() == 6 and not game.planning_mode, "save/load must preserve applied signal batches and clear ephemeral planning")
	game.queue_free()
	await process_frame
	print("Corridor integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
