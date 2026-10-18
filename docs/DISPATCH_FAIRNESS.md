# Deterministic dispatch fairness

Permanent train IDs no longer give one train first choice forever. At tick zero,
requests start in ascending ID order. Every **600 fixed ticks (ten simulation
seconds)**, that sorted order rotates by one position. Each assigned on-map train
therefore gets first choice once per cycle; stored off-map trains do not participate.
Parked, dwelling and held trains still protect their bodies but do not request ahead.

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
resolve deadlocks or give Express services a priority class. Existing single-track
section holds and departure rules still apply; this does not replace them with a
global journey dispatcher. A preference change
may change future unoccupied grants; existing occupancy and movement checks still
prevent overlaps. Adding/removing assigned trains changes the cycle deterministically.

## Persistence and verification

The ranking is a pure function of saved simulation tick and sorted active fleet
IDs. There is no extra random stream, hidden queue, wall-clock timer or new save
field. Loading reconstructs the same order for the same tick and active trains;
pause does not advance the cycle. Simulation speed changes elapsed real time,
not how many simulation ticks each train receives first choice for.

`test_dispatch_order.gd` covers rotating tile/switch/block grants, stationary body
and occupied-block precedence, input-order independence, clock save/load,
prolonged-wait wording, and crossing trains through a rotation boundary without
body overlap. Per-tick movement/grant histories match at 30/60/120 FPS at both 1×
and 10×. Existing reservation, signal, siding, long-consist, deadlock and inspector
regressions remain part of validation.
