extends RefCounted
## Full-period company snapshots; no wall-clock time, RNG or route attribution.
const Numbers = preload("res://scripts/core/arrival_targets.gd")
const Timetable = preload("res://scripts/core/timetable.gd")
const PERIOD := 86400 # 24 game hours, measured from this company's baseline.
const KEEP := 32
const MAX_VALUE := 1000000000000000
const COUNTERS := ["delivered", "fares", "freight", "running"]
const FIELDS := ["delivered", "fares", "freight", "running", "waiting", "population", "cash"]
const MODES := ["off", "notice", "pause"]
const MODE_NAMES := ["No report reminders", "Notice when a report is ready", "Notice and pause when ready"]
var state: Dictionary = defaults(0, empty_values())
static func empty_values() -> Dictionary:
	return {"delivered": 0, "fares": 0, "freight": 0, "running": 0, "waiting": 0, "population": 0, "cash": 0}
static func defaults(tick: int, values: Dictionary) -> Dictionary:
	return {"since": tick, "mode": "off", "baseline": {"tick": tick, "values": values.duplicate(true)}, "reports": []}
func initialize(tick: int, values: Dictionary) -> void: state = defaults(tick, values)
func due(tick: int) -> bool: return tick - int(state.baseline.tick) >= PERIOD
func advance(tick: int, values: Dictionary) -> bool:
	if not due(tick): return false
	state.reports.append({"start": int(state.baseline.tick), "end": tick, "before": state.baseline.values.duplicate(true), "after": values.duplicate(true)})
	while state.reports.size() > KEEP: state.reports.pop_front()
	state.baseline = {"tick": tick, "values": values.duplicate(true)}
	return true
func save_state() -> Dictionary: return state.duplicate(true)
func restore_state(value: Dictionary) -> void:
	state = value.duplicate(true)
	state.since = int(state.since)
	state.baseline.tick = int(state.baseline.tick)
	for field in FIELDS: state.baseline.values[field] = int(state.baseline.values[field])
	for row in state.reports:
		row.start = int(row.start)
		row.end = int(row.end)
		for field in FIELDS:
			row.before[field] = int(row.before[field])
			row.after[field] = int(row.after[field])
static func values_valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != FIELDS.size(): return false
	for field in FIELDS:
		if not Numbers.whole(value.get(field), -MAX_VALUE if field == "cash" else 0, MAX_VALUE): return false
	return true
static func monotonic(before: Dictionary, after: Dictionary) -> bool:
	for field in COUNTERS:
		if after[field] < before[field]: return false
	return true
static func from_save(data: Dictionary) -> Dictionary:
	var result := empty_values()
	if not data.get("state") is Dictionary or not data.get("passenger_revenue") is Dictionary or not data.get("demand") is Dictionary or not data.demand.get("queues") is Dictionary or not data.get("city_demand") is Dictionary or not data.city_demand.get("cities") is Dictionary: return {}
	for pair in [["delivered", "passengers_delivered"], ["freight", "freight_income"], ["cash", "money"]]:
		var value: Variant = data.state.get(pair[1])
		if not Numbers.whole(value, -MAX_VALUE if pair[0] == "cash" else 0, MAX_VALUE): return {}
		result[pair[0]] = int(value)
	for field in ["total_operating_cost", "freight_operating_cost"]:
		if not Numbers.whole(data.state.get(field), 0, MAX_VALUE): return {}
		result.running += int(data.state[field])
	for row in data.passenger_revenue.values():
		if not row is Dictionary or not Numbers.whole(row.get("income"), 0, MAX_VALUE): return {}
		result.fares += int(row.income)
	for queue in data.demand.queues.values():
		if not queue is Dictionary: return {}
		for count in queue.values():
			if not Numbers.whole(count, 0, MAX_VALUE): return {}
			result.waiting += int(count)
	for city in data.city_demand.cities.values():
		if not city is Dictionary or not Numbers.whole(city.get("population"), 0, MAX_VALUE): return {}
		result.population += int(city.population)
	return result if values_valid(result) else {}
static func valid(value: Variant, current: Dictionary, tick: int) -> bool:
	if not values_valid(current) or not value is Dictionary or value.size() != 4 or value.get("mode") not in MODES or not Numbers.whole(value.get("since"), 0, tick): return false
	var baseline: Variant = value.get("baseline")
	if not baseline is Dictionary or baseline.size() != 2 or not Numbers.whole(baseline.get("tick"), int(value.since), tick) or not values_valid(baseline.get("values")): return false
	if not monotonic(baseline.values, current) or not value.get("reports") is Array or value.reports.size() > KEEP: return false
	var previous_end := int(value.since)
	var previous: Dictionary = {}
	for row in value.reports:
		if not row is Dictionary or row.size() != 4 or not Numbers.whole(row.get("start"), previous_end, int(baseline.tick)) or not Numbers.whole(row.get("end"), int(row.start) + PERIOD, int(baseline.tick)) or not values_valid(row.get("before")) or not values_valid(row.get("after")): return false
		if not monotonic(row.before, row.after) or not monotonic(row.after, current): return false
		if not previous.is_empty() and (int(row.start) != previous_end or row.before != previous): return false
		if previous.is_empty() and value.reports.size() < KEEP and int(row.start) != int(value.since): return false
		previous_end = int(row.end)
		previous = row.after
	if value.reports.is_empty(): return int(baseline.tick) == int(value.since)
	return previous_end == int(baseline.tick) and previous == baseline.values
static func deltas(row: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field in FIELDS: result[field] = int(row.after[field]) - int(row.before[field])
	result["profit"] = result.fares + result.freight - result.running
	return result
static func period_text(row: Dictionary) -> String:
	return "%s → %s" % [Timetable.clock_text(Timetable.absolute_minute(int(row.start))), Timetable.clock_text(Timetable.absolute_minute(int(row.end)))]
func describe(index: int) -> String:
	if index < 0 or index >= state.reports.size(): return "No completed periods yet. The first report arrives after 24 game hours from this company's recording baseline."
	var row: Dictionary = state.reports[index]
	var change := deltas(row)
	var result := "%s\nFinal passenger journeys: %d\nFares £%d · freight receipts £%d · running costs £%d\nOperating contribution: £%d\nQueued passengers: %d → %d (%+d)\nCity population: %d → %d (%+d)\nCash: £%d → £%d (%+d)" % [period_text(row), change.delivered, change.fares, change.freight, change.running, change.profit, row.before.waiting, row.after.waiting, change.waiting, row.before.population, row.after.population, change.population, row.before.cash, row.after.cash, change.cash]
	if index > 0:
		var previous: Dictionary = state.reports[index - 1]
		if int(row.end) - int(row.start) == int(previous.end) - int(previous.start):
			var old := deltas(previous)
			result += "\nCompared with the previous equal-length period: %+d final journeys; £%+d operating contribution." % [change.delivered - old.delivered, change.profit - old.profit]
		else: result += "\nPrevious period has a different duration; totals are not compared."
	else: result += "\nNo previous retained period to compare."
	return result
