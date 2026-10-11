# Gameplay speed

The speed dropdown beside Pause shows **1×** by default. Click it to select
**1×, 2×, 5× or 10×**. Number-row positions **1, 2, 3, 4** select those speeds
directly. Physical key positions work unshifted on AZERTY as well as QWERTY;
change them in **Settings → keyboard bindings** if preferred. Tooltips show the
current bindings. Management dialogs and text entry suppress speed shortcuts.

Pause stays independent: selecting a speed while paused does not resume the game.
Space resumes at the chosen speed. Starting the application defaults to 1×;
loading a save keeps the current session's selection. Speed is UI state and adds no save fields. The current v20 schema adds waypoint
directives; loading keeps the session speed.

Trains, reservations, signals, station waits, production, income, running costs and
deadlock confirmation all advance with simulation time. Camera motion, interface
messages and menus use real time. Speed increases the number of fixed 1/60-second
ticks per frame, never the distance moved in one tick or the simulation step size.

The clock supports full 10× at 30/60/120 FPS and caps catch-up after a long stall
at eight normal-speed ticks multiplied by the chosen speed (80 at 10×). Sustained
low performance can therefore slow simulated time; the game avoids an unbounded
backlog or skipping safety checks to catch up.

This is a Phase 0 quality-of-life addition, built on the existing fixed clock and
input-remapping foundation, before waypoints and expanded services.

```sh
godot --headless --path . --script res://tests/test_game_speed.gd
```

Checks compare clock rates and real game state at all four speeds and all three
frame rates, including positions, station dwell, production, money and events.
They also cover pause, dropdown/keyboard controls, remapping, typing/dialog guards,
load behavior, stall limits and the selector at 200% UI scale.
