# Passenger fares and recorded revenue

Local passengers pay **£5** and Express passengers pay **£10**, once when their
train reaches their final destination. The Express premium rewards the existing
nonstop A↔C eligibility rule. A standard train can earn it on a qualifying leg;
a fast stopping service does not become Express merely through its model/name.

Boarding, intermediate stops, transfers and unfinished recovery do not pay.
Passengers who recover and reboard keep their class and pay only when they
finally arrive. Repeated arrival calls or reloading a completed trip cannot pay
again. Unknown/legacy onboard journey metadata defaults to Local, while actual
Express preferences saved in version 35 survive and earn the current £10 on a
future delivery after upgrading.

## Financial feedback

The header's **Operating profit** and **Accounts** use cumulative recorded
passenger receipts, rather than inferring them from delivered counts. Accounts
separately shows Local and Express paid deliveries/income, plus a legacy bucket.
Class eligibility and fare amounts also appear in Routes and passenger class
explanations in station/train information.

Operating profit remains passenger receipts plus freight income minus train
running costs. It excludes capital purchases, construction refunds, objective
rewards, financing interest, loan borrowing and principal repayments. Receipts
are cumulative and independent of the bounded recent journey/arrival histories;
removing old diagnostic samples does not erase income.

These are fixed tariffs, not player fare controls. There is no price elasticity,
punctuality multiplier, satisfaction rebate or transfer charge in this increment.
Prices have one source in passenger class definitions and are reused by payout,
validation and the UI.

## Persistence

Save version **36** stores paid-delivery counts and income for each new class
and for legacy flat-fare deliveries. Load restores counters without crediting
cash again. Validation checks whole nonnegative values, class rate arithmetic
and reconciliation with the saved overall delivered count before applying state.
Invalid loads leave cash, positions and receipts intact.

Version 35 and supported older saves paid £5 per delivery. Migration records
those previous deliveries in a **legacy** bucket at their historical flat rate,
without changing the balance or granting retroactive Express premiums. Older
bounded journey records cannot reconstruct every historical class, so the UI
explicitly labels that class split unavailable. Existing preferences, positions,
queues, ages, arrival targets, debt and running costs remain intact.

`tests/test_passenger_revenue.gd`: 25 checks cover mixed fares, numeric validation,
JSON persistence, real primary/additional services, no early/duplicate payment,
mid-trip/paid save-load, atomic invalid loads, legacy migration, operating profit,
class breakdowns and 100–200% Accounts layout. Existing passenger class tests now
assert the £10 premium, and the header fixture explicitly tests mixed-class income.
Network, transfer/recovery, passenger conservation, FPS and save suites remain
regression requirements.
