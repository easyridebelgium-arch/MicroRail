extends SceneTree
const Plan = preload("res://scripts/core/construction_plan.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	var plan := Plan.new()
	var live := {Vector2i(10, 10): false}
	var cell := Vector2i(11, 10)
	plan.stage({cell: false}, live)
	plan.stage({Vector2i(12, 10): false}, live)
	check(plan.quote().cost == 20 and live.size() == 1, "multiple strokes must remain an uncharged draft")
	plan.stage({cell: null}, live)
	check(plan.changes.size() == 1 and plan.quote().cost == 10 and plan.quote().refund == 0, "removing unbuilt ghost track cancels cost without granting refund")
	plan.stage({Vector2i(10, 10): "junction_6_2_4"}, live)
	check(plan.quote().cost == 110, "switch surcharge must be included in aggregate cost")
	var safe := func(_cell: Vector2i) -> bool: return false
	check(plan.validate(live, {}, {}, Vector2i(80, 50), safe, 500).is_empty(), "valid free draft must be ready to apply")
	check(plan.validate(live, {cell: 1, Vector2i(12, 10): 7}, {}, Vector2i(80, 50), safe, 500).contains("#7"), "current ownership must block the complete draft")
	check(plan.validate(live, {}, {}, Vector2i(80, 50), safe, 100).contains("Insufficient"), "aggregate affordability must be checked")
	live[Vector2i(12, 10)] = true
	check(plan.validate(live, {}, {}, Vector2i(80, 50), safe, 500).contains("since drafting"), "stale track values must be rejected")
	plan.clear()
	plan.stage({Vector2i(10, 10): null}, live)
	check(plan.quote().refund == 5, "real removal must quote actual refund")
	check(plan.validate(live, {}, {}, Vector2i(80, 50), func(c: Vector2i) -> bool: return c == Vector2i(10, 10), 500).contains("Platforms"), "facility protection must be respected")
	plan.clear()
	plan.stage({Vector2i(10, 10): "junction_6_2_4"}, live)
	check(plan.validate(live, {}, {Vector2i(10, 10): "auto"}, Vector2i(80, 50), safe, 500).contains("signal"), "signals may not be stranded on incompatible geometry")
	plan.clear()
	plan.stage({Vector2i(30, 30): "rail_3_7", Vector2i(31, 30): "rail_1_5"}, live)
	check(plan.validate(live, {}, {}, Vector2i(80, 50), safe, 500).contains("corner"), "final plan must reject diagonal corner crossings across separate strokes")
	print("Construction plan: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
