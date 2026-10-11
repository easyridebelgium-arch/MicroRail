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

const CURRENT_VERSION: int = 15
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
		14:
			return _v14_to_v15(data)

	# Unreachable while every version between OLDEST and CURRENT has a step.
	return data


# v15 adds the "sim" block: fixed-step clock, seeded RNG and event stream.
static func _v14_to_v15(data: Dictionary) -> Dictionary:
	data["sim"] = default_sim_state()
	return data


static func default_sim_state() -> Dictionary:
	return {
		"clock": {"tick": 0},
		# No random events exist yet, so a fixed seed is fine for old saves.
		"rng": {"seed": "1"},
		"events": {"next_id": 1, "events": []}
	}
