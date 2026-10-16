extends AcceptDialog
## Paused diagnosis and validated physical turn-back command.
var game: Node
var selected_id := -1
var data: Dictionary = {}
var summary: Label
var authority: Label
var recommendation: Label
var buttons: Dictionary = {}
var details_toggle: Button
var command_result: Label
func configure(owner_game: Node) -> void:
	game = owner_game
	title = "Train operating inspector"
	ok_button_text = "Close"
	exclusive = true
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	for field in ["summary", "recommendation"]:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(label)
		set(field, label)
	command_result = Label.new()
	command_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(command_result)
	var actions := HFlowContainer.new()
	column.add_child(actions)
	for entry in [["inspect_blocker", "Inspect blocking train"], ["reverse", "Reverse"], ["blocker", "Locate blocking train"], ["conflict", "Locate conflict cell"], ["route", "Show route and authority"], ["traffic", "Traffic controls"], ["fleet", "Fleet controls"]]:
		var button := Button.new()
		button.text = entry[1]
		var action: String = entry[0]
		if action == "inspect_blocker": button.pressed.connect(_inspect_blocker)
		elif action == "reverse": button.pressed.connect(_reverse_train)
		else: button.pressed.connect(func() -> void: game.train_inspector_action(action, data))
		buttons[action] = button
		actions.add_child(button)
	details_toggle = Button.new()
	details_toggle.toggle_mode = true
	details_toggle.text = "Show reservation details"
	details_toggle.tooltip_text = "Expand physical occupancy, granted/requested tiles, switch locks and block owners"
	details_toggle.toggled.connect(_toggle_details)
	column.add_child(details_toggle)
	authority = Label.new()
	authority.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	authority.visible = false
	column.add_child(authority)

func _toggle_details(expanded: bool) -> void:
	authority.visible = expanded
	details_toggle.text = "Hide reservation details" if expanded else "Show reservation details"

func _inspect_blocker() -> void:
	var id := int(data.get("blocker", -1))
	if id > 0: game.inspect_train(id)

func open_train(id: int) -> void:
	command_result.text = ""
	if selected_id != id:
		details_toggle.set_pressed_no_signal(false)
		_toggle_details(false)
	selected_id = id
	data = game.train_diagnostics(id)
	if data.is_empty(): return
	summary.text = "%s\n%s\n%s\nTraffic waiting: %.1f simulation seconds in the current measured episode.\nGame paused; close and resume when ready." % [data.title, data.state, data.reason, data.wait_seconds]
	if game.ServiceRoutes.is_passenger_key(str(data.service)):
		var manifest: Dictionary = game.passenger_destinations if data.service == "passenger" else game.passenger_services[data.service].passenger_destinations
		var destinations: PackedStringArray = []
		for station in game.passenger_demand.station_ids:
			if int(manifest.get(station, 0)) > 0:
				destinations.append("%s: %d%s" % [game.station_definitions()[station].name, int(manifest[station]), " (change trains)" if not game.services[data.service].stops.has(station) else ""])
		summary.text += "\nOnboard destinations: " + (", ".join(destinations) if not destinations.is_empty() else "none")
		summary.text += "\n" + game.journey_ledger.describe_train(str(data.service), manifest, game.sim_clock.tick)
		summary.text += "\n" + game.arrival_targets.describe(str(data.service), game.sim_clock.tick)
		summary.text += "\n" + game.PassengerClasses.describe(game.journey_ledger.aboard.get(str(data.service), []), game.station_definitions())
		var vehicle: Dictionary = game.Fleet.find(game.fleet, id)
		if not vehicle.is_empty():
			summary.text += "\nSeats occupied: %d / %d\n" % [game.PassengerDemand.total(manifest), game.Fleet.capacity(vehicle)] + game.passenger_occupancy.describe(id)
	if int(data.blocker) > 0: summary.text += "\nBlocked by: " + _names([data.blocker])
	summary.text += "\nRoute identity: [" + str(game.route_identity(str(data.service)).label) + "]" if game.services.has(str(data.service)) else ""
	var lines: PackedStringArray = ["Physical body now (%d tiles): %s" % [data.occupied.size(), game.TrainDiagnostics.cells_text(data.occupied)], "Last allocation at tick %d:" % data.tick, "Granted tiles (%d): %s" % [data.granted.size(), game.TrainDiagnostics.cells_text(data.granted)], "Attempted tile requests (%d): %s" % [data.requested.size(), game.TrainDiagnostics.cells_text(data.requested)]]
	for lock in data.switches:
		lines.append("Locked switch %d,%d — %s" % [lock.cell.x, lock.cell.y, "through" if lock.state == 0 else "branch"])
	for block in data.blocks:
		lines.append("B%02d — occupied at allocation: %s | authority: %s | requested: %s" % [block.id, _names(block.occupants), _names(block.authorities), "yes" if block.requested else "no"])
	if data.blocks.is_empty(): lines.append("No signal-block authority recorded for this train; tile reservations still apply.")
	if not data.cycle.is_empty(): lines.append("Deadlock cycle: " + _names(data.cycle))
	if int(data.blocker) > 0: lines.append("Blocking train: " + _names([data.blocker]))
	lines.append("Waiting measurements reset on load; saved incidents are history. Authority is the last allocation, not a traffic forecast.")
	authority.text = "\n".join(lines)
	recommendation.text = "Suggested action\n" + str(data.advice)
	var reverse_reason: String = game.reverse_train_reason(id)
	buttons.reverse.disabled = not reverse_reason.is_empty()
	buttons.reverse.tooltip_text = reverse_reason if not reverse_reason.is_empty() else "Reverse in place and return to this leg's departure stop, obeying signals and reservations. Close and resume to move."
	buttons.inspect_blocker.disabled = int(data.blocker) <= 0 or game.Fleet.find(game.fleet, int(data.blocker)).is_empty()
	buttons.inspect_blocker.visible = not buttons.inspect_blocker.disabled
	buttons.inspect_blocker.text = "Inspect blocking train #%d" % int(data.blocker)
	buttons.inspect_blocker.tooltip_text = _names([data.blocker]) if int(data.blocker) > 0 else "No blocking train identified"
	buttons.blocker.disabled = not game.can_locate_problem({"id": data.blocker, "cell": Vector2i(-1, -1)})
	buttons.conflict.disabled = not game._is_inside_map(data.cell)
	buttons.route.disabled = not game.services.has(data.service)
	buttons.traffic.disabled = buttons.route.disabled
	popup_centered_clamped(Vector2i(740, 550), 0.95)
func _reverse_train() -> void:
	var result: String = game.reverse_train(selected_id)
	open_train(selected_id)
	command_result.text = result

func _names(ids: Array) -> String:
	var names: PackedStringArray = []
	for id in ids:
		var train: Dictionary = game.Fleet.find(game.fleet, int(id))
		var service: String = str(train.get("service", ""))
		names.append("#%d %s%s" % [id, str(train.get("name", "Unknown train")), " / " + str(game.services[service].name) if game.services.has(service) else ""])
	return "; ".join(names) if not names.is_empty() else "none"
