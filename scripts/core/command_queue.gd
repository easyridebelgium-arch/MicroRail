extends RefCounted
## Player commands scheduled for a specific simulation tick.
##
## Gameplay-changing input (build, demolish, buy, reassign) should be queued
## here instead of changing the world straight from an input handler. The main
## loop drains the queue at the start of every simulation step, so the same
## starting state plus the same commands at the same ticks gives the same result.
##
## Usage in the main loop:
##     for command in command_queue.drain(sim_clock.tick):
##         _execute_command(command)
##
## Commands are plain data: {"seq", "tick", "type", "data"}. `data` may hold
## simple values only. Execution is the caller's job; this class only orders.

const MAX_PENDING: int = 256
const MAX_TYPE_LENGTH: int = 64
const MAX_SAVED_TICK: int = 1_000_000_000_000

## Increases for every accepted command; breaks ties between equal ticks.
var next_seq: int = 1

var _pending: Array[Dictionary] = []


## Queues a command for `tick`. A tick in the past runs on the next drain.
## Returns the command, or an empty Dictionary if it was rejected (empty or
## over-long type, negative tick, or a full queue).
func enqueue(tick: int, type: String, data: Dictionary = {}) -> Dictionary:
	if tick < 0 or tick > MAX_SAVED_TICK:
		return {}

	if type.is_empty() or type.length() > MAX_TYPE_LENGTH:
		return {}

	if _pending.size() >= MAX_PENDING:
		return {}

	var command: Dictionary = {
		"seq": next_seq,
		"tick": tick,
		"type": type,
		"data": data.duplicate(true)
	}

	next_seq += 1
	_pending.append(command)
	return command


## Removes and returns every command due at or before `current_tick`, ordered
## by tick and then by the order they were queued.
func drain(current_tick: int) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	var remaining: Array[Dictionary] = []

	for command in _pending:
		if int(command["tick"]) <= current_tick:
			due.append(command)
		else:
			remaining.append(command)

	_pending = remaining
	due.sort_custom(_before)
	return due


func count() -> int:
	return _pending.size()


func is_empty() -> bool:
	return _pending.is_empty()


func clear() -> void:
	_pending.clear()


func save_state() -> Dictionary:
	return {
		"next_seq": next_seq,
		"pending": _pending.duplicate(true)
	}


## Call only after is_valid_state() succeeded.
func restore_state(state: Dictionary) -> void:
	next_seq = int(state["next_seq"])
	_pending.clear()

	for command in state["pending"]:
		_pending.append({
			"seq": int(command["seq"]),
			"tick": int(command["tick"]),
			"type": str(command["type"]),
			"data": (command["data"] as Dictionary).duplicate(true)
		})


static func is_valid_state(state: Variant) -> bool:
	if not state is Dictionary:
		return false

	if not _is_whole(state.get("next_seq"), 1.0, float(MAX_SAVED_TICK)):
		return false

	var pending: Variant = state.get("pending")

	if not pending is Array or pending.size() > MAX_PENDING:
		return false

	var seen: Dictionary = {}
	var highest: int = 0

	for command in pending:
		if not command is Dictionary:
			return false

		if not _is_whole(command.get("seq"), 1.0, float(MAX_SAVED_TICK)):
			return false

		if not _is_whole(command.get("tick"), 0.0, float(MAX_SAVED_TICK)):
			return false

		var type: Variant = command.get("type")

		if not type is String or type.is_empty() or type.length() > MAX_TYPE_LENGTH:
			return false

		if not command.get("data") is Dictionary:
			return false

		var seq: int = int(command["seq"])

		if seen.has(seq):
			return false

		seen[seq] = true
		highest = maxi(highest, seq)

	# A restored queue must never hand out a sequence number already in use.
	return int(state["next_seq"]) > highest


static func _is_whole(value: Variant, low: float, high: float) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false

	var number: float = float(value)
	return is_finite(number) and number == floor(number) and number >= low and number <= high


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["tick"]) != int(b["tick"]):
		return int(a["tick"]) < int(b["tick"])

	return int(a["seq"]) < int(b["seq"])
