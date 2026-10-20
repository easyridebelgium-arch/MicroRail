# Station, routing and planning update — batches 1–3

This combined update ships operating features together with their controls,
save support, safety checks and documentation. It extends the supported game;
it does not enable arbitrary train/platform geometries or guarantee that a
single-track layout cannot deadlock.

## 1. Station operations

In Routes, select a stop and choose **Auto** for its platform. A train prefers its
existing choice, then considers another connected platform that fits its full
body and is not occupied or another train's claimed destination. Body clearance
checks cover the full stopping footprint, not only the centre tile.

The choice may be reconsidered while approaching, provided the entire travelled
leg, current body and three-tile lookahead retain identical geometry. A directional
single-track departure claim commits its chosen branch until arrival; it cannot
be retargeted mid-section. Reversal/recovery is never replanned. A too-late or
unavailable alternative leaves the retained route intact and normal signals and
reservations explain the wait. This is safe reselection, not teleportation or a
promise to find a free platform after passing its junction.

Shuttle and supported Loop routes use the rule. Long consists retain existing
route-shape/clearance restrictions. Platform assignments persist through the
existing service and retained-route records; load rebuilds transient authority.

A safety fix also seeds switch stem/selected-exit clearance for physical switch
occupants **before** future requests. A follower cannot take the stem while a
leader's body still occupies the switch, even when the follower gets the next
dispatch turn. Physical occupancy remains distinct from reserved clearance.

## 2. Routing and signals

Signals clicks now cycle **automatic → manual stop → one-way in each rail
direction → remove**. One-way arrows also request ordinary block authority; they
do not override occupancy or holds. Arrows point in the permitted travel direction,
including diagonal track. Drafts, save validation and blueprint transforms use
the same direction/geometry rules. Reverse preflight refuses an opposing one-way
signal on the retained return path before changing position, direction or load.

Routes now offers a waypoint **approach direction**. Select a waypoint and choose
travelling N/NE/E/SE/S/SW/W/NW, or select a direction before adding a new one.
“Approach travelling E” means enter that waypoint from its western neighbour.
Any approach retains the previous behaviour. Wrong-way approaches cannot satisfy
the route or its saved retained geometry. Shuttle directives govern its outward
path; the train retraces that path on return.

For a two-stop service, **Edit independent return path** switches only the draft
to Loop and selects its closing leg. Outward and return waypoints can then differ.
Use opposite one-way lanes on a passing loop to let routing choose the permitted
branch; add a waypoint when you need to specify it. Apply still requires the safe
editing state and validates physical route shape. Long Loop consists require a
continuous circuit through the first stop; the shortcut does not relax this rule.
Multi-stop Loop remains an ordered circuit, not an independently routed out-and-
back Shuttle. Existing multi-stop Shuttle retracing is unchanged.

Signals constrain new route searches and actual movement. Installing a one-way
signal does not teleport or silently reroute a moving train; an incompatible
retained journey waits until its infrastructure/orders are corrected. An empty
route is refused rather than bypassing direction rules. Route/platform-specific
signal modes and automatic dispatch detours around occupied branches remain
future refinements; one-way lanes are a direction rule, not a congestion solver.

## 3. Planning tools

In Overlays → Draft construction → Track blueprints, select **Rotation** and
**Mirror blueprint** before placing. Reflection happens first, then clockwise
rotation. Simple track ports, crossing lines, switch stem/through/branch roles
and one-way arrows all transform. The source library design is unchanged.
Placement stages a ghost through normal map, facility, price and reservation
validation; Apply and Undo/Redo remain atomic. A rotated design too tall/wide
for supported map dimensions is refused without a partial draft.

Draft quotes now itemise track, switch and bridge surcharges and their refunds.
Signal edits explicitly cost £0 in the prototype. The itemised amounts reconcile
with the existing total; prices and refunds themselves are unchanged.

Overlays reports shared unbranched runs between retained connected services,
with train IDs, tile count and location. These cached warnings invite review of
passing places and approach signals. They report structural facts, not predicted
congestion or proof of deadlock; they never allocate authority. Congestion view
also lists the three largest measured waiting hot spots in the recent ~60-second
simulation window. Dwell, loading and deliberate holds are excluded; derived
measurements reset on load.

## Persistence and validation

Save schema **54** expands supported signal modes and optional waypoint direction
records. The v53 migration preserves existing data without adding fictional state;
two-coordinate waypoints and automatic/manual signals retain their behaviour.
Older code should reject the newer schema. New waypoint records optionally contain
`[x, y, direction_index]`, with indices clockwise from N (0) to NW (7).

Focused tests cover directional routing and movement, independent Loop lanes,
waypoint approach validation, switch clearance ordering, blueprint transforms,
cost reconciliation, structural caching, actual platform retarget/save/load,
reversal refusal, editor shortcut and 200% layout. Existing network, consist,
scenario, blueprint and save regression suites protect the surrounding systems.
