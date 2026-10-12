extends SceneTree
const RouteBody = preload("res://scripts/core/route_body.gd")
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
func poses(game: Node) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for offset in game.Consists.offsets(game.Fleet.assigned(game.fleet, "passenger")):
		result.append(game.Consists.body_pose(game.route_path, game.route_distance, offset).position)
	return result
# Constant spacing on one line, in a fixed order, for every vehicle.
func rigid(game: Node) -> bool:
	var points := poses(game)
	for i in range(1, points.size()):
		if absf(points[i - 1].distance_to(points[i]) - 32.0) > 0.7 or absf(points[i].y - points[0].y) > 0.7 or points[i - 1].x < points[i].x: return false
	return true
func owned(game: Node) -> bool:
	game._rebuild_reservations()
	var length: float = game.Fleet.length(game.Fleet.assigned(game.fleet, "passenger"))
	for cell in game.reservations.footprint(game.route_path, game.route_distance, 32, length):
		if game.reservations.occupied_owners.get(cell) != 1: return false
	return true
func _run() -> void:
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.paused = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.money = 20000
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	for x in range(2, 39): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	for i in range(3): check(game.edit_consist(1, "coach").begins_with("Attached"), "coach %d attaches" % (i + 1))
	var configuration: Dictionary = game.services.duplicate(true)
	configuration.passenger.stops = ["a", "c", "b"]
	var message: String = game.apply_service_routes(configuration)
	check(message.begins_with("Routes applied") and game.route_connected, "a three-coach train accepts an A-C-B planned reversal: " + message)
	check(game.stop_distances.size() == 3 and game._next_passenger_stop() == 1, "the first leg targets C")
	var fold: float = RouteBody.folds(game.route_path)[0].distance if not RouteBody.folds(game.route_path).is_empty() else -1.0
	check(fold > 0.0 and absf(fold - game.stop_distances[1]) < 1.0, "the route reverses exactly at stop C")
	game.paused = false
	var always_rigid := true
	var always_owned := true
	var reached_c := false
	var checked_after_fold := false
	var ticks := 0
	var returned := false
	var visited: Array[int] = []
	var saved_mid_fold := false
	while ticks < 20000 and not returned:
		tick(game)
		ticks += 1
		if ticks % 4 == 0:
			always_rigid = always_rigid and rigid(game)
			always_owned = always_owned and owned(game)
		if not visited.has(game.passenger_stop_index): visited.append(game.passenger_stop_index)
		if game.passenger_stop_index == 1 and not reached_c and game.wait_remaining > 0:
			reached_c = true
			game._rebuild_reservations()
			check(game.reservations.occupied_owners.get(Vector2i(37, 8)) == 1 and game.reservations.occupied_owners.get(Vector2i(38, 8)) == 1, "dwelling at C owns the straight extension beyond the stop")
			check(game.reservations.occupied_owners.get(Vector2i(34, 8)) == 1, "and the tiles behind it")
			var dwell_poses := poses(game)
			game._save_game()
			game._load_game()
			check(poses(game) == dwell_poses and game.passenger_stop_index == 1, "load restores the dwell at the reversal point")
		if reached_c and not saved_mid_fold and game.passenger_stop_index == 1 and game.route_distance > fold + 40.0:
			saved_mid_fold = true
			var mid := poses(game)
			var east: bool = mid[0].x > mid[mid.size() - 1].x
			check(east, "after the reversal the locomotive end is still the east end (it propels)")
			check(game.reservations.occupied_owners.get(Vector2i(37, 8), 1) == 1, "the east extension stays owned while the tail clears it")
			game._save_game()
			game._load_game()
			check(poses(game) == mid and rigid(game), "load restores the body just after the reversal")
		if game.passenger_stop_index == 2 and not checked_after_fold:
			checked_after_fold = true
		returned = visited.has(2) and game.passenger_stop_index == 0 and absf(game.route_distance) < 0.01
	check(reached_c, "the train dwells at C")
	check(visited.has(2), "the train serves B after reversing")
	check(always_rigid, "every vehicle stays 32 px apart in order for the whole round trip")
	check(always_owned, "the whole body is always owned by the train")
	check(returned, "the shuttle returns to A after %d ticks" % ticks)
	check(game.reservation_waits.is_empty(), "no conflicts were recorded")
	print("Planned reversals: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
