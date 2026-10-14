extends RefCounted
## Passenger intent is independent of locomotive model and reservations.
const LOCAL := "local"
const EXPRESS := "express"
static func distant(origin: String, destination: String) -> bool:
	return (origin == "a" and destination == "c") or (origin == "c" and destination == "a")
static func valid(row: Dictionary) -> bool:
	var kind: Variant = row.get("class", LOCAL)
	if kind == LOCAL: return true
	return kind == EXPRESS and row.get("known", true) == true and distant(str(row.get("origin", "")), str(row.get("destination", "")))
static func eligible(row: Dictionary, destinations: Array, express_destinations: Array) -> bool:
	return destinations.has(row.destination) and (row.get("class", LOCAL) == LOCAL or (row.get("class") == EXPRESS and valid(row) and express_destinations.has(row.destination)))
static func direct(origin: String, future: Array) -> Array:
	return [future[0]] if not future.is_empty() and distant(origin, str(future[0])) else []
static func service_can_carry(config: Dictionary, origin: String, destination: String) -> bool:
	var index: int = config.stops.find(origin)
	var target: int = config.stops.find(destination)
	if index < 0 or target < 0: return false
	return (index + 1) % config.stops.size() == target if config.get("mode", "shuttle") == "loop" else absi(index - target) == 1
static func counts(rows: Array) -> Dictionary:
	var result := {LOCAL: 0, EXPRESS: 0}
	for row in rows: result[str(row.get("class", LOCAL))] += int(row.count)
	return result
static func describe(rows: Array) -> String:
	var totals := counts(rows)
	return "Passenger classes: Local %d / Express %d. Express needs a direct A ↔ C leg; Local accepts stops and transfers." % [totals[LOCAL], totals[EXPRESS]]
static func valid_progress(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2: return false
	for station in ["a", "c"]:
		var number: Variant = value.get(station)
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)) or float(number) != floor(float(number)) or number < 0 or number > 3: return false
	return true
static func migrate(data: Dictionary) -> void:
	if data.get("demand") is Dictionary:
		data.demand["class_progress"] = {"a": 0, "c": 0}
		if data.demand.get("batches") is Dictionary:
			for rows in data.demand.batches.values():
				if rows is Array:
					for row in rows:
						if row is Dictionary: row["class"] = LOCAL
	if data.get("journeys") is Dictionary:
		if data.journeys.get("aboard") is Dictionary:
			for rows in data.journeys.aboard.values():
				if rows is Array:
					for row in rows:
						if row is Dictionary: row["class"] = LOCAL
		if data.journeys.get("completed") is Array:
			for row in data.journeys.completed:
				if row is Dictionary: row["class"] = LOCAL
