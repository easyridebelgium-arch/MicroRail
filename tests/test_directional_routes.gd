extends SceneTree
const Directional = preload("res://scripts/core/directional_routes.gd")
const Router = preload("res://scripts/rail_router.gd")
const Services = preload("res://scripts/service_routes.gd")
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
	var tracks: Dictionary = {}
	var cells: Array[Vector2i] = []
	for x in range(4, 37): tracks[Vector2i(x, 8)] = false
	for x in range(4, 21): cells.append(Vector2i(x, 8))
	var path := Router.make_path(cells, 32)
	var guard := Directional.new()
	tracks.erase(Vector2i(6, 8))
	check(guard.is_clear(cells, path, 256, 512, tracks, 32), "break behind eastbound train ignored")
	check(not guard.is_clear(cells, path, 256, 0, tracks, 32), "same break blocks westbound travel")
	tracks[Vector2i(6, 8)] = false
	tracks.erase(Vector2i(18, 8))
	check(not guard.is_clear(cells, path, 256, 512, tracks, 32), "break ahead blocks eastbound travel")
	check(guard.is_clear(cells, path, 256, 0, tracks, 32), "break behind westbound train ignored")
	check(guard.is_clear(cells, path, 256, 384, tracks, 32), "gap after next stop does not prevent current leg")
	tracks[Vector2i(18, 8)] = false
	var built := Services.build(tracks, ["a", "c", "b"], 32)
	tracks.erase(Vector2i(10, 8))
	check(guard.is_clear(built.cells, built.path, built.distances[1] + 40, built.distances[2], tracks, 32), "revisited tiles use current occurrence rather than earlier leg")
	check(not guard.is_clear(built.cells, built.path, 64, built.distances[1], tracks, 32), "same repeated path blocks earlier affected leg")
	var snapshots: Array = []
	for fps in [30, 60, 120]:
		var game = load("res://scenes/main/main.tscn").instantiate()
		game.set_process(false)
		root.add_child(game)
		await process_frame
		game.set_process(false)
		game.paused = true
		for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
		for x in range(8, 29): game.tracks[Vector2i(x, 24)] = false
		game._check_route()
		game.route_distance = 256
		game.passengers_on_train = 4
		game.train_needs_boarding = false
		game.freight_train.distance_along_route = 320
		game.freight_train.cargo = 5
		game.logs_produced = 5
		game._update_train_transform()
		game.freight_train._update_transform()
		game.tracks.erase(Vector2i(6, 8))
		game.tracks.erase(Vector2i(10, 24))
		game._check_route()
		check(game.route_connected and game.freight_train.route_valid, "both trains can finish with gap behind")
		var position: Vector2 = game.train_position
		game._save_game()
		game._load_game()
		check(game.route_connected and game.freight_train.route_valid and game.train_position == position, "load preserves permitted travel away from gap")
		game.sim_clock.reset()
		game.event_log.clear()
		game.paused = false
		for frame in range(fps * 8):
			for step in game.sim_clock.advance(1.0 / fps):
				game.sim_clock.begin_tick()
				game._simulation_step(1.0 / 60.0)
		check(game.route_distance == 512 and not game.travelling_to_b and not game.route_connected, "passenger completes trip then waits at turned-around destination")
		check(game.passengers_on_train == 0 and game.passengers_delivered == 4, "passengers unload normally before waiting")
		check(game.freight_train.distance_along_route == 640 and not game.freight_train.to_terminal and not game.freight_train.route_valid, "freight completes trip then waits at terminal")
		check(game.logs_delivered == 5 and game.freight_train.cargo == 0, "freight delivery occurs before return warning")
		check(game._passenger_service_status().contains("Route incomplete ahead") and game.freight_train.status_text().contains("Route incomplete ahead"), "new heading explains broken return path")
		snapshots.append([game.route_distance, game.freight_train.distance_along_route, game.money, game.event_log.save_state()])
		game.paused = true
		game._save_game()
		game._load_game()
		check(not game.route_connected and not game.freight_train.route_valid, "load preserves stopped return leg")
		game.tracks[Vector2i(6, 8)] = false
		game.tracks[Vector2i(10, 24)] = false
		game._check_route()
		game.wait_remaining = 0
		game.freight_train.dwell = 0
		game.paused = false
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
		check(game.route_distance < 512 and game.freight_train.distance_along_route < 640, "repair resumes both return trips from destination")
		game.queue_free()
		await process_frame
	check(snapshots[0] == snapshots[1] and snapshots[1] == snapshots[2], "directional stopping and events match all frame rates")
	print("Directional routes: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
