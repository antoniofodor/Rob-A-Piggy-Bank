# Honeycomb â€” hexagonal cell revision

The current skin uses a honeycomb field with amber cell interiors and golden
wax rims, replacing the irregular giraffe patches. The spherical mapping
keeps the cells readable over the crown and underside; twelve pentagonal
junctions allow the otherwise hexagonal grid to close around the curved body.
There are no highlight dots or emissive effects.

The current closed-back body, snout, ears, legs, and their UVs are preserved.
The tail is solid honey-orange, with a separate translucent light-amber honey droplet and curved reflective streak at its tip.
Its geometry is skin-specific and requires the revised Tail mesh for that detail.
`source/coat-spec.json` records the geometry/UV checks for both source scenes.

## Files

- `honeycomb-complete.blend`: assembled review model with packed textures.
- `honeycomb-complete.fbx`: eight static meshes, colour textures embedded.
- `honeycomb-tail.fbx`: orange curl, translucent droplet, and reflective streak as three separate meshes, with its colour texture embedded.
- `honeycomb-tail-detail.png`: close-up of the orange curl and honey droplet.
- `honeycomb_body_color.png`, `honeycomb_trim_color.png`: current 1024 Ã— 1024 colour sheets, also in `../sheets/`.
- `honeycomb-hero.png`, `honeycomb-front.png`, `honeycomb-crown.png`, `honeycomb-spine.png`: current review renders.
- `honeycomb-asset-report.json`: geometry, UV, texture and FBX round-trip checks.

Older `*_emissive.png` and `honeycomb-glow.png` files are historical only;
the current package does not reference them. Do not assign them to the new skin.

## Import

Use the body colour sheet on the existing Body mesh and the trim colour sheet
on Snout, Ears, Legs and Tail. Existing Roblox texture IDs still reference the
previous pattern: both colour sheets need uploading. No runtime IDs changed.
The body, snout, ears, and legs can keep their shared meshes. Import
`honeycomb-tail.fbx` as a skin-specific Tail to show the new droplet; the
existing shared tail has no droplet geometry. The complete FBX is also available. Body width is 12 studs, with eight meshes (triangle counts are in the asset report).

The droplet uses a separate glass material: light amber (255, 199, 88),
transmission 0.78, alpha 0.78, roughness 0.12, IOR 1.47 in Blender. Preserve
the separate droplet and highlight materials when importing; configure the
droplet transparency in Roblox, since FBX does not reproduce Blender glass
identically. The supplied Blender file shows the intended appearance.

## Rebuild

Run these scripts with Blender in background mode from the repository root:

1. `assets/piggies/rare/honeycomb/generate/make_honeycomb_blend.py`
2. `blender/pig/make/bake_skin.py -- --skin honeycomb`
3. `blender/pig/make/package_animal.py -- --skin honeycomb --name Honeycomb --blend <absolute path to source/honeycomb_closed.blend>`

4. `assets/piggies/rare/honeycomb/generate/render_tail_preview.py`

The pattern is authored in `../generate/honeycomb_pattern.py` and is also used
by the shared rare-coat builder. Roblox upload and in-game review are pending.
