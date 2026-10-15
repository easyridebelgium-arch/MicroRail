# MicroRail development roadmap

This roadmap records the agreed development order, current implementation and
remaining work. Phases are milestones, not release dates. Preserve completed work
when regrouping features; an implemented feature in a later phase does not need to
be removed or rebuilt. Godot and GDScript remain the core development tools.

For a player-facing catalogue of current and proposed features, with stable IDs
and a feedback questionnaire, see [Game overview and player feedback](GAME_OVERVIEW_AND_FEEDBACK.md).

## Current position

| Milestone | Current status | Work still needed to close the milestone |
| --- | --- | --- |
| Phase 0 — Foundations | Implemented; requirements remain active for every update. | Continue deterministic, save and accessibility checks. Full input replay/controller support are later extensions. |
| Phase 1A — Network integrity | Core implemented and covered by regression tests. | Broaden safety coverage as new platform/body combinations arrive; preserve basic waiting explanations throughout. |
| Phase 1B — Service operations | Partially complete. | Other repeated-path body routing (planned reversals at stops and crossing figure-eights are done), arrival-time platform switching (lengths, numbering, assignment rule and fixed per-stop sidings exist). Linked services (several trains per route) are done. |
| Phase 1C — Planning and feedback | Substantial functionality implemented; milestone incomplete. | Evidence-based structural warnings and richer measured planning. Alert acknowledgement/persistence and optional incident slowdown are implemented. Unified waiting inspection is implemented. |
| Phases 2A–2C — Demand, freight chains and growth | Phase 2A demand foundations implemented; Phase 2B first complete freight chain implemented; Phase 2C catalog, generator, station-purchase and empty-start models implemented; main-scene/editor/station UI integrated in a development preview; generated saves and ordinary seed chooser implemented; city-owned population and trip supply implemented; growth/decline pending. | Direct destination journeys and frequency/timetables implemented; Richer satisfaction, processing chains and growth/scenario rules remain; station waiting-area amenities are implemented. |
| Phases 3–5 — Maintenance, progression and community | Mostly planned; some building/sharing tools already exist. | Add systems only when their prerequisites and player-facing benefits exist. |

**Current-stage UI work is complete:** all twelve items in the table below are
implemented. The final batch adds saved route identities, text/shape signal cues,
a persistent actionable alert banner with acknowledgement, optional incident
slowdown, map/time/balance save previews and the branded title menu. Save version
28 adds validated appearance/acknowledgement data; version 27 migrates to defaults.
These presentation changes preserve physical train positions and routing rules.

**Latest economy/UI update:** fixed-rate bank loans, accruing interest, automatic
instalments, arrears and early repayment are implemented ([bank loans](LOANS.md)).
The initial bank offers use one loan at a time, 1% per game hour and ten hourly
principal instalments. Save version 27 persists debt and migrates older games to
zero debt. Shared Map/Goals visibility and consistent facility inspectors are also
implemented. Grouped ribbon, compact status/Accounts and summary-first
train inspection with expandable reservation details are implemented. Four independent
manual game slots retain separate backups;
the slot chooser and fresh-game action remain available. The existing save is Slot 1.
See [save slots](SAVE_SLOTS.md). Configurable rotating autosaves and recovery are now implemented ([autosaves](AUTOSAVES.md)).
Toolbar refinement instructions are in the [Krita guide](../assets/ui/toolbar/KRITA_GUIDE.md).

**Latest gameplay batch:** Phase 2A connecting journeys are implemented. A–B
plus B–C carries A→C riders through a physical interchange at B, retaining the
final destination and paying only at C. Enabled/unheld complete services feed a
deterministic fewest-change graph. Station/train inspection explains connections;
withdrawn connections leave accepted passengers safely queued. Save version 29
preserves these manifests; version 28 upgrades without moving trains.

**Latest fairness batch:** oldest eligible station arrivals now board first, with
forward-stop order breaking equal-age ties. Partial groups keep their arrival ticks;
interchanges/recovery join the receiving queue at physical arrival. Station
information shows oldest waiting seconds per destination. Save version 30 preserves
priority; version 29 initializes unknown ages at its saved tick without changing
counts/positions. This measures station waiting, not total journey age. A primary Loop withdrawal
now continues past home when accepted through riders still need delivery; it
parks only when empty. The Loop regression checks this recovery after repairs.

**Latest satisfaction batch:** measured waiting-experience scores are implemented
in stations and Accounts, with live queues, bounded boarding history, explicit
amenity comfort and passenger-weighted ratings. Save version 31 preserves the
history; version 30 upgrades without changing arrival groups or positions.
This is station waiting satisfaction, not end-to-end journey or punctuality scoring;
see [passenger satisfaction](PASSENGER_SATISFACTION.md).

**Latest demand batch:** arrivals respond gradually to station waiting satisfaction,
with a saved 50–125% factor, at most one percentage point per normal arrival
interval. Growth above 100% requires recent boarding evidence and an enabled
connection. Station/Accounts explanations distinguish the current rate from the
target. Save version 32 retains factor/carry; existing passengers and queue caps
are preserved. See [demand response](DEMAND_RESPONSE.md).

**Latest journey batch:** original passenger origin/start ticks now survive
boarding, transfers, through stops, physical reversal/recovery and reboarding.
Accounts shows passenger-weighted recent completed times and origin/destination
breakdowns; train inspectors show tracked onboard elapsed time. Save version 33
preserves clocks and validates totals against manifests. Legacy origins remain
explicitly unmeasured. See [journey times](JOURNEY_TIMES.md).

**Latest occupancy batch:** passenger train inspectors show live seats used and
recent seat-time-weighted utilisation. Accounts adds company full-time and station
left-behind opportunities. Fixed-tick sampling includes enabled service waits and
dwell, excludes parked withdrawals, and follows permanent vehicle IDs and actual
capacity. Bounded occupancy diagnostics reset on load and introduced no change to version 33. No crowding
penalty is applied yet. See [occupancy feedback](PASSENGER_OCCUPANCY.md).

**Latest arrival batch:** optional directional journey targets capture the served
scheduled departure (or actual departure for unscheduled legs). Train inspectors
show active targets; Routes/Accounts report recent trip punctuality with an explicit
one-game-minute grace. Saved snapshots survive timing edits and loads; recovery
cancels unfinished measurements. Save version 34 preserves this bounded history.
No penalties or automatic target feasibility claims are applied.
See [arrival targets](ARRIVAL_TARGETS.md).

**Latest guidance batch:** Routes shows advisory travel-time ranges from draft
graph geometry and assigned train speeds, including linked trains, speed upgrades
and rolling stock limits. It distinguishes too-short budgets from targets relying
on grace and budgets that still need traffic margin. Routes/Accounts report
running time, positive arrival lateness and scheduled departure delay separately
for each direction. Diagnostics derive from existing history without changing
saved targets, movement or fares; save version remains 34.

**Latest passenger-class batch:** one in four newly generated A↔C passengers is
Express and waits for a service whose next stop is the final destination. Local
passengers retain stopping-service and transfer eligibility. Saved original
journey groups preserve preference through partial boarding and physical recovery;
Routes/station Details/train inspectors/Accounts explain the rule. Generation
adds no RNG draws or demand. Save version 35 keeps counters and metadata; older
passengers remain Local. This eligibility batch originally used flat £5 fares; version 36 adds the Express premium.
See [passenger classes](PASSENGER_CLASSES.md).

**Latest fare batch:** Local pays £5 and Express pays £10 once at the final
destination. Cumulative paid-delivery receipts are independent of bounded journey
history. Header profit and Accounts use actual income with class/legacy breakdowns.
Save version 36 persists receipts and reconciles them with delivered counts; old
flat-fare deliveries retain their £5 historical income without changing cash or
awarding retrospective premiums. Recovery/transfers remain unpaid until arrival.
See [recorded passenger revenue](PASSENGER_REVENUE.md).

**Latest freight batch:** Phase 2B versioned cargo/industry `.tres` definitions and
the optional £500 sawmill are implemented. It consumes 2 logs per timber every five
simulation seconds, keeps bounded inventories and pays £24 per timber only at the
terminal. Whole-train reservations and physical recovery remain authoritative.
Save version 37 retains production progress and freight stages; version 36 migrates
to the unchanged log-only service. Validation: 91 regression suites pass, including
39 focused sawmill checks. See [sawmill chain](SAWMILL_CHAIN.md).

**Latest factory batch:** the optional £800 factory completes the first freight
vertical slice. Timber is processed into finished goods every ten simulation
seconds; the terminal pays £40 per goods. Intermediate unloading remains unpaid,
with saved stock conservation and physical recovery. Save version 38 adds the
factory; version 37 keeps the existing sawmill service. Validation: 92 regression
suites pass, plus the final 30 focused factory checks. See [factory chain](FACTORY_CHAIN.md).

**Latest world foundation:** save version 39 stores a per-game facility catalog
with stable identities, geometry, labels, layout metadata and settlement references.
Drawing, map markers, facility protection and station labels use it; optional
industries immediately appear on the network map. Version 38 migrates the tutorial
without moving trains, changing cargo/passengers or consuming RNG draws. Current
gameplay still accepts only tutorial geometry while backend routing/demand is adapted.
Validation: 93 regression suites pass, including 34 catalog checks.
See [world catalog](WORLD_CATALOG.md).

**Latest catalog backend batch:** route validation/building, platform stop geometry,
retained-path reconstruction and directional clearance accept explicit station
catalogs. Local passenger queues, boarding/recovery and batch persistence use
per-instance station IDs. Tutorial defaults and schema 39 remain compatible.
Validation: 94 regression suites pass; the final focused suite passes 28 checks.
See [catalog routing and demand](CATALOG_ROUTING_AND_DEMAND.md).

**Latest station-state batch:** Local journey/interchange graphs, original journey
clocks/history, amenities, waiting satisfaction and demand response use catalog
identities. Arrival-target validation and Accounts/occupancy reporting enumerate
those stations too. Existing prices, demand bounds, timing and schema 39 are retained.
Validation: 95 regression suites pass; the final station-state suite passes 27 checks.
See [catalog station state](CATALOG_STATION_STATE.md).

**Latest facility/policy batch:** freight endpoints, processor stops and validation
use catalog positions. Express classification uses station distance (at least 32
tiles) and a direct next stop, preserving tutorial A↔C behavior while supporting
unfamiliar IDs. Counter/batch/journey validation uses the same per-game catalog.
Schema 39 and existing receipts remain unchanged. Validation: 96 regression suites
pass, and the final focused suite passes 25 checks. See
[catalog facilities and classes](CATALOG_FACILITIES_AND_CLASSES.md).

**Latest seeded-layout foundation:** the flat-grid generator produces 3–8 cities
and four freight sites from a seed, with validated station clearances, a separated
freight strip and land access. No stations, track or services are prebuilt. It
returns catalog geometry and RNG continuation; the tutorial loader and schema 39
stay unchanged. Validation: 97 regression suites pass; the generator suite passes
31 checks across 192 seed/density cases. See [generator](SEEDED_LAYOUT_GENERATOR.md).

**Latest station-construction backend:** previews link a horizontal five-tile platform
to the nearest city, with exclusive catchment ownership and itemized costs. Purchase
transactions recheck stale geometry, funds, signals and train claims; successful
snapshots preserve existing compatible rails. JSON station identity and routing are
tested. Validation: 98 regression suites pass, including 42 construction checks
covering 264 placements across 48 seeded maps. Main-scene placement/startup are now available in the development preview;
the normal seeded-game chooser and generated saving are now implemented. See
[city station construction](CITY_STATION_CONSTRUCTION.md).

**Latest empty-start construction model:** generated geometry, RNG continuation,
an empty fleet/network and station-owned state are initialized together. Station
purchases extend queues, amenities, measurements and journeys without resets or
free tutorial passengers. Explicit empty-start validation keeps existing save
checks strict. Validation: 99 regression suites pass, including 42 startup checks.
The model is now wired to the main scene in the development preview below. See
[empty sandbox startup](EMPTY_SANDBOX_START.md).

**Latest construction preview:** `scenes/dev/city_preview.tscn` inherits the main
scene and starts an empty seeded company. Fleet/Routes support absent primary
services; a Station tool previews catchments, footprints and costs and commits
JSON-safe fixed-tick purchases. Cities are visible and findable; passenger and
freight trains can be bought, routed and run under existing reservations. Adding
stations preserves operating trains and passenger state. Generated city saving is now implemented (below); the ordinary tutorial startup
remains unchanged. See
[launch steps and limits](CITY_SCENE_PREVIEW.md).
Validation: 100 regression suites pass; the final scene suite passes 31 checks.

**Latest generated-game persistence:** root save version 40 explicitly distinguishes
city companies and tutorial saves. All four slots and per-slot backups now support
empty companies, stored locomotives, passenger-only, freight-only and mixed games.
Geometry and physical train positions are restored directly, with queues, journeys,
loans, amenities, industry inventories and the live RNG stream. Full bodies are
validated before commit; reservations are rebuilt. Broken routes retain their
physical trains. Older tutorial saves migrate. Fleet also refreshes the departure/destination pair
at Start, including programmatic selection. Validation: all 101 regression suites
passed after correcting and rerunning the multi-service suite (58 checks); the
final city-save suite passes 60 checks. See [city saves](CITY_SAVES.md).

**Latest maintenance and playable startup:** naming/shadowing warnings and unused
helper parameters are cleaned up; planning/blueprint signals emit explicitly. Clock
and passenger-carry integer division retain their intentional whole-unit semantics
with local explanations, while global warnings remain enabled. A reusable script
warning audit is included ([maintenance](GDSCRIPT_MAINTENANCE.md)).

The title and in-game New Game chooser now offer Tutorial or City sandbox, a seed
and 3–8 cities, with validation, budget explanation and no automatic save overwrite.
Both modes retain the existing four-slot save/backup flow. A working first passenger
service is affordable in seven tested layouts, including boundary densities and
large seeds. Root save version 40 is unchanged. Validation: 102 suites covered;
the full batch passed 101, and the amenities fixture was updated to reopen its
inspector after loading and then passed all 25 checks. The new-game suite passes
44 checks, the warning audit checks 83 scripts, and all four planning/sharing
button signals were exercised. See [New Game](NEW_GAME.md).

**Latest city-owned demand:** saved city populations now own passenger requests;
station catchments admit them only when a usable service reaches the chosen city.
Destinations are population-weighted through the live seeded RNG. Local transfers,
direct Express eligibility, queue caps and existing amenity/response rules apply.
Missing stations/services, unserved Express and full queues are measured in a bounded
12-interval ledger; admitted queues retain their original times and destinations.
Map labels, station previews/inspectors and Find City show population and outcomes.
Root save 41 persists populations/carry/history and migrates v40 without moving
trains, changing accepted passengers or reseeding. Population remains fixed in this
slice. Validation: 104/104 regression suites pass on Godot 4.6.3; focused model
and scene suites pass 25 and 26 checks, and 84 game scripts pass the warning audit.
See [city demand](CITY_DEMAND.md).

**Seed chooser refinement:** both New Game entry points now have a **Random**
button beside the seed field. It chooses a different supported seed, keeps the
city count/slot, refreshes validation and leaves the running simulation RNG and
save files untouched. The chosen number remains editable/copyable for shared starts.
See [New Game](NEW_GAME.md).

**Game-menu refinement:** a visible Menu button beside Accounts and idle Escape
open Resume/active-slot Save/Settings/Return to Main Menu. Active tools cancel
first. Returning offers Save and Return, explicit Return Without Saving and Cancel;
a failed save keeps the current company available. Settings uses the same exit
flow. Simulation pause/speed, drafts, existing save slots and backups are preserved;
this is not periodic autosave. Menus scroll/clamp at 200% UI scale. See
[game menu and exit behaviour](GAME_MENU.md).

**Terrain-art integration:** summer grass is now the live default. Settings adds
Summer grass/Autumn leaves/Snow/Plain grid and grid visibility, persisted outside
game saves. Textures are muted, visible-area culled and clipped to the map; a dark
track bed keeps rails readable on snow. High contrast retains plain ground/grid.
All sixteen source materials, including deep/shallow water, are available as
named resources and in an F6 gallery. No dynamic seasons, water obstacles, bridges,
movement penalties or changes to seeded layouts are implied. See [terrain artwork](TERRAIN_ART.md).

**First-session playtest fixes:** the tutorial already starts its first train
automatically, so preserve that flow rather than adding a redundant route wizard.
Fresh Map/Goals preferences now start collapsed; camera/Home frame tutorial
stations below the header; automatic compact controls fit one row at 720p/default
scale. Connect mode marks valid passenger platform ends and explains horizontal
dragging. Unbuilt tutorial routes no longer open as incidents; established route
damage and freight-stage problems remain visible. The guide records the £150 A–B
cost and £100 connection reward. Follow-ups are Advanced scheduling, plain-language
refusals, station queue indicators, consistent dialog art and sandbox first-service
help. See [playtest evidence and acceptance checks](FIRST_SESSION_FEEDBACK.md).

**First-session guidance/save protection complete:** the optional, repeatable
[Guide checklist](FIRST_SERVICE_GUIDE.md), nearest-city suggestion, first-final-delivery
feedback and [rotating autosaves](AUTOSAVES.md) are implemented. Tutorial automatic
startup and existing rewards remain unchanged. City Goals shows the live next step;
the full guide opens only on request.

**Useful-service measurement implemented (2A / 2C):** [request cohorts and final
deliveries](USEFUL_SERVICE.md) now distinguish unmet requests, accepted unfinished
journeys, actual transfer legs and final completions. Older unfinished cohorts are
retained, recent history is bounded, and v41 saves migrate to an empty measurement
baseline in v42 without changing their passengers/RNG. City and station inspectors
show the results.

**Next implementation:** fair scoring and bounded city growth/decline.
Keep new-city grace periods, population floors, visible causes and slower/no-growth
rules. Match deliveries to their request cohorts; queued passengers do not earn
growth, and unfinished long trips must not count as instant failures. Arrival
budgets remain advisory until fair scoring rules exist.

Next expose the results through service performance cards, saved watchlists and
an actionable network summary (not an unexplained composite score). Add optional
progress reports and short scenarios, then river/bridge map variety before broader
terrain complexity. Contracts, fair dispatch priorities and full reputation follow
stable measurements. This is a development order, not a claim that the new items
are implemented. Rationale and acceptance points: [player feedback priorities](PLAYER_FEEDBACK_PRIORITIES.md).

**Artwork preparation:** an AI-generated source pack now contains seven sheets
with 112 proposed terrain, city, facility, vehicle, scenery, railway-equipment and
people/effect entries. Inventory, prompts, provenance and cleanup notes are in the
[art pack](../art/generated/microrail_pack_v1/README.md). A first selected subset is
now live: four locomotive appearances, standard/fast coaches, loaded log wagons,
station buildings, concrete platforms and forest/terminal/sawmill/factory graphics.
Measured atlas regions, fixed body/ground envelopes, existing hit targets and
high-contrast cues preserve the simulation. Empty wagons and processed cargo use
matching deck/plank/crate drawings. Other sheets remain candidates; see
[live world artwork and rendered preview](WORLD_ART.md).
Seasonal, terrain and stock artwork does not advance those gameplay mechanics.
Gradual city growth/decline follows measured service and unmet demand. See [seeded cities plan](SEEDED_CITIES_PLAN.md). Player fare controls, richer passenger
choices, timed connections and punctuality scoring remain planned refinements. Completed elapsed time is now measured; journey scoring
still needs explicit benchmarks rather than treating duration alone as lateness. Basic
waiting-based demand balancing is complete; population, player fare controls and richer
demand factors remain later refinements. Waiting-area amenities and the current UI work are complete.
Historical dashboards, expanded camera modes and optional gameplay branding remain
later enhancements. This closes the UI workstream, not every Phase 1B/1C extension.
Direct passenger
origins/destinations, per-destination queues, through riders and destination-only
fares are now implemented; see [passenger destinations](PASSENGER_DESTINATIONS.md).
Directional departure timetables and basic arrival targets are implemented. Contract
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
complete. The latest cloud validation covers all 90 passing headless suites in Godot 4.6.3
(full fare/revenue regression, including 25 revenue checks, 41 passenger-class checks, 34 guidance checks, 54 arrival-target checks, 22 capacity-feedback checks and 29 journey-timing checks), including 50 loan checks and
26 panel-preference/layout checks,
including the uploaded PNG ribbon, action bindings, selected/disabled states,
keyboard focus, live counters and wrapping at 100–200% UI scale, plus directional
departures, blocked-departure accounting and destination/dispatch save/load, passenger conservation, four independent manual slots,
version-26 station amenities, rename migration, version-27 debt persistence,
version-28 route identities/acknowledgements, title/save-preview/header layouts
and version-29 connecting passenger manifests, version-30 arrival cohorts and
version-31 satisfaction history, version-32 demand factor/carry, and version-33
journey provenance/timing. The 29 journey checks pass, including both real train
runtimes, transfer/reversal/recovery, final-only fares, atomic bad loads, legacy
queue ages, bounded history and equal 30/60/120 FPS results. The 29
demand-response checks pass, including actual held-connection gating, queue/RNG
protection, save continuation and equal 30/60/120 FPS results. The 28 satisfaction checks pass, including
score/comfort evidence, load validation, station overview, Accounts scaling and
30/60/120 FPS equality.
The 21 fairness checks and 40 Loop checks pass; both Loop and multiple-service
regressions now require withdrawal to finish accepted journeys and park empty.
Transfer queues, cash, aboard riders
and event timestamps match at 30/60/120 FPS.
The final eight focused UI suites pass after the layout adjustment, and threaded
title-to-New startup passes an isolated smoke check. Earlier gameplay
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
[station amenities](STATION_AMENITIES.md). Basic transfers, waiting-age fairness, waiting-experience satisfaction, gradual demand response, complete journey timing and occupancy/capacity-denial measurement are implemented; directional arrival targets and basic punctuality are implemented; advisory feasibility guidance and per-direction reports are implemented; Express/Local classes and direct-leg eligibility are implemented; differentiated fares and recorded revenue are implemented; Phase 2B now has its first complete single-shuttle freight chain.

**Rename checkpoint:** the project is now **MicroRail** (formerly "Trainz", a name already in use by another
game). Project name, window title, docs and save filenames (`microrail_save*`) are renamed. On first launch
`LegacyMigration` copies saves and settings from the old `Trainz` user-data folder into the new `MicroRail`
one (copy only, never overwrites, old folder left intact); see [save slots](SAVE_SLOTS.md). All 75 headless suites pass (run `godot --import` once after a fresh clone).

## Current-stage UI enhancements — Phase 1C / Phase 2A

All twelve improvements below are implemented. Maintain them alongside gameplay; retain the authoritative graph, reservations,
fixed clock, accessibility and atomic saves. Presentation must not alter movement
rules or hide actionable waiting causes. The grouped ribbon, compact status/Accounts and summary-first inspection remain available. See [UI clarity](UI_CLARITY.md).

| Improvement | Current status and next acceptance point |
| --- | --- |
| Grouped toolbar | Implemented: Construction, Operations, Inspection, Games/Settings with supplied separators. Pause/Speed and Save/Load remain adjacent. Flat controls wrap independently; compact mode reduces button size so 200% UI scale still leaves map space. |
| Compact status bar | Implemented: clock, balance, session operating profit, delivered passengers and Accounts. Detailed revenue/spend/queue figures move to a paused, scrollable Accounts window. Historical dashboard graphs follow measured metrics. |
| Collapsible panels | Implemented: Map/Goals visibility persists in shared player preferences across sessions/slots; toggles restore in sync. Existing layout reclaims space when panels are hidden. |
| Consistent inspectors | Implemented: train and facility overviews precede actions and expandable detail. Station/industry upgrades, amenities and loading rules remain available. Facility Close stays outside scrolling content; sidebar width is scaled once and clamped to the logical viewport. Bank uses the same readable, scrollable dialog theme. |
| Clear waiting explanations | Implemented: current blocker identity in the summary and direct Inspect blocking train action; reservation detail collapses independently. Retain honest stale-allocation warnings and actionable manual-stop/route/dwell explanations. More natural stop/block labels can follow. |
| Construction feedback near cursor | Implemented: pointer-side build/switch cost breakdown, refunds, valid/invalid/partial/draft wording, actual placement errors and retained-path service impact. Clamped/flipped inside the logical viewport; ignores input and hides over UI/dialogs. Draft stroke prices are distinct from full-plan validation. Safety/funds are rechecked on commit; no speculative conflict forecasts. |
| Route colours and labels | Implemented: saved palette and 1–6-character identity in Routes, locomotive badges, overlays and inspectors. Apply appearance independently of route edits while paused; linked trains share their source identity. High contrast retains labels with white lines. Livery remains separate. |
| Readable tooltips | Implemented: consistent action name/description across the ribbon, clear signals/waypoints/slots semantics, current remapped keyboard/mouse bindings where they exist, and 0.4-second hover delay. Existing accessible names/focus retained. Dynamic Pause/Speed controls continue showing current actions and bindings. |
| Accessible selection states | Implemented: PNG states, selected underline, keyboard focus and palette options; hovered cells use +/×, construction hints use words/symbols, and signals show S/H/R/A with shapes. S = manual stop, H = current held request, R = reserved signal tile, A = automatic/unrequested. R is not a global permission to enter; authority remains train-specific. |
| Quieter notifications | Implemented: identical pending alerts coalesce, persistent actionable banner offers Inspect/Bank and Acknowledge, and acknowledged conditions remain visible in Problems. Acknowledgement persists per save and rearms when the condition changes/resolves. Confirmed deadlock acknowledgement covers the cycle. Optional Settings slowdown changes 5×/10× to 1× on new waits/deadlocks/overdue payments; default off. |
| Save-slot previews | Implemented: bounded read-only map thumbnails, game time and balance for primary/backup slots. Missing/bad preview data has an explicit fallback; actual Load still performs full validation. Four separate manual slots and backups remain available. |
| Branded title screen | Implemented: uploaded logo, Continue to latest readable primary slot, slot-selectable Load/previous backup/New, Settings and Quit. Continue uses normal save validation; failed loads keep the menu usable. Threaded resource progress reports actual loading; New leaves saved files intact until Save. Scrollable at 100–200% UI scale. |

Use one inherited visual theme for readable typography, spacing, panel borders
and focus indication. Keep pixel-art icons/borders; retain a clear small text font.
Do not flatten the ribbon into one image or bake live speed/counter text into assets.
New presentation batches must test at 100–200% UI scale, in smaller windows and
fullscreen, and preserve existing shortcuts, saves and physical train positions.

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
Timed passenger connections, in-motion automatic platform
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
| Passenger destinations and transfers | Reward networks that connect useful places, including journeys requiring a change of train. | Direct destination journeys implemented: per-destination station queues, forward-itinerary boarding, through riders, destination-only delivery/fare and saved manifests. Basic transfers and deterministic fewest-change planning are implemented on the three-station map, with direct-service preference, physical interchange queues, final-only fares and saved off-route manifests. Oldest-eligible-first station boarding is also implemented, with saved arrival groups and oldest-wait diagnostics. Waiting-experience satisfaction is implemented with explicit comfort effects and saved history. End-to-end journey clocks and recent completed origin/destination timing are implemented, including transfers/recovery and honest legacy unknowns. Directional arrival targets and basic punctuality are implemented. Express/Local direct-leg eligibility is implemented on the three-station map. Timed connections, richer choices and punctuality/crowding scoring remain. See [passenger destinations](PASSENGER_DESTINATIONS.md). |
| Platform preferences | Prefer a platform by service, direction, train length, electrification, cargo access or transfer convenience, with safe fallback. | Basic platform infrastructure and assignment belong to Phase 1B. Phase 2A adds service/direction preferences, passenger transfer convenience and safe compatible fallback. Electrification and cargo-access preferences wait for those systems. Platform selection never overrides reservations. |
| Holding rules and timed transfers | Wait for a connection or a target load, avoid early departure and cap waiting time. Protect transfers within configurable windows and warn about missed connections. | Requires timetables, passenger destinations and platform metadata. Avoid indefinite holds and explain knock-on delays. |
| Express versus local passenger demand | High-paying express passengers prefer direct travel between distant hubs; commuters accept frequent stops along a local line. | Implemented initial slice: one in four new A↔C passengers is Express, boards only when the next stop is the final destination, and pays £10 at arrival; Local accepts stops/transfers and pays £5. Version 36 records actual cumulative class receipts. Broader hubs, journey choices and punctuality modifiers remain refinements. |
| Catchment visualisation and feeders | Show population, workplaces, inputs/outputs, walking distance and competing stations; abstract park-and-ride, bus and tram feeder capacity. | Implement catchment/destination rules first. Feeders are demand abstractions, not a second vehicle-management game. |
| Demand and bottleneck adviser | Forecast queues, platform demand and shortages; explain persistent congestion with clickable evidence and recommendations. | Stopped-traffic measurements and a bounded recent-wait overlay are implemented. Forecasts still require utilisation and demand history. Start with transparent heuristics; present forecasts as estimates, not guaranteed outcomes. |
| Passenger classes and preferences | Add commuters seeking frequency, business travellers prioritising speed/punctuality, tourists valuing comfort/scenery and budget travellers sensitive to fares. | Extend express/local demand rather than adding a competing demand system. Add classes gradually with understandable journey-choice rules. |
| Fare control and demand elasticity | Set fares by service/class and offer off-peak discounts, balancing demand and revenue. | Depends on destinations, classes, satisfaction and simple documented price-response rules. |
| Company reputation and passenger satisfaction | Reward reliable, comfortable service with demand growth, better contracts and subsidies instead of rewarding only transport volume. | First slice implemented: station waiting satisfaction from current queues plus the last 128 boarding groups per station, weighted by passengers, with explicit amenity comfort and causes in stations/Accounts. Save version 31 stores history; version 32 adds bounded gradual arrival response with service-evidence gating. Journey elapsed time is measured in version 33; occupancy/capacity denials are observed and version 34 records optional directional arrival targets and punctuality. Scoring and reputation-driven growth/contracts still require documented benchmarks before influencing gameplay. See [waiting satisfaction](PASSENGER_SATISFACTION.md). |
| Marketing, subsidies and public-service obligations | Fund temporary demand boosts and win regional contracts for reliable service to underserved towns, with frequency/fare conditions. | Reuse contracts, reputation, timetables and demand modifiers. Show obligations and penalties before acceptance. |
| Detailed station life and waiting passengers | Show tiny pixel-art passengers accumulating on platforms during delays and boarding when trains arrive. | Drive visuals from actual queues; cap or group sprites for performance without changing simulated passenger counts. |

### Phase 2B — Freight and supply chains

Logs → sawmill → timber → factory → finished-goods terminal is implemented as
one optional single-shuttle chain. Only generalise recipes/cargo behaviour after that full
chain is playable and its storage, stock compatibility and finances are verified.
Versioned cargo/industry definitions are implemented with the first processing industry.

| Feature | Gameplay or visual benefit | Status, dependencies and scope |
| --- | --- | --- |
| Industry supply chains | Move logs to sawmills, timber to factories, and finished goods to terminals. | Implemented first slice: optional sawmill, 2:1 log processing, bounded storage, timber loading/payment and physical recovery. Optional factory and finished-goods delivery now complete this first single-shuttle chain; general cargo rosters and independent freight services remain extensions. Verify input consumption, production recipes, bounded storage, compatible wagons and delivery accounting before generalising cargo types. |
| Cargo with distinct behaviours | Perishable cargo spoils over time, hazardous materials need lower speeds or special handling, and high-value express cargo rewards fast delivery. | Track shipment age and delivery terms; connect cargo requirements to rolling stock, facilities and routing. Make spoilage, restrictions and bonuses visible before loading. |
| Mail and parcels | Add small, fast, high-value consignments, including carriage on compatible passenger trains. | Requires cargo definitions, compatible vehicles and explicit capacity sharing; introduce before complex intermodal logistics. |
| Station facilities and amenities | Add platforms, waiting rooms, cargo warehouses and fuel depots to increase capacity, shorten loading times or lower running costs. | Physical platforms and usable lengths belong to Phase 1B. Phase 2A implements separate waiting-area capacity and demand/amenity purchases; train capacity does not create passengers. Passenger loading facilities follow measured dwell/loading rules; Phase 2B adds cargo warehouses and handling. Fuel depots wait for locomotive technology and energy costs. Each facility needs a clear priced benefit. |
| Delivery contracts | Earn rewards for specified quantities delivered within deadlines. | Extend the existing objective system with selectable, timed contracts and clear failure conditions. |

### Phase 2C — Seeded settlements, station construction, growth and persistence

Start with stable world IDs, seeded city/industry layouts and player-built station catchments;
then connect growth and decline to measured delivered/unmet service. See [seeded cities plan](SEEDED_CITIES_PLAN.md). Offer unlimited money and
slower/no growth as those systems arrive; expose no-breakdown options when
maintenance exists. Persist scenario rules and separate challenge eligibility from
relaxed sandbox play. Autosaves, basic scenario objectives and bounded performance
history may land earlier once their foundations are reliable.

| Feature | Gameplay or visual benefit | Status, dependencies and scope |
| --- | --- | --- |
| Seeded starting layouts | Start new sandbox games with reproducible cities and industries instead of three fixed stations. | Saved catalog foundation is implemented in version 39 with stable facility IDs and validated settlement references. Route/platform and Local demand adapters are implemented. Station-owned journey/amenity/response state is now adapted; Facility geometry and distance-based class adapters are now implemented. The seeded flat-grid generator now validates initial spacing, station clearances, freight-strip separation and land access. City-linked station preview/purchase rules are now implemented as a backend. The empty-start model now preserves dynamic station-owned state. Main-scene startup/editors and placement UI now work in the development preview. Generated save/load is implemented in version 40. A seed/city-count chooser is implemented, with actual first-service affordability checks and tutorial rewards separated. City-owned population and trip supply are implemented; growth/decline is next; deeper finance/scenario balance remains. Validate spacing, buildable station approaches, reachable industries and objective feasibility. Save generated geometry plus seed, generator/content versions and rules. Keep A/B/C as the tutorial/legacy scenario; full terrain generation is later. |
| Player-built stations and city catchments | Build stations beside cities and make location matter for passenger supply. | Horizontal five-tile station previews, exclusive city links, cost/reuse accounting and stale/safety checks are implemented as a backend. Dynamic station-owned state now extends safely in the empty-start model. Placement UI and main-scene adoption are available in the development preview. Generated save/load is implemented; ordinary new-game selection is implemented; city population/trip generation and population previews/reports are implemented; reject overlaps and preserve existing train positions during edits/load. Passenger origins/destinations belong to settlements; no station or no useful service leaves demand unmet. Clarify overlapping catchments so passengers are not generated twice. Support multiple stations per city after the initial one-station slice. |
| City growth and decline | Cities expand with useful service and contract when sustained passenger demand is unmet. | Request cohorts, matched final deliveries, pending journeys and completed transfer legs are implemented in v42 ([measurement](USEFUL_SERVICE.md)); population changes are still planned. Next: use bounded population and measured served/unserved demand over a rolling window, including delivered passengers, capacity, frequency and usable destinations. Grow/shrink gradually with grace periods and visible explanations; unserved new cities must not collapse immediately. Preserve existing buildings/station access during visual expansion; never demolish rail or teleport trains. Add slower/no-growth options and later integrate industry supply/jobs and land rights. |
| Industry growth | Useful cargo service creates production and expansion opportunities. | Retain the existing Phase 2C plan: measured delivered supply and usable demand support bounded industry growth. Extend the saved world catalog and production definitions; keep storage/recipe accounting valid and explain changes. Integrate land rights later. |
| Sandbox and scenario modes | Offer relaxed construction alongside structured challenges. | Expose unlimited-money and growth-rate options with the supporting systems. Add no-breakdown and maintenance-pressure controls when maintenance exists. Save rule settings and define challenge/achievement eligibility. Reuse introductory objectives for a small early scenario framework; avoid requiring all later simulation features first. |
| Operating budgets | Break costs down into maintenance, fuel/energy, workforce, vehicles, construction, interest, station upkeep and penalties. | Expand the company dashboard as each cost system arrives; avoid double-counting the same expense across categories. |
| Leasing and second-hand stock | Offer low-upfront-cost leases and cheaper used vehicles with clear running-cost or reliability trade-offs. | Build on fleet identities, contracts and vehicle condition. Add simple purchase/lease terms before resale-market simulation. |
| Incident log, journal and lightweight narratives | Generate factual headlines and selected passenger/cargo stories with destinations and senders/recipients. | Consume bounded simulation events and real shipment data. Cap visible stories; keep logs useful even with flavour text disabled. |
| Rotating autosaves and recovery | Keep a bounded quick-save roster, configurable periodic autosaves and recovery from the last valid save. | Four independent manual slots with per-slot backups and a fresh-game chooser are implemented ([save slots](SAVE_SLOTS.md)). Implemented: three independent rotating recovery copies per manual slot; Settings offers off / 1 / 3 / 6 game hours, default 1. Recovery is available from the title menu and in-game Load. Safe-boundary snapshots preserve queued commands and simulation RNG; failed writes preserve all prior copies. Manual files/backups remain untouched. No schema change. See [autosaves](AUTOSAVES.md). |
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
| Loans and debt | Borrow to fund infrastructure, with interest and repayment obligations. | Implemented early at player request: £1,000/£2,500/£5,000 offers, one loan at a time, fixed 1% per game hour, ten hourly principal instalments, tick-based accrual, automatic interest-first payments from available cash, arrears, early full payoff and v27 persistence. See [bank loans](LOANS.md). Variable rates/lenders, forecasts, insolvency and sandbox alternatives remain later work. |
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
| Procedural maps and shareable seeds | Generate terrain, rivers, towns, industries and resources with adjustable size/density and reproducible starts. | Phase 2C introduces seeded settlement/industry starts with player-built stations before a full terrain generator. Validate placement, connectivity and objective feasibility. Share seed, generator/content versions and scenario/modifier rules; a seed alone does not guarantee matching maps across releases. Full terrain and rivers remain later work; initial city layouts and catchments belong to Phase 2C. |
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

A written first-15-minutes guide and controls reference exists: [getting started](GETTING_STARTED.md). The in-game tutorial below is still planned.

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

Completed work stays in place. The detailed milestone tables above distinguish
implemented slices from remaining extensions. This list describes **remaining work**,
updated after the October 2026 catalogue feedback; it is not the order of feature IDs.

First-session guidance/save protection (1C / 2C) is complete: optional repeatable
checklist, first-delivery feedback and rotating autosaves. Representative startup
affordability checks remain in the regression suite; broader balance changes and
rescue rules still need playtesting.

1. **City response (2A / 2C):** request-to-delivery measurement, arrived transfer
   legs and unmet reasons are implemented ([useful service](USEFUL_SERVICE.md)).
   Define fair scoring and add bounded growth/decline, grace periods, population floors,
   readable reasons and slower/no-growth settings. Advisory arrival budgets must
   not become arbitrary growth penalties.
2. **Visible operational progress (1C / 2A):** compact service cards, per-game
   persistent watchlists, actionable network summary, optional end-of-day reports
   and proportionate historical trends. Distinguish company final-journey totals
   from the legs carried by individual services. Complete relevant remaining
   safety/platform/body-routing extensions when this work requires them.
3. **Focused goals (2B / 2C):** a few short feasible scenarios, explicit objectives,
   difficulty modifiers and locally comparable seed results. Contracts follow clear
   scoring, failure/recovery and measured delivery accounting.
4. **Map variety:** rivers and bridges first, then additional terrain/elevation,
   tunnels and map settings. Art alone never adds crossing permissions or geometry.
5. **Operational and business depth:** deterministic fair priorities, richer planning,
   wider service/platform choices and full reputation, introduced using existing
   measured evidence. Raise fleet limits only after realistic performance/usability
   tests. Physical depots follow when their gameplay prerequisites justify them.
6. **Later mechanics (3–5):** optional maintenance, research/eras, weather,
   richer content/editor/modding and community tools. Keep workforce, deeper finance,
   rivals and detailed replay behind a satisfying core loop.

Introduce resource-driven definitions with the corresponding fleet/content work.
Small scenario modifiers, cosmetic art/sound, accessible feedback and save reliability
may proceed alongside their prerequisite milestone. No global reservation SignalBus
is planned. The new [feedback/growth artwork](../art/generated/microrail_pack_v2/README.md)
provides 32 review candidates and a separate F6 gallery; no future gameplay mechanic
is marked implemented merely because its icon or sprite now exists.

Implemented tools and evidence: [foundations](phase-0-foundations.md),
[reservations](RESERVATIONS.md), [signals](SIGNALS.md), [recovery](DEADLOCKS.md),
[waypoints](WAYPOINTS.md), [multiple services/passing loops](MULTIPLE_SERVICES.md),
[consists](CONSISTS.md), [platform lengths](PLATFORMS.md), [inspection](NETWORK_INSPECTION.md),
[problems/waiting](PROBLEMS_AND_WAITING.md), [alerts](NOTIFICATIONS.md),
[construction drafts](CONSTRUCTION_PLANNING.md), [corridor signals](CORRIDOR_SIGNALS.md),
[blueprints](TRACK_BLUEPRINTS.md) and [object search](OBJECT_SEARCH.md).
