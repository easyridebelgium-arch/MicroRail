# MicroRail: your first 15 minutes

**Goal:** connect the stations, run passenger trains and earn enough to grow. Stations A, B and C are
already on the map in a row, and each ticket pays £5. You start with £1,000 and track costs £10 per tile.

## Minute 0–2: start and look around
- On the title screen choose a slot and **New game in selected slot**. The map starts paused.
  **Continue** opens your latest readable save; **Load game** and **Load previous save** recover a selected slot.
- Press **Space** to play/pause. Building, upgrades and amenities all need the game paused.
- Move the camera with **W A S D** or the arrow keys (hold **Shift** to go faster), drag with the
  **middle mouse button**, and zoom with the **mouse wheel**. **Home** resets the view.
- Check your **money**, **profit** and the **game clock** in the status bar. **Accounts** shows income, running costs and purchases. Press **G** to see your current objective.

## Minute 2–6: build track
1. Pick **Connect track** and drag from one station to the next. Bends, diagonals and platform approaches are automatic.
2. Prefer to steer? Use **Draw track**: hold the left mouse button and change direction as you go.
3. Mistakes: use **Undo** (paused only) or the **Remove** tool (**R**; also right-drag). A short right-click returns to Connect track.
4. Switches are added automatically at junctions. The **Switch** tool adjusts one by hand.
5. While dragging, the cursor callout shows track/switch cost, placement problems, refunds and affected services. Draft strokes show their own price; review the full plan in **Overlays**.

## Minute 6–9: make a route
1. Open **Routes**. Give the service a name, choose its mode (**Shuttle** goes back and forth, **Loop** circles) and add stops in order.
2. Leave each stop's platform on **Auto**. The game chooses a platform when applying the route and can choose a free destination platform before departure; it does not switch platforms while approaching.
3. Press **Apply**. If the route is not connected, the editor says what is missing.
4. While paused, choose a short route label and colour, then **Apply appearance**. This is separate from applying route instructions.
5. Open **Fleet** to buy, name or assign more trains.

## Minute 9–12: run a train
1. Press **Space** to resume and use **1 to 4** to choose a speed (1×, 2×, 5×, 10×).
2. Click a station and make sure passenger service is enabled. Click a train to inspect where it is going.
3. Passengers wait per final destination. A–B plus B–C lets C-bound passengers
   change at B; a direct A–C service is preferred. The oldest eligible riders board
   first. Click a station to see connections, oldest waits and **Waiting satisfaction**.
   **Accounts** explains the company score; more useful service reduces waits, and
   amenities add a small comfort bonus. The station's **Demand response** shows how
   arrivals gradually adapt (50–125%); growth needs actual boarding evidence. Train inspectors show tracked elapsed
   journeys; **Accounts** shows completed trip times, including transfers and recovery.
4. If a train stops, open **Problems** (toolbar) to see why, or use the alert banner's **Inspect**. **Acknowledge** hides that alert while keeping the problem visible.
5. Signal letters mean S = manual stop, H = current held request, R = reserved tile, A = automatic/unrequested. The train inspector explains actual permission to move.

## Minute 12–15: spend your first profit
1. **Pause**, then click a station.
2. Buy **Train capacity** (more seats) or **Speed**.
3. Build an **amenity** at a busy station: Shelter (£300, waiting limit +50, arrivals +5%),
   Waiting room (£700, needs a Shelter, +100 and +10%) or Kiosk (£400, +25 and +10%).
4. Use **Save game** in the toolbar. There are four slots, with map/time/balance previews.
5. To return to startup, use **Settings → Return to title screen (save first)**.

## Next steps
Short of cash? **Accounts → Bank loans** offers £1,000, £2,500 or £5,000 at 1% interest per game hour, repaid in ten hourly instalments (see [loans](LOANS.md)). Borrow while paused, and repay early if you can.

Add a second train in **Fleet**. Then try **headway** (minimum gap between trains) or a **timetable** in the
route editor, and **signals** where trains share track.

---

# Controls reference

| Action | Control |
|---|---|
| Pause / resume | **Space** |
| Speed 1×, 2×, 5×, 10× | **1, 2, 3, 4** |
| Move camera | **W A S D** or arrow keys (**Shift** = faster) |
| Pan / zoom | middle mouse drag / mouse wheel |
| Reset camera | **Home** |
| Fullscreen | **F11** |
| Cancel | **Esc** |
| Network map | **M** |
| Objectives | **G** |
| Inspect trains and stations | **I** |
| Event log | **L** |
| Remove-track tool | **R** |
| Connect track | left-drag between two points |
| Draw track | hold left mouse and change direction |
| Remove track | left-drag with Remove, or right-drag/hold |
| Back to Connect track | short right-click |

| Button | What it does |
|---|---|
| **Switch** | click track to add a switch; click again to change shape; last click removes it |
| **Signal** | click straight track: automatic block signal, then manual stop, then remove |
| **Routes** | name services, mode, stops, waypoints, platforms, links, headway, timetable |
| **Fleet** | buy, name and assign trains |
| **Problems** | what is waiting, blocked or deadlocked; searchable history |
| **Find** | search trains and facilities; pin a watchlist |
| **Traffic** | inspect blocked trains; reverse one in a deadlock |
| **Undo / Redo** | paused construction only; cleared when play resumes |
| **Accounts** | company income, running costs, purchases and the **Bank loans** offers |
| **Save game / Load** | four save slots |
| **Settings** | interface scale, colours and key bindings |

Upgrades, amenities and undo only work while paused. Keys can be changed in **Settings**. Settings also offers optional slowdown from 5×/10× to 1× on new traffic waits, deadlocks or overdue payments.

Hover toolbar controls for their action and description. Relevant shortcuts and
mouse controls follow your current Settings bindings; this reference lists defaults.

## Check whether your trains need more seats

Click a passenger train and compare **Seats occupied** with its recent occupancy
and eligible passengers left behind. Open **Accounts** for company and station
figures. People whose destination is not served by that departure do not count as
capacity denials. The boarding count represents opportunities, so repeated full
departures may count the same person again. Recent measurements restart on load.
See [occupancy feedback](PASSENGER_OCCUPANCY.md).

## Set and measure an arrival target

Pause and open **Routes**, choose a departure direction under **Timetable**, set
**Journey target (0 = off)** in game minutes, then **Apply**. Set each return
direction separately. Click a moving train for its current target; Routes and
Accounts show completed punctuality. A daily timetable uses scheduled departure
plus the budget; an unscheduled direction uses actual departure. Targets report
performance without changing fares or safety rules. See
[arrival targets](ARRIVAL_TARGETS.md).

Routes now shows approximate free-running travel time below the timing controls.
Check this against your target, especially for linked trains with different speeds.
Add margin for traffic and departure delays. Routes and Accounts also break down
punctuality by direction, separating running time from scheduled departure delay.
No measured arrivals means there is no result yet.

## Serve Express passengers

Station Details now splits waiting people into Local and Express. Express demand
appears gradually between A and C. Set a service to **A–C** to carry both classes;
**A–B–C** carries Local passengers while Express keeps waiting. A waypoint or
passing loop is allowed; a station call at B prevents Express eligibility.
Routes shows eligibility for the selected direction, and clicking a train shows
its onboard class counts. Both classes currently pay £5 at their final destination.
See [passenger classes](PASSENGER_CLASSES.md).
