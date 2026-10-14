extends ConfirmationDialog

const Services = preload("res://scripts/service_routes.gd")
const Timetable = preload("res://scripts/core/timetable.gd")
var game: Node
var draft: Dictionary
var service_choice: OptionButton
var route_mode: OptionButton
var heading: Label
var style_label: LineEdit
var style_colour: OptionButton
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
var copy_controls: HFlowContainer
var headway_controls: HFlowContainer
var headway_spin: SpinBox
var headway_label: Label
var timetable_field: LineEdit
var timetable_leg: OptionButton
var arrival_minutes: SpinBox
var arrival_hint: Label
var link_controls: HFlowContainer
var link_label: Label
var unlink_button: Button
var copy_source: OptionButton
var copy_button: Button
var directive_warning: Label
var removed_waypoint_legs: Dictionary = {}

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
	copy_controls = HFlowContainer.new()
	box.add_child(copy_controls)
	var copy_label := Label.new()
	copy_label.text = "Copy route from"
	copy_controls.add_child(copy_label)
	copy_source = OptionButton.new()
	copy_source.custom_minimum_size.x = 180
	copy_source.clip_text = true
	copy_controls.add_child(copy_source)
	copy_button = Button.new()
	copy_button.text = "Copy to draft"
	copy_button.tooltip_text = "Copy stops, mode, waypoints and platforms. Keeps this service's name and train; Apply checks safety."
	copy_button.pressed.connect(_copy_route)
	copy_controls.add_child(copy_button)
	link_controls = HFlowContainer.new()
	box.add_child(link_controls)
	link_label = Label.new()
	link_controls.add_child(link_label)
	unlink_button = Button.new()
	unlink_button.text = "Unlink"
	unlink_button.tooltip_text = "Keep this route as it is but edit it independently from now on."
	unlink_button.pressed.connect(_unlink)
	link_controls.add_child(unlink_button)
	name_field = LineEdit.new()
	name_field.max_length = 40
	name_field.placeholder_text = "Route name"
	box.add_child(name_field)
	var appearance := HFlowContainer.new()
	box.add_child(appearance)
	style_label = LineEdit.new()
	style_label.max_length = 6
	style_label.custom_minimum_size.x = 90
	style_label.placeholder_text = "Route label"
	appearance.add_child(style_label)
	style_colour = OptionButton.new()
	for name in game.Presentation.NAMES: style_colour.add_item(name)
	appearance.add_child(style_colour)
	var apply_style := Button.new()
	apply_style.text = "Apply appearance"
	apply_style.tooltip_text = "Changes only the route badge/colour; linked trains share their source identity. Save to keep it."
	apply_style.pressed.connect(func() -> void: status.text = game.set_route_identity(_key(), style_label.text, style_colour.selected))
	appearance.add_child(apply_style)

	route_mode = OptionButton.new()
	route_mode.add_item("Shuttle — return through stops in reverse")
	route_mode.add_item("Loop — last stop returns directly to first")
	box.add_child(route_mode)
	route_mode.item_selected.connect(_select_mode)
	headway_controls = HFlowContainer.new()
	box.add_child(headway_controls)
	var headway_title := Label.new()
	headway_title.text = "Target headway"
	headway_controls.add_child(headway_title)
	headway_spin = SpinBox.new()
	headway_spin.min_value = 0
	headway_spin.max_value = 3600
	headway_spin.step = 5
	headway_spin.suffix = "s"
	headway_spin.custom_minimum_size.x = 110
	headway_spin.tooltip_text = "Minimum seconds between departures from the first stop, shared by every train linked to this route. 0 turns it off."
	headway_spin.value_changed.connect(_set_headway)
	headway_controls.add_child(headway_spin)
	var timetable_title := Label.new()
	timetable_title.text = "Timetable"
	headway_controls.add_child(timetable_title)
	timetable_leg = OptionButton.new()
	timetable_leg.clip_text = true
	timetable_leg.custom_minimum_size.x = 180
	timetable_leg.item_selected.connect(_select_timetable_leg)
	headway_controls.add_child(timetable_leg)
	timetable_field = LineEdit.new()
	timetable_field.placeholder_text = "Departures HH:MM, e.g. 07:00, 07:30, 18:15"
	timetable_field.custom_minimum_size.x = 260
	timetable_field.tooltip_text = "Exact departure times for the selected direction each day (one game day = 24 minutes at 1×). Empty = no timetable. Trains never leave early; late trains leave at once."
	timetable_field.text_submitted.connect(func(_text: String) -> void: _set_timetable())
	timetable_field.focus_exited.connect(_set_timetable)
	headway_controls.add_child(timetable_field)
	var arrival_title := Label.new()
	arrival_title.text = "Journey target (0 = off)"
	headway_controls.add_child(arrival_title)
	arrival_minutes = SpinBox.new()
	arrival_minutes.min_value = 0
	arrival_minutes.max_value = 1440
	arrival_minutes.step = 1
	arrival_minutes.update_on_text_changed = true
	arrival_minutes.suffix = "game min"
	arrival_minutes.custom_minimum_size.x = 160
	arrival_minutes.tooltip_text = "Target journey time for the selected direction. Scheduled departure + target sets the planned arrival; without a timetable use actual departure. One game minute = one simulated second. Reports only, no penalties."
	arrival_minutes.value_changed.connect(_set_arrival_target)
	headway_controls.add_child(arrival_minutes)
	headway_label = Label.new()
	headway_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headway_label.custom_minimum_size.x = 540
	box.add_child(headway_label)
	arrival_hint = Label.new()
	arrival_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(arrival_hint)
	heading = Label.new()
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(heading)
	stop_list = ItemList.new()
	stop_list.custom_minimum_size.y = 140
	box.add_child(stop_list)
	editing_controls = HBoxContainer.new()
	box.add_child(editing_controls)
	station_choice = OptionButton.new()
	for key in game.station_definitions():
		station_choice.add_item(game.station_definitions()[key]["name"])
		station_choice.set_item_metadata(station_choice.item_count - 1, key)
	editing_controls.add_child(station_choice)
	add_button = _button("Add", _add_stop)
	remove_button = _button("Remove", _remove_stop)
	up_button = _button("Up", _move_stop.bind(-1))
	down_button = _button("Down", _move_stop.bind(1))
	platform_choice = OptionButton.new()
	for number in [1, 2, 3]: platform_choice.add_item("Platform %d" % number)
	platform_choice.add_item("Auto")
	platform_choice.tooltip_text = "Platform used at the selected stop. Platforms 2 and 3 are sidings beside the station tile; build and connect them first. Auto picks a free platform that fits the train when you Apply."
	platform_choice.disabled = true
	platform_choice.item_selected.connect(_select_platform)
	editing_controls.add_child(platform_choice)
	stop_list.item_selected.connect(_show_platform)
	stop_list.tooltip_text = "Drag a stop to reorder it, or use Up/Down."
	stop_list.set_drag_forwarding(_stop_drag_data, _stop_can_drop, _stop_drop)
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
	directive_warning = Label.new()
	directive_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(directive_warning)
	confirmed.connect(_apply)

func _button(title_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title_text
	button.pressed.connect(callback)
	editing_controls.add_child(button)
	return button

func open_editor(cell: Vector2i = Vector2i(-1, -1)) -> void:
	game.refresh_station_choices(station_choice)
	draft = game.services.duplicate(true)
	for key in draft:
		var chosen: Dictionary = draft[key].get("platforms", {})
		for stop in draft[key].get("auto", {}): chosen[stop] = 0
		draft[key]["platforms"] = chosen
		draft[key].erase("auto")
	removed_waypoint_legs.clear()
	directive_warning.text = ""
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
	if not _set_timetable():
		for item in range(service_choice.item_count):
			if service_choice.get_item_metadata(item) == _key(): service_choice.select(item)
		return
	_capture_name(_key())
	selected_service_key = service_choice.get_item_metadata(index)
	_show_service()

func _set_headway(value: float) -> void:
	if not draft.has(_key()) or not Services.is_passenger_key(_key()): return
	if int(value) <= 0: draft[_key()].erase("headway")
	else: draft[_key()]["headway"] = int(value)

func _set_timetable() -> bool:
	if not draft.has(_key()) or not Services.is_passenger_key(_key()) or not headway_controls.visible: return true
	var parsed := Timetable.parse(timetable_field.text)
	if not parsed.ok:
		status.text = str(parsed.error)
		return false
	if timetable_leg.selected <= 0:
		if parsed.times.is_empty(): draft[_key()].erase("timetable")
		else: draft[_key()]["timetable"] = parsed.times
	else:
		var leg: String = timetable_leg.get_selected_metadata()
		var later: Dictionary = draft[_key()].get("stop_timetables", {}).duplicate(true)
		if parsed.times.is_empty(): later.erase(leg)
		else: later[leg] = parsed.times
		if later.is_empty(): draft[_key()].erase("stop_timetables")
		else: draft[_key()]["stop_timetables"] = later
	timetable_field.text = Timetable.to_text(parsed.times)
	status.text = "Timetable updated in draft. Apply to use it."
	return true

func _set_arrival_target(value: float) -> void:
	if not draft.has(_key()) or not headway_controls.visible or timetable_leg.item_count == 0: return
	var targets: Dictionary = draft[_key()].get("arrival_targets", {}).duplicate(true)
	var leg: String = timetable_leg.get_selected_metadata()
	if value <= 0: targets.erase(leg)
	else: targets[leg] = int(value)
	if targets.is_empty(): draft[_key()].erase("arrival_targets")
	else: draft[_key()]["arrival_targets"] = targets
	status.text = "Arrival target updated in draft. Apply to use on future departures."
	_refresh_arrival_hint()

func _refresh_arrival_hint() -> void:
	if not headway_controls.visible or timetable_leg.item_count == 0: return
	var result: Dictionary = game.arrival_target_guidance(_key(), draft, str(timetable_leg.get_selected_metadata()))
	arrival_hint.text = str(result.text)
	var leg: String = timetable_leg.get_selected_metadata()
	arrival_hint.text += "\nPassenger eligibility: " + ("Local (£%d) and Express (£%d) on this direct distant-station leg." % [game.PassengerRevenue.LOCAL_FARE, game.PassengerRevenue.EXPRESS_FARE] if game.PassengerClasses.distant(leg.get_slice(">", 0), leg.get_slice(">", 1), game.station_definitions()) else "Local (£%d) only on this leg; Express (£%d) waits for a direct leg between stations at least 32 tiles apart." % [game.PassengerRevenue.LOCAL_FARE, game.PassengerRevenue.EXPRESS_FARE])

func _select_timetable_leg(_index: int) -> void:
	# The text field's focus-exit captures the previous leg before this click.
	_show_timetable_times()

func _show_timetable_times() -> void:
	if timetable_leg.item_count == 0: return
	var times: Array = draft[_key()].get("timetable", []) if timetable_leg.selected == 0 else draft[_key()].get("stop_timetables", {}).get(timetable_leg.get_selected_metadata(), [])
	timetable_field.text = Timetable.to_text(times)
	arrival_minutes.set_value_no_signal(float(draft[_key()].get("arrival_targets", {}).get(timetable_leg.get_selected_metadata(), 0)))
	_refresh_arrival_hint()

func _refresh_timetable_legs() -> void:
	if not Services.is_passenger_key(_key()): return
	var previous: String = str(timetable_leg.get_selected_metadata()) if timetable_leg.item_count > 0 else ""
	var legs := Timetable.departure_legs(draft[_key()].stops, draft[_key()].get("mode", "shuttle"))
	timetable_leg.clear()
	for leg in legs:
		timetable_leg.add_item("Depart " + leg.replace(">", " → ").to_upper())
		timetable_leg.set_item_metadata(timetable_leg.item_count - 1, leg)
		if leg == previous: timetable_leg.select(timetable_leg.item_count - 1)
	var later: Dictionary = draft[_key()].get("stop_timetables", {}).duplicate(true)
	var removed: PackedStringArray = []
	for leg in later.keys():
		if not legs.has(leg) or leg == legs[0]:
			if not later[leg].is_empty(): removed.append(str(leg).replace(">", " → ").to_upper())
			later.erase(leg)
	if later.is_empty(): draft[_key()].erase("stop_timetables")
	else: draft[_key()]["stop_timetables"] = later
	var targets: Dictionary = draft[_key()].get("arrival_targets", {}).duplicate(true)
	for leg in targets.keys():
		if not legs.has(leg):
			removed.append(str(leg).replace(">", " → ").to_upper() + " (arrival target)")
			targets.erase(leg)
	if targets.is_empty(): draft[_key()].erase("arrival_targets")
	else: draft[_key()]["arrival_targets"] = targets
	if not removed.is_empty():
		var warning := "Timing instructions removed from draft for changed legs: %s. Review departure times and arrival targets before Apply." % ", ".join(removed)
		removed_waypoint_legs[_key()] = str(removed_waypoint_legs.get(_key(), "")) + "\n" + warning
		directive_warning.text = removed_waypoint_legs[_key()]
	_show_timetable_times()

func _unlink() -> void:
	draft[_key()].erase("link")
	_show_service()
	status.text = "Unlinked. This service now keeps its own route."

func _show_service() -> void:
	draft = Services.propagate(draft)
	var linked: bool = draft[_key()].has("link") and Services.is_passenger_key(_key())
	link_controls.visible = linked
	var has_headway: bool = Services.is_passenger_key(_key()) and not linked
	headway_controls.visible = has_headway
	headway_label.visible = has_headway
	arrival_hint.visible = has_headway
	if has_headway:
		headway_spin.set_value_no_signal(float(draft[_key()].get("headway", 0)))
		timetable_field.text = Timetable.to_text(draft[_key()].get("timetable", []))
		headway_label.text = game.headway_report(_key())
	if linked: link_label.text = "Linked to %s — its route, headway, departure timetables and arrival targets follow that source." % draft[str(draft[_key()]["link"])].name
	directive_warning.text = str(removed_waypoint_legs.get(_key(), ""))
	name_field.text = draft[_key()]["name"]
	var identity: Dictionary = game.route_identity(_key())
	style_label.text = identity.label
	style_colour.select(int(identity.colour))
	editing_controls.visible = Services.is_passenger_key(_key())
	route_mode.visible = Services.is_passenger_key(_key())
	route_mode.select(1 if draft[_key()].get("mode", "shuttle") == "loop" else 0)
	_refresh_copy_sources()
	_refresh_stops()
	if linked:
		editing_controls.visible = false
		route_mode.disabled = true
		copy_controls.visible = false
		waypoint_add.disabled = true
	else:
		route_mode.disabled = false
		waypoint_add.disabled = false
	status.text = "Mode/stop/waypoint edits require an empty train at the first station. Shuttle returns through stops in reverse; Loop closes from last to first, with its own waypoints. Names can change mid-trip." if Services.is_passenger_key(_key()) else ("Forest → Sawmill → Factory → Terminal → Forest. Keep industry directives 18,24 and 23,24." if game.factory.state.installed else "Forest: logs → Sawmill: unload/process/load timber → Terminal: sell → Forest. Keep the 18,24 directive." if game.sawmill.state.installed else "Forest: load → Terminal: unload → return. Waypoint edits require the train at the forest. Return trips use the selected path in reverse.")

func _refresh_copy_sources() -> void:
	copy_controls.visible = Services.is_passenger_key(_key())
	copy_source.clear()
	for key in game.service_keys():
		if key == _key() or not Services.is_passenger_key(key): continue
		copy_source.add_item(draft[key].name)
		copy_source.set_item_metadata(copy_source.item_count - 1, key)
	copy_button.disabled = copy_source.item_count == 0
	copy_source.disabled = copy_button.disabled
	copy_source.tooltip_text = "Start another passenger service in Fleet to copy routes between services." if copy_button.disabled else "Copies the source's current draft instructions."

func _copy_route() -> void:
	if not Services.is_passenger_key(_key()) or copy_source.item_count == 0: return
	var source: String = copy_source.get_selected_metadata()
	if source == _key() or not Services.is_passenger_key(source) or not draft.has(source): return
	_capture_name(_key())
	draft[_key()] = Services.copy_route(draft[source], draft[_key()])
	removed_waypoint_legs.erase(_key())
	_show_service()
	status.text = "Copied %s into this draft. Review the stop sequence, platforms and waypoints, then Apply. The target train must be empty at the first stop; no trains are bought or moved." % draft[source].name

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
		var stop_name: String = game.station_definitions()[key]["name"] if game.station_definitions().has(key) else ("Forest — load logs" if key == "forest" else "Terminal — unload logs")
		var chosen: int = int(draft[_key()].get("platforms", {}).get(key, 1))
		stop_list.add_item("%d. %s%s" % [index + 1, stop_name, "" if chosen == 1 else (" — auto platform" if chosen == 0 else " — platform %d" % chosen)])
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
	_refresh_timetable_legs()

func _show_platform(index: int) -> void:
	var stops: Array = draft[_key()]["stops"]
	platform_choice.disabled = index < 0 or index >= stops.size()
	if platform_choice.disabled: return
	var chosen: int = int(draft[_key()].get("platforms", {}).get(stops[index], 1))
	platform_choice.select(3 if chosen == 0 else chosen - 1)

func _select_platform(choice: int) -> void:
	var selected: PackedInt32Array = stop_list.get_selected_items()
	if selected.is_empty(): return
	var stop: String = draft[_key()]["stops"][selected[0]]
	var platforms: Dictionary = draft[_key()].get("platforms", {})
	if choice == 0: platforms.erase(stop)
	elif choice == 3: platforms[stop] = 0
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

## Moves the stop at `from` so it sits at `to`, exactly like repeated Up/Down.
func move_stop_to(from: int, to: int) -> void:
	var stops: Array = draft[_key()]["stops"]
	if from < 0 or from >= stops.size() or to < 0 or to >= stops.size() or from == to: return
	var stop: String = stops[from]
	stops.remove_at(from)
	stops.insert(to, stop)
	_refresh_stops(to)

func _stop_drag_data(at: Vector2) -> Variant:
	var index := stop_list.get_item_at_position(at, true)
	if index < 0: return null
	var preview := Label.new()
	preview.text = stop_list.get_item_text(index)
	stop_list.set_drag_preview(preview)
	return {"stop_index": index}

func _stop_can_drop(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("stop_index")

func _stop_drop(at: Vector2, data: Variant) -> void:
	if not _stop_can_drop(at, data): return
	var stops: Array = draft[_key()]["stops"]
	var target := stop_list.get_item_at_position(at, true)
	move_stop_to(int(data["stop_index"]), stops.size() - 1 if target < 0 else target)

func _apply() -> void:
	if not _set_timetable(): return
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
	var removed: PackedStringArray = []
	for key in directives.keys():
		if not valid_keys.has(key):
			if not directives[key].is_empty(): removed.append(str(key).replace(">", " → ").to_upper())
			directives.erase(key)
	if not removed.is_empty():
		directive_warning.text = "Waypoints removed from draft for vanished legs: %s. Re-add them to the intended legs before Apply, or close and reopen to discard edits." % ", ".join(removed)
		removed_waypoint_legs[_key()] = directive_warning.text
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
	_refresh_arrival_hint()

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
