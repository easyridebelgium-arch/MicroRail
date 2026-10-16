extends SceneTree
const Events = preload("res://scripts/core/event_log.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
	for x in range(8, 29): game.tracks[Vector2i(x, 24)] = false
	game._check_route()
	game.route_distance = 96.0
	game.train_needs_boarding = false
	game.passengers_on_train = 4
	game.freight_train.distance_along_route = 96.0
	game.freight_train.cargo = 5
	game.logs_produced = 5
	game._update_train_transform()
	game.freight_train._update_transform()
	game._rebuild_reservations()
	var passenger_position: Vector2 = game.train_position
	var freight_position: Vector2 = game.freight_train.position
	check(game._can_demolish(Vector2i(14, 8)) and game._can_demolish(Vector2i(18, 24)), "unoccupied track ahead can be demolished")
	game.tracks.erase(Vector2i(14, 8))
	game.tracks.erase(Vector2i(18, 24))
	game._check_route()
	check(not game.route_connected and not game.freight_train.route_valid, "disconnection invalidates routes")
	check(game.train_position == passenger_position and game.freight_train.position == freight_position, "disconnection preserves both positions")
	check(game._passenger_service_status().contains("Route incomplete") and game.freight_train.status_text().contains("Route incomplete"), "both trains explain repair requirement")
	game.paused = false
	for step in range(120):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
	check(game.train_position == passenger_position and game.freight_train.position == freight_position, "disconnected trains remain stationary over simulation ticks")
	check(game.passengers_on_train == 4 and game.freight_train.cargo == 5, "stranded payload stays aboard")
	game.paused = true
	game._save_game()
	game.route_distance = 0
	game.freight_train.distance_along_route = 0
	game._load_game()
	check(game.train_position == passenger_position and game.freight_train.position == freight_position, "save restores stranded positions on retained geometry")
	check(not game.route_connected and not game.freight_train.route_valid, "load preserves disconnected condition")
	game.tracks[Vector2i(14, 8)] = false
	game.tracks[Vector2i(18, 24)] = false
	game._check_route()
	check(game.train_position == passenger_position and game.freight_train.position == freight_position, "repair does not reset positions")
	game.paused = false
	game.sim_clock.begin_tick()
	game._simulation_step(1.0 / 60.0)
	check(game.route_distance > 96 and game.freight_train.distance_along_route > 96, "both trains resume from exact stranded positions")
	game.queue_free()
	await process_frame
	print("Stopped routes: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
