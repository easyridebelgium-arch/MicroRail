extends "res://tests/test_city_scene.gd"
const Config = preload("res://scripts/core/new_game_config.gd")
const Title = preload("res://scripts/title_screen.gd")
const Settings = preload("res://scripts/core/game_settings.gd")

func run() -> void:
	root.size = Vector2i(1280, 720)
	for seed_text in ["", "01", "-1", "1.5", "9223372036854775808"]:
		check(not Config.validate({"mode": "cities", "seed": seed_text, "city_count": 4}).ok, "invalid seed rejected: " + seed_text)
	for count in [2, 9, 4.5, "4"]:
		check(not Config.validate({"mode": "cities", "seed": "42", "city_count": count}).ok, "invalid city count rejected")
	check(Config.validate({"mode": "cities", "seed": "42", "city_count": 4}).configuration.city_growth == "normal", "new city games default to normal bounded growth")
	check(not Config.validate({"mode": "cities", "seed": "42", "city_count": 4, "city_growth": "bad"}).ok, "invalid population rule rejected")
	check(not Config.validate({"mode": "unknown"}).ok and Config.validate({"mode": "tutorial"}).ok, "explicit supported profiles")
	for seed_text in ["0", "42", "99999", "9223372036854775807"]:
		for count in [3, 4, 8]: check(Config.validate({"mode": "cities", "seed": seed_text, "city_count": count}).ok, "bounded preview validates seed/density")
	game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.paused = true
	game.money = 1234
	game._save_game(4)
	var original_save := FileAccess.get_file_as_string(game.SaveSlots.path(4))
	var original_rng: Dictionary = game.sim_rng.save_state()
	game._open_new_game(4)
	var chooser: Node = game.new_game_dialog
	check(game._modal_open() and chooser.visible and game.paused and chooser.mode_choice.selected == 0, "in-game chooser defaults to cities and blocks map input")
	chooser.seed_field.text = "bad"
	chooser.refresh()
	check(chooser.get_ok_button().disabled and not chooser.validation.ok, "invalid seed disables Start")
	chooser.confirmed.emit()
	check(chooser.visible and game.money == 1234, "invalid acceptance preserves current game")
	chooser._seed_picker.seed = 2026
	for attempt in range(8):
		var previous_seed: String = chooser.seed_field.text
		chooser.random_seed_button.pressed.emit()
		check(chooser.seed_field.text != previous_seed and chooser.validation.ok and not chooser.get_ok_button().disabled, "Random replaces invalid or previous text with a valid different seed")
	check(chooser.city_count.value == 4 and chooser.mode_choice.selected == 0, "Random preserves city count and game mode")
	check(game.sim_rng.save_state() == original_rng and game.money == 1234 and FileAccess.get_file_as_string(game.SaveSlots.path(4)) == original_save, "Random changes no running simulation, balance or save")
	chooser.seed_field.text = "42"
	chooser.city_count.value = 8
	chooser.refresh()
	check(not chooser.get_ok_button().disabled and chooser.explanation.text.contains("£5000") and chooser.explanation.text.contains("£400"), "city preview gives real budget and train price")
	check(game.sim_rng.save_state() == original_rng and game.money == 1234 and FileAccess.get_file_as_string(game.SaveSlots.path(4)) == original_save, "preview consumes no live RNG, money or saves")
	chooser.hide()
	check(game.money == 1234 and not game._modal_open(), "cancel retains company")
	# Start through the real title/new-game acceptance flow.
	var title := Title.new()
	root.add_child(title)
	await process_frame
	current_scene = title
	title.new_game_dialog.open_dialog(4)
	title.new_game_dialog._seed_picker.seed = 42
	title.new_game_dialog.random_seed_button.pressed.emit()
	var chosen_seed: String = title.new_game_dialog.seed_field.text
	title.new_game_dialog.growth_choice.select(1)
	title.new_game_dialog.city_count.value = 8
	title.new_game_dialog.refresh()
	title.new_game_dialog.confirmed.emit()
	for frame in range(300):
		if current_scene != title: break
		await process_frame
	check(current_scene != title, "title chooser completes threaded main-scene launch")
	var fresh := current_scene
	if fresh == title:
		quit(1)
		return
	fresh.set_process(false)
	check(fresh.city_builder.is_city_game() and fresh.world.state.layout_seed == chosen_seed and fresh.world.state.settlements.size() == 8 and fresh.active_save_slot == 4, "randomly chosen seed, density, profile and slot reach startup")
	check(fresh.city_growth.state.rate == "slow", "selected per-game growth rule reaches threaded title startup")
	check(fresh.money == 5000 and fresh.tracks.is_empty() and fresh.fleet.trains.is_empty() and fresh.paused, "sandbox starts paused with stated budget and no prebuilt company")
	check(FileAccess.get_file_as_string(fresh.SaveSlots.path(4)) == original_save, "starting a generated game never overwrites the chosen slot")
	# Show that the quoted budget supports a complete first passenger service.
	var tutorial := game
	game = fresh
	var candidates: Array = game.CityBuildTool.Generator.planning(game.world.save_state()).station_candidates
	var first := Vector2i(candidates[0].cell[0], candidates[0].cell[1])
	var second := Vector2i(candidates[1].cell[0], candidates[1].cell[1])
	game.city_builder.submit(first)
	game.city_builder.submit(second)
	check(connect_stations(first, second), "initial budget constructs a real city-to-city track route")
	var purchase: Dictionary = game.buy_fleet_train("passenger_standard")
	check(purchase.ok and game.money > 0 and game.start_passenger_service(int(purchase.id), game.world.station_key(first), game.world.station_key(second)).contains("started"), "initial funds buy two stations, track and a usable passenger shuttle")
	check(game._save_game(4) and game._load_slot(4) and game._load_slot(4, true) and not game.city_builder.is_city_game() and game.money == 1234, "first generated save keeps previous tutorial as a loadable backup")
	# In-game New Game has the same choices and preserves saves on acceptance.
	game._open_new_game(2)
	game.new_game_dialog.mode_choice.select(1)
	game.new_game_dialog.refresh()
	check(not game.new_game_dialog.city_controls.visible and game.new_game_dialog.validation.configuration.mode == "tutorial", "tutorial remains an explicit choice")
	game.new_game_dialog.confirmed.emit()
	await process_frame
	await process_frame
	var next_game := current_scene
	check(next_game != game and not next_game.city_builder.is_city_game() and next_game.active_save_slot == 2 and next_game.money == 1000, "in-game chooser starts a tutorial in selected slot")
	next_game.set_process(false)
	var scale_before: float = Settings.ui_scale
	Settings.ui_scale = 2
	next_game._apply_settings()
	next_game._open_new_game(1)
	await process_frame
	await process_frame
	var dialog: Window = next_game.new_game_dialog
	check(dialog.size.x <= root.get_visible_rect().size.x and dialog.size.y <= root.get_visible_rect().size.y, "new-game chooser fits at 200 percent UI scale")
	dialog.hide()
	Settings.ui_scale = scale_before
	next_game._apply_settings()
	tutorial.queue_free()
	next_game.queue_free()
	current_scene = null
	await process_frame
	for seed_text in ["0", "99999", "9223372036854775807"]:
		for count in [3, 8]:
			game = load("res://scenes/main/main.tscn").instantiate()
			game.startup_allow_cli = false
			game.startup_city_seed = seed_text
			game.startup_city_count = count
			root.add_child(game)
			game.set_process(false)
			candidates = game.CityBuildTool.Generator.planning(game.world.save_state()).station_candidates
			first = Vector2i(candidates[0].cell[0], candidates[0].cell[1])
			second = Vector2i(candidates[1].cell[0], candidates[1].cell[1])
			game.city_builder.submit(first)
			game.city_builder.submit(second)
			var connected := connect_stations(first, second)
			purchase = game.buy_fleet_train("passenger_standard")
			check(connected and purchase.ok and game.money > 0 and game.start_passenger_service(int(purchase.id), game.world.station_key(first), game.world.station_key(second)).contains("started"), "affordable first service at boundary density for seed " + seed_text)
			game.queue_free()
			await process_frame
	print("New game: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
