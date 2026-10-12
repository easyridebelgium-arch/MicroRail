# Passenger coaches and log wagons

The first rolling-stock implementation supports up to four attached vehicles per
train. Passenger locomotives accept passenger coaches; freight locomotives accept
log wagons. Capacity and speed upgrades remain separate purchases.

| Stock | Purchase | Extra capacity | Speed limit | Extra running cost |
| --- | --- | --- | --- | --- |
| Passenger coach | £180 | 18 seats | 100 px/s | £1/s |
| Log wagon | £220 | 30 logs | 60 px/s | £1/s |

One locomotive is 28 pixels long. Each attached vehicle adds 32 pixels including
spacing, up to 156 pixels total. The reservation body is centred on the existing
train position. Vehicle positions follow the retained curve; reversing keeps each
vehicle at its route offset, with the locomotive able to propel the train on the
return trip. This is a basic reversible shuttle, not a shunting simulation.

## Try a coach train

1. Complete the horizontal Station A–B route. Keep it in **Shuttle** mode. A two-stop service is a good first test.
2. Extend horizontal straight track one cell past the outside of each endpoint:
   cell **3,8** behind Station A and **21,8** beyond Station B. The route itself
   already provides clearance toward the other station. One or two attached
   vehicles need these extensions; three or four need another cell at each end
   (**2,8** and **22,8**). Leave switches, bends and signals outside the full
   stopping area. This provides track clearance, not extra passenger platforms.
3. Pause and open **Fleet**. Select an empty train physically at its first stop,
   or a stored train. Choose the compatible stock and click **Attach wagon**.
4. Review capacity, length, effective speed and running cost, then close Fleet and
   resume. Watch coaches follow the track and the full body remain protected.
5. To change a moving consist, **Withdraw service**, resume until it is empty at
   its first stop, then pause. **Remove last of type** refunds half that vehicle's
   purchase price. Selling a stored train includes attached stock in its refund.

For freight, complete Forest–Terminal and extend straight track to **7,24** and
**29,24** for the first wagon. Larger consists need more straight clearance.
Stored passenger consists can start additional services on clear suitable stops,
and stored trains can replace existing service trains through Fleet.

## Safety and current scope

Startup, replacement, route edits and composition changes check both sides of
every stopping point. They refuse incompatible stock, insufficient money, excessive
length, loaded/moving edits and overlap with another train's reservations. A failed
edit spends nothing. Removing required clearance at a future destination stops the
train in place; repairing it lets the service resume. Occupied body tiles remain
protected from track removal.

The nose requests signal authority once, and switches/blocks remain protected
until the tail clears. Long-train requests use the same one-pixel scan resolution
as movement validation. Two-pixel lookahead previously skipped brief clearance
cells beside diagonal bends, stranding a coach train near switch 31,8 without a
real competitor. The whole-body protection remains conservative. Movement denials
now record the actual tile and owner (or missing authority), rather than falling
back to an unnamed train at -1,-1. Reservations rebuild normally on resume/load;
existing saves need no migration for this fix.

Save loading checks complete bodies for overlap even with
only the original passenger/freight pair. Composition is stored in save version
**23**; version 22 upgrades to single-vehicle trains through the existing migration
system. Unknown or incompatible stock is rejected before loading.

Consists now support **two- or three-stop Shuttle routes** with a continuous,
non-repeating track path. For example, A–B–C runs **A–B–C–B–A**: B is served on
both journeys, and the direction changes at A/C. Carriages retain their positions
across B's dwell and continue on the same curve. Independent passenger services
have the same support, including saved middle-stop dwell and physical turn-back to
the current leg's departure stop.

**Try it:** withdraw the service and let it return empty to its first stop, then
pause. Complete the track to C, keep straight signal-free stopping clearance at
A/B/C (one coach on a straight A–C line needs track from 3,8 through 37,8), and use
Routes to select Shuttle and order stops A, B, C. Apply, enable the service in Fleet
or resume it in Traffic, close the windows and resume simulation. Existing
waypoints remain supported when the full itinerary does not revisit any tile.
Capacity and fares still use the existing simple passenger queues; passenger
origin/destination demands come in Phase 2A.

Routes such as **A–C–B** fold back through already-used tiles and remain rejected
for carriage trains, as do **Loop** services. Those require continuous body routing
across planned reversals/loop wraps before being enabled. Formation templates, independent
wagon inventory, classes, tankers/boxcars and cargo-specific loading are later
features. Formal platform extensions, traction/power and yard operations are also
later; the current checker only verifies straight track and signal-free stopping
clearance. Speed purchases that attached stock would make ineffective are refused.

Tests: `test_train_length.gd`, `test_consists.gd` and
`test_consist_integration.gd` cover body protection, bounded stock validation,
pricing, service clearance, physical delivery/return, save/load, actual overlap
rejection, 200% UI scale and repeatable long-train movement at 30/60/120 FPS.

`test_long_diagonal_reservations.gd` reproduces diagonal/switch stalls at each
supported carriage count in both directions, using a signal and the same two-pass
authority allocation as the game. It also checks precise movement-denial records.

`test_multi_stop_consists.gd` covers all supported carriage counts fitting a
three-stop route, actual outward/return stops, full-body dwell ownership and vehicle
positions, signals, recovery to B, middle-stop/recovery save/load for primary and
additional services, and atomic refusal of folded/Loop routes. Save format stays v23.
