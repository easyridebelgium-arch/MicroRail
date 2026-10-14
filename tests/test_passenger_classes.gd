extends SceneTree
const Classes = preload("res://scripts/core/passenger_classes.gd")
const Demand = preload("res://scripts/core/passenger_demand.gd")
const Ledger = preload("res://scripts/core/journey_ledger.gd")
const Rng = preload("res://scripts/core/sim_rng.gd")
const Clock = preload("res://scripts/core/sim_clock.gd")
const Migrations = preload("res://scripts/core/save_migrations.gd")
class LastChoice extends RefCounted:
	func randi_range(_minimum: int, maximum: int) -> int: return maximum
class FirstChoice extends RefCounted:
	func randi_range(minimum: int, _maximum: int) -> int: return minimum
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func empty_demand() -> RefCounted:
	var demand := Demand.new()
	for station in Demand.STATIONS: demand.reset_total(station, 0)
	return demand
func fixture() -> Node:
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.paused = true
	game.money = 100000
	for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	for station in Demand.STATIONS: game.passenger_demand.reset_total(station, 0)
	return game
func advance(game: Node) -> void:
	game.sim_clock.begin_tick()
	game._refresh_directional_routes()
	game._rebuild_reservations(true)
	game._move_train(1.0 / 60.0)
func run() -> void:
	check(Classes.direct("a", ["c", "b"]) == ["c"] and Classes.direct("a", ["b", "c"]).is_empty(), "Express requires immediate distant destination")
	check(Classes.direct("c", ["a"]) == ["a"] and Classes.direct("b", ["a"]).is_empty(), "only distant hubs support Express")
	var demand = empty_demand()
	demand.generate("a", 8, 100, LastChoice.new(), 60, true)
	check(Classes.counts(demand.batches.a) == {"local": 6, "express": 2} and demand.queues.a.c == 8, "quarter of qualifying generation is Express without changing total demand")
	demand.generate("c", 4, 100, FirstChoice.new(), 60, true)
	check(Classes.counts(demand.batches.c).express == 1, "opposite hub follows same rule")
	demand.generate("b", 8, 100, LastChoice.new(), 60, true)
	check(Classes.counts(demand.batches.b).express == 0, "short commuter trips stay Local")
	var manifest: Dictionary = {}
	check(demand.board("a", ["b", "c"], 20, manifest, 120) == 6 and demand.waiting("a") == 2, "stopping/transfer opportunity leaves Express waiting")
	check(demand.eligible_waiting("a", ["c"], [], 120) == 0 and demand.eligible_waiting("a", ["c"], ["c"], 120) == 2, "capacity denial excludes class-ineligible people")
	manifest.clear()
	check(demand.board("a", ["c"], 1, manifest, 180, ["c"]) == 1 and demand.batches.a[0].count == 1 and demand.batches.a[0].start == 60, "partial Express boarding preserves remainder and original clock")
	var ledger := Ledger.new()
	ledger.ensure("passenger", {}, 180)
	ledger.board("passenger", demand.last_journeys)
	check(ledger.aboard.passenger[0].get("class") == "express", "aboard metadata retains class")
	var rows: Array = ledger.release("passenger", ["c"])
	demand.return_to("a", manifest, 240, rows)
	check(Classes.counts(demand.batches.a).express == 2 and demand.batches.a[0].start == 60, "physical recovery keeps Express preference and original start")
	demand.board("a", ["c"], 5, manifest, 300, ["c"])
	ledger.ensure("passenger", {}, 300)
	ledger.board("passenger", demand.last_journeys)
	ledger.finish("passenger", "c", manifest, 600)
	check(ledger.completed.size() == 1 and ledger.completed[0].get("class") == "express" and ledger.completed[0].count == 2, "completed class groups stay distinct and conserved")
	var mixed = empty_demand()
	mixed.generate("a", 4, 100, LastChoice.new(), 0, true)
	var mixed_load: Dictionary = {}
	mixed.board("a", ["c"], 4, mixed_load, 60, ["c"])
	var mixed_ledger := Ledger.new()
	mixed_ledger.ensure("passenger", {}, 60)
	mixed_ledger.board("passenger", mixed.last_journeys)
	check(mixed_ledger.aboard.passenger.size() == 2 and Classes.counts(mixed_ledger.aboard.passenger) == {"local": 3, "express": 1}, "equal-time mixed classes never merge aboard")
	mixed = empty_demand()
	mixed.generate("a", 4, 100, LastChoice.new(), 0, true)
	mixed_load = {}
	mixed.board("a", ["c"], 4, mixed_load, 60)
	var transfer_rows: Array = mixed.last_journeys.duplicate(true)
	check(mixed.interchange("b", ["a", "b"], mixed_load, 120, transfer_rows) == 3 and Classes.counts(mixed.batches.b).local == 3 and mixed.waiting("a") == 1, "Local transfers keep class while Express stays at origin")
	check(Classes.service_can_carry({"stops": ["a", "c", "b"], "mode": "loop"}, "a", "c") and not Classes.service_can_carry({"stops": ["a", "c", "b"], "mode": "loop"}, "c", "a"), "Loop eligibility respects direction and intermediate stops")
	var plain = empty_demand()
	var classified = empty_demand()
	var left_rng := Rng.new()
	var right_rng := Rng.new()
	left_rng.set_seed(45)
	right_rng.set_seed(45)
	plain.generate("a", 30, 100, left_rng, 0)
	classified.generate("a", 30, 100, right_rng, 0, true)
	check(plain.queues == classified.queues and left_rng.save_state() == right_rng.save_state(), "classification consumes no additional random draws")
	var progress: Dictionary = classified.class_progress.duplicate()
	classified.generate("a", 20, classified.waiting("a"), right_rng, 1, true)
	check(classified.class_progress == progress and left_rng.save_state() == right_rng.save_state(), "full queues do not advance class counter or RNG")
	var saved: Dictionary = classified.save_state({}, 1)
	var restored := Demand.new()
	restored.restore_state(JSON.parse_string(JSON.stringify(saved)))
	for i in range(8):
		classified.generate("a", 1, 100, LastChoice.new(), 2 + i, true)
		restored.generate("a", 1, 100, LastChoice.new(), 2 + i, true)
	check(classified.save_state({}, 10) == restored.save_state({}, 10), "generation fraction survives JSON load")
	root.size = Vector2i(1280, 720)
	var game := fixture()
	var config: Dictionary = game.services.duplicate(true)
	config.passenger.stops = ["a", "b", "c"]
	check(game.apply_service_routes(config).begins_with("Routes applied"), "stopping route fixture applies")
	game.passenger_demand.generate("a", 4, 100, LastChoice.new(), 0, true)
	check(game._board_waiting("a", ["b", "c"], 20, game.passenger_destinations) == 3 and game.waiting_at_a == 1, "real stopping service refuses Express even when C is served")
	check(game.passenger_occupancy.statistics(1).left == 0, "class refusal does not become a seats warning")
	game.passenger_destinations.clear()
	game.journey_ledger.aboard.clear()
	config.passenger.stops = ["a", "c"]
	check(game.apply_service_routes(config).begins_with("Routes applied"), "direct route fixture applies")
	check(game._board_waiting("a", ["c"], 20, game.passenger_destinations) == 1 and game.journey_ledger.aboard.passenger[0].get("class") == "express", "standard locomotive accepts Express on a direct leg")
	game.train_needs_boarding = false
	advance(game)
	game.inspect_train(1)
	check(game.train_inspector.summary.text.contains("Local 0 / Express 1"), "train inspector shows actual onboard class")
	game.train_inspector.hide()
	game.route_editor.open_editor()
	check(game.route_editor.arrival_hint.text.contains("Local and Express"), "Routes describes direct leg eligibility")
	game.route_editor.hide()
	check(game._save_game(4), "class metadata saves mid-journey")
	var position: Vector2 = game.train_position
	check(game._load_slot(4) and game.train_position == position and game.journey_ledger.aboard.passenger[0].get("class") == "express", "loaded class and position remain intact")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(4)))
	var bad: Dictionary = payload.duplicate(true)
	bad.journeys.aboard.passenger[0]["class"] = "first_class"
	check(not game._is_valid_save(bad), "unknown class rejects save")
	var corrupted := FileAccess.open(game.SaveSlots.path(4), FileAccess.WRITE)
	corrupted.store_string(JSON.stringify(bad))
	corrupted.close()
	check(not game._load_slot(4) and game.train_position == position and game.journey_ledger.aboard.passenger[0].get("class") == "express", "invalid class load preserves real train and manifest atomically")
	bad = payload.duplicate(true)
	bad.demand.class_progress.a = 4
	check(not game._is_valid_save(bad), "invalid class fraction rejects save")
	bad = payload.duplicate(true)
	bad.services.passenger.stops = ["a", "b", "c"]
	check(not game._is_valid_save(bad), "ineligible saved Express route rejected")
	payload.version = 34
	payload.demand.erase("class_progress")
	var old := Migrations.migrate(payload)
	check(old.ok and game._is_valid_save(old.data) and old.data.journeys.aboard.passenger[0].get("class") == "local" and old.data.state == payload.state, "legacy migration keeps positions/counts and marks old passengers Local")
	check(game.reverse_train(1).contains("reversed in place"), "Express train recovery is permitted safely")
	for i in range(100):
		advance(game)
		if not game.passenger_returning: break
	check(game.waiting_at_a == 1 and game.passenger_demand.batches.a[0].get("class") == "express" and game.passengers_delivered == 0, "physical reversal returns Express without earning fares")
	check(game._save_game(4) and game._load_slot(4) and game.passenger_demand.batches.a[0].get("class") == "express", "recovered preference persists")
	game.passenger_held = false
	game.passenger_service_enabled = true
	var cash: int = game.money
	for i in range(1500):
		advance(game)
		if game.passenger_stop_index == 1: break
	check(game.passengers_delivered == 1 and game.money == cash + 5 and game.journey_ledger.completed[0].get("class") == "express", "completed Express journey keeps existing fare and records class")
	game.header_controls.open_accounts()
	check(game.header_controls.accounts_text.text.contains("Passenger classes"), "Accounts exposes class rule and counts")
	game.header_controls.accounts_dialog.hide()
	game.queue_free()
	await process_frame
	game = fixture()
	game.sim_rng.set_seed(15)
	for i in range(8): game._generate_passengers(game.PASSENGER_INTERVAL)
	check(Classes.counts(game.passenger_demand.batches.a).express > 0 and Classes.counts(game.passenger_demand.batches.b).express == 0, "real game generation opts into deterministic class demand")
	game.selected_station = game.STATION_A
	game.station_panel.show()
	game._update_station_inspector()
	check(game.station_details.text.contains("Passenger classes"), "station Details exposes waiting classes and direct-service requirement")
	game.station_panel.hide()
	game.queue_free()
	await process_frame
	var reference: Dictionary = {}
	for fps in [30, 60, 120]:
		var result := replay(fps)
		if reference.is_empty(): reference = result
		check(result == reference, "class queues/boarding deterministic at %d FPS" % fps)
	print("Passenger classes: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func replay(fps: int) -> Dictionary:
	var clock := Clock.new()
	var rng := Rng.new()
	rng.set_seed(8)
	var demand = empty_demand()
	var manifest: Dictionary = {}
	for frame in range(fps * 12):
		for step in clock.advance(1.0 / fps):
			clock.begin_tick()
			if clock.tick % 60 == 0: demand.generate("a", 3, 100, rng, clock.tick, true)
			if clock.tick % 180 == 0: demand.board("a", ["c"], 30, manifest, clock.tick, ["c"])
	return {"demand": demand.save_state(manifest, clock.tick), "manifest": manifest, "rng": rng.save_state()}
