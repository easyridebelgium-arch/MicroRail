class_name PassengerServiceState
extends RefCounted
## Independent runtime for an additional passenger service. Shared track grants,
## queues, income and events remain owned by the game, not by this service.
const Services = preload("res://scripts/service_routes.gd")
const Runtime = preload("res://scripts/core/runtime_routes.gd")
const Directional = preload("res://scripts/core/directional_routes.gd")
const FleetData = preload("res://scripts/fleet.gd")
var key: String
var configuration: Dictionary
var cells: Array[Vector2i] = []
var path := Curve2D.new()
var distances: Array[float] = []
var distance := 0.0
var stop_index := 0
var forward := true
var dwell := 0.0
var boarding := true
var passengers := 0
var enabled := true
var held := false
var returning := false
var return_stop := 0
var operating_timer := 0.0
var position := Vector2.ZERO
var heading := 0.0
var connected := false
var travel := Directional.new()

func configure(service_key: String, service: Dictionary, built: Dictionary) -> void:
	key = service_key
	configuration = service.duplicate(true)
	cells.assign(built.cells)
	path = built.path
	distances.assign(built.distances)
	distance = 0
	stop_index = 0
	return_stop = 0
	forward = true
	dwell = 0
	boarding = true
	update_transform()

func is_loop() -> bool: return configuration.get("mode", "shuttle") == "loop"
func next_stop() -> int:
	if returning: return return_stop
	return (stop_index + 1) % configuration.stops.size() if is_loop() else stop_index + (1 if forward else -1)
func target_distance() -> float:
	return distances[stop_index + 1] if is_loop() and not returning else distances[next_stop()]
func at_home() -> bool:
	return distance <= 0.001 and stop_index == 0 and forward and passengers == 0 and not returning
func active() -> bool:
	return connected and not held and (returning or enabled or not at_home())

func check_route(game: Node, notify: bool = true) -> void:
	var was_clear := connected
	connected = not cells.is_empty() and travel.is_clear(cells, path, distance, target_distance(), game.tracks, float(game.TILE_SIZE))
	if notify and was_clear and not connected:
		game._show_notice("%s stopped: track incomplete ahead. Repair its path to continue." % configuration.name)

func rebuild_at_home(game: Node) -> void:
	if at_home():
		var built := Services.build(game.tracks, configuration.stops, float(game.TILE_SIZE), configuration.get("waypoints", {}), configuration.get("mode", "shuttle"))
		if not built.cells.is_empty() and built.cells != cells: configure(key, configuration, built)
	check_route(game)

func advance(game: Node, delta: float) -> void:
	if not active(): return
	var train: Dictionary = FleetData.assigned(game.fleet, key)
	var id := str(train.id)
	operating_timer += delta
	while operating_timer >= 1.0:
		operating_timer -= 1.0
		var cost := int(FleetData.MODELS[train.model].running_cost)
		game.money -= cost
		game.total_operating_cost += cost
	if dwell > 0:
		dwell = maxf(0, dwell - delta)
		return
	if boarding:
		var origin: String = configuration.stops[stop_index]
		var count: int = mini(game._waiting(origin), FleetData.capacity(train) - passengers)
		game._set_waiting(origin, game._waiting(origin) - count)
		passengers += count
		boarding = false
		game._record_event(game.EventLog.TRAIN_DEPARTED, id, {"service": key, "stop": origin, "passengers": passengers})
	var destination := next_stop()
	var target := target_distance()
	distance = game._reserved_movement(key, path, distance, move_toward(distance, target, FleetData.speed(train) * delta))
	if absf(distance - target) < 0.001:
		distance = target
		if returning:
			var origin: String = configuration.stops[stop_index]
			game._set_waiting(origin, game._waiting(origin) + passengers)
			passengers = 0
			returning = false
			held = true
			enabled = false
			forward = not forward
			boarding = true
			dwell = 0
			game._record_event(game.EventLog.TRAIN_RECOVERED, id, {"service": key, "stop": origin, "action": "returned to departure stop"})
		else:
			game.passengers_delivered += passengers
			game.money += passengers * game.TICKET_PRICE
			game._record_event(game.EventLog.TRAIN_ARRIVED, id, {"service": key, "stop": configuration.stops[destination], "passengers": passengers})
			passengers = 0
			stop_index = destination
			if is_loop():
				if stop_index == 0: distance = 0
				forward = true
			elif stop_index == distances.size() - 1: forward = false
			elif stop_index == 0: forward = true
			dwell = game.STATION_WAIT
			boarding = true
	update_transform()

func reverse() -> void:
	return_stop = stop_index
	returning = true
	held = false
	forward = not forward
	dwell = 0
	update_transform()

func update_transform() -> void:
	if path.point_count < 2: return
	position = path.sample_baked(distance)
	var tangent := path.sample_baked(minf(path.get_baked_length(), distance + 1)) - path.sample_baked(maxf(0, distance - 1))
	if not forward: tangent = -tangent
	heading = tangent.angle()

func status(game: Node) -> String:
	var title: String = configuration.name
	if held: return title + ": held here — enable in Fleet or resume in Traffic"
	if not connected: return title + ": Route incomplete ahead — stopped here. Repair the path to the next destination."
	if returning: return title + ": reversing to " + Services.STATIONS[configuration.stops[return_stop]].name
	if not enabled and at_home(): return title + ": withdrawn at first stop"
	if game.reservation_waits.has(key): return title + ": " + str(game.reservation_waits[key])
	if dwell > 0: return "%s: departing %s in %.1f seconds" % [title, Services.STATIONS[configuration.stops[stop_index]].name, dwell]
	return title + (": withdrawing; travelling to " if not enabled else ": travelling to ") + Services.STATIONS[configuration.stops[next_stop()]].name

func save_state() -> Dictionary:
	return {"cells": Runtime.encode(cells), "distance": distance, "stop_index": stop_index, "forward": forward, "dwell": dwell, "boarding": boarding, "passengers": passengers, "enabled": enabled, "held": held, "returning": returning, "return_stop": return_stop, "operating_timer": operating_timer}

static func from_save(service_key: String, value: Variant, service: Dictionary, capacity: int) -> PassengerServiceState:
	if not value is Dictionary or not Runtime.valid_cells(value.get("cells")): return null
	for field in ["forward", "boarding", "enabled", "held", "returning"]:
		if typeof(value.get(field)) != TYPE_BOOL: return null
	for field in ["distance", "stop_index", "dwell", "passengers", "return_stop", "operating_timer"]:
		var number: Variant = value.get(field)
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)) or float(number) < 0: return null
	for field in ["stop_index", "passengers", "return_stop"]:
		if float(value[field]) != floor(float(value[field])): return null
	if value.stop_index >= service.stops.size() or value.return_stop >= service.stops.size() or value.passengers > capacity or value.dwell > 2 or value.operating_timer >= 1: return null
	if value.returning and value.return_stop != value.stop_index: return null
	var built := Runtime.passenger_path(Runtime.decode(value.cells), service.stops, 32, service.get("waypoints", {}), service.get("mode", "shuttle"))
	if built.is_empty() or built.cells.is_empty(): return null
	var original_forward: bool = not value.forward if value.returning else value.forward
	if service.get("mode", "shuttle") == "loop" and not original_forward: return null
	var next: int = int(value.stop_index) + (1 if original_forward else -1)
	if next < 0 or next >= built.distances.size(): return null
	var start: float = built.distances[int(value.stop_index)]
	var end: float = built.distances[next]
	if float(value.distance) < minf(start, end) - 0.001 or float(value.distance) > maxf(start, end) + 0.001: return null
	if (value.boarding or value.dwell > 0) and absf(float(value.distance) - start) > 0.001: return null
	var result := PassengerServiceState.new()
	result.configure(service_key, service, built)
	for field in ["forward", "boarding", "enabled", "held", "returning"]: result.set(field, value[field])
	for field in ["stop_index", "passengers", "return_stop"]: result.set(field, int(value[field]))
	for field in ["distance", "dwell", "operating_timer"]: result.set(field, float(value[field]))
	result.update_transform()
	return result
