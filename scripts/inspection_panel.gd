extends PanelContainer
## Nonmodal, scrollable tools. Displaying inspection never advances simulation.
signal changed
var routes := false
var blocks := false
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
	for entry in [["Service paths", "routes"], ["Signal blocks", "blocks"]]:
		var toggle := CheckButton.new()
		toggle.text = entry[0]
		toggle.focus_mode = Control.FOCUS_NONE
		var field: String = entry[1]
		toggle.toggled.connect(func(enabled: bool) -> void:
			set(field, enabled)
			changed.emit())
		column.add_child(toggle)
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
