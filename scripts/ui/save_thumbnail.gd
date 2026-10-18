extends Control
## A diagram drawn from metadata, never a live simulation or asset screenshot.
var snapshot: Dictionary = {"available": false, "cells": []}
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(160, 80)
func set_snapshot(value: Dictionary) -> void:
	snapshot = value
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#182D2A"))
	if not snapshot.available: return
	var extent := Vector2(42, 28)
	for cell in snapshot.cells: extent = extent.max(Vector2(cell) + Vector2(3, 3))
	var factor := minf((size.x - 12) / extent.x, (size.y - 12) / extent.y)
	for cell in snapshot.cells:
		draw_rect(Rect2(Vector2(cell) * factor + Vector2(6, 6), Vector2.ONE * maxf(1, factor * 0.75)), Color("#B4C9D4"))
	for cell in [Vector2(4, 8), Vector2(20, 8), Vector2(36, 8)]:
		draw_rect(Rect2(cell * factor + Vector2(5, 5), Vector2(4, 4)), Color("#F0E442"))
