extends SceneTree
const Events = preload("res://scripts/core/event_log.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: _run.call_deferred()
func tick(game: Node) -> void:
	game.sim_clock.begin_tick()
	game._simulation_step(1.0 / 60.0)
func _run() -> void:
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.paused = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
	for x in range(8, 29): game.tracks[Vector2i(x, 24)] = false
	game._check_route()
	check(game.reverse_train(1).contains("already at") and not game.passenger_returning, "a train at its departure must not enter recovery")
	check(game.reverse_train(999).contains("assigned"), "unknown ID cannot reverse")
	game.fleet.trains.append(game.Fleet.make_train(3, "passenger_standard"))
	game.fleet.next_id = 4
	game.inspect_train(3)
	check(game.train_inspector.buttons.reverse.disabled, "stored train must show a disabled Reverse control")
	game.train_inspector.hide()
	game.route_distance = 256.0
	game.train_needs_boarding = false
	game.passengers_on_train = 7
	game._update_train_transform()
	game._use_signal_tool(Vector2i(14, 8))
	game._use_signal_tool(Vector2i(14, 8))
	for step in range(180): tick(game)
	check(game.train_diagnostics(1).state == "Traffic wait" and game.deadlocks.cycles.is_empty(), "fixture waits at a manual signal without confirmed deadlock")
	game.paused = false
	var before: float = game.route_distance
	check(game.reverse_train(1).contains("Pause") and game.route_distance == before, "running command rejects without movement")
	game.inspect_train(1)
	check(not game.train_inspector.buttons.reverse.disabled, "a waiting train may reverse before deadlock confirmation")
	# A separate incident must survive reversal of this train.
	game.movement_blocks[99] = 100
	game.movement_blocks[100] = 99
	game.deadlocks.update(game.movement_blocks, game.sim_clock.tick - 180)
	game.deadlocks.update(game.movement_blocks, game.sim_clock.tick)
	check(game.deadlocks.cycles == [[99, 100]], "independent wait-cycle fixture confirmed")
	var position: Vector2 = game.train_position
	var path: Curve2D = game.route_path
	var money: int = game.money
	game.train_inspector.buttons.reverse.pressed.emit()
	check(game.passenger_returning and not game.travelling_to_b, "inspector Reverse starts physical return")
	check(game.route_distance == before and game.train_position == position and game.route_path == path, "Reverse preserves physical position and retained route")
	check(game.passengers_on_train == 7 and game.money == money, "Reverse preserves riders and money")
	check(game.deadlocks.cycles == [[99, 100]] and game.event_log.query(Events.DEADLOCK_CLEARED).is_empty(), "unrelated incident is not cleared or falsely logged")
	check(game.train_inspector.visible and game.paused and game.train_inspector.command_result.text.contains("Resume"), "result explains how to resume while inspector remains paused")
	check(game.train_inspector.buttons.reverse.disabled and game.reverse_train(1).contains("already returning"), "repeat Reverse cannot flip a returning train")
	check(game.event_log.query(Events.TRAIN_REVERSED).size() == 1, "exactly one reversal event recorded")
	game.train_inspector.hide()
	# A different manual stop lies on the return leg: reversing cannot bypass it.
	game._use_signal_tool(Vector2i(8, 8))
	game._use_signal_tool(Vector2i(8, 8))
	for step in range(400): tick(game)
	check(game.route_distance < before and game.route_distance > 0 and game.passenger_returning, "return travels physically then waits before a stop signal")
	check(str(game.train_diagnostics(1).reason).to_lower().contains("manual stop"), "return wait identifies the real signal restriction")
	for click in range(3): game._use_signal_tool(Vector2i(8, 8))
	for step in range(600):
		tick(game)
		if game.passenger_held: break
	check(game.route_distance == 0 and game.passenger_held and not game.passenger_returning, "return reaches departure stop and holds")
	check(game.passengers_on_train == 0 and game.waiting_at_a >= 7, "passengers return to the departure queue only at arrival")
	check(game.reverse_train(1).contains("already at"), "arrived recovery cannot be restarted at zero distance")
	# Freight uses the same general command without a deadlock and keeps cargo.
	game.freight_train.distance_along_route = 128.0
	game.freight_train.cargo = 5
	game.freight_train.to_terminal = true
	game.freight_train.dwell = 0.0
	game.freight_train._update_transform()
	position = game.freight_train.position
	check(game.reverse_train(2).contains("reversed in place"), "freight can return before a confirmed deadlock")
	check(game.freight_train.position == position and game.freight_train.cargo == 5 and not game.freight_train.to_terminal, "freight reversal preserves load and position")
	for step in range(600):
		tick(game)
		if game.freight_train.held: break
	check(game.freight_train.held and game.freight_train.distance_along_route == 0 and game.freight_train.cargo == 5 and game.logs_delivered == 0, "freight returns physically without cargo payout")
	# Missing retained geometry must reject atomically.
	game.route_path = Curve2D.new()
	game.route_distance = 100
	check(game.reverse_train(1).contains("No retained path") and not game.passenger_returning, "missing path rejects without changing recovery state")
	game.queue_free()
	await process_frame
	print("Inspector Reverse: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
