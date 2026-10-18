extends RefCounted
## Pure preview/purchase transactions. The caller adopts successful snapshots together.
const World = preload("res://scripts/core/world_catalog.gd")
const Generator = preload("res://scripts/core/world_generator.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const STATION_PRICE := 250
const TRACK_PRICE := 10
const PLATFORM_RADIUS := 2
const CATCHMENT_RADIUS := 6

static func platform_cells(stop: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in range(-PLATFORM_RADIUS, PLATFORM_RADIUS + 1): result.append(stop + Vector2i(offset, 0))
	return result

static func building_cells(stop: Vector2i) -> Array[Vector2i]:
	return Generator.tiles(Rect2i(stop - Vector2i(1, 2), Vector2i(3, 2)))

static func _center(row: Dictionary) -> Vector2i:
	return Vector2i(int(row.cell[0]), int(row.cell[1]))

static func catchments(world: Dictionary) -> Dictionary:
	# Explicit city links, not overlapping circles, own the eventual passenger supply.
	var result: Dictionary = {}
	var towns: Array = world.settlements.duplicate()
	towns.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	for town in towns: result[town.id] = ""
	var sites: Array = world.facilities.duplicate()
	sites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	for site in sites:
		if site.kind == "station" and site.enabled and result.has(site.settlement_id) and result[site.settlement_id] == "": result[site.settlement_id] = site.stop_id
	return result

static func valid_links(world: Dictionary) -> bool:
	if not World.valid(world): return false
	var towns: Dictionary = {}
	for town in world.settlements: towns[town.id] = _center(town)
	var served: Dictionary = {}
	for site in world.facilities:
		if site.kind != "station": continue
		if not towns.has(site.settlement_id) or served.has(site.settlement_id): return false
		var delta: Vector2i = towns[site.settlement_id] - _center(site)
		if delta.length_squared() > CATCHMENT_RADIUS * CATCHMENT_RADIUS: return false
		served[site.settlement_id] = true
	return true

static func preview(world: Dictionary, stop: Vector2i, tracks: Dictionary = {}, signs: Dictionary = {}, claims: Dictionary = {}, money: int = 0) -> Dictionary:
	var platform := platform_cells(stop)
	var buildings := building_cells(stop)
	var track_cost := 0
	for cell in platform:
		if not tracks.has(cell): track_cost += TRACK_PRICE
	var result := {"ok": false, "message": "", "cell": stop, "platform_cells": platform, "building_cells": buildings, "settlement_id": "", "stop_id": "", "name": "", "cost": {"station": STATION_PRICE, "track": track_cost, "total": STATION_PRICE + track_cost}}
	if not valid_links(world) or world.layout_id != Generator.PROFILE or world.generator_version != Generator.GENERATOR_VERSION or world.content_version != Generator.CONTENT_VERSION:
		return _reject(result, "Station construction needs a supported city layout.")
	if int(world["size"][0]) != Generator.MAP_SIZE.x or int(world["size"][1]) != Generator.MAP_SIZE.y or world.settlements.size() < Generator.MIN_CITIES or world.settlements.size() > Generator.MAX_CITIES:
		return _reject(result, "Station construction needs the supported map size and city count.")
	var bounds := Rect2i(Vector2i.ZERO, Vector2i(int(world["size"][0]), int(world["size"][1])))
	for cell in buildings + platform:
		if not bounds.has_point(cell): return _reject(result, "The station footprint goes outside the map.")
	var nearest: Dictionary = {}
	var distance := CATCHMENT_RADIUS * CATCHMENT_RADIUS + 1
	for town in world.settlements:
		var delta: Vector2i = _center(town) - stop
		var candidate_distance: int = delta.length_squared()
		if candidate_distance <= CATCHMENT_RADIUS * CATCHMENT_RADIUS and (candidate_distance < distance or (candidate_distance == distance and (nearest.is_empty() or town.id < nearest.id))):
			nearest = town
			distance = candidate_distance
	if nearest.is_empty(): return _reject(result, "Build within 6 tiles of a city to serve its passengers.")
	result.settlement_id = nearest.id
	result.stop_id = "city_" + str(nearest.id).trim_prefix("town:")
	result.name = str(nearest.name) + " Station"
	if not World.label(result.name): result.name = str(nearest.name)
	for site in world.facilities:
		if site.kind == "station" and site.settlement_id == nearest.id: return _reject(result, "%s already has a station. Multiple stations per city come later." % nearest.name)
		if site.stop_id == result.stop_id: return _reject(result, "This station identity is already in use.")
		var protected := building_cells(_center(site))
		protected.append(_center(site))
		if site.kind == "station": protected.append_array(platform_cells(_center(site)))
		for cell in buildings + platform:
			if cell in protected: return _reject(result, "The station overlaps an existing station or industry site.")
	for town in world.settlements:
		var city_bounds := Generator.town_bounds(_center(town))
		for cell in buildings + platform:
			if city_bounds.has_point(cell): return _reject(result, "The station overlaps city buildings.")
	for cell in buildings + platform:
		if claims.has(cell): return _reject(result, "Track %d,%d is reserved or occupied by train #%d; let it clear first." % [cell.x, cell.y, int(claims[cell])])
		if signs.has(cell): return _reject(result, "Remove the signal from the station footprint first.")
	for cell in buildings:
		if tracks.has(cell): return _reject(result, "The station building would cover track. Choose another position.")
	for cell in platform:
		if tracks.has(cell) and not Geometry.same_connections(tracks[cell], false): return _reject(result, "Platforms need straight horizontal track; curves, switches and crossings cannot be replaced.")
	if money < int(result.cost.total): return _reject(result, "Insufficient funds: station needs £%d, available £%d." % [result.cost.total, money])
	var proposed := world.duplicate(true)
	proposed.facilities.append(_facility(result))
	if not World.valid(proposed): return _reject(result, "The station would exceed the catalog limits or create invalid geometry.")
	result.ok = true
	result.message = "Serve %s — station £%d + new platform track £%d = £%d." % [nearest.name, STATION_PRICE, track_cost, result.cost.total]
	return result

static func draft(world: Dictionary, stop: Vector2i, tracks: Dictionary, signs: Dictionary, claims: Dictionary, money: int) -> Dictionary:
	var quoted := preview(world, stop, tracks, signs, claims, money)
	if not quoted.ok: return quoted
	# Keep a read set rather than allowing a preview to overwrite intervening edits.
	quoted["world_before"] = world.duplicate(true)
	var before: Dictionary = {}
	for cell in quoted.building_cells + quoted.platform_cells:
		before[cell] = {"present": tracks.has(cell), "kind": tracks.get(cell), "signal_present": signs.has(cell), "signal": signs.get(cell)}
	quoted["before"] = before
	return quoted

static func purchase(draft_value: Dictionary, world: Dictionary, tracks: Dictionary, signs: Dictionary, claims: Dictionary, money: int) -> Dictionary:
	if not draft_value.get("ok", false) or not draft_value.get("cell") is Vector2i or not draft_value.get("world_before") is Dictionary or not draft_value.get("before") is Dictionary:
		return {"ok": false, "message": "Create a valid station preview first."}
	if world != draft_value.world_before: return {"ok": false, "message": "Cities or facilities changed since the preview. Preview the station again."}
	var stop: Vector2i = draft_value.cell
	for cell in building_cells(stop) + platform_cells(stop):
		var previous: Variant = draft_value.before.get(cell)
		if not previous is Dictionary or previous.get("present") != tracks.has(cell) or not _same(previous.get("kind"), tracks.get(cell)) or previous.get("signal_present") != signs.has(cell) or not _same(previous.get("signal"), signs.get(cell)):
			return {"ok": false, "message": "Track or signals changed since the preview. Preview the station again."}
	# Funds and train claims can change while a preview is open. Never trust its price.
	var checked := preview(world, stop, tracks, signs, claims, money)
	if not checked.ok: return {"ok": false, "message": checked.message}
	var proposed_world := world.duplicate(true)
	proposed_world.facilities.append(_facility(checked))
	var proposed_tracks := tracks.duplicate(true)
	for cell in checked.platform_cells:
		if not proposed_tracks.has(cell): proposed_tracks[cell] = false
	return {"ok": true, "message": checked.message, "world": proposed_world, "tracks": proposed_tracks, "money": money - int(checked.cost.total), "spent": int(checked.cost.total), "station_id": "station:" + checked.stop_id, "catchments": catchments(proposed_world)}

static func _facility(quoted: Dictionary) -> Dictionary:
	return {"id": "station:" + quoted.stop_id, "stop_id": quoted.stop_id, "kind": "station", "name": quoted.name, "cell": [quoted.cell.x, quoted.cell.y], "settlement_id": quoted.settlement_id, "enabled": true}

static func _reject(result: Dictionary, message: String) -> Dictionary:
	result.message = message
	return result

static func _same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b
