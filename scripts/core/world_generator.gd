extends RefCounted
## Flat-land starting geometry only. Does not build stations, track or services.
const World = preload("res://scripts/core/world_catalog.gd")
const SimRng = preload("res://scripts/core/sim_rng.gd")
const PROFILE := "seeded_flat"
const GENERATOR_VERSION := 1
const CONTENT_VERSION := 1
const MIN_CITIES := 3
const MAX_CITIES := 8
const MAP_SIZE := Vector2i(80, 50)

static func generate(seed_text: String, city_count: int = 4) -> Dictionary:
	if not seed_text.is_valid_int() or str(seed_text.to_int()) != seed_text or seed_text.to_int() < 0:
		return {"ok": false, "message": "Use a whole-number seed from 0 to 9223372036854775807."}
	if city_count < MIN_CITIES or city_count > MAX_CITIES:
		return {"ok": false, "message": "Choose between 3 and 8 cities."}
	var rng := SimRng.new(seed_text.to_int())
	# Shuffle a finite set of separated slots, rather than retrying random placements.
	var slots: Array = []
	for y in [9, 23]:
		for x in [10, 28, 46, 64]: slots.append(Vector2i(x, y))
	rng.shuffle(slots)
	var towns: Array = []
	for index in range(city_count):
		var center: Vector2i = slots[index] + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
		towns.append({"id": "town:%02d" % (index + 1), "name": "Town %d" % (index + 1), "cell": [center.x, center.y]})
	var first_x: int = rng.randi_range(8, 20)
	var freight_y: int = rng.randi_range(36, 43)
	var sites: Array = []
	var kinds := ["forest", "sawmill", "factory", "terminal"]
	for index in range(kinds.size()):
		var kind: String = kinds[index]
		sites.append({"id": "industry:" + kind, "stop_id": kind, "kind": kind, "name": kind.capitalize(), "cell": [first_x + index * 14, freight_y], "settlement_id": "", "enabled": kind in ["forest", "terminal"]})
	var world := {"schema_version": World.SCHEMA_VERSION, "layout_id": PROFILE, "generator_version": GENERATOR_VERSION, "content_version": CONTENT_VERSION, "layout_seed": seed_text, "size": [MAP_SIZE.x, MAP_SIZE.y], "settlements": towns, "facilities": sites}
	if not valid_initial(world):
		return {"ok": false, "message": "The generated layout failed its placement checks."}
	# Continue this stream when starting simulation; never seed a second live RNG.
	return {"ok": true, "world": world, "rng_state": rng.save_state(), "planning": planning(world)}

static func town_bounds(center: Vector2i) -> Rect2i:
	return Rect2i(center - Vector2i(2, 1), Vector2i(5, 3))

static func station_clearance(center: Vector2i) -> Rect2i:
	# Building rows, a nine-tile platform approach and an adjacent passing-loop row.
	return Rect2i(center + Vector2i(-4, 2), Vector2i(9, 4))

static func planning(world: Dictionary) -> Dictionary:
	var candidates: Array = []
	for town in world.settlements:
		candidates.append({"settlement_id": town.id, "cell": [int(town.cell[0]), int(town.cell[1]) + 4]})
	var positions: Dictionary = {}
	for site in world.facilities: positions[site.kind] = site.cell.duplicate()
	return {"station_candidates": candidates, "freight_corridor": [positions.forest, positions.terminal]}

static func valid_initial(value: Variant) -> bool:
	if not World.valid(value): return false
	if value.layout_id != PROFILE or value.generator_version != GENERATOR_VERSION or value.content_version != CONTENT_VERSION: return false
	if int(value["size"][0]) != MAP_SIZE.x or int(value["size"][1]) != MAP_SIZE.y or value.settlements.size() < MIN_CITIES or value.settlements.size() > MAX_CITIES or value.facilities.size() != 4: return false
	var bounds := Rect2i(Vector2i.ZERO, MAP_SIZE)
	var zones: Array[Rect2i] = []
	var blocked: Dictionary = {}
	var candidates: Array[Vector2i] = []
	for town in value.settlements:
		var center := Vector2i(int(town.cell[0]), int(town.cell[1]))
		var buildings := town_bounds(center)
		var access := station_clearance(center)
		if not bounds.encloses(buildings) or not bounds.encloses(access): return false
		for previous in zones:
			if previous.intersects(buildings) or previous.intersects(access): return false
		zones.append(buildings)
		zones.append(access)
		for tile in tiles(buildings): blocked[tile] = true
		candidates.append(center + Vector2i(0, 4))
	var sites: Dictionary = {}
	for site in value.facilities:
		if site.kind == "station" or site.enabled != (site.kind in ["forest", "terminal"]): return false
		sites[site.kind] = Vector2i(int(site.cell[0]), int(site.cell[1]))
	for kind in ["forest", "sawmill", "factory", "terminal"]:
		if not sites.has(kind): return false
	var previous_x: int = -100
	for kind in ["forest", "sawmill", "factory", "terminal"]:
		var cell: Vector2i = sites[kind]
		if cell.y != sites.forest.y or cell.x - previous_x < 10: return false
		previous_x = cell.x
		for tile in tiles(Rect2i(cell - Vector2i(1, 2), Vector2i(3, 2))): blocked[tile] = true
	var corridor := Rect2i(sites.forest - Vector2i(4, 2), Vector2i(sites.terminal.x - sites.forest.x + 9, 5))
	if not bounds.encloses(corridor): return false
	for zone in zones:
		if zone.intersects(corridor): return false
	# Flat-land reachability is a construction witness, not train movement authority.
	var reachable := {sites.forest: true}
	var pending: Array[Vector2i] = [sites.forest]
	var cursor := 0
	while cursor < pending.size():
		var tile: Vector2i = pending[cursor]
		cursor += 1
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = tile + direction
			if bounds.has_point(neighbor) and not blocked.has(neighbor) and not reachable.has(neighbor):
				reachable[neighbor] = true
				pending.append(neighbor)
	for candidate in candidates:
		if not reachable.has(candidate): return false
	return reachable.has(sites.terminal)

static func tiles(rectangle: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(rectangle.position.y, rectangle.end.y):
		for x in range(rectangle.position.x, rectangle.end.x): result.append(Vector2i(x, y))
	return result
