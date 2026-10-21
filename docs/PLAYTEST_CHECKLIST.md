# MicroRail playtest checklist

Use this short guide alongside [Getting started](GETTING_STARTED.md). Play normally;
you do not need to test every feature or finish a scenario to give useful feedback.
For a specific fault, use the report template below. Send it through your usual
feedback channel; the game does not upload reports automatically.

## A short session

1. Record the branch and commit you are playing (GitHub Desktop → History), your
   operating system, resolution, window/fullscreen mode and UI scale.
2. Start Tutorial, City sandbox or a [seeded scenario](SEEDED_SCENARIOS.md).
   Record the mode, seed and city count. Note whether this is a fresh game or a load.
3. Try to establish one working service using Guide if needed. Note the first
   instruction, control or refusal you could not understand. In the tutorial,
   connecting A–B starts the initial train automatically.
4. Watch a final delivery, then inspect a station and the service's figures.
   Can you distinguish waiting, boarding, transfers and completed journeys?
5. If traffic stops, inspect the train or Problems. Record the exact status and
   reason before editing signals, reversing trains or changing track. Do not
   deliberately damage your main save to manufacture a fault.
6. Save and reload when convenient. Note whether routes, positions, watchlists
   and progress return as expected. Stop here if you prefer a short test.

For a completed seeded scenario, open **Results** beside Goals/Guide and choose
**Copy summary** or **Export .txt**. Attach the summary to your feedback. See
[what Results measures](SCENARIO_RESULTS.md). Incomplete runs, Tutorial and ordinary
sandbox have no completion report; your observations and a save are still useful.

## Five quick questions

- Could you start a working service? Where did you need help?
- What first confused you?
- Could you explain why a stopped train was waiting?
- What felt satisfying or frustrating?
- What would make you play again?

Assess readability, click/drag feel, animation, audio and the pace at 1× on your
actual display if possible. Say when you used scripted input or headless testing;
those results cannot establish real-monitor feel or audible sound quality.

## Copyable problem report

```text
Short title:
Build: branch + commit (or downloaded build identifier)
System/display: OS, resolution, window/fullscreen, UI scale
Mode/map: Tutorial / City sandbox / scenario name; seed; city count; terrain
Session: fresh or loaded; simulation speed; paused/running
Affected objects: train/service names or IDs; station/waypoint names; tile coordinates

Steps from a known starting point:
1.
2.
3.

Expected:
Actually happened (copy exact status/reason or debugger error):
Reproducibility: every time / sometimes / once; attempts if known
Workaround tried and result (or none):
Attachments: screenshot, save before the fault, Results summary if available
```

For a waiting train, include its operating inspector's first status/reason and
any Reverse refusal. Show nearby signals, switches, route stops/waypoints and
train length in a screenshot if possible. A seed describes the initial map;
it cannot recreate later track, orders or player actions. A pre-fault save is
usually more useful than a seed for a network fault. Use **Save folder** in the
slot chooser to find the relevant file; [Save slots](SAVE_SLOTS.md) lists filenames.
Copy the relevant save for attachment and keep your original. Do not replace a
useful pre-fault save merely to obtain a newer screenshot.

## Balance observations

Record starting and ending company time, cash, construction/fleet spending,
fares, freight receipts, running costs, borrowing and rewards when available.
Include route length, train model, delivered final journeys and any idle periods.
Say which values you measured and which are estimates. Operating contribution
is not cash profit or payback: capital, loans and rewards change cash separately.
One profitable route does not establish that all seeds or longer routes balance.

Results records completion figures once. Later play does not update them. Older
completed saves may show **CURRENT company totals** instead; preserve that label
when sharing. Summaries are player-provided observations, not verified scores.

## Developer triage

Retain the reported build and save. Reproduce with its recorded configuration;
separate a simulation fault from a misleading explanation, UI obstruction or
balance concern. Record reproduced / not reproduced / awaiting evidence explicitly.
Turn a reproduced safety, persistence or deterministic-state fault into an
appropriate regression check; do not treat a headless pass as visual approval.
Use several comparable sessions before changing fares, budgets or loan pressure.
