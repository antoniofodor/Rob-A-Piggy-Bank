# Session handoff — 2026-09-16

## Latest Storm Wolf scale audit — existing correction verified

User reported Storm Wolf appearing smaller and asked whether Blender needs a
fix. Found an existing `Config.LEGENDARY_SCALE.stormwolf` correction of 12/10.5,
applied by `LegendaryModel` to mesh sizes, positions and rig scale about the
ground/vault pivot. Both running Client and Server have this configuration.
Temporary unparented Studio models built with the real published meshes verified
full-size Storm Wolf Body width 12.174743 vs Dragon 12, and miniature widths
2.434949 vs 2.4. These temporary models were destroyed afterwards.

No additional scale change was made: applying another correction would double
the existing fix. Raw exported Body width is 10.6529; the FBX/Blender asset
bypasses runtime correction when viewed directly. No equipped legendary was
found in Workspace/PlayerGui during inspection. Asked the user whether the
reported view was in-game/shop or a raw Studio/Blender import; answer pending.
Details: `assets/skins/animal/legendary/stormwolf/SCALE-NOTES.md`.

## Latest Rainbow Tiger refinement — fuller cheeks and under-snout hair

User clarified that the hair should still run alongside the snout, with roots
on the cheeks, and that additional hair should grow underneath it. The inner
cheek patch must be as full as the reference. This supersedes the previous
blank-edge fit and the blanket rule that every root must be outside nose width.

The main facial layers now sit closer to the snout rim. Added two overlapping
locks per inner cheek (CheekFill_-1 / CheekFill_1), reusing the approved textured
study curves. Their roots stay on Body and their tips follow the snout edge.
Added three downward curved chin locks (BeardFur) anchored to the actual lower
surface of Snout by upward ray projection. These overlap the beard and follow
Root; cheek fills follow the existing Ruff_L/R bones. All use the approved
beard color and normal maps. The separate study remains unchanged.

Current package: `blender/pig/skins/rainbowtiger/legendary-v2-swept/`.
15 meshes / 82,580 triangles; every mesh remains below 20,000 triangles.
`beard-root-checks.json` distinguishes cheek and under-snout attachments.
The previous fit is backed up in `before-full-cheek-fill/` beside the package.
Final full-resolution front/hero/side views checked. Updated Blender, static
FBX, idle FBX, five views, ear detail, animation GIF and gallery/import handoff.
FBX round-trip geometry/UV/color/normal/weight checks passed. All 23 root anchors
pass their attachment rules; 40 animation states pass cheek-root clearance,
under-snout attachment, loop and rear-vault checks. The approved study is unchanged.
Studio integration is still pending.

## Latest Rainbow Tiger build — approved textured beard applied

The user approved the dense layered study, approved its flowing texture strokes,
and requested applying it to the pig. The full package in
`blender/pig/skins/rainbowtiger/legendary-v2-swept/` now uses those exact study
meshes and UVs on both cheeks and under the snout. Individual locks are positioned
and rotated to preserve their smooth fullness; lower locks overlap at the chin.
The previous full pig is preserved in `before-approved-beard/` next to the package.

`blender/pig/make/rainbowtiger_fit_beard.py` imports the study, fits its locks,
preserves UV winding on the mirrored side, and groups each side as CheekFur_-1
and CheekFur_1. These replace the previous cheek/BeardFur meshes and follow
Ruff_L/R. Both `beard-flow-color.png` and `beard-flow-normal.png` are included;
use them as ColorMap/NormalMap with white part tint. The original ears, coat,
eyes, tail, body, snout and feet remain intact.

Full model: 12 meshes / 66,788 triangles; each beard side is 18,048 triangles.
All meshes are closed and under 20,000 triangles each. Static FBX reimport checks
passed for bounds, triangle counts, weights, UVs, color maps and beard normal maps.
The idle FBX loop and 40 sampled animation states passed, including rear vault
clearance. Updated five full model renders, the ear close-up, motion GIF and
local gallery/import handoff. Final front/side views and a moving pose were
visually checked. The original pig and approved study files retain their hashes.
The model remains a Blender/FBX art package; Studio integration is pending.

Latest correction: user said the hairs should not stem from the snout.
Reanchored every lock to the actual Body cheek surface using ray projection;
all roots lie outside the Snout's full width, with a small buried attachment.
The longest lower locks now root on the jaw at x=+/-0.68 native, z=-0.45.
Pulled the beard back from the nose, lowered the bottom locks, and adjusted the
upper two layers outward so they remain visible on the cheeks. Curves, fullness,
UV strokes and existing bones are retained. `beard-root-checks.json` records
and validates all 16 cheek-root anchors. The fitting helper before this correction
is preserved as `before-approved-beard/fit-before-cheek-root-correction.py`.
Rebuilt the final Blender and both FBX files, refreshed all review images and
the local gallery, and passed the existing export/motion checks again. The idle
check now also verifies every beard root stays outside the snout width throughout
all 40 sampled states. Front, hero and side renders were visually reviewed.

## Rainbow Tiger study approval history (before fitting)

User clarified that the direction is acceptable, but lower strands look muddled.
The reference has short tufts branching near the top, followed by a few longer
curved locks descending along the face. Previous full-mane iterations still
missed the strand shape. A separate review study is now built in
`blender/pig/skins/rainbowtiger/beard-shape-study/` using
`blender/pig/make/build_rainbowtiger_beard_study.py`.

This study shapes the inner and outer outline of each lock directly rather than
using the active model's swept-tube profile. Seven visible strands layer over a
root patch; light neutral clay makes their smooth contours easy to judge. The
package contains a grouped beard render, one isolated-strand render, editable
Blender file, FBX, and closed-mesh report. It is a geometry review, not a new
charcoal color choice or a rigged replacement. The active pig exports below have
not been replaced. User approved the study's shapes ("perfect") and requested
only thicker strands. The study now has 16% more width and 60% more rounded
depth, preserving curve centerlines/endpoints and scaling depth spacing with
thickness to preserve layer order. Both renders were visually checked; all eight
meshes are closed, with 18,048 triangles total. Approved pre-thickening assets
are preserved in `beard-shape-study/approved-shape-v1/`.
Latest follow-up: user requested substantially thicker locks and gap-free
layering like the reference. The study now uses 2.05x original width and 2.70x
original depth, bringing the middle/lower layers upward to overlap and filling
the upper junction with a recessed root patch. Individual visible curve paths
are retained. The previous thickness pass is saved in `fullness-v2/`.
User then approved the dense overlapping study and requested textured strokes.
Added 1024px UV color and tangent normal maps (`beard-flow-color.png` and
`beard-flow-normal.png`) with fine curved lines following each strand. Packed
both maps into the Blender study and exported separate PNGs alongside the FBX.
Geometry/layering unchanged; UV wrap seam corrected. Group and isolated-lock
renders checked. The approved untextured build is saved in `approved-dense-v3/`.
Next: fit the accepted shapes to the pig and update its materials/rig/export
package. The thickness revision has not yet been installed on the full pig.

## Rainbow Tiger active build — approved option C

User approved building the swept-charcoal concept (C). New model package:
`blender/pig/skins/rainbowtiger/legendary-v2-swept/`.
Latest requested refinements implemented: the user supplied option A as the
precise striping reference and allowed flat markings. Replaced all raised stripe
shells with a clean 2048px UV coat and separate stripe-only emission texture.
There is one stripe inside and one outside each eye. The current cheek and beard
locks are widest through the middle and taper softly at both ends.
Ear roots were moved again after the final placement request: they now start
at the actual medial ear corner near x=+/-0.075 native units (previously +/-0.42),
where the ears meet the forehead, and fan up/outward. Final depth refinement:
lock centerlines are projected onto the actual inner-ear mesh, with shallow
relief so the fur rests along the ear instead of floating in front of it. Soft brows, bare feet, RGB eyes,
original pig anatomy and gradient tail remain. Old v1/clean-review preserved.
September 18 latest beard reference: user explicitly requested banana-shaped
locks, thickest through the middle, softly tapered at both ends, with a mix of
single-direction C-curves and double-bending S-curves flowing down the face.
This supersedes the earlier full-root profile and sideways original cheek fan.
All six upper cheek locks were rebuilt. Eleven lower locks overlap down the
face and into the central chin point. Narrow root caps tuck into the coat and
under neighbouring fuller middles. Stable relief cross-sections and an XZ bend
radius constraint prevent folded silhouettes at tight turns. Fine, low-contrast
strand shading replaces the coarse grooves. The charcoal palette is retained.
BeardFur stays on Root; upper cheek locks retain their Ruff_L/R bones. Model
awaits user review against the new close-up reference.
Latest feedback: tips remained too jagged and dramatic. Relaxed the hooked
centerlines, shortened projecting side tips, and moved the cheek endpoints clear
of the snout to prevent a cut-off appearance. A gentler taper, denser end sampling,
and a smooth curvature limit replace the abrupt thinning that created hooked
points. Width and depth taper together; geometric surface ribs are removed from
the facial locks while the fine strand color texture remains.
The user accepted that direction and requested fuller ear hairs. Ear tuft roots
are now about 53% thicker, with a gradual taper to a fine point and denser curve
sampling. Their original inner-corner anchors and inner-ear surface projection
are preserved. User then supplied the close-up reference and requested coverage
across the whole ear. Each inner ear now has four broad overlapping locks,
fanning from its medial roots toward the upper tip and lower outside corner.
Root widths are constrained at the medial rim to prevent forehead spillover.
The full ear fans and revised downward facial ruff are both in the current build.


Builder: `build_rainbowtiger_swept.py`; motion validation/render:
`render_rainbowtiger_preview.py -- --swept`; gallery:
`build_rainbowtiger_swept_gallery.py`. All in `blender/pig/make/`.
Static export checks: 13 meshes, 48,066 triangles, all manifold,
FBX geometry/weights/UVs/textures round-trip successfully. Coat, charcoal fur and tail color maps are embedded, with a separate stripe
emission mask supplied for runtime setup. Bone idle,
RGB eyes and stripe pulse are retained; material animation still needs Fable's
Roblox implementation. Animation/render validation passed for the softer
banana-shaped locks: scene/gallery hashes match, static and animated FBX checks
pass, and rear clearance passes in 40 sampled states.
A new actual-model ear
close-up is saved as `rainbowtiger-ear-detail.png`; its renderer is
`render_rainbowtiger_ear_detail.py`. Studio integration and live checks remain pending.
No runtime scripts or Studio assets modified during this build.

## Rainbow Tiger latest direction — softer brows and fur concepts

User liked the FIRST clean concept (`concept-v3-hairless.png`) but wants its
brows less angry. Requested multiple new fur concepts using that same build.
Generated v5 options in `assets/animals/legendary/rainbow-tiger-concept/`:
A minimal light cheek/ear tufts; B fuller cream tiger ruff; C compact swept
charcoal cheek fur. All have relaxed brows and a smooth rainbow tail tip.
Exact prompts: `prompts-v5-fur-options.json`. B's initial angry expression was
corrected; the saved B image has the soft expression. Fur selection is pending.
No model/runtime changes in this concept-only turn. The clean-review-v2 Blender
base remains available; legendary-v1 preserves the prior tail/model.

## Rainbow Tiger latest review — clean concept, September 17

User rejected protruding eyebrow geometry and all added fur except the tail,
then explicitly requested deleting all hair and generating a new concept.
Current concept: `assets/animals/legendary/rainbow-tiger-concept/concept-v4-clean-no-brows.png`.
Built-in imagegen; prompt saved beside it. Concept v3 still had brow lips and
was corrected in v4. V4 is hair-free with round glowing eyes, a black piggy body,
wraparound rainbow stripes, forehead markings and a bare pig tail. Review pending.

Actual Blender cleanup: `blender/pig/skins/rainbowtiger/clean-review-v2/` contains
`rainbowtiger-clean-review.blend`, matching FBX, actual model render and deletion
report. All brows and hair were removed from this working copy. Previous
`legendary-v1` package stays intact, including the tail design the user liked,
so it can be restored if requested. Unused ruff bones remain in the review rig.
The new generated concept is not the Blender render; no Studio changes made.

## Rainbow Tiger legendary model — September 17 (uncommitted)

Latest user direction: **black tiger, cool and somewhat aggressive**, superseding
previous deep plum. User also rejected repeating stripe bands and plate-like fur;
use the supplied concept's broad tapered stripes, flowing fuller mane, ear fur and
tail hair. RGB eyes remain required. Current revision keeps the original piggy
body/snout/feet/openings, uses charcoal coat and lowered brows, silver swept ruff,
inner-ear tufts, cuffs around all four feet, and a continuous UV-textured
silver-to-rainbow tail plume (no colored droplet pieces). Added paired tapered
forehead marks between the eyes. Seven individually outlined mirrored
rainbow stripe patches are projected onto the body and now extend around the
rear hemisphere. Foot tufts were revised to connected dark layered ankle cuffs
with a short silver under-fringe, following the reference. Both eyes cycle RGB.
This model revision is for review, not yet approved by the user or imported.

Package: `blender/pig/skins/rainbowtiger/legendary-v1/`. Main import is
`rainbowtiger-complete.fbx`; `rainbowtiger-idle.fbx` is the matching four-second
bone animation. The Blender scene also previews emission pulses over the stripe
groups. **Material pulse does not transfer as an FBX animation**; Fable's exact
group/timing/color handoff is `animation-handoff.json` plus package README.
No runtime, crate, economy or uploads were changed. Live Studio integration,
vault seating across lock tiers, daylight glow, held/shop and mobile checks remain.

Rebuild model with `blender/pig/make/build_rainbowtiger_legendary.py`, validate
and render motion with `render_rainbowtiger_preview.py` (both inside Blender),
then run `build_rainbowtiger_gallery.py` in Python for the GIF/gallery/handoff.
Geometry: 41 meshes / 44,326 triangles, all manifold and below 20k per mesh;
static FBX reimport preserves count, weights, triangles and bounds. Idle checks
cover the imported four-bone loop, stationary root and moving rear clearance.
Latest wraparound/cuff revision passes all of these checks. Review gallery,
40-frame animation GIF, embedded tail gradient and Fable handoff are generated.
Art review and Studio integration remain pending.
Old Rainbow Tiger sources/maps and the shared pig master are preserved.

## Walk-in house revisions — September 17 (uncommitted)

All 18 permanent houses now have new Blender revisions with an accessible main
floor, empty walls/floors/ceilings, separate collision boxes and automatic swing
door geometry. Treehouse and Gloop are revision 3; the others are revision 2.
Original revisions are preserved. Seasonal Gingerbread remains excluded.
Start at [the walk-in gallery](assets/houses/walk-in.html); every package has
an FBX and `prepare-in-studio.luau` import helper with an Undo recording.

The approved Studio exterior scale factors from `build_house_runtime.py` are
baked into these new sources. The generator detects `geometry.walkIn` and uses
display scale 1.0, so room/collider/door dimensions are not multiplied twice.
This follows [the new interior brief](docs/HOUSE-INTERIOR-BRIEF.md): minimum
7-stud door, 8-stud ceiling, 12.3-stud display wall, named floor/side colliders,
and an empty `Wall` mount with explicit facing. Upper exterior storeys are not
additional accessible rooms in this pass.

Fishbowl glass material overrides now reach the FBX manifest and runtime
generator: dome transparency 0.82, bubbles 0.62, opaque inner pod. A fresh Studio
import also needs its package's preparation helper to apply Roblox properties.
`HouseDoorAnimator.client.luau` opens non-colliding leaves near players, using
separate pivot markers. The entrance collision always stays open.

Build with `assets/houses/tools/build_walkin_batch.py`; refresh handoffs with
`build_walkin_handoff.py`. Offline acceptance uses `check_walkin_packages.py`
(geometry, 40 clearance samples per house, colliders, FBX round trips),
`tests/check_walkin_runtime.py` (scale/glass/door regression), Luau compilation,
and a Rojo build. Final visual review corrected overlapping tunnel cut faces.
Final results: all 18 packages / 720 clearance probes pass, runtime fixture
passes, client script and 18 Studio helpers compile, Rojo builds, and 820
house links resolve. All 188 original binary assets remain unchanged.

**Integration pending:** these new meshes have not been uploaded/imported into
Studio or installed into the live catalogue templates. Import each new FBX,
record fresh mesh IDs (do not reuse an old revision's `studio-import.json`),
then regenerate its runtime template. Live avatar/camera, door sweep, plot/fence
clearance and multiplayer/mobile checks remain pending. Keep Fable's ongoing
runtime work and approved exterior sizes intact.

## House asset organization — September 17 (uncommitted)

All house art, models, concepts, plans and tools now live under **assets/houses/**.
Start with [the house index](assets/houses/README.md) or [the full gallery](assets/houses/index.html).
Model folders and filenames use readable design names: `fishbowl-house-v1/fishbowl-house.blend`
and `fishbowl-house-roblox.fbx` replace the former `modern` asset names; Gloop,
Ice Palace and the other houses follow the same pattern. Saved-game IDs and Rojo
runtime template names remain unchanged. `assets/houses/tools/house_paths.py`
maps stable IDs to asset names; builder/exporter commands still take stable IDs.

House-specific tools moved to `assets/houses/tools/`, house plans to `assets/houses/docs/`,
and the phase-4b visual package to `assets/houses/design/`. Updated references,
relative links, OBJ material-library names and generator paths. FBX files remain
generated, Git-ignored exports; rebuild them from Blender sources on another machine.

Verified all 18 permanent source/export pairs, all 527 local gallery/document
links, and unchanged hashes for 188 binary assets. Python syntax checks and the
house wiring/room audits pass. This is file organization, not additional Studio
integration. The already-missing Treehouse v1 package was not recreated; its dead
preview links were removed. Existing unrelated work is preserved.

## Smooth shop-sign joins — September 17 (uncommitted)

Replaced the guessed overlap between the rounded rectangle and rotated square
with matching 16px radii and coincident corner-arc centres. Compensates the
square's side length for the rounding lost at 45 degrees. Inner pieces use
13px radii and a true 3px inset, so the join is tangent and the border does not
fade. Same sign/icon positioning and category colours. Compilation, Rojo build
and 209 shop UI checks pass. Verified the smooth shoulders and rounded tip in
a fresh Studio playtest at 667x375; shop left open for review.

## Consistent shop-sign outline — September 17 (uncommitted)

Fixed the sign's gold fill reaching the outer body's right edge, which erased
the border around its curved shoulder. Fill now has a true 3px inset on all
four edges; the rotated tip's inner square also shrinks by exactly 6px in side
length. Applies to every category colour. Luau compilation, Rojo build and
209 shop UI checks pass. Confirmed the continuous border live in Studio's
667x375 phone preview; left the shop open for review.

## Raised shop sign and generated basket — September 17 (uncommitted)

User asked for a smoother sign protruding farther outside the modal and a
replacement for the Studio-drawn pig. ShopRevamp now raises the sign 12px and
overhangs left by 8px, rounds the angled tip, and slightly increases its height.
Generated a transparent pink basket with the built-in image tool, saved source
and exact prompt in assets/shop-ui/shop-basket-v3.*, imported via Studio as
image 84889322242631 and connected its ImageLabel in ShopRevamp. No native pig
fallback. Basket slightly overlaps the sign's top edge. Build and 209 UI checks
pass. Verified the imported basket, smooth raised sign and Home submenu live
at 667x375. Increased the panel's top allowance from 40 to 58px so Roblox's
top-left controls do not cover the basket handle; the panel's bottom stays put.
Updated the responsive test case to the resulting 627x287 panel. Short upgrade
details use the group-tab row for stats (Back restores group selection); short
crate collections hide the scroll hint and tighten odds rows to keep buying
and scrolling usable. All 209 checks pass at the new size. These two detail
adjustments are geometry-tested; their final live visual check is pending.

## Angled shop sign and floating close controls — September 17 (uncommitted)

Replaced the shop's rounded header pill with a native outlined sign with an
angled right end and a small top-left overhang. Keeps the piggy emblem and
category colours; heading width reserves space for the point. Theme.floatClose
now places existing X buttons across shop/submenus, bag, settings, daily rewards
and ride picker over the upper-right edge, with at least 44px tap targets.
Daily rewards and rides use the shared red/cream close styling. Compilation,
Rojo build and 209 shop UI checks pass. Restarted Studio in the iPhone 7
667x375 preview and confirmed the daily-rewards X protrudes without clipping.
Active user input blocked dismissing that modal; shop sign and other menus
still need live visual review.

## Compact shop submenus — September 17 (uncommitted)

Applied compact sizing to the catalogues as requested. ShopCatalogueLayout
reflows Home/Companions/Rides/Supplies/style cards to 144px tall on mobile,
with more columns and directly repositioned text/preview rows instead of
shrinking the whole card. Small name-picker chips retain their original height.
Home & Garden is now Home; empty home section headings and their grids hide
automatically as stock changes. Upgrade choices and crate collection tiles
also use 144px mobile cards. Crate purchase cards shrink from 350 to 306px,
keeping their odds, combine and purchase controls. Short-phone crate contents
place the odds beside the items, with purchase below the odds. Shared header
currency icon sizing from the previous change already applies to all submenus.
Luau compilation, Rojo build and 70 buyback checks pass. See shopui suite for
responsive geometry and ownership/purchase checks. Fresh Studio visual review
of all submenus remains pending.

## Clean shop and smaller mobile cards — September 17 (uncommitted)

Latest user correction supersedes the storefront trim below: removed awning,
side posts and sill entirely. Kept piggy emblem, HUD backpack and removed footer.
Mobile landscape now uses three columns from 560px panel width, 8px gaps and
96–150px card heights instead of the old 152px minimum. Compact captions are
44px with 14px titles/11px descriptions; removed compact card arrow discs.
Balance icons now scale their entire drawings into padded 22–24px mobile
holders, with balance text positioned after the icon rather than a fixed 52px
indent. Desktop icons remain up to 34px. 160 UI checks, compilation and Rojo
build pass; this revision has not been visually verified in a fresh play test.

## Piggy storefront and HUD backpack — September 17 (uncommitted)

User replaced the shop's basket emblem with a piggy-bank/coin emblem and asked
for a storefront border. ShopRevamp now has a green/cream striped awning, slim
green side posts and a lower sill. Removed the Your Bag/Achievements footer and
the shop achievement view/updates; the category list uses the freed space.
HUD inventory now uses the former shop backpack, polished with a gold flap,
open handle, pink pocket and simple highlights, shared through ShopMarks.
155 revised UI checks, Luau compilation and Rojo build pass. Restarted Studio
and confirmed the new HUD backpack. Shop visual review is pending: Studio was
receiving user input and blocked opening the shop, so controls were left alone.

## Boost button placement — September 17 (uncommitted)

HUDWidgets places the 2× boost token as the fourth item in the left rail, below
Shop, using HUDLayout's menu size/gap at every viewport. Improved readability
with a flat gold face, 22px multiplier and 10px bold caption (previously 19/8px).
Stock badge, active countdown and BoostUse behavior remain. Luau compilation
and Rojo build pass; fresh-play visual check pending.

## Action buttons and compact ride picker — September 17 (uncommitted)

ActionButtons now uses distinct blue dodge, mint scooter and purple stealth-mask
symbols. RidePicker replaces the old ride tiles with owned-only named cards,
static 3D previews, speed bonuses, selected/put-away state and integrated styles.
Existing RideRequest/RideStance requests remain authoritative. Desktop selection
and phone opening/closing were checked in Studio. The last swipe-preservation
change still needs a live recheck; the user stopped Computer Use with Escape.

User then said the mobile menu was too large. Compact layout is now 330x138
(previously 477x189 on the 667x375 phone), about half the panel area. Cards are
94px wide; styles share the 32px title row and the instruction footer is hidden.
Desktop sizing stays unchanged. 159 UI checks, Luau compilation and Rojo build
pass. This smaller revision needs a fresh play session for visual verification.

## The two inert effects written, and everything verified in Play — September 18 (uncommitted)

**`sway` and `scale` now have branches in `HouseFX.step`**, so nothing authored
is inert any more. Both hinge at the part's TOP rather than its centre, which is
what each was asked for: the galleon's sail hangs from a yard arm, and the Gloop
House's handoff says in as many words "only scale hanging goo, anchored at its
top" -- a drip grown about its centre lifts off the roof by half of what it
gains. `Entry` gained `restSize`, read once at registration like the pose,
because a size re-read each frame accumulates the previous frame's growth.

THE SWAY HINGES AT THE PART'S TOP RATHER THAN THE AUTHORED POINT, and that is a
deliberate approximation with its cost measured: converting the Blender hinge
would mean carrying the import's frame into this file, and at two degrees an
error of `d` studs moves the part by `d * sin(2deg)` -- 0.035 studs per stud. On
a sail a few studs tall, under a tenth of a stud.

VERIFIED IN A REAL PLAY SESSION, and the first measurement was the wrong one.
Sampling colour across 203 tagged parts reported 77 "still" -- which is what a
COLOUR test says about effects that animate POSITION. Re-measured per kind over
one second, every one behaves as designed:

    beacon   2 parts  colour 2                      hue steady
    bob     55        moved 55
    chase   31        colour 31                     hue steady
    cycle   45        colour 45   hue drifted 45     by design: it sweeps
    orbit   11        moved 11
    pulse   46        colour 46                      hue steady
    scale    6        moved 6     resized 6          the new branch
    sway     8        moved 8                        the new branch

`pulse`, `chase` and `beacon` holding their hue is the half that matters: it is
what keeps the Ice Palace blue. Only `cycle` sweeps the wheel, which is why three
parts read as reddish in a single frame -- two mid-sweep and one sail that is
authored red.

Also confirmed live: 18 templates, no `[House] no ... template` warning, 107 FX
parts tagged across ten standing houses plus the shops' 16, and the trophy row on
Plot1 measuring 15.84 wide inside an 18.00 wall with 1.08 clear each side.

A PEER ADDED A STARTUP FIT AUDIT and it agrees with the arithmetic: "deepest
Fishbowl House at 55.0, widest The Golden Piggy at 62.1; tightest back-fence gap
5.0, side-fence gap 2.6". That is the check the houses needed and it now runs
every boot.

STILL NOT SEEN: the Toadstool Cottage's own trophy wall. No plot stands it, and
the sandbox cannot fire `AdminRequest` to place one, so the octagon fix rests on
the offline measurement (10.14 of wall, a row that fits exactly). It wants the
designer to stand that tier once.

Two duplicate templates reappeared when Rojo re-synced the treehouse and slime,
and were removed the same way. The double Rojo plugin is still installed.

## The FX faults audited across all 18, and a third one found — September 17 (uncommitted)

Asked to make sure the other houses did not carry the two faults from the
screenshot. Both are clean everywhere -- all 13 spec keys are real tier styles
with a `HOUSE_TEMPLATE` row, and all 95 rows carried `Hue` and `Sat`, none
near-grey, none past the flash ceiling. Checking the INVERSE gap is what found
the third:

**THE GLOOP HOUSE'S HANDOFF USES A DIFFERENT KEY, and reading only one shape
lost the whole house.** Sixteen handoffs carry `effects`; `gloop-house-v3`
carries `drips` -- same fields, plus `phaseSeconds` in absolute seconds where
`effects` uses a 0..1 `phase`. Its three roof meshes were named `HouseFX_*` and
covered by nothing at all. Now read, converted, and the spec is 98 meshes across
13 houses.

**AND THE GOO IS AUTHORED AS A SCALE, WHICH THE ANIMATOR CANNOT DO.** The block
says "only scale hanging goo, anchored at its top" with a `scaleZ` of [1, 1.045]
-- and `HouseFX.step`'s `pulse` drives BRIGHTNESS. Emitting `pulse` would have
made the drips GLOW, an effect nobody asked for, so they are emitted as `scale`:
data carried, no branch, reported every run. Same call `sway` already gets.

`check_house_fx.py` makes all four questions standing, because every one of
these three faults was silent -- no error, no warning, an effect that never ran.
It asks: is the spec keyed the way it is READ, does every row carry a colour,
is every authored FX mesh covered, and does every row name a mesh that exists.

PROVOKED RATHER THAN TRUSTED, which is the half that matters: each of the three
faults was reintroduced in a throwaway copy and the audit fired on all three --
keyed by id, a row stripped of its colour, and an uncovered mesh. A clean run on
a file I had just fixed proves nothing about the check.

Two effects remain inert by design and are printed on every run: the galleon's
`sway` and the Gloop House's three `scale` drips. Both want a branch in
`HouseFX.step`, which is a contained addition if the designer wants it.

## Three FX/trophy faults from one screenshot — September 17 (uncommitted)

**THE SPEC WAS KEYED BY ID AND READ BY STYLE, which silently dropped the two
biggest FX houses.** `build_house_fx.py` emitted `neontower` and `skycastle`;
`House.buildTemplateHouse` looks up `HouseFXSpec[tier.style]`, which is `tower`
and `castle`. So the Neon Tower's twenty effects and the Sky Castle's seventeen
went to nobody -- 37 of 95 -- with no warning, which is exactly the id/style trap
already written above `Config.HOUSE_TEMPLATE`. The generator now reads id->style
out of `Config.HOUSE_TIERS` rather than assuming, so it cannot drift again.

**EVERY LIT EFFECT WAS RED, AND THE ART WAS INNOCENT.** Every colour branch in
`HouseFX.step` builds its colour as `Color3.fromHSV(entry.hue, entry.sat, ...)`
and ignores the part's own colour -- and `Hue` defaults to 0, which is RED. The
Ice Palace's blue and the Thundercloud's were being overwritten every frame by a
default nobody had set. The spec now carries `Hue` and `Sat` derived from each
mesh's authored `colorRGB`: palace 0.60, thundercloud 0.71 and 0.58, tower 0.52.
60 of the 95 are blue or cyan and exactly one is genuinely red. NOTHING TO CHANGE
IN BLENDER -- the colours were right in the source the whole time.

**THE TOADSTOOL'S PANELS WERE MEASURED AGAINST THE WRONG WALLS.** `wallSpan`
takes the widest pair of colliders matching "side", which describes how wide the
ROOM is -- the same number as the wall in a rectangular room, which is why this
held for sixteen of eighteen houses. The Toadstool Cottage is an OCTAGON:
`SideWall_02` and `_06` sit at x +-12.75 while `Wall_04`, the wall the mount is
on, is 10.74 wide. The row came out 14.16 and ran a stud and a half past each end
into the angled segments either side -- the reported clipping, measured.

Clamped to the MINIMUM of the two, never swapped: the treehouse is the case that
refuses the obvious fix, its rear wall being 17.00 across the outside while its
side walls leave 15.60 between inner faces. Sixteen houses are unchanged to the
decimal.

AND `PANEL.min` HAD TO GIVE WAY, because on a wall too narrow the clamp does not
make a panel readable, it hangs it off the end: four 2.6-wide panels are 11.66
against the toadstool's 10.14 of usable wall. Below the floor the row is divided
instead -- 2.22 there, 15% under the preference. `PANEL.max` is a real ceiling
and stays clamped. Verified across every house at both 3 and 4 panels: all fit.

NOT verified in Play. Studio was in Play throughout, so none of this has been
seen; the running session was confirmed to hold neither `HouseFXSpec` nor the
18th template, which is why the earlier fixes appeared to do nothing.

## House names aligned, Gingerbread retired, authored FX finally driven — September 17 (uncommitted)

**The Gingerbread Manor is gone from the shop.** The row is DELETED rather than
emptied, which is the only shape a house retirement can take: a tier IS its
catalogue row and `ensureRow` draws a card for every row it finds. Safe because
candy was never in `HOUSE_LEGACY_ORDER` -- that frozen list is the nine ids the
pre-schema-26 ladder counted -- and because ownership is keyed by id with
`DataService.reconcile` pruning against the catalogue, so there is no migration.
The Candy Cane KENNEL shares the word and stays. The audit reads 18 of 18.

**Four names were describing buildings that no longer exist**, all of them the
re-themed legacy houses: Starter Shack -> Cardboard Fort, Cosy Cottage -> Beehive
Cottage, Brick Townhouse -> Wonky Townhouse, Stone Manor -> Haunted Manor. Their
BLURBS went with them -- a blurb promising "steep tiled roof and a real chimney"
on a beehive is the copy-outlives-the-thing failure this project already records.
All 18 now match the art inventory exactly. NOTE: the designer asked for "Funky
Townhouse" and the art inventory says "Wonky"; Wonky shipped, being the
alignment target, and it is one word to change.

**THE AUTHORED EFFECTS HAD NEVER RUN, AND THERE WAS NO CODE TO ERROR.** Every
authored house ships meshes named `HouseFX_*` with a kind, period and phase in
its `animation-handoff.json` -- 95 of them across 12 houses -- and they sat
perfectly still, because `HouseFX` finds its work through a CollectionService TAG
and reads behaviour off ATTRIBUTES, while an .rbxmx carries both only as binary
blobs. The art named the parts; nothing in the engine reads names.

`assets/houses/tools/build_house_fx.py` turns the handoff files into
`Shared/HouseFXSpec.luau`, and `buildTemplateHouse` applies it while already
walking the cloned parts. A period in SECONDS becomes `Rate` in cycles a second
-- the one conversion here, and the one that would have been silently wrong: a
9-second pulse written as Rate 9 is nine flashes a second, past the
three-a-second ceiling `HouseFX.MAX_RATE` exists to hold.

THE TAG IS APPLIED AFTER PARENTING, which is the trap this would otherwise have
shipped. `House.build` builds into a DETACHED model, and a tag added outside the
DataModel never fires `GetInstanceAddedSignal` -- so the animator would only have
caught these inside its ten-second startup rescan, and a house bought by a player
an hour into a session would have animated nothing. Same fault `Decor.build` and
the shop doors have both already paid for.

Reported by the generator rather than assumed: `sway` (1 effect, the galleon) has
NO branch in `HouseFX.step` and is emitted as authored and inert, which is better
than mapping it onto `bob` and shipping an effect nobody asked for. Two portal
sections, `HouseFX_RingRim_9` and `_11`, match no mesh in that template and
animate nothing -- for the artist.

NOT verified in Play: Studio was in Play throughout, so Rojo could not push. The
treehouse and slime templates are also still absent from the live place for the
same reason -- both were moved out and back to force a fresh patch, which lands
on the next stop/start.

**FOLLOW-UP, AND THE SECOND CAUSE OF "NO GLOW" IS A MATERIAL RATHER THAN AN
ANIMATION.** The art asks for Neon NOWHERE: every mesh in every manifest is
authored flat, the `*Glow` and `*Light` materials are pale colours rather than
emission, and the generator writes `SmoothPlastic` on all 1,147. So even with the
animator driving them, the light effects were changing colour on a MATTE surface,
which at `Brightness` 2.4 with a bloom threshold of 1.7 is close to invisible.

`Neon` is now set on the LIGHT kinds only -- pulse, cycle, chase, beacon, 65 of
the 95 -- and never on `bob`, `orbit` or `sway`, because Neon on a floating rock
is the "first build shipped Neon and the whole house glowed" mistake the
generator's own comment records. Measured before switching: all 65 sit at or
below 0.70 relative luminance, so none is the pale Neon that renders as a white
hole. It is applied as a PROPERTY, not an attribute -- a stray `Neon` attribute
would have meant nothing to `HouseFX`.

CONFIRMED AGAINST THE RUNNING SESSION, which is the actual answer to "am I
missing something": the live server has no `HouseFXSpec` module, `House.luau`
there does not reference one, and it holds 16 templates rather than 18. Rojo
cannot push while Play is running, so that session predates every fix in this
entry. It needs a stop and restart, not more code.

## All 18 houses wired, place file groomed — September 17 (uncommitted)

**18 of 19 tiers now stand an authored Blender model.** Only the seasonal
Gingerbread Manor is still code-built, being the one house with no v2 export.
Dumped, checksummed, recorded and generated all 18 (v2, and v3 for the treehouse
and Gloop House); added the `Config.HOUSE_TEMPLATE` rows, keyed by STYLE so
`neontower` reads `tower = "neontower"` and `skycastle` reads
`castle = "skycastle"` -- keyed by id those two match nothing and fail silently.

`placeholder = true` came off mushroom, galleon, portal, thundercloud and void
for the reason crystal and goldenpig already had: `Config.residentHouseLevel`
reads that flag, so a tier with a real model and the flag still set is a house no
resident can ever stand. Only candy keeps it, and it is the one that deserves it.

ONE BAD PART IN 1,147, AND IT WOULD HAVE REFUSED A WHOLE HOUSE. The Cardboard
Fort's `Approach_WalkWall` is authored ZERO-THICKNESS and Roblox clamps it to its
0.001 floor, which the recorder reads as a resize. The dump now tolerates a
degenerate axis clamped to the engine floor and nothing else, so a real resize
still fails loudly. Worth telling the artist: that is a degenerate export.

THE PLACE FILE HAD 34 TEMPLATES WHERE IT SHOULD HAVE 18, and the cause is not
Rojo misbehaving -- TWO ROJO PLUGIN INSTANCES ARE LOADED (PluginGuiService shows
every Rojo gui twice), so each sync lands twice. Sixteen were exact duplicates;
TWO WERE STALE -- the treehouse at 72/55 and the Gloop House at 66/34 against
disk's 65/52 and 40/18, i.e. last revision's geometry off mesh ids that still
resolve. A stale sibling is worse than a missing one: `FindFirstChild` stands the
wrong house with nothing in any log. Removed all 18 wrong ones by MEASURING each
against the part counts on disk rather than trusting order.

Rojo has not re-added treehouse and slime since, even after rewriting both files,
so the live place holds 16 of 18. Disk is correct and a fresh `rojo build` carries
all eighteen (1,493 MeshParts) -- this is a live-sync problem, and the fix is on
the Studio side: one plugin, then reconnect.

Deleted 18 imported models holding 1,147 MeshParts from Workspace. Safe because
the templates carry the ids; an import is read exactly once, by the dump, and
after that it is debris that travels into every session.

GROOMED: 19 superseded asset folders deleted, 134 MB, at the designer's explicit
choice not to commit first -- so every v1 `.blend` is gone for good. Each was
removed only after checking that the template which superseded it exists.

169 ORPHANED MESH UPLOADS are recorded in `docs/ORPHANED-UPLOADS.md`, written
BEFORE the deletion because the ids lived in the `studio-import.json` files inside
the folders being deleted. `tools/groom_uploads.py` will now report zero orphans,
which means "no evidence left" rather than "none exist" -- the doc says so. They
cannot be deleted from here: there is no API in this toolchain that removes an
upload, and the doc argues for archiving over deleting.

## Tree card's acorn matches the shop's — September 17 (uncommitted)

`TreeClock` drew U+1F330 CHESTNUT in a TextLabel; the shop, the piggy bank panel
and every acorn price use `Theme.acorn`, a drawn shape. Swapped to
`Theme.acorn(card, 26)`, the same 26 the piggy panel's chip uses, centred in the
40-tall card at x 8 -- ending at 34 against a count that starts at 38.

Its own comment had flagged it: "NOT YET render-measured on a card". Measured on
the live client before the change, the glyph advanced 19.0 in a 26-wide box, and
an emoji is drawn from the COLOUR font so it ignores `TextColor3` -- it could
never have been themed. It was also the wrong nut.

NOT verified in Play: Studio is IN Play, and Rojo does not push while it is, so
the running session still carries the emoji. What was confirmed live is the card
this replaces -- adorned to `Canopy`, 196x40, glyph/count/timer reading
"12/24" and "next 2m".

## Trees scaled up — September 17 (uncommitted)

Three different trees, three different ceilings, and two of them fail silently.

**The grove behind the plots** went 1.15/1.30/1.45 to 1.85/2.10/2.35 -- heights
16.0/18.1/20.1 studs to 25.7/29.2/32.6. The ceiling is `buildTrees`' own startup
audit: the grove is planted from the back fence outward and `canopyReach` is the
DIAGONAL, so at 2.5 the outermost canopy reaches |z| 292.0 against a warn line of
exactly 292.0 -- passing, and touching. 2.35 lands at 290.8. The front row moved
22 -> 30 for the reason that note already records once: the clamp keeps canopies
out of the fence, so a row nearer than the canopy's own reach spends its inward
jitter piling against that clamp and reads as a hedge.

**The verge trees** went 0.75 -> 1.0, and this is the one with a silent cliff at
1.19. `clear(x)` vetoes a placement whose canopy would reach a driveway or a
shop, and every candidate sits at the same offset -- so too big a scale produces
NO VERGE TREES AT ALL rather than smaller ones or a warning. Measured from the
shipped offset of 21: 21 studs to a gap centre (shop half 11) and 19 to a plot
column (half a 17-stud driveway plus one), reach 7.986 per unit of scale, so the
driveway binds first at 1.19 with nothing spare. At 1.0 there are 2.0 studs clear
of the shop and 1.5 of the driveway -- deliberately most of the old margin spent,
and well short of the cliff.

**The acorn oak** went 1.0 -> 1.8: an 8.5-stud canopy to 15.3. The cap is the
SIDE FENCE -- it stands at plot x -25 against a fence interior at -33.6, so 2.0
puts its edge on -33.50 and 2.2 is 0.75 studs out over the alley.

AND THE CROP WAS MEASURED IN STUDS RATHER THAN IN TREES, which is the bug this
would have shipped. `AcornFill` hung ripe acorns at a literal radius 1.65 and
height 3.7 and dropped them at 2.25 -- all solved against the oak at 1.0. Scaling
the tree alone would have left the crop hanging inside the trunk with the ground
acorns out from under a canopy that had moved. They take `treeScale` now. The
ACORN's own size deliberately does not: an acorn is a thing a player catches, not
part of the tree.

`rojo build` passes and every margin above is arithmetic off the real constants.
NOT verified in Play: nothing has been looked at, and the two things only a
picture can answer are whether the grove now walls the street in and whether a
15-stud canopy sits over the basket and the shake prompt readably.

## Houses resized — September 17 (uncommitted)

Reported as way too small above the basic tier. Measured first, and the sizes do
not merely run small, THEY DO NOT LADDER: eleven of the eighteen authored models
are smaller than a tier below them, and the 750K Treehouse (55.7 x 54.9 x 39.9)
is bigger than everything up to the 80M Sky Castle.

RESIZED IN CODE, NOT IN BLENDER. `build_house_runtime.py` gained a `SCALE` table
keyed by stable id, applied after the importer's own factor, so the mesh ids are
untouched -- nothing re-exported, nothing re-uploaded. The designer chose the
monotonic-by-price option, which holds the bottom three unchanged.

TWO SCALES, AND CONFLATING THEM WOULD HAVE MOVED EVERY COLLIDER. `factor` is the
importer's, and `blender_to_import` inverts it to map Blender-authored boxes and
mounts into the import frame; `scale` is that times the display multiplier and is
what final coordinates and sizes go through. Collision box sizes are in Blender
units (studs) so they take the display multiplier ALONE -- the generator's own
comment records a first build that multiplied them by the importer's factor and
produced a deck 0.6 studs across.

Regenerated: modern 38.6x41.3x19.6 -> 50.6x54.1x25.7, crystal 23.9x24.6x45.0 ->
37.0x38.2x69.8, goldenpig 45.0x33.0x40.5 -> 62.1x45.5x55.9, shack unchanged.
Feet still on y 0, and `House.build` front-pins off its own measured bounds so
the seating followed with no change.

`placeholder = true` came off crystal and goldenpig. Not cosmetic:
`Config.residentHouseLevel` reads that flag to decide which tiers a NEIGHBOUR may
stand, so a tier with a real model and the flag still set is a house no resident
can ever show -- and the audit's own rule is that the two must agree.

THE WALK-IN PAIR IS PINNED AT 1.0 AND MUST STAY THERE WHILE INTERIORS ARE BEING
DRAWN. A scale multiplies rooms and doorways while a character stays five studs,
so the treehouse's 10.5-stud cabin is a contract with the rig. Any house getting
an interior needs its number settled BEFORE the interior is authored.

FOUND, NOT FIXED: the authored FX are inert. crystal ships 3 `HouseFX_*` parts,
goldenpig 4 and modern 4, each with a `kind`/`period`/`phase` spec in its
`animation-handoff.json` -- and the generator emits no `HouseFX` tag, which is
what `HouseFX.register` collects on. Slime has the same gap and predates this.
Nothing errors; the parts simply sit still.

`rojo build` passes. NOT verified in Play: no plot has stood a scaled house, so
the footprints are arithmetic -- goldenpig at 62.1 wide leaves 2.55 studs to each
side fence, which is the tightest thing in the catalogue and wants looking at.

## Four houses wired: Cardboard Fort, Fishbowl, Crystal Spire, Golden Piggy — September 17 (uncommitted)

Studio reconnected, so the blocker cleared. Workspace held FOUR imported models,
not the three the designer named — `crystal-spire-roblox` was there too — all
with `bad=0`, meaning identity rotation and `Size == MeshSize` on every part,
which is the assumption `record_house_import.py` carries and does not check for
itself.

Recorded and generated: shack 18 meshes at 93.09 imported units per stud,
modern 24 at 53.06, crystal 21 at 46.33, goldenpig 27 at 45.51 — four different
importer factors, which is why that number is derived per house rather than
shared. Footprints come out exactly as the manifest promises (22.0x20.4x13.4,
38.6x41.3x19.7, 23.9x24.6x45.0, 45.0x33.0x40.5), feet on y 0. Four
`Config.HOUSE_TEMPLATE` rows added; the audit now reads 6 of 19.

THE TRANSCRIPTION WAS CHECKSUMMED, and the check caught its own false alarm.
The dump has to cross from Studio into a file by hand, and a single wrong digit
in a mesh id is a missing mesh nobody would trace back. Counts, id sums and name
lengths matched exactly; the coordinate sum differed by 1 to 5 ten-thousandths,
which was MY checksum summing full-precision floats against a dump printed at
4dp. Re-run with per-component rounding on both sides, all four matched to the
digit. A checksum that rounds differently from the text it checks reports a
transcription error that is not there — and would have been believed.

All four are EXTERIORS: zero collision boxes, zero display mounts, so they stand
as non-colliding scenery exactly as the code-built houses did. Only treehouse and
slime are walk-in or carry a trophy room.

Still missing: eleven models not yet imported (cottage, townhouse, villa, manor,
neontower, palace, skycastle, galleon, portal, thundercloud, void), mushroom
needing a re-export for its colour manifest, and a decision on the seasonal
Gingerbread Manor. `neontower` and `skycastle` are the two whose rows must be
keyed `tower` and `castle`.

NOT verified in Play: the templates parse, carry one MeshPart per mesh with
distinct ids, and `rojo build` passes, but no plot has stood one yet.

## Shop sized for a laptop again — September 17 (uncommitted)

Reported: the shop is too big to click anything on a laptop while reading well
on a phone. That asymmetry is the diagnosis — both halves come from caps and
clamps that only bite on a big window.

Two causes, both measured rather than eyeballed:

- `panelSize.MaxSize` had been raised to 1480x920 for "larger desktop cards".
  The panel is sized in SCALE, so that cap is the only thing deciding how much
  of a desktop screen it takes, and at 1480 it is essentially the whole window.
  Now 1200x760, derived from the two layouts it holds: six 156-wide catalogue
  cards plus the 166 sidebar is 1166, and the landing's six tiles at their
  authored size is 1037.
- `ShopRevamp:layout` clamped the landing tile to 96..150 on the compact branch
  and `math.max(152, available/rows)` on the desktop one — bounded only from
  BELOW. Measured before: 405x275 tiles on a 1366x768 laptop and 450x309 on a
  1512x850 one, against artwork drawn for 333x269. That size is derived from the
  tile's own hardcoded offsets: the constructor authors a 78-tall caption and
  28px title, and the layout derives them as cellH*.29 and cardW*.084, so
  78/.29 = 269 and 28/.084 = 333 is where the two agree. Capped there, with the
  grid centred in whatever is left rather than stretched across it.

Modelled across six viewports: laptops now all land on a 1200-wide panel with
333x269 tiles and six catalogue cards a row; 1024x640 and 812x375 are
byte-identical to before, which is what says the phone layout was not touched.

`rojo build` passes. NOT verified in Play — Studio's MCP link is still down, and
this is a layout change, so it wants a look rather than a measurement: a picture
is the only thing that can say whether the centred grid reads as deliberate or
as a panel with gutters.

## House exteriors — integration prepared, blocked on the mesh ids — September 17 (uncommitted)

Sixteen new authored exteriors landed in `houses/` (plus gloop-house-v2
and treehouse-v2, already wired). Asked to wire them up; the wiring cannot be
completed offline, because the only route from an FBX to a template runs through
the UPLOADED MESH IDS, and those exist nowhere but inside the place after an
import. Studio's MCP link has been down all session.

Prepared instead:

- `assets/houses/tools/dump_house_import.luau` — the Studio dump, previously taken ad hoc.
  Emits exactly what `record_house_import.py` parses. Measures the model AABB
  PER PART rather than through `GetBoundingBox`, because that box is oriented by
  the pivot and the recorder divides those extents by the authored Blender size
  to derive the import scale — a transposed box would not fail, it would scale
  the house wrong. Counts rotated or resized parts as `bad=`, which the recorder
  refuses, rather than trusting the importer.
- Dry-ran `build_house_runtime.py` against a fabricated import in a scratch
  mirror (nothing written into the repo) to prove the generator tolerates an
  EXTERIOR-ONLY report: shack produced a template at "0 collision boxes, 0
  display mounts", feet on y 0, footprint 22.0 x 20.4. So these stand as
  non-colliding scenery exactly as the code-built houses do — not walk-in, no
  trophy room. Only treehouse and slime carry colliders and mounts.
- Checked all 18 against the plot envelope: every one fits inside the 67.2-stud
  interior and the 57 studs of depth that `HOUSE_FRONT_LINE` and `YARD_DEPTH`
  leave. Widest is treehouse at 55.7, deepest treehouse at 54.9, tallest void
  at 60.0.

Two traps recorded for the wiring itself. `Config.HOUSE_TEMPLATE` is keyed by
tier STYLE and two ids differ from their style: `neontower` is style `tower` and
`skycastle` is style `castle`. And `mushroom` cannot be imported yet — it has no
`*-roblox.fbx` and its `package-report.json` carries no `colorRGB`, so the
generator would hard-fail on colours; it needs a re-export first.

Audited per tier with the new `assets/houses/tools/audit_house_wiring.py`, after the designer
reported the void house as wired wrongly: **2 of 19 tiers are wired.** Eight
stand as the PLACEHOLDER BLOCK -- mushroom, candy, crystal, galleon, portal,
thundercloud, void, goldenpig -- and nine stand their rebuilt code builder. The
void report is exactly the block: that tier has never had a builder, so the
authored model is the first thing it could stand, and importing an FBX in Studio
changes nothing the game reads. The audit also caught two of its own parse traps
worth keeping: `Config.HOUSE_MESH` rows are written `= nil`, which is an ABSENT
key in Luau and read as nine meshed houses by a parser taking the text at face
value; and `str.index` on a table's NAME lands in the prose above its neighbour,
returning an empty slice that reads as a table with no rows.

No `Config.HOUSE_TEMPLATE` rows were added. A row whose template is missing
warns on every build of that tier, and residents stand tiers all over the
ladder, so sixteen rows ahead of sixteen templates is sixteen warnings a street
rather than a head start. Rows go in as each template lands.

## Settings menu exclusivity — September 17 (uncommitted)

Reported: opening settings and then the shop drew settings OVER the shop, and
closing the shop left settings still open. Both halves are one cause — settings
was the only menu with no exclusivity at all, and every menu sits at
`Theme.MENU_Z`, so the tie broke on child order and settings is built after the
shop panel.

Fixed with the instrument the bag and the shop already use: a `SettingsOpen`
attribute on the ScreenGui is the state and the panel follows it, so the bag —
built five thousand lines below the settings `do` block and unnameable from
inside it — can close settings and be closed by it without either reaching into
the other. Opening any one of the three now closes the other two. Escape closes
settings as well as the shop, which the documented key map already implied.

Toggling reads the ATTRIBUTE, not `panel.Visible`: attribute-changed signals are
deferred, so reading the panel would read the state as of the previous press.

`rojo build` passes. NOT verified in Play — Studio's MCP link is still down. The
six orderings to drive when it is back: settings then shop, shop then settings,
settings then bag, bag then settings, Escape on each, and the toggle pressed
twice.

## Gate jam retired — September 17 (uncommitted)

Designer asked for the gate jam to come out of the game for now. Removed the
whole surface rather than gating it behind a flag, because there is nothing
left that could read a flag: the gate post and its `JamPrompt` in
`PlotService.buildFence`, `isGateJammed` / `jamGate` / `onGateJam` /
`fireGateJam`, the decision handler in `HeistService.start`, and
`Config.PROMPTS.jam` with `ICON.JAM`. Zero live references remain; the only
matches for "jam" outside `jamb` are retirement notes and one historical
post-mortem in `docs/GAME.md` about `setPromptKind`.

Kept deliberately: the REFUSAL the jam was born from — the owner-locked gate,
and the three reasons it was rejected — now stands where `Config.GATE_JAM` was,
along with the D9 measurement (0.55 for 1.2s, not 0.35 for 2.0s) so a revival
does not re-derive a pair that deletes the chase. The fence penalty path it
borrowed is untouched and still reached through `firePenalty`.

`rojo build` passes. NOT verified in Play: Studio's MCP link was down and no
Luau CLI is installed here, so `tests/run-crates.py` could not run either — the
check that matters is one Play boot, because this touched `Config`.

## Menu icon simplification — September 17 (uncommitted)

User requested simpler Settings, Inventory and Shop icons while preserving the
theme. MenuIcons now draws a cream/gold cog without fasteners or nested machinery,
a pink closed bag with its original handle and one gold clasp (no protruding
cloth/pouch, patches or stitches), and a green storefront without the pig sign,
display coin or fine trim. Transparent backgrounds, hit areas and static behavior
remain. Luau compilation and Rojo build pass. Studio was actively in use during
this update; final visual review of these icons is pending the next play restart.

Generated `assets/piggy-hud/piggy-balance-v2.png` with the built-in image tool;
1254x1254 RGBA with verified transparency. Exact prompt and import instructions
are beside it. PiggyPanel now supports `ICON_IMAGE`, and the user imported the PNG under the
experience's owner: it is image `115881888441059`, assigned and live, so the
card draws the imported icon rather than the drawn pig. The drawn pig is kept as
the fallback for an emptied or unresolvable id. Not yet seen in Play -- Studio's
MCP link was down when the id arrived, so the load has not been confirmed.

## Shop visual implementation — September 17 (uncommitted)

**Follow-up:** User said the implementation did not match the approved image.
Reworked the landing to large illustrated cards across the full panel, cream
captions, gold SHOP sign/pink basket, green masthead and currency badges. Added
Bag/Achievements footer links and a read-only trophy-progress screen. User
explicitly said **no search bar**. New ShopScenes / ShopMarks / ShopAchievements
modules; category palette lives in Theme.SHOP_COLOURS. 138 isolated UI checks
pass. User approved Studio takeover; live desktop and iPhone 6 Plus landscape
emulator checks completed. Fixed category illustration framing/lighting, header
overlap with Roblox controls, touch scrolling (ScrollingFrame.Active), and shop
layering above mobile movement controls. Fresh phone session confirmed swipes
reach the last row and the Bag shortcut opens the existing inventory. Achievements
shows actual trophy progress. Real-device/controller/multiplayer QA remains pending.

After approving the colourful low-poly shop mockups, the user asked GPT to
build them. The UI implementation is now in the Rojo source; no economy,
save schema or server transaction changes were made for this work.

- Six-category home screen and desktop navigation; compact screens use
  category tiles and a Back control. Companions now has its own catalogue.
- Upgrades use Earn / Defend / Rob groups, static model previews, current →
  next stats from Config and existing PurchaseRequest / UpgradeRequest actions.
- Each crate has VIEW ALL CONTENTS: actual pool, owned/not-owned filters,
  live ChestState odds, progress and Acorn purchase. Combine and buyback remain
  on the crate list, and the existing discovery reel remains in use.
- Shared warm palette and flat surfaces; adaptive catalogue columns retain
  text size on phones. Existing Home/Rides/Supplies catalogue actions remain.
- New modules: ShopWidgets, ShopUpgradeFacts, ShopUpgrades, ShopRevamp,
  CrateContents. Integration edits: Crates and ClientMain. Mockups and prompts:
  assets/shop-ui/revamp-v2/. See docs/SHOP-UI-REVAMP.md for remaining scope.

Validation: changed UI modules/scripts compile (including ClientMain's
local/register limit); Rojo builds to ignored ShopRevamp-review.rbxlx.
138 shop UI state/layout checks + earlier 73 crate checks + 70 buyback checks pass.
Studio desktop and 736x414 phone-emulator appearance/navigation checked. Portrait
layout was inspected, but Studio reports portrait is not enabled for this game;
the orientation setting was left unchanged. Existing Bag UI still has its own
mobile CoreGui overlap, outside this shop revision.

Rojo responds at 127.0.0.1:34872 for “Rob a Piggy Bank”; a second attempted
server exited because that port was already occupied. Studio connection and
play-mode sync are confirmed. Other in-progress Fable edits were kept.

## Working agreement — GPT visuals, Fable scripting/planning

User explicitly assigned GPT physical/visual design, UI and buttons, and
Fable scripting and planning. See `docs/DESIGN-SCRIPTING-HANDOFF.md` for the
ownership/handoff workflow. GPT should deliver assets/specs and visual QA;
Fable owns runtime Luau, UI wiring, economy, migrations and functional tests.
Do not silently resume GPT gameplay scripting under the older master-plan
execution requests. Fable's new `docs/LATE-GAME-ECONOMY-PLAN.md` §11 records
the latest choices (individual houses, schema 26 stable IDs, accepted pace,
Option A2 beyond RB10). Its earlier unresolved recommendations are historical.

## Checkpoint — September 16, committed and pushed

**State:** 4b.1 (level-60 ladder, A2 taper), 4b.2 (houses by stable id,
schema 26), 1.11 (pig-crack acorn) and 2.6 (storage is a bank, acorn theft
only under a moon event) are implemented. All 23 isolated suites pass
(`python tests/run-crates.py --luau <luau> --suite <name>`, including the
new `ladder` and `houses`); Rojo builds.

**Designer direction for the next step:** the house exterior renders will be
generated later. Do not wait on them. **Add the revision-2 catalogue to the
game now with empty placeholder models** — the eighteen ids, names, prices
and rarities from `assets/houses/docs/HOUSE-TIER-BRIEF.md` §1 (the three re-themes rename
`villa`, `modern`, `palace` in place; `goldenpig` is earned, not priced), each
standing as a plain, clearly-temporary block sized to its brief height, so
buying, moving in, the catalogue cards and the sign all work end to end.
Then move on to the house INSIDES (trophy rooms, `HOUSE-TROPHY-ROOMS.md`,
brief B2 — GPT's blockouts are in `assets/houses/design/rooms/`).

**Still open for the designer:** the three re-themes (owners wake up in the
new house); Golden Piggy as the earned completion house; player robbery
cooldown 60 s → 180 s (4c.5); order of 4c.6 (delivery capped at the pig).

**Known design flag (from 2.6):** the re-derived acorn faucet is 1.0/hour
solo — a common crate every 5 hours — slower than §19.5 estimated. Levers:
the tree ladder (2.7) and the crate prices.

**Not verified live:** a two-player session (Phase 0.2) is still owed; the
house purchase path is proven at service level, not through the remote.

## Phase 5 implemented: the reputation yard and season one (September 17, latest)

User asked for all of Phase 5. Committed and pushed together with every
earlier uncommitted step below (tree ladder, 4c.6 caps, house catalogue,
Midnight Heist).

- **5.1 The sign.** `PlotService` narrows the rank row and adds a
  `SeasonChip` (`setSeasonChip`, text/colour from `Config.seasonChipText` /
  `seasonChipColour`) and a `Nemesis` line (`setNemesis`). The ledger is
  `data.nemesis = { index, rows }`, twenty rows (`Config.NEMESIS_ROWS`),
  written by `SeasonService.recordNemesis` on every player-victim delivery and
  reset with the season. Rank stars were already on the sign (4c).
- **5.2 Trophies.** Six new `TROPHIES` rows with `Decor` builders: Hot Streak
  (`bestSpree`, `ladder = "above"`), Old Hand (rap-sheet rank), Clean Sheet
  (clean five-slice deliveries), Season Cup (best tier ever), Wanted Poster
  (sessions on the Most Wanted poster), Good Harvest (own-tree acorns
  banked). New counters `trophies.clean/wanted/harvested`;
  `TrophyService.recordClean/recordWanted/recordHarvest/recheck`.
  **Van Job skipped: there is no Cash Van yet.**
- **5.3 The season.** `SeasonService` (new). `Config.SEASON.first = 592`
  (launch week 2026-09-17 is 591's rest week, so **Season 1 opens
  2026-09-24 UTC**). Rank is acorns BANKED this season (own-tree basket
  deposit and the pig-crack acorn), counted only in the four live weeks.
  Tiers 10/20/40/75/150/210/280/370/480/620, re-solved on
  `tests/sim/acorns/model.py x3 season` (the plan's 3..700 predates the x3
  crates and the overnight fill). Rewards go through `SetService.grant`
  (new kinds finish/plinth/kennel/coat), are recorded in `season.granted`
  so they land once, and an already-owned reward is said, not converted.
  Tier 9 is the sign's STAR words, tier 10 the season finish
  (`SEASON.finishes[1] = "midnightstar"`; a season with no row warns and
  skips). Lazy rollover keeps `season.best`. `Config.auditSeason` at boot.
- **5.4 Finishes.** `Config.FINISHES` (Bright Eyes, Polished, Lantern Glow,
  Gilded, Midnight Star): reflectance, neon eyes and the aura light, lamps
  capped at 0.6 by the audit. `cosmetics.finish/ownedFinishes`, pruned in
  reconcile. `PiggyBank.applyFinish` runs after the skin and effect;
  `CosmeticsService.equipFinish` (toggle, owned only); a **Finishes** tab in
  the inventory. **No particles**, per the standing no-piggy-effects rule.
- **5.5 Boards.** Top Defenders (`WEEKLY_DEFEND`, `data.defend`, counted on a
  nab win, a dog catch for the owner and an owner's hot recovery) and the
  season board (`SEASON_BOARD`, two 100-row pages, cached a minute). The one
  street board turns pages every `BOARD_PAGE_SECONDS` (thieves, defenders,
  season) and publishes `BoardPage`; on the season page each client hides it
  and draws `Shared/SeasonBoard` from its own `SeasonState`: three rows
  above and four below the reader, or the top seven plus a "you" row.
- **Admin:** Season group (shift a week, reset, +50, +300, status);
  `seasonshift`, `seasonearn`, `seasonstate` commands.
- **Checks:** new `season` suite (82 checks: clock and launch dates, tiers,
  grants once, already-owned, rollover and best, rest week, pre-season,
  window, nemesis cap, audit provocations, trophy grades and counters,
  finish prune, set kinds, defend counter, the board footer). Four heist
  suites gained SeasonService/Trophy/recordDefend stubs. All 26 suites pass;
  every script compiles; Rojo builds; `git diff --check` clean.
- **Not verified live (no Studio session):** the sign's new geometry
  (chip/nemesis/boasts overlap), the local season page over the board, the
  finishes on a real pig, the six trophy models, DataStore publish/fetch,
  and every multiplayer path (nemesis, defends).

## Midnight Heist, acorn theft off, crates x3 (September 16)

Designer decisions, all implemented; uncommitted (no commit yet by request).

- **Crates x3 (19.5):** `og`/`animal` 5->15, `alien` 6->18, `rarecrate`
  15->45, `legendarycrate` 40->120. Buy-back (3x per step) and the
  rebirth-crate bonus derive from them. `crates`, `buyback`, `rebirth`,
  `audits` tests now read prices from Config or were updated.
- **Midnight Heist replaces Rush Hour and the Harvest Moon.**
  `roster.midnight` (180 s, weight 2); `EVENT_UI.midnight` (U+1F319, the
  periwinkle); `Config.MIDNIGHT` (stealMultiplier 2, acornMultiplier 2);
  `Config.MIDNIGHT_LIGHT` + `WorldService.setNight` (renamed from setMoon).
  `EventService.runMidnight` sets both multipliers before the push;
  `getAcornMultiplier`; `HeistService.endCrack` stamps
  `carry.acornMultiplier` on a clean crack so a delivery after dawn is still
  doubled. Solo gets no acorn bonus (residents mint none), by decision.
  `Config.RUSH` and `runRush` are gone; admin panel has MIDNIGHT HEIST now.
- **Acorn theft disabled:** no row carries `acornTheft`; `auditAcorns`
  `theft.disabled` refuses one; `midnight.acorns` caps the night at 2x. The
  shake refusal now reads "Only its owner can shake this tree." Theft code
  remains, closed — revisit after play-testing.
- **Model** (`tests/sim/acorns/model.py [x3|old]`): per day — casual 5–12,
  regular 13–24, active solo 20–28, active multiplayer 22–30. Regular: ~1–1.6
  common crates a visit, a legendary every 5–9 days.
- **Measured event shares:** raid 40.9% (every ~37 min), night 59.1%.
- **Admin:** Tree group (`tree`, `ripe`) from earlier in this step.
- **Checks:** `moon` suite renamed `midnight` (31); `theft` 171 (+4 night
  acorn checks); all 25 suites pass; compile and Rojo build clean.
- **Not verified live:** the night's look, the crescent glyph's width, a
  doubled acorn delivery in a two-player session.

## 6.4 implemented: the Harvest Moon (September 16)

User asked for the next step; 6.4 was the remaining plan step needing
neither GPT art nor a live play session. Uncommitted, on top of everything
below; no commit yet by request.

- **Event:** `Config.EVENTS.roster.moon` = HARVEST MOON, 150 s, weight 1,
  `acornTheft = true`; `EVENT_UI.moon` (U+1F315, tone 192/182/255 after the
  first pick measured 4.46:1 at the warning pulse low). The banner, warning,
  countdown chip and patrol suppression are the generic event path.
- **Theft:** nothing new — 2.6's `EventService.isAcornTheftOpen`,
  `ShakeService.open` gate and the client prompt gate on
  `EventState.acornTheft` light up while `running == "moon"`. Ripe acorns
  only, basket x5 player / x1 resident, storage safe, normal getaway. A round
  already started may finish after the moon sets.
- **Light:** `Config.HARVEST_MOON` dusk; `WorldService.setMoon(on)` tweens
  (3 s) and on the way back sets `WorldService.DAY` exactly (ClockTime 14.5,
  Brightness 2.4, both ambients, sun tint). `restoreDay` also runs if the moon
  errors. The boot lighting now reads the same `DAY` table.
- **Audit:** `auditAcorns` requires exactly one theft row, 60–240 s, weight
  > 0, with a banner row.
- **Admin:** "HARVEST MOON now" button.
- **Measured shares** (40,000 slots): moon 27.9% (~1 an hour), raid 27.5%
  (down from ~41%, about one every 55 min), rush 44.7%.
- **Checks:** new `moon` suite (29); `audits` stub gained WorldService. All
  25 suites pass; 105 scripts compile; Rojo builds.
- **Not verified live:** the dusk's look and readability, the moon glyph's
  width, another tree's prompt appearing and disappearing with the banner in
  a real session, and a shaken neighbour's acorns delivered home.

## 2.7 implemented: the tree ladder (September 16)

Uncommitted, on top of the 4c.6 and house-catalogue work below.

- **Config:** `TREE_LEVELS` (0–4: 1.0/1.25/1.5/2.0/2.5 per hour; prices 25K,
  100K, 1M, 12M, each under the cheapest house of the rarity that opens it —
  first pass, re-solve with 19.5), `TREE_HOUSE_GATE` (best OWNED house: Common
  lv1/cap 8, Rare lv2/12, Epic lv3/16, Legendary lv4/24),
  `TREE_REBIRTH_BONUS` (+3% per rebirth, online only, max +60%). Helpers
  `bestHouseRarity`, `treeGate`, `treeLevelOf`, `treeCap`,
  `treeGrowthPerHour`, `nextTreeLevel`, `treeGateRarityFor`.
- `Config.growAcorns(data, now, online)` reads rate and cap off the save:
  offline path passes `false`, live tick `true`, shake settles with the
  owner's online state. Residents grow exactly as before.
- **Save:** `data.tree = { level = 0 }` via the generic fill (no schema bump);
  reconcile clamps the level and re-clamps ripe stock to the house cap after
  houses resolve. Level survives rebirth.
- **TreeService** (new): owner-only **Grow Tree** prompt on the oak (J,
  slot 1, kind `grow`, built in `PlotService.buildPlot`), plus `TreeRequest`.
  Refusals (gated, fully grown, won't fit, too few coins) name the reason and
  never charge; a purchase settles growth at the old rate, charges, redraws
  and saves. `CosmeticsService.onHouseBought` refreshes the offer. Main
  starts it and calls `TreeService.apply` on join; `PlotService.release`
  resets the oak and the prompt owner.
- **Placeholder look:** height-only stretch to 1.2x at level 4
  (`AcornTree.setGrowth`). Sideways growth was dropped: the trunk mesh's
  bounding box already reaches the storage crate at level 0. The ripe-acorn
  display scales its height by `PLOT_TREE_GROWTH_ATTRIBUTE`.
- **Audits:** `auditAcorns` checks the ladder, gate and bonus;
  `auditEconomy` prices the rungs. Boot line reports the top tree rate
  (4.0/h vs the 1.0/h base).
- **Checks:** new `tree` suite, 93 checks (simulated day per level, online-only
  bonus, house caps incl. 19.4a's "20 after eight hours", partial-hour carry
  across a purchase, purchase path and refusals, saves, provocations,
  level-4 clearances). All 24 suites pass; 104 scripts compile; Rojo builds.
- **Not done / not verified:** no Studio session (prompt card, J key, the
  stretched oak and the 🌳 glyph's width are unseen); the "next acorn" HUD
  chip and fertiliser; crate-price re-solve (19.5); an admin command to set
  tree level for testing.

**Follow-up, same day — the next-acorn clock over the tree** (designer
asked for it above the tree rather than on the HUD):
- `Shared/TreeClock` (client, owner-only, started in `ClientMain` with no
  new local): a paper card just above the canopy — chestnut glyph, `3/12`,
  `next 42m` / `0:42`, or `FULL` in good ink. Rises with the canopy.
- Server publishes `Config.PLOT_TREE_NEXT_ATTRIBUTE` (server time of the
  next acorn, nil when full) and `PLOT_TREE_CAP_ATTRIBUTE` via
  `PlotService.publishTree` / `updateTreeClock`; `Config.nextAcornIn`
  shares `growAcorns`' cursor and rate. Published from the economy push,
  a shake (`ShakeService.publish`), `TreeService.refresh` (join, purchase,
  house purchase); cleared on release.
- `tree` suite 106 (+13); `growth` and `shake` stubs gained `publishTree`.
  All 24 suites pass; 105 scripts compile; Rojo builds.
- **Not verified:** the card in Studio (position above the canopy, the
  chestnut glyph's width, `24/24` fitting its 62px box).

**Next:** Studio verification of the three uncommitted steps, then the
designer's call on the remaining order (19.5 re-solve, Harvest Moon 6.4,
the 4c robbery rework).

## 4c.6 implemented: nothing puts more in a pig than it holds (September 16)

User direction: skip the trophy rooms (4b.5) for now, do 4c.6 before 2.7, and
leave the three re-themed houses on their old models until the new models are
swapped in. Uncommitted.

- `Config.pigRoom` / `Config.fitInPig(coins, capacity, amount) -> banked, spilled`.
- **Capped (all minted coins):** `HeistService.deliver` (original, revenge
  and kept-haul half share), the return bounty, the shop-drop duplicate
  resale, `DailyService` coin rungs (including the Golden Bone day), and
  `EventService.payIncomeSeconds` (raid bounty). Each names the spill.
- **Coins coming back are capped too** (designer correction): `giveBack`
  (every coin return: nab, dog, patrol, voluntary return),
  `ResidentService.refund` and the drone recovery bank only the room and
  name the spill. The loss ledger is still credited in full.
- The victim is still charged in full; `totalStolen`, rap sheet, weekly board,
  robbery count and pig-crack acorn are unchanged. `HeistDelivered` carries
  `spilled`; `LootHaul` shows "PIGGY FULL: X SPILLED".
- Crack and smash toasts go through `homeWorthPhrase` (payout x spree x room),
  so the preview matches the banked figure.
- **Badge and prompt cards** (designer correction) show `Config.homeTake`:
  what the reader can carry home from a clean crack (smash card: a smash),
  capped at their own room. A full reader pig reads **PIG FULL** on the badge
  and **FULL** on the cards. `RobBadge` now listens to `StateUpdate` and the
  sack level; `ClientMain` keeps the reader's coins/capacity on `stealInfo`
  (no new top-level locals) and refreshes the cards on every push.
- **Design flag:** daily coin rungs (5–30 min of income) can mostly spill on
  a full pig. Lever if it feels harsh: hold the coins until there is room.
- **Checks:** `theft` 167 (+14), `badges` 26 (+9), `shopdrops` 104 (+2);
  `handoff` and `shopdrops` fixtures now carry `capacityLevel`; all 23 suites
  pass; 103 scripts compile; Rojo builds.
  GAME.md §4 and CLAUDE.md updated.
- **Not verified live:** no Studio session; a real delivery into a full pig,
  the card's spill line, and the badge/prompt `PIG FULL` / `FULL` text (width
  unmeasured on screen) are unseen.

**Next:** 2.7 (tree ladder and rebirth growth bonus), unless the designer
reorders. 4b.5 trophy rooms are deferred.

## Revision-2 house catalogue landed with placeholders (September 16, later)

The designer direction above is **done**; uncommitted. All nineteen rows from
`assets/houses/docs/HOUSE-TIER-BRIEF.md` §1 are in `Config.HOUSE_TIERS` in price order
(18 priced, shack to the 1B Void, plus the earned Golden Piggy).

- **New houses** (`mushroom`, `treehouse`, `slime`, `candy`, `crystal`,
  `galleon`, `portal`, `thundercloud`, `void`, `goldenpig`) carry
  `placeholder = true` and a brief `height`. `House.build` stands
  `buildPlaceholder` for them: plinth, block in the row's wall colour, roof
  cap, door, and a yellow-and-black construction band. Measured in a stubbed
  sweep: 29–71 parts each, zero coplanar pairs, footprints up to 51.2 x 37.2,
  heights equal to the brief. A style with no builder and no flag also gets
  the block now (it used to borrow the shack).
- **Re-themes** renamed in place (Fairy Lantern Cottage, Fishbowl House, Ice
  Palace) with new blurbs. **They keep standing their old models** so no
  paying owner wakes up in a block; switching `style` when the new builder
  lands is the one-word change. The Sky Castle blurb no longer says "the last
  thing anyone buys".
- **Golden Piggy:** no `cost`, `earned = "houses"`, explicit legendary.
  `isEarnedElsewhere` reads `earned`. `buyHouse` refuses it by name with the
  progress count (never charges); `CosmeticsService.grantEarnedHouses` grants
  it on the last priced purchase without moving the player out of what they
  just bought; it can then be moved into for free. The payload marks it
  `earned` with `earnedHave/earnedNeed`, and its card reads `EARNED n/18`.
  `Config.earnedHouseProgress` counts priced houses (shack included).
- **Residents** climb only built houses via `Config.residentHouseLevel`, so
  every neighbour stands exactly the house it did before.
- **Audit** now refuses a priced earned house, a priced row with no number, a
  placeholder over the 60x57 limit, and a catalogue out of price order.
- **Checks:** `houses` suite 1,239 (was 1,025); all 23 suites pass; all 103
  scripts compile; Rojo builds; `git diff --check` clean. The old test pinning
  the nine at positions 0–8 now asserts their relative order instead.
- **Not verified live:** no Studio session was available, so the blocks on a
  real plot, the shop card render, the sign and a purchase through the remote
  are unseen. The Void's near-black block against the card's near-black icon
  well is the first thing to look at (brief §2 trap 2).

**Next:** the house INSIDES — 4b.5 trophy rooms (`HOUSE-TROPHY-ROOMS.md`, brief
B2; GPT's blockouts in `assets/houses/design/rooms/`). Each new house's real
builder can land any time under its `style`, then drop `placeholder`.

## Fable handoff — economy and acorn re-centring (September 16)

Planning only; no runtime Config, service or client code changed. Three
documents carry it:

- `docs/LATE-GAME-ECONOMY-PLAN.md` — audit of the live formulas (regenerable
  via `tests/sim/late-game/`), the chosen late-game ladder (band C to L60 /
  RB20, top pig 1.241B, rebirth multiplier 0.12 to RB10 then 0.08),
  archetype pacing (regular player: 1B house ~week 8), individual house
  ownership by stable id, schema-26 migration that deletes
  `houseLevel`/`houseShown`, and §11 (trophy rooms + seasons as the loop
  after the catalogue; a voluntary Legacy reset).
- `docs/MASTER-PLAN.md` §19 — the acorn loop re-centred on the pig: coin
  pack dropped; one acorn minted per clean five-slice crack on a player's
  pig; banked acorns never stealable; acorn theft only inside a new
  **Harvest Moon** event (bounded lighting tween, no day/night cycle); a
  coin-priced tree ladder and rebirth online-growth bonus. Banners on §3-6,
  13, 14.2, 15, 16 and Phases 2/3/6; six new Part III C rejections. New
  execution steps 1.11, 2.6, 2.7, 6.4 and **Phase 4b** (ladder, house ids,
  catalogue UI, rooms, Legacy).
- `docs/BRIEFS-FOR-GPT.md` — step-1 briefs. **GPT needed now:** B1 house
  catalogue UI, B2 trophy-room templates (named mount points), B3 exterior
  constraints. **Later:** B4 Harvest Moon look, B5 tree levels, B6 Legacy.
- `assets/houses/docs/HOUSE-TIER-BRIEF.md` — the full eighteen-house tier list for GPT:
  nine new **fantasy** houses (toadstool, treehouse, slime, gingerbread,
  crystal spire, beached galleon, dragon's roost, sky islands, golden piggy)
  with stable ids, silhouettes, FX, room families and the yard constraints;
  the nine existing houses keep id/price with an optional later re-theme.
  Supersedes the realistic concepts in `HOUSE-CATALOGUE-PLAN.md`.

Fable can start 4b.1 (ladder, Config only), 4b.2 (house ids + migration),
1.11 (pig-crack acorn) and 2.6 (retire raids) with no visual dependency; 4b.3
waits on B1. Open decision for the user: do skins and rides survive a Legacy
reset (recommended yes).

## Fable — Phase 4b.1 implemented: the late-game ladder (September 16)

Config only, plus two readers. `ABSOLUTE_MAX_LEVEL` 40 → 60 with a third
growth band (`BAND_TOP_2` 40, `CAPACITY_GROWTH_C` 1.136, `INCOME_GROWTH_C`
1.10, band-B cost growth); `maxLevel` unchanged in form, so rebirth 20 opens
level 60; rebirth multiplier tapers to 0.08 past rebirth 10
(`REBIRTH_MULTIPLIER_TAPER`, read through `Config.rebirthIncomeFactor` /
`rebirthBonusPercent` — `Rebirth.luau` and `ProgressionService` converted);
both audits derive their rebirth sweep from `Config.rebirthsToMax()`.

- **Every value for L ≤ 40 / RB ≤ 10 is unchanged** — pinned by the new
  `tests/luau/ladder.luau` (121 checks; `--suite ladder`). Top pig is
  1,241,390,843; a 1B house is 80.6% of it and passes `auditEconomy`.
- All 21 existing suites pass unchanged; `rojo build` passes; `Config.luau`
  executes fully under the Luau CLI (so no load-time throw).
- `tests/sim/late-game/dump.py` now prints the tapered factor to RB22.
- `CLAUDE.md` gained the band-C entry (derivations, the taper, the pinned
  audit bounds); `docs/GAME.md` §4 says three bands and cites the taper.
- **Not done:** a Studio Play to watch the boot log. Studio was left to
  whoever holds the active Rojo session per `DESIGN-SCRIPTING-HANDOFF.md`.
- Uncommitted. Next Fable step: 4b.2 (house ids + schema 26).

## Fable — Phase 4b.2 implemented: houses by stable id, schema 26 (September 16)

`Config.HOUSE_TIERS` rows carry `id` (shack, cottage, townhouse, villa,
manor, modern, neontower, palace, skycastle); `style` stays the builder key.
`data.houses = { owned = { [id] = true }, shown = id }` replaces
`houseLevel`/`houseShown`, which `DataService.reconcile` reads once against
the frozen `Config.HOUSE_LEGACY_ORDER` (derive-only, never grants) and
deletes. Houses are a shelf: `CosmeticsService.buyHouse(player, id)` sells
any unowned house whose price fits the pig (a "grow your pig" refusal above
capacity, a coins refusal below), and moves into any owned one free. No
"buy the X first" copy survives. Readers converted: Config (helpers
`getHouseById`, `houseLevelOf`, `getShownHouse`, `legacyShownHouseLevel`;
retired `getHouseUpgradeCost`, `MAX_HOUSE_LEVEL`, `getShownHouseLevel`),
DataService, CosmeticsService (payload entries carry `id`; `houseShown` is
an id; `houseLevel` gone), AdminService (`house` takes an id or a legacy
number; `unlockall`, `reset`), EconomyService and ProgressionService sign
lines, ClientMain's three house sites (cards keyed by `info.id`),
`growth.luau` fixture. `auditEconomy` refuses a missing/duplicate id and a
legacy id not in the catalogue. `SCHEMA_VERSION` 26.

- `tests/luau/houses.luau` (`--suite houses`, 1,025 checks): the §8.2
  matrix twice, prune/fallback, never-grants, and `buyHouse` through the
  real service (outright purchase, free move-in, refusals never charge, a
  numeric key is refused, rebirth keeps every house).
- All 23 suites pass. Studio Play: clean boot, the schema-25 dev save
  (level 8 / shown 8) came back owning nine and showing the Sky Castle on
  the sign; one leftover reader (`applyToPlot`'s sign line) was caught by
  that boot, not by grep, and fixed.
- **Not verified live:** a purchase through the real `CosmeticRequest`
  remote — the MCP sandbox cannot fire capability-gated remotes; covered by
  the service-level test instead.
- `docs/GAME.md` §9 and §13 updated (game-doc agent). Uncommitted.
- Next: 1.11 (pig-crack acorn) and 2.6 (retire raids).

## Fable — Step 1.11 implemented: the pig-crack acorn (September 16)

`Config.ACORNS.payout.crack = 1` / `crackRevenge = 2`, read only through
`Config.crackAcorns(clean, victimIsPlayer, revenge)`. `HeistService.endCrack`
stamps `carry.clean` on "done"; `deliver` mints the acorns for the ORIGINAL
grabber on a player victim (residents and shops pay none, a nabbed carry
pays none, a partial crack pays none), pushes the plot's acorn count, names
it in the delivery toast and in the `HeistDelivered` payload (`acorns`);
`LootHaul` shows "+1 ACORN" on the summary card. `auditAcorns` gained
`acorn.crack` (whole, ≥1, revenge ≥ plain) and `acorn.crackGate` (the three
zero cases), and its legacy-faucet wording changed.

- `tests/luau/theft.luau` +10 checks, `audits.luau` +5 provocations; all
  affected suites pass.
- Not re-derived yet: the acorn rate model printed at boot
  (`Config.acornRates`) still describes the tree-and-raid faucet; 2.6 and
  19.5 re-solve it.

## Fable — Step 2.6 implemented: storage raids retired (September 16)

Storage is a bank: `ShakeService.open` refuses "storage" for everyone by
name; another occupant's tree is refused ("Only the Harvest Moon…") unless
the new `theftOpen` hook is true, wired to `EventService.isAcornTheftOpen()`
(true only while a roster row with `acornTheft = true` runs — none exists
until 6.4, so theft is closed). `EventState` carries `acornTheft`; the client
shake prompt on anybody else's tree is disabled unless it is set. Removed:
the crate's raid prompt (J is free), `ACORNS.share/lossCap/lossWindow`,
`resident.raidSeconds`, resident `raidReadyAt`, the raid-ready plot
attribute, the `acornRaid` prompt kind and the loss ledger.
`Config.acornRates` re-derived (own tree + pig-crack ceiling);
`ACORN_AUDIT` is `activeHours/minPopulationRatio/maxCrackRatio`;
`auditAcorns` gained `retiredRaid`, `crackCeiling` and dropped the loss-cap,
passive and 3x active floors. Boot print changed.

- `tests/luau/shake.luau` rewritten (raids inverted to named refusals, moon
  simulated); `shakeui`, `residents`, `audits` updated;
  `tests/studio/resident-acorns.luau` deleted (tested the retired
  countdown). All 23 suites pass.
- Studio Play: clean boot; zero raid prompts; own tree offered, nine
  resident trees withheld; the new model line printed.
- **Design flag:** the re-derived faucet is 1.0 acorn/hour solo (a common
  crate every 5 h) and 3.0 full-server — slower than §19.5's estimate. See
  the note added under MASTER-PLAN §19.5; the levers are 2.7 and crate prices.
- `docs/GAME.md` update running via the game-doc agent. Uncommitted.

## Fable — Phase 4c added: the robbery rework, and two rules verified (September 16)

`MASTER-PLAN.md` Phase 4c: harder crack (measure first — the dial was frozen
for the life of the feature), the panel redesign (B7), catching as beats
(dog lunge, officer corner-cut, owner shove, resident shout), new gadgets
(B8; candidates rule-checked, movement items refused). 4c.5 verifies the
same-victim cooldown (60 s per thief per victim, plus the 45%/h loss cap;
friend ping-pong is ~14x worse for the board than robbing residents) with an
offered decision to raise the player cooldown to 180 s. 4c.6 records that
**delivery is NOT capped at capacity today** — `deliver` overflows on purpose
— and plans the reversal: bank `min(amount * payout, room)`, spill said out
loud, every "worth at home" preview capped, one rule for dailies/events too.
Briefs B7 and B8 appended to `docs/BRIEFS-FOR-GPT.md`. No code changed.

## Fable — house catalogue revision 2 and houses-gate-trees (September 16)

Planning only. `assets/houses/docs/HOUSE-TIER-BRIEF.md` is now revision 2: dragon → Portal
House (300M), sky islands → Thundercloud Fortress (600M, storm grey-blue),
golden piggy → **The Void (1B), the one black house**; Golden Piggy becomes
an earned, unpriced completion house; re-themes Suburban Villa → Fairy
Lantern Cottage, Midnight Modern → Fishbowl House, Marble Palace → Ice
Palace (same ids, prices, owners — **pending designer confirmation**). New
rules: a house never contains a creature; exactly one black house.
`MASTER-PLAN.md` §19.4a: houses **gate and hold, never generate** — one tree
per plot; tree levels unlocked by best-owned house rarity (C 1 / R 2 / E 3 /
L 4); tree cap by house rarity (8/12/16/24), rate by tree level; reads the
best house OWNED, not shown. Added to the 19.5 re-derivation list. GPT: use
revision 2 for the exterior concepts.

## Current task — higher-tier house exterior concepts

Latest: user approved the shared themed trophy-room idea and requested a
house-count/price plan extending to 1B. `assets/houses/docs/HOUSE-CATALOGUE-PLAN.md` proposes
18 houses (nine existing prices preserved, nine additions). Assumes 1B is
the highest single purchase; proposed total is 2,228,455,000 coins. Four
houses exceed the current 96,904,045 capacity, so capacity progression or
staged payments must be decided before adding those prices. No pricing,
rarity, income, capacity or ownership changes were made to runtime Config.

Follow-up direction: user likes enterable showcase rooms and wants earned
achievements/trophies inside houses instead of in the yard. Proposed shared
room system and theme mappings are in `assets/houses/docs/HOUSE-TROPHY-ROOMS.md`; existing
TrophyService progress can be reused. No interior runtime changes yet.

User deferred fence expansion and requested exterior catalogue mockups;
interiors are a separate future proposal. Built-in image generation produced
three sheets (each front and three-quarter views): Emerald Chateau, Sunset
Sky Villa and Royal Observatory. Files, notes and exact prompts are saved in
`assets/houses/concepts/2026-09-16/`. These are proposals only: no house models,
prices or progression changes were implemented. MASTER-PLAN priority updated.
Existing houses use saved numeric levels, so future expansion must preserve
ownership instead of inserting/reordering the ladder without migration.

## Current direction — standalone piggy effects retired (September 16)

**The user explicitly rejected restoring the effects shop:** effects on a
piggy should only be coin-deposit feedback and Legendary skin visuals.
This supersedes the old Phase 4.3 / Art 11 brief. Do not ask to restore the
shelf again. Aurora, Starfall and the attempted shop UI have been removed.

- Retired direct coin/Acorn purchases, equip requests (except clearing None),
  event/pass grants and shop robbery drops for standalone piggy effects.
- Piggy Outfitters now drops skins only; overall 10% chance stays unchanged.
- The renderer disables the separate aura/light without touching coin or
  Legendary skin emitters. Non-Legendary skins cannot opt into skin auras.
- Legacy ownership and particle definitions remain for save compatibility.
  No player balance/ownership migration or deletion was performed.
- MASTER-PLAN Phase 4.3 now starts with yard/fence styles, then interiors;
  the proposed effects design file was removed. Those next shelves still
  need their design brief. Phase 0 and previous live gameplay checks remain
  deferred. Changes are uncommitted.
- Validation: 1,479 isolated checks pass across 21 suites (224 audit checks).
  All production scripts compile; final Rojo build and diff check pass.
  Native phone Play verified the effects tab/shortcut are absent, no Aura
  emitter is enabled, and Drip/Burst/SkinAura instances remain. No new runtime
  errors; existing unset-pass/MaxPlayers warnings persist. Studio returned
  to Edit. This does not close the pending multiplayer gameplay checks.

## Resume here — Robbery odds and discovery reel (September 16)

The user requested visible robbery loot odds and a dramatic item reel, then
approved **a compact non-blocking reveal on discovery** and **making Volt
Scrambler Legendary** so the shop can actually award a Legendary ride.

- `CrackState.loot` now contains the authoritative bonus-item odds. Shops
  show the overall clean-crack item chance and conditional rarity chances;
  locked Wheels & Kit shows 0% and rank 2 / 100 completed robberies. Eligible
  player skins show 100%; owned/protected/capped/in-transit skins show 0%
  with a reason. Resident piggies explicitly show 0%, coins only.
- `Config.shopLootOdds` builds the same eligible weighted pool used for the
  actual roll, displayed rarity odds and discovery reel. Unowned items are
  preferred; a completed collection uses the existing coin resale fallback.
  Event/pass-exclusive items stay excluded. The overall shop rates are unchanged.
- Fresh ride collection, conditional on a 3% drop: Common 76.63%, Rare 16.09%,
  Epic 5.75%, Legendary 1.53%. These change with ownership. Volt Scrambler now
  has explicit Legendary rarity; Hoverdisc stays event-exclusive.
- `RobberyLoot` draws a 2.5-second compact reel with real item model previews,
  server-selected winner, rarity colour/pulse, and carried/owned/resale status.
  No full-screen shade, input-blocking frame or client-side award. It queues
  discoveries and cleans up cards/models/listeners. Rotation updates the layout.
- Player skin preview and actual theft share eligibility logic, preserving
  recovery priorities, insurance and cap rules. Tests cover those conditions.
- **1,396 isolated checks across 21 suites pass.** Native phone fixtures
  verified readable odds text, exact Legendary winner, non-active reveal
  frame, fitting labels and automatic cleanup. Images are in
  `assets/robbery-ui/`. The fixture sends cosmetic packets only and changes
  no balances, stock or owned items. Its temporary runtime script was removed.
  This is component validation, not the still-pending multiplayer gameplay gate.
- All 103 production scripts compile and match Studio after fixture removal;
  the final Rojo build and whitespace checks pass. Studio remains in Edit
  with Rojo connected. No place was published.

The earlier rank/drop implementation and remaining plan work are below.

## Windows Phase 4.2 update (September 16)

The user explicitly approved implementing Phase 4.1 while keeping the older
multiplayer/mobile checks pending, then requested the next step, Phase 4.2.
Phase 0 is still deferred. The previous checkpoint below is historical.

- **4.1 implemented:** ranks 0–4 at 0/25/100/400/1,600 lifetime robberies.
  `Config.getRapSheetRank` derives rank from the existing saved counter.
  Residential signs show earned stars in a separate row; rank zero is labelled.
  CosmeticsService loads the rank on join; successful coin/Acorn getaways
  refresh it immediately; release clears it. No additional saved counter.
  Names/boasts retain their former dimensions; the board extends downward.
- **4.2 implemented:** shop drop chances are piggy 10%, home 8%, gear 3%,
  defend 20%. Gear requires rank 2 before rolling, including resale fallback.
  Missing data/unknown shops refuse. `auditSkinSteal` compares against the
  largest configured shop chance and rejects invalid probabilities.
- Tests exercise 99→100 for coin, Acorn and skin-only getaways and exact
  star counts. The real shop-drop function gives rank 1 no rides in 200
  attempts, six eligible rides in 200 evenly spaced draws, and 317/10,000
  (3.17%) in a seeded random run. Carry, duplicate resale, consumables and
  audit checks use isolated data, never the user's saved balances.
- The test runner now reads UTF-8 explicitly for Windows compatibility.
  This machine's official Luau 0.738 tools are temporarily installed at
  `%TEMP%/codex-luau-0.738/`; the helper is not a repository dependency.
- Studio/Rojo reconnect verified all 102 sources against the Mac checkpoint.
  Phase 4.1 boots successfully; its live rank-zero sign has fitting owner,
  rank and boast text. Final visual review was stopped by the user with Escape.
- Live phone hotbar checks passed reorder in both directions and cancel by
  dropping outside the bar, with unchanged item stock. Original order was
  restored. This is not a full touch/multiplayer/persistence review.
- **4.2 verification:** all 45 new shop-drop checks, 133 theft checks and
  185 audit checks pass. Both changed runtime scripts compile; Rojo builds
  and `git diff --check` passes. Studio Config/HeistService source hashes
  match disk; a fresh Play reaches Ready with no new feature errors.
  Existing unset-pass, MaxPlayers and stale mane-size warnings remain.
  Studio is left in Edit, connected through Rojo. No place was published.

**Next:** Phase 4.3 starts with the effects coin shelf and has a design gate;
read MASTER-PLAN §14, §18.2 and Art 11 before building new assets. Keep the
Phase 3.3 multiplayer exits, 3.4 badge/recovery visual checks, remaining Acorn
drag/getaway review, full mobile HUD review and rank-sign visual review open.
Do not claim those gates passed. Phase 4.4 is still blocked on its prerequisites.

This work is local and uncommitted. At the start of 4.2 the working tree also
contained deletions under `assets/dogs/` from outside this task; they were not
changed or restored as part of these rank/drop steps.

## Earlier September 16 checkpoint

This checkpoint is intended for `main` on
`https://github.com/antoniofodor/Rob-A-Piggy-Bank`. The user requested that all
current project changes be committed and pushed before moving machines.
Use `git log -1 --oneline` to identify the checkpoint after pulling.

### Start on the other machine

1. Pull `main` (or clone the repository) and open this project folder.
2. Install/use **Rojo 7.7**, Python 3 and the official Luau CLI. Blender is only
   needed for asset authoring; runtime assets already reference uploaded Roblox
   mesh/texture IDs and the committed guard templates.
3. Run `rojo serve default.project.json --port 34872` at the project root.
4. Open **Rob A Piggy Bank**, place ID **135433647855162**, in Roblox Studio.
   Connect the Rojo plugin to `localhost:34872` in **Edit mode**, allowing its
   script-modification permission. Connecting from Play's Client causes
   `Http requests can only be executed by game server`.
5. Enable Studio MCP and confirm the tool connection identifies that place.
   The repo's `.mcp.json` is a Windows launcher; configure Studio's MCP for the
   destination OS. The previous Mac's `/tmp/piggy_studio_mcp.py`, `/tmp/piggy-rojo`
   and `/tmp/piggy-luau` helpers are **temporary and not part of this checkout**.
6. Verify Rojo source sync, then start Play and check startup output. The last
   Phase 3.4 sync attempt found Studio with **no place open**, so that feature's
   live sync/startup/layout verification has not been completed.

### Current implementation and approved decisions

- Master plan foundation through **1.10**, separate tree/ground/storage Acorn
  loop through **2.5**, and carry handoff/keep/return code through **3.3** are
  implemented. Detailed validation limits are recorded in the entries below.
- **3.4 is implemented on disk:** cream street badges distinguish NEW HERE,
  SHIELD, ROBBED, EMPTY and CAPPED; no Acorn counts on the street badge.
  Owners see **RECOVER SKIN**, others see HOT SKIN. The private recovery task
  shows the actual stolen skin thumbnail and timer; select it for details.
- Acorn theft cooldown appears **only on nearby tree/crate prompts**, with an
  hourglass and **Steal ready in m:ss**. Player cooldowns are private and shared
  across both sources; resident rest remains shared. Own harvesting is exempt.
- Recovery remains tied to the last taker of that owner's particular skin,
  independent of the robber's outfit or later thefts from other players.
  Multiple owners retain separate claims and timers against the same robber.
- The approved exploratory mockup is archived at
  `docs/design/rob-badge-mockup.html`. It is the conversation HTML fragment;
  it uses host-provided Lucide/Tweak helpers. It is a design reference, not a
  Studio screenshot. The nearby cooldown cue was approved after that mockup.
- Imported guards are integrated; see `assets/guards/README.md` and the guard
  entry below. Phoenix art/generator/validation/effect companion work is also
  included; see `assets/phoenix/README.md`. **Phoenix runtime skin integration,
  real imported-asset placement and published animation ID remain pending.**
- Generated `.glb`/`.fbx` exports and Blender outputs covered by existing
  `.gitignore` rules are regenerated with the committed scripts. Asset folders
  document their rebuild/import steps; no dependency on those ignored exports
  is needed to run the currently integrated guard/tree/crate gameplay.

### Next work, in order

1. Verify 3.4 in Studio: four badge states from pavement distance, own/bystander
   skin tags, task thumbnail and expand/collapse on phone/desktop, countdown
   expiry, and tree/crate cooldown visibility only at interaction range.
2. Finish the **3.3 two-player pursuit, return and keep** test, including both
   clients' toasts, carried poses, transferred skins and recovery targets.
3. Complete the outstanding live Acorn drag/catch/getaway and full mobile HUD
   review. Earlier native component bounds tests are not full gameplay passes.
4. Continue **Phase 4.1 (robbery ranks and plot-sign stars)** after those gates,
   unless the user explicitly chooses to advance earlier. Follow
   `docs/MASTER-PLAN.md`; do not restart completed implementation steps.

### Last verified checks

- **1,267 isolated checks across eighteen suites**, **102 Luau scripts compile**,
  Rojo build succeeds, and `git diff --check` is clean.
- Example targeted command:
  `python3 tests/run-crates.py --luau /path/to/luau --suite badges`.
  The runner's `--help` lists all suites; the default runs only `crates`.
- Build: `rojo build default.project.json -o RobAPiggyBank.rbxlx` (ignored output).
- No live player balances/saves were changed by these checks. No Roblox live
  place publication was performed. Studio visual checks are still pending.

## Imported guard integration — 2026-09-16

- Replaced primitive guard geometry with the eight imported mesh creatures;
  preserved gameplay anchors, kennel/toys, coat/name cosmetics, bait, sleep,
  cooldowns and paid guard-duty vest.
- Five defaults: Terrier, Shepherd, Mastiff, Dire Wolf, Cerberus. Gorilla and
  Raptor are tier-4 wardrobe skins (250k each); Triceratops tier 5 (500k).
  Tier 4/5 upgrades follow existing 5k × 2.6^level pricing; new stats in Config.
- `GuardVisual` repairs Root-attached facial/foot meshes from authored report
  bone assignments. `GuardAnimator` runs local Motor6D motions and red eyes
  from authoritative `GuardState`; all three Cerberus jaws are independent.
- Mesh IDs, sizes and original mesh extents recorded in `assets/guards/studio-imports.json`.
  `blender/guards/build_runtime_assets.py` generates the catalog and eight
  ServerStorage RBXMX templates, mapped in the Rojo project.
- Source imports archived in Studio ServerStorage.GuardImportArchive.
  No hellhound/silverback in the active catalog. No live-place publication.
- Studio regression fixture: `tests/studio/guards.luau`. All eight rigs passed
  part/bone/coat/upgrade/duty/reset/catch/bait/sleep tests. The 54 save and
  90 rebirth checks also passed. Temporary test scripts/fixtures removed;
  Studio left in Edit mode. Client sampling verified six
  red Cerberus eyes and independent moving jaws. Viewport capture timed out;
  direct screen capture returned desktop wallpaper, so no screenshot QA pass.

## Earlier reconnect notes — September 15

**Mac reconnect update — 2026-09-15:** `main` is current and the Rojo 7.7
checkpoint builds. Studio MCP connects to the correct place, and Rojo's Edit
session connects to `localhost:34872`. All 89 project scripts matched disk;
a temporary module also confirmed live file syncing and was removed. Allow
Rojo's script-modification permission when prompted. Connect Rojo in **Edit**
mode: connecting from Play's Client produces `Http requests can only be
executed by game server`.

The iPhone 17 Pro landscape HUD loaded (750×361 safe-area viewport), but this
Mac's MCP viewport captures timed out. Direct Edit-mode regression snippets
also hit Studio's script-capability restrictions when requiring/cloning game
modules. These are incomplete checks, not a verified HUD pass. Pointer drags,
boost-state visuals, desktop/Android review and persistence remain pending.

The user paused the session to move to another machine, then requested a
commit and push of the current changes to `main`.

**The user has resumed the master plan despite the pending HUD review.** Prior
HUD request: move the left menu farther left, replace the oversized/ugly
`USE 2x` boost HUD, fix dragging/reordering hotbar items, and redesign the
next-event countdown. The implementation is on disk and synced through
Rojo, but the latest changes still need a live Studio play-test and visual
review. Do not report this HUD pass as fully verified yet.

## Latest development — Phase 3.4 badges/recovery/Acorn cues (September 16)

- User approved the cream-card mockup, then removed the Acorn street row.
  Tree/ground/crate contents remain visible on the props. RECOVER SKIN replaces
  YOUR SKIN for the rightful owner; other viewers see HOT SKIN.
- RobBadge now distinguishes NEW HERE from SHIELD and follows server refusal
  order through ROBBED, EMPTY and CAPPED. Rush worth and unlocked casing pips
  remain. Server publishes public cap/hot deadlines without claimant identities
  or skin keys. Income/refunds/reacquisition/expiry clear applicable states.
- FirstJob retains existing private authoritative recovery objectives, now as a
  compact task with the actual claimed skin's model and countdown. Tapping
  expands details. CHASE/HOME cover transported copies; claim priority and
  independent stacked deadlines stay unchanged. Buy-back still opens Crates.
- Nearby tree/crate prompts show an hourglass and Steal ready in m:ss. Private
  player-target deadlines share both sources; resident rest remains shared.
  Own harvesting is unaffected. Late subscriptions receive only their own
  snapshot; no client timer is accepted. Expiry restores ready prompts locally.
- **1,267 isolated checks pass in eighteen suites; all 102 source scripts
  compile, Rojo builds, and whitespace checks pass.** Checks include cooldown
  privacy/source switches/expiry, changing plot owners, exact-key thumbnails,
  thumbnail reuse/cleanup, stacked tags and live cap income/refund transitions.
- Rojo is serving this project on localhost:34872. Studio MCP initially found
  the place in Edit, then reported **Place is not open** during source checks.
  User has been asked to reopen it. Live source-sync, native layout/input and
  the 3.4 pavement screenshot remain pending; do not call the visual gate passed.
  The earlier 3.3 live two-player pursuit/return/keep gate also remains pending.

## Latest development — Phase 3.3 keep/return settlement (September 16)

- Implemented both drop-offs using the existing empty `DeliverRequest`.
  Server checks living holder/claimant, actual 3D position, current destination
  occupant and no active crack/collection. Acorns drop at crates; coins use the
  existing pig/plot radius. Returning your own intercepted haul is a return.
- Original claimant payouts remain unchanged. Other keepers receive half the
  RAW coins/Acorns rounded down, plus all carried items, with no revenge/spree/
  rebirth multiplier. This resolves conflicting plan wording in favor of its
  explicit 0.5x anti-farming example. Keeping counts one completed getaway.
- Returns restore all raw currency/items; Acorn receipts restore storage or
  ground as appropriate. One 25% bounty, floored, goes to the return deliverer
  in the returned currency. Own harvests and claimant undos mint no bounty.
  Returns do not count robberies or mint a coin reward for returning Acorns.
- The final keeper receives the skin and becomes its recovery/revenge target.
  Intercepted recoveries preserve the original recovery owner's claim against
  the final keeper. An interceptor gets no insured spare; the original owner
  can still recover that exact insured copy. Unrelated claims remain intact.
- Both destinations, owner names and reward amounts now appear on a carry card
  via `CarryDelivery` / `LootHaul`. KEEP/RETURN uses the existing tap/F request.
  Item-only carries work. The old carry banner is replaced to avoid overlapping
  the card; crack/collection panels hide the card and action while active.
- **1,219 isolated checks pass** across seventeen suites, including 76 new
  settlement and 15 presentation checks. Four old identity checks were retired
  because non-claimant delivery is now supported. **102 scripts compile**, Rojo
  builds, and Studio Play reaches Ready without feature errors.
- Native client fixtures cloned the real card/button and confirmed unclipped
  labels, in-bounds controls and an 8px gap at 1399×793, 750×361, 480×320 and
  320×568. These are component layout checks, not a complete mobile HUD review.
  Fixtures changed no player balances/saves. Existing pass-ID/MaxPlayers/mane
  warnings remain; concurrent guard work is separate.
- **Still required for the plan's 3.3 completion gate:** a live two-player
  pursuit, return and keep session, checking both players' toasts and carried
  poses. Isolated player/physics doubles are not that multiplayer verification.
  After that, 3.4 is the badge-row design/art step.

## Latest development — Phase 3.2 completed-tug handoff (September 16)

- Completed player tugs now move the same loot model, prompt and carry record
  to the winning nabber. `claimant` and victim remain fixed; `holder` changes.
  Coins, whole Acorns, source receipts and staged skins remain intact.
- Ticks advance time/contribution only: no per-tick refund, amount reduction or
  minted bounty. The first tick waits its interval; a clean tug takes one second
  regardless of crowd, currency or a haul-only carry. Opening closes the current
  crack/collection round. Highest eligible contribution wins; ties use join order.
- The old holder is empty-handed and loses the carry slow without a stun. The
  winner gets carry speed, loses shield/sneak, and gets three seconds of rest.
  Victim markers, prompt owner text and both HUDs follow the transfer. The prompt
  binds to the record's current holder, allowing the original claimant to nab it
  back after rest. Only successful handoffs award catch credit/effects.
- Transfer rechecks live nearby characters, empty hands and the exact root weld.
  Missing/dead/departed/busy winners or broken attachments preserve old escrow.
  Per-tug/carry tokens prevent old coroutines from touching replacement attempts.
  Confiscation/delivery invalidates a tug; those endings do not award catches.
- Dog and patrol paths retain full refunds and haul return; dog stun is unchanged.
  Acorn collection cannot append to a non-claimant's transferred basket.
- **1,132 isolated checks pass** in fifteen suites, including **78 new handoff
  checks** executing the actual private transfer, public nab, prompt callback,
  timed coroutine, cancellation and confiscation paths with player/physics doubles.
  **101 source scripts compile**, Rojo builds, and whitespace checks pass.
- Fresh Studio Play reaches Ready with no handoff/startup errors. HeistService
  and Config exactly match the running server sources after Rojo sync. Existing
  pass-ID and MaxPlayers warnings remain. Live two-player welding/pose and pursuit testing
  is still pending; isolated physics doubles are not a multiplayer visual pass.
- **Next: 3.3**, victim-return and alternate-holder keep payouts/drop-off choices.
  Current non-claimants carry and can be re-nabbed, but do not cash out until that
  step. Original-claimant delivery is unchanged; unusable home delivery prompts
  are suppressed for non-claimants in the meantime.

## Latest development — Imported storage crate + Phase 3.1 (September 16)

- Integrated the user's imported `Workspace.AcornStorageCrate`: four mesh
  parts, shared atlas, measured bottom-centre offsets, 3.6 × 1.9 × 2.8 XYZ.
  All residential plots now clone cached templates. The existing `Storage`
  floor remains an invisible interaction/fill anchor; mesh-load failure keeps
  the complete wooden fallback. The woven transport basket is unchanged.
- Archived the Studio IDs/measurements and a portable assembly under
  `assets/crate/AcornStorageCrate.json` / `.rbxmx`; Blender source remains there.
- **3.1 implemented:** `Carry.claimant` records the original grabber and
  `Carry.holder` records the player whose character carries the loot. One
  constructor initializes both after successful crack, smash or Acorn catch
  attachment. Additional slices/catches retain the existing identity.
- Both delivery entry points validate holder and claimant. Original-holder
  coin, skin and Acorn payouts remain unchanged. Missing/mismatched identities
  cannot settle and leave escrow intact. Phase 3.3 will add non-claimant
  settlement; Phase 3.2 transfer is not implemented yet.
- **1,054 isolated checks pass** across all fourteen suites; **98 source
  scripts compile** and Rojo builds. Tests cover both crate orientations,
  mesh cache/failure cleanup, retained floor anchor and refused-delivery escrow.
- Fresh Studio Play verified ten crates / forty imported parts, correct atlas,
  anchors and non-colliding visuals. The real-client display fixture passed
  0/3/8/24/200/0 stored counts, independent tree/ground contents and cleanup.
  No feature boot errors; existing pass-ID, MaxPlayers and stale mane warnings
  remain. Fixtures only change local display objects, never player balances.
- All 101 current sources match Studio Edit after the final sync (additional
  scripts arrived from concurrent work after compilation). Studio left in Edit.
  Live pointer collection, carried-pose review and end-to-end getaway remain
  pending; structural/display checks do not replace those play-tests.
- **Next: 3.2**, completed tug transfers the intact carry to the winning nabber
  while retaining claimant; then 3.3 adds the victim-return/alternate-holder exits.

## Latest development — Phase 2.5 resident Acorn supply (September 16)

- Implemented `ResidentAcorns` and real ResidentService seat/tick/evict wiring.
  Each residential plot gets four starting Acorns total: two ripe, two stored.
  The seed happens once per plot per server lifetime; shops have no Acorn stock.
  `resident.acornStock` is separate from resident carried coin `.loot`.
- Same one/hour tree growth and eight-ripe cap as players. Stored balance does
  not stop growth. A crop starting on an empty tree waits fifteen minutes;
  a resident at home then banks ripe stock. Ground leftovers and live collection
  leases postpone harvest. This conserves stock and introduces no new NPC
  harvest/carry animation. Coin production/raids stay unchanged.
- Valid resident Acorn openings start a shared 15-minute deadline across all
  thieves and both sources. Invalid/empty openings consume nothing. Prompt
  counters show RESTING m:ss and restore ripe/stored counts at expiry.
  Player-target Acorn cooldown remains 60 seconds per thief/victim.
- Claiming a property freezes resident production/harvesting. Releasing it
  restores the same stock and partial growth hour, never a new seed or a
  hidden growing tree. Raid/ground expiry remains real-time. Old in-flight
  receipts refund retained stock without crediting the new player occupant.
- Corrected the new-growth economy model, which previously counted some
  player crops as both own harvest and theft. Full capture at parity gives
  10 solo / 5.25 full per player-hour; own-harvest-only capture gives 1.25 at
  eight players. These are fresh-production scenarios, not observed earnings
  or an all-income ceiling. Initial seeds and re-raids of existing storage
  are excluded. No growth rate, payout multiplier or crate price was changed.
- **1,004 isolated checks pass**, including 36 resident stock/service checks,
  eight new shared-cooldown/refund checks and native-prompt behavior covered
  by both isolated and real-client fixtures. **97 scripts compile**, Rojo
  builds, and all source scripts match Studio Edit. Fresh Play boots cleanly
  for this feature; existing pass-ID and max-player warnings remain.
- Real client verified all nine resident houses at 2 ripe + 2 stored, using
  imported Acorn visuals and enabled H/J prompts; all four shops excluded.
  Local countdown fixture verified RESTING → counts and no cooldown leakage
  to a new player occupant. Fixture removed; no player balance/save edited.
- Natural 15-minute/one-hour timing is covered with deterministic clocks,
  including a 24-hour conservation run and actual ResidentService integration.
  Live player drag/catch/getaway and carry-pose review (2.4) remain pending.
- Updated master-plan §§3–5, §17, Phase 2.5 and `docs/GAME.md` to match.
  Final generated storage-crate art was integrated in the later 3.1 entry above.
- Next implementation: **3.1**, separate a haul's original claimant from its
  current holder, before the Phase 3.2 completed-tug transfer.

## Latest development — Tree → carry basket → storage crate (September 16)

This designer-approved correction supersedes the older 2.2/2.3 behavior below.

- Trees now grow into saved `treeAcorns` (one/hour, eight ripe maximum),
  independently of stored `loot`. Existing Acorn balances remain banked and
  are never copied into the tree. Offline/partial-hour growth is retained.
- H/Y at a tree opens a five-second collection round. One ripe Acorn is
  sufficient. Shaking moves ripe stock onto the ground; drag the offered
  Acorns into the carry basket. All icons stay available through the timer.
  Missed ground stock lasts 60 seconds and can be collected again. Tree and
  ground counts/timestamp persist; reconnecting cannot replay a harvest.
- Owners harvest without an alarm, theft cooldown or loss cap, and can retry
  leftovers with their own harvest basket. Own deposits pay one-for-one;
  they never count robberies, create grudges or consume revenge.
- J/X at another property's storage crate opens the same timed drag round.
  Quarter-share storage raids offer at least one if stock exists, bounded by
  four net losses per victim per rolling hour. Tree theft uses loose supply,
  independently of that storage budget. Both theft sources share the 60-second
  thief/victim cooldown and existing owner/dog/interruption protections.
  J avoids the hotbar's existing R binding.
- Imported woven baskets are exclusively transport. Residential properties
  have an open wooden `AcornStorage` blockout, 3.6 wide × 2.8 deep × 1.9 tall,
  at the old basket location. Carry delivery is at one's own crate. Storage
  labels always show the exact balance, including zero and 200; no PACKED.
  Imported Acorns are visible in tree, on ground, in storage and in carry.
- Source-tagged receipts preserve refunds: storage returns release matching
  loss receipts; tree returns go to loose ground with a fresh collection
  window, never directly into the wallet. Death/departure settlement still
  occurs before saving. Concurrent reservations and catch replay checks apply
  to both sources. Final tree/storage visual parts do not affect physics.
- **937 isolated checks pass**, all **96 source scripts compile**, Rojo builds
  and all 96 sources match Studio Edit. Fresh Play boots without Acorn errors.
  Real-client display fixtures passed exact 0/3/8/24/200/0 storage labels,
  eight stored plus eight ripe, shake-to-ground, catch/expiry and cleanup.
  Only local display fixtures were changed; no player balance was edited for
  tests. Final Play confirms ten crates, own harvesting enabled, own storage
  raiding disabled, nine other raid prompts on J, and a 440×284 collection
  panel. Existing pass IDs/player-cap warnings remain.
- **Live pointer collection, carried pose and end-to-end deposit still need
  play-testing.** The panel is a close-up representation of loose ground or
  crate contents; world Acorns are synchronized decorative models.
- Final crate art is pending import. Prompt and asset contract:
  `assets/crate/BLENDER-PROMPT.md`. Master plan sections 4–5 and Phase 2 plus
  `docs/GAME.md` describe the revised behavior.
- Next: Phase 2.4 live carry/gesture review, then 2.5 resident supply. Resident
  seeding/harvesting/regrowth/cadence remain unimplemented. Previous supply
  audit numbers are explicitly marked as needing tuning for separate stock.

## Latest development — Phase 2.3 shake and imported Acorn

- Implemented `HeistService.shake` / `ShakeService` and `Shared/Shake`.
  Residential trunks offer a half-second SHAKE hold on **H** (gamepad Y);
  client hides your own prompt and prompts while carrying/shaking. Shops
  receive none. Opening sounds the alarm, alerts the owner, drops the
  thief's shield/sneak and invokes the existing dog response.
- Four-second panel uses Theme's existing Acorn glyph, 56px drag targets,
  a 160×50 basket target, countdown, confirmed caught count and RUN. Mouse
  and touch each own their gesture; unrelated touches cannot finish it.
  Controller A catches a selected Acorn. The canopy shivers on all clients.
- Server schedules each Acorn, accepts only its unique attempt/index in its
  lifetime and rechecks range, life, stun/bin/ride state, owner interruption
  and plot occupant on every catch. Takes a floored quarter, at most four
  per victim in an actual rolling hour. Concurrent reservations share that
  budget. Repeat shakes wait 60 seconds; refusals name the reason.
- Added the carry settlement needed by 2.3/2.3a: catches debit one raw Acorn
  into a carried basket; only delivery at your own basket applies x1 for a
  resident or x5 + rebirth difference for a player, doubled for revenge.
  Coin/spree/friend/event bonuses do not multiply Acorns. Delivery counts one
  robbery, creates a player grudge, and keeps coin totals/weekly stats separate.
- Basket carries use existing slow/dodge/bin/jam/nab/patrol paths. Tug recovery
  returns whole Acorns without a coin bounty; dog/patrol/death and either
  participant's departure refund raw receipts. `DataService.onBeforeRelease`
  settles basket escrow before the final save. Receipts prevent duplicate
  refunds or an old return clearing newer losses from the rolling cap.
- User imported `Workspace.acorn` during this task. Wired its Nut/Cap/Stem
  mesh IDs and texture into `Config.ACORN_MESH`, with Studio-measured offsets
  and bounds (0.594×0.827×0.594). `AcornModel` prewarms a replicated template
  for basket fill, growth drops and carried contents. The original uploaded
  assembly is archived in `assets/acorn/acorn.json` and `acorn.rbxmx`; the
  original source GLB is still unavailable. 2D panel/HUD glyph is retained.
- **894 isolated checks pass**, including 36 shake authority, 36 basket
  settlement and 36 mouse/touch/controller/layout checks. All **95 scripts**
  compile, Rojo builds, and all 95 match Studio in Edit. Fresh Play boots with
  no shake/Acorn runtime errors. Existing pass IDs/max-player warnings remain;
  this boot also reported an unrelated stale mane mesh dimension warning.
- Running client verified ten shake prompts, own prompt disabled, and a
  440×284 panel / 56px targets / 160×50 basket inside a 750×361 test viewport.
  Imported fill fixture passed 0/3/8/20/0 counts, white tint, exactly three
  MeshParts per Acorn, no collision/query/touch and cleanup/re-entry.
- **Live drag/catch/delivery and visual review remain pending.** MCP refused
  a synthetic `ShakeState:FireClient` because of script capabilities; no
  bypass attempted. The mouse test therefore had no panel to operate on.
  Native computer-use capture also failed to initialize on this Mac. Isolated
  gesture tests are not a live phone pass. Temporary fixture vanished on
  restarting Play; no player balance/save was edited for testing.
- Next: **2.4 carry presentation/engine review** (core safe settlement is
  already in place); **2.5 resident basket seeding/regrowth and 15-minute
  cadence remain unimplemented**. Residents currently have no seeded Acorns;
  their existing `.loot` continues to mean stolen coins, never Acorns. Full
  shake economy audit figures remain modeled until resident supply lands.

## Latest development — Phase 2.2 growth and basket fill

- User approved the 2.1 oak/basket appearance. Implemented hourly Acorn growth
  in the existing server economy loop and offline-income path. Eight hours
  fills an empty wallet to eight; balances above eight are preserved.
- Saved `acornsGrownAt` retains partial hours through autosave/rejoin. Legacy
  saves use `lastSave` within the eight-hour allowance. Invalid/future cursors
  reset safely; time spent full is discarded. Income, friend and daily boosts
  do not multiply growth. The pig being full does not stop Acorn growth.
- `PLOT_ACORNS_ATTRIBUTE` publishes the wallet on the residential plot. The
  client draws up to eight Acorns inside the basket and PACKED above eight.
  HUD/crate/shop affordability follows the exact balance through StateUpdate;
  other services' balance changes repaint within one economy tick. Ownership
  changes clear the display; delayed/streamed/replaced plots are handled.
- `AcornGrown` is a server-only cosmetic cue for a falling Acorn on live growth.
  Offline catch-up draws the final pile silently. Client parts are anchored,
  non-colliding/non-queryable/non-touching, with bounded, cleaned-up flights.
- **Art limitation:** the plan's `assets/acorn/acorn.glb` is missing in this
  checkout; no named standalone Acorn was found in Studio. The fill uses small
  two-tone modeled Acorns from `AcornFill` until the intended mesh is supplied.
  Full/empty readability and the drop's appearance still need visual review.
- **784 isolated checks** pass, including 40 growth, 43 client-fill lifecycle,
  and 49 save checks. All 92 source scripts compile and Rojo builds. All 92
  match Studio through Rojo in Edit. Restarted Play boots without new errors.
- The actual running client passed temporary-fixture checks at 0/3/8/20/0:
  exact capped fill, PACKED only above eight, no physics/query/touch effects,
  and removal/re-entry cleanup. Fixture destroyed; no player balance/save
  was edited. Live growth/drop timing is covered by the isolated economy and
  renderer tests; the hourly production clock was not accelerated.
- Next: **2.3**, the shake interaction and its Art 4 panel design. Resident
  basket seeding/regrowth stays in 2.5; resident carried coin `.loot` is not
  used as an Acorn wallet. Shaking/carrying are not implemented yet.

## Latest development — Phase 2.1 basket integration

- Finished the residential tree/basket placement foundation. `AcornBasket`
  loads the imported hollow bowl and handles once, then clones the assembly
  at plot-local (-20, 16), beside the oak at (-25, 16). It follows both plot
  orientations and stays on the lawn across ownership changes. Shops get
  neither a tree nor a basket.
- Mesh/texture references are in `Config.ACORN_BASKET_MESH`, with measured
  offsets and original dimensions. Both parts are anchored, non-colliding,
  non-queryable and non-touching. `plot.acornBasket` keeps body/handle refs
  for the later fill and carry work. No saved balance or earnings changed.
- Studio Edit checks loaded the real uploaded assets and measured both rows:
  0.625 studs clear of the oak wood bounding box, 8.35 from the front fence
  and 12.33 from the side fence; bottom at lawn height. Temporary fixtures
  were removed. The prior `lawnI` migration still shelves owned decorations.
- **689 isolated checks** pass, including 89 oak/basket checks. All 91 source
  scripts compile and Rojo builds; all 91 match Studio in Edit mode through
  Rojo. Full in-game visual review remains pending.
- Next: **2.2**, online/offline growth and the Acorn fill display (up to eight,
  then PACKED). The basket is currently empty scenery; filling, prompts,
  shaking and carrying are not implemented. Art 7's full/empty readability
  check remains tied to that display.

## Latest integration — imported compact oak

- The designer imported `assets/tree/blender/oak.glb` into Studio. Recorded
  its uploaded mesh/texture references in `Config.ACORN_OAK_MESH`; all
  residential plots now build this 8.5-stud oak, including resident yards.
  Shops remain tree-free. Street `TREE_MESH` is unchanged.
- Used Studio's measured offsets: the importer reverses X/Z relative to the
  GLB report. The builder keeps the white texture tint and the ground pivot.
  A 1.3 × 3.4 × 1.3 invisible trunk collider prevents the branch mesh's wide
  bounding box from blocking empty lawn. Visual meshes do not collide/query.
- Studio Edit checks loaded both uploaded meshes through InsertService,
  verified dimensions, grounded both plot orientations and tested raycasts
  against the trunk/open branch space. Side/front fence-line clearances are
  4.37/6.54 studs. Temporary check geometry was removed; no player save used.
- All **655 isolated checks** pass, including 55 oak checks. All 90 source
  scripts compile and Rojo builds. All 90 scripts match Studio in Edit mode
  through Rojo. A full in-game visual/collision walk-through remains pending.
- Basket placement is now implemented above. Fill display/growth continue
  in 2.2. The old generated oak source stays available as a fallback.

## Latest asset work — compact Blender oak

- The designer installed Blender and asked for a smaller oak based on
  `assets/tree/tree-oak-render-v2.png`. Built an editable candidate with
  separate `Trunk` and `Canopy` meshes in `assets/tree/blender/oak.blend` and
  a textured `oak.glb` export. Source: `blender/tree/build_oak.py`.
- Size: 8.5 studs wide, about 9.25 tall and 4.68 deep. Trunk: 2,400 triangles;
  canopy: 6,400; one 256px base-colour texture. No acorns or basket are baked
  into the tree. The character comparison uses a 5.5-stud block scale guide.
- This is a Blender draft modeled against the approved reference, not an
  automatic image-to-3D reconstruction. The designer subsequently imported
  it; runtime integration and numeric checks are recorded above. The previous
  generated oak remains a fallback. In-game visual review remains pending.
- The installed Blender's bundled NumPy fails against this macOS version;
  a static GLB exporter avoids it. `blender/tree/validate_glb.py` independently
  checks the exported binary and texture. Multi-view and scale previews live
  beside the model. Phase 2 is still incomplete.

## Latest development — Phase 1.10

- Added saved, typed `data.robberies`, defaulting to zero for new and older
  saves without changing schema 25. Existing stolen-coin totals are preserved;
  no historical robbery count is invented. Reconciliation normalizes invalid
  counts to finite nonnegative whole numbers.
- Heist delivery records one lifetime robbery for a nonempty getaway against
  any player, resident or shop. Partial coin hauls and skin-only recoveries
  count; failed getaways, empty carries and repeated delivery requests do not.
  The count is recorded before reward callbacks can save. It survives rebirth
  and uses the existing autosave/final-release path.
- `claims` defaults/reconciliation were already completed in 1.7. The delivery
  increment from 4.1 lands now so progress accumulates before rank UI ships;
  rank thresholds and plot-sign stars remain Phase 4 work.
- Validation: **600 isolated checks** pass (including 37 new DataService
  lifecycle checks, 118 theft checks and 90 rebirth checks). Copying DataStore
  doubles exercise real load/save/release/rejoin and session-lock behavior;
  no live player saves were used. All 89 source scripts compile and Rojo
  builds `/tmp/piggy-step110.rbxlx`.
- Studio was in Play mode during final verification; Edit-mode source sync
  for these changes and live DataStore persistence are not yet verified.
  Stop Play, allow Rojo to sync in Edit, then start a fresh play session.
- Next: Phase 2, starting with 2.1's tree/basket design and implementation.
  Phase 0 remains deferred; 1.3 still depends on the Phase 2 shake system.

## Latest development — Phase 1.9

- Added `Config.auditAcorns` and `Config.auditRandomOutcomes`, warned at boot
  without stopping startup. Main also prints the explicitly labelled tree
  model; tree growth/shakes remain unimplemented Phase 2 work.
- The random-outcome sweep checks crate currencies/prices, authored coin-price
  plus crate tags, actual pool membership (including mixed event sets), pass
  exclusions, guaranteed skin theft, retired rebirth gates, rebirth crate
  existence and the future coin-pack id. `COIN_PACK.productId = 0` reserves
  the later integration point without selling anything.
- **Designer correction preserved:** rebirth still rolls a normal free
  Legendary Crate. A live coin-pack id now warns that it would fund that
  random reward. The approved 40-Acorn full-collection rebirth bonus stays.
- Removed event attendance/per-drone/clear/full-set Acorn payouts and their
  `Config.LOOT` table. Raids keep their coin bounty (including the clear
  bonus) and one free unowned set drop; a full set gets feedback and no
  duplicate/currency fallback. Rush Hour keeps boosted coin steals and has
  no separate attendance payout. No saved balance is migrated or removed.
- Moved 24 crate skins' historical coin-price fields to `sellBasis`, preserving
  their explicit rarities and every sale amount. Unowned crate skins still
  reject direct coin requests; missing `cost` never makes them free.
- Added the planned growth/share/loss constants early so the audit can model
  Phase 2. Its explicit assumptions are one full daily harvest, one passive
  raid/day and two active hours at parity without revenge. Solo/full-server
  rates are **10 / 5.625 Acorns per thief-hour**, with active/passive ratios
  **4.67x / 3.21x**. Full-server common/legendary waits are **53.33 min / 7.11 h**.
  These recompute the plan's rounded estimates; they are not live earning
  rates or a complete launch economy. The current routine tree source is
  still missing; existing balances and the approved rebirth bonus remain.
- Validation: **550 isolated checks** pass, including 167 audit/event checks.
  Every one of the 27 new audit rules was deliberately provoked and restored;
  tests exercise real raid settlement, full-set drops, Rush Hour, stale coin
  purchase requests, boot warning/error handling and unchanged resale values.
  Run `python3 tests/run-crates.py --suite audits --luau /path/to/luau`.
  All 89 source scripts compile, Rojo builds, and all 89 match Studio in Edit
  mode. No live player save was used. Live boot/event/persistence verification
  and Phase 2 earning-rate playtests remain pending.
- Step 1.10 is now implemented above (`claims` landed in 1.7).
  Phase 0 remains deferred and 1.3 still needs Phase 2.

## Latest development — Phase 1.8

- `FirstJob` now shares one card between onboarding and skin recovery. False
  `NeedsFirstJob` retires only onboarding; veterans can still see new losses.
- The private `RecoveryObjective` snapshot comes from HeistService's actual
  haul, timed claims, ownership and seasonal buy-back claims. The client
  subscribes after connecting its listener, retries until its first snapshot,
  and the server polls at 0.25s but sends only changed state. No client claim,
  price or deadline is trusted. Subscription requests are throttled.
- A fresh theft shows **GET IT BACK**, the robber's name and **Nab them now**,
  pointing to the fleeing character. After delivery, it points to the robber's
  pig with the real ten-minute countdown. Its wall-clock deadline is recorded
  alongside the existing monotonic expiry; coin revenge never extends it.
- A carried recovery says **GET IT HOME**, pointing home, including after its
  deadline. When recovery ends, the card becomes **BUY IT BACK — N ACORNS**
  only with a valid unowned seasonal claim. Tapping opens Crates and scrolls
  to that skin; it does not spend Acorns. Expiry flips locally without needing
  a new packet. Buying/recovering/returning the skin clears the objective.
- Stacks prioritize getting a carried skin home, an active chase, then the
  earliest recovery deadline before paid claims, with `+N more` shown. Latest
  takers replace only the same owner's skin target. Insured spares can be
  recovered but never acquire a paid fallback. Missing/disconnected robbers
  fall back to a valid buy-back rather than an unreachable recovery target.
- Card geometry clears the bank/Acorn column on desktop and landscape phones;
  text is bounded/truncated. Shop/bag overlays hide the card and marker.
- Validation: **383 isolated checks** (73 crates, 89 rebirth, 106 theft,
  70 buy-back, 45 objective). Run the new client checks with
  `python3 tests/run-crates.py --suite objective --luau /path/to/luau`.
  Actual theft transitions, private subscription/poll behavior, startup/load
  races, stale clicks, stacked timers, local expiry, navigation and viewport
  bounds are covered. All 89 source files compile and Rojo builds; all 89
  scripts match Studio in Edit mode through Rojo. Engine rendering, live
  multiplayer latency/input and persistence remain unverified;
  no live player saves were used.
- Step 1.9 is now implemented above. Phase 0 remains deferred, 1.3 needs
  Phase 2; step 1.10 is now implemented above.

## Latest development — Phase 1.7

- Losing an owned, stealable skin now saves `claims[key] = seasonIndex`.
  Losing only an insured spare creates no buy-back claim. Claims survive
  rejoining and last through the current five-week season (four active weeks
  plus one rest week, using the existing UTC week epoch).
- Crates shows an exact-skin BUY BACK card beside its source crate, only for
  a current claim whose skin is unowned. Prices are source crate cost times
  `3^rank`: **15 / 45 / 135 Acorns** for common / rare / legendary. The skin
  ladder has three steps; global `epic` does not inflate the legendary price.
- `SkinBuyback` accepts only the skin key. The server checks the claim, season,
  ownership and Acorn balance, then directly calls `SetService.grant`. Its
  save includes the charge and ownership together. No roll/spare is awarded;
  the robber keeps their copy. Repeated requests cannot charge an owned skin.
- Claims stay eligible for the rest of the season, hidden while owned.
  Cosmetic ownership updates refresh crate cards. Requests enforce expiry
  immediately; idle cards expire locally and a server rollover pass clears
  and saves online claims. Reconcile clears offline/invalid claims on load.
- The `claims` default/type/reconcile portion of 1.10 landed before its UI.
  The `robberies` counter remains pending. Only the Phase 5 season clock has
  landed early; ranks/rewards/season UI are still pending.
- Validation: **298 isolated checks** pass (73 crates, 89 rebirth, 69 theft,
  67 buy-back). `python3 tests/run-crates.py --suite buyback --luau /path/to/luau`
  exercises real Config/reconcile/ChestService/SetService and Crates state
  with engine and persistence doubles. It covers price tiers, rejoin, remote
  forgery, reentrant requests, direct grants, rollover and card expiry.
  All 89 source files compile and Rojo builds; all 89 scripts match Studio
  in Edit mode through Rojo. No live player save was used; live purchase,
  input/rendering and DataStore verification remain pending.
- Step 1.8 is now implemented above. Phase 0 remains deferred, 1.3 needs
  Phase 2; step 1.10 is now implemented above.

## Latest development — Phase 1.6

- Clean player cracks now always take an eligible skin; `revengeChance` is
  retired. Ordinary duplicate, protected-skin, spare and hourly-cap rules stay.
- **Designer clarification:** recovery claims stack by original owner, robber
  and skin. Robbing somebody else or changing outfits never erases an earlier
  victim's claim. Only the latest taker of that owner's same skin is valid.
- Each claim lasts `Config.REVENGE.window` from delivery. Coin revenge is
  separate: spending/refreshing it does not consume/extend the skin timer.
- A clean crack recovers one available skin (oldest deadline first) from the
  robber's owned collection, ignoring their outfit, skin-loss cap and spare
  insurance. It still needs to reach home; getting caught returns the copy
  and allows a retry inside the original window. An originally stolen spare
  is restored as that spare, with no ordinary duplicate-spare payout.
- Skin transfers are staged on the carry before any save can yield. Returning
  a carry drains its haul once and only refunds the matching loss window.
- Tests: 67 isolated checks in `tests/luau/theft.luau`, run with
  `python3 tests/run-crates.py --suite theft --luau /path/to/luau`.
  Full HeistService logic runs with service doubles and physical carry cleanup
  stubbed. Multiple victims, timers, latest taker, changed outfits, failed
  getaways, insurance and coin settlement are covered. Live multiplayer input
  and visuals remain unverified; no player saves were used. The 89 rebirth
  and 73 crate checks also pass (229 total). Luau compilation and Rojo build
  pass; Config and HeistService match Studio in Edit mode through Rojo.
- Step 1.7 is now implemented above. Phase 0 remains deferred and 1.3 needs
  Phase 2; step 1.10 is now implemented above.

## Latest development — Phase 1.5–1.5b

- **Designer correction:** rebirth opens a standard free Legendary Crate;
  do not implement next-unowned-in-order rewards. Normal 65% rare / 35%
  legendary odds and duplicate spares apply. Existing equipped skin stays on.
- Full eligible legendary collection still receives 40 Acorns instead.
- Bronze/Gold Leaf/Diamond now belong to `og`, retain explicit rarities and
  can be stolen. Their old rebirth-count ownership gates are removed.
- Schema 25 migrates earned ownership once using historical thresholds 1/3/6.
  Rejoining does not grant duplicates or restore a later sold/stolen skin.
  The retired pity field is removed; coins, Acorns and spares are untouched.
- The rebirth page shows a crate or completion Acorns. Old random-drop/pity
  helpers and unlock announcements are removed; the economy audit catches
  retired ownership gates anywhere in Config.
- Validation: 89 isolated checks in `tests/luau/rebirth.luau`, run with
  `python3 tests/run-crates.py --suite rebirth --luau /path/to/luau`.
  These use real services/reconciliation with engine and persistence doubles;
  no live player data is used. The 73 crate checks also pass, along with Luau
  compilation and Rojo build. All nine modified scripts match Studio through
  Rojo, in Edit mode. Live rebirth/reveal review remains pending.
- Step 1.6 is now implemented above. Phase 0 remains
  deferred. Step 1.3 still depends on Phase 2; 1.10 is now implemented above
  using the existing schema 25 from the ownership migration.

## Latest development — Phase 1.4

- User requested continuing the master plan; step 1.3 depends on Phase 2,
  so step 1.4 is the next independent implementation.
- All crates now charge existing `data.loot` Acorns: Originals/Animal 5,
  Rare 15, Legendary 40, Alien unchanged at 6. No balance migration.
- Server refuses coin/missing/unknown crate currencies before rolling.
  The card and refusal show the shortfall and tree-shaking hint; tree earning
  remains unimplemented, so this is not ready to publish as a complete economy.
- Regular crates retain combining via `Config.canCombineChest` and the
  server's `canCombine` card flag. Event-set crates remain excluded.
- `auditEconomy` catches a non-Acorn crate, separately from coin capacity.
- `python3 tests/run-crates.py --luau /tmp/piggy-luau/luau` runs isolated
  full-service tests without player data. Roblox constructors are stubbed;
  rendering, replication and persistence are outside that harness.
- Validation: 73 isolated crate checks pass; Luau compilation and Rojo build
  pass. Live card properties show correct prices and combine flags on desktop,
  iPhone 17 Pro (750×361) and Galaxy A06 (705×338). Phone title truncation was
  fixed with bounded text sizing; the equivalent live properties and a
  temporary shortfall-label fixture fit on both phones. This is property-level
  validation, not screenshot review; no crate purchases used the live save.
- Studio output showed no crate runtime errors. Existing warnings remain:
  three pass IDs are unset and the place allows 60 players versus Config's 8.
- Step 1.5 and its skin-ownership migration are now implemented above.
  Phase 0 is still deferred; HUD visual/input checks remain open separately.

## Project and workflow

- Game: **Rob A Piggy Bank**; an under-12 cartoon robbery game. Cream panels,
  cocoa outlines, gold coins, pink piggies, static detailed menu icons.
- Read `docs/MASTER-PLAN.md` for sequencing and `docs/GAME.md` for the
  implementation map. **Phase 0 is deferred by the user's instruction.**
- Rojo project: `default.project.json`; local server was on port **34872**.
  Start/connect Rojo on the new machine; do not depend on this host's process.
- Build: `rojo build default.project.json -o <temporary-path>.rbxlx`.
- Place ID **135433647855162**; universe ID **10764556948**.
- `ClientMain.client.luau` is near Luau's 200-local ceiling. Put new UI builders
  in shared modules and avoid adding top-level locals to the client.
- No Roblox publish was performed. Git push is separate from publishing.
- The last observed Studio state was **Edit**, default desktop viewport,
  connected to Rojo. The place was reopened from Studio's recent experiences
  after it closed during this session.
- This Mac used StudioMCP through a temporary Python stdio bridge.
  That bridge and the local Studio ID are machine-specific and not committed.
  Discover/connect the Studio tools available on the new machine.

## Completed earlier: mobile HUD overhaul

- `PiggyPanel.luau`: dynamic vault fill, balance/capacity/income, compact
  phone layout (252×64), larger desktop layout (420×128).
- `MenuIcons.luau`: static, transparent cartoon Options, Stuff and Shop icons.
- `ActionButtons.luau`: static illustrated Dodge, Ride and Sneak controls.
- `HUDLayout.luau`: left menu column; right-thumb actions above jump; ride
  extras positioned separately. All of these came from the user's requests.
- `HotBar.luau`: transparent 3D item previews, stock badges, selection marker,
  overflow paging with up to five mobile items and 44px paging controls.
- `Rebirth.luau`: earlier responsive positioning changes are intentional.
- Prior phone previews are in `assets/mobile-hud`, `assets/menu-icons`, and
  `assets/piggy-hud`. They predate the current follow-up fixes.

## Completed earlier: master-plan 1.1–1.2

- User approved **nut-brown Acorn, green cap, cocoa outline**, matching the
  detailed cartoon menu icons. Do not ask for approval again.
- `Theme.acorn` draws the static glyph in code; `Theme.acornPrice` decorates
  prices and removes its padding/icon when a label changes to owned/equipped.
- `Config.ROLL_CURRENCY` names Acorn/Acorns. **Persisted `data.loot` stays
  unchanged**, preserving existing balances without a migration.
- `PiggyPanel:setAcorns` receives `SetState`; the compact Acorn counter sits
  under the vault's left side, beside the event timer.
- Player-facing currency wording, shop prices, crate price, admin labels and
  carried-goods messages were updated. Internal `loot` names remain where
  they represent saved currency, carried models, remotes or notification types.
- Piggy delivery no longer calls `SetService.award`, includes a currency
  reward in its payload, or names Acorns in receipts. Coin/item settlement,
  revenge coin multiplier and spree coin multiplier remain intact.
- Retired `Config.LOOT.delivery` and `Config.REVENGE.loot`.
- `Config.acornMultiplier(thiefRebirths, victimRebirths, revenge)` is prepared
  for Phase 2: **nil** victim means resident ×1; player starts at ×5, plus
  the positive rebirth gap, then ×2 for revenge. No production caller yet.
- **Tree earning is not implemented.** Crate conversion is now done (1.4);
  the legacy-faucet audit and the other Phase 1 steps are still pending.
- Verified: Rojo build; seven multiplier cases and twelve isolated delivery
  cases in `tests/studio/acorns.luau`; phone HUD/crate visuals; balance
  hydration and spacing; no client errors. Preview images: `assets/acorn-ui`.

## Current HUD follow-up: implemented, needs live review

### Left menu

`HUDLayout.bindMenu` moves x=14 to **x=4 inside the device safe area**.
Check the visible result; the user may want more movement than ten pixels.
Keep the icons reachable and clear of cutouts and the joystick.

### Boost / Use widget

New `HUDWidgets.luau` builds a **60×44** transparent boost control: outlined
cream/gold 2x token, small BOOST caption and stock badge. An active boost
widens to **96×44** with its countdown. Fixed font sizes replace the old
`TextScaled` text. It sits beside the top left-menu icon and follows its size.

ClientMain's existing stock/deadline and `BoostUse` handler are retained;
`HUDWidgets.renderBoost` only renders them. Old competing boost layout code
was removed from `HUDLayout.bindRideExtras`.

### Event countdown

`HUDWidgets.event/renderEvent` replace the old standing countdown builder:
cream outlined ticket, code-drawn green stopwatch, two-line caption/time,
thin progress strip. Authored at 176×40; PiggyPanel's existing compact scale
makes it 132×30. The last-minute state turns the clock/progress gold and says
GET READY. Existing server durations, event gating, active event banner and
police banner logic are retained.

### Hotbar drag fixes

- `InputObject.Position` and GUI `AbsolutePosition` share the same coordinate
  system. Removed the erroneous additional `GetGuiInset()` offset. The ghost
  is positioned using pointer minus the ScreenGui's absolute origin.
- Only the initiating touch can move/end its drag. Mouse movement and release
  are handled separately; joystick touches cannot hijack an item drag.
- The row stays still while aiming. A gold outline previews the nearest
  destination, and the reorder commits **once on release**.
- `HotBarDrag.luau` supplies pure input ownership, target selection and bounds
  helpers. Page-end insertion uses the full arrangement's successor so an
  item does not jump to the final inventory page.
- Releasing outside the row cancels. Shelving requires the explicit compact
  **STORE IN BAG** target; it preserves stock. Previously nearly the whole
  screen above the bar counted as shelving.
- The drag ghost uses the actual slot size. Drag release suppresses accidental
  activation for 0.25 seconds; a fresh intentional press clears suppression.
- Focus loss and viewport resize cancel an active drag.
- **Ladder added to `HotBar.ITEMS`**: its omission caused its saved placement
  to be discarded on the server echo. Appended after raincoat to preserve
  existing item/key order. Server settings allowlist already includes ladder.
- The runtime Remotes dependency is now required only when saving preferences,
  allowing isolated Edit-mode module checks to load without waiting forever.

### Checks actually completed for the follow-up

- Final Rojo checkpoint build passed after the ladder/deferred-Remotes edits;
  `git diff --check` passed too.
- Final `HUDWidgets`, `HUDLayout`, `HotBarDrag`, and `HotBar` module clones
  all loaded successfully in Studio Edit mode.
- `tests/studio/hotbar-drag.luau` passed: left/right neighbour moves, page
  boundaries, empty-stock gaps, no-op drops, touch ownership, mouse input,
  bounds with a negative safe-area origin, and ladder in the save list.
- **Not yet tested:** actual pointer/touch drags, save echo/rejoin persistence,
  boost ready/active/empty visuals, final countdown layout, and runtime errors
  after these UI replacements. The current preview PNGs show the earlier HUD.

## Next actions

1. Pull `main`, start Rojo and connect Studio on the new machine. Preserve any
   local work there before pulling.
2. Build and run a phone play-test. Check the new left menu, boost and event
   widget against the Acorn counter, vault, movement controls and hotbar.
3. Drag items both ways on the same page; verify the final order and key
   labels after the settings echo. Test first/last positions, later pages,
   ladder movement, cancel outside the row, explicit shelving and restoration.
4. Verify a drag does not equip/use/spend an item, and a normal tap still
   selects it. Test a simultaneous movement-stick touch if tooling permits.
   Rejoin to check saved order; restore any test preference changes afterwards.
5. Check boost states using isolated client fixtures if needed. Avoid spending
   the user's saved boost stock solely for a visual check.
6. Check desktop and a smaller Android viewport too, collect current previews,
   and inspect the client error log. Update `docs/GAME.md` with this follow-up
   once the final behavior has been reviewed (it still describes some old
   boost/drag behavior).
7. Continue the master plan alongside the pending HUD review, as requested.
   Phase 0 remains deferred. Step 3.3 is implemented; verify the two-player exits, then design Phase 3.4.
   Step 1.3 depends on the Phase 2 shake system. Respect future
   design gates without reopening the already-approved Acorn icon decision.

## Test execution notes

The scripts in `tests/studio` are Luau snippets for Studio MCP `execute_luau`
in the **Edit** DataModel, after Rojo sync. They do not run automatically from
`default.project.json`. Acorn delivery tests extract the real settlement
function and run it with service doubles; they do not touch player saves.
Avoid testing economy changes by editing the real account's DataService data.

Two initial Edit-mode checks waited for the runtime Remotes folder. A temporary
empty folder released those checks and was removed; subsequent module checks
and drag tests passed. No temporary test module/folder was intentionally kept.

## Repository state at pause

The commit should include the task's source modules, docs, regression snippets
and preview PNGs from this session and the earlier HUD/Acorn work. It is a
checkpoint of work in progress, not a claim that the latest UI pass is done.
The original user-owned `notepad.txt` was already untracked when this work
started. It contains game-design notes and is included unchanged in the
requested checkpoint so it is available on the other machine. Treat these as
notes, not as replacements for the user's instructions or the master plan.
