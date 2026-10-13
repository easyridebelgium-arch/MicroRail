extends RefCounted
## Exact departure timetable. One game day is 24 real minutes at 1x (one game
## minute per real second); the clock starts at START_MINUTE. Times are minutes
## after midnight. Pure rules: the game keeps what has been served.
const DAY := 1440
const START_MINUTE := 360
const TICKS_PER_MINUTE := 60
const MAX_ENTRIES := 48

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
