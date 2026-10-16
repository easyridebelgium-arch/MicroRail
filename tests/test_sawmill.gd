extends SceneTree
const Mill = preload("res://scripts/core/sawmill.gd")
const Migrations = preload("res://scripts/core/save_migrations.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func fixture() -> Node:
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.paused = true
	game.money = 10000
	for x in range(8, 29): game.tracks[Vector2i(x, 24)] = false
	game._check_route()
	return game
func tick(game: Node) -> void:
	game.sim_clock.begin_tick()
	game._simulation_step(1.0 / 60.0)
func run() -> void:
	check(Mill.LOGS.cargo_id == "logs" and Mill.TIMBER.cargo_id == "timber" and Mill.DEFINITION.schema_version == 1, "versioned resources define cargo and recipe")
	var mill := Mill.new()
	mill.state.installed = true
	check(mill.accept(5) == 5, "logs enter real input stock")
	for i in range(299): mill.tick()
	check(mill.state.timber == 0 and mill.state.progress == 299, "no processing shortcut before full tick budget")
	var copy := Mill.new()
	copy.restore_state(JSON.parse_string(JSON.stringify(mill.save_state())))
	mill.tick()
	copy.tick()
	check(mill.save_state() == copy.save_state() and mill.state.logs == 3 and mill.state.timber == 1, "mid-process JSON resumes exactly")
	check(mill.take(20) == 1 and mill.state.loaded == 1 and Mill.valid(mill.save_state()), "loading conserves output without inventing stock")
	var full := Mill.new()
	full.state.installed = true
	full.state.timber = 200
	full.state.produced = 200
	full.state.consumed = 400
	full.state.received = 402
	full.state.logs = 2
	for i in range(600): full.tick()
	check(full.state.logs == 2 and full.state.progress == 0 and Mill.valid(full.save_state()), "full output storage stalls without destroying input")
	check(full.accept(1000) == 198 and full.state.logs == 200, "input capacity accepts only room")
	var bad: Dictionary = full.save_state()
	bad.produced += 1
	check(not Mill.valid(bad), "recipe accounting corruption rejected")
	root.size = Vector2i(1280, 720)
	var game := fixture()
	var position: Vector2 = game.freight_train.position
	check(game.build_sawmill().contains("installed") and game.money == 9500 and game.freight_train.position == position, "purchase installs physically on route without teleport")
	check(game.build_sawmill().contains("already") and game.money == 9500, "repeat purchase cannot charge twice")
	game.forest_stock = 20
	game.logs_produced = 20
	for i in range(600):
		tick(game)
		if game.sawmill.state.received > 0: break
	check(game.sawmill.state.received == 20 and game.freight_train.distance_along_route == game.freight_train.sawmill_distance and game.logs_delivered == 0 and game.freight_income == 0, "actual train unloads logs at sawmill with no sale")
	check(game._save_game(4), "sawmill stage saves")
	position = game.freight_train.position
	var loaded: bool = game._load_slot(4)
	check(loaded and game.freight_train.position == position and game.sawmill.state.logs == 20, "load retains industrial input and train position")
	for i in range(600):
		tick(game)
		if game.freight_train.cargo_kind() == "timber" and game.freight_train.cargo > 0 and game.freight_train.distance_along_route > game.freight_train.sawmill_distance + 10: break
	check(game.freight_train.cargo == 1 and game.sawmill.state.loaded == 1, "real processed timber loads and departs")
	position = game.freight_train.position
	check(game.reverse_train(2).contains("reversed in place") and game.freight_train.position == position and game.freight_train.recovery_stop == "sawmill", "recovery reverses in place to sawmill rather than forest")
	check(game._save_game(4) and game._load_slot(4) and game.freight_train.position == position, "mid-recovery timber and geometry survive load")
	for i in range(100):
		tick(game)
		if not game.freight_train.recovery_returning: break
	check(game.freight_train.held and game.freight_train.cargo == 1 and game.freight_train.distance_along_route == game.freight_train.sawmill_distance and game.freight_income == 0, "recovery keeps timber aboard and earns nothing")
	game.freight_train.held = false
	game.freight_train.service_enabled = true
	for i in range(800):
		tick(game)
		if game.sawmill.state.sold > 0: break
	check(game.sawmill.state.sold > 0 and game.freight_income == game.sawmill.state.sold * 24 and game.logs_delivered == 0, "only physical terminal delivery pays timber price")
	check(game.sawmill.state.loaded == game.sawmill.state.sold + game.freight_train.cargo and game.sawmill.state.produced == game.sawmill.state.timber + game.sawmill.state.loaded, "all timber remains accounted for")
	check(game._save_game(4) and game._load_slot(4), "paid chain state persists")
	var routes: Dictionary = game.services.duplicate(true)
	routes.freight.name = "Timber shuttle"
	check(game.apply_service_routes(routes).begins_with("Routes applied"), "loaded sawmill directive permits unrelated service edits")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(4)))
	bad = payload.duplicate(true)
	bad.sawmill.loaded += 1
	var file := FileAccess.open(game.SaveSlots.path(4), FileAccess.WRITE)
	file.store_string(JSON.stringify(bad))
	file.close()
	position = game.freight_train.position
	var stock: Dictionary = game.sawmill.save_state()
	check(not game._load_slot(4) and game.sawmill.save_state() == stock and game.freight_train.position == position, "invalid inventory load is atomic")
	game.selected_station = Mill.CELL
	game.station_panel.show()
	game._update_station_inspector()
	check(game.station_title.text == "Sawmill" and game.station_details.text.contains("2 logs → 1 timber"), "direct industry inspector exposes recipe and stock")
	game.station_panel.hide()
	game.header_controls.open_accounts()
	check(game.header_controls.accounts_text.text.contains("Sawmill:"), "Accounts reports industrial throughput")
	game.header_controls.accounts_dialog.hide()
	game.queue_free()
	await process_frame
	game = fixture()
	game._execute_set_signal({"x": 18, "y": 24, "mode": "auto"})
	check(game._save_game(4), "legacy log-only fixture saves")
	payload = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(4)))
	payload.version = 36
	payload.erase("sawmill")
	payload.freight.erase("chain_stage")
	payload.freight.erase("recovery_stop")
	payload.freight.erase("leg_origin")
	var old := Migrations.migrate(payload)
	check(old.ok and game._is_valid_save(old.data) and not old.data.sawmill.installed and old.data.state == payload.state, "v36 preserves log-only mode and state")
	game._execute_set_signal({"x": 18, "y": 24, "mode": ""})
	game.build_sawmill()
	check(game.sawmill.state.installed and game._load_slot(4) and not game.sawmill.state.installed and game.track_signals.has(Mill.CELL), "loading log-only slot into industrial map validates saved facilities, not live map")
	game.queue_free()
	await process_frame
	game = fixture()
	game.build_sawmill()
	game.forest_stock = 20
	game.logs_produced = 20
	for i in range(600):
		tick(game)
		if game.freight_train.chain_stage == 1: break
	game.freight_train.service_enabled = false
	for i in range(150):
		tick(game)
		if game.freight_train.distance_along_route < game.freight_train.sawmill_distance - 10: break
	check(not game.freight_train.to_terminal and game.freight_train.cargo == 0 and game.freight_train.leg_origin == "sawmill", "empty withdrawal leaves sawmill toward forest")
	position = game.freight_train.position
	check(game.reverse_train(2).contains("reversed in place") and game.freight_train.recovery_stop == "sawmill" and game.freight_train.position == position, "withdrawal recovery returns to actual sawmill origin")
	check(game._save_game(4) and game._load_slot(4), "empty withdrawal recovery survives load")
	for i in range(150):
		tick(game)
		if not game.freight_train.recovery_returning: break
	check(game.freight_train.held and game.freight_train.distance_along_route == game.freight_train.sawmill_distance, "withdrawal recovery parks at sawmill without teleport")
	game.freight_train.held = false
	game.freight_train.cargo = 1
	game.freight_train.to_terminal = true
	game.freight_train.loading_rule = game.freight_train.LoadingRule.FULL
	check(game.freight_train.ready_to_move(0), "withdrawn partial load can request authority to finish delivery")
	game.queue_free()
	await process_frame
	game = fixture()
	game.build_sawmill()
	game.forest_stock = 20
	game.logs_produced = 20
	game.tracks[Vector2i(7, 24)] = false
	game.tracks[Vector2i(29, 24)] = false
	game.Fleet.assigned(game.fleet, "freight")["wagons"] = ["log_wagon"]
	game._apply_fleet_specs()
	game._execute_set_signal({"x": 20, "y": 24, "mode": "stop"})
	for i in range(1300): tick(game)
	check(game.freight_train.cargo_kind() == "timber" and game.freight_train.cargo > 0 and game.freight_income == 0 and str(game.reservation_waits.get("freight", "")).contains("Manual stop"), "timber departure respects manual block signal")
	check(game.Fleet.length(game.Fleet.assigned(game.fleet, "freight")) == 60 and not game.reservations.occupied_owners.has(Vector2i(20, 24)), "whole timber consist stops before held signal tile")
	position = game.freight_train.position
	for i in range(120): tick(game)
	check(game.freight_train.position == position and game.sawmill.state.sold == 0, "held cargo remains physically stopped without earning")
	game._execute_set_signal({"x": 20, "y": 24, "mode": "auto"})
	for i in range(800):
		tick(game)
		if game.sawmill.state.sold > 0: break
	check(game.sawmill.state.sold > 0, "released timber train completes physical terminal delivery")
	game.queue_free()
	await process_frame
	var reference: Dictionary = {}
	for fps in [30, 60, 120]:
		game = fixture()
		game.sim_rng.set_seed(123)
		game.build_sawmill()
		game.forest_stock = 20
		game.logs_produced = 20
		game.paused = false
		for frame in range(24 * fps): game._process(1.0 / fps)
		var state: Dictionary = {"mill": game.sawmill.save_state(), "train": game.freight_train.save_state(), "stock": game.forest_stock, "income": game.freight_income, "cash": game.money}
		if reference.is_empty(): reference = state
		check(state == reference and game.sawmill.state.sold > 0, "production/transport/income deterministic at %d FPS" % fps)
		game.queue_free()
		await process_frame
	print("Sawmill: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
