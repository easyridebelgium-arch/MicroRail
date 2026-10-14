extends SceneTree
const Arrivals = preload("res://scripts/core/arrival_targets.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(not Arrivals.guidance(512, [], 8).known and not Arrivals.guidance(512, [0], 8).known, "missing fleet and invalid speed give no fabricated minimum")
	check(not Arrivals.guidance(0, [80], 8).known, "missing length cannot promise feasibility")
	check(Arrivals.guidance(512, [80], 4).status == "short_for_all", "too short even with grace is explicit")
	check(Arrivals.guidance(512, [120, 80], 4).status == "short_for_slowest", "fast vehicle cannot hide linked slow train")
	check(Arrivals.guidance(512, [80], 6).status == "uses_grace", "target may fit grace while lacking travel budget")
	check(Arrivals.guidance(512, [80], 8).status == "unproven", "free-running fit is not guarantee")
	check(Arrivals.guidance(512, [80], 0).status == "off", "off target still offers travel estimate")
	check(Arrivals.guidance(360.5, [60], 5).status == "uses_grace", "one fixed-tick boundary never creates false impossible warning")
	var meter := Arrivals.new()
	meter.depart("passenger", 1, "a>b", 120, 2, 0)
	meter.arrive("passenger", "b", 200)
	meter.depart("passenger", 1, "b>a", 220, 2)
	meter.arrive("passenger", "a", 250)
	meter.depart("passenger_3", 3, "a>b", 260, 2)
	meter.arrive("passenger_3", "b", 300)
	meter.depart("passenger_4", 4, "a>b", 320, 2)
	meter.arrive("passenger_4", "b", 350)
	var before: Dictionary = meter.save_state()
	var stats := meter.statistics("passenger", ["passenger_3"], "a>b")
	check(stats.count == 2 and stats.on_time == 1 and stats.scheduled == 1 and stats.departure_delay == 2.0, "group and direction filter isolate scheduled delay denominator")
	check(is_equal_approx(stats.travel_minutes, 1.0) and is_equal_approx(stats.late_minutes, 2.0 / 3.0), "running and positive lateness means preserve exact ticks")
	check(meter.statistics("passenger", [], "b>a").departure_delay == 0 and meter.statistics("passenger", [], "b>a").scheduled == 0, "unscheduled trips cannot pretend to have departure punctuality")
	check(meter.direction_report("passenger", ["passenger_3"], ["c>a"]).contains("no measured arrivals"), "unmeasured directions honest")
	check(meter.direction_report().contains("A → B") and meter.direction_report().contains("B → A") and meter.save_state() == before, "company direction report is read-only")
	var restored := Arrivals.new()
	restored.restore_state(JSON.parse_string(JSON.stringify(before)))
	check(restored.direction_report() == meter.direction_report(), "direction reports derive unchanged from existing JSON save")
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	var configuration: Dictionary = game.services.duplicate(true)
	configuration.passenger.stops = ["a", "b", "c"]
	configuration.passenger.arrival_targets = {"a>b": 8, "b>c": 8, "c>b": 8, "b>a": 8}
	var hint: Dictionary = game.arrival_target_guidance("passenger", configuration, "b>c")
	check(hint.known and is_equal_approx(hint.slowest, 6.4), "three-stop estimate measures one leg, without intermediate dwell or whole round trip")
	check(game.arrival_target_guidance("passenger", configuration, "c>b").slowest == hint.slowest, "Shuttle reverse uses same authoritative path length")
	var train: Dictionary = game.Fleet.make_train(3, "passenger_fast", "passenger_3")
	game.fleet.trains.append(train)
	configuration.passenger_3 = configuration.passenger.duplicate(true)
	configuration.passenger_3.link = "passenger"
	hint = game.arrival_target_guidance("passenger", configuration, "a>b")
	check(is_equal_approx(hint.fastest, 512.0 / 120.0) and is_equal_approx(hint.slowest, 6.4), "live assigned models including draft-linked fleet govern speeds")
	train.wagons = ["coach"]
	hint = game.arrival_target_guidance("passenger", configuration, "a>b")
	check(is_equal_approx(hint.fastest, 512.0 / 100.0), "attached rolling stock speed limit applies")
	train.wagons.clear()
	var loop_config: Dictionary = configuration.duplicate(true)
	loop_config.passenger.mode = "loop"
	loop_config.passenger.stops = ["a", "c", "b"]
	hint = game.arrival_target_guidance("passenger", loop_config, "b>a")
	check(is_equal_approx(hint.slowest, 6.4), "Loop closing leg uses final segment, not full circuit")
	configuration.passenger_3.platforms = {"a": 2}
	check(not game.arrival_target_guidance("passenger", configuration, "a>b").known, "disconnected linked first platform cannot inherit source geometry estimate")
	configuration.passenger_3.platforms = {}
	check(Arrivals.travel_guidance([4.0, 9.0], 5).status == "short_for_slowest", "different platform path lengths use each actual travel time")
	var primary: Dictionary = game.Fleet.assigned(game.fleet, "passenger")
	primary.speed_level = 1
	hint = game.arrival_target_guidance("passenger", configuration, "a>b")
	check(is_equal_approx(hint.slowest, 512.0 / 100.0), "speed upgrades change guidance")
	primary.speed_level = 0
	configuration.erase("passenger_3")
	game.fleet.trains.erase(train)
	# A real switch-connected bypass forces extra travel when a waypoint is added.
	game.tracks[Vector2i(8, 8)] = "junction_6_2_4"
	game.tracks[Vector2i(16, 8)] = "junction_2_6_4"
	for y in range(9, 11):
		game.tracks[Vector2i(8, y)] = true
		game.tracks[Vector2i(16, y)] = true
	game.tracks[Vector2i(8, 11)] = Geometry.from_ports(Vector2i.UP, Vector2i.RIGHT)
	game.tracks[Vector2i(16, 11)] = Geometry.from_ports(Vector2i.UP, Vector2i.LEFT)
	for x in range(9, 16): game.tracks[Vector2i(x, 11)] = false
	configuration.passenger.waypoints = {"a>b": [[12, 11]]}
	check(game.arrival_target_guidance("passenger", configuration, "a>b").slowest > 6.4, "waypoint bypass changes graph-derived travel estimate")
	configuration.passenger.platforms = {"a": 0}
	check(not game.arrival_target_guidance("passenger", configuration, "a>b").known, "unresolved Auto never estimates from guessed platform")
	configuration.passenger.platforms = {}
	var position: Vector2 = game.train_position
	var owners: Dictionary = game.reservations.owners.duplicate(true)
	var services: Dictionary = game.services.duplicate(true)
	var tick: int = game.sim_clock.tick
	game.arrival_target_guidance("passenger", configuration, "a>b")
	check(game.train_position == position and game.reservations.owners == owners and game.services == services and game.sim_clock.tick == tick, "guidance cannot move trains, allocate track or apply draft")
	game.tracks.erase(Vector2i(25, 8))
	check(not game.arrival_target_guidance("passenger", configuration, "a>b").known, "incomplete draft avoids unsupported feasibility claim")
	game.tracks[Vector2i(25, 8)] = false
	game.route_editor.open_editor()
	game.route_editor.arrival_minutes.value = 2
	check(game.route_editor.arrival_hint.text.contains("shorter than every assigned train"), "draft budget refreshes warning immediately")
	game.route_editor.arrival_minutes.value = 8
	check(game.route_editor.arrival_hint.text.contains("does not guarantee"), "reasonable budget remains qualified")
	game.route_editor.waypoint_x.value = 12
	game.route_editor.waypoint_y.value = 11
	var original_hint: String = game.route_editor.arrival_hint.text
	game.route_editor._add_waypoint()
	check(game.route_editor.arrival_hint.text != original_hint, "waypoint UI refreshes guidance without Apply")
	game.route_editor.hide()
	game.arrival_targets.restore_state(before)
	check(game.headway_report("passenger").contains("scheduled departure delay 2.0") and game.headway_report("passenger").contains("B → A"), "Routes shows direction results and departure delay")
	game.header_controls.open_accounts()
	check(game.header_controls.accounts_text.text.contains("Per direction (game minutes)") and game.header_controls.accounts_text.text.contains("A → B"), "Accounts company report includes observed directions")
	game.header_controls.accounts_dialog.hide()
	var scale: float = game.GameSettings.ui_scale
	for ui_scale in [1.0, 1.5, 2.0]:
		game.GameSettings.ui_scale = ui_scale
		game._apply_settings()
		game.route_editor.open_editor()
		await process_frame
		await process_frame
		check(float(game.route_editor.size.y) <= game.get_viewport_rect().size.y + 1, "guidance and reports fit at %d%%" % int(ui_scale * 100))
		game.route_editor.hide()
	game.GameSettings.ui_scale = scale
	game._apply_settings()
	game.queue_free()
	await process_frame
	print("Arrival guidance: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
