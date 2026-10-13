extends PanelContainer
## Persistent actionable current conditions; acknowledgement is not resolution.
var game: Node
var selected: Dictionary = {}
var label: Label
var view_button: Button
var acknowledge_button: Button
func configure(owner_game: Node) -> void:
	game = owner_game
	var box := HBoxContainer.new()
	add_child(box)
	label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(label)
	view_button = Button.new()
	view_button.text = "Inspect"
	view_button.pressed.connect(_view)
	box.add_child(view_button)
	acknowledge_button = Button.new()
	acknowledge_button.text = "Acknowledge"
	acknowledge_button.pressed.connect(func() -> void:
		game.acknowledge_problem(selected)
		refresh()
	)
	box.add_child(acknowledge_button)
	hide()
func refresh(rows: Array = []) -> void:
	selected = {}
	if rows.is_empty(): rows = game.problem_rows()
	for row in rows:
		if row.severity == "Info": continue
		if game.presentation.acknowledged.get(row.key, "") == row.signature: continue
		# An unbuilt starter route is a tutorial goal rather than an incident.
		if row.title.contains("Route incomplete"):
			var key: String = str(game.Fleet.find(game.fleet, int(row.id)).get("service", ""))
			var has_path := false
			for descriptor in game.inspection_trains():
				if descriptor.key == key and not descriptor.cells.is_empty(): has_path = true
			if not has_path: continue
		if selected.is_empty() or row.severity == "Urgent": selected = row
		if row.severity == "Urgent": break
	visible = not selected.is_empty()
	if not visible: return
	label.text = "! " + str(selected.title)
	label.tooltip_text = selected.details + "\nAcknowledgement hides this banner, not the condition in Problems."
	view_button.text = "Bank" if selected.key == "company:loan" else "Inspect"
func _view() -> void:
	if selected.is_empty(): return
	if selected.key == "company:loan": game.loans_dialog.open_dialog()
	elif not game.inspect_train(int(selected.id)): game._open_problems()
