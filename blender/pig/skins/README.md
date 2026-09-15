# skins/

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
