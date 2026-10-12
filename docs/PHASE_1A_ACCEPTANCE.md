# Phase 1A acceptance coverage

This maps the proposed network-integrity checklist to the current prototype. It
records implemented scope and regression evidence, not a proof that every possible
layout is safe. Extend it when directional signals, priorities, platforms and new
body-routing combinations become supported. Tests apply to the current engine/build;
fixed-tick FPS comparisons do not establish cross-version replay compatibility.

| Acceptance area | Current coverage and remaining scope |
| --- | --- |
| Entry/exit ports and invalid geometry | `test_junctions.gd`, `test_service_routes.gd`, `test_waypoint_router.gd`: targeted port, stem/exit, crossing and waypoint approaches. Switch route choice can set a free switch; its current free setting is not a permanently closed graph port. Exhaustive enumeration of every supported geometry/approach is a further coverage improvement. |
| One-way invalid approaches | Planned: one-way signal/waypoint restrictions are not implemented. Do not mark these tests passed based on bidirectional routing. |
| Reversal inside a junction | `test_train_length.gd` now checks a parked long body reversing at a switch retains its body ownership and selected movement lock. `test_deadlock_integration.gd` covers physical recovery on retained paths. More multi-junction/curved-body cases accompany continuous consist routing. |
| Protected destructive edits | `test_switch_tool.gd`, `test_planning_integration.gd`, `test_construction_plan.gd`, `test_corridor_integration.gd`: occupied/reserved changes are refused; an unsafe draft application is rejected atomically while its preview remains available. Protect actual body/authority, not every unreserved tile of a running route. |
| Broken unreserved routes | `test_stopped_routes.gd`, `test_directional_routes.gd`, `test_consist_integration.gd`: trains remain physically in place when required track/clearance is broken ahead; gaps behind need not interrupt the current trip. This intentional edit behaviour remains supported. |
| Graph/render separation | Track/switch/route drawing derives from authoritative dictionaries or separate draft previews. Geometry/routing/serialization have regression checks; full graphical regression remains a separate manual/visual check. Ghost previews never grant real movement. |
| Claiming switch locks and player protection | `test_reservations.gd`, `test_switch_tool.gd`, `test_train_length.gd`: selected stem/exit protection and ownership prevent incompatible movements/edits. A lock is represented by ownership maps; no additional `is_locked` flag is required. Reserving an unrelated part of a connected block does not indiscriminately lock every switch. |
| Head-on approaches | `test_reservations.gd`, `test_deadlock_integration.gd`: no body overlap and stable permanent-ID ordering. Existing occupancy takes precedence over future claims. A single-track standoff may safely stop both trains; it cannot always grant an end-to-end route to one train without escape infrastructure. |
| Converging approaches | `test_reservations.gd`, `test_multiple_services.gd`: contention, selected switch movements, configured passing loops and safe yielding. Spawn order/service priority is not the current rule: lower permanent train ID is first. |
| Release after rear clearance | `test_train_length.gd`: tail retains switch/block protection, then releases it. Rebuild at the next fixed allocation tick; retain a lock while any body or still-valid route request needs it. |
| Authority versus occupancy versus locks | Separate occupancy/owners/switch owners exist. `test_train_inspector.gd` checks separate physical body, allocation, requested/granted blocks and locks. Future authority is labelled as such, not falsely called physical occupancy. |
| Precise waiting reasons | `test_problems_integration.gd`, `test_train_inspector.gd`: manual signals, actual blockers/cycles, loading, dwell, holds, incomplete track/clearance and stale samples. Higher-priority-service denial waits for an actual priority system. |
| Signal presentation | Current symbols show automatic (`A`, circle) versus manual stop (`S`, square); they are not directional red/green aspects. A future aspect display must consume committed authority and cannot grant movement independently. Colour alone is never the cue. |
| Circular waits and threshold | `test_deadlock_monitor.gd`, `test_deadlock_integration.gd`: sustained actual wait cycles are confirmed after three simulation seconds, with deduplicated events and fixed-tick FPS comparisons. |
| Cycle diagnostics | `test_train_inspector.gd`: full cycle IDs, named blocker/service and conflict cell or block when known. Do not fabricate a specific junction when evidence only identifies a track tile. |
| Hold selected train | `test_deadlock_integration.gd`: dispatcher hold is explicit. It keeps physical occupancy protected; holding alone cannot be promised to resolve a circular wait. |
| Physical turn-back recovery | `test_deadlock_integration.gd`, `test_stopped_routes.gd`: reverse in place on the retained route and physically return to the departure stop. Returning only to a previous cleared signal/siding and validated alternative escape routing remain planned. |
| Post-recovery integrity | Existing recovery tests check position/load preservation, safe movement and save/load. Ownership is rebuilt normally and passed tiles release; never reset all locks while a train still physically occupies them. Extend multi-platform/body boundary cases as those systems arrive. |

The next expansion of this checklist follows Phase 1B: continuous long-body routing
across intermediate reversals/Loops, usable platform lengths, multiple platforms and
safe multiple trains per service. Service priorities and directional signals get
explicit new criteria when implemented.
