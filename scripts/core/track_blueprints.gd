extends RefCounted
## Versioned local designs contain geometry and signals, never trains or stations.
const Geometry = preload("res://scripts/track_geometry.gd")
const VERSION := 1
const MAX_DESIGNS := 50
const MAX_BYTES := 1048576

static func valid(data: Variant) -> bool:
	if not data is Dictionary or not _whole(data.get("version"), VERSION, VERSION): return false
	var name: Variant = data.get("name")
	if not name is String or name.strip_edges() != name or name.length() < 1 or name.length() > 40: return false
	for character in name:
		if character.unicode_at(0) < 32: return false
	if not _whole(data.get("width"), 1, 80) or not _whole(data.get("height"), 1, 50): return false
	if not data.get("tiles") is Array or data.tiles.is_empty() or data.tiles.size() > 4000 or not data.get("signals") is Array or data.signals.size() > 4000: return false
	var tiles: Dictionary = {}
	for row in data.tiles:
		if not _row(row, int(data.width), int(data.height)): return false
		var cell := Vector2i(int(row[0]), int(row[1]))
		if tiles.has(cell) or Geometry.connections(row[2]).size() < 2: return false
		tiles[cell] = row[2]
	var signs: Dictionary = {}
	for row in data.signals:
		if not _row(row, int(data.width), int(data.height)): return false
		var cell := Vector2i(int(row[0]), int(row[1]))
		if signs.has(cell) or not tiles.has(cell) or not Geometry.is_straight(tiles[cell]) or not preload("res://scripts/core/signal_rules.gd").valid_on(row[2], tiles[cell]): return false
		signs[cell] = row[2]
	return true

static func capture(tracks: Dictionary, signals: Dictionary, first: Vector2i, last: Vector2i, name: String, protected: Callable) -> Dictionary:
	var origin := Vector2i(mini(first.x, last.x), mini(first.y, last.y))
	var size := Vector2i(absi(last.x - first.x) + 1, absi(last.y - first.y) + 1)
	if size.x > 80 or size.y > 50: return {}
	var data := {"version": VERSION, "name": name.strip_edges(), "width": size.x, "height": size.y, "tiles": [], "signals": []}
	for y in range(size.y):
		for x in range(size.x):
			var cell := origin + Vector2i(x, y)
			if not tracks.has(cell) or protected.call(cell): continue
			data.tiles.append([x, y, tracks[cell]])
			if signals.has(cell) and Geometry.is_straight(tracks[cell]): data.signals.append([x, y, signals[cell]])
	return data if valid(data) else {}

static func place(data: Dictionary, anchor: Vector2i, tracks: Dictionary, signals: Dictionary, size: Vector2i, protected: Callable) -> Dictionary:
	var result := {"tracks": {}, "signals": {}, "error": ""}
	if not valid(data):
		result.error = "Invalid blueprint data."
		return result
	if anchor.x < 0 or anchor.y < 0 or anchor.x + int(data.width) > size.x or anchor.y + int(data.height) > size.y:
		result.error = "Blueprint footprint goes outside the map."
		return result
	for row in data.tiles:
		var cell := anchor + Vector2i(int(row[0]), int(row[1]))
		if protected.call(cell):
			result.error = "Blueprint overlaps a platform or facility grounds."
			return result
		if tracks.has(cell) and not _same(tracks[cell], row[2]):
			var base: Variant = Geometry.switch_base(row[2])
			if Geometry.connections(tracks[cell]).size() != 2 or not Geometry.is_switch(row[2]) or base == null or not Geometry.same_connections(tracks[cell], base):
				result.error = "Blueprint overlaps different track at %d,%d." % [cell.x, cell.y]
				return result
		result.tracks[cell] = row[2]
	for row in data.signals:
		var cell := anchor + Vector2i(int(row[0]), int(row[1]))
		if signals.has(cell) and signals[cell] != row[2]:
			result.error = "Blueprint overlaps a different signal mode."
			return result
		result.signals[cell] = row[2]
	return result

static func load_library(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"designs": [], "error": ""}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES: return {"designs": [], "error": "Blueprint library cannot be read or is too large."}
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or not _whole(data.get("version"), VERSION, VERSION) or not data.get("designs") is Array or data.designs.size() > MAX_DESIGNS: return {"designs": [], "error": "Invalid blueprint library."}
	var names: Dictionary = {}
	for design in data.designs:
		if not valid(design) or names.has(design.name): return {"designs": [], "error": "Invalid or duplicate blueprint."}
		names[design.name] = true
	return {"designs": data.designs, "error": ""}

static func save_library(path: String, designs: Array) -> bool:
	if designs.size() > MAX_DESIGNS: return false
	var names: Dictionary = {}
	for design in designs:
		if not valid(design) or names.has(design.name): return false
		names[design.name] = true
	var text := JSON.stringify({"version": VERSION, "designs": designs})
	if text.to_utf8_buffer().size() > MAX_BYTES: return false
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return false
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return false
	# Keep the prior library recoverable when replacing it (including Windows).
	var backup := path + ".backup"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK: return false
		if DirAccess.rename_absolute(path, backup) != OK: return false
	if DirAccess.rename_absolute(temp, path) == OK: return true
	if FileAccess.file_exists(backup): DirAccess.rename_absolute(backup, path)
	return false

static func _row(row: Variant, width: int, height: int) -> bool:
	return row is Array and row.size() == 3 and _whole(row[0], 0, width - 1) and _whole(row[1], 0, height - 1)

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

static func _same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b

## Transform a copy; stored source and library backup remain untouched.
static func transformed(data: Dictionary, turns: int, mirrored: bool) -> Dictionary:
	if not valid(data): return {}
	var result := data.duplicate(true)
	if mirrored:
		for row in result.tiles:
			row[0] = int(result.width) - 1 - int(row[0])
			row[2] = _transform_kind(row[2], true)
		for row in result.signals:
			row[0] = int(result.width) - 1 - int(row[0])
			row[2] = _transform_signal(row[2], true)
	for _turn in range(posmod(turns, 4)):
		var height := int(result.height)
		for row in result.tiles:
			var old_x := int(row[0])
			row[0] = height - 1 - int(row[1])
			row[1] = old_x
			row[2] = _transform_kind(row[2], false)
		for row in result.signals:
			var old_x := int(row[0])
			row[0] = height - 1 - int(row[1])
			row[1] = old_x
			row[2] = _transform_signal(row[2], false)
		result.height = result.width
		result.width = height
	return result if valid(result) else {}

static func _vector(value: Vector2i, mirrored: bool) -> Vector2i:
	return Vector2i(-value.x, value.y) if mirrored else Vector2i(-value.y, value.x)
static func _transform_kind(kind: Variant, mirrored: bool) -> Variant:
	var ports := Geometry.connections(kind)
	for i in range(ports.size()): ports[i] = _vector(ports[i], mirrored)
	if Geometry.is_switch(kind): return "junction_%d_%d_%d" % [Geometry.DIRECTIONS.find(ports[0]), Geometry.DIRECTIONS.find(ports[1]), Geometry.DIRECTIONS.find(ports[2])]
	if Geometry.is_crossing(kind): return Geometry.crossing_type(ports[0], ports[2])
	return Geometry.from_ports(ports[0], ports[1])
static func _transform_signal(mode: String, mirrored: bool) -> String:
	var direction := preload("res://scripts/core/signal_rules.gd").direction(mode)
	return mode if direction == Vector2i.ZERO else "oneway_%d" % Geometry.DIRECTIONS.find(_vector(direction, mirrored))
