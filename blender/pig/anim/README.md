# The pig's walk

Two things live here, built by one script, and only one of them ships.

```
make_walk.py     the SOURCE. Opens pig/pig_parts.blend read-only, scales the
                 five parts to studs with the feet on z = 0, rigs them, authors
                 one trot stride, bakes the body's curve, renders four frames
                 from two cameras, saves the .blend and exports the FBX.
walk_curve.lua   the BAKE: the body's lift / pitch / roll / yaw over one stride,
                 24 samples, already in Roblox axes. Pasted into
                 Config.PIGGY_WALK.frames; tests/luau/walk.luau holds Config to
                 it row by row. This is what the game plays TODAY.
pig_walk.blend   the rigged pig with the PigWalk action (gitignored like every
                 .blend here; re-run the script to get it back).
pig_walk.fbx     armature + five skinned meshes + the cycle, for a LATER import
                 through Roblox's 3D importer. Nothing here uploads anything.
```

```
blender.exe --background --python blender/pig/anim/make_walk.py
```

## What ships today, and why it is not the legs

A herd mini is `PiggyModel.build`: a `Body` MeshPart, ONE merged `Trim`
(ears, snout, legs and tail welded into a single mesh) and two `Eye`s. There
is no leg part to swing. And a MeshPart built at run time through
`CreateMeshPartAsync` does not deform under bones -- measured twice, recorded
in `CLAUDE.md` -- so the only route to real leg motion is an IMPORTED skinned
rig, which is a manual step under the developer's own account.

So `Shared/PiggyWalk` plays the baked BODY curve as a rigid whole-model
waddle about the feet, driven by the distance `HerdService` publishes. No
asset, no upload, works on the live site. The rig below is prepared so that
the day the import is worth doing, the walk it plays is the same one.

## The rig (what is in the FBX)

Bones, all rigid weights (every vertex 100% to one bone):

| bone | parent | drives |
|---|---|---|
| `root` | -- | the ground origin |
| `body` | root | `Body` mesh; points FORWARD (-Y in Blender), so local X = pitch, Y = roll, Z = yaw |
| `snout` | body | `Snout` |
| `ear.L`, `ear.R` | body | `Ears`, split by X sign |
| `tail` | body | `Tail` |
| `leg.FL`, `leg.FR`, `leg.BL`, `leg.BR` | body | `Legs`, split by X and Y sign; point down |

Units: 1 unit = 1 stud (the parts are scaled by `build_pig.py`'s 6.0 and
lifted so the feet stand on y = 0). Exported forward -Z / up Y, the same map
`build_pig.py`'s OBJ export uses.

One action, `PigWalk`, 24 fps, frames 1..25 with 25 == 1: a trot (diagonal
leg pairs swing together), the body bobbing twice a stride and swaying once,
ears flapping against the bob with a three-frame lag, tail wagging twice.

Verified by importing the FBX back into a clean Blender: 10 bones with the
parents above, five meshes each carrying its bone groups, one action with the
full range. That is the "fetch it back and diff it" rule from
`assets/animations/README.md`, applied before the upload rather than after.

## Manual import checklist (NOT done; do not do it casually)

Every upload is a publication under the developer's account and is moderated
-- `CLAUDE.md` records the `generate_material` ban. One FBX is one mesh set
plus one animation; do it once, look at it, and stop.

1. Studio, EDIT mode. **File -> Import 3D**, pick `blender/pig/anim/pig_walk.fbx`.
2. In the importer: **Rig type: Custom**, **Import animations: on**, scale unit
   **Studs**. Leave "Merge meshes" OFF -- the five parts must stay five
   MeshParts so `applySkin` can paint the trim separately from the body.
3. Import into the place. It arrives as a Model with `Bone` instances under
   the meshes and an `AnimationController`-ready rig, plus an `AnimSaves`/
   animation clip named `PigWalk`.
4. **Check the facing by PHOTOGRAPH.** The OBJ pipeline found the importer
   mirrors Z (`Config.PIGGY_MESH` carries a half turn for it). If the snout
   is at -Z, the fix is a half turn on the root, not a re-export.
5. Publish the animation clip **from the Explorer** (right-click, Save to
   Roblox), never through a rig in the Clip Editor -- that attaches
   `AnimationRigData` and Roblox retargets through it (the ride poses were
   all republished for exactly this). Put the id in `Config.ANIMATIONS`
   under a new `herdWalk` key.
6. Keep the imported rig model as a TEMPLATE in ReplicatedStorage (this is
   the one thing a run-time `CreateMeshPartAsync` cannot do). Fetch the
   animation back with `GetKeyframeSequenceAsync` and diff it against what
   Blender exported, and check for no rig data.
7. Delete anything staged in `workspace`. The `GearPreview` trap.

## Run-time work the import still needs (not written)

* `HerdService.buildMember` would clone the rig template instead of calling
  `PiggyModel.build`, then paint it with the skin (`Body` colour, `Trim`
  colour onto the four trim parts).
* Each client would load `Config.animationId("herdWalk")` on the member's
  `Animator`, play it at speed 0, and write `track.TimePosition = phase *
  track.Length` from the same `Walked` attribute `PiggyWalk` already reads --
  so the skeletal walk stays DISTANCE-driven, never a clock, and the rigid
  waddle in `PiggyWalk` becomes the fallback for a mini with no rig.
* The pick-up prompt, `PiggyModel.bodyOf` and every `Body`-named coupling
  keep working if the imported body mesh is named `Body`.
