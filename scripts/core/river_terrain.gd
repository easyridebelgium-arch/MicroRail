extends RefCounted
## Immutable v1 river profile. Ordinary graph rails become complete bridge spans.
const Geometry = preload("res://scripts/track_geometry.gd")
const PROFILES := ["flat", "river_v1"]
const EXTRA_COST := 40
const EXTRA_REFUND := 20
var profile := "flat"
func water(cell: Vector2i) -> bool: return profile == "river_v1" and cell.x >= 0 and cell.x < 80 and cell.y in [17, 18]
func save_state() -> Dictionary: return {"profile": profile}
func restore_state(value: Dictionary) -> void: profile = value.profile
static func valid(value: Variant, cities: bool) -> bool:
	return value is Dictionary and value.size() == 1 and value.get("profile") in PROFILES and (cities or value.profile == "flat")
func track_error(tracks: Dictionary, signals: Dictionary = {}) -> String:
	if profile == "flat": return ""
	for cell in tracks:
		if not water(cell): continue
		for y in range(16, 20):
			var point := Vector2i(cell.x, y)
			if not tracks.has(point) or not Geometry.same_connections(tracks[point], true): return "Bridge needs one straight north–south span across both water tiles and both dry bank tiles (rows 16–19). Extend the drag farther onto dry land on both sides. No curves or switches on the span."
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
		if profile == "river_v1" and cell.y in [16, 19] and (tracks.has(Vector2i(cell.x, 17)) or tracks.has(Vector2i(cell.x, 18))): return "Stations cannot replace a bridge bank; move clear of the crossing."
	return ""
