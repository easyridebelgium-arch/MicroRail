# Feedback and city-growth art pack

Created 15 October 2026 with OpenAI image_gen at the project owner's request.
Two original transparent PNG atlases contain 32 candidates. No external reference
images were supplied. This is AI-generated artwork, not a third-party CC0 pack.

## Review in Godot

Open `scenes/art/asset_review.tscn` and press **F6** (Run Current Scene).
Alternatively run `godot --path . scenes/art/asset_review.tscn` from the repository.
Scroll through UI icons and world objects. Each card shows a larger inspection
preview and an intended display-size preview. Tooltips identify resource files.
The scene is separate from the title/main game; F5 still starts MicroRail normally.

## Locations

| Purpose | Location |
| --- | --- |
| UI atlas, original bytes | `assets/ui/feedback/source_atlas.png` |
| Individually named UI textures | `assets/ui/feedback/icons/*.tres` |
| Gameplay atlas, original bytes | `assets/world/growth/source_atlas.png` |
| Individually named world textures | `assets/world/growth/props/*.tres` |
| Inventory, regions and hashes | `manifest.json` beside this README |
| Exact generation requests | `PROMPTS.md` beside this README |
| Visual review scene | `scenes/art/asset_review.tscn` |

Each `.tres` is an ordinary Godot **AtlasTexture**, usable in a TextureRect,
Sprite2D or texture property. Its region references one source atlas; there are
no cropped/resampled PNG copies. The original generation outputs also remain in
the cloud workspace's `generated_images` directory. Source files are unchanged.

## Contents

UI: first-service guide, rotating autosave, service report, watchlist, city growth,
decline, stability and grace period, completed journey, waiting queue, unmet demand,
on-time departure, network summary, delivery objective, beginner assistance and
blocking-train trace.

World: small/town/dense building clusters, construction foundation, garden,
new trees, civic plaza, vacant plot, platform bench, shelter, kiosk, waiting room,
two directional passenger-group proposals, accessible passenger group and luggage
trolley. These supplement the broad v1 pack; the existing artist's toolbar/logo
and the game renderer are preserved.

## Actual dimensions and review limits

Both tool outputs are **1254 × 1254 RGBA**, rather than requested 1024 × 1024.
They have genuine alpha transparency. Layout is not an exact uniform 4 × 4 grid:
the first gameplay row crosses the nominal quarter boundary. Regions in the
manifest use measured alpha bounds inside manually separated rows/columns, with
padding. Do not divide the files into equal quarters or expect tileable terrain.

- UI uses shape differences alongside colour (up/down arrows, equality bars,
  clocks, checks and a broken connector). Keep live labels, tooltips, accessible
  names and keyboard focus when integrating. Fine details need testing at 24–32 px.
- World candidates still show some facade edges and passenger body perspective;
  the requested strict roof-plan camera was not fully achieved. Direction names
  are proposals, **not verified direction frames**. Redraw/approve before replacing
  the world renderer. No animation or directional completeness is claimed.
- Passenger groups are not individual sprites or count-accurate crowd renderers.
  When integrated, show real queue counts, cap decorative sprites and retain the
  numerical accessibility alternative.
- UI previews use a 32 px box; world previews use a provisional 64 px box.
  These do not define physical sizes. Houses must fit the existing 5 × 3-tile city
  footprint, station buildings the existing 3 × 2 footprint, and amenity placement
  must preserve platforms, tracks, labels and click targets.
- Use nearest-neighbour filtering and lossless import. These are high-resolution
  source candidates, not pixel-perfect native sprites or a seamless autotile set.
- Growth-stage art does not implement growth/decline, autosave art does not add
  autosaves, and report/goal icons do not implement the associated UI or rules.

## Replacing an asset

Keep the existing PNGs and review them in Krita before modifying. For one approved
replacement, export a tightly padded transparent PNG under the corresponding
`icons/` or `props/` folder using the same base name. Update the consuming texture
reference and manifest; an isolated PNG need not replace the entire atlas.
For another atlas, update its `.tres` regions as well as the manifest. Never rely
on the generator reproducing identical margins. Record new provenance and hashes.

For seamless ground, vehicles and broader industry scenery, use the earlier
[v1 source pack](../microrail_pack_v1/README.md) and its cleanup notes.
