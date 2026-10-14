# Local and Express passenger demand

## Gameplay rules

**Local** passengers accept intermediate station stops and the existing
fewest-change transfer planning. **Express** passengers want a nonstop station
leg between the current map's distant hubs, **A and C**. They board only if the
train's next scheduled stop is their final destination. A train can pass Station
B's track without stopping there; waypoints and passing loops do not count as
station calls.

- A–B–C Shuttle: Local passengers can travel throughout; Express waits at A/C.
- A–C Shuttle: both classes can board in either direction.
- A–C–B Loop: A→C accepts Express, while C→B→A does not.
- A–B plus B–C: Local can change trains at B; Express keeps waiting at its origin.

Eligibility follows the stops and direction, not the locomotive model, speed,
livery, signal state or service name. A standard train running A–C qualifies;
a fast train stopping at B does not. Signals, track authority and route integrity
still decide whether an eligible train can move.

One in four **newly generated A→C passengers** and one in four **new C→A passengers**
are Express. Every other new passenger is Local. A saved counter per origin
implements this mix deterministically without extra RNG draws or extra demand.
Full station queues generate nobody and advance neither the class counter nor
random stream. Initial passengers and supported older saves remain Local; there
is no retroactive reclassification. This is an initial map-specific rule, not a
configurable population or ticket-class model yet.

## Read the information

In **Routes**, select a departure direction under Timetable. The guidance states
whether that leg accepts Express as well as Local. Station **Details** and
**Accounts** show waiting counts by class and explain the direct-service rule.
Click a passenger train for its onboard Local/Express counts.

Eligible passengers still board oldest first, within capacity. Equal-age groups
retain the existing destination ordering; otherwise-identical groups use Local
before Express as a deterministic tie. There is no class priority or seat quota.
A full eligible direct departure can create a capacity-denial observation; people
waiting for a different service/class opportunity do not count as denied seats.

Classes stay with original journey groups through partial boarding, completed
journeys, saved games and physical reversal/recovery. Express recovery returns
unfinished passengers to their original departure queue with their preference
and original journey clock intact. Local transfers preserve their class while
starting a new station wait as before. No passengers teleport or disappear.

## Economy and persistence

Both classes currently pay the existing **£5**, only at their final destination.
There is no Express bonus or new class-specific satisfaction penalty yet. Existing
waiting satisfaction includes all waiting groups, so unmet Express demand can
lower the existing station waiting rating just like other passengers' long waits.
The next increment will add differentiated fares with recorded income so the
financial UI stops relying on `delivered × flat fare`.

Save version **35** stores class metadata in station groups and journey records,
plus the two generation counters. Class totals remain views of the original
aggregate destination counts, preserving conservation and train capacity.
Version 34 and supported older saves migrate to Local without changing counts,
positions, ages, journey clocks, money, timetable progress or arrival targets.

Save validation rejects unknown classes, impossible Express origin/destination
pairs, Express station groups away from their origin, incompatible onboard service
routes and invalid counter fractions before loading any world state.

The demand helper defaults to Local-only generation for legacy/admin callers;
normal game generation explicitly enables classification. Aggregate fixture/admin
queue resets create Local groups and cannot invent Express journey provenance.

`tests/test_passenger_classes.gd`: 41 checks covering generation mix/no extra RNG,
capacity, fairness-compatible groups, Local transfers, direct/Loop eligibility,
partial Express boarding, physical recovery, income unchanged, atomic invalid
loads, migration, actual game generation, UI explanations and FPS determinism.
All network, journey, occupancy, timetable and save suites remain requirements.
