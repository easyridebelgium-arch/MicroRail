extends RefCounted
## Presentation only: rearrange controls and summarize existing simulation totals.
const Art = preload("res://scripts/ui/toolbar_art.gd")
var game: Node
var status_bar: HFlowContainer
var balance: Label
var profit: Label
var deliveries: Label
var accounts_button: Button
var accounts_dialog: AcceptDialog
var accounts_text: Label
var loans_button: Button
var network_button: Button
var separators: Array[TextureRect] = []

func configure(owner_game: Node) -> void:
	game = owner_game
	var groups := {
		"Construction": [game.straight_button, game.curve_button, game.switch_button, game.remove_button, game.signal_button, game.waypoint_button],
		"Operations": [game.pause_button, game.speed_selector, game.routes_button, game.fleet_button, game.traffic_button],
		"Inspection": [game.inspect_button, game.reservation_button, game.inspection_button, game.problems_button, game.find_button],
		"Games and settings": [game.save_button, game.load_button, game.backup_button, game.folder_button, game.settings_button],
	}
	var index := 0
	for group in groups:
		if index > 0:
			var separator := TextureRect.new()
			separator.texture = Art.texture("details/group_separator.png", Vector2i(4, 32))
			separator.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			separator.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			separator.custom_minimum_size = Vector2(8, 64)
			separator.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			separator.tooltip_text = group + " controls"
			separator.mouse_filter = Control.MOUSE_FILTER_PASS
			game.header_toolbar.add_child(separator)
			game.header_toolbar.move_child(separator, index)
			separators.append(separator)
			index += 1
		for control in groups[group]:
			control.set_meta("toolbar_group", group)
			game.header_toolbar.move_child(control, index)
			index += 1
	status_bar = HFlowContainer.new()
	status_bar.name = "StatusBar"
	status_bar.add_theme_constant_override("h_separation", 18)
	status_bar.add_theme_constant_override("v_separation", 4)
	game.header_box.add_child(status_bar)
	game.header_box.move_child(status_bar, game.instructions.get_index())
	game.clock_label.reparent(status_bar)
	for field in ["balance", "profit", "deliveries"]:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		status_bar.add_child(label)
		set(field, label)
	profit.tooltip_text = "Operating profit = passenger fares + freight income − train running costs. Capital purchases, financing interest and objective rewards are excluded."
	accounts_button = Button.new()
	accounts_button.text = "Accounts"
	accounts_button.accessibility_name = "Company accounts"
	accounts_button.tooltip_text = "View company income, running costs, purchases, station queues and waiting satisfaction"
	accounts_button.pressed.connect(open_accounts)
	status_bar.add_child(accounts_button)
	accounts_dialog = AcceptDialog.new()
	accounts_dialog.title = "Company accounts"
	accounts_dialog.ok_button_text = "Close"
	accounts_dialog.exclusive = true
	accounts_dialog.theme = game.header_box.theme
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	accounts_dialog.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	loans_button = Button.new()
	loans_button.text = "Bank loans"
	loans_button.tooltip_text = "Borrow, view interest and scheduled payments, or repay the full balance early"
	loans_button.pressed.connect(func() -> void: game.loans_dialog.open_dialog())
	var loan_icon := "res://assets/ui/toolbar/icons/loans.png"
	if ResourceLoader.exists(loan_icon):
		loans_button.icon = Art.texture("icons/loans.png", Vector2i(24, 24), true)
		loans_button.expand_icon = true
		loans_button.add_theme_constant_override("icon_max_width", 24)
		loans_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	network_button = Button.new()
	network_button.text = "Network summary"
	network_button.pressed.connect(func() -> void: accounts_dialog.hide(); game.open_network_summary())
	column.add_child(network_button)
	var reports_button := Button.new()
	reports_button.text = "Progress reports"
	reports_button.pressed.connect(func() -> void: accounts_dialog.hide(); game.open_progress_reports())
	column.add_child(reports_button)
	column.add_child(loans_button)
	accounts_text = Label.new()
	accounts_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	accounts_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(accounts_text)
	game.get_node("Interface").add_child(accounts_dialog)
	refresh()

func apply_layout(compact: bool) -> void:
	var side := 44 if compact else 64
	for child in game.header_toolbar.get_children():
		if child is Button and child.has_meta("toolbar_group"):
			child.custom_minimum_size = Vector2(76 if compact and child == game.speed_selector else 84 if child == game.speed_selector else side, side)
			if child != game.speed_selector:
				var icon_size := (20 if compact else 32) if child == game.problems_button else (28 if compact else 48)
				child.add_theme_constant_override("icon_max_width", icon_size)
	for separator in separators: separator.custom_minimum_size.y = side
	for child in status_bar.get_children(): child.add_theme_font_size_override("font_size", 14 if compact else 16)
	refresh()

func refresh() -> void:
	var fares: int = game.passenger_revenue.total()
	var running: int = game.total_operating_cost + game.freight_operating_cost
	var operating: int = fares + game.freight_income - running
	game.clock_label.text = game.game_clock_text()
	balance.text = "Balance £%d" % game.money
	profit.text = ("Op. profit £%d" if game.GameSettings.use_compact_header() else "Operating profit £%d") % operating
	deliveries.text = ("Delivered %d" if game.GameSettings.use_compact_header() else "Delivered %d passengers") % game.passengers_delivered
	loans_button.text = "Bank loans — overdue £%d" % game.loans.overdue() if game.loans.overdue() > 0 else "Bank loans"
	if not accounts_dialog.visible: return
	var amenity_value := 0
	for station in game.amenities.station_ids:
		for id in game.amenities.owned[station]: amenity_value += int(game.Amenities.DEFS[id].price)
	var waiting_lines: PackedStringArray = []
	for station in game.passenger_demand.station_ids:
		waiting_lines.append("%s %d" % [game.station_definitions()[station].name, game.passenger_demand.waiting(station)])
	accounts_text.text = "Balance: £%d\n\nPassenger fares: £%d\nFreight income: £%d\nTrain running costs: £%d\nOperating profit: £%d\n\nRecorded construction spend: £%d\nFleet purchases/upgrades less sale refunds: £%d\nInstalled amenities (current list value): £%d\nObjective rewards: £%d\n\nPassengers waiting: %s\nPassengers delivered: %d\nLogs delivered: %d\n\nOperating profit excludes financing interest, capital purchases, construction refunds, starting cash and objective rewards. These are session totals, not daily figures." % [game.money, fares, game.freight_income, running, operating, game.total_construction_cost, game.total_vehicle_cost, amenity_value, game.scenario_goals.earned_rewards(), " / ".join(waiting_lines), game.passengers_delivered, game.logs_delivered]

	accounts_text.text += "\n\n" + game.passenger_revenue.summary()
	if game.sawmill.state.installed: accounts_text.text += "\n\n" + game.sawmill.summary(game.factory.state.installed)
	if game.factory.state.installed: accounts_text.text += "\n\n" + game.factory.summary()

	accounts_text.text += "\n\nBank principal outstanding: £%d\nAccrued interest: £%d (early payoff £%d)\nLoan payments overdue: £%d\nLoan interest paid: £%d\nLoan principal repaid: £%d" % [game.loans.state.principal, game.loans.state.interest, game.loans.payoff(), game.loans.overdue(), game.loans.state.interest_paid, game.loans.state.principal_paid]

	accounts_text.text += "\n\n" + waiting_summary()
	accounts_text.text += "\n\n" + game.journey_ledger.summary()
	accounts_text.text += "\n\n" + game.passenger_occupancy.summary(game.passenger_demand.station_ids)
	accounts_text.text += "\n\n" + game.arrival_targets.report()
	var directions: String = game.arrival_targets.direction_report()
	if not directions.is_empty(): accounts_text.text += "\nPer direction (game minutes):\n" + directions

func open_accounts() -> void:
	game._cancel_right_gesture()
	game.is_dragging = false
	game.is_panning = false
	game.build_plan.clear()
	game.demolition_cells.clear()
	game.demolition_blocked.clear()
	game.paused = true
	game._update_toolbar()
	accounts_dialog.popup_centered_clamped(Vector2i(560, 500), 0.95)
	refresh()

func waiting_summary() -> String:
	var company: Dictionary = game.satisfaction.company(game.passenger_demand, game.sim_clock.tick, game.amenities)
	var lines: PackedStringArray = ["Passenger waiting satisfaction: no data yet" if company.rating < 0 else "Passenger waiting satisfaction: %d / 100" % company.rating]
	var network: Dictionary = game._passenger_network()
	for station in game.passenger_demand.station_ids:
		var experience: Dictionary = game.satisfaction.station(station, game.passenger_demand.waiting_groups(station, game.sim_clock.tick), game.sim_clock.tick, game.amenities.owned[station])
		lines.append("\n" + game.station_definitions()[station].name + "\n" + game.satisfaction.describe(station, game.passenger_demand, game.sim_clock.tick, game.amenities))
		lines.append(game.demand_response.describe(station, int(experience.rating), int(experience.boarded), not network[station].is_empty()))
		lines.append(game.PassengerClasses.describe(game.passenger_demand.waiting_groups(station, game.sim_clock.tick), game.station_definitions()))
	return "\n".join(lines)
