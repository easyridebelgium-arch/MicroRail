# Seeded cities and player-built stations — Phase 2C plan

The saved catalog foundation and flat-grid candidate generator are implemented
([world catalog](WORLD_CATALOG.md), [generator](SEEDED_LAYOUT_GENERATOR.md));
City-linked station preview/purchase rules are also implemented
([construction backend](CITY_STATION_CONSTRUCTION.md)); the
[main-scene preview](CITY_SCENE_PREVIEW.md) now connects startup, editors and station
placement. [Generated saves](CITY_SAVES.md) are now implemented; the ordinary
[seed chooser](NEW_GAME.md) is implemented; [city population/trip supply](CITY_DEMAND.md) is implemented; [bounded growth/decline](CITY_GROWTH.md) is now implemented. Geographic expansion and deeper economic influences remain planned.
The [empty-start construction model](EMPTY_SANDBOX_START.md) now initializes the
generated world without default stations/trains and safely extends station-owned
state as stations are purchased. Main-scene startup/editor integration is available
in the development preview; persistence is implemented and normal new-game
selection is implemented.
The fixed three-station map remains the tutorial and supports existing saves.
New sandbox layouts will instead contain cities and industries, with the player
building stations beside cities and connecting useful services.

## Dependency order

1. **Saved world catalog (foundation implemented):** persist stable settlement, station and industry IDs,
   positions, names and content versions. Routes, passenger destinations, station
   inspectors, demand and save validation must use this catalog instead of fixed
   A/B/C entries. Rendering, markers and station labels now use it; route/platform
   builders and passenger-demand/journey validators are integrated in stages.
   Route/platform, retained-path and Local queue adapters are now implemented
   ([details](CATALOG_ROUTING_AND_DEMAND.md)); journey
   validation and station-owned metrics are now adapted
   ([station state](CATALOG_STATION_STATE.md)). Facility positions and distance-based
   class policy are adapted too ([details](CATALOG_FACILITIES_AND_CLASSES.md)).
   Feasible layouts, station construction, empty-network/service startup and
   generated persistence are now available through the development preview.
   Old tutorial saves migrate without moving platforms, trains or passengers.
2. **Seeded layouts (flat-grid generator implemented):** 3–8 spaced cities and
   four freight-chain sites are generated deterministically on the 80×50 grid.
   Initial geometry checks station clearances, freight-strip separation and flat-land
   access ([generator details](SEEDED_LAYOUT_GENERATOR.md)). The layout is now available through the normal
   [New Game chooser](NEW_GAME.md). Save the actual generated layout as well as seed,
   generator/content versions and rules; regenerate neither geometry nor passengers
   during load. Representative first-service finances and operating routes are tested; deeper
   scenario balance remains.
3. **Station construction and catchments (backend, preview UI and saves implemented):**
   horizontal five-tile platform previews, itemized purchase costs, exclusive nearest-city
   links and stale/safety checks are implemented ([details](CITY_STATION_CONSTRUCTION.md)).
   Empty-start, station-owned state expansion, main-scene editors and fixed-tick
   placement and generated persistence are connected to the normal New Game flow.
   The full tool will show price, supported orientation, platform
   footprint, building clearance and linked population (now implemented). A passenger station must
   connect to a nearby city's catchment. Cities own trip origins/destinations;
   stations provide access to services. Start with one station per city, then extend
   to several with explicit catchment allocation to avoid duplicating customers.
   Reject overlap and protect occupied/reserved rail during edits.
4. **Playable sandbox chooser (seed/city-count and starter checks implemented):** the menu exposes seed and city count, with
   four fixed industry sites; industry-density controls remain a later refinement. A generated map without prebuilt
   stations must be playable before it is offered as a new-game option. Keep the
   A/B/C tutorial selectable.
5. **Growth and decline:** use bounded population and a measured window of useful
   served versus unmet passenger demand. Reliable service, capacity and reachable
   destinations support growth; sustained poor or missing service supports gradual
   decline. Give new cities a grace period. Show the current population, trend,
   demand and specific reasons; offer slower/no-growth settings.

City expansion must respect buildings, station access and rail rights rather than
covering track. Decline must not delete stations, onboard passengers or accepted
journeys; use a documented population floor and bounded rates. Industry supply,
local jobs and land purchase can influence growth in later refinements once these
measures exist. Growth should not be awarded merely for laying track nearby.

## Acceptance gates

- Same seed, generator/content version and settings produce the same starting map.
- Save/load preserves generated geometry, IDs, passenger trips and physical trains.
- Station previews show catchment and price; failed placement charges nothing.
- Unserved cities do not create passengers at unrelated freestanding stations.
- Catchments allocate each passenger once, including overlapping station coverage.
- Good service supports gradual growth; sustained unmet demand supports decline
  after the grace period. Pausing and 1×/2×/5×/10× follow the fixed simulation clock.
- Visual expansion/shrinkage respects infrastructure; existing safety checks pass.

Full terrain generation, rivers, complex commuting/jobs and rival land rights come
later. The first seeded-city slice can use the current flat grid and placeholder
building art while preserving a clear simulation model.
