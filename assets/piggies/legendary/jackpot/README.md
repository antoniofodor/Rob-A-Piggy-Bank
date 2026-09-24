## Legendary geometry revision v2

A fuller arched reel housing with side lamps, raised gold rails, rivets, a rear shield and a fitted saddle. The original three reels and floating tokens retain their animation.

5,396 added triangles across 75 parts. Uploaded and validated in Roblox Studio. The v1 files are retained.

- [V2 Blender](package/arcade-v2/jackpot-arcade-v2.blend)
- [V2 front](preview/arcade-v2/jackpot-v2-hero.png) / [rear](preview/arcade-v2/jackpot-v2-back.png)
- [Geometry report](package/arcade-v2/asset-report.json)

# Jackpot — Arcade v1

Burgundy pig with gold star and diamond markings, ivory snout and brass feet. A firmly seated rear saddle carries three rotating symbol reels in a lit brass housing. Gold tokens move beside the rear flanks. New aura specification, not an installed runtime emitter.

Tier: **Legendary**. 7 maps; 3600 added accessory triangles.

- [Packed Blender review](package/jackpot-arcade-v1.blend)
- [Procedural source](source/jackpot-arcade-v1-procedural.blend)
- [Complete static FBX](package/jackpot-arcade-v1-complete.fbx)
- [Front](preview/jackpot-arcade-v1-hero.png), [rear](preview/jackpot-arcade-v1-back.png), [concept](preview/jackpot-arcade-v1-concept.png)
- [Validation report](package/arcade-v1-asset-report.json)

Original six pig meshes and UVs are unchanged. All export meshes are closed and each is under 20,000 triangles. FBX reimports verified counts and bounds.
For animated assets play frames 1–145 at 24 fps (six seconds). FBX files are static import poses; the packed Blender file retains animation. The separate AURA collection is preview geometry and is excluded from exports.
Imported into the Arcade collection in Roblox Studio. All uploads are approved. Shared coats, accessory models, six auras and authored six-second animation loops are installed. See `../../arcade-build-v1/roblox-integration.json` for validation. Publishing the live place is separate.
Player One uses pixel-shaded texture artwork on the original smooth silhouette. It is not a 2D sprite or pixelated camera effect. Its revised authored coat qualifies as Rare; the original simple Common concept is superseded.

Rebuild: `blender -b --python assets/piggies/arcade-build-v1/build_arcade.py -- --skin jackpot`.
