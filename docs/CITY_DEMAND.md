# City-owned passenger supply — Phase 2C

City sandboxes now generate passenger trip requests at cities. A station provides
exclusive access to its linked city; building more unrelated stations cannot create
extra sources for the same people. The tutorial retains its original station-based
arrivals and starter passengers.

## What the player sees

- City map labels include population. **Find → City** explains population, recent
  requests, how many joined queues, and reasons requests could not join.
- Station previews quote the population of the city they serve. A station's ordinary
  inspector shows the same linked-city supply report below its service/queue details.
- Cities without stations still have measurable requests, but those requests do not
  appear at another city's station. Stations without useful passenger service likewise
  do not accumulate new city passengers. Already waiting/onboard passengers remain.
- A usable service admits requests into the existing station queue with an original
  arrival time and final station destination. Existing boarding, interchanges,
  journey timing, fares, timetables, reservations and queue limits remain authoritative.
- Local passengers may transfer. Every fourth distant request with both catchments
  available is Express; it requires an enabled direct scheduled leg. Otherwise the
  city report records the unmet Express request instead of creating an unboardable
  Express queue. Near trips remain Local.

The original supply increment used fixed population. [Bounded city response](CITY_GROWTH.md)
now updates it in the live game; the starting values remain unchanged. It starts at 800–1500 people, increasing by
100 in stable sorted city-ID order. This needs no extra RNG draw and therefore can
also initialize older generated saves without changing their random stream.
No buildings expand/shrink and no trains or accepted passengers are relocated.

## Demand and measurement rules

Every existing five-second arrival interval, baseline potential requests equal
`(population + carry) / 400`, rounded down, retaining the remainder. Origin station
amenities and the existing gradual waiting-experience demand response adjust rail
attractiveness once, before admission. At most 32 requests per city per interval
are processed. Current starting populations produce roughly 2–4 requests each.

Each request selects another city using population weights and the one saved
simulation RNG. The choice includes unserved destinations and is never rerolled
into a more convenient station. Cities and candidates are processed in stable ID
order. No new passenger is admitted unless both exclusive catchments exist and
an enabled, complete passenger service path is available. Dispatch-held, recovering,
withdrawn or broken services are excluded by the existing service-graph builder.
Signals and momentary traffic authority are not demand forecasts; queues can still
wait for a timetable or traffic clearance.

Each request has exactly one outcome:

| Outcome | Meaning |
| --- | --- |
| Joined queue | Admitted at its own city's station with the chosen destination. |
| Missing station | Origin or destination has no available city station. |
| No usable service | No enabled connected ride/transfer chain joins the stations. |
| Express needs direct service | Local connectivity exists but no direct Express leg does. |
| Queue full | The origin's existing queue limit leaves no room. |

The last 12 arrival intervals are saved per city: a bounded horizon of at most
60 simulation seconds of arrivals. Requested totals equal the sum of those outcomes.
These are admission measurements: **joined queue does not mean delivered**. There
is no endless off-map backlog of rejected requests, cumulative log spam or payment
for an unserved request. Existing accepted trips are never deleted to fit a cap.

City identities remain authoritative in the world catalog. With the current
one-station-per-city rule, each admitted batch's origin/final station IDs map back
to exactly one city. Passenger batch/journey fields remain compatible with existing
transfers and save validation. Multiple stations per city need explicit allocation
before this ownership model can be expanded.

## Saves and tests

Root save **41** adds `city_demand` schema 1: population, fractional supply carry,
Express intent progress and bounded outcome history keyed by saved city IDs. Saves
validate city membership, bounds, history times and request conservation before
committing. Loading normalizes integers and restores exact continuation.

Version 40 saves migrate to stable populations with empty city measurement history;
existing queues, accepted journeys, actors, geometry, money and RNG remain intact.
Old tutorial saves receive an empty city ledger. Population initialization never
calls the generator. Existing demand at migration is not retrospectively counted
as a new city request or a delivered trip.

On headless Godot 4.6.3, all 104 regression suites pass and the warning audit
passes 84 game scripts. The focused model suite passes 25 checks covering ownership, missing stations/services, Local transfers,
Express eligibility, full queues, conservation, bounded histories, JSON and weighted
RNG continuation. The scene suite passes 26 checks covering actual station construction and services,
UI reports, v40 migration, rejected-save atomicity, active-train save/load and
matching simulation at 30/60/120 FPS. The existing city-save suite still covers
freight-only/mixed companies and processing/consist persistence.

Implemented next slice: [useful-service cohorts](USEFUL_SERVICE.md) connect actual
completed journeys and unmet requests, preserving unfinished/transfer identities.
The next slice is now implemented: [bounded population response](CITY_GROWTH.md)
with grace, limits, pending-journey protection, reasons and saved growth rules. Merely filling queues must never earn growth.
