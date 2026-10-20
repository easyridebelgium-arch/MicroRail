# First seeded scenarios

Choose **New Game → Seeded scenario**, select a preset and read its briefing.
Starting replaces the in-memory game; manual saves change only when you Save.
Existing autosave/recovery rules still apply. Preset seed/city count are fixed;
the ordinary City sandbox keeps its editable seed, random button and city count.

| Preset | Starting world | Final-journey goal | Resident origins served | Restriction |
| --- | --- | --- | --- | --- |
| First Connection | Seed 42, 3 cities, £5000 | 40 | At least 5 final resident journeys from each of 2 cities | Ordinary bank loans allowed |
| Across the River | Seed 42, 3 cities, £5000, River preset | 40 final cross-river journeys by Town 3 residents | At least 5 resident journeys from one other city | Ordinary bank loans allowed |
| Three Town Link | Seed 7, 3 cities, £5000 | 75 | At least 5 final resident journeys from each of all 3 cities | No bank borrowing for this company |

The original three passenger presets are short introductory challenges with **no deadline**, extra completion
money, hidden penalties, medals or leaderboard. They start empty: build stations,
connect rails, buy a locomotive and start a service. The optional Guide remains
available. Initial growth is Normal and can be adjusted in Settings; that choice
is not a ranked difficulty rule in this first slice.

## Goals and useful service

The **Goals** panel opens initially for a new scenario and replaces the ordinary
first-service summary with both required counters. It can still be hidden with
Goals/G. The delivery bar covers the volume target; the second line separately
shows how many resident origins have met their five-completion minimum. Filling
the bar alone does not win if too few cities have been served.

Completions use the existing city request measurements, attributed to original
resident cities and counted only at final destinations. Boarding, queues,
interchanges, train purchases and station count alone do not qualify. A high
volume from one city cannot replace useful service for the other required cities.
There is no requirement for a particular train, route shape or platform design.

When both conditions are met, completion is recorded once at a fixed simulation
tick, a notice/event is emitted and Goals shows **SCENARIO COMPLETE**. Ordinary
fares continue; there is no completion cash award or repeated reward. Keep
playing or start another company. Three Town Link's no-borrowing rule remains
active after completion. It is enforced in the borrowing backend as well as the
disabled Bank buttons and their explanatory tooltips.

## Saves and scope

Save version **46** retains scenario identity and its completion tick. Progress
comes from the company's existing saved final city-journey measurements, without
a second set of delivery counters. Version 45 migration leaves older companies
as ordinary sandbox/tutorial games; it does not infer a scenario from a matching
seed or award old achievements.

Validation checks supported identities, preset world seed/city count, completion
bounds, actual goal measurements for claimed completion and zero lifetime bank
borrowing for Three Town Link. Load preserves physical positions, passengers,
RNG, commands, finances, city growth, watchlists and reports. Slots/backups and
autosaves retain their own scenario state.

The first scenarios validate a complete loop of selecting a reproducible start,
funding a feasible railway, moving real people and saving a clear outcome.
Challenge modifiers, scoring/medals and scenario editing remain extensions.
Timber Connection below adds a focused timed freight goal. Rivers and bridges now have a focused passenger scenario; broader scenario packs
can use this foundation later.

## Validation

`test_seeded_challenges.gd` builds actual stations and routes within the £5000
budget for both presets. It runs generated passengers through physical trains to
complete the goals, checks the multi-city requirements, rule enforcement, no
repeat awards, exact save/load and old-save defaults. New-game, loan, report,
city, service-card, autosave, slot and game-menu regressions remain active.

![Seeded scenario briefing](images/seeded_scenarios.png)

## Across the River

Select **New Game → Seeded scenario → Across the River**. The seed, three cities
and original two-row river preset are fixed. Town 3 is the only north-bank city;
its station catchment cannot reach the south bank. Every matched final journey by
its residents to another city therefore crosses the river. Goals counts **40 Town 3
resident final journeys**, plus five final resident journeys from at least one
other city. High volume between only the two southern cities cannot win.

Start with £5000 and no infrastructure. The briefing checks a complete affordable
Town 3–Town 1 construction witness (including platforms, bridge rails and shuttle).
Open **Guide → Preview suggested connection on map** for a dashed proposed layout.
Build both dry banks and every water tile as straight north–south bridge track;
leave and enter platforms horizontally. Bank loans remain available; there is no
deadline or completion bonus. Growth rules remain adjustable.

The preset uses the existing scenario identity, completion tick and city resident
measurements, with no new saved counters or save-format change (current version 53, which also retains priorities, optional freight contracts, reminder markers and scenario evidence).
Older companies and the original two scenarios retain their goals. An older build
that does not know this new scenario identity will reject its saves as incompatible.
Loading checks the required river profile and original city geometry as well as
qualified completion totals, preserving the cross-river inference.

`test_river_challenge.gd` purchases stations, lays the checked bridge through the
ordinary construction backend, buys/starts a shuttle, matches the quoted budget,
runs generated passengers to completion and checks unfinished/completed save-load,
terrain/geometry rejection and automatic terrain selection in the chooser.

## Timber Connection

Choose **New Game → Seeded scenario → Timber Connection** (seed 42, three cities,
flat terrain, £5000). This freight-only challenge needs no passenger stations.
Preparation is untimed; accepting the order starts its deadline.

1. Pause and connect the Forest loading tile to Terminal along the horizontal
   industry strip, passing through the proposed Sawmill loading tile. Keep its
   building footprint above the rails clear. The direct line costs £430 (43 tiles).
2. In Fleet buy a **Log Hauler (£500)** and start its freight service. Stay paused
   with the empty train at Forest.
3. Inspect Forest and **Build Sawmill (£500)**. The full starting investment is
   £1430, leaving £3570 for operations. Detours and other purchases cost extra.
4. When ready, open **Accounts → Freight contracts** and accept **Timber**.
5. Resume. Deliver **20 timber to Terminal within 18 game hours** after acceptance.
   Sawmill receipts and deliveries made before acceptance do not count. Do not
   install Factory before finishing: it changes the terminal's output cargo.

The optional **Guide** now shows freight steps and opens the relevant tools.
Goals displays order progress and time remaining. Optional deadline reminders
are available in Settings. Ordinary loans are allowed. The existing contract
pays £300 once; scenario completion adds no bonus. After completion you may keep
building, including the Factory.

If the order expires, Goals explains that the scenario remains incomplete. There
is no fine, forced reset or teleport; continue the company or start a fresh Timber
Connection scenario to retry the one-off order. Existing save slots remain separate.

The current save format retains the identity, completion tick and contract.
Timber Connection uses the ordinary contract counters. A claimed completion
must reference a completed timber order whose finish tick is no later than the
scenario completion tick; the ordinary contract validator also verifies actual
terminal totals. Older builds that do not recognize this identity cannot load it.

`test_timber_challenge.gd` constructs the generated line through ordinary building,
buys/starts freight, installs the mill, checks the exact budget, runs the physical
production chain to completion and validates active/completed save-load. Passenger
volume, expired orders and forged completion histories cannot substitute.

## Passing Place — guided shared-track challenge

Choose **New Game → Seeded scenario → Passing Place** (seed 4, three cities,
flat terrain, £5000). Everything starts unbuilt. Open **Guide → Show challenge
stations and loop** to frame a dashed teaching layout. This is a visual guide;
use the normal tools to purchase infrastructure.

1. Build **Town 3 Station at (30,14)** and **Town 2 Station at (66,14)** (£600).
2. Connect their horizontal platform ends along row 14 (£310).
3. In Guide choose **Draft suggested passing loop**, or in Overlays use a
   nine-tile horizontal loop below the line at **(44,14)**. Review train fit,
   signal-block isolation and the £330 extra cost, then **Apply plan**. Retain all
   four automatic boundary signals.
4. Buy two **Passenger Shuttles** (£800 together). Stay paused. Start one Shuttle
   **Town 3 → Town 2**, and the other **Town 2 → Town 3**, each with two stops.
5. Use the loop waypoint shortcut or Guide to open Routes with **(48,17)** filled
   in. Select only the **Town 2 → Town 3** service and leg, **Add waypoint**, review
   and **Apply**. Leave Town 3 → Town 2 on the main branch. Nothing is assigned
   automatically; normal empty-at-first-stop and route-validation rules apply.
6. Resume and complete **ten new final passenger journeys per service** while
   both prescribed routes, stations, loop and isolated automatic boundaries are
   ready. Goal counters identify main-line and loop service outcomes separately.

The ordinary checked investment is **£2040**, leaving **£2960** for operations.
The briefing verifies station transactions, construction protection/pricing,
block isolation and both authoritative route paths. Alternative infrastructure
costs extra; the goal intentionally teaches the stated fixed layout. Loans are
allowed; there is no deadline or extra completion payout. Ordinary fares apply.

Boarding, station queues and transfers do not count. Delivery baselines start
when the complete setup first runs ready, so earlier earnings on different routes
cannot instantly satisfy it. Resuming with incomplete setup resets the unfinished
attempt; a different selected service pair starts fresh baselines. Paused planning
can be repaired before resuming. Save/load preserves partial measured deliveries.
Topology analysis is cached; the goal reads actual per-service final receipts.

On completion the milestone remains saved even if a service is later retired,
its performance row is removed, or the layout is changed. Goals continues to show
its recorded result and the Guide remains complete. The company can continue.
Version **52** stores scenario evidence: empty for ordinary companies/other
presets, or the selected service IDs, their pre-attempt baselines and newly
completed delivery counts for this challenge. Validation checks distinct service
IDs, numeric bounds, completion thresholds and evidence totals against company
final deliveries. Version 51 migration adds empty evidence and preserves previous scenario identity,
completion, actors, RNG, finances and commands; older companies are not assigned
the new challenge. Original teaching city coordinates are checked on load.

`test_shared_track_challenge.gd` builds through ordinary purchases and the actual
Guide/Overlays/Routes flow, matches the checked budget, runs both physical services,
monitors shared-track occupancy and deadlocks, saves partial/completed attempts,
checks old-delivery exclusion and restart rules, retires a service and reloads its
completed milestone. Prior scenarios and save migrations remain covered.

After completing a seeded preset, open **Results** beside Goals/Guide for its
[saved completion review](SCENARIO_RESULTS.md). New completions retain their
company-time, delivery and operating figures as play continues. Older completions
show an explicitly labelled current-company fallback for unavailable historical
figures. Version 53 migrates existing scenario evidence automatically.
