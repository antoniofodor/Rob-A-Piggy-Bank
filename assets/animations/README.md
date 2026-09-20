# Animations: published, and how to publish the next one

Every animation in this game is BUILT IN CODE and has to be UPLOADED ONCE.
`KeyframeSequenceProvider:RegisterKeyframeSequence` works in Studio and is
refused on a published server, so in Studio everything animates and on the live
site nothing does until the asset id is in `Config.ANIMATIONS`.

**All 25 keys are published and verified (2026-09-19).** 24 assets, because
`hoverboard` and `hoverdisc` build byte-identical sequences and share one --
fingerprinted rather than assumed. A deploy from here animates.

| Key | Asset |
|-----|-------|
| `carry` | 79570016471528 |
| `sneak` | 119872214981754 |
| `dodgeRoll` | 71201705776623 |
| `throw` | 132725569119573 |
| `cameraSnap` | 86047766880960 |
| `bmx` | 131630123456554 |
| `skateboard` | 106489618346887 |
| `scooter` | 91060847823812 |
| `scrambler` | 88284702487997 |
| `hoverboard` | 81177304371469 |
| `hoverdisc` | 81177304371469 (shared) |
| `bmx#trick` | 115187422325364 |
| `skateboard#trick` | 76464848919550 |
| `scooter#trick` | 136245225446042 |
| `scrambler#trick` | 108628917952260 |
| `bmx@onehand` | 113153820661210 |
| `bmx@onehand#trick` | 100683207984365 |
| `skateboard@cruise` | 106364029188444 |
| `skateboard@cruise#trick` | 76199958795343 |
| `scooter@nohands` | 72285864748711 |
| `scooter@nohands#trick` | 74994623353767 |
| `scrambler@onehand` | 71325448354271 |
| `scrambler@onehand#trick` | 137946465146312 |
| `hoverboard@upsidedown` | 94681658442465 |
| `hoverdisc@zerog` | 103403534918034 |

## How each one was verified, and why that is not optional

24 near-identically named assets published by hand is exactly where two ids get
swapped, and a swap does not error -- it is a subtly wrong pose on one ride,
which is the hardest class of bug in this project to notice. So every id was
fetched back with `GetKeyframeSequenceAsync` and compared against the sequence
this repo builds for that key: keyframe time, joint path, CFrame and weight, in
both directions, plus a check for an `AnimationRigData` child. 25 of 25 clean.

`hoverdisc` was verified against `hoverboard`'s build locally rather than
against the asset, because `GetKeyframeSequenceAsync` hands back a CACHED
instance and the check had already destroyed that one -- after which every
later fetch of the same id returns an empty sequence, which looks exactly like
a bad upload. **Do not destroy what that call returns.**

## Publishing the next one

1. Build the sequence. In a Play session the `animdump` admin command builds
   every key into `ReplicatedStorage.AnimationDump`; in Edit the same builders
   (`CarryPose`, `SneakWalk`, `DodgeRoll`, `ThrowPose`, `CameraPose`,
   `RidePose.buildSequenceFor`) can be called straight into `ServerStorage`.
2. Publish it **from the Explorer**: right click, Save to Roblox.
3. Put the id in `Config.ANIMATIONS`, bare number or `rbxassetid://`, both work.
4. Fetch it back and diff it, as above.
5. Delete the staging folder. Anything left in the DataModel is debris Rojo
   does not reconcile -- the `GearPreview` trap.

**Never publish through a rig in the Clip Editor.** An asset published that way
carries that rig's `AnimationRigData`, and Roblox RETARGETS through it onto
whoever plays it: measured on the previous round, every rider's hands landed
about 0.87 studs off their own handlebars, with keyframes that diffed clean.
That is why the nine ride poses were republished.

**There is no scripted upload.** `AssetService:CreateAssetAsync` exists in
Studio and answers *"CreateAssetAsync and CreateAssetVersionAsync are not
available yet"*; `StudioAssetService`, `AssetManagerService` and `StudioService`
expose no publish member. Publishing is a UI action.

## Dead ids, which must not come back

On the account and no longer referenced. Every one plays the wrong thing:

* Ride poses with rig data: `bmx` 114403644299903, `bmx#trick`
  123032044115813, `skateboard` 90962106232371, `skateboard#trick`
  97117126427423, `scooter` 106867053658542, `scrambler` 134490288873353,
  `scrambler#trick` 136449255408633, `hoverboard` 122988506386726, `hoverdisc`
  78211909505189.
* `dodgeRoll` 112707884196284 -- the old stiff somersault, replaced by the dive
  roll. An uploaded id is played in preference to the built sequence, so this
  one would hide the dive roll everywhere.
* Retuned or replaced stances: `bmx@onehand` 86219177400254 and
  `bmx@onehand#trick` 139912200308894 (One Hand, now Laid Back),
  `scooter@nohands` 119583457591823 (now a T-pose), `scrambler@onehand`
  129207650513579 and `scrambler@onehand#trick` 84072966360791 (old legs),
  `skateboard@cruise` 88999637903592 and `skateboard@cruise#trick`
  83514290784857 (now the Coffin), `hoverboard@crossed` 78348588466887 (arms
  folded, retired outright).

## The legendaries' idle sway needs no upload, and that is not an oversight

`ServerStorage.RBX_ANIMSAVES` holds `phoenix-idle`, `dragon-idle` and
`rainbowtiger-idle`, each with one clip called `Scene`. The Blender FBX import
put them there; they are local clips in the place file, not assets, and they
have no ids. `Legendary/Rigs.luau` stores a sine fitted to each one and the
client moves the parts itself, so the sway works on a deployed server with
nothing published. A character's joints cannot be driven that way, which is why
everything in the table above needs a real asset.
