# Find objects and watchlist

Click **Find** in the toolbar. The game pauses while this window is open; close it
and resume when ready. Search matches names, permanent train IDs such as `#3`,
service routes, model names and current status text. Filter by Train, Service,
Station, Industry or City. This includes running and stored fleet vehicles, all active
services, tutorial or player-built stations, seeded cities and active industries.

Select an item to read its status. **Locate and show route**, or a double-click,
moves the camera to a running train's current location or a facility's map cell.
For a train or service it also opens Overlays with that service's route selected.
It does not move the train, repair track, reverse it or alter its service. Stored
trains have no map location, so their Locate button is disabled; manage them in
Fleet.

**Pin selected** adds a textual star and keeps the object in the **Pinned only**
watchlist. Pins use permanent train IDs or stable service/facility keys, so renaming
an object preserves its pin. Unpin it with the same button. Pins are saved with
this company, including its slot backups and autosaves. Loading replaces them
with the loaded company's list; new games start empty. Save after changing pins.
Missing objects are pruned before saving or refreshing Find. Stored vehicles keep
their pins. Older saves migrate to an empty watchlist. Per-object notification
rules and saved search presets remain future refinements.

**Service performance cards** opens outcome, money, capacity, waiting and
arrival-target cards for the selected service/assigned train, with a route
selector for the rest of the company. See [service performance](SERVICE_PERFORMANCE.md).

The window reports current object status when opened or its filters change; it is
not an incident history. **Problems** still separates current issues from saved
historical events, and **Traffic** provides dispatcher hold and recovery controls.

`test_object_browser.gd` verifies search/filter callbacks, stable pins across
renames, stored vehicles, current-position map location, synchronized route
controls, company-specific persistence on load and button accessibility at 200% UI scale.
