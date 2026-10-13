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
is labelled in the chooser. Restarting the application initially selects Slot 1;
load another slot to continue that game. Shared display/accessibility preferences
apply to every game, while maps, fleet, economy, passenger demand and simulation
state are stored independently.

| Slot | Game file | Previous-save file |
| --- | --- | --- |
| 1 | `trainz_save.json` | `trainz_save.backup.json` |
| 2 | `trainz_save_slot_2.json` | `trainz_save_slot_2.backup.json` |
| 3 | `trainz_save_slot_3.json` | `trainz_save_slot_3.backup.json` |
| 4 | `trainz_save_slot_4.json` | `trainz_save_slot_4.backup.json` |

All paths are under `user://`. Slot 1 preserves the existing filenames. The save
schema remains version 25: slots change storage locations, not simulation data.
Each write uses that slot's temporary file, checks write/backup errors, then
renames it into place. Failed saves retain the selected session/slot; failed loads
validate before applying state and cannot switch the current slot. Errors appear
inside the chooser. This is manual slot storage; periodic rotating autosaves remain
on the roadmap.

Validation: `tests/test_save_slots.gd` exercises four independent worlds, isolated
backups, malformed loads, failed writes, construction guards, chooser feedback and
fresh-game reset without overwriting files. Use an isolated `XDG_DATA_HOME` when
running save-writing tests so they cannot alter your personal game files.
