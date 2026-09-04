# Rob a Piggy Bank — the whole game

**This is the source of truth for WHAT the game is. `CLAUDE.md` is the source of
truth for WHY it is that way.** They are different documents on purpose and
neither replaces the other:

| | `docs/GAME.md` (this file) | `CLAUDE.md` | `docs/design-doc.html` |
|---|---|---|---|
| Answers | what exists, where it lives | why it was built that way, what breaks if you change it | the original pitch and balance targets |
| Shape | a map, read top to bottom | rules and post-mortems, read on demand | a designed page, read in a browser |
| Audience | anyone new to the repo | anyone about to change something | anyone deciding what to build |

**Numbers live in `Config.luau`, not here.** This file names the constant and the
file; it does not copy the value, because a copied number is a number that will
be wrong within a month. The handful of figures quoted below are the ones you
cannot orient without — they are marked, and if one of them disagrees with
`Config`, **`Config` is right and this file is stale.**

> **Maintenance.** This document is kept current by the `game-doc` agent
> (`.claude/agents/game-doc.md`). Run it after any change that adds a system,
> retires one, moves a number between systems, or changes a save field. It
> rewrites sections in place rather than appending.

---

## 1. What the game is

A shared-economy PvP idle game for an **under-12 audience**.

Every player owns one of eight plots on a suburban street. On the plot is a
**piggy bank** that fills with coins over time. Coins in the piggy bank are
**uncollected and stealable**; coins you have banked are **permanently safe**.
Other players can walk onto your lawn, crack your lock and take a slice of the
uncollected pile — and you can do the same to them.

Two upgrade trees compete: **defence** (fence, guard dog, vault lock) buys the
victim *time*, never immunity; **offence** (lockpicks, bigger sack, speed boots)
buys the thief speed and volume. Neither can ever close the other out.

The loop, in one line: **accrue → bank (or get robbed) → upgrade → rebirth →
collect cosmetics.**

### The three rules everything else is built on

1. **The server owns all state.** The client renders the last `StateUpdate` and
   never computes a balance.
2. **Only uncollected coins are stealable.** A robbery costs minutes of idle
   income and never costs progress. This is what keeps the game from being a
   bullying simulator.
3. **Speed is the currency.** `BASE_WALK_SPEED = 16` is the number every other
   system is calibrated against. Nothing may exceed it.

---

## 2. How the project is built

**The entire world is generated in code at server start.** There is no
hand-built geometry — the ground, the street, the tunnels, the houses, all
eight plots, the piggies, the dogs and the police car are constructed by
scripts. A fresh empty place plus this repo reproduces the world exactly, which
is why **the `.rbxl` is disposable and this repo is the project.**

```
rojo serve default.project.json     # then Plugins → Rojo → Connect in Studio
rojo build default.project.json -o RobAPiggyBank.rbxlx
```

Two things about Studio that cost time every session if forgotten:

- **Studio forks scripts when you press Play.** Save, wait for Rojo to push,
  *then* Play.
- **Rojo does not push at all while Play is running.** Stop, confirm the source
  landed, restart.

### Layout

```
src/
  ReplicatedStorage/Shared/     geometry and tables both sides need
  ServerScriptService/
    Main.server.luau            entry point: starts services, owns player lifecycle
    Services/                   one file per system (see §12)
  StarterPlayer/StarterPlayerScripts/
    ClientMain.client.luau      the HUD and the shop
```

**Geometry the shop renders lives in `Shared`.** That is why `House`, `Decor`,
`PiggyModel`, `RideModel`, `PigGear` and `PlayerGear` are modules and not
services: the shop shows the *real* item, built by the same function that puts
it on a lawn. A second near-identical copy drifts the first time either is
touched.

**`ClientMain` is one chunk and sits near Luau's 200-local ceiling.** A new HUD
feature goes in a `local function buildX() … end` (a function body gets its own
register file, so the chunk pays one local instead of twenty) or in its own
module. `AdminPanel`, `SpinWheel`, `RaidFX`, `HouseFX` and `Rebirth` are modules
for exactly this reason.

---

## 3. Currencies

There are **three**. Which one buys what used to be a legal question as much as
a design one; it no longer is, because none of the three can be bought with
Robux, at any price, ever.

| | Field | Earned by | Buys | Purchasable with Robux? |
|---|---|---|---|---|
| **Coins** | `data.coins` (banked), `data.vault` (stealable) | idle accrual, stealing, milestones, dailies | upgrades, skins, effects, houses, decorations, rides, consumables, and now **chests** (below) | **never, at any price** |
| **Medals** | `data.medals` | attending events | set items, in their own home tabs | never |
| **Tokens** | `data.tokens` | daily claims, attending events | the accessory roll, and now the `alien` event chest (below) — both wired server-side, neither reachable from any shop UI yet (see §17) | **never, at any price** |

### Why nothing here is a regulated loot box

Roblox defines a **paid random item** as one bought with Robux *or with in-game
currency purchasable with Robux*. Regulated ones carry a real cost: odds
disclosed before purchase summing to 100%, plus a `PolicyService` gate that
makes the feature refuse to open for restricted users in an expanding list of
regions.

**The coin pack was dropped entirely, and that single rule is what now keeps
the whole shop outside the regulation rather than compliant with it.** A chest
bought with coins is a paid random item only if those coins can be bought with
real money — so with coins permanently unsellable, *anything* may be sold for
coins, including random things, with no odds disclosure, no gate and no
regional lockout. `Config.CHESTS`' own header comment states this as the reason
the chest system is allowed to exist at all.

**The rule can only be broken once.** The day a coin pack ships, every chest in
the game becomes a regulated loot box retroactively, with nothing in this repo
having changed — and by then there will be a catalogue of them, not one roll
button. Monetization is named things, never currency: a Robux purchase may
grant an item (a ride, a pass, a stance) but never a coin or a chest, because a
purchase that hands over a specific thing mints no currency and feeds no roll
(see §15).

The accessory roll (below) predates this rule and was the earlier, narrower fix
for the same problem — earn-only currency rather than an unsellable one. It is
still in the game and still works the way it always did; it is no longer *why*
the shop is legal.

### Chests — coin-bought, and duplicates are allowed

`Config.CHESTS` is **five** chests: four on coins (`classics` — 17 skins
tagged `chest = "classics"`; `gear` — 12 accessories tagged `chest = "gear"`;
`animal` and `neon` — 13 skins each) and one on tokens (`alien`, an **event**
chest — see below). Each carries its own `cost`, `currency`, an `odds` table
by rarity and a `blurb`. Membership is a field **on the item**, the same
convention `zone` uses on decor and `set` uses on set items, rather than a
list kept on the chest — a list is a second place to remember and the one
that goes stale. An item's tier inside a chest is `Config.rarityOf`, the same
function that already borders every shop card — not a second notion of
rarity.

`Config.chestPool(key)` returns the stock grouped by tier. A `kind = "set"`
chest — only `alien` today — resolves through `Config.SETS` and
`Config.catalogueFor` instead of scanning a catalogue for a `chest` tag,
because a set spans five catalogues at once; every other chest is a plain
`skin`/`accessory` scan. Skins in a coin chest keep their ordinary `cost` too
— the chest is a second, faster route to the same catalogue, not a
replacement for direct purchase. Accessories carry no `cost` at all, exactly
as before; the `gear` chest and the roll are the only two routes to one.

**Unlike the roll, a chest can return a duplicate on purpose** — that reverses
the collection rule stated in §9. A duplicate becomes a **shard** of that tier
in the same reveal rather than a dead outcome. `Config.COMBINE` is three
shards of a tier for one roll at the next, with a small chance of climbing two
or three tiers in one combine. **Shards are global per tier, not per chest** —
a duplicate out of a finished chest is fuel for one barely started — and
**shards spend only on coin chests**, never on `alien`, so a rich player
cannot grind their way into event loot without ever attending an event.
Effects have no chest: there are too few priced tiers to spread across
rarities, so effects stay direct-purchase.

**`alien` is the first event chest**, bought with tokens rather than coins and
drawing on the same alien **set** (§8) that medals already unlock — a `kind =
"set"` chest is a gamble sitting *beside* the guaranteed medal price, never a
replacement for it. Duplicates from it still produce shards, which is a
small thank-you for attending, but shards cannot be spent back into it.

**`ChestService` is built and wired end to end, and there is still no way to
reach it as a player.** `ChestService.open` and `.combine` are real, the
`ChestOpen` / `ChestCombine` / `ChestResult` / `ChestState` remotes are live,
`Main` starts the service and registers `EconomyService.push` and
`CosmeticsService.push` as its balance pushers, and `data.shards` is a real
save field (`Config.SCHEMA_VERSION` 16). **No shop UI calls either remote** —
`ClientMain` has no chest tab at all — so the only way a human can open one
today is the admin panel's `chest` / `combine` dev commands. See §17.

### Why tokens exist, and what changed

Tokens were invented so the accessory roll could not be sped up with coins
bought by Robux. **That job no longer exists** — coins can never be bought with
Robux at all, so nothing paid for in them, tokens included, needs a separate
earned-only currency to stay legal. The design intent recorded in `CLAUDE.md`
is that tokens move onto event loot instead: earned the same way, but spent on
event-themed chests rather than on the standing catalogue, so a rich player
cannot skip an event. **That move is now built**: `Config.CHESTS.alien` is a
token-priced event chest drawing on the alien set (see above), `ChestService`
can open it, and the alien set's items still carry their own medal price
alongside it. `CosmeticsService.rollAccessory` is untouched and still spends
tokens directly, one at a time, no duplicates — so tokens now have two
destinations rather than one, but **neither the roll's own UI nor a chest tab
exposes the new one**: nothing in `ClientMain` fires `ChestOpen`, so in the
live game today tokens still only ever visibly buy the roll (see §17).

**Both sources are attendance regardless of what they end up buying.** Every
rung of `Config.DAILY_CYCLE` carries its own `tokens`, and an event pays
`Config.TOKENS.attend` plus `Config.TOKENS.cleared` when the street downs every
drone. Event tokens are deliberately **not** per drone — see §8. Neither source
can be hurried with coins.

The currency's **display name is a placeholder** — `Config.ROLL_CURRENCY` is one
table and a rename is that table alone. The **save field `tokens` is hardcoded**,
the same way `data.vault` stays `vault` while the HUD says PIGGY BANK; renaming
a persisted field is a schema migration and should have to look like one.

**One grant path:** `CosmeticsService.awardTokens(player, amount, why)`. It
credits the field and pushes the balance; `why` is optional and nil means
silent, which is how an event folds its tokens into the medal card instead of
firing a fourth toast. `Config.tokenWord(n)` is the singular/plural helper, so
"+1 tokens" cannot reach a nine-year-old from any of the sites that format an
amount.

**Where the numbers live:** `Config.ROLL_CURRENCY`, `Config.TOKENS`,
`Config.ROLL_BASE_COST` / `ROLL_GROWTH`, the per-rung `tokens` in
`Config.DAILY_CYCLE`, and `Config.CHESTS` / `Config.COMBINE` for the new system.

---

## 4. The economy

### The ladder

Income and capacity are each a purchasable level. Both run on **two bands**:

- **Levels 1–20** keep the original growth untouched — that curve was never the
  problem.
- **Levels 21–40** are gentler on both sides, because one curve extended to 40
  fails in both directions (too-fast income trivialises the game; too-fast cost
  means nobody buys the top).

`Config.banded()` writes both as *"band A to the top, then band B beyond"*
rather than branching between two formulas, so the seam is exactly one band-B
multiplier and cannot develop a step.

**Costs are indexed by the level you are LEAVING**, so they run one behind the
value tables: `getIncomeCost(20)` is the price of reaching 21.

**Read the ceiling through `Config.maxLevel(rebirths)`, never from a constant.**
It is `20 + 2 per rebirth`, capped at 40. `EconomyService` pushes its answer as
`maxIncome`/`maxCapacity` and the client draws the ladder from those, so both
ends agree by construction.

### Rebirth

Wipes income, capacity and **both upgrade trees**. Keeps everything cosmetic —
skins, effects, houses, decorations, accessories, gear, rides, medals, tokens
and bones.

- **The gate is a multiple of your reachable capacity**, not a flat number. A
  flat gate evaporates as the economy grows (measured: 334 seconds of income the
  first time you cap the ladder, eight seconds by rebirth 10) and a geometric one
  diverges into a wall. Capacity rides the same curve the player's economy rides,
  so it can do neither — and *"fill your piggy bank twice over"* is the only
  version a nine-year-old can read.
- **Every rebirth grants a skin.** The roll decides how rare, never whether.
- **The explainer page comes BEFORE the button, on the first rebirth only.**
  Shown afterwards it would be a receipt, not a decision. `Shared/Rebirth.luau`.
  Its three panels are deliberately three different shapes:
  **YOU LOSE** is exact — the player's real coin figure and their real upgrade
  levels, because a loss is somebody's actual afternoon; **YOU KEEP** is five
  fixed lines stating the *rule* (cosmetics, house, worn items, rides, stars all
  survive) rather than counting today's inventory, because a promise has to be
  total and a count read off a stale push can disagree with the server; and
  **YOU UNLOCK** is a row of rendered tiles rather than sentences — a drawn coin
  for the income step, a piggy with a "?" for the guaranteed skin (which one is
  a roll, so naming one would promise what the server never said), and any
  count-unlocked skin rendered from its own catalogue key. The model renderer is
  passed in from `ClientMain` rather than reimplemented.

### Offline

Capped, in `Config.OFFLINE_CAP_SECONDS`. The friend bonus does **not** apply to
offline accrual — your friends were not in the server while you were asleep.

**Where the numbers live:** `Config.BASE_INCOME`, `BASE_CAPACITY`,
`INCOME_GROWTH`(`_B`), `CAPACITY_GROWTH`(`_B`), the matching `*_COST_GROWTH`,
`BAND_TOP`, `ABSOLUTE_MAX_LEVEL`, `LEVELS_PER_REBIRTH`, `REBIRTH_MULTIPLIER`,
`REBIRTH_CAPACITY_MULTIPLE`, `OFFLINE_CAP_SECONDS`, `FRIEND_BONUS_*`.

---

## 5. The heist

The whole risk of this game lives in **the run home**.

1. **Walk onto a lawn.** Nothing watches an approach — the guard dog only fires
   *after* a completed steal, so holding somebody's lock carries no dog risk at
   all. Any "be sneakier" feature has to be designed against that fact.
2. **Hold the prompt.** Duration is the victim's Vault Lock against your
   Lockpicks.
3. **Carry.** You move at `CARRY_SPEED_MULTIPLIER` of base, and a banner says so
   to the whole street. Rides are disabled **server-wide** while loot is in
   transit — otherwise a bystander on a scrambler runs down a thief on foot.
4. **Deliver** to your own drop-off, or **get tagged** and lose it.

**`STEAL_RANGE + DROPOFF_RADIUS` must stay well under `PLOT_SPACING`.** If that
sum approaches the spacing, a thief can stand in their own drop-off zone and rob
a neighbour without ever running — and the run is the entire risk half of the
trade.

*Orientation only — `Config` is authoritative.* The sum is 27 against a spacing
of 80, so the shortest getaway is 53 studs, about 4.4 seconds at carry speed. It
was 37 studs and 3.1 seconds before the plot widened, so the rule holds by a
wider margin now rather than a narrower one — but a longer run also hands an
alerted Titan at 17 more time to close. **If robbing ever reads as too hard,
`DROPOFF_RADIUS` is the lever**: it is a fraction of your own plot rather than
an absolute, so it can grow with the plot.

Caps that make camping pointless: `STEAL_COOLDOWN`, `STEAL_MAX_PER_VICTIM`,
`STEAL_FRACTION`, and `NEW_PLAYER_SHIELD` (**15 minutes** — two players who join
and immediately try to rob each other will see nothing happen).

### Defence tree — buys time, never immunity

| | Effect | Ceiling |
|---|---|---|
| **Fence** | Slows and hazards a climb | **Never uncrossable.** Every tier from Barbed Wire up stays at a jumpable 6.0 studs against a 7.2 jump and escalates the hazard instead |
| **Guard Dog** | Chases and tags a thief after a completed steal | Beaten by bones; three breeds with rising `boneResist` |
| **Vault Lock** | Lengthens the steal hold | Readable from the street as a vault dial — a hatch in the piggy's back, with level 0 an open hole |

### Offence tree

**Lockpicks** (shorter hold), **Bigger Sack** (more per grab), **Speed Boots**
(carry speed, **capped at ×1.0** so they never exceed base).

**Where the numbers live:** `Config.UPGRADES`, `FENCE_TIERS`, `DOG_TIERS`,
`STEAL_*`, `TAG_*`, `CARRY_SPEED_MULTIPLIER`, `NEW_PLAYER_SHIELD`.

---

## 6. Consumables and the hot bar

Four catalogues, one gesture: **hold a stock, pick one, use it.**

| Catalogue | Config | What it counters |
|---|---|---|
| **Bones** | `Config.BONES` | The guard dog. Cheap bones bounce off Guard Duty; only the Golden Bone interrupts a chase |
| **Gadgets** | `Config.GADGETS` | Maxed Speed Boots. Range *falls* as power rises, so the decisive one cannot reach a thief who already got clear |
| **Home items** | `Config.HOME_ITEMS` | Guard Duty Treat, Garden Sprinkler (a joke, deliberately toothless), Patrol Radio |
| **Thief kit** | `Config.THIEF_KIT` | Raincoat — sheds the two cheap gadgets, admits the Zapper |

**Cheap counters bounce, the expensive one gets through — on both sides.** Each
raises the *price* of beating someone rather than making them unbeatable.

### The bar itself

- **An item is HELD before it is used.** Selecting is free (a number key or a
  tap asks the server to *draw* something); only a deliberate click out in the
  world spends it. This exists for two reasons: a stray thumb should not spend a
  30,000-coin Golden Bone, and **a thief walking up a driveway holding a Golden
  Bone is information** the defender can read off the lawn.
- **The click sends no position.** `BoneThrow` carries a key and nothing else;
  the server picks the target from its own positions.
- **Keys are fixed per item and never renumbered to fill gaps.** A player may
  *drag* to rearrange — position is the only handle a touch player has — but the
  game never silently moves a binding underneath them.
- **Shelving hides a slot and never destroys stock.** There is no stock cap
  anywhere, so a destroy button would only delete something already paid for.

**Key map:** `Q` dodge / trick · `B` shop · `V` garage · `R` radio · `Esc` close
· `F2` admin · `1`–`0` hot bar. *`G` is free.* A new binding gets checked
against this list and against whether it is genuinely exclusive with what it
lands on.

---

## 7. The police

**The only risk in the game that belongs to nobody.** Every other risk is the
victim's — their dog, their fence, their lock — which leaves a hole no purchase
can close: robbing an offline player is otherwise completely free.

- **Published.** The siren sounds fifteen seconds before the car appears and the
  HUD counts both clocks, so robbing during a patrol is a *choice* rather than
  bad luck — and bad luck is not something a nine-year-old can get better at.
- **Commits to one pursuit.** A live robbery always wins; otherwise the officer
  goes for the **Most Wanted**.
- **The officer runs at 14.5**, between a carrying thief's 12 and a free
  player's 16 — so *delivering* is the answer, and nothing in the patrol exceeds
  `BASE_WALK_SPEED`.
- **Bail is 3× what was taken, capped**, and comes out of the piggy bank, never
  banked coins. Being caught can cost an afternoon of idle income and can never
  cost a house, a skin or an upgrade.
- **An arrested thief is released at their own gate** — a teleport, not a
  respawn, fired off the *end* of the detention.
- **No player can ever aim an officer at another player.** `PoliceService.call`
  (the Patrol Radio) takes **no arguments at all** — not a player, not a plot,
  not a position. A radio brings a car onto the street and says nothing about
  who for; if the caller is top of the board, it is them the officer gets out
  for.

**Most Wanted** is a **per-session** rap sheet counted on *delivery*, not on the
grab. Lifetime totals made it unwinnable — whoever had played longest wore the
label permanently. Escaping a most-wanted pursuit is what unlocks
**`PlayerGear`**, the only cosmetic worn by the player rather than by their
piggy.

**Where the numbers live:** `Config.POLICE`, `STUN_SECONDS`, `Config.GEAR`.

---

## 8. Events

`EventService` runs a roster on a timer. Two events today: **Alien Invasion**
(the flagship) and **Rush Hour**.

- **An event reuses the heist verbs and adds none.** You break a beam by
  *throwing* a gadget and recover loot by *holding a prompt*. No new input, no
  new button, and no weapon anywhere in it.
- **The Alien Invasion is the flagship because the street has never been on the
  same side.** Every other mechanic is adversarial; for the length of a raid a
  full server means more *defenders*.
- **A drain that does not beat income is invisible.** `drainIncomeMultiple` is a
  floor expressed as a multiple of the victim's own income, so the pile visibly
  falls at every tier.
- **The picker damps repeats rather than forbidding them.** With two events,
  "never the same twice in a row" leaves exactly one candidate and produces
  strict alternation. `REPEAT_WEIGHT` keeps the last pick in the draw at a
  fraction of its weight.
- **An event suppresses the patrol**, which is what lets them share a HUD row.
  The patrol is *deferred*, never cancelled.

**Rewards:** coins (income-seconds), **medals**, **tokens**, and a **set drop**.
Event tokens are attendance only — deliberately **not** per drone, or the pacing
of the accessory collection would come from how many drones a random event
happened to spawn.

**Sets** are a **view over the existing catalogues**, never a new catalogue.
`Config.SETS` lists `{kind, key}` pairs pointing at ordinary members of `SKINS`,
`EFFECTS`, `ACCESSORIES`, `DECOR_ITEMS` and `RIDES`. No new ownership storage, no
new equip path. **`set` is an exclusion** and is load-bearing in four places — it
keeps set items out of the token roll, out of the rebirth drop pool, and out of
both free-if-costless fallbacks.

**Nothing is ever locked behind luck.** Every set item carries a medal price, so
a drop only ever saves you time. That is the line that makes a spinner safe for
a nine-year-old: bad luck costs a wait, never the item. **The wheel is free and
must stay free.**

---

## 9. Cosmetics

Roughly a hundred items across seven catalogues — the skins catalogue alone
grew past 40 once the Animal and Neon lines landed. **None of them confer
anything.**
That is what makes them safe to price steeply, and it is why houses in
particular are pure prestige.

| Catalogue | Config | Bought with | Notes |
|---|---|---|---|
| **Skins** | `SKINS` | coins, or granted by rebirth | Animated skins are driven **on the client** from a `SkinKey` attribute. 43 also carry a `chest` tag (17 `classics`, 13 `animal`, 13 `neon`) — see §3 |
| **Effects** | `EFFECTS` | coins | Shop tiles *simulate* the real particle numbers — a ViewportFrame renders BaseParts and nothing else. No chest: too few tiers |
| **Houses** | `HOUSE_TIERS` | coins | Bought as a ladder (`houseLevel`), worn as a shelf (`houseShown`) — move back into any tier free, forever |
| **Decorations** | `DECOR_ITEMS` | coins | Auto-placed into slots; **slots are scarcer than items** on purpose |
| **Accessories** | `ACCESSORIES` | **tokens, by rolling** | Four slots, all worn at once. 12 also carry `chest = "gear"`; `ChestService` can open it, but nothing in the shop UI does yet — see §3, §17 |
| **Rides** | `RIDES` | coins | Street only; a ride confers nothing else |
| **Player gear** | `GEAR` | earned only | Most Wanted escapes |
| **Stances** | in `RIDES` | **Robux (Style Pack)** | The one cosmetic shaped to be sold directly |

### The roll

The one random-outcome mechanic that is actually live. It predates the coin
chests in §3 and is untouched by them.

- **A roll can only return something you do not already own.** The pool is
  rebuilt from the unowned set every time, so duplicates are impossible, every
  roll is progress, and the collection always completes. No pity timer to tune,
  no duplicate currency to invent. **A coin chest reverses this on purpose** —
  see §3 — because a chest that cannot repeat has no rarity variance to feel.
- **Price climbs with how many you own**, so the pace is set by the collection
  rather than by whoever has the deepest vault.
- **Set accessories are excluded**, and both the price index and the "finished"
  test measure against `Config.rollableAccessoryCount()` — the pool a roll can
  actually draw from — not the whole catalogue.

### Rarity

**One ladder for the whole shop**, `Config.RARITIES`, with **absolute** coin
bands. A tier is **derived, never hand-tagged**: an explicit `rarity` wins, then
`unlockRebirths`, then the price. That is what keeps it honest as the shop grows.
**Only things you keep get a tier** — consumables deliberately have none.

The chests in §3 reuse this same function (`Config.rarityOf`) to sort their
stock into odds bands — one tier system for the whole shop, not a second one
invented for chests.

---

## 10. Rides and movement

Six rides. **A ride is for the street and is switched off everywhere else** —
carrying loot, being robbed, snagged on a fence, or not standing on the street.
Drop any one condition and a specific system dies.

`Config.isOnStreet` is the positive rule (the corridor between the two rows of
front fences, the whole verge included) and `PlotService.yardContaining` is a
veto on top. `isOnStreet`'s corridor is bounded by `streetMetrics().fenceLine`,
which derives from `Config.PLOT_FRONT_LINE`, and `yardContaining` tests that
same front line against `Config.PLOT_HALF_WIDTH` at the sides. **Those are two
different numbers now** — see §11; taking the wrong one moves the ride gate's
boundary.

- **Mounting is automatic** — no button. `Humanoid.HipHeight` is what lifts the
  rider onto a board authored with y=0 at the ground.
- **A rider's pose is an animation**, built at runtime and played per client,
  because a `hash://` id cannot replicate.
- **Move the bike to the hand, never the hand to the bike.** Poses are measured
  on a live rig, then the ride's grips and pedals are placed at what came back.
  A real bicycle does not fit a Roblox character.
- **A stance is an override, never a whole pose**, merged one level into `left`
  and `right`.
- **A trick is driven by the machine, never by a clock** — `RidePose.phaseOf`
  reads the chassis each frame, so the rider cannot desync from the bike.

**Speed table (orientation only — `Config` is authoritative):** base 16 ·
carrying 12 · dogs 12 / 14.5 / 17 · officer 14.5 · fence snags ×0.80 → ×0.30 ·
electric stun 0. **Anything that makes a player faster than 16 invalidates
several systems at once.**

### Sound

Every ride's `volume` is meaningless without its recording's own level —
measured with `Sound.PlaybackLoudness` in a **running game** (it reads 0.0 in
Edit for everything). `RollOffMinDistance` is what splits the rider's volume
from a bystander's: the emitter is welded to the rider's own body, so they are
always inside the bubble hearing the raw number while everyone else hears
`Volume × min / distance`.

---

## 11. The world

One street, eight plots in two rows of four, a **wide verge** carrying the
boards and the shops, and a hill with a tunnel through it at both ends.

### The shape, and why it changed

It was twelve plots in two rows of six with the plaza off one end, and the
numbers said that was too big for what happens on it:

| | 12 plots | 8 plots |
|---|---|---|
| Worst-case steal (corner to corner) | 336 studs / **21.0s** | 240 / **15.0s** |
| Farthest plot to the centre | 370 studs / **23.1s** | 96 / **6.0s** |
| Verge between kerb and fence | 18.4 studs | **38.4** |
| Driveway length | 18.4 studs | **38.4** |
| The getaway itself | 27 studs / 1.7s | **unchanged** |
| Workspace BaseParts | 1,891 | ~1,500 |

**Every along-street distance in this section was measured at the plot spacing
of the day**, in this table and in the `STREET_SPACING` one below it. The plot
has since widened and `PLOT_SPACING` went with it (see *The plot is a
rectangle*), so the row is now 307 studs across against the 243 in that column,
and the getaway is longer rather than unchanged. The cross-street figures and
the verge and driveway bands are untouched, because the plot got wider rather
than deeper.

Twenty-one seconds of holding W to buy a getaway that lasts two is a ten-to-one
ratio of travel to game, and the walk to the only reason to go anywhere was
worse. Moving everything worth walking to into the MIDDLE of the street is
the bigger of the two fixes; the plot count is the smaller one.

**Performance was never the reason.** 1,891 parts with 22 animated per frame is
nothing for Roblox. What eight players saves is eight characters and eight dogs
of replication, and what it really buys is the lobby: a twelve-cap server
sitting at six reads as abandoned, an eight-cap at six reads as busy.

**What it costs is rides.** The walk between plots is what a ride is sold
against, and a shorter street is a smaller saving. Four a side rather than
three is where that argument stopped.

### The row is continuous; the verge is what got wider

There was briefly a **hole** in the middle of each row — one empty
`PLOT_SPACING` slot — with the town square sitting in it. It worked and it read
as a missing tooth: a whole plot slot of nothing between two houses is not a
gap, it is an absence, and it was the widest thing on the street.

So the square moved **sideways instead of along**. `STREET_SPACING` went
**104 → 144**, which widens the band between the kerb and the front fences from
18.4 studs to 38.4, and everything the square held now stands on that band —
which runs the whole length of the street, so there is somewhere to put things
without taking a house out of the row.

**Why 144 and not 208.** Doubling was the obvious move and it costs the one
number that must not grow:

| spacing | verge band | cross-street carry | worst steal |
|---|---|---|---|
| 104 | 18.4 | 8.7s | 218 / 18.2s |
| **144** | **38.4** | **12.0s** | **240 / 20.0s** |
| 208 | 70.4 | 17.3s | 283 / 23.6s |

`STREET_SPACING`'s whole job is that across the road is *a choice* rather than
*never*. At 208 a cross-street robbery is 17.3 seconds of carrying at 12
against an alerted Titan at 17 — nobody does it, and half the server stops
being a target. It also lands the map **longer than the one this set out to
shrink**. 144 doubles the buildable band and still comes in shorter than the
twelve-plot map.

`ROAD_HALF_WIDTH` stays pinned, so all of that widening lands on the verge and
none of it on the tarmac. That is the whole reason it isn't derived.

- **`PLOT_COUNT` is DERIVED** as `PLOTS_PER_ROW * 2`. They used to be two
  independent constants, and `plotCFrame` puts row 0 at −z and *everything
  else* at +z — so changing one without the other would have built the extra
  plots silently on top of the far row.
- **The alley between neighbouring fences stays.** That one is load-bearing for
  the ride gate and the getaway; it is the one-slot hole in the row that went.
  `PLOT_SPACING` moved with `PLOT_SIZE.X` precisely to hold it — see below.

### The plot is a rectangle, and the fence is two numbers

`Config.PLOT_SIZE` is **wider than it is deep** for the first time: X runs
across the plot along the street, Z is depth, and the yard runs back from the
pavement to `−YARD_DEPTH`. The width grew to fit bigger houses and more lawn,
and `PLOT_SPACING` grew with it — the alley between two neighbouring fences is
`spacing − (plotWidth + 2 × FENCE_OFFSET)`, so leaving the spacing alone would
have driven that negative and had neighbouring fences share ground.

**The fence's side extent and its front line used to be one number, and they
are now two.** Both were `PLOT_SIZE.X / 2 + 1.6`, which was correct only while
the plot was square:

| | Constant | What it is |
|---|---|---|
| Sides | `Config.PLOT_HALF_WIDTH` | an **X extent** — how far the side fences stand out |
| Front | `Config.PLOT_FRONT_LINE` | a **Z position** — the line a thief crosses |
| Both | `Config.FENCE_OFFSET` | how far a fence stands off the slab edge |

Four readers had to be split: `PlotService.buildFence`,
`PlotService.yardContaining`, `HomeService.trespassers` and
`Config.streetMetrics`. **Taking the X half in `streetMetrics` would have moved
the front fence eight studs toward the road on every plot, silently** — the ride
gate's boundary, both boards and all four shop fronts are all derived from that
line, and nothing would have errored. Anything that reads one of these has to
say which.

This is the same trap `YARD_DEPTH` already records one axis over: **two numbers
that agree by coincidence are one bug waiting for somebody to change either of
them.**

`YARD_DEPTH` itself is **unchanged**. A deeper yard was considered and rejected;
there is still no back garden, and the back fence still sits where the deepest
house tier needs it.

**What the widening actually bought is room in the house catalogue.** Every
tier fitted inside the old fence interior and always had — the widest building
is the Marble Palace — but it left barely two studs of headroom, so the next
wide tier had nowhere to go. It now has eighteen. *(The long-standing claim
that the Sky Castle overhung the fence by 8.3 studs a side was a measurement
error, not a bug: see the `HouseFX` rule below.)*

### What lives on the verge

Everything is placed in the **gaps between driveways** — `DRIVEWAY_WIDTH` runs
down each plot centre, so the midpoint between two of them is the one stretch of
verge belonging to no plot — and set back by a figure derived in
`Config.streetMetrics` so widening the street moves them all. The gap positions
come from `gapX`, which is the midpoint of two `Config.plotColumnX` values and
therefore widened with `PLOT_SPACING`:

| | where | clearance |
|---|---|---|
| Lamp posts, wheelie bins | just off the kerb, \|z\| 9.8 | unchanged |
| Leaderboard / Most Wanted | mid-verge (`boardZ`), \|z\| 27.2, x 0 | 17.2 to the fence |
| Four shopfronts | back of the verge (`shopZ`), \|z\| 32.4, on the outer gaps | 4.8 to the front ClimbZone |

The two `|z|` figures survived the plot widening untouched, because both derive
from `PLOT_FRONT_LINE` and the plot got wider rather than deeper. **That is the
whole payoff of splitting the constant.**

- **One pair of boards, not two.** A SurfaceGui culls on distance from the
  *character*, so a single pair at one end of the street was never rendered for
  the far half — two pairs was the workaround. Centred at x 0, no plot is further
  than one and a half `PLOT_SPACING` along the street from the pair. They face each other across the road, standing on grass.
- **Four shopfronts**, one per shop tab, and they are four different
  *buildings* — a boutique with a pitched gable and a scalloped blind, a
  glasshouse with an open front, a workshop with a roller bay and a quarter
  pipe, and a strongroom with a castellated parapet and barred glass. Each
  carries a **projecting bracket sign**, because a fascia faces the road and
  is edge-on to anybody walking along it.
  - They are **destinations, not gates** — the panel still opens anywhere with
    B, and the door prompt only saves picking a tab.
  - **The window holds the real item**, built by the same function that puts
    one on a lawn or under a rider: a mini piggy, a BMX, a Golden Bone. The
    garden centre has none on purpose — its stock is its frontage.
  - **The neon is `HouseFX`**, the animator the house light show already uses.
    A tag and an `FX` attribute per part, no new animation code, and its
    `MAX_RATE` ceiling means nothing here can be authored into a strobe.
- **The driveway doubled in length** to 38.4, which is what puts the houses
  properly back off the street.

### `MaxPlayers` is not code, and it was wrong

One plot per player is a hard limit — `Main` kicks anybody it cannot seat with
"This server is full" — and the place was configured for **60** against twelve
plots. Forty-eight players out of sixty were being turned away, which is
invisible in a solo test.

`default.project.json` now owns it, so `rojo build` produces a place with
`MaxPlayers = 8`. It is **read-only from a script**, so an already-published
place has to be changed by hand in **File → Game Settings → World → Max Player
Count**, or on the Creator Dashboard. Keep it equal to `Config.PLOT_COUNT`.

### The lawn is rows, not a ring

`Config.DECOR_SLOTS` is a **grid**: four rows across the depth of the lawn,
three columns across its width, offsets plot-local with +Z toward the street.
Four of the twelve positions are spoken for: the piggy bank and the walk from
the gate up to it take the front three of the centre column, and the kennel
holds the front-right corner. That leaves **eight lawn slots**, up from the old
ring's seven. Only the back row keeps a centre slot, because it sits behind the
piggy where the gate walk does not reach. Two verge slots flank the driveway outside the fence, and
they are still the only ground out there that stays dry at fence tier 5.

**The row spacing is one number covering every pair.** Ornaments are far
shallower than they are wide, so two slots whose Z differs by more than the
deepest ornament cannot overlap whatever stands in them — one rule for all 196
item pairings instead of a per-pair clearance nobody re-checks when the
fifteenth ornament lands. **An ornament deeper than the row spacing breaks this
and has to move the rows**, which is the one thing to check before adding one.

**The old ring was measurably broken.** Its spacing argument had been written
against the gnome when the widest ornament is the Wacky Waving Man, and was
never re-derived: four of the seven slots put the widest item through a side
fence and two adjacent pairs overlapped outright.

**What limits the column count is that one ornament, not the plot.** A row fits
three columns at the tube man's width; at the next widest it would fit four. If
more slots are ever wanted, that ornament is the lever.

**The kennel moved to the front-right corner** when the plot widened — on the
old narrow lawn its position was near the edge, and on the wide one the same
offset stood a third of the way in, with the dog napping in the middle of
somebody's garden. The corner is also what buys the eighth slot: it holds
exactly one grid position, where anywhere in the middle would have cost two. It
is placed by `PlotService.buildPlot`, not by `Config.DECOR_SLOTS`.

Decorations are still **auto-placed and never collide** — every ornament is
`CanCollide` and `CanQuery` off, so none of it can body-block a defender, a
thief or the dog — and **slots stay scarcer than items** on purpose.

### Layout rules that still hold

- **A plot is three different floor heights** — lawn (+0.5), driveway (−0.28),
  verge (−0.5).
- **Only the yard's FRONT line is load-bearing.** That line is
  `Config.PLOT_FRONT_LINE` and every heist number is tuned against it, because
  a thief approaches from the street. The fence runs `YARD_DEPTH` back to
  enclose the house; the back can move freely to fit buildings, and everything
  derives from that constant rather than keeping a copy.
- **A house is seated by its FRONT wall.** Depth varies by 41 studs across nine
  tiers, so pinning the back threw all of it forward onto the lawn.
- **Measure a building by its PARTS, never by its Model.** A bounding box is the
  extent of everything parented under the model, and this project deliberately
  parents animated decoration into houses — halos, orbiting shards, crown
  segments. Anything asking *does this fit the plot* has to walk the BaseParts
  and skip the `HouseFX` tag, or it is measuring a light show sixty-seven studs
  in the air.
- **The road is a fixed width, never derived.** `Config.streetMetrics()` is the
  single source; two files need the tunnel mouths.
- **Nothing here can be dug.** A Part cannot cut a hole in another Part, so
  sunkenness is always an illusion: the moat's depth comes from kerbs standing
  *proud*, and the tunnel is a black `Neon` slab, not a bore. (CSG — `UnionAsync`
  / `SubtractAsync` — *does* work at runtime, but it is **server-only**.)
- **Hills are the only scenery that collides.** Everything else in
  `NeighborhoodService` is non-colliding so a chase can run through it.
- **Wheelie bins are public street furniture**, three a side, owned by nobody.
  Hiding is a *place*, not a costume. A bin buys a breath, never an escape.

---

## 12. Services

| Service | Owns |
|---|---|
| `DataService` | Session-locked DataStore persistence, the schema, reconcile |
| `WorldService` | Ground, lighting, `ClockTime` (fixed — **there is no night**) |
| `NeighborhoodService` | Road, tunnels, verge, shopfronts, trees, street furniture, bins |
| `PlotService` | Plot pool, fences, driveways, ownership, signs |
| `PiggyBank` | The piggy model, coin pile, skins, effects, vault dial |
| `GuardDog` | Patrol, kennel, guard duty, the off-duty nap |
| `BoneService` | Thrown bones |
| `EconomyService` | Accrual loop, milestones, banking, the `StateUpdate` push |
| `UpgradeService` | Both upgrade trees |
| `HeistService` | Stealing, carrying, tagging, delivering, the dodge |
| `CosmeticsService` | Buying and equipping everything cosmetic; **the roll and tokens** |
| `ProgressionService` | Rebirth |
| `SocialService` | Friend bonus, leaderboards, Most Wanted board, revenge markers |
| `PoliceService` | Patrol schedule, pursuit, arrest, the radio |
| `EventService` | The event roster |
| `SetService` | Medals, sets, the drop reel |
| `ChestService` | Opening chests and combining shard duplicates (leaf: requires `DataService`, `SetService`) — no shop UI reaches it yet, see §17 |
| `DailyService` | The daily ladder and boosts |
| `RideService` | Mount gate, welds, tricks |
| `StealthService` | Bins and hiding |
| `HeldItemService` | What is in a player's hand (**a leaf** — requires only `DataService`) |
| `GadgetService`, `HomeService` | The two remaining consumable catalogues |
| `PassService` | Game pass ownership, cached per session |
| `SettingsService` | The one thing a client may write |
| `AdminService` | Owner-only dev console (F2) |

**Cycles are broken with registries, not with requires.** `SetService.registerPusher`,
`HeldItemService`'s vetoes and `ChestService.registerBalancePusher` are all filled
in by `Main`, which keeps each service's dependency list at one line and makes a
cycle impossible rather than merely absent today.

---

## 13. Persistence

`Config.SCHEMA_VERSION` — bumped whenever a field is added.
`DataService.reconcile` fills in fields added by later versions **one level
deep** without touching existing values, so a new field that defaults to zero or
an empty table needs no migration branch at all. Real migrations (renames,
rescaling) branch on `envelope.schema`.

Two rules learned the hard way:

- **A retired item is pruned against the CATALOGUE, never against a list of
  names.** Ask whether the key and the slot still exist, and anything retired
  later is handled with no new code.
- **Any migration that pays out must be measured idempotent first.** One that
  pays on every join is a money printer — a far worse bug than the one being
  fixed.

**Settings are the one thing a client is allowed to write**, so
`SettingsService` is an **allowlist of sanitisers** — each key maps to a function
returning the value to *store*, or nil to refuse. A type name cannot bound a
table, which is why it is sanitisers rather than a key→typename map. **Nothing
in `settings` may ever affect an outcome** — no speed, no income, no odds.

---

## 14. Client surfaces

- **The HUD.** Top-centre is a five-band column and is **full** (coins, toast,
  rebirth, carry banner, patrol banner). Bottom-left is four rows deep and the
  fifth control went *sideways* rather than up. `IgnoreGuiInset` is on, so y=0 is
  *under* the Roblox topbar.
- **The shop.** Four tabs (Defend/Rob, Your Piggy, Your Home, Your Gear) over a
  front page that shows all seven shelves on one screen with no scrolling. Cards
  render the **real 3D item**. The tab rail is a `ScrollingFrame` — a fixed one
  silently ate two whole tabs, because a `UIListLayout` does not clip and does
  not error.
- **Notifications.** Nine *kinds* in `Config.NOTIFY`, each a colour, glyph,
  sound and hold. Toasts **stack**, each owns its own clock, and the hold is a
  function of how much there is to read. The three urgent kinds flash the screen
  edges.
- **Physical boards.** The leaderboard and the Most Wanted poster are objects in
  the world at *both* ends of the street, not HUD panels — the physicality is the
  mechanic. `SurfaceGui` culls by distance from the **character**, not the camera.
- **Music.** Cues play through once from a shuffled bag with 55–110 seconds of
  silence between them. **Nothing loops.** The toggle turns off *music only* —
  muting effects would hide the siren.

---

### The look

**`Shared/Theme` is the single source of every UI colour in the game, not only
the HUD's.** `ShopStyle`, `ClientMain`, `Rebirth`, `AdminPanel`, `HotBar` and
`SpinWheel` used to each carry their own palette — `ShopStyle` its own cold
navy, `ClientMain` alone 163 colour literals in 101 distinct values — which is
how the shop, the HUD and the rebirth page ended up looking like three
different products. All of them now `require(Theme)` and, where they used to
declare a colour, declare an alias instead: `ShopStyle.INK`, `ClientMain`'s
`GOLD`/`INK`/`PANEL`/`GOOD`/`WARN`, and so on all point at `Theme` values so
that the 300-odd call sites reading them never had to change. Only two things
still hold their own colour literals: the arrest scene's deliberately separate
dark world, and the handful of 3D viewport lighting values that Theme has no
opinion about.

- **A 3px warm-black outline on everything (`Theme.outline`).** The single
  difference between a flat rectangle and something that reads as drawn, and
  it gives a pale card an edge against bright grass. *Everything* means the
  buttons too — the rebirth button and the three `makeActionButton` controls
  each used to carry a pale tint of their own fill instead, which is a
  highlight rather than an edge. A GuiObject takes exactly one `UIStroke`, so
  anything that also wants a glow puts it in a sibling frame behind itself,
  never in a child: under `ZIndexBehavior.Sibling` a child always draws above
  its parent and would wash out the line.
- **One warm axis, not two.** Every neutral in `Theme` — the outline, the
  wells (`Theme.SLAB`/`SLAB_DEEP`), the panel ground (`Theme.SAND`/`SAND_DEEP`,
  for any large surface like the shop panel), and the card (`Theme.PAPER`/
  `PAPER_DEEP`) — sits on one hue band. A cold grey dropped into this set reads
  as a mistake even without a number attached.
- **Gloss is a `UIGradient`**, because there are no image assets — real texture
  means an upload, and uploads get moderated. `Theme.gloss` bakes a fixed
  top/bottom pair into a surface; `Theme.shade` *multiplies* the background
  rather than replacing it, so it shades without touching the hue. Two things
  need `shade` rather than `gloss`: a surface whose colour is written at
  runtime (the street banner repaints itself every frame it flashes), and any
  surface printing **dark type on a saturated fill** — a gloss running to a
  deep stop puts the label on a ground far darker than its `BackgroundColor3`,
  and that is invisible to a naive contrast probe. The audit evaluates the
  gradient at each label's own vertical position for exactly this reason.
- **`Theme.readable(tone, against)` now works in both directions.** It darkens
  a tone until it clears a 4.5 contrast ratio on a light ground, and *lifts*
  one — value up, saturation eased off — on a dark one. It only used to darken,
  which was backwards for a tone read against an icon well: asked for a
  readable colour against `Theme.SLAB` it returned a darker one, making the
  read worse. The four accents actually used as text (`GOOD`, `WARN`, `STOP`,
  `GOLD`, plus `COOL`) are pre-solved once as `Theme.GOOD_INK` /
  `WARN_INK` / `STOP_INK` / `GOLD_INK` / `COOL_INK`, so a call site sitting on
  paper doesn't run the 24-step search itself.
- **`Theme.MUTED_LIGHT`** is the second half of secondary text — `Theme.MUTED`
  reads on paper, `MUTED_LIGHT` reads on a dark well — because one colour
  cannot be "secondary" against both grounds at once.

Colour still carries meaning; it just stopped being the ground. A tone is the
chip ring, the stripe, the heading and the hold bar.

**Gold means money; pink means the pig — and both go on OBJECTS, never under
them.** `Theme.GOLD` is the coin badge's drawn coin and every price;
`Theme.PIG` is the drawn snout on the piggy bank panel and the piggy shop tab.
Both HUD readouts in the top corners are `Theme.card` paper with a drawn mark
on them (`Theme.coin`, `Theme.snout`) rather than a panel painted in the
accent — the piggy bank panel used to be a solid block of pink, which read as
pink rather than as a pig and left its own progress bar with no pink to be
drawn in. `Theme.PIG_DEEP` is that bar's empty half and exists to show the
gold fill sitting in it; it is measured against both fills, not one.
`Theme.PRESTIGE` is rebirth's own deep plum — it used to borrow
`HUE.effects`, a colour whose only job is to name a shop tab. It is the one
surface in the game that goes DARK and prints cream: a light version was
tried and could carry neither its own label nor its gold star chip, since a
mid-tone carries small type of neither polarity. The HUD button and the
page's confirm button are the same control in two places and are built to
match — same fill, radius, ink outline and sparkle.
Painting a whole panel in either would spend the accent on square footage
instead of meaning, which is why any large ground uses the neutral
`Theme.SAND` instead (see below). `Theme.coin` draws the coin from three
nested frames rather than typesetting the coin emoji, which rendered at 19px,
ignored `TextColor3` like every emoji, and was unreadable.

**Every catalogue tab owns a hue, and that table now lives in `Theme.HUE`, not
`ShopStyle`.** It moved because the shop stopped being the only thing drawing
it — the same aliasing that hit `ShopStyle`'s neutrals hit its nine category
colours. A tab, the shelf card that jumps to it, and the header it lands on
are all one colour, so "the pink one" is a usable instruction before a player
can reliably read "ACCESSORIES".

The hues are built as one family — a fixed saturation, and a lower value in
the green band, where green and lime read much brighter than red and blue at
the same number. On top of that they carry one constraint that is **not**
cosmetic: **every hue has to be able to carry ink type**, because a shelf card
is a block of its own colour with its name printed on it. That is the check to
run before adding or retuning one.

The whole HUD and shop is audited by walking the live tree and comparing every
visible label against its own painted ancestor — 4.5 for body, 3.0 for large
or `TextScaled` type. Measured after this pass: **425 labels, zero below
floor**, the tightest body pair at 4.65 and the tightest large pair at 3.51.
Two rules the probe needs or it lies: skip non-ASCII glyphs, since an emoji
carries its own colours and ignores `TextColor3`; and treat a `TextScaled`
label as large, since it reports a `TextSize` of 8 while rendering at several
times that.

**The shop's ground moved from its own cold navy, to pink, to a neutral —
three revisions, and the neutral is the settled one.** `ShopStyle` no longer
holds a palette at all: every name it exports (`INK`, `BASE`, `CARD`, `SUNK`,
`TEXT`, `LIGHT`, `MUTED`, `GOLD`, `GOOD`, `STOP`, `HUE`) is an alias for a
`Theme` value, and only the four card-state tints (`OWNED`/`BUY`/`DEAR`/
`LOCKED`) are still literals — each one an accent lifted toward `Theme.PAPER`
rather than a hand-picked colour. The panel (`ShopStyle.BASE`) is
`Theme.SAND`, the same neutral any large panel uses; a shop card
(`ShopStyle.CARD`) is `Theme.PAPER`, byte-identical to a HUD toast card. That
is most of what "consistent" means here: opening the shop no longer changes
which game you are looking at.

**`Config.luau` still requires nothing — it stays pure data — but its tones
follow `Theme`'s accent family by *rule*, not by reference.** A comment at the
top of the file states the derivation `Config.NOTIFY`, `Config.PROMPTS` and
`Config.RARITIES` are built to: saturation 0.72, value 0.90 (0.82 in the
green/lime band, hue 80–200, which reads brighter at the same value), and it
names the handful of tones that deliberately sit off that rule — gold is a
material rather than a category, so it stays at full value; the prank glyph is
pulled back from a pure magenta; hiding is a deliberate neutral; the shop door
and the alien-recovery prompt are moved off `GOOD`'s own green so four
different meanings are not one colour. A new tone is chosen by the rule, not
picked to look right next to its neighbours.

Applied to: the coin badge (a gold badge with a coin pip, not a dark panel
with gold text), the piggy bank panel, the toast cards, the carry banner, the
street banner, and every interaction prompt.

---

### Interaction prompts

Every ProximityPrompt in the game is drawn by `Shared/PromptUI` from a kind in
`Config.PROMPTS` — a tone, a glyph and a word. They used to be Roblox's
default grey pill, identical for all seven actions.

| kind | word | glyph | tone | where |
|---|---|---|---|---|
| `collect` | BANK COINS | 🏦 | gold | your own piggy |
| `steal` | STEAL | 💰 | red | somebody else's |
| `tag` | TAG THIEF | 🚨 | amber | a thief carrying loot |
| `hide` | HIDE | 🗑 | slate | a wheelie bin |
| `dig` | OPEN IT | 👀 | orange | a bin with somebody in it |
| `shop` | SHOP | 🛒 | green | the four shop doors |
| `recover` | RECOVER | 👽 | alien green | a downed raid drone |

- **Colour is never the only signal** — every card carries the word and the
  glyph too, the same rule the rarity borders follow.
- **Tones are borrowed from `Config.NOTIFY`**, so an action and the toast it
  produces are the same colour.
- **The hold bar shows the real duration**, and over
  `Config.PROMPT_COUNTDOWN_OVER` seconds it adds a countdown — the HUD half of
  the problem the vault dial solves from the street.
- Two prompts share a part in two places (piggy: collect/steal, bin:
  hide/dig). The game already guarantees they are mutually exclusive, so no
  card ever stacks.

---

## 15. Monetization and compliance

**Coins are never purchasable with Robux, at any price, ever.** That single
rule — not the earned-only tokens that came before it — is what now keeps every
coin sink in the game, including the two coin chests in §3, outside Roblox's
paid-random-item regulation. It can only be broken once: the day a coin pack
ships, every chest in the game becomes a regulated loot box retroactively, with
nothing in this repo having changed. See §3 for the full argument.

**Monetization is named things, never currency.** A Robux purchase may grant a
ride, a pass or a stance — never a coin, a token or a chest. Granting a named
thing mints no currency and feeds no roll; granting currency would put a price
on however that currency gets spent, including randomly.

**Shippable today:** the **Style Pack** game pass (riding stances). It confers
nothing, cannot be aimed at anybody, and a pose is the safest possible thing to
put in front of this audience.

**Rules that are not negotiable:**

- **A Robux purchase may grant an ITEM, never its coin value.** Granting a named
  thing mints no coins and feeds no roll.
- **A game pass is buyable from the store page, outside the game**, so nothing
  may assume the buyer already owned something. The Style Pack also grants the
  *entry* ride (the cheapest, never the matching one) when the buyer owns none —
  self-clearing, so it needs no bookkeeping.
- **An unset pass id UNLOCKS what it gates**, and warns at startup. Locking
  content no purchase can reach is indistinguishable from a broken feature and
  cannot be noticed from inside the game.
- **A failed ownership check is not a NO.** Leave the cache entry absent so the
  next ask retries; writing `false` on a network blip takes a paid feature away
  from someone who owns it.
- **Locked content is SENT to the client, never filtered out.** The shop is
  where something you do not own is supposed to be advertised.

**The rebirth skin drop is the one open question left.** It is random, it is
*not* purchased, but the gate in front of it is banked coins — so once coins
could in principle be earned faster by any future paid mechanic, money would
buy a faster route to a random outcome even though it never buys the outcome
itself. Weaker than the case the coin-pack ban already closes, and the next
thing to look at if that ban is ever revisited.

**Audio licensing:** prefer **Pro Sound Effects** (a library Roblox licensed
wholesale). The Creator Store is full of "free" effects lifted from Minecraft and
Undertale — free there means costing no Robux, not cleared.

**Original art only.** Every meme lawn ornament, the patrol car, the arrest
screen and the training hood are built as originals rather than as the named
thing, because moderation strips branded assets and **the penalty lands on the
experience, not the one prop**. What carries a joke is the *layout*, and a layout
is a genre rather than a property.

---

## 16. Dev tools

**F2** opens the admin panel. Admission is the `Config.ADMINS` allowlist,
**checked on the server before a single argument is read** — the RemoteEvent
exists for every player whether or not their panel was built, so hiding a button
protects nothing.

`AdminPanel.MENU` is a **table**, grouped by what you are testing rather than by
which service owns it. Adding a command is one row.

A command may target another player by userId (resolved **server-side** from the
live player list); `reset` is self-only, because every other command is undone by
pressing another button and a wiped save is not.

---

## 17. Known gaps

- **The chest system is fully built and wired, and still has no shop UI.**
  `Config.CHESTS` (five chests), `Config.COMBINE`, `Config.chestPool`,
  `ChestService.open`/`.combine`, the `ChestOpen`/`ChestCombine`/`ChestResult`/
  `ChestState` remotes and `data.shards` are all real, and `Main` wires
  `ChestService` and registers its balance pushers. `ClientMain` never fires
  `ChestOpen` or `ChestCombine` from anywhere — there is no chest tab and no
  card for one on the front page — so the admin panel's `chest`/`combine` dev
  commands are the only way a human can reach any of this today. The 12
  accessories tagged `chest = "gear"` are the identical 12 the roll already
  draws from, so once a chest tab ships, the two will offer the same items
  through two different currencies until one is retired.
- **Tokens have moved onto event loot for `alien` specifically, and nowhere
  else.** `Config.CHESTS.alien` is a real token-priced chest drawing on the
  alien set, alongside the set's existing medal prices — but it is one more
  chest with no UI (above), so it is exactly as unreachable as the coin
  chests. `CosmeticsService.rollAccessory` is untouched and is still the only
  thing a player can actually spend tokens on today: it still charges tokens
  per accessory, one at a time, no duplicates, exactly as before.
- **Anything needing two players is unproven**: the chase, lock-vs-lockpick
  timing, the guard dog catch, friend bonus, revenge markers, the Golden Bone's
  chase-break, hiding while carrying, and being tipped out of a bin by somebody
  else.
- **Pointer gestures cannot be synthesised here.** The MCP mouse tool does not
  land where it is aimed and `VirtualInputManager` refuses the keyboard, so the
  hot bar drag, the rebirth button's `Activated`, and the held-item click are all
  verified *either side* of the gesture and never through it.
- **No audio has been listened to.** Every claim about the ride sounds is
  reasoned from asset metadata and confirmed by measurement. Somebody has to put
  headphones on.
- **The music toggle lives in the shop header**, which is the wrong place and is
  written down as a stopgap in the source.

`CLAUDE.md`'s "Not yet verified" section is the long-form version of this list
and is kept in more detail.
