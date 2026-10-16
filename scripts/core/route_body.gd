extends RefCounted
## Continuous vehicle poses on an open route or a smooth, closed circuit.
## A folded out-and-back curve is not a circuit, even if its endpoints coincide.
static func is_closed(path: Curve2D) -> bool:
	if path.point_count < 3: return false
	if path.get_point_position(0).distance_to(path.get_point_position(path.point_count - 1)) > 0.001: return false
	var total := path.get_baked_length()
	if total <= 2.0: return false
	var first := (path.sample_baked(1.0) - path.sample_baked(0.0)).normalized()
	var last := (path.sample_baked(total) - path.sample_baked(total - 1.0)).normalized()
	return first.dot(last) > 0.999

static func distance_on_path(path: Curve2D, distance: float, closed: Variant = null) -> float:
	if closed == null: closed = is_closed(path)
	return fposmod(distance, path.get_baked_length()) if closed else distance

static func pose(path: Curve2D, distance: float, closed: Variant = null) -> Transform2D:
	if closed == null: closed = is_closed(path)
	var total := path.get_baked_length()
	if closed:
		var wrapped := fposmod(distance, total)
		var loop_tangent := (path.sample_baked(fposmod(wrapped + 1.0, total)) - path.sample_baked(fposmod(wrapped - 1.0, total))).normalized()
		return Transform2D(loop_tangent, Vector2(-loop_tangent.y, loop_tangent.x), path.sample_baked(wrapped))
	var edge := clampf(distance, 0.0, total)
	var tangent := (path.sample_baked(minf(total, edge + 1.0)) - path.sample_baked(maxf(0.0, edge - 1.0))).normalized()
	return Transform2D(tangent, Vector2(-tangent.y, tangent.x), path.sample_baked(edge) + tangent * (distance - edge))


## Planned reversals ("folds"). A route such as A -> C -> B doubles back at C: the
## retained path runs out to C and then retraces. The train is a rigid formation
## that keeps its physical orientation (the locomotive propels on the return), so a
## vehicle's place on the route is not simply `distance + offset`:
##   * after an odd number of folds the offset is mirrored (`distance - offset`);
##   * a vehicle that would lie beyond the nearest fold sits on the straight
##     extension past that stop instead of on the retraced leg.
## Folds are detected lazily and cached on the path so every consumer (reservations,
## signals, drawing, hit-testing) shares one definition. Paths without folds
## behave exactly as before.
const FOLD_META := "folds"

## Returns [{distance, point, tangent}] where `tangent` is the arrival direction.
static func find_folds(path: Curve2D) -> Array:
	var result: Array = []
	var points := path.get_baked_points()
	var travelled := 0.0
	var previous := Vector2.ZERO
	var has_previous := false
	for i in range(1, points.size()):
		var step: Vector2 = points[i] - points[i - 1]
		var length := step.length()
		if length < 0.001: continue
		var direction := step / length
		if has_previous and direction.dot(previous) < -0.99:
			result.append({"distance": travelled, "point": points[i - 1], "tangent": previous})
		previous = direction
		has_previous = true
		travelled += length
	return result

## Cached on the path itself; recomputed if the path's length ever changes.
static func folds(path: Curve2D) -> Array:
	var length := path.get_baked_length()
	if path.has_meta(FOLD_META):
		var cached: Variant = path.get_meta(FOLD_META)
		if cached is Dictionary and absf(float(cached.length) - length) < 0.001: return cached.marks
	var marks := find_folds(path)
	path.set_meta(FOLD_META, {"length": length, "marks": marks})
	return marks

## Pose of the vehicle `offset` pixels from the centre of a train whose centre is
## at route `distance`. Equal to `pose(path, distance + offset)` without folds.
static func body_pose(path: Curve2D, distance: float, offset: float, closed: Variant = null) -> Transform2D:
	var marks := folds(path)
	if marks.is_empty(): return pose(path, distance + offset, closed)
	var passed := 0
	for mark in marks:
		if float(mark.distance) < distance: passed += 1
	var coordinate := distance + (-offset if passed % 2 == 1 else offset)
	if passed < marks.size() and coordinate > float(marks[passed].distance):
		return _extension(marks[passed], coordinate - float(marks[passed].distance), 1.0)
	if passed > 0 and coordinate < float(marks[passed - 1].distance):
		return _extension(marks[passed - 1], float(marks[passed - 1].distance) - coordinate, -1.0)
	return pose(path, coordinate, false)

# Straight continuation past a stop, along the direction the train arrived.
static func _extension(mark: Dictionary, beyond: float, facing: float) -> Transform2D:
	var tangent: Vector2 = mark.tangent
	return Transform2D(tangent * facing, Vector2(-tangent.y, tangent.x) * facing, mark.point + tangent * beyond)
