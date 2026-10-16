extends SceneTree
const Corridor = preload("res://scripts/core/signal_corridor.gd")
const Plan = preload("res://scripts/core/construction_plan.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	var tracks: Dictionary = {}
	for x in range(10, 31): tracks[Vector2i(x, 15)] = false
	var safe := func(_cell: Vector2i) -> bool: return false
	var batch := Corridor.plan(tracks, Vector2i(10, 15), Vector2i(30, 15), 5, "auto", safe)
	check(batch.error.is_empty() and batch.updates.size() == 5, "connected corridor should produce endpoint and spaced automatic signals")
	check(batch.updates.has(Vector2i(15, 15)) and batch.updates.has(Vector2i(30, 15)), "spacing must follow route indices and include final endpoint")
	var reverse := Corridor.plan(tracks, Vector2i(30, 15), Vector2i(10, 15), 5, "stop", safe)
	check(reverse.updates.keys().size() == batch.updates.size() and reverse.updates[Vector2i(20, 15)] == "stop", "reverse selection should support manual-stop mode")
	tracks[Vector2i(20, 15)] = "junction_6_2_4"
	batch = Corridor.plan(tracks, Vector2i(10, 15), Vector2i(30, 15), 5, "auto", safe)
	check(not batch.updates.has(Vector2i(20, 15)), "switches must not receive batch signals")
	tracks.erase(Vector2i(20, 15))
	check(not Corridor.plan(tracks, Vector2i(10, 15), Vector2i(30, 15), 5, "auto", safe).error.is_empty(), "disconnected selection must not stage a partial corridor")
	tracks[Vector2i(20, 15)] = false
	var plan := Plan.new()
	plan.stage_signals({Vector2i(15, 15): "auto", Vector2i(25, 15): "stop"}, {}, tracks)
	check(not plan.is_empty() and plan.quote().net == 0, "signal-only draft should be valid with prototype signals free")
	check(plan.validate(tracks, {}, {}, Vector2i(80, 50), safe, 0).is_empty(), "signal-only draft must validate against final straight tracks")
	check(plan.validate(tracks, {Vector2i(15, 15): 4}, {}, Vector2i(80, 50), safe, 0).contains("#4"), "one reserved signal location must block entire batch")
	check(plan.validate(tracks, {}, {Vector2i(15, 15): "stop"}, Vector2i(80, 50), safe, 0).contains("since drafting"), "changed signal state must invalidate a stale batch")
	plan.clear()
	plan.stage_signals({Vector2i(40, 15): "auto"}, {}, tracks)
	check(plan.validate(tracks, {}, {}, Vector2i(80, 50), safe, 100).contains("straight"), "signal cannot be committed on absent track")
	plan.stage({Vector2i(40, 15): false}, tracks)
	check(plan.validate(tracks, {}, {}, Vector2i(80, 50), safe, 100).is_empty(), "track and signal can be drafted and validated together")
	print("Signal corridor: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
