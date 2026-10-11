# Problems, incidents and measured waiting

## Current problems

Click **Problems (N)** in the toolbar. Opening this window pauses the game, as
Fleet and Traffic do. Closing it or locating an item leaves the game paused;
resume with your configured pause key (Space by default).

The default view lists current problems for every active passenger or freight train:

- **Urgent — Confirmed deadlock:** the train is in a sustained wait cycle. Inspect
  the layout and signal boundaries; Traffic offers physical reversal.
- **Warning — Waiting:** an attempted movement was completely stopped by a signal
  or reservation. The reason names the signal, track or blocking train.
- **Warning — Route incomplete:** complete or repair the track/waypoint path to the
  next destination. This includes a service that has never acquired a route.
- **Info — Dispatcher hold:** the player deliberately held the train. This is not
  traffic congestion.

Search matches train IDs, custom train names, service names and explanations.
Severity filters narrow the list. **Locate selected item** centers the camera on
that active train and closes the window. It does not move the train or bypass signals.

A cleared wait disappears from current problems. The number on the toolbar counts
trains with a current problem, rather than the number of recorded incidents.
Normal station dwell, freight loading and withdrawn trains parked at home do not
become waiting problems solely because they are stationary.

## Recent incidents

Select **Recent incidents (history)** to browse waiting events, detected/cleared
deadlocks, dispatcher changes and recovery events from the existing event stream.
These are historical records and may already be resolved. The view uses the latest
200 events and supports the same search/severity filters. Times are elapsed simulation
seconds from the recorded ticks, not real-world timestamps.

Locate follows an incident's train at its current position if still active. If that
train has been stored or removed, a recorded track location is used instead. An
incident without a surviving train or recorded location cannot be located. Existing
saved event history is reused; this step introduces no save-format change.

This is the first problem/incident browser. Notification preferences, automatic
pause rules, acknowledgement and watchlists remain later steps.

## Measured waiting

Open **Overlays** and enable **Measured waiting**. White bars and numeric labels
show aggregate stopped **train-seconds** at each conflict cell during roughly the
last 60 simulation seconds. The bar reaches its maximum at 10 train-seconds; the
numeric value continues to show the actual amount. Hover a tile for its value.
Colours are not required to read this overlay.

Waiting is sampled once per fixed simulation tick, only when a train tries to move
and gets zero movement because of a signal or reservation. An approaching train
that still advances does not accrue stopped time. Station dwell, cargo loading,
missing-route stops and deliberate dispatcher holds are excluded. The recent window
uses aligned one-second buckets and expires old samples, including while trains are
moving normally. Pausing freezes measurements; 2×/5×/10× speed counts simulation time.

Problems show continuous waiting, recent waiting and total traffic waiting since
measurement began. These derived diagnostics restart after loading a save; event
history survives. This is observed congestion, not a prediction or a timetable delay.

## Signals are available now

Basic automatic block signals already belong to the implemented early network phase:
select **Signals**, then click straight track outside stations once for **A**
(automatic), twice for **S** (manual stop), and a third time to remove the signal.
A circle/square identifies the mode; these are not directional red/green aspects.
**Traffic** is the recovery window, not a track signal.

A loop with no boundaries can share one conservative block with both switches.
An arrival stopped between a switch and its platform can obstruct a departure.
Place boundaries on both branches inside the loop, keeping each switch with its
station approach. See [the tested passing-loop layout](MULTIPLE_SERVICES.md#a-repeatable-passing-loop-example)
and [signal operating rules](SIGNALS.md). One-way signals, route/platform signals,
priorities and automatic selection of a free loop branch remain on the roadmap.

Different liveries are also planned. Coaches and wagon consists need safe train-length
handling first; new industries and recipes follow in the passenger/freight-chain phase.
Art can be prepared alongside development, but longer trains need matching collision,
reservation, platform and block-length rules before becoming playable.

## Verification

```sh
godot --headless --path . --script res://tests/test_traffic_metrics.gd
godot --headless --path . --script res://tests/test_problems_integration.gd
```

Checks cover measured time at 30/60/120 FPS, true signal waits, exclusion of loading
and holds, bounded retention, resumption and history, search/severity filtering,
independent service identities, map location, load resets and dialog scaling at 200%.
