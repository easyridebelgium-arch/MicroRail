extends ConfirmationDialog
## Opening this window pauses the game. Reversal is explicit and revalidated by
## main.gd; the button never bypasses reservations or grants movement.
var game: Node
var train_choice: OptionButton
var details: Label
var result: Label

func configure(owner_game: Node) -> void:
	game = owner_game
	title = "Traffic and recovery"
	ok_button_text = "Reverse selected train"
	get_cancel_button().text = "Close"
	dialog_hide_on_ok = false
	exclusive = true
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 120
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(details)
	train_choice = OptionButton.new()
	box.add_child(train_choice)
	train_choice.item_selected.connect(func(_index: int) -> void: refresh())
	var explanation := Label.new()
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.text = "Reverse a train in a confirmed deadlock without changing its position or path. Resume to let it travel back to its departure stop under reservations. It then waits there; passengers return to that queue and freight cargo stays aboard. It can still wait for blocked track or a red signal. Enable the service in Fleet when ready. Reversal does not repair the layout or choose a passing loop."
	box.add_child(explanation)
	var dispatch := HFlowContainer.new()
	box.add_child(dispatch)
	for hold in [true, false]:
		var button := Button.new()
		button.text = "Hold selected train" if hold else "Resume selected train"
		button.pressed.connect(func() -> void:
			result.text = game.set_dispatch_hold(int(train_choice.get_selected_metadata()), hold)
			refresh())
		dispatch.add_child(button)
	result = Label.new()
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(result)
	confirmed.connect(_reverse)

func open_dialog() -> void:
	train_choice.clear()
	for service in ["passenger", "freight"]:
		var train: Dictionary = game.Fleet.assigned(game.fleet, service)
		train_choice.add_item("#%d %s" % [int(train["id"]), train["name"]])
		train_choice.set_item_metadata(train_choice.item_count - 1, int(train["id"]))
	result.text = ""
	refresh()
	popup_centered_clamped(Vector2i(580, 440), 0.95)

func refresh() -> void:
	details.text = game.traffic_summary()
	if train_choice.item_count > 0:
		get_ok_button().disabled = not game.deadlocks.contains(int(train_choice.get_selected_metadata()))

func _reverse() -> void:
	result.text = game.reverse_deadlocked_train(int(train_choice.get_selected_metadata()))
	refresh()
