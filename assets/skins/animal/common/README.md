# Eight complete animal piggy assets

[Open the gallery](index.html).

Bumblebee, Ladybird, Dairy Cow, Zebra, Giraffe, Leopard, Bengal Tiger and Snow Leopard are packaged under assets/skins/animal/common/<skin>/. Each includes a complete six-mesh Blender scene and FBX, the unchanged body/trim textures, four rendered views and a measured handoff. These are the existing animal designs; no new coats/species were invented.

All 16 source coat sheets passed the existing check_fade.py hard-edge test (0.00% broad fades). Packaging verifies texture SHA-256, preserved source scenes/master, original vertices and UVs, per-mesh triangle limits, manifold source edges, and FBX mesh/triangle/bounds reimport. The uniform package is 20,670 triangles; the largest mesh is 7,152 triangles. Every body is 12 studs wide.

Visual review includes crown and spine views. Angular fragments in the spotted coats are inherited from their procedural patterns: a direct unbaked Leopard render reproduced them, including after smoothing its normals. They are not introduced by the FBX export. This packaging pass preserves the original maps exactly; refining those patterns would be a separate coat-design edit.

The shared game mesh remains the preferred runtime route: use two texture assignments per animal, rather than uploading eight copies of the same geometry. Complete FBXs are standalone assembled assets for review/import. Eyes are optional where the game supplies them; no duplicate nostril inserts, fur sets, vault plate, coin pile or gameplay objects are included.

Neutral Blender previews are not Studio screenshots. Runtime material/scale/attachment checks and mobile/held-pig/shop review remain pending. Nothing was uploaded, installed or published. Source coat scenes, maps, shared master and Config were preserved.

Rebuild each package with blender/pig/make/package_animal.py -- --skin <id> inside Blender. Generate this gallery with build_animal_gallery.py. Use WORKFLOW.md only if the underlying coat needs rebuilding.
