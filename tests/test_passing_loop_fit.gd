extends "res://tests/test_city_scene.gd"
const Fit = preload("res://scripts/core/passing_loop_fit.gd")
const Template = preload("res://scripts/core/passing_loop_template.gd")
const Blueprints = preload("res://scripts/core/track_blueprints.gd")
const RuntimeSignals = preload("res://scripts/core/block_signals.gd")
const RuntimeReservations = preload("res://scripts/core/track_reservations.gd")
const RuntimeRouter = preload("res://scripts/waypoint_router.gd")
const Paths = preload("res://scripts/rail_router.gd")
const FleetData = preload("res://scripts/fleet.gd")
func run() -> void:
	var fleet := FleetData.empty()
	var locomotive := FleetData.make_train(1, "passenger_standard")
	var consist := FleetData.make_train(2, "passenger_standard")
	consist.wagons = ["coach", "coach", "coach", "coach"]
	fleet.trains = [consist, locomotive]
	fleet.next_id = 3
	var source := fleet.duplicate(true)
	for orientation in range(4):
		var anchor := Vector2i(10, 10)
		var proposal := Blueprints.place(Template.design(9, orientation), anchor + Template.footprint_offset(orientation), {}, {}, Vector2i(80, 50), func(_cell: Vector2i) -> bool: return false)
		var snapshot := proposal.duplicate(true)
		var result := Fit.inspect(anchor, 9, orientation, proposal.tracks, proposal.signals, fleet, 32)
		check(result.ok and result.trains[0].id == 1 and result.trains[1].length == 156, "uses permanent IDs, real consist length and stable row order")
		check(result.trains[0].main and result.trains[0].loop and result.trains[1].main and result.trains[1].loop, "supported short and four-coach trains fit both branches in orientation %d" % orientation)
		check(absf(result.main_span - 160.0) <= 1.1 and result.loop_span > result.main_span, "span is measured along real inner branch geometry")
		check(proposal == snapshot and fleet == source, "measurement does not mutate graph, signs or fleet")
		var main := Fit._branch(anchor, 9, orientation, false, 32)
		var loop := Fit._branch(anchor, 9, orientation, true, 32)
		check(not Fit._fits(main, 208, 32) and Fit._fits(loop, 208, 32), "oversized synthetic body fails short main holding space but fits longer loop")
		var long_main := Fit._branch(anchor, 17, orientation, false, 32)
		check(Fit._fits(long_main, 208, 32), "lengthening restores measured main-branch clearance")
		var outer_a := anchor - Template.transform(Vector2i.RIGHT, orientation)
		var outer_b := anchor + Template.transform(Vector2i(9, 0), orientation)
		var physical_tracks: Dictionary = proposal.tracks.duplicate()
		physical_tracks[outer_a] = orientation >= 2
		physical_tracks[outer_b] = orientation >= 2
		for detour in [false, true]:
			var via := Template.waypoint(anchor, 9, orientation)
			var cells := RuntimeRouter.find_route(physical_tracks, outer_a, outer_b, [[via.x, via.y]] if detour else [])
			var path := Paths.make_path(cells, 32)
			var branch: Dictionary = loop if detour else main
			for direction in [1, -1]:
				var boundary := anchor + Template.transform(Vector2i(8, 2) if detour else Vector2i(7, 0), orientation) if direction == 1 else anchor + Template.transform(Vector2i(0, 2) if detour else Vector2i(1, 0), orientation)
				var signs: Dictionary = proposal.signals.duplicate()
				signs[boundary] = "stop"
				var train := {"id": 7, "path": path, "cells": cells, "distance": path.get_baked_length() * 0.5, "length": 156.0, "moving": true, "forward": direction == 1}
				var signals := RuntimeSignals.new()
				signals.configure(physical_tracks, signs)
				signals.update([train], {}, 32)
				var held := signals.limit(train, path.get_baked_length() if direction == 1 else 0, 32)
				var clears: bool = not held.conflict.is_empty()
				for cell in RuntimeReservations.new().footprint(path, held.distance, 32, 156):
					if not branch.interior.has(cell): clears = false
				check(clears, "reported four-coach fit also clears boundaries at actual long-body runtime stop")
		proposal.signals[anchor + Template.transform(Vector2i(4, 0), orientation)] = "auto"
		check(not Fit.inspect(anchor, 9, orientation, proposal.tracks, proposal.signals, fleet, 32).ok, "additional signal invalidates old fit instead of displaying stale success")
	check(Fit.describe({"ok": true, "main_span": 160, "loop_span": 200, "trains": []}).contains("No owned trains"), "empty sandbox explains why there are no train comparisons")
	game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	game.inspection_panel.plan_toggle.button_pressed = true
	game.inspection_button.button_pressed = true
	var balance: int = game.money
	check(game._draft_passing_loop(Vector2i(45, 12)), "ordinary preview includes measurement")
	check(game.inspection_panel.loop_fit.text.contains("#1") and game.inspection_panel.loop_fit.text.contains("main fits; loop fits"), "UI shows owned-train fits with readable text")
	var before: String = game.inspection_panel.loop_fit.text
	game._update_passing_loop_fit()
	check(game.inspection_panel.loop_fit.text == before and game.money == balance and game.sim_clock.tick == 0, "repeated inspection is read-only and stable")
	game.fleet.trains[0].wagons = ["coach", "coach", "coach", "coach"]
	game._update_passing_loop_fit()
	check(game.inspection_panel.loop_fit.text.contains("4.9 tiles"), "fleet changes refresh cached body measurements")
	game.construction_plan.stage({Vector2i(49, 12): null}, game.tracks)
	game._update_passing_loop_fit()
	check(game.inspection_panel.loop_fit.text.contains("Fit unavailable"), "later draft edits invalidate the measured shape")
	game._discard_draft()
	check(game.passing_loop_preview.is_empty() and not game.inspection_panel.loop_fit.text.contains("#1"), "discard clears old results")
	game._draft_passing_loop(Vector2i(45, 12))
	check(game._apply_draft() and game.passing_loop_preview.is_empty(), "application clears preview-specific diagnostics")
	game._draft_passing_loop(Vector2i(45, 12))
	check(game._save_game(2) and game._load_slot(2) and game.passing_loop_preview.is_empty(), "load never reuses an old fit snapshot")
	game.queue_free()
	await process_frame
	print("Passing loop fit: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
