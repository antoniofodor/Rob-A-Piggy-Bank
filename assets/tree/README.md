# Acorn oak -- RETIRED, KEPT AS AN UPLOAD AND MEASUREMENT RECORD

The acorn currency was deleted in schema 29 and `Config.ACORN_OAK_MESH` went
with it, so nothing here is on a lawn any more. `Config.TREE_MESH` is a
DIFFERENT tree -- the street scenery oak -- and its ids are not in this folder.
What survives here is `tree.json` / `tree.rbxmx` (two uploaded ids for the
first generated oak, unrecoverable if deleted), the measurements in
`blender/oak-report.json`, the briefs and the generation prompts.
`tree-oak-render.png` (the superseded v1 reference) and the five
`blender/oak-*.png` review renders were removed on 2026-09-23;
`blender/tree/build_oak.py` regenerates the renders and still loads
`tree-oak-render-v2.png`, which is why that one is kept.

## Current compact Blender oak

The designer requested a smaller tree in Blender. See
[`blender/README.md`](blender/README.md) for the editable model, GLB export,
actual mesh renders and character-scale comparison. It is 8.5 studs wide
and approximately 9.25 tall. The designer imported it, and the residential
plot builder now uses its uploaded assets in `Config.ACORN_OAK_MESH`.

## Previous generated asset — fallback

`tree.rbxmx` is the generated Roblox model, with separate `Trunk` and
`Canopy` MeshParts. Insert it into Studio using **Insert from File**.
The model uses the uploaded mesh and texture IDs recorded in `tree.json`;
it is not a standalone GLB containing geometry and textures.

The model's pivot is at the trunk base. It is approximately 10.2 studs wide,
10.88 studs tall, and 8.10 studs deep, already at yard size. Do not apply the
master plan's 0.85 street-tree scale a second time. Both parts are anchored;
only the trunk collides. Animate the canopy separately for the shake.

There are no baked acorns or basket. Add those as separate game objects.
The mesh was requested with a 9,000-triangle budget; this is the generator
request, not an independent triangle-count measurement.

`tree-oak-render-v2.png` is the approved visual reference. Studio's generator
accepts text only, so the 3D asset is a recreation, not an exact image-to-mesh
conversion. The generation prompt and measured part sizes are in `tree.json`.

The old source model was staged as `Workspace.AcornOak` in Studio. It was
previously integrated and is now superseded by the compact Blender oak above.
`Config.TREE_MESH` continues to describe the separate street scenery oak.
Basket, growth and shaking gameplay are still separate Phase 2 work.

Validation: model XML structure, stored asset references, part names, anchors,
and measured yard width/depth were checked. Studio's screenshot call stalled,
so the generated model still needs a visual comparison with the reference.
