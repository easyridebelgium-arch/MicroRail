extends RefCounted
## Keep a train's travelled geometry independent of the current track network.
const Geometry = preload("res://scripts/track_geometry.gd")
const Router = preload("res://scripts/rail_router.gd")
const Services = preload("res://scripts/service_routes.gd")

static func encode(cells: Array[Vector2i]) -> Array:
	var result: Array = []
	for cell in cells: result.append([cell.x, cell.y])
	return result

static func decode(value: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for entry in value: result.append(Vector2i(int(entry[0]), int(entry[1])))
	return result

static func valid_cells(value: Variant) -> bool:
	if not value is Array or value.size() > 12000: return false
	for entry in value:
		if not entry is Array or entry.size() != 2: return false
		for number in entry:
			if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)) or float(number) != floor(float(number)): return false
		if float(entry[0]) < 0 or float(entry[0]) >= 80 or float(entry[1]) < 0 or float(entry[1]) >= 50: return false
	var cells := decode(value)
	for i in range(1, cells.size()):
		var delta: Vector2i = cells[i] - cells[i - 1]
		if delta == Vector2i.ZERO or maxi(absi(delta.x), absi(delta.y)) != 1: return false
	return true

static func passenger_path(cells: Array[Vector2i], stops: Array, tile_size: float, waypoints: Dictionary = {}) -> Dictionary:
	var path := Curve2D.new()
	path.bake_interval = 1.0
	var distances: Array[float] = [0.0]
	if cells.is_empty(): return {"cells": cells, "path": path, "distances": [], "error": "Route incomplete"}
	if cells[0] != Services.STATIONS[stops[0]]["cell"]: return {}
	var start := 0
	var leg_index := 0
	for stop in stops.slice(1):
		var end := -1
		for i in range(start + 1, cells.size()):
			if cells[i] == Services.STATIONS[stop]["cell"]:
				end = i
				break
		if end < 0: return {}
		var leg: Array[Vector2i] = cells.slice(start, end + 1)
		for i in range(1, leg.size() - 1):
			if Geometry.from_ports(leg[i - 1] - leg[i], leg[i + 1] - leg[i]) == null: return {}
		if not Services.waypoints_in_order(leg, waypoints.get(Services.leg_key(stops, leg_index), [])): return {}
		leg_index += 1
		var segment := Router.make_path(leg, tile_size)
		for i in range(segment.point_count):
			var point := segment.get_point_position(i)
			if path.point_count == 0 or path.get_point_position(path.point_count - 1).distance_to(point) > 0.001: path.add_point(point)
		distances.append(path.get_baked_length())
		start = end
	if start != cells.size() - 1: return {}
	return {"cells": cells, "path": path, "distances": distances, "error": ""}

static func connected(cells: Array[Vector2i], tracks: Dictionary) -> bool:
	if cells.size() < 2: return false
	for i in range(cells.size()):
		var cell: Vector2i = cells[i]
		if not tracks.has(cell): return false
		if i + 1 < cells.size():
			var next: Vector2i = cells[i + 1]
			if not tracks.has(next) or not Geometry.connections(tracks[cell]).has(next - cell) or not Geometry.connections(tracks[next]).has(cell - next): return false
		if i > 0 and i + 1 < cells.size():
			var entry: Vector2i = cells[i - 1] - cell
			var exit: Vector2i = cells[i + 1] - cell
			if entry == exit and cell in [Vector2i(4, 8), Vector2i(20, 8), Vector2i(36, 8)]: continue
			if not Geometry.exits_from(tracks[cell], entry).has(exit): return false
	return true

static func defaults() -> Dictionary:
	return {"passenger_cells": [], "freight_cells": [], "passenger_returning": false, "passenger_return_stop": 0, "passenger_held": false, "freight_returning": false, "freight_held": false}

static func valid_state(value: Variant, services: Dictionary) -> bool:
	if not value is Dictionary: return false
	for field in ["passenger_returning", "passenger_held", "freight_returning", "freight_held"]:
		if typeof(value.get(field)) != TYPE_BOOL: return false
	var target: Variant = value.get("passenger_return_stop")
	if typeof(target) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(target)) or float(target) != floor(float(target)) or float(target) < 0 or float(target) >= services["passenger"]["stops"].size(): return false
	for field in ["passenger_cells", "freight_cells"]:
		if not valid_cells(value.get(field)): return false
	var passenger := decode(value["passenger_cells"])
	if not passenger.is_empty() and passenger_path(passenger, services["passenger"]["stops"], 32, services["passenger"].get("waypoints", {})).is_empty(): return false
	var freight := decode(value["freight_cells"])
	if not freight.is_empty():
		if freight.size() < 2 or freight[0] != Vector2i(8, 24) or freight[-1] != Vector2i(28, 24): return false
		if not Services.waypoints_in_order(freight, services["freight"].get("waypoints", {}).get("forest>terminal", [])): return false
		for i in range(1, freight.size() - 1):
			if Geometry.from_ports(freight[i - 1] - freight[i], freight[i + 1] - freight[i]) == null: return false
	return true
