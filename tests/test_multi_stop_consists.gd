extends SceneTree
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
func advance_until(game: Node, predicate: Callable, limit: int = 2400) -> bool:
	for step in range(limit):
		if predicate.call(): return true
		tick(game)
	check(false, "Multi-stop consist did not reach its expected stop")
	return false
func poses(game: Node) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for offset in game.Consists.offsets(game.Fleet.assigned(game.fleet, "passenger")):
		result.append(game.Consists.pose(game.route_path, game.route_distance + offset).position)
	return result
func _run() -> void:
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.paused = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.money = 10000
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	for x in range(2, 39): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	check(game.edit_consist(1, "coach").begins_with("Attached"), "coach attaches at the empty first station")
	var configuration: Dictionary = game.services.duplicate(true)
	configuration.passenger.stops = ["a", "b", "c"]
	check(game.apply_service_routes(configuration).begins_with("Routes applied"), "coach train accepts a continuous three-stop Shuttle")
	check(game.stop_distances.size() == 3 and game._next_passenger_stop() == 1, "first departure targets B rather than bypassing it")
	for count in range(1, 5):
		var candidate: Dictionary = game.Fleet.find(game.fleet, 1).duplicate(true)
		candidate.wagons = []
		for wagon in range(count): candidate.wagons.append("coach")
		check(game._consist_service_fit(candidate, configuration.passenger).is_empty(), "every supported carriage count fits the extended three-stop route")
	# A-C-B reverses at C and retraces the B-C cells. This planned reversal is
	# supported (see test_planned_reversals.gd); applying it is covered there.
	var invalid: Dictionary = configuration.duplicate(true)
	invalid.passenger.stops = ["a", "c", "b"]
	var before: Dictionary = game.services.duplicate(true)
	check(game._consist_service_fit(game.Fleet.find(game.fleet, 1), invalid.passenger).is_empty(), "a planned reversal at C fits a one-coach train")
	invalid = configuration.duplicate(true)
	invalid.passenger.mode = "loop"
	check(game.apply_service_routes(invalid).contains("Shuttle") and game.services == before, "long Loop remains gated")
	# Keep a stop signal outside B's full stopping area; it must hold the nose.
	game._use_signal_tool(Vector2i(18, 8))
	game._use_signal_tool(Vector2i(18, 8))
	advance_until(game, func() -> bool: return game.traffic_metrics.statistics(1).continuous_seconds > 1.0)
	check(game.passenger_stop_index == 0 and game.route_distance < game.stop_distances[1] and game.reservation_waits.get("passenger", "").contains("Manual stop"), "long multi-stop train obeys a manual signal before B")
	for click in range(3): game._use_signal_tool(Vector2i(18, 8))
	advance_until(game, func() -> bool: return game.passenger_stop_index == 1)
	check(game.travelling_to_b and game._next_passenger_stop() == 2 and game.wait_remaining > 0, "outward arrival at B dwells without reversing")
	var middle_poses := poses(game)
	var middle_body: Array = game.reservations.footprint(game.route_path, game.route_distance, 32, 60)
	check(middle_body.has(Vector2i(19, 8)) and middle_body.has(Vector2i(21, 8)), "body straddles B along previous and next legs")
	game._rebuild_reservations(true)
	var all_owned := true
	for cell in middle_body: all_owned = all_owned and game.reservations.occupied_owners.get(cell) == 1
	check(all_owned, "the full body remains owned while dwelling across a leg boundary")
	game._save_game()
	game._load_game()
	check(game.services.passenger.stops == ["a", "b", "c"] and game.passenger_stop_index == 1 and game.travelling_to_b and poses(game) == middle_poses, "load restores the middle-stop dwell and every vehicle position")
	for step in range(30): tick(game)
	check(poses(game) == middle_poses, "carriages do not move or collapse during middle-stop dwell")
	advance_until(game, func() -> bool: return game.passenger_stop_index == 2)
	check(not game.travelling_to_b and game._next_passenger_stop() == 1, "only the last stop reverses the shuttle")
	advance_until(game, func() -> bool: return game.passenger_stop_index == 1)
	check(not game.travelling_to_b and game._next_passenger_stop() == 0, "return trip stops at B then continues toward A")
	check(poses(game) == middle_poses, "the same physical carriage positions are used at B on the return")
	game._save_game()
	game._load_game()
	check(game.passenger_stop_index == 1 and not game.travelling_to_b and poses(game) == middle_poses, "load preserves the inbound middle-stop direction and body")
	# Physically turn back mid-leg B-A: departure is B, not first stop A.
	advance_until(game, func() -> bool: return game.route_distance < 400.0 and game.wait_remaining == 0.0)
	var distance: float = game.route_distance
	var retained_path: Curve2D = game.route_path
	var vehicle_positions := poses(game)
	check(game.reverse_train(1).contains("reversed in place") and game.passenger_return_stop == 1 and game.route_distance == distance and poses(game) == vehicle_positions, "inbound B-A reversal retains every vehicle and returns to departure B")
	advance_until(game, func() -> bool: return game.passenger_held)
	check(game.route_distance == game.stop_distances[1] and game.passengers_on_train == 0 and not game.passenger_service_enabled and game.route_path == retained_path, "physical recovery finishes at middle stop B without rebuilding the route")
	game.set_dispatch_hold(1, false)
	advance_until(game, func() -> bool: return game.passenger_stop_index == 0)
	check(game.travelling_to_b and game.route_distance == 0, "released recovery completes the return to A")
	# A saved planned reversal (A-C-B) now loads: bodies are routed through the fold.
	game._save_game()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	saved.services.passenger.stops = ["a", "c", "b"]
	var folded: Dictionary = game.ServiceRoutes.build(game.tracks, ["a", "c", "b"], 32)
	saved.runtime.passenger_cells = game.RuntimeRoutes.encode(folded.cells)
	var file := FileAccess.open("user://folded_consist.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	before = game.services.duplicate(true)
	game._load_game("user://folded_consist.json")
	check(game.services.passenger.stops == ["a", "c", "b"] and not game.route_cells.is_empty(), "a saved intermediate reversal loads with its folded route")
	# Independent services use the same continuous body, dwell and saved-leg rules.
	game.passenger_held = true
	var purchased: Dictionary = game.buy_fleet_train("passenger_fast")
	var id := int(purchased.id)
	check(game.edit_consist(id, "coach").begins_with("Attached") and game.start_passenger_service(id, "c").contains("started"), "a stored coach train starts safely at C")
	var key: String = game.Fleet.find(game.fleet, id).service
	configuration = game.services.duplicate(true)
	configuration[key].stops = ["c", "b", "a"]
	check(game.apply_service_routes(configuration).begins_with("Routes applied"), "additional carriage service accepts C-B-A")
	var extra = game.passenger_services[key]
	advance_until(game, func() -> bool: return game.passenger_services[key].stop_index == 1)
	check(extra.forward and extra.next_stop() == 2 and extra.position == game._cell_center(game.STATION_B), "additional train dwells at B without reversing")
	var extra_state: Dictionary = extra.save_state()
	game._save_game()
	game._load_game()
	extra = game.passenger_services[key]
	check(extra.save_state() == extra_state, "additional middle-stop runtime survives loading exactly")
	advance_until(game, func() -> bool: return game.passenger_services[key].distance > 600.0 and game.passenger_services[key].dwell == 0)
	var extra_position: Vector2 = extra.position
	check(game.reverse_train(id).contains("reversed in place") and extra.return_stop == 1 and extra.position == extra_position, "additional coach reverses in place toward its middle departure stop")
	game._save_game()
	game._load_game()
	extra = game.passenger_services[key]
	check(extra.returning and extra.return_stop == 1 and extra.position == extra_position, "additional mid-leg recovery retains its middle-stop origin on load")
	advance_until(game, func() -> bool: return game.passenger_services[key].held)
	check(extra.position == game._cell_center(game.STATION_B) and not extra.enabled and extra.passengers == 0, "additional recovery physically reaches B, returns riders and holds")
	game.queue_free()
	await process_frame
	print("Multi-stop consists: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
