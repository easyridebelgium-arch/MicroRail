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

## Choosing a platform for a service

In **Routes**, select a stop in the stop list and pick **Platform 1/2/3** beside the
Up/Down buttons; the list shows `— platform N` for any choice other than 1. Apply
rebuilds the route to that platform's stop tile, so the train really drives onto the
siding and loads/unloads there. Two services can therefore use different platforms
of one station, and the existing reservations and signals keep them apart.

Rules:

- The choice is stored per stop in the service as `platforms: {stop: number}`. It is
  optional; services without it keep using platform 1. No save-version change was
  needed. Saved runtime routes must end on the chosen platform's stop tile, or the
  save is rejected.
- The siding must already be built and connected (normally with a switch), exactly
  like any other track. If it is missing or not connected, Apply refuses and
  changes nothing.
- A consist's platform fit is checked at the chosen platform's stop tile, using the
  siding's own straight length.
- The first stop's platform cannot change while that service stands on its current
  platform, because the train starts every trip there. Choose platforms for later
  stops, or move the first stop to another station.
- Platform choices for stops removed from a route are dropped automatically.

Platform choice is fixed per service. The automatic rule that picks a free platform
at arrival time (`Platforms.assign`, below) is not wired to movement yet.

`Platforms.assign` is the basic assignment rule: the lowest-numbered platform that
fits the whole train and is not busy. It is a pure function with tests; services use
sidings only through the fixed per-stop choice above.

## Relationship to the existing check

`Consists.stop_clearance` still decides whether a consist may start, edit or
continue; its behaviour is unchanged. `tests/test_platforms.gd` checks that the
formal rule agrees with it for every consist size and every combination of
extension tiles behind the start and beyond the end of a route (172 checks).
`tests/test_platform_ui.gd` checks the panel text.

## Not yet implemented

- Choosing a free platform at arrival time (`Platforms.assign`) instead of a fixed
  choice, with arrival/departure reservations that wait for a platform to clear.
- Platform choice for the first stop, and for freight terminals.
- A build tool or overlay for sidings; today they are ordinary track.
- Vertical or diagonal platforms (the existing rule only accepts horizontal track).
- Routing consist bodies through planned reversals and repeated paths, which is
  still the other open item of Phase 1B.
