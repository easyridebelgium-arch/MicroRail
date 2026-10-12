# Headway controls

A route can have a **target headway**: the minimum number of seconds between two
departures from its first stop. Set it in Routes ("Target headway", 0 = off). It belongs
to the source service of a [linked group](ROUTE_COPY.md), so every train on the route
shares it; linked services show no field of their own.

- **Rule:** a train waits at the first stop, before boarding, until the target has passed
  since the last departure of *any* train in its group. The wait is shown as "Holding for
  headway: N s until the next departure" in the train status and inspector.
- **Measurement:** departures are logged per group (`Main.headway_log`, last 24); Routes shows
  the last and average actual interval (`Main.headway_report`). The log is not saved; after
  loading, the first departure is free and measurement starts again.
- **Infeasible targets:** `Headway.infeasible_reason` estimates one round trip (out and back for
  Shuttle, once round for Loop, plus every station wait) and compares the target with
  round trip / number of trains. A target below that is explained in Routes ("needs about N
  trains"); it is still applied, and trains simply depart when they are ready.
- **Platforms:** a waiting train occupies its first-stop platform. Give the first stop a
  second platform and set it to **Auto** so an arriving train can use it; otherwise an
  arriving train waits outside until the held train leaves.
- **Not yet:** exact departure times, per-stop headways and satisfaction effects
  (Phase 2 timetables).

Code: `scripts/core/headway.gd` (pure rules), `Main._headway_hold`, `_record_departure`.
Tests: `tests/test_headway.gd`.
