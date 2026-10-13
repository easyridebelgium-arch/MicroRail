extends AcceptDialog
## Bank terms and current debt, shown before any transaction.
var game: Node
var summary: Label
var terms: Label
var feedback: Label
var offers: Dictionary = {}
var repay_button: Button

func configure(owner_game: Node) -> void:
	game = owner_game
	title = "Bank loans"
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
	for field in ["summary", "terms"]:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
		set(field, label)
	for amount in game.Loans.OFFERS:
		var quote: Dictionary = game.Loans.quote(amount)
		var button := Button.new()
		button.text = "Borrow £%d — first payment £%d" % [amount, quote.first_payment]
		button.tooltip_text = "Ten hourly principal instalments of £%d plus interest. Total £%d if paid on time." % [quote.instalment, quote.total]
		button.pressed.connect(_borrow.bind(amount))
		box.add_child(button)
		offers[amount] = button
	repay_button = Button.new()
	repay_button.pressed.connect(_repay)
	box.add_child(repay_button)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(feedback)

func open_dialog() -> void:
	game.header_controls.accounts_dialog.hide()
	game.paused = true
	game._update_toolbar()
	feedback.text = ""
	refresh()
	popup_centered_clamped(Vector2i(620, 540), 0.95)

func refresh() -> void:
	var bank = game.loans
	var state: Dictionary = bank.state
	summary.text = "Cash balance: £%d\nOutstanding principal: £%d\nAccrued interest: £%d%s\nOverdue payment: £%d\nInterest paid to date: £%d" % [game.money, state.principal, state.interest, " + a fraction of £1" if int(state.carry) > 0 else "", bank.overdue(), state.interest_paid]
	if bank.active():
		var minutes := ceili(float(int(state.next_tick) - game.sim_clock.tick) / 60.0)
		summary.text += "\nNext billing: in %d game minutes\nPrincipal instalments remaining: %d" % [minutes, state.payments_left]
	terms.text = "Interest: 1% of outstanding principal per game hour. Ten hourly principal instalments plus interest. One game hour is 60 simulation seconds at 1×; pause stops interest and payments.\n\nPayments use available cash, paying billed interest first. Unpaid amounts remain overdue and are paid from later available income. Interest continues on unpaid principal; no interest on interest or extra late fee.\n\nInterest rounds up to a whole pound at billing or early payoff. Only one loan can be active. Early full repayment has no extra fee."
	for amount in offers:
		offers[amount].disabled = bank.active()
		offers[amount].tooltip_text = "Repay the current loan before borrowing again." if bank.active() else "Principal £%d; estimated total £%d when paid on time. Initial payment is due one game hour after borrowing." % [amount, game.Loans.quote(amount).total]
	repay_button.text = "Repay full balance early — £%d" % bank.payoff()
	repay_button.disabled = not bank.active() or game.money < bank.payoff()
	repay_button.tooltip_text = "Clears all principal and accrued interest." if not repay_button.disabled else "No active loan, or insufficient cash to pay the full balance."

func _borrow(amount: int) -> void:
	feedback.text = game.borrow_money(amount)
	refresh()
	game.header_controls.refresh()

func _repay() -> void:
	feedback.text = game.repay_loan_early()
	refresh()
	game.header_controls.refresh()
