extends SceneTree
const Migration = preload("res://scripts/core/legacy_migration.gd")
const SaveSlots = preload("res://scripts/core/save_slots.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
func _initialize() -> void:
	var root_dir := OS.get_cache_dir().path_join("microrail_migration_test")
	var old_dir := root_dir.path_join("Trainz")
	var new_dir := root_dir.path_join("MicroRail")
	DirAccess.make_dir_recursive_absolute(old_dir)
	DirAccess.make_dir_recursive_absolute(new_dir)
	for name in DirAccess.get_files_at(old_dir) + DirAccess.get_files_at(new_dir):
		DirAccess.remove_absolute((old_dir if FileAccess.file_exists(old_dir.path_join(name)) else new_dir).path_join(name))
	write(old_dir.path_join("trainz_save.json"), "old slot 1")
	write(old_dir.path_join("trainz_save.backup.json"), "old backup")
	write(old_dir.path_join("trainz_save_slot_2.json"), "old slot 2")
	write(old_dir.path_join("settings.cfg"), "old settings")
	write(old_dir.path_join("track_blueprints.json"), "old blueprints")
	write(old_dir.path_join("trainz_save.tmp"), "half written")
	write(new_dir.path_join("microrail_save_slot_2.json"), "new slot 2")
	var copied := Migration.copy_legacy(old_dir, new_dir)
	check(copied == 4, "four files are copied, got %d" % copied)
	check(FileAccess.get_file_as_string(new_dir.path_join("microrail_save.json")) == "old slot 1", "slot 1 keeps its data under the new name")
	check(FileAccess.get_file_as_string(new_dir.path_join("microrail_save.backup.json")) == "old backup", "the backup is renamed too")
	check(FileAccess.get_file_as_string(new_dir.path_join("microrail_save_slot_2.json")) == "new slot 2", "a newer save is never overwritten")
	check(FileAccess.file_exists(new_dir.path_join("settings.cfg")) and FileAccess.file_exists(new_dir.path_join("track_blueprints.json")), "settings and blueprints come along")
	check(not FileAccess.file_exists(new_dir.path_join("microrail_save.tmp")), "unfinished temp files are ignored")
	check(FileAccess.file_exists(old_dir.path_join("trainz_save.json")), "the old folder is left untouched")
	check(Migration.copy_legacy(old_dir, new_dir) == 0, "running again copies nothing")
	check(Migration.copy_legacy(root_dir.path_join("missing"), new_dir) == 0 and Migration.copy_legacy(new_dir, new_dir) == 0, "a missing or identical folder is ignored")
	check(SaveSlots.path(1) == "user://microrail_save.json" and SaveSlots.path(3, "backup") == "user://microrail_save_slot_3.backup.json", "slots use the new filenames")
	print("Legacy migration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
