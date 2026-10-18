extends RefCounted
## Validated startup choices; previews never consume the live simulation RNG.
const Terrain = preload("res://scripts/core/river_terrain.gd")
const Challenges = preload("res://scripts/core/seeded_challenges.gd")
const Growth = preload("res://scripts/core/city_growth.gd")
const Generator = preload("res://scripts/core/world_generator.gd")
const Start = preload("res://scripts/core/sandbox_start.gd")
const Fleet = preload("res://scripts/fleet.gd")
const Construction = preload("res://scripts/core/station_construction.gd")

static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("mode") not in ["tutorial", "cities"]:
		return {"ok": false, "message": "Choose Tutorial or City sandbox."}
	if value.mode == "tutorial":
		return {"ok": true, "configuration": {"mode": "tutorial"}, "message": "Tutorial: £1000, three stations and the original trains. Follow the introductory goals."}
	var terrain: Variant = value.get("terrain", "flat")
	if terrain not in Terrain.PROFILES: return {"ok": false, "message": "Choose a listed terrain preset."}
	var challenge: Variant = value.get("challenge", "")
	if not challenge is String or (challenge != "" and not Challenges.DEFINITIONS.has(challenge)): return {"ok": false, "message": "Choose a listed scenario."}
	if challenge != "":
		var definition: Dictionary = Challenges.DEFINITIONS[challenge]
		if terrain != definition.get("terrain", "flat"): return {"ok": false, "message": "Use the scenario preset terrain."}
		if value.get("seed") != definition.seed or value.get("city_count") != definition.cities: return {"ok": false, "message": "Scenario seed and city count must match its preset."}
	var count: Variant = value.get("city_count")
	if typeof(count) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(count)) or float(count) != floor(float(count)) or count < Generator.MIN_CITIES or count > Generator.MAX_CITIES:
		return {"ok": false, "message": "Choose between 3 and 8 cities."}
	if not value.get("seed") is String:
		return {"ok": false, "message": "Enter a whole-number seed."}
	var growth: Variant = value.get("city_growth", "normal")
	if not growth is String or growth not in Growth.RATES: return {"ok": false, "message": "Choose Normal, Slower or Frozen city growth."}
	var generated := Generator.generate(value.seed, int(count))
	if not generated.ok: return generated
	var two_stations: int = 2 * (Construction.STATION_PRICE + 5 * Construction.TRACK_PRICE)
	var locomotive: int = Fleet.MODELS.passenger_standard.price
	if challenge != "":
		if Challenges.DEFINITIONS[challenge].has("contract"):
			var freight_price: int = Fleet.MODELS.freight_standard.price
			var mill_price: int = preload("res://resources/industries/sawmill.tres").build_price
			var corridor: Array = Generator.planning(generated.world).freight_corridor
			var rail_count: int = int(corridor[1][0]) - int(corridor[0][0]) + 1
			if corridor[0][1] != corridor[1][1] or rail_count <= 0: return {"ok": false, "message": "Scenario needs a clear horizontal industry corridor."}
			var rail_price: int = rail_count * Construction.TRACK_PRICE
			return {"ok": true, "configuration": {"mode": "cities", "seed": value.seed, "city_count": int(count), "city_growth": growth, "challenge": challenge, "terrain": terrain}, "message": Challenges.description(challenge) + "\n\nDirect industry line: %d rails £%d + Log Hauler £%d + Sawmill £%d = £%d, leaving £%d for operations. No track, train or mill is prebuilt. Detours cost extra." % [rail_count, rail_price, freight_price, mill_price, rail_price + freight_price + mill_price, Start.STARTING_BALANCE - rail_price - freight_price - mill_price]}
		var stations: int = int(Challenges.DEFINITIONS[challenge].served) * (Construction.STATION_PRICE + 5 * Construction.TRACK_PRICE)
		var crossing_budget := ""
		if challenge == "river_connection":
			var river := Terrain.new()
			river.profile = terrain
			var witness := preload("res://scripts/core/first_connection_path.gd").find(generated.world, river, Vector2i(64, 15), Vector2i(65, 29))
			if witness.is_empty() or int(witness.station_cost) + int(witness.track_cost) + locomotive > Start.STARTING_BALANCE: return {"ok": false, "message": "The river scenario no longer has an affordable checked starting connection."}
			crossing_budget = "\nChecked Town 3–Town 1 layout: stations £%d + connecting rails/bridge £%d + shuttle £%d = £%d. Other layouts can cost more." % [witness.station_cost, witness.track_cost, locomotive, int(witness.station_cost) + int(witness.track_cost) + locomotive]
		return {"ok": true, "configuration": {"mode": "cities", "seed": value.seed, "city_count": int(count), "city_growth": growth, "challenge": challenge, "terrain": terrain}, "message": Challenges.description(challenge) + "\n\nNo stations, track or trains are prebuilt. The required stations cost £%d and a passenger shuttle costs £%d, leaving £%d for track and operations. Growth can be adjusted in Settings." % [stations, locomotive, Start.STARTING_BALANCE - stations - locomotive] + crossing_budget}
	return {"ok": true, "configuration": {"mode": "cities", "seed": value.seed, "city_count": int(count), "city_growth": growth, "challenge": challenge, "terrain": terrain}, "message": ("%s: straight north–south bridges must include all water tiles and both dry banks. Water rails cost £50 each (refund £25); banks £10. Bridge spans vary with the terrain. Failed water drags highlight a feasible crossing; approaches cost extra.\n\n" % Terrain.PROFILE_NAMES[Terrain.PROFILES.find(terrain)] if terrain != "flat" else "") + "City sandbox: %d cities, four industry sites, £%d.\nNo stations, track or trains are prebuilt. Two new stations cost £%d and a passenger shuttle costs £%d, leaving £%d for connecting track and operations.\nPopulation drives city trip requests. City growth is bounded, with a day of protection against decline; adjust its rate in Settings; introductory tutorial rewards do not apply. Same seed and city count reproduce this starting layout." % [int(count), Start.STARTING_BALANCE, two_stations, locomotive, Start.STARTING_BALANCE - two_stations - locomotive]}
