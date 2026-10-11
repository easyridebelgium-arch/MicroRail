extends SceneTree
const Settings = preload("res://scripts/core/game_settings.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.paused = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	game.route_distance = 256.0
	game._update_train_transform()
	game._rebuild_reservations()
	var panel = game.inspection_panel
	check(not panel.visible and not panel.routes and not panel.blocks, "inspection must start collapsed with overlays disabled")
	panel.show()
	panel.routes = true
	panel.blocks = true
	game.reservation_overlay = true
	check(not game._management_window_is_open(), "inspection must not be a modal management window")
	var before: Dictionary = game._saved_runtime_routes().duplicate(true)
	var owners: Dictionary = game.reservations.owners.duplicate()
	var money: int = game.money
	var events: Dictionary = game.event_log.save_state().duplicate(true)
	for i in range(5):
		game._update_inspection()
		await process_frame
	check(game._saved_runtime_routes() == before and game.reservations.owners == owners, "rendering overlays must preserve runtime geometry and authority")
	check(game.money == money and game.event_log.save_state() == events, "inspection must not alter finances or emit events")
	check(panel.selector.item_count == 3, "selector must include all services and the two original trains")
	panel.selected_service = "freight"
	game.services.freight.name = "Renamed timber"
	game._update_inspection()
	check(panel.selected_service == "freight" and panel.selector.get_item_text(2).contains("Renamed"), "renaming must refresh labels without losing selected service")
	game.is_dragging = true
	game.demolition_mode = true
	game.demolition_cells = {Vector2i(6, 8): true}
	game._update_inspection()
	check(game.construction_feedback.affected[0].effect.begins_with("Current leg clear"), "demolition behind should explain later-leg damage")
	game.demolition_cells = {Vector2i(18, 8): true}
	game._update_inspection()
	check(panel.summary.text.contains("Breaks current leg"), "preview details should identify the current leg break")
	game._update_instructions()
	check(game.instructions.text.contains("Affects 1 services"), "header must give feedback even when inspection is collapsed")
	game.demolition_cells.clear()
	game.demolition_last_cell = Vector2i(12, 8)
	game._collect_demolition_cells(Vector2i(12, 8))
	game._update_inspection()
	check(game.construction_feedback.blocked.has(Vector2i(12, 8)), "dragging over protected occupied track must explain why it cannot be removed")
	check(not game.demolition_cells.has(Vector2i(12, 8)), "inspection must preserve existing demolition safety")
	game.is_dragging = false
	game._update_inspection()
	check(game.construction_feedback.affected.is_empty(), "ending a gesture must clear its impact report")
	game.tracks.erase(Vector2i(18, 8))
	game._check_route()
	check(game.inspection_trains()[0].cells.has(Vector2i(18, 8)), "inspection must keep showing missing tiles on retained routes")
	game.is_dragging = true
	game.demolition_mode = false
	game.build_plan = {"changes": {Vector2i(18, 8): false}}
	game._update_inspection()
	check(game.construction_feedback.affected[0].effect == "Restores current leg", "build preview should describe repair of a stopped train's route")
	panel.selected_service = "deleted_service"
	game._update_inspection()
	# Trigger a service-list refresh as a withdrawal or load would do.
	game.services.freight.name = "Timber"
	game._update_inspection()
	check(panel.selected_service.is_empty(), "a deleted service must safely fall back to all services")
	var old_scale: float = Settings.ui_scale
	for scale in [1.0, 2.0]:
		Settings.ui_scale = scale
		game._apply_settings()
		await process_frame
		await process_frame
		game._layout_header()
		var rect: Rect2 = panel.get_global_rect()
		check(Rect2(Vector2.ZERO, game.get_viewport_rect().size).encloses(rect), "inspection must fit viewport at %d%% scale (rect %s view %s)" % [scale * 100, rect, game.get_viewport_rect().size])
	Settings.ui_scale = old_scale
	game._apply_settings()
	game.is_dragging = false
	game.money = 10000
	game.tracks[Vector2i(18, 8)] = false
	game._check_route()
	var purchase: Dictionary = game.buy_fleet_train("passenger_standard")
	game.start_passenger_service(purchase.id, "b")
	game._update_inspection()
	check(game.inspection_trains().size() == 3 and panel.selector.item_count == 4, "new independent services must appear automatically")
	var key: String = "passenger_%d" % purchase.id
	panel.selected_service = key
	game.passenger_services[key].enabled = false
	game.remove_passenger_service(purchase.id)
	game._update_inspection()
	check(panel.selected_service.is_empty(), "removing the selected service must refresh the filter")
	game.queue_free()
	await process_frame
	var pair: Array = []
	for index in range(2):
		var running = load("res://scenes/main/main.tscn").instantiate()
		running.paused = true
		root.add_child(running)
		await process_frame
		running.set_process(false)
		for x in range(4, 21): running.tracks[Vector2i(x, 8)] = false
		for x in range(8, 29): running.tracks[Vector2i(x, 24)] = false
		running._check_route()
		running.sim_rng.set_seed(42)
		running.scenario_goals.current_index = running.ScenarioGoals.OBJECTIVES.size()
		pair.append(running)
	pair[1].inspection_panel.show()
	pair[1].inspection_panel.routes = true
	pair[1].inspection_panel.blocks = true
	pair[1].reservation_overlay = true
	for step in range(300):
		for running in pair:
			running.sim_clock.begin_tick()
			running._simulation_step(1.0 / 60.0)
		pair[1]._update_inspection()
	check(pair[0].route_distance > 0.0 and pair[0].route_distance == pair[1].route_distance, "moving trains must travel identically with all overlays enabled")
	check(pair[0].reservations.owners == pair[1].reservations.owners, "inspection must not change moving-train grants")
	check(pair[0].sim_rng.save_state() == pair[1].sim_rng.save_state() and pair[0].event_log.save_state() == pair[1].event_log.save_state(), "inspection must preserve seeded RNG and simulation events")
	check(pair[0].money == pair[1].money and pair[0].freight_train.save_state() == pair[1].freight_train.save_state(), "overlay use must preserve freight and financial simulation")
	for running in pair: running.queue_free()
	await process_frame
	print("Inspection integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
