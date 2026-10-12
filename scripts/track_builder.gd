extends RefCounted

const Geometry = preload("res://scripts/track_geometry.gd")


static func segment(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [start]
	var current: Vector2i = start
	while current != finish:
		var offset: Vector2i = finish - current
		current += Vector2i(signi(offset.x), signi(offset.y))
		cells.append(current)
	return cells


static func line(start: Vector2i, finish: Vector2i, tracks: Dictionary, fixed: Array[Vector2i] = []) -> Array[Vector2i]:
	if start == finish:
		return segment(start, finish)
	var direct: Vector2i = finish - start
	# A one-cell gesture off an existing endpoint is just its straight lead-out.
	# Do not manufacture extra cells to bend toward a nearby off-axis pointer.
	if tracks.has(start) and not _can_branch(start, tracks, fixed) and not tracks.has(finish) and maxi(absi(direct.x), absi(direct.y)) == 1:
		var extension: Array[Vector2i] = [start, start + _endpoint_port(start, finish, tracks)]
		return extension
	if direct.x == 0 or direct.y == 0 or absi(direct.x) == absi(direct.y):
		var direction := Vector2i(signi(direct.x), signi(direct.y))
		if (not tracks.has(start) or Geometry.connections(tracks[start]).has(direction) or _can_branch(start, tracks, fixed)) and (not tracks.has(finish) or Geometry.connections(tracks[finish]).has(-direction) or _can_branch(finish, tracks, fixed)):
			return segment(start, finish)
	var first: Vector2i = start
	var last: Vector2i = finish
	var cells: Array[Vector2i] = [start]
	if tracks.has(start) and not _can_branch(start, tracks, fixed):
		# Preserve a full straight tile beyond the existing rail's exit.
		# The following tile may bend toward the pointer.
		var port: Vector2i = _endpoint_port(start, finish, tracks)
		cells.append(start + port)
		first = start + port * 2
	if tracks.has(finish) and not _can_branch(finish, tracks, fixed):
		last += _endpoint_port(finish, start, tracks)
	for cell in segment(first, last):
		if cell != cells.back():
			cells.append(cell)
	if cells.back() != finish:
		cells.append(finish)
	return cells


static func _can_branch(cell: Vector2i, tracks: Dictionary, fixed: Array[Vector2i]) -> bool:
	if fixed.has(cell) or not tracks.has(cell) or not Geometry.is_straight(tracks[cell]): return false
	for port in Geometry.connections(tracks[cell]):
		if not tracks.has(cell + port) or not Geometry.connections(tracks[cell + port]).has(-port): return false
	return true


static func _automatic_switch(old: Variant, requested: Array[Vector2i]) -> Variant:
	if not Geometry.is_straight(old): return null
	var ports: Array[Vector2i] = Geometry.connections(old)
	var branches: Array[Vector2i] = []
	for port in requested:
		if not ports.has(port) and not branches.has(port): branches.append(port)
	if branches.size() != 1: return null
	var branch: Vector2i = branches[0]
	var best: Variant = null
	var best_score: float = INF
	for stem in ports:
		var kind: Variant = Geometry.switch_type(stem, -stem, branch)
		if kind == null: continue
		var score: float = Vector2(stem).normalized().dot(Vector2(branch).normalized())
		if requested.has(stem): score -= 0.01
		if score < best_score:
			best = kind
			best_score = score
	return best


static func _endpoint_port(cell: Vector2i, toward: Vector2i, tracks: Dictionary) -> Vector2i:
	var best: Vector2i = Vector2i.RIGHT
	var best_score: float = -INF
	for port in Geometry.connections(tracks[cell]):
		var score: float = Vector2(port).normalized().dot(Vector2(toward - cell).normalized())
		if score > best_score:
			best = port
			best_score = score
	return best


static func append_stroke(cells: Array[Vector2i], target: Vector2i) -> void:
	if cells.is_empty():
		cells.append(target)
		return
	var additions: Array[Vector2i] = segment(cells.back(), target)
	for index in range(1, additions.size()):
		var cell: Vector2i = additions[index]
		var previous_index: int = cells.find(cell)
		if previous_index >= 0:
			cells.resize(previous_index + 1)
		else:
			cells.append(cell)


static func plan(cells: Array[Vector2i], tracks: Dictionary, map_size: Vector2i, blocked: Callable, fixed: Array[Vector2i], single_direction: Vector2i = Vector2i.RIGHT) -> Dictionary:
	var result: Dictionary = {"tiles": {}, "changes": {}, "invalid": {}, "error": "", "new_count": 0, "switch_count": 0}
	if cells.is_empty():
		result["error"] = "Choose a tile to build track."
		return result
	var seen: Dictionary = {}
	for index in range(cells.size()):
		var cell: Vector2i = cells[index]
		if seen.has(cell):
			_fail(result, cell, "A drag cannot cross itself. Backtrack or use a new drag.")
			continue
		seen[cell] = true
		if cell.x < 0 or cell.y < 0 or cell.x >= map_size.x or cell.y >= map_size.y:
			_fail(result, cell, "Keep the route inside the map.")
			continue
		if blocked.call(cell):
			_fail(result, cell, "Station and industry grounds cannot contain track.")
			continue
		var first: Vector2i
		var second: Vector2i
		if cells.size() == 1:
			# A short stroke places one tile; an existing tile stays untouched.
			if tracks.has(cell):
				result["tiles"][cell] = tracks[cell]
				continue
			first = single_direction
			second = -first
		elif index == 0 or index == cells.size() - 1:
			var neighbor: Vector2i = cells[1] if index == 0 else cells[index - 1]
			first = neighbor - cell
			second = -first
			if tracks.has(cell):
				var old_ports: Array[Vector2i] = Geometry.connections(tracks[cell])
				if old_ports.has(first):
					second = old_ports[1] if old_ports[0] == first else old_ports[0]
				else:
					for port in old_ports:
						var old_neighbor: Vector2i = cell + port
						if tracks.has(old_neighbor) and Geometry.connections(tracks[old_neighbor]).has(-port):
							second = port
		else:
			first = cells[index - 1] - cell
			second = cells[index + 1] - cell
		var kind: Variant = Geometry.from_ports(first, second)
		if tracks.has(cell):
			var old: Variant = tracks[cell]
			var ports: Array[Vector2i] = Geometry.connections(old)
			if Geometry.is_switch(old) or Geometry.is_crossing(old):
				if not Geometry.exits_from(old, first).has(second):
					_fail(result, cell, "This junction cannot support that movement. Use another switch.")
					continue
				kind = old
			elif Geometry.is_straight(old) and (not ports.has(first) or not ports.has(second)):
				kind = _automatic_switch(old, [first, second])
				if kind == null:
					_fail(result, cell, "A switch supports one branch. Use separate junctions for more exits.")
					continue
		if kind == null:
			_fail(result, cell, "Turn too tight. Draw a wider bend.")
			continue
		result["tiles"][cell] = kind
		if tracks.has(cell):
			if Geometry.same_connections(tracks[cell], kind):
				continue
			if fixed.has(cell):
				_fail(result, cell, "Platform tracks stay horizontal. Leave or enter along their rails.")
				continue
			var new_ports: Array[Vector2i] = Geometry.connections(kind)
			for port in Geometry.connections(tracks[cell]):
				var neighbor: Vector2i = cell + port
				if tracks.has(neighbor) and Geometry.connections(tracks[neighbor]).has(-port) and not new_ports.has(port):
					_fail(result, cell, "This would break an existing connection. Use a switch or redraw the connection.")
		else:
			result["new_count"] += 1
		result["changes"][cell] = kind
	# A new end touching the side of an existing straight also needs a switch,
	# even if that existing tile wasn't explicitly included in the mouse stroke.
	for cell in result["tiles"].keys():
		if tracks.has(cell): continue
		for port in Geometry.connections(result["tiles"][cell]):
			var neighbor: Vector2i = cell + port
			if not tracks.has(neighbor): continue
			if result["tiles"].has(neighbor):
				if not Geometry.connections(result["tiles"][neighbor]).has(-port):
					_fail(result, neighbor, "This junction cannot support another connection. Use a separate switch.")
				continue
			if Geometry.connections(tracks[neighbor]).has(-port): continue
			if fixed.has(neighbor):
				_fail(result, neighbor, "Platform tracks stay horizontal. Leave or enter along their rails.")
				continue
			var switch_kind: Variant = _automatic_switch(tracks[neighbor], [-port])
			if switch_kind == null:
				_fail(result, neighbor, "Cannot add another connection here. Use a separate junction.")
				continue
			result["tiles"][neighbor] = switch_kind
			result["changes"][neighbor] = switch_kind
	for cell in result["changes"]:
		if Geometry.is_switch(result["changes"][cell]) and not Geometry.is_switch(tracks.get(cell)):
			result["switch_count"] += 1
	var proposed: Dictionary = tracks.duplicate()
	proposed.merge(result["tiles"], true)
	for cell in result["tiles"]:
		for port in Geometry.connections(result["tiles"][cell]):
			if port.x == 0 or port.y == 0:
				continue
			var side_a: Vector2i = cell + Vector2i(port.x, 0)
			var side_b: Vector2i = cell + Vector2i(0, port.y)
			if (proposed.has(side_a) and Geometry.connections(proposed[side_a]).has(Vector2i(-port.x, port.y))) or (proposed.has(side_b) and Geometry.connections(proposed[side_b]).has(Vector2i(port.x, -port.y))):
				_fail(result, cell, "Diagonal tracks cannot cross at a tile corner.")
	return result


static func _fail(result: Dictionary, cell: Vector2i, message: String) -> void:
	result["invalid"][cell] = true
	if result["error"].is_empty():
		result["error"] = message
