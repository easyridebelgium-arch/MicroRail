extends SceneTree
const Body = preload("res://scripts/core/route_body.gd")
const Consists = preload("res://scripts/core/consists.gd")
const Reservations = preload("res://scripts/core/track_reservations.gd")
const Signals = preload("res://scripts/core/block_signals.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const Clock = preload("res://scripts/core/sim_clock.gd")
const Router = preload("res://scripts/rail_router.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	var cells: Array[Vector2i] = []
	for x in range(2, 11): cells.append(Vector2i(x, 0))
	for y in range(1, 7): cells.append(Vector2i(10, y))
	for x in range(9, -1, -1): cells.append(Vector2i(x, 6))
	for y in range(5, -1, -1): cells.append(Vector2i(0, y))
	for x in range(1, 3): cells.append(Vector2i(x, 0))
	var path := Router.make_path(cells, 32)
	var total := path.get_baked_length()
	var tracks: Dictionary = {cells[0]: false}
	for index in range(1, cells.size() - 1): tracks[cells[index]] = Geometry.from_ports(cells[index - 1] - cells[index], cells[index + 1] - cells[index])
	tracks[Vector2i(1, 0)] = "junction_6_2_1"
	tracks[Vector2i(3, 0)] = "junction_6_2_1"
	check(Body.is_closed(path), "continuous circuit is detected")
	var folded: Array[Vector2i] = [Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(5, 0), Vector2i(4, 0)]
	check(not Body.is_closed(Router.make_path(folded, 32)), "out-and-back endpoint coincidence is not treated as a circuit")
	var table := Reservations.new()
	for length in [60.0, 92.0, 124.0, 156.0]:
		check(table.footprint(path, 0, 32, length) == table.footprint(path, total, 32, length), "body %.0f occupies the same cells before and after wrap" % length)
		for offset in [-64.0, -16.0, 16.0, 64.0]:
			check(Consists.pose(path, total + offset).position.distance_to(Consists.pose(path, offset).position) < 0.001, "vehicle offsets wrap on the circuit")
			check(Consists.pose(path, total - 0.1 + offset).position.distance_to(Consists.pose(path, 0.1 + offset).position) < 0.21, "vehicles travel continuously across the lap boundary")
		var train := {"id": 3, "length": length, "path": path, "cells": cells, "distance": 0.0, "forward": true, "moving": false}
		table.rebuild([train], tracks, 32)
		check(table.switch_owners.get(Vector2i(1, 0)) == 3 and table.switch_owners.get(Vector2i(3, 0)) == 3, "wrapped tail and nose both keep their switches locked")
		var grants: Dictionary = table.owners.duplicate()
		train.distance = total
		table.rebuild([train], tracks, 32)
		check(table.owners == grants, "wrapping a dwelling train does not release occupied tiles")
		train.distance = total - 0.5
		train.moving = true
		table.rebuild([train], tracks, 32)
		check(table.limit(3, path, train.distance, total, 32, length) == total, "long body can finish a lap under its grants")
	# Competing occupancy on the wrapped nose remains authoritative.
	var moving := {"id": 3, "length": 60.0, "path": path, "cells": cells, "distance": total - 80.0, "forward": true, "moving": true}
	var parked := {"id": 4, "length": 28.0, "path": path, "cells": cells, "distance": 16.0, "forward": true, "moving": false}
	table.rebuild([moving, parked], tracks, 32)
	var held := table.limit(3, path, moving.distance, total, 32, 60)
	check(held < total and table.waits[3].owner == 4, "wrapped nose stops before another train's occupied tile")
	var signal_tracks: Dictionary = tracks.duplicate()
	signal_tracks[Vector2i(1, 0)] = false
	signal_tracks[Vector2i(3, 0)] = false
	var signal_manager := Signals.new()
	signal_manager.configure(signal_tracks, {Vector2i(1, 0): "auto", Vector2i(3, 0): "auto"})
	var count := cells.size() - 1
	check(signal_manager._downstream(cells, count - 1, 1, true) == signal_manager.cell_blocks[Vector2i(2, 0)], "downstream block search crosses the closing occurrence")
	check(signal_manager._downstream(cells, 0, -1, true) == signal_manager.cell_blocks[Vector2i(0, 0)], "reverse downstream search wraps to the tail segment")
	var closing := {"id": 3, "length": 156.0, "path": path, "cells": cells, "distance": total - 100.0, "forward": true, "moving": true}
	signal_manager.update([closing], {Vector2i(4, 0): 4}, 32)
	check(signal_manager.requested_blocks[3].has(signal_manager.cell_blocks[Vector2i(4, 0)]), "nose lookahead can request a signal block beyond the route origin")
	signal_manager.configure(signal_tracks, {Vector2i(1, 0): "auto", Vector2i(3, 0): "stop"})
	signal_manager.update([closing], {}, 32)
	check(signal_manager.limit(closing, total - 40, 32).conflict.get("kind") == "manual_signal", "a manual signal beyond the join holds the wrapped nose")
	check(Consists.route_shape_error(path, cells, 60, "loop").is_empty(), "simple continuous circuit passes consist shape validation")
	check(not Consists.route_shape_error(path, cells, total + 1, "loop").is_empty(), "a train cannot occupy more than its entire circuit")
	var line: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	var editable := Router.make_path(line, 32)
	table._route_spans(editable, line, 32)
	editable.set_point_position(1, editable.get_point_position(1) + Vector2(0, 6))
	check(table._route_spans(editable, line, 32) == Reservations.new()._route_spans(editable, line, 32), "in-place curve edits invalidate cached occurrence distances")
	check(table._route_spans(editable, line, 16) == Reservations.new()._route_spans(editable, line, 16), "changing tile size invalidates cached occurrences")
	# Legacy single-vehicle Loops may revisit a switch with a different exit.
	# Wrapping must not replace the current lock with a later occurrence's state.
	var repeated: Array[Vector2i] = []
	repeated.assign(cells.slice(0, cells.size() - 1))
	var second_lap: Array[Vector2i] = cells.duplicate()
	second_lap[2] = Vector2i(4, 1)
	repeated.append_array(second_lap)
	var repeated_path := Router.make_path(repeated, 32)
	var repeated_tracks: Dictionary = tracks.duplicate()
	repeated_tracks[Vector2i(3, 0)] = "junction_6_2_3"
	repeated_tracks[Vector2i(5, 0)] = "junction_2_6_5"
	repeated_tracks[Vector2i(4, 1)] = Geometry.from_ports(Vector2i(-1, -1), Vector2i(1, -1))
	var single := {"id": 3, "length": 28.0, "path": repeated_path, "cells": repeated, "distance": repeated_path.get_closest_offset(Vector2(112, 16)), "forward": true, "moving": false}
	table.rebuild([single], repeated_tracks, 32)
	check(Body.is_closed(repeated_path) and table.switches.get(Vector2i(3, 0)) == 0, "current occurrence determines a legacy repeated Loop's switch lock")
	var boundaries: Array = [[0.0, 0], [10.0, 1], [10.0, 2], [20.0, 3]]
	var samples: Array = [-1.0, 0.0, 9.5, 10.0, 10.01, 19.9, 20.0, 100.0]
	var expected: Array = [0, 0, 0, 2, 2, 2, 3, 3]
	for sample in range(samples.size()): check(table._index_at(boundaries, samples[sample]) == expected[sample], "occurrence lookup preserves exact, duplicate and out-of-range boundaries")
	var snapshots: Array = []
	for fps in [30, 60, 120]:
		var clock := Clock.new()
		var periodic := {"id": 3, "length": 60.0, "path": path, "cells": cells, "distance": total - 1.5, "forward": true, "moving": true}
		for frame in range(fps * 2):
			for _tick in clock.advance(1.0 / fps):
				clock.begin_tick()
				table.rebuild([periodic], tracks, 32)
				var target := minf(total, float(periodic.distance) + 80.0 / 60.0)
				periodic.distance = table.limit(3, path, periodic.distance, target, 32, 60)
				if absf(periodic.distance - total) < 0.001: periodic.distance = 0.0
		table.rebuild([periodic], tracks, 32)
		snapshots.append([clock.tick, periodic.distance, table.owners.duplicate(), table.switch_owners.duplicate(), Consists.pose(path, periodic.distance - 16.0)])
	check(int(snapshots[0][0]) == 120 and float(snapshots[0][1]) > 100, "fixed-tick movement actually wraps and continues along the circuit")
	check(snapshots[0] == snapshots[1] and snapshots[1] == snapshots[2], "wrapped movement, vehicle poses and authority match at 30/60/120 FPS")
	print("Loop body: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
