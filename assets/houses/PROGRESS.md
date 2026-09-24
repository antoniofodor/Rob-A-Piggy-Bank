# Physical house assets — GPT handoff

Updated September 17, 2026. This file records house art and its import handoff.

## Latest: 18 empty walk-in revisions (September 17)

See [the current gallery](walk-in.html) and [asset index](README.md). All permanent
houses have a bare accessible main floor, a real doorway, separate collision
boxes, an empty display-wall mount and independent automatic door leaves.
Treehouse/Gloop use v3; the other houses use v2. Earlier exterior packages below
are historical. Upper storeys remain exterior architecture; no furniture or
display decorations were added. Gingerbread remains seasonal and excluded.

Approved exterior resizes are baked into each source; the runtime generator
uses display scale 1.0 for these interiors. The new
[interior brief](docs/HOUSE-INTERIOR-BRIEF.md) supplies the clearance,
collision and display-wall contract. Fishbowl's dome/bubble transparency now
travels through the export manifest, runtime generator and Studio helper.

`tools/build_walkin_batch.py` rebuilds the models, `tools/build_walkin_handoff.py`
refreshes the import helpers/gallery, and `tools/check_walkin_packages.py`
checks all packages. `tests/check_walkin_runtime.py` at the repository root
checks scale, glass and door pivots. Visual review includes exterior, entrance
and interior renders; tunnel cutting avoids coplanar lining faces.
Final verification passes: 18 packages, 720 clearance probes, runtime fixture,
client/helper Luau compilation and Rojo build. All 820 house links resolve;
the 188 original binary assets retain their pre-organization hashes.

**Fresh Studio imports and live walk-throughs are still required.** No new mesh
IDs were uploaded and no live templates were replaced. Each package README
explains the FBX import and `prepare-in-studio.luau` helper. Record new mesh IDs
before running the runtime generator; old import records describe old geometry.
The Rojo client door animator is ready for the new hinge markers. Verify camera,
door sweep, stairs, plot/fence clearance and multiplayer/mobile behavior in Play.

## Previous: all 18 permanent Blender models (September 17)

The final six legacy replacements are Cardboard Fort (`shack`), Beehive
Cottage (`cottage`), Wonky Townhouse (`townhouse`), Haunted Manor (`manor`),
Neon Tower and Sky Castle. These complete **18 permanent Blender house
models**, including the free starter and earned Golden Piggy. Seasonal
Gingerbread is excluded and was not rebuilt in this pass.

The complete [gallery](mvp-exteriors.html) and [inventory](MVP-EXTERIORS.md)
now account for all 18 IDs, revisions, source files and exports. The new six
include exterior/front/low-angle renders and offline geometry/FBX reports.
Rebuild with `assets/houses/tools/build_legacy_exteriors.py`; regenerate the full
inventory with `build_permanent_handoff.py`. Model coverage is distinct from
runtime integration. The six are closed exterior drafts, with interiors
deferred and Studio placement/collision/lighting still pending. No game
runtime, prices or ownership files were changed for this batch.

## Previous: MVP exterior library (September 17)

The exterior continuation now includes Portal House, Thundercloud Fortress,
The Void, Fairy Lantern Cottage, Fishbowl House, Ice Palace, Golden Piggy
and seasonal Gingerbread Manor, alongside Crystal Spire and Beached Galleon.
Start at [the model gallery](mvp-exteriors.html) or
[the measured batch handoff](MVP-EXTERIORS.md) for Blender sources, FBX files,
actual renders and validation scope. Interiors are deferred beyond MVP.
Studio integration and live checks remain pending. Existing Mushroom,
Treehouse and Gloop assets are preserved; their interior notes below record
earlier work and are not instructions to resume it.

## Previous: Gloop House sculpted revision 2 (September 17)

The next art task is built in `gloop-house-v2/`, using the original fantasy-v2
Gloop concept. It has a continuous hollow lime-green shell, dark drippy
roof, blob chimney, open purple door, amber windows and foundation slime.
The interior has an achievement cabinet, featured pedestal, records desk
and Legacy wall plaque with named display/interaction/standing mounts.
Example awards are render-only and excluded from exports.

Use **`gloop-house-v2/gloop-house-roblox.fbx`** for Studio import: 37 single-material
meshes, 42,776 triangles. There are eight draft collision boxes and fifteen
attachments in the companion RBXMX. Source and renders are in the same
folder; start at `gloop-house-v2/index.html` or its README for review/import notes.

Offline geometry and material checks passed. FBX bounds round trip error
was below 0.000002 units. All 113 sampled visual route points to the three
stations were unobstructed. These checks do not certify the draft colliders
or simulate a real Roblox avatar. Studio scale, collision, camera, mobile
performance and plot fit still need live checks.

Three named drip meshes have a pulse specification in
`animation-handoff.json`. No menus, runtime animation, Studio installation
or publishing were performed. Fable owns that integration. Rebuild with
`assets/houses/tools/build_slime_v2.py`, then
`assets/houses/tools/export_house_roblox.py -- slime 2` through Blender.
Runtime scripts and shared planning documents were not edited for this task.

## Previous: Treehouse reference rebuild (September 17)

The user found the first Blender model too far from the reference and requested
another Blender attempt. `treehouse-v2/` is the new **visual review** version,
built against `assets/houses/design/fantasy-v2/treehouse-concept.png`.

It adds the reference's branching/rooted oak, fuller canopy, steep shingled
roof, square amber and blue windows, heavier timber, front stair flights,
rope bridge, lookout, lanterns and interior furnishings. Exterior, front and
cutaway images are actual Blender renders. Source and exports are in the
revision folder; build/verification scripts are `build_treehouse_v2.py` and
`verify_treehouse_v2.py` under `assets/houses/tools/`.

The previous prototype is preserved. Its route checks/collision companion do
**not** apply to this new structure. V2 requires new Studio collision, camera,
scale, material-splitting and plot checks; no live integration was performed.
Start with `treehouse-v2/index.html` for the reference comparison and its
README for remaining limitations. The batch notes below describe v1.

For Studio import, use `treehouse-v2/treehouse-roblox.fbx`, generated by
`assets/houses/tools/export_treehouse_roblox.py`. It splits the art into 68 meshes
with one material per mesh, preserving 31,604 triangles and source bounds.
Its FBX round trip passed; live Studio colour/scale/collision checks remain
pending. `roblox-import-report.json` records exact colours for the importer.

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
  route verification scripts under `assets/houses/tools/`.
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
  `assets/houses/design/fantasy-v3/`. This Rare/Epic batch is static.
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
# Current location — September 17

The asset library is now `assets/houses/`. See [README.md](README.md) for the
complete house list and current file names. Models and exports use descriptive
names (for example, `fishbowl-house.blend`); game IDs remain stable. Build scripts
are in `tools/`, concept/design packages in `concepts/` and `design/`, and plans
in `docs/`. Historical status notes below retain their original scope.
