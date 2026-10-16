extends RefCounted
const Ground = preload("res://scripts/art/terrain_art.gd")
static func draw(canvas: CanvasItem, terrain: RefCounted, tracks: Dictionary, high_contrast: bool) -> void:
	if terrain.profile == "flat": return
	var water := Ground.texture("water_shallow") as AtlasTexture
	for x in range(80):
		for y in terrain.water_rows(x):
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
	# Shorelines follow the same profile mask, including the bends.
	for x in range(80):
		for y in terrain.water_rows(x):
			var cell := Vector2i(x, y)
			var at := Vector2(cell) * 32
			for delta in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if terrain.water(cell + delta): continue
				var first := at + (Vector2(0, 32) if delta == Vector2i.DOWN else Vector2(32, 0) if delta == Vector2i.RIGHT else Vector2.ZERO)
				canvas.draw_line(first, first + (Vector2(32, 0) if delta.x == 0 else Vector2(0, 32)), Color("#d5c797"), 2)
