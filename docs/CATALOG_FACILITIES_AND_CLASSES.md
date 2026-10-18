# Catalog-based facilities and Express policy

This Phase 2C adapter step removes fixed-coordinate assumptions from the freight
chain and fixed A/C identities from passenger-class rules. The playable profile
remains the tutorial until generated-map startup and station building are ready.

## Facilities

The world catalog exposes cached facility-cell lookups, including inactive
processor sites, and an industry-position dictionary. Main uses these positions
for freight endpoints, processor platforms, building footprints, waypoint
requirements, stop clearance, inspection and construction messages.

Freight receives its processor cells when configured. Route refresh retains them;
loading, production, delivery and reversal continue along the retained physical
path. Runtime/save validation uses the saved world's endpoints and loading sites,
rather than borrowing positions from the current map. On load, the freight home
position is also derived from the restored world.

Tutorial constants remain fallbacks for older pure helpers/tests. Recipes, prices,
stock conservation, whole-body reservations, signals and recovery are unchanged.
A test moves the whole chain five columns right and to row 30, then transports
logs through both processors and validates its goods and retained geometry.

## Passenger classes

Express eligibility uses **straight-line station distance of at least 32 tiles**.
It requires a direct next scheduled stop; waypoints do not count as station calls.
Nearby pairs are Local-only. Unknown stations and self journeys cannot qualify.

On the tutorial this produces exactly the old A↔C rule: A–C is 32 tiles, while
A–B and B–C are 16. One in four accepted distant arrivals becomes Express; this
counter does not add RNG draws. Only origins with an eligible distant destination
own counters. Each demand instance retains its own catalog, so generation,
boarding and batch validation agree. Queue caps retain their existing behavior.

Journey histories and save validation receive the same catalog. Local still pays
£5 and Express £10 once at final arrival; transfers/recovery do not earn extra
fares. Current queues, clocks and receipts remain intact. Growth-related hub roles
and more detailed passenger preferences are later refinements.

Save schema stays **39**: catalogs and per-origin counter dictionaries already
exist, and tutorial counter keys/values remain A/C-compatible. Current game-load
validation still rejects unsupported generated/relocated profiles. Core adapters
are not an invitation to edit live geometry under trains or bypass that guard.

## Next

Build a deterministic flat-grid layout generator with feasible city and industry
placement, then city-linked station construction and empty-network/service startup.
Only expose the seeded sandbox chooser when those parts work together. Preserve
A/B/C as the tutorial and migrate existing games without moving trains.
See [seeded cities plan](SEEDED_CITIES_PLAN.md).
