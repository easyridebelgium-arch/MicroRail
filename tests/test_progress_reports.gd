extends SceneTree
const Reports = preload("res://scripts/core/progress_reports.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var model := Reports.new()
	var values := Reports.empty_values()
	values.cash = 5000
	model.initialize(600, values)
	check(not model.advance(600 + Reports.PERIOD - 1, values), "report waits for whole measured period")
	values.delivered = 10
	values.fares = 50
	values.running = 20
	values.waiting = 4
	values.cash = 4930
	check(model.advance(600 + Reports.PERIOD, values), "first complete period records once")
	check(not model.advance(600 + Reports.PERIOD, values), "same tick cannot duplicate a report")
	var delta := Reports.deltas(model.state.reports[0])
	check(delta.profit == 30 and delta.cash == -70 and delta.delivered == 10, "operating contribution stays separate from all-cash change")
	check(model.describe(0).contains("No previous retained period"), "first period invents no trend")
	values.delivered = 25
	values.fares = 125
	values.running = 30
	model.advance(600 + 2 * Reports.PERIOD, values)
	check(model.describe(1).contains("+5 final journeys") and model.describe(1).contains("£+35"), "equal-length historical periods compare exact differences")
	check(Reports.valid(model.save_state(), values, 600 + 2 * Reports.PERIOD), "complete history validates")
	var restored := Reports.new()
	restored.restore_state(JSON.parse_string(JSON.stringify(model.save_state())))
	check(restored.save_state() == model.save_state(), "history and reminders survive exact JSON roundtrip")
	for index in range(40): model.advance(600 + (index + 3) * Reports.PERIOD, values)
	check(model.state.reports.size() == Reports.KEEP and Reports.valid(model.save_state(), values, 600 + 42 * Reports.PERIOD), "history remains bounded and continuous after truncation")
	var bad := model.save_state()
	bad.reports[1].before.fares += 1
	check(not Reports.valid(bad, values, 600 + 42 * Reports.PERIOD), "inconsistent neighbouring snapshots rejected")
	bad = model.save_state()
	bad.mode = "invalid"
	check(not Reports.valid(bad, values, 600 + 42 * Reports.PERIOD), "invalid saved reminder rejected")
	model.advance(600 + 44 * Reports.PERIOD, values)
	check(model.describe(Reports.KEEP - 1).contains("different duration"), "clock jumps produce one honest longer period and no unequal-length trend")
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	game.paused = true
	for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	for index in range(480):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
	# Arrange the clock near a boundary after genuine operations, avoiding a
	# 24-minute real-time wait in this regression test.
	game.sim_clock.restore_state({"tick": Reports.PERIOD - 120})
	check(game._save_game(1), "save live company before first report")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(1)))
	check(saved.version == 46 and game._is_valid_save(saved), "version 46 validates report baseline with live finances")
	var reference: Dictionary = {}
	for fps in [30, 60, 120]:
		check(game._load_slot(1), "restore report boundary company")
		game.paused = false
		game.sim_clock.speed = 10
		for frame in range(fps * 3): game._process(1.0 / fps)
		check(not game.paused and game.sim_clock.tick == Reports.PERIOD + 1680, "reminders off do not interrupt the full simulation interval")
		game.paused = true
		var state: Dictionary = JSON.parse_string(JSON.stringify({"reports": game.progress_reports.save_state(), "money": game.money, "delivered": game.passengers_delivered, "clock": game.sim_clock.save_state(), "events": game.event_log.save_state(), "rng": game.sim_rng.save_state()}))
		if reference.is_empty(): reference = state
		check(reference == state, "reports and simulation match at %d FPS at 10×" % fps)
	check(game.progress_reports.state.reports.size() == 1 and game.progress_reports.state.mode == "off", "recording is enabled with reminders off by default")
	var saved_reports: Dictionary = game.progress_reports.save_state()
	check(game._save_game(2), "completed report saves independently")
	var snapshot := JSON.stringify(game._save_snapshot(), "", true, true)
	game.open_progress_reports()
	check(game.progress_dialog.visible and game._modal_open() and snapshot == JSON.stringify(game._save_snapshot(), "", true, true), "reading reports pauses without mutating saved simulation")
	check(game.progress_dialog.details.text.contains("Final passenger journeys") and game.progress_dialog.choice.item_count == 1, "history selector displays actual completed period")
	game.progress_dialog.mode_choice.select(1)
	game.progress_dialog.mode_choice.item_selected.emit(1)
	check(game.progress_reports.state.mode == "notice", "paused reminder edit applies to this company")
	game.progress_dialog.hide()
	game.paused = false
	game.request_report_mode("pause")
	check(game.progress_reports.state.mode == "notice", "running preference waits for fixed tick")
	game.sim_clock.begin_tick()
	game._run_due_commands()
	check(game.progress_reports.state.mode == "pause", "fixed command queue applies reminder preference")
	game.sim_clock.restore_state({"tick": 2 * Reports.PERIOD})
	game._advance_progress_reports()
	check(game.paused and game.notice.contains("progress report ready"), "optional reminder pauses and points to report without opening popup")
	check(not game.progress_dialog.visible, "report never opens itself during simulation")
	check(game._load_slot(2) and game.progress_reports.save_state() == saved_reports, "loading restores slot's exact preference, history and next-period baseline")
	var old: Dictionary = saved.duplicate(true)
	old.version = 44
	old.erase("progress_reports")
	var migrated: Dictionary = game.SaveMigrations.migrate(old).data
	check(game._is_valid_save(migrated) and migrated.progress_reports.since == old.sim.clock.tick and migrated.progress_reports.reports.is_empty(), "v44 migration starts fresh report baseline without invented history")
	check(migrated.state == old.state and migrated.sim == old.sim and migrated.journeys == old.journeys, "migration preserves cash, passengers, RNG, events and queued commands")
	var damaged: Dictionary = game._save_snapshot()
	damaged.progress_reports.reports[0].after.fares = -1
	var file := FileAccess.open("user://bad-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(damaged))
	file.close()
	var reports_before: Dictionary = game.progress_reports.save_state()
	check(not game._load_game("user://bad-report.json") and reports_before == game.progress_reports.save_state(), "damaged report load fails atomically")
	game.GameSettings.ui_scale = 2.0
	game._apply_settings()
	game.open_progress_reports()
	for frame in range(4): await process_frame
	check(float(game.progress_dialog.size.y) <= game.get_viewport_rect().size.y and Rect2(Vector2.ZERO, Vector2(game.progress_dialog.size)).encloses(game.progress_dialog.get_ok_button().get_global_rect()), "report window and footer fit 200% viewport")
	game._reset_track_tools()
	check(not game.progress_dialog.visible, "right-click reset closes report window")
	game.GameSettings.ui_scale = 1.0
	game._apply_settings()
	game.queue_free()
	await process_frame
	print("Progress reports: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
