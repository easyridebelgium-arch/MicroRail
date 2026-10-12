extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	# Use a desktop window size; headless defaults to 64x64.
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.paused = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var browser = game.object_browser
	browser.open_dialog()
	check(browser.rows.size() == 9 and game._modal_open(), "browser must include two trains, two services, three stations and two industries and own game input")
	var keys: Dictionary = {}
	for row in browser.rows: keys[row.key] = true
	check(keys.size() == browser.rows.size(), "entity keys must be unique across object types")
	browser.search.text = "#1"
	browser.search.text_changed.emit("#1")
	check(browser.rows.size() == 2, "permanent train ID search must find both train and assigned service")
	browser.kind.select(1)
	browser.refresh()
	check(browser.rows.size() == 1 and browser.rows[0].key == "train:1", "type filter must distinguish trains from services")
	browser.toggle_pin()
	check(game.object_pins.has("train:1") and browser.items.get_item_text(0).begins_with("★"), "pinning must use a textual mark and permanent object key")
	game.fleet.trains[0].name = "Renamed shuttle"
	browser.search.clear()
	browser.pinned_only.button_pressed = true
	check(browser.rows.size() == 1 and browser.rows[0].title.contains("Renamed shuttle"), "watchlist must retain renamed trains without relying on names")
	game.train_position = Vector2(288, 272)
	browser.locate()
	check(not browser.visible and game.camera.position == game.train_position, "locating must use current position rather than train origin")
	check(game.inspection_panel.routes and game.inspection_panel.selected_service == "passenger" and game.inspection_panel.route_toggle.button_pressed, "locating a running train must highlight its service and synchronize overlay controls")
	browser.open_dialog()
	browser.toggle_pin()
	check(browser.rows.is_empty() and browser.get_ok_button().disabled, "unpinning in pinned-only mode must safely leave an empty result")
	browser.pinned_only.button_pressed = false
	browser.kind.select(4)
	browser.search.text = "LOGS"
	browser.refresh()
	check(browser.rows.size() == 2, "industry search must match cargo descriptions case insensitively")
	browser.search.text = "Terminal"
	browser.refresh()
	browser.locate()
	check(game.camera.position == game._cell_center(game.CARGO_TERMINAL), "industry locate must jump to the correct facility")
	browser.open_dialog()
	game.fleet.trains.append(game.Fleet.make_train(3, "passenger_standard"))
	game.fleet.next_id = 4
	browser.kind.select(1)
	browser.search.text = "#3"
	browser.refresh()
	check(browser.rows.size() == 1 and browser.get_ok_button().disabled and browser.rows[0].details.contains("Stored off-map"), "stored trains must be searchable with locate disabled and storage explained")
	browser.toggle_pin()
	check(game.object_pins.has("train:3"), "stored train must be pinnable by ID")
	browser.hide()
	var Settings = game.GameSettings
	Settings.ui_scale = 2.0
	game._apply_settings()
	browser.open_dialog()
	await process_frame
	await process_frame
	check(float(browser.size.y) <= game.get_viewport_rect().size.y + 1.0, "browser must fit the logical viewport at 200% UI scale")
	check(Rect2(Vector2.ZERO, Vector2(browser.size)).encloses(browser.get_ok_button().get_global_rect()), "locate must remain accessible at 200% UI scale")
	browser.hide()
	Settings.ui_scale = 1.0
	game._apply_settings()
	game._save_game()
	game._load_game()
	check(game.object_pins.is_empty(), "loading must clear session pins to avoid referring to another run's reused IDs")
	game.queue_free()
	await process_frame
	print("Object browser: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
