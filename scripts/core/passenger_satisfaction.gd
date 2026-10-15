extends RefCounted
## Waiting experience, not a claim about journey time or timetable punctuality.
const STATIONS: Array[String] = ["a", "b", "c"]
var station_ids: Array[String] = []
const MAX_GROUPS := 128
const GRACE_TICKS := 15 * 60
const PENALTY_TICKS := 3 * 60
const COMFORT := {"shelter": 3, "waiting_room": 5, "kiosk": 2}
var history: Dictionary = {}
func _init(ids: Array = STATIONS) -> void:
	station_ids.assign(ids)
	station_ids.sort()
	history = defaults(station_ids)
static func defaults(ids: Array = STATIONS) -> Dictionary:
	var result: Dictionary = {}
	for key in ids: result[key] = []
	return result
static func comfort(owned: Array) -> int:
	var result := 0
	for id in COMFORT:
		if owned.has(id): result += int(COMFORT[id])
	return result
static func score(wait_ticks: int, bonus: int) -> int:
	var penalty := mini(90, floori(float(maxi(0, wait_ticks - GRACE_TICKS)) / PENALTY_TICKS))
	return clampi(100 - penalty + bonus, 0, 100)
func record(station_key: String, groups: Array, tick: int, owned: Array) -> void:
	var bonus := comfort(owned)
	for group in groups:
		if int(group.count) <= 0: continue
		history[station_key].append({"count": int(group.count), "tick": tick, "wait": int(group.wait), "comfort": bonus})
		if history[station_key].size() > MAX_GROUPS: history[station_key].pop_front()
func station(station_key: String, queues: Array, tick: int, owned: Array) -> Dictionary:
	var count := 0
	var points := 0
	var waited := 0.0
	for row in history[station_key]:
		count += int(row.count)
		points += int(row.count) * score(int(row.wait), int(row.comfort))
		waited += float(row.count) * float(row.wait)
	var boarded := count
	for row in queues:
		var waiting := maxi(0, tick - int(row.tick))
		count += int(row.count)
		points += int(row.count) * score(waiting, comfort(owned))
		waited += float(row.count) * float(waiting)
	return {"count": count, "points": points, "waited": waited, "boarded": boarded, "rating": roundi(float(points) / count) if count > 0 else -1, "seconds": waited / count / 60.0 if count > 0 else 0.0}
func company(demand: RefCounted, tick: int, amenities: RefCounted) -> Dictionary:
	var count := 0
	var points := 0
	for key in station_ids:
		var row := station(key, demand.waiting_groups(key, tick), tick, amenities.owned[key])
		count += int(row.count)
		points += int(row.points)
	return {"count": count, "rating": roundi(float(points) / count) if count > 0 else -1}
func describe(station_key: String, demand: RefCounted, tick: int, amenities: RefCounted) -> String:
	var row := station(station_key, demand.waiting_groups(station_key, tick), tick, amenities.owned[station_key])
	var title := "Waiting satisfaction: no data yet" if row.rating < 0 else "Waiting satisfaction: %d / 100" % row.rating
	return "%s\nAverage measured station wait: %.1fs; %d recent boarding experiences plus %d currently waiting.\nComfort bonus: +%d (Shelter +3, Waiting room +5, Kiosk +2). First 15s incur no penalty; each extra 3s subtracts 1 point, capped at 90.\nOlder waits lower the rating. Add usable service capacity/frequency or repair blocked routes; comfort helps but cannot replace service.\nIncludes current queues and the last 128 boarding groups here, weighted by passengers. Recorded comfort is the bonus at boarding. Transfers count as separate station experiences. Journey time, punctuality and fares are not rated yet." % [title, row.seconds, row.boarded, demand.waiting(station_key), comfort(amenities.owned[station_key])]
func save_state() -> Dictionary: return history.duplicate(true)
func restore_state(value: Dictionary, ids: Array = STATIONS) -> void:
	station_ids.assign(ids)
	station_ids.sort()
	history = defaults(station_ids)
	for key in station_ids:
		for row in value[key]: history[key].append({"count": int(row.count), "tick": int(row.tick), "wait": int(row.wait), "comfort": int(row.comfort)})
static func integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high
static func valid_state(value: Variant, tick: int, ids: Array = STATIONS) -> bool:
	if not preload("res://scripts/core/passenger_demand.gd").valid_ids(ids): return false
	if not value is Dictionary or value.size() != ids.size(): return false
	for key in ids:
		var rows: Variant = value.get(key)
		if not rows is Array or rows.size() > MAX_GROUPS: return false
		var previous := 0
		for row in rows:
			if not row is Dictionary: return false
			if not integer(row.get("count"), 1, 1000000000) or not integer(row.get("tick"), previous, tick): return false
			if not integer(row.get("wait"), 0, int(row.tick)) or not integer(row.get("comfort"), 0, 10): return false
			previous = int(row.tick)
	return true
