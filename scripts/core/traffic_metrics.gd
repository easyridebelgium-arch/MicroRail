extends RefCounted
## Counts only actual zero-movement waits at fixed simulation ticks.
## Bounded, aligned-second rolling window; derived diagnostics reset on load.
const WINDOW_SECONDS := 60
const TICKS_PER_SECOND := 60
var records: Dictionary = {}
var window_trains: Dictionary = {}
var window_cells: Dictionary = {}
var _buckets: Dictionary = {}
var _last_tick := -1

func reset() -> void:
	records.clear()
	window_trains.clear()
	window_cells.clear()
	_buckets.clear()
	_last_tick = -1

func update(tick: int, active_ids: Array, waits: Dictionary) -> void:
	if tick <= _last_tick: return
	_last_tick = tick
	var second := tick / TICKS_PER_SECOND
	for old in _buckets.keys():
		if old <= second - WINDOW_SECONDS:
			var bucket: Dictionary = _buckets[old]
			_subtract(window_trains, bucket.trains)
			_subtract(window_cells, bucket.cells)
			_buckets.erase(old)
	for id in records.keys():
		if not active_ids.has(id): records.erase(id)
	for id in active_ids:
		if not records.has(id): records[id] = {"total_ticks": 0, "streak_ticks": 0, "reason": "", "cell": Vector2i(-1, -1)}
		var record: Dictionary = records[id]
		if not waits.has(id):
			record.streak_ticks = 0
			continue
		var wait: Dictionary = waits[id]
		record.total_ticks += 1
		record.streak_ticks += 1
		record.reason = str(wait.reason)
		record.cell = wait.cell
		if not _buckets.has(second): _buckets[second] = {"trains": {}, "cells": {}}
		var bucket: Dictionary = _buckets[second]
		_add(bucket.trains, id)
		_add(window_trains, id)
		if wait.cell != Vector2i(-1, -1):
			_add(bucket.cells, wait.cell)
			_add(window_cells, wait.cell)

func statistics(id: int) -> Dictionary:
	var record: Dictionary = records.get(id, {})
	return {"total_seconds": float(record.get("total_ticks", 0)) / TICKS_PER_SECOND, "continuous_seconds": float(record.get("streak_ticks", 0)) / TICKS_PER_SECOND, "recent_seconds": float(window_trains.get(id, 0)) / TICKS_PER_SECOND, "reason": str(record.get("reason", ""))}

static func _add(table: Dictionary, key: Variant) -> void:
	table[key] = int(table.get(key, 0)) + 1

static func _subtract(table: Dictionary, values: Dictionary) -> void:
	for key in values:
		table[key] = int(table.get(key, 0)) - int(values[key])
		if table[key] <= 0: table.erase(key)
