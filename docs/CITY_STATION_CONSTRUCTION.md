# City station construction — Phase 2C backend

`scripts/core/station_construction.gd` provides pure placement previews, catchment
ownership and purchase transactions for the `seeded_flat` city profile. This
increment does not add a station tool to the current tutorial or enable generated
games in New Game. The placement UI and starting with no network/services come next.

## First station rules

A station has a horizontal five-tile platform, centered on its stop, and a 3×2
building on the two rows immediately above it. This matches current platform
measurement and supports the existing maximum consist: a locomotive and four
attached vehicles. The generator's proposed station locations leave room to
extend track and build a passing loop; that additional track is not purchased here.

Catchment is measured from the stop to a city center: a squared grid distance of
at most 36 (a six-tile radius). Choose the closest city; equal distances use the
lowest stable city ID, independent of catalog row order. The station links to
that one city explicitly. It does not collect another city's passengers merely
because two catchment circles overlap. The first version allows one station per
city. Multiple stations and population-based allocation remain later work.

Station identity is derived from the city: `town:01` becomes `station:city_01`,
with route stop ID `city_01`. Names use the city label. `catchments(world)` includes
all cities, returning their enabled station stop ID or an empty string if unserved.
`valid_links(world)` rejects duplicate city ownership and stations beyond their
linked city's catchment. Actual population, city-owned trip generation and growth
are not implemented by this assignment map.

## Preview and purchase API

`preview(world, stop, tracks, signs, claims, money)` returns:

- `ok` and a readable `message`, including why a rejected placement cannot proceed.
- `building_cells`, `platform_cells` and the stop `cell` for a future ghost renderer.
- The linked city, station stop ID/name, and an itemized `cost`.

The provisional price is £250 plus £10 for each missing platform track tile:
£300 on empty ground. Existing compatible horizontal rails are reused and retain
their original graph representation. The preview neither charges funds nor alters
geometry, signals, services, passengers or random state. It reports the city served;
population-served numbers will require the upcoming population model.

Placement checks the complete building/platform footprint. It rejects map edges,
city buildings, other station footprints, industry sites (including unbuilt
processors), track under the building, incompatible rails, signals, and train
claims. A switch, curve, crossing or vertical rail cannot be replaced with a
platform. Even compatible rails under an active train claim must clear first.

`draft(...)` records the world and footprint track/signal read set of a valid
preview. `purchase(draft, world, tracks, signs, claims, money)` checks that those
reads remain current, rechecks funds and train claims, and recomputes price and
station identity. It preserves unrelated rail edits. Changing draft metadata
cannot grant a free or differently named station.

Successful purchases return fresh `world`, `tracks` and `money` snapshots, `spent`,
`station_id` and `catchments`. Failed purchases return only an error outcome. Neither
case mutates caller-owned state. The future fixed-tick command handler must adopt
all successful snapshots together, record `spent` in construction accounts, refresh
station-owned demand/metrics/UI state and rebuild routing/reservations. It must supply
current reservations **and physical occupancy** in `claims`; the module does not
read live train actors itself. UI clicks must not bypass that authoritative command.

## Persistence and evidence

New city/station links use the existing world catalog representation. JSON restores
their geometry and stable identity, but the playable game loader still supports
only the tutorial profile. Save version 39 therefore stays unchanged at this stage.
Full generated-game save/load is a gate for exposing the new-game selector.

All 98 regression suites pass. The focused suite passes 42 checks covering
affordability, reuse, footprint safety, stale drafts,
changed funds/claims, duplicate catchments, JSON identity, graph routing and catalog
consumer visibility. It also builds all 264 proposed stations across 48 seeded maps
and checks their costs and exclusive city links. No station tool or generated-game
UI behavior is claimed by these backend tests.

Next: empty-network/service initialization, city rendering and an authoritative
placement tool using these previews; station-owned state must extend safely when a
station is purchased. Then enable a playable seeded start and its persistence.
Service-driven city growth/decline follows those foundations.
