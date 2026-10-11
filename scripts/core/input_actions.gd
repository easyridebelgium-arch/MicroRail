extends RefCounted
## Every keyboard command goes through Godot's InputMap using these action
## names, so keys can be remapped and other devices added later.
##
## Letter shortcuts use the logical key (the letter printed on the key, as the
## game did before). Camera movement uses the physical key position, so WASD
## stays under the left hand on any keyboard layout.

const TOGGLE_PAUSE: StringName = &"toggle_pause"
const TOGGLE_MAP: StringName = &"toggle_map"
const TOGGLE_GOALS: StringName = &"toggle_goals"
const TOGGLE_INSPECT: StringName = &"toggle_inspect"
const RESET_CAMERA: StringName = &"reset_camera"
const CANCEL: StringName = &"cancel"
const CAMERA_UP: StringName = &"camera_up"
const CAMERA_DOWN: StringName = &"camera_down"
const CAMERA_LEFT: StringName = &"camera_left"
const CAMERA_RIGHT: StringName = &"camera_right"
const CAMERA_FAST: StringName = &"camera_fast"

## Order used by the settings screen.
const ORDER: Array[StringName] = [
	TOGGLE_PAUSE,
	TOGGLE_MAP,
	TOGGLE_GOALS,
	TOGGLE_INSPECT,
	RESET_CAMERA,
	CANCEL,
	CAMERA_UP,
	CAMERA_DOWN,
	CAMERA_LEFT,
	CAMERA_RIGHT,
	CAMERA_FAST
]

const MAX_KEY_CODE: int = 1 << 26


static func label(action: StringName) -> String:
	match action:
		TOGGLE_PAUSE: return "Pause / resume"
		TOGGLE_MAP: return "Show / hide network map"
		TOGGLE_GOALS: return "Show / hide objectives"
		TOGGLE_INSPECT: return "Inspect mode"
		RESET_CAMERA: return "Reset camera"
		CANCEL: return "Cancel"
		CAMERA_UP: return "Camera up"
		CAMERA_DOWN: return "Camera down"
		CAMERA_LEFT: return "Camera left"
		CAMERA_RIGHT: return "Camera right"
		CAMERA_FAST: return "Camera fast (hold)"

	return str(action)


static func uses_physical_keys(action: StringName) -> bool:
	return action in [
		CAMERA_UP,
		CAMERA_DOWN,
		CAMERA_LEFT,
		CAMERA_RIGHT,
		CAMERA_FAST
	]


static func default_keys(action: StringName) -> PackedInt32Array:
	match action:
		TOGGLE_PAUSE: return PackedInt32Array([KEY_SPACE])
		TOGGLE_MAP: return PackedInt32Array([KEY_M])
		TOGGLE_GOALS: return PackedInt32Array([KEY_G])
		TOGGLE_INSPECT: return PackedInt32Array([KEY_I])
		RESET_CAMERA: return PackedInt32Array([KEY_HOME])
		CANCEL: return PackedInt32Array([KEY_ESCAPE])
		CAMERA_UP: return PackedInt32Array([KEY_W, KEY_UP])
		CAMERA_DOWN: return PackedInt32Array([KEY_S, KEY_DOWN])
		CAMERA_LEFT: return PackedInt32Array([KEY_A, KEY_LEFT])
		CAMERA_RIGHT: return PackedInt32Array([KEY_D, KEY_RIGHT])
		CAMERA_FAST: return PackedInt32Array([KEY_SHIFT])

	return PackedInt32Array()


## Defaults for every action, as {action name: [key codes]}.
static func default_bindings() -> Dictionary:
	var result: Dictionary = {}

	for action in ORDER:
		result[str(action)] = Array(default_keys(action))

	return result


## Registers every action with its default keys. Safe to call more than once.
static func register_defaults() -> void:
	_install(default_bindings())


## Applies saved bindings. Unknown actions and invalid codes are ignored, so a
## damaged settings file can never leave the game without controls.
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

		# An empty list is allowed: the player may unbind an action.
		merged[name] = codes

	_install(merged)


## The bindings currently in the InputMap, as {action name: [key codes]}.
static func export_bindings() -> Dictionary:
	var result: Dictionary = {}

	for action in ORDER:
		result[str(action)] = Array(current_keys(action))

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


## Text for the player, such as "Space" or "W / Up". On other keyboard layouts
## a physical key shows the letter printed on it.
static func key_label(action: StringName) -> String:
	var names: PackedStringArray = []

	for code in current_keys(action):
		names.append(code_text(action, code))

	if names.is_empty():
		return "unbound"

	return " / ".join(names)


static func code_text(action: StringName, code: int) -> String:
	var logical: int = code

	# The headless display server (used by the tests) cannot translate keys.
	if uses_physical_keys(action) and DisplayServer.get_name() != "headless":
		logical = int(DisplayServer.keyboard_get_keycode_from_physical(code as Key))

	return OS.get_keycode_string(logical as Key)


static func _is_valid_code(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false

	var number: float = float(value)

	if not is_finite(number) or number != floor(number):
		return false

	return number > 0.0 and number < float(MAX_KEY_CODE)


static func _install(bindings: Dictionary) -> void:
	for action in ORDER:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

		InputMap.action_erase_events(action)

		for code in bindings.get(str(action), []):
			InputMap.action_add_event(action, _make_event(action, int(code)))


static func _make_event(action: StringName, code: int) -> InputEventKey:
	var event := InputEventKey.new()

	if uses_physical_keys(action):
		event.physical_keycode = code as Key
	else:
		event.keycode = code as Key

	return event
