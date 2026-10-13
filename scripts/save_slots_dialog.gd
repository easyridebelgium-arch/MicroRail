extends ConfirmationDialog
## Select a storage slot without changing the active game until an operation succeeds.
const Slots = preload("res://scripts/core/save_slots.gd")
var game: Node
var operation := "save"
var slots: ItemList
var explanation: Label
var fresh_button: Button

func configure(owner_game: Node) -> void:
	game = owner_game
	get_cancel_button().text = "Close"
	exclusive = true
	dialog_hide_on_ok = false
	var box := VBoxContainer.new()
	add_child(box)
	explanation = Label.new()
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(explanation)
	slots = ItemList.new()
	slots.custom_minimum_size = Vector2(400, 170)
	slots.item_selected.connect(func(_index: int) -> void: _refresh_action())
	box.add_child(slots)
	fresh_button = Button.new()
	fresh_button.text = "Start fresh game in selected slot"
	fresh_button.pressed.connect(_start_fresh)
	box.add_child(fresh_button)
	confirmed.connect(_perform)
	close_requested.connect(hide)

func open_dialog(mode: String) -> void:
	operation = mode
	title = "Save game" if mode == "save" else "Load game" if mode == "load" else "Load previous save"
	ok_button_text = "Save selected slot" if mode == "save" else "Load selected slot"
	explanation.text = "Saving replaces only the selected slot; its previous save is kept as that slot's backup." if mode == "save" else "Loading replaces the current game in memory. Start fresh creates an empty map; saved files change only when you Save."
	fresh_button.visible = mode == "load"
	slots.clear()
	for slot in range(1, Slots.COUNT + 1):
		var label := Slots.describe(slot)
		if slot == game.active_save_slot: label += " (current)"
		if mode == "backup" and not FileAccess.file_exists(Slots.path(slot, "backup")): label += " — No backup"
		slots.add_item(label)
		slots.set_item_tooltip(slot - 1, ProjectSettings.globalize_path(Slots.path(slot)))
	slots.select(game.active_save_slot - 1)
	_refresh_action()
	popup_centered_clamped(Vector2i(540, 330), 0.95)

func _refresh_action() -> void:
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
	game._start_new_game.call_deferred(slots.get_selected_items()[0] + 1)
	hide()
