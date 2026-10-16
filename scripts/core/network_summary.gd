extends RefCounted
## Read-only prioritisation, never dispatch authority or a composite company score.
const WAIT_SECONDS := 5.0
static func build(data: Dictionary) -> Array:
	var rows: Array = []
	for problem in data.problems:
		var cause: String = str(problem.get("cause", "loan" if problem.key == "company:loan" else ""))
		if cause == "wait" and float(problem.get("wait_seconds", 0)) < WAIT_SECONDS: continue
		var row: Dictionary = problem.duplicate(true)
		row["rank"] = {"deadlock": 0, "incomplete": 1, "loan": 1, "wait": 2, "hold": 6}.get(cause, 2)
		row["weight"] = float(problem.get("wait_seconds", 0)) if cause == "wait" else 0.0
		row["action"] = "bank" if cause == "loan" else "inspect"
		row["action_text"] = "Review bank payments" if cause == "loan" else "Inspect train and waiting cause"
		rows.append(row)
	for station in data.stations:
		if station.waiting > 0 and not station.reachable:
			rows.append({"key": "unserved:" + station.id, "id": -1, "rank": 3, "weight": float(station.waiting), "severity": "Advice", "title": "%s — %d waiting, no enabled connection" % [station.name, station.waiting], "details": "The current enabled, unheld, physically complete passenger-service graph has no outward connection here. Check Routes and Fleet, repair the route or release an intentional hold. Existing accepted passengers stay queued; this is not proof that their journeys have failed.", "cell": station.cell, "action": "station", "object_key": "station:" + station.id, "action_text": "Review station"})
		elif station.waiting * 5 >= station.capacity * 4 and station.capacity > 0:
			rows.append({"key": "queue:" + station.id, "id": -1, "rank": 4, "weight": float(station.waiting) / station.capacity, "severity": "Advice", "title": "%s — queue %d / %d" % [station.name, station.waiting, station.capacity], "details": "At least 80% of this station's waiting capacity is occupied now. Review its queue and serving routes. More frequent service or more seats may help; a larger waiting area only provides room and does not deliver passengers.", "cell": station.cell, "action": "station", "object_key": "station:" + station.id, "action_text": "Review station"})
	for city in data.cities:
		if city.served: continue
		rows.append({"key": "opportunity:" + city.id, "id": -1, "rank": 7, "weight": float(city.population), "severity": "Opportunity", "title": "%s — no station (%d residents)" % [city.name, city.population], "details": "This city has no station. Review its population and nearby city connections before spending. This is an expansion opportunity, not an operating incident or a guaranteed profitable route.", "cell": city.cell, "action": "find", "object_key": city.id, "action_text": "Review city"})
	for vehicle in data.vehicles:
		if vehicle.left <= 0: continue
		rows.append({"key": "capacity:%d" % vehicle.id, "id": vehicle.id, "rank": 5, "weight": float(vehicle.left), "severity": "Measured", "title": "#%d %s — %d left-behind opportunities" % [vehicle.id, vehicle.name, vehicle.left], "details": "Eligible passengers were left for lack of seats at recent boarding opportunities. This filters the latest 128 company-wide opportunities to the current vehicle, including earlier assignments. A person may be counted repeatedly. It is recent evidence, not proof that the train is full now; it resets on load. Review capacity and service frequency before buying upgrades.", "cell": Vector2i(-1, -1), "service": vehicle.service, "action": "service", "action_text": "Review service capacity"})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.rank != b.rank: return a.rank < b.rank
		if a.weight != b.weight: return a.weight > b.weight
		return str(a.key) < str(b.key))
	return rows
