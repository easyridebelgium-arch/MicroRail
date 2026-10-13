# Passenger waiting satisfaction

This Phase 2A increment measures the station waiting experience. Click a passenger
station for its rating, average measured wait and causes. **Accounts** shows the
company rating and the same detail for all stations. Both use words and numbers,
independent of palette colour.

## How the rating works

Each current waiting group and each of the last 128 boarding groups at a station
has a score from 0–100. The first 15 simulation seconds incur no penalty. Each
complete additional 3 seconds subtracts 1 point, capped at 90 points. Add comfort:

| Facility | Comfort points |
| --- | ---: |
| Shelter | +3 |
| Waiting room | +5 |
| Kiosk | +2 |

The result is clamped to 0–100. A 45-second wait without amenities scores 90.
Very long waits score 10, or at most 20 with all amenities: comfortable facilities
help, but cannot replace useful service.

Station and company ratings are weighted by passenger count. The average wait
uses these same experiences. Current queues age with the fixed simulation clock;
pause stops ageing and accelerated play speeds it up. Unserved destinations still
count, so ignoring a queue cannot improve the result. Empty queues/history show
**no data yet**, rather than an invented rating.

Boarding records the actual number accepted from each age group and its measured
wait. Partial boarding keeps the remaining riders' original arrival time.
Historical comfort is the bonus present when the group boarded; buying a facility
improves current/future experiences without rewriting earlier scores. History is
bounded separately for each station, so one busy station does not erase another's
record. When old groups leave that window, better new service can lift the rating.

Transfers and physical recovery start a new station wait on arrival. A passenger
who changes trains can therefore contribute more than one station experience.
This rating covers station waiting, not unique passengers' complete journey time.
Onboard delays, crowding, timetable punctuality, classes, fares and company
reputation are not measured here. Existing amenities retain their published
capacity/demand effects. Waiting-based demand response is now implemented as a
separate, bounded factor;
see [demand response](DEMAND_RESPONSE.md). Fares, movement and reservations remain
governed by their existing systems.

## Improve the result

Check station destination queues and connection availability. Increase usable
seats or frequency, add the missing connection, repair broken track, or resolve
signal/deadlock bottlenecks. Amenity comfort gives a small, explicit bonus.
A high score does not guarantee free track or an on-time arrival.

## Saves and validation

Save version **31** persists the bounded boarding history, alongside version-30
arrival groups. Version 30 migration keeps every queue age, count and train
position and starts history empty; previous experiences are unknown. Ratings
recompute from the saved history and live queues. Failed loads validate counts,
timestamps, wait duration and comfort bounds before applying state.

`test_passenger_satisfaction.gd` exercises the formula, live unserved queues,
partial boarding, amenity snapshots, bounded history, invalid records, game hooks,
atomic save/load, migration, Accounts at 100/150/200% scale and 30/60/120 FPS
(28 checks). Existing destination, transfer, fairness, withdrawal, consist,
signalling and save suites remain regression requirements.
