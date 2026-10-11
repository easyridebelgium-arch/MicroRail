extends ConfirmationDialog
## Global object search. Pins use stable object keys, never display names.
var game: Node
var search: LineEdit
var kind: OptionButton
var pinned_only: CheckButton
var items: ItemList
var details: Label
var pin_button: Button
var count_label: Label
var rows: Array = []

func configure(owner_game: Node) -> void:
	game = owner_game
	title = "Find objects and watchlist"
	ok_button_text = "Locate and show route"
	get_cancel_button().text = "Close"
	dialog_hide_on_ok = false
	exclusive = true
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	search = LineEdit.new()
	search.placeholder_text = "Search name, #ID, route, model or status"
	search.text_changed.connect(func(_text: String) -> void: refresh())
	box.add_child(search)
	var filters := HFlowContainer.new()
	box.add_child(filters)
	kind = OptionButton.new()
	for text in ["All types", "Train", "Service", "Station", "Industry"]: kind.add_item(text)
	kind.item_selected.connect(func(_index: int) -> void: refresh())
	filters.add_child(kind)
	pinned_only = CheckButton.new()
	pinned_only.text = "Pinned only"
	pinned_only.toggled.connect(func(_enabled: bool) -> void: refresh())
	filters.add_child(pinned_only)
	count_label = Label.new()
	box.add_child(count_label)
	items = ItemList.new()
	items.custom_minimum_size.y = 130
	items.item_selected.connect(func(_index: int) -> void: describe())
	items.item_activated.connect(func(_index: int) -> void: locate())
	box.add_child(items)
	pin_button = Button.new()
	pin_button.pressed.connect(toggle_pin)
	box.add_child(pin_button)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(details)
	confirmed.connect(locate)

func open_dialog() -> void:
	refresh()
	popup_centered_clamped(Vector2i(620, 470), 0.95)

func refresh() -> void:
	var previous := selected_key()
	rows.clear()
	items.clear()
	var query := search.text.strip_edges().to_lower()
	var filter := "" if kind.selected == 0 else kind.get_item_text(kind.selected)
	for row in game.object_rows():
		if not filter.is_empty() and row.kind != filter: continue
		if pinned_only.button_pressed and not game.object_pins.has(row.key): continue
		if not query.is_empty() and not (str(row.title) + " " + str(row.details)).to_lower().contains(query): continue
		rows.append(row)
		items.add_item(("★ " if game.object_pins.has(row.key) else "") + "[%s] %s" % [row.kind, row.title])
		items.set_item_tooltip(items.item_count - 1, row.details)
		if row.key == previous: items.select(items.item_count - 1)
	if items.get_selected_items().is_empty() and not rows.is_empty(): items.select(0)
	count_label.text = "%d matching objects. Pins last until game reload or exit." % rows.size()
	describe()

func selected_key() -> String:
	var selection := items.get_selected_items()
	return str(rows[selection[0]].key) if not selection.is_empty() and selection[0] < rows.size() else ""

func describe() -> void:
	var selection := items.get_selected_items()
	pin_button.disabled = selection.is_empty()
	get_ok_button().disabled = selection.is_empty()
	if selection.is_empty():
		details.text = "No matching objects. Change the search or filters."
		pin_button.text = "Pin selected"
		return
	var row: Dictionary = rows[selection[0]]
	pin_button.text = "Unpin selected" if game.object_pins.has(row.key) else "Pin selected"
	details.text = row.details
	get_ok_button().disabled = not game.can_locate_problem(row)

func toggle_pin() -> void:
	var key := selected_key()
	if key.is_empty(): return
	if game.object_pins.has(key): game.object_pins.erase(key)
	else: game.object_pins[key] = true
	refresh()

func locate() -> void:
	var selection := items.get_selected_items()
	if not selection.is_empty() and game.locate_object(rows[selection[0]]): hide()
