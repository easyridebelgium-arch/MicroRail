extends SceneTree
const Dispatch = preload("res://scripts/core/dispatch_order.gd")
const Routes = preload("res://scripts/service_routes.gd")
const Migrations = preload("res://scripts/core/save_migrations.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for bad in [-1, 3, 0.5, true, "High", null]: check(not Routes.valid_priority({"priority": bad}), "malformed priority rejected")
	for level in [0, 1, 2, 2.0]: check(Routes.valid_priority({"priority": level}), "listed whole priority accepted")
	check(Routes.valid_priority({}), "old services default Normal")
	var trains := [{"id": 3, "priority": 2}, {"id": 1, "priority": 0}, {"id": 2, "priority": 1}]
	var leads := {1: 0, 2: 0, 3: 0}
	for turn in range(6):
		var ranks := Dispatch.ranks(trains, turn * 600)
		for id in ranks:
			if ranks[id] == 0: leads[id] += 1
	check(leads == {1: 1, 2: 2, 3: 3}, "mixed priorities receive exactly 1/2/3 leading turns")
	check(Dispatch.cycle_ticks(trains) == 3600, "mixed cycle length is explicit")
	check(Dispatch.ranks(trains, 0) == Dispatch.ranks(trains, 3600), "weighted cycle repeats deterministically")
	check(Dispatch.describe(1, Dispatch.ranks(trains, 0), 0, 59, trains).contains("Low") and not Dispatch.describe(1, Dispatch.ranks(trains, 0), 0, 59, trains).contains("Prolonged"), "diagnostics use weighted cycle length")
	check(Dispatch.describe(1, Dispatch.ranks(trains, 0), 0, 60, trains).contains("does not prove starvation"), "full-cycle warning has no false liveness claim")
	var config := Routes.defaults()
	config.passenger.priority = 2
	config["passenger_5"] = {"name": "Linked", "stops": ["a", "b"], "link": "passenger", "priority": 0}
	check(Routes.propagate(config).passenger_5.priority == 0, "linked service retains its independent priority")
	check(Routes.copy_route(config.passenger, config.passenger_5).priority == 0, "copying route instructions does not overwrite target priority")
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	game.paused = true
	for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	for tick in range(240):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
	var position: Vector2 = game.train_position
	var distance: float = game.route_distance
	var money: int = game.money
	var passengers: int = game.passengers_on_train
	game.route_editor.open_editor()
	check(game.route_editor.priority_choice.selected == 1, "Routes shows Normal for existing services")
	game.route_editor.priority_choice.select(2)
	game.route_editor.priority_choice.item_selected.emit(2)
	check(game.services.passenger.get("priority", 1) == 1, "priority stays in draft before Apply")
	game.route_editor.hide()
	game.route_editor.open_editor()
	check(game.route_editor.priority_choice.selected == 1, "cancel/reopen discards priority draft")
	game.route_editor.priority_choice.select(2)
	game.route_editor.priority_choice.item_selected.emit(2)
	game.route_editor._apply()
	check(game.services.passenger.priority == 2, "Apply commits selected service priority")
	check(game.route_distance == distance and game.train_position == position and game.money == money and game.passengers_on_train == passengers, "priority Apply preserves mid-route position, cash and passengers")
	var invalid_configuration: Dictionary = game.services.duplicate(true)
	invalid_configuration.passenger.priority = 99
	check(game.apply_service_routes(invalid_configuration).contains("dispatch priority") and game.services.passenger.priority == 2, "invalid backend priority edit is refused atomically with an explanation")
	for index in range(game.route_editor.service_choice.item_count):
		if game.route_editor.service_choice.get_item_metadata(index) == "freight": game.route_editor._select_service(index)
	check(game.route_editor.priority_choice.visible, "freight exposes dispatch priority independently of passenger scheduling")
	game.route_editor.priority_choice.select(0)
	game.route_editor.priority_choice.item_selected.emit(0)
	game.route_editor._apply()
	check(game.services.freight.priority == 0, "freight Low priority applies through the same Routes control")
	game.route_editor.hide()
	game._rebuild_reservations(true)
	check(game.reservation_trains[1].priority == 2 and game.reservation_trains[2].priority == 0, "main scene feeds actual passenger and freight priorities into dispatch")
	game.inspect_train(1)
	check(game.train_inspector.authority.text.contains("priority at allocation: High"), "inspector explains selected priority")
	game.train_inspector.hide()
	var before_ranks: Dictionary = game.dispatch_ranks.duplicate()
	check(game._save_game(4), "priorities save")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(4)))
	check(saved.version == 49 and game._is_valid_save(saved) and game._load_slot(4) and game.services.passenger.priority == 2, "version 49 priority roundtrip validates")
	check(game.dispatch_ranks == before_ranks, "save/load reconstructs the same weighted rank at the same tick")
	var bad_save := saved.duplicate(true)
	bad_save.services.passenger.priority = 4
	check(not game._is_valid_save(bad_save), "invalid saved weight cannot enter dispatch")
	var old := saved.duplicate(true)
	old.version = 48
	for service in old.services.values(): service.erase("priority")
	var migrated: Dictionary = Migrations.migrate(old).data
	check(migrated.version == 49 and migrated.state == old.state and migrated.sim == old.sim and migrated.services == old.services, "v48 migration changes no physical state or instructions")
	check(game._load_game(game.SaveSlots.path(4)), "new priority save remains loadable after rejection checks")
	game.queue_free()
	await process_frame
	print("Service priority: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
