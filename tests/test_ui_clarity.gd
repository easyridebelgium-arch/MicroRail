extends SceneTree
## Presentation must remain readable and must not change physical authority.
const Settings = preload("res://scripts/core/game_settings.gd")
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	var header = game.header_controls
	check(game.save_button.get_index() + 1 == game.load_button.get_index(), "Save and Load remain adjacent")
	check(game.pause_button.get_index() + 1 == game.speed_selector.get_index(), "Pause and Speed remain adjacent")
	check(game.waypoint_button.get_index() < game.pause_button.get_index() and game.traffic_button.get_index() < game.inspect_button.get_index(), "construction, operations and inspection have distinct ordered groups")
	check(header.separators.size() == 3, "four toolbar groups have visual boundaries")
	check(game.clock_label.get_parent() == header.status_bar, "clock belongs to status bar rather than action ribbon")
	var tick_before: int = game.sim_clock.tick
	var position_before: Vector2 = game.train_position
	var authority_before: Dictionary = game.reservations.owners.duplicate()
	game.passengers_delivered = 10
	game.freight_income = 20
	game.total_operating_cost = 5
	game.freight_operating_cost = 3
	game.total_construction_cost = 1234
	game._update_instructions()
	check(header.profit.text == "Operating profit £62", "operating profit uses all service revenue/running costs and excludes construction")
	check(header.deliveries.text.contains("10 passengers"), "deliveries are live")
	check(not game.instructions.text.contains("Fares:") and not game.instructions.text.contains("Waiting: A"), "detailed accounts no longer consume map space")
	game.paused = false
	header.accounts_button.pressed.emit()
	check(game.paused and game._modal_open(), "Accounts pauses and suppresses gameplay input")
	check(header.accounts_text.text.contains("£1234") and header.accounts_text.text.contains("Passengers waiting:"), "Accounts exposes spend and queue details")
	check(game.sim_clock.tick == tick_before and game.train_position == position_before and game.reservations.owners == authority_before, "viewing Accounts does not advance or rebuild train authority")
	header.accounts_dialog.hide()
	for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	game.route_distance = 100
	game.train_needs_boarding = false
	game._update_train_transform()
	game.freight_train.route_cells = game.route_cells.duplicate()
	game.freight_train.route_path = game.route_path
	game.freight_train.distance_along_route = 240
	game.freight_train.held = true
	game.freight_train._update_transform()
	for step in range(120):
		game.sim_clock.begin_tick()
		game._simulation_step(1.0 / 60.0)
	game.inspect_train(1)
	var inspector = game.train_inspector
	check(inspector.data.blocker == 2 and inspector.summary.text.contains("Log Hauler"), "current blocker name is visible before technical details")
	check(not inspector.authority.visible and not inspector.details_toggle.button_pressed, "reservation detail starts collapsed")
	var before: Dictionary = game.reservations.owners.duplicate()
	inspector.details_toggle.button_pressed = true
	check(inspector.authority.visible and inspector.details_toggle.text.begins_with("Hide"), "detail toggle reveals actual authority")
	check(game.reservations.owners == before, "expanding details cannot change allocations")
	check(not inspector.buttons.inspect_blocker.disabled, "known blocker can be inspected directly")
	inspector.buttons.inspect_blocker.pressed.emit()
	check(inspector.selected_id == 2 and inspector.data.state == "Dispatcher hold", "blocker button opens that train's current inspector")
	check(game.reservations.owners == before, "blocker inspection preserves allocations")
	inspector.hide()
	var old_scale: float = Settings.ui_scale
	for scale_value in [1.0, 1.5, 2.0]:
		Settings.ui_scale = scale_value
		game._apply_settings()
		await process_frame
		await process_frame
		game._layout_header()
		check(game.header_background.size.y <= game.get_viewport_rect().size.y * 0.8, "grouped header leaves at least 20%% map space at %s%%" % (scale_value * 100))
		var bounds := Rect2(Vector2.ZERO, header.status_bar.size).grow(1)
		for child in header.status_bar.get_children():
			check(bounds.encloses(Rect2(child.position, child.size)), "status item remains inside wrapping bar")
		header.open_accounts()
		await process_frame
		await process_frame
		check(float(header.accounts_dialog.size.y) <= game.get_viewport_rect().size.y + 1, "Accounts fits at %s%%" % (scale_value * 100))
		check(Rect2(Vector2.ZERO, Vector2(header.accounts_dialog.size)).encloses(header.accounts_dialog.get_ok_button().get_global_rect()), "Accounts Close remains accessible")
		header.accounts_dialog.hide()
	Settings.ui_scale = old_scale
	game._apply_settings()
	game.queue_free()
	await process_frame
	print("UI clarity: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
