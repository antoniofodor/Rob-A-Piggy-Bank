# Chunky guard creatures — Blender source and animation kit

Eight models authored from the approved low-poly dog, wild and elite concepts.
Current reference images are preserved in `concepts/`. The earlier, more sculpted
dog set remains separately in `assets/dogs/`; this is a new version.

Open [PREVIEW.md](PREVIEW.md) to compare all eight idle/chase renders. The
`dogs-lineup`, `wild-lineup` and `elite-lineup` files are native Blender
comparison scenes with corresponding PNG previews. The complete downloadable
archive is `guard-creatures-blender-pack.zip`.

| Folder | Guard | Proposed defense tier | Authored height |
|---|---|---:|---:|
| `terrier` | Scruffy | 1 | 2.50 |
| `shepherd` | Rex | 2 | 3.25 |
| `mastiff` | Titan | 3 | 4.05 |
| `direwolf` | Dire wolf | 4 | 4.30 |
| `gorilla` | Gorilla | 4 | 4.30 |
| `raptor` | Raptor | 4 | 4.30 |
| `triceratops` | Triceratops | 5 | 4.70 |
| `cerberus` | Cerberus (three heads) | 5 | 4.70 |

Sizes include ears/horns and use the same nominal Blender unit across the
roster. These are final relative sizes, not base meshes to apply the existing
DOG_TIERS scale and shape deformation to again. Verify the FBX importer scale
against the yard before adopting a stud conversion.

## Files in each folder

- `<guard>.blend`: editable mesh parts, a skinned armature, and three actions.
- `<guard>.fbx`: rig and geometry in their resting pose, without a baked clip.
- `<guard>.glb`: alternate rigged geometry export, without animation clips.
- `<guard>_Idle.fbx`, `_Chase.fbx`, `_Attack.fbx`: exactly one baked clip each.
- `<guard>-idle.png`, `-chase.png`: renders of the actual Blender geometry.
- `<guard>-report.json`: part names, tint roles, bones, triangle counts and sizes.

The three motions are **starter animation blockouts**, not finished or
gameplay-tuned cycles. Idle breathes and wags; Chase demonstrates alternating
limbs and a moving open jaw; Attack demonstrates an in-place lunge and bite.
They use forward kinematics and rigid weights to preserve the angular look.
Foot contact, stride length, attack timing, sleeping and species-specific
behavior should be refined before shipping.

## Rig and face

Each vertex has exactly one bone influence. Root is at the origin and has no
weighted geometry. Body, Head, Jaw, limb joints, tail, ears and brows are named.
Each anatomical part remains a separate mesh and uses one flat material,
allowing basic coat colors to change without repainting textures. The gorilla
uses a separate `mask` tone for their flatter facial skin. Cerberus has `Head`,
`Head_Left`, `Head_Right` and matching `Jaw` bones, with six separate eyes.

The native preview switches eye and brow materials for the hostile render.
**Material colors are not skeletal animation data:** the FBX clips animate
the jaw, brows, body and limbs, but Roblox must switch the eye color/material
when its authoritative guard state changes. Returning to idle restores the
normal eye and brow colors. A skin must not override hostile red eyes.

`tone` and `bone` custom properties are authoring metadata. Do not assume the
Roblox importer automatically converts these into usable attributes; use the
report's part-name map when adapting the model loader.

## Add and edit animations

Read [ANIMATION-GUIDE.md](ANIMATION-GUIDE.md) for the Blender editing and
Roblox import workflow. No animation IDs are required to inspect the Blender
actions locally. Publishing in Roblox is a separate step.

## Scope and validation

Integrated in the local project and Studio on 2026-09-16. Imported mesh IDs
are captured in `studio-imports.json`; reproducible templates live under
`src/ServerStorage/GuardTemplates`. `GuardVisual` rebuilds the rigid skeleton
from report metadata because the importer attached face/foot pieces to Root.
`GuardDog` now uses these meshes instead of the retired primitive dog geometry.

Progression is Terrier → Shepherd → Mastiff → Dire Wolf → Cerberus.
Gorilla/Raptor are tier-4 wardrobe variants; Triceratops is tier 5. Their
wardrobe cards enforce the matching tier and confer no stat advantage.
Existing coat colors, names, kennel skins, toys, bait and guard duty remain.

Runtime motion is currently procedural (`GuardAnimation` + `GuardAnimator`),
including chase/attack jaws and state-driven red eyes. Published animation
clips are optional future polish, not a dependency of this integration.
This change has been tested in Studio Play; it has not been published to Roblox.
The Studio screenshot tool timed out, so visual verification was limited to
live client transforms/materials, bone attachments, bounds and facing.
 Cerberus replaces the armored hellhound at Tier 5.
The old hellhound is retained in `assets/retired-guards/hellhound/` for recovery
and is excluded from the active roster and downloadable pack. Silverback was
also removed as redundant with Gorilla and retained only in `assets/retired-guards/`. The superseded
elite concept sheet is archived in `assets/retired-guards/concepts/`; the
current Blender previews show Cerberus.
T. rex, baby dragon and alternate dog breeds have not been modeled in this batch.

`validation.json` records the FBX roundtrip checks: geometry and height,
bone names, rigid skinning, one clip per animation file, observable skinned
movement, and matching first/last poses for loops. GLB skins are checked too.
Passing these checks does not replace a Roblox Studio import/playtest.

Integration still needs the existing duty vest signal, a model loader,
animation IDs, state transitions, collision tuning, skin mapping, and yard
scale/performance checks. Non-canine behavior and later defense tiers are
design proposals, not implemented game rules.

## Rebuild

From the repository root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -t 4 --python blender/guards/build_guards.py
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -t 4 --python blender/guards/validate_guards.py
```

Use `GUARD_ONLY=terrier,gorilla` to limit either command to a subset, and
`GUARD_RENDER=0` to skip preview renders. Rebuilding overwrites generated files;
save hand-edited scenes under a separate filename first.

This Mac's bundled Blender NumPy requires a newer macOS version. An isolated
compatible NumPy 2.2.6 wheel was installed in `/tmp/guard-blender-python`, without
altering Blender itself. Set `GUARD_PYTHON_DEPS` to a compatible package folder
when rebuilding on this machine. Other working Blender installations can use
their bundled dependency normally. The delivered .blend and FBX files do not
depend on that temporary folder for viewing or animation editing.
