extends SceneTree
const Journeys = preload("res://scripts/core/passenger_journeys.gd")
const Demand = preload("res://scripts/core/passenger_demand.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var config := {"ab": {"stops": ["a", "b"]}, "bc": {"stops": ["b", "c"]}}
	var network := Journeys.graph(config)
	check(Journeys.plan(network, "a", "c") == ["a", "b", "c"], "two services create a connection at B")
	check(Journeys.plan(network, "c", "a") == ["c", "b", "a"], "Shuttle return direction is reachable")
	check(Journeys.boarding(network, "a", ["b"]) == ["b", "c"], "A-B accepts C-bound transfers")
	check(Journeys.boarding(network, "b", ["a"]) == ["a"], "wrong-way travel cannot manufacture a useful connection")
	config.ac = {"stops": ["a", "c"]}
	check(Journeys.boarding(Journeys.graph(config), "a", ["b"]) == ["b"], "direct service wins over an extra change")
	check(Journeys.plan(Journeys.graph({"ab": config.ab}), "a", "c").is_empty(), "unserved destinations are unreachable")
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	game.money = 100000
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	var purchase: Dictionary = game.buy_fleet_train("passenger_standard")
	check(game.start_passenger_service(int(purchase.id), "c").begins_with("Passenger"), "second train starts at C")
	var key: String = game.Fleet.find(game.fleet, int(purchase.id)).service
	var routes: Dictionary = game.services.duplicate(true)
	routes[key].stops = ["c", "b"]
	check(game.apply_service_routes(routes).begins_with("Routes applied"), "second service connects C-B")
	for station in Demand.STATIONS: game.passenger_demand.queues[station] = {}
	game.passenger_demand.queues.a = {"c": 5}
	check(game._destination_queue_text("a").contains("change at Station B"), "station explains transfer connection")
	game._board_passengers()
	check(game.passenger_destinations == {"c": 5} and game.waiting_at_a == 0, "primary train boards final destinations outside its own route")
	game.inspect_train(1)
	check(game.train_inspector.summary.text.contains("change trains"), "train inspector identifies off-route final destinations")
	game.train_inspector.hide()
	var money: int = game.money
	game._save_game(4)
	var position: Vector2 = game.train_position
	game.passenger_destinations.clear()
	check(game._load_slot(4) and game.passenger_destinations == {"c": 5} and game.train_position == position, "transfer manifest loads without moving the train")
	game.train_needs_boarding = false
	for step in range(650):
		game._rebuild_reservations(true)
		game._move_train(1.0 / 60.0)
		if game.passenger_stop_index == 1: break
	check(game.passenger_stop_index == 1 and game.waiting_at_b == 5 and game.passengers_on_train == 0, "physical arrival queues transfer riders at B")
	check(game.passengers_delivered == 0 and game.money == money, "changing trains awards no fare or delivered passengers")
	# First train physically clears the shared platform before C-B arrives.
	for step in range(900):
		game._rebuild_reservations(true)
		game._move_train(1.0 / 60.0)
		if game.passenger_stop_index == 0: break
	game.passenger_held = true
	var running = game.passenger_services[key]
	for step in range(650):
		game._rebuild_reservations(true)
		running.advance(game, 1.0 / 60.0)
		if running.stop_index == 1: break
	check(running.stop_index == 1, "connecting train physically reaches B")
	for step in range(900):
		game._rebuild_reservations(true)
		running.advance(game, 1.0 / 60.0)
		if running.stop_index == 0: break
	check(game.passengers_delivered == 5 and game.waiting_at_b == 0 and running.passengers == 0, "connecting train delivers C-bound riders once")
	check(game.passengers_delivered + game.waiting_at_a + game.waiting_at_b + game.waiting_at_c + game.passengers_on_train + running.passengers == 5, "transfers conserve passengers")
	# Additional train accepts A-bound riders, then retains them if connection is withdrawn.
	game.passenger_held = false
	game.passenger_demand.queues.c = {"a": 6}
	running.boarding = true
	running.dwell = 0
	running.advance(game, 1.0 / 60.0)
	check(running.passenger_destinations == {"a": 6}, "additional train boards off-route final destination")
	game._save_game(4)
	check(game._load_slot(4) and game.passenger_services[key].passenger_destinations == {"a": 6}, "additional transfer manifest persists")
	running = game.passenger_services[key]
	game.passenger_service_enabled = false
	check(game._destination_queue_text("c").contains("no enabled connection"), "withdrawn connection disappears from journey plan")
	for step in range(650):
		game._rebuild_reservations(true)
		running.advance(game, 1.0 / 60.0)
		if running.stop_index == 1: break
	check(game.waiting_at_b == 6 and running.passengers == 0 and game.passengers_delivered == 5, "withdrawn onward service leaves accepted riders safely queued")
	var manifest := {"c": 8}
	game.passenger_demand.queues.b = {"c": 100}
	check(game.passenger_demand.interchange("b", ["a", "b"], manifest) == 8 and game.waiting_at_b == 108, "full waiting area never discards transferred riders")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(4)))
	var migrated: Dictionary = game.SaveMigrations.migrate(dict_version(saved, 28))
	check(migrated.ok and migrated.data.version == game.SaveMigrations.CURRENT_VERSION and migrated.data.demand.queues == saved.demand.queues and migrated.data.demand.primary == saved.demand.primary, "v28 migration preserves demand and positions")
	game.queue_free()
	await process_frame
	var baseline: Dictionary = await frame_case(30)
	check(baseline.delivered == 5 and baseline.stage == 4, "frame-rate fixture completes a real connecting journey")
	for fps in [60, 120]:
		check(await frame_case(fps) == baseline, "transfer queues/manifests/income/events match at %d FPS" % fps)
	print("Passenger transfers: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func dict_version(saved: Dictionary, version: int) -> Dictionary:
	var result := saved.duplicate(true)
	result.version = version
	return result

func frame_case(fps: int) -> Dictionary:
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	game.money = 100000
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	var purchase: Dictionary = game.buy_fleet_train("passenger_standard")
	game.start_passenger_service(int(purchase.id), "c")
	var key: String = game.Fleet.find(game.fleet, int(purchase.id)).service
	var routes: Dictionary = game.services.duplicate(true)
	routes[key].stops = ["c", "b"]
	game.apply_service_routes(routes)
	for station in Demand.STATIONS: game.passenger_demand.queues[station] = {}
	game.passenger_demand.queues.a = {"c": 5}
	game.sim_clock.reset()
	game.sim_clock.speed = 1
	game.event_log = game.EventLog.new()
	game.notifications.reset()
	var stage := 0
	for frame in range(fps * 50):
		for step in range(game.sim_clock.advance(1.0 / fps)):
			game.sim_clock.begin_tick()
			game._rebuild_reservations(true)
			# Ordered physical dispatch clears B before the opposing service enters.
			if stage < 2:
				game._move_train(1.0 / 60.0)
				if stage == 0 and game.passenger_stop_index == 1: stage = 1
				elif stage == 1 and game.passenger_stop_index == 0:
					stage = 2
					game.passenger_held = true
			elif stage < 4:
				game.passenger_services[key].advance(game, 1.0 / 60.0)
				if stage == 2 and game.passenger_services[key].stop_index == 1: stage = 3
				elif stage == 3 and game.passenger_services[key].stop_index == 0: stage = 4
	var result: Dictionary = {"stage": stage, "tick": game.sim_clock.tick, "delivered": game.passengers_delivered, "cash": game.money, "queues": game.passenger_demand.queues.duplicate(true), "primary": game.passenger_destinations.duplicate(true), "other": game.passenger_services[key].passenger_destinations.duplicate(true), "events": game.event_log.save_state()}
	game.queue_free()
	await process_frame
	return result
