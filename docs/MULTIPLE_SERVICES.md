# Multiple active passenger services

The prototype supports up to eight independent passenger services, plus the existing
Forest–Terminal freight service. Each passenger route has one assigned train and
its own name, stops, Shuttle/Loop mode, waypoints, dwell, load, withdrawal and hold.
Stored trains stay off-map. Several trains on one service and multiple platforms
remain later steps.

## Update and start another train

1. Close Godot. In GitHub Desktop select `codex/fix-main-merge`, then **Fetch origin**
   and **Pull origin**. Reopen the existing project and press **F5**.
2. Complete a connected passenger route. In **Fleet**, buy a passenger model and
   select the stored train. Buying alone does not put it on the map.
3. Select **Start at Station A/B/C**, then **Start new passenger service**.
   A must be clear to start there: let the existing train depart, then pause and
   try again. Alternatively start the second train at B or C on a clear platform.
   Its initial route is A–B if started at A, or B/C–A otherwise.
4. Close Fleet and open **Routes**. Choose the new service from the dropdown; its
   train ID appears beside its name. Edit its name, stops, Shuttle/Loop mode and
   each leg's waypoints, then **Apply**. Edits require an empty train physically
   at the proposed first stop. Editing one route does not reset other trains.
5. Close Routes and resume. Trains share station queues, fares and running costs,
   and obey the same reservations, locked switches and signals. Small **#ID**
   labels distinguish passenger trains; the minimap includes every active train.
6. Use **Traffic** to select any active train, inspect its waiting reason, hold or
   resume it, or physically reverse a train in a confirmed deadlock.
7. Save normally. Version 22 retains every service's exact position, load, dwell,
   direction, withdrawal and recovery state. Supported earlier saves load with
   their existing services; no additional trains are created automatically.

For A–B and A–C from the same origin, launch the A–B train first. When it clears A,
start the second train at A and edit its stops to A, C before resuming. Direct the
A–C service through your bypass waypoint to pass B without stopping. Loop mode
lets you add B third and close directly back to A.

To reuse another passenger route, select the target in **Routes**, choose a source
under **Copy route from**, then **Copy to draft** and review before **Apply**.
The source can be running; the target must be empty at the proposed first stop.
Its own name/train are retained, and nothing is purchased or spawned by copying.
See [route copying](ROUTE_COPY.md).

## A repeatable passing-loop example

Track reservations prevent overlap, but a passing loop alone does not guarantee
that shuttles can repeatedly share single-track station approaches. A train waiting
at a platform can conflict with another arriving train. Automatic signals should
keep arrivals outside the switch and station approach until departures clear it.
Do not place that holding boundary between the switch and platform: an arrival
could then wait on the switch and obstruct the departure.

This tested example uses A (4,8), B (20,8) and horizontal mainline track:

- Left switch **(8,8)**: west stem, east straight branch, south loop branch.
- Right switch **(16,8)**: east stem, west straight branch, south loop branch.
- Vertical tracks at x=8 and x=16, y=9–10; corners at **(8,11)** and **(16,11)**;
  horizontal loop track between them at y=11.
- Automatic signals on the main branch at **(9,8)** and **(15,8)**, and on the
  loop branch at **(8,10)** and **(16,10)**. Keep the switch-to-platform approaches
  in the same blocks as their respective stations.
- First train: **A–B Shuttle**, no waypoints (main branch).
- Second train: start at **B**, **B–A Shuttle**, waypoint **(12,11)** on B → A
  (loop branch, also used in reverse).

Both trains can deliver repeatedly. A red signal also limits track reservations
beyond it, so a waiting train cannot lock the switch needed by a departure.
Different layouts, shared origins, additional trains or poor signal placement can
still produce deadlocks; Traffic explains and supports physical reversal. Automatic
passing-loop selection, one-way signals and multi-platform stations remain planned.

## Fleet management

- **Replace route's train**: select a stored compatible train and choose an existing
  route. Its current train must have returned empty to the first stop. The route
  stays in place and the replaced train becomes stored.
- **Upgrade capacity / Upgrade speed**: independent purchases apply to the selected
  owned train, including additional service trains and stored spares.
- **Withdraw service**: finish the current round trip/lap and park empty at that
  route's first station. A parked train still occupies the platform.
- **Store & remove route**: after an additional service has withdrawn to its first
  station, remove the route and store its train. It releases its occupied track;
  the stored train can then be sold or reassigned. The two original services remain.
- Fleet, Routes and Traffic are scrollable and fit 200% UI scale. A station inspector
  lists all serving passenger routes and their incoming loads; manage individual
  trains in Fleet.

## Checks

```sh
godot --headless --path . --script res://tests/test_multiple_services.gd
godot --headless --path . --script res://tests/test_fleet.gd
godot --headless --path . --script res://tests/test_signal_integration.gd
```

Use separate XDG configuration/data/cache directories for headless tests on Linux;
these checks write saves. Godot 4.6.3 is used in the cloud. Check actual mouse
interaction in the Windows editor after pulling.
