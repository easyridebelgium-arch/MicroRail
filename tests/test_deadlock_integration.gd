extends SceneTree
const Geometry = preload("res://scripts/track_geometry.gd")
const Router = preload("res://scripts/rail_router.gd")
const Events = preload("res://scripts/core/event_log.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	_run.call_deferred()
func fixture() -> Node:
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	return game
func prepare(game: Node) -> void:
	game.set_process(false)
	game.paused = false
	game.money = 5000
	for x in range(4, 27): game.tracks[Vector2i(x, 8)] = false
	game.tracks[Vector2i(10, 8)] = "junction_2_6_4"
	game.tracks[Vector2i(26, 8)] = Geometry.from_ports(Vector2i.LEFT, Vector2i.DOWN)
	for y in range(9, 24):
		game.tracks[Vector2i(10, y)] = true
		game.tracks[Vector2i(26, y)] = true
	game.tracks[Vector2i(10, 24)] = Geometry.from_ports(Vector2i.LEFT, Vector2i.UP)
	game.tracks[Vector2i(26, 24)] = Geometry.from_ports(Vector2i.UP, Vector2i.RIGHT)
	game.tracks[Vector2i(9, 24)] = false
	game.tracks[Vector2i(27, 24)] = false
	game._check_route()
	game.route_distance = 128.0
	game.train_needs_boarding = false
	game.passengers_on_train = 7
	game.waiting_at_a = 1
	game._update_train_transform()
	game.freight_train.distance_along_route = game.freight_train.route_path.get_closest_offset(game._cell_center(Vector2i(18, 8)))
	game.freight_train.to_terminal = false
	game.freight_train.cargo = 5
	game.logs_produced = 5
	game.freight_train._update_transform()
	game.sim_clock.reset()
	game.event_log.clear()
	game._rebuild_reservations()
func collide(game: Node, fps: int) -> bool:
	var overlap := false
	for frame in range(fps * 15):
		for step in game.sim_clock.advance(1.0 / fps):
			game.sim_clock.begin_tick()
			game._simulation_step(1.0 / 60.0)
			var body: Array = game.reservations.footprint(game.route_path, game.route_distance, 32)
			for cell in game.reservations.footprint(game.freight_train.route_path, game.freight_train.distance_along_route, 32):
				overlap = overlap or body.has(cell)
			if not game.deadlocks.cycles.is_empty(): break
		if not game.deadlocks.cycles.is_empty(): break
	return overlap
func _run() -> void:
	var snapshots: Array = []
	for fps in [30, 60, 120]:
		var game = fixture()
		await process_frame
		prepare(game)
		check(not game.freight_route_cells.is_empty(), "fixture shares a valid switch and passenger main line")
		check(not collide(game, fps), "head-on trains stop without overlap at %d FPS" % fps)
		check(game.deadlocks.cycles == [[1, 2]], "sustained mutual wait is detected")
		check(game.event_log.query(Events.DEADLOCK_DETECTED).size() == 1, "one detection event per incident")
		for step in range(120):
			game.sim_clock.begin_tick()
			game._simulation_step(1.0 / 60.0)
		check(game.event_log.query(Events.DEADLOCK_DETECTED).size() == 1, "confirmed deadlock does not spam events")
		snapshots.append([game.route_distance, game.freight_train.distance_along_route, game.money, game.sim_clock.tick, game.event_log.save_state()])
		var before: float = game.route_distance
		check(game.recall_deadlocked_train(1).contains("Pause"), "running recovery is refused")
		check(game.route_distance == before, "refused recovery preserves position")
		game._open_traffic_dialog()
		await process_frame
		check(game.paused and game._modal_open(), "Traffic pauses simulation and owns input")
		check(game.traffic_dialog.details.text.contains("Deadlock"), "dialog identifies the blocked trains")
		var old_scale: float = Settings.ui_scale
		Settings.ui_scale = 2.0
		game._apply_settings()
		game.traffic_dialog.hide()
		game.traffic_dialog.open_dialog()
		await process_frame
		await process_frame
		check(game.traffic_dialog.size.x <= root.get_visible_rect().size.x and game.traffic_dialog.size.y <= root.get_visible_rect().size.y, "Traffic fits the viewport at 200%")
		check(game.traffic_dialog.get_ok_button().get_global_rect().end.y <= game.traffic_dialog.size.y, "Recall button remains reachable")
		Settings.ui_scale = old_scale
		game._apply_settings()
		# Block the destination to verify validation is atomic.
		var freight_path: Curve2D = game.freight_train.route_path
		var freight_distance: float = game.freight_train.distance_along_route
		var near_home: Array[Vector2i] = [game.STATION_A, game.STATION_A + Vector2i.RIGHT]
		game.freight_train.route_path = Router.make_path(near_home, 32)
		game.freight_train.distance_along_route = 0.0
		check(game.recall_deadlocked_train(1).contains("refused"), "occupied recall destination is refused")
		check(game.route_distance == before and game.passengers_on_train == 7 and game.deadlocks.contains(1), "failed recall preserves train, passengers and incident")
		game.freight_train.route_path = freight_path
		game.freight_train.distance_along_route = freight_distance
		var waiting: int = game.waiting_at_a
		var money: int = game.money
		game.traffic_dialog.confirmed.emit()
		check(game.route_distance == 0 and not game.passenger_service_enabled and game.passengers_on_train == 0, "recall parks and disables passenger service")
		check(game.waiting_at_a == waiting + 7 and game.money == money, "recall conserves passengers and charges no hidden fee")
		check(game.deadlocks.cycles.is_empty(), "recall clears the deadlock")
		check(game.event_log.query(Events.TRAIN_RECOVERED).size() == 1, "recall logged with permanent train ID")
		var other_distance: float = game.freight_train.distance_along_route
		game.traffic_dialog.hide()
		game.paused = false
		for step in range(10):
			game.sim_clock.begin_tick()
			game._simulation_step(1.0 / 60.0)
		check(game.freight_train.distance_along_route < other_distance, "other train advances when the recalled train clears")
		check(game.route_distance == 0, "recalled service remains stopped until enabled")
		game.queue_free()
		await process_frame
	check(snapshots[0] == snapshots[1] and snapshots[1] == snapshots[2], "detection, timing, money and events match at 30/60/120 FPS")
	# Freight recall keeps cargo on the stopped train and survives save/load.
	var game = fixture()
	await process_frame
	prepare(game)
	collide(game, 60)
	game.paused = true
	var blocked_position: float = game.route_distance
	game._save_game()
	game._load_game()
	check(game.route_distance == blocked_position and game.deadlocks.cycles.is_empty(), "waiting save restores positions without a stale incident")
	game.paused = false
	check(not collide(game, 60) and game.deadlocks.cycles == [[1, 2]], "a persistent cycle is safely rediscovered after loading")
	game.paused = true
	var stock: int = game.forest_stock
	check(game.recall_deadlocked_train(2).contains("recalled"), "freight has a recovery option")
	check(game.freight_train.cargo == 5 and game.forest_stock == stock and game.logs_delivered == 0, "freight recall neither drops nor delivers cargo")
	check(not game.freight_train.service_is_active() and game.freight_train.distance_along_route == 0, "recalled freight is stopped at forest")
	game._save_game()
	game.freight_train.cargo = 0
	game._load_game()
	check(game.freight_train.cargo == 5 and not game.freight_train.service_enabled, "existing v18 saves preserve recovery state")
	check(game.deadlocks.cycles.is_empty(), "load starts with transient deadlock state reset")
	game.waiting_at_a = 105
	game.passenger_timer = 0.0
	game._generate_passengers(5.0)
	check(game.waiting_at_a == 105, "new passenger generation never discards returned overflow queues")
	check(game.recall_deadlocked_train(2).contains("not involved"), "the same incident cannot be recalled twice")
	game.queue_free()
	await process_frame
	print("Deadlock integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
