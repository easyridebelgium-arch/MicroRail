extends Control
const Art = preload("res://scripts/art/terrain_art.gd")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	var heading := Label.new()
	heading.text = "Terrain materials — grass, snow, water and ground details"
	heading.add_theme_font_size_override("font_size", 24)
	column.add_child(heading)
	var note := Label.new()
	note.text = "Summer / autumn / snow backgrounds are live in Settings. Water and other materials are prepared for later map features."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	column.add_child(grid)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/terrain/manifest.json"))
	for entry: Dictionary in manifest.entries:
		var card := VBoxContainer.new()
		card.custom_minimum_size.x = 160
		var preview := TextureRect.new()
		preview.texture = Art.texture(entry.id)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.custom_minimum_size = Vector2(160, 128)
		card.add_child(preview)
		var label := Label.new()
		label.text = str(entry.id).replace("_", " ").capitalize()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(label)
		grid.add_child(card)
	print("Terrain review: %d materials loaded." % manifest.entries.size())
