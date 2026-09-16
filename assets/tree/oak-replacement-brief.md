# Replace the yard oak from the approved image

Status: the designer requested Blender modeling and a smaller yard tree.
A compact editable draft and GLB now live in `blender/`, with actual mesh
views and a character-scale comparison. It is modeled against the reference,
not automatically reconstructed from the image. The designer imported the
compact oak and its assets are now configured for residential plots. Numeric
placement/collision checks pass; in-game visual review remains pending. The
previous source remains available as a fallback.

## Authoritative input

Use `tree-oak-render-v2.png` as the actual image input to reconstruction.
The existing `tree.rbxmx` is the rejected text-generated interpretation,
not the target geometry. Do not use the street oak as a shape reference.

Preserve the image's broad irregular crown, multiple distinct leafy lobes,
large exposed branching forks, thick angular sculpted trunk, compact flared
roots, faceted green foliage, and warm brown wood. No acorns, basket, ground,
or hanging decorations in the mesh. Build a complete three-dimensional tree,
including plausible side and rear surfaces; not a flat cutout or relief.

## Preparation for Roblox

- Export editable textured geometry, preferably GLB, and retain the source.
- Separate all wood into `Trunk` and all foliage into `Canopy` for shaking.
- Keep each MeshPart below this project's 10,000-triangle budget.
- The designer subsequently requested a smaller tree: target 8.5 studs of
  canopy width, scaled uniformly. Measure depth against plot fence clearance.
- Put the model origin at the trunk's ground contact.
- Keep acorns and basket separate so the game controls their visible counts.

## Acceptance before replacement

Render front, three-quarter, side, and rear views of the actual mesh. Compare
the front/three-quarter views directly with `tree-oak-render-v2.png`, paying
particular attention to silhouette and branching. Inspect beside the existing
street oak at the same displayed scale to confirm the approved shape is
recognizable. Check triangle counts, texture assignment, open space beneath
the canopy, and the yard footprint.

Only after these checks pass, update `Config.ACORN_OAK_MESH` and its measured
offsets, validate the two plot orientations, and inspect the actual yard tree
in Studio. Leave `Config.TREE_MESH` (street scenery) unchanged. Preserve the
old source as a fallback until the replacement is accepted.
