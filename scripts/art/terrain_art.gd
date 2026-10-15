extends RefCounted
## Static cosmetic ground. Never reads or advances the simulation RNG.
const ROOT := "res://assets/environment/terrain/materials/"
const STYLE_MATERIAL := {"summer": "grass_summer", "autumn": "leaf_litter", "winter": "snow_fresh"}
const PATCH_SIZE := 128.0
static var _textures: Dictionary = {}

static func texture(material: String) -> Texture2D:
	if not _textures.has(material): _textures[material] = load(ROOT + material + ".tres")
	return _textures[material]

static func effective_style(preferred: String, high_contrast: bool) -> String:
	return "plain" if high_contrast or not STYLE_MATERIAL.has(preferred) else preferred

static func grid_color(style: String) -> Color:
	if style == "winter": return Color(0.28, 0.36, 0.43, 0.28)
	if style == "plain": return Color(0.18, 0.23, 0.25)
	return Color(0.08, 0.13, 0.08, 0.3)

static func draw_ground(canvas: CanvasItem, map_size: Vector2, style: String) -> void:
	var map_rect := Rect2(Vector2.ZERO, map_size)
	canvas.draw_rect(map_rect, Color(0.10, 0.15, 0.13))
	if not STYLE_MATERIAL.has(style): return
	# Stable world-aligned patches: camera movement never shifts the pattern.
	# Draw only visible patches. AtlasTexture cannot safely repeat its parent sheet.
	var inverse := canvas.get_global_transform_with_canvas().affine_inverse()
	var visible_rect: Rect2 = (inverse * canvas.get_viewport_rect()).intersection(map_rect)
	if not visible_rect.has_area(): return
	var ground := texture(STYLE_MATERIAL[style]) as AtlasTexture
	var tint := Color(0.78, 0.85, 0.76) if style == "summer" else Color(0.72, 0.72, 0.72) if style == "autumn" else Color(0.92, 0.95, 1.0)
	for row in range(int(floor(visible_rect.position.y / PATCH_SIZE)), int(ceil(visible_rect.end.y / PATCH_SIZE))):
		for column in range(int(floor(visible_rect.position.x / PATCH_SIZE)), int(ceil(visible_rect.end.x / PATCH_SIZE))):
			var patch := Rect2(Vector2(column, row) * PATCH_SIZE, Vector2.ONE * PATCH_SIZE).intersection(map_rect)
			var source := Rect2(ground.region.position, ground.region.size * patch.size / PATCH_SIZE)
			canvas.draw_texture_rect_region(ground.atlas, patch, source, tint, false, false)

static func draw_track_bed(canvas: CanvasItem, geometry: Dictionary) -> void:
	var ballast := Color("#424A45")
	var runs: Array = [geometry]
	runs.append_array(geometry.get("extra", []))
	# Every branch bed is below every rail/sleeper, including crossings.
	for run: Dictionary in runs:
		canvas.draw_polyline(run.left, ballast, 14.0)
		canvas.draw_polyline(run.right, ballast, 14.0)
