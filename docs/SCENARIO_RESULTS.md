# Scenario completion review

After completing any seeded scenario, **Results** appears beside the bottom
Goals/Guide controls. Open it to pause and review the run. Closing leaves the
game paused; resume when ready. Completion itself shows a notice and keeps play
running, without opening a window automatically. Results remains available after
save/load, even with Goals hidden or measured services subsequently retired.

New completions retain a fixed snapshot:

- Elapsed company time at completion, in game hours; pauses do not advance it.
- Qualifying scenario deliveries, including resident-origin requirements,
  the timber order or both Passing Place services, as applicable.
- Company final passenger journeys, passenger fares and freight receipts.
- Running costs and **operating contribution = fares + freight − running costs**.
- Cash balance at the moment the goal completes.

Company figures cover activity since the company began. Passing Place's goal
figures cover its measured attempt; these are labelled separately. Construction,
fleet purchases, contract bonuses, rewards, borrowing, repayments and interest
can change cash separately from operating contribution. Boarding and transfers
do not create additional final journeys. The review introduces no ranking,
composite score or extra reward.

Continued play does not update the historical snapshot. The dialog reads saved
figures rather than taking a new snapshot when opened. For an older completion
with no historical snapshot, it shows the known completion time and clearly
labels the financial figures as **CURRENT company totals**. It never reconstructs
an unknown old balance or claims current totals were earned at completion.

Save version **53** adds `seeded_challenge.review`. It is empty before completion
and for older migrated completions. New snapshots store seven whole-number
counters: delivered, fares, freight, running, cash, primary and secondary goal
counts. Validation requires a completed supported scenario, bounded counters,
financial/delivery totals no larger than the current cumulative company values,
and qualifying goal counts backed by its city/contract/milestone records. Historical
cash may be greater or less than today's balance. Version 52 migration adds an
empty review without changing scenario evidence, actors, RNG, commands or finances.

Results uses the shared dialog theme, scrolls within the viewport at 200% UI
scale and participates in modal shortcut/mouse handling. A pending construction
stroke/draft or another open dialog must be resolved first. Load closes a stale
review. Tutorial introductory goals and ordinary sandbox games do not show this
seeded-scenario completion button.

`test_scenario_review.gd` covers real passenger completion, saved immutable
results, operating arithmetic, current-only legacy fallback, validation, migration,
modal/pause behavior and 200% layout/Close access. All existing scenario and
save/autosave tests also run against version 53.

## Sharing playtest feedback

Results offers **Copy summary** and **Export .txt**. Copy places a plain-text
report on the clipboard; Export opens a save picker with a suggested name such
as `microrail-first_connection-results.txt`. Choose a location, confirm replacement
if needed, then attach the UTF-8 text file to feedback. Cancelling leaves Results
open and the company paused. A failed write shows an explanation in the review;
choose another writable location and retry.

Both actions use the report captured when Results was opened. It includes the
scenario ID, map seed, layout/generator/content versions, terrain profile, initial
city count and loan rule, followed by the displayed figures and their historical
or current-only caveat. It includes no save contents or local file paths. This is
a player-provided summary, not a verified score or replay: matching seeds and
content versions do not reproduce player decisions. Nothing is uploaded.

Export adds no save fields or version bump, advances no ticks, and changes no
finances, goal counters or historical results. Export controls and the save picker
are covered by the scenario review integration suite, including UTF-8 output,
failed-write recovery, cancellation, immutable state and 200% dialog bounds.

Use the [playtest checklist and report template](PLAYTEST_CHECKLIST.md) to add
reproduction steps, build details and observations to the exported summary.
An unfinished scenario can be reported without a Results file.
