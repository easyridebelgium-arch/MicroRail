extends RefCounted


const Geometry = preload("res://scripts/track_geometry.gd")


static func connections(track_type: Variant) -> Array[Vector2i]:
	return Geometry.connections(track_type)


## Find a route using active connections at junctions.
## switch_states: {cell: [active_port_a, active_port_b]} for junctions
static func find_route(
	tracks: Dictionary,
	start: Vector2i,
	destination: Vector2i,
	switch_states: Dictionary = {}
) -> Array[Vector2i]:
	var empty_route: Array[Vector2i] = []

	if not tracks.has(start) or not tracks.has(destination):
		return empty_route

	var frontier: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var previous: Dictionary = {}
	var index: int = 0

	while index < frontier.size():
		var current: Vector2i = frontier[index]
		index += 1

		if current == destination:
			var route: Array[Vector2i] = [current]

			while current != start:
				current = previous[current]
				route.append(current)

			route.reverse()
			return route

		# Get active connections for this cell (use switch state if it's a junction)
		var current_type: Variant = tracks[current]
		var current_connections: Array[Vector2i]
		if Geometry.is_junction(current_type) and switch_states.has(current):
			current_connections = Geometry.active_connections(current_type, switch_states[current])
		else:
			current_connections = connections(current_type)

		for direction in current_connections:
			var neighbor: Vector2i = current + direction

			if visited.has(neighbor) or not tracks.has(neighbor):
				continue

			# Get active connections for neighbor
			var neighbor_type: Variant = tracks[neighbor]
			var neighbor_connections: Array[Vector2i]
			if Geometry.is_junction(neighbor_type) and switch_states.has(neighbor):
				neighbor_connections = Geometry.active_connections(neighbor_type, switch_states[neighbor])
			else:
				neighbor_connections = connections(neighbor_type)

			# Both pieces must connect across their shared edge.
			if not neighbor_connections.has(-direction):
				continue

			visited[neighbor] = true
			previous[neighbor] = current
			frontier.append(neighbor)

	return empty_route


static func make_path(cells: Array[Vector2i], tile_size: float) -> Curve2D:
	var path := Curve2D.new()
	path.bake_interval = 1.0
	if cells.size() < 2:
		return path
	var half: float = tile_size / 2.0
	for index in range(cells.size()):
		var origin: Vector2 = Vector2(cells[index]) * tile_size
		var center: Vector2 = origin + Vector2(half, half)
		if index == 0:
			_append_point(path, center)
			_append_point(path, center + Vector2(cells[1] - cells[0]) * half)
		elif index == cells.size() - 1:
			_append_point(path, center + Vector2(cells[index - 1] - cells[index]) * half)
			_append_point(path, center)
		else:
			for point in Geometry.centerline(cells[index - 1] - cells[index], cells[index + 1] - cells[index], tile_size):
				_append_point(path, origin + point)
	return path


static func _append_point(path: Curve2D, point: Vector2) -> void:
	if path.point_count > 0:
		var previous: Vector2 = path.get_point_position(
			path.point_count - 1
		)

		if previous.distance_to(point) < 0.001:
			return

	path.add_point(point)
