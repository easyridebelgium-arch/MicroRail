# Preparing the toolbar in Krita

These instructions refine the existing PNG pack; the game already displays it.
Keep filenames from [README.md](README.md). PNGs are game exports; `.kra` files are
editable sources. The original uploads should be kept as references, not overwritten
until you have checked the new exports.

## 1. Keep an editable copy

1. Open a PNG in Krita, then **File → Save As** a `.kra` file under
   `art/ui/toolbar/source/` (for example `button_states.kra` or `save.kra`).
2. Keep a copy of the original PNG under `art/ui/toolbar/references/` or outside
   the repository. Work on copies; the current game can keep using the old pack.
3. In the Layers docker, unlock the artwork layer if necessary. Hide any separate
   solid background layer. Transparent areas should reveal Krita's checkerboard.
   A checkerboard drawn into the image is not transparency.
4. If the background is baked into the same layer, use the **Contiguous Selection
   Tool** to select the outside background, adjust the selection so it does not
   eat the bevel, and delete it. Inspect the corners against both light and dark
   backgrounds. Do not select every white pixel: white icon highlights must remain.
   For difficult fringes, regeneration with real alpha can be cleaner than cutting.

## 2. Trim and resize a working copy

1. Zoom in. Use the **Rectangular Selection Tool** to enclose the complete visible
   asset, including every border pixel, without its large empty surround.
2. Choose **Image → Trim to Selection**.
3. Choose **Image → Scale Image to New Size**. Keep the aspect-ratio link enabled.
   Select **Nearest Neighbor/Nearest Neighbour** as the filter. This avoids blurred
   edges; it does not automatically turn a large AI image into clean pixel art.
4. Set the longest side to the target below. Check the preview/result: narrow
   strokes may disappear. Undo and simplify/redraw them if necessary.
5. Use **Image → Resize Canvas**, centre the anchor, and set the final square canvas
   where required. Canvas resizing adds space; image scaling resizes the drawing.

| Export | Canvas | Artwork fit |
| --- | --- | --- |
| Action icons | 24 × 24 px | Longest side at most 20 px; centre with ≥2 px margin |
| Six button backgrounds | 32 × 32 px | Identical outer silhouette across all states |
| Ribbon panel | 32 × 32 px | Plain stretchable centre; corners inside outer 6 px |
| Dropdown arrow | 8 × 8 px | Clear centred downward triangle |
| Group separator | 4 × 32 px | Consistent vertical line with transparent surround |

For an icon cropped to 300 × 240, scale to 20 × 16, then centre it on a transparent
24 × 24 canvas. Do not force it directly to 24 × 24 and distort its proportions.

## 3. Make the button states match

Independent AI generations have different borders and padding. Use one master
silhouette instead of separately scaling six inconsistent shapes.

1. Create a **32 × 32**, transparent Krita document. Copy the cleaned normal button
   into it. Align its bevel and corners on the pixel grid.
2. Name its layer `normal`, duplicate it five times and name the copies `hover`,
   `pressed`, `selected`, `selected_hover`, and `disabled`.
3. Change shading within that same outline. Hover gets a lighter highlight;
   pressed reverses/reduces the bevel to look inset; selected uses blue; selected
   hover combines blue and a brighter edge; disabled uses muted contrast.
4. Preserve the same canvas, outer corner pixels and border widths on every layer.
   Keep corner/bevel detail within the outer **6 px** on each side. Keep the centre
   plain so Godot can stretch it for wider controls without distorting corners.
5. Keep icons and labels out of these backgrounds. The game adds them separately.
6. Export each state by showing only its corresponding layer. Do not trim each
   exported state again: that would recreate inconsistent offsets.

The pressed file to replace is exactly
`assets/ui/toolbar/backgrounds/button_pressed.png`. Its transparency is now usable;
its border should be aligned with the normal button rather than positioned by eye
on its original large canvas.

## 4. Clean up the pixels

1. Work at roughly 800–1600% zoom with the pixel grid visible. Use a hard, 1 px brush
   at 100% opacity. Avoid soft brushes and antialiased shape edges.
2. Fix broken strokes, isolated specks, semi-transparent halos and uneven bevels.
3. Use the shared palette in README.md. Keep light coming from the upper left for
   the bevel; toolbar icons are front-facing symbols, not overhead world sprites.
4. Inspect at **100% zoom** and at **200%**. A beautiful enlarged drawing can still
   be unreadable at its actual size. Match stroke thickness across the entire pack.
5. Keep focus/selection recognisable by shape/brightness as well as colour. Godot
   retains its focus ring, tooltips and selected-tool underline.

## 5. Export and check in the game

1. Save the `.kra` source with its layers.
2. **File → Export** as PNG into the existing folder and filename. Preserve alpha
   transparency in the PNG options; do not flatten onto white. Do not export JPEG.
3. Reopen the exported PNG in Krita and confirm its dimensions/transparency.
4. Replace a small batch first: normal, hover, pressed and one action icon. Restart
   the game and check hover, pressed, selected, disabled and keyboard focus.
5. Test Settings UI scale at 100%, 150% and 200%, in a small window and fullscreen.
   Check the speed dropdown and Problems count as well as square buttons.
6. Once the states match, export the rest and commit the PNGs and editable sources.
   Do not manually edit Godot `.import` files.

The current adapter detects compact native-size images automatically. Large PNGs
with changed content positions need their crop bounds updated in
`scripts/ui/toolbar_art.gd`. Uniform native canvases make later adjustments easier.
The display currently uses 64 px buttons and up to 48 px icons: 2× these native sizes.
Extra UI scaling may use fractional display sizes; visual checks still matter.

## World assets are separate

For locomotives, wagons, stations, snow and water, keep the overhead orthographic
art style. Toolbar art uses a front-facing UI style. Do not automatically resize
world assets to 24 × 24: their dimensions must match the future map/sprite import
specification. Water/ground/snow surface tiles should usually fill their tile
edge-to-edge without transparent margins; decals, trees and vehicles need alpha.
Animation frames must share one canvas and pivot; avoid trimming frames separately.
