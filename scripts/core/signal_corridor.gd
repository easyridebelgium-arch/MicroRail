extends RefCounted
const Router = preload("res://scripts/rail_router.gd")
const Geometry = preload("res://scripts/track_geometry.gd")

static func plan(tracks: Dictionary, start: Vector2i, end: Vector2i, spacing: int, mode: String, protected: Callable) -> Dictionary:
	var cells := Router.find_route(tracks, start, end)
	var result := {"cells": cells, "updates": {}, "error": ""}
	if cells.size() < 2:
		result.error = "Choose two different points joined by a track route."
		return result
	if mode not in ["auto", "stop", ""]:
		result.error = "Invalid signal mode."
		return result
	spacing = clampi(spacing, 3, 30)
	for index in range(cells.size()):
		var cell: Vector2i = cells[index]
		if protected.call(cell) or not Geometry.is_straight(tracks[cell]): continue
		if mode.is_empty() or index % spacing == 0 or index == cells.size() - 1:
			if mode.is_empty(): result.updates[cell] = null
			else: result.updates[cell] = mode
	if result.updates.is_empty(): result.error = "No eligible straight track at the selected spacing."
	return result
