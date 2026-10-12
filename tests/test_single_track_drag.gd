extends SceneTree
const Builder = preload("res://scripts/track_builder.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
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
func mouse(game: Node, point: Vector2, pressed: bool) -> void:
	game.pointer = point
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	game._unhandled_input(event)
func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.set_script(MouseGame)
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	game.money = 5000
	var origin := Vector2i(45, 35)
	var initial: Dictionary = game.tracks.duplicate()
	var funds: int = game.money
	for draw_mode in [false, true]:
		game.draw_track_mode = draw_mode
		for direction in Geometry.DIRECTIONS:
			var start: Vector2 = game._cell_center(origin)
			mouse(game, start, true)
			check(game.build_plan.new_count == 1 and game._get_preview_cost() == game.TRACK_BUILD_COST, "press previews exactly one piece")
			game.pointer = start + Vector2(direction) * 8.0
			game._refresh_build_plan(origin)
			check(game.build_plan.new_count == 1 and Geometry.same_connections(game.build_plan.tiles[origin], Geometry.from_ports(direction, -direction)), "short drag rotates one piece without a second tile")
			mouse(game, game.pointer, false)
			check(game.tracks.size() == initial.size() + 1 and game.money == funds - game.TRACK_BUILD_COST, "one-cell release builds and charges exactly one tile")
			game._undo_construction()
			check(game.tracks == initial and game.money == funds, "single-piece undo restores exact track and funds")
			game._redo_construction()
			check(game.tracks.has(origin) and game.tracks.size() == initial.size() + 1, "single-piece redo adds no extra tile")
			# Extending the piece by one grid cell must add exactly one more.
			mouse(game, start, true)
			mouse(game, game._cell_center(origin + direction), false)
			check(game.tracks.size() == initial.size() + 2 and game.money == funds - 2 * game.TRACK_BUILD_COST, "one-cell extension adds only one new piece")
			game._undo_construction()
			game._undo_construction()
			check(game.tracks == initial and game.money == funds, "extension and original stroke are separate undo actions")
		# A nearby off-axis pointer must not create a whole bend automatically.
		for direction in Geometry.DIRECTIONS:
			game.tracks[origin] = Geometry.from_ports(direction, -direction)
			var toward: Vector2i = Geometry.DIRECTIONS[(Geometry.DIRECTIONS.find(direction) + 1) % 8]
			mouse(game, game._cell_center(origin), true)
			game.pointer = game._cell_center(origin + toward)
			game._refresh_build_plan(origin + toward)
			check(game.build_plan.error.is_empty() and game.build_plan.new_count == 1, "off-axis first extension previews one piece")
			check(Geometry.same_connections(game.build_plan.tiles[origin + direction], game.tracks[origin]), "first extension follows the existing rail")
			mouse(game, game.pointer, false)
			check(game.tracks.size() == initial.size() + 2 and game.money == funds - game.TRACK_BUILD_COST, "off-axis extension builds and charges one piece")
			game._undo_construction()
			game.tracks.erase(origin)
			check(game.tracks == initial and game.money == funds, "off-axis extension undo restores the original state")
		# Starting beside, rather than on, the rail must not add a second piece.
		for direction in Geometry.DIRECTIONS:
			game.tracks[origin] = Geometry.from_ports(direction, -direction)
			var adjacent: Vector2i = origin + direction
			mouse(game, game._cell_center(adjacent), true)
			mouse(game, game._cell_center(adjacent + direction), false)
			check(game.tracks.size() == initial.size() + 2 and game.tracks.has(adjacent) and not game.tracks.has(adjacent + direction), "adjacent-start one-cell drag creates only one piece")
			check(game.money == funds - game.TRACK_BUILD_COST and Geometry.same_connections(game.tracks[adjacent], game.tracks[origin]), "adjacent extension connects correctly and charges one piece")
			game._undo_construction()
			game.tracks.erase(origin)
		for direction in Geometry.DIRECTIONS:
			mouse(game, game._cell_center(origin), true)
			mouse(game, game._cell_center(origin + direction), false)
			check(game.tracks.size() == initial.size() + 1 and game.tracks.has(origin), "empty-ground one-cell drag creates only one piece")
			game._undo_construction()
			mouse(game, game._cell_center(origin), true)
			mouse(game, game._cell_center(origin + direction * 3), false)
			check(game.tracks.size() == initial.size() + 3 and game.tracks.has(origin + direction * 2) and not game.tracks.has(origin + direction * 3), "three-cell empty-ground drag creates three pieces")
			check(game.money == funds - 3 * game.TRACK_BUILD_COST, "longer drag charges its exact length")
			game._undo_construction()
	# Click without movement defaults to a single horizontal tile.
	mouse(game, game._cell_center(origin), true)
	mouse(game, game.pointer, false)
	check(game.tracks.get(origin) == false and game.tracks.size() == initial.size() + 1, "click places a single horizontal piece")
	game._undo_construction()
	# Single-tile drafts also retain aggregate quotes and atomic application.
	game._set_planning_mode(true)
	mouse(game, game._cell_center(origin), true)
	mouse(game, game.pointer, false)
	check(game.tracks == initial and game.money == funds and game.construction_plan.projected(initial).has(origin), "one-piece draft does not prematurely build or charge")
	game._apply_draft()
	check(game.tracks.size() == initial.size() + 1 and game.money == funds - game.TRACK_BUILD_COST, "applying draft builds exactly one piece")
	game._undo_construction()
	game._set_planning_mode(false)
	# Existing switches and platform inspection must never turn into new rails.
	var fixed: Array[Vector2i] = []
	var one: Array[Vector2i] = [origin]
	var blocked := func(_cell: Vector2i) -> bool: return false
	for kind in [false, true, "junction_6_2_4", "cross_0_2"]:
		var plan: Dictionary = Builder.plan(one, {origin: kind}, Vector2i(80, 50), blocked, fixed)
		check(plan.error.is_empty() and plan.changes.is_empty() and plan.tiles[origin] == kind, "existing single tile is a no-op, including switches")
	var invalid: Array[Vector2i] = [Vector2i(80, 50)]
	check(not Builder.plan(invalid, {}, Vector2i(80, 50), blocked, fixed).error.is_empty(), "single-piece placement still enforces map boundaries")
	check(not Builder.plan(one, {}, Vector2i(80, 50), func(_cell: Vector2i) -> bool: return true, fixed).error.is_empty(), "single-piece placement still protects station grounds")
	game.queue_free()
	await process_frame
	print("Single track drag: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
