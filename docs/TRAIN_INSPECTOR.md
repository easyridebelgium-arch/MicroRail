# Why is this train waiting?

With ordinary track-building controls selected, **left-click a visible train or
carriage** to inspect it directly. A click opens on release; dragging to another
cell builds track instead, including when starting from a station. Clicking the
platform outside a train sprite, or a station/industry building, opens its existing
station information panel. The primary click follows the player's remapped Build
mouse binding (left by default). Signal/switch/waypoint tools and draft construction
keep their own click actions.

You can also use **Inspect** (default `I`) and click a train or carriage tile on the map. Train
selection takes precedence over the platform beneath it; click the station building
above the track for station controls. Alternatively select a train/service in
**Find**, or a current/historical entry in **Problems**, then **Inspect train now**.
Historical entries open that train's **current** state, not a replay of the incident.
Stored trains are also inspectable through Find.

Opening the inspector pauses and cancels active mouse gestures, leaving staged
construction intact. It preserves the last movement allocation rather than rebuilding
it with paused trains. Closing or navigating leaves the simulation paused.

## Read the evidence

- **State and reason:** traffic wait, approaching restriction, confirmed deadlock,
  dispatcher hold, incomplete route/clearance, normal station dwell, boarding,
  freight loading, withdrawn service, stored train, or ready/moving.
- **Physical body now:** the tiles covered by the complete current train.
- **Last allocation tick:** granted tiles, attempted tile requests (including the
  first refused request) and locked switches with their selected through/branch state.
  This is bounded lookahead, not a reservation of the entire service route.
- **Signal blocks:** physical occupants at allocation, authority holders and whether
  this train requested that block. An authority holder need not physically occupy it.
  `Bxx` labels are transient block IDs and may change when track/signals are edited.
- **Blocking identity:** permanent train ID, custom name and service when known.
  Manual stops do not invent a competing train. Deadlocks list the full involved cycle.
- **Traffic waiting:** simulation seconds from actual zero-movement attempts.
  Dwell, loading and holds are excluded. Counters reset on load; saved incidents remain
  historical evidence. Grant occupancy is sampled before that tick's movement, so it
  is labelled separately from the current physical body.

If authority changes while paused (for example removing a manual stop), an old
waiting episode is labelled **Awaiting movement sample** until the next movement
attempt. Its previous cause is not presented as a freshly confirmed obstruction.

## Act on the actual cause

**Locate conflict cell** points at the signal, conflicting tile or identifiable
missing/incompatible track ahead. **Locate blocking train** follows the named active
blocker. **Show route and authority** enables and synchronizes route/block/reservation
controls. **Traffic controls** selects the inspected train for existing validated
hold/recovery actions; **Fleet controls** selects it for existing fleet management.

Recommendations follow evidence: a manual stop needs a deliberate signal change;
loading needs production or a departure-rule adjustment; incomplete routes need track
or stopping-clearance repair; a block wait needs its authority and route inspected.
The inspector does not claim every wait needs a passing loop or forecast throughput.
**Reverse** turns the inspected train around in place and returns it along its
retained route to the departure stop of the current leg. This works before a
confirmed deadlock, for primary/additional passenger trains and freight. Position,
path and load remain unchanged when the command is issued. The result appears in
the inspector; close and resume to move. Ordinary tile/body reservations, switch
locks and automatic/manual stop signals still apply on the return. At arrival the
train holds with its service disabled; use Traffic Resume or Fleet Enable when ready.
Passenger riders return to the departure queue; freight cargo stays aboard.

The button is disabled for stored trains, missing retained paths, trains already
at their departure stop, and trains already returning. Commands revalidate these
conditions before changing state. Reversing one train does not clear unrelated
confirmed traffic incidents. It does not find a new escape route or guarantee that
blocked track can be cleared. An incomplete return leg waits for repair.

Current signals are bidirectional. One-way signals are planned; when implemented,
the shared reversal validation must reject a return against their permitted
movement direction before changing the train, not merely disable a UI button.

No save-format change or global SignalBus is introduced. Requests and causes are
transient diagnostic records from the existing authoritative decision code.
`test_train_inspector.gd` covers navigation, allocation preservation, cause separation,
missing-track location, stale-wait handling, full cycle identities, authority versus
occupancy and control accessibility at 200% UI scale.

`test_direct_inspection.gd` checks actual press/release/motion input dispatch,
station-versus-train targeting, drag construction, tool priority, draft mode and
Escape/return-to-origin cancellation. Station panels retain their live behaviour;
train popups open paused.

`test_inspector_reverse.gd` covers the actual Reverse button, unconfirmed waits,
atomic rejection, unrelated incident preservation, physical return and manual-signal
compliance for passenger and freight trains.
