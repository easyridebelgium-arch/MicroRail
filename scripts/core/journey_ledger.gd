extends RefCounted
## Original journey clock survives vehicle changes and physical recovery.
const Demand = preload("res://scripts/core/passenger_demand.gd")
const Classes = preload("res://scripts/core/passenger_classes.gd")
const LIMIT := 128
var aboard: Dictionary = {}
var completed: Array = []
var unknown_completed := 0
static func counts(rows: Array) -> Dictionary:
	var result: Dictionary = {}
	for row in rows: result[row.destination] = int(result.get(row.destination, 0)) + int(row.count)
	return result
func ensure(key: String, manifest: Dictionary, tick: int) -> void:
	if Demand.normalize(counts(aboard.get(key, []))) == Demand.normalize(manifest):
		if not aboard.has(key): aboard[key] = []
		return
	aboard[key] = []
	for destination in Demand.STATIONS:
		if int(manifest.get(destination, 0)) > 0: aboard[key].append({"destination": destination, "origin": "unknown", "start": tick, "known": false, "count": int(manifest[destination]), "class": Classes.LOCAL})
func board(key: String, groups: Array) -> void:
	for group in groups:
		var merged := false
		for row in aboard[key]:
			if row.destination == group.destination and row.origin == group.origin and row.start == group.start and row.known == group.known and row.get("class", Classes.LOCAL) == group.get("class", Classes.LOCAL):
				row.count += int(group.count)
				merged = true
				break
		if not merged: aboard[key].append(group.duplicate(true))
func release(key: String, destinations: Array) -> Array:
	var result: Array = []
	var kept: Array = []
	for row in aboard.get(key, []):
		if destinations.has(row.destination): result.append(row.duplicate(true))
		else: kept.append(row)
	aboard[key] = kept
	return result
func finish(key: String, station: String, manifest: Dictionary, tick: int) -> void:
	ensure(key, manifest, tick)
	for row in release(key, [station]):
		if not row.known:
			unknown_completed += int(row.count)
			continue
		var sample: Dictionary = row.duplicate(true)
		sample.erase("known")
		sample["end"] = tick
		completed.append(sample)
		if completed.size() > LIMIT: completed.pop_front()
func summary() -> String:
	var count := 0
	var elapsed := 0.0
	var longest := 0
	for row in completed:
		var duration := int(row.end) - int(row.start)
		count += int(row.count)
		elapsed += float(duration) * float(row.count)
		longest = maxi(longest, duration)
	var result := "Completed journey time: no measured completions yet" if count == 0 else "Completed journey time: %.1fs average, %.1fs longest — %d passengers" % [elapsed / count / 60.0, float(longest) / 60.0, count]
	result += "\nUnmeasured completed deliveries (including legacy): %d\nLast 128 completed groups, passenger-weighted. Includes original queue wait, onboard travel/dwell/delays, transfers and recovery; simulation seconds. This is elapsed time, not lateness or a satisfaction penalty." % unknown_completed
	for origin in Demand.STATIONS:
		for destination in Demand.STATIONS:
			var passengers := 0
			var duration_sum := 0.0
			for row in completed:
				if row.origin == origin and row.destination == destination:
					passengers += int(row.count)
					duration_sum += float(int(row.end) - int(row.start)) * float(row.count)
			if passengers > 0: result += "\n%s → %s: %d passengers, %.1fs average" % [origin.to_upper(), destination.to_upper(), passengers, duration_sum / passengers / 60.0]
	return result
func describe_train(key: String, manifest: Dictionary, tick: int) -> String:
	if Demand.total(manifest) == 0: return "Journey timing: no passengers aboard"
	if Demand.normalize(counts(aboard.get(key, []))) != Demand.normalize(manifest): return "Journey timing: origins unknown for this manifest"
	var measured := 0
	var oldest := tick
	for row in aboard.get(key, []):
		if row.known:
			measured += int(row.count)
			oldest = mini(oldest, int(row.start))
	if measured == 0: return "Journey timing: origins/starts unknown for %d passengers; elapsed unavailable" % Demand.total(manifest)
	return "Journey timing: %d / %d passengers tracked; oldest tracked elapsed %.1fs from original queue arrival" % [measured, Demand.total(manifest), float(tick - oldest) / 60.0]
func save_state(manifests: Dictionary, tick: int) -> Dictionary:
	for key in manifests: ensure(key, manifests[key], tick)
	for key in aboard.keys():
		if not manifests.has(key): aboard.erase(key)
	return {"aboard": aboard.duplicate(true), "completed": completed.duplicate(true), "unknown_completed": unknown_completed}
func restore_state(data: Dictionary) -> void:
	aboard = data.aboard.duplicate(true)
	completed = data.completed.duplicate(true)
	unknown_completed = int(data.unknown_completed)
	for rows in aboard.values():
		for row in rows:
			row.count = int(row.count)
			row.start = int(row.start)
	for row in completed:
		for field in ["count", "start", "end"]: row[field] = int(row[field])
static func integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high
static func valid_row(row: Variant, tick: int, finished: bool = false) -> bool:
	if not row is Dictionary or not Demand.STATIONS.has(row.get("destination")) or not Classes.valid(row): return false
	if not integer(row.get("count"), 1, 1000000000) or not integer(row.get("start"), 0, tick): return false
	if finished:
		return Demand.STATIONS.has(row.get("origin")) and row.origin != row.destination and integer(row.get("end"), int(row.start), tick)
	if not row.get("known") is bool: return false
	return (Demand.STATIONS.has(row.get("origin")) and row.origin != row.destination) if row.known else (row.get("origin") == "unknown" or Demand.STATIONS.has(row.get("origin")))
static func manifests(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if not data.get("demand") is Dictionary or not data.demand.get("primary") is Dictionary: return result
	if not data.get("services") is Dictionary or not data.get("passenger_services") is Dictionary: return result
	for key in data.services:
		if key == "freight": continue
		if key == "passenger": result[key] = data.demand.primary
		else:
			var running: Variant = data.passenger_services.get(key)
			if not running is Dictionary or not running.get("passenger_destinations") is Dictionary: return {}
			result[key] = running.passenger_destinations
	return result
static func valid_save(value: Variant, data: Dictionary, tick: int) -> bool:
	if not value is Dictionary or not value.get("aboard") is Dictionary or not value.get("completed") is Array: return false
	if not integer(value.get("unknown_completed"), 0, 1000000000) or value.completed.size() > LIMIT: return false
	var loads := manifests(data)
	if loads.is_empty() or loads.size() != value.aboard.size(): return false
	for key in loads:
		if not Demand.valid_counts(loads[key], Demand.STATIONS): return false
		var rows: Variant = value.aboard.get(key)
		if not rows is Array or rows.size() > Demand.total(loads[key]): return false
		for row in rows:
			if not valid_row(row, tick): return false
			if row.get("class", Classes.LOCAL) == Classes.EXPRESS and not Classes.service_can_carry(data.services[key], row.origin, row.destination): return false
		if Demand.normalize(counts(rows)) != Demand.normalize(loads[key]): return false
	var delivered := int(value.unknown_completed)
	var previous := 0
	for row in value.completed:
		if not valid_row(row, tick, true) or int(row.end) < previous: return false
		previous = int(row.end)
		delivered += int(row.count)
	return integer(data.get("state", {}).get("passengers_delivered"), delivered, 1000000000)
static func migrate(data: Dictionary) -> void:
	var tick := 0
	if data.get("sim") is Dictionary and data.sim.get("clock") is Dictionary:
		var clock: Variant = data.sim.clock.get("tick")
		if integer(clock, 0, 1000000000000): tick = int(clock)
	if data.get("demand") is Dictionary and data.demand.get("batches") is Dictionary:
		for station in Demand.STATIONS:
			var rows: Variant = data.demand.batches.get(station)
			if not rows is Array: continue
			for row in rows:
				if not row is Dictionary: continue
				row["origin"] = "unknown"
				row["start"] = row.get("tick", tick)
				row["known"] = false
	var loads := manifests(data)
	var occupied: Dictionary = {}
	for key in loads:
		occupied[key] = []
		if not Demand.valid_counts(loads[key], Demand.STATIONS): continue
		for destination in Demand.STATIONS:
			if int(loads[key].get(destination, 0)) > 0: occupied[key].append({"origin": "unknown", "destination": destination, "start": tick, "known": false, "count": int(loads[key][destination])})
	var saved_state: Variant = data.get("state")
	var delivered: Variant = saved_state.get("passengers_delivered", 0) if saved_state is Dictionary else 0
	data["journeys"] = {"aboard": occupied, "completed": [], "unknown_completed": int(delivered) if integer(delivered, 0, 1000000000) else 0}
