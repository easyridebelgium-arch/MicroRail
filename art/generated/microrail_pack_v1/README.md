# MicroRail generated art pack v1

Seven AI-generated PNG source sheets, with **112 proposed entries** for the game.
Created on 2026-10-14 using the OpenAI image generation tool at the user's request.
These remain the original review/editing sources. A selected **14-texture subset**
from the rolling-stock and facility sheets is now used by the live game through
runtime copies and measured AtlasTexture regions. See [live artwork integration](../../../docs/WORLD_ART.md).
The terrain sheet now also supplies live summer/autumn/snow backgrounds, with all
16 ground materials exposed as named resources and in a review gallery. See
[terrain integration](../../../docs/TERRAIN_ART.md). Remaining sheets stay candidates.
Existing toolbar/logo and simulation rules are preserved.

## Files

| Sheet | Proposed contents (16 entries per sheet) |
| --- | --- |
| [Terrain](sheets/terrain.png) | Summer/meadow/dry grass, autumn leaves, fresh/patchy snow, ice, rock, deep/shallow water, sand, gravel, soil, furrows, asphalt, paving. |
| [City roofs](sheets/cities_roof_plan.png) | Cottages, terraces, bungalow, courtyard, apartments, office, town hall, school, hospital, market, shop, warehouse, church, garden. |
| [Facilities](sheets/facilities.png) | Passenger stations, platform/canopy, terminal, sawmill, factory, timber/forestry/container yards, depot, fuel facility, shelter, footbridge, crane, turntable. |
| [Rolling stock](sheets/rolling_stock.png) | Steam/diesel/electric locomotives, passenger powercars, maintenance locomotive, coaches, luggage van, boxcar, tanker, coal hopper, timber flatbed. |
| [Scenery](sheets/scenery.png) | Summer/autumn/winter trees, bare tree, shrubs, flowering bush, rocks, pond, footbridge, bench and picnic table. |
| [Railway equipment](sheets/railway_equipment.png) | Distinct-shape signal markers, one-way/waypoint markers, buffer stop, switch motor, cabinet, water tower, silo, signal box, catenary mast, crossing barriers, tools and sleepers. |
| [People and effects](sheets/people_effects.png) | Traveler direction proposals, waiting passengers, worker, wheelchair user, smoke, steam, rain, snow, loading dust and sparks. |

`manifest.json` lists every entry's intended row/column, unique ID and suggested
individual PNG filename. Rows/columns are **one-based** and describe the nominal
4×4 layout; they are not verified cropping coordinates. Actual PNGs are 1254×1254,
not the requested 1024×1024. The dimensions are not divisible by four, and some
sprites approach nominal cell boundaries. Select and check each object manually.

`PROMPTS.md` records the exact prompts for the seven selected sheets. The initial
city sheet is preserved under `references/cities_initial.png` only as the reference
for the camera-correction edit; it is not another set of 16 selected assets.
PNG source bytes are unchanged from tool output. The manifest includes SHA-256
hashes, actual dimensions, image modes and alpha extrema. Terrain is opaque;
the other six sheets have real alpha transparency.

`.gdignore` keeps these original sheets out of Godot's importer. Reviewed live
selections use unchanged copies under `assets/vehicles/` and
`assets/world/facilities/`, with ground materials under `assets/environment/terrain/`;
the remainder stays here. Adding source sheets does
not unlock the depicted stock, industries, terrain, seasons or weather mechanics.

## Cleanup and export targets

Work on copies in Krita; keep these originals. Choose a consistent native pixel
grid, select the full object, remove unwanted neighboring pixels, and repaint
details for the final size. Resizing a detailed source is only a starting point.
Use PNG with alpha for objects, opaque PNG for terrain, and nearest-neighbor
filtering for pixel-art previews/imports. Match pixel density across categories.

| Runtime use | Initial target, to verify during integration |
| --- | --- |
| Ground/water material | 32×32 px per tile; test opposite edges in Krita wrap-around mode. |
| Individual city building | 32×32 or 64×64 px; compose buildings within the authoritative 5×3-tile city footprint (160×96 px). |
| Station building | 96×64 px for the current 3×2-tile building footprint. |
| Platform | Modular 32×32 px tiles; current construction purchases five tiles (160×32 px). Do not stretch a source building over the platform. |
| Industries | Match the existing 3×2-tile grounds plus separate loading stop; remove overhangs or agree an explicit footprint change first. |
| Vehicle | Initial north-facing body about 12×28 px; verify width, center anchor and couplers. Current movement uses a 28 px body and 32 px spacing. Rotate/redraw to match the renderer's direction convention before use. |
| Trees/props | Usually 16×16 or 32×32 px; larger trees need deliberate layering and clearances. |
| Waiting passengers | Approximately 6×8 or 8×8 px; redraw to stay readable at gameplay zoom. |
| Operating markers | Usually 16×16 px with shapes and tooltips retained alongside color. |
| Smoke/weather particles | Small separate transparent sprites; animate in Godot after reduced-motion and layering checks. |

## Observed review work

- **All sheets:** final pixel density, palette, padding, anchors and alpha-edge
  cleanup are pending. Do not blindly split a nominal grid and declare it ready.
- **Terrain:** tiling and transition edges are unverified. Reduce busy textures
  where they compete with track. Water needs shoreline/corner pieces; snow needs
  terrain transitions. These sheets do not provide an autotile connectivity set.
- **City roofs:** the correction removes most facades, but dormers, tiny wall
  edges and roof/building identities still need review. The town-hall silhouette
  may read as a church; repaint it if that building type is used.
- **Facilities:** depot entrances and some equipment still suggest perspective.
  Flatten those details and fit the actual footprint. Roof scale varies.
- **Vehicles:** lengths/widths are inconsistent, and some couplers sit close to
  the next row. Select carefully. North-facing art is not a tested direction set;
  align pivots and validate turns before replacing procedural train drawing.
- **Scenery/equipment:** remove unwanted perspective on towers, supports and
  props. Operating signals remain driven by reservation/block state; art cannot
  determine whether a train is allowed to move.
- **People/effects:** the requested directions are proposals, not validated
  animation frames. Faces/body angles and wheelchair scale need cleanup. Smoke
  sizes are separate shapes, not an ordered, seamless animation. Weather particles
  must remain cosmetic until the relevant mechanics are deliberately implemented.

Live integration covers the current locomotives/coaches, log wagons,
station roofs, concrete platform, forest/terminal/sawmill/factory presentation
and selectable summer/autumn/snow ground.
The authoritative graph, occupancy footprints, accessibility overlays and waiting
information remain intact. City placement and seeded starts are already implemented;
city roof art, scenery, water obstacles and the other stock/facility entries remain later work.

Provenance is the generation record above; this pack is not third-party CC0 art.
No external reference art was supplied for these generations. Review and record
any later contributions and their provenance when creating approved exports.
