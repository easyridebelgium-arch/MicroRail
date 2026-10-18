# First freight processing chain

This Phase 2B slice adds an optional sawmill. Existing maps keep direct Forest →
Terminal log delivery (£8 per log) until you purchase it. The first processing
chain is Forest → Sawmill → Terminal → Forest. The optional [factory](FACTORY_CHAIN.md) now extends it with finished goods.

## Build and operate

1. Pause. Freight must be empty at the Forest (8,24). If it is away, withdraw its
   service and let it physically return before building.
2. Connect the Forest to the Terminal (28,24), passing through horizontal track
   at **18,24** exactly once. A straight line is the simplest first layout.
3. Leave the building grounds clear: columns 17–19, rows 22–23. Keep signals off
   the loading tile and allow clearance for the whole train at the stop.
4. Click the Forest or Terminal and choose **Build sawmill (£500)**. Its loading
   track becomes permanent and a required freight waypoint is added. Installation
   preserves the train's position and current route geometry; an ambiguous route
   needs review before purchase.
5. Enable freight and resume. It takes logs to the sawmill, unloads into storage,
   then loads processed timber under the existing Any/Half/Full rule. The Terminal
   pays **£24 per timber** on physical arrival. The train returns empty to the Forest.

The recipe is **2 logs → 1 timber every 5 simulation seconds**, with 200 units of
input storage and 200 output. Processing uses fixed ticks, pauses with the game,
and follows simulation speed. It stalls when input is insufficient or output is
full. Unaccepted logs remain aboard; cargo is never discarded to make space.
Any can depart with one timber; Half/Full wait for their minimum load or finish the available input batch when
it cannot fill the train. A withdrawn
empty train waiting at the sawmill returns to the Forest; a withdrawn loaded train
finishes delivery without collecting extra timber.

Click the sawmill for stock, recipe, progress and cumulative throughput. Accounts
also reports these figures. Logs accepted at the sawmill earn no payment; only
terminal delivery sells timber. Historical raw-log deliveries remain separate.
The introductory log-delivery objective counts both terminal logs and logs
physically received by the sawmill.

## Routing and safety

The sawmill is an intermediate physical stop, not a new independent freight
service. The existing freight locomotive/log wagons carry both logs and timber
in this first slice; specialised cargo vehicles follow later. Keep its required waypoint when editing freight. Tile reservations,
switch locks, one-way restrictions, block signals and whole-train clearance apply
as before. Route breaks stop a train safely in place; repair its forward route to
resume. Reverse returns to the actual departure stop: Forest, Sawmill or Terminal.
A reversing train retains its cargo and receives no sale during recovery.

Use passing loops and signal boundaries for shared track; this industry does not
resolve a single-track head-on conflict automatically. Initial artwork is the
existing facility renderer; custom sawmill art can be integrated later.

## Definitions and persistence

Cargo prototypes are `resources/cargo/logs.tres` and `timber.tres`; the industry
prototype is `resources/industries/sawmill.tres`. Typed Resource scripts describe
IDs, schema version, terminal prices, recipe, tick budget and storage capacities.
Treat these prototypes as read-only. Mutable inventories and train state are saved
separately; balance/schema edits require migration and conservation checks.

Save schema **37** stores industrial stocks, productive ticks and the freight
stage/departure/recovery stop. Version 36 migrates to an uninstalled, empty sawmill
without changing cash, train positions or the old log-only service. Loading rejects
inconsistent inventory totals, invalid stages and missing required loading track
before changing the live game. Mid-batch production resumes from the saved tick.

Automated coverage includes production timing, capacity limits, conservation,
actual loading and paid delivery, recovery, service withdrawal, whole-body
manual-signal stopping/release, atomic save rejection and equal results at 30/60/120 FPS.
