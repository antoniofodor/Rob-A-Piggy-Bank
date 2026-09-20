# Rainbow Tiger — option C, swept charcoal

Built from the approved [option C concept](../../../../../assets/skins/animal/legendary/rainbow-tiger-concept/concept-v5-c-swept-charcoal.png), with the latest adjustments:

- Upper cheek strands rebuilt to follow the face downward in curved layers.
- Inner-ear locks share roots at the actual medial corner nearest the forehead,
  then fan upward/outward while resting against the inner-ear surface.
  Ear tuft roots are fuller, with a gradual taper along each strand to a fine tip.
  Four broad overlapping tufts now span each inner ear from the upper tip to
  the lower outer corner, following the reference's full fan of hair.
- Banana-shaped cheek/beard locks are thickest through the middle and taper
  softly at both ends. Single C-curves and double-bending S-curves overlap down
  the face, with long lower locks converging at the chin. Narrow roots tuck
  under adjacent fuller middles, keeping the ruff dense.
- The latest softness pass relaxes the sharp hooks, smooths the width change
  through each bend, and uses closely spaced end sections for rounded swept tips.
- The facial ruff starts around eye level. Smooth sections avoid twisting in
  tight bends, and fine strand shading replaces the previous coarse grooves.
- Soft small eyebrow arches; fully visible RGB eyes.
- One inner and one outer face stripe per eye, spaced clear of the eyes.
- Clean painted stripe bands with broad centers and sharp tapered ends,
  continuing around the back. Raised stripe shells have been removed.
- Bare pig feet, original body/snout/bank openings, compact rainbow tail plume.

[Model gallery](index.html) · [Actual animation](rainbowtiger-idle.gif) · [Ear close-up](rainbowtiger-ear-detail.png)

## Import files

**`rainbowtiger-complete.fbx` is the main model.** `rainbowtiger-idle.fbx`
contains its matching four-second bone animation. The editable source is
`rainbowtiger-complete.blend`; all review images show this actual model.

Body is 12 studs wide. Preserve uniform scale and align the original body center,
snout and rear vault axis. Visual parts should be non-colliding in the game.
The previous `legendary-v1` and `clean-review-v2` packages remain preserved.

## Textures

The color images are embedded in the FBX and included separately:

- `rainbowtiger-coat.png`: Body, with a dedicated seam-wrapped coat UV layout.
- `rainbowtiger-stripe-emission.png`: Body stripe-only glow mask, supplied separately
  for runtime setup; black pixels leave the coat dark.
- `rainbowtiger-charcoal-fur.png`: CheekFur_-1, CheekFur_1, EarFur and BeardFur.
  The old separate beard texture is no longer assigned to the model.
- `rainbowtiger-tail-gradient.png`: TailPlume.

Preserve their UVs. If the importer drops a color image, reapply it as the mesh's
color map/SurfaceAppearance and keep the part tint white. The texture supplies
dark roots, lighter tips and subtle strand shading; flat gray would lose this.
Body must also retain a white part tint so its coat image supplies the color.
Other parts use RGB colors recorded in `rainbowtiger-asset-report.json`.
Ears retain a second inner material RGB 67,62,77. Do not apply the old painted
Rainbow Tiger textures or add duplicate eyes/fur meshes.

## Animation / Fable handoff

The rig retains Root, Tail, Ruff_L and Ruff_R. Root is stationary; Tail sways
3 degrees and the compact cheek tufts sway 1.2 degrees. The beard follows Root.
Import and publish the
idle FBX on the model's rig. Source action is frames 1–121 at 30 fps; FBX import
may shift it to 2–122 while preserving the four-second period.

**FBX does not transfer Blender's material animation.** Recreate the gentle
brightness pulse through the Body material using `rainbowtiger-stripe-emission.png`
and the timing in `animation-handoff.json`. Only painted stripes emit; do not
apply a uniform glow to the black body. The Eyes mesh has its own synchronized smooth
four-second RGB cycle. Keep the underlying coat and fur color maps fixed. Tail uses a continuous
color texture and bone movement. No particle aura is intended.

Keep the original coin slot, coin-deposit effects and flush rear vault plate.
Confirm lock-tier seating, daylight glow, held/shop appearances and mobile
performance after Studio integration. No runtime/economy files were changed.

## Verification

13 meshes / 48,066 triangles; largest mesh
11,242 triangles. All meshes are closed
and manifold. FBX reimport preserves count, triangles, weights and bounds within
0.000000954 studs; fur/tail UVs and textures survive.
The imported idle loop is closed, the root stays still, and animated accessories
clear the rear-plate probe in 40 sampled states. The original master and old
painted Rainbow Tiger source and maps retain their hashes.

**Art built; Studio integration and live checks pending.** The approved concept
is the target; the new physical model is ready for visual review.

## Rebuild

Run `build_rainbowtiger_swept.py` in background Blender; then
`render_rainbowtiger_preview.py -- --swept` in Blender; then
`build_rainbowtiger_swept_gallery.py` in Python. `--draft` changes only render
resolution/samples, not the geometry or exports.
