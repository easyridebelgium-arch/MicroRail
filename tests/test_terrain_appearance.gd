extends SceneTree
const Settings = preload("res://scripts/core/game_settings.gd")
const Art = preload("res://scripts/art/terrain_art.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func settle() -> void:
	for frame in range(4): await process_frame

func run() -> void:
	root.size = Vector2i(1280, 720)
	var existed := FileAccess.file_exists(Settings.SETTINGS_PATH)
	var previous := FileAccess.get_file_as_bytes(Settings.SETTINGS_PATH) if existed else PackedByteArray()
	var legacy := ConfigFile.new()
	legacy.set_value("display", "ui_scale", 1.0)
	legacy.save(Settings.SETTINGS_PATH)
	Settings.terrain_style = "winter"
	Settings.show_grid = false
	Settings.load_settings()
	check(Settings.terrain_style == "summer" and Settings.show_grid, "old settings default to summer grass with a visible grid")
	legacy.set_value("display", "terrain_style", "unknown")
	legacy.save(Settings.SETTINGS_PATH)
	Settings.load_settings()
	check(Settings.terrain_style == "summer", "unknown ground styles fall back safely")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/terrain/manifest.json"))
	check(manifest.entries.size() == 16, "all sixteen original ground materials are available")
	for entry: Dictionary in manifest.entries:
		var texture := Art.texture(entry.id) as AtlasTexture
		check(texture != null and texture.atlas != null and Rect2(Vector2.ZERO, texture.atlas.get_size()).encloses(texture.region), "material region loads inside its source sheet: " + str(entry.id))
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.paused = true
	await settle()
	var rng_before: Dictionary = game.sim_rng.save_state()
	var tick_before: int = game.sim_clock.tick
	var tracks_before: Dictionary = game.tracks.duplicate(true)
	var position_before: Vector2 = game.train_position
	var cash_before: int = game.money
	for style in Settings.TERRAIN_STYLES:
		game.settings_dialog.open_dialog()
		game.settings_dialog.terrain_choice.select(Settings.TERRAIN_STYLES.find(style))
		game.settings_dialog.grid_check.button_pressed = false
		check(Settings.terrain_style != style or style == "summer", "editing a ground choice is only a draft before Apply")
		game.settings_dialog._apply()
		game.settings_dialog.hide()
		await settle()
		check(Settings.terrain_style == style and not Settings.show_grid, "Apply selects the requested ground and grid preference: " + style)
		Settings.terrain_style = "invalid"
		Settings.show_grid = true
		Settings.load_settings()
		check(Settings.terrain_style == style and not Settings.show_grid, "ground and grid preferences persist: " + style)
	check(game.sim_rng.save_state() == rng_before and game.sim_clock.tick == tick_before and game.tracks == tracks_before and game.train_position == position_before and game.money == cash_before, "appearance changes never consume simulation RNG or move trains, spend money or alter track")
	Settings.terrain_style = "winter"
	check(Art.effective_style(Settings.terrain_style, true) == "plain" and Settings.terrain_style == "winter", "high contrast suppresses textured ground without overwriting the preferred season")
	Settings.ui_scale = 2
	game._apply_settings()
	game.settings_dialog.open_dialog()
	await settle()
	check(game.settings_dialog.size.y <= root.get_visible_rect().size.y and game.settings_dialog.size.x <= root.get_visible_rect().size.x, "terrain settings remain reachable at 200 percent UI scaling")
	game.settings_dialog.hide()
	game.queue_free()
	await settle()
	if existed:
		var file := FileAccess.open(Settings.SETTINGS_PATH, FileAccess.WRITE)
		file.store_buffer(previous)
		file.close()
	else: DirAccess.remove_absolute(Settings.SETTINGS_PATH)
	print("Terrain appearance: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
