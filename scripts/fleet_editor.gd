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
var assignment_choice: OptionButton
var start_station: OptionButton
var start_button: Button
var store_button: Button
var capacity_button: Button
var speed_button: Button
var wagon_choice: OptionButton
var wagon_details: Label
var attach_button: Button
var detach_button: Button
var selected_id: int = 1

func configure(owner_game: Node) -> void:
	game = owner_game
	title = "Fleet"
	ok_button_text = "Close"
	size = Vector2i(670, 610)
	exclusive = true
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 100
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	balance = Label.new()
	balance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(balance)
	var purchase := HBoxContainer.new()
	box.add_child(purchase)
	model_choice = OptionButton.new()
	model_choice.clip_text = true
	model_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for model in Fleet.MODELS:
		model_choice.add_item("%s — £%d" % [Fleet.MODELS[model]["name"], Fleet.MODELS[model]["price"]])
		model_choice.set_item_metadata(model_choice.item_count - 1, model)
	purchase.add_child(model_choice)
	model_choice.item_selected.connect(_model_changed)
	buy_button = _button(purchase, "Buy", _buy)
	model_details = Label.new()
	model_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(model_details)
	train_list = ItemList.new()
	train_list.custom_minimum_size.y = 145
	box.add_child(train_list)
	train_list.item_selected.connect(_select_train)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size = Vector2(0, 65)
	box.add_child(details)
	var rename_row := HBoxContainer.new()
	box.add_child(rename_row)
	name_field = LineEdit.new()
	name_field.max_length = 40
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rename_row.add_child(name_field)
	rename_button = _button(rename_row, "Rename", _rename)
	var actions := HFlowContainer.new()
	box.add_child(actions)
	assignment_choice = OptionButton.new()
	assignment_choice.clip_text = true
	assignment_choice.custom_minimum_size.x = 180
	actions.add_child(assignment_choice)
	assign_button = _button(actions, "Assign", _assign)
	service_button = _button(actions, "Withdraw service", _toggle_service)
	sell_button = _button(actions, "Sell", _sell)
	var start_row := HFlowContainer.new()
	box.add_child(start_row)
	start_station = OptionButton.new()
	for key in game.ServiceRoutes.STATIONS:
		start_station.add_item("Start at " + game.ServiceRoutes.STATIONS[key].name)
		start_station.set_item_metadata(start_station.item_count - 1, key)
	start_row.add_child(start_station)
	start_button = _button(start_row, "Start new passenger service", _start_service)
	store_button = _button(start_row, "Store & remove route", _store_service)
	var upgrades := HFlowContainer.new()
	box.add_child(upgrades)
	capacity_button = _button(upgrades, "Upgrade capacity", _upgrade.bind("capacity"))
	speed_button = _button(upgrades, "Upgrade speed", _upgrade.bind("speed"))
	var consist_row := HFlowContainer.new()
	box.add_child(consist_row)
	wagon_choice = OptionButton.new()
	wagon_choice.clip_text = true
	wagon_choice.custom_minimum_size.x = 180
	consist_row.add_child(wagon_choice)
	attach_button = _button(consist_row, "Attach wagon", _edit_consist.bind(false))
	detach_button = _button(consist_row, "Remove last of type", _edit_consist.bind(true))
	wagon_choice.item_selected.connect(func(_index: int) -> void: _describe_wagon())
	wagon_details = Label.new()
	wagon_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(wagon_details)
	status = Label.new()
	status.custom_minimum_size = Vector2(0, 70)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "One train per route; multiple passenger routes can run together. Start a stored passenger train on a clear platform, then edit it in Routes. Withdraw an extra service to its first station before storing/removing it. Use Save to keep changes."
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
	popup_centered_clamped(Vector2i(700, 620), 0.95)

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
	details.text = "%s | %d %s | %.0f px/s | £%d/s\nUpgrades: capacity %d/3, speed %d/3\n%s" % [model["name"], Fleet.capacity(train), "seats" if model["kind"] == "passenger" else "logs", Fleet.speed(train), Fleet.running_cost(train), train["capacity_level"], train["speed_level"], game.fleet_train_status(selected_id)]
	var previous: String = str(assignment_choice.get_selected_metadata()) if assignment_choice.item_count > 0 else ""
	assignment_choice.clear()
	for key in game.service_keys():
		if game.ServiceRoutes.kind(key) != model.kind: continue
		assignment_choice.add_item(game.services[key].name)
		assignment_choice.set_item_metadata(assignment_choice.item_count - 1, key)
		if key == previous: assignment_choice.select(assignment_choice.item_count - 1)
	assign_button.text = "Replace route's train"
	start_button.disabled = service != "" or model.kind != "passenger"
	start_station.disabled = start_button.disabled
	store_button.disabled = not game.passenger_services.has(service)
	for kind in ["capacity", "speed"]:
		var button: Button = capacity_button if kind == "capacity" else speed_button
		var base: int = (250 if model.kind == "passenger" else 300) if kind == "capacity" else (200 if model.kind == "passenger" else 250)
		var level := int(train[kind + "_level"])
		var price := base * (level + 1)
		button.text = "%s: maximum" % kind.capitalize() if level >= 3 else "Upgrade %s (£%d)" % [kind, price]
		button.disabled = level >= 3 or game.money < price
		if kind == "speed" and Fleet.speed(train) >= Fleet.Consists.speed_limit(train):
			button.disabled = true
			button.tooltip_text = "Attached stock already limits speed; remove it before buying another speed upgrade."
	details.text += "\nConsist: locomotive + %d vehicles | Length %.0f px" % [train.get("wagons", []).size(), Fleet.length(train)]
	wagon_choice.clear()
	for stock in Fleet.Consists.STOCK:
		if Fleet.Consists.STOCK[stock].kind != model.kind: continue
		wagon_choice.add_item(Fleet.Consists.STOCK[stock].name)
		wagon_choice.set_item_metadata(wagon_choice.item_count - 1, stock)
	_describe_wagon()
	assign_button.disabled = service != ""
	sell_button.text = "Sell (£%d)" % Fleet.sale_price(train)
	sell_button.disabled = service != ""
	sell_button.tooltip_text = "Only stored trains can be sold. Refund: half the model and upgrade purchase costs."
	service_button.disabled = service == ""
	if service != "":
		var enabled: bool = game.service_enabled(service)
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
	status.text = game.assign_fleet_train(selected_id, assignment_choice.get_selected_metadata())
	refresh()

func _sell() -> void:
	status.text = game.sell_fleet_train(selected_id)
	refresh()

func _toggle_service() -> void:
	status.text = game.toggle_fleet_service(selected_id)
	refresh()

func _start_service() -> void:
	status.text = game.start_passenger_service(selected_id, start_station.get_selected_metadata())
	refresh()

func _store_service() -> void:
	status.text = game.remove_passenger_service(selected_id)
	refresh()

func _upgrade(kind: String) -> void:
	status.text = game.upgrade_fleet_train(selected_id, kind)
	refresh()

func _describe_wagon() -> void:
	if wagon_choice.item_count == 0: return
	var stock: String = wagon_choice.get_selected_metadata()
	var wagon: Dictionary = Fleet.Consists.STOCK[stock]
	var train := Fleet.find(game.fleet, selected_id)
	wagon_details.text = "%s: £%d | +%d %s | +32 px | Speed limit %.0f px/s | +£%d/s\nRemoval refunds £%d. Edit stored trains or empty trains at their first stop. Long consists need straight clearance on both sides of every stop and use routes that never revisit a tile, except a planned reversal at a stop or the closing first stop of a Loop. Loop approaches must continue straight through the first stop." % [wagon.name, wagon.price, wagon.capacity, "seats" if wagon.kind == "passenger" else "logs", wagon.speed, wagon.cost, int(wagon.price / 2)]
	attach_button.disabled = train.get("wagons", []).size() >= Fleet.Consists.MAX_WAGONS or game.money < int(wagon.price)
	detach_button.disabled = not train.get("wagons", []).has(stock)

func _edit_consist(remove: bool) -> void:
	status.text = game.edit_consist(selected_id, wagon_choice.get_selected_metadata(), remove)
	refresh()
