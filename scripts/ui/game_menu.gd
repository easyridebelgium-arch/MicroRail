extends AcceptDialog
## Pauses the game without changing its fixed-step clock, speed or world state.
const Actions = preload("res://scripts/core/input_actions.gd")
var game: Node
var active := false
var was_paused := true
var returning := false
var from_settings := false
var save_button: Button
var settings_button: Button
var return_button: Button
var status: Label
var leave_dialog: ConfirmationDialog
var discard_button: Button
var return_explanation: Label

func configure(owner_game: Node) -> void:
	game = owner_game
	title = "Game menu"
	ok_button_text = "Resume"
	exclusive = true
	theme = game.header_box.theme.duplicate() as Theme
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#182330")
	panel.border_color = Color("#52687A")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(6)
	for edge in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: panel.set_content_margin(edge, 16)
	theme.set_stylebox("panel", "AcceptDialog", panel)
	theme.set_stylebox("panel", "ConfirmationDialog", panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(240, 140)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	save_button = _button(column, "Save game", _save)
	_button(column, "First service guide", func() -> void:
		resume_game()
		game.first_service_guide.open_guide())
	settings_button = _button(column, "Settings", _settings)
	return_button = _button(column, "Return to Main Menu", request_return)
	confirmed.connect(resume_game)
	canceled.connect(resume_game)
	close_requested.connect(resume_game)
	window_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed(Actions.CANCEL):
			resume_game()
			set_input_as_handled())
	leave_dialog = ConfirmationDialog.new()
	leave_dialog.title = "Return to Main Menu?"
	leave_dialog.ok_button_text = "Save and Return"
	leave_dialog.dialog_autowrap = true
	leave_dialog.exclusive = true
	leave_dialog.theme = theme
	leave_dialog.dialog_hide_on_ok = false
	var exit_scroll := ScrollContainer.new()
	exit_scroll.custom_minimum_size = Vector2(240, 100)
	exit_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	exit_scroll.follow_focus = true
	leave_dialog.add_child(exit_scroll)
	var exit_column := VBoxContainer.new()
	exit_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_column.add_theme_constant_override("separation", 16)
	exit_scroll.add_child(exit_column)
	return_explanation = Label.new()
	return_explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	exit_column.add_child(return_explanation)
	discard_button = _button(exit_column, "Return Without Saving", _leave)
	leave_dialog.confirmed.connect(_save_and_leave)
	leave_dialog.canceled.connect(_cancel_return)
	leave_dialog.close_requested.connect(_cancel_return)
	leave_dialog.window_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed(Actions.CANCEL):
			_cancel_return()
			leave_dialog.set_input_as_handled())
	game.get_node("Interface").add_child(leave_dialog)
	game.settings_dialog.visibility_changed.connect(_restore_after_settings.call_deferred)

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func open_menu() -> void:
	if active: return
	was_paused = game.paused
	active = true
	game.paused = true
	game._reset_track_tools()
	save_button.text = "Save game — Slot %d" % game.active_save_slot
	status.text = "Game paused. The simulation was already paused before opening this menu." if was_paused else "Game paused. Resume continues at %d× speed." % int(game.sim_clock.speed)
	popup_centered_clamped(Vector2i(420, 340), 0.95)
	get_ok_button().grab_focus()

func resume_game() -> void:
	if not active or returning or from_settings: return
	active = false
	hide()
	game.paused = was_paused
	game._update_toolbar()

func _save() -> bool:
	var saved: bool = game._save_game()
	status.text = "Saved to Slot %d." % game.active_save_slot if saved else "Could not save: " + str(game.notice)
	return saved

func _settings() -> void:
	from_settings = true
	hide()
	game._open_settings()

func _restore_after_settings() -> void:
	if not from_settings or returning or game.settings_dialog.visible: return
	from_settings = false
	popup_centered_clamped(Vector2i(420, 340), 0.95)
	get_ok_button().grab_focus()

func request_return() -> void:
	if not active:
		open_menu()
	from_settings = false
	returning = true
	hide()
	return_explanation.text = "Save to Slot %d before leaving? Return Without Saving discards progress since your last save. Construction drafts must be applied or discarded before saving." % game.active_save_slot
	leave_dialog.popup_centered_clamped(Vector2i(520, 260), 0.95)
	leave_dialog.get_cancel_button().grab_focus()

func _cancel_return() -> void:
	if not returning: return
	returning = false
	leave_dialog.hide()
	popup_centered_clamped(Vector2i(420, 340), 0.95)
	get_ok_button().grab_focus()

func _save_and_leave() -> void:
	if _save():
		_leave()
	else:
		_cancel_return()

func _leave() -> void:
	var error: Error = game.get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
	if error != OK:
		_cancel_return()
		status.text = "Could not open the main menu. Your current game is still available."
