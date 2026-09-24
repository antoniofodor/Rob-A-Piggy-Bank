## Legendary geometry revision v2

Broad brass-edged pauldrons, large pink energy gems, fitted plum shell plates with raised luminous seams, armored hips and mounted rear crystals. Black eyes and exposed pink face match the reference.

2,748 added triangles across 45 parts. Uploaded and validated in Roblox Studio. The v1 files are retained.

- [V2 Blender](package/arcade-v2/finalboss-arcade-v2.blend)
- [V2 front](preview/arcade-v2/finalboss-v2-hero.png) / [rear](preview/arcade-v2/finalboss-v2-back.png)
- [Geometry report](package/arcade-v2/asset-report.json)

# Final Boss — Arcade v1

Pink-faced pig in a plum panel coat, with substantial brass-edged violet guards, pink energy jewels and visible hinge joints. Four guards slowly flex; six rear energy blocks bob. Pig face, feet and ears remain exposed. No weapons or crown.

Tier: **Legendary**. 4 maps; 1080 added accessory triangles.

- [Packed Blender review](package/finalboss-arcade-v1.blend)
- [Procedural source](source/finalboss-arcade-v1-procedural.blend)
- [Complete static FBX](package/finalboss-arcade-v1-complete.fbx)
- [Front](preview/finalboss-arcade-v1-hero.png), [rear](preview/finalboss-arcade-v1-back.png), [concept](preview/finalboss-arcade-v1-concept.png)
- [Validation report](package/arcade-v1-asset-report.json)

Original six pig meshes and UVs are unchanged. All export meshes are closed and each is under 20,000 triangles. FBX reimports verified counts and bounds.
For animated assets play frames 1–145 at 24 fps (six seconds). FBX files are static import poses; the packed Blender file retains animation. The separate AURA collection is preview geometry and is excluded from exports.
Imported into the Arcade collection in Roblox Studio. All uploads are approved. Shared coats, accessory models, six auras and authored six-second animation loops are installed. See `../../arcade-build-v1/roblox-integration.json` for validation. Publishing the live place is separate.
Player One uses pixel-shaded texture artwork on the original smooth silhouette. It is not a 2D sprite or pixelated camera effect. Its revised authored coat qualifies as Rare; the original simple Common concept is superseded.

Rebuild: `blender -b --python assets/piggies/arcade-build-v1/build_arcade.py -- --skin finalboss`.
