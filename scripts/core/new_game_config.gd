extends RefCounted
## Validated startup choices; previews never consume the live simulation RNG.
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
	return {"ok": true, "configuration": {"mode": "cities", "seed": value.seed, "city_count": int(count), "city_growth": growth}, "message": "City sandbox: %d cities, four industry sites, £%d.\nNo stations, track or trains are prebuilt. Two new stations cost £%d and a passenger shuttle costs £%d, leaving £%d for connecting track and operations.\nPopulation drives city trip requests. City growth is bounded, with a day of protection against decline; choose its rate above; introductory tutorial rewards do not apply. Same seed and city count reproduce this starting layout." % [int(count), Start.STARTING_BALANCE, two_stations, locomotive, Start.STARTING_BALANCE - two_stations - locomotive]}
