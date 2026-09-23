# skins/ -- MOVED

**Every skin -- the four legendaries and the shared `metal/` pack included --
now lives in [`assets/piggies/<tier>/<key>/`](../../../assets/piggies/README.md)**
(designer, 2026-09-22): its scene in `source/`, its generator in `generate/`,
its sheets in `sheets/`, its renders in `preview/`, its derived import package
in `package/`, and a `manifest.json` naming the Config row, the SurfacePacks
templates and the live ids. `paths.py` resolves every key there. Tracked files
were `git mv`ed; the untracked scenes and sheets were COPIED, so the old
folders below are now duplicates the designer can delete once happy.
Everything from here down is the note as it stood before the move.

---

# skins/

Current import packages have moved to [assets/skins/animal](../../../assets/skins/animal/README.md):
**8 common, 7 rare, 4 legendary**. That folder is the current source for FBXs,
assembled Blender files, textures, previews, animation exports and effect helpers.
The current package builders now write there. This directory retains procedural
coat sources, concepts, masters and previous revisions. Version names mentioned
below describe the revision history; use the new package index for imports.


## Legendary animal layout revisions

Ice Phoenix has a separate `phoenix/legendary-v1` package: an ivory face,
495 closely layered ice-blue feathers, including 120 leg feathers, a seven-feather
crown and a fuller tail fan. Glowing frost veins run through the plumage;
branching face markings and a forehead motif follow the selected Crystal Crown concept.
A nine-bone rig pins the feather roots while their tips move. The body feathers
follow the skin's contour, with coverts filling the back and snout sides.
The cyan tips have a stronger pulse; masked emission shimmers
in staggered groups over four seconds. The original pig parts, flush vault
opening and clear coin slot remain. Build with
`../make/build_phoenix_legendary.py`, validate/render with
`../make/check_phoenix_vault_fit.py` and `../make/render_phoenix_legendary.py`, then package with
`../make/build_phoenix_legendary_gallery.py`. Original warm Phoenix sources
are preserved. Art approved with the feather edge verified against all four
runtime-sized vault plates, with no measured bare gap. Studio integration remains pending.

Dragon has a separate `dragon/legendary-v1` package: shallow beveled green
scale plates, curved horns, compact scalloped wings, and a tail fin. The old
belly/glow bands are replaced by continuous ember seams projected from the
actual scale borders. A four-bone rig supplies a slow wing/tail idle; separate
emissive masks and `DragonGlow.luau` supply breathing glow across the scaled coat. The original pig silhouette,
coin slot and flush vault bore remain. Build with `../make/build_dragon_legendary.py`,
validate/render with `../make/render_dragon_preview.py`, then run
`../make/build_dragon_gallery.py`. Raised-scale revision; Studio integration pending.

Rainbow Tiger's active package is **`rainbowtiger/legendary-v2-swept`**, built
from approved option C: compact charcoal cheek locks, inner-corner ear tufts,
relaxed brows, clean painted wraparound stripes, one inner/outer stripe per eye,
bare feet and a smooth rainbow tail. The coat, fur and tail color maps are embedded in
the FBX. Build with `../make/build_rainbowtiger_swept.py`, validate/render with
`../make/render_rainbowtiger_preview.py -- --swept`, then publish via
`../make/build_rainbowtiger_swept_gallery.py`. Previous v1 and clean-review scenes
remain preserved. Studio import and material animation integration are pending.

Storm Wolf's mohawk. Individually outlined broad rainbow stripes
carry a gentle four-second emission pulse; both eyes smoothly cycle RGB with
steady glow. Inner-forehead markings, four foot cuffs and a continuous textured
silver-to-rainbow tail plume complete the latest detail pass. A four-bone rig supplies small tail/ruff
motion. The old painted skin is preserved. Build with
`../make/build_rainbowtiger_legendary.py`, render/validate motion with
`../make/render_rainbowtiger_preview.py`, then publish its handoff with
`../make/build_rainbowtiger_gallery.py`. Fresh Studio imports and Fable's runtime
integration remain pending; the FBX carries bone motion, not material animation.

Storm Wolf's existing painted model has a separate `stormwolf/layout-v1`
revision and [review gallery](../../../assets/skins/animal/legendary/index.html).
It adds a hollow interior and flush rear vault opening, with the original
tail centered just above it and projecting outward with a low lift. User review explicitly rejected a protruding vault
collar and a side-mounted tail. The mane must stay continuous over the coin
deposit location: no visible coin slot or raised rim. Rebuild using
`../make/build_stormwolf_layout.py`, then `../make/build_legendary_gallery.py`.
Original source files are preserved; Studio integration remains pending.

All of the old blue bolt plates are replaced by long, chunky branching lightning.
`../make/stormwolf_lightning.py` authors six independent groups with rapid
stepped flashes; `../make/render_stormwolf_lightning.py` renders the motion
preview before rebuilding the gallery. The package includes an uninstalled
Studio playback helper generated from the same timing data. The cyan lightning
painted on the coat has its own emissive mask and synchronized brightness pulses,
authored by `../make/stormwolf_body_glow.py`. Follow the package import notes to
assign the mask and enable the helper's body glow in Studio.

## Rare animal coats

Seven first-pass rare designs live in `strawberrycow`, `cookiescream`,
`watermelon`, `peppermint`, `glacier`, `bubblegumleopard` and `honeycomb`.
Their palettes are in `../rare_coats.py`; `../make/build_rare_coat.py` derives
the coats from the common procedural scenes without saving the parents.
Each has a local generator entry point and a complete `asset-v1` package.
[Rare review gallery](../../../assets/skins/animal/rare/index.html).

These coats use separate `_emissive.png` masks for small static glow accents.
The colour maps stay opaque. Roblox now supports emissive masks on
SurfaceAppearance; follow the package import notes, since the older notes
below predate that feature. The crate pool and runtime are unchanged.

## Complete animal asset packages

The eight existing animal coats now have standalone Blender/FBX packages in
`<skin>/asset-v1/`: bee, ladybird, cow, zebra, giraffe, leopard, tiger and
snowleopard. [Open the review gallery](../../../assets/skins/animal/common/index.html) for
four views per animal, model downloads and import notes. Original coat scenes
and maps are preserved. These packages have not been installed in Roblox.
Regenerate them with `../make/package_animal.py`; `../WORKFLOW.md` remains the
current coat-authoring guide. The older cylindrical-UV notes below describe
the legacy mask pipeline, not the current baked-coat unwrap.

Everything in here is a texture that gets **uploaded to Roblox**. Nothing else
in `blender/pig/` is: the `.obj` files are meshes, the `.blend` files are
disposable, and `renders/` is pictures. `.gitignore` refuses every `*.png` in
this folder tree except these, because these are the source of a shipped asset
rather than a picture of one.

## Three kinds of folder, and the difference is who can wear the texture

### `animal/` — sheets named by MARKING TYPE

`pig_spots_color.png`, `pig_stripes_color.png`, `pig_patches_color.png` and so
on. **A sheet here belongs to no particular animal.** It carries a SHAPE in its
alpha channel and exactly ONE constant RGB, and `AlphaMode.Overlay` resolves to
`lerp(partColour, mapRGB, mapAlpha)` — so the same spots sheet dresses a
leopard, a cheetah and a snow leopard, and the only thing that differs between
them is two colours in `Config`.

Filing one of these under an animal's name would be a lie about what it is, and
would quietly stop the next person reusing it.

`animal/masks/` holds the hand-editable greyscale sources for these, and
`MASKS.md` beside them is the authoring guide. **The masks are the only thing
in this repo with no generator behind them** — every map here can be rebuilt
from its mask, and a mask can be rebuilt from nothing.

`pig_fur_normal.png` also lives here: one normal map, shared by every animal
pack, no per-animal art.

### `<skin>/` — one skin's own FULL-COLOUR textures

`bee/` and `tiger/`. A full-colour texture carries its own colours rather than
a shape plus one ink, so **it belongs to exactly one skin and nothing else can
ever wear it** — which is precisely why it gets a folder with that skin's name.
It also carries as many colours as it likes: the tiger is orange, cream, ink
and a pale inner ear, and `Overlay` can express two.

The trade, stated plainly: a full-colour sheet means `Config.SKINS.<skin>.body`
and `.trim` stop doing anything, because the map replaces the part's colour
outright. A colour tweak becomes a re-bake and a re-upload rather than a
one-line edit. What it buys is that what you paint is exactly what ships, with
no mask, no marking colour and no lerp to reason about.

    blender --background --python make/bake_skin.py -- --skin bee

writes `bee/bee_body_color.png` and `bee/bee_trim_color.png` straight from the
Blender materials. One command, no conversion step.

**The blend it bakes from is generated, not hand-saved.** A skin's script,
its scene, its preview and its two sheets all live in the skin's own folder and
are all named after it -- `bee/make_bee_blend.py`, `bee/bee.blend`,
`bee/bee_view.blend`, `bee/bee_*_color.png`. `../WORKFLOW.md` is the method.

### `metal/` — the metal pack

A colour, metalness and roughness map plus the band overlay, shared by every
metal skin the same way `animal/` sheets are shared.

## Two sheets per skin, not one, and it is the game's own split

The pig is a `Body` MeshPart and a `Trim` MeshPart (the trim being the snout,
ears, legs and tail — optionally cut into four). They are separate parts with
separate colours, so they need separate maps. They DO share one UV cylinder,
which is what `pig_uv.py` pins — so baking both into one sheet would have the
snout's marking overwrite whatever the flank had at the same coordinates.

## Before uploading

    python masks/make_paint_template.py --check skins/animal/pig_spots_color.png

Checks the things that are invisible until they are on a pig: more than one RGB
value in a sheet that is meant to carry one, marking inside an eye patch, and
detail in the pole zones where the unwrap converges to a point and smears it.

Every upload publishes under your own account and is moderated. Look at what
you are sending, and send few.
