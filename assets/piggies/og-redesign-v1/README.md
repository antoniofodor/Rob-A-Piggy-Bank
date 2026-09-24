# OG Piggies — redesign v1

15 individual concepts and 15 Blender assets: six rares, six epics, three legendaries.

Open `index.html` for the concept/model comparison gallery. Each pig's files are under its tier/key folder.
`design-specs.json` records the designs and tier evidence. `concept-receipts.json` records the exact built-in image_gen prompts and source paths.

Current tier authority: the designer's 2026-09-21 amendment in CLAUDE.md and Config's animal-epic comment.
The older PIGGY-SKIN-MAP's aura-only epic definition is superseded.

- Rare: authored coat/material, with modest embedded unlit accents on Rockslide and Quartz.
- Epic: a distinct visible coat plus emissive detail, a gentle material animation and its named aura.
- Legendary: coat, glow, aura and substantial animated solar/prism/cloud geometry. Rear orbital sway keeps the face clear.

All original body/trim/eye geometry and UVs are preserved. Every export is reimported to verify geometry counts and bounds.
Each mesh is closed and below 20,000 triangles. Six-second animation loops close continuously; legendary face clearance is sampled at nine frames.
Color maps are baked from spatial procedural materials at 2048 and reduced to 1024. Glow and Verdigris material masks are separate.

Live Config, SurfacePacks, skin prices/rarities and published Roblox assets are unchanged.
Install only after uploading the relevant maps/accessory meshes and capturing their IDs. The FBXs carry static import poses; the Blender scenes retain animation.
Existing runtime color animation must not replace full-color coats. Drive emitted strength or selected overlay regions instead. Use existing aura emitters rather than importing preview motes.

Rebuild: `python assets/piggies/og-redesign-v1/build_batch.py --keys marble,rockslide,quartz,banker,tiedye,verdigris,ghost,charcoal,starlight,nightlight,sugarrush,hologram,supernova,prismatic,stormcaller`
Then run `python assets/piggies/og-redesign-v1/finalize_gallery.py`.
