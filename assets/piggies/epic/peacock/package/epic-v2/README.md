# Peacock — epic v2

Built from the approved [concept](../../../_concepts-v2/epic-concepts.png).
Open the [Blender source](../../source/peacock-epic-v2.blend) or
[rendered preview](../../preview/peacock-epic-v2-hero.png).

Import `peacock-epic-v2-accessories.fbx` to use the existing shared pig body.
`peacock-epic-v2-complete.fbx` contains the complete static pig for inspection.
Both embed their textures. The body is 12 studs wide in the FBX; the editable
source retains the original 2-unit width. `asset-report.json` gives measured
per-mesh sizes/offsets, palette/Neon roles, and successful FBX round-trip checks.

The teal coat now continues around the belly without the old cream underside
strip. A smooth cream face patch ends above the belly, and the teal legs wear
narrow cream ankle bands. The fan is lower and wider, with nine rounded
feathers, eyespots on both faces, and three separated crest stems.
Body and trim colour maps are 2048 pixels square.

52,862 triangles total; 32,280 in new accessories.
Every mesh is below 20,000 triangles and every accessory has zero nonmanifold
edges. Base vertices, topology and UVs are unchanged.

Status: uploaded and approved in Roblox on 2026-09-23; game integration pending.
See [upload receipts](../../roblox-uploads.json) for the model and coat image IDs,
and [mesh import records](mesh-import.json) for individual mesh/palette IDs and
validated canonical placement. All coat and palette textures load in Studio.
Installed in the game on 2026-09-23: coat pack, accessory set and skin row.
See the [shared handoff](../../../_concepts-v2/README.md) for the integration steps.
