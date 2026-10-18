extends "res://tests/test_city_scene.gd"
const Config = preload("res://scripts/core/new_game_config.gd")
const Challenges = preload("res://scripts/core/seeded_challenges.gd")
func run() -> void:
	var choice := {"mode": "cities", "seed": "42", "city_count": 3, "challenge": "timber_connection", "terrain": "flat"}
	var configuration := Config.validate(choice)
	check(configuration.ok and configuration.message.contains("£1430"), "briefing quotes ordinary rails, locomotive and mill")
	var model := Challenges.new()
	model.initialize("timber_connection")
	check(not model.advance(1, {"cities": {"town": {"totals": {"delivered": 999}}}}), "passenger volume cannot complete a freight scenario")
	check(not model.advance(1, {}, {"timber": {"status": "expired", "delivered": 19}}), "expired order cannot complete scenario")
	game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	game.startup_city_seed = "42"
	game.startup_city_count = 3
	game.startup_challenge = "timber_connection"
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	check(game.tracks.is_empty() and game.fleet.trains.is_empty() and game.money == 5000, "scenario starts empty with ordinary sandbox funds")
	game.first_service_guide.open_guide()
	check(game.first_service_guide.heading.text.contains("freight") and not game.first_service_guide.preview_button.visible, "guide gives freight steps rather than passenger station advice")
	game.first_service_guide.close_guide(false)
	var updates: Array = []
	for x in range(game.FOREST_SITE.x, game.CARGO_TERMINAL.x + 1): updates.append([x, game.FOREST_SITE.y, false])
	game._execute_build({"cells": updates})
	check(game.tracks.size() == 43 and game.money == 4570, "ordinary build validates the 43-tile construction witness and price")
	var train: Dictionary = game.buy_fleet_train("freight_standard")
	check(train.ok and game.start_freight_service(train.id).contains("started"), "ordinary freight purchase and service start succeed")
	check(game.build_sawmill().contains("installed") and game.money == 3570, "ordinary mill installation matches total quoted budget")
	check(game.accept_freight_contract("timber").contains("accepted"), "prepared player can accept timber order")
	check(game._save_game(2) and game._load_slot(2), "active scenario and contract roundtrip")
	for batch in range(1000):
		for tick in range(60):
			game.sim_clock.begin_tick()
			game._simulation_step(1.0 / 60.0)
		if game.seeded_challenge.state.completed_tick >= 0: break
	check(game.freight_contracts.state.timber.status == "completed" and game.sawmill.state.sold >= 20, "physical logs become timber and reach Terminal before deadline")
	check(game.seeded_challenge.state.completed_tick >= 0, "actual order completion wins scenario")
	var cash: int = game.money
	game._check_scenario_objectives()
	check(game.money == cash and game.freight_contracts.earned() == 300, "scenario adds no duplicate contract reward")
	check(game._save_game(2), "completed scenario saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(2)))
	check(game._is_valid_save(saved) and game._load_slot(2) and game.seeded_challenge.state.completed_tick >= 0, "completion survives validated JSON load")
	var invalid := saved.duplicate(true)
	invalid.freight_contracts.timber.status = "available"
	check(not game._is_valid_save(invalid), "forged scenario completion without completed contract rejected")
	invalid = saved.duplicate(true)
	invalid.seeded_challenge.completed_tick = 0
	check(not game._is_valid_save(invalid), "completion cannot predate the actual order")
	game._open_new_game(3)
	game.new_game_dialog.mode_choice.select(2)
	game.new_game_dialog.scenario_choice.select(3)
	game.new_game_dialog.refresh()
	check(game.new_game_dialog.validation.configuration.challenge == "timber_connection", "chooser appends preset without changing existing scenario indices")
	game.new_game_dialog.hide()
	game.queue_free()
	await process_frame
	print("Timber challenge: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
