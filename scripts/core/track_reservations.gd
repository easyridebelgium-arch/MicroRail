extends RefCounted
## Transient ownership rebuilt before each fixed tick. Occupancy comes first,
## then requests in permanent fleet-ID order. Movement consumes these grants.
const Geometry = preload("res://scripts/track_geometry.gd")
const LOOKAHEAD_TILES := 3.0
const SAMPLE_STEP := 1.0
var owners: Dictionary = {}
var occupied_owners: Dictionary = {}
var switches: Dictionary = {}
var switch_owners: Dictionary = {}
var _switch_tiles: Dictionary = {}
var waits: Dictionary = {}
var _overlapping: Dictionary = {}

func footprint(path: Curve2D, distance: float, tile_size: float) -> Array[Vector2i]:
	var point := path.sample_baked(distance)
	var tangent := (path.sample_baked(minf(path.get_baked_length(), distance + 1.0)) - path.sample_baked(maxf(0, distance - 1.0))).normalized()
	# Conservative rotated rectangle enclosing both current vehicle sprites.
	var extent := Vector2(absf(tangent.x) * 14 + absf(tangent.y) * 8, absf(tangent.y) * 14 + absf(tangent.x) * 8) + Vector2.ONE * 0.5
	var low := Vector2i(((point - extent) / tile_size).floor())
	var high := Vector2i(((point + extent) / tile_size).floor())
	var cells: Array[Vector2i] = []
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1): cells.append(Vector2i(x, y))
	return cells

func rebuild(trains: Array, tracks: Dictionary, tile_size: float) -> void:
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
		for cell in footprint(train.path, train.distance, tile_size):
			if owners.has(cell) and owners[cell] != train.id:
				waits[train.id] = {"cell": cell, "owner": owners[cell]}
				waits[owners[cell]] = {"cell": cell, "owner": train.id}
				_overlapping[train.id] = true
				_overlapping[owners[cell]] = true
			else: owners[cell] = train.id
	occupied_owners = owners.duplicate()
	for train in ordered:
		var length: float = train.path.get_baked_length()
		var direction := 1.0 if train.forward else -1.0
		var end: float = clampf(train.distance + direction * tile_size * LOOKAHEAD_TILES, 0, length) if train.moving else train.distance
		var spans := _route_spans(train.path, train.cells, tile_size)
		var distance: float = train.distance
		while true:
			var required := footprint(train.path, distance, tile_size)
			var settings: Dictionary = {}
			var route_index := _index_at(spans, distance)
			# Reserve the stem and selected exit with the switch, atomically.
			for i in range(1, train.cells.size() - 1):
				var cell: Vector2i = train.cells[i]
				if absi(i - route_index) > 1 or not required.has(cell) or not Geometry.is_switch(tracks.get(cell)):
					continue
				for neighbor in [train.cells[i - 1], train.cells[i + 1]]:
					if not required.has(neighbor): required.append(neighbor)
				var state: int = Geometry.state_for(tracks[cell], train.cells[i - 1] - cell, train.cells[i + 1] - cell)
				# state_for handles both facing and trailing moves.
				if state < 0:
					state = Geometry.state_for(tracks[cell], train.cells[i + 1] - cell, train.cells[i - 1] - cell)
				if state >= 0: settings[cell] = state
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
			distance = move_toward(distance, end, SAMPLE_STEP)

func limit(id: int, path: Curve2D, current: float, proposed: float, tile_size: float) -> float:
	if _overlapping.has(id): return current
	var allowed := current
	while absf(allowed - proposed) > 0.001:
		var next := move_toward(allowed, proposed, SAMPLE_STEP)
		for cell in footprint(path, next, tile_size):
			if int(owners.get(cell, -1)) != id or (_switch_tiles.has(cell) and int(switch_owners.get(cell, -1)) != id):
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
