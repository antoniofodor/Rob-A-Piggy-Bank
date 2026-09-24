# The loot bag: the upload rounds (2026-09-22, re-cut 2026-09-23)

## Current carry version: rounded bottom

The rectangular `SackBase` has now also been removed at export. The closed,
rounded body forms the bottom; the middle coin stays and the side coins remain
excluded. `loot-bag-carry.blend`, `loot-bag.fbx`, the individual parts, and
previews reflect this version. The original shop icon scene is unchanged.

**Bag / Cloth is wired (2026-09-23): `115957622543698`.** It turned out the
02:26Z re-import had already uploaded the rounded-bottom cloth -- the mesh
the manifest of the day called "a duplicate Cloth mesh that nothing reads" --
and a fresh import of `parts/loot-bag-cloth.fbx` deduplicated onto that same
id. Told apart by reading both back with `CreateEditableMeshAsync`: the
rounded cloth's bottom five per cent spans 0.79 studs across, the rectangular
one's 1.56, and the `.obj` on disk reads 0.79. The old Bag id
`83387251897542` still refers to the rectangular base and is retired.
Use the current `manifest.json` for dimensions and triangle counts. The
round-one and round-two notes below are historical; their instructions to
retain the old Bag upload no longer apply.

**ROUND ONE IS LIVE.** All seven parts were uploaded by hand in Studio on
2026-09-23 and their ids are in `manifest.json` under `ids`.

**ROUND TWO IS FOUR OF THEM.** The designer's call of 2026-09-23 is **one
coin, on the front**: the smaller snouted coin leaning at the sack's left and
the stack of three plain coins at its right foot both come off. The side coin
is a full copy of the front one, so it wears all four gold-family materials —
**`Gold`, `GoldDark`, `GoldLight` and `Nostril` are re-exported and their live
ids are stale.** `Bag` (the cloth), `Lining` and `Rope` came out
**byte-identical** and must NOT be re-uploaded; see §0.

Uploads are the designer's, under the designer's own account — see CLAUDE.md
on generated-asset moderation, which is the most expensive entry in that file.
Once the four new ids exist, hand them to the session that owns `Config.luau`:
the whole table goes in ONE edit, because `Config.lootMesh()` returns nil for
the whole spec unless every row carries an id, so a half-filled table is the
primitives build and not half a bag.

## 0. Round two at a glance

| part | file | live id | do |
|---|---|---|---|
| `Bag` | `parts/loot-bag-cloth.fbx` | `83387251897542` | **nothing** — byte-identical |
| `Lining` | `parts/loot-bag-lining.fbx` | `121573282060816` | **nothing** — byte-identical |
| `Rope` | `parts/loot-bag-rope.fbx` | `90351490271230` | **nothing** — byte-identical |
| `Gold` | `parts/loot-bag-gold.fbx` | `120282914656671` | **re-upload** — lost the side coin's rim and face, and the whole foot stack |
| `GoldDark` | `parts/loot-bag-golddark.fbx` | `129884571364864` | **re-upload** — lost the side coin's recessed field |
| `GoldLight` | `parts/loot-bag-goldlight.fbx` | `140353057032495` | **re-upload** — lost the side coin's snout |
| `Nostril` | `parts/loot-bag-nostril.fbx` | `126223686538230` | **re-upload** — four nostrils down to two |

The three that stand were checked rather than assumed. Their `.obj` and
`.mtl` are byte-identical to the previous export; their `.fbx` differ in 40–52
bytes of the same length, and every one of those is header metadata — the FBX
`CreationTimeStamp` and Blender's per-run object UIDs. Both exports were
re-imported and diffed: same vertices, same polygons, same loop normals, same
UVs, on all three. **Two FBX exports are not expected to be byte-identical**
— the header alone is dated to the millisecond — so the geometry is what gets
compared, and the `.obj` is what gets compared byte for byte.

Why the three are untouched at all, which is the half worth keeping: the
exporter's scale is `TARGET_HEIGHT` over the whole model's own HEIGHT, and the
seat is the CLOTH's own bounding-box centre — deliberately, because the coins
are off to one side and centring on them would lean the bag. **Neither number
can see a coin**: the sack is the tallest thing in the scene, so it sets the
height, and the cloth sets the axis by itself. So every object came out of the
same x1.13837 and the same origin it always did, which is why three of the
seven are unchanged rather than nearly unchanged. Measured: scale 1.138365
before and after, and Cloth, Lining and Rope report the same offset and size
to four decimal places.

The one number that moved for them is the WHOLE model's box, which no Config
row reads: `2.8671 → 2.0491` on x, because the foot stack was what made the
model wider than the bag.

**The game does not need this to look right.** `UpgradePreview.builders.sack`
already builds the pictured object out of primitives, and that is what a thief
carries today. This is the upgrade, not the fix.

## What it is, and where it came from

`assets/shop-ui/icon-system-v1/sources/sack.blend` — the scene the Bigger Sack
shop icon (`sack.png`) is rendered from. Rebuilt for the game by
`generate/export_loot_bag.py` and read back by `generate/validate_loot_bag.py`.

* **The blend is FLAT MATERIAL COLOURS.** Seven materials, every one a plain
  Principled base colour, and not one image node or texture in the file. So
  **there is no texture to upload and none is wanted**: baking flat colour to a
  map would spend an upload and a UV set saying what a `Color3` already says,
  and it would take the colour away from the game. The model is split per
  material instead — the same call `Config.PIGGY_MESH` makes for the pig's Body
  and Trim, one step further along.
* **The green arrow is not part of the sack.** It is the icon's own "bigger"
  tell; an arrow welded to a thief's chest would be a HUD element stuck on the
  world. Excluded.
* **One coin, on the front** (designer, 2026-09-23). The icon scene carries
  three lots of gold and only the middle one survives. Excluded by name in
  `export_loot_bag.py`'s `DROP_OBJECTS`: `Coin_RolledRim.001`,
  `Coin_SatinFace.001`, `Coin_RecessedFace.001`, `PigSnout_Emboss.001`,
  `PigSnout_Nostril.002`, `PigSnout_Nostril.003` (the leaning coin) and
  `StackCoin`, `StackCoin.001`, `StackCoin.002` (the foot stack). **Named one
  by one rather than matched on a suffix**, because the FRONT coin's second
  nostril is `PigSnout_Nostril.001` and a rule like "drop every `.001`" would
  take a nostril off the coin that is meant to stay. **`sack.blend` is not
  modified**: the exporter never saves, so the icon's own scene still has all
  three coins in it, which is what `sack.png` is rendered from.
* **Sized to the pose, not to the picture.** `CarryPose.HOLD` was measured
  against a 2.2-stud mini piggy and the primitives sack stands 3.008 studs to the
  top of its own frill at level 0, so the export is scaled (x1.13837) to land on
  exactly 3.008 with **y = 0 at the base** and the coin facing **+Z**. Scale 1 is
  therefore LEVEL 0: a level is one uniform `ScaleTo((0.8 + level * 0.18) / 0.8)`,
  which is what the primitives build already does by multiplying every number
  by `s`.
* **Axes:** exported `axis_up=Y, axis_forward=-Z`, so Blender `(x, y, z)` is in
  the file as `(x, z, -y)`. Roblox reads it upright with the coin toward +Z.

## 1. The meshes (7 parts, 4 of them to re-upload)

Import each as its own MeshPart. The one that matters is the **cloth**: its
Config row is called `Bag`, the game renames that to `Body` and makes it the
PrimaryPart, exactly as `HeistService.buildLootBag` already renames the
primitives build's `Bag`, so the weld, the carry label, the trail and the nab
prompt all seat on it unchanged.

| file | feeds | triangles | game colour | round 2 |
|---|---|---|---|---|
| `parts/loot-bag-cloth.fbx` | `Config.LOOT_MESH` **Bag** `id` | 2,599 | 226, 182, 146 | — |
| `parts/loot-bag-lining.fbx` | `Config.LOOT_MESH` **Lining** `id` | 700 | 198, 138, 110 | — |
| `parts/loot-bag-rope.fbx` | `Config.LOOT_MESH` **Rope** `id` | 1,600 | 150, 96, 66 | — |
| `parts/loot-bag-gold.fbx` | `Config.LOOT_MESH` **Gold** `id` | 1,200 | 240, 198, 76 | **re-upload** |
| `parts/loot-bag-golddark.fbx` | `Config.LOOT_MESH` **GoldDark** `id` | 600 | 198, 150, 52 | **re-upload** |
| `parts/loot-bag-goldlight.fbx` | `Config.LOOT_MESH` **GoldLight** `id` | 600 | 246, 206, 198 | **re-upload** |
| `parts/loot-bag-nostril.fbx` | `Config.LOOT_MESH` **Nostril** `id` | 200 | 150, 84, 92 | **re-upload** |

**The triangle column did not move, and that is the budget binding rather
than nothing having changed.** All four gold parts were over `TRI_BUDGET`
before the cut and are still over it after, so each one lands on its budget
exactly as it did — what changed is how much collapsing it took to get there,
which is why the remaining coin is the better of the two. Gold entered at
5,348 triangles and now enters at 1,528; GoldDark 1,528 → 764; GoldLight
3,096 → 1,548; Nostril 3,840 → 1,920. `manifest.json` records both figures per
part.

7,499 triangles in total, against 43,340 as the icon scene authors the
objects this export keeps (51,392 before the coins came off).
**Roblox refuses a MeshPart over 10,000 triangles**, so the flared mouth alone
(12,288) would have been refused outright; every piece is decimated planar-first
and then collapsed to the budget in `export_loot_bag.py`, and the before/after
is in `manifest.json` so a piece that lost its shape can be found rather than
discovered.

**THE MODEL AND THE ARTWORK ARE NO LONGER THE SAME OBJECT, and that is the
decision rather than a drift.** This section used to end by saying the
decimated model and `sack.png` photograph as one thing, which was true and
stopped being true on 2026-09-23: the icon has three lots of gold and the
carried bag has one. `preview/loot-bag-{hero,front,side}.png` are re-rendered
from the same three cameras, so the two can be held up against each other —
everything but the coin count should still match, and the SACK is what the
decimation had to be judged on anyway.

**The colours in the table are the GAME's, not the blend's.** The blend is lit
by Cycles studio lamps, so its raw `tan` is (231, 164, 83) — an orange the
artwork does not show. `palette.png` carries both rows: the game's on top, the
blend's underneath.

`.obj` (with `.mtl`) sits beside every `.fbx` for anything that prefers it, and
`loot-bag.fbx` / `loot-bag.obj` hold all seven meshes in one file for a look
before importing.

## 2. The Config rows

**Round one's whole table is already in `Config.luau` and is not reprinted
here.** It went in with all seven ids AND `rot = CFrame.Angles(0, math.pi, 0)`
on every row — the 3D Importer turns each part half a turn about Y, which was
measured by reading the uploaded meshes back with
`AssetService:CreateEditableMeshAsync` and comparing their shape signatures
against the source `.obj`. **The turn is on all seven rows or none**, because
each row is seated by its own `offset` and a part left unturned lands its
features on the wrong side.

Round two changes **four rows and only their `offset` and `size`**. Sizes and
offsets are **measured off the exports**, not typed — they are
`manifest.json`'s own numbers, and `validate_loot_bag.py` reads the files back
and holds them to it. y = 0 is the base and the coin faces +Z. **`Bag`,
`Lining` and `Rope` are not edited at all**, which is the useful half: `Bag` is
what `HeistService.buildLootBag` renames to `Body` and makes the PrimaryPart,
so `CarryPose.HOLD` lands on the same centre it always did and nothing about
the carry, the weld, the label, the trail or the nab prompt moves.

| row | offset before | offset after | size before | size after |
|---|---|---|---|---|
| `Gold` | -0.0679, 0.8849, 0.4252 | **0.0000, 1.1725, 0.7640** | 2.8671, 1.6643, 0.8221 | **1.0928, 1.0928, 0.1456** |
| `GoldDark` | -0.4849, 0.8925, 0.6581 | **0.0000, 1.1725, 0.8158** | 1.8763, 1.4665, 0.3343 | **0.9070, 0.9070, 0.0191** |
| `GoldLight` | -0.4970, 0.8741, 0.7018 | **0.0000, 1.1725, 0.8610** | 1.5726, 0.9965, 0.4024 | **0.5792, 0.3996, 0.0844** |
| `Nostril` | -0.5078, 0.8643, 0.7033 | **0.0002, 1.1725, 0.8649** | 1.3016, 0.7497, 0.3344 | **0.2868, 0.1332, 0.0111** |

All four land on **x 0**: the coin is centred on the sack's own axis now
rather than pulled off it by a side coin and a foot stack, and all four are a
disc on that centre line. They also ride **higher and further forward** —
y 0.87 to 1.17, z 0.43 to 0.76 — because those figures were the centre of a
box that used to reach down to the ground and out to the stack.

```lua
	-- parts/loot-bag-gold.fbx
	{ part = "Gold", id = "<NEW ID>", colour = Color3.fromRGB(240, 198, 76),
		offset = Vector3.new(0.0000, 1.1725, 0.7640), size = Vector3.new(1.0928, 1.0928, 0.1456),
		rot = CFrame.Angles(0, math.pi, 0) },
	-- parts/loot-bag-golddark.fbx
	{ part = "GoldDark", id = "<NEW ID>", colour = Color3.fromRGB(198, 150, 52),
		offset = Vector3.new(0.0000, 1.1725, 0.8158), size = Vector3.new(0.9070, 0.9070, 0.0191),
		rot = CFrame.Angles(0, math.pi, 0) },
	-- parts/loot-bag-goldlight.fbx
	{ part = "GoldLight", id = "<NEW ID>", colour = Color3.fromRGB(246, 206, 198),
		offset = Vector3.new(0.0000, 1.1725, 0.8610), size = Vector3.new(0.5792, 0.3996, 0.0844),
		rot = CFrame.Angles(0, math.pi, 0) },
	-- parts/loot-bag-nostril.fbx
	{ part = "Nostril", id = "<NEW ID>", colour = Color3.fromRGB(150, 84, 92),
		offset = Vector3.new(0.0002, 1.1725, 0.8649), size = Vector3.new(0.2868, 0.1332, 0.0111),
		rot = CFrame.Angles(0, math.pi, 0) },
```

**THE OFFSET AND THE SIZE GO IN THE SAME EDIT AS THE ID, never after it.**
`LootMesh.build` sizes each clone and then seats it, so an id swapped in
against last cut's offset is a coin's field 0.4 studs off its own rim — which
is what the first photograph of this bag showed, from the other direction.

**CHECK THE TURN ON THE FIRST OF THE FOUR BEFORE FILLING IN THE REST.** The
three surviving rows carry `rot` because the importer turned round one's
uploads; four fresh imports of the same FBXs should be turned the same way,
and that is an expectation rather than a measurement. Import one, look at
which way the coin faces, and if the turn has gone then it has to come off all
seven rows and not four — a mixed table is the one state that reads as the
bag being broken rather than as a part being wrong.

**UNTIL THE FOUR IDS LAND, THE BAG IS THE OLD THREE-COIN MESH.** The live
Config still carries round one's four gold ids, so the game today shows the
picture the designer asked to change. Blanking one of those ids instead would
flip `Config.lootMesh()` to nil and put the whole bag on the primitives build
— and **`UpgradePreview.builders.sack` draws a `LeanCoin` and a ring of
`Coin` discs too**, so that is the same three-coin picture in primitives. The
coin count has to come off the primitives builder as well; neither half fixes
it alone.

## 3. The switch, which is one line

`Config.lootMesh()` is `Config.piggyMesh()` with the trim-splitting taken out —
walk `LOOT_MESH`, return nil the moment a row has an empty id, otherwise return
the rows with the id normalised to `rbxassetid://`.

Then **one line at the top of `builders.sack`**, and nothing else anywhere:

```lua
builders.sack = function(level)
	local s = 0.8 + level * 0.18
	if LootMesh.build(model, s) then return end
	-- ... the primitives build, unchanged ...
```

That one site covers the shop card, any 3D preview AND the carried loot,
because `HeistService.buildLootBag` goes through this builder — which is the
whole reason the loot was moved onto it. **`buildLootBag` does not change at
all**: it renames whatever child is called `Bag`, and the `Bag` row above is
the cloth.

`LootMesh` is the clone-from-a-prewarmed-folder helper the pig already needs,
for the reason `PiggyModel` has one: `InsertService:CreateMeshPartAsync` yields
and cannot be called from a client, so a service builds the seven MeshParts
once at startup into `ReplicatedStorage` and this clones them and applies
`ScaleTo(s / 0.8)`. **It must return false rather than throwing** when the
folder is not there yet, or the first client to open the shop before the
prewarm finishes gets no card at all.

## What is not done

* **The four re-cut parts are not uploaded and no id is invented.** The three
  live ids in the block above are the ones read back from Studio on
  2026-09-23 and recorded in `manifest.json`.
* **The re-cut has been looked at in Blender and not in Roblox.**
  `preview/loot-bag-{hero,front,side}.png` were re-rendered and show exactly
  one coin, centred on the front, snout toward the camera; nothing about how
  the four new meshes land in the engine has been seen, and the mirroring
  question below is still open.
* **The importer's turn WAS checked in round one, and round two's is an
  assumption.** Round one found the 3D Importer turning every part half a turn
  about Y — measured, by reading the uploaded meshes back with
  `AssetService:CreateEditableMeshAsync` and comparing shape signatures against
  the source `.obj` — so all seven live rows carry
  `rot = CFrame.Angles(0, math.pi, 0)`. Four fresh imports of the same files
  ought to be turned the same way and that has not been seen. **Import one of
  the four and look at which way the coin faces before filling in the rest**;
  the turn goes on ALL SEVEN rows or none, so a change there is a change to
  three rows nobody is re-uploading.
* **The decimation has been looked at in Blender and not in Roblox.** What the
  engine's own importer does to a 2,599-triangle cloth is its business — and
  note the cloth was not re-decimated at all this round, so whatever it looked
  like in game yesterday is what it looks like today.
* **The primitives bag still has three coins.** `UpgradePreview.builders.sack`
  draws a `LeanCoin` and two `Coin` discs per level at the foot, cut against
  the same artwork. It is the fallback whenever any row's id is blank, so the
  re-cut is only half applied until that builder loses its side coins too.
