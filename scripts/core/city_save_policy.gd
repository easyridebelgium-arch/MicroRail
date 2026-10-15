extends RefCounted
## Saved city geometry is authoritative. Validate it without regenerating the seed.
const World = preload("res://scripts/core/world_catalog.gd")
const Generator = preload("res://scripts/core/world_generator.gd")
const Construction = preload("res://scripts/core/station_construction.gd")
const Geometry = preload("res://scripts/track_geometry.gd")

static func valid_world(value: Variant, sawmill: bool, factory: bool) -> bool:
	if not World.valid(value) or not Construction.valid_links(value): return false
	var initial: Dictionary = value.duplicate(true)
	initial.facilities = []
	var protected: Dictionary = {}
	var bounds := Rect2i(Vector2i.ZERO, Generator.MAP_SIZE)
	for town in value.settlements:
		for cell in Generator.tiles(Generator.town_bounds(Vector2i(int(town.cell[0]), int(town.cell[1])))): protected[cell] = true
	for site in value.facilities:
		if site.kind == "station": continue
		if site.enabled != (sawmill if site.kind == "sawmill" else factory if site.kind == "factory" else true): return false
		var original: Dictionary = site.duplicate(true)
		original.enabled = site.kind in ["forest", "terminal"]
		initial.facilities.append(original)
		var center := Vector2i(int(site.cell[0]), int(site.cell[1]))
		for cell in Construction.building_cells(center) + [center]: protected[cell] = true
	if not Generator.valid_initial(initial): return false
	for site in value.facilities:
		if site.kind != "station": continue
		if not site.enabled or site.stop_id != "city_" + str(site.settlement_id).trim_prefix("town:") or site.id != "station:" + site.stop_id: return false
		var stop := Vector2i(int(site.cell[0]), int(site.cell[1]))
		for cell in Construction.building_cells(stop) + Construction.platform_cells(stop):
			if not bounds.has_point(cell) or protected.has(cell): return false
			protected[cell] = true
	return true

static func valid_platforms(world: Dictionary, tracks: Dictionary) -> bool:
	for site in world.facilities:
		var stop := Vector2i(int(site.cell[0]), int(site.cell[1]))
		if site.kind == "station":
			for cell in Construction.platform_cells(stop):
				if not tracks.has(cell) or not Geometry.same_connections(tracks[cell], false): return false
		elif tracks.has(stop) and tracks[stop] != false: return false
		elif site.enabled and site.kind in ["sawmill", "factory"] and not tracks.has(stop): return false
	return true

static func valid_absent_actors(data: Dictionary) -> bool:
	# Keep the legacy envelope inert when that actor does not exist in the company.
	if not data.services.has("passenger"):
		for field in ["passenger_stop_index", "passengers_on_train", "capacity_upgrade_level", "speed_upgrade_level", "wait_remaining", "operating_timer"]:
			if data.state[field] != 0: return false
		if data.state.passenger_service_enabled or data.route_distance != 0: return false
	if not data.services.has("freight"):
		for field in ["cargo", "distance", "dwell", "operating_timer", "chain_stage", "capacity_level", "speed_level"]:
			if data.freight.get(field) != 0: return false
		if data.freight.get("service_enabled") != false or data.sawmill.installed or data.factory.installed: return false
	return true
