extends AcceptDialog
const Timetable = preload("res://scripts/core/timetable.gd")
var game: Node
var details: Dictionary = {}
var offers: Dictionary = {}
var feedback: Label
func configure(owner_game: Node) -> void:
	game = owner_game
	title = "Freight delivery contracts"
	ok_button_text = "Close"
	exclusive = true
	theme = game.header_box.theme
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	var intro := Label.new()
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.text = "Optional, one active order at a time. Each offer can be accepted once per company. Only matching cargo delivered to Terminal after acceptance counts. Ordinary freight payments continue; the bonus is separate. Deadlines advance with simulation time, including at 2×/5×/10×. Expiry has no extra fine, but the offer is used up. No advance payment or cancellation. Finish an active order before upgrading industries: changing the terminal cargo can prevent its completion. Close and resume manually when ready."
	box.add_child(intro)
	for kind in game.FreightContracts.DEFINITIONS:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
		details[kind] = label
		var button := Button.new()
		button.text = "Accept %s order" % kind
		button.pressed.connect(_accept.bind(kind))
		box.add_child(button)
		offers[kind] = button
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(feedback)
func open_dialog() -> void:
	game.paused = true
	feedback.text = ""
	refresh()
	popup_centered_clamped(Vector2i(640, 560), 0.85)
	game._update_toolbar()
func _accept(kind: String) -> void:
	feedback.text = game.accept_freight_contract(kind)
	refresh()
func refresh() -> void:
	for kind in details:
		var definition: Dictionary = game.FreightContracts.DEFINITIONS[kind]
		var row: Dictionary = game.freight_contracts.state[kind]
		var text := "%s — %d units to Terminal within %d game hours; bonus £%d.\nStatus: %s | Delivered since acceptance: %d / %d" % [str(kind).capitalize(), definition.target, definition.hours, definition.bonus, row.status, row.delivered, definition.target]
		if row.status == "active": text += "\nDeadline: %s. Time remaining: %.1f game hours." % [Timetable.clock_text(Timetable.absolute_minute(int(row.deadline))), maxf(0.0, float(row.deadline - game.sim_clock.tick)) / 3600.0]
		if kind == "timber": text += "\nRequires a working sawmill chain; goods deliveries cannot substitute."
		if kind == "goods": text += "\nRequires a working sawmill and factory chain."
		details[kind].text = text
		var reason: String = game.freight_contract_reason(kind)
		offers[kind].disabled = not reason.is_empty()
		offers[kind].tooltip_text = reason if not reason.is_empty() else "Accept only when you are ready; the clock starts immediately. Only future terminal deliveries qualify."
		if row.status == "available" and not reason.is_empty(): details[kind].text += "\n" + reason
