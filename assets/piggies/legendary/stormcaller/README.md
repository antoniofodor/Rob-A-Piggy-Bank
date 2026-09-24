# Stormcaller — OG redesign v1

Storm-slate coat with sparse branching cyan lightning, navy snout and blue eyes. Two faceted cloud clusters and angular lightning forks bob beside the rear flanks. Small blue motes preview the storm aura.

**Tier: Legendary.** Substantial additional geometry, aura and visible movement.

- [Concept](preview/stormcaller-og-v1-concept.png), generated with built-in image_gen; exact prompt in `generate/og-v1-concept-prompt.txt`.
- [Actual model render](preview/stormcaller-og-v1-hero.png) and [rear](preview/stormcaller-og-v1-back.png).
- [Packed Blender review](package/stormcaller-og-v1.blend). Play frames 1–145 at 24 fps for the six-second loop on epics/legendaries.
- [Editable procedural source](source/stormcaller-og-v1-procedural.blend).
- [Complete FBX](package/stormcaller-og-v1-complete.fbx), with optional accessories-only FBX when this design has geometry.
- 4 1024 px maps in `sheets/`; all original pig geometry and UVs preserved.
- 696 added triangles; closed meshes and FBX round trips verified in `package/og-v1-asset-report.json`.

Blender -b --python assets/piggies/og-redesign-v1/build_og.py -- --skin stormcaller

The FBX is a static import pose. Animation and material pulses live in the packed Blender scene.
The AURA collection is a visual proxy for Roblox's `storm` emitter and is excluded from FBX exports.
Roblox upload and installation are pending. Do not stack the new geometry on the old shards/FX.
Use the existing shared pig meshes and replace their maps; the complete FBX is a standalone option.
Preserve the existing rarity, income, order and price. The concept is an art target; PNG model views show the delivered geometry and materials.
