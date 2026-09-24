# Piggy Meadows and connected world border

Built, uploaded and integrated into the Rojo project on 2026-09-23. Assets are
approved; the game itself has not been published by this task.

## Current layout

- Two large ponds replace the six small decorative ponds. Nominal diameters:
  52 studs on the negative-Z side and 64 studs in the waterfall basin. Their
  outlines are irregular and slightly compressed along Z.
- A 24-stud-wide waterfall feeds the larger basin through a short, broad outlet.
  Both ponds, the upper reservoir and the fall contain real Roblox Terrain water.
  Pond centers have six studs of water above their terrain beds.
- Nineteen reusable meadow assets: six rock shapes/groups, four flowers, three
  bushes, fern, mushrooms, fallen log, reeds, lily and cascade ledge.
- Twelve connected border chunks share corner vertices. Faceted cliffs lead to
  broad grass shoulders and distant ridges. Hidden wall collisions preserve
  both tunnel openings.
- Three shoreline meshes bridge the slab openings to irregular water edges.
  Their normals face upward. Visual banks do not collide; merged dry-bank
  supports prevent Roblox's convex collision hull from covering the water.

The 34 unique templates contain 5,136 triangles total, before instance reuse.
One small palette texture is shared across the kit.

## Approved Roblox packages

| Package | Model asset ID |
| --- | --- |
| Meadow props | 91341780443451 |
| Connected border | 104348945801853 |
| Wide shorelines, corrected normals | 97145432719670 |

`roblox-uploads.json` records current hashes, operations, moderation and superseded
shore packages. `mesh-import.json` records all current mesh IDs and measured
import bounds. Palette: `70405732448969`; the matte finish reuses the project's
existing white roughness map `105908452608029`.

## Source and integration

- `meadows-and-border.blend`, `meadow.fbx`, `border.fbx`: reusable kit and border.
- `shorelines.blend`, `shore-wide-v2.fbx`: current large basin banks.
- `kit-preview.png`: Blender contact sheet of the reusable kit.
- `catalog.json`: canonical bounds, triangles, export hashes and shared boundary.
- `shore-layout.json`: authored bank layout; the small layout is kept separately
  only as history.
- `src/ServerStorage/MeadowTemplates.rbxmx`: imported templates used by Rojo.
- `Shared/MeadowPlan`: current water dimensions and grove exclusion zones.
- `Shared/MeadowBuilder`: placement, obstacle footprints, waterfall and border.
- `Shared/MeadowWater`: owned voxel regions, real water and ground partitioning.
- `Shared/MeadowShore`: visual banks, dry footing and changed-layout fallback.

For a geometry revision, run Blender background scripts in order:
`blender/environment/build_meadows.py`, then `build_shores.py` (the first resets
the catalog). Canonical coordinates are Roblox studs; FBX export uses 0.01 scale.
Archive the changed package receipt before an intentional replacement upload.
`python tools/upload_meadows.py` validates without uploading; `--go` uploads and
resumes saved operations. Capture the returned model's MeshPart IDs, sizes and
positions into `mesh-import.json`, then run `python tools/finalize_meadows.py`.
Finalization checks dimensions and import handedness before writing templates.

Changing `MeadowPlan` requires rebaking the bank cache for a compact production
build. A triangle-bank fallback covers layout changes until that is done.

## Verification

`studio-validation.json` records 843 passing live checks: actual pond water,
accessible water surfaces, depth, tree clearance, bounded transforms, meadow
budget, all asset families, continuous boundary collisions, open tunnels,
nonoverlapping ground sections and no sampled ground holes. The running build
has 345 meadow parts (272 meshes), 114 border parts and seven ground sections.
Both ponds, the waterfall and joined border corners were also visually reviewed.

Luau compilation and Rojo place build pass. The tree suite passes 6,313 checks
with the real meadow reservation plan loaded. The grassland suite passes 3,185
checks but exercises the legacy missing-kit fallback, not the Terrain build.
The existing herd suite still fails its spawn-interval/bore-rate assertion;
this task did not change those herd settings. Swimming and mobile frame rate
have not been measured with a player test.

The waterfall uses Roblox's documented [Beam texture wrapping](https://create.roblox.com/docs/reference/engine/classes/Beam/TextureMode)
so texture length is measured in studs and the flow appears as long streaks.
