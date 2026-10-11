# Track reservations (Phase 1)

Passenger and freight services can now share tiles. Freight planning uses the
shortest port-valid path; passenger tiles and platforms are no longer excluded.

## Operating rules

- `scripts/core/track_reservations.gd` owns `{cell: permanent fleet train ID}`.
  Every fixed simulation tick first protects the body of **every** assigned
  train, including dwelling, loading and withdrawn trains. Then it grants track
  ahead in ascending ID order, independently of the order trains are moved.
- Moving trains request up to three tile lengths ahead. Requests stop at a
  conflict. Movement samples the path at at most one-pixel intervals and permits
  only positions whose whole sprite bounding box is owned. Curves and diagonals
  use a conservative rotated bounding box; this can leave extra clearance.
- A switch and its used stem/exit neighbours are granted together. Its state
  follows that owner's actual route, including trailing moves. A switch may
  occur more than once along a service path; each occurrence is considered at
  its own path distance. A crossing is also exclusive at tile level.
- Occupancy and ownership are rebuilt each tick, releasing passed tiles. While
  paused, unused lookahead is released; body tiles and the switch under a train
  remain protected. Build, demolition, switch changes and Undo/Redo recheck
  protection when applied. Pausing does not make an occupied tile editable.
- Blocked trains retain passengers/cargo and keep paying active running costs.
  Their status names the blocker and location. `TRAIN_WAITING` events use the
  permanent train ID and are recorded on entry into waiting or a changed reason,
  rather than every tick. They appear in the existing event log.
- The **Reservations** toolbar toggle shows real ownership with hatching and
  `#ID` labels. It uses shape and text as well as colour.

## Saves and limits

The schema remains **v18**. Reservations are transient and are reconstructed from
restored fleet IDs, paths, positions and direction before any train moves.

Opposing trains on a single track can wait indefinitely without player action.
[Deadlock detection and safe emergency recall](DEADLOCKS.md) now identify sustained
mutual waits and let the player clear them. Signals and automatic rerouting remain
subsequent work. A passing loop helps only when the
planned services actually use separate paths; this version does not automatically
reroute a held train into an alternate loop. Lower IDs win simultaneous requests;
priority classes and fairness policies come later. There is still one running
train per service. Longer consists will need updated body occupancy.

## Verification

Run from the project folder:

```sh
godot --headless --path . --script res://tests/test_reservations.gd
godot --headless --path . --script res://tests/test_reservation_integration.gd
```

These checks cover switch contention, body occupancy, release and resumption,
parked trains, protected construction and Undo, shortest shared freight routes,
save/load reconstruction, and matching real train positions, finances and events
at 30, 60 and 120 FPS. Existing geometry, route, fleet, save, UI and foundation
checks also remain applicable.

Manual play check:

1. Enable Reservations and watch `#ID` labels move with the trains.
2. Connect passenger and freight paths through a shared switch or crossing.
3. Watch one train wait, see its reason in the inspector/event log, and verify
   it moves again after the other clears the shared track.
4. Pause with a train at a switch; attempt to change or remove it. It stays locked.
5. Save and reload during movement or waiting. Ownership returns before movement.
6. Repeat using colour-blind and high-contrast palettes at 200% interface scale.
