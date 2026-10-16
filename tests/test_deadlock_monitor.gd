extends SceneTree
const Monitor = preload("res://scripts/core/deadlock_monitor.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	var monitor := Monitor.new()
	monitor.update({2: 1, 1: 2}, 10)
	check(monitor.cycles.is_empty(), "a momentary mutual wait is not confirmed")
	monitor.update({1: 2, 2: 1}, 189)
	check(monitor.cycles.is_empty(), "confirmation requires full three seconds")
	monitor.update({2: 1, 1: 2}, 190)
	check(monitor.cycles == [[1, 2]], "a sustained cycle is confirmed in ID order")
	check(monitor.new_cycles == [[1, 2]], "cycle reported once on confirmation")
	monitor.update({1: 2, 2: 1}, 191)
	check(monitor.new_cycles.is_empty(), "no per-tick duplicate alerts")
	check(monitor.contains(1) and not monitor.contains(3), "membership uses permanent IDs")
	monitor.update({1: 2}, 192)
	check(monitor.cycles.is_empty() and monitor.cleared_cycles == [[1, 2]], "a cleared wait ends the deadlock")
	monitor.update({1: 2}, 500)
	check(monitor.cycles.is_empty(), "waiting on a parked train is not a cycle")
	monitor.update({1: 2, 2: 1}, 501)
	monitor.update({}, 600)
	monitor.update({1: 2, 2: 1}, 601)
	monitor.update({1: 2, 2: 1}, 681)
	check(monitor.cycles.is_empty(), "interrupted cycles restart their confirmation timer")
	monitor.reset()
	monitor.update({4: 5, 5: 6, 6: 4, 2: 1, 1: 2, 3: 4}, 0)
	monitor.update({1: 2, 2: 1, 3: 4, 4: 5, 5: 6, 6: 4}, 180)
	check(monitor.cycles == [[1, 2], [4, 5, 6]], "distinct cycles are stable; feeder trains excluded")
	monitor.reset()
	check(monitor.cycles.is_empty(), "loading and recovery can reset transient history")
	print("Deadlock monitor: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
