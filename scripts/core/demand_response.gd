extends RefCounted
## Saved gradual demand response; existing arrival clock owns update timing.
const STATIONS: Array[String] = ["a", "b", "c"]
const MIN_FACTOR := 50
const MAX_FACTOR := 125
const REQUIRED_BOARDINGS := 10
var state: Dictionary = defaults()
static func defaults() -> Dictionary:
	var result: Dictionary = {}
	for key in STATIONS: result[key] = {"factor": 100, "carry": 0}
	return result
static func target(rating: int, boarded: int, connected: bool) -> int:
	if rating < 0: return 100
	var result := clampi(rating + 25, MIN_FACTOR, MAX_FACTOR)
	if boarded < REQUIRED_BOARDINGS or not connected: result = mini(100, result)
	return result
func arrivals(station: String, base: int, rating: int, boarded: int, connected: bool) -> int:
	var row: Dictionary = state[station]
	var goal := target(rating, boarded, connected)
	row.factor = int(row.factor) + clampi(goal - int(row.factor), -1, 1)
	var pool := maxi(0, base) * int(row.factor) + int(row.carry)
	row.carry = pool % 100
	return floori(float(pool) / 100.0)
func describe(station: String, rating: int, boarded: int, connected: bool) -> String:
	var goal := target(rating, boarded, connected)
	return "Demand response: %d%% of amenity-adjusted arrivals; current target %d%%.\nTarget = waiting rating +25, limited to 50–125%%. Above 100%% needs at least 10 recent boarding experiences and an enabled connection. No data targets 100%%.\nChanges by at most 1 percentage point each normal arrival interval. Existing queue limits still apply; waiting/transfer/recovery passengers are retained." % [state[station].factor, goal]
func save_state() -> Dictionary: return state.duplicate(true)
func restore_state(value: Dictionary) -> void:
	state = defaults()
	for key in STATIONS:
		state[key].factor = int(value[key].factor)
		state[key].carry = int(value[key].carry)
static func valid_state(value: Variant) -> bool:
	if not value is Dictionary or value.size() != STATIONS.size(): return false
	for key in STATIONS:
		var row: Variant = value.get(key)
		if not row is Dictionary: return false
		for field in ["factor", "carry"]:
			var number: Variant = row.get(field)
			if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)) or float(number) != floor(float(number)): return false
		if row.factor < MIN_FACTOR or row.factor > MAX_FACTOR or row.carry < 0 or row.carry > 99: return false
	return true
