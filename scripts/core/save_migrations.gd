extends RefCounted
## Upgrades older save files to the current format, one version at a time.
##
## To change the save format:
##   1. Raise CURRENT_VERSION by one.
##   2. Add a `_vN_to_vN+1` function that edits the dictionary.
##   3. Add it to _upgrade_one() below.
## Old saves then keep loading instead of being rejected.
##
## The first release of this system starts at version 14 (the last format
## before migrations existed); older formats cannot be reconstructed.

const Fleet = preload("res://scripts/fleet.gd")
const CURRENT_VERSION: int = 53
const OLDEST_SUPPORTED_VERSION: int = 14


## Returns {"ok": bool, "data": Dictionary, "error": String,
##          "from_version": int, "migrated": bool}.
## The input dictionary is never modified.
static func migrate(data: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"data": {},
		"error": "",
		"from_version": 0,
		"migrated": false
	}

	var raw_version: Variant = data.get("version")

	if typeof(raw_version) != TYPE_INT and typeof(raw_version) != TYPE_FLOAT:
		result["error"] = "The save file has no version number."
		return result

	var number: float = float(raw_version)

	if not is_finite(number) or number != floor(number):
		result["error"] = "The save file has an invalid version number."
		return result

	var version: int = int(number)
	result["from_version"] = version

	if version < OLDEST_SUPPORTED_VERSION:
		result["error"] = "This save is from an older development version and can no longer be upgraded. Start a new game."
		return result

	if version > CURRENT_VERSION:
		result["error"] = "This save was made by a newer version of the game."
		return result

	var upgraded: Dictionary = data.duplicate(true)

	while version < CURRENT_VERSION:
		upgraded = _upgrade_one(version, upgraded)
		version += 1
		upgraded["version"] = version

	result["ok"] = true
	result["data"] = upgraded
	result["migrated"] = int(result["from_version"]) != CURRENT_VERSION
	return result


static func _upgrade_one(from_version: int, data: Dictionary) -> Dictionary:
	match from_version:
		52:
			if data.get("seeded_challenge") is Dictionary and not data.seeded_challenge.has("review"):
				data.seeded_challenge["review"] = {}
			return data
		51:
			if data.get("seeded_challenge") is Dictionary and not data.seeded_challenge.has("evidence"):
				data.seeded_challenge["evidence"] = {}
			return data
		50:
			if data.get("freight_contracts") is Dictionary:
				for row in data.freight_contracts.values():
					if row is Dictionary: row["warned_tick"] = -1
			return data
		49:
			data["freight_contracts"] = preload("res://scripts/core/freight_contracts.gd").defaults()
			return data
		48:
			return data # Absent service priority defaults to Normal; preserve all live state.
		47:
			return data # Preserve immutable v1 terrain profiles and crossing geometry.
		46:
			data["terrain"] = {"profile": "flat"}
			return data
		45:
			data["seeded_challenge"] = {"id": "", "completed_tick": -1}
			return data
		44:
			var report_tick := 0
			if data.get("sim") is Dictionary and data.sim.get("clock") is Dictionary:
				var raw: Variant = data.sim.clock.get("tick")
				if preload("res://scripts/core/arrival_targets.gd").whole(raw, 0, 1e12): report_tick = int(raw)
			var reports_model = preload("res://scripts/core/progress_reports.gd")
			data["progress_reports"] = reports_model.defaults(report_tick, reports_model.from_save(data))
			return data
		43:
			data["watchlist"] = {}
			var performance_tick := 0
			if data.get("sim") is Dictionary and data.sim.get("clock") is Dictionary:
				var raw: Variant = data.sim.clock.get("tick")
				if preload("res://scripts/core/arrival_targets.gd").whole(raw, 0, 1e12): performance_tick = int(raw)
			data["service_performance"] = preload("res://scripts/core/service_performance.gd").defaults(performance_tick)
			return data
		42:
			var growth_sim: Variant = data.get("sim")
			var growth_tick := 0
			if growth_sim is Dictionary and growth_sim.get("clock") is Dictionary:
				var raw_tick: Variant = growth_sim.clock.get("tick", 0)
				if typeof(raw_tick) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(raw_tick)) and float(raw_tick) >= 0 and float(raw_tick) <= 1e12: growth_tick = int(raw_tick)
			data["city_growth"] = preload("res://scripts/core/city_growth.gd").defaults(data.world if data.get("world") is Dictionary else {}, data.city_demand if data.get("city_demand") is Dictionary else {}, data.city_service if data.get("city_service") is Dictionary else {}, growth_tick)
			return data
		41:
			var metric_world: Variant = data.get("world")
			var metric_sim: Variant = data.get("sim")
			var metric_clock: Variant = 0
			if metric_sim is Dictionary and metric_sim.get("clock") is Dictionary: metric_clock = metric_sim.clock.get("tick", 0)
			var metric_tick: int = int(metric_clock) if typeof(metric_clock) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(metric_clock)) and float(metric_clock) >= 0 and float(metric_clock) <= 1e12 else 0
			data["city_service"] = preload("res://scripts/core/city_service.gd").defaults(metric_world if metric_world is Dictionary else {}, metric_tick)
			return data
		40:
			var saved_world: Variant = data.get("world")
			data["city_demand"] = preload("res://scripts/core/city_demand.gd").defaults(saved_world if saved_world is Dictionary else {})
			return data
		39:
			data["game_mode"] = "tutorial"
			return data
		14:
			return _v14_to_v15(data)
		15:
			return _v15_to_v16(data)
		16:
			return _v16_to_v17(data)
		17:
			return _v17_to_v18(data)
		18:
			data["runtime"] = preload("res://scripts/core/runtime_routes.gd").defaults()
			data["signals"] = []
			return data

		19:
			if data.get("services") is Dictionary:
				for service in ["passenger", "freight"]:
					if data["services"].get(service) is Dictionary: data["services"][service]["waypoints"] = {}
			return data

		20:
			if data.get("services") is Dictionary:
				for service in ["passenger", "freight"]:
					if data["services"].get(service) is Dictionary: data["services"][service]["mode"] = "shuttle"
			return data

		21:
			data["passenger_services"] = {}
			return data

		22:
			if data.get("fleet") is Dictionary and data.fleet.get("trains") is Array:
				for train in data.fleet.trains:
					if train is Dictionary: train["wagons"] = []
			return data
		23:
			data["dispatch"] = {"timetables": {}, "headways": {}}
			return data

		24:
			data["demand"] = preload("res://scripts/core/passenger_demand.gd").migrate(data)
			return data

		25:
			data["amenities"] = preload("res://scripts/core/amenities.gd").default_save()
			return data

		26:
			data["loans"] = preload("res://scripts/core/loans.gd").defaults()
			return data

		27:
			data["presentation"] = preload("res://scripts/core/presentation.gd").defaults()
			return data

		28:
			# Manifests now allow final destinations reached via another service.
			# Existing destination counts and physical positions need no conversion.
			return data

		29:
			preload("res://scripts/core/passenger_demand.gd").migrate_ages(data)
			return data

		30:
			data["satisfaction"] = preload("res://scripts/core/passenger_satisfaction.gd").defaults()
			return data

		31:
			data["demand_response"] = preload("res://scripts/core/demand_response.gd").defaults()
			return data

		32:
			preload("res://scripts/core/journey_ledger.gd").migrate(data)
			return data

		33:
			data["arrivals"] = {"active": {}, "completed": []}
			return data

		34:
			preload("res://scripts/core/passenger_classes.gd").migrate(data)
			return data

		35:
			preload("res://scripts/core/passenger_revenue.gd").migrate(data)
			return data

		36:
			data["sawmill"] = preload("res://scripts/core/sawmill.gd").defaults()
			if data.get("freight") is Dictionary:
				data.freight["chain_stage"] = 0
				data.freight["recovery_stop"] = "forest"
				data.freight["leg_origin"] = "forest"
			return data

		37:
			data["factory"] = preload("res://scripts/core/factory.gd").defaults()
			return data

		38:
			if data.get("sawmill") is Dictionary and data.get("factory") is Dictionary:
				data["world"] = preload("res://scripts/core/world_catalog.gd").tutorial(bool(data.sawmill.get("installed", false)), bool(data.factory.get("installed", false)))
			return data

	# Unreachable while every version between OLDEST and CURRENT has a step.
	return data


# v15 adds the "sim" block: fixed-step clock, seeded RNG and event stream.
static func _v14_to_v15(data: Dictionary) -> Dictionary:
	data["sim"] = default_sim_state()
	return data

## Two development branches used v15: fleet-only and simulation-only.
## Preserve existing blocks; initialise only systems absent in that format.
## The game validates the complete migrated result before applying any state.
static func _v15_to_v16(data: Dictionary) -> Dictionary:
	if not data.has("sim"):
		data["sim"] = default_sim_state()
	if not data.has("fleet"):
		data["fleet"] = Fleet.defaults()
		if data.get("state") is Dictionary and data.get("freight") is Dictionary:
			var passenger: Dictionary = Fleet.assigned(data["fleet"], "passenger")
			var freight: Dictionary = Fleet.assigned(data["fleet"], "freight")
			passenger["capacity_level"] = data["state"].get("capacity_upgrade_level")
			passenger["speed_level"] = data["state"].get("speed_upgrade_level")
			freight["capacity_level"] = data["freight"].get("capacity_level")
			freight["speed_level"] = data["freight"].get("speed_level")
		if data.get("state") is Dictionary:
			# Starter trains were free; installed upgrades were purchased.
			data["state"]["total_vehicle_cost"] = 0
			if Fleet.is_valid(data["fleet"]):
				for train in data["fleet"]["trains"]:
					data["state"]["total_vehicle_cost"] += Fleet.sale_price(train) * 2 - int(Fleet.MODELS[train["model"]]["price"])
	return data


# v17 adds the command queue to the sim block for determinism.
static func _v16_to_v17(data: Dictionary) -> Dictionary:
	if data.has("sim") and data["sim"] is Dictionary:
		if not data["sim"].has("commands"):
			data["sim"]["commands"] = {"next_seq": 1, "pending": []}
	return data


# v18 adds switch tiles; "switches" lists [x, y, state] for each switch.
static func _v17_to_v18(data: Dictionary) -> Dictionary:
	if not data.has("switches"):
		data["switches"] = []
	return data


static func default_sim_state() -> Dictionary:
	return {
		"clock": {"tick": 0},
		# No random events exist yet, so a fixed seed is fine for old saves.
		"rng": {"seed": "1"},
		"events": {"next_id": 1, "events": []},
		"commands": {"next_seq": 1, "pending": []}
	}
