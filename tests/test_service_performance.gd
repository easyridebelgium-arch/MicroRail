extends SceneTree
const Metrics = preload("res://scripts/core/service_performance.gd")
const Pins = preload("res://scripts/core/watchlist.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func text_of(node: Node) -> String:
	var text := str(node.text) + "\n" if node is Label else ""
	for child in node.get_children(): text += text_of(child)
	return text
func run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	game.paused = true
	game.money = 100000
	for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	for station in game.PassengerDemand.STATIONS: game.passenger_demand.reset_total(station, 0)
	# Exercise genuine boarding, physical movement, final delivery and cost hooks.
	for passenger in range(6): game.passenger_demand.enqueue_trip("a", "b", 100, 0)
	for index in range(500):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
	var totals: Dictionary = game.service_performance.totals(["passenger"])
	check(totals.finals >= 6 and totals.finals == game.passengers_delivered, "actual final arrivals reconcile with company passenger total")
	check(totals.income == game.passenger_revenue.total() and totals.cost == game.total_operating_cost and totals.cost > 0, "receipts and charged passenger costs reconcile")
	check(totals.transfers == 0, "direct journeys do not create interchange credits")
	check(game._is_valid_save(game._save_snapshot()), "measured save validates")
	# Additional service expense hook and group totals, independent of first train.
	var purchase: Dictionary = game.buy_fleet_train("passenger_standard")
	var result: String = game.start_passenger_service(purchase.id, "c", "b")
	check(result.contains("started"), "independent passenger service starts")
	var extra: String = game.Fleet.find(game.fleet, purchase.id).service
	for index in range(120):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
	var extra_totals: Dictionary = game.service_performance.totals([extra])
	check(extra_totals.cost > 0 and game.service_performance.totals(["passenger", extra]).cost == game.total_operating_cost, "additional-service costs combine exactly once")
	# A connecting passenger leaves the feeder and remains unpaid until C.
	var manifest := {"c": 3}
	game.journey_ledger.ensure("passenger", manifest, game.sim_clock.tick)
	var income_before: int = game.passenger_revenue.total()
	check(game._transfer_passengers("passenger", "b", manifest) == 3 and manifest.is_empty(), "interchange uses actual alighting groups")
	check(game.service_performance.totals(["passenger"]).transfers == 3 and game.passenger_revenue.total() == income_before, "feeder interchange is not a final journey or fare")
	# A fresh tracked final manifest exercises the additional-service final hook.
	var final_manifest := {"c": 3}
	check(game._finish_passengers(extra, "c", final_manifest) == 3, "additional service completes final destinations")
	check(game.service_performance.totals([extra]).finals >= 3 and game.service_performance.totals([extra]).income >= 15, "last carrier receives finals and actual fare")
	game.object_pins = {"train:1": true, "service:" + extra: true, "station:a": true}
	check(game._save_game(1), "save company and mixed-type watchlist")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(1)))
	var saved_metrics: Dictionary = game.service_performance.save_state(game.services)
	check(saved.version == 52 and Pins.valid(saved.watchlist, Pins.keys(saved)), "version 52 validates pins against saved entities")
	game.object_pins = {"industry:forest": true}
	game.service_performance.record("passenger", "cost", 1)
	check(game._load_slot(1) and game.object_pins == saved.watchlist and game.service_performance.save_state(game.services) == saved_metrics, "load restores exact counters and this company's pins")
	game.object_pins = {"industry:forest": true}
	check(game._save_game(2) and game._load_slot(1) and game.object_pins == saved.watchlist, "slots keep distinct pin sets")
	check(game._load_slot(2) and game.object_pins == {"industry:forest": true}, "second slot restores its own pins")
	var old: Dictionary = saved.duplicate(true)
	old.version = 43
	old.erase("watchlist")
	old.erase("service_performance")
	var migrated: Dictionary = game.SaveMigrations.migrate(old).data
	check(game._is_valid_save(migrated) and migrated.watchlist.is_empty() and migrated.service_performance.since == old.sim.clock.tick and migrated.service_performance.services.is_empty(), "v43 migration starts honest empty counters and pins")
	check(migrated.state == old.state and migrated.sim == old.sim and migrated.journeys == old.journeys, "migration preserves finances, positions, RNG, commands and passengers")
	for corrupt in ["pin", "counter", "income", "baseline", "service"]:
		var bad := saved.duplicate(true)
		match corrupt:
			"pin": bad.watchlist["train:999999"] = true
			"counter": bad.service_performance.services.passenger.finals = -1
			"income": bad.service_performance.services.passenger.income = 100000000
			"baseline": bad.service_performance.since = bad.sim.clock.tick + 1
			"service": bad.service_performance.services["freight"] = {"finals": 0, "transfers": 0, "income": 0, "cost": 0}
		var live: Dictionary = game.service_performance.save_state(game.services)
		var pins: Dictionary = game.object_pins.duplicate(true)
		var path := "user://damaged-card.json"
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(bad))
		file.close()
		check(not game._load_game(path) and game.service_performance.save_state(game.services) == live and game.object_pins == pins, "damaged %s rejected atomically" % corrupt)
	# UI reads data without changing gameplay, provides routes and keeps no-data explicit.
	game.services[extra]["link"] = "passenger"
	game.passenger_occupancy.reset()
	game.passenger_occupancy.sample(game.sim_clock.tick, [{"id": 1, "capacity": 10, "passengers": 5}, {"id": int(purchase.id), "capacity": 20, "passengers": 10}])
	game.open_service_cards(extra)
	check(game.service_cards.selected == "passenger" and game.service_cards.members().size() == 2, "linked child selects source card and aggregates both members")
	check(text_of(game.service_cards).contains("50.0% of measured seat-time occupied"), "group occupancy weights seat-time rather than averaging trains")
	var combined: Dictionary = game.service_performance.totals(["passenger", extra])
	check(text_of(game.service_cards).contains("Fares £%d" % combined.income), "linked card displays exact combined receipts")
	game.service_cards.hide()
	game.services[extra].erase("link")
	var physical: Vector2 = game.train_position
	var money_before: int = game.money
	game.open_service_cards("passenger")
	check(game.service_cards.visible and game._modal_open() and game.paused, "cards pause and own map input")
	check(text_of(game.service_cards).contains("final journeys completed") and text_of(game.service_cards).contains("Latest 128 targeted"), "cards state outcomes and history scope")
	game.service_cards._pin()
	check(game.object_pins.has("service:passenger"), "card can pin stable service identity")
	game.service_cards._locate()
	check(not game.service_cards.visible and game.inspection_panel.selected_service == "passenger", "card locates and highlights applied route")
	game.open_service_cards("freight")
	check(text_of(game.service_cards).contains("Cargo delivered at the terminal") and not text_of(game.service_cards).contains("seat-time"), "freight card uses cargo and company lifetime finance, not passenger measures")
	game.service_cards.hide()
	check(game.train_position == physical and game.money == money_before, "browsing and pinning never move trains or alter money")
	game.GameSettings.ui_scale = 2.0
	game._apply_settings()
	game.open_service_cards("passenger")
	for frame in range(4): await process_frame
	check(float(game.service_cards.size.y) <= game.get_viewport_rect().size.y and Rect2(Vector2.ZERO, Vector2(game.service_cards.size)).encloses(game.service_cards.get_ok_button().get_global_rect()), "cards and locate button fit 200% logical viewport")
	game.service_cards.hide()
	game.GameSettings.ui_scale = 1.0
	game._apply_settings()
	# Stale preferences disappear before saving rather than crossing to reused IDs.
	game.object_pins["train:999999"] = true
	check(not game.saved_watchlist().has("train:999999"), "deleted objects are pruned before save")
	var metrics := Metrics.new()
	metrics.record("passenger", "finals", 2)
	metrics.record("passenger", "income", 10)
	metrics.record("passenger", "cost", 3)
	metrics.record("passenger_9", "cost", 4)
	check(metrics.totals(["passenger", "passenger_9"]).cost == 7 and not metrics.save_state({"passenger": {}}).services.has("passenger_9"), "group sums preserve identity and removed rows are omitted")
	var restored := Metrics.new()
	restored.restore_state(JSON.parse_string(JSON.stringify(metrics.save_state({"passenger": {}}))))
	check(restored.totals(["passenger"]) == metrics.totals(["passenger"]), "counter JSON roundtrip preserves integers")
	game.queue_free()
	await process_frame
	var empty = load("res://scenes/dev/city_preview.tscn").instantiate()
	empty.startup_allow_cli = false
	root.add_child(empty)
	empty.set_process(false)
	empty.open_service_cards()
	check(empty.service_cards.choice.item_count == 0 and empty.service_cards.get_ok_button().disabled and text_of(empty.service_cards).contains("No services yet"), "empty city company offers guidance and disables unavailable route actions")
	check(empty.object_pins.is_empty() and empty.service_performance.state.services.is_empty(), "new company inherits no pins or counters")
	empty.queue_free()
	await process_frame
	print("Service performance and watchlists: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
