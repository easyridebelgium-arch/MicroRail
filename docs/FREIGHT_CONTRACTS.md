# Optional freight delivery contracts

Open **Accounts → Freight contracts**. Opening pauses the game. Read the offer,
then accept when the railway is ready; close and resume manually. The timer starts
at acceptance and uses simulation time, so 2×/5×/10× also speed up deadlines.
Paused time does not count. The dialog shows the deadline on the game clock and
remaining game time (minutes near the deadline).

| Order | Terminal deliveries after acceptance | Time allowed | Additional bonus |
| --- | --- | --- | --- |
| Logs | 40 logs | 12 game hours | £200 |
| Timber | 20 timber | 18 game hours | £300 |
| Goods | 12 goods | 24 game hours | £450 |

One game hour is 60 simulation seconds. These first offers are fixed, not randomly
rolled. Accept only one at a time; each offer is available once per company. There
is no advance payment, acceptance cost, cancellation, penalty for expiry or repeat
bonus. Completing or missing an order frees the active slot. Other unused cargo
orders can then be accepted when their industry chain is installed.

## What counts

Only matching cargo physically unloaded at the Cargo Terminal **after acceptance**
counts. Existing lifetime deliveries, stockpiles, loading, passenger trips and
intermediate sawmill/factory receipts do not qualify. Cargo loaded before accepting
can qualify if it reaches Terminal after acceptance. Excess delivery above the
contract target still earns normal freight revenue but no extra contract bonus.
Delivery on the exact deadline tick qualifies; later deliveries do not.

Offers match the current installed terminal cargo: logs before the sawmill, timber
with a sawmill and no factory, goods with the full chain. Unavailable offers show
the reason. Finish an active order before upgrading industries: changing the cargo
sold at Terminal can leave its target unmet. Upgrades are not blocked; the ordinary
deadline and no-fine rule still apply.

Ordinary terminal payments continue. A completed order pays its bonus once into
company cash, recorded separately in **Accounts → Freight contract bonuses**.
Bonuses do not inflate freight haulage income, operating profit or delivered cargo.
Acceptance, completion and expiry are recorded in the event journal.

## Saves and verification

Version **50** saves the three offer states, acceptance/deadline/completion ticks,
counted terminal units and pre-acceptance lifetime delivery baseline. Loading
checks allowed states, exact terms, one active order, tick bounds and counted
units against real terminal totals. Completed orders cannot pay again on load.
Version 49 migration adds unused offers without retroactive credit, bonus cash or
changes to physical train/cargo state. Slots, backup and autosave rules are unchanged.

`test_freight_contracts.gd` covers partial/wrong/early/late cargo, exact deadlines,
one active order, one-off payout, expiry, JSON restoration, baseline validation,
paused UI acceptance and physical completion of all three production-chain tiers.
It verifies intermediate receipts do not count and completed states preserve valid
industry inventory on save/load. Existing sawmill, factory, accounting and company
save regression suites remain active.

Renewable/generated offers, negotiated prices, rival bidding, reputation penalties,
contract objectives in scenarios and optional deadline difficulty remain future work.

The [Network summary](NETWORK_SUMMARY.md) now shows the active order in its headline and review list. Deadline warnings use the final 25% of the time window or an observed freight obstacle, without predicting arrival. Review opens the active order; Locate points to Terminal.

Optional [deadline reminders](NOTIFICATIONS.md) are now available through Settings. They default Off, fire once in the final quarter, and retain a warning tick in save version 51 so loading cannot repeat them. Muted warnings stay in history; enabling alerts later does not replay past reminders.

The **Timber Connection** seeded scenario uses the ordinary timber order as its
completion goal. Preparation is untimed; see [scenario instructions](SEEDED_SCENARIOS.md#timber-connection).
