extends RefCounted
## Observational fixed-tick measurements. Recent history resets on load.
const WINDOW_SECONDS := 120
const TICKS_PER_SECOND := 60
const MAX_BOARDINGS := 128
var buckets: Dictionary = {}
var boardings: Array = []
var last_tick := -1

func reset() -> void:
	buckets.clear()
	boardings.clear()
	last_tick = -1

func sample(tick: int, trains: Array) -> void:
	if tick <= last_tick: return
	last_tick = tick
	var second := int(floor(float(tick) / TICKS_PER_SECOND))
	for old in buckets.keys():
		if int(old) <= second - WINDOW_SECONDS: buckets.erase(old)
	if trains.is_empty(): return
	if not buckets.has(second): buckets[second] = {}
	var seen: Dictionary = {}
	for train in trains:
		var id := int(train.id)
		if seen.has(id): continue
		seen[id] = true
		var capacity := int(train.capacity)
		if capacity <= 0: continue
		var passengers := clampi(int(train.passengers), 0, capacity)
		if not buckets[second].has(id): buckets[second][id] = {"ticks": 0, "passenger_ticks": 0, "seat_ticks": 0, "full_ticks": 0}
		var row: Dictionary = buckets[second][id]
		row.ticks += 1
		row.passenger_ticks += passengers
		row.seat_ticks += capacity
		if passengers == capacity: row.full_ticks += 1

func boarding(tick: int, id: int, station: String, boarded: int, eligible_left: int, onboard: int, capacity: int) -> void:
	# A call is one boarding opportunity, even if all seats were already taken.
	boardings.append({"tick": tick, "id": id, "station": station, "boarded": boarded, "left": eligible_left if onboard >= capacity else 0})
	while boardings.size() > MAX_BOARDINGS: boardings.pop_front()

func statistics(id: int = -1) -> Dictionary:
	var result := {"ticks": 0, "passenger_ticks": 0, "seat_ticks": 0, "full_ticks": 0, "boardings": 0, "boarded": 0, "left": 0}
	for bucket in buckets.values():
		for train_id in bucket:
			if id >= 0 and int(train_id) != id: continue
			for field in ["ticks", "passenger_ticks", "seat_ticks", "full_ticks"]: result[field] += int(bucket[train_id][field])
	for row in boardings:
		if id >= 0 and int(row.id) != id: continue
		result.boardings += 1
		result.boarded += int(row.boarded)
		result.left += int(row.left)
	return result

func describe(id: int = -1) -> String:
	var stats := statistics(id)
	var lines: PackedStringArray = []
	if stats.ticks == 0:
		lines.append("Recent occupancy: no service samples yet.")
	else:
		lines.append("Recent occupancy: %.1f%% of available seat-time; full %.1f%% of measured train-time (last ~120 simulation seconds)." % [100.0 * stats.passenger_ticks / stats.seat_ticks, 100.0 * stats.full_ticks / stats.ticks])
	lines.append("Recent boarding opportunities: %d; boarded %d; eligible passengers left behind for lack of seats: %d." % [stats.boardings, stats.boarded, stats.left])
	return "\n".join(lines)

func summary() -> String:
	var lines: PackedStringArray = ["Passenger occupancy and capacity", describe()]
	for station in ["a", "b", "c"]:
		var left := 0
		for row in boardings:
			if row.station == station: left += int(row.left)
		lines.append("Station %s: %d left-behind opportunities." % [station.to_upper(), left])
	lines.append("Boarding history covers the latest 128 opportunities; repeated waits may count the same person again. Occupancy includes station dwell, traffic waits and dispatcher holds for enabled services, plus withdrawn trains finishing journeys. Stored trains are excluded. These measurements reset on load and do not affect fares, satisfaction or demand.")
	return "\n".join(lines)
