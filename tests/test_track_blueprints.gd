extends SceneTree
const Blueprints = preload("res://scripts/core/track_blueprints.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	var tracks: Dictionary = {}
	for x in range(10, 16): tracks[Vector2i(x, 15)] = false
	tracks[Vector2i(12, 15)] = "junction_6_2_4"
	var signs := {Vector2i(14, 15): "auto"}
	var safe := func(_cell: Vector2i) -> bool: return false
	var data := Blueprints.capture(tracks, signs, Vector2i(15, 15), Vector2i(10, 15), "Junction", safe)
	check(Blueprints.valid(data) and data.width == 6 and data.tiles.size() == 6, "capture must normalize reversed rectangle endpoints")
	check(data.signals.size() == 1 and data.tiles[2][2] == "junction_6_2_4", "capture must retain switch topology and signal mode")
	var proposal := Blueprints.place(data, Vector2i(30, 20), {}, {}, Vector2i(80, 50), safe)
	check(proposal.error.is_empty() and proposal.tracks.has(Vector2i(35, 20)), "placement must translate relative geometry to the chosen anchor")
	check(proposal.signals.get(Vector2i(34, 20)) == "auto", "signal positions must translate with geometry")
	check(not Blueprints.place(data, Vector2i(78, 20), {}, {}, Vector2i(80, 50), safe).error.is_empty(), "blueprint footprint must remain within map bounds")
	check(not Blueprints.place(data, Vector2i(30, 20), {Vector2i(30, 20): true}, {}, Vector2i(80, 50), safe).error.is_empty(), "incompatible overlapping track must be refused")
	check(Blueprints.place(data, Vector2i(30, 20), {Vector2i(32, 20): false}, {}, Vector2i(80, 50), safe).error.is_empty(), "a switch may extend a compatible existing straight without replacing its through line")
	check(not Blueprints.place(data, Vector2i(30, 20), {}, {Vector2i(34, 20): "stop"}, Vector2i(80, 50), safe).error.is_empty(), "placement must not silently change manual signal modes")
	var bad_version := data.duplicate(true)
	bad_version.version = "wrong"
	check(not Blueprints.valid(bad_version), "malformed version types must be rejected without a script error")
	check(Blueprints.capture(tracks, signs, Vector2i.ZERO, Vector2i(1000000, 1000000), "Too big", safe).is_empty(), "capture must bound oversized rectangles before scanning")
	var invalid := data.duplicate(true)
	invalid.tiles.append(invalid.tiles[0])
	check(not Blueprints.valid(invalid), "duplicate tiles must be rejected")
	invalid = data.duplicate(true)
	invalid.signals[0][0] = 2
	check(not Blueprints.valid(invalid), "signals on switches must be rejected")
	var path := "user://test_blueprints.json"
	check(Blueprints.save_library(path, [data]), "valid local library should save")
	var loaded := Blueprints.load_library(path)
	check(loaded.error.is_empty() and loaded.designs.size() == 1 and Blueprints.valid(loaded.designs[0]), "JSON roundtrip must retain validated geometry")
	var second := data.duplicate(true)
	second.name = "Second junction"
	check(Blueprints.save_library(path, [data, second]) and FileAccess.file_exists(path + ".backup"), "replacing a library must retain the prior file as backup")
	check(not Blueprints.save_library(path, [data, data]), "duplicate design names must not overwrite valid library")
	check(Blueprints.load_library(path).designs.size() == 2, "failed save must preserve current library")
	print("Track blueprints: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
