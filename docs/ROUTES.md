# Named routes and ordered stops

Use GitHub Desktop to select `codex/fix-main-merge`, Fetch origin, then
Pull origin. Close Godot before pulling and reopen the existing project afterward.
The merged update uses save version 22. Version 14 and both version 15 development
formats migrate on loading; earlier formats are not supported. See [Fleet management](FLEET.md) for purchasing and assigning trains.

## Try a three-stop passenger service

1. Pause the game and connect Station A (4,8) to Station B (20,8).
2. Extend east from Station B to the new Station C (36,8). Each platform remains
   horizontal. Existing construction costs, previews and Undo still apply.
3. Click **Routes** on the toolbar. Opening the window pauses the game.
4. Select **Passenger service**, enter a name, select **Station C**, then **Add**.
5. Select a stop and use **Up** or **Down** to change its order. **Remove** removes
   it from the service, not from the map. Keep at least two different stops.
6. Choose **Shuttle** (return through stops in reverse) or **Loop** (last stop
   directly to first), then click **Apply**, close the window and resume.
7. With A, B, C selected, Shuttle visits A → B → C → B → A; Loop visits
   A → B → C → A. With stops ordered A, C, B, Loop visits A → C → B → A.
   It stops to exchange passengers at every listed station. An unlisted station can be passed through.
8. Save using the toolbar. Reload to restore the names, stop order, station queues,
   train position, dwell and current direction.

You can pan east using the existing camera controls or click Station C on the map.
Station C appears in the minimap and supports the existing station inspector.

For your bypass example, keep the waypoint on **A → C**, order the stops **A, C, B**,
and select **Loop**. Use the new **B → A** waypoint leg if the shortest closing path
needs directing. A waypoint does not create a station stop. Existing v20 routes
load as Shuttle with their positions and directives preserved.

## Editing behaviour

- Each service has one assigned train. Fleet can [start additional passenger
  services](MULTIPLE_SERVICES.md) on clear platforms, or replace a returned train.
  Multiple simultaneous trains on one service remain a later step.
- Passenger routes use two or three unique stations. Choose Shuttle or Loop per passenger route. The preview shows the full stop sequence.
- Renaming a route does not interrupt its train.
- Route mode, stops and passenger waypoints can change only with an empty train physically
  at the first stop of the proposed route. The complete new path must be valid.
  Edits never teleport trains or unload passengers mid-track. Freight waypoint
  edits require its train at the forest.
- Initial planning requires a complete route. Once underway, only the retained
  track between the train and its next destination is checked. A gap behind does
  not interrupt delivery; after turning it blocks the return leg and warns.
  A gap ahead stops the train in place until repaired.
- [Waypoints](WAYPOINTS.md) choose pass-through cells on each leg without
  adding station stops. Shuttle returns along the outward geometry in reverse.
  Loop has an independently routed last-to-first leg with its own waypoints.
  A loop defines stop order; build tracks or set waypoints to choose its actual
  circuit. A shortest path can pass an unlisted/intermediate station without stopping.
- Withdrawal completes the round trip or current lap and parks at the configured first stop.
- Closing without Apply discards draft edits; Apply updates the game, and the Save
  button writes it to disk. The game remains paused when the Routes window closes.
- Freight can be renamed and given waypoints, but Forest → Terminal retains its
  fixed load/unload roles.
- Passengers currently travel to the next listed stop. Individual destinations and
  transfers are not included yet.

## Automated checks

With Godot 4 on PATH, from the project directory:

```sh
godot --headless --path . --script res://tests/test_mouse_tracks.gd
godot --headless --path . --script res://tests/test_service_routes.gd
godot --headless --path . --script res://tests/test_loop_routes.gd
```

These integration tests write saves. On Linux set separate `XDG_CONFIG_HOME`,
`XDG_DATA_HOME` and `XDG_CACHE_HOME` directories to avoid replacing a playing save.
The cloud checks used Godot 4.6.3. Windows mouse interaction requires a local check.
