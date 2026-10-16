extends SceneTree
const Loans = preload("res://scripts/core/loans.gd")
const Clock = preload("res://scripts/core/sim_clock.gd")
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _fps_snapshot(fps: int, speed: float = 1.0) -> Dictionary:
	var bank := Loans.new()
	var clock := Clock.new()
	clock.speed = speed
	bank.borrow(1000, 0)
	var cash := 2000
	for frame in range(roundi(fps * 70.0 / speed)):
		for step in clock.advance(1.0 / fps):
			clock.begin_tick()
			cash -= int(bank.advance(clock.tick, cash).paid)
	return {"clock": clock.tick, "cash": cash, "loan": bank.save_state()}
func _run() -> void:
	for amount in Loans.OFFERS:
		var bank := Loans.new()
		var quote := Loans.quote(amount)
		check(bank.borrow(amount, 0), "valid offer accepted")
		check(not bank.borrow(amount, 0), "second active loan refused")
		check(bank.advance(Loans.PERIOD_TICKS - 1, amount * 2).paid == 0, "no payment before due tick")
		var first := bank.advance(Loans.PERIOD_TICKS, amount * 2)
		check(first.paid == quote.first_payment and bank.state.payments_left == 9, "first instalment matches displayed quote")
		var final := bank.advance(Loans.PERIOD_TICKS * 10, amount * 2 - int(first.paid))
		check(int(first.paid) + int(final.paid) == quote.total and not bank.active(), "on-time total matches quote and closes loan")
		check(bank.state.principal_paid == amount and bank.state.interest_paid == int(quote.total) - amount, "principal and interest reported separately")
		check(Loans.valid_state(bank.save_state(), Loans.PERIOD_TICKS * 10), "closed state validates")
	var late := Loans.new()
	late.borrow(1000, 0)
	var missed := late.advance(Loans.PERIOD_TICKS, -50)
	check(missed.paid == 0 and late.overdue() == 110 and missed.missed.size() == 1, "negative cash cannot force loan overdraft; debt remains overdue")
	var part := late.advance(Loans.PERIOD_TICKS + 1, 15)
	check(part.paid == 15 and late.state.principal == 995 and late.state.interest_paid == 10 and late.overdue() == 95, "partial automatic payment pays interest first")
	check(Loans.valid_state(late.save_state(), Loans.PERIOD_TICKS + 1), "partial arrears validate")
	late.advance(Loans.PERIOD_TICKS * 11, 0)
	check(late.state.payments_left == 0 and late.overdue() > late.state.principal, "unpaid principal continues accruing after term ends")
	var repayment := late.advance(Loans.PERIOD_TICKS * 11 + 1, 10000)
	check(repayment.paid > 995 and not late.active(), "future available income clears arrears and final accrued interest")
	var early := Loans.new()
	early.borrow(1000, 100)
	early.advance(101, 0)
	check(early.payoff() == 1001, "fractional interest is rounded explicitly at early payoff")
	var before := early.save_state()
	check(early.repay_early(1000).is_empty() and early.save_state() == before, "insufficient early repayment is atomic")
	check(early.repay_early(1001).paid == 1001 and not early.active(), "full early payoff closes loan without extra fee")
	check(early.borrow(2500, 101), "repaid loan permits another offer")
	check(_fps_snapshot(30) == _fps_snapshot(60) and _fps_snapshot(60) == _fps_snapshot(120), "interest and payments identical at 30/60/120 FPS")
	for speed in [2.0, 5.0, 10.0]: check(_fps_snapshot(60, speed) == _fps_snapshot(60), "speed %s advances the same debt over equal simulation time" % speed)
	var original := Loans.new()
	original.borrow(5000, 23)
	original.advance(987, 0)
	var restored := Loans.new()
	restored.restore_state(JSON.parse_string(JSON.stringify(original.save_state())))
	var identical := true
	for tick in range(988, 3902):
		if original.advance(tick, 130) != restored.advance(tick, 130): identical = false
	check(identical and original.save_state() == restored.save_state(), "save/load continues exact fractional interest and partial automatic repayments")
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	var cash_before: int = game.money
	check(game.borrow_money(1000).begins_with("Borrowed") and game.money == cash_before + 1000, "borrowing credits cash once")
	check(game.borrow_money(5000).contains("Repay") and game.money == cash_before + 1000, "duplicate request cannot credit cash")
	var saved_before: Dictionary = game.loans.save_state()
	game._process(1.0)
	check(game.loans.save_state() == saved_before, "paused wall time cannot accrue interest")
	game.sim_clock.tick = Loans.PERIOD_TICKS
	game._advance_loans()
	check(game.money == cash_before + 890 and game.loans.state.principal == 900, "game deducts automatic payment once")
	game._advance_loans()
	check(game.money == cash_before + 890, "same tick cannot duplicate payment")
	check(game._save_game(), "active loan can be saved")
	var saved := JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH)) as Dictionary
	check(int(saved.version) == game.SAVE_VERSION and int(saved.version) >= 27 and game._is_valid_save(saved), "v27 loan save validates")
	game.repay_loan_early()
	check(game._load_game() and game.loans.state.principal == 900 and game.loans.state.next_tick == Loans.PERIOD_TICKS * 2, "load restores debt and due tick without a new payout")
	var corrupt := saved.duplicate(true)
	corrupt.loans.principal = 900.5
	check(not game._is_valid_save(corrupt), "fractional principal rejected")
	corrupt = saved.duplicate(true)
	corrupt.loans.next_tick = game.sim_clock.tick
	check(not game._is_valid_save(corrupt), "expired saved due tick rejected")
	corrupt = saved.duplicate(true)
	corrupt.loans.principal_paid = 0
	check(not game._is_valid_save(corrupt), "principal ledger mismatch rejected")
	var old := saved.duplicate(true)
	old.version = 26
	old.erase("loans")
	var migrated: Dictionary = game.SaveMigrations.migrate(old)
	check(migrated.ok and migrated.data.loans == Loans.defaults() and game._is_valid_save(migrated.data), "v26 migration adds zero debt without changing clock/cash")
	game.header_controls.open_accounts()
	check(game.header_controls.accounts_text.text.contains("Bank principal outstanding: £900"), "Accounts shows real debt")
	game.header_controls.loans_button.pressed.emit()
	check(game.loans_dialog.visible and not game.header_controls.accounts_dialog.visible and game._modal_open(), "Bank opens paused without overlapping exclusive dialogs")
	check(game.loans_dialog.offers[1000].disabled and game.loans_dialog.summary.text.contains("Outstanding principal: £900"), "Bank shows terms/debt and prevents a second loan")
	game.loans_dialog.hide()
	game.queue_free()
	await process_frame
	print("Loans: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
