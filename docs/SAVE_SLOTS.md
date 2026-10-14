# Four independent games

The Save, Load and Previous-save toolbar buttons now open a four-slot chooser.
Opening it pauses gameplay; close it and press Play/Space to resume.

- **Save:** select Slot 1–4 and press **Save selected slot**. Only that slot changes.
  Its previous manual save becomes its own backup. Saving a different slot also
  makes that slot current, so the chooser selects it next time.
- **Load:** select a saved slot and press **Load selected slot**. Loading changes
  the game in memory and makes that slot current. Empty slots cannot be loaded.
- **Start fresh:** open Load, select any slot, then press **Start fresh game in
  selected slot**. This replaces the current in-memory session with a fresh map.
  Save it when ready. Starting fresh does not overwrite any saved file.
- **Previous save** (history/curved-arrow button): choose a slot to load its backup.
  Each slot has its own backup; this does not load another slot's history.
- **Save folder:** opens the Godot user-data folder containing these files.

Loading or starting fresh discards unsaved progress in the current session. Save
first if you want to keep it. Slot timestamps are shown in UTC. The current slot
is labelled in the chooser. The title screen offers Continue for the latest readable primary save; choose
another slot with Load game or recover its previous save with Load previous save. Shared display/accessibility preferences
apply to every game, while maps, fleet, economy, passenger demand and simulation
state are stored independently.

| Slot | Game file | Previous-save file |
| --- | --- | --- |
| 1 | `microrail_save.json` | `microrail_save.backup.json` |
| 2 | `microrail_save_slot_2.json` | `microrail_save_slot_2.backup.json` |
| 3 | `microrail_save_slot_3.json` | `microrail_save_slot_3.backup.json` |
| 4 | `microrail_save_slot_4.json` | `microrail_save_slot_4.backup.json` |

All paths are under `user://`. Slot 1 preserves the existing filenames. The save
schema is version 37, including amenities, loan state, route appearance,
alert acknowledgements, final destinations carried by connecting trains, and
station-arrival groups for boarding priority and bounded waiting-satisfaction
history, gradual demand factor/carry, and original journey clocks with recent
completed timing, plus active arrival targets and bounded punctuality history.
Version 36 migration adds an uninstalled sawmill and default freight-stage fields,
preserving the existing log-only service, cash and physical positions. Industrial
inventories, productive ticks and actual freight departure/recovery stops persist
in version 37; invalid stock conservation or stage geometry is rejected atomically.
See [sawmill chain](SAWMILL_CHAIN.md).
Version 35 migration records old flat-fare deliveries as legacy income at £5
each; there is no cash change or retroactive Express premium. New class receipts
and paid counts persist independently of recent journey history. Version 34 migration preserves all existing passengers as Local and adds saved
Express generation counters/class metadata, without moving trains or changing
journey clocks, revenue or arrival targets. Version 33 migration starts unknown arrival history empty without changing train
positions, queues or departure progress. Version 32 migration keeps queue ages and marks unknown
legacy journey origins unmeasured. Version 31 migration
starts response at 100%, preserving queues and satisfaction history. Version 30 migration preserves arrival groups and starts unknown
boarding history empty. Version 29
initializes unknown waiting ages at its saved clock without changing counts.
Version 28 preserves all counts/positions during migration; version 27 also gains
default presentation data. Slots choose storage
locations rather than changing simulation rules.
Each write uses that slot's temporary file, checks write/backup errors, then
renames it into place. Failed saves retain the selected session/slot; failed loads
validate before applying state and cannot switch the current slot. Errors appear
inside the chooser. This is manual slot storage; periodic rotating autosaves remain
on the roadmap.

Validation: `tests/test_save_slots.gd` exercises four independent worlds, isolated
backups, malformed loads, failed writes, construction guards, chooser feedback and
fresh-game reset without overwriting files. Use an isolated `XDG_DATA_HOME` when
running save-writing tests so they cannot alter your personal game files.

## Rename migration (Trainz → MicroRail)

Godot names the user-data folder after the project, so the rename moves it from `.../app_userdata/Trainz`
to `.../app_userdata/MicroRail`. On startup `scripts/core/legacy_migration.gd` copies any files the new folder
lacks, renaming `trainz_save*` to `microrail_save*` and skipping `.tmp` files. It never overwrites and never
touches the old folder, which can be deleted once the saves are confirmed.

Loan balances and repayment schedules are stored independently per slot; old saves
migrate to zero debt. Map/Goals visibility is shared in player settings, not saved
per game. See [bank loans](LOANS.md).

## Title menu and previews

The title screen supports Continue, selected-slot Load, Load previous save, New,
Settings and Quit. Continue chooses the most recently modified primary save with
readable metadata, then validates the complete save before entering gameplay.
Failed loads leave the title menu usable. New starts paused and changes no saved
file until you explicitly Save. In-game Settings can return to the title screen;
save your current progress first.

The in-game chooser includes a bounded read-only map thumbnail, game time and
balance for the selected primary/backup. Invalid metadata shows a fallback rather
than applying any state. Preview success is not full validation. No live simulation
is created for these thumbnails, and no image files are added to your save folder.
