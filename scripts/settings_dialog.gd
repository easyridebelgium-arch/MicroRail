extends ConfirmationDialog
## Accessibility and controls: UI scale, colour palette, reduced motion and
## key bindings. Nothing changes until the player presses Apply.

signal main_menu_requested
signal settings_applied

const Settings = preload("res://scripts/core/game_settings.gd")
const Actions = preload("res://scripts/core/input_actions.gd")

var slow_check: CheckBox
var notification_choices: Dictionary = {}

var scale_choice: OptionButton
var autosave_choice: OptionButton
var terrain_choice: OptionButton
var grid_check: CheckBox
var palette_choice: OptionButton
var reduced_motion_check: CheckBox
var compact_header_check: CheckBox
var fullscreen_check: CheckBox
var key_grid: GridContainer
var status: Label

var draft_bindings: Dictionary = {}
var draft_mouse_bindings: Dictionary = {}
var key_buttons: Dictionary = {}
var capturing_action: StringName = &""


func configure(in_game: bool = false) -> void:
	title = "Settings"
	size = Vector2i(560, 520)
	ok_button_text = "Apply"
	exclusive = true

	# Everything scrolls, so the Apply and Cancel buttons stay reachable at
	# any interface scale or window size.
	var outer := ScrollContainer.new()
	outer.custom_minimum_size = Vector2(0, 120)
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(outer)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(box)

	box.add_child(_heading("Display"))
	fullscreen_check = CheckBox.new()
	fullscreen_check.text = "Fullscreen"
	box.add_child(fullscreen_check)

	scale_choice = OptionButton.new()
	for scale_value in Settings.UI_SCALES:
		scale_choice.add_item("Interface scale %d%%" % roundi(scale_value * 100.0))
	box.add_child(scale_choice)

	palette_choice = OptionButton.new()
	for palette_name in Settings.PALETTE_NAMES:
		palette_choice.add_item("Colours: " + palette_name)
	box.add_child(palette_choice)

	terrain_choice = OptionButton.new()
	for ground_name in Settings.TERRAIN_NAMES: terrain_choice.add_item("Ground: " + ground_name)
	terrain_choice.tooltip_text = "Cosmetic appearance only. Snow does not affect trains. High contrast uses the plain background."
	box.add_child(terrain_choice)
	grid_check = CheckBox.new()
	grid_check.text = "Show map grid"
	grid_check.tooltip_text = "Hide grid lines for a cleaner view. High-contrast mode always shows the grid."
	box.add_child(grid_check)

	reduced_motion_check = CheckBox.new()
	reduced_motion_check.text = "Reduced motion (fewer moving effects as they are added)"
	box.add_child(reduced_motion_check)

	compact_header_check = CheckBox.new()
	compact_header_check.text = "Compact header (always on at 175% and above)"
	box.add_child(compact_header_check)

	box.add_child(_heading("Save protection"))
	autosave_choice = OptionButton.new()
	for hours in Settings.AUTOSAVE_HOURS:
		autosave_choice.add_item("Autosaves: off" if hours == 0 else "Autosave every game hour" if hours == 1 else "Autosave every %d game hours" % hours)
	autosave_choice.tooltip_text = "Three recovery copies per game slot, separate from manual saves. One game hour is about one real minute at 1×. Unfinished construction waits until it is safe. Recover via Load game or the main menu."
	box.add_child(autosave_choice)

	box.add_child(_heading("Operational alerts"))
	slow_check = CheckBox.new()
	slow_check.text = "Slow 5×/10× to 1× on new waits, deadlocks or overdue loans"
	box.add_child(slow_check)
	if in_game:
		var menu_button := Button.new()
		menu_button.text = "Return to Main Menu"
		menu_button.pressed.connect(func() -> void: hide(); main_menu_requested.emit())
		box.add_child(menu_button)

	var explanation := Label.new()
	explanation.text = "Choose notices or automatic pause for new incidents. All incidents stay in Problems history. Build and objective feedback keep their existing controls."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(explanation)
	for category in Settings.NotificationPolicy.ORDER:
		var label := Label.new()
		label.text = Settings.NotificationPolicy.LABELS[category]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
		var choice := OptionButton.new()
		for incident_mode in ["Off", "Notice", "Notice + pause"]: choice.add_item(incident_mode)
		box.add_child(choice)
		notification_choices[category] = choice

	box.add_child(_heading("Keys — click one, then press the new key"))

	key_grid = GridContainer.new()
	key_grid.columns = 2
	key_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_grid.add_theme_constant_override("h_separation", 16)
	box.add_child(key_grid)

	for action in Actions.ORDER:
		var action_label := Label.new()
		action_label.text = Actions.label(action)
		action_label.custom_minimum_size.x = 200
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

	box.add_child(_heading("Mouse buttons — click one, then press the new button"))

	var mouse_grid: GridContainer = GridContainer.new()
	mouse_grid.columns = 2
	mouse_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_grid.add_theme_constant_override("h_separation", 16)
	box.add_child(mouse_grid)

	for action in Actions.MOUSE_ORDER:
		var action_label := Label.new()
		action_label.text = Actions.label(action)
		action_label.custom_minimum_size.x = 200
		mouse_grid.add_child(action_label)

		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_begin_mouse_capture.bind(action))
		mouse_grid.add_child(button)
		key_buttons[action] = button

	var reset_mouse_button := Button.new()
	reset_mouse_button.text = "Restore default mouse buttons"
	reset_mouse_button.focus_mode = Control.FOCUS_NONE
	reset_mouse_button.pressed.connect(_reset_mouse_buttons)
	box.add_child(reset_mouse_button)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(0, 44)
	box.add_child(status)

	confirmed.connect(_apply)
	canceled.connect(_stop_capture)


func open_dialog() -> void:
	scale_choice.select(Settings.UI_SCALES.find(Settings.ui_scale))
	palette_choice.select(Settings.palette_mode)
	autosave_choice.select(maxi(0, Settings.AUTOSAVE_HOURS.find(Settings.autosave_hours)))
	terrain_choice.select(maxi(0, Settings.TERRAIN_STYLES.find(Settings.terrain_style)))
	grid_check.button_pressed = Settings.show_grid
	reduced_motion_check.button_pressed = Settings.reduced_motion
	compact_header_check.button_pressed = Settings.compact_header
	slow_check.button_pressed = Settings.slow_on_incident
	fullscreen_check.button_pressed = Settings.fullscreen
	fullscreen_check.tooltip_text = "Toggle fullscreen: " + Actions.key_label(Actions.TOGGLE_FULLSCREEN)
	var rules := Settings.NotificationPolicy.normalize(Settings.notification_rules)
	for category in notification_choices:
		notification_choices[category].select(int(rules[category]))
	draft_bindings = Actions.export_bindings()
	draft_mouse_bindings = Actions.export_mouse_bindings()
	capturing_action = &""
	status.text = ""
	_refresh_key_buttons()
	_refresh_mouse_buttons()
	popup_centered_clamped(Vector2i(560, 600), 0.95)


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


func _refresh_mouse_buttons() -> void:
	for action in Actions.MOUSE_ORDER:
		var button: Button = key_buttons[action]

		if action == capturing_action:
			button.text = "Press a button…"
			continue

		var codes: Array = draft_mouse_bindings.get(str(action), [])
		var names: PackedStringArray = []

		for code in codes:
			names.append(Actions.mouse_button_text(int(code)))

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


func _begin_mouse_capture(action: StringName) -> void:
	capturing_action = action
	status.text = "Press the new mouse button for “%s”. (Esc closes this window without applying.)" % Actions.label(action)
	_refresh_mouse_buttons()


func _reset_mouse_buttons() -> void:
	draft_mouse_bindings = Actions.default_mouse_bindings()
	capturing_action = &""
	status.text = "Default mouse buttons restored. Press Apply to keep them."
	_refresh_mouse_buttons()


func _input(event: InputEvent) -> void:
	# Window controls also work here, but never steal a key being remapped.
	if visible and capturing_action == &"" and event.is_action_pressed(Actions.TOGGLE_FULLSCREEN):
		Settings.toggle_fullscreen(get_tree().root)
		fullscreen_check.button_pressed = Settings.fullscreen
		get_viewport().set_input_as_handled()
		return
	if capturing_action == &"" or not visible:
		return

	if Actions.uses_mouse(capturing_action):
		var mouse_event := event as InputEventMouseButton

		if mouse_event == null or not mouse_event.pressed:
			return

		get_viewport().set_input_as_handled()

		if mouse_event.button_index == KEY_ESCAPE:
			status.text = "Mouse button change cancelled."
			_stop_capture()
			_refresh_mouse_buttons()
			return

		var mouse_code: int = int(mouse_event.button_index)

		if mouse_code <= 0:
			return

		_assign_mouse_button(capturing_action, mouse_code)
		_stop_capture()
		_refresh_mouse_buttons()
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


# The new mouse button becomes the action's first binding. Any other action using the
# same button loses it, so one button never triggers two commands.
func _assign_mouse_button(action: StringName, code: int) -> void:
	var moved_from: String = ""

	for other in Actions.MOUSE_ORDER:
		if other == action:
			continue

		var other_codes: Array = draft_mouse_bindings.get(str(other), [])

		if other_codes.has(code):
			other_codes.erase(code)
			draft_mouse_bindings[str(other)] = other_codes
			moved_from = Actions.label(other)

	var codes: Array = draft_mouse_bindings.get(str(action), [])
	codes.erase(code)
	codes.push_front(code)
	draft_mouse_bindings[str(action)] = codes

	var button_name: String = Actions.mouse_button_text(code)

	if moved_from.is_empty():
		status.text = "“%s” is now %s. Press Apply to keep it." % [Actions.label(action), button_name]
	else:
		status.text = "“%s” is now %s (taken from “%s”). Press Apply to keep it." % [Actions.label(action), button_name, moved_from]


func _apply() -> void:
	_stop_capture()

	var scale_index: int = maxi(scale_choice.selected, 0)
	Settings.ui_scale = Settings.UI_SCALES[scale_index]
	Settings.palette_mode = maxi(palette_choice.selected, 0)
	Settings.autosave_hours = Settings.AUTOSAVE_HOURS[maxi(0, autosave_choice.selected)]
	Settings.terrain_style = Settings.TERRAIN_STYLES[maxi(0, terrain_choice.selected)]
	Settings.show_grid = grid_check.button_pressed
	Settings.reduced_motion = reduced_motion_check.button_pressed
	Settings.compact_header = compact_header_check.button_pressed
	Settings.fullscreen = fullscreen_check.button_pressed
	Settings.slow_on_incident = slow_check.button_pressed
	for category in notification_choices:
		Settings.notification_rules[category] = notification_choices[category].selected

	Actions.apply_bindings(draft_bindings)
	Actions.apply_mouse_bindings(draft_mouse_bindings)
	Settings.key_bindings = Actions.export_bindings()
	Settings.mouse_bindings = Actions.export_mouse_bindings()

	var saved: bool = Settings.save_settings()
	settings_applied.emit()

	if not saved:
		push_warning("Could not write user://settings.cfg; settings apply for this session only.")
