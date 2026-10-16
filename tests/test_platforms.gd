extends SceneTree
const Platforms = preload("res://scripts/core/platforms.gd")
const Consists = preload("res://scripts/core/consists.gd")
const Router = preload("res://scripts/rail_router.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	var tracks := {}
	for x in range(4, 21): tracks[Vector2i(x, 8)] = false
	var stop := Vector2i(4, 8)
	var platform := Platforms.measure(tracks, {}, stop, 32)
	check(platform.left == 0 and platform.right == 16 and platform.tiles == 17, "run is measured from the stop tile")
	check(Platforms.max_wagons(platform, 32) == 0, "a bare station tile fits only the locomotive")
	check(Platforms.fits(platform, 28.0, 32), "locomotive fits a one-tile platform")
	check(not Platforms.fits(platform, 60.0, 32), "one coach needs track behind the stop")
	tracks[Vector2i(3, 8)] = false
	platform = Platforms.measure(tracks, {}, stop, 32)
	check(Platforms.max_wagons(platform, 32) == 2, "one extension tile fits two vehicles")
	check(Platforms.longest_body(platform, 32) == 95.0, "longest body matches tile maths")
	tracks[Vector2i(2, 8)] = false
	platform = Platforms.measure(tracks, {}, stop, 32)
	check(Platforms.max_wagons(platform, 32) == 4, "two extension tiles fit the maximum consist")
	check(Platforms.describe(platform, 32).contains("4 vehicles"), "description names the limit")
	check(Platforms.measure(tracks, {Vector2i(3, 8): "stop"}, stop, 32).left == 0, "a signal ends the platform")
	tracks[Vector2i(3, 8)] = "junction_6_2_4"
	check(Platforms.measure(tracks, {}, stop, 32).left == 0, "a switch ends the platform")
	check(Platforms.measure({}, {}, stop, 32).tiles == 0 and not Platforms.fits(Platforms.measure({}, {}, stop, 32), 28.0, 32), "no track means no platform")
	check(Platforms.describe(Platforms.measure({}, {}, stop, 32), 32).contains("no straight"), "empty platform is explained")
	# The formal rule must agree with the physical stop-clearance check.
	for extension in range(0, 4):
		for ahead in range(0, 4):
			var line := {}
			var cells: Array[Vector2i] = []
			for x in range(4 - extension, 21 + ahead): line[Vector2i(x, 8)] = false
			for x in range(4, 21): cells.append(Vector2i(x, 8))
			var path := Router.make_path(cells, 32)
			var start := Platforms.measure(line, {}, Vector2i(4, 8), 32)
			var finish := Platforms.measure(line, {}, Vector2i(20, 8), 32)
			for count in range(Consists.MAX_WAGONS + 1):
				var wagons: Array = []
				wagons.resize(count)
				var body := Consists.length({"wagons": wagons})
				check(Consists.stop_clearance(path, 0.0, body, line, 32).is_empty() == Platforms.fits(start, body, 32), "start platform agrees with clearance (ext %d, %d vehicles)" % [extension, count])
				check(Consists.stop_clearance(path, path.get_baked_length(), body, line, 32).is_empty() == Platforms.fits(finish, body, 32), "end platform agrees with clearance (ahead %d, %d vehicles)" % [ahead, count])
	# Sidings on neighbouring rows become numbered platforms with stable IDs.
	var yard := {}
	for x in range(2, 21): yard[Vector2i(x, 8)] = false
	check(Platforms.for_station(yard, {}, "a", Vector2i(4, 8), 32).size() == 1, "a lone track is platform 1")
	for x in range(3, 12): yard[Vector2i(x, 9)] = false
	var two := Platforms.for_station(yard, {}, "a", Vector2i(4, 8), 32)
	check(two.size() == 2 and two[1].id == "a/2" and two[1].offset == 1 and two[1].cell == Vector2i(4, 9), "row below is platform 2")
	for x in range(4, 8): yard[Vector2i(x, 7)] = false
	var three := Platforms.for_station(yard, {}, "a", Vector2i(4, 8), 32)
	check(three.size() == 3 and three[2].id == "a/3" and three[2].offset == -1, "row above is platform 3")
	check(three[1].id == "a/2", "existing platform IDs do not renumber when another appears")
	yard.erase(Vector2i(4, 9))
	var gap := Platforms.for_station(yard, {}, "a", Vector2i(4, 8), 32)
	check(gap.size() == 2 and gap[1].id == "a/3", "a removed siding leaves the others' IDs unchanged")
	yard[Vector2i(4, 9)] = false
	var long_body := 92.0
	check(Platforms.assign(three, long_body, 32) == "a/1", "assignment prefers the lowest platform that fits")
	check(Platforms.assign(three, long_body, 32, {"a/1": true}) == "a/2", "an occupied platform is skipped")
	check(Platforms.assign(three, long_body, 32, {"a/1": true, "a/2": true}) == "", "a platform too short is never assigned")
	check(Platforms.assign(three, 28.0, 32, {"a/1": true, "a/2": true}) == "a/3", "the locomotive alone fits the short platform")
	check(Platforms.assign([], 28.0, 32) == "", "no platforms means no assignment")
	print("Platform tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
