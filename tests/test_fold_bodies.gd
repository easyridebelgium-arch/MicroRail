extends SceneTree
const RouteBody = preload("res://scripts/core/route_body.gd")
const Reservations = preload("res://scripts/core/track_reservations.gd")
const Consists = preload("res://scripts/core/consists.gd")
const Router = preload("res://scripts/rail_router.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func cells_of(ranges: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for run in ranges:
		var from: int = run[0]
		var to: int = run[1]
		var step := 1 if to >= from else -1
		for x in range(from, to + step, step):
			if cells.is_empty() or cells.back() != Vector2i(x, 8): cells.append(Vector2i(x, 8))
	return cells
# Same construction as ServiceRoutes.build: one path per leg, joined at the stop.
func route_path(legs: Array) -> Curve2D:
	var path := Curve2D.new()
	path.bake_interval = 1.0
	for leg in legs:
		var segment := Router.make_path(cells_of([leg]), 32)
		for i in range(segment.point_count):
			var point := segment.get_point_position(i)
			if path.point_count == 0 or path.get_point_position(path.point_count - 1).distance_to(point) > 0.001: path.add_point(point)
	return path
func _initialize() -> void:
	# A (4) -> C (20) -> B (12): the route doubles back at C.
	var cells := cells_of([[4, 20], [19, 12]])
	var path := route_path([[4, 20], [20, 12]])
	var marks := RouteBody.folds(path)
	check(marks.size() == 1, "one planned reversal is found")
	var fold: float = marks[0].distance
	check(absf(fold - 16.0 * 32.0) < 2.0, "the fold is at the centre of stop C (%.1f)" % fold)
	check(marks[0].tangent.x > 0.99, "arrival tangent points toward the end of the line")
	check(RouteBody.folds(route_path([[4, 20]])).is_empty(), "a straight route has no folds")
	check(RouteBody.folds(path) == marks, "folds are cached on the path")
	# Without folds nothing changes.
	var plain := route_path([[4, 20]])
	check(RouteBody.body_pose(plain, 100.0, 24.0).origin == RouteBody.pose(plain, 124.0).origin, "no-fold body pose equals the plain pose")
	# The formation stays rigid through the reversal: constant spacing, same
	# order, same line, for every centre position around the fold.
	var offsets := [48.0, 16.0, -16.0, -48.0]
	var rigid := true
	var ordered := true
	for step in range(-40, 41):
		var centre := fold + float(step) * 7.0
		var xs: Array[float] = []
		var ys: Array[float] = []
		for offset in offsets:
			var pose := RouteBody.body_pose(path, centre, offset)
			xs.append(pose.origin.x)
			ys.append(pose.origin.y)
		for i in range(1, offsets.size()):
			rigid = rigid and absf((xs[i - 1] - xs[i]) - 32.0) < 0.6 and absf(ys[i] - ys[0]) < 0.6
			ordered = ordered and xs[i - 1] > xs[i]
	check(rigid, "vehicles stay 32 px apart on one line across the reversal")
	check(ordered, "vehicle order never flips")
	var after := RouteBody.body_pose(path, fold + 10.0, 48.0)
	check(absf(after.origin.x - (656.0 + 38.0)) < 1.0, "just after the fold the east end sits on the extension past C (%.1f)" % after.origin.x)
	check(after.x.x < -0.99, "extension vehicles face the new direction of travel")
	var before := RouteBody.body_pose(path, fold - 10.0, 48.0)
	check(absf(before.origin.x - (656.0 - 10.0 + 48.0)) < 1.0 and before.x.x > 0.99, "before the fold the nose already stands on the extension")
	# The same body on the way back (distance decreasing) is identical.
	check(RouteBody.body_pose(path, fold + 33.0, -20.0).origin == RouteBody.body_pose(path, fold + 33.0, -20.0).origin, "poses depend only on position, not direction")
	# Reservations own the extension tiles.
	var table := Reservations.new()
	var body := table.footprint(path, fold + 40.0, 32, 124.0)
	check(body.has(Vector2i(21, 8)) and body.has(Vector2i(17, 8)), "ownership covers both sides of the retraced leg after the fold")
	check(table.footprint(path, fold + 40.0, 32, 28.0) == table.footprint(path, fold + 40.0, 32), "a single vehicle ignores folds")
	# Route shape rules.
	check(Consists.route_shape_error(path, cells, 124.0, "shuttle").is_empty(), "a simple planned reversal is allowed")
	var two := cells_of([[4, 20], [19, 10], [11, 30]])
	check(Consists.route_shape_error(route_path([[4, 20], [20, 10], [10, 30]]), two, 124.0, "shuttle").is_empty(), "two reversals far enough apart are allowed")
	var tight := cells_of([[4, 20], [19, 17], [18, 30]])
	check(Consists.route_shape_error(route_path([[4, 20], [20, 17], [17, 30]]), tight, 124.0, "shuttle").contains("train length"), "reversals closer than a train length are refused")
	check(Consists.route_shape_error(path, cells, 28.0, "shuttle").is_empty(), "single vehicles are never restricted")
	var crossing := cells_of([[4, 20]])
	crossing.append(Vector2i(20, 9))
	crossing.append(Vector2i(19, 9))
	crossing.append(Vector2i(19, 8))
	check(Consists.route_shape_error(route_path([[4, 20], [20, 20]]), crossing, 124.0, "shuttle").contains("revisit"), "revisiting track without a reversal stays refused")
	check(Consists.route_shape_error(path, cells, 124.0, "loop").contains("Loop"), "a folded route is never a Loop circuit")
	print("Fold bodies: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
