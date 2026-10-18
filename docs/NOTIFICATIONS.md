# Operational notification preferences

Open **Settings**, scroll to **Operational alerts**, and choose a mode for:

- Signal / reservation waits.
- Confirmed deadlocks.
- Reversal / recovery / cleared deadlocks.
- Freight contract deadlines (new warnings only).

Each category offers **Off**, **Notice**, or **Notice + pause**. Press **Apply** to
keep the changes; Cancel leaves the applied preferences unchanged. Preferences
are stored with the player's display/control settings in `user://settings.cfg`,
so they apply to new and loaded games. Preferences are separate from company saves; the contract one-time warning marker is saved with the company.

The defaults show a notice for confirmed deadlocks and leave routine waits and
recovery and contract deadline notices off. Construction feedback, objective messages and other direct
command feedback keep their existing behavior.

A notice appears in the header with text explaining the incident. **Notice + pause**
finishes the complete simulation tick that generated the incident, then pauses.
At 2×/5×/10× speed, the remaining steps scheduled for that frame are discarded;
there is no extra movement after the incident tick. Use the configured pause key
(Space by default) to resume. The notice and paused status show the configured key.

Open **Problems** to inspect the current issue or search its historical record.
Off affects notification display and automatic pause; the event remains in the
same saved incident history. Changing preferences does not replay previous events.
A wait is announced when a new waiting episode/reason is recorded; resuming the same
ongoing wait does not repeatedly pause the game on the same event.

Loading restores history quietly and discards pending notices from the previous
world state. Resuming a blocked train after loading can record a fresh waiting
incident and follow the current notification preference. Notifications are displayed
from live events, rather than replaying the saved incident list.

Several incidents in one tick are combined into one header notice, with the most
severe message and a count of other alerts. Any requested pause is honored. The
pending display queue is bounded; the event stream remains the source for history.
Notifications introduce no flashing, sound, or modal popup. Acknowledgement,
watchlists and per-train rules remain planned. Future no-pause difficulty modes
must use the policy's pause-permission hook when applying automatic alerts.

## Quick test

1. Complete A–B and run the passenger train.
2. Place a signal on clear straight track ahead. Click twice to select **S**.
3. Open Settings and set **Signal / reservation waits → Notice + pause**. Apply.
4. Let the simulation run, optionally at 10×. The train approaches the signal,
   records its wait, and the game pauses with an explanatory header notice.
5. Open Problems to inspect/locate the train. Close and resume; the same unchanged
   wait should not repeatedly pause the game.
6. Remove the manual stop signal (third click with the Signals tool) and resume.
7. Return the wait preference to Off or Notice if you prefer uninterrupted dispatch.

## Checks

```sh
godot --headless --path . --script res://tests/test_notification_policy.gd
godot --headless --path . --script res://tests/test_notifications_integration.gd
```

Tests cover all modes, deduplication, bounded queues, severe-message selection,
pause-permission handling, quiet history restore, config persistence, unapplied
settings edits, 200% UI scaling and identical automatic-pause ticks at 30/60/120 FPS
at 10× speed. Existing signal, deadlock and save suites remain part of regression testing.

## Contract deadline reminders

Set **Settings → Operational alerts → Freight contract deadlines** to **Notice**
or **Notice + pause**, then Apply. The default is **Off**. An active order generates
one warning when it first reaches **25% or less of its original time window**,
provided it has not completed or expired. This is the same time threshold used by
Network summary, not an ETA or a prediction that the order will fail.

Off suppresses the header notice and pause, but the canonical warning is still
recorded in **Problems → History**. Enabling reminders later does not replay an
already-issued warning; use Accounts → Network summary or Freight contracts for
current progress. Completion, expiry and ordinary command feedback retain their
existing behaviour. Reminders never change contract terms, release trains or pay
bonuses.

Version **51** retains a per-contract warning tick. Loading does not rearm a
warning, even if older events have been pruned. Version 50 migration adds an unset
marker without changing deadlines, progress, cash or physical state. An active
older contract already in its final quarter can issue its first new reminder on
the next simulation tick, according to the current player preference.

At 10×, auto-pause still finishes exactly the warning tick. Resuming does not
immediately pause again. Successful autosaves no longer replace an active notice;
if a save fails, its error appears alongside the existing message. Existing alert
priority/batching still favours confirmed deadlocks and honours any requested pause.

`test_contract_notifications.gd` covers the exact threshold, Off/Notice/Pause,
quiet defaults, history retention, duplicate suppression after load with pruned
history, settings Apply/Cancel/persistence, version 50 migration, simultaneous
autosaving, and identical 10× warning snapshots at 30/60/120 FPS.
