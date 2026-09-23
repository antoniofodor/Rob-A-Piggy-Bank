# Ice Phoenix — legendary piggy

An ivory piggy with 495 closed, curved feathers in ice blue and indigo,
a seven-feather crown and a seven-feather tail fan. 120 smaller feathers
continue down all four legs, leaving a narrow pale hoof rim. Thin luminous
frost veins run along the feathers; mirrored branching frost markings frame
the face, with a six-ray forehead motif and a narrow upper snout flourish.
Body feathers now follow the skin's curvature, with their roots buried and
pinned to Root while their tips flex. Close-set coverts fill the back and
both sides of the snout. Only the functional coin slot and rear vault plate
clearance are reserved. Stronger cyan-white tips pulse from a material gain
of roughly 1.1 to 5.5; the vein and face masks stay restrained.
Veins and cyan-white feather tips shimmer in staggered groups while the
mantle, cheeks, crown and tail move gently in a four-second loop.
The vein pattern and color gradient are fixed; brightness
changes over time. Original pig body, snout, eyes, feet, ears and curled tail
are retained, with the tail above the flush rear vault opening. The crown
coin slot stays clear. This revision follows the user's selected and refined
Crystal Crown concept in `assets/piggies/legendary/phoenix/generate/concepts-v2/crystal-crown-refined.png`.

## Files

- `../../../../piggies/legendary/phoenix/package/phoenix-complete.blend`: editable scene, packed maps, nine-bone rig,
  material animation, review cameras and lighting.
- `../../../../piggies/legendary/phoenix/package/phoenix-complete.fbx`: main rigged model in its neutral pose.
- `../../../../piggies/legendary/phoenix/package/phoenix-idle.fbx`: matching four-second bone animation; import onto the
  main rig, not as another display model.
- `../../../../piggies/legendary/phoenix/package/phoenix_color.png`: opaque 2048 × 2048 atlas for every mesh, with 16 tiles.
- `../../../../piggies/legendary/phoenix/package/phoenix_emissive.png`: matching mask for frost veins, tips and face markings.
- `../../../../piggies/legendary/phoenix/package/PhoenixFrost.luau`: optional client companion for masked emission.
- `../../../../piggies/legendary/phoenix/package/phoenix-idle.gif`: actual 40-frame animation preview at 10 fps.
- Four full model views, a crystal detail view, `../../../../piggies/legendary/phoenix/package/index.html`, asset report,
  animation handoff and checks.

## Studio import

Import the main model with its rig intact. Body is 12 studs across; scale the
entire model uniformly if Studio adds an importer multiplier. Blender uses
X across, -Y forward, Z up; FBX declares -Z forward, Y up. Preserve all nine
bones and exact mesh names. Accessories are grouped by their controlling bone.

All exported meshes use the new `PhoenixPalette` UV map and the two supplied
atlases, including the eyes, snout and original body parts. Feather UVs now
vary across their width as well as their length; the face is projected into
its own tile. Reimport the complete model with these new UVs and atlases.
Do not apply the
old Phoenix textures or old pig UV maps. Assign the color atlas and assign
the grayscale mask as SurfaceAppearance EmissiveMaskContent, with white
EmissiveTint. Only after assigning the mask, add boolean attribute
`PhoenixFrostGlow = true` to the prepared SurfaceAppearances. Black areas
of the mask remain non-emissive. Do not use the mask as transparency.

Import the idle FBX through Animation Editor on the main rig, publish under
the experience owner, and play it looping through an Animator. FBX carries
bone motion, not the Blender material animation. Install `../../../../piggies/legendary/phoenix/package/PhoenixFrost.luau`
as a ModuleScript and call `local stop = require(module).start(phoenixModel)`
from the client cosmetic controller when starting the idle. The helper uses
the same four-second frost brightness curve and per-mesh phases as Blender.
An optional second argument offsets playback time in seconds. Call `stop()`
on skin changes; model destruction also cleans up and restores material values.
Preserve mesh names for phase lookup and preserve the blended Root/tip weights
so the feather bases remain attached. Tune glow strength in the game's lighting.
The older `assets/phoenix/PhoenixEffects.luau` targets a different rig and
must not be used with this package.

Keep game-owned deposit effects, collision behavior and the rear vault plate.
Use the verified runtime dial seat recorded in `../../../../piggies/legendary/phoenix/package/vault-fit-checks.json`:
Blender coordinates (0, 6.471867, -0.280617) studs, with normal
(0, 0.948537, -0.316667), at the package's 12-stud body width. Preserve the
existing 0.9-stud plate thickness and tier radii 1.55, 1.68, 1.82 and 1.95.
The smaller feathers intentionally tuck beneath the plate; keep them in the
model. They follow the body surface and are not a protruding mounting collar.
The bore and plate front remain unobstructed. Do not position the plate using
the body origin alone: its axis originates 1.88 studs above that origin.
Review held/shop views, daylight materials and mobile performance after import.

## Verification and status

22 meshes / 106,800 triangles; largest mesh
15,138 triangles. All meshes are manifold.
Static FBX reimport preserves mesh and triangle counts, weights, UV presence
and bounds (maximum error 0.000000954 studs). Animation
reimport preserves nine bones, actual accessory movement, a stationary Root,
and a closed loop. Added geometry clears the vault plate and coin slot;
moving geometry was checked at 40 animation states. Source/master and atlas
hashes are verified. The previous Phoenix files remain unchanged.

The fitted Iron and Gold previews reconstruct the runtime vault geometry in
Blender. All four tiers passed 128 radial samples with zero bare gap at the
plate edge. The latest clearance checks use the runtime's actual axis origin.

**Art approved with vault fit verified. Studio integration, uploads and in-game material
calibration remain pending.** No runtime, economy or crate catalogue edits.
The logical `phoenix` asset key is retained; the display name is Ice Phoenix.

## Rebuild

Run `blender/pig/make/build_phoenix_legendary.py` in Blender, then
`render_phoenix_legendary.py` in Blender and
`build_phoenix_legendary_gallery.py` in Python with Pillow.
Before the gallery, run `check_phoenix_vault_fit.py` in Blender to regenerate
the fitted previews and seam checks. `phoenix_vault_geometry.py` reads the
runtime dial constants directly to keep construction and clearance aligned.
`phoenix_crystal_atlas.py` authors the feather veins and facial frost markings
procedurally, without editing the approved concept raster. The builder's
`--draft` option lowers still-render quality. Outputs stay in this separate
package; original source scenes are never saved over.
