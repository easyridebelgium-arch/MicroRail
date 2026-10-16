extends SceneTree
const Settings = preload("res://scripts/core/game_settings.gd")
const Policy = preload("res://scripts/core/notification_policy.gd")
const Events = preload("res://scripts/core/event_log.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: _run.call_deferred()
func fixture() -> Node:
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.paused = true
	root.add_child(game)
	return game
func prepare(game: Node) -> void:
	game.set_process(false)
	for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
	for x in range(8, 29): game.tracks[Vector2i(x, 24)] = false
	game._check_route()
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	game.route_distance = 96
	game.passengers_on_train = 4
	game.train_needs_boarding = false
	game._update_train_transform()
	game._use_signal_tool(Vector2i(10, 8))
	game._use_signal_tool(Vector2i(10, 8))
	game.event_log.clear()
	game.notifications.reset()
	game.notice = ""
	game.notice_remaining = 0.0
	game.sim_rng.set_seed(42)
func _run() -> void:
	# Use a desktop window size; headless defaults to 64x64.
	root.size = Vector2i(1280, 720)
	var snapshots: Array = []
	for fps in [30, 60, 120]:
		var game = fixture()
		await process_frame
		prepare(game)
		Settings.notification_rules = {"waiting": Policy.PAUSE, "deadlocks": Policy.NOTICE, "recovery": Policy.OFF}
		game.sim_clock.speed = 10.0
		game.paused = false
		for frame in range(fps * 3):
			game._process(1.0 / fps)
			if game.paused: break
		check(game.paused and game.notice.contains("Paused by alert") and game.notice.contains("Manual stop"), "a wait alert must pause with a readable reason at %d FPS" % fps)
		check(game.sim_clock.tick < 240, "10x frame batch must stop at the alert tick")
		var stopped_tick: int = game.sim_clock.tick
		game._process(1.0 / fps)
		check(game.sim_clock.tick == stopped_tick, "paused frames must not advance the simulation")
		snapshots.append([game.sim_clock.tick, game.route_distance, game.freight_train.save_state(), game.event_log.save_state(), game.money])
		game.paused = false
		game._process(1.0 / fps)
		check(not game.paused and game.event_log.query(Events.TRAIN_WAITING).size() == 1, "resuming an unchanged wait must not repeatedly pause on the same incident")
		game.paused = true
		game._save_game()
		game._record_event(Events.TRAIN_WAITING, "1", {"reason": "stale pending wait"})
		game._load_game()
		check(game.notifications.take().is_empty(), "loading must discard pending pre-load notifications")
		var restored_count: int = game.event_log.count()
		game._process(1.0 / fps)
		check(game.event_log.count() == restored_count and not game.notice.contains("Paused by alert"), "restoring historical incidents must not replay alerts")
		game.queue_free()
		await process_frame
	check(snapshots[0] == snapshots[1] and snapshots[1] == snapshots[2], "auto-pause must finish the same complete fixed tick at 30/60/120 FPS, including 10x speed")
	var game = fixture()
	await process_frame
	prepare(game)
	Settings.notification_rules = Policy.defaults()
	var dialog = game.settings_dialog
	dialog.open_dialog()
	dialog.notification_choices.waiting.select(Policy.PAUSE)
	dialog.hide()
	check(Settings.notification_rules.waiting == Policy.OFF, "closing Settings must discard unapplied notification edits")
	dialog.open_dialog()
	check(dialog.notification_choices.waiting.selected == Policy.OFF, "reopening Settings must restore the applied preference")
	dialog.notification_choices.waiting.select(Policy.NOTICE)
	dialog.notification_choices.deadlocks.select(Policy.PAUSE)
	dialog.confirmed.emit()
	dialog.hide()
	check(Settings.notification_rules.waiting == Policy.NOTICE and Settings.notification_rules.deadlocks == Policy.PAUSE, "Apply must commit notification rules")
	Settings.notification_rules = Policy.defaults()
	Settings.load_settings()
	check(Settings.notification_rules.waiting == Policy.NOTICE and Settings.notification_rules.deadlocks == Policy.PAUSE, "notification preferences must persist in the player configuration")
	Settings.notification_rules.waiting = Policy.OFF
	game.paused = false
	for step in range(240):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
	check(not game.paused and game.event_log.query(Events.TRAIN_WAITING).size() == 1, "Off must preserve waiting history while avoiding notice/pause")
	check(not game.notice.contains("Manual stop"), "Off must not leak a configured wait notice")
	Settings.notification_rules.waiting = Policy.NOTICE
	game._record_event(Events.TRAIN_WAITING, "1", {"reason": "Notice only"})
	game._flush_notifications()
	check(not game.paused and game.notice.contains("Notice only"), "Notice mode must display the incident without pausing")
	Settings.notification_rules.deadlocks = Policy.OFF
	game._record_event(Events.DEADLOCK_DETECTED, "network", {"trains": [1, 2]})
	game._flush_notifications()
	check(not game.paused and not game.notice.contains("Deadlock"), "Off must also suppress deadlock notifications")
	var old_scale: float = Settings.ui_scale
	Settings.ui_scale = 2.0
	game._apply_settings()
	dialog.open_dialog()
	await process_frame
	await process_frame
	check(dialog.size.y <= game.get_viewport_rect().size.y + 1, "settings with alert controls must fit at 200% scale")
	dialog.hide()
	Settings.ui_scale = old_scale
	Settings.notification_rules = Policy.defaults()
	# Apply above wrote the test preferences to the real player config; restore it.
	Settings.save_settings()
	game.queue_free()
	await process_frame
	print("Notifications integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
