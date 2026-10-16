extends SceneTree
## Build and demolish go through the command queue while the game runs.
## Run: godot --headless --path . --script res://tests/test_command_wiring.gd

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
	game.money = 5000

	# Running game: the edit waits for the next simulation step.
	game.paused = false
	var before_tracks: Dictionary = game.tracks.duplicate()
	game.draw_track_mode = false
	game.drag_start = game.STATION_A
	game.is_dragging = true
	game._finish_track_drag(Vector2i(10, 12))
	check(game.tracks == before_tracks, "a running build must not change tracks immediately")
	check(game.command_queue.count() == 1, "a running build is queued")
	check(game.money == 5000, "money is untouched until the command runs")

	game._run_due_commands()
	check(game.tracks == before_tracks, "the command is not due in the same tick")

	game.sim_clock.begin_tick()
	game._run_due_commands()
	check(game.tracks.size() > before_tracks.size(), "the build runs at the start of the next step")
	check(game.money < 5000, "construction cost is charged when it runs")
	check(game.command_queue.is_empty(), "the queue is empty afterwards")

	# Running demolition is queued the same way, using a track tile just built.
	var target: Vector2i = Vector2i(-1, -1)

	for cell in game.tracks:
		if game._can_demolish(cell):
			target = cell
			break

	check(target != Vector2i(-1, -1), "the build left a demolishable tile")
	var built: Dictionary = game.tracks.duplicate()
	game.demolition_cells = {target: true}
	game.demolition_last_cell = target
	game._finish_demolition(target)
	check(game.tracks == built, "a running demolition must not change tracks immediately")
	check(game.command_queue.count() == 1, "a running demolition is queued")
	game.sim_clock.begin_tick()
	game._run_due_commands()
	check(not game.tracks.has(target), "the demolition runs at the start of the next step")

	# Saving executes anything still waiting, so no command is lost.
	game._save_game()
	check(game.command_queue.is_empty(), "saving leaves no pending commands")

	# Paused edits still run at once.
	game.command_queue.clear()
	game.paused = true
	var paused_before: Dictionary = game.tracks.duplicate()
	game.draw_track_mode = false
	game.drag_start = game.STATION_A
	game.is_dragging = true
	game._finish_track_drag(Vector2i(12, 14))
	check(game.command_queue.is_empty(), "a paused build does not use the queue")
	check(game.tracks != paused_before, "a paused build applies immediately")

	game.queue_free()
	await process_frame
	print("Command wiring tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
