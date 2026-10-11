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
