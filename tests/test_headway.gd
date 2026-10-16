extends SceneTree
const Headway = preload("res://scripts/core/headway.gd")
const Services = preload("res://scripts/service_routes.gd")
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
func _run() -> void:
	check(Headway.remaining_ticks(-1, 30, 100) == 0 and Headway.remaining_ticks(100, 0, 110) == 0, "no log or no target never holds")
	check(Headway.remaining_ticks(100, 10, 400) == 300 and Headway.remaining_ticks(100, 10, 700) == 0, "holds until the target interval has passed")
	var log: Array = []
	for t in [0, 600, 1500]: log = Headway.record(log, t)
	var stats := Headway.stats(log)
	check(stats.count == 3 and is_equal_approx(stats.last, 15.0) and is_equal_approx(stats.average, 12.5), "actual intervals are measured in seconds")
	check(Headway.infeasible_reason(20, 120.0, 2) != "" and Headway.infeasible_reason(60, 120.0, 2) == "", "a target below round trip / trains is explained")
	check(Headway.infeasible_reason(20, 120.0, 2).contains("6 trains"), "it says how many trains are needed")
	var cfg := Services.defaults()
	cfg["passenger"]["headway"] = 45
	check(Services.is_valid(cfg), "a headway is valid")
	cfg["passenger"]["headway"] = -5
	check(not Services.is_valid(cfg), "a negative headway is invalid")
	cfg["passenger"]["headway"] = 4000
	check(not Services.is_valid(cfg), "an excessive headway is invalid")

	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	game.money = 100000
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
	game._check_route()
	game.paused = true
	# Two linked trains share one route; leave the first stop at least 40 s apart.
	var configuration: Dictionary = game.services.duplicate(true)
	configuration["passenger"]["headway"] = 40
	configuration["passenger"]["platforms"] = {"a": 0, "b": 0}
	check(game.apply_service_routes(configuration).begins_with("Routes applied") and game.services.passenger.headway == 40, "the target applies and is stored")
	var bought: Dictionary = game.buy_fleet_train(game.Fleet.MODELS.keys()[0])
	game.paused = false
	for i in range(60 * 8): tick(game)
	game.paused = true
	check(game.duplicate_passenger_service(int(bought.id), "passenger", true).contains("linked copy"), "a linked copy joins the group")
	var key: String = game.Fleet.find(game.fleet, int(bought.id)).service
	game.paused = false
	var departures: Array = []
	var seen := 0
	var held_text := false
	for i in range(60 * 200):
		tick(game)
		var current: Array = game.headway_log.get("passenger", [])
		if current.size() != seen:
			seen = current.size()
			departures = current.duplicate()
		held_text = held_text or str(game.reservation_waits.get(key, "")).begins_with("Holding for headway")
	var intervals: Array = []
	for index in range(1, departures.size()): intervals.append(float(departures[index] - departures[index - 1]) / 60.0)
	check(departures.size() >= 3, "several departures were logged (%d)" % departures.size())
	var short := false
	for gap in intervals: short = short or gap < 39.5
	check(not short, "no two departures from the first stop are closer than the target: %s" % str(intervals))
	check(held_text, "the waiting train explains the headway hold")
	check(game.headway_report("passenger").contains("Headway target: 40 s") and game.headway_report("passenger").contains("Actual"), "the report shows target and actual intervals")
	game.paused = true
	game._open_routes_editor()
	await process_frame
	check(game.route_editor.headway_controls.visible and game.route_editor.headway_spin.value == 40.0, "Routes shows the target")
	game.route_editor.service_choice.item_selected.emit(2)
	check(not game.route_editor.headway_controls.visible, "a linked service does not show its own headway")
	game.route_editor.hide()
	game.queue_free()
	await process_frame
	print("Headway: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
