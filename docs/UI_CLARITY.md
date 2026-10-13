# UI clarity

The current UI work sits alongside Phase 1C feedback and Phase 2A gameplay.
It does not replace the network-safety milestones or passenger-transfer work.

## Grouped ribbon

The existing PNG buttons are ordered into four groups, separated by the supplied
pixel-art divider: Construction, Operations, Inspection, and Games/Settings.
Pause and Speed stay adjacent, as do Save and Load. Groups are identified in
separator tooltips. Controls remain individually focusable and can wrap without
forcing a wide group off-screen. No new shortcuts replace existing bindings.

Normal buttons are 64 logical pixels. Compact mode (selected in Settings, or
used automatically at 175–200% UI scale) reduces them to 48 logical pixels with
smaller icons. Display scaling still enlarges those controls; map zoom is preserved.
The existing selection underline, keyboard focus ring, live Problems counter and
speed dropdown remain active.

## Status bar and Accounts

The game clock, cash balance, operating profit, passenger deliveries and Accounts
button now have a wrapping status row beneath the ribbon. Feedback is one line,
with the current pause/wait/notice first. Hover it for the full message and mouse/
keyboard controls. This removes the old permanently displayed help/accounting
paragraphs from the map header.

**Operating profit** means all delivered passenger fares plus freight receipts,
minus both passenger and freight running costs. It is a session total, not a daily
rate or a reconciliation of cash balance. Construction, train/amenity purchases,
refunds, starting cash and objective rewards are excluded.

Accounts opens a paused, scrollable company overview containing revenue, running
costs, recorded construction spend, fleet spend less sale refunds, installed
amenities at current list value, objective rewards, queues and delivery totals.
Closing it does not automatically resume; use Play/Space. It reads existing state
without advancing the clock, changing routes or rebuilding reservations. Its
figures are refreshed while visible. Historical charts remain later work.

## Train inspector

Cause, measured waiting, current blocker identity, onboard destinations and advice
appear before actions. **Inspect blocking train #N** opens that train's current
inspector directly. **Locate blocking train** still jumps the camera to it.
Reverse and the existing route/traffic/fleet actions retain their safety rules.

**Show reservation details** expands physical body tiles, granted/requested tiles,
switch locks, block occupants/authority and deadlock participants. These are the
same read-only operating data as before. Details start collapsed for a different
train, and can stay expanded when refreshing the same train. Viewing either the
summary or details does not create new movement authority or change train position.
A stale measured wait remains explicitly identified as awaiting a movement sample.

## Validation and next work

`tests/test_ui_clarity.gd` checks grouping, live financial calculations, paused
Accounts, unchanged allocations, expandable details, direct blocker inspection
and readable layouts/Close buttons at 100%, 150% and 200%. Existing toolbar,
inspection, accessibility and simulation suites remain required.

The remaining current-stage UI work is listed in the roadmap's UI enhancement
table. Map/Goals visibility now persists in shared player preferences. Station/industry
inspectors now show overview, actions and expandable details, with an always-visible
Close button outside the scrolling region. Their sidebar is clamped in logical UI
pixels so 200% scaling does not double its width. Existing amenity, train-upgrade
and freight departure controls remain available. Bank loans are reached through
Accounts; see [loans](LOANS.md). Cursor-side construction feedback and consistent
tooltip descriptions are next. Branded
title-screen actions, save thumbnails and route identity colours are still planned.

## Cursor construction feedback and tooltips

During a track/removal drag a small, non-interactive callout follows the pointer.
It flips/clamps at viewport edges and hides over interface controls, dialogs or
when the gesture ends. It does not request reservations, emit events or change
money/track. Valid/invalid/partial/draft states use symbols and words rather than
colour alone. Build previews include new-track and automatic-switch charges;
removal previews show the refund for selected editable pieces and explain skipped
reserved tiles. Placement errors preserve the planner's actual message. Affected
services use the existing retained-path analysis; full details remain in Overlays.

Draft mode labels the amount as the **stroke** price and directs players to
Overlays for the combined draft price, refunds and validation. It does not judge
the entire draft's affordability from one stroke. Live reservations are current
operating data; the commit/Apply still rechecks safety and funds.

Toolbar tooltips now provide an action name and concise description. Relevant
keyboard/mouse bindings are read from InputMap after Settings Apply; no shortcuts
are invented for actions without bindings. Signal help distinguishes automatic
signals from permanent manual stops, and waypoint help distinguishes routing
markers from stations. Save/Load/Previous Save explain the four slots. Hover delay
is 0.4 seconds; existing accessible action names and keyboard focus remain.

Validation: `tests/test_construction_hint.gd` checks price/switch/refund accuracy,
reservation/error/draft wording, viewport corners at 100/150/200%, input pass-through,
remapped controls and unchanged finances/clock/events/authority. This batch also
passes the existing toolbar, UI clarity, UI scale, inspection, command-wiring,
panel-preference and mouse-track suites (eight focused suites total).
