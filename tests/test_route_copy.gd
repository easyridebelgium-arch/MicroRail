extends SceneTree
const Services = preload("res://scripts/service_routes.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var source := {"name": "Source", "stops": ["a", "c", "b"], "mode": "loop", "waypoints": {"a>c": [[12, 8]]}, "platforms": {"c": 2}}
	var target := {"name": "Target", "stops": ["a", "b"], "waypoints": {"a>b": [[10, 8]]}, "platforms": {"b": 3}}
	var copied := Services.copy_route(source, target)
	check(copied.name == "Target" and copied.stops == source.stops and copied.mode == "loop" and copied.platforms == {"c": 2}, "copy replaces instructions and keeps target identity")
	copied.stops.reverse()
	copied.waypoints["a>c"][0][0] = 13
	copied.platforms.c = 3
	check(source.stops == ["a", "c", "b"] and source.waypoints["a>c"] == [[12, 8]] and source.platforms.c == 2 and target.platforms == {"b": 3}, "nested edits never affect either original")
	check(Services.copy_route(Services.defaults().passenger, target).platforms.is_empty(), "default source clears previous overrides")
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	game.money = 10000
	for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	var editor = game.route_editor
	editor.open_editor()
	check(editor.copy_button.disabled, "no second passenger service means no copy source")
	editor.hide()
	var configuration: Dictionary = game.services.duplicate(true)
	configuration.passenger.stops = ["a", "b", "c"]
	configuration.passenger.waypoints = {"a>b": [[12, 8]], "b>c": [[28, 8]]}
	check(game.apply_service_routes(configuration).begins_with("Routes applied"), "source route configured")
	game.paused = false
	for step in range(240):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
	game.paused = true
	var purchase: Dictionary = game.buy_fleet_train("passenger_standard")
	check(purchase.get("ok", false), "stored train bought")
	if not purchase.get("ok", false):
		quit(1)
		return
	var id: int = purchase.id
	check(game.start_passenger_service(id, "a").contains("started"), "target starts safely after source clears home")
	var key: String = game.Fleet.find(game.fleet, id).service
	if key.is_empty():
		quit(1)
		return
	var source_position: Vector2 = game.train_position
	var source_distance: float = game.route_distance
	var money: int = game.money
	var target_position: Vector2 = game.passenger_services[key].position
	var fleet_before: Dictionary = game.fleet.duplicate(true)
	editor.open_editor()
	editor.service_choice.item_selected.emit(2)
	check(not editor.copy_button.disabled and editor.copy_source.item_count == 1 and editor.copy_source.get_selected_metadata() == "passenger", "only other passenger services are offered")
	editor.name_field.text = "Copied Express"
	editor.copy_button.pressed.emit()
	check(editor.draft[key].stops == ["a", "b", "c"] and editor.draft[key].name == "Copied Express" and editor.heading.text.contains("A → B → C → B → A"), "copy updates editable sequence and keeps typed target name")
	check(game.services[key].stops == ["a", "b"] and game.money == money and game.fleet == fleet_before, "draft makes no live edits, purchases or assignments")
	editor.hide()
	editor.open_editor()
	check(editor.draft[key].stops == ["a", "b"], "close and reopen discards copied draft")
	editor.service_choice.item_selected.emit(2)
	editor.name_field.text = "Copied Express"
	editor.copy_button.pressed.emit()
	editor.confirmed.emit()
	check(editor.status.text.begins_with("Routes applied") and game.services[key].stops == ["a", "b", "c"] and game.services[key].waypoints == configuration.passenger.waypoints, "safe target applies all source instructions")
	check(game.train_position == source_position and game.route_distance == source_distance and game.passenger_services[key].position == target_position and game.money == money, "applying copy preserves both physical positions and balance")
	# Editing nested target data remains independent after commit and save/load.
	editor.draft[key].waypoints["a>b"][0][0] = 13
	check(game.services.passenger.waypoints["a>b"] == [[12, 8]] and game.services[key].waypoints["a>b"] == [[12, 8]], "post-apply draft edits cannot mutate live source or target")
	game._save_game()
	game._load_game()
	check(game.services[key].stops == ["a", "b", "c"] and game.passenger_services[key].position == target_position and game.train_position == source_position, "copied route and positions survive save/load")
	editor.open_editor()
	# Target now owns a three-stop route, while the source is still travelling.
	editor.service_choice.item_selected.emit(2)
	editor.stop_list.select(2)
	editor._remove_stop()
	check(editor.directive_warning.text.contains("B → C") and editor.draft[key].waypoints == {"a>b": [[12, 8]]}, "removing a leg explicitly warns and preserves unaffected leg waypoints")
	editor.service_choice.item_selected.emit(0)
	editor.copy_button.pressed.emit()
	var live_before: Dictionary = game.services.duplicate(true)
	editor.confirmed.emit()
	check(not editor.status.text.begins_with("Routes applied") and game.services == live_before and game.train_position == source_position, "copy onto a moving train is rejected atomically")
	editor.hide()
	editor.open_editor()
	editor.service_choice.item_selected.emit(1)
	check(not editor.copy_controls.visible, "freight does not offer passenger route copying")
	editor.hide()
	var original_scale: float = Settings.ui_scale
	Settings.ui_scale = 2.0
	game._apply_settings()
	editor.open_editor()
	await process_frame
	await process_frame
	check(Vector2(editor.size).y <= game.get_viewport_rect().size.y + 1 and Rect2(Vector2.ZERO, Vector2(editor.size)).encloses(editor.get_ok_button().get_global_rect()), "copy controls retain reachable Apply at 200%")
	editor.hide()
	Settings.ui_scale = original_scale
	game._apply_settings()
	game.queue_free()
	await process_frame
	print("Route copy: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
