# Junctions and switches (Phase 1, step 1)

Status: integrated with building, drawing, trains and v22 saves. Geometry, switch
tool and save tests pass headlessly in Godot 4.6.3.
See [reservations](RESERVATIONS.md) for shared-track operation and switch locks.

## Tile kinds

| Kind | Code | Ports |
| --- | --- | --- |
| Simple | `bool`, `"NE"`/`"SE"`/`"SW"`/`"NW"`, `"rail_a_b"` | exactly two |
| Switch | `"junction_<stem>_<through>_<branch>"` | three, in that fixed order |
| Crossing | `"cross_<a>_<b>"`, 0 ≤ a < b ≤ 3 | four: a↔a+4 and b↔b+4 |

Ports are directions clockwise from north (0 = N … 7 = NW). A train that arrives
from the neighbour at `cell + d` enters through port `d`.

**Switch rules.** Stem↔through and stem↔branch must each be a valid rail shape
(at least 90° apart); the two exits are never connected to each other. State 0
sends a train entering at the stem to the through exit, state 1 to the branch. A
train entering from either exit always leaves through the stem (a trailing move)
whatever the state. **Crossing rules.** Both lines are always usable; a train
cannot change line.

## Code

- `TrackGeometry`: `connections`, `is_switch`, `is_crossing`, `exits_from`
  (every move planning may use), `exit_for` (the move a train takes at a given
  state), `state_for`, `switch_type`, `crossing_type`, and an exact
  `same_connections`.
- `RailRouter.find_path` returns `{"cells", "switches"}`; `find_route` returns just
  the cells. Planning ignores current switch positions and reports the settings a
  route needs, so toggling a switch never deletes a service route.

## Integrated controls and drawing

- **Drawing:** switches draw two rail paths and crossings two lines
  (`TrackGeometry.drawing_pairs`, `drawing_data` with an `"extra"` list). A
  switch shows its position with a filled marker on the open exit and a ring at
  the stem (shape as well as colour).
- **Switch positions follow reservations:** `switch_states` is `{cell: 0 or 1}`;
  the reservation owner sets its switch to the selected route exit before entering.
  The switch tile, stem and used exit are locked together. Unreserved switches
  retain their last position. Trains follow planned cell lists and may move only
  over granted tiles; the player cannot modify a reserved switch.
- **Switch state was added in v18 (current saves are v22):** a `switches` block of `[x, y, state]`, validated as a
  whole list (switch tiles only, state 0 or 1, no duplicates) before loading;
  version 17 saves upgrade with an empty list; tiles with three or four ports are
  accepted when loading.

## Switch tool

The toolbar's Switch button turns a straight tile into a switch (£100). Further
clicks cycle the eight variants (either end as the stem, any valid branch side)
and finally remove it (refund £100). Commands, events and paused Undo/Redo are
integrated. Reserved track cannot be changed.

## Next steps

[Deadlock detection and physical reversal](DEADLOCKS.md) and
[signals and dispatch controls](SIGNALS.md) are integrated. [Ordered waypoints](WAYPOINTS.md) use that layer to select passing-loop paths.
Route inspection and affected-service planning feedback come next.
Manual dispatch and switch-position controls must respect those locks. Crossing
placement and branching directly from Connect/Draw remain later building tools.
