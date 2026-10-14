extends SceneTree
const Demand = preload("res://scripts/core/passenger_demand.gd")
const Ledger = preload("res://scripts/core/journey_ledger.gd")
const Clock = preload("res://scripts/core/sim_clock.gd")
const Migrations = preload("res://scripts/core/save_migrations.gd")
class DestinationRng extends RefCounted:
	func randi_range(_low: int, _high: int) -> int: return 1
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var demand := Demand.new()
	var ledger := Ledger.new()
	for station in Demand.STATIONS: demand.reset_total(station, 0)
	demand.generate("a", 5, 100, DestinationRng.new(), 60)
	var manifest: Dictionary = {}
	ledger.ensure("first", manifest, 180)
	demand.board("a", ["c"], 3, manifest, 180)
	ledger.board("first", demand.last_journeys)
	check(ledger.aboard.first[0].origin == "a" and ledger.aboard.first[0].start == 60 and demand.waiting("a") == 2, "partial boarding keeps original origin and journey start")
	var rows := ledger.release("first", ["c"])
	demand.interchange("b", ["a", "b"], manifest, 360, rows)
	check(demand.batches.b[0].tick == 360 and demand.batches.b[0].start == 60, "interchange has a new station wait but preserves journey clock")
	ledger.ensure("second", manifest, 480)
	demand.board("b", ["c"], 2, manifest, 480)
	ledger.board("second", demand.last_journeys)
	check(ledger.aboard.second[0].start == 60 and demand.waiting("b") == 1, "partial connection boarding carries source clock")
	ledger.finish("second", "c", manifest, 600)
	Demand.alight(manifest, "c")
	check(ledger.completed[0].count == 2 and ledger.completed[0].end - ledger.completed[0].start == 540 and ledger.summary().contains("9.0s average"), "duration includes initial and interchange waits plus rides")
	ledger.ensure("second", manifest, 660)
	demand.board("b", ["c"], 5, manifest, 660)
	ledger.board("second", demand.last_journeys)
	demand.return_to("b", manifest, 780, ledger.release("second", ["c"]))
	check(demand.batches.b[0].start == 60 and demand.batches.b[0].tick == 780, "recovery resets station wait only")
	ledger.ensure("legacy", {"b": 2}, 60)
	check(ledger.describe_train("legacy", {"b": 2}, 120).contains("elapsed unavailable"), "unknown legacy clocks never display invented zero duration")
	ledger.finish("legacy", "b", {"b": 2}, 120)
	check(ledger.unknown_completed == 2, "unknown completions counted separately from measured averages")
	var bounded := Ledger.new()
	for tick in range(600, 740):
		bounded.aboard["train"] = [{"destination": "c", "origin": "a", "start": 0, "known": true, "count": 1}]
		bounded.finish("train", "c", {"c": 1}, tick)
	check(bounded.completed.size() == 128 and bounded.completed.front().end == 612, "bounded history retains the most recent completed groups")
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
	game.start_passenger_service(int(purchase.id), "c")
	var key: String = game.Fleet.find(game.fleet, int(purchase.id)).service
	var routes: Dictionary = game.services.duplicate(true)
	routes[key].stops = ["c", "b"]
	check(game.apply_service_routes(routes).begins_with("Routes applied"), "physical transfer fixture connects A-B and C-B")
	for station in Demand.STATIONS: game.passenger_demand.reset_total(station, 0)
	game.sim_clock.tick = 60
	game.passenger_demand.generate("a", 5, 100, DestinationRng.new(), 60)
	var fare_baseline: int = game.money + game.total_operating_cost
	for step in range(650):
		advance(game, "passenger")
		if game.passenger_stop_index == 1: break
	check(game.waiting_at_b == 5 and game.journey_ledger.completed.is_empty() and game.passengers_delivered == 0, "physical interchange records no completion or fare")
	check(game.passenger_demand.batches.b[0].origin == "a" and game.passenger_demand.batches.b[0].start == 60, "actual train arrival retains origin metadata")
	for step in range(900):
		advance(game, "passenger")
		if game.passenger_stop_index == 0: break
	game.passenger_held = true
	for step in range(650):
		advance(game, key)
		if game.passenger_services[key].stop_index == 1: break
	for step in range(900):
		advance(game, key)
		if game.passenger_services[key].passengers == 5: break
	check(game.journey_ledger.aboard[key][0].start == 60, "second physical train carries the original journey")
	game.inspect_train(int(purchase.id))
	check(game.train_inspector.summary.text.contains("5 / 5 passengers tracked"), "train inspector exposes tracked elapsed journeys")
	game.train_inspector.hide()
	check(game._save_game(4), "game saves active journey clocks")
	var position: Vector2 = game.passenger_services[key].position
	check(game._load_slot(4) and game.passenger_services[key].position == position and game.journey_ledger.aboard[key][0].start == 60, "load restores active clocks without teleporting")
	for step in range(150):
		advance(game, key)
		if game.passenger_services[key].distance < 400: break
	var running = game.passenger_services[key]
	position = running.position
	running.reverse()
	check(running.position == position, "reversal changes direction in place")
	for step in range(300):
		advance(game, key)
		if not running.returning: break
	check(running.held and game.waiting_at_b == 5 and game.passenger_demand.batches.b[0].start == 60 and game.passengers_delivered == 0, "physical turn-back retains clocks and unfinished riders")
	game._save_game(4)
	check(game._load_slot(4) and game.passenger_demand.batches.b[0].start == 60, "recovered queue timing survives save/load")
	running = game.passenger_services[key]
	running.held = false
	running.enabled = true
	for step in range(900):
		advance(game, key)
		if running.stop_index == 0: break
	check(game.passengers_delivered == 5 and game.journey_ledger.completed.size() == 1 and game.journey_ledger.completed[0].origin == "a", "destination completes one measured A-C journey group")
	check(game.journey_ledger.completed[0].start == 60 and game.journey_ledger.completed[0].end == game.sim_clock.tick, "elapsed duration spans physical recovery and reboarding")
	check(game.money + game.total_operating_cost == fare_baseline + 5 * game.TICKET_PRICE, "new timing cannot duplicate fares")
	game.header_controls.open_accounts()
	check(game.header_controls.accounts_text.text.contains("A → C: 5 passengers"), "Accounts shows completed origin-destination times")
	game.header_controls.accounts_dialog.hide()
	game.passenger_demand.generate("a", 2, 100, DestinationRng.new(), 60)
	game._save_game(4)
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(4)))
	var bad := payload.duplicate(true)
	bad.journeys.completed[0].end = game.sim_clock.tick + 1
	check(not game._is_valid_save(bad), "future completion rejected")
	bad = payload.duplicate(true)
	bad.journeys.aboard[key] = [{"destination": "c", "origin": "a", "start": 0, "known": true, "count": 1}]
	check(not game._is_valid_save(bad), "aboard metadata must match actual passenger manifest")
	var damaged := FileAccess.open("user://damaged_journeys.json", FileAccess.WRITE)
	damaged.store_string(JSON.stringify(bad))
	damaged.close()
	var history_before: Array = game.journey_ledger.completed.duplicate(true)
	position = game.passenger_services[key].position
	check(not game._load_game("user://damaged_journeys.json") and game.journey_ledger.completed == history_before and game.passenger_services[key].position == position, "damaged journey load is atomic for clocks and physical train")
	payload.version = 32
	payload.erase("journeys")
	var migrated := Migrations.migrate(payload)
	check(migrated.ok and migrated.data.version == 33 and migrated.data.journeys.completed.is_empty() and migrated.data.journeys.unknown_completed == 5 and game._is_valid_save(migrated.data), "v32 keeps counts and marks old completions unmeasured")
	check(migrated.data.demand.batches.a[0].tick == 60 and not migrated.data.demand.batches.a[0].known and migrated.data.demand.queues == payload.demand.queues, "legacy queue ages survive without inventing original journey provenance")
	game.queue_free()
	await process_frame
	var baseline := frame_case(30)
	for fps in [60, 120]: check(frame_case(fps) == baseline, "journey histories and queue metadata match at %d FPS" % fps)
	print("Journey times: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func advance(game: Node, key: String) -> void:
	game.sim_clock.begin_tick()
	game._rebuild_reservations(true)
	if key == "passenger": game._move_train(1.0 / 60.0)
	else: game.passenger_services[key].advance(game, 1.0 / 60.0)
func frame_case(fps: int) -> Dictionary:
	var demand := Demand.new()
	var ledger := Ledger.new()
	var clock := Clock.new()
	var manifest: Dictionary = {}
	for station in Demand.STATIONS: demand.reset_total(station, 0)
	for frame in range(12 * fps):
		for step in range(clock.advance(1.0 / fps)):
			clock.begin_tick()
			match clock.tick:
				60: demand.generate("a", 5, 100, DestinationRng.new(), clock.tick)
				180:
					ledger.ensure("one", manifest, clock.tick)
					demand.board("a", ["c"], 5, manifest, clock.tick)
					ledger.board("one", demand.last_journeys)
				360: demand.interchange("b", ["a", "b"], manifest, clock.tick, ledger.release("one", ["c"]))
				480:
					ledger.ensure("two", manifest, clock.tick)
					demand.board("b", ["c"], 5, manifest, clock.tick)
					ledger.board("two", demand.last_journeys)
				600:
					ledger.finish("two", "c", manifest, clock.tick)
					Demand.alight(manifest, "c")
	return {"ledger": ledger.save_state({"one": {}, "two": manifest}, clock.tick), "demand": demand.save_state({}, clock.tick), "tick": clock.tick}
