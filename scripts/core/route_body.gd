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
