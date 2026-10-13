extends RefCounted
## The game used to be called "Trainz". Godot keeps user data in a folder named
## after the project, so a renamed project would not see old saves or settings.
## On first run the old folder's files are copied (never moved or overwritten)
## into the new one, with the old save filename prefix renamed.
const OLD_NAME := "Trainz"
const OLD_PREFIX := "trainz_save"
const NEW_PREFIX := "microrail_save"

## Copies files from `old_dir` into `new_dir` that `new_dir` lacks. Returns the
## number of files copied.
static func copy_legacy(old_dir: String, new_dir: String) -> int:
	if old_dir == new_dir or not DirAccess.dir_exists_absolute(old_dir): return 0
	DirAccess.make_dir_recursive_absolute(new_dir)
	var copied := 0
	for filename in DirAccess.get_files_at(old_dir):
		if filename.ends_with(".tmp"): continue
		var target := filename.replace(OLD_PREFIX, NEW_PREFIX)
		var destination := new_dir.path_join(target)
		if FileAccess.file_exists(destination): continue
		if DirAccess.copy_absolute(old_dir.path_join(filename), destination) == OK: copied += 1
	return copied

## Looks for the pre-rename user folder next to the current one.
static func run() -> int:
	var new_dir := OS.get_user_data_dir()
	return copy_legacy(new_dir.get_base_dir().path_join(OLD_NAME), new_dir)
