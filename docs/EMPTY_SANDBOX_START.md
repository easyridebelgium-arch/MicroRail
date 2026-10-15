# Empty sandbox startup — Phase 2C construction model

`scripts/core/sandbox_start.gd` initializes the construction-stage state of a
seeded game without instantiating the legacy main scene or its default actors.
It connects generated geometry, RNG continuation and station purchase rules to
station-owned passenger state. It now drives the
[main-scene development preview](CITY_SCENE_PREVIEW.md), but is not yet a normal
New Game choice. Generated games now persist through [version 40 saves](CITY_SAVES.md).

## Initial state

Create a new startup object and call `initialize(seed_text, city_count)` once.
It validates/generates the flat layout before adopting any state. Invalid input
leaves the object uninitialized. A second initialization is rejected so it cannot
silently discard a developed construction session.

A successful start contains:

- The actual generated world catalog, with cities and four industry sites.
- No passenger stations, track, services or preassigned/purchased trains.
- Fleet `{next_id: 1, trains: []}` and a fresh fixed-tick clock/command queue.
- The layout generator's RNG continuation, without reseeding or extra draws.
- Empty demand, amenities, satisfaction, demand-response and journey models.
- A provisional £5000 sandbox construction budget and zero construction expense.

The sandbox budget is separate from the unchanged £1000 tutorial. Affordability
of actual startup routes/objectives must still be checked in the playable slice;
this amount does not establish a balanced scenario or an economy simulation.
Cities without stations do not create queues at invented A/B/C stations. City-owned
population/trip generation and growth remain separate planned work.

## Adding stations

`station_preview` and `station_draft` call the existing construction rules with
current catalog, rails, signals/claims and funds. `commit_station` revalidates the
draft, then stages a new catalog, rail/accounting snapshots and all station-owned
models before adopting them together. Failed purchases replace none of those.
The future authoritative command handler must call this with current signal,
reservation and physical-occupancy data; this helper does not process UI input,
advance simulation, record construction events or rebuild actor routes itself.

New stations start with zero queues and neutral/empty measurement defaults.
Existing queue counts, age/origin/class batches, class progress, amenities and
fractional carries, satisfaction history, demand response, unfinished journeys
and completed history survive expansion. Models own independent copied state.
Station construction neither draws random numbers nor advances time, creates a
service or buys a locomotive. A newly available destination does not inject the
tutorial's eight starter passengers into an established network.

## Explicit validator policy

`Fleet.is_valid(value, require_primary = true)` and
`ServiceRoutes.is_valid(value, catalog, positions, require_primary = true)` keep
the existing defaults. Tutorial save callers still require the original passenger/freight services and
assigned trains. The validated city save profile explicitly opts into optional actors.

Passing `false` explicitly allows an empty fleet, an unassigned first purchase,
no services or freight-only operation without passenger stations. IDs, model
kinds, assignment uniqueness, service geometry and linked instructions remain
validated. The maximum remains eight passenger services, even without freight.
The live loader checks the selected profile and its geometry before accepting optional actors.
`PassengerDemand` similarly keeps eight tutorial starter passengers by default;
the startup helper explicitly requests zero.

## Evidence and next integration

All 99 regression suites pass on headless Godot 4.6.3. The focused
`tests/test_sandbox_start.gd` suite passes 42 checks covering strict/empty policy boundaries, deterministic
initial state, no phantom queues, first/second/third station purchases, preservation
of nonempty passenger/measurement/journey state, cost accounting, failed-purchase
atomicity, independent starts and JSON-safe RNG continuation.

Main-scene startup/editor controls and actor access now support absent primary
services. Station placement, city rendering and dynamic state adoption are connected
to fixed-tick commands, preserving active physical trains. Generated-game save validation/restoration is now implemented in root save version
40, including older tutorial migration. Next expose the normal seeded new-game
selector and validate startup finances/objectives.
