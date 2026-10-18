# Feedback and progress UI artwork

New UI candidates live here, separate from the existing artist-supplied toolbar.
`source_atlas.png` preserves the generated PNG. `icons/*.tres` exposes 16 named
AtlasTexture resources without cropping or changing the source pixels.

Review via `scenes/art/asset_review.tscn` (F6). Generation records, inventory,
replacement instructions and limits: [art pack v2](../../../art/generated/microrail_pack_v2/README.md).
Keep live text, tooltips, focus and colour-independent state cues when integrating.
Most icons remain prepared resources. `icons/first_service_guide.tres` is now
used by the live Guide button; it retains a text label and tooltip.
