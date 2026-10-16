extends SceneTree
const Factory = preload("res://scripts/core/factory.gd")
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
	for x in range(7, 30): game.tracks[Vector2i(x, 24)] = false
	game._check_route()
	return game
func tick(game: Node) -> void:
	game.sim_clock.begin_tick()
	game._simulation_step(1.0 / 60.0)
func run() -> void:
	var factory := Factory.new()
	factory.state.installed = true
	check(factory.accept(3) == 3 and Factory.GOODS.cargo_id == "goods", "typed factory inputs and goods resource")
	for i in range(599): factory.tick()
	check(factory.state.output == 0 and factory.state.progress == 599, "production waits ten full simulation seconds")
	var restored := Factory.new()
	restored.restore_state(JSON.parse_string(JSON.stringify(factory.save_state())))
	factory.tick()
	restored.tick()
	check(factory.save_state() == restored.save_state() and factory.state.input == 2 and factory.state.output == 1, "mid-batch JSON continuation is exact")
	check(factory.take(9) == 1 and Factory.valid(factory.save_state()), "loading preserves production accounting")
	check(factory.accept(1000) == 198, "bounded input accepts only available room")
	var full := Factory.new()
	full.state.installed = true
	full.state.received = 202
	full.state.consumed = 200
	full.state.produced = 200
	full.state.input = 2
	full.state.output = 200
	for i in range(700): full.tick()
	check(full.state.input == 2 and full.state.progress == 0 and Factory.valid(full.save_state()), "full output stalls without loss")
	root.size = Vector2i(1280, 720)
	var game := fixture()
	check(game.build_factory().contains("sawmill") and game.money == 10000, "sawmill prerequisite never charges on rejection")
	game.build_sawmill()
	game._execute_set_signal({"x": 23, "y": 24, "mode": "auto"})
	check(game.build_factory().contains("signal") and game.money == 9500, "loading-pad signal must move before installation")
	game._execute_set_signal({"x": 23, "y": 24, "mode": ""})
	var position: Vector2 = game.freight_train.position
	check(game.build_factory().contains("installed") and game.money == 8700 and game.freight_train.position == position, "factory costs 800 without teleport or route change")
	check(game.build_factory().contains("already") and game.money == 8700, "repeat purchase cannot charge twice")
	game.Fleet.assigned(game.fleet, "freight")["wagons"] = ["log_wagon"]
	game._apply_fleet_specs()
	game.forest_stock = 20
	game.logs_produced = 20
	game._execute_set_signal({"x": 25, "y": 24, "mode": "stop"})
	for i in range(1600):
		tick(game)
		if game.factory.state.received > 0: break
	check(game.factory.state.received == 1 and game.sawmill.state.sold == 0 and game.freight_income == 0 and game.freight_train.chain_stage == 2, "timber physically unloads at factory without intermediate payment")
	for i in range(250): tick(game)
	position = game.freight_train.position
	check(game._save_game(4) and game._load_slot(4) and game.freight_train.position == position and game.factory.state.progress > 0, "productive timer and factory stop survive save/load")
	for i in range(900): tick(game)
	check(game.freight_train.cargo_kind() == "goods" and game.freight_train.cargo == 1 and game.factory.state.sold == 0 and str(game.reservation_waits.get("freight", "")).contains("Manual stop"), "finished goods respect held signal")
	check(not game.reservations.occupied_owners.has(Vector2i(25, 24)), "whole consist remains clear of signal tile")
	position = game.freight_train.position
	check(game.reverse_train(2).contains("reversed in place") and game.freight_train.position == position and game.freight_train.recovery_stop == "factory", "goods recovery returns to actual factory departure")
	check(game._save_game(4) and game._load_slot(4), "mid-recovery goods load persists")
	for i in range(200):
		tick(game)
		if not game.freight_train.recovery_returning: break
	check(game.freight_train.held and game.freight_train.cargo == 1 and game.freight_train.distance_along_route == game.freight_train.factory_distance and game.freight_income == 0, "recovery retains goods aboard at factory")
	game.freight_train.held = false
	game.freight_train.service_enabled = true
	game._execute_set_signal({"x": 25, "y": 24, "mode": "auto"})
	for i in range(600):
		tick(game)
		if game.factory.state.sold > 0: break
	check(game.factory.state.sold == 1 and game.freight_income == 40 and game.logs_delivered == 0 and game.sawmill.state.sold == 0, "only finished-goods terminal arrival pays")
	check(game.sawmill.state.loaded == game.factory.state.received and game.factory.state.loaded == game.factory.state.sold + game.freight_train.cargo, "cross-industry conservation")
	check(game._save_game(4) and game._load_slot(4), "paid full chain persists")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(4)))
	payload.factory.received += 1
	payload.factory.input += 1
	check(Factory.valid(payload.factory), "individual inventory can be valid while transfer totals conflict")
	var file := FileAccess.open(game.SaveSlots.path(4), FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	position = game.freight_train.position
	check(not game._load_slot(4) and game.freight_train.position == position, "corrupt inter-industry input rejected atomically")
	game.selected_station = Factory.CELL
	game.station_panel.show()
	game._update_station_inspector()
	check(game.station_title.text == "Factory" and game.station_details.text.contains("1 timber → 1 goods"), "factory inspector explains recipe")
	game.station_panel.hide()
	game.header_controls.open_accounts()
	check(game.header_controls.accounts_text.text.contains("Factory:"), "Accounts shows factory throughput")
	game.header_controls.accounts_dialog.hide()
	game.queue_free()
	await process_frame
	game = fixture()
	game.build_sawmill()
	game._save_game(4)
	payload = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(4)))
	payload.version = 37
	payload.erase("factory")
	var old := Migrations.migrate(payload)
	check(old.ok and old.data.sawmill == payload.sawmill and not old.data.factory.installed and game._is_valid_save(old.data), "v37 keeps sawmill service and adds empty factory")
	game.freight_train.loading_rule = game.freight_train.LoadingRule.FULL
	game.sawmill.accept(20)
	game.freight_train.chain_stage = 1
	check(game.freight_train.processing_minimum_load() == 10, "Full waits for finite batch instead of impossible output capacity")
	game.queue_free()
	await process_frame
	# Exercise Full end to end without frame/render work: one physical shuttle
	# must finish a finite batch rather than wait for another delivery by itself.
	var mill = preload("res://scripts/core/sawmill.gd").new()
	mill.state.installed = true
	factory = Factory.new()
	factory.state.installed = true
	var train = preload("res://scripts/freight_train.gd").new()
	root.add_child(train)
	var cells: Array[Vector2i] = []
	for x in range(8, 29): cells.append(Vector2i(x, 24))
	train.set_route(cells, 32.0)
	train.configure_industry(mill, 32.0, factory)
	train.loading_rule = train.LoadingRule.FULL
	var delivered := [0]
	train.delivered.connect(func(amount: int) -> void: delivered[0] += amount)
	var logs := 20
	for i in range(12000):
		mill.tick()
		factory.tick()
		logs -= train.advance(1.0 / 60.0, logs)
		if delivered[0] > 0: break
	check(delivered[0] == 10 and mill.state.consumed == 20 and factory.state.consumed == 10 and train.cargo == 0, "Full single-shuttle completes 20 logs to 10 paid goods without supply deadlock")
	train.queue_free()
	await process_frame
	var reference: Dictionary = {}
	for fps in [30, 60, 120]:
		game = fixture()
		game.build_sawmill()
		game.build_factory()
		game.sim_rng.set_seed(456)
		game.forest_stock = 20
		game.logs_produced = 20
		game.paused = false
		for frame in range(35 * fps): game._process(1.0 / fps)
		var state: Dictionary = {"mill": game.sawmill.save_state(), "factory": game.factory.save_state(), "train": game.freight_train.save_state(), "stock": game.forest_stock, "income": game.freight_income, "cash": game.money}
		if reference.is_empty(): reference = state
		check(state == reference and game.factory.state.sold > 0, "full chain is deterministic at %d FPS" % fps)
		game.queue_free()
		await process_frame
	print("Factory: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
