# Construction drafting

Open **Overlays** and enable **Draft construction**. The game pauses initially.
You may resume while drafting; trains use only the actual built network.

Draw several track strokes as usual. Each stroke is added to the draft, so later
strokes can connect to earlier ghost tracks. Use right-drag to stage removals and
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
3. Right-drag over a ghost tile: it disappears from the draft with no refund.
4. Apply, then Undo once: every stroke in that plan disappears together.
5. Redo to restore them. Draft a gap ahead of a moving train, pause and apply:
   the train stays in place. Undo repairs that gap without resetting the train.
6. Draft a change to occupied track and apply: the whole plan must be refused.
   Resume to let the train clear, then try again.

```sh
godot --headless --path . --script res://tests/test_construction_plan.gd
godot --headless --path . --script res://tests/test_planning_integration.gd
```
