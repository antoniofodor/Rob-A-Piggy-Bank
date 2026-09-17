# Toadstool Cottage — first Blender asset prototype

Status: editable visual model and collision/mount companion exported.
**Not imported, uploaded or integrated into Studio.** This is the first
physical prototype, not a final art sign-off or proven mobile play space.

## Files

- `mushroom.blend` — editable source, named meshes and trophy mount empties.
  REVIEW_ camera, ground and lights are for offline renders only.
- `mushroom-visual.fbx` — static visual meshes, no camera/ground/lights.
- `mushroom-visual.obj` + `.mtl` — alternative static export.
- `mushroom-collision-mounts.rbxmx` — 17 invisible anchored collision boxes,
  a non-colliding Root, and nine named trophy attachment positions.
- `exterior.png`, `front.png`, `interior.png` — actual Blender renders.
- `geometry-report.json`, `package-report.json`, `asset-checks.json` — metrics.

## Measured first-build numbers

- 86 visual meshes, 5,280 triangles total.
- No boundary/non-manifold edges in individual authored meshes.
- Full visual envelope: **25.2 wide × 27.003 deep × 14.4 high** design units,
  including the open door and roof. This exceeds the earlier 24-deep concept
  proposal; it remains below the brief's 60-wide / approximately 57-deep cap.
- Structural front-wall plane at local Z=0; complete visual front reaches
  Z=-5.903 and rear reaches Z=21.1. Fable must check this front projection
  against the actual plot's lawn slots, not just the total width/depth.
- 17 collision parts + Root: **104 BaseParts** if every visual mesh imports
  as one MeshPart. Actual trophy instances and importer splitting are extra.
- Door opening: 5.6 wide; spring height 5.35; crown 8.15. Floor at Y=.35.
- Nine standing-lane ray samples through the doorway pass in Blender.
- FBX reimport preserves all 86 exported mesh objects.

These checks do not establish zero coplanar pairs, actual Roblox collision
behaviour, camera comfort, mesh import scale or performance. Those remain
pending. Meshes intentionally intersect at some trim joints. The first
render pass fixed an inverted cutter winding that had blocked the door;
the current export has the opening verified by the lane samples.

## Import and alignment contract for Fable

Blender authoring: X across, Y into house, Z up. Export conversion targets
Roblox `(-x, z, y)`, so front is -Z. The companion RBXMX uses the same
conversion. Origin is ground level on the structural front-wall plane.
The OBJ's bounds confirm those exported axes; verify FBX importer settings.

1. Import visual FBX under the developer's own account. Preserve separate
   colours/meshes; no texture upload is required by this flat-colour source.
2. Confirm the imported complete size against the report. Blender numeric
   units are intended as studs; importer unit conversion must be checked.
3. Set visual mesh material to SmoothPlastic; use Theme colour tokens and
   turn visual collisions off. Material names group cap, cream, trim, timber,
   stone, glass, gold, green and rug colours. Mesh shading is not permission
   to introduce Metal, WoodPlanks or texture materials.
4. Align the collision/mount companion at the same authored origin. Do not
   independently centre each file by its bounding box. Use Root for the
   HOUSE_FRONT_LINE placement adapter.
5. Validate walking, jumping, camera views, door swing clearance, and future
   robbery/pursuit behaviour with the actual avatar in Studio. Collision
   proxies are deliberately simple; ceiling coverage and curved-wall corners
   may need adjustment based on those checks.
6. Mount actual trophy objects by ID. Shelf mount positions are draft;
   current full-size Decor displays must not be blindly scaled into tiny
   shelf slots. Resolve compact display variants/selection with the interior
   design. Wall/plaque attachment orientations require final alignment.

The house is Rare and currently has no animated decoration. Legendary
motion specifications live in `assets/design/phase-4b/fantasy-v3/`.
House construction and game integration remain Fable's area.

## Rebuild

Run Blender in background with `blender/houses/build_mushroom.py`, then run
`python blender/houses/package_mushroom.py`; Blender background with
`blender/houses/verify_mushroom.py` performs the asset checks. No runtime
game scripts are modified. The thumbnail-cache warning seen on save did
not affect the saved blend, renders, OBJ or FBX.

Recommended next physical work: refine this prototype in Studio to confirm
scale/collision/camera, then reuse the export contract for Treehouse and Gloop.
Do not multiply an unverified importer scale across the whole catalogue.
