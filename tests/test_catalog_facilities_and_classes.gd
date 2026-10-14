extends SceneTree
const World = preload("res://scripts/core/world_catalog.gd")
const Classes = preload("res://scripts/core/passenger_classes.gd")
const Demand = preload("res://scripts/core/passenger_demand.gd")
const Rng = preload("res://scripts/core/sim_rng.gd")
const Ledger = preload("res://scripts/core/journey_ledger.gd")
const Mill = preload("res://scripts/core/sawmill.gd")
const Factory = preload("res://scripts/core/factory.gd")
const Freight = preload("res://scripts/freight_train.gd")
const Runtime = preload("res://scripts/core/runtime_routes.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var catalog := {"west": {"name": "West", "cell": Vector2i(2, 12)}, "middle": {"name": "Middle", "cell": Vector2i(20, 12)}, "east": {"name": "East", "cell": Vector2i(40, 12)}}
	check(Classes.distant("west", "east", catalog) and not Classes.distant("west", "middle", catalog), "Express distance uses actual station cells")
	check(Classes.distant("a", "c") and not Classes.distant("a", "b"), "tutorial class policy is preserved")
	var edge := catalog.duplicate(true)
	edge.east.cell = Vector2i(34, 12)
	check(Classes.distant("west", "east", edge), "32-tile boundary qualifies")
	edge.east.cell = Vector2i(33, 12)
	check(not Classes.distant("west", "east", edge), "31-tile distance stays Local")
	edge.east.cell = Vector2i(25, 35)
	check(Classes.distant("west", "east", edge), "diagonal straight-line distance qualifies")
	edge.east.cell = Vector2i(22, 32)
	check(not Classes.distant("west", "east", edge), "long Manhattan distance alone does not qualify")
	check(not Classes.distant("missing", "east", catalog) and not Classes.distant("west", "west", catalog), "unknown and self trips never qualify")
	check(Classes.direct("west", ["east"], catalog) == ["east"] and Classes.direct("west", ["middle", "east"], catalog).is_empty(), "Express requires direct next scheduled stop")
	var row := {"origin": "west", "destination": "east", "known": true, "class": "express", "count": 1, "start": 0}
	check(Classes.valid(row, catalog) and not Classes.valid(row), "Express row validation uses supplied geometry")
	check(Classes.eligible(row, ["east"], ["east"], catalog) and not Classes.eligible(row, ["east"], [], catalog), "Express cannot board stopping or transfer departure")
	var demand := Demand.new(catalog.keys(), catalog)
	for id in demand.station_ids: demand.reset_total(id, 0)
	var rng := Rng.new(73)
	demand.generate("west", 80, 100, rng, 60, true)
	var distant := 0
	var express := 0
	for group in demand.batches.west:
		if group.destination == "east": distant += int(group.count)
		if group.get("class") == "express": express += int(group.count)
	check(distant > 0 and express == int(distant / 4.0) and demand.class_progress.west == distant % 4, "one in four accepted distant arrivals becomes Express without A/C IDs")
	check(Classes.valid_progress(demand.class_progress, catalog) and not demand.class_progress.has("a") and not demand.class_progress.has("middle"), "only eligible origins own generation counters")
	var saved: Dictionary = demand.save_state({}, 60)
	check(Demand.valid_state(saved, {"passengers_on_train": 0}, {}, 60, demand.station_ids, catalog), "custom Express queues and batches validate")
	var restored := Demand.new()
	restored.restore_state(JSON.parse_string(JSON.stringify(saved)), demand.station_ids, catalog)
	check(restored.save_state({}, 60) == saved and Classes.valid_progress(restored.class_progress, catalog), "Express progress and batches survive JSON restore")
	var rng_before: Dictionary = rng.save_state()
	var progress_before: Dictionary = demand.class_progress.duplicate()
	demand.generate("west", 10, demand.waiting("west"), rng, 120, true)
	check(rng.save_state() == rng_before and demand.class_progress == progress_before, "full queue consumes neither RNG nor class progress")
	var journey := row.duplicate(true)
	journey["end"] = 120
	journey.erase("known")
	check(Ledger.valid_row(journey, 120, true, demand.station_ids, catalog) and not Ledger.valid_row(journey, 120, true, demand.station_ids), "history validates custom Express geometry")
	var world := World.new()
	var shifted: Dictionary = world.save_state()
	for facility in shifted.facilities:
		if facility.kind != "station": facility.cell = [int(facility.cell[0]) + 5, 30]
	world.restore_state(shifted)
	check(World.valid(shifted) and world.cell("industry:forest") == Vector2i(13, 30) and world.cell("missing") == Vector2i(-1, -1), "catalog supplies moved industry cells and unknown sentinel")
	var positions: Dictionary = world.industry_positions()
	check(positions.sawmill == Vector2i(23, 30) and positions.factory == Vector2i(28, 30), "inactive processor sites retain proposed positions")
	var mill := Mill.new()
	mill.state.installed = true
	var factory := Factory.new()
	factory.state.installed = true
	var train := Freight.new()
	root.add_child(train)
	var cells: Array[Vector2i] = []
	for x in range(13, 34): cells.append(Vector2i(x, 30))
	train.configure_industry(mill, 32.0, factory, positions)
	train.set_route(cells, 32.0)
	check(train.sawmill_cell == positions.sawmill and train.factory_cell == positions.factory and train.sawmill_distance > 0, "route refresh retains moved loading positions")
	var paid := [0]
	train.delivered.connect(func(amount: int) -> void:
		paid[0] += amount
		factory.state.sold += amount)
	var logs := 20
	for i in range(3000):
		mill.tick()
		factory.tick()
		logs -= train.advance(1.0 / 60.0, logs)
		if train.chain_stage == 2 and train.cargo > 0 and train.distance_along_route > train.factory_distance + 16: break
	var before: Vector2 = train.position
	train.recovery_stop = train.leg_origin
	train.recovery_returning = true
	train.to_terminal = false
	check(train.position == before and train.target_distance() == train.factory_distance and paid[0] == 0, "reversal targets shifted factory without teleport or payment")
	check(Freight.valid_chain(train.save_state(), cells, true, true, 32.0, true, positions), "shifted recovery stage validates against its own geometry")
	for i in range(100):
		train.advance(1.0 / 60.0, 0)
		if not train.recovery_returning: break
	check(train.held and train.cargo == 1 and train.distance_along_route == train.factory_distance and paid[0] == 0, "physical recovery retains goods at moved factory")
	train.held = false
	train.service_enabled = true
	for i in range(500):
		train.advance(1.0 / 60.0, 0)
		if paid[0] > 0: break
	check(paid[0] == 1 and mill.state.received == 20 and factory.state.received == 1 and train.distance_along_route == train.route_path.get_baked_length(), "moved physical chain completes without old stop coordinates")
	var data := {"sawmill": mill.save_state(), "factory": factory.save_state(), "freight": train.save_state(), "runtime": {"freight_cells": Runtime.encode(cells)}, "services": {"freight": {"waypoints": {"forest>terminal": [[23, 30], [28, 30]]}}}, "tracks": []}
	for cell in cells: data.tracks.append([cell.x, cell.y, false])
	check(Mill.valid_game(data, positions) and Factory.valid_game(data, positions) and Freight.valid_chain(data.freight, cells, true, false, 32.0, true, positions), "stock and physical stage validate moved stops")
	check(not Mill.valid_game(data) and not Factory.valid_game(data), "moved chain cannot validate with tutorial coordinates")
	train.queue_free()
	await process_frame
	print("Catalog facilities/classes: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
