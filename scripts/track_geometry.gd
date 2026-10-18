extends RefCounted

# Ports are directions from the middle of a tile toward a neighbour, clockwise
# from north (index 0..7). A train entering a tile from the neighbour at
# cell + d enters through port d.
#
# Tile kinds:
#   simple    bool, "NE"/"SE"/"SW"/"NW" or "rail_a_b": exactly two ports.
#   switch    "junction_<stem>_<through>_<branch>": port indices in that fixed
#             order. Stem<->through and stem<->branch are ordinary rail shapes.
#             The two exits are never connected to each other. State 0 sends
#             a train from the stem to the through exit, state 1 to the branch.
#             Trains entering from an exit always leave through the stem.
#   crossing  "cross_<a>_<b>" (0 <= a < b <= 3): two straight lines, a<->a+4 and
#             b<->b+4, always both usable. A train cannot change line.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)
]
static var _drawing_cache: Dictionary = {}


## All ports of a tile. Simple: two. Switch: [stem, through, branch].
## Crossing: [a, a+4, b, b+4]. Invalid or unknown: empty.
static func connections(track_type: Variant) -> Array[Vector2i]:
	var ports: Array[Vector2i] = []
	if typeof(track_type) == TYPE_BOOL:
		ports.assign([Vector2i.UP, Vector2i.DOWN] if track_type else [Vector2i.RIGHT, Vector2i.LEFT])
		return ports
	if typeof(track_type) != TYPE_STRING:
		return ports

	match track_type:
		"NE": ports.assign([Vector2i.UP, Vector2i.RIGHT])
		"SE": ports.assign([Vector2i.RIGHT, Vector2i.DOWN])
		"SW": ports.assign([Vector2i.DOWN, Vector2i.LEFT])
		"NW": ports.assign([Vector2i.UP, Vector2i.LEFT])
	if not ports.is_empty():
		return ports

	var parts: PackedStringArray = track_type.split("_")

	if parts.size() == 3 and parts[0] == "rail":
		var rail: Array[int] = _indices(parts, 1)
		if rail.size() != 2 or rail[0] >= rail[1] or not _valid_bend(rail[0], rail[1]):
			return ports
		if track_type != "rail_%d_%d" % [rail[0], rail[1]]:
			return ports
		ports.assign([DIRECTIONS[rail[0]], DIRECTIONS[rail[1]]])
		return ports

	if parts.size() == 4 and parts[0] == "junction":
		var sw: Array[int] = _indices(parts, 1)
		if sw.size() != 3 or sw[1] == sw[2]:
			return ports
		if not _valid_bend(sw[0], sw[1]) or not _valid_bend(sw[0], sw[2]):
			return ports
		if track_type != "junction_%d_%d_%d" % [sw[0], sw[1], sw[2]]:
			return ports
		ports.assign([DIRECTIONS[sw[0]], DIRECTIONS[sw[1]], DIRECTIONS[sw[2]]])
		return ports

	if parts.size() == 3 and parts[0] == "cross":
		var lines: Array[int] = _indices(parts, 1)
		if lines.size() != 2 or lines[0] < 0 or lines[0] >= lines[1] or lines[1] > 3:
			return ports
		if track_type != "cross_%d_%d" % [lines[0], lines[1]]:
			return ports
		ports.assign([DIRECTIONS[lines[0]], DIRECTIONS[lines[0] + 4], DIRECTIONS[lines[1]], DIRECTIONS[lines[1] + 4]])
		return ports

	return ports


# Port indices from parts[start..]; empty if any is not a plain 0..7 integer.
static func _indices(parts: PackedStringArray, start: int) -> Array[int]:
	var result: Array[int] = []
	for index in range(start, parts.size()):
		if not parts[index].is_valid_int():
			return []
		var value: int = int(parts[index])
		if value < 0 or value > 7 or str(value) != parts[index]:
			return []
		result.append(value)
	return result


# Two ports form a track piece only if they are at least 90 degrees apart.
static func _valid_bend(a: int, b: int) -> bool:
	var gap: int = absi(a - b)
	return a != b and mini(gap, 8 - gap) >= 2


static func is_switch(track_type: Variant) -> bool:
	return typeof(track_type) == TYPE_STRING and track_type.begins_with("junction_") and connections(track_type).size() == 3


static func is_crossing(track_type: Variant) -> bool:
	return typeof(track_type) == TYPE_STRING and track_type.begins_with("cross_") and connections(track_type).size() == 4


## True for switches (kept for older callers); crossings have no state.
static func is_junction(track_type: Variant) -> bool:
	return is_switch(track_type)


## Every exit a train may take after entering through `entry`, whatever the
## switch is set to. Used for planning; empty if the move is impossible.
static func exits_from(track_type: Variant, entry: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var ports: Array[Vector2i] = connections(track_type)

	if not ports.has(entry):
		return result

	if is_switch(track_type):
		if entry == ports[0]:
			result.assign([ports[1], ports[2]])
		else:
			result.assign([ports[0]])
	elif is_crossing(track_type):
		result.assign([-entry])
	else:
		result.assign([ports[1] if entry == ports[0] else ports[0]])

	return result


## The exit a train actually takes, given the switch state (0 through, 1 branch;
## anything else counts as 0). Vector2i.ZERO means the move is impossible.
static func exit_for(track_type: Variant, entry: Vector2i, state: int = 0) -> Vector2i:
	var options: Array[Vector2i] = exits_from(track_type, entry)

	if options.is_empty():
		return Vector2i.ZERO

	if is_switch(track_type) and entry == connections(track_type)[0] and state == 1:
		return options[1]

	return options[0]


## The switch state needed to leave through `exit` when entering through the
## stem: 0 or 1. -1 when no setting is involved (not a switch, or a trailing move)
## or when the move is impossible.
static func state_for(track_type: Variant, entry: Vector2i, exit: Vector2i) -> int:
	if not is_switch(track_type):
		return -1

	var ports: Array[Vector2i] = connections(track_type)

	if entry != ports[0]:
		return -1

	if exit == ports[1]:
		return 0

	if exit == ports[2]:
		return 1

	return -1


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


## Builds a switch type from its ports. Null if the shape is not allowed.
static func switch_type(stem: Vector2i, through: Vector2i, branch: Vector2i) -> Variant:
	var indices: Array[int] = [DIRECTIONS.find(stem), DIRECTIONS.find(through), DIRECTIONS.find(branch)]
	if indices.has(-1):
		return null
	var kind: String = "junction_%d_%d_%d" % [indices[0], indices[1], indices[2]]
	if connections(kind).is_empty(): return null
	return kind


## Builds a crossing from one port of each of its two lines. Null if both
## ports belong to the same line.
static func crossing_type(first: Vector2i, second: Vector2i) -> Variant:
	var a: int = DIRECTIONS.find(first)
	var b: int = DIRECTIONS.find(second)
	if a < 0 or b < 0:
		return null
	a %= 4
	b %= 4
	if a == b:
		return null
	return "cross_%d_%d" % [mini(a, b), maxi(a, b)]


## True for a simple tile whose two ports are opposite (a straight piece).
static func is_straight(track_type: Variant) -> bool:
	var ports: Array[Vector2i] = connections(track_type)
	return ports.size() == 2 and ports[0] == -ports[1]


## The straight piece a tile is built on: the tile itself if straight, or a
## switch's stem and through ports as a straight. Null for anything else.
static func straight_base(track_type: Variant) -> Variant:
	if is_straight(track_type):
		return track_type

	if is_switch(track_type):
		var ports: Array[Vector2i] = connections(track_type)
		if ports[0] == -ports[1]:
			return from_ports(ports[0], ports[1])

	return null


## Original two-port connection, including the curve beneath an automatic switch.
static func switch_base(track_type: Variant) -> Variant:
	var ports: Array[Vector2i] = connections(track_type)
	if ports.size() == 2: return track_type
	if is_switch(track_type): return from_ports(ports[0], ports[1])
	return null


## Every switch that can replace a straight tile without changing where its
## stem and through ports are: either end may be the stem, and the branch may
## leave on any side that makes a valid piece with the stem. Ordered.
static func switch_variants(straight: Variant) -> Array:
	if not is_straight(straight):
		return []
	return _base_switch_variants(straight)


static func _base_switch_variants(base: Variant) -> Array:
	var result: Array = []
	var ports: Array[Vector2i] = connections(base)
	if ports.size() != 2: return result

	for stem_index in range(2):
		var stem: Vector2i = ports[stem_index]
		var through: Vector2i = ports[1 - stem_index]

		for branch in DIRECTIONS:
			if branch == stem or branch == through:
				continue

			var kind: Variant = switch_type(stem, through, branch)

			if kind != null:
				result.append(kind)

	return result


## What clicking a tile with the Switch tool turns it into: a straight becomes
## the first switch variant, each switch becomes the next variant, and the last
## restores its original straight or curve. Null for unsupported manual placement.
static func next_switch_variant(track_type: Variant) -> Variant:
	var base: Variant = switch_base(track_type) if is_switch(track_type) else straight_base(track_type)

	if base == null:
		return null

	var variants: Array = _base_switch_variants(base)

	if variants.is_empty():
		return null

	if not is_switch(track_type):
		return variants[0]

	var position: int = variants.find(track_type)

	if position < 0 or position + 1 >= variants.size():
		return base

	return variants[position + 1]


## Whether two tiles have identical ports. Simple tiles compare their two
## ports in any order; switches and crossings must match exactly (a switch
## with a different stem is a different tile).
static func same_connections(first: Variant, second: Variant) -> bool:
	var a: Array[Vector2i] = connections(first)
	var b: Array[Vector2i] = connections(second)
	if a.size() != b.size() or a.size() < 2:
		return false
	if a.size() == 2:
		return b.has(a[0]) and b.has(a[1])
	return typeof(first) == TYPE_STRING and typeof(second) == TYPE_STRING and first == second


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


## The port pairs that are drawn as rails: one for a simple tile, stem-through
## and stem-branch for a switch, the two lines for a crossing.
static func drawing_pairs(track_type: Variant) -> Array:
	var ports: Array[Vector2i] = connections(track_type)

	if ports.size() == 2:
		return [[ports[0], ports[1]]]

	if is_switch(track_type):
		return [[ports[0], ports[1]], [ports[0], ports[2]]]

	if is_crossing(track_type):
		return [[ports[0], ports[1]], [ports[2], ports[3]]]

	return []


## Rail outlines for a tile: {"left", "right", "sleepers"} for the first path
## plus "extra", the same dictionaries for any further paths (switch branch,
## second crossing line). Empty for an unknown tile.
static func drawing_data(track_type: Variant, tile_size: float) -> Dictionary:
	var key: String = str(track_type) + ":" + str(tile_size)
	if _drawing_cache.has(key):
		return _drawing_cache[key]
	var pairs: Array = drawing_pairs(track_type)
	if pairs.is_empty():
		return {}
	var result: Dictionary = _pair_geometry(pairs[0][0], pairs[0][1], tile_size)
	var extra: Array = []
	for index in range(1, pairs.size()):
		extra.append(_pair_geometry(pairs[index][0], pairs[index][1], tile_size))
	result["extra"] = extra
	_drawing_cache[key] = result
	return result


static func _pair_geometry(first_port: Vector2i, second_port: Vector2i, tile_size: float) -> Dictionary:
	var ports: Array[Vector2i] = [first_port, second_port]
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
	return {"left": left, "right": right, "sleepers": sleepers}
