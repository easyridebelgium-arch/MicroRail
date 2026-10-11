extends RefCounted

const WaypointRouter = preload("res://scripts/waypoint_router.gd")
const Router = preload("res://scripts/rail_router.gd")
const STATIONS: Dictionary = {
	"a": {"name": "Station A", "cell": Vector2i(4, 8)},
	"b": {"name": "Station B", "cell": Vector2i(20, 8)},
	"c": {"name": "Station C", "cell": Vector2i(36, 8)},
}

static func defaults() -> Dictionary:
	return {
		"passenger": {"name": "Passenger Shuttle", "stops": ["a", "b"], "waypoints": {}, "mode": "shuttle"},
		"freight": {"name": "Timber Service", "stops": ["forest", "terminal"], "waypoints": {}, "mode": "shuttle"},
	}

static func is_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in ["passenger", "freight"]:
		if not value.get(key) is Dictionary:
			return false
		var service: Dictionary = value[key]
		if not service.get("name") is String or not service.get("stops") is Array:
			return false
		var mode: Variant = service.get("mode", "shuttle")
		if not mode is String or mode not in ["shuttle", "loop"] or (key == "freight" and mode != "shuttle"): return false
		var title: String = service["name"]
		if title != title.strip_edges() or title.is_empty() or title.length() > 40 or "\n" in title or "\r" in title:
			return false
	var stops: Array = value["passenger"]["stops"]
	if stops.size() < 2 or stops.size() > STATIONS.size():
		return false
	var seen: Dictionary = {}
	for stop in stops:
		if not stop is String or not STATIONS.has(stop) or seen.has(stop):
			return false
		seen[stop] = true
	if value["freight"]["stops"] != ["forest", "terminal"]: return false
	return valid_waypoints(value["passenger"]) and valid_waypoints(value["freight"])

static func build(tracks: Dictionary, stops: Array, tile_size: float, waypoints: Dictionary = {}, mode: String = "shuttle") -> Dictionary:
	var cells: Array[Vector2i] = []
	var path := Curve2D.new()
	path.bake_interval = 1.0
	var distances: Array[float] = [0.0]
	for index in range(leg_count(stops, mode)):
		var from_stop: Dictionary = STATIONS[stops[index]]
		var to_stop: Dictionary = STATIONS[stops[(index + 1) % stops.size()]]
		var leg: Array[Vector2i] = WaypointRouter.find_route(tracks, from_stop["cell"], to_stop["cell"], waypoints.get(leg_key(stops, index), []))
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
	for service in ["passenger", "freight"]:
		var directives: Dictionary = result[service].get("waypoints", {})
		for leg in directives:
			var normalized: Array = []
			for point in directives[leg]: normalized.append([int(point[0]), int(point[1])])
			directives[leg] = normalized
		result[service]["waypoints"] = directives
		result[service]["mode"] = result[service].get("mode", "shuttle")
	return result
