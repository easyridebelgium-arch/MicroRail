extends SceneTree
const Terrain = preload("res://scripts/core/river_terrain.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var terrain := Terrain.new()
	check(terrain.inspect_span(Vector2i(10, 17), {}).is_empty(), "flat land has no bridge report")
	for profile in ["river_v1", "wide_river_v1", "meander_v1"]:
		terrain.profile = profile
		var cells := terrain.span(10)
		var report := terrain.inspect_span(cells[1], {})
		var water_count := terrain.water_rows(10).size()
		check(not report.complete and report.missing.size() == cells.size(), "empty crossing is not a complete bridge")
		check(report.full_cost == 20 + water_count * 50 and report.missing_cost == report.full_cost, "span price includes rails, banks and surcharge")
		var tracks: Dictionary = {}
		for point in cells: tracks[point] = true
		report = terrain.inspect_span(cells[0], tracks, {cells[0]: 7, cells[1]: 7, cells.back(): 2})
		check(report.complete and report.missing_cost == 0 and report.deck_refund == water_count * 25, "complete span reports current deck value")
		check(report.holders == [2, 7], "tile holders are unique and deterministically sorted")
		tracks[cells[0]] = false
		check(terrain.inspect_span(cells[0], tracks).incompatible == [cells[0]], "horizontal bank is explicitly incompatible")
		check(terrain.inspect_span(Vector2i(10, 1), tracks).is_empty(), "ordinary land cannot open a span")
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	game.startup_city_seed = "42"
	game.startup_terrain = "river_v1"
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	var before: String = JSON.stringify(game._save_snapshot(), "", true, true)
	check(game.bridge_inspector.open_at(Vector2i(10, 17)) and game._modal_open(), "Inspect opens an actual modal for an empty crossing")
	check(game.bridge_inspector.detail.text.contains("£120") and game.bridge_inspector.detail.text.contains("Missing:"), "dialog explains complete price and missing coordinates")
	check(JSON.stringify(game._save_snapshot(), "", true, true) == before, "inspection does not mutate company snapshot")
	game.bridge_inspector.close()
	game.paused = false
	check(game.bridge_inspector.open_at(Vector2i(10, 16)) and game.paused, "opening a dry bank pauses a running game")
	game.bridge_inspector.dialog.canceled.emit()
	check(not game.paused and not game.bridge_inspector.dialog.visible, "cancel restores previous running state")
	game.paused = true
	game._execute_build({"cells": [[10, 16, true], [10, 17, true], [10, 18, true], [10, 19, true]]})
	game.reservations.owners[Vector2i(10, 17)] = 9
	game.bridge_inspector.open_at(Vector2i(10, 17))
	check(game.bridge_inspector.detail.text.contains("Complete straight bridge") and game.bridge_inspector.detail.text.contains("[9]"), "built span displays actual tile claims")
	game.reservations.owners.clear()
	check(game._save_game(3) and game._load_slot(3) and not game.bridge_inspector.dialog.visible, "loading clears the stale paused inspection snapshot")
	game.is_dragging = true
	game.build_plan = {"new_count": 4, "switch_count": 0, "changes": {Vector2i(20, 17): true, Vector2i(20, 18): true}, "error": ""}
	check(game.construction_hint.preview_text().contains("Water rail subtotal £100"), "construction hint explains total water rail price including base rail")
	game.is_dragging = false
	game.queue_free()
	await process_frame
	print("Bridge inspector: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
