# City development and station detail artwork

`source_atlas.png` preserves the generated PNG. `props/*.tres` exposes 16 named
AtlasTexture candidates for city growth, station amenities and passenger details.
These are review artwork, not authoritative geometry, animation or growth rules.

Review via `scenes/art/asset_review.tscn` (F6). Generation records, inventory,
footprint/camera limits and replacement instructions:
[art pack v2](../../../art/generated/microrail_pack_v2/README.md).
Do not replace the current world renderer until the camera/pixel-density issues
are resolved and each object is fitted to the actual map footprint.
