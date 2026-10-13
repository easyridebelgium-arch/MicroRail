extends RefCounted
## Exact departure timetable. One game day is 24 real minutes at 1x (one game
## minute per real second); the clock starts at START_MINUTE. Times are minutes
## after midnight. Pure rules: the game keeps what has been served.
const DAY := 1440
const START_MINUTE := 360
const TICKS_PER_MINUTE := 60
const MAX_ENTRIES := 48

## Every departing station pair, including reverse legs of a Shuttle.
static func departure_legs(stops: Array, mode: String) -> Array[String]:
	var result: Array[String] = []
	for index in range(stops.size() - 1): result.append("%s>%s" % [stops[index], stops[index + 1]])
	if mode == "loop": result.append("%s>%s" % [stops.back(), stops[0]])
	else:
		for index in range(stops.size() - 1, 0, -1): result.append("%s>%s" % [stops[index], stops[index - 1]])
	return result

static func valid_times(value: Variant) -> bool:
	if not value is Array or value.size() > MAX_ENTRIES: return false
	var previous := -1
	for minute in value:
		if not _integer(minute) or minute < 0 or minute >= DAY or int(minute) <= previous: return false
		previous = int(minute)
	return true

static func schedule_map(services: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for group in services:
		if group == "freight" or services[group].has("link"): continue
		var config: Dictionary = services[group]
		if config.get("timetable", []).is_empty() and config.get("stop_timetables", {}).is_empty(): continue
		var legs := departure_legs(config.stops, config.get("mode", "shuttle"))
		for index in range(legs.size()):
			var times: Array = config.get("timetable", []) if index == 0 else config.get("stop_timetables", {}).get(legs[index], [])
			if not times.is_empty(): result[group if index == 0 else group + ":" + legs[index]] = times
	return result

## Dispatch progress is validated before loading any world state.
static func valid_dispatch(value: Variant, services: Dictionary, tick: int) -> bool:
	if not value is Dictionary or not value.get("timetables") is Dictionary or not value.get("headways") is Dictionary: return false
	var schedules := schedule_map(services)
	var now := absolute_minute(tick)
	for key in value.timetables:
		if not schedules.has(key): return false
		var state: Variant = value.timetables[key]
		if not state is Dictionary or state.get("times") != schedules[key]: return false
		var group: String = str(key).get_slice(":", 0)
		var leg: String = str(key).get_slice(":", 1) if str(key).contains(":") else "%s>%s" % [services[group].stops[0], services[group].stops[1]]
		if state.get("leg") != leg: return false
		if not _integer(state.get("last")) or state.last < -1 or state.last > now: return false
		for field in ["served", "missed"]:
			if not _integer(state.get(field)) or state[field] < 0 or state[field] > 1000000000: return false
		if not state.get("delays") is Array or state.delays.size() > 128: return false
		for delay in state.delays:
			if not _integer(delay) or delay < 0 or delay > now: return false
	for key in value.headways:
		if not services.has(key) or key == "freight" or services[key].has("link"): return false
		var log: Variant = value.headways[key]
		if not log is Array or log.size() > 128: return false
		var previous := -1
		for departure in log:
			if not _integer(departure) or departure < 0 or departure > tick or departure < previous: return false
			previous = int(departure)
	return true

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value))

static func normalize_dispatch(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	for key in result.timetables:
		var state: Dictionary = result.timetables[key]
		for field in ["last", "served", "missed"]: state[field] = int(state[field])
		for field in ["times", "delays"]:
			var numbers: Array = []
			for number in state[field]: numbers.append(int(number))
			state[field] = numbers
	for key in result.headways:
		var numbers: Array = []
		for number in result.headways[key]: numbers.append(int(number))
		result.headways[key] = numbers
	return result

## Absolute game minutes (since day 1 midnight) at a simulation tick.
static func absolute_minute(tick: int) -> int:
	return START_MINUTE + tick / TICKS_PER_MINUTE

static func format(minute: int) -> String:
	var m := posmod(minute, DAY)
	return "%02d:%02d" % [m / 60, m % 60]

static func clock_text(absolute: int) -> String:
	return "Day %d  %s" % [absolute / DAY + 1, format(absolute)]

## Parses "06:30, 7:00 18:15" into sorted unique minutes. {"ok", "times", "error"}.
static func parse(text: String) -> Dictionary:
	var times: Array = []
	var cleaned := text.replace(",", " ").replace(";", " ")
	for token in cleaned.split(" ", false):
		var parts := token.split(":")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			return {"ok": false, "times": [], "error": "'%s' is not a time. Use HH:MM, separated by commas." % token}
		var hours := int(parts[0])
		var minutes := int(parts[1])
		if hours < 0 or hours > 23 or minutes < 0 or minutes > 59 or parts[1].length() != 2:
			return {"ok": false, "times": [], "error": "'%s' is not a time between 00:00 and 23:59." % token}
		var minute := hours * 60 + minutes
		if not times.has(minute): times.append(minute)
	times.sort()
	if times.size() > MAX_ENTRIES: return {"ok": false, "times": [], "error": "At most %d departures a day." % MAX_ENTRIES}
	return {"ok": true, "times": times, "error": ""}

static func to_text(times: Array) -> String:
	var parts: PackedStringArray = []
	for minute in times: parts.append(format(int(minute)))
	return ", ".join(parts)

## Absolute scheduled times in (after, up_to].
static func slots_between(times: Array, after: int, up_to: int) -> Array:
	var result: Array = []
	if times.is_empty() or up_to <= after: return result
	for day in range(maxi(0, after) / DAY, up_to / DAY + 1):
		for minute in times:
			var slot: int = day * DAY + int(minute)
			if slot > after and slot <= up_to: result.append(slot)
	return result

## Smallest scheduled time strictly after `after`.
static func next_slot(times: Array, after: int) -> int:
	if times.is_empty(): return -1
	for day in range(maxi(0, after) / DAY, maxi(0, after) / DAY + 2):
		for minute in times:
			var slot: int = day * DAY + int(minute)
			if slot > after: return slot
	return -1

## Smallest gap between consecutive departures over a day (wrapping midnight).
static func tightest_gap(times: Array) -> int:
	if times.size() < 2: return DAY
	var gap := DAY
	for index in range(times.size()):
		var following: int = int(times[(index + 1) % times.size()])
		var diff: int = following - int(times[index])
		if diff <= 0: diff += DAY
		gap = mini(gap, diff)
	return gap
