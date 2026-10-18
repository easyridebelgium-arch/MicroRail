extends SceneTree
## The Switch tool: placing, cycling, removing, cost, Undo/Redo and routes.
## Run: godot --headless --path . --script res://tests/test_switch_tool.gd

const Geometry = preload("res://scripts/track_geometry.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1

	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var scene: PackedScene = load("res://scenes/main/main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	game.money = 1000

	for x in range(4, 21):
		game.tracks[Vector2i(x, 8)] = false

	game._check_route()
	check(game.route_connected, "the line starts connected")

	var cell := Vector2i(10, 8)
	game._use_switch_tool(cell)
	check(Geometry.is_switch(game.tracks[cell]), "first click places a switch")
	check(game.money == 900, "a switch costs £100 (money %d)" % game.money)
	check(game.route_connected, "the route survives the new switch")
	check(game.switch_states.get(cell) == 0, "the route sets it to through")

	game._undo_construction()
	check(game.tracks[cell] == false and game.money == 1000, "Undo removes the switch and refunds it")
	game._redo_construction()
	check(Geometry.is_switch(game.tracks[cell]) and game.money == 900, "Redo restores it")

	# Cycling through all variants and back leaves a straight, money restored.
	var kinds: Dictionary = {game.tracks[cell]: true}

	for step in range(7):
		game._use_switch_tool(cell)
		kinds[game.tracks[cell]] = true
		check(Geometry.is_switch(game.tracks[cell]) and game.money == 900, "cycling is free (step %d)" % step)

	check(kinds.size() == 8, "eight different variants were visited (got %d)" % kinds.size())
	game._use_switch_tool(cell)
	check(not Geometry.is_switch(game.tracks[cell]) and game.money == 1000, "the last click removes the switch and refunds £100")
	check(game.route_connected, "the route is still connected afterwards")

	# Things the tool must refuse.
	var before_money: int = game.money
	game._use_switch_tool(Vector2i(4, 8))
	check(game.tracks[Vector2i(4, 8)] == false and game.money == before_money, "a station platform tile cannot become a switch")
	game._use_switch_tool(Vector2i(30, 15))
	check(not game.tracks.has(Vector2i(30, 15)), "an empty tile is ignored")
	game.tracks[Vector2i(30, 15)] = "NE"
	game._use_switch_tool(Vector2i(30, 15))
	check(game.tracks[Vector2i(30, 15)] == "NE" and game.money == before_money, "a bend is refused")

	game.money = 50
	game._use_switch_tool(cell)
	check(not Geometry.is_switch(game.tracks[cell]) and game.money == 50, "not enough money: nothing changes")

	# While the game runs the change is queued for the next step.
	game.money = 1000
	game.paused = false
	game._use_switch_tool(cell)
	check(not Geometry.is_switch(game.tracks[cell]) and game.command_queue.count() == 1, "a running click is queued")
	game.sim_clock.begin_tick()
	game._run_due_commands()
	check(Geometry.is_switch(game.tracks[cell]), "the queued switch appears at the next step")

	# It saves and loads.
	game.paused = true
	game._save_game()
	game.tracks[cell] = false
	game._load_game()
	check(Geometry.is_switch(game.tracks[cell]), "the switch tile survives a save and load")

	game.queue_free()
	await process_frame
	print("Switch tool tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
