extends RefCounted
## One fixed-rate bank loan. Integer pounds and integer tick fractions only.
## One game hour = 60 simulation seconds. Rounding happens at billing/payoff.
const OFFERS: Array[int] = [1000, 2500, 5000]
const PERIOD_TICKS := 3600
const RATE_PERCENT := 1
const INSTALMENTS := 10
const INTEREST_DENOMINATOR := PERIOD_TICKS * 100
const CURRENT_FIELDS := ["principal", "interest", "carry", "due_principal", "due_interest", "instalment", "payments_left", "next_tick", "last_tick"]
var state: Dictionary = defaults()

static func defaults() -> Dictionary:
	return {"principal": 0, "interest": 0, "carry": 0, "due_principal": 0, "due_interest": 0, "instalment": 0, "payments_left": 0, "next_tick": 0, "last_tick": 0, "borrowed": 0, "principal_paid": 0, "interest_paid": 0}

@warning_ignore("integer_division")
static func _divide(value: int, divisor: int) -> int:
	return value / divisor

static func quote(amount: int) -> Dictionary:
	if not OFFERS.has(amount): return {}
	var portion := _divide(amount, INSTALMENTS)
	var interest := 0
	for index in range(INSTALMENTS): interest += _divide((amount - index * portion) * RATE_PERCENT + 99, 100)
	return {"principal": amount, "instalment": portion, "first_payment": portion + _divide(amount * RATE_PERCENT + 99, 100), "total": amount + interest}

func active() -> bool:
	return int(state.principal) + int(state.interest) > 0

func overdue() -> int:
	return int(state.due_principal) + int(state.due_interest)

func payoff() -> int:
	return int(state.principal) + int(state.interest) + (1 if int(state.carry) > 0 else 0)

func borrow(amount: int, tick: int) -> bool:
	if active() or not OFFERS.has(amount) or tick < 0: return false
	state.principal = amount
	state.instalment = _divide(amount, INSTALMENTS)
	state.payments_left = INSTALMENTS
	state.last_tick = tick
	state.next_tick = tick + PERIOD_TICKS
	state.borrowed += amount
	return true

func _round_interest() -> void:
	if int(state.carry) > 0:
		state.interest += 1
		state.carry = 0

func _finish() -> void:
	for field in CURRENT_FIELDS: state[field] = 0

func repay_early(cash: int) -> Dictionary:
	if not active() or cash < payoff(): return {}
	_round_interest()
	var result := {"paid": payoff(), "principal": int(state.principal), "interest": int(state.interest)}
	state.principal_paid += result.principal
	state.interest_paid += result.interest
	_finish()
	return result

func _pay(cash: int) -> Dictionary:
	var interest := mini(maxi(0, cash), int(state.due_interest))
	var principal := mini(maxi(0, cash - interest), int(state.due_principal))
	state.interest -= interest
	state.due_interest -= interest
	state.principal -= principal
	state.due_principal -= principal
	state.interest_paid += interest
	state.principal_paid += principal
	return {"paid": interest + principal, "principal": principal, "interest": interest}

## Advance to a later tick. The game calls this once per fixed tick; chunking also
## supports fast unit checks without a million scene updates. Arrears use any cash
## on the first available tick. Future instalments are never paid prematurely.
func advance(tick: int, cash: int) -> Dictionary:
	var result := {"paid": 0, "payments": [], "missed": []}
	if not active() or tick <= int(state.last_tick): return result
	var available := maxi(0, cash)
	while active() and int(state.last_tick) < tick:
		var until := mini(tick, int(state.next_tick))
		if overdue() > 0 and available > 0: until = mini(until, int(state.last_tick) + 1)
		var pool: int = int(state.carry) + int(state.principal) * RATE_PERCENT * (until - int(state.last_tick))
		state.interest += _divide(pool, INTEREST_DENOMINATOR)
		state.carry = pool % INTEREST_DENOMINATOR
		state.last_tick = until
		var billing := until == int(state.next_tick)
		if billing:
			_round_interest()
			if int(state.payments_left) > 0:
				state.due_principal += mini(int(state.instalment), int(state.principal) - int(state.due_principal))
				state.payments_left -= 1
			state.due_interest = int(state.interest)
			state.next_tick += PERIOD_TICKS
		var payment := _pay(available)
		# Interest accrued while a final principal instalment was overdue must
		# also be settled. No compound interest is charged on unpaid interest.
		if int(state.principal) == 0:
			_round_interest()
			state.due_interest = int(state.interest)
			var final_interest := _pay(available - int(payment.paid))
			payment.paid += final_interest.paid
			payment.interest += final_interest.interest
		if int(payment.paid) > 0:
			available -= int(payment.paid)
			result.paid += int(payment.paid)
			payment["tick"] = until
			payment["remaining"] = payoff()
			result.payments.append(payment)
		if billing and overdue() > 0: result.missed.append({"tick": until, "due": overdue()})
		if not active(): _finish()
	return result

func save_state() -> Dictionary:
	return state.duplicate(true)

func restore_state(value: Dictionary) -> void:
	for field in state: state[field] = int(value[field])

static func valid_state(value: Variant, tick: int) -> bool:
	var shape := defaults()
	if not value is Dictionary or value.size() != shape.size(): return false
	for field in shape:
		var number: Variant = value.get(field)
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT]: return false
		if not is_finite(float(number)) or float(number) != floor(float(number)) or float(number) < 0 or float(number) > 1_000_000_000_000.0: return false
	if int(value.borrowed) - int(value.principal_paid) != int(value.principal): return false
	if int(value.principal) > OFFERS[-1] or int(value.carry) >= INTEREST_DENOMINATOR: return false
	if int(value.due_principal) > int(value.principal) or int(value.due_interest) > int(value.interest): return false
	if int(value.principal) + int(value.interest) == 0:
		for field in CURRENT_FIELDS:
			if int(value[field]) != 0: return false
		return true
	if not [_divide(1000, INSTALMENTS), _divide(2500, INSTALMENTS), _divide(5000, INSTALMENTS)].has(int(value.instalment)): return false
	if int(value.borrowed) < int(value.instalment) * INSTALMENTS: return false
	if int(value.principal) > int(value.instalment) * INSTALMENTS or int(value.payments_left) > INSTALMENTS: return false
	if int(value.last_tick) != tick or int(value.next_tick) <= tick or int(value.next_tick) > tick + PERIOD_TICKS: return false
	# All principal scheduled so far is either paid or remains due.
	if int(value.principal) - int(value.due_principal) != int(value.instalment) * int(value.payments_left): return false
	return true
