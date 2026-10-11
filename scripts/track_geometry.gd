extends RefCounted

# Ports are clockwise from north. Simple tracks have 2 ports; junctions have 3 or 4.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)
]
static var _drawing_cache: Dictionary = {}

## Returns all possible connection ports for a track type.
## For simple tracks: 2 ports.
## For T-junctions: 3 ports (junction_a_b_c).
## For cross junctions: 4 ports (cross_a_b_c_d).
static func connections(track_type: Variant) -> Array[Vector2i]:
	var ports: Array[Vector2i] = []
	if typeof(track_type) == TYPE_BOOL:
		ports.assign([Vector2i.UP, Vector2i.DOWN] if track_type else [Vector2i.RIGHT, Vector2i.LEFT])
		return ports
	if typeof(track_type) != TYPE_STRING:
		return ports

	# Simple diagonal curves
	match track_type:
		"NE": ports.assign([Vector2i.UP, Vector2i.RIGHT])
		"SE": ports.assign([Vector2i.RIGHT, Vector2i.DOWN])
		"SW": ports.assign([Vector2i.DOWN, Vector2i.LEFT])
		"NW": ports.assign([Vector2i.UP, Vector2i.LEFT])
	if not ports.is_empty():
		return ports

	var parts: PackedStringArray = track_type.split("_")

	# Simple rail tracks: rail_a_b
	if parts.size() == 3 and parts[0] == "rail":
		if not parts[1].is_valid_int() or not parts[2].is_valid_int():
			return ports
		var a: int = int(parts[1])
		var b: int = int(parts[2])
		if a < 0 or b > 7 or a >= b or mini(b - a, 8 - b + a) < 2:
			return ports
		if track_type != "rail_%d_%d" % [a, b]:
			return ports
		ports.assign([DIRECTIONS[a], DIRECTIONS[b]])
		return ports

	# T-junction: junction_a_b_c (three ports)
	if parts.size() == 4 and parts[0] == "junction":
		if not parts[1].is_valid_int() or not parts[2].is_valid_int() or not parts[3].is_valid_int():
			return ports
		var a: int = int(parts[1])
		var b: int = int(parts[2])
		var c: int = int(parts[3])
		if a < 0 or b < 0 or c < 0 or a > 7 or b > 7 or c > 7:
			return ports
		if a == b or b == c or a == c:
			return ports
		ports.assign([DIRECTIONS[a], DIRECTIONS[b], DIRECTIONS[c]])
		return ports

	# Cross junction: cross_a_b_c_d (four ports)
	if parts.size() == 5 and parts[0] == "cross":
		if not parts[1].is_valid_int() or not parts[2].is_valid_int() or not parts[3].is_valid_int() or not parts[4].is_valid_int():
			return ports
		var a: int = int(parts[1])
		var b: int = int(parts[2])
		var c: int = int(parts[3])
		var d: int = int(parts[4])
		if a < 0 or b < 0 or c < 0 or d < 0 or a > 7 or b > 7 or c > 7 or d > 7:
			return ports
		if a == b or b == c or c == d or a == c or a == d or b == d:
			return ports
		ports.assign([DIRECTIONS[a], DIRECTIONS[b], DIRECTIONS[c], DIRECTIONS[d]])
		return ports

	return ports


## Returns true if this track type is a junction (has 3 or 4 ports).
static func is_junction(track_type: Variant) -> bool:
	return connections(track_type).size() >= 3


## Returns the active connection ports for a junction given its switch state.
## For simple tracks (2 ports), returns all connections (no switch state needed).
## For junctions, switch_state should be a pair of port indices: [port_a, port_b]
## Returns empty array if switch state is invalid for this track type.
static func active_connections(track_type: Variant, switch_state: Array[Vector2i] = []) -> Array[Vector2i]:
	var all_ports: Array[Vector2i] = connections(track_type)

	# Simple tracks: all ports are always active
	if all_ports.size() == 2:
		return all_ports

	# Junctions need a valid switch state
	if switch_state.size() != 2:
		return []

	var port_a: Vector2i = switch_state[0]
	var port_b: Vector2i = switch_state[1]

	if not all_ports.has(port_a) or not all_ports.has(port_b):
		return []

	return [port_a, port_b]


## Returns the default active ports for a junction (used when no state is set).
## For T-junctions: the two ports that are most likely to be the "through" path.
## For cross junctions: the two opposite ports that form a straight line.
static func default_active_ports(track_type: Variant) -> Array[Vector2i]:
	var all_ports: Array[Vector2i] = connections(track_type)

	if all_ports.size() != 3 and all_ports.size() != 4:
		return []

	# For cross junctions, find opposite ports
	if all_ports.size() == 4:
		for i in range(all_ports.size()):
			for j in range(i + 1, all_ports.size()):
				if all_ports[i] == -all_ports[j]:
					return [all_ports[i], all_ports[j]]

	# For T-junctions, return the first two (convention)
	return [all_ports[0], all_ports[1]]


static func from_ports(first: Vector2i, second: Vector2i) -> Variant:
	var a: int = DIRECTIONS.find(first)
	var b: int = DIRECTIONS.find(second)
	if a < 0 or b < 0:
		return null
	if a > b:
		var temporary: int = a
		a = b
		b = temporary
	if mini(b - a, 8 - b + a) < 2:
		return null
	if a == 0 and b == 4: return true
	if a == 2 and b == 6: return false
	if a == 0 and b == 2: return "NE"
	if a == 2 and b == 4: return "SE"
	if a == 4 and b == 6: return "SW"
	if a == 0 and b == 6: return "NW"
	return "rail_%d_%d" % [a, b]


## Create a junction type from 3 or 4 ports.
## For 3 ports: T-junction (junction_a_b_c)
## For 4 ports: Cross junction (cross_a_b_c_d)
## Returns null if invalid (not 3 or 4 ports, or invalid port indices)
static func from_ports_junction(ports: Array[Vector2i]) -> Variant:
	if ports.size() != 3 and ports.size() != 4:
		return null

	var indices: Array[int] = []
	for port in ports:
		var idx: int = DIRECTIONS.find(port)
		if idx < 0:
			return null
		indices.append(idx)

	# Check for duplicates
	var seen: Dictionary = {}
	for idx in indices:
		if seen.has(idx):
			return null
		seen[idx] = true

	indices.sort()

	if ports.size() == 3:
		return "junction_%d_%d_%d" % [indices[0], indices[1], indices[2]]
	else:
		return "cross_%d_%d_%d_%d" % [indices[0], indices[1], indices[2], indices[3]]


static func same_connections(first: Variant, second: Variant) -> bool:
	var a: Array[Vector2i] = connections(first)
	var b: Array[Vector2i] = connections(second)
	# For simple tracks, compare exact connections
	if a.size() == 2 and b.size() == 2:
		return b.has(a[0]) and b.has(a[1])
	# For junctions, compare all possible ports (regardless of switch state)
	return a.size() == b.size() and a.size() >= 3


static func centerline(entry: Vector2i, exit_port: Vector2i, tile_size: float) -> PackedVector2Array:
	var center := Vector2.ONE * tile_size / 2.0
	var first: Vector2 = center + Vector2(entry) * tile_size / 2.0
	var last: Vector2 = center + Vector2(exit_port) * tile_size / 2.0
	if entry == -exit_port:
		return PackedVector2Array([first, last])
	# Both rendering and train movement use this same rounded bend.
	var points := PackedVector2Array()
	for sample in range(17):
		var t: float = float(sample) / 16.0
		points.append(first * (1.0 - t) * (1.0 - t) + center * 2.0 * t * (1.0 - t) + last * t * t)
	return points


static func drawing_data(track_type: Variant, tile_size: float) -> Dictionary:
	var key: String = str(track_type) + ":" + str(tile_size)
	if _drawing_cache.has(key):
		return _drawing_cache[key]
	var ports: Array[Vector2i] = connections(track_type)
	if ports.size() != 2:
		return {}
	var points: PackedVector2Array = centerline(ports[0], ports[1], tile_size)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var curve := Curve2D.new()
	curve.bake_interval = 1.0
	for index in range(points.size()):
		var tangent: Vector2
		if index == 0:
			tangent = -Vector2(ports[0]).normalized()
		elif index == points.size() - 1:
			tangent = Vector2(ports[1]).normalized()
		else:
			tangent = (points[index + 1] - points[index - 1]).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		left.append(points[index] + normal * 6.0)
		right.append(points[index] - normal * 6.0)
		curve.add_point(points[index])
	var sleepers := PackedVector2Array()
	var length: float = curve.get_baked_length()
	var distance: float = 4.0
	while distance < length:
		var center: Vector2 = curve.sample_baked(distance)
		var tangent: Vector2 = (curve.sample_baked(minf(distance + 0.5, length)) - curve.sample_baked(maxf(distance - 0.5, 0.0))).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		sleepers.append(center - normal * 10.0)
		sleepers.append(center + normal * 10.0)
		distance += 8.0
	var result: Dictionary = {"left": left, "right": right, "sleepers": sleepers}
	_drawing_cache[key] = result
	return result
