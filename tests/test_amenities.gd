extends SceneTree
## Station amenities: rules, demand bonus, UI purchase, save v26 and migration.
const Amenities = preload("res://scripts/core/amenities.gd")
const Migrations = preload("res://scripts/core/save_migrations.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var a := Amenities.new()
	check(a.queue_limit("a") == 100 and a.demand_bonus("a") == 0, "stations start with the base limit and no bonus")
	var plain := 0
	for _i in range(10): plain += a.arrivals("a", 3)
	check(plain == 30, "no amenities generates exactly the batch")
	check(a.refusal("a", "waiting_room", 9999).contains("shelter"), "waiting room needs a shelter")
	check(a.refusal("a", "shelter", 10) != "" and a.buy("a", "shelter", 10) == -1 and a.owned.a.is_empty(), "too little money buys nothing")
	check(a.buy("a", "shelter", 1000) == 300 and a.queue_limit("a") == 150 and a.demand_bonus("a") == 5, "shelter adds 50 queue and 5%")
	check(a.buy("a", "shelter", 1000) == -1, "an amenity cannot be bought twice")
	check(a.buy("a", "waiting_room", 1000) == 700 and a.buy("a", "kiosk", 1000) == 400, "waiting room and kiosk can follow")
	check(a.queue_limit("a") == 275 and a.demand_bonus("a") == 25, "effects add up per station")
	check(a.queue_limit("b") == 100 and a.demand_bonus("b") == 0, "other stations are unaffected")
	var total := 0
	for _i in range(100): total += a.arrivals("a", 3)
	check(total == 375, "25%% bonus gives 375 arrivals over 100 batches of 3 (got %d)" % total)
	check(Amenities.valid_save(a.to_save()) and Amenities.valid_save(Amenities.default_save()), "valid saves accepted")
	var bad := a.to_save()
	bad.owned.b = ["waiting_room"]
	check(not Amenities.valid_save(bad), "waiting room without shelter rejected")
	bad = a.to_save()
	bad.owned.b = ["shelter", "shelter"]
	check(not Amenities.valid_save(bad), "duplicate amenity rejected")
	bad = a.to_save()
	bad.carry.c = 150
	check(not Amenities.valid_save(bad), "carry out of range rejected")
	bad = a.to_save()
	bad.owned.c = ["fountain"]
	check(not Amenities.valid_save(bad) and not Amenities.valid_save(null), "unknown amenity or missing block rejected")
	var old := Migrations.migrate({"version": 25, "demand": {}})
	check(old.ok and old.data.version == Migrations.CURRENT_VERSION and old.data.amenities == Amenities.default_save(), "version 25 migrates with no amenities")

	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	game.money = 5000
	game.selected_station = game.STATION_A
	game.station_panel.show()
	game._update_station_inspector()
	check(game.amenity_buttons.shelter.visible and not game.amenity_buttons.shelter.disabled, "shelter button available when paused")
	check(game.amenity_buttons.waiting_room.disabled, "waiting room button locked until shelter")
	game._buy_amenity("shelter")
	check(game.money == 4700 and game.amenities.has("a", "shelter") and game._destination_queue_text("a").contains("/ 150"), "purchase charges money and raises shown limit")
	game.paused = false
	game._buy_amenity("kiosk")
	check(game.money == 4700 and not game.amenities.has("a", "kiosk"), "cannot build while running")
	game.paused = true
	game.passenger_demand.reset_total("a", 120)
	game.passenger_timer = 0.0
	game._generate_passengers(game.PASSENGER_INTERVAL)
	check(game.passenger_demand.waiting("a") > 120, "queue above the old 100 limit keeps filling")
	game.passenger_demand.reset_total("a", 8)
	game.amenities.carry.a = 40
	check(game._save_game(2), "save with amenities")
	game.amenities.reset()
	game.money = 1
	check(game._load_slot(2), "load")
	check(game.amenities.has("a", "shelter") and game.amenities.carry.a == 40 and game.money == 4700, "amenities and carry survive load")
	# Loading closes stale inspection windows; reopen the freight site as a player does.
	game._inspect_station_at(game.FOREST_SITE)
	game._update_station_inspector()
	check(not game.amenity_buttons.shelter.visible, "amenity buttons hidden at freight sites")
	print("Amenities: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
