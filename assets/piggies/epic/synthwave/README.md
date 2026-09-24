# Synthwave — Arcade v1

Midnight purple pig with magenta and cyan perspective grid across lower body, large striped orange-to-pink sunset discs on both flanks, purple snout, cyan eyes. Restrained animated grid glow and sparse neon sparkle aura; no accessory geometry.

Tier: **Epic**. 4 maps; 0 added accessory triangles.

- [Packed Blender review](package/synthwave-arcade-v1.blend)
- [Procedural source](source/synthwave-arcade-v1-procedural.blend)
- [Complete static FBX](package/synthwave-arcade-v1-complete.fbx)
- [Front](preview/synthwave-arcade-v1-hero.png), [rear](preview/synthwave-arcade-v1-back.png), [concept](preview/synthwave-arcade-v1-concept.png)
- [Validation report](package/arcade-v1-asset-report.json)

Original six pig meshes and UVs are unchanged. All export meshes are closed and each is under 20,000 triangles. FBX reimports verified counts and bounds.
For animated assets play frames 1–145 at 24 fps (six seconds). FBX files are static import poses; the packed Blender file retains animation. The separate AURA collection is preview geometry and is excluded from exports.
Imported into the Arcade collection in Roblox Studio. All uploads are approved. Shared coats, accessory models, six auras and authored six-second animation loops are installed. See `../../arcade-build-v1/roblox-integration.json` for validation. Publishing the live place is separate.
Player One uses pixel-shaded texture artwork on the original smooth silhouette. It is not a 2D sprite or pixelated camera effect. Its revised authored coat qualifies as Rare; the original simple Common concept is superseded.

Rebuild: `blender -b --python assets/piggies/arcade-build-v1/build_arcade.py -- --skin synthwave`.
