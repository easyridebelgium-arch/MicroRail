extends SceneTree
const Metrics = preload("res://scripts/core/city_service.gd")
const Start = preload("res://scripts/core/sandbox_start.gd")
const Model = preload("res://scripts/core/city_demand.gd")
const Demand = preload("res://scripts/core/passenger_demand.gd")
const Ledger = preload("res://scripts/core/journey_ledger.gd")
const Rng = preload("res://scripts/core/sim_rng.gd")
class LastDestination extends RefCounted:
	func randi_range(_low: int, high: int) -> int: return high
var checks := 0
var failures := 0
var company_delivered := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func envelope(queues: RefCounted, ledger: RefCounted) -> Dictionary:
	return {"demand": {"batches": queues.batches}, "journeys": {"aboard": ledger.aboard}, "state": {"passengers_delivered": company_delivered}}
func run() -> void:
	var boot := Start.new()
	boot.initialize("42", 3)
	var world: Dictionary = boot.world.save_state()
	for index in range(3): world.settlements[index].cell = [[10, 8], [30, 8], [55, 8]][index]
	boot.world.restore_state(world)
	var metrics := Metrics.new()
	metrics.initialize(world)
	var fixed := LastDestination.new()
	boot.city_demand.generate(world, boot.demand, {}, fixed, 0, {}, Callable(), metrics.record_requests)
	check(metrics.summary("town:01", 0).totals.no_station == 2, "requests without stations retain explicit unmet reason")
	for candidate in boot.Generator.planning(world).station_candidates:
		check(boot.commit_station(boot.station_draft(Vector2i(candidate.cell[0], candidate.cell[1])), {}, {}).ok, "construct catchment for cohort test")
	world = boot.world.save_state()
	var stations: Dictionary = boot.world.stations()
	var ids: Array = stations.keys()
	ids.sort()
	var a: String = ids[0]
	var b: String = ids[1]
	var c: String = ids[2]
	var configurations := {"ab": {"stops": [a, b], "mode": "shuttle"}, "bc": {"stops": [b, c], "mode": "shuttle"}}
	boot.city_demand.initialize(world)
	metrics.initialize(world)
	var ledger := Ledger.new(ids)
	boot.city_demand.generate(world, boot.demand, {}, fixed, 0, {}, Callable(), metrics.record_requests)
	check(metrics.summary("town:01", 0).totals.no_service == 2, "unusable service differs from missing station")
	boot.city_demand.initialize(world)
	metrics.initialize(world)
	boot.city_demand.generate(world, boot.demand, configurations, fixed, 300, {b: 0, c: 0}, Callable(), metrics.record_requests)
	var report := metrics.summary("town:01", 300)
	check(report.totals.queued == 2 and report.pending == 2 and report.totals.delivered == 0, "admissions remain unfinished, never delivered")
	check(Metrics.valid(metrics.save_state(), world, 300, envelope(boot.demand, ledger), stations), "cohorts match real queued passenger groups")
	var manifest: Dictionary = {}
	ledger.ensure("ab", manifest, 400)
	check(boot.demand.board(a, [c], 1, manifest, 400) == 1, "board only part of a cohort")
	ledger.board("ab", boot.demand.last_journeys)
	check(metrics.summary("town:01", 400).totals.legs == 0, "boarding alone creates no arrived leg")
	var transfer: Array = ledger.release("ab", [c])
	check(boot.demand.interchange(b, [a, b], manifest, 500, transfer) == 1, "real transfer preserves unfinished passenger identity")
	metrics.record_arrivals(transfer, false, stations)
	report = metrics.summary("town:01", 500)
	check(report.totals.legs == 1 and report.totals.delivered == 0 and report.pending == 2, "interchange adds one arrived leg and no final delivery")
	check(Metrics.valid(metrics.save_state(), world, 500, envelope(boot.demand, ledger), stations), "transfer queues still reconcile to original cohort")
	ledger.ensure("bc", manifest, 600)
	check(boot.demand.board(b, [c], 1, manifest, 600) == 1, "board transfer on next service")
	ledger.board("bc", boot.demand.last_journeys)
	var finished := ledger.finish("bc", c, manifest, 800)
	company_delivered += Demand.alight(manifest, c)
	metrics.record_arrivals(finished, true, stations)
	report = metrics.summary("town:01", 800)
	check(report.totals.delivered == 1 and report.totals.legs == 2 and report.pending == 1, "two-service journey is one final delivery and two arrived legs")
	metrics.record_arrivals(ledger.finish("bc", c, manifest, 800), true, stations)
	check(metrics.summary("town:01", 800).totals.delivered == 1, "second unload of emptied manifest cannot credit another delivery")
	ledger.ensure("ab", manifest, 900)
	boot.demand.board(a, [c], 10, manifest, 900)
	ledger.board("ab", boot.demand.last_journeys)
	var recovered: Array = ledger.release("ab", [c])
	boot.demand.return_to(a, manifest, 1000, recovered)
	check(metrics.summary("town:01", 1000).pending == 1 and metrics.summary("town:01", 1000).totals.legs == 2, "recovery returns unfinished passengers without awarding transport or delivery")
	boot.city_demand.generate(world, boot.demand, configurations, fixed, 39000, {b: 0, c: 0}, Callable(), metrics.record_requests)
	report = metrics.summary("town:01", 39000)
	check(report.older_pending == 1 and report.pending > report.older_pending, "old unfinished cohort survives recent-history boundary without becoming a failure")
	check(Metrics.valid(metrics.save_state(), world, 39000, envelope(boot.demand, ledger), stations), "old and new queue cohorts reconcile together")
	ledger.ensure("ab", manifest, 40000)
	boot.demand.board(a, [c], 1, manifest, 40000)
	ledger.board("ab", boot.demand.last_journeys)
	finished = ledger.finish("ab", c, manifest, 41000)
	company_delivered += Demand.alight(manifest, c)
	metrics.record_arrivals(finished, true, stations)
	report = metrics.summary("town:01", 41000)
	check(report.totals.delivered == 2 and report.recent.delivered == 0 and report.older_pending == 0, "late completion credits its old request cohort, never today's demand")
	boot.city_demand.generate(world, boot.demand, configurations, fixed, 42000, {b: 0, c: 0}, Callable(), metrics.record_requests)
	check(metrics.state.cities["town:01"].retired.delivered == 2 and metrics.summary("town:01", 42000).totals.delivered == 2, "finished old cohort retires without losing all-time deliveries")
	check(Metrics.valid(metrics.save_state(), world, 42000, envelope(boot.demand, ledger), stations), "retired and active accounting remain conserved")
	check(metrics.describe("town:01", 42000).contains("Unfinished is not failed") and metrics.describe("town:01", 42000).contains("Day 1"), "player explanation uses game time and distinguishes unfinished trips")
	# The observer must not change the original city generator or its random stream.
	var left := Model.new()
	var right := Model.new()
	left.initialize(world)
	right.initialize(world)
	var left_queues := Demand.new(ids, stations, 0)
	var right_queues := Demand.new(ids, stations, 0)
	var left_rng := Rng.new(44)
	var right_rng := Rng.new(44)
	var observed := Metrics.new()
	observed.initialize(world)
	for index in range(20):
		left.generate(world, left_queues, configurations, left_rng, index * 300, {}, Callable(), observed.record_requests)
		right.generate(world, right_queues, configurations, right_rng, index * 300)
	check(left.save_state() == right.save_state() and left_queues.save_state({}, 6000) == right_queues.save_state({}, 6000) and left_rng.save_state() == right_rng.save_state(), "cohort observer preserves requests, passenger queues and seeded RNG exactly")
	check(observed.summary("town:01", 6000).totals.no_express > 0, "direct-Express refusals retained distinctly")
	var full_queues := Demand.new(ids, stations, 0)
	var full_model := Model.new()
	full_model.initialize(world)
	var full_metrics := Metrics.new()
	full_metrics.initialize(world)
	full_model.generate(world, full_queues, configurations, fixed, 0, {a: 0, b: 0, c: 0}, Callable(), full_metrics.record_requests)
	check(full_metrics.summary("town:01", 0).totals.full == 2, "full queues have their own unmet outcome")
	var saved := metrics.save_state()
	var restored := Metrics.new()
	restored.restore_state(JSON.parse_string(JSON.stringify(saved)))
	check(restored.save_state() == saved, "JSON restore normalizes integer cohort counters")
	for mutation in ["negative", "missing", "orphan", "duplicate", "physical", "retired"]:
		var bad := saved.duplicate(true)
		var city: Dictionary = bad.cities["town:01"]
		match mutation:
			"negative": city.totals.delivered = -1
			"missing": bad.cities.erase("town:01")
			"orphan": city.cohorts[0].origin = "station:missing"
			"duplicate": city.cohorts.append(city.cohorts[0].duplicate(true))
			"physical": city.cohorts[0].groups[0].destination = a
			"retired": city.retired.queued += 1; city.retired.requested += 1; city.totals.queued += 1; city.totals.requested += 1
		check(not Metrics.valid(bad, world, 42000, envelope(boot.demand, ledger), stations), "reject invalid cohort state: " + mutation)
	check(not Metrics.valid(saved, world, 42000, {}, stations), "malformed envelope rejected without an exception")
	var lost := envelope(boot.demand, ledger).duplicate(true)
	for station in lost.demand.batches: lost.demand.batches[station] = []
	for service in lost.journeys.aboard: lost.journeys.aboard[service] = []
	check(not Metrics.valid(saved, world, 42000, lost, stations), "outstanding cohorts require matching physical queue or train passengers")
	var duplicated := envelope(boot.demand, ledger).duplicate(true)
	for rows in duplicated.demand.batches.values():
		if not rows.is_empty():
			rows[0].count += 1
			break
	check(not Metrics.valid(saved, world, 42000, duplicated, stations), "extra physical passengers cannot impersonate an accepted measured cohort")
	check(Metrics.defaults({"settlements": 5}).cities.is_empty(), "malformed migration world does not raise an exception")
	# Bounded history with no queued passengers does not grow forever.
	for index in range(200): full_model.generate(world, full_queues, {}, fixed, (index + 1) * 300, {}, Callable(), full_metrics.record_requests)
	check(full_metrics.state.cities["town:01"].cohorts.size() <= 120 and full_metrics.summary("town:01", 60000).totals.requested > 120, "recent resolved/unmet history is bounded while cumulative totals survive")
	# Unknown pre-measurement journeys never become successes for new request cohorts.
	var baseline := Metrics.new()
	baseline.initialize(world, 42000)
	baseline.record_arrivals(finished, true, stations)
	check(baseline.summary("town:01", 42000).totals.delivered == 0 and baseline.summary("town:01", 42000).unmatched == 1, "legacy arrival is transparent and excluded from measured demand coverage")
	var saturated := Metrics.new()
	saturated.initialize(world)
	var saturated_city: Dictionary = saturated.state.cities["town:01"]
	for index in range(Metrics.MAX_COHORTS):
		saturated_city.cohorts.append({"tick": index, "origin": "", "counts": Metrics.counts(), "groups": []})
	saturated_city.last_tick = Metrics.MAX_COHORTS - 1
	var saturation_queues := Demand.new(ids, stations, 0)
	check(saturation_queues.enqueue_trip(a, c, 100, Metrics.MAX_COHORTS), "real passenger admitted before saturated measurement callback")
	var sample := {"tick": Metrics.MAX_COHORTS, "requested": 1, "queued": 1, "no_station": 0, "no_service": 0, "no_express": 0, "full": 0}
	saturated.record_requests("town:01", sample, a, [{"destination": c, "class": "local"}])
	check(saturated_city.cohorts.size() == Metrics.MAX_COHORTS and saturation_queues.waiting(a) == 1 and saturated_city.totals.unmeasured == 1 and saturated_city.totals.untracked_requests == 1 and saturated.summary("town:01", Metrics.MAX_COHORTS).pending == 0, "measurement limit stays bounded, retains passenger and reports unmeasured admission without a failure")
	check(Metrics.valid(saturated.save_state(), world, Metrics.MAX_COHORTS, envelope(saturation_queues, Ledger.new(ids)), stations), "saturated measurement remains a valid conserved state")
	var migration: Dictionary = preload("res://scripts/core/save_migrations.gd").migrate({"version": 41, "world": {"settlements": 5}, "sim": {"clock": null}})
	check(migration.ok and migration.data.city_service.cities.is_empty(), "malformed legacy world/clock does not crash migration before normal validation")
	print("City service cohorts: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
