# `assets/` -- source art that is uploaded rather than generated in code

This game is built in code. Nothing in this folder is synced by Rojo and
nothing here is read at run time: these are the SOURCE files behind assets
that had to be uploaded to Roblox and are referenced by id from `Config`.

**This folder is for art authored OUTSIDE the Blender pipeline** -- Meshy,
Studio's AI generator, anything hand-modelled, anything bought. The pig's own
pipeline is `blender/pig/` and it has its own contract in
`blender/pig/WORKFLOW.md` and its own `paths.py`; **do not move anything
there**, because sixty scripts resolve their locations through that one file.

The newer oak and dog Blender authoring scripts live in `blender/tree/` and
`blender/dogs/`; their reviewable `.blend`, GLB, and render deliverables live
with the named assets in `assets/tree/blender/` and `assets/dogs/`. This does
not change the pig pipeline's paths.

The approved simpler guard direction is in `assets/guards/`, authored by
`blender/guards/`. It includes the three revised dogs and five wild/elite
creatures, editable rigs, and starter animation clips. They are integrated
in the local project and Studio; the primitive guards have been retired. Reproducible imported
mesh templates live in `src/ServerStorage/GuardTemplates`; see
`assets/guards/ANIMATION-GUIDE.md` for animation details.

---

## The rule: one folder per named thing, named after its `Config` key

```
assets/
  acorn/
    acorn.glb        the source, named after the folder
  basket/
  dogs/
    terrier/  shepherd/  mastiff/
```

That is deliberately the same rule `blender/pig/skins/<skin>/` already
follows -- *a skin owns a folder and everything in it is named after the
skin* -- rather than a second convention to learn. The payoff is that the
folder name and the `Config` key are the same string, so the source of a
shipped asset is findable from the code and the code is findable from the
source with no index in between.

**Generator filenames are renamed on the way in.** A name like
`Meshy_AI_smooth_acorn_final_0915202639_image-to-3d-texture.glb` carries the
tool, a timestamp and a pipeline stage, none of which anybody will ever search
for, and it sorts next to every other file that tool ever produced rather than
next to the thing it is. Provenance lives in the commit message, where it
cannot rot.

## Where the uploaded id goes, and why there is no register here

**The id goes in `Config`, with a comment naming the source path**, exactly as
`Config.PIGGY_MESH`, `Config.TREE_MESH` and `Config.ANIMATIONS` already do.
One place, read by the game, so it cannot disagree with anything.

There is deliberately **no table of assets in this folder.** What exists, what
is missing and what state each thing is in is `docs/MASTER-PLAN.md` section
18.3, and a second copy of that list is the thing this project has already
paid for once -- seven planning documents that drifted apart. If an asset's
status is worth writing down, write it there.

**An empty id row is the correct way to ship an unfinished asset**, and every
reader in this codebase already handles one: `Config.animationId` returns nil
for an empty row and the caller degrades, `Config.fenceMesh` falls back per
style to the primitive decorator, and a dangling `MaterialVariant` name
renders the stock material. `Main` warns at startup for anything still empty
on a live server. That is what lets an asset land one piece at a time.

---

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
is a constant; the pig is stripped because 46 skins multiply a colour onto it
and a painted mesh is muddy on 45 of them. Anything new gets asked the same
question before its map is uploaded.

## Size, and git

Raw generator output is large, and it is almost entirely TEXTURE. The acorn is
21.4 MB of which 21.4 MB is two PNG maps -- a 14.9 MB base colour and a 6.6 MB
metallic-roughness -- against 3,138 triangles of actual geometry that would fit
in a few tens of kilobytes. **Commit the reduced file that actually gets
uploaded**; if raw output is worth keeping, keep it out of
the repo or put it behind Git LFS rather than letting a few hundred megabytes
of superseded generations accumulate. That is the same argument
`blender/.gitignore` already makes about preview renders, one category along:
what is worth committing is the source of a shipped asset, not every artefact
that was produced on the way to it.
