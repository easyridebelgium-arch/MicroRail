extends SceneTree
const Terrain = preload("res://scripts/core/river_terrain.gd")
const Plan = preload("res://scripts/core/construction_plan.gd")
const Config = preload("res://scripts/core/new_game_config.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280, 720)
	var terrain := Terrain.new()
	terrain.profile = "river_v1"
	var span := {Vector2i(10, 16): true, Vector2i(10, 17): true, Vector2i(10, 18): true, Vector2i(10, 19): true}
	check(terrain.track_error(span).is_empty(), "complete straight bank-to-bank span is valid")
	for bad in [{Vector2i(10, 17): true}, {Vector2i(10, 17): false}, {Vector2i(10, 17): "NE"}]: check(not terrain.track_error(bad).is_empty(), "partial or angled water rails rejected")
	check(not terrain.proposed_error(span, {Vector2i(10, 17): null}).is_empty(), "one missing deck tile invalidates span atomically")
	check(not terrain.proposed_error(span, {Vector2i(10, 16): null}).is_empty(), "bank cannot be removed under surviving bridge")
	check(not terrain.site_error([Vector2i(10, 16)], span).is_empty(), "station cannot replace an existing bridge bank")
	check(not terrain.track_error(span, {Vector2i(10, 17): "auto"}).is_empty(), "signals belong on dry banks")
	var plan := Plan.new()
	plan.terrain = terrain
	plan.stage(span, {})
	check(plan.quote().net == 120, "two bridge tiles plus dry banks quote £120")
	check(plan.validate({}, {}, {}, Vector2i(80, 50), func(_cell: Vector2i) -> bool: return false, 119).contains("Insufficient"), "bridge surcharge is enforced during affordability validation")
	check(Config.validate({"mode": "cities", "seed": "42", "city_count": 4, "terrain": "river_v1"}).ok, "ordinary city chooser accepts river profile")
	check(not Config.validate({"mode": "cities", "seed": "42", "city_count": 3, "challenge": "first_connection", "terrain": "river_v1"}).ok, "existing scenarios retain flat rules")
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	game.startup_city_seed = "42"
	game.startup_terrain = "river_v1"
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	check(game.river_terrain.water(Vector2i(10, 17)) and game.tracks.is_empty(), "river starts without phantom track")
	var before: int = game.money
	game._execute_build({"cells": [[10, 17, true]]})
	check(game.tracks.is_empty() and game.money == before, "partial bridge command changes no track or money")
	game._execute_build({"cells": [[10, 16, true], [10, 17, true], [10, 18, true], [10, 19, true]]})
	check(game.tracks.size() == 4 and game.money == before - 120, "live span builds with actual surcharge")
	check(game.RailRouter.find_route(game.tracks, Vector2i(10, 16), Vector2i(10, 19)).size() == 4, "normal authoritative graph routes across completed bridge")
	game._execute_set_tile({"x": 10, "y": 17, "tile": "junction_0_4_2"})
	check(game.tracks[Vector2i(10, 17)] == true, "switch editing cannot corrupt bridge geometry")
	game._execute_set_signal({"x": 10, "y": 17, "mode": "auto"})
	check(game.track_signals.is_empty(), "direct signal command cannot bypass river rule")
	game._execute_demolish({"cells": [[10, 17]]})
	check(game.tracks.size() == 4 and game.money == before - 120, "partial span removal refuses without charging or refund")
	game._execute_demolish({"cells": [[10, 17], [10, 18]]})
	check(game.tracks.size() == 2 and game.money == before - 70, "whole deck removal refunds £25 per water tile")
	game._undo_construction()
	check(game.tracks.size() == 4 and game.money == before - 120, "undo restores complete bridge and exact cash")
	game._redo_construction()
	check(game.tracks.size() == 2 and game.money == before - 70, "redo removes complete span with exact refund")
	game._undo_construction()
	check(game._save_game(1), "river company saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(1)))
	check(saved.version == 50 and game._is_valid_save(saved), "version 50 validates bridge topology")
	check(game._load_slot(1) and game.river_terrain.profile == "river_v1" and game.tracks.size() == 4, "load restores terrain and exact bridge graph")
	var bad: Dictionary = saved.duplicate(true)
	bad.tracks = bad.tracks.filter(func(row: Array) -> bool: return not (row[0] == 10 and row[1] == 17))
	check(not game._is_valid_save(bad), "broken bridge save rejected")
	var old: Dictionary = saved.duplicate(true)
	old.version = 46
	old.erase("terrain")
	var migrated: Dictionary = game.SaveMigrations.migrate(old).data
	check(migrated.terrain.profile == "flat" and migrated.tracks == old.tracks and migrated.sim == old.sim, "old saves gain no water and preserve graph/RNG")
	check(not game.river_terrain.site_error([Vector2i(10, 17)]).is_empty(), "station footprint cannot include water")
	# Construct a real station route with a perpendicular river crossing.
	game._execute_demolish({"cells": [[10, 17], [10, 18], [10, 16], [10, 19]]})
	var candidates: Array = game.CityBuildTool.Generator.planning(game.world.save_state()).station_candidates
	var north := Vector2i.ZERO
	var south := Vector2i.ZERO
	for row in candidates:
		var point := Vector2i(row.cell[0], row.cell[1])
		if point.y < 16: north = point
		if point.y > 19: south = point
	check(north != Vector2i.ZERO and south != Vector2i.ZERO, "river seed has playable cities on both banks")
	game.city_builder.submit(north)
	game.city_builder.submit(south)
	var cells: Array[Vector2i] = [north]
	var cursor := north
	while cursor.x != 40:
		cursor.x += 1 if cursor.x < 40 else -1
		cells.append(cursor)
	while cursor.y != south.y:
		cursor.y += 1
		cells.append(cursor)
	while cursor.x != south.x:
		cursor.x += 1 if cursor.x < south.x else -1
		cells.append(cursor)
	var proposal: Dictionary = game.TrackBuilder.plan(cells, game.tracks, Vector2i(80, 50), game._is_station_space, game.facility_cells())
	check(str(proposal.get("error", "")).is_empty(), "normal track builder designs bank-to-bank passenger route")
	var updates: Array = []
	for cell in proposal.changes: updates.append([cell.x, cell.y, proposal.changes[cell]])
	game._execute_build({"cells": updates})
	var purchase: Dictionary = game.buy_fleet_train("passenger_standard")
	check(purchase.ok and game.start_passenger_service(purchase.id, game.world.station_key(north), game.world.station_key(south)).contains("started"), "real service routes over complete span")
	var service_key: String = game.Fleet.find(game.fleet, purchase.id).service
	var crossed := false
	var protected_span := false
	for tick in range(3000):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
		var position: Vector2 = game.passenger_services[service_key].position
		if not protected_span and position.y > 17 * 32 and position.y < 19 * 32:
			var count_before: int = game.tracks.size()
			var cash_before: int = game.money
			game._execute_demolish({"cells": [[40, 17], [40, 18]]})
			protected_span = game.tracks.size() == count_before and game.money == cash_before
		if position.y > 20 * 32:
			crossed = true
			break
	check(crossed and protected_span, "moving train crosses while reservation checks prevent demolition beneath it")
	check(game._save_game(2) and game._load_slot(2), "moving cross-bank service survives real save/load")
	game.queue_free()
	await process_frame
	print("River bridges: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
