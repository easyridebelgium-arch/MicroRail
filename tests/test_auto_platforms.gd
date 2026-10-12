extends SceneTree
const Geometry = preload("res://scripts/track_geometry.gd")
const Platforms = preload("res://scripts/core/platforms.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: _run.call_deferred()
func _plat(number: int, left: int, right: int) -> Dictionary:
	return {"number": number, "id": "b/%d" % number, "left": left, "right": right, "tiles": left + right + 1, "cell": Vector2i(20, 8)}
func _run() -> void:
	var all := func(_n: int) -> bool: return true
	var list := [_plat(1, 3, 3), _plat(2, 3, 3), _plat(3, 0, 0)]
	check(Platforms.choose(list, 28.0, 32.0, {}, all) == 1, "free platform 1 is preferred")
	check(Platforms.choose(list, 28.0, 32.0, {"b/1": true}, all) == 2, "a busy platform is skipped for a free one")
	check(Platforms.choose(list, 28.0, 32.0, {"b/1": true, "b/2": true, "b/3": true}, all) == 1, "when all are busy a shared platform is used")
	check(Platforms.choose([_plat(1, 0, 0), _plat(2, 4, 4)], 156.0, 32.0, {}, all) == 2, "a too-short platform is skipped")
	check(Platforms.choose(list, 28.0, 32.0, {"b/1": true}, func(n: int) -> bool: return n != 2) == 3, "an unroutable siding is skipped")
	check(Platforms.choose([], 28.0, 32.0, {}, all) == 0, "no platforms gives 0")

	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	for x in range(4, 22): game.tracks[Vector2i(x, 8)] = false
	game.tracks[Vector2i(15, 8)] = "junction_6_2_3"
	game.tracks[Vector2i(16, 9)] = Geometry.from_ports(Vector2i(-1, -1), Vector2i(1, 0))
	for x in range(17, 21): game.tracks[Vector2i(x, 9)] = false
	game._check_route()
	check(Platforms.label_for_cell(game.tracks, game.track_signals, Vector2i(20, 9), 32.0) == "Station B platform 2", "siding cell is named")
	check(Platforms.label_for_cell(game.tracks, game.track_signals, Vector2i(20, 8), 32.0) == "Station B platform 1", "main cell is named")
	check(Platforms.label_for_cell(game.tracks, game.track_signals, Vector2i(10, 8), 32.0) == "", "open line is not a platform")

	var solo: Dictionary = game.services.duplicate(true)
	solo.passenger["platforms"] = {"b": 0}
	var resolved: Dictionary = game._resolve_auto_platforms(solo)
	check(resolved.configuration.passenger.platforms == {}, "alone, Auto takes platform 1")
	var busy_cfg: Dictionary = game.services.duplicate(true)
	busy_cfg.passenger["platforms"] = {"b": 0}
	busy_cfg["passenger_2"] = {"name": "Other", "stops": ["a", "b"], "mode": "shuttle", "waypoints": {}, "platforms": {}}
	resolved = game._resolve_auto_platforms(busy_cfg)
	check(resolved.configuration.passenger.platforms == {"b": 2}, "Auto avoids the platform another service uses: %s" % str(resolved.configuration.passenger.platforms))
	var first: Dictionary = game.services.duplicate(true)
	first.passenger["platforms"] = {"a": 0}
	check(game._resolve_auto_platforms(first).configuration.passenger.platforms == {}, "first-stop Auto stays on the current platform")
	game.tracks.erase(Vector2i(18, 9))
	resolved = game._resolve_auto_platforms(busy_cfg)
	check(resolved.configuration.passenger.platforms == {}, "a disconnected siding falls back to shared platform 1")
	game.tracks[Vector2i(18, 9)] = false
	var apply_cfg: Dictionary = game.services.duplicate(true)
	apply_cfg.passenger["platforms"] = {"b": 0}
	var applied: String = game.apply_service_routes(apply_cfg)
	check(applied.begins_with("Routes applied") and not game.services.passenger.platforms.has("b"), "applying Auto stores a concrete choice: " + applied)
	game.queue_free()
	await process_frame
	print("Auto platforms: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
