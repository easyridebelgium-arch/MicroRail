# Planned reversals for carriage trains (Phase 1B)

A service can now reverse at an **intermediate stop** even when it pulls carriages.
For example, stops **A, C, B** run A → C, reverse at C, retrace toward B, and the
Shuttle then returns B → C → A. Previously such routes revisited track and were
refused for any train longer than one vehicle.

## How the train behaves

The train is a rigid formation that keeps its physical orientation: the
locomotive propels on the return, exactly as at the end of an ordinary Shuttle.
At the reversal point the **tail becomes the lead**; no vehicle jumps, passes
through another, or changes order.

- While the train stands at the reversal stop, part of its body lies on the
  straight track *beyond* the stop. That track is owned and protected like the rest
  of the body, and must already be built (the usual straight, signal-free stop
  clearance rule, checked on both sides).
- After the train leaves, the vehicles that were beyond the stop clear that
  extension while the others follow along the retraced leg. Switch locks and signal
  blocks stay held until the last vehicle clears, as for any long train.
- Signals, manual stops, reservations and waiting explanations work on the retraced
  leg exactly as on any other leg (`test_reversal_signals.gd`).
- Loading, dwell, save/load and the physical recovery reverse are unchanged.

## What is accepted

| Route | Single vehicle | Carriage train |
| --- | --- | --- |
| Straight A–B–C | yes | yes |
| Planned reversal at a stop (A–C–B) | yes | **yes (new)** |
| Several reversals, each leg longer than the train plus 32 px | yes | **yes (new)** |
| Reversals closer together than a train length plus 32 px | yes | refused with an explanation |
| A leg that revisits its own tiles without reversing | yes | refused ("revisit") |
| Reversal that is not a straight retrace out of a stop | yes | refused |
| Loop with a reversal | yes | refused (a Loop must be a continuous circuit) |

The leg-length rule exists because a body must never span two reversals at once.
With three stations only one reversal is possible; the multi-reversal rule is
exercised by `test_fold_bodies.gd` and becomes reachable with more stations.

## Implementation

`RouteBody.folds(path)` finds the reversal points of a retained path (cached on the
path and recomputed if its length changes) and
`RouteBody.body_pose(path, distance, offset)` places each vehicle:

- after an odd number of reversals the offset is mirrored;
- a vehicle that would lie beyond the nearest reversal sits on the straight
  extension past that stop, facing the direction of travel.

Reservation footprints, signals, drawing and hit-testing all use this one
function; without reversals it equals the old `pose(path, distance + offset)`.
No save fields changed (saves stay **v23**); the folded route is rebuilt from its
saved cells as before. `Consists.route_shape_error` holds the acceptance rules.

## Checks

`tests/test_fold_bodies.gd` (geometry, rigid formation across the reversal,
ownership, route rules), `tests/test_planned_reversals.gd` (a three-carriage train
completes A–C–B–C–A with the body always owned, rigid and spaced, plus save/load
at the reversal and just after it) and `tests/test_reversal_signals.gd`.

## Not yet implemented

- Figure-eight circuits and other routes that revisit track without reversing.
- Reversals that diverge through a switch *within* the body length of the stop
  (the stop clearance rule keeps the area around the stop straight).
- Planned reversals for Loop routes and for freight trains.
- Automatic platform choice at arrival and platform-aware reservations (next).
