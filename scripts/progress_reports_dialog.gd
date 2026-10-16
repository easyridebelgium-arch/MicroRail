extends ConfirmationDialog
## Report browsing is read-only; reminders are a per-company presentation rule.
var game: Node
var choice: OptionButton
var mode_choice: OptionButton
var heading: Label
var details: Label
var history: Label
func configure(owner_game: Node) -> void:
	game = owner_game
	title = "Company progress reports"
	ok_button_text = "Network summary"
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
	heading = Label.new()
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(heading)
	mode_choice = OptionButton.new()
	mode_choice.clip_text = true
	for text in game.ProgressReports.MODE_NAMES: mode_choice.add_item(text)
	mode_choice.tooltip_text = "This company's saved reminder preference. Reports are recorded in all modes. No popup opens automatically."
	mode_choice.item_selected.connect(func(index: int) -> void: game.request_report_mode(game.ProgressReports.MODES[index]))
	box.add_child(mode_choice)
	choice = OptionButton.new()
	choice.clip_text = true
	choice.item_selected.connect(func(_index: int) -> void: describe())
	box.add_child(choice)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(details)
	var notes := Label.new()
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes.text = "Final journeys count once; transfers do not add deliveries. Operating contribution = fares + freight receipts − running costs. Construction, purchases, rewards, loans and interest affect cash, not that contribution. Queue and population figures are endpoint snapshots, not averages. Historical outcomes do not prove a current problem; use Network summary for today's evidence."
	box.add_child(notes)
	var history_toggle := CheckButton.new()
	history_toggle.text = "Recent period comparison"
	box.add_child(history_toggle)
	history = Label.new()
	history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(history)
	history.hide()
	history_toggle.toggled.connect(func(expanded: bool) -> void: history.visible = expanded)
	confirmed.connect(func() -> void: hide(); game.open_network_summary())
func open_dialog() -> void:
	var state: Dictionary = game.progress_reports.state
	heading.text = "Saved 24-game-hour periods · latest %d retained\nRecording began %s. Next report %s. Pausing/closing does not age reports. Reminders below apply only to this company; save to retain changes." % [game.ProgressReports.KEEP, game.Timetable.clock_text(game.Timetable.absolute_minute(int(state.since))), game.Timetable.clock_text(game.Timetable.absolute_minute(int(state.baseline.tick) + game.ProgressReports.PERIOD))]
	mode_choice.select(game.ProgressReports.MODES.find(state.mode))
	choice.clear()
	for row in state.reports: choice.add_item(game.ProgressReports.period_text(row))
	if choice.item_count > 0: choice.select(choice.item_count - 1)
	choice.disabled = choice.item_count == 0
	describe()
	popup_centered_clamped(Vector2i(700, 580), 0.85)
func describe() -> void:
	details.text = game.progress_reports.describe(choice.selected)
	var lines: PackedStringArray = []
	var rows: Array = game.progress_reports.state.reports
	for index in range(maxi(0, rows.size() - 8), rows.size()):
		var change: Dictionary = game.ProgressReports.deltas(rows[index])
		lines.append("%s: %d final journeys · £%d operating contribution" % [game.ProgressReports.period_text(rows[index]), change.delivered, change.profit])
	history.text = "No completed periods yet." if lines.is_empty() else "\n".join(lines)
