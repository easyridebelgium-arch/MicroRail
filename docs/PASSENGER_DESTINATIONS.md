# Passenger destinations — direct journeys

Passengers now have a destination station. Queue totals remain visible, but the
simulation stores A→B separately from A→C, and similarly for B and C. The starter
queue of eight at each station is split four/four between the other two stations.
New arrivals use the owned simulation RNG; its state is saved and restored.

## What changes in play

- An A–B service boards A→B passengers. A→C passengers wait for a route that
  includes C as an actual stop; a waypoint or passing its track is not a stop.
- On A–B–C Shuttle, A→C riders stay aboard at B, where only B-bound riders alight.
  At B on the outward trip, B→C riders can board; B→A riders wait for the return.
- A Loop can board for destinations beyond its closing first stop. A train may
  therefore arrive at its first stop with through passengers still aboard.
- Boarding prioritizes the upcoming stop order, respects the complete train's
  remaining seat capacity and never boards a destination outside the forward
  itinerary. FIFO/age fairness is a later refinement.
- Fares and the delivered counter increase only when the destination is reached.
  Flat £5 fares remain; distance pricing, classes and satisfaction are later work.
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
capacity**. Station waiting-area and demand/amenity upgrades are next Phase 2A work.

## Capacity and demand

The current waiting limit is 100 per station. New arrivals stop when the queue is
full. Returned recovery passengers may exceed that limit and are never discarded;
new demand resumes only when room is available. Increasing train capacity does not
create extra demand. Destinations are initially chosen uniformly from the other
two stations; towns, attractiveness and service-quality demand factors are later work.

Transfers are not implemented yet. Passengers wait for an enabled direct service
instead of boarding a train toward a potential interchange. Service presence is a
configuration fact, not a promise of punctuality or an unblocked route.

## Persistence and invariants

Save version **25** stores destination queues and onboard manifests. Aggregate
waiting/onboard counters are derived views and cross-checked against saved detail.
Invalid destinations, fractional/negative counts, mismatched totals and train
capacity violations reject a load before world state changes. Version 24 and
supported older saves preserve their queue totals; old riders aboard are assigned
to their previously intended next stop. No train changes position during migration. Additional-service expense timers are
backed by fixed ticks so fractional timer drift cannot alter a saved runtime.

Passenger counts are conserved across boarding, through stops, delivery and
physical recovery. Random demand uses one saved RNG in fixed station order. FPS
checks use a common explicit seed as well as a common starting map. Exact generated
demand changes with the seed and station queue availability.

Code: `scripts/core/passenger_demand.gd`, primary passenger hooks in `main.gd`,
`passenger_service.gd` for independent/linked trains. Tests:
`test_passenger_demand.gd`, fixed-frame-rate, service, consists, recovery and save suites.
