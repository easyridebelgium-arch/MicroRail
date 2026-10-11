# Junctions and switches (Phase 1, step 1)

Status: geometry and routing written; **not run in Godot yet** and not yet used by
building, drawing, trains, saves or the interface. Run
`godot --headless --path . --script res://tests/test_junctions.gd` first.

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

## Done in step 2 (also not yet run in Godot)

- **Drawing:** switches draw two rail paths and crossings two lines
  (`TrackGeometry.drawing_pairs`, `drawing_data` with an `"extra"` list). A
  switch shows its position with a filled marker on the open exit and a ring at
  the stem (shape as well as colour).
- **Switch positions follow routes:** `switch_states` is `{cell: 0 or 1}`;
  `_check_route` sets each switch to match the passenger and freight routes that
  use it (`RailRouter.switch_settings`). A switch no route uses keeps its
  position. Trains still follow their planned cell lists, so a position is
  currently display and bookkeeping, not a control.
- **Saves are version 18:** a `switches` block of `[x, y, state]`, validated as a
  whole list (switch tiles only, state 0 or 1, no duplicates) before loading;
  version 17 saves upgrade with an empty list; tiles with three or four ports are
  accepted when loading.

## Still to do (in order)

1. **Switch tool (written, not yet run).** The toolbar's Switch button turns a
   straight tile into a switch (£100); each further click cycles the eight
   variants (either end as the stem, the branch on any valid side) and the last
   click removes it (refund £100). It goes through the command queue, records a
   `SWITCH_CHANGED` event and supports paused Undo/Redo. Stem and through ports
   never change, so routes stay valid. Crossings and branching from the
   Connect/Draw tools come after.
2. A manual toggle once there
   is something for it to control (reservations and signals).
3. Trains set facing switches along their route and refuse to move a switch under
   a train (reservation check).
4. Interface: click a switch to toggle it, with a visible state.
