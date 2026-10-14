extends RefCounted
## Plain-data representation of an ephemeral station read set for fixed-tick input.
const World = preload("res://scripts/core/world_catalog.gd")
const Construction = preload("res://scripts/core/station_construction.gd")
static func encode(draft: Dictionary) -> Dictionary:
	if not draft.get("ok", false): return {}
	var rows: Array = []
	for cell in draft.building_cells + draft.platform_cells:
		var before: Dictionary = draft.before[cell]
		rows.append([cell.x, cell.y, before.present, before.kind, before.signal_present, before.signal])
	return {"x": draft.cell.x, "y": draft.cell.y, "world_before": draft.world_before.duplicate(true), "before": rows}

static func decode(value: Dictionary) -> Dictionary:
	if not World.whole(value.get("x"), 0, 79) or not World.whole(value.get("y"), 0, 49) or not World.valid(value.get("world_before")): return {}
	var stop := Vector2i(int(value.x), int(value.y))
	var cells := Construction.building_cells(stop) + Construction.platform_cells(stop)
	if not value.get("before") is Array or value.before.size() != cells.size(): return {}
	var before: Dictionary = {}
	for row in value.before:
		if not row is Array or row.size() != 6 or not World.whole(row[0], 0, 79) or not World.whole(row[1], 0, 49) or not row[2] is bool or not row[4] is bool: return {}
		var cell := Vector2i(int(row[0]), int(row[1]))
		if cell not in cells or before.has(cell): return {}
		before[cell] = {"present": row[2], "kind": row[3], "signal_present": row[4], "signal": row[5]}
	var catalog := World.new()
	catalog.restore_state(value.world_before)
	return {"ok": true, "cell": stop, "world_before": catalog.save_state(), "before": before}
