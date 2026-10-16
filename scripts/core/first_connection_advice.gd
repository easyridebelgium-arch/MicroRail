extends RefCounted
## Cheap, read-only starting budget comparison. Never a movement route or quote.
const Stations = preload("res://scripts/core/station_construction.gd")
const Generator = preload("res://scripts/core/world_generator.gd")

static func describe(world: Dictionary, terrain: RefCounted, money: int) -> String:
	var sites: Array[Dictionary] = []
	for town in world.settlements:
		var cell := Vector2i(int(town.cell[0]), int(town.cell[1]) + 4)
		var preview := Stations.preview(world, cell, {}, {}, {}, 1000000)
		if preview.ok and terrain.site_error(preview.platform_cells + preview.building_cells).is_empty():
			sites.append({"cell": cell, "name": town.name})
	var protected: Dictionary = {}
	for town in world.settlements:
		for cell in Generator.tiles(Generator.town_bounds(Vector2i(town.cell[0], town.cell[1]))): protected[cell] = true
	for site in world.facilities:
		var center := Vector2i(site.cell[0], site.cell[1])
		for cell in Stations.building_cells(center) + Stations.platform_cells(center): protected[cell] = true
	var best: Dictionary = {}
	for first in range(sites.size()):
		for second in range(first + 1, sites.size()):
			var a: Dictionary = sites[first]
			var b: Dictionary = sites[second]
			var extra := 0
			var crossing := ""
			# Generated cities occupy two dry bands. A cross-band journey must
			# cross the river; avoid promising a complete buildable approach.
			if terrain.profile != "flat" and (a.cell.y < 16) != (b.cell.y < 16):
				var advice: Dictionary = terrain.suggest(a.cell, {}, {}, {}, func(cell: Vector2i) -> bool: return protected.has(cell))
				if advice.is_empty(): continue
				var column: int = advice.cells[0].x
				extra = terrain.water_rows(column).size() * terrain.EXTRA_COST
				crossing = " Bridge surcharge at least £%d; inspect a north–south crossing near column %d and keep both banks clear." % [extra, column]
			var delta: Vector2i = a.cell - b.cell
			# Optimistic empty-land budget, allowing four platform tiles to
			# serve as approaches. Bends and detours can only increase it.
			var rails: int = maxi(0, absi(delta.x) + absi(delta.y) - 5)
			var budget := 1000 + rails * Stations.TRACK_PRICE + extra
			if best.is_empty() or budget < int(best.budget):
				best = {"budget": budget, "a": a, "b": b, "crossing": crossing}
	if best.is_empty(): return "No clear suggested station pair. Use Station previews to find dry sites and inspect protected approaches."
	var funds := "Current balance covers this minimum only." if money >= int(best.budget) else "Current balance is below this minimum."
	return "Starting budget comparison: %s and %s. At least £%d for two £300 stations, a £400 shuttle and connecting rails.%s %s This is a lower bound, not a route quote: curves, protected buildings, bank approaches and detours may cost more. Check Station and Connect previews before purchasing." % [best.a.name, best.b.name, best.budget, best.crossing, funds]
