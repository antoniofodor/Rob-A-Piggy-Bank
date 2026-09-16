# Compact Blender oak

An editable 3D draft modeled against `../tree-oak-render-v2.png`, reduced in
response to the designer's concern that the reference tree would crowd the
lawn. This is authored Blender geometry, not automatic image-to-3D output.

## Files

- `oak.blend`: editable `Trunk` and `Canopy`, packed base-colour texture,
  packed reference image, camera and preview lights.
- `oak.glb`: only the two textured meshes, at a shared trunk-ground origin.
- `oak-basecolor.png`: one 256 × 256 palette texture. No PBR map uploads.
- `oak-three-quarter.png`, `oak-front.png`, `oak-side.png`, `oak-rear.png`:
  views rendered from the actual mesh.
- `oak-scale.png`: the tree beside a **5.5-stud block character scale guide**.
  The guide and preview ground are absent from the export.
- `oak-report.json`: triangle counts and measured mesh bounds/offsets.

## Measured size and budget

Intended size is **8.5 studs wide × 9.25 tall × 4.68 deep**. Blender units
represent intended studs; verify the Roblox importer's unit/scale setting.
The GLB is Y-up, with both mesh origins at the trunk's ground contact.
`Trunk` has **2,400 triangles** and `Canopy` has **6,400 triangles**;
each is below the project's 10,000-triangle limit.

The Studio importer reverses the mesh's X/Z relative to the GLB report.
Runtime offsets therefore come from the imported assembly, recorded in
`Config.ACORN_OAK_MESH`. At trunk position (-25, 16), measured clearance is
**4.37 studs** from the side fence line and **6.54 studs** from the front.
Both street-row orientations were checked in Studio. An invisible lower
trunk collider blocks movement; the broad visual branch mesh does not.
No acorns or basket are baked into the geometry.

## Status

Imported by the designer and integrated into the residential plot builder.
Uploaded references live in `Config.ACORN_OAK_MESH`; the previous generated
source remains a fallback. The builder removes the importer's grey tint by
using white so the baked palette reads correctly. Studio Edit checks loaded
the uploaded meshes, measured dimensions/grounding/clearances and tested trunk
raycasts. A full in-game visual and collision walk-through remains pending.

## Rebuild

From the project root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -t 4 --python blender/tree/build_oak.py
python3 blender/tree/validate_glb.py
```

Set `OAK_PREVIEW_ONLY=1` to render only the three-quarter preview.
Blender needs macOS graphics access even for background rendering. This
installation's bundled glTF add-on cannot import its NumPy binary on the
current macOS version, so `export_glb.py` writes a static glTF 2.0 file without
that dependency. Independent binary checks cover accessor ranges, normals,
triangle winding, UV palette ranges, embedded PNG contents and dimensions.
