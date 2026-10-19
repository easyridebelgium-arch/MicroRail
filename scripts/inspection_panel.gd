extends PanelContainer
## Nonmodal, scrollable tools. Displaying inspection never advances simulation.
signal changed
signal planning_changed(enabled: bool)
signal apply_plan
signal discard_plan
signal pick_corridor(which: int)
signal pick_blueprint(which: int)
signal save_blueprint
signal import_blueprints
signal export_blueprint
signal use_loop_waypoint
signal place_passing_loop
signal place_blueprint
var loop_routes: Button
var loop_route_hint: Label
var loop_fit: Label
var loop_length: SpinBox
var loop_orientation: OptionButton
var blueprint_name: LineEdit
var blueprint_search: LineEdit
var blueprint_choice: OptionButton
var blueprint_status: Label
var blueprint_names: Array[String] = []
signal draft_corridor
var corridor_label: Label
var corridor_spacing: SpinBox
var corridor_mode: OptionButton
var plan_toggle: CheckButton
var plan_summary: Label
var plan_controls: VBoxContainer
var block_toggle: CheckButton
var route_toggle: CheckButton
var routes := false
var blocks := false
var congestion := false
var selected_service := ""
var selector: OptionButton
var summary: Label
var _keys: Array[String] = []
var _titles: Array[String] = []

func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var title := Label.new()
	title.text = "Network inspection"
	column.add_child(title)
	for entry in [["Service paths", "routes"], ["Signal blocks", "blocks"], ["Measured waiting", "congestion"]]:
		var toggle := CheckButton.new()
		toggle.text = entry[0]
		toggle.focus_mode = Control.FOCUS_NONE
		var field: String = entry[1]
		if field == "routes": route_toggle = toggle
		if field == "blocks": block_toggle = toggle
		toggle.toggled.connect(func(enabled: bool) -> void:
			set(field, enabled)
			changed.emit())
		column.add_child(toggle)
	plan_toggle = CheckButton.new()
	plan_toggle.text = "Draft construction"
	plan_toggle.focus_mode = Control.FOCUS_NONE
	plan_toggle.toggled.connect(func(enabled: bool) -> void: planning_changed.emit(enabled))
	column.add_child(plan_toggle)
	plan_controls = VBoxContainer.new()
	column.add_child(plan_controls)
	plan_controls.hide()
	plan_summary = Label.new()
	plan_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plan_controls.add_child(plan_summary)
	var actions := HFlowContainer.new()
	plan_controls.add_child(actions)
	for entry in [["Apply plan", "apply_plan"], ["Discard plan", "discard_plan"]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void:
			if entry[1] == "apply_plan": apply_plan.emit()
			else: discard_plan.emit())
		actions.add_child(button)
	corridor_label = Label.new()
	corridor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plan_controls.add_child(corridor_label)
	var endpoints := HFlowContainer.new()
	plan_controls.add_child(endpoints)
	for which in [1, 2]:
		var pick := Button.new()
		pick.text = "Pick start" if which == 1 else "Pick end"
		pick.focus_mode = Control.FOCUS_NONE
		pick.pressed.connect(func() -> void: pick_corridor.emit(which))
		endpoints.add_child(pick)
	corridor_spacing = SpinBox.new()
	corridor_spacing.min_value = 3
	corridor_spacing.max_value = 30
	corridor_spacing.value = 5
	corridor_spacing.prefix = "Spacing"
	corridor_spacing.suffix = "tiles"
	plan_controls.add_child(corridor_spacing)
	corridor_mode = OptionButton.new()
	for text in ["Automatic signals", "Manual stop signals", "Remove all corridor signals"]: corridor_mode.add_item(text)
	plan_controls.add_child(corridor_mode)
	var stage := Button.new()
	stage.text = "Draft corridor signals"
	stage.focus_mode = Control.FOCUS_NONE
	stage.pressed.connect(func() -> void: draft_corridor.emit())
	plan_controls.add_child(stage)
	var loop_title := Label.new()
	loop_title.text = "Guided passing loop"
	plan_controls.add_child(loop_title)
	var loop_hint := Label.new()
	loop_hint.text = "Choose total length including both switches and which side the loop occupies. Click the first switch: leftmost for horizontal, topmost for vertical. Review the draft before Apply; assign its waypoint in Routes. Options affect the next preview; discard an old draft before replacing it. Check whole-train fit; branches are not chosen automatically."
	loop_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plan_controls.add_child(loop_hint)
	var length_label := Label.new()
	length_label.text = "Loop length (tiles including switches)"
	plan_controls.add_child(length_label)
	loop_length = SpinBox.new()
	loop_length.min_value = preload("res://scripts/core/passing_loop_template.gd").WIDTH
	loop_length.max_value = preload("res://scripts/core/passing_loop_template.gd").MAX_LENGTH
	loop_length.step = 1
	loop_length.value = 9
	plan_controls.add_child(loop_length)
	loop_orientation = OptionButton.new()
	loop_orientation.fit_to_longest_item = false
	for text in preload("res://scripts/core/passing_loop_template.gd").ORIENTATIONS: loop_orientation.add_item(text)
	plan_controls.add_child(loop_orientation)
	var loop_button := Button.new()
	loop_button.text = "Preview passing loop"
	loop_button.tooltip_text = "Nothing is purchased until Apply plan. Matching rails are reused; incompatible track refuses placement."
	loop_button.pressed.connect(func() -> void: place_passing_loop.emit())
	plan_controls.add_child(loop_button)
	loop_fit = Label.new()
	loop_fit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loop_fit.text = "Place a passing-loop preview to compare owned train lengths."
	plan_controls.add_child(loop_fit)
	loop_routes = Button.new()
	loop_routes.text = "Use loop waypoint in Routes"
	loop_routes.disabled = true
	loop_routes.pressed.connect(func() -> void: use_loop_waypoint.emit())
	plan_controls.add_child(loop_routes)
	loop_route_hint = Label.new()
	loop_route_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loop_route_hint.text = "Preview and apply a loop first. Then choose a service and leg in Routes; Add waypoint changes only its draft."
	plan_controls.add_child(loop_route_hint)
	var blueprint_title := Label.new()
	blueprint_title.text = "Track blueprints"
	plan_controls.add_child(blueprint_title)
	var corners := HFlowContainer.new()
	plan_controls.add_child(corners)
	for which in [1, 2]:
		var corner := Button.new()
		corner.text = "Pick corner %d" % which
		corner.focus_mode = Control.FOCUS_NONE
		corner.pressed.connect(func() -> void: pick_blueprint.emit(which))
		corners.add_child(corner)
	blueprint_name = LineEdit.new()
	blueprint_name.placeholder_text = "Name for saved layout"
	blueprint_name.max_length = 40
	plan_controls.add_child(blueprint_name)
	var save_design := Button.new()
	save_design.text = "Save selected rectangle"
	save_design.focus_mode = Control.FOCUS_NONE
	save_design.pressed.connect(func() -> void: save_blueprint.emit())
	plan_controls.add_child(save_design)
	blueprint_search = LineEdit.new()
	blueprint_search.placeholder_text = "Search saved layouts"
	blueprint_search.text_changed.connect(func(_text: String) -> void: changed.emit())
	plan_controls.add_child(blueprint_search)
	blueprint_choice = OptionButton.new()
	blueprint_choice.fit_to_longest_item = false
	blueprint_choice.focus_mode = Control.FOCUS_NONE
	plan_controls.add_child(blueprint_choice)
	var place_design := Button.new()
	place_design.text = "Place selected blueprint"
	place_design.focus_mode = Control.FOCUS_NONE
	place_design.pressed.connect(func() -> void: place_blueprint.emit())
	plan_controls.add_child(place_design)
	var sharing := HFlowContainer.new()
	plan_controls.add_child(sharing)
	for entry in [["Import JSON", "import_blueprints"], ["Export selected", "export_blueprint"]]:
		var share := Button.new()
		share.text = entry[0]
		share.focus_mode = Control.FOCUS_NONE
		share.pressed.connect(func() -> void:
			if entry[1] == "import_blueprints": import_blueprints.emit()
			else: export_blueprint.emit())
		sharing.add_child(share)
	blueprint_status = Label.new()
	blueprint_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plan_controls.add_child(blueprint_status)
	selector = OptionButton.new()
	selector.fit_to_longest_item = false
	selector.custom_minimum_size.x = 260
	selector.focus_mode = Control.FOCUS_NONE
	selector.item_selected.connect(func(index: int) -> void:
		selected_service = _keys[index]
		changed.emit())
	column.add_child(selector)
	summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size.x = 260
	column.add_child(summary)

func refresh(trains: Array, text: String) -> void:
	var keys: Array[String] = [""]
	var titles: Array[String] = ["All services"]
	for train in trains:
		keys.append(train.key)
		titles.append("#%d %s" % [train.id, train.name])
	if keys != _keys or titles != _titles:
		_keys = keys
		_titles = titles
		selector.clear()
		for title in titles: selector.add_item(title)
		var index := keys.find(selected_service)
		if index < 0:
			index = 0
			selected_service = ""
		selector.select(index)
	summary.text = text

func refresh_blueprints(designs: Array) -> void:
	var selected := selected_blueprint()
	var names: Array[String] = []
	for design in designs:
		if blueprint_search.text.strip_edges().is_empty() or blueprint_search.text.strip_edges().to_lower() in str(design.name).to_lower(): names.append(design.name)
	if names == blueprint_names: return
	blueprint_names = names
	blueprint_choice.clear()
	for blueprint_title_name in names: blueprint_choice.add_item(blueprint_title_name)
	if names.is_empty():
		blueprint_choice.add_item("No matching blueprints")
		blueprint_choice.disabled = true
	else:
		blueprint_choice.disabled = false
		blueprint_choice.select(maxi(0, names.find(selected)))

func selected_blueprint() -> String:
	var index := blueprint_choice.selected
	return blueprint_names[index] if index >= 0 and index < blueprint_names.size() else ""

func show_service(key: String) -> void:
	selected_service = key
	route_toggle.button_pressed = true
	var index := _keys.find(key)
	if index >= 0: selector.select(index)

func show_authority(key: String) -> void:
	show_service(key)
	block_toggle.button_pressed = true
