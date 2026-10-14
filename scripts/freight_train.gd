extends Node2D

signal delivered(amount: int)
signal logs_received(amount: int)
const Sawmill = preload("res://scripts/core/sawmill.gd")
var industry: RefCounted
var chain_stage := 0
var recovery_stop := "forest"
var leg_origin := "forest"
var sawmill_distance := -1.0
signal operating_expense(amount: int)
signal departed(stop: String, cargo: int)
signal arrived(stop: String, cargo: int)
const Consists = preload("res://scripts/core/consists.gd")
var wagon_speed_limit := INF
var consist_entry: Dictionary = {}
const Router = preload("res://scripts/rail_router.gd")
const Palette = preload("res://scripts/core/palette.gd")

const CAPACITY: int = 20
const SPEED: float = 60.0
const STATION_WAIT: float = 2.0
const OPERATING_COST_PER_SECOND: int = 1
const MAX_CAPACITY_LEVEL: int = 3
const MAX_SPEED_LEVEL: int = 3

const CAPACITY_PER_UPGRADE: int = 10
const SPEED_PER_UPGRADE: float = 20.0

const BASE_CAPACITY_UPGRADE_PRICE: int = 300
const BASE_SPEED_UPGRADE_PRICE: int = 250

enum LoadingRule {
	ANY,
	HALF,
	FULL
}

var base_capacity: int = CAPACITY
var base_speed: float = SPEED
var running_cost_per_second: int = OPERATING_COST_PER_SECOND
var loading_rule: int = LoadingRule.ANY
var home_position: Vector2 = Vector2.ZERO
var cargo: int = 0
var movement_guard: Callable
var reservation_wait: String = ""

var route_cells: Array[Vector2i] = []
var route_path: Curve2D = Curve2D.new()

var distance_along_route: float = 0.0
var to_terminal: bool = true
var dwell: float = 0.0
var operating_timer: float = 0.0
var capacity_level: int = 0
var speed_level: int = 0
var service_enabled: bool = true
var route_valid: bool = true
var recovery_returning: bool = false
var held: bool = false

func set_route(cells: Array[Vector2i], tile_size: float) -> void:
	if cells != route_cells and not route_cells.is_empty() and distance_along_route > 0.001:
		return
	if cells == route_cells:
		return

	route_cells = cells.duplicate()
	route_path = Router.make_path(route_cells, tile_size)

	distance_along_route = 0.0
	to_terminal = true
	dwell = 0.0

	if industry != null: configure_industry(industry, tile_size)
	# Keep onboard logs when a route changes or is disconnected.
	_update_transform()


func advance(delta: float, available_logs: int) -> int:
	if not service_is_active():
		return 0

	_charge_operating_expenses(delta)

	if dwell > 0.0:
		dwell = maxf(0.0, dwell - delta)
		return 0

	var loaded: int = 0
	var route_length: float = route_path.get_baked_length()
	var at_forest: bool = to_terminal and distance_along_route <= 0.001
	var at_terminal: bool = not to_terminal and absf(distance_along_route - route_length) < 0.001

	# Load at the forest before departing.
	if at_forest and not recovery_returning:
		loaded = mini(get_capacity() - cargo, available_logs)
		cargo += loaded

		if cargo < get_minimum_load():
			return loaded

	if chain_enabled() and to_terminal and chain_stage == 1 and absf(distance_along_route - sawmill_distance) < 0.001 and not recovery_returning:
		if not service_enabled and cargo == 0:
			to_terminal = false
		else:
			if service_enabled: cargo += industry.take(get_capacity() - cargo)
			if service_enabled and cargo < get_minimum_load(): return loaded
	var target: float = target_distance()

	var previous_distance := distance_along_route
	distance_along_route = move_toward(
		distance_along_route,
		target,
		get_speed() * delta
	)

	if movement_guard.is_valid():
		distance_along_route = movement_guard.call(route_path, previous_distance, distance_along_route)

	if absf(distance_along_route - target) < 0.001:
		distance_along_route = target
		var stop := recovery_stop if recovery_returning and chain_enabled() else ("sawmill" if chain_enabled() and to_terminal and chain_stage == 0 else "terminal" if to_terminal else "forest")
		if absf(previous_distance - target) > 0.001: arrived.emit(stop, cargo)

		if recovery_returning:
			recovery_returning = false
			held = true
			service_enabled = false
			to_terminal = not to_terminal
			dwell = 0.0
			_update_transform()
			return loaded
		if chain_enabled() and to_terminal and chain_stage == 0:
			var accepted: int = industry.accept(cargo)
			cargo -= accepted
			if accepted > 0: logs_received.emit(accepted)
			if cargo > 0:
				_update_transform()
				return loaded
			chain_stage = 1
			leg_origin = "sawmill"
			dwell = STATION_WAIT
			_update_transform()
			return loaded
		if to_terminal:
			var delivered_amount: int = cargo
			cargo = 0

			if delivered_amount > 0:
				delivered.emit(delivered_amount)

		to_terminal = not to_terminal
		if chain_enabled():
			leg_origin = "forest" if to_terminal else "terminal"
			if to_terminal: chain_stage = 0
		dwell = STATION_WAIT
	elif (at_forest or at_terminal or (chain_enabled() and absf(previous_distance - sawmill_distance) < 0.001)) and absf(distance_along_route - previous_distance) > 0.001:
		departed.emit(leg_origin if chain_enabled() else "forest" if at_forest else "terminal", cargo)

	_update_transform()
	return loaded


func _update_transform() -> void:
	queue_redraw()
	if route_cells.is_empty():
		position = home_position
		rotation = 0.0
		return

	var route_length: float = route_path.get_baked_length()

	position = route_path.sample_baked(distance_along_route)

	var before: Vector2 = route_path.sample_baked(
		maxf(0.0, distance_along_route - 1.0)
	)
	var after: Vector2 = route_path.sample_baked(
		minf(route_length, distance_along_route + 1.0)
	)

	var direction: Vector2 = after - before

	if not to_terminal:
		direction = -direction

	rotation = direction.angle()


func _draw() -> void:
	var offsets := Consists.offsets(consist_entry)
	if offsets.size() > 1 and route_path.point_count >= 2:
		for index in range(offsets.size()):
			var pose := Consists.pose(route_path, distance_along_route + offsets[index])
			draw_set_transform(to_local(pose.position), pose.angle - global_rotation + (0.0 if to_terminal else PI))
			if index == 0: _draw_locomotive()
			else:
				draw_rect(Rect2(Vector2(-12, -7), Vector2(24, 14)), Palette.get_color(Palette.Role.TRAIN_FREIGHT))
				draw_rect(Rect2(Vector2(-12, -7), Vector2(24, 14)), Color.WHITE, false, 1.0)
				for y in [-4, 0, 4]: draw_line(Vector2(-9, y), Vector2(9, y), Color(0.55, 0.32, 0.15), 2.0)
			draw_set_transform(Vector2.ZERO, 0.0)
	else: _draw_locomotive()

func _draw_locomotive() -> void:
	var body := Rect2(Vector2(-14, -8), Vector2(28, 16))

	draw_rect(body, Palette.get_color(Palette.Role.TRAIN_FREIGHT))
	draw_rect(body, Color(0.05, 0.12, 0.22), false, 1.0)

	draw_rect(
		Rect2(Vector2(6, -5), Vector2(6, 10)),
		Color(0.75, 0.9, 1.0)
	)


func status_text() -> String:
	if not route_valid and not route_cells.is_empty(): return "Route incomplete ahead — stopped here. Repair the path to the next destination."
	if held: return "Held by dispatcher at current position"
	if not reservation_wait.is_empty(): return reservation_wait
	if recovery_returning: return "Reversing to " + (recovery_stop if chain_enabled() else "terminal" if to_terminal else "forest")
	if route_cells.is_empty():
		return "Needs a connected freight route"
	if not service_enabled:
		if service_is_active():
			return "Withdrawing after return to forest"

		return "Freight service stopped at forest"

	if dwell > 0.0:
		return "Stopped at loading track"

	if chain_enabled() and to_terminal:
		if chain_stage == 0 and absf(distance_along_route - sawmill_distance) < 0.001 and cargo > 0: return "Sawmill input storage full — waiting to unload logs"
		if chain_stage == 1 and absf(distance_along_route - sawmill_distance) < 0.001: return "Waiting for timber: %d / %d required; sawmill output %d" % [cargo, get_minimum_load(), industry.state.timber]
		if distance_along_route > 0.001: return "Carrying %s to %s" % [cargo_kind(), "sawmill" if chain_stage == 0 else "terminal"]
	if to_terminal:
		if distance_along_route <= 0.001 and cargo < get_minimum_load():
			return "Loading: %d / %d logs required" % [
				cargo,
				get_minimum_load()
			]

		return "Travelling to terminal"

	return "Returning to forest"


func save_state() -> Dictionary:
	return {
		"cargo": cargo,
		"distance": distance_along_route,
		"to_terminal": to_terminal,
		"dwell": dwell,
		"operating_timer": operating_timer,
		"loading_rule": loading_rule,
		"capacity_level": capacity_level,
		"speed_level": speed_level,
		"service_enabled": service_enabled,
		"chain_stage": chain_stage,
		"recovery_stop": recovery_stop,
		"leg_origin": leg_origin
	}


func restore_state(state: Dictionary) -> void:
	cargo = int(state["cargo"])
	chain_stage = int(state.get("chain_stage", 0))
	recovery_stop = str(state.get("recovery_stop", "forest"))
	leg_origin = str(state.get("leg_origin", "forest"))
	distance_along_route = clampf(
		float(state["distance"]),
		0.0,
		route_path.get_baked_length()
	)
	to_terminal = state["to_terminal"]
	dwell = float(state["dwell"])
	operating_timer = float(state["operating_timer"])
	loading_rule = int(state["loading_rule"])
	capacity_level = int(state["capacity_level"])
	speed_level = int(state["speed_level"])
	service_enabled = state["service_enabled"]
	_update_transform()


static func empty_state() -> Dictionary:
	return {
		"cargo": 0,
		"distance": 0.0,
		"to_terminal": true,
		"dwell": 0.0,
		"operating_timer": 0.0,
		"loading_rule": LoadingRule.ANY,
		"capacity_level": 0,
		"speed_level": 0,
		"service_enabled": true,
		"chain_stage": 0,
		"recovery_stop": "forest",
		"leg_origin": "forest"
	}


static func is_valid_state(state: Dictionary, route_length: float, model_capacity: int = CAPACITY) -> bool:
	var stage: Variant = state.get("chain_stage", 0)
	if typeof(stage) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(stage)) or float(stage) != floor(float(stage)) or stage < 0 or stage > 1: return false
	if state.get("recovery_stop", "forest") not in ["forest", "sawmill", "terminal"] or state.get("leg_origin", "forest") not in ["forest", "sawmill", "terminal"]: return false
	if typeof(state.get("service_enabled")) != TYPE_BOOL:
		return false
	if typeof(state.get("to_terminal")) != TYPE_BOOL:
		return false

	for field in [
		"cargo",
		"distance",
		"dwell",
		"operating_timer",
		"loading_rule",
		"capacity_level",
		"speed_level"
	]:
		var value: Variant = state.get(field)

		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			return false

		var number: float = float(value)

		if not is_finite(number) or number < 0.0:
			return false

	# These fields must contain whole numbers.
	for field in [
		"cargo",
		"loading_rule",
		"capacity_level",
		"speed_level"
	]:
		var number: float = float(state[field])

		if number != floor(number):
			return false

	var saved_capacity_level: float = float(state["capacity_level"])
	var saved_speed_level: float = float(state["speed_level"])

	if saved_capacity_level > MAX_CAPACITY_LEVEL:
		return false

	if saved_speed_level > MAX_SPEED_LEVEL:
		return false

	var saved_capacity: int = (
		model_capacity + int(saved_capacity_level) * CAPACITY_PER_UPGRADE
	)

	if float(state["cargo"]) > saved_capacity:
		return false

	if float(state["distance"]) > route_length + 0.001:
		return false

	if float(state["dwell"]) > STATION_WAIT:
		return false

	if float(state["operating_timer"]) >= 1.0:
		return false

	var saved_rule: float = float(state["loading_rule"])

	if saved_rule < LoadingRule.ANY or saved_rule > LoadingRule.FULL:
		return false

	return true
	
func _charge_operating_expenses(delta: float) -> void:
	operating_timer += delta

	while operating_timer >= 1.0:
		operating_timer -= 1.0
		operating_expense.emit(running_cost_per_second)
func get_minimum_load() -> int:
	match loading_rule:
		LoadingRule.HALF:
			return ceili(float(get_capacity()) / 2.0)

		LoadingRule.FULL:
			return get_capacity()

		_:
			return 1
func get_capacity() -> int:
	return base_capacity + capacity_level * CAPACITY_PER_UPGRADE


func get_speed() -> float:
	return minf(base_speed + speed_level * SPEED_PER_UPGRADE, wagon_speed_limit)


func get_capacity_upgrade_price() -> int:
	return BASE_CAPACITY_UPGRADE_PRICE * (capacity_level + 1)


func get_speed_upgrade_price() -> int:
	return BASE_SPEED_UPGRADE_PRICE * (speed_level + 1)
func service_is_active() -> bool:
	if not route_valid or held:
		return false
	if route_cells.is_empty():
		return false

	if recovery_returning or service_enabled:
		return true

	var parked_at_forest: bool = (
		distance_along_route <= 0.001
		and to_terminal
	)

	return not parked_at_forest

func chain_enabled() -> bool:
	return industry != null and industry.state.installed
func configure_industry(value: RefCounted, tile_size: float) -> void:
	industry = value
	sawmill_distance = -1.0
	var index := route_cells.find(Sawmill.CELL)
	if index >= 0: sawmill_distance = Router.make_path(route_cells.slice(0, index + 1), tile_size).get_baked_length()
func target_distance() -> float:
	if chain_enabled():
		if recovery_returning:
			if recovery_stop == "sawmill": return sawmill_distance
			return route_path.get_baked_length() if recovery_stop == "terminal" else 0.0
		if to_terminal and chain_stage == 0: return sawmill_distance
	return route_path.get_baked_length() if to_terminal else 0.0
func departure_distance() -> float:
	if chain_enabled():
		if leg_origin == "sawmill": return sawmill_distance
		return route_path.get_baked_length() if leg_origin == "terminal" else 0.0
	return 0.0 if to_terminal else route_path.get_baked_length()
func cargo_kind() -> String: return "timber" if chain_enabled() and chain_stage == 1 else "logs"
func ready_to_move(available_logs: int) -> bool:
	if not service_is_active() or dwell > 0: return false
	if recovery_returning: return true
	if chain_enabled() and to_terminal and absf(distance_along_route - sawmill_distance) < 0.001:
		if chain_stage == 0: return false
		if not service_enabled: return true
		return cargo + int(industry.state.timber) >= get_minimum_load()
	return not to_terminal or distance_along_route > 0.001 or cargo + available_logs >= get_minimum_load()

static func valid_chain(state: Dictionary, cells: Array[Vector2i], installed: bool, returning: bool, tile_size: float) -> bool:
	if not installed: return int(state.chain_stage) == 0
	var index := cells.find(Sawmill.CELL)
	if index < 0 or cells.count(Sawmill.CELL) != 1: return false
	var distance := Router.make_path(cells.slice(0, index + 1), tile_size).get_baked_length()
	var current := float(state.distance)
	if returning:
		if state.recovery_stop != state.leg_origin: return false
		if state.recovery_stop == "sawmill": return state.chain_stage == 1 and ((current <= distance + 0.001) if state.to_terminal else (current >= distance - 0.001))
		if state.recovery_stop == "forest": return state.chain_stage == 0 and not state.to_terminal and current <= distance + 0.001
		return state.chain_stage == 1 and state.to_terminal and state.cargo == 0
	if state.to_terminal:
		return (state.leg_origin == "forest" and current <= distance + 0.001) if state.chain_stage == 0 else (state.leg_origin == "sawmill" and current >= distance - 0.001)
	return state.chain_stage == 1 and state.cargo == 0 and (state.leg_origin == "terminal" or (state.leg_origin == "sawmill" and current <= distance + 0.001))
