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
func advance_until(game: Node, predicate: Callable, limit: int = 4000) -> bool:
	for step in range(limit):
		if predicate.call(): return true
		tick(game)
	return false
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
	for i in range(3): game.edit_consist(1, "coach")
	var configuration: Dictionary = game.services.duplicate(true)
	configuration.passenger.stops = ["a", "c", "b"]
	check(game.apply_service_routes(configuration).begins_with("Routes applied"), "planned reversal applies")
	game.paused = false
	check(advance_until(game, func() -> bool: return game.passenger_stop_index == 1 and game.wait_remaining > 0), "the train reaches C")
	# A manual stop on the retraced leg, well clear of every stopping area.
	game.paused = true
	game._use_signal_tool(Vector2i(28, 8))
	game._use_signal_tool(Vector2i(28, 8))
	check(game.track_signals.get(Vector2i(28, 8)) == "stop", "manual stop placed on the return leg")
	game.paused = false
	check(advance_until(game, func() -> bool: return game.route_distance > game.stop_distances[1] + 20.0), "the train reverses at C and heads for B")
	check(advance_until(game, func() -> bool: return str(game.reservation_waits.get("passenger", "")).contains("Manual stop")), "the retraced leg is held by the manual stop")
	var held_at: float = game.route_distance
	var nose_cells: Array = game.reservations.footprint(game.route_path, game.route_distance, 32, 124.0)
	check(not nose_cells.has(Vector2i(28, 8)), "the nose waits before the signal tile")
	for step in range(120): tick(game)
	check(absf(game.route_distance - held_at) < 0.01, "it stays put while the signal is red")
	game.paused = true
	for click in range(3): game._use_signal_tool(Vector2i(28, 8))
	game.paused = false
	check(not game.track_signals.has(Vector2i(28, 8)), "the signal is removed")
	check(advance_until(game, func() -> bool: return game.passenger_stop_index == 2), "the train then serves B")
	print("Reversal signals: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
