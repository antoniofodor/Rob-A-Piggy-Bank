# Rob a Piggy Bank — the whole game


> **September 16 direction:** standalone piggy auras and their shop are retired.
> Piggy effects are coin-deposit feedback and Legendary skin visuals only.
> Existing effect ownership is retained for save compatibility; these items
> cannot be bought, equipped or newly awarded. Piggy Outfitters drops skins
> only at its unchanged 10% overall bonus chance. Older effects-shop notes
> below are historical and must not be used to restore the feature.

> **September 21 direction: the acorn track is deleted, not converted.** The
> second currency, the residential oak/basket/storage loop, the tree ladder,
> the shake minigame and the acorn-ranked season ladder are all gone — `docs/
> GAME.md` §3 previously described Acorns as a currency **being introduced**;
> they were built, shipped, and then retired in the same month. **There is one
> currency again: coins.** Crates carry no price in coins or in any other
> in-game currency — `ChestService.open` and the priced-crate remote are gone,
> and `Config.auditRandomOutcomes` refuses a `Config.CHESTS` row that carries
> a `cost` or a `currency`. What they *do* carry, as of 2026-09-23, is a
> **Robux** price, which puts every one of them inside Roblox's paid random
> item rule and is why `ProductService` exists (§3, §15).
> Seasonal skin buy-backs are priced in coins, derived
> from `Config.sellValue`. `SeasonService` keeps only the
> nemesis ledger and the season *clock* (`Config.seasonIndex`/`seasonEndsAt`,
> which the buy-back claims and the hot-skin window still key off); the season
> **ladder** — tiers, rewards, the board's third page, the sign's season chip
> — is gone with the currency that ranked it, and `Config.FINISHES` is
> currently unobtainable as a result (§17). The ten-trophy lawn shelf also
> retired in the same period; its replacement, `TrophyRoom` — stat panels
> drawn inside an authored house — was itself retired outright one day later
> (2026-09-22). `data.trophies` is still tracked and still published to the
> plot (`PlotService.setTrophyState`), but nothing currently draws it (§9,
> §17).

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

Every player owns a plot on a suburban street — there are more plots
(`Config.PLOT_COUNT`) than a server holds players (`Config.MAX_PLAYERS`) on
purpose, below. On the plot is a
**piggy bank** that fills with coins over time, and **the piggy bank is the
wallet**: there is one balance, all of it is in the pig, and all of it can be
taken. Other players can walk onto your lawn, crack your lock and
carry a slice of it home — and you can do the same to them, and **the game
mints extra coins on delivery** (`Config.HEIST_PAYOUT`× what was taken).
Every plot nobody has claimed carries a **resident**
instead of standing empty — a named neighbour with a real, growing piggy bank
— so there is always somebody worth robbing, even alone (§5). Each of the four
shops on the street also hides a **strongroom vault** on its own back wall —
robbed by walking inside, on a plot nobody can ever claim — so a full server
never runs out of victims either (§5).

Two upgrade trees compete: **defence** (fence, vault lock) buys the victim
*time*, never immunity; **offence** (lockpicks, bigger sack, speed boots) buys
the thief speed and volume. Neither can ever close the other out. Every plot
also carries the same guard dog (`Config.DOG_LEVEL`) whether it is a player's
or a resident's — the dog is no longer a rung either tree can buy or skip.

The loop, in one line: **accrue → spend (or get robbed) → rob → rebirth →
collect cosmetics.**

> **Direction (September 2026): the robbing pivot.** The game as first built
> was an idle game with a robbery bolted on, and the arithmetic paid players to
> camp — a perfect steal at level 20 earned less than a minute of idle income
> and risked three times that. The pivot makes robbing the game: the pig is the
> only wallet, the thief's reward is decoupled from the victim's loss, revenge
> pays extra coins, and the join shield is short. A second currency (Acorns)
> and the tree that grew them were tried and then deleted outright (§3) — the
> game is back to one balance. The reasoning is in `CLAUDE.md` under *The
> robbing pivot*; the pitch-level version is `docs/design-doc.html#pivot`.

### The three rules everything else is built on

1. **The server owns all state.** The client renders the last `StateUpdate` and
   never computes a balance.
2. **A robbery costs minutes of income and never costs progress.** Everything
   in the pig is stealable, but a victim can lose at most a quarter of it in
   an hour (`Config.LOSS_CAP`), and anything *spent* — an upgrade, a house, a
   skin — is gone from the pig and permanently safe. This is what keeps the
   game from being a bullying simulator.
3. **Speed is the currency.** `BASE_WALK_SPEED = 24` is the number every other
   system is calibrated against. Nothing may exceed it.

---

## 2. How the project is built

**The entire world is generated in code at server start.** There is no
hand-built geometry — the ground, the street, the tunnels, the houses, every
plot, the piggies, the dogs and the police car are constructed by
scripts. A fresh empty place plus this repo reproduces the world exactly, which
is why **the `.rbxl` is disposable and this repo is the project.**

```
rojo serve default.project.json     # then Plugins → Rojo → Connect in Studio
rojo build default.project.json -o RobAPiggyBank.rbxlx
```

Three things about Studio that cost time every session if forgotten:

- **Studio forks scripts when you press Play.** Save, wait for Rojo to push,
  *then* Play.
- **Rojo does not push at all while Play is running.** Stop, confirm the source
  landed, restart.
- **A session lock left by your last Play session is stale at once.**
  `DataService.lockIsStale` treats a `studio-`-prefixed lock (Studio's own
  `JOB_ID`) as stale the moment it is checked under `RunService:IsStudio()`,
  rather than waiting out `Config.LOCK_STALE_SECONDS` — Studio gives
  `BindToClose` too little time to release a lock cleanly between Play
  sessions on one machine. The live rule for a real server is unchanged.

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
`PiggyModel`, `LegendaryModel`, `RideModel`, `PigGear` and `PlayerGear` are
modules and not services: the shop shows the *real* item, built by the same
function that puts it on a lawn. A second near-identical copy drifts the
first time either is touched.

**`GrassTuft.luau` is also in `Shared`, for a different reason.** Nothing
renders grass in a shop. It lives there because two *services* plant it —
`PlotService` on the lawns, `NeighborhoodService` on the verge — and its
template mesh comes from `InsertService:CreateMeshPartAsync`, which yields;
one shared cache means one web call for the asset and one place that can say
how tall a tuft is, instead of two that could disagree (§11).

**`DodgeRoll.luau`, `SneakWalk.luau` and `CarryPose.luau` are in `Shared` for a
third reason: a runtime-built animation needs the identical builder in two
places.** None renders anything for the shop — one client plays the sequence,
and the `animdump` admin command (§10, §16) has to build the exact same one to
upload — so the function that assembles the `KeyframeSequence` can only live
where both can reach it. `SneakWalk` is the tiptoe's own gait (§5, §10);
`CarryPose` is how a thief holds the loot they are carrying (§5, §10).

**`ClientMain` is one chunk and sits near Luau's 200-local ceiling.** A new HUD
feature goes in a `local function buildX() … end` (a function body gets its own
register file, so the chunk pays one local instead of twenty) or in its own
module. `AdminPanel`, `SpinWheel`, `RaidFX`, `HouseFX`, `LegendaryFX` and
`Rebirth` are modules for exactly this reason.

---

## 3. Currencies

There is **one**: coins. A second currency — Acorns, `data.loot`, fed by a
tree grown on every residential lawn — was built and shipped, and then
**deleted outright** rather than converted: schema 29 (§13) drops `loot`,
`tree`, `treeAcorns`, `groundAcorns`, `acornsGrownAt`, `acornsDroppedAt` and
the acorn-ranked `season` table from every save, with no payout, because
nothing here is refunded during beta. `Config.ROLL_CURRENCY`, `Config.lootWord`
and every function that priced something in Acorns are gone with it.

| | Field | Earned by | Buys |
|---|---|---|---|
| **Coins** | `data.coins` — the piggy bank, **unbounded** (§4) | idle accrual, delivering a robbery (`Config.HEIST_PAYOUT`×, more on a revenge hit via `Config.revengePayout()`, more again per wanted star — §5, §7), dailies, events, selling a spare (`Config.SELL`, below), a seasonal skin buy-back's refund | upgrades, houses, decorations, rides, consumables, skin buy-backs |

**Coins are not sold for Robux, and that is still load-bearing.** Nothing
bought with an in-game currency is a regulated *paid random item*, so a
combine, a spare sale and a skin buy-back have nothing to disclose and no
gate to build. The day a coin product ships, every coin-priced random outcome
in the game becomes regulated retroactively (§15). What has changed is that
crates no longer rely on that guarantee — they are sold for **Robux** and are
inside the rule on purpose, below.

### Crates are bought with Robux, earned on the daily ladder, or granted on a rebirth

**Three routes in, and nothing else opens a crate.** No `Config.CHESTS` row
carries a `cost` or a `currency` — `Config.auditRandomOutcomes` still refuses
one, and `ChestService.whyCannotOpen` fails closed on one, because coins are
not purchasable and a coin price on a random outcome is the regression
nothing else would notice. What a row carries instead is `robux` and
`productId`:

| Route | Reached by | Notes |
|---|---|---|
| **Robux** | `MarketplaceService.ProcessReceipt` → `ProductService` → `ChestService.openPaid` | A function, never a remote, so a client cannot fire the channel a paid open arrives on |
| **The daily ladder** | `DailyService.openCrate` → `ChestService.grantFree` | Day one and day seven, opened at the doorstep box (below) |
| **A rebirth** | `ProgressionService` → `ChestService.grantFree` | Every rebirth — a rare crate, and a legendary one every `Config.REBIRTH_LEGENDARY_EVERY`th (§4) |

(The admin console is the fourth caller of `grantFree` and the only one that
can open anything today, §16.)

**`auditRandomOutcomes` has inverted twice now, and this is the stricter
end.** It first demanded an earned-currency price, then demanded *no* price
at all; it now refuses a coin price **and** refuses a non-set crate that
carries no positive `robux` or no `productId` field at all — because a crate
with no way to buy it and no way to say so is a card that cannot even read
COMING SOON. **A set crate is exempt by its `kind = "set"`**, not by a
list: attendance is a set crate's only route, so a Robux price on one would
be the thing to refuse. No set crate exists today -- the Alien Cache, the only
one, was deleted on 2026-09-23 -- and the exemption is kept for the next. Nothing inside any pool may carry a coin `cost`, a `pass`
tag or an `unlockRebirths` gate, and no chest may authorise odds for a tier
it cannot stock.

**A Robux crate is a paid random item, and `ProductService` is the machinery
that rule demands.** It owns the server's single `ProcessReceipt` callback —
one assignable property per server, so a second file setting it would
silently replace the first and the symptom would be a purchase that takes the
money and never arrives. Three things it holds:

- **An idempotent receipt ledger**, `data.receipts` (§13): a capped list of
  purchase ids. Recorded **and saved** before the crate opens, so a
  disconnect inside that window hands out nothing rather than twice. A crate
  that *refuses* — a full lawn is the common one — un-records the receipt and
  leaves it `NotProcessedYet`, so Roblox brings the purchase back rather than
  spending it on a warning.
- **A `PolicyService` gate.** `ArePaidRandomItemsRestricted` is read once per
  session and memoised, and it **fails closed**: an absent or failed answer
  is *restricted*. That inverts `PassService`, deliberately — there a failed
  check must not take a paid feature away, here a wrong answer would offer a
  regulated purchase to the players the rule protects. The verdict rides to
  the client as `ChestState.restricted` and the card says why rather than
  dropping its button; a receipt from a restricted player is refused as a
  backstop, and the answer landing a beat after the join re-pushes
  `ChestState`.
- **The product mapping**, on the crate's own row rather than a tier ladder —
  the shape `Config.PASSES` already uses. `robux` is a **display** price kept
  in step with Roblox's own by hand; `productId` is the developer product,
  and `ProductService.crateRobux`/`.crateProduct`/`.crateOfProduct` are the
  only readers.

**Odds are disclosed before purchase, drawn from the server's own
renormalised numbers.** `ChestState` carries what `liveOdds` would actually
roll with — over the unowned pool, over the tiers that have stock — so the
stacked bar on the tile and the per-tier breakdown behind the `?` are the
percentages the purchase would really be made at, never `Config.CHESTS.odds`
(§14).

**Every `productId` is 0 today, so nothing is buyable yet.** That is a
working state rather than a broken one: the card reads COMING SOON, nothing
prompts, and the game degrades to the earned-only catalogue it was.
`ProductService.start` warns at startup naming every crate with a price and
no product, the same warning an unset pass id gets and for the same reason —
a zero id is invisible from inside the game (§17).

### Chests — and no crate ever pays a duplicate

`Config.CHESTS` is **four** chests across two sections
(`Config.CRATE_SECTIONS`, which is what `Shared/Crates` builds the tab from,
and what `Crates.mount` lays out again on the Robux page):

| Section | Chests | Kind | Draws from |
|---|---|---|---|
| **Piggy Crates** | `og` / `ograre` / `oglegendary` — shown as the Piggy Crate, Rare Piggy Crate and Legendary Piggy Crate | `skin` | every piggy skin in the crate economy, all tagged `chest = "og"` — 67 at the merge: common 17, rare 28, epic 11, legendary 11. Animal Kingdom and Arcade were separate shelves until 2026-09-23 (designer: *"stop separating by category of piggy and put all common, rare, epic, legendary into one pool"*); their skins keep the theme as a `collection` field that only the bag's headings read (`Config.SKIN_COLLECTIONS`). **`chest` is the crate and drives the odds, the buy-back price and the stealable-skin audit; `collection` is a heading and nothing else** — folding one into the other breaks the audit or loses the themes |
| **Guardians** | `guardian` | `coat` | five of the eight `Config.DOG_COATS` (below), `rare`/`epic`/`legendary` with no common rung — one rung only, since a tier crate is solved on coins per legendary and this one has no coin price to solve against |

Each chest carries an `odds` table by rarity, a `blurb`, a `colour` and an
`order`. A crate with no `floor` draws its whole pool — `og` and
`guardian`; the rest carry `floor = "rare"` and are odds-only crates over the
same pool, for players chasing a specific tier rather than the common flood
(why every floor is `"rare"` and never higher is below).
**Membership is a field on the ITEM** — `chest` on a skin or a coat, the same
convention `zone` uses on decor and `set` uses on set items — rather than a
list kept on the chest, because a list is a second place to remember and the
one that goes stale. An item's tier inside a chest is `Config.rarityOf`, the
same function that already borders every shop card, not a second notion of
rarity.

**NO CRATE EVER PAYS A DUPLICATE (designer, 2026-09-23), and that is a POOL
rule rather than a payout rule.** `ChestService.poolOf` takes the save and
filters every tier to what that player does **not** own, so the reveal cannot
land on something they already hold — for every kind, on every route, paid or
free. `handOver` writes no spare for any kind any more; its repeat branch
survives only as a fallback for a caller with its own pool, and for a skin it
still places a second piggy on a free pedestal rather than shredding one into
currency.

**An empty pool is refused BEFORE anything is spent.** `whyCannotOpen` is the
one predicate every route asks — the paid receipt, the doorstep box and the
rebirth pick all go through it — and it gives four different sentences for
four different reasons: a crate that does not exist, a catalogue with nothing
in it ("not stocked yet", which is a bug somebody has to fix), a collection
somebody has **finished** (which the card draws as COLLECTION COMPLETE), and
a lawn with no room for a piggy. The one failure mode here that looks like
theft is taking Robux and handing back nothing, so it cannot happen.

**`ChestService.pickOpenable(player, keys)` is how a caller with a *list* of
crates chooses one** — the rebirth ladder's route in. It asks the predicate
that actually decides rather than `Config.rebirthCratesOpen`, which tests
whether a shelf's *legendary* keys are all owned: that was the right question
while a crate could pay a duplicate and is the wrong one now that an
exhausted pool is refused outright. It picks at **random** among the openable
ones, so a rebirth does not always roll at the same shelf.

**A skin with a baked coat (`surface`, the `animal` shelf and most of `og`'s
non-Studio rows) has its SOURCE at `assets/piggies/<tier>/<key>/`, one folder per
skin, and nowhere else is authoritative for it** (`assets/piggies/README.md`)
— the authored Blender scene, the generator that builds it, the sheets that
get uploaded and the shop-card/hero renders each sit in their own room under
the key, resolved everywhere by `blender/pig/paths.py`. A closed-back pass
filled the vault hatch in the master mesh and re-baked every body sheet
against it; nothing has been uploaded from it yet, so the live `ColorMap` ids
still point at the open-hatch bake kept alongside the new one.

**Skins are back to all four rarity tiers — `epic` included — as of
2026-09-21.** The tier is meant to describe what the skin *is* rather than
only what it cost: common is a look, rare is colour that moves or a mark
with a twist, epic is a glow **plus** an aura, legendary is all of that
**plus** its own `SkinFX`/`LegendaryModel` geometry (§9) — a TECHNIQUE
ladder, not a price ladder wearing new names. Epic had **zero** stock
anywhere in the game until the **OG FAMILY** block landed — fourteen rows
built entirely *in Studio*, never Blender-baked: flat colour, a material,
the `pattern` part-builder, `anim`, `aura`, nothing uploaded, so nothing here
can be moderated away and nothing costs the developer's account (`CLAUDE.md`,
the `generate_material` ban — the *animal* shelf is where baked coats live).
Two commons (`muddy`, `rosegold` — the block's third common, `sooty`, was
deleted 2026-09-23), six rares (`marble`,
`rockslide`, `quartz`, `banker`, `tiedye`, `verdigris`) and six epics
(`ghost`, `charcoal`, `starlight`, `nightlight`, `sugarrush`, `hologram`) —
every epic carries a glowing element (Neon, glowing shards or lit eyes) *and*
an `aura`, which is the whole of what the rung is. The `animal` shelf gained
its own epics the same day — four of them landed (Hedgehog, Lion, Storm
Stone, Peacock) and two are left, Storm Stone retired and Lion deleted on
2026-09-23 — so epic is stocked on both collections now, not only `og`'s. All 72
skins carry an
explicit `rarity` field rather than falling back through `Config.rarityOf`'s
price derivation — `martian`, the Alien Cache's own skin, still keeps `epic`
too, but it is no longer the catalogue's sole one; it stays a *set* item in a
mixed-kind chest rather than a member of a skin chest, so it sits outside
this restructuring either way. `Config.RARITIES`/`RARITY_ORDER`/`RARITY_BANDS`
are unchanged — skins land on all four of them again, the same as every
other priced catalogue (§9). The three pre-existing OG legendaries
(`supernova`, `stormcaller`, `prismatic`) were re-numbered `order` 60–62 so
the shelf still sorts common → rare → epic → legendary with the new rows
slotted in; cosmetic only, no save impact.

**`Config.skinAura(tier)` is what an epic gets that a rare never does.** It
returns nil unless `Config.rarityOf(tier)` is `"epic"` or `"legendary"` *and*
the skin names an `aura` — so an epic is a glow plus that one particle system
and nothing more, where a legendary is the same aura plus the whole-model
overlay above it (§9); the aura is the one visual the two tiers share. Four
new `Config.SKIN_AURAS` rows back four of the six new epics — `wisp` (pale
smoke drifting up, for `ghost`), `fireflies` (a handful of slow wandering
points, for `nightlight`), `fizz` (the sparkle row at a boil in candy
colours, for `sugarrush`) and `hologram` (slowed cyan static, for the skin of
the same name) — and the other two reuse effects the catalogue already had:
`charcoal` takes `embers`, `starlight` takes `sparkle`. Every epic aura runs
at a deliberately low rate — an epic sits beside legendaries whose auras run
16–42 particles a second, and one that out-shouted a legendary would be the
ladder lying about which tier is louder.

**There is one piggy ladder, because there is one piggy pool.** `og` draws
`common 52 / rare 32 / epic 12 / legendary 4` over every piggy skin since the
2026-09-23 merge (the paragraph after this one is the history of the
`animal` shelf that merged into it); `guardian` borrows the SHAPE rather than
the pool. While epic
sat empty the middle rung carried what two tiers now split (`rare 44`);
`epic = 3 × legendary` is what keeps
`Config.COMBINE` (below) level against rolling a legendary straight, so the
12 cannot move without repricing the 4 above it. `ograre` (`floor = "rare"`)
now draws `rare 60 / epic 30 / legendary 10`; `oglegendary` draws
`rare 40 / epic 25 / legendary 35` and stays floored at `"rare"` rather than
`"epic"` even though epic is stocked now — flooring at the newly-stocked tier
would leave `legendary` the only tier left above it, and `liveOdds` would
renormalise that into a *guaranteed* legendary, the same trap a floor over an
unstocked tier always sets. **The Rare and Legendary Piggy Crates carry
those two rows**, and the Guardian Crate enters on the `*rare` split, since it
stocks rare and above and a common crate over it would have nothing to give.

**HISTORY — the `animal` shelf before the merge.** It was a crate of its own
until 2026-09-23; its skins are in the piggy pool now under
`collection = "animal"`. It became a full four-tier shelf in three steps
worth keeping, because each one is the shape of a mistake this file already
warns about. It shipped with eight painted coats
and one legendary (`stormwolf`) and no `rare` tier at all, so authoring
`common 52 / rare 44 / legendary 4` against an empty `rare` would have let
`liveOdds` drop the unstocked tier and *renormalise the crate*, quietly
repricing it to `common 93 / legendary 7` — the same failure the `alien`
chest's own comment records under a floor rather than an empty tier. It
shipped `common 96 / legendary 4` instead, holding legendary at parity with
`og`'s 4% by construction. Seven rares landed and it moved to
`common 52 / rare 44 / legendary 4` — again solved rather than typed, because
`rare` was standing in for the two tiers (rare and epic) it would eventually
split. And as of 2026-09-21, four epics — Hedgehog, Lion, Storm Stone and
Peacock, below — landed alongside it, so the shelf is `common 52 / rare 32 /
epic 12 / legendary 4`, `og`'s own ladder, with `epic = 3 × legendary`
holding `Config.COMBINE.need` (below) level the same way it does on `og`.
Two of those four epics have since gone — Storm Stone retired and Lion
deleted, both 2026-09-23 — and the ladder does not move for it: what these
odds need is that the tier is stocked AT ALL, because `liveOdds` drops an
*empty* tier and reprices the crate. That risk is smaller in the merged pool
— Animal Kingdom's epic tier held two skins, where the piggy pool's holds
eleven — but the rule is the same one.

**`Config.COMBINE.need` is 3 again, not 5.** It rose to 5 while epic sat
empty: losing that rung left the tier just below legendary far more abundant
(12% of a roll to 44%), which made combining 5.1× cheaper than rolling a
legendary directly against the four-tier game's own ratio of 2.4×, and five
spares of a tier was what restored it. With epic back at its original 12%,
the two routes to a legendary are level again by construction — `1 / 0.04 =
25` opens rolling one straight, `3 / 0.12 = 25` opens gathering three epics
and combining — so `need` dropped back to 3 to match. Left at 5 through this
change it would have been `5 / 0.12 = 41.7` opens, combining 67% dearer than
rolling, so nobody would ever combine and the spare screen would be
decoration.

`Config.chestPool(key)` returns the full stock grouped by tier, and
`ChestService.poolOf(key, data)` narrows it to what one player can still win.
A `kind = "set"` chest — only `alien` today — resolves through `Config.SETS`
and `Config.catalogueFor`, because a set spans five catalogues at once; every
other chest scans one catalogue for a `chest` tag, and the list of
catalogues a crate may draw from is an explicit if-chain in `chestPool`
(`skin`, `accessory`, `effect`, `coat`) rather than every table
`catalogueFor` answers for — widening it to all of them would make a typo in
a chest's `kind` **stock** a pool rather than empty one. `Config.ACCESSORIES`
is retired and empty (§9), and the `gear` chest that drew from it went with
it. Crate skins and crate coats carry explicit rarities and no coin `cost`;
their historical prices survive as `sellBasis`, read only by
`Config.sellValue`, because stripping a price would have taken the sell CAP
off as well as the rarity. Both services refuse a direct coin request for a
crate-only item by naming the crate (§9).

**A duplicate is impossible out of a crate now, so `data.spares` has
different sources.** The count is still **per item**, keyed `"kind:key"`
(`Config.chestEntry(chestKey, entry)` is the one place that knows the grammar
both ways — a bare key for an ordinary chest, `"kind:key"` for a
`kind = "set"` one), and everything that sells and combines a spare is
untouched. What went is the crate as a *source* of one. **What is left is
theft** (§5): a robbed skin the thief already owns lands as a spare rather
than as nothing, and a recovered insured copy comes back as one — plus the
admin console. A wild piggy — lassoed and carried home now, never picked up
free (below) — is a **second piggy** when it is a duplicate skin
(`Config.placePiggy`/`Config.addPiggy` bump `data.piggies.owned`), not a
spare, so nothing in normal play currently mints a `coat:` spare at all (§17).

**`Config.COMBINE` pools spares BY TIER**, so any `Config.COMBINE.need`
commons fund a higher-tier roll whatever items they are — a duplicate out of
a finished collection is still fuel for one barely started, with a small
chance of climbing two or three tiers in one combine (`Config.COMBINE.odds`).
**Combining spends spares into regular crates**, never into `alien`;
`Config.canCombineChest` draws that line off the chest's own kind, and
`ChestState.canCombine` carries it to the client while the service checks it
again before consuming anything. **The machine that does it is no longer in
the shop** — see the Piggy Press, below. Effects have no chest: there are too
few priced tiers to spread across rarities, so effects stay direct-purchase.

**`ChestService.rollUp(player, fromTier, kind)` is the combine's other half,
and it CONSUMES NOTHING.** It climbs a tier on `Config.COMBINE.odds` and
grants, for a caller that has already taken payment and wants to own the
reveal itself: call it first and consume only on a non-nil answer, because
consuming first is how three spares are eaten by a pool with nothing left in
it. It pools `unownedByKind` — every unowned item of one kind across *every*
collection, unioned through the crate pools so every exclusion those already
make comes for free — because a spare is pooled by tier regardless of which
shelf it came from, so what it buys has to be too. It walks **down** from the
rolled target first, so a lucky three-tier climb into an exhausted legendary
pool pays the epic it passed through rather than nothing, and never below
`from + 1`. Nothing calls it today; `CombineService` deliberately forwards to
`combine` instead (below).

**A duplicate SKIN is a second piggy, not a spare, by designer ruling
(2026-09-21).** `ChestService.handOver` places every repeat copy of a skin on
a free lawn pedestal (`Config.addPiggy`) rather than crediting `data.spares`
— a second piggy is real progress rather than a consolation, under the
collection redesign in `docs/PIGGY-COLLECTION-PLAN.md`. A crate that could
roll a skin is refused outright while every pedestal is already full
(`ChestService.whyCannotOpen`), before the roll and before any charge, so
there is no "rolled it and had nowhere to put it" case.

**A piggy standing on a pedestal can now be lifted, carried and put down
again — `ServerScriptService/Services/PiggyHaulService`.** Each of the six lawn pedestals carries
three more prompts beside its sell one, sharing one key and one prompt slot so
that exactly one is ever live on a given screen: **TAKE** lifts one of your
own off your own plinth (`Config.PIGGY_HAUL.takeHold` — a near-doorknob
press, undone by stepping off and pressing again); **SNATCH** lifts
somebody else's off theirs (`.snatchHold` — dearer than a crack's opening
doorknob, `Config.CRACK.openHold`, and cheaper than a sale's); **PLACE** sets
one you are carrying down on an empty
slot of your own (`.placeHold`, the same length as take's). Which one a
given reader sees is `Config.PROMPT_OWNER_ATTRIBUTE` (hides take and place
from everybody but the owner) against the new
`Config.PROMPT_DENY_OWNER_ATTRIBUTE` (hides snatch from the owner alone),
plus the plinth's own occupancy — take and place can never both apply, since
a plinth is holding a piggy or it is not (§14).

**A snatched piggy is not yours on arrival — it has to be *secured*.**
Standing on your own ground with an empty slot to receive it, for
`Config.PIGGY_HAUL.secureSeconds`, is what turns *stolen* into *owned*; the
place prompt refuses a stolen piggy by name, because a thief who could press
one the instant they got home would never be catchable on their own lawn.
The countdown runs on the billboard over the carried piggy, which is where
the *victim*, chasing from behind, can actually see it. There are two rooms
it can run in and it never mixes them: on the street the carrier's own yard
(`PlotService.yardContaining`) with a free *lawn* slot, and indoors the
carrier's own hallway with a free *hall* plinth (`InteriorService` registers
the hall lookup via `PiggyHaulService.registerHall`, since it requires the
haul service rather than the reverse). It resets the moment the carrier
leaves that room or its last free slot fills, a room with nothing free never
starts it, and a neighbour's hallway is never the carrier's ground.
`Config.PIGGY_HAUL.victimCooldown` (`Config.STEAL_COOLDOWN`'s own number)
then bounds how often one thief may pick over one lawn — it does **not**
bound what a whole street can take from one victim; that clause of
`Config.LOSS_CAP` does not exist yet for piggies (§17).

**The carry is its own service rather than a `kind` on the coin `Carry`,
because it has none of that carry's accounting** — no amount, no victim
balance, no bail, no revenge window; it moves an *object*. What it shares with
a coin haul is everything about the *weight* of a getaway: the carry speed
penalty, the ride refusal, the disguise breaking, and a guard dog hearing and
being able to catch a loaded thief. It does still earn a wanted star on the
secure, through the same `SocialService.recordSteal` the coin robbery calls
(§5, §7) — a snatch is a delivery too, on the one ladder that mechanic now
runs on, even though it never opens a revenge window.
`HeistService.haulingAnything` is the one question both kinds answer, fed
through `HeistService.registerPiggyHaul` (filled in by `Main`, since
`PiggyHaulService` requires `HeistService` and asking back would be a
cycle). It builds its own model rather than reusing the coin carry's — the
loot is `PiggyModel.build`, which already names its own output
`Config.LOOT_MODEL_NAME`. That is the *same* name the coin carry's money bag
wears (§5, below); the two carries are told apart by
`Config.CARRY_KIND_ATTRIBUTE` on the model itself (designer, 2026-09-23: the
piggy's carry is one animation, the coin sack's is another) — this one
stamped `"hug"`, the coin sack `"sling"` — so `CarryPose` plays the right
pose without either service knowing about the other, and a model naming
neither kind is hugged, which is what a piggy carry has always been. The two
are otherwise unrelated models — this one is the victim's own piggy skin,
welded through `CarryPose.anchor(character, "hug")` and seated at
`CarryPose.HOLD`, the hug's own seat.

**A wild piggy is lassoed now, not picked up free
(`docs/LASSO-PLAN.md`).** The old free `CatchPrompt` — a plain hold on a
landed piggy — is retired. A player holds a **lasso** (a fifth consumable
catalogue, §6) and it locks onto whichever landed piggy sits nearest the
centre of the screen, within `Config.LASSO.lockCone` of where the camera is
looking — no aim needed; a click throws it, the rope goes taut for a **struggle** of about
`Config.LASSO.struggle` seconds with a big TAP button (taps are counted on
the server and capped at `Config.LASSO.tapRate`, the crack's own
anti-autoclicker argument), and the server then rolls against
`Config.lassoChance` — the lasso's tier against the piggy's rarity, nudged up
by tapping (which **multiplies rather than adds**, so a fast thumb moves an
easy catch a lot and a hard one hardly at all: a Rope lasso cannot out-tap
its way past a legendary) and by **pity**, points added per miss by that
thrower on that piggy alone, with a hard guarantee by a fixed throw number.
Every number a player is shown — the shop card, the hot bar hint, the Robux
product text — is `Config.lassoDescription`, generated from the same table
the server rolls against, never typed by hand. **A lasso is spent on every
throw, caught or not**, and every refusal — no stock, the piggy already
roped by somebody else, out of range, nowhere at home to put it — happens
before it is spent, the same rule §6 states for every consumable. A miss
snaps the rope and the piggy **flees** a short way at
`Config.LASSO.flee.speed`, slower than a child, then grazes and can be
lassoed again — by anyone, now at the misser's own raised odds on it.

**A catch is carried home as a third kind of haul, `wild`**, alongside
`take`/`snatch` above — the identical hug carry, the identical secure
countdown on the carrier's own lawn or hallway. What differs is what a real
*hit* does to it: a nab landing on the carrier, a stunning gadget hit, or a
guard dog catch (if the carrier cuts across somebody's lawn) drops the piggy
**dazed** where the carrier stood, circled by stars, rather than sending it
back to an origin slot the way a snatched piggy does below — a wild catch
never had one. For `Config.LASSO.dazed.catcherWindow` seconds only the
original catcher may touch it (a short hold, no lasso needed); after that it
is open to **any** lasso at normal odds, one rope at a time, and it rejoins
the wild untouched after `Config.LASSO.dazed.wake` seconds if nobody does.
Any pick-up buys `Config.LASSO.dazed.immunity` seconds of nothing being able
to knock it loose again, so one recovery is a real chance to get away.
**Lassoing somebody else's dropped catch is a robbery** — a wanted star for
the taker, a revenge marker on them for the catcher (§7) — but the catcher
picking their own piggy back up never is.

**The Elite lasso is a Robux purchase, gated exactly like a paid crate
(§15), and stealing a dropped catch is open to every tier on purpose, never
gated to Elite alone** — an Elite-only steal was proposed and refused: it
would make PvP pay-to-win, and a player `PolicyService` restricts from
buying one could then neither contest a catch nor win their own back.

**Every ending that is not a successful secure sends a *snatched* piggy home
to its *origin slot*, never to whatever slot happens to be free.** A nab — from a
bystander's own prompt on the carried piggy, or a guard dog or shopkeeper
(routed through `HeistService.nab`, which falls back to the piggy path once
it finds no coin carry to resolve) — a patrol confiscation, a death and a
disconnect are five ways to stop being a thief, and one function,
`PiggyHaulService.returnHome`, handles all five, so a victim's lawn cannot
be reshuffled by somebody else's failed robbery. **A confiscating patrol still
charges the thief the ordinary arrest bail** (`Config.POLICE.bailFraction`
of *their own* balance, §7) even though nothing about a piggy's value feeds
into it — bail stopped being a multiple of what an arrest recovered the same
day it became a flat share of the thief's own till, so losing the piggy and
paying bail are now two separate costs of the same arrest rather than one
standing in for the other.

**Residents now keep piggies on their lawns too.**
`Config.RESIDENTS.piggyCount` is drawn from the same shuffled bag and the
same two exclusions a neighbour's own coin-pig skin already takes, and
**capped**, never scaled, at `Config.RESIDENTS.piggyTopRarity` — the same
"richer than the thief is a faucet" rule that already governs a resident's
coin pig. A snatched resident piggy is **not replaced**, so a server's
neighbour stock is finite and visibly runs down as the street is picked
over; the lawns are seeded short of full on purpose, so a picked-over lawn
still reads as picked-over rather than merely poor. Both numbers are
provisional, waiting on the same economy pass every other supply dial in
this collection still owes (§17).

**A neighbour's own pedestals fill now, and a neighbour goes out and robs
piggies too — both new on 2026-09-22.** The accrual tick used to credit only
a resident's coin pig; `resident.piggies.slots[i].buffer` sat at zero from
the day the plinths were seeded, because the loop that fills a buffer
(`EconomyService.start`) never touched a resident. It fills on the player's
own arithmetic now, every tick, capped and clamped exactly as a player's
would be. A neighbour walks to bank it, too: **`"collecting"`** is a new
`resident.state` of its own, reached when the *ripest* of their own six pads
clears `Config.RESIDENTS.collect.fullness` of its cap, the same "worth the
trip" test a player's own commons-lap already runs on. And each trip out now
*chooses a job*, `"crack"` or
`"snatch"`, weighted by `Config.RESIDENTS.snatch.playerWeight`/
`.residentWeight` — a snatch against a **player** is the threat (their
plinth goes bare, they are told who, and the neighbour walks it home at a
speed a player can chase down), a snatch against **another resident** is
scenery (nobody is told, nobody chases, and the weight is small enough that
a collection only visibly drifts over a long session); a shop or an emptied
lawn falls back to a crack rather than standing at a bare plinth for six
seconds. The snatch itself runs through `PiggyHaulService.residentSnatch`/
`.residentReturn` — registered into `ResidentService` by `Main`
(`.registerSnatch`/`.registerPiggyReturn`), the same registry shape the
trampoline's bounce veto uses, so `ResidentService` never has to require
`PiggyHaulService` back. Home with the loot, it goes on a plinth through
`Config.addPiggy`, the one door every piggy in this game arrives through; a
full lawn swaps out its **lowest-rarity** piggy first (`Config.rarityRank`)
rather than refusing, which is the resident's own collection changing over
time instead of filling once and freezing.

**How many neighbours may be moving at once is capped separately from how
many are out on a trip (2026-09-23).** `Config.RESIDENTS.walk.maxOut` already
bounded simultaneous trips; `.walk.maxMoving` (2) bounds every state but
`"home"` and `"chasing"` — a potter, a collect walk, a crack, a carry and the
walk back are each a figure being posed every frame — with a chase exempt, so
a shopkeeper still comes for a thief whatever the rest of the street is doing
(`ResidentService.movingCount`). A resident is only re-posed when its
position, facing, stride or what it is carrying has actually changed
(`ResidentService.poseIfChanged`), rather than every frame regardless. The
walker also publishes its own state as `Config.RESIDENT_STATE_ATTRIBUTE`
("ResidentState") on the resident model whenever it changes, read by nothing
in the game itself — it is there for a probe to ask which neighbours are
moving and why without a handle on the service.

**A pig is on the till at all times, by construction — there is no
take-from-till verb, only a SWAP.** `PiggyBank.build` gives the till's own
`Body` a fourth prompt (`SwapPrompt`, kind `swap`, card slot 1 — it stood
above the smash's own slot 1 and moved down to it once the smash was retired,
rather than leave a gap — held for
`Config.PIGGY_HAUL.swapHold`), owner-only and born disabled: it lives
exactly while the owner is standing there carrying a piggy of their own
(`PlotService.setSwapOffer`, the prompt's one writer, called at every carry
start, end and change), and it names what would go onto the till rather than
a bare verb. Holding it (`PiggyHaulService.swap`) puts the piggy in the
owner's arms onto the till and hands them the piggy that was standing there
instead — refused for empty hands, for a bag of coins rather than a piggy,
for anybody else's plot or a resident's, and for a snatched piggy that has
not finished its secure countdown yet (above). `CosmeticsService.applyToPlot`
dresses and rates the bank from whichever key is on the till now
(`Config.piggyKeyAt(data, 0)`) rather than from a wardrobe choice, and
mirrors it into `cosmetics.skin` so every other reader of "what is this
player wearing" still agrees; `equipSkin` — the bag's old tap-to-wear
button — refuses out loud and names SWAP instead of silently doing nothing.
A retired till key falls back to `Config.DEFAULT_SKIN` on reconcile, moving
the owned counts with it, so a till never stands bare (§13).

**A secured snatch is what finally wires the rap sheet to piggies.**
`SocialService.recordSteal` fires on the *secure*, never the grab — loot
taken back out of a thief's hands was never stolen, they were caught, the
same rule a coin robbery's delivery already follows — valued at
`Config.piggyWorth(key)` (`Config.sellValue("skin", key)`), so the Most
Wanted board (§7) and the sell prompt can never disagree about what a piggy
is worth. `HeistService.deliver`'s own coin-robbery call into `recordSteal`
stays alongside it: cash robbery is still live, so it still has to count
toward the poster, the weekly board and the patrol's target while it does.

**A spare has two exits: combine it, or sell it for coins.**
`ChestService.sell` (remote `SpareSell`) pays `Config.sellValue(kind, key)`
per copy — the tier's coin value off the inverse `Config.RARITIES` weight,
**capped at `Config.SELL.priceFraction` of the item's coin cost or historical
`sellBasis`** where it has one, so buying something in the shop and selling it straight back can
never turn a profit. **You may sell your last copy of an item, not only
spares** — the one guard is `SetService.inUse`, which refuses only the copy
currently equipped/worn/placed, so an accidental sale of the thing a player is
looking at is the failure this stops, not a lock on the mechanic itself.
Selling the last copy runs through `SetService.revoke`, the exact inverse of
`grant` (pushes the item's own service and the set panel, saves immediately —
spares alone are not saved per-sale, same as a chest open, see §13). **A sale
banks in full now, with the pig's ceiling.** It used to be refused outright,
never clamped, whenever the payout would not fit the reader's own capacity —
refused rather than clamped, because a clamp that destroys coins a player has
just earned is indistinguishable from theft — and both endings retired the
same day capacity did (§4): there is no room left to overflow.

**`alien` is the one event chest**, drawing on the same alien **set** (§8),
which is down to **two** items now — `martian` (skin) and `hoverdisc`
(ride); the set's two accessory members retired with `Config.ACCESSORIES` and
its decoration member (the Crashed Drone) retired with the lawn ornaments, so
`odds = { epic = 100 }` is the whole table. It is the one chest with no
`robux` field, and `auditRandomOutcomes` refuses one on it: attendance is its
only route and that is the whole point of it.

**Two rungs of the daily ladder pay a crate, and both are opened at the
doorstep.** Day one is a common `og` crate and day seven is `ograre` —
`Config.DAILY_CYCLE`. A claim does not open one on the spot: it queues the
`Config.CHESTS` key until the player walks to their own doorstep box and
presses the prompt there, at which point `DailyService.openCrate` clears it,
saves, and calls the same `ChestService.grantFree` a claim would otherwise
have called directly. Moving the reveal off the claim button and onto a box
on the lawn (`PlotService.setCrate`/`.setCrateOwner`, painted in the chest's
own `colour`) is what gives the rungs that pay something *playing cannot* a
moment of their own, rather than firing while the player is still looking at
the daily board. It survives a disconnect between the claim and the walk by
design — losing a seven-day streak's reward to a dropped session would be the
worst thing that ladder could do.

**It is a QUEUE, `data.daily.crates`, and the single field it replaced was a
silent loss.** `data.daily.crate` held one key, which was right while exactly
one rung paid a crate: claim day one, do not walk to the box, claim on
through to day seven, and the write replaced a common crate with a rare one
with nothing erroring and nothing on screen to say a reward had gone —
on the one ladder whose whole promise is that turning up is paid.
`DailyService.owedCrates` folds the retired field in on **first read** rather
than in a migration branch (it empties the old field as it consumes it, so it
is idempotent by construction) and caps the list at a length nobody will
reach, so it cannot grow for the life of an account. No schema bump: the
generic reconcile fill only adds missing keys, so a field a service invents
survives a rejoin (§13).

**`ChestService` is wired end to end, and there is no `ChestOpen` handler.**
Combining has moved to the Piggy Press on the verge (below); selling and the
seasonal skin buy-back are reachable through the inventory and the Crates
tab. Opening happens through `grantFree` — `DailyService` (days one and
seven), `ProgressionService` (a rebirth) and the admin console — or through
`openPaid`, reached only from `ProcessReceipt`. Nothing in `EventService`
calls either, so `alien` has no live in-game route today beyond the admin
panel; see §17. The `ChestCombine` / `SpareSell` / `SkinBuyback` /
`ChestResult` / `ChestState` remotes are live, plus `CombineOpen` /
`CombineRequest` for the station. `Main` starts the service and registers
`EconomyService.push` and `CosmeticsService.push` as its balance pushers;
`ChestService.start` is what registers `openPaid` with `ProductService` and
starts it, so no line in `Main` is load-bearing for a purchase working.
`Shared/Crates.luau` (§14) renders `ChestState` / `ChestResult` and drives
the Robux prompt; **`Shared/Inventory.luau`** (§14) — the one place a player
can see every spare they hold, since a chest reveal shows only the one item
just opened — fires `SpareSell` from a real card button.

`Config.isSellable` does not know which catalogues can actually carry a
spare — it admits anything with a coin `cost`, so a ride or a decoration
(neither of which any chest can ever duplicate) shows a SELL button too, and
selling one is a genuine, un-refused last-copy sale through the same
`SetService.revoke` path a skin or accessory uses. Recorded as a known gap in
§17, not fixed.

### The Piggy Press — the combine machine left the shop

**Combining is a PLACE now, not a row in a shop tab** (designer, 2026-09-23:
*"move the combine machine outside of the shop and into a dedicated spot on
the map"*). What stood on the Crates tab was four chips reading COMMON 2/3
under a header, which a nine-year-old had to already know what combining was
to find — and once no crate mints a spare, that row was permanently 0/3 on
that tab, which is the control that does nothing when pressed. A hopper, a
ram and a chute say what the thing does before a word is read, which is the
same argument that put rendered models on the shop cards.

Three new files and no new arithmetic:

| File | Owns |
|---|---|
| `Shared/CombineStation` | Where it stands, what it is made of, and the pure half of what its panel says |
| `Shared/CombinePanel` | The panel, on its own `ScreenGui` |
| `Services/CombineService` | The place, the prompt and the request handler |

**It forwards to `ChestService.combine` and owns none of the transaction.**
That function has validated the pick against the save, refused out loud on
every failure, consumed `Config.COMBINE.need` spares *past* every refusal,
rolled the climb and granted since spares existed — and `data.spares` is a
save field, so a second writer that got the decrement wrong would be a save
bug rather than a broken feature. What the station adds is the two things a
shop row did not need: a **kind** (`CombineStation.KINDS` — piggies eat
`skin` spares, guardians eat `coat` spares) and a refusal for the one failure
a shop row could not have, a kind whose crate is not stocked. It is
deliberately not `rollUp`: using that would mean writing the consumption in
`CombineService`, which is exactly the second writer.

- **Where it stands is DERIVED and has to agree with the boards.**
  `CombineStation.freeGaps` lists the verge gaps no `Config.SHOPS` entry
  stands in, nearest the middle of the row first — which reproduces
  `SocialService.boardX`'s own ordering — and the station takes `[2]`, the
  next one out from the boards' `[1]`. Today that is **gap 3, x 120, at
  `boardZ`**, front to the road, on the same shoulder as the leaderboard so
  that the two things out there a player walks up to and *reads* share a
  side. Every gap being spoken for is a real configuration and the fallback
  is past the last column, **loudly** — a machine nobody walks past is a
  smaller failure than one standing in a drive. (`boardX` is a local in
  `SocialService` that this file may not reach into, so the ordering is
  written twice — and `tests/luau/combine.luau` loads that very local out of
  the source and asserts the boards take `freeGaps[1]` and the station does
  not, so the day the two disagree a test says so rather than two objects
  sharing a patch of grass. Lifting it into a `Config.gapX` is the intended
  end state.)
- **Its whole pure half is plain numbers, never a `CFrame`.** `placement`,
  `bounds`, `boxes` and every clearance are arithmetic over `Config`, and
  `build` is the only function that touches a `CFrame` — which is what lets
  the coplanar audit, the box list and the whole street survey run in
  `tests/luau/combine.luau` with no engine at all.
- **The clearances are printed at startup and warned on if negative**, the
  same argument `auditFences` and `auditEconomy` make: the failure is a
  number, nothing errors, and a street edit that closes one should say so in
  the log rather than in a screenshot six weeks later.
- **`NeighborhoodService` takes two vetoes for it** — `CombineStation.occupies`
  keeps verge grass off the plinth and `.blocksTree` keeps a street tree out
  of it. The tree veto is **sided**, because the machine stands on one
  shoulder and a symmetric veto would cost the far row a tree for a machine
  that is not on it. It vetoes no tree today and is there so that a scale, an
  offset or a moved gap cannot put one through the shell silently.
- **The prompt is `Config.PROMPTS.combine`** — magenta, the Crates tab's own
  hue, because a player who has learned that magenta means the crate economy
  should not have to learn it twice. It keeps its **card** (it is not
  `plain`): a single prompt on an unfamiliar machine is the class the shop
  door and the bin are in, and the verb and glyph are the whole of what says
  what the thing does before anybody holds it. Its range is measured against
  every other prompt on that stretch of verge so nothing can ever be live
  alongside it, which is what lets it keep `E`.
- **The prompt is wired on the SERVER at the moment the part exists**, because
  the station is built during startup and a tag set before parenting never
  fires `GetInstanceAddedSignal` on a peer — the fault that left all four shop
  doors wired to nothing. The client cannot do it for itself.
- **`CombineOpen` carries nothing** and `CombineRequest` carries no price and
  no outcome: the inputs *are* the price, the server re-counts them against
  the save, and `validatePick` rebuilds the entry list from known-good parts
  before a single spare moves. Every argument is checked against the real
  lists — a kind out of `KINDS`, a shelf out of `shelvesFor`, a tier out of
  `Config.RARITY_ORDER` — the same reason `SettingsService` is an allowlist.
- **Both the require and the capability are guarded**, and `build` and
  `start` are pcalled: a machine that fails to build is a bare patch of
  verge, and one that fails to build and takes `Main` with it is every plot
  and no "Ready" in the log.

### The tree, the basket and the storage crate — retired

A residential oak on every unclaimed lawn, a carry basket, a storage crate
and a coin-priced tree-growth ladder once stood behind the Acorn currency
above. All of it is gone: `Shared/AcornTree`, `AcornFill`, `AcornModel`,
`AcornBasket`, `AcornStorage` and `TreeClock`, and the services that drove
them (`TreeService`, `ShakeService`, `ResidentAcorns`), are deleted outright
rather than left dormant. The lawn slot the oak and its crate stood on
(`lawnI`) is free ground again (§11); a save that still names it is shelved
by `DataService.reconcile`, which keeps the ornament and just drops the
retired slot.

**Two shop counters stand in the hallway, and they are the only way to their
shelves (2026-09-23).** `Config.BASE_COUNTERS` is the list — **Gadgets** and
**Guardians** — and `Shared/BaseShopStand` builds one per row: a plinth, a
counter, a roof, a lit fascia carrying the row's own `sign`, a shopkeeper
built by `ResidentModel`, and a **Browse** prompt keyed on `E`. The spots come
from `BaseShopStand.placements`, which returns one CFrame per row rather than
a hardcoded pair — they alternate sides of the doorway and step outward in
pairs, so the first two land exactly where they were measured and a third
costs a Config row rather than an edit at both ends. The counters share the
house's lifetime: parking a hall in `ServerStorage` parks its NPCs and its
prompts with it, and the prompt refuses while the room is parked.

They stopped being decoration the day the HUD basket went Robux-only. A
counter that does not build is not a missing ornament, it is a shelf no
player can reach — so `InteriorService` **pcalls each counter separately**
and warns by name, on the same rule `Decor.prewarm` follows: one dead
counter costs its own shelf, never the room, the plinths or the piggies
standing on them. A press fires `Remotes.ShopDoor` with the row's `tab`, and
the client opens the row's `section` — the Items tab leads with the at-home
kit and the Guardians tab with the nab effects, so a counter scrolls to the
shelf its sign names rather than to the top of a tab about something else.

**The collection now also stands behind the front door (§12, 2026-09-23).**
Every room a hallway has opened carries its own plots, one placement each,
wired through `Shared/IndoorPedestal` to the identical pad and four
prompts (Sell/Take/Place/Snatch) a lawn plinth uses. Its buffered figure
is painted straight onto the collect pad itself, through the same
`PiggyPedestal.buildPadFigure` the lawn pad uses — never on a sign of its
own; a hall placard stood in front of the pedestal for one day and blocked
its own coin emblem, and is retired (designer, 2026-09-23).
`PiggyPedestal.buildPrompts`, `.buildFigure` and `.wirePad` are shared
between the two builders rather than copied, so an indoor plot cannot
drift from the lawn's own rules for what it earns, how it is collected or
how it changes hands. Save slots are one dense array the whole way
through: 1..`Config.PIGGY_LAWN_SLOT_COUNT` are the six lawn plinths, and
`HouseInterior.slotOfPlot`/`.plotOfSlot` number every indoor plot after
them — the array's own width is `Config.PIGGY_SLOT_COUNT` now (the lawn
plus `Config.indoorPlotCeiling()`, the hallway's own rebirth ceiling, §13)
rather than the lawn alone, and `EconomyService`'s accrual loop,
`collectPiggy`, `sellPiggy` and `pedestalRates` are all bounded at that
wider count too, so an indoor pedestal fills, banks and sells exactly like
a lawn one rather than sitting lit and inert. `PlotService.pedestalAt`
answers "where does this slot stand" for a lawn plinth or an indoor plot
alike, and `.setIndoorPedestals` is how `InteriorService` publishes a
room's placements onto the plot the moment it builds them, and clears
them the moment it tears the room down. `HouseInterior.auditCollection`
runs at boot on a scratch save and provokes rather than reads the whole
chain — can the array hold an indoor entry, can a carried piggy be placed
on one, does it earn — so a bound left at the old lawn-only count is
caught once at startup rather than found later as a pad that lights and
refuses.

### Carry ownership

Every successful attach to a stolen piggy records `claimant` (the original
player who grabbed it) and `holder` (the player whose character is carrying
it right now) — the same pair the tug (§5) reads to decide who a completed
nab hands the carry to. `DeliverRequest` is an empty request; the server
checks a living carrier, their current position, activity and the
destination's ownership on every press against the pig's own plot drop-off.
Delivering pays the claimant the normal/revenge coin payout, further
multiplied by their wanted stars (§5, §7); a
different final holder who delivers it instead gets `NAB.keepShare` of the
raw amount with no multipliers, plus the whole item haul. Returning a carry
to its victim restores the full raw amount and pays a non-claimant deliverer
`NAB.bounty` instead, with no robbery bonus. `CarryDelivery` formats these
server-owned choices for the destination card; see §5 for the fuller account
of a robbery's carry, tug and delivery rules.

### Lifetime delivered robberies

`data.robberies` counts one nonempty getaway delivered home against any
player, resident or shop. Coins, partial cracks and skin-only recoveries all
qualify; carrying multiple items or earning a larger payout still counts once.
HeistService consumes the carry before crediting the counter, preventing
repeat requests from counting twice. Failed getaways and empty carries earn
no credit. The count updates before item rewards can trigger a save.

DataService defaults it to zero on new and existing schema-25 saves, retaining
all existing currency totals. Historical `totalStolen` cannot reconstruct a
robbery count. Reconciliation keeps finite nonnegative whole numbers, and
rebirth preserves the count alongside seasonal `claims`. Existing autosave
and final release persist it; no new per-delivery DataStore write is added.
`Config.RAP_SHEET_RANK` defines ranks 0–4 at 0/25/100/400/1,600 deliveries.
`getRapSheetRank` derives the rank from this count; no second counter is saved.
Residential signs show one earned star per rank, or ROBBER RANK 0. The server
publishes `RobberyRank` on the plot, loads it through CosmeticsService on join,
refreshes it after a coin getaway, and clears it on release. The name,
rank and existing boasts have separate rows; shops/residents show no rank.

### The season clock and the nemesis ledger

**The season *ladder* — ranked Acorns earned, with tiers, rewards, a chip on
the plot sign and a third page on the street board — retired with the
currency that fed it.** `SeasonService` used to carry both that ladder and a
separate nemesis ledger; the ladder is gone (`Config.SEASON.tiers`/`.finishes`/
`.first`, `seasonNumber`/`seasonActive`/`seasonTier`/`seasonReward`/
`seasonChipText`/`seasonChipColour`, `Config.SEASON_BOARD`,
`Shared/SeasonBoard.luau`, `PlotService.setSeasonChip`, and the street board's
season page are all deleted). A board that counted zero for everybody forever
is the broken-feature shape this project refuses everywhere else.

**What survived, and why.** `Config.SEASON` (`weeks`/`rest`) and
`Config.seasonIndex`/`Config.seasonEndsAt` are still here because the seasonal
skin **buy-back** claim and the recovery objective's hot-skin window (§5) key
off that same clock, and neither has anything to do with Acorns. The
**nemesis ledger** — `data.nemesis`, `{index, rows}`, rows keyed by the
thief's UserId (`name`, `count`), rolling with the season index — is also
untouched: `SeasonService.recordNemesis(victim, thief)` is called from
`HeistService.deliver` whenever the victim is a player, the smallest row is
dropped at `Config.NEMESIS_ROWS` for a new one, and `nemesisOf` returns the
top row for the plot sign's **NEMESIS** line (`PlotService.setNemesis`,
refreshed on join and on a new ledger entry, cleared on release). Both roll
lazily — a save (or ledger) carrying an older index is rolled the first time
anything reads it, so there is no job to run at a season boundary.
`SeasonService.start` is a deliberate no-op now; the board loop that used to
live there went with the ladder.

**`Config.FINISHES` is currently unobtainable.** A finish (§9) is a
season-tier reward and nothing else has ever granted one, so with the ladder
gone there is no live route to any of the five rows — `Config.auditSeason`
still checks that each stays unpriced, season-only and under a
light-brightness ceiling, but the catalogue itself is dead weight until
something (a job board is the intended home — `docs/PIGGY-COLLECTION-PLAN.md`
§7a) grants one again. See §17.

### Random-outcome boot audits

`Config.auditRandomOutcomes` walks every `Config.CHESTS` row and every pool
entry inside it. It refuses a coin `cost` or a `currency` on a chest; it
requires a positive `robux` and a `productId` **field** on every non-set
chest and refuses a `robux` on a set one; it refuses a coin `cost`, a `pass`
tag or an `unlockRebirths` gate on anything a pool can reach; it refuses a
chest that authorises odds for a tier it cannot stock (`liveOdds` drops an
empty tier and *renormalises*, so authorised odds for one fail completely
silently — the Alien Cache did it with 45 of its 100 points); it checks every
ride's tier has a `RIDE_TIER_SPEED` and carries no `multiplier` of its own;
it sweeps the whole of `Config` for a retired `unlockRebirths`, **exempting
`DOG_COATS`, `HOUSE_TIERS` and `RIDES` by identity** because on those three
it is a live SALE gate on a direct purchase; and it checks pass exclusions,
100% eligible skin theft and that `Config.REBIRTH_CRATES` and every
`Config.CRATE_SECTIONS` entry name real crates.

**The pool check is what makes those three exemptions affordable.** An
identity exemption is all-or-nothing, so the moment one row of an exempt
table entered a crate the gate would go unaudited on exactly the row that
must not have one. Asked of the **pool** instead, it catches a gated row
whichever table it came from, and it catches the next table too.

`Main` prints model figures, warns per violation and catches audit exceptions
without stopping startup. Both audits currently return none.

### One currency, and how it got there

Medals (attendance pay), tokens (the accessory roll's earn-only currency) and
Acorns (a later, single replacement for both, meant to buy crates and set
items) were tried in turn as a **second** currency doing jobs coins should not
— the accessory roll must never be reachable with purchasable coins, the
argument ran, so it needed a currency coins cannot buy. **Schema 17** merged
medals and tokens one-for-one into Acorns (`data.loot`); the accessory roll
retired in the same period as the catalogue it drew from
(`Config.ACCESSORIES`, §9); and once crates stopped being bought with any
*in-game* currency (§3), the reason a second currency existed at all was
gone — a Robux price does not bring it back, because Robux is not a balance
this game holds.
**Schema 29** deletes `data.loot` outright, with the tree that fed it and the
season ladder that ranked it. `Config.MEDALS`, `Config.TOKENS`,
`Config.ROLL_CURRENCY`, `Config.LOOT` and `Config.lootWord` are all gone.
There is one balance in this game, and it is the piggy bank.

---

## 4. The economy

### The pig is unbounded

**`data.coins` has no ceiling (designer decision, 2026-09-21, reaffirmed).**
Nothing clamps a mint, income never stops, and there is no `full` state — the
`Bigger Piggy Bank` upgrade tree is retired outright, along with
`BASE_CAPACITY`, the four `CAPACITY_*` growths, `CAPACITY_BASE_COST`,
`UPGRADE_COST_CEILING`, `REBIRTH_CAPACITY_MULTIPLE`, `Config.getCapacity`,
`getCapacityCost`, `pigRoom` and `fitInPig`. The reset bounds hoarding now,
not the pig — a player is required to rebirth for progress, and rebirth wipes
the balance, so the pig only ever grows between one rebirth and the next.

**What a pig reads as FULL on the lawn is `Config.pigFullAt(rebirths)`** —
the rebirth cash gate, below — not a ceiling. The coin pile inside the till,
the four `Config.MILESTONES` fractions and the delivery coin stream are all
pictures of "how full is it" and still need a denominator; the honest one is
the rebirth gate, because under the old rule the gate *was* one full pig at
the reachable ceiling — "the pig is full" and "you can rebirth" were the same
moment, and still are. Coins banked above that figure are simply a pig that
stays visually full, which is the correct picture of someone who has not
rebirthed yet. Nothing reads this as a limit: no mint clamps against it, no
collect or sale is refused by it.

**Every mint banks in full, and nothing spills.** `Config.fitInPig` — "nothing
puts more in a pig than it holds" — is reversed by the same designer along
with the ceiling it enforced: a delivery, the return bounty, a shop-drop
resale, a daily coin reward, an event payout, a refund, a returned carry (nab,
dog, patrol, voluntary return) and a drone recovery all bank the whole amount.
`HeistDelivered.spilled`, the "spilled" toast wording and `homeWorthPhrase`'s
two room-check endings (*"but your piggy only has room for X"* / *"...is
full, so none of it will fit"*) are dead code now rather than a live path —
kept rather than deleted because a bounded wallet is one designer call away
from coming back, and this is exactly what would need re-deriving.

**The rob badge and the steal card were already capacity-free
before this — a separate, earlier fix (`Config.homeTake` retired in favour of
`Config.homeWorth(vault, fraction, multiplier)`, which never reads a reader's
own room) — so today's change touches nothing about how they print.**

### The till is a display; the lawn pedestals earn

**Coins reach `data.coins` one way now, and it always needs a prompt.**
`Config.PIGGY_LAWN_SLOT_COUNT` lawn pedestals fill their own buffer at
their own rate, capped per-tier (`slotCeiling`), until a **Collect** prompt
on its pad — built by `PiggyPedestal`, whose `CollectPad` the prompt binds
to — banks the whole buffer into `data.coins` at once. **Slot 0, the till
itself — the centre piggy every player already owns — pays nothing at
all** (designer, 2026-09-23: *"the piggy bank displayed as the till should
not earn any money only displayed as the storage… it should also not auto
collect"*). The refusal lives in `Config.piggySlotRate` now — the one
answer to what a placement earns per second — and `EconomyService.slotRateOf`
and `ResidentService.slotEconomy` both forward to it rather than keeping
their own copy, since three readers agreeing by luck is the failure this
file records more often than any other. `Config.collectionRateOf`/
`Config.fullLawn` both sweep from slot 1 rather than slot 0, so the till
carries no rate anywhere a client, the accrual tick or an audit can read
one — the idle side of `Config.auditRobbery` moved with it, since it had
been counting a seventh income source nobody actually earns. Its second
row prints `Config.TILL_LABEL` ("BANK") instead of a figure, in paper
rather than the gold the six pedestals use — gold on that row means coins
per second everywhere else on the lawn, and a row reading +0/s is worse
than a blank one — drawn through the same `PiggyPedestal.nameplate` a
plinth's own name uses, so the till and the six pedestals can never
disagree about where a label hangs or what colour a tier is written in.
This retires the drip the till briefly had (2026-09-22, above): coins were
being added to `data.coins` on every accrual tick with nobody pressing
anything, reported in exactly those words ("I see my coins increasing
automatically"), and every other writer of `data.coins` in the game is an
event a player caused.

**A neighbour's lawn prints its own rates too, off a different source than
a player's.** `PlotService.setPiggyBuffers` used to gate the whole rates
array on `plot.owner`, which a resident plot never has — so every resident
plinth carried a name with a blank row under it from the day residents
were put on the piggy loop (2026-09-22) until this was found. A player's
lawn asks `EconomyService.pedestalRates`, because the friend bonus and
daily boost it folds in are facts about a *person* that `PlotService` may
not require `EconomyService` back to supply; a resident's lawn asks
`Config.piggySlotRate` directly instead, which is exact rather than a
fallback — a resident has neither multiplier, so the plain figure is the
whole answer, and it is the same one `ResidentService` fills its own
buffers at.

**The rule is about the placement, never the piggy.** The same skin that
earns nothing on the till earns its tier rate the moment it is swapped
onto a pedestal — which is the whole reason the swap prompt is worth
pressing. A new save is seeded so this costs nothing on day one:
`DataService.defaults` seats a Classic on the till *and* on lawn slot 1
(`owned = 2`), so a fresh player's income per second is unchanged, it just
now ripens on a pedestal instead of landing straight in the balance. An
existing save is deliberately **not** migrated the same way — seating a
free piggy onto every save with an empty lawn would be a piggy faucet keyed
to emptying your own lawn — so a save with nothing placed earns nothing
until something is (`fillpiggies` on the admin panel, §16). `data.tillBuffer`,
the till's own former buffer field from the 2026-09-22 drip, is retired:
`DataService.reconcile` folds whatever a save was still holding in it into
`data.coins` once, unconditionally, with no schema bump (§13).

### The ladder

**The Earn Faster rung is off the shop, so `data.incomeLevel` is frozen at
its default of 1** (designer, 2026-09-23). The pair used to be "income and
capacity"; capacity is gone (above), and now income has gone from the shop
too — `Config.UPGRADES` never held an `income` row (§5 lists the six trees
that do), so this was always the shop's own **Earn** group tab rather than a
tree, and that whole group tab is retired: `ShopUpgrades.GROUPS` is
`{ defense, offense }` now, two groups, and nothing on either can raise what
a piggy earns per second. **The server path is untouched and now
unreachable from the client** — `PurchaseRequest("income")`,
`Config.getIncomeCost`, `data.incomeLevel` and the `maxIncome` push all still
exist, and `incomeLevel` is still a real multiplier inside
`Config.collectionRate` — but nothing sends the purchase any more, so it sits
at 1 for every player from here on (a save that had already levelled it up
keeps whatever it has; `ProgressionService` still resets it to 1 on every
rebirth, the same as before). **Retiring the save field itself was not done
and is the designer's call**, not this file's. What this leaves as the two
levers on how fast a piggy earns: the piggy's own **tier** (§9,
`Config.getPiggyIncomeRate`) and the **rebirth multiplier**
(`Config.rebirthIncomeFactor`, above).

What follows is the growth curve `incomeLevel` still drives through
`Config.getIncomeRate`/`getIncomeCost` — kept because it is real, running
code, not because a player can still reach it. It runs on **three bands**:

- **Levels 1–20** keep the original growth untouched — that curve was never the
  problem.
- **Levels 21–40** are gentler on both sides, because one curve extended to 40
  fails in both directions (too-fast income trivialises the game; too-fast cost
  means nobody buys the top).
- **Levels 41–60** (`BAND_TOP_2`, `INCOME_GROWTH_C` 1.10, `INCOME_COST_GROWTH_C`
  1.26) exist because the ladder was extended to 60 to let a 1B house fit
  inside a pig that had a ceiling — the capacity half of that reasoning
  retired with the ceiling, but nothing below level 40 needs to move to undo
  it, so the income band stays at 60 rather than being cut back. Derivation
  and pacing in `docs/LATE-GAME-ECONOMY-PLAN.md`; pinned by `tests/luau/ladder.luau`.

`Config.banded()` writes it as *"band A to the top, then band B beyond, then
band C"* rather than branching between three formulas, so a seam is exactly
one growth-rate multiplier and cannot develop a step.

**Costs are indexed by the level you are LEAVING**, so they run one behind the
value table: `getIncomeCost(20)` is the price of reaching 21.

**Costs are the pure geometric curve, unclamped.** `Config.UPGRADE_COST_CEILING`
used to `math.min` every rung against a share of the pig that had to pay for
it — the deadlock this file already records in detail (`getIncomeCost(20)`
outrunning the pig at capacity level 17 of 20) only existed because the wallet
was bounded: with no ceiling, a price above your rate is an ordinary WAIT
rather than a WALL, so the clamp is retired along with it. What that costs:
late rungs are dearer than the clamped figures nobody could pay were cheap —
level 20 is 1,653,340 against a clamped 1,643,483 and level 40 is 168.2M
against 53.3M — and the "17 days at 2h/day" climb this file used to quote was
measured *with* the clamp and is void rather than re-measured.

**`Config.auditEconomy()` no longer checks that a price fits in a pig — there
is no pig to fail to fit in.** What it still checks is structural: no
catalogue carries a retired ownership gate (`unlockRebirths`); every priced
row's `cost` is a non-negative number; every `HOUSE_TIERS` row has a unique
`id` and every `Config.HOUSE_LEGACY_ORDER` entry resolves to one; a house is
either priced or `earned`, never both or neither, and priced ones sort
cheapest-first; and `Config.REBIRTH_CASH_GATE` (below) has a positive,
non-decreasing entry for every rebirth up to `Config.rebirthsToMax()`. `Main`
runs it once at startup and warns (never throws) per problem, in Studio as
well as live; it currently returns none.

**Read the ceiling through `Config.maxLevel(rebirths)`, never from a constant.**
It is `20 + 2 per rebirth`, capped at `ABSOLUTE_MAX_LEVEL` (60, reached at
rebirth 20 — `Config.rebirthsToMax()`). `EconomyService` pushes its answer as
`maxIncome` — there is no `maxCapacity` any more — and the client draws the
ladder from it, so both ends agree by construction.

**Hitting that ceiling is not always MAXED, which used to matter to a
player and now only matters to the server.** `Config.rebirthOpensMore(maxLevel)`
is true whenever `maxLevel < Config.ABSOLUTE_MAX_LEVEL` — i.e. whenever one more
rebirth would open further rungs of income — and it used to gate a live
surface: the shop's Upgrades tab read it to swap a maxed-but-gated Earn row
from MAX LEVEL to NEEDS REBIRTH. That row is gone with the Earn group (above),
so the only reader left is `EconomyService`'s own purchase refusal — *"Rebirth
to unlock more levels."* rather than *"Already at max level."* — which fires
only if something still sends `PurchaseRequest("income")`, and nothing in the
shop does. The six other upgrade trees have a fixed `max` no rebirth ever
lifts, so MAX LEVEL there was always unconditional.

### Rebirth

Wipes income and **both upgrade trees**. Keeps everything cosmetic —
skins, effects, houses, decorations, accessories, gear, rides and bones.

- **The gate used to be a multiple of your reachable capacity, and is a frozen
  table now that capacity is gone.** A flat gate evaporated as the economy grew
  (measured: 334 seconds of income the first time you capped the ladder, eight
  seconds by rebirth 10) and a geometric one diverged into a wall; capacity was
  the one anchor that rode the same curve the player's own economy rode, so it
  could do neither — which is exactly the argument that broke the day capacity
  retired. `Config.REBIRTH_CASH_GATE[r]` is that reasoning's old output
  (`getCapacity(maxLevel(r)) * REBIRTH_CAPACITY_MULTIPLE`) **frozen as
  literals** for every rebirth from 0 to `Config.rebirthsToMax()` — nothing got
  easier or harder by accident — and it is flat at the top row past the last
  rebirth that opens a level, same as the derivation it replaced.
  `Config.getRebirthThreshold(rebirths)` reads it; `Config.pigFullAt` (above)
  is the same function under a different name. **The designer's actual gate is
  "own specific piggies plus a cash amount", with no piggy numbers given yet**
  — `Config.rebirthPiggyGate(data)` is the hook, and it returns `true`
  unconditionally until it is filled in, so today the gate is cash alone.
  `ProgressionService.canRebirth` and the `rebirthThreshold`/`rebirthReady`
  push both call it, so the button, the page and the refusal move together the
  day it is written. Simulated against the real ladder and gate functions —
  no robbing, no offline accrual, no dailies — a pure idler still reaches
  rebirth 10 / level 40 in about **1.4 days** of continuous play, roughly 17
  days at two hours a day; that simulation predates the capacity removal and
  has not been re-run against the frozen table, though the table is by
  construction identical to what it replaced.
- **The income factor is `Config.rebirthIncomeFactor`**: +0.12 per rebirth through
  rebirth 10 and +0.08 beyond (`REBIRTH_MULTIPLIER_TAPER`), so the top of the game is
  3.0× rather than 3.4×. **`Config.rebirthMultipleText(rebirths)` is the one
  player-facing reading of it now** — "1x", "1.12x", "3x", two decimals with
  trailing zeros trimmed, because the 0.08 taper past rebirth 10 collides at
  one decimal (2.36 and 2.44 both round to "2.4"). Both the rebirth page's own
  GAIN row and `ProgressionService`'s "REBIRTH n!" toast read this one
  formatter, so the page and the server share one vocabulary rather than two.
  `Config.rebirthBonusPercent` (the old "+220%" reading) still exists and
  still backs `tests/luau/ladder.luau`, but nothing player-facing calls it any
  more.
- **Every rebirth opens a free crate, and every `Config.REBIRTH_LEGENDARY_EVERY`th
  one opens a LEGENDARY** (designer, 2026-09-23). It used to be a Legendary
  crate at every rebirth, which made the reward flat — the best crate in the
  game at rebirth one and again at rebirth twenty, so pressing the button
  harder bought nothing. The rare rung is `Config.REBIRTH_CRATES_RARE` and the
  legendary rung is `Config.REBIRTH_CRATES`; the cadence is counted on the
  **already-incremented** rebirth count, so the fifth rebirth is the one a
  player would count on their fingers.
- **The Guardian Crate came OFF the rebirth rung the same day it went on,
  and the guardian ladder is its own thing now** (designer, 2026-09-23).
  `Config.REBIRTH_CRATES_RARE` is `{ "ograre" }` (and `REBIRTH_CRATES` is `{ "oglegendary" }`) — piggy crates
  only — so a rebirth opens a piggy crate and never a guardian one. Instead
  `Config.DOG_COATS` (§9) carries its own coins-behind-a-rebirth pair —
  **Husky** at rebirth 1, **Mastiff** at rebirth 2 — beside free **Scrappy**,
  so the guardian ladder is bought directly rather than rolled for at every
  rebirth. What is left in the **paid** Guardian Crate is the five coats that
  are not on that ladder: Gorilla, Raptor, Triceratops, Dire Wolf and
  Cerberus, `rare`/`epic`/`legendary` with no common rung.
  - **What that puts back is the exposure the earlier rung was built to close,
    and it is recorded rather than argued away.** A random skin is safe to
    sell because the SKIN is obtainable free — every skin in a priced pool is
    stealable (§5), so its coin sale value is a property of the item rather
    than of the purchase. A coat is not stealable and no wild piggy wears
    one, so the five crate-only coats are purchased content carrying a coin
    `sellBasis` again — "a Robux purchase may grant an item, never its coin
    value" (§15) broken with one extra step. It is **latent**:
    `Shared/Inventory` has no coat tab and `EconomyService.sellPiggy` answers
    only for placements, so nothing in the game currently reaches a coat
    sale — `tests/luau/crates.luau` prints the exposure on every run rather
    than failing on it. The day a coat sale ships, the fix is to refuse it,
    not to put the crate back on a rebirth rung.
- **Which crate is asked of `ChestService.pickOpenable`, not of `Config`.**
  `Config.rebirthCratesOpen` tests whether a shelf's legendary keys are all
  owned, which was the right question while a crate could pay a duplicate;
  now an exhausted pool is refused at every tier, so the honest question is
  the predicate that actually decides. **The legendary shelf is the fallback**
  when no rare one will open, never nothing — without it, clearing the cheap
  shelves would silently cost four rebirths out of five their reward. With
  nothing left anywhere the rebirth toast **says** the collection is complete
  rather than silently paying zero: a crate has no price to fall back to.
  A duplicate cannot come out of it at all now (§3).
- **Bronze, Gold Leaf and Diamond are Piggy Originals crate skins.** Their
  explicit rarities remain; they are now stealable. Existing earned ownership
  is preserved by the schema-25 migration (§13), not by rebirth-count gates.
- **The plot fires a firework show, sized to the rebirth.**
  `PlotService.fireFireworks` writes `Config.PLOT_FIREWORK_RANK_ATTRIBUTE`
  (which rebirth this was) before bumping `Config.PLOT_FIREWORK_ATTRIBUTE` (a
  counter, never a flag or timestamp — two rebirths in one session must not
  collide on a single changed-signal) — after the plot's own teardown, so the
  show goes up over the level-0 slab the player has just paid for.
  `Shared/Fireworks.luau` is a client-side animator in the same shape as the
  animated skins, the moat and `HouseFX`: the server publishes those two
  attributes and never touches the show again, and every client that can see
  the plot builds it for itself from `Config.FIREWORKS`. Shell count is
  `Config.fireworkShells(rebirths)`, clamped at `.maxShells`, so a tenth
  rebirth is visibly a bigger event than a first. Nothing it builds collides,
  answers a query, casts a shadow or touches the screen — the show is ninety
  studs up in the world, loudest to whoever chooses to look. Both attributes
  are cleared (not zeroed) on `PlotService.release`, since `Fireworks` refuses
  a non-number outright and a release must never be able to trigger a show.
- **The explainer page comes BEFORE the button, every rebirth, not just the
  first.** `Shared/Rebirth.luau`. It used to open automatically only on the
  first rebirth and let the HUD button fire the remote directly after that —
  a confirmation nobody reads is worse than none, in theory — which in
  practice meant the biggest button in the game silently reset a player's
  coins and every upgrade on one tap from rebirth two onward, with nothing on
  screen first. Only the page's own REBIRTH TO N sends the request now, on
  every rebirth, and the tap-through objection is answered by what the page
  *says* (a fresh before/after multiplier every time) rather than by skipping
  it.
- **The page is ONE LIST now, not a grid** (designer, 2026-09-23): three
  `sectionCard` bands of plain rows, one column, read top to bottom in the
  order the trade happens in a child's head. It replaced three illustrated
  benefit cards in a two-column grid, an "Unlocks:" strip, a collapsible
  POSSIBLE REWARDS list printing real crate odds, and RESETS sitting beside
  YOU KEEP with a second collapsible inside one of them — five shapes and two
  expanders on the one page in the game that has to explain an irreversible
  decision before it happens, reported as far too busy. The rule it replaced
  them with: **a fact on this page is a row.**
  - **YOU GAIN** — the permanent coin multiplier as a before/after
    (`Config.rebirthMultipleText`, above), a free-crate row naming the exact
    crate (or "Rare crate"/"Legendary crate" when the server's own
    `ChestService.pickOpenable` could choose either) and omitted outright once
    nothing is left to open, and a "new things in the shop" row naming up to
    `Rebirth.UNLOCK_CAP` (3) of whatever the *next* rebirth unlocks —
    `Rebirth.unlocksAt` walks the pushed house/ride/coat catalogues' own
    `unlockRebirths` fields rather than reading `Config` directly, so it can
    never name a row the server has not published yet. The retired "higher
    upgrade limit" tile went with the Earn Faster rung it described (§4, "The
    ladder", above) — a benefit nothing could spend.
  - **YOU KEEP** — four fixed rows stating the *rule* (everything collected;
    house and garden; pets, rides and items; your rebirths) rather than
    counting today's inventory, because a promise has to be total and a count
    read off a stale push can disagree with the server.
  - **STARTS OVER** — the real coin figure, X → 0, and (only if anything was
    bought) the real upgrade levels reset, naming up to three trees by name in
    defence-then-offence order. The retired "Earn Faster / Lv N → 1" row could
    only ever have read "Lv 1 → 1" now that nothing raises that level (§4,
    "The ladder", above), so it is gone with the rung.
  - Below the three bands, a **coins-needed** bar against
    `Config.getRebirthThreshold` (the cash gate), and a footer of **NOT YET**
    / **REBIRTH TO N**. **The page stays open through a state change** — a
    robbery or a purchase dropping coins under the requirement used to close
    it; now the requirement row repaints and the confirm disables instead, so
    the page never vanishes from under a reader. It closes only when the
    rebirth count actually rises.

### Offline

**An absence fills the pedestal buffers, never the balance directly.**
`EconomyService.applyOfflineIncome` runs the same per-slot loop the live
tick does (above) against the elapsed time since `lastSave`, capped at
`Config.OFFLINE_CAP_SECONDS` — but each buffer still stops at its own
`slotCeiling`, which binds first for almost any real absence, so the
eight-hour cap decides very little a player will ever actually meet.
Nothing lands in `data.coins` on its own: the join toast names the
pedestals rather than the balance ("Your piggies earned N coins while you
were away. Collect it from your pedestals."), and a returning player still
walks the lawn to bank it. The friend bonus does **not** apply to offline
accrual — your friends were not in the server while you were asleep — and
neither does the daily boost, which multiplies the live drip only.

**Where the numbers live:** `Config.BASE_INCOME`,
`INCOME_GROWTH`(`_B`/`_C`), the matching `*_COST_GROWTH`,
`BAND_TOP`(`_2`), `ABSOLUTE_MAX_LEVEL`, `LEVELS_PER_REBIRTH`,
`REBIRTH_MULTIPLIER`(`_TAPER`), `REBIRTH_CASH_GATE`, `OFFLINE_CAP_SECONDS`,
`FRIEND_BONUS_*`.

---

## 5. The heist

The whole risk of this game lives in **the run home**.

**A victim is a player or a resident.** Every plot nobody has claimed carries
a `ResidentService.Resident`: a name (`Config.getResidentName`, indexed by
plot so a house keeps its identity across an owner arriving and leaving), a
piggy bank holding `Config.RESIDENTS.pigSeconds` of its own income
(`Config.getIncomeRate` at a level derived from the humans in the server —
**a resident's pig is still bounded even though a player's is not** (§4),
because a resident is the non-player robbery supply the audit below is
measured against, and an unbounded one would stop meaning anything as a
target; `ResidentService.getCapacity` is that bound and has nothing to do
with the retired player capacity tree), and
fence/lock/house levels derived from a level of its own, plus the same guard
dog every plot has (`Config.DOG_LEVEL` — see §5's defence tree note above;
there is no `dogPerLevels`, because the dog no longer ladders with anything).
`ResidentService`
seats one at startup and whenever a plot is released, and evicts it the
instant a player claims that plot (`PlotService.onClaim`/`.onRelease` — a
registry hook rather than a require, the same shape as `registerBounceVeto`).

**A resident house is seated on an *unclaimed* plot, so the supply of robbable
houses is `Config.PLOT_COUNT - players online`.** `Config.PLOT_COUNT` is now
bigger than `Config.MAX_PLAYERS` **on purpose** — 10 plots
(`Config.PLOTS_PER_ROW`, five a side) against 8 players — so that supply can
never reach zero: the extra column guarantees **two** resident houses that can
never be moved into at *any* population, however full the server. It is
bought with plots rather than with players — an earlier attempt opened the
same gap by capping `MAX_PLAYERS` to 6 against 8 plots instead, and that was
**rejected**, because it buys supply by removing children from the street
(§11, `MaxPlayers`).

**Four more victims that can never be evicted at all: a strongroom in every
shop.** `Config.LOSS_CAP` means player-versus-player robbing can never take
over from either of these at any population. `Config.SHOPS` is the floor that
survives a full server on its own: each of the four shops on the verge (§11)
is built around a **vault plot**, an ordinary `Plot` that carries a `shop`
field naming its tab — `PlotService.assign` skips any plot with one, so it can
never be handed to a player and `ResidentService` is never asked to evict it.
`PlotService.start` builds the `Config.PLOT_COUNT` house plots first and then
one shop plot per `Config.SHOPS` entry, indexed `PLOT_COUNT + i` so the two
spaces can't collide. A shop plot has no fence, no yard
(`PlotService.yardContaining` skips one outright — the verge it stands on is
street) and no garden; `ResidentService.applyStyle`'s `plot.shop` branch
ladders only its **Vault Lock**, off the resident's *style* level (below)
rather than its income level — the one defence that is still honest on a
shop counter and the one casing (below) reads. A tier-0 guard dog is built and
hidden rather than omitted, purely so the seven places that read `plot.dog`
stay safe.

**The shopkeeper is the shop's guard dog — its second defence, not a fourth
one.** A house has a fence, a dog, a lock and a garden; a shop plot ladders
only the lock, above, and for a while that left the figure behind the
counter watching a robbery and doing nothing. `HeistService.releaseDog` — the
one function every dog-release in the game already goes through — opens
with a `plot.shop` branch that calls `ResidentService.alertShopkeeper`
instead of `GuardDog.chase`, so the shopkeeper inherits all three of that
function's callers for nothing. It reacts to exactly what a real dog reacts
to on the loud path — a **missed crack slice** — and never to
a clean crack or to footsteps: the footstep watcher only reaches
`releaseDog` behind `GuardDog.isWatching`, which tests `level > 0`, and every
shop's dog is tier 0, so walking into the room a thief has to enter to reach
the vault can never itself start a chase. That exclusion is deliberate
rather than incidental: `Config.auditRobbery` (above) models an *upper
bound* on optimal play with no defender at all, so a shopkeeper who answered
a clean crack would quietly reprice the four vaults that carry the resident
floor at a full server with nothing in the audit moving to say so. Reacting
only to the loud paths keeps the audit correctly blind rather than
accidentally blind.

`Config.SHOPKEEPER` gives the chase its own numbers, at the officer's own
speed (§7 — between a carrying thief and a free player, so delivering is
still the answer) rather than a new one: a catch radius sized against a
twelve-stud room rather than a sixty-four-stud lawn, a `wakeDelay` before
they move (the same beat `Config.DOG_WATCH.wakeDelay` gives a real dog, so a
thief hears the noise and can still choose to bail), a `maxChase`, and a
hard `giveUp` leash in studs — a shop stands on the verge of a long street,
so a clock alone would strand a shopkeeper outside somebody's house at the
far end. `ResidentService.registerCatch` (filled by `Main` with
`HeistService.shopkeeperCatch`, the same registry shape `onClaim`/`onRelease`
already use, because `HeistService` requires `ResidentService`) asks whether
the thief is carrying exactly where a real dog does — at the *catch*, never
the alarm, since a shopkeeper set off by a fumble may arrive at someone who
has since banked three more slices — and ends the same two ways:
`HeistService.nab`/`.scare` both take an optional `catcher: string?` now, so
the toast reads "The shopkeeper saw you off!" rather than naming a dog that
does not exist on a plot with none.

**The money moved off the forecourt and into the building.** There used to be
a robbable piggy bank standing on a paving apron in front of each shop; now
`Shared/VaultModel.luau` builds a strongroom on the unit's own *back* wall —
carcass, mouth, jamb, a stack of `Config.COIN_COUNT` gold bars and an open
door with a dial seat — and `PiggyBank.buildVault` wraps it in exactly the
`Refs` a piggy bank returns, so every reader of `plot.piggy` (the steal
prompt, the rob badge, the fill, the dial, the alarm) runs
unmodified on a different set of parts; the one new field is `Refs.vault`,
read only by the three functions that dress a piggy — skin, accessories,
effect — which return early for it. The door stands **open** rather than
shut: a shut vault is a better picture and a worse readout, and the stack of
bars visibly drains as a thief works it, exactly like the coin pile on a
lawn. The client finds a plot's money by *name* in three places (the steal
prompt, the rob badge, the skin animator), and a house's is called
`PiggyBank` where a shop's is `ShopVault` — `Config.PLOT_BANK_NAMES` and
`Config.waitForPlotBank` are the one place that knows both, so nothing else
has to.

**Robbing one means going inside, and the range is the room rather than a
distance.** A
`ProximityPrompt` measures to a part's centre, and a vault on a
0.8-stud-thick back wall is two studs from the grass behind the building — no
activation distance can admit the whole room and exclude the strip right
behind it, and `RequiresLineOfSight` runs from the *camera*, which sits
behind a player who has just stepped through the door. `Config.shopRoomHolds`
is a rectangle in the unit's own frame instead (`Config.SHOP_UNIT`, padded by
`Config.SHOP_ROOM_SLACK`), checked when an attempt opens and polled for as
long as it runs; failing it refuses out loud — *"That vault is inside the
shop. Go in."* Going inside also changes the getaway, and in the direction
that costs the thief less: a shop's back wall faces the *houses*, so the walk
in moves the target **closer** to every drop-off on the street rather than
further from it. `Config.shopVaultRunStuds()` derives the carry from where
the vault actually stands (about 23 studs against a house's 53) instead of a
pinned figure, which is what caught the original plan assuming the opposite.

Its pig is smaller and its cycle shorter than a house's —
`Config.shopVaultPigSeconds()` derives it from the ratio of the two cycles,
scaled again by `Config.SHOP_VAULT_DISCOUNT` (**0.70** — a shop has no dog to
get past and a much shorter carry than a house, so it should and does pay
less; solved so a vault pays close to a house's rate and never more, which is
what keeps a thief working the whole street instead of camping the four
easiest targets on it). It is named after its shop (`ResidentService`'s
`shopName`) and never leaves the counter to rob a neighbour. Otherwise a shop
vault is a resource exactly like a house resident — no loss cap, no revenge
marker, no board — but the crack, the getaway and the rap sheet are
identical, and a delivery against one still counts toward Most Wanted (§7).

**A completed crack on a shop vault can hand over an item off that shop's own
shelves** (`Config.SHOP_VAULT_DROP`) — per
*completed* run, never per slice, so bailing early is never rewarded with
one. PIGGY OUTFITTERS, HOME & GARDEN and WHEELS & KIT drop an unowned
skin/effect, decoration or ride respectively, through
`SetService.grant`, weighted on `Config.RARITIES`. UPGRADES sells upgrade
*levels*, which cannot drop, so it drops a **consumable** instead — bones and
gadgets weighted by the inverse of what they cost, so the plunger and the dog
bone turn up often and the Golden Bone is a rare prize rather than a faucet.
`HeistService.registerStockPusher` is a registry `Main` fills with
`BoneService.push`/`GadgetService.push`, so a dropped consumable reaches the
hot bar the same push cycle it lands in.

The per-shop chances are **10% Piggy Outfitters, 8% Home & Garden, 3% Wheels
& Kit, and 20% Upgrades**. Wheels & Kit also requires robbery rank 2
(100 completed deliveries). `rollShopDrop` reads the saved count on the server
and silently refuses ineligible thieves before any random roll or payout,
including duplicate resale. Unknown shop keys and missing player data refuse
without awarding anything. `auditSkinSteal` checks that player skin theft is
more likely than the largest shop drop chance. A new `shopdrops` suite runs
the real reward function with isolated service doubles, including rank gates,
all four rates, carried rewards, resale, and stock notifications.

**The crack panel shows the actual bonus odds.** `CrackState.loot` describes
the current target: overall item chance for shops, plus Common/Rare/Epic/
Legendary percentages *conditional on an item dropping*. Rank-locked Wheels
& Kit shows 0% and its unlock requirement. Eligible player skins show 100%
on clean completion; ineligible/owned/capped/in-transit skins show 0% and a
reason. Resident piggies are coins-only. Player previews and theft share
`skinLootChoice`; `Config.shopLootOdds` supplies both shop displays and rolls.
Ownership changes the unowned pool and thus its rarity percentages.

The designer approved Volt Scrambler as Legendary. With all five shop rides
unowned, conditional tiers are 76.63% Common, 16.09% Rare, 5.75% Epic and
1.53% Legendary; the overall ride-drop chance remains 3%. The event-only
Hoverdisc stays out of this pool.

**Discovery uses a compact reel while the player can keep moving.** The
server sends `RobberyLoot` only after committing the selected reward or carry
entry. Its pool and winner drive real shop-model previews, a decelerating
2.5-second reel and a rarity-coloured result. Carried items say GET IT HOME;
consumables/direct grants say ADDED TO YOUR INVENTORY; duplicate resale names
the coin payout. This presentation grants nothing and has no full-screen
input blocker. `RobberyLoot.luau` owns responsive placement, queued reveals
and cleanup. Native phone preview fixtures are in `tests/studio` and screenshots
in `assets/robbery-ui`; full multiplayer getaway verification remains open.

**A drop that would repeat pays coins instead of nothing.** The three item
tabs roll from an *unowned* pool first, so a drop is real progress for as
long as progress is possible; once a thief owns everything a tab can give,
`rollShopDrop` falls back to a second pool of the *owned* items, weighted by
the same `Config.RARITIES` odds, and pays `Config.sellValue` of whichever one
it lands on straight into the pig — capped at the room left like every other
mint (§4), naming the item and saying it sold rather than handing back
nothing; a full pig sells it for nothing and says so. It pays coins rather
than a **spare** on purpose: a spare is `Config.COMBINE` fuel, and a shop
drop that produced one would be a second, cheaper faucet for it. (Since
2026-09-23 no crate mints a spare at all, §3 — so the only sources are a
theft haul and this refusing to be one.)

Together, `Config.RESIDENT_FLOOR` — the four shop vaults plus the two
guaranteed resident houses, six victims — is the non-player supply that never
runs dry, at any population.

**A resident's pig still tracks the server, and — since 2026-09-23 — its
look no longer does.** Each rolls a fixed `offset` — a *negative* number of
levels below the server's average `incomeLevel` (`currentLevel()`), never
above it — and keeps that offset for as long as it stands, so the whole
row's *pig sizes* still rise together as players level up rather than
converging on one number the moment anybody does. `pickOffset`
(`Config.RESIDENTS.levelSpread`, 6) guarantees `easyCount` (2) houses
seated at the bottom of the spread, for a player with no upgrades, and at
least one at the top of it (offset 0) — **downward only, and
load-bearing**: a resident's pig is `RESIDENTS.pigSeconds` of its *own*
income, so one level above the thief is worth `INCOME_GROWTH` more, and a
thief always robs the richest house on offer. Measured against
`Config.auditRobbery`'s own ceiling, a single level above parity pushes a
five-star thief's return well past the ceiling — houses-only, the case it was
originally derived from — so the peer-level house is the **ceiling** of the
street, never a rung in the middle of it. `Config.robberyFigures()` prints
the current figures rather than this file copying them; `HEIST_PAYOUT` and
`RESIDENTS.pigSeconds` were both re-solved 2026-09-22 alongside the
spree-to-stars rename below, and the idle side of the same audit moved
again 2026-09-23 when the till stopped earning (§4) — exactly the kind of
change that moves these numbers, and why this file does not copy them.
With the shop vaults in the mix, `robberyRates` returns the weighted mean
of both target classes, so the mixed step reads lower than the
houses-only one — the conclusion is unchanged, because +1 still clears or
sits on `ROBBERY_ADVANTAGE.max`, which is also the population `auditRobbery`
itself measures at (above), so guaranteeing one keeps the audited street and
the real one the same street.

**What a house *looks like* is a second, independent roll now** (designer,
2026-09-23: seeing every neighbour bare, or every neighbour upgraded, in
step with the player, "isn't natural" — every ladder used to hang off the
same `incomeLevel` as the pig, so the day a player bought a fence the whole
street grew one too). The fence, the lock, the house tier and the garden
are driven by `Resident.styleLevel`, rolled once at `seat` by `pickStyle()`
and held until the plot is released and re-seated — never re-read on a
tick, and never a function of a player's own level. `pickStyle` draws
uniformly over `0..Config.residentStyleMax()`, a **derived** ceiling (the
lowest level at which every defence ladder — fence, lock, garden — is
already maxed, so growing one of those ladders moves the band with it
rather than stranding it); `Config.RESIDENTS.style` guarantees its own
`easyCount` (2) houses pinned to the bottom of that band and `topCount`
(1) to the top, counted against the residents already standing the same
way `pickOffset` is. `ResidentService.applyStyle` is what actually
rebuilds the fence, the lock, the house and the garden (and a shop's
Vault Lock) off `styleLevel`; `applyLevel` calls it only when
`resident.styleShown ~= resident.styleLevel`, so a neighbour's *look* is
rebuilt once, on seating, rather than on every income tick the way it used
to be. This is what stops an unclaimed street moving in lockstep with the
player: at server level 0, the old offset clamped every resident to the
same floor, so a brand-new server and a freshly-rebirthed veteran's server
both showed a row of identical bare plots with no fence, no lock and no
garden on any of them; a bare lawn and a fully-defended one can now stand
side by side from the very first resident seated.

A richer-*looking* resident still carries a fuller **garden** — a
shuffled, per-resident order over every lawn-zone key in
`Config.DECOR_ITEMS` (`rollGarden`), planted as a growing *prefix* of that
order as the resident's **style** level climbs (`decorPerLevels`/
`decorMax`, the same per-level shape its fence/lock/house ladders share —
the dog is fixed and does not ladder, above) — so a bare lawn still reads
as the least-defended house on the street and a crowded one as the
best-defended. **What it no longer promises is the pig behind it**: a
resident's pig size and its style level are now two independent draws, so
a crowded garden does not mean a fat pig the way it once did by design.
The rob badge (below) still prints the real pile in gold over every
piggy, which is what keeps that loss affordable — a thief reads what a
house is *worth* from the pavement either way, just no longer from its
fence.

**Every resident also wears a piggy skin**, drawn once per plot from a
shuffled, per-*server* bag (`ResidentService.drawSkin`, excluding anything
`Config.isEarnedElsewhere` — a pass or set skin has no business on scenery
nobody paid for) rather than tied to the plot itself, so a house's pig
changes colour between sessions while its name does not. A skin confers
nothing; this exists so an unclaimed street reads as occupied houses rather
than a row of identical default pigs, and so the **Victim Shelf** trophy
(§9) — one little pig per skin robbed — is reachable by a single player at
all. A shop vault keeps the default skin; `applyLevel` returns before a skin
is ever applied to one, because a vault has no skin to cycle.

`HeistService` is written against `Target = Player | ResidentService.Resident`
rather than `Player`; `typeof(t) == "Instance"` is the whole discriminator, so
nothing else in the file branches on which kind it has. **A resident is a
resource, never a rival:** no `Config.LOSS_CAP`, no revenge marker, no
notification, no nemesis ledger (§3), no place on the street board or the
Most Wanted poster — but the
take, the crack, the carry penalty, the getaway, the dog, the nab, the patrol
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
   **Sneak** offence rung (below — it buys *speed* for the approach, never
   stealth; which dogs a given tiptoe still wakes is the dog tier's own
   `notice`). **Allowed while carrying now** — `HeistService.setTiptoe` no
   longer refuses it, reversing the rule that the getaway must always be
   loud: a tiptoeing carrier still moves under every breed's `notice` (18 x
   0.35 = 6.3 studs/sec), so the quiet getaway is real, it is just slow —
   about 8.4s for the 53-stud run home against 2.9s at ordinary carry speed.
   Still refused outright while **climbing** (two slows multiplied is a trap
   nobody designed, above). It plays as
   its own gait now, not the ordinary walk cycle slowed down —
   `Shared/SneakWalk.luau`, a looping animation published **per viewer** off
   `Config.SNEAK_ATTRIBUTE` (on the character, not the `TiptoeState` remote,
   which only ever told the sneaker themselves) and rate-driven by the
   character's own measured horizontal speed rather than a clock, so the
   Sneak rung, a fence snag and a stun are all inherited with no balance
   code of its own. The attribute is written in `HeistService.refreshSpeed`
   off the same test `currentSpeed` uses — whether the tiptoe is actually *in
   effect*, not merely asked for — so it also drops correctly the moment a
   climb starts, with nobody having pressed anything.
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
   reports a tap with no claim about whether it landed. **On a crack, a missed
   slice — and only a missed slice — sounds the alarm**
   (`Config.CRACK_ALARM_ON_MISS`) — it tells the victim they're being robbed
   and releases the guard dog (below); a clean run banks every slice in total
   silence.

   **The smash — a second, lock-blind way into the same pig — is retired**
   (designer, 2026-09-23: "lets remove the smash prompt and only keep the
   crack lock for simplicity"). `Config.SMASH`, `HeistService.smash` and its
   prompt card are gone; a pig is cracked or left alone. What its design rule
   is worth keeping: a faster way into a pig has to pay strictly less per
   second than a clean crack, or `Config.auditRobbery` stops being an upper
   bound on optimal play — the smash ran two slices rather than three because
   three would have paid about 92% of a clean crack's rate for 45% of the
   exposure, at which point nobody would ever crack again. Losing the smash
   also means the Vault Lock and the Guard Dog no longer answer two different
   attacks (below, under the guard dog) — a dog now matters on a fumbled
   slice and on footsteps only.
3. **Carry.** You move at `CARRY_SPEED_MULTIPLIER` of base, and a banner says so
   to the whole street. The thief is posed **holding** the loot — a money bag
   now rather than a miniature of the victim's pig (designer decision,
   2026-09-22, below) — and *how* they hold it depends on **which** load it is
   (designer, 2026-09-23): the coin sack is slung one-armed over the right
   shoulder, the left arm left to the run and the torso leant back to counter
   the load (the **sling**), while a hauled piggy (§3, `PiggyHaulService`)
   stays hugged with both arms wrapped round it against the chest (the
   **hug**, and the coin sack's own carry for part of a day before the sling
   took over) — rather than either load jogging along behind the thief welded
   stationary in front of them with their arms at their sides.
   `Shared/CarryPose.luau` (§2, §10) holds both poses as `CarryPose.KINDS`,
   keyed by `Config.CARRY_KIND_ATTRIBUTE` ("hug" or "sling") written onto the
   loot model itself by whichever service built it, so the picture every
   client draws and the seat the server pivoted into are one answer; a model
   naming neither kind is hugged. Either kind drives only the
   torso, head and arms (the sling's own spec carries no left-arm row at all,
   so the run keeps that one too), so the ordinary run cycle keeps the legs
   underneath it unmodified; `HumanoidRootPart` and `LowerTorso` are named in
   the pose purely as the path to the arms and carry `Pose.Weight = 0`, which
   is what stops them freezing the pelvis. `HeistService.attachLoot` welds the
   coin sack to the thief's right hand through `CarryPose.anchor(character,
   "sling")` (2026-09-23) — the same function `PiggyHaulService`'s own
   piggy-snatch carry calls with `"hug"` (§3) —
   which hands back the hand and that kind's own `HAND_HOLD` on an R15 rig, or
   the root and its own root-space `HOLD` on anything without one; it used to
   weld to the root at `HOLD` alone, which let the palms slide against a load
   that stood perfectly still through every stride. The hold position and
   the pose are one measurement either way, not two that could disagree.
   Every client poses every
   carrying player it can see, not only its own, by looking for a child named
   `Config.LOOT_MODEL_NAME` on that player's character and reading which kind
   off its `CARRY_KIND_ATTRIBUTE`; there is no remote for either question,
   because the loot model's presence and its own attribute already answer
   both. Rides are disabled **server-wide** while loot is in transit —
   otherwise a bystander on a scrambler runs down a thief on foot.
4. **Deliver** to your own drop-off, or get **nabbed** — a completed tug
   transfers the intact carry to the winning player (below).

**The coin carry is a money bag, not a little pig — a deliberate reversal on
2026-09-22.** `HeistService.attachLoot` used to hand a thief a miniature of
the *victim's own piggy*, wearing the victim's own skin; a thief cracks the
bank for coins now, and the pedestal piggies — the things that ARE carried
off as themselves — have their own snatch carry in `PiggyHaulService` (§3),
so the coin carry's picture moved to match what it actually steals. It is
`UpgradePreview.build("sack", thiefSackLevel)` — the Bigger Sack upgrade
card's own model at the thief's own sack level, so a bigger sack is visibly a
bigger bag on the street, the shop card and the getaway drawing one object.
**`builders.sack` is cut against the shop's own artwork** (designer,
2026-09-22) — the primitives now match `sack.png`, the rendered icon the
Bigger Sack card has always sold. **A real seven-part mesh has since replaced
the primitives at `builders.sack`'s own top**, through `Shared/LootMesh.build`
reading `Config.LOOT_MESH` (`assets/loot-bag/`, `UPLOADS.md`) — `LootMesh.build`
returns `false`, and the primitives build runs instead, the moment any row's
id is blank, so a half-uploaded table degrades to the old picture rather than
to half a bag. **The `Bag` row is the *rounded-bottom* cloth as of
2026-09-23** — the first round's flat-bottomed cloth is retired, and the
rounded one was told apart from it by reading both meshes back and comparing
the width of their bottom slice (`UPLOADS.md` has the figures). Its `Bag` part
is renamed `Body` and set
as the model's `PrimaryPart`, so the weld, the label, the trail and the nab
prompt seat on it exactly as they did on the mini — mesh or primitives alike.
The model is named `Config.LOOT_MODEL_NAME`, the same name the piggy-snatch
carry's model carries, and stamped `Config.CARRY_KIND_ATTRIBUTE = "sling"`
(§2, §5, §10; designer, 2026-09-23) — the **sling**, a one-armed shoulder
carry, where a hauled piggy is hugged in both arms instead; the two carries
are told apart by the word on the model itself rather than by which service
happens to be asking, and a model naming neither kind defaults to the hug.
The label over it reads *"<victim>'s coins"* rather than naming a
skin. A missing builder degrades to an empty model and `attachLoot` refuses
the carry outright rather than welding nothing.

**A dog only ever chases a robbery, never a visit.** `HeistService.watchLawns`
still wakes for the loudest trespasser's footsteps, but a loud non-owner who
is neither carrying loot nor mid-crack now gets a **bark only** — no chase, no
mark, and nothing said to the owner, because nothing has happened to their
piggy. Walking across somebody's lawn is allowed; robbing it is what the dog
answers. Each dog barks at most once per `Config.DOG_WATCH.alertSeconds`, so a
visitor standing there is not barked at ten times a second.

**A dog that has been alerted *while a robbery is under way* — carrying loot
or mid-crack, woken by footsteps or a missed slice, it is the same
release every time (`HeistService.releaseDog`) — branches
first on whether its owner is home.** Owner home: the dog is the **alarm, not the
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
loot from an earlier landed slice, a thief loses every coin **outright, in
one stroke** — a dog cannot hold a decision open the way a player can (the
tug, below), and handing an NPC a partial outcome would be a mechanic nobody
is playing; caught with nothing in hand — walking up before ever cracking a
lock, or a clean run that has already delivered — a thief is
**scared off** instead (`HeistService.scare`): there is no loot to drop, so
the cost is `Config.DOG_WATCH.scareStun` seconds held still and the crack
they were mid-way through, nothing more. Being robbed must stay survivable;
so must failing to rob.

**The chase itself is a leashed, imperfect pursuit, never an inescapable
one.** `Config.DOG_CHASE` binds it: the dog gives up the instant its target
leaves the yard's own fence rectangle extended forward to the end of the
driveway (`streetMetrics().driveFar`) and never runs past that box in either
direction — a chase can spill out onto the drive but never onto the street.
It also turns at a limited rate (`turnRate`) and slows through a sharp turn
(`turnSlow`), and it only actually catches within `catchCone` of its own
nose — so a chase can be juked by cutting a corner or breaking its turn
radius, not merely outrun.

**A dog may cross its own front fence line only through the gate**
(`GuardDog.setGate`, written by `PlotService.buildFence`), never the sides or
the back — `pastFence`/`chaseGoal`/`blockAtFence` route both an ordinary
patrol and a chase toward the gate's opening rather than the wire, and a
thief the other side of the fence from the dog cannot be caught even inside
`catchRadius`, because a catch is only judged **on the same side of the
fence**. This is the same rule a player's own gate already enforces on
everybody else; the dog just obeys its own fence for the first time.

**A catch made inside the victim's own yard throws the thief back out of
it.** `HeistService.knockOutOfYard` finds the nearest point on the yard's
own edge — the front, or a side alley, never the back, which would drop the
thief deeper into the neighbourhood instead of back toward the street — and
fires `DogKnockout` with that landing point. The client (`ClientMain`,
`bindFenceKnockback`) flies the thief there as a limp, tumbling arc, the
same picture a fence's own electric knockback already uses; the server
teleports them there directly if they are still inside the yard once
`knockout.verifyAfter` has passed, so a client that never plays the arc
cannot leave them standing on the lawn they were just caught robbing.

**An owner arriving home in person can break up a crack that is still open,
and it costs the thief less than either the dog or a nab.** While an attempt
is live, `HeistService` polls the plot's own owner alongside the thief's own
range to the piggy — never a resident's, who is never home by construction —
and the instant they come within `Config.OWNER_INTERRUPT_RANGE` of it the
attempt simply **ends**: every slice already banked stays banked, nothing
still to come is taken, and there is no stun, no alarm and no confiscation,
because two hard stops on one lawn is the rule "defence buys time, never
immunity" already refuses. It does not depend on the alarm having fired —
the owner does not need telling that somebody is standing on their lawn. What
it costs the thief is only the slices they had not taken yet, and the crack's
own ladder grows 1.4× a step, so an interruption at the third slice costs
more than the three it leaves behind.

**`STEAL_RANGE + DROPOFF_RADIUS` must stay well under `PLOT_SPACING`.** If that
sum approaches the spacing, a thief can stand in their own drop-off zone and rob
a neighbour without ever running — and the run is the entire risk half of the
trade.

*Orientation only — `Config` is authoritative.* The sum is 27 against a spacing
of 80, so the shortest getaway is 53 studs, about 2.9 seconds at carry speed. It
was 37 studs and 3.1 seconds before the plot widened, so the rule holds by a
wider margin now rather than a narrower one — but a longer run also hands the
alerted dog (fixed at 21.75, above) more time to close. **If robbing ever reads
as too hard,
`DROPOFF_RADIUS` is the lever**: it is a fraction of your own plot rather than
an absolute, so it can grow with the plot.

**A completed player nab transfers the intact carry.** The initial
`Config.NAB.hold` opens or joins one tug per holder. Each `tickRate` interval
advances progress toward `recoverSeconds`; a crowd divides contribution
credit without speeding it up. No coins leave escrow during a tug, and no
bounty is minted. A haul containing only a skin still takes the same time.
The ongoing crack/collection round closes when the tug starts.

At completion, the greatest contributor who is still alive, nearby and
empty-handed wins; equal contributions use join order. Busy, missing or
out-of-range players cannot receive the carry. The same loot model, prompt
and haul move to the winner's character; claimant and victim stay unchanged. The loser loses the carry slow without being stunned. The
winner receives the slow, loses shield/sneak, and gets `NAB.cooldown` rest.
The prompt reads its current holder, so the original thief can take it back
after that rest. Catch credit goes to contributors only on a successful transfer.

A dodge or escape breaks the tug, preserving the entire carry and applying
rest to its existing holder. A failed attachment likewise preserves escrow.
Death, departure, delivery or confiscation cannot let an old tug award a catch
or affect a replacement carry: each loop checks its original tug and carry.
The current-holder rest preserves the existing anti-swarm duty-cycle bound.

**Phase 3.3 settlement is implemented:** see Carry ownership above for the
return/keep rules. Live two-player end-to-end verification remains pending.

**A guard dog cannot tug, and the patrol was never in this at all.**
`HeistService.nab(nabber, thief, byDog)` only enters the tug when `byDog` is
false; a dog's own catch runs the older, binary path below it in the
function — instant, total, no hold, no partial outcome and no catch effect,
because an NPC has no decision to make and a partial outcome is a mechanic
nobody is playing (this is the branch the dog-alert paragraph above
describes). The patrol's confiscation (§7) is a third thing again, and never
`HeistService.nab` at all — the patrol defends nobody and thanks nobody, so
it owes none of the wording or the counterplay a nab carries.

**What an original claimant's coin delivery pays.** The victim loses the sum of every slice landed during
the crack — `Config.getCrackFraction`, each slice scaled by the thief's Bigger
Sack — taken out of their pig the instant it lands rather than promised for
later (two thieves working the same pig can't both be promised the same
coins). The thief banks that running total times `Config.HEIST_PAYOUT` on
delivery — the extra is minted by the game, which is what lets robbing be the
best earning rate on the street without a robbery being devastating.
Robbing somebody who
robbed *you* inside `Config.REVENGE.window` pays `Config.revengePayout()` —
`Config.HEIST_PAYOUT * Config.REVENGE.bonus`, a multiple of the ordinary rate
rather than a payout of its own — times the coins instead; the marker over
their plot lasts the same window. `Config.STEAL_FRACTION` survives only as the calibration
baseline the crack's slices are measured against — the old flat take lands
between the second and third slice of a clean run — and as the sack-scaling
factor inside `Config.getStealFraction`.

**Clean player cracks take eligible worn skins without a dice roll.**
`Config.SKIN_STEAL` retains the per-victim loss cap and window. Ordinary theft
skips a skin already owned by the thief and only admits `isStealableSkin`;
a spare absorbs the loss before the owned copy. Residents and incomplete
cracks grant no stolen skin. Items stay on the carry through player nabs until delivery. Voluntary return,
dog catch, arrest, death or departure use `returnHaul` to restore the original copy.

**Skin recovery claims stack independently.** On delivery, `HeistService`
records the skin under `grudge[owner][robber].skins`, with its own
`Config.REVENGE.window` deadline. A robber's later victims do not erase earlier
claims. A later theft of the same skin from the same owner replaces its old
robber claim; other skins remain valid. A clean crack selects the oldest
available claim and takes that skin from the robber's ownership, regardless
of outfit. Recovery bypasses ordinary insurance and skin-loss caps; the skin
still has to be carried home. Getting caught returns it and releases the
reservation without extending its original deadline.

Coin revenge has a separate expiry: using its bonus does not spend a skin
claim, and another coin robbery cannot refresh a skin's timer. Claims expire
individually and are cleared on player departure; they are not saved. If the
robber no longer owns the hot skin, that crack does not substitute an unrelated
skin. Recovered insured spares restore exactly the spare lost; an ordinary
skin reacquired before recovery yields no extra spare. Recovery itself creates
no timed counter-claim.

**A seasonal buy-back claim is separate from timed recovery.** Losing an owned
stealable skin writes `data.claims[key] = Config.seasonIndex()`; spare-only
loss does not. A claimed, currently unowned skin has an exact-item BUY BACK
card beside its source crate. `ChestService.buyback` (remote `SkinBuyback`)
checks the current season, skin eligibility and ownership on the server, then
charges **coins**, not a second currency: `Config.buybackCost(key)` is
`Config.sellValue("skin", key) * Config.BUYBACK.markup` (markup 4×), so the
price is the inverse of what letting the skin go would have paid — a
sell-then-rebuy can never turn a profit. Because this hands over one *named*
skin the player already owned, nothing about it is random and none of the
paid-random-item reasoning in §3 applies; it is an ordinary coin purchase. It
charges before `SetService.grant` writes ownership, refunding the coins if the
grant fails; the normal grant save contains both. No roll or spare is
awarded, and the robber keeps their copy. The claim persists through the
season, hidden while owned, so duplicate requests cannot charge again. Free
recovery remains available inside its separate timer.

`Config.SEASON` is the claims' clock: active weeks plus a rest week,
anchored to the existing UTC `weekIndex` — the same clock the nemesis ledger
rolls on (§3, *The season clock and the nemesis ledger*). Requests reject
expiry immediately. Crate cards expire locally; a 30-second server rollover
pass clears/saves online claims, and reconcile prunes expired offline claims.
The recovery objective card (§14) is implemented. It reads private `RecoveryObjective` snapshots derived from the
actual haul, timed claims and current ownership. Before delivery it directs
the victim to nab the fleeing robber; after delivery it uses the claim's
wall-clock deadline for a countdown. This does not change the server's
monotonic recovery expiry. Expiry switches locally to the existing buy-back
price only while eligible. No client-supplied claim, timer or price is used.

**Consecutive deliveries are worth more, and it is the only thing in the game
that varies *between* robberies rather than within one.** This used to be a
`spree` — `Config.SPREE`, a separate table of steps and a timestamp — and was
folded into a single ladder on 2026-09-22: `Config.WANTED_STARS`, drawn as the
stars on the rap-sheet chip (§7, §14), because a star is a reward and a threat
at once and two tables carrying one meaning is how they drift apart.
`SocialService` keeps `stars` — a count and a
timestamp, keyed by player — deliberately separate from `heat`, the rap
sheet: `heat` only ever rises and ranks Most Wanted (§7), while a star is
earned per delivery, **fades** one at a time after `Config.WANTED_STARS.fade`
seconds each with no delivery (checked lazily on read, no timer of its own),
and is wiped by any arrest (`SocialService.clearStars`). **The Most Wanted
leader is pinned at `WANTED_STARS.max` and does not fade** (designer
decision, 2026-09-22) — the name on the poster is the biggest sheet in the
server, and a leader whose stars quietly drained while their poster stayed up
would be two readouts telling two different stories about one player; the
fade clock is genuinely *held*, and `refreshMostWanted` re-stamps it once
more on a hand-over, so the old leader starts fading from five rather than
from wherever a stale clock would have put them. The run underneath the pin
keeps counting through every delivery regardless, because it is what the
best-spree trophy is measured against (`SocialService.getRun`, always
**unpinned** — a trophy for "five in a row" awarded on a leader's first
delivery would record a run nobody made). `HeistService.deliver`
multiplies `payout` by `SocialService.getStarMultiplier(thief)` — read
*before* `SocialService.recordSteal` bumps the count, so the delivery that
starts a run pays the plain rate and the one after it pays more
(`Config.getStarPayout`, up to `Config.WANTED_STARS.max` stars) — and the
delivery toast names the run once it is more than one delivery long. The same
star count is what the patrol reacts to (§7): from
`Config.WANTED_STARS.huntedFrom` stars the patrol comes on every pass for
whoever is carrying them, whether or not they lead the Most Wanted board at
all — a run is paid for in the risk half of the game the patrol already
owns, not in a new hazard. `SocialService.recordSteal` is also the piggy
pedestal's own snatch-secure call (§3), so a snatched piggy earns a star on
the same ladder even though it opens no revenge window — the two are answered
by different calls (`recordSteal` versus `markRevenge`), and only the coin
robbery path ever calls the second.

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

A robbed piggy used to wear a **plaster** — two crossed strips on its
forehead for `Config.ROBBED_MARK_SECONDS`, with a matching pair of jemmy scars
on a shop vault's door. **Retired**, with `ROBBED_MARK_SECONDS`,
`PLOT_ROBBED_ATTRIBUTE`, `PiggyBank.setRobbed` and `PlotService.setRobbed`. It
carried no behaviour, so nothing that prices a robbery moved with it. The rule
it stood for is unchanged and is the half that matters: **a robbery never costs
permanent progress**, which is why losing a house for being robbed was rejected
in the first place.

**`RobBadge` (`Shared/RobBadge.luau`) hangs a billboard over every piggy.** It
used to only ever show a negative — no badge meant robbable — on the argument
that eight badges all advertising themselves is wallpaper. **That rule is
reversed now:** a robbable pig carries its own contents in gold
(`Config.formatCoins`), because which pig is worth crossing the road for is
the whole decision a thief makes from the pavement, and "no badge" told them
nothing about that. A refusal still wins over the figure, checked in the same
order as `HeistService.whyCannotSteal`: the victim's shield (NEW HERE while
`NeedsFirstJob`, otherwise SHIELD), your own per-victim cooldown, an empty
vault, then CAPPED with the loss-window deadline. Nothing shows over an unclaimed plot
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

**`Config.auditRobbery()` checks that robbing is worth doing at all, against
every axis that can move it.** `Config.robberyRates(incomeLevel, rebirths,
stars, houses, shops, thief)` is the one function underneath every sweep: it
idles the thief on `Config.collectionRate` of a lawn (`thief`, defaulting to a
lawn of commons — the cheapest lawn anybody can fill) and robs the weighted
mean of the two non-player target classes, resident houses and shop vaults
(`houses`/`shops` optional, defaulting to the worst case, below), against an
hour of that idling. The audit asserts the ratio sits inside
`Config.ROBBERY_ADVANTAGE` (a min/max band) and stays **constant** across the
whole game (a `spread` ceiling) — the same invariant `RESIDENTS.pigSeconds`
exists to pin, so a later change that lets the ratio drift (a resident's pig
re-tied to a growing curve, a crack step retuned, the getaway distance moved)
shows up here instead of silently — over every level/rebirth pair. **It sweeps
both ends of the wanted-star ladder** (§7) — a *cold* thief (no stars) against
the band's floor, and one carrying `Config.WANTED_STARS.max` stars against its
ceiling — because the two answer different questions (is robbing ever worth
it; is the best case a faucet) and measuring only one lets the other drift
with nothing to say so, which is exactly what a star multiplying an
unmeasured payout would do.

**It also sweeps server population, which is the axis that actually broke
it.** A resident house is evicted the moment its plot is claimed, so house
supply is `Config.PLOT_COUNT - players online` — this reached zero on a full
server while `MAX_PLAYERS` and `PLOT_COUNT` were equal, exactly when the game
was busiest, and no cap on player count can fix that on its own
(`Config.LOSS_CAP` makes player-versus-player robbing worse than standing
still at every population, so the supply has to be non-player).
`Config.MAX_PLAYERS` is a **plain literal now, deliberately below
`Config.PLOT_COUNT`** (§11) — it may never sit above it, `Main` kicks anybody
it cannot seat, and `Config.auditRobbery` refuses a cap that is — so that gap
is a permanent floor of resident houses rather than a number that can reach
zero. `Config.RESIDENT_FLOOR` (`Config.SHOP_COUNT` plus `PLOT_COUNT -
MAX_PLAYERS`) is the floor the audit measures at every population from one
player up to `MAX_PLAYERS`, walking `houses` down while holding `shops` at
`Config.SHOP_COUNT` — the worst case is a *full* server, the opposite of
what the level/rebirth sweeps assume. A **directional** check alongside it
refuses a shop vault that pays *more* than a house (which would make every
house on the street pointless the moment a player worked it out) or under 60%
of one (which would make the floor those vaults exist to be fictional,
because nobody would walk to one) — never a symmetric skew check, because
`Config.SHOP_VAULT_DISCOUNT` is *meant* to sit below parity. It also checks
that the floor population's pigs — at a full server, the four shop vaults
plus the two resident houses `RESIDENT_FLOOR` now guarantees — lap faster
than `Config.RESIDENTS.stealCooldown`, or the cooldown would bind and every
ratio above would be optimistic. `Main` warns per problem at startup, in
Studio as well as live — the same shape as `auditEconomy`/`auditFences`
(§4, §11).

`Config.robberyFigures()` is the printable summary — the cold ratio, the
ratio at `Config.WANTED_STARS.max` stars, and the cold ratio against a thief's
own top-rarity lawn — rather than this file copying numbers that move every
time `HEIST_PAYOUT`, `RESIDENTS.pigSeconds` or the wanted-star ladder do; both
of the first two were re-solved on 2026-09-22 alongside the spree-to-stars
rename (§7), which is exactly the kind of change this audit exists to catch.
`Config.SHOP_VAULT_DISCOUNT` is the lever if a shop vault's own share of the
floor population ever needs paying for the shorter run home a strongroom on
the back wall costs a thief.

### Defence tree — buys time, never immunity

| | Effect | Ceiling |
|---|---|---|
| **Fence** | Slows and hazards a crossing | **Solid — the gate is the only free way across.** `Config.BASE_JUMP_HEIGHT` is **5.5**: tiers 1–2 (Rickety 3.6, White Picket 4.8) are jumpable; tiers 3–5 (Barbed Wire, Electric, Moat — all top 7.0) are not, and there is no built-in way over one. A gate (24 studs wide at tier 1, down to 8 at tier 5) always exists |
| **Vault Lock** | Narrows the crack's target windows (`Config.getCrackWindow`) | Readable from the street as a vault dial — a hatch in the piggy's back. Level 0 wears the bottom (iron) dial rather than an open hole (`PiggyBank.setLockLevel` clamps the drawn tier to 1 while the pips and the prompt label still read the true level 0, designer decision 2026-09-22 — an open hatch read as "no vault at all" on the mesh pig). Readable from *any distance* by a thief with maxed Lockpicks — see **casing**, below |

**The Guard Dog is not a rung in this tree any more — it retired outright.**
`Config.UPGRADES.dog` is gone (the defence tree is these two rungs, above,
and no more), and every plot — a player's and a resident's alike — carries
the same dog at `Config.DOG_LEVEL` (2, the Shepherd), regardless of anything
anybody has bought. What used to be five breeds bought in order is now one
fixed stat and a wardrobe of skins over it (§9): `Config.DOG_TIERS` still
holds every breed's model, voice, shape and `boneResist`, but only the row at
`DOG_LEVEL` is ever the *dog*, at speed **21.75** — between a free player's 24
and a carrying thief's 18, so running away empty-handed works, running with
the coins does not, and sneaking away (above) does. It still **watches the
lawn** (`HeistService.watchLawns`) and wakes for footsteps above `notice`, or a
**missed crack slice** — the only two triggers left now the smash is retired
(above); asleep-in-its-kennel vs.
patrolling-awake is still the tell for whether the owner is home; and it
still only ever chases a robbery, never a visit (above). **Owner home: alarm
only** — barks and marks the thief, never chases. **Owner away (always true
for a resident): the enforcer** — chases and nabs a carrying thief, or scares
off an empty-handed one, through its own gate and no other way across its
own fence (above). Beaten by bones, or a tiptoe kept under `notice`. A coat, a
kennel skin or a name on the collar change none of this — see the wardrobe in
§9.

**The lock and the dog no longer answer two different attacks.** While the
smash existed it was the loud, lock-blind way in — the dog was the whole of
what it had to get past, and the Vault Lock did nothing against it — while a
clean crack never woke the dog at all, so the lock was what slowed that one
down. With the smash retired there is one way into a pig, and both defences
bear on it together: the lock narrows every crack's target windows and the
dog answers only a fumbled slice or being heard approaching. Nothing here is
soft to a *different* attack any more; a well-locked, undogged pig and a
well-guarded, unlocked one both face the identical crack.

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

**Lockpicks** (wider crack windows), **Bigger Sack** (bigger takes —
scales every step of the crack, not a single flat take), **Getaway Speed** (carry
speed, **capped at ×1.0** so they never exceed base), **Sneak** — the
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
`DOG_LEVEL` (the fixed dog every plot carries, above),
`CRACK` (`getCrackSlice`/`getCrackFraction`/`getCrackTotal`/`getCrackWindow`),
`CRACK_ALARM_ON_MISS`, `STEAL_*` (including `STEAL_FRACTION`, the crack's
calibration baseline), `OWNER_INTERRUPT_RANGE` (an owner breaking up a crack
in person, above), `NAB` (`hold`/`distance`/`tickRate`/`recoverSeconds`/
`bounty`/`cooldown` — the tug, above; was `TAG_HOLD`/`TAG_DISTANCE`, two
constants, before it grew into a table),
`CARRY_SPEED_MULTIPLIER`, `HEIST_PAYOUT`, `LOSS_CAP`, `REVENGE`,
`NEW_PLAYER_SHIELD`, `JOIN_SHIELD`, `BASE_JUMP_HEIGHT`, `LAWN_LIFT`, `CLIMB_SPEED_RATIO`,
`CLIMB_MULTIPLIER`, `LADDER`, `RESIDENTS`, `PLOT_RESIDENT_ATTRIBUTE`,
`PLOT_RESIDENT_ID_ATTRIBUTE`, `TIPTOE`, `SNEAK_ATTRIBUTE`,
`PLAYER_FIRST_JOB_ATTRIBUTE`,
`DOG_WATCH` (`pollRate`, `wakeDelay`, `alertSeconds`, `scareStun` — all live,
read by `HeistService.watchLawns`/`.scare`), `ROBBERY_ADVANTAGE` (the audit
above), `WANTED_STARS` (`max`, `payoutPerStar`,
`huntedFrom`, `fade` — `getStarPayout`, §7), `REVENGE`
(`window`, `bonus` — `Config.revengePayout()`), `CASING`
(`Config.canCase`), `PLOT_LOCK_ATTRIBUTE` (the plot's Vault Lock tier,
published once by `PlotService.setLockLevel` and read by both the rob badge
and the steal prompt's own label), `SHOPS`/`SHOP_COUNT`/`SHOP_UNIT`/
`SHOP_ROOM_SLACK`/`SHOP_VAULT_DISCOUNT`/`SHOP_VAULT_DROP` (the shop-vault
supply floor and its item drop, above), `SHOPKEEPER` (the shop's own guard
dog, above), and `PLOTS_PER_ROW`/
`PLOT_COUNT`/`MAX_PLAYERS`/`RESIDENT_FLOOR` (the plot grid, the server cap and
the resulting worst-case victim count, all read by `Config.auditRobbery`).

---

## 6. Consumables and the hot bar

Five catalogues, one gesture: **hold a stock, pick one, use it.**

| Catalogue | Config | What it counters |
|---|---|---|
| **Bones** | `Config.BONES` | The guard dog. Cheap bones bounce off Guard Duty; only the Golden Bone interrupts a chase |
| **Gadgets** | `Config.GADGETS` | Maxed Getaway Speed. Range *falls* as power rises, so the decisive one cannot reach a thief who already got clear |
| **Home items** | `Config.HOME_ITEMS` | Guard Duty Treat, Garden Sprinkler (a joke, deliberately toothless), Patrol Radio |
| **Thief kit** | `Config.THIEF_KIT` | **Ladder** — the fence itself, now that no fence has a built-in way over (§5); **Raincoat** — sheds the two cheap gadgets, admits the Zapper |
| **Lassos** | `Config.LASSOS` | A wild piggy's resistance to being caught. Rope, Braided and Golden are coin-bought and rebirth-gated; Elite is a Robux paid random item (§3, §15) |

**Cheap counters bounce, the expensive one gets through — on both sides.** Each
raises the *price* of beating someone rather than making them unbeatable.

### The bar itself

- **Floating item icons, with readable stock badges.** The HUD uses static
  models without tile backgrounds, cream quantity pills, desktop key chips,
  and a gold underline for the server-confirmed held item. Mobile hides number
  chips while retaining active-state labels such as `ON`.
- **The bar fits between the mobile controls.** `HotBar.layoutFor` reserves
  120 pixels on each side of landscape touch screens. Up to five 52×60 slots
  appear per page, fewer on narrow screens, with fixed-position 44-pixel page
  buttons. Desktop shows the full row when it fits. Paging preserves item
  bindings and stock; selecting an item by key reveals its page.
- **An item is HELD before it is used.** Selecting is free (a number key or a
  tap asks the server to *draw* something); only a deliberate click out in the
  world spends it. This exists for two reasons: a stray thumb should not spend a
  30,000-coin Golden Bone, and **a thief walking up a driveway holding a Golden
  Bone is information** the defender can read off the lawn.
- **The click sends no position — with one deliberate exception.** `BoneThrow`
  and `GadgetThrow` carry a key and nothing else; the server picks the target
  from its own positions. `LassoThrow` carries the client's lock-on choice —
  a piggy's id, never a coordinate — and re-checks everything about it
  server-side before a lasso is spent (§3). The **Ladder** is the odd one out:
  `PlotService`
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
dial (§5) · `B` shop · `V` garage · `R` radio · `G` lasso · `I`
bag/inventory (§14) · `Esc` close (also bails a crack, banking whatever it
has) · `F2` admin · `1`–`0` hot bar. `G` was free after the smash retired (it
was the smash's own key, given a letter of its own because two prompts on
one key do not both work); the lasso took it as the hot bar's twelfth slot,
checked at build time against every existing `KeyCode` and prompt key before
landing on it (§3). A new binding gets checked against this list and against
whether it is genuinely exclusive with what it lands on.

---

## 7. The police

**The only risk in the game that belongs to nobody.** Every other risk is the
victim's — their dog, their fence, their lock — which leaves a hole no purchase
can close: robbing an offline player is otherwise completely free.

- **Published.** The siren sounds fifteen seconds before the car appears and the
  HUD counts both clocks, so robbing during a patrol is a *choice* rather than
  bad luck — and bad luck is not something a nine-year-old can get better at.
- **Commits to one pursuit.** A live robbery always wins; otherwise the officer
  goes for the **pursuit target** (below) — whoever is carrying at least
  `Config.WANTED_STARS.huntedFrom` stars, not necessarily the Most Wanted
  leader.
- **The officer runs at 21.75**, between a carrying thief's 18 and a free
  player's 24 — so *delivering* is the answer, and nothing in the patrol exceeds
  `BASE_WALK_SPEED`.
- **Bail is a flat share of the thief's OWN balance, on every arrest, whatever
  they were caught carrying.** `Config.POLICE.bailFraction` of `data.coins` —
  never a multiple of what was stolen or of the rap sheet — so a records
  check costs the same share of a bare-handed most-wanted arrest, a coin
  robbery caught mid-getaway, and a snatched piggy confiscation alike. There
  is only one balance now (§3), so bail comes out of it directly; being
  caught can cost an afternoon of idle income and can never cost a house, a
  skin or an upgrade — nothing spent is ever at risk. Confiscating a piggy
  (§3) still charges this same bail even though losing the piggy is a
  separate cost from it, since bail no longer reads what the arrest was for
  at all.
- **An arrested thief is released at their own gate** — a teleport, not a
  respawn, fired off the *end* of the detention.
- **Confiscation is not a nab, and the two never share a code path.** The
  patrol takes the loot off a thief on its own terms — instant, total, no
  hold and no counterplay — because it defends nobody and thanks nobody; a
  **nab** (§5) is always a person, or on an unclaimed plot a guard dog,
  recovering loot for a specific victim, and only a nab that fully empties a
  thief's hands fires a catch effect (§9). An arrest never does.
- **No player can ever aim an officer at another player.** `PoliceService.call`
  (the Patrol Radio) takes **no arguments at all** — not a player, not a plot,
  not a position. A radio brings a car onto the street and says nothing about
  who for; if the caller is top of the board, it is them the officer gets out
  for.

**Most Wanted** is a **per-session** rap sheet counted on *delivery*, not on the
grab. Lifetime totals made it unwinnable — whoever had played longest wore the
label permanently. Escaping a most-wanted pursuit is what unlocks
**`PlayerGear`**, the only cosmetic worn by the player rather than by their
piggy — the same counter (`data.gear.escapes`) also stands the lamps on the
**Siren Post** trophy (§9). **A player's own sheet is a standing HUD chip now** (`Shared/Wanted.luau`,
§14) — hidden until they have stolen anything, then STOLEN, or WANTED once
they lead the board, or HUNTED once their own stars reach
`Config.WANTED_STARS.huntedFrom` (which outranks leading the board and is
the only state that means the patrol is actually coming for them).

**Robbing a resident (§5) counts exactly like robbing a player.** `deliver`
credits the rap sheet off what was taken regardless of which kind of victim it
came from, so a single player can build a sheet, get chased, get arrested and
escape without anybody else in the server — the loop this section describes
no longer needs a second person to exist.

**Stars are momentum, not record — a second, separate piece of per-player
state alongside the rap sheet, and the single ladder that replaced the older
`spree` outright (`Config.SPREE`, retired 2026-09-22 — see §5).**
`SocialService` keeps `stars` (a count and a timestamp) that rises one per
delivery and **fades** one at a time after `Config.WANTED_STARS.fade` seconds
each with no delivery, expiring lazily on read; it is never conflated with
`heat` above, which only ever rises. Landing a delivery pays more
(`Config.getStarPayout`, §5) and **is what draws the patrol at all**: the
pursuit floor a leader's sheet used to have to clear is retired outright
(designer decision, 2026-09-22 — `Config.POLICE.wantedFloorSeconds` and
`Config.getStarFloorScale` no longer exist), and from
`Config.WANTED_STARS.huntedFrom` stars the patrol comes for whoever is
carrying them on every pass, so a thief working fast draws a records check a
listless one never does. **Crossing `huntedFrom` is said the instant it
happens, to that thief alone, whoever leads the board** —
`SocialService.recordSteal` fires it on the exact delivery that pushes their
own count over the line (*"N stars. The patrol comes for you on every pass
until they fade."*, `Notify` kind `police`), so a run's own consequence is
never a surprise the leaderboard has to explain later. Any arrest — not
only a most-wanted one — calls
`SocialService.clearStars`, unlike `SocialService.clearHeat` (§14), which
fires only on a most-wanted bust: a rap sheet is what you did and an ordinary
bust doesn't undo it, but stars are momentum and being put in a car plainly
ends them. The player's own rap-sheet chip (§14) draws the run as a row of
five draining stars under the sheet figure, held full with no motion while
that player is the Most Wanted leader (`SocialService.starsOf`'s pin, above).

**A nab (§5) does not touch either of them, even one that empties a thief
outright.** `SocialService.recordSteal`, `.markRevenge` and `.clearStars` are
called only from `HeistService.deliver` for a coin robbery (`.clearStars`
also from `PoliceService` on any arrest, above); nothing in `nab`, `tugTick`
or `endTug` calls any of the three. Only an arrest wipes stars.
`recordSteal` has one other caller now: a piggy pedestal snatch (§3) fires it
on the *secure*, never the grab — earning a star on the same ladder, since
one call now bumps both the sheet and the stars together — but never
alongside `markRevenge`, so a snatched piggy still opens no revenge window.

**The name on the board and the officer's target are two different
questions, answered by two different functions, and the second one no
longer asks about the first at all.** `SocialService.getMostWanted` is the
poster: the single biggest rap sheet in the server, full stop — still no
floor, unchanged. `SocialService.getPursuitTarget` decides who the patrol
may actually come for, and since the pursuit floor's retirement (designer
decision, 2026-09-22) checks exactly one thing, asked fresh every time: is
*anybody* on the server carrying at least `Config.WANTED_STARS.huntedFrom`
stars — the most-starred player taken, the biggest sheet breaking a tie —
**whoever that is, whether or not they lead the board at all**. Bail is
charged against the thief's own balance regardless of which function named
them (above), never against the star count or the sheet. `PoliceService`
reads `getPursuitTarget` at both sites that matter (the "They're out looking
for YOU" warning, and picking who the patrol goes for); `AdminService`'s
`mostwanted` command (which also grants `WANTED_STARS.huntedFrom` stars, so
the command actually draws a patrol rather than only naming a poster) and
the physical poster read `getMostWanted`. The poster's own progress bar
tracks the *leader's* stars against `huntedFrom` — "N STAR(S) TO A PATROL" /
"PATROL COMING" once they cross it — and a leader below that line gets *"You
are MOST WANTED. Take more and the patrol will come."*; one who crosses it
gets *"…The next patrol comes for you."*, fired the moment the sitting
leader's own stars cross `huntedFrom` without the board changing hands.

**Where the numbers live:** `Config.POLICE` (`bailFraction`, `callLockout`,
`Config.bailPercent()`), `STUN_SECONDS`, `Config.GEAR`,
`Config.WANTED_STARS` (`max`/`payoutPerStar`/`huntedFrom`/`fade`).

---

## 8. Events

`EventService` runs a roster on a timer, every `Config.EVENTS.period` (900s —
15 minutes), warned 20s ahead exactly like the patrol's own siren. **One
event today: Alien Invasion.** Midnight Heist — the dusk, the doubled coin
steal, `Config.MIDNIGHT`/`MIDNIGHT_LIGHT` — is retired outright rather than
disabled, on the designer's call alongside the pig-collection pivot (§4):
its whole payload was doubling coin steals and the pig-crack Acorn bonus, and
the Acorn half no longer exists. `Config.EVENTS.roster` is one row
(`raid`), so the picker draws it every slot and the damped-repeat rule below
is currently inert — kept rather than deleted, because it is exactly the
rule a second row would need on day one, and a two-row roster with no
damping is the strict-alternation trap this file already records once.

- **An event reuses the heist verbs and adds none.** You break a beam by
  *throwing* a gadget and recover loot by *holding a prompt*. No new input, no
  new button, and no weapon anywhere in it.
- **The Alien Invasion is the flagship because the street has never been on the
  same side.** Every other mechanic is adversarial; for the length of a raid a
  full server means more *defenders*.
- **A drain that does not beat income is invisible.** `drainIncomeMultiple` is a
  floor expressed as a multiple of the victim's own income, so the pile visibly
  falls at every tier.
- **The picker damps repeats rather than forbidding them.** "Never the same
  twice in a row" only matters once a second roster row exists — at one row it
  would be meaningless, and at exactly two it collapses into strict
  alternation with the weights doing nothing at all, which is the failure
  `REPEAT_WEIGHT` (damping the last pick's weight rather than excluding it)
  exists to avoid the day a second event lands.
- **An event suppresses the patrol**, which is what lets them share a HUD row.
  The patrol is *deferred*, never cancelled.

**Acorn theft, the shake-another-tree minigame and the whole tree/basket loop
are gone, not merely disabled.** A roster row once carried an `acornTheft`
flag that stayed permanently false; `ShakeService`, `EventService.isAcornTheftOpen`
and the theft-cooldown auditing it fed are all deleted along with the
currency (§3), so there is no longer a flag to flip.

**Rewards:** the Alien Invasion pays its existing coin bounty (income-seconds,
1.5x on a cleared street) and one free unowned set drop per player present.
A full set receives a completion message with no additional item, spare or
currency. No event awards Acorns — there is no Acorn to award. The coin
bounty banks in full now (§4) — there is no room to cap it against.

**Sets** are a **view over the existing catalogues**, never a new catalogue.
`Config.SETS` lists `{kind, key}` pairs pointing at ordinary members of `SKINS`,
`EFFECTS`, `ACCESSORIES`, `DECOR_ITEMS` and `RIDES`. No new ownership storage, no
new equip path. **`set` is an exclusion** — it keeps set items out of the
crate pools and out of both free-if-costless fallbacks (it also kept
them out of the accessory roll, which is retired along with the rest of
`ACCESSORIES`, §9).

**The alien set is down to two items, and its guaranteed-purchase route is
gone with the currency it was priced in.** `SetService.buy` and the `LootBuy`
remote are deleted — set items are no longer purchasable at all, in coins or
otherwise. The set's two accessory members retired with `Config.ACCESSORIES`,
and its decoration member (the Crashed Drone) retired with the lawn
ornaments; what is left, `martian` (skin) and `hoverdisc` (ride), is reachable
only through the alien raid's free unowned-item roll (above) — there is no
longer a way to buy either outright. The Alien Cache that was the other route
was deleted on 2026-09-23, and the raid is off the schedule while
`Config.EVENTS.enabled` is false (it still runs from the admin panel), so
today neither item reaches a player in normal play. The Tractor Beam
effect still carries a `set = "alien"` tag (which keeps it out of the effects
shop and any free-if-costless fallback) but is **not** in `Config.SETS.alien`
any more, so it has no route to a player at all; recorded in §17.

---

## 9. Cosmetics

Roughly a hundred items across fifteen catalogues — the skins catalogue alone
is 72. **None of them confer anything.**
That is what makes them safe to price steeply, and it is why houses in
particular are pure prestige.

| Catalogue | Config | Bought with | Notes |
|---|---|---|---|
| **Skins** | `SKINS` | **crates** — a Robux crate, a daily-ladder crate or a rebirth's free one (§3); a crate-only skin refuses a coin purchase outright, below | Animated skins are driven **on the client** from a `SkinKey` attribute — except the legendary tier, which wears a whole model instead of a palette (`skin.legendary`, `Config.LEGENDARIES`, below). 72 skins, all carrying an explicit `rarity` of `common`/`rare`/`epic`/`legendary` (§3) — 67 also carry a `chest` tag, all `og` since the piggy crates merged (2026-09-23), with the theme kept as `collection`: 36 OG, 21 `animal`, 10 `arcade`; the other 5 are the free default `classic`, Solid Gold, the two pass skins and the alien set's `martian` — none carries a `chest` tag, and `martian` instead reaches the Alien Cache through `set = "alien"` (§8). Every skin is also a `Config.piggyScale`, and the mini a thief carries or a pedestal displays wears the whole coat, not a swatch — see below |
| **Effects** | `EFFECTS` | coins — **deliberately not moving to a chest** | Shop tiles *simulate* the real particle numbers — a ViewportFrame renders BaseParts and nothing else. The 5 priced tiers (15K–600K) land 3 commons and 2 rares on `Config.RARITY_BANDS` with no epic or legendary, so a chest would have no top end |
| **Houses** | `HOUSE_TIERS` | coins, the top nine **behind a rebirth** | A shelf, not a ladder: `CosmeticsService.buyHouse` will sell *any* unowned tier once its price and its gate are met — no "buy the cheaper one first" rule. Each row carries a stable `id` (ownership key, saved in `data.houses.owned`) separate from its `style` (builder key); worn tier is `data.houses.shown`. Move back into any owned tier free, forever. Eighteen rows: rows flagged `placeholder` stand `House.build`'s construction-band block until their builder lands, and residents only climb built rows (`Config.residentHouseLevel`). `goldenpig` has no `cost` and `earned = "houses"` — never sold, granted by `CosmeticsService.grantEarnedHouses` once every priced house is owned (`Config.earnedHouseProgress`), and carries no gate because a sale gate on something not sold is a refusal nobody can act on |
| **Decorations** | `DECOR_ITEMS` | coins | Auto-placed into slots; **slots are scarcer than items** on purpose. The ten earned-only **trophies** that once lived here are retired — `Config.TROPHIES` is empty, and the readout moved indoors, below |
| **Border plants** | `BORDER_PLANTS` | coins | Along the fence line (not a lawn slot — a run of plants down each stretch of fence). Height is clamped to the fence's own visible top (`Config.borderHeight`), below |
| **Garden paths** | `GARDEN_PATHS` | coins | Gate to piggy, laid flat on the lawn. No fence needed — the one garden item a bare plot can carry |
| **Window boxes** | `WINDOW_BOXES` | coins | Ground-floor windows only, hung by walking the built house for parts named `Sill` — a post-pass, not an argument threaded through nine house-tier builders |
| **Accessories** | `ACCESSORIES` | — **retired** | `Config.ACCESSORIES` is now an empty table — the fourteen piggy accessories, the roll, the `gear` coin chest and the shop's accessory section all went together, in one edit, because every reader in the game already went through this one catalogue. `PigGear.luau`'s builders are untouched (a retired item keeps its builder, the expensive half, and loses only its catalogue row), so putting any of them back is re-adding rows here. The alien set (§8) lost its two accessory members with it and is two items now, not six |
| **Rides** | `RIDES` | coins, four of six **behind a rebirth** | Street only; a ride confers nothing else. The cheapest ride carries no gate and that is load-bearing — two passes grant it (§15). The Hoverdisc carries none either, because it is in a crate pool and `unlockRebirths` on anything luck can hand over is the retired ownership gate |
| **Player gear** | `GEAR` | earned only | Most Wanted escapes |
| **Stances** | in `RIDES` | **Robux (Style Pack)** | The one cosmetic shaped to be sold directly |
| **Dog coats** | `DOG_COATS` | **three routes** — one free, two coins-behind-a-rebirth, five crate-only (below) | Repaints only `fur`/`furDark`/`collar` on the Guard Dog every plot already has, or renders another breed's whole rig through `guardModel`. `scale` and `shape` — what a thief actually reads to price the risk — are structurally off limits; see below |
| **Dog kennels** | `DOG_KENNELS` | coins | Repaints only `wood`/`trim`. The roof always follows the *coat's* `collar`, never the kennel skin's own, so the two read as one dog's house |
| **Finishes** | `FINISHES` | **nothing — currently unobtainable** | An addition over the worn skin (sheen, glowing eyes, a dim light), never a repaint or a particle aura. Was a season-tier reward; the season ladder that granted it retired with the Acorn currency (§3). See §17 |
| **Catch effects** | `CATCH_EFFECTS` | coins, or granted by the VIP pass (§15) | A one-shot burst that fires on the **thief**, not on you, the moment you nab loot back out of their hands — the third kind of cosmetic, worn by neither a piggy nor a player. Worn tab (§14); see below |

**Skins are crate-only, which is a deliberate reversal of "nothing is ever
locked behind luck" for this one catalogue.** Most skins are not a guaranteed
coin purchase — they are a crate outcome only, and there is no way to walk up
to the shop and buy the exact one you want. **Prices stay in Config
regardless**, as `sellBasis` where the coin price came off:
`Config.sellValue` caps a payout at a fraction of an item's own `cost` **or**
`sellBasis`, so stripping a price without leaving a basis takes the sell cap
off as well as the rarity — which this project has already measured as a
money printer. A skin's crate *tier* no longer needs the price at all, now
that all 72 carry an explicit `rarity` (§3), but `Config.rarityOf` checks
that field first for every catalogue in the shop, so nothing about the
derivation changed for anything else.

**What stops a crate being a route to its items' coin value is that the
ITEMS are obtainable free.** Every skin in a priced pool is stealable (§5),
so a spare's sell value is a property of the item rather than of the
purchase — which is exactly why the Guardian Crate's coats had to be put on a
rebirth rung as well (§4). `Config.auditRandomOutcomes` refuses a coin `cost`
on a chest or on anything inside a pool (§3).

**Applied at both ends.** `CosmeticsService.buySkin` refuses a coin purchase
by name — *"%s comes from crates now, not coins."* — for any skin that
carries a `cost` and is not already owned or free. There is no card left to
draw a price on any more: the shop's Piggy tab (once the one place a priced
skin was shown at all) is gone (§14), so the refusal is now reachable only by
a stale client or a poked remote, and it stays loud rather than silent for
exactly that reason. A skin is sold nowhere in the shop now except as a
Crates-tab chest outcome; the Inventory panel's empty-skins message — *"Open a
crate to start collecting skins"* — still agrees with that.

### The mini is the till, dressed the same way

**A skin used to be a swatch on the mini and a whole animal on the lawn.**
`Shared/PiggyModel.build` — a snatched piggy's own carry (§3, §5; the coin
robbery's carry is a money bag now and does not go through this builder,
below), every pedestal display, every herd member and every shop card — now
dresses the mini through the *same*
three calls `PiggyBank.applySkin` (a Service, despite living beside the other
`Shared` geometry builders in §2) makes for the till itself:
`PiggyModel.applySurface` (the baked coat on body and trim),
`PiggyModel.applyFur` (a ruff, prewarmed at boot for every set in use via
`furSetsInUse` inside `PiggyModel.prewarm`) and `PiggyModel.configureAura`
(the skin's own particle aura, §3). The mini also gets glowing eyes and the
per-part colour overrides a `skin.parts` table names, in the same order the
till reads them. Designer, 2026-09-21: *"we need the minis to look exactly
like they were built"* — a Bengal Tiger on a pedestal used to be an orange
pig with cream trim; it is a tiger now.

**A mini carries no light.** `AuraLight` (the equipped effect) and `Glow`
(the vault fill) both belong to the till; a point light inside every one of
sixty pedestal minis and up to twenty herd members would be, as `CLAUDE.md`
already records for one lamp inside a piggy, a street that washes itself out.

**Whoever draws a mini finds it by name and waits for its body.**
`ClientMain`'s skin animator collects `Display` (a pedestal), `HerdPiggy` and
`Config.LOOT_MODEL_NAME` (a snatched piggy's carry) by scanning `workspace`
and watching `DescendantAdded`, then `WaitForChild("Body", 10)` rather than
`FindFirstChild` — a replicated model's children arrive after the model
itself, so a `FindFirstChild` answered nil for a display built after the
first scan and left it un-animated forever. The coin robbery's money bag
shares that same model name (§5) and is never mistaken for a skin: the
animator also requires a `SkinKey` attribute to be a string before it
collects anything, and `buildLootBag` never sets one on a bag. Trim is
collected by the `Trim`
attribute as well as by name (`ANIMATED_TRIM`, which now includes `Trim`
itself), because the mesh mini's whole trim is one part and the primitives
fallback still names four (`Snout`/`Tail`/`Ear`/`Leg`). Pruned on
`Destroying`, so a display torn down by the next dress, a herd member by its
catch, and a carry by its delivery each take their entry with them.

### Display scale

**A piggy's size on a pedestal or in a herd is a property of *where it is
standing*, never of the animal.** `Config.piggyScale(key)` reads a skin's own
`scale` field, clamped to `Config.PIGGY_SCALE` (**0.7 to 1.3** — designer,
2026-09-21: *"bee and lady bugs should be smaller but lions and tigers should
be larger"*), and defaults to 1 for a skin with none. `PiggyPedestal.dress`
and `HerdService`'s `buildMember` both multiply it by the **same** factor,
`Config.PIGGY_PEDESTAL.display` (`HerdService.memberFactor`) — a fix on
2026-09-22, designer: *"we need the minis to look like they were built"*.
`buildMember` used to apply `piggyScale` alone, the skin's own *share* of the
size and not the size, so the same Bengal Tiger stood 7.2 studs across on a
plinth and 2.2 in the grass — two animals for one skin. Both callers go
through `PiggyModel.scale` — which `ScaleTo`s the whole model and re-derives
the aura's particle size and speed against the *new* body size, so a
scaled-up display gets the aura the till would show at that size rather than
the mini's own. `HerdService`'s own `Config.HERDS.followSpacing`/`jitter` and
the dig visual's `Config.PIGGY_DIG` dirt/coin sizes are multiples of
`PIGGY_PEDESTAL.display` for the same reason, rather than numbers solved
against the old, smaller mini. **The till and a
snatched piggy's own carry never scale**: the till carries the vault dial,
the hatch, the coin pile and the crack camera, most of them pinned against
its own twelve studs, and a piggy-snatch carry is seated on a hug pose
measured against a 2.2-stud pig (`CarryPose.HOLD`, §5, §10) — honouring
`scale` on either would put the dial off the hatch or the thief's hands off
the pig they are holding. The coin robbery's own carry (the money bag) is
outside this system entirely — it is not a skin and carries no `scale` field
at all; its size instead tracks the thief's own Bigger Sack level (§5).

Because a scaled model's *pivot* is still its body centre, both callers lift
it back onto the ground by `PiggyModel.MINI_CENTRE_Y * (scale - 1)` — a herd
member's own `lift` field — rather than letting a lion float or a ladybird
sink. `Config.auditPiggySlots` checks the band both ways: that
`PIGGY_SCALE.max` cannot put two neighbouring pedestal displays into each
other at the lawn slots' own pitch, and that every skin naming a `scale`
falls inside `PIGGY_SCALE.min..max` — a value outside the band would not
error, `piggyScale` clamps, so a mis-typed row would silently render at the
band's edge instead of what its own author asked for. *Orientation only —
`Config` is authoritative:* the smallest riders are Ladybird and Bumblebee at
0.75, the largest are Giraffe and Bengal Tiger at 1.2.

### Legendary skins are whole models, not paint

**A legendary skin stands a set of meshes over the pig rather than
recolouring it, and the ordinary pig stays built underneath, hidden rather
than removed** — every prompt, the rob badge, the coin pile, the vault dial
and every other seat on a piggy is solved against the real `Body`, so taking
it away would mean re-deriving all of them per skin. `Config.LEGENDARIES`
lists, per legendary key, one row per mesh part: a mesh id, an offset and
size seated in the same frame `Config.PIGGY_MESH` is written in, and either a
`Shared/SurfacePacks` template name (`surface`) or a flat `color` — plus
`neon` to render a part glowing and `hidden` to start it invisible for the
client helper (below) to reveal. A skin reaches its row through its own
`legendary` field and `Config.legendary(skinKey)`.

**`Shared/LegendaryModel.luau`** builds and tears it down. `load`/`prewarm`
fetch every mesh through `CreateMeshPartAsync` once per id and cache the
template, so a dress is normally synchronous by the time anyone wears one.
`dress` recovers the seat from the pig's own live `Body` — undoing
`PIGGY_MESH`'s body offset and turn — so a legendary whose own Body row
matches the ordinary one lands on it to the stud, and one that does not (the
Storm Wolf) is placed relative to it instead of guessed; it also hides
whatever base parts the caller names, stashing each one's transparency on
itself so `undress` can restore it exactly. Two callers dress and undress it
on every skin change: `PiggyBank.applySkin` (anchored, for a plot's own pig —
a shop vault is skipped, since a strongroom has no legendary of its own) and
`PiggyModel` (welded, for the carried loot and every shop/inventory mini).

**The glow is client-side**, in the same family as the animated skins, the
moat and `HouseFX` (§11). `Shared/LegendaryFX.luau` — started once from
`ClientMain` — finds a worn legendary's folder by name in `workspace` and in
the player's own `PlayerGui`, and starts the matching helper from
`Shared/Legendary/`: `StormWolfLightning`, `DragonGlow`, `PhoenixFrost`,
`RainbowTigerGlow`. Each writes its own part colours and emissive strength
every frame, which is why it runs once per client rather than being
replicated.

**So is the idle sway.** On the plot's own pig (`dress` with `rig = true`)
`LegendaryModel` also places an invisible `IdleRig` anchor carrying the rig
frame and scale, and `LegendaryFX` starts `Shared/Legendary/Idle` beside the
glow helper on the same phase. It swings whole parts -- the dragon's wings
and tail, the tiger's cheek ruffs and tail, the phoenix's crest, mantle, ruff
and tail feathers -- about pivots listed in `Shared/Legendary/Rigs.luau`,
each on a sine track fitted to the imported idle clips. Minis and carried
loot do not sway. The Storm Wolf has no rig; its motion is the lightning.

**Four legendaries exist today, all Animal Kingdom skins** (`collection = "animal"`, rolled from the piggy crates since the merge):
`stormwolf` (Storm Wolf, lightning), `dragon` (Ember Dragon, wing embers and
a tail flame), `phoenix` (Ice Phoenix, frost) and `rainbowtiger` (Rainbow
Tiger, a colour-cycling glow) — all four sharing the wolf's own `sellBasis`,
without which an unpriced legendary would sell for the flat tier value
`Config.sellValue` pays a legendary with no basis at all. The Storm Wolf's
own `anim` field is gone: its lightning is the client helper's job now, not
the ordinary `SkinKey` palette animator, which paints the (now hidden) Body.

### The guard dog's wardrobe

**A coat is taste; the dog's stats (§5) are fixed, and the split is
structural rather than a promise.** With the Guard Dog rung retired, every
plot's dog is the same `Config.DOG_LEVEL` Shepherd — so `Config.DOG_TIERS`'
`scale` and breed `shape` (`leg`/`girth`/`head`/`earDroop`) no longer even
vary by what a player bought; they are simply what that one tier looks like.
A coat no longer needs to be *kept off* those fields to stop it being power —
it never had a rung to unbalance — but the split still holds: `GuardVisual.key`
lets a coat's `guardModel` render **any** breed's rig over the fixed
Shepherd stats, so a Cerberus skin is a Shepherd wearing a Cerberus, never a
faster or tougher one. `GuardDog.applyTier` is the *only* place a coat or
kennel is painted: a coat supplies `fur`/`furDark`/`collar`, a kennel supplies
`wood`/`trim`, and an empty `equipped`/`kennel` falls back to the breed's own
colours or the plain wooden kennel — the same toggle-to-remove convention
accessories and decorations use. **The kennel's roof always takes the
*coat's* `collar`, never a kennel skin's own** — so a bought kennel and a
bought coat read as one dog's house rather than fighting over who owns the
roof.

**There are THREE routes to a guardian, and a row belongs to exactly one of
them** (designer, 2026-09-23). Which route is read off the row's own fields
rather than from a list kept somewhere else, which is what stops the shop
card, the server refusal and the crate pool ever disagreeing about a coat:

| Route | Field | Rows |
|---|---|---|
| **Free** | `free = true` | **Scrappy** (the `terrier` key), and only Scrappy. `DataService.reconcile` grants every `free` coat into `data.dogs.owned` on every save, so the card is OWNED on a brand new account |
| **Coins behind a rebirth** | `cost` + `unlockRebirths` | **Husky** at rebirth 1 (250M) and the **Mastiff** at rebirth 2 (500M, down from 6) — kept earnable so that the breed a player has seen on somebody's lawn can be worked toward rather than rolled for, which is "nothing is locked behind luck" held on the pair where it costs the crate nothing |
| **Crate only** | `chest = "guardian"` | **the other five** — Gorilla, Raptor, Triceratops, Dire Wolf, Cerberus — reachable no other way: no `cost`, no gate, an explicit `rarity` and a `sellBasis` |

**`Config.DOG_COATS` is EIGHT rows now, one per `GuardCatalog` rig, not
thirteen** (designer, 2026-09-23: *"get rid of all the different colour dogs
that are the same model, we only need one of each"*). The Shepherd body used
to carry **six** palette-only coats — Chocolate, Husky, Golden Boy, Spotless
Dalmatian, Shadow and Glacier — selling one animal in six colours; five are
retired (Chocolate, Golden Boy, Spotless Dalmatian, Shadow and Glacier —
Shadow was the earlier coins-behind-a-rebirth row, now gone outright) and
Husky is the one kept, moved onto the rebirth-1 rung Shadow used to hold.
**Husky survives on the strength of its name**: a coat's `name` is what
`GuardRig.species` prints on the nameplate, so it has to be a species —
"Golden Boy" and "Shadow" are given names and would print `Rex / SHADOW`, a
given name sitting in the species row, and Husky is a breed. The five
retired rows are pruned from `data.dogs.owned` and `data.dogs.equipped` by
`DataService.reconcile` against the live catalogue, the same generic
retired-catalogue-entry pass every other cosmetic table gets, so a save
still holding one needs no migration — it simply falls back to whichever
coat (or the bare breed) it names next.

- **Every refusal is said out loud and names the route.**
  `CosmeticsService.buyDogCoat` refuses a crate coat by naming the crate
  (*"The Gorilla comes from the Guardian Crate."*) and a gated one by naming
  the rebirth — with the gate checked **above** the price, so a player short
  of both is told the one coins cannot fix. An **owned** coat is never gated:
  rebirth wipes power and never cosmetics, so one bought at rebirth 7 still
  equips at rebirth 0.
- **Every crate coat's stated `rarity` is the one its old price derived**, so
  nothing re-tiered when the prices came off, and the pool is 3 rare
  (Gorilla, Raptor, Triceratops) / 1 epic (Dire Wolf) / 1 legendary
  (Cerberus) — **no common rung at all**, matching `Config.CHESTS.guardian`'s
  own `odds = { rare = 60, epic = 30, legendary = 10 }`. Epic and legendary
  are the thinnest rungs at one each, which is the number to watch as coats
  come and go — `liveOdds` drops an *empty* tier and reprices the crate, so
  what matters is whether there is one at all.
- **The Guardian Crate is off the rebirth ladder** (§4) — `Config.REBIRTH_CRATES_RARE`
  is piggy crates only, so a rebirth never hands over a coat any more; the
  guardian ladder above is bought directly instead. That reopens a
  compliance question the rebirth rung had closed (§4, §15): the five
  crate-only coats are not stealable and no wild piggy wears one, so their
  `sellBasis` is purchased content carrying a coin value again — latent,
  because nothing in the game currently sells a coat.
- **A coat travels every path a skin does.** `Config.catalogueFor` answers
  `coat` — its seventh kind — and `Config.chestPool` has a `coat` branch on
  the same `chest`-tag test a skin uses, so the pool, the rarity grouping,
  the unowned-only filter, the sort, `getSetItem`, `sellValue`, the spares
  prune and `auditRandomOutcomes`' own per-entry checks all work unchanged.
  **`ChestService` has no coat branch at all.** `COSMETIC_KINDS` is
  deliberately *not* widened with it: that list is what gets *swept* (for
  pass exclusives, say), and this maps a kind to its table.
- **Scrappy is a rename and nothing else.** The breed was called "Terrier",
  which is a species and reads as a label rather than an animal — and this is
  the one guardian every player owns, so it wanted a character. The **save
  key is untouched** (`terrier`, `guardModel = "terrier"`), because a key
  rename is a migration nobody asked for. What it costs is that an unnamed
  dog wearing it reads `Rex / SCRAPPY` — a given name in the species row —
  which is affordable for the one coat everybody has.
- **Scrappy carries no `rarity` tag, deliberately.** `rarityOf` derives
  `common` from a nil cost, which is the right tier, and adding the tag would
  make `Config.isSellable`'s `earned` test truthy and walk a free item past
  the guard that refuses selling one. **A free thing may never be sold**, and
  with no cost, no rarity and no earned tag it is refused by a check that
  already existed.
- **Gorilla, Raptor and Triceratops** used to carry a `requiredTier` matching
  the retired dog rung; that gate could only have read "requires a tier
  nobody can buy", so it is gone and all three are crate rows now.

**Guard duty repaints a vest now, not the collar.** With the collar a coat
colour, the old tell (a neon collar reading ON GUARD) would go unreadable the
moment anybody bought one. `Config.DOG_DUTY_VEST` is a fixed colour, never
buyable, visible only while `GuardDog.onGuardDuty` is true — a state readout,
not a cosmetic, so it cannot be recoloured into invisibility.

**Naming is the one place in the game a player's own text reaches another
player, and it is filtered accordingly.** `CosmeticsService.nameDog` is the
only caller of `TextService:FilterStringAsync` /
`GetNonChatStringForBroadcastAsync`; both are pcalled, and either failing
**refuses the rename** rather than falling back to the raw text — a
moderation call that errors must never fail open. Clearing a name is free and
skips both the filter and the cooldown; setting one is rate-limited
(`Config.DOG_NAME.cooldown`, 45s) to bound the call rate against Roblox's own
API, not to charge for it. The name replaces the tier's placeholder — since
`Config.DOG_LEVEL` is fixed, that placeholder is always **"Rex"** now, on
every plot, whatever coat is worn over it — on the nameplate and is painted a
second time onto a `NameBoard` over the kennel door — but never touches the
breed line under it, which a thief still reads to price the risk regardless
of what the dog is called or which rig its coat is rendering.

**Dog toys are retired.** The ball, water bowl and bed — and the coin
purchases, shop section and save field that went with them — are gone
entirely; a dog now only ever patrols or **sleeps inside its own kennel**,
nose at the doorway, which reverses an earlier build that slept it on the
lawn in front of the door. That earlier placement was never actually forced
by the rigs — every breed fits its own kennel at its own scale, measured
against the real meshes — the real fault had been the kennel's own origin
sitting half a stud into the lawn. `GuardDog.kennelScale` derives the
kennel's scale from the rig that has to live in it (`GuardVisual.apply` now
writes `GuardHalfWidth`/`GuardBack`/`GuardFront` straight off the imported
mesh, rather than a second, hand-typed guess at a size the geometry already
knows), and `sleepCFrame` seats the dog on the kennel floor with its nose at
the opening — buried at the back would read as no dog at all from the
pavement. What a thief reads is unchanged either way — the sleeping
*posture*, not which side of the doorway it is on, is the tell. The
kennel's built-in food bowl is also gone (`Bowl`/`BowlRim`), since nothing
in the game ever fed the dog from it.

### The garden

Three plot-wide catalogues — `Config.BORDER_PLANTS` (4 rows: Lavender Row
40K, Box Hedge 120K, Rose Bushes 350K, Sunflowers 900K), `Config.GARDEN_PATHS`
(4 rows: Gravel Path 25K, Stepping Stones 90K, Herringbone 300K, Marble Walk
1.2M) and `Config.WINDOW_BOXES` (3 rows: Geraniums 60K, Daisies 160K,
Trailing Ivy 520K). **None of the three consumes a lawn slot** — the four
slots in `Config.DECOR_SLOTS` (§11) stay exactly as scarce as they were; a
border runs the fence line, a path runs the gate to the pig, and a box hangs
under a window, none of which is a `DECOR_ITEMS` position. All three are
bought, worn and put away through one control, `CosmeticsService.buyGarden`
(kind `border`/`path`/`window`) — buy it if you don't own it, wear it if you
do, take it off if you're already wearing it, the same toggle accessories and
decor already use.

**A border's height is bounded by the fence standing beside it, and that is
the load-bearing rule.** `Config.borderHeight(spec, fenceLevel)` clamps a
plant's authored height to `tier.decorTop - Config.LAWN_LIFT` for the fence
tier actually standing (`LAWN_LIFT` because the fence is built off the world
ground and a border is planted a stud higher, on the lawn). A plant at height
H can occlude no more than a fence of height H already does, so a clamped
border provably hides nothing the fence does not — by construction, at every
tier, rather than by a measurement somebody has to redo. **What this costs is
real and stated plainly: a plot's fence tier now sets how tall its garden may
be**, from 3.2 studs at Rickety up to 7.9 at Barbed Wire, Electric or the
Moat — the tall garden is available to the player who has already paid to
hide their own pig, never to the one who hasn't. A path and a window box
carry no such clamp: a path is laid flat and hides no sightline at all, and a
box's own height is fixed by the sill it hangs from.

**Rebuilt at the two seams that would otherwise leave one behind.** A border
is rebuilt at the end of `PlotService.buildFence` — its clamp and its gate
gap both come off the fence tier, so a fence purchase has to redraw it. A
window box is rebuilt at the end of `PlotService.setHouseLevel` — it hangs
off `Sill` parts inside the house model that function tears down and rebuilds
every time a tier changes, so a box left over from the old house would be a
planter floating where a window used to be. `PlotService.setGarden` is the
one place all three are put up together (on a purchase, and on a plot's
initial build), and both rebuild functions restore whatever is already
equipped without being told what it was — `plot.garden` is sticky on the
plot for exactly that reason.

**An existing lawn ornament learned to read the garden's neighbour, the
skin.** The `topiary` decoration — a hedge clipped into a pig — is coloured
from its owner's equipped piggy skin (`plot.skinKey`, now threaded through
`Decor.build`'s sixth argument and `PlotService.applySkin`), lerped 0.34
toward the hedge's own leaf green so a pale skin does not read as a dead
white bush. It keeps `Enum.Material.Grass` and takes no `reflectance` off the
skin — a topiary is a plant with a colour, never a second, shinier pig — and
an animated skin is sampled at its palette's first stop rather than driven
per frame, the same "sampled, never driven" rule the shop's own skin icons
follow.

*Orientation only — measured live, not a `Config` value:* a fully planted
plot (border, path and boxes all equipped) is 114 parts, about 1.3% of the
world. Every part is `CanCollide`/`CanQuery`/`CastShadow` false, the rule the
rest of the lawn already follows.

### Catch effects

**The third kind of cosmetic, and the first one that lands on somebody
else.** `Config.EFFECTS` is particles on your own piggy and `data.gear` is
worn on your own body — both are seen by other people and neither is a thing
you *do* to them. A catch effect is a one-shot burst that fires on the
**thief**, and only at the moment a player's own tug (§5) *empties* them —
never on a guard dog's catch and never on a patrol confiscation (§7), both of
which are instant and total rather than a hold anyone can win a share of —
which is also why it lives in its own top-level save table (`data.catch`)
rather than inside `cosmetics`: a catch effect is not worn by anything, it
fires on the person you just caught.

**Three rules, and without any one of them this is a harassment surface.**
It may never change an outcome — no slow, no stun, no push, no collision, no
query; the stun that lands with it is `Config.STUN_SECONDS`, the same stun
the tug itself already applies on an empty, and this is drawn on top of a
thing that has already happened rather than causing it. It may never
obscure the other player's view — nothing here is a `ScreenGui` or a camera
write, it is particles in the world at the thief's own feet, loudest to
everybody watching and quietest to the person it landed on. And it expires
with `Config.STUN_SECONDS`, derived rather than pinned, so it can never go on
marking somebody who has already got their legs back.

**Published as two attributes on the thief's own character and rendered by
every client itself** (`Config.CATCH_ATTRIBUTE`, the key, and
`Config.CATCH_COUNT_ATTRIBUTE`, a counter written second so a repeat with the
same effect still fires a changed signal — the `DodgeRoll` shape).
`Shared/CatchFX.luau` is the fourth client-side animator in the same shape as
the animated skins, the moat and `HouseFX` (§4, §11): the server decides and
publishes, every client builds the burst for itself, and nothing it builds
collides, queries or touches the screen.

**Whoever recovered the most wins the burst**, with whoever started the
recovery breaking a tie — the same measure the recovered coins are already
split by, so the cosmetic and the money answer the same question about who
did the work. Bought and equipped through one buy-or-equip control, the same
as a skin or a dog coat — except it does *not* toggle, because `none` is a
real, free member of the catalogue and is how a player turns a catch effect
back off; a toggle here would only be a way to un-equip by accident.

**Seven rows spanning all four rarity tiers by construction**: `none` (free),
then `dust`/`coins`/`bubbles`/`sirens`/`thunder` priced across common,
rare, epic and legendary — the spread `Config.EFFECTS` never had, which is
why that catalogue stays direct-purchase rather than moving to a chest
(above). **`paparazzi`** is the one entry that is about the *catcher* rather
than the loot — a camera flash, since the arrest scene already taught the
street to read one — and it carries `pass = "vip"` and no `cost` at all: it
is granted, never bought, by the VIP pass (§15).

### The trophy shelf — retired; the indoor trophy room retired with it

**The ten-lawn-ornament trophy shelf and its coin-bought plinth ladder are
both gone.** `Config.TROPHIES` and `Config.TROPHY_PLINTHS` are now empty
tables. Every trophy was a `Config.DECOR_ITEMS` row competing for one of the
four scarce lawn slots (§11), and the room that scarcity was designed for is
what refused it: a trophy is a 3D object with real depth, and hanging ten
differently-shaped ones in a fixed-size lawn slot cut through the slot's own
edges on some and left it half-empty on others. The counters underneath —
`data.trophies` (victims robbed, catches, best spree, clean cracks, wanted
appearances, own-tree harvests, `bestBounty`) — are **not** deleted; the game
was already computing most of them for other reasons (`data.totalStolen` and
`data.gear.escapes` in particular predate the trophy shelf entirely), so
losing the readout would have thrown away arithmetic rather than a system.

**What replaced it, `TrophyRoom`, is retired too — one day after it
shipped (2026-09-22).** `Services/TrophyRoom.luau`, which drew stat panels and
a wanted poster onto an *authored* house template's named mount points
(`Wall`, `Shelf_1..N`, `Featured`, `Record`, `Plaque_Legacy`, `Door_Exit`), is
deleted outright, and `PlotService` no longer calls `TrophyRoom.fill`.
`PlotService.setTrophyState` still exists and is still the one function every
counter above reports through — it still writes `plot.trophies` and still
rebuilds the (now-permanently-empty) lawn slot through `setDecor` when the
plot has a placement — but nothing renders the numbers any more: entering a
house lands in a real interior instead (`InteriorService`, §12), a fixed room
built off the map rather than an authored template's mount point, and the
achievements are meant to move into that base later. Nothing currently reads
`plot.trophies` to draw anything anywhere, which is a genuine, current gap
rather than a documentation lag — see §17.

**Three of the eighteen house tiers now build an AUTHORED interior instead
of that generic hall (`Services/ThemedInterior`, 2026-09-23).**
`Config.HOUSE_INTERIOR_KITS` maps a house tier's `id` to a `ServerStorage`
art package: the Cardboard Fort (`shack`, the free starter every save
already owns, so it is the interior a new save walks into), the Beehive
Cottage (`cottage`) and the Treehouse (`treehouse`). One wrapper builds all
three — their `Builder` modules are byte-identical apart from the folder
they clone from, so what differs is the art rather than the geometry
contract — and hands `InteriorService` back the same `HouseInterior.Refs`
shape the generic hall does. The other fifteen tiers keep the generic hall
until a kit is authored for them, and a server whose `ServerStorage` is
missing a kit falls back to it too, once per kit, said at boot rather than
silently. Nothing about this touches the gap above: still no achievement
wall is drawn on either kind of hallway, only what stands behind the door.

**Indoor shop counters.** `InteriorService` adds `Shared/BaseShopStand`'s
Gadgets and Guardians counters to every built lobby, including the generic
fallback. They flank the entrance and move outward with its aperture so the
door and central aisle stay clear. Each has a static `ResidentModel` shopkeeper
and a reserved bay behind the counter. A nearby Browse prompt opens the existing
gadget or guardian catalogue through `ShopDoor`; it never purchases on approach.
Guardian acquisition rules remain in the catalogue, including Guardian Crates
for gorillas and dinosaurs. The counters park and rebuild with their hallway.

`TrophyService` (§12) still requires only `DataService` and `PlotService`,
still owns every counter above, still calls `PlotService.setTrophyState` on
every change, and still pushes a shop-card repaint through a registry (`Main`
fills it with `CosmeticsService.push`) — none of that plumbing changed, only
that nothing downstream of `setTrophyState` draws anything any more.

### The roll — retired

The accessory roll was the older of the two random-outcome mechanics, and the
one the regular crates' own collection rule (duplicates allowed, producing a
spare, §3) was written to deliberately reverse. It is gone now, in the same
edit that emptied `Config.ACCESSORIES` (§9): `CosmeticsService`'s
`ownedCount`, `rollFrom` and `rollAccessory`, `Config.getRollCost` and its two
constants all went with the catalogue they rolled from. `Config.ROLL_CURRENCY`
retired later, with the Acorn currency it named (§3) — the roll had already
been its last spender for some time by then.

**The `animal` shelf's epic tier is a different technique per animal, not a
palette per animal.** Designer rule, 2026-09-21: an epic needs *"an
aura/glow/animation and either a pattern or a small amount of geometry"* —
built the same way the
mini renders any other skin (above), so each reads on a plinth and not only
on the till. **Hedgehog** (scale 0.85) is `PiggyModel`'s `shards` pattern —
quills raked back over the crown with no parting — plus the `fireflies`
aura. **Peacock** is a fan of eyed tail feathers
standing up behind the body — `Shared/SkinFX`'s `peacock` builder, one of the
per-skin geometry kinds `SkinFX.apply` welds onto the mini alongside a
pattern — with the `prism` aura. Neither carries a `sellBasis`; an unpriced
epic sells at the flat tier value every other unpriced epic does.

Two more stood here and do not now. **Storm Stone** was retired on
2026-09-23 (there is no Storm Stone; the skin is Stormcaller) and **Lion**
was deleted outright the same day, taking its `Config.SURFACE_PACKS.lion`
row, both `SurfacePacks/lion*.model.json` sheets and the `lionmane` fur set
it was the only wearer of. Nothing had to be migrated for either: a retired
skin key is answered at every read — `Config.piggyKeyAt` returns nil for a
placed one so the pedestal stops earning rather than earning the floor rate,
the till falls back to Classic in `DataService.reconcile`, and the wardrobe,
spares and trophy shelf are all pruned against `Config.SKINS`.

**No epic ever reaches a resident's lawn or a street herd**, animal or `og`
alike — see §17.

### Rarity

**One ladder for the whole shop**, `Config.RARITIES`, with **absolute** coin
bands. An explicit `rarity` wins; otherwise the price determines the tier. That is what keeps it honest as the shop grows.
**Only things you keep get a tier** — consumables deliberately have none.

The chests in §3 reuse this same function (`Config.rarityOf`) to sort their
stock into odds bands — one tier system for the whole shop, not a second one
invented for chests.

**Skins were the one catalogue that never landed on all four — not any
more.** All 72 carry an explicit `rarity`; `epic` sat empty for the length of
the three-tier interval and is stocked again as of 2026-09-21, when the
**OG FAMILY** block added six epic skins alongside two commons and six
rares, and the `animal` shelf's own four epics (Hedgehog, Lion, Storm Stone,
Peacock, below) landed the same day (§3) — two of which have since gone,
which costs the tier nothing while it is stocked. `martian`, the Alien Cache's own
skin, is no longer the game's
sole `epic` skin — it is still the sole one sorted here as a *set* item
alongside the alien set's other member, `hoverdisc` (§8), rather than as a
member of a skin chest, which is why it never depended on the restructuring
either way.

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
  takes that list rather than deriving its own — and always adds the keys
  that belong to a *player* rather than a ride: `dodgeRoll`, `sneak` (the
  tiptoe's own gait, §5, `Shared/SneakWalk.luau`) and the **two** carries,
  `carry` and `carrySling` (the hug and the sling, §5, `Shared/CarryPose.luau`
  — split from one key into two on 2026-09-23, below) — so `Main` warns at
  startup for any of the lot with no id. `animdump`'s own `own` table maps
  each of those player-owned keys to its builder and is *walked* to produce
  the upload list, rather than a second hardcoded copy of the same names
  sitting beside it — so another player-owned animation is one row there
  and the ride loop skips it for free, and none of them can silently go
  unbuilt the way `sneak` once did. A stance with no id falls back to the
  plain pose for that ride rather than to no pose at all.
- **Move the bike to the hand, never the hand to the bike.** Poses are measured
  on a live rig, then the ride's grips and pedals are placed at what came back.
  A real bicycle does not fit a Roblox character.
- **A stance is an override, never a whole pose**, merged one level into `left`
  and `right`.
- **A trick is driven by the machine, never by a clock** — `RidePose.phaseOf`
  reads the chassis each frame, so the rider cannot desync from the bike.

**Speed table (orientation only — `Config` is authoritative):** base 24 ·
carrying 18 · dogs 18 / 21.75 / 25.5 · officer 21.75 · fence snags ×0.80 → ×0.30 ·
electric stun 0 · climbing ×`CLIMB_SPEED_RATIO`×`CLIMB_MULTIPLIER` (§5) ·
tiptoe ×`Config.getTiptoeMultiplier(level)` — `Config.TIPTOE.base` to `.max`
across the Sneak rung, §5 — refused while carrying or climbing.
**Anything that makes a player faster than 24 invalidates several systems at
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

**Music** is client-side and per listener (`Shared/Music`, started from
`ClientMain`). The settings panel (the gear in the topbar) holds its two
controls: the `settings.music` on/off toggle and a volume slider saved as
`settings.musicVolume`, a 0..1 position where `Config.MUSIC.SLIDER_DEFAULT`
is the tuned level and reads 100%. The slider scales the rotation and the
chase layer, never the effects, and saves on release rather than per frame. The rotation is
`Config.MUSIC.TRACKS`, drawn from a shuffled bag so every track is heard before
any repeats. Each plays through once with no loop and the next starts as it
ends (`Config.MUSIC.GAP` is 0), so the score runs continuously. `Music.duck` lowers it under the siren and the arrest
scene.

**A robbery switches to a chase layer** (`Config.MUSIC.CHASE`). The thief (the
local character holds the coin sack, whose loot model has `CARRY_KIND` "sling",
or is hauling a piggy marked `PIGGY_HAUL_ATTRIBUTE` "stolen") hears the `thief`
track. The victim (another character's `CARRY_VICTIM_ATTRIBUTE` or
`PIGGY_HAUL_FROM_ATTRIBUTE` is this player's UserId) hears the `victim` track;
being the thief wins over being robbed. The rotation fades out for it and
returns `CHASE.resume` seconds after the chase ends. A chase track is unlooped
and resumes where the last chase left it. A resident or shop robbery gives the
thief the layer and nobody the victim track. `PIGGY_HAUL_FROM_ATTRIBUTE` is
set and cleared by `PiggyHaulService` beside `PIGGY_HAUL_ATTRIBUTE`.

**One-shot cues** live in `Config.SOUNDS`. A `good` toast plays `NOTIFY_POP`,
set in its `Config.NOTIFY` row, and the other toast kinds keep theirs.
`MILESTONE` is blank, so the pig's fill milestones, the spin-wheel win and the
loot-haul reveal are silent until something is chosen for them. A guard dog
taking a bone plays `BONE_BITE` (the Sound named "Squeak" in `GuardDog`). A
plunger knockdown plays `PLUNGER_SLIP` in the world from
`GadgetService.showHit`. `SIREN` is empty on purpose.

---

## 11. The world

One street, ten plots in two rows of five (`Config.PLOT_COUNT`,
`Config.PLOTS_PER_ROW`) — one column more than the eight players a server
holds, on purpose (below) — a **wide verge** carrying the boards and the
shops, and a hill with a tunnel through it at both ends — ringed, beyond the
valley wall, by four more layers of scenery so the map reads as a valley
rather than a floating plate from any camera above it (below).

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

**The street then grew a fifth column, for a reason that has nothing to do
with the walk: supply.** A resident house is seated on every unclaimed plot
(§5), so with `Config.PLOT_COUNT` equal to `Config.MAX_PLAYERS` a full server
had none at all — exactly the population this table was originally arguing
should stay possible to play. `Config.PLOTS_PER_ROW` went 4 → 5 rather than
cutting `MAX_PLAYERS`, which was tried once and rejected for removing children
from the street instead of adding victims to it (`MaxPlayers`, below). The row
went 240 → 320 studs, and corner-to-corner is now **351 studs / 21.9s** — past
the 336 / 21.0s that justified cutting the map from twelve plots in the first
place. `PLOT_SPACING` itself did not move, so every walk a player actually
makes is unchanged (next door 80 studs / 5.0s, across the street 144 / 9.0s,
the getaway 53 studs / 4.4s), and rides did not exist when the twelve-plot map
was cut — the same corner-to-corner run is 20.0s on foot, 14.8s on the
25,000-coin skateboard and 9.5s on the 4.5M-coin scrambler.

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
three is where that argument stopped — until the resident supply floor
bought a fifth, above.

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
against the fixed guard dog at 14.5 (above) — nobody does it, and half the server stops
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

`YARD_DEPTH` and `HOUSE_FRONT_LINE` both moved, and neither was picked by
hand any more. `YARD_DEPTH` is `HOUSE_FRONT_LINE` plus the deepest house in
the catalogue plus `Config.HOUSE_BACK_GAP`; `PlotService.auditYard()` (below)
now MEASURES the deepest house at every boot, per part, rather than trusting
a hand-take of the Sky Castle that had already gone stale by the time the
fantasy tiers landed. `HOUSE_FRONT_LINE` came forward because the lawn's own
back row retired (*The lawn is rows, not a ring*, below) and freed the
rearmost slot it used to clear — both constants shrank together, and the
audit is what catches the next tier that no longer fits either fence.

**What the widening actually bought is room in the house catalogue.** Every
tier fitted inside the old fence interior and always had — the widest building
was the Marble Palace when this was last hand-measured — but it left barely
two studs of headroom, so the next wide tier had nowhere to go. It now has
eighteen, and which tier is widest no longer needs re-deriving by hand:
`auditYard()` reports it fresh every boot. *(The long-standing claim that the
Sky Castle overhung the fence by 8.3 studs a side was a measurement error,
not a bug: see the `HouseFX` rule below.)*

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
| The Piggy Press | mid-verge (`boardZ`), the next free gap out from the boards' — x 120 today | 5.1 at its tightest, printed at startup |
| Four shopfronts | back of the verge (`shopZ`), \|z\| 32.4, on the outer gaps | 4.8 to the front ClimbZone |

The two `|z|` figures survived the plot widening untouched, because both derive
from `PLOT_FRONT_LINE` and the plot got wider rather than deeper. **That is the
whole payoff of splitting the constant.**

- **One pair of boards, not two.** A SurfaceGui culls on distance from the
  *character*, so a single pair at one end of the street was never rendered for
  the far half — two pairs was the workaround. Centred at x 0, no plot is
  further than two `PLOT_SPACING`s along the street from the pair (it was one
  and a half at four a side; the fifth column pushed the outermost plots
  further out). They face each other across the road, standing on grass.
- **The Piggy Press**, the combine machine (§3) — a hopper, a ram and a chute
  on a plinth with a name plate over it, front to the road, on the
  leaderboard's own shoulder so that the two things out here a player walks up
  to and *reads* share a side. **Which gap it stands in is derived**
  (`CombineStation.freeGaps`, the next one out from the boards') rather than
  typed, so a column added or a shop moved carries the boards and the machine
  together instead of standing either on somebody's tarmac. Both street trees
  in its gap still stand — the veto measures its real footprint and currently
  refuses neither. Its clearances are printed at startup and warned on if one
  ever goes negative.
- **Four shopfronts**, one per shop tab, and they are four different
  *buildings* — a boutique with a pitched gable and a scalloped blind, a
  glasshouse with an open front, a workshop with a roller bay and a quarter
  pipe, and a strongroom with a castellated parapet and barred glass. Each
  carries a **projecting bracket sign**, because a fascia faces the road and
  is edge-on to anybody walking along it.
  - **They are gates now, not destinations** (designer, 2026-09-23). The line
    that stood here said the opposite — *the panel still opens anywhere with
    B, and the door prompt only saves picking a tab* — and that is exactly
    what made four buildings, four window displays and four fascias into
    scenery. The HUD basket opens the **Robux** shelf and nothing else; every
    shelf bought with coins is behind a door.
  - **And then the shop moved off the door and onto the counter**
    (designer, 2026-09-23: *"players should have to go inside and interact on
    the npc at the counter in order to shop instead of on the door from the
    outside"*). The trigger is an invisible anchor standing in front of the
    shopkeeper now (`ShopFront`'s `CounterServe`, at `Config.SHOP_ROOM.keeperX`
    and ranged to `ShopFront.SERVE_RANGE`), not the door — a player has to
    walk inside to shop rather than pressing a sign from the pavement. The
    door still carries its tag and its `tab` attribute, so a probe can find
    "which shop is this" without walking to the back, but it no longer holds
    a `ProximityPrompt` of its own. `NeighborhoodService` re-checks
    `Config.shopRoomHolds` on every counter press — the same room test the
    vault behind it already makes (§5) — so a trigger reaching outside the
    walls is refused server-side however far its own range would otherwise
    carry.
    Four are these units and two
    are counters in a player's own hallway (§6), which is six counters for six
    shelves — `Config.SHOPS` and `Config.BASE_COUNTERS` are the complete list,
    each row naming the `category` it serves, and `tests/luau/shopui.luau`
    refuses a shelf with two doors or none.
  - **The window holds the real item**, built by the same function that puts
    one on a lawn or under a rider: a mini piggy, a BMX, a Golden Bone. The
    garden centre has none on purpose — its stock is its frontage.
  - **The neon is `HouseFX`**, the animator the house light show already uses.
    A tag and an `FX` attribute per part, no new animation code, and its
    `MAX_RATE` ceiling means nothing here can be authored into a strobe.
  - **Each one now hides a robbable vault on its own back wall** (§5,
    `Config.SHOPS`) — a strongroom built by `Shared/VaultModel.luau` and
    wrapped in a piggy bank's own `Refs`, on a plot no player can ever claim,
    which is what keeps the street's supply of victims from running out on a
    full server. There is no piggy bank standing outside any more — robbing
    one means walking in, and `Config.shopRoomHolds` tests the room itself
    rather than a distance from the vault (§5). Both street trees stand in
    every gap again now that nothing needs to stand outside for it.
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
Count**, or on the Creator Dashboard.

**`Config.MAX_PLAYERS` is a plain literal now, deliberately BELOW
`Config.PLOT_COUNT`** — 8 against 10 — and the gap is the point: a resident
house is seated on every unclaimed plot (§5), so with the two equal a full
server had none at all, exactly when the game was busiest. The fix was tried
the other way first — capping `MAX_PLAYERS` to 6 against 8 plots, to open the
same gap — and that was **rejected**: it buys supply by removing children
from the street, the one resource a busy server is made of. `PLOTS_PER_ROW`
grew instead (4 → 5), which opens the identical gap by adding a column rather
than subtracting players. **It may never sit ABOVE `PLOT_COUNT`** —
`Config.auditRobbery` refuses a cap that is, on top of `Main` kicking anybody
it cannot seat — and narrowing the gap further needs another column, not a
smaller `MAX_PLAYERS`: `Config.RESIDENT_FLOOR` (`Config.SHOP_COUNT` plus
`PLOT_COUNT - MAX_PLAYERS`) is the non-player supply floor at every
population, and it is what `Config.auditRobbery` measures against a full
server (§5).

### The lawn is rows, not a ring

`Config.DECOR_SLOTS` is a **grid**, plot-local with +Z toward the street, and
it has shrunk twice from the nine-slot grid it started at. The two middle
rows keep their outer columns (`lawnE`/`F`, `lawnG`/`H` — the inner pair sits
inside the piggy bank and the gate walk from the street): that is **four lawn
slots**. The front row's left slot (`lawnI`) went first, to the acorn oak and
its storage crate (§3); the four-column back row (`lawnA`–`lawnD`, at z −20)
went in this pass — the front-right corner was always the kennel, never a
slot — which is what let `Config.HOUSE_FRONT_LINE` move forward and
`Config.YARD_DEPTH` shrink with it (above). Two verge slots (`vergeL`/`vergeR`)
flank the driveway outside the fence, and they are still the only ground out
there that stays dry at fence tier 5.

**The row spacing is one number covering every pair.** Ornaments are far
shallower than they are wide, so two slots whose Z differs by more than the
deepest ornament cannot overlap whatever stands in them — one rule for every
item pairing in the catalogue instead of a per-pair clearance nobody
re-checks when the next ornament lands. **An ornament deeper than the row
spacing breaks this and has to move the rows**, which is the one thing to
check before adding one.

**The old ring was measurably broken.** Its spacing argument had been written
against the gnome when the widest ornament is the Wacky Waving Man, and was
never re-derived: four of the seven slots put the widest item through a side
fence and two adjacent pairs overlapped outright.

**What limits the column count is that one ornament, not the plot.** Each of
the two remaining rows fits two columns because the piggy bank, the gate walk
and the kennel claim the rest of the grid — never because of item width. A
narrower widest ornament, or a wider lawn, is the lever if more slots are ever
wanted. The lawn trophy shelf that once competed for these same four slots is
retired (§9); nothing standing here now records anything but what you bought.

**The kennel moved to the front-right corner** when the plot widened — on the
old narrow lawn its position was near the edge, and on the wide one the same
offset stood a third of the way in, with the dog napping in the middle of
somebody's garden. The corner is also what buys a slot back: it holds exactly
one grid position, where anywhere in the middle would have cost two. It
is placed by `PlotService.buildPlot`, not by `Config.DECOR_SLOTS`.

**It stands at plot-local `(KENNEL_X, 0, KENNEL_Z)` — (25, 0, 16) — turned by
`KENNEL_YAW` (a quarter turn, −90°) so its doorway faces across the lawn
rather than out at the street.** `GuardDog.clampToYard` then holds every
destination an ordinary patrol is ever sent to — a random patrol point, its
sleep spot (§9) — inside the **fence** rectangle (the same one
`PlotService.yardContaining` tests for ride and trespass purposes), inset by
the dog's own reach at its current breed scale. A **chase is a separate,
looser leash**: `Config.DOG_CHASE` extends that box forward to the end of the
driveway (`streetMetrics().driveFar`), so a dog may run a fleeing thief past
its own fence line and out onto the drive, but never onto the street itself
— see §5.

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

The street and grove use two **faceted scenery-tree models** from
`ServerStorage/SceneryTreeTemplates`: a branching broadleaf and a tiered evergreen.
`Services/SceneryTrees.luau` caches normalized templates, preserving their painted
textures, and clones them with deterministic rotations and slight size/tint
variation. Street trees are broadleaf; one quarter of the grove's candidate seeds
select evergreens. There are currently 24 street trees and 30 grove trees,
including eight evergreens. Each uses only two or three nonqueryable
MeshParts; render fidelity is authored on the templates. **The canopy still
answers no query and casts no collision** — a character walks straight
through the leaves — **but the trunk does now** (below).

The models fit the existing `Config.TREE_MESH` width, depth and height envelope,
so NeighborhoodService's planting and clearance calculations remain authoritative.
The previous mesh loader remains as a fallback if the synced template library is
missing. These are pure street/grove scenery — there is no plot tree of any
kind any more (the residential Acorn oak retired with the currency, §3). Asset
IDs and previews are recorded in `assets/scenery-trees/`.

**A canopy's reach is measured by its diagonal, not its depth, because every
tree carries its own yaw for variety** — `NeighborhoodService.canopyReach` —
and `buildTrees` clamps each tree's jittered depth against that reach so a
canopy can never stand over a back fence, the same shape as the fence-height
audits elsewhere in this section: the guarantee is a clamp, not a row depth
that happens to be big enough today. *Orientation only — measured live, not a
`Config` value:* worst canopy clearance past a fence line is currently about
7.5 studs.

**Every tree now carries one invisible collider round its trunk**
(`Config.TREES`, designer, 2026-09-21: *"make the trees around the map real
impassable trees so players and the piggies have to walk around them"*) —
the canopy above it still collides with nothing. The collider is sized off
the generated trunk mesh's own bounding box rather than typed
(`Config.TREES.boleFraction`, 0.35 of the smaller footprint axis, because
that box also carries the root flare and the main limbs and would otherwise
be a wall as wide as a car), sunk `Config.TREES.sink` below the grass so its
base can never stand proud as a lip, and its column runs up into the canopy
rather than stopping at the leaves' underside — a barrier topping out where
the canopy begins is a step a player can jump onto and then walk off the top
of, so it climbs to the higher of the canopy underside and
`Config.jumpReach() + Config.TREES.jumpMargin`, the same reach test
`auditFences`/`isHoppableFence` use.

**The grass band behind the plot rows is where the PvE piggy herds live**
(§12, `HerdService`). `Shared/Grassland` delegates its installed environment
to `MeadowBuilder`, which clones the low-poly `ServerStorage/MeadowTemplates`:
varied rocks, flowers, bushes, ferns, mushrooms, reeds, lilies and fallen logs.
`MeadowPlan.settings` controls the two large water clearings and waterfall
width. `NeighborhoodService.buildTrees` reserves those clearings before it
plants the grove, using canopy reach rather than just trunk positions.

**The ponds and waterfall contain actual Terrain water.** `MeadowWater`
replaces the ground slab with adjoining sections around the basins and writes
only their saved voxel regions. Reset restores those regions without clearing
unrelated terrain. A broad waterfall feeds the larger basin through a short
outlet; scrolling beams and splash particles add flow over its water volume.
`MeadowShore` bridges the ground openings to irregular banks with imported
meshes. Those visual banks do not collide: merged dry-bank supports leave the
water accessible without a convex mesh hull sealing the pond.

`Grassland.blocks` vetoes pond rims for herd movement and delegates rock, log
and outlet footprints to `MeadowBuilder.blocks`. Flowers and shrubs remain
noncolliding. `Config.GRASSLAND` still owns scatter seeds, the part budget and
herd margins. Its older procedural ponds are retained only as a fallback when
the mesh kit cannot load; their scan-based layout does not describe the normal
installed map.

**A pack is released from the sky now, not walked in through the tunnels
(designer, 2026-09-22).** The fiction: the street is a simulation and the
players are the subjects being watched, so a herd is *released into the
enclosure from above* rather than let in at the gate. A herd's life is three
states — `"drop"` → `"roam"` → `"recall"` — and the fall runs backwards for
the exit. `Config.HERDS.drop` names the descent: `height` (well clear of the
tallest house in the catalogue, so the pack is seen against the sky rather
than through a canopy), `seconds` (deliberately *slower* than real gravity —
a batch *lowered* into the enclosure, not dropped through a hole, with time
for anyone who caught the splash to turn round and watch), `stagger` (spreads
the ten landings so they don't touch down in lockstep), `bounce`/
`bounceSeconds` (the settle hop on arrival), `beaconSeconds`/`beaconFade`/
`beaconWidth` (a neon shaft standing on the landing spot from the moment the
batch is released — the always-on-top **DROP ZONE / BATCH N** card that used
to stand beside it is retired), `puffSeconds`/`puffRadius` (the landing dust),
and `tries` (how many landing zones are tested — *every member's own slot*
against the band and the ground vetoes — before a drop is refused out loud
rather than landing a pack half in a pond). Every player is told where over
`Remotes.HerdDrop`, which `Shared/DropBanner` renders as a full-screen splash
rather than a toast — see below. A member is **lassoable the instant it lands
and not a frame before** — it is stamped `Config.LASSO_TARGET_ATTRIBUTE` on
the thump, which is what a client's lock-on reads (§3), because a target
still 120 studs up is a target nobody can throw at. `Config.herdRoute`, the walk-in leg
machinery, the alternating tunnel bores, the single-file kerb formation they
needed, and the tunnel-bore-clearance check `Config.auditHerds` used to run
against that route are all retired with the walk — a pack now has one shape
(three abreast) used at the drop as well as on the roam, rather than a second
route kept in step with the first.

**The drop is announced by a splash, not a toast (designer, 2026-09-23).**
`Shared/DropBanner` reads `Remotes.HerdDrop` and pops **PIGGIES INCOMING!**
over the top-centre HUD column, in the game's own display face at
`Config.HERD_BANNER.textSize`, gold with a thick ink stroke, tilted, on its
own ScreenGui above the rest of the HUD. A second line sits under the
headline — `Config.HERD_BANNER.subtitle` — reading where to go in words
("look in the woods behind the backyards") and never naming a plot number,
even though `HerdDrop`'s own payload still carries the landing zone as a
string; the caption is smaller and in paper rather than gold, at the same
tilt, so it reads as the headline's caption rather than a second headline.
Both lines shake: a per-frame random jolt of position and rotation, sized in
pixels and degrees, under an envelope that decays from the moment the pop
lands (`Config.HERD_BANNER.shake`) — it moves only position and rotation,
never colour or transparency, so it stays clear of the three-flashes-a-second
ceiling this project holds every effect to. It pops in with a Back ease and
holds at `Config.HERD_BANNER.hold` seconds (10, raised from 3 on the
designer's call so a player who was mid-robbery when it landed can look up
and still catch it) before fading. The neon shaft from the entry above is the
half that says *where*; this is the half that says *what happened*.

**A herd is one piggy now, not ten (designer, 2026-09-23).** `Config.HERDS.size`
is pinned to a band of 1..1 and `HERDS.maxLoose` is **20** — the drop, roam and
recall machinery above is otherwise unchanged, and still rolls whatever pack
size a band names, which is what keeps the pack-shaped dig contract under
test. A caught member is replaced **one for one**, due `HERDS.replaceDelay`
after the catch and then paced by `HERDS.spawnEverySeconds`. Two landings
never stack: `HERDS.drop.separation` refuses any landing point within that
many studs of a piggy already loose (`HerdService.separated`). An **empty**
field — the boot, or every piggy caught at once — fills in a **wave**, one
landing per `HERDS.drop.waveGap` under a single drop-banner splash for the lot
(`HerdService.tick`); every spawn the scheduler makes on its own afterwards is
**quiet** — no splash, and a short `HERDS.drop.quietBeaconSeconds` marker
rather than the full `beaconSeconds` (`HerdService.spawn(kindKey, quiet)`).
And a member that has neither walked nor turned since the last tick is no
longer re-seated every frame (`member.stood`). *Orientation only — measured
live, not a `Config` value:* fifty roaming pack members were 400 of the 900
parts the server moved every frame, on a client running at eight frames a
second; twenty singles are about a third of that.

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

**`Config.GROUND_SIZE` and the grove came in together.** The grove's own
three rows (`NeighborhoodService.GROVE_ROWS`) tightened when the slab did —
only the front row, which shuts the sightline behind a plot, is pinned to the
canopy's own reach; the two rows behind it are depth of wood rather than a
sightline, so they were the cheap half of narrowing the valley.

### The horizon beyond the valley wall

**The installed world border is a connected low-poly mesh surface.**
`NeighborhoodService.buildHills` calls `MeadowBuilder.buildBorder` before its
legacy geometry. The imported chunks share exact perimeter vertices through
the corners, replacing independently overlapping caps and slabs.

The view progresses from a faceted stone cliff to broad grassy shoulders and
distant rolling ridges. `MeadowBoundary` contains the same inner boundary used
by the asset generator. Hidden wall colliders follow those spans and leave
the road apertures open. Tunnel floors, liners, roofs and black back walls
preserve the police-car entrances at `Config.streetMetrics()`' tunnel mouths.
The outer slopes and ridges are visual scenery.

`MeadowAssets` clones checked-in MeshParts; it does not upload or load models
over the network at startup. `blender/environment/build_meadows.py` and
`build_shores.py` produce the source meshes, while `tools/finalize_meadows.py`
verifies imported bounds and writes the Rojo templates and shared layout.
The build package records source hashes and Roblox asset receipts. Border
placement scales with the tunnel positions and `Config.GROUND_SIZE`.

The former tunnel mounds, valley columns and four-ring horizon remain in
`NeighborhoodService` only as the missing-kit fallback. They are not built
alongside the installed border.

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
- **That measurement runs at every boot now, not once by hand.**
  `PlotService.auditYard()` builds every `Config.HOUSE_TIERS` entry at
  startup — pcalled, because a measurement must never stop the server
  starting — applies the identical per-part, skip-`HouseFX` rule, and prints
  the deepest and widest tier plus the tightest back-fence and side-fence gap;
  it warns (never throws) if either gap goes negative. `HOUSE_FRONT_LINE` and
  `YARD_DEPTH` (above) are sized off whatever this audit currently finds
  deepest, which is the whole argument for having it rather than a number
  typed once and never revisited.
- **The road is a fixed width, never derived.** `Config.streetMetrics()` is the
  single source; multiple files need the tunnel mouths. `Config.ROAD_SURFACE_Y`
  — the tarmac's own height above the world ground, 0.06 proud so the two never
  z-fight — is shared the same way: it lived as a private local inside
  `PoliceService` until a second vehicle needed the identical number.
- **Meadow basins are openings in the ground with Terrain water underneath.**
  `MeadowWater` partitions the slab around them; it does not use runtime CSG.
  Plot moats retain their separate raised-edge construction, and tunnel backs
  remain black slabs.
- **The world boundary, tree trunks, meadow rocks, logs and dry banks collide.**
  Decorative flowers, shrubs and distant border slopes do not. Herd movement
  uses the matching tree and grassland footprint vetoes.
- **Wheelie bins are public street furniture**, three a side, owned by nobody.
  Hiding is a *place*, not a costume. A bin buys a breath, never an escape.
  **A hider leaves three ways, and none of them is a prompt** — a `CLIMB OUT`
  `ProximityPrompt` was tried and could never fire: `ClientMain` switches
  `ProximityPromptService` off for anybody hidden, so the one prompt built
  for the hider was the one prompt the hider could never see. `jump`
  (`UserInputService.JumpRequest`, which fires alike for Space, the
  on-screen touch jump button and gamepad A — hiding never touches
  `JumpHeight`, so the button stays on screen), a tap on the on-screen hint
  card (`Shared/BinExitHint`, visible only while hidden, reading JUMP TO
  CLIMB OUT), or a push in any direction that **started after the lid shut**
  — a movement key still held from diving in does not count, or the key
  under a player's own thumb would throw them straight back out, the bug
  that retired a bare direction-exit once already. All three arrive at the
  server as one `BinClimbOut` remote carrying at most a direction — never a
  position — which the server flattens, validates and falls back from to
  the direction the player went in on. All three wait out
  `Config.BINS.settleSeconds`; a press during it is **queued rather than
  dropped**. All three earn the exit's speed burst; being tipped out by
  somebody holding `OPEN`, or reaching the two-minute ceiling, earns none.
- **Every plot carries its own mailbox, and it is the ONLY way to the daily
  board.** The board used to open itself, 1.5 seconds after joining, and
  closing it without claiming lost the day silently — a reward still sitting
  there with nothing on screen to say so. **The auto-open is gone.**
  `PlotService.setMail`/`.setMailOwner` raise a foot-hinged flag and enable
  the `post` prompt (§14) together, on the same push (`DailyService.push`)
  that fills the board itself, so the flag and the board can never disagree
  about whether today's claim is waiting. Pressing the prompt fires
  `DailyOpen` — it carries nothing, since the client already holds the whole
  snapshot and the click only ever means "look at it". `Shared/MailCall.luau`
  builds the advert: a client-side **DAILY REWARD** billboard and a gold
  sparkle plume over the reader's *own* mailbox only, driven off the same two
  facts (`Enabled`, `Config.PROMPT_OWNER_ATTRIBUTE`) rather than a third
  piece of invented state — built server-side, the identical sign and plume
  would hang over every mailbox on the street for everybody, nine of them
  over post nobody present can open. `Config.PROMPT_OWNER_ATTRIBUTE` is also
  what lets every other client refuse somebody else's mailbox on its own
  screen; the server re-checks the owner on the trigger regardless.
  `DailyService.onPlayerReady` fires one **good**-toned notify on join,
  naming the mailbox, when a reward is waiting — the one thing that still
  happens automatically, and it points rather than opens.
- **A delivery van drives the street on its own schedule and confers
  nothing.** `TrafficService` runs one van at a time, west to east through
  both tunnels at `Config.DELIVERY.speed`, in the lane opposite the patrol's
  own (`Config.DELIVERY.lane`, derived by negating `Config.POLICE.lane` so
  the two can never drift onto one line), every `Config.DELIVERY.gapMin`–
  `gapMax` seconds, standing down while `PoliceService.isOut()` — a siren is
  the loudest thing this street does, and two vehicles sharing a lane pass
  through each other rather than colliding. Built from `Shared/VanModel.luau`
  on the same conventions as the patrol car; every part is
  `CanCollide`/`CanQuery`/`CanTouch` false, so nothing about it can be
  reached, aimed at, hidden behind or blocked by. It is the world's own,
  deliberately unwired explanation for the mailbox on every lawn and the
  doorstep crate above (§3) — painted in the mailbox's own red and cream —
  never a mechanism either one depends on.

---

## 12. Services

| Service | Owns |
|---|---|
| `DataService` | Session-locked DataStore persistence, the schema, reconcile |
| `WorldService` | Ground, lighting, `ClockTime` — fixed at 14.5 (there is no night in this game). `setNight`/`restoreDay` (Midnight Heist's dusk) retired with the event (§8) |
| `NeighborhoodService` | Road, tunnels, verge, shopfronts, trees, street furniture, bins, and the connected world border (`MeadowBuilder.buildBorder`, §11; `buildHorizon` is the missing-kit fallback); builds the trunk collider round every tree it places (`Config.TREES`, §11) |
| `SceneryTrees` | The generated tree meshes themselves (trunk, canopy, seeded variation) — required by `NeighborhoodService`, which places them and derives their collider from the built mesh |
| `PlotService` | Plot pool, fences, ladders, driveways, ownership, signs, the mailbox (`setMail`/`setMailOwner`/`onMailCheck`, §11), the doorstep crate box (`setCrate`/`setCrateOwner`/`onCrateOpen`, §3), the rebirth firework attributes (`fireFireworks`, §4), and the four un-claimable shop-vault plots (`Config.SHOPS`, built on the same frame `ShopFront` builds its walls in) — publishes `onClaim`/`onRelease` hooks; forwards the dog's coat, kennel skin and filtered name to `GuardDog` (`setDogCoat`/`setDogKennel`/`setDogName`, §9); holds each plot's trophy state and rebuilds the (empty) lawn shelf from it — nothing else draws it, `TrophyRoom` having retired the day after it shipped (`setTrophyState`, §9); holds what a plot's owner has planted and puts it up (`setGarden`/`refreshBorder`/`refreshWindowBoxes`, §9), and records a plot's own equipped skin (`applySkin`, `plot.skinKey`) so a topiary knows what to render; the sign's NEMESIS line (`setNemesis`, §3) |
| `InteriorService` | The front door: walking into a house's swept doorway teleports you into its `Shared/HouseInterior` hallway — a fixed room built off the map entirely (`Config.INDOOR`/`HOUSE_DOOR`) — and walking out puts you back on your own lawn. The crossing is a server-polled swept segment against the doorway plane, never a `ProximityPrompt` (which would read as opening a door rather than walking through one) or `Touched` (unreliable against a `PivotTo`-driven mover); `Config.crossedDoorway` is the plain-arithmetic decision. The server owns the teleport; the client only draws the cover. Room count grows with rebirths (`Config.indoorPlots`/`.indoorRooms`, a separate axis from a house's own cosmetic tier). A built hallway nobody is inside is *parked* in `ServerStorage.ParkedInteriors` rather than left standing in `workspace.Interiors` — `ServerStorage` does not replicate, so an unvisited interior costs every client nothing. `goInside` moves it back into `workspace.Interiors` before the mask lead so the client has a head start to receive it, and the last player out of a room — through the door, or by leaving the server — parks it again. Which hallway gets built is decided per house tier: `Services/ThemedInterior`'s authored kit for anything `Config.HOUSE_INTERIOR_KITS` names and can resolve, this module's generic hall otherwise — both hand back one `Refs` shape, cached per plot against the owner, the builder *and* the kit name, since all three authored kits resolve to one `ThemedInterior` table (§9). Every room a hallway opens also stands a placement on each of its plots (`syncPlacements`, `Shared/IndoorPedestal`) through the same pad, sign and four prompts a lawn plinth uses (`PiggyPedestal.buildPrompts`/`.buildFigure`/`.wirePad`, shared, §3, §4) — `syncPlacements` dresses those placements from the owner's save the moment they are built, rather than waiting for a prompt (`PlotService.setPiggySlots`/`.setPiggyBuffers`, the same two painters that dress the lawn) — and the client's own `Shared/IndoorZoom` clamps the camera's zoom distance while the character stands on the indoor estate so it cannot be wheeled up through a non-colliding roof (`Config.INDOOR_CAMERA`) |
| `ThemedInterior` | The authored per-house interiors under `assets/houses/interiors/` — one wrapper over three art packages (Treehouse, Cardboard Fort, Beehive Cottage), each built behind the same `HouseInterior.Refs` contract the generic hall uses. Resolves a kit by name out of `ServerStorage`, mapped from a house tier's `id` through `Config.HOUSE_INTERIOR_KITS`; repairs the `PrimaryPart` every kit template loses in a Rojo sync (`repairTemplates`) and falls back to the generic hall, per kit, on anything that will not resolve or assemble |
| `ResidentService` | The NPC neighbour seated on every plot nobody owns — a name, a seeded pig whose size tracks the server's average level plus a fixed, per-resident downward offset (§5), and defences/garden rolled once from a second, independent per-resident *style* level instead (`pickStyle`/`applyStyle`, §5), so a house's look no longer moves in lockstep with the street the way its pig still does. A resident's pig is still bounded (`ResidentService.getCapacity`, `pigSeconds` of its own income) even though a player's is not (§4), because it is the non-player robbery supply. A neighbour's own lawn pedestals now accrue and a `"collecting"` state banks the ripest one; each trip out also chooses `"crack"` or `"snatch"`, weighted toward robbing a player over another resident (`Config.RESIDENTS.snatch`/`.collect`, §3) — the snatch itself runs through `PiggyHaulService.residentSnatch`/`.residentReturn`, registered in by `Main` (`.registerSnatch`/`.registerPiggyReturn`) so this file never has to require `PiggyHaulService` back. Also seats a permanent shopkeeper on each shop plot, laddering only its Vault Lock, and gives that shopkeeper the shop's guard-dog reaction — `alertShopkeeper` wakes and chases on a fumbled crack slice, `registerCatch` is a registry `Main` fills with `HeistService.shopkeeperCatch` (§5) |
| `HerdService` | Roaming PvE piggy supply: up to twenty single piggies (`Config.HERDS.maxLoose`, replaced one for one) are released from the sky into a grass band behind the plot rows (`drop` → `roam` → `recall`, `Config.HERDS.drop`, §11) rather than walked in through the tunnels, then wander, graze and occasionally dig (visual only), steered off the street, fences and ponds by the same veto `Config.isOnStreet`/`yardContaining` uses. A member is stamped `Config.LASSO_TARGET_ATTRIBUTE` the instant it lands, which is all `LassoService` needs to name and lock it, and the file owns the animal's half of a catch — the one-rope-at-a-time lock (`setBusy`), the flee after a miss, the dazed state a knocked-loose catch lands in (`spawnDazed`), and the hand-over when it is caught (`grantAt`, the pedestal-placement door a crate roll also uses, §3) — while ownership still refuses out loud against a full lawn. A member stands at the same size its skin does on a pedestal (`Config.PIGGY_PEDESTAL.display * Config.piggyScale`, §3), with a two-row name-and-rate label floating over its own head (`buildRatePreview`, sized off `Config.PIGGY_NAME` — the same billboard shape `PiggyPedestal.dress`/`.setRate` build) — the skin's own name in its rarity colour (`Config.piggyTierColour`) over what it would earn on a pedestal at level 0/rebirth 0 (`Config.getPiggyIncomeRate`) — a herd member has no owner to level, rebirth or boost, so that base figure is the whole of what the rate row can say. Every skin draw excludes anything carrying an `aura`, same as a resident's coin pig (§9, §17) |
| `LassoService` | Catching a wild piggy (§3, §6): the throw, the flight, the struggle and its tap count, the roll against `Config.lassoChance`, per-(thrower, piggy) pity, spending and buying a lasso, the stock push, and starter stock (`data.lassoStarter`, §13). Wires `PiggyHaulService`'s third haul kind, `wild`, in at `start` (`.registerWild`) and registers with `ProductService.onLassoReceipt` for the Elite tier's pack purchases, behind the same `PolicyService` gate a crate uses (§15) |
| `PiggyBank` | The piggy model, coin pile, skins — including dressing/undressing a legendary's whole-model overlay on every skin change (`applySkin` → `LegendaryModel.dress`/`.undress`, §9) — effects, the season finish over a skin (`applyFinish`, §3), vault dial, and the shop strongroom (`buildVault`, wrapping the same `Refs` a piggy bank returns, §5) |
| `GuardVisual` | The imported mesh guard models, rebuilt from their authored bone assignments; required by `GuardDog` |
| `GuardDog` | Patrol, kennel, guard duty, the off-duty nap, and the awake/asleep posture that tells a thief whether the owner is home; a **leashed, cone-catch chase** (`Config.DOG_CHASE`) and `knockOutOfYard`'s landing point for a catch made inside the yard (§5). Exposes `isOwnerHome`/`bark` so `HeistService` can drive the alarm-only branch without `GuardDog` knowing anything about players (§5). Every plot's dog is now the fixed `Config.DOG_LEVEL` tier — `Config.UPGRADES.dog` is retired — and a coat's `guardModel` can render any breed's rig over it (§9). `setGate` (written by `PlotService.buildFence`) makes the dog's own front fence a real wall to it: an ordinary patrol and a chase both route through the gate opening and never the sides or back, and a catch is only judged on the same side of the fence (§5). Also owns the dog's wardrobe — coat, kennel skin and its (pre-filtered) name — repainted through the one function, `applyTier` (§9); `kennelScale`/`sleepCFrame` seat the dog on its own kennel floor, nose at the doorway; `clampToYard` holds every patrol/sleep destination inside the fence, and a chase inside the looser driveway-extended box (§11) |
| `BoneService` | Thrown bones |
| `EconomyService` | Accrual loop, milestones, the `StateUpdate` push (fires whenever the whole-coin balance changes) |
| `UpgradeService` | Both upgrade trees |
| `HeistService` | The crack (§5, the smash it once shared a pig with is retired), carrying, nabbing (including which catch effect fires and on whom, §9), delivering, the loss cap, coin revenge and per-owner timed skin recovery claims/private recovery objectives, the dodge, tiptoe (`tiptoeInEffect`, the local shared by `currentSpeed` and the `Config.SNEAK_ATTRIBUTE` publish in `refreshSpeed`, §5), and the lawn watch (`watchLawns`) that wakes a guard dog on footsteps or a missed slice — against a `Target` of a player **or** a resident, but only ever **releases** the dog (chase, or the owner-home alarm) for a loudest trespasser who is actually robbing (carrying loot or mid-crack); a loud non-robber gets a rate-limited **bark** and nothing more (§5). `releaseDog` is where a wake decides alarm-only (owner home) versus a chase (owner away); `markIntruder`, a `HeistService`-local, marks the alarmed thief with a Highlight — see §5. A delivered robbery, a nab and a dog's catch each report to `TrophyService` (§9) — a clean crack delivered calls `recordClean`, a new robber rank `recheck`; a delivery against a player also goes to `SeasonService.recordNemesis` (§3), and a player's nab win, a dog's catch for its owner and a hot skin brought home by its owner to `SocialService.recordDefend` (§14); a completed shop-vault crack also rolls its item drop (`Config.SHOP_VAULT_DROP`, §5) — a duplicate off an owned pool pays coins instead of nothing — pushed to the hot bar through `registerStockPusher` — filled by `Main` with `BoneService.push`/`GadgetService.push`; `shopkeeperCatch` (§5) runs the same `nab`/`scare` a real dog's catch does, with an optional `catcher` name so the toast can say "The shopkeeper" instead |
| `PiggyHaulService` | Lifting a piggy off a lawn pedestal and carrying it home — take (your own), snatch (somebody else's), a lassoed catch (`wild`, registered in by `LassoService.start`, §3) and place (put one down), plus the dwell that turns a snatch or a catch into a possession (§3). Registers three questions with `HeistService` (`registerPiggyHaul`) rather than requiring it back, since `PiggyHaulService` requires `HeistService`: `haulingAnything`, so the carry speed penalty, the ride refusal, the disguise break and the dog's hearing treat a piggy exactly as they treat coins (§5); `nab`, the seam every catcher in the game already comes through; `confiscate`, the patrol's, which charges no bail for it (§7). Anything that is not a secured snatch — a nab, a dog, an arrest, a death, a disconnect — sends a *snatched* piggy home to its origin slot; the identical endings drop a *lassoed* one dazed instead, since a wild catch never had one (`.knockWild`, wired to `GadgetService.registerZapKnock` by `Main`, §3). `SocialService.recordSteal` fires only on the secure, which is also where `data.piggiesStolen` counts up for the lobby board (§14). `.residentSnatch`/`.residentReturn` run a neighbour's own trip through the identical placement rules (§5) |
| `TrophyService` | Counts what has been earned (`data.trophies`) and rebuilds the retired lawn shelf from it (a no-op, `Config.TROPHIES` is empty) — its indoor replacement, `TrophyRoom`, retired the day after it shipped and nothing has drawn the counters since (§9, §17); `recordClean`/`recordWanted` and `recheck` for counts other services own (§9). **A leaf** — requires only `DataService` and `PlotService` — and pushes the shop's repaint through a registry (`registerPusher`) `Main` fills with `CosmeticsService.push` |
| `CosmeticsService` | Buying and equipping everything cosmetic, including catch effects (§9); the dog's coats and kennels, and `nameDog` — the only caller of Roblox's text-filter API anywhere in this game (§9); the garden's three catalogues through one function, `buyGarden` (§9); `grantPassItems`, the one path every Robux pass grants through, hooked to `PassService.Granted` (§15). The accessory roll it used to run is retired (§9) |
| `ProgressionService` | Rebirth reset, a free crate on every rebirth — the rare rung, or the legendary one every `Config.REBIRTH_LEGENDARY_EVERY`th, chosen through `ChestService.pickOpenable` with the legendary shelf as the fallback and a "collection complete" toast once nothing will open (§4) — immediate save |
| `SeasonService` | The season **clock** and the **nemesis ledger** only (§3) — the season *ladder* that used to live here (tiers, rewards, the board's third page) retired with the Acorn currency. Lazy rollover of `data.nemesis`, `recordNemesis`/`nemesisOf`, `refreshSign` (the plot sign's NEMESIS line), and a server-local dev clock shift (`shiftWeeks`) that the buy-back claims and hot-skin window also key off. Requires `DataService`, `PlotService` |
| `SocialService` | Friend bonus, the one street board and the two pages it turns (Top Thieves, Top Defenders — `recordDefend` and a weekly `Config.WEEKLY_DEFEND` store — the season page retired with `SeasonService`'s ladder, §14), Most Wanted board (handing it over calls `TrophyService.recordWanted`), revenge markers, the per-player rap sheet push (`pushWanted`, remote `WantedState`, §14), and the wanted stars — consecutive-delivery payout and pursuit-target state (`recordSteal`/`clearStars`/`starsOf`/`getRun`, `Config.WANTED_STARS`, replacing the retired `spree` on 2026-09-22; the pursuit *floor* it once scaled retired the same day, §7), kept in a table separate from the rap sheet on purpose (§5, §7) |
| `PoliceService` | Patrol schedule, pursuit, arrest, the radio |
| `LobbyBoardService` | The street leaderboard (§14) — everybody in the server, ranked by lifetime `coins`, `piggiesStolen` (§3, §5) and `rebirths`, all three read live off `DataService` rather than a second copy. A different claim from both physical boards: the poster is one person right now, the landscape board is this week's ladder, this is the whole account's lifetime. `snapshot` is pure (sorted, ties broken by piggies robbed then rebirths then name) so the suite can hold it with no `Players` service; pushed on `Config.LEADERBOARD_REFRESH` plus once on join and once on leave, broadcast rather than per-player since nothing in the payload is about the recipient. **A leaf** — requires only `DataService` |
| `TrafficService` | The delivery van — one at a time, west to east through both tunnels, standing down while `PoliceService.isOut()` (§11). Confers nothing and carries no gameplay hook |
| `EventService` | The event roster |
| `SetService` | Sets, the drop reel, ownership lookups shared with chests (`owns`, `inUse`, `grant`, `revoke`) — which also resolve the `finish`/`plinth`/`kennel`/`coat` ownership tables (`kennel`/`coat` are live, coin-bought catalogues; `finish`/`plinth` currently have nothing to grant them, §3, §9) |
| `ChestService` | Every crate open and the one pool rule under all of them: `grantFree` (the daily ladder, a rebirth, the admin console) and `openPaid` (a Robux receipt, never a remote); `poolOf`, which filters every pool to the player's unowned set so **no crate pays a duplicate**; `whyCannotOpen`, the one refusal every route asks; `pickOpenable`, which chooses among a list; `rollUp`, a consume-nothing tier climb with no caller today; coin skin buy-backs; combining per-item spares by tier; selling spares for coins. Requires `DataService` and `SetService`, and `ProductService` **lazily** — so it registers `openPaid` and starts that file itself rather than leaving a line in `Main` load-bearing for a purchase working (§3) |
| `ProductService` | The one `MarketplaceService.ProcessReceipt` callback in the server, the idempotent receipt ledger (`data.receipts`), and the `PolicyService` paid-random-item gate (`ArePaidRandomItemsRestricted`, memoised per session, **failing closed**). Maps a crate to its `robux` display price and its `productId`, warns at startup for every priced crate with no product, and hands a receipt to whatever registered `onCrateReceipt` — a registry rather than a require, so this is **a leaf**: `Config` and `DataService` and nothing else (§3, §15) |
| `CombineService` | The Piggy Press on the verge (§3): building the machine, wiring its prompt on the server at build time, and validating a `CombineRequest` against the real kind/shelf/tier lists before forwarding to `ChestService.combine`. Owns **no arithmetic** — `data.spares` has one writer. Requires `ChestService` under a pcall and checks the one function it uses by name, so a half-loaded `ChestService` is a machine that refuses out loud rather than an error inside a prompt handler |
| `DailyService` | The daily ladder and boosts; raises the mailbox flag on the same push that fills the board (`push`, §11), fires `DailyOpen` when the mailbox prompt is pressed, and notifies once on join when a reward is waiting (`onPlayerReady`); the **queue** of crates a claim owes until each is opened at the doorstep (`owedCrates`/`openCrate`, `data.daily.crates`, §3) |
| `RideService` | Mount gate, welds, tricks |
| `StealthService` | Bins, hiding, and the thief kit (Ladder, Raincoat) |
| `HeldItemService` | What is in a player's hand (**a leaf** — requires only `DataService`) |
| `GadgetService`, `HomeService` | The two remaining consumable catalogues |
| `PassService` | Game pass ownership, cached per session |
| `SettingsService` | The one thing a client may write |
| `AdminService` | Owner-only dev console (F2) |

**Cycles are broken with registries, not with requires.** `SetService.registerPusher`,
`HeldItemService`'s vetoes, `ChestService.registerBalancePusher`,
`HeistService.registerStockPusher` and `TrophyService.registerPusher` are all
filled in by `Main` (which also registers `CosmeticsService.push` as the
`SetService` pusher for the `finish`/`plinth`/`kennel`/`coat` grants), which keeps each service's dependency list at one line and makes a
cycle impossible rather than merely absent today. `ProductService.onCrateReceipt`
and `.onPolicy` are the same shape filled in from the other end —
`ChestService` registers with them and starts that file, rather than
`ProductService` requiring `ChestService` back, which is what keeps the
receipt handler a leaf. `PlotService.onClaim`/
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

**Schema 20** adds `data.dogs` — the guard dog's wardrobe (§9): which coats
and kennel skins are owned, which of each is equipped, and the
already-filtered name and when it was last set. It is a **new top-level
table**, so this is the bump that actually needed spending; `kennels`,
`kennel`, `name` and `namedAt` are all keys added inside that same table
since, and none of *those* needed a further bump — the generic
one-level-deep fill above already covers a table's own new keys.
`reconcile` prunes `owned` and `kennels` against their catalogues, and falls
the `equipped`/`kennel` fields back to `""` if they no longer resolve — the
same rule every retired-item prune in this file follows: ask the catalogue,
never a list of names. **Toys — `data.dogs.toys`, `Config.DOG_TOYS` — are
retired outright**, with no bump of their own: `reconcile` simply deletes the
`toys` key from every existing save, refunding nothing, because the game is
in beta.

**Schema 21** adds `data.catch` — catch effects (§9), the third kind of
cosmetic and the first that lands on somebody else. It is a **new top-level
table** rather than two more fields inside `cosmetics`, deliberately: that
table is what the *piggy* wears, and a catch effect fires on the person a nab
just caught, which is never the piggy's owner. Filing it under the piggy's
wardrobe would have been the first name in this save that stopped describing
what is actually in it.

**Schema 22** added `data.daily.crate` — a `Config.CHESTS` key naming the
chest the day-seven daily reward still owed this save, or `""` for nothing
owed. A new field inside an existing table, so `reconcile`'s generic
one-level-deep fill picked it up on every existing save with no migration
branch — the same free ride `week`, `loot`, `spares` and `dogs`' own later
keys took. **It is retired as of 2026-09-23**, see `data.daily.crates` below.

**Schema 23** adds `data.trophies` — the trophy shelf (§9). A **new top-level
table**: which piggy skins have been robbed (`victims`, a set), a defender's
catch count and best delivery streak (`caught`/`bestSpree`, both new numbers —
everything else a trophy reads, `totalStolen` and `gear.escapes`, already
existed), and the bought half (`plinths`/`plinth`, the same owned/worn pair
every other cosmetic keeps). `reconcile` prunes `victims` against
`Config.SKINS` and `plinths`/`plinth` against `Config.TROPHY_PLINTHS` — the
same catalogue-not-a-list-of-names rule below, applied before a lawn ever
tries to build a trophy for a skin that no longer exists.

**Schema 24** adds `data.garden` — the garden's three catalogues (§9): which
border plants, paths and window boxes are owned (`borders`/`paths`/`boxes`,
each an owned map) and which one of each is equipped
(`border`/`path`/`window`, each `""` for none). A **new top-level table**, so
the generic one-level-deep fill picks it up on every existing save with no
migration branch, the same free ride `week`, `loot`, `spares` and `dogs`
each took — a save written before the garden existed joins with a bare lawn,
which is exactly what it already had. `reconcile` prunes all three owned
maps against their catalogues and falls each equipped field back to `""` if
it no longer resolves, the same catalogue-not-a-list-of-names rule as the
dog's wardrobe and the trophy shelf, written once as a loop over the three
pairs rather than three copies of the same nine lines.

**Schema 25** preserves the former rebirth milestones as explicit
`cosmetics.owned` entries for Bronze, Gold Leaf and Diamond. `reconcile` captures
`data.schema` before filling defaults, grants each whose historical threshold
was reached, then stamps `Config.SCHEMA_VERSION`. This runs only for older
saves, so a later sale or theft is never undone by rejoining. The equipped
skin, coins and spares are preserved; `sinceLegendary` is removed.
The historical thresholds live only in the migration. `auditEconomy` reports
any surviving `unlockRebirths` field anywhere in Config.

**Schema 26** moves houses from a ladder to a shelf keyed by stable id.
`data.houses = { owned = { [id] = true }, shown = id }` replaces the old
`houseLevel`/`houseShown` pair (catalogue positions, which shifted whenever a
tier was inserted). `Config.HOUSE_LEGACY_ORDER` is the frozen nine-id list
(`shack` … `skycastle`) used **only** by this migration: `reconcile` reads a
pre-26 save's numeric `houseLevel`/`houseShown` through it once, grants
`owned` up to that position and sets `shown` to the id at `houseShown`, then
deletes both old fields — derive-only, it never grants a house nobody had
already bought. On every save, old and new alike, `reconcile` also prunes
`owned` against unknown ids, forces `owned.shack = true` (the free starter
tier every player owns), and rewrites `shown` through
`Config.getShownHouse` in case the worn id no longer resolves.

**Seasonal buy-back claims** add `claims: { [skinKey]: seasonIndex }` with an
empty default and generic reconciliation; no schema bump or currency grant.
Load-time validation removes expired, future, malformed and ineligible keys.
A current claim survives rejoin and remains stored while its skin is owned;
only currently unowned eligible skins are offered. This is distinct from the
session-local timed robber-recovery claims (§5).

**Phase 5 (no schema bump at the time; superseded by schema 29 below)** added
`nemesis` `{index, rows}` and `defend` `{index, count}` (§3, §14);
`trophies.clean`/`.wanted`/`.harvested` (§9); and `cosmetics.finish` plus
`cosmetics.ownedFinishes` (§3) — along with a `season` table that schema 29
has since deleted outright. `nemesis` rolls lazily on read against
`Config.seasonIndex`, `defend` against `Config.weekIndex` — no rollover job.
`reconcile` prunes `ownedFinishes` against `Config.FINISHES` and takes the
worn `finish` off (`""`) unless it is owned — both now dead code paths, since
nothing currently grants a finish (§3, §9, §17) — and restores `nemesis.rows`
if a save carries the wrong type. `trophies.harvested` is still filled in and
still exists on the save; nothing writes to it or reads it any more, since the
trophy it counted for (Good Harvest) retired with the lawn shelf (§9).

**Schema 29 deletes the Acorn track, not converts it.** `data.loot`, `.tree`,
`.treeAcorns`, `.groundAcorns`, `.acornsGrownAt`, `.acornsDroppedAt` and the
`.season` table are all set to `nil` — before the generic fill, so they are
consumed rather than left beside a freshly-defaulted field — with **no
payout**: the game is in beta, and a migration that pays out has to be
measured idempotent first or it is a money printer, which this deliberately
is not. `Config.SEASON`, `Config.seasonIndex` and `Config.seasonEndsAt`
survive this bump; only the `season` table on the *save* is gone, because
what it ranked no longer exists (§3).

**No schema bump** covers the skin restructuring (§3, §9): retiring five skins
and folding one chest into another needed no new field, only a wider prune.
`reconcile` drops any `data.cosmetics.owned`/`ownedEffects` key no longer in
`Config.SKINS`/`Config.EFFECTS`, falls `data.cosmetics.skin`/`.effect` back to
the default if the worn key no longer resolves, and drops any `data.spares`
entry whose `"kind:key"` catalogue no longer holds it — the same
catalogue-not-a-list-of-names rule as every prune above, run against
`Config.catalogueFor` rather than a hardcoded five-kind branch so a retired
ride or ornament is covered by the identical loop.

**No schema bump** also covers the till's own buffer retiring (§4,
2026-09-22): the till (slot 0) no longer buffers its income at all, so
`data.tillBuffer` has nothing left to hold. `DataService.reconcile` folds it
rather than drops it — unconditionally, before the generic fill: whatever a
save was still holding banks straight into `data.coins`, once, and the field
is deleted. `Config.SCHEMA_VERSION` does not move for it, the same rule the
skin-restructuring prune above follows. (The lawn-pedestal collection system
that introduced `tillBuffer` in the first place is not otherwise documented
in this section — see §17.)

**No schema bump** covers `data.piggiesStolen` (§14, 2026-09-22): a lifetime
count of secured snatches, incremented once by `PiggyHaulService.secureStep`
on every secure — never on the grab — and read by nothing else in the save.
A plain top-level number defaulting to 0, normalised defensively on load
(a non-numeric, `NaN` or negative value is reset to 0, matching whatever
`data.coins` and `data.rebirths` already do), the same free ride `sessions`
took: it needed no migration branch, only a default in the fresh-save table
and a floor-and-clamp in `reconcile`.

**No schema bump** covers `data.piggies.slots` widening to hold the hallway
as well as the lawn (§3, §12, 2026-09-23): the array's width is
`Config.PIGGY_SLOT_COUNT` now — `Config.PIGGY_LAWN_SLOT_COUNT` plus
`Config.indoorPlotCeiling()`, sized to the rebirth *ceiling* rather than to
whatever a save has unlocked today — instead of the lawn's six alone.
`Config.piggySlots` grows and trims to the wider bound, so an existing
save's lawn entries are untouched and the new indoor entries simply do not
exist until something is placed in one; the shape of a slot (`key`,
`buffer`) did not change, only how many of them the array may hold. This is
the first piece of `data.piggies`'s own schema history written down in this
section — see §17 for the rest of it, which still is not.

**No schema bump** covers `data.receipts` (§3, §15, 2026-09-23): the Robux
crate's idempotent receipt ledger, a **list** of `PurchaseId` strings capped
at `ProductService`'s own `RECEIPT_MEMORY`. It is created lazily by
`ProductService` — `DataService.save` writes the whole table and `reconcile`'s
generic fill only *adds* missing keys, so a field a service invents survives
a rejoin, the same free ride `data.claims` takes — and normalised
defensively in `reconcile` so a hand-edited or truncated save cannot crash a
receipt. **A list rather than a map keyed by purchase id**, because a map
grows for the life of an account and nothing would ever prune it; Roblox
re-delivers only receipts that never returned `PurchaseGranted`, so the
window this guards is a lost return or a disconnect mid-fulfilment.

**No schema bump** covers `data.daily.crates` (§3, 2026-09-23), the queue of
crates the daily ladder still owes this save, replacing the single
`data.daily.crate` of schema 22. `DailyService.owedCrates` creates it lazily
and folds the retired field in **on first read** rather than in a migration
branch: it empties the old field as it consumes it, so a second call finds
nothing to fold and the operation is idempotent by construction. `reconcile`
normalises the list, the same defensive pass `receipts` and `claims` get.
Day one and day seven both pay a crate, and a single field silently replaced
one with the other — which is the class of failure this project refuses above
every other, landing on the one ladder whose whole promise is that turning up
is paid.

**No schema bump** covers `data.lassoStarter` (§3, §6, 2026-09-23): a plain
boolean, false by default, that stops a new save being granted
`Config.LASSO.starter` stock more than once. `LassoService` sets it the first
time it grants the starter stock and the generic one-level-deep fill picks up
the new field on every existing save with no migration branch — the same
free ride `sessions` and `piggiesStolen` took.

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

- **The HUD.** The **coin readout** is `Shared/PiggyPanel`, mounted by
  `ClientMain` at the top right, and as of a 2026-09-21 designer call — the
  same one that removed the pig's ceiling (§4) — it is **one plate and one
  number**: a 176×56 paper card with a drawn coin icon and the balance,
  nothing else. `StateUpdate` drives only that figure. It used to also carry a
  skin medallion, an income-rate pill and a capacity bar with a FULL warning;
  all three are recorded, deleted rather than left dormant, and their reasons
  are kept in the source as the brief for whoever proposes bringing one back —
  the medallion cost the largest object on the HUD to repeat what the player
  already knows; the rate pill's job moved to `HUDWidgets.renderBoost` in the
  bottom-left stack when the boost pill was built; and the bar's FULL warning
  had nowhere left to point once a pig could no longer fill up — what says so
  now is a collect's own refusal, at the moment it actually costs the player
  something, rather than a standing readout. The card scales down
  (`PiggyPanel.COMPACT_SCALE`, 0.64) as one shape on short/narrow viewports
  rather than reflowing to a second layout, because there is no second line
  left to drop. The `Wanted` chip is hung directly under its drawn bottom edge
  so the two can never overlap on a resize, sharing this plate's width and
  right edge. Rebirth is a compact 146×44 button between the Roblox controls
  and the coin plate.
  The left side holds a column of static, transparent icons drawn by
  `Shared/MenuIcons.luau`: Options, Stuff, Shop and — as of 2026-09-22 —
  Trophy, which opens the street leaderboard (`Shared/LobbyBoard.luau`,
  below). `Shared/HUDLayout.bindMenu` sizes the rail by however many tiles are
  actually *visible*, floored at three, and re-fits whenever one is added or
  removed — a `UIListLayout` neither clips nor errors, so a rail sized for
  three would have drawn a fourth tile past its own edge with nothing to say
  so. `Shared/HUDLayout.luau` keeps this column above the joystick, with
  44–48 pixel icons on phones.
  Dodge, Ride and Sneak sit above Jump on the right in 52-pixel circular
  buttons. `Shared/ActionButtons.luau` draws static sneaker, wind and board
  illustrations; short captions and cooldown/state feedback remain. A riding
  trick shares Dodge's position. The ride picker opens toward the centre.
  Shop (`B`) and Stuff (`I`) retain
  their keyboard shortcuts; Stuff opens the standalone inventory below. The income
  purchase that used to sit above both is a row in the shop's
  Upgrades tab now. Bottom-left is four rows deep and the fifth control went
  *sideways* rather than up. `IgnoreGuiInset` is on, so y=0 is *under* the
  Roblox topbar.
- **The shop.** **One shelf per visit, and the shelf is chosen by the door you
  came through** (designer, 2026-09-23: *"lets stop letting players tab
  through the whole shop with the one ui button"*). `Shared/ShopRevamp` no
  longer carries a category **sidebar** — a live index of every shelf pinned
  down the left of whatever tab you were already on, which was the fastest
  way to tab through the lot. **There is no landing page at all any more**
  (designer, 2026-09-23: *"we don't need that original shop home page
  anymore"*): the six-card **map** of where every shop stood
  (`Config.shopLocation`) is deleted outright rather than left inert. Every
  way in now picks its own shelf — a street door or a hallway counter opens
  its own (below), and the HUD basket / `B` open **Robux** directly — so a
  page whose only job was pointing at a shelf has nothing left to route to.
  **The Robux shelf carries the real crate tiles**, not a banner to a second
  copy of them: the Piggy Crate, Rare Piggy Crate and Legendary Piggy Crate
  plus the Guardian Crate (`Config.CRATE_SECTIONS`) are mounted on the page
  by `Crates.mount` and painted by the crates shelf's own painter — one
  renderer shown in two places, so the odds bar, the price and every inert
  state can never disagree between them. Buying is one tap, on the tile's
  own price button; **`?`** opens the crates shelf itself, reset to that
  crate's contents page (`Crates.peek`). Coin buy-backs never show
  here — `Crates.setBuybacks` only turns them on once a counter opened the
  shelf (below), since a coin price is only ever met at a counter. The back
  arrow (`ShopBack`) shows only when the open shelf has somewhere real to go
  back to — today, only the crates reached *through* Robux, which point back
  at it (`Shell:setBack`); every other route shows the shop basket on the
  sign instead. A counter-opened panel also closes on its own once the
  player walks more than `SHOP.LEASH` studs from where they opened it (a
  death, a respawn or a door trip moves them further than that too), except
  while the Robux shelf is selected, which carries no leash — it opens from
  the HUD from anywhere. With the sidebar gone every shelf
  starts at the panel edge and is **174 pixels wider** on any window that
  used to carry one. Cards render the **real 3D item**. The tab rail behind
  all this is hidden by the shell and is a `ScrollingFrame` — a fixed one
  silently ate two whole tabs, because a `UIListLayout` does not clip and
  does not error — with each tab **sized to its own label**
  (`TextService:GetTextSize`). **Inventory is deliberately not a shop tab** — a shop tab
  is where you go to spend, and this is where you go to look at what you
  already own, so it is its own full-screen panel instead; see the Inventory
  bullet below. **The Piggy tab is gone**, and its two sections went with it:
  skins are bought nowhere in the shop any more (only opened out of a crate
  or equipped from the bag, above), and priced *effects* lost their only
  storefront — `Config.CHESTS` has no effects chest, so the five buyable
  auras (§9) are currently unreachable by any route, a known and deliberate
  gap rather than a bug. `Remotes.get("LootBuy")` is gone entirely — sets have
  no purchase route of any kind now (§8) — which leaves the alien
  set's `martian` skin and `hoverdisc` ride reachable only from the alien
  raid's drop, and the raid is off the schedule (§8); the Tractor Beam effect is not even in the set any more and
  currently has no route to a player at all (§17). The
  **Upgrades** tab is the one tab that changes an outcome, and it is a
  list-and-detail browser (`Shared/ShopUpgrades.luau`) rather than a grid:
  **two group tabs — Defend, Rob — and there is no Earn group any more**
  (designer, 2026-09-23). Earn used to hold one row, **Earn Faster**, raising
  what every piggy pays per second for coins; what raises that rate now is
  the **permanent coin multiplier**, bought with a rebirth (§4) — a
  coin-priced rung doing the same job was a second answer to one question, on
  the shelf a player reads first. Bigger Piggy Bank had already gone with the
  pig's ceiling (§4), so the group emptied to nothing and was retired rather
  than left holding one dead tile; every remaining row has a fixed `max` no
  rebirth lifts. **The server path is untouched and now unreachable from the
  client** — `PurchaseRequest("income")`, `Config.getIncomeCost` and
  `data.incomeLevel` all still exist, and `incomeLevel` is still a real
  multiplier inside `Config.collectionRate` — but nothing sends the purchase
  any more (§4, "The ladder").
  Each tab lists its upgrades as tiles, with the selected one opening a
  detail panel carrying a rendered 3D preview of the next rung, a scrolling
  NOW/NEXT stat comparison (`Shared/ShopUpgradeFacts.luau` — coins/second,
  crack-slice size, fence slow, carrying speed, and so on, read straight off
  the `Config` formula each tree already runs) and a buy strip. Defend and
  Rob use rendered vault, fence, lockpick,
  coin-sack, speed-boot and crouching-resident icons. Sneak uses the existing
  resident NPC, including the hair cutout, carrying the snout-emblem robbery
  bag. The shared figure now wears 32 alternating hollow chain links and a
  snout medallion with a connecting bail; every resident inherits this necklace.
  All six upgrades use the same PNG
  in cards and details, cropped to measured alpha bounds with 16px clearance.
  `Shared/UpgradePreview.luau` remains a fallback for future unregistered items.
  Selected cards have checkmarks and glowing borders. `ShopRevamp` uses the six rendered
  category icons, and `Theme.coin` uses the front-facing snout coin. Supplies
  uses the plunger, bubblegum bomb and golden bone PNGs; crate cards and their
  contents summary use distinct common/rare/legendary chest artwork. The source
  art and upload provenance live in `assets/shop-ui/icon-system-v1/`.
  Home's 18 house cards use transparent images rendered from their actual
  authored house models. `Shared/ShopHouseCards.luau` maps stable house IDs to
  artwork and paints the full card from `Config.RARITIES`; ownership and price
  states remain in the action pill. Sources, renders and upload records live in
  `assets/houses/<model-folder>/shop-cards/`, with the index in
  `assets/shop-ui/house-images/`. New houses without artwork retain a 3D fallback.
- **Guardians** replaces Companions. **Eight** static native-model renders
  (`ShopGuardianCards.images`, one per `Config.DOG_COATS` row — §9) use the
  same full rarity-colored card presentation as houses. PNGs and provenance
  live beside their original rigs in `assets/guards/<rig>/shop-cards/`;
  `assets/SHOP-RENDER-INDEX.md` links all house and guardian images to
  their source models and Roblox upload IDs (the index's acorn entries are
  archived artwork for a retired currency, §3; the five retired coats' ids
  stay recorded in `assets/shop-ui/guardian-images/roblox-uploads.json` for
  the same reason `ORPHANED-UPLOADS` is kept — the Assets API has no list
  endpoint). No guardian card has a live 3D viewport.
  **The pill names the ROUTE rather than always a price** (§9): a coin price
  for the two priced coats (Husky, Mastiff), nothing for free Scrappy, and
  **FROM CRATE** for the other five — because ClientMain's loop writes
  `format(info.cost)` before the card paints, and a crate coat has no cost, so
  without that overwrite five cards would read a gold `0` on the
  you-can-afford-this green and do
  nothing when pressed. That exact failure is on record from the ten
  drop-pool skins. It is one call site rather than a branch in the loop.
- **A gated item still SHOWS, behind a wash, and `ShopWidgets.gate` is the
  one treatment for all three shelves that have one.** Houses, rides and
  guardians all carry `unlockRebirths` (designer, 2026-09-23), and three
  shelves each deciding what "gated" looks like is three things that can
  disagree about which rebirth opens what. `W.gate` draws a translucent ink
  sheet with a padlock and **"Rebirth N required"** (`W.GATE_TEXT`, the
  designer's exact wording), and `W.gateRank` is the `LayoutOrder` — open
  items first, then gated ones by ascending gate, then the catalogue's own
  order inside a rung. An ungated row returns exactly `info.order`, so every
  shelf without a ladder lays out byte-identically to before.
  - **`locked` is the SERVER's verdict, not a comparison the card makes.**
    Both `CosmeticsService.push` and `RideService.push` send `locked` and
    `unlockRebirths`, so the wash and the refusal cannot disagree, and an
    **owned** item is never locked.
  - **The press is let through on purpose.** A locked card fires its request
    and the server names the rebirth — `buyHouse`, `RideService.buy` and
    `buyDogCoat` each check the gate **above** the price, so nothing is spent
    — because a control that does nothing when pressed reads as broken, and
    this closure cannot reach the notification stack. `Locked` is still
    written as an attribute for a probe to read; it simply no longer swallows
    the press.
  - **The price pill is raised ABOVE the wash**, and that is a measurement:
    gold on the pill's slate reads 4.61:1, and a 0.38 ink wash over it takes
    it under the 4.5 body floor. Raising the pill keeps "the price is still
    readable underneath" true at any wash strength. The sheet does not touch
    the card's background, so "ownership changes the action pill, never the
    item's tier colour" survives.
- Pets are paused (`Config.PETS_ENABLED = false`): no shop entries, purchases,
  equipped attribute or follower startup. Existing pet purchases remain saved.
  Kennel color purchases/equipping are retired; live kennels automatically take
  the guardian's body/dark palette and collar (or a creature's light accent).
  Legacy kennel purchases remain saved but inactive. This paragraph's own
  "Season tier 4" grant is stale in a second way now: the season ladder that
  granted anything at a tier is itself retired with the Acorn currency (§3),
  so nothing is granted at any tier any more.

  **No upgrade tree in the shop is rebirth-gated any more.** The NEEDS
  REBIRTH tile treatment — dropping the detail header's arrow, labelling the
  NOW/NEXT comparison REBIRTH instead of NEXT, turning the buy strip into
  REBIRTH TO UNLOCK MORE on `Theme.PRESTIGE` — was Earn Faster's own, keyed
  off `Config.rebirthOpensMore` (§4, "The ladder"); it went with the Earn
  group. Defend and Rob both had a fixed `max` no rebirth ever lifted, so
  they always read a flat MAX LEVEL and never touched that helper. The **Home**
  tab leads with **YOUR GUARD DOG** / **ITS KENNEL** — the
  guard dog's wardrobe (§9) — then **ALONG THE FENCE** / **THE PATH TO YOUR
  PIGGY** / **WINDOW BOXES** — the garden's three catalogues (§9) — above its
  own consumable sections (§6), because a coat, a kennel skin or a hedge is
  bought for the same lawn those items defend. An equipped garden card reads
  PLANTED, LAID or UP rather than a shared word, because each names what
  actually happened to the thing. The
  **Worn** tab is the thinnest tab in the shop and the one whose subject is
  already *you* rather than your piggy: **MOST WANTED** (player gear, §7),
  then **WHEN YOU NAB SOMEBODY** (catch effects, §9), then **SPECIAL OFFERS**
  (the Robux passes, §15) — one card per pass, skipping any that already has
  a better home (the Style Pack, sold on the Rides tab beside the stances it
  animates).
- **The dog name box.** The only place in the game a player types free text
  (top of the Home tab, beside the coat cards). Everything else here is a
  button over a fixed catalogue; this sends whatever was typed, on
  `FocusLost` with Enter rather than per keystroke — a filter call per
  character would be an unbounded rate against Roblox's own moderation API.
  The server, not the box, decides what is actually shown (§9).
- **Crates.** `Shared/Crates.luau` is the shop tab that reaches
  `ChestService`, laid out as **collections**: one section per
  `Config.CRATE_SECTIONS` row, each a row of large crate tiles. The full pool
  is one tap deeper — a tile opens `Shared/CrateContents`, which lists every
  item in the crate with the odds printed.
  - **The tile carries the price and therefore has to carry the odds.** A
    crate is bought with Robux, which makes it a paid random item, and that
    rule asks for real odds summing to 100% disclosed **before** purchase
    (§3, §15) — so the stacked bar is drawn to scale on the tile itself, from
    the server's own renormalised `ChestState` percentages, with the best
    tier's exact figure printed beside the crate's name and the `?` opening
    the full per-tier breakdown.
  - **Six button states, in this order, and five of them are inert.**
    `EARN THIS CRATE` (no `robux` at all — no live crate reaches this state
    since the Alien Cache was deleted; it is kept for the next earned crate,
    where naming where it comes from is the answer to the question a player
    opening this tab actually has); `COLLECTION COMPLETE` (`ChestState.complete`, the unowned
    pool empty); `NOT AVAILABLE HERE` (`ChestState.restricted` — the policy
    gate's verdict, **said** rather than silently dropping the button);
    `COMING SOON` (a price with `productId` 0, which is every crate today —
    prompting for 0 throws, so the button declines to ask rather than failing
    silently, the same wording a pass with no id gets); **the server's own
    refusal sentence, printed verbatim** (`ChestState.refusal` — a full lawn
    is the one a player meets, and printing rather than summarising is what
    stops the card and the toast disagreeing about why); and the live one,
    which fires `MarketplaceService:PromptProductPurchase`. The client holds
    `ui.productId` nil in every inert state, so the button cannot prompt for
    a crate it is not currently selling.
  - **There is no combine row.** It left for the Piggy Press (§3): a row of
    chips that can only light while somebody holds spares was permanently 0/3
    on a tab where no crate mints one, which is the control that does nothing
    when pressed.
  - **The reveal reuses `SpinWheel`**, the same reel the event drop already
    used, generalised with three optional fields (`title`, `subtitle`,
    `note`) rather than forking a second one — so a combine made at the
    machine plays the same reel as a crate opened here, and nothing draws a
    second one.
  - **Seasonal buy-back cards** sit beside the source crate, with the real
    lost skin preview and its **coin** price and shortfall (§3). Only current
    unowned claims are shown; `SkinBuyback` sends the key alone. Ownership
    changes refresh the cards through
    `CosmeticsService.registerCollectionPusher(ChestService.push)` and the
    policy answer landing re-pushes the same state; cards also disappear
    locally at the supplied `buybacksExpireAt` boundary. Buy-back has no
    crate reveal.
- **The Piggy Press panel.** `Shared/CombinePanel.luau`, opened by holding
  the machine's prompt on the verge (§3) and by nothing else — not a tab, not
  a rail tile, not a key, because it is about a **place**. Escape closes it;
  walking away does not, because the only thing at stake is a list the server
  re-checks anyway. It draws the server's own numbers and keeps none of its
  own: every spare, its tier, its sell value and whether it is in use arrive
  on `ChestState`, so this is a third handler on the push the Crates tab and
  the bag already read rather than a channel of its own. The reveal is
  `Crates`' — `ChestResult` is already connected unconditionally, and a second
  one drawn here would be two on one result. It publishes
  `CombinePanel.ATTRIBUTE` on the HUD `ScreenGui` so `ClientMain` can make it
  mutually exclusive with the menus in one line, the same job `BagOpen` does.
  Its own module, started in one statement holding no local, for the
  200-register ceiling.
- **Inventory — a standalone panel, not a shop tab.** `Shared/Inventory.luau`
  is the mirror of Crates and never shows a price — that is the property the
  module exists to protect. **Crates is how you *get* a cosmetic; Inventory is
  what you *have*.** It lived behind the shop's rail for about an hour and was
  moved out: a shop tab is where you go to spend, and this is where you go to
  look at what you already own, so it is its own full-screen panel (`I`, or
  the bag toggle beside SHOP) built to the shop panel's own geometry — same
  scale, corner and close button — and the two are **mutually exclusive**,
  opening one closes the other. It lists every **owned** item across the
  wearable/placeable catalogues (skins, effects, accessories, decor, rides,
  and a **Finishes** tab, sent only when owned, worn through
  `CosmeticRequest` kind `"finish"`, never sellable — currently always
  empty, since nothing grants a finish any more, §3, §9, §17),
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
- **Physical boards.** The street board and the Most Wanted poster are objects
  in the world, standing mid-verge (§11), not HUD panels — the physicality is
  the mechanic. `SurfaceGui` culls by distance from the **character**, not the
  camera. **The one street board turns two pages**, each for
  `Config.BOARD_PAGE_SECONDS`, publishing which is up as
  `Config.BOARD_PAGE_ATTRIBUTE` on the panel: **Top Thieves this week**
  (`Config.WEEKLY_HEIST`) and **Top Defenders this week** — thieves a player
  stopped (a nab win, their dog's catch, a hot skin they carried home;
  `SocialService.recordDefend`, counted in `data.defend` and published to a
  weekly `Config.WEEKLY_DEFEND` store on the same cadence as Top Thieves). A
  third page once ranked the season and retired with the Acorn currency (§3),
  along with `Shared/SeasonBoard.luau`, the client-side overlay that used to
  draw it; `Config.BOARD_PAGE_ATTRIBUTE` still publishes which of the two
  surviving pages is up, which is the only reason that plumbing still exists.
- **The street leaderboard is a third, toggled panel (`Shared/LobbyBoard.luau`,
  new 2026-09-22) — neither physical board and not a standing HUD readout.**
  It answers a third question the two boards don't: not *one person right
  now* (the poster) and not *this week's ladder* (the street board), but
  **lifetime, across servers** — everybody currently in this server ranked by
  `coins`, `piggiesStolen` and `rebirths`, pushed by `LobbyBoardService`
  (§12). 570×380, centred, opened from the Trophy tile in the left menu rail
  (above) or `Tab`/`L` and closed with `Escape`. It does **not** take the
  mutual-exclusion the shop and the bag keep — that rule exists because two
  panels the *same size* leave the loser's close button unreachable, and
  every menu in this game is bigger (`0.94` of the screen at `Theme.MENU_Z`)
  — so the relation is one-way: it closes itself the instant a menu opens
  (the bag's `BagOpen` attribute, the settings' `SettingsOpen`, the shop's own
  `DisplayOrder`) and refuses to open while one is already up, and draws one
  step below `Theme.MENU_Z` so the ordering is by number rather than by which
  frame happened to build later. `Tab` is accepted even when Roblox marks it
  processed (the default player list is off, so the key is free, but nobody
  here has measured whether it still arrives *unprocessed*) unless a
  `TextBox` has focus; `L` is the ordinary binding that needs no such
  reasoning. A module, started from `ClientMain` in one statement holding no
  local, the same shape as `RobBadge`, `Wanted` and `CarryPose`.
- **The rap sheet chip.** `Shared/Wanted.luau` is the second chip in the
  top-right column, directly under the standing event countdown chip (176×46
  at y 224, the same 8px gap the countdown leaves under the piggy bank panel)
  — the top-centre column is *alerts*, this corner is *standing readouts*. The
  chip stands 18px taller than a bare badge/caption/amount row for a **star
  row** underneath (§5, §7) — that first row already spends all 176 pixels, so
  the run gets a row of its own rather than competing for space in it.
  **Stars, not pips** (designer decision, 2026-09-22): a pip reads as "how far
  along", where the street's whole vocabulary for a wanted thief is stars.
  Five of them, each an eight-pointed star built from two squares — one
  square-on, one turned 45°, the same trick `Theme.gear` draws its teeth with,
  not a text glyph, since half the obvious dingbats render as a tofu box and
  the emoji forms ignore `TextColor3` — with the gold **fill draining out of
  the newest star first**, over `Config.WANTED_STARS.fade` a star at a time,
  rather than blinking one off outright, so a run visibly *runs out* instead
  of suddenly being one shorter. Pushed per player by `SocialService.pushWanted`
  (remote `WantedState`): on the board's own `Config.LEADERBOARD_REFRESH` tick,
  and immediately inside `recordSteal` (a delivery), `clearHeat` (an arrest
  clearing the sheet) and `clearStars` (any arrest ending a run, whether or
  not it clears the sheet). Payload is seven fields — `sheet`, `isLeader`,
  `hunted`, `stars`, `starsMax`, `starsAt`, `pinned` — nothing the chip has no
  reader for. `starsAt` is the server-time stamp the drain is measured from
  (`SocialService.starsOf` re-stamps it on every read, so the fade clock is
  genuinely *held* rather than merely long); `pinned` is the Most Wanted
  leader's own five, held full with no motion by `starsOf` until
  `refreshMostWanted` hands the title on — the run underneath keeps counting
  through `recordSteal` regardless, because the best-spree trophy is read off
  the **unpinned** count (`SocialService.getRun`, never `starsOf`), or a
  leader's first delivery would record a run of five nobody actually made.
  Hidden until the player's own sheet is above zero, then captions STOLEN /
  WANTED / HUNTED with the escalation carried entirely by the badge ring
  (muted → gold once the poster has your name → red once `hunted` arrives
  true) — the server decides `hunted` before it is pushed, and it is a pure
  stars test now (`run >= Config.WANTED_STARS.huntedFrom`), true for anybody
  carrying that many regardless of whether they lead the board at all (§7),
  and the chip has no business re-deriving that. `Wanted.fills`, the pure
  function the drain is drawn from, is held against `Config.starsAfterQuiet`
  by `tests/luau/wanted.luau`, which also drives the real `SocialService`
  against a clock it can advance and asserts the sheet, the stars and the
  board are all kept **per server** — cleared on `PlayerRemoving`, written to
  no save. Started from `ClientMain` in one statement holding no local, the
  same shape as
  `FirstJob` and `Crack`.
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
- **Skin tags.** `CappedUntil` and `HotSkinUntil` publish only server-owned
  public facts. A valid private recovery claim changes HOT SKIN to **RECOVER
  SKIN** for its owner. Refunds, reacquisition, disconnects and expiration
  clear the corresponding state; changing outfits does not. (There is no
  Acorn theft cooldown to show any more — the whole tree/basket/storage loop
  it protected is retired, §3.)
- **Onboarding and recovery objective.** `Shared/FirstJob.luau` shares one
  objective slot. Onboarding/buy-back use a 44-pixel card; a live recovery
  uses a compact 64×68 skin task icon, expandable to show details. The preview
  is built from the exact claim key, independent of the robber’s worn skin,
  and reused across timer ticks. With no recovery objective, onboarding says
  **GO AND ROB A PIGGY BANK** and highlights the nearest worthwhile pig.
  `Config.PLAYER_FIRST_JOB_ATTRIBUTE` still derives from `data.totalStolen`;
  the first delivery retires onboarding, but leaves recovery listening.
  A stolen skin shows **RECOVER SKIN**, the robber's name and "Nab them now"
  when expanded. The compact icon reads CHASE while in flight, then the
  actual countdown, with a highlight on the robber's
  pig after delivery. A recovered carry says **GET IT HOME** and points home;
  the carried copy remains deliverable after the timer ends. Expired or
  unavailable free recovery falls back to **BUY IT BACK — N COINS** only for
  a current unowned seasonal claim. **Tapping no longer opens Crates**
  (designer, 2026-09-23: a coin shelf's only door is a building now, and
  this card was one of three HUD side doors left open behind it) — it
  calls `SHOP.pointTo`, which raises a toast naming where the shelf
  actually stands (`Config.shopLocation`, the same sentence the shop's own
  landing page prints) rather than opening anything, with no purchase on
  the objective itself.
  Multiple claims prioritize a carried recovery, then an active chase, then
  the earliest recovery deadline before paid claims; `+N more` shows the
  remaining stack. Owned reacquisitions disappear; insured spares retain
  their free-recovery objective but have no paid fallback. The client listens
  before subscribing to `RecoveryObjective` and retries until a snapshot
  arrives. HeistService polls subscribed players every 0.25 seconds and sends
  only changes privately; repeated subscribe requests are throttled. Local
  wall-clock rendering flips at expiry without a packet. The card and marker
  hide beneath shop/bag overlays. Responsive bounds clear the bank column;
  long names truncate. Isolated state/layout checks pass, while live input,
  multiplayer latency and rendering remain unverified.
- **Music.** Cues play through once from a shuffled bag with 55–110 seconds of
  silence between them. **Nothing loops.** The toggle turns off *music only* —
  muting effects would hide the siren.
- **Performance: distance culling of particles and lights (2026-09-23).**
  `Shared/FxCull.luau`, started from `ClientMain` in one statement holding no
  local, switches every `ParticleEmitter` and `Light` in `workspace` off once
  the camera is beyond `Config.FX_CULL.emitterRange`/`.lightRange` of it,
  re-checked every `Config.FX_CULL.interval` seconds. It never disagrees with
  the server: each instance's *authored* `Enabled` value is tracked off its
  own changed signal (masked against this module's own writes), so a server
  toggle — a sleeping dog's puff switched off, an aura newly equipped — is
  honoured whether or not the camera happens to be in range that moment. A
  burst fired through `Emit()` plays at any range regardless (the landing
  dust, the catch sparkle, the rebirth fireworks), and anything carrying the
  `FxCullExempt` attribute is skipped outright. *Orientation only — measured
  live, not a `Config` value:* disabling the culled emitters and lights took
  the mean client frame from about 70 ms to 43 on a machine that could not
  draw ten frames a second. `GuardAnimator.client.luau` (§9) runs the same
  idea for the guard dogs it poses: beyond `Config.FX_CULL.guardRange` of the
  camera a dog's joints stop being lerped every frame at all, and its face
  colour/material are written only when they actually change rather than
  every frame regardless.
- **Performance: distance fading of grass tufts.** `Shared/TuftCull.luau`,
  started from `ClientMain` right after `FxCull` in one statement holding no
  local, fades every `MeshPart` named `Tuft` out past `Config.FX_CULL.
  tuftRange` of the camera, on *this client only*, ramping over
  `Config.FX_CULL.tuftFade` studs via `LocalTransparencyModifier` so a tuft
  comes up through the grass as the camera approaches rather than popping in.
  Re-checked every `Config.FX_CULL.interval` seconds. The server never sees
  it.

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

| kind | word | glyph | tone | style | where |
|---|---|---|---|---|---|
| `steal` | STEAL | 💰 | red | pill | anybody's piggy but your own — opens the crack (§5); the smash that once lived on this same body is retired |
| `sell` | SELL | 💰 | amber | pill | your own lawn pedestal, holding a piggy — the only way to free one for a crate to fill (§3) |
| `take` | TAKE | 🐷 | gold | pill | your own lawn pedestal, holding one of your own piggies (§3) |
| `snatch` | SNATCH | 🤚 | red | pill | anybody else's lawn pedestal, holding a piggy — refused on the owner's own screen (§3) |
| `place` | PLACE | 📍 | green | pill | your own empty lawn pedestal, while you're carrying a piggy — refuses a stolen one by name (§3) |
| `swap` | SWAP | 🐷 | green | pill | your own till (`PiggyBank`'s `Body`), owner-only, live only while you're carrying a piggy — `place`'s own tone, since it costs and risks nothing (§3) |
| `nab` | NAB | 🚨 | amber | card | a thief carrying loot — coins or a piggy off a snatched pedestal (§3, §5) |
| `hide` | HIDE | 🗑 | slate | card | a wheelie bin |
| `dig` | OPEN IT | 👀 | orange | card | a bin with somebody in it |
| `shop` | SHOP | 🛒 | green | card | the counter inside each of the four shops — no longer the door itself (§11) |
| `post` | CHECK POST | 📫 | gold | card | a plot's own mailbox, once the day's claim is waiting |
| `crate` | OPEN CRATE | 📦 | gold | card | the box on a plot's doorstep, once the daily ladder owes a crate (§3) |
| `combine` | COMBINE | 📦 | magenta | card | the Piggy Press out on the verge (§3) |
| `recover` | RECOVER | 👽 | alien green | card | a downed raid drone |

**The seven `pill` kinds carry no card** — every kind that lives on a piggy or
a lawn/till pedestal (`Config.PROMPTS[kind].plain = true`, designer,
2026-09-23: "remove the card when you walk up to any piggy … just the button
and action"). `Config.setPromptKind` leaves a plain kind on
`Enum.ProximityPromptStyle.Default` — Roblox's own key-and-action pill,
`ActionText`/`ObjectText` only, no glyph and no tone rendered — and every
`card` kind on `Custom`, drawn by `Shared/PromptUI` as below. The glyph and
tone columns above are `Config.PROMPTS`' own vocabulary; only the `card` rows
currently put them on screen.

**`Config.PROMPTS.collect` is a dead entry.** There is no collect/bank action
since the pivot — the pig is the wallet and nothing is banked (§4) — so
`EconomyService.collect`, the `CollectRequest` remote and the piggy's
`CollectPrompt` are all gone. The table row survives in Config, unread by
anything; `steal` is the only prompt left on a piggy's own body, enabled for
everybody but its owner.

**`nab` is never offered to the one player it would nab.** It is welded to a
carrying thief's own root so every *other* player can reach it, which also
puts the thief permanently at distance zero from their own prompt.
`PromptUI` disables the prompt on the thief's own client the instant loot is
welded to them, and `HeistService.nab` refuses a self-nab server-side
regardless — a forged self-nab would otherwise return the loot to the victim
and stun the thief for nothing.

- **Colour is never the only signal on a card** — every card carries the word
  and the glyph too, the same rule the rarity borders follow. A pill carries
  only the word.
- **Tones are borrowed from `Config.NOTIFY`**, so a card's action and the
  toast it produces are the same colour.
- **`Config.setPromptKind` sets the kind and switches the prompt's own
  `Style` in one call — `Custom` for a card kind, `Default` (plus
  `Config.setPromptSlot` on whatever slot the prompt already carries) for a
  `plain` one — and the two used to be written apart.** `PromptUI` refuses to
  adopt anything still on Roblox's default style, on
  the sound reasoning that a default prompt is one nobody has given a kind
  yet — but a prompt that had a kind and was never switched still passed
  that guard, and rendered as the plain grey pill regardless. Measured live:
  the mailbox and a gate jam both set only the kind for a session and both
  drew the default pill the whole time, undetected by any property read,
  because reading `ActionText`/`HoldDuration`/range back reports they were
  built correctly and says nothing about which picture is on screen.
- **The hold fills either way** — Roblox's own pill draws the ring natively
  on a `plain` prompt, and a `card` prompt draws its own bar. Over
  `Config.PROMPT_COUNTDOWN_OVER` seconds a *card* also adds a countdown — the
  HUD half of the problem the vault dial solves from the street; a pill has
  no room for one. `steal`'s own hold is a flat `Config.CRACK.openHold` (half
  a second, well under the countdown threshold anyway) — it opens the crack
  panel rather than timing the robbery, so the lock-vs-lockpicks axis shows
  on the crack dial instead (§5, §14).
- **A `card` prompt can carry a live gold amount beside the verb**
  (`Config.PROMPT_AMOUNT_ATTRIBUTE`), watched rather than read once at build
  so it stays true while a player stands there — `PromptUI` only draws it on
  a `Custom`-style prompt. `steal` still publishes the attribute
  every push (`ClientMain`) but is `plain` now, so nothing renders it; the
  live figure instead rides `ObjectText` on the pill itself — the Vault Lock
  tier (or `Unlocked …`), and
  `Holding … · run home` once the thief is already carrying —
  which is also what `RobBadge` shows from the pavement (§5).
- **A prompt that names an owner is for nobody else.** `post` and `crate`
  both carry `Config.PROMPT_OWNER_ATTRIBUTE` — a plot's own player id — and
  `PromptUI.start` watches *every* prompt in the world for one, rather than
  only prompts that already carry the attribute at build time (a plot's
  mailbox has no owner until somebody moves in). A client disables the
  prompt on its own screen the moment the attribute names somebody else;
  the server re-checks the owner on the trigger regardless, so the client
  rule is a courtesy and never the actual guard.
- **And the mirror exists now too: a prompt that is for everybody EXCEPT
  one person.** `snatch` carries `Config.PROMPT_DENY_OWNER_ATTRIBUTE` so a
  lawn pedestal's owner never sees a pill offering to rob their own plinth,
  while `sell`/`take`/`place` on the same plinth carry the ordinary
  `PROMPT_OWNER_ATTRIBUTE` and are hidden from everybody else (§3). All four
  are switched off and back on across a real frame whenever a plot changes
  hands (`PiggyPedestal.republish`), never toggled within one — Roblox only
  replicates the value a property *has* at the end of a frame, so an
  off-and-on inside a single frame is no change a client ever sees.
- **A part can carry a whole cluster of prompts, and there are two patterns
  for how they share it.** The bin (`hide`/`dig`, both `card`) is
  **exclusive**: only one of the two is ever enabled for a given reader. A
  pedestal's `sell` alongside whichever of
  `take`/`place` applies to its owner is the opposite — **concurrent**,
  both enabled for the same reader at once, because a choice you cannot see
  is not a choice; every one of these is `plain` now. `Config.PROMPT_SLOT_ATTRIBUTE`
  is what keeps concurrent prompts off the same pixels either way:
  `Config.setPromptSlot` grows a later slot's card billboard and pins the
  card to the bottom edge on a `Custom` prompt (a *constant pixel gap* at
  every range — a world-space `StudsOffset` gap would instead close up and
  overlap at exactly the range a reader decides from, `COLLECT_RANGE` on a
  pedestal's set), and nudges the pill itself
  down by `Config.PROMPT_PLAIN_ROW_PX` screen pixels per slot, through
  `UIOffset`, on a `Default`-style (`plain`) one. Slot 0 (`steal`, `sell`)
  sits exactly where a lone prompt on a part has always sat. **The till's
  own `Body` carries a second slot** (`swap`, slot 1 since the smash was
  retired — above), which no single reader ever sees alongside `steal`:
  `steal` is hidden from the owner and `swap` is hidden from everybody
  else, so the two can share the Body without ever sharing a screen — the
  slot exists for the geometry rather than because any one screen shows both
  at once.

---

## 15. Monetization and compliance

**No coin product is enabled, and coins are not purchasable with Robux at
any price, ever.** That is the load-bearing sentence and it has not moved:
it is what keeps a combine, a spare sale and a skin buy-back outside
Roblox's paid random item rule, and it can only be spent once — the day a
coin product ships, every coin-priced random outcome in the game becomes
regulated retroactively with nothing in this repo having changed.

**Two shapes of purchase now, not one.** Monetization used to be *named
things only*; as of 2026-09-23 it is named things **plus** one regulated
random one.

| | Product | Grants |
|---|---|---|
| **Game passes** | `Config.PASSES` — **Style Pack** (riding stances, §10), **VIP** (a skin, an aura, a catch effect and a mark on the plot sign), **Starter Pack** (a skin, an aura and an entry ride) | a NAMED item. Confers nothing, cannot be aimed at anybody |
| **Developer products** | one per crate, `Config.CHESTS[key].productId` (§3); the Elite Lasso, `Config.LASSOS.elite.productId` (§3, §6) | one roll of that crate; a pack of `Config.LASSOS.elite.pack` Elite lassos, each a chance at a catch |

**A crate bought with Robux IS a paid random item, and the machinery that
rule demands exists rather than being deferred.** `docs/GAME.md` said for
months that the Robux route was "deliberately not built" and that a price
field on a chest was a compliance bug; the designer shipped the purchase, and
the Elite Lasso reuses every piece of it end to end
(`ProductService.onLassoReceipt`, §16) rather than growing a second gate — the
purchase itself is not the random draw, but what it buys (a chance per throw,
never a guaranteed catch) is, so:

- **Real odds, disclosed before purchase, summing to 100%** — drawn to scale
  on the tile that carries the price, from the server's own renormalised
  `liveOdds`, with the full per-tier breakdown a tap away (§14). Disclosure
  is a UI obligation and `ProductService` does not do it; what it does is
  refuse to fulfil a receipt whose crate would not honestly open — an empty
  pool, a full lawn — so a purchase can never be spent on nothing.
- **A `PolicyService` gate** — `ArePaidRandomItemsRestricted`, which is true
  for a growing list of players (UK under-18, Australia, Belgium) and for an
  under-12 audience is a large share of them. A restricted player is never
  prompted and never meets a button that does nothing: the card **says**
  NOT AVAILABLE HERE. The check **fails closed**, which is the deliberate
  inverse of `PassService`'s rule below.
- **An idempotent receipt ledger**, `data.receipts`, recorded and saved
  *before* the crate opens, with a refusal un-recording the receipt so the
  purchase comes back rather than being spent on a warning (§3, §13).
- **One `ProcessReceipt` callback per server**, in `ProductService` and
  nowhere else, because it is a single assignable property and a second
  writer would silently replace the first — a purchase that takes the money
  and never arrives.

**The item-versus-value rule is what constrains WHICH crates may be sold.**
A random skin is safe because every skin in a priced pool is **stealable**
(§5), so its coin sale value is a property of the item rather than of the
purchase. A guardian coat is not stealable and no wild piggy wears one, so
the Guardian Crate's five coats (§9) are purchased content carrying a coin
sale value — which is the rule below broken with one extra step. It is
**latent** rather than closed: nothing in the game currently reaches a coat
sale, so the exposure sits unexercised and `tests/luau/crates.luau` prints it
on every run rather than failing on it (§4). It used to sit on a rebirth
rung too, for the same reason, which made the coats *earnable* and closed the
question; that rung is retired (§4) — the guardian ladder is bought with
coins directly now, and the Guardian Crate stands alone as an ordinary paid
crate. **Anything added to a paid pool has to answer the same question.**

**Every `productId` is 0, so nothing is buyable yet** — a working state, not
a broken one: the card reads COMING SOON, nothing prompts, and the game
degrades to the earned-only catalogue it was. `ProductService.start` warns at
startup naming each one, because a zero id is invisible from inside the game.
Creating them is a Creator Dashboard job; the ids then go in `Config.CHESTS`.
`Config.LASSOS.elite.productId` is the same PLACEHOLDER 0 and warns the same
way (`Config.auditLassos`, §6); the coin-bought lassos are outside the rule
entirely, the same as every other coin price in the game, because coins are
never purchasable and an Elite lasso itself is never sellable back for them.

**VIP is not a rate, and that is arithmetic rather than policy.** A straight
income multiplier fails `Config.auditRobbery` (§5) outright — the full-server
baseline it would be dragging down from is already close to
`Config.ROBBERY_ADVANTAGE.min`, with `Config.SHOP_VAULT_DISCOUNT` sitting at
0.70 to pay for the shorter run home a shop vault costs a thief (§5). The whole
residents-and-shop-vaults programme exists because idling was out-earning
robbing, and a rate pass reintroduces that exact failure for paying players
specifically — the worst group to break it for. So VIP is named things and a
mark on the street
instead: any catalogue item anywhere carrying `pass = "vip"` is granted
(`Config.passItems`, derived by walking every cosmetic catalogue rather than
kept as a second list that could drift) — today the Velvet Rope skin, the
Spotlight aura and the Paparazzi catch effect (§9) — plus `signWord`/
`signColour` on the owner's own plot sign (`PlotService.setSignPass`), the
only physical boast surface this game has. `CosmeticsService.grantPassItems`,
hooked to `PassService.Granted`, is the one grant path every pass uses —
through `SetService.grant`, never a second one — so a pass item cannot drift
from how a chest or an event grants the same thing. **Granted into the save
rather than gated at render time**: an entitlement re-checked at every join
survives a lost save, and a refund does not claw the items back.

**The Starter Pack is the entry offer**, priced below the Style Pack, and
carries no consumables and no countdown or fake discount — a stack of bones
is coins with extra steps regardless of how they arrive, and time-pressure
selling aimed at this audience is a decision made in the source rather than a
rules question. Like the Style Pack it grants the cheapest ride, never a
matching one, when the buyer owns none.

**Rules that are not negotiable:**

- **A Robux purchase may grant an ITEM, never its coin value.** Granting a named
  thing mints no coins and feeds no roll.
- **A game pass is buyable from the store page, outside the game**, so nothing
  may assume the buyer already owned something. The Style Pack and the Starter
  Pack both grant the *entry* ride (the cheapest, never the matching one) when
  the buyer owns none — self-clearing, so it needs no bookkeeping.
- **An unset pass id UNLOCKS what it gates**, and warns at startup. Locking
  content no purchase can reach is indistinguishable from a broken feature and
  cannot be noticed from inside the game.
- **A failed ownership check is not a NO.** Leave the cache entry absent so the
  next ask retries; writing `false` on a network blip takes a paid feature away
  from someone who owns it.
- **A failed POLICY check IS a no**, which is the deliberate inverse of the
  rule above and the one place the two diverge. There the wrong answer takes
  a paid feature from somebody who paid; here it *offers* a regulated
  purchase to somebody the rule protects. `ProductService.restricted` reads
  anything that is not an explicit `true` as restricted, checks
  `ArePaidRandomItemsRestricted == false` strictly (so a field Roblox renames
  or stops sending reads as restricted rather than as permission), and leaves
  a failure absent so the next ask retries.
- **A `robux` field on a crate or a pass is a DISPLAY price**, kept in step
  with Roblox's own by hand — there is no API that makes it authoritative.
  `productId` is the thing that actually charges.
- **Locked content is SENT to the client, never filtered out.** The shop is
  where something you do not own is supposed to be advertised.
- **Every pass gets a card on the shop's SPECIAL OFFERS shelf (Worn tab,
  §14) unless it already has a better home.** `Config.PASSES.stylePack.soldWith`
  points that one pass at its own tab instead, so a riding pose is sold next
  to the rides it animates rather than as a second card nobody connects to
  them — the same argument against a near-identical duplicate this file makes
  everywhere else.

**Rebirth still leads to a random reward**, and it is now a rare crate with a
legendary every fifth (§4) rather than a legendary every time. It is FREE, so
it is outside the paid random item rule; what puts it back inside is a coin
product, because the gate in front of it is coins. Any future coin-sale work
must revisit this route and the master plan's random-reward audit first.

**The Robux ladder is 1 : 3 : 12 across a shelf's three rungs, and it was
measured rather than picked.** Value per coin is odds over price, so matching
the cheap crate's rate exactly would make the top one *cheap* per legendary
and nobody would buy anything else. At a retail-looking 79 / 199 / 449 the
ladder inverts — the legendary crate comes out cheaper per legendary than the
common one — and it becomes decoration. The shipped ratio holds the premium
the retired coin ladder had, and **the top rung stays under VIP's price**,
because a single random roll costing more than a permanent entitlement is
indefensible for this audience whatever the odds are. The Guardian Crate is
priced on its own row rather than off a tier ladder, and **below the entry
pass**, on the argument that a single random open should be the cheapest
thing in the shop. Named constants only here — the figures are in
`Config.CHESTS`.

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

The **Season window** group exists because the buy-back claims and the
hot-skin timer key off `Config.seasonIndex` (§3): `seasonshift` moves *this
server's* season clock by whole weeks (`SeasonService.shiftWeeks`, never
saved, bounded), and `seasonstate` prints `SeasonService.status`. There is no
`seasonearn` command any more — it credited the season ladder's rank, which
retired with the Acorn currency (§3) — and no Tree group: the tree it used to
set a level on is deleted along with everything else in that loop.

The **Piggies** group is the lawn-and-indoor pedestal collection (§3, §12):
`fillpiggies` fills every free slot the save can hold today — the six lawn
pedestals (`Config.PIGGY_LAWN_SLOTS`, a placement grid separate from the
ordinary decor lawn slots) plus whatever indoor plinths this rebirth count
has unlocked (`Config.indoorPlots(data.rebirths)`, numbered from
`PIGGY_LAWN_SLOT_COUNT + 1`, same as a hallway's own plots) — through
`Config.placePiggy`, the door a hallway's Place prompt uses too, so a slot
the interior would refuse is refused here. `clearpiggies` clears all
`Config.PIGGY_SLOT_COUNT` slots, lawn and indoor together. `piggystate`
reports the two counts apart (lawn against six, indoors against however many
this rebirth count unlocked), because the lawn is fixed and the hallway is
not. Two named placements — a common Classic Pink and a legendary Prismatic —
sit side by side at opposite ends of the rarity ladder so the rate multiplier
between tiers is visible on one lawn.

The **Lasso** group tests catching one without a second player or Robux.
`lassos` sets the caller's stock of every tier — the Elite included, so its
odds can be exercised without spending real money — to a flat count through
the same stock table a purchase fills, and repaints the card. `droppiggy
<rarity>` drops a single wild piggy beside the caller at a chosen rarity,
common through legendary, through the same landing rules a real herd drop
uses, so a tier the natural spawn cap (§17) does not yet reach can still be
lassoed and looked at.

**"Spawn any piggy to look at…" is the one row that opens a second screen
instead of firing a command directly** (`open = "piggies"`, the panel's only
use of that vocabulary): `Shared/AdminPiggyPicker` is a shelf of every skin in
the game, laid out like the Crates tab and grouped by collection, and every
card fires `AdminRequest("spawnpiggy", key)` itself — the panel still owns
nothing but its table of rows. `AdminService.spawnpiggy` builds the skin
through `PiggyModel.build`, scales it to `Config.PIGGY_PEDESTAL.display *
Config.piggyScale(key)` (§9) — the exact size a lawn pedestal would show it
at — and stands it anchored on the ground in front of the caller, lined up
seven studs apart in rows of six as more are spawned, with a nameplate in the
skin's own rarity colour. It is named `Display`, which is load-bearing: that
is one of the three names `ClientMain`'s mini animator collects by, so a
spawn under any other name would stand still with no aura running — a mute
copy of the one thing this tool exists to show moving. Spawns live under
`workspace.AdminSpawns.<userId>`, own no save data, and `spawnclear` deletes
the caller's own folder.

The **Collection** group is the only way to open a crate at all today, since
no developer product exists yet (§15). `chest <key> <n>` runs
`ChestService.grantFree` up to 25 times and prints the tier and item of each
roll, or `refused` with the reason the whole flow would have given; a bad key
lists every chest. `daily <n>` winds `lastDay` back and claims through the
real path, so the day-one and day-seven crate rungs queue onto the doorstep
exactly as they would on a Sunday, and `post` stops one step short so the
mailbox flag can be looked at. `spares <n>` seats spares of every tier — and
it is the only route to a `coat:` spare in the game, which is what the Piggy
Press's GUARDIANS setting currently needs (§17). `combine <tier> <chest>`
runs the real `ChestService.combine`.

The **Heist** group exists so a solo session can drive a real robbery with no
second player. `shield` calls `HeistService.openSeason()`, dropping every
join shield and clearing the per-victim cooldowns street-wide. `crack`
(replaced `smash` when the smash was retired, 2026-09-23, requiring
`ResidentService`) finds the *nearest resident's* pig on
a house plot within `Config.STEAL_RANGE` — never a real player, and never a shop, since a shop's vault
has to be robbed from inside the room — opens it with `HeistService.attemptSteal`
and lands every slice through the real judge, `HeistService.devTapInZone`, at
the moment its own marker sits in its own zone: `whyCannotSteal`, the drain,
`attachLoot`, the
carry, the alarm, the dog. That is what makes the coin carry's money bag
(§5) inspectable at all outside a real two-player session — no prompt can be
held in Studio otherwise, because `RenderStepped` never fires while the
viewport is not drawing, so no prompt is ever shown. `catchfx` fires a
player's own catch effect on themselves for the same reason: the real
trigger needs a second player carrying somebody else's coins.

A command may target another player by userId (resolved **server-side** from the
live player list); `reset` is self-only, because every other command is undone by
pressing another button and a wiped save is not.

---

## 17. Known gaps

**This section records absences, and nothing prompts a re-read of an absence
when the thing that fills it lands.** A doc pass runs against the system that
was just added and updates the section that describes it, never the section
that recorded it missing — which is how three bullets here went stale at
once: a `ChestCombine` caller that now exists, a `screen_capture` camera limit
`CLAUDE.md` itself has since lifted, and a skins-crate cutover that had
already shipped. Corrected below.

- **The dog's wardrobe is verified end to end on the owner's own plot, and the
  one thing left is whether a THIEF can read it from the pavement.** Measured
  live (§9): a kennel skin repaints `wood`/`trim` while the roof stays the
  coat's `collar`; toggling a skin off restores plain wood; the duty vest
  shows only on the one dog that was given a treat (1 of 14) and survives
  three full `applyTier` repaints — a coat cleared, a different coat worn and
  the kennel re-skinned — with the collar never going neon and the plate
  holding ON GUARD; and a save naming a kennel that has been deleted from
  `Config` degrades to plain wood without throwing. (Dog toys were retired
  after this pass and are gone from the wardrobe entirely, §9.)

  None of that needed a second player, because none of it is per-client: the
  server builds the parts and the nameplate and the kennel board are ordinary
  replicated GUIs. What has NOT been checked is the thing the vest exists for —
  **whether the vest, the name and a sleeping posture actually read from the
  street**, at the `MaxDistance` of 90 both labels carry. That is a
  look-at-it question rather than a code one, and it is no longer blocked by
  the tool: `CLAUDE.md`'s `screen_capture` entry now says the camera CAN be
  aimed during Play, provided the write to `workspace.CurrentCamera` is held
  on `RenderStepped` — it is the tool's own camera arguments that are
  ignored, not the camera. It has simply not been tried yet.

- **The leashed chase, the knockout and the sleep pose are all unverified
  against a live pursuit.** `Config.DOG_CHASE`'s leash box, turn rate and
  catch cone, `HeistService.knockOutOfYard`'s front-or-alley landing choice,
  and the `DogKnockout` client-side arc in `bindFenceKnockback` have only
  been reasoned about against the geometry, never driven through a real
  chase — that needs a second player carrying loot for a dog to actually
  catch. Nor has the new Sleep pose (`GuardAnimation`, the eyes squashed shut
  by `GuardAnimator.client`) been seen on screen; it is built the same way
  every other posture in this file was, and none of those were trusted until
  somebody looked.

- **No Robux crate can be bought, because every `productId` is 0 (§3, §15).**
  That is the deliberate unshipped state — the card reads COMING SOON and
  `ProductService.start` warns at startup naming each one — but it means the
  *whole* paid path is unexercised in a running game: no `ProcessReceipt` has
  ever fired here, no receipt has ever been written to `data.receipts`, and
  no purchase prompt has ever opened. The suite
  (`tests/run-crates.py --suite crates`) drives the receipt ledger, the
  idempotency, the policy gate and the refusal-before-charge against the real
  `ProductService` and `ChestService`; nothing about it has met Roblox.
- **The `PolicyService` answer has never been a real one.** Every test of the
  gate has set `allowed` directly or stubbed the service. What has *not* been
  seen is `GetPolicyInfoForPlayerAsync` returning on a live join, the
  fail-closed default holding for the beat before it lands, or the re-push
  repainting the card off `restricted` — which is the one sequence a
  restricted player actually experiences.
- **Nothing in normal play mints a `coat:` spare, so the Piggy Press's
  GUARDIANS setting can only ever read 0/3.** Spares now come from theft
  (§3) and the only kind a haul carries is `skin`; a wild piggy caught out of
  a herd is a second piggy rather than a spare. So the machine's second kind
  is exactly the control-that-does-nothing the combine row was moved off the
  Crates tab to avoid, reachable today only through the admin console's
  `spares` command. `Shared/Inventory` has no coat tab either, so a coat
  spare cannot be *sold* from inside the game any more than it can be
  earned. Recorded, not fixed — the fix is a source change (a coat being
  stealable, or a coat duplicate becoming a spare), not a doc one.
- **The Piggy Press has never been built, held or looked at.**
  `tests/luau/combine.luau` (293 checks) covers its placement, its box list,
  its coplanar audit, every street clearance and every refusal its panel can
  print — deliberately, because the pure half is plain arithmetic and a probe
  needing a workspace could not run at all. What that suite states it does
  **not** cover is the whole of the rest: no pixel has been looked at, no
  prompt has been held, the model has never been built in a session, and the
  reveal, the hold and the panel's layout are unverified.
- **Every earlier verification of the shop's Crates tab was against a charged
  `ChestOpen` remote that no longer exists, and none of it has been re-run.**
  This section used to carry several detailed bullets — real pointer clicks
  producing a reveal, an OPEN button greying when unaffordable,
  `ChestCombine` chips, `Inventory`'s SpareSell button — all measured against
  the mechanism where a crate had a coin or Acorn price. `ChestService.roll`'s
  charged path and the `ChestOpen` handler are deleted (§3). Nothing here has
  driven the current flow through a real pointer click: the two daily-ladder
  doorstep crates, a rebirth's free crate, the five button states and the
  collections layout are all unverified end to end in their current shape,
  and the combine row those bullets describe is not on that tab any more.
  Treat every number in the removed bullets as describing a mechanism that no
  longer exists.
- **The shop's rebirth gate is measured, not looked at.** `tests/luau/shopui.luau`
  (511 checks) holds the routes, the purchase gates, the wash and its order,
  and asserts each house gate sits at or below the first rebirth whose pig
  holds that price — against `Config.REBIRTH_CASH_GATE` rather than a number
  anybody typed, so **a gate may never be the last thing refusing a house**
  and a price edit that outran its own gate is caught at the next run. It
  also asserts the cheapest ride carries no gate, derived from the prices
  rather than the key, so a re-priced catalogue cannot strand the ride two
  passes grant. What has NOT been seen is the wash itself: the ink sheet's
  strength over a real card, the padlock, and whether the raised price pill
  actually reads through it. The label's own geometry *is* measured —
  "Rebirth 20 required" is the longest string it can ever print, since
  `rebirthsToMax()` is 20, and it fits one line on the shipped card with
  room, wrapping to two rather than shrinking on anything narrower (which is
  why `TextScaled` is off and `TextTruncate` is None: with those the failure
  is silent shrinkage or silent clipping). Measured through
  `TextService:GetTextSize`, never looked at.
- **The duplicate-skin-becomes-a-second-piggy rule (§3) is unverified, and it
  is now a FALLBACK rather than a live path.** `poolOf` filters every crate
  pool to the unowned set, so `ChestService.handOver`'s repeat branch cannot
  be reached from a crate at all; it survives for a caller with its own pool.
  `Config.addPiggy`, `Config.firstFreePiggySlot` and the "your lawn is full"
  refusal in `whyCannotOpen` are all still live — the refusal is what a paid
  receipt hits first — and none of the three has been driven through a real
  crate open. The admin panel's **Piggies** group (§16) is the fastest way to
  exercise it.
- **Carrying a piggy off a pedestal (§3) is verified live end to end for
  everything one player and a resident can exercise, and nothing beyond
  that.** Every verb ran through the real prompts: take → carrying → place
  onto a different plinth and back down; snatch → the victim's slot
  emptying, the piggy marked `stolen`, the first-session shield dropping;
  the secure dwell counting down and landing on the nearest free plinth,
  resetting the moment the carrier leaves the lawn, never starting on a
  full one; the per-victim cooldown refusing a second snatch by name; a
  guard dog catch returning the piggy to its origin slot; a disconnect
  mid-carry doing the same; and a ride refusing to mount while carrying.
  What has NOT run is **a real second player**: the alarm toast naming the
  thief, the shield refusal against a live victim, and a bystander pressing
  the nab prompt on a carrying player are all reasoned about rather than
  driven — the same wall the rest of the heist system is behind.
  `Config.LOSS_CAP`'s piggy clause (bounding what a whole street can take
  from one victim, rather than one thief from one victim) is not built at
  all, and `Config.RESIDENTS.piggyCount`/`.piggyTopRarity` are both
  provisional pending the same economy pass. The pedestal guard
  (`docs/PIGGY-COLLECTION-PLAN.md` §12, waking something on a snatch beyond
  the dog's ordinary footstep rule) is also not built, and neither is an
  indoor room — `roomFor` is the one
  predicate that changes when a house becomes a second room with its own
  free-shelf test; today it is `PlotService.yardContaining` and nothing
  else.
- **The lasso (§3, §6) has never run in Studio, and `Config.HERDS.tierCap`
  still stops it reaching most of its own catalogue.** The cap is `"rare"`,
  a leftover from the free-catch era, so an epic or a legendary lands only
  through the admin console's `droppiggy` (§16) — natural drops cannot yet
  produce the piggies the top two lasso tiers exist to be worth having for.
  Raising it is an open decision (`docs/LASSO-PLAN.md` §8), and doing so
  re-opens `auditRobbery`/`auditHerds` (§4), because a wild pedestal is idle
  income the same as any other. The odds table, the pity ladder, the prices
  and the rebirth gates are all placeholders for the same reason. Offline:
  every rule in `Config.lassoChance`, the struggle, the flee, the dazed
  state's timers and its exclusivity, and the theft/star/revenge wiring are
  covered by `tests/luau/lasso.luau`. Unmeasured: whether the tap struggle
  feels good on a tablet, and whether a fleeing piggy reads as a chase or a
  nuisance — both are look-at-it and feel-it questions no suite can answer.
- **`Config.isSellable` does not know which catalogues can produce a spare.**
  It admits anything with a coin `cost`, so the Inventory panel shows a SELL
  button on rides and decorations too, even though no chest can ever
  duplicate either — a 90,000-coin BMX shows "SELL 22.5K", and pressing it
  fires a genuine, un-refused last-copy sale through the same
  `SetService.revoke` path a skin uses. Recorded, not fixed.
- **The alien set (§8) has no live in-game route.** The Alien Cache was
  deleted on 2026-09-23, so the alien raid's `SetService.rollDrop` is the only
  source of the Martian and the Hoverdisc -- and `Config.EVENTS.enabled` is
  false, so the raid runs only from the admin console. The Tractor Beam effect carries a
  stale `set = "alien"` tag but is no longer listed in `Config.SETS.alien`,
  so it currently has no route to a player at all — neither a crate, a
  storefront, nor an event drop.
- **`Config.FINISHES` is unobtainable.** The season-tier ladder that used to
  grant one is retired (§3); nothing in the game currently calls
  `SetService.grant(player, "finish", key)`. The catalogue, the Inventory's
  Finishes tab and `PiggyBank.applyFinish`/`PlotService.applyFinish` are all
  still present and presumably still work if something grants one, but that
  has not been exercised since the season ladder retired.
- **The lawn-pedestal piggy collection's own base save schema
  (`data.piggies`, the per-slot buffers, `data.tillBuffer` before its
  2026-09-22 retirement, §3, §4) is still not documented in §13** — not
  the schema version it landed at (the till buffer's own retirement comment
  in `DataService` names it "schema 27", which this file has never
  described), and not what version folded `data.piggies` in either. §13
  currently jumps straight from schema 26 (houses) to the seasonal buy-back
  claims with nothing about either. What §13 now covers is only the
  array's 2026-09-23 *widening* to hold the hallway as well as the lawn
  (§3, §12) — this is a documentation gap in this file, not a claim about
  the save shape being wrong.
- **The achievement counters have no visual home at all, and this is new
  rather than carried over.** `TrophyRoom`, which drew three stat panels and a
  wanted poster onto an authored house's `Wall` mount, was retired outright on
  2026-09-22 — one day after it shipped, before the question above (whether it
  rendered correctly, and what a code-built tier with no mount looked like)
  was ever settled. `data.trophies` is still counted and `plot.trophies` is
  still published by `PlotService.setTrophyState`, but nothing reads either
  one to draw anything. The lawn's own trophy rebuild is confirmed dead by
  reading `Config.TROPHIES = {}`, not by looking at a lawn.
- **Residents (§5) close most of the "needs two players" gap, and that is
  newly TRUE rather than newly VERIFIED — nothing in this pass exercised it.**
  A single player can now rob a `ResidentService.Resident` end to end: the
  crack against a real Vault Lock, the carry, the guard dog chase and
  nab, the getaway, delivery and ×`HEIST_PAYOUT`, a patrol pursuit, an arrest,
  and bail all run against a resident exactly as they would
  against a player, by construction of `HeistService`'s `Target` type. What a
  resident genuinely cannot exercise, because `HeistService` skips it for one
  on purpose: `Config.LOSS_CAP`'s clamp on a fourth grab, `Config.REVENGE`'s
  window/payout and the grudge marker, and the friend bonus. Those, plus the
  Golden Bone's chase-break, hiding while carrying, and being tipped out of a
  bin by somebody else, still need a real second victim.
- **No skin with an `aura` can spawn on a resident's lawn or in a street
  herd — which now includes every epic, not only every legendary.**
  `Config.herdSkinPool` and `ResidentService`'s own coin-pig (`drawSkin`) and
  pedestal-piggy draws (§3, §5) all skip anything carrying an `aura`, the
  same test that already keeps a pass or set skin off scenery nobody paid
  for. That exclusion pre-dates 2026-09-21 — every existing legendary already
  had one — but the OG family's six new epics and the `animal` shelf's own
  four (§3, §9) all walk straight into it too, so a resident or a herd
  member can currently only ever wear a common or a rare skin. Recorded, not
  fixed.
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
- **The tug (§5) and the owner-interrupt (§5) are two more gaps residents
  cannot close, and neither has run end to end.** A resident can only ever be
  a *victim* — `HeistService.nab`'s `thief` parameter is always a `Player`,
  and nothing about a resident can carry loot away to be nabbed for — so
  unlike almost everything else the residents bullet above closes, a
  player-versus-player tug needs a second real thief. Nothing about who wins
  a multi-nabber tug, whether a dodge genuinely breaks one mid-recovery, or
  the anti-swarm rest actually holding under a crowd has been driven through
  the real remote. What HAS run is the *picture*: the admin panel's
  `commands.catchfx` writes the same two attributes
  `HeistService.fireCatchEffect` writes, in the same order, so `CatchFX`'s
  renderer (§9) is proven — its own comment says in as many words that this
  is "the cheap way past" the wall and that it does *not* exercise who wins a
  tug. The owner-interrupt has the identical shape and the identical gap: it
  needs the plot's actual owner, never a resident, walking home in person
  while somebody else is on their lawn cracking the lock.
- **The crack (§5) is live, and the single fixed steal hold it replaced is
  gone.** `Config.CRACK`, `Config.CRACK_ALARM_ON_MISS`,
  `HeistService.crackTap`/`.crackStop`/`.isCracking`/`.scare` and
  `Shared/Crack.luau` are wired end to end — `attemptSteal` only opens an
  attempt now. `Config.STEAL_HOLD`/`Config.getStealHold` and
  `UpgradeService.getStealHold`/`.getStealFraction` are retired with it.
  The two gaps this bullet used to record are both closed: the guard dog now
  wakes on footsteps above a breed's `notice` as well as on a missed slice
  (`HeistService.watchLawns`, §5), and `Config.UPGRADES.tiptoe` (Sneak)
  gives tiptoe its own four upgrade levels, read by `currentSpeed` through
  `UpgradeService.getLevel`. Like the rest of the heist system, the crack has
  not been exercised end to end against a real second player — see the
  residents bullet above for what a solo session can and cannot cover.
- **The smash — the loud, fast way into the same pig this bullet used to
  verify — is retired** (designer, 2026-09-23; see §5). `Config.SMASH`,
  `HeistService.smash`, `PiggyBank.buildSmashPrompt` and the second stacked
  prompt card it drove are all gone; the figures this bullet used to record
  (a smash's coins-per-second against a clean crack's, the shop-room refusal
  at 5.2 studs, the guard-dog release on landing) described a mechanic that
  no longer exists and are not carried forward.
- **The shopkeeper (§5) — the shop's own guard dog — was verified through the
  real smash prompt, which is retired; the surviving trigger (a fumbled crack
  slice) has not been re-driven.** The earlier run had a smash on a shop
  vault announce the shopkeeper, who came out to a measured 2.16 studs from
  the thief and caught them at a gap of 4.38 studs, returned to the counter
  by t4.4 and rested there; the leash was checked by teleporting the thief
  200 studs away in a single frame, which made the shopkeeper give up
  without ever leaving the counter (peak distance from it 0.00). Nothing
  about `ResidentService.alertShopkeeper` or `HeistService.shopkeeperCatch`
  changed when the smash left, and the admin `crack` command (above) can
  fumble a slice on a shop's own resident, but that specific path has not
  been driven since. What has NOT run either way is the branch against a
  real second player rather than a resident standing in for one — nothing
  about the catch itself differs between the two, since
  `HeistService.shopkeeperCatch` calls the same `nab`/`scare` a real dog
  does.
- **The shop-vault drop's owned-item fallback (§5) is isolated-test verified;
  live gameplay verification remains open.** `Config.sellValue` returns the right coin
  figure for a duplicate off each of the three item tabs (2.0K for
  `skin:bubblegum`, 50.0K for `skin:lava`, 22.5K for `ride:bmx`), so the
  numbers `rollShopDrop` would pay are known to be right. The real fallback
  function now also passes an isolated ride-collection payout/save/toast test.
  Observing it in normal play requires a completed crack, a successful
  per-shop roll, and a fully owned shop collection.
- **The wanted-star ladder (§5, §7) now has a state-machine pass —
  `tests/luau/wanted.luau` — and what it covers and what it still does not are
  two different lines.** Before it was folded into `Config.WANTED_STARS` on
  2026-09-22, this mechanism was `Config.SPREE`; `Config.SPREE`,
  `getSpreePayout`, `getSpreeFloorScale` and `breakSpree` are all gone, and
  the pursuit floor they were folded toward (`wantedFloorSeconds`,
  `getStarFloorScale`) retired outright the same day (§7). The new suite loads
  the *real* `SocialService` against a clock it can advance and drives it
  directly — `recordSteal` climbing the ladder, the Most Wanted pin holding a
  leader at `WANTED_STARS.max` with the fade clock held, the hand-over
  re-stamping the old leader to fade from five, `clearHeat`/`clearStars`
  firing in the right order on an arrest, and the whole state cleared on
  `PlayerRemoving` and written to no save — and feeds the real payload into
  the real `Shared/Wanted.luau`, holding the drawn star fill against
  `Config.starsAfterQuiet`. That is the fresh pass against the new names this
  bullet used to be waiting on. What it does **not** cover, because nothing
  short of a live server can: `HeistService.deliver`'s own two star lines
  (reading the multiplier before `recordSteal` bumps it, and naming the run
  in the delivery toast) firing off a *real* robbery, and a real second player
  (or resident) actually watching the chip and the poster move. That needs
  the same real delivery the rest of the heist system is waiting on.
- **The tiptoe animation (`Shared/SneakWalk.luau`, §5, §10) is verified live
  on one character and not across two.** Driven through the real remote and
  attribute rather than a mock: `Config.SNEAK_ATTRIBUTE` publishes, the track
  loads and `WalkSpeed` drops with it, the loop holds exactly `RATE_FLOOR`
  while stationary and unwinds cleanly on release, every phase keeps the toe
  below the heel (worst case +0.285 studs) with no new floor clipping (deepest
  foot +0.012 against a +0.006 standing baseline), the swing foot peaks 1.21
  studs up and the head rides +0.26 higher. What has NOT run: a second player
  actually seeing somebody else's sneak — the entire reason it publishes
  per-viewer rather than through `TiptoeState` — and the uploaded asset
  itself, since `Config.ANIMATIONS.sneak` ships empty and every test so far
  has only exercised Studio's own runtime `RegisterKeyframeSequence` path.
  `animdump` builds it now — its `own` table is walked rather than
  special-casing `dodgeRoll`, so `sneak` and `carry` (below) are both
  produced (§10) — but nobody has run the command and published the result.
- **The carry pose (`Shared/CarryPose.luau`, §2, §5, §10) is new this session
  and unverified across two players, in the same shape as the tiptoe above.**
  It is the identical mechanism — a code-built `KeyframeSequence` per KIND,
  each registered at runtime in Studio and looked up first as an uploaded
  `Config.ANIMATIONS` id (`carry` for the hug, `carrySling` for the sling),
  both of which ship empty — so on a published server nobody's arms hold
  anything until both ids are filled in and published through `animdump`.
  `CarryPose.luau`'s own header records both poses measured on a single
  character (hand-to-load contact, the weight-0 root/lower-torso path
  holding the run's own pelvis, the Movement priority sitting under a
  dodge), with the load welded to the right hand via `CarryPose.anchor`
  rather than to the root. **The carries split permanently on 2026-09-23**,
  after a one-armed shoulder sling briefly replaced the hug for both loads
  and was then restored to the hug for both: the designer's final call keeps
  *both* — a hauled piggy (`PiggyHaulService`) hugged in both arms, stamping
  `Config.CARRY_KIND_ATTRIBUTE = "hug"`, and the coin sack (`HeistService`)
  slung one-armed over the shoulder, stamping `"sling"` — told apart by the
  word on the model itself, with a model naming neither defaulting to the hug.
  A single-player robbery WAS driven end to end through the real prompt
  rather than through a module handle, under the intermediate hug-only state
  that has since been split — walked into range, `PromptShown` and
  `Triggered` both firing, the smash landing (the smash itself is retired
  since, above; this record is historical), and the coin sack seating at
  exactly `CarryPose.HOLD` (the hug's own seat, since coins were hugged at
  the time) with the pose running at Movement priority and clearing again on
  delivery. **The SLING half has been driven again since the split**, through
  the admin `smash` command (the real `HeistService.smash` path, residents
  only — that command is `crack` now, above, and runs a real clean crack
  rather than a smash): the bag arrived stamped `"sling"`, welded to the right hand, with
  the `CarryPoseSling` track playing at Movement and the cloth's own `Body`
  part 0.09 studs off `SLING_HOLD` in root space, and it was photographed
  over the shoulder from behind and from the side. **The HUG half has not**:
  a live piggy snatch has not been driven against the two-kind code, so
  `HOLD` on a hauled piggy is verified by the resident suite's stub and by
  the seat being byte-identical to what it was, not by a prompt. Nor has one
  player watched ANOTHER carry loot home of
  either kind — the entire reason it publishes per-viewer, off the loot
  model's own presence and its `CARRY_KIND_ATTRIBUTE` on the carrier's
  character, rather than through a remote.
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
- **What survived the season ladder's retirement has not run against a real
  DataStore either.** The NEMESIS line and the shortened boasts on the plot
  sign are unverified layouts; the season ladder they used to sit beside
  (tiers, finishes, the trophy shelf, the board's third page,
  `Shared/SeasonBoard`) is not merely unverified now, it is deleted (§3, §9,
  §14) and none of those old claims should be trusted for anything still
  standing. The Top Defenders store has never been written to or read from
  live.

`CLAUDE.md`'s "Not yet verified" section is the long-form version of this list
and is kept in more detail.
