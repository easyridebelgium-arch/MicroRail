extends ConfirmationDialog
## Read-only service cards. Opens paused; no sampling or gameplay runs in UI code.
const Timetable = preload("res://scripts/core/timetable.gd")
var game: Node
var choice: OptionButton
var body: VBoxContainer
var pin_button: Button
var inspect_button: Button
var selected := ""
func configure(owner_game: Node) -> void:
	game = owner_game
	title = "Service performance"
	ok_button_text = "Locate route"
	get_cancel_button().text = "Close"
	dialog_hide_on_ok = false
	exclusive = true
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 100
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	choice = OptionButton.new()
	choice.clip_text = true
	body.add_child(choice)
	choice.item_selected.connect(func(index: int) -> void: selected = str(choice.get_item_metadata(index)); refresh())
	var actions := HFlowContainer.new()
	body.add_child(actions)
	pin_button = Button.new()
	pin_button.pressed.connect(_pin)
	actions.add_child(pin_button)
	inspect_button = Button.new()
	inspect_button.text = "Inspect first assigned train"
	inspect_button.pressed.connect(_inspect)
	actions.add_child(inspect_button)
	confirmed.connect(_locate)
func open_dialog(key: String = "") -> void:
	selected = str(game.Presentation.source(game.services, key)) if game.services.has(key) else selected
	choice.clear()
	for service in game.service_keys():
		if game.services[service].has("link"): continue
		choice.add_item(str(game.services[service].name))
		choice.set_item_metadata(choice.item_count - 1, service)
		if service == selected: choice.select(choice.item_count - 1)
	selected = str(choice.get_item_metadata(choice.selected)) if choice.item_count > 0 else ""
	refresh()
	popup_centered_clamped(Vector2i(680, 580), 0.85)
func members() -> Array:
	return game.headway_group_members(selected) if game.services.has(selected) else []
func refresh() -> void:
	while body.get_child_count() > 2:
		var child := body.get_child(2)
		body.remove_child(child)
		child.queue_free()
	var available: bool = game.services.has(selected)
	pin_button.disabled = not available
	inspect_button.disabled = not available
	get_ok_button().disabled = not available
	pin_button.text = "Unpin service" if game.object_pins.has("service:" + selected) else "Pin service"
	if not available:
		_card("No services yet", "Build and connect two stations, then start a passenger service in Fleet. Your saved watchlist is available in Find.")
		return
	var group := members()
	var stops: PackedStringArray = []
	for stop in game.services[selected].stops:
		stops.append(str(game.station_definitions()[stop].name) if game.station_definitions().has(stop) else "Forest" if stop == "forest" else "Cargo Terminal")
	_card("Route · %d assigned service(s)" % group.size(), " → ".join(stops) + "\nSource and currently linked services combined.")
	if selected == "freight":
		_card("Cargo delivered at the terminal", "%d logs · %d timber · %d goods\nIntermediate processing deliveries are excluded from these terminal totals." % [game.logs_delivered, game.sawmill.state.sold, game.factory.state.sold])
		_card("Operating result · company lifetime", "Receipts £%d · running costs £%d · net £%d\nOne freight service. Excludes train purchases, construction, loans and interest." % [game.freight_income, game.freight_operating_cost, game.freight_income - game.freight_operating_cost])
	else:
		var totals: Dictionary = game.service_performance.totals(group)
		var since := Timetable.clock_text(Timetable.absolute_minute(int(game.service_performance.state.since)))
		_card("Passenger outcomes · since " + since, "%d final journeys completed\n%d passenger interchange arrivals\nOnly final journeys earn fares. Interchanges are connecting work, not additional completed journeys." % [totals.finals, totals.transfers])
		_card("Operating result · same measurement period", "Fares £%d · running costs £%d · net £%d\nOperating contribution excludes purchases, construction, loans and interest. Fares go to the final delivering service." % [totals.income, totals.cost, totals.income - totals.cost])
	var vehicles: PackedStringArray = []
	var occupancy := {"ticks": 0, "seat_ticks": 0, "passenger_ticks": 0, "full_ticks": 0, "left": 0, "boardings": 0}
	for key in group:
		var train: Dictionary = game.Fleet.assigned(game.fleet, key)
		if train.is_empty(): continue
		var id := int(train.id)
		vehicles.append("#%d %s — %s" % [id, train.name, game.fleet_train_status(id)])
		var wait: Dictionary = game.traffic_metrics.statistics(id)
		vehicles.append("Traffic wait: %.1fs continuous · %.1fs in the last ~60 simulation seconds.\n%s" % [wait.continuous_seconds, wait.recent_seconds, wait.reason])
		if selected != "freight":
			var stats: Dictionary = game.passenger_occupancy.statistics(id)
			for field in occupancy: occupancy[field] += int(stats[field])
	_card("Assigned vehicles · current status", "\n".join(vehicles) + "\nTraffic diagnostics reset on load. Inspect a train for the current blocking cause.")
	if selected != "freight":
		var utilization := "No seat-time samples yet." if occupancy.seat_ticks == 0 else "%.1f%% of measured seat-time occupied · %.1f%% of measured train-time full." % [100.0 * occupancy.passenger_ticks / occupancy.seat_ticks, 100.0 * occupancy.full_ticks / occupancy.ticks]
		_card("Capacity · current assigned vehicles", utilization + "\n%d eligible passengers left behind across %d boarding opportunities. Repeated waits may count a person again.\nLast ~120 simulation seconds of seat-time; latest 128 boarding opportunities company-wide, filtered to these vehicles. Resets on load." % [occupancy.left, occupancy.boardings])
		_card("Arrival targets · current member identities", game.arrival_targets.report(selected, group) + "\nLatest 128 targeted trips company-wide, filtered to current members. No target means no punctuality measurement.")
	var notes_button := CheckButton.new()
	notes_button.text = "Measurement details"
	body.add_child(notes_button)
	var notes := _card("How to read these measurements", "Saved counters follow service identities across route edits and train replacements. Removed services leave the comparison; a new service starts at zero. Older saves start a fresh baseline. Fares are not shared with feeder services.\nQueues, boarding, through stops and unfinished recovery do not count as completed arrivals. Each interchange arrival may be one leg of a longer journey.\nCapacity diagnostics follow currently assigned vehicle IDs, including their earlier assignments. Seat-time includes dwell, traffic waits and intentional holds for enabled services. Traffic wait measurements exclude dwell and intentional holds.\nArrival-target history follows current member identities, includes earlier route configurations and survives loading. It applies no fare or satisfaction penalty.")
	notes.hide()
	notes_button.toggled.connect(func(expanded: bool) -> void: notes.visible = expanded)
	inspect_button.disabled = first_train() < 0
func _card(heading: String, text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#182331")
	style.border_color = Color("#33465e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	body.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title_label := Label.new()
	title_label.text = heading
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_color_override("font_color", Color("#8dccf2"))
	box.add_child(title_label)
	var content := Label.new()
	content.text = text
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(content)
	return panel
func first_train() -> int:
	for key in members():
		var train: Dictionary = game.Fleet.assigned(game.fleet, key)
		if not train.is_empty(): return int(train.id)
	return -1
func _pin() -> void:
	var key := "service:" + selected
	if game.object_pins.has(key): game.object_pins.erase(key)
	elif game.object_pins.size() < game.Watchlist.LIMIT: game.object_pins[key] = true
	refresh()
func _inspect() -> void:
	var id := first_train()
	if id < 0: return
	hide()
	game.inspect_train(id)
func _locate() -> void:
	for row in game.object_rows():
		if row.key == "service:" + selected and game.locate_object(row):
			hide()
			return
