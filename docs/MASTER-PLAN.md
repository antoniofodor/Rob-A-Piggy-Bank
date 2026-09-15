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
| the nab today | a 1.0s tug that drains coins back to the victim per tick; 25% bounty minted and split; 3s rest on the thief; the dodge breaks it | `NAB` |
| the rob badge today | "NEW HERE 1m" for any shield, "ROBBED 54s" for your own per-victim cooldown, EMPTY, or the pig's value in gold; readable to 224 studs | `RobBadge` |
| shop drop today | 20% of clean shop cracks, flat, every shop; a duplicate pays its sell value | `SHOP_VAULT_DROP` |
| audits at boot | robbery 0, skin-steal 0, economy 0 problems | live |

Two derived figures used throughout, both **guesses until telemetry exists**:
a realistic robbing pace is a quarter of the ceiling (**~45 deliveries an
hour, ~15 a session**), and a casual child plays four twenty-minute sessions
a week while a keen one plays two hours a day. Every price and threshold below
is set against those and is re-solved the day there is a number.

## 3. Acorns are the spine

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

**AND THE MULTIPLIER IS WHAT HOLDS ACORN INCOME UP AS A SERVER FILLS, which
is the one product that has already broken this project twice.** The acorn
faucet is **one per plot per hour and nothing else** -- ten trees on a
ten-plot street, whether a player or a resident is standing under them -- so
a fixed faucet is shared by a growing number of thieves. Measured against the
resident floor (section 17): a solo thief working nine resident trees earns
about **10 an hour**; eight thieves sharing seven player trees and two
resident ones earn about **5.6 each**. Raising the PLAYER multiplier is what
closes that, because it only pays out where the extra thieves are: at x5 the
fall is 1.8x, and **x10 would make it flat.** It is at 5 because x10 means a
single shake catching two acorns banks twenty -- four crates -- which is a
currency inflating faster than it is countable. Recorded rather than solved:
it is the first number telemetry re-derives.

**RESIDENTS PAY ACORNS ON A SLOWER CLOCK THAN THEY PAY COINS.** The coin
cooldown stays at 60 seconds per target; **a resident's basket may be shaken
at most once per 15 minutes.** Growth binds harder than the cadence does in
the long run -- nine trees can only ever yield nine an hour -- so what the
cadence actually buys is the SESSION SHAPE: a thief arriving on a street of
full baskets takes the harvest in one lap and then has to wait, which is what
stops a solo player mining the resident row on a sixty-second loop and makes
a real player, who has no such cadence, the better target inside the hour.

**THE SPREE MULTIPLIES COINS AND NEVER ACORNS.** A spree that multiplied
acorns would put a hot thief at ten a shake -- two crates from one tree --
and every price below would be wrong by a factor of two for exactly the
players who play best.

## 4. The tree and the basket

Every plot has an **oak on the lawn** and a **basket at its foot**, and the
basket is where a player's acorns live. It is the readout, the trickle and
the stake at once.

**Where it stands.** The tree takes the front-left lawn corner -- the slot
`lawnI`, at plot-local (-25, 16) -- which mirrors the kennel at (25, 16), so
the two flank the gate walk and the lawn reads as a garden with a dog on one
side and a tree on the other. The slot comes out of `DECOR_SLOTS`, which
takes the lawn from nine ornament slots to eight; the scarcity argument for
the shelf says fewer is more curated, and a save with an ornament placed on
`lawnI` is pruned by the same catalogue-not-a-list rule every retired slot
already takes. The basket sits on the pig side of the trunk, at about
(-20, 16), in the ornament footprint so nothing else can ever stand in it.

**The tree is the street's own oak, smaller.** `Config.TREE_MESH` is already
generated, uploaded and textured; the yard oak is the same two parts at a
scale of about 0.85, so the canopy is roughly ten studs across. Measured
against the plot: canopy edge at x -30 against a side fence at -33.6, and at
z 21 against a front fence at 25.6, so it neither hangs over the alley nor
the pavement; and because it stands beside the pig rather than in front of
it, the sightline from the pavement over the front fence to the piggy is
untouched. No upload, no new art.

**Acorns fall.** The tree grows one acorn an hour, online and offline alike,
and it falls into the basket -- a client-side drop animation on the tick, so
a player looking at their own lawn sees the harvest arrive and a player
joining sees the night's acorns already in the basket. **The rate and the cap
are derived rather than typed:** `growCap` is 8 and `growSeconds` is
`OFFLINE_CAP_SECONDS / growCap`, which is 28,800 over 8, exactly 3,600. **A
full basket is one offline window** -- the same eight hours the pig already
fills over -- and a school day fills both.

**These two numbers are now the entire acorn supply of the game.** Nothing
else creates one. Ten trees on a ten-plot street at one an hour is a faucet of
**ten acorns an hour per server**, whatever anybody does, and everything below
-- the crate prices, the season tiers, the buy-back ladder -- is priced
against that figure and the shake's multiplier on top of it.

**Growth stops at the cap; robbing has no ceiling.** The pig's own rule --
income stops at capacity, a delivery overflows it -- applied to the second
currency, so there is one sentence covering both balances. A player holding
two hundred acorns grows none; a player holding three grows five overnight.

**The basket draws eight and reads PACKED above that.** The coin pile inside
the pig already works this way. A readout with a ceiling is a picture, and
the exact number lives on the HUD where a number belongs. What a thief reads
from the pavement is *full* or *not*, and the rob badge (section 9) prints
the count.

**Residents have trees, and they are now the whole non-player floor.** A
resident's basket is seeded at four and regrows at the same rate, so a quiet
server always has baskets to shake; the 15-minute cadence in section 3 is
about a resident's basket and nothing else. **Shops have no tree and pay no
acorns** -- a vault is a room inside a building and there is no lawn for one --
which is a real cost rather than a tidy-up: the four tills used to carry a
quarter of the non-player acorn floor, and the floor is nine resident trees at
a quiet server and two at a full one.

**Nothing bought with coins may touch the rate, the cap or the share.** The
garden catalogues may restyle the tree and the basket; they may never raise
the yield. A coin-bought bigger tree would be money buying a faster route to
every crate in the game.

**What this spends, because it is a rule the designer has refused once.**
*Displayed objects generating money per second, stolen off your base, is
Steal a Brainrot with pigs* -- and this is an object on a lawn that fills up
and that other people take from. Three things make it a different object: it
produces **no coins**, so it cannot compete with the income ladder or move a
number `auditRobbery` measures; **the tree is never taken**, only the harvest;
and the harvest is taken by a robbery with the same carry, the same nab and
the same dog as any other, so it adds no second way to farm a lawn. What it
buys is both of the brief's yard asks in one object: the yard has a job for
its owner (the Tuesday hook -- the basket is full) and a job for a thief (a
rich player is *visibly* worth crossing the road for).

## 5. Robbing the basket

Taking acorns is its own robbery and the ONLY way to take one. It is not a
side effect of cracking a pig, it is not a drop off a shop vault, and it is
not a number added to a delivery toast: a thief who wants acorns walks up to
somebody's tree, **shakes it**, catches what falls, and **carries the basket
home**.

**The shake.** A prompt on the trunk, SHAKE, on its own key, with a hold of
`CRACK.openHold` (half a second). Holding it opens the panel: the canopy
shivers and acorns tumble down the screen for `ACORNS.shakeSeconds` (4
seconds); the thief **drags each one into the basket icon** at the bottom
before it rolls off the edge. Every acorn caught is one taken, up to the take
below. It is drag rather than tap because most of this audience is on a
tablet, and it is a dexterity test rather than a timing one so it is not the
crack again with a different picture.

**How much falls.** A quarter of what the victim holds, rounded down, and
the victim may lose at most **four in a rolling hour whoever is robbing** --
half a basket, which is `LOSS_CAP`'s own shape and very nearly its own
fraction. A share rather than a flat number is what makes the rich the better
target: at eight held a thief may catch two, at a hundred and thirty-five they
may catch the capped four. Which of those actually land is the drag.

Note which of the two numbers binds, because it is not the obvious one. Over
an hour a tree only grows one acorn, so **growth binds long before the cap
does** and the cap is doing a different job entirely: it bounds the RAID on a
basket somebody filled overnight. A player who joins holding eight cannot be
stripped in the first ten minutes by a queue of thieves; they lose half a
basket an hour at worst, and they were asleep for the other half.

**The carry.** What is caught is a second carry kind: a basket welded to the
thief's back where the stolen pig would be, at `CARRY_SPEED_MULTIPLIER`,
nabbable, dodgeable, jammable, hideable, and confiscated by the patrol exactly
as a pig is. It is delivered at the thief's own basket.

**And it pays a MULTIPLE of what it holds, which reverses this section's own
first answer.** The draft said *it pays exactly what it holds, no doubling*,
on the grounds that minting on delivery would make a fat basket worth three
crates in one run and end the crack as a target. **That argument expired when
the crack stopped paying acorns.** It was a claim about two jobs competing for
one currency; they no longer share one. The crack pays coins and takes skins,
the shake pays acorns, and they are not substitutes -- so what is left is the
reason `HEIST_PAYOUT` exists at all, which applies here with more force than
it does to coins, because the acorn faucet is ten an hour for a whole street
and a currency that is only ever moved and never minted cannot pay eight
people. `ACORNS.payout` is **5 on a real player's tree and 1 on a resident's**
(section 3), so a shake that costs a child two acorns banks the thief ten, and
the two halves are tuned against different things: the victim's loss against
how much a day of growing is worth, the thief's gain against how many thieves
are standing on the street.

**The tree is the LOUD target.** A shake wakes a watching dog on the first
tick and tells the owner, the way a smash does; there is no quiet way to
shake a tree. So a plot now reads from the pavement as three jobs: the crack
(quiet, skilled, coins and maybe a skin), the smash (loud, fast, coins), and
the shake (loud, unskilled, acorns). The owner-interrupt range ends a shake
as it ends a crack; the per-thief per-victim cooldown is the same 60 seconds;
and a shake on a real player counts for the hot rule and the grudge exactly
as a crack does.

**The two jobs no longer have to be compared, and that is worth saying once,
because the draft spent a paragraph on it.** A crack and a shake pay different
currencies now, so neither can out-earn the other and there is no ratio to
protect: a thief who wants coins cracks, a thief who wants a crate shakes, and
a thief who wants both does both to the same plot. What replaced that check is
a harder one -- **acorns per hour against the crate prices**, since the shake
is now the only thing being checked against them. `auditAcorns` (section 17)
holds that end.

**What the owner does about it.** Spend them. A basket that is sitting at
forty is a basket somebody will shake, and a crate is five. That is the
spend-it-or-lose-it loop the pig already runs on, arriving on the second
currency with the same answer.

## 6. Crates, and the Rebirth Crate

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

**Rebirth opens a Legendary Crate, and the rebirth-only skins retire with the
drop that handed them out.** Today `ProgressionService` calls
`CosmeticsService.rollRebirthDrop`, rolls a rarity and equips one skin, with a
coins fallback when the pool is empty; and three skins -- **Bronze (rebirth
1), Gold Leaf (3) and Diamond (6)** -- carry an `unlockRebirths` gate instead
of a price, so they are owned by arithmetic rather than by anything in the
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
   spinning. Nothing is random, so nothing is exposed. **Recommended**, and
   it is the better reward anyway -- a real Legendary Crate draws `rare 65 /
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
| acorns in the basket | **yes, capped** | section 5 -- a quarter a shake, four per victim per hour |
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

**The hot rule is the free route back.** A stolen skin is *hot* for
`REVENGE.window`. A revenge crack on the thief takes it back at 100%
**whatever they are wearing** -- today the roll takes what the victim wears,
so a thief could hide it by changing skin, which is the loophole this closes
-- and a recovered skin comes *off* the thief. Two outcomes a nine-year-old
can hold: **get them back now and take it off them, or rob somebody else and
buy it back.**

**The buy-back ladder, and why 3x per step is the right shape.** Losing a
skin writes `data.claims[key]`; for the rest of the season that skin's crate
card carries BUY BACK, a direct purchase in acorns with no roll, and the thief
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
all shipped. New: the objective card that carries *go and rob a piggy bank*
for a new player carries **GET IT BACK -- JAMIE, 10:00** with the countdown,
and flips to **BUY IT BACK -- 135 ACORNS** when the window closes.

## 8. The nab is a hand-off

Today a nab is a one-second tug that drains coins back to the victim per tick
and pays the nabber a minted quarter. **It becomes a confiscation: the nabber
takes the pig, and is now the one carrying it.** The tug keeps everything
that made it safe -- the hold, the dodge that breaks it, the crowd that
joins without speeding it up, the rest stamped on the thief -- and changes
only its ending.

**The three exits, on the new carrier's own prompt card:**

| the nabber... | delivers where | gets | the victim gets |
|---|---|---|---|
| **keeps it** | their own pig | half the coins' worth at home, half the acorns rounded down, and **the whole haul** -- a stolen skin goes with the pig | nothing more than they had already lost |
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
confiscation with its own scene. The bounty is still minted and still split
across everybody who held. And the staged-robbery arithmetic still refuses
the farm: a pair who rob, nab and keep give up the claimant's full 2.0x to
collect 0.5x, so the honest play is still to deliver.

**What is traded away, stated plainly.** The tug's per-tick partial outcome
-- *the thief got home with less* -- is gone. Its replacement is a different
partial outcome: *the thief got it back*, or *a stranger ran off with it*.
That is a better story and a worse guarantee, and the two-player session is
what decides whether it reads.

## 9. Timers visible from the street

The rob badge over every pig already says most of this, per viewer, to 224
studs: **NEW HERE 1m** for a shield, **ROBBED 54s** for the reader's own
per-victim cooldown, **EMPTY**, or the pig's worth in gold. What is missing,
and what each costs:

* **A rejoin shield is not "new here".** The same attribute carries both
  shields and the badge cannot tell them apart. It can: `NeedsFirstJob` is
  already published on the player and is true exactly for somebody who has
  never delivered a robbery. NEW HERE when that is set; **SHIELD 45s**
  otherwise. Zero new state.
* **The hourly loss cap is invisible.** A victim who has been robbed to
  `LOSS_CAP` is un-robbable for the rest of the window and nothing on the
  street says so; the crack refuses out loud only once you are standing at
  the pig. The server publishes `CappedUntil` on the plot when the allowance
  runs out; the badge reads **CAPPED 41m**. The badge's own rule stands --
  it is kept in the same order as `whyCannotSteal` asks its questions, so
  the new row goes where the refusal goes.
* **The basket needs a row.** Under the coin figure, an acorn glyph and the
  count, or SHAKEN 54s while the reader's own tree cooldown runs, or the
  same CAPPED when the acorn cap has bound. It is the same card, one row
  taller, and it is what lets a thief compare two lawns from the road.
* **A hot skin gets a mark** on the badge, so the whole street can see who is
  holding stolen goods and the owner can see where theirs went.

Every one of those is a property read on the client; the only new server
write is the capped-until stamp. And the check for all of it is a photograph
from the pavement, not a probe: the badge is not `AlwaysOnTop`, so it is one
of the few labels in this game that a capture can actually see.

## 10. Shop drops are smaller, and the wheels shop is gated

Today every clean shop crack rolls a 20% drop from that shop's own shelf.
Three changes, and the first is a deletion.

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
getaway, the tree's rate, the basket's cap or the shake's share. The yard
already has this written down -- *a cosmetic may never imply a tier that has
not been bought* -- and the expansion is where it gets tested, because a fence
STYLE and a fence TIER are one object wearing two meanings.

### 14.2 The shape of the expansion: sideways, never upward

`auditEconomy` refuses any price above `getCapacity(ABSOLUTE_MAX_LEVEL)`,
which is **96.9M**, and the Sky Castle at 80M is already 83% of the largest
pig this game can produce. **So there is no room above the catalogue, only
beside it.** Every figure below is breadth: more things at prices that already
exist, not a tier above the top.

| shelf | today | add | added value | reuses |
|---|---|---|---|---|
| **effects** | 7 authored, **0 obtainable** | put the buy button back, and author an epic (~1.5M) and a legendary (~12M) so the band is complete | **~15M** | the effect system, `makeEffectIcon`, `Config.EFFECTS` |
| **house interiors** | none -- a house is a facade | 8 interior styles, priced per tier band | **~90M** | `LowPoly`, and the room `ShopFront` already builds |
| **the yard** | 11 garden items | tree and basket styles, **fence styles** (the panel, never the height or the hazard), driveway surfaces, mailboxes, gate and plot-sign styles -- about 28 items | **~45M** | `Decor`, `Config.fenceMesh`, the driveway builder |
| **the dog** | 15 coats, kennels and toys | 12 more, and a second animal | **~35M** | `GuardDog.applyTier`, the wardrobe/kennel split |
| **rides** | 6 | 4 more, plus trails and accents that change no speed | **~25M** | `RideModel`, `RidePose`, `RideSound` |
| **ornaments** | 23 | 15 on the candy-garden direction already set | **~25M** | `Decor.buildOne` |

That is **+235M against 218.6M**, so the shelf roughly doubles to **~455M**,
and houses fall from 65% of it to 31% -- which is the number that actually
matters, because a catalogue that is two thirds one category is a catalogue
with one decision in it.

**House interiors are the biggest single item on that list and the one to
build first**, for a reason that is not the money: the shops acquired an
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
* **Order is compliance-critical, and section 14 is now part of it:** crates
  to acorns, the Rebirth Crate guaranteed, the boot audit, *and enough coin
  shelf to be worth buying* -- all before the pack's product id is set. The
  first three are what keep it legal; the fourth is what keeps it from being
  a refund queue.
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

The invariant: **no random outcome is priced in coins or gated behind
coins.**

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
| **the Rebirth Crate** | a rebirth, gated by banked coins | **only if guaranteed** (section 6); rolled, plus a pack, it is a paid random item |
| season tier rewards | acorns this season | no |
| the tree's growth | a flat rate, capped at eight | not applicable |
| daily boosts | attendance; accelerate coins only | coins reach nothing random, so a boost reaches nothing random |

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
resident acorn cadence (3); the basket's share and hourly loss cap (5 -- the
growth rate and the cap on the BASKET are derived from `OFFLINE_CAP_SECONDS`,
these two are judgement); the four crate prices (6); the ten tier thresholds
(12); the buy-back ladder (7, derived from the real pool odds); the nabber's
keep share (8); the rank thresholds and the per-shop drop chances (10); the
six added coin shelves (14); and the pack's size (15, equal to capacity by
construction).

**Product one -- the acorn faucet against the number of people drinking from
it. This is the sharpest product in the plan and it is the one that has broken
this project twice already.** The faucet is fixed by construction:

    acorns minted / hour  =  trees x (3600 / growSeconds)  =  10 x 1  =  10
    acorns banked / hour  =  sum over trees of (growth x that tree's multiplier)

Ten trees on a ten-plot street, whoever is standing under them. The multiplier
is the only thing that responds to population, because it only pays out where
the extra people are:

| population | trees available to one thief | banked / hour, whole server | per thief | vs solo |
|---|---|---|---|---|
| 1 player, 9 residents | 9 resident + own | 9 x1 + 1 = **10** | 10.0 | -- |
| 4 players, 6 residents | 3 player + 6 resident + own | 3 x5 + 6 x1 + 4 = **25** | 6.3 | 1.6x down |
| 8 players, 2 residents | 7 player + 2 resident + own | 7 x5 + 2 x1 + 8 = **45** | 5.6 | **1.8x down** |

**A 1.8x fall as a server fills, against a coin economy that this project
fought for months to get flat.** It is recorded rather than hidden, and the
lever is named: **x10 on a player's tree makes the curve flat** (7 x 10 + 2 +
8 = 80, 10.0 each). It ships at x5 because x10 means one shake catching two
acorns banks twenty, which is four crates from one tree and a currency
inflating faster than a nine-year-old can count it. **The other lever is the
one this plan will not pull**: raising `growCap` raises the faucet for
everybody including the player who never robs anybody, which is the brief's
own rule broken -- *robbing must pay what coins cannot buy*. `auditAcorns`
asserts the full-server figure is at least half the solo one and warns with
both numbers, so the day the fall gets worse it is in the boot log rather than
in a review.

**Product two -- robbing against growing.** A player who never robs anybody
grows eight a day and loses some of it, netting about six: **a common crate a
day, and a legendary crate a week.** A player who works the street for two
hours banks about 19 a day at a full server and 28 solo, on top of the same
harvest. The ratio is **3.4x to 4.5x**, which clears the 3.0 floor this
project holds the coin economy to and clears it by less than the coin economy
does. `auditAcorns` asserts it at both ends.

**Product three -- the tree's growth against what a thief may take.** A full
basket is eight and the hourly loss cap is four, so **the worst hour anybody
can have costs them half a basket** -- and they were asleep for the eight
hours that filled it. The invariant is unchanged and is the one that stops the
basket reading as broken: `growCap` must exceed the expected daily loss at the
shipped share and cap, or a passive player holds nothing ever, which is an
empty basket that never fills and is indistinguishable from the tree not
working.

**Product four -- the crate prices against the faucet.** Five acorns is a
common crate; forty is a legendary. At 5.6 an hour on a full server that is a
common crate every 54 minutes and a legendary every seven hours, and the whole
40-skin og pool is a long autumn. **That is the number to look at first in a
real playtest**, because it is the one this plan is least confident about:
every acorn figure above rests on the tree growing exactly one an hour, which
was derived from `OFFLINE_CAP_SECONDS` back when the tree was a supplement and
has never been re-derived now that it is the whole supply. If crates read as
unreachable, the order to try the levers in is **the multiplier, then the
crate prices, then `growCap` last** -- because the first two pay robbers and
the third pays everybody.

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
| the guard dog | 3 breeds off one 24-part list, four tone slots, four shape numbers | CODE | **moving to `EXT` by decision -- see 18.5** |
| residents and shopkeepers | one code-built figure, per-server skin bag | CODE | fine; they inherit whatever the pig gets |
| the patrol car and officer | code-built originals, posed on the server | CODE | fine |
| rides | 6, each sized to the rider by measured contacts | CODE | section 14 wants 4 more |
| consumable props | 11 across `BoneModel`, `GadgetModel`, `HomeModel`, `ThiefModel` | CODE | **3 gadgets only**, and no throw or use animation for any of them |
| lawn ornaments | 23 | CODE | section 14 wants 15 more |
| **the acorn** | **source art DONE** -- `assets/acorn/acorn.glb`, 3,138 triangles, one material | EXT | not uploaded, and **unsegmented**: one mesh, one primitive, one `Color`, so the nut and the cap live in a baked map and can never be recoloured. Fine while the acorn's colour is a constant (the tree's argument); a re-split the day an acorn hue lands in `Theme`. Its 21.4 MB is ALL texture, including a metallic-roughness map a flat-shaded street does not use. **The ICON is a separate asset -- see below** |
| **the oak and the basket** | neither exists | GEN + CODE | the oak reuses `TREE_MESH` at 0.85 and needs no upload; **the basket is new** and is the object a whole currency is read off. **[DESIGN]** |
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
| **the shake minigame** | does not exist | **[DESIGN]** -- section 5 |
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
| 56 | **Basket readout** | *does not exist* | draws up to 8 and PACKED above. **[DESIGN]**, Art 7 |

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

# PART II -- THE EXECUTION PLAN

Ordered. Nothing in a later phase starts before the earlier one is verified.
Each step names what it touches; *done when* is the check. Files are named
where the reader has to go there.

**The art track runs beside all of it**, not after it, and six of its steps
block a phase step -- the table under Art 1 says which. Two of them block
early: there is no shake without a shake panel, and no basket without a
basket.

## Phase 0 -- Gates (hours, not days, and two of them cost something today)

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
"legendarycrate")` -- guaranteed form: the pool is the legendaries the player
does not own, in `order`, and the reel lands on the first. Retire
`rollRebirthDrop`, `getDropWeights`, `LEGENDARY_PITY` and `DROP_RARITIES`; the
coins fallback becomes forty acorns. *Done when* a rebirth on a fresh save
opens the crate and hands over a legendary, and a rebirth on a save owning
every legendary pays forty acorns.

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
`revengeChance` retires. `rollSkinSteal` on a revenge crack takes the hot
skin from the thief's `owned` regardless of what they wear, and revokes it.
The hot set is the `grudge` table's victim entry extended with the skin key.
*Done when* a revenge crack on a thief wearing a different skin still
returns the stolen one and removes it from them.

1.7 **The buy-back ladder.** `data.claims[key] = seasonIndex` written in
`rollSkinSteal`; `Config.BUYBACK = { perStep = 3 }`; the crate card shows
BUY BACK at `crate.cost * 3^rank` for any claimed skin, a direct grant through
`SetService.grant` charged in acorns, cleared when the season rolls. *Done
when* a claimed common buys back at 15, a rare at 45, a legendary at 135, and
the button is absent for an unclaimed skin.

1.8 **The objective card.** The first-job card gains a second reason to
show: a live claim inside the revenge window prints GET IT BACK with the
countdown, then BUY IT BACK with the price. *Done when* the card is on screen
within a second of a theft and flips at the window's end.

1.9 **`auditAcorns` and the sweep audit** (sections 16 and 17), warned at
boot beside the other four. *Done when* the boot log is clean and each check
is provoked once to prove it fires.

1.10 **Save.** `data.claims` (new top-level table, generic reconcile) and
`data.robberies` (new counter). Schema 25. Both land before any UI reads
them.

## Phase 2 -- The tree, the basket and the shake

2.1 **The tree and the basket. [DESIGN -- Art 7]** `Config.ACORNS = { growCap = 8, growSeconds
= OFFLINE_CAP_SECONDS / 8, share = 0.25, lossCap = 4, lossWindow = 3600,
shakeSeconds = 4, treeScale = 0.85, slot = "lawnI", payout = { resident = 1,
player = 5 } }`. `PlotService.buildPlot`
builds the oak from `Config.treeMesh()` at the slot and a code-built basket
beside it; `lawnI` comes out of `DECOR_SLOTS` and `reconcile` prunes any
`placed` entry on it. *Done when* every plot boots with a tree and a basket,
the canopy clears both fences by the numbers in section 4, and a save with
an ornament on `lawnI` boots with that ornament shelved.

2.2 **Growth.** `data.acornsGrownAt` (a timestamp); `EconomyService`'s
accrual tick adds one per `growSeconds` while `loot < growCap`, offline
included through the same path offline coins take. The basket publishes
`Config.PLOT_ACORNS_ATTRIBUTE` and the client draws up to eight and PACKED
above. *Done when* a save left eight hours joins with eight, a save at
twenty grows none, and the drop animation plays on a live tick.

2.3 **The shake, which is now the only way an acorn changes hands. [DESIGN --
Art 4, and this one blocks: there is no shake without its panel.]** A prompt
on the trunk, kind `shake`, on its own key, hold `CRACK.openHold`;
`HeistService.shake` opens an attempt bound to the lawn like a crack, wakes the
dog and notifies the owner on open, computes the take (share, `lossCap`,
`lossWindow` -- keyed per VICTIM like `losses`, never per thief), and fires
`ShakeState` with the count. `Shared/Shake.luau` renders the fall and the drag;
`ShakeCatch` reports each catch and the server accepts up to the take. The
owner-interrupt poll ends it. *Done when* a shake on a resident holding eight
offers two, the drag lands them, a second shake inside 60s is refused, and a
victim who has already lost four this hour offers nothing with the reason named
rather than an empty minigame.

2.3a **The multiplier is applied at DELIVERY, not at the catch.** What the
thief carries is what the victim lost; `Config.acornMultiplier` is read when
the basket is delivered, so the carry label reads *3 acorns, worth 15 at home*
-- the crack's own sentence arriving on the second currency -- and a basket
confiscated or nabbed pays whoever ends up delivering it on the same rule.
Applied at the catch instead, the victim's loss and the thief's carry would
disagree on a label both of them can see. *Done when* a three-acorn catch off
a player delivers 15, the same catch off a resident delivers 3, and the
victim's basket falls by exactly 3 in both cases.

2.4 **The basket carry.** `Carry.kind = "pig" | "basket"`; `attachLoot`
builds a basket model for the second kind; the delivery poll accepts a
basket at the thief's own tree and credits exactly what it holds; every
reader of `carrying` -- the nab, the dodge, the jam, the bins, `confiscate`,
the carry label -- is walked and made kind-agnostic. *Done when* a basket
run delivers its count, a nab on a basket carrier works, and the patrol
confiscates one.

2.5 **Residents' baskets, which are the whole non-player floor now.**
`ResidentService.seat` seeds four and the tick regrows them at `growSeconds`;
the 15-minute cadence of 1.3 gates the shake. Shops are explicitly given no
tree -- `PlotService` skips the slot on any plot carrying a `shop` -- which is
the one line standing between this plan and a fifth acorn source nobody
designed. *Done when* a solo player can shake nine resident trees, a shop
offers no shake prompt at all, and `auditAcorns` reports the solo and
full-server figures of section 17 within a tenth of an acorn an hour.

## Phase 3 -- The hand-off, and the timers on the street

3.1 **The carry's claimant.** `Carry.claimant` written at the grab;
`Carry.holder` is the character it is welded to. *Done when* the two fields
exist and every delivery reads both.

3.2 **The tug ends in a transfer.** `endTug(thief, "emptied")` calls
`handOff(thief, catchWinner(tug))`: detach the loot from the loser, attach
it to the winner, keep `claimant`, stamp `nabRest` on the new holder, and
retire `tugTick`'s per-tick `giveBack`. The dog and the patrol paths are
untouched. *Done when* a completed tug moves the pig to the nabber with the
haul intact and the old thief is empty-handed and unstunned.

3.3 **The three exits.** The carrier's own prompt card names both drop-offs;
delivery at the victim's plot is `returnCarry` (victim refunded through the
existing `refund`, bounty minted to the deliverer); delivery at the holder's
own pig pays by claimant test -- full for the claimant, `NAB.keepShare` (0.5)
of coins and acorns otherwise, the haul whole. The grudge and revenge marker
re-point to a non-claimant deliverer. *Done when* each exit is driven with
two players and the toasts name what happened at both ends.

3.4 **The badge rows. [DESIGN -- Art 5, and this one blocks: four states in
text is a paragraph over a pig.]** `RobBadge` reads `NeedsFirstJob` to choose NEW HERE
against SHIELD; `HeistService.lossAllowance` publishes `CappedUntil` on the
plot when it hits zero and the badge prints CAPPED; a second row prints the
basket count, SHAKEN while the reader's tree cooldown runs, and the hot
mark. *Done when* a photograph from the pavement -- the badge is not
`AlwaysOnTop`, so a capture can see it -- shows all four states legibly at
the plot spacing.

## Phase 4 -- Shop drops, and the pack

4.1 **The rank.** `data.robberies` incremented in `deliver`;
`Config.RAP_SHEET_RANK = { 0, 25, 100, 400, 1600 }`; a star row on the plot
sign. *Done when* a save at 99 shows one star and at 100 shows two.

4.2 **The drop table.** `SHOP_VAULT_DROP.chance` becomes per-shop with the
`minRank` on `gear`; `rollShopDrop` refuses below the rank silently;
`auditSkinSteal` compares against the largest chance. *Done when* a rank-1
thief never draws a ride across two hundred simulated rolls and a rank-2 one
draws at about three per cent.

4.3 **The coin shelf, before the pack. [DESIGN -- Art 11, per shelf]**
Section 14, in its own order:
effects get their buy button back and the two missing tiers authored -- the
smallest job on the list and it closes a live gap, since seven authored
effects are obtainable by no route at all today; then the yard styles, which
are `Decor` rows and `fenceMesh` rows; then interiors, which are the long one.
`auditEconomy` runs after every batch, because every price is measured against
`getCapacity(ABSOLUTE_MAX_LEVEL)` and there is only 16.9M of headroom above the
Sky Castle. *Done when* the summed spendable coin catalogue clears 400M, the
new boot check finds no item carrying both a `cost` and a `chest` tag, and all
seven effects are buyable.

4.4 **The pack -- only after Phases 1 and 2 are live, and after 4.3.** A developer product
whose receipt writes `data.parcel = "pigfill"`; `PlotService.setCrate` draws
it on the doorstep box; opening it at the pig adds `capacity - coins` and
clears the field; refused with the reason if the pig is already full. The
card carries the sentence in section 15, and the shelf it buys is 4.3's.
*Done when* a bought parcel is on
the doorstep across a rejoin, opens to a full pig, and a second purchase
while one is unopened is refused before charging.

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

## Phase 6 -- Events as structure

**[DESIGN -- Art 8 for the reward reveal and the two new `EVENT_UI` rows.]**

6.1 The weekly scheduled raid and the countdown chip's six-day mode; it pays
a free crate open through `ChestService.grantFree`. 6.2 The Cash Van:
`TrafficService` parks the van as an event target carrying a pig built by
`PiggyBank.buildVault` on the van's own plot record -- no owner, no cap,
double COINS. 6.3 Harvest Saturday: one flag doubling `growSeconds` for the
day. *Done when* a van event runs on a one-player server end to end, and
`auditAcorns` confirms no event path credits an acorn.

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
cap as a red line -- and has never been designed. The shake does not exist at
all: acorns falling down a panel for four seconds, dragged into a basket, on a
tablet. *Ask for:* a layout sketch for each, and specifically **how a falling
acorn reads as catchable on a phone held sideways**, which is the only
genuinely new interaction in this plan. *Done when* both are driven end to end
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

**Art 7 -- the acorn, the oak and the basket. [DESIGN]** **The acorn's 3D
source is done** -- `assets/acorn/acorn.glb`, remeshed to 3,138 triangles
against the 10,000 ceiling, on 2026-09-15. What is left on it is a job with no
design in it (strip the PBR maps, resize the base colour, upload, put the id in
`Config`) and ONE open design question: it came back unsegmented, so it gets a
single `Color` and its two tones are baked. That is the right answer if the
acorn's colour is a constant, and the wrong one the moment `Theme` carries an
acorn hue -- decide which before uploading, because splitting it afterwards
re-does the upload. **The ICON is a separate asset and is NOT this mesh
shrunk**: see 18.3's interface table.

The oak is `TREE_MESH` at 0.85 and costs no upload. **The basket is new**, and it is the object an entire
currency is read off from the pavement: it draws up to eight and reads PACKED
above that, and a thief decides whether to cross the road by looking at it.
*Ask for:* what the basket looks like full and empty. *Done when* the canopy
clears both fences by section 4's numbers, the sightline from the pavement to
the pig is unchanged, and full and empty are told apart at the kerb.

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

* **Effects** -- the buy button back, and an epic and a legendary authored so
  the price band is complete. Smallest job on the list, and it closes the
  live gap where seven authored effects are obtainable by no route at all.
* **Shop interiors. [DESIGN]** The four units got four silhouettes on the
  outside and kept one room shape on the inside -- the exact complaint that
  was fixed on the frontages, unfixed one wall behind them. Everything
  needed is already built once: `Config.shopRoomHolds`, the plinth-is-a-ring
  lesson, and the light-masonry/dark-joinery split that ended a four-suspect
  chase through a white window.
* **Houses. [DESIGN]** Breadth at existing prices, never a tier above the
  top: the Sky Castle is 80M against a hard ceiling of 96.9M, and
  `auditEconomy` refuses anything above it. Interiors are the bigger item and
  the one to build first.
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
