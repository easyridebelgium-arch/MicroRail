extends RefCounted
## Cumulative actual receipts; independent of the bounded journey history.
const Classes = preload("res://scripts/core/passenger_classes.gd")
const LOCAL_FARE := Classes.LOCAL_FARE
const EXPRESS_FARE := Classes.EXPRESS_FARE
const MAX_PASSENGERS := 1_000_000_000
var state: Dictionary = defaults()
static func defaults() -> Dictionary:
	return {"local": {"passengers": 0, "income": 0}, "express": {"passengers": 0, "income": 0}, "legacy": {"passengers": 0, "income": 0}}
func record(counts: Dictionary) -> int:
	var received := 0
	for kind in [Classes.LOCAL, Classes.EXPRESS]:
		var count := int(counts.get(kind, 0))
		var income := count * (LOCAL_FARE if kind == Classes.LOCAL else EXPRESS_FARE)
		state[kind].passengers += count
		state[kind].income += income
		received += income
	return received
func total() -> int:
	var income := 0
	for row in state.values(): income += int(row.income)
	return income
func summary() -> String:
	return "Passenger revenue recorded: £%d\nLocal: %d passengers, £%d (£%d each)\nExpress: %d passengers, £%d (£%d each)\nLegacy flat-fare deliveries: %d passengers, £%d. Historical class split unavailable; these passengers already paid £5.\nReceipts are cumulative, credited once at the final destination; transfers and unfinished recovery do not pay. No punctuality bonus/penalty or price-response modifier." % [total(), state.local.passengers, state.local.income, LOCAL_FARE, state.express.passengers, state.express.income, EXPRESS_FARE, state.legacy.passengers, state.legacy.income]
func save_state() -> Dictionary: return state.duplicate(true)
func restore_state(value: Dictionary) -> void:
	state = value.duplicate(true)
	for row in state.values():
		row.passengers = int(row.passengers)
		row.income = int(row.income)
static func whole(value: Variant, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and value >= 0 and value <= maximum
static func valid_save(value: Variant, delivered: Variant) -> bool:
	if not whole(delivered, MAX_PASSENGERS) or not value is Dictionary or value.size() != 3: return false
	var count := 0
	for kind in ["local", "express", "legacy"]:
		var row: Variant = value.get(kind)
		if not row is Dictionary or row.size() != 2: return false
		if not whole(row.get("passengers"), MAX_PASSENGERS) or not whole(row.get("income"), MAX_PASSENGERS * EXPRESS_FARE): return false
		var fare := EXPRESS_FARE if kind == "express" else LOCAL_FARE
		if row.income != row.passengers * fare: return false
		count += int(row.passengers)
	return count == int(delivered)
static func migrate(data: Dictionary) -> void:
	var value := defaults()
	var saved: Variant = data.get("state", {})
	if saved is Dictionary and whole(saved.get("passengers_delivered"), MAX_PASSENGERS):
		value.legacy.passengers = int(saved.passengers_delivered)
		value.legacy.income = value.legacy.passengers * LOCAL_FARE
	data["passenger_revenue"] = value
