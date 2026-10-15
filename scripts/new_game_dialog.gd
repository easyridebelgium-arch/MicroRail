extends ConfirmationDialog
## Shared title/in-game chooser. Acceptance starts a company; it never writes a save.
signal start_requested(slot: int, configuration: Dictionary)
const Config = preload("res://scripts/core/new_game_config.gd")
const Slots = preload("res://scripts/core/save_slots.gd")
var slot := 1
var mode_choice: OptionButton
var seed_field: LineEdit
var random_seed_button: Button
var _seed_picker := RandomNumberGenerator.new()
var city_count: SpinBox
var city_controls: VBoxContainer
var explanation: Label
var validation: Dictionary = {}

func _ready() -> void:
	_seed_picker.randomize()
	title = "New game"
	ok_button_text = "Start new game"
	get_cancel_button().text = "Cancel"
	exclusive = true
	dialog_hide_on_ok = false
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	mode_choice = OptionButton.new()
	mode_choice.add_item("City sandbox")
	mode_choice.add_item("Tutorial — three stations")
	mode_choice.item_selected.connect(func(_index: int) -> void: refresh())
	box.add_child(mode_choice)
	city_controls = VBoxContainer.new()
	box.add_child(city_controls)
	var seed_label := Label.new()
	seed_label.text = "Map seed (share it with the city count)"
	city_controls.add_child(seed_label)
	seed_field = LineEdit.new()
	seed_field.text = "42"
	seed_field.max_length = 19
	seed_field.placeholder_text = "0 to 9223372036854775807"
	seed_field.text_changed.connect(func(_text: String) -> void: refresh())
	var seed_row := HBoxContainer.new()
	city_controls.add_child(seed_row)
	seed_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(seed_field)
	random_seed_button = Button.new()
	random_seed_button.text = "Random"
	random_seed_button.accessibility_name = "Choose random map seed"
	random_seed_button.tooltip_text = "Choose a different map seed. Keep or copy the number to recreate this layout with the same city count."
	random_seed_button.pressed.connect(_choose_random_seed)
	seed_row.add_child(random_seed_button)
	var count_label := Label.new()
	count_label.text = "Cities (80 × 50 map)"
	city_controls.add_child(count_label)
	city_count = SpinBox.new()
	city_count.min_value = 3
	city_count.max_value = 8
	city_count.step = 1
	city_count.value = 4
	city_count.value_changed.connect(func(_value: float) -> void: refresh())
	city_controls.add_child(city_count)
	explanation = Label.new()
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(explanation)
	confirmed.connect(_accept)
	close_requested.connect(hide)
	refresh()

func open_dialog(target_slot: int) -> void:
	if target_slot < 1 or target_slot > Slots.COUNT: return
	slot = target_slot
	title = "New game — Slot %d" % slot
	refresh()
	popup_centered_clamped(Vector2i(620, 480), 0.95)

func refresh() -> void:
	city_controls.visible = mode_choice.selected == 0
	validation = Config.validate({"mode": "cities", "seed": seed_field.text, "city_count": city_count.value} if mode_choice.selected == 0 else {"mode": "tutorial"})
	explanation.text = validation.message + "\n\nStarting replaces the current game in memory. Existing saved files change only when you Save. Cancel keeps the current game."
	get_ok_button().disabled = not validation.ok

func _choose_random_seed() -> void:
	# This UI-only generator never consumes the live simulation's seeded stream.
	# Combine two 32-bit draws into the supported non-negative 63-bit range.
	var next_seed: int = ((_seed_picker.randi() & 0x7fffffff) << 32) | _seed_picker.randi()
	if str(next_seed) == seed_field.text:
		next_seed = 0 if next_seed == 9223372036854775807 else next_seed + 1
	seed_field.text = str(next_seed)
	refresh()

func _accept() -> void:
	if city_count.get_line_edit().has_focus(): city_count.apply()
	refresh()
	if not validation.ok: return
	var configuration: Dictionary = validation.configuration.duplicate(true)
	hide()
	start_requested.emit(slot, configuration)
