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
