extends RefCounted
## An ephemeral edit transaction. Original values detect stale drafts.
const Geometry = preload("res://scripts/track_geometry.gd")
var prices: Dictionary

func _init(costs: Dictionary = {"track": 10, "refund": 5, "switch": 100}) -> void:
	prices = costs.duplicate()

var before: Dictionary = {}
var changes: Dictionary = {}

func clear() -> void:
	before.clear()
	changes.clear()

func stage(updates: Dictionary, live: Dictionary) -> void:
	for cell in updates:
		if not before.has(cell): before[cell] = live.get(cell)
		if _same(updates[cell], before[cell]):
			changes.erase(cell)
			before.erase(cell)
		else: changes[cell] = updates[cell]

func projected(live: Dictionary) -> Dictionary:
	var result := live.duplicate()
	for cell in changes:
		if changes[cell] == null: result.erase(cell)
		else: result[cell] = changes[cell]
	return result

func quote() -> Dictionary:
	var cost := 0
	var refund := 0
	for cell in changes:
		var old: Variant = before[cell]
		var next: Variant = changes[cell]
		if old == null and next != null: cost += int(prices.track)
		if old != null and next == null: refund += int(prices.refund)
		if next != null and Geometry.is_switch(next) and not Geometry.is_switch(old): cost += int(prices.switch)
		if old != null and next != null and Geometry.is_switch(old) and not Geometry.is_switch(next): refund += int(prices.switch)
	return {"cost": cost, "refund": refund, "net": cost - refund}

func validate(live: Dictionary, owners: Dictionary, signals: Dictionary, size: Vector2i, protected: Callable, money: int) -> String:
	if changes.is_empty(): return "The plan is empty."
	for cell in changes:
		if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y: return "Plan goes outside the map."
		if not _same(live.get(cell), before[cell]): return "Track changed at %d,%d since drafting. Discard and redraw the plan." % [cell.x, cell.y]
		if protected.call(cell): return "Platforms and facility grounds cannot be changed."
		if owners.has(cell): return "Track %d,%d is reserved by train #%d; let it clear before applying." % [cell.x, cell.y, int(owners[cell])]
		if changes[cell] != null and Geometry.connections(changes[cell]).size() < 2: return "Invalid track geometry."
		if signals.has(cell) and changes[cell] != null and not Geometry.is_straight(changes[cell]): return "Remove the signal before changing its track geometry."
	var proposed := projected(live)
	for cell in proposed:
		for port in Geometry.connections(proposed[cell]):
			if port.x == 0 or port.y == 0: continue
			var a: Vector2i = cell + Vector2i(port.x, 0)
			var b: Vector2i = cell + Vector2i(0, port.y)
			if (proposed.has(a) and Geometry.connections(proposed[a]).has(Vector2i(-port.x, port.y))) or (proposed.has(b) and Geometry.connections(proposed[b]).has(Vector2i(port.x, -port.y))): return "Diagonal tracks cannot cross at a tile corner."
	if quote().net > money: return "Insufficient funds: plan needs £%d, available £%d." % [quote().net, money]
	return ""

static func _same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b
