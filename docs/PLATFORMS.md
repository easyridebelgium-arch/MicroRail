# Platform lengths (Phase 1B foundation)

A stop's **platform** is now a measured quantity instead of a vague "clearance"
rule. `scripts/core/platforms.gd` measures the continuous run of straight,
horizontal, signal-free track through the stop tile. Trains stop centred on the
stop tile, so a train needs the same number of whole tiles on each side.

| Platform tiles each side of the stop | Longest train | Fits |
| --- | --- | --- |
| 0 (bare station tile) | 31 px | locomotive only |
| 1 | 95 px | locomotive + 2 vehicles |
| 2 | 159 px | locomotive + 4 vehicles (the maximum) |

The station panel now shows a line such as
`Platform: 5 tiles (160 px), fits locomotive + 4 vehicles`. It is measured from the
live track, so laying straight track behind a stop lengthens the platform at once;
a signal or switch ends it. Nothing new needs buying or saving: no save fields were
added, and the earlier save format (v23) is unchanged.

## Relationship to the existing check

`Consists.stop_clearance` still decides whether a consist may start, edit or
continue; its behaviour is unchanged. `tests/test_platforms.gd` checks that the
formal rule agrees with it for every consist size and every combination of
extension tiles behind the start and beyond the end of a route (172 checks).
`tests/test_platform_ui.gd` checks the panel text.

## Not yet implemented

- Stable platform IDs, several platforms per station and basic platform assignment.
- Platform-aware arrival/departure reservations, so two trains can use separate
  platforms of one station.
- Vertical or diagonal platforms (the existing rule only accepts horizontal track).
- Routing consist bodies through planned reversals and repeated paths, which is
  still the other open item of Phase 1B.
