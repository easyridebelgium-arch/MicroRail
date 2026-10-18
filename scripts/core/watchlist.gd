extends RefCounted
## Presentation preferences belong to a saved company, never a global profile.
const Catalog = preload("res://scripts/core/world_catalog.gd")
const LIMIT := 128
static func keys(data: Dictionary) -> Dictionary:
	var result := {"industry:forest": true, "industry:terminal": true}
	for train in data.fleet.trains: result["train:%d" % int(train.id)] = true
	for key in data.services: result["service:" + key] = true
	for town in data.world.settlements: result[town.id] = true
	var catalog := Catalog.new()
	catalog.restore_state(data.world)
	for key in catalog.stations(): result["station:" + key] = true
	if data.sawmill.installed: result["industry:sawmill"] = true
	if data.factory.installed: result["industry:factory"] = true
	return result
static func valid(value: Variant, available: Dictionary) -> bool:
	if not value is Dictionary or value.size() > LIMIT: return false
	for key in value:
		if not key is String or not available.has(key) or not value[key] is bool or value[key] != true: return false
	return true
static func clean(value: Dictionary, available: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var ordered: Array = value.keys()
	ordered.sort()
	for key in ordered:
		if available.has(key) and value[key] == true and result.size() < LIMIT: result[key] = true
	return result
