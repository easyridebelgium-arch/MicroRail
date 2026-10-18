extends "res://tests/test_city_scene.gd"
const Challenges = preload("res://scripts/core/seeded_challenges.gd")
const Config = preload("res://scripts/core/new_game_config.gd")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var model := Challenges.new()
	model.initialize("first_connection")
	var measurements := {"cities": {"one": {"totals": {"delivered": 40}}, "two": {"totals": {"delivered": 4}}}}
	check(not model.advance(10, measurements), "raw volume cannot substitute for the second served city")
	measurements.cities.two.totals.delivered = 5
	check(model.advance(11, measurements) and not model.advance(12, measurements) and model.state.completed_tick == 11, "completion is recorded once when all goals hold")
	var restored := Challenges.new()
	restored.restore_state(JSON.parse_string(JSON.stringify(model.save_state())))
	check(restored.save_state() == model.save_state(), "completion survives exact JSON roundtrip")
	check(not Config.validate({"mode": "cities", "seed": "42", "city_count": 3, "challenge": "bad"}).ok, "unknown challenge rejected")
	check(not Config.validate({"mode": "cities", "seed": "43", "city_count": 3, "challenge": "first_connection"}).ok, "preset cannot silently use another seed")
	for key in Challenges.DEFINITIONS:
		var definition: Dictionary = Challenges.DEFINITIONS[key]
		if definition.has("terrain"): continue # River preset has a separate end-to-end suite.
		var configuration := {"mode": "cities", "seed": definition.seed, "city_count": definition.cities, "challenge": key}
		check(Config.validate(configuration).ok, "scenario preview uses validated generated start")
		game = load("res://scenes/main/main.tscn").instantiate()
		game.startup_allow_cli = false
		game.startup_city_seed = definition.seed
		game.startup_city_count = definition.cities
		game.startup_challenge = key
		root.add_child(game)
		game.set_process(false)
		for frame in range(4): await process_frame
		check(game.seeded_challenge.state.id == key and game.money == 5000 and game.tracks.is_empty(), "scenario starts with documented empty city world and budget")
		check(game.objective_panel.visible and game.objective_description.text.contains("Final city journeys"), "scenario goals replace guide panel and are visible initially")
		var candidates: Array = game.CityBuildTool.Generator.planning(game.world.save_state()).station_candidates
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.cell[0]) < int(b.cell[0]))
		var stations: Array = []
		for index in range(int(definition.served)):
			var point := Vector2i(candidates[index].cell[0], candidates[index].cell[1])
			game.city_builder.submit(point)
			stations.append(point)
		check(game.world.stations().size() == definition.served, "required stations can be purchased")
		for index in range(stations.size() - 1): check(connect_stations(stations[index], stations[index + 1]), "required station corridor has a constructible rail witness")
		var purchase: Dictionary = game.buy_fleet_train("passenger_standard")
		var first: String = game.world.station_key(stations[0])
		var second: String = game.world.station_key(stations[1])
		check(purchase.ok and game.start_passenger_service(purchase.id, first, second).contains("started") and game.money > 0, "budget funds actual infrastructure and a working initial train")
		if key == "three_towns":
			var train_key: String = game.Fleet.find(game.fleet, purchase.id).service
			var configuration_routes: Dictionary = game.services.duplicate(true)
			configuration_routes[train_key].stops.append(game.world.station_key(stations[2]))
			check(game.apply_service_routes(configuration_routes).begins_with("Routes applied"), "all three towns support one valid shuttle before challenge play")
			var before: int = game.money
			check(game.borrow_money(1000).contains("disabled") and game.money == before and game.loans.state.borrowed == 0, "no-loan rule enforced in backend, not merely button appearance")
			game.loans_dialog.open_dialog()
			check(game.loans_dialog.offers[1000].disabled and game.loans_dialog.offers[1000].tooltip_text.contains("Scenario rule"), "Bank explains disabled scenario borrowing")
			game.loans_dialog.hide()
		# Complete both presets through actual generated demand and movement.
		for batch in range(240):
			for tick in range(60):
				game.sim_clock.begin_tick()
				game._simulation_step(1.0 / 60.0)
			if int(game.seeded_challenge.state.completed_tick) >= 0: break
		check(int(game.seeded_challenge.state.completed_tick) >= 0, "real generated passenger journeys complete " + key)
		check(game.seeded_challenge.progress(game.city_service.state).served >= definition.served and game.seeded_challenge.progress(game.city_service.state).delivered >= definition.deliveries, "completed scenario reflects real final resident journeys")
		var cash: int = game.money
		var completed: int = game.seeded_challenge.state.completed_tick
		game._check_scenario_objectives()
		check(game.money == cash and game.seeded_challenge.state.completed_tick == completed, "goals award no repeat money and completion is stable")
		check(game._save_game(1), "scenario saves")
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(1)))
		check(saved.version == 51 and game._is_valid_save(saved), "version 51 validates preset and completion")
		var scenario_state: Dictionary = game.seeded_challenge.save_state()
		check(game._load_slot(1) and game.seeded_challenge.save_state() == scenario_state, "load restores scenario identity and progress")
		var bad: Dictionary = saved.duplicate(true)
		bad.seeded_challenge.id = "unknown"
		check(not game._is_valid_save(bad), "unknown scenario save rejected")
		var old: Dictionary = saved.duplicate(true)
		old.version = 45
		old.erase("seeded_challenge")
		var migrated: Dictionary = game.SaveMigrations.migrate(old).data
		check(migrated.seeded_challenge.id == "" and migrated.state == old.state and migrated.sim == old.sim, "older companies remain ordinary sandbox without invented challenge history")
		game._open_new_game(2)
		game.new_game_dialog.mode_choice.select(2)
		game.new_game_dialog.refresh()
		check(game.new_game_dialog.validation.ok and game.new_game_dialog.scenario_choice.visible and not game.new_game_dialog.city_controls.visible, "new-game chooser exposes preset mode without editable seed controls")
		game.new_game_dialog.hide()
		game.queue_free()
		await process_frame
	print("Seeded challenges: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
