extends SceneTree
const Clock = preload("res://scripts/core/sim_clock.gd")
const Actions = preload("res://scripts/core/input_actions.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	_run.call_deferred()
func key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event
func _run() -> void:
	# Use a desktop viewport for toolbar layout checks; headless defaults to
	# 64 × 64, smaller than a single accessible ribbon button at 200% scale.
	root.size = Vector2i(1280, 720)
	for fps in [30, 60, 120]:
		for speed in [1, 2, 5, 10]:
			var clock := Clock.new()
			clock.speed = speed
			var ticks := 0
			for frame in range(fps * 2): ticks += clock.advance(1.0 / fps)
			check(ticks == speed * 120, "%dx gives exact simulated seconds at %d FPS" % [speed, fps])
	var stall := Clock.new()
	stall.speed = 10
	check(stall.advance(5.0) == 80, "long stalls bounded at accelerated speed")
	check(stall.advance(1.0 / 60.0) == 10, "no backlog after stall")
	stall.speed = 0
	check(stall.advance(1.0) == 0, "zero speed remains supported by foundation")
	var reference: Array = []
	for fps in [30, 60, 120]:
		for speed_index in range(4):
			var game = load("res://scenes/main/main.tscn").instantiate()
			game.set_process(false)
			root.add_child(game)
			game.sim_rng.set_seed(12345)
			await process_frame
			game.set_process(false)
			game.paused = true
			for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
			for x in range(8, 29): game.tracks[Vector2i(x, 24)] = false
			game._check_route()
			game.sim_clock.reset()
			game.event_log.clear()
			game.waiting_at_a = 10
			game.forest_stock = 20
			game.log_production_timer = 0
			game.passenger_timer = 0
			game.operating_timer = 0
			game.money = 5000
			check(game.sim_clock.speed == 1 and game.speed_selector.selected == 0, "new game defaults to 1x")
			game.speed_selector.item_selected.emit(speed_index)
			var multiplier: int = int(game.GAME_SPEEDS[speed_index])
			check(game.paused and game.sim_clock.speed == multiplier, "dropdown changes speed without unpausing")
			var tick_before: int = game.sim_clock.tick
			game._process(1.0)
			check(game.sim_clock.tick == tick_before, "paused game does not advance at chosen speed")
			game.paused = false
			for frame in range(fps * 12 / multiplier): game._process(1.0 / fps)
			check(game.sim_clock.tick == 720, "selected speed runs same 12 seconds at %d FPS" % fps)
			var snapshot: Array = [game.route_distance, game.freight_train.save_state(), game.money, game.waiting_at_a, game.waiting_at_b, game.passengers_delivered, game.logs_delivered, game.forest_stock, game.log_production_timer, game.passenger_timer, game.event_log.save_state()]
			if reference.is_empty(): reference = snapshot
			check(snapshot == reference, "movement, dwell, production, money and events match 1x at %d FPS/%dx" % [fps, multiplier])
			game.queue_free()
			await process_frame
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.set_process(false)
	root.add_child(game)
	game.sim_rng.set_seed(12345)
	await process_frame
	game.set_process(false)
	for index in range(4):
		game._unhandled_input(key_event((KEY_1 + index) as Key))
		check(game.sim_clock.speed == game.GAME_SPEEDS[index] and game.speed_selector.selected == index, "number-row shortcut selects expected speed")
	game._open_traffic_dialog()
	game._unhandled_input(key_event(KEY_1))
	check(game.sim_clock.speed == 10, "management dialog blocks speed shortcuts")
	game.traffic_dialog.hide()
	var entry := LineEdit.new()
	root.add_child(entry)
	entry.grab_focus()
	game._unhandled_input(key_event(KEY_1))
	check(game.sim_clock.speed == 10, "typing does not change speed")
	entry.release_focus()
	entry.queue_free()
	Actions.apply_bindings({str(Actions.SPEED_NORMAL): [KEY_F6]})
	game._unhandled_input(key_event(KEY_F6))
	check(game.sim_clock.speed == 1, "remapped physical shortcut works")
	game._set_game_speed(3)
	game._unhandled_input(key_event(KEY_1))
	check(game.sim_clock.speed == 10, "old speed key no longer changes selection after remapping")
	Actions.apply_bindings(Settings.key_bindings)
	game._set_game_speed(3)
	game._save_game()
	game._load_game()
	check(game.sim_clock.speed == 10 and game.speed_selector.selected == 3, "load retains session speed without save-schema changes")
	game._set_game_speed(-1)
	game._set_game_speed(4)
	check(game.sim_clock.speed == 10, "invalid selections ignored")
	var old_scale: float = Settings.ui_scale
	Settings.ui_scale = 2
	game._apply_settings()
	await process_frame
	await process_frame
	check(game.speed_selector.get_global_rect().end.x <= game.get_viewport_rect().size.x, "speed selector remains inside viewport at 200%")
	Settings.ui_scale = old_scale
	game._apply_settings()
	game.queue_free()
	await process_frame
	print("Gameplay speed: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
