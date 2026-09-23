# The loot bag: the upload round (2026-09-22)

Every file below is on disk and checked; **nothing has been uploaded**. Uploads
are the designer's, one round, under the designer's own account — see CLAUDE.md
on generated-asset moderation, which is the most expensive entry in that file.
Once the ids exist, hand them to the session that owns `Config.luau`: all seven
rows go in ONE edit, because `Config.lootMesh()` returns nil for the whole spec
unless every row carries an id, so a half-filled table is the primitives build
and not half a bag.

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
* **Sized to the pose, not to the picture.** `CarryPose.HOLD` was measured
  against a 2.2-stud mini piggy and the primitives sack stands 3.008 studs to the
  top of its own frill at level 0, so the export is scaled (x1.13837) to land on
  exactly 3.008 with **y = 0 at the base** and the coin facing **+Z**. Scale 1 is
  therefore LEVEL 0: a level is one uniform `ScaleTo((0.8 + level * 0.18) / 0.8)`,
  which is what the primitives build already does by multiplying every number
  by `s`.
* **Axes:** exported `axis_up=Y, axis_forward=-Z`, so Blender `(x, y, z)` is in
  the file as `(x, z, -y)`. Roblox reads it upright with the coin toward +Z.

## 1. The meshes (7 uploads)

Import each as its own MeshPart. The one that matters is the **cloth**: its
Config row is called `Bag`, the game renames that to `Body` and makes it the
PrimaryPart, exactly as `HeistService.buildLootBag` already renames the
primitives build's `Bag`, so the weld, the carry label, the trail and the nab
prompt all seat on it unchanged.

| file | feeds | triangles | game colour |
|---|---|---|---|
| `parts/loot-bag-cloth.fbx` | `Config.LOOT_MESH` **Bag** `id` | 2,599 | 226, 182, 146 |
| `parts/loot-bag-lining.fbx` | `Config.LOOT_MESH` **Lining** `id` | 700 | 198, 138, 110 |
| `parts/loot-bag-rope.fbx` | `Config.LOOT_MESH` **Rope** `id` | 1,600 | 150, 96, 66 |
| `parts/loot-bag-gold.fbx` | `Config.LOOT_MESH` **Gold** `id` | 1,200 | 240, 198, 76 |
| `parts/loot-bag-golddark.fbx` | `Config.LOOT_MESH` **GoldDark** `id` | 600 | 198, 150, 52 |
| `parts/loot-bag-goldlight.fbx` | `Config.LOOT_MESH` **GoldLight** `id` | 600 | 246, 206, 198 |
| `parts/loot-bag-nostril.fbx` | `Config.LOOT_MESH` **Nostril** `id` | 200 | 150, 84, 92 |

7,499 triangles in total, against 37,571 as the icon scene authored them.
**Roblox refuses a MeshPart over 10,000 triangles**, so the flared mouth alone
(12,288) would have been refused outright; every piece is decimated planar-first
and then collapsed to the budget in `export_loot_bag.py`, and the before/after
is in `manifest.json` so a piece that lost its shape can be found rather than
discovered. Photographed against the icon at `preview/loot-bag-hero.png` and
`preview/loot-bag-front.png` — the decimated model and the artwork are the same
object.

**The colours in the table are the GAME's, not the blend's.** The blend is lit
by Cycles studio lamps, so its raw `tan` is (231, 164, 83) — an orange the
artwork does not show. `palette.png` carries both rows: the game's on top, the
blend's underneath.

`.obj` (with `.mtl`) sits beside every `.fbx` for anything that prefers it, and
`loot-bag.fbx` / `loot-bag.obj` hold all seven meshes in one file for a look
before importing.

## 2. The Config rows

Sizes and offsets below are **measured off the exports**, not typed — they are
`manifest.json`'s own numbers, and `validate_loot_bag.py` reads the files back
and holds them to it. The block goes beside `Config.PIGGY_MESH`, which it is
modelled on.

```lua
-- THE LOOT BAG AS A MESH, AND AN EMPTY ID IS THE SHIPPED BUILD.
--
-- `UpgradePreview.builders.sack` builds the carried loot and the Bigger Sack
-- card out of primitives, cut against the same artwork this mesh came from, so
-- an empty table here is a bag that looks right rather than a feature that is
-- missing. Same contract as `Config.PIGGY_MESH`: `Config.lootMesh()` returns
-- nil for the WHOLE spec unless every row has an id, because a half-uploaded
-- set is a sack with no rope on it and nothing in any log to say so.
--
-- SCALE 1 IS LEVEL 0. The export is sized so the model stands 3.008 studs to
-- the top of its frill, which is what `builders.sack` builds at `s = 0.8`, and
-- a level is one uniform `ScaleTo((0.8 + level * 0.18) / 0.8)`.
--
-- Measured off `assets/loot-bag/manifest.json`, which the exporter writes and
-- `validate_loot_bag.py` holds the files to. y = 0 is the base and the coin
-- faces +Z.
Config.LOOT_MESH = {
	-- The bag itself: `parts/loot-bag-cloth.fbx`, which the export calls
	-- `Cloth` after its material. The PART is called `Bag` because
	-- `HeistService.buildLootBag` renames whichever child has that name to
	-- `Body` and makes it the PrimaryPart -- so keeping it leaves the weld,
	-- the carry label, the trail and the nab prompt untouched by the swap.
	{ part = "Bag", id = "",
		colour = Color3.fromRGB(226, 182, 146),
		offset = Vector3.new(0.0000, 1.5040, 0.0000),
		size = Vector3.new(2.0491, 3.0080, 1.5254) },
	-- parts/loot-bag-lining.fbx
	{ part = "Lining", id = "",
		colour = Color3.fromRGB(198, 138, 110),
		offset = Vector3.new(0.0191, 2.5381, -0.0091),
		size = Vector3.new(1.3993, 0.9097, 1.0139) },
	-- parts/loot-bag-rope.fbx
	{ part = "Rope", id = "",
		colour = Color3.fromRGB(150, 96, 66),
		offset = Vector3.new(0.0049, 2.2632, 0.1715),
		size = Vector3.new(1.0643, 0.6240, 0.9757) },
	-- parts/loot-bag-gold.fbx
	{ part = "Gold", id = "",
		colour = Color3.fromRGB(240, 198, 76),
		offset = Vector3.new(-0.0679, 0.8849, 0.4252),
		size = Vector3.new(2.8671, 1.6643, 0.8221) },
	-- parts/loot-bag-golddark.fbx
	{ part = "GoldDark", id = "",
		colour = Color3.fromRGB(198, 150, 52),
		offset = Vector3.new(-0.4849, 0.8925, 0.6581),
		size = Vector3.new(1.8763, 1.4665, 0.3343) },
	-- parts/loot-bag-goldlight.fbx
	{ part = "GoldLight", id = "",
		colour = Color3.fromRGB(246, 206, 198),
		offset = Vector3.new(-0.4970, 0.8741, 0.7018),
		size = Vector3.new(1.5726, 0.9965, 0.4024) },
	-- parts/loot-bag-nostril.fbx
	{ part = "Nostril", id = "",
		colour = Color3.fromRGB(150, 84, 92),
		offset = Vector3.new(-0.5078, 0.8643, 0.7033),
		size = Vector3.new(1.3016, 0.7497, 0.3344) },
}
```

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

* **Nothing is uploaded and no id is invented.**
* **The importer's mirroring has not been checked**, because that needs Studio.
  `Config.PIGGY_MESH` carries `rot = CFrame.Angles(0, math.pi, 0)` on both rows
  with a comment saying the importer mirrors Z and only a photograph catches it.
  The rows above carry no `rot`. **Import one part and look at which way the
  coin faces before filling in the rest** — if it faces the thief, every row
  wants the same half turn, and it wants it on ALL of them or the pieces face
  opposite ways.
* **The decimation has been looked at in Blender and not in Roblox.** The
  render is the artwork; what the engine's own importer does to a 2,599-triangle
  cloth is its business.
