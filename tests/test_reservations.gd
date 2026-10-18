extends SceneTree
const Reservations = preload("res://scripts/core/track_reservations.gd")
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
func _initialize() -> void:
	var main: Array[Vector2i] = []
	for x in range(11): main.append(Vector2i(x, 0))
	var branch: Array[Vector2i] = [Vector2i(10, 1), Vector2i(9, 1), Vector2i(8, 1), Vector2i(7, 1), Vector2i(6, 1), Vector2i(5, 0), Vector2i(4, 0), Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 0), Vector2i(0, 0)]
	var tracks := {Vector2i(5, 0): "junction_6_2_3"}
	var table := Reservations.new()
	var a := train(1, main, 64)
	var b := train(2, branch, 64)
	table.rebuild([b, a], tracks, 32)
	check(table.owners.get(Vector2i(5, 0)) == 1, "lower ID wins the switch regardless of input order")
	check(table.switches.get(Vector2i(5, 0)) == 0, "through train locks the switch through")
	var snapshot := table.owners.duplicate()
	table.rebuild([a, b], tracks, 32)
	check(table.owners == snapshot, "stable request ordering")
	a.distance = 288.0
	table.rebuild([a, b], tracks, 32)
	check(table.owners.get(Vector2i(5, 0)) == 2, "waiting train claims a cleared switch")
	check(table.switches.get(Vector2i(5, 0)) == 1, "trailing branch move also locks its exit")
	# A later route leg can revisit the same switch through another exit.
	var first_leg: Array[Vector2i] = [Vector2i(8, 1), Vector2i(7, 1), Vector2i(6, 1), Vector2i(5, 0), Vector2i(4, 0), Vector2i(3, 0)]
	var second_leg: Array[Vector2i] = [Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(8, 0)]
	var repeated := first_leg.duplicate()
	repeated.append_array(second_leg.slice(1))
	var repeating := train(1, repeated, 64.0)
	var path := Router.make_path(first_leg, 32)
	var turn_distance := path.get_baked_length()
	var return_path := Router.make_path(second_leg, 32)
	for i in range(1, return_path.point_count): path.add_point(return_path.get_point_position(i))
	repeating.path = path
	table.rebuild([repeating], tracks, 32)
	check(table.switches.get(Vector2i(5, 0)) == 1, "first occurrence uses the branch despite a later through leg")
	repeating.distance = turn_distance + 32.0
	table.rebuild([repeating], tracks, 32)
	check(table.switches.get(Vector2i(5, 0)) == 0, "later occurrence uses the through exit")
	# A stopped vehicle still owns every tile touched by its body.
	a.distance = 112.0
	a.moving = false
	b = train(2, main, 240, false)
	table.rebuild([a, b], {}, 32)
	check(table.owners.get(Vector2i(3, 0)) == 1 and table.owners.get(Vector2i(4, 0)) == 1, "body straddling an edge keeps both tiles")
	var allowed := table.limit(2, b.path, b.distance, 0.0, 32)
	check(allowed > 112.0, "head-on train stops before the occupied body")
	var switch_result := simulate(60, true)
	check(switch_result == simulate(30, true) and switch_result == simulate(120, true), "switch contention is repeatable across FPS")
	var thirty := simulate(30)
	check(thirty == simulate(60), "30 and 60 FPS match")
	check(thirty == simulate(120), "30 and 120 FPS match")
	print("Reservation tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func simulate(fps: int, use_switch: bool = false) -> Array:
	var clock := Clock.new()
	var table := Reservations.new()
	var horizontal: Array[Vector2i] = []
	var vertical: Array[Vector2i] = []
	for i in range(11):
		horizontal.append(Vector2i(i, 5))
		vertical.append(Vector2i(5, i))
	var track_data := {}
	if use_switch:
		horizontal.clear()
		for x in range(11): horizontal.append(Vector2i(x, 0))
		vertical.assign([Vector2i(10, 1), Vector2i(9, 1), Vector2i(8, 1), Vector2i(7, 1), Vector2i(6, 1), Vector2i(5, 0), Vector2i(4, 0), Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 0), Vector2i(0, 0)])
		track_data[Vector2i(5, 0)] = "junction_6_2_3"
	var a := train(1, horizontal, 0)
	var b := train(2, vertical, 0)
	var waited := false
	var collision := false
	for frame in range(fps * 10):
		for tick in clock.advance(1.0 / fps):
			clock.begin_tick()
			table.rebuild([b, a], track_data, 32)
			for t in [a, b]:
				var proposed: float = minf(t.distance + 80.0 / 60.0, t.path.get_baked_length())
				var result: float = table.limit(t.id, t.path, t.distance, proposed, 32)
				waited = waited or result < proposed - 0.001
				t.distance = result
			var occupied := {}
			for t in [a, b]:
				for cell in table.footprint(t.path, t.distance, 32):
					collision = collision or occupied.has(cell)
					occupied[cell] = t.id
	check(not collision, "moving trains never share a body tile")
	check(waited, "crossing conflict causes waiting")
	check(absf(a.distance - a.path.get_baked_length()) < 0.001 and absf(b.distance - b.path.get_baked_length()) < 0.001, "both trains continue after conflict clears")
	return [a.distance, b.distance, clock.tick]
