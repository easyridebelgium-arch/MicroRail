extends SceneTree
const Growth = preload("res://scripts/core/city_growth.gd")
const Demand = preload("res://scripts/core/city_demand.gd")
const Service = preload("res://scripts/core/city_service.gd")
const Generator = preload("res://scripts/core/world_generator.gd")
const CityArt = preload("res://scripts/art/city_art.gd")
var checks := 0
var failures := 0
var world: Dictionary
var demand: RefCounted
var service: RefCounted
var growth: RefCounted
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func fixture(rate: String = "normal", tick: int = 0) -> void:
	world = Generator.generate("42", 3).world
	demand = Demand.new()
	demand.initialize(world)
	service = Service.new()
	service.initialize(world, tick)
	growth = Growth.new()
	growth.initialize(world, demand.save_state(), service.save_state(), tick, rate)
func outcomes(id: String, delivered: int, unmet: int) -> void:
	var city: Dictionary = service.state.cities[id]
	# Already resolved historical outcomes: no live passenger identities are needed.
	for collection in [city.totals, city.retired]:
		collection.requested += delivered + unmet
		collection.queued += delivered
		collection.delivered += delivered
		collection.legs += delivered
		collection.no_station += unmet
func advance(tick: int, pending: int = 0, unknown: bool = false) -> Array:
	return growth.advance(tick, demand, service, {"cities": {"town:01": pending}, "unknown": unknown})
func population(id: String = "town:01") -> int: return int(demand.state.cities[id].population)
func valid(tick: int) -> bool: return Growth.valid(growth.save_state(), world, demand.save_state(), service.save_state(), tick)
func run() -> void:
	fixture()
	check(valid(0) and population() == 800 and growth.state.rate == "normal", "new city model preserves deterministic initial population")
	outcomes("town:01", 5, 0)
	check(advance(Growth.PERIOD - 1).is_empty() and population() == 800, "no assessment or population change before six game hours")
	var unchanged_supply: Dictionary = demand.save_state()
	var changes := advance(Growth.PERIOD)
	check(population() == 808 and changes.size() == 1 and changes[0].delta == 8, "five new final deliveries support bounded one-percent growth during grace")
	unchanged_supply.cities["town:01"].population = 808
	check(demand.save_state() == unchanged_supply, "growth changes population only, preserving demand carries and histories")
	check(valid(Growth.PERIOD), "positive assessment validates with source counters")
	advance(Growth.PERIOD * 2)
	check(population() == 808 and growth.state.cities["town:01"].history.back().delivered == 0, "old deliveries cannot reward another assessment")
	fixture()
	for index in range(1, 5):
		outcomes("town:01", 0, 20)
		advance(Growth.PERIOD * index)
	check(population() == 800 and growth.state.cities["town:01"].reason == "grace", "new city is protected through the full first game day")
	outcomes("town:01", 0, 20)
	advance(Growth.PERIOD * 5)
	check(population() == 800 and growth.state.cities["town:01"].bad_periods == 1, "one post-grace unmet interval gives a warning")
	outcomes("town:01", 0, 20)
	advance(Growth.PERIOD * 6)
	check(population() == 796 and growth.state.cities["town:01"].reason == "decline", "two post-grace unmet intervals permit half-percent decline")
	check(valid(Growth.PERIOD * 6), "decline history preserves population and outcome conservation")
	for index in range(7, 190):
		outcomes("town:01", 0, 20)
		advance(Growth.PERIOD * index)
	check(population() == 400 and growth.state.cities["town:01"].reason == "floor", "persistent missing service never reduces population below half its starting value")
	check(growth.state.cities["town:01"].history.size() == Growth.HISTORY and valid(Growth.PERIOD * 189), "long decline history remains bounded and valid")
	fixture()
	for index in range(1, 180):
		outcomes("town:01", 5, 0)
		advance(Growth.PERIOD * index)
	check(population() == 2400 and growth.state.cities["town:01"].reason == "cap", "growth stops at three times the starting population")
	check(valid(Growth.PERIOD * 179), "capped city remains valid after repeated successful service")
	fixture("slow")
	outcomes("town:01", 5, 0)
	advance(Growth.PERIOD)
	check(population() == 802, "Slower applies a quarter of normal population growth")
	for index in range(2, 5):
		outcomes("town:01", 5, 0)
		advance(Growth.PERIOD * index)
	check(population() == 808 and valid(Growth.PERIOD * 4), "slow fractional progress persists deterministically")
	fixture("off")
	outcomes("town:01", 100, 100)
	advance(Growth.GRACE * 4)
	check(population() == 800 and growth.state.cities["town:01"].reason == "off", "Frozen mode changes neither growth nor decline")
	check(growth.set_rate("normal", Growth.GRACE * 4, service), "resume normal growth through game rule API")
	advance(Growth.GRACE * 4 + Growth.PERIOD)
	check(population() == 800, "unfreezing never catches up accumulated frozen deliveries")
	outcomes("town:01", 5, 0)
	advance(Growth.GRACE * 4 + Growth.PERIOD * 2)
	check(population() == 808, "fresh service after unfreezing can earn normal growth")
	var saved: Dictionary = growth.save_state()
	check(not growth.set_rate("bad", 1, service) and growth.save_state() == saved, "invalid growth rule is rejected without mutation")
	fixture()
	outcomes("town:01", 0, 100)
	advance(Growth.GRACE + Growth.PERIOD, 20)
	outcomes("town:01", 0, 100)
	advance(Growth.GRACE + Growth.PERIOD * 2, 20)
	check(population() == 800 and growth.state.cities["town:01"].reason == "pending", "unfinished journeys cannot cause decline, even after grace")
	outcomes("town:01", 5, 0)
	advance(Growth.GRACE + Growth.PERIOD * 3, 20)
	check(population() == 808, "actual final deliveries support growth while other passengers remain in transit")
	fixture()
	outcomes("town:01", 0, 100)
	advance(Growth.GRACE + Growth.PERIOD, 0, true)
	check(population() == 800 and growth.state.cities["town:01"].reason == "unknown", "unknown pre-baseline origins conservatively suspend decline")
	service.state.cities["town:01"].totals.untracked_requests = 1
	outcomes("town:01", 5, 0)
	advance(Growth.GRACE + Growth.PERIOD * 2)
	check(population() == 800 and growth.state.cities["town:01"].reason == "tracking", "incomplete request measurement never creates growth or decline")
	fixture()
	outcomes("town:01", 4, 0)
	advance(Growth.PERIOD)
	check(population() == 800 and growth.state.cities["town:01"].reason == "low", "small positive service preserves population but does not pass the growth threshold")
	var station_catalog := {"a": {"settlement_id": "town:01"}, "b": {"settlement_id": "town:02"}}
	var cohort := {"origin": "a", "known": true, "count": 3}
	var pending := Growth.pending_passengers(station_catalog, {"b": [cohort]}, {"train": [cohort.duplicate(true)]})
	check(pending.cities["town:01"] == 6 and not pending.unknown, "transferred and onboard passengers are attributed to original city, not current location")
	pending = Growth.pending_passengers(station_catalog, {"b": [{"origin": "unknown", "known": false, "count": 2}]}, {})
	check(pending.unknown, "legacy unknown passengers stay explicitly unscorable")
	fixture()
	for index in range(1, 4):
		outcomes("town:01", 5, 0)
		advance(Growth.PERIOD * index)
	saved = growth.save_state()
	var restored := Growth.new()
	restored.restore_state(JSON.parse_string(JSON.stringify(saved)))
	check(restored.save_state() == saved and valid(Growth.PERIOD * 3), "JSON saves preserve counters, fractions, grace and assessment history")
	for corruption in ["rate", "missing", "anchor", "baseline", "carry", "future", "population", "delta"]:
		var bad: Dictionary = saved.duplicate(true)
		var city: Dictionary = bad.cities["town:01"]
		match corruption:
			"rate": bad.rate = "unknown"
			"missing": bad.cities.erase("town:01")
			"anchor": city.initial = 1
			"baseline": city.delivered += 1
			"carry": city.carry = 1000
			"future": city.history[-1].tick = Growth.PERIOD * 4
			"population": city.history[-1].population += 1
			"delta": city.history[-1].delta = 10000
		check(not Growth.valid(bad, world, demand.save_state(), service.save_state(), Growth.PERIOD * 3), "reject malformed growth save: " + corruption)
	var text: String = growth.describe("town:01", Growth.PERIOD * 3, population())
	check(text.contains("floor 400; cap 2400") and text.contains("five final deliveries") and not text.contains("%%"), "growth explanation provides limits and clear reasons")
	check(CityArt.density(400, 800) == "small" and CityArt.density(800, 800) == "town" and CityArt.density(1200, 800) == "dense", "art density reflects bounded population thresholds")
	var plot := Rect2(100, 100, 160, 96)
	for image in CityArt.IMAGES.values(): check(plot.encloses(CityArt.fitted_bounds(plot, image.region.size)), "city artwork stays inside its original protected plot")
	print("City growth: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
