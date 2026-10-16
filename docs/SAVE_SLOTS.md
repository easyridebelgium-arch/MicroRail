# Four independent games

The Save, Load and Previous-save toolbar buttons now open a four-slot chooser.
Opening it pauses gameplay; close it and press Play/Space to resume.

- **Save:** select Slot 1–4 and press **Save selected slot**. Only that slot changes.
  Its previous manual save becomes its own backup. Saving a different slot also
  makes that slot current, so the chooser selects it next time.
- **Load:** select a saved slot and press **Load selected slot**. Loading changes
  the game in memory and makes that slot current. Empty slots cannot be loaded.
- **Start fresh:** open Load, select any slot, then press **Start fresh game in
  selected slot**. Choose Tutorial or City sandbox in the [New Game dialog](NEW_GAME.md).
  Starting then replaces the current in-memory session; Cancel keeps it. Save when ready. Starting fresh does not overwrite any saved file.
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
schema is version 48, including amenities, loan state, route appearance,
alert acknowledgements, final destinations carried by connecting trains, and
station-arrival groups for boarding priority and bounded waiting-satisfaction
history, gradual demand factor/carry, and original journey clocks with recent
completed timing, plus active arrival targets and bounded punctuality history.
Version 38 migration adds the saved tutorial world/facility catalog. It preserves
physical positions, passengers, inventories, money and simulation RNG state.
Version 39 validates facility identities, geometry, enabled industry flags and
layout versions before changing the game. Version 40 explicitly supports the
validated generated city profile, optional services and empty companies alongside
tutorial saves. Loaded geometry is never regenerated; see [city saves](CITY_SAVES.md)
and [world catalog](WORLD_CATALOG.md). Version 41 persists [city populations and
request outcomes](CITY_DEMAND.md), initializing historical measurements empty when
upgrading v40 while preserving accepted journeys and the live RNG. Version 42
persists [useful-service request cohorts](USEFUL_SERVICE.md) and cross-checks
unfinished measurements against queued/onboard passengers. Version 41 migrations
start this measurement at the saved clock with an empty baseline, preserving all
existing company and passenger state. Version 43 adds [bounded city growth](CITY_GROWTH.md):
per-game rules, population anchors, assessment/grace clocks, consumed outcome
counters, fractions, reasons and history. Version 42 migrations preserve the
company and start a fresh grace/assessment baseline at the saved clock.
Version 44 adds [service performance counters and per-company watchlists](SERVICE_PERFORMANCE.md).
Version 43 migrations preserve the company, start route measurements at the saved
clock and use an empty watchlist. Loading another slot replaces its pins/counters;
backups and autosaves retain their own snapshots.
Version 45 adds [company progress reports](PROGRESS_REPORTS.md). Version 44 migrations
start a recording baseline at the saved clock with current totals, no invented
history and reminders off. Slots, backups and autosaves retain independent report
histories and reminder choices.
Version 46 adds [seeded scenario identity/completion](SEEDED_SCENARIOS.md). Version
45 migrations keep earlier companies ordinary sandbox/tutorial games. Goals use
existing final city-journey counters; no old completion is inferred from a seed.
Version 47 adds [immutable terrain profiles and bridge validation](RIVERS_AND_BRIDGES.md).
Version 46 migrations use flat terrain and preserve existing rails and company
state; a new river sandbox must be explicitly selected for water crossings.
Version 48 recognises [wide and meandering river presets](RIVER_VARIETY.md). Version
47 migration preserves the original immutable profile and company state exactly;
existing rivers are not widened or moved.
Version 37 migration adds an uninstalled factory, preserving sawmill inventory,
physical train stages, cash and historical sales. Version 38 retains factory
processing progress and validates stock transferred between industries and goods
aboard/delivered at the terminal. See [factory chain](FACTORY_CHAIN.md).
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
inside the chooser. Periodic autosaves keep three separate recovery copies per slot; they never replace
manual files or backups. Configure their interval in Settings and use **Recover autosave**
on the title screen or in the Load chooser. See [autosaves](AUTOSAVES.md).

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
Recover autosave, Settings and Quit. Continue chooses the most recently modified primary save with
readable metadata, then validates the complete save before entering gameplay.
Failed loads leave the title menu usable. New starts paused and changes no saved
file until you explicitly Save. In-game Settings can return to the title screen;
save your current progress first.

The in-game chooser includes a bounded read-only map thumbnail, game time and
balance for the selected primary/backup. Invalid metadata shows a fallback rather
than applying any state. Preview success is not full validation. No live simulation
is created for these thumbnails, and no image files are added to your save folder.
