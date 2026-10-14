# Seeded cities and player-built stations — Phase 2C plan

The saved catalog foundation and flat-grid candidate generator are implemented
([world catalog](WORLD_CATALOG.md), [generator](SEEDED_LAYOUT_GENERATOR.md));
playable seeded starts, station construction and growth remain planned gameplay.
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
   Generated starts still need feasible layouts, station construction and
   empty-network/service startup.
   Old tutorial saves migrate without moving platforms, trains or passengers.
2. **Seeded layouts (flat-grid generator implemented):** 3–8 spaced cities and
   four freight-chain sites are generated deterministically on the 80×50 grid.
   Initial geometry checks station clearances, freight-strip separation and flat-land
   access ([generator details](SEEDED_LAYOUT_GENERATOR.md)). The candidate is not yet
   a playable new-game option. Save the actual generated layout as well as seed,
   generator/content versions and rules; regenerate neither geometry nor passengers
   during load. Startup finances/objectives and operating routes still need validation.
3. **Station construction and catchments:** preview price, orientation, platform
   footprint, building clearance and population served. A passenger station must
   connect to a nearby city's catchment. Cities own trip origins/destinations;
   stations provide access to services. Start with one station per city, then extend
   to several with explicit catchment allocation to avoid duplicating customers.
   Reject overlap and protect occupied/reserved rail during edits.
4. **Playable sandbox chooser:** expose seed and city/industry density once dynamic
   stations and usable routes work end to end. A generated map without prebuilt
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
