extends Control
## Startup contains no live game. Continue/load use the normal atomic validator.
const Settings = preload("res://scripts/core/game_settings.gd")
const Actions = preload("res://scripts/core/input_actions.gd")
const Slots = preload("res://scripts/core/save_slots.gd")
const Preview = preload("res://scripts/core/save_preview.gd")
const Legacy = preload("res://scripts/core/legacy_migration.gd")
const SettingsWindow = preload("res://scripts/settings_dialog.gd")
const NewGameDialog = preload("res://scripts/new_game_dialog.gd")
var new_game_dialog: ConfirmationDialog
var pending_configuration: Dictionary = {}
var continue_button: Button
var slot_choice: OptionButton
var status: Label
var progress: ProgressBar
var settings_window: ConfirmationDialog
var menu: VBoxContainer
var pending_slot := 0
var pending_load := false
var pending_autosave := ""
var recovery_picker: ConfirmationDialog
var busy := false
var finishing := false
const GAME := "res://scenes/main/main.tscn"
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = preload("res://scripts/ui/shared_theme.gd").build()
	Legacy.run()
	Settings.load_settings()
	Actions.register_defaults()
	Actions.apply_bindings(Settings.key_bindings)
	Actions.apply_mouse_bindings(Settings.mouse_bindings)
	Settings.apply(get_window())
	var background := ColorRect.new()
	background.color = Color("#101923")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	menu = VBoxContainer.new()
	menu.custom_minimum_size.x = minf(420, get_viewport_rect().size.x - 32)
	menu.add_theme_constant_override("separation", 12)
	center.add_child(menu)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/branding/game_logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, minf(130, get_viewport_rect().size.y * 0.22))
	menu.add_child(logo)
	var title := Label.new()
	title.text = "MicroRail"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	menu.add_child(title)
	var latest := Preview.latest_slot()
	continue_button = _button("Continue — Slot %d" % latest if latest > 0 else "Continue — no readable save yet", func() -> void: start(latest, true))
	continue_button.disabled = latest == 0
	slot_choice = OptionButton.new()
	for slot in range(1, Slots.COUNT + 1): slot_choice.add_item(Slots.describe(slot))
	slot_choice.clip_text = true
	menu.add_child(slot_choice)
	_button("Load game", func() -> void: start(slot_choice.selected + 1, true))
	recovery_picker = preload("res://scripts/ui/autosave_picker.gd").new()
	add_child(recovery_picker)
	recovery_picker.recovery_requested.connect(func(slot: int, filename: String) -> void:
		if busy: return
		start(slot, true)
		if busy:
			pending_autosave = filename
			recovery_picker.hide())
	_button("Recover autosave…", func() -> void:
		if not busy: recovery_picker.open_slot(slot_choice.selected + 1))
	_button("Load previous save", func() -> void: start(slot_choice.selected + 1, true, true))
	new_game_dialog = NewGameDialog.new()
	new_game_dialog.theme = theme
	add_child(new_game_dialog)
	new_game_dialog.start_requested.connect(func(slot: int, configuration: Dictionary) -> void: start(slot, false, false, configuration))
	_button("New game in selected slot", func() -> void:
		if not busy: new_game_dialog.open_dialog(slot_choice.selected + 1))
	settings_window = SettingsWindow.new()
	settings_window.theme = theme
	settings_window.configure()
	settings_window.settings_applied.connect(func() -> void:
		Settings.apply(get_window())
		Actions.apply_bindings(Settings.key_bindings)
		Actions.apply_mouse_bindings(Settings.mouse_bindings)
		menu.custom_minimum_size.x = minf(420, get_viewport_rect().size.x - 32)
	)
	add_child(settings_window)
	_button("Settings", settings_window.open_dialog)
	_button("Quit", func() -> void: get_tree().quit())
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "Manual saves change only when you Save. Autosaves keep separate recovery copies. Load validates the selected game."
	menu.add_child(status)
	progress = ProgressBar.new()
	progress.show_percentage = true
	progress.visible = false
	menu.add_child(progress)
func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	menu.add_child(button)
	return button
func start(slot: int, load_game: bool, backup: bool = false, configuration: Dictionary = {}) -> void:
	if busy or slot < 1 or slot > Slots.COUNT: return
	var validated := NewGameDialog.Config.validate(configuration if not configuration.is_empty() else {"mode": "tutorial"})
	if not validated.ok:
		status.text = validated.message
		return
	pending_configuration = validated.configuration
	pending_slot = slot
	pending_load = load_game
	pending_autosave = ""
	set_meta("backup", backup)
	busy = true
	status.text = "Loading game resources…"
	progress.visible = true
	progress.value = 0
	var result := ResourceLoader.load_threaded_request(GAME)
	if result != OK:
		busy = false
		status.text = "Could not request game resources."
		progress.hide()
func _process(_delta: float) -> void:
	if not busy or finishing: return
	var values: Array = []
	var stage := ResourceLoader.load_threaded_get_status(GAME, values)
	if not values.is_empty(): progress.value = float(values[0]) * 100
	if stage == ResourceLoader.THREAD_LOAD_LOADED:
		finishing = true
		_finish.call_deferred(ResourceLoader.load_threaded_get(GAME))
	elif stage == ResourceLoader.THREAD_LOAD_FAILED or stage == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		busy = false
		progress.hide()
		status.text = "Could not load game resources."
func _finish(scene: PackedScene) -> void:
	var game = scene.instantiate()
	game.active_save_slot = pending_slot
	game.startup_allow_cli = false
	if not pending_load and pending_configuration.get("mode") == "cities":
		game.startup_city_seed = pending_configuration.seed
		game.startup_city_count = pending_configuration.city_count
		game.startup_city_growth = pending_configuration.city_growth
		game.startup_challenge = pending_configuration.get("challenge", "")
		game.startup_terrain = pending_configuration.get("terrain", "flat")
	game.paused = true
	game.set_process(false)
	get_tree().root.add_child(game)
	game.get_node("Interface").hide()
	game.hide()
	var loaded := true
	if pending_load:
		loaded = game._load_slot(pending_slot, bool(get_meta("backup", false))) if pending_autosave.is_empty() else game._load_autosave(pending_slot, pending_autosave)
	if not loaded:
		busy = false
		finishing = false
		status.text = "Load failed: " + game.notice + " Select another slot or its previous save."
		game.queue_free()
		progress.hide()
		return
	game.get_node("Interface").show()
	game.show()
	game.set_process(true)
	get_tree().current_scene = game
	queue_free()
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Actions.TOGGLE_FULLSCREEN):
		Settings.toggle_fullscreen(get_window())
		get_viewport().set_input_as_handled()
