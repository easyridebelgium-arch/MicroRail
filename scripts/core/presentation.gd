extends RefCounted
## Saved appearance/acknowledgement choices, independent of simulation routes.
const COLOURS := ["#56B4E9", "#E69F00", "#009E73", "#CC79A7", "#D55E00", "#F0E442", "#A6CEE3", "#FFFFFF"]
const NAMES := ["Sky", "Amber", "Teal", "Violet", "Coral", "Yellow", "Pale blue", "White"]
static func defaults() -> Dictionary: return {"routes": {}, "acknowledged": {}}
static func source(services: Dictionary, key: String) -> String:
	return str(services.get(key, {}).get("link", key))
static func identity(services: Dictionary, state: Dictionary, key: String) -> Dictionary:
	key = source(services, key)
	var ordinal := 1 if key == "passenger" else 2 if key == "freight" else int(key.trim_prefix("passenger_"))
	return state.routes.get(key, {"label": "F" if key == "freight" else "P%d" % ordinal, "colour": posmod(ordinal - 1, COLOURS.size())}).duplicate(true)
static func label_valid(text: String) -> bool:
	if text.is_empty() or text.length() > 6: return false
	for letter in text:
		if not "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-".contains(letter): return false
	return true
static func valid(value: Variant, services: Dictionary) -> bool:
	if not value is Dictionary or not value.get("routes") is Dictionary or not value.get("acknowledged") is Dictionary: return false
	for key in value.routes:
		if not services.has(key): return false
		var row: Variant = value.routes[key]
		if not row is Dictionary or not row.get("label") is String or not label_valid(row.label): return false
		var index: Variant = row.get("colour")
		if typeof(index) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(index)) or float(index) != floor(float(index)) or float(index) < 0 or float(index) >= COLOURS.size(): return false
	if value.acknowledged.size() > 100: return false
	for key in value.acknowledged:
		if not key is String or key.length() > 80 or not value.acknowledged[key] is String or value.acknowledged[key].length() > 1500: return false
	return true
static func normalize(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	for key in result.routes: result.routes[key].colour = int(result.routes[key].colour)
	return result
