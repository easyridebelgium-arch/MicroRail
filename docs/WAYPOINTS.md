# Ordered pass-through waypoints

Waypoints choose a particular branch or passing loop without another station.
They guide planning; trains still obey signals, reservations and track connectivity.
There is no loading, unloading, station dwell or reversal at a waypoint.

## Add a waypoint

1. Build the connected route and any desired loop. Passenger route edits require
   an empty train at its first station; freight edits require its train at the
   forest. Withdraw the service and let it return there if needed.
2. Select **Waypoint** in the toolbar and click an existing track cell outside a
   station/industry platform. **Routes** opens and pauses the simulation, with
   the selected X/Y coordinates filled in.
3. Choose **Passenger service** or **Freight service**. Select a leg,
   such as **A → B**, **B → C**, or **FOREST → TERMINAL**. Passenger Loop mode also exposes
   the closing leg (for example **B → A** for stops A, C, B).
4. Click **Add waypoint**. Repeat through X/Y coordinates for additional cells,
   using **Up/Down** to set their required order and **Remove** to delete a draft
   directive. You can also open Routes directly and enter coordinates manually.
5. Click **Apply**. The complete route must pass through every selected cell in
   order, using valid switch/crossing ports. Invalid paths or unsafe mid-trip
   edits leave live routes, train positions and loads unchanged.
6. Close the window and resume. Diamond markers labelled **P1/P2…** or **F1/F2…**
   show passenger/freight waypoint order on the map (numbering restarts per leg).
   Save normally to keep the changes. Closing without Apply discards the draft.

A selected cell is only added after **Add waypoint** and **Apply**. Waypoints are
free route directives in this prototype, not separate buildings. Editing/removing
one does not demolish track. Changing the stop list removes draft directives for
legs that no longer exist; closing without Apply preserves the live configuration.

## Behavior and limits

Up to 16 distinct waypoint cells are allowed per leg. Passenger stations
and industry platforms cannot be waypoints. The shortest port-valid route that
satisfies the ordered directives is chosen. The search carries the entry port
through the whole leg, so a waypoint on a switch cannot allow a forbidden
branch-to-branch move or a turn between crossing lines. The destination is reached
only after all directives have been satisfied.

Shuttles return along the selected geometry in reverse. Passenger Loop routes
follow the ordered stops and a separate last-to-first leg with its own directives;
A, C, B in Loop mode visits A → C → B → A without stopping at C again.
One-way waypoint arrows, independent shuttle return itineraries, automatic
passing-loop selection and timed priority dispatch remain future work. A chosen passing loop helps only when the
services' actual paths avoid the contested section and its signals have appropriate
boundaries. A waypoint never overrides another train's occupied/reserved track.

Broken-track checks use the current route occurrence, heading and next destination.
A gap behind a train permits delivery; after turning, it waits if the return path
crosses that gap. Route edits never replace geometry under a moving train.

Saves **v22** persist per-leg directives and retain train route snapshots/positions.
V19 saves receive empty directives; v20 saves retain their directives and default
to Shuttle mode. Validation checks that retained paths satisfy
their saved waypoint order; coordinates are normalized to integers on load.

```sh
godot --headless --path . --script res://tests/test_waypoint_router.gd
godot --headless --path . --script res://tests/test_waypoint_integration.gd
godot --headless --path . --script res://tests/test_directional_routes.gd
```

Checks cover forced bypasses, ordered traversal, invalid coordinates, switch and
crossing port safety, actual editor controls, physical no-dwell movement, atomic
mid-trip refusal, save/load, migration, direction-aware stops and 200% UI layout.
