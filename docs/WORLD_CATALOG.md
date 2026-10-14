# Saved world and facility catalog — Phase 2C foundation

Save schema **39** adds a versioned `world` section with layout identity,
generator/content versions, layout seed, map size, settlement rows and facility
rows. Loading restores saved geometry rather than generating a replacement map.
Version 38 migration adds the existing tutorial catalog without changing trains,
routes, passengers, cash, industrial stocks or the saved simulation RNG.

## Current gameplay

The playable layout is still the A/B/C tutorial. Its saved facilities have stable
IDs: `station:a`, `station:b`, `station:c`, `industry:forest`, `industry:terminal`,
`industry:sawmill` and `industry:factory`. Optional processors become enabled when
installed; installation immediately updates the network map. Their loading tracks,
prices, physical positions and safety rules remain the same.

Drawing, building-space protection, station lookup, map markers, station labels,
Find and the station choices in Routes/Fleet read this per-game catalog. Station
names remain separate from stop IDs; cached station definitions are read-only.
No static global station dictionary is changed, so two game instances cannot
change each other's catalog. Labels refresh when opening an editor after loading.
The current tutorial keeps its original fixed facility names on industry screens.

The layout seed is `"0"` for this fixed tutorial profile; it is separate from the
saved simulation RNG seed/state. No random draws occur while creating or restoring
its catalog. Future seeded layouts will save their seed and generated geometry.
A seed alone does not promise identical maps across generator/content versions.

## Schema and validation

- Settlement: stable `town:` ID, display name and tile coordinate.
- Facility: stable ID, stop ID, kind, display name, coordinate, settlement ID and
  enabled flag. Stations use `station:` IDs; industries use `industry:` IDs.
- Catalog limits: 64 settlements, 64 facilities and bounded map dimensions.
- IDs and stop IDs must be unique. Names, whole-number coordinates and versions
  are bounded. Layout seeds use canonical decimal strings, avoiding JSON rounding.
- Station settlement references must exist. Non-tutorial station rows require a
  settlement relation; the tutorial's empty settlement list preserves legacy play.
- Enabled facility platforms and building footprints cannot overlap or leave the map.
- JSON numbers are validated by value, then normalized on restore.

The catalog model can describe other station IDs/geometry and settlement links.
**Current game-load validation accepts only the supported tutorial profile** and
requires optional industry flags to agree with the industry inventories. A moved
platform or a different station set is rejected before changing the live game.
This guard prevents rendering saved geometry while the remaining tutorial-specific
routing and demand code uses A/B/C elsewhere.

## Next dependency

Route building, platform geometry and Local passenger queues now accept explicit
per-game catalogs ([backend adapters](CATALOG_ROUTING_AND_DEMAND.md)). Retained
paths and additional-train saves use those identities too. Journey/interchange validation, station-owned amenities/satisfaction/response and
aggregate reporting are now adapted ([station state](CATALOG_STATION_STATE.md)).
Next adapt facility geometry and broader class policy, preserving accepted journeys. Then add seeded settlement/industry placement, city-linked station
construction and a usable sandbox chooser. Growth/decline follows measured useful
service and unmet demand. These gameplay systems are planned, not enabled by this
catalog update. See [seeded cities plan](SEEDED_CITIES_PLAN.md).
