extends RefCounted
## Pure fixed-tick round robin. No hidden queue or save state.
## Only future requests are ordered; physical occupancy always wins first.
const TURN_TICKS := 600 # Ten simulation seconds, independent of render FPS/speed.
const TICKS_PER_SECOND := 60
static func ranks(trains: Array, tick: int) -> Dictionary:
	var ids: Array[int] = []
	for train in trains:
		if not ids.has(int(train.id)): ids.append(int(train.id))
	ids.sort()
	var result: Dictionary = {}
	if ids.is_empty(): return result
	var turn := int(floor(float(maxi(0, tick)) / TURN_TICKS)) % ids.size()
	for index in range(ids.size()): result[ids[(turn + index) % ids.size()]] = index
	return result
static func before(a: Dictionary, b: Dictionary, order: Dictionary) -> bool:
	var left := int(order.get(int(a.id), int(a.id)))
	var right := int(order.get(int(b.id), int(b.id)))
	return left < right if left != right else int(a.id) < int(b.id)
static func describe(id: int, order: Dictionary, tick: int, wait_seconds: float) -> String:
	if not order.has(id): return "No active dispatch request order recorded."
	var remaining := float(TURN_TICKS - maxi(0, tick) % TURN_TICKS) / TICKS_PER_SECOND
	var text := "Dispatch request position %d/%d at allocation. First choice rotates every 10 simulation seconds (next in %.1fs). Occupied tiles/blocks and manual stops always take precedence; parked trains do not request ahead." % [int(order[id]) + 1, order.size(), remaining]
	if wait_seconds >= maxf(20.0, order.size() * 10.0):
		text += "\nProlonged traffic wait: at least one full dispatch cycle. This alone does not prove starvation. Inspect the blocking train, occupied block, manual signal or deadlock; rotating requests cannot free occupied space or repair an incomplete route."
	return text
