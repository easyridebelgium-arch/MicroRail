extends RefCounted
## Derived starting guidance. Cache only the latest geometry, never save it.
const Path = preload("res://scripts/core/first_connection_path.gd")
const Fleet = preload("res://scripts/fleet.gd")
static var cached_input: Array = []
static var cached_result: Dictionary = {}

static func recommend(world: Dictionary, terrain: RefCounted, live: Dictionary = {}, signs: Dictionary = {}, owners: Dictionary = {}) -> Dictionary:
	var input: Array = [world, terrain.profile, live, signs, owners]
	if input == cached_input: return cached_result.duplicate(true)
	var best: Dictionary = {}
	for first in range(world.settlements.size()):
		for second in range(first + 1, world.settlements.size()):
			var a: Dictionary = world.settlements[first]
			var b: Dictionary = world.settlements[second]
			var path := Path.find(world, terrain, Vector2i(a.cell[0], int(a.cell[1]) + 4), Vector2i(b.cell[0], int(b.cell[1]) + 4), live, signs, owners)
			if path.is_empty(): continue
			var budget: int = path.station_cost + path.track_cost + int(Fleet.MODELS.passenger_standard.price)
			if best.is_empty() or budget < int(best.budget):
				best = path
				best.merge({"budget": budget, "first": a.name, "second": b.name})
	cached_input = input.duplicate(true)
	cached_result = best.duplicate(true)
	return best

static func describe(world: Dictionary, terrain: RefCounted, money: int, live: Dictionary = {}, signs: Dictionary = {}, owners: Dictionary = {}) -> String:
	var best := recommend(world, terrain, live, signs, owners)
	if best.is_empty(): return "No validated simple connection found. This bounded search is not proof that no route exists. Use Station and Connect previews to explore other sites or detours."
	var funds := "Current balance covers this layout." if money >= int(best.budget) else "Current balance is below this layout's cost."
	return "Suggested connection: %s and %s. Validated layout £%d: stations/platforms £%d + connecting rails/bridges £%d + shuttle £%d. Suggested station centres %d,%d and %d,%d; leave platforms horizontally and turn via column %d. %s This checks a simple construction witness, not the globally cheapest route. Recheck live previews before buying; different curves or detours change the price. No track is placed or reserved." % [best.first, best.second, best.budget, best.station_cost, best.track_cost, Fleet.MODELS.passenger_standard.price, best.a.x, best.a.y, best.b.x, best.b.y, best.column, funds]
