# Rare animal skins — first art pass

[Review all seven](index.html): Strawberry Cow, Cookies & Cream, Watermelon, Peppermint, Glacier, Bubblegum Leopard, Honeycomb.

Each package contains a six-mesh Blender scene, FBX, two opaque 1024px colour sheets, two separate emissive masks, five renders and an import handoff. All use the existing pig geometry/UVs; total 20,670 triangles, with a 12-stud-wide body. The common skins and shared master remain untouched.

The new coats follow the sweets/fruit/weather list in docs/animal-crate-plan.md. The newer MASTER-PLAN.md Art 10 brief adds a small glow detail to rare skins, implemented here as sparse static highlights with separate masks. No animated colour, fur or extra geometry is added. Turn emission strength off for a painted-only presentation.

Roblox now supports emissive masks on SurfaceAppearance, contrary to the older repository notes. See [official PBR documentation](https://create.roblox.com/docs/art/modeling/surface-appearance). Set up masks in the editor/import pipeline; tune strength in Studio, since the Blender preview is not a brightness guarantee.

The seven designs are review assets, not a change to the crate pool. The older proposed ladder only called for four rares; final selection, runtime IDs, uploads, Studio material/scale checks and mobile review remain pending. No rarity weights, economy or ownership data were changed.

Durable sources: blender/pig/rare_coats.py and blender/pig/make/build_rare_coat.py. Each skin folder also has a make_<id>_blend.py entry point. Regenerate colour maps with bake_skin.py, packages with package_animal.py --skin <id> --name <name>, and this gallery with build_rare_gallery.py.
