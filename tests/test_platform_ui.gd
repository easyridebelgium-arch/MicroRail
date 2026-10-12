extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.paused = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
	game.station_panel.show()
	game.selected_station = Vector2i(4, 8)
	game._update_station_inspector()
	var text: String = game.station_details.text
	check(text.contains("Platform 1:") and text.contains("locomotive only"), "station panel shows the bare platform: " + text)
	game.tracks[Vector2i(3, 8)] = false
	game.tracks[Vector2i(2, 8)] = false
	game._update_station_inspector()
	check(game.station_details.text.contains("4 vehicles"), "laying straight track lengthens the platform immediately")
	game.track_signals[Vector2i(3, 8)] = "stop"
	game._update_station_inspector()
	check(game.station_details.text.contains("locomotive only"), "a signal shortens the platform")
	check(not game.station_details.text.contains("Platform 2:"), "no second platform without a siding")
	for x in range(3, 9): game.tracks[Vector2i(x, 9)] = false
	game._update_station_inspector()
	check(game.station_details.text.contains("Platform 2:"), "a parallel siding appears as platform 2")
	print("Platform UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
