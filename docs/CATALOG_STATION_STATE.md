# Catalog-owned journey and station state

This Phase 2C increment removes A/B/C assumptions from the Local journey graph,
journey timing/history, amenities, waiting satisfaction and demand response.
Arrival-target validation and occupancy/Accounts reporting also accept current
station identities. The playable map remains the tutorial until seeded generation, city-linked
station construction and empty-network startup are ready.

## Implemented behavior

- Journey graphs initialise every catalog station, choose deterministic connections
  and decline unknown/withdrawn connections. Boarding can include a final destination
  reached through a physical interchange at another catalog station.
- Original origin/start ticks survive boarding, transfers, recovery and completion.
  Journey histories validate origins/destinations and manifests against supplied IDs;
  foreign identities and inconsistent totals are rejected.
- Each amenity, satisfaction and response instance owns a sorted station-ID list.
  Restoring a different valid catalog removes phantom tutorial entries.
- Custom stations retain the existing purchase prices, prerequisites, capacity and
  demand bonuses. Waiting satisfaction keeps its bounded history and comfort rules.
  Demand response still changes gradually within 50–125%, with actual service and
  boarding evidence required for growth above 100%.
- Company satisfaction, queue totals, amenity value and occupancy reports enumerate
  current stations. Main waiting lookups read the authoritative queue dictionary,
  while A/B/C aggregate aliases remain for tutorial save compatibility.
- Arrival targets validate directional legs against the saved station catalog.
  Timing budgets, grace, payment and reservation rules are unchanged.

Constructors and save validators accept station IDs explicitly; older callers keep
A/B/C defaults. Main load/validation uses the saved catalog. State dictionary shapes
are unchanged, so the save schema remains **39** and no new migration is needed.
The current Express A↔C policy remains a separate tutorial rule: this increment
exercises Local journeys for unfamiliar IDs.

Tests cover a four-station transfer, preserved clocks and completion reports,
JSON persistence, invalid identities, amenity benefits/prerequisites/isolation,
company satisfaction, bounded demand growth/decline, custom arrival legs and
occupancy reporting. Existing safety and frame-rate determinism remain required.

Catalog-owned industry positions and distance-based passenger classes are now
adapted ([details](CATALOG_FACILITIES_AND_CLASSES.md)). Next: feasible seeded
city/industry layouts, city-linked station building and empty-network startup.
See [seeded cities plan](SEEDED_CITIES_PLAN.md).
