extends RefCounted
## Optional, repeatable assistance. No purchases, route edits or simulation commands.
const Guide = preload("res://scripts/core/first_service.gd")
var game: Node
var dialog: AcceptDialog
var heading: Label
var steps: Label
var detail: Label
var action_button: Button
var button: Button
var snapshot: Dictionary = {}
var elapsed := 0.0
var active := false
var was_paused := true

func configure(owner_game: Node) -> void:
	game = owner_game
	dialog = AcceptDialog.new()
	dialog.title = "First service guide"
	dialog.ok_button_text = "Close guide"
	dialog.exclusive = true
	dialog.confirmed.connect(close_guide)
	dialog.canceled.connect(close_guide)
	dialog.close_requested.connect(close_guide)
	dialog.theme = game.game_menu.theme
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 100
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	dialog.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	heading = _label(column)
	steps = _label(column)
	detail = _label(column)
	action_button = Button.new()
	action_button.pressed.connect(_perform)
	column.add_child(action_button)
	game.get_node("Interface").add_child(dialog)
	button = Button.new()
	button.text = "Guide"
	button.custom_minimum_size = Vector2(96, 40)
	button.icon = preload("res://assets/ui/feedback/icons/first_service_guide.tres")
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 24)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.tooltip_text = "Optional first-service checklist. Available again from the game menu."
	button.pressed.connect(open_guide)
	game.get_node("Interface/ConstructionHistory").add_child(button)
	refresh(0.0, true)

func _label(column: Control) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)
	return label

func open_guide() -> void:
	# Stop costs/time while reading, then restore the prior pause choice on Close.
	# Build/Fleet and Resume actions deliberately choose their own pause state.
	if game.is_dragging or game.right_pending:
		game._show_notice("Finish or cancel the track stroke before opening the guide.")
		return
	if not active:
		was_paused = game.paused
	active = true
	game.paused = true
	refresh(0.0, true)
	dialog.popup_centered_clamped(Vector2i(620, 480), 0.85)
	dialog.get_ok_button().grab_focus()

func close_guide(restore_pause: bool = true) -> void:
	if restore_pause and active: game.paused = was_paused
	active = false
	dialog.hide()
	game._update_toolbar()

func refresh(delta: float, force: bool = false) -> void:
	elapsed += delta
	if not force and (elapsed < 0.25 or not (dialog.visible or game.objective_panel.visible)): return
	elapsed = 0.0
	snapshot = Guide.inspect(game)
	var lines: PackedStringArray = []
	for index in range(snapshot.rows.size()):
		var row: Dictionary = snapshot.rows[index]
		lines.append(("[Done] " if row.done else "[Next] " if snapshot.next == index else "[ ] ") + str(row.title))
	heading.text = "First passenger journey complete — %d delivered. Keep improving your railway." % snapshot.delivered if snapshot.delivered > 0 else "Your first city service" if snapshot.city_mode else "Your first tutorial service"
	steps.text = "\n".join(lines)
	detail.text = snapshot.suggestion + "\n\n" + ("These checks describe the current company. You can reopen this guide at any time; it does not reset progress or pay rewards." if snapshot.complete else str(snapshot.rows[snapshot.next].hint))
	action_button.visible = not snapshot.complete
	if not snapshot.complete: action_button.text = snapshot.rows[snapshot.next].button

func _perform() -> void:
	refresh(0.0, true)
	if snapshot.complete: return
	var action: String = snapshot.rows[snapshot.next].action
	if not game.construction_plan.is_empty():
		detail.text = "Apply or discard the construction draft in Overlays first. The guide keeps your draft intact."
		return
	close_guide(false)
	match action:
		"stations":
			game.paused = true
			if not game.city_builder.active: game.city_builder.toggle()
		"connect":
			game.paused = true
			game._select_straight_track()
		"fleet": game._open_fleet_editor()
		"run":
			game.paused = false
			game._clear_construction_history()
	game._update_toolbar()
