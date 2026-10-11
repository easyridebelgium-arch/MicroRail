# Trainz development roadmap

This roadmap combines the earlier gameplay suggestions with the requested future
features. The phases are a proposed development order, not release dates. Features
listed as planned are not implemented yet. Keep the core game playable while adding
each system, with Godot and GDScript as the main development tools.

## Current foundation

- Mouse-drawn tracks with automatic bends, diagonals and a straight first extension
  tile when departing existing rails.
- Construction costs, drag demolition and paused construction Undo/Redo.
- Passenger and log-freight services, production and delivery income.
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
- Station inspection, camera scrolling, minimap, introductory objectives and saves.

These are prototype foundations. The fleet assigns one train to each active
service; additional passenger services can run together and spares stay off-map.
Individual passenger destinations, multiple trains per service, multiple platforms
and additional dispatch policies remain planned. See [multiple active services](MULTIPLE_SERVICES.md).
Junctions, reservations and basic block signals provide shared-track safety.
See [Fleet management](FLEET.md) for the implemented controls.

## Phase 0 — Determinism, saves and accessibility first

The merged foundation and fleet integration passes headless checks in Godot 4.6.3,
including fixed-step movement, save migration and RNG continuation. The Phase 0
accessibility and command-queue work is integrated: UI scale to 200%, keyboard and
mouse remapping, compact layouts and saved pending construction commands. Full
input replay and controller support remain later work. See [foundation status](phase-0-foundations.md).

| Foundation | Scope and completion evidence |
| --- | --- |
| Fixed-timestep simulation | Separate simulation ticks from rendering and wall-clock time. Queue gameplay commands at defined ticks and use stable update ordering. Check that the same initial state and command sequence produce matching simulation results at different rendering frame rates. |
| Gameplay speed controls (implemented) | Phase 0 quality of life, before adding more operations: default 1×, then 2×/5×/10× using a dropdown showing the current speed and remappable number-row keys 1–4. Accelerate all simulation systems through the fixed clock; leave camera/UI timing and pause independent. The frame budget supports 10× at 30/60/120 FPS, with bounded catch-up after stalls. See [gameplay speed](GAMEPLAY_SPEED.md). |
| One seeded simulation RNG | Route simulation randomness through one owned RNG; save its seed and current state so loading continues the sequence. Keep visual randomness separate. Seeds alone do not guarantee determinism: update order, input timing and algorithms must also be controlled. |
| Versioned saves | Maintain one schema version source and validate the whole save before applying it. Use explicit migrations for supported formats; reject unsupported or ambiguous development formats clearly. Branches must not assign the same version to incompatible schemas. Keep failed loads atomic and preserve backups. |
| Bounded event stream | Record simulation tick, stable subject/train ID, event type and compact payload for logs, alerts and journals. Bound retention and preserve ordering. An event log is not sufficient to reconstruct full world state or moving trains. |
| Accessibility defaults | UI-only scale from 100–200%, high-DPI layouts, colourblind-safe and high-contrast palettes, shapes/icons alongside colour, reduced motion/flashing and key remapping. Preserve AZERTY/QWERTY support and mouse-only construction. Test dialogs and toolbars at the largest supported scale. |
| Input and interface separation | Use named input actions, keep typing and menu navigation from controlling the map, and design focus/navigation paths early. Full controller/Steam Deck support and radial menus wait until the core menus stabilise. |

## Phase 1 — Network integrity, services, then planning and readable feedback

Implementation order within this phase: junction topology → reservations and safe
waiting → signals and deadlock/recovery handling → waypoints and safe route edits
→ Shuttle/Loop route modes → multiple active passenger services with shared-track
reservations → reservation-aware planning, conflict previews and bulk edits.
A cost-only ghost preview can arrive earlier, but
must not claim to predict traffic conflicts without the reservation layer.


| Planned feature | Intended gameplay or visual benefit | Dependencies and scope |
| --- | --- | --- |
| Expanded fleet and route assignment | Extend the existing purchases and replacement assignments to more services and multiple running trains. Retain separate speed and capacity purchases. | Permanent IDs, model choices, stored spares and Shuttle/Loop routes are implemented. Implemented: up to eight independent active passenger services (e.g. A–B and A–C), each with its own assigned train, route, mode, directives and saved runtime. Shared switches, no overlaps, physical recovery, withdrawal/storage and save/load are checked. Multiple trains per service and multiple platforms remain later work. |
| Train consists and rolling stock (Phase 2, after safe train-length handling) | Assemble locomotives with passenger coaches of different classes, boxcars, tankers, hoppers and flatcars. Give each vehicle its own capacity, loading speed and cargo suitability. | Extend the fleet model with vehicle composition, cargo compatibility and total train length. Account for platform and block lengths before running long consists. Introduce stock types as their passenger classes or cargo types become available. |
| Junctions and switches | Build branching networks and share infrastructure between services. | Implemented: port-aware routing, locked switches, crossings and a switch tool. Further construction conveniences remain planned. |
| Block signals and track reservations | Prevent collisions and introduce dispatching decisions. | Basic tile reservations, switch/selected-port locking, safe waiting events and a hatched ownership overlay are implemented. Shared passenger/freight routing is enabled. Basic deadlock detection, physical reversal, bidirectional automatic block signals and manual holds are implemented; reservations do not select alternate passing-loop paths. |
| Priority and pathfinding rules | Offer simple dispatch priorities, initially express > local passenger > freight, so players can influence junction behaviour without configuring complex signalling. | Priorities choose between safe movements; they never override reservations. Allow player overrides, explain why a train is waiting, and prevent low-priority services from waiting indefinitely. Respect waypoint directives when choosing paths. |
| Waypoints and waypoint directives | Place lightweight markers or directional waypoints to force a train through a particular track without constructing a station. Allow routing directives associated with signals. | Implemented: up to 16 ordered pass-through track cells per passenger leg (including a Loop closing leg) and outward freight leg, map selection, editing and persisted directives for passenger and freight routes. Shuttles return along that path in reverse; passenger Loops route last-to-first independently. Entry ports are preserved through waypoint routing; stops, reservations and signals remain authoritative. One-way/directional waypoint rules and independent Shuttle return directives remain planned. See [waypoints](WAYPOINTS.md). |
| Signal control modes | Automatic signals/reservations by default, with optional one-way, route, platform and manual dispatch controls. | Bidirectional automatic blocks, manual stop signals and Traffic Hold/Resume are implemented; one-way, route and platform modes remain planned. All modes use reservations and explain blocked movements. See [signals and dispatch](SIGNALS.md). |
| Deadlock detection and emergency recovery | Detect circular waits, identify involved trains/blocks and offer safe hold, turn-back, reroute or recovery actions. | Continuous actual wait cycles are detected after three simulation seconds. Traffic reverses the selected train in place, retaining its path and load until it physically returns to its departure stop, then holds it. Manual Hold/Resume is also available. Automatic turn-back, alternate routing and full reversal-location rules remain later work. See [deadlock recovery](DEADLOCKS.md). Full shunting and yard operations arrive later. |
| Construction planning and conflict preview | Draft ghost tracks, stations, bridges, signals and blueprints before committing; show cost and affected services. | Implemented: multi-stroke track/switch/removal drafts, aggregate cost/refund and affected-service previews, atomic reservation-aware application and grouped Undo/Redo. Drafts remain separate from live simulation. Add terrain, ownership and travel-time warnings as those systems arrive; see [construction planning](CONSTRUCTION_PLANNING.md). |
| Corridor selection and batch tools | Upgrade long segments, double-track, electrify, add signals/platforms or demolish in bulk. | Implemented: connected-corridor selection, spaced automatic/manual signals and whole-corridor signal removal through atomic drafts with grouped Undo/Redo. Track drag-demolition remains available. Track-speed, double-track, electrification and platform batches depend on their underlying systems; see [corridor signals](CORRIDOR_SIGNALS.md). |
| Track inspection and route overlays | Toggle service paths, block occupancy, reservations, signals, speed limits and congestion; later add gradients, electrification, ownership and condition. | Implemented: collapsible service-path filtering, actual signal-block IDs/authority, hatched reservations, directional affected-service construction reports and measured waiting by conflict cell. Speed limits, occupancy/utilisation measurements and richer planning remain future work. Never substitute decorative colours for operational state. |
| Search, filtering, pinning and jump-to | Find trains, stations, industries, services and later contracts; filter by type or status, highlight routes and maintain watchlists. | Implemented: searchable current problems and recent incidents, train/service names, severity filters and map location for original and independent trains. Global object search, pinning and watchlists remain planned. |
| Advisory pathfinding | Recommend a route between stations with cost, travel time and supported conflict warnings without building it. | Reuse route and construction validation. Start with read-only advice; reserve shared pathfinding work for any later rival AI. |
| Configurable alerts and notification centre | Persist incidents with severity filters; let players choose which events notify or pause. | Implemented: current problem counts and severity-filtered historical incident browsing from the saved event stream. Implemented: saved per-category Off/Notice/Notice + pause preferences for waiting, deadlock and recovery events, with pause applied after a complete fixed tick. Acknowledgement, watchlists and per-train rules remain planned; see [notifications](NOTIFICATIONS.md). Provide non-colour and non-audio cues, and coordinate pause behaviour with no-pause challenges. |
| Passing loops and multiple platforms | Reduce bottlenecks and let faster services pass slower trains. | Depends on junctions, reservations and platform assignment. |
| Route performance panel and company dashboard | Compare income, running costs, occupancy, waiting passengers and delays. Expand into historical graphs of profit, ridership, occupancy and punctuality per route and across the company. | Attribute costs and deliveries to services and individual trains. Start recording bounded historical data early; add delay statistics when timetables are introduced. |
| Custom livery | Add selectable fleet colour palettes to the existing individual train names. | Stable identities and train renaming are implemented. Palette-friendly artwork and readable service indicators remain to be added. |
| Detailed station life and waiting passengers | Show tiny pixel-art passengers accumulating on platforms during delays and boarding when trains arrive. | Drive visuals from actual queues; cap or group sprites for performance without changing simulated passenger counts. |

## Phase 2 — Passenger demand, freight chains and growth

| Planned feature | Intended gameplay or visual benefit | Dependencies and scope |
| --- | --- | --- |
| Passenger destinations and transfers | Reward networks that connect useful places, including journeys requiring a change of train. | Replace the current next-stop passenger model with origins, destinations and journey planning. |
| Express versus local passenger demand | High-paying express passengers prefer direct travel between distant hubs; commuters accept frequent stops along a local line. | Define clear rules for directness, stops, journey time and fares. Depends on passenger destinations and service performance data. |
| Timetables and service frequencies | Set exact departures or recurring frequencies. Early and late arrivals affect passenger satisfaction and freight contract payouts. | Build on a simulation clock, station dwell rules and shared-track dispatching. Define tolerances, holding for scheduled departure, missed services and recovery from delays; show the consequences before players accept a contract. |
| Holding rules and timed transfers | Wait for a connection or a target load, avoid early departure and cap waiting time. Protect transfers within configurable windows and warn about missed connections. | Requires timetables, passenger destinations and platform metadata. Avoid indefinite holds and explain knock-on delays. |
| Platform preferences | Prefer a platform by service, direction, train length, electrification, cargo access or transfer convenience, with safe fallback. | Requires multi-platform stations and reservations; choices must respect train and infrastructure compatibility. |
| Non-disruptive service edits and replacement rules | Draft changes for application after the trip, at a depot or when safe; replace ageing trains or increase capacity at sustained high occupancy. | Extend current immediate paused replacements once lifecycle, utilisation and safe change points exist. Keep automatic rules opt-in and show projected purchase costs. |
| Formation templates and vehicle comparison | Save reusable consists and purchase missing vehicles; compare cost, capacity, power, reliability, fuel and infrastructure needs. | Depends on rolling stock composition and the corresponding simulated attributes. Avoid presenting unimplemented attributes as meaningful statistics. |
| Catchment visualisation and feeders | Show population, workplaces, inputs/outputs, walking distance and competing stations; abstract park-and-ride, bus and tram feeder capacity. | Implement catchment/destination rules first. Feeders are demand abstractions, not a second vehicle-management game. |
| Demand and bottleneck adviser | Forecast queues, platform demand and shortages; explain persistent congestion with clickable evidence and recommendations. | Stopped-traffic measurements and a bounded recent-wait overlay are implemented. Forecasts still require utilisation and demand history. Start with transparent heuristics; present forecasts as estimates, not guaranteed outcomes. |
| Passenger classes and preferences | Add commuters seeking frequency, business travellers prioritising speed/punctuality, tourists valuing comfort/scenery and budget travellers sensitive to fares. | Extend express/local demand rather than adding a competing demand system. Add classes gradually with understandable journey-choice rules. |
| Fare control and demand elasticity | Set fares by service/class and offer off-peak discounts, balancing demand and revenue. | Depends on destinations, classes, satisfaction and simple documented price-response rules. |
| Industry supply chains | Move logs to sawmills, timber to factories, and finished goods to terminals. | Add cargo types, production recipes, storage limits and compatible loading rules. |
| Cargo with distinct behaviours | Perishable cargo spoils over time, hazardous materials need lower speeds or special handling, and high-value express cargo rewards fast delivery. | Track shipment age and delivery terms; connect cargo requirements to rolling stock, facilities and routing. Make spoilage, restrictions and bonuses visible before loading. |
| Mail and parcels | Add small, fast, high-value consignments, including carriage on compatible passenger trains. | Requires cargo definitions, compatible vehicles and explicit capacity sharing; introduce before complex intermodal logistics. |
| Station facilities and amenities | Add platforms, waiting rooms, cargo warehouses and fuel depots to increase capacity, shorten loading times or lower running costs. | Extend station construction and upgrades with clear benefits and costs. Tie platform capacity to train length, warehouses to cargo storage, and fuel facilities to compatible locomotive technology. |
| Delivery contracts | Earn rewards for specified quantities delivered within deadlines. | Extend the existing objective system with selectable, timed contracts and clear failure conditions. |
| Company reputation and passenger satisfaction | Reward reliable, comfortable service with demand growth, better contracts and subsidies instead of rewarding only transport volume. | Use understandable measures such as punctuality, crowding, journey time and amenities. Show causes and recovery options; connect reputation to town growth and contract availability. |
| Marketing, subsidies and public-service obligations | Fund temporary demand boosts and win regional contracts for reliable service to underserved towns, with frequency/fare conditions. | Reuse contracts, reputation, timetables and demand modifiers. Show obligations and penalties before acceptance. |
| Operating budgets | Break costs down into maintenance, fuel/energy, workforce, vehicles, construction, interest, station upkeep and penalties. | Expand the company dashboard as each cost system arrives; avoid double-counting the same expense across categories. |
| Leasing and second-hand stock | Offer low-upfront-cost leases and cheaper used vehicles with clear running-cost or reliability trade-offs. | Build on fleet identities, contracts and vehicle condition. Add simple purchase/lease terms before resale-market simulation. |
| Incident log, journal and lightweight narratives | Generate factual headlines and selected passenger/cargo stories with destinations and senders/recipients. | Consume bounded simulation events and real shipment data. Cap visible stories; keep logs useful even with flavour text disabled. |
| Rotating autosaves and recovery | Keep a bounded quick-save roster, configurable periodic autosaves and recovery from the last valid save. | Build on atomic versioned saves. In-game-hour autosaves are a proposed default, not a real-time guarantee. Never overwrite the only valid save when a write fails. |
| Recent visual replay | Watch approximately the last ten simulation minutes and jump to incidents. | Combine the event stream with a small ring buffer of sampled train positions, headings, identities and relevant visual/map changes. Set explicit sample-rate and memory limits. This is visual history, not rollback, a save replacement or deterministic input replay. |
| Town and industry growth | Let reliable transport increase demand and create expansion opportunities. | Growth should respond to delivered service and connect to land ownership rules when introduced. |
| Sandbox and scenario modes | Offer relaxed construction alongside structured challenges. | Build on introductory objectives; expose economy, progression and difficulty settings. |

## Phase 3 — Infrastructure, maintenance and business decisions

| Planned feature | Intended gameplay or visual benefit | Dependencies and scope |
| --- | --- | --- |
| Terrain, bridges and tunnels | Balance construction cost against distance, grades and journey time. | Introduce terrain and elevation constraints before grade-dependent traction or weather effects. |
| Maintenance yards and breakdowns | Route trains to depots or maintenance sheds. Neglected trains become slower, cost more to run, or break down and block single-track sections. | Add condition, maintenance schedules, depot visits and repair/recovery actions. Depends on fleet identities and safe traffic reservations. Provide warnings and configurable difficulty. |
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

| Planned feature | Intended gameplay or visual benefit | Dependencies and scope |
| --- | --- | --- |
| Steam → diesel → electric eras | Advance through time or research investment. Early steam locomotives are affordable but slow; later electric trains offer high performance with costly electrification. | Add locomotive technology, operating costs, unlock rules and overhead catenary infrastructure. Validate that electric services have suitable electrified routes. Make era progression configurable for sandbox play. |
| Research and technology tree | Invest in better signalling, higher-speed track, efficient locomotives and advanced cargo handling for long-term goals. | Use one unlock system shared with historical eras rather than separate conflicting progressions. Show prerequisites, research costs and benefits, with configurable time-based or investment-based progression. |
| Dynamic weather and seasons | Add rain, snow and autumn foliage. Snow can slow mountain passes or increase running costs; rain can reduce traction on steep inclines. | Separate visual effects from optional simulation penalties. Terrain grades and traction must exist before grade-based effects. Forecasts and clear status messages should explain operational changes. |
| Day/night and dynamic lighting | Add station lights, headlamps and readable signals through a changing visual day. | Rendering follows simulation time without driving it. Night restrictions or comfort effects are optional and disabled until their supporting systems exist. |
| Company valuation, milestones and sustainability | Track company value, passenger-distance, freight movement, punctuality, reputation and optional emissions-related incentives. | Aggregate measured service data; add technology-based emissions only with eras and energy costs. Keep environmental scoring optional in historical sandboxes. |
| Dynamic events and disruptions | Introduce temporary closures, sudden demand surges and other challenges that prompt network adjustments during sandbox play. | Reuse demand, contracts, weather and maintenance systems where appropriate. Give events clear duration, advance information when appropriate, recovery conditions and configurable frequency. |

## Phase 5 — Building tools, spectators and community content

| Planned feature | Intended gameplay or visual benefit | Dependencies and scope |
| --- | --- | --- |
| Blueprints and copy/paste track designs | Save and reuse junctions, loops and terminal layouts. | Stabilise junction, signal and platform data first. Preview the full cost, land requirements and conflicts before placing a blueprint; support Undo for the whole placement. |
| Camera tools, spectator views and traffic overview | Expand existing camera scrolling and the minimap with free-camera controls, train-follow/ride-along mode, close station views with minimal UI, and a network traffic-density heat map. | Use stable train targets and traffic measurements, an easy return to normal controls, and protection against accidental construction while watching. Spectator controls can arrive earlier; the heat map builds on dashboard data. |
| Procedural maps and shareable seeds | Generate terrain, rivers, towns, industries and resources with adjustable size/density and reproducible starts. | Requires Phase 0 RNG ownership, versioned generator settings and map validation. Share seed plus generator/game version and settings; a seed alone does not promise identical maps across releases. |
| Photo mode and sharing tools | Capture screenshots with optional route-name and train-information overlays for sharing. | Build on camera tools and selectable UI visibility. Start with local image export; keep posting to external services a deliberate player action. Video/GIF export is deferred outside core scope. |
| Railway sound design | Give locomotives distinct horns and rail sounds, add station announcements, and use ambient audio to make the network feel alive. | Use spatial sound tied to train type, speed, distance and station events; scale platform crowd ambience from visible queues. Provide separate volume controls and visual equivalents for important audio cues; use appropriately licensed or original assets. |
| Level and scenario editor | Create maps, place industries and define delivery challenges for sharing. | Define a versioned content format, validate maps and objectives, and separate scenario definitions from saved sessions. Start with local import/export and sharing through community forums. Steam Workshop integration is a later distribution-specific option, not a requirement for using the editor. |
| Blueprint browser | Tag and search saved junction, loop and terminal designs; preview footprint, cost and compatibility before placement. | Extends blueprints with versioned local import/export. Reservation-aware conflict checking must already exist. |
| Town names, company lore and scenario flavour | Rename towns and add short generated histories, industry descriptions and regional needs such as commuter relief, export access or industrial revival. | Use lightweight local templates and editable text. No external generative service is required. |
| Tourism, special trains and railway heritage | Offer scenic excursions, seasonal/royal/military services, preservation lines and an encyclopedia or railway museum. | Start as optional scenarios/contracts using existing routes, amenities and scenery data. In-world trophies or locomotive decals are low-priority cosmetic rewards. |
| Lightweight modding | Support custom scenarios, train sprites and simple cargo definitions to extend the game and encourage community contributions. | Reuse scenario formats and data-driven vehicle/cargo definitions. Document schemas, asset requirements and version compatibility; validate content and report missing assets clearly. Start with data and asset packs rather than requiring executable mods. |

## Modes, learning and accessibility — across all phases

| Planned feature | Intended gameplay benefit | Dependencies and scope |
| --- | --- | --- |
| Tutorial campaigns with progressive unlocking | Teach track building → stations → signals → contracts → growth, one system at a time. | Expand introductory objectives into guided scenarios as each system becomes available. Provide contextual explanations, repeatable lessons and an option to skip tutorials. |
| Difficulty modifiers | Offer higher running costs, stricter contracts, optional no-pause play, and adjustable maintenance, weather and event pressure. | Present modifiers explicitly when creating a game and save them with the scenario. Keep a relaxed sandbox preset; ensure no-pause play still offers a usable route-editing workflow instead of relying on the current automatic pause. |
| Seeded challenges and asynchronous community play | Offer daily/weekly seeds, campaign medals and score comparisons for profit, punctuality, efficiency or optional environmental goals; share results and seeds asynchronously. | Requires deterministic starts, versioned rules and explicit modifier eligibility. Start with local or manually shared results before hosted leaderboards and validation infrastructure. |
| Ghost networks and benchmark histories | Compare anonymised network layouts, construction timelines or performance against a benchmark. | Share versioned summaries or recorded timelines first. Executable deterministic replays additionally need an initial state, tick-stamped commands, RNG state and verification—not just the event log or position buffer. |
| Achievements and challenge packs | Add replayable goals such as delivering a passenger target without delays or connecting every town below a track-length budget. | Extend scenario objectives with measurable constraints and clear eligibility rules for difficulty settings. Support local progress first; platform achievements are optional integration work. |

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

## Consolidated implementation priority

1. Integrate and verify Phase 0: fixed ticks, owned RNG, coherent versioned saves,
   events, remapping, UI scale, colourblind/high-contrast modes and reduced motion.
2. Junctions, reservations, signals, physical deadlock recovery, directional
   broken-track checks, waypoint routing and Shuttle/Loop modes (implemented).
   Independent active passenger services, signal-limited reservation lookahead,
   passing-loop directives, safe withdrawal/storage and saves are now implemented.
   Multiple trains per service and priorities build on that foundation.
3. Reservation-aware planning, overlays, batch edits, search and alerts. Begin with
   measured congestion indicators; predictive bottleneck advice waits for demand data.
4. Consists/templates, vehicle comparison, safe service edits and replacement rules.
5. Destinations, timetables, transfers, catchments, satisfaction and freight depth.
   Expand forecasts and company dashboards only as the underlying data becomes useful.
6. Maintenance, depots, terrain, economy and optional workforce abstraction.
7. Eras/research, weather and events; controllers once interaction patterns stabilise.
8. Procedural maps, scenarios, campaigns, seeded challenges and community sharing.

Autosave and logs can land as soon as the save/event foundations are reliable; they
need not wait for controller support. Visual polish and sound can proceed alongside
the phases, with gameplay effects explicitly optional. Build the reservation layer
once and reuse it for preview, dispatch, work zones, recovery and eventual shunting.
Junctions, reservations, sustained deadlock detection, physical reversal, automatic
block signals, manual dispatch and ordered waypoints are integrated. Missing track
ahead on the current leg stops trains in place; a gap behind does not interrupt
delivery. After turning, the new leg is checked again. Shuttle/Loop route modes
and closing-leg waypoints are integrated. Multiple independent passenger services
now run together on shared tracks with selected passing-loop paths and signal
boundaries. Route inspection, signal-block authority overlays and directional
affected-service construction feedback are now implemented; see
[network inspection and testing](NETWORK_INSPECTION.md). Measured traffic waiting,
a bounded recent-wait overlay, searchable current problems and historical incidents
are now implemented; see [problems and waiting](PROBLEMS_AND_WAITING.md).
Operational notification preferences and safe fixed-tick automatic pause are now
implemented; see [notification controls](NOTIFICATIONS.md). Richer
reservation-aware multi-stroke construction drafts are implemented; see
[construction planning](CONSTRUCTION_PLANNING.md). Corridor selection and batch
signal drafting are now implemented; see [corridor signals](CORRIDOR_SIGNALS.md).
Next: reusable track blueprints and a local design browser.
Predictive traffic advice waits for timetable/demand data; multiple trains per
service follow the independent-service model. See [reservation behaviour and checks](RESERVATIONS.md).
