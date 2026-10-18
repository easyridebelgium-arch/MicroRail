extends SceneTree
const Metrics = preload("res://scripts/core/passenger_occupancy.gd")
const Clock = preload("res://scripts/core/sim_clock.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var metrics := Metrics.new()
	check(metrics.describe().contains("no service samples"), "unknown history is explicit")
	metrics.sample(1, [{"id": 1, "passengers": 10, "capacity": 20}])
	metrics.sample(2, [{"id": 1, "passengers": 20, "capacity": 40}])
	var stats := metrics.statistics(1)
	check(stats.passenger_ticks == 30 and stats.seat_ticks == 60, "capacity changes use seat-time weighting")
	metrics.sample(2, [{"id": 1, "passengers": 40, "capacity": 40}])
	check(metrics.statistics(1) == stats, "duplicate ticks cannot inflate measurements")
	metrics.sample(3, [{"id": 2, "passengers": 5, "capacity": 5}])
	check(metrics.statistics(2).full_ticks == 1 and metrics.statistics(1).full_ticks == 0, "full-time and vehicle IDs remain separate")
	metrics.sample(120 * 60, [])
	check(metrics.statistics().ticks == 0 and metrics.buckets.is_empty(), "history expires even when no trains run")
	metrics.boarding(1, 1, "a", 0, 7, 19, 20)
	check(metrics.statistics(1).left == 0, "free seats do not count as capacity denial")
	for i in range(140): metrics.boarding(i, 2, "b", 0, 3, 20, 20)
	check(metrics.boardings.size() == 128 and metrics.statistics(2).left == 384, "boarding history is bounded and counts repeated opportunities honestly")
	check(replay(30) == replay(60) and replay(60) == replay(120), "fixed-tick occupancy identical at 30/60/120 FPS")
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	for station in game.PassengerDemand.STATIONS: game.passenger_demand.reset_total(station, 0)
	var train: Dictionary = game.Fleet.assigned(game.fleet, "passenger")
	var capacity: int = game.Fleet.capacity(train)
	game.passenger_demand.queues.a = {"b": capacity + 3, "c": 9}
	game.passenger_destinations.clear()
	var cash: int = game.money
	var position: Vector2 = game.train_position
	check(game._board_waiting("a", ["b"], capacity, game.passenger_destinations) == capacity, "actual game boarding fills seats")
	check(game.passenger_occupancy.statistics(train.id).left == 3, "ineligible destination excluded from left-behind count")
	check(game.passenger_demand.queues.a.c == 9 and game.money == cash and game.train_position == position, "measurement never discards riders, charges or moves trains")
	game.passenger_held = true
	game.sim_clock.tick += 1
	game._sample_passenger_occupancy()
	check(game.passenger_occupancy.statistics(train.id).full_ticks == 1, "enabled dispatcher hold contributes actual full service time")
	train.capacity_level = 1
	game.capacity_upgrade_level = 1
	game.sim_clock.tick += 1
	game._sample_passenger_occupancy()
	check(game.passenger_occupancy.statistics(train.id).seat_ticks == capacity + 30, "actual upgrade changes available seat-time")
	train.capacity_level = 0
	game.capacity_upgrade_level = 0
	var extra: Dictionary = game.Fleet.make_train(3, "passenger_fast")
	game.fleet.trains.append(extra)
	game.fleet.next_id = 4
	game.start_passenger_service(3, "c")
	var key := "passenger_3"
	check(game.passenger_services.has(key), "second passenger service fixture starts")
	game.passenger_services[key].passenger_destinations = {"b": 6}
	game.sim_clock.tick += 1
	game._sample_passenger_occupancy()
	check(game.passenger_occupancy.statistics(3).passenger_ticks == 6 and game.passenger_occupancy.statistics(3).seat_ticks == 12, "multiple services sample their own vehicle and capacity")
	game.passenger_services[key].enabled = false
	game.passenger_services[key].passenger_destinations.clear()
	game.sim_clock.tick += 1
	game._sample_passenger_occupancy()
	check(game.passenger_occupancy.statistics(3).ticks == 1, "stored second vehicle excluded")
	var prior_ticks: int = game.passenger_occupancy.statistics(train.id).ticks
	game.passenger_service_enabled = false
	game.passenger_destinations.clear()
	game.route_distance = 0
	game.travelling_to_b = true
	game.sim_clock.tick += 1
	game._sample_passenger_occupancy()
	check(game.passenger_occupancy.statistics(train.id).ticks == prior_ticks, "withdrawn empty parked train excluded")
	game.passenger_service_enabled = true
	game.passenger_held = false
	game.train_inspector.open_train(train.id)
	check(game.train_inspector.summary.text.contains("Seats occupied: 0 / %d" % capacity), "inspector shows live manifest rather than previous sample")
	game.train_inspector.hide()
	game.header_controls.open_accounts()
	check(game.header_controls.accounts_text.text.contains("Station A: 3 left-behind"), "Accounts gives station capacity evidence")
	game.header_controls.accounts_dialog.hide()
	check(game._save_game(4), "existing save schema accepts observations without added fields")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(4)))
	payload.version = 999
	check(not game._is_valid_save(payload) and game.passenger_occupancy.statistics(train.id).left == 3, "rejected save cannot clear live measurements")
	check(game._load_slot(4) and game.passenger_occupancy.statistics().ticks == 0 and game.passenger_occupancy.boardings.is_empty(), "successful load resets derived history")
	game.queue_free()
	await process_frame
	print("Passenger occupancy: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func replay(fps: int) -> Dictionary:
	var clock := Clock.new()
	var metrics := Metrics.new()
	for frame in range(fps * 4):
		for step in clock.advance(1.0 / fps):
			clock.begin_tick()
			metrics.sample(clock.tick, [{"id": 1, "passengers": 20 if clock.tick >= 120 else 5, "capacity": 20}])
	return metrics.statistics()
