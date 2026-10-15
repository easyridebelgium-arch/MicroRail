extends RefCounted
## Presentation only. Pixels never define tracks, train length or building grounds.
const VEHICLE_ROOT := "res://assets/vehicles/sprites/"
const FACILITY_ROOT := "res://assets/world/facilities/sprites/"
const VEHICLES := ["passenger_standard", "passenger_fast", "freight_standard", "freight_heavy", "coach_standard", "coach_fast", "log_wagon_loaded"]
const FACILITIES := ["station_small", "station_large", "platform", "terminal", "sawmill", "factory", "forest"]
static var _textures: Dictionary = {}

static func texture(id: String) -> Texture2D:
	if not _textures.has(id):
		var directory := VEHICLE_ROOT if id in VEHICLES else FACILITY_ROOT
		_textures[id] = load(directory + id + ".tres")
	return _textures[id]

static func fitted_rect(id: String, bounds: Rect2) -> Rect2:
	var size: Vector2 = texture(id).get_size()
	var factor := minf(bounds.size.x / size.x, bounds.size.y / size.y)
	var fitted := size * factor
	return Rect2(bounds.get_center() - fitted * 0.5, fitted)

static func draw_fitted(canvas: CanvasItem, id: String, bounds: Rect2) -> void:
	canvas.draw_texture_rect(texture(id), fitted_rect(id, bounds), false)

## The supplied vehicle noses face north. Callers add PI/2 to the existing
## positive-X train heading, without changing the simulation's heading or pose.
static func draw_vehicle(canvas: CanvasItem, id: String, high_contrast: bool) -> void:
	draw_fitted(canvas, id, Rect2(-7, -14, 14, 28))
	if high_contrast:
		canvas.draw_rect(Rect2(-7, -14, 14, 28), Color.WHITE, false, 1.0)
	# A small front light remains readable even at the default zoom.
	if not id.begins_with("coach") and id != "log_wagon_loaded":
		canvas.draw_line(Vector2(-2, -12), Vector2(2, -12), Color("#FFF1BB"), 2.0)

static func draw_empty_wagon(canvas: CanvasItem, high_contrast: bool) -> void:
	# The sheet has no empty flatbed frame. Draw its deck instead of showing
	# a full load after delivery. This uses the same 28 px body envelope.
	canvas.draw_rect(Rect2(-6, -14, 12, 28), Color("#303E48"))
	canvas.draw_rect(Rect2(-4, -11, 8, 22), Color("#795B3D"))
	for plank in [-7, -2, 3, 8]:
		canvas.draw_line(Vector2(-4, plank), Vector2(4, plank), Color("#B49765"), 1.0)
	canvas.draw_rect(Rect2(-6, -14, 12, 28), Color.WHITE if high_contrast else Color("#87939B"), false, 1.0)

static func draw_freight_wagon(canvas: CanvasItem, kind: String, loaded: bool, high_contrast: bool) -> void:
	if loaded and kind == "logs":
		draw_vehicle(canvas, "log_wagon_loaded", high_contrast)
		return
	draw_empty_wagon(canvas, high_contrast)
	if not loaded: return
	if kind == "timber":
		for plank in [-3, 0, 3]:
			canvas.draw_rect(Rect2(plank - 1, -10, 2, 20), Color("#D2B781"))
	else:
		for crate in [-8, 0, 8]:
			canvas.draw_rect(Rect2(-4, crate - 3, 8, 6), Color("#BD8B50"))
			canvas.draw_rect(Rect2(-4, crate - 3, 8, 6), Color("#F1CE8D"), false, 1.0)
