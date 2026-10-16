extends SceneTree
const Metrics = preload("res://scripts/core/traffic_metrics.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	var metrics := Metrics.new()
	var cell := Vector2i(10, 8)
	var wait := {1: {"cell": cell, "reason": "Manual stop signal"}}
	for tick in range(1, 121): metrics.update(tick, [1, 2], wait)
	check(metrics.statistics(1).total_seconds == 2.0 and metrics.statistics(1).continuous_seconds == 2.0, "fixed ticks must count actual simulation seconds")
	check(metrics.statistics(2).total_seconds == 0.0, "an unsampled train must not accrue congestion")
	check(metrics.window_cells[cell] == 120, "measured location must accumulate stopped train ticks")
	metrics.update(120, [1, 2], wait)
	check(metrics.statistics(1).total_seconds == 2.0, "duplicate UI or tick update must not double count")
	metrics.update(121, [1, 2], {})
	check(metrics.statistics(1).continuous_seconds == 0.0 and metrics.statistics(1).total_seconds == 2.0, "resumption clears current streak while retaining totals")
	for tick in range(122, 3801): metrics.update(tick, [1, 2], {})
	check(metrics.window_cells.is_empty() and metrics.statistics(1).recent_seconds == 0.0, "old congestion must expire from the bounded rolling window")
	check(metrics.statistics(1).total_seconds == 2.0, "window expiry must not discard session total")
	metrics.update(3801, [2], {})
	check(not metrics.records.has(1), "removed services must not retain unbounded session records")
	metrics.reset()
	check(metrics.records.is_empty() and metrics._buckets.is_empty(), "loading/reset clears all derived measurements")
	var both := {1: {"cell": cell, "reason": "Block busy"}, 2: {"cell": cell, "reason": "Block busy"}}
	for tick in range(1, 61): metrics.update(tick, [1, 2], both)
	check(metrics.window_cells[cell] == 120, "cell congestion uses aggregate train-seconds, not elapsed wall time")
	for tick in range(61, 10001): metrics.update(tick, [1, 2], both)
	check(metrics._buckets.size() <= 60, "measurement retention must stay bounded on long runs")
	print("Traffic metrics: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
