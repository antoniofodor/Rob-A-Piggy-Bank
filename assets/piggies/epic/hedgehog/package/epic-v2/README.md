# Hedgehog — epic v2

Built from the approved [concept](../../../_concepts-v2/epic-concepts.png).
Open the [Blender source](../../source/hedgehog-epic-v2.blend) or
[rendered preview](../../preview/hedgehog-epic-v2-hero.png).

Import `hedgehog-epic-v2-accessories.fbx` to use the existing shared pig body.
`hedgehog-epic-v2-complete.fbx` contains the complete static pig for inspection.
Both embed their textures. The body is 12 studs wide in the FBX; the editable
source retains the original 2-unit width. `asset-report.json` gives measured
per-mesh sizes/offsets, palette/Neon roles, and successful FBX round-trip checks.

The brown coat continues smoothly around the underside, with no cream strip
cutting across the belly. The cream face patch has a curved edge and ends
above the belly, using the same treatment as the peacock. The quills and
cream-tipped feet keep their existing design. Body and trim colour maps are
2048 pixels square.

31,022 triangles total; 10,440 in new accessories.
Every mesh is below 20,000 triangles and every accessory has zero nonmanifold
edges. Base vertices, topology and UVs are unchanged.

Status: uploaded and approved in Roblox on 2026-09-23; game integration pending.
See [upload receipts](../../roblox-uploads.json) for the model and coat image IDs,
and [mesh import records](mesh-import.json) for individual mesh/palette IDs and
validated canonical placement. All coat and palette textures load in Studio.
Installed in the game on 2026-09-23: coat pack, accessory set and skin row.
See the [shared handoff](../../../_concepts-v2/README.md) for the integration steps.
