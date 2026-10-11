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

## Still to do (in order)

1. Builder: an explicit rule for turning an existing straight into a switch, and
   for crossings (today crossing an existing line is rejected).
2. Drawing: `drawing_data` returns nothing for switches and crossings.
3. `switch_states` in `main.gd`: `{cell: 0 or 1}`, saved as a `switches` block
   (save version 17, migration from 16, validation), included in Undo/Redo, changed
   through the command queue, recorded as a `SWITCH_THROWN` event.
4. Trains: set facing switches along their route; refuse to move a switch under a
   train (a reservation check later).
5. Interface: click a switch to toggle it, with a visible state.
6. `main.gd` currently accepts only two-port tiles when loading a save
   (`TrackGeometry.connections(value).size() == 2`), so switches cannot be loaded
   until step 3.
