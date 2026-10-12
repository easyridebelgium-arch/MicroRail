extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	# Use a desktop window size; headless defaults to 64x64.
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.paused = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.money = 5000
	for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	var before: int = game.money
	check(game.edit_consist(1, "coach").contains("straight") and game.money == before, "missing platform clearance must refuse purchase without spending")
	game.tracks[Vector2i(3, 8)] = false
	game.tracks[Vector2i(21, 8)] = false
	check(game.edit_consist(1, "coach").begins_with("Attached") and game.money == before - 180, "coach must attach to an empty train with suitable stop clearance")
	check(game._get_train_capacity() == 38 and game.reservation_trains[1].length == 60, "passenger boarding capacity and reservation descriptor must both use composition")
	check(game.reservations.occupied_owners.get(Vector2i(3, 8)) == 1, "train at its first station must protect the part behind the path origin")
	game.tracks.erase(Vector2i(21, 8))
	game._refresh_directional_routes()
	check(not game.route_connected and game.train_position == game._cell_center(game.STATION_A), "removing destination clearance must stop a long train without relocating it")
	game.tracks[Vector2i(21, 8)] = false
	game._refresh_directional_routes()
	check(game.route_connected, "restoring clearance must let the consist resume")
	check(game.upgrade_fleet_train(1, "speed").contains("bought") and game._get_train_speed() == 100, "speed upgrade may reach but must respect coach speed limit")
	before = game.money
	check(game.upgrade_fleet_train(1, "speed").contains("limits speed") and game.money == before, "an ineffective speed upgrade must not charge the player")
	game._set_waiting("a", 40)
	var finished := false
	var start_position: Vector2 = game.train_position
	var moved := false
	for tick in range(1200):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
		moved = moved or game.train_position != start_position
		if game.passengers_delivered >= 38 and game._can_replace_service_train("passenger"):
			finished = true
			break
	check(moved and finished, "an attached coach must actually deliver its larger load and physically shuttle back home")
	game.passengers_on_train = 1
	before = game.money
	check(game.edit_consist(1, "coach", true).contains("empty") and game.money == before, "loaded trains must not shrink or receive a refund")
	game.passengers_on_train = 0
	check(game.edit_consist(1, "coach", true).begins_with("Removed") and game.money == before + 90 and game.reservation_trains[1].length == 28, "removal must refund half price and rebuild the smaller body")
	game.edit_consist(1, "coach")
	var config: Dictionary = game.services.duplicate(true)
	config.passenger.mode = "loop"
	check(game.apply_service_routes(config).contains("Shuttle"), "long consists must not enter unsupported Loop wrapping")
	game.fleet.trains.append(game.Fleet.make_train(3, "passenger_standard"))
	game.fleet.next_id = 4
	check(game.edit_consist(3, "coach").begins_with("Attached"), "stored trains must accept compatible stock")
	check(game.start_passenger_service(3, "a").contains("occupied"), "starting consist must reject another train's body")
	check(game.start_passenger_service(3, "b").contains("started"), "a stored consist may start a separate service at a clear suitable station")
	for x in range(7, 30): game.tracks[Vector2i(x, 24)] = false
	game._check_route()
	check(game.edit_consist(2, "log_wagon").begins_with("Attached") and game.freight_train.get_capacity() == 50 and game.freight_train.running_cost_per_second == 2, "log wagon must affect freight capacity and expenses")
	var draws: Array = [0]
	game.freight_train.draw.connect(func() -> void: draws[0] += 1)
	game.freight_train._update_transform()
	await process_frame
	await process_frame
	check(draws[0] > 0, "freight movement must redraw its wagon poses, not leave the old single-locomotive drawing cached")
	game.freight_train.cargo = 45
	game._save_game()
	game.fleet.trains[0].wagons.clear()
	game._load_game()
	check(game.Fleet.length(game.Fleet.find(game.fleet, 1)) == 60 and game.freight_train.cargo == 45 and game.freight_train.get_capacity() == 50, "save/load must restore composition and accept cargo above the locomotive-only capacity")
	game.fleet_editor.open_editor()
	game.fleet_editor.selected_id = 1
	game.fleet_editor.refresh()
	check(game.fleet_editor.details.text.contains("Length 60") and game.fleet_editor.wagon_choice.item_count == 1, "Fleet UI must show body length and compatible stock")
	var Settings = game.GameSettings
	Settings.ui_scale = 2.0
	game._apply_settings()
	game.fleet_editor.open_editor()
	await process_frame
	await process_frame
	check(float(game.fleet_editor.size.y) <= game.get_viewport_rect().size.y + 1.0, "Fleet consist controls must remain scrollable at 200% UI scale")
	game.fleet_editor.hide()
	Settings.ui_scale = 1.0
	game._apply_settings()
	# Force a corrupt long-body overlap while keeping centre-sized footprints separate.
	var extra = game.passenger_services["passenger_3"]
	extra.distance = 64.0
	extra.boarding = false
	extra.update_transform()
	game.route_distance = 480.0
	game.train_needs_boarding = false
	game.wait_remaining = 0.0
	game._update_train_transform()
	game._save_game()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	check(game._is_valid_save(saved), "overlap fixture must pass ordinary save validation so the full-body guard is exercised")
	var sentinel: int = game.money + 17
	game.money = sentinel
	game._load_game()
	check(game.money == sentinel, "load must reject overlapping full bodies before mutating the running game")
	game.queue_free()
	await process_frame
	print("Consist integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
