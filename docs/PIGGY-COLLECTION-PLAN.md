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

**LAWN — SIX PEDESTALS. Resolved 2026-09-20, and it reverses what this
section and §4 used to say.** The paragraph here read *"every piggy you own,
all of them, all the time. There is no cap here and no bag behind it... the
grid grows (more rows, tighter spacing) as the collection grows rather than
ever refusing a new arrival"*, and §4 stated it as flatly as a rule gets:
*"EVERY PIGGY YOU OWN IS ALWAYS PLACED AND ALWAYS EARNING. There is no
unslotted state, no bag, no shed."* It is **six slots**
(`Config.PIGGY_LAWN_SLOTS`), and the first four of them are the retired lawn
ornament grid reused rather than a new one invented — `Config.DECOR_SLOTS`'
own comment says those four coordinates cost nothing standing empty and that
deleting them would be the expensive half of coming back.

**WHAT IT COSTS is the "nothing ever sits doing nothing" rule, and that is a
real loss rather than a technicality.** Own a seventh piggy and it is owned,
counted, and earning nothing until there is room — so `owned` and what is
PLACED are two different numbers now, and every income figure has to read the
placements rather than the collection. §4's own argument that a repeat pull
from a crate is "the thing you were hoping for" is weaker against a full
lawn than it was against an unlimited one.

**WHAT IT BUYS BACK IS THE PRESSURE THE UNCAPPED VERSION GAVE AWAY.** §4 had
to argue that the reason to buy a bigger house was *"find room or leave your
best pieces exposed"* — which is a far weaker sentence than "find room or it
earns nothing" — and §6 is 126 plots of indoor capacity that, uncapped,
nothing actually needed. Capped, the whole rebirth hallway has a job again,
and so does every fence tier and lock that defends six visible pedestals
instead of an unbounded pile.

**TWO WAYS ONTO A PEDESTAL, AND THEY ARE DELIBERATELY NOT THE SAME.**

* A piggy you **went and got** — rounded up out of a herd (§15) or snatched
  off somebody's lawn (§5) — is placed **by hand** into any free slot. You
  carried it home; you choose where it stands.
* A piggy out of a **crate** lands on the **first free slot, front to back**,
  with nothing to press. A reveal is already a moment — the reel, the tier,
  the spare chip — and making it also a placement decision spends that moment
  on admin.

Front-to-back is the order of the table, so a collection grows **toward the
street** rather than appearing behind the house where nobody walking past
would see it. This is still the default state of everything you own, and it
is still what anybody can walk up and take.

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

**~~EVERY PIGGY YOU OWN IS ALWAYS PLACED AND ALWAYS EARNING.~~ Reversed
2026-09-20 — the lawn is six slots. See §3.** What stood here read: *"There
is no unslotted state, no bag, no shed. A piggy comes out of a crate standing
on your lawn, earning from that second... nothing this design ever hands a
player is allowed to sit there doing nothing. The pressure to buy a bigger
house is not 'find room or lose income' — every piggy already pays regardless
of where it stands — it is 'find room or leave your best pieces exposed.'"*

It is kept rather than deleted because the sentence it gave up is the one to
weigh against anything that widens the lawn again: **a spare piggy now sits
there doing nothing, which is the thing this design said it would never
hand anybody.** What replaces it is that the pressure went back to being
"find room or it earns nothing", which is the stronger half of the trade and
is what gives the rebirth hallway in §6 something to be for.

**A PLACED PIGGY EARNS WHEREVER IT STANDS, WHICH IS UNTOUCHED BY THAT.** A
lawn pedestal, the till and an indoor plot all pay the same rate; placement
is entirely about exposure (§9.2). What changed is only whether a copy is
placed at all.

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

## 6. Indoor capacity — a hallway gated by rebirth, not by house tier

**Superseded 2026-09-20.** This section used to derive shelf count from each
house's own authored floor area (Crystal Spire's narrow tower, a clamp
borrowed from `UPGRADE_COST_CEILING`, a `Shelf_N`-per-perimeter tooling
pass). None of that survives now that the interior is one fixed-size generic
room for every tier — see §6a and `docs/PIGGY-COLLECTION-BUILD-ORDER.md`.
What follows is the replacement.

**Every house interior is the same fixed size and the same fixed layout: one
long hallway, doors along it, floor plots between them.** What a house
purchase buys for the interior is the THEME dressing on that hallway — the
part §6a is actually about — never more space and never more plots. Capacity
is a separate axis entirely, and it comes from rebirths.

**Piggies stand on floor plots, not wall shelves.** This is closer to the
lawn's own placement grid than to `TrophyRoom`'s wall-mount system — the same
"a piggy has a spot, and the spot is a floor position" logic, just relocated
indoors and behind the door/fence/lock gate instead of open to the street.
The achievement wall (`TrophyRoom`, stats plus the wanted poster) is
untouched and keeps its own `Wall` mount somewhere along the hallway — a
separate display on a separate contract, for a separate thing.

**Each door along the hallway unlocks at a rebirth threshold**, revealing
more corridor and more plots beyond it. The strictly-monotonic rule this
section always carried survives unchanged, and it is trivially true now
instead of needing a clamp to guarantee it: it is a designed sequence — a
typed table of plot count per rebirth tier — rather than something derived
from messy per-house art.

**Asserted at boot the same way the old formula would have been** — a clause
that walks the rebirth ladder and refuses to boot clean if the plot count
per tier is not strictly increasing. Cheaper to write than what this
replaced: there is no art left to measure, only a table to check.

**Plus the till (1) and the lawn, which has room for everything else you
own.**

**The ear shelves stay a one-off on the top house** — visible from the
street, unreachable by anyone but the owner, pure flex. Unaffected by any of
the above; they were never part of the indoor capacity ladder.

**Switching your displayed house is now purely cosmetic.** Under the old
model, displaying a smaller house risked orphaning shelved piggies onto the
lawn, which needed its own toast and its own reasoning. That risk is gone —
capacity never comes from the house at all under this shape, so changing
which house is shown changes nothing about what fits where.

**One new room every rebirth, 6 plots each, straight through to rebirth 20.**
Resolved 2026-09-20 — rebirth 20 matches the ceiling this game already uses
elsewhere (band C already runs "two levels per rebirth to rebirth 20"), so
that half isn't a new number, just a new axis using an existing one. 21
rooms (rebirth 0's starting room plus one per rebirth through 20) at 6 each
is **126 total indoor plots** — 120 if the first room itself is meant to
require the first rebirth rather than existing from day one; either is a
one-line change to the per-tier table, not a design question.

**More skins is the right instinct, and 126 plots against a ~44-skin
catalogue (§1) says roughly how many.** Duplicates stacking and earning (§4)
means the economy never runs short of room to fill — the lawn alone is
uncapped — so nothing here is blocked on having more skins; the hallway will
fill with duplicates fine either way. What more skins buys is a curated
hallway that still reads as a COLLECTION at rebirth 20 rather than the same
44 faces averaging three copies apiece. Filling it near 1:1 wants roughly
the catalogue tripled; even getting average duplication down to about 2x
wants it somewhere past 60. That's a dial, not a hard requirement — and it's
a content-authoring track, not a blocker for Stage 4's engineering. It can
run in parallel, the same way the house art and the runtime integration were
split into separate workstreams in
`assets/houses/docs/HOUSE-TROPHY-ROOMS.md`.

---

## 6a. Making eighteen houses feel like eighteen different amounts of space

**Deferred past the MVP — resolved 2026-09-20, see `docs/PIGGY-COLLECTION-BUILD-ORDER.md`.**
The MVP interior is one code-generated generic room, not per-house Blender
art, so nothing below is being built yet. It stays here rather than being
deleted because it is exactly the brief to pick back up if bespoke,
theme-matched interiors get built later — the curated shortlist and the
reasoning behind it don't go stale just because the first version skips them.

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
  **DONE 2026-09-21**, out of order — ahead of the job board rather than after
  it, because the crate decision below forced it. `data.loot` is deleted
  (schema 29). See `CLAUDE.md` under THERE IS ONE CURRENCY.
* **The crate purchase in the shop.** **DONE 2026-09-21.** No crate carries a
  `currency` or a `cost`, `ChestService.open` and the `ChestOpen` remote are
  gone, and `auditRandomOutcomes` now REFUSES a priced crate. Nothing in
  `Config.CHESTS` — the pool, the odds, the tier structure — changed; only what
  pays for a roll. Crates are award-only in the meantime: day seven of the
  daily ladder, a rebirth, and events. **The job board (§7a) is still the
  intended earn surface and is still unbuilt**, so the tab is thinner than it
  will be.
* **The season track**, which counted acorns and nothing else. **DONE
  2026-09-21** — the RANK, its tiers, its rewards, its board page and the plot
  sign's chip. `Config.seasonIndex` survives because the buy-back claims and
  the hot-skin window key off it, and so does the nemesis ledger. **The five
  `Config.FINISHES` are now unobtainable**, which is the one hole this left.
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

---

## 11. Rebirth-gated content

**Houses already work this way** — §6 already says "Rebirth raises the house
ceiling rather than wiping the collection." Nothing new needed there; this
section is about extending the same shape to a category that doesn't have it
yet.

**Gadgets join the same ladder.** The §5a mobility gadgets (Spring Boots,
Grapple Gun, Jetpack) unlock progressively by rebirth count rather than being
purchasable from level 0 — a new player cannot buy their way to reaching an
indoor shelf on day one, the same way a new player cannot buy their way to
the top house tier today.

**"Etc." needs a specific list before this is buildable, and one thing has to
stay off it no matter what's on it.** Rebirth-gating "everything" would
include the piggy collection itself if read literally, and that directly
reverses the rule this whole plan is built on top of: *"Rebirth wipes power
but never cosmetics... the collection is the reason to press the button."*
Piggies are income now, not cosmetics, but the rule protecting them from
rebirth is the same rule — losing the collection on rebirth would mean losing
the income source on the one action meant to grow it. **Gate power (gadgets,
fence tiers, upgrade trees), never the collection.**

*Open: what else is on the "etc" list?*

## 12. The piggy-pedestal guards run slower than the player

The reference game's guards sleep until triggered, then chase — but never win
a footrace against a player with any separation. That's the rule to
replicate: **guard speed for the pedestal defence sits below the player's own
carrying speed (12 studs/s)**, so once a thief is moving with a head start,
distance only grows. The threat is being caught close, not being run down
from across the lawn.

This is a genuinely different speed rule from the till's existing guard dog,
where the top tier (Titan, 17) is deliberately *faster* than even a
free-running player (16) — that asymmetry is load-bearing for the till's own
chase math and the officer/dog speed ladder the whole getaway is tuned
against. So this wants to ship as a **separate speed profile on the same
`GuardDog` rig** (a pedestal-guarding role vs. a till-guarding role), not a
global retune, unless there's a reason to want the till softer too.

*Open: confirm this is scoped to pedestal guards only.*

## 13. An in-base shop

The interior gets a second shop entrance — same door-and-prompt pattern as
the street shops, opening the identical shop panel that already exists. No
new shop system; just a second door into the one that's there.

## 14. Robux-purchasable crates — flagged, not decided

This is the one item here that isn't a "note it down and move on," because it
reverses the single most defended rule in this file's whole history:
*"COINS ARE NOT PURCHASABLE WITH ROBUX AT ANY PRICE, EVER... the day a coin
pack ships, every chest in the game becomes a regulated loot box
retroactively... this rule can only ever be broken once."* Pets-from-crates
is already this game's design — §7a already has piggies coming from crates,
earned through jobs. What's new in "mimic the reference game" is Robux being
able to buy those crates directly, or buy a currency that can.

If that is really what's wanted, it needs to be built as a **compliant paid
random item**, not a bare purchase button: Roblox requires disclosed
numerical odds summing to 100% before purchase, and a
`PolicyService.ArePaidRandomItemsRestricted` check that refuses the feature
outright for restricted regions and ages (UK under-18, Australia, Belgium,
and expanding) — meaning a real share of this game's own stated audience
would meet a button that does nothing. That is buildable, but it is a real
compliance surface, not a config flag, and it is one-way: once it ships, it
cannot be walked back without every existing chest becoming retroactively
regulated alongside it.

**The alternative already in use elsewhere in this game** gets most of the
commercial value without any of that: sell a *named* pet directly for Robux —
no randomness, no odds disclosure, no regional gate — the same shape as the
Style Pack and the ride passes. A guaranteed legendary skin for a fixed Robux
price is a real thing to sell; a gamble at one is the thing that needs the
compliance work above.

*Open: direct Robux-to-crate purchase (needs the compliance build), or a
named-pet direct purchase (already the pattern this game uses)?*

## 15. Roaming herds — a fourth way to earn a crate

**The shape:** herds of small, pet-scale piggies run out through the street's
own tunnel mouths — the same geometry the patrol car already enters and
exits by — and roam the street for a while before despawning. A player who
catches one banks a crate, the same reward shape dailies and jobs already
pay, not a guaranteed specific piggy.

**Cadence and cap reuse the event scheduler's own shape**, not new machinery:
a timed roll every few minutes, weighted rather than uniform (the
damped-repeat picker already built for raid/rush-hour is the pattern), and a
hard cap on how many herds are loose on the street at once.

**Catching is a genuinely new verb.** Every other pickup in this game is a
stationary target — a till, a pedestal, a bin. A herd member has to move on
its own (wander, and maybe flee once approached) before a player closes on
it, which is new NPC-movement code, not a reskin of anything that exists.
Contested the same way everything else on this shared street is: first
player to reach a given pig gets it.

**Pet-sized is right, and it buys something specific: no accessory slots, no
vault hatch, no dial.** Every scale-dependent measurement this game has ever
shipped — the accessory anchors, `DIAL_MAX_R`, the vault opening sized
against the smallest lock tier — was solved against one specific pig radius,
and re-deriving all of it at a new, smaller scale is exactly the class of
work this file has whole sections of scar tissue about. A herd piggy that is
skin-only, with nothing worn and no hatch cut into it, sidesteps that math
entirely rather than reopening it.

**Crates are earned four ways once this lands: catching a herd member, the
daily ladder, jobs (§7a), and Robux (§14, still undecided which shape).**
