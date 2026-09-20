# Scenery trees · September 18, 2026

Two new ornamental tree models replace the map's decorative trees:

- **Broadleaf:** faceted foliage clusters, visible forked branches and a flared
  trunk base. All 24 street trees and 22 grove trees use this model.
- **Evergreen:** overlapping scalloped foliage tiers and a tapered silhouette.
  Eight trees in the background grove use this model.

The Acorn tree is unchanged. Its geometry, configuration, growth, shaking,
baskets and upgrade logic were not edited.

## Files

- `src/ServerStorage/SceneryTreeTemplates/*.rbxmx` — Rojo-synced templates with
  mesh IDs, matte surfaces, authored dimensions, and render settings.
- `src/ServerScriptService/Services/SceneryTrees.luau` — template normalization,
  deterministic placement variation, and species selection.
- `manifest.json` — generated asset references and original mesh transforms.
- `street-review.png` — actual Studio playtest screenshot.

The generator was requested to stay within 2,200 triangles for the broadleaf
and 1,500 for the evergreen; these are requested budgets, not measured counts.
The runtime uses 154 MeshParts across all 54 trees. Templates are cloned locally;
there are no per-tree asset-insertion requests.

## Validation

Both Luau modules compile and the Rojo project builds. Studio runtime checks
confirmed 54 trees, 24 on the verge and 30 in the grove, with eight evergreens.
All tree parts are anchored with collision, touch, and query disabled.
Measured conservative world-space bounding-box clearances:

- Driveway: **2.79 studs** minimum.
- Shop/board band: **1.09 studs** minimum.
- Back fence: **9.14 studs** minimum.
- Ground seating error: less than **0.000002 studs**.

`AcornTree.luau`, `TreeService.luau`, and `Config.luau` retain their pre-edit
SHA-256 hashes. The game has not been published.

## Matte revision

Removed the generated color textures and their painted highlights. Both species
use a nonmetallic SurfaceAppearance with a constant white roughness map, muted
leaf colors (broadleaf 96/150/73, evergreen 67/120/90), and warm brown bark
(117/82/57). Reflectance is zero. Template-authored maps avoid protected property
writes during gameplay; the runtime only varies the surface tint.
The original generated texture IDs in the manifest are provenance, not active textures.
Geometry, placement, clearance envelopes, and the Acorn tree are unchanged.
