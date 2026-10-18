extends SceneTree
## Run with isolated XDG_DATA_HOME; exercises real slot writes, loads and backups.
const Slots = preload("res://scripts/core/save_slots.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _write(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()

func _run() -> void:
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	check(Slots.path(1) == game.SAVE_PATH and Slots.path(1, "backup") == game.SAVE_BACKUP_PATH, "legacy save remains slot 1")
	for slot in range(1, 5):
		for kind in ["save", "backup", "temp"]:
			if FileAccess.file_exists(Slots.path(slot, kind)): DirAccess.remove_absolute(Slots.path(slot, kind))
		game.money = 1000 + slot
		check(game._save_game(slot), "save slot %d" % slot)
		check(game.active_save_slot == slot, "saving selects its slot")
	for slot in range(1, 5):
		check(game._load_slot(slot), "load slot %d" % slot)
		check(game.money == 1000 + slot, "slot %d retains its own game" % slot)
	game.money = 2042
	check(game._save_game(), "default save writes current slot")
	check(game._load_slot(4, true) and game.money == 1004, "slot 4 backup is its previous save")
	check(not FileAccess.file_exists(Slots.path(1, "backup")), "other slot backups remain untouched")
	check(game._load_slot(1) and game.money == 1001, "slot 1 unaffected by slot 4 overwrite")
	var good := FileAccess.get_file_as_string(Slots.path(4))
	_write(Slots.path(4), "{broken")
	check(not game._load_slot(4), "damaged slot rejected")
	check(game.active_save_slot == 1 and game.money == 1001, "failed load retains game and active slot")
	game._open_save_slots("load")
	check(game._modal_open() and game.paused, "chooser pauses and blocks map input")
	check(game.save_slots_dialog.slots.item_count == 4, "four visible choices")
	game.save_slots_dialog.slots.select(3)
	game.save_slots_dialog._perform()
	check(game.save_slots_dialog.visible and game.save_slots_dialog.explanation.text.contains("could not be read"), "load error remains visible inside chooser")
	game.save_slots_dialog.hide()
	_write(Slots.path(4), good)
	DirAccess.make_dir_absolute(Slots.path(3, "temp"))
	check(not game._save_game(3), "failed temporary write rejected")
	check(game.active_save_slot == 1, "failed save does not select another slot")
	check(JSON.parse_string(FileAccess.get_file_as_string(Slots.path(3))).state.money == 1003, "failed write preserves existing game")
	DirAccess.remove_absolute(Slots.path(3, "temp"))
	game.is_dragging = true
	check(not game._save_game(2), "active construction cannot be saved")
	game.is_dragging = false
	check(not game._load_slot(0) and not game._save_game(5), "invalid slot IDs rejected")
	current_scene = game
	var previous := FileAccess.get_file_as_string(Slots.path(3))
	game._start_new_game(3)
	var fresh = current_scene
	fresh.set_process(false)
	check(fresh != game and fresh.active_save_slot == 3, "fresh game adopts selected slot")
	check(fresh.money == 1000 and fresh.tracks.size() == 5, "fresh game resets map and economy")
	check(FileAccess.get_file_as_string(Slots.path(3)) == previous, "starting fresh does not overwrite saved game")
	check(fresh._save_game(), "fresh game saves to selected slot")
	check(fresh._load_slot(3, true) and fresh.money == 1003, "fresh save preserves previous game as backup")
	current_scene = null
	fresh.queue_free()
	await process_frame
	print("Save slots: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
