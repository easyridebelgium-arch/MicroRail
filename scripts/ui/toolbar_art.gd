extends RefCounted
## Display-only adaptation of approved source PNGs. Originals remain untouched.
const ROOT := "res://assets/ui/toolbar/"
# Explicit opaque-content bounds, measured from the approved uploads. Update
# these when replacing a source image with a differently sized/cropped version.
const BOUNDS := {
	"backgrounds/button_disabled.png": Rect2i(278, 291, 698, 657),
	"backgrounds/button_hover.png": Rect2i(279, 291, 698, 658),
	"backgrounds/button_normal.png": Rect2i(278, 292, 697, 655),
	"backgrounds/button_pressed.png": Rect2i(354, 353, 547, 548),
	"backgrounds/button_selected.png": Rect2i(278, 292, 699, 657),
	"backgrounds/button_selected_hover.png": Rect2i(277, 292, 700, 656),
	"backgrounds/ribbon_panel.png": Rect2i(85, 140, 1748, 536),
	"details/dropdown_arrow.png": Rect2i(421, 418, 560, 344),
	"details/group_separator.png": Rect2i(576, 128, 66, 1052),
	"icons/find.png": Rect2i(231, 246, 802, 805),
	"icons/fleet.png": Rect2i(157, 424, 941, 426),
	"icons/history.png": Rect2i(165, 148, 924, 993),
	"icons/inspect.png": Rect2i(157, 187, 920, 895),
	"icons/load.png": Rect2i(248, 227, 758, 845),
	"icons/overlays.png": Rect2i(286, 181, 683, 943),
	"icons/pause.png": Rect2i(406, 366, 442, 522),
	"icons/play.png": Rect2i(313, 263, 634, 723),
	"icons/problems.png": Rect2i(135, 229, 984, 814),
	"icons/redo.png": Rect2i(279, 316, 779, 625),
	"icons/reservations.png": Rect2i(235, 235, 831, 789),
	"icons/routes.png": Rect2i(176, 314, 978, 697),
	"icons/save.png": Rect2i(218, 239, 818, 775),
	"icons/save_folder.png": Rect2i(210, 299, 834, 688),
	"icons/settings.png": Rect2i(166, 163, 922, 923),
	"icons/signals.png": Rect2i(495, 244, 265, 781),
	"icons/switch.png": Rect2i(340, 171, 756, 920),
	"icons/track_connect.png": Rect2i(214, 369, 1108, 332),
	"icons/track_draw.png": Rect2i(267, 196, 799, 868),
	"icons/track_remove.png": Rect2i(273, 238, 708, 778),
	"icons/traffic.png": Rect2i(287, 220, 682, 869),
	"icons/undo.png": Rect2i(235, 235, 823, 784),
	"icons/waypoint.png": Rect2i(342, 192, 603, 861),
}
static var textures: Dictionary = {}
static var styles: Dictionary = {}

static func texture(relative: String, canvas: Vector2i, icon: bool = false) -> Texture2D:
	var cache_key := relative + str(canvas) + str(icon)
	if textures.has(cache_key): return textures[cache_key]
	var source: Texture2D = load(ROOT + relative)
	var source_image := source.get_image()
	var region: Rect2i = BOUNDS[relative] if BOUNDS.has(relative) else source_image.get_used_rect()
	# Accept compact replacements exported at the documented native sizes.
	if region.end.x > source_image.get_width() or region.end.y > source_image.get_height():
		region = source_image.get_used_rect()
	var image := source_image.get_region(region)
	image.convert(Image.FORMAT_RGBA8)
	# This one source has an opaque white surround. Remove only white connected
	# to the crop edges, preserving enclosed white bevel highlights.
	if relative == "backgrounds/button_pressed.png": _clear_white_surround(image)
	if icon:
		var scale_factor := minf(float(canvas.x - 4) / image.get_width(), float(canvas.y - 4) / image.get_height())
		var fitted := Vector2i(maxi(1, roundi(image.get_width() * scale_factor)), maxi(1, roundi(image.get_height() * scale_factor)))
		image.resize(fitted.x, fitted.y, Image.INTERPOLATE_NEAREST)
		var centred := Image.create(canvas.x, canvas.y, false, Image.FORMAT_RGBA8)
		centred.fill(Color.TRANSPARENT)
		centred.blit_rect(image, Rect2i(Vector2i.ZERO, fitted), (canvas - fitted) / 2)
		image = centred
	else:
		image.resize(canvas.x, canvas.y, Image.INTERPOLATE_NEAREST)
	var result := ImageTexture.create_from_image(image)
	textures[cache_key] = result
	return result

static func _clear_white_surround(image: Image) -> void:
	var queue: Array[Vector2i] = []
	for x in range(image.get_width()):
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, image.get_height() - 1))
	for y in range(image.get_height()):
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(image.get_width() - 1, y))
	var index := 0
	while index < queue.size():
		var pixel := queue[index]
		index += 1
		if pixel.x < 0 or pixel.y < 0 or pixel.x >= image.get_width() or pixel.y >= image.get_height(): continue
		var colour := image.get_pixelv(pixel)
		if colour.a == 0 or minf(colour.r, minf(colour.g, colour.b)) < 0.85: continue
		image.set_pixelv(pixel, Color.TRANSPARENT)
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]: queue.append(pixel + offset)

static func style(state: String) -> StyleBoxTexture:
	if styles.has(state): return styles[state]
	var box := StyleBoxTexture.new()
	box.texture = texture("backgrounds/button_%s.png" % state, Vector2i(64, 64))
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, 12)
		box.set_content_margin(side, 8)
	styles[state] = box
	return box

static func decorate(button: Button, action: String, label: String) -> void:
	button.set_meta("toolbar_action", action)
	button.set_meta("toolbar_label", label)
	button.accessibility_name = label
	button.text = ""
	button.icon = texture("icons/%s.png" % action, Vector2i(24, 24), true)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = true
	button.custom_minimum_size = Vector2(64, 64)
	button.add_theme_constant_override("icon_max_width", 48)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.focus_mode = Control.FOCUS_ALL
	if button.tooltip_text.is_empty(): button.tooltip_text = label
	button.add_theme_stylebox_override("normal", style("normal"))
	button.add_theme_stylebox_override("hover", style("hover"))
	button.add_theme_stylebox_override("pressed", style("selected" if button.toggle_mode else "pressed"))
	button.add_theme_stylebox_override("hover_pressed", style("selected_hover" if button.toggle_mode else "pressed"))
	button.add_theme_stylebox_override("disabled", style("disabled"))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("#E7EEF4")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(5)
	button.add_theme_stylebox_override("focus", focus)
	# A selected tool also has a white underline, independent of its blue fill.
	button.draw.connect(func() -> void:
		if button.toggle_mode and button.button_pressed:
			var centre := button.size.x * 0.5
			button.draw_line(Vector2(centre - 8, button.size.y - 5), Vector2(centre + 8, button.size.y - 5), Color.WHITE, 2))
