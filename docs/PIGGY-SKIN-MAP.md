# The piggy skin map

**What this is:** every piggy the catalogue can contain, what each one is made
of, and which existing machinery builds it. It is a BUILD SPEC rather than a
pitch — the reasoning for the shape of the catalogue lives in
`docs/PIGGY-PACKS-PLAN.md`, and this file is what somebody actually works from.

**How to read a row.** Every skin names a MECHANISM (§1) and, where it needs
one, a GENERATOR (§3). Those two together are the whole build: the mechanism
says what kind of thing it is and what tier that makes it, the generator says
which existing Blender script draws it with a different palette. A row naming
neither is not yet a spec.

**Faces are deliberately not in here.** They are their own axis and their own
piece of work; this file's job is what a piggy IS MADE OF. Where a row wants a
particular expression it says so in one phrase and no more.

---

## 1. The mechanism palette — what a skin can be made of

These are the seven levers that exist in code today. Nothing else does, and
anything a row asks for outside this list is new engineering rather than new
content.

### 1a. Flat colour — free, no upload

| field | what it does |
| --- | --- |
| `body` | the sphere |
| `trim` | **the snout, both ears, the tail AND the legs**, all four |
| `material` | `SmoothPlastic`, `Neon`, `Glass`, `Metal`, `Foil` |
| `trimMaterial` | falls back to `material`; the reason a Neon pig keeps a face |
| `reflectance` | 0–1 |
| `transparency` | 0 on every shipped skin, and should stay there |
| `glowEyes` | the eyes go `Neon` instead of `SmoothPlastic` |

**`trim` IS THE FACE AS MUCH AS THE FEET.** Three of the four things it paints
are on the head, so a dark trim reads as a pig wearing a mask rather than as
one with dirty trotters — measured by building exactly that and looking at it.

**A NEON PART WANTS A DEEP COLOUR.** Neon renders flat out and the
`BloomEffect` takes it from there, so a pale tint on a twelve-stud sphere is a
white hole rather than a glowing pig. This project has shipped that mistake
four separate times: the Martian, the palace colonnade, a townhouse window rank
and the street lamp. Saturation is what survives the bloom; value is not.

### 1b. `pattern` — marks built out of PARTS. Free, no upload

Three kinds, all in `Shared/PiggyModel`. This is the cheapest marked skin there
is and it carries **no moderation exposure**, because nothing is uploaded.

| kind | fields |
| --- | --- |
| `spots` | `count`, `size`, `vary`, `seed`, `colour`, `bump`, `proud` |
| `stripes` | `count`, `width`, `arc`, `axis`, `spread`, `taper`, `wobble`, `faceGap`, `colour`, `seed` |
| `shards` | `count`, `size`, `thick`, `depth`, `lo`, `hi`, `rake`, `twist`, `parting`, `vary`, `seed`, `colour`, `glowColour`, `glowEvery`, `glowMaterial`, `faceHigh`, `faceStop` |

`spots` and `stripes` lie FLUSH and cannot change a silhouette. `shards` is the
one kind that deliberately stands proud — it takes the model's longest axis
from 2.625 to 2.980 on the Storm Stone spec, which re-frames every preview of
it (the shop bay renders the body at 88%, the shop card at 84%). **Quote the
surface in the same breath as the number**; the two are not interchangeable.

### 1c. `surface` — a baked Blender coat. Two uploads

A row in `Config.SURFACE_PACKS` naming a `template` and a `trimTemplate`. This
is the pipeline in `blender/pig/WORKFLOW.md`, and it is the only mechanism here
that costs an upload under the developer's own account — see §5.

### 1d. `anim` — a colour that moves. Free

`anim = { kind = ..., speed = ..., palette = { ... } }`, driven per client.

**EXACTLY FOUR KINDS EXIST: `pulse`, `cycle`, `flicker`, `rainbow`.** A fifth
means editing `ClientMain` at its 200-local register ceiling, which takes the
whole HUD down when it goes over. Treat the four as fixed.

### 1e. `aura` — particles. Free

A key into `Config.SKIN_AURAS` (`spotlight`, `confetti`, `glint`, `sunburst`,
`storm`, `prism`) or a `Config.EFFECTS` row. New auras are a data row.

**`Config.skinAura` CURRENTLY REFUSES ANYTHING NOT TAGGED `legendary`.** Its
first line is a rarity test. An epic authored with an aura gets no particles at
all, with nothing in any log — so the epic tier needs that gate opened in the
same change that creates it. One line.

### 1f. `fx` — geometry attached to the body. Free, no upload

A key into `Shared/SkinFX`'s `builders` table: `diamond`, `party`, `vip`,
`supernova`, `stormcaller`, `prismatic`. Crystal shards, a corona, storm
clouds, a ring of prisms. Client-animated, and it renders inside a
`ViewportFrame` — which particles do NOT, so this is what makes a top-tier skin
look top-tier on a shop card as well as on a lawn.

Sited on the flanks or at radius 8–10, **clear of every accessory anchor and of
the rob badge over the head**. A new `fx` kind is a function in that file.

### 1g. `Config.LEGENDARIES` — the body replaced

A 9–24-mesh Blender creature standing over a hidden pig. Weeks of work and many
uploads. Four exist. This is the MYTHIC tier and should stay small.

---

## 2. The tier ladder is the production ladder

The tier is DERIVED from the mechanism, never typed beside it — see packs plan
§1. Rarity is income now (`Config.PIGGY_RARITY_INCOME`), so a hand-typed tier
is a hand-typed income rate.

| tier | mechanism | upload? | nameplate |
| --- | --- | --- | --- |
| **Common** | flat colour, `pattern` parts | no | plain |
| **Rare** | a baked `surface` coat, **or** an `anim` | yes / no | blue |
| **Epic** | `aura` particles, no attached geometry | no | (open) |
| **Legendary** | `fx` geometry **plus** `aura` | no | gold |
| **Mythic** | a whole-model creature | many | moves |

The common/rare line is **does it need an upload**, which tracks authoring cost
exactly. The rare/epic line is **does anything come off the pig**. The
epic/legendary line is **is there geometry**.

---

## 3. The generator library — what Blender can already draw

From `docs/animal-crate-plan.md` §2, and the point of it is that **a new skin is
usually an existing generator with a different palette**, not new geometry.

| generator | what it draws | what it can be |
| --- | --- | --- |
| `tiger` | rings round the body, a radial fan on the face | anything striped |
| `zebra` | bands about a pole through the muzzle | anything banded |
| `rosette` | cells with petal rings, closing to solid at the extremities | anything spotted |
| `giraffe` | flat cells separated by lanes | anything tiled, cracked or leaded |
| `cow`, `ladybird` | blotches, and discs | anything blobby or dotted |
| `phoenix` | overlapping scallops on a staggered lattice | anything feathered, scaled or shingled |
| `dragon` | the cell field with the input vector SQUASHED | wide-and-short scales |
| `stormwolf` / `stormstone` | a Voronoi cell-net that makes forks branch | lightning, cracks, veins |
| `diamond` | 3D Voronoi facets plus a normal map | anything faceted or crystalline |
| `metal` | bands whose alpha hands the tint back to the skin | **one upload, many metals** |

**THE ALPHA PASS IS THE OTHER HALF.** `make/bake_alpha.py` plus
`make/apply_alpha.py` lets a sheet hand SOME of its texels back to the client
animator, so part of a coat moves and the rest stays baked. A material with no
`ALPHA_MASK` node bakes fully opaque, so the pass existing costs finished skins
nothing.

**AND IT COLLAPSES A MULTI-COLOUR REGION INTO ONE.** `lerp(part.Color,
map.RGB, map.Alpha)` has one part colour in it, so every alpha-0 texel gets the
same `Color3`. The test before reaching for it: *how many colours are in the
region you are about to make transparent?* More than one and the pass costs you
all but one of them.

---

## 4. What exists today — all 46, sorted by what they are made of

Measured over `Config.SKINS`, not counted by eye. **`tier now` is what the row
is tagged; `tier derived` is what §2 makes it.** Where they differ, the derived
one is right and the tag is the thing to change.

### 4a. Flat colour only — 10

| key | name | tier now | derived | body / material | verdict |
| --- | --- | --- | --- | --- | --- |
| `classic` | Classic Pink | common | common | pink, SmoothPlastic | **keep** — the free starter, on most tills |
| `bubblegum` | Bubblegum | common | common | hot pink, SmoothPlastic | keep |
| `mint` | Mint Choc | common | common | mint + cocoa trim | keep |
| `sunset` | Sunset | common | common | orange + rose trim | keep |
| `midnight` | Midnight | common | common | indigo, Glass | keep |
| `lava` | Lava | common | common | orange, Neon | keep — the orange glow |
| `galaxy` | Galaxy | common | common | violet, Neon | keep |
| `pearl` | Pearl | common | common | pale, Glass | keep |
| `bronze` | Bronze | rare | **common** | bronze, Metal | keep, re-tier |
| `goldleaf` | Gold Leaf | rare | **common** | gold, Metal | **CUT** — third metal, dE 15.3 from Bronze |

### 4b. A baked coat — 17

| key | name | tier now | derived | generator | verdict |
| --- | --- | --- | --- | --- | --- |
| `bullion` | Solid Gold | legendary | **rare** | `metal` (bands) | keep, re-tier |
| `diamond` | Diamond Facets | legendary | legendary | `diamond` + `fx` + `aura` | keep |
| `ladybird` | Ladybird | common | **rare** | `ladybird` | keep, re-tier |
| `cow` | Dairy Cow | common | **rare** | `cow` | keep, re-tier |
| `zebra` | Zebra | common | **rare** | `zebra` | keep, re-tier |
| `bee` | Bumblebee | common | **rare** | `bee` (full-colour) | keep, re-tier |
| `giraffe` | Giraffe | common | **rare** | `giraffe` | keep, re-tier |
| `leopard` | Leopard | common | **rare** | `rosette` | keep, re-tier |
| `tiger` | Bengal Tiger | common | **rare** | `tiger` | keep, re-tier |
| `snowleopard` | Snow Leopard | common | **rare** | `rosette` | **CUT** — third rosette |
| `strawberrycow` | Strawberry Cow | rare | rare | `cow` | keep |
| `cookiescream` | Cookies & Cream | rare | rare | `cow` | **CUT** — third cow blotch |
| `watermelon` | Watermelon | rare | rare | `ladybird` | keep |
| `peppermint` | Peppermint | rare | rare | `tiger` | keep |
| `glacier` | Glacier | rare | rare | `tiger` | **CUT** — third tiger stripe |
| `bubblegumleopard` | Bubblegum Leopard | rare | rare | `rosette` | keep |
| `honeycomb` | Honeycomb | rare | rare | `giraffe` | keep |

### 4c. An `anim` and nothing else — 10

| key | name | tier now | derived | anim | verdict |
| --- | --- | --- | --- | --- | --- |
| `ember` | Ember Glow | rare | rare | pulse, Neon orange | **CUT** — third orange glow |
| `frostbite` | Frostbite | rare | rare | pulse, Glass ice | keep |
| `toxic` | Toxic Ooze | rare | rare | cycle, Neon green | keep |
| `candyswirl` | Candy Swirl | rare | rare | cycle, pastel | keep |
| `aurora` | Aurora | rare | rare | cycle, Neon teal | keep |
| `magma` | Magma Core | rare | rare | flicker, Neon orange | **CUT** — dE 7.9 from Lava, the closest pair in the catalogue, AND the key is wanted by the finished Blender coat at `assets/piggies/rare/magma/` |
| `voidsilk` | Void Silk | rare | rare | pulse, Glass | **CUT** — fourth Glass, shares `pulse` with Frostbite |
| `cyberlime` | Cyber Lime | rare | rare | pulse, Neon lime | **CUT** — dE 13.3 from Toxic |
| `neonmint` | Neon Mint | rare | rare | pulse, Neon mint | **CUT** — Mint Choc plus Neon, the palette split Neon Nights already refused |
| `martian` | Martian | epic | **rare** | pulse, Neon green | keep — alien set, `rarity` override stays |

### 4d. `fx` geometry plus `aura` — 6

| key | name | tier now | derived | fx / aura | verdict |
| --- | --- | --- | --- | --- | --- |
| `supernova` | Supernova | legendary | legendary | `supernova` / `sunburst` | keep |
| `stormcaller` | Stormcaller | legendary | legendary | `stormcaller` / `storm` | keep |
| `prismatic` | Prismatic | legendary | legendary | `prismatic` / `prism` | keep |
| `velvet` | Velvet Rope | legendary | legendary | `vip` / `spotlight` | keep — pass skin |
| `firstday` | Party Piggy | rare | **legendary** | `party` / `confetti` | keep, re-tier |
| (`diamond`) | — | — | — | listed in 4b | — |

### 4e. Whole-model creatures — 4, and these are MYTHIC

| key | name | meshes | generator lineage |
| --- | --- | ---: | --- |
| `stormwolf` | Storm Wolf | 9 | Voronoi cell-net forks, alpha pass |
| `dragon` | Ember Dragon | 24 | squashed cell field, burning seams animate |
| `phoenix` | Ice Phoenix | ~12 | staggered scallop lattice, feather tips animate |
| `rainbowtiger` | Rainbow Tiger | ~12 | `tiger` with hue indexed off the stripe number |

### 4f. Built in Blender, NOT wired into `Config` — free content sitting there

| dir | what it is | where it goes |
| --- | --- | --- |
| `assets/piggies/rare/magma/` | dark plates, glowing cracks, alpha pass done | **rare** — takes the `magma` key once the flat row above is cut |
| `blender/pig/skins/stainedglass/` | jewel panes, near-black leading, alpha pass done | **rare** |
| `assets/piggies/epic/stormstone/` | broken rock with lightning in the cracks, `shards` + Neon bolts | **legendary** (it has geometry) |

**Three finished skins are one Config row each away from shipping.** That is
the cheapest content in this entire document and it should go first.

---

## 5. The rule that outranks everything else in this file

**EVERY GENERATION AND EVERY UPLOAD IS PUBLISHED UNDER THE DEVELOPER'S OWN
ACCOUNT, AND IT HAS ALREADY COST A BAN.** `generate_material` was run twelve
times in one session to compare candidates — one call returns four variants,
each with four maps, so three calls was forty-eight uploaded images — and the
account was actioned for an asset named *Generated RoughnessMap*, a greyscale
noise image with nothing depicted in it.

The blast radius is the ACCOUNT, not the experience. It does not strip one
asset; it stops the developer opening Studio, and it presents as a broken login
(`403` across DataStore, sound, group and product APIs at once).

So, in order of preference:

1. **Flat colour and `pattern` parts cost nothing and upload nothing.** Every
   common in §6 is one of these on purpose.
2. **A baked coat is two uploads.** Generate one candidate, not twelve.
3. **A whole-model creature is many.** Four exist; the plan does not ask for
   more.

---

## 6. The map — every skin to build

37 survive §4's nine cuts. 43 new take the catalogue to 80, on the
distribution packs plan §6b derives: **24 common, 30 rare, 14 epic, 8
legendary, 4 mythic.**

Every new row below names its mechanism and, where it needs one, its
generator. **A row with a generator is a palette swap on a script that already
runs** — an afternoon, not a modelling job.

---

### 6a. OG — "the piggy family" · 15 BUILT, 2026-09-21

**OG IS MADE IN STUDIO, NOT IN BLENDER, AND THAT IS THE SHELF'S IDENTITY
(designer, 2026-09-21).** The street's own pigs are built out of what the
engine hands out for free — flat colour, a material, `pattern` PARTS, an
`anim`, an `aura` — so nothing on this shelf is uploaded and nothing on it can
be moderated away. Baked coats belong to the animal shelf. The three coats this
section used to list for OG (Spotty, Piggy Bank, Patched) are still built in
`assets/piggies/` (`spotty`, `piggybank`, `patched`) and are un-shelved rather than cut; they want a home on
Farmyard or a later pack.

**Fifteen rows landed in `Config.SKINS` under the OG FAMILY block, every one
authored rather than measured.** The first pedestal render found the fault the
retired Neon stripe-and-dot skins had been reporting as "stuck ON the mesh
pig": every part-built mark was seated on a SPHERE and the body is not one, so
spots floated a stud off the flank. `PiggyModel.surfaceSampler` seats marks on
the real surface now (raycast against a precise probe of the body), verified
live on Muddy, Sooty and Marble at 0.10 to 0.18 studs of inner-face bury with
the spread under 0.02. **Looked at: Rockslide (good), Muddy (good after the
fix). Not yet looked at: Marble and Banker after the fix** — their arcs were
standing off the crown before it, and thin bands are the shape most likely to
still want tuning.

| key | name | tier | mechanism | spec |
| --- | --- | --- | --- | --- |
| `classic` | Piggy | common | flat | *exists* — rename to its type still open |
| `muddy` | Muddy Piggy | common | flat + `spots` | pink body, **pink trim**, 9 brown splats `size 0.15 vary 0.42` |
| `sooty` | Sooty Piggy | common | flat + `spots` | pale grey, mid-grey trim, 11 near-black spots |
| `rosegold` | Rose Gold | common | flat, Metal | pink-copper, `reflectance 0.32`; base pulled down so the highlight has range |

| key | name | tier | mechanism | spec |
| --- | --- | --- | --- | --- |
| `marble` | Marble | rare | `stripes` | cream; 6 thin veins, `wobble 0.9 taper 0.7`, pole tilted `(0.55, 0.7, 0.45)` |
| `rockslide` | Rockslide | rare | `shards` | slate; 16 matte shards, no glow — the silhouette rare |
| `quartz` | Quartz | rare | `shards` on Glass | pale pink glass, 12 white SmoothPlastic crystals |
| `banker` | Banker Piggy | rare | `stripes` | cream; 14 navy pinstripes on the FLANK pole (`axis = X`) so they run nose to tail, `faceGap 18` |
| `tiedye` | Tie-Dye | rare | `anim` cycle + `spots` | SmoothPlastic cycling pink / orange / violet under 8 pale-yellow splats |
| `verdigris` | Verdigris | rare | flat Metal + `spots` | copper with 14 matte green patina spots |

| key | name | tier | mechanism | glow | aura |
| --- | --- | --- | --- | --- | --- |
| `ghost` | Ghost Piggy | epic | Glass + slow `pulse` | Neon eyes `(170, 232, 232)` | `wisp` (new: pale smoke, up, sparse) |
| `charcoal` | Charcoal Piggy | epic | near-black + `shards` | every 2nd shard Neon ember, Neon eyes | `embers` (existing) |
| `starlight` | Starlight Piggy | epic | midnight Glass + `shards` | every shard a white Neon point, Neon eyes | `sparkle` (existing) |
| `nightlight` | Nightlight Piggy | epic | deep amber Neon + `pulse` | the body, `glow 1.4` | `fireflies` (new: 5/s, drifting) |
| `sugarrush` | Sugar Rush Piggy | epic | Neon candy `cycle` | the body, `glow 1.8` | `fizz` (new: candy sparkle at a boil) |
| `hologram` | Hologram Piggy | epic | `ForceField` cyan | the material's own shimmer, Neon eyes | `hologram` (new: static, cyan) |

**Bubble Piggy was dropped from the six** (designer). **Birthday was never
built**: Party Piggy already owns confetti and a hat, and an earned epic that
reads as the starter-pack skin undercuts the pack.

**Legendaries — none new.** Diamond, Supernova, Stormcaller and Prismatic
stay, and their `order` moved to 60–62 so the shelf reads in tier order.

**What the block changed beyond the rows.** `Config.skinAura` admits epic (it
refused everything under legendary); `CHESTS.og` rolls 52 / 32 / 12 / 4 again
with `ograre` at 60 / 30 / 10 and `oglegendary` at 40 / 25 / 35; and
`COMBINE.need` is back to 3, re-derived against the restored odds (25 opens by
either route). Herds and resident lawns still exclude any skin carrying an
aura, so no epic spawns in a herd yet — that rule predates epics and wants
revisiting now that herds are the primary acquisition route.

**The mood commons (Happy, Sad, Sleepy, Angry, Cheeky, Grandpa, Fatty, Momma,
Jr) stay on the bench** until the `face` and `prop` mechanisms exist. They are
the right idea and not buildable today.

---

### 6b. Farmyard — today's `animal` · 1 new

Its seven surviving coats all become RARE (§4b), which empties its common
tier. **The OG family is what restocks it** — that is the hard interlock in
packs plan §2 and it is why OG ships first.

| key | name | tier | mechanism | spec |
| --- | --- | --- | --- | --- |
| `firefly` | Firefly Piggy | epic | flat + `anim` + `aura` | dusk-green body, `flicker`, drifting motes |

---

### 6c. Sweet Shop — latent inside `animal` today · 3 new

Five coats already exist here (Strawberry Cow, Watermelon, Peppermint,
Honeycomb, Bubblegum Leopard). It needs nothing but a top end.

| key | name | tier | mechanism | spec |
| --- | --- | --- | --- | --- |
| `candyfloss` | Candy Floss Piggy | epic | flat + `anim` + `aura` | pink/white `cycle`, a sugar-dust aura |
| `fizzypop` | Fizzy Pop Piggy | epic | flat + `aura` | orange soda body, rising bubbles |
| `gingerbread` | Gingerbread Piggy | epic | coat · `cow` + `aura` | biscuit body, white icing piping, a warm crumb aura |

---

### 6d. Deep Sea · 8 new

| key | name | tier | mechanism | spec |
| --- | --- | --- | --- | --- |
| `sand` | Sandy Piggy | common | flat | pale sand, wet-sand trim |
| `tide` | Tide Piggy | common | flat + `spots` | sea-glass green, scattered pebble spots |
| `clownfish` | Clownfish Piggy | rare | coat · `zebra` | orange with three white bands, black edging |
| `koi` | Koi Piggy | rare | coat · `cow` | white with red-orange blotches |
| `pufferfish` | Pufferfish Piggy | rare | coat · `ladybird` + `spots` `bump` | sand body, dark discs, raised bumps as spines |
| `biolum` | Bioluminescent Piggy | epic | flat + `anim` + `aura` | deep indigo, slow `pulse`, drifting blue motes |
| `jellyfish` | Jellyfish Piggy | epic | flat Glass + `anim` + `aura` | translucent violet, `cycle`, trailing particles |
| `kraken` | Kraken Piggy | legendary | coat · `phoenix` + new `fx` + `aura` | deep-sea hide in overlapping scallops, suckered tendrils ringing the body, an ink aura |

---

### 6e. Dino · 7 new

| key | name | tier | mechanism | spec |
| --- | --- | --- | --- | --- |
| `stone` | Stone Piggy | common | flat | grey granite, darker trim |
| `fossil` | Fossil Piggy | common | flat + `spots` | bone-cream body, dark ammonite discs |
| `stego` | Stego Piggy | rare | coat · `dragon` + `shards` | olive scales; a ridge of plates down the spine |
| `raptor` | Raptor Piggy | rare | coat · `tiger` | teal body, dark dorsal stripes, cream belly |
| `tarpit` | Tar Pit Piggy | epic | flat + `anim` + `aura` | glossy black, slow `pulse`, rising bubbles |
| `amber` | Amber Piggy | epic | flat Glass + `aura` | honey-gold translucent, a `glint` aura with a fleck suspended in it |
| `trex` | T-Rex Piggy | legendary | coat · `dragon` + new `fx` + `aura` | pebbled hide, a crest and a row of back-plates, a dust aura |

---

### 6f. Arcade · 5 new

| key | name | tier | mechanism | spec |
| --- | --- | --- | --- | --- |
| `pixel` | Pixel Piggy | common | flat + `spots` | flat primary body, large square-ish spots at low `count` |
| `checker` | 8-Bit Piggy | rare | coat · `giraffe` | even square cells, two flat colours, hard edges |
| `circuit` | Circuit Piggy | rare | coat · `stormwolf` net | dark board-green, traced copper lines, alpha pass on the traces |
| `powerup` | Power-Up Piggy | epic | flat Neon + `anim` + `aura` | saturated Neon on `cycle`, rising star motes |
| `hiscore` | Hi-Score Piggy | epic | flat + `anim` + `aura` | black body, gold `flicker`, a `sunburst` aura |

**`glitched` is held back deliberately.** It is the seed of the future
Glitched tier (packs plan §0), and spending it as an ordinary legendary now
means that tier opens with nothing in it — the empty-rung failure this project
has already recorded once.

---

## 7. The count

Counted off the tables in §6 rather than asserted — the first draft of this
table said 5 OG rares and the table above it listed 7, which is the kind of
number that gets quoted later and is wrong.

| | common | rare | epic | legendary | mythic | total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| kept after §4's nine cuts | 9 | 18 | 0 | 6 | 4 | **37** |
| OG family | 10 | 7 | 4 | 1 | 0 | 22 |
| Farmyard | 0 | 0 | 1 | 0 | 0 | 1 |
| Sweet Shop | 0 | 0 | 3 | 0 | 0 | 3 |
| Deep Sea | 2 | 3 | 2 | 1 | 0 | 8 |
| Dino | 2 | 2 | 2 | 1 | 0 | 7 |
| Arcade | 1 | 2 | 2 | 0 | 0 | 5 |
| **new** | **15** | **14** | **14** | **3** | **0** | **46** |
| **total** | **24** | **32** | **14** | **9** | **4** | **83** |

`classic` appears in §6a as a RENAME rather than a new row, and `magma` as a
key RECLAIMED — the flat Neon rare is cut in §4c and the finished Blender coat
takes the key. Neither is counted as new above.

**Against packs plan §6b's target of 24 / 30 / 14 / 8 / 4:** common and epic
land exactly, rare is +2 and legendary +1. Both are inside the noise of a
draft, and §6a's bench is what absorbs the difference if the ladder needs
holding precisely — the property to preserve is the per-name column in that
plan, not these counts.

**EPIC IS THE ONE THAT MATTERS.** It goes from a standing start of **zero** to
14. Nothing in the catalogue carries an `aura` without also carrying `fx`
today, so epic is the one rung no crate can currently authorise odds for at
all — and §1e's one-line gate in `Config.skinAura` has to open with it.

---

## 8. Rules an author must not break

Each of these is a failure this project has already paid for once.

1. **Never generate twelve candidates.** §5. It cost an account.
2. **`trim` is the snout, ears, tail and legs.** Three are on the face.
3. **A Neon part needs a deep colour**, or it is a white hole under the bloom.
4. **A `Ball` ignores a non-uniform size; a `Cylinder` does not.** Three balls
   at (6,6,6), (12,6,6) and (6,12,6) render identically.
5. **A Roblox cylinder's axis is its X axis.** Written the other way round it
   is a disc on edge — five separate times so far.
6. **Surfaces must never be coplanar.** Two faces at one depth flicker.
7. **Price every legendary.** `Config.sellValue` only caps a payout on a row
   with a `cost`, so an unpriced legendary sells for the full tier value — more
   than the chest that produced it.
8. **A cut key must be pruned against the CATALOGUE, never a list of names**,
   and the prune has to reach `data.piggies.owned` and `data.piggies.slots` as
   well as the old wardrobe tables. A retired key in a slot renders nothing on
   a plinth, with nothing in any log.
9. **Nothing in a chest may authorise odds for a tier it cannot stock.**
   `liveOdds` silently renormalises, which reprices the crate rather than
   refusing it.
10. **Look at it.** Three separate things on this pig — the tail cap's depth,
    the vault rim, the hatch disc — were each retired or mis-seated on a number
    measured against a MODEL of the body rather than the body. On a generated
    mesh the only instrument that touches the real surface is a picture.

---

## 9. What is NOT in this file

* **Faces.** Their own axis and their own piece of work.
* **Colour values.** Every row above names a palette in words on purpose —
  the exact `Color3`s are an authoring decision, and the one hard constraint
  on them is rule 3 plus the dE 14 separation test in packs plan §5a.
* **Prices.** Every crate-only skin still carries a `cost` as a RARITY INPUT
  and a SELL CEILING, never as a purchase (packs plan §5a).
