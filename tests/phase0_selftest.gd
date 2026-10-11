extends SceneTree
## Headless checks for the Phase 0 foundation modules.
##
## Run from the project folder:
##     godot --headless --path . --script res://tests/phase0_selftest.gd
## Exit code 0 means every check passed.

const SimClock = preload("res://scripts/core/sim_clock.gd")
const SimRng = preload("res://scripts/core/sim_rng.gd")
const EventLog = preload("res://scripts/core/event_log.gd")
const SaveMigrations = preload("res://scripts/core/save_migrations.gd")
const Palette = preload("res://scripts/core/palette.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
const Actions = preload("res://scripts/core/input_actions.gd")

var failures: int = 0
var checks: int = 0


func _init() -> void:
	_test_clock()
	_test_rng()
	_test_events()
	_test_migrations()
	_test_palette()
	_test_actions()

	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	checks += 1

	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _json_round_trip(value: Variant) -> Variant:
	var parser := JSON.new()

	if parser.parse(JSON.stringify(value)) != OK:
		return null

	return parser.data


func _test_clock() -> void:
	var clock := SimClock.new()
	var steps: int = 0

	for frame in range(60):
		steps += clock.advance(1.0 / 60.0)

	check(steps in [59, 60], "one second of 60 fps frames gives about 60 steps (got %d)" % steps)

	var uneven := SimClock.new()
	var total: int = 0

	for frame in range(30):
		total += uneven.advance(1.0 / 30.0)

	check(total in [59, 60], "30 fps frames give the same step count (got %d)" % total)

	var stalled := SimClock.new()
	check(stalled.advance(5.0) == SimClock.MAX_STEPS_PER_FRAME, "a long stall is capped")
	check(stalled.advance(0.0) == 0, "zero delta gives no steps")

	stalled.speed = 0.0
	check(stalled.advance(1.0) == 0, "speed 0 gives no steps")

	stalled.begin_tick()
	check(stalled.tick == 1, "begin_tick advances the timestamp")

	var restored := SimClock.new()
	restored.restore_state(_json_round_trip(stalled.save_state()))
	check(restored.tick == 1, "clock survives a JSON round trip")
	check(not SimClock.is_valid_state({"tick": -1}), "negative tick is invalid")
	check(not SimClock.is_valid_state({"tick": 1.5}), "fractional tick is invalid")
	check(SimClock.is_valid_state({"tick": 10}), "plain tick is valid")


func _test_rng() -> void:
	var first := SimRng.new(12345)
	var second := SimRng.new(12345)
	var same: bool = true

	for index in range(50):
		if first.randi() != second.randi():
			same = false

	check(same, "same seed gives the same sequence")

	var rng := SimRng.new(777)

	for index in range(10):
		rng.randi()

	var saved: Variant = _json_round_trip(rng.save_state())
	check(SimRng.is_valid_state(saved), "saved RNG state is valid")

	var expected: Array[int] = []

	for index in range(10):
		expected.append(rng.randi())

	var resumed := SimRng.new()
	resumed.restore_state(saved)
	var matches: bool = true

	for index in range(10):
		if resumed.randi() != expected[index]:
			matches = false

	check(matches, "restored RNG continues the exact same stream")
	check(not SimRng.is_valid_state({"seed": 5}), "numeric seed is rejected")
	check(not SimRng.is_valid_state({"seed": "abc"}), "non-numeric seed is rejected")
	check(SimRng.is_valid_state({"seed": "1"}), "seed-only state is valid (migrated saves)")

	var shuffled: Array = [1, 2, 3, 4, 5, 6]
	SimRng.new(9).shuffle(shuffled)
	shuffled.sort()
	check(shuffled == [1, 2, 3, 4, 5, 6], "shuffle keeps every element")
	check(SimRng.new(1).pick([]) == null, "pick on an empty array gives null")


func _test_events() -> void:
	var events_log := EventLog.new()
	var first: Dictionary = events_log.record(10, EventLog.TRAIN_ARRIVED, "passenger", {"stop": "a"})
	var second: Dictionary = events_log.record(20, EventLog.CARGO_DELIVERED, "freight", {"logs": 20})

	check(int(second["id"]) == int(first["id"]) + 1, "ids increase by one")
	check(events_log.query(EventLog.TRAIN_ARRIVED).size() == 1, "query by type")
	check(events_log.query("", "freight").size() == 1, "query by subject")
	check(events_log.query("", "", 15).size() == 1, "query by tick")

	for index in range(EventLog.MAX_EVENTS + 50):
		events_log.record(index, EventLog.TRACK_BUILT, "player")

	check(events_log.count() == EventLog.MAX_EVENTS, "the log stays bounded")

	var saved: Variant = _json_round_trip(events_log.save_state())
	check(EventLog.is_valid_state(saved), "saved event state is valid")
	check(saved["events"].size() == EventLog.MAX_SAVED_EVENTS, "only recent events are saved")

	var restored := EventLog.new()
	restored.restore_state(saved)
	check(restored.count() == EventLog.MAX_SAVED_EVENTS, "events restore")

	var next: Dictionary = restored.record(1, EventLog.ROUTE_CHANGED, "passenger")
	check(int(next["id"]) == int(saved["next_id"]), "ids continue after loading")

	check(not EventLog.is_valid_state({"next_id": 0, "events": []}), "next_id below 1 is invalid")
	check(not EventLog.is_valid_state({"next_id": 5, "events": [{"id": 9, "tick": 1, "type": "a", "subject": "b", "data": {}}]}), "event id beyond next_id is invalid")
	check(not EventLog.is_valid_state({"next_id": 5, "events": [{"id": 1, "tick": 1, "type": "", "subject": "b", "data": {}}]}), "empty type is invalid")
	check(EventLog.is_valid_state(SaveMigrations.default_sim_state()["events"]), "default event state is valid")


func _test_migrations() -> void:
	var old_save: Dictionary = {"version": 14, "tracks": [], "state": {}}
	var result: Dictionary = SaveMigrations.migrate(old_save)

	check(result["ok"], "version 14 migrates")
	check(int(result["data"]["version"]) == SaveMigrations.CURRENT_VERSION, "migrated save has the current version")
	check(result["data"].has("sim"), "migration adds the sim block")
	check(result["migrated"], "migration is reported")
	check(not old_save.has("sim"), "migration does not modify its input")
	check(SimClock.is_valid_state(result["data"]["sim"]["clock"]), "migrated clock is valid")
	check(SimRng.is_valid_state(result["data"]["sim"]["rng"]), "migrated rng is valid")

	var current: Dictionary = SaveMigrations.migrate({"version": float(SaveMigrations.CURRENT_VERSION)})
	check(current["ok"] and not current["migrated"], "a current save passes through unchanged")

	check(not SaveMigrations.migrate({"version": 13})["ok"], "version 13 is rejected")
	check(not SaveMigrations.migrate({"version": 999})["ok"], "future versions are rejected")
	check(not SaveMigrations.migrate({})["ok"], "missing version is rejected")
	check(not SaveMigrations.migrate({"version": "14"})["ok"], "text version is rejected")
	check(not SaveMigrations.migrate({"version": 14.5})["ok"], "fractional version is rejected")


func _test_palette() -> void:
	var original_mode: int = Settings.palette_mode

	for mode in Settings.PaletteMode.values():
		Settings.palette_mode = mode

		for role in Palette.Role.values():
			var color: Color = Palette.get_color(role)
			check(color.a > 0.0, "palette %d role %d is visible" % [mode, role])

	Settings.palette_mode = Settings.PaletteMode.COLOUR_BLIND
	check(Palette.get_color(Palette.Role.TRAIN_PASSENGER) != Palette.get_color(Palette.Role.TRAIN_FREIGHT), "colour-blind train colours differ")
	check(Palette.get_color(Palette.Role.HOVER_OK) != Palette.get_color(Palette.Role.HOVER_BAD), "colour-blind ok/bad colours differ")

	Settings.palette_mode = original_mode


func _test_actions() -> void:
	Actions.register_defaults()

	for action in Actions.ORDER:
		check(InputMap.has_action(action), "action %s exists" % action)
		check(Actions.current_keys(action).size() >= 1, "action %s has a default key" % action)

	check(Actions.current_keys(Actions.CAMERA_UP).size() == 2, "camera up keeps W and Up")

	# Damaged settings must not break the controls.
	Actions.apply_bindings({
		"toggle_pause": "not an array",
		"toggle_map": [-5, 0, "x", 1.5],
		"unknown_action": [65]
	})
	check(Actions.current_keys(Actions.TOGGLE_PAUSE) == PackedInt32Array([KEY_SPACE]), "invalid pause binding falls back to default")
	check(Actions.current_keys(Actions.TOGGLE_MAP).is_empty(), "all-invalid codes leave the action unbound, not broken")

	Actions.apply_bindings({"toggle_map": [KEY_N]})
	check(Actions.current_keys(Actions.TOGGLE_MAP) == PackedInt32Array([KEY_N]), "valid rebinding applies")

	var exported: Dictionary = Actions.export_bindings()
	check(exported["toggle_map"] == [KEY_N], "export reflects the InputMap")

	Actions.apply_bindings(Actions.default_bindings())
	check(Actions.current_keys(Actions.TOGGLE_MAP) == PackedInt32Array([KEY_M]), "defaults can be restored")
