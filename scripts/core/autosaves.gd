extends RefCounted
## Three independently replaced recovery files per manual slot. Never rename or
## rotate old files before the replacement has been fully written and flushed.
const Slots = preload("res://scripts/core/save_slots.gd")
const COUNT := 3
const MAX_BYTES := 8 * 1024 * 1024

static func path(slot: int, copy_index: int) -> String:
	assert(slot >= 1 and slot <= Slots.COUNT and copy_index >= 1 and copy_index <= COUNT)
	return "user://microrail_autosave_slot_%d_copy_%d.json" % [slot, copy_index]

static func owns(slot: int, filename: String) -> bool:
	for copy_index in range(1, COUNT + 1):
		if filename == path(slot, copy_index): return true
	return false

static func entries(slot: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for copy_index in range(1, COUNT + 1):
		var filename := path(slot, copy_index)
		if not FileAccess.file_exists(filename): continue
		var sequence := 0
		var file := FileAccess.open(filename, FileAccess.READ)
		if file != null and file.get_length() <= MAX_BYTES:
			var parser := JSON.new()
			if parser.parse(file.get_as_text()) == OK and parser.data is Dictionary:
				var value: Variant = parser.data.get("autosave_sequence", 0)
				if typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= 0 and float(value) <= 1e12:
					sequence = int(value)
		if file != null: file.close()
		result.append({"path": filename, "sequence": sequence, "modified": FileAccess.get_modified_time(filename)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.sequence > b.sequence)
	return result

## Empty result means failure; existing files remain untouched on a failed write.
static func write(slot: int, snapshot: Dictionary) -> String:
	if slot < 1 or slot > Slots.COUNT: return ""
	var copies := entries(slot)
	var target := ""
	for copy_index in range(1, COUNT + 1):
		if not FileAccess.file_exists(path(slot, copy_index)):
			target = path(slot, copy_index)
			break
	if target.is_empty(): target = copies.back().path
	var data := snapshot.duplicate(true)
	data["autosave_sequence"] = 1 if copies.is_empty() else int(copies.front().sequence) + 1
	var temp := target + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return ""
	file.store_string(JSON.stringify(data, "\t", true, true))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK: return ""
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(target)) != OK: return ""
	return target
