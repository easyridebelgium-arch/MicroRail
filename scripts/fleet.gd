extends RefCounted

const Consists = preload("res://scripts/core/consists.gd")
const Services = preload("res://scripts/service_routes.gd")

const MODELS: Dictionary = {
	"passenger_standard": {"name": "Passenger Shuttle", "kind": "passenger", "price": 400, "capacity": 20, "speed": 80.0, "running_cost": 1},
	"passenger_fast": {"name": "Fast Passenger", "kind": "passenger", "price": 650, "capacity": 12, "speed": 120.0, "running_cost": 2},
	"freight_standard": {"name": "Log Hauler", "kind": "freight", "price": 500, "capacity": 20, "speed": 60.0, "running_cost": 1},
	"freight_heavy": {"name": "Heavy Log Hauler", "kind": "freight", "price": 650, "capacity": 40, "speed": 40.0, "running_cost": 2},
}
const MAX_TRAINS: int = 100

static func make_train(id: int, model: String, service: String = "") -> Dictionary:
	return {"id": id, "model": model, "name": "%s %d" % [MODELS[model]["name"], id], "service": service, "capacity_level": 0, "speed_level": 0, "wagons": []}

static func defaults() -> Dictionary:
	return {"next_id": 3, "trains": [make_train(1, "passenger_standard", "passenger"), make_train(2, "freight_standard", "freight")]}

static func empty() -> Dictionary:
	return {"next_id": 1, "trains": []}

static func from_save(value: Dictionary) -> Dictionary:
	# JSON numbers are floats; keep stable IDs and levels as integers in memory.
	# Call only after is_valid has checked the complete save.
	var restored: Dictionary = value.duplicate(true)
	restored["next_id"] = int(restored["next_id"])
	for train in restored["trains"]:
		for field in ["id", "capacity_level", "speed_level"]:
			train[field] = int(train[field])
	return restored

static func find(data: Dictionary, id: int) -> Dictionary:
	for train in data["trains"]:
		if int(train["id"]) == id:
			return train
	return {}

static func assigned(data: Dictionary, service: String) -> Dictionary:
	for train in data["trains"]:
		if train["service"] == service:
			return train
	return {}

static func valid_name(value: Variant) -> bool:
	return value is String and not value.is_empty() and value == value.strip_edges() and value.length() <= 40 and not "\n" in value and not "\r" in value

static func _whole(value: Variant, lower: int, upper: int) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number: float = float(value)
	return is_finite(number) and number == floor(number) and number >= lower and number <= upper

## Default save policy requires both original assignments; sandbox opts in explicitly.
static func is_valid(value: Variant, require_primary: bool = true) -> bool:
	if not value is Dictionary or not value.get("trains") is Array or not _whole(value.get("next_id"), 3 if require_primary else 1, 1000000000):
		return false
	if value["trains"].size() < (2 if require_primary else 0) or value["trains"].size() > MAX_TRAINS:
		return false
	var ids: Dictionary = {}
	var assignments: Dictionary = {}
	for train in value["trains"]:
		if not train is Dictionary or not _whole(train.get("id"), 1, int(value["next_id"]) - 1):
			return false
		if ids.has(int(train["id"])):
			return false
		ids[int(train["id"])] = true
		if not train.get("model") is String or not MODELS.has(train["model"]) or not valid_name(train.get("name")):
			return false
		if not _whole(train.get("capacity_level"), 0, 3) or not _whole(train.get("speed_level"), 0, 3):
			return false
		if not Consists.valid(train.get("wagons", []), MODELS[train.model].kind): return false
		var service: Variant = train.get("service")
		if not service is String or not (service == "" or service == "freight" or Services.is_passenger_key(service)):
			return false
		if service != "":
			if MODELS[train["model"]]["kind"] != Services.kind(service) or assignments.has(service):
				return false
			assignments[service] = true
	return not require_primary or (assignments.has("passenger") and assignments.has("freight"))

static func capacity(train: Dictionary) -> int:
	return int(MODELS[train["model"]]["capacity"]) + int(train["capacity_level"]) * 10 + Consists.extra_capacity(train)

static func speed(train: Dictionary) -> float:
	return minf(float(MODELS[train["model"]]["speed"]) + int(train["speed_level"]) * 20.0, Consists.speed_limit(train))

static func sale_price(train: Dictionary) -> int:
	var model: Dictionary = MODELS[train["model"]]
	var capacity_base: int = 250 if model["kind"] == "passenger" else 300
	var speed_base: int = 200 if model["kind"] == "passenger" else 250
	var capacity_level: int = int(train["capacity_level"])
	var speed_level: int = int(train["speed_level"])
	var invested: int = int(model["price"])
	invested += int(capacity_base * capacity_level * (capacity_level + 1) / 2.0)
	invested += int(speed_base * speed_level * (speed_level + 1) / 2.0)
	for wagon in train.get("wagons", []): invested += int(Consists.STOCK[wagon].price)
	return int(invested / 2.0)

static func length(train: Dictionary) -> float:
	return Consists.length(train)

static func running_cost(train: Dictionary) -> int:
	return int(MODELS[train.model].running_cost) + Consists.running_cost(train)
