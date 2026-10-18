extends SceneTree
const Dispatch = preload("res://scripts/core/dispatch_order.gd")
const Reservations = preload("res://scripts/core/track_reservations.gd")
const Signals = preload("res://scripts/core/block_signals.gd")
const Router = preload("res://scripts/rail_router.gd")
const Clock = preload("res://scripts/core/sim_clock.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func train(id: int, cells: Array[Vector2i], distance: float, forward: bool = true) -> Dictionary:
	return {"id": id, "cells": cells, "path": Router.make_path(cells, 32), "distance": distance, "forward": forward, "moving": true}
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var ids := [{"id": 9}, {"id": 2}, {"id": 5}]
	check(Dispatch.ranks(ids, 0) == {2: 0, 5: 1, 9: 2}, "initial order retains lower-ID tie break")
	check(Dispatch.ranks(ids, 600) == {5: 0, 9: 1, 2: 2} and Dispatch.ranks(ids, 1200)[9] == 0, "each active ID gets first choice in a cycle")
	check(Dispatch.ranks(ids, 1800) == Dispatch.ranks(ids, 0), "order cycles without hidden history")
	check(Dispatch.ranks([], 100).is_empty(), "empty fleet is safe")
	var saved_clock := Clock.new()
	saved_clock.tick = 1250
	var restored_clock := Clock.new()
	restored_clock.restore_state(JSON.parse_string(JSON.stringify(saved_clock.save_state())))
	check(Dispatch.ranks(ids, restored_clock.tick) == Dispatch.ranks(ids, saved_clock.tick), "saved clock reconstructs dispatch order without a saved queue")
	check(Dispatch.ranks([{ "id": 9 }, { "id": 2 }], 600) == {9: 0, 2: 1}, "changed active fleet is reordered deterministically")
	check(not Dispatch.describe(2, Dispatch.ranks(ids, 0), 0, 29).contains("Prolonged") and Dispatch.describe(2, Dispatch.ranks(ids, 0), 0, 30).contains("does not prove starvation"), "prolonged wait threshold is a full cycle and is not a false diagnosis")
	var horizontal: Array[Vector2i] = []
	var vertical: Array[Vector2i] = []
	for i in range(11):
		horizontal.append(Vector2i(i, 5))
		vertical.append(Vector2i(5, i))
	var a := train(1, horizontal, 64)
	var b := train(2, vertical, 64)
	var table := Reservations.new()
	for tick in [0, 600, 1200]:
		var rank := Dispatch.ranks([b, a], tick)
		table.rebuild([b, a], {}, 32, {}, rank)
		var expected := 2 if tick == 600 else 1
		check(table.owners[Vector2i(5, 5)] == expected, "unoccupied tile grant rotates to each claimant")
		var snapshot := table.owners.duplicate()
		table.rebuild([a, b], {}, 32, {}, rank)
		check(table.owners == snapshot, "input order cannot change grants")
	a.distance = 160.0
	a.moving = false
	table.rebuild([b, a], {}, 32, {}, Dispatch.ranks([a, b], 600))
	check(table.occupied_owners[Vector2i(5, 5)] == 1 and table.owners[Vector2i(5, 5)] == 1, "rotating preference never steals a parked body")
	var branch: Array[Vector2i] = [Vector2i(10, 1), Vector2i(9, 1), Vector2i(8, 1), Vector2i(7, 1), Vector2i(6, 1), Vector2i(5, 0), Vector2i(4, 0), Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 0), Vector2i(0, 0)]
	var main: Array[Vector2i] = []
	for x in range(11): main.append(Vector2i(x, 0))
	a = train(1, main, 64)
	b = train(2, branch, 64)
	table.rebuild([a, b], {Vector2i(5, 0): "junction_6_2_3"}, 32, {}, Dispatch.ranks([a, b], 600))
	check(table.switch_owners.get(Vector2i(5, 0)) == 2 and table.switches.get(Vector2i(5, 0)) == 1, "switch locks follow the same rotating tile order")
	var tracks: Dictionary = {}
	var cells: Array[Vector2i] = []
	for x in range(13):
		tracks[Vector2i(x, 0)] = false
		cells.append(Vector2i(x, 0))
	a = train(1, cells, 32)
	b = train(2, cells, 352, false)
	var signals := Signals.new()
	signals.configure(tracks, {Vector2i(3, 0): "auto", Vector2i(9, 0): "auto"})
	signals.update([a, b], {Vector2i(1, 0): 1, Vector2i(11, 0): 2}, 32, Dispatch.ranks([a, b], 600))
	check(signals.limit(b, 224, 32).distance == 224 and signals.limit(a, 128, 32).conflict.owner == 2, "signal block requests use the same rotating preference")
	signals.update([a, b], {Vector2i(5, 0): 1}, 32, Dispatch.ranks([a, b], 600))
	check(signals.limit(b, 224, 32).conflict.owner == 1, "occupied blocks cannot be stolen by first-choice train")
	var baseline := simulate(60, 1.0)
	for fps in [30, 60, 120]:
		for speed in [1.0, 10.0]: check(simulate(fps, speed) == baseline, "moving-train grants and safety match across FPS and speed")
	print("Dispatch order: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func simulate(fps: int, speed: float) -> Array:
	var clock := Clock.new()
	clock.tick = 590
	clock.speed = speed
	var h: Array[Vector2i] = []
	var v: Array[Vector2i] = []
	for i in range(11):
		h.append(Vector2i(i, 5))
		v.append(Vector2i(5, i))
	var a := train(1, h, 64)
	var b := train(2, v, 64)
	var table := Reservations.new()
	var overlap := false
	var history: Array = []
	for frame in range(ceili(8.0 * fps / speed)):
		for step in clock.advance(1.0 / fps):
			clock.begin_tick()
			table.rebuild([b, a], {}, 32, {}, Dispatch.ranks([a, b], clock.tick))
			for t in [a, b]: t.distance = table.limit(t.id, t.path, t.distance, minf(t.distance + 80.0 / 60.0, t.path.get_baked_length()), 32)
			var occupied: Dictionary = {}
			for t in [a, b]:
				for cell in table.footprint(t.path, t.distance, 32):
					overlap = overlap or occupied.has(cell)
					occupied[cell] = t.id
			history.append([a.distance, b.distance, table.owners.get(Vector2i(5, 5), -1)])
	check(not overlap, "moving trains never overlap across a rotation boundary")
	check(absf(a.distance - a.path.get_baked_length()) < 0.001 and absf(b.distance - b.path.get_baked_length()) < 0.001, "both crossing trains clear after contention: %s / %s" % [a.distance, b.distance])
	return history
