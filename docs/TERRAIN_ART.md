# Grass, snow and ground artwork

The original terrain sheet is now available through ordinary gameplay. Run **F5**:
summer grass is the default, including for existing saves. Use **Menu → Settings →
Ground** to choose **Summer grass**, **Autumn leaves**, **Snow** or **Plain grid**,
then press **Apply**. **Show map grid** can be disabled for a cleaner view.

These are static cosmetic choices, not automatic seasons. They never change
speed, traction, demand, buildability, routes or train positions. High-contrast
mode uses the original plain background and a visible grid while preserving your
preferred ground/grid settings for other palettes. Textured ground has muted
colours and the rails have a dark ballast bed to remain readable, especially on snow.

Ground/grid preferences live in `user://settings.cfg`, separate from saved
companies. Old settings default to summer/visible grid; an unknown style falls
back to summer. Editing or cancelling Settings does not apply a draft choice.
No game save version changes.

## Asset locations

| Location | Contents |
| --- | --- |
| `art/generated/microrail_pack_v1/sheets/terrain.png` | Original generated source sheet |
| `assets/environment/terrain/sheets/terrain.png` | Unchanged runtime copy |
| `assets/environment/terrain/materials/*.tres` | All 16 individually named AtlasTexture resources |
| `assets/environment/terrain/manifest.json` | Source hash, regions and active background selections |
| `scripts/art/terrain_art.gd` | Cached textures, visible-patch drawing, grid colours and track beds |
| `scenes/art/terrain_review.tscn` | F6 review gallery of every material, including water |

Materials include summer/meadow/dry grass, leaf litter, fresh/patchy snow, ice,
rock, deep/shallow water, sand, gravel, soil, furrows, asphalt and paving.

**Water textures are prepared, but rivers, lakes and water-crossing rules are not
added to playable maps in this batch.** Painting a buildable river would mislead
players about bridge requirements. Review these textures through the F6 gallery;
terrain obstacles, shoreline transitions and bridges remain separate roadmap work.

## Rendering and source limitations

The 1254 × 1254 RGB source is preserved byte-for-byte. Each selected region has
a two-pixel inset from its nominal quadrant, avoiding neighbouring materials.
Godot imports losslessly and uses nearest filtering. Live drawing uses explicit
source-sheet regions, preserving facility/vehicle visibility across repeated
background changes. Ground repeats in 128-world-
pixel patches aligned to world coordinates, with visible-area culling and map-edge
clipping. It does not repeat the entire atlas or sample another material.

The source was not supplied as a verified seamless tile/autotile set. Some repeated
patterns or seams may remain visible; the quieter tint reduces distraction. Replace
a material resource with an approved seamless PNG later without changing gameplay.
No runtime image resizing or random cosmetic draws consume the simulation RNG.

## Review and checks

[Summer example](images/terrain_summer.png), [snow example](images/terrain_winter.png)
and [all materials](images/terrain_materials.png) are actual Godot renderer captures
of an example network/gallery. They are not new starting layouts or new terrain rules.

The terrain appearance suite checks old/invalid preferences, all 16 resource
regions, Apply/persistence, high-contrast fallback and 200% UI layout. Related city,
construction, display, menu and toolbar tests protect existing behaviour. The
rendered smoke check switches all four appearances and verifies that RNG, clock,
track, trains and money remain identical.

For the sprite-clipping regression, run `godot --path . --script
res://tools/check_terrain_render.gd` with a graphics display. It compares opaque
facility pixels across repeated theme changes, as well as simulation snapshots.
It exits as unexecuted under the headless dummy renderer, which cannot validate
actual pixels. This check guards buildings disappearing when atlas batches redraw.
