extends "res://tests/test_city_scene.gd"
const Check = preload("res://scripts/core/passing_loop_blocks.gd")
const Template = preload("res://scripts/core/passing_loop_template.gd")
const Blueprints = preload("res://scripts/core/track_blueprints.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
func join_outside(tracks: Dictionary, anchor: Vector2i, length: int, orientation: int) -> Vector2i:
	var cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i(-1, 0), Vector2i(-2, 0)]
	for y in [-1, -2, -3]: cells.append(Vector2i(-2, y))
	for x in range(-1, length + 2): cells.append(Vector2i(x, -3))
	for y in [-2, -1, 0]: cells.append(Vector2i(length + 1, y))
	cells.append(Vector2i(length, 0))
	cells.append(Vector2i(length - 1, 0))
	for index in range(cells.size()): cells[index] = anchor + Template.transform(cells[index], orientation)
	for index in range(1, cells.size() - 1): tracks[cells[index]] = Geometry.from_ports(cells[index - 1] - cells[index], cells[index + 1] - cells[index])
	return anchor + Template.transform(Vector2i(-2, -1), orientation)
func run() -> void:
	for orientation in range(4):
		for length in [9, 17, 31]:
			var anchor := Vector2i(20, 12)
			var proposal := Blueprints.place(Template.design(length, orientation), anchor + Template.footprint_offset(orientation), {}, {}, Vector2i(80, 50), func(_cell: Vector2i) -> bool: return false)
			var snapshot := proposal.duplicate(true)
			var result := Check.inspect(anchor, length, orientation, proposal.tracks, proposal.signals)
			check(result.ok and result.issues.is_empty(), "ordinary template has four separate block regions in orientation %d" % orientation)
			check(proposal == snapshot, "block diagnostics never mutate projected graph or signs")
			var boundary := anchor + Template.transform(Vector2i(1, 0), orientation)
			proposal.signals.erase(boundary)
			result = Check.inspect(anchor, length, orientation, proposal.tracks, proposal.signals)
			check(result.ok and result.roles.main == result.roles.first and Check.describe(result).contains("Missing boundary signal"), "missing signal reports real main/approach block merger")
			proposal.signals[boundary] = "auto"
			var break_cell := join_outside(proposal.tracks, anchor, length, orientation)
			result = Check.inspect(anchor, length, orientation, proposal.tracks, proposal.signals)
			check(result.roles.first == result.roles.last and result.roles.main != result.roles.loop, "external connection merges approaches while branch blocks remain separate")
			check(Check.describe(result).contains("outside this template"), "explanation identifies the external unsignalled connection")
			proposal.signals[break_cell] = "auto"
			result = Check.inspect(anchor, length, orientation, proposal.tracks, proposal.signals)
			check(result.issues.is_empty() and result.roles.first != result.roles.last, "adding an external boundary separates approaches")
			proposal.signals[boundary] = "stop"
			result = Check.inspect(anchor, length, orientation, proposal.tracks, proposal.signals)
			check(Check.describe(result).contains("Manual stop") and result.roles.main != result.roles.first, "manual stop remains a boundary but explains its hold")
			proposal.signals[boundary] = "auto"
			var middle := anchor + Template.transform(Vector2i(4, 0), orientation)
			proposal.signals[middle] = "auto"
			result = Check.inspect(anchor, length, orientation, proposal.tracks, proposal.signals)
			check(result.roles.main.size() == 2 and Check.describe(result).contains("Extra signal boundaries"), "additional in-branch signal describes split holding space")
			proposal.signals.erase(middle)
			for y in [1, 2]: proposal.tracks[anchor + Template.transform(Vector2i(4, y), orientation)] = Geometry.from_ports(Template.transform(Vector2i.UP, orientation), Template.transform(Vector2i.DOWN, orientation))
			proposal.tracks[middle] = Geometry.switch_type(Template.transform(Vector2i.LEFT, orientation), Template.transform(Vector2i.RIGHT, orientation), Template.transform(Vector2i.DOWN, orientation))
			proposal.tracks[anchor + Template.transform(Vector2i(4, 3), orientation)] = Geometry.switch_type(Template.transform(Vector2i.LEFT, orientation), Template.transform(Vector2i.RIGHT, orientation), Template.transform(Vector2i.UP, orientation))
			result = Check.inspect(anchor, length, orientation, proposal.tracks, proposal.signals)
			check(result.ok and result.roles.main == result.roles.loop and Check.describe(result).contains("Main branch and Loop branch share"), "added track joining both branches is diagnosed despite edited template")
			proposal.tracks.erase(middle)
			check(not Check.inspect(anchor, length, orientation, proposal.tracks, proposal.signals).ok, "broken template path invalidates interpretation")
	game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	game.inspection_panel.plan_toggle.button_pressed = true
	game._draft_passing_loop(Vector2i(45, 12))
	check(game.inspection_panel.loop_blocks.text.contains("separate signal blocks") and game.inspection_panel.loop_blocks.text.contains("draft"), "UI labels new partition as a draft snapshot")
	var clock: int = game.sim_clock.tick
	var cash: int = game.money
	var live: Dictionary = game.tracks.duplicate()
	game.construction_plan.stage_signals({Vector2i(46, 12): null}, game.track_signals, game.tracks)
	game._update_passing_loop_fit()
	check(game.inspection_panel.loop_blocks.text.contains("Missing boundary signal") and game.inspection_panel.loop_fit.text.contains("Fit unavailable"), "missing boundary refreshes block report independently of unavailable body-fit result")
	check(game.sim_clock.tick == clock and game.money == cash and game.tracks == live, "diagnostics do not run simulation, spend or alter live track")
	game._discard_draft()
	check(not game.inspection_panel.loop_blocks.text.contains("Missing boundary signal"), "discard clears old block warnings")
	game.queue_free()
	await process_frame
	print("Passing loop blocks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
