# Physical house assets — GPT handoff

Updated September 16, 2026. This file records art work without changing Fable's
runtime/planning files or the shared root PROGRESS.md.

## Completed in this batch

- Built actual Blender prototypes for **The Treehouse** (`treehouse`, 750K Rare)
  and **Gloop House** (`slime`, 2.5M Epic), continuing the Toadstool prototype.
- Treehouse has a walkable switchback stair, raised cabin, deck, short bridge,
  side platform, fixed collision guides and internal trophy positions. Branches
  rise behind the cabin rather than cutting through its shelves. Door opens
  inward to keep the exterior circulation space clear.
- Gloop has green interior/exterior walls, slime lobes and drips, a purple
  doorway and a larger trophy/display room. The shell is physically hollow.
- Added common Blender construction, collision/mount packaging and offline
  route verification scripts under `blender/houses/`.
- Added a local gallery (`index.html`), generated asset READMEs, actual model
  renders, editable `.blend` files, OBJ/MTL exports and RBXMX companions.
- Each model has Featured, Shelf_1..4, Wall, Record, Plaque_Legacy and Door_Exit
  attachment positions. Actual trophy art/layout still needs integration.

The latest counts, measured bounds and results live in each model's
`package-report.json` and `asset-checks.json`. Bounds are measured from exported
vertices, not enlarged rotated-object bounding boxes. Counts include separate
collision guides but exclude actual trophies and importer splitting.

## Validation and limitations

Models were visually inspected in exterior and cutaway renders. Checked
individual mesh manifold edges, per-mesh triangle budget, complete visual
width/depth, FBX round-trip object counts, and sampled routes. Treehouse/Gloop
route checks include visual geometry and proxy collisions, five upward rays
and horizontal cross-rays at three body heights. They do not simulate Roblox
Humanoids or a continuous swept avatar. Coplanar intersections were corrected
where seen, but a complete coplanar audit has not been performed.

**No Studio control connection is available in this session. These assets have
not been imported, uploaded, installed, or playtested in Studio.** Blender
numeric units are intended as studs; import scale must be confirmed. Live
camera, jumping, stair behaviour, complete collision coverage, trophy sizing,
mobile performance and plot/lawn clearance remain pending. In particular,
check Treehouse's stair projection in front of HOUSE_FRONT_LINE.

The root `.gitignore` intentionally excludes generated FBX files. Rebuild
those from the Blender scripts on another machine; the source `.blend` and
OBJ exports remain available. Blender backup files and Python caches are
ignored locally. No commit or push was made during this continuation.

## Design decisions still in force

- Walk-in interiors occupy the house's physical world space; no teleport.
- Gingerbread stays seasonal despite its reappearance in revision 2's table.
  The permanent 8M slot still needs a replacement concept.
- Gloop is green inside and out.
- Revision 2 reserves the single black house for **The Void** at 1B.
- Every Legendary house gets decorative animation, including Portal House.
  Specifications and the Portal motion study are in
  `assets/design/phase-4b/fantasy-v3/`. This Rare/Epic batch is static.
- Earned Golden Piggy rules and re-theme migrations remain Fable's work and
  require the outstanding design confirmations recorded in that handoff.

## Resume here

1. Review the actual models in `index.html` and the per-asset import handoffs.
2. Fable/integrator: import a prototype and verify the shared origin/scale,
   HOUSE_FRONT_LINE placement and real avatar/camera behaviour before
   multiplying the same dimensions across the remaining catalogue.
3. GPT: use those measurements to refine these prototypes, then build the
   next approved silhouettes. Legendary assets should keep animated scenery
   separate from static floor, stairs and collision guides.
4. Keep runtime scripts, economy, ownership migrations and functional game
   tests with Fable; do not overwrite concurrent edits.
