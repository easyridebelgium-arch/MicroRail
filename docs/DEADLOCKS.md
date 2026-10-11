# Deadlock detection and emergency recall

The reservation layer prevents collisions. A deadlock monitor now detects when
trains are **actually stopped** waiting on each other for three simulation seconds.
It uses a directed graph of permanent fleet IDs: each stopped train points to the
train blocking its movement. A cycle is confirmed only while all its waits stay
continuous. Planning lookahead, loading, station dwell, and waiting on a single
parked train are not cycles.

Confirmation produces one `DEADLOCK_DETECTED` event and changes the toolbar button
to **Traffic (1)**. Continuing to wait does not produce an alert every tick.
Clearing a confirmed cycle produces `DEADLOCK_CLEARED`; successful recovery also
records `TRAIN_RECOVERED` with the permanent train ID.

## Player recovery

1. Open **Traffic**. The game pauses and the window lists involved trains and
   their reservation waiting reasons.
2. Select a train in the confirmed cycle and press **Recall selected train**.
   The button itself is the explicit recovery action; closing/cancelling the
   window does not recall anything.
3. Recall checks the entire first-stop footprint against current ownership.
   If another train occupies or locks it, recall is refused without changing
   train positions, service state, passengers, cargo or money. Try the other train.
4. A successful recall represents off-track emergency transport to the first
   stop. It does not drive or reverse through reserved track. The recalled service
   is disabled and will stay there after you resume.
5. Passenger riders return to their last departure queue, without a ticket payout.
   Returned passengers can temporarily exceed the normal waiting capacity; new
   passenger generation does not discard that overflow. Freight logs remain on
   the recalled train; recall neither adds them to industry storage nor delivers
   them. Cargo is transported normally after you enable that service again.
6. Close Traffic and resume so the other train can clear. When ready, pause,
   open **Fleet**, select the recalled train and **Enable service**. A repaired
   layout or better operating order is needed to prevent the same incident again.

Recall is free in this prototype. There is no hidden delivery income, cargo loss
or permanent train sale/replacement. A train that is not part of a confirmed
cycle cannot be recalled through this action. Running recovery is refused.

## State and limits

Saves remain **v18**. Position, cargo, queues and stopped-service flags already
exist in that schema and preserve a completed recall. The wait graph and its
confirmation timer are transient; after load, a persistent cycle is rediscovered
once trains actually wait for three simulation seconds again. Pausing does not
advance that timer. Changing a service path clears stale traffic incidents.

This is the first safe recovery mechanism, not automatic dispatch. It does not
choose passing loops, back a train into a siding, change priorities, or add block
signals. A recalled train's first stop can itself block a shared route. Traffic
also shows ordinary waiting reasons, but one train held by a parked train is not
labelled a deadlock: enable/move that parked train or adjust its service. Signals,
manual holding and route-aware rerouting are subsequent work.

## Verification

```sh
godot --headless --path . --script res://tests/test_deadlock_monitor.gd
godot --headless --path . --script res://tests/test_deadlock_integration.gd
```

The monitor tests check continuous confirmation, interrupted waits, single waits,
multiple cycles and event deduplication. Integration tests use real shared-track
passenger/freight routes and their movement hooks, and check collision prevention,
matching detection/positions/money/events at 30/60/120 FPS, occupied-destination
refusal, both recovery choices, passenger/cargo conservation, existing save/load,
resumption of the other train, and the Traffic window at 200% UI scale.

Manual checks: provoke a head-on meeting, wait three simulation seconds, recall one
train through Traffic, resume, then re-enable it in Fleet. Try closing Traffic
without recalling, and save/reload before and after recovery. Check the event log
and Reservations overlay to verify the status and ownership agree.
