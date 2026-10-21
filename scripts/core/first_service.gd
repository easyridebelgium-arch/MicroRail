extends RefCounted
## Read-only onboarding derived from the live graph and actual final deliveries.
const Router = preload("res://scripts/rail_router.gd")
const Advice = preload("res://scripts/core/first_connection_advice.gd")
const FleetData = preload("res://scripts/fleet.gd")

static func inspect(game: Node) -> Dictionary:
	if game.seeded_challenge.state.id == "passing_place": return shared_inspect(game)
	if game.seeded_challenge.state.id == "timber_connection": return freight_inspect(game)
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
	var suggestion := "The tutorial train is already provided. Connect A–B and resume; no Fleet or Routes setup is needed."
	if city_mode:
		suggestion = Advice.describe(game.world.state, game.river_terrain, game.money, game.tracks, game.track_signals, game.reservations.owners) if stations.is_empty() else nearest_pair(game.world.state.settlements)
	return {"city_mode": city_mode, "rows": rows, "next": next_index, "done": done_count, "complete": next_index == rows.size(), "connection": connection, "suggestion": suggestion, "delivered": game.passengers_delivered}

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

static func freight_inspect(game: Node) -> Dictionary:
	var order: Dictionary = game.freight_contracts.state.timber
	var owns := false
	for train in game.fleet.trains:
		if FleetData.MODELS[train.model].kind == "freight": owns = true
	var rows: Array[Dictionary] = [
		{"done": not Router.find_route(game.tracks, game.FOREST_SITE, game.CARGO_TERMINAL).is_empty(), "title": "Connect Forest through Sawmill to Terminal", "hint": "The industry loading tiles form one horizontal line. Drag along it; no passenger stations are needed. Keep the Sawmill building footprint above its loading tile clear.", "action": "connect", "button": "Choose Connect track"},
		{"done": owns, "title": "Buy a Log Hauler (£500)", "hint": "Open Fleet and buy the freight locomotive. The guide makes no purchases.", "action": "fleet", "button": "Open Fleet"},
		{"done": game.services.has("freight"), "title": "Start its freight service in Fleet", "hint": "Select the stored Log Hauler and start freight service. Stay paused so it remains empty at Forest.", "action": "fleet", "button": "Open Fleet"},
		{"done": game.sawmill.state.installed, "title": "Install the Sawmill (£500)", "hint": "In the Forest inspector choose Build Sawmill while the train is empty at Forest. Do not install Factory until the timber order is complete.", "action": "forest", "button": "Inspect Forest"},
		{"done": order.status != "available", "title": "Accept the Timber order when ready", "hint": "Accounts → Freight contracts: accept Timber. The 18-game-hour deadline starts now; only later terminal deliveries count.", "action": "contracts", "button": "Review Timber order"},
		{"done": order.status == "completed", "title": "Deliver 20 timber to Terminal", "hint": "Resume. Logs become timber at the Sawmill; only Terminal deliveries finish the order. Expiry requires a new scenario to retry; ordinary company play remains available.", "action": "run" if order.status != "expired" else "contracts", "button": "Resume and watch freight" if order.status != "expired" else "Review expired order"}
	]
	var next_index := rows.size()
	var done_count := 0
	for index in range(rows.size()):
		if rows[index].done: done_count += 1
		elif next_index == rows.size(): next_index = index
	return {"freight": true, "city_mode": true, "rows": rows, "next": next_index, "done": done_count, "complete": next_index == rows.size(), "connection": "Industry corridor", "suggestion": "Timber Connection: untimed preparation, then 20 timber within 18 game hours. Normal contract bonus £300; no extra scenario reward.", "delivered": order.delivered}

static func shared_inspect(game: Node) -> Dictionary:
	var measured: Dictionary = game.shared_track_progress()
	var finished: bool = int(game.seeded_challenge.state.completed_tick) >= 0
	var rows: Array[Dictionary] = [
		{"done": measured.stations, "title": "Build Town 3 Station (30,14) and Town 2 Station (66,14)", "hint": "Pause and use Station to build at those exact cells below the two towns. Each five-tile station costs £300. No stations or trains are provided.", "action": "stations", "button": "Choose Station tool"},
		{"done": measured.connected, "title": "Connect the two horizontal platform ends", "hint": "Connect along row 14, leaving each platform along its rails. The recommended connecting track costs £310 before the loop.", "action": "connect", "button": "Choose Connect track"},
		{"done": measured.loop and measured.boundaries, "title": "Draft and apply the passing loop at (44,14)", "hint": "Default 9×4 loop below the main line. Review train fit, signal blocks and £330 extra cost in Overlays, then Apply plan. Keep all four automatic boundaries; the Guide only drafts the geometry.", "action": "shared_preview", "button": "Draft suggested passing loop"},
		{"done": measured.owns_two, "title": "Buy two Passenger Shuttles (£400 each)", "hint": "Use Fleet. The checked total investment, including stations, track and loop, is £2040. Stay paused until both routes are ready.", "action": "fleet", "button": "Open Fleet"},
		{"done": measured.opposing, "title": "Start opposite Shuttle services: Town 3→2 and Town 2→3", "hint": "In Fleet start one stored train at Town 3 Station for Town 2 Station, and the other at Town 2 Station for Town 3 Station. Keep Shuttle mode and two stops each. Do not resume yet.", "action": "fleet", "button": "Open Fleet"},
		{"done": measured.ready, "title": "Give only Town 2→3 the loop waypoint (48,17)", "hint": "Open Routes, select the Town 2→3 service and leg, Add waypoint 48,17, review and Apply. Leave Town 3→2 on the main branch. Existing safe-edit rules apply: both trains should still be empty at their first stops.", "action": "shared_routes", "button": "Open loop waypoint in Routes"},
		{"done": finished, "title": "Complete ten final passenger journeys with each service", "hint": "Resume when both routes are ready. Boarding and waiting queues do not count. Goals counts new final deliveries after both routes are ready. Keep both routes ready while running; resuming with incomplete setup or a different service pair restarts unfinished progress. Maintain the prescribed loop and signal boundaries until completion; afterwards you can change the company freely.", "action": "run", "button": "Resume and watch both services"}
	]
	var next_index := rows.size()
	var done_count := 0
	for index in range(rows.size()):
		if finished: rows[index].done = true
		if rows[index].done: done_count += 1
		elif next_index == rows.size(): next_index = index
	return {"shared": true, "city_mode": true, "rows": rows, "next": next_index, "done": done_count, "complete": finished, "connection": "Town 3 ↔ Town 2", "suggestion": "Passing Place: fixed teaching layout, £5000, £2040 checked setup, no deadline or extra reward. Loans are available. Complete ten final journeys with each correctly configured opposing service.", "delivered": int(measured.direct_finals) + int(measured.bypass_finals)}
