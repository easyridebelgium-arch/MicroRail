extends RefCounted
## The one random number generator for simulation code.
##
## RULE: simulation code must never call the global randf(), randi(),
## Array.shuffle() or Array.pick_random(). Those use a global generator that
## is not saved, so seeds, replays and challenges would stop being repeatable.
## Cosmetic randomness (particles, UI) may still use the global functions.

var seed_value: int = 0

var _rng := RandomNumberGenerator.new()


func _init(initial_seed: int = 0) -> void:
	set_seed(initial_seed)


func set_seed(new_seed: int) -> void:
	seed_value = new_seed
	_rng.seed = new_seed


## Picks a fresh seed for a new game and returns it (so it can be shown/shared).
func randomize_seed() -> int:
	var fresh: int = int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_usec()
	set_seed(fresh & 0x7FFFFFFFFFFFFFFF)
	return seed_value


func randf() -> float:
	return _rng.randf()


func randi() -> int:
	return _rng.randi()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## True with the given probability (0.0 to 1.0).
func chance(probability: float) -> bool:
	return _rng.randf() < probability


## Random element of a non-empty array, or null when it is empty.
func pick(items: Array) -> Variant:
	if items.is_empty():
		return null

	return items[_rng.randi_range(0, items.size() - 1)]


## In-place Fisher-Yates shuffle using this generator.
func shuffle(items: Array) -> void:
	for index in range(items.size() - 1, 0, -1):
		var other: int = _rng.randi_range(0, index)
		var held: Variant = items[index]
		items[index] = items[other]
		items[other] = held


# JSON stores numbers as 64-bit floats, which cannot hold a full 64-bit state.
# Seed and state are therefore saved as decimal strings.
func save_state() -> Dictionary:
	return {
		"seed": str(seed_value),
		"state": str(_rng.state)
	}


func restore_state(state: Dictionary) -> void:
	set_seed(str(state["seed"]).to_int())

	# Seeding resets the stream; the saved state continues it exactly.
	if state.has("state"):
		_rng.state = str(state["state"]).to_int()


static func is_valid_state(state: Variant) -> bool:
	if not state is Dictionary:
		return false

	if not state.get("seed") is String or not state["seed"].is_valid_int():
		return false

	# "state" is optional: migrated saves only carry a seed.
	if state.has("state"):
		if not state["state"] is String or not state["state"].is_valid_int():
			return false

	return true
