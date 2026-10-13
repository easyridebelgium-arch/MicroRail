extends SceneTree
const Body = preload("res://scripts/core/route_body.gd")
const Consists = preload("res://scripts/core/consists.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: _run.call_deferred()
func tick(game: Node) -> void:
	game.sim_clock.begin_tick()
	game._simulation_step(1.0 / 60.0)
func positions(game: Node) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for offset in Consists.offsets(game.Fleet.assigned(game.fleet, "passenger")):
		result.append(Consists.pose(game.route_path, game.route_distance + offset).position)
	return result
func _run() -> void:
	# Rule checks: a crossing may be crossed once along each line, nothing else.
	var tracks := {Vector2i(1, 0): "cross_0_2", Vector2i(0, 0): false}
	var line: Array = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
	var path := Curve2D.new()
	for point in [Vector2(16, 48), Vector2(80, 48)]: path.add_point(point)
	var eight: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(1, 1), Vector2i(1, 0), Vector2i(1, -1)]
	check(Consists.route_shape_error(path, eight, 124.0, "shuttle", tracks).is_empty(), "a route crossing itself at a crossing is allowed")
	check(Consists.route_shape_error(path, eight, 124.0, "shuttle", {}).contains("crossings"), "the same revisit on ordinary track is refused")
	var parallel: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 0), Vector2i(0, 0)]
	check(not Consists.route_shape_error(path, parallel, 124.0, "shuttle", tracks).is_empty(), "retracing along the same line of a crossing is refused")

	var game = load("res://scenes/main/main.tscn").instantiate()
	game.paused = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.money = 10000
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	for x in range(1, 41): game.tracks[Vector2i(x, 8)] = false
	for x in range(13, 40): game.tracks[Vector2i(x, 16)] = false
	for x in range(2, 12): game.tracks[Vector2i(x, 4)] = false
	for y in range(9, 16):
		game.tracks[Vector2i(40, y)] = true
		game.tracks[Vector2i(12, y)] = true
	for y in range(5, 8):
		game.tracks[Vector2i(12, y)] = true
		game.tracks[Vector2i(1, y)] = true
	game.tracks[Vector2i(12, 8)] = "cross_0_2"
	game.tracks[Vector2i(40, 8)] = "SW"
	game.tracks[Vector2i(40, 16)] = "NW"
	game.tracks[Vector2i(12, 16)] = "NE"
	game.tracks[Vector2i(12, 4)] = "SW"
	game.tracks[Vector2i(1, 4)] = "SE"
	game.tracks[Vector2i(1, 8)] = "NE"
	game._check_route()
	check(game.edit_consist(1, "coach").begins_with("Attached"), "a coach attaches")
	var configuration: Dictionary = game.services.duplicate(true)
	configuration.passenger.stops = ["a", "b", "c"]
	configuration.passenger.mode = "loop"
	configuration.passenger.waypoints = {"c>a": [[40, 16], [12, 16], [12, 4], [1, 4]]}
	var applied: String = game.apply_service_routes(configuration)
	check(applied.begins_with("Routes applied") and Body.is_closed(game.route_path), "a figure-eight Loop can be activated: " + applied)
	check(game.route_cells.count(Vector2i(12, 8)) == 2, "the route visits the crossing twice")
	var visits: Array[int] = []
	var previous := 0
	var max_jump := 0.0
	var crossed_vertically := false
	for step in range(60 * 200):
		var before := positions(game)
		tick(game)
		var after := positions(game)
		for index in range(before.size()): max_jump = maxf(max_jump, before[index].distance_to(after[index]))
		for point in after: crossed_vertically = crossed_vertically or (absf(point.x - 12 * 32 - 16) < 1.0 and point.y < 8 * 32 and point.y > 4 * 32)
		if game.passenger_stop_index != previous:
			previous = game.passenger_stop_index
			visits.append(previous)
		if visits.size() >= 6: break
	check(visits.size() >= 6 and visits.slice(0, 6) == [1, 2, 0, 1, 2, 0], "the train completes two laps of the figure-eight: %s" % str(visits))
	check(max_jump < 1.5, "the body never jumps (%.2f)" % max_jump)
	check(crossed_vertically, "the body travels up through the crossing on the return")
	check(game.deadlocks.cycles.is_empty(), "the train does not block itself at the crossing")
	game.queue_free()
	await process_frame
	print("Figure eight: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
