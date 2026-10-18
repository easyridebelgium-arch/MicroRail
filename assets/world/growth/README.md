# City development and station detail artwork

`source_atlas.png` preserves the generated PNG. `props/*.tres` exposes 16 named
AtlasTexture candidates for city growth, station amenities and passenger details.
These are review artwork, not authoritative geometry, animation or growth rules.

Review via `scenes/art/asset_review.tscn` (F6). Generation records, inventory,
footprint/camera limits and replacement instructions:
[art pack v2](../../../art/generated/microrail_pack_v2/README.md).
Do not replace the current world renderer until the camera/pixel-density issues
are resolved and each object is fitted to the actual map footprint.

## Live city density

`props/city_small_cluster.tres`, `city_town_block.tres` and `city_dense_block.tres`
now render live city density through `scripts/art/city_art.gd`. Sources remain
unchanged. Rendering fits each image inside the existing five-by-three protected
plot and never determines movement or construction geometry. See
[population rules](../../../docs/CITY_GROWTH.md). Other props remain prepared resources.
