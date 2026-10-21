# Construction drafting

A click on empty ground previews and places one horizontal track piece. A short
drag within that cell sets its direction, including diagonals, without requiring
a second piece. Continue into more cells to build a longer stroke. This works in
both Draw and Connect modes; each new cell is charged once. Clicking an existing
track does not replace it, and direct station/train clicks retain inspection.
When starting on empty ground, a one-cell drag places one piece in the starting
cell; each further cell of movement adds one piece. Starting on an existing rail
uses that rail as the anchor instead. Connecting to an existing endpoint includes
the complete connection, without charging for either existing rail.
The first one-cell extension from an open end follows the existing track's
direction even when the pointer moves slightly off-axis; drag farther to start
a bend. Branches off an existing through line create a switch automatically.

A short right-click cancels the active gesture/tool and returns to Connect track.
Right-drag removes track; holding right for 0.4 seconds also activates removal.
Moving 6 screen pixels starts a drag immediately, without waiting for the timer.
Red removal previews commit on release, so Escape can cancel before deletion.
Alternatively press **R** (remappable), or select **Remove**, then left-drag.
Right-click inside Traffic closes it on release, keeping its pause state; dialog
and toolbar holds never delete the map underneath them. Staged construction is
retained when changing tools; Apply or Discard handles that draft.

A straight approach can also join an existing curve with an automatic switch,
preserving both original curve connections. The three-port shape must allow the
movement; a tight turn, extra exit or conflicting nearby track is still rejected.
The preview/status message explains the rejection. Occupied/reserved curves
remain protected, including in a loaded game.

Open **Overlays** and enable **Draft construction**. The game pauses initially.
You may resume while drafting; trains use only the actual built network.

Draw several track strokes as usual. Each stroke is added to the draft, so later
strokes can connect to earlier ghost tracks. Select **Remove** and left-drag to stage removals and
**Switches** to cycle a planned straight into switch variants. A **P** marker
identifies planned tiles; white crosses mark planned removals. Nothing is charged
or changed in the real network until you apply the draft.

The Overlays panel shows aggregate construction cost, refund, net cost and
current validation errors. Affected-service reports use retained runtime routes
and distinguish a break ahead from a break behind the train. Reserved tiles can
be drafted, but ownership prevents applying them until the train clears.

- **Apply plan** pauses and validates the entire transaction against live track,
  current reservations, protected platforms/grounds, diagonal corner conflicts,
  signal compatibility and the available balance. Failure leaves every real tile
  and the balance unchanged and keeps the draft for review.
- **Discard plan** removes the ghosts without changing the network or balance.
- After Apply/Discard, disable Draft construction to return to immediate building.
  Trying to disable the mode with uncommitted edits keeps the draft available.

A successfully applied plan is one grouped Undo/Redo action while paused. Track
removed by the plan takes its signal with it; Undo restores both. Undo/Redo refuse
to change reserved track or overwrite a signal edited since that action.

Existing build commands are settled before entering planning. If real track in
the draft footprint changes later, discard and redraw that stale draft. Removing
a newly drafted tile cancels its cost and gives no refund. Each new tile is charged
once; switches include their normal surcharge. Real removals use the normal track
refund and switch-to-straight conversions use the normal switch refund.

Signal clicks also stage their automatic/stop/remove cycle while drafting.
[Corridor controls](CORRIDOR_SIGNALS.md) stage spaced signals or remove a batch;
these can be applied together with track edits.

Drafts are session-only. Apply or discard before saving; a successful load clears
any old draft. Blueprint storage and additional corridor tools are separate steps.

## Try it

1. Enable Draft construction, then draw a five-tile line away from stations.
2. Extend it by another stroke sharing an endpoint: the shared tile is charged once.
3. Select Remove and left-drag over a ghost tile: it disappears without a refund.
4. Apply, then Undo once: every stroke in that plan disappears together.
5. Redo to restore them. Draft a gap ahead of a moving train, pause and apply:
   the train stays in place. Undo repairs that gap without resetting the train.
6. Draft a change to occupied track and apply: the whole plan must be refused.
   Resume to let the train clear, then try again.

```sh
godot --headless --path . --script res://tests/test_construction_plan.gd
godot --headless --path . --script res://tests/test_planning_integration.gd
```

Draft summaries now itemise track, switch and bridge costs/refunds, with prototype
signal edits explicitly free. Overlays also identifies shared unbranched runs
and lists measured congestion hot spots. Warnings are advisory structural facts,
not traffic forecasts. See [the combined update](OPERATIONS_BATCHES_1_3.md).
