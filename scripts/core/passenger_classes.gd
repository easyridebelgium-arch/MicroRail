extends RefCounted
## Passenger intent is independent of locomotive model and reservations.
const LOCAL := "local"
const EXPRESS := "express"
const LOCAL_FARE := 5
const EXPRESS_FARE := 10
const EXPRESS_DISTANCE_TILES := 32
const DEFAULT_CATALOG = preload("res://scripts/service_routes.gd").STATIONS
static func distant(origin: String, destination: String, catalog: Dictionary = DEFAULT_CATALOG) -> bool:
	if origin == destination or not catalog.has(origin) or not catalog.has(destination): return false
	var delta: Vector2i = catalog[origin].cell - catalog[destination].cell
	return delta.length_squared() >= EXPRESS_DISTANCE_TILES * EXPRESS_DISTANCE_TILES
static func valid(row: Dictionary, catalog: Dictionary = DEFAULT_CATALOG) -> bool:
	var kind: Variant = row.get("class", LOCAL)
	if kind == LOCAL: return true
	return kind == EXPRESS and row.get("known", true) == true and distant(str(row.get("origin", "")), str(row.get("destination", "")), catalog)
static func eligible(row: Dictionary, destinations: Array, express_destinations: Array, catalog: Dictionary = DEFAULT_CATALOG) -> bool:
	return destinations.has(row.destination) and (row.get("class", LOCAL) == LOCAL or (row.get("class") == EXPRESS and valid(row, catalog) and express_destinations.has(row.destination)))
static func direct(origin: String, future: Array, catalog: Dictionary = DEFAULT_CATALOG) -> Array:
	return [future[0]] if not future.is_empty() and distant(origin, str(future[0]), catalog) else []
static func service_can_carry(config: Dictionary, origin: String, destination: String) -> bool:
	var index: int = config.stops.find(origin)
	var target: int = config.stops.find(destination)
	if index < 0 or target < 0: return false
	return (index + 1) % config.stops.size() == target if config.get("mode", "shuttle") == "loop" else absi(index - target) == 1
static func counts(rows: Array) -> Dictionary:
	var result := {LOCAL: 0, EXPRESS: 0}
	for row in rows: result[str(row.get("class", LOCAL))] += int(row.count)
	return result
static func describe(rows: Array, catalog: Dictionary = DEFAULT_CATALOG) -> String:
	var totals := counts(rows)
	var rule := "needs a direct next scheduled stop at least %d tiles away" % EXPRESS_DISTANCE_TILES
	if catalog.is_empty(): rule += "; no stations exist in this layout yet"
	return "Passenger classes: Local %d / Express %d. Local pays £%d; Express pays £%d and %s. Local accepts stops and transfers." % [totals[LOCAL], totals[EXPRESS], LOCAL_FARE, EXPRESS_FARE, rule]
static func progress_defaults(catalog: Dictionary = DEFAULT_CATALOG) -> Dictionary:
	var result: Dictionary = {}
	var ids := catalog.keys()
	ids.sort()
	for origin in ids:
		for destination in ids:
			if distant(origin, destination, catalog):
				result[origin] = 0
				break
	return result
static func valid_progress(value: Variant, catalog: Dictionary = DEFAULT_CATALOG) -> bool:
	var expected := progress_defaults(catalog)
	if not value is Dictionary or value.size() != expected.size(): return false
	for station in expected:
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
