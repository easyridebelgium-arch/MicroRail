extends SceneTree
## Switch and crossing geometry plus port-aware routing.
## Run: godot --headless --path . --script res://tests/test_junctions.gd

const Geometry = preload("res://scripts/track_geometry.gd")
const Router = preload("res://scripts/rail_router.gd")

const N := Vector2i(0, -1)
const NE := Vector2i(1, -1)
const E := Vector2i(1, 0)
const SE := Vector2i(1, 1)
const S := Vector2i(0, 1)
const SW := Vector2i(-1, 1)
const W := Vector2i(-1, 0)
const NW := Vector2i(-1, -1)

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_test_shapes()
	_test_moves()
	_test_crossing()
	_test_same_connections()
	_test_routing_switch()
	_test_routing_crossing()
	_test_simple_routing()
	_test_drawing()
	_test_variants()
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(value: bool, message: String) -> void:
	checks += 1

	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _v(items: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(items)
	return result


# West-to-east main line with a switch at (5,0): stem west, through east,
# branch south-east, continuing east along y = 1.
func _switch_network() -> Dictionary:
	var tracks: Dictionary = {}

	for x in range(0, 5):
		tracks[Vector2i(x, 0)] = false

	tracks[Vector2i(5, 0)] = "junction_6_2_3"

	for x in range(6, 11):
		tracks[Vector2i(x, 0)] = false

	tracks[Vector2i(6, 1)] = "rail_2_7"

	for x in range(7, 11):
		tracks[Vector2i(x, 1)] = false

	return tracks


func _test_shapes() -> void:
	check(Geometry.connections("junction_6_2_3") == _v([W, E, SE]), "switch ports are stem, through, branch in that order")
	check(Geometry.is_switch("junction_6_2_3") and Geometry.is_junction("junction_6_2_3"), "switch is recognised")
	check(not Geometry.is_switch("rail_2_7") and not Geometry.is_switch(false), "simple tiles are not switches")
	check(Geometry.connections("junction_0_4_1").is_empty(), "branch only 45 degrees from the stem is rejected")
	check(Geometry.connections("junction_0_4_4").is_empty(), "through and branch must differ")
	check(Geometry.connections("junction_0_0_4").is_empty(), "stem cannot equal an exit")
	check(Geometry.connections("junction_0_4_8").is_empty(), "port index above 7 is rejected")
	check(Geometry.connections("junction_0_4").is_empty(), "too few ports is rejected")
	check(Geometry.connections("junction_0_4_x").is_empty(), "non-numeric port is rejected")
	check(Geometry.connections("junction_00_4_3").is_empty(), "non-canonical number is rejected")
	check(Geometry.connections("cross_0_2") == _v([N, S, E, W]), "plus crossing ports")
	check(Geometry.connections("cross_1_3") == _v([NE, SW, SE, NW]), "diagonal crossing ports")
	check(Geometry.connections("cross_2_0").is_empty(), "crossing lines must be in ascending order")
	check(Geometry.connections("cross_0_4").is_empty(), "crossing line index above 3 is rejected")
	check(Geometry.connections("cross_1_1").is_empty(), "crossing needs two different lines")
	check(Geometry.switch_type(W, E, SE) == "junction_6_2_3", "switch_type builds the code")
	check(Geometry.switch_type(N, E, NE) == null, "switch_type rejects a hairpin branch")
	check(Geometry.crossing_type(N, E) == "cross_0_2", "crossing_type builds the code")
	check(Geometry.crossing_type(N, S) == null, "crossing_type rejects one line twice")
	check(Geometry.connections("rail_2_7").size() == 2 and Geometry.connections(true).size() == 2, "simple tiles still have two ports")


func _test_moves() -> void:
	var kind: String = "junction_6_2_3"
	check(Geometry.exits_from(kind, W) == _v([E, SE]), "from the stem a train may take either exit")
	check(Geometry.exits_from(kind, E) == _v([W]), "from the through exit only the stem is possible")
	check(Geometry.exits_from(kind, SE) == _v([W]), "from the branch exit only the stem is possible")
	check(Geometry.exits_from(kind, N).is_empty(), "a side without a port gives no moves")
	check(Geometry.exit_for(kind, W, 0) == E, "state 0 leads to the through exit")
	check(Geometry.exit_for(kind, W, 1) == SE, "state 1 leads to the branch")
	check(Geometry.exit_for(kind, E, 1) == W, "trailing moves ignore the switch state")
	check(Geometry.exit_for(kind, N, 0) == Vector2i.ZERO, "impossible move gives zero")
	check(Geometry.state_for(kind, W, E) == 0 and Geometry.state_for(kind, W, SE) == 1, "state_for maps exits to states")
	check(Geometry.state_for(kind, E, W) == -1, "trailing moves need no setting")
	check(Geometry.state_for(false, W, E) == -1, "simple tiles need no setting")
	check(Geometry.exits_from(false, W) == _v([E]), "simple tile passes straight through")


func _test_crossing() -> void:
	var kind: String = "cross_0_2"
	check(Geometry.exits_from(kind, N) == _v([S]), "crossing: north to south")
	check(Geometry.exits_from(kind, W) == _v([E]), "crossing: west to east")
	check(Geometry.exits_from(kind, NE).is_empty(), "crossing has no diagonal port")
	check(Geometry.exit_for(kind, S, 1) == N, "crossing ignores any state")
	check(Geometry.state_for(kind, N, S) == -1, "crossing needs no setting")


func _test_same_connections() -> void:
	check(Geometry.same_connections("junction_6_2_3", "junction_6_2_3"), "identical switches match")
	check(not Geometry.same_connections("junction_6_2_3", "junction_2_6_3"), "same ports with a different stem do not match")
	check(not Geometry.same_connections("junction_6_2_3", "junction_6_2_5"), "different branch does not match")
	check(not Geometry.same_connections("junction_6_2_3", false), "switch and straight do not match")
	check(Geometry.same_connections("cross_0_2", "cross_0_2") and not Geometry.same_connections("cross_0_2", "cross_1_3"), "crossings compare exactly")
	check(Geometry.same_connections(false, "rail_2_6"), "a straight and its rail code have the same ports")
	check(Geometry.same_connections("NE", "rail_0_2"), "equivalent simple tiles still match")


func _test_routing_switch() -> void:
	var tracks: Dictionary = _switch_network()

	var through: Dictionary = Router.find_path(tracks, Vector2i(0, 0), Vector2i(10, 0))
	check(through["cells"].size() == 11 and through["switches"] == {Vector2i(5, 0): 0}, "main line route sets the switch to through (got %s)" % str(through["switches"]))

	var branch: Dictionary = Router.find_path(tracks, Vector2i(0, 0), Vector2i(10, 1))
	check(not branch["cells"].is_empty(), "a route to the branch exists")
	check(branch["switches"] == {Vector2i(5, 0): 1}, "branch route sets the switch to branch")
	check(branch["cells"].has(Vector2i(6, 1)) and not branch["cells"].has(Vector2i(6, 0)), "branch route leaves the main line at the switch")

	check(Router.switch_settings(tracks, branch["cells"]) == {Vector2i(5, 0): 1}, "switch_settings reads the branch setting from route cells")
	check(Router.switch_settings(tracks, through["cells"]) == {Vector2i(5, 0): 0}, "switch_settings reads the through setting from route cells")

	var back: Dictionary = Router.find_path(tracks, Vector2i(10, 1), Vector2i(0, 0))
	check(not back["cells"].is_empty() and back["switches"].is_empty(), "trailing back through the points needs no setting")

	var exit_to_exit: Array[Vector2i] = Router.find_route(tracks, Vector2i(10, 0), Vector2i(10, 1))
	check(exit_to_exit.is_empty(), "no route from one exit to the other through the switch")

	check(Router.find_route(tracks, Vector2i(0, 0), Vector2i(10, 0)).size() == 11, "find_route still returns a cell list")
	check(Router.find_route(tracks, Vector2i(0, 0), Vector2i(0, 0)) == _v([Vector2i(0, 0)]), "start equals destination")
	check(Router.find_route(tracks, Vector2i(0, 0), Vector2i(50, 50)).is_empty(), "missing destination gives an empty route")

	# The route must not depend on any stored switch position.
	var again: Dictionary = Router.find_path(tracks, Vector2i(0, 0), Vector2i(10, 1))
	check(again["cells"] == branch["cells"], "planning is repeatable")


func _test_routing_crossing() -> void:
	var tracks: Dictionary = {}

	for x in range(0, 11):
		tracks[Vector2i(x, 0)] = false

	for y in range(-3, 4):
		tracks[Vector2i(5, y)] = true

	tracks[Vector2i(5, 0)] = "cross_0_2"

	var along: Array[Vector2i] = Router.find_route(tracks, Vector2i(0, 0), Vector2i(10, 0))
	check(along.size() == 11, "east-west line passes through the crossing")

	var across: Array[Vector2i] = Router.find_route(tracks, Vector2i(5, -3), Vector2i(5, 3))
	check(across.size() == 7, "north-south line passes through the crossing")

	var turn: Array[Vector2i] = Router.find_route(tracks, Vector2i(0, 0), Vector2i(5, 3))
	check(turn.is_empty(), "a train cannot change line on a crossing")


func _test_simple_routing() -> void:
	var tracks: Dictionary = {}

	for x in range(0, 6):
		tracks[Vector2i(x, 0)] = false

	check(Router.find_route(tracks, Vector2i(0, 0), Vector2i(5, 0)).size() == 6, "straight line route")
	check(Router.find_route(tracks, Vector2i(5, 0), Vector2i(0, 0)).size() == 6, "reverse straight line route")

	tracks[Vector2i(2, 0)] = true
	check(Router.find_route(tracks, Vector2i(0, 0), Vector2i(5, 0)).is_empty(), "mismatched edge breaks the route")


func _test_drawing() -> void:
	var simple: Dictionary = Geometry.drawing_data(false, 32.0)
	check(not simple.is_empty() and simple["extra"].is_empty(), "a simple tile has one rail path")
	var switch: Dictionary = Geometry.drawing_data("junction_6_2_3", 32.0)
	check(switch["extra"].size() == 1 and not switch["left"].is_empty() and not switch["extra"][0]["left"].is_empty(), "a switch draws two paths")
	var crossing: Dictionary = Geometry.drawing_data("cross_0_2", 32.0)
	check(crossing["extra"].size() == 1, "a crossing draws two lines")
	check(Geometry.drawing_data("junction_0_4_1", 32.0).is_empty(), "an invalid tile draws nothing")
	check(Geometry.drawing_pairs("junction_6_2_3") == [[W, E], [W, SE]], "switch pairs are stem-through and stem-branch")


func _test_variants() -> void:
	var horizontal: Array = Geometry.switch_variants(false)
	check(horizontal.size() == 8, "a straight has eight switch variants (got %d)" % horizontal.size())
	check(Geometry.switch_variants(true).size() == 8, "a vertical straight has eight variants")
	check(Geometry.switch_variants("NE").is_empty(), "a bend has no switch variants")

	var all_valid: bool = true
	var same_ports: bool = true

	for kind in horizontal:
		if Geometry.connections(kind).size() != 3:
			all_valid = false
		if not Geometry.same_connections(Geometry.straight_base(kind), false):
			same_ports = false

	check(all_valid, "every variant is a valid switch")
	check(same_ports, "every variant keeps the straight's stem and through ports")
	check(Geometry.is_straight(false) and Geometry.is_straight("rail_1_5") and not Geometry.is_straight("NE"), "is_straight")
	check(Geometry.straight_base("junction_6_2_3") != null and Geometry.same_connections(Geometry.straight_base("junction_6_2_3"), false), "a switch's base is its stem-through straight")
	check(Geometry.straight_base("cross_0_2") == null and Geometry.straight_base("NE") == null, "crossings and bends have no base")

	var tile: Variant = false
	var seen: Dictionary = {}

	for step in range(8):
		tile = Geometry.next_switch_variant(tile)
		check(Geometry.is_switch(tile) and not seen.has(tile), "step %d gives a new switch" % step)
		seen[tile] = true

	check(Geometry.same_connections(Geometry.next_switch_variant(tile), false) and not Geometry.is_switch(Geometry.next_switch_variant(tile)), "the ninth click returns to a straight")
	check(Geometry.next_switch_variant("NE") == null, "a bend cannot hold a switch")
	check(Geometry.next_switch_variant("cross_0_2") == null, "a crossing cannot hold a switch")
