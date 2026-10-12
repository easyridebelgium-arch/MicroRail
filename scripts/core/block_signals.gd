extends RefCounted
## Signal tiles cut the network into conservative connected blocks. Authority
## is seeded from real body occupancy, then requested in permanent ID order.
const Geometry = preload("res://scripts/track_geometry.gd")
const Reservations = preload("res://scripts/core/track_reservations.gd")
var signs: Dictionary = {}
var cell_blocks: Dictionary = {}
var block_owners: Dictionary = {}
var _spans: Dictionary = {}
var _helper = Reservations.new()
var _network_hash := -1
var _sign_hash := -1

func configure(tracks: Dictionary, signals: Dictionary) -> void:
	if _network_hash == tracks.hash() and _sign_hash == signals.hash(): return
	_network_hash = tracks.hash()
	_sign_hash = signals.hash()
	signs = signals.duplicate()
	cell_blocks.clear()
	var id := 0
	for first in tracks:
		if signs.has(first) or cell_blocks.has(first): continue
		var pending: Array[Vector2i] = [first]
		cell_blocks[first] = id
		var index := 0
		while index < pending.size():
			var cell: Vector2i = pending[index]
			index += 1
			for direction in Geometry.connections(tracks[cell]):
				var next: Vector2i = cell + direction
				if not tracks.has(next) or signs.has(next) or cell_blocks.has(next): continue
				if not Geometry.connections(tracks[next]).has(-direction): continue
				cell_blocks[next] = id
				pending.append(next)
		id += 1

func update(trains: Array, occupied: Dictionary, tile_size: float) -> void:
	block_owners.clear()
	_spans.clear()
	if signs.is_empty(): return
	for cell in occupied:
		if not cell_blocks.has(cell): continue
		var block: int = cell_blocks[cell]
		if not block_owners.has(block): block_owners[block] = {}
		block_owners[block][int(occupied[cell])] = true
	var ordered := trains.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.id) < int(b.id))
	for train in ordered:
		var spans := _helper._route_spans(train.path, train.cells, tile_size)
		_spans[train.id] = spans
		if not train.moving: continue
		var direction := 1 if train.forward else -1
		var distance: float = train.distance
		var half := (Reservations.train_length(train) - Reservations.VEHICLE_LENGTH) * 0.5
		# Scan centre lookahead once; the occurrence index below shifts it to the nose.
		var end := clampf(distance + direction * tile_size * Reservations.LOOKAHEAD_TILES, 0, train.path.get_baked_length())
		var requested: Dictionary = {}
		while true:
			var index := _helper._index_at(spans, distance + direction * half)
			var cell: Vector2i = train.cells[index] if not train.cells.is_empty() else Vector2i(-1, -1)
			if signs.has(cell) and not requested.has(cell):
				requested[cell] = true
				if signs[cell] == "stop": break
				var block := _downstream(train.cells, index, direction)
				var owners: Dictionary = block_owners.get(block, {})
				if not _other_owner(owners, train.id).is_empty(): break
				if block >= 0:
					block_owners[block] = {int(train.id): true}
			if absf(distance - end) < 0.001: break
			distance = move_toward(distance, end, 1.0)

func limit(train: Dictionary, proposed: float, tile_size: float) -> Dictionary:
	if signs.is_empty(): return {"distance": proposed, "conflict": {}}
	var current: float = train.distance
	var allowed := current
	var body := Reservations.train_length(train)
	var half := (body - Reservations.VEHICLE_LENGTH) * 0.5
	var start_body := _helper.footprint(train.path, current, tile_size, body)
	var direction := 1 if proposed >= current else -1
	while absf(allowed - proposed) > 0.001:
		var next := move_toward(allowed, proposed, 1.0)
		var index := _helper._index_at(_spans.get(train.id, [[0.0, 0]]), next + direction * half)
		for cell in _helper.footprint(train.path, next, tile_size, body):
			if not signs.has(cell) or start_body.has(cell): continue
			var reason := ""
			var owner := -1
			if signs[cell] == "stop":
				reason = "Manual stop signal at %d,%d" % [cell.x, cell.y]
			else:
				var occurrence := -1
				for i in range(maxi(0, index - 1), mini(train.cells.size(), index + 2)):
					if train.cells[i] == cell: occurrence = i
				if occurrence < 0: continue
				var block := _downstream(train.cells, occurrence, direction)
				var owners: Dictionary = block_owners.get(block, {})
				var others := _other_owner(owners, train.id)
				if not others.is_empty():
					owner = int(others[0])
					reason = "Signal at %d,%d: block held by train #%d" % [cell.x, cell.y, owner]
				elif block >= 0 and not owners.has(int(train.id)):
					reason = "Signal at %d,%d: waiting for block authority" % [cell.x, cell.y]
			if not reason.is_empty(): return {"distance": allowed, "conflict": {"cell": cell, "owner": owner, "reason": reason}}
		allowed = next
	return {"distance": allowed, "conflict": {}}

func _downstream(cells: Array[Vector2i], index: int, direction: int) -> int:
	var next := index + direction
	while next >= 0 and next < cells.size():
		if cell_blocks.has(cells[next]): return int(cell_blocks[cells[next]])
		next += direction
	return -1

static func _other_owner(owners: Dictionary, id: int) -> Array:
	var result: Array = []
	for owner in owners:
		if int(owner) != id: result.append(int(owner))
	result.sort()
	return result
