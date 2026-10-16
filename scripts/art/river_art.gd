extends RefCounted
const Ground = preload("res://scripts/art/terrain_art.gd")
static func draw(canvas: CanvasItem, terrain: RefCounted, tracks: Dictionary, high_contrast: bool) -> void:
	if terrain.profile != "river_v1": return
	var water := Ground.texture("water_shallow") as AtlasTexture
	for x in range(80):
		for y in [17, 18]:
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell) * 32, Vector2(32, 32))
			if high_contrast: canvas.draw_rect(rect, Color("#243c51"))
			else: canvas.draw_texture_rect_region(water.atlas, rect, water.region, Color.WHITE, false, false)
			canvas.draw_line(rect.position + Vector2(3, 12), rect.position + Vector2(25, 12), Color("#a1d7df"), 1)
			canvas.draw_line(rect.position + Vector2(8, 23), rect.position + Vector2(29, 23), Color("#a1d7df"), 1)
			if tracks.has(cell):
				canvas.draw_rect(rect.grow(-3), Color("#6d6555"))
				canvas.draw_line(rect.position + Vector2(3, 0), rect.position + Vector2(3, 32), Color("#e6d8a8"), 3)
				canvas.draw_line(rect.position + Vector2(29, 0), rect.position + Vector2(29, 32), Color("#e6d8a8"), 3)
	canvas.draw_line(Vector2(0, 17 * 32), Vector2(80 * 32, 17 * 32), Color("#d5c797"), 2)
	canvas.draw_line(Vector2(0, 19 * 32), Vector2(80 * 32, 19 * 32), Color("#d5c797"), 2)
