# MicroRail development roadmap

This roadmap records the agreed development order, current implementation and
remaining work. Phases are milestones, not release dates. Preserve completed work
when regrouping features; an implemented feature in a later phase does not need to
be removed or rebuilt. Godot and GDScript remain the core development tools.

## Current position

| Milestone | Current status | Work still needed to close the milestone |
| --- | --- | --- |
| Phase 0 — Foundations | Implemented; requirements remain active for every update. | Continue deterministic, save and accessibility checks. Full input replay/controller support are later extensions. |
| Phase 1A — Network integrity | Core implemented and covered by regression tests. | Broaden safety coverage as new platform/body combinations arrive; preserve basic waiting explanations throughout. |
| Phase 1B — Service operations | Partially complete. | Other repeated-path body routing (planned reversals at stops and crossing figure-eights are done), arrival-time platform switching (lengths, numbering, assignment rule and fixed per-stop sidings exist). Linked services (several trains per route) are done. |
| Phase 1C — Planning and feedback | Substantial functionality implemented; milestone incomplete. | Evidence-based structural warnings, alert acknowledgement/persistence and optional incident slowdown. Unified waiting inspection is implemented. |
| Phases 2A–2C — Demand, freight chains and growth | Phase 2A demand foundations implemented; Phases 2B/2C planned. Direct log delivery already exists. | Direct destination journeys and frequency/timetables implemented; waiting-area/amenity upgrades, transfers, satisfaction, processing chains and growth/scenario rules remain. |
| Phases 3–5 — Maintenance, progression and community | Mostly planned; some building/sharing tools already exist. | Add systems only when their prerequisites and player-facing benefits exist. |

**Latest usability update:** four independent manual game slots with separate backups,
a slot chooser and fresh-game action are implemented; the existing save is Slot 1.
See [save slots](SAVE_SLOTS.md). Periodic autosaves remain Phase 2C work.
Toolbar refinement instructions are in the [Krita guide](../assets/ui/toolbar/KRITA_GUIDE.md).

**Next implementation:** Phase 2A passenger transfers and satisfaction (waiting-area amenities are done); demand
factors follow. Direct passenger
origins/destinations, per-destination queues, through riders and destination-only
fares are now implemented; see [passenger destinations](PASSENGER_DESTINATIONS.md).
Directional departure timetables remain implemented. Arrival targets, contract
penalties and timed transfers follow their demand/contract prerequisites.
Phase 1B remains complete for supported route/body combinations; the refused
repeated-path cases and in-motion arrival-platform changes remain deferred. Automatic platform
choice is done at Apply time (the editor's "Auto" option; see [platforms](PLATFORMS.md)); choosing
a different platform at arrival time, while the train is moving, remains optional later work and
must preserve the physical body and its route behind the train.
Services can already be assigned a fixed platform per stop in Routes (trains drive onto switch-connected sidings). Platform lengths, stable numbered platforms (1 = stop track,
2 = siding below, 3 = siding above) and the assignment rule are implemented and shown in the station panel;
see [platform lengths](PLATFORMS.md). The unified why-waiting inspector (Phase 1C) is now implemented; see
[train operating inspection](TRAIN_INSPECTOR.md). Completed Phase 1C
tools remain available while Phase 1B gaps are closed; Phase 1 overall is not yet
complete. The latest cloud validation passed all 73 headless suites in Godot 4.6.3,
including the uploaded PNG ribbon, action bindings, selected/disabled states,
keyboard focus, live counters and wrapping at 100–200% UI scale, plus directional
departures, blocked-departure accounting and version-25 destination/dispatch save/load, passenger conservation and four independent manual slots. Earlier gameplay
updates were also tested in Godot 4.7.stable.
Tests that change player preferences must
restore them: a leftover pause-on-deadlock setting once made the deadlock suite fail on
repeat runs, and both suites now isolate/restore it; see the regression checks and acceptance coverage below.

**Presentation checkpoint:** the approved PNG toolbar pack is integrated into existing
controls, with live speed/Problems text, nearest-neighbour display, accessible names,
keyboard focus and a non-colour selected underline. Source files are preserved and usable while the artist refines margins in Krita.
The existing pressed-button surround is handled at display time; no art refinement
is required to continue gameplay development. See
[toolbar graphics](../assets/ui/toolbar/README.md). This presentation update does not
advance or reorder the gameplay milestones above.

**Amenities checkpoint:** stations can buy a Shelter, Waiting room and Kiosk. Each raises that
station's waiting limit and passenger arrivals by a small, saved percentage (save version 26); see
[station amenities](STATION_AMENITIES.md). Transfers and satisfaction are next.

**Rename checkpoint:** the project is now **MicroRail** (formerly "Trainz", a name already in use by another
game). Project name, window title, docs and save filenames (`microrail_save*`) are renamed. On first launch
`LegacyMigration` copies saves and settings from the old `Trainz` user-data folder into the new `MicroRail`
one (copy only, never overwrites, old folder left intact); see [save slots](SAVE_SLOTS.md). All 75 headless suites pass (run `godot --import` once after a fresh clone).

**Resume checkpoint:** maximized startup, adaptive window filling and saved
fullscreen (Settings/F11) are implemented and confirmed working by the player.
One piece is built per drag step; short right-click restores Connect track and
right-drag/hold removes track (R also selects Remove). Junction switches are
created automatically on both departure and arrival, including merges onto end
tiles and compatible curves, with validated costs and grouped Undo/Redo.
Platform length measurement is implemented (`scripts/core/platforms.gd`, station
panel line, `tests/test_platforms.gd`, `tests/test_platform_ui.gd`). Platform IDs, multi-platform detection
from parallel sidings and `Platforms.assign` are also implemented; the assignment rule is not yet
used to choose an arrival automatically. Services can be given a fixed platform per stop in the Routes editor
(`ServiceRoutes.stop_cell`, `platforms` in each service, `tests/test_platform_routes.gd`; the first stop's
platform is fixed). Routes now copies another passenger service’s instructions into the selected service’s
editable draft, preserving its name and train and validating the existing safe edit point
on Apply; see [route copying](ROUTE_COPY.md). Vanished waypoint legs produce an explicit
draft warning. Drag reordering and Fleet "Copy of …" service duplication are done (see [route copying](ROUTE_COPY.md)). Auto stops re-route to a free platform when a train leaves its previous stop (`Main._maybe_reroute_platform`, `tests/test_platform_reroute.gd`). Single-track holds stop head-on lockups between stops (`SingleTrack`, `tests/test_single_track_holds.gd`; see [platforms](PLATFORMS.md)). Automatic platform choice (`Platforms.choose`, `Main._resolve_auto_platforms`, `tests/test_auto_platforms.gd`)
is implemented; wait messages and the station panel name platforms. Continue
Phase 1B with figure-eight/repeated-path body routing. Multiple trains per route are done as linked services (Fleet "Linked to …", see [route copying](ROUTE_COPY.md)). Carriage trains can now reverse at intermediate stops
(`RouteBody.folds`/`body_pose`, `Consists.route_shape_error`, `tests/test_fold_bodies.gd`,
`tests/test_planned_reversals.gd`, `tests/test_reversal_signals.gd`); platform selection must keep
the tail's route and the extension past a reversal stop intact. Figure-eight routes that cross themselves at a crossing tile now work for carriage trains ([Loop consists](LOOP_CONSISTS.md)); other revisits (same line twice, shared ordinary track or switches) remain refused.

## Current foundation

- Mouse-drawn tracks with automatic bends, diagonals and a straight first extension
  tile when departing existing rails.
- Construction costs, drag demolition and paused construction Undo/Redo.
- Short right-click returns active tools to Connect track; right-drag/hold removes
  track. R/Remove also selects left-drag removal.
  Track laying adds correctly oriented switches automatically, including the
  switch price in preview/drafts; see [automatic junctions](AUTOMATIC_SWITCHES.md).
- Direct passenger destinations, per-destination queues and through riders; log-freight
  production and delivery income.
- Separate speed and capacity upgrades.
- Ordered pass-through waypoints per passenger leg and freight service, with
  port-aware pathfinding, map selection and a scrollable editor.
- Simulation speed selector: 1× (default), 2×, 5× and 10×, with remappable
  number-row shortcuts and independent pause.
- Named services and ordered passenger stops across Stations A, B and C, with
  Shuttle (reverse stop order) or Loop (last-to-first) modes and a sequence preview.
- Up to eight independently active passenger services, each with its own train,
  stops, mode and directives; shared reservations/signals, Fleet controls and saved
  runtimes. Red signals limit future reservations to keep departure switches clear.
- A fleet roster with permanent train IDs, four purchasable models, individual
  names, stored spares, replacement assignment, sales and per-train upgrades.
- Passenger coaches and log wagons with full-body protection, saved composition
  continuous two-/three-stop carriage Shuttles and carriage Loops on continuous circuits.
- Atomic construction drafts, corridor signals, searchable blueprints and JSON sharing.
- Route/block/wait overlays, Problems/Find, session watchlists and alert preferences.
- Station inspection, camera scrolling, minimap, introductory objectives and saves.
- Maximized desktop startup, map/toolbars filling the window and saved fullscreen
  through Settings or remappable F11; UI scale remains independent of map zoom.

These are prototype foundations. The fleet assigns one train to each active
service; additional passenger services can run together and spares stay off-map.
Passenger transfers, in-motion automatic platform
selection and additional dispatch policies remain planned; fixed platform sidings exist. See [multiple active services](MULTIPLE_SERVICES.md).
Junctions, reservations and basic block signals provide shared-track safety.
See [Fleet management](FLEET.md) for the implemented controls.

## Architecture rules — across all phases

- The authoritative track topology, routes, physical occupancy and granted movement
  authority govern the simulation. TileMapLayers, train sprites and signal visuals
  derive from committed state; rendering never grants movement or changes topology.
- Reservation requests are resolved and committed by the explicit simulation
  coordinator in fixed order. **Do not introduce a global reservation SignalBus.**
  Direct Godot signals may notify UI, audio and alerts after a complete state commit;
  subscribers do not independently grant reservations or change update order.
- Use typed .tres Resources for stock/cargo/industry definitions as their systems
  expand. Treat shared definitions as read-only prototypes, keep per-entity runtime
  state separate, and save stable definition IDs instead of installation paths.
  Version content catalogs separately from save schemas and validate dependencies.
- Phase 0 remains an invariant: tick ordering, owned RNG, atomic versioned saves,
  remapping, 100–200% UI scale, reduced motion and colour-blind-safe palettes.
  Signal states and alerts always have text/shapes/patterns alongside colour. Custom
  liveries must preserve those operational indicators.
- A seed alone does not establish reproducibility. Initial state, generator/content
  versions, rules, command timing and stable algorithm ordering also matter. Matching
  results across rendering FPS is tested; cross-version/platform replay is not an
  assumed guarantee.

## Phase 0 — Determinism, saves and accessibility first

The merged foundation and fleet integration passes headless checks in Godot 4.6.3,
including fixed-step movement, save migration and RNG continuation. The Phase 0
accessibility and command-queue work is integrated: UI scale to 200%, keyboard and
mouse remapping, compact layouts and saved pending construction commands. Full
input replay and controller support remain later work. The desktop viewport now
fills its window, starts maximized and offers saved fullscreen with a remappable
F11 shortcut; see [display controls](DISPLAY.md). See [foundation status](phase-0-foundations.md).

| Foundation | Scope and completion evidence |
| --- | --- |
| Fixed-timestep simulation | Separate simulation ticks from rendering and wall-clock time. Queue gameplay commands at defined ticks and use stable update ordering. Check that the same initial state and command sequence produce matching simulation results at different rendering frame rates. |
| Gameplay speed controls (implemented) | Phase 0 quality of life, before adding more operations: default 1×, then 2×/5×/10× using a dropdown showing the current speed and remappable number-row keys 1–4. Accelerate all simulation systems through the fixed clock; leave camera/UI timing and pause independent. The frame budget supports 10× at 30/60/120 FPS, with bounded catch-up after stalls. See [gameplay speed](GAMEPLAY_SPEED.md). |
| One seeded simulation RNG | Route simulation randomness through one owned RNG; save its seed and current state so loading continues the sequence. Keep visual randomness separate. Seeds alone do not guarantee determinism: update order, input timing and algorithms must also be controlled. |
| Versioned saves | Maintain one schema version source and validate the whole save before applying it. Use explicit migrations for supported formats; reject unsupported or ambiguous development formats clearly. Branches must not assign the same version to incompatible schemas. Keep failed loads atomic and preserve backups. |
| Bounded event stream | Record simulation tick, stable subject/train ID, event type and compact payload for logs, alerts and journals. Bound retention and preserve ordering. An event log is not sufficient to reconstruct full world state or moving trains. |
| Accessibility defaults | UI-only scale from 100–200%, high-DPI layouts, colourblind-safe and high-contrast palettes, shapes/icons alongside colour, reduced motion/flashing and key remapping. Preserve AZERTY/QWERTY support and mouse-only construction. Test dialogs and toolbars at the largest supported scale. |
| Input and interface separation | Use named input actions, keep typing and menu navigation from controlling the map, and design focus/navigation paths early. Full controller/Steam Deck support and radial menus wait until the core menus stabilise. |

## Phase 1 — Strict network, operations and feedback milestones

The dependency order is 1A → 1B → 1C. Basic waiting explanations ship with network
integrity; the richer inspector belongs to 1C. Existing planning/search tools have
already landed before all of 1B is complete and remain usable. Optional advanced
signalling, priorities and cosmetic work need not block the basic exit criteria.

### Phase 1A — Network integrity

Core implemented: port-aware junctions, separate physical occupancy and future
reservations, body-aware switch/block locks, automatic blocks, manual holds,
missing-track stopping, sustained deadlock detection and physical reversal/recovery.
Maintain these guarantees while expanding the supported train/platform combinations.

| Feature | Gameplay or visual benefit | Status, dependencies and scope |
| --- | --- | --- |
| Junctions and switches | Build branching networks and share infrastructure between services. | Implemented: port-aware routing, locked switches, crossings, automatic switch placement during track laying and the manual Switch tool. Automatic branches preserve the original through line and include switch costs; reserved/signalled/protected junctions reject edits. See [automatic junctions](AUTOMATIC_SWITCHES.md). Further construction conveniences remain planned. |
| Block signals and track reservations | Prevent collisions and introduce dispatching decisions. | Basic tile reservations, switch/selected-port locking, safe waiting events and a hatched ownership overlay are implemented. Shared passenger/freight routing is enabled. Basic deadlock detection, physical reversal, bidirectional automatic block signals and manual holds are implemented; reservations do not select alternate passing-loop paths. |
| Signal control modes | Automatic signals/reservations by default, with optional one-way, route, platform and manual dispatch controls. | Bidirectional automatic blocks, manual stop signals and Traffic Hold/Resume are implemented; one-way, route and platform modes remain planned. One-way implementation must validate manual reversal direction before any state change. All modes use reservations and explain blocked movements. See [signals and dispatch](SIGNALS.md). |
| Deadlock detection and emergency recovery | Detect circular waits, identify involved trains/blocks and offer safe hold, turn-back, reroute or recovery actions. | Continuous actual wait cycles are detected after three simulation seconds. The train inspector offers Reverse before a confirmed deadlock; Traffic also reverses a selected deadlocked train in place, retaining its path and load until it physically returns to its departure stop, then holds it. Manual Hold/Resume is also available. Automatic turn-back, alternate routing and full reversal-location rules remain later work. See [deadlock recovery](DEADLOCKS.md). Full shunting and yard operations arrive later. |
| Priority and pathfinding rules | Offer simple dispatch priorities, initially express > local passenger > freight, so players can influence junction behaviour without configuring complex signalling. | Priorities choose between safe movements; they never override reservations. Allow player overrides, explain why a train is waiting, and prevent low-priority services from waiting indefinitely. Respect waypoint directives when choosing paths. |

### Phase 1B — Service operations

Implemented: ordered waypoints, safe paused route edits, single-vehicle Shuttle/Loop
modes, independently active passenger services, configured passing loops and initial
coaches/log wagons. Long consists now support continuous two-/three-stop Shuttle routes without
revisiting track tiles; intermediate stops retain the complete carriage body.
Carriage Loops now work on continuous circuits that repeat only their closing first
stop, with periodic body/vehicle poses and saved recovery. Straight stopping clearance is not a formal platform system.
Planned intermediate reversals now have fold-aware body routing; other repeated-path support still needs its own
body routing. Usable platform lengths and safe assignment precede multiple platforms/trains per service.

| Feature | Gameplay or visual benefit | Status, dependencies and scope |
| --- | --- | --- |
| Expanded fleet and route assignment | Extend the existing purchases and replacement assignments to more services and multiple running trains. Retain separate speed and capacity purchases. | Permanent IDs, model choices, stored spares and Shuttle/Loop routes are implemented. Implemented: up to eight independent active passenger services (e.g. A–B and A–C), each with its own assigned train, route, mode, directives and saved runtime. Shared switches, no overlaps, physical recovery, withdrawal/storage and save/load are checked. Multiple trains per service and multiple platforms remain later work. |
| Waypoints and waypoint directives | Place lightweight markers or directional waypoints to force a train through a particular track without constructing a station. Allow routing directives associated with signals. | Implemented: up to 16 ordered pass-through track cells per passenger leg (including a Loop closing leg) and outward freight leg, map selection, editing and persisted directives for passenger and freight routes. Shuttles return along that path in reverse; passenger Loops route last-to-first independently. Entry ports are preserved through waypoint routing; stops, reservations and signals remain authoritative. One-way/directional waypoint rules and independent Shuttle return directives remain planned. See [waypoints](WAYPOINTS.md). |
| Train consists and rolling stock | Assemble locomotives with passenger coaches of different classes, boxcars, tankers, hoppers and flatcars. Give each vehicle its own capacity, loading speed and cargo suitability. | Implemented: up to four passenger coaches or log wagons per locomotive, capacity/cost/speed/length effects, visible vehicles, safe empty-home edits, straight signal-free stop clearance and full-body load validation. Consists now support two-/three-stop Shuttle routes, including a planned reversal at an intermediate stop (A–C–B, see [planned reversals](PLANNED_REVERSALS.md)), with body continuity across intermediate dwell, return visits, saved states and manual turn-back. Continuous carriage Loops are also implemented when only the closing first stop repeats and every station is a through stop; see [Loop consists](LOOP_CONSISTS.md). Platform lengths are now measured and shown (see [platforms](PLATFORMS.md)); Phase 1B still needs figure-eight/other repeated-path body routing and automatic platform selection before those combinations are enabled; fixed numbered sidings already exist. Other stock types follow their cargo/classes in Phase 2; see [consists](CONSISTS.md). |
| Passing loops and multiple platforms | Reduce bottlenecks and let faster services pass slower trains. | Passing loops work with configured waypoints and signal boundaries; easier safe branch selection remains to be added. Fixed numbered platforms, measured lengths and switch-connected siding routes are implemented. Automatic selection of a free compatible platform and platform-aware arrival/departure reservations remain in Phase 1B, after the (now implemented) planned-reversal body routing. Passenger/transfer-aware preferences belong to Phase 2A. See [tested passing loops](MULTIPLE_SERVICES.md). |
| Service duplication, route cloning and drag reordering | Make service expansion and stop editing easier without disturbing running trains. | Route copying implemented: copy stops/mode/waypoints/platforms from another passenger service into the selected service’s draft; preserve target name/train and leave live state unchanged until validated Apply. Copying a running source is safe; a moving target must first return empty to the proposed first stop. Existing Up/Down edits retain matching waypoint legs and now warn when legs disappear. Freight is excluded. Creating a new service still uses Fleet and checks platform availability; no automatic purchase/spawn. Drag reordering and Fleet "Copy of …" duplication are implemented. See [route copying](ROUTE_COPY.md). |
| Non-disruptive service edits and replacement rules | Draft changes for application after the trip, at a depot or when safe; replace ageing trains or increase capacity at sustained high occupancy. | Extend current immediate paused replacements once lifecycle, utilisation and safe change points exist. Keep automatic rules opt-in and show projected purchase costs. |
| Formation templates and vehicle comparison | Save reusable consists and purchase missing vehicles; compare cost, capacity, power, reliability, fuel and infrastructure needs. | Depends on rolling stock composition and the corresponding simulated attributes. Avoid presenting unimplemented attributes as meaningful statistics. |
| Versioned data definitions | Extend stock and cargo rosters without scattering balance constants through scripts. | Start typed .tres rolling-stock definitions alongside Phase 1B fleet work and introduce cargo/industry recipes before Phase 2B. Definitions are shared read-only prototypes; runtime loads/upgrades/positions remain separate. Saves reference stable definition IDs. Content-definition versions and save-schema versions are distinct; validate references and deterministic catalog ordering before simulation starts. |

### Phase 1C — Planning and readable feedback

Implemented: reservation-aware atomic drafts, cost/refund/service-impact previews,
Undo/Redo, corridor signal batches, track blueprints/JSON sharing, route/block/wait
overlays, searchable Problems/Find, session pins and configurable incident pause.
The unified train inspector is implemented. Extend the existing alert centre
instead of creating another competing source of operational state.

| Feature | Gameplay or visual benefit | Status, dependencies and scope |
| --- | --- | --- |
| Unified why-waiting train inspector | Selecting a stalled train immediately explains its state and provides a useful next action. | Implemented in Phase 1C: paused train inspection from direct train/carriage clicks, Inspect mode and Problems/Find; direct station/building clicks open existing station information, physical occupancy, granted/attempted tile requests, block requests/authority, locked switches, measured wait duration and blocking permanent train ID/service. Distinguish loading, intentional holds, missing routes, signal waits and deadlocks. Derive recommendations from the actual cause: release a manual stop, inspect a named block, repair clearance, or consider a passing place only when layout evidence supports it. Actions navigate to conflict/blocker, synchronized overlays and the existing validated Traffic/Fleet controls. Stale waits are labelled after allocation changes; see [train inspector](TRAIN_INSPECTOR.md). |
| Construction planning and conflict preview | Draft ghost tracks, stations, bridges, signals and blueprints before committing; show cost and affected services. | Implemented: multi-stroke track/switch/removal drafts, aggregate cost/refund and affected-service previews, atomic reservation-aware application and grouped Undo/Redo. Extend aggregate quotes to itemised track/switch/signal/platform costs as those systems exist. Add evidence-based structural warnings for shared single-track sections without passing places. These identify layout risks, not guaranteed future congestion. Demand/timetable forecasts remain in Phase 2A; terrain/ownership checks follow their systems. See [construction planning](CONSTRUCTION_PLANNING.md). |
| Corridor selection and batch tools | Upgrade long segments, double-track, electrify, add signals/platforms or demolish in bulk. | Implemented: connected-corridor selection, spaced automatic/manual signals and whole-corridor signal removal through atomic drafts with grouped Undo/Redo. Track drag-demolition remains available. Track-speed, double-track, electrification and platform batches depend on their underlying systems; see [corridor signals](CORRIDOR_SIGNALS.md). |
| Track inspection and route overlays | Toggle service paths, block occupancy, reservations, signals, speed limits and congestion; later add gradients, electrification, ownership and condition. | Implemented: collapsible service-path filtering, actual signal-block IDs/authority, hatched reservations, directional affected-service construction reports and measured waiting by conflict cell. Speed limits, occupancy/utilisation measurements and richer planning remain future work. Never substitute decorative colours for operational state. |
| Search, filtering, pinning and jump-to | Find trains, stations, industries, services and later contracts; filter by type or status, highlight routes and maintain watchlists. | Implemented: searchable current problems and recent incidents, train/service names, severity filters and map location for original and independent trains. Implemented: global object search by name/ID/model/route/status, type filters, current-location map jump, selected-service route highlighting and a session watchlist that survives renaming. Persistent watchlists and preset status filters remain later refinements; see [object search](OBJECT_SEARCH.md). |
| Advisory pathfinding | Recommend a route between stations with cost, travel time and supported conflict warnings without building it. | Reuse route and construction validation. Start with read-only advice; reserve shared pathfinding work for any later rival AI. |
| Configurable alerts and notification centre | Persist incidents with severity filters; let players choose which events notify or pause. | Implemented: searchable current problems/history, severity filters, click-to-locate and per-category Off/Notice/Notice + pause applied after a complete fixed tick. Extend this existing centre with acknowledgement, persistent watchlists and actionable evidence. Add optional highlight/slow-to-1×/pause for sustained incidents at 5×/10×, with deduplication and thresholds so routine signal waits do not repeatedly interrupt play. Respect no-pause rules; see [notifications](NOTIFICATIONS.md). |
| Route performance panel and company dashboard | Compare income, running costs, occupancy, waiting passengers and delays. Expand into historical graphs of profit, ridership, occupancy and punctuality per route and across the company. | Measured continuous/recent/total traffic waiting already exists. Add bounded history for deliveries per simulation-time interval, occupancy, profit and incident episodes. Separate loading/dwell, deliberate holds and traffic waits; state denominators and whether loading resets each measure. Punctuality requires schedules, and forecasts require demand/operating history. |

### Phase 1 exit criteria

See [Phase 1A acceptance coverage](PHASE_1A_ACCEPTANCE.md) for the proposed safety
checklist, current regression evidence and explicitly unsupported cases.

- Supported running, parked and loading trains never share occupied body tiles;
  ownership and physical occupancy are distinguishable in diagnostics.
- Switches and blocks stay protected until the tail clears; manual stop signals,
  holds and recovery never bypass reservation safety.
- Save/load restores valid positions, loads and identities, rejects overlapping
  bodies atomically, and recomputes authority before movement resumes.
- Supported deadlocks are identified and expose a safe recovery action, or explain
  which escape track/infrastructure is missing. Recovery never teleports a train.
- Players can identify loading/dwell, dispatcher holds, incomplete routes, signal
  waits and deadlocks, with a named blocker and a relevant action where applicable.
- Configured passing loops and multiple compatible platforms work reliably with
  train length, safe entry/exit reservations and deterministic basic assignment.
- Regression results match at 30/60/120 rendering FPS for supported fixed-tick
  scenarios; diagnostics and controls remain readable at 200% scale without colour
  as the sole cue. Unsupported combinations fail clearly before spending or moving.

## Phase 2 — Demand, freight and growth in playable increments

### Phase 2A — Demand and passengers

Begin with measured service frequency/headways before exact timetables; attainable
frequency depends on round-trip time and available trains. Build real origin →
destination journeys, then transfers/classes/fares. Basic platform assignment is a
Phase 1B dependency; passenger-aware preferences extend it here. Structural layout
warnings can precede demand, but queue/throughput forecasts need actual history and
must be labelled estimates.

| Feature | Gameplay or visual benefit | Status, dependencies and scope |
| --- | --- | --- |
| Timetables and service frequencies | Set exact departures or recurring frequencies. Early and late arrivals affect passenger satisfaction and freight contract payouts. | Recurring headway controls are implemented (target gap, actual vs target, infeasibility explanation; see [headway](HEADWAY.md)); exact departure timetables are implemented for the first stop with a 24-minute game day ([timetables](TIMETABLES.md)); timetables at later stops and satisfaction effects remain. Record actual versus target intervals and explain infeasible targets; multiple trains per service depend on Phase 1B body/platform safety. Daily departure schedules now work at every passenger stop/direction; physical departure counts, missed slots, recent delays and saved cursors are implemented. Scheduled arrivals, punctuality penalties and timed transfers follow actual passenger destinations/contracts and reliable arrival/dwell rules. |
| Passenger destinations and transfers | Reward networks that connect useful places, including journeys requiring a change of train. | Direct destination journeys implemented: per-destination station queues, forward-itinerary boarding, through riders, destination-only delivery/fare and saved manifests. Transfers, journey planning across services, waiting-age fairness and satisfaction remain. See [passenger destinations](PASSENGER_DESTINATIONS.md). |
| Platform preferences | Prefer a platform by service, direction, train length, electrification, cargo access or transfer convenience, with safe fallback. | Basic platform infrastructure and assignment belong to Phase 1B. Phase 2A adds service/direction preferences, passenger transfer convenience and safe compatible fallback. Electrification and cargo-access preferences wait for those systems. Platform selection never overrides reservations. |
| Holding rules and timed transfers | Wait for a connection or a target load, avoid early departure and cap waiting time. Protect transfers within configurable windows and warn about missed connections. | Requires timetables, passenger destinations and platform metadata. Avoid indefinite holds and explain knock-on delays. |
| Express versus local passenger demand | High-paying express passengers prefer direct travel between distant hubs; commuters accept frequent stops along a local line. | Define clear rules for directness, stops, journey time and fares. Depends on passenger destinations and service performance data. |
| Catchment visualisation and feeders | Show population, workplaces, inputs/outputs, walking distance and competing stations; abstract park-and-ride, bus and tram feeder capacity. | Implement catchment/destination rules first. Feeders are demand abstractions, not a second vehicle-management game. |
| Demand and bottleneck adviser | Forecast queues, platform demand and shortages; explain persistent congestion with clickable evidence and recommendations. | Stopped-traffic measurements and a bounded recent-wait overlay are implemented. Forecasts still require utilisation and demand history. Start with transparent heuristics; present forecasts as estimates, not guaranteed outcomes. |
| Passenger classes and preferences | Add commuters seeking frequency, business travellers prioritising speed/punctuality, tourists valuing comfort/scenery and budget travellers sensitive to fares. | Extend express/local demand rather than adding a competing demand system. Add classes gradually with understandable journey-choice rules. |
| Fare control and demand elasticity | Set fares by service/class and offer off-peak discounts, balancing demand and revenue. | Depends on destinations, classes, satisfaction and simple documented price-response rules. |
| Company reputation and passenger satisfaction | Reward reliable, comfortable service with demand growth, better contracts and subsidies instead of rewarding only transport volume. | Use understandable measures such as punctuality, crowding, journey time and amenities. Show causes and recovery options; connect reputation to town growth and contract availability. |
| Marketing, subsidies and public-service obligations | Fund temporary demand boosts and win regional contracts for reliable service to underserved towns, with frequency/fare conditions. | Reuse contracts, reputation, timetables and demand modifiers. Show obligations and penalties before acceptance. |
| Detailed station life and waiting passengers | Show tiny pixel-art passengers accumulating on platforms during delays and boarding when trains arrive. | Drive visuals from actual queues; cap or group sprites for performance without changing simulated passenger counts. |

### Phase 2B — Freight and supply chains

Complete logs → sawmill → timber delivery first, then add factory processing and a
finished-goods destination. Only generalise recipes/cargo behaviour after that full
chain is playable and its storage, stock compatibility and finances are verified.
Versioned cargo/industry definitions start before the first processing industry.

| Feature | Gameplay or visual benefit | Status, dependencies and scope |
| --- | --- | --- |
| Industry supply chains | Move logs to sawmills, timber to factories, and finished goods to terminals. | Phase 2B first delivers a playable logs → sawmill → timber delivery chain, then adds a factory and finished-goods destination to complete the logs → sawmill → timber → factory chain. Verify input consumption, production recipes, bounded storage, compatible wagons and delivery accounting before generalising cargo types. |
| Cargo with distinct behaviours | Perishable cargo spoils over time, hazardous materials need lower speeds or special handling, and high-value express cargo rewards fast delivery. | Track shipment age and delivery terms; connect cargo requirements to rolling stock, facilities and routing. Make spoilage, restrictions and bonuses visible before loading. |
| Mail and parcels | Add small, fast, high-value consignments, including carriage on compatible passenger trains. | Requires cargo definitions, compatible vehicles and explicit capacity sharing; introduce before complex intermodal logistics. |
| Station facilities and amenities | Add platforms, waiting rooms, cargo warehouses and fuel depots to increase capacity, shorten loading times or lower running costs. | Physical platforms and usable lengths belong to Phase 1B. Phase 2A next adds separate waiting-area capacity and demand/amenity purchases; train capacity does not create passengers. Passenger loading facilities follow measured dwell/loading rules; Phase 2B adds cargo warehouses and handling. Fuel depots wait for locomotive technology and energy costs. Each facility needs a clear priced benefit. |
| Delivery contracts | Earn rewards for specified quantities delivered within deadlines. | Extend the existing objective system with selectable, timed contracts and clear failure conditions. |

### Phase 2C — Growth and persistence

Connect growth to delivered passenger/cargo service. Offer unlimited money and
slower/no growth as those systems arrive; expose no-breakdown options when
maintenance exists. Persist scenario rules and separate challenge eligibility from
relaxed sandbox play. Autosaves, basic scenario objectives and bounded performance
history may land earlier once their foundations are reliable.

| Feature | Gameplay or visual benefit | Status, dependencies and scope |
| --- | --- | --- |
| Town and industry growth | Let reliable transport increase demand and create expansion opportunities. | Phase 2C: growth responds to measured delivered service and usable passenger/cargo demand. Provide slower-growth and no-growth options; integrate land rights when introduced. Do not couple visual town expansion to unimplemented demand. |
| Sandbox and scenario modes | Offer relaxed construction alongside structured challenges. | Expose unlimited-money and growth-rate options with the supporting systems. Add no-breakdown and maintenance-pressure controls when maintenance exists. Save rule settings and define challenge/achievement eligibility. Reuse introductory objectives for a small early scenario framework; avoid requiring all later simulation features first. |
| Operating budgets | Break costs down into maintenance, fuel/energy, workforce, vehicles, construction, interest, station upkeep and penalties. | Expand the company dashboard as each cost system arrives; avoid double-counting the same expense across categories. |
| Leasing and second-hand stock | Offer low-upfront-cost leases and cheaper used vehicles with clear running-cost or reliability trade-offs. | Build on fleet identities, contracts and vehicle condition. Add simple purchase/lease terms before resale-market simulation. |
| Incident log, journal and lightweight narratives | Generate factual headlines and selected passenger/cargo stories with destinations and senders/recipients. | Consume bounded simulation events and real shipment data. Cap visible stories; keep logs useful even with flavour text disabled. |
| Rotating autosaves and recovery | Keep a bounded quick-save roster, configurable periodic autosaves and recovery from the last valid save. | Four independent manual slots with per-slot backups and a fresh-game chooser are implemented ([save slots](SAVE_SLOTS.md)). Periodic rotating autosaves remain planned. Build on atomic versioned saves. In-game-hour autosaves are a proposed default, not a real-time guarantee. Never overwrite the only valid save when a write fails. |
| Recent visual replay | Watch approximately the last ten simulation minutes and jump to incidents. | Combine the event stream with a small ring buffer of sampled train positions, headings, identities and relevant visual/map changes. Set explicit sample-rate and memory limits. This is visual history, not rollback, a save replacement or deterministic input replay. |

## Phase 3 — Infrastructure, maintenance and business decisions

Mechanical condition, breakdown penalties and workforce complexity use explicit
difficulty presets/modifiers; relaxed play retains a no-breakdown option. Rival AI
remains deferred. Keep stable IDs and validated content boundaries suitable for a
future rival, without adding speculative AI frameworks.

| Feature | Gameplay or visual benefit | Status, dependencies and scope |
| --- | --- | --- |
| Terrain, bridges and tunnels | Balance construction cost against distance, grades and journey time. | Introduce terrain and elevation constraints before grade-dependent traction or weather effects. |
| Maintenance yards and breakdowns | Route trains to depots or maintenance sheds. Neglected trains become slower, cost more to run, or break down and block single-track sections. | Add condition, warnings, maintenance schedules, depot visits and repair/recovery actions after fleet and reservation safety. Gate mechanical penalties behind relaxed/standard/challenging presets or explicit modifiers; no-breakdown sandbox remains available. Difficulty changes frequency/severity and costs, never collision safety. |
| Depots and stabling tracks | Store spare trains, hold vehicles between services and provide cleaning facilities away from running lines. | Share depot access and fleet management with maintenance yards. Track siding capacity and safe entry/exit reservations; add timetable-based layovers when schedules exist. Parking and cleaning remain distinct from mechanical maintenance. |
| Track wear, rail classes and weight limits | Heavy trains wear infrastructure faster; choose light, standard or heavy rail with different costs and supported loads. | Requires train mass, maintenance costs and visible condition. Validate weight limits during routing and purchase planning. |
| Work zones and temporary speed restrictions | Apply clear-duration slow orders for works, damage or weather, with affected services visible. | Reuse reservations and route speed constraints; integrate weather causes only when weather gameplay exists. |
| Workforce, fatigue and skills (one optional system) | Abstract drivers, conductors, maintenance and station staff into costs, reliability, dwell and service quality. | Merge crew and staff proposals rather than running two management systems. Keep staffing largely automatic; detailed rosters and per-person micromanagement are not core scope. |
| Shunting, reversing and yard operations | Split/merge consists, reverse at valid facilities, send trains to depots and operate recovery locomotives. | Later extension of safe recovery, depots, consists and temporary reservations. Implement only where it creates useful network decisions. |
| Rivers, crossings, landmarks and regional themes | Create meaningful bridge placement and recognisable Alpine, desert, tropical, urban, countryside or Nordic maps. | Terrain/visual variety first; add regional cargo, cost or weather modifiers behind explicit settings. Flood simulation is optional later work. |
| Loans and debt | Borrow to fund expensive infrastructure such as tunnels, with variable interest and repayment obligations. | Show interest terms, rate changes, repayments and projected cash flow clearly. Define insolvency rules and sandbox alternatives. |
| Land purchase and transit rights | Buy land or access rights before town growth makes expansion more expensive. | Integrate ownership with construction previews, town growth and infrastructure costs. |
| Rival bidding and territory pressure (deferred) | Rival companies can bid for limited industry rights or claim territory. | Revisit after contracts, land rights and the economy are stable. Full autonomous railway-building AI is outside the core release scope. |

## Phase 4 — Historical progression and the changing environment

| Feature | Gameplay or visual benefit | Status, dependencies and scope |
| --- | --- | --- |
| Steam → diesel → electric eras | Advance through time or research investment. Early steam locomotives are affordable but slow; later electric trains offer high performance with costly electrification. | Add locomotive technology, operating costs, unlock rules and overhead catenary infrastructure. Validate that electric services have suitable electrified routes. Make era progression configurable for sandbox play. |
| Research and technology tree | Invest in better signalling, higher-speed track, efficient locomotives and advanced cargo handling for long-term goals. | Use one unlock system shared with historical eras rather than separate conflicting progressions. Show prerequisites, research costs and benefits, with configurable time-based or investment-based progression. |
| Dynamic weather and seasons | Add rain, snow and autumn foliage. Snow can slow mountain passes or increase running costs; rain can reduce traction on steep inclines. | Separate visual effects from optional simulation penalties. Terrain grades and traction must exist before grade-based effects. Forecasts and clear status messages should explain operational changes. |
| Day/night and dynamic lighting | Add station lights, headlamps and readable signals through a changing visual day. | Rendering follows simulation time without driving it. Night restrictions or comfort effects are optional and disabled until their supporting systems exist. |
| Company valuation, milestones and sustainability | Track company value, passenger-distance, freight movement, punctuality, reputation and optional emissions-related incentives. | Aggregate measured service data; add technology-based emissions only with eras and energy costs. Keep environmental scoring optional in historical sandboxes. |
| Dynamic events and disruptions | Introduce temporary closures, sudden demand surges and other challenges that prompt network adjustments during sandbox play. | Reuse demand, contracts, weather and maintenance systems where appropriate. Give events clear duration, advance information when appropriate, recovery conditions and configurable frequency. |

## Phase 5 — Building tools, spectators and community content

| Feature | Gameplay or visual benefit | Status, dependencies and scope |
| --- | --- | --- |
| Blueprints and copy/paste track designs | Save and reuse junctions, loops and terminal layouts. | Implemented: rectangular capture of built track/switches/signals, relative placement through priced reservation-aware drafts and grouped Undo/Redo. Stations/platforms, rotation and land ownership checks follow their own systems; see [track blueprints](TRACK_BLUEPRINTS.md). |
| Camera tools, spectator views and traffic overview | Expand existing camera scrolling and the minimap with free-camera controls, train-follow/ride-along mode, close station views with minimal UI, and a network traffic-density heat map. | Use stable train targets and traffic measurements, an easy return to normal controls, and protection against accidental construction while watching. Spectator controls can arrive earlier; the heat map builds on dashboard data. |
| Procedural maps and shareable seeds | Generate terrain, rivers, towns, industries and resources with adjustable size/density and reproducible starts. | Start with bounded random industry placement for targeted scenarios before a full terrain generator. Validate placement, connectivity and objective feasibility. Share seed, generator/content versions and scenario/modifier rules; a seed alone does not guarantee matching maps across releases. Full terrain, rivers and town generation remain later work. |
| Photo mode and sharing tools | Capture screenshots with optional route-name and train-information overlays for sharing. | Build on camera tools and selectable UI visibility. Start with local image export; keep posting to external services a deliberate player action. Video/GIF export is deferred outside core scope. |
| Railway sound design | Give locomotives distinct horns and rail sounds, add station announcements, and use ambient audio to make the network feel alive. | Use spatial sound tied to train type, speed, distance and station events; scale platform crowd ambience from visible queues. Provide separate volume controls and visual equivalents for important audio cues; use appropriately licensed or original assets. |
| Level and scenario editor | Create maps, place industries and define delivery challenges for sharing. | Define a versioned content format, validate maps and objectives, and separate scenario definitions from saved sessions. Start with local import/export and sharing through community forums. Steam Workshop integration is a later distribution-specific option, not a requirement for using the editor. |
| Blueprint browser | Tag and search saved junction, loop and terminal designs; preview footprint, cost and compatibility before placement. | Implemented: searchable local design browser, versioned JSON import/export, format validation and backup persistence. Tags, thumbnail previews and rotation/mirroring remain later refinements; see [track blueprints](TRACK_BLUEPRINTS.md). |
| Town names, company lore and scenario flavour | Rename towns and add short generated histories, industry descriptions and regional needs such as commuter relief, export access or industrial revival. | Use lightweight local templates and editable text. No external generative service is required. |
| Tourism, special trains and railway heritage | Offer scenic excursions, seasonal/royal/military services, preservation lines and an encyclopedia or railway museum. | Start as optional scenarios/contracts using existing routes, amenities and scenery data. In-world trophies or locomotive decals are low-priority cosmetic rewards. |
| Lightweight modding | Support custom scenarios, train sprites and simple cargo definitions to extend the game and encourage community contributions. | Reuse scenario formats and data-driven vehicle/cargo definitions. Document schemas, asset requirements and version compatibility; validate content and report missing assets clearly. Start with data and asset packs rather than requiring executable mods. |
| Custom livery | Add selectable fleet colour palettes to the existing individual train names. | Stable identities and train renaming are implemented. Provide basic player-selectable palettes freely, with additional cosmetic liveries and historical visual themes unlocked by achievements. Preserve readable operational markers independently of paint colours and colour-blind palettes. Cosmetic historical themes do not require technology-era simulation. |

## Modes, learning and accessibility — across all phases

A small scenario framework can arrive earlier than the full editor or procedural
maps. Combine targeted, achievable modifiers with validated random industry
placement instead of requiring a large content roster. Track-budget, single-track
and low-cash challenges can precede schedules; strict punctuality cannot.

Score throughput per simulation-time interval, mean traffic wait with a declared
population of trains/trips, and incident episodes per declared time/delivery count.
Distinguish traffic waits from dwell/loading/intentional holds. Cosmetic rewards
augment freely selectable base liveries/themes and remain separate from operational
readability and mechanical technology progression.

| Feature | Gameplay or visual benefit | Status, dependencies and scope |
| --- | --- | --- |
| Tutorial campaigns with progressive unlocking | Teach track building → stations → signals → contracts → growth, one system at a time. | Expand introductory objectives into guided scenarios as each system becomes available. Provide contextual explanations, repeatable lessons and an option to skip tutorials. |
| Difficulty modifiers | Offer higher running costs, stricter contracts, optional no-pause play, and adjustable maintenance, weather and event pressure. | Present modifiers explicitly when creating a game and save them with the scenario. Keep a relaxed sandbox preset; ensure no-pause play still offers a usable route-editing workflow instead of relying on the current automatic pause. |
| Seeded challenges and asynchronous community play | Offer daily/weekly seeds, campaign medals and score comparisons for profit, punctuality, efficiency or optional environmental goals; share results and seeds asynchronously. | Begin with local/manual sharing of low-cash, track-budget and single-track-only scenarios using feasible random industry placement. Punctuality challenges require schedules. Shared runs include seed, generator/content versions, rules and modifier eligibility; add daily/weekly challenges and hosted comparison only after reproducibility is demonstrated. |
| Ghost networks and benchmark histories | Compare anonymised network layouts, construction timelines or performance against a benchmark. | Share versioned summaries or recorded timelines first. Executable deterministic replays additionally need an initial state, tick-stamped commands, RNG state and verification—not just the event log or position buffer. |
| Achievements and challenge packs | Add replayable goals such as delivering a passenger target without delays or connecting every town below a track-length budget. | Extend measurable scenario objectives and explicit difficulty eligibility. Score throughput, waiting and incident episodes with documented denominators; count incidents once per episode, not once per blocked tick. Keep basic liveries available and unlock additional palettes/themes through local achievement milestones. Platform achievements are optional. |

## Tutorial coverage

Teach one operational concept at a time as it becomes available:

1. Track building, stations and reading block/reservation/signal congestion.
2. Fixing delays with loops, platforms, holding rules and rerouting.
3. Profitable services: demand, frequency, capacity, fares and costs.
4. Transfers: timing, platform layouts and total journey time.
5. Freight chains: inputs, outputs, storage, wagons and deadlines.
6. Safe expansion: planning, land rights and phased upgrades without disruption.
7. Incidents: breakdowns, closures, weather and safe recovery.
8. Modernisation: fleet replacement, electrification and loans.

Campaign stories can include reviving a branch, supplying wartime industry,
modernising a network or building a metropolitan railway. Reuse scenario objectives
instead of adding a separate campaign simulation.

## Deferred or outside the core solo-project scope

| Feature | Decision |
| --- | --- |
| Power grids, substations and load management | Defer. Start with route electrification and operating costs; revisit only if additional power management improves the railway game. |
| Insurance and detailed disaster recovery finance | Defer. Basic breakdown repair and incident recovery remain in scope. |
| Airports and operating ferries | Outside core scope. Ports, warehouses and intermodal terminals may initially act as rail cargo sources/sinks; no extra transport-mode simulation is required. |
| Cinematic camera scripting and video/GIF/time-lapse export | Defer. Photo mode and the bounded in-game visual replay cover the initial sharing/spectator goals. |
| Cooperative multiplayer | Outside core scope until determinism, commands, networking conflict rules and saves are proven. Phase 0 is a prerequisite, not a promise to implement multiplayer. |
| Full competitor railway-building AI | Defer. Limited bids or contract rivalry are a smaller future option. |
| Detailed staff rostering | Defer in favour of the single optional workforce abstraction. |
| Hosted leaderboards and Steam Workshop | Optional distribution/community integrations after local content sharing and challenge formats are stable. |

## Agreed next implementation order

1. **Unified why-waiting inspector (1C, implemented):** current occupancy, requested/granted
   authority, named blocker, measured waiting and evidence-based actions. Build on
   existing Problems/Traffic/Overlays; keep routine waits distinct from incidents.
2. **Continuous consist body routing (1B, planned reversals implemented):** continuous
   two-/three-stop Shuttles now retain every vehicle through intermediate stops,
   return visits, saved dwell and manual recovery. Continuous carriage circuits now
   preserve periodic body/vehicle poses, tail locks, signal authority and save/load
   through the Loop boundary. Planned reversals at intermediate stops now preserve the
   rigid formation, extension ownership, tail locks and signals. Still needed: figure-eights
   and other repeated paths before enabling those combinations.
   Extend regression tests for tail locks and save/load.
3. **Formal platform lengths and multiple platforms (1B, lengths, IDs and assignment rule implemented; fixed per-stop platform choice implemented; automatic choice at arrival pending):** physical geometry,
   stable IDs, train fit, basic assignment and safe arrival/departure reservations;
   improve passing-loop branch selection while preserving waypoint intent.
4. **Service editor expansion and frequency foundation (1B → 2A):** draft-based
   route copying is implemented with draft preview, safe Apply and vanished-leg warnings.
   Still needed: full service duplication/drag reordering, safe multiple trains per service, then measured
   headways and frequency targets with clear attainable limits.
5. **Passenger demand (2A, direct destinations implemented):** next add separate
   station waiting-area capacity and demand/amenity upgrades, then transfers and
   journey choices, classes/fares/satisfaction. Departure timetables are implemented;
   arrival targets and punctuality contracts follow their demand/contract rules.
6. **One complete freight chain (2B):** logs → sawmill → timber delivery, followed
   by factory/finished goods; verify stock, recipes, storage and payments first.
7. **Growth, sandbox rules and persistence (2C):** service-driven growth,
   eligibility-aware scenario rules, bounded metrics and reliable rotating saves.
8. **Later mechanics (3–5):** opt-in maintenance, terrain/economy, research/eras,
   optional weather effects, full scenario/editor/community expansion.

Introduce versioned .tres stock definitions alongside the relevant fleet work and
cargo/industry definitions before processing chains. Small scenario modifiers,
cosmetic art/sound, accessible feedback and save reliability may proceed alongside
their prerequisite milestone. No global reservation SignalBus is planned.

Implemented tools and evidence: [foundations](phase-0-foundations.md),
[reservations](RESERVATIONS.md), [signals](SIGNALS.md), [recovery](DEADLOCKS.md),
[waypoints](WAYPOINTS.md), [multiple services/passing loops](MULTIPLE_SERVICES.md),
[consists](CONSISTS.md), [platform lengths](PLATFORMS.md), [inspection](NETWORK_INSPECTION.md),
[problems/waiting](PROBLEMS_AND_WAITING.md), [alerts](NOTIFICATIONS.md),
[construction drafts](CONSTRUCTION_PLANNING.md), [corridor signals](CORRIDOR_SIGNALS.md),
[blueprints](TRACK_BLUEPRINTS.md) and [object search](OBJECT_SEARCH.md).
