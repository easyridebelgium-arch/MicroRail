extends SceneTree

const Migrations = preload("res://scripts/core/save_migrations.gd")
const Fleet = preload("res://scripts/fleet.gd")
const Actions = preload("res://scripts/core/input_actions.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func write_save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t", true, true))
	file.close()

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main/main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	game.money = 10000
	game.selected_station = game.STATION_A
	game._upgrade_capacity()
	game._upgrade_speed()
	game._upgrade_freight_capacity()
	game._upgrade_freight_speed()
	for x in range(4, 21):
		game.tracks[Vector2i(x, 8)] = false
	for x in range(8, 29):
		game.tracks[Vector2i(x, 24)] = false
	game._check_route()
	game.sim_rng.set_seed(42)
	game.sim_rng.randi()
	game._save_game()
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	check(int(base["version"]) == 16 and base.has("sim") and base.has("fleet"), "Combined save must have one v16 schema with fleet and simulation blocks")
	var expected_random: int = game.sim_rng.randi()
	game._load_game()
	check(game.sim_rng.randi() == expected_random, "Merged save must continue the exact RNG stream")
	# All three pre-merge formats must load without dropping upgrades or data.
	for format in ["routes14", "fleet15", "sim15"]:
		var old: Dictionary = base.duplicate(true)
		old["version"] = 14 if format == "routes14" else 15
		if format != "fleet15":
			old.erase("fleet")
			old["state"].erase("total_vehicle_cost")
		if format != "sim15":
			old.erase("sim")
		var original: Dictionary = old.duplicate(true)
		var migration: Dictionary = Migrations.migrate(old)
		check(migration["ok"] and old == original, "Migration must not mutate its input: " + format)
		write_save("user://legacy_merge_test.json", old)
		game.money = -1
		game._load_game("user://legacy_merge_test.json")
		check(game.money == int(base["state"]["money"]) and "Upgraded" in game.notice, "Actual game load must accept supported legacy format: " + format)
		check(game._get_train_capacity() == 30 and game._get_train_speed() == 100.0 and game.freight_train.get_capacity() == 30 and game.freight_train.get_speed() == 80.0, "Legacy upgrades must survive migration: " + format)
		check(game.total_vehicle_cost == 1000, "Migration must preserve/reconstruct purchased upgrade accounting: " + format)
		if format == "sim15":
			check(game.sim_rng.randi() == expected_random, "Simulation-only v15 must preserve its existing RNG state")
	# Fleet-only v15 must preserve custom names, ownership and a loaded heavy train.
	var bought: Dictionary = game.buy_fleet_train("freight_heavy")
	game.assign_fleet_train(bought["id"], "freight")
	game.rename_fleet_train(bought["id"], "Merged Heavy")
	game.freight_train.cargo = 40
	game._save_game()
	var heavy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	heavy["version"] = 15
	heavy.erase("sim")
	write_save("user://legacy_merge_test.json", heavy)
	game.freight_train.cargo = 0
	game._load_game("user://legacy_merge_test.json")
	check(game.freight_train.cargo == 40 and Fleet.assigned(game.fleet, "freight")["name"] == "Merged Heavy", "Fleet v15 migration must retain purchased heavy model, custom name and cargo")
	# Current-format corrupt data must fail without defaults hiding the problem.
	var broken: Dictionary = base.duplicate(true)
	broken.erase("sim")
	write_save("user://invalid_merge_test.json", broken)
	var before_fleet: Dictionary = game.fleet.duplicate(true)
	var before_clock: Dictionary = game.sim_clock.save_state()
	game._load_game("user://invalid_merge_test.json")
	check(game.fleet == before_fleet and game.sim_clock.save_state() == before_clock and game.freight_train.cargo == 40, "Missing current-schema data must be rejected atomically")
	# Check real _process, not just the standalone clock: exactly one simulation loop.
	write_save("user://baseline_merge_test.json", base)
	var outcomes: Array[Dictionary] = []
	for fps in [30, 60, 120]:
		game._load_game("user://baseline_merge_test.json")
		game.sim_clock.reset()
		game.passenger_timer = 0.0
		game.log_production_timer = 0.0
		game.paused = false
		for frame in range(fps * 2):
			game._process(1.0 / float(fps))
		check(game.sim_clock.tick == 120 and absf(game.passenger_timer - 2.0) < 0.00001, "Simulation must run once for two seconds at %d FPS" % fps)
		check(absf(game.route_distance - 200.0) < 0.001, "Passenger movement must advance once per tick at %d FPS" % fps)
		outcomes.append({"timer": game.passenger_timer, "log_timer": game.log_production_timer, "money": game.money, "waiting": game.waiting_at_a, "distance": game.route_distance})
	check(outcomes[0] == outcomes[1] and outcomes[1] == outcomes[2], "Frame rate must not change the merged simulation result")
	# Rebinding must supersede old hard-coded shortcuts.
	Actions.apply_bindings({"toggle_map": [KEY_N]})
	var map_visible: bool = game.network_map.visible
	game._unhandled_input(key(KEY_M))
	check(game.network_map.visible == map_visible, "Old M shortcut must stop working after rebinding")
	game._unhandled_input(key(KEY_N))
	check(game.network_map.visible != map_visible, "New map binding must toggle exactly once")
	for dialog in [game.route_editor, game.fleet_editor, game.settings_dialog]:
		game.paused = true
		dialog.show()
		game._unhandled_input(key(KEY_SPACE))
		game._unhandled_input(key(KEY_N))
		check(game.paused and game.network_map.visible != map_visible, "Every management dialog must suppress game shortcuts")
		dialog.hide()
	Actions.apply_bindings(Actions.default_bindings())
	game.queue_free()
	await process_frame
	print("Merge integration tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
