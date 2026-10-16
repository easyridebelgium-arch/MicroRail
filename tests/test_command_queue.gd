extends SceneTree
## Headless checks for the command queue.
## Run: godot --headless --path . --script res://tests/test_command_queue.gd

const CommandQueue = preload("res://scripts/core/command_queue.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run()
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(value: bool, message: String) -> void:
	checks += 1

	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _round_trip(value: Variant) -> Variant:
	var parser := JSON.new()

	if parser.parse(JSON.stringify(value)) != OK:
		return null

	return parser.data


func _run() -> void:
	var queue := CommandQueue.new()
	var late: Dictionary = queue.enqueue(30, "build", {"cell": [1, 2]})
	var early: Dictionary = queue.enqueue(10, "demolish")
	var tie_a: Dictionary = queue.enqueue(10, "buy")
	var tie_b: Dictionary = queue.enqueue(10, "sell")

	check(int(late["seq"]) == 1 and int(tie_b["seq"]) == 4, "sequence numbers count up in queue order")
	check(queue.count() == 4, "four commands pending")
	check(queue.drain(9).is_empty(), "nothing is due before its tick")

	var due: Array[Dictionary] = queue.drain(10)
	var types: Array = []

	for command in due:
		types.append(command["type"])

	check(types == ["demolish", "buy", "sell"], "equal ticks keep queue order (got %s)" % str(types))
	check(queue.count() == 1, "later command stays pending")

	var overdue: Array[Dictionary] = queue.drain(500)
	check(overdue.size() == 1 and overdue[0]["type"] == "build", "overdue commands run on the next drain")
	check(queue.is_empty(), "queue is empty after draining")

	var original: Dictionary = {"nested": {"a": 1}}
	var copied: Dictionary = queue.enqueue(5, "edit", original)
	original["nested"]["a"] = 99
	check(int(copied["data"]["nested"]["a"]) == 1, "enqueue copies the data")

	check(queue.enqueue(-1, "x").is_empty(), "negative tick is rejected")
	check(queue.enqueue(1, "").is_empty(), "empty type is rejected")
	check(queue.enqueue(1, "x".repeat(CommandQueue.MAX_TYPE_LENGTH + 1)).is_empty(), "over-long type is rejected")

	var full := CommandQueue.new()

	for index in range(CommandQueue.MAX_PENDING):
		full.enqueue(index, "fill")

	check(full.enqueue(0, "extra").is_empty(), "a full queue rejects new commands")
	check(full.count() == CommandQueue.MAX_PENDING, "a full queue stays at its limit")

	# Save, JSON round trip, restore.
	var source := CommandQueue.new()
	source.enqueue(40, "build", {"cell": [3, 4]})
	source.enqueue(20, "buy")
	var saved: Variant = _round_trip(source.save_state())
	check(CommandQueue.is_valid_state(saved), "saved state is valid")

	var restored := CommandQueue.new()
	restored.restore_state(saved)
	check(restored.next_seq == source.next_seq, "next_seq survives a round trip")

	var again: Array[Dictionary] = restored.drain(100)
	check(again.size() == 2 and again[0]["type"] == "buy" and int(again[1]["tick"]) == 40, "restored commands run in order")
	check(typeof(again[0]["seq"]) == TYPE_INT and typeof(again[0]["tick"]) == TYPE_INT, "restored numbers are integers again")
	check(restored.enqueue(1, "new")["seq"] == 3, "new commands continue the sequence")

	# Damaged states must be rejected before they can touch the game.
	var good: Dictionary = {"next_seq": 2, "pending": [{"seq": 1, "tick": 5, "type": "a", "data": {}}]}
	check(CommandQueue.is_valid_state(good), "minimal valid state")
	check(not CommandQueue.is_valid_state({"next_seq": 1, "pending": good["pending"]}), "next_seq must exceed every pending seq")
	check(not CommandQueue.is_valid_state({"next_seq": 0, "pending": []}), "next_seq below 1 is invalid")
	check(not CommandQueue.is_valid_state({"next_seq": 2, "pending": [good["pending"][0], good["pending"][0]]}), "duplicate seq is invalid")
	check(not CommandQueue.is_valid_state({"next_seq": 2, "pending": [{"seq": 1, "tick": 1.5, "type": "a", "data": {}}]}), "fractional tick is invalid")
	check(not CommandQueue.is_valid_state({"next_seq": 2, "pending": [{"seq": 1, "tick": 1, "type": "", "data": {}}]}), "empty type is invalid")
	check(not CommandQueue.is_valid_state({"next_seq": 2, "pending": [{"seq": 1, "tick": 1, "type": "a", "data": 5}]}), "non-dictionary data is invalid")
	check(not CommandQueue.is_valid_state({"next_seq": 2, "pending": "x"}), "non-array pending is invalid")
	check(not CommandQueue.is_valid_state(5), "non-dictionary state is invalid")
