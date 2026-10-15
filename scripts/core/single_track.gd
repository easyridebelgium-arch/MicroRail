extends RefCounted
## Single-track section holds. Two trains must not enter the same stretch of
## plain track from opposite ends: neither could ever back out, and tile
## reservations only see a few tiles ahead. A train leaving a stop therefore
## claims every plain tile on its way to its next stop (with its direction of
## travel) and waits at the stop while an opposing train's claim overlaps it.
## Only sections bounded by switches at both ends count. Switch and crossing tiles are excluded (they have their own locks, and they
## are where trains pass). Pure data: no scene or save state.
const Geometry = preload("res://scripts/track_geometry.gd")
const SAMPLE_STEP := 4.0
const ARRIVAL_TOLERANCE := 0.6

## True when walking both ways from a plain tile reaches a switch or crossing
## before any open track end. Runs that end in a dead end or station stub are
## approaches, not passing-place-to-passing-place sections, so they are not held.
static func bounded(tracks: Dictionary, cell: Vector2i, cache: Dictionary) -> bool:
	if cache.has(cell): return cache[cell]
	var run: Array[Vector2i] = [cell]
	var result := true
	var ports: Array[Vector2i] = Geometry.connections(tracks[cell])
	for start in ports:
		var previous := cell
		var current := cell + start
		var steps := 0
		while steps < 128:
			steps += 1
			if current == cell: break
			if not tracks.has(current):
				result = false
				break
			var connections: Array[Vector2i] = Geometry.connections(tracks[current])
			if not connections.has(previous - current):
				result = false
				break
			if connections.size() != 2: break
			run.append(current)
			var onward: Vector2i = connections[0] if connections[1] == previous - current else connections[1]
			previous = current
			current += onward
		if not result: break
	for member in run: cache[member] = result
	return result

## cell -> heading (Vector2i, each axis -1/0/1) for the plain tiles the path
## crosses between distances `from` and `to`.
static func corridor(path: Curve2D, from: float, to: float, tracks: Dictionary, tile_size: float) -> Dictionary:
	var result: Dictionary = {}
	var cache: Dictionary = {}
	if path == null or path.point_count < 2 or absf(to - from) < 0.001: return result
	var travel_sign := 1.0 if to > from else -1.0
	var length := path.get_baked_length()
	var d := clampf(from, 0.0, length)
	var end := clampf(to, 0.0, length)
	while (end - d) * travel_sign > -0.001:
		var ahead := clampf(d + travel_sign * SAMPLE_STEP, 0.0, length)
		var here := path.sample_baked(d)
		var delta := path.sample_baked(ahead) - here
		var cell := Vector2i(floori(here.x / tile_size), floori(here.y / tile_size))
		if tracks.has(cell) and Geometry.connections(tracks[cell]).size() == 2 and delta.length() > 0.01 and bounded(tracks, cell, cache):
			var direction := delta.normalized()
			var heading := Vector2i(roundi(direction.x), roundi(direction.y))
			if heading != Vector2i.ZERO and not result.has(cell): result[cell] = heading
		if absf(d - end) < 0.001: break
		d = clampf(d + travel_sign * SAMPLE_STEP, minf(from, end), maxf(from, end))
	return result

## Id of the first claimant whose corridor crosses `mine` head-on, else -1.
## `claims` is {id: {"corridor": Dictionary, ...}}; `ignore` is the asking train.
static func conflict(mine: Dictionary, claims: Dictionary, ignore: int) -> int:
	var ids: Array = claims.keys()
	ids.sort()
	for id in ids:
		if int(id) == ignore: continue
		var theirs: Dictionary = claims[id].get("corridor", {})
		for cell in mine:
			if theirs.has(cell) and theirs[cell] == -mine[cell]: return int(id)
	return -1

## Cells where `mine` and `theirs` are travelled head-on.
static func overlap(mine: Dictionary, theirs: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in mine:
		if theirs.has(cell) and theirs[cell] == -mine[cell]: result.append(cell)
	return result
