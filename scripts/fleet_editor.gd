extends AcceptDialog

const Fleet = preload("res://scripts/fleet.gd")
var game: Node
var train_list: ItemList
var model_choice: OptionButton
var model_details: Label
var details: Label
var balance: Label
var name_field: LineEdit
var buy_button: Button
var assign_button: Button
var sell_button: Button
var service_button: Button
var rename_button: Button
var status: Label
var selected_id: int = 1

func configure(owner_game: Node) -> void:
	game = owner_game
	title = "Fleet"
	ok_button_text = "Close"
	size = Vector2i(670, 610)
	exclusive = true
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	balance = Label.new()
	box.add_child(balance)
	var purchase := HBoxContainer.new()
	box.add_child(purchase)
	model_choice = OptionButton.new()
	model_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for model in Fleet.MODELS:
		model_choice.add_item("%s — £%d" % [Fleet.MODELS[model]["name"], Fleet.MODELS[model]["price"]])
		model_choice.set_item_metadata(model_choice.item_count - 1, model)
	purchase.add_child(model_choice)
	model_choice.item_selected.connect(_model_changed)
	buy_button = _button(purchase, "Buy", _buy)
	model_details = Label.new()
	box.add_child(model_details)
	train_list = ItemList.new()
	train_list.custom_minimum_size.y = 145
	box.add_child(train_list)
	train_list.item_selected.connect(_select_train)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size = Vector2(620, 65)
	box.add_child(details)
	var rename_row := HBoxContainer.new()
	box.add_child(rename_row)
	name_field = LineEdit.new()
	name_field.max_length = 40
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rename_row.add_child(name_field)
	rename_button = _button(rename_row, "Rename", _rename)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	assign_button = _button(actions, "Assign", _assign)
	service_button = _button(actions, "Withdraw service", _toggle_service)
	sell_button = _button(actions, "Sell", _sell)
	status = Label.new()
	status.custom_minimum_size = Vector2(620, 70)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	var hint := Label.new()
	hint.text = "One train per service. Spares stay off-map without running costs.\nChanges apply immediately; use Save after closing. The game stays paused."
	box.add_child(hint)

func _button(parent: Node, title_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title_text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func open_editor() -> void:
	status.text = "Choose a model to buy or select an owned train to manage it."
	refresh()
	popup_centered()

func refresh() -> void:
	game._sync_fleet_upgrades()
	balance.text = "Balance: £%d | Owned: %d / %d | Net fleet investment: £%d" % [game.money, game.fleet["trains"].size(), Fleet.MAX_TRAINS, game.total_vehicle_cost]
	train_list.clear()
	var selection: int = 0
	for train in game.fleet["trains"]:
		var assignment: String = "Stored" if train["service"] == "" else game.services[train["service"]]["name"]
		train_list.add_item("#%d  %s — %s" % [train["id"], train["name"], assignment])
		train_list.set_item_metadata(train_list.item_count - 1, int(train["id"]))
		if int(train["id"]) == selected_id:
			selection = train_list.item_count - 1
	train_list.select(selection)
	_select_train(selection)
	_model_changed(model_choice.selected)

func _model_changed(_index: int) -> void:
	var model: Dictionary = Fleet.MODELS[model_choice.get_selected_metadata()]
	model_details.text = "%d %s | Speed %.0f px/s | Running £%d/s while active" % [model["capacity"], "seats" if model["kind"] == "passenger" else "logs", model["speed"], model["running_cost"]]
	buy_button.disabled = game.money < int(model["price"]) or game.fleet["trains"].size() >= Fleet.MAX_TRAINS

func _select_train(index: int) -> void:
	selected_id = int(train_list.get_item_metadata(index))
	var train: Dictionary = Fleet.find(game.fleet, selected_id)
	var model: Dictionary = Fleet.MODELS[train["model"]]
	var service: String = train["service"]
	name_field.text = train["name"]
	details.text = "%s | %d %s | %.0f px/s | £%d/s\nUpgrades: capacity %d/3, speed %d/3\n%s" % [model["name"], Fleet.capacity(train), "seats" if model["kind"] == "passenger" else "logs", Fleet.speed(train), model["running_cost"], train["capacity_level"], train["speed_level"], game.fleet_train_status(selected_id)]
	assign_button.text = "Assign to %s" % model["kind"]
	assign_button.disabled = service != ""
	sell_button.text = "Sell (£%d)" % Fleet.sale_price(train)
	sell_button.disabled = service != ""
	sell_button.tooltip_text = "Only stored trains can be sold. Refund: half the model and upgrade purchase costs."
	service_button.disabled = service == ""
	if service != "":
		var enabled: bool = game.passenger_service_enabled if service == "passenger" else game.freight_train.service_enabled
		service_button.text = "Withdraw service" if enabled else "Enable service"
	else:
		service_button.text = "Withdraw service"

func _buy() -> void:
	var result: Dictionary = game.buy_fleet_train(model_choice.get_selected_metadata())
	if result["ok"]:
		selected_id = int(result["id"])
	status.text = result["message"]
	refresh()

func _rename() -> void:
	status.text = game.rename_fleet_train(selected_id, name_field.text)
	refresh()

func _assign() -> void:
	var train: Dictionary = Fleet.find(game.fleet, selected_id)
	status.text = game.assign_fleet_train(selected_id, Fleet.MODELS[train["model"]]["kind"])
	refresh()

func _sell() -> void:
	status.text = game.sell_fleet_train(selected_id)
	refresh()

func _toggle_service() -> void:
	status.text = game.toggle_fleet_service(selected_id)
	refresh()
