extends SceneTree
const Rules = preload("res://scripts/core/signal_rules.gd")
const Router = preload("res://scripts/waypoint_router.gd")
const Rail = preload("res://scripts/rail_router.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const Blocks = preload("res://scripts/core/block_signals.gd")
const Blueprints = preload("res://scripts/core/track_blueprints.gd")
const Plan = preload("res://scripts/core/construction_plan.gd")
const Impact = preload("res://scripts/core/construction_impact.gd")
const Services = preload("res://scripts/service_routes.gd")
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
	for x in range(12):
		tracks[Vector2i(x, 0)] = false
		cells.append(Vector2i(x, 0))
	var signs := {Vector2i(5, 0): "oneway_2"}
	check(Rules.valid_on("oneway_2", false) and not Rules.valid_on("oneway_0", false), "direction must follow signal track axis")
	check(not Rules.valid("oneway_9") and not Rules.valid(2), "invalid modes rejected")
	check(Rules.next_mode("stop", false) == "oneway_2" and Rules.next_mode("oneway_6", false) == "", "signal click cycle covers both directions then removal")
	check(not Router.find_route(tracks, cells[0], cells[-1], [], signs).is_empty(), "routing follows permitted signal direction")
	check(Router.find_route(tracks, cells[-1], cells[0], [], signs).is_empty(), "wrong-way route rejected")
	check(not Router.find_route(tracks, cells[0], cells[-1], [[3, 0, 2]]).is_empty(), "directional waypoint accepts matching approach")
	check(Router.find_route(tracks, cells[0], cells[-1], [[3, 0, 6]]).is_empty(), "directional waypoint rejects wrong approach")
	check(Services.waypoints_in_order(cells, [[3, 0, 2]]) and not Services.waypoints_in_order(cells, [[3, 0, 6]]), "retained route validates waypoint approach")
	var loop_tracks := tracks.duplicate()
	loop_tracks[Vector2i(3, 0)] = "junction_6_2_3"
	loop_tracks[Vector2i(4, 1)] = Geometry.from_ports(Vector2i(-1, -1), Vector2i.RIGHT)
	for x in range(5, 9): loop_tracks[Vector2i(x, 1)] = false
	loop_tracks[Vector2i(9, 1)] = Geometry.from_ports(Vector2i.LEFT, Vector2i(1, -1))
	loop_tracks[Vector2i(10, 0)] = "junction_2_6_5"
	var loop_signs := {Vector2i(6, 0): "oneway_2", Vector2i(6, 1): "oneway_6"}
	var catalog := {"a": {"name": "A", "cell": cells[0]}, "b": {"name": "B", "cell": cells[-1]}}
	var circuit := Services.build(loop_tracks, ["a", "b"], 32, {"b>a": [[6, 1, 6]]}, "loop", {}, catalog, loop_signs)
	check(not circuit.cells.is_empty() and circuit.distances.size() == 3 and circuit.cells.has(Vector2i(6, 1)), "two-stop Loop routes outward and return independently through directed passing lanes")
	var shuttle := Services.build(loop_tracks, ["a", "b"], 32, {}, "shuttle", {}, catalog, loop_signs)
	check(shuttle.cells.is_empty() and shuttle.error.contains("Shuttle retraces"), "a Shuttle cannot promise a return against a one-way signal")
	var path := Rail.make_path(cells, 32)
	var train := {"id": 1, "cells": cells, "path": path, "distance": 96.0, "forward": true, "moving": true, "length": 28.0}
	var blocks := Blocks.new()
	blocks.configure(tracks, signs)
	blocks.update([train], {}, 32)
	check(blocks.limit(train, 200, 32).distance == 200, "permitted direction receives ordinary block authority")
	blocks.configure(tracks, {Vector2i(5, 0): "oneway_6"})
	blocks.update([train], {}, 32)
	var denied := blocks.limit(train, 200, 32)
	check(denied.distance < 160 and denied.conflict.kind == "oneway_signal", "wrong-way movement stops before entering signal tile with precise reason")
	var reservations = preload("res://scripts/core/track_reservations.gd").new()
	var junction_tracks := tracks.duplicate()
	junction_tracks[Vector2i(5, 0)] = "junction_6_2_3"
	var leader := {"id": 3, "cells": cells, "path": path, "distance": 174.66, "forward": true, "moving": true, "length": 28.0}
	var follower := {"id": 1, "cells": cells, "path": path, "distance": 96.0, "forward": true, "moving": true, "length": 28.0}
	reservations.rebuild([follower, leader], junction_tracks, 32)
	check(reservations.owners.get(Vector2i(4, 0)) == 3 and reservations.switch_owners.get(Vector2i(5, 0)) == 3, "physical switch holder protects cleared stem before lower-ID future requests")
	check(not reservations.waits.has(3) and reservations.limit(3, path, 174.66, 200, 32) > 174.66, "leader clears switch while following train yields")
	var data := {"version": 1, "name": "Shape", "width": 3, "height": 2, "tiles": [[0, 0, false], [1, 0, "junction_6_2_3"], [2, 0, "cross_0_2"]], "signals": [[0, 0, "oneway_2"]]}
	var original := data.duplicate(true)
	var rotated := Blueprints.transformed(data, 1, false)
	check(Blueprints.valid(rotated) and rotated.width == 2 and rotated.height == 3 and rotated.signals[0][2] == "oneway_4", "rotation transforms footprint and directional signals")
	check(Geometry.connections(rotated.tiles[1][2]) == [Vector2i.UP, Vector2i.DOWN, Vector2i(-1, 1)], "rotation preserves switch stem/through/branch roles")
	var restored := rotated
	for i in range(3): restored = Blueprints.transformed(restored, 1, false)
	check(restored == original and data == original, "four turns restore source without mutating library")
	var reflected := Blueprints.transformed(data, 0, true)
	check(reflected.signals[0][2] == "oneway_6" and Blueprints.transformed(reflected, 0, true) == original, "double reflection restores all ports, signal direction and coordinates")
	var plan := Plan.new()
	plan.stage({Vector2i(2, 2): false, Vector2i(3, 2): "junction_6_2_3"}, {})
	var detail := plan.quote_details()
	check(detail.track == 20 and detail.switch == 100 and detail.track + detail.switch + detail.bridge == plan.quote().cost, "itemised draft costs reconcile with charged total")
	var impact := Impact.new()
	var trains := [{"id": 1, "cells": cells}, {"id": 2, "cells": cells}]
	var risks := impact.structural(tracks, trains)
	check(risks.size() == 1 and risks[0].contains("12 tiles") and risks[0].contains("not a forecast"), "shared plain run produces evidence-labelled structural warning")
	check(impact.structural(tracks, trains) == risks, "unchanged structural result is cached")
	check(impact.structural(tracks, [{"id": 1, "cells": cells}]).is_empty(), "removing competing service clears stale warning")
	print("Operations batches: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
