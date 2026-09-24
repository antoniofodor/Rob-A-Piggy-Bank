# Rob a Piggy Bank -- the master plan

*The one plan. Written 2026-09-15 against the working tree at schema 24,
replacing `ROADMAP.md`, `core-loop-plan.md`, `nab-plan.md`, `yard-plan.md`,
`shop-vaults-plan.md`, `endless-plan.md` and `economy-design.md`, all of
which are deleted. `CLAUDE.md` is still WHY and `GAME.md` is still WHAT; this
file is WHEN and WHAT-NEXT. Where an older document is named anywhere in the
code or in `CLAUDE.md`, the pointer now lands here, and Part III says where
inside this file the thing it pointed at lives.*

*Every number in Part I was read off `Config.luau` in a running Studio
session (the DataModel copy matched disk byte for byte) or derived from those
reads with the arithmetic shown. Where a number is a guess it says so and
names what would settle it.*

**How to use this file.** Part I is the design as decided: read it before
building anything; section 18 is the asset register that says which of it has
to be drawn before it can be built. Part II is the execution plan and it has
**two tracks**: Phases 0-7, which are systems and are strictly ordered, and
Art 1-11, which are assets and interface and run beside them on their own
clock. Each step names the files, fields and checks it touches; work is
ordered from there and nowhere else. **A step marked [DESIGN] stops and asks
the designer for a look before any of it is built** -- what to ask for is in
section 18.2, and it is a hard stop. Part III is the record carried out of the retired documents --
what shipped, what is still open, what was rejected and why, and the
measurements that justify constants nobody would otherwise re-derive. Nothing
in Part III is a proposal; it is the reasoning that stops a road being walked
twice.

---

## THE ACORN TRACK IS RETIRED (2026-09-21). READ THIS BEFORE BUILDING FROM ANY SECTION BELOW.

**Acorns, the tree, the carry basket, the storage crate, the shake minigame,
the pig-crack acorn and the acorn-ranked season ladder were removed from the
codebase in full.** `data.loot` is deleted (schema 29). There is one currency:
coins.

What forced it was a crate decision rather than a complaint about acorns:
**crates are EARNED or bought with ROBUX, never with in-game currency**
(designer, 2026-09-21). Acorns had two spenders -- crates and set items -- so
once crates stopped taking them there was a whole currency, faucet, minigame,
ladder, HUD tab and save-field set left buying three alien cosmetics. The
reasoning is written up in full in `CLAUDE.md` under **THERE IS ONE
CURRENCY**; `docs/GAME.md` describes what the game is now.

**SO THE FOLLOWING ARE VOID AS PLANS AND SURVIVE ONLY AS RECORD** -- the
measurements in them are still the honest arithmetic of the day they were
taken, and Part III's whole purpose is that a rejected road stays rejected,
so nothing here is deleted:

| section | what it planned |
| --- | --- |
| 3. Acorns are the spine | the currency itself |
| 4. The tree, carry basket and storage crate | the faucet and its geometry |
| 9. Street badges and nearby Acorn cooldowns | the acorn half of it |
| 12. Seasons, boards and achievements | the season RANK; the nemesis ledger and the board's other two pages survive |
| 19 and 19.1-19.6 | the whole re-centred acorn loop |
| Phase 1 -- Acorns | built, then retired |
| Phase 2 -- The tree, carry basket, storage crate and timed collection | built, then retired |
| Phase 5 -- season one | the ladder half |

**WHAT SURVIVED OUT OF THEM, so nobody deletes it by association:**
`Config.seasonIndex`/`seasonEndsAt` (the buy-back claims and the hot-skin
window key off that clock), the NEMESIS ledger, Top Thieves and Top
Defenders, and `Config.FINISHES` -- which is now **unobtainable** until
something grants it again, and is the one real hole this left.

**AND THE ROBUX HALF IS NOT BUILT.** A direct Robux-to-crate purchase puts
every crate inside Roblox's paid random item rule: disclosed numerical odds
summing to 100% shown before purchase, and an `ArePaidRandomItemsRestricted`
gate. That is `docs/PIGGY-COLLECTION-PLAN.md` section 14 / Stage 6, and
`Config.auditRandomOutcomes` now refuses any crate carrying a price until it
ships.

---

# PART I -- THE DESIGN

## 1. Constraints that may not be broken

Settled. Design around them; do not propose removing them.

1. **Nothing may be aimed at a specific player by another player as a
   punishment.** No calling the police on somebody, no targeted griefing
   tools. A gadget can be thrown; an officer can never be pointed.
2. **Under-12 audience.** No weapons, no violence in the model, no mechanic
   that reads as bullying. Roblox's maturity questionnaire is answered by
   what is literally in the game.
3. **Being robbed while offline is impossible** and stays impossible: a plot
   is released when its owner leaves.
4. **A defence buys TIME, never immunity.** No purchase may make a player
   un-robbable, or the offence tree dies and the economy stalls at the top.
   The player-side form of the same rule: **no combination of bystanders may
   reduce a well-played robbery to unwinnable**, and **nothing an owner does,
   in combination with anything they can buy, may reduce the maximum possible
   take to zero.**
5. **No random outcome in this game may be reachable with coins.** Every
   random reward is priced in the earned-only currency, gated behind an
   action, or does not exist. Coins are going on sale, so this is the line
   that keeps every crate outside Roblox's paid-random-item regulation.
6. **Monetisation is named things, never currency that reaches randomness.**
   A Robux purchase may grant a pass, a ride, a stance. Coins are sold only
   under rule 5, and only in the shape section 15 describes.
7. **Two currencies.** Coins and acorns. `data.spares` is a hidden third and
   stays hidden; nothing here adds a fourth.

## 2. The measurements everything rests on

| what | value | where from |
|---|---|---|
| income / capacity, level 0 | 7.4/s, 3,571 -- a pig fills in **8.0 min** | `getIncomeRate`, `getCapacity` |
| level 20, rebirth 0 | 2,995/s, 2.99M -- **16.6 min** | same |
| level 40, rebirth 10 | 128K/s, 96.9M -- **12.6 min** | same |
| rebirth gate | 2.99M at RB0, 17.0M at RB5, 96.9M at RB10 | `getRebirthThreshold` |
| robbing vs idling at the resident floor (2 houses + 4 shops) | **3.21x cold, 6.42x hot**, flat at every level | `robberyRates` |
| one robbery, door to door | 22.25s house, 17.68s shop, 19.21s average | `robberyCycleSeconds` |
| perfect-play deliveries per hour | **187** (the 60s cooldown would allow 360 and never binds) | derived |
| a clean crack takes | 21.9% of a pig at a bare sack, 41.6% maxed | `getCrackTotal` |
| player robberies per victim per hour under `LOSS_CAP` 0.45 | **2.06** bare sack, **1.08** maxed | derived |
| the second currency today | 1 per delivery; 3 / 2 per drone / 3 per raid; +1 on revenge | `LOOT`, `REVENGE` |
| skin steal today | clean five-slice crack on a player, 50% (100% revenge), cap 1 per victim per hour, spares absorb, thief wears it | `SKIN_STEAL` |
| skins | 45, of which **37 stealable** | `isStealableSkin` |
| crates | og 500K / animal 500K / rare 1.5M / legendary 6M **coins** -- all four retiring to acorns (section 6); alien 6 loot | `CHESTS` |
| og crate pool | 7 common, 16 rare, 5 legendary; a specific rare is 2.75% per open, a specific legendary 0.8% | `chestPool` |
| whole coin catalogue, as previously summed | 274.3M | summed |
| what coins can **actually be spent on** | **218.6M**, of which houses are 142.0M (65%) | re-summed, section 14 |
| skins a player may buy with coins | **one** (Solid Gold, 1.5M); 37 are crate-only and 3 are rebirth-gated | `SKINS` |
| effects obtainable by any route today | **none of 7** | `EFFECTS`, and the retired Piggy tab |
| the nab today | a 1.0s tug transfers the intact carry; no tick refunds/bounty; 3s rest follows the holder; dodge breaks it; return/keep settlement implemented (3.3); live two-player check pending | `NAB` |
| the rob badge today | "NEW HERE 1m" for any shield, "ROBBED 54s" for your own per-victim cooldown, EMPTY, or the pig's value in gold; readable to 224 studs | `RobBadge` |
| shop drop today | 20% of clean shop cracks, flat, every shop; a duplicate pays its sell value | `SHOP_VAULT_DROP` |
| audits at boot | robbery 0, skin-steal 0, economy 0 problems | live |

Two derived figures used throughout, both **guesses until telemetry exists**:
a realistic robbing pace is a quarter of the ceiling (**~45 deliveries an
hour, ~15 a session**), and a casual child plays four twenty-minute sessions
a week while a keen one plays two hours a day. Every price and threshold below
is set against those and is re-solved the day there is a number.

## 3. Acorns are the spine

> **Amended September 16 -- see section 19.** The faucet gains a second source and
> the theft rule reverses: a **clean five-slice crack on another player's
> pig mints one acorn** for the thief (residents none), **banked acorns are
> never stealable**, and shaking somebody else's tree happens **only inside
> the Harvest Moon event**. Everything below about the tree as the faucet and
> the shake as the multiplier stands; "the only way one player's acorns
> become somebody else's" is now "the only way, and only during the moon."
> Section 19 is the later instruction where the two disagree.

`data.loot` is the second currency already, already earned rather than
bought. What changes is its name, its scale, where it comes from, and that it
now has a place in the world -- a tree on every lawn, and a basket under it
that other people can take from.

**The name is ACORNS, and they are not gold ones.** `Theme`'s own rule is
that gold means money and pink means the pig, and that is the whole colour
system; a gold acorn would read as a coin, and the one thing this currency
must never do is read as money. They are nut-brown with a green cap and carry
their own hue on the HUD chip and the shop card. The save field stays
`data.loot`, exactly as `data.vault` stayed while the HUD said PIGGY BANK:
renaming a persisted field to fix a label is a schema migration solving a
wording problem.

**Why acorns and not keys, shards, carrots or truffles.** A pig rooting for
acorns is real pig behaviour that needs no sentence of explanation; an acorn
is small and countable enough that a crate can cost five of them; and it can
grow on a tree in a yard, which section 4 is built on. Two alternates lost on
one thing each: *nest eggs* is the better name (a nest egg is literally
savings somebody can take) and pigs do not lay eggs; *piglets* is the most
on-theme word available and it is already spoken for -- `Shared/PetModel.luau`
builds one for the deferred yard pet, and its own comment reads *"a piglet is
a piglet; it is not a small piggy bank."*

**THERE IS EXACTLY ONE ACORN FAUCET AND IT IS THE TREE.** An acorn is never
paid for delivering a pig. That is a correction rather than a trim, and the
reason decides the shape of everything below. The first draft paid acorns per
delivered robbery *and* grew them on a tree -- two unrelated sources for one
currency -- and it put the acorn take inside the crack, which is the thing the
designer refused in one sentence: *robbing acorns through a regular piggy rob
doesn't really make sense.* It does not. **A pig holds coins.** Cracking one
open and being handed nuts is the game asserting a relationship between two
objects a nine-year-old can see are unrelated. Nuts come off a tree, and you
get them by shaking one.

So the whole of the acorn economy is three sentences:

* **A tree grows acorns into a basket** (section 4). That is the only place an
  acorn is created.
* **A shake takes them** (section 5). That is the only way one player's acorns
  become somebody else's, and it is a drag minigame rather than a hold.
* **A crack pays coins and may take a skin; a smash pays coins. Neither ever
  pays an acorn.**

**ONE ROBBERY, ONE CURRENCY EACH**, which is what makes the three jobs on a
plot legible from the pavement: crack the pig for coins, smash it for coins
faster and louder, shake the tree for acorns. Nobody has to be taught which
object holds what, because the objects say so.

**AND A SHOP HAS NO ACORNS AT ALL.** A vault is a room inside a building with
no lawn in front of it; there is nowhere for a tree to stand and a
shopkeeper's takings are money. So a shop pays coins and rolls a drop from its
own shelf (section 10) and that is the whole of what it pays. The acorn drop
rate on a shop vault is not lowered, it does not exist. What that costs is
stated in section 17 and it is the one thing this change genuinely takes away:
under the draft the four tills were **two thirds** of the non-player acorn
floor at a full server -- four shops against two resident houses -- and the
floor is resident trees alone now, which is two of them.

**WHAT CUTTING THE DELIVERY ROUTE COSTS, AND THE NUMBER IT MOVES.** Under the
first draft a player crack paid five acorns and the tree was a supplement:
measured, the delivery routes ran about **72 acorns an hour** from players and
**24** from the NPC floor, against the tree's **one**. That is ninety-nine per
cent of the supply. Cutting it does
not trim the acorn economy, it removes it. So the multiplier that sat on the
delivery moves onto the shake instead, and it is now the only lever this
currency has. **The tree is the faucet; the shake is the multiplier.** Those
are the two numbers, and section 17 is where their product is checked.

**What a shake banks, by whose tree it is:**

| whose tree | the thief banks | why this number |
|---|---|---|
| a resident's | what falls, **x1** | the tutorial target, and the quiet-server floor |
| **a real player's** | what falls, **x5** | the point of the game, and the population lever |
| a player above your rebirth | x5 **plus the gap** | robbing up pays; the rebirth-8 basket is the prize |
| revenge, inside `REVENGE.window` | **x2 on top** | the table already exists and already pays extra |
| nabbed or arrested carrying a basket | half what it holds, rounded down | the attempt is never zero |
| a shop | **nothing** | there is no tree |

**THE VICTIM LOSES WHAT FALLS; THE THIEF BANKS A MULTIPLE OF IT, AND THE
EXTRA IS MINTED.** That is `HEIST_PAYOUT`'s own argument arriving on the
second currency, and this file already records why it exists: *while the
thief's gain and the victim's loss were the same number, every point of
incentive was a point of pain, so the reward could never be raised without
making the game a bullying simulator.* An acorn is worth far more per unit
than a coin -- a full basket is a day of growing -- so a one-for-one shake is
either too cruel to the victim or too thin for the thief, with nothing in
between. Decoupled, a shake that costs a child two acorns can pay the thief
ten, and the two halves can be tuned against different things.

**Population and supply.** Trees grow one raw Acorn per plot per hour.
The x5 player-theft payout helps compensate for sharing that supply. The
revised **new-growth capture model** is 10 Acorns/hour solo and 5.25 per
player/hour at eight players, assuming every fresh Acorn is collected and
all multiplayer player crops are stolen at parity. Each grown Acorn is
counted once; own harvesting and theft cannot both claim it. Seed stock,
repeat theft of stored balances, revenge, missed catches and travel are
outside that model. Section 17 separates those assumptions from observed
play earnings. Payout constants have not changed.

**Residents use a shared quarter-hour raid cadence.** Their coin cooldown
remains unchanged. Opening a valid Acorn round starts a 15-minute deadline
shared by all thieves and both sources, tree and crate. Empty/out-of-range
refusals do not consume it. The prompt displays RESTING m:ss until it ends.
Four starting Acorns are split two ripe/two stored, seeded once per plot per
server lifetime. Residents bank ripe crops while home, after the crop has
been available for at least fifteen minutes. This moves stock; it is not a
refill. Ordinary hourly growth is the only repeating production source.

**THE SPREE MULTIPLIES COINS AND NEVER ACORNS.** A spree that multiplied
acorns would put a hot thief at ten a shake -- two crates from one tree --
and every price below would be wrong by a factor of two for exactly the
players who play best.

## 4. The tree, carry basket and storage crate

> **Amended September 16 -- see section 19.** The tree gains a coin-priced
> ladder (growth rate and cap) and a rebirth bonus on growth while online.
> The storage crate is a **bank**: nothing in it can be raided. The basket
> stays the transport prop for own-tree harvests and for Harvest Moon
> shakes.

**Designer correction, September 2026:** growing stock, carried stock and
spendable storage are separate. This replaces the earlier wallet-growth,
stationary-basket and PACKED design. A player can have eight banked Acorns
and another eight ripe on their tree at the same time.

Every residential plot has the compact imported `AcornOak` at lawnI
(-25, 16) and an **open wooden storage crate** beside it at (-20, 16).
Shops have neither. The tree remains the approved 8.5-stud-wide imported oak;
lawnI stays retired and existing ornaments remain owned but shelved.
The imported woven basket is now exclusively the player's transport prop.
`AcornStorage` supplies a functional 3.6 × 2.8 × 1.9-stud wooden blockout
until the final Blender prop is imported. Art prompt: `assets/crate/BLENDER-PROMPT.md`.

**Growth:** one Acorn per hour online/offline, up to eight **on the tree**.
`treeAcorns` and the partial-hour cursor are saved. Existing `loot` remains
banked storage, uncapped by growth; migration never copies it into the tree.
Time spent at the tree cap is discarded. Coin boosts do not affect growth.
Ripe Acorns stay visible on the tree until shaken.

**Ground:** shaking moves ripe Acorns into `groundAcorns`, not the wallet.
Missed Acorns remain around the trunk for 60 seconds from the shake, allowing
another collection round. A round begun just before expiry gets its full
five seconds. Collection of an existing pile does not shake newly grown
Acorns down; clear that pile first. Growth can resume while a pile is loose.
Ground count and expiry are saved so rejoining cannot duplicate a harvest.
Expired loose Acorns disappear; storage is unaffected. Failed carries return
raw tree Acorns to the ground with another 60-second collection window.

**Storage:** the crate displays an exact count, including zero and large
balances. Decorative contents are bounded to eight meshes for performance;
there is no PACKED label. Deposited Acorns are available to all existing
Acorn purchases, crates and buybacks. The HUD continues to show this balance.

**Resident supply:** `ResidentAcorns` owns one stock record per residential
plot for the server's lifetime; `resident.acornStock` references it. Each
starts with two ripe and two stored Acorns, zero loose. Shops get no stock.
Resident `.loot` remains carried coins. A new crop starting on an empty tree
waits fifteen minutes before a resident at home banks it. Harvesting waits
while loose Acorns or an active collection lease exist; no new NPC carrying
animation is introduced by this stock transfer.

Claiming a plot freezes its resident production/harvest clocks. Releasing it
resumes the same stock and partial growth hour, never another seed. Raid
cooldown and ground expiry continue in real time. An old carried receipt can
refund this retained stock without crediting the new player occupant.

## 5. Timed harvesting and storage raids

> **Amended September 16 -- see section 19.** **Storage raids are retired**,
> and with them the four-acorn rolling-hour loss cap, the resident 15-minute
> raid cadence and the basket-nab acorn settlement. Own-tree collection
> (hold H, the five-second drag round) is unchanged and is the harvest
> minigame. Shaking another property's tree is only possible during the
> Harvest Moon event (section 19.3); outside it the prompt does not exist.

**Tree collection:** hold H (gamepad Y) at a residential trunk for half a
second. One ripe Acorn is enough; loose leftovers can also be collected.
Shaking releases ripe stock onto the ground and opens a **five-second drag
round**. Drag as many available Acorns as possible into the carry basket.
All offered Acorns remain draggable through the timer, rather than falling
out of the panel individually. The collection panel represents the ground
pile; replicated decorative models show that pile around the actual trunk.
Own-tree harvesting has no alarm, theft cooldown, quarter-share or loss cap.
An owner may retry leftovers with their current basket from that same tree.

**Storage raid:** hold J (gamepad X) at another property's crate. The same
five-second interaction moves Acorns from the crate into the carry basket.
The take is a quarter of stored stock rounded down, **at least one if any
exists**, bounded by the remaining **four-Acorn rolling-hour loss limit**.
Uncollected storage stays banked. A player cannot raid their own storage.

**Theft protections:** tree theft and storage raids alert the owner, wake the
dog and drop the thief's shield/sneak. Owner arrival, death, distance, stun,
bins, rides or plot occupant changes interrupt collection. Player-target repeat cooldown
is 60 seconds per thief/victim across both sources. Resident targets instead
share a 15-minute deadline across every thief and both sources; the hourly loss budget
applies to storage only. Active attempts reserve available stock so two
collectors cannot claim the same Acorn. Every drag is verified by attempt ID,
index, server time and current scene state. Shops have no Acorn prompts.

**Carry and deposit:** accepted drags debit one raw Acorn into a carried
basket. An incompatible haul must be deposited first. Only deposit at the
carrier's **own storage crate** credits spendable `loot`. Own harvesting
pays one-for-one and never counts a robbery, creates a grudge or consumes
revenge. Theft keeps the existing resident x1/player x5-plus-positive-rebirth-gap
payout, with revenge doubled, computed at delivery. Coin bonuses do not apply.
A completed stolen basket counts one robbery; coin leaderboards are unchanged.

Nabs, dog/patrol confiscation, death and departures return raw receipts to
the correct source. Storage refunds also release the matching loss budget;
ground refunds never bank the owner's harvest. Receipts prevent duplicate
returns; departure settlement runs before the final save.

The imported basket is used for carried contents (up to eight visible
Acorns). Live gesture/carry/visual review remains part of Phase 2.4. Phase 3's
future claimant/holder transfer design is unchanged.

## 6. Crates, and the Rebirth Crate

> **Amended September 16 -- see section 19.** Crates stay priced in acorns and
> acorns stay unbuyable, so nothing here about compliance moves. What moves
> is the faucet behind the prices -- section 19.5 lists the re-derivation.
> The **coin pack is dropped** (section 19.1), so the "compliance fork"
> below resolves to its option 3 and the standard rolled Rebirth Crate is
> unconditionally fine.

**NO CRATE IS PRICED IN COINS, AND NONE EVER MAY BE.** Every crate, chest,
roll, spin and combine in this game costs **acorns**. The four coin prices
below are struck through rather than deleted so that nobody re-proposes them:
they are what shipped, and the reason they cannot stay is section 16's
invariant -- coins are about to be purchasable with Robux, and a random
outcome a player can reach with purchasable currency is a paid random item
under Roblox's own definition, whatever the button says. The boot audit
refuses `currency = "coins"` on any entry in `CHESTS`, so this stops being a
rule somebody has to remember and becomes a property of the file.

**Crate prices**, solved on acorns per legendary the way the coin ladder was
once solved on coins per legendary:

| crate | was (coins -- retired) | **price (acorns)** | acorns per legendary |
|---|---|---|---|
| Piggy Originals (og) | 500K, 4% | **5** | 125 |
| Animal Kingdom | 500K, 4% | **5** | 125 |
| Rare Crate | 1.5M, 10% | **15** | 150 |
| Legendary Crate | 6M, 35% | **40** | 114 |
| Alien Cache | 6 loot, 15% | **6** (unchanged -- `loot` IS the acorn field) | 40; its POOL is still attendance-gated |

Five acorns is **a lap of the street's trees, or one good shake on a rich
neighbour**, which is the sentence a nine-year-old reads off the price.
`COMBINE.need` stays at 5 -- the ratio was solved against the odds and the
odds do not move.

**What a crate price is measured against now, and it is not what it was.**
When acorns were paid per delivery the price was legible as *one robbery, one
crate*. There is no delivery route any more, so five acorns is measured
against the shake: a thief catching two off a player's tree banks ten at the
x5 multiplier, which is two crates -- so the sentence a player learns is
**shake somebody rich and you can open something.** If the multiplier moves,
these four prices move with it; they are the same number written twice.

**Designer clarification — 2026-09-15:** A rebirth opens a standard free
Legendary Crate with its usual odds and duplicate spares. It does **not** select
the next unowned skin in order. The completed-legendary-collection fallback
remains the crate's Acorn price. This overrides option 1 below and the original
guaranteed wording of step 1.5. Coin sales remain unimplemented; the later
random-reward audit must retain its check for a rolled rebirth reward.

**Rebirth opens a Legendary Crate, and the rebirth-only skins retire with the
drop that handed them out.** Before step 1.5, `ProgressionService` called
`CosmeticsService.rollRebirthDrop`, rolled a rarity and equipped one skin, with a
coins fallback when the pool was empty; and three skins -- **Bronze (rebirth
1), Gold Leaf (3) and Diamond (6)** -- carried an `unlockRebirths` gate instead
of a price, so they were owned by arithmetic rather than by anything in the
save. All of that goes. A rebirth opens a **Legendary Crate**: the same reel,
the same reveal, the same forty-acorn crate everybody else earns.

**The three skins are not deleted, they move into the crate pools**, because
retiring authored art to remove a mechanic is waste and because a skin nobody
can obtain is the effects tab's own bug arriving on the wardrobe. Bronze,
Gold Leaf and Diamond are metals and belong in Piggy Originals; tagged
`chest`, they pick up a rarity from the pool they land in and -- this is the
consequence worth stating -- **they become stealable**, because
`isStealableSkin` is *this skin is in a crate* and that predicate is the whole
of section 7. That is the right answer rather than a side effect: the class
line is *a thing may change hands only if the game can hand it back for
acorns*, and once they are in a crate it can.

**`unlockRebirths` is an ownership route with no save entry behind it, so
retiring it needs a one-time migration and it is the only migration in this
plan.** A player at rebirth 4 today OWNS Gold Leaf in the sense that
`isSkinUnlocked` says yes, and owns nothing in `cosmetics.owned` to prove it.
Drop the gate without granting and their wardrobe silently loses a skin they
earned, with `getSkin` falling back to Classic Pink and nothing in any log --
the exact silent failure this project refuses above all others. So
`DataService.reconcile` grants `owned[key]` for each of the three whose
threshold the save's `rebirths` already clears, once, keyed off the schema
bump so it cannot pay out twice. **A migration that runs on every join is a
money printer**, which this file already records about the retired-ornament
refund, and the check is the same one: prove it idempotent before shipping it.

**What retiring the drop takes with it:** `rollRebirthDrop`, `getDropWeights`,
`LEGENDARY_PITY`, `DROP_RARITIES`, the `unlockRebirths` branch of
`Config.rarityOf` and the matching branch of `isSkinUnlocked`. Four of those
are the pity timer and the weight table for a roll that no longer exists, and
`rarityOf` loses a source it reads before price -- so the three skins need an
explicit `rarity` on the way into the pool, which every crate skin carries
anyway.

**And that walks into the one compliance fork in this plan, stated once.**
The rebirth gate is banked coins (`getRebirthThreshold`, one full pig at your
ceiling). A coin pack that fills a pig fills the gate. With a pack on sale the
chain is *Robux, pack, full pig, rebirth, a random legendary roll* -- a paid
random item by Roblox's definition with nothing in this repo having changed.
Three ways out:

1. **The Rebirth Crate is guaranteed rather than rolled**: it hands over the
   next legendary you do not own, in a published order, with the reel still
   spinning. Nothing is random, so nothing is exposed. **Previously recommended; not selected by the designer**, since
   the standard crate is the requested reward. The original rationale was -- a real Legendary Crate draws `rare 65 /
   legendary 35`, so two rebirths in three would hand over a rare, which is
   a letdown on the hardest button in the game.
2. The pack refuses to open when it would carry a player over their own
   rebirth threshold. It works, and it refuses at exactly the moment somebody
   most wants it.
3. No coin pack, which section 15 recommends on other grounds anyway.

If the pack is dropped, option 1 is unnecessary and a genuinely random crate
on rebirth is fine, exactly as today's drop is fine. **The completion
fallback survives either way:** a Rebirth Crate with nothing left to give
pays forty acorns instead, which is the crate's own price.

## 7. Permanent loss: the class line and the rails

**A thing may change hands only if the game can hand it back for ACORNS.**
That is exactly the shipped predicate -- `isStealableSkin` is *this skin is in
a crate* -- once the crates are priced in acorns, and it settles every case:

| class | stealable? | why |
|---|---|---|
| crate skins (**40** -- 37 today plus Bronze, Gold Leaf and Diamond, section 6) | **yes** | the crate returns them, for acorns |
| banked Acorns in storage | **yes, capped** | section 5 -- quarter share (minimum one), four per victim per hour |
| ripe/loose tree Acorns | **yes** | section 5 -- timed collection, separate from the storage loss cap |
| the free default, alien set skins, pass skins | no | no coin-or-acorn crate returns them; already excluded by the predicate |
| **coin-bought skins (Solid Gold, and anything section 14 adds)** | no | the coin shelf is the safe shelf, and the rule below is what keeps it safe as it grows |
| houses, upgrades, rides, ornaments, coats, kennels, garden, plinths | **no** | their route back is **coins**, and coins are for sale -- so stealing one would create *pay to get your stuff back*, the one shape that turns a robbery game into a complaint |
| trophies, season rank, spares | no | a record of what you did cannot be un-done; spares are insurance, not stakes |
| **anything bought with Robux** | **never**, and audited | `isEarnedElsewhere` already excludes `pass` items; the boot audit asserts it |

So the shop is two shelves with two meanings: **coins buy the safe shelf;
acorns buy the stakes.** A coin buyer can never buy a thing another child
then takes.

**AND THAT IS A RULE ABOUT EVERY FUTURE ITEM, NOT A DESCRIPTION OF TODAY'S.**
Section 14 roughly doubles the coin shelf, and the line that has to survive it
is: **nothing purchasable with coins may ever be placed in a crate pool, and
nothing in a crate pool may ever be given a coin price.** The two halves fail
in opposite directions and both are silent -- a crate item with a price means
money buys a stake, and a priced item in a crate means a child loses a thing
they paid coins for, which is the *pay to get your stuff back* shape this
whole section exists to refuse. `auditSkinSteal` walks both directions at
boot, and it is the check that stops the coin expansion undoing the class
line one item at a time.

**Five rails, four of them shipped.**

1. *Only crate skins* (shipped).
2. *A spare absorbs it* (shipped) -- and a spare now costs acorns, so
   insurance is bought with robberies.
3. *One skin per victim per hour, whoever is robbing* (shipped).
4. *Loud at both ends, and the victim's line names the way back* (shipped).
5. *The buy-back ladder*, below.

**There is no opt-in rail, and cutting it cost nothing.** A player who has
never robbed anybody is wearing Classic Pink, which is not stealable, and the
only way to own a stealable skin is to open a crate, which costs acorns, which
come from robbing. The gate is structural -- the same shape as `canCase`
being a predicate on a rung count rather than a flag -- and needs no field.
What it does mean, stated plainly: a player who buys their first crate on day
one and wears what falls out can lose it that afternoon. The join shield, the
cap, the spare and the ladder are what stand between them and that.

**The chance is 100% on a clean crack.** *Five slices takes the skin* is the
rule, and it is a skill test rather than a dice roll: the fifth window is 30%
of the dial at lock level 1 and clamps to 21% against a maxed Vault Lock. The
shipped 50% was solved against `LOSS_CAP` throttling player cracks to two an
hour; with the rails in front of it a roll adds nothing but the sense that
the fifth slice sometimes does nothing.

**The hot rule is the free route back.** Each delivered stolen skin creates a
claim for its original owner against that robber for `REVENGE.window`, starting
at delivery. A clean revenge crack takes that skin from the robber's ownership
regardless of their outfit. It is carried home under the usual getaway rules;
being caught returns it and reopens the claim inside its original deadline.

**Designer clarification — 2026-09-15:** Claims stack per owner, robber and
skin. The robber taking from another player does not erase an earlier victim's
claim, so several players can recover from the same robber independently.
Only the latest person to take a particular skin from that owner has the valid
claim; a later theft of a different skin does not replace it. Each skin keeps
its own deadline. Spending coin revenge or a subsequent coin robbery does not
consume or extend the skin window. One clean crack recovers one available
claim, oldest deadline first. Claims remain session-local, like revenge.

Recovery revokes the owned copy, bypassing ordinary skin-loss caps and spare
insurance on the robber. If the original loss was an insured spare, delivery
restores that spare; an already reacquired ordinary skin pays no extra copy.
If the robber no longer owns the claimed skin, this crack does not substitute
an unrelated outfit. Paid seasonal buy-back is implemented below.

**The buy-back ladder, and why 3x per step is the right shape.** Losing a
owned skin writes `data.claims[key] = seasonIndex`; for the rest of the season
an exact-skin card beside its source crate carries BUY BACK while unowned, a
direct purchase in acorns with no roll, and the thief
keeps their copy. Measured against the og crate's real pool, rolling for a
specific skin costs:

| you lost | chance per open | opens to expect it | acorns at 5 a crate |
|---|---|---|---|
| a common | 7.43% | 13.5 | 67 |
| a rare | 2.75% | 36.4 | 182 |
| a legendary | 0.80% | 125 | 625 |

A flat "3x the crate" is 15 acorns against all three: four times cheaper than
rolling for a common and **forty-two times cheaper for a legendary**, which
would make the ticket the only sane route and the crate decorative. So the
ticket is **3x per rarity step off the crate's price**:

| you lost | ticket | rolling | the ticket is cheaper by |
|---|---|---|---|
| a common | 3 crates = **15** | 67 | 4.5x |
| a rare | 9 crates = **45** | 182 | 4.0x |
| a legendary | 27 crates = **135** | 625 | 4.6x |

That constancy is not arranged: the rarity odds are themselves roughly a
factor of three apart, so a 3x-per-step ladder and the roll it replaces move
together, and it stays right if the odds are retuned where a flat number
would not. A legendary buy-back is twenty-seven real-player robberies,
against a free route inside ten minutes that costs nothing but a fight.

**The sixty seconds after.** The plaster, the toast naming thief and crate,
the revenge marker over the thief's plot and the thief wearing the skin are
all shipped. The shared objective card now carries **GET IT BACK**, the
robber's name and a countdown after delivery, then **BUY IT BACK -- 135
ACORNS** when the window closes (while the seasonal claim is valid/unowned).
Before delivery it says to nab the fleeing robber; a recovered carry says
**GET IT HOME**. A tap on the paid objective opens the matching Crates card.
Stacked claims prioritize a current carry/chase, then the earliest live
recovery deadline, with the remaining count shown. Insured spares have no paid
fallback. Returning/reacquiring the skin clears its objective; onboarding
resumes only if the first job is still unfinished.

## 8. The nab is a hand-off

Phase 3.2 now implements the one-second tug handoff; ticks move no currency.
**The nabber takes the intact pig or basket and becomes its holder.**
Phase 3.3 now implements the return/keep settlement choices. The tug keeps everything
that made it safe -- the hold, the dodge that breaks it, the crowd that
joins without speeding it up, the rest stamped on the thief -- and changes
only its ending.

**The three exits, on the new carrier's own prompt card:**

| the nabber... | delivers where | gets | the victim gets |
|---|---|---|---|
| **keeps it** | their own pig | half the raw coins or Acorns, rounded down, and **the whole haul** -- a stolen skin goes with the pig | nothing more than they had already lost |
| **returns it** | the victim's pig (the drop-off radius on the victim's own plot) | the bounty, minted, `NAB.bounty` of what came back | every coin, and the skin, if one was in the haul |
| **is nabbed in turn** | -- | -- | -- |

A nabber who is the victim carrying their own coins home is the return case
by construction, and still collects the bounty: a defender who catches their
own thief is the only person in the game who is paid for defending, and that
is right.

**The original thief can take it back for their full claim.** The carry
record gains a `claimant` alongside its `holder`. Whoever delivers it home
while holding it is paid by whether they are the claimant: the claimant gets
the full doubled worth and the full acorns, anybody else gets the halves
above. So a robbery becomes a **hot potato** in which the person holding it
is always the slowest person on the street (carry speed 12 against 16), and
the one who wants it most is the fastest. That is a chase with a shape.

**What keeps it from being the swarm.** The rest (`NAB.cooldown`, 3s) is
stamped on whoever is carrying after every tug ends, so a fresh carrier gets
the same breath the old thief had, and the swarm bound -- a carrier is under
a tug at most a quarter of any stretch of time -- carries across unchanged.
A confiscated pig cannot be re-nabbed inside that rest, and the dodge still
breaks a tug outright. The measured derivation of why this bound exists is in
Part III D1.

**What the hot rule does with it.** The grudge and the revenge marker are
written at the grab against the claimant. If somebody else delivers the pig
home, the victim's marker moves to the deliverer -- because that is who has
their skin now -- and the claimant, who lost it, is nobody's target for it.

**What does not change.** The dog's catch stays binary and returns the coins
outright: an NPC has no decision to make. The patrol's arrest stays a
confiscation with its own scene. One bounty is minted to the return deliverer,
in the returned currency and rounded down; no per-participant payout is made.
Own harvests and claimant undos earn no bounty. And the staged-robbery arithmetic still refuses
the farm: a pair who rob, nab and keep give up the claimant's full 2.0x to
collect 0.5x, so the honest play is still to deliver.

**What is traded away, stated plainly.** The tug's per-tick partial outcome
-- *the thief got home with less* -- is gone. Its replacement is a different
partial outcome: *the thief got it back*, or *a stranger ran off with it*.
That is a better story and a worse guarantee, and the two-player session is
what decides whether it reads.

## 9. Street badges and nearby Acorn cooldowns

**Designer-approved September 16:** warm cream street badges show coin worth
or one blocking state, plus a small recovery tag. No Acorn counts or Acorn
cooldown row on the street badge: players inspect the tree, ground and storage
crate themselves. The carried basket remains transport.

* **NEW HERE / SHIELD:** while a shield is active, `NeedsFirstJob` selects
  NEW HERE; returning players see SHIELD and the remaining time. A finished
  or dropped shield never stays protected just because onboarding is unfinished.
* **ROBBED / EMPTY / CAPPED:** the viewer's coin cooldown, empty balance and
  hourly loss cap follow the server's refusal order. `CappedUntil` comes from
  the actual loss allowance/window and clears when income, refunds or expiry
  reopen it. Rush worth and unlocked lock pips remain on available targets.
* **RECOVER SKIN:** the rightful owner sees this tag on the last robber's plot
  while their private recovery claim is valid. Bystanders see HOT SKIN when
  any valid claim remains. Neither depends on the robber's equipped skin.
* **Personal recovery task:** a compact icon renders the actual stolen skin,
  with its countdown (or CHASE/HOME during transport). Selecting it expands
  the robber/skin details. Multiple claims retain their independent timers;
  the task prioritizes getting a carry home, an active chase, then the earliest
  recovery deadline. Other claims remain available as the current one resolves.
* **Nearby Acorn cooldown:** at the normal tree/crate interaction range, an
  hourglass and **Steal ready in 0:54** replace the ready action. Only the
  affected viewer sees their player-target cooldown; resident rest remains
  shared. The same deadline covers both sources. Own harvesting is exempt.
  Both prompts return to normal at expiry without needing a new server packet.

Implemented in Phase 3.4. Automated state/expiry checks pass. The remaining
art gate is a real pavement view showing all four badge states legibly at plot
spacing; badges remain occluded by the world (`AlwaysOnTop = false`).

## 10. Shop drops are smaller, and the wheels shop is gated

Phase 4.2 replaces the former flat 20% shop drop with the per-shop rates below.
The first change was the removal of shop Acorns.

**A SHOP PAYS NO ACORNS.** Not a lowered rate, not a rarer drop -- none. It
has no lawn, no tree and no basket, so there is nothing on a forecourt for a
shake to take and nothing in a delivery toast to add. What a shop pays is
coins and a chance at the shelf below, and that is the whole of it. The
15-minute acorn cadence in section 3 is about resident baskets and nothing
else, and section 17's NPC floor is counted in resident trees rather than in
targets.

**A robbing rank, from lifetime deliveries.** `data.robberies` counts every
delivered robbery, any target, and the RAP SHEET RANK is read off it:

| rank | deliveries | about |
|---|---|---|
| 0 | 0 | the first session |
| 1 | 25 | a couple of evenings |
| 2 | 100 | a fortnight, casual |
| 3 | 400 | a keen month |
| 4 | 1,600 | the long game |

It is a count rather than coins stolen because coins scale with level (a
level-40 thief takes more in one delivery than a new one takes in an
evening); a count means the same at every level. It is also the achievement
ladder section 11 hangs trophies on, so it is one number doing two jobs.

**The drop table, per shop:**

| shop | drops | chance | gated at |
|---|---|---|---|
| Piggy Outfitters | skins, effects | **10%** | -- |
| Home & Garden | ornaments | **8%** | -- |
| **Wheels & Kit** | rides | **3%** | **rank 2** -- no ride drops before a hundred deliveries |
| Lock & Key | consumables | 20% | -- |

The consumable shop keeps its 20% on purpose: it is the on-ramp, the counter
to the wall priced above the players the wall stops, and a plunger is not a
prize. A ride is 25,000 to 4.5M coins and the top of the coin shelf, so it is
the smallest chance and the only gated one. `auditSkinSteal`'s standing rule
-- a player must be a bigger prize than a shop -- is checked against the
largest of these rather than one flat number.

## 11. The rest of the yard: reputation

The tree is the yard's production half. This is the half a thief reads, all
of it from the pavement:

* **The plot sign** gains the season tier as a coloured chip, the rap sheet
  rank as a star row, and a NEMESIS line (the counterparty who has robbed you
  most this season, from a twenty-row ledger on the save). A thief choosing
  a target reads *how good is this player* off the sign, *how much is in it*
  off the basket and the badge, and robbing up pays more acorns.
* **The trophy shelf is the achievement track**, and it stands on the lawn:
  a thing you did is a thing on your grass. Four today; the rows below are
  data on the existing `TROPHIES` shape, each with a builder the size of the
  kennel's:

  | trophy | counts | exists in the save? |
  |---|---|---|
  | Hot Streak | `bestSpree` | yes, tracked and read by nothing |
  | Old Hand | `robberies`, the rank ladder | section 10 |
  | Clean Sheet | clean five-slice cracks | new counter |
  | Season Cup | best tier last season | new field, written at rollover |
  | Wanted Poster | times on the Most Wanted board | new counter |
  | Van Job | clean cracks on the Cash Van | new counter |
  | Good Harvest | acorns grown and kept, lifetime | new counter |

  Mastery per target -- a row per shop and house tier of the ways it has
  been robbed, filling 85% unlocking an approach -- is the long form and is
  Phase 7.
* **The pig wears the last skin taken** and **the victim shelf shows every
  skin ever robbed** (both shipped).

## 12. Seasons, boards and achievements

* **A season is four weeks and a rest week.** Roblox's own guidance and the
  cadence a one-person live-ops budget can keep.
* **Season rank is acorns earned this season.** It cannot go down, because
  acorns are only ever earned, so the rank floor comes free. `WEEKLY_HEIST`
  already keys its store by week index; the season is the same key divided
  by five, the reset is lazy, and last season's page stays behind it.
* **Ten tiers, rewards lock in on reaching them**, sized against the acorn
  rates in section 3 and geometric at 1.85 -- a casual child's sixteen
  sessions land around tier five and a keen player reaches ten in the third
  week -- and **re-derived from telemetry before season two** (section 17):

  | tier | acorns this season | reward |
  |---|---|---|
  | 1 | 3 | the tier chip on the sign |
  | 2 | 6 | a plinth style |
  | 3 | 10 | a common finish |
  | 4 | 18 | a coat or kennel |
  | 5 | 32 | a rare finish |
  | 6 | 60 | the Season Cup trophy |
  | 7 | 110 | a catch effect |
  | 8 | 200 | a legendary finish on a skin you own |
  | 9 | 380 | the season title on the sign |
  | 10 | 700 | **the season finish, never sold again** |

  **These came down by three and a half times when the delivery route was
  cut**, and that is the clearest illustration of what section 3 actually
  moved. Solved against the first draft's 72 acorns an hour, tier ten at 2,500
  was a keen player's third week; solved against the shake alone -- about 20 a
  day for a keen player at two hours, 28 days in a season -- the same third
  week lands at about 700. **A tier table is a function of the faucet**, so it
  is re-solved every time the faucet or the multiplier moves, and it is the
  second number telemetry produces.

* **Finishes are the content, and they cost no upload.** A finish is an
  addition over a skin that exists -- an aura, an animated trim, a
  reflectance, a glow -- applied in `applySkin` from a `finish` field beside
  `skin`. Five finishes over 45 skins is 225 collectables from art already
  authored. Never a body repaint: legendary skins carry baked textures, and a
  colour multiply over a texture is the muddy pig again.
* **One rule per season, kept if it lands.** Season 1: Harvest Saturday.
  Season 2: the Cash Van. Season 3: a heat modifier.
  The rule is a Config flag and it is the month's content. (Season 1 was
  *shops pay double acorns on Saturdays* while shops paid acorns; it is
  **Harvest Saturday** now -- every tree on the street drops at twice the
  rate for the day, which raises the faucet rather than one target's rate and
  therefore raises what there is to steal as well as what there is to grow.)
* **Three boards and no more.** Top Thieves this week (exists); **Top
  Defenders** this week (nabs returned, dog catches, hot skins recovered --
  so defending is a collection rather than a tax); and the season board,
  drawn **five above and five below the reader**, because a global top-eight
  produces one euphoric winner and seven demoralised children.
* **Nothing tells a player their standing outside the top eight today**, and
  nothing in the game is time-limited. Both are what the season is for.

**Live-ops cost, honestly:** one rule flag, one exclusive finish and one
tier-table check every five weeks. No new art. About a day.

## 13. Events as structure

> **Amended September 16 -- see section 19.** A third roster row, **Harvest Moon**,
> is the only window in which acorns can be stolen. Section 19.3.

An event is load-bearing when it is **the sole source of something the season
needs** and **scheduled so a child can plan to be there**. The first is
already true; the second is new.

**AND THERE IS ONE RULE ABOUT WHAT AN EVENT MAY PAY, because section 3 left
exactly one acorn faucet and an event is the obvious place to open a second
one by accident.** An event may **raise the faucet**, **hand over a crate**,
or **pay coins**. It may never mint an acorn. The draft of this section broke
that three times in five bullets -- a raid paying ten acorns, a van paying
double acorns, Rush Hour moved onto acorns -- each of which is a tree that
does not exist, and between them they would have been a larger acorn source
than every tree on the street. Rewritten against the rule, every one of them
gets *better* rather than smaller:

* **The weekly moment.** One raid a week at a published UTC time, with the
  standing countdown chip counting down to it for the six days before. It pays
  **a free crate open** rather than a handful of acorns -- which is the day
  seven rung's own argument (*a crate open lands on the permanent cosmetic
  track, the one thing an hour of idling cannot buy*) and is a far louder
  reward than ten nuts.
* **The Cash Van, zero art, and it is a CASH van.** The delivery van already
  drives the street and confers nothing. As an event it stops mid-street, its
  cargo is a pig nobody owns -- no `LOSS_CAP`, no victim, no alarm -- and
  every clean crack on it pays **uncapped coins** for ninety seconds. A
  robbery of nobody is the one co-operative thing this design can add without
  a bullying surface; it is the quiet-server answer, since a van comes whether
  or not anybody else is online; and it is the only uncapped coin source in
  the game, which is worth more to the coin side than an acorn payout ever was
  now that section 14 has a shelf to spend it on.
* **Rush Hour stays on coins**, and the draft's move of it onto acorns is
  withdrawn. It is a coin event, it always was, and the sentence a player
  reads -- *steals are double* -- is about the thing in the pig.
* **Harvest Saturday is the acorn event, and it is the only shape one can
  take.** Every tree on the street drops at twice the rate for the day. That
  raises the faucet rather than minting beside it, so it lifts what a passive
  player grows AND what a thief can take in the same move, and it needs one
  Config flag. It is season one's rule (section 12).
* **The set drops stay attendance-only** and the alien chest stays at six.

## 14. The coin catalogue has to grow, and it was thinner than anybody thought

Crates leave coins in section 6. That is correct and it takes something with
it, so this section is the bill.

**FIRST, THE MEASUREMENT, BECAUSE THE ONE THIS PLAN HAS BEEN QUOTING IS
WRONG.** Section 2 has carried *whole coin catalogue 274.3M* since it was
written. Re-summed entry by entry against the live `Config`, what a player can
actually hand coins over for is **218.6M**, and the gap is skins: 37 of 45
carry a `chest` tag and 3 carry `unlockRebirths`, so their `cost` is a rarity
input and a sell cap and has never been a price anybody could pay. **Exactly
one skin in this game is buyable with coins** -- Solid Gold, at 1.5M. The
other 35.5M of "skin catalogue" was a column being added up.

Where the 218.6M actually sits:

| shelf | items | coins | share |
|---|---|---|---|
| houses | 9 | **142.0M** | **65%** |
| lawn ornaments | 18 priced of 23 | 34.3M | 16% |
| kennels | 6 | 16.5M | 8% |
| dog coats | 6 | 14.1M | 6% |
| rides | 5 priced of 6 | 6.1M | 3% |
| the garden (borders, paths, window boxes) | 11 | 3.8M | 2% |
| skins | **1** | 1.5M | 1% |
| dog toys, home items, consumables | 14 | 0.3M | -- |
| **effects** | 7 authored | **0 obtainable at any price** | -- |

**So coins buy a house ladder and a garden, and that is very nearly all.**
Two thirds of the shelf is nine buildings; a third of it is things standing on
grass; and the one category that is pure light-show spectacle cannot be bought
at all, because the Piggy tab was retired with the skins and the effects went
with it and there is no effects crate to catch them (the price spread is
missing -- three commons and two rares, no epic, no legendary, which is a
content gap rather than a code one).

**WHY THIS IS URGENT NOW RATHER THAN A TIDY-UP.** Three things have left the
coin side in one pass: the crates (8.5M of *repeatable* sink, the only
repeatable one that was not a consumable), the rebirth skin drop, and -- as of
this plan -- the whole idea that coins are what a collection is bought with.
Meanwhile section 15 puts coins on sale for Robux. **A currency that is for
sale and has nothing left to buy is a refund request**, and the honest version
of the pack's card cannot be written until the shelf behind it is worth
opening.

### 14.1 The rule every added item has to clear

**Nothing bought with coins may ever enter a crate pool, and nothing in a
crate pool may ever be given a coin price.** That is section 7's class line
stated as a constraint on future content rather than as a description of
today's, and it is what keeps *coins buy the safe shelf, acorns buy the
stakes* true while the safe shelf doubles. The boot audit walks it both ways.

**And nothing added may touch an outcome.** A coin-bought thing may change how
the plot looks and may never change the steal, the chase, the tag, the
getaway, the tree's rate, the tree's cap or the storage-raid share. The yard
already has this written down -- *a cosmetic may never imply a tier that has
not been bought* -- and the expansion is where it gets tested, because a fence
STYLE and a fence TIER are one object wearing two meanings.

### 14.2 The shape of the expansion: sideways, never upward

> **Superseded in part, September 16.** "No room above the catalogue" was
> true of a 96.9M ceiling. `docs/LATE-GAME-ECONOMY-PLAN.md` extends the
> ladder to level 60 / rebirth 20 (top pig 1.24B) so the eighteen-house
> catalogue to 1B fits; that file is the later instruction on capacity,
> house ownership by id, and the Legacy reset. The *sideways* shelves below
> are unaffected and still wanted.

**New planning target, September 16:** the user requested price coverage up
to 1B. This reopens the former 96.9M-only scope; it does not itself change
capacity or approve live prices. `assets/houses/docs/HOUSE-CATALOGUE-PLAN.md` proposes 18
houses and records the required affordability/ownership decisions. Earlier
~400M catalogue targets below are historical sizing assumptions pending the
new price plan. Shared themed trophy rooms are approved as the approach.

**Current priority, September 16:** the user deferred fence expansion and
requested higher-tier house **exterior** catalogue mockups. Interiors remain
a future implementation task. The user subsequently approved the direction
of displaying earned achievements and trophies **inside houses instead of
in the yard**. A shared themed trophy-room approach is proposed in
`assets/houses/docs/HOUSE-TROPHY-ROOMS.md`; its architecture/art/visiting rules are not yet
implemented or approved in detail. Three exterior
concept sheets and exact prompts are saved under
`assets/houses/design/`; selection, prices and progression are
not approved yet. Preserve existing saved house ownership when expanding
the catalogue; do not silently reorder its numeric levels.

`auditEconomy` refuses any price above `getCapacity(ABSOLUTE_MAX_LEVEL)`,
which is **96.9M**, and the Sky Castle at 80M is already 83% of the largest
pig this game can produce. **So there is no room above the catalogue, only
beside it.** Every figure below is breadth: more things at prices that already
exist, not a tier above the top.

| shelf | today | add | added value | reuses |
|---|---|---|---|---|
| **standalone piggy effects — cancelled September 16** | retired by user direction | do not restore this shop; piggy effects are coin-deposit feedback and Legendary skin visuals only | **0** | legacy definitions retained for skins/save compatibility |
| **house interiors** | none -- a house is a facade | 8 interior styles, priced per tier band | **~90M** | `LowPoly`, and the room `ShopFront` already builds |
| **the yard** | 11 garden items | tree and basket styles, **fence styles** (the panel, never the height or the hazard), driveway surfaces, mailboxes, gate and plot-sign styles -- about 28 items | **~45M** | `Decor`, `Config.fenceMesh`, the driveway builder |
| **the dog** | 15 coats, kennels and toys | 12 more, and a second animal | **~35M** | `GuardDog.applyTier`, the wardrobe/kennel split |
| **rides** | 6 | 4 more, plus trails and accents that change no speed | **~25M** | `RideModel`, `RidePose`, `RideSound` |
| **ornaments** | 23 | 15 on the candy-garden direction already set | **~25M** | `Decor.buildOne` |

With the effects shelf cancelled, the remaining estimate is **+220M against 218.6M**, or **~439M**; re-audit the live catalogue as each shelf lands,
and houses fall from 65% of it to 31% -- which is the number that actually
matters, because a catalogue that is two thirds one category is a catalogue
with one decision in it.

**The original plan prioritized house interiors** (now deferred behind
exterior work), for a reason that is not the money: the shops acquired an
inside this year and houses did not, so the most expensive object a player
owns is a facade they cannot walk into. It is also the one shelf where the
work is already done once -- `Config.shopRoomHolds`, the plinth-is-a-ring
lesson, the light-masonry/dark-joinery palette -- and a second use of that
work is cheap where a first use was not.

### 14.3 What this does not fix, stated plainly

Even doubled, **the whole coin shelf is about 1.0 hours of income at level 40
rebirth 10** (128K/s), against 0.47 hours today. Adding a third as much again
would buy another twenty minutes. **The coin catalogue cannot be made to last
at endgame income, and no amount of content fixes it**, because the pig is
bounded: the largest price the audit can admit is one pig, and the endgame
earns a pig every 12.6 minutes. That is arithmetic, not a content shortfall.

**So say what coins are for rather than pretending.** Coins are the **mid-game
currency**: they carry a player from their first plot to a finished house and
a full yard, which is the seventeen-day climb this project already measured,
and they are the thing a time-saver pack can honestly sell against. The
**endgame is acorns, rank and seasons** -- three tracks that are earned by
robbing people and cannot be bought at any price -- and that is the whole
point of this plan. An expanded coin shelf is not a fix for the endgame; it is
what stops the *first fortnight* being thin, and the first fortnight is when a
nine-year-old decides whether to come back.

## 15. Selling coins without selling a complaint

> **Decided September 16: the coin pack is dropped.** Coins are never
> purchasable with Robux, which restores `CLAUDE.md`'s standing rule and
> this section's own *stated disagreement*. Monetisation is a season pass
> and named cosmetics (stances, pets, rides, the pack skin). The design
> below is kept as the record of what a pack would have needed; nothing in
> it is scheduled. `COIN_PACK.productId` stays 0 and the audit keeps
> refusing a live id.

The decision to sell coins stands; this is how to make it survivable.

* **The pack is one pig-fill, never a flat number.** Its value is
  `capacity - coins` at the moment it is opened -- 3.5K for a new player,
  97M at the top -- which is *the same eight to seventeen minutes of income
  at every level*, the daily ladder's own rule applied to the one thing money
  buys. It cannot stack past a full pig, and a full pig stops earning, so a
  buyer who does not spend is wasting it.
* **It arrives as a parcel on the doorstep**, on the crate box that already
  holds the day-seven chest, and is opened at the pig when the player
  chooses. Unopened it is not in the pig and cannot be robbed. That is the
  offline-earnings-in-a-crate shape and not the rejected yard stash: the
  parcel holds nothing the player earned and cannot be topped up.
* **The card says what happens next:** *"Coins in your piggy bank can be
  robbed. Spend them."* Once opened, every bought coin is stealable at the
  game's own rule. Nothing softens that, because softening it is the timed
  shield this plan rejects.
* **Coin sales remain a later design gate.** The designer selected the
  standard rolled Rebirth Crate in section 6. The original prerequisite of a
  guaranteed reward therefore has not been met. Resolve that interaction,
  complete the boot audit and build the coin shelf before setting a pack's
  product id.
* **Stated disagreement, for the record.** In this genre the products that
  sell are named things, and a coin pack in a game whose every coin is
  stealable will generate refund requests that name the game's own rules.
  The product that sells better and is cleaner is a **season pass**: a
  premium reward track beside the free one, cosmetic only, named things, no
  currency. Ship it first; the pig-fill can ship beside it.

**What the coin buyer gets:** the coin shelf and the 676M upgrade ladder to
level 40, faster. Nothing on the board, nothing in a crate, no skin, no
finish, no tier, no acorn, no stake. **That shelf is 218.6M today and about
455M once section 14 lands** -- twenty-five hours of standing still at level
20 and about an hour at level 40, which is the honest shape of a time-saver
and the reason the pack is worth buying in week one and worth almost nothing
in month two. Say that on the card rather than discovering it in the reviews.

## 16. The random-outcome sweep

> **Amended September 16 -- see section 19.** With no coin pack the invariant
> below is satisfied trivially rather than by construction, and the "honest
> grey area" grows one entry: coins buy tree levels, tree levels grow
> acorns, acorns open crates. Recorded, not designed out -- it is the same
> class as boots making cracks more frequent, and it is the reason the
> no-pack decision is load-bearing rather than a preference.

The crate invariant: **no random outcome is priced in coins.** The original
coin-gate rule has one explicit designer correction: rebirth opens a standard
random Legendary Crate (1.5), so the future coin pack must stay disabled while
that reward remains. The boot sweep reports a live coin-pack id as a conflict;
it does not silently replace the approved crate with a deterministic skin.

| outcome | costs / gated by | Robux-reachable? |
|---|---|---|
| og / animal / rare / legendary crates | acorns | no: an acorn is created only by a tree growing one and moved only by a shake; nothing converts coins to acorns; acorns are never sold |
| Alien Cache | acorns | no |
| combining five spares | spares from acorn crates | no |
| the day-seven crate | seven consecutive days | no |
| shop drops (3-20% of clean shop cracks) | a clean crack, and rank 2 for rides | no |
| event drop reel | attendance | no |
| skin theft | *not random* -- 100% on a clean crack | not applicable |
| the basket shake | *not random* -- what you catch is what you get | not applicable |
| a shop vault | pays **no acorns at all** (section 10) | not applicable -- there is nothing to reach |
| everything section 14 adds to the coin shelf | coins | not applicable -- **none of it is random and none of it may enter a crate** (7, 14.1) |
| **the Rebirth Crate** | a rebirth, gated by banked coins | standard random Legendary Crate by designer correction; `COIN_PACK.productId` must remain 0, and a live id triggers the audit |
| season tier rewards | acorns this season | no |
| the tree's growth | a flat rate, capped at eight | not applicable |
| daily boosts | attendance; accelerate coins only | do not multiply tree growth or shake payouts; the approved random rebirth reward still exists |

**The one honest grey area.** Coins buy Speed Boots and Lockpicks, which
make clean cracks more frequent, so a coin buyer earns acorns faster. Under
Roblox's definition that is not a paid random item -- the *price* of every
random thing is acorns -- and it is the same class as a bought sword farming
drops. Measured, it is small: maxed boots take the cycle from 22.25s to
21.00s, six per cent. Recorded rather than designed out, because designing it
out means un-coupling offence upgrades from coins.

**A boot audit makes the invariant a property of the file:** walk `CHESTS`
and refuse any `currency = "coins"`; walk every catalogue and refuse any
`pass` item `isStealableSkin` admits; refuse `SKIN_STEAL.chance < 1`; refuse
a Rebirth Crate that rolls while a coin pack has a live product id; **refuse
any item carrying both a `cost` and a `chest` tag, in either direction**
(section 14.1); and refuse any surviving `unlockRebirths` field, which is the
retired route and would otherwise hand out a skin nothing else in the game
knows about. Warn, never throw.

## 17. Numbers to re-derive, and the five products

**To re-derive before anything ships:** the shake multiplier and the resident
multiplier (3 -- these are now the only levers the acorn economy has); the
resident acorn cadence (3); the storage raid share and hourly loss cap (5 -- the
growth rate and the cap on the TREE are derived from `OFFLINE_CAP_SECONDS`,
these two are judgement); the four crate prices (6); the ten tier thresholds
(12); the buy-back ladder (7, derived from the real pool odds); the nabber's
keep share (8); the rank thresholds and the per-shop drop chances (10); the
six added coin shelves (14); and the pack's size (15, equal to capacity by
construction).

**Product one — new growth versus population.** Trees produce at most ten
raw Acorns/hour on a ten-house street. The model assigns each to exactly one
harvest/deposit. In solo play, the owner collects their own crop and steals
resident supply at x1. With multiple players, the upper scenario assigns all
player crops to theft at parity x5 and all resident supply to theft at x1.
This is a **new-growth capture ceiling**, not expected earnings or a ceiling
on all possible income. Stored balances can be stolen again; that circulation,
opening seeds, revenge, rebirth differences and the approved rebirth completion
bonus are outside this calculation. Misses, expiry, absence and travel reduce
fresh-supply capture.

| Players / residents | New-growth banking, whole server | Per player/hour | Opening resident seed |
|---|---:|---:|---:|
| 1 / 9 | 1 own + 9 resident = 10 | 10 | 36 |
| 4 / 6 | 4 × 5 + 6 = 26 | 6.5 | 24 |
| 8 / 2 | 8 × 5 + 2 = 42 | 5.25 | 8 |

Seed is **four total per resident**, created once per server plot and excluded
from hourly supply. If multiplayer crops are harvested by their owners instead,
the full-capture banking scenario is 10 / player-count per hour: 1.25 at eight
players. Mixed play sits between these fresh-supply scenarios. The old
5.625/full estimate double-counted some player stock as both own harvest and
theft and is superseded. Actual rate needs play telemetry; payout remains x5.

**Product two — illustrative daily comparison.** The existing audit scenario
assumes an eight-Acorn overnight harvest already deposited, one storage raid
costing two, and two additional active hours at the fresh-supply capture ceiling.
It yields passive 6/day, active 28 solo or 18.5 at eight players, ratios 4.67x
and 3.08x. These conditional figures keep the 3x audit check; they do not
promise that players achieve them. Harvest theft before banking can lose more
than the assumed storage raid. The scenarios must not be presented as live rates.

**Product three — storage protection.** The four-Acorn rolling-hour loss cap
protects **stored** balances. Tree and loose stock are separately stealable,
so the older claim that a player's total worst-hour loss is four is false.
Storage refunds release their matching loss receipts. The resident 15-minute
cadence is shared across all thieves; invalid opens do not consume it. The
server's initial stock, partial growth, automatic banking and reseating are
checked for conservation, including old carry refunds.

**Product four — crate prices versus fresh supply.** Common/Legendary costs
remain 5/40. At the full-server fresh-supply ceiling of 5.25/hour, those are
57.14 minutes/7.62 hours; they are scenario-based reference times. Re-raids of
stored balances may increase income, while gameplay losses/absence reduce it.
Measure actual collection and deposit rates before changing multiplier, prices
or growth. The current change does not rebalance those constants.

**Product five -- tier thresholds against the realistic pace.** Section 12's
thresholds now assume about twenty acorns a day for a keen player rather than
the first draft's seventy an hour, and they came down 3.5x on that alone.
Set from a guess that is half the truth, keen players finish in week one; set
from double, nobody sees tier ten. **The realistic pace is still the first
number telemetry has to produce.**

**And the old one, wearing new clothes:** the spree is a flat multiplier on
coins and must stay off acorns.

---

## 18. Assets: what has to be made, who makes it, and where the work stops to ask

Everything above is systems. This is the other half of the same plan, and it
is written down because it has a different critical path: a mechanic is
finished when it is verified, and an asset is finished when somebody has
LOOKED at it and said yes. Nothing in Part II can be scheduled honestly
without knowing which steps stop and wait for that.

### 18.1 The four ways a thing gets made, and the one that carries real risk

**Where source art lives:** `blender/pig/` is the pig's own pipeline and has
its own contract in `WORKFLOW.md` and its own `paths.py`; everything authored
outside it -- Meshy, Studio's generator, anything hand-modelled -- goes in
`assets/<thing>/`, one folder per named thing, named after its `Config` key.
`assets/README.md` carries that convention and the upload limits every mesh
has to clear. The uploaded id itself goes in `Config` with a comment naming
the source, because one place cannot disagree with itself.

| how | what it means | used for |
|---|---|---|
| `CODE` | built in Luau at server start, from primitives or `LowPoly` | the default and the reason this repo IS the project -- the ground, the houses, the shops, the dogs, the rides, every ornament |
| `GEN` | Studio's AI `generate_mesh` / `generate_texture`, uploaded and referenced by id | the pig, the street tree, the grass tuft, all five fence panels |
| `EXT` | authored in outside software by the designer, uploaded by the designer | four animal legendaries already waiting; the dogs, from this plan onward |
| `UI` | a screen or an element, drawn in code from `Theme` and `ShopStyle` | every panel, chip, card, badge and banner in the game |

**`GEN` IS THE ONE WITH A PRICE ON IT AND THE PRICE IS THE DEVELOPER'S OWN
ACCOUNT.** `generate_material` was run twelve times in one session to compare
candidates and the account was actioned for an asset named *Generated
RoughnessMap* -- a greyscale noise map with nothing depicted in it. One call
returns four variants of four maps: **sixteen uploads**, published under the
developer's name, moderated like anything else they publish, and never seen by
anybody. The blast radius is the ACCOUNT rather than the experience, which is
worse than every other moderation entry in this project, and it presents as a
broken Studio login (403s across DataStores, sounds, meshes and
`GetProductInfo` at once). So: **generate one or two candidates, never a
dozen, and look at every one as a publication.** Mesh generation is a smaller
surface -- one mesh and one texture rather than sixteen maps -- and it is the
same rule, not a different one.

### 18.2 The design gate

A step marked **[DESIGN]** in Part II may not start until the designer has
handed over the look. It is a hard stop, not a preference: an asset built to
a guess is an asset built twice, and this project has already paid that twice
over -- the rickety fence that came back as *cream posts with pale blue rails*
because the prompt never said "dark brown", and four rounds of whack-a-mole on
a mask assembled from spheres because nobody had drawn what it was meant to
look like first.

**A design gate names exactly what it needs**, so the ask is one message and
the answer can be one reply. That is one of:

* a **reference image** or three, for anything with a silhouette;
* a **palette**, as hex or as a named thing in the world ("brass, not gold");
* a **layout sketch**, for a panel -- boxes and labels, not pixels;
* or the words **"you decide"**, which is a complete and valid answer and
  means the implementer picks and shows the result before it is wired up.

The gate exists so nobody builds thirty skins to a brief that was never
agreed. It does not exist to block work: every gated step names something
that can be built *around* it while the answer comes back, and Part II says
what.

### 18.3 The register: what the game has now, and what is missing

Measured against the working tree rather than remembered.

**Three-dimensional things.**

| thing | today | how | the gap |
|---|---|---|---|
| the piggy bank | one `GEN` mesh, 24 MeshParts with explicit segmentation | GEN | the tail socket is a segmentation scar filled by a sphere cap that shades differently; the body is faceted and the artefact is specular, loudest on Metal, Glass and Foil skins. Both are recorded as accepted. **Regenerating is a design decision, not a fix** -- it re-derives the landmark contract twelve accessories, the vault dial, the coin pile and both bores are cut against |
| **the coin pile and the drip** | 32 primitive discs sealed inside an opaque shell, plus a six-particle burst and a sound | CODE | **there is no coin object in flight anywhere in this game.** The pile cannot be seen at all since the pig went opaque and the bore was retired, so the only reading of "money just arrived" is a chime and six particles. **[DESIGN]** -- see 18.4 |
| houses | 9 tiers, rebuilt low-poly, 1,032 parts, zero coplanar pairs | CODE | section 14 wants breadth; interiors do not exist at all |
| shop units | 4, 433 parts, each with a room, a counter, a shopkeeper and a vault | CODE | the INTERIORS are one room shape four times with a different accent -- the exact complaint that was fixed on the outsides and never on the insides. **[DESIGN]** |
| fences | 5 tiers, all meshed, every tier cheaper than the primitives it replaced | GEN | tier STYLES (the panel, never the height or the hazard) are a section 14 shelf that does not exist |
| the guard dog | live: code-built breeds; latest chunky Blender candidates in `assets/guards/`, generated by `blender/guards/build_guards.py`; earlier sculpted set retained in `assets/dogs/` | CODE + EXT | revised dogs grow by tier; five additional wild/elite creature candidates (Tier 4 retains Gorilla; Tier 5 has Triceratops and Cerberus; Silverback and armored hellhound are retired), tintable parts, rigs and starter Idle/Chase/Attack FBXs. Studio import, runtime mapping, duty-vest fitting and final animation/gameplay work remain pending; proposed later tiers are not live rules. See 18.5 and `assets/guards/ANIMATION-GUIDE.md` |
| residents and shopkeepers | one code-built figure, per-server skin bag | CODE | fine; they inherit whatever the pig gets |
| the patrol car and officer | code-built originals, posed on the server | CODE | fine |
| rides | 6, each sized to the rider by measured contacts | CODE | section 14 wants 4 more |
| consumable props | 11 across `BoneModel`, `GadgetModel`, `HomeModel`, `ThiefModel` | CODE | **3 gadgets only**, and no throw or use animation for any of them |
| lawn ornaments | 23 | CODE | section 14 wants 15 more |
| **the acorn** | **IMPORTED / WIRED** -- Nut, Cap and Stem; 0.594×0.827×0.594 studs; one texture. Archived in `assets/acorn/acorn.json` and `.rbxmx` | EXT | `AcornModel` replicates a prewarmed template for tree/ground Acorns, storage contents and carried contents; white tint, nut-centred placement. The original source GLB is unavailable. The 2D interface keeps `Theme.acorn`. |
| **the oak and the basket** | **source models generated** -- `assets/tree/tree.rbxmx`, `assets/basket/basket.rbxmx`; staged in Studio as `AcornOak` and `AcornBasket` | GEN | oak integrated into residential plots through `AcornTree` / `ACORN_OAK_MESH`; current script sources match Studio through Rojo. Basket: 4,374 measured triangles, recessed empty interior, separate runtime acorns; basket geometry is now integrated through `AcornBasket` / `ACORN_BASKET_MESH` on residential plots; fill display remains 2.2 work. The compact Blender replacement in `assets/tree/blender/` is now imported and configured for residential plots: 8.5 × 9.25 studs, separate wood/foliage, 2,400/6,400 triangles. Studio Edit asset/placement/collision-query checks pass; full in-game visual review remains pending. Existing street `TREE_MESH` is unchanged. **[DESIGN]** full/empty readability and remaining Phase 2 gameplay still need verification |
| trees, grass | `TREE_MESH`, `GrassTuft`; 46 canopies, 1,463 tufts | GEN | fine |

**Animations.** `Config.ANIMATIONS` holds nine rows and **two are empty**, and
both fail silently on a published server because `RegisterKeyframeSequence` is
Studio-only:

* `sneak` -- with it blank the tiptoe is a speed number with the ordinary walk
  cycle on top, which is the precise bug the animation was written to fix.
* `carry` -- with it blank a thief's stolen pig floats in front of somebody
  whose arms are swinging at their sides, for the most-watched three seconds
  in the game.

Both sequences are BUILT and need uploading, which is a job with no design in
it. Everything a new gadget needs -- a throw, a use -- is a new sequence and a
new upload.

**Interface.** Every surface in the game, and none of it has had a design
pass as a set. The summary is below; **the complete chart -- all fifty-six
surfaces, with their measured sizes, is section 18.6**, and that is the list
to design against rather than this one:

| surface | where | state |
|---|---|---|
| the HUD element kit -- card, chip, badge, bar, banner, toast | `Theme`, `ClientMain` | one palette and one outline rule, arrived at by repair rather than by design. Contrast is audited to zero failures; **the LOOK has never been decided**. **[DESIGN]** -- and it is first, because every panel below inherits it |
| the piggy bank panel | top-right | merged the coin badge in; drawn from `Theme.coin` and `Theme.snout` |
| the event chip, the rap sheet chip | top-right column | paper cards with tone rings |
| the carry and street banners | top-centre | measured, verified, undesigned |
| the toast stack | top-left | nine kinds, nine glyphs, emoji |
| the hot bar, garage slot, dodge, stance pill, boost pill | bottom-left | four rows deep and full |
| **the shop** | 8 tabs, a front page, ~425 labels | the largest surface in the game |
| the bag / inventory | its own HUD button | shares the shop's card |
| **the daily rewards board** | seven rungs, a free crate on day 7 | **[DESIGN]** -- named by the designer |
| **the crack minigame** | `Crack.luau` -- a dial, a marker, a gauge, a cap line | **[DESIGN]** -- the one screen a robbery happens on |
| **the shake minigame** | **IMPLEMENTED** -- five-second ground/storage drag panel | CODE | 56px targets, basket target, countdown, RUN and controller alternative; live touch/visual Art 4 review remains pending |
| the reel | `SpinWheel`, shared by the event drop and every crate open | **[DESIGN]** -- it is the reveal for the whole cosmetic track |
| the rebirth page | two columns and an unlock band | recently reworked |
| the arrest scene | mugshot card, stamp, bail counter | deliberately dark; rotated onto the warm axis |
| **the re-rob timer** | `RobBadge` prints "ROBBED 54s" as TEXT | **[DESIGN]** -- section 9 asks for four states on that badge and a word with a number after it is not a timer |
| prompt cards | `PromptUI`, seven kinds | the one always-on-top class nobody has ever photographed |
| **the acorn icon** | the HUD chip, the crate price row, the basket readout, the shake panel | **[DESIGN]** -- and it is NOT the 3D acorn shrunk. `Theme.coin` is drawn in code as a disc, a rim and one highlight precisely because an emoji carries its own colours and ignores `TextColor3`; the acorn needs the same, at chip size, where the mesh's baked map is unreadable |
| the two street boards | `SocialService` | paper sheets on timber |

**Events.** There are **exactly two** -- `raid` and `rush` -- and
`Config.EVENT_UI` is already the vocabulary, so a third is a row rather than a
branch. Section 13 changed what all of them may pay and added two more. Their
interface is a banner, a countdown chip, a drop reel and `RaidFX`.

**Skins.** 45 today: **16 common, 19 rare, 9 legendary** and one epic (the
alien Martian, which stays epic because it lives in a mixed-kind chest). By
pool: **og 28, animal 9**, eight untagged. Section 6 moves three of those
eight into og. The gaps are specific rather than "more skins":

* **the animal shelf has an empty RARE tier** -- its odds read common 96 /
  legendary 4, so the middle of that crate does not exist;
* **its two legendaries do not meet the legendary brief**, which is *geometry,
  an animation and a glow* -- the Bengal Tiger and the Snow Leopard are a coat
  and a pattern;
* **four `EXT` creatures are authored and unuploaded** -- dragon, phoenix,
  rainbowtiger, stormwolf -- and they are exactly what that tier is for;
* a colour multiply over a baked texture is the muddy pig, so **a legendary is
  never a body repaint**.

### 18.4 The coin, which is the smallest item here and the most visible

The user asked for this first and it deserves its own paragraph, because it is
the one asset every player sees several hundred times an hour and it is
currently a sound.

What exists: `setFill` walks 32 discs to a target count inside a shell that
has been opaque since the bore was retired, so **the pile is invisible**;
`playCoinDrop` plays a chime at 0.94-1.06 pitch and emits six particles. What
does not exist: a coin, in the air, going into the pig.

Two things are needed and they are separate decisions. **The coin object**: it
is seen at a few pixels from the pavement and at arm's length on the lawn, so
it is a silhouette and a colour rather than a model -- and `Theme.coin`
already draws one in UI (a gold disc, a deeper rim, one off-centre highlight)
which is the shape to carry into three dimensions rather than invent twice.
**The arrival**: an arc into the coin slit, a squash on landing, and the slit
lighting for a beat. `COIN_COUNT` is **not** the dial to turn for any of this
-- it is the drip cadence, tuned so a coin lands about every fifteen seconds
at every level, and its own comment calls that a heartbeat; doubling it to
make the pig feel busier doubles the chime rate as an invisible side effect,
which is two curves multiplied without checking the product for the ninth time
in this project.

**[DESIGN]** wanted: what a coin looks like, and how loud the arrival is.
Loud is affordable once and unaffordable four times a minute.

### 18.5 The dogs move to outside software, by decision

`CLAUDE.md` argues at length that the dogs are code-built rather than meshed,
and the argument is good: `applyTier` repaints the whole animal per breed from
four tone slots, a generated mesh gets ONE colour unless it is segmented, its
baked texture cannot be prompted away, and three breeds would be three uploads
and therefore three moderation events on the developer's own account.

**That argument is being overridden deliberately, and what it costs is worth
writing down so nobody is surprised.** A meshed dog gives up per-breed
repainting unless it is uploaded with `segmentation: "explicit"` -- which is
exactly what the pig does, and what gives the pig its trim colour at all -- so
**the dog has to be authored in separable pieces (body, head, ears, tail,
legs, collar) or the six coats and the ON GUARD collar tell both die.** The
collar is not cosmetic: it is the guard-duty signal a thief reads from the
pavement, and `applyTier` restores it after every repaint.

What survives untouched, and it is most of the system: three breeds are three
`shape` rows of four numbers (`leg`, `girth`, `head`, `earDroop`) driving
groups rather than named parts, so a mesh in named pieces inherits the breed
ladder; the patrol, the catch radius, the clamp, the sleep posture, the puff
and the nameplate are all code and none of them touch geometry.

**[DESIGN]** wanted: three breeds, in separable pieces, in the low-poly
flat-shaded vocabulary the houses and shops are now in -- not a realistic dog,
which would be the only realistic object on the street. Authored and uploaded
by the designer; the ids go in a `Config.DOG_MESH` table shaped exactly like
`Config.PIGGY_MESH`, and **an empty row falls back to the code-built dog**, so
this can land one breed at a time and a moderated asset degrades to what
ships today rather than to an invisible animal.
### 18.6 The interface chart: every surface in the game, to design against

Walked out of the source rather than remembered, so it is a work list rather
than a summary. **Every size below is measured** -- these are what ships
today, they are what the layout is verified against, and a design that changes
one has to say so. **Fifty-six surfaces in four families (A to D)**, plus the
element kit they are all built from (E) and the rules they all have to
survive (F).

**The five sizes the whole chart is checked against, before anything else.**
A phone held sideways is **546 tall** and is the shortest thing that has to
work. `IgnoreGuiInset` is on, so **y=0 is UNDER the Roblox topbar** and
`AbsolutePosition` reads 58 lower than the offset you wrote. The shop panel
caps at **1040 x 660**. A body label needs **4.5:1** contrast against its own
ground and large or scaled text needs **3.0:1**. And the game renders in the
viewer's theme, so every colour is a `Theme` token and never a literal.

#### A. The persistent HUD -- always on, drawn over the world

The corners are full. Anything new displaces something.

| # | element | corner | measured | what it says | module |
|---|---|---|---|---|---|
| 1 | **Piggy bank panel** | top-right, ends y 88 | 320 x 74 | balance, rate, fill bar, drawn snout, *full in 14m* / FULL | `ClientMain` `PiggyPanel` |
| 2 | **Event countdown chip** | top-right, x 606, ends y 130 | 176 x 34 | hourglass badge, caption, clock; ring goes gold in the last minute | `ClientMain` `NextEvent` |
| 3 | **Rap sheet chip** | top-right, starts y 138 | 176 x 34 | STOLEN / WANTED / HUNTED, figure, four spree pips, tone ring | `ClientMain` |
| 4 | **Rebirth button + halo** | top-centre, y 96-148 | -- | star chip, label, pulsing halo as a SIBLING at lower ZIndex | `Rebirth` |
| 5 | **Carry banner** | top-centre, y 140-192 | 340 wide | what you are holding and what it is worth at home | `ClientMain` |
| 6 | **Street banner (patrol)** | top-centre, y 200-238 | 340 x 38 | siren countdown, pursuit clock | `ClientMain` |
| 7 | **Event banner** | same anchor, exclusive with 6 | 340 x 44, ends y 244 | event name, phase, draining bar + number | `ClientMain` `EventBanner` |
| 8 | **Toast stack** | top-left | 330 wide, cards 56-85 tall | nine kinds; capped by measured HEIGHT, not count | `ClientMain` `Notifications` |
| 9 | **Screen-edge flash** | all four edges | 0.26 of height, 0.17 of width | alarm / chase / police only; squared falloff, 1.67Hz | `ClientMain` |
| 10 | **Hot bar** | bottom-left, y 20-74 | 11 slots, drag to reorder | throwables; tile + key chip + count + equip ring | `HotBar` |
| 11 | **Boost pill** | bottom-left, y 86-130 | -- | a held daily boost | `ClientMain` |
| 12 | **Garage slot** | bottom-left, x 98, y 140-208 | 68 x 68 | RIDING / READY; edge gold when a ride is out; hidden with no ride | `ClientMain` `GarageSlot` |
| 13 | **Dodge / trick button** | bottom-left, x 22, same row | 68 x 68 | shares one slot with the trick button, never both | `ClientMain` |
| 14 | **Garage picker fan** | fans sideways from x 174 | -- | the ride collection, sideways because upward runs off a phone | `ClientMain` `GaragePicker` |
| 15 | **Stance pill** | bottom-left, y 216-250 | -- | riding stance, or the locked STYLES advert | `ClientMain` `StancePill` |
| 16 | **Shop button** | bottom-right corner | in a 210 x 50 frame | the control players know the position of | `ClientMain` |
| 17 | **Bag button** | bottom-right, LayoutOrder 0 | same frame | opens the inventory; grows the frame upward | `ClientMain` |
| 18 | **First-job objective card** | top-centre, y 50-94 | -- | *go and rob a piggy bank*; also GET IT BACK / BUY IT BACK | `FirstJob` |
| 19 | **Music toggle** | shop header | -- | **recorded as a stopgap in the wrong place** -- a shop is where you spend, not where you configure | `ClientMain` `MusicToggle` |
| 20 | **Acorn chip** | *does not exist* | -- | count, glyph, and the one shortfall line coins cannot fix | Phase 1.1 |

#### B. Full-screen panels -- opened deliberately

| # | surface | measured | notes |
|---|---|---|---|
| 21 | **Shop panel** | 0.92 x 0.86 of viewport, capped **1040 x 660**; content **1020 x 578** | the largest surface in the game; ~425 labels |
| 22 | Tab rail | 8 tabs, **772** wide, each sized to its own word (692 used) | a ScrollingFrame, because a rail that does not scroll silently EATS tabs |
| 23 | Front page | 3 x 3 grid, cells in SCALE not pixels | one screen, no scrolling -- the property to protect |
| 24 | **Item card** | **156 x 182**, `UIScale` 0.78 on a short screen | model preview well, name, price pill, rarity edge, state tint |
| 25 | Section header + "?" bubble | bubble 14px over ~330 | cream paper, one short paragraph, never four |
| 26 | Price pill / rarity edge / icon well | well is `SLAB`, edge is 3px (5 legendary) | rarity wins the one `UIStroke` a GuiObject gets |
| 27 | Upgrade card | full-width EARN band + two tree columns, scrolling | pips under 5 rungs, a continuous bar at 40 |
| 28 | **Bag / inventory** | own HUD button, 5 tabs, rail 44 tall +3 padding | never shows a price, only what you own |
| 29 | Spare chip / sell control | chip shows TOTAL copies (`x2` for one spare) | WEARING greys the sell |
| 30 | **Crates tab card** | three best-tier previews + a drawn odds bar | percentages are the server's `liveOdds`, never recomputed |
| 31 | Combine chips | derived from the chest's own stocked pool | never from a hardcoded rarity list |
| 32 | **Rebirth page** | SAND ground, KEEP / LOSE columns, unlock band of tiles | asks on the first rebirth only |
| 33 | **Daily rewards board** | seven rungs, day 7 a free crate | **[DESIGN]** |
| 34 | **Admin panel** (F2) | scrolling body, categories, rows, a target dropdown | dev-only, still needs to be legible |
| 35 | Settings panel | `SettingsPanel` | one allowlisted key per setting |

#### C. Moments -- transient, and the loudest things in the game

| # | surface | measured | notes |
|---|---|---|---|
| 36 | **Crack minigame** | **430 x 176**, dial 34 tall | marker sweeps, gauge draws the PIG with the cap as a red line, next slice drawn ahead. **[DESIGN]** |
| 37 | **Shake minigame** | *does not exist* | acorns falling for 4s, dragged into a basket, on a tablet. **[DESIGN]** |
| 38 | **The reel** | window + 560px bloom + rays + prize card | shared by the event drop AND every crate open. **[DESIGN]** |
| 39 | **Arrest scene** | card **480 x 302** | mugshot, BUSTED stamp, bail counting up; holds 5.5s, skippable at 3.5s |
| 40 | Rebirth fireworks | -- | six colours; read at 213 studs, not arm's length |
| 41 | RaidFX | -- | saucer, beams, drones |
| 42 | Style offer banner | `StyleOffer` | the pass advert |

#### D. In-world UI -- billboards and surfaces, read from the pavement

**Everything with `AlwaysOnTop` here is invisible to every screenshot ever
taken of it**, because the capture is taken before that pass composites. To
photograph one, build a throwaway copy with the flag off, shoot it, destroy
it -- never change the shipped flag.

| # | surface | measured | notes |
|---|---|---|---|
| 43 | **Prompt cards** | **250 x 82**, `StudsOffset` 1.6, slots grow the billboard | seven kinds; verb, key chip, detail row, amount, hold bar + countdown |
| 44 | **Rob badge** | **150 x 40**, grows to 52 with lock pips; lift 11, reach **224** | four timer states asked of it in section 9. **[DESIGN]** |
| 45 | Carried loot label | `HeistService` billboard | what the thief is holding, visible to everyone |
| 46 | Robber mark | `RobberMark` | replaced a Highlight so a thief cannot hide |
| 47 | Revenge marker | `ClientMain` `RevengeMarker` | lasts exactly `REVENGE.window` |
| 48 | Dog nameplate + kennel board | `MaxDistance` **90** | ON GUARD / OFF DUTY / DISTRACTED -- **never verified legible at 90 studs** |
| 49 | Resident nameplate | `ResidentModel`, two billboards | the name on the sign |
| 50 | **Plot sign** | `PlotService` SurfaceGui | rebirths, house, skin -- and section 11 adds a tier chip, rank stars, a NEMESIS line |
| 51 | **Leaderboard** | canvas **600 x 400** over 30 x 20 studs = **20 px/stud** | TOP THIEVES THIS WEEK; paper sheet inset 16px |
| 52 | **Most Wanted poster** | canvas **400 x 550** over 16 x 22 studs = **25 px/stud** | portrait; photo well, three rows, bounty; inset 20px |
| 53 | Shop fascia plaque | distance-capped **260**; NOT always-on-top | a name punching through its own building reads as HUD |
| 54 | Shop bracket sign | guis on LEFT and RIGHT faces | the street runs along X |
| 55 | Police car plate, van livery, statue prints | `PoliceModel`, `VanModel`, `Decor` x3 | originals, never real brands |
| 56 | **Storage crate readout** | **implemented** | bounded decorative contents with the exact stored count at every balance; final crate art pending |

**The two boards do not share a pixel scale** -- 20 per stud against 25 -- so a
height copied from one renders visibly smaller on the other. **Choose it in
studs and multiply up.**

#### E. The element kit -- the atoms everything above is built from

This is what Art 3 actually designs. Get these right and fifty-six surfaces
follow; get them wrong and every one is repaired separately, which is how the
current look was arrived at.

**card** (paper ground, 3px ink outline, gloss gradient) - **chip** (dark disc
with a tone ring) - **badge** - **pill** - **track / fill / groove** -
**icon well** (sunk, holds a rendered model) - **price tag** - **rarity edge**
(3px, 5px legendary) - **pip ladder** (right to about five rungs; at forty a
pip is 4.4px and becomes noise, so that gets a bar) - **section header** -
**hint bubble** - **toast card** - **banner** - **prompt card** - **tab** -
**key chip** - **the glyph set** (nine notify, five banner, plus the drawn
coin and the drawn snout).

#### F. The nine rules a design here has to survive

Every one of these has already cost this project a bug. They are constraints
on the design, not on the implementation.

1. **An emoji ignores `TextColor3`** and renders from the colour font. That is
   why the coin is DRAWN in `Theme.coin` -- three nested frames -- rather than
   typed, and why a chip is a dark disc with a tone RING instead of a disc of
   the tone. Any small glyph is a smudge below chip size.
2. **`TextScaled` makes "it fits" meaningless** -- the failure is silent
   SHRINKAGE. `TextTruncate` is the same trap wearing the other face: silent
   CLIPPING, while the label reads back the full string to every probe. The
   test is `TextBounds.X` against `AbsoluteSize.X`, never the string.
3. **One `UIStroke` per GuiObject.** Rarity wins on a card, so the shop's dark
   edge cannot also be there, and the rebirth button's pulse had to become a
   separate halo frame.
4. **A `Border` stroke draws OUTSIDE the object** and a scrolling parent clips
   it. This has bitten three times, on both axes. Size a clipping box against
   the TALLEST state, not the resting one.
5. **A child always draws above its parent** under `ZIndexBehavior.Sibling`.
   A halo has to be a sibling at a lower ZIndex or it washes over the thing it
   is behind.
6. **Never write `TextWrapped = false` after `TextScaled = true`** -- it
   silently turns scaling off and drops the label to `TextSize` 8.
7. **Contrast is audited by walking the live tree**, including the gradient
   evaluated at each label's own vertical position -- a probe that reads
   `BackgroundColor3` sees the TOP of a ramp and misses the label sitting
   lower. It is at zero failing pairs across ~425 labels and must stay there.
8. **A mid-tone carries neither polarity.** A colour that needs dark text on
   one surface and pale text on another is the wrong colour; move the GROUND,
   which is what took the dodge tile to paper and the rebirth button to plum.
9. **`ClientMain` is one chunk at Luau's 200-local ceiling**, and overflowing
   it kills the ENTIRE HUD with an error naming an innocent variable two
   thousand lines away. Any new surface is a MODULE started in one statement
   holding no local -- which is also why `HotBar`, `Crates`, `Inventory`,
   `Rebirth`, `Crack`, `SpinWheel` and `AdminPanel` already are.
---

## 19. The acorn loop, re-centred on the pig (September 16)

**Designer direction, September 16, authoritative where earlier sections
disagree.** The game is called Rob a Piggy Bank and its daily verb has to be
robbing piggy banks. Sections 3-5 built a second robbery economy beside the
first -- a second object to rob, a second minigame, a second carry, a second
loss cap -- available on every lawn at every moment, and that dilutes the
core. The acorn system stays, because a timer currency behind the crates is
the right shape and 2,692 lines of it are built and tested. What changes is
**where acorns come from, when they can be taken, and what they connect to.**

### 19.1 The coin pack is dropped, and that is what makes the rest cheap

Sections 6, 15 and 16 exist to keep crates legal beside a Robux coin pack.
The pack never shipped, `COIN_PACK.productId` is 0, the boot audit refuses a
live id while the Rebirth Crate rolls, and section 15's own last paragraph
argues a season pass is the cleaner product. **Decided: no coin pack.** Coins
are never sold; `CLAUDE.md`'s rule that this can only ever be broken once is
un-broken. Monetisation is named things -- a season pass, stances, pets,
rides -- as `CLAUDE.md` already prescribes.

Crates therefore stay priced in **acorns**, at 5 / 15 / 40 / 6, and acorns
stay unbuyable. A price that moved with a player's own income was considered
for coin-priced crates and **rejected as confusing** -- a price is a number a
child reads off a card, not a function.

### 19.2 One acorn per clean crack on a player's pig -- minted, never taken

A **clean five-slice crack on another player's pig mints one acorn** for the
thief, plus one more inside `REVENGE.window`. Residents and shops pay none:
the pig-crack acorn is the reason to rob *people*, and the tree is the solo
faucet.

* **Minted, not taken.** The victim loses coins and possibly the skin they
  are wearing, and nothing else. That is `HEIST_PAYOUT`'s own principle --
  the thief's reward is never the victim's loss -- and it is what stops a
  robbery acquiring a third sting.
* **Clean crack only**, the same rule skin theft uses. A one-slice tap (2% of
  the pig) may never pay an acorn: it would be twenty-two acorns an hour per
  victim before the loss cap bit. Clean-only means `LOSS_CAP` bounds the
  acorn faucet too -- about two per victim per hour, whoever is robbing.
* **The noun stays honest** with one line of fiction: *the alarm shakes their
  tree and an acorn drops for the thief.* Nuts still come from trees.

### 19.3 Banked acorns are safe; theft happens only under the Harvest Moon

> **Amended September 16 (designer):** the Harvest Moon was replaced by
> **Midnight Heist** (coin steals 2x, pig-crack acorns 2x, a dusk), and
> **acorn theft is disabled** for now -- no event opens another player's tree.
> The reasoning below about an event rather than a night cycle still holds;
> the tree-theft half is on hold until play-testing. See 6.4.

**Coins are the risk currency; acorns are the timer currency.** That
asymmetry is deliberate and is the whole of this section.

* **Storage is a bank.** Nothing in the crate on a lawn can be raided, ever.
  Storage raids, the four-an-hour acorn loss cap, the resident 15-minute
  raid cadence and the basket-nab acorn settlement **retire**.
* **A tree cannot be shaken by anyone but its owner** under normal
  conditions. The everyday street has one thing to rob on it, and it is the
  pig.
* **Harvest Moon** is a third `EventService` roster row: two to three
  minutes, weighted to land roughly once an hour. The street dims -- a
  `Lighting` **tween for the window only**, never a permanent cycle -- and
  for that window other players' *ripe* tree acorns can be shaken at the
  existing x5 and carried home in the basket under the normal getaway rules.
  Resident trees are shakeable at x1 during the moon so a solo server has
  something to do in it. Storage stays safe even then.

**Why an event and not a day/night cycle.** `CLAUDE.md` records *there is no
night in this game* as a load-bearing decision: `ClockTime` is 14.5 once,
and every neon effect, the bloom threshold, the piggy's readability from the
pavement and the dog-posture tell are tuned against one sun. A permanent
night half re-tunes all of that and spends half of every session in worse
readability for nine-year-olds -- and a cycle in which acorn theft is open
half the time does not make it rare, it makes it half the game again. A
window makes it an **occasion**: the countdown chip says the moon is a minute
out, and *when the moon comes out, empty your tree* is one sentence a child
learns once -- the same decision shape as banking before a patrol. It reuses
the shake minigame, the basket, the nab, the banner, the chip and the roster
weighting, and it is a lever (weight, length) where a cycle is not.

### 19.4 The tree is a progression object

* **A coin-priced ladder** on the tree -- growth rate and cap -- so the two
  economies connect in the direction the title wants: *rob pigs, spend coins
  on your tree, grow acorns, open crates.* It is also the repeatable coin
  sink section 14 says the coin shelf lacks. First pass, to re-solve:

  | level | growth /h |
  |---|---|
  | 0 | 1.0 |
  | 1 | 1.25 |
  | 2 | 1.5 |
  | 3 | 2.0 |
  | 4 | 2.5 |

  The cap column that stood here moved to the HOUSE (19.4a): the ladder
  sells the rate, the house decides how much the tree holds.

  One tree with levels, never more trees: lawn slots are scarce, and a
  bigger, fuller oak at level 4 is a tell read from the pavement.
* **Rebirth boosts growth while online**, a few percent per rebirth. Online
  only, because the loop is on the street; it is also the one thing rebirth
  still grows past the ladder's ceiling.
* **The anticipation layer**, which is not economy: a HUD chip reading *next
  acorn 43m*, ripe acorns visible on the branches, a **fertiliser** boost as
  a daily-ladder rung and event drop (the boost pocket already exists for
  coins), and the tree wobbling when one is ready.

### 19.4a Houses gate and hold; they never generate (September 16)

**Designer direction:** the house you own should matter beyond looks, without
letting acorns be collected fast. The rule that makes both true: **a house may
GATE what the tree ladder sells and may decide how much the tree HOLDS; a
house never adds a tree and never adds acorns per hour.**

* **One tree per plot, always.** More trees was the obvious reading and it
  is refused: a second tree is 2x the per-hour faucet stacked on the ladder's
  2.5x, so every price solved against the faucet -- the crates, the season
  tiers, the buy-back ladder -- would be wrong by a factor that depends on
  which house somebody bought, and the house would out-sell the tree ladder
  as an acorn purchase. It also spends lawn slots, which are the scarce
  thing.
* **Tree level is gated by house rarity.** The ladder stays coin-priced; its
  rungs unlock with your home:

  | best house owned | tree levels you may buy |
  |---|---|
  | Common | 0-1 |
  | Rare | up to 2 |
  | Epic | up to 3 |
  | Legendary | up to 4 |

  The per-hour ceiling does not move -- 2.5/h at level 4 either way -- the
  house decides WHEN you may buy it. It also restores something individual
  ownership removed: with the sequence rule gone, nothing made anybody buy
  a Rare or an Epic on the way to the house they wanted. *Your tree grows as
  grand as your house* is one sentence, and the gate is honest because the
  thing behind it is still bought.
* **The tree's cap is set by house rarity; its rate by tree level.**

  | best house owned | ripe acorns the tree holds |
  |---|---|
  | Common | 8 (today's cap -- nothing moves for anybody here) |
  | Rare | 12 |
  | Epic | 16 |
  | Legendary | 24 |

  An active player earns nothing extra from this -- the rate is untouched.
  What it moves is **acorns per day for anybody away longer than
  cap / rate**: a Common owner at level 1 caps in 6.4 hours, a Legendary
  owner at level 4 comes back from the 8-hour offline window to 20. That is
  the hatch-timer feel scaled by the house, aimed at the casual half of the
  audience whose acorn income is what they find when they log in.
* **"Best house OWNED", never the one shown.** Houses are individually owned
  (`LATE-GAME-ECONOMY-PLAN.md` §7), and moving into a cheaper-looking house
  for taste must never cost a player their tree. The gate reads the highest
  rarity in `data.houses.owned`.
* **Houses are never lost** except by the deferred Legacy reset, so the gate
  never drops in play. Whoever builds the Legacy reset resolves the one case
  where it could (recommended: keep the tree level, re-clamp the cap).
* **It is a bigger Harvest Moon target, and that is the right way round.** A
  Legendary tree holds more ripe acorns during the moon, so a rich house is
  a richer shake. Storage stays safe regardless.

**What a house may also do, none of it a faucet:** a bigger trophy room
(more `Shelf_N` mounts and a larger `Featured` spot -- display, never
achievement capacity); one house-matched finish the lawn pig may wear at
Legendary (pure look). **Refused, recorded:** extra trees, a per-hour
multiplier, fertiliser that drops more often at higher tiers (a rate
multiplier wearing a hat), and anything touching spawn, drop-off radius,
fence, dog, lock, income, capacity or shield -- *houses confer nothing* on
the getaway or the defence stack, which are the balance.

### 19.5 Numbers to re-derive before any of this ships

The faucet changed, so by section 17's own rule everything solved against it
re-solves: the season tier table (section 12), the four crate prices, the
buy-back ladder (section 7), the Harvest Moon weight and length, the tree
ladder's rates and coin prices, the house-rarity cap table (19.4a -- it is
the one that moves acorns per DAY), the rebirth growth bonus, and the acorn audit
scenarios in `tests/luau/audits.luau`. The solo rate falls -- no resident
tree lap outside the moon -- to roughly a crate every two to four hours from
an unupgraded tree, which is what a timer economy is meant to feel like and
is the first number telemetry has to check.

**Re-solved for 2.7 and 6.4 (September 16, later): crates tripled.** The 2.6
figures below count ONLINE growth only; a tree also fills for up to eight
hours offline, and the ladder lifts the rate. `tests/sim/acorns/model.py`
(reusing the late-game simulator's house timelines) measures per day: casual
5-12, regular 13-24, active solo 20-28, active multiplayer 22-30 (the pig-crack
acorn and the night's doubling add ~2). The designer approved crate prices
x3 -- `og`/`animal` 15, `alien` 18, `rarecrate` 45, `legendarycrate` 120 --
giving a regular player about one common crate a visit and a legendary every
5-9 days, a casual player a legendary every 10-25 days. Buy-back tickets
(3x per step off the crate) and the rebirth-crate bonus follow. Still to
re-solve against the new model: the season tier table (section 12, not built
yet). The old "crate every two to four hours" target was deliberately not
used: it would need 8-16x prices.

**Re-derived with step 2.6 (September 16), and it came out slower than the
estimate above.** `Config.acornRates` now models the two steady sources --
the player's own tree and the pig-crack acorn at the `LOSS_CAP` ceiling (two
clean bare-sack cracks per victim-hour). Measured at boot: **solo 1.0 acorn
an hour** (a 5-acorn crate every **5 hours**, legendary crate 40 hours);
**full server 3.0 an hour** (common crate 100 minutes, legendary 13.3
hours); active/passive 1.25x solo and 1.75x full. The old 3x active floor
was a theft-era target and was dropped rather than met; `maxCrackRatio` (2x
the tree) now keeps the pig-crack acorn a side faucet. The tree ladder
(2.7), the rebirth growth bonus, the fertiliser and the Harvest Moon are the
levers that bring the solo rate back toward the "two to four hours" above,
and the crate prices are the other; both are this section's to re-solve.

### 19.6 What this does to the phases

Phase 2's storage-raid and acorn-loss-cap steps are retired; own-tree
harvest, storage and the basket stand. Phase 3's basket hand-off survives
only for Harvest Moon carries. Phase 6 gains the Harvest Moon row. Phase 1.1's
acorn chip gains the *next acorn* countdown. The late-game house ladder,
individual house ownership and the Legacy reset are in
`docs/LATE-GAME-ECONOMY-PLAN.md`.

# PART II -- THE EXECUTION PLAN

Ordered. Nothing in a later phase starts before the earlier one is verified.
Each step names what it touches; *done when* is the check. Files are named
where the reader has to go there.

**The art track runs beside all of it**, not after it, and six of its steps
block a phase step -- the table under Art 1 says which. Two of them block
early: there is no shake without a shake panel, and no basket without a
basket.

## Phase 0 -- Gates (hours, not days, and two of them cost something today)

**Execution update — 2026-09-15:** Phase 0 is deferred by the designer's
instruction. Its checks remain open; they are not treated as passed. Phase 1
may proceed while these gates are scheduled for later. The asset design gates
in section 18.2 still apply.

These are carried unchanged from the retired roadmap because nothing below
can be tuned without them.

0.1 **Set the live place's `MaxPlayers` to 8.** File, Game Settings, World,
Max Player Count. It is 60 against a `Config.MAX_PLAYERS` of 8, `Main` kicks
anybody it cannot seat, and it is read-only from a script. *Done when* the
boot log stops warning.

0.2 **The two-player session.** One hour with a second person, watching in
this order, because each is a rule that has never run: a real steal against
a real player (the doubled payout, `LOSS_CAP` clamping a fourth grab, the
revenge multiplier and marker, the plaster); the owner-home dog barking and
marking and *not* chasing; the tug as it stands; the chase (the officer's
escape branch, a Golden Bone breaking a chase, being dug out of a bin, hiding
while carrying); and whether a defended plot reads from the pavement at the
90-stud `MaxDistance` the dog's labels carry. *Done when* every bullet is
measured or written into `GAME.md` §17 as a named failure.

0.3 **Listen to the game.** Nothing in this toolchain can hear. One session
in headphones: the six ride loops, the dog barks, the arrest sting, the music
cues and the nine placeholder cues. Hardest: the siren (11 seconds with an
engine hum, looped), the countdown tick, and the nab. *Done when* each is
kept or swapped.

0.4 **Press the COMBINE chip by hand once.** It is wired and server-verified
and no pointer has ever landed on it.

0.5 **Real pass ids.** `Config.PASSES` carries three rows and every `id` is
0, which unlocks what it gates and warns at boot. Create the passes in the
Creator Dashboard and paste the ids in. Five minutes, and it is the whole of
monetisation until Phase 4.

## Phase 1 -- Acorns (a weekend, and it changes the shape of the game)

**Execution update — 2026-09-15:** Steps **1.1–1.2 implemented** in the
Rojo workspace and verified in Studio. Designer approved the nut-brown,
green-cap, cocoa-outline cartoon icon. `Theme.acorn` now draws the HUD and
price glyph; the compact balance chip sits beside the event timer. Existing
`data.loot` balances are preserved. Piggy deliveries grant no Acorns and
their receipts name none. `Config.acornMultiplier` is ready for Phase 2,
with no production caller yet (nil victim rebirth count means a resident).
Checks: Rojo build, phone HUD/crate preview, no client errors, seven multiplier
cases and twelve isolated delivery cases in `tests/studio/acorns.luau`.
**Step 1.4 implemented — 2026-09-15:** All crate prices use Acorns; the
server rejects coin/missing/unknown currencies before rolling. Cards show the
Acorn glyph, shortfall and shake-tree hint. Regular crates retain spare
combining through an explicit eligibility flag; Alien Cache stays excluded.
`auditEconomy` reports non-Acorn crates. Isolated full-service tests cover
charging, refusals, duplicates, free crates, combines and provoked audit
failures (73 checks); no player saves are used. See `tests/run-crates.py`.
Luau compilation and Rojo build pass. Live desktop/iPhone/Android card
properties confirm prices and combine flags; phone text-fit checks pass with
bounded title sizing. Screenshot/reveal review remains pending.

**Steps 1.5–1.5b implemented — 2026-09-15:** Rebirth opens the standard free
Legendary Crate, with a crate-price Acorn fallback for the full legendary
collection. Bronze, Gold Leaf and Diamond join `og`; schema 25 records their
legacy threshold ownership once. The rebirth page shows the crate or fallback.
Isolated tests cover normal odds and duplicates, progression, migration
thresholds, rejoin idempotence and no regrant after a sold/stolen skin (89 checks).
The 73 crate checks, Luau compilation and Rojo build also pass; modified scripts
match Studio through Rojo. Live
rebirth/reveal review remains pending; the player's save was not used as a test.

**Step 1.6 implemented — 2026-09-15:** Guaranteed eligible clean-crack theft,
per-owner timed claim stacks, latest-taker replacement and carried recovery.
The normal duplicate/cap/spare rails remain, with restitution bypassing the
robber's insurance and cap. Isolated tests cover multiple victims, separate
expiry, changed outfits, failed getaways and claim supersession (67 checks).
The full 229-check set, Luau compilation and Rojo build pass. Config and
HeistService match Studio through Rojo. Multiplayer
input/visual verification remains pending; no live player saves were used.

**Step 1.7 implemented — 2026-09-15:** Persisted seasonal claims, direct
15/45/135-Acorn skin buy-backs and exact-skin Crates cards. Eligibility and
pricing are server-owned; owned, unclaimed or expired skins cannot be bought.
The robber keeps their copy. Claims remain valid through a five-week cycle
(four active weeks plus rest), with immediate request validation, local card
expiry, online rollover cleanup and load-time pruning. Claim defaults from
1.10 and the Phase 5 season clock landed early; season ranks/rewards remain
pending. The 298 isolated checks, all 89 source compilations and Rojo build
pass; all 89 scripts match Studio in Edit mode through Rojo. Live purchase,
input/rendering and DataStore checks remain pending.

**Step 1.8 implemented — 2026-09-15:** FirstJob now shows private recovery
objectives even after onboarding is finished. A 0.25-second server poll sends
changes from the actual heist records; client wall-clock rendering handles
timer expiry without waiting for another packet. In-flight chase, timed
recovery, carrying home and seasonal buy-back are distinct states. Stacks,
latest takers, insured spares, disappearance/reacquisition and subscriber
startup races are covered. The 383 isolated checks, all 89 source compilations
and Rojo build pass; all 89 scripts match Studio through Rojo in Edit mode.
Live multiplayer timing/input and visual review remain pending; no player
saves were used.

**Step 1.9 implemented — 2026-09-15:** Acorn and random-outcome boot audits,
with 27 rule failures deliberately provoked. Removed event Acorn faucets;
raid coin bounties/free set drops and Rush Hour coin multipliers remain.
Crate skins use `sellBasis` for their preserved resale limits rather than a
coin purchase `cost`. The standard random rebirth crate remains, with a
warning if the reserved coin-pack product id becomes live. Planned Phase 2
constants support an explicitly labelled model, not live earnings. All 550
isolated checks pass. All 89 scripts compile, Rojo builds, and all 89 match
Studio in Edit mode. Live boot/event/persistence checks remain pending.

**Step 1.10 implemented — 2026-09-15:** Saved `robberies` defaults to zero
for new/older saves, normalizes malformed counters and survives rebirth.
Every nonempty delivered robbery counts once against any target. The 4.1
increment lands early so progress accumulates before rank UI; thresholds and
stars remain pending. Existing coin totals cannot reconstruct historical
robbery counts. Claims defaults/reconciliation already landed in 1.7.
All 600 isolated checks pass, including real DataService lifecycle tests with
copying store doubles. All 89 scripts compile and Rojo builds. Studio was in
Play during final verification; Edit-mode source sync and live persistence
remain unverified for this step. No live player saves were used.

**1.3 remains open** and depends on Phase 2; trees/shakes are not implemented.
This is an incremental local change, not a release.

1.1 **The name. [DESIGN -- Art 8]** `Config.ROLL_CURRENCY` is the one table
player-facing wording reads; set it to Acorns with the acorn glyph and its own
hue in `Theme`. The glyph is a design gate rather than a character: an emoji
carries its own colours and ignores `TextColor3`, which is why the coin is
DRAWN in `Theme.coin` rather than typed, and the acorn wants the same
treatment on the HUD chip, the price row and the crate card. Grep every string that prints "loot" to a player and read each one.
*Done when* no player-facing string says loot.

1.2 **Acorns come off the delivery, entirely.** `Config.LOOT.delivery`
retires: `HeistService.deliver` stops crediting the second currency on any
target, and its toast stops naming one. What replaces it is
`Config.acornMultiplier(thief, victim, revenge)` -- resident 1, player 5,
plus `perRebirthAbove` and the revenge x2 -- which has exactly one caller and
it is the shake in 2.3, not this function. *Done when* a delivered player
crack pays coins and a skin and **zero acorns**, a delivered shop crack pays
coins and a drop and **zero acorns**, and no delivery toast anywhere mentions
them.

1.3 **The resident acorn cadence.** A per-target `lastAcornsAt` beside the
existing `lastGrab`; a resident's basket may be shaken for acorns only if 15
minutes have passed, and the panel says so when it would pay nothing rather
than opening a minigame with no prize in it. Shops are not in this path at
all, because shops have no tree. *Done when* two shakes on one resident a
minute apart pay out then refuse with the wait named.

1.4 **Crates in acorns, and never in coins again.** `Config.CHESTS.*.currency
= "loot"` with the prices in section 6 -- all four, no exceptions, no coin
fallback; `ChestService.open` already charges by `currency`, so this is a data
change rather than a feature. The Crates tab's cards read the currency off the
chest and print the acorn glyph, and the refusal names acorns AND where they
come from, because this is the one price in the shop that more coins cannot
meet and every other price on that screen has trained the player to go and
earn some. *Done when* an og open costs 5 acorns, refuses at 4 with the
shortfall and the route both named, and `auditEconomy` counts no crate in the
coin catalogue.

1.5 **The Rebirth Crate, and the rebirth skins retire with it.**
`ProgressionService.rebirth` calls `ChestService.grantFree(player,
"legendarycrate")` with the standard crate odds, per the designer's correction
on 2026-09-15. The outcome may be rare or legendary; duplicates pay spares.
Retire `rollRebirthDrop`, `getDropWeights`, `LEGENDARY_PITY` and `DROP_RARITIES`;
the completed-legendary-collection fallback becomes forty acorns. *Done when*
a rebirth on a fresh save opens a free standard Legendary Crate, and a rebirth
on a save owning every eligible legendary pays forty acorns.

1.5a **Bronze, Gold Leaf and Diamond move into Piggy Originals.** Drop
`unlockRebirths` from all three, give each an explicit `rarity`, tag each
`chest = "og"`, and delete the `unlockRebirths` branch from `Config.rarityOf`
and from `Config.isSkinUnlocked`. *Done when* all three appear in the og pool,
are admitted by `isStealableSkin`, and the boot audit reports no surviving
`unlockRebirths` field anywhere in `Config`.

1.5b **The ownership migration, and it is the only one in this plan.** In
`DataService.reconcile`, gated on the schema bump so it runs exactly once per
save: for each of the three, if `data.rebirths` already clears its old
threshold, write `cosmetics.owned[key] = true`. Without it a player at rebirth
4 silently loses Gold Leaf -- `getSkin` falls back to Classic Pink, the bag
shows nothing equipped, and nothing errors anywhere. **Prove it idempotent
before shipping it**: a migration that pays out on every join is a far worse
bug than the one it fixes, which this project has already recorded once over
the retired-ornament refund. *Done when* a schema-24 save at rebirth 6 joins
owning all three, rejoins owning exactly three, and a save at rebirth 0 joins
owning none.

1.6 **Skin theft at 100%, and the hot rule.** `SKIN_STEAL.chance = 1`;
`revengeChance` retires. A clean crack recovers a live claimed skin from the
last robber's `owned`, regardless of what they wear. `grudge[victim][thief]`
contains separate coin expiry and per-skin timed claims. Claims stack across
victims and skins, and only a later theft of that owner's same skin replaces
its previous robber claim (designer clarification in section 7). *Done when*
two victims can independently recover from one robber who changed outfits,
inside each claim's own window; expired or superseded claims cannot recover.

1.7 **The buy-back ladder. [IMPLEMENTED]** `data.claims[key] = seasonIndex`
written in `rollSkinSteal` on owned-copy loss; `Config.BUYBACK.perStep = 3`;
a card beside the source crate shows BUY BACK at `crate.cost * 3^rank` for
any current, unowned claimed skin, a direct grant through
`SetService.grant` charged in acorns, cleared when the season rolls. *Done
when* a claimed common buys back at 15, a rare at 45, a legendary at 135, and
the button is absent for an unclaimed skin.

1.8 **The objective card. [IMPLEMENTED]** The first-job card gains a second reason to
show: a live claim inside the revenge window prints GET IT BACK with the
countdown, then BUY IT BACK with the price. *Done when* the card is on screen
within a second of a theft and flips at the window's end.

1.9 **`auditAcorns` and the sweep audit [IMPLEMENTED]** (sections 16 and 17), warned at
boot beside the other four. *Done when* the boot log is clean and each check
is provoked once to prove it fires.

1.10 **Save. [IMPLEMENTED]** `data.claims` (new top-level table, generic
reconcile) and `data.robberies` (new lifetime counter). Schema 25 landed for
1.5b; no further version bump is needed. Claims landed with 1.7 before its UI.
Robberies defaults to zero, survives rebirth and records each nonempty
successful delivery once, ahead of its Phase 4 UI.

1.11 **The pig-crack acorn. [Fable; no visual needed] — DONE September 16**
(`Config.crackAcorns`, `tests/luau/theft.luau`). Section 19.2. In
`HeistService.deliver`, a delivered carry whose crack ran all five slices
against a PLAYER victim mints one acorn (`data.loot += 1`), plus one inside
`REVENGE.window`; residents and shops mint none; a partial crack mints none.
The delivery toast names it beside the coins. `auditAcorns` gains the rule
"no acorn is credited on a resident, a shop, or fewer than five slices."
*Done when* the isolated theft suite shows a five-slice player crack paying
1 (2 on revenge), a four-slice one paying 0, and a resident crack paying 0.

## Phase 2 -- The tree, carry basket, storage crate and timed collection

> **Amended September 16 -- see section 19.** The storage-raid steps and the
> acorn loss cap in this phase are retired; own-tree harvest, the crate as a
> bank, the basket and the drag round stand.

2.1 **Props. [IMPLEMENTED; final storage art pending]** Approved imported oak
and carry basket. A functional open wooden storage crate now replaces the
stationary basket at (-20, 16), with an exact-count label. Generate its final
art using `assets/crate/BLENDER-PROMPT.md`, then integrate measured imported
mesh offsets without changing the storage interaction. Shops have no props.

2.2 **Growth. [IMPLEMENTED; revised to separate tree stock]** Saved
`treeAcorns`, `groundAcorns`, `acornsDroppedAt`, `acornsGrownAt`; unchanged
banked `loot`. One/hour, maximum eight ripe, bounded offline growth and
partial-hour preservation. Stored balances never block growth. Imported
Acorns appear on the tree, fall when shaken, and remain on the ground until
collected/expired. Crate contents have an exact-count label, never PACKED.

2.3 **Five-second collection and storage raids. [IMPLEMENTED; live input
review pending]** H/Y tree collection (including own trees), J/X storage raid
(other properties only), half-second server-checked hold, five-second drag
panel. Tree attempts offer the loose supply, up to eight at once. Storage
raids offer max(1, floor(balance × .25)), bounded by four net losses in a
rolling hour. Unique server-checked catches and concurrent reservations;
interruptions and 60-second theft cooldown. Missed ground persists for 60
seconds; missed stored Acorns remain in storage. Full rules are in §4–5.

2.3a **Deposit accounting. [IMPLEMENTED]** Own harvest deposits one-for-one
with no robbery/grudge. Theft multiplier applies only on delivery at one's
own crate. Raw refundable receipts retain the source; no premature banking.

2.4 **Basket carry. [CORE HANDOFF IMPLEMENTED; engine/presentation review
remains]** Imported carry basket displays up to eight Acorns. The existing
nab/dodge/bin/jam/patrol paths use whole-Acorn refunds. Death and departure
settle receipts before saving. Crate range gates delivery. Isolated tests
cover replay/refunds/settlement and mouse/touch/controller handlers; live
catch-to-deposit and carried pose review remain.

2.5 **Resident supply. [IMPLEMENTED]** Two ripe + two stored Acorns per
residential plot, seeded once per server. Same one/hour growth as players;
residents at home bank a crop once its first ripe Acorn has waited fifteen
minutes, postponing for ground stock or an active collection. Shops have no
Acorn stock. A successful round opening starts a shared 15-minute raid timer
for all thieves and both sources, displayed on the prompts. Invalid/empty
openings do not start it. Claim/release pauses/resumes the same stock, so no
reseeding or hidden production occurs under a player's tree. Delayed refunds
retain the correct stock identity. Existing coin growth/robberies are unchanged.

Isolated tests cover full production/harvest cycles, real ResidentService
seat/tick/evict integration, cooldown boundaries and refunds across occupants.
Studio verifies nine resident houses with both seeded sources and four shops
with neither, plus real-client countdown expiry and ownership handover.
Section 17's new-growth-only model counts each fresh Acorn once. NPC harvest
animation and live player gesture/getaway review remain separate visual work.

2.6 **Retire storage raids and the acorn loss cap. [Fable] — DONE September 16**
(the moon gate is `EventService.isAcornTheftOpen`; `shake`/`shakeui` suites inverted). Section 19.3.
Remove the J prompt on other properties' crates, the four-an-hour acorn loss
budget and its receipts, and the resident 15-minute raid cadence; storage is
a bank. The shake prompt on another player's tree is gated on
`EventService.isEventLive("harvestmoon")` and does not exist otherwise.
Own-tree harvest, storage deposit and the basket are untouched. *Done when*
`basket`, `settlement` and `residents` suites pass with the raid cases
inverted (a raid attempt is refused by name) and `auditAcorns` is clean.

2.7 **The tree ladder and the rebirth growth bonus. [Fable; visuals B5
later]** Section 19.4. `Config.TREE_LEVELS` (rate, cap, coin cost per rung,
first pass in 19.4), `data.tree.level`, a `TreeRequest` remote validated
server-side, growth read through `Config.treeGrowthPerHour(level, rebirths,
online)`. Coin prices go through `auditEconomy`. Ships with a placeholder
scale change on the oak until B5 lands. *Done when* growth at each level
matches the table over a simulated day, the rebirth bonus applies online and
not offline, and a cost above the largest pig is refused by the audit.
**IMPLEMENTED September 16 (Studio check pending).** `Config.TREE_LEVELS`
(rates per 19.4; first-pass prices 25K / 100K / 1M / 12M, each below the
cheapest house of the rarity that opens it), `TREE_HOUSE_GATE` (19.4a caps and
level gates, read from the best OWNED house), `TREE_REBIRTH_BONUS` (+3% a
rebirth online, capped at +60%). `Config.growAcorns(data, now, online)` reads
level, cap and bonus off the save; residents unchanged. `data.tree.level`
(generic fill, no schema bump; survives rebirth). `TreeService` sells the next
rung from an owner-only **Grow Tree** prompt (J, slot 1 on the oak) and
`TreeRequest`; a house purchase refreshes the offer. Placeholder growth is
HEIGHT ONLY (up to 1.2x) because the trunk mesh's bounding box already meets
the storage crate at level 0; the ripe-acorn display rises with it
(`PLOT_TREE_GROWTH_ATTRIBUTE`). New `tree` suite, 93 checks, all *Done when*
conditions included; 24 suites pass. Solo top rate 4.0 an hour (level 4, full
bonus) against 1.0 base. **The next-acorn clock landed the same day, over the
tree rather than on the HUD (designer choice):** an owner-only card above the
canopy reading `🌰 3/12 · next 42m` or `FULL`, drawn by `Shared/TreeClock`
from `TreeNextAcornAt` / `TreeCap`, which the server publishes through
`PlotService.publishTree` on the economy push, a shake, a purchase, join and
a house purchase (`Config.nextAcornIn`). `tree` suite now 106 checks.
*Not done:* the fertiliser and the tree wobble (the rest of 19.4's
anticipation layer), crate-price re-solve (19.5), and an admin command to set
a tree level for Studio testing.

## Phase 3 -- The hand-off, and the timers on the street

> **Amended September 16 -- see section 19.** The basket hand-off applies only
> to Harvest Moon carries; there is no other stolen-acorn carry.

3.1 **The carry's claimant. [IMPLEMENTED]** `Carry.claimant` is written on
successful crack, smash or basket attachment; `Carry.holder` identifies the
player whose character it is welded to. Additional slices/catches retain the
original record. Both delivery entry points read both fields and reject stale
holder indexes or non-claimant settlement until 3.3 supplies that branch.
Coin/skin/Acorn regressions cover unchanged original-holder payouts and intact
escrow on refusal. The imported four-part storage crate is also integrated,
retaining its existing floor anchor and a complete asset-load fallback.

3.2 **The tug ends in a transfer. [IMPLEMENTED]** `endTug(thief, "emptied")` calls
`handOff(thief, catchWinner(tug))`: detach the loot from the loser, attach
it to the winner, keep `claimant`, stamp `nabRest` on the new holder, and
retire `tugTick`'s per-tick `giveBack`. The dog and the patrol paths are
untouched. *Done when* a completed tug moves the pig to the nabber with the
haul intact and the old thief is empty-handed and unstunned.
Implementation retains the same model/prompt and escrow record, binds the
prompt to the current holder, and selects the highest-contributing eligible
nabber with join-order ties. Every tick preserves the whole amount and receipts;
no bounty is paid during a tug. Missing/busy/dead/distant winners, broken welds,
and stale carry/tug callbacks cannot consume escrow or credit a catch. Both
player HUDs and victim markers update. Phase 3.3 now supplies non-claimant delivery.

3.3 **The three exits. [IMPLEMENTED — live two-player verification pending]** The carrier's own prompt card names both drop-offs;
delivery at the victim's plot is `returnCarry` (victim refunded through the
existing `refund`, bounty minted to the deliverer); delivery at the holder's
own pig pays by claimant test -- full for the claimant, `NAB.keepShare` (0.5)
of coins and acorns otherwise, the haul whole. The grudge and revenge marker
re-point to a non-claimant deliverer. *Done when* each exit is driven with
two players and the toasts name what happened at both ends.
Implemented explicit keep/return selection by server-checked position, current
occupant and living-holder identity; the request still carries no payload.
Non-claimant keep is floor(raw amount × 0.5), without multipliers, matching the
anti-farming 0.5x example above. Return bounty is floor(raw amount × 0.25) in
the same currency, paid once to the deliverer. Original-claimant undos and
own-harvest returns mint no bounty. Acorn refunds retain source receipts.
Victim holders take the return path, and item-only carries have working actions.
Both named destinations/payouts appear on a carry card; minigames hide it.
Automated settlement/UI checks and native cloned-card layout fixtures pass;
a live two-player pursuit/settlement test remains the completion gate.

3.4 **Street badges, recovery task and nearby Acorn cooldown. IMPLEMENTED;
live art review pending.** The approved cream badge shows NEW HERE / SHIELD,
ROBBED, EMPTY, CAPPED or coin worth in server-refusal order. Public HOT SKIN
becomes RECOVER SKIN for the relevant owner. A private task uses the actual
stolen skin thumbnail and its independent deadline; tapping expands details.
Acorn quantities stay off street badges. Nearby tree/crate prompts show an
hourglass and Steal ready in m:ss for the viewer's shared source cooldown,
then restore normally at expiry. Automated checks pass. *Done when* a real
pavement photograph and mobile interaction review confirm legibility and
placement. The separate 3.3 multiplayer settlement gate remains pending.

## Phase 4 -- Shop drops, and the pack

4.1 **The rank. [IMPLEMENTED; final visual review pending]** `data.robberies` already increments in `deliver` as of 1.10;
add `Config.RAP_SHEET_RANK = { 0, 25, 100, 400, 1600 }`; a star row on the plot
sign. *Done when* a save at 99 shows one star and at 100 shows two.
The server derives rank from the saved count, updates the sign at join and
after coin/Acorn deliveries, and clears it on release. Isolated renderer and
settlement checks pass the 99/100 threshold, including skin-only getaways.
Studio loaded the rank-zero sign with fitting text; visual review was interrupted.

4.2 **The drop table. [IMPLEMENTED]** `SHOP_VAULT_DROP.chance` becomes per-shop with the
`minRank` on `gear`; `rollShopDrop` refuses below the rank silently;
`auditSkinSteal` compares against the largest chance. *Done when* a rank-1
thief never draws a ride across two hundred simulated rolls and a rank-2 one
draws at about three per cent.
Implemented 10%/8%/3%/20% for piggy/home/gear/defend, with gear requiring
rank 2 before rolling or paying any reward. Unknown shop keys refuse too.
The actual drop function passes 45 isolated checks: rank 1 yields no rides
in 200 attempts; 200 evenly spaced eligible draws yield six rides; a seeded
10,000-attempt run yields 317 (3.17%). Carry/resale/stock paths and the
maximum-shop-chance audit are exercised without live saves.

**Approved follow-up: visible odds and discovery presentation.** The crack
panel now shows overall item odds and conditional rarity odds from the actual
eligible server pool, plus accurate 0%/100% player-skin and resident states.
The user chose a compact non-blocking reel on discovery and promoted Volt
Scrambler to Legendary. The reel cycles eligible models and lands on the
server-selected item, distinguishing carried items from banked grants/resale.
The 3% overall ride chance and rank-2 gate remain. Automated checks and native
phone component previews pass; outstanding Phase 3 gameplay gates remain open.

4.3 **The coin shelf, before the pack. [DESIGN -- Art 11, per shelf]**
**September 16 user correction supersedes the earlier effects brief:** no
standalone piggy effects, no effects shop, no Aurora or Starfall. Piggy
effects are limited to coin-deposit feedback and Legendary skin visuals.
**Latest user priority:** defer fences; explore higher-tier house exterior
appearances first. Exterior mockups are in `assets/houses/design/`.
Interiors remain future work; entering, visitors and room layout are not yet designed.
`auditEconomy` runs after every batch, because every price is measured against
`getCapacity(ABSOLUTE_MAX_LEVEL)` and there is only 16.9M of headroom above the
Sky Castle. *Done when* the summed spendable coin catalogue clears 400M, the
new boot check finds no item carrying both a `cost` and a `chest` tag.
The former requirement to make seven piggy effects buyable is cancelled.

4.4 **The pack -- only after Phases 1 and 2 are live, and after 4.3.** A developer product
whose receipt writes `data.parcel = "pigfill"`; `PlotService.setCrate` draws
it on the doorstep box; opening it at the pig adds `capacity - coins` and
clears the field; refused with the reason if the pig is already full. The
card carries the sentence in section 15, and the shelf it buys is 4.3's.
*Done when* a bought parcel is on
the doorstep across a rejoin, opens to a full pig, and a second purchase
while one is unopened is refused before charging.

## Phase 4b -- The late-game ladder, house ids and the Legacy reset (Fable; runs beside 4-6)

Independent of Phases 1-3 and of the art track except where marked; the
whole of it is `docs/LATE-GAME-ECONOMY-PLAN.md`, which carries the numbers,
the migration and the tests. Decisions recorded there in §11.

4b.1 **The ladder (L1). [IMPLEMENTED — September 16; Studio Play check pending]** `ABSOLUTE_MAX_LEVEL` 60,
`BAND_TOP_2` 40, `CAPACITY_GROWTH_C` 1.136, `INCOME_GROWTH_C` 1.10, band-C
cost growth 1.26/1.16, rebirth multiplier 0.12 to RB10 and **0.08 beyond**
(A2), audit sweep bounds derived. *Done when* every value for L ≤ 40 /
rb ≤ 10 is byte-identical to today, `capacity(60) ≥ 1.2e9`, fill time at
every ceiling sits in 10-18 min, all three audits are clean, and a provoked
`ABSOLUTE_MAX_LEVEL = 40` with a 1B house fires `auditEconomy`.

Implemented in `Config` (`BAND_TOP_2`, three `*_GROWTH_C`, `ABSOLUTE_MAX_LEVEL`
60, `REBIRTH_MULTIPLIER_TAPER`, `rebirthsToMax`, `rebirthIncomeFactor`,
`rebirthBonusPercent`, a three-clause `banded()`, derived audit bounds), plus
`Rebirth.luau` and `ProgressionService` reading the factor through Config.
`tests/luau/ladder.luau` (121 checks) pins every pre-change value at L ≤ 40 /
RB ≤ 10, the 1,241,390,843 top pig, the seams, the taper, fill 10–18 min at
every ceiling, the clamp binding on 40–59, the flat robbery ratio to L60/RB20,
both audits clean and the provoked 1B-house refusal. All 21 existing suites
pass; Rojo builds. Not yet done: one Studio Play to confirm a clean boot.

4b.2 **House ids and schema 26 (L2). [Fable; no visual] — DONE September 16**
(`tests/luau/houses.luau`, 1,025 checks; dev save migrated live). Stable ids on
`HOUSE_TIERS`, `HOUSE_LEGACY_ORDER`, `data.houses = { owned, shown }`,
derive-only reconcile, `houseLevel`/`houseShown` **deleted**, every reader in
the plan's §8.3 converted, `HouseRequest` by id. *Done when* the migration
matrix passes twice and a schema-25 save showing a Sky Castle over a Marble
Palace comes back owning nine and showing the castle.

4b.3 **Individual purchase UI (L3). [needs B1 from GPT]** Every house a card
with SHOWN / OWNED / AFFORDABLE / TOO DEAR / WON'T FIT; MOVE IN as a toggle;
no "buy the next one" copy. Fable wires; GPT supplies the card states and
the section layout at 1040 and 546.

4b.4 **The catalogue (L4). [needs B3 from GPT, per house]** The five houses
that fit today's pig may land before 4b.1; the 150M-1B four after it. Each is
one row; the audit admits it automatically.
**Rows landed September 16, ahead of the art (designer direction).** All
nineteen revision-2 rows are in `Config.HOUSE_TIERS` in price order: the nine
new ids stand `placeholder` blocks sized to their brief height, with a
construction band so they cannot be mistaken for the finished house; the
re-themes renamed `villa`, `modern` and `palace` in place and still stand their
old models; `goldenpig` is earned (no `cost`, `earned = "houses"`), refused by
`buyHouse` and granted on the last priced purchase. Residents climb only the
built houses (`Config.residentHouseLevel`). `auditEconomy` refuses a priced
earned house, a priced row with no number, a placeholder over the 60x57 yard
limit and a catalogue out of price order. `houses` suite 1,239 checks; all 23
suites pass; placeholders sweep at zero coplanar pairs. *Still per house:* the
real builder under each `style`, then drop `placeholder`. *Not verified live:*
a Studio Play of the blocks on a plot and on the shop card.

4b.5 **Trophy rooms (L5). [needs B2 from GPT]** `HOUSE-TROPHY-ROOMS.md`, with
the named display points in B2. The reason "own all eighteen" is not the
end of the game (plan §11.1).

4b.6 **Legacy reset. [needs B6 from GPT; last]** Plan §11.2: voluntary at
RB20 with every house owned; wipes coins, ladders, trees, rebirths and every
house but the shack; keeps everything that records what the player did;
`data.legacy += 1`, a sign star and a room plaque. Open decision: skins and
rides survive (recommended yes).

## Phase 4c -- The robbery rework (Fable for rules and code; GPT for the panel and the props)

**Designer direction, September 16.** The crack, the catch and the kit are
the game, and they ship in their first shape. This phase makes the minigame
harder, the panel worth looking at, the catch a set of beats rather than a
radius, and the kit wider -- and it pins two rules the designer asked to
verify. Sections 4c.5 and 4c.6 are the verification; the rest is the work.

**What the audit for this phase is.** `auditRobbery` is an UPPER BOUND on
perfect play and is structurally blind to a defence (`CLAUDE.md`), so nothing
here may be judged by it alone. Every difficulty change is checked against
the crack's measured windows and the cycle time it feeds; every catch change
against `BASE_WALK_SPEED` -- speed is the currency, and nothing in this phase
makes anybody faster than 16.

4c.1 **The crack gets harder, and the first step is to play it.** [Fable]
`CLAUDE.md` records that the dial's marker was frozen for the life of the
feature (a local shadowed the function passed to `Connect`), so the tuned
windows -- 0.692 down to 0.298 of the dial at lock 1 -- have never been
played as tuned; the current difficulty is a number nobody has felt. So:
(a) a one-session play of the crack as it stands, recorded; then (b) the
ladder, in this order of preference, each a `Config.CRACK` number: a lower
`windowStart` and steeper `windowDecay`; a `sweepSeconds` that shortens per
slice so the marker is quicker on the fifth than the first; and a lock-tier
PATTERN rather than only a width -- tier 3 splits the zone in two, tier 4
reverses the marker on the last slice -- so a Vault Lock is a thing a thief
reads, not only a narrower green. **Kept deliberately: there is no clock on a
step.** The pressure is the dog crossing the lawn, and a per-step timer would
change what the minigame is about; if the designer wants one it is a
decision, not a tuning. *Done when* a maxed Lockpicks against a maxed Vault
Lock is a real contest on the fifth slice, and the cold robbery advantage
still clears `ROBBERY_ADVANTAGE.min` with the new cycle time.

4c.2 **The crack panel. [DESIGN -- brief B7 to GPT; Art 4 applies]** The
430 x 176 panel is a dial, a marker, a gauge and a cap line, arrived at by
repair. It is the one screen a robbery happens on and it has never had a
look chosen. It now also carries the loot odds row (Phase 4.2) and will carry
the delivery room (4c.6). GPT designs it at 1040 and at 546; Fable rebuilds
it as the module it already is.

4c.3 **Catching is beats, not a radius. [Fable; DESIGN for the tells]**
Today a chase ends by one of: the dog's `catchRadius` on a tick, the owner's
one-second nab hold, the officer's `catchRadius`, or the thief reaching the
drop-off; the thief's answers are the dodge's half-second immunity, a bin, a
ladder, a bone and three gadgets. The catch gets a vocabulary instead of a
number, every item a TELL the thief can read and answer, none of it a speed:

* **the dog lunges** -- a wound-up leap with a visible crouch, dodgeable,
  landing a catch if it connects and a stumble (a beat of no movement) if it
  does not; the lunge replaces the tick-radius catch on tiers 2 and 3;
* **the officer cuts the corner** -- steers toward where the thief is GOING
  (the drop-off is known), not where they are, so a straight run home is the
  worst line and a feint is worth something;
* **the owner's shove** -- the nab hold gains a shorter, weaker alternative:
  a bump that knocks the loot loose for a beat without ending the carry, so
  a defender who cannot hold the tug still has a play;
* **the street helps** -- a resident on their lawn points and shouts when a
  carrying thief passes, which is information for defenders and costs the
  thief nothing but being seen.

*Done when* each beat is measured on a live rig against the getaway (53
studs, 4.4 s carrying) and the two-player check in 0.2 is repeated with them.

4c.4 **New gadgets. [DESIGN -- brief B8 to GPT for models; Art 1 pipeline
for the two sequences each]** Three exist (plunger, gum, zapper) beside three
bones, and every new one is a model, a `GADGETS` row shaped like the
existing three, a hot-bar slot -- **the number row is full at ten, so each
takes a letter and there are fewer left than it looks** -- and two uploaded
animations, throw and use, which no gadget has today. Candidates, each
checked against the rules a gadget has to survive (no speed above 16, a tag
never the catch, cost per throw, range falls as power rises, prank cooldown
on the target):

| gadget | what it does | rule check |
|---|---|---|
| **Smoke Bomb** | a cloud that mutes footsteps inside it for a few seconds -- the dog's `notice` hears nothing in the smoke | passes: the dog reads speed, and this is a temporary tiptoe by area, not a stealth flag |
| **Decoy Piggy** | a wind-up pig that runs a fixed line; a chasing dog or drone takes it for the thief for a beat | passes if it only ever affects NPC chasers, never a player |
| **Oil Slick** | a patch that slows whoever crosses it, thief included | passes: slower, never faster; it is `applySlow` on a zone |
| **Snare** | a ground trap that holds a runner for a beat, a defender's tool | passes as a gadget for the DEFENDER; needs the prank cooldown so a player cannot be chain-held |
| grapple / dash items | move the character | **refused** -- a second way to move, the rule `Config.DODGE` exists to prevent |

*Done when* two new gadgets are live with both animations uploaded and the
hot-bar letter map in `CLAUDE.md` is updated.

4c.5 **VERIFIED: a player can only rob the same player once per cooldown,
and back-and-forth robbing cannot climb the board.** Measured in the code:

* `whyCannotSteal` -- shared by crack and smash -- refuses a thief whose
  `lastGrab[victim][thief]` is under `Config.STEAL_COOLDOWN` (**60 s per
  thief, per victim**; residents 60 too, `stealCooldownFor`).
* `LOSS_CAP` refuses once a victim has lost **45% of their pig in a rolling
  hour, across all thieves** -- checked at attempt open, on every slice, and
  on a smash. Residents are exempt on purpose.
* The weekly TOP THIEVES board publishes `currentWeekStolen` -- coins the
  VICTIM lost, any target. So two friends robbing each other back and forth
  each add at most **0.45 pig an hour** to their total, while robbing
  residents cold adds about **6.4 pigs an hour** of victim-loss (half of the
  3.21x banked rate). Ping-pong is roughly fourteen times worse for the
  board than playing. Revenge (3x inside ten minutes) does not change that:
  it multiplies the thief's minted payout, never the victim-loss the board
  counts, and the loss cap bounds it either way.
* The rank counter (`data.robberies`) counts any delivery with coins in it,
  so one-slice ping-pong could count 22 an hour per victim before the cap --
  against a realistic 45 an hour robbing residents. Not a farm. The
  pig-crack acorn (1.11) is clean-crack-only, so the cap bounds it to about
  two per victim per hour.

**Decision offered:** the rule is in place and self-consistent at 60 s. If
the designer wants "once per X" to read as a rule rather than an arithmetic
consequence, raise `STEAL_COOLDOWN` for PLAYER victims to **180 s** and leave
residents at 60. It keeps revenge viable inside its 600 s window, costs the
resident supply nothing, and makes back-and-forth visibly not a thing. It is
one constant and `auditRobbery`'s lap check re-runs on it.

4c.6 **DELIVERY IS CAPPED AT THE PIG, AND THE REST IS LOST. [Fable] --
IMPLEMENTED September 16; live check pending** (see the status note at the end
of this step) `HeistService.deliver`
currently banks `amount * payout` with no cap -- its comment reads *"allowed
to overflow capacity: income stops above the cap anyway, so an overfull pig
is self-limiting, and it is the juiciest target on the street."* That
reasoning is reversed by decision: **a pig never holds more than its
capacity, from any source.** The victim still loses the full amount (that is
the robbery); the thief banks `min(amount * payout, capacity - coins)`; the
remainder is minted-and-spilled, never returned.

Why it is better than the dynamic it replaces:

* it closes the newcomer overflow named in `LATE-GAME-ECONOMY-PLAN.md`
  section 6.2 -- a level-5 player cracking a level-32 resident could bank
  180x their own capacity in one run; capped, they bank a full pig, which is
  still the best minute of their session;
* it gives *spend it or lose it* teeth on the robbery side: robbing with a
  full pig spills, so a thief empties the pig into the shop first, which is
  the loop the whole economy runs on;
* it makes the rebirth gate honest -- "fill your pig" now means AT the
  ceiling capacity, which the cost clamp guarantees is always affordable.

Rules that ride with it, each because a clamp is silent by default and this
project refuses silent failure: **the spill is said** -- the delivery toast
names it (*"Your piggy was full: 1.2M spilled."*); **the preview shows
room** -- every *"worth X at home"* string (crack clean, crack partial,
smash, the rob badge's gold figure, the crack panel) prints the capped
figure, so a thief is never promised coins the pig cannot take; **the same
rule for dailies and events** -- one sentence, *nothing puts more in a pig
than it holds*, rather than a robbery exception; **bail, the rap sheet,
`totalStolen`, the weekly board and the acorn are all measured against what
the victim lost**, unchanged. `auditRobbery` stays an upper bound (it assumes
room) and needs no change. *Done when* a delivery into a full pig banks
zero, spills loudly, still charges the victim, still counts the robbery and
the acorn, and the crack panel's preview matches the banked figure across a
full and an empty pig.

*Status, September 16:* `Config.fitInPig` caps every mint -- delivery, return
bounty, shop-drop resale, daily coin rungs, event payouts -- and each names its
spill; by designer decision own coins coming back (refunds, returned carries,
drone recovery, resident refunds) are capped and spill too. `deliver` sends
`spilled` on `HeistDelivered` and the card shows it. The crack and smash toasts
use `homeWorthPhrase` (payout x spree x room). The rob badge and the steal and
smash cards show `Config.homeTake` -- what the reader can carry home, capped at
their own room, PIG FULL / FULL when none fits. `theft` +14 checks, `badges`
+9, `shopdrops` +2; the `handoff` and `shopdrops` fixtures now carry
`capacityLevel`. All 23 suites pass.
*Not verified live:* a real robbery into a full pig in Studio.

## Phase 5 -- The reputation yard and season one

5.1 **The sign.** Tier chip, rank stars, NEMESIS line from `data.nemesis`
(twenty rows of counterparty and count, written on every player-victim
delivery). 5.2 **Trophies.** The seven rows in section 11 as `TROPHIES`
entries with builders. 5.3 **The season.** `Config.SEASON = { weeks = 4,
rest = 1, tiers = {...} }`, `data.season = { index, earned, tier }`, the
store keyed on `weekIndex() // 5`, tier rewards granted through
`SetService.grant` on crossing, the exclusive finish flagged `season =
index`. 5.4 **Finishes. [DESIGN -- Art 10's brief applies: an addition over a skin,
never a body repaint, because legendaries carry baked textures.]** `finish`
beside `skin` in `data.cosmetics`, a `Config.FINISHES` table, rendered in
`applySkin` as an addition only.
5.5 **Boards.** Top Defenders and the season board as two more
`OrderedDataStore` pages, the season board drawn five above and five below.
*Done when* a season rolls over lazily on a real week boundary with the
previous page intact, and a tier crossing grants once and never twice.

> **Implemented September 17 (Fable).** All five steps, in `SeasonService`,
> `Shared/SeasonBoard` and the files listed in `PROGRESS.md`. Differences from
> the text above, by decision or by measurement: the tier table is
> 10/20/40/75/150/210/280/370/480/620, re-solved on `tests/sim/acorns/model.py
> x3 season` after the x3 crates and the overnight fill (section 12's 3..700
> predates both); Season 1 is index 592 and opens 2026-09-24 (launch fell in
> 591's rest week); Van Job is deferred with the Cash Van; finishes carry no
> particles (standing rule); the season board is drawn three above and four
> below on the one street board, which now turns three pages rather than
> standing two more boards. Checked by the `season` suite (lazy rollover,
> grant-once). **Not verified live:** Studio look, DataStore pages, and the
> multiplayer paths.

## Phase 6 -- Events as structure

> **Amended September 16 -- see section 19.** Add the **Harvest Moon** row: the
> only acorn-theft window, with a bounded lighting tween. Section 19.3.

**[DESIGN -- Art 8 for the reward reveal and the two new `EVENT_UI` rows.]**

6.1 The weekly scheduled raid and the countdown chip's six-day mode; it pays
a free crate open through `ChestService.grantFree`. 6.2 The Cash Van:
`TrafficService` parks the van as an event target carrying a pig built by
`PiggyBank.buildVault` on the van's own plot record -- no owner, no cap,
double COINS. 6.3 Harvest Saturday: one flag doubling `growSeconds` for the
day. *Done when* a van event runs on a one-player server end to end, and
`auditAcorns` confirms no event path credits an acorn.

6.4 **Harvest Moon. [Fable for mechanics now; B4 from GPT for the look]**
Section 19.3. A `Config.EVENTS.roster` row and an `EVENT_UI` row; while
live, other players' *ripe* tree acorns are shakeable at x5 and resident
trees at x1, carried in the basket under the normal getaway; storage stays
safe; a bounded `Lighting` tween on entry and exit, no permanent cycle.
Weight and length are numbers to re-derive (19.5). *Done when* the event
runs end to end on a one-player server, the shake prompt on another tree
exists only while the banner does, the lighting returns to `ClockTime` 14.5
exactly, and the roster's measured frequencies are recorded.
**SUPERSEDED THE SAME DAY BY MIDNIGHT HEIST (designer decision).** The moon
was built (150 s, `acornTheft`) and measured: its inherited x5 on player trees
made moon theft ~67 acorns a day for an active multiplayer player against ~28
from their own tree. The designer replaced it, and Rush Hour with it:
**`roster.midnight`** (180 s, weight 2) is a dusk (`Config.MIDNIGHT_LIGHT`,
`WorldService.setNight` / `restoreDay` / `DAY`) during which coin steals pay
2x and a clean player-pig crack that ends under it pays 2x acorns
(`Config.MIDNIGHT`, stamped on the carry). **Acorn theft is disabled** --
no row opens it, `auditAcorns` (`theft.disabled`) refuses one that does --
to be revisited after play-testing; the shake/basket theft code stays,
closed. Solo players get no acorn bonus (residents mint no crack acorn),
by decision. Measured: raid 40.9% of slots (every ~37 min), night 59.1%.
`midnight` suite 31 checks; `theft` +4 (night stamp, paid after dawn,
residents still nothing). *Not done:* Studio run; B4 is now the night's look.

## Phase 7 -- Verbs

Mastery rows per target, heat modifiers, and the rebirth ladder of verbs --
the record for all three is in Part III B7. Each is its own plan when it is
reached.

## Later, by decision

The yard pet (built as a client renderer, unwired), seasons of the ground
(the repaint), the gilding ladder on coins spent, co-op robbery, and trading.
Part III B carries each with its reasons.

---

## The art track -- Art 1 to Art 11, running BESIDE the phases

Not a phase eight. Art has a different critical path -- an upload can be
moderated, a design gate waits on a person, and a mesh authored outside this
repo lands on the designer's own clock -- so it runs alongside, and the table
below is the only ordering that actually binds.

**What blocks what:**

| art step | blocks | because |
|---|---|---|
| Art 3, the element kit | Art 4, 5, 6 and every new panel | a panel drawn before the vocabulary is agreed is a panel drawn twice |
| Art 4, the minigame panels | **Phase 2.3**, the shake | the shake IS its panel; there is no shake without one |
| Art 5, the timer element | **Phase 3**, the street timers | section 9 asks for four states on a badge that prints a word and a number |
| Art 7, the oak and the basket | **Phase 2.1** | a currency nobody can see is a currency nobody counts |
| Art 8, events | **Phase 6** | section 13 changed what every event pays |
| Art 11, the shelves | **Phase 4.3**, and therefore the pack | section 14 is a content list, and this is the content |

Everything else can run whenever there is a person free.

> **September 16 — the GPT/Fable split, RETIRED 2026-09-23.** For a week the
> work above was split between a visual-design collaborator and a scripting
> one, with a per-feature brief for each hand-off. That model is gone: several
> Claude sessions work this tree at once now, under the announce-then-act rule
> in `CLAUDE.md`, and the two documents that carried it are deleted. Their
> briefs either shipped — the house catalogue UI, the trophy rooms and the
> house exteriors, all better documented now in `assets/houses/docs/` — or were
> retired with their features, which is what happened to the Harvest Moon and
> to the acorn tree. Art 1 to Art 11 below are unchanged; Art 11's *Houses*
> bullet points at `LATE-GAME-ECONOMY-PLAN.md` for the ceiling.

**Art 1 -- the two empty animation rows.** No design in it, and it is first
because it is free and because both are live silent failures on the published
game: `sneak` blank means the tiptoe is a speed number with the walk cycle on
top, and `carry` blank means a stolen pig floats in front of a thief whose
arms are at their sides. Both sequences are already BUILT by
`DodgeRoll.buildSequence` and `CarryPose`; `animdump` stages them in
ReplicatedStorage for publishing. *Done when* both ids are in
`Config.ANIMATIONS`, each is fetched back with
`GetKeyframeSequenceProvider:GetKeyframeSequenceAsync` and diffed against the
sequence this repo builds for that key -- **the name on an asset is the one
thing nothing in the engine checks** -- and `Main`'s startup warning prints
nothing on a live server.

**Art 2 -- the coin, and its arrival. [DESIGN]** Section 18.4. Build the coin
as a part carrying `Theme.coin`'s own three-layer reading into three
dimensions, fly it into the coin slit on the drip, squash it on landing, light
the slit for a beat. **`COIN_COUNT` is not touched**: it is the drip cadence
and doubling it doubles the chime rate as a side effect. *Ask for:* what a
coin looks like, and how loud the arrival is -- loud is affordable once and
unaffordable four times a minute. *Done when* a coin lands about every fifteen
seconds at level 0 and level 40 alike, the arrival reads from the pavement,
and `playCoinDrop`'s own comment about a heartbeat is still true of it.

**Art 3 -- the interface kit. [DESIGN]** The whole game's UI vocabulary
decided once, as a set, rather than repaired one surface at a time: the card,
the chip, the badge, the bar, the banner, the toast, the pill, the well, the
price tag. **Section 18.6 is the work list** -- every surface in the game with
its measured size, grouped by where it lives, plus the nine rules a design
here has to survive, every one of which has already cost this project a bug.
Design the KIT in 18.6E first and fifty-six surfaces follow from it; design
them one at a time and you are repeating how the current look was arrived at. It is `Theme` and `ShopStyle` and it already has a palette, an
outline rule and a contrast audit at zero failures -- what it has never had is
a LOOK anybody chose. *Ask for:* three reference images and a yes or no on the
warm-paper-and-ink direction the theme currently holds. **Change the tokens,
not the call sites**: 167 places read `ShopStyle` and every one is an alias
for a `Theme` value, so a direction change is one file. *Done when* the
contrast sweep still reports zero failing pairs across all ~425 labels, in
both the light and dark token sets, walked live rather than eyeballed.

**Art 4 -- the two minigame panels. [DESIGN]** The crack and the shake, and
they are one job because they are the two screens a robbery happens on and
they must not look like two different games. The crack exists and works -- a
dial, a sweeping marker, a gauge with the next slice drawn on it and the loss
cap as a red line. The implemented collection panel offers ground or stored
Acorns for five seconds, dragged into a carry basket. *Review:* whether the
56px targets and two-row layout read clearly on a phone held sideways. *Done when* both are driven end to end
on a touch target: five slices landed, and a shake caught and delivered.

**Art 5 -- the re-rob timer, as an element rather than a word. [DESIGN]**
`RobBadge` prints `ROBBED 54s` and `NEW HERE 1m`, which is a label with a
number after it. Section 9 asks that badge to carry four states -- the join
shield, the rejoin shield, the per-thief cooldown and the hourly loss cap --
and four states in text is a paragraph over a pig. *Ask for:* one element that
counts down and says WHICH clock it is, readable at `RobBadge`'s measured 224
studs. *Done when* all four states render at 224 studs, the badge still grows
and shrinks with the lock ladder, and the order it asks its questions in still
matches `whyCannotSteal` -- **reorder one and reorder both**, or the badge and
the refusal contradict each other.

**Art 6 -- the daily board and the reel. [DESIGN]** Two surfaces, one job:
they are both *something good just happened*. The daily board is seven fixed
published rungs with a free crate on day seven; the reel is `SpinWheel`,
shared by the event drop and every crate open, and it is the reveal for the
entire cosmetic track -- which after this plan is the entire endgame. *Ask
for:* a layout for the board, and a treatment for the reel's landing moment.
*Done when* a day-seven claim opens its crate through the real path and the
reel's printed odds are still the server's own `liveOdds` numbers and not a
second copy computed on the client.

**Art 7 -- the acorn, the oak and the basket. [INTEGRATED -- filled/readability review pending]**
The designer imported a three-part Acorn (Nut, Cap, Stem) during 2.3. Its
shared texture and measured transforms now live in `Config.ACORN_MESH`;
`AcornModel` supplies tree/ground Acorns, storage fill and carried contents. The
imported assembly is archived under `assets/acorn/`. The earlier recorded
source GLB is not present on this machine. The panel/HUD icon remains the
separate code-drawn `Theme.acorn`, legible at touch/chip size.

The oak now uses the imported compact Blender asset in `ACORN_OAK_MESH`,
superseding the street oak at 0.85. The woven basket is the carry prop.
The open storage crate now holds the spendable balance and always shows its
exact count. Its blockout is implemented; final art should follow
`assets/crate/BLENDER-PROMPT.md`. *Review:* ripe versus loose Acorns, empty
versus full storage, and carried basket readability from normal camera range.

**Art 8 -- the events, built out and fixed. [DESIGN for the reveal]** There
are two events in this game, `raid` and `rush`, and section 13 rewrote what
every event may pay.

* **Fix what the two pay.** The raid pays a free crate open rather than a
  handful of acorns; Rush Hour stays on coins and the draft's move of it onto
  acorns is withdrawn.
* **Add the two that exist on paper.** The Cash Van (uncapped coins, no
  victim, the quiet-server answer) and Harvest Saturday (every tree drops at
  twice the rate for the day). Both are `Config.EVENTS.roster` rows and
  `Config.EVENT_UI` rows -- **a third event is a row rather than a branch**,
  which is what that table was extracted for.
* **And the roster stops being degenerate at four.** At two events the
  anti-repeat rule collapses: "never the same twice in a row" leaves exactly
  one candidate, so the picker strictly ALTERNATES and the weights do nothing
  -- which is why `REPEAT_WEIGHT` damps rather than forbids. At four the
  weights finally mean something, and the measured frequency has to be
  re-derived because it is a consequence of them and not a target.
* **The interface.** The banner and the countdown chip exist and are measured;
  each new event needs its `EVENT_UI` row (tone, glyph, wording) or it draws
  nothing and falls through to the patrol -- deliberately the louder failure.
  The drop reel is Art 6. **The acorn chip is new**: `Config.ROLL_CURRENCY` is
  the one table player-facing wording reads, and acorns need a HUD chip, a
  shop price glyph, a crate card and a shortfall line that names where they
  come from, because it is the one price in the shop more coins cannot meet.

*Ask for:* what an event reward reveal looks like, once, used by the raid, the
crate and the day-seven claim. *Done when* four events run end to end on a
one-player server, the picker's measured frequencies are recorded, and no
event path credits an acorn.

**Art 9 -- the dogs, in outside software. [DESIGN, and the designer's own
hands]** Section 18.5 has the full argument and the one constraint that
matters: **authored in separable pieces, or the six coats and the ON GUARD
collar tell both die**, because `applyTier` repaints the animal per breed from
four tone slots and a single-`Color` mesh cannot carry that. Low-poly and
flat-shaded, to sit with the houses and the shops -- a realistic dog would be
the only realistic object on the street. *Ask for:* three breeds, uploaded,
with the piece names. The ids go in `Config.DOG_MESH`, shaped exactly like
`Config.PIGGY_MESH`. *Done when* a row falls back to the code-built dog when
it is empty, one breed can land alone, the collar still goes neon on guard
duty, and the tier repaint still reaches every piece.

**Art 10 -- skins, at the tiers that are actually short. [DESIGN brief]** Not
"more skins": 45 exist at 16 common, 19 rare and 9 legendary, and the holes
are specific.

* **The animal shelf's rare tier is EMPTY** -- its odds read common 96 /
  legendary 4, so the middle of that crate does not exist. That is the first
  gap, and the one a player meets soonest.
* **Four `EXT` creatures are authored and unuploaded** -- dragon, phoenix,
  rainbowtiger, stormwolf -- and they are precisely what the animal legendary
  tier is for. Its current two, the Bengal Tiger and the Snow Leopard, are a
  coat and a pattern and do not meet the brief; they hold the top of that
  shelf only because a crate with no top end is a crate nobody opens twice.
* **The brief per tier is already written and is worth keeping**, because
  "epic" was never a brief anybody could build against: **common is paint;
  rare is paint with a twist and something that glows; legendary adds
  GEOMETRY** -- fur, a pattern standing proud of the body, parts that are not
  the pig -- **plus an animation and a glow.**
* **A legendary is never a body repaint.** Legendary skins carry baked
  textures and a colour multiply over a texture is the muddy pig.
* **A new skin needs a `rarity` and a `chest`, and may never carry a `cost`**
  (section 14.1), or it is a coin item in a crate and the class line is
  broken by one row.

*Done when* the animal crate's three tiers are all stocked, `chestPool`
refuses nothing, and no `floor` in `Config.CHESTS` names a tier its pool
cannot stock -- **a floor that empties a crate is caught loudly and a floor
that PROMOTES one is not**, which is how six million coins once bought a
guaranteed legendary.

**Art 11 -- the section 14 shelves, which are mostly art. [DESIGN per shelf]**
Section 14 says what to add and what it is worth; this is who makes it. In the
order 4.3 gives:

* **Standalone piggy effects — cancelled by the user September 16.** Do not
  restore the shop or add purchasable auras. Retain coin-deposit feedback
  and effects belonging to Legendary skins only.
* **Shop interiors. [DESIGN]** The four units got four silhouettes on the
  outside and kept one room shape on the inside -- the exact complaint that
  was fixed on the frontages, unfixed one wall behind them. Everything
  needed is already built once: `Config.shopRoomHolds`, the plinth-is-a-ring
  lesson, and the light-masonry/dark-joinery split that ended a four-suspect
  chase through a white window.
* **Houses. [DESIGN]** Breadth at existing prices, never a tier above the
  top: the Sky Castle is 80M against a hard ceiling of 96.9M, and
  `auditEconomy` refuses anything above it. September 16 priority is exterior
  catalogue expansion; interiors are deferred.
* **Fences. [DESIGN]** STYLES, not tiers: the panel changes and the height,
  the hazard and the climb never do. `Config.fenceMesh` already falls back per
  style to the primitive decorator, so these land one at a time.
* **Gadgets, with throw and use animations. [DESIGN]** Three exist. Each new
  one is a model, a `GADGET_FUN`-shaped entry, a hot bar slot -- **and the
  number row is full at ten, so the twelfth consumable needs a letter and
  there are fewer left than it looks** -- plus two new uploaded sequences,
  which is the first time this game has animated a throw at all.
* **Rides and ornaments.** Four and fifteen, on directions already set.

*Done when* the summed spendable coin catalogue clears 400M, no priced item
appears in any crate pool, all seven effects are buyable, and `auditEconomy`
is clean after every batch rather than after the last one.
---

# PART III -- THE RECORD

Carried out of the retired documents so nothing that justified a constant is
lost. **Where an old pointer lands:** `core-loop-plan.md` section 9 is D4;
`nab-plan.md` §4.2 is D1; `shop-vaults-plan.md` is D2 and B4; `yard-plan.md`
is B3 and C; `ROADMAP.md` is Phase 0 and C; `endless-plan.md` is B7 and C.

## A. What has shipped, so nobody re-proposes it

Residents on every unclaimed plot; the robbery audit and its band; the shield
ending on the first robbery; the rob badge saying yes as well as no; the
first-job card; the crack as a greed dial; the smash; the watching dog and
the owner-home alarm branch; tiptoe and the Sneakers rung; casing; the
owner-interrupt; the thief-side gate jam; the spree; the shop vaults and
the shopkeeper; the shop drop; skin theft with four rails; the tug with its
bounty and rest; catch effects; VIP and the starter pack as passes; the
mailbox, the doorstep crate, the delivery van and the rebirth fireworks; the
garden; the trophies and the plinths; the dog's coats, kennels and toys; the
pet's client renderer and model (unwired -- no Config, no service, no
catalogue); the chests, spares, combine, sell and the Crates and Inventory
panels. The yard plan and the nab plan both said much of this was unbuilt
while it stood in code, which is the reason this record exists.

## B. Still open, carried with its reasons

**B1 Core loop.** *A choice INSIDE a single robbery* beyond bail-or-stay --
the tills delivered loud-versus-quiet *between* robberies; a choice within
one is still the more valuable version. *The un-wallable-plot audit* --
"nothing an owner does, in combination with anything they can buy, may
reduce the maximum possible take to zero" -- was stated as work to do and
never written. *A general rule for multiplicative slows* -- only the
tiptoe/climb pair is refused (0.35 x 0.35 is two studs a second); there is
no floor on the product. *The marked allowance line on the greed bar* --
decided, drawn against a real player only, unbuilt. *The rap sheet's
consequence ladder* -- how far from the floor you are, and what the leader
has, were left off the chip because a 176x34 chip cannot draw them; they
need their own surface. *Carry two pigs* -- dropped because `carrying` is
single-victim state read by seven things and the greed decision is already
carried by the crack; reopen only if the two-player session says the single
getaway is thin. *Vault a fence without a ladder* -- rejected; the ladder is
the route. *Co-op robbery* -- the cheapest source of infinite variety because
the other player is the variety; wants the crack as its home; needs 0.2
first. Open questions kept: does the dog's notice care about distance as
well as speed; should a resident's pig read differently from a player's
before a thief commits to the road; does co-op split the haul or pay both.

**B2 Nab.** Does breaking free cost the thief a slice or only end the nab;
does the bounty count toward the rap sheet (it should not); where a catch
effect's sound comes from; whether VIP gets a colour. *The collar and the
duty vest*: the guard-duty tell is a real defence signal a thief reads before
burning a 30,000-coin Golden Bone, so if the neon collar is ever made
cosmetic the vest ships in the same change, never after.

**B3 Yard.** *Phase 5, the world turns*: a seasonal repaint read once at
startup from the UTC month, a palette per season authored WHOLE (a tint
applied as a multiplier lands somewhere nobody chose -- `GRASS`, `GRASS_DARK`
and `LAWN` came down 30% the day the lawn went flat for exactly that
reason), the hills decided separately because a half-buried sphere and a
plane catch the sun differently, the ~1,400 tufts (47% of every BasePart in
the world) tinted at build and never on a loop, and a communal snowman as
the first thing two children do together. *Phase 6, the flex*:
`data.totalSpent`, incremented at the existing spend sites and never derived,
with fittings gaining brass, silver and gold finishes as lifetime spend
crosses thresholds -- **measure coins spent, never coins held**, because held
is already printed over every pig in gold and advertising it harder paints a
target, while spent is permanent and unstealable. *The pet*: the renderer
never attaches to the character (so `hideCharacter` cannot miss it), and it
**must not read as a guard dog** -- a cat, a duck, a piglet, or off other
people's lawns -- because a dog trotting about is the tell that somebody is
home. Open: where the duty vest sits against a bought collar; whether
seasons touch the canopies (baked texture; a tint may need a second mesh);
how many coats before Rex and Titan stop being distinguishable at pavement
range; and confirming the mailbox flag clears on release. Trophy rows still
unbuilt: a personal-best plaque, the cracked dial, days unrobbed, bail
receipts, and spares-as-display (a spare Pearl under glass is worth more than
the 266,666 coins it sells for).

**B4 Shop vaults.** *Does robbing a shop belong on the rap sheet?* It does
today because a shop is a plot; a shop with no victim arguably should not put
a child on Most Wanted, and the police loop in a one-player server is exactly
what the rap sheet was built to make work. Leave it until a full server says
which way it reads. *The verge composition*: two canopies a gap plus the
bracket signs and the rob badges have to stay readable from the road, and
that wants a human looking down the street, not a number.

**B5 Animal crate.** The rare tier is empty (`odds = { common 96, legendary
4 }`); the epic-glow lever is unmeasured in the real renderer (a baked
colour is a reflectance and cannot return more light than falls on it; the
test is a bright part on a lawn in Studio, twenty minutes); the mane
(`furSet = "mane"`, asset already uploaded, worn by nothing) is a legendary
trait for one Config field; `makeModelIcon` frames off the bounding-box
centre and a crest drifts it 0.318 studs; and the catalogue prune for
scrapped skins is now overdue rather than pending. `animal-crate-plan.md`
stays until the glow test is run, because seventeen art-pipeline files cite
its technique sections.

**B6 Launch.** Telemetry, deliberately deferred behind the core loop, and it
goes to the top of the list the day the game is live -- "you cannot get data
from zero players, so the two-player session IS the telemetry until then."
Cleared audio uploads. A thumbnail and an icon. A soft launch, then tune
live: the first number to look at is D4.

**B7 Verbs, from the endless plan.** *Heat modifiers* the thief sets on
their own pig, each a rule change on an existing verb (Bare Hands, No Dodge,
Heavy, One Short, Loud, Flagged, Clean Only) multiplying acorns only, with
slots earned by rebirth. *A rebirth ladder of verbs*, one per rung, each
ADDED never swapped -- a heat slot, a panic lock, insurance, a crew of two,
the back way, a fence for spares -- with each rebirth starting at the two
levels it unlocked so the re-climb is never the same rungs twice.
*Contracts*: three rotating cards from a grammar, cumulative, any target,
never expiring, completable against residents. *Mastery per target*: a row
of ways each shop and house tier has been robbed, 85% unlocking an approach,
never 100%. The One Short modifier removes the fifth slice, 7.7% of a pig,
and has to be checked against a maxed sack the way `LOSS_CAP` was or it
silently refunds the sack's top rung.

## C. Rejected, and staying rejected

* **A flat coin payout multiplier for robbing players.** Parity at level 0
  wants `HEIST_PAYOUT` near 29 or a cap near 360% an hour; the second makes
  being robbed devastating. The fix was never this dial; it was the supply.
* **PvP as the supply at any cap.** A sole thief robbing seven permanently
  full neighbours perfectly earns 0.97x standing still. The supply has to be
  non-player at every population; that is arithmetic, not a preference.
* **Capping the server to buy supply.** `MAX_PLAYERS` 6 against 8 plots
  worked and paid for a robbable street by removing players. Open the gap
  with plots, never with children.
* **Paying less for robbing a resident than a player.** Sound reasoning
  (a resident has no pain) with a dangerous conclusion: it makes robbing
  the child the better play. The incentive must point at the NPC.
* **A resident's pig as a share of capacity.** A category error: capacity
  is a storage limit for something that spends, and a resident never
  spends. The ratio drifted 3.7x to 12.3x. `pigSeconds` pins it.
* **Lengthening the coin ladder.** Postpones the end; does not remove it.
  `INCOME_GROWTH` 1.30 with the income ceiling at 1.00 is 6.6 weeks; a
  ladder has a top.
* **Displayed objects earning coins per second, stolen off your base.**
  Steal a Brainrot with pigs. The tree survives that refusal by producing
  no coins, never being taken itself, and paying nothing extra on delivery.
* **A yard stash, or anywhere on the lawn to keep coins.** Reverses the
  pivot's central decision and leaves `LOSS_CAP` protecting a wallet that
  no longer needs it. Collectable is fine; stealable is the stash in a coat.
* **Trophies, ornaments, houses or upgrades a thief can take.** Their route
  back is coins, and coins are for sale; a stolen ornament becomes pay to
  get your stuff back.
* **Losing your house for being robbed too much.** A crying-then-uninstall
  event a parent sees. What was right about it is the plaster.
* **A robbery that costs the victim a spare or a shard.** A spare is
  combine fuel; a theft that minted one would be a faucet outside the crate
  system.
* **The opt-in rail.** Redundant by construction; see section 7.
* **A flat 3x buy-back.** Forty-two times cheaper than rolling for a
  legendary; the ladder is the shape.
* **The rebirth skin as a published ladder** (the first draft's answer) --
  overridden by the Rebirth Crate, with the fork in section 6.
* **Direction B in full (carry acorns to a shop counter to convert them).**
  Its production half became the tree; its carry-to-a-counter half stays out
  because the shake and the existing carry do the same job with no new
  counter, no third thing to hold, and no second way to farm a lawn.
* **Direction C in full (ornaments and provenance as the spine).** Recovery
  needs the thief to be on your server, and with eight-player servers and no
  matchmaking they usually are not: a grudge against somebody you may never
  see again. Its hot rule survives; the rest does not.
* **A coin pack that is a flat number, or that lands in the pig unasked.**
  A flat pack is worth 3.5K to one child and 97M to another for the same
  Robux; a pack that lands in the pig is stealable the moment it is bought.
* **Any Robux purchase that grants currency, a rate, or a random outcome.**
  A 2x income pass takes the full-server figure from 3.51x to 1.76x, through
  the floor, on boot. A daily free crate, a VIP chest and a coin stipend are
  the three most common VIP perks on the platform and one sentence refuses
  all three.
* **Timed shields.** They tax the core verb.
* **The owner-locked front gate.** Contradicts the always-open gate, does
  nothing about camping, stacks defence on the one plot with an owner on it.
  Kept only inverted, as the thief-side jam.
* **A counter-mechanic for camping.** The economy flip made camping
  self-punishing; the right response to a camper is that they are losing.
* **The lockpick minigame as a gate.** "Complete N taps to open the lock"
  is a checklist with an animation on it. It is a greed dial instead.
* **Seeing the crack one step ahead.** There is no clock on a step, so the
  zone is visible as long as anybody likes; a look-ahead would read as a
  capability and measurably do nothing.
* **The dog sleeping while its owner is home.** You would never see the pet
  you paid for. It sleeps only while the owner is out.
* **Waking the dog on the lock being rattled.** Then every robbery is loud
  and being good at the minigame is rewarded with nothing. It wakes on a
  fumble, on footsteps, and on a shake.
* **Alarm on the first slice, or on completion.** The owner always wins, or
  can never defend. On a miss is the third answer.
* **A tug outcome for the dog or the patrol.** An NPC has no decision to
  make; the dog stays binary and an arrest is a confiscation.
* **A rescue fee taken from the recovery.** Being rescued would cost you,
  which reads as a second robbery to a nine-year-old. The bounty is minted.
* **The bounty multiplied per participant.** Split, never multiplied, or a
  crowd is a hard stop.
* **The bounty shipping ahead of the per-thief rest.** D1 is the arithmetic.
* **A shopkeeper who reacts to a clean crack.** It would reprice the four
  targets that carry the supply floor at a full server with no audited
  number moving. Fumble and smash only, which keeps the audit blind to a
  defender *correctly*.
* **A colliding shop shell.** Nothing here pathfinds, so a solid building is
  a place nothing can reach you.
* **A tutorial.** One sentence; a nine-year-old closes a tutorial.
* **Sightline cover, gravel paths that wake the dog, decoy piggies, and
  bluffs** are *deliberately unsettled* rather than rejected: every one
  changes an outcome and deserves its own decision priced against the
  tiptoe tree, never arriving inside a cosmetic pass.
* **Trading and the yard sale.** Scamming and moderation load on under-12s;
  it needs a policy answer before a design one. Phase 3 at the earliest,
  spares only, atomic, never on a lawn, behind a safety quiz.
* **Offline plot raiding.** Every async raider that survived runs shields,
  guards, caps and a no-attack-while-online rule; release on leave stays,
  and the hook worth keeping is the report, not the loss.
* **Resident heat** (NPC neighbours hardening per account). It makes the
  world climb with the player, but the world it climbs is NPCs. The dial
  moved onto the thief as heat modifiers.
* **Countdowns, fake discounts and repeatable consumables in a pack.** Ten
  Golden Bones is 300,000 coins in a trenchcoat; time-pressure selling aimed
  at nine-year-olds is a decision, and it is made here.
* **A raised-arm riding stance.** The hand ends up in the player's own hair,
  which is a stud wide on some avatars and a different stud on every one.

**Rejected September 16, from the acorn re-centring (section 19):**

* **A permanent day/night cycle.** Would re-tune every lighting, neon and
  readability decision made against one sun, and a cycle that opens acorn
  theft half the time does not make it rare. A bounded lighting tween inside
  an event gets the fantasy without the cost.
* **Always-available acorn theft** (tree shakes and storage raids on every
  lawn at every moment). It made a second everyday robbery beside the pig
  and diluted the title verb. Theft lives inside Harvest Moon only.
* **Storage raids** in any form. Banked acorns are the timer currency's
  bank; the pig is the one wallet a thief opens.
* **Crates priced in coins, denominated in seconds of income.** Legal once
  the pack is gone and it keeps a crate a constant time-cost at every level
  -- and it is a price that moves, which a child cannot read off a card.
* **The coin pack** (section 15). Never shipped, blocked by its own audit,
  argued against in its own section. Dropping it is what let crates stay in
  acorns without inventing anything.
* **Acorns paid for robbing a resident or a shop.** The pig-crack acorn is
  the reason to rob a person; the tree is the solo faucet.

## D. Measurements recorded only in the retired documents

**D1 -- The swarm, verbatim, from the nab plan.** *A thief carries at 12
and a free bystander runs at 16, so a chaser closes 4 studs a second over a
53-stud, 4.42-second getaway. A nab does not require touching anybody: it
requires getting inside `NAB.distance` (14 studs) with `NAB.hold` (0.4s) to
spare.*

    by t = 4.02s the thief has gone 48.2 studs and a chaser can cover 64.3
    => a bystander starting up to 30.1 STUDS BEHIND still lands the nab

*For scale, the alley between two yards is 16 studs, so a neighbour standing
on the next lawn is already inside that window. Against that the thief has
exactly one counter. `Config.DODGE` buys 4.5 studs and 0.5s of immunity --
which does waste a whole hold, worth 2.0 studs of closing -- on a 5-second
cooldown against a 4.42-second run. One dodge per getaway, and it is
single-use against an unbounded number of chasers:*

    2 chasers  -> dodge the first, the second lands
    n chasers  -> n - 1 land

*No value of the bounty fixes that, because the fault is not the size of the
incentive, it is that the threat scales with the crowd and the counterplay
does not.* What balances it: the rest stamped on the thief (a carrier is
under a tug at most `recoverSeconds / (recoverSeconds + cooldown)` = 25% of
any stretch of time, however many are holding), the bounty split never
multiplied, and a partial outcome. The staged-robbery arithmetic: a pair
gives up the haul x `HEIST_PAYOUT` (2.0) to gain the haul x bounty (0.25),
eight to one against. *If `HEIST_PAYOUT` ever falls, the bounty has to fall
with it.*

**D2 -- The shopkeeper, from the shop-vaults plan.** `speed` 14.5 is the
officer's number, between a carrying thief's 12 and a free player's 16, so
the loot is what makes you catchable. `catchRadius` 4.5, because the
Terrier's 7 was measured wrong: the shopkeeper stands **6.83 studs** from
where a thief has to stand to reach the smash prompt, so the catch fired on
the first tick and robbing a shop was an unavoidable arrest. `wakeDelay` 1.2
gates the catch as well as the walk, or somebody inside the radius is taken
on the first tick with no tell. `giveUp` 60 studs is a leash as well as a
clock, or a chase strands the shopkeeper at the far end of a 350-stud street.
Verified live: out to 2.16 studs, caught at a gap of 4.38, back at the
counter by t4.4. Reacting only to a fumble and a smash is what keeps
`auditRobbery` blind to a defender correctly: a clean-crack reaction would
reprice the floor at a full server (3.37x against 3.0, twelve per cent of
headroom) with nothing in any log. Two bugs found by driving: `byDog` doing
double duty as behaviour and wording ("a message naming a dog that is not
there is the tell lying"), and `goHome` being a settle rather than a walk.

**D3 -- The structural finding, from the core-loop plan.** Under a 25% cap:
total hourly victim loss = 8 x 0.25 x pig = 2.0 pigs; thief gain = x2 = 4.0
pigs; per player, 0.5 pigs an hour. Level 0: 2,500/hr robbing against
36,000/hr idling (7%); level 20: 2.1M against 14.5M (14%). At 0.45 it is 13%
rather than 7% and the conclusion does not move. `HEIST_PAYOUT` was raised to
make robbing worthwhile and `LOSS_CAP` added to keep it survivable, in the
same session, and nobody multiplied them. **The cap binds long before the
payout does.**

**D4 -- The first number to look at in a real playtest.** *Watch what the
tills do to a busy server. Eight thieves working four tills will drain them,
so a full street should find them thinner and PvP relatively more worth
trying. That is arguably the right pressure rather than a problem.* Since
partly answered: `PLOTS_PER_ROW` went 4 to 5, putting two permanent resident
houses behind the four shops at every population, and the audit sweeps
population. Still the first thing to look at, now beside the basket.

**D5 -- Residents as a faucet, the drift table.** A resident's pig as a
share of capacity, which grows 1.40 a level against income at 1.35:

    lvl  1   pig = 300 s of its own income   ratio  3.69x
    lvl 20   pig = 599 s                     ratio  7.37x
    lvl 40   pig = 998 s                     ratio 12.28x

`pigSeconds` pins it (`ratio ~= 0.0123 x pigSeconds`); it went 400 to 200
when the spree shipped so that cold is 4.12x and hot is 8.25x -- what
everybody earned before, with the spree as how you reach it.

**D6 -- Supply as a function of population.** Residents are seated on
unclaimed plots, so at a cap equal to the plot count a full server had none:

    players  residents  robbing vs idling
       1-5       7-3        4.12x
        6         2         2.92x
        7         1         1.46x
        8         0         0.14x

The audit hardcoded `PLOT_COUNT - 1` residents, one point on the axis that
broke. Measured with every victim permanently full, a sole thief robbing
seven neighbours perfectly reaches 0.97x. The shops fixed it (3.51x cold at
eight players), and the extra plot column fixed the shops being drained.

**D7 -- The first thirty seconds, as a storyboard with four requirements.**
Spawn 17 studs from your own empty piggy; one line, *Your piggy is empty. Go
and take somebody else's*; walk to a resident's pig with a number on it;
cross the lawn past a sleeping dog; the crack, and the first real decision in
the game is a greed decision made nine seconds in; run home; deliver doubled;
buy the first upgrade. Requirements: the first target already has money in
it; the first haul clears the first upgrade (a seeded resident holds 3,000
and one haul banks 480 against a rung of 400); **no shield may block the
first target**; and the first robbery a player ever performs cannot be a
live contest against a defending owner. Before the fix, the first robbery
available to a new player cost them 82 coins.

**D8 -- Tiptoe's guarantee chain.** Tiptoe on 5.60, under Scruffy's notice
of 11 and Rex's 10.2, over nothing against a Titan's 0; carry 12.0; so *you
can sneak in and you can never sneak the money out*. Refused while carrying
(12 x 0.35 = 4.2 is under every threshold and the risk half evaporates) and
while climbing (0.35 x 0.35 is two studs a second, seven seconds up an
eight-stud fence). Sneakers at max 9.60 is still under Rex.

**D9 -- The gate jam.** 0.35 for 2.0s costs a chaser 20.8 studs against the
17.7 they gain over a whole getaway -- one jam deleted the chase. 0.55 for
1.2s costs 8.6, about half, and leaves it winnable.

**D10 -- The catalogue's own numbers.** Both upgrade trees total 467K, 156
seconds of idling at level 20, so "nobody can buy both" is a tutorial and not
a pillar. The effects catalogue is three commons and two rares, which is why
there is no effects chest: it is the price spread that is missing, not the
count.

## E. Invariants, in one place

* The server owns all state; the client renders the last push.
* One balance, all of it in the pig, all of it stealable; `LOSS_CAP` is the
  only bound on what a real person can lose in coins, and the basket's take
  cap is the same bound for acorns.
* The thief's reward is never the victim's loss: `HEIST_PAYOUT` mints the
  extra; the bounty is minted; a shake pays no more than it took.
* Residents are a resource, never a rival: no cap, no grudge, no board, and
  everything a thief can feel is identical.
* The robbery advantage is a flat ratio in a band: floor 3.0, ceiling 10.0,
  spread 0.02, swept cold and hot and across population, and the lap must
  be longer than the cooldown.
* An audit that models best-case play cannot catch a defence; the shopkeeper
  and the dog react to loud paths only, on purpose.
* Exactly one defender per lawn: the owner home means the dog is the alarm,
  the owner away means the dog is the enforcer.
* A verb is added at a rung, never swapped for one.
* Derive, never pin: a pinned figure describes the game on the day somebody
  typed it.
* Two curves multiplied without checking the product is the most repeated
  failure here; section 17 names this plan's five.
* Two meanings never share one field.
* Nil is not no: a client-read attribute has three states.
* `ClientMain` is at the 200-local ceiling; a new client feature is a module
  started in one statement holding no local.
* Anything a thief reads from the pavement is checked with a photograph from
  the pavement, not a probe beside it.
* Every generated asset is an upload under the developer's own account;
  generate few.
