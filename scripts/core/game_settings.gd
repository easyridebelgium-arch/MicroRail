extends RefCounted
## Player settings that belong to the player, not to a save file:
## UI scale, colour palette, reduced motion and key bindings.
## Stored in user://settings.cfg and shared by every game.
##
## All members are static, so any script can read them without an autoload:
##     if GameSettings.reduced_motion: ...

const NotificationPolicy = preload("res://scripts/core/notification_policy.gd")
static var notification_rules: Dictionary = NotificationPolicy.defaults()

const SETTINGS_PATH: String = "user://settings.cfg"

## Offered scales. The window scales everything; main.gd cancels that for the
## map camera, so only the interface grows.
const UI_SCALES: Array[float] = [1.0, 1.25, 1.5, 1.75, 2.0]

enum PaletteMode {
	DEFAULT,
	COLOUR_BLIND,
	HIGH_CONTRAST
}

const PALETTE_NAMES: Array[String] = [
	"Default",
	"Colour-blind safe",
	"High contrast"
]

static var ui_scale: float = 1.0
static var palette_mode: int = PaletteMode.DEFAULT
static var reduced_motion: bool = false
static var fullscreen: bool = false
## Restore the previous desktop window when leaving fullscreen.
static var _windowed_mode: Window.Mode = Window.MODE_MAXIMIZED

## Hides the title and key hints and shortens the status text. Always on at 175%
## and above, where the header would otherwise fill the window.
static var compact_header: bool = false
static var map_visible: bool = true
static var goals_visible: bool = true

## {action name: [key codes]} as saved. Empty means "use the defaults".
static var key_bindings: Dictionary = {}
## {action name: [mouse button indices]} as saved.
static var mouse_bindings: Dictionary = {}


static func load_settings() -> void:
	var config := ConfigFile.new()

	if config.load(SETTINGS_PATH) != OK:
		return

	ui_scale = nearest_scale(float(config.get_value("display", "ui_scale", 1.0)))
	palette_mode = clampi(
		int(config.get_value("display", "palette", PaletteMode.DEFAULT)),
		0,
		PaletteMode.size() - 1
	)
	reduced_motion = bool(config.get_value("display", "reduced_motion", false))
	compact_header = bool(config.get_value("display", "compact_header", false))
	fullscreen = bool(config.get_value("display", "fullscreen", false))
	map_visible = bool(config.get_value("panels", "map_visible", true))
	goals_visible = bool(config.get_value("panels", "goals_visible", true))

	notification_rules = NotificationPolicy.normalize(config.get_value("notifications", "rules", {}))

	var saved_bindings: Variant = config.get_value("input", "bindings", {})
	key_bindings = saved_bindings if saved_bindings is Dictionary else {}
	var saved_mouse: Variant = config.get_value("input", "mouse_bindings", {})
	mouse_bindings = saved_mouse if saved_mouse is Dictionary else {}


## Returns true when the file was written.
static func save_settings() -> bool:
	var config := ConfigFile.new()

	config.set_value("display", "ui_scale", ui_scale)
	config.set_value("display", "palette", palette_mode)
	config.set_value("display", "reduced_motion", reduced_motion)
	config.set_value("display", "compact_header", compact_header)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("panels", "map_visible", map_visible)
	config.set_value("panels", "goals_visible", goals_visible)
	config.set_value("input", "bindings", key_bindings)
	config.set_value("input", "mouse_bindings", mouse_bindings)
	config.set_value("notifications", "rules", NotificationPolicy.normalize(notification_rules))

	return config.save(SETTINGS_PATH) == OK


## Applies the settings that act on the window itself.
static func apply(window: Window) -> void:
	# Use the real window size: enlarging it reveals more map, rather than
	# enlarging a fixed 1280x720 canvas. UI scaling still works independently.
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_size = Vector2i.ZERO
	window.content_scale_factor = ui_scale
	apply_fullscreen(window)


static func apply_fullscreen(window: Window) -> void:
	var currently_fullscreen: bool = window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	if fullscreen == currently_fullscreen:
		return
	if fullscreen:
		_windowed_mode = window.mode if window.mode in [Window.MODE_WINDOWED, Window.MODE_MAXIMIZED] else Window.MODE_MAXIMIZED
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = _windowed_mode


static func toggle_fullscreen(window: Window) -> void:
	fullscreen = not fullscreen
	apply_fullscreen(window)
	if not save_settings():
		push_warning("Could not save fullscreen preference; it applies for this session only.")


static func use_compact_header() -> bool:
	return compact_header or ui_scale >= 1.75


static func nearest_scale(value: float) -> float:
	var best: float = UI_SCALES[0]

	for candidate in UI_SCALES:
		if absf(candidate - value) < absf(best - value):
			best = candidate

	return best
