extends SceneTree
const Geometry = preload("res://scripts/track_geometry.gd")
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
func layout(game: Node) -> void:
	for x in range(2, 40): game.tracks[Vector2i(x, 8)] = false
	for sx in [20, 36]:
		game.tracks[Vector2i(sx - 5, 8)] = "junction_6_2_3"
		game.tracks[Vector2i(sx - 4, 9)] = Geometry.from_ports(Vector2i(-1, -1), Vector2i(1, 0))
		for x in range(sx - 3, sx + 4): game.tracks[Vector2i(x, 9)] = false
		game.tracks[Vector2i(sx + 4, 9)] = Geometry.from_ports(Vector2i(-1, 0), Vector2i(1, -1))
		game.tracks[Vector2i(sx + 5, 8)] = "junction_2_6_5"
	for x in range(2, 7): game.tracks[Vector2i(x, 9)] = false
	game.tracks[Vector2i(7, 9)] = Geometry.from_ports(Vector2i(-1, 0), Vector2i(1, -1))
	game.tracks[Vector2i(8, 8)] = "junction_2_6_5"
func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	game.money = 100000
	layout(game)
	game._check_route()
	game.paused = true
	var configuration: Dictionary = game.services.duplicate(true)
	configuration["passenger"]["platforms"] = {"b": 0}
	var applied: String = game.apply_service_routes(configuration)
	check(applied.begins_with("Routes applied"), "routes apply: " + applied)
	var bought: Dictionary = game.buy_fleet_train(game.Fleet.MODELS.keys()[0])
	check(game.start_passenger_service(int(bought.id), "b").contains("started"), "second service starts at B platform 1")
	var key: String = game.Fleet.find(game.fleet, int(bought.id)).service
	check(game.services.passenger.get("auto", {}) == {"b": true}, "the Auto choice is remembered with the service")
	var unchanged: String = game.apply_service_routes(game.services.duplicate(true))
	check(unchanged.begins_with("Routes applied"), "re-applying unchanged services is accepted: " + unchanged)
	var other = game.passenger_services[key]
	other.dwell = 5.0
	game._rebuild_reservations()
	game.paused = false
	game.sim_clock.begin_tick()
	game._maybe_reroute_platform("passenger")
	check(game.services.passenger.platforms.get("b", 1) == 2, "a train re-routes to the free siding when platform 1 is occupied")
	check(game.route_cells.back() == Vector2i(20, 9) and game.route_distance == 0.0, "its route now ends on the siding and it has not moved")
	var saved_cells: Array = game.route_cells.duplicate()
	game._maybe_reroute_platform("passenger")
	check(game.route_cells == saved_cells, "a stable choice is not re-planned")
	for i in range(60 * 60): tick(game)
	check(game.deadlocks.cycles.is_empty(), "no deadlock afterwards")
	game.paused = true
	game._save_game()
	game._load_game()
	check(game.services.passenger.get("auto", {}) == {"b": true}, "the Auto choice survives save and load")
	game.queue_free()
	await process_frame
	print("Platform reroute: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
