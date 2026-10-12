extends SceneTree
const Reservations = preload("res://scripts/core/track_reservations.gd")
const Signals = preload("res://scripts/core/block_signals.gd")
const Router = preload("res://scripts/rail_router.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func line(count: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(count): cells.append(Vector2i(x, 0))
	return cells
func train(id: int, cells: Array[Vector2i], distance: float, length: float = 28.0, moving: bool = true, forward: bool = true) -> Dictionary:
	return {"id": id, "length": length, "cells": cells, "path": Router.make_path(cells, 32), "distance": distance, "forward": forward, "moving": moving}
func occupied(table, trains: Array) -> Dictionary:
	var result := {}
	for t in trains:
		for cell in table.footprint(t.path, t.distance, 32, Reservations.train_length(t)): result[cell] = t.id
	return result
func _initialize() -> void:
	var table := Reservations.new()
	var main := line(13)
	var path := Router.make_path(main, 32)
	check(table.footprint(path, 160, 32) == table.footprint(path, 160, 32, 28.0), "default length matches the single vehicle footprint")
	var long_body := table.footprint(path, 160, 32, 96)
	check(long_body.has(Vector2i(3, 0)) and long_body.has(Vector2i(6, 0)), "96 px train covers tiles ahead of and behind its centre")
	check(not table.footprint(path, 160, 32).has(Vector2i(3, 0)), "single vehicle does not cover the extra tiles")
	check(table.footprint(path, 0, 32, 96).has(Vector2i(-1, 0)), "a train longer than its platform extends past the path start")
	check(table.footprint(path, 0, 32, 28).has(Vector2i(-1, 0)) == false, "a single vehicle fits the start tile")
	# The tail keeps the switch locked after the centre has passed it.
	var tracks := {Vector2i(5, 0): "junction_6_2_3"}
	var branch: Array[Vector2i] = [Vector2i(10, 1), Vector2i(9, 1), Vector2i(8, 1), Vector2i(7, 1), Vector2i(6, 1), Vector2i(5, 0), Vector2i(4, 0), Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 0), Vector2i(0, 0)]
	var short_a := train(1, line(11), 256.0)
	var long_a := train(1, line(11), 256.0, 160.0)
	var waiting := train(2, branch, 64.0)
	table.rebuild([waiting, short_a], tracks, 32)
	check(table.owners.get(Vector2i(5, 0)) == 2, "short train has released the switch behind it")
	table.rebuild([waiting, long_a], tracks, 32)
	check(table.owners.get(Vector2i(5, 0)) == 1, "long train keeps the switch until its tail clears")
	check(table.switches.get(Vector2i(5, 0)) == 0, "switch stays locked through")
	long_a = train(1, line(11), 300.0, 96.0)
	table.rebuild([waiting, long_a], tracks, 32)
	check(table.owners.get(Vector2i(5, 0)) == 2, "switch is granted once the tail has cleared")
	# Movement stops earlier because the nose, not the centre, meets the obstacle.
	var parked := train(1, main, 256.0, 28.0, false)
	var runner := train(2, main, 150.0, 96.0)
	table.rebuild([parked, runner], {}, 32)
	var long_limit := table.limit(2, runner.path, 150.0, 300.0, 32, 96.0)
	runner.length = 28.0
	table.rebuild([parked, runner], {}, 32)
	var short_limit := table.limit(2, runner.path, 150.0, 300.0, 32, 28.0)
	check(long_limit <= 192.0 and long_limit > 150.0, "long train stops with its nose clear of the parked train")
	check(short_limit > long_limit + 25.0, "single vehicle can approach closer")
	# A parked long train blocks tiles that a short one would leave free.
	var long_parked := train(1, main, 200.0, 128.0, false)
	var intruder := train(2, main, 20.0, 28.0)
	table.rebuild([long_parked, intruder], {}, 32)
	check(table.limit(2, intruder.path, 20.0, 400.0, 32) < 120.0, "parked consist protects its whole body")
	check(table.waits.has(2), "blocked train reports the owner")
	# Block authority follows the tail.
	var line_tracks := {}
	for x in range(13): line_tracks[Vector2i(x, 0)] = false
	var manager := Signals.new()
	manager.configure(line_tracks, {Vector2i(3, 0): "auto"})
	var left_block: int = manager.cell_blocks[Vector2i(1, 0)]
	var long_b := train(2, main, 110.0, 96.0)
	manager.update([long_b], occupied(table, [long_b]), 32)
	check(manager.block_owners.get(left_block, {}).has(2), "tail inside the left block keeps it held")
	var short_b := train(2, main, 110.0)
	manager.update([short_b], occupied(table, [short_b]), 32)
	check(not manager.block_owners.get(left_block, {}).has(2), "single vehicle has already cleared the left block")
	long_b.distance = 300.0
	manager.update([long_b], occupied(table, [long_b]), 32)
	check(not manager.block_owners.get(left_block, {}).has(2), "block releases after the tail leaves")
	# The nose requests authority for the block beyond a signal.
	var holder := train(1, main, 350.0, 28.0, false)
	var approaching := train(2, main, 0.0, 128.0)
	manager.update([holder, approaching], occupied(table, [holder, approaching]), 32)
	var result := manager.limit(approaching, 200.0, 32)
	check(result.distance < 200.0, "long train waits at a signal into a held block")
	print("Train length tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
