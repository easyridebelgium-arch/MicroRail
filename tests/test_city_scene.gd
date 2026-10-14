extends SceneTree
var game: Node
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()

func connect_stations(origin: Vector2i, destination: Vector2i) -> bool:
	var direction := Vector2i.RIGHT if destination.x >= origin.x else Vector2i.LEFT
	var first := origin + direction * 3
	var last := destination - direction * 3
	var queue: Array[Vector2i] = [first]
	var previous := {first: first}
	var cursor := 0
	while cursor < queue.size() and not previous.has(last):
		var current := queue[cursor]
		cursor += 1
		for delta in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var next: Vector2i = current + delta
			if not previous.has(next) and game._is_inside_map(next) and not game._is_station_space(next) and not game.tracks.has(next):
				previous[next] = current
				queue.append(next)
	if not previous.has(last): return false
	var middle: Array[Vector2i] = [last]
	while middle.back() != first: middle.append(previous[middle.back()])
	middle.reverse()
	var cells: Array[Vector2i] = [origin, origin + direction, origin + direction * 2]
	cells.append_array(middle)
	cells.append_array([destination - direction * 2, destination - direction, destination])
	var plan: Dictionary = game.TrackBuilder.plan(cells, game.tracks, Vector2i(80, 50), game._is_station_space, game.facility_cells())
	if not plan.error.is_empty(): return false
	var updates: Array = []
	for cell in plan.changes: updates.append([cell.x, cell.y, plan.changes[cell]])
	game._execute_build({"cells": updates})
	return not game.RailRouter.find_route(game.tracks, origin, destination).is_empty()
func run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/dev/city_preview.tscn").instantiate()
	game.startup_city_count = 8
	root.add_child(game)
	game.set_process(false)
	await process_frame
	check(game.city_builder.is_city_game() and game.paused and game.tracks.is_empty(), "main scene adopts empty city startup")
	check(game.object_rows().filter(func(row: Dictionary) -> bool: return row.kind == "City").size() == 8 and game._facility_markers().size() == 10, "cities can be found and located on the network map")
	check(game.service_keys().is_empty() and game.reservation_trains.is_empty() and not game.freight_train.visible, "no phantom actors or reservations")
	game.route_editor.open_editor()
	check(game.route_editor.get_ok_button().disabled and game.route_editor.empty_label.visible, "empty Routes offers instructions")
	game.route_editor.hide()
	game.fleet_editor.open_editor()
	check(game.fleet_editor.train_list.item_count == 0 and game.fleet_editor.start_button.disabled, "empty Fleet is usable")
	game.fleet_editor.hide()
	game.city_builder.toggle()
	check(game.city_builder.active and not game.straight_button.button_pressed, "Station button selects exclusive tool")
	var candidates: Array = game.CityBuildTool.Generator.planning(game.world.save_state()).station_candidates
	var stop := Vector2i(candidates[0].cell[0], candidates[0].cell[1])
	game.city_builder.submit(stop)
	check(game.world.stations().size() == 1 and game.money == 4700 and game.tracks.size() == 5, "paused station click commits catalog, tracks and balance")
	check(game.passenger_demand.station_ids.size() == 1 and game.passenger_demand.waiting(game.world.station_key(stop)) == 0, "station-owned state connected to main")
	game._inspect_station_at(stop)
	game._update_station_inspector()
	game.station_panel.hide()
	game.city_builder.submit(stop)
	check(game.money == 4700 and game.world.stations().size() == 1, "duplicate purchase has no charge")
	game._reset_track_tools()
	check(not game.city_builder.active and not game.draw_track_mode, "reset returns to Connect")
	check(not game._can_build_at(Vector2i(game.world.state.settlements[0].cell[0], game.world.state.settlements[0].cell[1])), "city buildings protect land from track")
	check(not game._can_demolish(stop + Vector2i(2, 0)), "purchased platform extensions are protected")
	game.paused = false
	for tick in range(1, 61):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
	game.paused = true
	game._update_instructions()
	game._update_network_map()
	check(game.reservation_trains.is_empty(), "empty world can advance without actors")
	check(not game._save_game(4), "development mode cannot write an incompatible save")
	var queued_stop := Vector2i(candidates[3].cell[0], candidates[3].cell[1])
	game.paused = false
	game.city_builder.submit(queued_stop)
	check(game.world.stations().size() == 1 and game.command_queue.count() == 1, "running station input waits for the next fixed tick")
	var command_state: Dictionary = JSON.parse_string(JSON.stringify(game.command_queue.save_state()))
	game.command_queue.restore_state(command_state)
	game.sim_clock.begin_tick()
	game._run_due_commands()
	game.paused = true
	check(game.world.stations().size() == 2 and game.command_queue.is_empty(), "plain-data station command survives JSON and executes at its tick")
	game.city_builder.submit(queued_stop)
	check(game.world.stations().size() == 2, "queued purchase remains unique")
	var second := Vector2i(candidates[1].cell[0], candidates[1].cell[1])
	game.city_builder.submit(second)
	check(game.world.stations().size() == 3 and connect_stations(stop, second), "normal construction connects two generated stations around city land")
	var bought: Dictionary = game.buy_fleet_train("passenger_standard")
	check(bought.ok and int(bought.id) == 1, "first train bought through main Fleet gets ID one")
	game.fleet_editor.open_editor()
	check(not game.fleet_editor.start_button.disabled, "Fleet enables starting a passenger route after stations exist")
	check(game.fleet_editor.start_destination.item_count == 2 and game.fleet_editor.start_destination.get_selected_metadata() != game.fleet_editor.start_station.get_selected_metadata(), "Fleet offers a destination separate from the departure station")
	game.fleet_editor.hide()
	var message: String = game.start_passenger_service(int(bought.id), game.world.station_key(stop), game.world.station_key(second))
	check(message.contains("started") and game.passenger_services.size() == 1 and not game.services.has("passenger"), "first service uses catalog stops without a legacy primary")
	var key: String = game.fleet.trains[0].service
	game.route_editor.open_editor()
	check(game.route_editor.selected_service_key == key and not game.route_editor.get_ok_button().disabled, "Routes opens the first actual city service")
	game.route_editor.hide()
	check(game.apply_service_routes(game.services.duplicate(true)).begins_with("Routes applied"), "route edits accept catalog-based city services")
	var before: Vector2 = game.passenger_services[key].position
	game.paused = false
	for tick in range(180):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
	game.paused = true
	check(game.passenger_services[key].position.distance_to(before) > 1 and game.reservation_trains.size() == 1, "city service moves under reservations without phantom trains")
	var physical: Vector2 = game.passenger_services[key].position
	game.city_builder.submit(Vector2i(candidates[2].cell[0], candidates[2].cell[1]))
	check(game.world.stations().size() == 4 and game.passenger_services[key].position == physical, "adding a station leaves an operating train in place")
	game._inspect_station_at(game.FOREST_SITE)
	game._update_station_inspector()
	game.station_panel.hide()
	var freight_bought: Dictionary = game.buy_fleet_train("freight_standard")
	var freight_cells: Array = []
	for x in range(game.FOREST_SITE.x, game.CARGO_TERMINAL.x + 1): freight_cells.append([x, game.FOREST_SITE.y, false])
	game._execute_build({"cells": freight_cells})
	check(game.start_freight_service(int(freight_bought.id)).contains("started") and game.freight_train.visible, "first freight service starts independently")
	game.route_editor.open_editor()
	game.route_editor.hide()
	game._inspect_station_at(game.FOREST_SITE)
	game._update_station_inspector()
	game.station_panel.hide()
	game.forest_stock = 20
	game.paused = false
	for tick in range(180):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
	game.paused = true
	check(game.freight_train.distance_along_route > 1 and game.reservation_trains.size() == 2, "freight and city passengers both advance with only their real reservations")
	var tutorial = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(tutorial)
	tutorial.set_process(false)
	tutorial.paused = true
	check(tutorial._save_game(4), "ordinary tutorial can still save its slot")
	check(game._load_slot(4), "a development city session can return to a saved tutorial")
	game._update_toolbar()
	check(not game.city_builder.is_city_game() and not game.city_builder.button.visible and not game.save_button.disabled and game.service_keys() == ["passenger", "freight"], "tutorial loading restores normal tools, saving and primary services")
	tutorial.queue_free()
	await process_frame
	game.queue_free()
	await process_frame
	print("City scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
