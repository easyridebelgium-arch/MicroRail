extends SceneTree
const Router = preload("res://scripts/rail_router.gd")
const Events = preload("res://scripts/core/event_log.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var states: Array = []
	for fps in [30, 60, 120]:
		var game = load("res://scenes/main/main.tscn").instantiate()
		root.add_child(game)
		await process_frame
		game.set_process(false)
		game.sim_clock.reset()
		game.event_log.clear()
		var horizontal: Array[Vector2i] = []
		var vertical: Array[Vector2i] = []
		for x in range(4, 21): horizontal.append(Vector2i(x, 8))
		for y in range(17): vertical.append(Vector2i(12, y))
		game.route_cells = horizontal
		game.route_path = Router.make_path(horizontal, 32)
		game.route_connected = true
		game.route_distance = 0.0
		game.stop_distances.assign([0.0, 512.0])
		game.waiting_at_a = 10
		game._update_train_transform()
		game.freight_train.set_route(vertical, 32)
		game.freight_train.base_speed = 80.0
		game.freight_route_cells = vertical
		game.forest_stock = 80
		var collision := false
		for frame in range(fps * 10):
			for step in game.sim_clock.advance(1.0 / fps):
				game.sim_clock.begin_tick()
				game._simulation_step(1.0 / 60.0)
				var passenger_tiles: Array[Vector2i] = game.reservations.footprint(game.route_path, game.route_distance, 32)
				for cell in game.reservations.footprint(game.freight_train.route_path, game.freight_train.distance_along_route, 32):
					collision = collision or passenger_tiles.has(cell)
		check(not collision, "real passenger/freight hooks prevent overlap at %d FPS" % fps)
		check(game.passengers_delivered > 0 and game.logs_delivered > 0, "both services deliver after waiting")
		var waits: Array = game.event_log.query(Events.TRAIN_WAITING)
		check(not waits.is_empty(), "blocked movement records an event")
		check(waits.size() < 10, "waiting events are not repeated each tick")
		check((str(waits[0].data.reason) if not waits.is_empty() else "").contains("Waiting for"), "waiting includes the blocker and location")
		states.append([game.route_distance, game.freight_train.distance_along_route, game.money, game.event_log.save_state()])
		game.queue_free()
		await process_frame
	check(states[0] == states[1] and states[1] == states[2], "real fixed-step train positions, money and events match at all FPS")
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
	for x in range(8, 29): game.tracks[Vector2i(x, 24)] = false
	game._check_route()
	game.paused = true
	game.train_needs_boarding = false
	game.route_distance = 96.0
	game._update_train_transform()
	game._rebuild_reservations()
	var ownership: Dictionary = game.reservations.owners.duplicate()
	game._save_game()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	check(int(saved["version"]) == 18 and not saved.has("reservations"), "reservations need no new save schema")
	game.reservations.owners.clear()
	game.route_distance = 0.0
	game._load_game()
	check(game.reservations.owners == ownership, "load reconstructs ownership from restored positions")
	var occupied := Vector2i(7, 8)
	check(not game._can_demolish(occupied), "occupied track cannot be removed")
	var before: Dictionary = game.tracks.duplicate()
	game._execute_set_tile({"x": 7, "y": 8, "tile": "junction_6_2_3"})
	check(game.tracks == before, "switch tool cannot modify reserved track")
	game._execute_build({"cells": [[7, 8, true]], "new_count": 0})
	check(game.tracks == before, "queued construction cannot modify reserved track")
	check(not game._apply_construction_history({"before": {occupied: null}, "after": {occupied: false}, "money_change": 0, "construction_change": 0}, true), "Undo cannot remove reserved track")
	var shared: Array[Vector2i] = [Vector2i(12, 24)]
	check(not game._find_freight_route(game.tracks, shared).is_empty(), "freight shortest path may share passenger tiles")
	game.queue_free()
	await process_frame
	print("Reservation integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
