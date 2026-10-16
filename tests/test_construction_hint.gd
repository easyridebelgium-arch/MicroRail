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
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	var hint = game.construction_hint
	var tick_before: int = game.sim_clock.tick
	var money_before: int = game.money
	var tracks_before: Dictionary = game.tracks.duplicate(true)
	var owners_before: Dictionary = game.reservations.owners.duplicate()
	var events_before: Dictionary = game.event_log.save_state()
	check(hint.mouse_filter == Control.MOUSE_FILTER_IGNORE and hint.message.mouse_filter == Control.MOUSE_FILTER_IGNORE and hint.focus_mode == Control.FOCUS_NONE, "hint cannot capture clicks or keyboard focus")
	game.is_dragging = true
	game.build_plan = {"new_count": 2, "switch_count": 1, "error": ""}
	game.construction_feedback = {"affected": [{"id": 1}], "blocked": {}}
	hint.refresh_at(Vector2(600, 400), true)
	check(hint.visible and hint.message.text.contains("BUILD — £120") and hint.message.text.contains("switches 1 × £100"), "preview prices include automatically created switches")
	check(hint.message.text.contains("affects 1 services"), "service impact remains available beside the cursor")
	game.money = 50
	check(hint.preview_text().contains("INSUFFICIENT CASH") and hint.preview_text().contains("need £70 more"), "unaffordable build explains shortfall")
	game.money = money_before
	game.construction_feedback.blocked = {Vector2i(4, 8): 1}
	check(hint.preview_text().contains("RESERVED TRACK") and not hint.preview_text().contains("✓"), "reserved edits cannot show a valid build checkmark")
	game.build_plan.error = "Remove the signal before adding a switch on its tile."
	check(hint.preview_text().contains("CANNOT BUILD") and hint.preview_text().contains("Remove the signal"), "exact geometric rejection remains visible")
	game.build_plan.error = ""
	game.planning_mode = true
	game.money = 0
	check(hint.preview_text().contains("DRAFT") and hint.preview_text().contains("full draft price/validation") and not hint.preview_text().contains("INSUFFICIENT CASH"), "draft stroke cannot misrepresent full-plan affordability")
	game.demolition_mode = true
	game.demolition_cells = {Vector2i(5, 8): true, Vector2i(6, 8): true}
	check(hint.preview_text().contains("Refund £10 at Apply plan"), "draft removal explains deferred refund")
	game.planning_mode = false
	check(hint.preview_text().contains("PARTIAL") and hint.preview_text().contains("skipped; other tiles can be removed"), "removal excludes protected tiles without falsely blocking all removal")
	game.demolition_mode = false
	game.money = money_before
	game.construction_feedback = {"affected": [], "blocked": {}}
	var original_scale: float = Settings.ui_scale
	for scale_value in [1.0, 1.5, 2.0]:
		Settings.ui_scale = scale_value
		game._apply_settings()
		await process_frame
		for corner in [Vector2(0, 0), game.get_viewport_rect().size - Vector2.ONE, Vector2(game.get_viewport_rect().size.x - 1, 0)]:
			hint.refresh_at(corner, true)
			await process_frame
			check(game.get_viewport_rect().encloses(hint.get_global_rect()), "hint remains on-screen at every tested corner/scale")
	hint.refresh_at(Vector2.ZERO, false)
	check(not hint.visible, "toolbar/dialog hover suppresses hint")
	game.is_dragging = false
	hint.refresh_at(Vector2.ZERO, true)
	check(not hint.visible, "ending or cancelling a gesture clears hint")
	check(game.tracks == tracks_before and game.reservations.owners == owners_before and game.money == money_before and game.sim_clock.tick == tick_before and game.event_log.save_state() == events_before, "preview never mutates tracks, authority, money, clock or events")
	var original_keys: Dictionary = Settings.key_bindings.duplicate(true)
	var original_mouse: Dictionary = Settings.mouse_bindings.duplicate(true)
	Settings.key_bindings = {str(game.InputActions.SELECT_REMOVE): [KEY_T]}
	Settings.mouse_bindings = {str(game.InputActions.BUILD): [MOUSE_BUTTON_XBUTTON1]}
	game._apply_settings()
	check(game.remove_button.tooltip_text.contains("Shortcut: T"), "Remove tooltip follows remapped key")
	check(game.straight_button.tooltip_text.contains(game.InputActions.mouse_label(game.InputActions.BUILD)) and game.instructions.tooltip_text.contains(game.InputActions.mouse_label(game.InputActions.BUILD)), "tool and status hints follow remapped mouse controls")
	check(game.signal_button.tooltip_text.contains("does not release automatically") and game.waypoint_button.tooltip_text.contains("not passenger stops"), "tooltips explain operational differences")
	check(game.load_button.tooltip_text.contains("four saved games") and game.save_button.tooltip_text.contains("four save slots"), "save controls describe slot behaviour")
	Settings.key_bindings = original_keys
	Settings.mouse_bindings = original_mouse
	Settings.ui_scale = original_scale
	game._apply_settings()
	game.queue_free()
	await process_frame
	print("Construction hint: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
