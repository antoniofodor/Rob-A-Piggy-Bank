# Golden Bone — standalone game asset

Smooth golden dog bone matching the approved Supplies icon. One mesh with a
rounded shaft and paired knuckles; packed gold material palette.

- `golden-bone.glb`: preferred import with the packed palette.
- `golden-bone.fbx`: alternate import with embedded texture.
- `../../sources/golden-bone.blend`: editable source and presentation scene.
- `palette.png`, `manifest.json`, `validation.json`: materials, measurements,
  effect positions and verified GLB/FBX round trips.

Import at one unit per stud. The bone is approximately 2.68 studs long, oriented
along Roblox Z with knuckles across X, matching BoneModel's existing orientation.
Its authored root is at the visual center. Preserve that root when placing the
model. No rig is required. Disable CanCollide, CanTouch and CanQuery on the visual
mesh when used with the game's existing thrown-item presentation.

The three decorative star graphics remain in the shop icon. The 3D export is a
clean bone; optional golden sparkles are real particles added by the helper.
Install `../SupplyEffects.luau` and `../SupplyDefinitions.luau` together, then:

```lua
local fx = SupplyEffects.attach(model, root, "golden-bone", true)
-- root: invisible BasePart at the bone's authored center, moving with the model.
-- false as the last argument produces a clean shop preview.
-- fx.setEnabled(false) for distance culling; fx.destroy() before pooling.
```

FX_GlintA and FX_GlintB empties are exported position references. The helper creates
the corresponding Roblox Attachments. It uses built-in sparkle textures and has
no continuous update loop. Apply once per client and test appearance in Studio.
No changes to bait duration, dog behavior, prices or inventory are included.

Status: exported and validated; not uploaded or installed in the live game.
