# Automatic junction construction

Draw or Connect a branch onto an existing straight line, or drag outward from
a straight tile that already connects through to its neighbors. The preview
replaces that tile with a switch, preserving the original through line and adding
the branch in the direction of the new track. A new track endpoint touching the
side of an existing straight tile also includes that neighboring switch.
Merging onto a straight end tile works even if it has zero or one connected
neighbors, including when the approach begins on an already-built branch. The
switch is placed on the selected merge tile, not on an offset old-port approach.

The normal switch price (£100) is added to new-track costs (£10 per piece).
The preview shows the full amount. The approach and switch commit together;
Undo/Redo treats the entire stroke as one action. In Draft construction the switch
is staged with the approach and included in the aggregate quote.

Automatic placement does not bypass safety. Reserved/occupied junctions reject
the whole edit. Remove a signal before turning its tile into a switch. Fixed
station/facility tiles stay unchanged. A pending stroke is rejected if its target
track changes before the next fixed simulation tick.

An ordinary switch has three ports. Its stem connects to the original through
exit or the new branch; the two exits do not connect directly. The incoming branch
angle determines the stem orientation, with the stroke's requested continuation
breaking ties for perpendicular branches. Existing route authority still controls
the active switch state. Four-way crossings and extra exits require separate
junctions; automatic construction does not convert them into unsupported switches.
The manual Switch tool remains available for cycling a junction's shape.

Short right-click returns active map tools to Draw track and cancels the current
gesture. Right-drag, or holding right for 0.4 seconds, previews track removal,
which commits on release. A drag starts after 6 screen pixels; it needs no hold
delay. Escape, entering UI or losing window focus cancels the gesture safely.
Remove remains available through the toolbar or remappable **R**, with left-drag.
Opening Traffic pauses the game; right-click closes it on release and keeps pause.

Checks: `test_auto_switches.gd` covers all eight through orientations and branch
approaches, preserved through routes, branch routing, neighbor switches, costs,
Undo/Redo, drafts, signals, occupancy and stale queued strokes.
It also covers merging from existing branches into isolated/end/through tiles.
`test_tool_reset.gd` covers reset from all map tools, Traffic window input, draft
retention, left-drag removal and migration of the previous mouse binding.
`test_right_mouse_gesture.gd` checks hold/drag classification at 30/60/120 FPS and
1×/10× speeds, movement thresholds at 100%/200% UI scale, cancellation, protected
track, draft removal, typing/modal guards and remappable R.
