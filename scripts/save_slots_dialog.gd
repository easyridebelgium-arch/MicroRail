extends ConfirmationDialog
## Select a storage slot without changing the active game until an operation succeeds.
const Preview = preload("res://scripts/core/save_preview.gd")
const Thumbnail = preload("res://scripts/ui/save_thumbnail.gd")
var thumbnail: Control
var preview_label: Label
const Slots = preload("res://scripts/core/save_slots.gd")
var game: Node
var operation := "save"
var slots: ItemList
var explanation: Label
var fresh_button: Button
var recovery_button: Button
var recovery_picker: ConfirmationDialog

func configure(owner_game: Node) -> void:
	game = owner_game
	get_cancel_button().text = "Close"
	exclusive = true
	dialog_hide_on_ok = false
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 80
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	explanation = Label.new()
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(explanation)
	slots = ItemList.new()
	slots.custom_minimum_size = Vector2(400, 170)
	slots.item_selected.connect(func(_index: int) -> void: _refresh_action())
	box.add_child(slots)
	var preview_row := HBoxContainer.new()
	box.add_child(preview_row)
	thumbnail = Thumbnail.new()
	preview_row.add_child(thumbnail)
	preview_label = Label.new()
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_row.add_child(preview_label)

	fresh_button = Button.new()
	fresh_button.text = "Start fresh game in selected slot"
	fresh_button.pressed.connect(_start_fresh)
	box.add_child(fresh_button)
	recovery_picker = preload("res://scripts/ui/autosave_picker.gd").new()
	add_child(recovery_picker)
	recovery_picker.recovery_requested.connect(func(slot: int, filename: String) -> void:
		if game._load_autosave(slot, filename):
			recovery_picker.hide()
			hide()
		else: recovery_picker.explanation.text = game.notice)
	recovery_button = Button.new()
	recovery_button.text = "Recover autosave for selected slot…"
	recovery_button.pressed.connect(func() -> void:
		if not slots.get_selected_items().is_empty(): recovery_picker.open_slot(slots.get_selected_items()[0] + 1))
	box.add_child(recovery_button)
	confirmed.connect(_perform)
	close_requested.connect(hide)

func open_dialog(operation_mode: String) -> void:
	operation = operation_mode
	title = "Save game" if operation_mode == "save" else "Load game" if operation_mode == "load" else "Load previous save"
	ok_button_text = "Save selected slot" if operation_mode == "save" else "Load selected slot"
	explanation.text = "Saving replaces only the selected slot; its previous save is kept as that slot's backup." if operation_mode == "save" else "Loading replaces the current game in memory. Start fresh opens the Tutorial/City sandbox chooser; manual saves change only when you Save; autosaves keep separate recovery copies."
	fresh_button.visible = operation_mode == "load"
	recovery_button.visible = operation_mode == "load"
	slots.clear()
	for slot in range(1, Slots.COUNT + 1):
		var label := Slots.describe(slot)
		if slot == game.active_save_slot: label += " (current)"
		if operation_mode == "backup" and not FileAccess.file_exists(Slots.path(slot, "backup")): label += " — No backup"
		slots.add_item(label)
		slots.set_item_tooltip(slot - 1, ProjectSettings.globalize_path(Slots.path(slot)))
	slots.select(game.active_save_slot - 1)
	_refresh_action()
	popup_centered_clamped(Vector2i(620, 450), 0.95)

func _refresh_action() -> void:
	if not slots.get_selected_items().is_empty():
		var snapshot := Preview.read(Slots.path(slots.get_selected_items()[0] + 1, "backup" if operation == "backup" else "save"))
		thumbnail.set_snapshot(snapshot)
		preview_label.text = snapshot.text
	get_ok_button().disabled = slots.get_selected_items().is_empty()
	if not get_ok_button().disabled and operation != "save":
		get_ok_button().disabled = not FileAccess.file_exists(Slots.path(slots.get_selected_items()[0] + 1, "backup" if operation == "backup" else "save"))

func _perform() -> void:
	if slots.get_selected_items().is_empty(): return
	var slot := slots.get_selected_items()[0] + 1
	var success: bool = game._save_game(slot) if operation == "save" else game._load_slot(slot, operation == "backup")
	if success: hide()
	else: explanation.text = game.notice

func _start_fresh() -> void:
	if slots.get_selected_items().is_empty(): return
	game._open_new_game.call_deferred(slots.get_selected_items()[0] + 1)
	hide()
