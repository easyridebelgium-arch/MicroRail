# Signals and dispatcher controls

## Player controls

1. Select **Signals** in the toolbar. Click straight track outside platforms:
   first click adds **A** (automatic), second changes it to **S** (manual stop),
   third removes it. A circle and a square distinguish modes without relying
   only on colour. These symbols show the mode, not a one-way green/red aspect.
2. Put automatic signals on approaches and exits around a junction or shared
   section. Signal tiles divide the connected network into blocks; switches and
   connected branches inside a block are treated as one conservative block.
3. **A** grants entry only when the next block is free or already owned by that
   train. **S** stops entry from either direction until changed or removed.
   A signal placed under a train lets that train finish clearing the tile.
4. Inspect waiting reasons in Fleet, the station inspector, Traffic or the event
   log. A reason identifies the manual signal or the train holding a block. The
   [Problems window](PROBLEMS_AND_WAITING.md) adds search, measured wait duration
   and map location; Overlays can display where stopped traffic has accumulated.
5. Open **Traffic**, select a train and **Hold selected train** to stop it exactly
   where it is. **Resume selected train** releases the hold and enables its service.
   Close Traffic and resume simulation; track reservations and signals still apply.
   Fleet **Withdraw service** remains different: it finishes the round trip.

Signals are free prototype controls. Running signal clicks execute through the
fixed-tick command queue; paused clicks apply immediately. They do not participate
in construction Undo/Redo. Holds apply while paused; opening Traffic pauses for you.

## Operating rules and limits

Each fixed tick seeds block ownership from actual train bodies (including held and
dwelling trains), then grants upcoming blocks in the same fixed-tick rotating order used by tile
and switch requests. Occupied blocks always take precedence over request order.
Authority is rebuilt every tick, so vacated blocks are released. Tile/switch
reservations remain the final safety check, including when new signals divide a
block containing multiple trains. Missing track ahead on the current leg freezes trains; a gap behind permits
delivery before the return-leg check.

Both signal modes share the rotating dispatch request policy. Priority classes,
route/platform signals and automatic passing-loop selection remain extensions. Signals alone cannot resolve a poor single-track layout; a cycle
may require [physical reversal](DEADLOCKS.md). Connected branches can make a block
larger than expected: add boundaries on each approach/exit. There is one assigned
running train per service. Use [waypoint directives](WAYPOINTS.md) to choose pass-through tracks.

Saves v22 persist signal locations/modes and dispatcher state. Runtime ownership is
reconstructed before movement. Shape/text indicators work alongside palette choices.

## Verification

```sh
godot --headless --path . --script res://tests/test_block_signals.gd
godot --headless --path . --script res://tests/test_signal_integration.gd
```

Unit checks cover competing entrances, deterministic request order, occupied/empty blocks,
release, manual stops in either direction, and clearing a signal changed under a
train. Integration checks exercise the tool cycle, real train stopping/resumption,
actual Hold/Resume buttons, persistence/invalid saves, v18 migration and equal
positions, money and events at 30/60/120 FPS. Also run reservation/deadlock suites.

[Dispatch fairness](DISPATCH_FAIRNESS.md) explains rotating first choice and prolonged-wait diagnostics.
