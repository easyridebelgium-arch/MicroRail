extends "res://tests/test_city_scene.gd"
const Config = preload("res://scripts/core/new_game_config.gd")
const Path = preload("res://scripts/core/first_connection_path.gd")
const Challenges = preload("res://scripts/core/seeded_challenges.gd")
func run() -> void:
	var choice := {"mode": "cities", "seed": "42", "city_count": 3, "challenge": "river_connection", "terrain": "river_v1"}
	var configuration := Config.validate(choice)
	check(configuration.ok and configuration.message.contains("Checked Town 3–Town 1 layout"), "preset validates a fully affordable cross-river witness")
	var wrong := choice.duplicate()
	wrong.terrain = "flat"
	check(not Config.validate(wrong).ok, "river goal cannot silently use a flat map")
	var model := Challenges.new()
	model.initialize("river_connection")
	var measured := {"cities": {"town:01": {"totals": {"delivered": 100}}, "town:03": {"totals": {"delivered": 0}}}}
	check(not model.advance(1, measured), "other cities' volume cannot satisfy Town 3 cross-river goal")
	measured.cities["town:01"].totals.delivered = 4
	measured.cities["town:03"].totals.delivered = 40
	check(not model.advance(2, measured), "40 cross-river journeys still require useful service from another origin")
	measured.cities["town:01"].totals.delivered = 5
	check(model.advance(2, measured) and not model.advance(3, measured), "qualified goal completes once")
	game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	game.startup_city_seed = "42"
	game.startup_city_count = 3
	game.startup_challenge = "river_connection"
	game.startup_terrain = "river_v1"
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	check(game.seeded_challenge.state.id == "river_connection" and game.river_terrain.profile == "river_v1" and game.tracks.is_empty(), "preset starts empty with the intended terrain")
	check(game.objective_description.text.contains("Town 3 resident cross-river"), "goals explain whose journeys qualify")
	var a := Vector2i(64, 15)
	var b := Vector2i(65, 29)
	var witness := Path.find(game.world.state, game.river_terrain, a, b)
	check(not witness.is_empty(), "crossing witness exists before any purchase")
	if witness.is_empty():
		game.queue_free()
		quit(1)
		return
	game.city_builder.submit(a)
	game.city_builder.submit(b)
	var updates: Array = []
	for cell in witness.changes: updates.append([cell.x, cell.y, witness.changes[cell]])
	game._execute_build({"cells": updates})
	check(not game.RailRouter.find_route(game.tracks, a, b).is_empty() and game.river_terrain.track_error(game.tracks).is_empty(), "ordinary construction commits a real complete bridge")
	var train: Dictionary = game.buy_fleet_train("passenger_standard")
	check(train.ok and game.start_passenger_service(train.id, game.world.station_key(a), game.world.station_key(b)).contains("started"), "ordinary purchase and service start work")
	check(game.money == 5000 - witness.station_cost - witness.track_cost - 400 and game.money > 0, "checked budget matches actual purchases exactly")
	check(game._save_game(2) and game._load_slot(2), "unfinished river scenario roundtrips")
	for batch in range(480):
		for tick in range(60):
			game.sim_clock.begin_tick()
			game._simulation_step(1.0 / 60.0)
		if game.seeded_challenge.state.completed_tick >= 0: break
	check(game.seeded_challenge.state.completed_tick >= 0, "actual generated passengers cross bridge and complete objective")
	check(Challenges.progress(game.city_service.state, "town:03").delivered >= 40, "completion is based on Town 3 matched final deliveries")
	var cash: int = game.money
	game._check_scenario_objectives()
	check(game.money == cash, "completion does not grant repeat money")
	check(game._save_game(2), "completed river scenario saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(2)))
	check(game._is_valid_save(saved) and game._load_slot(2) and game.seeded_challenge.state.completed_tick >= 0, "completed scenario validates and loads")
	var invalid := saved.duplicate(true)
	invalid.terrain.profile = "flat"
	check(not game._is_valid_save(invalid), "save cannot remove required river")
	invalid = saved.duplicate(true)
	invalid.world.settlements[0].cell[1] = 9
	check(not game._is_valid_save(invalid), "save cannot invalidate unique north-bank origin assumption")
	game._open_new_game(3)
	game.new_game_dialog.mode_choice.select(2)
	game.new_game_dialog.scenario_choice.select(2)
	game.new_game_dialog.refresh()
	check(game.new_game_dialog.validation.ok and game.new_game_dialog.validation.configuration.terrain == "river_v1", "chooser selects preset terrain automatically")
	game.new_game_dialog.hide()
	game.queue_free()
	await process_frame
	print("River challenge: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
