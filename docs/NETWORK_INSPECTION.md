# Network inspection and construction feedback

Open **Overlays** in the toolbar. This panel is scrollable, works at 100–200%
interface scale, and leaves the game running. Close it with the same button.
Opening a station inspector closes the panel so the two do not cover each other.

- **Service paths** shows each assigned train's retained route, including missing
  track. Filter to one service to inspect shared tracks and waypoint detours.
  Dashed paths use different patterns, squares mark route origins, circles mark
  each train's next destination, and labels show permanent train IDs. Loop routes
  include their closing leg; these are runtime paths, not a new shortest-path
  calculation. Trains that have not yet acquired a route have no path to draw.
- **Signal blocks** shows dotted tile outlines with block IDs. Hover a track tile
  to read its block's authority holders. Authority includes reserved entry, so it
  does not imply that a train physically occupies every tile in that block.
  Signals create boundaries; useful dispatch authority requires signals.
- **Reservations** remains a separate toolbar toggle. Hatched tiles show the
  actual owner ID. The inspection panel reports whether the hovered tile is
  physically occupied or reserved ahead.

Start a build or removal drag on the map. The header gives an affected-service
count and warns about reserved tiles. With Overlays open, the panel names each
service and explains whether the edit breaks its current leg, affects a later
leg, restores its current leg, or merely edits track on a still-clear route.
These checks use each train's current position and next destination: deleting
track behind an outward train does not claim that it must stop immediately.

Reserved track cannot be edited. Construction rechecks ownership when the command
runs; a build touching reserved track is rejected without charge. Removal skips
protected tiles and can still remove the other selected tiles. The panel also
reports protected track encountered by a removal drag. The prediction is live
feedback, not a reservation of the planned work: traffic can change before release.

To test:

1. Build A–B, let the passenger train depart, then pause halfway along the line.
2. Turn on Service paths and select the passenger service.
3. Right-drag a tile behind the train: the report should say the current leg is
   clear and a later leg is incomplete. Cancel without releasing to keep it.
4. Right-drag an unreserved tile ahead: the report should say the current leg
   would break. Cancel, or release to test stopping in place.
5. Draw the missing tile back in: the report should say it restores the current
   leg. Release and resume to let the train continue.
6. Enable Reservations and drag over a hatched tile: it must be protected.
7. Add another passenger service using [the passing-loop guide](MULTIPLE_SERVICES.md)
   and check that both services appear in the filter and shared-track reports.

This step does not add traffic forecasts, alternate-route recommendations, speed
limits, congestion measurements, work zones or batch confirmations. Those require
additional operations data and remain on the roadmap. Overlay preferences are
local to the current session; there is no save-format change.

Automated checks:

```sh
godot --headless --path . --script res://tests/test_construction_impact.gd
godot --headless --path . --script res://tests/test_inspection_integration.gd
```
