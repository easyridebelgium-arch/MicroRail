extends RefCounted
## Reusable geometry of the passing-loop example; placement uses normal drafts.
const Blueprints = preload("res://scripts/core/track_blueprints.gd")
const WIDTH := 9
const HEIGHT := 4
const MAX_LENGTH := 31
const ORIENTATIONS := ["Horizontal — loop below", "Horizontal — loop above", "Vertical — loop right", "Vertical — loop left"]
const Geometry = preload("res://scripts/track_geometry.gd")

static func design(length: int = WIDTH, orientation: int = 0) -> Dictionary:
	if length < WIDTH or length > MAX_LENGTH or orientation < 0 or orientation >= ORIENTATIONS.size(): return {}
	var tiles: Array = []
	for x in range(length):
		tiles.append([x, 0, "junction_6_2_4" if x == 0 else "junction_2_6_4" if x == length - 1 else false])
		tiles.append([x, 3, "NE" if x == 0 else "NW" if x == length - 1 else false])
	for x in [0, length - 1]:
		for y in [1, 2]: tiles.append([x, y, true])
	var signs: Array = [[1, 0, "auto"], [length - 2, 0, "auto"], [0, 2, "auto"], [length - 1, 2, "auto"]]
	var offset := footprint_offset(orientation)
	for row in tiles:
		var point := transform(Vector2i(row[0], row[1]), orientation) - offset
		row[0] = point.x
		row[1] = point.y
		var ports := Geometry.connections(row[2])
		row[2] = Geometry.switch_type(transform(ports[0], orientation), transform(ports[1], orientation), transform(ports[2], orientation)) if ports.size() == 3 else Geometry.from_ports(transform(ports[0], orientation), transform(ports[1], orientation))
	for row in signs:
		var point := transform(Vector2i(row[0], row[1]), orientation) - offset
		row[0] = point.x
		row[1] = point.y
	return {"version": Blueprints.VERSION, "name": "Guided passing loop", "width": length if orientation < 2 else HEIGHT, "height": HEIGHT if orientation < 2 else length, "tiles": tiles, "signals": signs}

## The clicked point is always the first switch (leftmost/topmost along the main line).
static func transform(point: Vector2i, orientation: int) -> Vector2i:
	match orientation:
		1: return Vector2i(point.x, -point.y)
		2: return Vector2i(point.y, point.x)
		3: return Vector2i(-point.y, point.x)
	return point

static func footprint_offset(orientation: int) -> Vector2i:
	return Vector2i(0, -3) if orientation == 1 else Vector2i(-3, 0) if orientation == 3 else Vector2i.ZERO

static func waypoint(anchor: Vector2i, length: int = WIDTH, orientation: int = 0) -> Vector2i:
	return anchor + transform(Vector2i(floori(float(length - 1) / 2.0), 3), orientation)

static func instructions(anchor: Vector2i, length: int = WIDTH, orientation: int = 0) -> String:
	var last := anchor + transform(Vector2i(length - 1, 0), orientation)
	var via := waypoint(anchor, length, orientation)
	return "Passing-loop draft (%s, %d tiles including switches): switches %d,%d and %d,%d; loop waypoint %d,%d. Review cost, reservations and affected services before Apply plan. Connect the outer switch ends to your line. In Routes, give one service the loop waypoint; leave the other on the main branch. Four automatic signals separate both branches. Keep station approaches outside this footprint. Check that your whole train fits between holding points; choose a longer loop for long consists. This does not automatically choose branches or prevent every deadlock." % [ORIENTATIONS[orientation], length, anchor.x, anchor.y, last.x, last.y, via.x, via.y]
