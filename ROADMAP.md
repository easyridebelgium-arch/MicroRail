# Roadmap

A low-resolution PC game for train lovers, built around passenger and freight
transport. Developed with **Godot** and **GDScript**.

This roadmap combines the earlier gameplay suggestions with the requested
future features. The phases are a proposed development order, **not release
dates**. Anything listed as planned is **not implemented yet**. The core game
must stay playable after every phase.

Related documents:
- [docs/feature-catalogue.md](docs/feature-catalogue.md) - every complementary feature, grouped, with benefits and integration notes
- [docs/design-principles.md](docs/design-principles.md) - cross-cutting rules, dependencies and suggested adjustments
- [docs/tutorial-plan.md](docs/tutorial-plan.md) - tutorial and retention coverage

## Current foundation (implemented)

- Mouse-drawn tracks with automatic bends, diagonals and a straight first
  extension tile when departing existing rails.
- Construction costs, drag demolition and paused construction Undo/Redo.
- Passenger and log-freight services, production and delivery income.
- Separate speed and capacity upgrades.
- Named services and ordered passenger stops across Stations A, B and C.
- Station inspection, camera scrolling, minimap, introductory objectives and
  saves.

## Phase 0 - Foundations (first version written; needs in-engine testing)

Cheap decisions now that avoid rewrites later. Details, usage rules and the
test checklist are in [docs/phase-0-foundations.md](docs/phase-0-foundations.md).

- [x] Fixed-timestep simulation separated from rendering (`SimClock`).
- [x] One seeded RNG for all simulation randomness (`SimRng`).
- [x] Event stream: tick + subject + event type, bounded, saved (`EventLog`).
- [x] Versioned save format (v15) with step-by-step migration (`SaveMigrations`).
- [x] Accessibility defaults: interface scale, colour-blind and high-contrast
  palettes, reduced-motion setting, key remapping through the InputMap.
- [ ] Verified in Godot 4.7 (run `tests/phase0_selftest.gd` and the manual checklist).
- [ ] Mouse buttons and the wheel moved to InputMap actions (needed for controllers).
- [ ] Interface-only scaling and 200% layouts (header and toolbar need to reflow).

## Phase 1 - Network integrity and tools (planned)

- Junctions, block reservations and signals (automatic by default).
- Deadlock detector and conflict preview built on the reservation layer.
- Ghost / planning mode with cost and conflict preview.
- Overlays: reservations, block occupancy, signals, speed limits, congestion.
- Batch track upgrade, segment selection, bulk construction and demolition.
- Search, filter, pinning and jump-to tools.
- Advisory pathfinding (read-only route recommendation).
- Notification centre with severity filters and per-event pause settings.
- Signal control modes (one-way, route, platform, manual dispatch points).
- Shunting, reversing and emergency recovery basics.

## Phase 2 - Services, passengers and rolling stock (planned)

- Passenger destinations, classes, satisfaction and reputation.
- Timetables, service holding and dispatch rules, platform preferences.
- Timed transfer windows and connection management.
- Fleet model: formation templates, vehicle comparison, leasing and
  second-hand stock, automatic replacement rules.
- Non-disruptive service editing (apply after trip / at depot).
- Station and industry catchment visualisation, demand prediction, bottleneck
  adviser (advisory only).
- Fare control and demand elasticity, operating budget categories.
- Mail and parcels, procedural news/journal, light passenger/cargo narratives.
- Autosave rotation, incident log, bounded replay buffer.

## Phase 3 - Maintenance, crews and terrain (planned)

- Maintenance, wear, track classes and weight limits.
- Temporary speed restrictions and work zones.
- Crew, fatigue and skill (staff abstraction kept largely automatic).
- Depots, train recovery, yard splitting/merging.
- Terrain costs, rivers, water crossings, landmarks.
- Biome / regional themes (visual first, gameplay effects behind toggles).

## Phase 4 - Eras, weather and power (planned)

- Era progression, electrification, loans and modernisation.
- Weather and incidents, optional insurance for higher difficulties.
- Day-night cycle and dynamic lighting (rendering separate from simulation).
- Company valuation, milestones and sustainability score.
- Power grid and substations (only if electrification proves fun without it).
- Intermodal terminals, ports, feeders (start as industries/terminals).

## Phase 5 - Replayability and polish (planned)

- Procedural maps with shareable seeds, scenario and map editor.
- Campaigns, seeded daily/weekly challenges, scenario medals.
- Blueprint browser (versioned JSON/Resource files).
- Spatial sound design with separate volume sliders and visual alerts.
- Controller / Steam Deck support, radial menus.
- Cinematic replay and time-lapse export.
- Community sharing of seeds and results.

## Priority order (consolidated)

1. Phase 0 foundations (determinism, events, save versioning, accessibility defaults).
2. Robust reservations, deadlock prevention, recovery and emergency controls.
3. Construction planning, overlays, bottleneck tools, bulk/batch tools.
4. Fleet templates, replacement rules, non-disruptive service editing.
5. Station catchment, demand prediction, transfer visualisation.
6. Controller support and remaining accessibility polish, autosave.
7. Procedural maps, seeds, biome themes, scenario variety.
8. Campaigns, seeded challenges, community sharing.

Full multiplayer and competitor AI are deliberately out of scope until the
simulation is deterministic and the above is stable.
