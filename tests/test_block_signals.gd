extends SceneTree
const Signals = preload("res://scripts/core/block_signals.gd")
const Router = preload("res://scripts/rail_router.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	var tracks: Dictionary = {}
	var cells: Array[Vector2i] = []
	for x in range(13):
		tracks[Vector2i(x, 0)] = false
		cells.append(Vector2i(x, 0))
	var path := Router.make_path(cells, 32)
	var a := {"id": 1, "cells": cells, "path": path, "distance": 32.0, "forward": true, "moving": true}
	var b := {"id": 2, "cells": cells, "path": path, "distance": 352.0, "forward": false, "moving": true}
	var signs := {Vector2i(3, 0): "auto", Vector2i(9, 0): "auto"}
	var manager := Signals.new()
	manager.configure(tracks, signs)
	check(manager.cell_blocks[Vector2i(2, 0)] != manager.cell_blocks[Vector2i(4, 0)], "signal splits connected blocks")
	manager.update([b, a], {Vector2i(1, 0): 1, Vector2i(11, 0): 2}, 32)
	check(manager.limit(a, 128, 32).distance == 128, "lower permanent ID obtains empty block first")
	var blocked := manager.limit(b, 224, 32)
	check(blocked.distance > 224 and blocked.conflict.owner == 1, "opposing entrance held before signal body overlap")
	var owners: Dictionary = manager.block_owners.duplicate(true)
	manager.update([a, b], {Vector2i(1, 0): 1, Vector2i(11, 0): 2}, 32)
	check(manager.block_owners == owners, "input order does not change block grants")
	manager.update([b], {Vector2i(11, 0): 2}, 32)
	check(manager.limit(b, 224, 32).distance == 224, "empty block released and waiting train admitted")
	manager.update([a, b], {Vector2i(5, 0): 2, Vector2i(1, 0): 1}, 32)
	check(manager.limit(a, 128, 32).conflict.owner == 2, "body occupancy beats lower ID")
	signs[Vector2i(3, 0)] = "stop"
	signs[Vector2i(9, 0)] = "stop"
	manager.configure(tracks, signs)
	manager.update([a, b], {}, 32)
	check(manager.limit(a, 128, 32).distance < 128, "manual stop blocks forward entry")
	check(manager.limit(b, 224, 32).distance > 224, "manual stop blocks reverse entry")
	a.distance = 96.0
	manager.update([a], {Vector2i(3, 0): 1}, 32)
	check(manager.limit(a, 128, 32).distance == 128, "signal changed under train allows clearing occupied tile")
	manager.configure(tracks, {})
	manager.update([a, b], {}, 32)
	check(manager.limit(a, 200, 32).distance == 200, "removing all signals restores tile-only operations")
	print("Block signals: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
