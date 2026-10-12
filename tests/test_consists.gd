extends SceneTree
const Fleet = preload("res://scripts/fleet.gd")
const Stock = preload("res://scripts/core/consists.gd")
const Router = preload("res://scripts/rail_router.gd")
const Migrations = preload("res://scripts/core/save_migrations.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	var train := Fleet.make_train(3, "passenger_fast")
	check(Fleet.length(train) == 28 and Fleet.capacity(train) == 12 and Fleet.speed(train) == 120, "unmodified train must retain original length, capacity and speed")
	train.wagons = ["coach", "coach"]
	check(Fleet.length(train) == 92 and Fleet.capacity(train) == 48, "two coaches must add capacity and full body length")
	check(Fleet.speed(train) == 100 and Fleet.running_cost(train) == 4, "coaches must cap speed and add running costs")
	check(Stock.offsets(train) == [32.0, 0.0, -32.0], "vehicle offsets must remain centred and independent of travel direction")
	check(not Stock.valid(["coach"], "freight") and not Stock.valid(["log_wagon"], "passenger"), "mixed passenger/cargo stock must be refused")
	check(not Stock.valid(["unknown"], "passenger") and not Stock.valid(["coach", "coach", "coach", "coach", "coach"], "passenger"), "unknown stock and overlength consists must be refused")
	check(Fleet.sale_price(train) == 505, "selling a stored consist must refund half the locomotive and attached stock investment")
	var fleet := Fleet.defaults()
	fleet.trains[0].wagons = ["log_wagon"]
	check(not Fleet.is_valid(fleet), "save validation must reject incompatible stock")
	fleet.trains[0].wagons = ["coach"]
	check(Fleet.is_valid(fleet), "valid saved composition must pass fleet validation")
	var cells: Array[Vector2i] = []
	var tracks: Dictionary = {}
	for x in range(4, 21):
		cells.append(Vector2i(x, 8))
		tracks[Vector2i(x, 8)] = false
	var path := Router.make_path(cells, 32)
	check(not Stock.stop_clearance(path, 0, 60, tracks, 32).is_empty(), "platform check must detect absent track behind the route start")
	tracks[Vector2i(3, 8)] = false
	check(Stock.stop_clearance(path, 0, 60, tracks, 32).is_empty(), "straight approach extension must provide body clearance")
	check(not Stock.stop_clearance(path, 0, 60, tracks, 32, {Vector2i(3, 8): "stop"}).is_empty(), "stopping clearance must not spawn a body across a manual signal")
	tracks[Vector2i(3, 8)] = "junction_6_2_4"
	check(not Stock.stop_clearance(path, 0, 60, tracks, 32).is_empty(), "switches must not count as straight platform clearance")
	var migrated := Migrations.migrate({"version": 22, "fleet": Fleet.defaults()})
	check(migrated.ok and migrated.data.version == 23 and migrated.data.fleet.trains[0].wagons.is_empty(), "version 22 must upgrade to single-vehicle consists without altering ownership")
	var thirty := simulate(30)
	check(thirty == simulate(60) and thirty == simulate(120), "long-body movement and ownership must be identical at 30, 60 and 120 FPS")
	print("Consists: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func simulate(fps: int) -> Array:
	var Clock = preload("res://scripts/core/sim_clock.gd")
	var clock := Clock.new()
	var table := preload("res://scripts/core/track_reservations.gd").new()
	var cells: Array[Vector2i] = []
	for x in range(21): cells.append(Vector2i(x, 5))
	var path := Router.make_path(cells, 32)
	var a := {"id": 1, "path": path, "cells": cells, "distance": 224.0, "moving": false, "forward": true, "length": 60.0}
	var b := {"id": 2, "path": path, "cells": cells, "distance": 0.0, "moving": true, "forward": true, "length": 92.0}
	var safe := true
	var waited := false
	var resumed := false
	for frame in range(fps * 4):
		for tick in range(clock.advance(1.0 / fps)):
			clock.begin_tick()
			a.moving = clock.tick > 120
			table.rebuild([b, a], {}, 32)
			if a.moving: a.distance = table.limit(1, path, a.distance, a.distance + 100.0 / 60.0, 32, a.length)
			var old: float = b.distance
			b.distance = table.limit(2, path, b.distance, b.distance + 120.0 / 60.0, 32, b.length)
			if b.distance == old: waited = true
			elif waited: resumed = true
			var owned: Array[Vector2i] = table.footprint(path, a.distance, 32, a.length)
			for cell in table.footprint(path, b.distance, 32, b.length):
				if owned.has(cell): safe = false
	check(safe and waited and resumed, "long train must wait without body overlap and resume when the parked train clears (%d FPS)" % fps)
	return [clock.tick, a.distance, b.distance, table.owners]
