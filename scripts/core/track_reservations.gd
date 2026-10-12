extends RefCounted
## Transient ownership rebuilt before each fixed tick. Occupancy comes first,
## then requests in permanent fleet-ID order. Movement consumes these grants.
const Geometry = preload("res://scripts/track_geometry.gd")
const LOOKAHEAD_TILES := 3.0
const SAMPLE_STEP := 1.0
const VEHICLE_LENGTH := 28.0
const BODY_STEP := 4.0
var requested: Dictionary = {}
var owners: Dictionary = {}
var occupied_owners: Dictionary = {}
var switches: Dictionary = {}
var switch_owners: Dictionary = {}
var _switch_tiles: Dictionary = {}
var waits: Dictionary = {}
var _overlapping: Dictionary = {}

## Body centred on `distance`; `length` is the whole train in pixels. A single
## vehicle (the default) keeps the original conservative rectangle. Longer
## trains union that rectangle along the path, extrapolating past either end so
## a train longer than its platform is detected instead of clamped away.
func footprint(path: Curve2D, distance: float, tile_size: float, length: float = VEHICLE_LENGTH) -> Array[Vector2i]:
	var extra := maxf(0.0, (length - VEHICLE_LENGTH) * 0.5)
	var steps := ceili(extra / BODY_STEP) if extra > 0.0 else 0
	var cells: Array[Vector2i] = []
	for i in range(-steps, steps + 1):
		var offset := extra * float(i) / float(steps) if steps > 0 else 0.0
		for cell in _vehicle_cells(path, distance + offset, tile_size):
			if not cells.has(cell): cells.append(cell)
	return cells

func _vehicle_cells(path: Curve2D, distance: float, tile_size: float) -> Array[Vector2i]:
	var total := path.get_baked_length()
	var point: Vector2
	var tangent: Vector2
	if distance < 0.0 or distance > total:
		var edge := total if distance > total else 0.0
		tangent = (path.sample_baked(minf(total, edge + 1.0)) - path.sample_baked(maxf(0.0, edge - 1.0))).normalized()
		point = path.sample_baked(edge) + tangent * (distance - edge)
	else:
		point = path.sample_baked(distance)
		tangent = (path.sample_baked(minf(total, distance + 1.0)) - path.sample_baked(maxf(0, distance - 1.0))).normalized()
	# Conservative rotated rectangle enclosing both current vehicle sprites.
	var extent := Vector2(absf(tangent.x) * 14 + absf(tangent.y) * 8, absf(tangent.y) * 14 + absf(tangent.x) * 8) + Vector2.ONE * 0.5
	var low := Vector2i(((point - extent) / tile_size).floor())
	var high := Vector2i(((point + extent) / tile_size).floor())
	var cells: Array[Vector2i] = []
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1): cells.append(Vector2i(x, y))
	return cells

static func train_length(train: Dictionary) -> float:
	return maxf(VEHICLE_LENGTH, float(train.get("length", VEHICLE_LENGTH)))

func rebuild(trains: Array, tracks: Dictionary, tile_size: float, request_ends: Dictionary = {}) -> void:
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
	for train in ordered:
		requested[int(train.id)] = []
		var length: float = train.path.get_baked_length()
		var direction := 1.0 if train.forward else -1.0
		var end: float = clampf(train.distance + direction * tile_size * LOOKAHEAD_TILES, 0, length) if train.moving else train.distance
		# A red signal limits future requests, not the protection of the body.
		if request_ends.has(train.id):
			end = clampf(float(request_ends[train.id]), minf(train.distance, end), maxf(train.distance, end))
		var spans := _route_spans(train.path, train.cells, tile_size)
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
			var low_index := _index_at(spans, distance - half)
			var high_index := _index_at(spans, distance + half)
			# Reserve the stem and selected exit with the switch, atomically.
			for i in range(1, train.cells.size() - 1):
				var cell: Vector2i = train.cells[i]
				if i < low_index - 1 or i > high_index + 1 or not required.has(cell) or not Geometry.is_switch(tracks.get(cell)):
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
			if blocked: break
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
				waits[id] = {"cell": cell, "owner": tile_owner, "kind": "track_reservation"}
				if tile_owner < 0: waits[id]["reason"] = "Waiting for track authority at %d,%d" % [cell.x, cell.y]
				return allowed
			if _switch_tiles.has(cell) and switch_owner != id:
				waits[id] = {"cell": cell, "owner": switch_owner, "kind": "switch_lock"}
				if switch_owner < 0: waits[id]["reason"] = "Waiting for switch authority at %d,%d" % [cell.x, cell.y]
				return allowed
		allowed = next
	return allowed

# Match each occurrence of a tile to its distance along the baked route. The
# same switch may be visited again on a later leg with a different exit.
func _route_spans(path: Curve2D, cells: Array[Vector2i], tile_size: float) -> Array:
	var spans: Array = [[0.0, 0]]
	if cells.is_empty(): return spans
	var index := 0
	var distance := 0.0
	var previous: Vector2 = path.get_baked_points()[0]
	for point in path.get_baked_points():
		distance += previous.distance_to(point)
		previous = point
		var cell := Vector2i((point / tile_size).floor())
		if index + 1 < cells.size() and cell == cells[index + 1]:
			index += 1
			spans.append([distance, index])
	return spans

func _index_at(spans: Array, distance: float) -> int:
	var index := 0
	for span in spans:
		if float(span[0]) > distance: break
		index = int(span[1])
	return index
