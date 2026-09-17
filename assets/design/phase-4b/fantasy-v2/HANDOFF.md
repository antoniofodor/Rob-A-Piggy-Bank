# Fantasy house concepts — first pass, September 16

Sources: `docs/HOUSE-TIER-BRIEF.md`, B3 in `docs/BRIEFS-FOR-GPT.md`,
and the user's latest walk-in interior direction.

## What changed

**Latest user revision:** Gingerbread Manor is seasonal and excluded from
the current permanent catalogue. This pass proposes **Raven's Rest** at its
8M Epic slot: two floors in a raven-shaped charcoal/jet-black house.
`raven` is a proposed ID for Fable to align with the registry, not a saved
data rename. Reserve `candy` for future seasonal content; do not silently
give that ID a raven appearance. No runtime registry is changed here.

Gloop House must be slime throughout: lime-green walls outside AND inside,
dark-green fat drips/window frames, oversized wall lobes and a plum door.
It must not read as cream masonry under a green roof.

Fable's original fantasy IDs were `mushroom`, `treehouse`, `slime`, `candy`, `crystal`,
`galleon`, `dragon`, `skyisland`, `goldenpig`. These replace the previous
provisional nine additions at the same prices. Existing nine IDs are unchanged.
No saved data migration or runtime registry is changed by this visual pass.

Earlier exterior concepts and the previous shop demo's new-house IDs are
historical references. Do not wire `gardenbungalow`, `coastalvilla`,
`hilltopmansion`, `sunsetvilla`, `emeraldchateau`, `royalobservatory`,
`skylinepenthouse`, `imperialestate` or `celestialcitadel` from that demo.
B1's card geometry, states, filters and affordability presentation still apply.

## Started here

- One nine-house lineup for silhouette review, approximately to common scale.
- Toadstool Cottage exterior/front/interior concept sheet.
- Treehouse exterior/front/deck concept sheet with physical ground access.
- `catalogue.json`: all nine IDs, prices, target envelopes, accessible floors,
  interior direction, drive treatment and draft blurbs.
- `prompts.json`: exact prompts; generated with the built-in image tool.

These are drafts for visual selection, not final model approval. Part counts
and measured footprints are explicitly null. An image's stairs, dimensions
or cutaway are not evidence that the corresponding Roblox model works.
The latest revision adds individual Raven's Rest and Gloop House sheets,
plus `fantasy-lineup-v2.png`. Their prompts are in `revision-prompts.json`.
The original lineup containing gingerbread is superseded. Crystal, galleon,
dragon, sky islands and golden pig have overview concepts only.

## Walk-in interior precedence

The updated documents still mention a reserved-region/shared trophy room.
The user's newer instruction is real interiors in the actual street houses,
with size/condition and floors varying by house. That instruction controls
this pass. Cozy/classic/modern/royal are finish families, not teleport targets.
There is no fallback room spawned elsewhere. Any fallback must fit the actual
house shell. Trophies remain the same saved collection in every home.

The treehouse needs a normal route from the ground to its door. A rope ladder
alone is not the walk-right-in experience requested. Use a continuous stair
with a landing and guardrails; retain the rope ladder/pulley as set dressing.
Floating islands likewise need grounded access. Keep load-bearing floors,
stairs and bridges stationary; any later decorative movement must not move
the walkable structure out from under an avatar.

## First geometry pass after visual selection

### mushroom

Target complete envelope: 26 W × 24 D × 14 H, including cap and small mushrooms.
One enclosed floor. Prototype a clear central route and display wall before
roof detail. Target doorway clear width 5 and height 8; ceiling clearance
at least 9 in the usable centre (design targets, not engine guarantees).
Fit the camera using the game's actual avatar and camera settings.
The doorway is a true void in the stalk. Raised cap spots must intersect
the cap slightly without exposed coincident faces. Ground trim is a ring.
Start with a cozy trophy alcove, short shelf and compact record board/book.

### treehouse

Target complete envelope: 38 W × 34 D × 30 H, including canopy, platforms,
stairs, bridge and pulley. Main deck around Y=10; one enclosed cabin floor.
Reserve a 5-stud clear stair width, a landing at least as deep as the stair
width, and 8-stud clearance above the walking route. Actual treads/rise and
camera clearance must be checked with the game's avatar before detailing.
Canopy must not intersect the cabin, stairs or collection-camera view.
The bridge reaches a small viewing deck; avoid implying another whole house.
Keep a clear interior loop, timber display shelf and modest feature trophy.

Both: author model pivot at ground level on the structural front-wall plane;
front faces -Z, interior extends +Z. Physical thresholds can be elevated.
Measure any access projection toward -Z separately: front-pinning is not
permission to occupy lawn slots. Export structural and complete bounds,
including stairs/canopy, before acceptance. Proposed width/depth values do
not certify front clearance in a real plot.

Use the existing semantic attachments: `Featured`, `Shelf_1..Shelf_N`,
`Wall`, `Record`, `Plaque_Legacy`, `Door_Exit`. Final N, positions and
orientations follow measured floorplans; none are fabricated here.

## Palette / rendering

SmoothPlastic structural geometry; no woodgrain or masonry textures.
Suggested new Theme tokens (proposals for Fable to centralise):

| Token | Proposed RGB | Use |
| --- | --- | --- |
| HOUSE.MUSHROOM_CAP | 151, 46, 60 | Deep red cap |
| HOUSE.MUSHROOM_STALK | 237, 218, 179 | Cream walls and raised spots |
| HOUSE.TIMBER | 111, 76, 46 | Treehouse structure |
| HOUSE.TIMBER_DARK | 68, 47, 34 | Joinery and recesses |
| HOUSE.LEAF | 84, 138, 72 | Existing Decor leaf reference; reconcile with world oak |
| HOUSE.RAVEN_BLACK | 22, 24, 30 | Wing roof and deepest black planes |
| HOUSE.RAVEN_CHARCOAL | 35, 37, 44 | Black walls |
| HOUSE.RAVEN_GRAPHITE | 57, 60, 69 | Readable edges and opening frames |

Golden Piggy should use existing Theme.GOLD (255,203,61) and GOLD_DEEP
(227,138,30). Slime should match the existing candy-garden base reference
(126,222,78). Generated colours are approximate; final assets use tokens.

No animated effects are authored in this pass. The brief's HouseFX requests
need reconciliation with the user's earlier effects restriction before
implementation, particularly the giant piggy-house shimmer. Static concept
lighting does not author a ParticleEmitter, Light or runtime animation.

## Concept review limitations

The individual sheets govern design details ahead of the overview. The
generated lineup is not accurately to common scale: Raven's Rest reads
taller than its 26-stud target, and the overview adds a small eye-like dot
that should be omitted from the final model. It also retains a masonry
chimney on Gloop; use the green blob chimney from the individual sheet.
The actual common-scale model study must use the numeric height targets.

The individual Gloop sheet meets the requested all-green exterior/interior
direction. Its specular shine is illustrative: use flat-colour SmoothPlastic,
not reflective textures. Raven's warm upper windows in the concept must be
made unlit in the final exterior per the brief. The treehouse's side-platform
support differs between views; resolve it as part of the same oak/support
system, within the complete canopy/platform envelope. Concept cutaways do
not replace measured floorplans, stairs or part-count checks.

## Build route and next batch

Prefer simple reusable visual geometry modules or exported models; runtime
House construction/integration remains Fable's area. GPT can create asset
tooling/model hierarchies after selection. Target approximately 200 parts,
but count the whole walk-in model, furniture and displayed trophies; do not
treat a 200-part exterior plus unlimited interior as meeting the budget.
No count is promised until geometry exists.

Next concepts: crystal; then galleon, dragon, skyisland and
goldenpig. Price accessibility is Fable's economy work, not an art blocker.
Optional existing-house re-themes are deferred as the brief requests.
