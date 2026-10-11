extends SceneTree
const WaypointRouter = preload("res://scripts/waypoint_router.gd")
const Router = preload("res://scripts/rail_router.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const Services = preload("res://scripts/service_routes.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	var tracks: Dictionary = {}
	for x in range(4, 21): tracks[Vector2i(x, 8)] = false
	tracks[Vector2i(8, 8)] = "junction_6_2_4"
	tracks[Vector2i(16, 8)] = "junction_2_6_4"
	for y in range(9, 11):
		tracks[Vector2i(8, y)] = true
		tracks[Vector2i(16, y)] = true
	tracks[Vector2i(8, 11)] = Geometry.from_ports(Vector2i.UP, Vector2i.RIGHT)
	tracks[Vector2i(16, 11)] = Geometry.from_ports(Vector2i.UP, Vector2i.LEFT)
	for x in range(9, 16): tracks[Vector2i(x, 11)] = false
	var normal := Router.find_route(tracks, Vector2i(4, 8), Vector2i(20, 8))
	check(WaypointRouter.find_route(tracks, Vector2i(4, 8), Vector2i(20, 8), []) == normal, "no directives retains existing shortest path")
	var detour := WaypointRouter.find_route(tracks, Vector2i(4, 8), Vector2i(20, 8), [[12, 11], [14, 11]])
	check(detour.size() > normal.size() and detour.has(Vector2i(12, 11)) and detour.has(Vector2i(14, 11)), "ordered directives force bypass through selected branch")
	check(Services.waypoints_in_order(detour, [[12, 11], [14, 11]]), "waypoints visited in exact order")
	check(WaypointRouter.find_route(tracks, Vector2i(4, 8), Vector2i(20, 8), [[12, 40]]).is_empty(), "missing waypoint track gives no route")
	var trap := {Vector2i(5, 5): "junction_6_2_4", Vector2i(6, 5): false, Vector2i(5, 6): true}
	check(WaypointRouter.find_route(trap, Vector2i(6, 5), Vector2i(5, 6), [[5, 5]]).is_empty(), "waypoint cannot forget entry port and jump between switch branches")
	trap = {Vector2i(5, 5): "cross_0_2", Vector2i(4, 5): false, Vector2i(5, 6): true}
	check(WaypointRouter.find_route(trap, Vector2i(4, 5), Vector2i(5, 6), [[5, 5]]).is_empty(), "crossing waypoint cannot turn between crossing lines")
	var configuration := Services.defaults()
	configuration.passenger.waypoints = {"a>b": [[12, 11]]}
	check(Services.is_valid(configuration), "valid directive configuration accepted")
	var built := Services.build(tracks, ["a", "b"], 32, configuration.passenger.waypoints)
	check(built.distances.size() == 2 and built.cells.has(Vector2i(12, 11)), "pass-through points do not create stopping distances")
	for points in [[[12, 11], [12, 11]], [[80, 10]], [[4, 8]], [[1.5, 11]], [[12, "bad"]]]:
		configuration.passenger.waypoints = {"a>b": points}
		check(not Services.is_valid(configuration), "invalid/duplicate/platform coordinates rejected")
	configuration.passenger.waypoints = {"b>c": [[12, 11]]}
	check(not Services.is_valid(configuration), "directive for absent leg rejected")
	print("Waypoint routing: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
