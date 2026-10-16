extends SceneTree
const Summary = preload("res://scripts/core/network_summary.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func problem(key: String, cause: String, seconds: float = 0) -> Dictionary:
	return {"key": key, "cause": cause, "wait_seconds": seconds, "title": key, "severity": "Urgent" if cause == "deadlock" else "Info" if cause == "hold" else "Warning", "id": 1, "details": "Evidence", "cell": Vector2i(-1, -1)}
func keys(rows: Array) -> Array:
	var result: Array = []
	for row in rows: result.append(row.key)
	return result
func select_key(dialog: Node, key: String) -> bool:
	for index in range(dialog.rows.size()):
		if dialog.rows[index].key == key:
			dialog.items.select(index)
			dialog.describe()
			return true
	return false
func run() -> void:
	var data := {"problems": [problem("train:1", "wait", 4.9), problem("train:2", "wait", 5), problem("train:3", "wait", 12), problem("train:4", "hold"), problem("train:5", "incomplete"), problem("train:6", "deadlock"), problem("company:loan", "loan")], "stations": [{"id": "a", "name": "A", "cell": Vector2i(4, 8), "waiting": 16, "capacity": 20, "reachable": true}, {"id": "b", "name": "B", "cell": Vector2i(20, 8), "waiting": 10, "capacity": 20, "reachable": false}, {"id": "c", "name": "C", "cell": Vector2i(36, 8), "waiting": 15, "capacity": 20, "reachable": true}], "cities": [{"id": "town:1", "name": "Town 1", "cell": Vector2i(10, 10), "served": false, "population": 800}, {"id": "town:2", "name": "Town 2", "cell": Vector2i(30, 30), "served": true, "population": 900}], "vehicles": [{"id": 1, "name": "Shuttle", "service": "passenger", "left": 3}]}
	var before := data.duplicate(true)
	var rows := Summary.build(data)
	var ordered := keys(rows)
	check(data == before, "summary never mutates measurement input")
	check(not ordered.has("train:1") and ordered.has("train:2"), "five-second traffic threshold excludes brief waits, includes boundary")
	check(ordered[0] == "train:6" and ordered.find("train:5") < ordered.find("train:3"), "deadlock and incomplete routes precede traffic waits")
	check(ordered.find("train:3") < ordered.find("train:2"), "longer continuous wait leads within its category")
	check(ordered.has("queue:a") and not ordered.has("queue:c"), "queue threshold includes 80%, excludes lower fill")
	check(ordered.has("unserved:b") and not ordered.has("queue:b"), "unserved station gets one actionable queue entry")
	check(ordered.back() == "opportunity:town:1" and not ordered.has("opportunity:town:2"), "only unserved cities are expansion opportunities after operational issues")
	check(ordered.has("capacity:1") and rows[ordered.find("capacity:1")].details.contains("A person may be counted repeatedly"), "capacity entry identifies opportunity counting limits")
	check(rows[ordered.find("company:loan")].action == "bank" and rows[ordered.find("train:5")].action == "inspect", "issues route to the relevant control")
	for collection in ["problems", "stations", "cities", "vehicles"]:
		data[collection].reverse()
		check(keys(Summary.build(data)) == ordered, "stable ranking ignores %s insertion order" % collection)
	check(Summary.build({"problems": [], "stations": [], "cities": [], "vehicles": []}).is_empty(), "empty network has no fabricated safety score or issue")
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	game.paused = true
	for x in range(4, 37): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	game.passenger_held = true
	var snapshot := JSON.stringify(game._save_snapshot(), "", true, true)
	game.open_network_summary()
	check(game.network_summary.visible and game._modal_open() and game.paused, "summary pauses and owns input")
	check(snapshot == JSON.stringify(game._save_snapshot(), "", true, true), "opening and deriving summary leaves complete save/RNG/commands unchanged")
	check(game.network_summary.headline.text.contains("Company lifetime") and game.network_summary.headline.text.contains("operating contribution"), "headline labels financial and delivery scope")
	check(select_key(game.network_summary, "train:1"), "intentional hold remains reviewable")
	game.network_summary.act()
	check(game.train_inspector.visible and not game.network_summary.visible, "train action opens operating inspector")
	game.train_inspector.hide()
	game.open_network_summary()
	select_key(game.network_summary, "train:1")
	var position: Vector2 = game.train_position
	game.network_summary.locate()
	check(not game.network_summary.visible and game.camera.position == position and game.train_position == position, "locate changes camera without moving train")
	game.open_network_summary()
	select_key(game.network_summary, "unserved:a")
	game.network_summary.act()
	check(game.station_panel.visible and game.selected_station == game.STATION_A, "station advice opens the actual station inspector")
	game._close_station_inspector()
	# Recent left-behind evidence routes to a service card, not a compulsory purchase.
	game.passenger_occupancy.boarding(game.sim_clock.tick, 1, "a", 0, 2, 20, 20)
	game.open_network_summary()
	check(select_key(game.network_summary, "capacity:1"), "live recent capacity evidence appears")
	game.network_summary.act()
	check(game.service_cards.visible and game.service_cards.selected == "passenger", "capacity action opens correct service card")
	game.service_cards.hide()
	game.loans.state.due_principal = 100
	game.open_network_summary()
	check(select_key(game.network_summary, "company:loan") and game.network_summary.get_ok_button().disabled, "overdue bank row has no fabricated map location")
	game.network_summary.act()
	check(game.loans_dialog.visible and not game.network_summary.visible, "overdue action opens Bank")
	game.loans_dialog.hide()
	game.loans.state.due_principal = 0
	game.header_controls.open_accounts()
	game.header_controls.network_button.pressed.emit()
	check(game.network_summary.visible and not game.header_controls.accounts_dialog.visible, "Accounts action opens summary and releases exclusive accounts window")
	game.network_summary.hide()
	game.GameSettings.ui_scale = 2.0
	game._apply_settings()
	game.open_network_summary()
	for frame in range(4): await process_frame
	check(float(game.network_summary.size.y) <= game.get_viewport_rect().size.y and Rect2(Vector2.ZERO, Vector2(game.network_summary.size)).encloses(game.network_summary.get_ok_button().get_global_rect()), "summary and footer fit 200% viewport")
	game._reset_track_tools()
	check(not game.network_summary.visible, "right-click tool reset closes summary with other management windows")
	game.GameSettings.ui_scale = 1.0
	game._apply_settings()
	game.queue_free()
	await process_frame
	var city = load("res://scenes/dev/city_preview.tscn").instantiate()
	city.startup_allow_cli = false
	root.add_child(city)
	city.set_process(false)
	city.open_network_summary()
	check(city.network_summary.rows.size() == 4 and city.network_summary.rows[0].severity == "Opportunity", "fresh city world shows expansion opportunities rather than startup failures")
	var chosen: Dictionary = city.network_summary.rows[0]
	city.network_summary.items.select(0)
	city.network_summary.act()
	check(city.object_browser.visible and city.object_browser.selected_key() == chosen.object_key, "city opportunity opens exact city's report")
	city.object_browser.hide()
	city.queue_free()
	await process_frame
	print("Network summary: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
