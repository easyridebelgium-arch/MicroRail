# Live rolling-stock artwork

`sheets/rolling_stock.png` is an unchanged copy of the approved-for-integration
v1 source sheet. `sprites/*.tres` provides individual AtlasTextures for the four
existing locomotive models, two coach appearances and loaded log wagon.

Render north-facing sprites inside a 14 × 28 world-pixel envelope, adding a
drawing-only quarter turn to the simulation heading. Use the existing physical
consist poses and offsets; never enlarge occupancy based on source PNG dimensions.
`scripts/art/world_art.gd` handles drawing, empty decks and processed cargo cues.

Regions/hashes are recorded in
`assets/world/facilities/runtime_manifest.json`. Integration and replacement guide:
[live world artwork](../../docs/WORLD_ART.md).
