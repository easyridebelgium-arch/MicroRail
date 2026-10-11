extends SceneTree
## Switch tiles in saves, validation and route-driven switch settings.
## Run: godot --headless --path . --script res://tests/test_switch_save.gd

const Migrations = preload("res://scripts/core/save_migrations.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1

	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _read_save(game) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))


func _run() -> void:
	var scene: PackedScene = load("res://scenes/main/main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true

	# Passenger line A to B with a switch in the middle (stem west, through east).
	for x in range(4, 21):
		game.tracks[Vector2i(x, 8)] = false

	game.tracks[Vector2i(10, 8)] = "junction_6_2_3"
	game._check_route()
	check(game.route_connected, "a route runs straight through the switch")
	check(game.switch_states.get(Vector2i(10, 8)) == 0, "the route sets the switch to through")

	# A switch no route uses keeps whatever position it was given.
	for x in range(30, 33):
		game.tracks[Vector2i(x, 15)] = false

	game.tracks[Vector2i(31, 15)] = "junction_6_2_3"
	game._check_route(true)
	game.switch_states[Vector2i(31, 15)] = 1
	game._check_route(true)
	check(game.switch_states.get(Vector2i(31, 15)) == 1, "an unused switch keeps its position")

	game._save_game()
	var saved: Dictionary = _read_save(game)
	check(int(saved["version"]) == Migrations.CURRENT_VERSION, "save has the current version")
	check(saved["switches"].size() == 2, "both switches are saved (got %d)" % saved["switches"].size())
	check(game._is_valid_save(saved.duplicate(true)), "a save with switches is valid")

	game.switch_states[Vector2i(31, 15)] = 0
	game._load_game()
	check(game.tracks.get(Vector2i(31, 15)) == "junction_6_2_3", "switch tiles load")
	check(game.switch_states.get(Vector2i(31, 15)) == 1, "switch position loads")

	# Damaged switch lists are rejected before anything changes.
	var bad_state: Dictionary = saved.duplicate(true)
	bad_state["switches"] = [[31, 15, 2]]
	check(not game._is_valid_save(bad_state), "state other than 0 or 1 is rejected")

	var not_a_switch: Dictionary = saved.duplicate(true)
	not_a_switch["switches"] = [[30, 15, 0]]
	check(not game._is_valid_save(not_a_switch), "a switch entry on a plain tile is rejected")

	var duplicate: Dictionary = saved.duplicate(true)
	duplicate["switches"] = [[31, 15, 0], [31, 15, 1]]
	check(not game._is_valid_save(duplicate), "a duplicated switch entry is rejected")

	var missing: Dictionary = saved.duplicate(true)
	missing.erase("switches")
	check(not game._is_valid_save(missing), "a missing switch list is rejected")

	var fractional: Dictionary = saved.duplicate(true)
	fractional["switches"] = [[31.5, 15, 0]]
	check(not game._is_valid_save(fractional), "a fractional position is rejected")

	# A version 17 save (no switch list) upgrades.
	var old: Dictionary = saved.duplicate(true)
	old["version"] = 17
	old.erase("switches")
	var migrated: Dictionary = Migrations.migrate(old)
	check(migrated["ok"] and migrated["data"]["switches"] == [], "version 17 upgrades with an empty switch list")

	game.queue_free()
	await process_frame
	print("Switch save tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
