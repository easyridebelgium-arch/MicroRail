extends RefCounted


const Geometry = preload("res://scripts/track_geometry.gd")


static func connections(track_type: Variant) -> Array[Vector2i]:
	return Geometry.connections(track_type)


## Shortest route between two tiles, as a list of cells. Planning ignores the
## current switch positions: the route is found over every move a train could
## make, and find_path() reports which switch settings it needs.
static func find_route(
	tracks: Dictionary,
	start: Vector2i,
	destination: Vector2i
) -> Array[Vector2i]:
	return find_path(tracks, start, destination)["cells"]


## Like find_route, but returns {"cells": Array[Vector2i], "switches": Dictionary}.
## "switches" maps each switch tile the route enters through its stem to the
## state it needs (0 through, 1 branch). Trailing moves need no setting.
##
## The search runs over (tile, port the train entered through), so a switch
## never lets a train pass from one exit straight to the other, and a crossing
## never lets it change line.
static func find_path(
	tracks: Dictionary,
	start: Vector2i,
	destination: Vector2i
) -> Dictionary:
	var empty_cells: Array[Vector2i] = []
	var result: Dictionary = {"cells": empty_cells, "switches": {}}

	if not tracks.has(start) or not tracks.has(destination):
		return result

	if start == destination:
		var single: Array[Vector2i] = [start]
		result["cells"] = single
		return result

	# A state is (cell, entry port index); the start has no entry port (-1).
	var first_state := Vector3i(start.x, start.y, -1)
	var frontier: Array[Vector3i] = [first_state]
	var visited: Dictionary = {first_state: true}
	var previous: Dictionary = {}
	var index: int = 0

	while index < frontier.size():
		var state: Vector3i = frontier[index]
		index += 1
		var current := Vector2i(state.x, state.y)

		var exits: Array[Vector2i]
		if state.z < 0:
			exits = Geometry.connections(tracks[current])
		else:
			exits = Geometry.exits_from(tracks[current], Geometry.DIRECTIONS[state.z])

		for direction in exits:
			var neighbor: Vector2i = current + direction

			if not tracks.has(neighbor):
				continue

			# The neighbour must accept a train arriving through the shared edge.
			var entry: Vector2i = -direction

			if Geometry.exits_from(tracks[neighbor], entry).is_empty():
				continue

			var next_state := Vector3i(neighbor.x, neighbor.y, Geometry.DIRECTIONS.find(entry))

			if visited.has(next_state):
				continue

			visited[next_state] = true
			previous[next_state] = state

			if neighbor == destination:
				return _build_result(tracks, next_state, previous)

			frontier.append(next_state)

	return result


static func _build_result(tracks: Dictionary, last: Vector3i, previous: Dictionary) -> Dictionary:
	var states: Array[Vector3i] = [last]

	while previous.has(states.back()):
		states.append(previous[states.back()])

	states.reverse()

	var cells: Array[Vector2i] = []
	var switches: Dictionary = {}

	for position in range(states.size()):
		var state: Vector3i = states[position]
		var cell := Vector2i(state.x, state.y)
		cells.append(cell)

		# Leaving a switch through its stem side needs the right setting.
		if state.z >= 0 and position + 1 < states.size():
			var following := Vector2i(states[position + 1].x, states[position + 1].y)
			var needed: int = Geometry.state_for(tracks[cell], Geometry.DIRECTIONS[state.z], following - cell)

			if needed >= 0:
				switches[cell] = needed

	return {"cells": cells, "switches": switches}


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
