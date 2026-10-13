# Toolbar graphics

This folder holds approved, separate toolbar assets. The ribbon is assembled from
reusable pieces so it can fit different windows and 100–200% UI scale. Adding art
here does not automatically connect it to the game's buttons.

## Layout and filenames

```text
assets/ui/toolbar/
  backgrounds/
    ribbon_panel.png
    button_normal.png
    button_hover.png
    button_pressed.png
    button_selected.png
    button_selected_hover.png
    button_disabled.png
  icons/
    inspect.png
    track_connect.png
    track_draw.png
    track_remove.png
    switch.png
    play.png
    pause.png
    save.png
    load.png
    save_folder.png
    history.png
    routes.png
    fleet.png
    settings.png
    reservations.png
    overlays.png
    problems.png
    find.png
    traffic.png
    signals.png
    waypoint.png
    undo.png
    redo.png
  details/
    dropdown_arrow.png
    group_separator.png
  README.md
```

Use lowercase snake_case filenames. Keep icons separate from button backgrounds.
Keep labels, simulation speed and incident counters as live Godot text.

## Target dimensions

These are design targets, not a claim about the dimensions of uploaded files.
Preserve original artwork until it has been reviewed; do not blindly shrink it.

| Asset | Native size | Initial intended display |
| --- | --- | --- |
| Action icon | 24 × 24 px; symbol inside 20 × 20 px | 48 × 48 px |
| Button background | 32 × 32 px | 64 × 64 px |
| Ribbon background | 32 × 32 px reusable panel | Stretch to available width |
| Dropdown arrow | 8 × 8 px | 16 × 16 px |
| Group separator | 4 × 32 px | 8 × 64 px |

Export PNG with real alpha transparency, no baked checkerboard, text or watermark.
All button states must share the same canvas, silhouette and border geometry.
For stretchable backgrounds keep corners/bevels inside the outer 6 native pixels;
the centre must be plain. The proposed nine-slice margins are 6 px per side and
must be checked against the final artwork before integration.

Use nearest-neighbour texture filtering and integer art scaling where practical.
PNG imports should not introduce lossy compression. Exact Godot theme, filtering,
scaling and button-state wiring will be configured during the UI integration task.

## Visual style

Flat front-facing pixel-art UI. Upper-left highlights, dark navy surfaces,
restrained steel-blue bevels and readable light icons. Suggested palette:

| Role | Colour |
| --- | --- |
| Deep shadow | #101923 |
| Dark panel | #1B2836 |
| Raised surface | #263747 |
| Steel border | #52687A |
| Edge highlight | #8194A3 |
| Light icon | #E7EEF4 |
| Selected blue | #176391 |
| Selected border | #54B9EC |

Normal, hover, pressed, selected, selected-hover and disabled states must remain
recognisable. Do not communicate operational state using colour alone; retain
shapes, tooltips, focus indication and accessible text in the eventual UI.

## Sources and reference layout

Keep editable sources under `art/ui/toolbar/source/`, approved mockups under
`art/ui/toolbar/references/`, and generation notes under `art/ui/toolbar/prompts.md`.
Large unused experiments can stay outside the repository. Record creator/tool,
creation date, reference provenance and applicable licence/usage terms for approved
assets. Godot creates `.import` sidecars; do not hand-edit them or rename a live
referenced asset without updating references.

At documentation creation, the newly prepared toolbar PNGs were not visible on
GitHub's published branches. The existing `assets/ui/icons/toolbar.svg` is separate
from this proposed artwork pack and remains in place. No graphics are wired into
the game by this documentation update.
