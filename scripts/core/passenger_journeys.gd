extends RefCounted
## Deterministic service connectivity, independent of movement authority.
## One graph edge is a ride without changing trains; fewer changes win.
const Demand = preload("res://scripts/core/passenger_demand.gd")
static func graph(configurations: Dictionary, ids: Array = Demand.STATIONS) -> Dictionary:
	var result: Dictionary = {}
	for station in ids: result[station] = []
	var keys := configurations.keys()
	keys.sort()
	for key in keys:
		var stops: Array = configurations[key].stops
		# Shuttles serve both directions; Loops reach every listed stop after wrapping.
		if not stops.all(func(stop: String) -> bool: return result.has(stop)): continue
		for origin in stops:
			for destination in stops:
				if origin != destination and not result[origin].has(destination): result[origin].append(destination)
	for station in result: result[station].sort()
	return result
static func plan(network: Dictionary, origin: String, destination: String) -> Array:
	if not network.has(origin) or not network.has(destination): return []
	if origin == destination: return [origin]
	var pending: Array = [[origin]]
	var seen := {origin: true}
	while not pending.is_empty():
		var path: Array = pending.pop_front()
		for next in network.get(path.back(), []):
			if seen.has(next): continue
			var extended := path.duplicate()
			extended.append(next)
			if next == destination: return extended
			seen[next] = true
			pending.append(extended)
	return []
static func boarding(network: Dictionary, origin: String, future: Array) -> Array:
	var result := future.duplicate()
	var destinations := network.keys()
	destinations.sort()
	for destination in destinations:
		if destination == origin or result.has(destination): continue
		var journey := plan(network, origin, destination)
		# Never take an extra change when a direct service exists, even if it waits.
		if journey.size() <= 2: continue
		for interchange in future:
			var onward := plan(network, interchange, destination)
			if not onward.is_empty() and onward.size() == journey.size() - 1:
				result.append(destination)
				break
	return result
