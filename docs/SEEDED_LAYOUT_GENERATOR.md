# Seeded flat layouts — Phase 2C foundation

`scripts/core/world_generator.gd` generates candidate starting geometry for an
80×50 flat map. It now feeds the [New Game menu](NEW_GAME.md). The development preview now connects it to the main scene, and
[version 40 saves](CITY_SAVES.md) restore generated companies without regeneration.
The ordinary seeded New Game chooser is implemented; tutorial geometry remains supported.

## Generation contract

`WorldGenerator.generate(seed_text, city_count = 4)` accepts a canonical decimal
seed from `0` through `9223372036854775807` and 3–8 cities. Unsupported values
return `ok: false` with a message and no partial world or random state.
Successful results contain:

- `world`: the actual versioned catalog geometry, not instructions to regenerate it.
- `rng_state`: the continuation of the one `SimRng` used during generation.
- `planning`: proposed station positions and the endpoints of a clear freight
  corridor. These are construction witnesses, not purchased facilities or rail.

The profile is `seeded_flat`, generator version 1 and content version 1. Map size,
city count, versions and seed are represented in the catalog. Density is the saved
settlement count; this profile has exactly four industry sites. Keep the actual
catalog and RNG continuation when integrating startup. Restore them directly on
load; never regenerate a saved map or reseed its running simulation.

Reproducibility assumes the same Godot RNG implementation. The future share-code
format should identify the compatible engine/build alongside the profile,
versions, seed and city count. Generator/content versions must change when their
placement rules or definitions change; seed alone is not a cross-release promise.

## Placement and validation

Generation shuffles eight separated slots and jitters each selected city by at
most two tiles. It uses a finite number of RNG calls and no retry-until-success
placement, frame time or global random calls. Each city has a provisional 5×3
building footprint and a separate nine-tile-wide station approach with space for
the building, platform and an adjacent passing-loop row. These clearances guide
the next construction slice; they do not assign population or create passengers.

Forest → sawmill → factory → terminal sites lie along a translated horizontal
freight corridor, 14 tiles apart. Forest and terminal are available; processors
remain unbuilt. Clearance includes the buildings of inactive processor sites and
extra space at both ends and beside the corridor. No track, passenger stations,
trains, services or purchases are created by the generator.

`valid_initial(world)` checks the catalog and supported profile, all city and
station clearances, industry ordering/spacing, bounds and separation from the
freight strip. A bounded four-neighbor flood fill checks that every proposed
station can be reached through flat land from the freight corridor. This proves
land access, not an operating track route, signal safety or an affordable scenario.
Those checks remain with the authoritative rail graph and the future startup rules.
This validator applies to initial geometry, not a later developed city world.

## Evidence and remaining work

All 97 regression suites pass. `tests/test_world_generator.gd` passes 31 checks
covering 192 seed/density combinations, exact repeat
results, seed variation, maximum seed, JSON geometry/RNG continuation, physical
clearances and rejection of malformed layouts. The test also verifies that the
tutorial remains valid and that a generated candidate cannot masquerade as a
playable tutorial save.

City-linked station purchase/placement, empty startup, generated save/load and the
normal [seed chooser](NEW_GAME.md) are now implemented. Real first-service construction
checks cover representative seeds/densities with the starting budget. City-owned
passenger supply and bounded service-based growth/decline are next; deeper scenario
balance remains separate from the generator's geometry checks.
