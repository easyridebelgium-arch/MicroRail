extends ConfirmationDialog
## Search current operational problems separately from saved incident history.
var game: Node
var search: LineEdit
var source: OptionButton
var severity: OptionButton
var items: ItemList
var inspect_button: Button
var acknowledge_button: Button
var details: Label
var count_label: Label
var _rows: Array = []

func configure(owner_game: Node) -> void:
	game = owner_game
	title = "Problems and recent incidents"
	ok_button_text = "Locate selected item"
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
	search.placeholder_text = "Search train, service, reason or #ID"
	search.text_changed.connect(func(_text: String) -> void: refresh())
	box.add_child(search)
	var filters := HFlowContainer.new()
	box.add_child(filters)
	source = OptionButton.new()
	source.add_item("Current problems")
	source.add_item("Recent incidents (history)")
	source.item_selected.connect(func(_index: int) -> void: refresh())
	filters.add_child(source)
	severity = OptionButton.new()
	for text in ["All severities", "Urgent", "Warning", "Info"]: severity.add_item(text)
	severity.item_selected.connect(func(_index: int) -> void: refresh())
	filters.add_child(severity)
	count_label = Label.new()
	box.add_child(count_label)
	items = ItemList.new()
	items.custom_minimum_size.y = 130
	items.item_selected.connect(func(_index: int) -> void: _describe_selected())
	box.add_child(items)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(details)
	inspect_button = Button.new()
	inspect_button.text = "Inspect train now"
	inspect_button.pressed.connect(_inspect)
	box.add_child(inspect_button)
	acknowledge_button = Button.new()
	acknowledge_button.text = "Acknowledge selected problem"
	acknowledge_button.pressed.connect(func() -> void:
		if items.get_selected_items().is_empty(): return
		game.acknowledge_problem(_rows[items.get_selected_items()[0]])
		refresh()
	)
	box.add_child(acknowledge_button)
	confirmed.connect(_locate)

func open_dialog() -> void:
	refresh()
	popup_centered_clamped(Vector2i(620, 460), 0.95)

func refresh() -> void:
	var previous := ""
	if not items.get_selected_items().is_empty(): previous = str(_rows[items.get_selected_items()[0]].key)
	_rows.clear()
	items.clear()
	var rows: Array = game.problem_rows() if source.selected == 0 else game.incident_rows()
	var query := search.text.strip_edges().to_lower()
	var selected_severity := "" if severity.selected == 0 else severity.get_item_text(severity.selected)
	for row in rows:
		if not selected_severity.is_empty() and row.severity != selected_severity: continue
		if not query.is_empty() and not (str(row.title) + " " + str(row.details)).to_lower().contains(query): continue
		_rows.append(row)
		items.add_item("[%s] %s%s" % [row.severity, row.title, " (acknowledged)" if row.get("acknowledged", false) else ""])
		items.set_item_tooltip(items.item_count - 1, row.details)
		if str(row.key) == previous: items.select(items.item_count - 1)
	if items.get_selected_items().is_empty() and not _rows.is_empty(): items.select(0)
	count_label.text = "%d matching %s" % [_rows.size(), "current problems" if source.selected == 0 else "historical incidents"]
	_describe_selected()

func _describe_selected() -> void:
	var selection := items.get_selected_items()
	if selection.is_empty():
		details.text = "No matching problems." if source.selected == 0 else "No matching historical incidents. History is not a list of active problems."
		acknowledge_button.disabled = true
		inspect_button.disabled = true
		get_ok_button().disabled = true
		return
	var row: Dictionary = _rows[selection[0]]
	acknowledge_button.disabled = source.selected != 0 or row.get("acknowledged", false)
	inspect_button.text = "Open Bank loans" if row.key == "company:loan" else "Inspect train now"
	inspect_button.disabled = row.key != "company:loan" and game.Fleet.find(game.fleet, int(row.id)).is_empty()
	details.text = row.details
	get_ok_button().disabled = not game.can_locate_problem(row)

func _locate() -> void:
	var selection := items.get_selected_items()
	if selection.is_empty(): return
	if game.locate_problem(_rows[selection[0]]): hide()

func _inspect() -> void:
	var selection := items.get_selected_items()
	if selection.is_empty(): return
	if _rows[selection[0]].key == "company:loan":
		hide()
		game.loans_dialog.open_dialog()
		return
	var id := int(_rows[selection[0]].id)
	if game.Fleet.find(game.fleet, id).is_empty(): return
	hide()
	game.inspect_train(id)
