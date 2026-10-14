# End-to-end passenger journey times

A new passenger group keeps its original station and queue-arrival tick until it
physically reaches its final destination. Boarding another train, changing at an
interchange, travelling through a stop or reversing to the departure station does
not restart that journey clock.

## Where to see it

Click a train: its inspector shows how many onboard passengers have tracked
origins and the oldest tracked elapsed journey. **Accounts** shows average and
longest completed journey time, the number of measured passengers and breakdowns
such as **A → C**. Empty trains and histories are identified explicitly.

The completed statistics use the latest 128 completed groups, weighted by passenger
count. They are recent statistics, not an all-time average. One group can contain
several passengers with the same origin, destination and starting tick. The longest
value is the longest measured duration within that retained window.

Elapsed time includes initial waiting, onboard travel, dwell, traffic delays,
interchange waiting and physical recovery. It advances with simulation ticks;
pause freezes it and accelerated gameplay advances the same rules. These are
simulation seconds, consistent with the existing waiting diagnostics.

## Transfers and recovery

For A–B plus B–C, A→C riders keep A and their original start time aboard both
trains. At B they acquire a new **station queue arrival** for fair boarding and
station waiting satisfaction, while retaining their separate **journey start**.
Partial boarding splits counts without changing the source clock. A physical
turn-back and reboarding work the same way. Queues can overflow during recovery
without discarding either passengers or their metadata.

A completed time is recorded only at the final destination. Transfers and recovery
are unfinished journeys. Delivered counts and fares still increase once, at the
actual destination; timing is observational and does not create movement authority,
change routes or impose a new satisfaction/fare penalty. Waiting satisfaction and
gradual demand response retain their existing station-experience rules. Arrival
punctuality requires planned arrival targets before it can be scored.

## Saves and legacy data

Save version **33** adds origin/start metadata to waiting groups, per-service
onboard journey groups, bounded completed history and an unmeasured-delivery count.
Metadata totals must match the existing authoritative destination counts. Invalid
counts, origins, future clocks, impossible chronology or excess completed records
reject a load before applying world state.

Version 32 preserves its passenger counts, station queue ages, physical positions,
waiting satisfaction and demand factors. Its original journey origins are unknown,
so existing queues/onboard groups and old delivered passengers are marked
unmeasured. No complete-trip duration is invented from a station-wait timestamp.
New random arrivals after migration are fully tracked. Saving and loading current
tracked journeys preserves their original start and active train position.

## Validation

`test_journey_times.gd` covers partial boarding, connection queues, both actual
train runtimes, save/load, physical reversal/recovery/reboarding, final-only fares,
origin-destination display, corrupt-load atomicity, legacy migration and identical
30/60/120 FPS results (29 checks). Existing destination, fairness, demand response,
consist, signalling and save suites remain regression requirements.
