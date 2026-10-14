# Passenger destinations and transfers

Passengers now have a destination station. Queue totals remain visible, but the
simulation stores A→B separately from A→C, and similarly for B and C. The starter
queue of eight at each station is split four/four between the other two stations.
New arrivals use the owned simulation RNG; its state is saved and restored.

## What changes in play

- An A–B service boards A→B passengers and can also carry A→C passengers
  changing onto B–C. If no enabled connection exists, C-bound passengers remain
  at A. A waypoint or passing a platform is not a passenger stop.
- On A–B–C Shuttle, A→C riders stay aboard at B, where only B-bound riders alight.
  At B on the outward trip, B→C riders can board; B→A riders wait for the return.
- A Loop can board for destinations beyond its closing first stop. A train may
  therefore arrive at its first stop with through passengers still aboard.
- Boarding prioritizes the oldest eligible station arrivals and respects the
  complete train's remaining seat capacity. Equal-age groups use upcoming stop
  order. Transfer riders board only when a forward stop makes progress along a
  journey with the fewest changes. Unserved demand remains queued.
- Fares and the delivered counter increase only when the destination is reached.
  Flat £5 fares remain; distance pricing, classes and broader satisfaction are later work. Waiting-experience scores are now
  visible; see [satisfaction](PASSENGER_SATISFACTION.md).
- Withdrawal stops taking new riders and completes accepted journeys. A Loop may
  need to continue past its first stop once more to deliver through passengers,
  then return empty before storage/replacement/route edits.
- Recovery keeps passengers on the reversing train until its departure stop is
  physically reached, then returns unfinished destinations to that station's
  queue. It does not turn them into delivered passengers at an arbitrary stop.

Station information shows waiting counts by destination, enabled direct-service
availability, waiting queue capacity and all aboard passengers destined for that
station. The train inspector shows its onboard destination counts. Current station
panel capacity purchases still upgrade the train; the button now says **Train
capacity**. Station waiting-area and demand upgrades are now amenities; see [station amenities](STATION_AMENITIES.md).

## Capacity and demand

The base waiting limit is 100 per station (amenities raise it). New arrivals stop when the queue is
full. A gradual satisfaction-based factor now scales amenity-adjusted arrivals
between 50–125%; see [demand response](DEMAND_RESPONSE.md). Returned recovery passengers may exceed that limit and are never discarded;
new demand resumes only when room is available. Increasing train capacity does not
create extra demand. Destinations are initially chosen uniformly from the other
two stations; towns, attractiveness and service-quality demand factors are later work.

## Connecting journeys

An enabled, unheld passenger service with complete track contributes its station
stops to a deterministic service graph. One edge means travelling without changing
trains; fewest changes win and direct services are preferred. Shuttles serve both
directions; Loops can reach their listed stops after wrapping. Waypoints, freight
routes, stored trains, manual recovery and withdrawn services provide no connection.
This graph describes connectivity, not reservations, a guaranteed departure time,
available seats or punctuality.

On the current three-station map, A–B plus B–C enables A→C via B. Riders keep C as
their final destination while aboard A–B. Physically arriving at B moves them into
B's C-bound queue; they compete for seats on B–C in oldest-eligible-first order. No fare or delivered count is awarded at B. The £5 fare is paid
once at C. Transfer arrivals can overflow a full waiting area without losing riders;
new random arrivals remain capped. There is no walking delay or timed-connection hold.

Through riders stay on A–B–C instead of unnecessarily changing trains. A direct
A–C service is preferred to A–B plus B–C, even if the direct train is temporarily
waiting for track. A held/withdrawn/broken onward service disappears from new
journey plans. Already accepted riders still reach their interchange and safely
wait there until a usable connection returns. Recovery returns unfinished final
destinations to the physically reached departure queue, as before.

Click a station for destination counts and **direct service**, **change at Station B**
or **no enabled connection**. Train inspectors mark off-route final destinations
with **change trains**. Transfer events enter the existing event log. Waiting-experience scores are implemented. Crowding/punctuality satisfaction, larger-map journey leg assignment and
protected timed connections remain later Phase 2A work.

## Persistence and invariants

Destination queues and onboard manifests began in version 25. Version 29 permits
a final destination outside the current train’s stops, for
transfers. Save version **30** adds grouped station-arrival ticks for waiting-age
priority. Version 29 queues start their unknown waiting ages at the saved clock,
without inventing old arrival times or changing counts/positions.
Version 28 upgrades without changing counts, train positions or route instructions. Aggregate
waiting/onboard counters are derived views and cross-checked against saved detail.
Invalid destinations, fractional/negative counts, mismatched totals and train
capacity violations reject a load before world state changes. Version 24 and
supported older saves preserve their queue totals; old riders aboard are assigned
to their previously intended next stop. No train changes position during migration. Additional-service expense timers are
backed by fixed ticks so fractional timer drift cannot alter a saved runtime.

Passenger counts are conserved across boarding, through stops, delivery and
physical recovery and interchanges. Random demand uses one saved RNG in fixed station order. FPS
checks use a common explicit seed as well as a common starting map. Exact generated
demand changes with the seed and station queue availability.

Code: `scripts/core/passenger_demand.gd`, primary passenger hooks in `main.gd`,
`passenger_service.gd` for independent/linked trains. Tests:
`test_passenger_demand.gd`, `test_passenger_transfers.gd`, fixed-frame-rate, service, consists, recovery and save suites.

Validation: the transfer suite covers both train runtimes, a physical two-service
journey, final-only fares, capacity/queue conservation, withdrawn connections,
waiting-area overflow, inspector explanations and version-28 migration. Its fixed
clock fixture compares queues, onboard manifests, cash and the event stream at
30, 60 and 120 FPS with identical results (26 checks).

## Waiting-age fairness

Available seats go to the oldest passengers who can use this departure, across
all eligible final destinations. Equal arrival ticks retain the existing upcoming
stop order. A partially boarded group keeps its original arrival tick; newer riders
to the same destination cannot overtake it. Unreachable or wrong-direction demand
continues waiting without blocking other eligible riders.

The station inspector shows **Oldest wait** per destination in simulation seconds.
It grows with the fixed simulation clock, including accelerated play, and stops
while paused. Arrival groups are saved, so reloading does not reset priority.
Passengers reaching an interchange or physically returning after recovery join
that station's queue at the current tick, behind its existing older groups. This
measures the current station wait, not total journey time; waiting-experience satisfaction is now measured; end-to-end journey clocks now survive transfers and recovery; see
[journey times](JOURNEY_TIMES.md).

Counts remain aggregated; no individual passenger nodes or RNG draws are added.
`test_passenger_age.gd` covers older versus newer demand, partial boarding,
unserved demand, equal-age ties, interchange ordering, age-preserving saves,
invalid/duplicate/future cohorts, legacy migration, station wording and equal
30/60/120 FPS outcomes (21 checks).

Waiting satisfaction now uses these arrival groups and actual boarded counts;
click a station or open Accounts for its score and explanation. See
[passenger waiting satisfaction](PASSENGER_SATISFACTION.md).

Original journey origins and start ticks are now tracked separately from each
station's queue arrival. Train inspectors and Accounts expose current/recent
journey times; see [journey tracking](JOURNEY_TIMES.md). Legacy unknown origins
are excluded from measured complete-trip averages.
