extends SceneTree
## Run with an isolated XDG_DATA_HOME: this suite deliberately writes recovery files.
const Autosaves = preload("res://scripts/core/autosaves.gd")
const Slots = preload("res://scripts/core/save_slots.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func write_text(filename: String, value: String) -> void:
	var file := FileAccess.open(filename, FileAccess.WRITE)
	file.store_string(value)
	file.close()
func fixture() -> Node:
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	root.add_child(game)
	game.set_process(false)
	return game
func run() -> void:
	root.size = Vector2i(1280, 720)
	var game = fixture()
	await process_frame
	var config := ConfigFile.new()
	config.set_value("display", "ui_scale", 1.0)
	config.save(Settings.SETTINGS_PATH)
	Settings.autosave_hours = 0
	Settings.load_settings()
	check(Settings.autosave_hours == 1, "existing settings enable default hourly autosaves")
	for invalid in [-1, 2, "off", 1.5]:
		config.set_value("saves", "autosave_hours", invalid)
		config.save(Settings.SETTINGS_PATH)
		Settings.load_settings()
		check(Settings.autosave_hours == 1, "malformed interval falls back safely")
	game.settings_dialog.open_dialog()
	game.settings_dialog.autosave_choice.select(2)
	check(Settings.autosave_hours == 1, "editing interval is a draft until Apply")
	game.settings_dialog._apply()
	game.settings_dialog.hide()
	Settings.autosave_hours = 0
	Settings.load_settings()
	check(Settings.autosave_hours == 3, "applied interval persists across settings reload")
	Settings.autosave_hours = 1
	game._reset_autosave_schedule()
	for slot in range(1, 5):
		for copy_index in range(1, 4):
			var filename := Autosaves.path(slot, copy_index)
			if FileAccess.file_exists(filename): DirAccess.remove_absolute(filename)
	game.money = 2468
	check(game._save_game(2), "manual save baseline")
	game.money = 1357
	check(game._save_game(2), "manual backup baseline")
	var manual := FileAccess.get_file_as_bytes(Slots.path(2))
	var backup := FileAccess.get_file_as_bytes(Slots.path(2, "backup"))
	game.sim_clock.tick = 3599
	game._check_autosave()
	check(Autosaves.entries(2).is_empty(), "no autosave before interval")
	game.sim_clock.tick = 3600
	game.is_dragging = true
	game._check_autosave()
	check(Autosaves.entries(2).is_empty(), "active drag defers due save")
	game.is_dragging = false
	game.right_pending = true
	game._check_autosave()
	check(Autosaves.entries(2).is_empty(), "long right-click removal defers save")
	game.right_pending = false
	game.construction_plan.stage({Vector2i(1, 1): false}, game.tracks)
	game._check_autosave()
	check(Autosaves.entries(2).is_empty(), "construction draft defers save")
	game.construction_plan.clear()
	game.game_menu.open_menu()
	game._check_autosave()
	check(Autosaves.entries(2).is_empty(), "modal menu defers save")
	game.game_menu.resume_game()
	game.command_queue.enqueue(3601, "test_pending", {"value": 42})
	game.paused = true
	var before: String = JSON.stringify(game._save_snapshot(), "", true, true)
	game._process(0.0)
	check(Autosaves.entries(2).size() == 1, "due save completes at safe boundary")
	check(before == JSON.stringify(game._save_snapshot(), "", true, true), "autosave leaves simulation, RNG, event log and commands unchanged")
	check(game.command_queue.count() == 1, "autosave never executes next-tick commands")
	check(game.active_save_slot == 2, "autosave preserves active manual slot")
	var newest: String = Autosaves.entries(2)[0].path
	check(game._load_autosave(2, newest), "autosave round-trips through full validator")
	check(game.command_queue.count() == 1 and game.money == 1357, "recovery restores queued command and cash")
	check(game.paused and game.autosave_next_tick == 7200, "recovery pauses and starts a fresh interval")
	game.command_queue.clear()
	for index in range(4):
		game.money = 3000 + index
		game.sim_clock.tick += 3600
		game._check_autosave()
	var copies := Autosaves.entries(2)
	check(copies.size() == 3, "rotation remains bounded after five writes")
	check(copies[0].sequence == 5 and copies[2].sequence == 3, "three newest generations retained in order")
	check(Autosaves.entries(1).is_empty() and Autosaves.entries(3).is_empty() and Autosaves.entries(4).is_empty(), "other games' recovery files remain separate")
	check(manual == FileAccess.get_file_as_bytes(Slots.path(2)) and backup == FileAccess.get_file_as_bytes(Slots.path(2, "backup")), "manual save and backup are byte-for-byte unchanged")
	var original: Dictionary = {}
	for entry in copies: original[entry.path] = FileAccess.get_file_as_bytes(entry.path)
	var blocked_temp: String = copies.back().path + ".tmp"
	check(DirAccess.make_dir_absolute(blocked_temp) == OK, "simulate unwritable temporary output")
	game.sim_clock.tick += 3600
	game._check_autosave()
	check(game.notice.contains("Autosave failed"), "write failure gives actionable notice")
	for filename in original:
		check(original[filename] == FileAccess.get_file_as_bytes(filename), "write failure preserves existing recovery copy")
	check(game.autosave_next_tick > game.sim_clock.tick, "failure throttled until next interval")
	DirAccess.remove_absolute(blocked_temp)
	# Force a rename failure after a successful temporary write, with other copies present.
	var reserved_path := Autosaves.path(3, 1)
	DirAccess.make_dir_absolute(reserved_path)
	write_text(Autosaves.path(3, 2), FileAccess.get_file_as_string(copies[0].path))
	write_text(Autosaves.path(3, 3), FileAccess.get_file_as_string(copies[1].path))
	var retained := FileAccess.get_file_as_bytes(Autosaves.path(3, 2))
	check(Autosaves.write(3, game._save_snapshot()).is_empty(), "failed replacement rejected after temporary file was written")
	check(retained == FileAccess.get_file_as_bytes(Autosaves.path(3, 2)), "rename failure preserves previous readable recovery")
	DirAccess.remove_absolute(reserved_path)
	DirAccess.remove_absolute(reserved_path + ".tmp")
	Settings.autosave_hours = 0
	game._check_autosave()
	game.sim_clock.tick += 100000
	game._check_autosave()
	check(Autosaves.entries(2)[0].sequence == 5, "disabled autosave writes nothing")
	Settings.autosave_hours = 3
	game._check_autosave()
	check(game.autosave_next_tick == game.sim_clock.tick + 10800, "changed interval schedules forward without backfill")
	game.money = 7000
	var newest_path := Autosaves.entries(2)[0].path as String
	write_text(newest_path, "{broken")
	check(not game._load_autosave(2, newest_path) and game.money == 7000, "corrupted recovery rejected without changing live game")
	check(game._load_autosave(2, Autosaves.entries(2)[0].path), "next readable recovery remains loadable")
	check(not game._load_autosave(2, Slots.path(2)) and not game._load_autosave(1, Autosaves.entries(2)[0].path), "recovery refuses foreign paths or slots")
	game._open_save_slots("load")
	game.save_slots_dialog.slots.select(1)
	game.save_slots_dialog.recovery_button.pressed.emit()
	var picker = game.save_slots_dialog.recovery_picker
	check(picker.visible and picker.list.item_count == 3, "in-game load chooser exposes recovery copies")
	picker.list.select(2)
	var recovery_cash: int = game.money
	picker.confirmed.emit()
	check(picker.visible and game.money == recovery_cash and picker.explanation.text.contains("could not be read"), "failed recovery remains in chooser with explanatory error")
	picker.list.select(0)
	picker.confirmed.emit()
	check(not picker.visible and not game.save_slots_dialog.visible and game.paused, "successful recovery closes both choosers and stays paused")
	picker.open_slot(4)
	check(picker.list.item_count == 0 and picker.get_ok_button().disabled, "empty recovery roster disables Recover")
	picker.hide()
	# One long advance at different display frame rates must not alter scheduling.
	for fps in [30, 60, 120]:
		var elapsed_ticks := 0
		game.sim_clock.restore_state({"tick": 0})
		game.sim_clock.speed = 10
		Settings.autosave_hours = 1
		game._reset_autosave_schedule()
		for frame in range(fps * 6):
			for step in game.sim_clock.advance(1.0 / fps):
				game.sim_clock.begin_tick()
				elapsed_ticks += 1
		check(elapsed_ticks == 3600 and game.sim_clock.tick == game.autosave_next_tick, "same autosave boundary at %d FPS and 10×" % fps)
	game.queue_free()
	await process_frame
	var title_screen = load("res://scenes/ui/title.tscn").instantiate()
	root.add_child(title_screen)
	current_scene = title_screen
	await process_frame
	title_screen.recovery_picker.open_slot(2)
	title_screen.recovery_picker.list.select(0)
	title_screen.recovery_picker.confirmed.emit()
	for frame in range(300):
		await process_frame
		if not is_instance_valid(title_screen): break
	check(not is_instance_valid(title_screen), "title recovery completes threaded scene transition")
	if current_scene != null and current_scene.has_method("_load_autosave"):
		check(current_scene.active_save_slot == 2 and current_scene.paused, "title recovers selected game paused")
		current_scene.queue_free()
		await process_frame
	print("Autosaves: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
