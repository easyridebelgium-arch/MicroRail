# Arrival targets and punctuality

## Set a directional journey target

1. Pause and open **Routes**, selecting the source passenger service.
2. Under **Timetable**, choose a direction, for example **Depart A → B**.
3. Set **Journey target (0 = off)** to a whole number of **game minutes**.
   One game minute equals one simulated second; the range is 1–1440.
4. Set other directions separately, then **Apply** and resume. Linked trains
   inherit their source's targets; unlink to set independent ones.

Targets are optional and work without daily departure schedules. Shuttles have
separate outbound/return targets; Loops include the closing last-to-first leg.
Route copying copies targets independently. Removing a direction removes its
stale target from the draft with a warning. Editing timing instructions leaves
train positions and route geometry unchanged.

## Check the journey guidance

The selected direction now shows an approximate free-running travel-time range
for the source train and trains linked to it in the draft. It builds each assigned
train's own draft path, including a linked train's separate first platform,
from the track graph, platforms and waypoints, and uses its speed
upgrades and attached rolling stock speed limit. Return directions use the same
Shuttle leg in reverse; a Loop closing direction uses only its closing segment.

The hint updates when you edit targets, platforms, stops or waypoints. It flags
target-plus-grace windows shorter than even the fastest train's travel time,
budgets too short for slower linked trains, and budgets that rely on grace.
A fixed tick of rounding tolerance avoids warnings at near-equal boundaries.
Targets remain editable and Apply is not blocked by this advisory hint.

These are travel estimates, not traffic forecasts. Origin dwell is excluded,
while signal waits, dispatcher holds and late departures are not predicted.
Unresolved Auto platforms or an incomplete draft route show guidance unavailable;
resolved Auto choices may change on Apply. Platform fit and safe topology remain
subject to the existing Apply checks. A budget covering free-running travel still
needs operating margin and does not promise on-time arrival.

## How the planned arrival is chosen

A measurement starts only when the train physically leaves its departure stop.
A held or signal-blocked train still at that stop has no new arrival measurement.
For a timetabled departure, the target is the **served scheduled departure time
plus the journey budget**. A late departure therefore consumes some or all of its
budget. Existing timetable rules choose the latest unused due slot and count
older slots as missed; targets use that same served slot.

Without a timetable for that direction, the target is **actual departure plus
journey budget**. This measures running time rather than adherence to a daily
arrival schedule. Start-stop dwell before departure is excluded; signal waits,
missing track, dispatcher holds and other delays after departure are included.

The budget and departure baseline are captured at departure. Editing or disabling
the target mid-trip affects future departures; the current measurement stays
intact. Reversing for recovery cancels that incomplete trip, while preserving
previous results. Rejected reversals leave the measurement intact. Recovery
returns are not ordinary scheduled arrivals and are not scored.

The arrival hook completes the measurement at the destination, before dwell and
before the next leg begins. Early arrivals continue normally; targets never
hold a train in a block, bypass reservations, throw locked switches or move it.

## Read the results

- Click a passenger train: the operating inspector shows its active direction,
  target day/time, baseline and current lateness.
- **Routes** reports completed punctuality for the source and its linked trains,
  split by the current route directions.
- **Accounts** reports company punctuality and average measured running time,
  split by every direction observed in the retained history.

**On time** means arrival no more than **one game minute late**, including early
arrivals. Calculations use exact fixed ticks, rather than rounded display minutes.
Average positive lateness averages `max(0, arrival − target)` over all measured
arrivals, so early trips cannot cancel late trips. Results are weighted by trips,
not passengers. The company history retains the latest 128 completed targeted
trips; a service report filters that same bounded window. Services without a
target contribute no fabricated result. All clocks follow simulation speed and
pause, with identical outcomes at 30/60/120 FPS.

Per-direction results separate mean running time, mean positive arrival lateness
and scheduled departure delay. Departure delay averages only timetabled trips and
shows their count; unscheduled trips explicitly have no scheduled-departure data.
Directions without measured arrivals say so. Reports derive from the original
snapshots, so editing a target does not rewrite past results.

There is **no fare, satisfaction, demand or contract penalty**. Free-running
feasibility guidance and per-direction diagnostics are implemented; congestion
forecasts, timed connections and scoring need further rules. End-to-end passenger journeys remain a separate measure, because
one passenger may change services or stay aboard for several legs.

## Saves and validation

Save version **34** stores active target snapshots and bounded completed results.
Loading preserves exact train positions and the originally captured budget, even
if current configuration differs after a mid-trip edit. Validation checks numeric
bounds, chronology, due-time arithmetic, active vehicle assignment and the current
route direction before applying any world state. Invalid loads leave current
measurements and trains intact.

Version 33 and supported older saves migrate with empty arrival history. An
already-moving legacy train begins measurement on its next physical departure;
its unknown original departure is not reconstructed. Existing queues, passengers,
journey clocks, finances and timetable progress remain intact.

`tests/test_arrival_targets.gd`: 54 checks for targets, copy/link semantics,
precise grace boundaries, bounded results, real departure/arrival hooks, mid-trip
edits and persistence, blocked tracks/repair, cancellation, atomic invalid loads,
old saves, midnight, UI scale 100–200%, FPS equality and 2×/5×/10× simulation.

`tests/test_arrival_guidance.gd`: 34 checks for advisory thresholds, linked models and distinct first-platform paths,
speed upgrades/coach limits, Shuttle return/Loop closure distances, waypoint
refresh, incomplete/Auto drafts, read-only behaviour, group/direction weighting,
JSON history and 100–200% UI layout. This reporting increment requires no new
save version; existing version-34 snapshots retain all inputs.
