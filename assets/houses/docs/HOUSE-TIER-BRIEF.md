# House tier brief for GPT — eighteen houses, all of them somewhere you could not actually live

Fable → GPT, September 16 — **revision 2** (designer feedback folded in:
no creatures on houses, an ice palace, underwater, portal, candy, galaxy,
thundercloud and fairy-lantern houses, exactly one all-black house as the
1B top, and the Golden Piggy moved out of the price ladder). This is the
step-1 brief for the whole house catalogue. It replaces the provisional names in
`HOUSE-CATALOGUE-PLAN.md`; the **prices, count and rarity bands there stand**,
the concepts do not.

**Designer direction:** the catalogue is not a street of real-estate. No
plain-Jane houses you could find in a suburb. Every tier is a *fictional*
place — a mushroom, a treehouse, a slime blob, a beached galleon, a giant
golden piggy bank — and the ladder should read as **climbing out of the
ordinary and into the impossible**: whimsical at the bottom, magical in the
middle, cosmic at the top.

What is fixed (Fable's side) · what is yours (GPT's side) · what you hand back.

---

## 1. Fixed: ids, prices, rarity, ownership

Eighteen houses. Ids are **stable strings** and never reorder; ownership is a
set of ids per player (`LATE-GAME-ECONOMY-PLAN.md` §7–8), so a house may be
bought in any order once its price fits the pig. The nine that exist keep
their ids, prices and rarity so nobody's save changes meaning. Rarity is
derived from price against the shared bands (Rare ≥100K, Epic ≥1M,
Legendary ≥10M) and is not a choice.

| # | id | price | rarity | status |
|---|---|---:|---|---|
| 0 | `shack` | free | Common | exists — Starter Shack |
| 1 | `cottage` | 35K | Common | exists — Cosy Cottage |
| 2 | `townhouse` | 120K | Rare | exists — Brick Townhouse |
| 3 | `mushroom` | 250K | Rare | **new** — Toadstool Cottage |
| 4 | `villa` | 400K | Rare | **re-theme** — Fairy Lantern Cottage *(was Suburban Villa)* |
| 5 | `treehouse` | 750K | Rare | **new** — The Treehouse |
| 6 | `manor` | 1.4M | Epic | exists — Stone Manor |
| 7 | `slime` | 2.5M | Epic | **new** — Gloop House |
| 8 | `modern` | 5M | Epic | **re-theme** — Fishbowl House *(was Midnight Modern)* |
| 9 | `candy` | 8M | Epic | **new** — Gingerbread Manor |
| 10 | `neontower` | 15M | Legendary | exists — Neon Tower |
| 11 | `crystal` | 25M | Legendary | **new** — Crystal Spire |
| 12 | `palace` | 40M | Legendary | **re-theme** — Ice Palace *(was Marble Palace)* |
| 13 | `skycastle` | 80M | Legendary | exists — Sky Castle |
| 14 | `galleon` | 150M | Legendary | **new** — The Beached Galleon |
| 15 | `portal` | 300M | Legendary | **new** — Portal House *(replaces the dragon)* |
| 16 | `thundercloud` | 600M | Legendary | **new** — Thundercloud Fortress *(replaces sky islands)* |
| 17 | `void` | 1B | Legendary | **new** — The Void *(the one black house)* |
| — | `goldenpig` | **not for sale** | Legendary | **new** — The Golden Piggy, earned by owning all seventeen priced houses |

Nine new models plus three re-themes are the job. **Re-themes keep the id,
the price and every owner** — a player who bought the Suburban Villa owns
the Fairy Lantern Cottage the day it lands. *Pending designer confirmation:*
the three re-themes and the Golden Piggy as an earned house; the ids above
are written so either answer costs nothing.

**The Golden Piggy is the trophy class, not a purchase.** No `cost`; an
`earned` tag; `Config.isEarnedElsewhere` covers it exactly as it covers the
lawn trophies, so it can never appear in a crate or be sold. Fable owns the
grant (the moment the seventeenth priced id lands in `houses.owned`).

---

## 2. The nine new houses

Each entry: the fantasy, the silhouette (the one thing that has to read from
the road at seventy studs), what moves (tagged `HouseFX`), the trophy-room
family it opens into, and the trap to avoid. **Nothing that moves on a house
is a creature** (§3) — only light, weather and machinery.

### 3 · `mushroom` — Toadstool Cottage · 250K · Rare
A house that *is* a giant toadstool: a fat spotted cap for a roof, a round
door in the stalk, a tiny round window, a smaller mushroom as a chimney and
two or three baby mushrooms round the base. **Silhouette:** one dome on a
stalk — nothing else on the street is round. **Palette:** cap in a deep
saturated red or purple with pale spots, cream stalk, dark door. **FX:**
none. **Room:** cozy. **Trap:** spots that are flat discs coplanar with the
cap flicker — every spot stands proud.

### 4 · `villa` — Fairy Lantern Cottage · 400K · Rare · *re-theme*
A crooked little cottage under a bowed string of glowing paper lanterns,
toadstool-cap window hoods, a round green door, ivy up one wall.
**Silhouette:** a low leaning cottage with a sagging line of lights across
the front — the first glow on the ladder. **Palette:** warm cream walls,
moss-green trim, lanterns in two or three DEEP warm hues (amber, rose,
violet — never pale). **FX:** the lanterns `pulse` gently, phased apart so
they never read as one flash. **Room:** cozy. **Trap:** a bright pale lantern
is a white hole on Neon; saturation survives the bloom, value does not.

### 5 · `treehouse` — The Treehouse · 750K · Rare
A cabin built up in the boughs of one big oak: a trunk, a platform deck, a
rope-and-plank bridge to a second smaller platform, a rope ladder down, a
bucket on a pulley. **Silhouette:** a box floating in a canopy, the first
house on the ladder with real HEIGHT. **Palette:** warm timber, a leaf canopy
in the game's own tree green. **FX:** none. **Room:** cozy (timber shelves).
**Trap:** the canopy may not overhang the fence line or the lawn slots
(§3); the tree is a trunk with a canopy *above* the yard, not a grove.

### 7 · `slime` — Gloop House · 2.5M · Epic
A house being eaten by slime, cheerfully. Wobbly walls that bulge, a roof of
green goo dripping over the eaves in fat drops, a slime-blob chimney, windows
with gloop half-drawn across them, a puddle of slime for a doormat.
**Silhouette:** rounded and sagging everywhere the others are square.
**Palette:** the candy-garden slime green, a darker green in the drips, one
accent (the door) in a colour that is not green. **FX:** two or three drips
that *pulse* slowly (the `pulse` kind). **Room:** modern fallback, or a new
"gloop" family if you want it — propose one, with the modern room as the
tested fallback. **Trap:** slime is a genre, not a property — no eyes, no
face, nothing that reads as a specific game's mascot.

### 8 · `modern` — Fishbowl House · 5M · Epic · *re-theme*
A pod house sitting inside a giant glass dome full of water: coral and
seaweed round the base, a sand floor, a porthole door, bubbles rising.
**Silhouette:** a dome — the only one on the ladder. **Palette:** deep
teal water tint, coral in two warm accents, a pale pod. **FX:** two small
fish shapes `orbit` the pod slowly (a fish is scenery here, the size of a
window, never an actor — see §3), bubbles `bob`. **Room:** an "aquarium"
variant of modern, with modern as the tested fallback. **Trap:** the dome is
glass over a building — author it as a transparent shell that does not
z-fight the pod, and keep the water tint deep or the pod vanishes.

### 9 · `candy` — Gingerbread Manor · 8M · Epic
A gingerbread house grown to two storeys: biscuit walls with piped icing at
every edge, a roof of overlapping sweets, candy-cane posts on the porch,
gumdrop path lights, a lollipop weathervane. **Silhouette:** a manor with
scalloped icing on every line. **Palette:** biscuit brown, white icing, and
the candy garden's own gummy colours for the sweets. **FX:** none, or a
gentle `pulse` on a couple of the sweets. **Room:** cozy. **Trap:** this
sits beside the candy-garden ornaments; use their vocabulary so a
gingerbread house and a gummy bear on the lawn read as one set.

### 11 · `crystal` — Crystal Spire · 25M · Legendary
A geode turned into a house: a dark rock base cracked open to show a
cluster of huge glowing crystal shards, the largest as the tower, a doorway
cut into the base, smaller crystals sprouting from the roofline.
**Silhouette:** a jagged spire — tall, sharp, the opposite of the round
mushroom and the sagging slime. **Palette:** near-black rock, crystals in
ONE saturated hue (deep violet or teal) — a pale crystal on Neon is a white
hole. **FX:** the crystals glow (`pulse`), two or three of them phased apart
so they never read as one flash. **Room:** modern (cases, dark trim, one
accent light). **Trap:** the neon rule — saturation survives the bloom,
value does not; author the glow colour a long way from white.

### 12 · `palace` — Ice Palace · 40M · Legendary · *re-theme*
A palace carved out of ice: translucent blue-white walls, icicle eaves,
frosted turrets, a frozen fountain in front. **Silhouette:** the palace's
existing width and columns, with icicles on every line. **Palette:** ice
blue and white — so the GLOW has to be a deep saturated blue, far from white
(the palace's first lit colonnade was a white blowout for exactly this
reason). **FX:** icicles `pulse` in a slow chase. **Room:** royal, with an
"ice" variant. **Trap:** pale walls plus pale glow is one white sheet —
`fxGlow` must differ from the wall colour.

### 14 · `galleon` — The Beached Galleon · 150M · Legendary
A pirate ship run aground on the lawn and moved into: hull as the house,
gangplank as the front path, a mast with a crow's nest, a stern cabin with
lattice windows, a wheel on the poop deck, a rope ladder. **Silhouette:** a
mast — the tallest thing yet, and unmistakable. **Palette:** dark timber, a
red-and-cream striped sail (furled or half-furled), brass trim. **FX:** a
lantern at the masthead that `pulse`s. **Room:** classic (timber cabin,
cabinets). **Trap:** no flag with a skull on it, no cannons, no cutlasses —
the maturity questionnaire is answered by what is literally in the model,
and it is a home, not a warship.

### 15 · `portal` — Portal House · 300M · Legendary
A house split down the middle by a huge standing ring: the front half an
ordinary stone house, the back half stepping *through* the ring into another
world — inverted palette, floating steps, a tilted roof. **Silhouette:** a
ring — nothing else on the street is one. **Palette:** stone and slate on
the near side; on the far side the same shapes in a deep violet/teal
scheme. **FX:** the ring's rim `cycle`s colour; three floating steps `bob`.
**Room:** modern, with a "portal" variant. **Trap:** the ring must read as a
FRAME with the house seen through it, so the inside of the ring is empty
air, not a disc.

### 16 · `thundercloud` — Thundercloud Fortress · 600M · Legendary
Dark towers rising out of a heavy storm cloud that hides the ground: a
bulbous cloud base, three spires with pennant-less tops, rain streaks
beneath the cloud. **Silhouette:** a dark rounded mass with spires — taller
and heavier than anything below it. **Palette:** **storm grey-blue, NOT
black** (exactly one black house, §3), pale-violet lightning. **FX:** rain
streaks `cycle`; lightning is a `beacon` sweep across the cloud — never a
strobe (three flashes a second is the ceiling). **Room:** royal, with a
"storm" variant. **Trap:** a flicker that reads as a flash is an
accessibility failure; lightning moves, it does not blink.

### 17 · `void` — The Void · 1B · Legendary · *the one black house*
An all-black manor with every edge traced in a single deep neon hue
(violet), a front door that is a swirling portal ring, and windows that show
starfield instead of rooms; a tilted ring encircles the whole building and
two planets and a comet `orbit` it at different radii and speeds. The
galaxy the ladder was climbing toward is *inside* this house.
**Silhouette:** the only shape on the street DARKER than everything around
it, drawn by its own glowing outline, with things circling it — visible from
the tunnel. Tallest on the street (~60). **Palette:** near-black
(~(17,17,19) — charcoal catches the sky and reads grey; the tunnel liner
learned this), one neon trace hue, deep nebula accents in the windows.
**FX:** edge trace `pulse` (slow, phased by side), orbit ring, planets and
comet `orbit`, window stars `cycle`. **Room:** a "void" variant of modern
(starfield walls), modern as fallback. **Traps:** (1) black has no corners
in flat colour — the neon trace IS the hard line at every edge; (2) the shop
card's icon well is near-black too, so this card needs a lighter well or the
trace has to carry it (the "drawn and invisible against its neighbour"
failure); (3) it must out-scale the Sky Castle's orbiting shards — rings and
a disc, not just more orbits — or the two read as siblings.

### — · `goldenpig` — The Golden Piggy · not for sale · earned
The game's own title at house scale: a colossal gold piggy bank you live
inside — coin slot skylight, belly door, snout bay window, ear balconies,
tail chimney, coin-slab path. Granted when a player owns all seventeen
priced houses; it is the completion trophy, not a purchase. **Silhouette:**
a pig. **Palette:** `GOLD`/`GOLD_DEEP` flat (gold on `Metal` shades olive),
pink snout, ink lines. **FX:** slow flank shimmer; one coin `bob`s over the
slot. **Room:** royal, gold-trimmed. **Trap:** the piggy-BANK proportions
(the mesh pig's), never a realistic pig.

**The ladder reads:** toadstool → lantern cottage → treehouse → slime →
fishbowl → gingerbread → crystal → ice palace → galleon → portal →
thundercloud → the void, with the golden pig standing beside it for anyone
who finished. Round, leaning-and-lit, tall, sagging, domed, scalloped,
jagged, icicled, masted, ringed, storm-heavy, black. It climbs from
whimsical through magical to cosmic, and the top is the one shape darker
than the street.

---

## 3. Constraints every house has to meet (Fable's side; measured)

* **Front-pinned.** A house is seated by its **front wall** at
  `Config.HOUSE_FRONT_LINE` (28 studs behind the piggy). Depth varies freely.
* **Fits the yard, measured by parts.** Structure width **≤ 60** (fence
  interior 67.2; the widest today is 49.0), depth **≤ ~57**. Measure by
  walking the BaseParts through their own CFrames, never `GetBoundingBox` —
  animated FX parts sit at altitude and lie. Nothing may reach a lawn slot,
  the kennel corner or the fence line — that includes canopies, islands,
  sails and drips.
* **Height sells.** The road is seventy studs away; the top tiers read by
  going UP and clearing the grove behind the plots. Rough ladder: mushroom
  ~14, lantern cottage ~16, treehouse ~30, slime ~18, fishbowl ~22,
  candy ~24, crystal ~45, ice palace (the palace's), galleon ~50, portal ~40,
  thundercloud ~55, void ~60, goldenpig ~40 but *wide*. Sketch the nine side by side
  at one scale before modelling any.
* **Low-poly, flat colour.** `SmoothPlastic` only — no `Brick`, `Slate`,
  `WoodPlanks`, `Metal`, `Grass`, no textures. Plinth where it meets the
  ground, framed openings, courses on a roof, hard lines at corners. Zero
  coplanar pairs: anything standing on something sinks ~0.1 into it.
* **Parts budget ~200 per house** (manor 212, palace 186 are the ceiling).
  Tufts are 47% of the world; a house is not where the budget goes.
* **FX are tagged neon parts, never lights or particles**, so they render in
  the shop card's viewport. Kinds: `pulse`, `cycle`, `bob`, `chase`,
  `beacon`, `orbit`. No more than 0.9 cycles/second on anything; phase
  multiple emitters apart. Deep saturated hues only.
* **Originals.** No named character, brand, franchise or wordmark; a genre
  not a property. No weapons, no gore, no fire aimed at anyone.
* **A house never contains a creature.** Everything that moves on a plot
  today is an ACTOR — a dog, a resident, a player — and a thief reads
  posture off them from the pavement. A dragon asleep on a roof looks like a
  mechanic. What moves on a house is light, weather or machinery; a fish in
  the Fishbowl is a window-sized ornament orbiting a pod, never something
  that stands on the lawn.
* **Exactly one black house: `void`.** Black works as a contrast against a
  ladder that got steadily brighter, and stops working the moment there are
  two. The Thundercloud is storm grey-blue; the Midnight Modern's black
  retires with its re-theme.
* **One drive spec per house** — `Config.HOUSE_TIERS[].drive` is the visible
  half of the tier from the road (dirt, gravel, brick, slate, lit asphalt
  today): the mushroom wants a mossy path, the candy house gumdrops, the
  galleon planks, the ice palace frosted slabs, the void a black path with a
  neon edge, the golden pig coins.
* **A one-line blurb** in the voice of the existing ones (*"Four walls and a
  leaky roof. Everyone starts here"*).

---

## 4. Optional: re-theming the nine existing houses (later, never blocking)

Same id, same price, same rarity, same ownership — only the model changes,
which is what stable ids buy. Direction per house if and when it is wanted,
in the same escalating fantasy register:

| id | today | fantasy direction |
|---|---|---|
| `shack` | Starter Shack | a cardboard-box fort, tape and a crayon door — still the free one, still humble |
| `cottage` | Cosy Cottage | a beehive cottage: hexagon windows, a honey-drip roof |
| `townhouse` | Brick Townhouse | a wonky stacked tower — three crooked storeys leaning different ways |
| `villa` | Suburban Villa | **committed above: Fairy Lantern Cottage** |
| `manor` | Stone Manor | a haunted manor: crooked chimneys, a friendly ghost `bob`bing in the attic window |
| `modern` | Midnight Modern | **committed above: Fishbowl House** (retires the second black building) |
| `neontower` | Neon Tower | keep — already fantasy |
| `palace` | Marble Palace | **committed above: Ice Palace** |
| `skycastle` | Sky Castle | keep — already fantasy |

Do the nine new first. If any of these is picked up, it lands one at a time
through `Config.HOUSE_REBUILD` exactly as the low-poly rebuild did, so a
re-theme can be looked at beside the original and backed out by one word.

---

## 5. Trophy rooms: what each house opens into

September 17 update: every house has a physical walk-in interior within its
exterior, following `HOUSE-TROPHY-ROOMS.md` and brief B2. Cozy, classic,
modern and royal families describe furniture/material treatments, with
variants such as gloop, hoard, sky and gold; they are not separate rooms.
Every home has an achievement cabinet, records book and Legacy plaque,
with `Featured`, `Shelf_1..Shelf_N`, `Wall`, `Record`, `Plaque_Legacy` and
`Door_Exit` mounts. Larger homes show more items at once; all homes retain
full achievement menu access. Proposed capacities, interaction markers and
the GPT/Fable work split are recorded in `HOUSE-TROPHY-ROOMS.md`.

---

## 6. What to hand back (per house)

1. Concept sheet: front and three-quarter, and the nine side by side on one
   scale.
2. On approval: the asset — a `House.luau` builder in the `LowPoly`
   vocabulary, or a mesh with a `Config.HOUSE_MESH` row (segmented if it
   needs more than one colour). State which.
3. The handoff row: `id`, `name`, `cost`, `width / depth / storeys`,
   wall/roof/trim tokens, `drive` spec, `blurb`, the FX parts list with kind
   and phase, the room family (and fallback), and the measured part count
   and footprint.
4. Note anything that is still a mockup rather than a usable model.

Fable then: adds the row, runs `auditEconomy` (every price has to fit the
largest pig — the four above 96.9M wait for the ladder change in
`LATE-GAME-ECONOMY-PLAN.md`), seats it front-pinned, sweeps coplanar pairs
and footprint, wires the drive, and renders it on the catalogue card.

**Order that fits the economy work:** `mushroom`, `villa`, `treehouse`,
`slime`, `modern`, `candy`, `crystal`, `palace` fit today's pig and can land
any time; `galleon`, `portal`, `thundercloud`, `void` land after the ladder
extends (4b.1 is implemented, so that is now). `goldenpig` lands with house
ids (4b.2), since its grant reads the owned set.

---

## 7. What a house does besides look (`MASTER-PLAN.md` §19.4a)

A house **gates and holds; it never generates.** It never adds a tree and
never adds acorns per hour. What it decides, by the rarity of the best house
a player OWNS: which tree levels they may buy (Common 0–1, Rare 2, Epic 3,
Legendary 4) and how many ripe acorns the tree holds (8 / 12 / 16 / 24).
For GPT this means one visual ask: the oak's five levels (brief B5) should
look like they belong to the house tier that unlocks them — and a bigger
trophy room at higher tiers is display, never achievement capacity.
