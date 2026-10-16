extends SceneTree
const Timetable = preload("res://scripts/core/timetable.gd")
const Services = preload("res://scripts/service_routes.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
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
	check(Timetable.absolute_minute(0) == 360 and Timetable.absolute_minute(60 * 90) == 450, "the clock starts at 06:00 and runs a game minute per simulated second")
	check(Timetable.format(450) == "07:30" and Timetable.clock_text(1440 + 450) == "Day 2  07:30", "times format as HH:MM and day")
	var parsed := Timetable.parse("07:30, 6:00 ; 18:15 07:30")
	check(parsed.ok and parsed.times == [360, 450, 1095], "times parse sorted and unique: %s" % str(parsed.times))
	check(not Timetable.parse("25:00").ok and not Timetable.parse("7.30").ok and not Timetable.parse("07:5").ok, "bad times are rejected")
	check(Timetable.parse("").ok and Timetable.parse("").times.is_empty(), "empty text clears the timetable")
	check(Timetable.slots_between([360, 450], 359, 450) == [360, 450] and Timetable.slots_between([360], 360, 1800) == [1800], "slots between two moments, across days")
	check(Timetable.next_slot([360, 450], 450) == 1800 and Timetable.next_slot([360, 450], 100) == 360, "next slot wraps to tomorrow")
	check(Timetable.tightest_gap([360, 450, 1400]) == 90 and Timetable.tightest_gap([0, 1430]) == 10, "closest departures wrap midnight")
	var cfg := Services.defaults()
	cfg["passenger"]["timetable"] = [360, 450]
	check(Services.is_valid(cfg), "a sorted timetable is valid")
	cfg["passenger"]["timetable"] = [450, 360]
	check(not Services.is_valid(cfg), "an unsorted timetable is invalid")
	cfg["passenger"]["timetable"] = [1440]
	check(not Services.is_valid(cfg), "a time past midnight is invalid")

	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	game.money = 100000
	for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	game.paused = true
	# Depart A at 06:01, 06:20 and 06:40 (1 sim second = 1 game minute).
	var configuration: Dictionary = game.services.duplicate(true)
	configuration["passenger"]["timetable"] = [361, 380, 400]
	check(game.apply_service_routes(configuration).begins_with("Routes applied"), "a timetable applies")
	check(game.services.passenger.timetable == [361, 380, 400], "it is stored with the service")
	game.paused = false
	var held := false
	var departed_at: Array = []
	var previous_log := 0
	for i in range(60 * 45):
		tick(game)
		held = held or str(game.reservation_waits.get("passenger", "")).begins_with("Holding for timetable")
		var state: Dictionary = game.timetable_state.get("passenger", {})
		if not state.is_empty() and int(state.served) != previous_log:
			previous_log = int(state.served)
			departed_at.append(Timetable.absolute_minute(game.sim_clock.tick))
	check(held, "the train waits for its scheduled time")
	check(departed_at.size() >= 2 and departed_at[0] == 361 and departed_at[1] == 380, "departures follow the timetable: %s" % str(departed_at))
	var state: Dictionary = game.timetable_state["passenger"]
	check(int(state.served) >= 2 and state.delays.size() == int(state.served), "served departures and delays are counted")
	check(game.timetable_report("passenger").contains("Served"), "the report shows punctuality")
	check(game.game_clock_text().begins_with("Day 1"), "the header clock reads the game day")
	game.paused = true
	game._open_routes_editor()
	await process_frame
	var editor = game.route_editor
	check(editor.timetable_field.text == "06:01, 06:20, 06:40", "Routes shows the timetable")
	editor.timetable_field.text = "08:00, 8:30"
	check(editor._set_timetable() and editor.draft["passenger"]["timetable"] == [480, 510], "typed times update the draft")
	editor.timetable_field.text = "nonsense"
	check(not editor._set_timetable() and editor.draft["passenger"]["timetable"] == [480, 510], "a bad entry keeps the old draft and says why")
	editor.hide()
	game.queue_free()
	await process_frame
	print("Timetable: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
