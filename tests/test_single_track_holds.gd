extends SceneTree
const Geometry = preload("res://scripts/track_geometry.gd")
const Router = preload("res://scripts/rail_router.gd")
const SingleTrack = preload("res://scripts/core/single_track.gd")
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
	# Pure rules: plain tiles only, head-on overlap only.
	var tracks: Dictionary = {}
	for x in range(0, 8): tracks[Vector2i(x, 0)] = false
	for sx in [0, 4, 7]: tracks[Vector2i(sx, 0)] = "junction_6_2_3"
	var cells: Array[Vector2i] = []
	for x in range(0, 8): cells.append(Vector2i(x, 0))
	var path := Router.make_path(cells, 32)
	var east := SingleTrack.corridor(path, 16.0, 7 * 32.0 + 16.0, tracks, 32.0)
	var west := SingleTrack.corridor(path, 7 * 32.0 + 16.0, 16.0, tracks, 32.0)
	check(not east.has(Vector2i(4, 0)) and east.has(Vector2i(3, 0)) and east.has(Vector2i(5, 0)), "switch tiles are not claimed")
	check(east[Vector2i(3, 0)] == Vector2i(1, 0) and west[Vector2i(3, 0)] == Vector2i(-1, 0), "headings follow the direction of travel")
	check(SingleTrack.conflict(east, {7: {"corridor": west}}, 1) == 7, "opposing claims conflict")
	check(SingleTrack.conflict(east, {7: {"corridor": east}}, 1) == -1, "following claims do not conflict")
	check(SingleTrack.conflict(east, {1: {"corridor": west}}, 1) == -1, "a train never conflicts with itself")

	# Two services on single track between sidings must never lock head to head.
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
	game.paused = false
	for i in range(60 * 6): tick(game)
	game.paused = true
	var bought: Dictionary = game.buy_fleet_train(game.Fleet.MODELS.keys()[0])
	game.start_passenger_service(int(bought.id), "a")
	var key: String = game.Fleet.find(game.fleet, int(bought.id)).service
	var configuration: Dictionary = game.services.duplicate(true)
	configuration[key]["stops"] = ["a", "b", "c"]
	configuration[key]["platforms"] = {"a": 0, "b": 0, "c": 0}
	configuration["passenger"]["platforms"] = {"a": 0, "b": 0}
	check(game.apply_service_routes(configuration).begins_with("Routes applied"), "both services accept Auto platforms")
	game.paused = false
	var overlap := false
	var first_delivered: int = game.passengers_delivered
	var moved_c := false
	var held_seen := false
	for i in range(60 * 240):
		tick(game)
		if i % 30 == 0:
			var seen: Dictionary = {}
			for train in game.reservation_trains.values():
				for cell in game.reservations.footprint(train.path, train.distance, 32, train.length):
					if seen.has(cell) and int(seen[cell]) != int(train.id): overlap = true
					seen[cell] = train.id
			moved_c = moved_c or game.passenger_services[key].position.x > 34 * 32
			held_seen = held_seen or not game.section_held.is_empty()
	check(game.deadlocks.cycles.is_empty(), "no deadlock after four simulated minutes: %s" % str(game.reservation_waits))
	check(not overlap, "bodies never overlap")
	check(moved_c and game.passengers_delivered > first_delivered + 100, "both services keep delivering (%d)" % game.passengers_delivered)
	check(held_seen, "a train was held at a stop for the opposing train")
	game.queue_free()
	await process_frame
	print("Single-track holds: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
