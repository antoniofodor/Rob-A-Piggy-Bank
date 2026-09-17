# Gloop House — Blender prototype

Green walls inside and out, thick slime drips, a purple door and a larger display room.

**Status: offline asset prototype, not imported or integrated into Studio.**
This is actual mesh geometry with walk-in space inside the shell. The interior
render temporarily hides the front wall and roof; gameplay uses the full shell.

## Contents

- `slime.blend`: editable source, named meshes, trophy marker empties.
- `slime-visual.fbx`: static visual export, without review lights/camera/ground.
- `slime-visual.obj` and `.mtl`: alternate export and material colours.
- `slime-collision-mounts.rbxmx`: anchored invisible collision guides, Root,
  and nine semantic trophy attachments. Visual MeshParts should not collide.
- Exterior, front and interior PNGs: actual Blender renders.
- Geometry, package and asset-check reports: measured build outputs.

FBX exports follow the repository's existing ignore rule. On another machine,
rebuild from the checked-in Blender scripts/source or use the OBJ export.

## Measured build

- 84 visual mesh objects; 12,668 triangles total.
- 11 collision parts plus Root; **96 BaseParts** before trophies
  if each exported mesh becomes one MeshPart. Importer splitting can add parts.
- Complete visual bounds: **27.400 W × 29.825 D × 17.680 H**.
  Includes open door, roof, foliage and exterior decorations.
- Front projection: local Roblox Z=-6.625; rear Z=23.200.
- Floor at Y=0.4; doorway 6 wide.
- 43 route centreline samples passed the offline clearance/support check.
  Each sample uses five upward rays and horizontal cross-rays at three body
  heights across a 1.7-unit footprint against visible geometry and collision
  guides; steps below .65 are allowed. This is not a
  swept avatar test and does not prove the entire floor is navigable.
- FBX round trip preserved all 84 mesh objects and matched authored
  bounds within .001 design unit.
- Individual meshes have no non-manifold edges and stay below 20,000 triangles.
  Trim intersections and intentional overlaps are not a zero-coplanar audit.

## Import contract for Fable

1. Authoring is Blender X across, Y inward, Z up. Export and companion use
   Roblox **(-x, z, y)**. Front faces -Z; Root is at ground level on the
   structural front-wall plane. Numeric units are intended as studs.
2. Verify Studio's FBX import scale against the bounds above. Keep all imported
   objects in their original relative positions. Align the companion using
   the same origin; do not separately centre files by their bounding boxes.
3. Set visual parts anchored, CanCollide=false, SmoothPlastic. Match material
   names to the sRGB palette in `geometry-report.json` and approved Theme
   colours. No texture uploads or wood/metal materials are required.
4. Place Root using HOUSE_FRONT_LINE. Validate the entire footprint, including
   negative-Z stairs/open door, against live plots and lawn/robbery areas.
5. Keep the collision guides static. Validate walking, jumping, stairs, rail
   corners, camera comfort and pursuit with actual desktop/mobile avatars.
   These boxes are drafts and may need adjustment after those tests.
6. Trophy attachment names are Featured, Shelf_1..4, Wall, Record,
   Plaque_Legacy and Door_Exit. They mark placement; actual awarded displays
   are not baked in. Full Decor models need purpose-sized variants or
   selected display pieces, not blind scaling. Wall/plaque orientation and
   actual trophy clearance must be set during integration.

Animation: None authored; Epic. Decorative drips can be wired separately if desired.
All Legendary house animation specifications remain in
`assets/design/phase-4b/fantasy-v3/ANIMATION-HANDOFF.md`.

## Rebuild

From the repository root:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 4 --python blender/houses/build_slime.py
python blender/houses/package_assets.py slime
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 4 --python blender/houses/verify_assets.py -- slime
python blender/houses/build_review.py
```

The source does not modify runtime scripts or upload meshes. Studio scale,
camera, mobile navigation, full collision and performance checks remain pending.
