# Dragon — raised-scale legendary revision

An ember dragon built on the existing round piggy layout: 458
actual green scale plates, curved ivory horns, compact scalloped wings and a
fin on the original curled tail. The scales have shallow beveled edges and
rise 0.12–0.168 studs above the skin. They cover the body, outer ears, legs and
tail, including the forehead, crown and belly. The old gold belly and horizontal
glow bands are removed. Narrow warm seams follow the new scales across the
coat and brighten together in a breathing cycle. The smooth snout, inner ears,
opening seats and cavity remain non-emissive. Original pig body, ears, feet,
snout silhouette, flush rear vault opening and crown coin slot are retained.
The snout uses one green color, including its recessed nostrils.

The four-second idle lifts the wings by five degrees and sways the tail by
three degrees. Warm seams and wing/tail accents brighten in a slow breathing
cycle; the green plates retain their colors. The base body never moves.

## Files

- `dragon-complete.blend`: editable scene in studs, packed maps, four-bone
  rig, review lighting, bone motion and animated material emission.
- `dragon-complete.fbx`: the main rigged model in its neutral pose.
- `dragon-idle.fbx`: matching four-second bone animation. Import onto the
  main model's rig, not as a second display model.
- `dragon-idle.gif`: actual model animation, 40 frames at 10 fps.
- `dragon_body_color.png` / `dragon_trim_color.png`: opaque 1024px green
  undercoat and warm seam maps. Trim covers Snout, Ears, Legs and Tail.
- `dragon_body_emissive.png` / `dragon_trim_emissive.png`: grayscale masks
  projected from the actual raised scale borders, selecting only their warm
  seams. Do not assign these as transparency maps or use the old banded maps.
- `DragonGlow.luau`: optional client material playback companion.
- `dragon-asset-report.json`, `animation-handoff.json`, `animation-checks.json`:
  exact colors, bones, timing, file hashes, geometry and export checks.
- Four model views, a scale close-up and `index.html` for review.

## Studio import

Import the main FBX with its rig intact. Body is **12 studs across**; normalize
the entire imported model uniformly if Studio adds an importer multiplier.
Blender is X across, -Y forward, Z up; FBX declares -Z forward and Y up.
Preserve Root, Tail, Wing_L and Wing_R bones and weights. Accessories share
meshes by material and bone. Flat colors are recorded per mesh in the report.
Keep all `Dragon_Root_Scale*` and `Dragon_Tail_Scale*` meshes: these are the
real beveled plates. Apply their recorded flat green materials, not the body
texture. Tail scales share the Tail bone so they move with its original mesh.

Apply the body maps to Body and the trim maps to Snout, Ears, Legs and Tail,
using each object's preserved UVs. Use the emissive maps as each prepared
SurfaceAppearance's EmissiveMaskContent, with white EmissiveTint. Add boolean
attribute `DragonGlow = true` to those prepared SurfaceAppearances only.
Black areas of each mask stay non-emissive. The small Eyes use flat dark brown
(RGB 36, 24, 16).

Import the idle FBX into Roblox's Animation Editor on this rig, publish under
the experience owner and play the animation through an Animator, looping.
The Blender material animation does not transfer through FBX. Install
`DragonGlow.luau` as a ModuleScript and call
`local stop = require(module).start(dragonModel)` from the client cosmetic
controller when starting the idle animation. Call `stop()` when changing skins;
model destruction also cleans up. An optional phase offset in seconds lets the
controller match an already-playing idle. The helper pulses prepared masked
SurfaceAppearances from 0.35 to 2.2 and applies a warm Neon pulse to the three
named `Dragon_*_Ember` meshes. Tune bloom/strength in the game's lighting.

Keep game-owned deposit effects, coins, collisions and the rear vault plate.
Seat the plate against the existing flush opening and check every lock tier.
Do not add another collar, duplicate eyes or replace the shared pig master.
Validate held/shop views, daylight glow and mobile performance after import.

## Verification and status

24 meshes / 40,512 triangles; largest mesh
8,172 triangles. All meshes are manifold.
Static FBX preserves mesh count, triangle count, weights and bounds
(maximum error 0.000000954 studs). Animated FBX preserves
four bones, actual wing/tail movement, stationary Root and a closed loop.
The moving accessories clear the coin slot and largest rear dial plate over
40 sampled animation states. Source scene, original maps and shared master
hashes are unchanged. All four delivered maps have verified hashes.

**Raised-scale art revision for review; not installed or uploaded to Roblox.**
No runtime, crate catalogue or economy files changed. Live integration and
in-game material calibration remain pending.

## Rebuild

Run `blender/pig/make/build_dragon_legendary.py` in Blender, followed by
`render_dragon_preview.py` in Blender and `build_dragon_gallery.py` in Python
with Pillow. The model builder's `--draft` flag lowers still-render quality.
It always rebuilds a separate package and never saves into original sources.
`dragon_raised_scales.py` partitions the original surface into closed beveled
plates, then projects their borders to matching seam maps. Temporary baking
ribbons are removed before export. Colors vary per plate without belly bands.
