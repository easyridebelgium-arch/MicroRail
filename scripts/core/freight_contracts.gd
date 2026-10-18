extends RefCounted
## Optional one-off terminal orders. No queues, transfers or stockpile credits.
const Numbers = preload("res://scripts/core/arrival_targets.gd")
const MAX_TICK := 1000000000000
const DEFINITIONS := {
	"logs": {"target": 40, "hours": 12, "bonus": 200},
	"timber": {"target": 20, "hours": 18, "bonus": 300},
	"goods": {"target": 12, "hours": 24, "bonus": 450}
}
var state: Dictionary = defaults()
static func defaults() -> Dictionary:
	var result: Dictionary = {}
	for kind in DEFINITIONS: result[kind] = {"status": "available", "accepted": -1, "deadline": -1, "finished": -1, "delivered": 0, "baseline": 0}
	return result
func active() -> String:
	for kind in state:
		if state[kind].status == "active": return kind
	return ""
func accept(kind: String, tick: int, totals: Dictionary) -> bool:
	if not DEFINITIONS.has(kind) or state[kind].status != "available" or active() != "": return false
	var deadline: int = tick + int(DEFINITIONS[kind].hours) * 3600
	if tick < 0 or deadline > MAX_TICK: return false
	state[kind] = {"status": "active", "accepted": tick, "deadline": deadline, "finished": -1, "delivered": 0, "baseline": int(totals.get(kind, 0))}
	return true
func advance(tick: int) -> String:
	var kind := active()
	if kind == "" or tick <= int(state[kind].deadline): return ""
	state[kind].status = "expired"
	state[kind].finished = tick
	return kind
func deliver(kind: String, amount: int, tick: int) -> int:
	if not DEFINITIONS.has(kind) or amount <= 0 or state[kind].status != "active" or tick < int(state[kind].accepted) or tick > int(state[kind].deadline): return 0
	var row: Dictionary = state[kind]
	row.delivered = mini(int(DEFINITIONS[kind].target), int(row.delivered) + amount)
	if row.delivered < int(DEFINITIONS[kind].target): return 0
	row.status = "completed"
	row.finished = tick
	return int(DEFINITIONS[kind].bonus)
func earned() -> int:
	var result := 0
	for kind in state:
		if state[kind].status == "completed": result += int(DEFINITIONS[kind].bonus)
	return result
func save_state() -> Dictionary: return state.duplicate(true)
func restore_state(value: Dictionary) -> void:
	state = value.duplicate(true)
	for row in state.values():
		for field in ["accepted", "deadline", "finished", "delivered", "baseline"]: row[field] = int(row[field])
static func valid(value: Variant, tick: int, totals: Dictionary) -> bool:
	if not value is Dictionary or value.size() != DEFINITIONS.size(): return false
	var active_count := 0
	for kind in DEFINITIONS:
		var row: Variant = value.get(kind)
		if not row is Dictionary or row.size() != 6 or row.get("status") not in ["available", "active", "completed", "expired"]: return false
		for field in ["accepted", "deadline", "finished", "delivered", "baseline"]:
			if not Numbers.whole(row.get(field), -1 if field in ["accepted", "deadline", "finished"] else 0, MAX_TICK): return false
		if row.status == "available":
			if row.accepted != -1 or row.deadline != -1 or row.finished != -1 or row.delivered != 0 or row.baseline != 0: return false
			continue
		if row.accepted < 0 or row.accepted > tick or int(row.deadline) != int(row.accepted) + int(DEFINITIONS[kind].hours) * 3600: return false
		if int(row.baseline) + int(row.delivered) > int(totals.get(kind, 0)) or row.delivered > DEFINITIONS[kind].target: return false
		if row.status == "active":
			active_count += 1
			if row.finished != -1 or tick > row.deadline or row.delivered >= DEFINITIONS[kind].target: return false
		elif row.status == "completed":
			if row.delivered != DEFINITIONS[kind].target or row.finished < row.accepted or row.finished > row.deadline or row.finished > tick: return false
		else:
			if row.finished <= row.deadline or row.finished > tick or row.delivered >= DEFINITIONS[kind].target: return false
	return active_count <= 1
