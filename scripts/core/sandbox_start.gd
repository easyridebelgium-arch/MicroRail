extends RefCounted
## Construction-stage startup data. No actors, tutorial services or save-file writes.
const CityDemand = preload("res://scripts/core/city_demand.gd")
var city_demand := CityDemand.new()
const Generator = preload("res://scripts/core/world_generator.gd")
const World = preload("res://scripts/core/world_catalog.gd")
const StationConstruction = preload("res://scripts/core/station_construction.gd")
const Fleet = preload("res://scripts/fleet.gd")
const Demand = preload("res://scripts/core/passenger_demand.gd")
const Amenities = preload("res://scripts/core/amenities.gd")
const Satisfaction = preload("res://scripts/core/passenger_satisfaction.gd")
const Response = preload("res://scripts/core/demand_response.gd")
const Journeys = preload("res://scripts/core/journey_ledger.gd")
const SimRng = preload("res://scripts/core/sim_rng.gd")
const Clock = preload("res://scripts/core/sim_clock.gd")
const Commands = preload("res://scripts/core/command_queue.gd")
const STARTING_BALANCE := 5000 # Provisional sandbox budget; tutorial remains £1000.
var initialized := false
var world: RefCounted
var sim_rng := SimRng.new()
var sim_clock := Clock.new()
var command_queue := Commands.new()
var tracks: Dictionary = {}
var services: Dictionary = {}
var fleet: Dictionary = Fleet.empty()
var money := 0
var total_construction_cost := 0
var demand: RefCounted
var amenities: RefCounted
var satisfaction: RefCounted
var demand_response: RefCounted
var journey_ledger: RefCounted

func initialize(seed_text: String, city_count: int = 4) -> Dictionary:
	if initialized: return {"ok": false, "message": "Create a fresh startup object to begin another world."}
	var generated := Generator.generate(seed_text, city_count)
	if not generated.ok: return generated
	var catalog := World.new()
	catalog.restore_state(generated.world)
	var station_state := _expanded_station_state(catalog)
	world = catalog
	city_demand.initialize(world.save_state())
	sim_rng.restore_state(generated.rng_state)
	sim_clock = Clock.new()
	command_queue = Commands.new()
	tracks = {}
	services = {}
	fleet = Fleet.empty()
	total_construction_cost = 0
	money = STARTING_BALANCE
	_adopt_station_state(station_state)
	initialized = true
	return {"ok": true, "message": "City layout ready for construction; no stations, track, trains or services are prebuilt."}

func station_preview(stop: Vector2i, signs: Dictionary = {}, claims: Dictionary = {}) -> Dictionary:
	if not initialized: return {"ok": false, "message": "Initialize the city layout first."}
	return StationConstruction.preview(world.save_state(), stop, tracks, signs, claims, money)

func station_draft(stop: Vector2i, signs: Dictionary = {}, claims: Dictionary = {}) -> Dictionary:
	if not initialized: return {"ok": false, "message": "Initialize the city layout first."}
	return StationConstruction.draft(world.save_state(), stop, tracks, signs, claims, money)

## Invoke from the future authoritative command handler with current signal/claim data.
## No simulation tick, random draw, boarding or default service is created by a build.
func commit_station(draft_value: Dictionary, signs: Dictionary, claims: Dictionary) -> Dictionary:
	if not initialized: return {"ok": false, "message": "Initialize the city layout first."}
	var purchased := StationConstruction.purchase(draft_value, world.save_state(), tracks, signs, claims, money)
	if not purchased.ok: return purchased
	var catalog := World.new()
	catalog.restore_state(purchased.world)
	var station_state := _expanded_station_state(catalog)
	# Stage all station-owned models before adopting catalog, track and accounting.
	world = catalog
	tracks = purchased.tracks
	money = int(purchased.money)
	total_construction_cost += int(purchased.spent)
	_adopt_station_state(station_state)
	return {"ok": true, "message": purchased.message, "station_id": purchased.station_id, "spent": purchased.spent}

func _expanded_station_state(catalog: RefCounted) -> Dictionary:
	var definitions: Dictionary = catalog.stations()
	var ids: Array = definitions.keys()
	var next_demand := Demand.new(ids, definitions, 0)
	var next_amenities := Amenities.new(ids)
	var next_satisfaction := Satisfaction.new(ids)
	var next_response := Response.new(ids)
	var next_journeys := Journeys.new(ids)
	if initialized:
		var demand_state := next_demand.save_state({}, sim_clock.tick)
		for id in demand.station_ids:
			demand_state.queues[id] = demand.queues[id].duplicate(true)
			demand_state.batches[id] = demand.batches[id].duplicate(true)
		for id in demand.class_progress:
			if demand_state.class_progress.has(id): demand_state.class_progress[id] = demand.class_progress[id]
		next_demand.restore_state(demand_state, ids, definitions)
		next_demand.last_boarding = demand.last_boarding.duplicate(true)
		next_demand.last_journeys = demand.last_journeys.duplicate(true)
		var amenity_state := Amenities.default_save(ids)
		for id in amenities.station_ids:
			amenity_state.owned[id] = amenities.owned[id].duplicate()
			amenity_state.carry[id] = amenities.carry[id]
		next_amenities.load_save(amenity_state, ids)
		var satisfaction_state := Satisfaction.defaults(ids)
		for id in satisfaction.station_ids: satisfaction_state[id] = satisfaction.history[id].duplicate(true)
		next_satisfaction.restore_state(satisfaction_state, ids)
		var response_state := Response.defaults(ids)
		for id in demand_response.station_ids: response_state[id] = demand_response.state[id].duplicate(true)
		next_response.restore_state(response_state, ids)
		next_journeys.restore_state({"aboard": journey_ledger.aboard.duplicate(true), "completed": journey_ledger.completed.duplicate(true), "unknown_completed": journey_ledger.unknown_completed}, ids)
	return {"demand": next_demand, "amenities": next_amenities, "satisfaction": next_satisfaction, "response": next_response, "journeys": next_journeys}

func _adopt_station_state(value: Dictionary) -> void:
	demand = value.demand
	amenities = value.amenities
	satisfaction = value.satisfaction
	demand_response = value.response
	journey_ledger = value.journeys
