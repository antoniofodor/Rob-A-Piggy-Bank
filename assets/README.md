# `assets/` -- source art that is uploaded rather than generated in code

**Nothing in this folder is synced by Rojo and nothing here is read at run
time.** These are the SOURCE files behind assets that had to be uploaded to
Roblox, plus the only local RECORD of the ids they were uploaded under. The game
itself is built in code.

Everything here is one of three things, and the difference decides whether it
can be deleted:

* an **authoring source** -- a `.blend`, a generator script, a
  `ride-geometry.json`. Regenerable in principle, expensive in practice.
* an **upload record** -- a `manifest.json`, a `roblox-uploads.json`, an
  `UPLOADS.md`, a `*-report.json`. **These are irreplaceable.** The Assets API
  has no list endpoint, so an id deleted here is recoverable only by searching
  the developer's Studio inventory and dating candidates with
  `GetProductInfo`. `docs/ORPHANED-UPLOADS.md` is what that costs.
* a **review render** -- a hero shot, a contact sheet, a concept sheet. Worth
  the least, and the first thing to go.

An upload record is never deleted, even when the art it describes is retired and
even when the feature it was for has been cut from the game.

## What each folder is

| Folder | What it is | Status |
|---|---|---|
| [`animations/`](animations/README.md) | The 24 uploaded animation assets behind `Config.ANIMATIONS`, keyed by animation name | **Upload record. Live** -- `Config.luau` names this file, and there is no other copy of these ids |
| [`environment/`](environment/) | The Piggy Meadows kit and world border: concepts, Blender build, FBX exports, import manifest | Authoring source + record. Live -- `tools/finalize_meadows.py` and `tools/upload_meadows.py` read `piggy-meadows/build-v1`. **Untracked** |
| [`guards/`](guards/README.md) | All thirteen guardian rigs (`Config.DOG_COATS`): a `.blend` per rig, measurement reports, shop-card renders, roster sheets, and a handoff zip holding the FBX/GLB exports | Authoring source + upload record. Live |
| [`houses/`](houses/) | The house catalogue's models and shop cards | Live. **Owned elsewhere -- not covered by this index** |
| [`loot-bag/`](loot-bag/UPLOADS.md) | The carried coin sack: Blender export scripts, the seven per-material meshes, and the ids in `Config.LOOT_MESH` | Authoring source + upload record. Live -- `import/asset-ids.csv` and `tools/stage_import.py` both name it |
| [`piggies/`](piggies/README.md) | The source of truth for every piggy skin: scene, generator, sheets, previews, import package and live texture ids | Live. **Owned elsewhere -- not covered by this index** |
| [`rides/`](rides/) | `ride-geometry.json` (the render source) and a shop card per ride, with ids mapped by `ShopRideCards` | Authoring source + upload record. Live |
| [`scenery-trees/`](scenery-trees/README.md) | The broadleaf and evergreen street trees imported into `ServerStorage.SceneryTreeTemplates`, with every mesh and texture id | **Upload record. Live** -- `SceneryTrees.luau` clones those templates |
| [`shop-ui/`](shop-ui/icon-system-v1/FILES.md) | The generated shop icon set (`icon-system-v1`), the 3D game models cut from it, and the `*-images/` upload records for the house, guardian, ride and skin cards | Authoring source + upload record. Live |
| [`skins/`](skins/animal/README.md) | Only the animal-skin TIER GALLERY pages now (`index.html`, `manifest.json`, checks). The packages moved to `piggies/<tier>/<key>/` | Review pages. Live -- `blender/pig/paths.py` writes them |
| [`ui/`](ui/) | `pop-the-pins-v1` (the crack minigame sprites, named by `Shared/Crack.luau`), `rebirth-icons-v1` (named by `Config` and `Shared/Rebirth.luau`), and two retired concept rounds kept for their reasoning | Authoring source + sprite masters. Live. **Note: no upload record here** -- these ids live only as `rbxassetid://` literals in `Config` and `Crack.luau`, so those are the single copy |
| [`robbery-ui/`](robbery-ui/) | Two phone mockups of the robbery HUD, cited by `docs/GAME.md` as verification art | Review render. Kept for that citation only |
| [`acorn/`](acorn/README.md) | **RETIRED.** The acorn currency was deleted in schema 29 | Upload record only -- five ids that cannot be re-derived |
| [`crate/`](crate/README.md) | **RETIRED.** The acorn storage crate; the doorstep crate is built from primitives in `PlotService` | Upload record only -- five ids |
| [`tree/`](tree/README.md) | **RETIRED.** The acorn oak. `Config.TREE_MESH` is a DIFFERENT tree and its ids are not in here | Upload record + measurements |
| [`piggy-hud/`](piggy-hud/README.md) | **RETIRED.** The generated piggy-balance icon; the panel draws `Theme.snout` now | Upload record -- one id, recorded nowhere else |

Four folders survive **only** as upload records. Each one's README opens by
saying so, so nobody has to come back to this table to find out.

## The rule: one folder per named thing, named after its `Config` key

```
assets/
  guards/
    terrier/  shepherd/  mastiff/
  rides/
    bmx/  skateboard/  scrambler/
```

That is deliberately the same rule `assets/piggies/<tier>/<skin>/` follows -- *a
skin owns a folder and everything in it is named after the skin* -- rather than
a second convention to learn. The payoff is that the folder name and the
`Config` key are the same string, so the source of a shipped asset is findable
from the code and the code is findable from the source with no index in between.

Note the KEY, not the display name. The Scrappy guardian's folder is
`guards/terrier/`, because `terrier` is what the save and `Config.DOG_COATS`
call it; renaming the folder to match the shop would be a rename nothing in the
code would follow.

**Generator filenames are renamed on the way in.** A name like
`Meshy_AI_smooth_acorn_final_0915202639_image-to-3d-texture.glb` carries the
tool, a timestamp and a pipeline stage, none of which anybody will ever search
for, and it sorts next to every other file that tool ever produced rather than
next to the thing it is. Provenance lives in the commit message, where it cannot
rot.

## Where the uploaded id goes

**The id goes in `Config`, with a comment naming the source path**, exactly as
`Config.PIGGY_MESH`, `Config.TREE_MESH`, `Config.LOOT_MESH` and
`Config.ANIMATIONS` already do. One place, read by the game, so it cannot
disagree with anything.

**And a second copy stays here**, in the folder's own `manifest.json`,
`roblox-uploads.json` or `UPLOADS.md`. That is not a contradiction of the rule
above: `Config` is what the GAME reads, and the record here is what survives the
row being deleted from `Config` when a feature is cut. The four retired folders
above are that rule being paid for.

There is deliberately **no table of assets in this folder.** What exists, what
is missing and what state each thing is in is `docs/MASTER-PLAN.md` section
18.3, and a second copy of that list is the thing this project has already paid
for once -- seven planning documents that drifted apart. If an asset's status is
worth writing down, write it there. `docs/ASSET-INVENTORY.md` is the cross-cut
by id.

**An empty id row is the correct way to ship an unfinished asset**, and every
reader in this codebase already handles one: `Config.animationId` returns nil for
an empty row and the caller degrades, `Config.fenceMesh` falls back per style to
the primitive decorator, and a dangling `MaterialVariant` name renders the stock
material. `Main` warns at startup for anything still empty on a live server. That
is what lets an asset land one piece at a time.

## What every mesh has to clear before it is uploaded

Checked on the way in, not after a failed upload.

| limit | value | why it bites |
|---|---|---|
| **triangles per `MeshPart`** | **10,000** | image-to-3D generators routinely return 100k-250k. A mesh over the limit is refused outright |
| texture | one map, and it is downsized on upload | this street is **flat-shaded low poly**; a PBR set (base + normal + roughness) is three uploads' worth of data describing lighting the game does not use |
| colour | a mesh gets **one** `Color` unless it is segmented | anything that needs two tones must come back in separate pieces, or the second tone can only live in a baked texture and can never be recoloured |
| `MeshId` | **not writable from a script** | meshes come from `InsertService:CreateMeshPartAsync`; `TextureID` *is* writable and is assigned afterwards -- a generated mesh and its map are two separate uploads |
| every upload | published under the **developer's own account** | and moderated like anything else they publish. See `CLAUDE.md` on `generate_material`: twelve candidates in one session got the account actioned, and it presented as a broken Studio login |

**A baked texture is right for a tree and wrong for a pig**, and the test is
whether the thing has a skin system. The tree keeps its map because its colour
is a constant; the pig is stripped because every skin multiplies a colour onto it
and a painted mesh is muddy on all but one of them. Anything new gets asked the
same question before its map is uploaded.

## Size, and git

Raw generator output is large, and it is almost entirely TEXTURE.
`acorn/acorn.glb` is the worked example: 21.5 MB of which nearly all is two PNG
maps -- a base colour and a metallic-roughness -- against a few thousand
triangles of geometry that would fit in tens of kilobytes. It is not even the
file the uploaded acorn meshes came from. **Commit the reduced file that actually
gets uploaded**; if raw output is worth keeping, keep it out of the repo or put
it behind Git LFS rather than letting a few hundred megabytes of superseded
generations accumulate.

Two classes to watch, both of which had accumulated by 2026-09-23:

* **`.blend1` files.** Blender writes one beside every `.blend` it saves; they
  are backups of the file next to them. `assets/tree/blender/.gitignore` already
  ignores them, nothing else does, and `shop-ui/icon-system-v1/sources/` has 7.5
  MB of them.
* **A `*.before-closedback.*` twin of a whole package.** `assets/skins/` held 102
  MB of those, and every byte was a second copy of something still sitting in
  `assets/piggies/`. A pre-change backup is what git is for.

That is the same argument `blender/.gitignore` already makes about preview
renders, one category along: what is worth committing is the source of a shipped
asset and the record of its upload, not every artefact produced on the way to it.
