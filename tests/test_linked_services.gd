extends SceneTree
const Services = preload("res://scripts/service_routes.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: _run.call_deferred()
func tick(game: Node) -> void:
	game.sim_clock.begin_tick()
	game._simulation_step(1.0 / 60.0)
func _run() -> void:
	# Pure rules.
	var base := Services.defaults()
	base["passenger_5"] = {"name": "Second", "stops": ["a", "b"], "waypoints": {}, "mode": "shuttle", "link": "passenger"}
	check(Services.is_valid(base), "a link to an existing passenger service is valid")
	var bad := base.duplicate(true)
	bad["passenger_5"]["link"] = "passenger_5"
	check(not Services.is_valid(bad), "a service cannot link to itself")
	bad["passenger_5"]["link"] = "freight"
	check(not Services.is_valid(bad), "only passenger services can be linked to")
	bad["passenger_5"]["link"] = "passenger_9"
	check(not Services.is_valid(bad), "a link to a missing service is invalid")
	var chain := base.duplicate(true)
	chain["passenger_6"] = {"name": "Third", "stops": ["a", "b"], "waypoints": {}, "mode": "shuttle", "link": "passenger_5"}
	check(not Services.is_valid(chain), "links are one level deep")
	var source := base.duplicate(true)
	source["passenger"]["stops"] = ["a", "c", "b"]
	source["passenger"]["platforms"] = {"b": 2, "a": 3}
	var followed := Services.propagate(source)
	check(followed["passenger_5"]["stops"] == ["a", "c", "b"] and followed["passenger_5"]["platforms"] == {"b": 2}, "a linked service follows stops and platforms but keeps its first-stop platform")
	check(followed["passenger_5"]["name"] == "Second" and followed["passenger_5"]["link"] == "passenger", "it keeps its own name and link")
	var orphan := base.duplicate(true)
	orphan["passenger_5"]["link"] = "passenger_8"
	check(not Services.propagate(orphan)["passenger_5"].has("link"), "propagate drops a dangling link")

	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.scenario_goals.current_index = game.ScenarioGoals.OBJECTIVES.size()
	game.money = 100000
	for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	game.paused = false
	for i in range(60 * 8): tick(game)
	game.paused = true
	var bought: Dictionary = game.buy_fleet_train(game.Fleet.MODELS.keys()[0])
	var message: String = game.duplicate_passenger_service(int(bought.id), "passenger", true)
	check(message.contains("linked copy"), "a linked copy starts: " + message)
	var key: String = game.Fleet.find(game.fleet, int(bought.id)).service
	check(game.services[key].get("link", "") == "passenger", "the copy is linked to its source")
	# Put both trains at home, then edit the source: the copy follows.
	game.route_distance = 0.0
	game.passenger_stop_index = 0
	game.passengers_on_train = 0
	game.passenger_returning = false
	game.travelling_to_b = true
	game._update_train_transform()
	var linked = game.passenger_services[key]
	linked.distance = 0.0
	linked.stop_index = 0
	linked.forward = true
	linked.passengers = 0
	linked.returning = false
	linked.update_transform()
	var configuration: Dictionary = game.services.duplicate(true)
	configuration["passenger"]["stops"] = ["a", "b", "c"]
	var applied: String = game.apply_service_routes(configuration)
	check(applied.begins_with("Routes applied"), "editing the source applies: " + applied)
	check(game.services[key].stops == ["a", "b", "c"] and game.passenger_services[key].cells == game.route_cells, "the linked service follows the new stops and route")
	# Editor shows the link and Unlink stops following.
	game._open_routes_editor()
	await process_frame
	var editor = game.route_editor
	editor.service_choice.item_selected.emit(2)
	check(editor.link_controls.visible and not editor.editing_controls.visible and editor.route_mode.disabled, "Routes locks a linked service's route controls")
	editor.unlink_button.pressed.emit()
	check(not editor.draft[key].has("link") and editor.editing_controls.visible, "Unlink frees the route for editing")
	editor.confirmed.emit()
	check(not game.services[key].has("link"), "unlinking is applied")
	editor.hide()
	game.queue_free()
	await process_frame
	print("Linked services: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
