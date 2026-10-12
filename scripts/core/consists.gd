extends RefCounted
## Initial rolling stock: passenger coaches and log wagons, up to four attachments.
const RouteBody = preload("res://scripts/core/route_body.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const Reservations = preload("res://scripts/core/track_reservations.gd")
const MAX_WAGONS := 4
const STOCK := {
	"coach": {"name": "Passenger coach", "kind": "passenger", "price": 180, "capacity": 18, "speed": 100.0, "cost": 1},
	"log_wagon": {"name": "Log wagon", "kind": "freight", "price": 220, "capacity": 30, "speed": 60.0, "cost": 1},
}
static func valid(wagons: Variant, kind: String) -> bool:
	if not wagons is Array or wagons.size() > MAX_WAGONS: return false
	for wagon in wagons:
		if not wagon is String or not STOCK.has(wagon) or STOCK[wagon].kind != kind: return false
	return true
static func length(train: Dictionary) -> float:
	return Reservations.VEHICLE_LENGTH + 32.0 * train.get("wagons", []).size()
static func extra_capacity(train: Dictionary) -> int:
	var result := 0
	for wagon in train.get("wagons", []): result += int(STOCK[wagon].capacity)
	return result
static func running_cost(train: Dictionary) -> int:
	return train.get("wagons", []).size()
static func speed_limit(train: Dictionary) -> float:
	var result := INF
	for wagon in train.get("wagons", []): result = minf(result, STOCK[wagon].speed)
	return result
## Straight platform/approach clearance is needed on both sides of each stop.
## The station itself remains one tile; this does not purchase extra platforms.
static func stop_clearance(path: Curve2D, distance: float, body: float, tracks: Dictionary, tile_size: float, signs: Dictionary = {}) -> String:
	if body <= Reservations.VEHICLE_LENGTH: return ""
	if path.point_count < 2: return "Complete the service route before running a consist."
	for cell in Reservations.new().footprint(path, distance, tile_size, body):
		if signs.has(cell): return "Place signals outside the full consist stopping clearance. Relocate this signal before running the longer train."
		if not tracks.has(cell) or not Geometry.same_connections(tracks[cell], false):
			return "Consist needs continuous horizontal straight track on both sides of this stop (missing or incompatible at %d,%d)." % [cell.x, cell.y]
	return ""
static func route_shape_error(path: Curve2D, cells: Array, body: float, mode: String) -> String:
	if body <= Reservations.VEHICLE_LENGTH: return ""
	if path.point_count < 2: return "Complete the service route before running a consist."
	var closed := mode == "loop"
	if closed and (not RouteBody.is_closed(path) or path.get_baked_length() <= body):
		return "Long Loop consists need a continuous circuit through the first stop, with no reversal at the join and room for the full train. Use Shuttle or revise the closing leg."
	var seen: Dictionary = {}
	for index in range(cells.size()):
		var cell: Vector2i = cells[index]
		if closed and index == cells.size() - 1 and cell == cells[0]: continue
		if seen.has(cell): return "Long consists need a route that does not revisit track tiles, except the closing first stop of a continuous Loop. Repeated-path body routing comes later."
		seen[cell] = true
	return ""

static func pose(path: Curve2D, distance: float) -> Dictionary:
	var result := RouteBody.pose(path, distance)
	return {"position": result.origin, "angle": result.x.angle()}
static func offsets(train: Dictionary) -> Array[float]:
	var result: Array[float] = []
	var count: int = train.get("wagons", []).size() + 1
	for index in range(count): result.append(float(count - 1) * 16.0 - index * 32.0)
	return result
