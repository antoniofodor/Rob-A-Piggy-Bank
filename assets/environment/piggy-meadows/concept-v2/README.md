# Lower-poly meadow kit and world border — concept v2

User direction: simplify the meadow assets and redesign the entire map border,
including poorly joined pieces, overlapping layers and unattractive surrounding
structures. This revision is concept art only; no game code or geometry changed.

- [World border concept](world-border-concept.png)
- [Lower-poly asset kit](low-poly-asset-kit.png)
- [Exact border prompt](world-border-prompt.txt)
- [Exact asset-kit edit prompt](low-poly-kit-prompt.txt)

Generated with the built-in image_gen tool. The border uses live Studio views of
the current perimeter and map as references. The asset sheet edits the original
v1 sheet. Preserve v1 for comparison; v2 supersedes its detailed modeling style.

## Simplified art direction

Use broad flat-shaded planes and a shared solid-color palette. Rocks have a few
large faces and simple moss patches. Bushes use a few uneven foliage masses.
Flowers have fewer stems, chunky petals and broad leaves. Logs have a low-sided
trunk with minimal bark detail. Preserve distinctive silhouettes and variation.
These images illustrate the desired complexity; they are not measured mesh
triangle counts or production meshes.

## Whole-map border proposal

Preserve the current playable footprint, street, plot placement, rear herd lanes
and two tunnel approaches. Round the visual border's corners outside those
clearances. All four sides should form one coherent landscape.

| Layer | Proposed shape | Visual role |
| --- | --- | --- |
| Inner cliff | Connected faceted escarpment, broad height changes, an integrated grass edge and occasional sloped rock feet | Define the playable boundary cleanly |
| Grassy slopes | Continuous rolling terrain behind the cliff, sparse groups of chunky trees | Connect the foreground cliff to the wider landscape |
| Distant ridge | Broad asymmetric peaks and saddles, subdued colors, fewer silhouette changes | Add depth without overpowering the village |

The border board includes close views of a joined corner and tunnel transition,
plus a profile showing the order and relationship of the landscape layers.

Avoid the current repeated grass-capped rectangular slabs and overlapping corner
tops. Do not substitute regular pyramids, stacked blocks or evenly spaced peaks.
Keep a continuous ground mass under all landscape layers so there are no sky gaps
or exposed shelf cuts from supported gameplay cameras. Soft distance haze may
help separate the ridge, but must not conceal geometry defects.

Use one modest waterfall as a break in the inner cliff, feeding a recessed pool
beside the meadow. Retain the real-water requirement from v1 for ponds, channels,
the upper reservoir and plunge pool, with added flow/spray VFX for the falling
appearance. Preserve dry routes and herd landing clearings.

## Construction direction for a later implementation

The current border and horizon builders are in
`src/ServerScriptService/Services/NeighborhoodService.luau`: `buildValley`,
`ringWalk`, `landSegment`, `horizonColumn` and `buildHorizon`.
The current outer scenery uses separate apron, foothill, shelf and range rings;
the concept proposes replacing their visible form with the three-layer landscape
above. The live corner view shows broad rectangular tops crossing one another.
This was a visual/code inspection, not a full geometry intersection audit.

Build the visible cliff and grass boundary from shared perimeter vertices or
modules with matching edge profiles. Give each exposed surface one owner.
Use dedicated turns and corner pieces, height-transition pieces, and a tunnel
shoulder/arch assembly. Do not let independently generated side runs both own
the same corner. Small hidden joins can overlap inside the terrain; exposed
coplanar surfaces and cap plates must not overlap.

Suggested module families:
- Three straight cliff silhouettes with matching end profiles.
- Low/high transition and sloped-foot variants.
- Broad chamfered corner assembled from two or three angled facets.
- Tunnel portal with matching shoulders and continuous ground above.
- Waterfall notch connecting to the same cliff profile.
- Broad slope patches and a small set of distant ridge silhouettes.

Derive placement from Config.GROUND_SIZE and the existing playable clearances.
Use a deterministic shared boundary layout; avoid fixing seams with independent
random height jitter. Keep collision continuous and the visible boundary matched
to it. Check all four sides and corners, road openings, cliff feet, the maximum
normal camera orbit, elevated cameras supported by gameplay, and herd routes.
Concept art is not evidence that those geometric checks have passed.
