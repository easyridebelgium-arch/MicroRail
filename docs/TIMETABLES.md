# Game clock and timetables

## Game clock

One game day is 24 real minutes at 1× speed: **one game minute per simulated second**
(`Timetable.TICKS_PER_MINUTE = 60`). The clock starts at 06:00 on Day 1, speeds up with
game speed, pauses with the game and is saved with the simulation tick (no save-format
change). It is shown in the header ("Day 1  06:42").

## Timetables

A route can have exact **departure times** from its first stop, entered in Routes
("Timetable": `07:00, 07:30, 18:15`; up to 48, sorted and unique). Like headway it belongs
to the source service of a [linked group](ROUTE_COPY.md).

- **Never early:** a train waits at the first stop, before boarding, until a scheduled time
  has passed that no departure has used yet ("Holding for timetable: next departure
  07:30"). A timetable and a headway target can both apply; the train waits for both.
- **Late trains** leave at once and use the latest scheduled time that has passed. Any
  earlier unused times in that gap count as **missed**.
- **Punctuality:** Routes reports served and missed departures and the average and last
  delay in game minutes (`Main.timetable_report`).
- **Infeasible tables:** the closest two departures are compared with what the group's
  trains can deliver (round trip ÷ trains, as for headway); Routes explains how many
  trains are needed. Note that a game minute equals a simulated second, so the headway
  seconds and timetable minutes use the same numbers.
- **Not saved:** served/missed counts and the departure log reset on load; the schedule
  itself is saved with the service.
- **Not yet:** timetables at later stops, early/late effects on passenger satisfaction and
  freight contracts, timed transfers.

Code: `scripts/core/timetable.gd` (pure rules), `Main._timetable_hold`, `_record_departure`.
Tests: `tests/test_timetable.gd`.
