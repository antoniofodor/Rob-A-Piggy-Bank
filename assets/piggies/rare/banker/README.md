# Banker Piggy — OG redesign v1

Tailored coat painted on the pig: deep navy body with fine ivory longitudinal pinstripes, ivory shirt bib and sharp navy lapel edges framing a muted gold tie, warm pink snout and ear interiors, navy cuff feet. Tailoring is surface artwork. Preserve pig silhouette. No hat, glasses, briefcase or other accessories. No glow or particles.

**Tier: Rare.** Distinct authored coat/material; limited non-glowing embedded rock/quartz accents.

- [Concept](preview/banker-og-v1-concept.png), generated with built-in image_gen; exact prompt in `generate/og-v1-concept-prompt.txt`.
- [Actual model render](preview/banker-og-v1-hero.png) and [rear](preview/banker-og-v1-back.png).
- [Packed Blender review](package/banker-og-v1.blend). Play frames 1–145 at 24 fps for the six-second loop on epics/legendaries.
- [Editable procedural source](source/banker-og-v1-procedural.blend).
- [Complete FBX](package/banker-og-v1-complete.fbx), with optional accessories-only FBX when this design has geometry.
- 2 1024 px maps in `sheets/`; all original pig geometry and UVs preserved.
- 0 added triangles; closed meshes and FBX round trips verified in `package/og-v1-asset-report.json`.

Blender -b --python assets/piggies/og-redesign-v1/build_og.py -- --skin banker

The FBX is a static import pose. Animation and material pulses live in the packed Blender scene.
The AURA collection is a visual proxy for Roblox's `none` emitter and is excluded from FBX exports.
Roblox upload and installation are pending. Do not stack the new geometry on the old shards/FX.
Use the existing shared pig meshes and replace their maps; the complete FBX is a standalone option.
Preserve the existing rarity, income, order and price. The concept is an art target; PNG model views show the delivered geometry and materials.
