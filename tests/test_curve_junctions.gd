extends SceneTree
const Builder = preload("res://scripts/track_builder.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const Router = preload("res://scripts/rail_router.gd")
const Blueprints = preload("res://scripts/core/track_blueprints.gd")
class MouseGame:
	extends "res://scripts/main.gd"
	var pointer := Vector2.ZERO
	func _pointer_world() -> Vector2: return pointer
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func mouse(game: Node, cell: Vector2i, down: bool) -> void:
	game.pointer = game._cell_center(cell)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	game._unhandled_input(event)
func _run() -> void:
	var origin := Vector2i(40, 30)
	var open := func(_cell: Vector2i) -> bool: return false
	var fixed: Array[Vector2i] = []
	for first_index in range(8):
		for second_index in range(first_index + 1, 8):
			var first: Vector2i = Geometry.DIRECTIONS[first_index]
			var second: Vector2i = Geometry.DIRECTIONS[second_index]
			var curve: Variant = Geometry.from_ports(first, second)
			if curve == null or Geometry.is_straight(curve): continue
			for branch in Geometry.DIRECTIONS:
				if branch in [first, second]: continue
				var valid_shape: bool = Geometry.switch_type(first, second, branch) != null or Geometry.switch_type(second, first, branch) != null
				for neighbors in [0, 1, 2]:
					var source: Vector2i = origin + branch * 3
					var tracks: Dictionary = {origin: curve, source: Geometry.from_ports(branch, -branch)}
					if neighbors > 0: tracks[origin + first] = Geometry.from_ports(first, -first)
					if neighbors > 1: tracks[origin + second] = Geometry.from_ports(second, -second)
					var before := tracks.duplicate()
					var plan := Builder.plan(Builder.line(source, origin, tracks), tracks, Vector2i(80, 50), open, fixed)
					check(tracks == before, "curve preview never mutates the network")
					if not valid_shape:
						check(not plan.error.is_empty(), "too-tight curve branch is rejected")
						continue
					check(plan.error.is_empty() and plan.switch_count == 1 and plan.new_count == 2, "valid merge onto any curve adds two gaps and one switch")
					var kind: Variant = plan.tiles.get(origin)
					check(Geometry.is_switch(kind) and Geometry.same_connections(Geometry.switch_base(kind), curve), "automatic junction retains the original curve")
					check(Geometry.connections(kind).has(branch), "new branch follows the actual approach")
					var proposed := tracks.duplicate()
					proposed.merge(plan.changes, true)
					if neighbors == 2:
						check(Router.find_route(proposed, origin + first, origin + second).size() == 3, "both old curve connections remain routable")
	# Actual mouse construction, including a saved and reloaded curve layout.
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.set_script(MouseGame)
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	game.money = 1000
	var source := origin + Vector2i.LEFT * 3
	game.tracks[origin] = "NE"
	game.tracks[origin + Vector2i.UP] = true
	game.tracks[origin + Vector2i.RIGHT] = false
	game.tracks[source] = false
	game._save_game()
	game.tracks[origin] = false
	game._load_game()
	check(game.tracks.get(origin) == "NE", "save restores the original curved layout")
	for draw in [false, true]:
		game.draw_track_mode = draw
		var before: Dictionary = game.tracks.duplicate()
		mouse(game, source, true)
		for step in [1, 2, 3]:
			game.pointer = game._cell_center(source + Vector2i.RIGHT * step)
			game._refresh_build_plan(source + Vector2i.RIGHT * step)
		check(game.build_plan.error.is_empty() and game._get_preview_cost() == 120, "Connect and Draw preview a curved turnout with full price")
		mouse(game, origin, false)
		check(Geometry.is_switch(game.tracks[origin]) and Geometry.same_connections(Geometry.switch_base(game.tracks[origin]), "NE") and game.money == 880, "straight approach merges onto curve without replacing its old connections")
		game._undo_construction()
		check(game.tracks == before and game.money == 1000, "Undo restores complete curve layout and balance")
		game._redo_construction()
		check(Geometry.is_switch(game.tracks[origin]), "Redo restores curved switch")
		game._undo_construction()
	# Drafting and blueprints share the same curved base geometry.
	game._set_planning_mode(true)
	mouse(game, source, true)
	mouse(game, origin, false)
	check(game.construction_plan.quote().cost == 120 and game.tracks[origin] == "NE", "draft quotes curved switch without changing real track")
	check(game._apply_draft() and Geometry.is_switch(game.tracks[origin]), "draft applies curved junction")
	game._set_planning_mode(false)
	var data := Blueprints.capture(game.tracks, game.track_signals, origin, origin, "Curve turnout", open)
	var placed := Blueprints.place(data, origin, {origin: "NE"}, {}, Vector2i(80, 50), open)
	check(not data.is_empty() and placed.error.is_empty() and Geometry.is_switch(placed.tracks.get(origin)), "blueprint can add curved turnout onto its original curve")
	game._save_game()
	game.tracks[origin] = "NE"
	game._load_game()
	check(Geometry.is_switch(game.tracks[origin]) and Geometry.same_connections(Geometry.switch_base(game.tracks[origin]), "NE"), "curved junction survives save/load")
	var balance: int = game.money
	for step in range(16):
		game._use_switch_tool(origin)
		if not Geometry.is_switch(game.tracks[origin]): break
		check(Geometry.same_connections(Geometry.switch_base(game.tracks[origin]), "NE") and game.money == balance, "cycling curved switch preserves old base and is free")
	check(game.tracks[origin] == "NE" and game.money == balance + game.SWITCH_COST, "last switch cycle restores original curve and refunds switch")
	# An occupied curve must still reject the whole approach.
	game.tracks = {game.STATION_A: false, game.STATION_B: false, game.STATION_C: false, game.FOREST_SITE: false, game.CARGO_TERMINAL: false}
	for x in range(5, 8): game.tracks[Vector2i(x, 8)] = false
	game.tracks[Vector2i(8, 8)] = "SW"
	for y in range(9, 12): game.tracks[Vector2i(8, y)] = true
	game.tracks[Vector2i(8, 12)] = "NE"
	for x in range(9, 19): game.tracks[Vector2i(x, 12)] = false
	game.tracks[Vector2i(19, 12)] = "NW"
	for y in range(9, 12): game.tracks[Vector2i(19, y)] = true
	game.tracks[Vector2i(19, 8)] = "SE"
	game._check_route()
	game.route_distance = 128.0
	game._update_train_transform()
	game._rebuild_reservations()
	var occupied := Vector2i(8, 8)
	check(game.reservations.owners.has(occupied), "occupied curve fixture belongs to the moving train")
	var network: Dictionary = game.tracks.duplicate()
	balance = game.money
	mouse(game, Vector2i(8, 5), true)
	mouse(game, occupied, false)
	check(game.tracks == network and game.money == balance, "occupied curved junction cannot be modified or partially built")
	game.queue_free()
	await process_frame
	print("Curve junctions: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
