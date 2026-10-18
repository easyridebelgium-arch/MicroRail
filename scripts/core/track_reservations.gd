extends RefCounted
## Transient ownership rebuilt before each fixed tick. Occupancy comes first,
## then requests in the supplied deterministic dispatch order. Movement consumes these grants.
const Dispatch = preload("res://scripts/core/dispatch_order.gd")
const RouteBody = preload("res://scripts/core/route_body.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const LOOKAHEAD_TILES := 3.0
const SAMPLE_STEP := 1.0
const VEHICLE_LENGTH := 28.0
const CORNER_TOLERANCE := 4.0
const BODY_STEP := 4.0
var requested: Dictionary = {}
var owners: Dictionary = {}
var occupied_owners: Dictionary = {}
var switches: Dictionary = {}
var switch_owners: Dictionary = {}
var _switch_tiles: Dictionary = {}
var waits: Dictionary = {}
var _overlapping: Dictionary = {}
var _span_cache: Dictionary = {}
var _blocked_claims: Dictionary = {}

## Body centred on `distance`; `length` is the whole train in pixels. A single
## vehicle (the default) keeps the original conservative rectangle. Longer
## trains union that rectangle along the path. Open routes extrapolate beyond
## either end; continuous circuits wrap vehicle poses onto the other end.
func footprint(path: Curve2D, distance: float, tile_size: float, length: float = VEHICLE_LENGTH) -> Array[Vector2i]:
	var extra := maxf(0.0, (length - VEHICLE_LENGTH) * 0.5)
	var steps := ceili(extra / BODY_STEP) if extra > 0.0 else 0
	var closed := RouteBody.is_closed(path)
	var cells: Array[Vector2i] = []
	for i in range(-steps, steps + 1):
		var offset := extra * float(i) / float(steps) if steps > 0 else 0.0
		for cell in _vehicle_cells(path, distance, offset, tile_size, closed):
			if not cells.has(cell): cells.append(cell)
	return cells

func _vehicle_cells(path: Curve2D, distance: float, offset: float, tile_size: float, closed: bool = false) -> Array[Vector2i]:
	var pose := RouteBody.body_pose(path, distance, offset, closed)
	var point: Vector2 = pose.origin
	var tangent: Vector2 = pose.x
	# Conservative rotated rectangle enclosing both current vehicle sprites.
	var extent := Vector2(absf(tangent.x) * 14 + absf(tangent.y) * 8, absf(tangent.y) * 14 + absf(tangent.x) * 8) + Vector2.ONE * 0.5
	# On a diagonal the bounding box only reaches the next tile with a corner of
	# the sprite (a few pixels). Parallel tracks are a tile apart, so ignore it;
	# otherwise a train on a siding branch claims the main line beside it.
	extent -= Vector2.ONE * (minf(absf(tangent.x), absf(tangent.y)) * CORNER_TOLERANCE)
	var low := Vector2i(((point - extent) / tile_size).floor())
	var high := Vector2i(((point + extent) / tile_size).floor())
	var cells: Array[Vector2i] = []
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1): cells.append(Vector2i(x, y))
	return cells

static func train_length(train: Dictionary) -> float:
	return maxf(VEHICLE_LENGTH, float(train.get("length", VEHICLE_LENGTH)))

func rebuild(trains: Array, tracks: Dictionary, tile_size: float, request_ends: Dictionary = {}, dispatch_order: Dictionary = {}) -> void:
	requested.clear()
	owners.clear()
	occupied_owners.clear()
	switches.clear()
	switch_owners.clear()
	_switch_tiles.clear()
	for cell in tracks:
		if Geometry.is_switch(tracks[cell]): _switch_tiles[cell] = true
	waits.clear()
	_overlapping.clear()
	_blocked_claims.clear()
	var ordered := trains.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.id) < int(b.id))
	# Parked and dwelling trains are obstacles too. Existing occupancy must
	# never be stolen by a lower-ID request.
	for train in ordered:
		for cell in footprint(train.path, train.distance, tile_size, train_length(train)):
			if owners.has(cell) and owners[cell] != train.id:
				waits[train.id] = {"cell": cell, "owner": owners[cell]}
				waits[owners[cell]] = {"cell": cell, "owner": train.id}
				_overlapping[train.id] = true
				_overlapping[owners[cell]] = true
			else: owners[cell] = train.id
	occupied_owners = owners.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Dispatch.before(a, b, dispatch_order))
	for train in ordered:
		requested[int(train.id)] = []
		var length: float = train.path.get_baked_length()
		var direction := 1.0 if train.forward else -1.0
		var end: float = clampf(train.distance + direction * tile_size * LOOKAHEAD_TILES, 0, length) if train.moving else train.distance
		# A red signal limits future requests, not the protection of the body.
		if request_ends.has(train.id):
			end = clampf(float(request_ends[train.id]), minf(train.distance, end), maxf(train.distance, end))
		var closed := RouteBody.is_closed(train.path)
		var spans := _route_spans(train.path, train.cells, tile_size)
		var switch_occurrences: Array = []
		for route_index in range(1, train.cells.size() - 1):
			if _switch_tiles.has(train.cells[route_index]): switch_occurrences.append({"index": route_index, "cell": train.cells[route_index]})
		var distance: float = train.distance
		var body := train_length(train)
		var half := (body - VEHICLE_LENGTH) * 0.5
		# A long body spans several route cells, so switches under the nose or
		# tail are locked too. Match movement resolution: a coarser claim scan
		# can miss brief clearance cells beside bends and strand an unblocked train.
		var step := SAMPLE_STEP
		while true:
			var required := footprint(train.path, distance, tile_size, body)
			var settings: Dictionary = {}
			var low_index := _index_at(spans, RouteBody.distance_on_path(train.path, distance - half, closed))
			var high_index := _index_at(spans, RouteBody.distance_on_path(train.path, distance + half, closed))
			# Reserve the stem and selected exit with the switch, atomically.
			for occurrence in switch_occurrences:
				var i: int = occurrence.index
				var cell: Vector2i = occurrence.cell
				var in_body_window := i >= low_index - 1 and i <= high_index + 1
				if closed and low_index > high_index: in_body_window = i >= low_index - 1 or i <= high_index + 1
				if not in_body_window or not required.has(cell):
					continue
				for neighbor in [train.cells[i - 1], train.cells[i + 1]]:
					if not required.has(neighbor): required.append(neighbor)
				var state: int = Geometry.state_for(tracks[cell], train.cells[i - 1] - cell, train.cells[i + 1] - cell)
				# state_for handles both facing and trailing moves.
				if state < 0:
					state = Geometry.state_for(tracks[cell], train.cells[i + 1] - cell, train.cells[i - 1] - cell)
				if state >= 0: settings[cell] = state
			for cell in required:
				if not requested[int(train.id)].has(cell): requested[int(train.id)].append(cell)
			var blocked := false
			for cell in required:
				if owners.has(cell) and owners[cell] != train.id:
					waits[train.id] = {"cell": cell, "owner": owners[cell]}
					blocked = true
					break
			if blocked:
				_blocked_claims[int(train.id)] = {"cells": required.duplicate(), "cause": waits[train.id].duplicate(true)}
				break
			for cell in required: owners[cell] = train.id
			switches.merge(settings, true)
			for cell in settings: switch_owners[cell] = train.id
			if absf(distance - end) < 0.001: break
			distance = move_toward(distance, end, step)

func limit(id: int, path: Curve2D, current: float, proposed: float, tile_size: float, length: float = VEHICLE_LENGTH) -> float:
	if _overlapping.has(id): return current
	var allowed := current
	while absf(allowed - proposed) > 0.001:
		var next := move_toward(allowed, proposed, SAMPLE_STEP)
		for cell in footprint(path, next, tile_size, length):
			var tile_owner := int(owners.get(cell, -1))
			var switch_owner := int(switch_owners.get(cell, -1))
			if tile_owner != id:
				_record_denial(id, cell, tile_owner, "track_reservation")
				return allowed
			if _switch_tiles.has(cell) and switch_owner != id:
				_record_denial(id, cell, switch_owner, "switch_lock")
				return allowed
		allowed = next
	return allowed

func _record_denial(id: int, cell: Vector2i, owner: int, kind: String) -> void:
	var claim: Dictionary = _blocked_claims.get(id, {})
	if owner < 0 and not claim.is_empty() and claim.cells.has(cell):
		# An atomic switch/body claim was refused by a known owner. The missing
		# grant is a consequence: retain the actual blocking identity and cell.
		waits[id] = claim.cause.duplicate(true)
		waits[id]["kind"] = kind
		return
	waits[id] = {"cell": cell, "owner": owner, "kind": kind}
	if owner < 0:
		var authority := "switch" if kind == "switch_lock" else "track"
		waits[id]["reason"] = "Waiting for %s authority at %d,%d" % [authority, cell.x, cell.y]

# Match each occurrence of a tile to its distance along the baked route. The
# same switch may be visited again on a later leg with a different exit.
func _route_spans(path: Curve2D, cells: Array[Vector2i], tile_size: float) -> Array:
	var spans: Array = [[0.0, 0]]
	if cells.is_empty(): return spans
	# Baked geometry and route occurrences are stable between edits. Comparing
	# the full packed points also invalidates in-place edits and reused curve IDs.
	var points := path.get_baked_points()
	var key := path.get_instance_id()
	var cached: Dictionary = _span_cache.get(key, {})
	if not cached.is_empty() and cached.cells == cells and cached.points == points and cached.tile_size == tile_size: return cached.spans
	var index := 0
	var distance := 0.0
	var previous: Vector2 = points[0]
	for point in points:
		distance += previous.distance_to(point)
		previous = point
		var cell := Vector2i((point / tile_size).floor())
		if index + 1 < cells.size() and cell == cells[index + 1]:
			index += 1
			spans.append([distance, index])
	if _span_cache.size() >= 32: _span_cache.clear()
	_span_cache[key] = {"cells": cells.duplicate(), "points": points, "tile_size": tile_size, "spans": spans}
	return spans

func _index_at(spans: Array, distance: float) -> int:
	var index := 0
	var lower := 0
	var upper := spans.size() - 1
	while lower <= upper:
		var middle := (lower + upper) >> 1
		if float(spans[middle][0]) <= distance:
			index = int(spans[middle][1])
			lower = middle + 1
		else:
			upper = middle - 1
	return index
