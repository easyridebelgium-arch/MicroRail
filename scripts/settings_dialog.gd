extends ConfirmationDialog
## Accessibility and controls: UI scale, colour palette, reduced motion and
## key bindings. Nothing changes until the player presses Apply.

signal settings_applied

const Settings = preload("res://scripts/core/game_settings.gd")
const Actions = preload("res://scripts/core/input_actions.gd")

var scale_choice: OptionButton
var palette_choice: OptionButton
var reduced_motion_check: CheckBox
var key_grid: GridContainer
var status: Label

var draft_bindings: Dictionary = {}
var key_buttons: Dictionary = {}
var capturing_action: StringName = &""


func configure() -> void:
	title = "Settings"
	size = Vector2i(560, 520)
	ok_button_text = "Apply"
	exclusive = true

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	box.add_child(_heading("Display"))

	scale_choice = OptionButton.new()
	for scale_value in Settings.UI_SCALES:
		scale_choice.add_item("Interface scale %d%%" % roundi(scale_value * 100.0))
	box.add_child(scale_choice)

	palette_choice = OptionButton.new()
	for palette_name in Settings.PALETTE_NAMES:
		palette_choice.add_item("Colours: " + palette_name)
	box.add_child(palette_choice)

	reduced_motion_check = CheckBox.new()
	reduced_motion_check.text = "Reduced motion (fewer moving effects as they are added)"
	box.add_child(reduced_motion_check)

	box.add_child(_heading("Keys — click one, then press the new key"))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 140
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	key_grid = GridContainer.new()
	key_grid.columns = 2
	key_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_grid.add_theme_constant_override("h_separation", 16)
	scroll.add_child(key_grid)

	for action in Actions.ORDER:
		var action_label := Label.new()
		action_label.text = Actions.label(action)
		action_label.custom_minimum_size.x = 220
		key_grid.add_child(action_label)

		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_begin_capture.bind(action))
		key_grid.add_child(button)
		key_buttons[action] = button

	var reset_button := Button.new()
	reset_button.text = "Restore default keys"
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.pressed.connect(_reset_keys)
	box.add_child(reset_button)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(500, 44)
	box.add_child(status)

	confirmed.connect(_apply)
	canceled.connect(_stop_capture)


func open_dialog() -> void:
	scale_choice.select(Settings.UI_SCALES.find(Settings.ui_scale))
	palette_choice.select(Settings.palette_mode)
	reduced_motion_check.button_pressed = Settings.reduced_motion
	draft_bindings = Actions.export_bindings()
	capturing_action = &""
	status.text = ""
	_refresh_key_buttons()
	popup_centered_clamped(Vector2i(560, 520), 0.95)


func _heading(text_value: String) -> Label:
	var heading := Label.new()
	heading.text = text_value
	heading.add_theme_font_size_override("font_size", 18)
	return heading


func _refresh_key_buttons() -> void:
	for action in Actions.ORDER:
		var button: Button = key_buttons[action]

		if action == capturing_action:
			button.text = "Press a key…"
			continue

		var codes: Array = draft_bindings.get(str(action), [])
		var names: PackedStringArray = []

		for code in codes:
			names.append(Actions.code_text(action, int(code)))

		button.text = " / ".join(names) if not names.is_empty() else "unbound"


func _begin_capture(action: StringName) -> void:
	capturing_action = action
	status.text = "Press the new key for “%s”. (Esc closes this window without applying.)" % Actions.label(action)
	_refresh_key_buttons()


func _stop_capture() -> void:
	capturing_action = &""


func _reset_keys() -> void:
	draft_bindings = Actions.default_bindings()
	capturing_action = &""
	status.text = "Default keys restored. Press Apply to keep them."
	_refresh_key_buttons()


func _input(event: InputEvent) -> void:
	if capturing_action == &"" or not visible:
		return

	var key_event := event as InputEventKey

	if key_event == null or not key_event.pressed or key_event.echo:
		return

	get_viewport().set_input_as_handled()

	if key_event.keycode == KEY_ESCAPE:
		status.text = "Key change cancelled."
		_stop_capture()
		_refresh_key_buttons()
		return

	var code: int = int(key_event.physical_keycode) if Actions.uses_physical_keys(capturing_action) else int(key_event.keycode)

	if code <= 0:
		return

	_assign_key(capturing_action, code)
	_stop_capture()
	_refresh_key_buttons()


# The new key becomes the action's first binding. Any other action using the
# same key loses it, so one key never triggers two commands.
func _assign_key(action: StringName, code: int) -> void:
	var moved_from: String = ""

	for other in Actions.ORDER:
		if other == action:
			continue

		if Actions.uses_physical_keys(other) != Actions.uses_physical_keys(action):
			continue

		var other_codes: Array = draft_bindings.get(str(other), [])

		if other_codes.has(code):
			other_codes.erase(code)
			draft_bindings[str(other)] = other_codes
			moved_from = Actions.label(other)

	var codes: Array = draft_bindings.get(str(action), [])
	codes.erase(code)
	codes.push_front(code)
	draft_bindings[str(action)] = codes

	var key_name: String = Actions.code_text(action, code)

	if moved_from.is_empty():
		status.text = "“%s” is now %s. Press Apply to keep it." % [Actions.label(action), key_name]
	else:
		status.text = "“%s” is now %s (taken from “%s”). Press Apply to keep it." % [Actions.label(action), key_name, moved_from]


func _apply() -> void:
	_stop_capture()

	var scale_index: int = maxi(scale_choice.selected, 0)
	Settings.ui_scale = Settings.UI_SCALES[scale_index]
	Settings.palette_mode = maxi(palette_choice.selected, 0)
	Settings.reduced_motion = reduced_motion_check.button_pressed

	Actions.apply_bindings(draft_bindings)
	Settings.key_bindings = Actions.export_bindings()

	var saved: bool = Settings.save_settings()
	settings_applied.emit()

	if not saved:
		push_warning("Could not write user://settings.cfg; settings apply for this session only.")
