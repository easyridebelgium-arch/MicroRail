extends RefCounted

const WaypointRouter = preload("res://scripts/waypoint_router.gd")
const Router = preload("res://scripts/rail_router.gd")
const STATIONS: Dictionary = {
	"a": {"name": "Station A", "cell": Vector2i(4, 8)},
	"b": {"name": "Station B", "cell": Vector2i(20, 8)},
	"c": {"name": "Station C", "cell": Vector2i(36, 8)},
}

const MAX_PASSENGER_SERVICES := 8
## Platform number -> row offset from the station's stop tile (see platforms.gd).
const PLATFORM_ROWS: Dictionary = {1: 0, 2: 1, 3: -1}

## Stop tile used by a service for a station: platform 1 (the default) is the
## station tile itself; platforms 2 and 3 are sidings beside it.
static func stop_cell(platforms: Dictionary, stop: String) -> Vector2i:
	return STATIONS[stop]["cell"] + Vector2i(0, int(PLATFORM_ROWS.get(int(platforms.get(stop, 1)), 0)))

static func is_stop_cell(cell: Vector2i) -> bool:
	for key in STATIONS:
		for row in PLATFORM_ROWS.values():
			if cell == STATIONS[key]["cell"] + Vector2i(0, int(row)): return true
	return false

static func valid_platforms(service: Dictionary) -> bool:
	var chosen: Variant = service.get("platforms", {})
	if not chosen is Dictionary: return false
	for key in chosen:
		if not key is String or not service.stops.has(key) or not STATIONS.has(key): return false
		var number: Variant = chosen[key]
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)) or float(number) != floor(float(number)) or not PLATFORM_ROWS.has(int(number)): return false
	return true

static func is_passenger_key(key: Variant) -> bool:
	if not key is String: return false
	if key == "passenger": return true
	if not key.begins_with("passenger_"): return false
	var suffix: String = key.trim_prefix("passenger_")
	return suffix.is_valid_int() and int(suffix) >= 1 and int(suffix) < 1000000000 and str(int(suffix)) == suffix

static func kind(key: String) -> String:
	return "passenger" if is_passenger_key(key) else key

## Copy operating instructions only. Identity, train assignment and runtime
## remain with the target; nested waypoint arrays must never alias the source.
static func copy_route(source: Dictionary, target: Dictionary) -> Dictionary:
	var result := target.duplicate(true)
	for field in ["stops", "mode", "waypoints", "platforms"]:
		result.erase(field)
	var instructions := source.duplicate(true)
	result["stops"] = instructions.stops
	result["mode"] = instructions.get("mode", "shuttle")
	result["waypoints"] = instructions.get("waypoints", {})
	result["platforms"] = instructions.get("platforms", {})
	return result

static func defaults() -> Dictionary:
	return {
		"passenger": {"name": "Passenger Shuttle", "stops": ["a", "b"], "waypoints": {}, "mode": "shuttle"},
		"freight": {"name": "Timber Service", "stops": ["forest", "terminal"], "waypoints": {}, "mode": "shuttle"},
	}

static func is_valid(value: Variant) -> bool:
	if not value is Dictionary or not value.has("passenger") or not value.has("freight") or value.size() > MAX_PASSENGER_SERVICES + 1: return false
	for key in value:
		if key != "freight" and not is_passenger_key(key): return false
		if not value[key] is Dictionary: return false
		var service: Dictionary = value[key]
		if not service.get("name") is String or not service.get("stops") is Array: return false
		var mode: Variant = service.get("mode", "shuttle")
		if not mode is String or mode not in ["shuttle", "loop"] or (key == "freight" and mode != "shuttle"): return false
		var title: String = service["name"]
		if title != title.strip_edges() or title.is_empty() or title.length() > 40 or "\n" in title or "\r" in title: return false
		if key == "freight":
			if service.stops != ["forest", "terminal"]: return false
		else:
			var stops: Array = service.stops
			if stops.size() < 2 or stops.size() > STATIONS.size(): return false
			var seen: Dictionary = {}
			for stop in stops:
				if not stop is String or not STATIONS.has(stop) or seen.has(stop): return false
				seen[stop] = true
		if not valid_waypoints(service) or not valid_platforms(service): return false
	return true

static func build(tracks: Dictionary, stops: Array, tile_size: float, waypoints: Dictionary = {}, mode: String = "shuttle", platforms: Dictionary = {}) -> Dictionary:
	var cells: Array[Vector2i] = []
	var path := Curve2D.new()
	path.bake_interval = 1.0
	var distances: Array[float] = [0.0]
	for index in range(leg_count(stops, mode)):
		var from_stop: Dictionary = STATIONS[stops[index]]
		var to_stop: Dictionary = STATIONS[stops[(index + 1) % stops.size()]]
		var leg: Array[Vector2i] = WaypointRouter.find_route(tracks, stop_cell(platforms, stops[index]), stop_cell(platforms, stops[(index + 1) % stops.size()]), waypoints.get(leg_key(stops, index), []))
		if leg.is_empty():
			return {"cells": [], "path": Curve2D.new(), "distances": [], "error": "Missing track or waypoint path: %s → %s" % [from_stop["name"], to_stop["name"]]}
		for cell in leg:
			if cells.is_empty() or cells.back() != cell:
				cells.append(cell)
		# Build each leg separately: an ordered stop can require reversal.
		var leg_path: Curve2D = Router.make_path(leg, tile_size)
		for point_index in range(leg_path.point_count):
			var point: Vector2 = leg_path.get_point_position(point_index)
			if path.point_count == 0 or path.get_point_position(path.point_count - 1).distance_to(point) > 0.001:
				path.add_point(point)
		distances.append(path.get_baked_length())
	return {"cells": cells, "path": path, "distances": distances, "error": ""}


static func leg_key(stops: Array, index: int) -> String:
	return "%s>%s" % [stops[index], stops[(index + 1) % stops.size()]]

static func leg_count(stops: Array, mode: String) -> int:
	return stops.size() if mode == "loop" else stops.size() - 1

static func valid_waypoints(service: Dictionary) -> bool:
	var directives: Variant = service.get("waypoints", {})
	if not directives is Dictionary: return false
	var legs: Array[String] = []
	for index in range(leg_count(service["stops"], service.get("mode", "shuttle"))): legs.append(leg_key(service["stops"], index))
	for key in directives:
		if not key is String or not legs.has(key) or not directives[key] is Array or directives[key].size() > 16: return false
		var seen: Dictionary = {}
		for point in directives[key]:
			if not point is Array or point.size() != 2: return false
			for number in point:
				if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)) or float(number) != floor(float(number)): return false
			if point[0] < 0 or point[0] >= 80 or point[1] < 0 or point[1] >= 50: return false
			var cell := Vector2i(int(point[0]), int(point[1]))
			if seen.has(cell) or cell in [Vector2i(4, 8), Vector2i(20, 8), Vector2i(36, 8), Vector2i(8, 24), Vector2i(28, 24)]: return false
			seen[cell] = true
	return true


static func waypoints_in_order(cells: Array[Vector2i], points: Array) -> bool:
	var progress := 0
	for cell in cells:
		if progress < points.size() and cell == Vector2i(int(points[progress][0]), int(points[progress][1])): progress += 1
	return progress == points.size()


static func from_save(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	for service in result:
		var directives: Dictionary = result[service].get("waypoints", {})
		for leg in directives:
			var normalized: Array = []
			for point in directives[leg]: normalized.append([int(point[0]), int(point[1])])
			directives[leg] = normalized
		result[service]["waypoints"] = directives
		result[service]["mode"] = result[service].get("mode", "shuttle")
		var chosen: Dictionary = result[service].get("platforms", {})
		var normalized_platforms: Dictionary = {}
		for stop in chosen: normalized_platforms[stop] = int(chosen[stop])
		result[service]["platforms"] = normalized_platforms
	return result
