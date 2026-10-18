extends RefCounted
## Bounded metadata only. The normal loader remains the authority for save validity.
const Slots = preload("res://scripts/core/save_slots.gd")
const Timetable = preload("res://scripts/core/timetable.gd")
const Migrations = preload("res://scripts/core/save_migrations.gd")
const MAX_BYTES := 8 * 1024 * 1024
static func read(path: String) -> Dictionary:
	var result := {"available": false, "text": "Empty slot", "cells": [], "cash": 0, "tick": 0}
	if not FileAccess.file_exists(path): return result
	result.text = "Preview unavailable; Load will validate the saved game."
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES: return result
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not parser.data is Dictionary: return result
	var data: Dictionary = parser.data
	if not number(data.get("version"), 1, Migrations.CURRENT_VERSION): return result
	if not data.get("state") is Dictionary or not data.get("sim") is Dictionary or not data.sim.get("clock") is Dictionary: return result
	if not number(data.state.get("money"), -1000000000, 1000000000) or not number(data.sim.clock.get("tick"), 0, 1000000000000): return result
	if not data.get("tracks") is Array or data.tracks.size() > 10000: return result
	for entry in data.tracks:
		if not entry is Array or entry.size() != 3 or not number(entry[0], 0, 1000) or not number(entry[1], 0, 1000): return result
		result.cells.append(Vector2i(int(entry[0]), int(entry[1])))
	result.available = true
	result.cash = int(data.state.money)
	result.tick = int(data.sim.clock.tick)
	var minute := Timetable.absolute_minute(result.tick)
	result.text = "%s | Balance £%d\n%d track tiles. Preview only; loading validates all simulation data." % [Timetable.clock_text(minute), result.cash, result.cells.size()]
	return result
static func number(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high
static func latest_slot() -> int:
	var latest := -1
	var selected := 0
	for slot in range(1, Slots.COUNT + 1):
		if not read(Slots.path(slot)).available: continue
		var timestamp := FileAccess.get_modified_time(Slots.path(slot))
		if timestamp > latest: latest = timestamp; selected = slot
	return selected
