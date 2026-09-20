# The piggy collection — plan

**Status: draft for approval. Nothing here is built.** Written 2026-09-20.

This replaces the passive income drip and the acorn track with one object that
does four jobs at once. It is the largest change to this design since the
September robbing pivot, and it is a CONSOLIDATION rather than an addition:
when it lands the game has fewer systems than it has today, not more.

---

## 1. The decision, in one paragraph

**A skin stops being a costume and becomes a piggy bank you own, place and can
lose.** Every piggy you own earns coins per second, all the time, from the
moment you get it — there is no shelf, no bag, no state where owning something
does not pay. It stands on your lawn by default, where anybody can carry it
off; a house gives you a limited number of indoor shelves where the same
piggy earns the same rate but cannot be touched. Coins still collect in the
big pig on your plot and are still robbed exactly as they are now.

Said the way a nine-year-old would say it:

> Collect piggies. They all make money, all the time. Everyone can steal the
> ones on your lawn — unless you've got room for them inside.

---

## 2. Why this and not another system

The comparison game (*Hide a Base and Steal*) is not simple because it has few
features. It is simple because **one object is the collection, the income, the
loot and the progress bar at the same time.** You look at somebody's base and
you know how they are doing without reading anything.

Count what this game has today: coins are income, skins are the collection,
crates are the source, loot is a second currency, acorns are a third, the house
is prestige, the pig is the wallet. **Seven objects, seven jobs, not one of them
doing more than one.** That is the reason the game is hard to hold in your head,
and no amount of added content fixes it.

After this change, one object — a piggy — is:

| job | how |
| --- | --- |
| the collection | you own them, there are ~44, duplicates stack |
| the income | each one earns per second while slotted |
| the loot | a lawn piggy can be picked up and carried off |
| the progress bar | your plot and your rooms ARE the readout |

---

## 3. Where a piggy can be — four placements

This answers "what skin should the pig on each player's plot be".

**THE TILL — one, safe, big, 12 studs, on the lawn where it is today.**
The big pig does not go anywhere and is not a collectible. It is the bank:
coins produced by the collection drip into it, it fills to capacity, it stops
earning when full, and it is what a coin robbery cracks. Every behaviour it has
now survives untouched — the coin pile, the vault dial, the lock tiers, the
plaster, the rob badge, the steal prompt, the crack minigame.

**What it LOOKS like is a slot.** The till wears whichever piggy you have chosen
to display on it, drawn from ones you own, and that piggy earns like any other.
So it is your shopfront: the first thing a thief sees from the pavement, and a
statement about what you have. A player who owns nothing else gets **Classic
Pink**, which is free and everybody has it. If the displayed piggy ever leaves
your collection the till falls back to Classic.

This is the answer to the question: **not a fixed default — the default until
you own something you would rather show.**

**LAWN — every piggy you own, all of them, all the time.** There is no cap
here and no bag behind it. `Config.DECOR_ITEMS` is empty — the lawn ornament
catalogue was retired and left a placement grid, an auto-slot, a put-away
toggle, a rebuild-on-plot path and a save field standing with nothing in them
— and a piggy moves straight onto it the moment you own it. The grid grows
(more rows, tighter spacing) as the collection grows rather than ever
refusing a new arrival; the only real ceiling is a part-count number far
beyond anything a player will reach, and it is a rendering concern, never a
design lever. This is the default state of everything you own, and it is
what anybody can walk up and take.

**INDOOR SHELVES — N, set by your house tier, earning the same rate.** The
authored house templates already carry `Featured`, `Shelf_1..N` and `Wall`
mounts, and `TrophyRoom` currently draws only the wall. **The shelves exist
in the art and render nothing.** Moving a piggy onto one does not change what
it earns — indoor and outdoor pay identically — it changes whether it can be
stolen at all without the fence, the lock and the mobility gadgets in §5a
all being beaten first. The number of shelves is the reason to buy a bigger
house: not more income, more of your collection out of reach.

**THE EAR SHELVES — two, safe, top-tier house only.** The 1B house grows two
display plinths beside the ears, visible from the street and unreachable. Pure
flex, and the reward for finishing the ladder.

---

## 4. Income

**`BASE_INCOME` survives with a new meaning: it is what one Classic piggy
earns.** Everything else is a multiple of it, which means the constant every
audit in the game is calibrated against keeps its value and its name.

**Every player starts with one Classic piggy, already on the till.** Without it
a new save earns zero, and the first minute of the game is the one minute that
may not be broken.

**Rate by tier, multiplied by the income tree and the rebirth bonus.** Shape,
not derived values — these need solving against `auditRobbery` before anything
is typed:

| tier | earns | why |
| --- | ---: | --- |
| common | 1× | the floor, and what the starter piggy pays |
| rare | ~4× | |
| legendary | ~15× | one of these should feel like a windfall |

**Duplicates stack and each one earns.** Three Pearls in three slots pay three
times. This is what makes a repeat pull from a crate exciting rather than a
consolation, and it is why `spares` stops being a sell-it-back pity system and
becomes the thing you were hoping for.

**EVERY PIGGY YOU OWN IS ALWAYS PLACED AND ALWAYS EARNING.** There is no
unslotted state, no bag, no shed. A piggy comes out of a crate standing on
your lawn, earning from that second — this is the rule the plan opened with,
stated here as flatly as the one it replaces, because it is just as
load-bearing: nothing this design ever hands a player is allowed to sit there
doing nothing. The pressure to buy a bigger house is not "find room or lose
income" — every piggy already pays regardless of where it stands — it is
"find room or leave your best pieces exposed."

**The income tree becomes a multiplier on the collection.** "Earn Faster" now
raises what every piggy pays instead of raising a drip. Capacity is untouched —
the till still holds what it holds, still stops accepting when full, and "spend
it or lose it" runs exactly as it does today.

---

## 4a. Collection is active — a piggy earns into itself, not into the till

**Nothing drips into the till directly any more. Every slot fills itself, on
its own small clock, and you walk to it.**

Each slotted piggy accrues coins into a buffer of its own, at that piggy's
rate, exactly the way the till already fills and caps today — this is the
till's own fill/cap/refuse logic, run once per slot instead of once per plot.
The buffer caps at `rate × Config.PIGGY_BUFFER_SECONDS` (target: 90–120
seconds of that piggy's own rate, so a full lap of the plot happens roughly
every one to two minutes — needs the same sim treatment as `RESIDENTS.pigSeconds`
before it is typed as a real number), and a `collect` prompt
(`Config.PROMPTS.collect` — "BANK COINS", gold — currently unused since the
vault-into-coins pivot retired the old bank action) deposits the buffer into
the till.

**Walking the collect route is the loop this section exists to add.** A player
with a big collection is walking between the till, a lawn full of pedestals
and whatever shelves their house has, banking as they go — the "physical,
walk over buttons" feel the comparison games have and this game currently
does not.

**A full till refuses a collect exactly like it refuses a sale today.** "Your
piggy bank is full. Spend some coins before you collect." No new refusal
shape — reuse the existing one, word for word.

**This only runs while the owner is present.** Offline accrual is untouched:
it stays the separate formula that computes total household rate × capped
offline hours and credits coins directly on return, exactly as it does today.
If the per-piggy buffer ran while offline too, its 90–120 second cap would
gut offline accrual to almost nothing regardless of time away — so the two
paths stay split: present is the active loop, away is the existing idle
formula.

**A piggy carried off a lawn takes its buffer with it as zero, not as a
bonus.** A robbed piggy's own accrued coins were never the thief's target —
the object is — so a snatched piggy resets to an empty buffer on its new
owner's lawn rather than handing over a windfall.

---

## 5. Stealing a piggy

**The verb is a hold, not a crack.** Walk onto a lawn, hold the prompt on a
pedestal, and the piggy comes off it and into your arms. The crack minigame
stays on the till and is unchanged, so the two robberies stay distinct: crack
the bank for money, snatch a pedestal for an object.

**Carrying is already built.** `attachLoot` welds a miniature to the thief's
chest, `CarryPose` holds it in two hands, the carry speed penalty applies and a
highlight shows through walls. The mini piggy geometry is `PiggyModel` and is
already skinned by key — it is the display object, finished.

**A stolen piggy has to be slotted to earn, so it goes on the thief's lawn.**
That is the whole recovery mechanic and it costs nothing to build: the piggy
that was taken from you is now standing in the open on the plot of the person
who took it, and the verb to get it back is the verb they used. Revenge already
exists and already pays triple inside its window.

**Stealing has no capacity cost, because there is no capacity to spend.** A
thief's own lawn is exactly as unlimited as anyone's, so a stolen piggy just
joins the pile, earning immediately. What already stops a street from being
hoovered up is the same thing that stops it in the coin economy today: the
per-victim `STEAL_COOLDOWN`, the run home, and the defences below — friction
on the ACTION, never a shelf running out.

**The fence, the dog, the lock and the patrol all defend the lawn as they do
now,** and for the first time they are defending something a player can point
at. This closes the hole where the entire defence half of the shop has no
positive outcome.

**Reaching an INDOOR piggy is a harder version of the same robbery, not a
different one.** See §5a — it needs the yard crossed, and then either a
locked door cracked or a mobility gadget to skip it, but it is never
impossible. That is the same "defence buys time, never immunity" rule the
fence ladder has followed since it was first written down, applied one level
up.

---

## 5a. Reaching indoor piggies — new gadgets, new fence tiers

**Indoor shelves needed a reason to exist beyond "safe," and the reason is
that nothing behind a fence may ever actually be unreachable.** `CLAUDE.md`
states this as a rule the fence ladder has followed since it shipped —
*"a fence must never be uncrossable... defence buys time, never immunity"*
— and a house interior no gadget could ever open would be the first
exception to it in the whole game. So an indoor piggy is defended by three
things stacked on top of each other, and a thief who has invested in all
three can reach it.

**Two new fence tiers above Moat, because the current top is not tall enough
to justify a mobility gadget on its own.** `Brick Wall` (tier 6) and
`Golden Gate Fence` (tier 7) extend the existing ladder the same way
Electric and Moat did — taller, and escalating the HAZARD of climbing rather
than only the height, per the ladder's own rule. The gate stays open at
every tier, as it always has; what these two buy a defender is that the side
and back routes stop being a jump or even a climb, and start needing real
mobility.

**Three new offense items, cheapest to most capable — the same "cheap
counters bounce, the expensive one gets through" shape the bones and
gadgets already use:**

* **Spring Boots — a worn item with a duration**, the same shape as an
  existing buff: for a fixed window it grants a much higher jump, enough to
  clear the new fence tiers and reach a house's lower windows or a balcony.
  Cheapest, simplest, no aiming — the "I just want to get up there" option,
  which is what makes it the right one for this audience to reach for first.
* **Grapple Gun — a targeted single pull**, closer in shape to the plunger
  and the zapper than to a worn item: aim, fire, and it hauls the thief to
  the point it lands on. Costs coins per use like the other gadgets, and its
  range should be shorter than a jetpack's the same way a gadget's range
  already shrinks as its power rises — precise, but you have to be close
  enough to land it.
* **Jetpack — sustained flight**, the top of this ladder: it clears any
  fence height and is the only one of the three that can reach an upper
  floor a house's exterior only shows as architecture (see §6a). Priced and
  positioned the way the Golden Bone and maxed Speed Boots are — a real
  investment that answers a real wall, not a toy.

**A house's front door carries its own lock, the same vocabulary the vault
dial already speaks.** Reaching it via the yard and picking it is one route
in; reaching an upper window with a mobility gadget and skipping the lock
entirely is the other. Both need the fence beaten first — a mobility gadget
gets a thief onto the property faster and higher, never through a wall.

**None of this needs a new number solved today.** The heights, the lock
tiers and the gadget prices all want the same `auditFences`/`auditRobbery`
treatment every other defence number in this game gets before it ships — the
shape above is what to build against, not the final constants.

---

## 6. Indoor shelves and the house ladder

**The catalogue has grown since this section was first drafted: eighteen
tiers exist in `Config.HOUSE_TIERS` today, not nine** — shack through
goldenpig, the last one earned rather than bought. The rule below is
unchanged; only the row count is bigger, and every number this section
carries below is illustrative rather than final until generated against the
real eighteen.

**The rule is strictly monotonic: every tier holds at least one more indoor
shelf than the tier below it, with no exceptions and no ties.** A player who
rebirths straight past a middle tier must never end up with fewer shelves
than one they walked past.

**Shelf count is derived from the room's own floor area, and the derivation
needs a clamp the moment you look at the real numbers.**
`assets/houses/tools/walkin_catalogue.py` already has a measured, walkable
room for all eighteen houses, and floor area is not remotely monotonic with
price today: Crystal Spire, at $25M, has the SMALLEST room of any tier —
smaller than the free Starter Shack. That is not a flaw to fix in the room
geometry (a crystal spire is meant to be a narrow tower, and §6a is what
actually fixes it); it is a reason the shelf FORMULA cannot be a bare
`floor(area / density)`. It has to be that, clamped to never fall below the
previous tier's count plus one — the exact shape `Config.UPGRADE_COST_CEILING`
already uses to keep an unrelated curve from breaking a rule it was never
solved to respect.

**The count still comes from the art, never from a number typed twice** —
that half of the rule doesn't change. What changes is that "the art" gets a
tooling pass rather than a hand-authored mount per house: a script (extending
`build_walkin.py`) places `Shelf_N` mounts around a room's own perimeter at a
fixed spacing, so the count is a consequence of the room someone already
built rather than a fresh decision per tier.

**And the ladder is asserted at boot, not eyeballed.** An audit — either a
new `Config.auditHouseSlots()` or a clause inside whichever audit already
walks the house catalogue — builds every tier, counts its `Shelf_N` mounts,
and refuses to boot clean if the sequence is not strictly increasing.
`CLAUDE.md`'s own history is the argument for this: the Sky Castle's "16.6
studs too wide," the vault opening sized against only one of four lock
tiers, `SHOP_BANK_PIG_SECONDS` wrong by 62% on its first audited boot — every
one of those was a number that looked fine until something actually measured
it.

**Plus the till (1) and the lawn, which has room for everything else you
own.**

**The ear shelves are a one-off, not a step in the ladder.** They belong to
the top house alone — visible from the street, unreachable by anyone but the
owner, pure flex, earning the same rate as anything else. If a nineteenth
priced house is ever added, it does not get its own matching flourish by
default; that pattern was spent once, deliberately, at the top.

**Switching your displayed house down costs protection, never income.**
`houseShown` and `houseLevel` are already separate — a player may wear any
house tier they have unlocked, not only their newest, purely for looks — and
under the old "unslotted piggies earn zero" model that meant a real risk of
orphaning a collection. It does not any more: the lawn is unlimited, so
anything that no longer fits on the smaller house's shelves simply stands
outside instead, still earning, now just exposed. Worth a heads-up toast on
the switch — *"Only 4 of your 16 shelved piggies fit in Beehive Cottage; the
rest will be on the lawn."* — but never a blocking confirm, because nothing
is actually at stake in the way the old draft of this section thought it was.

**Rebirth raises the house ceiling rather than wiping the collection.**
Rebirth keeps doing what it does — wipes the upgrade trees and coins, never
touches cosmetics — and since cosmetics are now income, what it must NOT do
is take piggies. What it grants instead is access to the next house tiers,
which is "more rooms unlocked via rebirths" and is exactly the loop the
comparison game runs on.

---

## 6a. Making eighteen houses feel like eighteen different amounts of space

**Right now every one of the eighteen has exactly one room, and most of them
are lying about it.** `walkin_catalogue.py`'s own comment says so: *"Higher
exterior storeys remain architectural until connected floors are designed
separately."* Townhouse (3 storeys), Villa (2), Manor (3), Slime (2), Modern
(2), Neon Tower (6!), Crystal Spire (4), Palace (3), Sky Castle (5), Galleon
(3), Portal (3), Thundercloud (5), Void (5) and Golden Piggy (3) all show a
multi-storey exterior and deliver a single ground-floor room. That gap
between what the outside promises and the inside delivers is the actual
thing behind "they all have about the same indoor space" — it is true, and
it is because fourteen of the eighteen have unused floors sitting right
there in the model.

**Floor AREA already varies for free — it is FLOOR COUNT that is flat.**
Measured off the room bounds in `walkin_catalogue.py`, the eighteen rooms run
from about 127 sq. studs (Crystal Spire, Toadstool Cottage) to about 762
(Sky Castle), with real spread in between — Manor 420, Palace 669, Void 605,
Portal 632. That spread is a real ladder already sitting in the geometry;
the shelf-count formula in §6 can lean on it today with zero new modelling.

**So the plan is two tracks, not one re-model of everything.** Track one:
run the §6 formula against the room areas that already exist — free, and it
already produces most of the differentiation being asked for. Track two: a
short, curated list of tiers get an actual second connected floor, because
building sixteen new upper storeys is a lot of Blender work for tiers where
it would go unseen for a long time, and the tiers with the biggest gap
between promise and delivery are also, not coincidentally, some of the ones
a player spends the most real time looking at.

**A first cut at the list, picked on gap size and payoff, not tier by
tier:**

| tier | why this one |
| --- | --- |
| Crystal Spire | its ground floor is the smallest room in the game at a $25M price — a second chamber up the spire is the fix, not a nice-to-have |
| Haunted Manor | the strongest "there's something upstairs" trope in the whole catalogue, and it's a mid-tier a lot of players will live in for a while |
| Neon Tower | six exterior storeys delivering one room is the single biggest gap in the catalogue — a penthouse floor is the obvious payoff |
| Sky Castle | the top of the original nine-tier ladder and still a landmark; a second floor (a keep interior above the hall) matches what "castle" already promises |
| Thundercloud Fortress | five storeys, and "climb up into the eye of the storm" is a strong second-floor beat for very little new dressing beyond what a storm interior already wants |

The rest keep their one room for now. This is a shortlist to argue with, not
a final one — the criterion to reapply if it changes is: does the gap
between the exterior's storey count and the interior's room count actually
cost the tier something a player would notice, and is the tier itself one
people spend enough time in to make new modelling worth it.

---

## 7. What retires

* **The passive drip.** Income comes from piggies. Offline accrual keeps
  running off the same collection, so coming back is never empty.
* **Acorns, the tree, the basket, the shake, `ResidentAcorns`, `auditAcorns`.**
  Confirmed.
* **The coin-priced crate purchase in the shop.** Crates are job-earned only
  (see §7a) and event-earned as they are today; the Crates tab's buy button
  retires with it. Nothing in `Config.CHESTS` — the pool, the odds, the tier
  structure — changes; only what pays for a roll.
* **The season track**, which counts acorns and nothing else. It has no readers
  after the above and it is a live-ops retention system on a game that has not
  launched.
* **Skins as a wardrobe.** There is no "equipped skin" any more, only "which
  piggy is on the till".

---

## 7a. Jobs — how a crate is actually earned

**Crates are earned, never bought.** The shop's Crates tab keeps its role as
an inventory — see what you have earned, open it — and loses its buy button.
This is the twist against the genre: nothing in this catalogue is a
transaction. Everything in it is a receipt for having played.

**A rotating task board, in three tiers, reusing verbs the game already
has.** No new minigame, no new currency to invent — every objective is built
from an action players already take.

| tier | refreshes | shape | example |
| --- | --- | --- | --- |
| Daily | every UTC day (`Config.dayIndex()`, the same clock the daily ladder already uses) | short, always completable in one sitting | Collect from every slotted piggy. Snatch one piggy off a lawn. |
| Weekly | every UTC week (`Config.weekIndex()`, the same clock the leaderboard already uses) | accumulates across several sessions | Deliver 5 stolen piggies. Fill every lawn pedestal at once. |
| Feat | persists until done, no refresh | harder, often skill- or luck-gated, one-off | Land two robberies in a row (spree tier 2+). Top the Most Wanted board. Survive a patrol while carrying. |

**The daily board always carries at least one job a nervous new player can
complete without ever robbing anybody.** Collecting your own lawn is a job;
so is filling an empty shelf. Nothing here may require PvP to progress at
all — it only pays *faster* if you take the riskier jobs, the same shape the
whole robbing-vs-idling economy already runs on. This is the same rule that
protects a first-session player everywhere else in this design.

**Jobs pay `loot`, and crates are priced in `loot` instead of coins.** `loot`
already exists, already means "you went out and did something," and already
buys the accessory roll and the set items — so this is one more thing one
currency already earns, not a new currency to teach. It also settles §9's
gap on `loot` outright (see below): a crate's price becomes a `loot` cost
instead of a coin cost; nothing about `Config.CHESTS`' pool, odds or tier
structure changes, only what pays for the roll.

**Feat-tier jobs pay the best crates, because they are the hardest to
fake.** A daily job can be done by walking a route; a spree or a Most Wanted
feat needs the street to actually go your way, which is the honest reason to
reserve the top of the crate ladder for it.

---

## 8. What this breaks, stated plainly

**Every economy ratio is measured against the idle rate, and the idle rate is
gone.** `auditRobbery` compares robbing to idling; `ROBBERY_ADVANTAGE` is 3–10×
of it; `RESIDENTS.pigSeconds` is solved against income; the daily ladder is
denominated in seconds of income; the upgrade cost ceilings ride capacity which
rides income. None of it breaks silently — the audits exist precisely for this
and will refuse a bad band at boot — but all of it has to be re-derived against
"what a player's collection produces". **This is the single largest piece of
work in the plan and it is arithmetic rather than code.**

**A rule in `TrophyRoom` is being deliberately spent.** Its header says:
*"display capacity may grow with the house and ACHIEVEMENT capacity may never…
a grander template is an art change and cannot become a gameplay advantage."*
Once shelves hold earning piggies, a grander template IS a gameplay advantage.
The achievement wall keeps the rule; the piggy shelves consciously break it, and
the two must stay separate mounts so the line is still drawn somewhere.

**Losing a piggy is losing permanent progress, which this design has refused
once.** `CLAUDE.md` records that taking progress was proposed as the robbery
incentive and rejected: *a crying-then-uninstall event a parent sees.* Three
things bound it and all three already exist:

* a plot is RELEASED when its owner logs off, so nobody is ever robbed while
  away;
* the indoor shelves raise the cost of reaching your best pieces sharply — a
  fence tier crossed, a mobility gadget owned, a lock cracked or skipped
  (§5a) — the fence ladder's own "defence buys time, never immunity" rule
  applied one level up, not a guarantee;
* a stolen piggy is standing in plain sight on the thief's lawn and can be
  taken back.

`LOSS_CAP` should grow a second clause — a maximum number of piggies lost per
rolling hour, whoever is taking them — for the same reason it caps coins.

**Compounding.** More piggies → more income → more crates → more piggies.
Slots are no longer the brake — every piggy earns regardless of where it
stands — so the brake is now the job board's own cadence (§7a): a daily and
a weekly refresh cap how many crates anyone can earn per unit time, whoever
they are, which is a harder ceiling than a slot count ever was. Crates must
still never be buyable with coins, or that ceiling has a side door.

**Skins must stay crate-only.** They were already, for rarity and sell-cap
reasons. Now there is a harder one: a skin bought with coins is income bought
with income.

**A coin sink just left the game, and nobody has re-checked what that does to
the endgame.** The late-game ladder (houses, rebirth pacing) was solved
against a coin economy that included buying crates. Retiring that purchase
in favour of jobs (§7a) means coins that used to leave the economy there now
just pool — which either needs a bigger house/upgrade sink to absorb it, or
it needs to be shown harmless. This is exactly the kind of two-curves-
multiplied-without-checking-the-product failure `CLAUDE.md` keeps a whole
section on; it wants a sim pass alongside the income-rate work in §4, not an
assumption that it nets out.

**The till's fill animation stops being a smooth rise.** It currently reads
capacity filling continuously; under active collection it now jumps once per
collect instead. That is a real visual change to the one readout every thief
prices a job on, and it wants a look before launch rather than a surprise.

---

## 9. Gaps I cannot close without a decision from you

1. **Three rarity tiers or more?** Skins are on three today, chosen because a
   four-rung ladder was setting the art schedule. With income attached a longer
   ladder is worth more. Adding a tier means authoring for it.
2. ~~Do lawn piggies earn the same as indoor ones?~~ **Resolved 2026-09-20.**
   Yes, identically. Placement is entirely about exposure, never about rate.
3. ~~Can a thief ever get inside a house?~~ **Resolved 2026-09-20 — see §5a.**
   Yes, through a beaten fence plus a mobility gadget and either a cracked or
   skipped lock. Never free, never impossible — the same rule the fence
   ladder has always followed.
4. **What do residents display?** Every resident lawn should carry piggies or a
   solo player can never build a collection. How rich their pedestals are is
   the single biggest dial on solo pacing.
5. ~~What happens to `loot`?~~ **Resolved 2026-09-20 — see §7a.** Jobs pay
   loot, and crates are priced in loot instead of coins. It was never one too
   many; it just needed a third job.

---

## 10. Phases

**Phase 1 — the slice worth testing before anything else is built.**
Piggies earn into their own buffer and must be collected by hand (§4a). Lawn
only, no interiors, no cap. Starter Classic on the till. Income tree
re-pointed. Passive drip removed. One piggy, one spot, one collect prompt,
one number going up.

**Phase 2 — the point of the whole thing.**
Snatch a piggy off a lawn, carry it home, slot it. Stolen piggies appear on the
thief's lawn. `LOSS_CAP` gains its piggy clause.

**Phase 3 — the base.**
Indoor shelves read from `Shelf_N` mounts auto-placed by the room-area
formula in §6. House tier sets the count, identical earn rate to the lawn.

**Phase 4 — the tail.**
Ear shelves on the top house. Acorns and the season track retired. The job
board ships (§7a) and the coin-crate purchase in the shop retires with it.
Spring Boots, Grapple Gun and Jetpack ship alongside Brick Wall and Golden
Gate Fence (§5a), and the curated second floors from §6a land.

**Phase 1 and 2 together are the vertical slice.** If placing a piggy, watching
it earn, and having somebody take it is not fun with an open lawn and no
rooms, no amount of interior work will rescue it.
