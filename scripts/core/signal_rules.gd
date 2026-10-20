extends RefCounted
## One representation shared by tools, saved data, routing and operating authority.
const Geometry = preload("res://scripts/track_geometry.gd")
static func valid(mode: Variant) -> bool:
	if not mode is String: return false
	return mode in ["auto", "stop"] or mode in ["oneway_0", "oneway_1", "oneway_2", "oneway_3", "oneway_4", "oneway_5", "oneway_6", "oneway_7"]
static func direction(mode: String) -> Vector2i:
	return Geometry.DIRECTIONS[int(mode.trim_prefix("oneway_"))] if mode.begins_with("oneway_") and valid(mode) else Vector2i.ZERO
static func permits(mode: String, travel: Vector2i) -> bool:
	var allowed := direction(mode)
	return allowed == Vector2i.ZERO or travel == allowed
static func valid_on(mode: Variant, kind: Variant) -> bool:
	if not valid(mode) or not Geometry.is_straight(kind): return false
	return direction(mode) == Vector2i.ZERO or Geometry.connections(kind).has(direction(mode))
static func next_mode(old: String, kind: Variant) -> String:
	var ports := Geometry.connections(kind)
	if ports.size() != 2: return ""
	var first := "oneway_%d" % Geometry.DIRECTIONS.find(ports[0])
	var second := "oneway_%d" % Geometry.DIRECTIONS.find(ports[1])
	if old == "": return "auto"
	if old == "auto": return "stop"
	if old == "stop": return first
	if old == first: return second
	return ""
static func route_error(cells: Array[Vector2i], signs: Dictionary, forward: bool = true) -> String:
	for i in range(cells.size()):
		if not signs.has(cells[i]): continue
		var travel := Vector2i.ZERO
		if forward and i + 1 < cells.size(): travel = cells[i + 1] - cells[i]
		elif not forward and i > 0: travel = cells[i - 1] - cells[i]
		if travel != Vector2i.ZERO and not permits(str(signs[cells[i]]), travel): return "One-way signal at %d,%d forbids this direction." % [cells[i].x, cells[i].y]
	return ""
