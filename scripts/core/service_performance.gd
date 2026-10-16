extends RefCounted
## Saved actual passenger receipts/expenses and completed stop outcomes.
## Counters follow a service identity, including route edits and train replacements.
const Numbers = preload("res://scripts/core/arrival_targets.gd")
const Revenue = preload("res://scripts/core/passenger_revenue.gd")
const MAX_COUNT := 1_000_000_000_000_000
const FIELDS := ["finals", "transfers", "income", "cost"]
var state: Dictionary = defaults()
static func defaults(tick: int = 0) -> Dictionary:
	return {"since": tick, "services": {}}
func record(key: String, field: String, amount: int) -> void:
	if amount <= 0 or field not in FIELDS: return
	if not state.services.has(key): state.services[key] = {"finals": 0, "transfers": 0, "income": 0, "cost": 0}
	state.services[key][field] += amount
func totals(members: Array) -> Dictionary:
	var result := {"finals": 0, "transfers": 0, "income": 0, "cost": 0}
	for key in members:
		for field in FIELDS: result[field] += int(state.services.get(key, {}).get(field, 0))
	return result
func save_state(services: Dictionary) -> Dictionary:
	var result := state.duplicate(true)
	for key in result.services.keys():
		if not services.has(key): result.services.erase(key)
	return result
func restore_state(value: Dictionary) -> void:
	state = value.duplicate(true)
	state.since = int(state.since)
	for row in state.services.values():
		for field in FIELDS: row[field] = int(row[field])
static func valid(value: Variant, data: Dictionary, tick: int) -> bool:
	if not value is Dictionary or value.size() != 2 or not Numbers.whole(value.get("since"), 0, tick) or not value.get("services") is Dictionary: return false
	var finals := 0
	var income := 0
	var cost := 0
	for key in value.services:
		if not data.services.has(key) or key == "freight": return false
		var row: Variant = value.services[key]
		if not row is Dictionary or row.size() != FIELDS.size(): return false
		for field in FIELDS:
			if not Numbers.whole(row.get(field), 0, MAX_COUNT): return false
		if int(row.income) < int(row.finals) * Revenue.LOCAL_FARE or int(row.income) > int(row.finals) * Revenue.EXPRESS_FARE: return false
		finals += int(row.finals)
		income += int(row.income)
		cost += int(row.cost)
	# A removed service may no longer contribute to these rows. Migration starts
	# a fresh baseline; older company totals must not be invented per route.
	if not data.get("state") is Dictionary or not data.get("passenger_revenue") is Dictionary: return false
	var receipts := 0
	for row in data.passenger_revenue.values():
		if not row is Dictionary or not Numbers.whole(row.get("income"), 0, MAX_COUNT): return false
		receipts += int(row.income)
	return Numbers.whole(data.state.get("passengers_delivered"), finals, MAX_COUNT) and Numbers.whole(data.state.get("total_operating_cost"), cost, MAX_COUNT) and income <= receipts
