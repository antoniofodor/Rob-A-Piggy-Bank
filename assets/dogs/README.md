# Blender guard dogs

Three independently authored, flat-shaded dog models for Scruffy (terrier),
Rex (shepherd), and Titan (mastiff). These are real editable meshes, not
generated concept images or Roblox primitive assemblies.

Open `dogs-lineup.blend` for the comparison scene, or a breed's `.blend` for
individual editing. `dogs-lineup.png` shows the actual models at their relative
sizes. Each breed directory includes its `.glb`, `.blend`, four rendered views,
and a measured `*-report.json`.

| Breed | Triangles | Shape |
|---|---:|---|
| Terrier / Scruffy | 4,666 | compact body, short legs, pointed and folded ears, cheek tufts, beard, upright tail |
| Shepherd / Rex | 4,584 | longer legs, pointed ears, projecting muzzle, dark saddle, bushy lowered tail |
| Mastiff / Titan | 5,020 | broad chest, heavy head, hanging ears, dark jowls, wide paws |

## Recoloring and articulation

Body, head, muzzle, ears, legs, paws, tail, collar and facial details remain
separate named objects. Each object uses a single flat material, with `tone`
and `group` metadata copied into the GLB node extras and the JSON report.
There are no baked coat textures or external image dependencies.

| Tone | Runtime meaning |
|---|---|
| `fur` | the breed or coat's `fur` color |
| `dark` | the breed or coat's `furDark` color |
| `collar` | the chosen collar color, including the tag |
| `eye` | fixed dark eyes, nose and mouth |
| `fixed` | small pale eye highlights; do not recolor as fur |

The shepherd's saddle is a separate region of its body surface, sharing exact
boundary vertices with the main fur region. It is not a raised accessory.
Those two surface pieces should move together. Limb and tail origins are at
their attachment joints; head details share the `head` group. The files have
no armature, skin weights or baked walk/sleep animations.

## Import contract

- One Blender unit corresponds to one intended Roblox stud. GLB is Y-up and
  the dogs face +Z. Geometry sits at ground level.
- These are **finished breed proportions**. Do not apply the existing
  `DOG_TIERS.scale` and `shape` deformation again; adapt the importer to use the
  authored dimensions. Collision/chase radii remain gameplay configuration.
- Every exported object is below the project's 10,000-triangle MeshPart budget.
  Exact per-object counts and whole-model dimensions are in each report.
- The future loader must map `dark` to `furDark`, retain fixed facial details,
  and keep parts aligned during group motion. GLB extras are metadata for the
  importer; Roblox is not assumed to turn them into attributes automatically.
- Current gameplay uses a separate hi-vis duty vest. Preserve that signal
  when adapting the runtime renderer; a cosmetic collar alone is insufficient.
- Keep the current code-built dogs as fallback if a breed mesh is unavailable.

## Status

Local Blender source and GLB exports only. The in-game dogs have not been
replaced, uploaded, or rebalanced. Mesh import, runtime part mapping, animation,
duty-vest fitting and in-game visual checks remain a separate integration step.

## Rebuild

From the repository root, with Blender installed:

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -t 4 --python blender/dogs/build_dogs.py
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -t 4 --python blender/dogs/render_lineup.py
python3 blender/dogs/validate_glb.py
```

Set `DOG_BREED=terrier`, `shepherd`, or `mastiff` to rebuild one breed;
`DOG_QUICK=1` renders only its three-quarter view. Blender requires macOS
graphics access here even in background mode. The small GLB exporter avoids
this installation's incompatible NumPy dependency in the standard glTF add-on.
Validation independently parses the GLB and checks buffer bounds, material
slots, joint origins, dimensions, triangle budgets, nondegenerate triangles,
unit normals, and winding.
