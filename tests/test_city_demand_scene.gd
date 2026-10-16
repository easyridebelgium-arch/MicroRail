extends "res://tests/test_city_scene.gd"
const Migrations = preload("res://scripts/core/save_migrations.gd")
func step(count: int) -> void:
	game.paused = false
	for index in range(count):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
	game.paused = true
func normalized(value: Variant) -> Variant: return JSON.parse_string(JSON.stringify(value))
func snapshot() -> Dictionary:
	return normalized({"cities": game.city_demand.save_state(), "city_service": game.city_service.save_state(), "city_growth": game.city_growth.save_state(), "queues": game.passenger_demand.save_state({}, game.sim_clock.tick), "journeys": game._saved_journeys(), "trains": game._saved_passenger_services(), "money": game.money, "rng": game.sim_rng.save_state(), "tick": game.sim_clock.tick})
func run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	game.startup_city_seed = "42"
	game.startup_city_count = 3
	root.add_child(game)
	game.set_process(false)
	await process_frame
	var population_before: Dictionary = game.city_demand.save_state()
	step(301)
	check(game.passenger_demand.queues.is_empty() and game.city_demand.summary("town:01").no_station > 0, "unserved city generates measured requests without phantom queues")
	check(game.object_rows().filter(func(row: Dictionary) -> bool: return row.kind == "City")[0].details.contains("Population: 800"), "Find City explains population and unmet demand")
	game._update_objective_panel()
	check(not game.objective_details.text.contains("pending") and game.objective_heading.text.begins_with("FIRST SERVICE") and game.objective_description.text == "Build stations beside two different cities", "objective panel describes the playable sandbox")
	var candidates: Array = game.CityBuildTool.Generator.planning(game.world.save_state()).station_candidates
	var first := Vector2i(candidates[0].cell[0], candidates[0].cell[1])
	var second := Vector2i(candidates[1].cell[0], candidates[1].cell[1])
	check(game.city_builder.preview(first).message.contains("Population served: 800"), "station preview reports its exclusive city's population")
	game.city_builder.submit(first)
	game.city_builder.submit(second)
	check(game.city_demand.summary("town:01").no_station > 0 and game.city_demand.state.cities["town:01"].population == population_before.cities["town:01"].population, "station purchases keep city population/history and create no free passengers")
	check(connect_stations(first, second), "build actual rail connection")
	step(301)
	check(game.passenger_demand.waiting(game.world.station_key(first)) == 0 and game.passenger_demand.waiting(game.world.station_key(second)) == 0, "rails and stations alone do not admit city passengers")
	var bought: Dictionary = game.buy_fleet_train("passenger_standard")
	check(game.start_passenger_service(int(bought.id), game.world.station_key(first), game.world.station_key(second)).contains("started"), "create useful passenger service")
	step(901)
	var key: String = game.fleet.trains[0].service
	var admitted: int = game.city_demand.summary("town:01").queued + game.city_demand.summary("town:02").queued
	check(admitted > 0 and game.passenger_services[key].distance > 1, "real running service admits city trips and moves normally")
	for batch in range(60):
		if game.passengers_delivered > 0: break
		step(60)
	var matched := 0
	for id in game.city_service.state.cities:
		var service_report: Dictionary = game.city_service.summary(id, game.sim_clock.tick)
		matched += int(service_report.totals.delivered)
		check(service_report.pending == int(service_report.totals.queued) - int(service_report.totals.delivered), "accepted city journeys conserve deliveries plus unfinished passengers")
	check(matched == game.passengers_delivered and matched > 0, "real fixed-step final arrivals update request cohorts exactly once")
	check(game.city_demand.summary("town:03").queued == 0 and game.city_demand.summary("town:03").no_station > 0, "unserved third city never uses another city's station")
	game._inspect_station_at(first)
	check(game.station_summary.text.contains("Useful service") and game.station_summary.text.contains("Unfinished is not failed"), "station inspector exposes measured completions and unfinished journeys")
	check(game.station_summary.text.contains("Population: 800") and game.station_summary.text.contains("Joined station queues"), "station inspector shows linked city supply and outcome reasons")
	game.station_panel.hide()
	var geometry: Dictionary = game.world.save_state()
	var physical: Vector2 = game.passenger_services[key].position
	check(game._save_game(1), "save populated city-demand state")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(1)))
	check(saved.version == 46 and game._is_valid_save(saved), "version 46 validates city state alongside actual actors")
	step(601)
	var uninterrupted := snapshot()
	check(game._load_slot(1) and game.passenger_services[key].position.distance_to(physical) < 0.001 and game.world.save_state() == geometry, "load demand without moving trains or regenerating geometry")
	step(601)
	check(snapshot() == uninterrupted, "city requests, queue clocks, journeys, RNG, train state and cash resume exactly")
	# Invalid city ledger must fail before altering any live company state.
	var invalid := saved.duplicate(true)
	invalid.city_demand.cities["town:01"].history[-1].queued += 1
	var file := FileAccess.open("user://bad_city_demand.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(invalid))
	file.close()
	var before := snapshot()
	check(not game._load_game("user://bad_city_demand.json") and snapshot() == before, "invalid outcome conservation rejects atomically")
	# New cohort corruption must fail before changing any actor or live accounting.
	for corruption in ["missing", "overcount", "future", "orphan"]:
		var bad: Dictionary = saved.duplicate(true)
		var cohort_city: Dictionary = bad.city_service.cities["town:01"]
		match corruption:
			"missing": bad.city_service.cities.erase("town:01")
			"overcount": cohort_city.totals.delivered += 1
			"future": cohort_city.cohorts[-1].tick = game.sim_clock.tick + 100000
			"orphan": cohort_city.cohorts[-1].origin = "station:missing"
		var bad_file := FileAccess.open("user://bad_city_service.json", FileAccess.WRITE)
		bad_file.store_string(JSON.stringify(bad))
		bad_file.close()
		before = snapshot()
		check(not game._load_game("user://bad_city_service.json") and snapshot() == before, "invalid service cohort rejected atomically: " + corruption)
	var old_service: Dictionary = saved.duplicate(true)
	old_service.version = 41
	old_service.erase("city_service")
	var service_migration: Dictionary = Migrations.migrate(old_service)
	check(service_migration.ok and service_migration.data.city_service.started_tick == saved.sim.clock.tick and service_migration.data.city_service.cities["town:01"].totals.requested == 0 and game._is_valid_save(service_migration.data), "v41 migration starts an honest empty measurement baseline")
	check(service_migration.data.sim == old_service.sim and service_migration.data.demand == old_service.demand and service_migration.data.journeys == old_service.journeys and service_migration.data.city_demand == old_service.city_demand and service_migration.data.passenger_services == old_service.passenger_services, "v41 migration preserves demand, manifests, passengers, population, events, commands and RNG")
	# Upgrade old generated saves with an empty measured history, keeping existing trips.
	var old := saved.duplicate(true)
	old.version = 40
	old.erase("city_demand")
	var migration: Dictionary = Migrations.migrate(old)
	check(migration.ok and migration.data.city_demand.cities["town:01"].history.is_empty() and migration.data.sim.rng == old.sim.rng and migration.data.demand == old.demand and migration.data.passenger_services == old.passenger_services and game._is_valid_save(migration.data), "v40 migration preserves queues, actor geometry and RNG without inventing historical trips")
	old.world = null
	check(Migrations.migrate(old).ok, "malformed old world does not crash migration; normal world validation rejects it")
	# Same loaded active railway, different rendering rates, same fixed-clock city supply.
	var reference: Dictionary = {}
	for fps in [30, 60, 120]:
		check(game._load_slot(1), "restore FPS test baseline")
		game.paused = false
		game.sim_clock.speed = 2
		for frame in range(fps * 3): game._process(1.0 / fps)
		game.paused = true
		if reference.is_empty(): reference = snapshot()
		check(snapshot() == reference, "city demand and live services repeat at %d FPS" % fps)
	game._load_slot(1)
	game.set_dispatch_hold(int(bought.id), true)
	step(301)
	var last: Dictionary = game.city_demand.state.cities["town:01"].history[-1]
	check(last.queued == 0 and game.passenger_services[key].position.distance_to(physical) < 0.001, "held service does not admit new trips or move while existing queues remain")
	game._load_slot(1)
	var missing: Vector2i = game.passenger_services[key].cells[-4]
	game.tracks.erase(missing)
	game._check_route()
	step(301)
	check(game.city_demand.state.cities["town:01"].history[-1].queued == 0, "broken service route admits no new city trips")
	game.queue_free()
	await process_frame
	print("City demand scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
