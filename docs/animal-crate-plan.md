# Animal crate plan — the crate stops being a zoo and becomes a paint shop

**Status: WORKING DOCUMENT, September 2026. Not a fourth source of truth.**

CLAUDE.md is WHY (rules and post-mortems), GAME.md is WHAT (the map),
design-doc.html is the original pitch. This file is a scratchpad for a
direction that has not shipped. As each phase below lands in code, its
reasoning moves into CLAUDE.md and its description moves into GAME.md, and
the entry here is deleted. When this file is empty, delete it.

**The authoring method is `blender/pig/WORKFLOW.md`.** Everything below is
about WHAT to make; that file is HOW, and it is the one to read before
touching a generator.

---

## 1. The diagnosis: the top of the crate is more cats

`Config.CHESTS.animal` is a solved ladder at 500,000 coins a pull:

| tier | odds | what is in it today | baked coat? |
|---|---|---|---|
| Common | 52% | Ladybird 25K · Dairy Cow 35K · Woolly Sheep 60K · Dalmatian 90K | yes · yes · **no** · **no** |
| Rare | 32% | Zebra 250K · Bumblebee 400K · Cheetah 900K | yes · yes · **no** |
| Epic | 12% | Giraffe 1.8M · Leopard 2.4M · Orca 4M | yes · yes · **no** |
| Legendary | 4% | Bengal Tiger · Snow Leopard (no price, explicit `rarity`) | yes · yes |

**THE PROBLEM IS NOT THAT THE TIERS ARE EMPTY, IT IS THAT THE TOP OF THE
LADDER IS THE SAME KIND OF THING AS THE BOTTOM.** A Bengal tiger is a
beautiful skin and it is not a different KIND of object from the leopard two
tiers below it — same animal family, same technique, same read from the
pavement. A tier that costs eight times as much has to be a different
experience rather than a better photograph.

**AND FOUR OF THE TWELVE HAVE NO COAT AT ALL.** Woolly Sheep, Dalmatian,
Cheetah and Orca are `pattern` rows — the old primitive spot/stripe system —
and have never been cut as a baked `surface`. They are being SCRAPPED rather
than drawn (see §6), because the pipeline's time is better spent on things
nobody has seen.

---

## 2. The reframe: collect looks, not species

There are **five working pattern generators** under `assets/piggies/<tier>/<key>/generate/`
(the legendaries' still under `blender/pig/skins/`), and
a fantasy skin is one of them with a different palette and material:

| generator | what it draws | what it can be |
|---|---|---|
| `make_tiger_blend.py` | rings round the body, a radial fan on the face | anything striped |
| `make_zebra_blend.py` | bands about a pole through the muzzle | anything banded |
| `rosette.py` (leopard, snow leopard) | cells with petal rings, closing to solid at the extremities | anything spotted |
| `make_giraffe_blend.py` | flat cells separated by lanes | **anything tiled, cracked or leaded** |
| `make_cow_blend.py`, `make_ladybird_blend.py` | blotches, and discs | anything blobby or dotted |
| `skins/phoenix/` | **overlapping arcs on a staggered lattice** | anything feathered, scaled or shingled |

**THE SIXTH ONE IS NEW AND ITS FINDING IS THE INTERESTING PART: A SCALLOP IS AN
OVERLAP ORDERING, NOT A SHAPE.** Both obvious routes draw the wrong object. A
distance-to-a-LINE (the tiger's `to_band`) warps into corrugated iron, because
one continuous boundary is shared by two rows and it cannot stagger. A Voronoi
nearest-centre boundary is the perpendicular bisector, which is STRAIGHT, so
overlapping the discs resolves back to the same bisector and draws honeycomb.

What works is a lattice of ellipses where **the smaller row wins** — head over
tail, like roof tiles. And it costs ONE distance field rather than four: at the
shipped radii a point outside row `r`'s ellipse is always inside row `r+1`'s
and row `r-1` can never reach it, so `d < 1 ? r : r+1` is exact and one `d`
decides the colour, the tip, the shadow and the row index.

So **a "Rainbow Tiger" is not a new skin.** It is `make_tiger_blend.py` with
the ink colour indexed off the stripe number — an afternoon, no new geometry,
no upload beyond the two sheets that every skin needs anyway.

**THAT IS THE WHOLE ARGUMENT FOR THE DIRECTION.** You are not collecting
species, you are collecting LOOKS, and the ceiling on a look is far higher
than the ceiling on "another cat". The crate's own blurb still holds — every
one of these is a coat — it just stops being a documentary.

---

## 3. What a "unique trait" can actually be

A skin **confers nothing** and the mesh is shared across the whole catalogue,
so there are no horns, no wings and no extra tails, ever. These are the levers
that exist:

| lever | cost | used by |
|---|---|---|
| `material` Neon / Glass + `reflectance` | free | the classics |
| `anim` — `pulse`, `cycle`, `flicker`, `rainbow` | free, but **exactly four kinds**; a fifth means editing ClientMain at its 200-local ceiling | the neon skins |
| **`furSet = "mane"`** — 36 tufts, crown + cheeks + brisket | **free today.** Uploaded as `79359659715894` and **worn by nothing in the game** | nobody |
| `furSet = "crest"` — a short upright forelock | one `.obj` upload; the file is already at `blender/pig/pig/pig_fur_crest.obj` | zebra declares it, `id` is `""` |
| alpha holes in a baked sheet, so an `anim` colour shows THROUGH the coat | **built — `make/bake_alpha.py`, see §4** | Magma |

**THE MANE IS THE FIND.** A full ruff, already uploaded, worn by nothing. That
is a legendary trait sitting on the shelf for the price of one Config field.

---

## 4. The tier ladder IS the technique ladder

**COMMON AND RARE ARE PAINT. EPIC GLOWS. LEGENDARY GLOWS AND MOVES.**

That replaces the earlier "one reserved lever per legendary" idea, and it is
better for the reason `Config.CASING` is better than a multiplier: a player
can SEE which tier a skin is without being told, because the tiers are
different KINDS of object rather than different qualities of the same object.

| tier | what it is | how |
|---|---|---|
| Common, Rare | a painted coat | the baked sheet, fully opaque |
| **Epic** | a coat with something on it that GLOWS | baked colours bright enough to clear the BloomEffect |
| **Legendary** | glows AND the glow moves | the alpha pass below, plus an `anim` block |

### How a Blender file says which texels glow or move

**A `SurfaceAppearance` HAS NO EMISSIVE CHANNEL AND NO "ANIMATE" FLAG.** It
carries ColorMap, NormalMap, MetalnessMap and RoughnessMap, and that is all.
So nothing in a texture can say "this texel behaves differently" — except
one thing. `AlphaMode.Overlay` composites the map over the part's own
`Color3`:

    final = lerp(part.Color, map.RGB, map.Alpha)

**ALPHA IS THE ONLY PER-TEXEL SWITCH THE FORMAT HAS.** At 255 the baked
picture wins and the texel is static. At 0 the part's own `Color` wins — and
`ClientMain`'s skin animator rewrites `body.Color` every Heartbeat. So you
paint alpha opaque where you want the bake and transparent where you want the
animation, and the two live on one sheet.

**THIS IS NOT A NEW TRICK.** `Config.SURFACE_PACKS.bands` already ships on
exactly this mechanism: one metal band image whose alpha hands the tint back
to the skin, so gold, silver, chrome and copper come out of a single upload.
That one uses it for COLOUR; this uses it for MOTION.

**GLOW IS A SEPARATE QUESTION AND IS NOT SOLVED BY ALPHA.** Alpha buys an
animated colour, not emission. What glows is whatever `BloomEffect` picks up —
`WorldService` runs it at `Threshold = 1.8`, it operates on the final image
after lighting, per pixel, and it cares nothing for materials.

**AND THE EPIC LEVER AS FIRST WRITTEN HERE IS PROBABLY NOT AVAILABLE.** This
section said the epic tier glows by "baking a colour bright enough to clear
1.8". Measured while building Stained Glass, the brightest pixel on a whole
baked animal under the preview's copy of the game's sun rig is **218 of 255 —
nothing clips** — against a palette whose palest glass sits at relative
luminance 0.846 in full sun. Linearised that is about 0.70 against a threshold
of 1.8, short by a factor of 2.6.

The ARGUMENT under the measurement is the part that travels: **a baked colour
is a REFLECTANCE, and a diffuse surface cannot return more light than falls on
it.** Short of an emissive material there is no route from paint to bloom, and
`Config.skinSurface` has already refused the only emissive material available.

**IT IS NOT SETTLED, BECAUSE IT WAS MEASURED IN THE WRONG RENDERER.** Blender's
preview is a proxy for Roblox's sun rig, not Roblox, and the two do not share a
tone curve or an HDR buffer. The test that decides it is a bright part on a
lawn in Studio, which needs no upload and about twenty minutes.

**IF IT HOLDS, THE EPIC TIER NEEDS A DIFFERENT LEVER**, and there are three:
the pig's own `Glow` PointLight tinted per skin (a real glow, though it lights
the whole body rather than a marking); `furSet` (the mane, still worn by
nothing); or the alpha pass with a SMALL, slow animation against the
legendary's large one — which keeps the ladder intact and needs nothing new.

**AND `Material.Neon` IS NOT AVAILABLE, WHICH IS WHY THE BLOOM ROUTE MATTERS.**
`Config.skinSurface` refuses to hand a surface pack to any skin whose material
is Neon or Glass and returns nil, because a part wearing a `SurfaceAppearance`
IGNORES its own Material while going on reporting it. A Neon Magma would not
glow, it would silently lose its coat. Anything wanting to glow has to do it
in the PAINT.

### The pass, and why the fallback is free

    blender --background --python assets/piggies/<tier>/<skin>/generate/make_<skin>_blend.py
    blender --background --python make/bake_skin.py   -- --skin <skin>
    blender --background --python make/bake_alpha.py  -- --skin <skin>
    python make/apply_alpha.py --skin <skin>

A skin opts in by labelling one node `ALPHA_MASK`, whose output is 1 where the
map should be opaque. **A material with no such node bakes fully opaque**, so
the eight finished skins are unaffected by the pass existing.

**IT IS A SEPARATE SCRIPT FROM `bake_skin.py` AND THAT IS THE DESIGN RATHER
THAN A CONVENIENCE.** It never touches colour, so the RGB sheet is
byte-identical either way — verified on every run rather than asserted. The
fallback is therefore not a saved copy of anything: it is re-running the
colour bake and stopping, or `apply_alpha.py --undo`. A skin that looks worse
animated goes back by not running one command.

### What it cost to get right, which is worth keeping

**A BAKE WRITES NOTHING OUTSIDE A UV ISLAND, AND ZERO IN THIS MAP DOES NOT
MEAN BLANK — IT MEANS TRANSPARENT.** So an unwritten background hands every
seam on the animal to the part colour through the bilinear filter. Forcing it
opaque took three attempts and **the first two failed silently**:

1. Detect unwritten texels as "alpha below 0.5". Finds nothing: `images.new`
   hands back an image that is already `(0, 0, 0, 1)`.
2. Pre-fill the buffer white — via `generated_color`, via
   `pixels.foreach_set`, with `use_clear` off in the scene AND passed
   explicitly to the operator. All three discarded.

**ALL THREE MEASURED 37.51% TRANSPARENT, TO TWO DECIMALS, AND THAT IS THE
FINDING.** A fix that changes the number not at all is a fix that never ran —
the identical figure was the evidence, not the pictures. The background is
BAKED now: a second pass with every material emitting pure white marks every
texel the bake can reach, and `where(coverage, mask, opaque)` cannot be wrong
about a texel neither pass touched. Measured after: 67.4% of the body sheet is
island, and 8% of that is core.

### What the alpha pass cannot be used for

**EVERY ALPHA-0 TEXEL GETS THE SAME `Color3`, SO THE PASS COLLAPSES A
MULTI-COLOUR REGION INTO ONE.** `lerp(part.Color, map.RGB, map.Alpha)` has one
part colour in it, and there is one `Color` property per MeshPart. Handing
Rainbow Tiger's stripes to the animator therefore does not animate eight hues,
it DELETES them: eight authored colours become one cycling colour, and what
comes back is a white pig with one shimmering stripe set. That is a perfectly
good legendary and it is not Rainbow Tiger.

**SO THE PASS SUITS A SKIN WHOSE ANIMATED REGION IS ALREADY ONE COLOUR.**
Magma's cores are one colour and Stained Glass's opal is one of twelve; both
lose nothing. A skin whose identity IS the variety inside the region has to
hand over a SUBSET instead — every nth stripe index, say, which on the tiger is
one node off the `floor` that already computes the hue. Most of the wheel stays
baked and a few strokes shimmer through it.

**THE GENERAL TEST BEFORE REACHING FOR IT: how many colours are in the region
you are about to make transparent? If the answer is more than one, the pass
will cost you all but one of them.**

### The trim animates to a DIFFERENT colour from the body

`ClientMain`'s animator writes `entry.body.Color = colour` but
`p.Color = colour:Lerp(skin.trim, 0.55)` on the four trim parts. So a marking
that crosses from the flank onto a leg, an ear or the snout **flickers more
muted there**, pulled halfway toward the skin's own trim colour.

That is not a bug and it should not be 'fixed' — it is what stops an animated
skin's trim reading as a second body. But it means a hand-composited preview
that uses one colour for both sheets is showing something the game will not
draw, and a marking designed to run off the body onto a leg will not cycle
evenly across the join. Model both when previewing; `skins/stormwolf/preview_anim.py`
does and `skins/stainedglass/preview_anim.py` does not.

### Seeing it before it is uploaded

**THE BLENDER PREVIEW RENDERS RGB AND KNOWS NOTHING ABOUT ALPHA**, so the
animated half of a skin is invisible in the ordinary loop — which would mean
the only way to look at a legendary is to publish it. It is not: compositing
`lerp(part.Color, map.RGB, map.Alpha)` by hand at a few points around a cycle
and rendering each gives a real 3D preview of what the engine will draw.
`renders/magma_glow_cycle.png` is that, at the trough, the authored value and
the peak.

## 5. The catalogue

### Common — the eight real animals

The eight coats already baked from 3D: **bee, ladybird, cow, zebra, tiger,
giraffe, leopard, snow leopard.** They are good, they are done, and they are
what the tier at 52% should be full of.

Note this DEMOTES Bengal Tiger and Snow Leopard from legendary. They stay in
the crate and stay excellent; what changes is that they stop being the
ceiling.

### Rare — sweets, weather and fruit

Cool and desirable, no trait required. Each is a palette on a generator that
already exists:

| skin | generator | look |
|---|---|---|
| **Strawberry Cow** | cow | pale pink coat, deep pink blotches |
| **Cookies & Cream** | cow | cream coat, dark chocolate blotches |
| **Watermelon** | ladybird | green rind, black seed spots, hard pink belly |
| **Peppermint** | tiger | red and white stripes |
| **Glacier** | tiger | white coat, ice-blue stripes |
| **Bubblegum Leopard** | rosette | pink coat, magenta rosettes |
| **Honeycomb** | giraffe | gold cells, amber lanes |

### Epic — where a material or an animation joins in

| skin | generator | trait |
|---|---|---|
| **Cyber Tiger** | tiger | obsidian coat, cyan circuit-trace stripes, Neon, slow `pulse` |
| **Galaxy Leopard** | rosette | indigo coat, rosettes filled with starfield, slow `flicker` so the stars twinkle |
| **Glitch Zebra** | zebra | bands that stutter on a fast `flicker`. The one skin that looks broken on purpose |
| **Toxic** | cow | acid-green blobs on black, Neon |

### Legendary — one reserved lever each

**THAT IS THE RULE: A LEGENDARY OWNS A LEVER NOTHING BELOW IT MAY USE.** Then
the tier is unique by construction rather than by being labelled, which is the
same argument `Config.CASING` makes about a rung that hands over a VERB rather
than a number.

| skin | generator | trait | reserves |
|---|---|---|---|
| **Rainbow Tiger** | tiger | the coat runs the spectrum while the stripes hold | the alpha-hole technique |
| **Magma** | giraffe, **inverted** | near-black obsidian plates, the lanes glowing orange as cracks, on a `pulse` — it glows from inside | emissive lanes |
| **Stained Glass** | giraffe | jewel-coloured panes with near-black leading, `Material.Glass` | the only skin made of glass |
| **Golden Lion** | — | `furSet = "mane"` in gold over a tawny coat | **the only piggy with fur** |

**MAGMA AND STAINED GLASS ARE THE SAME FIELD READ TWO OPPOSITE WAYS**, which
is a feature rather than a duplication: one is dark plates with bright cracks,
the other is bright panes with dark leading, and building both proves the cell
generator can carry both reads. If they turn out to look like relatives, the
lever to separate them is the CELL SHAPE — the giraffe's cells are irregular
and a leaded window's want to be closer to even.

**If the tier stays at two, ship Rainbow Tiger and Magma** — one animated, one
emissive, neither of them an animal anybody has seen, and between them they
use two different traits.

---

## 6. The proposed ladder, and what it costs

| tier | odds | count | contents |
|---|---|---|---|
| Common | 52% | 8 | the real animals |
| Rare | 32% | 4 | of the sweets set |
| Epic | 12% | 3 | |
| Legendary | 4% | 2 | Rainbow Tiger, Magma |

**ADDING LEGENDARIES DOES NOT MAKE LEGENDARIES COMMONER.** A chest rolls a
TIER first at a fixed 4% and then picks inside it, so two legendaries is a 2%
shot at a named one and four is 1%. At 500,000 coins a pull that is a long
road for a nine-year-old, and it is the reason the tier is held at two rather
than filled with everything in §5.

**THE ODDS RELATION IS SOLVED AND MUST SURVIVE.** `Config.CHESTS.animal`'s own
comment records `epic = 3 * legendary` — 12 against 4 — which is what keeps
`Config.COMBINE` (three spares of a tier make one roll of the next) level
against rolling directly. Counts are free; those two numbers are not.

### Three flags before any of this is wired

**PRICE EVERY LEGENDARY, EVEN THOUGH NOTHING IS BOUGHT.** `Config.sellValue`
applies its cap only `if type(spec.cost) == "number" and spec.cost > 0`, so an
unpriced legendary sells for the full tier value of
`SELL.base * (100/4)` = **1,000,000 coins, out of a 500,000 chest.** Bengal
Tiger and Snow Leopard are both unpriced today, so a duplicate of either pays
DOUBLE what the open cost — against CLAUDE.md's own rule that a duplicate
"always returns 21% to 35%... always a real loss, never nothing". That is live
now and it gets one notch worse per unpriced legendary added. A `cost` on a
crate-only skin is a RARITY and a SELL CEILING first and a purchase never,
which is the argument CLAUDE.md already makes for keeping prices on skins
after the buy button came off.

**A SKIN THAT STANDS PROUD OF ITS OWN BODY RE-FRAMES EVERY PREVIEW OF IT, AND
THE TWO SURFACES DISAGREE BY DIFFERENT AMOUNTS FOR DIFFERENT REASONS.** Every
pattern kind in the catalogue until now lies FLUSH -- a stripe segment clears
the body by `LIFT` alone and a spot's thickness is solved so its inner face is
buried where the sphere drops away under its own rim, precisely so it does not
read as a coin lying on the pig. Flush geometry cannot extend a bounding box,
and both surfaces that preview a piggy frame off one. `shards` is the first
kind that deliberately does not: measured on the Storm Stone spec, 26 shards
and 40 bolt segments take the model's longest axis from 2.625 to 2.980.

Neither surface CLIPS, and neither is broken. What both do is render the BODY
smaller than every other skin's beside it, and the numbers are not the same
number:

| surface | how it frames | body renders |
|---|---|---|
| shop bay (`ShopFront`) | `DISPLAY_SPAN / longest`, a longest-axis ratio | 2.980 / 2.625 -> **88%** |
| shop card (`makeModelIcon`) | camera distance off the bbox diagonal | 3.893 -> 4.647, **84%** |

**QUOTING ONE AT THE OTHER IS THE MISTAKE TO AVOID**, and it is this whole
document's recurring failure in miniature: a figure measured correctly on one
thing and spent as though it described another. Name the surface in the same
breath as the number.

**AND THE CARD HAS A SECOND FAULT THAT NO RATIO SHOWS.** `makeModelIcon`
re-centres on the BOUNDING-BOX centre rather than the body's -- deliberately,
so an icon spins about the middle of its own shape -- and a crest sitting high
and aft drags that centre with it. Measured: **0.318 studs of drift**, so a
shard pig sits low and forward in its tile with dead space opposite. On a
legendary, which is the card most likely to be looked at, that reads worse than
the scale does.

The card can afford the fix and the bay cannot. Framed off the body the crest
still clears the card's frame with 30% to spare; the same change in the bay
pushes the display 0.55 studs deeper into a customer strip that would then land
under `SHOP_ROOM.minWalk`. So the bay keeps its 12% on purpose and the card is
the one worth fixing.

**IT IS NOT FIXED YET AND THE REASON IS THE SHAPE OF THE FIX.**
`makeModelIcon` frames houses, rides, decorations and accessories as well as
piggies, and none of those has a body to frame off -- so the narrow version is
an optional part argument on a function with many callers, whose absence reads
as nil. That is `setDecor` exactly, which CLAUDE.md records as five callers and
a missing positional landing as a silent EMPTY on a lawn. It wants doing
deliberately rather than in passing.

Nothing renders wrong today, because no `shards` skin is in `Config.SKINS`
yet -- which is also the reason to wait rather than to hurry: the spec's `size`
and `boltLen` are still being tuned, and a framing constant measured against a
moving spec describes the build it was measured on. That is
`SHOP_BANK_PIG_SECONDS` again, pinned and wrong by 62% on its first audited
boot.

**A SCRAPPED ROW IS PRUNED AGAINST THE CATALOGUE, NEVER BY A LIST OF NAMES.**
Cutting Woolly Sheep, Dalmatian, Cheetah and Orca leaves dead keys in any save
that owned one, and `Decor.buildOne` already records what that looks like: a
lookup that returns nil and an item that quietly never appears, with nothing
in the log. Confirm the skin path has the same catalogue-derived prune that
`data.decor` has before the first row is cut. Nothing has been earned yet,
which is what makes now the free moment to do it.

---

## 7. Where things stand

| skin | who | state |
|---|---|---|
| **Dragon** | this session | **built, and through the alpha pass.** The giraffe's cell field for the third time, separated by SQUASHING the input vector before the Voronoi walks it — round cells in a squashed world are wide-and-short scales on the pig. Four tones per cell, gold belly plates, and the seams between the scales burn where the fire is. The burning seams are what the animator drives. |
| **Magma** | this session | **built, and the first skin through the alpha pass.** Four rounds. 0.00% in a fade. Cores handed to the animator (8% of the coat); everything else static. |
| **Rainbow Tiger** | delegated agent | **built, 8 hues.** Hue indexed off `floor(phase)` into a CONSTANT ramp — a colour table, not a gradient. No `ALPHA_MASK`, deliberately: see "What the alpha pass cannot be used for". |
| **Phoenix** | delegated agent | **built, and through the alpha pass.** A sixth generator: overlapping scallops on a staggered lattice, gold at the breast running to crimson at the tail in five flat bands. The feather TIPS animate. Recommended `fur = (238, 88, 26)` for the mane, chosen by rendering four candidates on the real mesh. |
| **Storm Wolf** | delegated agent | **built, and through the alpha pass.** A Voronoi cell-net makes the forks branch for free; two smooth noise masks on the WIDTH make them sparse, so three or four bolts survive with tapered tips. The channel of the bolt animates and the core stays baked. |
| **Storm Stone** | this session | **built, and through the alpha pass.** Storm Wolf's fork machinery on Magma's plate crust, from a reference photograph: a creature made of dark stone with lightning running in the cracks. Everything from `# ===== THE STORM` down is byte-identical to the wolf's, which is the point -- the branching a fork needs was already built and measured. The first build was a FOOTBALL and the two numbers that made it one are recorded in the file: a near-black seam at nearly a tenth of a cell reads as a NET with fill in the holes, whatever the plates are doing. **It is the first skin whose look does not live only in the sheet** -- the broken rock standing off its back is `PiggyModel`'s `shards` pattern kind, and the Neon bolts among them are the only part of this animal that can actually reach the BloomEffect. |
| **Stained Glass** | delegated agent | **built, and through the alpha pass.** Lead drawn LAST over everything, panes near-even, six glasses at two densities. The opal panes are handed to the animator; the came and the jewels hold. |

**AND WHAT DECIDES A HUE COUNT IS NOT SMOOTHNESS, IT IS HOW MUCH OF THE WHEEL
ONE CAMERA SEES.** Swept at 6, 8, 10, 12 and 14, all of which pass the checker
now. A higher count is a smaller step, so the flank gets smoother — and every
VIEW shows a narrower arc, because a camera only ever sees part of a barrel. At
14 the rump is red/orange/gold/lime and nothing else: a gradient, not a
rainbow. 8 is where the rump still runs red to teal and the face fan carries
the whole wheel.

**`WORKFLOW.md`'S "JUDGE IT ON THE CROWN AND THE SPINE" EARNED ITS KEEP HERE.**
Ten wins a hero shot and loses both of the views that rule names, and it would
have shipped off a three-quarter view.

Nothing is uploaded, nothing is wired, and `Config.luau` is untouched. Getting
a skin into the game is two texture uploads and a Config row per
`WORKFLOW.md`, and that is the serial part.

**THE PARALLEL RULE IS `WORKFLOW.md`'s.** Three sessions authoring three skins
at once is safe because everything the loop touches is named after the skin.
The three shared WRITES are `pig/pig_parts.blend` (rebuilt by
`make_parts_blend.py` — one at a time, nothing else running), `Config.luau`
(one owner, announced) and the toolkit at the root. An agent authoring a skin
touches none of them.
