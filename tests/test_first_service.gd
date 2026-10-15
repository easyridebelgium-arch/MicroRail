extends "res://tests/test_city_scene.gd"
const Guide = preload("res://scripts/core/first_service.gd")
const Settings = preload("res://scripts/core/game_settings.gd")

func facts() -> Dictionary:
	game.first_service_guide.refresh(0.0, true)
	return game.first_service_guide.snapshot
func next_id() -> String:
	var result := facts()
	return "complete" if result.complete else str(result.rows[result.next].id)
func steps(count: int) -> void:
	for tick in range(count):
		game.sim_clock.begin_tick()
		game._run_due_commands()
		game._simulation_step(1.0 / 60.0)

func run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/dev/city_preview.tscn").instantiate()
	game.startup_allow_cli = false
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	check(not game.first_service_guide.dialog.visible and not game.objective_panel.visible and not game.network_map.visible, "fresh game leaves guide, goals and map collapsed")
	check(next_id() == "stations" and facts().rows.size() == 5, "empty city company starts at two-city station step")
	var before: String = JSON.stringify(game._save_snapshot(), "", true, true)
	game.first_service_guide.open_guide()
	check(game._modal_open() and game.first_service_guide.dialog.visible, "Guide opens a modal checklist")
	check(JSON.stringify(game._save_snapshot(), "", true, true) == before, "opening and reading guide preserves money, RNG, commands, pause and simulation state")
	check(facts().suggestion.contains("closest city centres"), "guide suggests nearest city pair without guaranteeing track layout")
	game.first_service_guide._perform()
	check(game.paused and game.city_builder.active and not game.first_service_guide.dialog.visible, "station action selects existing tool without purchasing")
	check(game.money == 5000 and game.world.stations().is_empty(), "guide never spends startup budget")
	var candidates: Array = game.CityBuildTool.Generator.planning(game.world.save_state()).station_candidates
	var first := Vector2i(candidates[0].cell[0], candidates[0].cell[1])
	var second := Vector2i(candidates[1].cell[0], candidates[1].cell[1])
	game.city_builder.submit(first)
	check(next_id() == "stations", "one station does not satisfy the two-city step")
	game.city_builder.submit(second)
	check(next_id() == "track", "two purchased stations advance to connection")
	game.first_service_guide.open_guide()
	game.first_service_guide._perform()
	check(not game.city_builder.active and not game.draw_track_mode and game.paused, "connection action selects Connect and keeps build paused")
	check(connect_stations(first, second), "build a real graph connection through platform ports")
	check(next_id() == "train", "actual graph route satisfies track step")
	var route: Array = game.RailRouter.find_route(game.tracks, first, second)
	var broken_cell: Vector2i = route[3]
	var original_kind: Variant = game.tracks[broken_cell]
	game.tracks.erase(broken_cell)
	check(next_id() == "track", "broken connection regresses guidance instead of trusting old completion")
	game.tracks[broken_cell] = original_kind
	check(next_id() == "train", "repair restores graph-derived step without resetting company")
	var bought: Dictionary = game.buy_fleet_train("freight_standard")
	check(bought.ok and next_id() == "train", "owning only a freight locomotive does not satisfy passenger train step")
	game.first_service_guide.open_guide()
	game.first_service_guide._perform()
	check(game.fleet_editor.visible and not game.first_service_guide.dialog.visible and game.paused, "train step opens normal Fleet without buying")
	game.fleet_editor.hide()
	bought = game.buy_fleet_train("passenger_standard")
	check(bought.ok and next_id() == "service", "purchased passenger locomotive advances to service setup")
	var home: String = game.world.station_key(first)
	var destination: String = game.world.station_key(second)
	check(game.start_passenger_service(int(bought.id), home, destination).contains("started"), "start service through ordinary Fleet backend")
	check(next_id() == "delivery" and game.passengers_delivered == 0, "starting service does not count as a delivery")
	var key: String = game.fleet.trains.back().service
	game.passenger_demand.generate(home, 7, 100, game.sim_rng, game.sim_clock.tick)
	check(game.passenger_demand.waiting(home) == 7 and not facts().complete and game.first_delivery_notice.is_empty(), "waiting queues produce no completion or first-delivery announcement")
	game.first_service_guide.open_guide()
	game.first_service_guide._perform()
	check(not game.paused and not game.first_service_guide.dialog.visible, "final step resumes the existing simulation")
	steps(240)
	check(game.passenger_services[key].passengers > 0 and game.passengers_delivered == 0 and game.first_delivery_notice.is_empty(), "boarding produces no premature success")
	check(game._finish_passengers(key, home, game.passenger_services[key].passenger_destinations) == 0 and game.first_delivery_notice.is_empty(), "non-destination stop never announces final arrival")
	for tick in range(3600):
		steps(1)
		if game.passengers_delivered > 0: break
	check(game.passengers_delivered > 0 and facts().complete, "physical journey to final destination completes guide")
	check(game.first_delivery_notice.contains("First passengers delivered!") and game.first_delivery_notice.contains("fares £"), "first final arrival records clear feedback with actual fares")
	game.paused = true
	game._process(0.0)
	check(game.notice.contains("First passengers delivered!") and game.first_delivery_notice.is_empty(), "completion message flushes once after fixed-step batch")
	check(game._save_game(4), "completed company saves through unchanged schema")
	game.first_delivery_notice = "obsolete message"
	check(game._load_slot(4) and facts().complete and game.first_delivery_notice.is_empty(), "load reconstructs completion without replaying arrival announcement")
	var cash: int = game.money
	game.first_service_guide.open_guide()
	check(not game.first_service_guide.action_button.visible and game.first_service_guide.heading.text.contains("complete"), "repeat visit shows actual delivered total and no redundant startup action")
	game.first_service_guide._perform()
	check(game.money == cash, "reopening completed guide never grants extra reward")
	game.first_service_guide.close_guide()
	game.construction_plan.stage({Vector2i(0, 0): false}, game.tracks)
	# Regress the live readiness by removing a train assignment; guide must not apply a draft.
	game.passenger_services[key].enabled = false
	game.first_service_guide.open_guide()
	game.first_service_guide._perform()
	check(game.first_service_guide.dialog.visible and not game.construction_plan.is_empty() and game.first_service_guide.detail.text.contains("draft"), "guide actions preserve unapplied construction drafts")
	game.first_service_guide.close_guide()
	game.construction_plan.clear()
	game.passenger_services[key].enabled = true
	game.first_service_guide.open_guide()
	Settings.ui_scale = 2.0
	game._apply_settings()
	game.first_service_guide.open_guide()
	for frame in range(4): await process_frame
	check(game.first_service_guide.dialog.size.y <= 306 and game.first_service_guide.dialog.size.x <= 544, "guide scrolls within 720p viewport at 200% scale")
	game.queue_free()
	await process_frame
	Settings.ui_scale = 1.0
	game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	check(facts().rows.size() == 2 and next_id() == "track", "tutorial only asks to connect and deliver, with no redundant buying or route wizard")
	check(facts().suggestion.contains("already provided"), "tutorial explains automatic starter train")
	game.paused = false
	before = JSON.stringify(game._save_snapshot(), "", true, true)
	game.first_service_guide.open_guide()
	check(game.paused, "guide pauses a running company while reading")
	var reading_tick: int = game.sim_clock.tick
	var reading_cash: int = game.money
	game._process(1.0)
	check(game.sim_clock.tick == reading_tick and game.money == reading_cash, "no simulation time or running costs accrue while reading the guide")
	game.first_service_guide.dialog.confirmed.emit()
	check(JSON.stringify(game._save_snapshot(), "", true, true) == before and not game.paused, "opening/closing guide does not change running tutorial pause or economy")
	game.is_dragging = true
	game.first_service_guide.open_guide()
	check(not game.first_service_guide.dialog.visible and game.is_dragging, "guide refuses active stroke without canceling it")
	game.is_dragging = false
	game.game_menu.open_menu()
	for child in game.game_menu.find_children("*", "Button", true, false):
		if child.text == "First service guide": child.pressed.emit()
	check(not game.game_menu.active and game.first_service_guide.dialog.visible and game.paused, "game menu hands off to Guide without leaving invisible modal ownership")
	game.first_service_guide.dialog.canceled.emit()
	check(not game.paused, "closing guide after menu handoff restores originally running company")
	game.queue_free()
	await process_frame
	print("First service guide: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
