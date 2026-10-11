extends SceneTree

const Fleet = preload("res://scripts/fleet.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _write_save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t", true, true))
	file.close()

func _run() -> void:
	check(Fleet.is_valid(Fleet.defaults()), "The starting fleet must validate")
	for bad_key in ["id", "capacity_level", "speed_level"]:
		var bad: Dictionary = Fleet.defaults()
		bad["trains"][0][bad_key] = 0.5
		check(not Fleet.is_valid(bad), "Fractional identifiers and upgrade levels must be rejected")
	var duplicate: Dictionary = Fleet.defaults()
	duplicate["trains"][1]["id"] = 1
	check(not Fleet.is_valid(duplicate), "Duplicate train identities must be rejected")
	var wrong_kind: Dictionary = Fleet.defaults()
	wrong_kind["trains"][0]["model"] = "freight_standard"
	check(not Fleet.is_valid(wrong_kind), "A freight model cannot be assigned to passenger service")
	var missing_assignment: Dictionary = Fleet.defaults()
	missing_assignment["trains"][0]["service"] = ""
	check(not Fleet.is_valid(missing_assignment), "Each current service must have exactly one train")
	var duplicate_assignment: Dictionary = Fleet.defaults()
	duplicate_assignment["trains"].append(Fleet.make_train(3, "passenger_standard", "passenger"))
	duplicate_assignment["next_id"] = 4
	check(not Fleet.is_valid(duplicate_assignment), "Two trains cannot occupy one service")
	var bad_model: Dictionary = Fleet.defaults()
	bad_model["trains"][0]["model"] = "missing_model"
	check(not Fleet.is_valid(bad_model), "Unknown train models must be rejected")
	for bad_name in ["", "\n", " padded ", "x".repeat(41)]:
		check(not Fleet.valid_name(bad_name), "Invalid individual train names must be rejected")
	var scene: PackedScene = load("res://scenes/main/main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	game.money = 5000
	check(game._get_train_capacity() == 20 and game._get_train_speed() == 80.0, "Starting passenger model must preserve previous gameplay")
	check(game.freight_train.get_capacity() == 20 and game.freight_train.get_speed() == 60.0, "Starting freight model must preserve previous gameplay")
	var starting_fleet: Dictionary = game.fleet.duplicate(true)
	game.money = 1
	check(not game.buy_fleet_train("passenger_fast")["ok"], "Unaffordable purchases must be refused")
	check(game.money == 1 and game.fleet == starting_fleet, "Failed purchase must not charge money or consume an ID")
	game.money = 5000
	game.paused = false
	check(not game.buy_fleet_train("passenger_fast")["ok"], "Fleet purchases require pause")
	game.paused = true
	# Buy via the actual fleet UI.
	game._open_fleet_editor()
	await process_frame
	var editor = game.fleet_editor
	check(editor.visible and game.paused, "Fleet window opens with the game paused")
	check(editor.size.x <= 1280 and editor.size.y <= 720 and game.fleet_button.get_global_rect().end.x <= 1280, "Fleet window and toolbar button must fit the standard viewport")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	var zoom_before: Vector2 = game.camera.zoom
	game._input(wheel)
	var space := InputEventKey.new()
	space.pressed = true
	space.keycode = KEY_SPACE
	game._unhandled_input(space)
	check(game.camera.zoom == zoom_before and game.paused, "Fleet interaction must not pan, zoom or resume the underlying game")
	editor.model_choice.select(1)
	editor.model_choice.item_selected.emit(1)
	editor.buy_button.pressed.emit()
	var fast_id: int = editor.selected_id
	check(game.fleet["trains"].size() == 3 and game.money == 4350, "Buying a fast passenger model must charge exactly its listed price")
	check(Fleet.find(game.fleet, fast_id)["service"] == "" and Fleet.assigned(game.fleet, "passenger")["id"] == 1, "A purchased train must be stored without replacing the running train")
	editor.name_field.text = "  Belgian Express  "
	editor.rename_button.pressed.emit()
	check(Fleet.find(game.fleet, fast_id)["name"] == "Belgian Express", "Individual names must persist after trimming whitespace")
	game.assign_fleet_train(fast_id, "freight")
	check(Fleet.assigned(game.fleet, "freight")["id"] == 2, "Wrong cargo type must not replace a service train")
	# Upgrade the original, swap it out, then verify the upgrade stays with it.
	game.selected_station = game.STATION_A
	game._upgrade_capacity()
	game._upgrade_speed()
	check(Fleet.find(game.fleet, 1)["capacity_level"] == 1 and Fleet.find(game.fleet, 1)["speed_level"] == 1, "Purchases must attach upgrades to the assigned vehicle")
	editor.assign_button.pressed.emit()
	check(Fleet.assigned(game.fleet, "passenger")["id"] == fast_id and Fleet.find(game.fleet, 1)["service"] == "", "Assigning a stored train must store the old train and retain exactly one assignment")
	check(game._get_train_capacity() == 12 and game._get_train_speed() == 120.0, "The fast model must use its own capacity and speed without inheriting old upgrades")
	game.assign_fleet_train(1, "passenger")
	check(game._get_train_capacity() == 30 and game._get_train_speed() == 100.0, "Reassigning the original train must restore its upgrades")
	game.assign_fleet_train(fast_id, "passenger")
	check(Fleet.is_valid(game.fleet), "Repeated assignments must keep the fleet valid")
	var before_sale: int = game.money
	var assigned_count: int = game.fleet["trains"].size()
	game.sell_fleet_train(fast_id)
	check(game.money == before_sale and game.fleet["trains"].size() == assigned_count, "Selling an assigned train must be refused")
	# Passenger route movement and safe withdrawal before replacement.
	editor.hide()
	for x in range(4, 21):
		game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	game.waiting_at_a = 30
	game._move_train(1.0)
	check(game.passengers_on_train == 12 and absf(game.route_distance - 120.0) < 0.1, "Fast model must actually board and move with its own specifications")
	game.operating_timer = 0.0
	var before_cost: int = game.money
	game._charge_operating_cost(1.0)
	check(game.money == before_cost - 2, "Fast passenger running costs must match the model")
	var journey_position: Vector2 = game.train_position
	game.assign_fleet_train(1, "passenger")
	check(Fleet.assigned(game.fleet, "passenger")["id"] == fast_id and game.train_position == journey_position and game.passengers_on_train == 12, "Mid-journey replacement must preserve train, position and passengers")
	game.toggle_fleet_service(fast_id)
	for step in range(400):
		if game._passenger_service_is_active():
			game._move_train(0.1)
	check(not game._passenger_service_is_active() and game.passengers_on_train == 0, "Withdrawal must finish deliveries and park empty at the first stop")
	game.assign_fleet_train(1, "passenger")
	check(Fleet.assigned(game.fleet, "passenger")["id"] == 1 and game.passenger_service_enabled, "A returned train can be replaced and the new train is enabled")
	# Heavy freight can carry more than the old fixed capacity, including after load.
	var purchase: Dictionary = game.buy_fleet_train("freight_heavy")
	var heavy_id: int = int(purchase["id"])
	game.assign_fleet_train(heavy_id, "freight")
	check(game.freight_train.get_capacity() == 40 and game.freight_train.get_speed() == 40.0, "Heavy freight must use its capacity/speed trade-off")
	for x in range(8, 29):
		game.tracks[Vector2i(x, 24)] = false
	game._check_route()
	game.forest_stock = 60
	game.logs_produced = 60
	before_cost = game.money
	game.forest_stock -= game.freight_train.advance(1.0, game.forest_stock)
	check(game.freight_train.cargo == 40 and game.forest_stock == 20, "Heavy model must load forty logs without loss")
	check(absf(game.freight_train.distance_along_route - 40.0) < 0.1 and game.money == before_cost - 2, "Heavy freight movement and costs must match its model")
	game.assign_fleet_train(2, "freight")
	check(Fleet.assigned(game.fleet, "freight")["id"] == heavy_id and game.freight_train.cargo == 40, "Loaded freight cannot be swapped or lose cargo")
	game._save_game()
	var saved_fleet: Dictionary = game.fleet.duplicate(true)
	var saved_money: int = game.money
	var saved_position: Vector2 = game.freight_train.position
	game.rename_fleet_train(fast_id, "Temporary name")
	game.money = 0
	game._load_game()
	check(game.fleet == saved_fleet and game.money == saved_money, "Save/load must restore IDs, names, assignments, upgrades and money")
	check(game.freight_train.cargo == 40 and game.freight_train.get_capacity() == 40 and game.freight_train.position.distance_to(saved_position) < 0.1, "Save/load must validate cargo against the assigned heavy model and restore its movement")
	# Reject inconsistent fleet data before applying any part of a save.
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	for field in ["capacity_level", "model"]:
		var invalid: Dictionary = saved.duplicate(true)
		var record: Dictionary = Fleet.assigned(invalid["fleet"], "freight")
		record[field] = 1 if field == "capacity_level" else "freight_standard"
		_write_save("user://invalid_fleet.json", invalid)
		game._load_game("user://invalid_fleet.json")
		check(game.fleet == saved_fleet and game.money == saved_money and game.freight_train.cargo == 40, "Inconsistent upgrades or over-capacity cargo must fail load atomically")
	game.toggle_fleet_service(heavy_id)
	for step in range(500):
		game.forest_stock -= game.freight_train.advance(0.1, game.forest_stock)
	check(not game.freight_train.service_is_active() and game.freight_train.cargo == 0 and game.logs_delivered == 40, "Heavy freight must deliver and withdraw without reloading")
	game.assign_fleet_train(2, "freight")
	check(Fleet.assigned(game.fleet, "freight")["id"] == 2, "An empty returned freight train can be replaced")
	# Stored trains do not run or incur expenses; selling cannot duplicate a refund.
	game.passenger_service_enabled = false
	game.freight_train.service_enabled = false
	before_cost = game.money
	var passenger_before: Vector2 = game.train_position
	var freight_before: Vector2 = game.freight_train.position
	game.paused = false
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	game._process(1.0)
	check(game.money == before_cost and game.train_position == passenger_before and game.freight_train.position == freight_before, "Stored trains and withdrawn services must not move or charge operating costs")
	game.paused = true
	var refund: int = Fleet.sale_price(Fleet.find(game.fleet, fast_id))
	var next_id: int = game.fleet["next_id"]
	game.sell_fleet_train(fast_id)
	check(game.money == before_cost + refund and Fleet.find(game.fleet, fast_id).is_empty(), "Selling a stored train must credit exactly one listed refund")
	game.sell_fleet_train(fast_id)
	check(game.money == before_cost + refund, "A sold train cannot be sold twice")
	purchase = game.buy_fleet_train("passenger_standard")
	check(int(purchase["id"]) == next_id and int(purchase["id"]) != fast_id, "Sold IDs must never be reused")
	game._save_game()
	var before_reload: Dictionary = game.fleet.duplicate(true)
	game._load_game()
	check(game.fleet == before_reload and Fleet.is_valid(game.fleet), "Fleet transactions must survive another save/load cycle")
	game.queue_free()
	await process_frame
	print("Fleet tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
