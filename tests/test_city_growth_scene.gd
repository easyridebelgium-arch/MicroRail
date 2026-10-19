extends "res://tests/test_city_scene.gd"
const Growth = preload("res://scripts/core/city_growth.gd")
const Config = preload("res://scripts/core/new_game_config.gd")
const Migrations = preload("res://scripts/core/save_migrations.gd")
func step(count: int) -> void:
	for index in range(count):
		game.sim_clock.begin_tick()
		game._run_due_commands()
		game._simulation_step(1.0 / 60.0)
func normalized(value: Variant) -> Variant: return JSON.parse_string(JSON.stringify(value))
func snapshot() -> Dictionary:
	return normalized({"reports": game.progress_reports.save_state(), "performance": game.service_performance.save_state(game.services), "growth": game.city_growth.save_state(), "demand": game.city_demand.save_state(), "service": game.city_service.save_state(), "world": game.world.save_state(), "queue": game.passenger_demand.save_state({}, game.sim_clock.tick), "journeys": game._saved_journeys(), "trains": game._saved_passenger_services(), "money": game.money, "rng": game.sim_rng.save_state(), "tick": game.sim_clock.tick, "events": game.event_log.save_state(), "commands": game.command_queue.save_state()})
func run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/dev/city_preview.tscn").instantiate()
	game.startup_allow_cli = false
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	check(game.city_growth.state.rate == "normal" and game.city_growth.state.cities.size() == 4, "city startup initializes per-game growth model")
	var candidates: Array = game.CityBuildTool.Generator.planning(game.world.save_state()).station_candidates
	var first := Vector2i(candidates[0].cell[0], candidates[0].cell[1])
	var second := Vector2i(candidates[1].cell[0], candidates[1].cell[1])
	game.city_builder.submit(first)
	game.city_builder.submit(second)
	check(connect_stations(first, second), "build real generated-city passenger route")
	var purchase: Dictionary = game.buy_fleet_train("passenger_standard")
	check(purchase.ok and game.start_passenger_service(purchase.id, game.world.station_key(first), game.world.station_key(second)).contains("started"), "start normal passenger service for growth evidence")
	for batch in range(120):
		step(60)
		var sufficient := false
		for city in game.city_service.state.cities.values():
			if int(city.totals.delivered) >= 5: sufficient = true
		if sufficient: break
	var actual_deliveries := 0
	for city in game.city_service.state.cities.values(): actual_deliveries += int(city.totals.delivered)
	check(actual_deliveries >= 5 and game.passengers_delivered == actual_deliveries, "actual passengers complete matched journeys before first assessment")
	var geometry: Dictionary = game.world.save_state()
	var baseline_population: Dictionary = {}
	for id in game.city_demand.state.cities: baseline_population[id] = game.city_demand.state.cities[id].population
	# Arrange a near boundary after earning real delivery evidence; avoid spending
	# six real minutes merely to wait for the assessment clock in a regression test.
	game.sim_clock.restore_state({"tick": Growth.PERIOD - 120})
	game.paused = true
	check(game._save_game(1), "save physical company just before its first growth assessment")
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(1)))
	check(before.version == 52 and game._is_valid_save(before), "version 52 validates the population rule and assessment state")
	var reference: Dictionary = {}
	for fps in [30, 60, 120]:
		check(game._load_slot(1), "restore population assessment baseline")
		game.paused = false
		game.sim_clock.speed = 10
		for frame in range(fps * 3): game._process(1.0 / fps)
		game.paused = true
		var current := snapshot()
		if reference.is_empty(): reference = current
		check(current == reference, "population, city demand, train state, RNG and events match at %d FPS at 10×" % fps)
	var increases := 0
	for id in game.city_demand.state.cities:
		var city: Dictionary = game.city_demand.state.cities[id]
		if int(city.population) > int(baseline_population[id]): increases += 1
	check(increases > 0 and game.city_growth.state.last_tick == Growth.PERIOD, "fixed-step assessment grows cities supported by final deliveries")
	check(game.notice.contains("City population:"), "population change gives an immediate readable notice")
	check(game.world.save_state() == geometry, "growth never changes city plots, station footprints or track catalog")
	var key: String = game.fleet.trains[0].service
	var physical: Vector2 = game.passenger_services[key].position
	var current_tracks: Dictionary = game.tracks.duplicate(true)
	var routes: Dictionary = game.services.duplicate(true)
	game._advance_city_growth()
	check(game.passenger_services[key].position == physical and game.tracks == current_tracks and game.services == routes, "population response does not teleport trains or alter routes/rails")
	game._inspect_station_at(first)
	check(game.station_summary.text.contains("City response") and game.station_summary.text.contains("floor") and game.station_summary.text.contains("Last assessment"), "station inspector explains growth, limits and measured outcome")
	game.station_panel.hide()
	var city_rows: Array = game.object_rows().filter(func(row: Dictionary) -> bool: return row.kind == "City")
	check(city_rows[0].details.contains("Next assessment") and city_rows[0].details.contains("Decline grace ends"), "Find City exposes next assessment and grace period")
	check(game._save_game(3), "save assessed company with history and fractional state")
	var grown: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(3)))
	step(240)
	var continued := snapshot()
	check(game._load_slot(3), "reload assessed city state")
	step(240)
	check(snapshot() == continued, "assessed population and actual service simulation resume exactly after loading")
	var old := grown.duplicate(true)
	old.version = 42
	old.erase("city_growth")
	var migration: Dictionary = Migrations.migrate(old)
	check(migration.ok and game._is_valid_save(migration.data) and migration.data.city_growth.started_tick == old.sim.clock.tick, "v42 migration starts a fresh grace/assessment baseline at saved game time")
	check(migration.data.city_demand == old.city_demand and migration.data.city_service == old.city_service and migration.data.demand == old.demand and migration.data.journeys == old.journeys and migration.data.sim == old.sim and migration.data.passenger_services == old.passenger_services, "migration preserves population, accepted passengers, physical trains, RNG, events and commands")
	for corruption in ["rate", "missing", "counter", "history", "floor"]:
		var bad: Dictionary = grown.duplicate(true)
		var id: String = bad.city_growth.cities.keys()[0]
		match corruption:
			"rate": bad.city_growth.rate = "unknown"
			"missing": bad.city_growth.cities.erase(id)
			"counter": bad.city_growth.cities[id].delivered = 1000000000
			"history": bad.city_growth.cities[id].history[-1].population += 20
			"floor": bad.city_demand.cities[id].population = 1
		var file := FileAccess.open("user://bad_city_growth.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(bad))
		file.close()
		var unchanged := snapshot()
		check(not game._load_game("user://bad_city_growth.json") and snapshot() == unchanged, "invalid growth data rejects atomically: " + corruption)
	game._open_settings()
	check(game.settings_dialog.growth_box.visible and game.settings_dialog.growth_choice.selected == 0, "city game settings show current per-game growth mode")
	game.settings_dialog.growth_choice.select(2)
	check(game.city_growth.state.rate == "normal", "growth rule remains a draft until Apply")
	game.paused = false
	game.settings_dialog._apply()
	game.settings_dialog.hide()
	check(game.city_growth.state.rate == "normal" and game.command_queue.count() == 1, "running-game growth rule is queued for the next fixed tick")
	game.sim_clock.begin_tick()
	game._run_due_commands()
	game.paused = true
	check(game.city_growth.state.rate == "off", "queued population rule executes at fixed boundary")
	check(game._save_game(2) and game._load_slot(1) and game.city_growth.state.rate == "normal", "Frozen setting in slot 2 does not change slot 1")
	check(game._load_slot(2) and game.city_growth.state.rate == "off", "Frozen mode persists with its own game")
	game.queue_free()
	await process_frame
	game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	root.add_child(game)
	game.set_process(false)
	game._open_settings()
	check(game.city_growth.state.rate == "off" and game.city_growth.state.cities.is_empty() and not game.settings_dialog.growth_box.visible, "tutorial keeps original stationary population model and hides city growth controls")
	game.queue_free()
	await process_frame
	print("City growth scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
