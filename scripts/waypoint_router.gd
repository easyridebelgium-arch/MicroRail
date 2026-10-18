extends RefCounted
## One port-aware search across the whole leg. Splitting shortest paths at
## waypoints would forget the entry port and allow illegal branch-to-branch turns.
const Router = preload("res://scripts/rail_router.gd")
const Geometry = preload("res://scripts/track_geometry.gd")

static func find_route(tracks: Dictionary, start: Vector2i, destination: Vector2i, points: Array) -> Array[Vector2i]:
	if points.is_empty(): return Router.find_route(tracks, start, destination)
	var empty: Array[Vector2i] = []
	if not tracks.has(start) or not tracks.has(destination): return empty
	var required: Array[Vector2i] = []
	for point in points:
		var cell := Vector2i(int(point[0]), int(point[1]))
		if not tracks.has(cell): return empty
		required.append(cell)
	var first := Vector4i(start.x, start.y, -1, 0)
	var frontier: Array[Vector4i] = [first]
	var visited: Dictionary = {first: true}
	var previous: Dictionary = {}
	var index := 0
	while index < frontier.size():
		var state := frontier[index]
		index += 1
		var current := Vector2i(state.x, state.y)
		var exits := Geometry.connections(tracks[current]) if state.z < 0 else Geometry.exits_from(tracks[current], Geometry.DIRECTIONS[state.z])
		for direction in exits:
			var next: Vector2i = current + direction
			if not tracks.has(next) or Geometry.exits_from(tracks[next], -direction).is_empty(): continue
			var progress: int = state.w
			if progress < required.size() and next == required[progress]: progress += 1
			# A destination platform is the stopping point, not an incidental
			# pass-through before the directives have been completed.
			if next == destination and progress < required.size(): continue
			var candidate := Vector4i(next.x, next.y, Geometry.DIRECTIONS.find(-direction), progress)
			if visited.has(candidate): continue
			visited[candidate] = true
			previous[candidate] = state
			if next == destination:
				var states: Array[Vector4i] = [candidate]
				while previous.has(states[-1]): states.append(previous[states[-1]])
				states.reverse()
				var result: Array[Vector2i] = []
				for entry in states: result.append(Vector2i(entry.x, entry.y))
				return result
			frontier.append(candidate)
	return empty
