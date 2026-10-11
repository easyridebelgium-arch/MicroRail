# Find objects and watchlist

Click **Find** in the toolbar. The game pauses while this window is open; close it
and resume when ready. Search matches names, permanent train IDs such as `#3`,
service routes, model names and current status text. Filter by Train, Service,
Station or Industry. This includes running and stored fleet vehicles, all active
services, the three stations, the forest and the cargo terminal.

Select an item to read its status. **Locate and show route**, or a double-click,
moves the camera to a running train's current location or a facility's map cell.
For a train or service it also opens Overlays with that service's route selected.
It does not move the train, repair track, reverse it or alter its service. Stored
trains have no map location, so their Locate button is disabled; manage them in
Fleet.

**Pin selected** adds a textual star and keeps the object in the **Pinned only**
watchlist. Pins use permanent train IDs or stable service/facility keys, so renaming
an object preserves its pin. Unpin it with the same button. This first watchlist is
session-only: loading a game or exiting clears it, preventing pins from pointing
to reused IDs in another game. Persistent watchlists and per-object notification
rules remain future refinements.

The window reports current object status when opened or its filters change; it is
not an incident history. **Problems** still separates current issues from saved
historical events, and **Traffic** provides dispatcher hold and recovery controls.

`test_object_browser.gd` verifies search/filter callbacks, stable pins across
renames, stored vehicles, current-position map location, synchronized route
controls, session reset on load and button accessibility at 200% UI scale.
