extends RefCounted
## Small immutable scenario definitions; completion uses final city deliveries.
const Generator = preload("res://scripts/core/world_generator.gd")
const Numbers = preload("res://scripts/core/arrival_targets.gd")
const DEFINITIONS := {
	"first_connection": {"name": "First Connection", "seed": "42", "cities": 3, "deliveries": 40, "served": 2, "no_loans": false},
	"three_towns": {"name": "Three Town Link", "seed": "7", "cities": 3, "deliveries": 75, "served": 3, "no_loans": true},
	"river_connection": {"name": "Across the River", "seed": "42", "cities": 3, "deliveries": 40, "served": 2, "no_loans": false, "terrain": "river_v1", "origin": "town:03"}
}
var state: Dictionary = {"id": "", "completed_tick": -1}
func initialize(id: String) -> void: state = {"id": id if DEFINITIONS.has(id) else "", "completed_tick": -1}
func no_loans() -> bool: return bool(DEFINITIONS.get(state.id, {}).get("no_loans", false))
static func progress(measurements: Dictionary, origin: String = "") -> Dictionary:
	var delivered := 0
	var served := 0
	for id in measurements.get("cities", {}):
		var city: Dictionary = measurements.cities[id]
		var count := int(city.totals.delivered)
		if origin == "" or id == origin: delivered += count
		if count >= 5: served += 1
	return {"delivered": delivered, "served": served}
func advance(tick: int, measurements: Dictionary) -> bool:
	if state.id == "" or int(state.completed_tick) >= 0: return false
	var config: Dictionary = DEFINITIONS[state.id]
	var measured := progress(measurements, config.get("origin", ""))
	if measured.delivered < config.deliveries or measured.served < config.served: return false
	state.completed_tick = tick
	return true
static func description(id: String) -> String:
	if not DEFINITIONS.has(id): return ""
	var row: Dictionary = DEFINITIONS[id]
	if id == "river_connection":
		return "Across the River — seed 42, 3 cities, River with bridge crossings, £5000.\nComplete 40 final journeys by Town 3 residents to other cities. Town 3 is the only city north of the river, so these are cross-river journeys. Also complete at least five resident journeys from one other city.\nBuild a complete straight north–south bridge including both dry banks. Guide can preview a validated first connection. Ordinary bank loans are available. No deadline, no bonus money. Queues, boarding and transfers do not count. Completion is saved; play can continue."
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
	if not data.get("terrain") is Dictionary: return false
	if data.get("terrain", {}).get("profile", "flat") != row.get("terrain", "flat"): return false
	if data.world.layout_seed != row.seed or data.world.settlements.size() != row.cities: return false
	if row.no_loans and (not data.get("loans") is Dictionary or not Numbers.whole(data.loans.get("borrowed"), 0, 0)): return false
	if value.id == "river_connection":
		# Preserve the preset geometry behind the cross-river inference,
		# including station catchment distances from either bank.
		var expected: Array = Generator.generate(row.seed, row.cities).world.settlements
		for index in range(expected.size()):
			var town: Dictionary = data.world.settlements[index]
			if town.id != expected[index].id or Vector2i(int(town.cell[0]), int(town.cell[1])) != Vector2i(expected[index].cell[0], expected[index].cell[1]): return false
	if int(value.completed_tick) >= 0:
		var measured: Dictionary = progress(data.city_service, row.get("origin", ""))
		if measured.delivered < row.deliveries or measured.served < row.served: return false
	return true
