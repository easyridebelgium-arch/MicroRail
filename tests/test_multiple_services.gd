extends SceneTree
const Services = preload("res://scripts/service_routes.gd")
const Fleet = preload("res://scripts/fleet.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: _run.call_deferred()
func fixture(game: Node) -> void:
	for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
	game.tracks[Vector2i(8, 8)] = "junction_6_2_4"
	game.tracks[Vector2i(16, 8)] = "junction_2_6_4"
	for y in [9, 10]:
		game.tracks[Vector2i(8, y)] = true
		game.tracks[Vector2i(16, y)] = true
	game.tracks[Vector2i(8, 11)] = Geometry.from_ports(Vector2i.UP, Vector2i.RIGHT)
	game.tracks[Vector2i(16, 11)] = Geometry.from_ports(Vector2i.UP, Vector2i.LEFT)
	for x in range(9, 16): game.tracks[Vector2i(x, 11)] = false
	# Bound each station approach together with its switch. Signals sit inside
	# each loop branch, so arrivals wait outside an occupied station approach.
	for cell in [Vector2i(9, 8), Vector2i(15, 8), Vector2i(8, 10), Vector2i(16, 10)]: game.track_signals[cell] = "auto"
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	game.money = 10000
	game._check_route()
func tick(game: Node) -> void:
	game.sim_clock.begin_tick()
	game._simulation_step(1.0 / 60.0)
func no_overlap(game: Node) -> bool:
	var seen: Dictionary = {}
	var trains: Array = [{"path": game.route_path, "distance": game.route_distance}]
	for key in game.additional_service_keys(): trains.append({"path": game.passenger_services[key].path, "distance": game.passenger_services[key].distance})
	for train in trains:
		for cell in game.reservations.footprint(train.path, train.distance, 32):
			if seen.has(cell): return false
			seen[cell] = true
	return true
func write_save(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()
func _run() -> void:
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.paused = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	fixture(game)
	game._open_fleet_editor()
	await process_frame
	var editor = game.fleet_editor
	editor.buy_button.pressed.emit()
	var id: int = editor.selected_id
	check(id == 3 and Fleet.find(game.fleet, id).service == "", "Bought second passenger train is initially stored")
	var money: int = game.money
	editor.start_button.pressed.emit()
	check(game.passenger_services.is_empty() and Fleet.find(game.fleet, id).service == "" and game.money == money and editor.status.text.contains("occupied"), "Cannot spawn on occupied A or charge for rejected creation")
	editor.start_station.select(1)
	editor.start_button.pressed.emit()
	var key: String = Fleet.find(game.fleet, id).service
	check(key != "" and game.passenger_services.size() == 1 and Fleet.is_valid(game.fleet), "Fleet starts a second independently assigned passenger service at B")
	check(game.passenger_services[key].position == game._cell_center(game.STATION_B) and no_overlap(game), "New service starts on its clear physical platform")
	editor.hide()
	game._open_routes_editor()
	await process_frame
	var routes = game.route_editor
	check(routes.service_choice.item_count == 3, "Routes lists both passenger services and freight")
	routes.service_choice.item_selected.emit(2)
	routes.name_field.text = "Loop Bypass"
	routes.waypoint_x.value = 12
	routes.waypoint_y.value = 11
	routes.waypoint_add.pressed.emit()
	routes.confirmed.emit()
	check(game.services[key].name == "Loop Bypass" and game.services[key].waypoints["b>a"] == [[12, 11]] and game.services.passenger.waypoints.is_empty(), "Editor independently names and directs second service")
	check(game.passenger_services[key].cells.has(Vector2i(12, 11)) and not game.route_cells.has(Vector2i(12, 11)), "Opposing services choose different tracks through passing loop")
	routes.hide()
	var clear_every_tick := true
	var both_moved := false
	var bypass_used := false
	for step in range(1800):
		tick(game)
		clear_every_tick = clear_every_tick and no_overlap(game)
		both_moved = both_moved or (game.route_distance > 100 and game.passenger_services[key].distance > 100)
		bypass_used = bypass_used or game.passenger_services[key].position.y > 330
	check(clear_every_tick and both_moved and bypass_used, "Opposite-bound trains move through switches and passing loop without any footprint overlap")
	check(game.passengers_delivered > 16 and game.deadlocks.cycles.is_empty(), "Both trains deliver over repeated trips without a deadlock in the passing layout")
	var generated := roundi((30 - game.passenger_timer) / game.PASSENGER_INTERVAL)
	var conserved: int = game.passengers_delivered + game.waiting_at_a + game.waiting_at_b + game.waiting_at_c + game.passengers_on_train + game.passenger_services[key].passengers
	check(conserved == 24 + generated * 9, "Shared station queues never duplicate or discard passengers")
	check(game.money == money + game.passengers_delivered * game.TICKET_PRICE - game.total_operating_cost, "Both services account for fares and model running costs exactly")
	var primary_position: Vector2 = game.train_position
	var second_position: Vector2 = game.passenger_services[key].position
	var configuration: Dictionary = game.services.duplicate(true)
	configuration[key].mode = "loop"
	check(game.apply_service_routes(configuration).contains("first stop") and game.train_position == primary_position and game.passenger_services[key].position == second_position, "Mid-trip edit of second service cannot relocate either train")
	game._save_game()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	var runtime: Dictionary = game.passenger_services[key].save_state()
	tick(game)
	game._load_game()
	check(game.passenger_services[key].save_state() == runtime and game.train_position == primary_position and game.passenger_services[key].position == second_position, "Save/load restores every route and exact train state")
	game.selected_station = game.STATION_B
	game.station_panel.show()
	game._update_station_inspector()
	check(game.station_details.text.contains("Loop Bypass") and game.station_details.text.contains("Passenger Shuttle"), "Station inspector includes all serving routes")
	game._close_station_inspector()
	check(game.reservation_trains.size() == 3 and no_overlap(game), "Reservations include all loaded active trains")
	var overlap: Dictionary = saved.duplicate(true)
	overlap.services[key] = overlap.services.passenger.duplicate(true)
	overlap.passenger_services[key].cells = overlap.runtime.passenger_cells.duplicate(true)
	overlap.passenger_services[key].distance = overlap.route_distance
	overlap.passenger_services[key].stop_index = overlap.state.passenger_stop_index
	overlap.passenger_services[key].forward = overlap.state.travelling_to_b
	overlap.passenger_services[key].dwell = overlap.state.wait_remaining
	overlap.passenger_services[key].boarding = overlap.state.train_needs_boarding
	write_save("user://overlap_multi.json", overlap)
	game._load_game("user://overlap_multi.json")
	check(game.passenger_services[key].save_state() == runtime and game.notice.contains("overlapping"), "Overlapping loaded trains are rejected before any live state changes")
	var malformed: Dictionary = saved.duplicate(true)
	malformed.passenger_services.erase(key)
	check(not game._is_valid_save(malformed), "Missing service runtime rejected")
	malformed = saved.duplicate(true)
	Fleet.assigned(malformed.fleet, key).service = ""
	check(not game._is_valid_save(malformed), "Orphan route assignment rejected")
	malformed = saved.duplicate(true)
	malformed.passenger_services[key].passengers = 1000
	check(not game._is_valid_save(malformed), "Over-capacity second train rejected")
	malformed = saved.duplicate(true)
	malformed.passenger_services[key].distance = -1
	write_save("user://invalid_multi.json", malformed)
	game._load_game("user://invalid_multi.json")
	check(game.passenger_services[key].save_state() == runtime and game.train_position == primary_position, "Invalid additional runtime leaves the whole live game unchanged")
	game._open_traffic_dialog()
	check(game.traffic_dialog.train_choice.item_count == 3, "Traffic includes second passenger train")
	check(game.set_dispatch_hold(id, true).contains("held") and game.passenger_services[key].held, "Traffic holds selected additional train")
	second_position = game.passenger_services[key].position
	for step in range(60): tick(game)
	check(game.passenger_services[key].position == second_position, "Held additional train stays physically in place")
	game.set_dispatch_hold(id, false)
	game.traffic_dialog.hide()
	# Reversal action uses a confirmed-cycle fixture; monitor detection is covered
	# separately by test_deadlock_integration.gd.
	game.deadlocks.cycles = [[1, id]]
	second_position = game.passenger_services[key].position
	check(game.reverse_deadlocked_train(id).contains("reversed in place") and game.passenger_services[key].position == second_position and game.passenger_services[key].returning, "Additional train reverses physically without route reset")
	game._save_game()
	game._load_game()
	check(game.passenger_services[key].returning and game.passenger_services[key].position == second_position, "Additional recovery state persists")
	# Resume its normal direction in the fixture to continue testing withdrawal.
	var running = game.passenger_services[key]
	running.returning = false
	running.forward = not running.forward
	running.update_transform()
	game.toggle_fleet_service(id)
	check(not running.enabled, "Fleet withdraws only the selected additional service")
	check(game.remove_passenger_service(id).contains("Withdraw"), "Moving service cannot disappear into storage")
	for step in range(3600):
		if running.at_home(): break
		tick(game)
	check(running.at_home() and not running.active() and running.passengers == 0, "Additional withdrawal delivers riders and returns empty to its first stop")
	game._save_game()
	game._load_game()
	check(game.passenger_services[key].at_home() and not game.passenger_services[key].enabled, "Withdrawn additional service reloads parked")
	var before_upgrades: int = game.money
	game.upgrade_fleet_train(id, "speed")
	game.upgrade_fleet_train(id, "capacity")
	check(Fleet.speed(Fleet.find(game.fleet, id)) == 100 and Fleet.capacity(Fleet.find(game.fleet, id)) == 30 and game.money == before_upgrades - 450, "Additional train has independently purchased speed and capacity upgrades")
	# Replacement keeps the route identity and stores the upgraded old vehicle.
	var replacement: Dictionary = game.buy_fleet_train("passenger_fast")
	var old_id := id
	id = int(replacement.id)
	check(game.assign_fleet_train(id, key).contains("assigned") and Fleet.find(game.fleet, old_id).service == "" and Fleet.assigned(game.fleet, key).id == id, "Additional service can replace its returned vehicle while retaining route identity")
	check(Fleet.find(game.fleet, old_id).speed_level == 1 and Fleet.find(game.fleet, old_id).capacity_level == 1 and Fleet.capacity(Fleet.find(game.fleet, id)) == 12, "Replacement preserves each train's own upgrades")
	# Starting the old vehicle must not overwrite the still-existing route key.
	check(game.start_passenger_service(old_id, "c").contains("started") and game.passenger_services.size() == 2 and game.reservation_trains.size() == 4, "Third active train gets a distinct route without overwriting replacement service")
	var third_key: String = Fleet.find(game.fleet, old_id).service
	check(third_key != key and no_overlap(game), "Independent third service begins on a clear C platform")
	game._save_game()
	game._load_game()
	check(game.passenger_services.size() == 2 and Fleet.assigned(game.fleet, key).id == id and no_overlap(game), "Three active trains and independent assignments survive load")
	game.toggle_fleet_service(old_id)
	game.remove_passenger_service(old_id)
	game.toggle_fleet_service(id)
	# Add C and Loop mode to the second service while physically at B.
	configuration = game.services.duplicate(true)
	configuration[key].stops = ["b", "a", "c"]
	configuration[key].mode = "loop"
	check(game.apply_service_routes(configuration).contains("applied") and game.passenger_services[key].distances.size() == 4, "Additional route supports three-stop Loop with closing leg")
	game._save_game()
	game._load_game()
	check(game.services[key].mode == "loop" and game.passenger_services[key].at_home(), "Additional Loop mode survives load at its starting station")
	var old_scale: float = Settings.ui_scale
	Settings.ui_scale = 2
	game._apply_settings()
	game._open_fleet_editor()
	await process_frame
	await process_frame
	check(editor.size.x <= root.get_visible_rect().size.x and editor.size.y <= root.get_visible_rect().size.y and editor.get_ok_button().get_global_rect().end.y <= editor.size.y, "Expanded Fleet fits at 200% scale with accessible Close")
	editor.hide()
	game._open_routes_editor()
	await process_frame
	check(routes.service_choice.item_count == 3 and routes.size.x <= root.get_visible_rect().size.x and routes.size.y <= root.get_visible_rect().size.y, "Multi-service Routes fits at 200% scale")
	routes.hide()
	Settings.ui_scale = old_scale
	game._apply_settings()
	check(game.remove_passenger_service(id).contains("stored") and Fleet.find(game.fleet, id).service == "" and not game.services.has(key), "Withdrawn extra service can be removed and train stored safely")
	check(game.reservation_trains.size() == 2 and Fleet.is_valid(game.fleet), "Removal releases reservations and retains valid original services")
	game._save_game()
	game._load_game()
	check(game.passenger_services.is_empty() and game.service_keys().size() == 2, "Removed service stays removed on reload")
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	legacy.version = 21
	legacy.erase("passenger_services")
	write_save("user://legacy_v21.json", legacy)
	primary_position = game.train_position
	game._load_game("user://legacy_v21.json")
	check(game.passenger_services.is_empty() and game.train_position == primary_position, "v21 migration preserves original journey and adds no extra trains")
	game.passenger_service_enabled = false
	for step in range(1800):
		if game.route_distance <= 0.001 and game.passenger_stop_index == 0: break
		tick(game)
	check(not game._passenger_service_is_active(), "Original service can withdraw after additional service removal")
	game.start_passenger_service(old_id, "c")
	key = Fleet.find(game.fleet, old_id).service
	configuration = game.services.duplicate(true)
	configuration[key].stops = ["c", "b"]
	configuration[key].mode = "loop"
	game.apply_service_routes(configuration)
	running = game.passenger_services[key]
	for step in range(80): tick(game)
	var retained: Vector2 = running.position
	game.tracks.erase(Vector2i(34, 8))
	game._check_route()
	check(running.connected and running.position == retained, "Gap behind an additional train permits its current delivery without relocation")
	for step in range(800):
		if running.stop_index == 1: break
		tick(game)
	check(running.stop_index == 1 and not running.connected and running.position == game._cell_center(game.STATION_B), "Additional Loop checks the broken closing leg only after arriving at B")
	game._save_game()
	game._load_game()
	running = game.passenger_services[key]
	check(not running.connected and running.stop_index == 1, "Stopped additional Loop loads at the same intermediate station")
	game.tracks[Vector2i(34, 8)] = false
	game._check_route()
	var visits: Array[int] = []
	var previous: int = running.stop_index
	var maximum_step := 0.0
	for step in range(2000):
		retained = running.position
		tick(game)
		maximum_step = maxf(maximum_step, retained.distance_to(running.position))
		if running.stop_index != previous:
			previous = running.stop_index
			visits.append(previous)
		if visits.size() == 4: break
	check(visits == [0, 1, 0, 1] and maximum_step < 2, "Additional train repeats Loop laps with no physical jump")
	for step in range(180):
		if running.distance > running.distances[1] + 50: break
		tick(game)
	game._save_game()
	retained = running.position
	game._load_game()
	running = game.passenger_services[key]
	check(running.stop_index == 1 and running.position == retained and running.next_stop() == 0, "Additional closing-leg save restores its destination and position")
	game.deadlocks.cycles = [[1, old_id]]
	game.reverse_deadlocked_train(old_id)
	game._save_game()
	game._load_game()
	running = game.passenger_services[key]
	check(running.returning and running.next_stop() == 1 and running.position == retained, "Additional closing-leg reversal restores toward departure B")
	for step in range(200):
		if running.held: break
		tick(game)
	check(running.held and running.position == game._cell_center(game.STATION_B), "Additional Loop recovery physically returns to departure B")
	game.queue_free()
	await process_frame
	# Same initial shared-track services produce identical simulation at each FPS.
	var reference: Array = []
	for fps in [30, 60, 120]:
		game = load("res://scenes/main/main.tscn").instantiate()
		game.paused = true
		root.add_child(game)
		await process_frame
		game.set_process(false)
		fixture(game)
		var purchase: Dictionary = game.buy_fleet_train("passenger_standard")
		game.start_passenger_service(int(purchase.id), "b")
		key = Fleet.find(game.fleet, int(purchase.id)).service
		configuration = game.services.duplicate(true)
		configuration[key].waypoints = {"b>a": [[12, 11]]}
		game.apply_service_routes(configuration)
		game.sim_clock.reset()
		game.event_log.clear()
		game.sim_clock.speed = 5
		game.paused = false
		for frame in range(fps * 4): game._process(1.0 / fps)
		var snapshot: Array = [game.sim_clock.tick, game.route_distance, game.passenger_stop_index, game.passengers_on_train, game.passenger_services[key].save_state(), game.money, game.waiting_at_a, game.waiting_at_b, game.waiting_at_c, game.event_log.save_state(), game.reservations.owners.duplicate()]
		check(game.sim_clock.tick == 1200 and no_overlap(game), "Two services advance 20 simulated seconds safely at 5×")
		if reference.is_empty(): reference = snapshot
		check(snapshot == reference, "Shared-track multi-service results match at %d FPS" % fps)
		game.queue_free()
		await process_frame
	print("Multiple services: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
