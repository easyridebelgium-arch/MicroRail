extends SceneTree
const Terrain = preload("res://scripts/core/river_terrain.gd")
const Plan = preload("res://scripts/core/construction_plan.gd")
const Generator = preload("res://scripts/core/world_generator.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func clear(_cell: Vector2i) -> bool: return false
func run() -> void:
	var terrain := Terrain.new()
	terrain.profile = "river_v1"
	check(terrain.span(10) == [Vector2i(10, 16), Vector2i(10, 17), Vector2i(10, 18), Vector2i(10, 19)], "existing profile keeps exact geometry")
	for profile in ["wide_river_v1", "meander_v1"]:
		terrain.profile = profile
		var water_cells: Dictionary = {}
		for x in range(80):
			for y in terrain.water_rows(x): water_cells[Vector2i(x, y)] = true
		check(water_cells.size() == (240 if profile == "wide_river_v1" else 160), "profile has expected immutable water footprint")
		var first: Vector2i = water_cells.keys()[0]
		var reached := {first: true}
		var queue: Array = [first]
		var cursor := 0
		while cursor < queue.size():
			var current: Vector2i = queue[cursor]
			cursor += 1
			for delta in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if water_cells.has(current + delta) and not reached.has(current + delta):
					reached[current + delta] = true
					queue.append(current + delta)
		check(reached.size() == water_cells.size(), "river remains connected through every bend")
		for seed_text in ["0", "7", "42", "99999"]:
			var generated: Dictionary = Generator.generate(seed_text, 8)
			var dry := true
			for town in generated.world.settlements:
				for cell in Generator.tiles(Generator.town_bounds(Vector2i(town.cell[0], town.cell[1]))):
					if terrain.water(cell): dry = false
			check(dry, "existing city building plots remain dry across seeded layouts")
		var suggestion := terrain.suggest(Vector2i(40, 18), {}, {}, {}, clear)
		check(not suggestion.is_empty() and suggestion.cells == terrain.span(40), "nearest feasible crossing suggestion uses current profile")
		var plan := Plan.new()
		plan.terrain = terrain
		plan.stage(suggestion.changes, {})
		check(plan.quote().cost == suggestion.cost and suggestion.cost == (170 if profile == "wide_river_v1" else 120), "suggested span quote matches authoritative construction pricing")
		check(terrain.track_error(suggestion.changes).is_empty(), "suggested empty-land span passes terrain validation")
		var reused := terrain.suggest(Vector2i(40, 18), suggestion.changes, {}, {}, clear)
		check(reused.cost == 0 and reused.changes.is_empty(), "existing complete crossing can be reused without invented construction cost")
		var reserved := {suggestion.cells[0]: 1}
		var alternate := terrain.suggest(Vector2i(40, 18), {}, {}, reserved, clear)
		check(alternate.cells[0].x == 39, "reserved crossing skipped with deterministic west-first tie")
		var protected := func(cell: Vector2i) -> bool: return cell.x == 40
		check(terrain.suggest(Vector2i(40, 18), {}, {}, {}, protected).cells[0].x == 39, "protected bank is excluded from advice")
		var blocked := func(_cell: Vector2i) -> bool: return true
		check(terrain.suggest(Vector2i(40, 18), {}, {}, {}, blocked).is_empty(), "no feasible crossing yields no fabricated suggestion")
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	game.startup_city_seed = "42"
	game.startup_terrain = "meander_v1"
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	game.is_dragging = true
	game.drag_start = Vector2i(40, 18)
	game._refresh_build_plan(Vector2i(43, 18), true)
	check(not game.build_plan.get("bridge_suggestion", {}).is_empty() and game.build_plan.invalid.size() > 0, "invalid river stroke highlights a feasible full crossing")
	check(game.construction_hint.preview_text().contains("Suggested crossing"), "pointer hint explains suggested span and extra approaches")
	game.GameSettings.ui_scale = 2.0
	game._apply_settings()
	for frame in range(3):
		game.construction_hint.refresh_at(Vector2(300, 160), true)
		await process_frame
	check(game.get_viewport_rect().encloses(game.construction_hint.get_global_rect()), "crossing advice fits the scaled viewport after layout settles")
	game.GameSettings.ui_scale = 1.0
	game._apply_settings()
	game.is_dragging = false
	var quote: Dictionary = game.river_terrain.suggest(Vector2i(40, 18), game.tracks, {}, {}, game._plan_protected)
	var before := JSON.stringify(game._save_snapshot(), "", true, true)
	game.river_terrain.suggest(Vector2i(40, 18), game.tracks, {}, {}, game._plan_protected)
	check(before == JSON.stringify(game._save_snapshot(), "", true, true), "advice changes no saved simulation, RNG, cash or command state")
	var updates: Array = []
	for cell in quote.changes: updates.append([cell.x, cell.y, true])
	var cash: int = game.money
	game._execute_build({"cells": updates})
	check(game.money == cash - quote.cost and game.river_terrain.track_error(game.tracks).is_empty(), "meandering profile crossing builds at suggested cost")
	check(game._save_game(1) and game._load_slot(1) and game.river_terrain.profile == "meander_v1", "new profile and bridge survive save/load")
	var saved: Dictionary = game._save_snapshot()
	var old: Dictionary = saved.duplicate(true)
	old.version = 47
	old.terrain.profile = "river_v1"
	old.tracks = []
	var migrated: Dictionary = game.SaveMigrations.migrate(old).data
	check(migrated.version == 53 and migrated.terrain == old.terrain and migrated.sim == old.sim, "v47 migration preserves old profile and simulation exactly")
	game.is_dragging = true
	game.demolition_mode = true
	game.demolition_cells = {quote.cells[1]: true}
	check(game.construction_hint.preview_text().contains("INCOMPLETE SPAN") and game.construction_hint.preview_text().contains("Refund £25"), "demolition hint prices water refund and warns about partial span")
	game.queue_free()
	await process_frame
	print("River variety and advice: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
