extends RefCounted
## Small immutable scenario definitions; completion uses final city deliveries.
const Numbers = preload("res://scripts/core/arrival_targets.gd")
const DEFINITIONS := {
	"first_connection": {"name": "First Connection", "seed": "42", "cities": 3, "deliveries": 40, "served": 2, "no_loans": false},
	"three_towns": {"name": "Three Town Link", "seed": "7", "cities": 3, "deliveries": 75, "served": 3, "no_loans": true}
}
var state: Dictionary = {"id": "", "completed_tick": -1}
func initialize(id: String) -> void: state = {"id": id if DEFINITIONS.has(id) else "", "completed_tick": -1}
func no_loans() -> bool: return bool(DEFINITIONS.get(state.id, {}).get("no_loans", false))
static func progress(measurements: Dictionary) -> Dictionary:
	var delivered := 0
	var served := 0
	for city in measurements.get("cities", {}).values():
		var count := int(city.totals.delivered)
		delivered += count
		if count >= 5: served += 1
	return {"delivered": delivered, "served": served}
func advance(tick: int, measurements: Dictionary) -> bool:
	if state.id == "" or int(state.completed_tick) >= 0: return false
	var config: Dictionary = DEFINITIONS[state.id]
	var measured := progress(measurements)
	if measured.delivered < config.deliveries or measured.served < config.served: return false
	state.completed_tick = tick
	return true
static func description(id: String) -> String:
	if not DEFINITIONS.has(id): return ""
	var row: Dictionary = DEFINITIONS[id]
	return "%s — seed %s, %d cities, £5000.\nComplete %d final city passenger journeys, including at least five by residents of each of %d different cities.\n%s No deadline, no bonus money. Completed journeys count once; queues and transfers do not qualify. Completion is saved and play can continue." % [row.name, row.seed, row.cities, row.deliveries, row.served, "Bank borrowing is disabled for this company." if row.no_loans else "Ordinary bank loans are available."]
func save_state() -> Dictionary: return state.duplicate(true)
func restore_state(value: Dictionary) -> void:
	state = value.duplicate(true)
	state.completed_tick = int(state.completed_tick)
static func valid(value: Variant, data: Dictionary, tick: int) -> bool:
	if not value is Dictionary or value.size() != 2 or not value.get("id") is String or not Numbers.whole(value.get("completed_tick"), -1, tick): return false
	if value.id == "": return int(value.completed_tick) == -1
	if not DEFINITIONS.has(value.id) or data.get("game_mode") != "cities": return false
	var row: Dictionary = DEFINITIONS[value.id]
	if data.world.layout_seed != row.seed or data.world.settlements.size() != row.cities: return false
	if row.no_loans and (not data.get("loans") is Dictionary or not Numbers.whole(data.loans.get("borrowed"), 0, 0)): return false
	if int(value.completed_tick) >= 0:
		var measured: Dictionary = progress(data.city_service)
		if measured.delivered < row.deliveries or measured.served < row.served: return false
	return true
