extends RefCounted
## Directional journey budgets, captured only on physical departure.
const Timetable = preload("res://scripts/core/timetable.gd")
const KEEP := 128
const TOLERANCE_TICKS := 60 # One game minute, one simulated second.
const MAX_TICK := 1_000_000_000_000
var active: Dictionary = {}
var completed: Array = []

static func valid_targets(config: Dictionary) -> bool:
	var targets: Variant = config.get("arrival_targets", {})
	if not targets is Dictionary: return false
	if config.stops == ["forest", "terminal"]: return targets.is_empty()
	var legs := Timetable.departure_legs(config.stops, config.get("mode", "shuttle"))
	for leg in targets:
		if not legs.has(leg) or not whole(targets[leg], 1, 1440): return false
	return true

func depart(service: String, train_id: int, leg: String, tick: int, minutes: int, scheduled_tick: int = -1) -> void:
	active.erase(service)
	if minutes <= 0: return
	var baseline := scheduled_tick if scheduled_tick >= 0 else tick
	active[service] = {"service": service, "train_id": train_id, "leg": leg, "depart": tick, "planned_depart": baseline, "minutes": minutes, "due": baseline + minutes * Timetable.TICKS_PER_MINUTE, "scheduled": scheduled_tick >= 0}

func arrive(service: String, destination: String, tick: int) -> void:
	if not active.has(service): return
	var row: Dictionary = active[service]
	active.erase(service)
	if str(row.leg).get_slice(">", 1) != destination: return
	row = row.duplicate(true)
	row["arrive"] = tick
	completed.append(row)
	while completed.size() > KEEP: completed.pop_front()

func cancel(service: String) -> void: active.erase(service)

func describe(service: String, tick: int) -> String:
	if not active.has(service): return "Arrival target: no measured trip in progress."
	var row: Dictionary = active[service]
	var due_minute := Timetable.START_MINUTE + int(floor(float(row.due) / Timetable.TICKS_PER_MINUTE))
	return "Arrival target %s: %s (%d game min from %s); %s. Safety restrictions still apply." % [str(row.leg).replace(">", " → ").to_upper(), Timetable.clock_text(due_minute), row.minutes, "scheduled departure" if row.scheduled else "actual departure", "late by %.1f game min" % (float(tick - row.due) / Timetable.TICKS_PER_MINUTE) if tick > row.due + TOLERANCE_TICKS else "within the target window"]

func statistics(service: String = "", members: Array = [], leg: String = "") -> Dictionary:
	var result := {"count": 0, "on_time": 0, "late_minutes": 0.0, "travel_minutes": 0.0, "scheduled": 0, "departure_delay": 0.0}
	for row in completed:
		if service != "" and row.service != service and not members.has(row.service): continue
		if leg != "" and row.leg != leg: continue
		result.count += 1
		if int(row.arrive) <= int(row.due) + TOLERANCE_TICKS: result.on_time += 1
		result.late_minutes += maxf(0.0, float(row.arrive - row.due) / Timetable.TICKS_PER_MINUTE)
		result.travel_minutes += float(row.arrive - row.depart) / Timetable.TICKS_PER_MINUTE
		if row.scheduled:
			result.scheduled += 1
			result.departure_delay += float(row.depart - row.planned_depart) / Timetable.TICKS_PER_MINUTE
	if result.count > 0:
		result.late_minutes /= result.count
		result.travel_minutes /= result.count
	if result.scheduled > 0: result.departure_delay /= result.scheduled
	return result

func report(service: String = "", members: Array = []) -> String:
	var stats := statistics(service, members)
	if stats.count == 0: return "Arrival punctuality: no completed targeted trips yet."
	return "Arrival punctuality: %d / %d on time (%.1f%%); average positive lateness %.1f game min; average running time %.1f game min. On time includes early arrivals and up to 1 game min late. Latest %d measured trips; no fare/satisfaction penalties." % [stats.on_time, stats.count, 100.0 * stats.on_time / stats.count, stats.late_minutes, stats.travel_minutes, stats.count]

func direction_report(service: String = "", members: Array = [], legs: Array = []) -> String:
	var selected: Array = legs.duplicate()
	if selected.is_empty():
		for row in completed:
			if service != "" and row.service != service and not members.has(row.service): continue
			if not selected.has(row.leg): selected.append(row.leg)
		selected.sort()
	var lines: PackedStringArray = []
	for leg in selected:
		var stats := statistics(service, members, str(leg))
		if stats.count == 0:
			lines.append("%s: no measured arrivals yet." % str(leg).replace(">", " → ").to_upper())
			continue
		var departure := "no scheduled departures measured" if stats.scheduled == 0 else "scheduled departure delay %.1f min (%d trips)" % [stats.departure_delay, stats.scheduled]
		lines.append("%s: %d / %d on time; running %.1f min; positive arrival lateness %.1f min; %s." % [str(leg).replace(">", " → ").to_upper(), stats.on_time, stats.count, stats.travel_minutes, stats.late_minutes, departure])
	return "\n".join(lines)

## Approximate free-running travel time. Origin dwell/dispatch wait are excluded.
static func guidance(length: float, speeds: Array, target: int) -> Dictionary:
	if length <= 0 or not is_finite(length) or speeds.is_empty(): return {"known": false, "text": "Journey guidance unavailable: complete the route and assign a train."}
	var times: Array = []
	for speed in speeds:
		if float(speed) <= 0 or not is_finite(float(speed)): return {"known": false, "text": "Journey guidance unavailable: assigned train speed is unknown."}
		times.append(length / float(speed))
	return travel_guidance(times, target)

static func travel_guidance(times: Array, target: int) -> Dictionary:
	if times.is_empty(): return {"known": false, "text": "Journey guidance unavailable: assign a train."}
	var fastest := INF
	var slowest := 0.0
	for minutes in times:
		if float(minutes) <= 0 or not is_finite(float(minutes)): return {"known": false, "text": "Journey guidance unavailable: travel time is unknown."}
		fastest = minf(fastest, float(minutes))
		slowest = maxf(slowest, float(minutes))
	var status := "off"
	var advice := "Target is off."
	if target > 0:
		if target + 1 < fastest - 1.0 / 60.0:
			status = "short_for_all"
			advice = "Target plus the 1-minute grace is shorter than every assigned train's approximate travel time. Increase it."
		elif target + 1 < slowest - 1.0 / 60.0:
			status = "short_for_slowest"
			advice = "Target plus the 1-minute grace is too short for the slower assigned train. Review the linked fleet or increase it."
		elif target < slowest - 1.0 / 60.0:
			status = "uses_grace"
			advice = "A slower assigned train needs some of the grace window even without traffic. Add margin."
		else:
			status = "unproven"
			advice = "Target covers free-running travel; add margin for traffic and late departures. This does not guarantee on-time arrival."
	return {"known": true, "fastest": fastest, "slowest": slowest, "status": status, "text": "Approximate free-running time: %.1f–%.1f game min across assigned trains. %s" % [fastest, slowest, advice]}

func save_state() -> Dictionary: return {"active": active.duplicate(true), "completed": completed.duplicate(true)}
func restore_state(state: Dictionary) -> void:
	active = state.active.duplicate(true)
	completed = state.completed.duplicate(true)
	for row in active.values() + completed:
		for field in ["train_id", "depart", "planned_depart", "minutes", "due"]: row[field] = int(row[field])
		if row.has("arrive"): row.arrive = int(row.arrive)

static func whole(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

static func valid_row(row: Variant, tick: int, finished: bool, ids: Array = ["a", "b", "c"]) -> bool:
	if not row is Dictionary: return false
	if not row.get("service") is String or not row.get("leg") is String or not row.get("scheduled") is bool: return false
	var leg: PackedStringArray = row.leg.split(">")
	if leg.size() != 2 or not ids.has(leg[0]) or not ids.has(leg[1]) or leg[0] == leg[1]: return false
	if row.service != "passenger":
		var suffix: String = str(row.service).trim_prefix("passenger_")
		if not str(row.service).begins_with("passenger_") or not suffix.is_valid_int() or int(suffix) < 1 or int(suffix) >= 1000000000 or str(int(suffix)) != suffix: return false
	if not whole(row.get("train_id"), 1, 999999999) or not whole(row.get("minutes"), 1, 1440): return false
	for field in ["depart", "planned_depart"]:
		if not whole(row.get(field), 0, tick): return false
	if row.planned_depart > row.depart or (not row.scheduled and row.planned_depart != row.depart): return false
	if not whole(row.get("due"), 0, MAX_TICK + 86400) or row.due != row.planned_depart + row.minutes * 60: return false
	if finished: return whole(row.get("arrive"), int(row.depart), tick)
	return not row.has("arrive")

static func valid_save(value: Variant, data: Dictionary, tick: int, ids: Array = ["a", "b", "c"]) -> bool:
	if not value is Dictionary or not value.get("active") is Dictionary or not value.get("completed") is Array or value.completed.size() > KEEP: return false
	for service in value.active:
		var row: Variant = value.active[service]
		if not valid_row(row, tick, false, ids) or row.service != service or not data.services.has(service): return false
		var config: Dictionary = data.services[service]
		if not Timetable.departure_legs(config.stops, config.get("mode", "shuttle")).has(row.leg): return false
		var found := false
		for train in data.fleet.trains:
			if train.service == service and train.id == row.train_id: found = true
		if not found: return false
		var index: int = int(data.state.passenger_stop_index) if service == "passenger" else int(data.passenger_services[service].stop_index)
		var forward: bool = data.state.travelling_to_b if service == "passenger" else data.passenger_services[service].forward
		var returning: bool = data.runtime.passenger_returning if service == "passenger" else data.passenger_services[service].returning
		if returning or index < 0 or index >= config.stops.size(): return false
		var following: int = (index + 1) % config.stops.size() if config.get("mode", "shuttle") == "loop" else index + (1 if forward else -1)
		if following < 0 or following >= config.stops.size() or row.leg != "%s>%s" % [config.stops[index], config.stops[following]]: return false
	var previous := -1
	for row in value.completed:
		if not valid_row(row, tick, true, ids) or row.arrive < previous: return false
		previous = int(row.arrive)
	return true
