extends SceneTree
const Revenue = preload("res://scripts/core/passenger_revenue.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const Classes = preload("res://scripts/core/passenger_classes.gd")
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
func fixture() -> Node:
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.paused = true
	game.money = 100000
	for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	for station in game.PassengerDemand.STATIONS: game.passenger_demand.reset_total(station, 0)
	return game
func advance(game: Node, key: String = "passenger") -> void:
	game.sim_clock.begin_tick()
	game._refresh_directional_routes()
	game._rebuild_reservations(true)
	if key == "passenger": game._move_train(1.0 / 60.0)
	else: game.passenger_services[key].advance(game, 1.0 / 60.0)
func run() -> void:
	var revenue := Revenue.new()
	check(revenue.record({"local": 3, "express": 2}) == 35 and revenue.total() == 35, "mixed class receipts use £5/£10")
	check(Revenue.valid_save(revenue.save_state(), 5), "class counts reconcile with delivered total")
	var restored := Revenue.new()
	restored.restore_state(JSON.parse_string(JSON.stringify(revenue.save_state())))
	check(restored.save_state() == revenue.save_state(), "JSON restores exact integer receipts")
	for field in ["passengers", "income"]:
		var bad: Dictionary = revenue.save_state()
		bad.express[field] = -1
		check(not Revenue.valid_save(bad, 5), "negative %s rejected" % field)
	var bad: Dictionary = revenue.save_state()
	bad.express.income = 10
	check(not Revenue.valid_save(bad, 5), "understated Express income rejected")
	bad = revenue.save_state()
	bad.local.passengers = 3.5
	check(not Revenue.valid_save(bad, 5), "fractional deliveries rejected")
	check(not Revenue.valid_save(revenue.save_state(), 6), "inconsistent delivered count rejected")
	var old := Migrations.migrate({"version": 35, "state": {"passengers_delivered": 12}})
	check(old.ok and old.data.passenger_revenue.legacy == {"passengers": 12, "income": 60} and old.data.passenger_revenue.express.income == 0, "legacy flat fares migrate without invented premiums")
	root.size = Vector2i(1280, 720)
	var game := fixture()
	var config: Dictionary = game.services.duplicate(true)
	config.passenger.stops = ["a", "c"]
	game.apply_service_routes(config)
	game.passenger_demand.generate("a", 4, 100, LastChoice.new(), 0, true)
	var cash: int = game.money
	for i in range(150): advance(game)
	check(game.passengers_on_train == 4 and game.money == cash and game.passenger_revenue.total() == 0, "boarding and incomplete travel do not credit income")
	check(game._save_game(4), "unpaid mixed journey saves")
	var position: Vector2 = game.train_position
	check(game._load_slot(4) and game.train_position == position and game.passenger_revenue.total() == 0, "mid-trip load cannot pay early")
	for i in range(1000):
		advance(game)
		if game.passenger_stop_index == 1: break
	check(game.passengers_delivered == 4 and game.money == cash + 25 and game.passenger_revenue.total() == 25, "real direct trip pays mixed fare once at final destination")
	check(game.passenger_revenue.state.local.passengers == 3 and game.passenger_revenue.state.express.passengers == 1, "receipt class counts match completed journey")
	check(game._finish_passengers("passenger", "c", game.passenger_destinations) == 0 and game.money == cash + 25 and game.passenger_revenue.total() == 25, "repeat arrival cannot double-credit receipts")
	game.total_operating_cost = 3
	game.freight_income = 20
	game.freight_operating_cost = 2
	game.header_controls.refresh()
	check(game.header_controls.profit.text == "Operating profit £40", "profit uses actual £25 receipts rather than four flat fares")
	game.header_controls.open_accounts()
	check(game.header_controls.accounts_text.text.contains("Express: 1 passengers, £10") and game.header_controls.accounts_text.text.contains("Passenger fares: £25"), "Accounts reconciles class receipts and headline fares")
	game.header_controls.accounts_dialog.hide()
	check(game._save_game(4) and game._load_slot(4) and game.passenger_revenue.total() == 25 and game.money == cash + 25, "paid receipts persist without crediting balance twice")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(4)))
	bad = payload.duplicate(true)
	bad.passenger_revenue.express.income += 5
	var file := FileAccess.open(game.SaveSlots.path(4), FileAccess.WRITE)
	file.store_string(JSON.stringify(bad))
	file.close()
	position = game.train_position
	check(not game._load_slot(4) and game.passenger_revenue.total() == 25 and game.train_position == position and game.money == cash + 25, "invalid revenue load is atomic")
	payload.version = 35
	payload.erase("passenger_revenue")
	old = Migrations.migrate(payload)
	check(old.ok and game._is_valid_save(old.data) and old.data.passenger_revenue.legacy.income == 20 and old.data.state.money == payload.state.money and old.data.journeys == payload.journeys, "v35 migration honors old flat fares even when recent journey records include Express")
	game.header_controls.open_accounts()
	var scale: float = game.GameSettings.ui_scale
	for ui_scale in [1.0, 1.5, 2.0]:
		game.GameSettings.ui_scale = ui_scale
		game._apply_settings()
		game.header_controls.open_accounts()
		await process_frame
		check(float(game.header_controls.accounts_dialog.size.y) <= game.get_viewport_rect().size.y + 1, "receipt breakdown fits at %d%%" % int(ui_scale * 100))
		game.header_controls.accounts_dialog.hide()
	game.GameSettings.ui_scale = scale
	game._apply_settings()
	game.queue_free()
	await process_frame
	# A real extra service delivers mixed classes via a bypass around held train B.
	game = fixture()
	for i in range(500):
		advance(game)
		if game.passenger_stop_index == 1: break
	game.passenger_held = true
	game.tracks[Vector2i(16, 8)] = "junction_6_2_4"
	game.tracks[Vector2i(24, 8)] = "junction_2_6_4"
	for y in range(9, 11):
		game.tracks[Vector2i(16, y)] = true
		game.tracks[Vector2i(24, y)] = true
	game.tracks[Vector2i(16, 11)] = Geometry.from_ports(Vector2i.UP, Vector2i.RIGHT)
	game.tracks[Vector2i(24, 11)] = Geometry.from_ports(Vector2i.UP, Vector2i.LEFT)
	for x in range(17, 24): game.tracks[Vector2i(x, 11)] = false
	var purchase: Dictionary = game.buy_fleet_train("passenger_fast")
	game.start_passenger_service(int(purchase.id), "c")
	var key: String = game.Fleet.find(game.fleet, int(purchase.id)).service
	config = game.services.duplicate(true)
	config[key].stops = ["c", "a"]
	config[key].waypoints = {"c>a": [[20, 11]]}
	check(game.apply_service_routes(config).begins_with("Routes applied"), "independent direct bypass service applies")
	game.passenger_demand.generate("c", 4, 100, FirstChoice.new(), game.sim_clock.tick, true)
	cash = game.money + game.total_operating_cost
	for i in range(1500):
		advance(game, key)
		if game.passenger_services[key].stop_index == 1: break
	check(game.passengers_delivered == 4 and game.passenger_revenue.total() == 25 and game.money + game.total_operating_cost == cash + 25, "extra service also credits actual mixed-class fare and keeps operating costs separate")
	game.queue_free()
	await process_frame
	print("Passenger revenue: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
