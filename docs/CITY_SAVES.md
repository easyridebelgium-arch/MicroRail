# Generated city saves — Phase 2C

Generated companies now use the same four manual save slots, slot-specific backups,
temporary writes and save chooser as the tutorial. Start a generated game through
[New Game](NEW_GAME.md) (or the development preview), then use **Save**, choose a slot and
confirm. **Load** restores it from either the preview or the ordinary main scene.
Starting a new tutorial does not replace an existing save until explicitly saved.

Root save version **40** added an explicit `game_mode` (`tutorial` or `cities`).
Version 39 and older supported tutorial saves migrate to `tutorial`; their geometry,
actors, queues and finances are preserved. The world catalog remains schema 1.
Root version **41** adds saved [city-owned population/supply](CITY_DEMAND.md), with
empty historical measurements on v40 migration and no changes to accepted trips.
Generated saves retain the actual catalog, seed and generator/content versions.
Loading never calls the generator or reseeds the live random stream.

## Restored state

- An empty network/company, unassigned purchased locomotives, passenger-only,
  freight-only or mixed operation. No original passenger/freight actor is invented.
- City/station IDs, exclusive city catchments and purchased five-tile platforms.
- Retained train paths, exact positions, direction/recovery, dwell, instructions,
  consist length, cargo and passenger manifests. Missing track ahead may stop a
  service; it does not reset it or replace its retained geometry.
- Station queues and their arrival/journey clocks, amenities, measurements, industry
  installation and inventories, money, loans/interest, simulation tick, commands,
  event history and RNG continuation, using the existing save models.
- Reservations, occupancy and switch locks are recomputed from restored actors.
  Traffic wait measurements still reset on load as documented by the inspector.

## Validation and atomicity

The city profile explicitly opts into optional-service validation. The tutorial's
strict default validators still require its original assigned pair. Unsupported
modes, orphan city links, invalid generated geometry, overlapping buildings and
missing purchased platform tiles are rejected. Industry loading rails may be absent
before construction; installed processing stops must retain their track.

Every actor and its full body are staged before live state is replaced. Overlapping
saved train bodies are rejected. An absent actor must have an inert runtime envelope,
preventing phantom positions/cargo. Failed loads retain the current company, funds,
fleet and RNG. Loading clears stale station inspection/tool selections and rebinds
the station construction models, so purchasing another station remains usable.

The focused `tests/test_city_saves.gd` suite passes 60 checks covering these cases through real slot
writes/loads, including JSON normalization, future fixed-tick station commands, queued passenger groups, onboard journey
manifests, loans/amenities, generated processors, a long freight consist, rejected
save atomicity, retained broken routes, overwritten-slot backups and tutorial/city
cross-loading. A continuation check compares loaded versus uninterrupted train state,
RNG and balance. The full regression run passed 100 of 101 suites; its Fleet
departure/destination issue was corrected and the affected multi-service suite
then passed all 58 checks, completing coverage of all 101 suites. Final scene,
journey and slot checks also passed. Headless functional testing does not replace
visual review.

The normal seeded New Game chooser and representative startup affordability checks
and city-owned population/trip supply are implemented. Bounded service-driven
growth/decline is next. Artwork remains separate from these mechanics.
