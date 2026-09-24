# Lasso plan: catching wild piggies

Working document, 2026-09-23. It replaces the free "Catch Piggy" hold with a
lasso that costs coins, locks on by itself, and lands a catch on a chance
that tapping and later throws improve. As each phase lands, its reasoning
moves into CLAUDE.md and its description into GAME.md, and this file shrinks.

## Decided (designer, 2026-09-23)

- A catch is a lasso throw with a percentage chance. It is not a hold and it
  is not a flat coin price.
- **A lasso is spent on every throw, caught or not.** A miss visibly snaps it.
- **After a miss, the piggy breaks away, runs a short way, and stops again.**
  The run is short and slower than a child, so the chase stays easy.
- **Aiming is automatic.** Point at a piggy and the held lasso highlights it
  and locks on. No aim skill is involved.
- **Tapping fast during the struggle helps, but it cannot beat the lasso
  tier.** A basic lasso on a legendary must not land first time however fast
  somebody taps.
- **A miss raises only the thrower's odds**, and only on that piggy.
- **Each lasso's chances appear in its item description**, not over the
  piggy.
- **Lassos are bought with coins, and better ones unlock with rebirths.**
  Elite tiers cost Robux and have a much higher success rate.
- **Only one rope can be on a piggy at a time.** Several players may compete
  for one piggy, and the first successful roll wins it.
- **A caught piggy is carried home**, not sent to the lawn. It uses the same
  carry as a snatched piggy.
- **A real hit knocks a carried catch loose.** The catcher has a short window
  to pick it back up; after that, anyone can lasso it with any lasso. See
  section 3.

## Needs a decision

1. **Wild piggies are capped at rare today.** `Config.HERDS.tierCap` is
   `"rare"`, so no epic or legendary ever lands to be lassoed. The cap exists
   because a free catch creates a piggy from nothing. Now that a catch costs
   lassos, the lasso price is the brake, so the cap can move. Proposal: raise
   it to legendary, spawn epics and legendaries rarely (roughly 8% and 2% of
   drops), and give a legendary landing its own banner ("A LEGENDARY PIGGY
   LANDED!"). This changes how much an idle lawn earns, so
   `auditRobbery` and `auditHerds` have to be re-read after it lands.
2. **Prices and rebirth gates.** The figures below are placeholders.
3. **Starter stock.** The proposal is 5 Rope Lassos in a new save, plus a
   lasso rung on the daily ladder. A new player with no lassos and no coins
   cannot catch anything.
4. **Elite lasso Robux price and pack sizes.**

Settled: when somebody misses, another player may lasso the running piggy at
their own odds. Only the struggle itself is exclusive.

## 1. How a catch plays

1. **Hold a lasso.** It is drawn from the hot bar like any consumable, and
   the character twirls it overhead.
2. **Lock on.** The client picks the landed piggy nearest the centre of the
   screen, in front of the player and within `range` (about 30 studs), and
   puts a Highlight on it in the lasso's tier colour. Turning the camera
   moves the lock. Nothing is aimed.
3. **Throw.** A click or tap sends the locked piggy's id. The server checks
   it again: the lasso is in hand, the piggy is on the ground and within
   range plus slack, nobody else has it in a struggle, it has not been taken,
   the thrower is not already carrying something, and there is a free plinth
   on their lawn or in their hallway. **Any refusal happens before the
   lasso is spent**, and it is said out loud.
4. **Struggle, about 2.5 seconds.** A rope (a Beam from hand to piggy) goes
   taut, the piggy wriggles, and a big TAP! button fills a bar. Space, a
   click and a screen tap all count. Nobody else can throw at this piggy
   during the struggle.
5. **Result.** The server rolls. If the catch holds, the piggy is yanked into
   the thrower's arms and the carry home begins (section 3). If it misses,
   the rope snaps into two falling pieces, the character stumbles, and the
   piggy bolts.
6. **The run.** The piggy runs directly away from the thrower for about 2.5
   seconds at 0.6 of walking speed (14.4 against a child's 24), kept inside
   the herd band, then stops and grazes on the spot for about 10 seconds
   before it roams again. The thrower's odds on it are now higher.

## 2. The odds

```
chance = min(1, base[tier][rarity] * tapFactor + pity)
```

- **`base`** is the lasso tier against the piggy's rarity.
- **`tapFactor` runs from 1.0 to 1.2** and follows the tap rate during the
  struggle. The server counts taps and caps them at 8 a second, so an
  autoclicker earns exactly what a fast child earns (the same reasoning as
  the crack). Tapping **multiplies**, so it moves an easy catch a lot and a
  hard one hardly at all. That is the balance rule: a Rope on a legendary
  goes from 4% to 4.8%, never to a sure thing.
- **`pity`** adds `pityStep[rarity]` for each miss by this thrower on this
  piggy, and throw number `guaranteeBy[rarity]` always lands. The ladder
  counts misses with any tier, lives on the (thrower, piggy) pair, and ends
  when the piggy is caught or leaves.

First-throw chance with no taps / fast taps (placeholders):

| Lasso | Gate | Common | Rare | Epic | Legendary |
|---|---|---|---|---|---|
| Rope | none | 80 / 96 | 35 / 42 | 12 / 14 | 4 / 5 |
| Braided | rebirth 2 | 90 / 100 | 50 / 60 | 20 / 24 | 8 / 10 |
| Golden | rebirth 5 | 100 | 70 / 84 | 35 / 42 | 15 / 18 |
| Elite (Robux) | none | 100 | 90 / 100 | 60 / 72 | 35 / 42 |

| | Common | Rare | Epic | Legendary |
|---|---|---|---|---|
| `pityStep` per miss | +30 | +20 | +12 | +8 |
| Guaranteed by throw | 2 | 4 | 6 | 10 |

With a Rope, catching a legendary takes about five throws on average and
never more than ten. With an Elite lasso it takes one or two.

**The description is generated from these tables and never typed by hand.**
The shop card, the hot bar hint and the Robux prompt text are all built from
`Config.LASSOS`, so the odds shown cannot disagree with the odds the server
rolls. For example: *"Rope Lasso. First throw: Common 80-96%, Rare 35-42%,
Epic 12-14%, Legendary 4-5%. Fast tapping moves you to the top. Every miss
raises your odds on that piggy, and it is guaranteed by throw 2 / 4 / 6 /
10."*

## 3. Contesting a piggy, carrying it home, and dropping it

### One rope at a time

A struggle is exclusive. While one player's rope is on a piggy, a throw at it
from anybody else is refused before a lasso is spent ("Somebody already has a
rope on that one."). When the struggle ends in a miss, the piggy runs and
anybody may throw at it, each at their own odds. The first roll that lands
wins.

### Carrying it home

A caught wild piggy uses the carry that already exists for a snatched piggy
(`PiggyHaulService`): the two-armed hug, the slower walk, no riding, and the
five-second countdown once the carrier stands on their own lawn or in their
own hallway. The piggy is theirs when the countdown finishes, and not before.

What is new is a third kind of haul, `wild`. A snatched piggy that is nabbed
goes back to the pedestal it came from, but a wild piggy has no pedestal, so
a nabbed wild piggy **drops on the ground** instead.

### What knocks it loose

Only a real hit does, never a bump:

- somebody completing the **nab** hold on the carrier (the prompt a carried
  piggy already has);
- a **gadget hit** that stuns (the zapper);
- a **guard dog** catch, if the carrier cuts across somebody's lawn.

A dodge still beats one nab or one lunge, as it does for every carry. The
existing rest after a gadget hit still limits how often one player can be
hit.

### The dropped piggy

1. **It lands dazed** where the carrier was, with stars circling its head.
2. **For 5 seconds only the catcher may pick it up.** A short hold, no lasso
   needed. Nobody else can throw at it or hold it during this window. This is
   the catcher's guaranteed chance to recover it.
3. **After 5 seconds it is open.** Anybody may lasso it with any lasso at
   their normal odds, one rope at a time. The catcher can still pick it up by
   hand with the short hold, so it becomes a race.
4. **After about 30 seconds untouched it wakes up** and becomes an ordinary
   wild piggy again.

### Protection for the carrier

- **After a pick-up, nothing can knock the piggy loose for about 8
  seconds.** A carrier cannot be knocked down every few steps, and one
  recovery is a real chance to get away.
- **The worst a child can lose is the lassos they spent plus that piggy.**
  Nothing they already owned is at risk.

### Taking somebody else's catch is a robbery

A player who lassos a dropped piggy that somebody else caught earns a wanted
star, and the catcher gets a revenge marker on them, like every other theft
in the game. The catcher picking their own piggy back up is not a theft.

### Why stealing is not limited to the Elite lasso

The first proposal was that only an Elite lasso could take a dropped piggy.
That was refused for three reasons:

- It makes stealing pay-to-win: a child who never spends Robux could never
  contest a piggy, and one who has could grief everybody who has not.
- Players restricted from paid random items (UK under-18, Australia,
  Belgium) cannot buy an Elite lasso at all, so they could neither steal nor
  win their own catch back from an Elite thief.
- It turns a Robux luck item into a tool for taking another child's catch.

The Elite lasso still stands out, because its odds are better at everything,
dropped piggies included.

## 4. The Elite lasso is a paid random item, and that is fine if it is gated

A Robux purchase that buys a **chance** at an outcome falls under Roblox's
paid random item rules, the same as the Robux crates. Crates already carry
the three things this needs, so the lasso reuses them:

- **Odds shown before purchase.** The generated description above does this,
  and it has to be on the Robux product card, not just in the bag.
- **The `PolicyService` gate.** `ArePaidRandomItemsRestricted` fails closed
  in `ProductService`. A restricted player (UK under-18, Australia, Belgium)
  sees the Elite card refuse with a readable line. Their coin lassos work as
  normal.
- **A receipt ledger** so a redelivered receipt does not grant twice.

Two rules follow from this game's existing Robux line:

- **An Elite lasso is never sellable for coins,** and nothing converts it
  into coins. A Robux purchase may grant an item, never its coin value.
- **Coins are never sold.** That is what keeps the coin lassos outside the
  rule altogether.

`auditRandomOutcomes` gains a lasso clause: every Robux-priced lasso carries
a `productId` and a complete odds table, and no coin lasso carries a Robux
price.

## 5. Build

### Files

| File | What it does |
|---|---|
| `Config.luau` | `LASSOS` catalogue (name, gate, price, base odds, colour), `LASSO` table (range, struggle seconds, tap cap, tap factor, pity, guarantee, flee), `lassoChance()`, `lassoDescription()`, an audit |
| `LassoService.luau` (new, server) | the throw remote, validation, struggle state, tap counting, the roll, pity, spending the lasso, refusals |
| `HerdService.luau` | remove `CatchPrompt`; add the one-rope `struggling` lock, the `flee` state, and the `dazed` dropped state with its catcher window and wake-up timer |
| `PiggyHaulService.luau` | a third haul kind, `wild`: the same hug carry and secure countdown, but a nab or a stun drops the piggy as `dazed` instead of sending it home; the 8-second knock immunity after a pick-up |
| `SocialService` | lassoing somebody else's dropped catch counts as a theft: a wanted star and a revenge marker |
| `HeldItemService` / `HeldItem` | a grip entry for the lasso coil |
| `HotBar.luau` | one Lasso tile with a tier picker fanned sideways like the garage slot. The number row is full, so it takes a letter (probably L, checked against the key map at build time) |
| `Shared/LassoUI.luau` (new, client) | lock-on Highlight, throw, rope Beam, the TAP bar, outcome effects. A module, because `ClientMain` is at its 200-local limit |
| `ProductService.luau` | the Elite product, gated like crates |
| Shop | coin lassos at the gadgets counter; Elite in the Robux shop |
| `DataService` | starter lassos in `consumables` (no schema bump) |
| `AdminService` | give lassos; force a piggy of a chosen rarity to land nearby |

### Phases

1. **Rules, offline and testable.** Config, LassoService, the HerdService
   changes, admin commands, and `tests/luau/lasso.luau`. The suite asserts:
   - every chance matches the table;
   - fast tapping never gets a Rope over 5% on a legendary;
   - the guarantee lands on the stated throw;
   - a refused throw spends nothing;
   - pity belongs to the thrower alone and dies with the piggy;
   - the struggle is exclusive;
   - a nab or a stun drops a wild carry as `dazed`, and nothing else does;
   - only the catcher can touch a dazed piggy for its first 5 seconds;
   - no second knock lands within 8 seconds of a pick-up;
   - an untouched dazed piggy rejoins the wild after about 30 seconds;
   - a lasso on somebody else's dropped catch awards a star and a revenge
     marker, and the catcher's own pick-up does not.
2. **Feel.** Lock-on, the throw, the rope, the TAP bar, snap and flee. It
   uses placeholder animations built in code, so it does not wait on art.
3. **Shop.** Coin lassos with rebirth gates, generated descriptions, starter
   stock, and the Elite product with its gate.
4. **Art and numbers.** Swap in the Blender assets, decide the tier cap,
   re-read the audits, then run the `game-doc` agent and add the CLAUDE.md
   entry.

The shared files are Config, HerdService, ProductService and the shop views.
Before editing any of them, announce a claim to the other sessions and wait
for the answer.

## 6. Art

### Models

1. **Lasso coil**, held in the right hand, shared by Rope, Braided, Golden,
   and Elite. One assembled model with rope and handle wrap as separate
   meshes. The shop card renders this model, so no separate icon is needed.
2. **Tier textures** (designer update, 2026-09-23): all four tiers use the
   same coil geometry with different base-color maps. Elite is purple with
   a gold grip and a blue emblem; it no longer needs a separate ornate mesh.
3. **Loop**, the open capture ring that closes around the piggy's torso.
   Code scales it to each piggy's girth and recolours it for the lasso tier.
4. **Snapped rope end**, one short frayed piece. Code uses it twice when a
   throw misses.
5. **Daze star** (optional), one reusable cartoon star. Code instances and
   orbits it above a dropped piggy's head; the orbit is not a physical ring.
   Code can build the stars from parts if the mesh is skipped.

Every model: flat-shaded, under 10k triangles for the complete prop, with
+Y up in the Roblox export. The latest designer request adds tier textures:
simple base-color atlases, with no baked lighting or realistic fibre detail.
The rope between hand and piggy is a Beam built in code, so it needs no mesh.

Recommended production contract for the briefs below:

- Export only the named meshes, with one material per mesh. Both coil parts
  use the same tier atlas. No baked lighting, floating decorative fibres, or
  visible helpers. Use white MeshPart Color with textures to avoid tinting.
  Keep flat face shading, closed geometry, and rounded low-poly silhouettes.
- Coil parts share one origin at the assembled bounds centre. Record a
  `HandGrip` transform at the band and a `RopeExit` point at the tail tip in
  the asset manifest, relative to that origin. These are attachment metadata,
  not extra visible parts. Fit the prop to the actual right hand in Studio;
  "dinner plate" and "hand wide" are visual proportions, not import units.
- The capture loop's origin is the centre of its opening, excluding the
  knot and stub from that calculation. It lies in the exported XZ plane.
  Record `RopeExit` at the stub tip so the Beam meets the mesh cleanly.
- The snapped end is centred along its main shaft, with its length on the
  exported X axis and the broken tips towards +X. Record the intact endpoint
  for placement. The star is centred on its own shape, with +Y towards its
  top point and its broad faces towards +/-Z.
- Review each coil both as a held prop and in a 64-pixel shop thumbnail.
  Render the shop card from the same model. Recolour the shared coil for
  all four tiers; the Braided texture does not require fibre geometry.
  Tier names remain visible in UI alongside the colour differences.
- Use the coil for holding and the overhead twirl, then hide it at the
  throw's `Release` marker and show the capture loop plus Beam. On a miss,
  remove the loop/Beam and spawn two copies of the snapped end. These are
  separate visual states; the rigid coil does not need an uncoiling rig.

The complete local kit is in `assets/lassos/`, with its handoff in `README.md`.
`coil/` is the production shared mesh; `tiers/` contains four textured Blender
looks and `textures/` contains matching 1024- and 512-pixel atlases. The loop,
snapped end, and daze star have their own sources and exports. Manifests
record attachment positions. `validation.json` records export checks and
identical tier geometry. Live in-hand and piggy fit remain integration work.
The original plain-color coil is retained in `rope/`.

Generate few candidates and import only the one you pick. Anything uploaded
to Roblox lands on your account and is moderated like anything else you
upload.

### Character animations (R15)

Author these on a rig with the real character's proportions, not the default
block rig; the carry hand position was once wrong by most of a stud because
of that. Upload each as a KeyframeSequence and give it a row in
`Config.ANIMATIONS`.

| Name | Length | Body | Notes |
|---|---|---|---|
| LassoTwirl | loop | upper body only | right arm circles the coil overhead while held. Leave the legs out so the run cycle keeps them |
| LassoThrow | about 0.4 s | upper body only | overhand release. Add a keyframe marker named `Release` where the rope should leave the hand |
| LassoPull | loop | full body | feet planted, leaning back, both hands on the rope. Code speeds it up with the tap rate |
| LassoWin | about 0.8 s | full body | a yank and a fist pump |
| LassoSnap | about 0.6 s | full body | a stumble back as the rope breaks |
| KnockedLoose | about 0.6 s | full body | the carrier jolts and the piggy tumbles out of their arms |
| ScoopUp | about 0.5 s | full body | a crouch and a scoop, picking a dazed piggy up off the ground; it ends in the existing hug carry pose |

The carry home itself needs no new animation: it is the existing hug.

**A 3D generator cannot make these.** Text-to-3D tools produce meshes; the
ones that animate do it on their own skeleton, which then has to be
retargeted onto R15 before Roblox will play it. The cheaper route is the one
this game already uses for the dodge, the rider poses and the carry: the
poses are written in code and uploaded as KeyframeSequences. The plan is to
build all seven that way in phase 2; the models above are separate Blender
authoring work.

### Nothing to build for the piggy

Wild piggies are built from parts and animated by code (`PiggyWalk`), so the
wriggle, the run and the caught pop are code. Animating them in Blender would
mean rigging every piggy, which is a far bigger job than this feature.

### Model briefs / generator prompts

Revised after reading the gameplay requirements. These shapes are simple
enough to author directly in Blender, which lets us control the topology,
part split, and attachment positions. A text-to-3D generator is optional.
The paragraphs describe appearance; the production contract above must be
implemented and checked in the exported model, not assumed from a prompt.

Shared style: low-poly cartoon props for a kids' game, flat-shaded with
rounded silhouettes and clean base colours. Tier atlases add a broad woven
pattern for Braided and a blue grip emblem for Elite. No baked lighting,
realistic fibres, text, logos, hands, characters, ground, or display bases.
Each brief describes one assembled asset; named parts remain separate meshes.
Preview lighting is not baked into materials.

**1. Lasso coil**

> An upright cowboy lasso coil, compact enough to hold by its top band in one
> hand. One continuous thick rope makes three and a half to four neat turns,
> nested side by side in a mostly flat circular spiral. Keep a clearly open
> centre, roughly one third of the coil's overall width. Each rope strand is
> round in cross-section and about one twelfth of the coil's width, with
> smooth, untwisted segments. At the bottom, the outer turn bends gently into
> a short downward tail with a straight final section and a blunt end. At
> twelve o'clock, a broad rounded leather band crosses and binds all turns;
> hide the inner rope end beneath it. Exactly two meshes: `Rope`, plain light
> tan, and `Grip`, dark brown. No buckle, stitching, extra ties, or ornaments.

Authoring target: at most 6,000 triangles total. The existing first model is
compatible with this brief; it does not need to be regenerated from scratch.

**2. Tier texture set, including Elite**

> Four clean cartoon base-color maps for the same standard coil and UV layout.
> Rope: plain light tan rope with a dark brown leather grip. Braided: warm
> brown rope with broad interwoven tan and brown bands, and a dark brown grip
> with lighter end bands. Golden: bright warm gold rope, a copper-brown grip,
> and gold bands at the ends. Elite: royal purple rope with a warm gold grip
> and one sky-blue faceted emblem printed on the front of the grip. Keep the
> emblem large enough to read on a shop card. No additional geometry, hanging
> charms, realistic fibres, lighting baked into the colours, or glow shells.

All tiers share the 4,964-triangle coil. One atlas per tier covers both mesh
parts and also supplies the matching rope effect colours. Use the same
texture on the loop and snapped end. The earlier sculpted Elite is retained
only as an alternate in `assets/lassos/alternates/elite-sculpted/`.

**3. Loop**

> One open circular capture loop of smooth, untwisted rope, lying flat.
> Its outside diameter is eight to ten times the rope's strand diameter,
> leaving a generous clear opening for a cartoon piggy's torso. The rope has
> a round, softly faceted cross-section. At one side, a compact rounded slip
> knot sits outside the opening; a short straight rope stub projects radially
> outward from it for the connecting rope. Keep the knot chunky and readable,
> without tiny interwoven strands. One mesh named `Loop`, entirely plain
> light tan, including knot and stub. No long trailing rope or decorations.

Authoring target: at most 1,500 triangles. All tiers share and recolour this
model. Test closure around actual piggy bodies; size to the torso, not the
neck, and leave enough clearance to avoid sinking into the body. The Beam
supplies the long rope to the hand.

**4. Snapped rope end**

> A short cartoon rope fragment with a straight thick shaft about six times
> as long as it is wide. One end is blunt and softly rounded. The other end
> splits into four short, thick, slightly splayed fibre lobes, joined to the
> shaft and ending in rounded tips. Make the broken silhouette readable at a
> small size, like a chunky forked tuft rather than a fine paintbrush. One
> mesh named `SnappedEnd`, entirely plain light tan. Smooth rope surface,
> without twisted strands, hair-like fibres, separate flying pieces, or knots.

Authoring target: at most 800 triangles. Recolour to the active rope tier;
spawn and rotate two instances for the break effect. No separate left/right
exports or prebuilt falling animation are needed.

**5. Daze star (optional)**

> One chunky five-pointed cartoon star, plain bright lemon yellow. A clean,
> symmetric silhouette with short rounded points, gently bevelled edges,
> broad flat front and back faces, and biscuit-like thickness about one
> fifth of its width. One mesh named `Star`, upright and centred. No face,
> outline, white orbit ring, trail, glow, stand, or additional stars.

Authoring target: at most 300 triangles for the one star. Code places three
to five copies around the head and controls their orbit, tilt, and fade.

## 7. Build status (2026-09-23)

Phases 1 to 3 are in code; phase 4 (art upload and numbers) is open.

| Piece | Where |
|---|---|
| Odds, prices, description, audit | `Config.LASSOS`, `Config.LASSO`, `Config.lassoChance`, `lassoDescription`, `auditLassos` |
| Throw, struggle, taps, pity, buying, stock push, starter stock | `LassoService` |
| Target ids, flee, dazed piggies, wake-up | `HerdService` (the free CatchPrompt is gone) |
| The `wild` haul, knock-loose, pick-up immunity, theft | `PiggyHaulService`, wired by `LassoService.start` |
| Zapper knock | `GadgetService.registerZapKnock` |
| Elite receipts behind the PolicyService gate | `ProductService.onLassoReceipt` |
| Lock-on, throw, rope, TAP card, stars, poses | `Lasso.client.luau`, `Shared/LassoModel`, `Shared/LassoPose` |
| Supplies cards, hot bar tiles (key G), Elite card | `Shared/LassoShop`, `PremiumShop`, `HotBar` |
| Admin | `lassos`, `droppiggy <rarity>` on the Lasso panel group |
| Tests | `tests/luau/lasso.luau`, `tests/luau/lassopose.luau` |

The Golden Lasso's key is `goldlasso`, never `golden`: that is the Golden
Bone's key, and every consumable shares one namespace.

Four calls the build made where the plan was silent:

1. **Knocking loose a STOLEN catch gives the 5-second window to the robbed
   catcher,** not to the thief who was carrying it. If the catcher has left,
   it falls back to the carrier.
2. **A theft counts when the piggy is secured, not at the throw.** That is
   the existing snatch rule: a haul knocked loose on the way home was never
   stolen. The catcher is alerted at the catch.
3. **A missed dazed piggy does not run.** It stays dazed; the miss still
   raises the thrower's odds on it.
4. **A dazed piggy that wakes outside the herd band** (on the street, a
   lawn or in a hallway) is recalled into the sky rather than roaming there.

## 8. Not yet verified

Nothing has run in Studio. The mesh and texture kit has local Blender
sources and validated FBX exports, but that does not verify the gameplay. The two things only a playtest can answer are
whether 2.5 seconds of tapping feels good on a tablet, and whether a
14.4-stud-per-second flee reads as a chase or as a nuisance.
