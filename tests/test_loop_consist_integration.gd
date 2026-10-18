extends SceneTree
const Body = preload("res://scripts/core/route_body.gd")
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
func positions(game: Node, path: Curve2D, distance: float, key: String = "passenger") -> Array[Vector2]:
	var result: Array[Vector2] = []
	for offset in game.Consists.offsets(game.Fleet.assigned(game.fleet, key)):
		result.append(game.Consists.pose(path, distance + offset).position)
	return result
func _run() -> void:
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.paused = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.money = 10000
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	# A-B-C run rightwards. The return continues past C, turns onto a
	# separate upper track and approaches A from the left without reversing.
	for x in range(1, 41):
		game.tracks[Vector2i(x, 8)] = false
		game.tracks[Vector2i(x, 4)] = false
	for y in range(5, 8):
		game.tracks[Vector2i(1, y)] = true
		game.tracks[Vector2i(40, y)] = true
	game.tracks[Vector2i(1, 8)] = "NE"
	game.tracks[Vector2i(1, 4)] = "SE"
	game.tracks[Vector2i(40, 8)] = "NW"
	game.tracks[Vector2i(40, 4)] = "SW"
	for cell in [Vector2i(10, 8), Vector2i(28, 8), Vector2i(30, 4), Vector2i(10, 4)]: game.track_signals[cell] = "auto"
	game._check_route()
	check(game.edit_consist(1, "coach").begins_with("Attached"), "coach attaches with sufficient stopping clearance")
	var configuration: Dictionary = game.services.duplicate(true)
	configuration.passenger.stops = ["a", "b", "c"]
	configuration.passenger.mode = "loop"
	configuration.passenger.waypoints = {"c>a": [[40, 4], [2, 4]]}
	check(game.apply_service_routes(configuration).begins_with("Routes applied") and Body.is_closed(game.route_path), "continuous carriage Loop can be activated")
	for count in range(1, 5):
		var candidate: Dictionary = game.Fleet.find(game.fleet, 1).duplicate(true)
		candidate.wagons = []
		for wagon in range(count): candidate.wagons.append("coach")
		check(game._consist_service_fit(candidate, configuration.passenger).is_empty(), "all supported carriage counts fit the continuous Loop")
	var invalid: Dictionary = configuration.duplicate(true)
	invalid.passenger.waypoints.clear()
	check(not game._consist_service_fit(game.Fleet.find(game.fleet, 1), invalid.passenger).is_empty(), "a Loop closing along the outgoing rails is rejected")
	var visits: Array[int] = []
	var previous := 0
	var wrapped := false
	var max_jump := 0.0
	for step in range(3600):
		var before := positions(game, game.route_path, game.route_distance)
		tick(game)
		var after := positions(game, game.route_path, game.route_distance)
		for index in range(before.size()): max_jump = maxf(max_jump, before[index].distance_to(after[index]))
		if game.passenger_stop_index != previous:
			previous = game.passenger_stop_index
			visits.append(previous)
		if visits == [1, 2, 0]:
			wrapped = true
			break
	print("Primary lap checked")
	check(wrapped and max_jump < 1.5, "all carriages complete A-B-C-A without a wrap jump")
	check(game.travelling_to_b and game.route_distance == 0 and game.wait_remaining > 0, "Loop arrival at A wraps its cursor and dwells without changing direction")
	game._rebuild_reservations(true)
	var body_at_start: Array = game.reservations.footprint(game.route_path, 0, 32, 60)
	var all_owned := true
	for cell in body_at_start: all_owned = all_owned and game.reservations.occupied_owners.get(cell) == 1
	check(all_owned, "every wrapped body tile remains physically owned during A dwell")
	var before := positions(game, game.route_path, 0)
	game._save_game()
	game._load_game()
	check(game.services.passenger.mode == "loop" and positions(game, game.route_path, game.route_distance) == before, "load preserves the Loop body at its first-stop boundary")
	# Save and manually recover on the closing leg: departure C must be kept.
	var closing_start: float = game.stop_distances[2]
	game.route_distance = closing_start + 100.0
	game.passenger_stop_index = 2
	game.train_needs_boarding = false
	game.wait_remaining = 0
	game._update_train_transform()
	before = positions(game, game.route_path, game.route_distance)
	check(game.reverse_train(1).contains("reversed in place") and positions(game, game.route_path, game.route_distance) == before, "closing-leg recovery reverses each vehicle in place")
	game._save_game()
	game._load_game()
	check(game.passenger_returning and game.passenger_return_stop == 2 and positions(game, game.route_path, game.route_distance) == before, "load retains the closing-leg departure C and returning body")
	for step in range(300):
		tick(game)
		if game.passenger_held: break
	check(game.passenger_held and game.passenger_stop_index == 2 and game.route_distance == closing_start, "closing-leg recovery physically returns to C and holds")
	game.set_dispatch_hold(1, false)
	# Finish the closing leg, then add another same-direction carriage circuit.
	for step in range(2000):
		tick(game)
		if game.passenger_stop_index == 0: break
	check(game.passenger_stop_index == 0, "released recovery completes the circuit")
	var bought: Dictionary = game.buy_fleet_train("passenger_fast")
	var id := int(bought.id)
	game.edit_consist(id, "coach")
	check(game.start_passenger_service(id, "c").contains("started"), "additional carriage train starts on a clear C platform")
	var key: String = game.Fleet.find(game.fleet, id).service
	configuration = game.services.duplicate(true)
	configuration[key].stops = ["c", "a", "b"]
	configuration[key].mode = "loop"
	configuration[key].waypoints = {"c>a": [[40, 4], [2, 4]]}
	check(game.apply_service_routes(configuration).begins_with("Routes applied"), "additional service can run the same circuit from C")
	var extra = game.passenger_services[key]
	visits.clear()
	previous = 0
	var overlap := false
	for step in range(4200):
		tick(game)
		var primary: Array = game.reservations.footprint(game.route_path, game.route_distance, 32, 60)
		for cell in game.reservations.footprint(extra.path, extra.distance, 32, 60): overlap = overlap or primary.has(cell)
		if extra.stop_index != previous:
			previous = extra.stop_index
			visits.append(previous)
		if visits == [1, 2, 0]: break
	print("Shared additional lap checked")
	check(visits == [1, 2, 0] and not overlap and game.deadlocks.cycles.is_empty(), "two carriage Loops share signals and complete an additional lap without body overlap")
	var extra_state: Dictionary = extra.save_state()
	game._save_game()
	game._load_game()
	check(game.passenger_services[key].save_state() == extra_state, "additional Loop wrap state survives loading")
	game.queue_free()
	await process_frame
	print("Loop consist integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
