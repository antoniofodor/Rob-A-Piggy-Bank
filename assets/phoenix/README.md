# Phoenix legendary pig

Created from the project's separated Body, Snout, Ears, Legs and Tail meshes, using `approved-concept.png` as the visual target. The Phoenix uses simplified, faceted copies of those body parts: 4,168 triangles total, 32 broad feathers and a 15-bone rig. The original shared pig master is untouched; the coin slot and rear vault bore remain clear. Black nostril insert objects are removed; the snout retains its sculpted recesses.

## Files

- `../../blender/pig/skins/phoenix/phoenix.blend` — editable scene, named feather rig, four-second idle loop, materials, lights, three cameras and animated preview flame/ember geometry. Open and press Space to preview animation.
- `Phoenix.fbx` — full pig with separate body parts and rigged feather groups, in a neutral pose. Import this model first.
- `Phoenix_Idle.fbx` — the same rig with the four-second looping feather animation. Import this into Roblox's Animation Editor against the imported rig, then publish the animation under the game's owner/group.
- `Phoenix.glb` — portable textured/animated copy for inspection in compatible viewers.
- `Phoenix_palette.png` — shared color atlas, also packed into the Blender scene and GLB and embedded in the FBX.
- `PhoenixEffects.luau` — Roblox companion for glowing tips, small flames and floating embers. This is an import companion, not automatically installed into the live skin system.
- `Phoenix-report.json` — exact part colors, bone mapping, source units and effect locations.
- `Phoenix-validation.json` — source-silhouette, weight, animation loop, opening-clearance and export round-trip checks.
- `Phoenix-idle.gif` — preview of the actual rig animation.
- `Phoenix-hero.png`, `Phoenix-rear.png`, `Phoenix-crown.png` — actual Blender renders.

## Roblox import

1. Import **Phoenix.fbx** with its hierarchy and bones preserved. Keep the full model together. Import only once; the animation file is not a second display model.
2. The source body is two Blender units wide; the game body is 12 studs wide. Scale the **whole model uniformly** until Body.Size.X is 12. The source origin is retained for alignment to the existing pig, with ground at Blender Z = -1.02. Match the existing pig's body center and front direction; do not resize individual pieces.
3. If the importer does not retain colors, upload `Phoenix_palette.png` and assign it as the mesh color texture (or SurfaceAppearance.ColorMap) across the model. It uses the included `PhoenixPalette` UVs. Preserve the atlas for Body and Legs, which have multiple colors. Do not apply this atlas to the old in-game mesh: the new exported copies carry the atlas UVs.
4. Import `Phoenix_Idle.fbx` through the Animation Editor, publish it, and play its AnimationId through the rig's AnimationController/Animator with `Looped = true`. The base body remains stationary while the crest, cheek fans, coat and tail feathers sway.
5. Put `PhoenixEffects.luau` in a ModuleScript and call `Effects.attach(phoenixModel)` on the client after scaling. Call its returned cleanup function before removing/replacing the skin. This expects actual imported Bone instances and checks their presence. The final effect attachment placement still needs an in-game visual check after import.
6. Wire this imported asset into the Phoenix skin only. Keep the game-built coin pile, vault plate, interactions and effects in their existing positions. This package does not replace the global pig mesh or automatically add a new crate entry.

The Blender flame tongues/embers are preview-only and deliberately excluded from FBX/GLB. Roblox glow and particles are supplied by the companion; Blender emission and compositor bloom do not become Roblox effects. No animation asset ID is fabricated or published by this build.

## Rebuild

Use Blender 5.2.2 LTS:

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -t 8 --python blender/pig/skins/phoenix/build_phoenix_asset.py
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python blender/pig/skins/phoenix/validate_phoenix.py
```

The generator reads `paths.RAW` and writes `paths.skin_blend('phoenix')`. Rebuild the raw pig with `blender/pig/make/build_pig.py` if it is missing. It does not overwrite the editable separated `pig_parts.blend` master. The low-poly copies keep their vertices within 0.009 Blender units of the original surface. The idle loop closes exactly, and the FBX/GLB files were imported back successfully. The Roblox companion passed an isolated Studio test for effect creation, Neon tips and cleanup. Placement on the actual imported asset still requires visual checking.

NumPy must be compatible with the host; on this Mac the export runtime uses `/tmp/guard-blender-python` when available.
