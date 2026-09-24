# Authoring skins by hand

How to design an animal skin for *Rob a Piggy Bank* yourself, and the workflow
that makes the fiftieth one as cheap as the second.

This is a HOW, next to the tools it describes. `CLAUDE.md` is the WHY and wins
wherever the two disagree.

**THERE ARE TWO ROUTES TO A SKIN AND THIS IS ONE OF THEM.** This file is the
HAND-PAINTED route: you paint a greyscale mask in an image editor and
`make_paint_template.py` turns it into a map. The other is the GENERATED route
— a procedural `coat()` in Blender — and it is written up in
`blender/pig/WORKFLOW.md`, which owns the toolkit, the master scene and the
two-skins-at-once rule. They are peers rather than versions of each other:
reach for the generator when the marking is a field of cells, scales, forks or
stripes that wants to be re-rolled in a different palette, and for this file
when the marking is a specific drawing. Neither supersedes the other, and both
land in the game the same way — two texture uploads and a `Config.SKINS` row.

---

## 1. Three channels, and the rule for choosing

A skin can say what it needs to say in one of three places. They cost wildly
different amounts, and **you go up a tier only when the tier below genuinely
cannot say it.**

| | what it is | cost | upload? |
|---|---|---|---|
| **Colour** | `body`, `trim`, and per-part `parts` in `Config.SKINS` | minutes | no |
| **Pattern** | `pattern = { kind = "stripes" \| "spots", ... }`, built out of parts on the body at run time | an hour of tuning | no |
| **Surface** | `surface = "..."`, a `SurfaceAppearance` with a ColorMap and a NormalMap | half a day + moderation exposure | **yes** |

Most of the 46-skin catalogue is channel one. The whole animal bucket is
channel two or three.

**Why the ordering is not a preference.** Channels one and two need no asset,
so they cannot be moderated away, they render identically in the world and in
the shop tile, and they are reversible by editing a table. Channel three is the
only one that can produce fur, fine speckle or a soft edge — and it is the only
one that puts an image under your own Roblox account. See §7.

---

## 2. The colour rules that are already load-bearing

These are not style advice. Each one has already cost something.

**`AlphaMode.Overlay` resolves to `lerp(partColour, mapRGB, mapAlpha)`.** The
map carries the SHAPE, the skin carries the BASE COLOUR. This is why one
uploaded map dresses unlimited colourways, and it is the single biggest
efficiency lever in the whole pipeline.

**One map is one marking colour.** A part has one `Color3` to lerp from, so a
sheet holds exactly one RGB value. Measured across every shipped map: one
distinct RGB in the whole 1024 square — `(14, 12, 14)` on the dark patterns and
`(246, 248, 252)` on the orca, which is the same convention inverted for a pale
marking on a dark animal. **A light marking and a dark marking on one animal
need two maps and cannot be one.**

**Neon and Glass never take a pack.** `Config.skinSurface` refuses the pairing,
because a `SurfaceAppearance` overrides the material while `Material` goes on
reporting whatever was set. A pack on a Neon skin kills the glow silently.

**A pack deletes a metal skin's `reflectance`** while the property panel still
shows the value you set. Anything shiny has to carry its shine in its own
metalness and roughness maps.

**A Neon skin wants a DEEP colour.** Neon renders flat out and the BloomEffect
takes it from there, so a pale tint on a twelve-stud sphere is a white hole
rather than a glowing pig.

**Price IS rarity.** `Config.rarityOf` derives the border tier from `cost`
(bands at 100K / 1M / 10M). Pricing a skin is a design act, not bookkeeping —
and anything with no coin price needs an explicit `rarity` or it silently falls
through to common.

---

## 3. The sheet, and the four things about it that are invisible

Everything is unwrapped on ONE cylinder about the standing axis: `u` is the
angle around the animal, `v` is normalised world height. `blender/pig/pig_uv.py`
owns that range and pins it deliberately, so a geometry tweak does not move
every texture in the pack.

**THE PIG IS UPSIDE DOWN ON ITS OWN TEXTURE.** `make_animal_maps.py` writes row
`y` as `v = (y + 0.5) / SIZE`, so **v = 0 is the TOP row of the file** — and
v = 0 is the animal's FLOOR. Open a shipped map in any paint program and the
feet are at the top, the crown at the bottom. This is the opposite of the usual
convention and it is invisible until the pig is on a lawn. Proved rather than
assumed: read unflipped, `pig_stripes_color.png` has a maximum alpha of **0**
inside the eye cores, which is `eye_keep` doing exactly its job; read flipped,
the same cores read **240**, which is full strength.

**A CIRCLE IS NOT A CIRCLE.** The whole circumference goes across `u = 0..1`
and the whole height across `v`, and the animal is far wider than it is tall.
One stud is between **1.38 and 2.90 times** as much `v` as it is `u`, and the
figure varies with height because the girth does. Draw a spot round on the
sheet and it lands as an ellipse up to three times taller than it is wide. The
guide draws one-stud rings at six heights so you can copy the local shape.

**THE CROWN AND THE FLOOR ARE SINGULARITIES.** A cylindrical unwrap collapses
every `u` onto a single point at each end. The leopard's spots came out as a
starburst over the crown and were reported as "distorted near the top". The
generator fades markings out over the last 15% of the body's span at each end —
and that happens to be what real animals look like, since markings thin over
the spine and a pale unmarked belly is nearly universal.

**THE PARTS OVERLAP.** Body, snout, ears, legs and tail all share the one
cylinder, so the same `(u, v)` belongs to several of them. That is why every
animal pack carries both a `template` and a `trimTemplate`: the trim wears the
coat WITHOUT the pattern, or you get tiger bars running down a snout.

Landmarks, for reference:

| | value |
|---|---|
| sheet | 1024 × 1024 RGBA |
| body occupies | `v` 0.026 … 0.850 |
| eyes | `u` 0.1955 and 0.3045, `v` 0.594; radii 0.052 / 0.082, feathered 45% |
| pole fade | 15% of the body's span at each end |
| one unit of `v` | 13.98 studs |
| one unit of `u` | 25.7 studs at the belly, 40.7 at mid-body, 22.8 near the crown |

---

## 4. The tool

    cd blender/pig
    python make_paint_template.py

writes three files:

* **`paint_guide.png`** — transparent overlay: eye patches, body span, the two
  pole-fade danger zones, and one-stud rings showing the local squash. Drop it
  on top of your working file as a locked layer and delete it before export.
* **`paint_islands.png`** — which region of the sheet is which part.
* **`paint_template.png`** — both, flattened, for a quick look.

Then:

    python make_paint_template.py --from-mask my_mask.png out_color.png
    python make_paint_template.py --check out_color.png

**You paint a GREYSCALE MASK, not a texture.** White is full marking, black is
bare skin. `--from-mask` writes the constant RGB and puts your mask in the
alpha channel. This is not a simplification of the real thing — it *is* the real
thing: extracting a shipped map's alpha and rebuilding it through `--from-mask`
reproduces that map **byte for byte**.

`--check` refuses the mistakes that are invisible until the pig is standing on
a lawn: marking inside an eye core, more than one RGB value, and detail sitting
in a pole zone where it will smear. It reports clean on every shipped map — a
check that fires on the work it protects is worse than no check.

---

## 5. Designing one skin

1. **Reference first, and a real animal.** Pick the two or three things that
   actually identify it. A zebra is a fan radiating from the muzzle; a cow is
   few large blotches; a dalmatian is many small dots. The difference between
   the cow and the dalmatian in this codebase is entirely `count` against
   `size`.
2. **Choose the channel** (§1). Start at colour and work up.
3. **Colour before art.** Set `body` and `trim`, price it, and look at it. Half
   of what reads as "wrong pattern" is wrong values.
4. **Look at it in the shop tile.** The tile renders the REAL piggy from the
   real builder, so it is a free preview of the world without leaving the shop.
5. **Only then, art.** And only if steps 2–4 could not get there.

**Two channels, two jobs.** `body` is the animal and `trim` is the face and
feet — give each one something to say. The Dairy Cow keeps a PINK trim rather
than going black with its blotches, because a cow's muzzle is the one part of
it that is pink; two channels both saying "Holstein" would waste one.

---

## 6. Designing a PACK, which is where the leverage is

Because Overlay decouples the map from the colour, **author maps by MARKING
TYPE, never by animal.** Nine maps already exist — stripes, bold stripes, spots,
big dots, blotches, patches, bands, orca, fur — and between them they cover
most of the animal kingdom:

> tiger, zebra and okapi are one stripe map; leopard, cheetah, jaguar and
> serval are one spot map; cow, dalmatian and hyena are one blotch map.

So **a new animal is usually zero uploads**: pick a marking map that already
exists, pick two colours, price it, name it. That is a fifteen-minute skin, and
it is why the catalogue can grow without the moderation surface growing with
it.

Add a NEW map only when the marking's *shape* is genuinely new — not when the
colour is. Ask: could an existing map at a different base colour be this animal?
If yes, it already is.

A pack that ships together wants one more thing: **a spread of prices**, because
price is rarity (§2). A pack whose members all cost 200K is a pack with one
tier, and the chest that rolls it has nothing to roll for. The effects
catalogue is the cautionary case — five items priced 15K to 600K is three
commons and two rares, no epic and no legendary, which is why there is no
effects chest and why more effects would not fix it. It is the price spread
that is missing, not the count.

---

## 7. Upload discipline — read this before generating anything

**Every generated or uploaded image is published under YOUR OWN Roblox account
and is moderated like anything else you upload.** This project has already been
actioned once, for *sexual content*, on an asset named `Generated
RoughnessMap` — a greyscale surface-detail image with nothing depicted in it.
One `generate_material` call is sixteen uploaded images; comparing a dozen
candidates was forty-eight.

The blast radius is the ACCOUNT, not the experience. It does not break the
game, it stops you opening Studio, and from inside it presents as
`MeshContentProvider could not fetch`, HTTP 403 from DataStoreService,
`Player:IsInGroup failed`, and `GetProductInfo failed` — all at once, while
cached meshes go on loading fine. **Anything that suddenly 403s across several
unrelated services at once is an account question before it is a Studio
question.**

So:

* **Generate few.** Two candidates, not twelve.
* **Look at every image before it goes up.** It is a publication under your name.
* **Prefer the channels that upload nothing.** This is the real reason §1 is
  ordered the way it is.
* **Batch uploads at the end** of a design pass, not during it.

---

## Stripe transitions in the current Blender coats

Tiger, Glacier, Peppermint, Raptor and Zebra use
`blender/pig/stripe_transition.py` to join their face and flank markings.
The old hard selector cut every stripe at one shoulder plane. The shared
helper now blends distances to the two fields' stroke edges over a smooth,
slightly irregular transition, then thresholds the result to solid ink.
Do not blend unwrapped phases (which makes dense pinstripes) or simply overlay
the patterns (which makes a grid). Narrow Tiger strokes also ease to a point
instead of disappearing at the minimum-width threshold.

The Tiger and Zebra generators apply this helper automatically. Rare coats
inherit it from their Tiger source. Existing authored scenes can be updated
without replacing their geometry, UVs or palette:

```powershell
blender --background --python blender/pig/make/refresh_stripe_transitions.py -- tiger zebra glacier peppermint raptor
blender --background --python blender/pig/make/bake_skin.py -- --skin glacier
```

Repeat the bake for each affected skin, using its closed-back scene when one
exists, and refresh its derived package and previews. Rainbow Tiger's current
legendary package has a separate hand-shaped stripe atlas and is unaffected.
Run `python blender/pig/look/check_fade.py tiger zebra glacier peppermint raptor`
to check that the baked strokes retain their full colours. New sheets still
need uploading and their SurfacePack asset IDs updating before Roblox shows
the change; a local rebake does not replace an existing Roblox image.

## 8. How this compares to how Roblox artists usually work

Worth knowing, because two of these are things we deliberately do differently.

**The standard tool is Substance Painter**, which has official Roblox templates
and export presets, and Roblox staff maintain a DevForum guide for it. It paints
directly on the model, which sidesteps every UV-distortion trap in §3 at once.
**If you are going to hand-author much, this is the single biggest upgrade
available** — and `pig.blend` already carries the shipped UVs, so Blender's own
Texture Paint mode gets most of the same benefit for free and for nothing.

**Painting on the model is normal; painting on the flat sheet is the fallback.**
Our pipeline generates maps procedurally, which is why it has been fine on the
flat sheet — the generator knows the corrections. A human does not, which is
what §4 exists to fix.

**Overlay-with-a-revealed-base-colour is Roblox's own recommended technique**
for exactly this: their docs describe designing a colour map that partially
reveals the mesh's `Color` property for custom skin tones and other per-instance
colour. Our one-map-many-colourways trick is the documented path, not a hack.

**Preserve colour in transparent pixels** so filtering cannot pull dark fringes
along an alpha edge. We satisfy this by construction — one RGB value across the
whole sheet including the clear areas, verified on the shipped maps.

**Do not tune material values to one lighting setup.** Base them on the physical
characteristics and check across lighting. This project's `ClockTime` is pinned
at 14.5 and never changes, which makes the trap easy to walk into.

**Texture budget: 512² is the documented size for a 10 × 10 stud object and
1024² for a 20 × 20 one.** The pig's body is twelve studs, so 512² is what the
guidance actually calls for and every animal map here is 1024². The maps are
shared assets so the cost is per-unique-texture rather than per-pig, and the pig
is the object the whole game is named after — but a 512 test is cheap and worth
running before the pack grows. The fur NORMAL map is the one most likely to
need the extra resolution.

Sources: [PBR textures](https://create.roblox.com/docs/art/modeling/surface-appearance) ·
[Texture specifications](https://create.roblox.com/docs/art/modeling/texture-specifications) ·
[Texturing setup](https://create.roblox.com/docs/art/characters/creating/texturing-setup) ·
[Substance Painter overview (Roblox staff)](https://devforum.roblox.com/t/substance-painter-overview-setup-and-general-pbr-creation/2884177) ·
[Substance Painter to Studio](https://devforum.roblox.com/t/substance-painter-to-studio-tutorial-surfaceappearance-pbr/866962)

---

## 9. The checklist

Before a skin ships:

- [ ] Does it read from the PAVEMENT, not just up close? That is where a thief
      decides.
- [ ] Do `body` and `trim` each say something different?
- [ ] Is it priced, and does the price put it in the rarity band you meant?
- [ ] If it is Neon: is the colour deep enough not to blow out under bloom?
- [ ] If it has a `surface`: is the material neither Neon nor Glass, and does it
      carry its own shine if it is meant to be shiny?
- [ ] If it has a map: does `--check` report clean?
- [ ] Have you looked at it in the shop tile AND on a lawn?
