# Gradual passenger demand response

New passenger arrivals now respond to each station's measured waiting satisfaction.
The station overview shows **Demand response**; Details and Accounts explain the
current percentage, target and evidence. These percentages multiply the existing
amenity-adjusted arrivals, not the number of passengers already waiting.

## Rules

| Waiting satisfaction | Target arrival factor |
| --- | ---: |
| No data | 100% |
| 10 / 100 | 50% |
| 50 / 100 | 75% |
| 75 / 100 | 100% |
| 100 / 100, with service evidence | 125% |

Target = rating + 25, clamped to 50–125%. A target above 100% additionally requires
at least ten boarding experiences in the station's recent satisfaction history and
an enabled, unheld passenger connection with complete track. A high initial score
alone cannot create a growth bonus. Missing service prevents further growth above
normal; an existing higher factor gradually returns towards its new target.

The current factor starts at 100% and moves by at most **one percentage point per
normal arrival interval** (five simulation seconds). Moving from 100% to 125%
takes at least 125 simulation seconds. The displayed target can change immediately
when conditions change, while the current factor moves gradually. Pause freezes
updates; faster gameplay advances the same fixed-clock rules.

The 50% floor keeps new demand alive so players can recover from poor service.
Existing queues, transfer arrivals and physically returned passengers are never
removed or scaled down. Queue capacity still caps new arrivals; recovery/transfer
overflow remains protected. A full queue does not bank a backlog of rejected
arrivals or consume destination RNG draws.

Amenity percentage carry is applied first, then demand-response carry preserves
fractional passengers deterministically. For example, a sustained 50% factor
applied to three arrivals per interval produces fifteen over ten intervals before
queue caps. The destination distribution remains uniform and uses the owned RNG
in fixed station order. No additional random service-quality rolls are introduced.

## Improve demand

Click the station to examine oldest waits, waiting satisfaction and connection
availability. Provide useful seats/frequency, repair missing track or clear network
bottlenecks. Amenities improve waiting comfort and retain their existing capacity
and attraction effects. New passengers still need actual service to reach their
final destination and pay a fare.

This increment balances arrivals against the measured station waiting experience.
Town population/growth, passenger classes, fare elasticity, journey time and
punctuality do not affect this factor until their measurements and rules exist.

## Saves and tests

Save version **32** stores each station's factor and fractional carry. Version 31
migration starts response at 100%, retaining its queues, arrival ages, satisfaction
history, fleet and positions. Loading cannot bypass the 50–125% factor bounds or
reset a valid carry.

`test_demand_response.gd` covers target bounds, service-evidence gating, gradual
rise/fall, exact fractional demand, continuation after load, invalid state, actual
generation wiring, station/Accounts explanations, physical-state protection, queue
caps, migration and 30/60/120 FPS equality including amenities, destinations and
RNG state (29 checks). Existing service, withdrawal, reservation and save suites
remain required.
