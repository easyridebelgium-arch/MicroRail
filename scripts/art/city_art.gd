extends RefCounted
## Density changes only inside the city's existing protected plot.
const IMAGES := {
	"small": preload("res://assets/world/growth/props/city_small_cluster.tres"),
	"town": preload("res://assets/world/growth/props/city_town_block.tres"),
	"dense": preload("res://assets/world/growth/props/city_dense_block.tres")
}
static func density(population: int, initial: int) -> String:
	if population * 5 < initial * 4: return "small"
	if population * 2 >= initial * 3: return "dense"
	return "town"

static func fitted_bounds(plot: Rect2, source_size: Vector2) -> Rect2:
	var available := plot.grow(-4.0)
	var factor := minf(available.size.x / source_size.x, available.size.y / source_size.y)
	var size := (source_size * factor).floor()
	return Rect2((available.get_center() - size * 0.5).floor(), size)

static func draw_city(canvas: CanvasItem, plot: Rect2, population: int, initial: int) -> void:
	var image: AtlasTexture = IMAGES[density(population, initial)]
	# Draw the source atlas explicitly; repeated AtlasTexture draw calls can
	# otherwise lose regions on a CanvasItem after another atlas is drawn.
	canvas.draw_texture_rect_region(image.atlas, fitted_bounds(plot, image.region.size), image.region, Color.WHITE, false, false)
