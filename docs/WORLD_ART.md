# Live train, station and industry artwork

The first selected assets from the existing `rolling_stock.png` and `facilities.png`
sheets are now used by the ordinary main scene, in tutorial and city games. Open
the project and press **F5**; this does not require the separate artwork gallery.
Existing saves automatically use the new presentation. Save format remains 41.

## Integrated artwork

| Game object | Source sheet selection |
| --- | --- |
| Passenger Shuttle | Cream/red passenger powercar, row 2 column 2 |
| Fast Passenger | Blue passenger powercar, row 2 column 3 |
| Log Hauler | Red diesel, row 1 column 3 |
| Heavy Log Hauler | Blue diesel, row 1 column 4 |
| Passenger coach | Red/cream coach; fast services use blue/silver coach |
| Loaded log wagon | Timber flatbed, row 4 column 4 |
| Station | Small red-roof building; purchased Waiting room uses the larger roof |
| Platforms | Concrete deck with yellow edge, repeated along the platform |
| Forest loading site | Timber-yard stacks |
| Cargo terminal | Terminal warehouse |
| Sawmill / factory | Their matching buildings |

Empty wagons use a small matching deck drawing because the sheet contains no
empty flatbed frame. Timber and goods use distinct plank/crate drawings on that
deck instead of displaying logs after processing. These are cargo-category cues,
not a count of individual physical load units. Locomotive names, performance and
prices remain those in Fleet; the artwork does not unlock new eras or stock types.

## Files and replacement

- `assets/vehicles/sheets/rolling_stock.png`: unchanged runtime copy of the source.
- `assets/vehicles/sprites/*.tres`: seven individually named AtlasTextures.
- `assets/world/facilities/sheets/facilities.png`: unchanged runtime source copy.
- `assets/world/facilities/sprites/*.tres`: seven facility/platform AtlasTextures.
- `assets/world/facilities/runtime_manifest.json`: measured regions and SHA-256 hashes.
- `scripts/art/world_art.gd`: cached textures and presentation helpers.

Originals and generation provenance remain in
[art pack v1](../art/generated/microrail_pack_v1/README.md). The runtime copies are
outside its `.gdignore`. No source PNG was cropped, repainted or resampled; Godot
AtlasTexture regions select the artwork, with lossless import and nearest filtering.
Regions account for actual row spacing, not an assumed equal-quarter grid.

For a replacement, change the relevant `.tres` texture reference/region while
retaining the same visual envelope. Use an isolated transparent PNG if available.
Record the replacement's provenance in the manifest. Other source-sheet entries
remain future artwork; their presence does not introduce additional industries,
vehicle classes, terrain or seasons.

## Geometry, rendering and accessibility

- Vehicle sprites are fitted inside a 14 × 28 px box, centred on the existing body
  pose. A drawing-only quarter turn aligns north-facing art with positive-X heading.
  Existing consist offsets, body length, rotations, reversal and switch locks govern
  all movement; pixels do not change occupancy or collision.
- Facility pictures remain within the existing 3 × 2-tile reserved building grounds.
  Labels use an opaque name chip and retain normal inspection/click geometry.
- City platforms show all five purchased tiles. Their apron is inside the rail
  tiles, so outer columns cannot hide a separate track above the building footprint.
  Tutorial/industry aprons use the existing reserved strip above the track.
- Route labels, IDs, signal shapes, reservation hatching and construction markers
  remain separate. High-contrast mode adds a white vehicle outline and preserves
  front lights. Palette switches do not repaint the original art.
- Stations are still horizontal; existing train sprites rotate with the route.
  There is no new animation, livery editor or station orientation mechanic.

## Preview and verification

[Example network screenshot](images/polished_world_preview.png) is an actual Godot
Compatibility-renderer capture of a constructed example, with coaches/log wagons
and installed facilities. It is not a new starting layout or a scenario unlock.
Scroll the wheel to inspect artwork more closely in your own game.

Validation includes source alpha/region/hash checks, an actual rendered preview,
the GDScript warning audit and existing consist, loop, multi-stop, inspection,
platform, city and first-session regression suites. Visual camera/pixel density
can still be refined from player feedback without changing the simulation.
