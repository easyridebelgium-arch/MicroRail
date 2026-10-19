extends RefCounted
## Fixed teaching layout; structure is cached, progress reads actual service receipts.
const Generator = preload("res://scripts/core/world_generator.gd")
const World = preload("res://scripts/core/world_catalog.gd")
const Start = preload("res://scripts/core/sandbox_start.gd")
const Stations = preload("res://scripts/core/station_construction.gd")
const Plan = preload("res://scripts/core/construction_plan.gd")
const Blueprints = preload("res://scripts/core/track_blueprints.gd")
const Template = preload("res://scripts/core/passing_loop_template.gd")
const Fit = preload("res://scripts/core/passing_loop_fit.gd")
const Blocks = preload("res://scripts/core/passing_loop_blocks.gd")
const Services = preload("res://scripts/service_routes.gd")
const Fleet = preload("res://scripts/fleet.gd")
const Numbers = preload("res://scripts/core/arrival_targets.gd")
const LEFT := Vector2i(30, 14)
const RIGHT := Vector2i(66, 14)
const ANCHOR := Vector2i(44, 14)
const VIA := Vector2i(48, 17)
const LEFT_ID := "city_03"
const RIGHT_ID := "city_02"
const TARGET := 10
var source: Array = []
var structure: Dictionary = {}

func inspect(world: Dictionary, tracks: Dictionary, signs: Dictionary, services: Dictionary, fleet: Dictionary, performance: Dictionary) -> Dictionary:
	var key: Array = [world.hash(), tracks.hash(), signs.hash(), services.hash(), fleet.hash()]
	if key != source:
		source = key
		structure = _structure(world, tracks, signs, services, fleet)
	var result := structure.duplicate(true)
	for kind in ["direct", "bypass"]:
		result[kind] = ""
		result[kind + "_finals"] = 0
		for candidate in result[kind + "_keys"]:
			var finals: int = int(performance.get("services", {}).get(candidate, {}).get("finals", 0))
			if result[kind] == "" or finals > result[kind + "_finals"]:
				result[kind] = candidate
				result[kind + "_finals"] = finals
	result.ready = result.stations and result.connected and result.loop and result.boundaries and result.opposing and result.direct != "" and result.bypass != ""
	return result

static func _structure(world: Dictionary, tracks: Dictionary, signs: Dictionary, services: Dictionary, fleet: Dictionary) -> Dictionary:
	var catalog := World.new()
	catalog.restore_state(world)
	var stations := catalog.stations()
	var result := {"stations": stations.has(LEFT_ID) and stations.has(RIGHT_ID) and stations[LEFT_ID].cell == LEFT and stations[RIGHT_ID].cell == RIGHT, "connected": false, "loop": false, "boundaries": false, "opposing": false, "owns_two": false, "direct_keys": [], "bypass_keys": []}
	var count := 0
	for train in fleet.trains:
		if Fleet.MODELS[train.model].kind == "passenger": count += 1
	result.owns_two = count >= 2
	result.loop = Fit.layout_error(ANCHOR, 9, 0, tracks, signs).is_empty()
	if result.loop:
		var blocks := Blocks.inspect(ANCHOR, 9, 0, tracks, signs)
		result.boundaries = blocks.ok and blocks.issues.is_empty()
	if not result.stations: return result
	var direct_started := false
	var reverse_started := false
	var keys: Array = services.keys()
	keys.sort()
	for key in keys:
		if not Services.is_passenger_key(key) or Fleet.assigned(fleet, key).is_empty(): continue
		var row: Dictionary = services[key]
		if row.get("mode", "shuttle") != "shuttle": continue
		var forward: bool = row.stops == [LEFT_ID, RIGHT_ID]
		var reverse: bool = row.stops == [RIGHT_ID, LEFT_ID]
		if not forward and not reverse: continue
		var built := Services.build(tracks, row.stops, 32, row.get("waypoints", {}), "shuttle", row.get("platforms", {}), stations)
		if built.cells.is_empty(): continue
		result.connected = true
		if forward: direct_started = true
		if reverse: reverse_started = true
		if forward and built.cells.has(Vector2i(48, 14)) and not built.cells.has(VIA): result.direct_keys.append(key)
		if reverse and built.cells.has(VIA) and not built.cells.has(Vector2i(48, 14)) and row.get("waypoints", {}).get(RIGHT_ID + ">" + LEFT_ID, []).has([VIA.x, VIA.y]): result.bypass_keys.append(key)
	result.opposing = direct_started and reverse_started
	# Track may already be connected before either service is purchased.
	if not result.connected: result.connected = not preload("res://scripts/waypoint_router.gd").find_route(tracks, LEFT, RIGHT, []).is_empty()
	return result

static func evidence_valid(value: Variant, completed: int, total: int) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return completed < 0
	if value.size() != 6 or not Services.is_passenger_key(value.get("direct")) or not Services.is_passenger_key(value.get("bypass")) or value.direct == value.bypass: return false
	var counted := 0
	for field in ["direct_baseline", "bypass_baseline", "direct_finals", "bypass_finals"]:
		if not Numbers.whole(value.get(field), 0, total): return false
		counted += int(value[field])
	if counted > total: return false
	var met: bool = int(value.direct_finals) >= TARGET and int(value.bypass_finals) >= TARGET
	return met if completed >= 0 else not met

static func quote() -> Dictionary:
	var start := Start.new()
	if not start.initialize("4", 3).ok: return {"ok": false}
	for cell in [LEFT, RIGHT]:
		var draft := start.station_draft(cell)
		if not draft.ok or not start.commit_station(draft, {}, {}).ok: return {"ok": false}
	var protected: Dictionary = {}
	for town in start.world.state.settlements:
		for cell in Generator.tiles(Generator.town_bounds(Vector2i(town.cell[0], town.cell[1]))): protected[cell] = true
	for site in start.world.state.facilities:
		var cell := Vector2i(site.cell[0], site.cell[1])
		for building in Stations.building_cells(cell): protected[building] = true
		if site.kind == "station":
			for platform in Stations.platform_cells(cell): protected[platform] = true
		else: protected[cell] = true
	var guard := func(cell: Vector2i) -> bool: return protected.has(cell)
	var plan := Plan.new()
	var updates: Dictionary = {}
	for x in range(LEFT.x + 3, RIGHT.x - 2): updates[Vector2i(x, LEFT.y)] = false
	plan.stage(updates, start.tracks)
	var loop := Blueprints.place(Template.design(), ANCHOR, plan.projected(start.tracks), {}, Generator.MAP_SIZE, guard)
	if not loop.error.is_empty(): return {"ok": false}
	plan.stage(loop.tracks, start.tracks)
	plan.stage_signals(loop.signals, {}, start.tracks)
	var trains: int = 2 * int(Fleet.MODELS.passenger_standard.price)
	if not plan.validate(start.tracks, {}, {}, Generator.MAP_SIZE, guard, start.money - trains).is_empty(): return {"ok": false}
	var projected := plan.projected(start.tracks)
	var signs := plan.projected_signals({})
	var blocks := Blocks.inspect(ANCHOR, 9, 0, projected, signs)
	var a := Services.build(projected, [LEFT_ID, RIGHT_ID], 32, {}, "shuttle", {}, start.world.stations())
	var b := Services.build(projected, [RIGHT_ID, LEFT_ID], 32, {RIGHT_ID + ">" + LEFT_ID: [[VIA.x, VIA.y]]}, "shuttle", {}, start.world.stations())
	if not blocks.ok or not blocks.issues.is_empty() or a.cells.is_empty() or b.cells.is_empty(): return {"ok": false}
	var station_cost: int = Start.STARTING_BALANCE - start.money
	return {"ok": true, "stations": station_cost, "track": plan.quote().net, "trains": trains, "total": station_cost + int(plan.quote().net) + trains}
