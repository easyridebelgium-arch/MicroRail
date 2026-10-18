extends SceneTree
const Advice = preload("res://scripts/core/first_connection_advice.gd")
const Path = preload("res://scripts/core/first_connection_path.gd")
const Generator = preload("res://scripts/core/world_generator.gd")
const Terrain = preload("res://scripts/core/river_terrain.gd")
const Router = preload("res://scripts/rail_router.gd")
const Plan = preload("res://scripts/core/construction_plan.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	var terrain := Terrain.new()
	var world: Dictionary = Generator.generate("42", 4).world
	var before := JSON.stringify(world)
	for profile in Terrain.PROFILES:
		terrain.profile = profile
		var result := Advice.recommend(world, terrain)
		check(not result.is_empty(), "constructible pair on " + profile)
		if result.is_empty(): continue
		check(not Router.find_route(result.tracks, result.a, result.b).is_empty(), "authoritative graph connects platforms")
		check(terrain.track_error(result.tracks).is_empty(), "complete legal bridge geometry")
		check(result.budget == result.station_cost + result.track_cost + 400, "whole startup price includes actual construction")
		check(Advice.describe(world, terrain, 5000).contains("Validated layout"), "guide labels witness")
		check(Advice.describe(world, terrain, 0).contains("below this layout"), "funds refresh independently of cached geometry")
		check(result == Advice.recommend(world, terrain), "deterministic repeated witness")
		result.tracks.clear()
		check(not Advice.recommend(world, terrain).tracks.is_empty(), "callers cannot mutate cached witness")
		check(JSON.stringify(world) == before, "advice preserves world")
	world.settlements[0].cell = [10, 9]
	world.settlements[1].cell = [10, 23]
	world.settlements[2].cell = [64, 9]
	world.settlements.resize(3)
	var a := Vector2i(10, 13)
	var b := Vector2i(10, 27)
	terrain.profile = "flat"
	var flat := Path.find(world, terrain, a, b)
	terrain.profile = "wide_river_v1"
	var wide := Path.find(world, terrain, a, b)
	check(not flat.is_empty() and not wide.is_empty(), "vertical station pair has real horizontal lead-outs")
	if not wide.is_empty() and not flat.is_empty():
		check(wide.track_cost == flat.track_cost + 120, "three water tiles use actual bridge surcharge")
		check(wide.station_cost == 600, "platform rails priced once")
		check(wide.cells[1].y == a.y and wide.cells[-2].y == b.y, "leave and enter platforms horizontally")
		var denied := {a: 99}
		check(Path.find(world, terrain, a, b, {}, {}, denied).is_empty(), "occupied proposed station prevents witness")
		var blocked := {a: "auto"}
		check(Path.find(world, terrain, a, b, {}, blocked).is_empty(), "signal in proposed footprint prevents witness")
		var reused := {Vector2i(8, 13): false}
		var cheaper := Path.find(world, terrain, a, b, reused)
		check(not cheaper.is_empty() and cheaper.station_cost == 590, "existing compatible platform rail reduces station quote")
	print("First connection advice: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
