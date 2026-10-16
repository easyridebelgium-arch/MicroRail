# MicroRail
## Game overview, feature catalogue and player feedback

**Discussion edition: 15 October 2026**  
**Current gameplay snapshot: 3bd2913 · Save format 41**  
**Format: single-player desktop railway-management prototype**

**Update after this snapshot:** configurable rotating autosaves and recovery are now implemented (F70); see [usage and safety](AUTOSAVES.md). The optional [first-service checklist](FIRST_SERVICE_GUIDE.md), nearest-city suggestion and first-final-delivery feedback are also implemented. This is an initial slice of F63; full tutorial campaigns remain planned. [Useful-service measurement](USEFUL_SERVICE.md) (N01) is also implemented in save version 42; initial bounded city response (N02/N03) is now implemented in save version 43 ([rules](CITY_GROWTH.md)); broader reputation/jobs/urban expansion remain future work. [Service performance cards and persistent company watchlists](SERVICE_PERFORMANCE.md) are now implemented in save version 44. The [actionable network summary](NETWORK_SUMMARY.md) now combines operational issues and expansion opportunities with direct review actions, without another save change. The remaining catalogue describes the snapshot above.

This document describes what can be played today and what may be added later. Future features are proposals for discussion, with no promised release dates. Please use the feature IDs when giving feedback.

## 1. The game we are building

MicroRail combines the dispatching and network-management appeal of Rail Route with the passenger and industry logistics of OpenTTD, presented as a readable, low-resolution railway game.

You build track, connect cities and industries, buy trains, define services and improve the railway as demand and operating problems emerge. The aim is a satisfying balance between building, watching trains run, solving bottlenecks and making business decisions. A small solo-project scope means that clarity and useful railway decisions take priority over simulating every possible transport system.

**Core play loop:** build a connection → assign trains → transport people or goods → understand delays and finances → improve the network → expand.

Cities already create passenger requests. The snapshot originally planned city growth next. Initial bounded population response is now available; see the update above.

## 2. How to read the catalogue

- **C IDs — Current:** implemented in the prototype, subject to the limits described below.
- **N IDs — Next direction:** the immediate planned development focus.
- **F IDs — Future:** proposed additions or expansions; priority remains open to feedback.
- **D IDs — Deferred/outside core:** deliberately postponed, optional integrations or features outside the initial solo-project scope.

An existing feature may have a separate future extension. For example, automatic block signals exist now; advanced one-way signalling is future work. Similarly, station waiting satisfaction exists, but a full company reputation system does not.

## 3. Playable features today

### 3.1 Starting a game and exploring the map

| ID | Feature | Available behaviour |
| --- | --- | --- |
| C01 | Tutorial and city sandbox | Choose the original three-station tutorial or an empty city sandbox from New Game. Introductory objectives exist; a full guided campaign does not. |
| C02 | Reproducible city layouts | Enter a seed and choose 3–8 cities on an 80 × 50 flat map with four industry sites. Matching starts also depend on game/generator versions and settings. |
| C03 | Player-built city stations | Place horizontal five-tile stations near cities, with a building/platform preview, catchment, population, cost and refusal explanation. One station belongs to one city in this first version. |
| C04 | Camera and map navigation | Pan and zoom, use keyboard navigation with AZERTY/QWERTY support, and locate cities, facilities and trains through a minimap and search. |
| C05 | Desktop display controls | A large resizable/maximized play area, optional fullscreen and a remappable fullscreen shortcut. Interface scaling is separate from map zoom. |
| C06 | Simulation time | Pause or run at 1×, 2×, 5× or 10×, using a speed selector and remappable shortcuts. The clock shows game day and time. |

### 3.2 Track construction and railway safety

| ID | Feature | Available behaviour |
| --- | --- | --- |
| C07 | Mouse-based track laying | Connect or draw track with automatic straights, bends and diagonals. Extensions respect the original connection direction. Rotation shortcuts are unnecessary. |
| C08 | Automatic and manual junctions | Build branches and merge onto existing track with automatic switch placement; a manual Switch tool and crossing geometry also exist. |
| C09 | Demolition and construction costs | Drag-remove track; short right-click returns to Connect, while right-drag/hold removes track. Previews show costs/refunds, invalid placement and affected services. |
| C10 | Draft construction and Undo/Redo | Plan multiple rail/switch/removal strokes before committing, inspect the total quote, and apply a validated group. Supported construction edits have grouped Undo/Redo. Station purchases are separate and not undoable. |
| C11 | Shared-track reservations | Passenger and freight trains can share rails. Whole train bodies, occupied tiles and reserved track protect movement; switch locks remain until the tail clears. |
| C12 | Signals and manual dispatch | Bidirectional automatic block signals, manual stop signals and train Hold/Resume controls are available. Corridor tools place or remove batches of signals. |
| C13 | Deadlock detection and reversal | Detect sustained circular waits and inspect their causes. Reverse a train physically back toward its departure stop, retaining its load and position; recovery does not teleport it. |
| C14 | Track damage and incomplete routes | A train keeps its physical position when its route is broken. It may continue if the break is behind it and the forward journey remains clear; warnings explain what needs repair. |
| C15 | Passing loops and platforms | Waypoints and signal boundaries support configured passing loops. Compatible numbered platform sidings, measured lengths, fixed choices and Auto choices exist. Shuttle alternatives are checked before departure, not while approaching a platform. |

### 3.3 Fleet and service operations

| ID | Feature | Available behaviour |
| --- | --- | --- |
| C16 | Four locomotive models | Passenger Shuttle, Fast Passenger, Log Hauler and Heavy Log Hauler offer different purchase prices, capacities, speeds and running costs. |
| C17 | Individual fleet management | Buy, name, sell, store, withdraw and replace trains. Permanent IDs identify vehicles; stored spares are off-map rather than using physical depot tracks. |
| C18 | Separate train upgrades | Purchase speed and capacity upgrades independently, with separate prices. Upgrades belong to the vehicle, including when it is stored. |
| C19 | Coaches and wagons | Attach up to four passenger coaches or log wagons. Capacity, length, speed limits and running cost change; platform fit and safe editing conditions are checked. |
| C20 | Shuttle and Loop routes | Define ordered stops and choose a back-and-forth Shuttle or a closing Loop. Supported carriage routes include planned stop reversals and crossing figure-eights; arbitrary repeated track remains restricted. |
| C21 | Waypoints and directives | Add ordered pass-through track cells per passenger leg and outward freight route, allowing a service to use a bypass without adding a station stop. |
| C22 | Multiple passenger trains | Up to eight active passenger train/service instances in total, including linked ones, plus the current freight service. Trains can have independent routes or follow shared source instructions through linked services. |
| C23 | Route editing and duplication | Copy instructions into a draft, duplicate a passenger service, drag-reorder stops, link/unlink instructions and keep independent train identities. Route geometry changes require safe physical starting conditions. |
| C24 | Headway targets | Set a minimum origin-departure gap, measure actual gaps and see why a target may be unattainable. Linked trains share their group's headway. |
| C25 | Departure timetables | Set daily departure times by passenger stop/direction, including returns and Loop closing legs. Linked trains share scheduled slots; missed departures and departure delays are measured. |
| C26 | Arrival targets and guidance | Set optional directional arrival-time budgets and inspect punctuality, journey-time measurements and advisory feasibility ranges. These do not currently impose lateness fines or satisfaction penalties. |
| C27 | Route identities | Saved route colours and short labels appear in editors, overlays and train badges. Individual train names are supported; custom locomotive paint schemes are not yet available. |

### 3.4 Passengers, cities and station life

| ID | Feature | Available behaviour |
| --- | --- | --- |
| C28 | City-owned trip supply | Fixed city populations generate requests for other cities, with larger destinations attracting more trips. Missing stations or unusable services produce unmet-demand measurements rather than passengers at unrelated stations. |
| C29 | Destination queues and transfers | Passengers retain a final destination, can stay aboard through intermediate stops or change trains, and pay only at final delivery. Oldest eligible waiting groups board first. |
| C30 | Local and Express demand | Local passengers accept stopping services and transfers. Express passengers need a direct next scheduled leg over a sufficiently distant journey. In the city model, every fourth eligible distant request expresses that preference. |
| C31 | Differentiated fares | Current fixed fares are £5 per Local delivery and £10 per Express delivery. Receipts are recorded by class; the player cannot set fares yet. |
| C32 | Station amenities and queue capacity | Buy a Shelter, Waiting room and Kiosk to improve waiting capacity, comfort and attractiveness. Train capacity upgrades do not themselves create passengers. |
| C33 | Waiting satisfaction and demand response | Stations measure waiting experiences and comfort. Arrival attractiveness adjusts gradually; this is not yet a full reputation or end-to-end satisfaction system. |
| C34 | Journey, occupancy and capacity feedback | View original journey elapsed times, recent completion summaries, seat utilisation and passengers left behind through lack of capacity. Some live diagnostics reset on load. |
| C35 | City demand reports | Map labels show population. Station previews/inspectors and Find → City explain requests joining queues and requests blocked by missing stations, service, Express requirements or full queues. |

### 3.5 Freight and the company economy

| ID | Feature | Available behaviour |
| --- | --- | --- |
| C36 | Log transport | Produce logs at the forest, load a compatible freight train and deliver to the cargo terminal. Loading/departure rules, capacity and running costs apply. |
| C37 | A complete processing chain | Optionally install a sawmill and factory: logs → timber → finished goods → terminal. Processing time, recipes, storage and physical deliveries determine output; intermediate transfers do not pay terminal revenue. |
| C38 | Freight recovery and persistence | Freight cargo, production progress, inventories, train formation and recovery state survive loading. The current chain uses one freight shuttle/service. |
| C39 | Company accounts | Track cash, passenger/freight income, construction spend, fleet costs and operating costs, with an Accounts breakdown and measured operating profit. Full historical business graphs are still planned. |
| C40 | Bank loans | Borrow £1000, £2500 or £5000, one loan at a time. Fixed interest accrues, instalments are automatic, arrears are visible and early full repayment is possible. |

### 3.6 Planning, feedback, interface and saves

| ID | Feature | Available behaviour |
| --- | --- | --- |
| C41 | Direct inspection | Click a train/carriage, station or facility to inspect it; Inspect mode is also available. Train information distinguishes loading, timetable holds, traffic waits, route problems and deadlocks. |
| C42 | Why-waiting diagnostics | See the blocker, physical footprint, requests/authority, reserved blocks and switch locks, with relevant actions such as locating the blocker, releasing a hold or reversing safely. |
| C43 | Operational overlays | View service paths, signal blocks, hatched reservations and measured waiting hot spots. These display operational measurements, not guaranteed predictions of future traffic. |
| C44 | Problems, incidents and alerts | Search current problems/history, filter severity, jump to locations and acknowledge conditions. Configurable notifications can pause or optionally slow high-speed play when qualifying incidents occur. |
| C45 | Find and watchlists | Search trains, services, stations, cities and industries; filter, locate and pin objects; after the snapshot these pins are saved per company and survive loading/exiting. |
| C46 | Blueprints and local sharing | Capture reusable track/switch/signal layouts, search a local library and import/export validated JSON designs. Placement is priced and safety-checked; station blueprints, rotation and mirroring remain future extensions. |
| C47 | Grouped interface | A grouped icon ribbon, compact status/Accounts, collapsible Map/Goals panels, readable tooltips, route badges and a branded title screen are implemented. |
| C48 | Accessibility and controls | 100–200% UI scaling, colour-blind-safe/high-contrast options, text/shapes/patterns alongside colour, reduced-motion settings and keyboard/mouse remapping. Full controller support is future work. |
| C49 | Four manual save slots | Four independent games, a previous-save backup per slot, map/time/balance previews, Continue and explicit Load. New Game does not replace a saved file until Save is used. |
| C50 | Reliable simulation and saves | Fixed simulation steps and saved RNG state support repeatability. Supported old saves migrate; invalid loads are rejected before replacing the current game. This is not a guarantee of cross-version replay compatibility. |

## 4. Present limits and what feedback should take into account

- This is an evolving prototype, with placeholder/in-progress world artwork and a small stock/industry roster. The final appearance, soundscape, onboarding and balance are unfinished.
- City populations are fixed. The city sandbox starts with £5000; the tutorial starts with £1000 and its original stations/trains. A fresh city station normally costs £300 including five new rail tiles; a Passenger Shuttle costs £400. Values are provisional.
- There are 3–8 cities on one flat 80 × 50 map. Terrain, rivers, bridges and tunnels are not simulated yet. One station serves one city in the current catchment model.
- The active passenger-service limit includes linked instances. Freight currently has one service/shuttle and the initial log/timber/goods chain, rather than arbitrary cargo routes or a general freight network.
- Passing loops still need appropriate routes/waypoints, signal boundaries and sufficient clearance. Reservations do not make every layout deadlock-free or automatically choose every bypass.
- Auto platform changes are limited to supported choices and departure-time Shuttle checks. One-way signals, advanced automatic traffic priorities and in-motion arrival-platform switching are not available.
- Route/formation changes need safe starting conditions; there is no general moving-train route-editing system. Some repeated-path/long-consist combinations are refused.
- Historical diagnostic coverage varies: live waiting/occupancy measurements may reset on load, while saved journey, timetable, city-request and financial histories have their own bounded records.
- No general scenario editor, mod loader, multiplayer or full rival railway AI is currently provided.

## 5. Immediate development direction

| ID | Planned next step | Intended outcome |
| --- | --- | --- |
| N01 | Useful-service measurement | Implemented after the snapshot: matched request cohorts, final deliveries, pending journeys, arrived transfer legs and unmet reasons. See [measurement](USEFUL_SERVICE.md). Initial bounded response is also implemented; see N02. |
| N02 | Bounded city growth and decline | Implemented after the snapshot: six-hour assessments, small bounded changes, full-day grace and protection for unfinished/unknown journeys; existing track/stations remain intact. |
| N03 | Clear growth reasons and settings | Implemented initial slice: inspector reasons, next assessment/grace end, bounded history and saved Normal/Slower/Frozen rules. Deeper quality/industry scoring remains future work. |

## 6. Future feature catalogue

### 6.1 Better operations and building tools

| ID | Proposed feature | Intended gameplay benefit |
| --- | --- | --- |
| F01 | Advanced signalling | Add one-way, route and platform signal modes with clearer dispatch control and direction-aware recovery rules. |
| F02 | Train priorities and fair dispatch | Let Express, Local and freight receive appropriate priorities and player overrides, while preventing starvation and retaining safe movement. |
| F03 | Broader deadlock recovery | Offer more automatic turn-back, alternate routes and valid reversing locations; later include recovery locomotives and yard actions. |
| F04 | Easier passing-loop routing | Help trains use suitable passing places while respecting deliberate waypoint choices; make shared station approaches easier to understand. |
| F05 | Richer platform selection | Extend safe platform choice to more route situations, passenger preferences and potentially arrival-time changes; account for direction, length and transfer convenience. |
| F06 | Directional and return waypoints | Add directional directives and independently controlled Shuttle return paths rather than automatically reversing the outward path. |
| F07 | Wider repeated-path support | Broaden supported train-body geometry beyond the current loops, planned reversals and crossing figure-eights. |
| F08 | Deferred service edits | Apply route/formation changes after a trip or at a suitable depot, without moving trains unexpectedly or interrupting accepted journeys. |
| F09 | Fleet automation and comparison | Compare compatible vehicles, save formation templates and optionally automate replacement or capacity increases with visible costs. |
| F10 | Better planning and path advice | Recommend routes with estimated cost/time, itemise more construction costs and flag evidence-based single-track bottlenecks and affected services. |
| F11 | Expanded corridor tools | Add double-tracking, speed upgrades, electrification and platform batches when their underlying systems exist. |
| F12 | Richer blueprints | Include compatible stations/platforms, rotation, mirroring, tags and footprint/cost thumbnail previews. |
| F13 | More persistent search and alerts | Company watchlists are now persistent. Saved search presets and refined actionable notification filtering/operational labels remain future work. |

### 6.2 Passenger demand and service quality

| ID | Proposed feature | Intended gameplay benefit |
| --- | --- | --- |
| F14 | Timed transfers and holding rules | Wait for connections or a target load within a maximum waiting window, and explain missed connections and knock-on delays. |
| F15 | More complete scheduling | Extend headway controls and arrival planning, with appropriate service-quality consequences and transparent feasibility guidance. |
| F16 | Richer passenger preferences | Gradually add business, tourist and budget priorities alongside commuters/Express, with understandable choices around frequency, comfort, scenery and punctuality. |
| F17 | Fare controls and elasticity | Set service/class fares or off-peak discounts and see how prices affect demand and revenue. |
| F18 | Full company reputation | Extend waiting satisfaction into documented journey, punctuality and crowding scoring, unlocking stronger demand, contracts or subsidies. |
| F19 | Demand and bottleneck adviser | Estimate future queues, platform demand and shortages using measured history, with clickable evidence and clearly labelled forecasts. |
| F20 | Wider catchments and feeder access | Show walking access, workplaces and competing stations; support several stations per city with explicit allocation and abstract bus/tram/park-and-ride feeders. |
| F21 | Detailed station life | Draw waiting pixel passengers and boarding activity from actual queue counts, grouping sprites for performance. |
| F22 | Expanded passenger facilities | Add priced improvements for loading/dwell and service quality beyond existing shelters, waiting rooms, kiosks and platform geometry. |

### 6.3 Freight, industry and business

| ID | Proposed feature | Intended gameplay benefit |
| --- | --- | --- |
| F23 | General cargo networks | Expand the first processing chain into more industries/recipes and independent freight routes/services. |
| F24 | Special cargo behaviour | Add perishables, hazardous loads and high-value express freight with visible spoilage, handling, speed or delivery requirements. |
| F25 | Mail and parcels | Carry smaller high-value consignments, possibly in compatible passenger formations with explicit shared capacity. |
| F26 | More rolling stock | Add coach classes, boxcars, tankers, hoppers and flatcars with distinct suitability, loading rates and capacity. |
| F27 | Freight and energy facilities | Build warehouses, handling upgrades and, when locomotive energy is modelled, fuel facilities. |
| F28 | Delivery contracts | Accept quantities/deadlines with clear rewards and failure terms; connect punctuality to contract payouts when that system is ready. |
| F29 | Industry growth | Let useful supply and deliveries support bounded production/industry expansion, preserving recipe and storage accounting. |
| F30 | Marketing and public-service support | Offer temporary promotion, subsidies or regional obligations with stated frequency/fare requirements and penalties. |
| F31 | Deeper operating budgets | Separate fuel/energy, maintenance, workforce, station upkeep, interest and penalties as those costs become real systems. |
| F32 | Expanded finance | Add variable lenders/rates, forecasts and insolvency rules; extend the existing fixed-rate loan system carefully. |
| F33 | Leasing and used vehicles | Trade lower upfront costs against leasing terms, condition, reliability and operating expenses. |
| F34 | Land and transit rights | Buy access or land before expansion makes it expensive; integrate ownership with construction previews. |
| F35 | Limited rival bidding | Consider competition for industry rights or territory once contracts/land systems are stable. This is separate from full railway-building AI. |
| F36 | Factual company journal | Turn real incidents and shipments into bounded headlines and optional passenger/cargo stories without obscuring operational logs. |

### 6.4 Infrastructure and maintenance

| ID | Proposed feature | Intended gameplay benefit |
| --- | --- | --- |
| F37 | Terrain, bridges and tunnels | Weigh grades, construction cost and route distance; introduce infrastructure challenges beyond the flat map. |
| F38 | Rivers, regions and landmarks | Create recognisable countryside, Alpine, Nordic, desert, tropical or urban settings with meaningful crossings and optional regional differences. |
| F39 | Depots and stabling | Provide physical spare-train storage, layovers and cleaning away from running lines, with capacity and safe access. |
| F40 | Maintenance yards and breakdowns | Add condition, servicing visits, warnings, repairs and possible temporary bottlenecks. Mechanical penalties should be adjustable, including no-breakdown play. |
| F41 | Track wear, rail classes and weight limits | Make heavy trains and stronger rail a maintenance/cost choice, with visible conditions and routing constraints. |
| F42 | Work zones and slow orders | Apply temporary, explained speed restrictions for works, damage or supported weather effects. |
| F43 | Optional workforce abstraction | Merge crew/staff ideas into one mostly automatic system affecting cost, fatigue, skills and service quality, without detailed personal rosters. |
| F44 | Shunting and yard operations | Split/merge formations, reverse at suitable facilities and operate depot/recovery movements where these create useful decisions. |

### 6.5 Progression and a changing world

| ID | Proposed feature | Intended gameplay benefit |
| --- | --- | --- |
| F45 | Historical eras and electrification | Progress from steam to diesel to electric, with infrastructure and operating trade-offs; electric trains need suitable wired routes. |
| F46 | Research and technology | Use one coherent unlock system for signalling, track speed, locomotives and cargo handling, with optional time/investment progression. |
| F47 | Weather and seasons | Add rain, snow and autumn appearance; optional operational effects follow actual terrain/traction systems and clear forecasts. |
| F48 | Day/night lighting | Add station lights and headlamps while keeping signals readable; operational night restrictions remain optional. |
| F49 | Valuation, milestones and sustainability | Measure company value, passenger/freight movement and service quality; consider optional era-aware environmental goals. |
| F50 | Dynamic disruptions and surges | Introduce closures, temporary demand spikes and events with clear durations, recovery conditions and adjustable frequency. |

### 6.6 Presentation, spectators and community

| ID | Proposed feature | Intended gameplay benefit |
| --- | --- | --- |
| F51 | Finished low-resolution art | Refine world/building/train assets and animation into a consistent visual style; toolbar graphics are already partly integrated. |
| F52 | Custom liveries and cosmetic rewards | Paint fleets with selectable palettes; keep operational labels readable and basic palettes freely available. Unlock extra liveries/themes through achievements. |
| F53 | Railway soundscape | Add locomotive horns, rail sounds, station announcements and ambient audio, with volume controls and visual alternatives for important cues. |
| F54 | Train-follow and spectator cameras | Follow a train, watch a station or use a minimal-UI ride-along view, with an easy return to building controls. |
| F55 | Richer overview and statistics | Add measured traffic-density views and historical company/route graphs for profit, ridership, occupancy, delays and incidents. |
| F56 | Photo mode and local sharing | Export screenshots with optional route/train overlays and selectable interface visibility. Posting externally remains a deliberate player action. |
| F57 | Recent visual replay | Watch a bounded recent history, approximately ten simulation minutes, and revisit incidents. Visual replay is distinct from undo, rollback and deterministic replay. |
| F58 | Full procedural terrain settings | Expand seeded starts to adjustable map size, rivers, terrain and resource/industry density. Share versions/rules with seeds for reproducibility. |
| F59 | Level and scenario editor | Create maps, industries, objectives and delivery challenges, starting with validated local import/export and forum sharing. |
| F60 | Lightweight modding | Support documented scenario, sprite and cargo/vehicle data packs, with clear compatibility checks. |
| F61 | Town names, lore and regional stories | Add player town renaming, editable local histories, industry flavour and regional needs without requiring an online generative service. |
| F62 | Tourism and railway heritage | Offer optional scenic, seasonal, royal/military or preservation scenarios, special services, an encyclopedia/museum and cosmetic trophies. |

### 6.7 Modes, learning, accessibility and longevity

| ID | Proposed feature | Intended gameplay benefit |
| --- | --- | --- |
| F63 | Guided tutorial campaigns | Teach track, stations, signals, transfers, contracts, incidents and growth one system at a time, with repeatable/skippable lessons and contextual help. |
| F64 | Sandbox and difficulty modifiers | Add unlimited money, slower/no growth, cost/contract pressure and optional no-pause rules. Maintenance/weather/event controls arrive with those mechanics. |
| F65 | Scenario packs and challenges | Combine low cash, track budgets, single-track restrictions or punctuality goals with achievable objectives and explicit scoring. |
| F66 | Achievements and cosmetic unlocks | Reward measurable goals such as efficient town connections or on-time deliveries, with optional platform achievements and extra cosmetic themes. |
| F67 | Shared seeds and asynchronous competition | Share runs, campaign medals and results manually first; consider daily/weekly challenges after formats are stable. |
| F68 | Ghost networks and benchmarks | Compare layouts or construction/performance histories. Executable deterministic replays need additional recording and verification beyond existing logs. |
| F69 | Controller and Steam Deck support | Add stable focus/navigation, suitable menus and possibly radial controls once the core interface settles. |
| F70 | Periodic rotating autosaves | Implemented after the snapshot: three recovery copies per manual slot, configurable game-time interval, title/in-game recovery and protected manual saves/backups. See [autosaves](AUTOSAVES.md). |

## 7. Deliberately deferred or outside the core release scope

| ID | Feature | Current scope decision |
| --- | --- | --- |
| D01 | Detailed electric power grids | Defer substations, distribution and load management. Basic route electrification is the earlier goal. |
| D02 | Insurance and detailed disaster finance | Defer; basic incident repair/recovery remains in the maintenance direction. |
| D03 | Airports and operating ferries | Outside the initial railway scope. Ports/intermodal facilities may instead act as rail cargo origins or destinations. |
| D04 | Cooperative multiplayer | Outside core scope until simulation, saves, commands and networking rules are proven; the current foundations are not a multiplayer promise. |
| D05 | Full competitor railway-building AI | Defer. Limited bids/rights competition is the smaller possible future mechanic. |
| D06 | Detailed staff rostering | Defer personal shifts/rosters in favour of the single optional workforce abstraction. |
| D07 | Cinematic scripting and video exports | Defer video/GIF/time-lapse export and elaborate camera scripting; photo tools and visual replay are earlier candidates. |
| D08 | Hosted leaderboards and Steam Workshop | Optional later integrations after local sharing/challenge formats work. They are not required for the base editor or game. |

## 8. Feedback we would like from players

You do not need to be a railway expert or a programmer. Comments about confusion, enjoyment, pace and things you would remove are as useful as new feature suggestions.

### 8.1 Quick response form

Copy this section into your reply, or send it as a separate document.

- **Name or nickname (optional):**
- **Experience with railway/transport games:** new / occasional / experienced
- **Have you played this prototype?** yes / no; if yes, give build/commit, mode and approximate time played.
- **What most appeals to you about the concept?**
- **Your five highest-priority future features:** list N/F IDs in order, with a short reason.
- **Three features you would postpone or remove:** list IDs and reasons.
- **Preferred emphasis:** network dispatch / open-ended building / passenger service / freight logistics / business strategy / watching trains / a mixture.
- **Preferred complexity:** relaxed / balanced / demanding. Which systems should always be optional?
- **What would make you return after the first session?**

### 8.2 Questions for people who have played

1. Was it clear how to build stations/track and start the first useful service? Where did you get stuck?
2. When a train waited, could you understand the cause and find a useful action? Give a specific example.
3. Were passing loops, signals, waypoints and platform choices understandable? What explanation or preview was missing?
4. Could you distinguish a Shuttle from a Loop and independent routes from linked trains?
5. Did city population, trip requests and unmet-demand reports explain where passengers came from? Was 'joined queue' clearly different from 'delivered'?
6. Did the first network feel affordable? Which costs, fares or upgrade choices felt too generous or too restrictive?
7. Did schedules, headways, arrival targets and passenger classes create interesting decisions or extra administration?
8. How readable were the toolbar, map, inspectors and alerts at your screen size/UI scale? Were any cues dependent on colour or hard to operate?
9. Did 1×/2×/5×/10×, pause and incident notifications provide the control you wanted?
10. What was your most satisfying moment, and your biggest frustration?

### 8.3 Questions about the future direction

1. Should city growth reward frequent, reliable, completed journeys, broad destination coverage, low fares, or another measure? What would feel unfair?
2. Would you enjoy maintenance and breakdowns? What warning/recovery options and relaxed settings would you need?
3. Would terrain, bridges/tunnels and historical electrification add more value than a larger cargo or locomotive roster?
4. Is deeper finance/reputation attractive, or would it distract from the railway?
5. Would you primarily play sandbox, hand-crafted scenarios, seeded challenges or an introductory campaign?
6. How much priority should art, sound, station crowds, custom liveries and spectator cameras receive compared with new management systems?
7. Would you create or share blueprints, scenarios or data/asset mods? Which sharing format would you actually use?
8. What important railway decision is missing? If you add a feature, suggest one existing proposal it could replace or postpone.

### 8.4 Reporting a reproducible problem

Please include the build/commit, tutorial/city mode, seed and city count where relevant, simulation speed, steps to reproduce, expected/actual behaviour and the exact inspector message. A screenshot or save file helps if available. Do not include personal information you do not want shared.

For each suggestion, this format is useful: **Feature ID → problem or benefit → proposed change → priority (must/should/could) → complexity you would accept.**

## 9. Project context and document scope

MicroRail currently uses Godot and GDScript. The design favours a reliable simulation, safe saves, accessible controls and a small coherent railway game. Low-resolution artwork and animation are being prepared; their presence in planning does not imply that every visual set is integrated.

This edition is a discussion snapshot, checked against the current implementation and feature documentation. Older roadmap paragraphs sometimes describe earlier stages; this catalogue uses current behaviour for linked services, platform choices, schedules and city demand. Future priorities can change after feedback, and no purchase, distribution, release-date or multiplayer commitment is implied.

Developer reference: [development roadmap](ROADMAP.md), [starting a game](NEW_GAME.md), [city demand](CITY_DEMAND.md), [platforms](PLATFORMS.md), [route copying/linked trains](ROUTE_COPY.md), [timetables](TIMETABLES.md) and [save guarantees](CITY_SAVES.md).
