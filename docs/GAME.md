# Rob a Piggy Bank — the whole game


> **September 16 direction:** standalone piggy auras and their shop are retired.
> Piggy effects are coin-deposit feedback and Legendary skin visuals only.
> Existing effect ownership is retained for save compatibility; these items
> cannot be bought, equipped or newly awarded. Piggy Outfitters drops skins
> only at its unchanged 10% overall bonus chance. Older effects-shop notes
> below are historical and must not be used to restore the feature.

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
taken. Other players can walk onto your lawn, crack — or smash — your lock and
carry a slice of it home — and you can do the same to them, and **stolen coins
count double** once they are home. Every plot nobody has claimed carries a **resident**
instead of standing empty — a named neighbour with a real, growing piggy bank
— so there is always somebody worth robbing, even alone (§5). Each of the four
shops on the street also hides a **strongroom vault** on its own back wall —
robbed by walking inside, on a plot nobody can ever claim — so a full server
never runs out of victims either (§5).

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
> currency (**Acorns**) is moving to tree shakes under the master plan,
> revenge pays extra coins, and the join shield is short. Events, chests and sets are frozen until this is clear and
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
hand-built geometry — the ground, the street, the tunnels, the houses, every
plot, the piggies, the dogs and the police car are constructed by
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
module. `AdminPanel`, `SpinWheel`, `RaidFX`, `HouseFX` and `Rebirth` are modules
for exactly this reason.

---

## 3. Currencies

There are **two**. Coins buy the standing catalogue; earned-only Acorns buy
crates and set items. Neither currency is currently sold for Robux.

| | Field | Earned by | Buys | Purchasable with Robux? |
|---|---|---|---|---|
| **Coins** | `data.coins` — the piggy bank, all of it stealable | idle accrual (stops at capacity), delivering a robbery (**counts double**, triple on revenge), dailies, events, **selling a chest-duplicate spare** (`Config.SELL`, below) | upgrades, houses, decorations, rides, consumables, **trophy plinths** (§9); crates use Acorns | No current product |
| **Acorns** | `data.loot` (unchanged save field) | approved full-legendary-collection rebirth bonus; tree growth/shakes remain Phase 2. Events and piggy deliveries pay none | set items and every crate in `Config.CHESTS`; the accessory roll is retired along with `ACCESSORIES` (§9) | **never, at any price** |

**Medals and tokens are retired into loot.** `data.medals` and `data.tokens`
were merged into `data.loot` one-for-one at schema 17. The daily ladder pays
coins and boosts and no Acorns.
Chest duplicates are a separate, chest-internal currency — see **spares**,
below.

### Earned-only crate purchases

**No crate charges coins.** Every `Config.CHESTS` entry uses the persisted
`loot` currency, named Acorns by `Config.ROLL_CURRENCY`. `ChestService` refuses
an unknown, missing or coin currency before rolling or charging; it has no
coin-payment fallback. `Config.auditEconomy` reports any crate that violates
this rule at boot, separately from the coin catalogue's capacity checks.

This implements master-plan step 1.4. Step 1.9 now adds the broader
random-outcome sweep and removes legacy event Acorn payouts (below).
No coin product is sold. The accessory roll is retired with `ACCESSORIES` (§9).

### Chests — Acorn-priced, and duplicates are allowed

`Config.CHESTS` is **five** Acorn-priced chests (15 / 15 / 18 / 45 / 120 for
`og` / `animal` / `alien` / `rarecrate` / `legendarycrate` since the 19.5
re-solve; buy-back tickets and the rebirth-crate bonus derive from them): four skin crates (`og` — "Piggy
Originals", 31 skins tagged `chest = "og"`; `animal` — "Animal Kingdom", 9
skins tagged `chest = "animal"`; `rarecrate` and `legendarycrate`, which carry
no themed pool of their own and instead draw rare-or-better across both skin
shelves) and one event-set crate (`alien` — see below). `og` is
the old `classics` chest with the retired `neon` chest's eleven skins folded
into it — the two were never a different *kind* of skin, just a palette
split, and palette is not an axis a nine-year-old shops on; `animal` is left
as the Blender-textured set now that its four flat-paint members (Woolly
Sheep, Dalmatian, Cheetah, Orca) are gone; Circuit Board went with them in
the same pass but off the neon shelf, not this one. Each chest carries its
own `cost`, `currency`, an `odds` table by rarity and a `blurb`. Membership is
a field **on the item**, the same convention `zone` uses on decor and `set`
uses on set items, rather than a list kept on the chest — a list is a second
place to remember and the one that goes stale. An item's tier inside a chest
is `Config.rarityOf`, the same function that already borders every shop card —
not a second notion of rarity.

**Skins carry three rarity tiers now, not four — `common`, `rare` and
`legendary`, with no `epic` skin.** The tier is meant to describe what the
skin *is* rather than only what it cost — common is a flat paint, rare is a
paint with a twist plus one glowing element, legendary adds geometry, an
animation and a glow on top of that — and it is the TECHNIQUE ladder, not a
price ladder wearing new names: a coat is common however well it is painted,
and only a skin built through the alpha pass (glow, and the glow *moves*)
counts as legendary. Every one of the 45 skins carries an explicit `rarity`
field now rather than falling back through `Config.rarityOf`'s price
derivation — the one exception is `martian`, the Alien Cache's own skin, which
keeps `epic`: it is a *set* item in a mixed-kind chest rather than a member of
a skin chest, so the three-tier restructuring does not reach it.
`Config.RARITIES`/`RARITY_ORDER`/`RARITY_BANDS` are unchanged and still four
tiers — skins are the one catalogue in the shop that only ever lands on three
of them (§9).

**`og` and `animal` do not share odds.** `og` draws `common 52 / rare 44 /
legendary 4`, the middle rung absorbing what used to be split between `rare`
and `epic`. `animal` is eight painted coats and one legendary — `stormwolf`,
the only skin on that shelf built through the tier's own alpha pass, and, as
shipped, still *wearing paint rather than its coat*: its baked sheet is built
but not uploaded, so it renders as body/trim colour plus a `flicker`
animation until `Config.skinSurface` has a pack to point it at — so the shelf
has no `rare` skin in stock at all and is priced `common 96 / legendary 4`
instead, holding legendary at the same 4% `og` sells: `Config.chestPool`
drops an unstocked tier and `liveOdds` renormalises the rest, so the `44%`
`rare` slice would otherwise have fallen onto `legendary` and repriced the
shelf. The tier crates retain their `odds` and rare `floor`; the Acorn price
ladder lives in `Config.CHESTS` and master-plan section 6. Neither the pools
nor the odds change with the currency conversion.

The Crates cards draw `Theme.acornPrice` and compare their price only with
`data.loot`. A short balance shows `Config.acornShortfall`: the missing amount
and the tree-shaking route. Pressing the card can request the same refusal
from the server, which checks the current balance before rolling. The hint
has two lines of space. Tree earning itself remains pending Phase 2; this
incremental workspace change is not a completed economy release.

**`Config.COMBINE.need` went from 3 to 5.** Losing the epic rung made the tier
just below legendary far more abundant — 12% of a roll to 44% — which made
combining 5.1× cheaper than rolling a legendary directly, against the
four-tier game's ratio of 2.4×. Five spares of a tier restores that ratio
rather than turning the top of the ladder into something assembled instead of
rolled for.

`Config.chestPool(key)` returns the stock grouped by tier. A `kind = "set"`
chest — only `alien` today — resolves through `Config.SETS` and
`Config.catalogueFor` instead of scanning a catalogue for a `chest` tag,
because a set spans five catalogues at once; every other chest today is a
plain `skin` scan — `Config.ACCESSORIES` is retired and empty (§9), and the
`gear` chest that once drew from it went with it, though the `chest`-tag scan
still supports `accessory` as a kind for whichever catalogue next wants one.
Crate skins have explicit rarities and no coin purchase `cost`. Historical
resale limits live in `sellBasis`, read only by `Config.sellValue`; all 24
moved values preserve their previous sale amounts. The skin service refuses
unowned crate skins on a direct coin request (§9).

**Unlike the roll, a chest can return a duplicate on purpose** — that reverses
the collection rule stated in §9. A duplicate becomes a **spare** of that
*item* in the same reveal rather than a dead outcome — `data.spares` is a
count **per item**, keyed `"kind:key"` (`Config.chestEntry(chestKey, entry)`
is the one place that knows the grammar both ways — a bare key for an
ordinary chest, `"kind:key"` for a `kind = "set"` one — and `ChestService`'s
own `entryKey` builds a spare's storage key the same way), not a counter per
tier. `Config.COMBINE` still pools spares **by tier** when combining — any
`Config.COMBINE.need` commons fund a higher-tier roll, whatever items they are — so a duplicate out
of a finished chest is still fuel for one barely started, with a small chance
of climbing two or three tiers in one combine. **Combining spends spares into regular Acorn crates**, never into `alien`.
`Config.canCombineChest` distinguishes regular crates from event sets rather
than inferring eligibility from currency. `ChestState.canCombine` carries
that decision to the card; the service checks it again before consuming spares. Effects have no chest: there are too few
priced tiers to spread across rarities, so effects stay direct-purchase.

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
spares alone are not saved per-sale, same as a chest open, see §13). A sale
that would overflow the pig's capacity is **refused outright, never clamped
and never partially filled** — the "spend it or lose it" pig rule (§4) applied
to a payout instead of an accrual.

**`alien` is the first event chest**, bought with Acorns and
drawing on the same alien **set** (§8) that loot already unlocks item-by-item
— a `kind = "set"` chest is a gamble sitting *beside* the guaranteed Acorn
price, never a replacement for it. Duplicates from it still produce spares,
which is a small thank-you for attending; those spares can be **sold** but
cannot be **combined** back into `alien` — only into a regular crate.

**A chest can also arrive as a free delivery instead of a purchase.** Day
seven of the daily ladder (`Config.DAILY_CYCLE`) owes the claimer a chest
rather than opening one on the spot — `data.daily.crate` (schema 22, §13)
holds the `Config.CHESTS` key until the player actually walks to their own
doorstep and presses the prompt there, at which point `DailyService.openCrate`
clears the field, saves, and calls the same `ChestService.grantFree` a claim
would otherwise have called directly. Moving the reveal off the claim button
and onto a box on the lawn (`PlotService.setCrate`/`.setCrateOwner`, painted
in the chest's own `colour`) is what gives the one rung on that ladder which
pays something *playing cannot* a moment of its own, rather than firing while
the player is still looking at the daily board. It survives a disconnect
between the claim and the walk by design — losing a seven-day streak's reward
to a dropped session would be the worst thing that ladder could do.

**`ChestService` is wired end to end.** Opening, combining, selling and
seasonal skin buy-back are reachable through the shop/inventory. The
`ChestOpen` / `ChestCombine` / `SpareSell` / `SkinBuyback` / `ChestResult` /
`ChestState` remotes are live, `Main` starts the service and registers
`EconomyService.push` and `CosmeticsService.push` as its balance pushers, and
`data.spares` is a real save field (`Config.SCHEMA_VERSION` 18).
`Shared/Crates.luau` (§14) fires `ChestOpen` from a real card button and
renders `ChestState` / `ChestResult`; **`Shared/Inventory.luau`** (§14) — the
one place a player can see every spare they hold, since a chest reveal shows
only the one item just opened — fires `SpareSell` from a real card button.
The Crates card's combine chips call `ChestCombine`; event-set cards hide
that row. An Acorn purchase pushes both the crate state and currency balances.
The existing `data.loot` balance is used directly, with no save migration.

`Config.isSellable` does not know which catalogues can actually carry a
spare — it admits anything with a coin `cost`, so a ride or a decoration
(neither of which any chest can ever duplicate) shows a SELL button too, and
selling one is a genuine, un-refused last-copy sale through the same
`SetService.revoke` path a skin or accessory uses. Recorded as a known gap in
§17, not fixed.

### Residential Acorn oaks, carry baskets and storage

`Shared/AcornTree.luau` loads the two uploaded meshes from
`Config.ACORN_OAK_MESH` once and clones them into each residential plot after
its final rotation. The source is `assets/tree/blender/oak.glb`, imported by
the designer at 8.5 studs wide and about 9.25 tall. Studio-measured offsets
preserve the imported assembly; `treeScale = 1` avoids shrinking it twice.
Both meshes keep a white tint and the shared baked palette.

`PlotService` seats the ground pivot at `ACORNS.treeOffset`, with the lawn
surface height. A hidden lower-trunk collider is the sole physical/query
part; visual roots, branches and foliage do not create a bounding-box barrier.
Shops use a separate builder and receive no tree. `lawnI` is reserved; existing
save reconciliation shelves placements there while retaining owned ornaments.
The remaining eight lawn slots continue to work.

Studio Edit fixtures verified asset loading, grounding, both street-row
orientations, fence-line clearance and trunk/open-space raycasts. Full in-game
visual/walk-through checks remain pending.

`Shared/AcornBasket.luau` supplies the imported woven **carry basket**.
Residential lawns now have an open `AcornStorage` crate at (-20, 16), beside
the oak. The imported four-mesh `AcornStorageCrate` is 3.6 wide × 2.8 deep ×
1.9 tall. `Config.ACORN_STORAGE_MESH` stores its uploaded IDs and measured
assembly; the builder caches templates and retains the old invisible floor
for prompts and fill. A complete wooden fallback handles asset-load failures.
Source art and import measurements are in `assets/crate/`. Shops have neither
tree nor crate.

**The tree ladder (step 2.7).** A tree grows at the rate of its saved level
(`data.tree.level`, `Config.TREE_LEVELS`: 1.0 / 1.25 / 1.5 / 2.0 / 2.5 an
hour for levels 0–4) and holds as many ripe acorns as the **best house the
player owns** allows (`Config.TREE_HOUSE_GATE`: Common 8, Rare 12, Epic 16,
Legendary 24). The same gate decides how high the ladder may be bought
(Common to 1, Rare 2, Epic 3, Legendary 4). A house never adds a tree or
acorns per hour. Rungs are coin-priced and bought from the owner-only
**Grow Tree** prompt (J) on the oak, or `TreeRequest`; `TreeService` settles
growth at the old rate before charging, refuses by name without charging,
and redraws the oak (a placeholder height stretch until brief B5) and the
offer. A house purchase refreshes the offer. Rebirths add 3% each to growth
**while online only**, capped at +60% (`Config.TREE_REBIRTH_BONUS`).
`Config.growAcorns(data, now, online)` reads all of it off the save, so a
resident's stock (no level, no houses) grows exactly as before. The level
survives rebirth. `auditAcorns` checks the ladder and gate; `auditEconomy`
prices the rungs against the largest pig. Over the owner's own oak,
`Shared/TreeClock` shows ripe count against cap and the time to the next acorn
(or FULL), counting down to `TreeNextAcornAt`, which the server publishes
(`PlotService.publishTree`).

Trees grow one Acorn/hour up to eight ripe at level 0 with a Common house, online and offline. Saved
`treeAcorns` is independent of banked `loot`; a stored balance of 200 does
not stop a tree growing. Existing wallet balances remain banked unchanged.
`acornsGrownAt` preserves partial hours; full-tree time cannot be banked.
Shaken Acorns move into saved `groundAcorns` with `acornsDroppedAt`, and
expire after 60 seconds. A round started near expiry gets its full duration.

`AcornFill` uses the imported Nut/Cap/Stem asset for ripe tree Acorns, fallen
ground Acorns and bounded crate contents. The crate always displays the
exact stored count, including zero and values above eight; PACKED is gone.
The HUD/spending systems continue to use `loot`. Imported assets are archived
under `assets/acorn/`. The renderer handles late/removed props and plots.

### Carry ownership

Every successful pig or basket attachment records `claimant` (the original
player who grabbed it) and `holder` (the player whose character carries it).
Later crack slices and Acorn catches retain that record. Both delivery entry
points validate the holder against the requesting player and read claimant
before settlement. Original-holder payouts are unchanged. Missing claimant or
mismatched holder leaves escrow intact. Completed tugs transfer the same carry.

`DeliverRequest` remains an empty request. The server checks a living carrier,
current position, activity and destination ownership on every press. Coins use
the pig's existing plot drop-off; Acorns use the storage crate. Both check
vertical distance. A newly occupied resident/player property cannot receive
an old victim's return.

- **Keep at home:** claimant receives the existing normal/revenge/spree coin
  payout or Acorn multiplier. Other holders get floor(raw amount ×
  `NAB.keepShare`) with no multipliers, plus the whole item haul. Keeping
  counts one getaway; Acorns never inflate coin statistics.
- **Return to the victim:** full raw coins and items are restored. Acorn
  receipts restore their original storage or ground source. The delivering
  non-claimant gets floor(raw amount × `NAB.bounty`) in the same currency.
  No robbery/revenge bonus is awarded. Own harvests and claimant undos pay no
  bounty. A victim bringing their own intercepted haul home always returns it.
- **Nabbed again:** claimant and receipts persist; the final holder decides.

The final keeper becomes the victim's revenge target. If an in-flight skin
recovery is intercepted, its original recovery owner gets the claim against
that keeper; insured recoveries never create a spare for an interceptor.
Unrelated owners' claims remain independent. Carries are consumed before
item grants can yield, so repeated requests cannot repeat payouts/refunds.

`CarryDelivery` formats server-owned choices for `LootHaul`'s destination card.
It names both drop-offs and rewards, handles item-only carries, and offers
KEEP/RETURN only for the current location. The card replaces the old RUN HOME
banner and hides during crack/collection minigames. The server also refuses
settlement during those activities. Touch and the existing F action use the
same empty request.

### Timed Acorn collection and storage raids

Hold H (gamepad Y) at any residential tree for half a second. One ripe Acorn
is enough to shake; an existing loose pile can be collected again. A
five-second panel represents the ground pile: drag as many Acorns as you can
into your basket. All remain available through the timer. Missed Acorns
stay on the ground briefly, while newly grown stock remains on the tree.
Owner harvesting is free of alarms, theft cooldowns and loss limits. Owners
can retry leftovers with a basket from the same tree.

Hold J (gamepad X) at another property's crate for a storage raid using the
same timer. It offers max(1, floor(stored × .25)), limited to four net Acorns
per victim in a rolling hour. Misses stay in the crate. Tree theft offers
loose stock independently of the storage loss limit. Both theft sources
share owner notification, dog response,
shield/sneak drop and owner-interrupt checks. Own storage cannot be raided.

Every catch is server-checked by attempt, unique index, timer, position,
character state and current plot occupant. Concurrent attempts reserve the
available supply. Catches enter carry escrow, not spendable storage.

Bring the basket to your **own crate** and use DELIVER to bank it. Your own
harvest pays one-for-one and never increments robberies or creates revenge.
Stolen Acorns retain the resident x1/player x5-plus-rebirth-gap payout,
doubled for revenge, at deposit only. Coin boosts/statistics remain separate.
Failed carries refund raw Acorns to their original source; tree refunds
return to the ground with a fresh collection window. Death/departure refunds
settle before the final save. Imported carry contents show up to eight.

### Resident Acorn supply

Residential NPCs start with **two ripe Acorns and two stored**, four total.
`ResidentAcorns` retains one stock record per plot per server; the resident's
coin haul `.loot` is unchanged. Trees grow at one/hour, up to eight ripe,
independently of the stored balance. A crop starting on an empty tree stays
available for fifteen minutes, then a resident at home banks the ripe stock.
Loose ground or a live collection lease postpones harvesting. This is a
server stock transfer, with no new NPC harvesting animation.

A valid round opening starts a **shared fifteen-minute cooldown** across
both resident sources and every thief. Player-target Acorn cooldown remains
60 seconds per thief/victim. Empty/out-of-range refusals start no timer.
Both resident prompts show an hourglass and Steal ready in m:ss nearby and
return to their stock counts when
ready. Existing resident coin raids keep their original cooldown.

Player occupancy freezes resident growth/harvest clocks; releasing the plot
resumes the same stock and partial hour. No repeat seed, hidden tree growth
or transfer of resident stock to the player occurs. Real-time raid/ground
expiry continues, and delayed old receipts refund the retained resident stock.
Shops have no stock or Acorn interactions. Initial stock resets only with a
new server. Live input/carry visual review remains pending.

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
refreshes it after coin/Acorn getaways, and clears it on release. The name,
rank and existing boasts have separate rows; shops/residents show no rank.
Phase 4.1's isolated renderer check verifies one star at 99 and two at 100;
settlement tests cover coin, Acorn and skin-only threshold crossings. Native
Studio rank-zero loading and text bounds pass; final visual review remains open.
Save/rejoin and rebirth checks use isolated data; live persistence is unverified.
Phase 5 narrows the rank row to seat the season chip beside it (below).

### The season (Phase 5)

**Season rank is Acorns *earned* this season, and `SeasonService` never mints
one.** A season is the same `Config.seasonIndex` the buy-back claims already
use (`Config.SEASON.weeks` active weeks plus `Config.SEASON.rest`), numbered
from `Config.SEASON.first` by `Config.seasonNumber` — an earlier index is
pre-season. `Config.seasonActive` is true only in a numbered season's active
weeks; in a rest week or pre-season `SeasonService.earn` does nothing.
`HeistService` calls `earn` with Acorns it has *already banked*: a delivered
basket (in practice the owner's own-tree harvest, since acorn theft is off,
§8) and a delivery's pig-crack acorn. Refunds, grants and admin gifts do not
count — only the `seasonearn` dev command goes through `earn` directly (§16).

**The save and the lazy rollover.** `data.season` is `{index, earned, tier,
best, granted}`. `SeasonService.state` rolls a save carrying an older index the
first time anything reads it — `earned`, `tier` and `granted` reset, `best`
(the highest tier ever reached) is kept — so nothing runs at the boundary, the
same shape as the weekly street-board pages (§14).

**Tiers grant once per season.** `Config.SEASON.tiers` is a ladder of `need`
thresholds (`Config.seasonTier`), each with one `reward`. When `earn` crosses a
tier, every tier reached and not yet in `season.granted` is marked there
*before* its grant, so a re-entrant call cannot pay twice; the sign is
refreshed, trophies are re-asked and the player is saved. Reward kinds:

| Kind | What happens |
|---|---|
| `finish`, `plinth`, `kennel`, `catch` | `SetService.grant` (which now knows the `finish`/`plinth`/`kennel`/`coat` ownership tables; `Main` registers `CosmeticsService.push` as their pusher). Already owned: announced and skipped — never converted to Acorns |
| `finish` keyed `"season"` | resolved by `Config.seasonReward` through `Config.SEASON.finishes[number]`, the season's never-sold-again exclusive; a season with no row warns and grants nothing rather than repeating last season's |
| `trophy` | `TrophyService.recheck` — the Season Cup reads `season.best` (§9) |
| `sign` | a word on the plot sign's season chip |

**Finishes** (`Config.FINISHES`) are the season's own cosmetic: an *addition*
over a skin, never a repaint and never a particle aura — a `reflectance` added
to the skin's own, Neon `eyes`, and/or a dim `light` on the pig's spare
`AuraLight`. Every row carries `season`, which `Config.isEarnedElsewhere` now
reads, so no finish can reach a crate, a sale or a free fallback; `season = N`
marks season N's exclusive. Owned in `cosmetics.ownedFinishes`, worn in
`cosmetics.finish`. `PiggyBank.applyFinish` runs after the skin and effect
repaints (which reset what it adds) and skips a shop vault;
`PlotService.applyFinish` remembers `plot.finishKey` and re-applies it after
every skin repaint; `CosmeticsService.applyToPlot` puts it on last.
`CosmeticsService.equipFinish` (`CosmeticRequest` kind `"finish"`) toggles an
owned finish and refuses an unowned one by name. The cosmetics push carries
only *owned* finishes, drawn on the Inventory's Finishes tab (§14).

**The plot sign.** The rank row carries a **season chip**
(`PlotService.setSeasonChip`; text and colour from `Config.seasonChipText` and
`Config.seasonChipColour` — hidden below tier 1, the colour climbing the rarity
ladder, the season's words from the top tiers). Under the boasts, a
**NEMESIS** line (`PlotService.setNemesis`) names who has robbed this player
most this season; while it shows, the boasts give up part of their height.
`SeasonService.refreshSign` writes both on join, on a tier crossing and on a
new ledger entry; `PlotService.release` clears both and the finish. Neither
layout has been checked in Studio.

**The nemesis ledger.** `data.nemesis` is `{index, rows}`, rows keyed by the
thief's UserId (`name`, `count`), rolling with the season index like
`data.season`. `SeasonService.recordNemesis(victim, thief)` is called from
`HeistService.deliver` when the victim is a player; at `Config.NEMESIS_ROWS`
the smallest row is dropped for a new one. `nemesisOf` returns the top row.

**The season board.** One `OrderedDataStore` per season, named from
`Config.SEASON_BOARD.store` and the index. A player's total is published when
it changed, on the service's loop and on leaving; the loop then fetches
`pages` × `pageSize` sorted rows at most every `refresh` seconds and pushes
every player `SeasonState` — season number, whether it is active, earned,
tier, what the next tier needs, the season's end in server time, and the rows
from `SeasonService.window`: `above`/`below` rows around the reader, or the
top of the list plus a "you" row when the reader is outside the cached pages.
`SeasonService.getTop` feeds the shared season page of the street board (§14).

**Audited at boot.** `Config.auditSeason` checks that thresholds climb, every
promised reward exists, every season-exclusive row is flagged for its season,
and every finish is unpriced, season-only and under a light-brightness
ceiling; `Main` warns per problem.

### Acorn and random-outcome boot audits

`Config.auditAcorns` checks finite growth/payout/resident parameters, whole
bounded seeds, valid raid/harvest cadence, population/share/storage caps,
one-offline-window tree growth, crate prices and the existing modeled
population/active-to-passive thresholds. Coin boosts/events do not feed Acorns.

`Config.acornRates` now counts each freshly grown Acorn once. With full capture,
parity theft and no losses, the **new-growth-only** banking scenarios are
10 solo / 5.25 full per player-hour. Full-capture own harvesting instead gives
1.25/full. Initial resident seeds and re-raids of existing storage are excluded;
these are neither observed earnings nor ceilings on all sources of income.
The illustrative daily audit adds an eight-Acorn overnight harvest and assumes
one two-Acorn storage loss: 6 passive, 28 solo active, 18.5 full active, ratios
4.67x/3.08x. See master-plan §17 for limitations. No payout/price changed.

`Config.auditRandomOutcomes` checks Acorn crate currencies and whole positive
prices, both authored coin-price/crate tags and actual pools, pass exclusions,
100% eligible skin theft, retired rebirth gates and the rebirth crate reference.
The designer-approved rebirth reward still rolls a standard Legendary Crate.
`COIN_PACK.productId = 0` reserves a disabled future integration point; setting
it live warns about the random rebirth reward. No product is currently sold.
Main prints model figures, warns per violation and catches audit exceptions
without stopping startup. The 185 isolated audit tests provoke every rule,
verify reward services/boot warnings and preserve all affected resale values.
Live boot/event/persistence checks remain pending.

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
rename would touch — now names **Acorns**.

**Acorns are being introduced in master-plan steps 1.1–1.2.** Piggy
cracks and smashes deliver coins and carried items, never Acorns, including
revenge and sprees. `Config.LOOT.delivery` and `Config.REVENGE.loot` are
retired. Legacy event payouts remain pending the Phase 1.9 faucet audit;
the tree and shake earning path belongs to Phase 2 and is not built yet.
`Config.acornMultiplier(thiefRebirths, victimRebirths, revenge)` is ready
for that path: nil victim means a resident (x1); a real player starts at x5,
adds one per rebirth above the thief, then doubles for revenge.

**Balance and presentation:** `SetService.award` credits the existing
`data.loot` field and pushes `SetState`. `PiggyPanel:setAcorns` renders that
balance in a compact chip beside the event timer. `Theme.acorn` draws the
approved brown nut, green cap and cocoa outline without images or animation;
shop prices and all crate cards use the same glyph.
`Config.lootWord(n)` supplies singular/plural wording. Existing balances
are preserved; no save migration is needed for this rename.

**Where the numbers live:** `Config.ROLL_CURRENCY`, `Config.LOOT`,
`Config.ROLL_BASE_COST` / `ROLL_GROWTH`, `Config.CHESTS` / `Config.COMBINE`,
and `Config.SELL` (spare sale value).

---

## 4. The economy

### The ladder

Income and capacity are each a purchasable level. Both run on **three bands**:

- **Levels 1–20** keep the original growth untouched — that curve was never the
  problem.
- **Levels 21–40** are gentler on both sides, because one curve extended to 40
  fails in both directions (too-fast income trivialises the game; too-fast cost
  means nobody buys the top).
- **Levels 41–60** (`BAND_TOP_2`, `CAPACITY_GROWTH_C` 1.136, `INCOME_GROWTH_C`
  1.10, band-B cost growth) exist so a 1B house fits a pig: the top pig is
  ~1.24B and 1B sits at 80% of it. Nothing below level 40 changed. Derivation
  and pacing in `docs/LATE-GAME-ECONOMY-PLAN.md`; pinned by `tests/luau/ladder.luau`.

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
produce is 96.9M and the old price was not slow, it was impossible. Since
schema 26 it also refuses a house row with no `id`, a duplicated `id`, or a
`Config.HOUSE_LEGACY_ORDER` entry missing from the live catalogue — the
migration list and the catalogue must never disagree about which ids exist.

**Read the ceiling through `Config.maxLevel(rebirths)`, never from a constant.**
It is `20 + 2 per rebirth`, capped at `ABSOLUTE_MAX_LEVEL` (60, reached at rebirth 20 — `Config.rebirthsToMax()`). `EconomyService` pushes its answer as
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
- **The income factor is `Config.rebirthIncomeFactor`**: +0.12 per rebirth through
  rebirth 10 and +0.08 beyond (`REBIRTH_MULTIPLIER_TAPER`), so the top of the game is
  3.0× rather than 3.4×. The rebirth page and toast read `rebirthBonusPercent`.
- **Every rebirth opens a standard free Legendary Crate**, through
  `ChestService.grantFree` and `Config.REBIRTH_CRATE`. Its ordinary rare/legendary
  odds apply, and an owned result pays a spare. It does not select the next
  unowned skin, and it leaves the equipped skin unchanged. When
  `Config.rebirthCrateComplete` finds every legendary in that crate already
  owned, the reward is its Acorn price instead. Exclusives outside the crate
  do not count toward completion. The old rarity roll, pity timer and coin
  fallback are retired.
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
- **The explainer page comes BEFORE the button, on the first rebirth only.**
  Shown afterwards it would be a receipt, not a decision. `Shared/Rebirth.luau`.
  Its three panels are deliberately three different shapes:
  **YOU LOSE** is exact — the player's real coin figure and their real upgrade
  levels, because a loss is somebody's actual afternoon; **YOU KEEP** is five
  fixed lines stating the *rule* (cosmetics, house, worn items, rides, stars all
  survive) rather than counting today's inventory, because a promise has to be
  total and a count read off a stale push can disagree with the server; and
  **YOU UNLOCK** is a row of rendered tiles rather than sentences — a drawn coin
  for the income step and a drawn Legendary Crate, or an Acorn glyph and
  the fallback amount when the legendary collection is complete. It refreshes
  the reward when a cosmetics snapshot changes while the page is open.

### Offline

Capped, in `Config.OFFLINE_CAP_SECONDS`. The friend bonus does **not** apply to
offline accrual — your friends were not in the server while you were asleep.

### Full

Income stops at capacity and there is no bank to empty the pig into. The way
to make room is to **spend** — or to be robbed. **Nothing puts more in a pig
than it holds** (`Config.fitInPig`, MASTER-PLAN 4c.6): a robbery delivery, the
return bounty, a shop-drop resale, a daily coin reward and an event payout all
bank only the room that is left, and the rest **spills** — named in the toast
and, for a delivery, on the summary card (`HeistDelivered.spilled`). The
victim still loses the full amount, and bail, the rap sheet, `totalStolen`,
the weekly board and the pig-crack acorn are all measured against that. Coins
coming **back** obey the same cap: a refund, a returned carry (nab, dog,
patrol, voluntary return — all through `HeistService.giveBack`, and
`ResidentService.refund` for a resident) and a drone recovery bank only the
room left and name the spill. Every street figure is what the reader can
actually carry home (`Config.homeTake`: a clean crack's take x the event
multiplier x `HEIST_PAYOUT`, capped at the reader's own room): the rob badge
(reads **PIG FULL** when there is no room), the steal card and the smash card
(**FULL**), and the "worth X at home" line that ends a crack or a smash
(`homeWorthPhrase`, which adds revenge and the spree).

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
street) and no garden; `ResidentService.applyLevel`'s `plot.shop` branch
ladders only its **Vault Lock**, the one defence that is still honest on a
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
to on the loud paths — a **missed crack slice** or a **smash** — and never to
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
prompt, the rob badge, the fill, the dial, the plaster, the alarm) runs
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
distance — for a smash exactly as for a crack; both share this test.** A
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
one, and **never on a smash** (above) — a smash's cycle is a fraction of a
crack's, and rolling it there would make smashing the cheapest drop farm in
the game. PIGGY OUTFITTERS, HOME & GARDEN and WHEELS & KIT drop an unowned
skin/effect, decoration or ride respectively, through
`SetService.grant`, weighted on `Config.RARITIES`. LOCK & KEY sells upgrade
*levels*, which cannot drop, so it drops a **consumable** instead — bones and
gadgets weighted by the inverse of what they cost, so the plunger and the dog
bone turn up often and the Golden Bone is a rare prize rather than a faucet.
`HeistService.registerStockPusher` is a registry `Main` fills with
`BoneService.push`/`GadgetService.push`, so a dropped consumable reaches the
hot bar the same push cycle it lands in.

The per-shop chances are **10% Piggy Outfitters, 8% Home & Garden, 3% Wheels
& Kit, and 20% Lock & Key**. Wheels & Kit also requires robbery rank 2
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
nothing; a full pig sells it for nothing and says so. It pays coins rather than a **spare** on purpose: a
spare is `Config.COMBINE` fuel, and a shop drop that produced one would be a
way to farm combines by robbing rather than by opening chests — the same
arrow this design already refuses to run backwards for the `alien` chest,
above.

Together, `Config.RESIDENT_FLOOR` — the four shop vaults plus the two
guaranteed resident houses, six victims — is the non-player supply that never
runs dry, at any population.

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
street, never a rung in the middle of it. Those three figures are the
**houses-only** case they were originally derived from and still reproduce
exactly; with the shop vaults in the mix, `robberyRates` returns the weighted
mean of both target classes, so the mixed step reads lower than the
houses-only one — the conclusion is unchanged, because +1 still clears or
sits on `ROBBERY_ADVANTAGE.max`, which is also the population `auditRobbery`
itself measures at (above), so guaranteeing one keeps the audited street and
the real one the same street. A richer resident also carries a fuller
**garden**: a shuffled, per-resident order over every lawn-zone key in
`Config.DECOR_ITEMS` (`rollGarden`), planted as a growing *prefix* of that
order as the resident's level climbs (`decorPerLevels`/`decorMax`, the same
per-level shape as its fence/dog/lock/house ladders) — so a bare lawn reads as
the bottom of the street and a crowded one as the best-paying, best-defended
plot on it, readable before a thief ever crosses the road.

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
   **Sneakers** offence rung (below — it buys *speed* for the approach, never
   stealth; which dogs a given tiptoe still wakes is the dog tier's own
   `notice`), and refused outright while carrying or climbing (either
   combined with a tiptoe would let the getaway itself go quiet). It plays as
   its own gait now, not the ordinary walk cycle slowed down —
   `Shared/SneakWalk.luau`, a looping animation published **per viewer** off
   `Config.SNEAK_ATTRIBUTE` (on the character, not the `TiptoeState` remote,
   which only ever told the sneaker themselves) and rate-driven by the
   character's own measured horizontal speed rather than a clock, so the
   Sneakers rung, a fence snag and a stun are all inherited with no balance
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

   **Or smash it.** `HeistService.smash` is the loud, fast alternative into
   the same pig — a second prompt card (`G`) live on the piggy at the same
   time as the crack's, because a choice you cannot see is not a choice. It
   shares every gate the crack does (`whyCannotSteal`, the shop-room rule,
   the per-victim cooldown, the loss allowance) and none of its patience: one
   `Config.SMASH.hold`-second hold (1.3s, half a dial sweep) takes a **fixed**
   share of the pig straight out — `Config.getSmashFraction(sack)`, which is
   `Config.getCrackFraction` evaluated at `Config.SMASH.steps` (two), so
   Bigger Sack (below) scales it exactly as it scales a crack. There is no
   lock involved at all — a Vault Lock does nothing to a smash — and it
   **always** sounds the plot's alarm and releases the guard dog the instant
   it lands, before the thief has taken a step, where the crack's alarm above
   is fumble-only. A completed smash never rolls the shop's item drop
   (`Config.SHOP_VAULT_DROP`, below); that stays a crack-only roll, or a
   smash's much shorter cycle would farm it. The coins land as carried loot
   exactly like a crack's banked total, so steps 3 and 4 below apply
   unchanged. *Orientation only:* a smash pays about half a clean crack's
   coins-per-second on a house and about three-quarters on a shop — strictly
   less either way, by design, so the crack stays the better rate and a
   smash is chosen for being unmissable and quick rather than for the money.
3. **Carry.** You move at `CARRY_SPEED_MULTIPLIER` of base, and a banner says so
   to the whole street. The thief is posed **holding** the mini piggy — both
   arms wrapped round its flanks, torso leant back to counter the load — rather
   than jogging along behind one welded stationary in front of them with their
   arms at their sides. `Shared/CarryPose.luau` (§2, §10) drives only the
   torso, head and arms, so the ordinary run cycle keeps the legs underneath
   it unmodified; `HumanoidRootPart` and `LowerTorso` are named in the pose
   purely as the path to the arms and carry `Pose.Weight = 0`, which is what
   stops them freezing the pelvis. `HeistService.attachLoot` seats the model
   at `CarryPose.HOLD`, a CFrame in root space, instead of the flat offset it
   used before the pose existed — the hold position and the pose are one
   measurement now, not two that could disagree. Every client poses every
   carrying player it can see, not only its own, by looking for a child named
   `Config.LOOT_MODEL_NAME` on that player's character; there is no attribute
   and no remote for it, because the loot model's presence already answers the
   question. Rides are disabled **server-wide** while loot is in transit —
   otherwise a bystander on a scrambler runs down a thief on foot.
4. **Deliver** to your own drop-off, or get **nabbed** — a completed tug
   transfers the intact carry to the winning player (below).

**A dog that has been alerted — woken by footsteps, a missed slice or a smash,
it is the same release every time (`HeistService.releaseDog`) — branches
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
of 80, so the shortest getaway is 53 studs, about 4.4 seconds at carry speed. It
was 37 studs and 3.1 seconds before the plot widened, so the rule holds by a
wider margin now rather than a narrower one — but a longer run also hands an
alerted Titan at 17 more time to close. **If robbing ever reads as too hard,
`DROPOFF_RADIUS` is the lever**: it is a fraction of your own plot rather than
an absolute, so it can grow with the plot.

**A completed player nab transfers the intact carry.** The initial
`Config.NAB.hold` opens or joins one tug per holder. Each `tickRate` interval
advances progress toward `recoverSeconds`; a crowd divides contribution
credit without speeding it up. No coins or Acorns leave escrow during a tug,
and no bounty is minted. A haul containing only a skin still takes the same time.
The ongoing crack/collection round closes when the tug starts.

At completion, the greatest contributor who is still alive, nearby and
empty-handed wins; equal contributions use join order. Busy, missing or
out-of-range players cannot receive the carry. The same loot model, prompt,
haul and Acorn receipts move to the winner's character; claimant and victim
stay unchanged. The loser loses the carry slow without being stunned. The
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
Sack — or the single fixed take of a smash (`Config.getSmashFraction`,
above), taken out of their pig the instant it lands rather than promised for
later (two thieves working the same pig can't both be promised the same
coins). The thief banks that running total times `Config.HEIST_PAYOUT` on
delivery — the extra is minted by the game, which is what lets robbing be the
best earning rate on the street without a robbery being devastating.
Deliveries pay **zero Acorns**, including revenge. Robbing somebody who
robbed *you* inside `Config.REVENGE.window` pays `Config.REVENGE.payout` times
the coins instead; the marker over their plot lasts
the same window. `Config.STEAL_FRACTION` survives only as the calibration
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
checks the current season, skin eligibility, ownership and Acorn balance on
the server. The price is the themed source crate's cost times `3^rank`, with
skin ranks common=1, rare=2, legendary=3: **15 / 45 / 135 Acorns**. It charges
before `SetService.grant` writes ownership; the normal grant save contains
both. No roll or spare is awarded, and the robber keeps their copy. The claim
persists through the season, hidden while owned, so duplicate requests cannot
charge again. Free recovery remains available inside its separate timer.

`Config.SEASON` is the claims' clock: active weeks plus a rest week,
anchored to the existing UTC `weekIndex` — and, since Phase 5, the season
rank and rewards on the same index (§3, *The season*). Requests reject
expiry immediately. Crate cards expire locally; a 30-second server rollover
pass clears/saves online claims, and reconcile prunes expired offline claims.
The recovery objective card (§14) is implemented. It reads private `RecoveryObjective` snapshots derived from the
actual haul, timed claims and current ownership. Before delivery it directs
the victim to nab the fleeing robber; after delivery it uses the claim's
wall-clock deadline for a countdown. This does not change the server's
monotonic recovery expiry. Expiry switches locally to the existing buy-back
price only while eligible. No client-supplied claim, timer or price is used.

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
spreeSteps, houses, tills)` is the one function underneath every sweep: it
models a thief working the whole street as the weighted mean of the two
non-player target classes — resident houses and shop vaults, `houses`/`tills`
optional and defaulting to the worst case (below) — against an hour of
standing still. The audit asserts the ratio sits inside
`Config.ROBBERY_ADVANTAGE` (a min/max band) and stays **constant** across the
whole game (a `spread` ceiling) — the same invariant `RESIDENTS.pigSeconds`
exists to pin, so a later change that lets the ratio drift (a resident's pig
re-tied to a growing curve, a crack step retuned, the getaway distance moved)
shows up here instead of silently — over every level/rebirth pair. **It sweeps
both ends of the spree ladder** — a *cold* thief (no run going, `steps = 0`)
against the band's floor, and a *hot* one (a maxed spree) against its ceiling
— because the two answer different questions (is robbing ever worth it; is
the best case a faucet) and measuring only one lets the other drift with
nothing to say so, which is exactly what a spree multiplying an unmeasured
payout would do.

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
player up to `MAX_PLAYERS`, walking `houses` down while holding `tills` at
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

*Orientation only — `Config` is authoritative.* Measured at level 20 across
population 1 → 8 (cold / hot spree): 3.80x / 7.60x at one player down to
3.37x / 6.73x at a full server, always clearing `Config.ROBBERY_ADVANTAGE.min`
(3.0) — 12% of headroom to spare at the worst population, down from 24% once
`Config.SHOP_VAULT_DISCOUNT` came down from 0.85 to 0.70 to pay for the
shorter run home a strongroom on the back wall costs a thief.

### Defence tree — buys time, never immunity

| | Effect | Ceiling |
|---|---|---|
| **Fence** | Slows and hazards a crossing | **Solid — the gate is the only free way across.** `Config.BASE_JUMP_HEIGHT` is **5.5**: tiers 1–2 (Rickety 3.6, White Picket 4.8) are jumpable; tiers 3–5 (Barbed Wire, Electric, Moat — all top 7.0) are not, and there is no built-in way over one. A gate (24 studs wide at tier 1, down to 8 at tier 5) always exists |
| **Guard Dog** | **Watches the lawn** (`HeistService.watchLawns`) and wakes for footsteps above the breed's `notice` speed, a **missed crack slice**, or any **smash**, always, the instant it lands; asleep-in-kennel vs. patrolling-awake is a visible tell for whether the owner is home. **Owner home: alarm only** — barks and marks the thief, never chases. **Owner away (always true for a resident): the enforcer** — chases and nabs a carrying thief, or scares off an empty-handed one | Beaten by bones, or a tiptoe kept under `notice` — a smash cannot be sneaked past, since it wakes the dog unconditionally rather than on being heard; three breeds with rising `boneResist`. A coat, a kennel skin, toys on the lawn or a name on the collar change none of this — see the wardrobe in §9 |
| **Vault Lock** | Narrows the crack's target windows (`Config.getCrackWindow`) — a smash (above) bypasses it entirely, there being no lock to pick | Readable from the street as a vault dial — a hatch in the piggy's back, with level 0 an open hole. Readable from *any distance* by a thief with maxed Lockpicks — see **casing**, below |

**A crack and a smash put different weight on these two rungs.** A smash
takes no time on the lock at all, so the Vault Lock is worthless against one
— the Guard Dog is the whole of what a smash has to get past, since a smash
always sounds the alarm and releases it on landing. A clean crack never
wakes the dog at all, so the lock is what actually slows *that* down. A
well-locked, undogged pig is soft to a smash; a well-guarded, unlocked one is
soft to a crack — readable from the pavement, because the dial says one and
the kennel's posture (awake or asleep) says the other.

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

**Lockpicks** (wider crack windows — a smash ignores this rung too, above),
**Bigger Sack** (bigger takes — scales every step of the crack and a smash's
fixed share alike, not a single flat take), **Speed Boots** (carry
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
`CRACK_ALARM_ON_MISS`, `SMASH` (`steps`/`hold` — `Config.getSmashFraction`,
the other way in, above), `STEAL_*` (including `STEAL_FRACTION`, the crack's
calibration baseline), `OWNER_INTERRUPT_RANGE` (an owner breaking up a crack
in person, above), `NAB` (`hold`/`distance`/`tickRate`/`recoverSeconds`/
`bounty`/`cooldown` — the tug, above; was `TAG_HOLD`/`TAG_DISTANCE`, two
constants, before it grew into a table),
`CARRY_SPEED_MULTIPLIER`, `HEIST_PAYOUT`, `LOOT`, `LOSS_CAP`, `REVENGE`,
`NEW_PLAYER_SHIELD`, `JOIN_SHIELD`, `ROBBED_MARK_SECONDS`,
`PLOT_ROBBED_ATTRIBUTE`, `BASE_JUMP_HEIGHT`, `LAWN_LIFT`, `CLIMB_SPEED_RATIO`,
`CLIMB_MULTIPLIER`, `LADDER`, `RESIDENTS`, `PLOT_RESIDENT_ATTRIBUTE`,
`PLOT_RESIDENT_ID_ATTRIBUTE`, `TIPTOE`, `SNEAK_ATTRIBUTE`,
`PLAYER_FIRST_JOB_ATTRIBUTE`,
`DOG_WATCH` (`pollRate`, `wakeDelay`, `alertSeconds`, `scareStun` — all live,
read by `HeistService.watchLawns`/`.scare`), `ROBBERY_ADVANTAGE` (the audit
above), `SPREE` (`window`, `maxSteps`, `payoutPerStep`,
`floorDropPerStep` — `getSpreePayout`/`getSpreeFloorScale`), `CASING`
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
dial (§5) · `G` smash a lock (§5) · `B` shop · `V` garage · `R` radio · `I`
bag/inventory (§14) · `Esc` close (also bails a crack, banking whatever it
has) · `F2` admin · `1`–`0` hot bar. A new binding gets checked against this
list and against whether it is genuinely exclusive with what it lands on.

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

**A nab (§5) does not touch either of them, even one that empties a thief
outright.** `SocialService.recordSteal`, `.markRevenge` and `.breakSpree` are
called only from `HeistService.deliver`; nothing in `nab`, `tugTick` or
`endTug` calls any of the three. Only an arrest breaks a spree.

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
(the flagship) and **Midnight Heist**.

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

**Midnight Heist** (`roster.midnight`, 180 s, weight 2; replaced Rush Hour
and the short-lived Harvest Moon on September 16). The street fades to a dusk
(`Config.MIDNIGHT_LIGHT`, `WorldService.setNight`, then the day table
`WorldService.DAY` — ClockTime 14.5 — is set outright; a night that errors is
restored by the scheduler). For its length every coin steal pays
`Config.MIDNIGHT.stealMultiplier` (2x, pushed as `EventState.stealMultiplier`
before the phase push) and a clean crack of a **player's** pig that ends under
it stamps `carry.acornMultiplier` (2x), so the pig-crack acorn is doubled even
if the carry is delivered after dawn. Residents and shops mint no pig-crack
acorn, so a solo player gets no acorn bonus. Measured shares: raid ~41% of
slots (every ~37 min), night ~59%. Admin panel: MIDNIGHT HEIST now.

**Acorn theft is disabled.** No roster row carries `acornTheft`, so
`EventService.isAcornTheftOpen()` is always false, `ShakeService.open`
refuses anyone's tree but the owner's ("Only its owner can shake this tree"),
and the client never shows the shake prompt on another tree. `auditAcorns`
(`theft.disabled`) refuses a row that re-opens it, and
`midnight.acorns` caps the night's acorn multiplier at 2. The
shake-another-tree and acorn-basket carry code stays in place, closed.

**Rewards:** the Alien Invasion pays its existing coin bounty (income-seconds,
1.5x on a cleared street) and one free unowned set drop per player present.
A full set receives a completion message with no additional item, spare or
currency. Midnight Heist rewards the boosted coin steals (and doubled
pig-crack acorns) made during its window; there is no separate attendance
payout. Events never award Acorns. The old
`Config.LOOT.event` attend/per-drone/clear/completed-set faucet is retired.
The coin bounty is capped at the room left in the pig and names any spill (§4).

**Sets** are a **view over the existing catalogues**, never a new catalogue.
`Config.SETS` lists `{kind, key}` pairs pointing at ordinary members of `SKINS`,
`EFFECTS`, `ACCESSORIES`, `DECOR_ITEMS` and `RIDES`. No new ownership storage, no
new equip path. **`set` is an exclusion** — it keeps set items out of the
crate pools and out of both free-if-costless fallbacks (it also kept
them out of the accessory roll, which is retired along with the rest of
`ACCESSORIES`, §9).

**Nothing is ever locked behind luck — except that the shop no longer sells
half of what it promises to.** Every set item still carries a loot price
(`SetService.buy`, remote `LootBuy`), and that is still the line that is
meant to make a spinner safe for a nine-year-old: bad luck costs a wait, never
the item. But `LootBuy` was only ever fired from a skin or an effect card
(§14), and both of those cards went with the shop's Piggy tab — so of the
alien set's four members (`crashedDrone` a decoration, `tractor` an effect,
`martian` a skin, `hoverdisc` a ride; down from six once the two alien
accessories were retired with the whole accessory catalogue), **the effect and
the skin currently have no guaranteed-purchase route at all**, and the Alien
Cache (§3) is the only way to either. The server-side guarantee is untouched —
`SetService.buy` still charges loot and grants correctly if the remote is
fired — so this is a missing storefront, not a broken rule, and putting one
back is one call site rather than a feature. **The wheel is free and must stay
free.**

---

## 9. Cosmetics

Roughly a hundred items across fifteen catalogues — the skins catalogue alone
is 45. **None of them confer anything.**
That is what makes them safe to price steeply, and it is why houses in
particular are pure prestige.

| Catalogue | Config | Bought with | Notes |
|---|---|---|---|
| **Skins** | `SKINS` | **crates**, including a free Legendary Crate on rebirth — a priced skin refuses a coin purchase outright, below | Animated skins are driven **on the client** from a `SkinKey` attribute. 45 skins, all carrying an explicit `rarity` of `common`/`rare`/`legendary` (§3) — 40 also carry a `chest` tag (31 `og`, 9 `animal`); the other 5 are the free default `classic`, Solid Gold, the two pass skins and the alien set's `martian` — none carries a `chest` tag, and `martian` instead reaches the Alien Cache through `set = "alien"` (§8) |
| **Effects** | `EFFECTS` | coins — **deliberately not moving to a chest** | Shop tiles *simulate* the real particle numbers — a ViewportFrame renders BaseParts and nothing else. The 5 priced tiers (15K–600K) land 3 commons and 2 rares on `Config.RARITY_BANDS` with no epic or legendary, so a chest would have no top end |
| **Houses** | `HOUSE_TIERS` | coins | A shelf, not a ladder: `CosmeticsService.buyHouse` will sell *any* unowned tier once its price fits the pig — no "buy the cheaper one first" rule. Each row carries a stable `id` (ownership key, saved in `data.houses.owned`) separate from its `style` (builder key); worn tier is `data.houses.shown`. Move back into any owned tier free, forever. Nineteen rows (revision 2): rows flagged `placeholder` stand `House.build`'s construction-band block until their builder lands, and residents only climb built rows (`Config.residentHouseLevel`). `goldenpig` has no `cost` and `earned = "houses"` — never sold, granted by `CosmeticsService.grantEarnedHouses` once every priced house is owned (`Config.earnedHouseProgress`) |
| **Decorations** | `DECOR_ITEMS` | coins, except the ten **trophies** — earned only, below | Auto-placed into slots; **slots are scarcer than items** on purpose — the trophies make that literal, since a trophy on display costs a slot an ornament was using |
| **Border plants** | `BORDER_PLANTS` | coins | Along the fence line (not a lawn slot — a run of plants down each stretch of fence). Height is clamped to the fence's own visible top (`Config.borderHeight`), below |
| **Garden paths** | `GARDEN_PATHS` | coins | Gate to piggy, laid flat on the lawn. No fence needed — the one garden item a bare plot can carry |
| **Window boxes** | `WINDOW_BOXES` | coins | Ground-floor windows only, hung by walking the built house for parts named `Sill` — a post-pass, not an argument threaded through nine house-tier builders |
| **Accessories** | `ACCESSORIES` | — **retired** | `Config.ACCESSORIES` is now an empty table — the fourteen piggy accessories, the roll, the `gear` coin chest and the shop's accessory section all went together, in one edit, because every reader in the game already went through this one catalogue. `PigGear.luau`'s builders are untouched (a retired item keeps its builder, the expensive half, and loses only its catalogue row), so putting any of them back is re-adding rows here. The alien set (§8) lost its two accessory members with it and is four items now, not six |
| **Rides** | `RIDES` | coins | Street only; a ride confers nothing else |
| **Player gear** | `GEAR` | earned only | Most Wanted escapes |
| **Stances** | in `RIDES` | **Robux (Style Pack)** | The one cosmetic shaped to be sold directly |
| **Dog coats** | `DOG_COATS` | coins | Repaints only `fur`/`furDark`/`collar` on a Guard Dog you already own. `scale` and `shape` — what a thief actually reads to price the risk — are structurally off limits; see below |
| **Dog kennels** | `DOG_KENNELS` | coins | Repaints only `wood`/`trim`. The roof always follows the *coat's* `collar`, never the kennel skin's own, so the two read as one dog's house |
| **Dog toys** | `DOG_TOYS` | coins | Not worn — placed on the lawn. Changes *where* the dog goes, never how fast, how far it hears, or whether a bone works; see below |
| **Finishes** | `FINISHES` | **season tiers only** — never sold, never in a crate | An addition over the worn skin (sheen, glowing eyes, a dim light), never a repaint or a particle aura. Worn from the Inventory's Finishes tab; see §3, *The season* |
| **Catch effects** | `CATCH_EFFECTS` | coins, or granted by the VIP pass (§15) | A one-shot burst that fires on the **thief**, not on you, the moment you nab loot back out of their hands — the third kind of cosmetic, worn by neither a piggy nor a player. Worn tab (§14); see below |

**Skins are crate-only now, which is a deliberate reversal of "nothing is
ever locked behind luck" for this one catalogue.** Most skins are no longer
a guaranteed coin purchase — they are a chest outcome only. A duplicate
becomes a spare rather than nothing, but there is no way to walk up to the
shop and buy the exact one you want. **Prices stay in Config regardless**:
`Config.sellValue` still caps a spare's payout at a fraction of the skin's own
`cost` — remove the price and the sell cap collapses. A skin's chest *tier* no
longer needs the price at all, now that all 45 carry an explicit `rarity`
(§3), but `Config.rarityOf` checks that field first for every catalogue in
the shop, so nothing about the derivation changed for anything else. Every crate now charges earned Acorns, and `ChestService` refuses any
other currency. Acorns have no Robux purchase path (§15).

**Applied at both ends.** `CosmeticsService.buySkin` refuses a coin purchase
by name — *"%s comes from crates now, not coins."* — for any skin that
carries a `cost` and is not already owned or free. There is no card left to
draw a price on any more: the shop's Piggy tab (once the one place a priced
skin was shown at all) is gone (§14), so the refusal is now reachable only by
a stale client or a poked remote, and it stays loud rather than silent for
exactly that reason. A skin is sold nowhere in the shop now except as a
Crates-tab chest outcome; the Inventory panel's empty-skins message — *"Open a
crate to start collecting skins"* — still agrees with that.

### The guard dog's wardrobe

**A coat is taste; the Guard Dog tree (§5) is power, and the split is
structural rather than a promise.** `Config.DOG_TIERS` carries `scale` and
the breed `shape` (`leg`/`girth`/`head`/`earDroop`) — the numbers a thief
actually reads to price the risk at the fence — and no coat or kennel entry
may reach either. `GuardDog.applyTier` is the *only* place any of it is
painted: a coat supplies `fur`/`furDark`/`collar`, a kennel supplies
`wood`/`trim`, and an empty `equipped`/`kennel` falls back to the breed's own
colours or the plain wooden kennel — the same toggle-to-remove convention
accessories and decorations use. **The kennel's roof always takes the
*coat's* `collar`, never a kennel skin's own** — so a bought kennel and a
bought coat read as one dog's house rather than fighting over who owns the
roof.

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
API, not to charge for it. The name replaces the tier's placeholder
("Scruffy"/"Rex"/"Titan") on the nameplate and is painted a second time onto
a `NameBoard` over the kennel door — but never touches the breed line under
it, which a thief still reads to price the risk regardless of what the dog
is called.

**Toys are the only dog cosmetic that changes behaviour, and two things stop
that mattering.** A `kind = "visit"` toy (Squeaky Ball, Water Bowl) is a
destination the dog sometimes takes instead of a random patrol point
(`Config.DOG_TOY_VISIT_CHANCE`, 45%); `kind = "sleep"` (the Dog Bed) is where
it lies down instead of its kennel doorway. Every one of those destinations —
patrol, toy visit, sleep — is held inside the fence by `GuardDog.clampToYard`
(§11), so no toy offset can pull a dog further from its post than an
ordinary patrol step already does; and a toy is silent, because the bark is
the "seen me" tell and a squeaking toy would be a bought object faking one.
What a thief reads from the pavement is unchanged either way — the sleeping
*posture*, not the location, is the tell.

### The garden

Three plot-wide catalogues — `Config.BORDER_PLANTS` (4 rows: Lavender Row
40K, Box Hedge 120K, Rose Bushes 350K, Sunflowers 900K), `Config.GARDEN_PATHS`
(4 rows: Gravel Path 25K, Stepping Stones 90K, Herringbone 300K, Marble Walk
1.2M) and `Config.WINDOW_BOXES` (3 rows: Geraniums 60K, Daisies 160K,
Trailing Ivy 520K). **None of the three consumes a lawn slot** — the nine
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

### The trophy shelf

**Money buys the frame; play buys the picture.** Ten lawn ornaments are
*earned* rather than bought, in `Config.TROPHIES`, and stand on a fifth,
coin-bought ladder of bases, `Config.TROPHY_PLINTHS`. A trophy is an
**ordinary decor item** in every other respect — it lives in
`Config.DECOR_ITEMS`, carrying a `trophy` field and no `cost` (the whole of
what makes it one) — so ownership, the auto-slot, the put-away toggle, the
plot rebuild, the shop card and the reconcile prune are all `data.decor`
doing exactly what it already did for the other eighteen. That also makes
the nine lawn slots (§11) scarce by construction: standing a trophy costs a
slot an ornament was using.

| Trophy | Records | Grows as |
|---|---|---|
| **Victim Shelf** (`victimshelf`) | robbing **5+ different piggy skins** | one rendered mini piggy (`PiggyModel.build`) per skin robbed, up to every entry in `Config.SKINS` |
| **The Haul** (`haulvault`) | `data.totalStolen` — lifetime coins taken off other pigs | a gold bar per **doubling** from 100K, ten bars |
| **Medal Board** (`medalboard`) | `data.trophies.caught` — thieves *you* stopped: your own guard dog emptying one on your lawn, or you personally nabbing one empty anywhere on the street | a rosette every three catches, capped at nine |
| **Siren Post** (`sirenpost`) | `data.gear.escapes` — most-wanted patrols outrun (§7) | one blue Neon lamp per escape, up to five |
| **Hot Streak** (`hotstreak`) | `data.trophies.bestSpree` — the longest run of consecutive deliveries (§5) | one flame tier per grade, a grade per step past its need |
| **Old Hand** (`oldhand`) | the robber rank, `Config.getRapSheetRank(data.robberies)` (§3) | one star per grade, a grade per rank past its need |
| **Clean Sheet** (`cleansheet`) | `data.trophies.clean` — clean five-slice cracks delivered home | a gold ring on a vault dial per grade, graded by doubling |
| **Season Cup** (`seasoncup`) | `data.season.best` — the best season tier ever reached (§3) | a larger cup and one gem per grade, a grade per tier past its need |
| **Wanted Poster** (`wantedposter`) | `data.trophies.wanted` — times this player topped Most Wanted | one poster per grade, graded by doubling |
| **Good Harvest** (`goodharvest`) | `data.trophies.harvested` — Acorns delivered from the player's **own** tree | a barrel, with one ring of acorns heaped over the rim per grade, graded by doubling |

The spread is deliberate — offence (Haul, Hot Streak, Old Hand, Clean Sheet),
defence (Medal Board), the police (Siren Post, Wanted Poster), collection
(Victim Shelf), the tree (Good Harvest) and the season (Season Cup) — so a
player who spent everything on fences and locks still has something to earn.
A patrol **arrest** never counts toward Medal Board: the police belong to
nobody, so crediting a plot owner for a car the street sent would make the
patrol a defence upgrade. The need, grade cap and ladder of each live in
`Config.TROPHIES`; `Config.trophyGrade` reads them — a count grades linearly,
by doubling (`double`), or one grade per step past the need (`ladder =
"above"`, for counts that are already small ladders).

**`TrophyService.counts`/`.state`** are the only place any of these numbers
is read for display, so a shop card's progress bar (the same have/need pair
the Most Wanted gear cards already draw) and the geometry standing on the lawn
can never disagree about what "earned" means. `TrophyService.check` runs after
every event that could move one — a delivery, a nab, a dog's catch, a patrol
escape, a new best spree (`recordSpree`), and the three Phase 5 counters,
each bumped where the thing is *complete*: `recordClean` when a clean crack's
haul gets home, `recordHarvest` when an own-tree basket is delivered, and
`recordWanted` when `SocialService` hands the Most Wanted board to a player —
at most once per session each, or two friends trading the lead would farm it.
Counts that live elsewhere in the save (the robber rank, the season's best
tier) are re-asked through `TrophyService.recheck` by their writers. It grants
**and auto-places** anything newly earned, in catalogue order; if the lawn is
full it still grants ownership and says so, rather than silently withholding a
reward already earned.

**`Config.TROPHY_PLINTHS`** is the coin side of the shelf: Stone (40K) →
Marble (400K, adds an engraved plaque naming the trophy's own figure) →
Gilded (4M, adds a Neon uplight — never a `PointLight`, since there is no
night in this game, §11). One purchase restyles every trophy at once.
Bought and equipped through one control — `CosmeticRequest` kind `"plinth"`
→ `TrophyService.buyPlinth`/`.equipPlinth` — the same buy-or-equip shape a
skin or a dog coat uses. **A plinth confers nothing**: it repaints a base and
adds a plaque, never anything a thief reads off the lawn, which is what lets
it be sold for coins under "money buys the frame".

`TrophyService` (§12) requires only `DataService` and `PlotService`, and
pushes the shop's repaint through a registry (`registerPusher`, filled by
`Main` with `CosmeticsService.push`) rather than requiring `CosmeticsService`
back — that service already requires `TrophyService`, for the progress bar on
a locked trophy card.

### The roll — retired

The accessory roll was the older of the two random-outcome mechanics, and the
one the regular crates' own collection rule (duplicates allowed, producing a
spare, §3) was written to deliberately reverse. It is gone now, in the same
edit that emptied `Config.ACCESSORIES` (§9): `CosmeticsService`'s
`ownedCount`, `rollFrom` and `rollAccessory`, `Config.getRollCost` and its two
constants all went with the catalogue they rolled from. `Config.ROLL_CURRENCY`
did not — that names the **loot** currency itself (§3), which the event chests
still price in; the roll was one spender of loot, not its definition.

### Rarity

**One ladder for the whole shop**, `Config.RARITIES`, with **absolute** coin
bands. An explicit `rarity` wins; otherwise the price determines the tier. That is what keeps it honest as the shop grows.
**Only things you keep get a tier** — consumables deliberately have none.

The chests in §3 reuse this same function (`Config.rarityOf`) to sort their
stock into odds bands — one tier system for the whole shop, not a second one
invented for chests.

**Skins are the one catalogue that never lands on all four.** All 45 carry an
explicit `rarity`, and every one of them is `common`, `rare` or `legendary` —
`epic` is unused on a skin, deliberately, so a three-tier pool is deep enough
at every rung to be a pool rather than a coin flip (§3). `martian`, the Alien
Cache's own skin, is the sole `epic` skin in the game; it reads that way
because it is a *set* item sorted by the same `Config.rarityOf` alongside the
alien set's other three members (a decoration, an effect and a ride, §8), not
because the skin restructuring missed it.

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
  takes that list rather than deriving its own — and always adds three more
  keys that belong to a *player* rather than a ride: `dodgeRoll`, `sneak` (the
  tiptoe's own gait, §5, `Shared/SneakWalk.luau`) and `carry` (holding stolen
  loot on the run home, §5, `Shared/CarryPose.luau`) — so `Main` warns at
  startup for any of the lot with no id. `animdump`'s own `own` table maps
  each of those three keys to its builder and is *walked* to produce the
  upload list, rather than a second hardcoded copy of the same three names
  sitting beside it — so a fourth player-owned animation is one row there
  and the ride loop skips it for free, and none of the three can silently go
  unbuilt the way `sneak` once did. A stance with no id falls back to the
  plain pose for that ride rather than to no pose at all.
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

One street, ten plots in two rows of five (`Config.PLOT_COUNT`,
`Config.PLOTS_PER_ROW`) — one column more than the eight players a server
holds, on purpose (below) — a **wide verge** carrying the boards and the
shops, and a hill with a tunnel through it at both ends.

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
  the far half — two pairs was the workaround. Centred at x 0, no plot is
  further than two `PLOT_SPACING`s along the street from the pair (it was one
  and a half at four a side; the fifth column pushed the outermost plots
  further out). They face each other across the road, standing on grass.
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

`Config.DECOR_SLOTS` is a **grid**, plot-local with +Z toward the street: four
columns across the back row (`lawnA`–`lawnD`), the outer two columns only on
each of the two middle rows (`lawnE`/`F`, `lawnG`/`H` — the inner pair sits
inside the piggy bank and the gate walk from the street), and one slot on the
front row's left (`lawnI`) — the front-right corner is the kennel. That is
**nine lawn slots**, up from the old ring's seven. Two verge slots
(`vergeL`/`vergeR`) flank the driveway outside the fence, and they are still
the only ground out there that stays dry at fence tier 5.

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

**What limits the column count is that one ornament, not the plot.** The back
row already fits four columns at the tube man's width; the middle rows and the
front row carry fewer only because the piggy bank, the gate walk and the
kennel already claim those positions, never because of item width. A narrower
widest ornament — or a wider lawn — is the lever if more are ever wanted.
Trophies (§9) are lawn items like any other, which is what makes the shelf
scarce: nine slots against eighteen ornaments and four trophies means
displaying what you have *done* costs a slot you were using for what you
*bought*.

**The kennel moved to the front-right corner** when the plot widened — on the
old narrow lawn its position was near the edge, and on the wide one the same
offset stood a third of the way in, with the dog napping in the middle of
somebody's garden. The corner is also what buys a slot back: it holds exactly
one grid position, where anywhere in the middle would have cost two. It
is placed by `PlotService.buildPlot`, not by `Config.DECOR_SLOTS`.

**It stands at plot-local `(KENNEL_X, 0, KENNEL_Z)` — (25, 0, 16) — turned by
`KENNEL_YAW` (a quarter turn, −90°) so its doorway faces across the lawn
rather than out at the street.** `GuardDog.clampToYard` then holds every
destination the dog is ever sent to — a random patrol point, a toy visit, its
sleep spot (§9) — inside the **fence** rectangle (the same one
`PlotService.yardContaining` tests for ride and trespass purposes), inset by
the dog's own reach at its current breed scale. A toy's offset is authored
kennel-local for the same reason the kennel's own position is: it travels
with the kennel if the kennel ever moves again, rather than being left
pointing at wherever it used to stand.

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
  single source; multiple files need the tunnel mouths. `Config.ROAD_SURFACE_Y`
  — the tarmac's own height above the world ground, 0.06 proud so the two never
  z-fight — is shared the same way: it lived as a private local inside
  `PoliceService` until a second vehicle needed the identical number.
- **Nothing here can be dug.** A Part cannot cut a hole in another Part, so
  sunkenness is always an illusion: the moat's depth comes from kerbs standing
  *proud*, and the tunnel is a black `Neon` slab, not a bore. (CSG — `UnionAsync`
  / `SubtractAsync` — *does* work at runtime, but it is **server-only**.)
- **Hills are the only scenery that collides.** Everything else in
  `NeighborhoodService` is non-colliding so a chase can run through it.
- **Wheelie bins are public street furniture**, three a side, owned by nobody.
  Hiding is a *place*, not a costume. A bin buys a breath, never an escape.
- **Every plot carries its own mailbox, and it is the only way back to the
  daily board.** The board opens itself once per session, 1.5 seconds after
  joining, and nothing else in the game reopens it — so closing it without
  claiming lost the day silently, with a reward still sitting there and
  nothing on screen to say so. `PlotService.setMail`/`.setMailOwner` raise a
  foot-hinged flag and enable the `post` prompt (§14) together, on the same
  push (`DailyService.push`) that fills the board itself (remote `DailyOpen`
  is what re-opens it — it carries nothing, since the client already holds
  the whole snapshot and the click only ever means "look at it"), so the flag
  and the board can never disagree about whether today's claim is waiting.
  `Config.PROMPT_OWNER_ATTRIBUTE` is what lets every other client refuse
  somebody else's mailbox on its own screen; the server re-checks the owner
  on the trigger regardless.
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
| `WorldService` | Ground, lighting, `ClockTime` — fixed at the day table (`WorldService.DAY`) except for Midnight Heist's dusk (`setNight`/`restoreDay`, §8), which never goes dark |
| `NeighborhoodService` | Road, tunnels, verge, shopfronts, trees, street furniture, bins |
| `PlotService` | Plot pool, fences, ladders, driveways, ownership, signs, the mailbox (`setMail`/`setMailOwner`/`onMailCheck`, §11), the doorstep crate box (`setCrate`/`setCrateOwner`/`onCrateOpen`, §3), the rebirth firework attributes (`fireFireworks`, §4), and the four un-claimable shop-vault plots (`Config.SHOPS`, built on the same frame `ShopFront` builds its walls in) — publishes `onClaim`/`onRelease` hooks; forwards the dog's coat, kennel skin, toys and filtered name to `GuardDog` (`setDogCoat`/`setDogKennel`/`setDogToys`/`setDogName`, §9); holds each plot's trophy state and rebuilds the lawn from it (`setTrophyState`, §9); holds what a plot's owner has planted and puts it up (`setGarden`/`refreshBorder`/`refreshWindowBoxes`, §9), and records a plot's own equipped skin (`applySkin`, `plot.skinKey`) so a topiary knows what to render; the sign's season chip and NEMESIS line (`setSeasonChip`/`setNemesis`) and the worn finish, remembered as `plot.finishKey` and re-applied after every skin repaint (`applyFinish`, §3); the owner's Grow Tree prompt and the tree's level and next-acorn clock (`setTreeOwner`/`setTreeLevel`/`publishTree`, §3) |
| `ResidentService` | The NPC neighbour seated on every plot nobody owns — a name, a seeded pig, and defences/garden that track the server's average level plus a fixed, per-resident downward offset (§5). Also seats a permanent shopkeeper on each shop plot, laddering only its Vault Lock, and gives that shopkeeper the shop's guard-dog reaction — `alertShopkeeper` wakes and chases on a fumble or a smash, `registerCatch` is a registry `Main` fills with `HeistService.shopkeeperCatch` (§5) |
| `PiggyBank` | The piggy model, coin pile, skins, effects, the season finish over a skin (`applyFinish`, §3), vault dial, the robbed plaster, and the shop strongroom (`buildVault`, wrapping the same `Refs` a piggy bank returns, §5) |
| `GuardVisual` | The imported mesh guard models, rebuilt from their authored bone assignments; required by `GuardDog` |
| `GuardDog` | Patrol, kennel, guard duty, the off-duty nap, and the awake/asleep posture that tells a thief whether the owner is home. Exposes `isOwnerHome`/`bark` so `HeistService` can drive the alarm-only branch without `GuardDog` knowing anything about players (§5). Also owns the dog's wardrobe — coat, kennel skin, toys and its (pre-filtered) name — repainted through the one function, `applyTier` (§9); `clampToYard` holds every patrol/toy/sleep destination inside the fence (§11) |
| `BoneService` | Thrown bones |
| `EconomyService` | Accrual loop, milestones, the `StateUpdate` push (fires whenever the whole-coin balance changes) |
| `UpgradeService` | Both upgrade trees |
| `HeistService` | The crack and the smash (§5), carrying, nabbing (including which catch effect fires and on whom, §9), delivering, the loss cap, coin revenge and per-owner timed skin recovery claims/private recovery objectives, the dodge, tiptoe (`tiptoeInEffect`, the local shared by `currentSpeed` and the `Config.SNEAK_ATTRIBUTE` publish in `refreshSpeed`, §5), and the lawn watch (`watchLawns`) that wakes a guard dog on footsteps or a missed slice — against a `Target` of a player **or** a resident. `releaseDog` is where a wake decides alarm-only (owner home) versus a chase (owner away); `markIntruder`, a `HeistService`-local, marks the alarmed thief with a Highlight — see §5. A delivered robbery, a nab and a dog's catch each report to `TrophyService` (§9) — a clean crack delivered calls `recordClean`, an own-tree basket `recordHarvest`, a new robber rank `recheck`; banked Acorns (a basket, the pig-crack acorn) go to `SeasonService.earn`, a delivery against a player to `SeasonService.recordNemesis` (§3), and a player's nab win, a dog's catch for its owner and a hot skin brought home by its owner to `SocialService.recordDefend` (§14); a completed shop-vault crack also rolls its item drop (`Config.SHOP_VAULT_DROP`, §5) — a duplicate off an owned pool pays coins instead of nothing — pushed to the hot bar through `registerStockPusher` — filled by `Main` with `BoneService.push`/`GadgetService.push`; `shopkeeperCatch` (§5) runs the same `nab`/`scare` a real dog's catch does, with an optional `catcher` name so the toast can say "The shopkeeper" instead |
| `TrophyService` | The trophy shelf (§9): what has been earned, the plinth ladder, and the one place a trophy or a plinth is ever granted; the Phase 5 counters (`recordClean`/`recordWanted`/`recordHarvest`) and `recheck` for counts other services own. **A leaf** — requires only `DataService` and `PlotService` — and pushes the shop's repaint through a registry (`registerPusher`) `Main` fills with `CosmeticsService.push` |
| `CosmeticsService` | Buying and equipping everything cosmetic, including catch effects (§9), wearing an earned season finish (`equipFinish`, the `finishes` push payload, §3) and trophy plinths (routed to `TrophyService`, §9); **the roll**, priced in loot; the dog's coats, kennels and toys, and `nameDog` — the only caller of Roblox's text-filter API anywhere in this game (§9); the garden's three catalogues through one function, `buyGarden` (§9); `grantPassItems`, the one path every Robux pass grants through, hooked to `PassService.Granted` (§15) |
| `ProgressionService` | Rebirth reset, free Legendary Crate or completed-collection Acorn payout, immediate save |
| `SeasonService` | The season (§3): lazy rollover of `data.season`, `earn` (never mints), tier grants once per season through `SetService.grant`, the nemesis ledger (`recordNemesis`/`nemesisOf`), the season board store, `window` rows and the `SeasonState` push, `getTop` for the street board, `refreshSign`, and a server-local dev clock shift (`shiftWeeks`). Requires `DataService`, `PlotService`, `SetService`, `TrophyService` |
| `SocialService` | Friend bonus, the one street board and the three pages it turns (Top Thieves, Top Defenders — `recordDefend` and a weekly `Config.WEEKLY_DEFEND` store — and the season, §14), Most Wanted board (handing it over calls `TrophyService.recordWanted`), revenge markers, the per-player rap sheet push (`pushWanted`, remote `WantedState`, §14), and the spree — consecutive-delivery payout/pursuit-floor state (`recordSteal`/`breakSpree`), kept in a table separate from the rap sheet on purpose (§5, §7) |
| `PoliceService` | Patrol schedule, pursuit, arrest, the radio |
| `TrafficService` | The delivery van — one at a time, west to east through both tunnels, standing down while `PoliceService.isOut()` (§11). Confers nothing and carries no gameplay hook |
| `EventService` | The event roster |
| `TreeService` | The tree ladder (§3): buying the next level (`TreeRequest`, the owner-only Grow Tree prompt) and the offer; growth itself is `Config.growAcorns` |
| `ShakeService` | Shaking a tree: moving ripe Acorns into a refundable carry, and the per-thief Acorn cooldowns (`AcornCooldown`); opening anyone's tree but the owner's is closed (§8) |
| `ResidentAcorns` | One Acorn stock record per residential plot for the server's life (§3) |
| `SetService` | Loot, sets, the drop reel, ownership lookups shared with chests (`owns`, `inUse`, `grant`, `revoke`) — which also resolve the season's reward kinds `finish`, `plinth`, `kennel` and `coat` (ownership only; none is in `Config.catalogueFor`) |
| `ChestService` | Opening chests, seasonal exact-skin Acorn buy-backs, combining per-item spares by tier, selling spares for coins (leaf: requires `DataService`, `SetService`) — opening and combining are on the Crates tab; selling is in the Inventory panel |
| `DailyService` | The daily ladder and boosts; raises the mailbox flag and re-opens the board (`push`, §11) in the same push that fills it; the chest a day-seven claim owes until it is opened at the doorstep (`openCrate`, §3) |
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
`SetService` pusher for the season's `finish`/`plinth`/`kennel`/`coat` grants), which keeps each service's dependency list at one line and makes a
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

**Schema 20** adds `data.dogs` — the guard dog's wardrobe (§9): which coats
and kennel skins are owned, which of each is equipped, the already-filtered
name and when it was last set, and which toys are owned versus standing out.
It is a **new top-level table**, so this is the bump that actually needed
spending; `kennels`, `kennel`, `toys`, `name` and `namedAt` are all keys added
inside that same table since, and none of *those* needed a further bump — the
generic one-level-deep fill above already covers a table's own new keys.
`reconcile` prunes `owned`, `kennels` and both `toys.owned`/`toys.out` against
their catalogues, and falls the `equipped`/`kennel` fields back to `""` if
they no longer resolve — the same rule every retired-item prune in this file
follows: ask the catalogue, never a list of names.

**Schema 21** adds `data.catch` — catch effects (§9), the third kind of
cosmetic and the first that lands on somebody else. It is a **new top-level
table** rather than two more fields inside `cosmetics`, deliberately: that
table is what the *piggy* wears, and a catch effect fires on the person a nab
just caught, which is never the piggy's owner. Filing it under the piggy's
wardrobe would have been the first name in this save that stopped describing
what is actually in it.

**Schema 22** adds `data.daily.crate` — a `Config.CHESTS` key naming the chest
the day-seven daily reward still owes this save, or `""` for nothing owed
(§3). A new field inside an existing table, so `reconcile`'s generic
one-level-deep fill picks it up on every existing save with no migration
branch — the same free ride `week`, `loot`, `spares` and `dogs`' own later
keys took.

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
skin, coins, Acorns and spares are preserved; `sinceLegendary` is removed.
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

**Phase 5 (no schema bump; `Config.SCHEMA_VERSION` is unchanged)** adds three
top-level tables and five fields, all filled by the generic pass with empty or
zero defaults: `season` `{index, earned, tier, best, granted}`, `nemesis`
`{index, rows}` and `defend` `{index, count}` (§3, §14);
`trophies.clean`/`.wanted`/`.harvested` (§9); and `cosmetics.finish` plus
`cosmetics.ownedFinishes` (§3). `season` and `nemesis` roll lazily on read
against `Config.seasonIndex`, `defend` against `Config.weekIndex` — no
rollover job. `reconcile` prunes `ownedFinishes` against `Config.FINISHES`,
takes the worn `finish` off (`""`) unless it is owned, and restores the
one-deeper shapes (`season.granted`, `nemesis.rows`) if a save carries the
wrong type. The tree ladder's `data.tree` `{level}` (§3) arrived the same way.

**No schema bump** covers the skin restructuring (§3, §9): retiring five skins
and folding one chest into another needed no new field, only a wider prune.
`reconcile` drops any `data.cosmetics.owned`/`ownedEffects` key no longer in
`Config.SKINS`/`Config.EFFECTS`, falls `data.cosmetics.skin`/`.effect` back to
the default if the worn key no longer resolves, and drops any `data.spares`
entry whose `"kind:key"` catalogue no longer holds it — the same
catalogue-not-a-list-of-names rule as every prune above, run against
`Config.catalogueFor` rather than a hardcoded five-kind branch so a retired
ride or ornament is covered by the identical loop.

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

- **The HUD.** The **coin readout** is `Shared/PiggyPanel`,
  mounted by `ClientMain` at the top right. The cream card has a drawn pink
  pig medallion, balance/capacity, green income pill and a rounded gold bar.
  `StateUpdate` drives the numbers; the bar tweens to the clamped
  `coins / capacity` ratio, including backwards when spending. An empty pig
  shows no fill, overflow keeps the real balance with a 100% bar, and the
  footer reads time to full or **FULL · Spend to earn again**. The 420×128
  card becomes a two-line 252×64 card on short/narrow viewports, keeping the
  balance, capacity, income and fill percentage while hiding the title and
  status footer. This uses about 45% less area than the previous mobile card.
  Event and wanted chips sit beneath it at 75% size. Rebirth is a compact
  146×44 button between the Roblox controls and the vault card.
  The left side holds three static, transparent icons in a column, drawn by
  `Shared/MenuIcons.luau`: Options, Stuff and Shop. `Shared/HUDLayout.luau`
  keeps this column above the joystick, with 44–48 pixel icons on phones.
  Dodge, Ride and Sneak sit above Jump on the right in 52-pixel circular
  buttons. `Shared/ActionButtons.luau` draws static sneaker, wind and board
  illustrations; short captions and cooldown/state feedback remain. A riding
  trick shares Dodge's position. The ride picker opens toward the centre.
  Shop (`B`) and Stuff (`I`) retain
  their keyboard shortcuts; Stuff opens the standalone inventory below. The income and
  capacity purchases that used to sit above both are rows in the shop's
  Upgrades tab now. Bottom-left is four rows deep and the fifth control went
  *sideways* rather than up. `IgnoreGuiInset` is on, so y=0 is *under* the
  Roblox topbar.
- **The shop.** A seven-tab rail (Everything, Upgrades, Home, Rides, Items,
  Worn, **Crates**) over a front page — the Everything tab — showing **six**
  cards: the **Houses**, **Decorations**, **Rides** and **Throw & Sneak**
  shelves, plus **Defend / Rob** and **Crates**, one card each, centred in a
  3×3-cell grid (`1/3 × 1/3`) with the empty bottom row left as margin rather
  than resized away. Cards render the **real 3D item**. The tab rail is a
  `ScrollingFrame` — a fixed one silently ate two whole tabs, because a
  `UIListLayout` does not clip and does not error — and each tab is now
  **sized to its own label** (`TextService:GetTextSize`) rather than a flat
  width, so a short word like "Worn" does not spend the same room as
  "Everything". **Inventory is deliberately not an eighth tab** — a shop tab
  is where you go to spend, and this is where you go to look at what you
  already own, so it is its own full-screen panel instead; see the Inventory
  bullet below. **The Piggy tab is gone**, and its two sections went with it:
  skins are bought nowhere in the shop any more (only opened out of a crate
  or equipped from the bag, above), and priced *effects* lost their only
  storefront — `Config.CHESTS` has no effects chest, so the five buyable
  auras (§9) are currently unreachable by any route, a known and deliberate
  gap rather than a bug. `Remotes.get("LootBuy")` has no client caller left
  either, which is what makes the alien set's `martian` skin and Tractor Beam
  effect Alien Cache drops and nothing else now (§8) — the server-side
  guaranteed-purchase path behind that remote is untouched, so restoring a
  storefront for either is one call site rather than a feature. The
  **Upgrades** tab is the one tab
  that changes an outcome: a
  full-width **EARN** band (Earn Faster, Bigger Piggy Bank — the income and
  capacity purchases) sits above two columns, **DEFEND** and **ROB**, one card
  per upgrade tree. All eight rows share one card builder (`makeUpgradeCard`);
  the six tree cards show a pip ladder and the two EARN cards show a
  continuous bar reading `Lv N / M`, because income and capacity run to
  `Config.maxLevel` (up to 40) where pips would be unreadable. The **Home**
  tab leads with **YOUR GUARD DOG** / **ITS KENNEL** / **ITS TOYS** — the
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
  sells for N" line goes. Regular crates also show combine chips; Alien
  remains excluded. A short balance shows the Acorn shortfall and tree hint;
  tapping OPEN still requests the server refusal. Tree earning is pending Phase 2.
  Seasonal buy-back cards sit beside the source crate, with the real lost skin
  preview, server price and shortfall. Only current unowned claims are shown;
  `SkinBuyback` sends the key alone. Ownership changes refresh the cards through
  `CosmeticsService.registerCollectionPusher(ChestService.push)`; cards also
  disappear locally at the supplied `buybacksExpireAt` boundary. Buy-back has
  no crate reveal. Isolated UI state checks pass; live rendering/input remains
  unverified.
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
  and a **Finishes** tab for season finishes, §3 — sent only when owned,
  worn through `CosmeticRequest` kind `"finish"`, never sellable),
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
  camera. **The one street board turns three pages** (Phase 5), each for
  `Config.BOARD_PAGE_SECONDS`, publishing which is up as
  `Config.BOARD_PAGE_ATTRIBUTE` on the panel: **Top Thieves this week**
  (`Config.WEEKLY_HEIST`), **Top Defenders this week** — thieves a player
  stopped (a nab win, their dog's catch, a hot skin they carried home;
  `SocialService.recordDefend`, counted in `data.defend` and published to a
  weekly `Config.WEEKLY_DEFEND` store on the same cadence as Top Thieves) — and
  **the season**, whose server copy paints the global top from
  `SeasonService.getTop`. On that page `Shared/SeasonBoard.luau` hides the
  server's `BoardGui` *on this client only* and draws its own local
  `SurfaceGui` from the reader's `SeasonState` (§3): the rows around the
  reader, their own row in gold, and a footer with their tier and what the
  next one needs. It never writes to the replicated labels. Its layout mirrors
  the server board and has not been checked in Studio.
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
- **Skin tags and nearby Acorn cooldown.** Street badges have no Acorn row.
  `CappedUntil` and `HotSkinUntil` publish only server-owned public facts.
  A valid private recovery claim changes HOT SKIN to **RECOVER SKIN** for
  its owner. Refunds, reacquisition, disconnects and expiration clear the
  corresponding state; changing outfits does not. A nearby tree or storage
  prompt shows an hourglass and **Steal ready in m:ss** during that viewer's
  Acorn theft cooldown. `AcornCooldown` sends private server deadlines for
  both sources; resident rest uses the existing public plot deadline. Owners
  can still harvest. Expiry restores the prompt locally; server validation
  remains authoritative even if a client attempts to trigger early.
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
  unavailable free recovery falls back to **BUY IT BACK — N ACORNS** only for
  a current unowned seasonal claim. Tapping opens Crates and scrolls to that
  exact skin, with no purchase on the objective itself.
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
| `steal` | STEAL | 💰 | red | anybody's piggy but your own — opens the crack (§5), it no longer completes a robbery by itself |
| `smash` | SMASH | 💥 | red | anybody's piggy but your own, live on the same body as `steal` at the same time — the loud, fast way in (§5); ignores the Vault Lock and always sounds the alarm |
| `nab` | NAB | 🚨 | amber | a thief carrying loot |
| `hide` | HIDE | 🗑 | slate | a wheelie bin |
| `dig` | OPEN IT | 👀 | orange | a bin with somebody in it |
| `shop` | SHOP | 🛒 | green | the four shop doors |
| `post` | CHECK POST | 📫 | gold | a plot's own mailbox, once the day's claim is waiting |
| `crate` | OPEN CRATE | 📦 | gold | the box on a plot's doorstep, once a day-seven crate is owed (§3) |
| `recover` | RECOVER | 👽 | alien green | a downed raid drone |

**`Config.PROMPTS.collect` is a dead entry.** There is no collect/bank action
since the pivot — the pig is the wallet and nothing is banked (§4) — so
`EconomyService.collect`, the `CollectRequest` remote and the piggy's
`CollectPrompt` are all gone. The table row survives in Config, unread by
anything; `steal` and `smash` now live on a piggy together (below), both
enabled for everybody but its owner.

**`nab` is never offered to the one player it would nab.** It is welded to a
carrying thief's own root so every *other* player can reach it, which also
puts the thief permanently at distance zero from their own prompt.
`PromptUI` disables the prompt on the thief's own client the instant loot is
welded to them, and `HeistService.nab` refuses a self-nab server-side
regardless — a forged self-nab would otherwise return the loot to the victim
and stun the thief for nothing.

- **Colour is never the only signal** — every card carries the word and the
  glyph too, the same rule the rarity borders follow.
- **Tones are borrowed from `Config.NOTIFY`**, so an action and the toast it
  produces are the same colour.
- **`Config.setPromptKind` sets the kind and switches the prompt's own
  `Style` to `Custom` in one call, and the two used to be written apart.**
  `PromptUI` refuses to adopt anything still on Roblox's default style, on
  the sound reasoning that a default prompt is one nobody has given a kind
  yet — but a prompt that had a kind and was never switched still passed
  that guard, and rendered as the plain grey pill regardless. Measured live:
  the mailbox and a gate jam both set only the kind for a session and both
  drew the default pill the whole time, undetected by any property read,
  because reading `ActionText`/`HoldDuration`/range back reports they were
  built correctly and says nothing about which picture is on screen.
- **The hold bar shows the real duration**, and over
  `Config.PROMPT_COUNTDOWN_OVER` seconds it adds a countdown — the HUD half of
  the problem the vault dial solves from the street. `steal`'s own hold is now
  a flat `Config.CRACK.openHold` (half a second, well under the countdown
  threshold) — it opens the crack panel rather than timing the robbery, so the
  lock-vs-lockpicks axis shows on the crack dial instead (§5, §14). `smash`'s
  hold (`Config.SMASH.hold`, 1.3s) is the opposite: there is no panel after
  it, the hold *is* the whole robbery, and the bar is the only warning anyone
  standing nearby gets before it lands.
- **A card can carry a live gold amount beside the verb**
  (`Config.PROMPT_AMOUNT_ATTRIBUTE`), watched rather than read once at build
  so it stays true while a player stands there — the steal prompt uses it to
  show the pig's own contents (or `Holding … · run home` once the thief is
  already carrying), which is also what `RobBadge` shows from the pavement
  (§5). The smash prompt carries the same attribute quoting what a smash
  would actually take (`~%s`, or `EMPTY` once the fixed share rounds to
  nothing) — the two cards read as *what's in there* against *what I'd get*,
  side by side on the same body.
- **A prompt that names an owner is for nobody else.** `post` and `crate`
  both carry `Config.PROMPT_OWNER_ATTRIBUTE` — a plot's own player id — and
  `PromptUI.start` watches *every* prompt in the world for one, rather than
  only prompts that already carry the attribute at build time (a plot's
  mailbox has no owner until somebody moves in). A client disables the
  prompt on its own screen the moment the attribute names somebody else;
  the server re-checks the owner on the trigger regardless, so the client
  rule is a courtesy and never the actual guard.
- **Two prompts can share a part now, and only one of the two pairings is
  mutually exclusive.** The bin (`hide`/`dig`) still guarantees only one is
  ever enabled at once, so its cards never stack. A piggy's `steal` and
  `smash` are the opposite: both are enabled for the same thief at the same
  time, on purpose — a choice you cannot see is not a choice. What lets both
  cards stand on one billboard without overlapping is
  `Config.PROMPT_SLOT_ATTRIBUTE`: it grows the smash's billboard by a slot
  and pins its card to the bottom edge, holding a *constant pixel gap* at
  every range — a world-space `StudsOffset` gap would instead separate the
  two cards close up and overlap them at exactly `STEAL_RANGE`, the distance
  a thief actually decides from. Slot 0 (`steal`) renders byte-identical to
  what a lone card on a part has always looked like.

---

## 15. Monetization and compliance

**No coin or Acorn product is currently enabled.** Monetization grants
named rides, passes and stances. Crates now charge earned-only Acorns and
reject coin payment (§3). The master plan keeps broader reward and economy
gates ahead of any future coin product; converting crates alone does not
complete those gates.

**Shippable today:** three game passes, `Config.PASSES` — the **Style Pack**
(riding stances, §10), **VIP** (a skin, an aura, a catch effect and a mark on
the plot sign) and the **Starter Pack** (a skin, an aura and an entry ride).
All three confer nothing, cannot be aimed at anybody, and are named things
rather than currency.

**VIP is not a rate, and that is arithmetic rather than policy.** A straight
income multiplier fails `Config.auditRobbery` (§5) outright — the full-server
baseline it would be dragging down from is already only 3.37x
(`Config.SHOP_VAULT_DISCOUNT` came down to 0.70 to pay for the shorter run
home a shop vault costs a thief, §5), against a floor of 3.0. The whole
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
- **Locked content is SENT to the client, never filtered out.** The shop is
  where something you do not own is supposed to be advertised.
- **Every pass gets a card on the shop's SPECIAL OFFERS shelf (Worn tab,
  §14) unless it already has a better home.** `Config.PASSES.stylePack.soldWith`
  points that one pass at its own tab instead, so a riding pose is sold next
  to the rides it animates rather than as a second card nobody connects to
  them — the same argument against a near-identical duplicate this file makes
  everywhere else.

**Rebirth still leads to a random reward.** The designer chose a standard
Legendary Crate rather than the proposed deterministic reward. Coins currently
have no purchase product. Any future coin-sale work must revisit this route
and the master plan's random-reward audit before shipping.

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

The **Season** group (Phase 5) exists because the season only counts in an
active week and the launch fell in a rest week: `seasonshift` moves *this
server's* season clock by whole weeks (`SeasonService.shiftWeeks`, never
saved, bounded) and repaints every sign and push; `seasonearn` credits season
Acorns through the real `SeasonService.earn` path, so tier grants, the sign
and the save all run as they would in play; `seasonstate` prints
`SeasonService.status`. A **Tree** group sets the tree level outright
(`tree`), bypassing the house gate that only restricts buying.

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
  coat's `collar`; toggling a skin off restores plain wood; all nine toy parts
  build hidden and show on demand with the water keeping its authored 0.35
  transparency; the Dog Bed makes a settling dog walk 8.93 studs from its
  kennel and lie at the bed spot to 0.00 studs, and putting the bed away sends
  it back to the doorway to 0.00; the ball bounces 1.50 studs and returns to
  rest with zero drift; the duty vest shows only on the one dog that was given
  a treat (1 of 14) and survives three full `applyTier` repaints — a coat
  cleared, a different coat worn and the kennel re-skinned — with the collar
  never going neon and the plate holding ON GUARD; and a save naming a kennel
  that has been deleted from `Config` degrades to plain wood without throwing.

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

- **Opening a chest is reachable now, and so is selling a spare — combining
  has a control too, below.** The shop's **Crates** tab (`Shared/Crates.luau`,
  §14) fires `ChestOpen` from a real card and renders `ChestState`/`ChestResult` —
  verified live: all five crate cards build with three real previews each
  and the correct renormalised odds, opening the chest then called `classics`
  produced a real reveal through the shared `SpinWheel` reel (title "PIGGY
  CLASSICS", subtitle "52% common · 32% rare · 12% epic · 4% legendary",
  landed on the server's actual item), a duplicate showed "Spare · sells for
  95.2K", the OPEN button greys within 0.5s of the pig being drained and
  relights on top-up without spending on a greyed click, progress repainted
  4/17 → 6/17 across opens, and real pointer clicks on the SHOP button and the
  front-page CRATES card opened the panel and selected the tab. **That test
  predates the skin restructuring in §3**: the chest is `og` now, 28 skins
  rather than 17, and the odds/subtitle are `common 52 / rare 44 / legendary
  4` with no `epic` band — the mechanism this bullet verifies (the reveal, the
  greying, the progress repaint) has not been re-run against the new pool.
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
- **`ChestCombine` has a real caller now, and the gap is narrower than "no
  button."** The Crates tab's own cards carry the control: three chips per
  card — one per tier below legendary, each reading `have/need` off
  `Config.COMBINE.need` — and a press calls `deps.combine(tier, chestKey)`,
  which `ClientMain` fires straight to
  `Remotes.get("ChestCombine"):FireServer(tier, chestKey)`. The alien card
  hides the row outright rather than showing three chips that always refuse.
  Server-path verification is unchanged and still holds: `combine` pools
  per-item spares by tier and auto-picks cheapest first, a client-named list
  it does not hold is refused whole, combining into the event-set `alien`
  chest is refused, and 42 spares across 14 items survived a full server
  restart at schema 18. **What has NOT run is a pointer press on the chip
  itself** — the same class of gap as the hot bar drag and the rebirth
  button, below: a click can be synthesised at a known coordinate, and
  nobody has aimed one at this control yet. **This bullet's last sentence used
  to record a gap that has since closed by a route nobody here chose**: the
  `gear` chest and the roll it duplicated are both gone, because
  `Config.ACCESSORIES` — the catalogue behind both — is now retired and empty
  (§9). Neither survived to be "the one retired" between them.
- **`Config.isSellable` does not know which catalogues can produce a spare.**
  It admits anything with a coin `cost`, so the Inventory panel shows a SELL
  button on rides and decorations too, even though no chest can ever
  duplicate either — a 90,000-coin BMX shows "SELL 22.5K", and pressing it
  fires a genuine, un-refused last-copy sale through the same
  `SetService.revoke` path a skin uses. Recorded, not fixed.
- **All five crates now use earned Acorns.** `Crates.render` walks every
  stocked chest in `ChestState`, including `alien`. Phase 1.4 tests cover
  their prices, charges, refusals and combine eligibility with service doubles.
  Live Studio property checks cover card text and combine visibility; purchase
  effects and reveal visuals still need an end-to-end play-test.
  `CosmeticsService.rollAccessory` — once a second, parallel route to
  loot-priced accessories — is gone along with `Config.ACCESSORIES` (§9), so
  the accessory roll this bullet used to record as a duplicate route no
  longer exists to duplicate anything.
- **Residents (§5) close most of the "needs two players" gap, and that is
  newly TRUE rather than newly VERIFIED — nothing in this pass exercised it.**
  A single player can now rob a `ResidentService.Resident` end to end: the
  crack against a real Vault Lock, the carry, the guard dog chase and
  nab, the getaway, delivery and ×`HEIST_PAYOUT`, a patrol pursuit, an arrest,
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
  (`HeistService.watchLawns`, §5), and `Config.UPGRADES.tiptoe` (Sneakers)
  gives tiptoe its own four upgrade levels, read by `currentSpeed` through
  `UpgradeService.getLevel`. Like the rest of the heist system, the crack has
  not been exercised end to end against a real second player — see the
  residents bullet above for what a solo session can and cannot cover.
- **The smash (§5) — the loud, fast way into the same pig — is live and
  verified against a resident.** `Config.SMASH`, `HeistService.smash`,
  `PiggyBank.buildSmashPrompt` (on both a house piggy and a shop vault) and
  the second stacked prompt card (`Config.PROMPT_SLOT_ATTRIBUTE`, `PromptUI`)
  are wired end to end. Driven through the real prompt rather than a module
  handle: a smash on a resident took 71 coins at a bare Bigger Sack (4.79% of
  a 1,481-coin pile) and 436.3K at a maxed sack, doubled to the thief's own
  payout, set the plaster, dropped the shield and released the guard dog on
  landing — and a Titan caught the carrying thief and recovered the loot.
  The shop-room rule refused a smash from 5.2 studs outside a vault's back
  wall (*"That vault is inside the shop. Go in."*) and allowed one from 6.4
  studs inside. Rate measured on the live server rather than only reasoned
  about: a smash pays 49% of a clean crack's coins-per-second on a house and
  72% on a shop, both flat across the sack ladder, so the crack stays the
  better rate at every level. What has NOT run, for the usual reason: a
  smash against a real player rather than a resident — the doubled payout is
  proven, but the revenge multiplier, `Config.LOSS_CAP` clamping a second or
  third smash inside the same rolling hour, and an owner's own alarm toast
  landing on a person rather than nobody are all still reasoned about rather
  than driven.
- **The shopkeeper (§5) — the shop's own guard dog — is live and verified
  through the real smash prompt, not a module handle.** A smash on a shop
  vault announced the shopkeeper, who came out to a measured 2.16 studs from
  the thief and caught them at a gap of 4.38 studs, returned to the counter
  by t4.4 and rested there. The leash was checked the same way: teleporting
  the thief 200 studs away in a single frame made the shopkeeper give up
  without ever leaving the counter (peak distance from it 0.00). What has
  NOT run is the branch against a real second player rather than a resident
  standing in for one, for the usual reason — nothing about the catch itself
  differs between the two, since `HeistService.shopkeeperCatch` calls the
  same `nab`/`scare` a real dog does.
- **The shop-vault drop's owned-item fallback (§5) is isolated-test verified;
  live gameplay verification remains open.** `Config.sellValue` returns the right coin
  figure for a duplicate off each of the three item tabs (2.0K for
  `skin:bubblegum`, 50.0K for `skin:lava`, 22.5K for `ride:bmx`), so the
  numbers `rollShopDrop` would pay are known to be right. The real fallback
  function now also passes an isolated ride-collection payout/save/toast test.
  Observing it in normal play requires a completed crack, a successful
  per-shop roll, and a fully owned shop collection.
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
  It is the identical mechanism — a code-built `KeyframeSequence`, registered
  at runtime in Studio and looked up first as an uploaded `Config.ANIMATIONS`
  id, which ships empty — so on a published server nobody's arms hold
  anything until that id is filled in and published through `animdump`.
  `CarryPose.luau`'s own header records the pose measured on a single
  character (hand-to-pig contact, the weight-0 root/lower-torso path holding
  the run's own pelvis, the Movement priority sitting under a dodge).
  A single-player robbery HAS been driven end to end through the real prompt
  rather than through a module handle — walked into range, `PromptShown` and
  `Triggered` both firing, the smash landing, and the loot model seating at
  exactly `CarryPose.HOLD` with the pose running at Movement priority and
  clearing again on delivery. What has not run is one player actually
  watching ANOTHER carry loot home — the entire reason it publishes
  per-viewer, off the loot model's own presence on the carrier's character,
  rather than through an attribute or a remote.
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
- **Phase 5 (the season, finishes, the nemesis ledger, six new trophies and
  the paging street board) has not run in Studio or against a real
  DataStore.** Every layout that is new is marked unverified in its own
  source: the season chip on the narrowed rank row (the widest star row was
  not photographed at that width), the NEMESIS line and the shortened boasts,
  and `Shared/SeasonBoard`'s local page, which mirrors the server board's
  measured layout without having been looked at. The season board and Top
  Defenders stores have never been written to or read from live, and a
  season tier crossing, a finish on a real pig under the bloom, and the six
  new trophy builders standing on a lawn are all unobserved. Launch fell in a
  rest week, so nothing counts until Season 1's first active week; testing
  sooner needs the `seasonshift` dev command (§16). `Config.SEASON.tiers` are
  solved in the acorn model and are flagged there to be re-derived from
  telemetry before Season 2. `bestSpree` — recorded here previously as read by
  nothing — is now read by the Hot Streak trophy (§9).

`CLAUDE.md`'s "Not yet verified" section is the long-form version of this list
and is kept in more detail.
