extends "res://tests/test_city_scene.gd"
## Persistence through the public slot flow, with strict rejected-save atomicity.
const Migrations = preload("res://scripts/core/save_migrations.gd")

func payload(slot: int) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(slot)))

func step(count: int) -> void:
	game.paused = false
	for index in range(count):
		game.sim_clock.begin_tick()
		game._run_due_commands()
		game._simulation_step(1.0 / 60.0)
	game.paused = true

func reject(data: Dictionary, message: String) -> void:
	var file := FileAccess.open("user://invalid_city.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var state: Dictionary = game.world.save_state()
	var funds: int = game.money
	var fleet: Dictionary = game.fleet.duplicate(true)
	var rng: Dictionary = game.sim_rng.save_state()
	check(not game._load_game("user://invalid_city.json"), message)
	check(game.world.save_state() == state and game.money == funds and game.fleet == fleet and game.sim_rng.save_state() == rng, "rejected load leaves live company intact: " + message)

func run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/dev/city_preview.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	check(game._save_game(1), "save an empty generated company")
	var empty := payload(1)
	check(game._is_valid_save(empty) and empty.game_mode == "cities" and empty.journeys.aboard.is_empty(), "empty city envelope validates without phantom manifests")
	check(game._load_slot(1) and game.fleet.trains.is_empty() and game.tracks.is_empty() and game.reservation_trains.is_empty(), "restore an empty company with no industry rails or ghost actors")
	game._update_toolbar()
	check(not game.save_button.disabled and game.city_builder.button.visible, "city tools and four-slot saving available after load")
	check(not game.ServiceRoutes.is_valid({}) and not game.Fleet.is_valid(game.fleet), "legacy validators retain strict defaults")
	var candidates: Array = game.CityBuildTool.Generator.planning(game.world.save_state()).station_candidates
	var first := Vector2i(candidates[0].cell[0], candidates[0].cell[1])
	var draft: Dictionary = game.CityBuildTool.Construction.draft(game.world.save_state(), first, game.tracks, {}, {}, game.money)
	game.command_queue.enqueue(game.sim_clock.tick + 10, "build_station", game.CityBuildTool.Command.encode(draft))
	check(game._save_game(2) and game._load_slot(2) and game.command_queue.count() == 1 and game.world.stations().is_empty(), "future station command survives save/load without premature purchase")
	step(10)
	check(game.world.stations().size() == 1 and game.command_queue.is_empty() and game.money == 4700, "restored station command purchases exactly once on its fixed tick")
	check(game._load_slot(1), "restore empty baseline after command coverage")
	game.city_builder.submit(first)
	check(game.world.stations().size() == 1, "station construction remains usable after restoring empty city")
	var stored: Dictionary = game.buy_fleet_train("passenger_standard")
	check(stored.ok and stored.id == 1 and game._save_game(2) and game._is_valid_save(payload(2)), "store first unassigned locomotive with next ID two")
	check(game._load_slot(2) and game.fleet.next_id == 2 and game.fleet.trains.size() == 1 and game.service_keys().is_empty(), "stored fleet restores without starting a train")
	var second := Vector2i(candidates[1].cell[0], candidates[1].cell[1])
	game.city_builder.submit(second)
	game.money = 50000 # Fixture budget; construction still uses the real purchase path.
	check(connect_stations(first, second), "build a real connected city passenger route")
	var home: String = game.world.station_key(first)
	var destination: String = game.world.station_key(second)
	check(game.start_passenger_service(int(stored.id), home, destination).contains("started"), "start restored stored train")
	game.selected_station = first
	game._buy_amenity("shelter")
	check(game.borrow_money(1000).contains("Borrowed"), "bank loan uses normal company accounting")
	var key: String = game.fleet.trains[0].service
	game.passenger_demand.generate(home, 7, 100, game.sim_rng, game.sim_clock.tick)
	step(240)
	game.passenger_demand.generate(destination, 5, 100, game.sim_rng, game.sim_clock.tick)
	check(game.passenger_services[key].passengers == 7 and game.passenger_demand.waiting(destination) == 5, "fixture includes onboard journeys and station queue batches")
	var physical: Vector2 = game.passenger_services[key].position
	check(physical != game._cell_center(first), "passenger train is physically away from its start")
	var auto_before: String = JSON.stringify(game._save_snapshot(), "", true, true)
	var recovery_path: String = game.Autosaves.write(4, game._save_snapshot())
	check(not recovery_path.is_empty(), "autosave a moving city train without manual save synchronisation")
	check(JSON.stringify(game._save_snapshot(), "", true, true) == auto_before, "city autosave preserves live state")
	check(game._load_autosave(4, recovery_path), "recover moving city train, upgrades, loan and onboard journeys")
	check(game.passenger_services[key].position.distance_to(physical) < 0.001, "city autosave recovery preserves physical train position")
	check(game._save_game(3) and game._is_valid_save(payload(3)), "save and validate a moving passenger-only company")
	var active := payload(3)
	var before_rng: Dictionary = game.sim_rng.save_state()
	var before_world: Dictionary = game.world.save_state()
	var before_money: int = game.money
	var before_tick: int = game.sim_clock.tick
	step(120)
	var continued: Dictionary = game.passenger_services[key].save_state()
	var continued_rng: Dictionary = game.sim_rng.save_state()
	var continued_money: int = game.money
	game.station_panel.show()
	game.selected_station = game.FOREST_SITE
	check(game._load_slot(3), "load passenger-only city save")
	check(not game.station_panel.visible and game.selected_station == Vector2i(-1, -1), "loading clears stale station inspection")
	check(JSON.parse_string(JSON.stringify(game.loans.save_state())) == active.loans and JSON.parse_string(JSON.stringify(game.amenities.to_save())) == active.amenities, "loan interest and station upgrades restore")
	check(game.passenger_services[key].position.distance_to(physical) < 0.001 and game.world.save_state() == before_world and game.money == before_money and game.sim_clock.tick == before_tick and game.sim_rng.save_state() == before_rng, "restore exact physical position, geometry, accounts, tick and RNG")
	check(JSON.parse_string(JSON.stringify(game.passenger_demand.save_state({}, game.sim_clock.tick))) == active.demand and JSON.parse_string(JSON.stringify(game._saved_journeys())) == active.journeys, "station queues and journey manifests restore together")
	step(120)
	check(game.passenger_services[key].save_state() == continued and game.sim_rng.save_state() == continued_rng and game.money == continued_money, "resumed simulation reproduces the uninterrupted continuation")
	check(game._load_slot(3), "reload before testing damaged saves")
	var bad := active.duplicate(true)
	bad.game_mode = "tutorial"
	reject(bad, "reject city geometry labelled as tutorial")
	bad = active.duplicate(true)
	bad.world.facilities[-1].settlement_id = "town:missing"
	reject(bad, "reject a station with an orphan city link")
	bad = active.duplicate(true)
	bad.tracks = bad.tracks.filter(func(row: Array) -> bool: return row[0] != first.x + 2 or row[1] != first.y)
	reject(bad, "reject a missing purchased platform extension")
	bad = active.duplicate(true)
	bad.runtime.passenger_cells = [[0, 0], [1, 0]]
	reject(bad, "reject geometry for an absent primary actor")
	bad = active.duplicate(true)
	bad.freight.cargo = 1
	reject(bad, "reject cargo in an absent freight actor")
	bad = active.duplicate(true)
	var duplicate_train: Dictionary = bad.fleet.trains[0].duplicate(true)
	duplicate_train.id = 8
	duplicate_train.service = "passenger_8"
	bad.fleet.trains.append(duplicate_train)
	bad.fleet.next_id = 9
	bad.services.passenger_8 = bad.services[key].duplicate(true)
	bad.passenger_services.passenger_8 = bad.passenger_services[key].duplicate(true)
	bad.journeys.aboard.passenger_8 = bad.journeys.aboard[key].duplicate(true)
	reject(bad, "reject two saved trains occupying the same body tiles")
	check(game.notice.contains("overlapping train bodies"), "collision rejection comes from physical occupancy staging")
	# Missing track ahead is a legal stopped service, not a reason to teleport it.
	var missing: Vector2i = game.passenger_services[key].cells[-4]
	game.tracks.erase(missing)
	game._check_route()
	check(game._save_game(2) and game._load_slot(2) and game.passenger_services[key].position.distance_to(physical) < 0.001 and not game.tracks.has(missing), "damaged route restores retained geometry and actual train position")
	check(game._load_slot(3), "restore complete network after damaged-route coverage")
	# A valid moved city and station are restored from saved geometry, never a seed rerun.
	var moved := empty.duplicate(true)
	moved.world.settlements[0].name = "Saved City"
	moved.world.settlements[0].cell[0] += 1
	var file := FileAccess.open("user://moved_city.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(moved))
	file.close()
	check(game._load_game("user://moved_city.json") and game.world.state.settlements[0].name == "Saved City" and game.world.state.settlements[0].cell[0] == moved.world.settlements[0].cell[0], "restore saved geometry and name instead of regenerating seed")
	check(game._load_slot(3), "return to running city company")
	var third := Vector2i(candidates[2].cell[0], candidates[2].cell[1])
	game.city_builder.submit(third)
	check(game.world.stations().size() == 3 and game.passenger_services[key].position.distance_to(physical) < 0.001, "construction after load preserves the existing actor")
	# Freight is independently optional, and retains its physical state too.
	var freight: Dictionary = game.buy_fleet_train("freight_standard")
	var rails: Array = []
	for x in range(game.FOREST_SITE.x, game.CARGO_TERMINAL.x + 1): rails.append([x, game.FOREST_SITE.y, false])
	game._execute_build({"cells": rails})
	check(game.start_freight_service(int(freight.id)).contains("started"), "start independent city freight")
	step(240)
	var freight_position: Vector2 = game.freight_train.position
	check(game._save_game(4) and game._is_valid_save(payload(4)), "mixed city company saves in the fourth slot")
	var mixed := payload(4)
	check(game._load_slot(4) and game.freight_train.position.distance_to(freight_position) < 0.001 and game.reservation_trains.size() == 2, "mixed company restores both actors and recomputes reservations")
	# Simulate freight-only company using a separate empty city session.
	check(game._load_slot(1), "return to empty company for freight-only coverage")
	game.buy_fleet_train("passenger_standard")
	game._save_game(2)
	game._load_slot(1)
	game.money = 50000
	freight = game.buy_fleet_train("freight_standard")
	game._execute_build({"cells": rails})
	check(game.start_freight_service(int(freight.id)).contains("started"), "freight can be first active service")
	step(240)
	check(game._save_game(2) and game._is_valid_save(payload(2)) and game._load_slot(2), "freight-only city round trip without passenger stations")
	check(game.service_keys() == ["freight"] and game.reservation_trains.size() == 1 and game.passenger_demand.station_ids.is_empty(), "freight-only restore creates no passenger actor or queues")
	check(FileAccess.file_exists(game.SaveSlots.path(2, "backup")) and JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(2, "backup"))).fleet.trains[0].service == "", "slot backup retains the overwritten stored-train company")
	check(game._load_slot(2), "return to saved freight-only position")
	# Install processors before departure using a fresh empty session.
	check(game._load_game(game.SaveSlots.path(1)), "load empty baseline for processor geometry")
	game.money = 50000
	freight = game.buy_fleet_train("freight_standard")
	game._execute_build({"cells": rails})
	game.start_freight_service(int(freight.id))
	check(game.build_sawmill().contains("installed") and game.build_factory().contains("installed"), "generated sites accept the real processing chain")
	game.Fleet.assigned(game.fleet, "freight").wagons = ["log_wagon"]
	game._apply_fleet_specs()
	game.forest_stock = 20
	game.logs_produced = 20
	step(900)
	check(game._save_game(2) and game._is_valid_save(payload(2)) and game._load_slot(2), "generated processing chain and long freight consist round trip")
	check(game.sawmill.state.installed and game.factory.state.installed and game.reservation_trains.size() == 1, "processor installation and full-body actor restored")
	# Cross-mode loading must work from the normal main scene, not just the preview.
	var tutorial = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(tutorial)
	tutorial.set_process(false)
	tutorial.paused = true
	check(tutorial._save_game(1), "save tutorial using the versioned mode envelope")
	var legacy := payload(1)
	legacy.version = 39
	legacy.erase("game_mode")
	var migration: Dictionary = Migrations.migrate(legacy)
	check(migration.ok and migration.data.game_mode == "tutorial" and tutorial._is_valid_save(migration.data), "version 39 tutorial migration keeps original company state")
	check(tutorial._load_slot(4) and tutorial.city_builder.is_city_game() and tutorial.reservation_trains.size() == 2, "ordinary main scene can load a saved generated company")
	check(game._load_slot(1) and not game.city_builder.is_city_game() and game.service_keys() == ["passenger", "freight"], "generated scene can load a tutorial company")
	check(tutorial._save_game(4) and tutorial._is_valid_save(payload(4)), "city loaded through normal scene remains saveable")
	tutorial.queue_free()
	game.queue_free()
	await process_frame
	print("City saves: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
