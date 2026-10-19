extends SceneTree
const Contracts = preload("res://scripts/core/freight_contracts.gd")
const Policy = preload("res://scripts/core/notification_policy.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
const Events = preload("res://scripts/core/event_log.gd")
const Migrations = preload("res://scripts/core/save_migrations.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: run.call_deferred()
func fixture() -> Node:
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	root.add_child(game)
	game.set_process(false)
	game.paused = true
	game.accept_freight_contract("logs")
	game.sim_clock.tick = 32399
	game.notice = ""
	game.notice_remaining = 0.0
	return game
func tick(game: Node) -> void:
	game.sim_clock.begin_tick()
	game._simulation_step(1.0 / 60.0)
func run() -> void:
	var model := Contracts.new()
	model.accept("logs", 0, {})
	check(model.deadline_warning(32399) == "" and model.deadline_warning(32400) == "logs", "warning fires exactly at final-quarter boundary")
	check(model.deadline_warning(32401) == "" and model.deadline_warning(43200) == "", "one reminder per contract even at later threshold ticks")
	check(Contracts.valid(model.save_state(), 32400, {}), "warned active order validates without deliveries")
	var restored := Contracts.new()
	restored.restore_state(JSON.parse_string(JSON.stringify(model.save_state())))
	check(restored.deadline_warning(32401) == "", "saved marker suppresses warning independently of event history")
	var bad := model.save_state()
	bad.logs.warned_tick = 1
	check(not Contracts.valid(bad, 32400, {}), "impossible early warning tick is rejected")
	var finished := Contracts.new()
	finished.accept("logs", 0, {})
	finished.deliver("logs", 40, 100)
	check(finished.deadline_warning(32400) == "", "completed order never warns")
	var late := Contracts.new()
	late.accept("logs", 0, {})
	check(late.deadline_warning(43201) == "", "overdue order does not generate a stale near-deadline warning")
	check(Policy.defaults().contract_deadlines == Policy.OFF, "deadline notices are opt-in")
	root.size = Vector2i(1280, 720)
	var game = fixture()
	Settings.notification_rules = Policy.defaults()
	game.paused = false
	tick(game)
	check(not game.paused and not game.notice.contains("deadline") and game.event_log.query(Events.CONTRACT_DEADLINE).size() == 1, "Off preserves canonical warning without notice or pause")
	var history_has_warning := false
	for incident in game.incident_rows(): history_has_warning = history_has_warning or incident.title.contains("contract deadline")
	check(history_has_warning, "muted warning remains available in Problems history")
	Settings.notification_rules.contract_deadlines = Policy.PAUSE
	tick(game)
	check(not game.paused and game.event_log.query(Events.CONTRACT_DEADLINE).size() == 1, "enabling alerts later does not replay the muted reminder")
	game.event_log.clear()
	game.notifications.reset()
	game.paused = true
	check(game._save_game(1) and game._load_slot(1), "warned contract saves and loads with pruned event history")
	game.paused = false
	tick(game)
	check(not game.paused and game.event_log.query(Events.CONTRACT_DEADLINE).is_empty(), "load cannot rearm reminder even when its event was pruned")
	game.paused = true
	var saved: Dictionary = game._save_snapshot()
	check(saved.version == 52 and game._is_valid_save(saved), "version 52 validates the one-time warning marker")
	var old := saved.duplicate(true)
	old.version = 50
	for order in old.freight_contracts.values(): order.erase("warned_tick")
	var migrated: Dictionary = Migrations.migrate(old).data
	check(migrated.version == 52 and migrated.freight_contracts.logs.warned_tick == -1 and migrated.state == old.state and migrated.sim == old.sim, "v50 migration adds unset warning markers without changing simulation or progress")
	game.queue_free()
	await process_frame
	game = fixture()
	Settings.notification_rules = Policy.defaults()
	Settings.notification_rules.contract_deadlines = Policy.NOTICE
	game.paused = false
	tick(game)
	check(not game.paused and game.notice.contains("contract deadline approaching"), "Notice displays reminder without pausing")
	game.queue_free()
	await process_frame
	var results: Array = []
	for fps in [30, 60, 120]:
		game = fixture()
		Settings.notification_rules = Policy.defaults()
		Settings.notification_rules.contract_deadlines = Policy.PAUSE
		game.sim_clock.speed = 10.0
		game.paused = false
		game._process(1.0 / fps)
		check(game.paused and game.sim_clock.tick == 32400 and game.notice.contains("Paused by alert"), "10x pauses at %d FPS: paused=%s tick=%d notice=%s" % [fps, game.paused, game.sim_clock.tick, game.notice])
		check(not game.Autosaves.entries(game.active_save_slot).is_empty(), "simultaneous successful autosave must not hide the deadline pause reason")
		results.append([game.sim_clock.tick, game.freight_contracts.save_state(), game.event_log.save_state(), game.money])
		game.paused = false
		game._process(1.0 / fps)
		check(not game.paused and game.event_log.query(Events.CONTRACT_DEADLINE).size() == 1, "resuming does not immediately pause again")
		game.queue_free()
		await process_frame
	check(results[0] == results[1] and results[1] == results[2], "warning and simulation snapshot are frame-rate independent")
	game = fixture()
	Settings.notification_rules = Policy.defaults()
	game.settings_dialog.open_dialog()
	check(game.settings_dialog.notification_choices.contract_deadlines.selected == Policy.OFF, "Settings presents quiet default")
	game.settings_dialog.notification_choices.contract_deadlines.select(Policy.PAUSE)
	game.settings_dialog.hide()
	game.settings_dialog.open_dialog()
	check(game.settings_dialog.notification_choices.contract_deadlines.selected == Policy.OFF, "cancel discards deadline preference draft")
	game.settings_dialog.notification_choices.contract_deadlines.select(Policy.NOTICE)
	game.settings_dialog.confirmed.emit()
	Settings.load_settings()
	check(Settings.notification_rules.contract_deadlines == Policy.NOTICE, "Apply persists deadline preference in player configuration")
	Settings.notification_rules = Policy.defaults()
	Settings.save_settings()
	game.queue_free()
	await process_frame
	print("Contract notifications: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
