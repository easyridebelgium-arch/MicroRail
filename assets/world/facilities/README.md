# Live station and industry artwork

`sheets/facilities.png` preserves the v1 source bytes. `sprites/*.tres` provides
the two station buildings, platform deck, terminal, sawmill, factory and timber
yard used for the forest loading site. `runtime_manifest.json` records all 14
live facility/vehicle texture regions and source hashes.

The main renderer fits buildings into their existing 3 × 2-tile grounds, retains
name chips and click targets, and keeps city platform strips inside purchased rail
tiles. Pictures do not define buildability, platform length or passenger demand.

Integration, source mapping and replacement instructions:
[live world artwork](../../../docs/WORLD_ART.md).
