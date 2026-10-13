extends RefCounted
## Slot 1 retains the original manual save and backup filenames.
const COUNT := 4

static func path(slot: int, kind: String = "save") -> String:
	assert(slot >= 1 and slot <= COUNT)
	assert(kind in ["save", "backup", "temp"])
	var base := "user://trainz_save" if slot == 1 else "user://trainz_save_slot_%d" % slot
	match kind:
		"backup": return base + ".backup.json"
		"temp": return base + ".tmp"
	return base + ".json"

static func describe(slot: int) -> String:
	var filename := path(slot)
	if not FileAccess.file_exists(filename): return "Slot %d — Empty" % slot
	var modified := Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(filename)).replace("T", " ")
	return "Slot %d — Saved %s UTC" % [slot, modified]
