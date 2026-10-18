# Deterministic dispatch fairness

Choose a service in **Routes → Dispatch priority: Low / Normal / High**, then
**Apply**. The choice stays in the route draft until Apply; Cancel/reopen discards
it. It changes dispatch opportunities, not speed, fares, running costs or passenger
classes. Every service defaults to Normal, including existing companies. Linked
services keep an independent priority; copying route instructions preserves the
target priority.

Requests use **600-tick (ten simulation-second)** turns. In a mixed-priority fleet,
Low gets one leading turn per cycle, Normal two and High three. For example, IDs
1 Low, 2 Normal and 3 High lead in the order **1, 2, 3, 2, 3, 3**, then repeat.
Within a turn, the other IDs follow in cyclic sorted order. Every assigned on-map
train retains a leading opportunity; stored off-map trains do not participate.
A cycle has at most three times the active train count in turns. Equal-priority
fleets use ordinary round robin, exactly as before. Parked, dwelling and held trains
protect their bodies but do not request ahead.

The same ranking feeds tile reservations, switch locks, signal-block requests and
the final signal-limited reservation rebuild. Physical occupancy is always seeded
first, independently of the rotating preference. No preference can steal occupied
space, override a manual stop or change a locked movement unsafely. Movement still
uses the existing whole-body authority checks and releases after clearance.

## Inspecting prolonged waits

Open a train's operating inspector and expand **reservation details** to see its
request position at the last allocation and time until the next rotation. The
inspector flags continuous measured traffic waiting of at least one full rotation
cycle (minimum 20 simulation seconds). This is a diagnostic, **not proof of
starvation**: inspect the actual blocking train, occupied block, manual signal,
incomplete route or deadlock. Waiting measurements reset on load as before.

Rotation provides opportunities to win an otherwise free contested resource; it
cannot guarantee passage through occupied track, an unsuitable single-track layout
or a manual stop. It does not choose passing loops, reserve an entire journey,
resolve deadlocks or automatically label Express trains High. All priorities are player-selected. Existing single-track
section holds and departure rules still apply; this does not replace them with a
global journey dispatcher. A preference change
may change future unoccupied grants; existing occupancy and movement checks still
prevent overlaps. Adding/removing assigned trains changes the cycle deterministically.

## Persistence and verification

The ranking is a pure function of saved simulation tick, active fleet IDs and
service priority. There is no extra random stream, hidden queue or wall-clock timer.
Save version **49** records the optional service priority; absent means Normal.
Version 48 migration preserves physical state, RNG, finances and route instructions
without inventing preferences. Unsupported or non-integral priorities are rejected. Loading reconstructs the same order for the same tick, priorities and active trains;
pause does not advance the cycle. Simulation speed changes elapsed real time,
not how many simulation ticks each train receives first choice for.

`test_dispatch_order.gd` covers rotating tile/switch/block grants, stationary body
and occupied-block precedence, input-order independence, clock save/load,
prolonged-wait wording, and crossing trains through a rotation boundary without
body overlap. Per-tick movement/grant histories match at 30/60/120 FPS at both 1×
and 10×. Existing reservation, signal, siding, long-consist, deadlock and inspector
regressions remain part of validation.

`test_service_priority.gd` verifies the 1:2:3 allocation, a turn for Low, bounded
cycle diagnostics, validation, independent linked priorities, draft cancellation,
Apply without teleporting a loaded mid-route train, actual main-scene dispatch,
invalid edit refusal, and version 49 save/load and version 48 migration. The moving
crossing FPS/speed test also uses mixed Low/High priorities.
