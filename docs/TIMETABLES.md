# Game clock and directional departure timetables

One game day is 24 real minutes at 1×: one game minute per simulated second.
The clock starts at 06:00 on Day 1, follows simulation speed, pauses with the game
and is saved with the simulation tick. The header displays day and HH:MM.

## Set a timetable

1. Pause and open **Routes**. Select the source passenger service. Linked trains
   follow that source's timetable; unlink first to set an independent schedule.
2. Under **Timetable**, select a departure direction, such as **Depart A → B**,
   **Depart B → C** or **Depart B → A**.
3. Enter daily departure times: `06:15, 06:30, 18:15`. Up to 48 sorted, unique
   times per direction are supported. Empty text disables only that direction.
4. Press **Apply**, close Routes and resume. Time changes can apply without
   changing the route geometry or moving the train.

Shuttles offer separate return directions. Loops offer the closing last-to-first
leg. A three-stop A–B–C Shuttle therefore has A→B, B→C, C→B and B→A schedules.
Unscheduled legs leave normally after dwell. Existing first-stop timetables keep
working; they remain in `timetable`, while later directions use `stop_timetables`.
Removing/reordering stops or changing mode warns when later-direction tables no
longer belong to a valid leg. Route copying also copies departure schedules.

## Operating rules

- Never early: after normal dwell, hold at the stop until an unused departure
  time is due. The inspector names the direction and the next day/time.
- Timetable holds do not request lookahead movement authority and are excluded
  from measured traffic waiting. Physical body protection stays in place.
- Signals, occupancy, switch locks, dispatch holds and route integrity still
  govern movement. A due time never overrides network safety.
- Count a departure only when the train actually moves away from its stop,
  not when boarding begins. A blocked train does not consume a departure slot.
- Late trains use the latest unused due time when they can move. Earlier unused
  times in that gap count as missed. No lateness penalty is charged yet.
- Linked trains share one cursor per direction. The normal deterministic service
  update order chooses departures; a used slot cannot be used by another train.
- First-stop headway and timetable requirements both apply. Later stops use their
  directional timetable, without adding those departures to the origin headway.
- Manual recovery bypasses the timetable but continues to obey movement safety.
- Editing a direction's times resets that direction's measured history and starts
  at the current clock minute. Unchanged schedules retain their progress.

Routes reports served/missed departures per direction and average/last delay in
**game minutes**. The recent average covers at most the latest 24 measured
departures. First-stop frequency feasibility remains a rough minimum based on
round-trip travel/dwell and fleet size; it does not forecast junction congestion
or promise that arbitrary later-stop combinations are attainable.

## Saves and remaining work

Save version **24 and later** stores timetable cursors, counts/recent delays and origin
headway history. Loading preserves served slots and exact train positions.
Version 23 and supported earlier saves migrate with empty dispatch history; their
schedules remain and begin monitoring from the loaded clock time. The complete
save, including bounded numeric dispatch data, is validated before any world
state is changed.

Optional [directional arrival targets and basic punctuality](ARRIVAL_TARGETS.md)
are implemented in version 34, using each served departure slot as their baseline.
Passenger satisfaction effects, freight contract bonuses/penalties
and timed transfers remain future work. They require actual passenger destinations,
contracts and reliable demand/arrival measurements. Weather/art preparation does
not change the simulation clock or departure rules.

Code: `scripts/core/timetable.gd`, `Main._scheduled_departure_hold`,
`Main._record_departure`. Tests: `tests/test_timetable.gd`,
`tests/test_stop_timetables.gd`, existing headway/network/save suites.
