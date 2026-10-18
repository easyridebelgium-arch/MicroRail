extends RefCounted
## Immutable terrain profiles. Bridge rails always belong to the movement graph.
const Geometry = preload("res://scripts/track_geometry.gd")
const PROFILES := ["flat", "river_v1", "wide_river_v1", "meander_v1"]
const PROFILE_NAMES := ["Flat land", "River with bridge crossings", "Wide river", "Meandering river"]
const EXTRA_COST := 40
const EXTRA_REFUND := 20
var profile := "flat"
func water_rows(x: int) -> Array[int]:
	if x < 0 or x >= 80 or profile == "flat": return []
	if profile == "wide_river_v1": return [16, 17, 18]
	if profile == "meander_v1":
		var first: int = [16, 17, 18, 17][int(x / 20.0)]
		return [first, first + 1]
	return [17, 18]
func span(x: int) -> Array[Vector2i]:
	var rows := water_rows(x)
	var result: Array[Vector2i] = []
	if rows.is_empty(): return result
	for y in range(rows[0] - 1, rows.back() + 2): result.append(Vector2i(x, y))
	return result
func water(cell: Vector2i) -> bool: return cell.y in water_rows(cell.x)
## Read-only span facts. Prices are rail values, not permission to edit.
func inspect_span(cell: Vector2i, tracks: Dictionary, owners: Dictionary = {}) -> Dictionary:
	var cells := span(cell.x)
	if cell not in cells: return {}
	var missing: Array[Vector2i] = []
	var incompatible: Array[Vector2i] = []
	var holders: Array[int] = []
	var water_count := water_rows(cell.x).size()
	var missing_cost := 0
	var deck_refund := 0
	for point in cells:
		if not tracks.has(point):
			missing.append(point)
			missing_cost += 10 + (EXTRA_COST if water(point) else 0)
		elif not Geometry.same_connections(tracks[point], true): incompatible.append(point)
		if tracks.has(point) and water(point): deck_refund += 5 + EXTRA_REFUND
		if owners.has(point) and not holders.has(int(owners[point])): holders.append(int(owners[point]))
	holders.sort()
	return {"cells": cells, "water_count": water_count, "missing": missing, "incompatible": incompatible, "holders": holders, "complete": missing.is_empty() and incompatible.is_empty(), "rail_cost": cells.size() * 10, "surcharge": water_count * EXTRA_COST, "full_cost": cells.size() * 10 + water_count * EXTRA_COST, "missing_cost": missing_cost, "deck_refund": deck_refund}
func save_state() -> Dictionary: return {"profile": profile}
func restore_state(value: Dictionary) -> void: profile = value.profile
static func valid(value: Variant, cities: bool) -> bool:
	return value is Dictionary and value.size() == 1 and value.get("profile") in PROFILES and (cities or value.profile == "flat")
func track_error(tracks: Dictionary, signals: Dictionary = {}) -> String:
	if profile == "flat": return ""
	for cell in tracks:
		if not water(cell): continue
		var crossing := span(cell.x)
		for point in crossing:
			if not tracks.has(point) or not Geometry.same_connections(tracks[point], true): return "Bridge needs straight north–south rail from bank %d,%d to bank %d,%d. Extend onto dry land on both sides; no curves or switches on the span." % [crossing[0].x, crossing[0].y, crossing.back().x, crossing.back().y]
	for cell in signals:
		if water(cell): return "Place signals on the dry bank, not over water."
	return ""
func proposed_error(live: Dictionary, changes: Dictionary, signals: Dictionary = {}) -> String:
	var proposed := live.duplicate()
	for cell in changes:
		if changes[cell] == null: proposed.erase(cell)
		else: proposed[cell] = changes[cell]
	return track_error(proposed, signals)
func site_error(cells: Array, tracks: Dictionary = {}) -> String:
	for cell in cells:
		if water(cell): return "Stations and their platforms need dry land; move away from the river."
		var crossing := span(cell.x)
		if crossing.is_empty() or cell not in [crossing[0], crossing.back()]: continue
		for y in water_rows(cell.x):
			if tracks.has(Vector2i(cell.x, y)): return "Stations cannot replace a bridge bank; move clear of the crossing."
	return ""
## Advisory only: no track changes or authority requests. Existing curves,
## protected land and current reservations are excluded; prices omit approaches.
func suggest(near: Vector2i, live: Dictionary, signals: Dictionary, owners: Dictionary, protected: Callable, land_price: int = 10) -> Dictionary:
	if profile == "flat": return {}
	var columns: Array = range(80)
	columns.sort_custom(func(a: int, b: int) -> bool: return absi(a - near.x) < absi(b - near.x) if absi(a - near.x) != absi(b - near.x) else a < b)
	for x in columns:
		var crossing := span(int(x))
		var changes: Dictionary = {}
		var cost := 0
		var blocked := false
		for cell in crossing:
			if protected.call(cell) or owners.has(cell) or (live.has(cell) and not Geometry.same_connections(live[cell], true)) or (water(cell) and signals.has(cell)):
				blocked = true
				break
			if not live.has(cell):
				changes[cell] = true
				cost += land_price + (EXTRA_COST if water(cell) else 0)
		if blocked: continue
		return {"cells": crossing, "changes": changes, "cost": cost, "text": "Suggested crossing %d,%d → %d,%d N–S. Span £%d + approach rails. Extend past both banks; recheck reservations/funds." % [x, crossing[0].y, x, crossing.back().y, cost]}
	return {}
