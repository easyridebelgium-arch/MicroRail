extends RefCounted
## Immutable scenario goals derived from final deliveries or completed contracts.
const Generator = preload("res://scripts/core/world_generator.gd")
const Review = preload("res://scripts/core/scenario_review.gd")
const Shared = preload("res://scripts/core/shared_track_challenge.gd")
const Numbers = preload("res://scripts/core/arrival_targets.gd")
const DEFINITIONS := {
	"first_connection": {"name": "First Connection", "seed": "42", "cities": 3, "deliveries": 40, "served": 2, "no_loans": false},
	"three_towns": {"name": "Three Town Link", "seed": "7", "cities": 3, "deliveries": 75, "served": 3, "no_loans": true},
	"river_connection": {"name": "Across the River", "seed": "42", "cities": 3, "deliveries": 40, "served": 2, "no_loans": false, "terrain": "river_v1", "origin": "town:03"},
	"timber_connection": {"name": "Timber Connection", "seed": "42", "cities": 3, "no_loans": false, "contract": "timber"},
	"passing_place": {"name": "Passing Place", "seed": "4", "cities": 3, "no_loans": false, "deliveries": 20, "served": 2, "shared_track": true}
}
var state: Dictionary = {"id": "", "completed_tick": -1, "evidence": {}, "review": {}}
func initialize(id: String) -> void:
	state = {"id": id if DEFINITIONS.has(id) else "", "completed_tick": -1, "evidence": {}, "review": {}}
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
func advance(tick: int, measurements: Dictionary, contracts: Dictionary = {}, shared: Dictionary = {}) -> bool:
	if state.id == "" or int(state.completed_tick) >= 0: return false
	var config: Dictionary = DEFINITIONS[state.id]
	if state.id == "passing_place":
		if not shared.get("ready", false):
			state.evidence = {}
			return false
		if state.evidence.is_empty() or state.evidence.direct != shared.direct or state.evidence.bypass != shared.bypass:
			state.evidence = {"direct": shared.direct, "bypass": shared.bypass, "direct_baseline": int(shared.direct_finals), "bypass_baseline": int(shared.bypass_finals), "direct_finals": 0, "bypass_finals": 0}
		for role in ["direct", "bypass"]:
			state.evidence[role + "_finals"] = maxi(0, int(shared[role + "_finals"]) - int(state.evidence[role + "_baseline"]))
		if state.evidence.direct_finals < Shared.TARGET or state.evidence.bypass_finals < Shared.TARGET: return false
		state.completed_tick = tick
		return true
	if config.has("contract"):
		if contracts.get(config.contract, {}).get("status") != "completed": return false
		state.completed_tick = tick
		return true
	var measured := progress(measurements, config.get("origin", ""))
	if measured.delivered < config.deliveries or measured.served < config.served: return false
	state.completed_tick = tick
	return true
static func description(id: String) -> String:
	if not DEFINITIONS.has(id): return ""
	var row: Dictionary = DEFINITIONS[id]
	if id == "passing_place":
		return "Passing Place — seed 4, 3 cities, flat map, £5000.\nBuild Town 3 Station at 30,14 and Town 2 Station at 66,14. Connect their horizontal platform ends. Preview a default 9×4 loop at 44,14; review body fit and signal blocks, then Apply.\nBuy two Passenger Shuttles. Start Town 3 → Town 2 on the main line and Town 2 → Town 3 with loop waypoint 48,17. Use Shuttle mode and keep all four automatic boundaries. Stay paused until both routes are ready.\nComplete ten final passenger journeys with each of these services while the prescribed shared layout and routes are intact. Guide explains each step. No deadline or extra cash reward; loans allowed. Completion is a saved milestone, so later network edits or retiring trains do not undo it."
	if row.has("contract"):
		return "Timber Connection — seed 42, 3 cities, flat map, £5000.\nConnect Forest → Sawmill → Terminal along the industry loading tiles. Buy a Log Hauler in Fleet and start its freight service. While paused with the empty train at Forest, build the Sawmill from its inspector. No passenger stations are needed.\nWhen ready, accept the Timber order in Accounts → Freight contracts, then deliver 20 timber to Terminal within 18 game hours. Preparation is untimed; only post-acceptance deliveries count. Do not install the Factory before completing this order. The ordinary £300 contract bonus is the only reward. Loans are available. Expiry leaves the scenario incomplete: restart from New Game to retry, or keep playing your company."
	if id == "river_connection":
		return "Across the River — seed 42, 3 cities, River with bridge crossings, £5000.\nComplete 40 final journeys by Town 3 residents to other cities. Town 3 is the only city north of the river, so these are cross-river journeys. Also complete at least five resident journeys from one other city.\nBuild a complete straight north–south bridge including both dry banks. Guide can preview a validated first connection. Ordinary bank loans are available. No deadline, no bonus money. Queues, boarding and transfers do not count. Completion is saved; play can continue."
	return "%s — seed %s, %d cities, £5000.\nComplete %d final city passenger journeys, including at least five by residents of each of %d different cities.\n%s No deadline, no bonus money. Completed journeys count once; queues and transfers do not qualify. Completion is saved and play can continue." % [row.name, row.seed, row.cities, row.deliveries, row.served, "Bank borrowing is disabled for this company." if row.no_loans else "Ordinary bank loans are available."]
func save_state() -> Dictionary: return state.duplicate(true)
func restore_state(value: Dictionary) -> void:
	state = value.duplicate(true)
	state.completed_tick = int(state.completed_tick)
	for field in state.review: state.review[field] = int(state.review[field])
	if state.id == "passing_place" and not state.evidence.is_empty():
		for field in ["direct_baseline", "bypass_baseline", "direct_finals", "bypass_finals"]: state.evidence[field] = int(state.evidence[field])
static func valid(value: Variant, data: Dictionary, tick: int) -> bool:
	if not _valid_goal(value, data, tick): return false
	return Review.valid(value.review, int(value.completed_tick), DEFINITIONS.get(value.id, {}), value.evidence, data)

static func _valid_goal(value: Variant, data: Dictionary, tick: int) -> bool:
	if not value is Dictionary or not value.get("id") is String or not Numbers.whole(value.get("completed_tick"), -1, tick): return false
	if value.size() != 4 or not value.get("evidence") is Dictionary or not value.get("review") is Dictionary: return false
	if value.id != "passing_place" and not value.evidence.is_empty(): return false
	if value.id == "": return int(value.completed_tick) == -1
	if not DEFINITIONS.has(value.id) or data.get("game_mode") != "cities": return false
	var row: Dictionary = DEFINITIONS[value.id]
	if not data.get("terrain") is Dictionary: return false
	if data.get("terrain", {}).get("profile", "flat") != row.get("terrain", "flat"): return false
	if data.world.layout_seed != row.seed or data.world.settlements.size() != row.cities: return false
	if row.no_loans and (not data.get("loans") is Dictionary or not Numbers.whole(data.loans.get("borrowed"), 0, 0)): return false
	if value.id in ["river_connection", "passing_place"]:
		# Preserve the geometry behind these fixed teaching layouts.
		var expected: Array = Generator.generate(row.seed, row.cities).world.settlements
		for index in range(expected.size()):
			var town: Dictionary = data.world.settlements[index]
			if town.id != expected[index].id or Vector2i(int(town.cell[0]), int(town.cell[1])) != Vector2i(expected[index].cell[0], expected[index].cell[1]): return false
	if value.id == "passing_place":
		var company: Variant = data.get("state")
		if not company is Dictionary: return false
		var total: Variant = company.get("passengers_delivered")
		return Numbers.whole(total, 0, 1_000_000_000_000_000) and Shared.evidence_valid(value.get("evidence"), int(value.completed_tick), int(total))
	if int(value.completed_tick) >= 0:
		if row.has("contract"):
			var contracts: Variant = data.get("freight_contracts")
			if not contracts is Dictionary or not contracts.get(row.contract) is Dictionary: return false
			var order: Dictionary = contracts[row.contract]
			return order.get("status") == "completed" and Numbers.whole(order.get("finished"), 0, int(value.completed_tick))
		var measured: Dictionary = progress(data.city_service, row.get("origin", ""))
		if measured.delivered < row.deliveries or measured.served < row.served: return false
	return true
