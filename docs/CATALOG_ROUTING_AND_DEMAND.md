# Catalog-driven routing and local passenger queues

This Phase 2C increment adapts route building, retained paths and local passenger
queues to explicit station catalogs. The playable profile remains the A/B/C
tutorial until the other station-owned systems and world generation are adapted.

## Implemented

- Service validation and route building accept a per-game station dictionary,
  including unfamiliar IDs, different positions and more than three stops.
- Platform offsets and protected waypoint tiles come from that dictionary.
  An unused old tutorial station location is not automatically protected when
  a different catalog is explicitly supplied.
- Retained passenger geometry is reconstructed against its own station catalog.
  Planned reversals recognise those stops. Directional clearance caches include
  the catalog, preventing a result from another layout from being reused.
- Additional passenger-train save validation checks destinations and geometry
  against the supplied station identities.
- Local demand instances own a sorted station-ID list. Initial distribution,
  arrivals, capacity limits, boarding, recovery and batch persistence use it.
  Empty/single-station catalogs generate no impossible trips or RNG draws.
- Queue validation rejects foreign destinations/origins. Custom station queues
  do not require invented `waiting_at_*` legacy counters; existing tutorial
  aggregate counters remain checked for compatibility.
- Main-game callers pass the live catalog for operations and the saved catalog
  for validation/load, rather than borrowing whichever world is currently open.

Tutorial defaults remain available to existing helpers/tests. No static station
registry is mutated. Save schema remains **39**: station IDs are already in the
world catalog and queue dictionaries, so this change adds no redundant save field.
Old tutorial passengers, manifests, timing and paid receipts retain their IDs.

## Remaining gate before seeded sandbox starts

Journey/interchange graph validation, amenities, satisfaction, demand response,
station aggregate adapters, arrival validation and reports are now adapted
([station state](CATALOG_STATION_STATE.md)). Broader passenger-class policy still
has tutorial assumptions. The current Express A↔C policy is retained; unfamiliar station IDs
exercise Local demand in this increment. Freight facilities still use the fixed
first-chain profile. Adapt these remaining consumers and facility geometry before
offering generated layouts or player-built stations as a playable option.

Tests use four unfamiliar stations, moved platforms, a planned reversal, catalog
cache changes, unknown-stop diagnostics, passenger boarding and recovery, JSON
persistence, foreign-ID rejection and isolation from tutorial instances. Existing
network safety, industry chains and determinism remain regression requirements.
See [world catalog](WORLD_CATALOG.md) and [seeded cities plan](SEEDED_CITIES_PLAN.md).
