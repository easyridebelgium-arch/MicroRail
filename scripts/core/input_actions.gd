extends RefCounted
## Every command goes through Godot's InputMap using these action names, so
## keys and mouse buttons can be remapped. Letter shortcuts use the logical
## key. Camera movement uses the physical key position, so WASD stays under
## the left hand on any keyboard layout.

const TOGGLE_PAUSE: StringName = &"toggle_pause"
const TOGGLE_MAP: StringName = &"toggle_map"
const TOGGLE_GOALS: StringName = &"toggle_goals"
const TOGGLE_INSPECT: StringName = &"toggle_inspect"
const TOGGLE_LOG: StringName = &"toggle_log"
const RESET_CAMERA: StringName = &"reset_camera"
const CANCEL: StringName = &"cancel"
const CAMERA_UP: StringName = &"camera_up"
const CAMERA_DOWN: StringName = &"camera_down"
const CAMERA_LEFT: StringName = &"camera_left"
const CAMERA_RIGHT: StringName = &"camera_right"
const CAMERA_FAST: StringName = &"camera_fast"

const BUILD: StringName = &"build"
const DEMOLISH: StringName = &"demolish"
const CAMERA_PAN: StringName = &"camera_pan"
const ZOOM_IN: StringName = &"zoom_in"
const ZOOM_OUT: StringName = &"zoom_out"

## Keyboard actions shown on the settings screen.
const ORDER: Array[StringName] = [
	TOGGLE_PAUSE,
	TOGGLE_MAP,
	TOGGLE_GOALS,
	TOGGLE_INSPECT,
	TOGGLE_LOG,
	RESET_CAMERA,
	CANCEL,
	CAMERA_UP,
	CAMERA_DOWN,
	CAMERA_LEFT,
	CAMERA_RIGHT,
	CAMERA_FAST
]

## Mouse actions shown on the settings screen.
const MOUSE_ORDER: Array[StringName] = [
	BUILD,
	DEMOLISH,
	CAMERA_PAN,
	ZOOM_IN,
	ZOOM_OUT
]

const MAX_KEY_CODE: int = 1 << 26
const MAX_MOUSE_BUTTON: int = 9


static func label(action: StringName) -> String:
	match action:
		TOGGLE_PAUSE: return "Pause / resume"
		TOGGLE_MAP: return "Show / hide network map"
		TOGGLE_GOALS: return "Show / hide objectives"
		TOGGLE_INSPECT: return "Inspect mode"
		TOGGLE_LOG: return "Show / hide event log"
		RESET_CAMERA: return "Reset camera"
		CANCEL: return "Cancel"
		CAMERA_UP: return "Camera up"
		CAMERA_DOWN: return "Camera down"
		CAMERA_LEFT: return "Camera left"
		CAMERA_RIGHT: return "Camera right"
		CAMERA_FAST: return "Camera fast (hold)"
		BUILD: return "Build track"
		DEMOLISH: return "Remove track"
		CAMERA_PAN: return "Pan camera"
		ZOOM_IN: return "Zoom in"
		ZOOM_OUT: return "Zoom out"

	return str(action)


static func uses_physical_keys(action: StringName) -> bool:
	return action in [
		CAMERA_UP,
		CAMERA_DOWN,
		CAMERA_LEFT,
		CAMERA_RIGHT,
		CAMERA_FAST
	]


static func uses_mouse(action: StringName) -> bool:
	return action in MOUSE_ORDER


static func default_keys(action: StringName) -> PackedInt32Array:
	match action:
		TOGGLE_PAUSE: return PackedInt32Array([KEY_SPACE])
		TOGGLE_MAP: return PackedInt32Array([KEY_M])
		TOGGLE_GOALS: return PackedInt32Array([KEY_G])
		TOGGLE_INSPECT: return PackedInt32Array([KEY_I])
		TOGGLE_LOG: return PackedInt32Array([KEY_L])
		RESET_CAMERA: return PackedInt32Array([KEY_HOME])
		CANCEL: return PackedInt32Array([KEY_ESCAPE])
		CAMERA_UP: return PackedInt32Array([KEY_W, KEY_UP])
		CAMERA_DOWN: return PackedInt32Array([KEY_S, KEY_DOWN])
		CAMERA_LEFT: return PackedInt32Array([KEY_A, KEY_LEFT])
		CAMERA_RIGHT: return PackedInt32Array([KEY_D, KEY_RIGHT])
		CAMERA_FAST: return PackedInt32Array([KEY_SHIFT])

	return PackedInt32Array()


static func default_mouse_buttons(action: StringName) -> PackedInt32Array:
	match action:
		BUILD: return PackedInt32Array([MOUSE_BUTTON_LEFT])
		DEMOLISH: return PackedInt32Array([MOUSE_BUTTON_RIGHT])
		CAMERA_PAN: return PackedInt32Array([MOUSE_BUTTON_MIDDLE])
		ZOOM_IN: return PackedInt32Array([MOUSE_BUTTON_WHEEL_UP])
		ZOOM_OUT: return PackedInt32Array([MOUSE_BUTTON_WHEEL_DOWN])

	return PackedInt32Array()


static func default_bindings() -> Dictionary:
	var result: Dictionary = {}

	for action in ORDER:
		result[str(action)] = Array(default_keys(action))

	return result


static func default_mouse_bindings() -> Dictionary:
	var result: Dictionary = {}

	for action in MOUSE_ORDER:
		result[str(action)] = Array(default_mouse_buttons(action))

	return result


static func register_defaults() -> void:
	_install_keys(default_bindings())
	_install_mouse(default_mouse_bindings())


static func apply_bindings(saved: Dictionary) -> void:
	var merged: Dictionary = default_bindings()

	for action in ORDER:
		var name: String = str(action)

		if not saved.has(name) or not saved[name] is Array:
			continue

		var codes: Array = []

		for code in saved[name]:
			if _is_valid_code(code) and not codes.has(int(code)):
				codes.append(int(code))

		merged[name] = codes

	_install_keys(merged)


static func apply_mouse_bindings(saved: Dictionary) -> void:
	var merged: Dictionary = default_mouse_bindings()

	for action in MOUSE_ORDER:
		var name: String = str(action)

		if not saved.has(name) or not saved[name] is Array:
			continue

		var codes: Array = []

		for code in saved[name]:
			if _is_valid_mouse(code) and not codes.has(int(code)):
				codes.append(int(code))

		merged[name] = codes

	_install_mouse(merged)


static func export_bindings() -> Dictionary:
	var result: Dictionary = {}

	for action in ORDER:
		result[str(action)] = Array(current_keys(action))

	return result


static func export_mouse_bindings() -> Dictionary:
	var result: Dictionary = {}

	for action in MOUSE_ORDER:
		result[str(action)] = Array(current_mouse_buttons(action))

	return result


static func current_keys(action: StringName) -> PackedInt32Array:
	var codes := PackedInt32Array()

	if not InputMap.has_action(action):
		return codes

	for event in InputMap.action_get_events(action):
		var key_event := event as InputEventKey

		if key_event == null:
			continue

		if uses_physical_keys(action):
			codes.append(int(key_event.physical_keycode))
		else:
			codes.append(int(key_event.keycode))

	return codes


static func current_mouse_buttons(action: StringName) -> PackedInt32Array:
	var codes := PackedInt32Array()

	if not InputMap.has_action(action):
		return codes

	for event in InputMap.action_get_events(action):
		var mouse_event := event as InputEventMouseButton

		if mouse_event == null:
			continue

		codes.append(int(mouse_event.button_index))

	return codes


static func key_label(action: StringName) -> String:
	return _join_names(current_keys(action), action, false)


static func mouse_label(action: StringName) -> String:
	return _join_names(current_mouse_buttons(action), action, true)


static func code_text(action: StringName, code: int) -> String:
	if uses_mouse(action):
		return mouse_button_text(code)

	var logical: int = code

	if uses_physical_keys(action) and DisplayServer.get_name() != "headless":
		logical = int(DisplayServer.keyboard_get_keycode_from_physical(code as Key))

	return OS.get_keycode_string(logical as Key)


static func mouse_button_text(code: int) -> String:
	match code:
		MOUSE_BUTTON_LEFT: return "Left mouse"
		MOUSE_BUTTON_RIGHT: return "Right mouse"
		MOUSE_BUTTON_MIDDLE: return "Middle mouse"
		MOUSE_BUTTON_WHEEL_UP: return "Wheel up"
		MOUSE_BUTTON_WHEEL_DOWN: return "Wheel down"
		MOUSE_BUTTON_WHEEL_LEFT: return "Wheel left"
		MOUSE_BUTTON_WHEEL_RIGHT: return "Wheel right"
		MOUSE_BUTTON_XBUTTON1: return "Mouse 4"
		MOUSE_BUTTON_XBUTTON2: return "Mouse 5"

	return "Mouse button %d" % code


static func _join_names(codes: PackedInt32Array, action: StringName, mouse: bool) -> String:
	var names: PackedStringArray = []

	for code in codes:
		names.append(mouse_button_text(code) if mouse else code_text(action, code))

	if names.is_empty():
		return "unbound"

	return " / ".join(names)


static func _is_valid_code(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false

	var number: float = float(value)

	if not is_finite(number) or number != floor(number):
		return false

	return number > 0.0 and number < float(MAX_KEY_CODE)


static func _is_valid_mouse(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false

	var number: float = float(value)

	if not is_finite(number) or number != floor(number):
		return false

	return number >= 1.0 and number <= float(MAX_MOUSE_BUTTON)


static func _install_keys(bindings: Dictionary) -> void:
	for action in ORDER:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

		InputMap.action_erase_events(action)

		for code in bindings.get(str(action), []):
			InputMap.action_add_event(action, _make_key_event(action, int(code)))


static func _install_mouse(bindings: Dictionary) -> void:
	for action in MOUSE_ORDER:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

		InputMap.action_erase_events(action)

		for code in bindings.get(str(action), []):
			var event := InputEventMouseButton.new()
			event.button_index = code as MouseButton
			InputMap.action_add_event(action, event)


static func _make_key_event(action: StringName, code: int) -> InputEventKey:
	var event := InputEventKey.new()

	if uses_physical_keys(action):
		event.physical_keycode = code as Key
	else:
		event.keycode = code as Key

	return event
