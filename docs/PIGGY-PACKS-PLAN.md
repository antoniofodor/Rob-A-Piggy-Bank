# Piggy packs — the content track

**Status: draft for approval, 2026-09-21. Nothing here is built.**

This is the content half of `docs/PIGGY-COLLECTION-PLAN.md`. That plan turns a
skin into an object you own, place, lose and earn from; this one is about what
those objects ARE, how many there should be, and in what order they get made.
It exists because §6 of the collection plan flags the catalogue size as "a
content-authoring track, not a blocker for Stage 4's engineering" and then
stops — and because the brief changed on 2026-09-21 in ways that reach further
than a count.

**`docs/PIGGY-SKIN-MAP.md` IS THE BUILD SPEC THAT CAME OUT OF THIS.** This
file is the reasoning — why five tiers, why 80, what the cut list is measured
on. That one is the row-by-row map an author works from: every skin the
catalogue can contain, the mechanism that makes it, and the Blender generator
that draws it. Where the two disagree about a count, the map is counted off its
own tables and this one is not.

**FACES ARE A SEPARATE WORKSTREAM.** §5c argues the common tier should be
expressions, and that stands; the implementation is somebody else's and
deliberately not specified here or in the map.

`docs/animal-crate-plan.md` stays the authoritative working doc for the ANIMAL
shelf's technique ladder and the Blender pipeline. Nothing here replaces it;
§1 below generalises its central finding to the whole catalogue.

---

## 0. What the brief changed

Four things, and the first is the one the rest fall out of.

**A skin stops being a costume and becomes A PIGGY — a named thing, not a
paint job.** The player-facing noun is the object: *Piggy*, *Muddy Piggy*,
*Happy Piggy*, *Sad Piggy*, *Cow Piggy*. Nobody owns "the Bubblegum skin" any
more; they own a Bubblegum Piggy, and it is standing on a plinth earning coins.

**The tier is a NAMEPLATE and a PRODUCTION CLASS at the same time.** The name
stands above the object and its colour says the tier:

| tier | nameplate | what the object IS |
| --- | --- | --- |
| Common | plain text | a piggy with a look — *Piggy*, *Muddy Piggy*, *Happy Piggy* |
| Rare | **blue** text | a described variant — *Cow Piggy* |
| Epic | (colour open) | a non-standard piggy **with an effect** |
| Legendary | **gold** text | added **geometry** and effects |
| Mythic | **a nameplate that MOVES** | the piggy is a different creature entirely |

**FIVE TIERS, BECAUSE MYTHIC ARRIVED EARLY — resolved 2026-09-21.** It was
going to be a later rung; it is a rung today, because the four whole-model
creatures are already built and *"those took a lot of effort."* Storm Wolf,
Ember Dragon, Ice Phoenix and Rainbow Tiger move up, and §9f records that this
single decision takes the legendary tier from fourteen-against-a-target-of-six
to exactly on target, with no re-tagging anywhere else.

**The test is one field.** `Config.LEGENDARIES[key]` exists means the pig's own
BODY has been replaced by a 9–24-mesh creature; that is mythic. `fx` geometry
attached to an ordinary body is legendary. Nothing about that needs a judgement
call, which is §1's whole argument.

**The mythic nameplate is the only one that moves**, which is the tier ladder's
own logic applied to the label: each rung is a different KIND of thing, and
*legendary glows and moves* has a natural next step in *the name itself
moves*. A slow hue cycle, never a strobe — continuous curve, under `MAX_RATE`,
the photosensitivity rule `HouseFX` holds the whole game to.

**Glitched is still later**, and the Arcade pack (§9e) is where its first row
comes from. The requirement on the code is unchanged: the tier list, the
nameplate treatments and the income multipliers are DATA that a row can be
added to, never a branch.

**Target ~80 piggies, and refine before expanding.** Delete what is too
similar to something else first; fix the art direction (§5b); then ship packs.
The order is deliberate and it is the same discipline the collection plan's own
Stage 7 follows — replace a thing only once the replacement has proven itself.

---

## 1. The tier ladder is the production ladder, and it has to be DERIVED

`docs/animal-crate-plan.md` §4 already argues this for one shelf:

> COMMON AND RARE ARE PAINT. EPIC GLOWS. LEGENDARY GLOWS AND MOVES. ... a
> player can SEE which tier a skin is without being told, because the tiers
> are different KINDS of object rather than different qualities of the same
> object.

The new brief is that argument with the rungs redrawn, and it maps cleanly onto
mechanisms this game has already built:

| tier | mechanism in code today | authoring cost |
| --- | --- | --- |
| Common | `body`/`trim` colour + `material`, `pattern` parts, plus (new) `face` and `prop` parts — see §9a/§9b | an afternoon, no upload |
| Rare | a baked coat (`surface`/`template`) **or** an `anim` block | a Blender pass plus two uploads, or an hour |
| Epic | `aura` particles, no attached geometry | a `SKIN_AURAS` row and a palette |
| Legendary | `fx` geometry (`Shared/SkinFX`) **plus** `aura` | code-built shape, no upload |
| Mythic | a whole-model creature in `Config.LEGENDARIES` | weeks, 9–24 meshes, many uploads |

**`Config.PIGGY_RARITY_INCOME` NEEDS A FIFTH ROW, AND THE FALLBACK IS WHY IT
CANNOT BE FORGOTTEN.** That table runs 1 / 4 / 8 / 15 and its own comment
records the trap in as many words: an unknown rarity falls back to 1x, which
*"would have made a 120-loot event exclusive pay exactly what the free starter
pays, with nothing erroring and nothing in any log."* A mythic with no row
earns like a Classic. Continuing the ladder geometrically puts it near **28**
(15 x 1.87, the same step epic-to-legendary takes), and it is provisional
exactly like the four above it — none of the five is solved against
`auditRobbery` yet, which is collection plan §8's job.

**THE TIER MUST BE DERIVED FROM THE MECHANISM, NOT TYPED BESIDE IT, AND THAT
REVERSES AN EXEMPTION THIS PROJECT GRANTED ON PURPOSE.** `CLAUDE.md` states
the general rule — *"A tier is DERIVED, never hand-tagged... hand-tagging
sixty of them means re-tagging them every time a price moves"* — and then
records skins being exempted from it, because once skins stopped being priced
there was no price left to derive from: *"All 44 skins carry an explicit
`rarity`."*

That exemption expires here, for a reason stronger than the one that created
it. **Rarity is INCOME now** (`Config.PIGGY_RARITY_INCOME`, 1 / 4 / 8 / 15x).
A hand-typed tier on eighty objects is eighty hand-typed income rates, and a
tag that drifts from what the object actually IS is a piggy that earns four
times what it looks like it should — silently, with nothing erroring, which is
the failure family this repo keeps a whole section on.

**So `rarityOf` gains a piggy branch that reads the mechanism**: geometry and
an aura is legendary, an aura alone is epic, a coat or an anim is rare, colour
alone is common. An explicit `rarity` stays legal as an OVERRIDE for the
handful that need one — the alien-set Martian is the documented case — and the
audit worth writing is that an override may never CONTRADICT the mechanism,
only refine it. Same shape as `Config.CASING` deriving its threshold from
`Lockpicks.max` rather than pinning it.

---

## 2. Where the catalogue actually stands against that ladder

Measured over `Config.SKINS` (46 rows) rather than counted by eye:

| production class | what carries it | count | tagged today |
| --- | --- | ---: | --- |
| flat colour only | classic, bubblegum, mint, sunset, midnight, lava, galaxy, pearl, bronze, goldleaf | 10 | 8 common, 2 rare |
| a baked coat | 8 animal commons, 7 animal rares, bullion's `bands`, diamond | 17 | 8 common, 7 rare, 2 legendary |
| an `anim` block, no coat, no effect | ember, frostbite, toxic, candyswirl, aurora, magma, voidsilk, cyberlime, neonmint, martian | 10 | 9 rare, 1 epic |
| `fx` geometry plus `aura` | diamond, supernova, stormcaller, prismatic, velvet, firstday | 6 | 4 legendary, 1 rare, 1 legendary |
| whole-model creature | stormwolf, dragon, phoenix, rainbowtiger | 4 | 4 legendary |

Four findings, in the order they bite.

*(Resolved 2026-09-21: the OG family stocked the rung with six Studio-built
epics and `Config.skinAura` admits epic — see `docs/PIGGY-SKIN-MAP.md` §6a.
The paragraph below is kept as the record of why it mattered.)*

**EPIC HAS ZERO STOCK, AND IT IS THE RUNG THE BRIEF MOST WANTS.** Nothing in
the catalogue carries an `aura` without also carrying `fx`. The Martian — the
one row tagged `epic` today — is `anim = pulse` and nothing else, which is a
rare under the derived rule. So the middle rung cannot be authorised in any
crate until a pack carries one: `auditRandomOutcomes` refuses odds for a tier
that cannot be stocked, and the one thing worse than that refusal is the
failure it was written to catch — `liveOdds` silently renormalising the missing
tier's points onto the tiers above it, which is a REPRICING rather than a
rounding. **The first pack must carry epics, or epic odds stay off.**

**`Config.skinAura` REFUSES ANYTHING THAT IS NOT LEGENDARY.** Its first line is
`if not tier or Config.rarityOf(tier) ~= "legendary" ... return nil`. An epic
piggy authored with an `aura` therefore gets no particles at all, with nothing
in any log — the whole identity of the rung, silently absent. That gate has to
open to epic in the same change that creates the rung, and it is one line.

**RE-TAGGING EMPTIES THE ANIMAL SHELF'S COMMON TIER.** All eight of its commons
are baked coats (Ladybird, Dairy Cow, Zebra, Bumblebee, Giraffe, Leopard,
Bengal Tiger, Snow Leopard), and a coat is a RARE under the new ladder.
`Config.CHESTS.animal` authorises `common = 52`, and its own comment already
records what happens when a tier it authorises has no stock: measured last
time, 52/44/4 over a pool with no rares resolved to 93% common and 7.1%
legendary, *"which is 7.0M per legendary against the 12.5M every other 500K
crate charges, making this quietly the best value in the game."* **So the
re-tag may not ship before that shelf has commons.** It is the hardest
sequencing constraint in this document.

**LEGENDARY IS 22% OF THE CATALOGUE AT 4% ODDS.** Ten rows qualify as legendary
under the derived rule, against a tier that is rolled 4% of the time — so a
NAMED legendary is about 0.4% a pull, roughly 250 opens. The animal-crate plan
already states the mechanism (*"two legendaries is a 2% shot at a named one and
four is 1%"*); what is new is that the number has drifted to ten while nobody
was counting. The legendary tier wants CUTTING or splitting, not growing — see
§6b.

---

## 3. What the re-tag costs, stated plainly

* **Income moves on every row that changes tier.** Eight animal coats going
  common to rare is 4x the income on eight objects. This lands squarely in the
  economy re-derivation the collection plan §8 already calls *"the single
  largest piece of work in the plan"* — so it should be done BEFORE that
  derivation rather than after it, or the derivation is solved against a
  catalogue that is about to change underneath it.
* **Crate odds and the solved price ladder.** Restoring epic means restoring
  `epic = 3 x legendary` (12 against 4), which `Config.CHESTS.animal`'s own
  comment records as the relation that keeps `Config.COMBINE` level against
  rolling directly. `COMBINE.need` is 5, derived against THREE tiers — a fourth
  tier re-opens that derivation. The table to re-run is the one in
  `Config.CHESTS`: coins per legendary, 12.5M / 15.0M / 17.1M.
* **`Config.sellValue`'s cap only applies to a priced row.** The animal-crate
  plan flags this and it gets one notch worse per unpriced legendary: an
  unpriced legendary sells for the full tier value against a chest that cost a
  fraction of it. Every legendary needs a `cost`, which is a RARITY INPUT and a
  SELL CEILING and never a purchase.
* **A cut key has to be pruned from the new save shape, not just the old one.**
  `DataService.reconcile` prunes the wardrobe tables and `spares` against their
  catalogues. `data.piggies.owned` (a count map) and `data.piggies.slots` (keys
  standing on pedestals) are new and are not on that list. A retired key left
  in a slot renders nothing on a plinth, with nothing in any log — which is
  `Decor.buildOne` returning nil exactly, the failure this repo has the most
  words about. **Confirm the prune reaches both before the first row is cut**,
  which is free to do now because nothing has been earned yet.

---

## 4. The nameplate is new UI, and it is what makes any of this legible

The brief's tier treatment is A NAME STANDING ABOVE THE OBJECT, coloured by
tier. Nothing like it exists today.

**What exists is `PiggyPedestal` writing `prompt.ObjectText = skin.name`** —
the right string in the wrong place twice over. A ProximityPrompt card is only
drawn INSIDE range, and pedestal prompts are owner-only
(`PROMPT_OWNER_ATTRIBUTE`), so today a piggy's name is visible to exactly one
person, standing next to it. A collection nobody can read from the pavement is
not a collection, and it is the rob badge's own argument arriving on a second
object: *an absence is something a new player cannot read.*

**Constraints, all of them already paid for once elsewhere in this project:**

* **Not `AlwaysOnTop`.** A name that punches through the house it is behind
  reads as a HUD element — the shop fascia plaque's own rule. It also makes the
  thing invisible to every screenshot ever taken of it, which this repo records
  as having cost six systems their entire visual verification.
* **Distance-capped.** The shop plaque caps at 260 studs *"because eight of
  these legible from anywhere on a 350-stud street is a wall of text over the
  world"*. This is eighty-four of them — six pedestals across fourteen plots —
  so the cap matters more here, and it wants measuring rather than copying.
* **Rounded in SCALE, not pixels**, for the plaque's reason: a billboard's
  pixel size falls with distance, so an offset corner radius is a nick up close
  and a lozenge from across the street.
* **The colours have to clear `Theme`'s contrast floors against GRASS AND SKY**,
  not against a card. Gold on a bright lawn in full sun is the pairing to
  measure first: raw gold measures 1.42:1 on paper here, which is why
  `Theme.GOLD_INK` exists at all. Use `Theme.readable` against the ground it
  actually sits on, and remember the stroke is what holds paper type legible
  over a drawing — `Contextual`, never `ApplyStrokeMode.Border`, which outlines
  the label's invisible rectangle rather than its glyphs.
* **The colour table is DATA.** Glitched and Mythic are promised; a branch per
  tier is a branch to edit twice.

**And it is the second reader of the tier**, after income — which is the
argument for deriving the tier in §1 rather than typing it. A nameplate saying
Legendary over a piggy earning the rare rate is the two-copies-of-one-fact
failure in its most visible possible form.

### 4a. A nameplate that is not `AlwaysOnTop` inherits the fence, and a live photo pass found it

**Corrected 2026-09-21, from the Stage 1 sightline pass in
`docs/PIGGY-COLLECTION-BUILD-ORDER.md`.** Everything above is right about
what a nameplate is FOR and wrong about what one surface can carry.

Measured on a live plot: lawn 0.50, plinth top 1.75, display top **5.20**,
against a Picket barrier at 4.30 and the three climbed tiers at **7.50**. So
behind Picket about a quarter of a piggy shows and behind Barbed, Electric or
Moat **not one pedestal is visible from the street**. A label pinned above an
object that is 2.3 studs below a fence is 2.3 studs below a fence. **§4's own
rule against `AlwaysOnTop` therefore also refuses it the one job this section
opened by claiming for it** — reading a collection from the pavement.

**SO IT IS TWO QUESTIONS AND TWO SURFACES, and they were one because nobody
had looked at the fence.**

| question | surface | occluded? |
| --- | --- | --- |
| *Is this lawn worth going into?* | the **rob badge**, which already punches through | no — that is what it is for |
| *What is that particular piggy?* | the **nameplate**, over the object | yes, exactly like the object |

That split is not a compromise, it is the answer this project already reached
once on the same geometry. `CLAUDE.md` records the pig's own fill ceasing to
read from the street at high fence tiers, and the fix was *"not taller
geometry, it was the rob badge publishing the figure."* The build-order's own
sightline entry reaches the identical conclusion independently, and adds the
better half: **the badge says what a lawn is CARRYING while the fence goes on
hiding WHICH pieces.**

**AND THE BADGE ALREADY HAS THE VOCABULARY.** A maxed Lockpicks grows it *"a
four-pip ladder showing the victim's Vault Lock tier"* — a pip ladder on that
exact billboard, gated behind an upgrade, reading a fact about a lawn from the
pavement. A best-tier-on-this-lawn marker is that mechanism a second time, and
`Config.CASING` is the precedent for making the richer read something a rung
HANDS OVER rather than something everybody gets.

**WHAT IT BUYS IS BETTER THAN WHAT THE NAMEPLATE WOULD HAVE**, which is the
part worth keeping. Knowing a lawn holds a mythic without knowing which one or
where turns a raid into a search rather than a shopping trip — and the
collection plan's §5 verb is a hold on a pedestal, so a thief who gets in still
has to pick. A street where you can read every name through every fence is a
catalogue with a fence drawn on it.

**§10c SURVIVES THIS INTACT, and the reason is worth stating so nobody
"fixes" it twice.** That section makes the nameplate the catalogue now that
nobody browses a shop. Nothing occludes a HERD piggy running down the street,
nothing occludes your own lawn, and nothing occludes the bag — which is where
you learn what exists. The fence only occludes the one case that is not about
learning at all: deciding whether to rob somebody. Different question, and it
has its own surface now.

*Open: what exactly does the badge publish — the best tier on the lawn, a
count per tier, or a pip ladder? And is the richer read free or is it
`Config.CASING`'s second verb?*

---

## 5. Phase 0 — refine what exists, before any pack is authored

### 5a. The cut list, measured rather than eyeballed

Perceptual distance (CIE Lab dE over `body` and `trim`) across the flat rows,
plus generator identity across the coats. The clusters:

| cluster | rows | evidence |
| --- | --- | --- |
| **orange glow** | Lava (com), Magma Core (rare), Ember Glow (rare) | Lava/Magma dE **7.9**, both Neon — the closest pair in the catalogue |
| **acid green** | Toxic Ooze, Cyber Lime | dE **13.3**, both Neon, both animated |
| **mint and teal** | Mint Choc, Neon Mint, Aurora | Neon Mint is Mint Choc plus Neon, which is the palette split the Neon Nights retirement already refused |
| **glass** | Midnight, Pearl, Frostbite, Void Silk | four Glass bodies; Frostbite and Void Silk share `anim = pulse` |
| **metal** | Bronze, Gold Leaf, Solid Gold | three metals, two of them flat |
| **rosette coat** | Leopard, Snow Leopard, Bubblegum Leopard | one generator, three palettes |
| **cow blotch** | Dairy Cow, Strawberry Cow, Cookies and Cream | one generator, three palettes |
| **tiger stripe** | Bengal Tiger, Peppermint, Glacier | one generator, three palettes — four with Rainbow Tiger |
| **giraffe cell** | Giraffe, Honeycomb | one generator — borderline, and these two genuinely read differently |

**Proposed cuts: nine rows** — Magma Core, Ember Glow, Cyber Lime, Neon Mint,
Void Silk, Gold Leaf, Snow Leopard, Cookies and Cream, Glacier. That takes 46
to 37 and removes every pair under dE 14 without emptying a generator.

**Two notes on specific cuts.** `magma` is also a KEY COLLISION waiting to
happen: `assets/piggies/rare/magma/` holds a finished, alpha-passed legendary
coat that is not wired, while the key is occupied by a flat Neon rare. Cutting
the flat row frees the key for the thing that was actually built. And the
palette-swap clusters are the animal-crate plan's *"collect looks, not
species"* strategy working exactly as designed — variety per authoring hour is
the point of it — so cutting one from each cluster is a trim, not a reversal.

**Nothing here is a refund question.** The game has not launched and no piggy
has been earned, which is what makes this the free moment — the same argument
the retired lawn ornaments used.

### 5b. The porcelain problem, diagnosed

*"Currently they look like porcelain"* is diagnosable rather than a matter of
taste, and there are four contributing causes:

1. **Twenty of forty-six wear a hard shiny material** — 12 Neon, 5 Glass, 3
   Metal — and four carry `reflectance`. Glossy hard surfaces on a smooth ovoid
   is the definition of a ceramic ornament. (Counted across the whole
   catalogue, not just the flat rows: Snow Leopard is Glass and Solid Gold is
   Metal under their coats, which a census of the uncoated rows alone misses.)
2. **The body is a smooth ovoid with no silhouette interruption.** The only
   rows that break it are the four whole-model creatures and the `shards`
   pattern kind, which is authored and not yet in any row.
3. **The generated mesh is FACETED and a Part is analytically smooth**, which
   this repo already records as producing a shattered specular highlight —
   *"loudest on the Metal, Glass and Foil skins"*, which is exactly the set
   above.
4. **There is no face.** `PiggyModel` builds a snout, two nostrils and two
   fixed eyeballs. No brows, no lids, no mouth. **A character has an expression
   and an ornament does not**, and that is the single largest difference
   between what is on the plinth and what the brief is asking for.

### 5c. So the common tier becomes FACES, not more pastel balls

The brief names the commons as *Piggy, Muddy Piggy, Happy Piggy, Sad Piggy* —
moods, not colours. That is the right axis and it answers three things at once:

* it gives the bottom rung an identity that is not "another colour", which is
  what eight flat pastel bodies currently are;
* it is the direct fix for §5b(4), and therefore for the porcelain read, on the
  tier that has the most rows and gets looked at most;
* it is the cheapest authoring in the whole plan — a brow, a lid and a mouth
  are a handful of parts on a body that already exists, with no Blender pass,
  no upload and no moderation exposure.

The placement contract is already written: the eyeballs sit at x ±2.35 reaching
z 5.53, the head's surface at eye height is z 5.62, and `PiggyModel`'s pattern
code already computes per-eye angular exclusion zones — so it already knows
where an eye is to within a degree, in both the twelve-stud and the 2.2-stud
mini frames.

**The one rule to carry over: a face may never stand in an accessory anchor.**
`CLAUDE.md` records the Vault Lock's padlock being built at the hat anchor and
swallowing every hat in the game. The face anchor is the glasses slot; a brow
sitting in it is that bug with different geometry.

### 5d. "Smaller" needs one decision before anything is cut

*"Making the skins smaller"* has two readings and they cost wildly different
amounts:

* **A display scale change.** The pedestal mini is a 2.2-stud ball scaled by
  `PIGGY_PEDESTAL.display` (1.55) to about 3.4 studs, on a 3.4-wide plinth.
  This is one constant plus re-seating against `MINI_CENTRE_Y` — an afternoon,
  and it reaches the plinth's own proportions and the lawn slot audit.
* **A proportion restyle of the pig itself** — a rounder, chunkier, more
  cartoon body. This re-derives the landmark contract that twelve accessories,
  `DIAL_MAX_R`, the vault opening, the coin pile, the rob badge and every
  pattern band are all cut against, and it is an upload under the developer's
  own account. That is the exact class of work `docs/PIGGY-COLLECTION-PLAN.md`
  §15 sidesteps on purpose when it makes herd piggies skin-only.

**Recommendation: take the display scale now and hold the restyle.** Most of
the porcelain read is materials and the missing face (§5b), both of which are
cheap and neither of which touches the mesh. Re-measure after those land and
decide about the body then, against a picture rather than against a
description.

---

## 6. The packs

### 6a. Sizing to eighty

46 today, less 9 cuts is **37**. Target 80, so **about 43 new piggies**.

### 6b. The rarity distribution is derived, not chosen

A crate rolls a TIER at fixed odds and then picks inside it, so what decides
how hard a NAMED piggy is to get is `odds / count`. For the ladder to mean
anything that ratio has to fall at every rung — and the constraint that falls
out of `epic = 3 x legendary` is counter-intuitive enough to write down:

> **a named legendary is only rarer than a named epic while the legendary count
> is greater than the epic count divided by three.**

Against the solved 52 / 32 / 12 / 4 ladder, a distribution that holds it:

| tier | weight | count | per-name | notes |
| --- | ---: | ---: | ---: | --- |
| Common | 52 | 24 | 2.17 | widened by the character commons — see §9 |
| Rare | 31 | 30 | 1.03 | the widest rung, and the cheapest coat-and-anim work |
| Epic | 12 | 14 | 0.86 | zero stock today; §9d is what fills it |
| Legendary | 4 | 8 | 0.50 | six inherited plus two new |
| Mythic | 1 | 4 | 0.25 | the four whole-model creatures, already built |
| | | **80** | | |

Strictly decreasing at every step, and it lands on the target exactly.

**`epic = 3 x legendary` SURVIVES THE FIFTH RUNG** (12 against 4), which is the
relation `Config.CHESTS.animal`'s own comment records as what keeps
`Config.COMBINE` level against rolling directly. `COMBINE.need` is 5, derived
against THREE tiers, and five tiers re-opens that derivation whatever else
happens.

**This table has now moved twice, and both moves were driven by content
decisions rather than by tuning.** It was 18 / 34 / 18 / 8 when the rungs were
four and the commons were colours; §9's character commons made the bottom rung
the cheapest content in the plan, and Mythic arriving took the top rung from
over-target to on-target without a single re-tag. The shape to preserve is the
per-name column, not the counts.

**AND `weight` IS DELIBERATELY NOT CALLED `odds` ANY MORE.** See §10: crates
stop being the primary way a piggy is acquired, so this column is what a tier
is worth wherever a piggy comes from — a crate roll, a herd spawn, or what a
resident happens to be displaying. The arithmetic is identical and the noun had
stopped being true. **The legendary tier SHRINKS**, which is
§2's fourth finding acted on — and the whole-model creatures are the obvious
candidates to lift into the Mythic rung when it is added, which fixes the
order-of-magnitude cost mismatch between a code-built `fx` legendary and a
24-mesh Blender dragon sharing one rung, one income rate and one 4% roll.

### 6c. What a pack IS — and the packs are already latent in the two shelves

A pack wants to be a SHELF (a `collection`) with its own crates, because that
is what the crates screen already renders and what `chestPool` already filters
on. The cost is real and should be stated: **three chest rows and a
crates-screen section per pack**, and each pack must carry stock in every tier
its odds authorise or the crate reprices itself (§2).

**So a pack's minimum viable composition is about twelve**: 3 common, 5 rare,
3 epic, 1 legendary. Below that a tier is a coin flip rather than a pool.

**The interesting finding is that the current two shelves already contain four
coherent packs.** `og` is really Elements (Lava, Frostbite, Aurora,
Stormcaller, Supernova, Toxic) plus Metals and Gems (Bronze, Solid Gold, Pearl,
Diamond, Midnight, Prismatic); `animal` is really Farmyard (Ladybird, Cow,
Zebra, Bee, Giraffe, Leopard, Tiger plus the creatures) plus Sweet Shop
(Strawberry Cow, Watermelon, Peppermint, Honeycomb, Bubblegum Leopard, Candy
Swirl, Bubblegum). Re-shelving along those lines costs no new art and makes
every crate answer a question a nine-year-old actually asks — which is the rule
the Neon Nights retirement set, and which `og` has never satisfied.

**It also fixes §2's sequencing constraint for free.** A Farmyard shelf whose
commons are the new MOOD piggies (§5c) and whose rares are the coats is
correctly tiered from the day it ships, where re-tagging `animal` in place
empties its common tier.

*Open: re-shelve into four packs, or keep `og`/`animal` and hang new packs
beside them? The first is better browsing and better crates; the second is
fewer moving parts during a period when the economy is already being
re-derived.*

### 6d. The pack criterion

**A pack must answer *"what do I want my piggy to be"*, never *"do you want a
glowing one"*.** That is the rule the Neon Nights retirement set and the one
`og` has never satisfied, and it is the whole test a theme has to pass.

**The packs themselves live in §9d and §9e and are deliberately not listed
twice.** This section first carried its own four-row table and it went stale
inside a day — Mythic moved the creatures, the epic rung got stocked, Moods
folded into the OG family and Glitched was held back. A second description of
one thing is the copy that drifts, which this project records about the mini
piggy, `Decor.buildOne` and `RideSound`; two tables of packs in one document
is that failure with nothing to catch it.

**The one thing worth keeping from the version that stood here**: the mood
piggies are commons-only and go FIRST, because they are the cheapest content in
the plan, they are the fix for the porcelain read (§5b), and they restock the
common tier the re-tag is about to empty (§2). They are also the one group that
should never sit behind an opening of any kind — a mood piggy is what a new
player meets in their first minute, which is the collection plan's own rule that
a starter earns from the moment they arrive.

---

## 7. The checklist a pack passes before it ships

Every one of these is a failure this repo has already paid for once.

1. **Stock in every tier its crate authorises.** `auditRandomOutcomes` refuses
   odds for a tier with no stock; `liveOdds` silently renormalises what is
   left, which reprices the crate.
2. **A `cost` on every legendary**, or `Config.sellValue` pays the uncapped
   tier value on a duplicate.
3. **Tier derived from mechanism**, with any explicit `rarity` checked against
   it rather than trusted over it (§1).
4. **Nameplate colour measured against grass and sky**, not against a card.
5. **`epic = 3 x legendary` preserved**, and `COMBINE.need` re-run if the tier
   count moves.
6. **No two rows inside dE 14 of each other** on body-and-trim, and no two rows
   sharing a generator and a palette family (§5a's method).
7. **Re-run the income ceiling.** A pack's rarity mix moves what a maxed
   collection earns, which multiplies against the income tree and the rebirth
   bonus — the two-curves-multiplied failure this project records more than any
   other.

---

## 8. Open questions

1. **Epic's nameplate colour.** Blue is rare and gold is legendary. Purple is
   the genre convention and `Theme.PRESTIGE` is a plum that already exists and
   already clears ink — but it currently means REBIRTH, and this project's own
   palette rule is that a colour says one thing.
2. **Re-shelve into packs, or hang new packs beside `og`/`animal`?** (§6c) —
   and §10d lowers the stakes on this considerably, since a pack no longer has
   to be able to fill a crate.
3. ~~**"Smaller" — display scale now, body restyle later?**~~ **Resolved
   2026-09-21: display-only** (§9c). The restyle stays available and is a
   bounded piece of work, not a redesign.
4. ~~**Does Mythic arrive with the whole-model creatures lifted into it?**~~
   **Resolved 2026-09-21: yes, now** (§0). Five tiers today.
5. **The cut list itself** — nine rows proposed on measured evidence in §5a,
   and which of each cluster survives is a designer's call.
6. **Does a caught herd piggy still ALSO pay a crate, or does the piggy
   replace it?** (§10a) Replacing is cleaner; keeping both makes a herd the
   best event in the game by a distance, which may be the intent.
7. **What do resident lawns display?** Collection plan §9.4, still open, and
   §10e is the argument that it has been promoted from a pacing dial to THE
   supply question.
8. **Do crates survive at all, and at what share?** §10d narrows the rule to
   *every crate needs every tier it authorises* — which is a constraint on
   whatever crates remain, not an argument for keeping or cutting them.

---

## 9. The proposed catalogue

Started from the designer's own list on 2026-09-21: *muddy piggy, happy piggy,
sad piggy, fatty piggy, momma piggy, jr piggy (small pig with a spinny hat)*.
Six names, and between them they name two mechanisms that do not exist and one
decision that has to be made before any of them can stand on a till.

### 9a. `pattern` and `surface` are two mechanisms, and §1 lumped them

`PiggyModel`'s `pattern` kinds — `spots`, `stripes`, `shards` — build marks out
of PARTS, for the reason the whole world is built out of parts: *"an uploaded
texture is a third-party asset that can be moderated away and take the whole
catalogue's readability with it."* `surface` is a baked Blender sheet and two
uploads. Measured, only `bee` still declares a pattern and every shipped coat
is a `surface`.

**So the common/rare line is DOES IT NEED AN UPLOAD**, which is a better line
than "is it marked" because it tracks authoring cost exactly:

| rung | mechanism | upload? |
| --- | --- | --- |
| Common | colour, material, face, body, `pattern` parts | no |
| Rare | a baked `surface` coat, or an `anim` | yes, or free-but-animated |

That is what lets **Muddy Piggy be a common exactly as it was listed** — mud is
`pattern = spots` in brown, which is parts.

### 9b. Two new mechanisms

**`face` — expression parts.** `PiggyModel` builds a snout, two nostrils and
two fixed eyeballs, and nothing else. A brow, a lid, a mouth and a pupil offset
are a handful of parts on a body that already exists. The placement contract is
already written (eyeballs at x ±2.35 reaching z 5.53, surface at eye height
z 5.62) and the pattern code already computes per-eye angular exclusion zones,
so it already knows where an eye is to within a degree in both the twelve-stud
and the 2.2-stud frames.

**`prop` — character geometry.** Jr's propeller beanie, Momma's headscarf,
Grandpa's spectacles. Small, seated on the body, code-built, no upload.

**`prop` IS NOT `fx`, AND THE LINE IS WHOSE GEOMETRY IT IS.** `fx` is effect
geometry — crystal shards, a solar corona, a ring of prisms — which
`Shared/SkinFX` deliberately sites on the flanks or at radius 8–10, *"clear of
every accessory anchor and of the rob badge over the head."* A beanie is **what
the pig is**, not what surrounds it. Effect geometry is a legendary marker;
character geometry is not, and a rule that cannot tell them apart makes every
hat in this pack a legendary.

**A PROP IN AN ACCESSORY ANCHOR MUST YIELD TO THE PLAYER'S OWN ACCESSORY.**
`CLAUDE.md` is unambiguous: *"Nothing the game owns may stand in an accessory
anchor. The four anchors are the player's, permanently"* — and records the
Vault Lock's padlock being built a stud above the hat anchor and swallowing
every hat in the game. Jr's beanie sits exactly there. It hides when a hat is
equipped, the way `PlayerGear` already hides hair under a training hood, with
the original state stashed in an ATTRIBUTE on the part rather than a table
keyed on it. This only bites on the TILL, which is the one placement that wears
accessories at all.

**The spin rides `SkinFX.start`, not a fifth `anim` kind.** `anim` has exactly
four kinds and a fifth means editing `ClientMain` at its 200-local ceiling;
`SkinFX` already drives per-frame CFrames on an anchored set. It also means the
propeller correctly does NOT spin on the carried mini — a client that moved a
welded part would fight its weld, which is the rule that module already keeps.

### 9c. The one decision: body proportion and the till

*Fatty*, *Jr* and *Momma* vary the BODY, and there are five places a piggy
renders: the till (12 studs), a lawn pedestal (3.4), carried loot, a
ViewportFrame card, and an indoor plot. **Four of the five do not care. The
till cares about all of it**, because it is the one that carries the vault
dial, the hatch, the coin pile, the rob badge, twelve accessory anchors, the
steal prompt and the crack panel's camera — and most of those are PINNED
numbers rather than functions of the body (`DIAL_MAX_R` 1.95, the hat anchor at
14.15, the eyeballs at ±2.35). `SkinFX` is the exception and already scales by
`Size.X / 12`, which is the shape the rest would have to take.

Non-uniform is worse than uniform: the dial sits on a flank and the accessories
sit on cardinal points, so *wider* moves things *sideways* and a single scale
factor will not carry it.

| option | cost | what it costs the player |
| --- | --- | --- |
| **Display-only — DECIDED 2026-09-21** | one field, read by the pedestal, the mini, the card and the indoor plot; the till renders canonical proportions | your till does not show off a Jr's size — only its colours, face and marks |
| Uniform scale everywhere | make the dial, the anchors, the pile and the badge functions of `Size` | bounded but real; a band (say 0.85–1.15) keeps it sane |
| Bar varied bodies from the till | free | the shopfront cannot wear half the pack, which is worse than it sounds |

**Display-only it is.** The pedestal is where a collection is actually read, it
ships the pack immediately, and it touches nothing the economy or the robbery
is measured against. The cost is stated above rather than discovered, and the
lever if it ever matters is the middle row — which is a bounded piece of work,
not a redesign.

**IT IS A PROPERTY OF THE PLACEMENT, NOT OF THE SKIN, and writing it the other
way round is the trap.** `proportion` on the row is what the piggy IS; whether
a given surface honours it is a fact about the surface. So the pedestal, the
mini, the card and the indoor plot read the field and the till does not — one
branch, in the place that builds each, rather than a `tillSafe` flag on eighty
rows that somebody has to remember to set. Same argument as `setDecor` refusing
a fifth positional argument: the number of callers is what decides, and a
missing flag reads as nil, which here would silently be *"canonical"*.

### 9d. OG — "the piggy family"

**This finally gives `og` an identity.** §6c flags that `og` answers no
question a nine-year-old asks — it is a shelf split on palette, which is the
one axis the Neon Nights retirement already refused. *The piggy family* is a
real answer: these are the street's own pigs, which is what `og` always said it
was and never demonstrated.

**Commons — 10 new characters, each owning one expression.** Every common gets
a face; the existing COLOUR commons keep the neutral one, and **an expression
is used once**, so no two commons collide on the §5a dE rule.

| name | face | body | marks / prop |
| --- | --- | --- | --- |
| **Piggy** | neutral | — | — (this is Classic Pink, renamed to its type) |
| **Muddy Piggy** | cheerful | — | brown `spots`, darker trotters |
| **Happy Piggy** | wide smile, crescent eyes | — | — |
| **Sad Piggy** | downturned, droopy lids | — | one tear part |
| **Fatty Piggy** | contented, small eyes | wider | — |
| **Momma Piggy** | kind, lashes | larger | headscarf `prop` |
| **Jr Piggy** | big eyes, big head | smaller | propeller beanie `prop`, spinning |
| **Sleepy Piggy** | half-lidded | — | snore bubble `prop`, pulsing |
| **Angry Piggy** | V brows, flared nostrils | — | flushed cheek parts |
| **Cheeky Piggy** | wink, tongue out | — | — |
| **Grandpa Piggy** | bushy white brows | — | spectacles `prop` |

Reserve bench for when the rung widens or a colour common is cut: **Shy**
(blush, pupils looking away), **Grumpy**, **Surprised**, **Piglet** (smaller
than Jr, oversized ears).

**Rares — baked coats in the same family.** Five, to restock a tier the cut
list takes from eleven to five:

* **Spotty Piggy** — a real coat of darker-pink spots, the parts version's
  grown-up sibling
* **Freckled Piggy** — freckles across the snout and cheeks only
* **Piggy Bank Piggy** — glazed ceramic with a painted coin slot and a hairline
  crack. The pig as the object the game is named after, and the one row in the
  catalogue that is a joke about the game itself
* **Patched Piggy** — stitched fabric panels, a toy pig
* **Plush Piggy** — felt nap and visible seams

**Epics — a family member with an `aura`, and this rung is where the pack earns
its keep**, because epic currently has zero stock anywhere (§2):

* **Ghost Piggy** — translucent body, wisp aura
* **Bubble Piggy** — soap bubbles rising off it
* **Birthday Piggy** — confetti (`firstday` already carries a `party`/`confetti`
  pair to lift from)
* **Sugar Rush Piggy** — a fizz of sparkles

**Legendaries — none new.** `og` already holds four (Diamond, Supernova,
Stormcaller, Prismatic) against a target of six across the entire catalogue.
§2's fourth finding says this tier shrinks rather than grows, and a pack that
adds to it makes every existing legendary rarer by name.

### 9e. The other packs, sketched

**A pack is no longer required to carry every tier**, and §10 is why: that rule
came from each pack owning a crate whose odds it had to be able to fill. With
acquisition moving to herds and stealing, a pack is a THEME and nothing else,
so it can be three rows or twenty. Sweet Shop is three here; the OG family is
nineteen.

| pack | commons | rares (coats) | epics (aura) | legendary (fx) |
| --- | --- | --- | --- | --- |
| **Farmyard** (today's `animal`) | restocked from the OG family — see the interlock below | Cow, Zebra, Bee, Giraffe, Leopard, Tiger, Ladybird | **Firefly** | *(Storm Wolf, Dragon, Phoenix, Rainbow Tiger — now MYTHIC)* |
| **Sweet Shop** (latent in `animal`) | — | Strawberry Cow, Watermelon, Peppermint, Honeycomb, Bubblegum Leopard | **Candy Floss, Fizzy Pop, Gingerbread** | — |
| **Deep Sea** | **Sand, Tide** | **Clownfish, Koi, Pufferfish** | **Bioluminescent, Jellyfish** | **Kraken** |
| **Dino** | **Stone, Fossil** | **Stegosaur plates, Raptor stripes** | **Tar Pit, Amber** | **T-Rex** |
| **Arcade** | **Pixel** | **8-bit checker, Circuit** | **Power-Up, Hi-Score** | — (Glitched is held; see §9f) |

Bold is new. Unbolded rows already exist and only change tier.

**Farmyard's commons are the interlock from §2 and Stage 8.** Every one of its
eight commons today is a baked coat, which is a rare under the new ladder — so
re-tagging in place empties a tier its crate authorises at 52%, and `liveOdds`
reprices the crate rather than refusing it. The OG family is what restocks it,
which is the second reason that pack goes first. **Note this interlock survives
§10 in a weakened form**: it is a problem for as long as `Config.CHESTS.animal`
exists at all, whatever share of acquisition crates end up carrying.

### 9f. The count

Re-derived 2026-09-21 against five tiers. The KEPT row is the 37 survivors of
§5a's nine cuts, sorted by §1's derived rule rather than by what they are
tagged today:

| | common | rare | epic | legendary | mythic | total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| **kept** after §5a's nine cuts | 9 | 18 | 0 | 6 | 4 | **37** |
| OG family (§9d) | 10 | 5 | 4 | 0 | 0 | 19 |
| Deep Sea | 2 | 3 | 2 | 1 | 0 | 8 |
| Dino | 2 | 2 | 2 | 1 | 0 | 7 |
| Arcade | 1 | 2 | 2 | 0 | 0 | 5 |
| Sweet Shop (new rows only) | 0 | 0 | 3 | 0 | 0 | 3 |
| Farmyard (new rows only) | 0 | 0 | 1 | 0 | 0 | 1 |
| **new** | **15** | **12** | **14** | **2** | **0** | **43** |
| **total** | **24** | **30** | **14** | **8** | **4** | **80** |

**Eighty exactly, and on every rung of §6b's target.** That is not a coincidence
being reported as a result — it is what the Mythic decision bought. The
previous draft landed legendary at fourteen against a target of six and had to
propose re-tagging two rows down into epic to close the gap. Moving the four
whole-model creatures up takes the inherited legendaries from ten to six, which
leaves room for exactly the two new ones the packs wanted anyway. **One
decision closed a gap that was otherwise going to be closed by re-tagging
things that were correctly tagged.**

**Three sketched legendaries did not survive the arithmetic**, and which ones
go is the honest part. Kraken and T-Rex keep the rung because they are the
strongest silhouettes of the four; Gingerbread drops to epic, where a coat with
an aura belongs anyway; and **Glitched is held back deliberately** — it is the
seed of the Glitched tier (§0), and spending it as an ordinary legendary now
means the tier opens with nothing in it, which is the empty-rung failure §2
already records once.

Sweet Shop and Farmyard add no commons and no rares because they already have
theirs — Sweet Shop is five coats deep and Farmyard is seven. What both lacked
was an epic, which is the rung nothing in the game can stock today.

### 9g. Build order for the list

1. **`face` parts**, and the neutral expression on every existing common.
   Nothing else in this section works without it, and it is the porcelain fix.
2. **The OG family commons** — the ten above. No upload, no pipeline, no
   moderation exposure.
3. **`prop`**, plus the accessory-anchor yield. Three of the ten want it.
4. **The proportion field** (§9c), display-only.
5. **The OG epics** — because epic has zero stock and no crate can authorise
   the rung until something fills it.
6. **The OG rares**, which are the first baked coats this pack needs and
   therefore the first pipeline work in it.
7. Everything in §9e, in whatever order the art schedule prefers.

---

## 10. Acquisition moved, and it reaches further than the shop card

**Decided 2026-09-21: piggies are collected by STEALING them and by CATCHING
THEM OUT OF HERDS.** The remark that set it was about shop cards not mattering
much any more, and the reason given is the load-bearing half: *"collecting the
piggies will be via stealing and from the herds of pigs that come out."*

That is a smaller sentence than what it does. Five things follow.

### 10a. It changes what §15 of the collection plan pays out

`docs/PIGGY-COLLECTION-PLAN.md` §15 says a caught herd member *"banks a crate,
the same reward shape dailies and jobs already pay, not a guaranteed specific
piggy."* Under this decision it hands over **the piggy you just caught**.

**That is strictly better and it is the whole reason the mechanic earns its
new job.** A crate is an abstraction with a reveal bolted to it; a Cow Piggy
running down the street that you chase, corner and pick up is the acquisition
AND the reveal AND the story, with no UI in it at all. It is also the only
version where the thing you see is the thing you get, which is what makes a
rare spawn worth shouting about.

*Open: does the herd still ALSO pay a crate, or does the piggy replace it?
Replacing is cleaner. Keeping both makes a herd the best event in the game by
a distance, which may be the point.*

### 10b. Rarity stops being crate odds and becomes SPAWN WEIGHT

§6b's `weight` column is renamed for this reason and the arithmetic is
untouched: what decides how hard a NAMED piggy is to get is still
`weight / count`, and the monotonic rule — a named mythic must be rarer than a
named legendary, and so on down — still constrains the counts exactly as it
did. What changes is where the weight is read.

**And a spawn weight is VISIBLE in a way crate odds never were.** Everyone on
the street sees the same herd. A mythic running past is a shared event, first
player to reach it takes it, and nobody had to open anything to find out it
existed. This design has exactly one cooperative mechanic (`FRIEND_BONUS`, a
passive multiplier nobody performs) and the collection plan says so in as many
words; a contested rare spawn is not cooperation, but it is the first thing in
the game that a whole server experiences at the same moment and acts on
independently.

### 10c. The nameplate stops being a nicety and becomes the catalogue

§4 argued the nameplate on the grounds that a collection nobody can read from
the pavement is not a collection. This decision promotes it much further:
**if you never browse a shop, the nameplate is the only place you learn what
exists.** A lawn full of named piggies, a herd running past with names over it,
and the bag showing what you hold — that is the entire catalogue surface.

So §4's constraints get sharper rather than looser. The distance cap in
particular: a name you cannot read at the range you decide to chase from is a
name that is not doing its job, and the range a herd is decided on is further
out than the range a pedestal is read at. **That wants measuring against a
running pig, not against a plinth.**

### 10d. A pack stops needing stock in every tier

§6c derived a twelve-row minimum per pack — 3/5/3/1 — from the requirement that
a crate must be able to fill the odds it authorises. **That requirement came
from per-pack crates and it dissolves with them.** The acquisition pool is the
whole catalogue weighted by tier; a pack is a theme for browsing, for a
nameplate to belong to, and for an art schedule to be organised around. It can
be three rows.

§9f is already written that way: Sweet Shop is three and Farmyard is one.

**What does NOT dissolve is §2's interlock**, and it is worth being exact about
why. `Config.CHESTS.animal` still exists and still authorises `common = 52`.
For as long as any crate exists at all, a tier it authorises and cannot stock
is a silent repricing. The rule narrows from *every pack needs every tier* to
**every CRATE needs every tier it authorises** — which is what it always
actually said.

### 10e. Residents become the primary supply, and that is now the biggest dial

`docs/PIGGY-COLLECTION-PLAN.md` §9.4 is still open and it has just become the
most important open question in the content plan:

> **What do residents display?** Every resident lawn should carry piggies or a
> solo player can never build a collection. How rich their pedestals are is the
> single biggest dial on solo pacing.

Under crates that was a pacing question. Under stealing it is **the supply
question**, because on a quiet server the only lawns to steal from are
residents' — and the build-order's own live pass records the current state:
sixty pedestals standing across ten residential plots, and Stage 1's open item
5 says *"every resident lawn is six empty plinths right now, so a solo player
has nothing to snatch."*

**Two properties the resident distribution has to have**, both of which fall
out of rules already written:

* **It must be drawn against the same weights as everything else**, or a
  resident's lawn becomes a second economy that can drift from the real one —
  which is the argument `ResidentService` already makes for using
  `Config.getIncomeRate` and `getCapacity` directly rather than inventing
  parallel curves.
* **It must NOT scale with the thief.** The residents' own level offset is
  deliberately DOWNWARD-ONLY, because *"residents richer than the thief are a
  faucet, full stop."* The same reasoning applies one level up: a resident
  lawn that seeds mythics because the street is rich is a mythic faucet, and
  the audit that would catch it does not exist yet.

### 10f. What mints a piggy, and what removes one

Worth writing down before the numbers are solved, because this is the
two-curves-multiplied shape this repo records more than any other failure.

**Stealing MOVES a piggy and mints nothing.** It is circulation. **Herds MINT**
— every catch is a new row in somebody's collection, permanently, and there is
no sink anywhere in the design that removes one.

That is survivable and it should be understood rather than assumed. The bound
is not on how many you OWN, it is on how many EARN: the collection plan caps
placement at six lawn pedestals plus the till plus the indoor hallway, and
records the cost of that cap in as many words — *"a spare piggy now sits there
doing nothing, which is the thing this design said it would never hand
anybody."* So unbounded minting produces unbounded HOARDING and bounded income,
which is the right way round.

**The number nobody has multiplied yet is `LOSS_CAP`'s piggy clause against
theft-as-acquisition.** Collection plan §8 wants a cap on how many piggies a
victim may lose per rolling hour, for the same reason it caps coins. That cap
is also, from the other end, **a cap on how fast anybody can BUILD a collection
by stealing** — the one route this decision just made primary. `LOSS_CAP` x
`HEIST_PAYOUT` is the canonical version of this failure in `CLAUDE.md`: two
protections and incentives multiplied without anybody checking the product,
found months later by somebody happening to measure. This one is visible
before it ships and should be measured with the §8 re-derivation, not after it.
