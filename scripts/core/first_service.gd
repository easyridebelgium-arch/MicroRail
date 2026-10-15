extends RefCounted
## Read-only onboarding derived from the live graph and actual final deliveries.
const Router = preload("res://scripts/rail_router.gd")
const FleetData = preload("res://scripts/fleet.gd")

static func inspect(game: Node) -> Dictionary:
	var city_mode: bool = game.city_builder.is_city_game()
	var stations: Dictionary = game.station_definitions()
	var towns: Dictionary = {}
	for station in stations.values(): towns[station.get("settlement_id", "")] = true
	var connected := false
	var connection := ""
	if city_mode:
		var ids: Array = stations.keys()
		ids.sort()
		for first in range(ids.size()):
			for second in range(first + 1, ids.size()):
				var a: Dictionary = stations[ids[first]]
				var b: Dictionary = stations[ids[second]]
				if a.settlement_id == b.settlement_id: continue
				if not Router.find_route(game.tracks, a.cell, b.cell).is_empty():
					connected = true
					connection = "%s ↔ %s" % [a.name, b.name]
					break
			if connected: break
	else:
		connected = game.route_connected
	var owns_train := false
	for train in game.fleet.trains:
		if FleetData.MODELS[train.model].kind == "passenger": owns_train = true
	var started := false
	for key in game.service_keys():
		if not game.ServiceRoutes.is_passenger_key(key) or not game.service_enabled(key): continue
		if FleetData.assigned(game.fleet, key).is_empty(): continue
		if city_mode:
			var served_towns: Dictionary = {}
			for stop in game.services[key].stops:
				if stations.has(stop): served_towns[stations[stop].settlement_id] = true
			if served_towns.size() < 2: continue
		var intact: bool = game.route_connected if key == "passenger" else game.passenger_services[key].connected
		if intact: started = true
	var rows: Array[Dictionary] = []
	if city_mode:
		rows.append({"id": "stations", "done": towns.size() >= 2, "title": "Build stations beside two different cities", "hint": "Pause, choose Station and build within six tiles of each city. A new five-tile platform usually costs £300. You need two different cities, not two platforms at one city.", "action": "stations", "button": "Choose Station tool"})
	rows.append({"id": "track", "done": connected, "title": "Connect the platforms along their rails" if city_mode else "Connect Station A to Station B", "hint": "Choose Connect track. Start at a highlighted platform end and drag left/right along the rails, not from above or below. Keep junctions outside the platform.", "action": "connect", "button": "Choose Connect track"})
	if city_mode:
		rows.append({"id": "train", "done": owns_train, "title": "Buy a passenger train in Fleet", "hint": "In Fleet, select Passenger Shuttle and Buy (£400). Track, two new stations and the shuttle all come from your starting balance; the guide makes no purchases.", "action": "fleet", "button": "Open Fleet"})
		rows.append({"id": "service", "done": started, "title": "Start its service in Fleet", "hint": "Select your train, choose different departure and destination stations, then Start new passenger service. The default shuttle visits both; scheduling is optional. Already assigned? Use Enable service if withdrawn, or Routes/the train inspector to repair its route.", "action": "fleet", "button": "Open Fleet"})
	rows.append({"id": "delivery", "done": game.passengers_delivered > 0, "title": "Deliver passengers to their final destination", "hint": "Resume the simulation. Passengers must board, travel and arrive. Waiting queues, boarding and transfers do not count as completed deliveries or earn a fare. If a train stays stopped, click it to inspect the reason; the guide never overrides holds or signals.", "action": "run", "button": "Resume and watch trains"})
	var next_index := rows.size()
	var done_count := 0
	for index in range(rows.size()):
		if rows[index].done: done_count += 1
		elif next_index == rows.size(): next_index = index
	return {"city_mode": city_mode, "rows": rows, "next": next_index, "done": done_count, "complete": next_index == rows.size(), "connection": connection, "suggestion": nearest_pair(game.world.state.settlements) if city_mode else "The tutorial train is already provided. Connect A–B and resume; no Fleet or Routes setup is needed.", "delivered": game.passengers_delivered}

static func nearest_pair(settlements: Array) -> String:
	var closest := INF
	var pair := ""
	for first in range(settlements.size()):
		for second in range(first + 1, settlements.size()):
			var a: Dictionary = settlements[first]
			var b: Dictionary = settlements[second]
			var distance := Vector2(float(a.cell[0]) - float(b.cell[0]), float(a.cell[1]) - float(b.cell[1])).length_squared()
			if distance < closest:
				closest = distance
				pair = "%s and %s" % [a.name, b.name]
	return "Nearby starting pair: %s (closest city centres). Check the track preview price before building." % pair if not pair.is_empty() else "Choose two nearby cities."
