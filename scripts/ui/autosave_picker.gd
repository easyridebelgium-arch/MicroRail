extends ConfirmationDialog
## Recovery uses the normal full save validator; previews are never a validity guarantee.
signal recovery_requested(slot: int, filename: String)
const Autosaves = preload("res://scripts/core/autosaves.gd")
const Preview = preload("res://scripts/core/save_preview.gd")
const Thumbnail = preload("res://scripts/ui/save_thumbnail.gd")
var selected_slot: int = 1
var copies: Array[Dictionary] = []
var list: ItemList
var explanation: Label
var thumbnail: Control
var preview_label: Label

func _ready() -> void:
	theme = preload("res://scripts/ui/shared_theme.gd").build()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#182330")
	panel.border_color = Color("#52687A")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(6)
	for edge in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: panel.set_content_margin(edge, 16)
	theme.set_stylebox("panel", "AcceptDialog", panel)
	theme.set_stylebox("panel", "ConfirmationDialog", panel)
	title = "Recover autosave"
	ok_button_text = "Recover selected copy"
	exclusive = true
	dialog_hide_on_ok = false
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 100
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	explanation = Label.new()
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(explanation)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(300, 100)
	list.item_selected.connect(func(_index: int) -> void: _refresh())
	box.add_child(list)
	thumbnail = Thumbnail.new()
	box.add_child(thumbnail)
	preview_label = Label.new()
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(preview_label)
	confirmed.connect(func() -> void:
		var selected := list.get_selected_items()
		if not selected.is_empty(): recovery_requested.emit(selected_slot, copies[selected[0]].path))
	close_requested.connect(hide)

func open_slot(slot: int) -> void:
	selected_slot = slot
	copies = Autosaves.entries(slot)
	explanation.text = "Slot %d — newest copy first. Recovery replaces the game in memory and pauses it. Manual saves and their backups stay unchanged." % slot
	list.clear()
	for index in range(copies.size()):
		var timestamp := Time.get_datetime_string_from_unix_time(copies[index].modified).replace("T", " ")
		list.add_item("%s — %s UTC" % ["Newest" if index == 0 else "Older copy %d" % index, timestamp])
	if not copies.is_empty(): list.select(0)
	else: explanation.text += " No autosaves yet. Enable them in Settings and let game time advance."
	_refresh()
	# Leave room for embedded window decorations at 200% UI scale.
	popup_centered_clamped(Vector2i(620, 450), 0.85)

func _refresh() -> void:
	var selected := list.get_selected_items()
	get_ok_button().disabled = selected.is_empty()
	var snapshot := Preview.read(copies[selected[0]].path) if not selected.is_empty() else Preview.read("")
	thumbnail.set_snapshot(snapshot)
	preview_label.text = snapshot.text
