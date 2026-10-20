extends "res://tests/test_city_scene.gd"
const Config = preload("res://scripts/core/new_game_config.gd")
const Shared = preload("res://scripts/core/shared_track_challenge.gd")
func run() -> void:
	var choice := {"mode": "cities", "seed": "4", "city_count": 3, "challenge": "passing_place", "terrain": "flat"}
	var quote := Shared.quote()
	check(quote.ok and quote.total == 2040 and Config.validate(choice).message.contains("£2040"), "preset checks full ordinary budget before starting")
	var model = preload("res://scripts/core/seeded_challenges.gd").new()
	model.initialize("passing_place")
	var measured := {"ready": true, "direct": "passenger_1", "bypass": "passenger_2", "direct_finals": 100, "bypass_finals": 100}
	check(not model.advance(10, {}, {}, measured) and model.state.evidence.direct_finals == 0, "old service deliveries cannot instantly complete a newly ready setup")
	measured.direct_finals = 110
	measured.bypass_finals = 109
	check(not model.advance(11, {}, {}, measured), "each distinct service needs ten new final deliveries")
	check(not model.advance(12, {}, {}, {}) and model.state.evidence.is_empty(), "breaking unfinished setup resets its delivery baseline")
	check(not model.advance(13, {}, {}, measured), "repairing setup starts a fresh measured attempt")
	measured.direct_finals = 120
	measured.bypass_finals = 119
	check(model.advance(14, {}, {}, measured) and not model.advance(15, {}, {}, {}), "completed milestone persists after later layout changes")
	game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	game.startup_city_seed = "4"
	game.startup_city_count = 3
	game.startup_challenge = "passing_place"
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	check(game.money == 5000 and game.tracks.is_empty() and game.fleet.trains.is_empty(), "challenge starts empty without purchases or services")
	game.first_service_guide.open_guide()
	check(game.first_service_guide.heading.text.contains("Passing Place") and game.first_service_guide.preview_button.visible, "specific Guide replaces unrelated nearest-city advice")
	game.first_service_guide.show_preview()
	check(game.first_service_guide.preview.has("loop_cells") and game.money == 5000 and game.tracks.is_empty(), "visual station/loop guide frames checked layout without building")
	game.first_service_guide.clear_preview()
	game.city_builder.submit(Shared.LEFT)
	game.city_builder.submit(Shared.RIGHT)
	var updates: Array = []
	for x in range(33, 64): updates.append([x, 14, false])
	game._execute_build({"cells": updates})
	check(game.shared_track_progress().stations and game.shared_track_progress().connected, "ordinary station and track purchases complete first guide steps")
	game.first_service_guide.open_guide()
	game.first_service_guide._perform()
	check(game.planning_mode and not game.construction_plan.is_empty() and game.money == 4090, "Guide only drafts the suggested loop without spending")
	check(game._apply_draft(), "ordinary atomic plan applies loop and boundaries")
	var a: Dictionary = game.buy_fleet_train("passenger_standard")
	var b: Dictionary = game.buy_fleet_train("passenger_standard")
	check(a.ok and b.ok and game.money == 5000 - quote.total, "actual purchases exactly match checked full budget")
	check(game.start_passenger_service(a.id, Shared.LEFT_ID, Shared.RIGHT_ID).contains("started") and game.start_passenger_service(b.id, Shared.RIGHT_ID, Shared.LEFT_ID).contains("started"), "two services start at opposite stations")
	var direct: String = game.Fleet.find(game.fleet, a.id).service
	var bypass: String = game.Fleet.find(game.fleet, b.id).service
	check(not game.shared_track_progress().ready, "two mainline services alone cannot satisfy shared-track setup")
	game.first_service_guide.open_guide()
	game.first_service_guide._perform()
	var editor: Node = game.route_editor
	check(editor.visible and editor.waypoint_x.value == 48 and editor.waypoint_y.value == 17, "Guide hands exact loop cell to reviewed Routes draft")
	for index in range(editor.service_choice.item_count):
		if editor.service_choice.get_item_metadata(index) == bypass:
			editor.service_choice.select(index)
			editor._select_service(index)
	editor._add_waypoint()
	editor._apply()
	check(editor.status.text.begins_with("Routes applied") and game.shared_track_progress().ready, "ordinary route review configures correct separate branches")
	editor.hide()
	game.inspection_panel.plan_toggle.button_pressed = false
	check(game._save_game(2) and game._load_slot(2), "unfinished scenario evidence and services roundtrip")
	var overlap := false
	var partial_checked := false
	for batch in range(600):
		for tick in range(60):
			game.sim_clock.begin_tick()
			game._simulation_step(1.0 / 60.0)
		if not partial_checked and game.seeded_challenge.state.completed_tick < 0 and not game.seeded_challenge.state.evidence.is_empty():
			var partial: Dictionary = game.seeded_challenge.state.evidence.duplicate(true)
			if partial.direct_finals > 0 or partial.bypass_finals > 0:
				check(game._save_game(2) and game._load_slot(2) and game.seeded_challenge.state.evidence == partial, "partial new-delivery counts and baselines survive save/load")
				partial_checked = true
		if batch % 2 == 0:
			var seen: Dictionary = {}
			for train in game.reservation_trains.values():
				for cell in game.reservations.footprint(train.path, train.distance, 32, train.length):
					if seen.has(cell) and seen[cell] != train.id: overlap = true
					seen[cell] = train.id
		if game.seeded_challenge.state.completed_tick >= 0: break
	check(partial_checked, "physical run exercised a partial measured save before completion")
	check(game.seeded_challenge.state.completed_tick >= 0 and not overlap and game.deadlocks.cycles.is_empty(), "real opposing services safely complete shared-track challenge")
	var evidence: Dictionary = game.seeded_challenge.state.evidence.duplicate(true)
	check(evidence.direct == direct and evidence.bypass == bypass and evidence.direct_finals >= 10 and evidence.bypass_finals >= 10, "completion captures distinct services' actual final deliveries")
	var cash: int = game.money
	game._check_scenario_objectives()
	check(game.money == cash, "scenario awards no repeat or extra cash")
	check(game._save_game(2), "completed milestone saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(2)))
	check(game._is_valid_save(saved) and game._load_slot(2) and game.seeded_challenge.state.evidence == evidence, "completed evidence validates through JSON load")
	var invalid := saved.duplicate(true)
	invalid.seeded_challenge.evidence.bypass = invalid.seeded_challenge.evidence.direct
	check(not game._is_valid_save(invalid), "one service cannot be forged into both milestone roles")
	invalid = saved.duplicate(true)
	invalid.seeded_challenge.evidence.direct_finals = saved.state.passengers_delivered + 1
	check(not game._is_valid_save(invalid), "evidence cannot exceed actual company final deliveries")
	var legacy := saved.duplicate(true)
	legacy.version = 51
	legacy.seeded_challenge = {"id": "", "completed_tick": -1}
	var migrated: Dictionary = game.SaveMigrations.migrate(legacy).data
	check(migrated.version == 53 and migrated.seeded_challenge.evidence.is_empty() and migrated.state == legacy.state and migrated.sim == legacy.sim, "v51 migration adds empty milestone state without changing actors, RNG or accounting")
	game.toggle_fleet_service(b.id)
	for batch in range(180):
		for tick in range(60):
			game.sim_clock.begin_tick()
			game._simulation_step(1.0 / 60.0)
		if game.passenger_services[bypass].at_home(): break
	game.paused = true
	check(game.remove_passenger_service(b.id).contains("stored"), "completed challenge permits legitimate service retirement")
	game._update_objective_panel()
	check(game.objective_heading.text == "SCENARIO COMPLETE" and game.seeded_challenge.state.evidence == evidence, "retiring the measured service does not regress historical milestone")
	check(game._save_game(2) and game._load_slot(2) and not game.services.has(bypass) and game.seeded_challenge.state.completed_tick >= 0, "retired-service milestone still validates and loads")
	game._open_new_game(3)
	game.new_game_dialog.mode_choice.select(2)
	game.new_game_dialog.scenario_choice.select(4)
	game.new_game_dialog.refresh()
	check(game.new_game_dialog.validation.configuration.challenge == "passing_place", "new preset appends without changing previous scenario choices")
	game.new_game_dialog.hide()
	game.queue_free()
	await process_frame
	print("Shared track challenge: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
