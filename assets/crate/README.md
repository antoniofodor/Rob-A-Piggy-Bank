# AcornStorageCrate

Chunky open wooden storage crate with three horizontal boards per wall, a solid
0.25-unit floor, corner posts, a thicker rim, and a tan/brown Acorn emblem.

## Files

- `AcornStorageCrate.blend`: editable source; packed texture; separate presentation collection.
- `AcornStorageCrate.glb`: game model only, with the texture embedded.
- `AcornStorageCrate_Atlas.png`: 512×512 flat-colour base-colour atlas.
- `AcornStorageCrate-preview.png`: three-quarter preview.
- `AcornStorageCrate-report.json`: geometry and export measurements.

## Import

Import the GLB at scale 1. Target dimensions are **3.6 wide × 2.8 deep × 1.9 tall**
(Roblox XYZ: **3.6, 1.9, 2.8**). Origin is at the bottom centre. Front faces Blender
−Y, or glTF/Roblox +Z. Root is `AcornStorageCrate`; child meshes are `CrateBody`,
`CornerPosts`, `TopRim`, and `AcornEmblem`. All transforms are applied.

**966 triangles**, one matte material, flat shading, one atlas. No lid, handles,
text, or Acorns inside. Small disconnected solid components are intentional
wood joinery; the emblem graphic uses flat surface polygons over a solid badge.

For Roblox collision, use simple floor/wall boxes or a separate invisible
collider; a single bounding-box collider would close off the hollow interior.

## Rebuild and validate

From the project root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b -t 4 --python blender/crate/build_crate.py
python3 blender/crate/validate_crate.py
```

The builder only writes this asset's outputs. Cameras, lighting, and backdrop
are excluded from the GLB. No gameplay files or Studio instances are changed.

## Runtime integration (September 16)

Imported `Workspace.AcornStorageCrate` is now the residential storage prop.
`AcornStorageCrate.json` records the four uploaded IDs and bottom-relative
measurements; `AcornStorageCrate.rbxmx` reconstructs the imported assembly.
Measured emblem faces local −Z in Studio; plot rotation applies to all parts.
`Config.ACORN_STORAGE_MESH` drives the runtime builder with a white tint and
shared atlas. Meshes prewarm once, then clone into each residential plot.
The invisible `Storage` floor retains the existing raid/drop-off/fill anchor.
All decorative parts are non-colliding. A complete wooden blockout remains
available if mesh loading fails. The woven AcornBasket remains the carried prop.
