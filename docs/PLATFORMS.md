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

## Numbered platforms and sidings

A station can now have up to three platforms, found automatically from the track
(no new tool, no save fields):

| Number | ID | Where |
| --- | --- | --- |
| 1 | `<station>/1` | the stop tile's own track |
| 2 | `<station>/2` | a straight signal-free siding on the row **below** the stop tile |
| 3 | `<station>/3` | the same on the row **above** it |

Numbers come from the row offset, so they are stable: building platform 3 never
renumbers platform 2, and removing platform 2 leaves platform 3 unchanged. A siding
must contain the tile directly beside the stop tile (same column). The station
panel lists every platform with its length, the longest train it fits and the train
currently occupying it.

`Platforms.assign` is the basic assignment rule: the lowest-numbered platform that
fits the whole train and is not busy. It is a pure function with tests; **trains do
not use sidings yet** because routing still targets the station's own stop tile.

## Relationship to the existing check

`Consists.stop_clearance` still decides whether a consist may start, edit or
continue; its behaviour is unchanged. `tests/test_platforms.gd` checks that the
formal rule agrees with it for every consist size and every combination of
extension tiles behind the start and beyond the end of a route (172 checks).
`tests/test_platform_ui.gd` checks the panel text.

## Not yet implemented

- Routing trains to a siding: connect sidings with switches, let arrival choose
  `Platforms.assign`, and make arrival/departure reservations platform-aware so two
  trains can use separate platforms of one station at the same time.
- Persisting a player's platform preference per service.
- Vertical or diagonal platforms (the existing rule only accepts horizontal track).
- Routing consist bodies through planned reversals and repeated paths, which is
  still the other open item of Phase 1B.
