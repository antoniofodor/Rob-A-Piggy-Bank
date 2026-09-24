## Legendary geometry revision v2

Rebuilt with layered navy shoulder guards, fitted steel shell panels, chunky three-piece boots, raised cyan vents, recessed turbine thrusters, navy ear rims and a clean pale face. Black eyes match the reference; the hardware supplies the glow.

6,068 added triangles across 81 parts. Uploaded and validated in Roblox Studio. The v1 files are retained.

- [V2 Blender](package/arcade-v2/mechaplayer-arcade-v2.blend)
- [V2 front](preview/arcade-v2/mechaplayer-v2-hero.png) / [rear](preview/arcade-v2/mechaplayer-v2-back.png)
- [Geometry report](package/arcade-v2/asset-report.json)

# Mecha Player — Arcade v1

Pale steel and navy robot pig with clean angular panel coat and tiny orange warning stripes. Substantial mechanical boot cuffs around existing legs, hinged flank guards and twin firmly mounted rear thrusters. Cyan illuminated vents pulse and small exhaust cones breathe at the rear; no flight pose. Preserve the original pig face and body, no helmet or weapons.

Tier: **Legendary**. 4 maps; 2360 added accessory triangles.

- [Packed Blender review](package/mechaplayer-arcade-v1.blend)
- [Procedural source](source/mechaplayer-arcade-v1-procedural.blend)
- [Complete static FBX](package/mechaplayer-arcade-v1-complete.fbx)
- [Front](preview/mechaplayer-arcade-v1-hero.png), [rear](preview/mechaplayer-arcade-v1-back.png), [concept](preview/mechaplayer-arcade-v1-concept.png)
- [Validation report](package/arcade-v1-asset-report.json)

Original six pig meshes and UVs are unchanged. All export meshes are closed and each is under 20,000 triangles. FBX reimports verified counts and bounds.
For animated assets play frames 1–145 at 24 fps (six seconds). FBX files are static import poses; the packed Blender file retains animation. The separate AURA collection is preview geometry and is excluded from exports.
Imported into the Arcade collection in Roblox Studio. All uploads are approved. Shared coats, accessory models, six auras and authored six-second animation loops are installed. See `../../arcade-build-v1/roblox-integration.json` for validation. Publishing the live place is separate.
Player One uses pixel-shaded texture artwork on the original smooth silhouette. It is not a 2D sprite or pixelated camera effect. Its revised authored coat qualifies as Rare; the original simple Common concept is superseded.

Rebuild: `blender -b --python assets/piggies/arcade-build-v1/build_arcade.py -- --skin mechaplayer`.
