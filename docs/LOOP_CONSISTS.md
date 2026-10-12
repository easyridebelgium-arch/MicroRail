# Carriage trains on continuous Loop circuits

Carriage trains can now use **Loop** routes on a continuous physical circuit.
For A, B, C the service visits **A → B → C → A**, dwells at every stop, and
continues in the same direction. Primary and additional passenger services have
the same support. Shuttle routes still visit A → B → C → B → A.

## Build a suitable circuit

The itinerary and the track layout must agree. A long Loop needs a through route
at every station, including its first station. A train cannot turn around at C and
retrace its own outward track as part of this version of a Loop.

One example is an A–B–C line with a return track that continues **past C**, loops
around the east end, and joins **to the left of A**. The train arrives and departs
A/B/C in the same physical direction. A terminal at C needs an extension before it
can be part of this circuit. A passing loop alone does not make an entire service
a continuous circuit.

1. Withdraw the chosen service, let it return empty to its first stop, then pause.
2. Build a continuous circuit and keep straight, signal-free stopping clearance
   under the complete body at every station. Existing fits/refusal messages still
   apply to every carriage count.
3. Open **Routes**, select **Loop**, and order the desired stops.
4. Select the **closing leg** (e.g. C → A) and add waypoints on the separate return
   track. The test circuit uses an eastern connection at 40,4 and the return west
   of A at 2,4; these are examples for that layout, not mandatory coordinates.
5. Apply, enable the service in Fleet or release its dispatcher hold in Traffic,
   close the windows and resume simulation.
6. Add signal boundaries on the approaches/branches to avoid treating the entire
   network as one large block. Check the block overlay and waiting inspector;
   Resume does not override occupied blocks or a manual stop.

Start with one carriage service, then add another running in the same direction
on suitable clear starting platforms. Other shared/opposing traffic still needs
passing tracks, appropriate waypoints and signal boundaries. Loop support does not
resolve a head-on standoff automatically.

## What is preserved

Vehicle positions and the full physical body follow the same periodic curve.
When the service cursor wraps from the closing leg to zero, carriages keep their
positions. Wrapped nose/tail tiles keep ownership, switch locks and signal-block
occupancy; only cleared space releases. A held or dwelling train remains an obstacle.

Manual **Reverse** retains the body in place and returns to the departure stop of
the current leg. Reversing on C → A returns to C, not the first station A. Signals
and reservations still apply; at arrival the service holds as before. Current
signals remain bidirectional.

Saves stay **v23**. Positions, route cells and returning state already exist in the
schema; periodic poses, ownership and locks are derived on load. The loader uses
the same shape check as route activation, so malformed/folded saved circuits cannot
bypass the carriage restriction. Save loading remains atomic and checks full bodies
for overlaps.

## Current boundary

The only repeated route cell permitted for a carriage Loop is the closing first
stop. Planned reversals at intermediate stations, figure-eight/repeated-track
circuits and shunting still need occurrence/history-aware body routing and remain
rejected for carriage services. Single-vehicle routes retain their existing rules.
This is progress within Phase 1B, not completion of its platform or reversal work.

`test_loop_body.gd` covers periodic vehicle poses, curve-crossing tails, switch
locks across the join, competing body occupancy, wrapped signals, actual blocker
diagnostics, cache invalidation, legacy single-vehicle repeated switch occurrences,
and matching wrapped movement/authority at 30/60/120 FPS.
`test_loop_consist_integration.gd` exercises full laps, all carriage counts fitting,
primary/additional service save/load, closing-leg recovery and two same-direction
carriage services sharing signal blocks without body overlap.
