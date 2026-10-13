# Environment asset generation prompts

Use the tile introduction for ground/water, and the object introduction for isolated
objects/overlays. Append one asset-specific prompt below. Generate each separately.
Save approved PNGs under `assets/environment/<category>/`; keep editable sources
and approved references under `art/environment/source/` and `art/environment/references/`.
These are art specifications; terrain/weather mechanics are not implemented by
adding these files. Suggested grid is 32 × 32 px per map cell. Large structures can
span several cells. Generator output requires pixel-art cleanup and tiling checks.

## Opaque tile introduction

Create an original terrain tile for a low-resolution railway management game.
Crisp pixel art, restrained palette, clear forms and consistent pixel scale.
Strict overhead orthographic view, looking vertically down; no isometric angle,
visible façades, horizon or perspective distortion. Subtle upper-left lighting.
Design on a 32 × 32 pixel grid. Opaque square, artwork filling the entire canvas,
no frame or transparent margin. Seamlessly tileable on opposite edges. Use solid
colour clusters, no blurred edges or smooth gradients. No text, watermark, rails,
vehicles or buildings. Match supplied reference assets' palette and pixel scale.

## Transparent object introduction

Create an original isolated asset for a low-resolution railway management game.
Crisp pixel art, restrained palette, clear silhouette and consistent pixel scale.
Strict overhead orthographic view, looking vertically down; no isometric angle,
visible building façades or perspective distortion. Upper-left lighting.
Real transparent background, no baked checkerboard, ground plane, text, watermark
or surrounding scenery. No blurred edges or smooth gradients. Centre the complete
asset with a small transparent margin. Keep shadows compact within the canvas.
Match supplied reference assets' palette and pixel scale. Treat dimensions below
as the intended final pixel grid, not a guarantee of the generator's output.

## Ground and water — use opaque tile introduction

### grass_01.png — terrain/
Short muted olive-green meadow grass. Subtle small pixel clusters with no strong
central feature or visible repeating stripes. Make three separate compatible
variants, keeping their edge colours and overall brightness consistent.

### soil_01.png — terrain/
Compact earthy brown soil with sparse small stones. Quiet texture that does not
compete with railway tracks. No large cracks or central motif.

### gravel_01.png — terrain/
Neutral grey crushed railway ballast, small angular stone clusters, low contrast.
No rails, sleepers or border; suitable as a repeating track-bed surface.

### snow_01.png — terrain/
Continuous undisturbed snow cover. Off-white surface with sparse pale blue-grey
pixel clusters, very subtle upper-left highlights. No footprints, objects or
large shadows. Quiet texture readable beside dark railway tracks.

### ice_01.png — terrain/
Frozen lake surface in muted pale blue-grey, a few restrained white ice flecks.
No large fracture pattern or central feature; seamlessly repeating edges.

### water_01.png — water/
Calm lake water in muted deep teal-blue. Sparse short light ripple clusters,
uniform overall brightness, no shore, foam, reflections of objects or central
feature. Seamlessly repeating edges.

### water_01_frame_01.png through water_01_frame_04.png — water/
Using the approved water tile as reference, create four individually exported
animation frames. Same canvas, palette and edge pixels in every frame. Change
only a few interior ripple highlights; no camera motion, scale change or drifting
shoreline. Frame four must loop smoothly into frame one. Export frames separately,
not an illustrated contact sheet. Seamless tiling in every frame.

### sand_01.png — terrain/
Muted beige sand with sparse small warm-grey pixel clusters. No shells, footprints
or dunes. Seamless low-contrast repeating ground texture.

## Shore transitions — opaque, use tile introduction with this override

For these transition tiles replace "seamlessly tileable on opposite edges" with
"edge-compatible with the supplied approved water and grass tiles". Reuse those
references. Do not independently invent new water or grass colours.

### shore_north.png — water/shore/
Water occupies the lower portion. Grass occupies the upper portion. A narrow
irregular earth/sand shoreline runs left-to-right through the tile. No objects.
Left and right shoreline endpoints must match when repeated horizontally.

### shore_corner_outer_nw.png — water/shore/
Grass forms a convex northwest land corner, joining the north and west tile edges;
water fills the rest. A narrow earth/sand boundary follows the convex corner.
Match the straight shoreline tiles' edge transition positions.

### shore_corner_inner_nw.png — water/shore/
Water forms a concave inlet touching the northwest corner; grass fills the rest.
A narrow earth/sand boundary follows the inlet. Match approved straight shoreline
edge transition positions.

Produce east/south/west versions of the straight shore and all four rotations of
each corner in the pixel editor. Check corners/straight edges on a repeated test
map. More transition combinations can be added when the terrain tileset is built.

## Isolated scenery — use transparent object introduction

### tree_deciduous_summer.png — vegetation/
One deciduous tree seen directly from above. 32 × 32 pixel canvas. Rounded irregular
leaf canopy in muted greens; trunk mostly hidden by the canopy. Compact lower-right
shadow. No visible side view of the trunk, ground patch or other trees.

### tree_deciduous_autumn.png — vegetation/
Using the approved summer tree as reference, create the same canopy silhouette,
canvas, centre and shadow in muted ochre, rust and copper foliage. Seasonal variant,
not a differently shaped tree.

### tree_deciduous_winter.png — vegetation/
Using the approved summer tree as reference, create the same tree and canopy extent
in winter. Sparse overhead branches and small snow clumps, matching canvas, centre
and shadow. No grass or surrounding snow-covered ground.

### tree_pine.png — vegetation/
One conifer viewed vertically down onto its pointed canopy. 32 × 32 pixel canvas.
Layered irregular radial needle clusters in dark muted greens. No side-on triangular
Christmas-tree silhouette, ornaments, ground or extra trees.

### rocks_small.png — scenery/
Three small irregular grey rocks grouped within a 32 × 32 pixel canvas. Distinct
upper-left highlights and compact shadows. Mostly flat shapes viewed from above.
No cliff wall or ground patch.

### shrubs.png — vegetation/
A small cluster of low leafy shrubs. 32 × 32 pixel canvas. Muted greens, irregular
rounded forms and compact shadows. No trees, ground patch or flowers.

### snow_patch.png — weather/
An irregular thin patch of snow as a transparent overlay on a 32 × 32 pixel canvas.
Opaque off-white snow clusters with stepped pale blue-grey edges; transparent gaps.
No ground beneath, objects or soft transparency gradient. This is an overlay, not
a seamless full snow terrain tile.

### snowfall_frame_01.png through snowfall_frame_04.png — weather/
A sparse transparent snowfall effect on a fixed 32 × 32 pixel canvas. Tiny white
1–2 pixel flakes, consistent pixel sizes. Four individually exported frames with
small steady downward movement and a seamless temporal loop. No background,
buildings, blue haze or blur. Match flake continuity across successive frames.

### rain_frame_01.png through rain_frame_04.png — weather/
A sparse transparent rain effect on a fixed 32 × 32 pixel canvas. Short muted
blue-grey pixel streaks leaning slightly right. Four individually exported frames
with steady downward movement and a seamless temporal loop. No scenery, puddles,
fog, lightning or motion blur. Keep the screen readable underneath.

### station_roof_small.png — buildings/
A small station building seen strictly from above, on a 64 × 32 pixel canvas.
Muted slate roof, restrained brick-coloured trim, one small chimney and a narrow
roof ridge. No visible façades, platform, rails, passengers or ground. The building
sits beside the railway rather than covering the track.

### warehouse_roof.png — buildings/
A modest cargo warehouse seen strictly from above, on a 64 × 64 pixel canvas.
Muted corrugated grey-blue roof, shallow stepped roof details and one small roof
vent. No façades, loading vehicles, rails, signs or ground.

### sawmill_roof.png — industry/
A compact sawmill building seen strictly from above, on a 64 × 64 pixel canvas.
Weathered timber-toned roof sections, a restrained metal vent and an open-sided
roofed work area visible only as a roof. No ground, rail tracks, loose logs or
visible façades. Logs will be separate reusable props.

### logs_stack.png — industry/
A compact orderly stack of cut timber logs viewed directly from above, on a
32 × 32 pixel canvas. Parallel warm brown cylinders, readable bark texture and
compact shadows. No wagons, machinery, ground or labels.

### timber_stack.png — industry/
An orderly bundle of sawn timber planks viewed directly from above, on a
32 × 32 pixel canvas. Pale warm wood, parallel rectangular planks and two dark
binding straps. Clearly distinct from round logs. No ground or vehicles.

### passenger_waiting.png — people/
One tiny standing passenger viewed strictly from above, on an 8 × 8 pixel canvas.
Head and shoulders readable from the top, muted blue clothing. Clear silhouette,
compact proportions and transparent background. No platform or side-facing body.
Create separate coat-colour variants on the exact same canvas and centre.

### passenger_walk_frame_01.png through passenger_walk_frame_04.png — people/
Using the approved passenger sprite as reference, create four individually
exported 8 × 8 pixel frames walking toward the top of the image. Same character,
canvas, scale and anchor in every frame. Tiny alternating arm/leg movement, no
camera movement or changing proportions. Frame four loops into frame one.

### signal_auto.png — railway/
A tiny railway signal assembly viewed strictly from above, on a 16 × 16 pixel
canvas. Compact dark housing and a readable circular lamp marker. Separate red,
amber and green state exports must share identical housing and anchor. Pair states
with distinct marker shapes so operational meaning does not rely on colour alone.
No track, ground or side-on upright signal illustration.

### waypoint_marker.png — railway/
A small golden diamond-shaped railway waypoint marker on a 16 × 16 pixel canvas.
Strong dark outline and a clear central dot. Flat map-symbol style, no pole,
ground or perspective. It must remain visible over both snow and grass.

## Quality and animation notes

AI is useful for concepts, but exact tile boundaries, tiny sprites and animation
registration usually need manual cleanup. Test tiling in a 3 × 3 grid. Remove baked
checkerboards. Keep animation frames identical in canvas size and anchor and avoid
independently regenerating each pose without a reference. Save separate PNG frames
or a carefully aligned sprite sheet, plus frame order/duration notes. Prefer subtle
2–4-frame effects initially; particle effects may replace weather sheets later.
