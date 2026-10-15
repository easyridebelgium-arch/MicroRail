# City construction in the main scene — development preview

The empty-start model is now connected to the real main scene, Fleet, Routes,
station inspectors, reservations, Find and the minimap. A Station tool previews
and purchases city-linked stations using the fixed-tick command queue. Procedural
placeholder buildings are used; generated artwork remains deferred.

## Try it in Godot

1. Pull `codex/fix-main-merge` and let Godot import the updated scripts.
2. Open `scenes/dev/city_preview.tscn` in the FileSystem dock.
3. Press **F6** (Run Current Scene). This scene inherits the normal main scene;
   it is not a separate simulation or renderer.
4. It starts paused with seed `42`, four cities, £5000 and no trains or track.
   To change the layout, select the preview's root node and edit **Startup City
   Seed** / **Startup City Count** in the Inspector. Save the preview scene and
   run it again. Counts 3–8 are supported.
5. Click **Station** in the top toolbar. Move over empty land beside a city.
   The hatched ghost shows the 3×2 building and five-tile horizontal platform;
   the circle shows the six-tile catchment radius. `+` or `×`, price and readable
   status text explain whether placement is allowed. A good initial position is
   four grid tiles below a city's center. The building must not cover city land.
6. Left-click to buy: £250 plus £10 for each missing platform tile, normally £300.
   One station serves one city. Compatible existing straight rails are reused;
   buildings, claims, signals and incompatible track block placement.
7. Short right-click or Escape returns to **Connect track**. Existing right-drag
   and long-right-hold removal, and the Remove shortcut, remain available.
8. Connect two stations, keeping their initial five-tile platforms horizontal.
   Put junctions outside those protected platforms. Use **Find → City** or click
   hollow city markers on the minimap to reach other settlements.
9. Open **Fleet**, buy a passenger locomotive, choose **Start at** and **To**,
   and click **Start new passenger service**. Both stations must exist and the
   track must connect them. Open **Routes** for further stops, modes and waypoints.
   Close the editor and resume to run under the existing reservation rules.
10. For freight, connect the forest and terminal loading tiles with horizontal
    track at the loading cells. Buy a freight locomotive in Fleet and click
    **Start freight service**. It can operate independently of passenger routes.

The initial camera focuses on the first city. City markers are hollow squares;
stations/industries retain filled markers. City-owned population/growth is not yet
implemented, so the interface does not invent population figures. Built stations
use the current passenger demand model, initially with empty queues.

## Preview limitations

**Generated games can now be saved.** Use **Save** and choose one of the four
slots; overwriting retains that slot's previous save as a backup. **Load** works
from this preview or the ordinary main scene and preserves the saved map, train
positions, queues and finances. See [city saves](CITY_SAVES.md).

Normal **F5** still starts the tutorial; the ordinary seeded New Game chooser is
next. If custom command-line city arguments are set, clear them to return to normal
startup. The preview budget and objectives remain provisional.

Station purchases are not undoable and clear the prior construction history so
old rail undo entries cannot remove a purchased platform. Later track edits still
use the existing undo rules. The tutorial objective reward sequence does not run
in city mode; the objective panel instead shows construction guidance and station
coverage. The budget and objective feasibility still need balancing.

For command-line development, the normal main scene also accepts:

```sh
godot --path . -- --city-seed=42 --city-count=4
```

## Integration and safety

- Normal tutorial startup and strict validation retain their existing defaults;
  version 40 migrates older tutorial saves and explicitly supports city companies.
- The scene no longer draws, reserves, charges or offers phantom primary trains.
  An empty company has usable Fleet/Routes guidance instead of invalid selections.
- New city passenger services use ordinary `PassengerService` actors and catalog
  stop IDs. Creating a first route does not require a hidden A/B/C service.
- Station commands contain plain JSON-safe data, not Vector2i dictionary keys.
  Running edits wait for the next fixed tick; paused edits follow the existing
  current-tick policy. World/track read sets, current funds and current physical
  occupancy/reservations are rechecked on execution.
- City land, existing facility grounds and purchased platform cells are protected.
  Missing industry loading rails can be built horizontally, then are protected.
- Buying another station preserves queues, history, in-flight journey clocks and
  every active train's physical position. It does not recreate existing actors.

The scene integration suite passes 31 checks on headless Godot 4.6.3 covering
startup, editor empty states, purchases,
JSON/tick command execution, first-route editing and train movement, later station
construction, independent freight startup under real reservations, and return to
ordinary tutorial saves. The tests check functional state; a graphical pixel-level
review of the new preview remains useful when running F6 locally.

Generated-game save validation/restoration is now implemented. Next: the ordinary
seeded new-game chooser and scenario affordability checks. Population/city-owned trip
generation and bounded service-driven growth follow the playable persistence slice.
