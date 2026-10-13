extends RefCounted
## Station amenities: pure rules, no scene access. Each passenger station owns a
## set of amenities. Each raises the waiting-area limit and adds a small arrival
## bonus (whole percent). Train capacity never creates demand; amenities do.
const STATIONS: Array[String] = ["a", "b", "c"]
const BASE_QUEUE: int = 100
const ORDER: Array[String] = ["shelter", "waiting_room", "kiosk"]
const DEFS: Dictionary = {
	"shelter": {"name": "Shelter", "price": 300, "queue": 50, "demand": 5, "requires": ""},
	"waiting_room": {"name": "Waiting room", "price": 700, "queue": 100, "demand": 10, "requires": "shelter"},
	"kiosk": {"name": "Kiosk", "price": 400, "queue": 25, "demand": 10, "requires": ""},
}

var owned: Dictionary = {}   # station -> Array[String] in purchase order
var carry: Dictionary = {}   # station -> hundredths of a passenger carried over

func _init() -> void:
	reset()

func reset() -> void:
	for station in STATIONS:
		owned[station] = []
		carry[station] = 0

func has(station: String, id: String) -> bool:
	return owned.get(station, []).has(id)

func queue_limit(station: String) -> int:
	var result := BASE_QUEUE
	for id in owned.get(station, []): result += int(DEFS[id].queue)
	return result

func demand_bonus(station: String) -> int:
	var result := 0
	for id in owned.get(station, []): result += int(DEFS[id].demand)
	return result

## Returns "" when the amenity can be bought, otherwise the reason it cannot.
func refusal(station: String, id: String, money: int) -> String:
	if not STATIONS.has(station) or not DEFS.has(id): return "Unknown amenity."
	if has(station, id): return "%s is already built here." % DEFS[id].name
	var need: String = DEFS[id].requires
	if need != "" and not has(station, need): return "%s needs a %s first." % [DEFS[id].name, DEFS[need].name.to_lower()]
	if money < int(DEFS[id].price): return "Insufficient funds. %s costs £%d." % [DEFS[id].name, int(DEFS[id].price)]
	return ""

## Returns the price paid, or -1 when refused. The caller deducts the money.
func buy(station: String, id: String, money: int) -> int:
	if refusal(station, id, money) != "": return -1
	owned[station].append(id)
	return int(DEFS[id].price)

## Whole passengers to generate this interval. Percent bonus is carried in
## hundredths, so no randomness is used and a station without amenities
## generates exactly `batch`.
func arrivals(station: String, batch: int) -> int:
	var pool: int = int(carry.get(station, 0)) + batch * (100 + demand_bonus(station))
	carry[station] = pool % 100
	return pool / 100

func to_save() -> Dictionary:
	return {"owned": owned.duplicate(true), "carry": carry.duplicate(true)}

static func default_save() -> Dictionary:
	var result := {"owned": {}, "carry": {}}
	for station in STATIONS:
		result.owned[station] = []
		result.carry[station] = 0
	return result

static func valid_save(value: Variant) -> bool:
	if not value is Dictionary or not value.get("owned") is Dictionary or not value.get("carry") is Dictionary: return false
	if value.owned.size() != STATIONS.size() or value.carry.size() != STATIONS.size(): return false
	for station in STATIONS:
		var list: Variant = value.owned.get(station)
		if not list is Array: return false
		var seen: Dictionary = {}
		for id in list:
			if not id is String or not DEFS.has(id) or seen.has(id): return false
			var need: String = DEFS[id].requires
			if need != "" and not seen.has(need): return false
			seen[id] = true
		var rest: Variant = value.carry.get(station)
		if typeof(rest) not in [TYPE_INT, TYPE_FLOAT] or float(rest) != floor(float(rest)) or float(rest) < 0 or float(rest) > 99: return false
	return true

func load_save(value: Dictionary) -> void:
	reset()
	for station in STATIONS:
		for id in value.owned[station]: owned[station].append(str(id))
		carry[station] = int(value.carry[station])
