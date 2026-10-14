# Simulation definition resources

`cargo/` holds typed cargo prototypes (stable ID, definition schema version,
display name and terminal price). `industries/` holds typed production prototypes
(input/output cargo IDs, recipe, productive tick budget, build price and storage).

These `.tres` files are read-only shared prototypes. Runtime inventory, processing
progress, movement and upgrades belong to separate saved state. Definition schema
versions are distinct from the root save version. Preserve stable IDs and add a
migration plus conservation/transport tests when changing saved semantics.

Current slice: logs → sawmill → timber → optional factory → goods terminal. See
[operation and persistence](../docs/FACTORY_CHAIN.md). Rolling-stock resources and
additional industries remain later work; this folder does not replace fleet models.
