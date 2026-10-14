# Passenger occupancy and capacity feedback

Click a passenger train to see **Seats occupied: passengers / capacity** and recent
utilisation in its operating inspector. Open **Accounts** for company utilisation
and left-behind opportunities at Stations A, B and C.

## What is measured

Every fixed simulation tick samples actual onboard counts and the assigned
vehicle's seats, including capacity upgrades and attached passenger coaches.
Measurements use permanent train IDs, so replacing a vehicle does not inherit the
previous vehicle's observations. Mean occupancy is passenger-time divided by
available seat-time; a capacity change therefore updates the denominator fairly.
The full percentage is measured train-time when all seats were occupied.

History covers the latest 120 aligned simulation-second buckets (approximately
119–120 seconds). Company figures combine trains using their measured seat-time
and train-time, rather than averaging percentages. Enabled passenger services
are measured during movement, station dwell, signal/traffic waits, dispatcher
holds and incomplete routes. Withdrawn trains are measured until parked empty at
their first stop. Stored trains and freight are excluded. Pausing adds no samples;
2x/5x/10x advances measurements in simulation time, not wall-clock time.

Each actual boarding opportunity records boarded passengers and eligible people
left in the queue **only if all seats are occupied**. Wrong-direction and
unreachable destinations do not count as denied seats. A full through train can
leave people behind even when nobody boards. History retains the latest 128
opportunities across services, including opportunities with no capacity denial.

These are **opportunities**, not unique passengers: someone waiting through two
full departures may count twice. No passengers are discarded or forced onto a
full train. Use this evidence alongside destination queues, route and signal
inspection before buying more seats or adding services.

## Persistence and scope

Live manifests, capacity, journey clocks and demand remain saved as before.
Recent occupancy and boarding observations are derived diagnostics, like traffic
wait samples: a successful load starts them empty. Failed loads leave them intact.
Occupancy introduced no schema change; save version **34** now additionally
persists separate [arrival targets](ARRIVAL_TARGETS.md). The UI explicitly says
when no service samples exist.

This increment is observational. It changes no fares, waiting satisfaction,
demand response, train movement, route choices or reservations. Crowding penalties
need separate documented rules before scoring. Arrival punctuality is measured
separately without changing fares or satisfaction.

`test_passenger_occupancy.gd` checks time weighting, capacity changes, full time,
identity isolation, bounded history, eligible boarding, held/withdrawn trains,
multiple real services, inspector/Accounts, rejected/successful loads and
30/60/120 FPS equivalence (22 checks).
