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
func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	game.money = 100000
	for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	var configuration: Dictionary = game.services.duplicate(true)
	configuration["passenger"]["stops"] = ["a", "b", "c"]
	configuration["passenger"]["name"] = "Coast Line"
	game.paused = true
	check(game.apply_service_routes(configuration).begins_with("Routes applied"), "source service has three stops")
	var bought: Dictionary = game.buy_fleet_train(game.Fleet.MODELS.keys()[0])
	check(game.duplicate_passenger_service(int(bought.id), "passenger").contains("occupied"), "a copy cannot start on the source's occupied first platform")
	check(game.passenger_services.is_empty(), "a refused copy creates nothing")
	game.paused = false
	for i in range(60 * 8): tick(game)
	game.paused = true
	var message: String = game.duplicate_passenger_service(int(bought.id), "passenger")
	check(message.contains("copy of Coast Line"), "copy starts once the platform is clear: " + message)
	var key: String = game.Fleet.find(game.fleet, int(bought.id)).service
	check(key != "" and game.services[key].stops == ["a", "b", "c"] and game.services[key].name != "Coast Line", "copy has the same stops and its own name")
	check(game.passenger_services[key].cells == game.route_cells, "copy builds the same route")
	check(game.services["passenger"].name == "Coast Line", "the source service is untouched")
	check(game.duplicate_passenger_service(int(bought.id), "freight").begins_with("Choose"), "freight cannot be copied")
	check(game.duplicate_passenger_service(99, "passenger").length() > 0 and game.passenger_services.size() == 1, "an unknown train creates nothing")
	game.queue_free()
	await process_frame
	print("Service duplication: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
