# Corridor signal drafting

Open **Overlays → Draft construction**. In the draft controls:

1. Click **Pick start**, then click an existing or drafted track tile on the map.
2. Click **Pick end**, then click a second connected track tile.
3. Inspect the outlined route. Selection follows the shortest valid rail path,
   preserving switch entry rules. Select endpoints within the desired branch to
   avoid selecting a different path through a junction.
4. Choose **Spacing** (3–30 route tiles) and **Automatic signals**, **Manual stop
   signals**, or **Remove all corridor signals**.
5. Click **Draft corridor signals**. Inspect the pending PA/PS/P× symbols and
   the affected-service/ownership report, then **Apply plan**.

Platforms, facility grounds, switches, crossings and bends do not receive signals.
Placement considers the selected route's tile indices at the requested spacing
and includes an eligible final endpoint. Ineligible sampled tiles are skipped;
this may leave larger gaps. Removal covers every signal on the selected corridor.

Signals remain free prototype controls. They are staged separately from real block
boundaries, so trains see no changes until application. Track and signals can be
drafted and applied together; the point Signals tool also stages its cycle while
Draft construction is enabled. The entire transaction is refused if any target
is reserved, its original track/signal has changed, or the final geometry is invalid.
A successful signal batch has one Undo/Redo entry. History refuses to overwrite a
signal edited later or change signals on reserved track. Applied signals use the
existing save format; session-only drafts must be applied or discarded before saving.

Spacing is a placement aid, not an automatic dispatcher or a guarantee of safe
passing-loop operation. A junction and its connected branches can share one large
block unless boundaries divide them. Use [the tested passing-loop layout](MULTIPLE_SERVICES.md#a-repeatable-passing-loop-example)
and inspect **Signal blocks** and **Reservations** before resuming traffic. One-way
signals and automatic selection of alternate passing-loop routes remain planned.

```sh
godot --headless --path . --script res://tests/test_signal_corridor.gd
godot --headless --path . --script res://tests/test_corridor_integration.gd
```
