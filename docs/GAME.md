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

A shared-economy PvP game for an **under-12 audience**, about robbing.

Every player owns one of eight plots on a suburban street. On the plot is a
**piggy bank** that fills with coins over time, and **the piggy bank is the
wallet**: there is one balance, all of it is in the pig, and all of it can be
taken. Other players can walk onto your lawn, crack your lock and carry a slice
of it home — and you can do the same to them, and **stolen coins count double**
once they are home. Every plot nobody has claimed carries a **resident**
instead of standing empty — a named neighbour with a real, growing piggy bank
— so there is always somebody worth robbing, even alone (§5).

Two upgrade trees compete: **defence** (fence, guard dog, vault lock) buys the
victim *time*, never immunity; **offence** (lockpicks, bigger sack, speed boots)
buys the thief speed and volume. Neither can ever close the other out.

The loop, in one line: **accrue → spend (or get robbed) → rob → rebirth →
collect cosmetics.**

> **Direction (September 2026): the robbing pivot.** The game as first built
> was an idle game with a robbery bolted on, and the arithmetic paid players to
> camp — a perfect steal at level 20 earned less than a minute of idle income
> and risked three times that. The pivot makes robbing the game: the pig is the
> only wallet, the thief's reward is decoupled from the victim's loss, a second
> currency (**loot**) comes only from robbing, revenge pays extra, and the join
> shield is short. Events, chests and sets are frozen until this is clear and
> bug free. The reasoning is in `CLAUDE.md` under *The robbing pivot*; the
> pitch-level version is `docs/design-doc.html#pivot`.

### The three rules everything else is built on

1. **The server owns all state.** The client renders the last `StateUpdate` and
   never computes a balance.
2. **A robbery costs minutes of income and never costs progress.** Everything
   in the pig is stealable, but a victim can lose at most a quarter of it in
   an hour (`Config.LOSS_CAP`), and anything *spent* — an upgrade, a house, a
   skin — is gone from the pig and permanently safe. This is what keeps the
   game from being a bullying simulator.
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

**`GrassTuft.luau` is also in `Shared`, for a different reason.** Nothing
renders grass in a shop. It lives there because two *services* plant it —
`PlotService` on the lawns, `NeighborhoodService` on the verge — and its
template mesh comes from `InsertService:CreateMeshPartAsync`, which yields;
one shared cache means one web call for the asset and one place that can say
how tall a tuft is, instead of two that could disagree (§11).

**`ClientMain` is one chunk and sits near Luau's 200-local ceiling.** A new HUD
feature goes in a `local function buildX() … end` (a function body gets its own
register file, so the chunk pays one local instead of twenty) or in its own
module. `AdminPanel`, `SpinWheel`, `RaidFX`, `HouseFX` and `Rebirth` are modules
for exactly this reason.

---

## 3. Currencies

There are **two**. Which one buys what used to be a legal question as much as
a design one; it no longer is, because neither can be bought with Robux, at
any price, ever.

| | Field | Earned by | Buys | Purchasable with Robux? |
|---|---|---|---|---|
| **Coins** | `data.coins` — the piggy bank, all of it stealable | idle accrual (stops at capacity), delivering a robbery (**counts double**, triple on revenge), dailies, events, **selling a chest-duplicate spare** (`Config.SELL`, below) | upgrades, skins, effects, houses, decorations, rides, consumables, and **chests** (below) | **never, at any price** |
| **Loot** | `data.loot` | **delivering a robbery** (`Config.LOOT`), and attending events when they return | the accessory roll (`Config.ROLL_CURRENCY`), set items, and the `alien` event chest — all three are live in the shop (the roll, and now the **Crates** tab's OPEN button); see §17 for what the Crates tab still cannot do | **never, at any price** |

**Medals and tokens are retired into loot.** `data.medals` and `data.tokens`
were merged into `data.loot` one-for-one at schema 17. The daily ladder pays
coins and boosts and no loot: loot is the currency you go out and earn.
Chest duplicates are a separate, chest-internal currency — see **spares**,
below.

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
`animal` and `neon` — 13 skins each) and one on loot (`alien`, an **event**
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
the collection rule stated in §9. A duplicate becomes a **spare** of that
*item* in the same reveal rather than a dead outcome — `data.spares` is a
count **per item**, keyed `"kind:key"` (`Config.chestEntry(chestKey, entry)`
is the one place that knows the grammar both ways — a bare key for an
ordinary chest, `"kind:key"` for a `kind = "set"` one — and `ChestService`'s
own `entryKey` builds a spare's storage key the same way), not a counter per
tier. `Config.COMBINE` still pools spares **by tier** when combining — any
three commons make a rare roll, whatever items they are — so a duplicate out
of a finished chest is still fuel for one barely started, with a small chance
of climbing two or three tiers in one combine. **Combining spends only on coin
chests**, never on `alien`, so a rich player cannot grind their way into event
loot without ever attending an event. Effects have no chest: there are too few
priced tiers to spread across rarities, so effects stay direct-purchase.

**A spare has two exits: combine it, or sell it for coins.**
`ChestService.sell` (remote `SpareSell`) pays `Config.sellValue(kind, key)`
per copy — the tier's coin value off the inverse `Config.RARITIES` weight,
**capped at `Config.SELL.priceFraction` of the item's own coin cost** where it
has one, so buying something in the shop and selling it straight back can
never turn a profit. **You may sell your last copy of an item, not only
spares** — the one guard is `SetService.inUse`, which refuses only the copy
currently equipped/worn/placed, so an accidental sale of the thing a player is
looking at is the failure this stops, not a lock on the mechanic itself.
Selling the last copy runs through `SetService.revoke`, the exact inverse of
`grant` (pushes the item's own service and the set panel, saves immediately —
spares alone are not saved per-sale, same as a chest open, see §13). A sale
that would overflow the pig's capacity is **refused outright, never clamped
and never partially filled** — the "spend it or lose it" pig rule (§4) applied
to a payout instead of an accrual.

**`alien` is the first event chest**, bought with loot rather than coins and
drawing on the same alien **set** (§8) that loot already unlocks item-by-item
— a `kind = "set"` chest is a gamble sitting *beside* the guaranteed loot
price, never a replacement for it. Duplicates from it still produce spares,
which is a small thank-you for attending; those spares can be **sold** but
cannot be **combined** back into `alien` — only into a coin chest.

**`ChestService` is built and wired end to end, and two of its three remotes
now have a real front door.** `ChestService.open`, `.combine` and `.sell` are
real, the `ChestOpen` / `ChestCombine` / `SpareSell` / `ChestResult` /
`ChestState` remotes are live, `Main` starts the service and registers
`EconomyService.push` and `CosmeticsService.push` as its balance pushers, and
`data.spares` is a real save field (`Config.SCHEMA_VERSION` 18).
`Shared/Crates.luau` (§14) fires `ChestOpen` from a real card button and
renders `ChestState` / `ChestResult`; **`Shared/Inventory.luau`** (§14) — the
one place a player can see every spare they hold, since a chest reveal shows
only the one item just opened — fires `SpareSell` from a real card button.
**`ChestCombine` still has none**: nothing in `ClientMain` fires it, so
combining remains reachable only through the admin panel's `chest` /
`combine` dev commands. The plan is to put a COMBINE control on the `Crates`
tab's own cards, since a combine rolls into a specific coin chest. See §17.

`Config.isSellable` does not know which catalogues can actually carry a
spare — it admits anything with a coin `cost`, so a ride or a decoration
(neither of which any chest can ever duplicate) shows a SELL button too, and
selling one is a genuine, un-refused last-copy sale through the same
`SetService.revoke` path a skin or accessory uses. Recorded as a known gap in
§17, not fixed.

### Why medals and tokens became one currency

Medals (attendance pay) and tokens (the accessory roll's earn-only currency,
invented so the roll could never be sped up with Robux-bought coins) were two
earned-only currencies doing overlapping jobs, plus spare duplicates from
chests doing a third. A nine-year-old cannot hold three. **The robbing pivot
merged `data.medals` and `data.tokens` into `data.loot` one-for-one at schema
17** (spares stay separate — they are chest-internal, and sell for coins
rather than for loot). `Config.MEDALS` and
`Config.TOKENS` are gone; every catalogue item that used to price in either
now prices `loot = N`, and `Config.ROLL_CURRENCY` — still the one table a
rename would touch — is named **Loot**.

**Loot's job as an earn-only currency didn't disappear, it just has a new
first source.** Coins can never be bought with Robux at all, so loot no longer
needs to exist to keep the roll uncatchable by money — but it still is one:
robbing (`Config.LOOT.delivery` per delivery, §5) is now the primary source,
and events pay the old medal shape when they resolve (`Config.LOOT.event`:
`attend` for everybody present, `perDrone` for drones you personally knocked
down, `cleared` shared by the whole street, `setComplete` as a fallback payout
once a player already owns the whole set). **The daily ladder pays none** —
loot is the currency you go out and earn, not one you collect for logging in.

**One grant path:** `SetService.award(player, amount, why)` — the *only* place
loot is credited. `why` is optional and nil means silent, which is how a
delivery or an event folds loot into its own toast instead of firing a second
one. It pushes both the set panel and every registered **loot pusher**
(`SetService.registerLootPusher`, filled by `Main` with
`CosmeticsService.push`, which carries the roll button's balance) — so a
balance can never move without both of its readers being told.
`Config.lootWord(n)` is the singular/plural helper.

**Where the numbers live:** `Config.ROLL_CURRENCY`, `Config.LOOT`,
`Config.ROLL_BASE_COST` / `ROLL_GROWTH`, `Config.CHESTS` / `Config.COMBINE`,
and `Config.SELL` (spare sale value).

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

**Every rung is clamped to a fraction of the pig that has to pay for it.**
`CAPACITY_COST_GROWTH`(`_B`) and `INCOME_COST_GROWTH`(`_B`) each outrun the
value curve they buy, so left uncapped the price of a rung eventually exceeds
the size of the pig it has to be paid out of — measured, that happened at
capacity level 17 of 20, which left 20 of 40 capacity rungs and 9 of 40 income
rungs unbuyable by earning at all, made the rebirth gate unreachable, and
deadlocked an idle-only player. `getIncomeCost`/`getCapacityCost` now
`math.min` the geometric curve against `Config.UPGRADE_COST_CEILING` (a
fraction, income looser than capacity so income stays the cheaper rung) times
`Config.getCapacity` at the level being left — so *"a rung never costs more
than the pig that pays for it"* is true by construction rather than by
tuning. The clamp only bites late (capacity level 16, income level 20
onward), so early-game prices are unchanged and the first rebirth is still
~2.3 hours of play.

**`Config.auditEconomy()` is the safety net for every other price in the
game.** It walks both ladders over every reachable level, all nine priced
catalogues against the largest pig the game can ever produce
(`getCapacity(ABSOLUTE_MAX_LEVEL)`), and every rebirth gate, and returns
anything nobody could ever afford — a mispriced item fails exactly like a
locked one, a button that never lights. `Main` runs it once at startup and
warns (never throws) once per problem, in Studio as well as live; it currently
returns none. It caught the Sky Castle: `Config.HOUSE_TIERS`' top tier was
repriced **100,000,000 → 80,000,000**, because the largest pig the game can
produce is 96.9M and the old price was not slow, it was impossible.

**Read the ceiling through `Config.maxLevel(rebirths)`, never from a constant.**
It is `20 + 2 per rebirth`, capped at 40. `EconomyService` pushes its answer as
`maxIncome`/`maxCapacity` and the client draws the ladder from those, so both
ends agree by construction.

### Rebirth

Wipes income, capacity and **both upgrade trees**. Keeps everything cosmetic —
skins, effects, houses, decorations, accessories, gear, rides, loot and bones.

- **The gate is a multiple of your reachable capacity**, not a flat number. A
  flat gate evaporates as the economy grows (measured: 334 seconds of income the
  first time you cap the ladder, eight seconds by rebirth 10) and a geometric one
  diverges into a wall. Capacity rides the same curve the player's economy rides,
  so it can do neither. The multiple is **1** since the pivot — *"fill your piggy
  bank"* — because income alone can never carry the pig past capacity now that
  the pig is the only wallet; robbing is how you get there faster. Simulated
  against the real ladder and gate functions — no robbing, no offline accrual,
  no dailies — a pure idler now reaches rebirth 10 / level 40 in about **1.4
  days** of continuous play, roughly 17 days at two hours a day.
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

### Full

Income stops at capacity and there is no bank to empty the pig into. The way
to make room is to **spend** — or to be robbed. Anything delivered from a
robbery, a daily or an event may overflow capacity; income never does.

**Where the numbers live:** `Config.BASE_INCOME`, `BASE_CAPACITY`,
`INCOME_GROWTH`(`_B`), `CAPACITY_GROWTH`(`_B`), the matching `*_COST_GROWTH`,
`UPGRADE_COST_CEILING`, `BAND_TOP`, `ABSOLUTE_MAX_LEVEL`, `LEVELS_PER_REBIRTH`,
`REBIRTH_MULTIPLIER`, `REBIRTH_CAPACITY_MULTIPLE`, `OFFLINE_CAP_SECONDS`,
`FRIEND_BONUS_*`.

---

## 5. The heist

The whole risk of this game lives in **the run home**.

**A victim is a player or a resident.** Every plot nobody has claimed carries
a `ResidentService.Resident`: a name (`Config.getResidentName`, indexed by
plot so a house keeps its identity across an owner arriving and leaving), a
piggy bank holding `Config.RESIDENTS.pigSeconds` of its own income and accruing
on the same `Config.getIncomeRate`/`getCapacity` curves a player uses, and
fence/dog/lock/house levels derived from a level of its own. `ResidentService`
seats one at startup and whenever a plot is released, and evicts it the
instant a player claims that plot (`PlotService.onClaim`/`.onRelease` — a
registry hook rather than a require, the same shape as `registerBounceVeto`).

**Residents vary across the street rather than being seated identically.**
Each one rolls a fixed `offset` — a *negative* number of levels below the
server's average `incomeLevel` (`currentLevel()`), never above it — and keeps
that offset for as long as it stands, so the whole row rises together as
players level up rather than converging on one number the moment anybody
does. `pickOffset` (`Config.RESIDENTS.levelSpread`, 6) guarantees
`easyCount` (2) houses seated at the bottom of the spread, for a player with
no upgrades, and at least one at the top of it (offset 0) — **downward only,
and load-bearing**: a resident's pig is `pigSeconds` of its *own* income, so
one level above the thief is worth `INCOME_GROWTH` more, and a thief always
robs the richest house on offer. Measured against `Config.auditRobbery`'s own
ceiling, a single level above parity takes a maxed spree from 8.25x idling to
11.14x (15.03x at +2), so the peer-level house is the **ceiling** of the
street, never a rung in the middle of it — which is also the plot
`auditRobbery` itself measures, so guaranteeing one keeps the audited street
and the real one the same street. A richer resident also carries a fuller
**garden**: a shuffled, per-resident order over every lawn-zone key in
`Config.DECOR_ITEMS` (`rollGarden`), planted as a growing *prefix* of that
order as the resident's level climbs (`decorPerLevels`/`decorMax`, the same
per-level shape as its fence/dog/lock/house ladders) — so a bare lawn reads as
the bottom of the street and a crowded one as the best-paying, best-defended
plot on it, readable before a thief ever crosses the road.

`HeistService` is written against `Target = Player | ResidentService.Resident`
rather than `Player`; `typeof(t) == "Instance"` is the whole discriminator, so
nothing else in the file branches on which kind it has. **A resident is a
resource, never a rival:** no `Config.LOSS_CAP`, no revenge marker, no
notification, no place on the Richest Piggies or Most Wanted boards — but the
take, the crack, the carry penalty, the getaway, the dog, the tag, the patrol
and the rap sheet are all identical to robbing a player, and a delivery
against one still counts toward Most Wanted (§7). That is what makes the
whole heist loop reachable by a single player.

1. **Walk onto a lawn.** A guard dog watches it (`HeistService.watchLawns`,
   polling ten times a second): **asleep** in its kennel while its owner is
   away — which is what makes an unclaimed plot a resident's own to defend —
   or **patrolling awake** whenever the owner is home, and that posture is
   itself a tell readable from the pavement. Either way it wakes for the
   loudest trespasser on **noise**, never on presence alone — standing still
   is never a crime: **footsteps** above the breed's own `notice` speed
   (`Config.DOG_TIERS`, measured between ticks, never read off `WalkSpeed`),
   or a **missed slice mid-crack** (below). A thief may **tiptoe** (`C`, or
   the SNEAK button) to keep footsteps under `notice`: a movement mode, not a
   disguise — `Config.TIPTOE`/`Config.getTiptoeMultiplier` is one more factor
   inside `HeistService.currentSpeed`, buyable up to level 4 by the
   **Sneakers** offence rung (below — it buys *speed* for the approach, never
   stealth; which dogs a given tiptoe still wakes is the dog tier's own
   `notice`), and refused outright while carrying or climbing (either
   combined with a tiptoe would let the getaway itself go quiet).
2. **Crack the lock.** A flat half-second hold (`Config.CRACK.openHold`) opens
   the attempt; everything after that is a **push-your-luck minigame**, not a
   duration — `Config.CRACK`, drawn by `Shared/Crack.luau`. A marker sweeps a
   dial and tapping (`F`, or the panel's own button) while it sits inside the
   moving target zone lands a **slice**: a growing share of the victim's pig
   (`Config.getCrackSlice`, scaled by the thief's Bigger Sack), taken out of
   the pig the instant it lands rather than promised for later. Up to
   `Config.CRACK.maxSteps` (five) slices per attempt, each worth more than the
   last and each with a **narrower window** to land it
   (`Config.getCrackWindow` — tightened by the victim's Vault Lock, widened by
   the thief's Lockpicks). A thief may bail at any point — `Escape`, or the
   STOP button — and **keeps whatever has already been banked**; a missed tap
   ends the attempt the same way, banked coins and all. `HeistService.crackTap`
   / `.crackStop` / `.isCracking` run the whole thing server-side; the client
   reports a tap with no claim about whether it landed. **A missed slice, and
   only a missed slice, sounds the alarm**
   (`Config.CRACK_ALARM_ON_MISS`) — it tells the victim they're being robbed
   and releases the guard dog (below); a clean run banks every slice in total
   silence.
3. **Carry.** You move at `CARRY_SPEED_MULTIPLIER` of base, and a banner says so
   to the whole street. Rides are disabled **server-wide** while loot is in
   transit — otherwise a bystander on a scrambler runs down a thief on foot.
4. **Deliver** to your own drop-off, or **get tagged** and lose it.

**A dog that has been alerted — woken by footsteps or by a missed slice, it is
the same release either way (`HeistService.releaseDog`) — branches first on
whether its owner is home.** Owner home: the dog is the **alarm, not the
enforcer** — `GuardDog.bark` sounds (the same bark either way it happens, so
the tell for which one this is stays the dog's *posture*, read before
committing rather than by ear) and `markIntruder`, a local in `HeistService`
that `GuardDog` has no business knowing about, puts a Highlight
(`DogMark`, the alarm tone) on the thief for `Config.DOG_WATCH.alertSeconds`,
refreshed rather than stacked on repeated noise; both sides are notified and
the dog does **not** give chase — two things that can both hard-stop one
thief on one lawn is how a plot becomes a wall, and the owner standing right
there is the first one. Owner away — always true for a resident, which is
what keeps every unclaimed plot dangerous — the dog is the enforcer and
**branches again on whether the thief is holding anything**: caught carrying
loot from an earlier landed slice, a thief is **tagged** exactly as if a
player had caught them; caught with nothing in hand — walking up before ever
cracking a lock, or a clean run that has already delivered — a thief is
**scared off** instead (`HeistService.scare`): there is no loot to drop, so
the cost is `Config.DOG_WATCH.scareStun` seconds held still and the crack
they were mid-way through, nothing more. Being robbed must stay survivable;
so must failing to rob.

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

**What a delivery pays.** The victim loses the sum of every slice landed during
the crack — `Config.getCrackFraction`, each slice scaled by the thief's Bigger
Sack — taken out of their pig per slice as it lands, never as one lump at the
end (two thieves cracking the same pig can't both be promised the same
coins). The thief banks that running total times `Config.HEIST_PAYOUT` on
delivery — the extra is minted by the game, which is what lets robbing be the
best earning rate on the street without a robbery being devastating. Every
delivery also pays `Config.LOOT.delivery` loot (§3). Robbing somebody who
robbed *you* inside `Config.REVENGE.window` pays `Config.REVENGE.payout` times
instead and an extra `Config.REVENGE.loot`; the marker over their plot lasts
the same window. `Config.STEAL_FRACTION` survives only as the calibration
baseline the crack's slices are measured against — the old flat take lands
between the second and third slice of a clean run — and as the sack-scaling
factor inside `Config.getStealFraction`.

**Consecutive deliveries are worth more, and it is the only thing in the game
that varies *between* robberies rather than within one.** `SocialService`
keeps a `spree` table — steps and a timestamp, keyed by player — deliberately
separate from `heat`, the rap sheet: `heat` only ever rises and ranks Most
Wanted (§7), while a spree counts consecutive deliveries, **decays** after
`Config.SPREE.window` seconds with no delivery (checked lazily on read, no
timer of its own), and is spent by any arrest. `HeistService.deliver`
multiplies `payout` by `SocialService.getSpreeMultiplier(thief)` — read
*before* `SocialService.recordSteal` bumps the count, so the delivery that
starts a run pays the plain rate and the one after it pays more
(`Config.getSpreePayout`, up to `Config.SPREE.maxSteps` steps for up to
double) — and the delivery toast names the run once it is more than one
delivery long. The same step count scales the pursuit floor down
(`Config.getSpreeFloorScale`, §7): a run is paid for in the risk half of the
game the patrol already owns, not in a new hazard.

Caps that keep it survivable: `STEAL_COOLDOWN` (per thief per victim, and only
starts once at least one slice has been banked — a first tap that misses costs
nothing and starts no cooldown), `Config.LOSS_CAP` (a victim loses at most that
fraction of their pig per rolling window, whoever is doing the robbing — a
slice worth nothing because the allowance ran out ends the attempt outright
rather than landing for free; **a resident has none**, see above), and the
shield: `Config.JOIN_SHIELD` on every join,
`Config.NEW_PLAYER_SHIELD` on a player's **first session only**
(`data.sessions == 1`). `NEW_PLAYER_SHIELD` is a **ceiling**, not a guaranteed
duration — `HeistService.dropShield` ends it the instant that player completes
their own first grab (on the grab, not the delivery), so a player chooses the
moment they become a target rather than waiting one out. There is no lifetime
per-victim cap — `STEAL_MAX_PER_VICTIM` is retired.

A robbed piggy wears a **plaster** for `Config.ROBBED_MARK_SECONDS`
(`PiggyBank.setRobbed`, published as `Config.PLOT_ROBBED_ATTRIBUTE`). It is a
tell and nothing else: visible, temporary, and it costs the victim nothing.

**`RobBadge` (`Shared/RobBadge.luau`) hangs a billboard over every piggy.** It
used to only ever show a negative — no badge meant robbable — on the argument
that eight badges all advertising themselves is wallpaper. **That rule is
reversed now:** a robbable pig carries its own contents in gold
(`Config.formatCoins`), because which pig is worth crossing the road for is
the whole decision a thief makes from the pavement, and "no badge" told them
nothing about that. A refusal still wins over the figure, checked in the same
order as `HeistService.whyCannotSteal`: the victim's new-player shield, your
own per-victim cooldown, an empty vault. Nothing shows over an unclaimed plot
or your own, and a resident's plot reads exactly like a player's — the vault
comes from the same `Config.PLOT_VAULT_ATTRIBUTE` either way, and eligibility
from `Config.PLOT_RESIDENT_ID_ATTRIBUTE`/`OwnerUserId`, whichever is set. It
is per-viewer because the cooldown is per thief-per-victim: each client learns
its own cooldowns from the `StealCooldown` RemoteEvent (fired to the thief on
a completed grab, carrying the victim's id — negative for a resident, see
above — and an expiry in `workspace:GetServerTimeNow()` seconds) and reads the
shield off `Config.PLAYER_SHIELD_ATTRIBUTE`, an attribute on the **Player**
instance (zeroed by `HeistService.openSeason`; a resident has none). A module,
not a section of `ClientMain`, for the usual 200-local-ceiling reason;
`ClientMain` starts it with one statement holding no local.

**`Config.auditRobbery()` checks that robbing is worth doing at all.** It
measures a full clean crack against a *resident* (never a player —
`Config.LOSS_CAP` caps that on purpose) at every level/rebirth pair, an hour
of that against an hour of standing still, and asserts the ratio sits inside
`Config.ROBBERY_ADVANTAGE` (a min/max band) and stays **constant** across the
whole game (a `spread` ceiling) — the same invariant `RESIDENTS.pigSeconds`
exists to pin, so a later change that lets the ratio drift (a resident's pig
re-tied to a growing curve, a crack step retuned, the getaway distance moved)
shows up here instead of silently. **It sweeps both ends of the spree ladder**
— a *cold* thief (no run going, `steps = 0`) against the band's floor, and a
*hot* one (a maxed spree) against its ceiling — because the two answer
different questions (is robbing ever worth it; is the best case a faucet) and
measuring only one lets the other drift with nothing to say so, which is
exactly what a spree multiplying an unmeasured payout would do. It also checks
a thief can't lap every resident on the street faster than `STEAL_COOLDOWN`
allows, which would make the measured ratio optimistic. `Main` warns per
problem at startup, in Studio as well as live — the same shape as
`auditEconomy`/`auditFences` (§4, §11).

### Defence tree — buys time, never immunity

| | Effect | Ceiling |
|---|---|---|
| **Fence** | Slows and hazards a crossing | **Solid — the gate is the only free way across.** `Config.BASE_JUMP_HEIGHT` is **5.5**: tiers 1–2 (Rickety 3.6, White Picket 4.8) are jumpable; tiers 3–5 (Barbed Wire, Electric, Moat — all top 7.0) are not, and there is no built-in way over one. A gate (24 studs wide at tier 1, down to 8 at tier 5) always exists |
| **Guard Dog** | **Watches the lawn** (`HeistService.watchLawns`) and wakes for footsteps above the breed's `notice` speed or a **missed crack slice**; asleep-in-kennel vs. patrolling-awake is a visible tell for whether the owner is home. **Owner home: alarm only** — barks and marks the thief, never chases. **Owner away (always true for a resident): the enforcer** — chases and tags a carrying thief, or scares off an empty-handed one | Beaten by bones, or a tiptoe kept under `notice`; three breeds with rising `boneResist` |
| **Vault Lock** | Narrows the crack's target windows (`Config.getCrackWindow`) | Readable from the street as a vault dial — a hatch in the piggy's back, with level 0 an open hole. Readable from *any distance* by a thief with maxed Lockpicks — see **casing**, below |

**The permanent climbing trellis is retired — a fence is solid now.** Every
segment used to carry a built-in `TrussPart` at the segment's midpoint, which
meant every fence, including the cheapest tier, had a free way over it built
in: a fence was a slower floor rather than a wall. `PlotService.buildFence`
no longer builds one. The only crossing a segment offers on its own is
whatever `Config.isHoppableFence` already allows; going over anything taller
means bringing a **Ladder** (§6).

**Whether a tier is hoppable is a fact about three numbers**, checked by
`Config.isHoppableFence`/`Config.isClimbedFence` and enforced at startup by
`Config.auditFences` (`Main` warns on any tier that fails both): the jump,
the tier's `top`, and `Config.LAWN_LIFT` — the stud the lawn stands above the
ground the fence is built on. A tier has to clear the jump from **both**
sides or from **neither**; tiers 3–5 went from `top` 6.0 to 7.0 for exactly
this reason; at 6.0 they were hoppable *out* of a yard (lawn side) but not
*into* one (street side), which handed a free getaway on the tier that costs
the most to buy.

**The Ladder is a placed climbing point, not a new control.**
`PlotService.placeLadder(player)` reads the caller's own character position —
no coordinate on the wire, unlike a thrown bone or gadget — projects it onto
the nearest fence `Barrier` segment (segments publish `AlongX`/`Span`
attributes for exactly this), clamped off the segment's own ends by
`Config.LADDER.margin`, and refuses a tier `Config.isClimbedFence` says is
already hoppable. It stands for `Config.LADDER.seconds`, fading over the last
`Config.LADDER.fade`, straddles the fence so it serves both ways over, and
placing a new one retires the placer's previous one. `ThiefModel.buildLadder`
is the one geometry shown in the shop, in the hand and on the fence; what
actually climbs is an invisible `TrussPart` inside it, sized to the fence's
own `top` plus `Config.LADDER.overhang` so there is something to mantle onto.

A climbing player moves at `Config.CLIMB_SPEED_RATIO` (the engine's own
climb-to-WalkSpeed ratio) times `Config.CLIMB_MULTIPLIER`, and that factor
stacks with carrying, snags and stuns the same way a ride multiplier does —
`HeistService.currentSpeed` asks the humanoid's own state, so nothing about
carrying, a fence snag or a stun needs to know climbing exists separately.
`Config.climbSeconds(height, speed)` is what a tier costs to cross. *Orientation
only:* a 7.0-stud fence is about 1.8s free and 2.4s carrying.

### Offence tree

**Lockpicks** (wider crack windows), **Bigger Sack** (bigger slices — scales
every step of the crack, not a single flat take), **Speed Boots** (carry
speed, **capped at ×1.0** so they never exceed base), **Sneakers** — the
fourth and last rung, `Config.UPGRADES.tiptoe` — buys **speed for the
tiptoe approach, never stealth**: sneak speed climbs `Config.TIPTOE.base` to
`.max` across 4 levels (`Config.getTiptoeMultiplier`, fed by
`UpgradeService.getLevel(player, "tiptoe")`), and which dogs a given tiptoe
still wakes is entirely the dog tier's own `notice` — this rung never touches
that.

**Maxed Lockpicks also hands over "casing" — the first upgrade in the game
that is a verb rather than a number.** Every other rung is a rate: faster,
more, cheaper, slower for someone else. `Config.canCase(lockpickLevel)`
(true once the level reaches that upgrade's own `.max`, so the threshold is
*derived from the rung count*, the same move `TIPTOE.max` uses) lets a player
read any plot's **Vault Lock tier from the pavement** — drawn as a four-pip
ladder on the rob badge (§14) rather than printed as a number, since a
maxed rung is meant to change which pig you walk toward rather than add one
more thing to read. It is *added at the rung*, never swapped in for what
Lockpicks already did — the crack windows still widen at every level exactly
as before — so there is no migration and no player's save changes shape.
This is also the one thing that restores what moving the Vault Lock to a
hatch under the cape (the table above, and `PiggyBank`) took away: the dial's
own metal used to carry its tier from the street for everybody; casing gives
that reading back to the one player who bought the right to it.

**Where the numbers live:** `Config.UPGRADES`, `FENCE_TIERS`, `DOG_TIERS`,
`CRACK` (`getCrackSlice`/`getCrackFraction`/`getCrackTotal`/`getCrackWindow`),
`CRACK_ALARM_ON_MISS`, `STEAL_*` (including `STEAL_FRACTION`, the crack's
calibration baseline), `TAG_*`,
`CARRY_SPEED_MULTIPLIER`, `HEIST_PAYOUT`, `LOOT`, `LOSS_CAP`, `REVENGE`,
`NEW_PLAYER_SHIELD`, `JOIN_SHIELD`, `ROBBED_MARK_SECONDS`,
`PLOT_ROBBED_ATTRIBUTE`, `BASE_JUMP_HEIGHT`, `LAWN_LIFT`, `CLIMB_SPEED_RATIO`,
`CLIMB_MULTIPLIER`, `LADDER`, `RESIDENTS`, `PLOT_RESIDENT_ATTRIBUTE`,
`PLOT_RESIDENT_ID_ATTRIBUTE`, `TIPTOE`, `PLAYER_FIRST_JOB_ATTRIBUTE`,
`DOG_WATCH` (`pollRate`, `wakeDelay`, `alertSeconds`, `scareStun` — all live,
read by `HeistService.watchLawns`/`.scare`), `ROBBERY_ADVANTAGE` (the audit
above), `SPREE` (`window`, `maxSteps`, `payoutPerStep`,
`floorDropPerStep` — `getSpreePayout`/`getSpreeFloorScale`), `CASING`
(`Config.canCase`) and `PLOT_LOCK_ATTRIBUTE` (the plot's Vault Lock tier,
published once by `PlotService.setLockLevel` and read by both the rob badge
and the steal prompt's own label).

---

## 6. Consumables and the hot bar

Four catalogues, one gesture: **hold a stock, pick one, use it.**

| Catalogue | Config | What it counters |
|---|---|---|
| **Bones** | `Config.BONES` | The guard dog. Cheap bones bounce off Guard Duty; only the Golden Bone interrupts a chase |
| **Gadgets** | `Config.GADGETS` | Maxed Speed Boots. Range *falls* as power rises, so the decisive one cannot reach a thief who already got clear |
| **Home items** | `Config.HOME_ITEMS` | Guard Duty Treat, Garden Sprinkler (a joke, deliberately toothless), Patrol Radio |
| **Thief kit** | `Config.THIEF_KIT` | **Ladder** — the fence itself, now that no fence has a built-in way over (§5); **Raincoat** — sheds the two cheap gadgets, admits the Zapper |

**Cheap counters bounce, the expensive one gets through — on both sides.** Each
raises the *price* of beating someone rather than making them unbeatable.

### The bar itself

- **An item is HELD before it is used.** Selecting is free (a number key or a
  tap asks the server to *draw* something); only a deliberate click out in the
  world spends it. This exists for two reasons: a stray thumb should not spend a
  30,000-coin Golden Bone, and **a thief walking up a driveway holding a Golden
  Bone is information** the defender can read off the lawn.
- **The click sends no position — with one deliberate exception.** `BoneThrow`
  and `GadgetThrow` carry a key and nothing else; the server picks the target
  from its own positions. The **Ladder** is the odd one out: `PlotService`
  reads the *caller's own character position* instead, because "anywhere along
  the fence" is the whole appeal and a coordinate on the wire would be one to
  forge. You choose the spot by standing there; the click still only ever
  means "use it".
- **Keys are fixed per item and never renumbered to fill gaps.** A player may
  *drag* to rearrange — position is the only handle a touch player has — but the
  game never silently moves a binding underneath them.
- **Shelving hides a slot and never destroys stock.** There is no stock cap
  anywhere, so a destroy button would only delete something already paid for.

**Key map:** `Q` dodge / trick · `C` sneak (tiptoe, §5) · `F` tap the crack
dial (§5) · `B` shop · `V` garage · `R` radio · `I` bag/inventory (§14) ·
`Esc` close (also bails a crack, banking whatever it has) · `F2` admin ·
`1`–`0` hot bar. *`G` is free.* A new binding gets checked against this list
and against whether it is genuinely exclusive with what it lands on.

---

## 7. The police

**The only risk in the game that belongs to nobody.** Every other risk is the
victim's — their dog, their fence, their lock — which leaves a hole no purchase
can close: robbing an offline player is otherwise completely free.

- **Published.** The siren sounds fifteen seconds before the car appears and the
  HUD counts both clocks, so robbing during a patrol is a *choice* rather than
  bad luck — and bad luck is not something a nine-year-old can get better at.
- **Commits to one pursuit.** A live robbery always wins; otherwise the officer
  goes for the **pursuit target** (below) — the Most Wanted, but only once
  their sheet clears their own income floor.
- **The officer runs at 14.5**, between a carrying thief's 12 and a free
  player's 16 — so *delivering* is the answer, and nothing in the patrol exceeds
  `BASE_WALK_SPEED`.
- **Bail is 3× what was taken, capped at whatever the thief actually has.**
  There is only one balance now (§3), so bail comes out of it directly. Being
  caught can cost an afternoon of idle income and can never cost a house, a
  skin or an upgrade — nothing spent is ever at risk.
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
piggy. **A player's own sheet is a standing HUD chip now** (`Shared/Wanted.luau`,
§14) — hidden until they have stolen anything, then STOLEN / WANTED / HUNTED
as their sheet crosses the board's leader and the pursuit floor below.

**Robbing a resident (§5) counts exactly like robbing a player.** `deliver`
credits the rap sheet off what was taken regardless of which kind of victim it
came from, so a single player can build a sheet, get chased, get arrested and
escape without anybody else in the server — the loop this section describes
no longer needs a second person to exist.

**The spree is momentum, not record — a second, separate piece of per-player
state alongside the rap sheet.** `SocialService` keeps a `spree` table (steps
and a timestamp) that counts consecutive deliveries within
`Config.SPREE.window` seconds of each other and expires lazily on read; it is
never conflated with `heat` above, which only ever rises. Landing a delivery
pays more (`Config.getSpreePayout`, §5) and **lowers the pursuit floor**
(`Config.getSpreeFloorScale` — up to `Config.SPREE.maxSteps` steps drops the
floor to a fifth of resting, never further), so a thief working fast draws a
records check on a smaller sheet than the same thief taking their time. Any
arrest — not only a most-wanted one — calls `SocialService.breakSpree`, unlike
`SocialService.clearHeat` (§14), which fires only on a most-wanted bust: a rap
sheet is what you did and an ordinary bust doesn't undo it, but a spree is
momentum and being put in a car plainly ends it. The player's own rap-sheet
chip (§14) draws the run as a row of pips under the sheet figure.

**The name on the board and the officer's target are two different
questions, answered by two different functions.** `SocialService.getMostWanted`
is the poster: the single biggest rap sheet in the server, full stop — no
floor. `SocialService.getPursuitTarget` is the same player, but only if their
sheet also clears `wantedFloor` (their own income rate ×
`Config.POLICE.wantedFloorSeconds`, scaled down by the spree above); otherwise
nil. The floor is evaluated
**once per refresh, about the winner only** — never as a filter over who gets
to lead — and cached in a module-local so it cannot disagree with the hat the
street can see. `PoliceService` reads `getPursuitTarget` at both sites that
matter (the "They're out looking for YOU" warning, and picking who the patrol
goes for); `AdminService`'s `mostwanted` command and the physical poster read
`getMostWanted`. A leader below the floor gets *"You are MOST WANTED. Take
more and the patrol will come."*; one above it gets *"…The next patrol comes
for you."*, which also fires the moment a sitting leader's sheet crosses the
floor without the board changing hands.

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

**Rewards:** coins (income-seconds), **loot** (`Config.LOOT.event`), and a
**set drop**. Loot for the Alien Invasion is `attend` (everybody present) plus
`perDrone` for every drone *you* personally knocked down, plus a shared
`cleared` bonus if the street downed every one of them — the co-operative
bonus pays the people who did nothing too, on purpose, or the incentive would
be to let a neighbour fail. Rush Hour, the cheap continuous event, pays only
`attend`. The coin reward may overflow a full piggy bank, same as any other
delivery (§4); loot has no capacity to overflow.

**Sets** are a **view over the existing catalogues**, never a new catalogue.
`Config.SETS` lists `{kind, key}` pairs pointing at ordinary members of `SKINS`,
`EFFECTS`, `ACCESSORIES`, `DECOR_ITEMS` and `RIDES`. No new ownership storage, no
new equip path. **`set` is an exclusion** and is load-bearing in four places — it
keeps set items out of the accessory roll, out of the rebirth drop pool, and out
of both free-if-costless fallbacks.

**Nothing is ever locked behind luck.** Every set item carries a loot price, so
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
| **Skins** | `SKINS` | coins, or granted by rebirth — **heading toward crate-only, below** | Animated skins are driven **on the client** from a `SkinKey` attribute. 41 of 46 also carry a `chest` tag (17 `classics`, 13 `animal`, 13 `neon`) — see §3 |
| **Effects** | `EFFECTS` | coins — **deliberately not moving to a chest** | Shop tiles *simulate* the real particle numbers — a ViewportFrame renders BaseParts and nothing else. The 5 priced tiers (15K–600K) land 3 commons and 2 rares on `Config.RARITY_BANDS` with no epic or legendary, so a chest would have no top end |
| **Houses** | `HOUSE_TIERS` | coins | Bought as a ladder (`houseLevel`), worn as a shelf (`houseShown`) — move back into any tier free, forever |
| **Decorations** | `DECOR_ITEMS` | coins | Auto-placed into slots; **slots are scarcer than items** on purpose |
| **Accessories** | `ACCESSORIES` | **loot, by rolling, or from the `gear` crate** | Four slots, all worn at once. 12 also carry `chest = "gear"` — the same 12 the roll draws from, now reachable through two different currencies until one is retired — see §3, §17 |
| **Rides** | `RIDES` | coins | Street only; a ride confers nothing else |
| **Player gear** | `GEAR` | earned only | Most Wanted escapes |
| **Stances** | in `RIDES` | **Robux (Style Pack)** | The one cosmetic shaped to be sold directly |

**Skins are heading crate-only, and that is a deliberate reversal of "nothing
is ever locked behind luck" for this one catalogue.** Once cut over, most
skins stop being a guaranteed coin purchase and become a chest outcome only —
a duplicate becomes a spare rather than nothing, but there stops being a way
to walk up to the shop and buy the exact one you want. **Prices stay in
Config regardless**: `Config.rarityOf` derives a skin's chest tier from its
`cost`, and `Config.sellValue` caps a spare's payout at a fraction of that
same `cost` — remove the price and both the chest tiers and the sell cap
collapse. The legal position is unchanged either way: coins still can never
be bought with Robux (§15), so a chest that only ever charges coins is still
not a regulated paid random item, luck or no luck.

**Not yet cut over.** `CosmeticsService.buySkin` and the shop's own Piggy tab
still sell every non-rebirth, non-set skin for coins exactly as before this
decision — there is no `crateOnly` flag anywhere in `Config`. The decision is
written down today only in comments (`Inventory.luau`, the shop's tab rail)
and in one piece of built UI: the Inventory panel's empty-skins message reads
*"Open a crate to start collecting skins"* rather than pointing at a shop
tab. See §17.

### The roll

The older of the two random-outcome mechanics, and the one every collection
rule in this section was originally written against. It predates the coin
chests in §3 and is untouched by them — a chest opened from the Crates tab is
a second, parallel random outcome with the opposite collection rule (§3:
duplicates are allowed there, and produce a spare).

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
  because a `hash://` id cannot replicate. Every one of them also needs an
  UPLOADED asset id in `Config.ANIMATIONS`: `RegisterKeyframeSequence` is
  Studio-only, so a pose with no id plays in Studio and not on the live site.
  `RidePose.animationKeys()` is the authoritative list of keys that want one —
  a style, its trick, and **the same pair per stance** (`scrambler@onehand`),
  since the published style carries the stance. `Config.animationKeys(rideKeys)`
  takes that list rather than deriving its own; `Main` warns at startup for any
  key with no id, and the `animdump` admin command builds them all for
  publishing. A stance with no id falls back to the plain pose for that ride
  rather than to no pose at all.
- **Move the bike to the hand, never the hand to the bike.** Poses are measured
  on a live rig, then the ride's grips and pedals are placed at what came back.
  A real bicycle does not fit a Roblox character.
- **A stance is an override, never a whole pose**, merged one level into `left`
  and `right`.
- **A trick is driven by the machine, never by a clock** — `RidePose.phaseOf`
  reads the chassis each frame, so the rider cannot desync from the bike.

**Speed table (orientation only — `Config` is authoritative):** base 16 ·
carrying 12 · dogs 12 / 14.5 / 17 · officer 14.5 · fence snags ×0.80 → ×0.30 ·
electric stun 0 · climbing ×`CLIMB_SPEED_RATIO`×`CLIMB_MULTIPLIER` (§5) ·
tiptoe ×`Config.getTiptoeMultiplier(level)` — `Config.TIPTOE.base` to `.max`
across the Sneakers rung, §5 — refused while carrying or climbing.
**Anything that makes a player faster than 16 invalidates several systems at
once.**

`HeistService.refreshSpeed` also sets `Humanoid.UseJumpPower = false` on every
call — a rig defaults to `true`, under which `JumpPower` governs and
`JumpHeight` (and therefore `Config.BASE_JUMP_HEIGHT` and the stunned
`JumpHeight = 0`) is stored and silently ignored. It is called once on spawn as
well as on every speed-changing event, so a fresh character's jump is correct
from the first frame.

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

### The ground and the grove

The world ground, every plot's `Base` and `Yard`, and the hills (mounds and
the tunnel banks) are **flat** — `Enum.Material.SmoothPlastic`, no texture.
`Config.GRASS_MATERIAL` is a two-field pair, `material` and `name` (a
`MaterialVariant` to lay over it, or `""` for none, currently empty), read by
`WorldService`, `PlotService` and `NeighborhoodService` alike, so switching
the whole street between flat ground and any future textured one is those two
lines and nothing else. **A dangling `name` is safe** — a `MaterialVariant`
naming something that does not exist falls back to the part's own
`BaseMaterial`, so nothing errors if a variant is ever removed.

**A generated painted-grass variant shipped first and was dropped.** Twelve
candidates were compared against the shipped `LAWN` colour and none of them
read as *cartoon* — every one read as a good photograph of a lawn. Worse, a
`MaterialVariant` **multiplies** `Part.Color`, so every candidate pulled the
bright, pastel `LAWN` tint down into a muddy olive; the flat slab was the only
option in the comparison still showing the actual colour. Generating them also
got the account that made them moderated (later overturned on appeal) — a
repo pointing at a moderated asset is a liability on its own, separate from
how the texture looked. If a variant is ever reinstated, note that
`MaterialVariant` properties are plugin-gated and cannot be created at
runtime, so it has to ship as a Rojo-synced asset file rather than a script
assembling it at server start.

The grove behind the plots is **generated tree meshes**, not the original box
trunk with a ball balanced on it. `Config.TREE_MESH`/`Config.treeMesh()` hold
a trunk and a canopy mesh id, a texture id for each, and a handful of uniform
scales; `NeighborhoodService.ensureTreeTemplates` builds the two meshes once
and clones them per tree, tinting each canopy one of two near-white
multiplies. **A tree keeps its baked texture**, unlike the piggy mesh (whose
texture is stripped so forty-plus skins can multiply a flat colour onto it) —
nothing skins a tree, so there is no multiply-tint system for a painted mesh
to go muddy against, and the baked shading between leaf clumps is what makes
the canopy read as clumps at all. A blank id in `Config.TREE_MESH`
falls back to the original box-and-ball builder rather than to a missing tree.

**A canopy's reach is measured by its diagonal, not its depth, because every
tree carries its own yaw for variety** — `NeighborhoodService.canopyReach` —
and `buildTrees` clamps each tree's jittered depth against that reach so a
canopy can never stand over a back fence, the same shape as the fence-height
audits elsewhere in this section: the guarantee is a clamp, not a row depth
that happens to be big enough today. *Orientation only — measured live, not a
`Config` value:* worst canopy clearance past a fence line is currently about
7.5 studs.

**A flat ground is a bare colour field, and the tufts are the whole of what
makes it read as a lawn rather than a slab.** From standing height a plane
reads as a plane however it is coloured — what sells a stylised lawn is
*silhouette*: blades breaking the line where the ground meets everything
standing on it. `Shared/GrassTuft.luau` plants the actual clumps that stand up
out of the ground, on the plot lawns and along the verge. Going flat is only
affordable because these exist — `Config.GRASS_TUFT.perStuds` (density) went
up to compensate for the ground no longer carrying any texture of its own.

- **The template is built once and cloned.** `GrassTuft.template()` calls
  `InsertService:CreateMeshPartAsync` for one generated MeshPart (box
  collision, `Automatic` render fidelity — there are hundreds of these, so
  shedding triangles with distance is exactly what should happen; the piggy is
  `Precise` for the opposite reason) and assigns the texture afterwards,
  because that call does not carry one. `Config.GRASS_TUFT`/`Config.grassTuft()`
  holds the mesh and texture ids, the tuft's natural size, a `minScale`/
  `maxScale` pair, `perStuds` (density — one tuft per that many square studs),
  a sink distance, and two near-white multiply tints. A nil id blanks the grass
  and changes nothing else, the same fallback the lawn material itself follows.
- **`GrassTuft.scatterRect(topCFrame, width, depth, parent, seed, accept)`
  takes a surface's own CFrame, not plot-local numbers**, so
  `GrassTuft.scatterOn(surface, parent, seed, accept)` — what both planters
  actually call — is correct under any rotation for free. `PlotService.buildPlot`
  plants into a `Grass` folder on both the `Base` and `Yard` parts *before* the
  model's closing `PivotTo`, so the turn that flips the far row carries every
  tuft with it. No veto is needed on a plot: the driveway runs in plot-local z
  entirely in front of the lawn, and a tier-5 moat sits outboard of the fence
  ring, so neither ever reaches this grass.
- **`NeighborhoodService.buildVergeGrass`** scatters the verge band instead,
  derived from what is already standing on it — outboard of the lamp posts and
  wheelie bins on the verge line, inboard of the boards and shopfronts behind
  it — on both sides, with a driveway veto: a driveway *crosses* that band at
  every plot column, where on a plot it never touches the lawn at all.
- **Every tuft is `Anchored`, and `CanCollide`/`CanQuery`/`CastShadow` are all
  false** — the rule the rest of `NeighborhoodService` and every lawn ornament
  already follow, and it matters more here than anywhere else because there
  are hundreds of them: one that collided would body-block a chase on the
  exact ground a chase happens on.

*Orientation only — measured live, not a `Config` value:* 819 tufts stand
across the street against a world of 2,428 `BasePart`s, at 0.73–1.35 studs
tall, none on a driveway slab and none breaking the collide/query/shadow/anchor
rule. A tier-5 moat against the LAWN grass has not been
measured — see §17.

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
| `PlotService` | Plot pool, fences, ladders, driveways, ownership, signs — publishes `onClaim`/`onRelease` hooks |
| `ResidentService` | The NPC neighbour seated on every plot nobody owns — a name, a seeded pig, and defences/garden that track the server's average level plus a fixed, per-resident downward offset (§5) |
| `PiggyBank` | The piggy model, coin pile, skins, effects, vault dial, the robbed plaster |
| `GuardDog` | Patrol, kennel, guard duty, the off-duty nap, and the awake/asleep posture that tells a thief whether the owner is home. Exposes `isOwnerHome`/`bark` so `HeistService` can drive the alarm-only branch without `GuardDog` knowing anything about players (§5) |
| `BoneService` | Thrown bones |
| `EconomyService` | Accrual loop, milestones, the `StateUpdate` push (fires whenever the whole-coin balance changes) |
| `UpgradeService` | Both upgrade trees |
| `HeistService` | The crack (§5), carrying, tagging, delivering, the loss cap, revenge, the dodge, tiptoe, and the lawn watch (`watchLawns`) that wakes a guard dog on footsteps or a missed slice — against a `Target` of a player **or** a resident. `releaseDog` is where a wake decides alarm-only (owner home) versus a chase (owner away); `markIntruder`, a `HeistService`-local, marks the alarmed thief with a Highlight — see §5 |
| `CosmeticsService` | Buying and equipping everything cosmetic; **the roll**, priced in loot |
| `ProgressionService` | Rebirth |
| `SocialService` | Friend bonus, leaderboards, Most Wanted board, revenge markers, the per-player rap sheet push (`pushWanted`, remote `WantedState`, §14), and the spree — consecutive-delivery payout/pursuit-floor state (`recordSteal`/`breakSpree`), kept in a table separate from the rap sheet on purpose (§5, §7) |
| `PoliceService` | Patrol schedule, pursuit, arrest, the radio |
| `EventService` | The event roster |
| `SetService` | Loot, sets, the drop reel, ownership lookups shared with chests (`owns`, `inUse`, `grant`, `revoke`) |
| `ChestService` | Opening chests, combining per-item spares by tier, selling spares for coins (leaf: requires `DataService`, `SetService`) — opening (Crates tab) and selling (Inventory panel) are reachable; combining is not, see §17 |
| `DailyService` | The daily ladder and boosts |
| `RideService` | Mount gate, welds, tricks |
| `StealthService` | Bins, hiding, and the thief kit (Ladder, Raincoat) |
| `HeldItemService` | What is in a player's hand (**a leaf** — requires only `DataService`) |
| `GadgetService`, `HomeService` | The two remaining consumable catalogues |
| `PassService` | Game pass ownership, cached per session |
| `SettingsService` | The one thing a client may write |
| `AdminService` | Owner-only dev console (F2) |

**Cycles are broken with registries, not with requires.** `SetService.registerPusher`,
`HeldItemService`'s vetoes and `ChestService.registerBalancePusher` are all filled
in by `Main`, which keeps each service's dependency list at one line and makes a
cycle impossible rather than merely absent today. `PlotService.onClaim`/
`.onRelease` are the same shape from the other direction: `ResidentService`
requires `PlotService` and calls these directly, so `PlotService` never has to
require `ResidentService` back to seat or evict a neighbour.

---

## 13. Persistence

`Config.SCHEMA_VERSION` — bumped whenever a field is added.
`DataService.reconcile` fills in fields added by later versions **one level
deep** without touching existing values, so a new field that defaults to zero or
an empty table needs no migration branch at all. Real migrations (renames,
rescaling) branch on `envelope.schema`. **Schema 17** is the robbing pivot's:
`vault` merges into `coins` (one stealable balance, §3) and `medals` plus
`tokens` merge one-for-one into `loot` — real renames, so both branch on
`envelope.schema` and run before the generic fill, consuming the old fields
rather than leaving them beside a zeroed new one. `data.sessions` (incremented
once per join) needed no branch at all: it is a plain new field defaulting to
0, which is what distinguishes it in the save from a rename — and it is what
`NEW_PLAYER_SHIELD` (first session only) reads to tell itself apart from the
shorter `JOIN_SHIELD` every login gets after that (§5).

**Schema 18** retired `data.shards` (a counter per rarity tier) for
`data.spares` (a count per *item*, keyed `"kind:key"`) — the chest system's
duplicate currency moved from per-tier to per-item, §3. This one is a **drop**,
not a rename: a tier counter cannot say which item it came from, so
`reconcile` sets `data.shards = nil` and grants nothing back. Safe because
nothing was lost — there was no chest UI at any point `shards` existed, so the
only copies that ever existed came from the admin console.

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

- **The HUD.** There is exactly **one money readout**: the piggy bank panel,
  top right. It carries a drawn snout, the balance, the income rate and a fill
  bar whose label names the capacity (`of 3.0M`) — or says `FULL` and what to
  do about it, since a full pig stops earning. The separate top-centre coin
  badge was merged into it when the pivot left the two printing the same
  number. Top-centre is now rebirth, the carry banner and the patrol banner,
  with 16..90 free where the badge stood. Bottom-right holds **SHOP** and,
  stacked above it, a **bag toggle** (🎒 STUFF, `I`) that opens the standalone
  inventory panel below — the corner grew from a single button when Inventory
  turned out to belong beside the shop rather than inside it. The income and
  capacity purchases that used to sit above both are rows in the shop's
  Upgrades tab now. Bottom-left is four rows deep and the fifth control went
  *sideways* rather than up. `IgnoreGuiInset` is on, so y=0 is *under* the
  Roblox topbar.
- **The shop.** An eight-tab rail (Everything, Upgrades, Piggy, Home, Rides,
  Items, Worn, **Crates**) over a front page — the Everything tab — whose
  9-cell grid (`1/3 × 1/3`) is exactly full: all seven cosmetic shelves plus
  **Defend / Rob** and **Crates**, one card each, on one screen with no
  scrolling. Cards render the **real 3D item**. The tab rail is a
  `ScrollingFrame` — a fixed one silently ate two whole tabs, because a
  `UIListLayout` does not clip and does not error — and each tab is now
  **sized to its own label** (`TextService:GetTextSize`), because a flat
  102px-per-tab width that fit seven tabs left the eighth sitting off the edge
  of the rail, reachable only by scrolling. **Inventory is deliberately not a
  ninth tab** — it was one for about an hour, overflowed the rail (eight tabs
  measure 692px of a 772px window and it wanted about 98 more), and putting
  "look at what you own" behind the button that means "go and spend" argued
  against the whole point of splitting Crates from Inventory in the first
  place; see the Inventory bullet below. The **Upgrades** tab is the one tab
  that changes an outcome: a
  full-width **EARN** band (Earn Faster, Bigger Piggy Bank — the income and
  capacity purchases) sits above two columns, **DEFEND** and **ROB**, one card
  per upgrade tree. All eight rows share one card builder (`makeUpgradeCard`);
  the six tree cards show a pip ladder and the two EARN cards show a
  continuous bar reading `Lv N / M`, because income and capacity run to
  `Config.maxLevel` (up to 40) where pips would be unreadable.
- **Crates.** `Shared/Crates.luau` is the shop tab that finally reaches
  `ChestService` — a card per chest, each with three real item previews
  (best tier first), a stacked odds bar drawn to the server's own
  renormalised `ChestState` percentages (a tier's share prints inside its own
  segment only once the segment is wide enough to hold it), and an OPEN
  button that greys when the price can't be afforded and re-lights on its
  own. A finished chest keeps opening — the blurb swaps to say every roll
  from here on is a spare, never a dead end. The reveal reuses **`SpinWheel`**,
  the same reel the event drop already used, generalised with three optional
  fields (`title`, `subtitle`, `note`) rather than forking a second one — the
  event drop's own call is untouched, and `note` is where a chest's "Spare ·
  sells for N" line goes. Opening is reachable from here; combining is not
  — see §17.
- **Inventory — a standalone panel, not a shop tab.** `Shared/Inventory.luau`
  is the mirror of Crates and never shows a price — that is the property the
  module exists to protect. **Crates is how you *get* a cosmetic; Inventory is
  what you *have*.** It lived behind the shop's rail for about an hour and was
  moved out: a shop tab is where you go to spend, and this is where you go to
  look at what you already own, so it is its own full-screen panel (`I`, or
  the bag toggle beside SHOP) built to the shop panel's own geometry — same
  scale, corner and close button — and the two are **mutually exclusive**,
  opening one closes the other. It lists every **owned** item across the five
  wearable/placeable catalogues (skins, effects, accessories, decor, rides),
  one card each: the real rendered model, a rarity stroke, a spare-count chip
  showing the *total* copies held (one spare reads `x2`), a WEAR/WEARING
  toggle and a SELL button. Wearing fires the shop's own `CosmeticRequest`
  (`RideRequest` for a ride) rather than a second equip path; selling fires
  `SpareSell` — the same remote the admin console's `spares` command already
  used, now with a player-reachable caller (§3, §17). A locked item is never
  shown — an empty section names where to go and get one instead, the same
  rule that keeps a locked tile out of a Most Wanted or Style Pack advert
  (§7, §15).
- **The crack panel.** `Shared/Crack.luau` draws the one moment in this game
  where standing still is the point (§5): a gauge showing the victim's pig
  draining as slices are banked, with `Config.LOSS_CAP`'s remaining allowance
  drawn as a line across it, and a dial — a marker sweeping a track with a
  moving target zone, narrower each step. Pushed entirely by the server on
  `CrackState`; the panel decides nothing and the client's `CrackTap` carries
  no argument at all. `F` taps, `Escape` (or the STOP button) bails and banks
  whatever has landed so far. Opened by the steal prompt's own flat
  `Config.CRACK.openHold` hold; the piggy's prompt now shows what is **in**
  the pig rather than a computed take, since there is no longer one flat
  number a hold could quote.
- **Notifications.** Nine *kinds* in `Config.NOTIFY`, each a colour, glyph,
  sound and hold. Toasts **stack**, each owns its own clock, and the hold is a
  function of how much there is to read. The three urgent kinds flash the screen
  edges.
- **Physical boards.** The leaderboard and the Most Wanted poster are objects in
  the world at *both* ends of the street, not HUD panels — the physicality is the
  mechanic. `SurfaceGui` culls by distance from the **character**, not the camera.
- **The rap sheet chip.** `Shared/Wanted.luau` is the second chip in the
  top-right column, directly under the standing event countdown chip (176×46
  at y 196, the same 8px gap the countdown leaves under the piggy bank panel)
  — the top-centre column is *alerts*, this corner is *standing readouts*. The
  chip grew 12px taller for a **pip row** showing the spree (§5, §7): the
  badge/caption/amount row already spends all 176 pixels, so the run gets its
  own row underneath rather than competing for space in the first one — gold
  pips for steps taken, `Theme.SAND_DEEP` grooves for steps not, sized
  `1/Config.SPREE.maxSteps` of the row the same way the upgrade pips size
  themselves. Pushed per player by `SocialService.pushWanted` (remote
  `WantedState`): on the board's own `Config.LEADERBOARD_REFRESH` tick, and
  immediately inside `recordSteal` (a delivery), `clearHeat` (an arrest
  clearing the sheet) and `breakSpree` (any arrest ending a run, whether or
  not it clears the sheet). Payload is five fields — `sheet`, `isLeader`,
  `hunted`, `spree`, `spreeMax` — nothing the chip has no reader for. Hidden
  until the player's own sheet is above zero, then captions STOLEN / WANTED /
  HUNTED with the escalation carried entirely by the badge ring (muted → gold
  once the poster has your name → red once your sheet also clears your own
  pursuit floor, §7 — itself scaled down by the spree). Started from
  `ClientMain` in one statement holding no local, the same shape as `FirstJob`
  and `Crack`.
- **Rob badges.** A billboard over each piggy bank, per-viewer, built by
  `Shared/RobBadge.luau` (not part of the HUD panel stack). It used to only
  ever refuse — no badge meant robbable; it now shows the pig's own contents
  in gold on a robbable pig, and a refusal (see §5) otherwise. Reads a
  resident's plot exactly like a player's. **A viewer with maxed Lockpicks
  gets a second row: a four-pip ladder naming that plot's Vault Lock tier**
  (`Config.canCase`, §5) — filled pips in `Theme.STOP`, empty ones
  `Theme.SAND_DEEP`, the same groove colour an unbought upgrade pip already
  uses. It only shows beside a gold figure, never over a shielded, cooled-down
  or empty pig — a refusal is already the answer there, so a lock reading
  would answer a question nobody asked. The badge itself grows by one row
  (`CARD_H` to `CARD_H + LOCK_ROW`) rather than the ladder floating separately.
  The viewer's own Lockpicks level rides in on `UpgradeState`, the same push
  the shop's tree rows read, so the badge and the card selling the rung can
  never disagree about whether it is owned.
- **Onboarding.** `Shared/FirstJob.luau` is the whole tutorial, one sentence:
  a card at top centre reading *"Your piggy bank is empty. Go and rob a
  neighbour!"* plus a gold highlight on the nearest robbable pig — usually a
  resident's (§5). Driven by `Config.PLAYER_FIRST_JOB_ATTRIBUTE`, derived from
  `data.totalStolen` rather than a new save field, and it retires for good,
  this session and every future one, on a player's first delivery.
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
them.** `Theme.GOLD` is the piggy bank bar's fill and every price;
`Theme.PIG` is the drawn snout on the piggy bank panel and the piggy shop tab.
The one HUD money readout is `Theme.card` paper with a drawn mark on it
(`Theme.snout`) rather than a panel painted in the accent — the same fix the
coin badge got before it merged in (`Theme.coin` survives on the rebirth
page) — the piggy bank panel used to be a solid block of pink, which read as
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

Applied to: the piggy bank panel (paper with a drawn snout and a gold bar,
not a block of pink or a dark panel with gold text), the toast cards, the
carry banner, the street banner, every interaction prompt, and both physical
boards — the leaderboard and the Most Wanted poster are a printed paper sheet
inset on their own timber, built by `SocialService` on the server from the
same `Theme`. They were the one interface the original repaint missed, because
that sweep covered the client UI files and these build UI from a service.

---

### Interaction prompts

Every ProximityPrompt in the game is drawn by `Shared/PromptUI` from a kind in
`Config.PROMPTS` — a tone, a glyph and a word. They used to be Roblox's
default grey pill, identical for every action.

| kind | word | glyph | tone | where |
|---|---|---|---|---|
| `steal` | Crack Lock | 💰 | red | anybody's piggy but your own — opens the crack (§5), it no longer completes a robbery by itself |
| `tag` | TAG THIEF | 🚨 | amber | a thief carrying loot |
| `hide` | HIDE | 🗑 | slate | a wheelie bin |
| `dig` | OPEN IT | 👀 | orange | a bin with somebody in it |
| `shop` | SHOP | 🛒 | green | the four shop doors |
| `recover` | RECOVER | 👽 | alien green | a downed raid drone |

**`Config.PROMPTS.collect` is a dead entry.** There is no collect/bank action
since the pivot — the pig is the wallet and nothing is banked (§4) — so
`EconomyService.collect`, the `CollectRequest` remote and the piggy's
`CollectPrompt` are all gone. The table row survives in Config, unread by
anything; only `steal` now lives on a piggy, enabled for everybody but its
owner.

**`tag` is never offered to the one player it would tag.** It is welded to a
carrying thief's own root so every *other* player can reach it, which also
puts the thief permanently at distance zero from their own prompt.
`PromptUI` disables the prompt on the thief's own client the instant loot is
welded to them, and `HeistService.tag` refuses a self-tag server-side
regardless — a forged self-tag would otherwise return the loot to the victim
and stun the thief for nothing.

- **Colour is never the only signal** — every card carries the word and the
  glyph too, the same rule the rarity borders follow.
- **Tones are borrowed from `Config.NOTIFY`**, so an action and the toast it
  produces are the same colour.
- **The hold bar shows the real duration**, and over
  `Config.PROMPT_COUNTDOWN_OVER` seconds it adds a countdown — the HUD half of
  the problem the vault dial solves from the street. `steal`'s own hold is now
  a flat `Config.CRACK.openHold` (half a second, well under the countdown
  threshold) — it opens the crack panel rather than timing the robbery, so the
  lock-vs-lockpicks axis shows on the crack dial instead (§5, §14).
- **A card can carry a live gold amount beside the verb**
  (`Config.PROMPT_AMOUNT_ATTRIBUTE`), watched rather than read once at build
  so it stays true while a player stands there — the steal prompt uses it to
  show the pig's own contents (or `Holding … · run home` once the thief is
  already carrying), which is also what `RobBadge` shows from the pavement
  (§5).
- The one shared part left is the bin (`hide`/`dig`), which the game already
  guarantees are mutually exclusive, so no card ever stacks.

---

## 15. Monetization and compliance

**Coins are never purchasable with Robux, at any price, ever.** That single
rule — not the earned-only tokens that came before it — is what now keeps every
coin sink in the game, including the two coin chests in §3, outside Roblox's
paid-random-item regulation. It can only be broken once: the day a coin pack
ships, every chest in the game becomes a regulated loot box retroactively, with
nothing in this repo having changed. See §3 for the full argument.

**Monetization is named things, never currency.** A Robux purchase may grant a
ride, a pass or a stance — never a coin, loot or a chest. Granting a named
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
*not* purchased, but the gate in front of it is the coins in the piggy bank
(§4) — so once coins could in principle be earned faster by any future paid
mechanic, money would buy a faster route to a random outcome even though it
never buys the outcome itself. Weaker than the case the coin-pack ban already
closes, and the next thing to look at if that ban is ever revisited.

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

- **Opening a chest is reachable now, and so is selling a spare; combining
  still is not.** The shop's **Crates** tab (`Shared/Crates.luau`, §14) fires
  `ChestOpen` from a real card and renders `ChestState`/`ChestResult` —
  verified live: all five crate cards build with three real previews each
  and the correct renormalised odds, opening `classics` produced a real
  reveal through the shared `SpinWheel` reel (title "PIGGY CLASSICS",
  subtitle "52% common · 32% rare · 12% epic · 4% legendary", landed on the
  server's actual item), a duplicate showed "Spare · sells for 95.2K", the
  OPEN button greys within 0.5s of the pig being drained and relights on
  top-up without spending on a greyed click, progress repainted 4/17 → 6/17
  across opens, and real pointer clicks on the SHOP button and the
  front-page CRATES card opened the panel and selected the tab.
- **The Inventory panel (`Shared/Inventory.luau`, §14) is the collection/spares
  screen the bullet above used to say did not exist, and it fires
  `SpareSell` from a real card.** It has since moved out of the shop rail onto
  its own full-screen panel (§14) — the facts below predate that move and are
  about the module, not its container. Verified live this session: the server
  boots clean with the tab wired; it rendered 43 skins / 7 effects / 14
  accessories / 1 decor / 6 rides for the account tested; selling a
  Bubblegum spare paid 2,000 coins with the toast "Sold 1 Bubblegum for
  2.0K." and took the spare count 3 → 2 and the card's own chip x4 → x3; the
  free `classic` skin correctly shows no sell control at all; a worn item
  that still holds spares keeps selling; and equipping a BMX (which can
  never carry a spare) flipped its sell control to a greyed WEARING,
  restored the instant it was unequipped. The server-side facts this
  replaces were already verified against the raw remote before there was a
  button, and still hold: the price cap biting per item (Bubblegum 8,000 →
  2,000; Lava 200,000 → 50,000; Pearl 1.2M → 266,666; Hyperdrive 14M →
  1,000,000), both capacity refusals with the spare surviving each ("Your
  piggy bank is full…" and "That is worth 1.0M and your piggy bank only has
  room for 88.2K…"), and the last copy refused while worn and sold once
  taken off with `SetService.revoke` actually removing ownership.
- **`ChestCombine` still has no caller anywhere in `ClientMain`.** Combining
  remains reachable only through the admin panel's `chest`/`combine` dev
  commands, and everything known about it is server-path verification rather
  than a button proven reachable: `combine` pools per-item spares by tier and
  auto-picks cheapest first, a client-named list it does not hold is refused
  whole, combining into the loot-priced `alien` chest is refused, and 42
  spares across 14 items survived a full server restart at schema 18. The
  plan is a COMBINE control on the Crates tab's own cards, since a combine
  rolls into a specific coin chest — the same tab that already knows how to
  price and preview one. The 12 accessories tagged `chest = "gear"` are still
  the identical 12 the roll already draws from, so the two continue to offer
  the same items through two different currencies until one is retired.
- **`Config.isSellable` does not know which catalogues can produce a spare.**
  It admits anything with a coin `cost`, so the Inventory panel shows a SELL
  button on rides and decorations too, even though no chest can ever
  duplicate either — a 90,000-coin BMX shows "SELL 22.5K", and pressing it
  fires a genuine, un-refused last-copy sale through the same
  `SetService.revoke` path a skin uses. Recorded, not fixed.
- **Skins are directed to become crate-only, and the shop has not been cut
  over.** `CosmeticsService.buySkin` and the Piggy tab's own card still sell
  every non-rebirth, non-set skin for coins exactly as before (§9); the only
  built evidence of the decision is the Inventory panel's empty-skins message
  and the comments beside it.
- **Loot buys the `alien` chest too, and it is opened exactly the way the coin
  chests are.** `Crates.render` walks every chest `ChestState` sends with
  stock, so `Config.CHESTS.alien` gets a card on the same tab, priced and
  opened in loot rather than coins — nothing in the Crates tab is coin-only by
  construction. This has not been verified live the way the coin chests were —
  the "verified live" list above was run against `classics` only.
  `CosmeticsService.rollAccessory` is untouched and remains a second,
  parallel route to loot-priced accessories: it still charges loot per
  accessory, one at a time, no duplicates, exactly as before.
- **Residents (§5) close most of the "needs two players" gap, and that is
  newly TRUE rather than newly VERIFIED — nothing in this pass exercised it.**
  A single player can now rob a `ResidentService.Resident` end to end: the
  crack against a real Vault Lock, the carry, the guard dog chase and
  tag, the getaway, delivery and ×`HEIST_PAYOUT`, a patrol pursuit, an arrest,
  bail and the robbed plaster all run against a resident exactly as they would
  against a player, by construction of `HeistService`'s `Target` type. What a
  resident genuinely cannot exercise, because `HeistService` skips it for one
  on purpose: `Config.LOSS_CAP`'s clamp on a fourth grab, `Config.REVENGE`'s
  window/payout and the grudge marker, and the friend bonus. Those, plus the
  Golden Bone's chase-break, hiding while carrying, and being tipped out of a
  bin by somebody else, still need a real second victim.
- **The alarm-only guard dog (owner home) is new, and is verified only at the
  predicate level — the branch as a whole has not run end to end.** The pieces
  it is built from — `GuardDog.isOwnerHome`, `GuardDog.bark` and
  `HeistService.markIntruder`'s `DogMark` Highlight — hold up individually.
  What has NOT run is the branch as a whole against a real intruder, and it
  cannot from a single session by construction: `HeistService.watchLawns`
  deliberately **excludes a plot's own owner** from the intruder search
  (`player ~= owner`), so a solo tester standing on their own lawn can never be
  found as the "loudest trespasser" on it and can never trigger their own
  alarm. It needs a second player walking onto a plot whose owner is a
  different, currently-connected player standing at home.
- **The crack (§5) is live, and the single fixed steal hold it replaced is
  gone.** `Config.CRACK`, `Config.CRACK_ALARM_ON_MISS`,
  `HeistService.crackTap`/`.crackStop`/`.isCracking`/`.scare` and
  `Shared/Crack.luau` are wired end to end — `attemptSteal` only opens an
  attempt now. `Config.STEAL_HOLD`/`Config.getStealHold` and
  `UpgradeService.getStealHold`/`.getStealFraction` are retired with it.
  The two gaps this bullet used to record are both closed: the guard dog now
  wakes on footsteps above a breed's `notice` as well as on a missed slice
  (`HeistService.watchLawns`, §5), and `Config.UPGRADES.tiptoe` (Sneakers)
  gives tiptoe its own four upgrade levels, read by `currentSpeed` through
  `UpgradeService.getLevel`. Like the rest of the heist system, the crack has
  not been exercised end to end against a real second player — see the
  residents bullet above for what a solo session can and cannot cover.
- **The spree (§5, §7) is verified as a state machine and never as a real
  delivery.** Driven directly against `SocialService` rather than through a
  robbery: the ladder climbs one step per call and clamps at
  `Config.SPREE.maxSteps`, it decays back to zero once `Config.SPREE.window`
  has elapsed since the last one, `breakSpree` clears it, and
  `Config.auditRobbery` passes sweeping both the cold (`steps = 0`) and hot
  (maxed) ends of `Config.ROBBERY_ADVANTAGE`. What has NOT run is
  `HeistService.deliver`'s two spree lines — reading the multiplier before
  `recordSteal` bumps it, and naming the run in the delivery toast — because
  both were checked by reading the source rather than by robbing somebody.
  Needs the same real second-player (or resident) delivery the rest of the
  heist system is waiting on.
- **A pointer CLICK can be synthesised; a DRAG has still never been tried.**
  This bullet used to say the MCP mouse tool "does not land where it is aimed",
  which `CLAUDE.md` had already corrected and this session demonstrated: two
  clicks driven at `AbsolutePosition + AbsoluteSize/2` read off the live
  instances hit the SHOP button and the front-page CRATES card exactly, opening
  the panel and selecting the tab. Every earlier miss was the coordinate, not
  the tool — source offsets disagree with screen position by the 58px GUI
  inset, which is what made guessing look like a broken tool.

  So the things gated on a single click are now testable and should be tested
  rather than assumed unreachable: the rebirth button's `Activated` and the
  held-item world click are both still unverified only because nobody has run
  them. What genuinely remains untried is the **hot bar drag** — down, move, up
  — which the tool does expose as separate actions but which nothing here has
  exercised, and `VirtualInputManager` still refuses the keyboard, so the
  number-row path stays unreachable from a test.
- **No audio has been listened to.** Every claim about the ride sounds is
  reasoned from asset metadata and confirmed by measurement. Somebody has to put
  headphones on.
- **A tier-5 moat has never been measured against the lawn grass tufts
  (§11).** The scatter takes no veto on a plot because the driveway sits in
  front of the lawn and the moat sits outboard of the fence ring — the first
  half is measured live at zero tufts on any driveway across every plot, the
  second is derivation only. Forcing a moat needs a real plot table
  (`PlotService.buildFence(plot, 5)`), which the MCP sandbox cannot supply — a
  service required there hands back a fresh module whose `start()` never ran.
- **The music toggle lives in the shop header**, which is the wrong place and is
  written down as a stopgap in the source.

`CLAUDE.md`'s "Not yet verified" section is the long-form version of this list
and is kept in more detail.
