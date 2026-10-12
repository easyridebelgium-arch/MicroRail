extends ConfirmationDialog

const Services = preload("res://scripts/service_routes.gd")
var game: Node
var draft: Dictionary
var service_choice: OptionButton
var route_mode: OptionButton
var heading: Label
var name_field: LineEdit
var stop_list: ItemList
var station_choice: OptionButton
var status: Label
var editing_controls: HBoxContainer
var add_button: Button
var remove_button: Button
var up_button: Button
var down_button: Button
var platform_choice: OptionButton
var waypoint_leg: OptionButton
var waypoint_list: ItemList
var waypoint_x: SpinBox
var waypoint_y: SpinBox
var waypoint_add: Button
var selected_service_key: String = "passenger"

func configure(owner_game: Node) -> void:
	game = owner_game
	title = "Routes"
	size = Vector2i(580, 510)
	ok_button_text = "Apply"
	dialog_hide_on_ok = false
	exclusive = true
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 100
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	service_choice = OptionButton.new()
	service_choice.add_item("Passenger service")
	service_choice.add_item("Freight service")
	service_choice.set_item_metadata(0, "passenger")
	service_choice.set_item_metadata(1, "freight")
	service_choice.clip_text = true
	box.add_child(service_choice)
	service_choice.item_selected.connect(_select_service)
	name_field = LineEdit.new()
	name_field.max_length = 40
	name_field.placeholder_text = "Route name"
	box.add_child(name_field)
	route_mode = OptionButton.new()
	route_mode.add_item("Shuttle — return through stops in reverse")
	route_mode.add_item("Loop — last stop returns directly to first")
	box.add_child(route_mode)
	route_mode.item_selected.connect(_select_mode)
	heading = Label.new()
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(heading)
	stop_list = ItemList.new()
	stop_list.custom_minimum_size.y = 140
	box.add_child(stop_list)
	editing_controls = HBoxContainer.new()
	box.add_child(editing_controls)
	station_choice = OptionButton.new()
	for key in Services.STATIONS:
		station_choice.add_item(Services.STATIONS[key]["name"])
		station_choice.set_item_metadata(station_choice.item_count - 1, key)
	editing_controls.add_child(station_choice)
	add_button = _button("Add", _add_stop)
	remove_button = _button("Remove", _remove_stop)
	up_button = _button("Up", _move_stop.bind(-1))
	down_button = _button("Down", _move_stop.bind(1))
	platform_choice = OptionButton.new()
	for number in [1, 2, 3]: platform_choice.add_item("Platform %d" % number)
	platform_choice.tooltip_text = "Platform used at the selected stop. Platforms 2 and 3 are sidings beside the station tile; build and connect them first."
	platform_choice.disabled = true
	platform_choice.item_selected.connect(_select_platform)
	editing_controls.add_child(platform_choice)
	stop_list.item_selected.connect(_show_platform)
	var waypoint_heading := Label.new()
	waypoint_heading.text = "Pass-through waypoints — no loading or station wait"
	box.add_child(waypoint_heading)
	waypoint_leg = OptionButton.new()
	box.add_child(waypoint_leg)
	waypoint_leg.item_selected.connect(func(_index: int) -> void: _refresh_waypoints())
	waypoint_list = ItemList.new()
	waypoint_list.custom_minimum_size.y = 90
	box.add_child(waypoint_list)
	var point_controls := HFlowContainer.new()
	box.add_child(point_controls)
	for axis in ["X", "Y"]:
		var label := Label.new()
		label.text = axis
		point_controls.add_child(label)
		var spin := SpinBox.new()
		spin.max_value = 79 if axis == "X" else 49
		spin.step = 1
		spin.custom_minimum_size.x = 84
		point_controls.add_child(spin)
		if axis == "X": waypoint_x = spin
		else: waypoint_y = spin
	for text in ["Add waypoint", "Remove", "Up", "Down"]:
		var button := Button.new()
		button.text = text
		match text:
			"Add waypoint":
				waypoint_add = button
				button.pressed.connect(_add_waypoint)
			"Remove": button.pressed.connect(_remove_waypoint)
			"Up": button.pressed.connect(_move_waypoint.bind(-1))
			"Down": button.pressed.connect(_move_waypoint.bind(1))
		point_controls.add_child(button)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 60
	box.add_child(status)
	confirmed.connect(_apply)

func _button(title_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title_text
	button.pressed.connect(callback)
	editing_controls.add_child(button)
	return button

func open_editor(cell: Vector2i = Vector2i(-1, -1)) -> void:
	draft = game.services.duplicate(true)
	service_choice.clear()
	for key in game.service_keys():
		var train: Dictionary = game.Fleet.assigned(game.fleet, key)
		service_choice.add_item("%s — #%d" % [game.services[key].name, int(train.id)])
		service_choice.set_item_metadata(service_choice.item_count - 1, key)
	service_choice.select(0)
	selected_service_key = "passenger"
	_show_service()
	if cell.x >= 0:
		waypoint_x.value = cell.x
		waypoint_y.value = cell.y
		status.text = "Cell %d,%d selected. Choose the service and leg, click Add waypoint, then Apply." % [cell.x, cell.y]
	popup_centered_clamped(Vector2i(680, 620), 0.95)

func _key() -> String:
	return selected_service_key

func _capture_name(key: String) -> void:
	draft[key]["name"] = name_field.text.strip_edges()

func _select_service(index: int) -> void:
	_capture_name(_key())
	selected_service_key = service_choice.get_item_metadata(index)
	_show_service()

func _show_service() -> void:
	name_field.text = draft[_key()]["name"]
	editing_controls.visible = Services.is_passenger_key(_key())
	route_mode.visible = Services.is_passenger_key(_key())
	route_mode.select(1 if draft[_key()].get("mode", "shuttle") == "loop" else 0)
	_refresh_stops()
	status.text = "Mode/stop/waypoint edits require an empty train at the first station. Shuttle returns through stops in reverse; Loop closes from last to first, with its own waypoints. Names can change mid-trip." if Services.is_passenger_key(_key()) else "Forest: load → Terminal: unload → return. Waypoint edits require the train at the forest. Return trips use the selected path in reverse."

func _refresh_stops(selected: int = -1) -> void:
	stop_list.clear()
	var stops: Array = draft[_key()]["stops"]
	# Platform choices only make sense for stops that remain on the route.
	var platforms: Dictionary = draft[_key()].get("platforms", {})
	for stop in platforms.keys():
		if not stops.has(stop): platforms.erase(stop)
	draft[_key()]["platforms"] = platforms
	for index in range(stops.size()):
		var key: String = stops[index]
		var stop_name: String = Services.STATIONS[key]["name"] if Services.STATIONS.has(key) else ("Forest — load logs" if key == "forest" else "Terminal — unload logs")
		var chosen: int = int(draft[_key()].get("platforms", {}).get(key, 1))
		stop_list.add_item("%d. %s%s" % [index + 1, stop_name, "" if chosen == 1 else " — platform %d" % chosen])
	if selected >= 0 and selected < stops.size():
		stop_list.select(selected)
	_show_platform(selected)
	var itinerary := stops.duplicate()
	if draft[_key()].get("mode", "shuttle") == "loop": itinerary.append(stops[0])
	else:
		var back := stops.slice(0, stops.size() - 1)
		back.reverse()
		itinerary.append_array(back)
	var names: PackedStringArray = []
	for stop in itinerary: names.append(str(stop).to_upper())
	heading.text = "Stop sequence: " + " → ".join(names)
	_refresh_legs()

func _show_platform(index: int) -> void:
	var stops: Array = draft[_key()]["stops"]
	platform_choice.disabled = index < 0 or index >= stops.size()
	if platform_choice.disabled: return
	platform_choice.select(int(draft[_key()].get("platforms", {}).get(stops[index], 1)) - 1)

func _select_platform(choice: int) -> void:
	var selected: PackedInt32Array = stop_list.get_selected_items()
	if selected.is_empty(): return
	var stop: String = draft[_key()]["stops"][selected[0]]
	var platforms: Dictionary = draft[_key()].get("platforms", {})
	if choice == 0: platforms.erase(stop)
	else: platforms[stop] = choice + 1
	draft[_key()]["platforms"] = platforms
	_refresh_stops(selected[0])
	status.text = "Platform changed in draft. Apply checks that the siding is connected and long enough for the train."

func _select_mode(index: int) -> void:
	draft[_key()]["mode"] = "loop" if index == 1 else "shuttle"
	_refresh_stops()
	status.text = "Mode changed in draft. Apply at the first station with an empty train. Switching to Shuttle removes closing-leg waypoints."

func _add_stop() -> void:
	var key: String = station_choice.get_selected_metadata()
	var stops: Array = draft[_key()]["stops"]
	if stops.has(key):
		status.text = "That station is already on this route. Select it and use Up or Down."
		return
	stops.append(key)
	_refresh_stops(stops.size() - 1)

func _remove_stop() -> void:
	var selected: PackedInt32Array = stop_list.get_selected_items()
	if selected.is_empty():
		return
	var stops: Array = draft[_key()]["stops"]
	if stops.size() <= 2:
		status.text = "Keep at least two stops. Add another station before removing one."
		return
	stops.remove_at(selected[0])
	_refresh_stops(mini(selected[0], stops.size() - 1))

func _move_stop(direction: int) -> void:
	var selected: PackedInt32Array = stop_list.get_selected_items()
	if selected.is_empty():
		return
	var stops: Array = draft[_key()]["stops"]
	var index: int = selected[0]
	var target: int = index + direction
	if target < 0 or target >= stops.size():
		return
	var stop: String = stops[index]
	stops[index] = stops[target]
	stops[target] = stop
	_refresh_stops(target)

func _apply() -> void:
	_capture_name(_key())
	status.text = game.apply_service_routes(draft)


func _refresh_legs() -> void:
	var stops: Array = draft[_key()]["stops"]
	var old: String = str(waypoint_leg.get_selected_metadata()) if waypoint_leg.item_count > 0 else ""
	waypoint_leg.clear()
	var valid_keys: Array[String] = []
	for index in range(Services.leg_count(stops, draft[_key()].get("mode", "shuttle"))):
		var key := Services.leg_key(stops, index)
		valid_keys.append(key)
		waypoint_leg.add_item("%s → %s" % [str(stops[index]).to_upper(), str(stops[(index + 1) % stops.size()]).to_upper()])
		waypoint_leg.set_item_metadata(index, key)
		if key == old: waypoint_leg.select(index)
	var directives: Dictionary = draft[_key()].get("waypoints", {}).duplicate(true)
	for key in directives.keys():
		if not valid_keys.has(key): directives.erase(key)
	draft[_key()]["waypoints"] = directives
	_refresh_waypoints()

func _points() -> Array:
	var key: String = waypoint_leg.get_selected_metadata()
	var directives: Dictionary = draft[_key()]["waypoints"]
	return directives.get(key, [])

func _refresh_waypoints(selected: int = -1) -> void:
	waypoint_list.clear()
	if waypoint_leg.item_count == 0: return
	var points := _points()
	for index in range(points.size()):
		waypoint_list.add_item("%d. Track %d,%d" % [index + 1, int(points[index][0]), int(points[index][1])])
	if selected >= 0 and selected < points.size(): waypoint_list.select(selected)

func _add_waypoint() -> void:
	var point: Array = [int(waypoint_x.value), int(waypoint_y.value)]
	var cell := Vector2i(point[0], point[1])
	if not game.can_place_waypoint(cell):
		status.text = "Choose existing track outside station/industry platforms."
		return
	var points := _points()
	if points.size() >= 16 or points.has(point):
		status.text = "Use up to 16 different waypoint cells per leg."
		return
	points.append(point)
	draft[_key()]["waypoints"][str(waypoint_leg.get_selected_metadata())] = points
	_refresh_waypoints(points.size() - 1)
	status.text = "Waypoint added to draft. Apply validates the complete path; closing discards edits."

func _remove_waypoint() -> void:
	var selected := waypoint_list.get_selected_items()
	if selected.is_empty(): return
	var points := _points()
	points.remove_at(selected[0])
	if points.is_empty(): draft[_key()]["waypoints"].erase(str(waypoint_leg.get_selected_metadata()))
	_refresh_waypoints(mini(selected[0], points.size() - 1))

func _move_waypoint(direction: int) -> void:
	var selected := waypoint_list.get_selected_items()
	if selected.is_empty(): return
	var points := _points()
	var index: int = selected[0]
	var target := index + direction
	if target < 0 or target >= points.size(): return
	var point: Array = points[index]
	points[index] = points[target]
	points[target] = point
	_refresh_waypoints(target)
