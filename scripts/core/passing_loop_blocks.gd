extends RefCounted
## Draft topology only. Reuse the operating block partition without requesting authority.
const Template = preload("res://scripts/core/passing_loop_template.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const Signals = preload("res://scripts/core/block_signals.gd")
const LABELS := {"main": "Main branch", "loop": "Loop branch", "first": "First switch", "last": "Far switch"}

static func inspect(anchor: Vector2i, length: int, orientation: int, tracks: Dictionary, signs: Dictionary) -> Dictionary:
	if Template.design(length, orientation).is_empty(): return _unavailable()
	var main: Array[Vector2i] = []
	var loop: Array[Vector2i] = [anchor]
	for x in range(length): main.append(anchor + Template.transform(Vector2i(x, 0), orientation))
	for y in [1, 2, 3]: loop.append(anchor + Template.transform(Vector2i(0, y), orientation))
	for x in range(1, length): loop.append(anchor + Template.transform(Vector2i(x, 3), orientation))
	for y in [2, 1, 0]: loop.append(anchor + Template.transform(Vector2i(length - 1, y), orientation))
	for cells in [main, loop]:
		for index in range(cells.size()):
			var cell: Vector2i = cells[index]
			if not tracks.has(cell): return _unavailable()
			if signs.has(cell) and (not Geometry.is_straight(tracks[cell]) or not preload("res://scripts/core/signal_rules.gd").valid_on(signs[cell], tracks[cell])): return _unavailable()
			var ports := Geometry.connections(tracks[cell])
			if index > 0 and not ports.has(cells[index - 1] - cell): return _unavailable()
			if index + 1 < cells.size() and not ports.has(cells[index + 1] - cell): return _unavailable()
			if index > 0 and index + 1 < cells.size() and not Geometry.exits_from(tracks[cell], cells[index - 1] - cell).has(cells[index + 1] - cell): return _unavailable()
	for index in [0, length - 1]:
		var cell: Vector2i = main[index]
		var stem := Template.transform(Vector2i.LEFT if index == 0 else Vector2i.RIGHT, orientation)
		var through := -stem
		var branch := Template.transform(Vector2i.DOWN, orientation)
		if not Geometry.is_switch(tracks[cell]) or not Geometry.exits_from(tracks[cell], stem).has(through) or not Geometry.exits_from(tracks[cell], stem).has(branch) or signs.has(cell): return _unavailable()
	var boundary: Array[Vector2i] = [main[1], main[length - 2], loop[2], loop[loop.size() - 3]]
	var issues: PackedStringArray = []
	var complete := true
	for cell in boundary:
		if not signs.has(cell):
			complete = false
			issues.append("Missing boundary signal at %d,%d. Restore a suitable boundary before relying on branch isolation." % [cell.x, cell.y])
		elif not Geometry.is_straight(tracks[cell]) or not preload("res://scripts/core/signal_rules.gd").valid_on(signs[cell], tracks[cell]):
			return _unavailable()
		elif signs[cell] == "stop": issues.append("Manual stop at %d,%d keeps trains held until released; it is still a block boundary." % [cell.x, cell.y])
	var blocks := Signals.new()
	blocks.configure(tracks, signs)
	var regions := {"main": main.slice(2, length - 2), "loop": loop.slice(3, loop.size() - 3), "first": [main[0]], "last": [main[length - 1]]}
	var roles: Dictionary = {}
	for role in regions:
		var ids: Array[int] = []
		for cell in regions[role]:
			if blocks.cell_blocks.has(cell) and not ids.has(int(blocks.cell_blocks[cell])): ids.append(int(blocks.cell_blocks[cell]))
		ids.sort()
		roles[role] = ids
		if ids.size() > 1: issues.append("%s contains %d blocks. Extra signal boundaries change holding positions; review them with the body-fit check." % [LABELS[role], ids.size()])
		if ids.is_empty(): issues.append("%s has no holding block between its boundary signals. Review the extra signals in this branch." % LABELS[role])
	var keys: Array = roles.keys()
	for first in range(keys.size()):
		for last in range(first + 1, keys.size()):
			var a: String = keys[first]
			var b: String = keys[last]
			var shared: Array[int] = []
			for id in roles[a]:
				if roles[b].has(id): shared.append(id)
			if shared.is_empty(): continue
			if a == "first" and b == "last":
				issues.append("End switches share %s. %s Inspect the joining connection and place suitable boundaries on it, keeping station-to-switch approaches clear; a train there can hold both approaches." % [_ids(shared), "An unsignalled connection outside this template joins them." if complete else "An unsignalled connection joins them."])
			else:
				issues.append("%s and %s share %s. Inspect missing boundaries or extra connections; a train in that block can hold both areas." % [LABELS[a], LABELS[b], _ids(shared)])
	return {"ok": true, "roles": roles, "issues": issues, "first": main[0], "last": main[length - 1]}

static func describe(result: Dictionary) -> String:
	if not result.ok: return str(result.message)
	var lines: PackedStringArray = ["Last loop preview — signal blocks (draft)"]
	for role in result.roles:
		var label: String = LABELS[role]
		if role in ["first", "last"]:
			var cell: Vector2i = result[role]
			label += " (%d,%d)" % [cell.x, cell.y]
		lines.append("%s: %s" % [label, _ids(result.roles[role])])
	if result.issues.is_empty(): lines.append("Both branches and end switches are in separate signal blocks in this draft.")
	else:
		for issue in result.issues: lines.append("Warning: " + issue)
	lines.append("Preview block IDs may differ from live IDs. This is current draft connectivity, not traffic authority or a deadlock forecast. Body fit, service waypoints and station approaches still need review. Apply performs the normal safety checks.")
	return "\n".join(lines)

static func _ids(ids: Array) -> String:
	var labels: PackedStringArray = []
	for id in ids: labels.append("B%02d" % id)
	return ", ".join(labels) if not labels.is_empty() else "no holding block"

static func _unavailable() -> Dictionary:
	return {"ok": false, "message": "Last loop preview — block check unavailable: its two branch paths or end switches have changed. Place a fresh template to identify the intended holding areas."}
