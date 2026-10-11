extends RefCounted
## Notification decisions do not alter or filter the canonical event stream.
const Events = preload("res://scripts/core/event_log.gd")
const OFF := 0
const NOTICE := 1
const PAUSE := 2
const ORDER: Array[String] = ["waiting", "deadlocks", "recovery"]
const LABELS := {"waiting": "Signal / reservation waits", "deadlocks": "Confirmed deadlocks", "recovery": "Reversal / recovery / cleared deadlocks"}
const MAX_PENDING := 32
var _pause_requested := false
var _last_id := 0
var _pending: Array[Dictionary] = []

static func defaults() -> Dictionary:
	return {"waiting": OFF, "deadlocks": NOTICE, "recovery": OFF}

static func normalize(value: Variant) -> Dictionary:
	var rules := defaults()
	if not value is Dictionary: return rules
	for key in ORDER:
		var mode: Variant = value.get(key)
		if typeof(mode) == TYPE_INT and mode >= OFF and mode <= PAUSE: rules[key] = mode
	return rules

static func category(type: String) -> String:
	match type:
		Events.TRAIN_WAITING: return "waiting"
		Events.DEADLOCK_DETECTED: return "deadlocks"
		Events.DEADLOCK_CLEARED, Events.TRAIN_REVERSED, Events.TRAIN_RECOVERED: return "recovery"
	return ""

func reset() -> void:
	_last_id = 0
	_pause_requested = false
	_pending.clear()

func consume(event: Dictionary, rules: Dictionary) -> void:
	var id := int(event.id)
	if id <= _last_id: return
	_last_id = id
	var key := category(str(event.type))
	if key.is_empty(): return
	var mode: int = normalize(rules)[key]
	if mode == OFF: return
	_pause_requested = _pause_requested or mode == PAUSE
	var priority := 2 if key == "deadlocks" else 1 if key == "waiting" else 0
	var item := {"text": Events.summary(event), "pause": mode == PAUSE, "priority": priority}
	if _pending.size() >= MAX_PENDING:
		# Keep severe alerts when low-priority chatter fills the bounded queue.
		var lowest := 0
		for index in range(1, _pending.size()):
			if _pending[index].priority < _pending[lowest].priority: lowest = index
		if priority < int(_pending[lowest].priority): return
		_pending.remove_at(lowest)
	_pending.append(item)

func take(pause_allowed: bool = true) -> Dictionary:
	if _pending.is_empty(): return {}
	var selected: Dictionary = _pending[0]
	var pause := _pause_requested
	for item in _pending:
		pause = pause or bool(item.pause)
		if int(item.priority) >= int(selected.priority): selected = item
	var text: String = selected.text
	if _pending.size() > 1: text += " (+%d other alerts; see Problems)" % (_pending.size() - 1)
	_pending.clear()
	_pause_requested = false
	return {"text": text, "pause": pause and pause_allowed}
