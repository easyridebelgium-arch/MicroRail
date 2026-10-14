extends SceneTree
const Arrivals = preload("res://scripts/core/arrival_targets.gd")
const Services = preload("res://scripts/service_routes.gd")
const Migrations = preload("res://scripts/core/save_migrations.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func tick(game: Node) -> void:
	game.sim_clock.begin_tick()
	game._simulation_step(1.0 / 60.0)
func fixture() -> Node:
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.paused = true
	game.money = 100000
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	return game
func run() -> void:
	var config := Services.defaults()
	config.passenger.arrival_targets = {"a>b": 8, "b>a": 9}
	check(Services.is_valid(config), "separate outbound and return targets accepted")
	for bad in [{"c>a": 4}, {"a>b": 0}, {"a>b": 1441}, {"a>b": 3.5}, {"a>b": "8"}]:
		config.passenger.arrival_targets = bad
		check(not Services.is_valid(config), "invalid leg/duration refused")
	config.passenger.arrival_targets = {"a>b": 8.0}
	check(typeof(Services.from_save(config).passenger.arrival_targets["a>b"]) == TYPE_INT, "JSON targets normalize")
	var copied := Services.copy_route(config.passenger, {"name": "Copy", "stops": ["b", "c"]})
	copied.arrival_targets["a>b"] = 3
	check(config.passenger.arrival_targets["a>b"] == 8, "copied budgets do not alias source")
	config.passenger.stops = ["a", "c", "b"]
	config.passenger.mode = "loop"
	config.passenger.arrival_targets = {"b>a": 4}
	check(Services.is_valid(config), "Loop closing leg supports target")
	var meter := Arrivals.new()
	meter.depart("passenger", 1, "a>b", 120, 2, 0)
	meter.arrive("passenger", "b", 181)
	check(meter.completed[0].due == 120 and meter.report().contains("0 / 1 on time"), "scheduled baseline includes late departure and precise tolerance")
	meter.depart("passenger", 1, "b>a", 200, 2)
	meter.arrive("passenger", "a", 380)
	check(meter.report().contains("1 / 2 on time"), "unscheduled baseline is actual departure and tolerance includes boundary")
	meter.depart("passenger", 1, "a>b", 400, 2)
	meter.cancel("passenger")
	meter.arrive("passenger", "a", 500)
	check(meter.completed.size() == 2 and meter.active.is_empty(), "turn-back cancels result rather than recording destination arrival")
	for i in range(140):
		meter.depart("passenger", 1, "a>b", 600 + i, 2)
		meter.arrive("passenger", "b", 600 + i)
	check(meter.completed.size() == 128, "history bounded")
	root.size = Vector2i(1280, 720)
	var game := fixture()
	config = game.services.duplicate(true)
	config.passenger.timetable = [360]
	config.passenger.arrival_targets = {"a>b": 8, "b>a": 9}
	check(game.apply_service_routes(config).begins_with("Routes applied"), "actual targets apply")
	game.passenger_held = true
	for i in range(120): tick(game)
	check(game.arrival_targets.active.is_empty(), "held train cannot begin target or consume slot")
	game.passenger_held = false
	tick(game)
	check(game.arrival_targets.active.passenger.depart == 121 and game.arrival_targets.active.passenger.due == 480, "physical departure snapshots scheduled arrival")
	var position: Vector2 = game.train_position
	config = game.services.duplicate(true)
	config.passenger.arrival_targets["a>b"] = 20
	check(game.apply_service_routes(config).begins_with("Routes applied") and game.train_position == position and game.arrival_targets.active.passenger.due == 480, "budget edit affects future departures without rewriting active target")
	game.inspect_train(1)
	check(game.train_inspector.summary.text.contains("Arrival target A → B"), "train inspector shows live target")
	game.train_inspector.hide()
	check(game._save_game(4), "mid-trip target saves")
	var original: Dictionary = game.arrival_targets.save_state()
	check(game._load_slot(4) and game.arrival_targets.save_state() == original and game.train_position == position, "load keeps snapshot and exact position")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(4)))
	for field in ["due", "depart", "train_id", "minutes"]:
		var bad: Dictionary = payload.duplicate(true)
		bad.arrivals.active.passenger[field] = -1
		check(not game._is_valid_save(bad), "invalid %s rejected before apply" % field)
	var bad: Dictionary = payload.duplicate(true)
	bad.arrivals.active.passenger.leg = "b>a"
	check(not game._is_valid_save(bad), "wrong-direction snapshot refused")
	payload.version = 33
	payload.erase("arrivals")
	payload.services.passenger.erase("arrival_targets")
	var old := Migrations.migrate(payload)
	check(old.ok and game._is_valid_save(old.data) and old.data.arrivals.active.is_empty() and old.data.state == payload.state, "v33 migration preserves physical state with unknown timing history")
	for i in range(500):
		tick(game)
		if game.arrival_targets.completed.size() > 0: break
	check(game.arrival_targets.completed.size() == 1 and game.arrival_targets.completed[0].due == 480, "real arrival completes original budget")
	game.header_controls.open_accounts()
	check(game.header_controls.accounts_text.text.contains("Arrival punctuality: 1 / 1"), "Accounts shows measured arrival result")
	game.header_controls.accounts_dialog.hide()
	game.route_editor.open_editor()
	game.route_editor.arrival_minutes.value = 12
	check(game.route_editor.draft.passenger.arrival_targets["a>b"] == 12 and game.services.passenger.arrival_targets["a>b"] == 20, "UI budget is draft only until Apply")
	game.route_editor.hide()
	var original_scale: float = game.GameSettings.ui_scale
	for ui_scale in [1.0, 1.5, 2.0]:
		game.GameSettings.ui_scale = ui_scale
		game._apply_settings()
		game.route_editor.open_editor()
		await process_frame
		await process_frame
		check(float(game.route_editor.size.y) <= game.get_viewport_rect().size.y + 1, "Routes arrival controls fit at %d%%" % int(ui_scale * 100))
		game.route_editor.hide()
		game.header_controls.open_accounts()
		await process_frame
		check(float(game.header_controls.accounts_dialog.size.y) <= game.get_viewport_rect().size.y + 1, "Accounts punctuality fits at %d%%" % int(ui_scale * 100))
		game.header_controls.accounts_dialog.hide()
	game.GameSettings.ui_scale = original_scale
	game._apply_settings()
	for i in range(300):
		tick(game)
		if game.arrival_targets.active.has("passenger"): break
	check(game.arrival_targets.active.has("passenger") and game.arrival_targets.active.passenger.leg == "b>a", "return direction starts separate target")
	game.reverse_train(1)
	check(game.arrival_targets.active.is_empty(), "physical recovery cancels target immediately")
	game.queue_free()
	await process_frame
	game = fixture()
	game.passenger_held = true
	var purchase: Dictionary = game.buy_fleet_train("passenger_fast")
	game.start_passenger_service(int(purchase.id), "c")
	var key: String = game.Fleet.find(game.fleet, int(purchase.id)).service
	config = game.services.duplicate(true)
	config[key].stops = ["c", "b"]
	config[key].arrival_targets = {"c>b": 8, "b>c": 8}
	check(game.apply_service_routes(config).begins_with("Routes applied"), "independent service accepts targets")
	tick(game)
	check(game.arrival_targets.active.has(key) and game.arrival_targets.active[key].train_id == int(purchase.id), "extra service uses own actual departure hook and identity")
	check(game._save_game(4) and game._load_slot(4) and game.arrival_targets.active.has(key), "extra active target survives load")
	game.tracks.erase(Vector2i(30, 8))
	game._check_route()
	for i in range(720): tick(game)
	check(game.arrival_targets.completed.is_empty() and game.arrival_targets.describe(key, game.sim_clock.tick).contains("late by"), "missing track cannot fabricate arrival or hide accrued lateness")
	game.tracks[Vector2i(30, 8)] = false
	game._check_route()
	for i in range(600):
		tick(game)
		if not game.arrival_targets.completed.is_empty(): break
	check(game.arrival_targets.completed.size() == 1 and game.arrival_targets.report(key).contains("0 / 1 on time"), "repaired service completes as late with continuous timing")
	var saved: Dictionary = game.arrival_targets.save_state()
	check(game._save_game(4) and game._load_slot(4) and game.arrival_targets.save_state() == saved, "completed punctuality history persists")
	payload = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(4)))
	bad = payload.duplicate(true)
	bad.arrivals.completed[0].arrive = game.sim_clock.tick + 1
	var file := FileAccess.open(game.SaveSlots.path(4), FileAccess.WRITE)
	file.store_string(JSON.stringify(bad))
	file.close()
	position = game.passenger_services[key].position
	check(not game._load_slot(4) and game.arrival_targets.save_state() == saved and game.passenger_services[key].position == position, "corrupt arrival history load is atomic")
	game.route_editor.open_editor()
	game.route_editor.draft.passenger.arrival_targets = {"a>b": 8, "b>a": 9}
	game.route_editor.draft.passenger.stops = ["a", "c"]
	game.route_editor._refresh_timetable_legs()
	check(not game.route_editor.draft.passenger.has("arrival_targets") and game.route_editor.directive_warning.text.contains("arrival target"), "changed legs discard targets with draft warning")
	game.route_editor.hide()
	config = game.services.duplicate(true)
	config.passenger.arrival_targets = {"a>b": 6, "b>a": 7}
	config[key].link = "passenger"
	var linked := Services.propagate(config)
	check(linked[key].arrival_targets == config.passenger.arrival_targets and linked[key].stops == config.passenger.stops, "linked route inherits directional arrival targets")
	var linked_meter := Arrivals.new()
	linked_meter.depart(key, int(purchase.id), "a>b", 100, 2)
	linked_meter.arrive(key, "b", 200)
	check(linked_meter.report("passenger", [key]).contains("1 / 1 on time"), "source-group report includes linked trains")
	game.queue_free()
	await process_frame
	meter = Arrivals.new()
	meter.depart("passenger", 1, "a>b", 64770, 4, 64740)
	check(meter.describe("passenger", 64770).contains("Day 2"), "arrival targets wrap midnight using absolute clock")
	var reference: Dictionary = {}
	for fps in [30, 60, 120]:
		game = fixture()
		config = game.services.duplicate(true)
		config.passenger.arrival_targets = {"a>b": 8, "b>a": 8}
		game.apply_service_routes(config)
		game.paused = false
		for frame in range(18 * fps): game._process(1.0 / fps)
		var state: Dictionary = game.arrival_targets.save_state()
		if reference.is_empty(): reference = state
		check(state == reference and not state.completed.is_empty(), "physical arrival results equal at %d FPS" % fps)
		game.queue_free()
		await process_frame
	for speed in [2.0, 5.0, 10.0]:
		game = fixture()
		config = game.services.duplicate(true)
		config.passenger.arrival_targets = {"a>b": 8, "b>a": 8}
		game.apply_service_routes(config)
		game.paused = false
		game.sim_clock.speed = speed
		for frame in range(int(60 * 18 / speed)): game._process(1.0 / 60.0)
		check(game.arrival_targets.save_state() == reference, "arrival timing uses simulation clock at %dx" % int(speed))
		game.queue_free()
		await process_frame
	print("Arrival targets: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
