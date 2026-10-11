extends PanelContainer
## Nonmodal, scrollable tools. Displaying inspection never advances simulation.
signal changed
signal planning_changed(enabled: bool)
signal apply_plan
signal discard_plan
var plan_toggle: CheckButton
var plan_summary: Label
var plan_controls: VBoxContainer
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
		button.pressed.connect(emit_signal.bind(entry[1]))
		actions.add_child(button)
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
