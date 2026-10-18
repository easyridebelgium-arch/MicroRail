extends ConfirmationDialog
## Current company snapshot; no timers, sampling, predictions or saved state.
var game: Node
var headline: Label
var items: ItemList
var details: Label
var action_button: Button
var rows: Array = []
func configure(owner_game: Node) -> void:
	game = owner_game
	title = "Network summary"
	ok_button_text = "Locate selected item"
	get_cancel_button().text = "Close"
	dialog_hide_on_ok = false
	exclusive = true
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 100
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	headline = Label.new()
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(headline)
	var reports_button := Button.new()
	reports_button.text = "Progress reports"
	reports_button.pressed.connect(func() -> void: hide(); game.open_progress_reports())
	box.add_child(reports_button)
	var contracts_button := Button.new()
	contracts_button.text = "Freight contracts"
	contracts_button.pressed.connect(func() -> void: hide(); game.contracts_dialog.open_dialog())
	box.add_child(contracts_button)
	var guide := Label.new()
	guide.text = "Review order: deadlocks → broken routes/overdue loans/contract warnings → waits of 5s+ → unserved queues → queue pressure → measured capacity → intentional holds/other active contracts → expansion. Contract warnings mean a current obstacle or at most 25% of its original time window left; they are not forecasts. Equal priority uses measured size, then stable ID."
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.text += "\nOperating contribution excludes capital purchases, rewards, loan flows and interest. Enabled services can still be dwelling, held or waiting."
	var rules_button := CheckButton.new()
	rules_button.text = "Review order and measurement notes"
	box.add_child(rules_button)
	box.add_child(guide)
	guide.hide()
	rules_button.toggled.connect(func(expanded: bool) -> void: guide.visible = expanded)
	items = ItemList.new()
	items.custom_minimum_size.y = 150
	items.item_selected.connect(func(_index: int) -> void: describe())
	box.add_child(items)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(details)
	action_button = Button.new()
	action_button.pressed.connect(act)
	box.add_child(action_button)
	confirmed.connect(locate)
func open_dialog() -> void:
	var data: Dictionary = game.network_summary_data()
	rows = game.NetworkSummary.build(data)
	headline.text = "%s · £%d balance · £%d operating contribution\nCompany lifetime: %d final passenger journeys · £%d fares · £%d freight receipts\nNow: %d queued passengers · %d enabled services · %d items below" % [game.game_clock_text(), data.money, data.profit, data.delivered, data.fares, data.freight, data.waiting, data.enabled, rows.size()]
	var contract: Dictionary = data.get("contract", {})
	if not contract.is_empty(): headline.text += "\nActive freight order: %s %d/%d · %s remaining" % [str(contract.kind).capitalize(), contract.progress, contract.target, game.FreightContracts.time_left(int(contract.remaining))]
	headline.tooltip_text = "Operating contribution excludes capital purchases, rewards, loan flows and interest."
	items.clear()
	for row in rows:
		items.add_item("[%s] %s%s" % [row.severity, row.title, " (acknowledged)" if row.get("acknowledged", false) else ""])
		items.set_item_tooltip(items.item_count - 1, row.details)
	if not rows.is_empty(): items.select(0)
	describe()
	popup_centered_clamped(Vector2i(720, 570), 0.85)
func selected() -> Dictionary:
	var selection := items.get_selected_items()
	return rows[selection[0]] if not selection.is_empty() and selection[0] < rows.size() else {}
func describe() -> void:
	var row := selected()
	details.text = "No items meet these review rules. This is not a guarantee of future traffic safety or service quality. Routine waits below five seconds are omitted; detailed current states and incident history remain in Problems." if row.is_empty() else str(row.details)
	action_button.disabled = row.is_empty()
	action_button.text = "Review selected item" if row.is_empty() else str(row.action_text)
	get_ok_button().disabled = row.is_empty() or not game.can_locate_problem(row)
func locate() -> void:
	var row := selected()
	if not row.is_empty() and game.locate_object(row): hide()
func act() -> void:
	var row := selected()
	if row.is_empty(): return
	hide()
	match row.action:
		"inspect": game.inspect_train(int(row.id))
		"bank": game.loans_dialog.open_dialog()
		"contract": game.contracts_dialog.open_dialog(str(row.contract_kind))
		"service": game.open_service_cards(str(row.service))
		"station":
			game.locate_problem(row)
			game._inspect_station_at(row.cell)
		"find":
			var browser = game.object_browser
			browser.search.clear()
			browser.kind.select(0)
			browser.pinned_only.set_pressed_no_signal(false)
			browser.open_dialog()
			for index in range(browser.rows.size()):
				if browser.rows[index].key == row.object_key:
					browser.items.select(index)
					browser.describe()
					break
