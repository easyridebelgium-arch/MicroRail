extends RefCounted
## Read-only DTO: actual body now, last allocation, and measured movement cause.
static func snapshot(game: Node, id: int) -> Dictionary:
	var train: Dictionary = game.Fleet.find(game.fleet, id)
	if train.is_empty(): return {}
	var key: String = str(train.service)
	var result := {"id": id, "title": "#%d %s" % [id, train.name], "service": key, "state": "Stored", "reason": "Stored off-map; this train has no running route.", "advice": "Open Fleet to assign it to a compatible service or start a passenger service.", "blocker": -1, "cycle": [], "cell": Vector2i(-1, -1), "occupied": [], "granted": [], "requested": [], "blocks": [], "switches": [], "tick": game.authority_tick, "wait_seconds": 0.0}
	if not game.services.has(key): return result
	result.title += " — " + str(game.services[key].name)
	var actual: Dictionary = {}
	for descriptor in game.inspection_trains():
		if descriptor.id == id: actual = descriptor
	if actual.is_empty(): return result
	var path: Curve2D = actual.path
	if path.point_count < 2: path = game.reservation_trains[id].path
	result.occupied = game.reservations.footprint(path, actual.distance, float(game.TILE_SIZE), game.Fleet.length(train))
	for cell in game.reservations.owners:
		if int(game.reservations.owners[cell]) == id: result.granted.append(cell)
	result.requested = game.reservations.requested.get(id, []).duplicate()
	for cell in game.reservations.switch_owners:
		if int(game.reservations.switch_owners[cell]) == id: result.switches.append({"cell": cell, "state": int(game.reservations.switches[cell])})
	var block_ids: Array = []
	if not game.block_signals.signs.is_empty():
		for cell in result.occupied:
			if game.block_signals.cell_blocks.has(cell) and not block_ids.has(game.block_signals.cell_blocks[cell]): block_ids.append(game.block_signals.cell_blocks[cell])
	for block in game.block_signals.block_owners:
		if game.block_signals.block_owners[block].has(id) and not block_ids.has(block): block_ids.append(block)
	for block in game.block_signals.requested_blocks.get(id, []):
		if not block_ids.has(block): block_ids.append(block)
	block_ids.sort()
	for block in block_ids:
		var occupants: Array = []
		for cell in game.reservations.occupied_owners:
			if game.block_signals.cell_blocks.get(cell, -1) == block:
				var owner := int(game.reservations.occupied_owners[cell])
				if not occupants.has(owner): occupants.append(owner)
		occupants.sort()
		var authorities: Array = game.block_signals.block_owners.get(block, {}).keys()
		authorities.sort()
		result.blocks.append({"id": block, "occupants": occupants, "authorities": authorities, "requested": game.block_signals.requested_blocks.get(id, []).has(block)})
	var stats: Dictionary = game.traffic_metrics.statistics(id)
	var held: bool
	var connected: bool
	var dwell: float
	var boarding: bool
	var at_home: bool
	if key == "passenger":
		held = game.passenger_held
		connected = game.route_connected
		dwell = game.wait_remaining
		boarding = game.train_needs_boarding
		at_home = game.route_distance <= 0.001 and game.passenger_stop_index == 0
	elif key == "freight":
		held = game.freight_train.held
		connected = game.freight_train.route_valid
		dwell = game.freight_train.dwell
		boarding = false
		at_home = game.freight_train.distance_along_route <= 0.001 and game.freight_train.to_terminal
	else:
		var running = game.passenger_services[key]
		held = running.held
		connected = running.connected
		dwell = running.dwell
		boarding = running.boarding
		at_home = running.distance <= 0.001 and running.stop_index == 0
	result.state = "Ready / moving"
	result.reason = "No measured traffic wait in the latest simulation sample."
	result.advice = "Resume to run; use the route overlay to inspect its planned path."
	if game.deadlocks.contains(id):
		for cycle in game.deadlocks.cycles:
			if cycle.has(id): result.cycle = cycle.duplicate()
		result.state = "Confirmed deadlock"
		result.reason = "A sustained cycle of trains waiting for each other has been detected."
		result.advice = "Open Traffic to review and reverse a selected train physically. Check that its return path can clear; reversal does not create escape track."
	elif held:
		result.state = "Dispatcher hold"
		result.reason = "The dispatcher deliberately held this train."
		result.advice = "Open Traffic to resume it when safe. This is not traffic congestion."
	elif not connected:
		result.state = "Route incomplete"
		result.reason = "Track, waypoint routing or consist stopping clearance is incomplete toward the next destination."
		result.advice = "Show the route and repair missing/incompatible track or straight stopping clearance. Keep signals outside the full stopping area."
		var issue := route_issue(game, actual, train)
		if not issue.is_empty():
			result.reason = issue.reason
			result.cell = issue.cell
	elif not game.service_enabled(key) and at_home:
		result.state = "Withdrawn"
		result.reason = "The service is withdrawn at its first stop."
		result.advice = "Open Fleet to enable, replace or store the train."
	elif dwell > 0.0:
		result.state = "Station dwell"
		result.reason = "Normal station dwell: %.1f simulation seconds remaining." % dwell
		result.advice = "Resume and let the dwell finish. It is not traffic waiting."
	elif key == "freight" and at_home and not game.freight_train.recovery_returning and game.freight_train.cargo < game.freight_train.get_minimum_load():
		result.state = "Loading"
		result.reason = "Loaded %d/%d logs needed for the departure rule; %d logs remain in forest storage." % [game.freight_train.cargo, game.freight_train.get_minimum_load(), game.forest_stock]
		result.advice = "Allow production/loading to continue, or change the departure rule in the forest/terminal inspector. Adding a passing loop will not supply cargo."
	elif str(game.reservation_waits.get(key, "")).begins_with("Holding for"):
		result.state = "Scheduled departure hold"
		result.reason = str(game.reservation_waits[key])
		result.advice = "Let the game clock reach the departure time, or edit the source route's timetable/headway in Routes. This intentional hold is not traffic congestion."
	elif boarding:
		result.state = "Boarding"
		result.reason = "The train is at a stop and will board before its next movement."
		result.advice = "Resume to board. Boarding is not measured traffic waiting."
	elif stats.continuous_seconds > 0.0:
		if int(game.movement_conflicts.get(id, {}).get("revision", -1)) == game.authority_revision:
			result.state = "Traffic wait"
			result.reason = stats.reason
		else:
			result.state = "Awaiting movement sample"
			result.reason = "Last measured wait: %s (%.1fs). Authority changed after that sample." % [stats.reason, stats.continuous_seconds]
			result.advice = "Resume to evaluate movement under the new allocation. The previous waiting cause may already be resolved."
	elif game.reservation_waits.has(key):
		result.state = "Approaching restriction"
		result.reason = "The train can still approach a restricted movement: " + str(game.reservation_waits[key])
	if result.state in ["Traffic wait", "Approaching restriction", "Confirmed deadlock"]:
		var conflict: Dictionary = game.movement_conflicts.get(id, {})
		result.blocker = int(conflict.get("owner", -1))
		result.cell = conflict.get("cell", Vector2i(-1, -1))
		result.wait_seconds = stats.continuous_seconds
		if result.state != "Confirmed deadlock":
			match str(conflict.get("kind", "track_reservation")):
				"oneway_signal": result.advice = "This movement opposes a one-way arrow. Correct its direction or edit a safe route; a two-stop Loop can use separate outbound and return paths. Waiting alone will not change the direction rule."
				"manual_signal": result.advice = "Locate the manual stop. Use Signals to change/remove it when safe; it will not release automatically."
				"block_busy", "block_authority": result.advice = "Inspect the signal block and its authority holders; automatic signals release when the block clears. Check boundaries and route choices before changing infrastructure."
				_: result.advice = "Locate the blocking train and inspect the shared track/switch. Let it clear, or review the routes and signal boundaries. A passing loop is useful only if the layout and route choices allow trains to pass."
		if not conflict.is_empty() and int(conflict.get("block", -1)) >= 0: result.reason += " (block B%02d)" % int(conflict.block)
	return result

static func cells_text(cells: Array) -> String:
	var ordered := cells.duplicate()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var values: PackedStringArray = []
	for index in range(mini(ordered.size(), 40)): values.append("%d,%d" % [ordered[index].x, ordered[index].y])
	if ordered.size() > 40: values.append("… +%d" % (ordered.size() - 40))
	return "; ".join(values) if not values.is_empty() else "none"

static func route_issue(game: Node, actual: Dictionary, train: Dictionary) -> Dictionary:
	if actual.path.point_count < 2 or actual.cells.is_empty():
		return {"reason": "No valid connected route to the next destination through the configured stops/waypoints.", "cell": Vector2i(-1, -1)}
	var spans: Array = game.reservations._route_spans(actual.path, actual.cells, float(game.TILE_SIZE))
	var first: int = game.reservations._index_at(spans, actual.distance)
	var last: int = game.reservations._index_at(spans, actual.target)
	var direction := 1 if last >= first else -1
	var index := first
	while true:
		var cell: Vector2i = actual.cells[index]
		if not game.tracks.has(cell): return {"reason": "Track missing at %d,%d toward the next destination." % [cell.x, cell.y], "cell": cell}
		if index == last: break
		var next: Vector2i = actual.cells[index + direction]
		if not game.TrackGeometry.connections(game.tracks[cell]).has(next - cell): return {"reason": "Incompatible track exit at %d,%d toward the next destination." % [cell.x, cell.y], "cell": cell}
		index += direction
	if game.Fleet.length(train) > 28.0:
		for cell in game.reservations.footprint(actual.path, actual.target, float(game.TILE_SIZE), game.Fleet.length(train)):
			if not game.tracks.has(cell) or not game.TrackGeometry.same_connections(game.tracks[cell], false) or game.track_signals.has(cell):
				return {"reason": "Consist stopping clearance is missing or incompatible at %d,%d." % [cell.x, cell.y], "cell": cell}
	return {}
