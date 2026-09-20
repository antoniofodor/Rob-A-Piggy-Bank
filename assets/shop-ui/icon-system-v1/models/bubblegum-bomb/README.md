# Bubblegum Bomb — standalone game asset

Pink sticky gum body, raised gum patches, short curved fuse, pink fuse collar and
golden ember. Reuses the approved Supplies icon geometry; no candy wrappers.

- `bubblegum-bomb.glb`: preferred import, packed palette and two meshes.
- `bubblegum-bomb.fbx`: alternate import with embedded texture.
- `../../sources/bubblegum-bomb.blend`: editable source and presentation scene.
- `palette.png`, `manifest.json`, `validation.json`: materials, exact measurements,
  effect positions and verified GLB/FBX round trips.

Import at one unit per stud. The ball is about 1.88 studs across, matching the
existing gum projectile scale. Preserve the root at the center of the gum ball,
not the center of the complete model including its fuse. Blender +Z becomes
Roblox +Y. Keep GumBody and Fuse together under one Model; no rig is required.

For the game's anchored projectile presentation, disable CanCollide, CanTouch and
CanQuery on both meshes. Keep GadgetModel.flightCFrame and the existing gum hit/
puddle behavior. The files do not change those systems or install themselves.

Optional fuse sparks: install `../SupplyEffects.luau` and `../SupplyDefinitions.luau`
together. Pass an invisible BasePart at the model's authored root as `root`:

```lua
local fx = SupplyEffects.attach(model, root, "bubblegum-bomb", true)
-- false as the last argument produces a clean shop preview.
-- fx.setEnabled(false) disables emission and clears existing particles.
-- fx.destroy() cleans up before pooling or replacing the model.
```

The FX_FuseTip empty is an exported position reference; the helper creates the
Roblox Attachment and emitter. World effects follow the moving root. No floating
star mesh is baked into the projectile. Test final import and effects in Studio.

Status: exported and validated; not uploaded or installed in the live game.
