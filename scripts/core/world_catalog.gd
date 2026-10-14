extends RefCounted
## Saved geometry and stable identities. Never regenerate a loaded world.
const SCHEMA_VERSION := 1
const MAX_FACILITIES := 64
const MAX_SETTLEMENTS := 64
var state: Dictionary = tutorial()
var _station_views: Dictionary = {}

func _init() -> void: _refresh_station_views()

static func tutorial(sawmill: bool = false, factory: bool = false) -> Dictionary:
	var facilities: Array = []
	for row in [["a", "Station A", 4], ["b", "Station B", 20], ["c", "Station C", 36]]:
		facilities.append({"id": "station:" + row[0], "stop_id": row[0], "kind": "station", "name": row[1], "cell": [row[2], 8], "settlement_id": "", "enabled": true})
	for row in [["forest", "Forest", 8, true], ["terminal", "Terminal", 28, true], ["sawmill", "Sawmill", 18, sawmill], ["factory", "Factory", 23, factory]]:
		facilities.append({"id": "industry:" + row[0], "stop_id": row[0], "kind": row[0], "name": row[1], "cell": [row[2], 24], "settlement_id": "", "enabled": row[3]})
	return {"schema_version": SCHEMA_VERSION, "layout_id": "tutorial_abc", "generator_version": 1, "content_version": 1, "layout_seed": "0", "size": [80, 50], "settlements": [], "facilities": facilities}

func save_state() -> Dictionary: return state.duplicate(true)
func restore_state(value: Dictionary) -> void:
	state = value.duplicate(true)
	state.schema_version = int(state.schema_version)
	state.generator_version = int(state.generator_version)
	state.content_version = int(state.content_version)
	state["size"] = [int(state["size"][0]), int(state["size"][1])]
	for collection in [state.facilities, state.settlements]:
		for row in collection: row.cell = [int(row.cell[0]), int(row.cell[1])]
	_refresh_station_views()

func set_enabled(id: String, enabled: bool) -> void:
	for row in state.facilities:
		if row.id == id:
			row.enabled = enabled
			_refresh_station_views()
			return

func facilities() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in state.facilities:
		if row.enabled:
			var view: Dictionary = row.duplicate(true)
			view.cell = Vector2i(int(row.cell[0]), int(row.cell[1]))
			result.append(view)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return result

func _refresh_station_views() -> void:
	var views: Dictionary = {}
	for row in facilities():
		if row.kind == "station":
			row.make_read_only()
			views[row.stop_id] = row
	views.make_read_only()
	_station_views = views

func stations() -> Dictionary:
	return _station_views

func station_key(cell: Vector2i) -> String:
	for key in _station_views:
		if _station_views[key].cell == cell: return key
	return ""

static func whole(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum
static func point(value: Variant, size: Array) -> bool:
	return value is Array and value.size() == 2 and whole(value[0], 0, int(size[0]) - 1) and whole(value[1], 0, int(size[1]) - 1)
static func identifier(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 64: return false
	for character in value:
		if not (character in "abcdefghijklmnopqrstuvwxyz0123456789_:"): return false
	return true
static func label(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 40 and value == value.strip_edges() and not value.contains("\n") and not value.contains("\r") and not value.contains("\t")

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 8: return false
	if not whole(value.get("schema_version"), 1, 1) or not identifier(value.get("layout_id")): return false
	if not whole(value.get("generator_version"), 1, 1000000) or not whole(value.get("content_version"), 1, 1000000): return false
	var seed: Variant = value.get("layout_seed")
	if not seed is String or not seed.is_valid_int() or str(seed.to_int()) != seed or seed.to_int() < 0: return false
	var size: Variant = value.get("size")
	if not size is Array or size.size() != 2 or not whole(size[0], 4, 512) or not whole(size[1], 4, 512): return false
	if not value.get("settlements") is Array or value.settlements.size() > MAX_SETTLEMENTS: return false
	if not value.get("facilities") is Array or value.facilities.size() > MAX_FACILITIES: return false
	var ids: Dictionary = {}
	var settlements: Dictionary = {}
	for row in value.settlements:
		if not row is Dictionary or row.size() != 3 or not identifier(row.get("id")) or not row.id.begins_with("town:") or not label(row.get("name")) or not point(row.get("cell"), size): return false
		if ids.has(row.id): return false
		ids[row.id] = true
		settlements[row.id] = true
	var stops: Dictionary = {}
	var occupied: Dictionary = {}
	for row in value.facilities:
		if not row is Dictionary or row.size() != 7: return false
		if not identifier(row.get("id")) or not identifier(row.get("stop_id")) or not label(row.get("name")) or not point(row.get("cell"), size): return false
		if not row.get("enabled") is bool or row.get("kind") not in ["station", "forest", "terminal", "sawmill", "factory"]: return false
		if row.id != ("station:" if row.kind == "station" else "industry:") + row.stop_id: return false
		if row.kind != "station" and row.stop_id != row.kind: return false
		if ids.has(row.id) or stops.has(row.stop_id): return false
		ids[row.id] = true
		stops[row.stop_id] = true
		if not row.get("settlement_id") is String: return false
		if not row.settlement_id.is_empty() and (row.kind != "station" or not settlements.has(row.settlement_id)): return false
		if value.layout_id != "tutorial_abc" and row.kind == "station" and row.settlement_id.is_empty(): return false
		if row.enabled:
			var cell := Vector2i(int(row.cell[0]), int(row.cell[1]))
			if cell.x < 1 or cell.x >= int(size[0]) - 1 or cell.y < 2: return false
			# Existing facilities have a 3x2 building plus the platform stop tile.
			var footprint: Array[Vector2i] = [cell]
			for x in range(cell.x - 1, cell.x + 2):
				for y in range(cell.y - 2, cell.y): footprint.append(Vector2i(x, y))
			for tile in footprint:
				if occupied.has(tile): return false
				occupied[tile] = row.id
	return true

static func valid_tutorial(value: Variant, sawmill: bool, factory: bool) -> bool:
	if not valid(value): return false
	var expected := tutorial(sawmill, factory)
	# Routing/demand still support the tutorial profile only. Reject arbitrary
	# relocated geometry rather than render one map and simulate another.
	for field in ["layout_id", "generator_version", "content_version", "layout_seed"]:
		if value[field] != expected[field]: return false
	if value["size"][0] != 80 or value["size"][1] != 50 or not value.settlements.is_empty() or value.facilities.size() != 7: return false
	var by_id: Dictionary = {}
	for row in value.facilities: by_id[row.id] = row
	for row in expected.facilities:
		if not by_id.has(row.id): return false
		var actual: Dictionary = by_id[row.id]
		if row.kind != "station" and actual.name != row.name: return false
		for field in ["stop_id", "kind", "settlement_id", "enabled"]:
			if actual[field] != row[field]: return false
		if actual.cell[0] != row.cell[0] or actual.cell[1] != row.cell[1]: return false
	return true
