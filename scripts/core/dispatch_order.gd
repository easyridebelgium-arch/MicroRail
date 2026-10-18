extends RefCounted
## Pure fixed-tick weighted round robin. No hidden queue or save state.
## Only future requests are ordered; physical occupancy always wins first.
const TURN_TICKS := 600 # Ten simulation seconds, independent of render FPS/speed.
const TICKS_PER_SECOND := 60
const PRIORITY_NAMES := ["Low", "Normal", "High"]
static func slots(trains: Array) -> Array[int]:
	var priorities: Dictionary = {}
	for train in trains: priorities[int(train.id)] = clampi(int(train.get("priority", 1)), 0, 2)
	var ids: Array = priorities.keys()
	ids.sort()
	var result: Array[int] = []
	var uniform := true
	for id in ids:
		if priorities[id] != priorities[ids[0]]: uniform = false
	for round_index in range(1 if uniform else 3):
		for id in ids:
			if round_index <= int(priorities[id]): result.append(int(id))
	return result
static func cycle_ticks(trains: Array) -> int:
	return slots(trains).size() * TURN_TICKS
static func ranks(trains: Array, tick: int) -> Dictionary:
	var schedule := slots(trains)
	var result: Dictionary = {}
	if schedule.is_empty(): return result
	var turn := int(floor(float(maxi(0, tick)) / TURN_TICKS)) % schedule.size()
	var ids: Array = []
	for id in schedule:
		if not ids.has(id): ids.append(id)
	ids.sort()
	var first: int = ids.find(schedule[turn])
	for index in range(ids.size()): result[ids[(first + index) % ids.size()]] = index
	return result
static func before(a: Dictionary, b: Dictionary, order: Dictionary) -> bool:
	var left := int(order.get(int(a.id), int(a.id)))
	var right := int(order.get(int(b.id), int(b.id)))
	return left < right if left != right else int(a.id) < int(b.id)
static func describe(id: int, order: Dictionary, tick: int, wait_seconds: float, trains: Array = []) -> String:
	if not order.has(id): return "No active dispatch request order recorded."
	var remaining := float(TURN_TICKS - maxi(0, tick) % TURN_TICKS) / TICKS_PER_SECOND
	var text := "Dispatch request position %d/%d at allocation. First choice uses weighted turns every 10 simulation seconds (next in %.1fs). Occupied tiles/blocks and manual stops always take precedence; parked trains do not request ahead." % [int(order[id]) + 1, order.size(), remaining]
	var cycle := float(cycle_ticks(trains)) / TICKS_PER_SECOND if not trains.is_empty() else order.size() * 10.0
	if wait_seconds >= maxf(20.0, cycle):
		text += "\nProlonged traffic wait: at least one full dispatch cycle. This alone does not prove starvation. Inspect the blocking train, occupied block, manual signal or deadlock; rotating requests cannot free occupied space or repair an incomplete route."
	if not trains.is_empty():
		for train in trains:
			if int(train.id) == id: text += "\nService dispatch priority at allocation: %s. Dispatch cycle %.0fs; Low/Normal/High get 1/2/3 first-choice turns." % [PRIORITY_NAMES[int(train.get("priority", 1))], cycle]
	return text
