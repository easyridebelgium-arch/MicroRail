extends RefCounted
## Single stream of game events: who (train / station), when (sim tick) and
## what (event type). Alerts, the news journal, the incident log and replay
## markers should all read from here instead of keeping their own records.
##
## Event data should hold only simple values (numbers, strings, booleans).
## After a save/load round trip, whole numbers come back as floats, so read
## them with int().

signal event_recorded(event: Dictionary)

# Event types. Add new ones here so names stay consistent.
const TRAIN_DEPARTED: String = "train_departed"
const TRAIN_WAITING: String = "train_waiting"
const TRAIN_ARRIVED: String = "train_arrived"
const CARGO_DELIVERED: String = "cargo_delivered"
const TRACK_BUILT: String = "track_built"
const TRACK_DEMOLISHED: String = "track_demolished"
const SWITCH_CHANGED: String = "switch_changed"
const ROUTE_CHANGED: String = "route_changed"
const OBJECTIVE_COMPLETED: String = "objective_completed"
const UPGRADE_BOUGHT: String = "upgrade_bought"
const SERVICE_TOGGLED: String = "service_toggled"
const CONSTRUCTION_UNDONE: String = "construction_undone"
const CONSTRUCTION_REDONE: String = "construction_redone"

const MAX_EVENTS: int = 2000
const MAX_SAVED_EVENTS: int = 200
const MAX_TEXT_LENGTH: int = 40

## Print every event to the Output panel (debugging aid).
var echo_to_output: bool = false

var _events: Array[Dictionary] = []
var _next_id: int = 1


func record(tick: int, type: String, subject: String, data: Dictionary = {}) -> Dictionary:
	var event: Dictionary = {
		"id": _next_id,
		"tick": tick,
		"type": type,
		"subject": subject,
		"data": data
	}

	_next_id += 1
	_events.append(event)

	if _events.size() > MAX_EVENTS:
		_events.pop_front()

	if echo_to_output:
		print(describe(event))

	event_recorded.emit(event)
	return event


func count() -> int:
	return _events.size()


## Newest events last. Pass 0 for everything held in memory.
func recent(maximum: int = 0) -> Array[Dictionary]:
	if maximum <= 0 or maximum >= _events.size():
		return _events.duplicate()

	var result: Array[Dictionary] = []
	result.assign(_events.slice(_events.size() - maximum))
	return result


## Filter by any combination of type, subject and earliest tick.
## An empty type or subject matches everything.
func query(type: String = "", subject: String = "", since_tick: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for event in _events:
		if not type.is_empty() and event["type"] != type:
			continue

		if not subject.is_empty() and event["subject"] != subject:
			continue

		if int(event["tick"]) < since_tick:
			continue

		result.append(event)

	return result


func clear() -> void:
	_events.clear()
	_next_id = 1


static func describe(event: Dictionary) -> String:
	return "[t=%d #%d] %s %s %s" % [
		int(event["tick"]),
		int(event["id"]),
		event["subject"],
		event["type"],
		JSON.stringify(event["data"])
	]


## Short line for the in-game event log. Colour is not used as the only cue.
static func summary(event: Dictionary) -> String:
	var data: Dictionary = event.get("data", {})
	var kind: String = str(event.get("type", ""))
	var who: String = str(event.get("subject", ""))

	match kind:
		TRAIN_WAITING:
			return "Train #%s: %s" % [who, data.get("reason", "Waiting for track")]
		TRAIN_DEPARTED:
			return "%s departed %s" % [who, data.get("stop", "")]
		TRAIN_ARRIVED:
			return "%s arrived at %s" % [who, data.get("stop", "")]
		CARGO_DELIVERED:
			return "Delivered %s logs" % str(int(data.get("logs", 0)))
		TRACK_BUILT:
			return "Built %s tiles" % str(int(data.get("new_tiles", data.get("tiles", 0))))
		TRACK_DEMOLISHED:
			return "Removed %s tiles" % str(int(data.get("tiles", 0)))
		SWITCH_CHANGED:
			return "Switch %s" % str(data.get("change", "changed"))
		ROUTE_CHANGED:
			return "Passenger route updated"
		OBJECTIVE_COMPLETED:
			return "Objective completed"
		UPGRADE_BOUGHT:
			return "%s bought a %s upgrade" % [who, str(data.get("kind", ""))]
		SERVICE_TOGGLED:
			return "%s service %s" % [who, "enabled" if bool(data.get("enabled", false)) else "withdrawn"]
		CONSTRUCTION_UNDONE:
			return "Construction undone"
		CONSTRUCTION_REDONE:
			return "Construction redone"
		_:
			return "%s %s" % [who, kind]


func save_state() -> Dictionary:
	var kept: Array = _events.slice(maxi(0, _events.size() - MAX_SAVED_EVENTS))

	return {
		"next_id": _next_id,
		"events": kept.duplicate(true)
	}


func restore_state(state: Dictionary) -> void:
	_events.clear()

	for entry in state["events"]:
		_events.append({
			"id": int(entry["id"]),
			"tick": int(entry["tick"]),
			"type": entry["type"],
			"subject": entry["subject"],
			"data": entry["data"].duplicate(true)
		})

	_next_id = int(state["next_id"])


static func is_valid_state(state: Variant) -> bool:
	if not state is Dictionary:
		return false

	if not _is_whole_number(state.get("next_id")) or float(state["next_id"]) < 1.0:
		return false

	if not state.get("events") is Array:
		return false

	var events: Array = state["events"]

	if events.size() > MAX_EVENTS:
		return false

	var previous_id: float = 0.0

	for entry in events:
		if not entry is Dictionary:
			return false

		if not _is_whole_number(entry.get("id")) or not _is_whole_number(entry.get("tick")):
			return false

		if float(entry["id"]) <= previous_id or float(entry["id"]) >= float(state["next_id"]):
			return false

		previous_id = float(entry["id"])

		if float(entry["tick"]) < 0.0:
			return false

		for field in ["type", "subject"]:
			if not entry.get(field) is String:
				return false

			if entry[field].is_empty() or entry[field].length() > MAX_TEXT_LENGTH:
				return false

		if not entry.get("data") is Dictionary:
			return false

	return true


static func _is_whole_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false

	var number: float = float(value)
	return is_finite(number) and number == floor(number) and absf(number) < 1.0e12
