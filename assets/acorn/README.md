# Imported Acorn -- RETIRED, KEPT AS AN UPLOAD RECORD

THE ACORN CURRENCY IS GONE (schema 29). `data.loot`, the tree, the basket, the
minigame, the season ladder and the HUD tab were all deleted; `Config.ACORN_MESH`
is gone, so nothing builds these meshes and nothing mounts the icon.
`Shared/ShopIcons.luau` says so in its header and names this folder as where the
icon's id is archived -- that is a POINTER TO A RECORD, not a live read.

This folder survives for one reason only: it is the only local copy of FIVE
UPLOADED ASSET IDS that cannot be re-derived, because the Assets API has no list
endpoint (the only recovery route is a Studio inventory search plus
`GetProductInfo` dates). Do not delete these:

- `acorn.json` -- the Nut / Cap / Stem mesh ids and their shared texture id,
  with Studio-measured sizes and offsets.
- `acorn.rbxmx` -- the same ids as a portable assembly.
- `ui/acorn-model-icon.json` + `.png` -- the uploaded shop icon and its id.
- `acorn-report.json` -- triangle counts and measured bounds.

`acorn.glb` (21.5 MB, UNTRACKED) is raw image-to-3D generator output, almost
entirely two PBR maps, and is NOT the source the uploaded meshes came from -- the
note below says the original GLB was never supplied with the import. It is the
file `assets/README.md` uses as its worked example of what not to commit. It was
left in place on 2026-09-23 ONLY because it is untracked and therefore
unrecoverable; it is on a quarantine list awaiting the owner's approval.

The original import note follows.

The designer imported `Workspace.acorn`. Its three uploaded meshes (Nut,
Cap and Stem) share one texture. `acorn.json` records Studio measurements;
`acorn.rbxmx` preserves a portable Roblox assembly using those uploaded IDs.
The original source GLB was not supplied with this import.

Overall bounds: 0.594 × 0.827 × 0.594 studs. Runtime uses a white tint and
positions each piece relative to the Nut centre. `Config.ACORN_MESH` is the
runtime source of IDs, dimensions and offsets. `AcornModel` prewarms a
replicated template; tree/ground Acorns, storage fill and carried baskets clone it.
The shake panel keeps the existing legible 2D `Theme.acorn` glyph.
