# Cookies & Cream — rare skin, first art pass

Asset ID proposal: `cookiescream`. Based on the approved `cow` procedural coat.
Palette: base #FFEECD, ink #44271C, nose #A36C50, ear #E7B58D, pale #FFF7E4.

## Files

- `cookiescream-complete.blend`: assembled pig with packed colour and emissive masks, review lighting and camera.
- `cookiescream-complete.fbx`: six separated static meshes with embedded colour textures. Assign the supplied emissive masks explicitly in Studio; do not assume the FBX importer recreates Blender's emission graph.
- `cookiescream_body_color.png`, `cookiescream_trim_color.png`: opaque 1024×1024 colour sheets.
- `cookiescream_body_emissive.png`, `cookiescream_trim_emissive.png`: 1024×1024 grayscale glow masks; white marks the sparse highlights.
- Five review renders, including dim lighting, and `cookiescream-asset-report.json`.
- `blender/pig/skins/cookiescream/coat-spec.json`: palette, parent scene hash and preview glow strength.

## Import

Use Body's colour/mask pair on Body. Snout, Ears, Legs and Tail share the trim pair and UV atlas. Eyes are an optional separate mesh; omit them when the game creates its own eyes. Keep the existing coin-slot/vault frame and game-built functional parts.

The body is 12 studs wide. Full envelope is 12 × 17.076 × 13.974 studs; origin is the body centre. Blender faces -Y with Z up; FBX declares -Z forward with Y up. Total 20,670 triangles, largest mesh 7,152. FBX reimport kept mesh count, UV presence, triangles and bounds (error 0.000000477).

Assign emissive masks in Studio using SurfaceAppearance.EmissiveMaskContent. Start with white EmissiveTint and tune EmissiveStrength in the actual game lighting; Blender's 0.8 strength is a preview value, not a cross-renderer guarantee. Set strength to zero for a painted-only version. This is a static detail, with no pulsing, animated colour or added geometry.

Roblox's current [emissive-mask documentation](https://create.roblox.com/docs/art/modeling/surface-appearance) supersedes the older repository note that SurfaceAppearance lacks an emissive channel. Mask assignment is an editor/import step.

Prefer the shared game meshes over uploading another duplicate pig. The crate catalogue, rarity weights and economy were not modified. These seven art proposals are not a decision to put all seven into the live crate. No uploads or Studio installation were performed; Studio material, scale and mobile review remain pending.

## Rebuild

In Blender, run `blender/pig/make/build_rare_coat.py -- --skin cookiescream`, then `make/bake_skin.py -- --skin cookiescream`, then `make/package_animal.py -- --skin cookiescream --name "Cookies & Cream"`. The durable palette definitions are in `blender/pig/rare_coats.py`; the builder reuses the parent graph without saving the parent. Run `build_rare_gallery.py` after rebuilding packages.
