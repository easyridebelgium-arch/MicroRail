extends RefCounted
## Bounded construction witnesses, not a globally cheapest-path search.
const Stations = preload("res://scripts/core/station_construction.gd")
const Generator = preload("res://scripts/core/world_generator.gd")
const Builder = preload("res://scripts/track_builder.gd")
const Plan = preload("res://scripts/core/construction_plan.gd")
const Router = preload("res://scripts/rail_router.gd")

static func find(world: Dictionary, terrain: RefCounted, a: Vector2i, b: Vector2i, live: Dictionary = {}, signs: Dictionary = {}, owners: Dictionary = {}) -> Dictionary:
	var tracks := live.duplicate(true)
	var proposed_world := world.duplicate(true)
	var station_cost := 0
	for stop in [a, b]:
		var draft := Stations.draft(proposed_world, stop, tracks, signs, owners, 1000000)
		if not draft.ok or not terrain.site_error(draft.platform_cells + draft.building_cells, tracks).is_empty(): return {}
		var bought := Stations.purchase(draft, proposed_world, tracks, signs, owners, 1000000)
		if not bought.ok: return {}
		tracks = bought.tracks
		proposed_world = bought.world
		station_cost += int(bought.spent)
	var blocked: Dictionary = {}
	var fixed: Array[Vector2i] = []
	for town in world.settlements:
		for cell in Generator.tiles(Generator.town_bounds(Vector2i(town.cell[0], town.cell[1]))): blocked[cell] = true
	for site in proposed_world.facilities:
		var center := Vector2i(site.cell[0], site.cell[1])
		for cell in Stations.building_cells(center): blocked[cell] = true
		if site.kind == "station": fixed.append_array(Stations.platform_cells(center))
		else: blocked[center] = true
	var columns: Array = range(int(world["size"][0]))
	columns.sort_custom(func(x: int, y: int) -> bool:
		var dx := absi(x - a.x) + absi(x - b.x)
		var dy := absi(y - a.x) + absi(y - b.x)
		return dx < dy if dx != dy else x < y)
	for column in columns:
		var cells: Array[Vector2i] = [a]
		for corner in [Vector2i(column, a.y), Vector2i(column, b.y), b]:
			var segment := Builder.segment(cells.back(), corner)
			for index in range(1, segment.size()): cells.append(segment[index])
		var built := Builder.plan(cells, tracks, Vector2i(world["size"][0], world["size"][1]), func(cell: Vector2i) -> bool: return blocked.has(cell), fixed)
		if not built.error.is_empty(): continue
		var plan := Plan.new()
		plan.terrain = terrain
		plan.stage(built.changes, tracks)
		var protected := func(cell: Vector2i) -> bool: return blocked.has(cell) or cell in fixed
		if not plan.is_empty() and not plan.validate(tracks, owners, signs, Generator.MAP_SIZE, protected, 1000000).is_empty(): continue
		var projected := plan.projected(tracks)
		if not terrain.track_error(projected, signs).is_empty() or Router.find_route(projected, a, b).is_empty(): continue
		var price: int = plan.quote().net
		return {"cells": cells, "tracks": projected, "changes": built.changes, "station_cost": station_cost, "track_cost": price, "a": a, "b": b, "column": column}
	return {}
