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
	game.blueprints.clear()
	for suffix in ["", ".backup", ".tmp"]:
		if FileAccess.file_exists(game.BLUEPRINT_PATH + suffix): DirAccess.remove_absolute(game.BLUEPRINT_PATH + suffix)
	game._load_blueprints()
	game.inspection_button.button_pressed = true
	game.inspection_panel.plan_toggle.button_pressed = true
	for x in range(40, 46): game.tracks[Vector2i(x, 15)] = false
	game.tracks[Vector2i(42, 15)] = "junction_6_2_4"
	game.track_signals[Vector2i(44, 15)] = "auto"
	game.corridor_pick = 3
	game._pick_corridor_cell(Vector2i(40, 14))
	game.corridor_pick = 4
	game._pick_corridor_cell(Vector2i(45, 16))
	check(game.blueprint_first == Vector2i(40, 14) and game.blueprint_last == Vector2i(45, 16), "capture corners must permit empty map cells")
	game.inspection_panel.blueprint_name.text = "Passing-loop junction"
	check(game._save_blueprint() and game.blueprints.size() == 1, "saving must populate the local design browser")
	check(not game._save_blueprint() and game.blueprints.size() == 1, "duplicate names must not overwrite a saved design")
	game.blueprints.clear()
	game._load_blueprints()
	check(game.blueprints.size() == 1 and game.inspection_panel.selected_blueprint() == "Passing-loop junction", "library must persist independently of game saves")
	game.inspection_panel.blueprint_search.text = "not found"
	game._update_inspection()
	check(game.inspection_panel.selected_blueprint().is_empty(), "search must filter unrelated designs")
	game.inspection_panel.blueprint_search.text = "JUNCTION"
	game._update_inspection()
	check(not game.inspection_panel.selected_blueprint().is_empty(), "search must be case insensitive")
	var balance: int = game.money
	check(game._place_blueprint(Vector2i(50, 20)) and not game.tracks.has(Vector2i(50, 21)) and game.money == balance, "placement must only stage changes without building or spending")
	var changes: int = game.construction_plan.changes.size()
	check(not game._place_blueprint(Vector2i(79, 20)) and game.construction_plan.changes.size() == changes, "failed placement must not partially alter the draft")
	game._update_inspection()
	check(game.construction_plan.quote().net == 160, "draft must include normal track and switch prices")
	check(game._apply_draft() and game.tracks.get(Vector2i(52, 21)) == "junction_6_2_4" and game.track_signals.get(Vector2i(54, 21)) == "auto" and game.money == balance - 160, "apply must commit translated switch, signals and full price")
	game._undo_construction()
	check(not game.tracks.has(Vector2i(50, 21)) and not game.track_signals.has(Vector2i(54, 21)) and game.money == balance, "one undo must remove entire blueprint and refund its price")
	game._redo_construction()
	check(game.tracks.has(Vector2i(50, 21)) and game.track_signals.has(Vector2i(54, 21)) and game.money == balance - 160, "one redo must restore geometry and signals")
	check(game._place_blueprint(Vector2i(50, 20)) and game.construction_plan.is_empty(), "stamping an identical layout must be an idempotent no-op")
	game._save_game()
	game.blueprints.clear()
	game._load_game()
	game._load_blueprints()
	check(game.blueprints.size() == 1 and game.track_signals.has(Vector2i(54, 21)), "game reload must preserve applied geometry and independent library")
	check(game._export_blueprint("user://exported-design.json"), "selected design must export to a versioned local JSON file")
	check(not game._export_blueprint(game.BLUEPRINT_PATH) and game.blueprints.size() == 1, "export must not replace the active library with a subset")
	check(not game._import_blueprints("user://exported-design.json") and game.blueprints.size() == 1, "duplicate import must preserve existing library")
	var imported: Dictionary = game.blueprints[0].duplicate(true)
	imported.name = "Imported junction"
	game.TrackBlueprints.save_library("user://imported-design.json", [imported])
	check(game._import_blueprints("user://imported-design.json") and game.blueprints.size() == 2, "import must merge uniquely named validated designs")
	var mixed: Array = [imported.duplicate(true), game.blueprints[0]]
	mixed[0].name = "Would be new"
	game.TrackBlueprints.save_library("user://mixed-designs.json", mixed)
	check(not game._import_blueprints("user://mixed-designs.json") and game.blueprints.size() == 2, "a collision later in a multi-design import must prevent every partial update")
	game.inspection_panel.plan_toggle.button_pressed = true
	game.inspection_panel.blueprint_rotation.select(1)
	game.inspection_panel.blueprint_mirror.button_pressed = true
	var source: Dictionary = game.blueprints[0].duplicate(true)
	var cash_before: int = game.money
	check(game._place_blueprint(Vector2i(60, 30)) and game.money == cash_before and game.blueprints[0] == source, "UI transform drafts a copy without spending or changing the source")
	game._update_inspection()
	check(game.inspection_panel.plan_summary.text.contains("Switches £100") and game.inspection_panel.plan_summary.text.contains("signal edits: £0"), "plan panel shows itemised costs")
	check(game._apply_draft(), "rotated mirrored blueprint applies through normal atomic validation")
	game._undo_construction()
	check(game.money == cash_before, "transformed placement undoes as one fully refunded action")
	var file := FileAccess.open(game.BLUEPRINT_PATH, FileAccess.WRITE)
	file.store_string('{"version":"invalid","designs":[]}')
	file.close()
	game._load_blueprints()
	check(not game.blueprint_library_error.is_empty() and not game._save_blueprint(), "malformed library must be reported and must not be overwritten by saving")
	game.queue_free()
	await process_frame
	print("Blueprint integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
