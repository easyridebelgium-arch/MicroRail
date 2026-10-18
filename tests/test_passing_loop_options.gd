extends "res://tests/test_city_scene.gd"
const Template = preload("res://scripts/core/passing_loop_template.gd")
const Blueprints = preload("res://scripts/core/track_blueprints.gd")
const Router = preload("res://scripts/waypoint_router.gd")
func run() -> void:
	check(Template.design(8).is_empty() and Template.design(32).is_empty() and Template.design(9, 4).is_empty(), "unsupported dimensions and orientations refuse cleanly")
	for orientation in range(4):
		for length in [9, 10, 17, 31]:
			var design := Template.design(length, orientation)
			check(Blueprints.valid(design), "transformed blueprint valid for orientation %d length %d" % [orientation, length])
			var anchor := Vector2i(10, 10)
			var proposal := Blueprints.place(design, anchor + Template.footprint_offset(orientation), {}, {}, Vector2i(80, 50), func(_cell: Vector2i) -> bool: return false)
			var first := anchor - Template.transform(Vector2i.RIGHT, orientation)
			var last := anchor + Template.transform(Vector2i(length, 0), orientation)
			proposal.tracks[first] = orientation >= 2
			proposal.tracks[last] = orientation >= 2
			var via := Template.waypoint(anchor, length, orientation)
			var direct := Router.find_route(proposal.tracks, first, last, [])
			var loop := Router.find_route(proposal.tracks, first, last, [[via.x, via.y]])
			var reverse := Router.find_route(proposal.tracks, last, first, [[via.x, via.y]])
			check(not direct.is_empty() and not direct.has(via) and loop.has(via) and reverse.has(via), "ports support through and loop routing in both directions for %d/%d" % [orientation, length])
			check(proposal.signals.size() == 4, "orientation retains four signal boundaries")
	game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	game.money = 10000
	game.inspection_panel.plan_toggle.button_pressed = true
	for orientation in range(4):
		game.inspection_panel.loop_length.value = 17
		game.inspection_panel.loop_orientation.select(orientation)
		var anchor := Vector2i(44, 12)
		var cash: int = game.money
		check(game._draft_passing_loop(anchor) and game.money == cash, "UI options stage only")
		var via := Template.waypoint(anchor, 17, orientation)
		check(game.inspection_panel.blueprint_status.text.contains("%d,%d" % [via.x, via.y]), "instructions reflect transformed waypoint")
		check(game.construction_plan.quote().net == 580, "17 tile empty footprint uses normal geometry price")
		check(game._apply_draft() and game.tracks.has(via) and game.money == cash - 580, "rotated/mirrored layout applies atomically")
		game._undo_construction()
		check(not game.tracks.has(via) and game.money == cash, "one undo restores complete transformed layout")
	game.inspection_panel.loop_orientation.select(1)
	check(not game._draft_passing_loop(Vector2i(44, 1)) and game.construction_plan.is_empty(), "above-loop footprint cannot silently clip map top")
	game.inspection_panel.loop_orientation.select(3)
	check(not game._draft_passing_loop(Vector2i(1, 12)) and game.construction_plan.is_empty(), "left-loop footprint cannot silently clip map edge")
	game.inspection_panel.loop_orientation.select(2)
	game._draft_passing_loop(Vector2i(44, 12))
	check(game._apply_draft() and game._save_game(2) and game._load_slot(2), "vertical long loop survives real save and load")
	check(game.track_signals.size() == 4 and game.tracks.get(Vector2i(47, 20)) == true, "loaded track orientation and signal locations retained")
	game.queue_free()
	await process_frame
	print("Passing loop options: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
