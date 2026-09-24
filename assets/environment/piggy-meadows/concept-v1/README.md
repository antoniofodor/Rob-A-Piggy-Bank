# Piggy Meadows — concept v1

Created 2026-09-23 from the live Rob A Piggy Bank map and the request to improve
the piggy roaming areas with varied rocks, flowers, bushes, ponds and a waterfall.
These are concept images; the meshes and map changes have not been implemented.

- [Environment concept](meadow-concept.png)
- [Reusable asset kit](asset-kit.png)
- [Environment prompt](prompt.txt)
- [Asset-kit prompt](asset-kit-prompt.txt)

Both images were generated using the built-in image_gen tool. The environment
used a live Studio screenshot as its layout/style reference; the asset kit used
the environment concept as its style reference. Exact prompts are saved above.

## Art direction

Friendly, softly faceted forms, warm-grey rocks with moss accents, rich green
foliage, and small bright flower groups. Preserve the street, player plots,
grove trees and terraced valley walls. Upgrade the grass bands behind the plots.
The images show a visual direction, not a surveyed placement plan or exact scale.

Use three recurring compositions: open wildflower clearings, irregular lily
ponds, and a waterfall nook against the outer wall. Start with one waterfall
landmark. Vary the planting and rock arrangements on the opposite side rather
than making identical mirrored gardens. Add one mossy log and occasional fern
and mushroom groups as smaller discoveries.

Keep at least 60% of each roaming band as usable open ground in implementation.
The illustration exaggerates planting density for readability; do not copy every
flower into the game. Keep flowers low beside open routes, tall shrubs beside
walls and trunks, and large rocks outside herd landing clearings. Test clearance
with the full ten-pig herd footprint, not only an individual pig or player.

## Initial reusable kit

| Family | Assets |
| --- | --- |
| Rocks | Rounded boulder, split boulder, flat slab, leaning wedge, unequal rock cluster, pebble scatter |
| Flowers | White daisies, violet bellflowers, pink cup flowers, golden flower spikes |
| Plants | Low leafy bush, tall shrub, flowering bush, fern patch |
| Water edges | Reeds/cattails, lily pads, waterlily, irregular shore stones |
| Landmarks/details | Mossy fallen log, mushroom/clover nook, modular cascade ledges |

Build separable moss/plant variants so every rock does not repeat the same green
patch. Use a shared small material palette and broad readable leaves, then make
small/medium/large clumps from the same kit. Flowers and fine foliage should not
obstruct movement; substantial rocks and logs need matching collision and herd
avoidance footprints. Avoid hard edges that trap players at the pond shore.

## Actual water requirement

All ponds, stream sections, the upper waterfall reservoir and plunge pool must
contain Roblox Terrain Water with genuine depth. The current Grassland builder
uses raised decorative pond surfaces over a solid ground Part; simply adding
water beneath that Part would conceal it and block entry. Local ground sections
must be rebuilt with basin openings and shaped earth/stone banks before filling
with water. Keep the rest of the map's ground and plot elevations stable.

Use irregular shorelines with mixed grass, reeds, exposed earth and occasional
rock groups instead of a full ring of repeated spheres. Size basins for Terrain's
4-stud voxel resolution. Keep a dry route around each pond and the short stream;
stepping stones should be optional, not the only way to reach piggies.

For the waterfall, use actual water volumes in its reservoirs and wetted channel,
with animated flow, foam and spray effects at the drop. Terrain water does not
provide a simulated flowing waterfall by itself; the falling appearance needs
VFX. Maintain the user's real-water requirement underneath the visual treatment,
and validate the cascade's water-volume shape in a small Studio prototype before
building the full landmark. Water appearance settings apply to the Terrain, so
coordinate them with other real-water features in the map.

Roblox references:
- [Terrain and water](https://create.roblox.com/docs/parts/terrain)
- [Waterfall VFX](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/create-waterfalls)

## Placement and implementation notes

The live Config gives the rear roaming bands as |z| = 158–255, between the plot
backs and valley walls. Preserve the existing entrance corridors, grove canopy
clearance and safe herd drop zones. Use the current deterministic placement scan
and explicit obstacle footprints rather than hand-placing everything against
coordinates from the concept image.

Likely integration points are Shared/Grassland.luau, Config.GRASSLAND,
NeighborhoodService's grove layout, ground construction in WorldService, and the
shared herd/ground vetoes. Extend avoidance to any substantial new rocks, logs,
shorelines and cascade footprint; current small decorative rocks are passable.
Validate water visibility/depth, players entering and leaving water, ten-pig
route clearance, landing-zone selection, camera sightlines and mobile rendering
cost before populating both sides.

Suggested build order: reusable rock/plant kit, one real-water pond prototype,
one complete meadow segment, small waterfall prototype, then populate the rest
using the validated spacing and asset reuse rules.
