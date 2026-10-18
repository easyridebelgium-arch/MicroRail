# Ground materials

`sheets/terrain.png` is an unchanged runtime copy of the original v1 sheet.
`materials/*.tres` selects all sixteen materials without editing source pixels;
`manifest.json` records their regions and provenance hash.

Summer grass, autumn leaves and fresh snow are used by the live background.
Plain grid and high-contrast fallback remain available. Water/other materials are
prepared resources, not newly simulated terrain. Review all materials by opening
`scenes/art/terrain_review.tscn` and pressing F6.

Usage, limitations and screenshots: [terrain artwork](../../../docs/TERRAIN_ART.md).
