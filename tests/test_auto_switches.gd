extends SceneTree
const Builder = preload("res://scripts/track_builder.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const Router = preload("res://scripts/rail_router.gd")
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
	for direction in Geometry.DIRECTIONS:
		for branch in Geometry.DIRECTIONS:
			if branch == direction or branch == -direction: continue
			var old: Dictionary = {}
			for step in range(-2, 3): old[origin + direction * step] = Geometry.from_ports(direction, -direction)
			for outward in [false, true]:
				var cells := Builder.line(origin, origin + branch * 3, old) if outward else Builder.line(origin + branch * 3, origin, old)
				var plan := Builder.plan(cells, old, Vector2i(80, 50), open, fixed)
				check(plan.error.is_empty() and plan.switch_count == 1, "joining or leaving a through line creates one automatic switch")
				var kind: Variant = plan.tiles.get(origin)
				check(Geometry.is_switch(kind) and Geometry.connections(kind).has(branch), "switch branch follows the stroke direction")
				var proposed := old.duplicate()
				proposed.merge(plan.changes, true)
				check(Router.find_route(proposed, origin - direction * 2, origin + direction * 2).size() == 5, "automatic switch preserves the original through route")
				if Geometry.is_switch(kind):
					var stem: Vector2i = Geometry.connections(kind)[0]
					check(not Router.find_route(proposed, origin + branch * 3, origin + stem * 2).is_empty(), "branch is routable to its chosen stem")
	# End beside a line: its neighbor, outside the stroke, must also be updated.
	var old: Dictionary = {origin: false, origin + Vector2i.LEFT: false, origin + Vector2i.RIGHT: false}
	var single: Array[Vector2i] = [origin + Vector2i.UP]
	var side := Builder.plan(single, old, Vector2i(80, 50), open, fixed, Vector2i.UP)
	check(side.error.is_empty() and side.new_count == 1 and side.switch_count == 1 and Geometry.is_switch(side.changes[origin]), "adjacent placement includes the needed neighbor switch")
	fixed.assign([origin])
	check(not Builder.plan(single, old, Vector2i(80, 50), open, fixed, Vector2i.UP).error.is_empty(), "neighbor switch cannot replace a protected platform")
	fixed.clear()
	var kind: Variant = Geometry.switch_type(Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP)
	var junction: Dictionary = {origin: kind, origin + Vector2i.LEFT: false, origin + Vector2i.UP: true}
	var through: Array[Vector2i] = [origin + Vector2i.LEFT, origin, origin + Vector2i.UP]
	var retrace := Builder.plan(through, junction, Vector2i(80, 50), open, fixed)
	check(retrace.error.is_empty() and retrace.changes.is_empty() and retrace.switch_count == 0, "retracing a switch movement preserves it for free")
	var crossing := Builder.plan(Builder.segment(origin + Vector2i.UP * 2, origin + Vector2i.DOWN * 2), old, Vector2i(80, 50), open, fixed)
	check(not crossing.error.is_empty(), "four-way crossing cannot become an invalid switch")

	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.set_script(MouseGame)
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	for draw in [false, true]:
		game.draw_track_mode = draw
		for reverse in [false, true]:
			game.tracks.merge(old, true)
			game.money = 1000
			var initial: Dictionary = game.tracks.duplicate()
			mouse(game, origin if reverse else origin + Vector2i(3, -3), true)
			var end: Vector2i = origin + Vector2i(3, -3) if reverse else origin
			game.pointer = game._cell_center(end)
			game._refresh_build_plan(end, true)
			var count: int = game.build_plan.new_count
			check(game.build_plan.error.is_empty() and game._get_preview_cost() == count * game.TRACK_BUILD_COST + game.SWITCH_COST, "preview includes the switch surcharge")
			mouse(game, end, false)
			check(Geometry.is_switch(game.tracks[origin]) and game.money == 1000 - count * game.TRACK_BUILD_COST - game.SWITCH_COST, "stroke commits switch and exact charge together")
			game._undo_construction()
			check(game.tracks == initial and game.money == 1000, "one Undo restores entire stroke and switch")
			game._redo_construction()
			check(Geometry.is_switch(game.tracks[origin]), "Redo restores automatic switch")
			game._undo_construction()
	game.track_signals[origin] = "auto"
	var initial: Dictionary = game.tracks.duplicate()
	mouse(game, origin + Vector2i(3, -3), true)
	mouse(game, origin, false)
	check(game.tracks == initial and game.money == 1000 and game.track_signals.get(origin) == "auto", "signalled junction refuses entire stroke without removing signal")
	game.track_signals.erase(origin)
	game.money = 50
	mouse(game, origin + Vector2i(3, -3), true)
	mouse(game, origin, false)
	check(game.tracks == initial and game.money == 50, "insufficient switch funds reject whole stroke")
	game.money = 1000
	game._set_planning_mode(true)
	mouse(game, origin + Vector2i(3, -3), true)
	mouse(game, origin, false)
	check(game.tracks == initial and game.construction_plan.quote().cost == 130, "draft quotes three tracks plus one switch")
	check(game._apply_draft() and Geometry.is_switch(game.tracks[origin]) and game.money == 870, "draft applies junction atomically")
	game._undo_construction()
	game._set_planning_mode(false)
	for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	game.route_distance = 96.0
	game._update_train_transform()
	game._rebuild_reservations()
	var occupied := Vector2i(7, 8)
	check(game.reservations.owners.has(occupied), "reserved-switch fixture is physically occupied")
	var reserved_before: Dictionary = game.tracks.duplicate()
	mouse(game, occupied + Vector2i(3, -3), true)
	mouse(game, occupied, false)
	check(game.tracks == reserved_before and game.money == 1000, "occupied junction refuses the switch and every new approach tile")
	game.route_distance = 0.0
	game._update_train_transform()
	# A switch added beside a train's occupied tile must reject the whole build.
	var station: Vector2i = game.STATION_A
	game.tracks[station + Vector2i.RIGHT] = false
	game.tracks[station + Vector2i.RIGHT * 2] = false
	game._check_route()
	var before: Dictionary = game.tracks.duplicate()
	var cells: Array = [[station.x, station.y, kind], [station.x, station.y + 3, false]]
	game._execute_build({"cells": cells, "new_count": 1})
	check(game.tracks == before and game.money == 1000, "protected or occupied junction never partially builds")
	# Queued strokes must not overwrite an edit made before their tick.
	game.paused = false
	mouse(game, origin + Vector2i(3, -3), true)
	mouse(game, origin, false)
	check(game.command_queue.count() == 1 and not Geometry.is_switch(game.tracks[origin]), "running switch stroke waits for fixed tick")
	game.tracks[origin] = true
	game.sim_clock.begin_tick()
	game._run_due_commands()
	check(game.tracks[origin] == true and game.money == 1000 and not game.tracks.has(origin + Vector2i(1, -1)), "stale queued stroke cannot overwrite or partially build")
	game.queue_free()
	await process_frame
	print("Automatic switches: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
