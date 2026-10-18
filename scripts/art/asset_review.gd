extends Control
## Standalone artwork review; never advances or changes the railway simulation.

const MANIFEST := "res://art/generated/microrail_pack_v2/manifest.json"

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	_text(column, "MicroRail — feedback and city-growth art review", 24)
	_text(column, "Candidate art. Main-game visuals and simulation are unchanged. Scroll to review both categories.", 16)
	_text(column, "Left: larger inspection preview. Right: intended display-size preview. Gameplay sprites still need pixel/perspective cleanup.", 16)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not data is Dictionary or not data.has("sheets"):
		push_error("Cannot read artwork manifest")
		get_tree().quit(1)
		return
	var count := 0
	for sheet: Dictionary in data["sheets"]:
		_text(column, "UI feedback icons" if sheet["category"] == "ui" else "City, station and passenger candidates", 22)
		var grid := HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		column.add_child(grid)
		for entry: Dictionary in sheet["entries"]:
			var texture := load("res://" + str(entry["resource"])) as AtlasTexture
			if texture == null or texture.atlas == null or texture.region.size.x <= 0 or texture.region.size.y <= 0:
				push_error("Artwork texture failed to load: " + str(entry["id"]))
				get_tree().quit(1)
				return
			var panel := PanelContainer.new()
			panel.custom_minimum_size = Vector2(275, 220)
			panel.tooltip_text = str(entry["resource"])
			var box := VBoxContainer.new()
			panel.add_child(box)
			var label := _text(box, str(entry["label"]), 16)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var previews := HBoxContainer.new()
			previews.alignment = BoxContainer.ALIGNMENT_CENTER
			previews.add_theme_constant_override("separation", 16)
			box.add_child(previews)
			_preview(previews, texture, 128)
			_preview(previews, texture, int(entry["suggested_display_px"]))
			var caption := _text(box, "%d px preview · candidate" % int(entry["suggested_display_px"]), 14)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			grid.add_child(panel)
			count += 1
	print("Artwork review: %d candidate AtlasTextures loaded." % count)

func _text(parent: Node, value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 230
	parent.add_child(label)
	return label

func _preview(parent: Node, texture: Texture2D, pixels: int) -> void:
	var preview := TextureRect.new()
	preview.texture = texture
	preview.custom_minimum_size = Vector2(pixels, pixels)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(preview)
