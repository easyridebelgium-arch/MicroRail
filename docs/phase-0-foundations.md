# Phase 0 - Foundations

Status: integrated with the merged fleet and route code and checked headlessly in
Godot 4.6.3. Foundation module and merge integration tests pass. Phase 0 accessibility
work is now complete (UI scale to 200%, mouse button remapping, command queue persistence).
Test with the checklist below before building on this.

## What was added

| File | Purpose |
|---|---|
| `scripts/core/sim_clock.gd` | Fixed 60 Hz simulation steps, tick counter, speed multiplier |
| `scripts/core/sim_rng.gd` | The one random number generator for simulation code, saved in saves |
| `scripts/core/event_log.gd` | Bounded event stream (tick, subject, type, data) |
| `scripts/core/save_migrations.gd` | Upgrades old saves one version at a time |
| `scripts/core/game_settings.gd` | Player settings in `user://settings.cfg` (not in saves) |
| `scripts/core/palette.gd` | Colours by role: Default, Colour-blind safe, High contrast |
| `scripts/core/input_actions.gd` | All keyboard commands as InputMap actions, with remapping |
| `scripts/settings_dialog.gd` | Settings window: scale, palette, reduced motion, keys |
| `scripts/core/command_queue.gd` | Construction commands scheduled and executed by `main.gd`, with save persistence |
| `tests/phase0_selftest.gd` | Headless checks for the modules above |
| `tests/test_command_queue.gd` | Headless checks for the command queue |

The running code is under `scripts/`. The `patched/` folder and
`phase0-changes.diff` are historical copies, not installation instructions for the
merged game. `patched/.gdignore` keeps those backups out of Godot imports; do not
copy them over the current scripts.

## What changed in behaviour

- **Simulation steps are fixed at 1/60 s** instead of using each frame's
  `delta`. Integration tests compare timers and moving trains at 30, 60 and
  120 FPS. Long stalls deliberately drop excess catch-up time; this is not yet
  a full deterministic command/replay system. Rendering, camera, notices and UI
  still use real frame time.
- **Saves are version 19**, defined only by `SaveMigrations.CURRENT_VERSION`.
  Version 14 route saves and both version 15 variants (fleet-only and
  simulation-only) migrate in memory. The v16→v17 migration adds the command queue; v17→v18 adds switch positions; v18→v19 adds retained runtime paths,
  physical recovery/dispatch state and signal modes.
  Existing data is preserved; missing systems receive defaults. Pre-fleet saves
  reconstruct starter-train upgrades and their purchase costs. Validation
  completes before the live game changes. Saving again writes v19 and retains
  the previous save as a backup. Saves older than 14, future versions and
  invalid current-format data are rejected.
- **Keys go through the InputMap.** Defaults match the old keys (Space, M, G,
  I, Home, Esc, WASD/arrows, Shift). Letter shortcuts follow the letter
  printed on the key; camera movement follows the physical key position (WASD
  stays under the left hand on AZERTY and other layouts).
- **Mouse buttons go through the InputMap.** Build (left), demolish (right),
  pan (middle), zoom in (wheel up) and zoom out (wheel down) are now remappable
  in the settings dialog alongside keyboard commands.
- **New Settings button** in the toolbar (next to Routes).
- **Trains, build preview and map markers use the palette.** Default colours
  are unchanged.
- **UI scale now supports 200%** with a 175% step. The compact header mode
  activates at 175% instead of 150%. All UI offsets scale with the interface
  factor.

## Rules for new code

1. **Simulation logic goes in `_simulation_step()`** (or something it calls).
   Never put game rules in `_process(delta)`.
2. **Never use global `randf()`, `randi()`, `Array.shuffle()` or
   `Array.pick_random()` for gameplay.** Use `sim_rng`. Cosmetic effects may
   use the global ones.
3. **Record meaningful happenings with `_record_event(type, subject, data)`**
   and add new types as constants in `event_log.gd`. Alerts, the news
   journal, the incident log and replay markers should read this stream.
   Event data: simple values only; after loading, whole numbers are floats, so
   read them with `int()`.
4. **Changing the save format:** raise `SaveMigrations.CURRENT_VERSION`, add a
   `_vN_to_vN+1` step, add a case in `_upgrade_one()`, add the new fields to
   `_save_game()` and `_is_valid_save()`, and extend the self-test.
5. **New keyboard command:** add a constant, a label, a default key and an
   entry in `ORDER` in `input_actions.gd`; then use
   `event.is_action_pressed(InputActions.YOUR_ACTION)`. Never test
   `event.keycode` directly.
6. **New colour that carries meaning:** add a role to `palette.gd` with a value
   for all three modes, and pair it with a shape or label.

## Known limits (deliberate, for later)

- **Build and demolish use the command queue.** While the game runs they wait
  for the start of the next simulation step; while paused they run at once.
  Upgrades, purchases, Undo/Redo, route and fleet changes already require the
  game to be paused, so they act directly and never wait. The queue is now
  saved in version 17 and restored on load. Tests: `test_command_queue.gd` (27 checks),
  `test_command_wiring.gd`, `test_mouse_tracks.gd` and
  `test_merge_integration.gd` pass (11 Oct 2026).
- **Paused edits are not logged.** They run immediately and are not recorded
  anywhere a replay could read, so deterministic replay is still incomplete.

- **Reduced motion has nothing to reduce yet.** The setting is stored and
  readable (`GameSettings.reduced_motion`); gate screen shake, particles and
  flashing on it as they are added.
- **The event stream is not shown anywhere yet.** For now set
  `event_log.echo_to_output = true` to print events to the Output panel.
- **Freight departures and arrivals are not recorded**, only deliveries, because
  `FreightTrain` has no signal for them. Add signals when the notification
  centre needs them.
- **Esc closes the settings window**, so Esc cannot be assigned as a key in it.
- **Map markers and trains differ by colour only** on the network map; add
  distinct shapes (e.g. square stations, triangle industries) in Phase 1.
- **Colour-blind palette** uses the Okabe-Ito colours; it has not been checked
  with a simulator on your screens.

## Checklist before building on this

Run the self-test:

    godot --headless --path . --script res://tests/phase0_selftest.gd

It should print `N checks, 0 failed`. Then play and check:

1. The game starts; both trains move; income and objectives behave as before.
2. Speed feels the same as before (it should, since speeds are per second).
3. Pause (Space), map (M), goals (G), inspect (I), Home, Esc and WASD all work.
4. Save, quit, load: trains, money and objectives are restored.
5. Load a **version 14 save** (keep a copy first): it loads with an
   "Upgraded from save version 14" notice, then saves as v17.
6. Settings: pick 125%/150%/175%/200% scale; switch to Colour-blind safe and check the
   build preview, invalid cells, both trains and the map; remap a key, press
   Apply, restart, confirm it persisted; "Restore default keys" works;
   remap mouse buttons and confirm they work.
7. Turn on `event_log.echo_to_output` and confirm events appear when trains
   arrive and depart, tracks are built, and logs are delivered.
8. Let the game run for a while with a slow frame rate (drag the window) and
   confirm nothing speeds up or breaks.

If anything fails, send me the Output panel text and I will fix it.
