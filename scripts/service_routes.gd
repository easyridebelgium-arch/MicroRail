extends RefCounted

const WaypointRouter = preload("res://scripts/waypoint_router.gd")
const Router = preload("res://scripts/rail_router.gd")
const ArrivalTargets = preload("res://scripts/core/arrival_targets.gd")
const Timetable = preload("res://scripts/core/timetable.gd")
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
static func stop_cell(platforms: Dictionary, stop: String, station_catalog: Dictionary = STATIONS) -> Vector2i:
	if not station_catalog.has(stop): return Vector2i(-1, -1)
	return station_catalog[stop]["cell"] + Vector2i(0, int(PLATFORM_ROWS.get(int(platforms.get(stop, 1)), 0)))

static func is_stop_cell(cell: Vector2i, station_catalog: Dictionary = STATIONS) -> bool:
	for key in station_catalog:
		for row in PLATFORM_ROWS.values():
			if cell == station_catalog[key]["cell"] + Vector2i(0, int(row)): return true
	return false

static func valid_platforms(service: Dictionary, station_catalog: Dictionary = STATIONS) -> bool:
	var chosen: Variant = service.get("platforms", {})
	if not chosen is Dictionary: return false
	for key in chosen:
		if not key is String or not service.stops.has(key) or not station_catalog.has(key): return false
		var number: Variant = chosen[key]
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)) or float(number) != floor(float(number)) or not PLATFORM_ROWS.has(int(number)): return false
	return true

## Stops whose platform is chosen automatically at each departure ("auto":
## {stop: true}); the stored `platforms` entry is the platform in use right now.
static func valid_auto(service: Dictionary, station_catalog: Dictionary = STATIONS) -> bool:
	var marks: Variant = service.get("auto", {})
	if not marks is Dictionary: return false
	for key in marks:
		if not key is String or not service.stops.has(key) or not station_catalog.has(key) or marks[key] != true: return false
	return true

## Target seconds between departures from the first stop (0 = off); kept on
## the source service of a linked group.
static func valid_headway(service: Dictionary) -> bool:
	var value: Variant = service.get("headway", 0)
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and value >= 0 and value <= 3600

## Departure minutes after midnight (sorted, unique), kept on the source service.
static func valid_timetable(service: Dictionary) -> bool:
	if not Timetable.valid_times(service.get("timetable", [])): return false
	var later: Variant = service.get("stop_timetables", {})
	if not later is Dictionary: return false
	var legs := Timetable.departure_legs(service.stops, service.get("mode", "shuttle"))
	for leg in later:
		if not leg is String or leg == legs[0] or not legs.has(leg) or not Timetable.valid_times(later[leg]): return false
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
	result.erase("timetable")
	if instructions.has("timetable"): result["timetable"] = instructions.timetable
	result.erase("stop_timetables")
	if instructions.has("stop_timetables"): result["stop_timetables"] = instructions.stop_timetables
	result.erase("arrival_targets")
	if instructions.has("arrival_targets"): result["arrival_targets"] = instructions.arrival_targets
	return result

## A linked service follows another passenger service's route ("link": key of
## the source). The source cannot itself be linked, so a group is one level deep.
static func valid_link(value: Dictionary, key: String) -> bool:
	var service: Dictionary = value[key]
	if not service.has("link"): return true
	var source: Variant = service["link"]
	if not source is String or source == key or not is_passenger_key(source) or not value.has(source): return false
	return not value[source].has("link")

## Copies each source's stops, mode, waypoints and platforms onto services
## linked to it. A linked service keeps its own name and first-stop platform.
static func propagate(configuration: Dictionary) -> Dictionary:
	var result := configuration.duplicate(true)
	for key in result:
		var service: Dictionary = result[key]
		var source_key: Variant = service.get("link", "")
		if not source_key is String or not result.has(source_key) or source_key == key or result[source_key].has("link"):
			service.erase("link")
			continue
		var source: Dictionary = result[source_key]
		var own_first: String = str(service.stops[0]) if service.get("stops", []).size() > 0 else ""
		var own_platform: int = int(service.get("platforms", {}).get(own_first, 1))
		var own_auto: bool = service.get("auto", {}).has(own_first)
		var copied := copy_route(source, service)
		copied["name"] = service.name
		copied["link"] = source_key
		var first: String = str(copied.stops[0])
		var platforms: Dictionary = copied.get("platforms", {})
		if own_first == first and own_platform != 1: platforms[first] = own_platform
		else: platforms.erase(first)
		copied["platforms"] = platforms
		var marks: Dictionary = source.get("auto", {}).duplicate()
		marks.erase(first)
		if own_first == first and own_auto: marks[first] = true
		if marks.is_empty(): copied.erase("auto")
		else: copied["auto"] = marks
		result[key] = copied
	return result

static func defaults() -> Dictionary:
	return {
		"passenger": {"name": "Passenger Shuttle", "stops": ["a", "b"], "waypoints": {}, "mode": "shuttle"},
		"freight": {"name": "Timber Service", "stops": ["forest", "terminal"], "waypoints": {}, "mode": "shuttle"},
	}

static func is_valid(value: Variant, station_catalog: Dictionary = STATIONS) -> bool:
	if not valid_catalog(station_catalog): return false
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
			if service.get("stop_timetables", {}) != {}: return false
		else:
			var stops: Array = service.stops
			if stops.size() < 2 or stops.size() > station_catalog.size(): return false
			var seen: Dictionary = {}
			for stop in stops:
				if not stop is String or not station_catalog.has(stop) or seen.has(stop): return false
				seen[stop] = true
		if not valid_waypoints(service, station_catalog) or not valid_platforms(service, station_catalog) or not valid_auto(service, station_catalog) or not valid_link(value, key) or not valid_headway(service) or not valid_timetable(service) or not ArrivalTargets.valid_targets(service): return false
	return true

static func build(tracks: Dictionary, stops: Array, tile_size: float, waypoints: Dictionary = {}, mode: String = "shuttle", platforms: Dictionary = {}, station_catalog: Dictionary = STATIONS) -> Dictionary:
	var cells: Array[Vector2i] = []
	var path := Curve2D.new()
	path.bake_interval = 1.0
	var distances: Array[float] = [0.0]
	if not valid_catalog(station_catalog) or stops.size() < 2 or mode not in ["shuttle", "loop"]:
		return {"cells": [], "path": path, "distances": [], "error": "Invalid station catalog or stop sequence"}
	for stop in stops:
		if not station_catalog.has(stop): return {"cells": [], "path": path, "distances": [], "error": "Unknown station stop: %s" % str(stop)}
	for index in range(leg_count(stops, mode)):
		var from_stop: Dictionary = station_catalog[stops[index]]
		var to_stop: Dictionary = station_catalog[stops[(index + 1) % stops.size()]]
		var leg: Array[Vector2i] = WaypointRouter.find_route(tracks, stop_cell(platforms, stops[index], station_catalog), stop_cell(platforms, stops[(index + 1) % stops.size()], station_catalog), waypoints.get(leg_key(stops, index), []))
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

static func valid_waypoints(service: Dictionary, station_catalog: Dictionary = STATIONS) -> bool:
	var protected: Array = [Vector2i(8, 24), Vector2i(28, 24)]
	for station in station_catalog.values(): protected.append(station.cell)
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
			if seen.has(cell) or cell in protected: return false
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
		var times: Array = []
		for minute in result[service].get("timetable", []): times.append(int(minute))
		if times.is_empty(): result[service].erase("timetable")
		else: result[service]["timetable"] = times
		var later: Dictionary = {}
		for leg in result[service].get("stop_timetables", {}):
			var normalized: Array = []
			for minute in result[service].stop_timetables[leg]: normalized.append(int(minute))
			if not normalized.is_empty(): later[leg] = normalized
		if later.is_empty(): result[service].erase("stop_timetables")
		else: result[service]["stop_timetables"] = later
		if int(result[service].get("headway", 0)) <= 0: result[service].erase("headway")
		else: result[service]["headway"] = int(result[service]["headway"])
		var targets: Dictionary = {}
		for leg in result[service].get("arrival_targets", {}): targets[leg] = int(result[service].arrival_targets[leg])
		if targets.is_empty(): result[service].erase("arrival_targets")
		else: result[service]["arrival_targets"] = targets
		var marks: Dictionary = {}
		for stop in result[service].get("auto", {}): marks[stop] = true
		if marks.is_empty(): result[service].erase("auto")
		else: result[service]["auto"] = marks
	return result

static func valid_catalog(value: Dictionary) -> bool:
	if value.is_empty() or value.size() > 64: return false
	for key in value:
		if not key is String or key.is_empty() or key.length() > 64 or not value[key] is Dictionary: return false
		if not value[key].get("cell") is Vector2i or not value[key].get("name") is String: return false
	return true
