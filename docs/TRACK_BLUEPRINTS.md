# Reusable track blueprints

1. Open **Overlays** and enable **Draft construction**. This pauses the game.
2. Under **Track blueprints**, click **Pick corner 1**, then click a map cell.
   Repeat with **Pick corner 2** to select an inclusive rectangle. Empty corner
   cells are allowed; the white outline shows the selected area.
3. Enter a unique name and click **Save selected rectangle**. This copies **built**
   tracks, switches and straight-track automatic/manual signals. Apply any ghost
   construction first if you want it included. Platforms and facility grounds are
   omitted; trains, waypoints, switch positions and operational reservations are
   not part of a design.
4. Search saved layouts by name and choose one from the list. Click **Place
   selected blueprint**, then click its top-left map cell. Escape cancels picking.
5. Inspect the ghost geometry, aggregate price/refund, service impact and any
   reservation warning. Other strokes or blueprint copies can join the same draft.
   **Apply plan** performs validation and applies everything together; **Discard
   plan** removes the preview. Undo/Redo treats an applied draft as one action.

A footprint outside the map, protected track or incompatible existing track/signal
refuses placement without changing the draft. Matching existing tracks are reused
at no extra cost; a compatible switch can extend an existing straight. Occupied or
reserved changes may be previewed, but application waits until those trains clear.
Blueprints keep their captured orientation; rotation/mirroring and tags are future
improvements. The tool shows current reservations and route impacts, not a traffic
forecast or land-rights check.

## Local browser and sharing

The library is independent of game saves, with up to 50 named designs. It lives in
`user://track_blueprints.json` (Godot: **Project → Open User Data Folder**). Saving
uses a temporary file and retains the previous library as `.backup`. A malformed
library is reported and preserved; repair it or keep a copy and remove it before
restarting the game to create a fresh library.

**Export selected** writes one design in a versioned JSON library. **Import JSON**
validates every design and merges unique names into the local library. Duplicate
names, malformed data or the design limit refuse the entire import. Export cannot
replace the active library or its backup. Share exported JSON files directly; no
account, server or Steam Workshop is required. Designs carry relative coordinates,
track topology and signal modes, but no saved train or company state. Applied
tracks/signals continue to use the existing game-save version.

Checks: `test_track_blueprints.gd` covers format validation, relative geometry,
compatibility, bounded capture and backup persistence. `test_blueprint_integration.gd`
covers actual UI selection/search, draft pricing, apply/Undo/Redo, game reload and
atomic import/export.

## Guided passing-loop preview

Open **Overlays → Draft construction → Preview passing loop**, then click the
first switch tile. Choose a total length of **9–31 tiles including switches**,
and **Horizontal — loop below/above** or **Vertical — loop right/left**. Click
the leftmost switch for a horizontal main line, or the topmost switch for a
vertical one. The default is nine tiles wide and four high, loop below. Every
layout has two switches and four automatic block signals.
It does not use or overwrite your saved blueprint library. Escape or short right
click cancels picking; Discard plan removes a staged preview.

Nothing is purchased until **Apply plan**. Review ghost rails, price, reservations
and affected services first. Matching rails are reused. On an existing matching
nine-tile main line, the template adds 13 rails and two £100 switch upgrades
(£330); on empty ground it costs £420. Signals currently have no purchase cost.
Normal bounds, protected-platform/facility, terrain and reservation validation
apply. Failed placement preserves the existing draft. Application is atomic and
one Undo/Redo covers the whole plan.

Connect the outer ends of both switches to your line. The instructions below the
blueprint controls give the exact loop waypoint coordinates for the chosen length
and orientation (default: four tiles right and three down from the clicked switch). In Routes, assign that waypoint to the service
using the loop; leave the other service on the main branch. A tested example clicks
(8,8), with stations A (4,8) and B (20,8): start one service A–B, another B–A,
and give B–A waypoint (12,11). See [multiple services](MULTIPLE_SERVICES.md).

The branch is three tiles away from the main line. Above/left footprints extend
three tiles above/left of the clicked switch, and cannot clip the map boundary.
Options apply to the next placement, not an existing draft; Discard plan before
replacing a preview with a different length/orientation. Session tool settings are
not saved as company rules. On empty ground a length L costs £(20×L + 240);
existing compatible mainline rails reduce that price. Longer trains need more
space: check that the entire train fits between holding points and choose a
longer siding as needed. A numeric length alone is not a traffic safety guarantee. Keep station approaches
outside the footprint. The template does not choose branches for trains or
promise that arbitrary services, origins or signal arrangements cannot deadlock.
There is no automatic route editing, train purchase, waypoint creation or save
schema change. After applying, capture the layout to your library if desired.

`test_passing_loop_template.gd` exercises UI placement, geometry, pricing,
refusals, atomic application, Undo/Redo, waypoint routing, physical shared-track
running and save/load. Existing construction validation tests cover live
reservation protection and stale drafts.

`test_passing_loop_options.gd` checks minimum/maximum and even/odd lengths in
all four orientations, both route directions, signal boundaries, price, above/left
map edges, ordinary UI options, atomic apply/Undo and real save/load.

## Measured train fit

After placing a guided loop preview, **Overlays** shows **Last loop preview —
measured train fit** below its controls. It lists both inner holding spans in
map tiles, followed by every owned train's permanent ID, name, actual consist length
and **main fits / loop fits** or **TOO SHORT**. Stored trains are labelled too.
An empty fleet is explained rather than given an unconditional success message.

The span is the route distance inside the two signal boundaries. Fit uses the
runtime red-signal stopping calculation and the whole train's conservative body
footprint at **both ends** of each branch, including curved loop geometry. Every
occupied tile must lie inside the branch, clear of the two signals and switches;
a 2 px planning allowance is included. Displayed lengths are rounded to one
decimal tile; the calculation uses full precision. A raw span is not used as a substitute for
this body test. Current single locomotives and four-coach consists fit the default
loop; the measurement also supports longer bodies as rolling stock expands.

If a branch is too short, choose a longer length or shorten the consist, discard
the old draft and preview again. These are advisory local clearance results:
construction remains subject to ordinary cost/protection/reservation checks, and
this panel does not assign routes, alter trains, predict traffic or prove that
surrounding signal blocks are isolated. An incorrectly routed train or shared
station approach can still deadlock even when every body fits this local siding.

Measurements refresh when the fleet changes. Later edits to template track or
signals replace the result with **Fit unavailable**, requiring a fresh preview.
Changing the length/orientation controls affects only the next placement. Applying,
discarding or loading clears the preview-specific measurement; no new save state
or gameplay rules are introduced. Measurements are cached between relevant edits
and never move the simulation or spend money.

`test_passing_loop_fit.gd` covers four orientations, real consist lengths, both
runtime stopping directions, short/long synthetic clearance cases, graph/fleet
immutability, row ordering, cache refresh, stale draft detection and cleanup on
apply/discard/load. Existing running tests continue to verify shared-track safety.

## Loop waypoint shortcut

1. Place a guided loop preview, review cost and fit, then **Apply plan**.
2. In Overlays, click **Use loop waypoint in Routes**. The helper shows which
   built loop cell it will use. It opens Routes paused with that cell's X/Y filled
   in and a persistent instruction beside the waypoint controls.
3. Choose the intended **service and leg**, then click **Add waypoint**. Existing
   waypoints remain in order; this appends the loop cell. Use Up/Down if needed.
4. Review the full route and click **Apply**. Closing/Cancel discards the route
   draft; the already-built track is a separate construction transaction.

Opening the shortcut makes no purchases, inserts no waypoint and changes no
service. Choose the train/service that should use the loop; the other service
can stay on the main branch. Shuttle return trips retrace that leg's selected
path. Loop mode has separate legs, including the closing leg; choose deliberately.
A linked service follows its source: select that source or deliberately Unlink
before editing independently. Existing duplicate/16-point limits and safe route
application rules remain in force. A running train cannot be teleported or have
its route changed through this shortcut; finish the trip or physically reverse
back to its first stop as the normal Routes message explains.

The shortcut requires built, unmodified template geometry/signals, a service and
no pending construction. Apply or discard other construction first. It never
applies construction on your behalf or overwrites an already-open dialog draft.
Undo disables a shortcut whose track disappears; Redo can restore it. An identical
already-built template can be previewed at no cost to recover the shortcut. The
last applied template context is temporary and clears on load; an applied service
waypoint is saved through the ordinary route schema. Editing the length/orientation
controls does not move the cell associated with an earlier preview.

`test_loop_waypoint_handoff.gd` covers pre-build refusal, Apply/Undo/Redo,
explicit service selection, draft-only Add, duplicate refusal, protection of an
open draft, Cancel, normal Apply, running-train restrictions, pending construction,
ordinary Routes hint reset and saved waypoint persistence without saved handoff state.
