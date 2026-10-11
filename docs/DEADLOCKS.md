# Deadlocks and physical recovery

Actual stopped trains waiting on each other form a wait graph keyed by permanent
fleet IDs. A continuous cycle lasting three simulation seconds generates one
`DEADLOCK_DETECTED` event and **Traffic (1)**. Loading, dwell, a single wait and
lookahead contention alone are not deadlocks. Pausing freezes confirmation time.

## Reverse a train

1. Open **Traffic**; this pauses the simulation and shows waiting reasons.
2. Select a train in a confirmed cycle and click **Reverse selected train**.
   Its position, path and load stay unchanged. Only its direction reverses.
3. Close Traffic and resume. It travels back along its existing path to the
   station/industry from which this leg departed, obeying reservations and signals.
   It can still wait for occupied track, a stop signal or an incomplete path.
4. At arrival, it is held and its service disabled. Passenger riders return to
   that departure queue without fares; freight cargo stays aboard without a
   delivery payout. Queue overflow is retained. No recovery fee is charged.
5. Fix the layout or operating order. Use **Resume selected train** in Traffic
   or **Enable service** in Fleet when ready, then close the window and resume.

Reversal logs `TRAIN_REVERSED` and clears the confirmed incident; physical arrival
logs `TRAIN_RECOVERED`. A blocked cycle may form again and be detected again.
Already returning trains cannot be reversed repeatedly through this control.
There is no teleport, automatic siding selection or alternate-path search.

## Missing track and saves

Removing unoccupied track on a travelled route freezes the train at its current
position, with its load aboard and a persistent route-incomplete warning. Its
runtime path is retained separately from the edited network. Repair that path to
continue; constructing a different path does not redirect a train mid-trip.
Occupied/reserved track remains protected from demolition. Stop-order changes
require an empty train physically at the new first stop and a connected new route.

Saves are **v19** and retain runtime paths, unfinished reversals, loads and holds.
V18 saves receive defaults during migration. Reservation ownership, signal block
authority and deadlock timers are rebuilt after load. A persistent cycle is
rediscovered after three seconds of actual waiting.

## Checks

```sh
godot --headless --path . --script res://tests/test_deadlock_monitor.gd
godot --headless --path . --script res://tests/test_deadlock_integration.gd
godot --headless --path . --script res://tests/test_stopped_routes.gd
```

Checks cover collision safety, physical return of either train, passenger/cargo
conservation, save/load during and after recovery, stranded saves, repair/resumption,
matching detection at 30/60/120 FPS and Traffic at 200% UI scale. Manual play: remove
an unreserved tile ahead of a moving train, save/reload, repair it, then provoke a
head-on meeting and reverse either train through Traffic.
