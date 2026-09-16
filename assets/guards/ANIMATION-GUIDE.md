# Animate the guard creatures

**Current runtime (2026-09-16):** the imported guards are wired in.
`GuardAnimation.luau` and `GuardAnimator.client.luau` provide procedural starter
motion and hostile expressions with no animation IDs required. `GuardVisual`
repairs the import into named Motor6D joints with the facial pieces welded to
the correct head/jaw. The Blender clip workflow below is for future authored
animation polish; test/retarget clips against this repaired rig before replacing
the procedural animator. Do not run two animators on the same joints.


The models already have simple skinned rigs and editable Idle, Chase and Attack
actions. There is no need to rig them from scratch. These are custom creature
rigs, not R15 player avatars.

## In Blender

1. Open a guard's `.blend`, select `<guard>_Rig`, and enter Pose Mode.
2. Open the Animation workspace. In the Dope Sheet, switch to Action Editor.
   Select `<guard>_Idle`, `<guard>_Chase`, or `<guard>_Attack`. The actions have
   fake users so they remain saved even when another action is active.
3. Keep the scene at 30 fps. Idle spans frames 1–61 (2 seconds); Chase and
   Attack span 1–25 (0.8 seconds). Set the playback end to match the chosen clip.
4. Move the timeline, rotate the bones, and insert Location & Rotation keys.
   Start with Body and Head, then legs, then Jaw and brows. The rig uses FK:
   each limb joint is posed directly; there are no hidden IK controllers.
5. Jaw opens around the model's world X axis. For this deliberately rigid style,
   keep the jaw and head as separate pieces rather than smoothing the muzzle.
6. For a loop, make the final pose equal the first pose. Preview the full motion
   from front and side to catch sliding feet and intersecting limbs.
7. Save an edited copy. Use the export script below or File → Export → FBX.

Suggested next clips: Walk, Sleep, Wake, Alert, Chase, Attack and ReturnToIdle.
Dogs can share an animation approach, but the raptor and gorilla should get
their own footwork. Triceratops should charge with its horns rather than bite.

### Export edited clips

From the repository root, this exports the tagged actions from your edited
scene into a sibling `edited-exports` folder without rebuilding the model:

```sh
/Applications/Blender.app/Contents/MacOS/Blender assets/guards/terrier/terrier.blend -b --python blender/guards/export_current.py
```

Change the scene path to your edited file. New actions should carry a `clip`
custom property such as `Walk` and a name beginning with the creature key
(`terrier_Walk`), or use manual FBX export instead.

For manual export, select the rig and its mesh children, export Selected
Objects, disable Add Leaf Bones, and choose FBX Unit Scale. For animation,
enable Bake Animation, disable All Actions and NLA Strips, and set Simplify to
0. Export one clip per file, using its own timeline range. The supplied FBXs
already follow the one-clip-per-file approach.

## In Roblox Studio

1. Use Studio's 3D Importer to import `<guard>.fbx`. Keep its custom skeleton;
   do not convert this creature to a player-avatar rig. Check orientation,
   scale, colors, part names and bones in the import preview.
2. For a non-Humanoid guard, use an `AnimationController` with an `Animator`
   child. Create the Animator on the server for a shared NPC. Keep movement
   and collision controlled by the game's guard system.
3. Open Animation Editor on the imported rig. Use its menu → Import → From
   File (called From FBX Animation in some versions) and choose the matching
   `<guard>_Idle.fbx`. Repeat for Chase and Attack. Import each clip onto the
   exact rig it was exported for.
4. Set Idle to loop at Idle priority, Chase to loop at Movement priority, and
   Attack to play once at Action priority. Inspect foot contact and jaw motion
   on the imported model before publishing.
5. Publish each animation to Roblox. Choose the same owner/group as the game,
   then copy the animation IDs into the future guard animation configuration.
6. Load each animation with `Animator:LoadAnimation()` and crossfade tracks
   when the guard changes state. Publish/save permissions and final import
   behavior must be verified in the target experience.

## Cute idle → threatening chase

Use the guard state to coordinate two separate things:

| State | Skeletal motion | Material change |
|---|---|---|
| Idle | Quiet body/head movement, closed jaw, neutral brows | Restore normal eye and brow colors |
| Alert | Look toward the intruder, lower brows | Eyes turn red |
| Chase | Running cycle, moving open jaw, angry brows | Keep red eyes; optionally Neon material |
| Attack | Brief species-specific bite, swipe or charge | Keep red eyes |
| Return | Blend back to the relaxed pose | Restore normal eyes |

Cerberus has three independent head/jaw chains: `Head` / `Jaw`,
`Head_Left` / `Jaw_Left`, and `Head_Right` / `Jaw_Right`. Animate each jaw
separately; the included chase clip staggers their opening. Its extra eye and
brow part names carry `_Left` or `_Right` suffixes. Apply hostile colors to
all six eyes, using the part report's `eye` tone mapping.

The exported clips do not animate material colors. On the model's `Eye_L`
and `Eye_R` MeshParts, set `Color` to red during hostility and restore the
saved original color afterward. If the importer renames or merges parts,
establish the name mapping first. Preserve separate eye geometry when importing.
Use similarly mapped brow parts for the optional darker hostile brow color.

The runtime should decide hostility from the existing authoritative guard
state, not from the frame currently playing. Animation events can trigger bark
sounds or visual bite effects; catching/damaging a player must still use the
server's gameplay checks. These starter animations do not add combat rules.

Basic coat skins should recolor only the fur/dark/light material roles while
preserving eyes, mouth and teeth. Keep the defense tier's size and silhouette.
The current game also has a duty-vest indicator; include it when integrating
the replacement models.

## Official references

- [Roblox export settings](https://create.roblox.com/docs/art/modeling/export-requirements)
- [General model, rig and animation specifications](https://create.roblox.com/docs/art/modeling/specifications)
- [Animation Editor](https://create.roblox.com/docs/animation/editor)
- [Animation use, including non-Humanoid rigs](https://create.roblox.com/docs/animation/using)

These instructions were checked against the current official documentation.
The files have been validated through Blender FBX roundtrips; target-place
Studio imports and gameplay integration passed the guard regression fixture in
`tests/studio/guards.luau`. Animation-clip publishing and final visual polish
remain separate; no live-place publish was performed.
