# Rob a Piggy Bank

A Roblox shared-economy PvP game for an under-12 audience. Eight players to a
server, one plot each, on a street wide enough to carry shops and boards on its
verge. Players own a plot with a piggy bank that fills with coins over time; other players can steal from the
*uncollected* portion. Defence and offence are competing upgrade trees.

**Three documents, three jobs.** This file is WHY: the rules, the
post-mortems, and what breaks if you change something. It is read on demand,
never top to bottom.

* [`docs/GAME.md`](docs/GAME.md) is WHAT: a complete map of every system, where
  it lives, and how the pieces relate -- the file to hand somebody new. It names
  constants rather than copying their values, and it is maintained by the
  `game-doc` agent (`.claude/agents/game-doc.md`). Run that agent after anything
  that adds or retires a system, moves a responsibility, or changes a save
  field.
* [`docs/design-doc.html`](docs/design-doc.html) is the original pitch, the
  balance targets and the build phases -- open it in a browser.

Nothing from this file gets moved into GAME.md. The reasoning is the point of
this one, and a rule stripped of the failure that produced it is a rule nobody
believes.

---

## Getting set up

The game is **generated entirely in code**. There is no hand-built geometry: the
ground, the street, the houses, all eight plots, the piggies and the dogs are
constructed at server start. A fresh empty place plus this repo gives you the
identical world, which means the `.rbxl` is disposable and this repo is the project.

1. Install [Rojo](https://rojo.space) 7.7+
2. `rojo serve default.project.json`
3. In Studio: **Plugins → Rojo → Connect**
4. Press Play

`rojo build default.project.json -o RobAPiggyBank.rbxlx` produces a complete place
file if you need to open one without syncing.

---

## Layout

```
src/
  ReplicatedStorage/Shared/
    Config.luau            Every tunable number in the game
    Remotes.luau           Every client/server channel, declared in one table
    BoneModel.luau         Bone geometry, shared by the server and the shop icons
    PigGear.luau           Accessory geometry, shared the same way
    DodgeRoll.luau         The dodge somersault, a KeyframeSequence built in code
    PoliceModel.luau       The patrol car and the officer, both built in code
    House.luau             The upgradeable house -- shared, because the shop renders it
    Decor.luau             Lawn ornaments -- shared for the same reason
    PiggyModel.luau        The little piggy: carried loot, and every skin tile
    RideModel.luau         The five rides, sized to the rider that sits on them
    RidePose.luau          How a rider sits or stands, and how they lean in a trick
    RideSound.luau         What a ride sounds like, and silencing the footsteps
    Music.luau             The score: one cue, then silence, then another
  ServerScriptService/
    Main.server.luau       Entry point: starts services, owns player lifecycle
    Services/
      DataService          Session-locked DataStore persistence
      WorldService         Ground and lighting
      NeighborhoodService  Road, trees, street furniture (pure scenery)
      PlotService          Plot pool, fences, ownership
      PiggyBank            The piggy model, coin pile, skins, effects
      GuardDog             Patrolling dog, its kennel, and the off-duty nap
      BoneService          Thrown bones: the counter to the guard dog
      EconomyService       Accrual loop, milestones, banking
      UpgradeService       The two upgrade trees
      HeistService         Stealing, carrying, tagging, delivering
      CosmeticsService     Buying and equipping skins/effects
      ProgressionService   Rebirth
      SocialService        Friend bonus, leaderboard, revenge markers
      PoliceService        The street patrol and its thirty-second pursuit
      SettingsService      Player preferences -- the one thing a client may write
      AdminService         Owner-only dev console (F2 in game)
  StarterPlayer/StarterPlayerScripts/
    ClientMain.client.luau HUD and shop panel
```

---

## Rules that are load-bearing

Breaking any of these silently breaks the game rather than erroring.

**The server owns all state.** The client renders whatever the last `StateUpdate`
said and never computes a balance. If client and server disagree, the server is
right by construction.

**Only uncollected coins are stealable.** Banked coins are permanently safe. A
robbery costs the victim a few minutes of idle income and never costs progress.
This is what keeps the game from being a bullying simulator, and it is why the
caps in `Config` are hard limits rather than discouragements.

**`STEAL_RANGE + DROPOFF_RADIUS` must stay well under `PLOT_SPACING`.** If that
sum approaches the spacing, a thief can stand in their own drop-off zone and rob a
neighbour without ever running — and the run is the entire risk half of the trade.
At 11 + 16 against a spacing of 80 the shortest getaway is 53 studs, about 4.4
seconds at carry speed; the margin is 34% of the spacing, wider than the 42% it
was at the old 64.

**THE GETAWAY GREW WHEN THE PLOT DID, AND THAT IS A REAL BALANCE SHIFT rather
than a wash.** It was 37 studs and 3.1 seconds. Over the longer run an alerted
Titan at 17 now closes **22.1 studs** on a carrying thief against 15.5 before,
so defence got quietly stronger everywhere at once — dogs, gadgets and the
patrol all get more time. If robbing starts reading as too hard, the lever is
`DROPOFF_RADIUS` and not `PLOT_SPACING`: a drop-off zone is a fraction of your
own plot rather than an absolute distance, so it can grow with the plot and hand
the run back, while the spacing is holding up the alley and the row length.

**Speed is the currency.** `BASE_WALK_SPEED = 16` is the number every other system
is calibrated against: the carry penalty (×0.75), Speed Boots (capped at ×1.0, so
they never exceed base), dog speeds (12 / 14.5 / 17), fence snags (×0.80 → ×0.30)
and the electric stun (0). Anything that makes a player faster than 16 invalidates
several systems at once.

**A fence must never be uncrossable.** Defence buys *time*, never immunity. An
un-robbable player kills the offence tree and stalls the economy at the top. Every
tier from Barbed Wire up stays at a jumpable 6.0 studs and escalates the hazard
instead — `BASE_JUMP_HEIGHT` is 7.2.

**Rebirth wipes power but never cosmetics.** Skins, effects, houses, decorations
and accessories are the permanent progression track that a reset cannot take
away. Rebirth already costs every upgrade a player owns; the collection is the
*reason* to press the button. Take that too and nobody rebirths, which stalls
the economy at exactly the point rebirth exists to unstall.

**THE ROLL IS PAID FOR IN A CURRENCY THAT CANNOT BE BOUGHT, AND THAT IS THE
LINE THAT KEEPS IT LEGAL.** It used to cost COINS, under the rule that coins
must therefore never be sellable. That rule was correct and it was also a trap:
it made the single largest monetization lever in the game permanently
unavailable, and it would have been broken by a business decision rather than
by a code change -- the day a coin pack shipped, the roll would have become a
paid random item with nothing in this repo having moved.

Roblox defines a paid random item as one bought with Robux **or with in-game
currency purchasable with Robux**. They are regulated rather than banned: real
numerical odds shown before purchase, summing to 100%, and a `PolicyService`
gate (`ArePaidRandomItemsRestricted`) that makes the feature refuse to open for
restricted users. Restrictions are regional and expanding -- UK under-18,
Australia, Belgium. For an under-12 audience that is a large share of players
meeting a button that does nothing.

**MOVING THE ROLL ONTO AN EARNED-ONLY CURRENCY DOES NOT COMPLY WITH THAT RULE,
IT STEPS OUT OF IT.** Nothing random here is purchased, so there is nothing to
disclose and nothing to gate.

**AND THEN THE COIN PACK WAS DROPPED ENTIRELY, WHICH IS A BIGGER DECISION THAN
THE ROLL EVER WAS.** The paragraph above was written to make a pack safe. There
is no pack. **COINS ARE NOT PURCHASABLE WITH ROBUX AT ANY PRICE, EVER**, and
that single sentence is now what keeps the whole shop outside the paid random
item rule rather than compliant with it.

What it buys is enormous and worth stating, because the constraint reads like a
cost and is mostly a saving: **anything in this game may now be sold for coins,
including random things.** Chests, spins, crates and combines are all ordinary
in-game rewards for in-game money -- no odds disclosure obligation, no
`PolicyService` gate, no regional lockouts, no player in Belgium or the UK
meeting a button that refuses to open. The design space that the roll had to be
carefully walked out of is simply open.

**THE PRICE IS THAT THIS RULE CAN ONLY EVER BE BROKEN ONCE.** The day a coin
pack ships, every chest in the game becomes a regulated loot box retroactively,
with nothing in this repo having changed -- and by then there will be a
catalogue of them, not one roll button. So it is not a preference that a later
business decision can revisit: it is load-bearing structure, and anything that
wants to sell currency has to replace this entire section first.

**MONETIZATION IS NAMED THINGS, NEVER CURRENCY.** Pets, rides, passes,
stances: a purchase that hands over a specific item mints no coins, feeds no
chest, and is an ordinary direct purchase -- which is the safest possible shape
to put in front of an under-12 audience. `Config.PASSES` and the Style Pack are
already this, and the rule above the Style Pack (*"a Robux purchase may grant an
item, never its coin value"*) is the same sentence from the other end.

**EVENT TOKENS BECAME EVENT LOOT, WHICH IS WHERE THEY BELONGED.** They were
invented to carry the accessory roll away from purchasable coins; that job no
longer exists. What they do now is the one thing coins must not: they buy
chests of EVENT-THEMED loot, earned by turning up and by doing things during an
event rather than by being rich. Coins buy the standing catalogue; tokens buy
the alien set, and whatever the next event brings. That keeps the attendance
ladder meaningful without it standing in front of the main loop.

**DUPLICATES NOW EXIST, WHICH REVERSES A RULE THIS FILE USED TO STATE AS
LOAD-BEARING.** It read: *"a roll can only return something you do not already
own... every roll is progress, and the collection always completes... there is
no pity timer to tune and no duplicate-currency to invent: those exist to paper
over a problem this design does not have."*

That was right for what it described -- one button, a pool of twelve, and
nothing else random in the game. It is the wrong shape for a chest. A chest
that cannot repeat is a checklist with an animation on it: you open it N times,
you finish, and there is no moment in any of it. The thrill in a chest is
rarity variance, and duplicates are what make a tier mean anything.

**SO THE RULE IT IS REPLACED WITH IS NARROWER AND HARDER: A DUPLICATE IS NEVER
A DEAD OUTCOME.** It converts to shards the instant it lands, in the same reveal,
so an open always visibly pays out -- and the shards are what feed the combine.
What the old rule protected was that a nine-year-old never opens something and
gets nothing; that is still true. What it no longer protects is that they never
open something twice, which was never the part that mattered.

**THREE OF A TIER, NOT TWO, AND THE ARITHMETIC DECIDED IT.** The proposal was
two commons for a 97% shot at a rare. Two compounds to about EIGHT commons for
a legendary -- roughly eleven chests -- which makes the top tier something a
player manufactures rather than something they get, and drains the one moment
the chest exists to produce. At three it is twenty-seven, and the two routes to
a legendary cost about the same: 25 opens rolling for one directly, 25 opens
gathering three epics and combining. **That balance is the property to
preserve**, not the specific numbers -- if combining ever gets much cheaper than
rolling, nobody rolls for the top tier and a chest becomes a common dispenser.

**AND THE SKIP CHANCE IS SIZED TO BE SEEN.** 97% is an exchange rate rather than
a gamble: all of its tension sits in a 3% window most players never meet once.
At 15% across two tiers, a child who combines ten times has probably jumped one
and will tell somebody about it. That is the whole reason the mechanic is there.

**TWO CURRENCIES, AND THE ARROW ONLY POINTS ONE WAY.** Coins buy the standing
catalogue -- `classics` and `gear` today, `animal` and `neon` when their skins
land. Tokens buy EVENT chests, and no amount of coins reaches one: you were on
the street when the saucer came or you were not. **Shards spend only on COIN
chests**, which is the rule that keeps that true in the other direction -- a
rich player could otherwise grind coin chests and combine their way into the
alien set without ever attending an event. Duplicates from an event chest do
still PRODUCE shards, which is a small thank-you for turning up; the arrow just
does not run back.

**SHARDS ARE GLOBAL PER TIER, NOT PER CHEST, and that is what answers the
question a chest system otherwise cannot.** What does a chest give you once you
own everything in it? Per-chest shards strand themselves: finish Piggy Classics
and its duplicates become currency for a shop with nothing left to sell. Held
globally, a duplicate out of a finished collection is fuel for one barely
started, so no open is ever wasted and a completed chest keeps paying.

**MEDALS ARE NOT REPLACED BY ANY OF THIS.** Every set item still carries its
medal price, so the guaranteed route survives beside the gamble -- which is the
rule that says NOTHING IS EVER LOCKED BEHIND LUCK. Medals buy the item you
want; the Alien Cache is the gamble that might save you the wait. Two routes
out of one event, and bad luck still only ever costs time.

**A TIER WITH ODDS AND NO STOCK IS RENORMALISED, NEVER RE-ROLLED.** An event
pool has no commons at all and a half-built bucket may have no legendary yet,
so `ChestService.liveOdds` drops empty tiers and rescales what is left. The
alternative is either handing back nothing or looping until the dice cooperate,
and both are worse. It also means the percentages the reel prints have to come
from that same function -- computing them from `Config.CHESTS.odds` directly
would show a player numbers the server did not use.

**THE CHARGE HAPPENS AFTER THE OUTCOME EXISTS.** The tier is rolled and the item
is picked BEFORE a single coin moves, so a chest can never take the money and
then discover it had nothing to hand over. That is the one failure mode here
that would read as theft rather than as bad luck.

**`ChestService` LEANS ON `SetService.owns` AND `.grant` RATHER THAN WRITING A
SECOND GRANT PATH.** Those already resolve all five catalogues through
`Config.catalogueFor` and push whichever service renders the thing, and
SetService requires DataService and nothing else -- so there is no cycle. A
chest granting a ride, a decoration, an effect, a skin and an accessory through
its own copy of that logic is exactly the near-identical second copy this file
keeps recording as the thing that drifts.

**A SET CHEST'S POOL ENTRIES ARE `kind:key`, EVERYTHING ELSE'S ARE BARE KEYS.**
A set spans five catalogues, so a bare key does not say which table to grant
from. `splitEntry` is the one place that knows that grammar -- the same lesson
`RideSound` learned by keeping a second copy of the ride-key grammar and
breaking within the hour.

**THE ODDS GET PRINTED ANYWAY, THOUGH NOTHING NOW REQUIRES IT.** The event drop
reel already shows real percentages and this file already argues why -- *"printing
the number is what makes it honest rather than merely true"*. Being outside the
regulation is not a reason to stop; it is the reason it costs nothing to comply
with the spirit of it.

**IT IS `data.tokens`, AND THE NAME IS A PLACEHOLDER ON PURPOSE.** What the
currency is finally called has not been decided; what it IS has been.
Everything player-facing reads `Config.ROLL_CURRENCY`, so a rename is that one
table. The SAVE FIELD is hardcoded, exactly as `data.vault` stays `vault` while
the HUD says PIGGY BANK -- routing every read through a Config string would buy
a rename nobody needs and cost the type checker, every grep, and the ability to
see at a glance who spends it. Renaming the field is a schema migration and
should have to look like one.

**BOTH SOURCES ARE ATTENDANCE, AND A THIRD HAS TO CLEAR THE SAME BAR.** The
daily ladder pays 17 a week, published per rung on the board; an event pays 1
for being there when it resolves plus 1 more if the street cleared it. Neither
can be hurried with coins.

Note what that property is FOR now that coins are not sellable: it is no longer
doing legal work, it is doing pacing work. Tokens buy event-themed loot, and
the point of them is that a rich player cannot skip an event -- attendance is
the only route. The legal question is settled one level up, by coins never
being purchasable at all.

**A CURRENCY WITH NO VISIBLE SOURCE IS A BROKEN FEATURE, so this one is loud at
both ends.** The refusal names the shortfall AND where tokens come from, and
the roll note says it again -- because this is the only price in the shop that
more coins cannot meet, and every other price on that screen has trained the
player to go and earn some. Measured live: *"Need 2 more tokens. Claim your
daily reward or join a street event."* The daily board carries a purple `+N`
pip on every card and one line under the row naming what the pips are, since
that board is where a nine-year-old meets this currency before they meet the
thing it buys.

**EVENT TOKENS ARE GRANTED SILENTLY AND NAMED IN THE MEDAL LINE.** A raid
already fires an income toast, a medal toast and a drop reel; a fourth card
announcing two tokens is where a reward turns into noise. So
`CosmeticsService.awardTokens` takes an OPTIONAL `why` and nil means silent,
and EventService folds the count into the string it passes to
`SetService.award` -- one card naming both currencies. The daily claim does the
same thing from the other end by appending to its own message. Nothing is ever
granted with nothing on screen; the caller owns the wording, not the choice of
whether to speak.

**EVENT TOKENS DELIBERATELY DO NOT PAY PER DRONE, which is the one place
`Config.TOKENS` differs in shape from `Config.MEDALS`.** Medals already reward
knocking drones down. If tokens did too, a raid that happened to spawn ten
would pay several rolls at once, and the pacing of the whole collection would
come from how many drones a random event chose rather than from how often
somebody turns up.

**THE PRICE LADDER IS SMALL INTEGERS BECAUSE THE CURRENCY ARRIVES IN ONES AND
TWOS.** 2, 2, 3, 3, 4, 6, 7, 9, 11, 14, 18, 23 -- 102 tokens for the twelve,
against roughly 37 a week from both sources, so about three weeks: slower than
either upgrade tree, faster than a stack of rebirths, and paced by ATTENDANCE
rather than by whoever has the deepest vault. That was always the intent of the
old coin ladder and it was never true of it -- a player sitting on ten million
coins cleared the pool in one sitting. Verified live, price and charge equal on
every roll: 2, 2, 3, 3, 4, 6 taking a balance of 25 down to 5, then a refusal
at 7 that did NOT spend, repeated seven times.

**THE ROLL'S OWN COUNT WAS WRONG, AND MOVING CURRENCY IS WHAT SURFACED IT.**
`rollFrom` has always excluded `set` accessories -- they are earned at events
and bought with medals -- but the PRICE index and the "have you finished" test
both counted the whole of `Config.ACCESSORIES`. With two alien items in there
the collection could never read complete from rolling alone: a player who had
rolled all twelve was told 12 of 14, charged a thirteenth price, and then
refused with "Nothing left to roll." It ran the other way too -- buying an
alien hat with medals pushed the roll's price up a rung, so a MEDAL purchase
silently made rolling more expensive. `Config.rollableAccessoryCount` and a
set-aware `ownedCount` put both ends on the same pool: what a roll can actually
give you. Verified live at owned=12 total=12 with the button flipping to
COLLECTION COMPLETE.

**THE REBIRTH SKIN DROP IS THE REMAINING QUESTION AND IS DELIBERATELY LEFT
ALONE.** It is random, it is not purchased, and the gate in front of it is
banked COINS -- so once coins are sellable, money buys a faster route to a
random outcome even though it never buys the outcome. That is a weaker case
than the roll was and it is not obviously inside the rule, but it is the next
thing to look at before a pack ships, not after. Same for anything that ever
gates a random reward behind a coin cost.

**An accessory's pivot is its AUTHORED ORIGIN, never its visual centre.** This is
the placement contract, and breaking it broke almost every item at once. A hat
is authored with y=0 at its brim so it can sit ON a head; a shoe with y=0 at the
sole so it can stand on the lawn. Pivoting on the bounding-box centre instead
placed the middle of each shape at the anchor -- which dropped the top hat 1.65
studs and buried its brim two studs inside the skull. The shop icon wants the
other point and computes it for itself in `makeModelIcon`; a model cannot serve
both from one pivot, so it serves the one that has to be right in the world.

**The pig's own geometry is the spec accessories are cut against.** Eyeballs at
x = +/-2.35 and reaching z 5.53; the head's surface at eye height at z 5.62; the
tail a ball standing 1.37 studs proud of the back at y 9.7; the lawn at y 0.5.
Those four numbers decide where glasses, capes and shoes can physically go, and
every clipping bug so far has been one of them ignored -- lenses placed between
the eyes instead of over them, arms run lengthwise through the eyeballs, a cape
hung where the tail already is, wheels authored below the grass. A slot anchor
is the shared attachment point; an item's `offset` in Config is its own nudge
off it, because one anchor cannot suit a cape that hugs the back and a jetpack
that stands off it.

**Nothing the game owns may stand in an accessory anchor.** The four anchors
are the player's, permanently: whatever they roll has to be able to sit there.
The Vault Lock's padlock was built at (0, 15.2, 0), which IS the hat anchor at
14.15 plus a stud, so every hat in the game spawned inside it and neither could
be seen. It was not a tuning problem and no offset would have fixed it. The
lock is a vault dial on the front flank now -- the only patch of the body that
is both empty and turned towards someone walking in from the street, since the
top is the hat, the front is the snout and the eyes, the back is the cape and
the tail, and the underside is the four legs. Its clearances are measured in
`DIAL_MAX_R`: grow the plate past 1.95 and its top edge reaches the eyeballs.

**THE VAULT IS A HATCH IN THE BACK, BELOW THE TAIL, AND LEVEL 0 IS AN OPEN
HOLE.** Three placements were tried and the first two were both wrong in the
same way: 45 degrees round from dead front is the CHEEK, not the flank -- on a
sphere whose whole front is snout and eyes, the dial landed beside the face at
snout height and the piggy read as having a wheel growing out of its jaw --
and 72 degrees fixed that but still read as hardware bolted to the side of an
animal. A hatch in the back of a piggy bank is a thing that already exists in
the world, which is why it is the one that looks right.

MEASURED AGAINST WHAT IS ALREADY BACK THERE. The tail spans local y 0.35 to
2.05 and the legs top out at -4.59, leaving about five studs. At local y -1.9
the largest plate spans -3.85 to 0.05: clear of the tail by 0.30 and the legs
by 0.74.

**LEVEL 0 SHOWS THE HOLE, NOT NOTHING.** An unlocked piggy used to hide the
dial entirely, which reads as "this piggy has no vault" rather than "this
piggy is not locked" -- and the second is what a thief at the gate is actually
deciding on. The opening is built once at full size and never resized, so
every tier is the same hole with a different door over it.

**THE RIM IS A RING OF SEGMENTS, and it took two goes to get there.** One
cylinder cannot be an annulus, so the first version put a solid disc in FRONT
of the hole and covered the whole opening with a pale lid. The second rotated
each segment by -a, which maps its long axis onto the RADIUS -- twelve spikes
sticking out of the pig like a sunburst. A segment sits at (sin a, cos a) * r
in the seat's YZ plane, so its tangent is (cos a, -sin a) and the turn is
`-a - pi/2`; verified at |radial . longAxis| = 0.000 across all twelve.

The lip exists because nothing here can be DUG. A recess is made by standing
something PROUD around the dark, never by sinking the dark -- the eye takes
the highest line as the surface. Exactly the moat's kerbs at a twentieth of
the scale.

**IT SITS UNDER THE CAPE, AND THAT IS ACCEPTED RATHER THAN MISSED.** The back
accessory anchor is directly above and a Hero Cape hangs to local y -1.77, so
a caped piggy hides the top of its own vault. This is the REVERSE of the
padlock bug recorded below: there the game's part swallowed the player's hat
and ruined something they had rolled for. Here the player's own cape covers
the game's tell, on a piggy they chose to put a cape on -- their purchase is
intact and what they lose is advertising their own lock.

The cost is real and worth stating plainly: a thief walks up from the STREET
and sees the face, so the metal tier no longer carries from out there. What
it buys instead is that an unlocked vault is now a visible hole, which is the
signal that actually changes a mind at the gate.

**A defence upgrade has to be visible from outside the fence, and legible at
the piggy.** A ProximityPrompt draws the same filling circle whether the hold
is three seconds or nine, so without a body on it the whole Vault Lock tree was
invisible to both sides -- the defender could not see what they had bought and
the thief could not see what they were up against. The dial ramps two things
because they land at different distances: the metal (iron, bronze, steel, gold)
carries from the street, where a thief decides whether to come in at all, and
the spoke count (2 to 5) only resolves up close, where they are deciding
whether to commit to the hold. Neither needs counting -- a 2-spoke wheel is a
bar handle and a 5-spoke one is a bank vault.

**The daily ladder is FIXED AND PUBLISHED, and that is the wall, not a
presentation choice.** Seven days, repeating, every rung readable from day one.
The plan sells coins, so a random daily reward would be a random outcome
standing downstream of a coin purchase -- which is the one thing this economy
is not allowed to contain. Nothing about a claim is a surprise on purpose.

**A daily coin reward is denominated in SECONDS OF YOUR OWN INCOME, never a
flat number.** Five thousand coins is a gift on day one and an insult at three
thousand a second, and a ladder that stops mattering at exactly the point
players have the habit is worse than no ladder. Day 1 pays five minutes of
your current rate, day 7 pays thirty. The `floor` on each rung is the other
end of the same problem: a brand new player earning 10 a second would otherwise
get 3,000 coins for a week of turning up.

**Boosts are handed to a pocket, never applied on claim.** The vault caps at
capacity, so a 2x boost given to somebody sitting on a full vault is worth
exactly nothing -- and that is precisely the player most likely to be logging
in to collect a daily. Holding it makes the reward keep its value and turns
"bank first, then boost" into a small real decision. It multiplies the live
drip only and never offline accrual: a boost is for playing, and one that ticks
while you are logged off is just a worse coin reward with extra steps.

**One missed day is forgiven; two ends the streak.** A hard reset is the right
rule for an audience that can choose to be here every day. This one cannot --
they are nine, and Tuesday is not their decision. Losing a thirty-day streak to
a school trip teaches them the feature is a trap, and a player who feels
trapped stops opening the game at all.

**Days are UTC day INDICES, never timestamps and never `os.date`.** The only
question ever asked is which day it was, so the save stores the day itself and
no clock, timezone or daylight saving can get between it and the answer. Two
servers in different regions would otherwise disagree about what day it is.

**A roll can only return something you do not already own.** The pool is rebuilt
from the unowned set every time, so duplicates are impossible, every roll is
progress, and the collection always completes. That makes it a guaranteed ladder
wearing the clothes of a gamble -- which is the only honest shape for this
audience. It also means there is no pity timer to tune and no duplicate-currency
to invent: those exist to paper over a problem this design does not have.

**Animated skins are driven on the CLIENT.** The server publishes a `SkinKey`
attribute and nothing else; each client computes colours itself in one shared
Heartbeat loop. Animating server-side would replicate a colour write per piggy
per frame — around 700 property updates a second across twelve plots — to say
something every machine could derive from a single string.

**The dodge somersault is an ANIMATION, and that is the only thing that
works.** Two cheaper mechanisms were measured against a real character and both
are dead ends. Rotating the root joint's C0 — the usual way to spin a body
without touching physics — is impossible here: this rig joins parts with
`AnimationConstraint`, not `Motor6D`, and its `C0` is READ ONLY. Rotating
`HumanoidRootPart` directly drops the Humanoid into `FallingDown` within a
frame and it does not get back up — measured still on its side a second and a
half later, ten studs from where it started. In a chase. The state machine owns
that orientation and will not share it. The animation system is the one thing
allowed to drive those joints.

**The roll animates the body and NEVER the root.** Every pose is relative to
`HumanoidRootPart` and the root's own pose stays at identity, so there is no
root motion — measured at 0.00 studs travelled across a whole roll.
`Config.DODGE` is explicit that a dodge is a multiplier on currentSpeed and
never an impulse or a nudge, because `BASE_WALK_SPEED` is what the carry
penalty, the dog speeds, the fence snags and the getaway are all measured
against. A roll that shifted the character even slightly would be exactly the
second, parallel way to move that rule exists to prevent. Lifting the LowerTorso
pose is fine and does not count: that is the body leaving the ground, not the
character — and without it the head swings 3.66 studs below the root, which is
through the grass.

**The dash is a DIRECTION, not an impulse — and it has to be written after
the control module.** Being a pure multiplier meant a player standing still
dodged at 2.5x of nothing and went nowhere, so the client now drives the
humanoid's own move direction for the length of the window: whatever is
being held, or the character's facing when nothing is. Still the same
multiplier, still inside the one movement system every other speed here is
expressed in, so a fence stops it dead — measured, a dodge into a piggy
bank 1.5 studs away travels 3.81 studs against 9.76 on open ground.

The frame stage is the trap. The default controls write a move direction
every RenderStepped, and whoever writes last before the physics step wins.
Heartbeat is AFTER physics, so a dash driven there is overwritten by an
empty input every frame — measured at 0.51 studs from a standing start,
which looks exactly like the bug it was meant to fix. Bind above the
control module (`RenderPriority.Character + 1`) or lose the frame.

**`RegisterKeyframeSequence` IS STUDIO-ONLY, AND IT TOOK EVERY ANIMATION IN
THE GAME DOWN IN PRODUCTION WHILE PASSING EVERY TEST IN STUDIO.** The paragraph
below describes why the roll is generated rather than uploaded, and the
reasoning still stands. What it got wrong is that the id that call hands back
is TEMPORARY AND LOCAL TO STUDIO: live, the call is refused. The dodge and all
nine rider poses were dead on the published site -- the dodge still moved you
at the right speed and a ride still carried you, so nothing crashed and nothing
in the log said a word.

Both readers already pcalled and warned, which is what made it survivable and
also what made it invisible: a warning on a client nobody is reading is not a
report. **THE FAILURE SHAPE IS THE LESSON** -- this is the same class as the
`RenderFidelity` incident recorded above. An API that works in Studio and is
refused live cannot be caught by any amount of testing in Studio, because
Studio is the thing that is different. Anything capability-gated or
Studio-gated needs a live check or a fallback, not a test.

**SO EVERY ANIMATION IS AN UPLOADED ASSET NOW, WITH REGISTRATION AS THE
FALLBACK.** `Config.ANIMATIONS` maps a key to an id, `Config.animationId`
returns nil for an empty row, and both readers try that first. An empty row
behaves exactly as before, so Studio development is untouched and the ids can
be filled in one at a time -- each animation starts working the moment its row
lands. `Config.animationKeys()` derives the list from the ride catalogue rather
than repeating it, so a new ride with a trick appears in the dump and in the
warning without anybody remembering to add it.

**AND `Main` WARNS AT STARTUP ON A LIVE SERVER, naming every animation with no
id.** Gated on `not RunService:IsStudio()`, so it is silent where it would be
noise and loud in the one place the gap actually exists. Same shape and same
reason as PassService's unset game-pass warning: the whole cost of this bug was
that nothing said anything.

**THE `animdump` COMMAND BUILDS THE SEQUENCES FOR UPLOADING, AND USES THE SAME
FUNCTIONS THE GAME PLAYS.** `DodgeRoll.buildSequence` and
`RidePose.buildSequenceFor` are exported for it, so what gets published is
exactly what Studio has been showing -- building them a second way for the
uploader would be the near-identical copy that drifts.

**THE ANIMATION EDITOR IS CALLED THE CLIP EDITOR NOW, and Rig Builder is called
Character.** Both live on the Avatar tab. It loads clips from an `AnimSaves`
model inside a rig and, on first sight of one, offers to MIGRATE them to
`ServerStorage.RBX_ANIMSAVES.<rig name>` -- which is where they live afterwards,
keyed by the RIG'S NAME. Keep a rig with that name or the association is lost.

**A RIG FOR THE EDITOR MUST BE UNANCHORED, AND THAT IS HOW AN NPC ENDED UP
WANDERING THE MAP.** The editor drives joints, so it refuses an anchored rig
with "Select a rig to animate" -- which reads as the rig being unrecognised
rather than as anchoring. Unanchoring it fixed the editor and put a live
Humanoid in `workspace`, in the PLACE FILE, where Rojo does not reach: it then
turned up in every Play session as a stray character. Exactly the `GearPreview`
trap this file already records, created fresh while fixing something else.

It lives in `ServerStorage` between uses now, which does not replicate. **The
rule is the one already written down: anything staged in the DataModel gets
cleaned up, and `workspace` in Edit is Camera and Terrain and nothing else** --
this whole world is built at run time, so anything sitting there in Edit is
debris by definition.

**TWO POSES ARE BYTE-IDENTICAL AND SHARE ONE UPLOAD.** `hoverdisc` aliases
`hoverboard` in `POSES`, so fingerprinting the ten sequences collapses them to
nine. Worth re-checking before any future upload round: the pool is small and
an alias is cheap to miss.

**The roll is built in code, not uploaded.**
`KeyframeSequenceProvider:RegisterKeyframeSequence` takes a sequence assembled
at runtime and returns a `hash://` id an Animator will play, so the animation is
generated the way the ground and the piggies are, and there is no asset to be
moderated away. The catch: a hash id is local to the peer that registered it and
CANNOT replicate, so the server publishes a `DodgeRoll` counter on the character
and every client plays the roll itself — the same shape as animated skins. A
counter rather than a flag, because a boolean set true twice fires one signal.
Intermediate keyframes are load-bearing as well: rotation interpolates the short
way round, so a lone keyframe at -360 is identical to one at 0 and the character
does nothing at all.

**THE PAGE THAT EXPLAINS A REBIRTH COMES BEFORE IT, NEVER AFTER.** "Here is
what you kept and what you lost" shown once the button has been pressed is a
RECEIPT: every line on it is already true and there is nothing left to decide,
which for a nine-year-old who did not understand what they pressed is the
worst possible moment to explain it. The same two columns shown FIRST are a
decision, with a way out at the bottom. That is also why the way out is
labelled NOT YET rather than CANCEL -- nothing is being undone, they are
deciding whether they are ready.

**IT ASKS ON THE FIRST REBIRTH ONLY, and the flag is `rebirths == 0` rather
than a saved boolean.** The question the page answers is "what does this button
do", which is asked once; a veteran on their ninth reset who has to clear a
dialogue every time learns to tap through it without reading, and the
confirmation everybody dismisses reflexively is the one that fails when it
finally matters. Reusing the rebirth count means no new save field and no way
for a flag to disagree with reality. `Rebirth.FIRST_TIME_ONLY` is the one line
to change if it should ever ask every time.

**THE NUMBERS ON IT ARE REAL, and that is the whole feature.** "You will lose
your upgrades" is a definition; "Vault Lock Lv 3, Fence Lv 4, Guard Dog Lv 2,
Lockpicks Lv 4" is somebody's actual afternoon, and the difference decides
whether a player understands the trade or merely reads about it. Everything
comes off the pushes the HUD is already drawing, so nothing is computed twice.
Only levels ABOVE ZERO are listed as losses -- an upgrade never bought is not a
loss, and padding the scary column would overstate the cost of the one decision
this economy most needs players to make. The losses are listed in the SHOP'S
order, defence tree then offence: sorting by table key instead came out boots,
dog, lockpicks, locks, sack, which is alphabetical order over names the player
has never seen.

**THE COSMETIC PAYLOAD'S `houses` IS KEYED BY POSITION, NOT BY LEVEL.** It is
built with `ipairs` so the keys are 1-based numbers, while `houseLevel` and
`houseShown` are 0-based -- `owned = (i - 1) <= level`. So `houses[houseShown]`
is wrong twice over and `houses[tostring(houseShown)]` is wrong three times.
Ask which entry has `current == true`; it is on there for exactly this reason.

**REBIRTH RAISES THE CEILING, NOT JUST THE RATE, and before it did this game
got SHORTER the more you prestiged.** `MAX_INCOME_LEVEL` and
`MAX_CAPACITY_LEVEL` were constants at 20, so a rebirth multiplied your income
against a catalogue that had not grown -- the reward for resetting was reaching
the end sooner. Measured before the change: 19.8 hours to own everything at
rebirth 0 and **7.9 hours at rebirth 6**. The one mechanic built to extend play
was the one accelerating the ending.

`Config.maxLevel(rebirths)` is `20 + 2 per rebirth` capped at 40, so every
rebirth opens two levels that COULD NOT BE BOUGHT BEFORE AT ANY PRICE. Read the
cap through that function and never from a constant: `EconomyService` pushes its
answer as `maxIncome`/`maxCapacity` and the client draws the ladder from those,
so both ends agree by construction.

**THE LADDER IS TWO CURVES AND THE SEAM MUST BE ONE CLEAN STEP.** Levels 1-20
keep the original growth untouched -- that curve was never the problem. Levels
21-40 are gentler on both sides (income 1.16, cost 1.26; capacity 1.19, cost
1.16), because one curve extended to 40 fails in both directions: at 1.35 income
the rate hits 121K/s and trivialises everything, and at 1.55 cost the top level
runs to 10.6B and nobody buys it. `banded()` writes both as "band A to the top,
then band B beyond" rather than branching between two formulas, so level 21 is
exactly level 20 times ONE band-B multiplier -- verified live at 1.1600 and
1.1900 with band A unchanged at 10/s, 3.0K/s and 3.0M.

Note costs are indexed by the level you are LEAVING, so they run one behind the
value tables; `getIncomeCost(20)` is the price of reaching 21 and is the first
band-B price. Getting that off by one is worth 250M of total content -- an
earlier model did exactly that and came out at 1.42B against the shipped 1.17B.

**THE REBIRTH GATE IS A MULTIPLE OF CAPACITY, because a flat gate cannot
survive an economy that grows and a geometric one cannot either.** It was a
flat 1,000,000: measured, 334 seconds of income the first time you cap the
ladder and **eight seconds by rebirth 10**. It vanished exactly as the decision
it guards got serious. The obvious fix is worse -- a geometric gate compounds
faster than income does (income rises about 1.35x per rebirth), so it diverges
and the gap becomes a wall: simulated, `1M * 3^rebirths` spends 60 days stuck at
gates and `1M * 5^rebirths` never finishes at all.

Capacity is the one anchor that can do neither, because it rides the same curve
the player's own economy rides. `2x` costs three tenths of a week and buys about
a day of deliberate banking before each reset. It is also the only version a
nine-year-old can read -- *fill your piggy bank twice over*, on the bar they are
already watching -- and `canRebirth` tests banked `coins`, so that is literally
the action. Measured against the CEILING they can reach rather than the capacity
they happen to have bought, so the gate cannot be lowered by declining to
upgrade.

**AND `REBIRTH_MULTIPLIER` HAD TO COME DOWN THE SAME DAY, because the two
levers multiply each other.** At 0.25 against a 40-level ladder the top rate is
204K/s, which earns the entire content of the game in about two hours; at 0.12
it settles at 93K/s and the ceiling does the work. The multiplier is the small
half of prestige now and the unlocked levels are the large half, which is the
way round that keeps rebirthing worth doing at rebirth 9. Verified end to end
against the live server: ceiling 20 to 40 across ten rebirths, gate 6.0M to
193.8M, L40 at 58.3K/s base and 128.2K/s at rebirth 10, and a day-by-day
simulation driven by the real Config functions landing at **8.9 weeks** to own
everything at 2h/day (13.0 casual, 6.7 heavy) with rebirths falling every four
to six days.

**Every rebirth grants a skin.** The roll decides how rare, never whether.
Rebirth already costs a player every upgrade they own; handing back nothing is
the fastest way to stop people doing it. A legendary is reachable on the first
rebirth (~2.7%) rising to ~31%, with a pity floor at 12. Drop-pool skins have no
`cost`, so `isSkinUnlocked` checks `rarity` before the free-if-costless fallback
— without that, every legendary would unlock for everyone immediately.

**EIGHT PLAYERS, FOUR A SIDE, AND THE MAP WAS CUT TO FIT THEM.** It was
twelve and six a side. Measured before the cut: the far corner of one row to
the far corner of the other was 336 studs -- TWENTY-ONE SECONDS of holding W --
to buy a getaway that is 27 studs and lasts two. A ten-to-one ratio of travel
to game, and the walk to the plaza was worse at 370.

**PERFORMANCE WAS NEVER THE REASON, AND SAYING SO MATTERS.** The whole world
measured 1,891 BaseParts with 22 animated per frame, which for Roblox is
nothing -- plots were 84% of it at a median 99 parts each. Anybody cutting this
map for frames is cutting the wrong thing. What eight players saves is eight
characters and eight dogs of REPLICATION, and what it actually buys is the
lobby: a twelve-cap server sitting at six reads as abandoned and an eight-cap
at six reads as busy, and it fills in half the time.

**WHAT IT COSTS IS RIDES, and that is the argument that set the number.** The
walk between plots is the one thing a ride is sold against -- this file already
says the walk "was the one part of this game that was pure holding W" -- so a
shorter street is a smaller saving on a purchase that runs to 4.5M coins. Four
a side rather than three is where that stopped.

**`PLOT_COUNT` IS DERIVED FROM `PLOTS_PER_ROW`, and it was not.** They were two
independent constants, and `plotCFrame` puts row 0 at -z and EVERYTHING ELSE at
+z -- so setting the per-row count to 4 and leaving the total at 12 would have
built plots 9..12 silently on top of 5..8, in the same place, with nothing in
the log to say so. `PLOTS_PER_ROW` also has to be EVEN, because that is what
gives the slot grid a true middle to leave empty.

**A ROW IS CONTINUOUS, AND THE HOLE IN THE MIDDLE OF IT LASTED ONE PASS.**
There was an empty PLOT_SPACING slot in each row with the town square sitting
in it. It worked, every clearance measured, and it read as a MISSING TOOTH:
sixty-four studs of nothing between two houses is not a gap, it is an absence,
and it was the widest thing on the street. The 16-stud alley between
neighbours is a gap; a whole missing frontage is not.

**SO THE SQUARE MOVED SIDEWAYS INSTEAD OF ALONG THE STREET.** Everything it
held -- two boards, four shops -- now stands on the VERGE, the band between
the kerb and the front fences, which runs the whole length of the street. That
is the difference that matters: there is somewhere to put things without
taking a house out of the row to do it.

**`STREET_SPACING` WENT 104 -> 144, AND NOT 208, WHICH WAS THE ASK.** The
widening is what makes the verge buildable at all -- 18.4 studs is a driveway
and nothing else; 38.4 is a pavement with lamp posts and bins on it and
buildings set back behind them. But doubling costs the one number that must
not grow. Measured, with the row's gap closed up:

      spacing   verge band   cross-street carry   worst steal
         104       18.4            8.7s           218 / 18.2s
         144       38.4           12.0s           240 / 20.0s
         208       70.4           17.3s           283 / 23.6s

This constant's whole job is that across the road is A CHOICE rather than
NEVER, and at 208 a cross-street robbery is 17.3 seconds of carrying at 12
against an alerted Titan doing 17. Nobody does it, and half the server stops
being a target. It would also have landed the map LONGER than the one all of
this set out to shrink. 144 doubles the buildable band and still comes in
shorter than the twelve-plot map.

**ROAD_HALF_WIDTH BEING PINNED IS WHAT MAKES THAT SAFE.** All of the widening
lands on the verge and none on the tarmac -- which is the whole reason that
constant is not derived from this one, and it is now doing that job for real
rather than in principle.

**WHERE THINGS STAND ON THE VERGE IS DERIVED, AND IT WAS NOT.** `boardZ` and
`shopZ` live in `streetMetrics` so widening the street moves everything that
sits on it. The board's own offset used to be a hardcoded 26 measured against
a TUNNEL BORE it no longer stands anywhere near, and it survived two moves by
luck. Boards go mid-verge, because a board reads from the carriageway and from
the pavement; shops go at the back of the band, behind the lamp posts and bins
that sit just off the kerb at 9.8.

**EVERYTHING ON THE VERGE GOES IN A GAP BETWEEN DRIVEWAYS.** A driveway is
`DRIVEWAY_WIDTH` on its own plot centre, so the clear gap between two of them
is `PLOT_SPACING - DRIVEWAY_WIDTH` -- the same stretch the lamp posts and
wheelie bins already use, and the one piece of ground out here that belongs to
no plot. Stated as the derivation rather than as a figure because both of those
constants have moved since: the gap was 51 studs at the old 64 spacing and is
67 at 80, so the 15.5-stud shop-to-driveway clearance measured back then is now
23.5 and would have gone on reading as measured.

**MEASURE A SHOP AGAINST THE FENCE'S CLIMBZONE, NOT THE FENCE LINE.**
`shopZ = fenceLine - 12` put the forecourt at |z| 42.1 against a ClimbZone
standing proud at 44.9 -- 2.8 studs. The derived fence LINE is 46.4 and would
have said 4.3. It is 14 back now, measured at 4.8, with ten studs of pavement
still between the forecourt and the kerb.

**AND THE DRIVEWAY DOUBLED FOR FREE.** `driveFar` is `streetHalf -
ROAD_HALF_WIDTH`, so widening the street lengthened every driveway from 18.4
to 38.4 with nothing to change -- which is what actually puts the houses back
off the street.

**FOUR SHOPS, ONE SHELL, AND THE FIRST VERSION WAS FOUR IDENTICAL BOXES.** A
shared shell with a different accent colour and a different word on the fascia
is a colour swatch rather than a shop: nothing about a box says what is inside
it, four in a row say it four times, and a player walking past learns nothing
they could not read off the panel. The shell stayed and everything else became
per-STYLE -- roof line, frontage, lighting, what stands in the window and what
stands on the pavement. A boutique with a pitched gable and a scalloped blind,
a glasshouse with an open front, a workshop with a roller bay and a quarter
pipe, a strongroom with a castellated parapet and barred glass. Four
silhouettes before a word is read.

**THE BRACKET SIGN IS A FIX, NOT A FLOURISH.** A fascia faces the ROAD and a
player approaches ALONG the road, so the one thing naming each shop was edge-on
from every direction anybody arrives from and legible only once you had already
stopped in front of it. A projecting sign hung square to the frontage is how a
real high street solves exactly that. Its panel is thin on X with its guis on
LEFT and RIGHT, because the street runs along X and those are the faces
pointing along it -- verified, four signs readable both ways, none one-sided.

**A BUILDER'S ANCHORING IS A FACT ABOUT WHERE IT WAS DESIGNED TO GO, AND A
DISPLAY CASE IS A THIRD PLACE THAT IS NEITHER.** `BoneModel` builds ANCHORED,
because a bone lies in the grass. `RideModel` and `PiggyModel` build UNANCHORED
and Massless, because both get welded to a character and an anchored part
welded to a humanoid pins the humanoid. Stood in a shop window with nothing to
weld to, they simply FELL: three of four displays vanished on the first build
and the only survivor was the bone, which is exactly the one that was already
anchored. `ShopFront` anchors whatever it is handed.

This is the EXACT INVERSE of the rule `HeldItem` records, where the same
builders had to have their anchors taken OFF to be welded into a hand. Neither
module may assume; both have to state what they need.

**AND THE TEST THAT MISSED IT READ THE MODEL IN THE FRAME IT WAS BUILT.**
Calling the three builders in isolation reported all three fine, because
nothing had fallen yet -- the same "verified at the endpoints is not verified"
failure the wheelie lean already records, in the time axis. Anything unanchored
gets sampled after a beat.

**A CHASE IS SAMPLED ACROSS A WHOLE CYCLE, NOT AT TWO POINTS IN IT.** One
bright band travels the run, so at any instant most bulbs sit at `Dim` and a
two-sample check reports them dead -- measured at "10 parts, 1 moved", which
looks exactly like a broken effect. Swept over a full 2-second cycle instead:
all nine bulbs swing 0.45 in brightness, so the band reaches every one.

**A REWRITE DROPS THINGS SILENTLY, AND THE PROMPT WAS ONE.** Rebuilding
`ShopFront` from the shell up lost the ProximityPrompt entirely -- no error,
the shops built, the doors were still tagged and still carried their tab
attribute, and nothing on screen said the one interactive thing on the street
had gone. It surfaced only because a probe indexed nil. When a file is
rewritten rather than edited, the check is the FEATURE LIST, not the diff.

****A SHOP UNIT'S FOOTPRINT IS ITS FORECOURT, NEVER ITS BUILDING.** The first
pass was 20 wide with a forecourt four studs wider than the walls, which
measured 24 across and left 0.4 studs to what it had to clear. The building
was never the number. It is 18 with a two-stud overhang now.

**`MaxPlayers` IS NOT CODE, AND IT WAS SILENTLY WRONG.** One plot per player is
a hard limit -- `Main` kicks anybody it cannot seat with "This server is full"
-- and the place was configured for SIXTY against twelve plots. Forty-eight
players out of sixty were being turned away, which is invisible in a solo test
and catastrophic in a live one. `default.project.json` owns it now via
`$properties` on the Players service, so a `rojo build` is correct; but it is
READ-ONLY from a script, so an existing place has to be changed by hand in
File -> Game Settings -> World -> Max Player Count. Keep it equal to
`Config.PLOT_COUNT`. This is the same class as the `GearPreview` folder: state
that lives in the place rather than in `src/`, where nothing reconciles it.

****The yard is a rectangle; only its FRONT line is load-bearing.** The fence runs
`YARD_DEPTH` back from the plot centre to enclose the house, but the front stays
at `PLOT_SIZE.X/2 + 1.6` because a thief approaches from the street. Lengthening
the yard behind the piggy changes nothing about the steal, the getaway or the
drop-off, which is what makes it cheap.

**THE STONE TRIM RINGS THE WHOLE YARD, HOUSE INCLUDED.** It was
`PLOT_SIZE + 4` -- a 52-stud square centred on the piggy -- so it stopped dead
at the back of the front lawn and a plot read as a bordered garden with an
unbordered field of grass stuck on the back of it. The border is the thing
that says where one property ends and the next begins, so it has to run the
length of the thing it borders: from the pavement to two studs behind the back
fence, which is the same rectangle `buildFence` encloses.

**The yard grass is the same width as the lawn, and that is what keeps the
border a constant width.** At 51.2 -- the full fence interior -- the grass grew
1.6 studs wider at the seam behind the piggy while the trim stayed at 52, so
the visible stone shrank from 2 studs to 0.4 at exactly that line and read as
the border running out. The strip between the grass and the fence is stone
now, along the whole length, exactly as it already was along the front.

**A plot part may be resized freely because the model's `PrimaryPart` is the
Base.** Everything in `buildPlot` is authored around `origin` and the whole
model is turned by one `PivotTo` at the end, so a part whose bounds change
would move the pivot -- and the plot with it -- if the pivot were the bounding
box. It is not. Verified after the trim grew 46 studs: both rows still centred
at z -52 and +52 to the stud.

**Anything positioned relative to the yard must measure from `YARD_DEPTH`, not
from the plot slab.** They were the same number until the fence was lengthened
to enclose the house, and everything anchored to the old edge went silently
wrong rather than erroring. The grove behind the plots was placed at
`rowZ + halfPlot` (24) instead of `rowZ + YARD_DEPTH` (70), which dropped the
first row of trees 46 studs inside the fence — full-grown trees standing on
people's lawns among their houses. When a derived constant stops being derived,
grep for everything that assumed it.

**A HOUSE IS SEATED BY ITS FRONT WALL, NEVER ITS BACK.** Those sound
equivalent and are not. Depth varies by 41 studs across the nine tiers, so
pinning the back threw every bit of that variation FORWARD onto the lawn:
measured, the Sky Castle's front reached z -8.2 and stood on three decoration
slots, while the Marble Palace and the Midnight Modern each covered one. A
player who bought the best house in the game lost three ornaments to it.

Pinning the front fixes both halves at once. Every tier begins the same
distance behind the piggy -- which is the view that matters, since a house is
looked at from the street -- and no house can reach a slot at any tier, by
construction rather than by nine separate checks. Verified: all nine fronts on
z -28.0 with a spread of 0.000, all clear of the ornaments, and the deepest
still 5.2 studs off the back fence.

`Config.HOUSE_FRONT_LINE` is DERIVED: the rearmost lawn slot is lawnF at -19,
and the deepest ornament standing in it reaches -24.5, so 28 clears the
furthest an ornament can stick out by 3.5. Add a deeper ornament and that is
the number to re-derive.

**`YARD_DEPTH` is 90 because the deepest house needs it, and lengthening the
yard is the cheap lever.** Only the yard's FRONT line is load-bearing -- the
steal, the getaway and the drop-off all measure from there -- so the back can
move to fit the buildings. It went 70 -> 90 when houses were front-pinned
(28 + 56.8 for the Sky Castle + 5 of clearance). Everything followed on its
own: the fence, the stone trim, the yard grass and the grove behind the plots
all derive from it rather than keeping a copy.

**THE SKY CASTLE WAS NEVER TOO WIDE, AND THIS ENTRY USED TO SAY IT WAS.** For
a long time it read: *"still 16.6 studs too wide... 8.3 studs through the side
fence on each side... NOT fixed."* That was measured off
`Model:GetBoundingBox`, and the bounding box of a house includes its HouseFX --
so what it actually measured was the castle's ORBITING SHARDS, which sit at
x 30.9 and **y 67**, sixty-seven studs in the air, where no fence has ever
been.

Measured again with the tagged FX parts excluded, the castle's STRUCTURE --
keep, gatehouse, four turrets and their caps -- spans -24.31 to 23.69: **48.0
studs**, comfortably inside even the old 51.2 interior. Every one of the nine
tiers fitted, and always had; the widest building in the game is the Marble
Palace at 49.0.

**MEASURE A BUILDING BY ITS PARTS, NOT BY ITS MODEL.** A bounding box is the
extent of everything parented under a Model, and this project deliberately
parents animated decoration into houses -- halos, orbiting shards, crown
segments. Anything asking "does this fit the plot" has to walk the BaseParts
and skip the `HouseFX` tag, or it is measuring a light show.

**WHAT WAS REAL is that the catalogue had run out of room.** At the old 51.2
interior the Marble Palace's 49.0 left **2.2 studs** of headroom, so the next
wide house tier had nowhere to go -- which is a genuine ceiling, just not the
one recorded here. At a 67.2 interior it is 18.2. That is what widening the
plot actually bought, and it is worth being exact about it, because for months
this file justified a decision with a number that was measuring the sky.

**`Model:GetBoundingBox` IS ORIENTED BY THE MODEL'S PIVOT, SO IT TRANSPOSES
EXTENTS -- AND IT HAS NOW COST TWO SEPARATE DECISIONS.** A Model with no
PrimaryPart takes its pivot from whatever part the builder happened to create
FIRST. If that part is an upright cylinder -- and `cylinderY` rolls one 90
degrees about Z -- the box comes back in a rotated frame with width and height
swapped. It does not error, it does not look wrong, and the number is exactly
plausible.

Measured across the eighteen lawn ornaments, **six report transposed
dimensions**: the Wacky Waving Man, the trampoline, Brace Face, the trophy,
the crashed drone and Loo Guy.

What it cost, twice in one session: the Sky Castle's long-recorded "16.6 studs
too wide" was its FX at altitude, and the "widest lawn ornament is the Wacky
Waving Man at 21.08" -- which this file has stated for months and which the
entire slot grid was derived from -- is the tube man's **HEIGHT**. It is 9.03
studs wide. The real widest ornament is the Shark In Trainers at 13.70.

**MEASURE A MODEL PER PART, IN WORLD SPACE.** Walk the BaseParts and project
each one's own size through its own CFrame:

    halfX = |cf.RightVector.X| * sx/2 + |cf.UpVector.X| * sy/2 + |cf.LookVector.X| * sz/2

That is what caught both. A bounding box is a convenience for things you
already know are axis-aligned, and almost nothing built in this repo is.

**A TAG ADDED TO AN INSTANCE OUTSIDE THE DATAMODEL DOES NOT FIRE
`GetInstanceAddedSignal`, and this is a trap every builder in this repo walks
into.** `Decor.build` creates its Model DETACHED, runs every builder into it,
and parents it at the very end -- so a part tagged inside a builder is tagged
while it is nowhere. `CollectionService:GetTagged` finds it afterwards, because
by then it IS in the world; the added-signal never fired at all.

Measured on the trampoline: the mat was tagged, `GetTagged` returned it,
`Touched` fired fifteen times, and the handler had never been connected. No
error, no warning, nothing in the log.

The moat looked like a precedent for doing it by signal and is not: it parents
each band to `plot.fence` as it builds, and that folder is already in the
world. **Anything tagged inside a detached model has to be bound after it
lands** -- `PlotService.setDecor` walks the model it just parented, which also
covers the rebuild that happens every time an owner buys or shelves an
ornament.

**A SERVER-SIDE WRITE TO `AssemblyLinearVelocity` ON A PLAYER'S CHARACTER IS
DISCARDED, because the client owns its own physics.** Tested three ways on a
live rig -- a raw write, a write after `ChangeState(Jumping)`, and one after
`ChangeState(Freefall)` -- and the character reached exactly its 5.00-stud drop
height on all three. So the trampoline's server side decides (which mat, which
player, the cooldown, the veto) and fires a remote carrying NOTHING; the client
applies the velocity. Same split as the dodge.

The wheelie bin's exit hop gets away with a server write and is not a
counter-example: it happens in the frame the root is unanchored, which is the
one moment the server has authority over that assembly.

**A TRAMPOLINE IS THE FIRST DECORATION THAT DOES ANYTHING, AND THE VETO IS WHAT
KEEPS THAT SAFE.** The rule it has to clear is that a cosmetic never changes an
OUTCOME -- not the steal, the chase, the tag or the getaway. Three things
enforce it rather than argue it:

  * **The mat is a TRIGGER, not a surface.** Everything in `Decor` is
    CanCollide and CanQuery off because it sits on the ground a defender
    defends and a thief runs across. `Touched` fires on overlap without
    collision, so that rule is untouched and a trampoline can never body-block
    or be used as cover.
  * **It is vertical only.** The horizontal components are read back and
    written straight through -- measured at **0.00 studs of drift** across a
    bounce. Height is not a fence bypass either: the ClimbZone snag spans y 5.5
    to 10.5 and catches a climber on the way UP whatever their apex, which is
    the measured reason spring shoes were dropped rather than tuned.
  * **Anyone mid-heist is refused.** `PlotService.registerBounceVeto` is filled
    in by `Main` with `HeistService.isCarrying`, the same registry shape
    `SetService.registerPusher` uses and for the same reason -- HeistService
    already requires PlotService, so asking directly is a cycle.

Measured: 10.1 studs of bounce above the mat, repeatable, zero drift.

**THE LAWN IS A CANDY GARDEN NOW, NOT A MEME SHELF, and two of the three
reasons are not about taste.** Nine of the fourteen lawn ornaments were
internet jokes, which is the genre every other stealing game on the platform is
already in. **A meme has a shelf life and a shape does not** -- a reference from
two years ago reads as dated rather than funny, while a gummy bear needs no
one to get it. And **it takes the IP exposure to zero**: this file carries
several paragraphs about building meme ornaments as ORIGINALS because the real
ones are property, moderation strips branded assets, and the penalty lands on
the EXPERIENCE -- the Brace Face note even records live litigation over that
exact class of character. Slime, jelly and gummy are unownable.

**The meme ornaments STAY.** They are built, priced and already on lawns, and
with nine curated slots a mixed garden is the point. This is what gets added.

**THE VERGE DECORATION SLOTS WERE UNDERWATER, and the comment above them said
the opposite.** It read *"the ONLY ground out there that stays dry at every
fence tier"*; measured on a live tier-5 fence, both sat inside a MoatWater
band. The dry causeway is `max(gate, DRIVEWAY_WIDTH + 1)` -- so |x| < 7 -- and
they were at +-9.5.

**WIDENING THE DRIVEWAY CANNOT FIX THAT**, which is the counter-intuitive part
and the reason it is written down. The causeway is defined as the paving plus
one stud, so both edges move together and the dry strip beside the drive stays
half a stud wide at ANY driveway width. Widening the causeway independently
works and is worse: fitting even a small ornament needs about 25 studs of
bridge against a gate of 24, which makes the whole gate approach dry and stops
tier 5 doing anything on the side people actually walk in from.

So the slots moved OUT instead of the water moving. The moat and its banks
reach z 31.6 and the kerb is at 38.4; measured across that band at +-9.5, wet
through z 32 and dry from 33 out. They sit at z 35, x +-22 -- outboard of the
plot sign, which is bigger than it looks at nine parts spanning x 8.9 to 17.5.

**THE LAWN IS ROWS NOW, NOT A RING, AND THE ROW SPACING IS ONE NUMBER THAT
COVERS EVERY PAIR.** The ring was seven positions 15 to 19 studs apart and it
was measurably broken: built and measured against every ornament's real
bounding box, four of the seven put the widest item through a side fence and
two adjacent pairs overlapped outright. Two tube men on one lawn intersected.
The spacing argument had been written against the gnome at 12.5 when the
widest ornament is not the gnome -- but the replacement number, 21.08, was
itself the tube man's HEIGHT read off a transposed bounding box. Re-measured
per part: the widest is the Shark In Trainers at **13.70** and the deepest is
the Giant Rubber Duck at **11.00**.

Ornaments are far shallower than they are wide -- the deepest is the Big Duck
at 11.0, against widths reaching 21.08 -- so **two slots whose Z differs by at
least 11.0 cannot overlap whatever stands in them**, and that is one number
covering all 196 pairings instead of a per-pair clearance nobody will re-check
when the fifteenth ornament lands. Rows 11 apart, columns 21.08 apart: on a
64-wide plot that is 4 x 3, less the piggy in the middle, the gate walk up the
front-centre, and the kennel in the front-right corner. **Eight slots**, all
verified by building the widest ornament in every one of them at once.

**WHAT LIMITS THE COUNT IS THE MIDDLE OF THE LAWN, NOT THE ORNAMENTS.** Once
the widest was measured properly at 13.70 the grid went to four columns, and
the count only rose from eight to nine -- because the piggy bank holds the
centre, the walk from the gate to it takes the whole middle of every row in
FRONT of the piggy (the gate is 24 wide, wider than the driveway outside it),
and the kennel holds a corner. Seven of the sixteen grid positions are spoken
for. A narrower ornament buys nothing now; only moving the piggy or the gate
would.

**THE TUBE MAN IS ALSO NOT CENTRED ON ITS OWN ANCHOR** -- it sits 0.55 studs
to the LEFT of wherever it is put, which at one point broke the side fence on
the four left-hand slots and not the four right-hand ones, an asymmetry no
screenshot would have caught. It no longer binds anything now the columns are
at +-25 and +-8.5, but anything placed near a fence gets measured on both
sides rather than one.

**A house tier's `width` is its main block, not its footprint.** Wings, gables
and roof slabs all overhang it -- the Manor measured 65 studs against a 51.2
fence interior and its wings stuck straight through the side fence. `House.build`
builds first, then measures its own bounding box and seats itself: back edge a
fixed distance from the fence, centred sideways. Centring matters because the
villa's garage hangs off one side only.

**The road is a fixed width, never derived.** `ROAD_HALF_WIDTH` is pinned so
that widening `STREET_SPACING` lands on the driveway instead of the tarmac.
`Config.streetMetrics()` is the single source; `NeighborhoodService` used to keep
its own copy of that arithmetic and the two drifted.

**The street ends in a hill with a tunnel through it, at both ends.** The
patrol car used to appear at the end of the road out of clear air and vanish
the same way, which reads as a spawn rather than as traffic. It now spawns
*inside* the east bore — 12 studs in, behind a 22-stud unlit recess — drives
out, works the street, and leaves through the far tunnel behind the plaza
rather than reversing back out of the one it arrived through.

The mouths are in `Config.streetMetrics()` with everything else about the
street, because two files need them: the one that draws the tunnel and the one
that drives through it. That is the same rule the road width already follows,
and the reason is the same drift.

**The tunnel is blacked out, not bored through.** There is nothing behind the
void slab and there does not need to be. Two things make it read: the void is
`Neon` on pure black, the one material that ignores the light falling on it —
a dark `SmoothPlastic` slab still picks up the sun and looks like a grey wall
at the end of a corridor. And the lining has to be near-black (17, 17, 19)
rather than merely dark: at (58, 57, 56) it caught the sky and read as two
bright wedges either side of the opening, turning the tunnel into a shallow
alcove. The road surface also has to carry on into the recess, or there is
grass in the tunnel and the illusion dies at the threshold.

**Only the INSIDE of the mouth is black, and that is a fact about the earth,
not about the paint.** The bore was first built as a 2.5-stud skin of
near-black concrete with the domes left to bury it, which they did not:
measured, the outer walls came out 45% exposed and the roof 98%, so the tunnel
read as a black box standing between two hills. No arrangement of domes fixes
that. A sphere sunk into the ground is at its WIDEST at the ground, so any dome
big enough to cover a roof 16 studs up is wider still at road level — the same
sphere that buries the roof fills the bore underneath it, and one resting *on*
the roof carries its equator thirty studs up and overhangs the road like a
mushroom. So the mass around the bore is EARTH — grass blocks thick enough to
be a hillside — and the near-black is a thin liner a few inches inside the
opening. There is now nothing dark outside the mouth to be buried in the first
place. Anything added here gets checked the same way: sample the outward faces
and count how many are inside the hill.

**The mouth is MASONRY, because a squared-off mass is the one thing a dome
cannot hide.** The earth around a 14-stud bore is a 14-stud wall along its
whole length, and the front of that wall can never be covered: a dome close
enough to reach it is standing in the carriageway. Every green version of this
ended up as a box beside a hill. A concrete headwall is not a hole in that
argument, it is the answer to it — a portal is what a road tunnel actually
looks like, so the one shape that has to be seen is the one shape that wants
to be. It stands taller than the earth behind it and carries a coping proud on
every side, so from the street the silhouette is concrete and then hillside,
with nothing green and rectangular between them. The earth over the bore stops
half a stud above the lintel — level would put two faces at the same depth over
the patch where they overlap — and stepping it up in courses was tried and is
worse: from any camera above the portal the steps read as a staircase cut into
a hill, which is a stranger thing to see than a flat top.

**Every dome is placed against the bore and against the open ground in front of
the mouth.** Those are the two things a hill must not be standing in, and both
are easy to get wrong because a sunken sphere is widest exactly where the road
is. The clearance in front is DERIVED per end rather than tuned twice: a lane's
width at the open end, the whole 56-stud plaza at the closed one, since the
west mouth sits on the plaza lip where players spawn.

**Hills are the only scenery in `NeighborhoodService` that collides.** The rest
of the file is explicitly non-colliding so a chase can run through it; a hill
is the edge of the world and should stop you, and the banks are what stop a
player walking into the void and finding out it is a cupboard.


**The driveway is the visible half of a house upgrade.** The house stands 70
studs behind the piggy, so from the road its driveway surface is what actually
announces the tier -- dirt, gravel, brick, concrete, slate, lit asphalt. It is
built by `PlotService`, not `NeighborhoodService`, because it is per-owner.

**The moat leaves a causeway the width of the driveway, not the gate.** The
driveway is the only ground outside the fence that must stay usable at every
tier, and a wide bridge does not widen the narrow gate behind it, so this costs
the defender nothing. Anything placed elsewhere on the perimeter ends up in the
water the moment its owner buys tier 5 -- the moat takes the whole ring.

**A plot is three different floor heights.** The lawn is the top of the plot
slab (+0.5), the driveway is paving on the world ground (-0.28), and the verge
is bare world ground (-0.5). `Decor.build` takes a height per zone; passing one
number left everything outside the fence hovering a full stud.

**Decorations are placed automatically and never collide.** Buying one drops it
into the next free slot for its zone. There is deliberately no placement mode:
the lawn is the ground an owner defends on, and more prompts there would compete
with the collect and steal prompts that matter. Every ornament is CanCollide and
CanQuery off, so none of it can body-block a defender, a thief, or the dog.

**Slots are scarcer than items, and the ring is full at seven.** Twelve lawn
items against seven slots is deliberate: the lawn is a shelf you curate, not a
checklist you complete, and choosing what stays in the shed IS the decoration.
Seven is also the physical limit — the lawn is 48 studs across with a piggy in
the middle, the widest ornament measures 12.5 across the gnome's fists, and the
ring positions are 15 to 19 studs apart, which is exactly what the two widest
items standing side by side need. An eighth squeezed between two of them puts
an ornament through its neighbour, and the obvious front-centre spot at
(0, 19) is the walk from the gate to the piggy. Before adding a slot, measure
the two widest footprints against the closest pair.

**Meme ornaments are built as ORIGINALS, never as the named thing.** The silly
half of the lawn shelf — the duck, the swole gnome, the tube man, the loo guy,
the shark in trainers, the drip statue — exists because a fountain says you are
rich and a shark in trainers says you are rich *and* you thought this was
funny, and only the second one gets talked about. But the specific ones a nine
year old asks for by name are property: a fashion house's wordmark, its
interlocking emblem and its monogram canvas are each separately registered, and
the cartoon characters are somebody's copyright. Roblox moderation strips
branded assets and the penalty lands on the **experience**, not the one
ornament — an unshippable game is a steep price for a lawn decoration. What
actually carries the joke is the LAYOUT, and a layout is a genre rather than a
property: a serif wordmark stacked over a roundel, a checked monogram on a tan
holdall, an enormous bath toy. So the statue wears `PIGGY` over a snout
roundel and carries a snout-monogrammed bag, and it is funnier for it.

**A BAG NEEDS ROUND ENDS AND A FLAT FRONT, AND THREE SHAPES WERE TRIED BEFORE
ONE GAVE BOTH.** A BOX with a ball stuck on each end -- the original -- had
three flat faces meeting spheres matching none of their dimensions, so every
junction was a step and it read as a crate with rounded corners. A CAPSULE
(cylinder plus two balls of the SAME radius, tangent where they meet) fixed
the smoothness and cost the print, because a barrel has no flat side. A
STADIUM PRISM gives both: a box with a cylinder capping each end, where the
cylinder's DIAMETER EQUALS THE BOX'S HEIGHT, so it is tangent to the box's top
and bottom and the two make one shape with no step at the join.

**THAT IS THE GENERAL TRICK: TANGENCY IS A DIMENSION MATCH, NOT AN
ARRANGEMENT.** Cap radius equal to the half-height in the stadium; ball radius
equal to the cylinder radius in the capsule. Get the number right and the
seam disappears without CSG; get it wrong by any amount and no amount of
nudging positions will hide the step. Every piece stays a smooth-shaded
primitive, so none of this needs a union, a template or a server.

**A CANVAS PRINT NEEDS A FLAT SIDE, WHICH IS WHY THE SHAPE HAS TO EARN THE
MONOGRAM.** On a 0.95-radius barrel a panel wide enough to read stood its
corners 0.73 studs off the curve -- a plank stuck to a bag -- so the capsule
version had to cut the check down to a small plate. But the canvas IS the
reference: a designer holdall is the monogram. The stadium's 2.30-wide flat
front takes it at full size, and the print is sized to FILL that face rather
than float in the middle of it, because a panel with a margin all round reads
as a patch sewn onto a plain bag. Tiles are 7 x 5 so they come out near
square; at 6 x 4 they were half again taller than wide and read as brickwork.

**THE END CAPS ARE SET 0.02 SHALLOWER THAN THE BOX, which does two jobs at
once.** Their faces sit BEHIND the box's front instead of level with it -- two
surfaces at one depth is the coplanar flicker this file has caught three times
-- and it leaves the whole flat face clear for the print even where the caps
overlap the box behind it. Colouring them LEATHER against the tan canvas turns
the join into trim rather than a seam, which is what the reference does.

**A THIN OUTLINE MADE BY TWO OFFSET SPHERES IS ALWAYS GOING TO SPECKLE, AND
MAKING IT THINNER MAKES IT WORSE.** The eye's dark rim used to be a ball sunk
BEHIND the white on a different centre, showing as the sliver by which its
silhouette exceeded the white's. Measured, those two spheres crossed at 12.2
degrees -- near-TANGENT, so the surfaces ran alongside each other within
depth-buffer noise for the whole length of the ring. That is the speckle, and
it is structural: a thinner ring means the two surfaces are CLOSER, so every
attempt to refine it made the noise worse.

**CONCENTRIC SURFACES NEVER INTERSECT, SO THE RING HAS TO BE CUT RATHER THAN
PEEKED PAST.** The outline is now a dark shell sharing the eyeball's own
centre -- white 0.82, outline 0.84, lid 0.86, one centre, 0.02 apart -- with a
bore cut through it. Nothing in that stack can z-fight with anything else,
because parallel spheres have no crossing to be shallow. What is left crosses
the HEAD at 49.9 degrees, which is crisp.

**THE BORE IS SIZED AGAINST THE WHITE'S SILHOUETTE, NOT CHOSEN.** At 0.752
against a silhouette of 0.762 the dark starts just INSIDE where the white
leaves the head, so eye and outline always touch. Go wider than 0.762 and a
sliver of skin appears between the eye and its own outline. The ring's minimum
width is then fixed by the shell thickness -- +0.02 gives 0.025, +0.04 gives
0.049 -- so thickness and ring width are one decision, not two.

**A BIGGER SKULL BUYS FACE, NOT A BIGGER FACE.** Growing the head 4.3 -> 4.7
while every feature KEEPS its own size is what creates room: the same eyes on
a wider head leave more skin all round them, and the forehead band between the
eye and the hairline went 0.373 -> 0.620. That is the move when a face feels
cramped -- grow the head, not shrink the features, or the whole thing just
scales and nothing is gained. Lift the centre with it (15.30 -> 15.40) or the
skull eats the neck.

**A BROW CURVES BY ROTATING, NOT BY STEPPING.** The mouth already taught this
file that stacking segments by height alone puts a visible staircase in a
line. Three short segments that ROTATE as well as step (-3, -8, -14 degrees)
read as one arc; overlapping them by 0.08 at 0.26 spacing keeps it a brow
rather than three dashes. The arc peaks in the middle and drops toward the
outer end, and every sign follows `sx`, or the two brows mirror into a frown.

**AN EYELID CANNOT BE A BALL, AND THE REASON IS ARITHMETIC RATHER THAN
TASTE.** A ball's top is its centre plus its radius. A lid has to cover the
top of an eyeball already standing 0.39 proud of the skull, so its centre must
ride up -- and the radius then carries its crown into the hair. No radius and
no offset escapes that. It is a CAP cut from a ball CONCENTRIC with the
eyeball, which has no rest-of-the-sphere to stick up and cannot exceed the
eye's own envelope. Its cut is placed where the PUPIL stops, not by eye.

**A CAP TEMPLATE IS BUILT IN ITS OWN SPACE AND SEATED BY ONE CFRAME PER
COPY.** Centre on the origin, cap facing +Y, so the template's space means
"eye centre, lid pointing up" -- then each eye is
`CFrame.fromMatrix(eye, axis:Cross(up).Unit, axis)` and there is no mirrored
geometry to keep in step. `template.CFrame` must ride along in that product,
because a CSG result keeps its origin wherever the subtract left it.

**A NOTCH CANNOT BE ADDED BY ADDING.** Cutting hair reveals the head, so any
skin-coloured piece laid on top has to bulge PAST the hair to be seen -- a
lump on the hair, not a cut into it. Measured: a sphere sunk until it stood
0.05 proud showed a round patch only 0.23 across, and any box wide enough to
read had its corners standing off the curve. Cuts are CSG.

**CUT A SPHERE WITH A PLANE, NOT A SHAPE.** A big box with one face laid
across the cap leaves a flat FACET whose boundary meets the skull as a
straight edge, and a straight edge is what reads as deliberate rather than as
a bite. Place the cutter's centre one half-extent beyond the plane distance
along its own normal and the near face lands exactly on the plane.

**A RAISED SPHERE HAS EXACTLY ONE HAIRLINE, AND THAT IS ITS LIMIT.** A sphere
cuts the head in a PLANE, so its hairline is one constant height all the way
round. The reference needs two things at once -- a hairline coming down at the
sides near the ear, and a sharp raised edge across the forehead clear of the
brows -- and no amount of moving or resizing ONE sphere delivers both, because
it only ever has the one line to give.

**A LEAN IS HOW YOU ORDER FRONT, SIDE AND BACK -- and the first attempt threw
that away.** The reference wants THREE heights: high and sharp at the front,
halfway down the eye at the temple, lower again at the nape. A ball raised
straight UP gives the sides and the back the same height, so it can never
produce the last step, and the first build shipped without a nape because of
it. Leaning the offset back tips the hairline plane and orders all three in
one move, for free. The lean is SLIGHT -- 6 degrees -- because the plane is
long and a little tilt travels a long way across it.

**THEN THE FRONT IS CUT OFF THAT, and the cut is what makes the edge sharp.**
A plane leaves a flat facet meeting the skull as a straight line, where a
sphere can only give a soft circle. It carries the front hairline to 16.90 and
hands back to the natural line at y 15.40 -- just above the eye's centre,
which is exactly where the reference's edge turns the corner and starts
running back toward the ear.

**A RAZOR SLICE HAS TO CUT THE EDGE, NOT THE MIDDLE**, so it is placed to
reach past the hairline rather than to sit inside the hair -- an enclosed hole
in the middle of a fringe is a dent, not a razor line.

**AND A PLANE CANNOT CUT ONE, WHICH SHOWED UP AS A DARK PATCH RATHER THAN AS A
MISSING FEATURE.** A plane at a narrow angular radius only shaves the OUTER
SKIN of the cap: measured, it removed 0.052 of a coat 0.232 thick, leaving a
flat hair-coloured facet that catches the light at its own angle and reads as
a smudge on the head. To show scalp a cutter has to pass inside the HEAD's
surface, not merely inside the hair's -- and that is the general rule for
cutting anything worn on anything.

**DEPTH AND WIDTH ARE THE SAME NUMBER FOR A PLANE, which is why going deeper
does not rescue it.** A plane deep enough to reach the scalp here opens a
31-degree cap -- a third of the head shaved flat. A BOX fixes that and is
still not a slice: its thickness bounds the slot equally at both ends, so it
cuts a parallel-sided slit, measured at a constant 0.42 wide from end to end.

**SO THE CUTTER IS A MIRRORED PAIR OF WEDGES, whose union is one symmetric
triangle** -- measured widening 0.07 to 0.39 from tip to base. Two, because a
single WedgePart grows from its own base edge and gives a one-sided slash;
mirroring costs nothing since `SubtractAsync` takes the UNION of everything
handed to it. Mirror by flipping BOTH the width axis and the depth axis:
flipping only the width gives a LEFT-handed frame, which is not a rotation and
which `CFrame.fromMatrix` will accept without complaint.

**A WEDGEPART'S SOLID WAS RAYCAST, NOT ASSUMED.** Casting a grid at a test
wedge reports full height at +Z falling to nothing at -Z, extruded along X.
Guessing that from the field names is exactly the mistake `legRoll` and the
cylinder axis are already recorded for.

**A FEATURE NEAR A CUT IS CHECKED AGAINST THE PLANE, NOT AGAINST A HEIGHT.**
Once a hairline is a plane rather than a circle it has no single height to
compare a brow against -- it drops as it goes outboard, and the OUTER segment
is the one that gets buried. The honest test is which side of the plane the
brow falls on: dot its corners against the cut normal. No eyeballed y-value
would have established that.

**RAISING A HAIRLINE MOVES THE BROWS, because a brow is centred in the band
rather than pinned to the eye.** Lifting the front hairline 16.70 -> 16.90
left them sitting almost on the eye with 0.45 of bare forehead above -- the
gap the change was meant to open, opened in the wrong place. Re-centred, it is
0.24 of skin below and about 0.2 above.

**A UNIONOPERATION'S `Position` IS ITS BOUNDING-BOX CENTRE, NOT THE SHAPE'S
ORIGIN, and a clearance measured from it is fiction.** Testing whether the ear
was buried in the hair used `hair.Position` as the hair sphere's centre; the
cuts had moved it, so the test reported the ear 0.067 INSIDE a hair ball it is
nowhere near. Keep the authored centre, or measure against the solid.

**AND THE ONLY SURFACE WORTH TESTING IS THE SURFACE THAT CAN BE SEEN.** That
same check compared the ear's CENTRE against the hair -- a point buried inside
the skull, which no camera will ever reach. Sampling the ear's surface, and
skipping every sample inside the head, put the ear at 100% visible: the right
answer, and the opposite of the wrong one. Test the visible set, not the
convenient point.

**+X IS THE VIEWER'S RIGHT, and it is worth deriving rather than guessing.** A
statue faces +Z, so a camera looking at its front looks down -Z; with up at
+Y, its right vector is +X. Anything asked for on "the right side" of a
reference photo goes on +X.

**A CSG CUT IS INVISIBLE TO A BOUNDING BOX WHEN THE CUTTER IS DIAGONAL.** The
notched hair measured identical to the uncut ball, because the slice comes off
a diagonal and the sphere keeps its extremes on all three axes. This file
already recorded that a bounding box cannot verify a subtract; this is the
sharper case, where it does not move AT ALL. Look at it.

**NOR CAN A SPATIAL QUERY, AND `GetPartBoundsInRadius` FAILS SILENTLY IN THE
CONFIDENT DIRECTION.** It tests BOUNDING BOXES, so every sample inside a
union's box reports covered -- a probe asking whether the slice had bared any
scalp answered "0 samples" for a cut that is plainly there in the render. That
sits alongside the raycast trap: rays hit a union's simplified collision hull,
which knows nothing about the hole. THERE IS NO GEOMETRIC QUERY IN THE ENGINE
THAT CAN SEE A CSG HOLE. Solve it numerically outside the engine, then LOOK.

**A CLONED TEMPLATE WANTS A PLAIN-GEOMETRY FALLBACK.** A client that asks
before the server has built one would otherwise get a bald statue. The hair
falls back to an uncut ball: hair without its notch is a far smaller fault
than no hair, and the same applies to anything else trading a primitive for a
template.

**SHARED CSG SCAFFOLDING GOES ABOVE THE BUILDERS, and that is the
forward-reference trap rather than tidiness.** A `local` declared after a
function that reads it is a nil GLOBAL to that function, and Luau says nothing
until the call dies naming nothing useful. `builders.dripstatue` sits 340
lines above where the folder and cache used to be, so leaving them there would
have been the EIGHTH time this project hit it.

**A SMIRK IS A TILT, NOT A STAIRCASE.** Asymmetry is the whole of a smirk -- a
symmetric curve is a smile and a flat bar is a deadpan -- but building the rise
out of stacked segments puts a step in the line. At 0.08 between boxes 0.16
tall the step is HALF THE HEIGHT OF THE MOUTH, and close up it reads as three
offset blocks. One bar rotated in the face plane has no steps in it to see.
Rotate about Z: the face looks down +Z, so Z is the axis coming out of it, and
rotating about X or Y pitches the mouth into the skull instead.

**MOVING A FEATURE DOWN A FACE IS TWO NUMBERS, NOT ONE.** The face is a
SPHERE, so its surface falls away as you descend it: dropping the mouth from
y 14.30 to 14.00 also has to bring z back from 1.885 to 1.692, or the mouth
stays where the face used to be and hangs off the chin in mid-air. Solve the
new z on the same shell radius the feature already sat on and the clearance
comes out unchanged -- both mouth pieces still stand 0.11 proud after the
move. It now sits 59% of the way from the eyes to the chin instead of
crowding the nose.

**HALF IN, HALF OUT IS WHAT STOPS A BALL ON A FACE READING AS A BALL STUCK ON
A FACE.** The nose was centred correctly and still wrong at 0.13 proud --
barely a nose. Pushed to 0.30 proud with 0.36 still buried it reads. The same
ratio is why the eyes work at 0.39 proud and failed at 1.01, when their own
centres sat outside the skull entirely.

**A POINTED NOSE IS A TAPER, AND ONE BALL CANNOT TAPER.** A sphere is round by
definition however it is placed, so the round-nose version could only ever be
a bump. Four balls shrinking 0.44 -> 0.17 along an axis pointing out and 27
degrees down do taper, and the step between them (0.12, against radii summing
to about 0.4) is what decides whether it reads as a cone or as beads -- the
same spacing-versus-radius test the turtle's band failed. THE BASE IS SIZED BY
THE EYES rather than by taste: they sit close in on a head this size, and 0.44
clears the white by 0.038 where 0.50 clips it outright.

**A FACE IS SET INTO THE HEAD, NOT STUCK ONTO IT.** The statue's eyes were two
1.9 balls centred 2.21 from the head's centre against a head radius of 2.15 --
each one's own CENTRE outside the skull, standing a full 1.01 studs proud. That
is a googly eye glued to a sphere, and it is why the face read as a mask with
something attached rather than as a face. Placed BY DIRECTION at a measured
distance instead -- the same technique the turtle's mottling uses -- they
protrude 0.39 and show a disc 0.768 across, which is an eye in a face.

**A PUPIL LOOKS FORWARD; IT DOES NOT LOOK WHERE ITS OWN EYE POINTS.** Set
radially, a pupil sits dead centre of the disc it is on -- and on a round head
each eye's disc faces OUTWARD, so two perfectly centred pupils read as
walleyed. Measured at 36.5 degrees of splay on the first pass and still 28.9
after the eyes were brought in and shrunk; the fix is not more splay-chasing
but pushing the pupils forward in Z, which lands them about 18% off their own
disc centre toward the nose. That is what "looking at you" is.

**TWO BALLS THAT ARE EXACTLY TANGENT ARE ONE BALL AS FAR AS A SILHOUETTE IS
CONCERNED.** The eyes' centres sat 1.90 apart against a 1.90 diameter, so the
two whites touched and merged into a single mass. They are 1.66 apart against
1.64 now -- close-set like the reference, separated by 0.02. Anything paired
and round wants that gap checked rather than assumed.

**HAIR IS A SPHERE PUSHED UP, NOT A DISC LAID ON TOP.** A cylinder on the crown
with a box fringe in front reads as a bowl balanced on the head. A sphere
raised above the head's own centre intersects the skull in a circle, so it
covers the crown and follows it exactly. The hairline and the cap size move
TOGETHER -- raising the sphere lifts the hairline and shrinks the cap -- and
what limits the travel is the eyes underneath: at radius 1.91 raised 0.70 the
hairline lands at y 16.35, clearing the top of the eye by 0.37.

**BRACE FACE IS THE MEME-ORNAMENT RULE APPLIED TO A REFERENCE THAT WAS
ENTIRELY SOMEBODY ELSE'S.** The ask was a specific film turtle in a purple
mask with braces edited over its grin. Both halves of that are property: the
colour-coded mask is literally *which character it is*, and the still is
separately a photograph somebody owns -- and there is live litigation right
now over exactly this class of character, with the studio behind the biggest
game on Roblox suing and being countersued over a brainrot character's
trademark. What survived the filter is the BRACES: a tough guy undercut by a
dentist is a joke, not a property, and it is the funny half anyway.

The bandana is simply gone rather than replaced. A first version swapped it
for ORTHODONTIC HEADGEAR -- a strap-and-bow harness occupying the same band on
the skull -- but that was solving a problem the eye band below had already
solved, and it shipped with a bug of its own: every part in it was a flat box
laid over the head, which is a Roblox BALL, and a box has no curvature to
match one. Its corners sat further from the head's own centre than its faces
did, broke the dome's surface by half a stud on the crown, and read as a pale
slab shot through the head rather than as a strap sitting on it. Removed
rather than repaired, on request -- the grin carries the joke by itself, and
the statue is smoother with nothing pretending to hug a sphere out of straight
edges. No weapons either, which is a separate question from the copyright one
and would apply even if the mask were free: Roblox's maturity questionnaire is
answered by what is literally in the model.

**THE EYE BAND IS THE TURTLE'S OWN MARKING, NEVER A TIED CLOTH ONE.** A band
across the eyes with the eyes showing through is a real reptile face and
belongs to nobody. A COLOURED bandana on a green turtle is a different object
entirely: the colour is the thing that says which of the four brothers this
is, so it is the identifying mark rather than a decoration on top of one. This
one is dark and desaturated -- the same family as the mottling beside it -- and
reads as an animal instead of a costume.

**THE BAND WRAPS THE WHOLE HEAD; IT DOES NOT FRAME THE EYES.** The first
version was four boxes clustered tight around each eyeball -- correct as a
frame, wrong as a headband. Nothing continued past the eyes, so the temples
and the back of the head stayed plain hide colour, and the four boxes fused
together at the bridge into one dark block sitting on the front of the face:
it read as a smear across the eyes rather than as something worn.

**FOUR REBUILDS OF THAT BAND FAILED BEFORE THIS ONE, and the failures are
worth more than the fix.** Overlapping BALLS read as a strand of pearls: each
keeps its own round shading and its own seam, and cloth has neither. FLAT
PANELS tangent to the head, tiled edge to edge, looked right from straight on
and fell apart everywhere else -- two panels tangent at DIFFERENT points on a
sphere are not coplanar, so what reads as overlap face-on is a roof-ridge from
the side, and the surfaces only touch along one line. Measured: a clean front
elevation and a lattice of gaps from any oblique angle. Then a hollow CSG
SHELL with sphere-cut eye holes, which was smooth but bulky -- a shell has an
inner surface as well as an outer one, so every cut edge came out doubled, and
the eyes read as sunk into a thick mask rather than bulging through a strip.

**THE BAND IS A SOLID ZONE OF A SPHERE: one ball, two boxes, nothing else.**
Everything above and below the strip is sliced off and that is the entire
shape. The shell version needed the `A minus (A minus KEEP)` trick to fake an
intersection Roblox does not offer -- three CSG passes for a shape two
subtracts produce directly. Simpler geometry also tessellates better, which is
what actually fixed the faceting.

**IT HAS NO EYE HOLES, AND THAT IS THE MEASUREMENT THAT SIMPLIFIED
EVERYTHING.** An eyeball's centre sits 1.701 from the head's centre with its
own radius of 0.55, so it reaches 2.251 -- a full 0.35 PROUD of the 1.9 skull.
A band at 1.97 passes BEHIND the eyes and they push through it on their own.
Cutting holes was solving a problem the geometry had already solved: the holes
had to be wide enough to clear a 0.55 eyeball, which on a band this tall broke
through its own bottom edge anyway.

**THE BAND'S LOWER EDGE IS SET BY THE SNOUT, NOT BY THE EYES.** The muzzle's
top face is at y 4.750 and the grin panel's top edge at 4.625, so a band that
dips below either cuts across the face -- the version that did hung a dark
spike down between the eyes over the teeth, which is what "clipping with the
head" looked like. 4.80 clears the muzzle by 0.05 and the grin by 0.175. Note
this makes "under the eyes" impossible at the FRONT: the eyes span y 4.450 to
5.550, so their bottom third is below the band and bulges out under it. That
is the geometry, not a compromise -- the snout is simply higher than the
bottom of the eyes.

**`RenderFidelity` IS PLUGIN-SECURITY ONLY, AND REACHING FOR IT TOOK THE WHOLE
SERVER DOWN.** A UnionOperation is a real MESH rather than the smooth-shaded
primitive a `Ball` is, and on the default `Automatic` fidelity Roblox renders
a decimated copy that sheds triangles with distance -- so `Precise` looks like
exactly the right fix for CSG that has to read as curved. A plain assignment
throws *The current thread cannot write 'RenderFidelity' (lacking capability
Plugin)*. It threw OUTSIDE the pcall around the subtract, so it took
`Decor.prewarm`, then `PlotService.start`, then the whole of `Main` -- twelve
plots and every service after them, gone, from one property write. The console
showed the build line, the stack, and then no "Ready" at all.

**AND IT PASSES WHEN TESTED FROM THE COMMAND BAR OR AN MCP SANDBOX, which run
WITH plugin capability.** That is the trap and it is worth stating on its own:
the context that proves the write works is the one context that is not the
game. Anything touching a capability-gated property has to be exercised from a
real Script before it is believed.

**SO `Decor.prewarm` IS PCALLED: A LAWN ORNAMENT MAY NEVER STOP THE SERVER
STARTING.** It is called from `PlotService.start`, which `Main` runs in
sequence with every other service, so anything that throws in there takes the
plots, the economy and the game with it. A statue that loses its headband is a
cosmetic fault in one ornament; losing the server is not, and the two must
never be able to trade.

**Mottling is placed ON a sphere BY DIRECTION, never by hand-picked
coordinates.** A spot positioned by eye floats a tenth of a stud off a curved
surface and reads as a bug rather than as a marking. Normalise a direction,
multiply by a radius inside the sphere's own, and every spot is half sunk by
construction -- verified at all seven embedded and all seven still proud.

**THE SHELL IS THE BODY, AND THAT IS WHAT MAKES IT A TURTLE.** The first
version was a bust -- a head the same size as the mass under it -- and
rendered as a green lump with teeth. A turtle reads from two things and
neither is the face: a WIDE LOW DOME, and a head that comes out of the FRONT
of it rather than sitting on top. Stacked discs rather than a ball, because a
Roblox sphere is as tall as it is wide and a shell that tall is a boulder.

**A PRINT SIZED IN ONE VERSION DOES NOT FIT THE NEXT ONE.** The grin was
hard-coded at 3.4 x 1.5 for the bust, survived the rebuild that took the
muzzle to 2.9, and promptly overhung it on both sides -- reading as a white
box hung in front of the face rather than as a mouth. It takes its size from
the caller now, because the muzzle is the thing that decides how wide a grin
is. Measured after: 2.75 on a 2.90 muzzle, contained, 0.02 proud of the face.

**Two of the clipping numbers on this model are SUPPOSED to be non-zero, and
a checker that flags every overlap will cry wolf about both.** The brow
overhangs the top of each eyeball by 0.225 of a 1.10 ball -- that is what a
brow ridge is -- and the face bow overlaps the side strap by 0.30 because it
has to *touch* the strap it hangs from; at zero it floated unattached. What
must be zero is the bow against the eyeball, which the first attempt ran
straight through on all three axes.

**A print is drawn, not built.** The statue's shirt graphic and its bag
monogram are SurfaceGuis on invisible panels, because a print is flat and no
arrangement of studs holds a legible word at three studs across. Two things
have already bitten: `Face` must be `Back`, since Front is -Z and every one of
these faces the street on +Z; and the panel has to clear the geometry it sits
on — the bag is centred on z = 0.3 rather than zero, so a symmetric ±1.05
buried the front print inside the bag it was printed on.

**An ornament is seen from the pavement, so its silhouette must work
BROADSIDE.** The shark was authored nose-forward and read as a blue disc with a
horn: a body seen end-on is a circle, three trainers in a row stack into one
white block, and the tail sticks up over the top looking like a fin. Everything
that identifies it lives in the side profile. Anything long gets its long axis
across the viewer — which is also the cheap direction, since a cylinder's own
axis is X.

**Every decoration slot faces the road, and none of them carries a yaw.**
Plot-local +Z is the street on both rows — the far row's half-turn is already
in its plot CFrame — and every builder authors its ornament facing +Z, so an
unrotated slot points the one good angle at the one place anybody stands. The
slots used to scatter by 20/90/155/200 degrees to read as a garden arranged by
hand rather than a showroom, which works on a plan view and nowhere else: the
two back slots were turned past 90, so the trophy showed its blank back, the
drip statue faced its own house, and the shark went nose-on again — the exact
bug its builder was rewritten to fix. Variety nobody is standing where they
could see is not variety. `Decor.build` still reads `slot.yaw`, so a slot that
genuinely wants an angle can carry one; nothing does.

**`Fabric` is a dark, noisy texture, not a colour.** A bright orange tube man
rendered muddy brown at any distance, and a tan duffel bag rendered near black.
Use it for cloth that is meant to look woven and dark; use `SmoothPlastic` for
anything whose colour is the point.

**Nothing here can be DUG, so sunkenness is always an illusion.** The world
ground is one solid Part and a Part cannot cut a hole in another Part. Setting
the moat's water surface 0.16 below ground level did not make a trench — it
made the moat vanish, because the grass is still there above it. Every layer of
the channel sits *proud* of the ground and the depth comes from the kerbs: two
stone banks standing 0.5 above the grass with the water surface 0.19 below
their top edge, because the eye takes the highest line as ground level. Then an
opaque dark bed under half a stud of translucent blue, or the water tints the
grass beneath it and the moat comes out pond-green. This applies to anything
else that ever wants to look excavated.

**The moat's kerbs belong to the RING, not to the bands.** The water is cut
into five bands that overlap at the corners, so a kerb built per band ran
straight across its neighbour's channel and the moat came out with stone bars
lying across it like cattle grids. There is an outer edge and an inner edge;
the kerb is two closed rectangles laid on those, and it does not care how the
water was divided up.

**The moat is animated on the CLIENT, like the skins.** The server builds the
channel once and publishes each band's span as an attribute; every machine
works the surface bob and the travelling ripples out for itself. Driving it
server-side would replicate a CFrame and a Transparency write per band per
frame — twenty-five parts for one moat, before anyone buys a second. The parts
are found by CollectionService tag rather than collected once at startup,
because a moat is built when someone buys the fifth fence and torn down when
they rebirth.

**The officer's run is posed on the SERVER, and that is not the exception it
looks like.** The animated skins and the moat are client-side because they are
work multiplied by twelve plots and running forever. This is one officer, alive
for at most thirty seconds, and -- the part that settles it -- `Model:PivotTo`
was ALREADY writing every descendant's CFrame every frame, all twenty-two of
them, just to drag the model rigidly. Posing the limbs individually replicates
exactly the same properties, so the swing costs nothing. The client version is
not merely no better, it cannot work: the server owns this position because the
catch depends on it, so a client-side swing would be overwritten by the
server's next write, every frame, forever.

**The stride is driven by DISTANCE TRAVELLED, never by a clock.**
`poseOfficer` takes how far the officer has run, and the legs are a function of
that. This is why there is no "am I moving" test anywhere: an officer standing
still has its legs together by construction, one that is slowed steps in
proportion, and the animation cannot desync from the movement it depicts
because it IS the movement. The same idea would suit anything else in this
world that walks.

**The officer's FEET DO NOT TILT, and the body drop is measured off them.**
Three separate bugs live in this one paragraph and all three were caught by
numbers rather than by looking:

  * Swinging the shoe with its leg looks obviously right and sinks it. A shoe
    is 1.4 studs long, and turning that much geometry 40 degrees dips its toe
    0.45 studs THROUGH the grass -- and no body drop fixes it, because the sink
    scales with the shoe's LENGTH rather than the leg's. A flat foot has no
    such term and is what a blocky cartoon run looks like anyway. It still
    can't come off the ankle: rotating a fixed point about a fixed hinge
    preserves distance.
  * A joint's Z is the BODY CENTRE, never the piece's own. A shoe is authored
    0.22 forward -- it is a foot, it points somewhere -- and taking Z from the
    piece hung it on a hinge 0.22 in front of the hip its leg swings from. Two
    limbs, two arcs, 0.119 studs of ankle pulling apart mid-stride.
  * The "how far did the lower foot rise" accumulator is seeded at INFINITY,
    not at zero. Both feet rise when the legs split -- cosine does not care
    which way a leg went -- so a zero seed is always the minimum, the body
    never comes down, and the officer runs with both soles 0.42 studs above the
    grass and no bob at all.

The bob is not tuned: it is whatever planting the lower foot requires, so
raising `LEG_SWING` raises the bounce for free. Verified across a full cycle at
one foot always planted, deepest sole -0.00000, ankle drift 0.00000, and 0.292
studs of bob.

**THE ARREST SCENE HAS ITS OWN CLOCK, AND A SKIP GATE, and the gate is the
whole fix.** It was derived from `STUN_SECONDS` on the argument below, which is
sound -- and the implementation quietly undid it: the dismiss handler fired from
the frame the scene appeared, with nothing enforcing the "once the stamp has
landed" its own comment promised. So the movement key the player was already
holding -- which is everyone, they were running from the police -- killed the
whole thing instantly, and it read as the scene being far too fast. A comment is
not a guard.

It now HOLDS for `arrestHold` (5.5s) and becomes skippable at `arrestSkipAfter`
(3.5s), and the "press anything" prompt fades in exactly WHEN that becomes true
rather than sitting there through a window in which pressing does nothing. That
also settles the outlasting worry properly rather than by fiat: the stun lifts at
4, and from 3.5 the player can already dismiss it and move.

**The arrest is a SCENE, and its length is DERIVED from `STUN_SECONDS`.**
Getting caught used to be a toast with a number in it -- the same information
and none of the event. It is now a camera flash, a mugshot card, a BUSTED
stamp and the bail counting up. Every beat is computed from
`Config.STUN_SECONDS`, so the card clears at about the moment the player gets
their legs back: a cutscene that outlasts the thing it narrates is taking away
time somebody could have been playing, while this one only fills time they had
already lost. Change `STUN_SECONDS` and the scene follows. It is also
dismissable with any input once the stamp has landed -- the drama is the point,
but a player who has seen it forty times should not sit through the fortieth.

The toasts survive alongside it deliberately. The scene is the one part of this
that could fail to build, and a charge the player cannot see is
indistinguishable from a broken feature.

**The arrest screen is an ORIGINAL, and the obvious reference is somebody
else's property.** The temptation here is a specific wordmark in a specific
typeface over a specific desaturated screen, plus its audio. All of that is
registered, moderation strips branded assets, and the penalty lands on the
EXPERIENCE rather than on the one screen -- the same rule the meme lawn
ornaments follow, and the same reason the patrol car carries a pig snout
instead of a crest. What actually carries the joke is the LAYOUT, and a layout
is a genre: a height chart, a headshot, a name board, a stamp. The palette is
the game's own navy and gold.

The sting is a CELL DOOR rather than a drone, and that is not only a licensing
dodge. A door clanging shut says *sentenced*; a death drone says *you died*,
in a game where nothing kills anybody and where the whole point of the bail cap
is that being caught is survivable. Searching the Creator Store for the obvious
sound returns Undertale and Zelda rips almost exclusively -- "free" there means
costing no Robux, not cleared. `SHUTTER` and `CELL_DOOR` are Pro Sound Effects,
verified loading at 1.30s and 2.50s.

**The mugshot uses `rbxthumb://`, never `GetUserThumbnailAsync`.** The content
URL resolves itself and never yields, so the scene cannot be held up waiting on
a web call at the exact instant it is meant to slam onto the screen.

**A stamp goes on the PHOTOGRAPH.** Centred across the card it looked better in
the abstract and sat straight over the CHARGE row -- the one line that says what
you actually did. Note a rotated label reaches further than its width suggests:
a 58-tall box turned 8 degrees needs about four extra pixels each side.

**AN ANTI-REPEAT RULE THAT EXCLUDES THE LAST PICK COLLAPSES AT SMALL ROSTER
SIZES.** With TWO events, "never the same twice in a row" leaves exactly one
candidate, so the picker strictly ALTERNATES and the weights do nothing at
all -- raid, rush, raid, rush, an invasion every second slot instead of the
intended one in three, and a player who has seen a Rush Hour knows precisely
what is coming next. This file had already recorded the identical trap for
shuffled bags and it was then reimplemented in a different shape.

Damp the repeat instead of forbidding it: the last pick keeps its place in
the draw at `REPEAT_WEIGHT` of its weight. Measured over 4,000 draws at the
shipped weights, the raid lands 41.5% of slots -- one every 36 minutes -- with
29.4% back-to-back repeats, which is the number that proves it is random
rather than alternating. A frequency like that is DERIVED from the weights and
moves when a third event is added, so it is stated in the comments as measured
rather than pinned as a target.

**A SERVER COMMAND IS NOT A DEV TOOL UNTIL IT IS ON THE PANEL.** The F2 admin
panel is a hardcoded button list, not a text console, so `commands.event`
existed for a while with no way for a human to reach it -- it was only ever
driven by firing the remote from a test script, which is exactly the shape of
thing that ships unverified. The buttons name the event they start rather than
saying "start an event", because the scheduler picks a raid only about 41% of
the time and the whole point of a dev trigger is to test the ONE you are
working on.

**MEDALS EXIST BECAUSE COINS ARE NOT SCARCE.** Measured: events contribute
**7.5% of hourly income** at endgame -- 808K an hour best case against 10.8M
an hour of standing still. A coin payout is a thank-you, not a reason to come
back, so events pay a second currency that only attendance can earn.

**MEDALS ARE FLAT, AND THAT IS THE ONE PLACE THE SECONDS-OF-INCOME RULE IS
DELIBERATELY BROKEN.** Every other reward is denominated in the player's own
income so it keeps meaning the same thing as they grow. Medals do the opposite
on purpose: a set costs the same number of events for a brand-new player as
for a maxed one, so the ladder measures ATTENDANCE and nothing else. Coins
scale with the player; medals scale with turning up, and a rich player cannot
buy their way up this one.

**A SET IS A VIEW OVER THE EXISTING CATALOGUES, NEVER A NEW CATALOGUE.**
`Config.SETS` lists `{kind, key}` pairs pointing at items living in
`SKINS`, `EFFECTS`, `ACCESSORIES`, `DECOR_ITEMS` and `RIDES` as ordinary
members. No new ownership storage, no new save field per item, no new equip
path -- each item stays in the system that already knows how to build, price,
render and wear it, and an item is bought in its own home tab with a medal
price instead of a coin one. `SetService` only knows which table to tick and
which service to tell.

**`set` IS AN EXCLUSION, AND IT IS LOAD-BEARING IN FOUR PLACES.** Accessories
and drop-pool skins are roll-only, so an alien hat in `Config.ACCESSORIES`
would fall out of the COIN accessory roll and a Martian with a `rarity` would
fall out of the REBIRTH drop pool -- either of which hands set items to players
who never attended an event, and the set stops meaning attendance. It is also
needed in both FREE-IF-COSTLESS fallbacks: a set item is priced in medals and
therefore has no `cost`, and `(nil or 0) <= 0` is TRUE, so without it the
Tractor Beam was unlocked for every player in the game from the first second.
`Config.isSkinUnlocked`, `Config.getSkinsOfRarity`, `CosmeticsService.rollFrom`
and the effect push all check it.

**EVERY BRANCH THAT ENDS IN `format(info.cost)` HAS TO ASK WHETHER THE THING
HAS A COIN PRICE.** This file already recorded that for the ten drop-pool
skins, and it bit again in THREE more renderers the moment set items arrived
-- cosmetics, decorations and rides -- because `format` floors its argument
and a missing cost is nil, so those threw rather than rendering a wrong
number. The louder failure is the better one, but the rule is the same.

**SETS PUSH THROUGH A REGISTRY THAT `Main` FILLS IN.** A set spans five
catalogues owned by two services, so granting a ride must tell RideService and
granting a skin must tell CosmeticsService -- but `RideService` requires
`HeistService`, which requires `EventService`, which needs `SetService`.
Requiring either directly is a cycle. `SetService.registerPusher` keeps its
dependency list at one line and makes the cycle impossible rather than merely
absent today.

**AND `grant` MUST PUSH THE SET STATE TOO.** Telling CosmeticsService about a
new skin tells the SET panel nothing, so the first real drop was won and the
progress stayed at 0/6. Two pushes, because they are two different questions.

**THE DROP IS A REEL, THE SERVER DECIDES, AND THE PERCENTAGES ARE REAL.** The
server rolls over the UNOWNED pool and sends the winner with the pool it came
from; the client only animates landing on it. Because the pool is only ever
what you do not own, duplicates are impossible and the odds visibly improve as
a set fills -- which is the honest version of what a crate pretends to do, and
printing the number is what makes it honest rather than merely true. A reel
and not a pie because Roblox UI has no arc or conic gradient.

**NOTHING IS EVER LOCKED BEHIND LUCK.** Every set item carries a medal price,
so a drop only ever saves you time. That is the line that makes a spinner safe
for a nine-year-old: bad luck costs them a wait, never the item.

**THE WHEEL IS FREE AND MUST STAY FREE.** No Robux spins, no extra spins, no
premium wheel, no pass that re-rolls it. A free spin is fine for an under-13
audience; the moment real money can reach it, it is a paid random-chance item
and the penalty lands on the whole EXPERIENCE. Same shape as the coins rule,
and it is why moving the roll onto an event currency is the cleanest route
this design has to "the roll is unreachable with money".

**PROCEDURAL COSMETICS ARE OUT, AND THAT IS A DESIGN DECISION RATHER THAN A
SCOPE ONE.** You cannot look forward to something that has no name. The pull
of a collectable is wanting THAT specific one, and a pool where some results
are duds trains players to stop caring about the roll. Everything in a set is
authored.

**TWO RIDES MAY NOT SHARE A `style`.** `RidePose.rideForStyle` scans
`Config.RIDES` with `pairs` and returns the FIRST match, so a shared style
resolves non-deterministically and differently on different clients -- and it
hands back the ride KEY that `phaseOf` uses to find the mounted model, so the
wrong answer breaks tricks for whichever ride lost the coin toss. The Hoverdisc
has its own style and `POSES.hoverdisc = POSES.hoverboard` aliases the measured
pose instead. That alias is only honest while the geometry keeps the
hoverboard's contacts, so the disc stands at the same height with pads at the
same +-1.08 the posed feet land on.

**A NEON SKIN NEEDS A DEEP COLOUR, for the reason the Marble Palace already
learned.** Neon renders a colour flat out and the BloomEffect takes it from
there, so a pale tint on a twelve-stud sphere is a white hole rather than a
glowing pig -- the first Martian at (126, 232, 132) blew out the piggy, the
lawn, the fence and every ornament around it into one white mass. Keep an
animated palette WITHIN its own hue too: a ramp topping out near white spends
half its cycle blown out. And two bright sources on one piggy compound, so a
set effect that may sit on a Neon skin gets a weaker light than Inferno's.

**A LENS GOES OVER THE EYEBALLS AT x +-2.35, NOT BETWEEN THEM.** The Abductor
Visor's lit ovals were authored at +-1.4 and measured x[-2.25 -0.55] and
x[0.55 2.25] -- two lights sitting in the GAP between the pig's eyes. Same
failure this file already recorded, caught the same way: by measuring each
part's world extents against the pig's own landmarks rather than looking.

**SESSION EVENTS EXIST BECAUSE NOTHING DIFFERS BETWEEN A PLAYER'S THIRD
SESSION AND THEIR THIRTIETH.** Measured against the live Config: both upgrade
trees max at 2h11m, the highest rebirth gate in the whole game is 6, and both
sources of randomness are finite lists -- twelve accessories and ten drop
skins -- that run dry and never refill. An event cannot be exhausted because
it is not an item: it has no pool, no catalogue and no completion state,
which is exactly the property the two collection rolls do not have.

**THE ALIEN RAID IS THE FLAGSHIP BECAUSE THE STREET HAS NEVER BEEN ON THE SAME
SIDE.** Stealing, dogs, fences, locks, gadgets and Most Wanted are all
adversarial; the patrol is neutral and comes for individuals. `FRIEND_BONUS`
is the ONLY cooperative mechanic in the codebase and it is a passive income
multiplier rather than an action -- you are paid for your friends being
present, you never do anything together. So a full server means MORE THIEVES.
For the length of a raid it means more defenders, and that is the single
biggest change available to this design.

**AN EVENT REUSES THE HEIST VERBS AND ADDS NONE.** You break a beam by
THROWING a gadget, exactly as at a thief carrying your coins, and recover the
loot by HOLDING A PROMPT, exactly as you collect or steal. No new input, no
new button on a phone, nothing to teach, and no weapon anywhere in it -- the
same shipping requirement that gives the officer no baton. It also gives the
gadget tree a second life: today those work only on somebody ACTIVELY carrying
loot, which is almost never true.

**A DRAIN THAT DOES NOT BEAT INCOME IS INVISIBLE, and that is structural
rather than a tuning slip.** The first build took a fraction of the vault over
a fixed `drainSeconds`; income is a fraction of the same vault over a SHORTER
time, so income wins at every level of the game. Measured: a maxed player's
pile sat at 2,988,151 for a whole raid while coins were genuinely being taken
at 1,660/s against 2,995/s of income. The loss landed correctly at the end and
could not be seen for a second of it -- which for a nine-year-old is
indistinguishable from nothing happening. `drainIncomeMultiple` is a FLOOR
expressed as a multiple of the victim's own income, so the pile visibly falls
whatever tier they are at; the cap still bounds the total. Anything else that
takes from a live vault needs the same floor.

**A PRIMARYPART THAT IS ITSELF ROTATED LOSES ITS ROTATION ON THE FIRST
`PivotTo`.** `HomeModel` already records this from the building side; the
saucer met it from the driving side. Its hull is a cylinder and so carries a
90-degree roll, making it the PrimaryPart put that roll into the model's
pivot, and `PivotTo(CFrame.new(pos))` -- an identity rotation -- replaced it.
Measured on the first flight: hull axis (1.00, 0.00, 0.00), a disc standing on
edge like a wheel, with the dome swung round to exactly hull height. No
PrimaryPart and an explicit identity `WorldPivot` at the centre moves
everything rigidly and every relative rotation survives.

**THE THING A PLAYER MUST AIM AT CANNOT LIVE INSIDE THE EFFECT ADVERTISING
IT.** The beam originally ran from the saucer to the piggy -- 64 studs long
and 6.8 wide -- and the drone, 3.4 across, hovered INSIDE it and could not be
seen at all. Every measurement passed; only a screenshot showed it. The beam
now emits from the DRONE, which fixes three things at once: the drone sits
proud at the top of a ~15-stud beam where it reads as the source, the beam is
a fixed length however far away the saucer parks, and the saucer goes back to
being the scenery it should always have been.

**AN EVENT SUPPRESSES THE PATROL, WHICH IS WHAT LETS THEM SHARE A HUD ROW.**
The top-centre column is full and measured -- coins 16, rebirth 96, carry
140..192, street banner 200..238 -- and a fourth row lands 35% of the way down
a phone held sideways. `EventService.isEventLive` makes the two mutually
exclusive BY CONSTRUCTION, which is the same reasoning the dodge and trick
buttons follow. The patrol is deferred and never cancelled: `dueAt` is its own
clock and the suppression does not touch it -- verified live, `due` counted
down unbroken from 472s through a whole deferred patrol.

**A TEXTLABEL DRIVEN BY A HEARTBEAT CANNOT BE MEASURED IN PLACE.** Two
attempts to check the new banner strings against the box returned five
identical widths for five obviously different strings, because the banner's
own loop rewrites `label.Text` every frame and the probe was reading back
whatever the loop had just put there. Measure on a DETACHED CLONE with
`TextScaled` off at a known size. Done properly: the patrol's longest line is
322px in a 322px box -- exactly on the edge -- and the three new lines are
276-297px.

**The patrol is the only risk in this game that belongs to NOBODY.** Every
other one is the victim's -- their dog, their fence, their lock, their tag --
which leaves a hole no purchase can close: robbing an offline player, or one
stood at the far end of the street, is completely free, because the person who
paid for the defence is not there to use it. The police cannot be bought,
upgraded, bribed or aimed, and they do not care whose plot you were on. That is
the whole point of them, and it is why they must never become a defence
upgrade: the moment a player can buy, summon or aim a patrol, it stops being
the house's risk and becomes a twelfth thing the rich player owns.

**MOST WANTED IS A SESSION CONTEST, NOT A LIFETIME ONE, AND THAT IS WHAT
MAKES IT A CONTEST AT ALL.** It used to read `data.totalStolen`, the persisted
lifetime figure, which made it unwinnable: whoever had played longest wore the
label permanently and nothing a new player could do in an evening would ever
take it off them. So the one status in this game that cannot be bought was also
the one nobody could earn. `SocialService` keeps a per-session RAP SHEET
instead, counted on DELIVERY rather than on the grab -- loot tagged out of your
hands or confiscated by the patrol was never stolen, you were caught, which is
the same line `data.totalStolen` already draws.

**THE PATROL COMES FOR THE NAME ON THE BOARD WHEN NOBODY IS MID-ROBBERY.**
Three things stop that being a tax on playing well, and removing any one breaks
it. A LIVE ROBBERY ALWAYS WINS, and the test for one is made AT THE TOP OF THE
PATROL rather than at the end of it -- nothing is pending when the car arrives,
so "is anybody mid-robbery" is exactly "did a steal beat the siren". Running it
after the cruise instead, which is how it shipped first, cost the feature its
whole shape: the officer only set off once the forty-five seconds had expired
and the car was already leaving, so the most wanted watched the patrol drive up
and down for the entire window and then get out at the last second. The pursuit
read as an afterthought because it literally was one. A steal during the patrol
still takes it whenever there is no most wanted to go after, which is the common
case early on. THE TARGET IS NOT CARRYING
ANYTHING, so they run at 16 against an officer at 14.5 and simply outrun them:
being wanted is dangerous precisely when you are greedy enough to be holding
loot as well, which hands the decision this whole feature is built around to
the one player who has taken the most. And THE ARREST CLEARS THE SHEET, so the
title passes to somebody else and the same child is not hunted all evening.

**A PLAYER MAY BUY THE TIMING. A PLAYER MAY NEVER BUY THE TARGET.** The
Patrol Radio calls a patrol out early for 75,000 coins, which flatly
contradicts "the police cannot be bought" as that line was first written --
so it is worth being exact about which half of that rule was ever
load-bearing. It was never that the police are unsummonable. It is that
NOTHING ANOTHER PLAYER DOES CAN AIM AN OFFICER AT YOU, which is the same
shipping requirement the gadgets carry and the reason there is no target
argument anywhere in this feature.

`PoliceService.call` takes no arguments at all -- not a player, not a plot,
not a position. A radio brings a car onto the street and says nothing about
who for; the pursuit is then chosen by the two rules that already existed, a
completed steal during the cruise or else the name on the board. The caller
cannot name anybody, cannot exclude themselves, and gets no protection: if
they are top of the board it is THEM the officer gets out for, which the shop
card says in as many words. That is also what stops it being a defence
purchase -- it does not protect your piggy, it starts a minute in which the
biggest thief in the server is being hunted, and the biggest thief is
sometimes you.

Which makes it the one lever the rest of the street has against a runaway
leader, and the closest thing this economy has to a pressure valve. It is
sold under its own header rather than beside the treat and the sprinkler
because it is the one thing on that tab that does nothing to your own plot,
and shelving it as a third way to defend your piggy would describe it wrongly
in the one place a player reads about it.

**A CALL BORROWS THE STREET, NEVER THE CLOCK.** The schedule has its own
deadline (`dueAt`) kept apart from how long the current phase has left
(`phaseEnds`), and it is advanced only when the patrol about to run is the
scheduled one. Folding the two together is what the admin trigger used to do:
it set `phaseEnds = 0`, the loop ran a patrol, then started a fresh eight
minutes -- so every `police` command silently pushed the next real patrol back
by however long the fake one took, and nothing on screen said so. Measured
across a called patrol: `due` counted 333s down to 210s in step with the wall
clock, straight through fifteen seconds of siren, a forty-five second cruise
and the drive-off, and the quiet that followed was the REMAINDER of the
original schedule rather than a new one.

`dueAt` is also set at the START of the warning rather than at the end of the
patrol, so the interval is siren to siren. The old arithmetic
(`period - warning - patrol`, then wait) made every cycle late by however long
that cycle's chase had run.

**IN A MATURE ECONOMY THE LOCKOUT IS THE CAP, NEVER THE PRICE.** A maxed
player earns about 3,000 coins a second, so the radio's 75,000 is
twenty-five seconds of income to them and no gate whatever; the same number is
two hours to a new player. A price can hold back somebody who has not finished
the game and can never hold back somebody who has, which means any consumable
whose ABUSE matters needs a clock as well as a cost. Without one a rich player
chains calls and the patrol stops being an event: forty-five seconds of car is
a hazard, and forty-five seconds of car every minute is a curfew -- the exact
thing the one-pursuit rule exists to prevent.

`callLockout` is three minutes of quiet measured from the END of a patrol, the
same shape as `guardLockUntil` and for the same reason: measured from the call
it would overlap the patrol it started and guarantee no gap at all. That puts
the floor at roughly one patrol every four minutes with unlimited money, twice
the scheduled rate, so the street reads as busy rather than occupied. Verified
live: the lockout stamped at 180 the instant the called patrol ended and
counted down while `due` went on counting independently, and a second radio
used during it was refused with the real wait named ("off shift for another
1m 46s") and was NOT spent.

**A CALLED PATROL IS ANNOUNCED, AND DELIBERATELY NOT ATTRIBUTED.** That the
patrol was paid for is a fact about the street and everybody gets it, at the
same moment the sirens start and with the same fifteen-second head start a
scheduled one gives. WHO paid is an accusation, and naming a child as the one
who called the police on the server is the shape of thing this whole feature
is built to avoid. The caller gets a private line confirming their coins did
something -- a 75,000-coin purchase with nothing on screen reads as broken --
and the street gets an anonymous one. The patrol belongs to nobody, including
the person who called it.

**THE NUMBER ROW IS FULL AT TEN, so the eleventh consumable takes a letter.**
Keys are fixed per item and never renumbered to fill gaps, so there was no
shuffling to be done: the radio is R. Checked against the rest of the map,
which is now Q dodge/trick, B shop, V garage, R radio,
Escape close, F2 admin console, and 1-0 the hot bar. A twelfth consumable
needs the same check and there are fewer letters left than it looks.

**A MOST-WANTED ARREST CHARGES THE RECORD; AN ORDINARY BUST CHARGES THE JOB.**
Bail is three times whatever the arrest was FOR, so `chargeBail` needs no branch
at all -- `alarm.amount` is the loot in their hands for a steal-triggered
pursuit and the whole rap sheet for a board-triggered one. It is still capped
against the piggy bank, so the top thief in a session can lose an afternoon of
idle income and never a house, a skin or an upgrade.

**ONLY A MOST-WANTED ARREST CLEARS THE SHEET.** A thief caught mid-robbery pays
three times the loot in their hands and keeps their record, because that is what
they were caught for. Clearing on any arrest is an exploit with a friendly face:
run a hundred thousand up on the board, get deliberately caught carrying fifty
coins, pay a hundred and fifty, walk away clean.

**THE FLOOR IS SECONDS OF YOUR OWN INCOME, never a flat number** -- the same
rule the daily ladder follows, for the same reason. A steal takes 5% of a
victim's piggy bank and capacity climbs without limit, so any fixed figure is a
serious crime on day one and a rounding error by the weekend. Measured live: a
maxed player earning 2,994/s has to steal 179,677 to make the board, while a new
player at 10/s needs 600. The floor exists for one specific failure -- in a quiet
server, one player who lifted one small pile would otherwise top the board and be
hunted every eight minutes for the rest of the session -- and it is tested PER
PLAYER rather than once against the winner, so a rich player's petty theft
cannot hold the title against a poorer player's serious one.

**THE WANTED BOARD IS A PORTRAIT POSTER AGAINST THE LEADERBOARD'S LANDSCAPE
TABLE.** That is the whole reason it reads as a different object from forty
studs rather than as a second, shorter list of names. It carries one face and
three lines because it is about ONE person; a ranked top eight of thieves would
be the richest-piggies board again with a different column in it. The bounty is
on there because the patrol is published on principle -- the siren runs fifteen
seconds ahead of the car and the HUD counts both clocks -- and a price on your
head that nobody could read would be the one part of it still arriving as a
surprise. Empty state names the mechanic ("rob a neighbour to get on this
board") rather than reporting a blank, which is the state it is in for the first
minutes of every server.

**A PAIR OF BOARDS AT EACH END, because one pair covered half the street.**
The plots ran x -172 to +172 and the west boards sat at x -210, so a player on
the east plots was about 380 studs from them -- and a SurfaceGui culls by
distance from the CHARACTER, not the camera, so for six of the twelve plots
the leaderboard was not merely far away, it was never rendered at all.

THAT IS NOW A PROBLEM REMOVED RATHER THAN WORKED AROUND, and the pair at each
end went with it: the boards stand MID-VERGE at the centre of the street, so
every plot is within 96 studs of one pair. See the layout section. The
reasoning above is kept because it is the thing to re-derive if the street
ever gets long enough to want a second pair again.

Both ends are built from the SAME builders with an `endSign`, so the two pairs
cannot drift; and the refresh drives a LIST rather than the last board built,
which is what a second copy actually costs. The ranking is computed once and
painted onto every board, because two leaderboards must never disagree about
who is winning and they cannot if they read one list.

`boardYaw` flips the base quarter turn AND the 45-degree splay with the end.
Flipping only the base points the east pair's faces back down the street but
splays them outward into the hillside instead of in toward the road.

**NOT A JUMBOTRON, AND NOT A HUD ELEMENT.** The physicality IS the mechanic:
the design doc files the leaderboard under "social pressure, built in", and
the default Roblox player list is switched off here precisely because "the
square has a physical leaderboard and an eight-plot server tells you who is on
it by looking out of the window". A board you walk past creates a moment of
comparison; a HUD panel is a menu you dismiss. The HUD is also genuinely full
-- top-centre is a five-band column and bottom-left is four deep.

**UNMANAGED WORKSPACE DEBRIS SURVIVES FOREVER, because Rojo does not own it.**
A `GearPreview` folder holding a 90x26 panel floating at y=40 in the middle of
the map was mistaken for a feature and nearly turned into one. It appeared
nowhere in `src/` -- no script built it -- so it was scaffolding left over
from photographing gear, sitting in the place file where nothing would ever
reconcile it away. A `RadioPreview` model from this session was beside it.

This is the same failure as the `_preview` MODULE clones already recorded here,
one level up: the rule is not "clean up module clones", it is CLEAN UP
ANYTHING STAGED IN THE DATAMODEL. Before believing a stray object is part of
the world, grep `src/` for its name -- and delete leftovers in EDIT, because a
Play session's snapshot is thrown away and the place file is not.

**A BOARD NEVER STANDS IN THE CARRIAGEWAY, AND THAT RULE HAS OUTLIVED THREE
PLACEMENTS.** The leaderboard once sat dead on the road's own centreline,
thirty studs wide, twenty-eight studs in front of a tunnel bore only 22 wide
-- so from anywhere on the street the west portal was a board on legs. Then
they flanked that bore. They stand mid-verge at the centre of the street now,
facing each other across the road at `boardZ`, measured at 17.2 studs clear of
the fence behind and a pavement's width clear of the tarmac in front.

The 45-degree splay went with the tunnel, and it should have: it existed
because a board at a portal had to serve somebody approaching ALONG the street
and somebody standing on the plaza, and halfway was the only angle serving
both. Facing each other across a road there is no such compromise -- the
readers are between them -- so each faces square-on, and Roblox Front being -Z
means the +Z board takes no rotation at all.

**ONE POST IS A NOTICE BOARD; TWO LEGS ARE A BILLBOARD.** The legs have to
carry the panel's yaw or they splay out from under it at every angle except
head-on.

**A QUARTER TURN OFF A WIDTH AXIS IS THE NORMAL, WHICH IS THE ONE WRONG
ANSWER THAT STILL LOOKS DELIBERATE.** `billboardLegs` spread its pair along
`CFrame.Angles(0, math.rad(-90) + yaw, 0).RightVector` -- the panel's yaw
plus ninety degrees, which is exactly perpendicular to the width it was
meant to follow. So both legs landed on the board's CENTRELINE, one in front
of it and one behind, holding up nothing: every board in the game floated,
with a free-standing post either side of it. Reported, accurately, as random
posts by the signs.

It survived because it is invisible in the only two views anybody checks. A
plan view shows two posts at the right distance from the board's centre; a
head-on view shows them stacked behind it. It is only wrong from the side,
and there is nothing else out there to compare against.

MEASURE A CHILD IN ITS PARENT'S OWN FRAME, which is what caught it and what
a screenshot could not: `panel.CFrame:PointToObjectSpace(leg.Position)` gives
alongWidth and alongDepth directly, and the failure reads as alongWidth 0.00
with alongDepth +-9.60 -- a leg entirely on the wrong axis. Fixed, all eight
read alongWidth +-9.60 (leaderboard) and +-5.12 (poster) with alongDepth
0.00. The panel is built as `CFrame.new(...) * CFrame.Angles(0, yaw, 0)` with
width on local X, so the spread direction is that frame's RightVector and
nothing else -- never a rotation derived separately, which is what drifted.

**THE ONLY PAVED THINGS ON THIS STREET ARE THE ONES THAT ARE ACTUALLY ROAD,
and getting there took three goes.** The arrival plaza was paved in KERB grey
concrete -- a different colour AND material from the carriageway it joins --
so a 56-stud square of pale stone sat on the lawn with four hard edges and
nothing explaining it. Asphalt in the road's own colour fixed the material
argument, and the town square inherited it. Closing the row took the square,
and the paving followed it onto the verge as two aprons under the boards --
which was one move too many: a verge is GRASS, everything else standing on it
(lamp posts, bins, mailboxes, the four shops) does so with no slab underneath,
and two rectangles of tarmac in the middle read as the leftover of something
removed.

So: the carriageway, its kerbs, its centre line, and the driveway each plot
lays for itself. Nothing else. A shop's own forecourt is a different thing and
stays -- a building meeting a lawn at a made edge is what a forecourt is for,
and it belongs to the unit rather than to the street.

The kerb-ring technique is still worth keeping written down for whatever pave
next: a LARGER rectangle at a LOWER lift with the surface on top, so only the
border shows. Two slabs at one lift would z-fight, which is the trap the road,
the moat and the guard dog's eyes have each hit already.

**TWO BOARDS SIDE BY SIDE DO NOT SHARE A TYPE SCALE, and pixel sizes copied
between them lie.** The poster is 400x550 over a 16x22 panel, which is 25 pixels
per stud; the leaderboard is 600x400 over 30x20, which is 20. So a 62-pixel
heading is 3.1 studs there and 2.5 here, and carrying the leaderboard's numbers
across rendered the poster's title visibly smaller than the list beside it -- on
the board that is meant to be the louder of the two. Choose the height in STUDS
and multiply up.

**A CHILD NAMED `Name` IS SHADOWED BY `Instance.Name` ON EVERY DOTTED LOOKUP.**
`board.Suspect.Name` reads back the string "Suspect", not the TextLabel. The
service never noticed because it holds direct references in `wantedUI`, so this
only bites whatever inspects the board from outside -- a probe, a test, the next
person. The label is called "Who", matching the leaderboard rows.

**The police take the PIGGY BANK, never the coins.** Bail comes out of
`vault`, the uncollected pile that was already stealable, and never out of
`coins`. This is the same line the whole game is built on -- banked progress is
permanently safe, from thieves and from the police alike -- and it is why a
patrol can cost you an afternoon of idle income and can never cost you a house,
a skin or an upgrade.

**An arrested thief is RELEASED AT THEIR OWN GATE, and it is a teleport
rather than a respawn.** Being caught used to leave you stunned at the far end
of the street with a 240-stud walk home, which is dead time added to a
punishment that was already paid in coins. `LoadCharacter` looks like the free
way to do it -- `Main.onCharacterAdded` already seats every new character on
its owner's plot, so the placement would need no code at all -- and it is wrong
twice. The stun is a WalkSpeed written on the humanoid the player currently
has, so a respawn hands them a brand new one and ENDS THE DETENTION the instant
it begins, seconds early, with the arrest card still on screen saying
otherwise. And it reads as a death, in a game where nothing kills anybody and
where the bail cap exists precisely so that being caught is survivable.

It fires off the END of the detention rather than off the catch, so the
officer's GOT YOU still lands on somebody: the scene plays out where the arrest
happened and the release is what comes after it. That is also what hides the
move, since the card is opaque for the whole detention and only starts fading
at that moment -- so the reveal is the player's own lawn. It lands just INSIDE
the stun rather than racing it, or a player holding W gets a step in first and
is yanked back mid-stride.

Measured on a real catch, dropped 245.6 studs from home at the far end of the
street: the officer deployed, WalkSpeed went to 0 at 28.73s, the teleport landed
at 32.46s -- 3.73s later, exactly `STUN_SECONDS - 0.3` -- with the player STILL
stunned on arrival, and control came back one sample later at 32.73s standing
17.0 studs from their own piggy, which is the join spawn point to the decimal.

**Bail is capped at three times what was taken, and the cap is the feature.**
Uncapped, a thief who lifted 2,500 off a neighbour while sitting on 200,000 of
their own uncollected coins loses all 200,000 -- eighty to one, and the lesson a
nine year old takes from that is *never rob anybody again*. The economy needs
people robbing each other; the Guard Duty Treat exists for exactly that reason
and this is the same argument. At 3x it is always legible as "three times what
you grabbed", it always hurts, and it can never exceed what was already at risk.

Bail is charged even when the loot is already gone -- delivered home, or tagged
out of your hands on the way. It answers for the ROBBERY, and getting the coins
home before they caught you is the good outcome rather than an acquittal.

**The officer runs at 14.5, and that number is the entire balance.** It sits
between a carrying thief's 12 and a free player's 16, so holding the loot means
losing ground and DELIVERING is the answer -- the counter is a decision the
player already knows how to make. Nothing in the patrol exceeds
`BASE_WALK_SPEED`. The car is quicker, but the car never catches anybody: only
the officer's `catchRadius` ends a chase, and the car never leaves the road.

**The patrol is PUBLISHED, and commits to ONE pursuit.** The siren sounds
fifteen seconds before the car appears and the HUD counts down both the patrol
and the thirty-second escape, so robbing during one is a choice rather than bad
luck -- and bad luck is not something a nine year old can get better at. It
also makes an existing item better: the Disguise Kit is sold as a WAITING tool,
and waiting out a patrol on somebody's lawn as a wheelie bin is the best thing
it does. Committing to one thief keeps forty-five seconds of car from being a
curfew, and hands a second thief a free run -- a decoy play worth discovering.

**NO PLAYER CAN EVER POINT THE PATROL AT ANOTHER PLAYER, and that is the
load-bearing half of this rule -- not "only chases you while you are robbing",
which is no longer true.** The patrol now hunts the MOST WANTED thief when
nobody is mid-robbery, so an officer will chase somebody standing empty-handed
on their own lawn. What still holds, and what the shipping requirement actually
was, is that nothing another player does can aim an officer at you: the only
thing that puts you on that list is steals YOU completed, you are the only
person who can put yourself there, and being caught takes you off it. There is
still no way to call the police on somebody. Same requirement the gadgets
carry, and here it is still free rather than enforced. It is also why the officer carries no belt kit, no baton and no cuffs
and why the catch is a tag: Roblox's maturity questionnaire is answered by what
is actually in the model, and every one of those props answers it differently
for an under-12 audience. The car is an ORIGINAL for the same reason the meme
ornaments are -- a real force's crest, wordmark and chequered banding are each
registered somewhere, and moderation penalises the EXPERIENCE, not the prop.
What carries "police car" is the layout: a light bar, a two-tone body, a
roundel on the door. This one says PATROL over a pig snout.

**The dodge is a MULTIPLIER on `currentSpeed`, never a teleport.** That single
choice is what makes it safe. `currentSpeed` is the one function that owns every
speed in the game, so adding one more factor there means the dodge inherits all
of them with no new balance code: stunned returns 0 before the dodge is reached
(a zapper cannot be rolled out of), carrying scales it off 12 rather than 16, a
snag makes it proportionally slower, and riding refuses it outright. An impulse
or a CFrame nudge would have been a second, parallel way to move that none of
those numbers knew about. The DISTANCE is deliberately tiny -- about 4.5 studs,
a tenth off a 37-stud getaway. **The immunity is the point:** half a second where
you cannot be tagged, caught or hit, against a `TAG_HOLD` of 0.4s, so a defender
who eats a dodge starts their hold again. A dodge buys a moment, never an
escape, and it is free for everyone because it is a control rather than a power.

**ClientMain is near Luau's 200-local-register ceiling.** It hit it, and the
error names an innocent variable far from the cause ("Out of local registers
when trying to allocate dayLabel"). Every HUD feature added this session was
keeping four top-level locals for its state; they are now one table each
(`gadgetUI.tiles`, `stealthUI.held`). Group any new feature the same way rather
than adding four more -- and note the budget is being spent by more than one
person at a time.

**The guard dog does not watch an approach.** `GuardDog.chase` only fires from
`HeistService.attemptSteal`, AFTER a completed steal, so walking up to somebody's
piggy and holding their lock for up to twelve seconds carries no dog risk at
all. Every bit of pressure in this game is on the run home. Any "be sneakier"
feature has to be designed against that fact or it solves a problem that does
not exist -- which is why the Disguise Kit is sold as a WAITING tool and why
spring shoes were dropped (fences are already jumpable at 6.0 against a 7.2
jump, and the toll is the ClimbZone snag, which spans y 5.5 to 10.5 and catches
you on the way up whatever your apex).

**HIDING IS A PLACE NOW, NOT A COSTUME, and that dissolved the problem
rather than patching it.** Disguising AS a wheelie bin was wrong twice over
and both were the same mistake: a costume has to be PLAUSIBLE, and nothing
about the placement could be made so. `bins` is a VERGE item, so the decor
system will not let an owner put one on their own lawn even if they bought it
-- a bin standing on grass is a thing the game itself forbids. And the prop was
squared to the WORLD rather than to the plot: measured, the near row's plots
carry LookVector (0,0,-1) and the far row (0,0,+1), and the bins model is
front-to-back asymmetric -- 2 of its 6 parts change sides between the two -- so
on six of the twelve plots the disguise stood backwards to every real ornament
around it. A hiding PLACE carries none of that burden. The bin is already
there, the game put it there, it is already straight, and nobody has to own it.

**THE PURCHASABLE WHEELIE BINS ARE RETIRED, and had to be.** Once bins became
public street furniture, selling an identical-looking one as a verge
decoration would put two objects on the same street that a player cannot tell
apart, where one can be hidden in and one cannot. That is a worse tell than no
bin at all. The GEOMETRY stayed; only the purchase went.

**RETIRING AN ITEM DOES NOT REMOVE ITS BUILDER, and `buildOne` is the trap.**
`Decor.buildOne` resolves a key through `Config.DECOR_ITEMS` and returns nil
when it misses, so deleting the catalogue entry would have stopped the public
bins spawning with nothing in the log to say why -- the exact silent failure
this file keeps writing rules about. `Decor.buildStreetBin` reaches the builder
directly and is honest about what it is: shared geometry, not a shared item.

**THE PARKED CARS ARE RETIRED, AND THE WHOLE DRIVEWAY ZONE WENT WITH THEM.**
The Hatchback and the Sports Car were the only two items that could ever stand
in it, so the `drive1` slot and the shop's DRIVEWAY section were removed in the
same pass -- a header sitting over an empty grid reads as a catalogue that
failed to load, which is how a deliberate removal comes to look like a bug.
`builders.car` went too; nothing else built one, because the patrol's car is
`PoliceModel`'s own and deliberately so.

**A RETIRED ORNAMENT IS PRUNED AGAINST THE CATALOGUE, NEVER BY A LIST OF
NAMES.** Retiring an item leaves dead keys in every save that owned one, and a
`placed` entry pointing at an item or a slot that no longer exists -- the
driveway slot went with the cars. Neither errors: `Decor.buildOne` returns nil
and the ornament quietly never appears, which is the failure mode this file
spends the most words on. So the prune asks the CATALOGUE whether a key and a
slot still exist, which means anything retired later is handled with no new
code, no schema version to remember, and no migration table sitting in Config
that somebody has to work out is safe to delete.

Nothing is refunded -- the game is in beta and a retired ornament is simply
gone. The version that DID refund was measured idempotent first, and that is
the check any future payout migration needs before anything else: one that
pays out on every join is a money printer, which is a far worse bug than the
one being fixed.

**A comment that justifies a constant with a thing you just deleted is now a
lie.** `STREET_SPACING` is 104 because the driveway had to fit an 11.5-stud
hatchback -- and there is no hatchback any more. The number still stands, held
up now by the driveway length, the moat ring and the ride gate, so the comment
says that instead of pointing at a car nobody can find.

**A BIN BUYS A BREATH, NEVER AN ESCAPE.** Same line the bones draw on the
other side of the fight, and the reason the item is worth having at all. You do
not lose a pursuer by getting in -- they converge on the bin and dig you out.
What you buy is the LINE: they arrive stopped, at a known point, and you come
out facing wherever you like instead of being run down from behind at 14.5
against your 12.

**COMING OUT IS A VAULT, AND IT IS WORTH ABOUT ONE DODGE.** The exit used to
be a silent snap 4.5 studs sideways -- the right position, arrived at with
nothing to watch. It now pops the lid, plays the somersault, hops, and hands
out a short burst of speed. The size is DERIVED rather than picked: the burst
tapers from 1.30 to nothing over two seconds, so the mean excess is half the
peak and the ground it actually buys is 16 x 0.15 x 2.0 = **4.8 studs** --
deliberately about one dodge (4.5), spread over two seconds instead of half of
one. A flat 1.30 across the same window would buy 9.6 and be worth two.
Measured live: WalkSpeed 20.68 at the exit falling linearly to 16.00 at 2.07s.

**THE BURST IS A MULTIPLIER ON `currentSpeed`, never an impulse -- the same
decision `Config.DODGE` records and for the same reason.** `currentSpeed` is
the one function that owns every speed in this game, so a factor added there
inherits all of them with no new balance code: a stun returns 0 before it is
reached, carrying scales it off 12 rather than 16, a fence snag scales it
proportionally, a ride refuses it. Verified multiplicative rather than
additive by stacking it on an electric fence: 16 x 0.30 x 1.30 = 6.24 against
a measured **6.22**, where an additive burst would have read 9.6. Re-applying
does not stack either -- three bursts in a row measured 20.72 then 20.68,
falling rather than climbing, because a second one is taken against what the
running one is worth RIGHT NOW and not against its opening value.

**Carrying, it peaks at 15.6 against an officer's 14.5 and drops back under
them after about half a second.** That is the whole of it and it is the point:
the burst is paid for choosing your own moment, never for winning the race. If
it ever grows enough to simply outrun the person who found you, the bin has
stopped being a breath.

**THE HOP IS VERTICAL ONLY.** 30 studs/s is a 2.29-stud apex against a normal
jump's 7.2 -- a vault out of a bin rather than a launch. Any horizontal
component would be exactly the second, parallel way to move that the rule
above exists to rule out, so there is none: the sideways 4.5 studs is still
the single placement it always was.

**THE ROLL IS THE DODGE'S OWN SEQUENCE ON A SEPARATE ATTRIBUTE, and the
separate attribute is the load-bearing half.** Bumping `DodgeRoll` would have
been one line fewer and wrong -- that client handler also DASHES the local
player, driving their move direction for a quarter of a second, which would be
a third way to move stacked on the placement and the burst. `BinExit` gets the
animation without the dash. Sharing the animation is right for the opposite
reason: tumbling out of a bin is the same gesture as rolling out of the way,
and a second sequence built to look almost the same is the copy that drifts
the first time either is touched. A COUNTER and not a flag, because a boolean
set true twice fires one signal and somebody using two bins in one chase would
animate once.

**THE LID IS THE ONLY PART OF ANY OF THIS THAT ANOTHER PLAYER CAN SEE.** A
hider is invisible and a vault is over in a fifth of a second, so without it a
bin swallows and spits out players with no more animation than a light switch.
It flaps on the way IN as well, for the same reason -- that is the half a
pursuer is actually looking at. Hinged at the BACK edge like a real one:
verified, the front edge rises 2.35 studs while the hinge moves 0.0000. Fast
open and a slower bounce shut, because that is the order those two things
happen in; a symmetrical swing reads as a hatch rather than as somebody
bursting out of it. Measured at 1.29 studs of lift, back down by 0.75s.

**Both lids are called `Lid`, so they are collected by WALKING THE MODEL.** A
bin prop is a PAIR of bins, and `FindFirstChild("Lid")` returns the same one
twice -- the other would never move. Same trap the castle's four `Finial`s
already recorded.

**THE BIN REACTS WHOEVER OPENED IT; ONLY THE BURST IS EARNED.** The lid, the
roll and the hop happen on every exit, because they are the bin doing
something. The speed burst is gated on `direction ~= nil and why == nil` --
which is exactly somebody pushing their own way out, since every other caller
passes a reason and no direction. Handing a burst to a player who has just
been dug out would reward the outcome that is supposed to hurt.

**SO YOU MAY HIDE WHILE CARRYING, which REVERSES the old rule that the
disguise broke the instant loot was picked up.** That rule is why the item was
mechanically inert -- nothing in the game checked `isDisguised` except
RideService, and only to refuse a mount, so an officer would sprint at a
wheelie bin and arrest it. What the rule protected -- the run home is the risk
half of the trade and has to stay visible -- is kept, but paid for with
INFORMATION rather than a refusal: a bin with loot in it overflows, readable
only up close, so hiding with the goods is riskier than hiding without and the
chaser is rewarded for closing distance rather than handed a marker.

**ONE BIN PER PURSUIT IS A COOLDOWN ON THE PLAYER, NEVER A JAM ON THE BIN.**
Jamming the lid behind you only sends the thief to the next bin, and bin-to-bin
down the street is exactly the kiting this must not allow. It is set against
`POLICE.chase` so one patrol gets one hide. Verified: re-entering the same bin
is refused, and so is a different one.

**A PROMPT RADIUS IS MEASURED AGAINST THE ROAD, NEVER CHOSEN FOR FEEL.** A
bin hatch sits at |z| 9.8 -- ROAD_HALF_WIDTH plus the 1.8 verge line the lamp
posts stand on -- so a 14-stud prompt reached the centre of the carriageway
and a player could climb into a bin from the white line halfway across the
street. That is not hiding, it is teleporting into cover. At 5 the centreline
is 9.89 away and refused while the kerb is 2.23 away and works; measured
across the street, the cut falls between 4.02 (two studs onto the tarmac,
hides) and 5.95 (four studs on, refused). It cannot go much tighter and stay
usable, because the tarmac edge is only 1.8 studs from the bin -- what matters
is that the reachable set is the KERB and not the middle of the road.

**CLIMBING OUT IS A DIRECTION, NOT A BUTTON.** You are in a bin; you push a
way and you come out that way. No new control to teach, identical on a
keyboard and a thumbstick, and it is the entire reason the bin is worth using.
It is driven off `Humanoid.MoveDirection`, which keeps reporting input while
the root is ANCHORED -- measured, and the whole design rests on it. Verified at
exactly 4.50 studs in the pushed direction on every axis tried.

**THE HIDER IS PARKED AT THE BIN AND ANCHORED THERE.** Being inside has to be
spatially true rather than only visual: a pursuer converging on the bin is
converging on the player, and the catch radius has to agree with the picture.
Anchored on the SERVER, which replicates -- on the client it famously does not.

**A HIDE REMEMBERS WHICH CHARACTER IT BELONGS TO, and that check is the
safety net.** Dying in a bin left it occupied for the full two-minute ceiling,
because the `CharacterAdded` hook meant to clear it is connected inside
`PlayerAdded` -- which never fires for a player already in the game when the
service starts, i.e. every player in Play Solo and the first player into any
server. That hook had been silently doing nothing for the whole life of the
disguise. Both are fixed, but only the character comparison makes the CLASS of
bug impossible: `not root` could never have caught it, because a respawned
player HAS a root -- just not the one that was put in the bin. Measured at
still refusing entry six seconds after a respawn; now released in 1.5.

**A bin outlives its occupant, so `PlayerRemoving` goes through `reveal`.**
Dropping the `hidden` entry alone leaves `occupant` set and the enter prompt
disabled -- one player quitting mid-hide would kill that bin for the rest of
the server's life, with nothing on screen to say why it stopped working.

**Bins are PUBLIC street furniture, built with the road and owned by nobody.**
Four per side, at the midpoint between two GRID SLOTS beside the lamp post --
slots rather than plot frontages, because the row has a hole in the middle for
the square and the midpoint of the two inner plots is the square itself --
the one stretch of verge that belongs to no plot, since a plot's own verge
slots sit at its centre +/- 9.5 and a driveway runs down its middle. That puts
cover about 32 studs from any driveway: a real option on a 37-stud getaway,
far enough that reaching one is a decision. They are non-colliding like
everything else in `NeighborhoodService`, so a bin can never body block a
thief, a defender or the dog.

**The disguise hides the wait, never the getaway.** Standing still IS the
disguise -- drift past `drift` studs and it drops -- so it is self-limiting by
construction and needs no timer worth tuning. It breaks the instant loot is
picked up, without exception, because the run home is the risk half of the
whole trade and must stay visible. It deliberately survives the LOCK HOLD,
which is the joke. It also blocks rides: `StealthService` hides the character by
walking its descendants ONCE at conceal time, so a board mounted afterwards is
not on the list and would be a floating motorbike parked inside an ornament.

**Cheap counters bounce, the expensive one gets through -- on BOTH sides.** The
Guard Duty Treat refuses the two cheap bones and admits the Golden Bone; the
Raincoat sheds the plunger and the gum and admits the Zapper. Same shape twice,
on purpose: each raises the PRICE of beating someone rather than making them
unbeatable, and each keeps the top item of the other tree meaningful. Neither
touches speed, which stays capped at 16.

**The Guard Duty Treat exists to get people out of the house.** The economy
needs players robbing each other, and what stopped them was anxiety about their
own vault: there was no "lock up before you go out" action anywhere, so the only
way to protect a full piggy was to sit on it, and a player sitting still is the
worst outcome this design has. The treat does NOT grant immunity -- a Golden
Bone still gets through, the same line the chase-break draws. A prepared
defender makes robbing them cost 30,000 instead of 2,500 rather than closing the
door, which matters because an alert Titan runs at 17 against a thief carrying
at 16 and "cannot be bribed" would simply mean "cannot be robbed". Guard duty
also suppresses the dog's cooldown, so it is checked through `onCooldown` in one
place rather than at the six sites that used to compare against `busyUntil` --
miss one and the dog naps through the thing its owner just paid to prevent.

**Guard duty does not stack, and cannot be re-applied the moment it lapses.**
`setGuardDuty` used to add its duration to whatever was left, so ten treats
bought an hour: 100,000 coins for a dog that never napped and never took a
cheap bone. That is immunity, and defence buys *time*.

Refusing the stack alone does not fix it. Without a lockout an owner simply
re-applies the second it expires and the plot is guarded permanently anyway —
the same exploit, one click at a time. So `guardLockUntil` runs from EXPIRY,
not from use: six minutes on, four off, and the collar says which. Measured
from use, a 6-minute duty and a 4-minute lockout would overlap entirely and
guarantee no gap at all.

It also makes an existing counter reachable. The Wheelie Bin is sold on
standing still *"through six minutes of guard duty until the collar stops
glowing"* — against an owner who could top up on expiry that wait could never
end, and the disguise was advertising something it could not do.

Both refusals name the real wait and neither spends the treat, which is the
same rule the bone refusals follow: an item consumed for nothing is
indistinguishable from an item that is broken.

**A buff nobody can see is a trap, so guard duty is loud.** Neon collar, ON
GUARD on the nameplate, and the refusal names the rule. The counter to a buff
should be information rather than a fight: a thief reads it from the pavement
and walks to one of the other eleven plots, instead of burning a 30,000-coin
Golden Bone to find out. Anything that repaints the dog has to restore the tell
-- `applyTier` repaints every piece from the tier, and `rouse` rewrites the
nameplate, so both check guard duty first.

**The sprinkler is a joke and must stay one.** No damage, no stun, no slow: it
nudges trespassers toward the gate and soaks them, and they can walk straight
back in. Loitering is not a mechanical problem here -- `STEAL_COOLDOWN` and
`STEAL_MAX_PER_VICTIM` already make camping a plot pointless -- so the
irritation is social and the answer is too. Anything with teeth would be a
fourth defence stacking on the fence, the dog and the locks, and it would bite
during a steal attempt, since a thief cracking a lock is stood still on that
very lawn. It never touches the owner, and `HomeUse` carries no target
argument at all: the server acts on the caller's own plot or on nothing.

**A gadget buys a tag, never the catch.** Gadgets are to maxed Speed Boots
what bones are to the guard dog: the counter to a top-of-tree purchase that
had none. `getCarryMultiplier` caps at 1.0, so a thief with boots maxed carries
at 16 -- the SAME speed as the person chasing them -- and tagging becomes
impossible unless you are already on top of them. Three things keep the fix
from becoming the disease: they **cost coins every throw**; **tagging still
recovers the loot**, so a gadget is setup and never the terminal action; and
**range falls as power rises**, so the decisive one cannot reach a thief who
already got clear.

**A FOURTH RULE STOOD HERE -- that the only valid target, ever, was somebody
CARRYING LOOT -- and it has been deliberately dropped. What it protected is
kept; only the refusal is gone.** It was never a balance rule. It was the
shipping requirement: a gadget pointable at anybody is a harassment toy handed
to under-twelves. What it got wrong is WHERE that protection had to live.
Harassment is the EFFECT -- taking somebody's movement away, repeatedly, at
will -- not the aim. So the aim opened and the effect is what got held down
instead.

**A PRANK IS A SECOND CLASS OF HIT, and the branch is in `applyGadget`, not at
the throw.** A target holding loot takes the tuned thing: full duration, full
stun, raincoat in the way. Anybody else takes `Config.GADGET_FUN` -- 0.9s
against 1.2-2.2, the zapper's dead stop capped from 0.6 to 0.3, and no
raincoat. Measured on a live character: a zapper prank ran WalkSpeed 0 for
0.35s, then 9.60, then back to 16.00 at 0.95s. Deciding it at LANDING rather
than at the throw is what makes it honest across the half-second of flight --
somebody who picks loot up mid-flight catches the real one, and a thief who
delivers first catches the joke. Neither end can time their way around it.

**THE PRANK COOLDOWN IS ON THE PERSON BEING HIT, NEVER ON THE THROWER, and
that is the whole anti-harassment argument.** A thrower cooldown is no
protection at all: six players with plungers simply take turns, and the child
in the middle never gets to move. Keyed to the target, the worst the entire
server can do to one player -- however many are throwing, however rich -- is
0.9 seconds in every 6, and each of those costs somebody 1,500 coins. Anybody
still cooling down is SKIPPED by the target search rather than returned, so a
throw lands on somebody else instead of being spent on a refusal.

**A PRANK MUST NEVER BURN A RAINCOAT, so the ward check lives INSIDE the
carrying branch.** A coat is bought to survive a chase. Left where it was, the
cheapest item in the game would strip the defence off somebody who was not
even robbing anyone yet -- 1,500 coins to delete a 22,000-coin counter, at
will, from across the street. Verified: warded before a prank, warded after.

**A REASON THAT STOPS BEING A REASON HAS TO BE DELETED, NOT LEFT TO BE
OUTRANKED.** `nearestCarrier` returned "Nobody is running off with anything
right now" when the street was quiet, which was the correct refusal while
carrying was the only valid target and is now merely a true, irrelevant fact.
It was still the FIRST reason found, so it still won: measured, a plunger
thrown in an empty server came back with it, which reads exactly like the item
refusing to work. It returns nil now and the refusal is "Nobody close enough
to throw that at."

**THE END TIME IS PART OF "TAKE THE WORST", and it was not.** `applySlow` took
the minimum multiplier and the maximum stun from an overlapping penalty and
then reset `until_` unconditionally -- so a SHORT penalty landing on a long one
CUT THE LONG ONE SHORT. Harmless while every source lasted about the same time,
and an exploit the moment a 0.9s joke could be thrown at anybody: a friend
lobbing a plunger at a thief crawling off an electric fence would have wiped
three seconds of that snag. Verified after the fix -- a 4s fence snag with a
prank landing 0.4s into it still ran its full length, WalkSpeed holding 4.80
until 4.05s.

**Nothing about a real chase changed, and the target search is what guarantees
it.** A carrier is looked for FIRST at every range, then a raid drone, then
somebody to prank -- so a thief in range is still picked over a bystander
standing next to them. A prank cannot start, help or finish a robbery, because
the effect that matters in a chase still requires the target to be holding
somebody's coins.

**Nobody rides while loot is in transit, not just the two players involved.**
Blocking only the victim left any BYSTANDER free to stay on a scrambler at 33.6
and run down a thief doing 12, and `HeistService.tag` lets anyone tag. That is
not a chase, it is an execution. Server-wide is also the version that reads as
a rule rather than a restriction: when the alarm goes, the whole street is on
foot. A carry lasts seconds, so the cost is small and the drama is free.

**SHELVING IS "ABOVE THE BAR", NEVER "INSIDE A BOX".** The drop test compared
the pointer against the bin rectangle exactly -- 210 by 48 pixels -- and the
box was drawn at y H-134..H-86 while the bar's own top edge sits at H-74. So
there was a TWELVE PIXEL DEAD BAND between the two and open dead space above,
and dragging FURTHER -- the natural way to mean "get this off my bar" -- took
you straight back out of the target.

The gesture is pulling a tile off the bar, so the test is the bar's top edge
and nothing else: everything above it counts, full screen width, all the way
up. Measured, a drop 217 pixels above the threshold now shelves, where the old
band would have missed it entirely. The drawn zone is only an AFFORDANCE and
its bottom edge is placed exactly on the threshold, so what a player sees is
where the behaviour changes -- and overshooting still works, which is the
right way round for a target.

`SHELF_MARGIN` does two jobs at once because reordering runs live during the
drag and freezes over the bin: it is where the ghost turns red AND what a
release means. Sixteen pixels is past any drift in a sideways drag and well
short of a deliberate upward pull.

**THE KEY ROW CLOSES UP BEHIND A SHELVED ITEM, AND ONLY A SHELVED ITEM.** Two
things take a tile off the bar and they are not the same. A stock running out
is not the player's doing, so that slot keeps its number and the number goes
unused -- that is the rule protecting muscle memory and it stands. Shelving is
the player deliberately removing a tile, so the row closes behind it; leaving
the hole showed a bar numbered 1..8 then 0, which reads as a bug rather than
as a gap somebody made. Restoring reopens the row, so nothing is lost by
closing it -- and both paths have to repaint, because both change which keys
exist.

**THE KEY BELONGS TO THE SLOT, AND A DRAG MOVES THE ITEM BETWEEN SLOTS.** The
old rule -- one fixed item-to-key map, never renumbered -- was half right. What
it protected against is AUTOMATIC renumbering: number the tiles you can
currently SEE, 1..n, and the bar reshuffles every time a stock runs out, so the
key that threw a plunger a moment ago throws a 22,000-coin zapper. That stays
forbidden. But a DELIBERATE drag is the opposite case -- the player chose the
position, so the position is what they remember, and a tile that visibly moves
to slot 3 while its key stays 7 is the bar lying about itself.

Both hold at once because the key is an index into the ARRANGEMENT, which
contains every item whether held, empty or shelved. An empty tile is hidden and
its number is simply unused, so nothing renumbers when stock changes; only a
drag reorders. One list drives the layout AND the keys, which is the only
reason a tile's number can be trusted to match where it sits.

**A KEY LABEL PAINTED BY A RENDER FUNCTION GOES STALE THE MOMENT THE
ARRANGEMENT MOVES.** The label is dual-purpose -- the key normally, a state
word like "ON" while a buff runs -- so `HotBar` cannot own it, and ClientMain
paints it once per render. Nothing re-rendered when the arrangement changed, so
in the two cases that matter -- a saved arrangement arriving after the first
render, and a drag -- the labels kept their designed keys while the tiles sat
somewhere else. Measured: golden in position 1 still showing key 3.
`HotBar.onArranged` is the hook; it fires at the two sites that can move a key
and nowhere else.

**THE HOT BAR NAMES THE ITEM, ON HOVER AND ON USE.** Eleven tiles of 3D icons
and a number is fine once you know the bar and unreadable the first time --
this audience is nine. Hover covers desktop; USE covers touch, where nobody
hovers anything, so the same hint fires from a keypress and from a tap. The
label is parented to the ScreenGui rather than to the bar, because the bar has
`AutomaticSize.X` and re-centres as tiles come and go -- a label inside it
would slide sideways every time a stock ran out.

**THE DISGUISE KIT IS GONE, AND IT HAD NEVER WORKED.** Its `prop` named
`"bins"`, which is not a key in `Config.DECOR_ITEMS` -- there is a
`builders.bins` in Decor.luau but no catalogue entry to reach it -- so
`Decor.buildOne` returned nil and `conceal` refused SILENTLY, without spending
the item or saying anything. A 4,000-coin purchase that did nothing, and a
straight breach of "never fail silently".

What it was selling is delivered properly by the PUBLIC WHEELIE BINS
NeighborhoodService puts on the kerb, which are a live feature with their own
prompt -- so the consumable was a second, broken route to the same fantasy.
`StealthService` had both paths in one state table and the comment already
called `prop` "the old ornament disguise"; only that path went, and all six
`isHidden` callers plus `isDisguised` still work through the bins.

**THE BACKPACK COREGUI IS OFF, and for a sharper reason than the player list
is.** Roblox binds the number row 1..0 to the Backpack permanently, so its tool
hotkeys sit directly on top of this game's hot bar keys. There are no Tools
here so nothing visibly broke, but the binding is real enough that Studio's own
VirtualInput refuses to send those keys -- which is how it was found, and which
also means the keypress path cannot be exercised by the test harness. The hot
bar IS this game's backpack; two of them, one always empty, is one too many.

**AN ITEM IS HELD BEFORE IT IS USED, AND THAT IS A TELL RATHER THAN A STEP.**
Every consumable used to be spent by a single press: tap a tile, the bone is
gone. That is one input and it cost two things worth more than the input it
saved. The first is the MISTAP -- there is no confirmation anywhere on that
path and no stock cap to make a mistake cheap, so a nine-year-old stray thumb
spent a 30,000-coin Golden Bone with nothing on screen having asked. The
second is the one that matters to the street: a thief walking up somebody
driveway holding a Golden Bone is INFORMATION, read off the lawn exactly the
way ON GUARD on a collar is, and the whole consumable layer used to be
invisible until the instant it went off. This game prefers information to a
fight everywhere it can -- the guard-duty tell, the overflowing bin, the
published patrol -- and this was the one system with nothing to read.

**SELECTING IS FREE; CLICKING SPENDS.** A number key or a tile tap asks the
server to DRAW something and costs nothing; only a deliberate click out in the
world uses it. Pressing the same key again puts it away, which is what one
button means everywhere else here -- accessories, decorations and rides all
toggle.

**THE CLICK SENDS NO POSITION, and that is the load-bearing half of moving to
one.** A click is the obvious place to start sending a coordinate, and every
one of the four remotes would then have one to forge and a range check to
defeat. `BoneThrow` still carries a key and nothing else, the server still
picks the dog from its own positions and the gadget target from its own
search: the click means "use it", never "use it there".

**THE HELD ITEM IS SERVER STATE, because it is now a tell other players act
on.** Two clients disagreeing about what somebody is carrying is a bug in what
the street can read, not a cosmetic one. So `HeldItemService` validates the
stock against `data.consumables` -- the same table all four services already
spend from -- before a single part is built, and welds the prop itself. A
client-side selection with a local model would let somebody show themselves
holding a Golden Bone they do not own.

**AND THE USE IS GUARDED, WHICH IS WHAT KEEPS THE TELL HONEST.**
`HeldItemService.holding` is asked at the top of all four use paths. Without
it the prop is decoration over an unchanged remote: a bone could leave a hand
it was never in, and a defender reading empty hands would be reading a lie.
The refusal names the fix ("Hold the Golden Bone out first.") because a
rejection nobody can see is indistinguishable from a broken item.

**`HeldItemService` IS A LEAF, AND THE TWO THINGS IT CANNOT ASK ARE VETOES.**
It requires DataService and nothing else, which is exactly what lets
BoneService, GadgetService, HomeService and StealthService all require IT with
no cycle. Whether you are riding or standing in a wheelie bin cannot be asked
from down there, so `Main` registers those as vetoes -- the same shape as
`SetService.registerPusher` and for the same reason. Both states also PUT AWAY
whatever is already in hand at the moment they begin; the veto is the half a
put-away cannot cover. Verified live both ways: mounting printed "You put that
away to ride" and a later draw was refused with "Not while you are riding.",
and the bin did the same with "Not while you are hiding."

**AND THE BIN PUT-AWAY IS THE ONE WITH TEETH, for the reason the rides
already record.** `hideCharacter` walks the descendants ONCE, so a prop drawn
after concealment is not on its list and would hang in the air over the lid --
the identical trap that made a board mounted after concealment a floating
motorbike. Note bins sit ON the street, so in practice a player arrives at one
already mounted and already empty-handed; the line covers the player who owns
no ride, and that is the case it was measured on.

**AN EMPTY HAND HAS TO EMPTY ITSELF: `revalidate` after every spend.** A
player left holding a prop that refuses every click is the silent-refusal bug
wearing a picture. All four services call it after their stock decrement.
Measured: the last Dog Bone left the stock and the prop and the attribute went
with it in the same frame.

**THE PROP IS WELDED LIKE A RIDE, AND UNANCHORED IN THE SAME PASS.** All four
builders return ANCHORED parts, because all four exist to drop something on a
lawn or fly it through the air -- and an anchored part welded to a humanoid
PINS THE HUMANOID. `RideModel` builds its parts unanchored and Massless
already, which is the only reason RideService gets to skip this. Verified
against an empty-handed baseline of 15.91 studs in a second: 0.952 to 1.002
across the set, so no pin and no drag.

**MEASURING THAT NEEDED THE CONTROL-MODULE TRAP AND THE FENCE.** Two runs
reported a pin that was not there. `Humanoid:Move` driven on Heartbeat is
overwritten by the default controls every frame -- the dodge dash already
records this -- and read 0.00 studs for the held case AND the empty one; bind
above `RenderPriority.Character` instead. Then every case walked from where
the previous one stopped, so the third started against a fence and read 0.04.
Reset the start point per run and compare against an empty-handed baseline, or
the harness will keep inventing this bug.

**A HELD PROP IS SCALED FROM ONE NUMBER, NEVER TUNED PER ITEM.** These models
are authored to be seen on the ground and run 2.68 to 4.53 studs on their
longest side against a hand measuring 0.55. Every prop is scaled so its
longest side lands on `GRIP_SPAN` (1.9), so a new consumable is the right size
with nothing to remember -- the same call `PlayerGear` makes. Ten hand-picked
scales would each drift the first time a builder was touched.

**THE GRIP IS PER STYLE, and the hand own frame was measured rather than
assumed.** On a live R15 rig hand +X reads (0.99, -0.12, 0.05) in root space
and hand -Z reads (0.05, 0.01, -1.00), and the wrist attachment sits at local
+Y 0.167 -- so the arm enters from above and hand-local -Y is down the
fingers. Each entry then adds the turn that puts the model OWN long axis where
it belongs, and they differ because the builders were authored for different
jobs: a bone lies along Z, a treat along X, and the walkie-talkie is 4.53
studs tall on Y and is MEANT to stay upright. A rule that aligned every long
axis with the fingers would have laid the radio flat.

**A WIDE PROP IS TURNED FORE-AFT, NOT PUSHED OUTWARD.** The hand hangs at x
1.25 from the root and the thigh outer face is at about 1.05, so 0.2 studs
separate them and anything wider reaches the leg by construction -- measured,
the raincoat put 0.22 into RightUpperLeg. Forward cannot fix it either: the
thigh is 0.9 deep, so clearing it that way needs the coat 0.8 studs out in
front, where it reads as floating. Turned a quarter, its lateral half is 0.37
and the inboard edge lands at 0.88, measured clear at 0.00. Same trick the
shark ornament uses from the other side.

**AND THE SMALL OVERLAPS ON THE REST ARE THE IDLE ARM SWAY, NOT PLACEMENTS.**
The Dog Bone and the Golden Bone share one grip entry and measured 0.02 and
0.08 into the same thigh on two passes, which is how you know 0.08 is the
noise floor here rather than a number to chase. Only a figure that survives
across passes is a placement.

**AND THERE IS NO FAST PATH, WHICH IS THE POINT.** G threw the cheapest bone
held, and it survived one revision of this feature as a two-press draw-then-
throw before going entirely. What is wrong with it is not the keybind, it is
that it was a shortcut for ONE of the four catalogues: bones had a key nothing
else on the bar had, and BoneService was the only purchase message in the game
that taught a control rather than reporting a count. Eleven items reached
eleven ways is the thing the number row exists to prevent. Every item is now
its own number, then a click -- and the bone purchase line says "You have %d."
like the other three.

**A TOUCH IS A USE ONLY IF IT LANDS WHERE IT WENT DOWN.** A mouse click is a
click, but every camera swing on a tablet begins exactly like a tap, so the
touch path records the start and fires on release within 12 pixels -- about a
fingertip own wobble, the same slop the hot bar drag threshold uses.
`gameProcessedEvent` is what keeps a tap on the bar itself from also throwing
what it just selected, which is `HotBar.suppress` doing the same job one layer
up from the other side.

****The hotbar carries throwables, never rides.** Bones and gadgets share it
because they are the same gesture -- hold a stock, pick one, throw it -- and
two bars for one verb costs twice the phone screen to teach a distinction the
game does not make. Rides are excluded on purpose: mounting is automatic and a
ride cannot be used during a chase, so a slot for one would be inert at exactly
the moment the bar matters. Keys are FIXED per item, never renumbered to fill
gaps, or the key that threw a 1.5K plunger a moment ago throws a 22K zapper
once a stock runs out.

**THE PLAYER ARRANGES THE BAR, AND THAT DOES NOT TOUCH THE RULE ABOVE,
BECAUSE ORDER AND KEYS ARE TWO DIFFERENT THINGS.** "Keys are fixed per item,
never renumbered" is a rule about the GAME silently changing a binding
underneath somebody -- the key that threw a 1,500-coin plunger throwing a
22,000-coin zapper once a stock ran out. `HotBar.KEYS` is still hardcoded and
dragging a tile does not move it. What a drag moves is POSITION, which is the
only handle a touch player has at all: most of this audience is on a tablet,
where the number chips are decoration for a keyboard they do not own. A
keyboard player arranges nothing and keeps their numbers; a tablet player
arranges the bar and keeps their thumb. Neither changes unless the player
changes it.

**SHELVING HIDES A SLOT AND NEVER DESTROYS THE STOCK, and the reason is that
there is no stock cap anywhere in this game.** Not on bones, gadgets, home
items or the thief kit -- checked, all four are bare counters. So a destroy
button has nothing to make room for, and the only thing it could do is delete
something a nine-year-old has already paid coins for. That is the opposite of
every other rule here: a robbery never costs progress, bail is capped so being
caught is survivable, and bones deliberately survive rebirth. Dragging a tile
onto the bin takes it OFF THE BAR, in one tap, reversibly, with the item still
in the shop and still throwable by its own number key. The bin says OFF THE
BAR rather than DELETE for the same reason.

**A DRAG AND A TAP END WITH THE SAME `InputEnded`, so the throw has to be
suppressed explicitly.** `Activated` fires after the release, so without
`HotBar.suppress()` at the top of all four slot handlers a player could never
rearrange a bone without spending one. Same shape as the dodge-while-riding
suppression: the client declines to ask rather than firing something it knows
is wrong.

**THE GHOST IS A CLONE, NOT A REPARENT.** Lifting the real tile out of the
UIListLayout collapses the bar by one slot at the exact moment the player is
aiming at a gap in it. The clone follows the pointer while the real tile stays
in the bar and slides to where it will land -- and connections do not survive
`Clone`, so the copy cannot be tapped or throw anything.

**A ride lives in its own slot, and the hotbar still never carries one.** The
garage slot in the bottom-left is the answer to what the hotbar rule left
open: rides were rightly kept off the bar, but that put *which board* and
*whether one is out at all* four taps deep behind a shop tab -- fine for a
purchase, absurd for something changed on the way past a gate. The slot holds
whatever is out and fans the rest of the collection sideways when tapped, and
it changes no rule underneath: it writes the same `equipped` field the shop
tile writes, through the same `RideRequest` toggle, and the street gate still
decides whether anyone is actually riding. Keeping one server path matters --
two ways to equip is two things that can disagree about what you are on.

The slot says RIDING or READY, never just "equipped", because those are
different states: selected-but-walking is the normal thing on your own lawn,
and a slot claiming you were riding while you were plainly on foot reads as a
bug. It hides itself entirely until a ride is owned -- a control that does
nothing when pressed reads as broken rather than as locked, and the shop is
where an unaffordable ride is supposed to be advertised.

The fan opens SIDEWAYS. Five tiles stacked upward is 250px and climbs off the
top of a phone in landscape; sideways stays in the band the slot already
holds. That band is now FOUR deep in the bottom-left and none of them may
overlap -- measured at stance pill 216-250 above the bottom edge, garage slot
140-208, boost pill 86-130, item bar 20-74. The bar is centred and grows with
however many throwables are held, reaching x=20 at its widest, which is why
the slot is on its own row and not beside it.

The stance pill took the last row this corner has. Anything added above 250 is
climbing into the middle of the screen and wants a different home -- and note
the four are measured against a 546-tall viewport, which is a phone held
sideways and the shortest thing that has to work.

**SO THE FIFTH THING WENT SIDEWAYS INSTEAD, AND THAT IS THE MOVE THIS CORNER
HAS LEFT.** The dodge came over from the bottom-right and there was no row for
it: a fifth would have put its top edge at 284, which is 52% of the way up a
phone held sideways and outside the thumb that is also holding the phone --
for the one control in this game you press mid-chase. It shares the GARAGE'S
row instead, two 68-square slots side by side, and the column does not grow at
all. Rows are the scarce axis here; the rows themselves have width going spare.

**THE DODGE TAKES x=22 AND THE GARAGE MOVED RIGHT TO x=98, because the garage
HIDES ITSELF ENTIRELY until a ride is owned.** Left the other way round, every
player who has not bought a board yet would have had a dodge button floating
in the middle of an empty row with nothing to its left. The always-present
control gets the anchor. Both the picker and the stance pill derive from
`SLOT_X` rather than keeping a copy, so they followed on their own -- the
picker now fans from 174 and the pill sits above the garage it belongs to
rather than above the dodge, which is the more honest place for it anyway.

**THE MCP MOUSE TOOL DOES WORK, AND THE EARLIER NOTE SAYING IT DOES NOT WAS
WRONG ABOUT THE CAUSE.** This file records that `moveTo` "does not land where
it is aimed" and that pointer gestures therefore cannot be verified here. What
is actually true: it lands EXACTLY where it is aimed, and every earlier miss
was the coordinate being wrong. Measured this session -- a "?" chip at
AbsolutePosition (318, 273) size 22 was hit dead-on at (329, 284), which is
`AbsolutePosition + AbsoluteSize/2` and nothing else. The same click with an
eyeballed +11 fudge on Y missed a 102x38 TAB, twice; the exact centre hit it
first time.

So: derive the point from `AbsolutePosition + AbsoluteSize/2` read off the
live instance, never from a screenshot and never from the offsets in the
source -- `IgnoreGuiInset` means those two disagree by 58, which is what makes
guessing look like a broken tool. `instance_path` is still unreliable and
returned "Instance not found" for a path `GetFullName()` had just printed;
coordinates are the route that works. THAT UNBLOCKS THE THINGS THIS FILE
LISTS AS UNVERIFIABLE -- the hot bar drag, the rebirth button's Activated --
and they should be attempted rather than assumed unreachable.

**NAMING A LABEL IS WHAT MADE IT ADDRESSABLE AT ALL.** Six section headers all
called "TextLabel" in one scroll, and the "?" chip parented to one of them had
no usable path. `Section_<NAME>` fixed it. Same rule the admin panel's rows
already carry, and it is worth applying the moment a probe has to find
something.

**AND THEN THE FIRST TAB, WHICH IS THE SAME BUG IN THE OTHER SCROLLING
PARENT.** "The Everything tab has its left border cut off" was reported twice
before it was read correctly: the first two attempts went after the CARD GRID
on the Everything tab, which was never the fault. The complaint was the tab
BUTTON labelled Everything. The rail is a ScrollingFrame, its layout puts the
first tab at x=0, and a Border stroke draws outside that -- measured, the tab
at 246 against a rail starting at 246, its outline reaching 243, while every
other tab was clear. Four pixels of rail padding fixed it; seven tabs need 769
of 772, so it still fits without scrolling.

THE LESSON IS THE CLASS, NOT THE TWO INSTANCES: in this shop the clipping
parents are the SCROLLS, so any outside stroke on a first child of one needs
clearance. When it turns up again, check every scrolling ancestor rather than
the container that happens to be on screen.

**AND MEASURE BEFORE BELIEVING A DIAGNOSIS.** The front page was padded on the
theory that its card borders were merging with the panel's own -- plausible,
documented, and wrong: tinting the panel yellow at runtime and driving one
card's stroke to 12px showed the border rendering perfectly on all four sides.
Nothing there was ever clipped. The padding was left in place because it gives
real clearance and costs 4px of card, but the reasoning that produced it did
not survive a look. Two runtime tricks worth keeping: TINT THE PARENT a colour
nothing else uses, and FATTEN THE STROKE -- between them they separate "not
drawn" from "drawn and invisible against its neighbour" in one screenshot.

**A `Border` STROKE DRAWS OUTSIDE THE PART, SO THE FIRST COLUMN LOST ITS
EDGE.** Measured: the scroll's left edge and the leftmost card's left edge
were the same pixel, and `ApplyStrokeMode.Border` puts its 3px OUTSIDE that --
into the region a ScrollingFrame clips. Only the first column was affected,
which is why it read as a rendering glitch rather than as a layout mistake.
The cards cannot be moved, because a UIListLayout owns their position: the fix
is a `UIPadding` on the scroll. Anything with an outside stroke needs the same
clearance from a clipping parent.

**THE SHOP WENT LIGHT, AND THAT HALF STILL STANDS.** The HUD sits over the
world and must stay dark to keep off it; the shop is a full-screen panel with
nothing behind it to compete with, so it can be light where the HUD cannot. A
game named after a piggy bank had a brown shop.

**IT WENT LIGHT PINK, AND THAT HALF DID NOT.** The panel is SAND now -- see
the palette entry in the Theme section. The short version of why: pink MEANS
the pig here, so spending it on the largest surface in the game left the
piggy bank panel with no colour of its own. The lesson is not about pink. It
is that this game's GROUNDS have to be neutral, because both of its colours
are already carrying a meaning.

**AND THE DARK THEY STAYED WAS A PLUM, WHICH ON A PINK PANEL READ AS A
PURPLE BOX BEHIND EVERY ITEM.** `SUNK` was (58, 40, 50) -- red and blue both
well above green, so a magenta cast -- and it backs both the icon well and the
price pill, which is most of the surface area on a card.

**IT THEN WENT TO A COLD SLATE, AND THAT WAS THE RIGHT PROBLEM SOLVED WITH
THE WRONG INSTRUMENT.** The table below chose between three darks on their
contrast against gold. Re-measured across every candidate, CONTRAST CHOSE
NOTHING: they all land between 8.7 and 10.5, and the numbers in that table
are the pill's own gold rather than the well's. What actually separated them
was HUE, and slate sits at 221 while every other dark in this game is warm.
`SUNK` is `Theme.SLAB` now. The table stays because it is a good record of
what a plausible measurement looks like when it is measuring the wrong
thing.

THE SHOP WAS ALREADY HALF SLATE, which is what settled the replacement. The
cosmetic cards never used `SUNK`: they lerp their own swatch toward a
hardcoded (30, 35, 46), so the two halves of the shop had been quietly
disagreeing about what a well looks like. Adopting that slate everywhere ends
the disagreement AND measures better on both jobs this colour has:

      well colour        gold price    against the card
      plum   58,40,50       3.82           4.51
      slate  30,35,46       4.61           5.45

It is also the right NEUTRAL rather than merely a different colour. A well
backs a rendered model and this catalogue is overwhelmingly warm -- bone
white, gold, wood, red, piggy pink -- so a cool ground makes all of it pop,
where the espresso that scored almost identically (4.52) would have swallowed
the wooden houses and the golden bone. The two hardcoded lerp targets now
point at `ShopStyle.SUNK`, so they cannot drift apart again.

**THE WELLS AND PILLS STAY DARK, which is what made the inversion cheap.** An
icon well holds a rendered model and a price pill holds gold type, and both
were designed against a dark ground. Keeping `SUNK` dark means every model,
rarity tag and price reads exactly as before without one of them being
re-checked -- so the light theme is the CARD and the PANEL, not everything.

**MUTED ON A LIGHT GROUND HAS TO BE DARKER, NOT PALER, and it took two
measurements to believe it.** (150, 104, 126) gave 2.02:1 against the card and
(104, 66, 84) gave 2.89:1 -- both under the 4.5:1 body floor, both of them
still reading to the eye as "a faded ink". A mid-tone reads as faded on black
and as WASHED OUT on white; secondary type on a light card is separated from
the primary by hue and weight, not by lightness. It settled at (58, 34, 46).

**INVERTING A THEME BREAKS EVERY COLOUR THAT ENCODED STATE, and there were
thirty-eight of them.** A card's background says owned / affordable / too dear
/ locked, and all four were dark greens and greys picked against a dark panel.
Dropped onto a pink card they read as holes AND took the name printed on them
from ink to invisible. They are four light tints now (`OWNED`, `BUY`, `DEAR`,
`LOCKED`). The ones to watch are the sites a global replace CANNOT see: a
fifth green (38, 74, 60) that was not in the map, and two labels that print on
something dark or saturated -- the red close button and the shelf pills --
where flipping `TEXT` to ink was exactly wrong.

**AUDIT CONTRAST BY WALKING THE LIVE TREE, because eyeballing a repaint finds
the loud failures and none of the quiet ones.** Comparing every visible
TextLabel's colour against its own background (or its parent's, where the
label is transparent) turned up about 140 pairs under floor, including one at
**1.15:1** -- pale green on pale green, invisible, on the card selling the
game pass. Use 3:1 for large or bold type and 4.5:1 for body; the two floors
matter, because gold-on-plum at 3.66 is fine for a 15px price and would be a
real failure for a 12px blurb. Down to zero after four passes.

**A VIEWPORTFRAME CAN PHOTOGRAPH BLACK AND BE PERFECTLY FINE.** A capture
taken shortly after the shop opened showed every icon well empty, which looks
exactly like a broken preview. The tree said otherwise -- ten viewports, ten
models, ten cameras, all visible -- and a later capture showed them all. Probe
the instances before believing a screenshot of a ViewportFrame; this is the
mirror of the CSG rule, where only the screenshot can be believed.

**A BUBBLE IS CREAM, NOT ANOTHER DARK PANEL.** The first one was drawn in
`ShopStyle.SUNK` -- (42, 30, 34) against a shop base of (58, 42, 48) -- so the
single thing on the page that exists to be READ was the lowest-contrast
surface in the shop, a slightly darker rectangle on a dark screen. Inverting
it to `Theme.PAPER` with ink text costs nothing and makes it unmissable, and
it matches what every other readable thing in this game is: paper with ink on
it.

**THE EXPLAINERS WERE WRITTEN AS DOCUMENTATION AND HAD TO BE CUT TO CAPTIONS.**
They were 172 to 551 characters, several with paragraph breaks in them, which
is a page rather than a hint -- and a bubble a nine-year-old has to read four
paragraphs of is one they close. Every one is now one short paragraph carrying
only the fact that would otherwise read as a bug: the rides note keeps "a
board switches itself off away from the street", the radio keeps "you do not
choose who they chase, and it might be you", the treat keeps "a Golden Bone
still gets past". Measured on the longest, the merged bones-and-gadgets pair:
822 characters down to 307, and the bubble is 136 tall in a 571 panel.

Shortening them also removed every `

` in that copy, which is worth having
on its own -- this file has twice had a backslash sequence rewritten in
transit into the bytes it named, ending the literal and taking down the whole
HUD at compile time. There are no escape sequences left in any of them.

**A HINT BUBBLE, NOT AN INLINE EXPANSION, AND THE INLINE VERSION WAS WRONG IN
TWO WAYS AT ONCE.** Expanding the paragraph under its header did shorten the
tab, which was the point -- and it set the text at the width of the whole
scroll, ninety-odd characters a line at 13px, which reads as fine print; and
opening one PUSHED every card below it down the page, so the thing you were
looking at moved while you read about it. A bubble is a fixed narrow measure
laid OVER the tab: nothing reflows, and 14px over 330 is a readable line.
ONE bubble instance, reused by every "?", which is what makes "opening another
closes this one" free. Verified end to end with real clicks: opens under its
chip inside the panel, closes on a second tap, and closes on a tab change.

**SEVEN TABS, SPLIT BY VERB.** Your Home had become two different shops
sharing a scroll -- houses and ornaments, which are taste bought once, and
gadgets, sprinkler, treat and radio, which are STOCK you spend -- and it was
4.13 screens because it carried both. Your Gear had the same fault three ways:
a vehicle you mount, a stock you throw and a hat you wear are three unrelated
verbs. Measured after: Home 4.13 -> 2.38 screens, Gear 1.99 -> 1.00, the new
Items tab 1.73, Worn 1.00.

**A GRID HOLDING THREE ITEMS STILL TAKES A WHOLE ROW, which is what
over-sectioning actually costs.** Six one-to-three-item sections spent six
rows on ten items where two would hold them. Merging the two "throw" sections
and the two "at home" ones took Items from 2.60 screens to 1.73. THE RADIO WAS
DELIBERATELY LEFT OUT of that merge: this file already records that it gets
its own header because it is the one thing on that tab that does nothing to
your own plot, and folding it under AT HOME would describe it wrongly in the
one place a player reads about it.

**MERGING TWO CATALOGUES INTO ONE GRID COLLIDES THEIR LAYOUT ORDERS.** Bones
and gadgets both number their own items from 1, so a shared grid came out
bone, gadget, bone, gadget. The second catalogue is pushed past the first with
a +100 offset -- the same blocks-of-a-hundred idea the sections themselves
use. And the offset has to be applied AFTER the tile exists: the parent grid
is chosen at the top of the render loop and the button is not built until the
ensure call, so writing `button.LayoutOrder` beside the parent choice indexes
a nil and takes every render with it.

**A CARD'S COUNT ROW IS A COUNT, NOT A DESCRIPTION.** It fell back to the
item's `detail` when you held none -- a whole sentence, in an 11px label with
no truncation, on a 156-wide card. Measured on the sprinkler: one line ran
clean across two neighbouring cards. Every count row truncates now, and the
fallback is gone: the description lives in the section's bubble like all the
others.

**`tostring(nil)` PUTS THE WORD "nil" IN FRONT OF A NINE-YEAR-OLD.** The
merged AT HOME bubble was written to join two paragraphs, and that section
never had an explainer of its own -- the sprinkler is a joke and needs none.
Concatenating would have shipped "nil" into the bubble. Check that both halves
of a join exist before writing the join.

**THE 200-LOCAL CEILING, AGAIN, AND THE SPLIT IS WHAT SPENT IT.** Seven tabs
meant two views, two scroll triples and two indices -- ten new top-level
locals -- and the chunk stopped compiling, which does not cost the tabs, it
costs the ENTIRE HUD. It died allocating `trackMoatWater` two thousand lines
away, naming a variable with nothing to do with the change. One `SHOP` table
holds the lot, and folding the three older *_TAB indices in as well left the
chunk two registers BETTER off than before the split.

**THE LAST TAB DRAWN IN THE OLD VOCABULARY WAS THE ONE THAT COULD LEAST
AFFORD IT.** Four tabs were restyled and Defend / Rob was not, which left the
only tab in the shop that changes an OUTCOME as six flat rows with a two-pixel
stripe, floating in a 1020x578 area -- the plainest screen in the game sitting
behind the loudest card on the front page. A restyle that stops at four fifths
does not read as unfinished, it reads as that tab being unimportant.

**A LEVEL IS DRAWN AS A LADDER, NOT WRITTEN AS A FRACTION.** "Lv 3/4" is a
thing you read; four pips with three filled is a thing you SEE, and it answers
the only question that tab is ever asked -- how much have I got, how much is
left -- with no reading at all, which matters for the half of this audience
that is not reading the numbers anyway. Pips are sized `1/max` of the row, so
a four-rung tree and a five-rung one fill the same bar and the two trees stay
comparable at a glance.

**REBUILD A LADDER ONLY WHEN THE RUNG COUNT CHANGES.** Repainting is one
property per pip; tearing the row down each push would rebuild six ladders on
every coin tick, and the upgrade render runs off the same state push the coin
counter does.

**AFFORDABILITY MOVED TO THE PILL, because the card's outline was already
spoken for.** Tinting a whole row green fought the tree colour on its own
border -- and that border is the only thing telling DEFEND from ROB now the
stripe is gone. Two signals, two places: the outline says which tree, the pill
says whether you can afford it.

**A SPINNING SHOP ICON IS CHOPPY, AND NO AMOUNT OF TUNING FIXES IT.** Every
icon turned on one shared Heartbeat -- a per-frame `PivotTo` on a Model inside
a ViewportFrame, a few dozen of them at once -- and it read as juddering
rather than as lively. It is gone entirely rather than slowed: the motion buys
nothing a still three-quarter view does not already give, and a catalogue of
objects gently stuttering is worse than a catalogue of objects. The `spin`
parameter stays on `makeModelIcon` and is ignored, which is cheaper than
editing seventeen call sites for no behavioural change.

**ONE SHOP, ONE CARD SHAPE.** Throwables, home items, the thief kit and the
rides were drawn as narrow ROWS -- a 48-pixel icon with three lines of text
beside it -- while skins, houses and decorations were cards. Same shop, two
shapes, and the row-shaped half read as a settings list rather than as things
to want. Rows also waste the width they are given, which is most of why a tab
took several screens. All seven builders now share the card the cosmetics
already used, and the conversion was mechanical: the icon moves into a well on
top and the labels move under it.

**A SCALED GRID CELL NEEDS A UISCALE ON THE CARD, and forgetting it looks
exactly like a layout bug.** `refitCards` shrinks the CELL on a short panel,
but a card's internal positions are pixels and do not follow. Measured on the
converted tiles: the cell went to 0.78 while the price row stayed at y 143, so
pills rendered outside their own cards and the next section header landed on
top of them. The cosmetic card had always registered a `UIScale`; the seven
new ones now do too.

**THE SHRINK THRESHOLD WENT FROM THREE ROWS TO TWO, WHICH REVERSES AN EARLIER
DECISION ON PURPOSE.** The old rule shrank as soon as fewer than three full
rows fit, on the argument that twelve big items lose to twenty-one slightly
smaller ones. That was right when a card was a name, a description and a price
stacked on a swatch -- a list entry, where more entries visible is better. The
card is now mostly PICTURE and the description has moved behind a "?", so what
is being optimised is whether an item looks worth having, and shrinking a
picture to fit more pictures on defeats it. A phone held sideways still gets
the smaller card, because it cannot show two rows of anything.

**THE DESCRIPTION MOVED BEHIND A "?" ON THE SECTION HEADER.** The explainers
are genuinely worth keeping -- the rides one states that a board switches
itself off away from the street, which somebody needs BEFORE spending four and
a half million coins -- but at 92 pixels each they were most of a tab's
length. Collapsed, a UIListLayout skips them entirely, so the shop is short by
default and the words are one tap away. The per-card blurb went altogether: a
156-wide card carrying a name, a line of prose AND a price is three rows of
text on a picture. A player who has stopped to look at one item is reading; a
player scanning a shelf is not.

**COPY OUTLIVES THE THING IT DESCRIBES, AND NOTHING ERRORS.** The SNEAKING
section still sold "hide as a wheelie bin" as something on that shelf -- the
Disguise Kit, retired a while ago, whose fantasy is now delivered by the free
public bins. `ThiefModel`'s header comment explained at length why the kit's
tile showed a holdall rather than a bin, reasoning about a tile that no longer
exists. Neither is reachable from any test: retiring an item prunes its DATA
and leaves every sentence written about it standing. Grep the player-facing
strings for a retired feature's name in the same pass that retires it.

**A REGEX THAT MATCHES A WIDGET BY VARIABLE NAME WILL MATCH THREE OF THEM.**
Deleting the card blurb with a pattern on `local blurb = ...` also deleted the
upgrade tree row's blurb -- which is LIVE STATE, rewritten every render because
the dog's blurb names its next breed -- and the Style Pack banner's, which is
the only thing selling the pass. Neither is a card and neither was in scope.
Both were caught by grepping the surviving references (`row.blurb.Text`,
`blurb.Text = pass.blurb`) rather than by anything failing, because a nil
global here dies at render time and not at compile time. Count the matches
before a bulk delete, and check what still reads the name afterwards.

**THE SHOP WAS BORING, AND BORING WAS A CHOICE NOBODY MADE ON PURPOSE.** It
grew a tab at a time and every tab was drawn in the HUD's own vocabulary --
flat dark rectangles, 2-pixel edges, 13-pixel Gotham. That vocabulary is
CORRECT for the HUD, which sits over the game and must never compete with it,
and exactly wrong for the one screen a player opens deliberately and then
reads for a minute. The HUD's job is to disappear; the shop's job is to be
worth opening. `Shared/ShopStyle.luau` is the second vocabulary -- outline,
round, gloss, pop -- and it is a MODULE for the reason HotBar and AdminPanel
are: ClientMain is at the 200-local ceiling, so the whole kit costs one local.

**A UIGRADIENT CAN ONLY DARKEN, WHICH IS WHY A "SHEEN" IS BUILT UPSIDE DOWN.**
`Color` MULTIPLIES the fill and channels cap at 1, so there is no way to add a
highlight with it. The first gloss tried to fake one through `Transparency`
instead, which does not lighten anything -- it makes the object SEE-THROUGH.
Measured on the live panel: the gold coin pill rendered as a dark olive smear
with the panel showing through it. So the fill is authored at the LIT value
and the gradient darkens downward. Same picture, and the only one the engine
can actually draw.

**A DARK OUTLINE ON DARK TEXT IS A SMEAR, so `chip` decides by LUMINANCE.**
Popping type exists to hold pale text off a bright fill. Applied to text that
is already dark it just thickens the glyphs -- and dark-on-light needed no
help, which is why it was chosen. One test on the text colour, not a flag per
call site.

**A GUIOBJECT TAKES ONE UISTROKE, so the shop's dark edge and the rarity edge
cannot both be on a card.** Rarity wins, because it is the one carrying
information: it went to 3 pixels (5 for Legendary) and IS the card's outline
now. Legendary keeps both channels -- hue AND weight -- which is the
colour-blind case the thicker border was introduced for.

**ONE BAND BEAT TWO, AND IT MADE THE CONTENT WIDER RATHER THAN SHORTER.** The
header was a title at 12, a glyph rail down the left from 44, and content from
86. The title existed for exactly one reason, written down at the time: THE
RAIL WAS GLYPHS, so the open tab's name appeared nowhere else. Putting the
words ON the tabs makes that label redundant and frees the whole band.

The measurement is the point, because "a horizontal bar costs height" is the
obvious objection and it is wrong here. A VERTICAL rail costs WIDTH forever,
and one wide enough for words costs about 96 of it. At the 1040 cap: the old
rail left 950, which takes FIVE 156-wide cards across (six needs 976); a
labelled vertical rail would have left 910 and still five. The horizontal band
leaves 1020 x 578 -- six across and three down, 18 visible against 15, with
the tabs finally readable. Note the "six across" recorded earlier was true at
a 148-wide card and quietly stopped being true at 156.

**THE SELECTED TAB IS THE ONLY ONE WEARING ITS COLOUR.** Painting all five
their own hue at once looks livelier in a mockup and is unreadable in use:
five saturated buttons in a row have no winner, so nothing answers "where am
I" -- which is the only question a tab bar exists for. The active one also
stands taller, the same two-channel argument Legendary's border makes.

**EVERY CATEGORY OWNS A HUE, AND THAT IS NAVIGATION.** The shelf card and the
tab it opens are the same colour, so the trip from "the pink one" to the skins
is one recognisable colour rather than two words a nine-year-old has to read
twice. Previews sit in a SUNK, desaturated well of that hue rather than on it
-- a pink piggy on a pink card disappears, which is the failure the item
card's own swatch already had to solve by lerping toward the panel.

**THE FRONT PAGE'S CELL IS IN SCALE, NOT PIXELS, so "one screen, no scrolling"
keeps its own promise.** Three cells of (1/3 - 8) with 12 of padding come to
exactly the parent width -- 3 * (W/3 - 8) + 2 * 12 = W -- at every panel size,
so the grid fits on a desktop and on a phone held sideways with no resize
handler and nothing to keep in step. The old cell was a measured 224x158
against a content area that has since changed twice. It is also a plain Frame
now rather than a ScrollingFrame: a scroll here was a standing invitation for
the front page to quietly become scrollable, which is the one property it may
not have. Verified at 8 cards, lowest edge 548 against a shelf bottom of 548.

**"EVERYTHING" DID NOT CONTAIN EVERYTHING.** It mapped the seven cosmetic
catalogues and silently omitted Defend / Rob -- the one tab that changes an
OUTCOME rather than how something looks -- while leaving two empty cells in
the grid where it belonged. The eighth card is built outside the shelf loop
because it has no catalogue behind it: nothing to count, preview or price, so
running it through that loop would have meant a branch at all four points. A
BIG GLYPH stands where the three preview wells go, since three empty wells
beside seven full ones reads as a card that failed to load.

**THE HOT BAR IS SUPPRESSED WHILE THE SHOP IS OPEN, through the hook that
already existed.** The bar is pinned to the bottom of the screen and the panel
is 0.86 of it, so the tiles were drawing over the bottom shelf of the front
page. `HotBar.shouldShow` already refuses to show a bar with nothing usable on
it -- a row of throwables a player cannot throw while reading a shop is the
same "looks available, does nothing" control -- so this is one clause, plus a
`Visible` watcher, because the bar only re-asks when a stock changes.

**A SECTION HEADER IS A SIGNPOST AND IS SET AT THE WEIGHT OF ONE.** At 13px
grey Gotham it was quieter than the item names underneath it, which inverts
the hierarchy: the thing you scan for while scrolling was the faintest text on
the screen.

**THE SHOP PREVIEWS STILL ANIMATE, AND THAT IS RECORDED AS AN OPEN QUESTION
RATHER THAN A DECISION.** Measured after the rework: 158 of 469 preview parts
change colour within 0.6 seconds, so the skin cycling, the effect simulation
and HouseFX are all still running inside the tiles. They were kept because
they are what tells Rainbow from Prismatic at a glance -- the same argument
that put rendered models in the shop in the first place. If they should go,
the three places to cut are `watchShopPiggy`, `makeEffectIcon` and the
`HouseFX` tag on house cards, and the cost is that those three catalogues
become stills.

**A TAB RAIL THAT DOES NOT SCROLL SILENTLY EATS TABS.** Eight tabs at 48 plus
8 of padding is 440 pixels; the rail on the old 620x420 panel was 368. Rides
and Collection were measured at 433 and 489 against a rail ending at 417 --
both drawn past the edge, both unreachable, and nothing on screen to say they
existed. A UIListLayout does not clip and does not error: it just keeps
drawing, so the shop looked like a deliberate six-tab shop. The rail is a
ScrollingFrame now, which cannot have the bug at any panel size or tab count.
The bigger panel fixes it today; the scroll is what stops the ninth tab
bringing it back.

**EIGHT TABS BECAME FOUR, AND THE CLUTTER WAS NEVER THE BIG TABS.** Counted
before anything moved: Bones held three items, Gadgets three and Rides five.
Eleven of the catalogue's eighty-one taking three of the eight rail slots, so
more than a third of the navigation led to tabs you visit once and never
again. Your Piggy carried twenty-seven in two headed sections and read fine,
which is the shape the merge copied. The grouping is by WHAT THE PLAYER WANTS
rather than by what the thing is -- Defend / Rob, Your Piggy (worn), Your Home
(your plot and defending it), Your Gear (what you take out robbing) -- which is
the same split the upgrade tab already names, so the shop and the trees now
describe the game the same way round.

**SUB-TABS WERE THE OTHER OPTION AND ARE WORSE.** Every section in the shop is
already a HEADER you can see while scrolling past it; a sub-tab replaces that
with a button you have to press and puts every item one tap deeper. This file
had already written that lesson down for the garage slot, where "four taps
deep behind a shop tab" is the bug the slot exists to fix. Merging tabs IN is
the move; splitting inside one is not.

**MERGED SECTIONS ALLOCATE LAYOUT ORDERS IN BLOCKS OF A HUNDRED, and that is
not tidiness.** Three tabs' worth of sections now share a UIListLayout and are
still WRITTEN in the order the old tabs were built, so a second group starting
at 1 again would interleave itself through the first -- silently, with nothing
on screen to say why the driveway ornaments were sitting between the houses. A
block also means inserting a section never renumbers a neighbouring group.

**THE SHOP OPENS ON A MAP OF ITSELF: SEVEN SHELVES, ONE SCREEN, NO SCROLLING.**
The merge fixed the rail and made the scrolls longer -- Your Home is 3.55
screens on a phone held sideways. So the front page shows every category at
once with three real items in each and a tap that lands you ON the section.
A front page you have to scroll to read is a ninth thing to navigate rather
than the answer to navigating, which is why the cards are measured against the
panel (four across, two down, 224x158 in a 950-wide content area) and the
previews are deliberately small.

**THE THREE PREVIEWS ARE CHOSEN BY STATE, NEVER "the first three".**
Affordable and unowned first, then unowned, then owned -- so a shelf always
leads with something the player could walk away with, and visibly changes as
they get richer. Items 1-3 of a catalogue somebody finished a week ago is dead
space in the most valuable spot in the shop. Three passes rather than a sort,
because within a rank the catalogue's own order has to survive: sorting by rank
alone would shuffle twenty-one skins into a new arrangement every coin tick.

**NOTHING ON THE FRONT PAGE RE-IMPLEMENTS A CARD.** The shelves show ICONS and
a COUNT, and the count is the only stateful thing on them. A second, smaller
version of the real card -- with its own owned/equipped/price branches -- is
the copy that drifts from the original the first time either is touched, which
this file already argues about `Decor.buildOne` and the mini piggy. The model
builders are shared and there is only one line of state logic, so there is
nothing to keep in step.

**A SUMMARY OF SIX REMOTES IS DIRTY-DRIVEN, NEVER CALLED FROM THE SIX PLACES
THAT FEED IT.** Two separate bugs made that necessary and the first cost an
hour. The catalogues arrive on six different remotes at join in no fixed order,
so rendering from the handler that happened to be edited first drew five
shelves and left rides and throwables permanently blank -- they had simply not
arrived yet. And the obvious second hook, the coin tick, IS NOT A TICK: state
is pushed on CHANGE, so a player sitting on a full piggy bank generates no
updates at all and the front page had no reason to ever look again. Measured at
exactly three renders in a whole session. Every data site sets `dirty` and one
Heartbeat drains it, above the closed-panel early-out so the shelves are right
at the instant the panel opens.

**A JUMP INTO A NEVER-OPENED TAB MUST CONVERGE, NOT FIRE ONCE.** A hidden
frame's descendants carry stale `AbsolutePosition`s, so a single deferred read
after `selectTab` is measurably wrong the FIRST time a tab is opened and right
every time after -- the worst shape a bug can have, because it works whenever
you go looking for it. Measured: the first jump to the accessories computed an
offset of 0 and landed at the top of the skins, and the identical second click
landed at 614. The jump now re-reads where the target actually is each frame
and stops once it is already there, usually in one or two, so a stale read
corrects itself instead of being guessed around with a frame count.

**A SECTION'S JUMP TARGET IS WHAT YOU SHOULD BE LOOKING AT, WHICH IS USUALLY
THE HEADER AND DELIBERATELY IS NOT ALWAYS.** The accessories land on the ROLL
button rather than on HATS: the roll sits above that block and is the entire
point of it, so landing on the first header would scroll the one control in the
section off the top of the screen.

**The panel header NAMES THE ACTIVE TAB, because the rail is glyphs.**
`tab.title` was being stored by `makeTab` and read by nothing, so the name of
every tab existed in the source and nowhere on screen -- eight emoji and no
words, for an audience that is nine. The coin balance that used to occupy
that label moved right rather than being dropped: it is the number every
price on the screen is read against.

**A shop tile's size is MEASURED against the panel, never chosen.** The first
card was 158x150, which looked right and measured wrong: five across, three
down, and the piggy tab went from 1.9 screens of scrolling to 3.2. At 148x132
it is six across and four down -- 24 items visible against the old row's 15,
and 1.5 screens instead of 2.3. Cards get taller faster than they get more
legible, and the only way to know which side of that line one is on is to
compute columns and rows against every viewport that matters.

**Short screens get the SAME card, scaled -- never a second layout.** A phone
held sideways gives the panel 322 pixels and the grid 266 of that, which is
one row of full-size card where the old text row fitted three. A `UIScale` on
the card takes the whole thing with it -- swatch, both text rows, padding and
type -- so there is one design and no second set of offsets to drift. The
trigger is derived, not a magic height: shrink as soon as fewer than three
full rows fit, which also catches a short-but-wide desktop window (1513x546
gives 469 of panel, and twelve big cards lose to twenty-one slightly smaller
ones). 0.78 is the floor -- it takes the 14px name to 11, and a third step
would buy one more item per screen at the cost of the reason anyone is
looking at it.

**An effect had nothing to show, so it showed nothing -- for 600,000 coins.**
Effects were the one cosmetic built with no swatch, on the reasonable grounds
that a particle system has no still image. That produced eleven identical
grey tiles covering the top end of the shop. The two ends of the effect's own
`ColorSequence` are the honest answer: Inferno reads as fire and Frost as ice
without rendering a particle. The same two-tone treatment carries the skins,
where `body` into `trim` is what actually distinguishes Bubblegum from
Sunset -- a single flat rectangle cannot, and a 14-pixel stripe down the side
of a text row was showing about a fiftieth of it.

**ONE RARITY LADDER FOR THE WHOLE SHOP, and the bands are ABSOLUTE COIN
AMOUNTS.** Common / Rare / Epic / Legendary started as the accessory roll's
weights and are now what every collectable in the game is bordered with,
which is why the table is `Config.RARITIES` rather than
`ACCESSORY_RARITIES`. The bands are global — 100K, 1M, 10M — and never
fitted per tab. That means the effects tab tops out at Rare, because Inferno
is the loudest thing in it and still only costs 600,000, while houses spend
three tiers at Legendary. That gap is the economy telling the truth. A
border that meant "expensive FOR AN EFFECT" would be four different ladders
wearing one set of colours, and the gold on a Sky Castle would stop meaning
anything.

**A tier is DERIVED, never hand-tagged, and `Config.rarityOf` reads three
sources in a fixed order.** An explicit `rarity` wins — the ten drop-pool
skins and all twelve accessories have one because they are not bought at
all, so there is no price to read and the rarity is what decided how likely
they were. Then `unlockRebirths`, because a reset-locked skin is also
unpriced and what it costs is resets. Then the PRICE, for everything else,
because in this economy the price IS the rarity: there is no drop rate to
express. Deriving is what keeps it honest as the shop grows — a decoration
added at 12 million is Legendary the moment it is priced, with nothing else
to remember. Hand-tagging sixty items means re-tagging them every time a
price moves, and the tag that gets missed is the one that lies.

**Only things you KEEP get a tier.** Skins, effects, houses, decorations,
accessories and rides carry a border; bones, gadgets, home items and the
thief kit deliberately do not. A tier on something you rebuy every time you
throw it describes a purchase you will make a hundred times, which is not a
rarity. That line is also why the hot bar has no borders on it.

**The tier goes on the EDGE, because every other part of the card is
taken.** The swatch is what the item looks like and the background is
whether you own it or can afford it — painting the background by rarity
would have fought the affordability colour that was there first, and tinting
the swatch would have lied about the skin. Legendary is drawn thicker as
well as gold: colour alone separates four tiers only for players who can see
four, and blue-against-purple (Rare against Epic) is exactly the pair that
goes for a colour-blind nine-year-old. And the tier is spelled out on a chip
over the swatch, because a colour nobody has been taught is decoration —
measured at 60px wide, since "LEGENDARY" renders 55 at 9px GothamBold and
the first attempt at 52 clipped it.

**A catalogue with no price needs something in the price row.** Putting
borders on the skins tab exposed that the ten drop-pool skins had nothing
left to say: not equipped, not unlocked, no `unlockRebirths`, and a missing
`cost` that arrives as 0 — so all ten fell through to the price branch and
rendered "0" in gold on the you-can-afford-this green. The rarest items in
the game each advertised themselves as free, and tapping them did nothing
because the server correctly refused. They say REBIRTH DROP now. Any future
branch that ends in `format(info.cost)` needs to ask first whether the thing
has a cost at all.

**A FIELD THAT WAS ALWAYS THERE BECOMES OPTIONAL THE FIRST TIME IT ISN'T,
and the reader that never asked is the bug.** Every home item had a
`duration` until the Patrol Radio, which has none -- it is a phone call, and
what it starts is a patrol with its own published clock. The shop row was
`("%s . %s"):format(durationText, price)` with an unguarded `info.duration >= 60`
inside it, so the new item did not render a wrong number, it errored. That is
the same shape as the ten drop-pool skins rendering "0" in the price row, and
it has the same fix: before formatting a field, ask whether the thing has one.
The radio's row is the price on its own.

**A key may be shared, but only between states that cannot both be live --
and then the client must SUPPRESS the loser, not let the server refuse it.**
Q is the dodge on foot and the trick on a ride, which is safe because
`HeistService.dodge` refuses outright while a ride multiplier is set: you do
not roll off a moving scrambler, so a rider pressing Q has exactly one thing
it could have meant. One key doing the one available thing is one fewer key
to teach, and this audience is nine.

The trap is that the refusal is LOUD -- "Not while you're riding" -- which is
right for a press that meant a dodge and wrong for every single manual. So
the client does not fire the dodge while `ridingNow`, the same shape as the
number keys, which do nothing for an item you do not hold rather than firing
a remote the server will only reject. The server keeps the authority; the
client just stops asking for a known no. **Sharing a key without that
suppression is the bug, not the sharing.**

The touch half is the same decision and is easy to forget: the DODGE button
hides while riding and the trick button appears. Most of this audience never
presses a key at all, so a live-looking button that does nothing is the
version of this bug that most players would actually meet.

The map as it stands: Q dodge / trick, B opens the shop, V opens the garage,
Escape closes the panel, F2 the admin console, and the number row is the
hotbar. G IS FREE: it threw the cheapest bone held, which was a second route
to using an item and a special case for exactly one of the four catalogues --
so bones were the only things on that bar with a shortcut, and BoneService was
the only purchase message in the game that taught a control. Every item is
reached the same way now: its own number, then a click. A new binding gets checked against this
list, and against whether it is genuinely exclusive with what it lands on.

**A bone buys a window, never the dog.** Bones are the offence tree's answer to
the one defence purchase that had none, and the same line governs both: defence
buys *time*, never immunity — and so does the counter. Four things keep a bone
from deleting the thing it counters, and removing any one of them breaks it:
it costs coins **every time**, so farming a guarded plot is an ongoing expense
that scales with how well guarded it is; a nap is always **shorter than that
breed's own cooldown**, so waiting out a real chase stays the cheaper option;
bigger dogs resist (`boneResist` 1.0 / 0.8 / 0.6); and **only the Golden Bone
interrupts a chase**, so the other two have to be thrown *before* the dog
notices you. That last one is what makes a bone a plan rather than a panic
button.

**A dog has TWO clocks, and only one of them answers to guard duty.**
`busyUntil` is the cooldown the dog earns by finishing a chase, and the Guard
Duty Treat exists precisely to suppress it. `napUntil` is a nap a thief *bought*
with a bone, and guard duty must never suppress that — the only bone that can
set one has already paid to get past the guard-duty gate.

Both used to be `busyUntil`, and the Golden Bone therefore bought nothing on a
guarded plot: `lure` let it through the gate, stamped the field, and
`onCooldown` — which reads `... and not onGuardDuty(dog)` — threw the stamp
away again for the next six minutes. The dog kept patrolling on a 30,000-coin
bone. Worse, `BoneService` compared `os.clock() < dog.busyUntil` *raw*, so it
called that same still-patrolling dog "already off duty" and refused every
later throw. Two readers, one field, disagreeing in opposite directions, and
the item's own shop text ("Cheap bones bounce off. A Golden Bone still works")
promising the behaviour neither of them delivered.

Ask `GuardDog.isOffDuty`, never a raw field. The note above `onCooldown` says
the comparison lives in one place — `BoneService` had already copied it out,
which is how it drifted the moment a second clock existed.

**A bone throw sends no position.** The client fires `BoneThrow` with a bone key
and nothing else; the server picks the target from its own dog positions. There
is no coordinate to forge and no range check to defeat. It also auto-targets the
nearest eligible dog rather than aiming — most of this audience is on a
touchscreen, where lobbing an object at a moving dog is a fight with the camera,
and "get it near the dog" was never the interesting decision.

**Bones survive rebirth.** Every other offensive purchase is wiped. A bone is
spent the moment it is thrown, so a stockpile is not standing power the way a
maxed tree is — and wiping it would only teach players to burn their stock the
hour before rebirthing, which is a chore, not a decision.

**THERE IS NO NIGHT IN THIS GAME, so a light is the wrong instrument and
NEON is the right one.** `WorldService` sets `ClockTime = 14.5` exactly once
and nothing anywhere else ever touches it. The endgame tiers were nonetheless
built on four `lantern()` calls, and `Config.HOUSE_TIERS` says in as many
words that they "light up at night so they read in the dark too" -- describing
a state the game never enters. That was the whole reason the top of the ladder
read as vanilla: at `Brightness = 2.4` in full sun, a PointLight at brightness
0.9 over an 18-stud range is invisible from a street 100 studs away.

Neon is the one material that ignores the scene entirely. It renders at full
saturation in daylight and the BloomEffect already in `WorldService`
(threshold 1.1) blooms it for free, so every animated effect on a house is a
COLOUR WRITE ON AN EMISSIVE PART and the few real lights left are garnish. If
a day/night cycle is ever added none of this changes -- neon reads in both.

**`glow` IS A LANTERN COLOUR AND `fxGlow` IS A NEON COLOUR, and they are not
allowed to be the same field.** This file already recorded that the palace's
glow was pulled back from (255, 226, 150) because it "bloomed hard against
marble walls of almost the same colour" -- correct, for a lamp. Neon is not a
lamp: it renders that value flat out, so the same pale cream that reads as a
warm bulb reads as a hole cut in the building. Measured on the first build of
the lit colonnade and steps: nine emissive parts in `glow` came out as ONE
WHITE BLOB across the whole frontage with nothing in it anybody could name.

The fix is a saturated hue, not a dimmer one -- the effects have to still say
GOLD at full brightness, and only a colour a long way from white can be seen
against white marble. The two light-walled tiers therefore carry both fields.
The Neon Tower carries `fxGlow` identical to `glow` on purpose, because its
bands `cycle` and override the hue every frame: all that colour contributes
there is its SATURATION, and 0.61 is what gives a vivid wheel rather than six
pure primaries that read as a test pattern.

**A LIGHT INSIDE ITS OWN PLINTH IS STILL A LIGHT, and it is invisible.** The
palace's column uplights were placed at the columns' own base, y 1.1 -- which
is inside the three-step plinth that stacks to y 2.1, because the columns
start under it and emerge through it. Six emissive parts entirely within solid
marble. Anything placed at a "base" gets measured against what is actually
stacked there rather than against the part it belongs to.

**A PART'S NAME IS NOT UNIQUE, because a house is one flat folder.** The
castle's four turret finials are all called `Finial`, so
`folder:FindFirstChild("Finial")` returned the same first turret on all four
passes and every light would have stacked on one corner -- and the palace
builds a part with that name too. Hold the reference the builder just
returned; never look one back up by name in here.

**HOUSEFX IS THE THIRD CLIENT-SIDE ANIMATOR, and it is a MODULE rather than
another inline section.** Same shape as the animated skins and the moat: the
server builds the geometry, tags it `HouseFX`, stamps attributes saying what
each part should do, and never touches it again; every client runs one shared
Heartbeat over what it can see. Driving it server-side would be a replicated
colour write per part per frame -- twelve plots of forty parts is around
twenty-nine thousand property updates a second to say something derivable
from a clock and a string.

It is a module and not a `do` block beside the other two because `ClientMain`
is at Luau's 200-local ceiling: a function body gets its own register file, so
the whole feature costs this chunk ONE local instead of a dozen. That is now
the default for any new HUD-adjacent system, not a special case.

**EMISSIVE GEOMETRY ANIMATES IN A VIEWPORTFRAME FOR FREE, which is the
positive half of the rule about particles.** A ViewportFrame renders BaseParts
and nothing else -- so a light show built out of emitters or lights would be
invisible on the card selling a hundred-million-coin house, and that is most
of why this is neon. Built out of tagged neon parts it renders on the tile
exactly as it does on the lawn, and the shop tiles join the animator by tag
with no second implementation. Measured live: 88 tagged parts inside the shop's
house cards, with every one of the six effect kinds showing a real per-frame
delta inside its viewport.

**AN ORBIT TURNS ABOUT A POINT ON THE PART'S OWN AXIS, NEVER ABOUT THE MODEL
PIVOT.** Orbiting the pivot is the obvious version and it is not reliable
anywhere: a Model with no PrimaryPart takes its pivot from wherever
`WorldPivot` happens to be, `House.build` moves the model twice while seating
it, and `makeModelIcon` resets the pivot to identity at the VISUAL centre for
a shop tile. The same ring would turn about three different points in three
places, none of them chosen. Each part carrying its own radius makes the
centre a fact about how the ring was authored, which is the only place it is
actually known.

**THREE FLASHES A SECOND IS THE ACCESSIBILITY CEILING, and `MAX_RATE` is what
makes that a property of the file.** The standard treats a flash as a 10%
luminance change over 20% of the screen, and more than three a second as
unsafe. This audience is nine. So there is no strobe anywhere in `HouseFX`:
every effect is a continuous curve, no tier may ask for more than 0.9 cycles a
second however it is authored, the one effect that genuinely blinks sweeps
like a lighthouse rather than switching, and the castle's four finials are
phased a quarter turn apart because four corners pulsing in lockstep is the
one arrangement that reads as a single full-screen flash.

**Luau forward references, SIXTH time: `glowPart`.** Written next to
`lantern`, which sits BELOW every builder that calls it, so it compiled
against a nil global and died at the call with "attempt to call a nil value"
naming neither the function nor the cause. It lives above `builders` now. The
rule has not changed and neither has the failure: when something reads nil and
the message names nothing useful, check declaration order first.

**The top three house tiers sell HEIGHT, because that is the only thing visible
from the road.** A house stands 70 studs behind its own piggy, so up to the
Midnight Modern the driveway has been doing the announcing and the building
itself is a distant shape. The Neon Tower, Marble Palace and Sky Castle go up
rather than out -- 64, 41 and 59 studs against the manor's 35 -- so they clear
the grove behind the plots and read from anywhere on the street, and each
carries emissive detail so they read at night too. Adding a fourth wide house
would have added nothing nobody could see.

**The plot sign carries the boasts, hardest first.** Rebirths, then the house,
then the skin. The house is on there because it is otherwise the least visible
expensive thing anyone owns: past the first few tiers a passer-by cannot tell a
1.4M manor from a 40M palace at that range. The Starter Shack is deliberately
never named -- a sign announcing the free tier reads as a jeer at players who
have not bought anything yet.

**Anything that changes how a plot should LOOK goes through
`CosmeticsService.applyToPlot`.** It is the one function whose job is making the
plot match the data. Buying a house used to call `PlotService.setHouseLevel`
alone, which rebuilt the building while the sign went on announcing the old one
until the player next rejoined.

**Every plot has a house, owned or not.** `buildPlot` returned `house = nil`
and nothing built one until somebody bought a tier, so an unclaimed plot was a
bare slab with a piggy on it and no driveway either — the drive is only ever
built inside `setHouseLevel`. `PlotService.start` now seats the Starter Shack
on every plot as it builds it. Level 0 is the free tier every player already
owns, so showing one on an empty plot is honest rather than generous.

`release` resets it too, and that was the sharper half of the bug: it wiped the
fence, the dog and the lock but never the house, so a player leaving with a Sky
Castle left the Sky Castle standing on an unclaimed plot until somebody else
took it over.

**A house is bought as a ladder and worn as a shelf.** Two numbers, not one:
`houseLevel` is the highest tier bought and decides what is for sale next,
`houseShown` is the one actually standing. Only the next rung is ever for sale,
but any tier already owned can be moved back into for free, both ways, forever
— so there is no sell-and-rebuy loop to farm. A house is pure taste, the top
tiers cost tens of millions, and forcing someone who liked the Beach Villa to
live in a Neon Tower because they bought one turns a status symbol into a
punishment. Read the pair through `Config.getShownHouseLevel`, never
separately, and note the sign names the house that is STANDING — announcing a
Sky Castle over a villa is a boast about a building that is not there.

**A ride is for the street, and is switched OFF everywhere else.** Rides run
straight into "speed is the currency": the scrambler doubles `BASE_WALK_SPEED`,
which is the number the carry penalty, the three dog speeds, every fence snag
and the 37-stud getaway are all calibrated against. So the whole design is the
conditions that disable it -- carrying loot, being robbed, snagged on a fence,
or not standing on the street. Drop any one and a specific system dies: a thief
rides away from a three-second getaway, or a defender at 33.6 catches every
thief who ever tried at 12. What is left is the walk between plots, which was
the one part of this game that was pure holding W. Like a house, a ride confers
nothing else.

**"On the street" is narrower than "not in a yard", and the gate tests both.**
`Config.isOnStreet` is the positive rule and the one players are told: the
corridor between the two rows of front fences, plus the arrival plaza. It rules
out the woodland behind the plots and the twelve-stud alleys between
neighbouring yards -- public ground, but not a street, and not somewhere anyone
should be crossing at 33 studs a second. `PlotService.yardContaining` (the
FENCE rectangle, not the plot slab) is then a veto on top. The two cannot
disagree with the plots where they are, but one of them is balance-critical and
the other is tidiness, so the yard test runs first and fails safe. Because
`isOnStreet` needs to know where the street ends, the plaza and road extents
now live in `Config.streetMetrics()` -- which is memoised, since the ride gate
asks it ten times a second per player.

**A RIDER'S POSE IS AN ANIMATION, for exactly the reasons the dodge roll
is.** Same rig, same dead ends: `AnimationConstraint.C0` is read only,
`Transform` is a read-back rather than an input, and the animation system is
the only thing allowed to drive these joints. So `RidePose` builds a
KeyframeSequence per ride STYLE at runtime and registers it, and the server
publishes a `RideStyle` attribute that every client poses from itself —
because a `hash://` id cannot replicate. Styles with no entry (scooter,
hoverboard, scrambler) get no pose and keep the old rest pose, which is a
working state rather than a gap.

Stopping the walk cycle on mount was right; leaving NOTHING in its place was
not. The rest pose is arms-at-sides, feet-together — plausible on a
hoverboard, and on the BMX it stood the rider bolt upright a foot behind
their own handlebars.

**MOVE THE BIKE TO THE HAND, NEVER THE HAND TO THE BIKE.** Posing a rider to
reach a fixed handlebar is inverse kinematics with no solution when the bar
is out of reach — and the BMX's was. So the pose is measured first on a live
rig, hand and foot positions are read back in ROOT space, and the ride's
contact points are placed at what came back. That direction always has an
answer. Verified end to end: hand-to-grip 0.06 studs, sole-to-pedal 0.07,
pelvis-to-saddle 0.00, and both skateboard soles within 0.07 of the deck.

**A REAL BICYCLE DOES NOT FIT A ROBLOX CHARACTER, and no animation fixes
that.** The old BMX was authored at honest proportions — 2.5-stud wheels, a
4.3-stud wheelbase — and measured against a seated rider it was unrideable:
the saddle sat 1.5 studs BEHIND the hips and 0.89 above the pelvis, and the
saddle-to-grip span was 3.35 studs against an arm that reaches 2.10. Sit down
or hold on, never both. Dropping the rider onto the saddle instead put the
pedals 2.5 studs below a leg 1.5 studs long. The rig is five studs tall with
short limbs, so the bike is now sized to the RIDER — same call the deck
above already made, except what is visible here is a child sitting on it.
Anything else anyone wants a character to sit on gets measured the same way
before it gets built.

**`stand` is what the rider STANDS on, so a seated ride has none.** It is 0
for the BMX — not a missing value — because a seated rider is held up by the
saddle, which is placed under the pelvis where it already is; raising them
would lift them off it. And it is 0.85 on the skateboard rather than the
deck's own 1.05, because the pose bends the knees: seating the deck under a
straight-legged rider left the bent feet hanging 0.2 studs above it. `stand`
sets how high the ROOT rides, so it has to account for the pose, not just
the surface.

**Abduction lifts a foot, and only the PELVIS can put it back down.** Swinging
a leg out to reach the skateboard's tail shortens that leg's vertical reach,
so the back foot floated 0.20 studs above the deck no matter how the knee was
bent — knee bend moves it 0.05. Tilting the pelvis 8 degrees drops the
reaching side and lifts the other, which levels the feet to 0.06 and is what
a skater's hips actually do; the torso counter-rolls by the same 8 to keep the
shoulders level. Reach for `hipRoll` before fighting a knee.

**`legRoll` is not mirrored: positive swings BOTH feet toward +X.** It reads
like a symmetric "spread" and it is not, which cost more time than any other
sign here. A stance with feet apart needs one side negative and the other
positive. The other conventions, all verified rather than reasoned about:
negative `torso` leans forward, positive `armPitch` raises the arm forward,
negative `elbow` bends it in, positive `hipFlex` lifts the knee, negative
`knee` folds the shin back, negative `headYaw` turns toward +X.

**NEVER KEY A WEAK TABLE ON AN INSTANCE and expect the entry to survive.**
Lua's collector cannot see the DataModel's reference to an Instance, because
that reference lives in C++ — so an Animator inside a live character, held in
a `__mode = "k"` table, is reachable to the engine and garbage to the
collector. The entry vanishes on the next GC, the next call finds no track,
loads another and plays it ON TOP of the one nothing stopped. Measured at
five copies of the same pose stacked on one rider inside a second, blending
into a pose that is subtly wrong and drifts. `RidePose` therefore asks the
animator what it is already playing and keeps exactly one — authoritative, no
bookkeeping, immune to both the collector and a respawn, and it unwinds a
stack that somehow appears. DodgeRoll still has the weak-keyed version; it is
a one-shot that stops its own track before replaying, so a dropped entry
leaks a track rather than stacking a pose — worth fixing, lower severity.

**ALL FIVE RIDES ARE POSED, and every contact is measured.** BMX and Volt
Scrambler seated with both hands on the bars; skateboard across the deck with
the back foot on the tail; scooter along the deck, one foot forward, hands up;
hoverboard square with the arms out to balance. Verified on a live mounted
character: hand-to-grip 0.01–0.06 studs, sole-to-peg 0.06, pelvis-to-seat
0.00, and every sole within 0.02 of the deck or pad it stands on.

**The Volt Scrambler was rescaled to the rider, exactly like the BMX.** It was
built at honest dirt-bike proportions — 3.5-stud wheels, a 5.5-stud wheelbase,
seat at y 4.4 and bars at 5.5 — which no five-stud rig with a 2.1-stud reach
can sit on or hold. Its wheels, frame and bodywork are now built around the
three measured contacts and nothing else. That is now the rule for anything a
character touches, not a one-off for the bike.

**A ride's contact points are NAMED CONSTANTS at the top of its builder.** The
scrambler has eleven parts positioned off `SEAT_TOP`, `GRIP_*` and `PEG_*`.
Inline the numbers instead and the next tuning pass moves a bar without moving
the brace, the mirror and the stem that were sitting on it — and a hand-tuned
bar height that drifts from the pose is a rider gripping thin air. The
skateboard's `PAD_X` on the hoverboard is the same idea from the other end:
when the board shrank by a fifth, that one number stayed pinned to where the
feet land instead of scaling with everything else.

**To preview a runtime-built model in EDIT, clone the module AND its
dependency.** The MCP sandbox caches modules per ModuleScript instance and
that cache defeats nested requires, so a `RideModel` clone still picks up
whatever `Config` the sandbox loaded in some earlier session — which was stale
enough to have no `RIDES` table at all. Cloning both, renaming the dependency,
and rewriting the clone's require to point at it gives two instances the cache
has never seen:

```lua
local cfg = RS.Shared.Config:Clone()
cfg.Name = "Config_preview"; cfg.Parent = RS.Shared
local rm = RS.Shared.RideModel:Clone()
rm.Name = "RideModel_preview"
rm.Source = rm.Source:gsub("Shared%.Config", "Shared.Config_preview")
rm.Parent = RS.Shared
local RideModel = require(rm)
```

This is what makes `screen_capture` usable on generated geometry, which is
otherwise unseeable — the capture tool is edit-time only and the models only
exist at runtime. **DESTROY BOTH CLONES IN THE SAME SCRIPT.** A clone left in
`Shared` gets reconciled by Rojo into a SECOND instance under the real name,
and a duplicate ModuleScript with stale source sitting next to the live one is
about as nasty as this project gets — `require` picks one of them and there is
nothing on screen to say which. One was found this session alongside a
`PigGear_preview` left over from an earlier one; both are gone. Tell them
apart by a marker only the newest edit contains, never by position.

**A TRICK TIPS THE RIDE AND LEANS THE RIDER, and the second half is what was
missing.** The manual and the wheelie were never mechanically broken: the
mount's C0 tween worked from the day it was written, and the ride rotated its
exact pitch about its exact rear contact patch. What looked broken was the
rider staying bolt upright while it happened — measured at **2.01 studs of
hand-to-grip** mid-wheelie. Posing the rider is what exposed it; before that
their arms hung at their sides and there was nothing to come off the bars.
The front wheel comes up 1.56 (BMX), 1.83 (Scrambler) and the board's nose
1.07 with the tail still planted.

**"VERIFIED AT THE ENDPOINTS" IS NOT VERIFIED.** The first version of the
lean was measured at rest and at full lock, read 0.02–0.03 studs at both, and
was recorded here as correct through the whole move. It was not: sampling
every frame instead showed the bike reaching its full 30 degrees at 0.22s and
the rider not arriving until 0.30, **1.33 studs of hand-to-grip in between**,
which is a player's hands a foot off their own handlebars for a sixth of a
second, every single time. That is the bug a user reported as "the bike comes
up faster than the player". Anything that MOVES gets sampled across the move.

**THE RIDER IS DRIVEN BY THE MACHINE, NEVER BY A CLOCK.** The ride is tipped
by a C0 tween on the server; the rider is posed by an animation on every
client. Those are two different curves over two different durations, and
nothing that starts both and hopes will keep them together — the old pairing
was a 0.18s Quad-Out tween against a 0.2s linear pose fade, plus up to 0.1s of
the client's own poll interval before it even began. So `RidePose.phaseOf`
reads the CHASSIS each frame and leans to whatever it finds. Same idea as the
officer's stride being a function of distance travelled: the animation cannot
desync from the thing it depicts because it is a function of it. It also made
the tween's shape a free choice again — it is 0.26s easing in and out on the
way up and 0.20s accelerating on the way down now, because a wheelie is a
lever and a landing is gravity, and neither number can put anyone's hands off
the grips any more.

**Read the machine on `PreAnimation`, not on `Heartbeat`.** Same trap as the
dodge dash, from the other end: a weight set on Heartbeat lands after the
animation system has already evaluated the frame, so it shows up on the next
one. Measured as a one-frame sawtooth — the rider holding last frame's angle
against the bike's current one, hands swinging 0.57 studs off the grips and
back every other frame.

**A TRICK POSE IS PART DERIVED AND PART SOLVED, and the split is the point.**
The body's share is derived: the ride's own rotation, conjugated into pose
space. But a rider rotated RIGIDLY with the machine keeps every contact
perfect and looks like the bike lifting the rider rather than the rider
lifting the bike — which is the second half of what was reported. A real
wheelie turns the machine further than the body and the ARMS take up the
difference. That difference is what a pull IS.

So each trick pose carries a `lean`, the share of the pitch the body takes,
and a per-side limb adjustment that restores the contacts. **The limb half was
solved numerically, not tuned by eye**: forward kinematics off the rig's own
attachment CFrames (validated against the live character at 0.015 studs),
then coordinate descent against the contact points, with the ride's rotation
applied to them. Two things that matters for:

  * **Give the solver real joint limits or it will hyperextend.** Left free it
    put the elbow 40 degrees the wrong way to save a tenth of a stud — an arm
    bending backwards, and cheaper by its own cost function.
  * **The limits then CHOSE the lean.** At 0.80 the elbow reaches its stop
    (-12 to 0, dead straight) and can give no more, so leaning further just
    pulls the hands off. 0.80 is where the arm runs out, not a taste call. The
    skateboard leans to 0.60 because nothing is held there — only knees to
    answer to — so the difference can be big enough to read: 16 degrees of
    rider against 26 of deck.

Solve leans by CONTINUATION, seeding each from the last. Solved cold, 0.45
found a better cost than 0.60 by climbing into a different, contorted basin.

Measured: body tracks the ride at 0.80 (0.60 on the board) on every frame of
the move, contacts hold at 0.05 held and 0.09–0.25 worst mid-move, and both
sides come back to within 0.01 of rest.

**That transform is conjugated TWICE, through two different frames, and
missing either one is a bug that looks like bad tuning.** `mount` carries the
rotation from the ride's space into the root's — it is the same transform
`RideService.mount` welds the model on, so it must stay in step with it.
`ROOT_JOINT` then carries it from the root's space into the one a Pose is
actually written in. Skipping the second left 0.64 studs of hand-to-grip
error: a third of the way back to no fix, and entirely plausible-looking.

Conjugating rather than special-casing is also what makes the skateboard work
for free. `bodyYaw = 90` turns the board's nose-up pitch into a ROLL from the
rider's point of view — correct, since you stand across a deck — and it falls
out of the arithmetic instead of having to be noticed.

**A `Pose` CFrame is a JOINT transform, not a placement in root space.** The
body swings about the root joint's attachment, measured at **(0, -1.252, 0)**
— 1.25 studs below the root's centre, not at its origin. Measured by posing
the LowerTorso 40 degrees about X and solving for the centre of the arc the
part traced. Any pose maths derived in root space has to be conjugated
through that point before it is handed to a Pose, and nothing about the
result *looks* wrong enough to make you suspect it.

**A server-written `Motor6D.C0` does not show up as a changed C0 on the
client, but its RESULT does.** Measured on a live wheelie: the client read
its own `motor.C0` as byte-identical before and after, while the chassis it
drives had visibly rotated 30 degrees and moved 0.84 studs. So a client that
watches C0 to find out whether a trick is happening sees nothing forever.
That result is what the rider is posed from, and reading it off the CHARACTER
rather than from this client's own button is what makes somebody else popping
a wheelie down the street lean too. `RideTricking` is still published, but
nothing poses off it any more — it is only the honest answer to "is this
player holding the button", which nothing else on a remote peer has.

**AN ANIMATION TRACK'S WEIGHT OF ZERO IS TERMINAL, and nothing says so.**
Measured on a live Animator: a track played at weight 0 never starts at all
(`IsPlaying` false immediately), and `AdjustWeight(0)` on a running one STOPS
it — permanently, since `AdjustWeight(1)` afterwards does not bring it back.
Which is fair of the engine, because a fade to zero weight is exactly what
`Stop` is. It cost an afternoon because it fails in the shape of a tuning
problem: the trick track was started at 0 and dialled up, so it was born dead
and the rider never leaned; and once a trick had ENDED at weight 0, the track
was rebuilt every tenth of a second forever and every rebuild was born dead
too — a rider who leans on their first wheelie and never again. No warning,
no exception. `RidePose.FLOOR` is 0.001, verified alive across repeated
up-and-down cycles, and it costs 0.024 degrees of lean at rest.

**A trick's `pivot` tracks the rear axle, so rescaling a ride moves it.** The
wheelie went from -2.15 to -1.62 with the bike. Left at the old value it
would turn about a point half a stud behind the wheel and drive the tyre
through the road.

**A RIDER'S FOOTSTEPS COME FROM A ROBLOX SCRIPT, and it is not the one that
was already disabled.** Mounting disables `Animate`, which stops the walk
cycle -- but the footstep sound lives in `RbxCharacterSounds`, a separate
LocalScript in PlayerScripts, and it kept playing. It had to: a ride is a
WalkSpeed multiplier and nothing else, which is the whole reason the street
gate can be a speed rule, so as far as the Humanoid is concerned a player
doing 33 studs a second on a Volt Scrambler is *sprinting*. The server cannot
reach it either -- those Sound instances are built on each CLIENT, for every
player, so they do not exist on the server at all.

**Mute it, do not destroy it, and stash the old volume ON THE SOUND.**
`RbxCharacterSounds` sets `Volume` exactly once, at creation, and thereafter
only toggles `Playing` -- so a volume of 0 sticks and muting is a single
property write rather than a fight. The original goes into an ATTRIBUTE on
that sound, never a table keyed by it: weak-keyed, the collector drops it
while the engine still holds the object (the trap at the top of `RidePose`);
strong-keyed, it leaks every character that ever rode anything. An attribute
lives and dies with the thing it describes.

**Ask the MOUNTED MODEL what someone is riding, not the published style
string.** `RideSound` first looked the ride up by matching `RideStyle` against
`Config.RIDES` -- and broke inside the hour, because that attribute is a KEY
and not a style: `bmx#trick` for a trick, and `bmx@onehand` the moment stances
shipped. A plain equality test matched nothing, silently, and every rider kept
their footsteps. `RidePose` owns that grammar and strips it correctly; a
second copy was one more thing to keep in step and it did not. The model's
name needs no grammar at all -- `Ride_<key>` is what RideService welds on, it
names what is REALLY mounted rather than a label describing it, and its mere
presence answers "is this player riding".

**Three sounds for five rides became FIVE FOR SIX, and the shared-recording
trick was only ever right for one of the three it was used on.** The idea --
the same one the dog barks use, one coyote and three breeds -- was that a
skateboard, a BMX and an e-scooter could share one recording of wheels on
concrete. It holds for the SCOOTER, whose small hard wheels really do sit
above a board's, so pitching up describes the machine. It did not hold for
the bike, and the disc should never have shared at all.

**THE MICROPHONE POSITION IS A TUNABLE, AND IT OUTRANKS THE FADER.** After
the volume had been halved twice the wheel rides were still reported as
obnoxious, which is the signal that loudness was never the complaint. The
recording was *"CU Wheels, recorded from FRONT"* -- a close-up mic pointed
straight at the bearings, which is all grind and grit with none of the air
that makes a rolling sound pleasant. The same session has a SIDE take, and
that is what ships now. When something is harsh rather than loud, look at
what the recording IS before reaching for gain.

**PRO SOUND EFFECTS DOES HAVE BICYCLES AND NOT ONE IS USABLE, which is a
different claim from either of the two that stood here before it.** The
original note said "no bicycle at all", which was false -- there is a whole
"Vehicles - Bicycles" category. Finding it, a bicycle pedal recording went
straight in on the strength of its NAME and CATEGORY, and shipped a BMX with
NO SOUND AT ALL. Every bicycle in that library is a quiet, sparse field
recording. Measured mean loudness against the skateboard's 344: Pedal 1 is
2.5 and Pedal 2 is 1.6 (both over 98% silence), Spokes 102 is 3.5, Sting Ray
3 is 11.9, Spokes 201 is 16.8, and the only continuous one -- Training Wheel
-- is 24.6, a fourteenth of the board. No gain fixes that; there is nothing
on the tape to turn up. The bike rides a TYRE now, pitched below the
scrambler: a real pneumatic tyre is what a BMX rolls on and a closer match
than hard urethane, and the two machines sharing it is the shared-source
trick used the way it actually works -- two vehicles that genuinely have the
same part.

**PLAYBACKLOUDNESS IS THE MEASUREMENT, AND NOT HAVING USED IT IS WHAT MADE
EVERY EARLIER PASS GUESSWORK.** `Sound.PlaybackLoudness` on a playing Sound
reports real output level, so a couple of seconds of sampling says what a
recording actually IS rather than what its title claims. It only reports
in a running game -- in Edit every sound measures 0.0 including known-good
ones, which looks exactly like a broken asset. Confirm playback advanced by
watching `TimePosition` before believing a zero.

**A `volume` NUMBER IS MEANINGLESS WITHOUT THE RECORDING'S OWN LEVEL, and
three tuning passes were spent not knowing that.** Volume is a scale factor
on a source, so two rides at 0.18 and 0.19 are only comparable if their
recordings are -- and these were not, by nearly 5x. Measured effective level
(volume x source loudness) before this pass: skateboard 45.0, scooter 45.8,
scrambler 25.8, hoverdisc 23.8, hoverboard 10.7, BMX 0.2. So THE CHEAPEST
RIDE IN THE GAME WAS THE LOUDEST, at nearly twice the flagship, and a
1.2M-coin hoverboard was the quietest thing on the street -- none of which
was visible in a column of numbers that all read about 0.17. That is why the
skateboard kept being reported as obnoxious through two rounds of cutting its
number: the cuts were real and it was still starting from far too high.

Normalised against measured source loudness, the ladder is now 19 to 30 --
BMX 19.1, scooter 22.9, skateboard 23.0, hoverboard 24.2, hoverdisc 26.2,
scrambler 29.5 -- so the flagship is finally the loudest thing and the spread
is deliberate rather than accidental. ANY new ride sound gets measured and
placed on that ladder; do not copy a volume from a neighbouring ride, because
the number does not travel between recordings.

**THE ONE RIDE THAT IS WON RATHER THAN BOUGHT MUST NOT SOUND BORROWED.** The
Hoverdisc shared the Hoverboard's pod tone, which is defensible while both
are "a machine that hovers" and makes the alien set's 120-medal legendary
sound like the 1.2M-coin board anybody can buy. It has its own deep power
drone now -- and deliberately NOT another take from the same Pod session,
because two recordings from one session sound related however different their
file names are.

**`eq` IS PER RIDE, AND THE TWO BANDS DO TWO DIFFERENT JOBS.** A single flat
`HighGain = -4` on every ride was the wrong instrument twice over: it left
the two wheel rides harsh while spending the same cut on two synth drones
that had no grit in them to remove. `mid` is the control for "this recording
is harsh" -- a close-mic'd wheel's grind lives there -- and `high` is the
control for "this is a resample", so the further a ride is pitched from 1.0
the more of it it wants. Missing `eq` falls back to the old flat -4, so a
ride that does not specify one behaves exactly as it did before.

**WHAT IS NOT VERIFIED HERE IS THE ONLY THING THAT MATTERS: HOW IT SOUNDS.**
Every claim above is reasoned from asset metadata (perspective, category,
duration) and confirmed by measurement -- all six rides load, every id
resolves, lengths and EQ and pitch read back as authored. None of it was
LISTENED to, because nothing in this toolchain can hear. "Recorded from the
side is less harsh than recorded from the front" is a sound engineering
principle and a hypothesis about these two specific files, not a measurement.
Somebody has to put headphones on -- and note that the one thing measurement
DID catch, it caught only because the BMX went completely silent. A recording
that was merely wrong rather than absent would have shipped. The alternates
worth keeping to hand for an A/B: skateboard front takes 9125955671 (39.1s)
and 9125955737 (41.6s), and disc 9119413023 ("Hollow Air Rush Drone", airier
and less deep than the one chosen). No bicycle is on that list, for the
reason above.

**A ride's sound is scaled against ITS OWN top speed, never an absolute one.**
A skateboard flat out is 21.6 studs a second and a scrambler is 33.6, so one
shared scale would leave the cheapest ride permanently quiet and permanently
low -- describing the price of the machine rather than what it is doing. Each
reaches the top of its own range at its own top speed, and the RANGE is what
says a scrambler is quicker. `idle` is the other half: zero for the three that
only roll, because a rolling sound from a machine standing still is a machine
that is moving, and a real hum for the two that are powered, because a
hoverboard that falls silent when you stop has landed.

**GRAINY IS A LITERAL DESCRIPTION OF WHAT `PlaybackSpeed` DOES FAR FROM 1.0,
not a complaint about the recording.** `Sound.PlaybackSpeed` is a raw
resample -- Roblox has no formant-preserving pitch shift on it -- so every ride
here pushing its one shared recording away from 1.0 to sound like a different
machine was always spending some grain to buy that differentiation. The
question was never whether to spend it, only how much. Two rides spent far
too much: the BMX reached down to 0.60 (a 40% resample) and the Volt Scrambler
reached up to 1.55 (55%), and the scrambler paired that with the loudest
volume here (0.44) and the longest range (85), which is "loud, far-carrying
and the most artifacted pitch in the set" -- reported back in almost those
words. Retuned so no ride's pitch strays more than about 30% from 1.0 --
BMX now 0.74-0.88, scrambler 0.92-1.32 -- while keeping every ride's relative
character intact: the bike is still the low, heavy one, the scrambler still
climbs highest of the five as its motor opens up, and the skateboard, which
was already tight at 0.88-1.12, was not touched.

**Volume came down with it, across all five, not only the loudest one** --
and then came down AGAIN, by nearly half, because the first pass was tuned
against the wrong reference. It is recorded in two steps because the second
one is the interesting half. The first cut the scrambler's 0.44 to 0.34 and
the rest by a smaller even amount, keeping the gaps between rides, which is
part of what tells them apart at a distance. It was still too loud, reported
in exactly those words.

**A CONTINUOUS SOUND IS MEASURED AGAINST THE OTHER CONTINUOUS SOUND, AND
THERE IS ONLY ONE.** 0.34 does not look extreme on a 0-1 scale, and next to
the alerts (0.25 to 1.0) or the dog barks (0.42 to 0.75) it looks modest --
which is what made the first pass land short. Those are all ONE-SHOTS, over
in a second. The score is the only other sound in this game that never stops,
and it is deliberately quiet at 0.18 for precisely that reason. Measured on a
live rider at full throttle the loop sat at **0.340 against the music's
0.180**, nearly twice the score, forever. The rides are 0.15 to 0.19 now, so
the loudest one at full speed is level with the music rather than over it.

**ONE `Volume` SERVES TWO LISTENERS, AND `RollOffMinDistance` IS WHAT SPLITS
THEM.** This is the part that is not obvious and it is why the fix was not
simply "halve the numbers". A Sound plays at its full `Volume` with NO
attenuation anywhere inside `RollOffMinDistance`, and the emitter is the
chassis welded to the rider's own body -- measured at 3.2 studs. So the rider
is always inside the bubble and hears the raw Config number, permanently,
while everybody else hears `Volume * min / distance`. Halving `Volume` alone
would therefore have halved the STREET too, and a Volt Scrambler you cannot
hear coming is a worse game than a loud one.

Raising `min` from 8 to 14 puts the distant listener back where they were --
(V/2) * (2m)/d is V*m/d -- while doing nothing at all to the rider, who was
never on the falloff curve. Verified across all six rides: the rider's peak
fell 0.27-0.34 to 0.15-0.19, while a bystander at 30 studs moved by at most
0.002 on any ride. Anything that changes a ride's `volume` from here has to
say which of those two listeners it meant.

**AND THE FOOTSTEPS WERE NOT THE CULPRIT THIS TIME, WHICH IS WORTH RECORDING
BECAUSE THEY LOOK LIKE IT.** `Running` sits in the root at volume 0.65 --
nearly four times the music, the loudest continuous thing a character owns --
and at 1.85 pitch while sprinting it is exactly the frantic noise a complaint
about ride audio would describe. Measured on a live rider it reads **0.000**:
`muteFootsteps` is doing its job. A probe that finds it playing at 0.65 has
found an unmounted player, not a bug -- which is how the first measurement
this session was misread for a minute.

**`EqualizerSoundEffect` WITH A MODEST HIGH CUT IS THE OTHER HALF OF THE
GRAIN FIX, and it costs nothing else.** Client-side, one instance per ride's
loop, `HighGain = -4`. It will not be heard as EQ on its own -- 4 dB is
subtle -- but it is exactly the standard fix for the brightening a naive
resample adds, so it is the difference between "a wheel at a different pitch"
and "a wheel at a different pitch that has been resampled," which is the gap
between satisfying and grainy.

**Mounting is automatic, and `HipHeight` is what does it.** No button, no
prompt -- you leave your gate and you are on it, which also means a thief
learns the getaway is on foot by watching the board vanish rather than by
reading a message. Every ride is authored with y=0 AT THE GROUND, so seating
one at the character's feet buries the rider's shins in their own deck. The
model goes on the floor and `Humanoid.HipHeight` is raised by the ride's
`stand` height to lift the rider onto it. Set HipHeight FIRST and compute the
placement from the new value: the weld locks in whatever offset exists at that
instant, and the character has not physically risen yet. Restore the
REMEMBERED base value on dismount, never by subtracting -- a respawn in
between hands you a fresh humanoid at the rig default, and subtracting from
that leaves a player permanently a stud taller than everyone else.

**A FAILED MOUNT MUST LEAVE THE CHARACTER EXACTLY AS IT FOUND IT, and getting
that wrong does not cost a ride -- it costs the session.** `mount` raised
HipHeight and only then built the geometry, so a throw anywhere below that
write left the character a stud in the air with `mounted[player]` never set --
and `dismount` restores from `current.baseHip`, which did not exist. There was
no way down and nothing to press.

THE GATE POLLS TEN TIMES A SECOND, WHICH IS WHAT TURNS A BROKEN MOUNT INTO A
RUNAWAY. `step` re-enters `mount` every tick while nothing is mounted, and
each attempt reads the ALREADY-RAISED HipHeight as its new base. So the
failure does not settle at one stud of float, it compounds: measured on the
hoverdisc, HipHeight climbed 2.225 to 23.805 in three seconds -- 8.3 studs a
second -- and was still climbing, with no ride visible, the server log taking
ten stack traces a second, and `step` aborting partway so every player after
the affected one in the iteration lost their gate for that tick too.

So the ride is BUILT AND VALIDATED FIRST, before anything about the character
is touched. None of that work needs the character, which is what makes the
reordering free. The remaining failure shape is a ride that does not appear --
a bug somebody reports -- rather than one that eats the session.

**AND `accent` IS NOT OPTIONAL ON A RIDE, which nothing said until the
hoverdisc shipped without one.** It is the speed streak's colour and
`ColorSequence.new(nil)` THROWS, so a missing field was not a ride with no
trail, it was the throw above. `addTrail` now warns and returns instead --
losing a streak, never a mount. Warned rather than defaulted to a colour: a
silent fallback is a ride whose streak is quietly wrong forever, which is the
kind of thing nobody ever files, and this file's rule is that a rejection
nobody can see is indistinguishable from a broken feature. Note the hoverdisc
was the sixth ride and the only one to reach the shop without an `accent` --
the other five all carry one, so nothing caught it by comparison.

**THE SIDEWAYS STANCE EASES TOWARD ITS TARGET, AND NEVER SNAPS TO IT.** The
skateboard is the only ride with a `bodyYaw`, so it is the only one whose root
gets turned by ClientMain at all (see `RIDE_YAW_ATTRIBUTE` in RideService) --
and the first version of that turn set the root's CFrame straight to the exact
target orientation every single frame. That is right for WHICH WAY to face,
which a keyboard has to report instantly, and wrong for HOW FAST to get there:
`Humanoid.MoveDirection` is not continuous, it is one of eight fixed vectors
that changes in a single frame the moment A becomes D, so the board spun on
the spot instead of carving into the new heading -- reported as jaggy, and it
was, because there was no interpolation anywhere in the path.

The fix eases a tracked `currentAngle` toward the target at
`Config.RIDE_STANCE_TURN_RATE` (420 degrees a second, chosen so a full A-to-D
reversal takes just under half a second -- fast enough to stay responsive in a
chase, slow enough that consecutive frames differ by a few degrees rather than
by however far the input happened to turn), using the same shape as the
patrol car's lane change: a per-frame delta clamped to `rate * dt`, angle
WRAPPED to take the short way round. Wrapping matters here for the same reason
it matters for the car -- without it, turning from just past -170 degrees to
just past +170 (five degrees apart the short way) would ease the LONG way,
through zero, spending most of a second crossing 350 degrees of nothing.
`currentAngle` starts nil and is set to the target outright on the first frame
after a mount, so stepping onto a board does not cost half a second turning
onto a stance nobody asked for yet -- only a heading CHANGE eases, not the
mount itself.

**`ToEulerAnglesYXZ` RETURNS THREE VALUES AND THE YAW IS THE SECOND, NOT THE
FIRST.** A call used as the sole argument to another function expands every
return into its own argument, so an earlier draft of this fix wrote
`wrapAngle(cf:ToEulerAnglesYXZ())` and silently wrapped the PITCH instead,
because Lua handed `wrapAngle` all three returns and it only ever reads the
first parameter. Caught before it shipped by naming both return values
explicitly (`local _, targetY = cf:ToEulerAnglesYXZ()`) and reasoning about
which one a pure-Y-axis CFrame actually carries its rotation in, rather than
trusting the position in a multi-return expression to line up with intent.

**A REST OFFSET IS NOT ZERO, so "arms straight down" has to be MEASURED, not
assumed from the field names.** The skateboard's Cruise stance was written to
read as low and a little behind, and it was neither: measured on a live rig,
the shipped values (left armPitch -12/armRoll -14/elbow -6, right -16/12/-5)
put the left hand 0.87 studs OUT from the shoulder and 0.15 studs FORWARD of
it -- still swung away from the body, not yet behind it at all. That is
exactly what "only brings the arms down slightly" was describing.

The reasoning that produced those numbers assumed `armPitch = armRoll = 0`
means arms hanging vertically at the sides, since that is the rig's rest pose
with no animation playing at all. It measures nothing like that once the
skateboard's own cruise LEAN is in the chain: with every arm field at zero,
the left shoulder-to-hand vector already reads (dx -0.53, dy -1.18, dz -0.37)
-- half a stud out and over a third of a stud forward, entirely from the
body's torsoYaw/torsoRoll/hipRoll carrying the shoulder along with it. A
stance tuned against an assumed zero is tuned against a pose that was never on
screen.

**RETUNED BY SWEEPING ONE AXIS AT A TIME ON A LIVE RIG, never by reasoning
about sign conventions from the field names.** armPitch, armRoll and elbow
were each driven to a wide angle alone first, to read which world direction
each one actually moves the hand and at roughly what rate, before combining
them -- catching along the way that `armRoll`'s direction is NOT the same
sign on both arms (positive swings the left hand inward, toward the body, and
the right hand outward, away from it), which is exactly the kind of thing
this file already keeps a warning about for `legRoll`. Left and right also
are not mirrors of magnitude: the same "close and slightly behind" target
needs `armRoll = 23` on the left and `armRoll = -17` on the right, because the
skateboard's own asymmetric lean starts each shoulder from a different
orientation.

Verified on the real `RidePose` module, not just the throwaway rig used to
search for the numbers: shoulder-to-hand now reads left (dx -0.16, dy -1.33,
dz +0.22), right (dx +0.20, dy -1.31, dz +0.30) -- both arms within a fifth of
a stud of hanging straight down from their own shoulder, and both genuinely
BEHIND it rather than in front, against the old -0.87/+0.82 out and
-0.15/+0.28 (still forward on the left) this replaced.

**A STANCE IS AN OVERRIDE, NEVER A WHOLE POSE.** Alternate riding poses are
merged over the base field by field, one level into `left` and `right`, and
that is the only reason they are cheap. Every base pose was authored by posing
a live rig, reading the hands and feet back in ROOT SPACE, and then moving that
ride's grips, pads and pedals to what came back — a one-way street that is
already spent, because once a handlebar exists at the hand's measured position
a second pose cannot move it. A stance that re-authored the whole body would be
exactly the inverse-kinematics problem `RidePose` says has no solution, with
the escape hatch gone. Overriding field by field means the limbs a stance does
not mention are still the measured ones: verified on all five, every stance
moved its freed limbs and moved every foot by **0.000**.

The merge has to go one level in, not replace the side table. An arm and a leg
share `left`, so swapping the table wholesale to change an arm silently throws
away the `hipFlex`, `knee` and `ankle` beside it and puts the feet through the
deck.

**So the cheap stances are the ones that LET GO of something.** A free limb has
no contact to miss, which is why all five are a hand off the bar, both hands
off, arms folded, a leg off the peg. Measured: the retained grip keeps its
depth exactly (+0.08 to +0.12 inside the grip, same as classic), and every
freed limb clears both the machine and the rider's own torso. Anything that
KEEPS a contact and changes how it is held is a re-measure and has to be
treated as one rather than nudged.

**A STANCE MAY CHANGE THE TRICK, AND THAT IS WHERE THE GOOD ONES LIVE.** The
`trick` block has the same shape as a pose — `lean`, `left`, `right` — so it
merges by the same rule applied to itself, one level in. Replacing it wholesale
would make a stance that wants to drop one leg re-state the lean and both arm
corrections, which is three chances to silently undo work that was measured
against a grip.

It matters because a rider cruising the street is scenery, while a wheelie is
the one moment on that ride anybody actually watches. The scrambler's first
stance put an arm in the air during normal riding and was a flourish nobody was
looking at; it now hangs the left hand off the bar while cruising and drops the
left LEG off the peg when the front wheel comes up. It needs no timing of its
own — the trick pose is blended by how far the bike has actually rotated, so
the leg swings off as the wheel rises and tucks back as it lands.

**A TRICK BLOCK IS A DELTA, NOT A POSE.** `v()` in `addKeyframe` ADDS it to the
base angle, so a trick written as though its numbers were absolutes barely
moves anything. The leg drop was first authored at `hipFlex = -18`, which on
top of the seated 52 is 34 — still a knee up by the tank — and the measured
foot came out HIGHER than the classic wheelie, world y 1.31 against 1.06. Work
the numbers backwards from where the limb has to END UP: the seated leg is
52 / -54 and a dangling one wants about -20 / -8, so the delta is -72 / +46.

And -20 rather than 0 because the body is already leaning 24 degrees into the
wheelie, so a leg square to the torso points down and FORWARD in the world
rather than at the ground. Measured on the finished pose: the dangling sole
sits at world -0.03 against a road at -0.44 — reaching for the tarmac without
going through it — while the foot still on the peg stays exactly where the
classic wheelie put it.

**The stance rides inside the published style string** — `bmx@onehand`, the
same way the trick is carried as `bmx#trick` — so it is one more lookup rather
than a parallel table that could disagree about which styles exist. One
attribute, not two, because two would let a client read a new style against a
stale stance on exactly the frame somebody changed one. `rideForStyle` has to
strip the stance before matching `Config.RIDES`: it also hands back the ride
KEY that `phaseOf` uses to find the model, so missing it leaves every stanced
rider stuck at trick phase 0. An unknown stance falls back to the base pose,
the same call the trick makes when a ride has no manual.

**A RAISED ARM IS THE ONE LIMB YOU CANNOT AUTHOR, because hair is the
player's choice.** The scrambler wore an arm-in-the-air stance for exactly one
session and it is worth keeping the measurements, because the next person to
reach for that idea should know what it costs. Pitched forward to 152 the hand
went up IN FRONT OF THE FACE, where the rider's own hair covered it. Rolled out
instead, the height came good and the opposite bug appeared: 0.08 studs out,
straight up through the top of the skull. Swept on a live rig the two trade
against each other — roll -120 gives 0.48 above the head and 1.50 out, -135
gives 0.66 and 1.08, -145 gives 0.75 and 0.78, -155 gives 0.71 and 0.47 —
and there is no setting that is both high and clear.

You cannot measure your way out of that, because the obstacle is not on the
rig you are measuring: some hair is a stud wide, and it is a different stud
wide on every player. A limb that has to pass near the head is a limb whose
final position somebody else chooses. Everything else in the stance set moves
in front of the torso or away from the body, where the only geometry involved
is the geometry this repo built.

**Stances are the one cosmetic shaped to be sold for Robux, and they must stay
a DIRECT purchase.** They confer nothing, they cannot be aimed at anybody, and
a pose is the safest possible thing to put in front of an under-12 audience.
That is only true while they are bought outright: a stance in the accessory
roll would be a Robux-reachable random outcome, which is the loot box the
coins-are-never-purchasable rule exists to prevent. Sell one; never roll one.

**A ROBUX PURCHASE MAY GRANT AN ITEM, NEVER ITS COIN VALUE.** This is a
different line from the one above the accessory roll and it is the one that
makes a paid product legal here at all. Coins buy rolls, so coins must never be
purchasable; but a purchase that hands over a NAMED thing mints no coins, feeds
no roll, and is an ordinary direct purchase. Grant the ride. Never grant what
the ride costs.

**A GAME PASS IS BUYABLE FROM THE STORE PAGE, OUTSIDE THE GAME, so nothing may
assume the buyer already had something.** No button can be hidden to prevent a
purchase — the same shape as the admin rule, where hiding the console protects
nothing because the RemoteEvent exists for everyone. A riding pose bought by
somebody who owns no ride is a purchase that visibly does nothing, which is the
worst failure this game can hand a nine-year-old. So the Style Pack also grants
the ENTRY ride when the buyer owns none.

The cheapest ride, never the one the pose is for. Rides run 25,000 to 4,500,000
coins, so bundling the matching one would price a cosmetic above the largest
coin sink in the game and delete the reason to go on earning. It is also
self-clearing and therefore needs no bookkeeping: *owns the pass and owns no
ride* stops being true the instant it fires.

**An unset pass id UNLOCKS what it gates, and says so at startup.** The other
default is worse in a way nobody can see: a pass id left at 0 would lock
content that no purchase on earth could reach, which is indistinguishable from
the feature being broken and cannot be noticed from inside the game. Shipping
something free by accident is the smaller failure, and the startup warning is
what stops it being a silent one. `PassService.unlocked` is the "can they use
it" question and treats an unset id as yes; `PassService.owns` is "did they pay"
and is never true without a real id — which is what keeps the entry-ride grant
from firing for every player during development. Two questions, two functions,
and mixing them up hands the whole server a free skateboard.

**Pass ownership is cached per session and a FAILED CHECK IS NOT A NO.**
`UserOwnsGamePassAsync` is a web call that yields and can throw, and it gets
asked on every stance change, every push and every shop render — so it is asked
once at join and again when a purchase completes, which are the only two times
the answer can change. If the call throws, the entry is left ABSENT rather than
written false, so the next ask retries: writing false on a network blip would
take a paid feature away from somebody who owns it for the rest of the session,
which looks exactly like being robbed. And a pass rather than a developer
product, because Roblox holds the entitlement — if a save is lost the player
still owns what they paid for.

**Locked content is SENT to the client, never filtered out of the payload.**
The shop is where something you do not own is supposed to be advertised, and a
stance list that quietly omitted the locked ones would leave the pack with
nothing on screen to explain what it buys. The client then does two things with
that: it refuses to CYCLE a locked style — the server's refusal is the loud
kind, and the client not asking for a known no is the same rule the number keys
and the dodge-while-riding suppression follow — and when nothing but the
default is unlocked, the pill stops being a switch and becomes the advert,
reading STYLES with a lock and opening the shop at the offer. A control that
does nothing when pressed reads as broken; one that opens the shop does not.

**MOST WANTED GEAR IS THE FIRST COSMETIC WORN BY THE PLAYER RATHER THAN BY
THEIR PIGGY, and none of the wardrobe rules above apply to it.** Skins, effects
and all twelve accessories go on the PIGGY BANK -- `PiggyBank.applyAccessories`
-- and every pivot and clearance rule in this file is cut against the pig's
eyeballs, tail and lawn line. `Shared/PlayerGear.luau` is a separate system with
its own geometry, its own attachment and its own save field (`data.gear`, schema
13). It is in `Shared` for the reason House, Decor and PiggyModel are: the shop
renders the real item.

**IT IS THE CARROT ON THE MOST WANTED BOARD, and without one that board is a
tax on playing well** -- an officer comes for you every eight minutes and you
get a label for it. Earned by ESCAPING a most-wanted pursuit, never by being
caught, and specifically a most-wanted one rather than any pursuit at all: a
thief who robs during a patrol and outruns the officer did something else, and
it already paid, because they still have the loot. `alarm.wanted` is what tells
the two apart, so it costs nothing. Deliberately not hard -- in a wanted pursuit
you carry nothing and run 16 against 14.5 -- which makes tier 1 a ceremony
rather than a grind and leaves the difficulty for the obvious tier 2: the same
event with one flag flipped, escaping while CARRYING at 12 against 14.5.
`gear.escapes` therefore survives the unlock rather than being spent by it.

**A CHARACTER FACES -Z, WHICH IS THE OPPOSITE OF EVERY OTHER MODEL HERE.**
Measured: `FaceFrontAttachment` sits at head-local z = -0.594. The dog, the
piggy, the ornaments and all five rides are authored facing +Z. Gear authored to
house convention comes out with its face hole at the BACK of the skull, and it
neither errors nor looks like a bug -- it looks deliberate.

**THE HAIR IS THE PLAYER'S, NOT OURS, so wearing head gear hides it.** This is
the raised-arm riding stance problem -- "a limb that has to pass near the head is
a limb whose final position somebody else chooses" -- except it cannot be
designed around, because the gear IS on the head. Hair and hats are found by
ATTACHMENT (`HairAttachment` / `HatAttachment` on the handle) rather than by
`AccessoryType`, which is absent on older assets, and the original transparency
is stashed in an ATTRIBUTE on the handle -- weak-keyed the collector drops it
while the engine still holds the object, strong-keyed it leaks every character
that ever wore anything.

**A PART CANNOT CUT A HOLE IN ANOTHER PART, BUT THE ENGINE CAN: `UnionAsync`
and `SubtractAsync` WORK AT RUNTIME.** This file asserted the opposite twice --
under the moat, and under the mask -- and it is true only of plain Parts.
Measured here at 15 ms to union and 17 ms to subtract, and the result is a
`UnionOperation` that can be resized. Almost every difficulty below came from
not reaching for it.

**WHAT THE NO-CSG ASSUMPTION COST, recorded because the failure was gradual
rather than obvious.** Without a subtract, an opening can only be the GAP
between solids -- so the mask grew to eight overlapping spheres and a cylinder
band, each one bounding some edge of the eye slot. Every piece was solved
against the measured head and every piece was correct alone, and the assembly
still read as LUMPS, because a union of spheres of different radii creases
wherever two of them meet and the ears were the worst of it. It also cost four
rounds of whack-a-mole -- tightening the crown opened the ears, adding a side
piece opened the nape, and the last gap was two degrees wide and only appeared
on a 2-degree sweep. None of that is fixable by arrangement. It is what an
assembly of primitives looks like.

**A BALL PART IS ALWAYS A SPHERE, and that is why the shell is a UNION.**
Measured: three balls at (6,6,6), (12,6,6) and (6,12,6) render pixel-identical,
so non-uniform `Size` does nothing to one. A `UnionOperation` has no such
limit -- which is the whole trick here. The head is a rounded cylinder, so a
sphere big enough to contain it has to clear the RIM at 0.715 and ends up 0.127
proud at the face where the head is only 0.593: correct, smooth, and a size too
big everywhere except two rings. The shell is therefore a capsule -- a cylinder
with a sphere on each end -- SQUASHED to height afterwards, which no primitive
can be. It lands 0.06 proud at the face and 0.14 over the crown.

**A UNION INHERITS THE ORIENTATION OF THE PART IT WAS BUILT FROM, so which axis
is "up" has to be DERIVED.** This one is built from a cylinder stood on end, so
its local X is the vertical and squashing `Size.Y` flattens the mask
front-to-back instead. Nor can the CFrame be reset to identity to tidy that up:
a union stores its mesh relative to its own frame, so straightening the frame
tips the geometry on its side. Ask the union
`CFrame:VectorToObjectSpace(Vector3.yAxis)` and scale whichever component comes
back dominant.

**CSG IS SERVER-ONLY.** `UnionAsync` from a LocalScript throws "CSG API can
only be called from the Server", and the shop is drawn on the client -- so the
first version had a correct mask on every character in the world and an empty
shop tile, with the reason only in the client log. The shells are built once on
the server, parked in `ReplicatedStorage.PlayerGearTemplates`, and CLONED
everywhere. That is cheaper than every peer computing the same solid and it
guarantees the tile and the head cannot disagree. `PlayerGear.prewarm` runs
them at startup, because otherwise the first one is built inside a
CharacterAdded handler and CSG yields.

**A ROW OF SPHERES CUTS A CLEANER SLOT THAN ONE ELONGATED CUTTER, and they must
overlap far more than looks necessary.** A cylinder with an elliptical
cross-section is the obvious cutter and is not worth betting the shape on,
given a Ball silently ignores non-uniform size. Overlapping spheres cannot be
ambiguous and give the rounded ends a balaclava actually has. Each subtends
10.5 degrees on this shell, and at 10-degree spacing they meet at their rims and
leave a visibly SCALLOPED edge along the bottom of the opening; at 2.5 they
overlap four deep and it reads as one smooth stadium.

**A RAYCAST CANNOT TEST A CSG HOLE, and a bounding box cannot either.** Both of
those wasted a cycle here. Rays hit a union's COLLISION geometry, which is a
simplified hull that knows nothing about the hole -- so a mask with a perfectly
good eye slot reported solid at every angle. And a bounding box barely moves
when a channel is cut into the middle of a face, since the rest of the surface
still reaches just as far: a cut that plainly worked shrank `Size.Z` by 0.012
and read as a failure. Check a subtract by LOOKING at it.

**A HEAD IS NOT A SPHERE OF `Size.X / 2`, and assuming it was put the wearer's
skull through the top of their own mask.** That is the half-extent along one
axis, not a radius. Raycast, the real mesh is a ROUNDED CYLINDER: straight
sides at horizontal radius 0.60, rounded caps, 1.20 tall, with its furthest
points 0.715 out at the top and bottom RIMS. Every coverage check run against
an inscribed sphere reported perfection while the forehead corner stuck
straight through it. Measure a head by casting at the mesh, not by reading a
property.

**ADAPTIVE PER-HEAD FITTING WAS TRIED TWICE AND CANNOT WORK, and both attempts
look obviously right.** GROWING each piece until it clears the furthest mesh
point it owns closes every gap and widens its angular cap while doing it --
measured, it covered the whole head, eye slot included, and reported a
triumphant zero misses. SCALING centre and radius together seems to fix that,
since `cos t = (r^2 + D^2 - R^2) / (2rD)` is unchanged when k multiplies all
three; but the head is not being scaled, and `|r*d - kC| <= kR` is the same
statement as a SMALLER head inside the same ball, which sits deeper in the cap.
Identical failure. There is no transform that reaches further out without also
reaching further around. Design against the head's real shape and scale only
for SIZE -- from the largest bounding-box dimension, so a body-scaled avatar
gets gear scaled with it.

**THE OBVIOUS REFERENCE IS A REAL BRAND, AND IT IS THE SAME ANSWER AS THE LAWN
ORNAMENTS.** A specific sportswear maker's swoosh, wordmark and product name are
each registered; moderation strips branded assets and the penalty lands on the
EXPERIENCE. What carries it is the GARMENT, and a garment is a genre -- and the
thing being referenced is genuinely sportswear rather than a crime prop, so
building it as a training hood is both safer and more faithful than building a
burglar's balaclava. The eyes are left showing on purpose: a full cover reads as
a blank egg and takes away the one part of the avatar that is recognisably the
player's.

**THE LOGO IS A PIG SNOUT WHERE THE BRAND'S WOULD BE, ON THE TEMPLE.** Same
substitution the patrol car makes with its roundel and the lawn statue makes
with PIGGY over a snout. On the temple rather than the forehead because the
forehead is the top edge of the eye slot, and because in profile the temple is
the one face of this thing anybody standing on the pavement actually sees. It is
0.18 across: at 0.30 it spanned a quarter of the head's width and read as a
second, larger eye rather than as a mark on a garment -- a logo is small or it is
a face. Its lift is measured against the CHEEK SPHERE it sits on, at that
sphere's surface where the snout actually is (radius 0.695, ten degrees off its
axis) and not where the sphere is widest, or the plate hangs in the air beside
the mask.

**Houses confer nothing.** The house behind a plot is pure prestige, priced above
the skins so it stays the last thing anyone finishes. The power balance is a closed
system of speed, time and distance; hanging a stat off a status symbol reopens
every one of those decisions.

**THE ADMIN PANEL IS A TABLE, NOT A LIST OF CALLS.** It was eighteen
hardcoded `button(...)` lines, which is fine at eight and unreadable at
eighteen -- and every feature added one more to the bottom regardless of what
it related to. `AdminPanel.MENU` is now the whole panel: adding a command is
one row, adding a category is one table, and neither touches a line of the
building code. Grouped by WHAT YOU ARE TESTING rather than by which service
owns it, the same split the shop's four tabs already use.

It is a MODULE for the reason SpinWheel and RaidFX are -- `ClientMain` is at
Luau's 200-local ceiling -- and its body SCROLLS, because a fixed-height panel
with a growing menu has exactly the failure the tab rail already shipped: a
UIListLayout does not clip and does not error, it just keeps drawing past the
edge, so the panel would look like a deliberate six-category panel.

**AN ADMIN COMMAND MAY NAME SOMEBODY ELSE NOW, WHICH MAKES THE ORDER OF THE
HANDLER LOAD-BEARING RATHER THAN MERELY TIDY.** `AdminRequest` carries a
target userId, so the allowlist check has to run BEFORE any argument is read --
nothing below it executes for a non-admin, which is what keeps the target
argument from ever being read on behalf of one. The target is then resolved
SERVER-SIDE from the userId against the live player list, so a stale or
invented id resolves to nobody and is refused rather than silently landing on
whoever now matches. The log names both ends: "who did it" stopped being
enough the moment a command could be pointed at somebody else.

**`reset` IS SELF-ONLY, and that is the one exception the dropdown gets.**
Every other command here is undone by pressing another button; a wiped save is
not. One mis-set dropdown should not be able to delete somebody's account, so
`SELF_ONLY` refuses the target and the panel says so on the row.

**A DROPDOWN SIZES TO ITS CONTENTS OR IT COVERS WHAT IT FLOATS OVER.** Fixed
at 132 pixels it was an empty box in a solo session sitting on top of the
category you had just expanded -- capped as well as sized, because a
twelve-player server would otherwise open a list taller than the panel.

**NAME EVERY INSTANCE A PROBE MIGHT ADDRESS.** Two unnamed `ScrollingFrame`s
in one panel are indistinguishable to anything resolving a path -- a test, a
tool, the next person -- and the click harness simply could not find them.
Heads, rows and groups now carry their command or group in the name.

**Admin access is authorised on the SERVER, never the client.** `AdminService`
checks its allowlist at the top of the one handler, before reading any argument,
and logs every accepted command and every denied attempt. The client panel is
convenience only — the RemoteEvent exists for every player whether or not their
panel was built, so hiding a button protects nothing.

**Fence collision and decoration are separate.** One invisible slab per side carries
all collision; everything visible has `CanCollide` off. Styles can look like
anything without changing the jump maths, which depends only on `tier.top`.

---

## Gotchas that have already bitten

**COLLECTIONSERVICE CANNOT FIND AN INSTANCE THAT REPLICATES ALREADY TAGGED.**
The shop doors were tagged on the server and collected on the client, which
wired NOTHING -- measured at "wired 0 doors at startup". `GetTagged` returned 0
because the shops had not replicated yet, and `GetInstanceAddedSignal` never
fired for them when they did: that signal reports a tag being ADDED on this
peer, and a tag the server set before parenting never is. Both halves verified
-- tagging a fresh local part DOES fire it, and the four doors were tagged and
present to any probe that looked afterwards.

That last part is what makes it nasty: THE BUG IS ONLY REACHABLE AT STARTUP.
Every check run later passes, and the prompts themselves fire correctly on the
client, so everything looks right except the one thing that matters.

This is also why the moat gets away with the identical pattern and is right to:
a moat is built when somebody buys a fifth fence tier, which is always AFTER
the client is running. THE RULE IS THE TIMING, NOT THE TAG -- anything built
during SERVER STARTUP has to be pushed to a client, or found by something that
does not depend on that signal.

**`HouseFX` HAD THE SAME LATENT BUG AND HAD NEVER HIT IT.** It collects by
tag on the client exactly as the doors did, and got away with it because
everything it animated was built LATE: a house light show only exists once
somebody owns a top tier. The shops are built at server startup, so tagging
their neon would have produced four buildings full of parts that never
animated -- present, correct, and dead, which in a still is indistinguishable
from working.

It now runs a BOUNDED RESCAN: the collect repeats every half second for ten
seconds, then stops and leaves the signal to carry everything built from then
on. `register` already returns early for anything it has seen, so a rescan is
idempotent and costs one table walk. Verified afterwards by colour delta
rather than by looking -- all four shops moving, largest delta 0.443 to 0.690
across cycle, pulse, beacon and chase.

****Surfaces must never be coplanar — at any scale.** Two faces at identical depth
give the renderer nothing to sort by, so it picks per pixel and per camera angle
and they flicker through each other. This has now bitten three times: the road
against the grass, the moat against the grass, and the guard dog's eyes against
its own face. Detail parts want to sit slightly PROUD of the surface they
decorate, never flush with it. See the `LIFT_` constants in `NeighborhoodService`
and the eye offset in `GuardDog`.

**Luau forward references, FOURTH time: `makeModelIcon`.** The cosmetic cards
render 3D previews now and are built four hundred lines ABOVE the viewport
helper, so a `local function` down there was invisible to them. Luau does not
error on that -- it compiles the earlier reference against a nil GLOBAL and dies
at the call with "attempt to call a nil value", naming neither the function nor
the cause. It is forward-declared next to `refreshStealPrompts`, which exists
for exactly this reason. When something reads nil and the message names nothing
useful, check declaration order first.

**`Model:PivotTo` aims the PRIMARY PART, not the model's origin, so driving
one by a ground position sinks it by its own anchor part's height.** The two
APIs read as if they take the same thing and do not: `PoliceModel.buildCar`
takes a GROUND origin and offsets every bone up from it, while `PivotTo` takes
the primary part's CFrame -- the car's body at 1.6, the officer's torso at
3.05. Both were driven per frame toward a ground-level Y and both sank exactly
that far: the car spent every patrol 1.6 studs into the tarmac with its wheels
half buried, and the officer converged on `feet = -2.55` against a lawn at
0.50, walking through the grass to the chest. Neither errored and neither
looked wrong in a still. `CAR_PIVOT_Y` and `OFFICER_PIVOT_Y` are derived from
the geometry tables so the numbers cannot drift; anything that moves one of
these per frame must add the offset.

**A lane change folded into a travel heading never happens.** The street is
over four hundred studs long and the two lanes are 8.4 apart, so a single
heading built from both is 99.8% X, and the patrol car crept across the centre
line for the entire length of the road -- measured still straddling the white
line at z=0.14 halfway back. Travel along the long axis and ease the small one
separately. The same shape applies to the officer stepping up a kerb.

**A Roblox cylinder's axis is its X axis.** `Size.X` is the LENGTH along that
axis and `Size.Y`/`Size.Z` are the cross-section, so a vertical column is
`Vector3.new(height, d, d)` plus a 90-degree turn about Z -- never
`Vector3.new(d, height, d)`. Written the wrong way round it becomes a disc as
wide as the height was tall, and the turn that was meant to stand it upright
lays that disc flat instead. This has bitten five times now: the decor car's
wheels, the Midnight Modern's pilotis (two black plates hanging in the air
across the front of the house), the most-wanted hat -- which stood a neon
rod out of the top of the wearer's skull rather than laying a brim on it,
and is a floating label now -- the piggy's own padlock, whose shackle was
Vector3.new(1.5, 1.5, 0.55) and so was a rod aimed at the camera instead of
a U over the body, which is why nobody could tell what it was -- and it is
why `cylinderUp`/`cylinderForward` exist in PiggyBank.

**Luau forward references.** A `local` declared *after* a function that reads it
silently becomes a nil global. This has caused three bugs so far. Declare shared
state above its readers.

**`SurfaceGui` culls by distance from the character, not the camera.** A screenshot
with the camera moved but the character left behind will show a blank board even
when it works in game. The physical leaderboard needs a one-time client-side
`Enabled` off/on nudge after replication — that is a workaround, not a fix.

**Roblox `NormalId`: Front is `-Z`, Back is `+Z`.** Plot signs sit on the `+Z` edge
and need `Back`.

**Never write `TextWrapped` next to `TextScaled`.** Setting `TextWrapped = false`
*after* `TextScaled = true` silently turns `TextScaled` back OFF and drops the
label to the default `TextSize` of 8 — measured on the plot sign, where both
rows rendered as a faint smudge. `TextScaled` implies wrapping. The way to stop
text overflowing is to give the row enough height for the lines it will wrap
into, not to disable wrapping: a wrapped line in a too-short row falls off the
bottom and gets clipped, which is how a maxed-out player's sign came to read
"12* · Neon Tower ·" with the skin missing. `TextBounds` against `AbsoluteSize`
is the check; `TextFits` alone can report true while the last line sits exactly
on the frame edge.

**The sign's ARM is what reaches over the lawn, not the board.** Clearance
between the plot sign and the decor slots has to be measured against every sign
part, because the piece that comes closest to the grass is the cross-arm
hanging back over it. Eyeballing it off the signboard put the first placement
4.9 studs clear when the widest ornament needs 6.4.

**ANY BACKSLASH ESCAPE CAN BE REWRITTEN IN TRANSIT, AND `rojo build` WILL
NOT CATCH IT.** The emoji case below is the famous one, but it bit again this
session on a plain `\n`: two newline escapes written into a shop explainer
arrived on disk as REAL newlines, which ends the string literal mid-sentence.
Luau then refuses the whole chunk, which takes down the ENTIRE HUD rather than
the one label -- and `rojo build` reported success, because Rojo packages Luau
and never compiles it. The only reliable construction is to build the
backslash rather than write one (`chr(92) .. "n"` from the generating script,
`utf8.char` for a character). The cheap check afterwards is to scan for lines
with an odd number of quotes: a broken literal shows up as one immediately.

**HALF THE OBVIOUS DINGBATS ARE NOT IN ROBLOX'S FONT, AND THE ONE THAT IS
IGNORES `TextColor3`.** Rendered side by side at 40px in GothamBold and looked
at: U+2718 HEAVY BALLOT X, U+2715 MULTIPLICATION X and U+2717 BALLOT X all draw
a tofu box, and all three measured an identical 20.0 wide -- that number is the
fallback width, not a glyph. U+2714 HEAVY CHECK MARK does exist, and is worse
in a subtler way: it is an EMOJI-presentation glyph, so it renders in its own
grey and ignores the colour you set, exactly the way the notification chips
were found to. What works and takes its colour: **U+2713 (check) and U+00D7
(multiplication sign)**, plus U+25CF and U+2022 for a dot. `TextBounds` alone
cannot tell you -- a tofu box measures like a character. Render the candidates
and LOOK at them, the same rule this file already writes for CSG holes.

**BUILD A FOUR-BYTE EMOJI WITH `utf8.char`, NEVER A DECIMAL ESCAPE.** The
music toggle's speaker glyph went in as `"\240\159\148\138"` and arrived on
disk as an actual non-breaking space and a carriage return -- one layer of
shell or editor rewrote the escapes into the bytes they named. Luau then
refused the file with *Malformed string; did you forget to finish it?*, which
takes down the ENTIRE HUD, not the button: the chunk never compiles, so
nothing gets built. `utf8.char(0x1F50A)` cannot be rewritten by anything in
the pipeline, and it says which character it is. Note the existing byte-escape
in the garage slot survives only because nothing has edited that line since.

**A DESTROYED INSTANCE STILL ANSWERS PROPERTY READS, so a probe holding one
reads frozen numbers forever.** A ride-sound test grabbed the loop, drove the
character down the street and watched the volume rise correctly and then never
fall -- which looks exactly like a broken update loop. It was not: driving
+Z crossed the road, leaving the street dismounted the player, the model and
its sound were destroyed, and the probe's own reference kept reporting the
last values they ever had. Re-fetch the instance every sample, or assert its
`Parent` is still set, before believing a number that has stopped changing.

**THE MCP MOUSE TOOL DOES NOT LAND WHERE IT IS AIMED, and it fails silently
by returning Success.** Measured while trying to drive a drag on the hot bar:
a `moveTo` at x=1012 put the cursor at x=3, a `moveTo` by `instance_path` landed
314 pixels left and 50 above the target's centre, and a second `instance_path`
move did not move the cursor at all -- `GetMouseLocation` read back byte-
identical. This is the same class of problem already recorded for
`VirtualInputManager` and the keyboard tool, and it means a POINTER GESTURE
cannot currently be verified from here. Verify everything either side of the
gesture through the real remotes instead, and be honest in "Not yet verified"
about the gesture itself rather than reporting the tool's Success as a pass.

**Studio forks scripts when you press Play.** Save, wait a beat for Rojo to push,
*then* Play — otherwise you test stale code and chase a bug you already fixed.

**AND ROJO DOES NOT PUSH AT ALL WHILE PLAY IS RUNNING, which is the sharper
half and costs a cycle every time it is forgotten.** An edit made mid-session
never reaches the DataModel, so the fix appears not to work -- and the
clone-a-ModuleScript trick does not rescue it either, because the clone is
taken from the STALE source sitting in Studio rather than from disk. Measured:
the module on disk was 22,612 characters and the one in the DataModel was
21,393, and a probe against the clone dutifully reproduced the old behaviour
three times. Stop, confirm the source length or a marker string in Edit, then
Play.

**`ProximityPrompt.PromptButtonHoldEnded` fires BEFORE `Triggered`**, and it fires
at hold *completion*, not on release — measured at 0.584s and 0.584s on a 0.6s
prompt. Never clear per-hold state in that handler. Doing so made every steal in
the game silently fail for weeks.

**`CFrame.lookAt` aims LookVector, which is `-Z`.** Models authored facing `+Z`
(the dog, the mini piggy) need `* CFrame.Angles(0, math.pi, 0)` after it, or they
travel backwards. The guard dog ran tail-first through every patrol and chase
from the day it was built until this was caught.

**`Model:PivotTo` moves every descendant.** Anything a model walks *to* must live
outside that model. The kennel started life inside the dog's own model and fled
at exactly the dog's speed, so the dog could never reach it.

**A long `task.wait` is a state machine that ignores the world.** The guard dog's
patrol pause was one flat `task.wait` of up to six seconds, so nothing that
happened during it was noticed until it expired. Bait a dog just after it
settled into a pause and it stood in the open for the whole nap, then ambled to
its kennel afterwards — and against a short nap it never got there at all, so
the one signal that tells a thief the plot is unguarded never appeared. Chases
and the `dognap` admin command were late for the same reason. It is a polled
loop now. Any wait longer than a frame that sits next to shared state wants to
be a poll.

**`Anchored` set on the client does not replicate.** Setting `root.Anchored =
true` and then a `CFrame` to hold a test character in place leaves the *server*
seeing the character wherever it physically was. A throw-range test built that
way passed at every distance including 70 studs against a 42-stud limit, because
the server never saw the character move. Hold a test character with a per-frame
`CFrame` write instead, and confirm the position server-side before trusting the
result.

**Equipping is a TOGGLE, so a script that fires blind flips things off.** Both
accessories and decorations toggle on a repeated request -- that is deliberate,
since it is the only way to empty a slot without a second control. It means a
test script that "equips" a set it already owns takes the set off instead. Drive
it from the pushed state, not from an assumed starting point. This has now cost
time twice.

**Clipping is measured, not eyeballed.** Every accessory is checked against the
body sphere, the eyeballs, the tail and the lawn line before it is looked at:
whether any part is fully swallowed, whether it enters something it should not,
and for the cape whether consecutive panels still touch. Three separate bugs got
past a screenshot and were caught by numbers, and one "fix" that looked right in
a screenshot had opened gaps between the cape panels. Measure the world-space
extents -- `Size.Y/2` is wrong for the rotated parts half of these are.

**A `CFrame.Angles` sign flips which way a panel leans.** The cape's cloth is
laid along its hang line; with the rotation negated the panels tilted ACROSS
that line instead, swinging each one's lower end forward into the pig. No amount
of moving the cape backwards fixed it, because the geometry was wrong rather
than the position -- which is worth remembering before nudging an offset a
fourth time.

**GEOMETRY THE SHOP RENDERS LIVES IN `Shared`, and that is why House, Decor
and the mini piggy are not services.** The shop shows the REAL item, built by
the same function that puts it on a lawn -- nineteen ornaments were identical
grey squares, twelve houses were a wall colour, and a skin was the one thing a
stripe of colour cannot tell you, which is what a piggy wearing it looks like.
House and Decor were always pure geometry over Config with no server-only API
in either, so they MOVED rather than being copied; a second nearly-identical
copy drifts from the original the first time either is touched, which is the
same argument `Decor.buildOne` already makes about the disguise's wheelie bin.
`PiggyBank.buildMini` was lifted into `PiggyModel` and delegated back to,
because PiggyBank is full of things the shop has no business loading -- prompts,
sounds, the coin pile, the vault dial.

**A ViewportFrame RENDERS BASEPARTS AND NOTHING ELSE -- no particles, no
beams, no trails, no lights -- and that is measured, not assumed.** Two
identical viewports were put on screen side by side, one carrying a
200-per-second ParticleEmitter at LightEmission 1 and size 3, and they came out
pixel-identical: the emitter drew nothing at all. Anything that wants to show a
particle effect in UI has to fake it with parts.

**So an effect preview SIMULATES its own Config numbers.** Nothing about the
motion is invented per effect: the speed, lifetime, spread, drag, acceleration
and colour ramp are read straight out of `Config.EFFECTS`, which is what makes
the tiles actually differ -- frost falls because its accel is -4, inferno
rockets through a 34-degree cone because its accel is +14, sparkle drifts
across a full sphere at speed 1 to 2.5, and storm barely moves because it is
big and slow. Verified by measuring net vertical drift per tile: +0.120,
+0.074, +0.036, +0.005, -0.025, which is the exact ordering of the accel column
in Config. Change a number there and the tile follows.

Only the overall REACH is normalised, and only because it has to be: an inferno
particle covers eleven studs in its lifetime and a sparkle covers three, so at
a shared scale one is a blur off the edge of a 156-pixel tile and the other
barely moves. Direction, spread, colour, size and the speed spread WITHIN an
effect all survive.

"None" renders a piggy and no particles, which is the truth about it.

**Shop piggies join the SAME animator list as the twelve on the street.** A
tile's preview carries a `SkinKey` attribute exactly as a real piggy does, so a
Rainbow tile cycles and a Storm tile flickers with none of the animation maths
written twice. The animator takes them as they arrive rather than collecting
once, because a card is built when the catalogue replicates -- long after the
loop starts.

**A card is 156x170 now, and the note about height was right until it wasn't.**
"Cards get taller faster than they get more legible" held while the top of the
card was a flat rectangle; it stopped applying the moment that rectangle became
a rendered Sky Castle. `refitCards` derives everything from `cardFit.full`, so
the short-screen shrink followed on its own.

**THE KEEP COLUMN IS A RULE NOW, NOT AN INVENTORY.** It used to itemise --
"Your 2 skins", "Your 5 lawn decorations", "Your 1 piece of gear" -- nine
rows counted off the pushed catalogues. Every line was true and the column
was a STOCKTAKE, which is the wrong shape for the reassuring half of a scary
page: a nine-year-old deciding whether to press this needs to know that
NOTHING THEY COLLECTED GOES, and counting it back at them makes them audit
the list instead of reading the promise. Five fixed lines.

It is also more honest than the counts were. *Rebirth wipes power but never
cosmetics* is a rule about the GAME rather than about today's inventory, so
stating the rule cannot disagree with what the server does -- where a count
read off a stale push can. `countOwned` and `owned` went with it.

**AND THAT ASYMMETRY WITH THE LOSE COLUMN IS DELIBERATE, because the entry
above it still stands.** "THE NUMBERS ON IT ARE REAL" was written about the
losses, and it is untouched: "Vault Lock Lv 3, Fence Lv 4" is somebody's
actual afternoon and has to be specific. A thing you LOSE has to be exact; a
thing you KEEP has to be total. Those want opposite treatments and it took
this long to say so.

**THE UNLOCK BAND IS PICTURES.** "The Bronze skin, yours to wear" is a thing
you READ; a Bronze piggy is a thing you WANT, and this page exists to make
somebody want to press the button. Same argument the shop already settled --
nineteen lawn ornaments were identical grey squares until the cards rendered
the real item -- arriving on the one screen where the decision is largest.
Three tiles: a drawn coin for the income, a piggy with a gold "?" for the
guaranteed skin, and the named skin rendered from ITS OWN KEY off the pushed
catalogue, so the picture cannot disagree with the name under it.

**THE MYSTERY TILE IS A "?" BECAUSE THE REWARD IS A ROLL.** Rendering a
specific skin there would promise something the server never said. The image
of "a skin, and you will find out which" is a piggy with a question mark on
it, not a piggy nobody was offered.

**`makeModelIcon` IS HANDED IN, NEVER REIMPLEMENTED.** It lives in ClientMain
and knows things `Rebirth` has no business knowing: how to frame a model from
its own bounding box, which way to tilt it, and that the ICON copy re-centres
on its visual centre while the world copy keeps its authored pivot. A second
nearly-identical viewport helper is the copy that drifts the first time
either is touched -- so `Rebirth.init` takes it as a third argument, optional,
degrading to empty wells rather than to no page.

**A BADGE IS BUILT AFTER THE THING IT LABELS, because `layer` re-stamps every
ZIndex by DEPTH once the page is built.** The badge and the ViewportFrame are
siblings, so they end up on the same level and CHILD ORDER decides which is
on top. Built second the badge wins; built first it would sit behind the
picture it is labelling.

**CENTRING THE TILES LOOKED RIGHT AND MEASURED WRONG.** Three 128-wide tiles
in a 1140-wide band leave nearly four hundred pixels either side, so the row
floated in the middle of the band with YOU UNLOCK stranded in an empty left
third. Left-aligned under the heading it reads as one block, and it reads the
same whether the rebirth hands over two tiles or three.

**AND THE BAND'S HEIGHT IS DERIVED FROM THE TILE, not nudged until it fitted:**
band = well + caption + the list's own 36 of inset, and `columns` takes
whatever the header, the band, the footer and three 10-pixel gaps leave. Grow
the well and both follow.

**AND THE BUTTONS THEMSELVES WERE THE ONE THING IN THE GAME WITHOUT THE INK
LINE.** `Theme` calls that outline "the whole trick" -- it is what makes a
surface read as drawn, and what gives a pale card an edge against bright
grass -- and the four loudest controls on the HUD did not have it. The
rebirth button carried a 2px violet stroke at 0.55 transparency, and every
`makeActionButton` (SHOP, DODGE, MANUAL) carried `tint:Lerp(white, 0.45)` at
1.5px. Those are HIGHLIGHTS, not edges: they were correct on the old dark HUD
and invisible once everything around them became a cream card with a hard
black line round it. Reported, exactly, as forgetting the actual button
players press.

**A GUIOBJECT TAKES ONE UISTROKE, SO THE PULSE HAD TO MOVE OFF IT.** The
rebirth button's breathing edge and the ink line cannot both be strokes on
the same frame, and the ink line is not negotiable. The pulse is a HALO now:
a separate frame 7 studs proud on every side, in the same violet, tweening
its transparency at the same 0.45 cycles a second.

**AND THE HALO HAD TO BE A SIBLING, NOT A CHILD -- which is the trap.** Under
`ZIndexBehavior.Sibling`, which this HUD uses, a CHILD ALWAYS DRAWS ABOVE ITS
PARENT whatever its ZIndex. So a halo parented to the button covered the
button, its shading and -- worst of all -- the 3px ink line it was added to
sit behind, as a 0.62-transparent wash over the one thing that has to stay
hard and dark. As a sibling at a lower ZIndex it draws underneath, which is
what a halo is. The cost is that it no longer inherits `Visible`, so that is
mirrored with a property watcher rather than set at the two sites that toggle
the button -- a watcher cannot drift out of step with what it watches.

**THE CONTRAST AUDIT WAS BLIND TO GRADIENTS, AND THAT IS THE REAL FINDING
HERE.** A probe reads `BackgroundColor3`, which is the TOP of a `UIGradient`
ramp; a label sitting lower down is on something darker that the probe never
sees. Measured: the REBIRTH! button was plainly unreadable in a screenshot
while the whole HUD reported clean, because `Theme.gloss` ran to a deep
violet and took ink to **2.47**. The audit now evaluates the gradient at each
label's OWN vertical position within its ground -- not the fill, and not the
gradient's darkest point either, which over-corrects and flagged five shelf
titles that sit at the top where the ramp has not started. Position-aware, it
found exactly one real failure and no false ones.

**`gloss` RUNS TO A COLOUR; `shade` MULTIPLIES. DARK TYPE NEEDS `shade`.**
There is no deep stop that carries ink on the prestige violet -- the value
that clears 4.5 is (155, 115, 250), which IS the fill, so there is no gloss
to be had. Both rebirth buttons and every action button use a shallow
`Theme.shade` instead. The rule: anything printing dark type on a saturated
fill gets `shade`; `gloss` is for surfaces whose text sits on the light end,
or which carry no text at all.

**A MID-TONE CARRIES SMALL TYPE OF NEITHER POLARITY, and that is why the
DODGE tile stopped being blue.** `Theme.COOL` is 4.96 against ink flat --
thin before any shading -- and the stacked label sits at the BOTTOM of the
sheen, where it measured 3.17. Paper text does not rescue it: 3.80, failing
the same floor from the other side. There is no text colour that works, so
the GROUND had to move. It is `Theme.PAPER` now and the same label reads at
14.98.

That was the right answer for a second reason, already written in the source
above `makeActionButton`: a stacked control "has to be the same KIND of
object as the garage slot beside it". Once that slot became a paper card, a
blue tile next to it stopped being one. The tint is not lost -- on a stacked
slot it colours the KEY CHIP, which is small enough to cost the card nothing.
The garage's own edge came along too: ink at rest, GOLD when a ride is out,
which is the signal the hot bar's equip ring already uses.

**A SPAN REPLACEMENT SILENTLY DROPPED `button.Size = size`, and three
controls collapsed to nothing.** Rewriting the head of `makeActionButton`
took out one property line that was not part of what was being changed. It
did not error: the buttons built, the layout reflowed around three zero-sized
frames, and the bottom-left corner simply had no dodge in it. Same class as
the blurb-deleting regex already recorded here. WHEN A SPAN IS REPLACED
RATHER THAN EDITED, DIFF THE PROPERTY LIST -- the check is which assignments
survived, not whether it compiles.

**THE TWO LOUDEST BLOCKS OF COLOUR LEFT WERE THE PIGGY BANK PANEL AND THE
REBIRTH BUTTON, AND BOTH WERE THE SAME FAULT AT SMALLER SCALE.**

**A 320x74 BLOCK OF PINK READS AS PINK, NOT AS A PIG.** The panel's own
comment defended it well: everything else on this HUD is cream and gold,
which is coins, so the one readout about the PIG needed something of its own.
What it got wrong is WHERE. An accent spent on a ground is an accent spent --
the rule that took the shop off its pink panel -- and here it cost TWICE,
because the bar drawn ON that pink then had no pink left to be drawn in.

**THE BAR COULD NOT SHOW ITS OWN FILL, and that is the part that was a bug
rather than a preference.** Measured: the empty half sat at **1.41** against
the orange it turns when full and 1.87 against the gold it is the rest of the
time. So the one readout in this game that is a PICTURE OF A NUMBER could not
show you the number, and nothing about the panel looked broken enough for
anybody to check.

**THE COIN BADGE TWO HUNDRED PIXELS AWAY ALREADY HAD THE ANSWER, and its own
comment says so.** It was a gold ground with a gold coin on it -- "one gold
too many" -- and it became a PAPER card with a DRAWN gold coin. This was one
pink too many, and it is that badge's sibling now: same card, and the pig is
an OBJECT on it. `Theme.snout` is a drawn snout beside the title, for exactly
the reason `Theme.coin` is drawn -- an emoji renders from the colour font,
ignores `TextColor3` and is a smudge at chip size. The bar track carries the
rest of the pink, deepened to (196, 76, 120): **2.98** against gold and 4.24
against the card behind it, so the bar reads as a bar from across a room.
Anything that touches `Theme.PIG_DEEP` gets measured against BOTH fills.

That is also the general shape of it: **pink and gold go on OBJECTS, never
under them.** A drawn coin and a drawn snout say "money" and "pig" far
louder than a rectangle of either colour, and they cost the ground nothing.

**REBIRTH WAS WEARING THE SHOP'S EFFECTS TAB.** `Theme.HUE.effects` is a
colour whose entire job is to say "this tab", and the biggest decision in the
game was borrowing it. Nothing was visibly wrong, because the rebirth button
hides itself behind the shop panel and they never appear together -- it was
simply one colour saying two unrelated things. `Theme.PRESTIGE` is its own
colour now, because nothing else here was going to be: gold is money, pink
the pig, green good, orange caution, red alarm, blue the police.

**IT WAS A LIGHT VIOLET FOR ONE SESSION AND THAT WAS THE WRONG HALF OF THE
TRADE.** It was solved like a category hue -- value at 1.0, saturation eased
until INK type cleared -- and it only just did, at 4.67, the worst body pair
in the game. The number that actually gave it away was the STAR: the gold
chip this button carries measured **2.25** on that violet, so the one element
naming the reward was the least readable thing on the control. Reported as
the button looking muddy, which is precisely what a label and a badge both
sitting on the floor look like.

**A MID-TONE CARRIES NEITHER POLARITY -- the same finding that moved the dodge
tile onto paper, resolved the opposite way.** The dodge went LIGHT because it
sits in a row of paper slots; rebirth goes DARK because it is one button that
should feel expensive. Deep plum with PAPER type: the label goes 4.67 to 7.80
(9.06 at the gloss bottom) and the gold star 2.25 to 5.48. The star chip
INVERTS with it -- gold ground, ink numeral -- because an ink chip on a deep
plum is 2.08 and vanishes.

**AND PLUM RATHER THAN VIOLET BECAUSE OF WHERE IT SITS ON THE WHEEL.** Violet
was the one cool surface in a warm palette, which is what read as not
matching. Plum sits with gold, pink and sand, and is far enough from PIG
(342, and light) and STOP (6) that it can be neither the pig nor danger.

**THE HALO HAD TO GO THE OTHER WAY WHEN THE FILL WENT DARK.** A halo in the
button's own colour was a glow while the fill was light and became a SHADOW
the moment it was not -- a dark wash spilt on the grass behind the button. It
is the fill lifted 45% toward paper now, so it reads as light coming off the
control rather than as something under it.

**THE TWO BUTTONS ARE ONE CONTROL IN TWO PLACES AND WERE BUILT FIVE HUNDRED
LINES APART, which is the whole reason they drifted.** The HUD one had a 3px
opaque ink outline, a 12 corner and a sparkle; the confirm had a 1.5px stroke
at 0.4 transparency, a 10 corner and no glyph. Matched piece by piece now,
and NOT YET took the same radius and line as its neighbour -- the hierarchy
between those two is carried by the FILL, paper against plum, rather than by
one of them being drawn more faintly. Only the halo is left off the confirm:
that one pulses to catch an eye looking at the WORLD, and on a modal page
nothing is competing for it.

**AND THE REBIRTH PAGE WAS STILL ON THE OLD COLD NAVY.** Its ground was
`INK`, which in that file meant (28, 33, 44) -- the dashboard palette, on the
one screen in the game that exists to explain an irreversible decision. It is
`Theme.SAND` now, the same ground the shop panel uses, because they are the
same kind of object: a large modal with paper cards on it. Sharing it means
the page a nine-year-old meets once looks like the screen they already know.

**`makeRow` SERVES THREE LISTS AND ONLY TWO OF THEM ARE ON PAPER.** KEEP and
LOSE sit on cards; UNLOCK sits on a SAND_DEEP band, where faded ink measured
**4.30** against a floor of 4.5. All three rows print in INK now -- none of
those sentences is secondary text, and the tick, cross or star beside each
already carries the tone. A helper shared across grounds cannot pick a text
colour from the tone alone.

**AND THE PANEL'S PARTS WERE ALL CALLED `Frame`, which this file already has
a rule about.** A probe checking the half-full state matched the TRACK
instead of the FILL and resized the wrong thing -- the exact failure "NAME
EVERY INSTANCE A PROBE MIGHT ADDRESS" exists to prevent, hit while verifying
a fix for something else. They are `Snout`, `Title`, `Rate`, `Track`,
`Track.Fill` and `Track.Amount` now.

**THERE WERE FOUR PALETTES, AND THE MEASUREMENT IS WHAT SETTLED IT.** The
complaint was that the theming is inconsistent, which was true and is worth
stating as a number rather than as an impression: `ClientMain` alone carried
**163 colour literals in 101 distinct values**, and four files -- ClientMain,
ShopStyle, Rebirth and AdminPanel -- each declared their own private set of
locals for the same jobs. Two of those near-blacks were **a hundred degrees
apart on the colour wheel**: `Theme.INK` at hue 322, a plum, and ClientMain's
own INK, the shop's icon well and every survivor of the old dashboard at hue
221, a navy. There were two golds two degrees apart. `Theme` is the only
place a colour is decided now; ClientMain is down to 19 literals and every
one of those is the arrest scene's own world, a text halo, or 3D lighting.

**THE PINK WAS WRONG BECAUSE IT WAS A GROUND, NOT BECAUSE IT WAS PINK.** This
file already says GOLD MEANS MONEY AND PINK MEANS THE PIG, AND THAT IS THE
WHOLE COLOUR SYSTEM, and the shop broke it -- painting the panel pink spent
the pig's own colour on the largest surface in the game, so the piggy bank
panel on the HUD, the one readout that IS the pig, had nothing left to be. An
accent spent on a ground is an accent spent. Making the shop GOLD instead
would have cost the coin counter exactly the same thing, which is why the
answer to "make it a lighter pink" and the answer to "use that yellow
instead" are the same answer: **the ground is SAND**, a warm neutral one step
under PAPER carrying no meaning at all, and pink and gold went back to being
accents that say something.

**ONE WARM AXIS, HUE 21 TO 39, OUTLINE TO PAPER.** INK, SLAB, MUTED, SAND and
PAPER are one ladder. That is the property to check before adding anything: a
cold grey dropped into this set looks like a mistake to somebody who cannot
say why, and it is exactly what half the HUD was.

**A SHOP CARD AND A HUD CARD ARE NOW LITERALLY THE SAME COLOUR**, which is
most of what "consistent" meant here. `ShopStyle` keeps its names because 167
call sites read them, but every one is an alias for a `Theme` value.

**THE ACCENTS ARE A FAMILY, AND EQUALISING THE NUMBER IS NOT EQUALISING THE
APPEARANCE.** Saturation 0.72 throughout, value 0.90 -- except in the green
band (hue 80 to 200) at 0.82, because green and lime read considerably
brighter than red and blue at the same value. GOLD is the one deliberate
exception, carried at full value because it is a MATERIAL rather than a
category: it is what a coin is made of.

**AND EVERY CATEGORY HUE HAS TO CARRY INK TYPE, which the family rule alone
did not give them.** A shelf card is a block of its own colour with its name
printed on it, so this is a hard constraint rather than a preference. Built at
a flat value three of them failed: red 4.26, pink 4.10 and purple **3.20**
against a floor of 4.5 -- all three on the front page, where a nine-year-old
picks a category by looking at it. Red and pink only wanted their value taking
to 1.0 and kept their saturation; purple is the one hue on the wheel that
cannot be bright at full saturation and eased to 0.62. Fully equalising the
family on ink-contrast instead was tried and is worse: it lands every hue at
luminance 0.29, which turns the gold into an olive.

**THE ALIASES IN `Theme.HUE` ARE KEPT IN STEP BY HAND, AND THAT IS WHERE IT
BROKE.** `skins` IS `piggy` and `kit` IS `upgrades` -- a section and the tab
it lives on must be one colour -- and both were missed when red and pink were
lightened. The live audit came back with exactly those two and nothing else,
which is the whole argument for running it rather than looking.

**`Theme.readable` ONLY WALKED DOWN, WHICH IS RIGHT ON PAPER AND EXACTLY
WRONG ON A CHIP.** Asked for a readable green against a near-black well it
returned a DARKER green -- so the one call that most needed help got the
answer that made it worse. Nine of the twenty-seven remaining failures were
that. The ground decides the direction now: below a luminance of 0.18 the
tone is LIFTED instead, value up and saturation eased off, because a
saturated hue cannot get bright enough on its own to clear a dark ground.

**AND SECONDARY TEXT NEEDS TWO COLOURS, because one cannot be secondary on
both grounds.** `Theme.MUTED` is faded ink for paper and `Theme.MUTED_LIGHT`
is faded paper for a slab. The sweep that moved the shop onto paper moved the
CARDS and left everything printed inside the dark PRICE PILL solved against
the card sitting behind it -- nine labels, all of them the same mistake.

**THE PRE-DARKENED ACCENTS EXIST SO THAT A COLOUR IS DECIDED ONCE.**
`Theme.GOOD_INK`, `WARN_INK`, `STOP_INK`, `GOLD_INK` and `COOL_INK` are the
text forms, solved at load. `Theme.readable` is still the right tool at a
call site that knows it is sitting on something unusual -- the piggy bank's
rate is printed on PINK, where the paper-solved green measured 2.67.

**CARD STATE IS THE ONLY THING A CARD'S BACKGROUND SAYS**, since its edge is
the rarity and its pill is the price -- so a state you cannot see is the
background saying nothing. The four tints are each their accent lifted 58% to
PAPER. The first pass used 74% and every state landed within 1.006 to 1.209
of the ground: on the skins tab, with twenty-seven affordable cards, seven
owned and thirteen locked on screen at once, the three read as one cream.
DEAR goes the other way and sits BELOW the ground, because too dear should
read as recessed.

**AN EMPTY RUNG IS NOT A WELL.** The upgrade pips used `SUNK` for "not bought
yet", which put six rows of near-black bars across a cream card and read as
disabled rather than as empty. A well holds a rendered model and wants to be
a hole; a pip is a groove, and belongs one step under the ground.

**THE ARREST SCENE WAS ROTATED, NOT REDESIGNED.** It is a mugshot board and
it stays DARK -- that is the register of the thing. What it stops being is
navy, which was the last of the old palette anywhere in the game. Every
colour in it keeps its EXACT WCAG luminance and only its hue moved onto the
warm axis, so not one contrast pairing in that scene can have changed. That
is the cheap way to re-theme something that has already been verified.

**THE TONES IN `Config` ARE WRITTEN OUT AS NUMBERS ON PURPOSE.** Config
requires NOTHING -- it is pure data pulled in by every server service -- and
making it depend on a UI module to name a colour would be the wrong trade by
a distance. The family is DERIVED, so a new tone is not a taste decision, and
four sit off it deliberately with a reason at each entry: money is the real
GOLD, the prank is pulled back from a pure magenta (it is the one hit that
costs the player nothing and should not be the loudest colour in the set),
hiding is deliberately a NEUTRAL because it is not good, bad, money or
danger, and the shop door and the alien recovery are moved off GOOD's own
green so that four meanings are not one colour.

**THE RARITY LADDER'S `common` WAS THE LAST COLD THING, AND ONLY BY HUE.** A
blue-grey at hue 214 is a perfectly good neutral in a cold palette and the
one thing this one has no room for -- beside a warm outline it reads as a
colour rather than as an absence of one. Rotated to hue 30 at its exact
luminance (0.3554 to 0.3561), so nothing about how it RANKS against rare,
epic and legendary moved; only which palette it is from.

**THE SHOP BUTTON WEARS THE SHOP DOOR'S OWN TONE, taken from
`Config.PROMPTS.shop` rather than copied.** Both open the same thing, one on
the street and one in the corner. It also settled a collision the sweep
created: it had landed on the same purple as REBIRTH, which is the loudest
button on the HUD and an entirely unrelated action.

**AUDIT BY WALKING THE LIVE TREE; DO NOT OPEN THE PANEL AND LOOK.** Every
visible label against its own painted ancestor, 3.0 for large or scaled type
and 4.5 for body. It went **69 failing pairs to 0 across 425 labels** in four
passes, and not one of those was found by looking at a screenshot. Two probe
rules that matter: skip every non-ASCII glyph, because an emoji carries its
own colours and ignores `TextColor3` (measuring one reports a confident
failure that is not real); and treat a `TextScaled` label as LARGE, since it
reports `TextSize` 8 while rendering at three times that.

**THE HUD WAS A DASHBOARD AND THIS IS A CARTOON.** Everything was cold navy
-- ink (28, 33, 44) on panel (38, 45, 60) -- with a thin accent stroke and a
grey body font, which is the default look of every admin console ever built
and the wrong one for a game about robbing a piggy bank, aimed at
nine-year-olds, rendered in full sun on green grass. `Shared/Theme` is the one
place that decides now, and three things carry it.

**THE INK OUTLINE IS THE WHOLE TRICK.** A hard dark line round every surface
is the single difference between a flat rectangle and something that reads as
DRAWN -- it is what a sticker, a comic panel and every cartoon UI have in
common. It also does a real job rather than only a stylistic one: a pale card
on bright grass has no edge of its own, and a 2px coloured stroke does not
give it one. 3px, warm near-black, on every surface.

**THE GROUND IS WARM PAPER, NOT COLD SLATE.** Cream reads as a label stuck on
the world; navy reads as a window cut into it. The near-black is a plum rather
than a blue-grey, because a cold outline on a warm surface is the tell that a
palette was assembled rather than chosen.

**GLOSS IS A GRADIENT, BECAUSE THERE ARE NO IMAGE ASSETS.** Real texture means
an upload, an upload is a third-party asset that can be moderated away, and
this project builds the ground, the houses and the piggies in code for exactly
that reason. A held highlight across the top third then a fall to a deeper
stop is the asset-free way to make a surface look moulded rather than printed.

**AND `Theme.shade` EXISTS BECAUSE ONE SURFACE CHANGES COLOUR EVERY FRAME.**
`Theme.gloss` bakes two colours in, which is right for anything with a fixed
ground and useless for the street banner, which rewrites its own
BackgroundColor3 per phase and flashes during a pursuit -- a baked gradient
would simply replace whatever it chose. A UIGradient MULTIPLIES the
background, so a white-to-grey ramp is a pure shading pass that leaves the hue
to the caller.

**COLOUR STILL MEANS SOMETHING; IT STOPPED BEING THE GROUND.** `Config.NOTIFY`
and `Config.PROMPTS` are untouched. What moved is where a tone GOES: it was
the panel and the stroke, and it is now the chip ring, the stripe, the heading
and the hold bar, on a surface that stays the same colour whatever happened.
Every card being a differently-coloured dark rectangle is what made this look
like a dashboard.

**GOLD MEANS MONEY AND PINK MEANS THE PIG, AND THAT IS THE WHOLE COLOUR
SYSTEM.** The coin badge was a gold ground with a gold coin on it, which is
one gold too many -- the coin had nothing to stand out against and the
numerals fought the hue they were printed on. The badge is paper now, the coin
is the only gold object on it, and the PIGGY BANK panel is PINK. That last one
matters more than it sounds: everything on this HUD was cream and gold, which
is coins, so the one readout about the pig itself had no colour of its own and
read as another cream card. Gold is what you have banked; pink is what the pig
is still holding.

**A CHIP IS A HOLE FOR AN ICON, SO IT HAS TO BE NEAR-BLACK.** `Theme.SLAB` was
(64, 46, 58), which at hue 327 is a PLUM -- reported, accurately, as "a purple
circle". A chip exists to be something the icon sits in, not a colour of its
own. (44, 32, 34) is warm and dark and reads as a hole.

**A DRAWN COIN BEATS THE COIN EMOJI, and the emoji was the other half of that
report.** It rendered at 19px inside a 34px chip, from the colour font, and
ignored `TextColor3` like every emoji does -- so it was a smudge that could
not even be recoloured to help. `Theme.coin` is three nested frames: a gold
disc, a deeper rim so the face reads as struck, and one off-centre highlight.
Legible at any size, takes the palette, and costs no more instances than the
chip it replaced. THE SAME ARGUMENT APPLIES TO ANY SMALL EMOJI IN THIS UI:
they are fine at chip size on a card and unreadable below it.

**THE SHOP HAD ITS OWN PALETTE AND IT WAS THE GENERIC ONE.** `ShopStyle` was
BASE (38, 42, 66) on CARD (56, 62, 92) with near-white text -- cold navy, the
default of every dark interface built in the last decade, and a SECOND
unrelated palette to the HUD's, so opening the shop changed which game you
were in. It is warm dark now, off the same `Theme.INK`, so the line round a
shop card and the line round a toast are the same line.

**IT STAYED DARK ON PURPOSE, though.** The HUD is light cards ON the world;
the shop is a large modal panel OVER it, and a full screen of cream is glare.
Light cards on a dark board, both cut from one palette, is the arrangement --
not "everything is cream now".

**A PALETTE INVERSION IS CHECKED BY MEASURING EVERY LABEL, not by opening the
panel and looking.** Any label that hardcoded a colour instead of asking
`ShopStyle` would be the wrong side of its new ground, and there is no way to
eyeball 304 of them. Measured against each label's own painted ancestor: worst
3.06, everything clears the 3.0 large-text bar.

**AND TWO PROBE MISTAKES ARE WORTH THE WARNING.** Measuring an EMOJI's
`TextColor3` against its ground is meaningless -- an emoji ignores it -- and
doing so reported a crossed-swords tab icon at 1.50 as though it were a
failure. And walking up from a child to "the panel" by stopping at the first
full-width ancestor lands on the HEADER every time; walk to the outermost
GuiObject. The header also reads back a default grey because it is
`BackgroundTransparency = 1` and never painted at all.

****MOVING THE GROUND TO CREAM SENDS A BILL, AND IT LANDS ON THE TONES THAT
WERE EASIEST TO READ BEFORE.** `collect` is gold and `recover` is a pale mint:
both were perfect as light text on a dark panel and both are nearly invisible
as text on paper. Measured, the gold verb sat at a contrast ratio of 1.4
against the card it was on. `Theme.readable` walks a tone's VALUE down --
holding the hue, nudging saturation up so a dimmed pastel deepens instead of
turning to mud -- until it clears 4.5 against the ground. Measured after, all
seven prompt tones and all four titled notify tones land 4.61 to 5.17, from
1.41 to 3.77 before.

**IT IS APPLIED AT THE CALL SITE AND NOT INSIDE `Theme.title`, which is where
the tidy version would have put it.** That helper has no idea what its label
is sitting on, and two of its callers are on SATURATED grounds -- the carry
banner's gold on red and the street banner's white on a colour that changes
every frame. Folding the darkening in would have fixed the quiet labels and
made the loudest two unreadable.

**THE CARRY BANNER'S GROUND WENT DOWN RATHER THAN ITS TEXT GOING PALE.** Gold
on the first red measured 2.40, the worst pairing in the HUD and on its
loudest element. Four grounds were measured; at (162, 36, 32) gold reaches
4.77 and cream 7.18, so the red deepened. Paling the text instead would have
turned an alarm into a pink label.

**AND THE COLLECT PROMPT STOPPED REACHING ACROSS THE LAWN.** It was 16,
hardcoded in PiggyBank, against a piggy 12 studs across -- so it reached TEN
studs past its own surface and an owner could bank from a third of the way
across their plot, before they had visibly arrived at the thing they were
banking into. `Config.COLLECT_RANGE` is 9, which is 3 studs off the surface,
and deliberately TIGHTER than `STEAL_RANGE` -- an owner should not get the
prompt from further out than a thief needs to reach it. STEAL_RANGE itself is
untouched at 11: it is load-bearing for the getaway.

****SEVEN ACTIONS SHARED ONE PICTURE, and that was every interaction in the
game.** Roblox's default ProximityPrompt is a grey pill with a letter in it,
drawn identically whether a player is banking their own coins, robbing
somebody else's piggy, climbing into a wheelie bin or tipping somebody out of
one. The loudest thing anybody can do on this street looked exactly like the
quietest, and the only way to tell them apart was to stop and read.

`Config.PROMPTS` is the vocabulary and `Shared/PromptUI` is the one place that
draws it -- deliberately the same shape as `Config.NOTIFY`, so adding a
treatment restyles every site already using that kind without touching one.
The tones are BORROWED FROM NOTIFY on purpose: robbing somebody is the same
red their alarm toast will be, banking is the money gold, being tagged is the
chase amber. An action and the message it produces are one colour.

**COLOUR IS NEVER THE ONLY SIGNAL, which the rarity borders already learned.**
Every prompt carries a tone, a GLYPH and a WORD. Red reinforces STEAL; it is
not how you know.

**AND THE CHIP IS A DARK DISC WITH A TONE RING, for the reason the toast
chips are.** An emoji carries its own colours and ignores `TextColor3`, so a
red siren on a red disc is a red smudge.

**THE HOLD SHOWS HOW LONG IT IS, which is the HUD half of the vault-lock
problem.** A default prompt draws the same filling circle whether the hold is
three seconds or nine -- the reason that whole tree was once invisible to the
thief standing in front of it. The dial answers it from the street; over
`Config.PROMPT_COUNTDOWN_OVER` seconds the card answers it at arm's length
with a real countdown, so a thief knows they are committing to twelve seconds
BEFORE they commit. Verified on a 6s hold: bar 0.19 -> 0.80 linear, countdown
running down to 1.2s.

**`PromptButtonHoldEnded` IS NOT "CANCELLED".** It fires at hold COMPLETION as
well as on release -- this file has it measured at 0.584s on a 0.6s prompt,
firing before `Triggered` -- so PromptUI only ever uses it to stop the fill.
Anything that treated it as an abort would be the same bug that made every
steal in the game silently fail for weeks.

**TWO PROMPTS SHARE A PART IN TWO PLACES, AND THE GAME ALREADY GUARANTEES
THEY ARE EXCLUSIVE.** collect/steal sit on a piggy's Body and hide/dig on a
bin's Hatch, so a naive renderer would stack two cards on identical pixels.
It does not happen: measured live, exactly one card at a piggy, because
`collect` is enabled only for the owner and `dig` only when somebody is
inside. Anything that adds a third prompt to a shared part has to keep that
property -- there is no offsetting logic and there should not need to be.

**`prompt.UIOffset` IS A VECTOR2 IN SCREEN PIXELS, and adding it to a stud
offset throws.** It is for the default UI. A custom card positions itself in
studs and owes the old one nothing -- caught loudly on the first frame anybody
walked up to a piggy, which is the right way for it to fail.

**A PROMPT PROBE HAS TO MATCH ON CONTENT, NOT ON ADORNEE, and stand inside the
prompt's own radius.** Both mistakes were made here and both produced
confident wrong answers: matching by adornee made the steal card read as
"BANK COINS" (its sibling on the same part), and standing 7 studs from a
5-stud bin prompt reported "NO CARD" for two kinds that were working
perfectly. Derive the stand-off from `MaxActivationDistance`.

**AND ENABLING A PROMPT WHILE ALREADY IN RANGE DOES NOT FIRE `PromptShown`.**
It fires on ENTERING range. A test that flips `Enabled` and then looks will
find nothing; leave the area, flip it, walk back.

****A notification's KIND is its whole design, and there are eight of them.**
`Notify(message, kind)` reaches roughly a hundred and thirty call sites across
twelve services, and `Config.NOTIFY` is what a kind means: a colour, a glyph,
an optional headline, a sound and a hold. It was two kinds for everything, so
banking coins, being refused a purchase, and a stranger emptying your piggy
bank all arrived as the same grey bar with different words in it -- the
loudest thing in the game read exactly like the quietest. Adding a treatment
to that table upgrades every site already using the kind without touching one
of them, which is why the vocabulary is the only thing that has to be agreed.

**Toasts STACK, and each owns its own clock.** The old one replaced its
predecessor, which failed hardest exactly where it mattered: a robbery fires
three notifications inside a second and you saw only the last. Newest at top,
and the cap is derived by counting the stack's children -- a counter desynced
immediately, because a card retired early by the cap still had its own
fade-out scheduled and decremented twice, measured at five cards against a
limit of four.

**A CARD'S HOLD IS A FUNCTION OF HOW MUCH THERE IS TO READ, and a flat one is
the wrong number for every message but one.** Each kind carried a single hold
of 2.2 to 4.5 seconds, so "Banked 12 coins" and a fourteen-word robbery alert
got the same window and the long ones were gone before a nine-year-old had
finished the first line. They are also read by somebody who is RUNNING -- the
card is not what they are looking at -- so the clock has to cover NOTICING it
as well as reading it. A kind's `hold` is now a FLOOR and `Config.NOTIFY_READ`
is the other half: 2.2s to notice plus 0.42 a word, capped at 9. Measured
end to end on all nine kinds, card birth to destruction: money 3.9s, warn
4.4s, chase 6.0s, police 7.2s, alarm 8.9s against the 4.5 it used to get.

**THE CARD WAS SHORTER THAN ITS OWN ICON, which is half of why the icons
looked wrong.** The chip sat at a hand-set (15, 10) and the text column at a
hand-set (56, 10). `AutomaticSize` measures children, and on a one-line
message the tallest was the column at 10 + 18 + 12 = 40 -- while the chip
needed 10 + 32 = 42. Measured at a **38px card holding a 32px chip that
reached 42**, so the icon hung out of the bottom of the card it was drawn on.

**AND NOTHING ALIGNED THEM.** On a one-line card the text centre sat **6.4px
above** the icon's; on a title-plus-body card it sat **16.6px below**, leaving
the icon stranded at the top. Two hand-set offsets cannot both be right when
one of the two things changes height and the other does not. A horizontal
`UIListLayout` with `VerticalAlignment.Center` fixes both at once and cannot
drift: the row grows to whichever is taller, the card grows to the row, and
the shorter one is centred against it. Verified across all nine kinds on 56px,
70px and 85px cards -- **icon-to-text alignment 0.0 on every one**, and the
card always contains its chip. The stripe stays a direct child of the card
deliberately: a UIListLayout owns EVERY child of its parent, so an accent bar
that has to hug the left edge cannot be a sibling of the row.

**A BMP EMOJI HAS A TEXT FORM, AND U+26A0 DEFAULTS TO IT.** The other half of
"the icons aren't centred". Six of the nine glyphs are four-byte emoji with no
text form and always render from the colour emoji font; the three BMP symbols
have one, and the warning triangle took it -- so it was drawn by Gotham as a
monochrome character while everything beside it was drawn as an emoji.
Measured in a 32x32 chip at TextSize 17: every other glyph advances **16.0**
and the triangle advanced **12.0**. That landed on the kind players see most,
since every refusal in the game is a `warn`. Appending VARIATION SELECTOR-16
asks for the emoji form explicitly and takes it to 16.0. It goes on all three
BMP glyphs rather than only the broken one, because the tick and the cross
happen to default to emoji on THIS machine and that is a per-platform font
decision rather than a promise.

**The banner glyphs are a SEPARATE table and were measured before assuming
anything.** `GLYPH` in ClientMain does not read `Config.NOTIFY`, and this file
records the patrol banner's longest line at 277 of 282 usable pixels -- so a
glyph that got 4px wider there would have overflowed. Measured at TextSize 15:
all five banner emoji advance 14.0 including `bolt` (U+26A1), which is BMP and
could have had the same fault and does not. Nothing was changed there.

**THE STACK IS CAPPED BY MEASURED HEIGHT, NOT ONLY BY COUNT.** Four cards was
fine while a card was 38px tall. Once a card contains its own icon it is 56 at
its shortest and 85 with a headline, and the longer holds mean four coexist
routinely -- four tall ones is 364px, which runs past the garage slot, the one
neighbour this corner has. So the limit is the stack's own `AbsoluteSize.Y`
against the band that is actually free: viewport minus the stack top minus the
bottom-left's 216-pixel reserve. Derived per screen rather than assumed -- this
window gives 435px, a phone held sideways gives 258. The count cap stays as a
backstop. The trim is deferred a frame, because AutomaticSize has not measured
the new card yet and trimming against a stale height retires nothing.

Verified both ways with eight tall cards fired in 2.4 seconds: at a 435px band
the stack peaked at 364px and 4 cards (the count cap held it), and with the
band tightened to 180px it peaked at **178px and 2 cards** -- the height cap
trimming below the count cap, with no overflow either time.

**The three urgent kinds FLASH THE SCREEN EDGES.** Someone robbing you, a dog
on you, the patrol on you. A toast in a corner is the wrong instrument for
those: the player is running and looking at the world, not at the HUD. Four
bands fading inward, so the middle of the screen stays clear.

**ALL FOUR BANDS WERE INSIDE OUT, which is the whole of why this read as a
square laid over the screen rather than as a glow round the edge of it.** The
keypoints ran (0, transparency 1) to (1, transparency 0) -- invisible at
gradient offset 0, opaque at offset 1 -- while every `rot` in the table points
offset 0 AT THE SCREEN EDGE. So each band was invisible where it touched the
frame and solid along its INNER lip, and the four together drew a bright
rectangle outline floating 120 pixels inside the screen. Measured on the live
HUD before the fix: top band rotation 90 with keys `0 1 0 / 1 0 0`, and the
same 180-degree error on every one of the four. Measured after: opacity 1.000
at the screen edge falling to 0.000 at the inner lip, on all four.

Fixed by flipping the SEQUENCE and not the rotations, so `rot` keeps meaning
the one readable thing -- from the screen edge inward.

**THE RAMP IS A CURVE, NOT A LINE, AND THAT IS WHAT KILLS THE SEAMS.** A
straight ramp reaches zero with its slope still on, which the eye reads as a
crease -- a Mach band -- exactly where the band stops, in a straight line right
across the screen. It shows up twice over: once at each band's inner lip, and
again down the line where a side band stops overlapping a top one, because the
sum of two linear ramps has a kink there. The ramp is now alpha = (1 - t)^2 in
eight keypoints, whose slope is ZERO at the inner end: measured at 0.143 over
the last segment against the old 1.0. Both creases go, the bands melt out
instead of stopping, and the corners -- where two of them multiply -- come out
as a rounded falloff rather than a denser square.

**DEPTH IS A FRACTION OF THE SCREEN, never a pixel count.** 120 was 18% of
this window's height and 8% of its width, which is part of why the sides read
as stripes while the top read as a band. At 0.26 of height and 0.17 of width
it is the same vignette on every device. Verified covering the screen exactly:
y -58..607 and x 0..1513 on a 1513x665 viewport, with nothing left uncovered
at the bottom edge.

The pulse itself was not touched and still measures right: two clean pulses to
0.65 opacity and back, 0.78s in total, all four bands lit, in the kind's own
tone -- amber (240,148,56) for a chase, red for an alarm. Still nowhere near
the three-flashes-a-second ceiling.

**The chased player hears the bark FLAT, at the front.** The bark on the dog
is a 3D sound that falls off with distance, which is right for the street and
useless for the one player it is about -- they are running AWAY from it, so
the person who most needs to hear it is the one it fades for. The `chase` kind
plays the same snarl 2D for them alone.

**Toasts moved to the TOP LEFT, because the top-centre column was already
colliding.** The old toast sat at y=88, straight through the rebirth button at
96..148. The left edge is empty from the topbar down to the garage slot --
room for four cards and no neighbours to fight.

**There is no safe supply of UI cue sounds on the Creator Store.** Searching it
for a notification chime returns Undertale, COD Zombies, Fallout 3, SCP and Mr
Hopp's Playhouse on the first page, and Pro Sound Effects -- the licensed
library this project uses -- is a FIELD RECORDING collection with no interface
beeps in it at all. So the noisy kinds borrow sounds the game already ships and
the quiet ones stay silent: `police` and `warn` have no sound on purpose, and a
missing sound is tolerated rather than an error. Do not fill those slots from a
keyword search.

**The player-facing word is PIGGY BANK; `vault` is the field name and stays
put.** The thing on the lawn is a piggy bank and the game is named after it, so
"Vault" in the HUD was internal vocabulary that had leaked out. `data.vault` is
still `data.vault` -- renaming a persisted field to fix a label would be a
schema migration to solve a wording problem.

The Vault LOCK keeps its name, and that is not an oversight. It is a different
object: a lock you buy, built as a bank-vault dial, whose readability from the
street rests entirely on looking like one. The admin console keeps "vault" too,
since it names the field it is setting and its reader is a developer.

**"Piggy Bank" is five characters longer than "Vault", which broke the panel
and revealed it had been broken already.** The title label was 296 wide,
left-aligned, with the numbers inside it, so at large balances it ran straight
under the rate readout -- "Vault 146.1K / 3.0M+3.0K/s", no gap. `TextScaled`
does not save you there: it shrinks text only once it exceeds its own BOX, and
the box was already overlapping its neighbour. The fix was to stop treating one
row as two: the title is bounded to 178 and the numbers moved ONTO the bar,
which was 296 studs wide and carrying nothing, and which is a picture of
exactly those numbers. Measured at a 51px gap.

**Two controls that share a key and can never both be live share a SLOT.** The
dodge button and the ride's trick button are the same key (Q), do the same job
at the same moment, and are mutually exclusive by construction -- the dodge is
refused outright while a ride multiplier is set, and the trick button only
exists while one is. Drawn in two different corners they read as two buttons
where there is only ever one. They now sit at the same LayoutOrder in the
bottom-right list at the same size: a UIListLayout skips invisible children, so
whichever is live lands on the identical pixels and the other takes up no room.
Nothing positions anything.

Size a shared slot for the longest label EITHER occupant can show, not the one
you happen to be looking at: "DODGE  Q" is 76 pixels and "WHEELIE  Q" is 91,
so a button fitted to the dodge would appear to change size when you got on a
bike. It fitted inside the original 92 by a single pixel -- the exact margin
that reports `TextFits` true and still touches the frame edge elsewhere.

**The top-centre HUD column is FULL, and it is measured in offsets, not in
what a screenshot looks like.** The stack is coin counter 16..78, toast 88,
rebirth 96..148, carry banner 140..192, patrol banner 200..238. The patrol
banner went in at 86 and landed straight on the rebirth button -- the same
collision documented below, second time. The carry banner is the one that
settles where anything new goes: it is on screen exactly when a chase is
happening, so a chase overlay has to stack under it rather than share the row.
Note `AbsolutePosition` reads 58 lower than the offset you wrote, because
`IgnoreGuiInset` is on -- so check geometry against the offsets, or add 58 back.

**A HUD overlay near the top of the screen will collide with the shop panel.**
The rebirth button is pinned at y=96 and the panel's header and first row sit
right under it, so it covered the roll button outright. Panel visibility is
watched with `GetPropertyChangedSignal` rather than poked from the three places
that toggle the panel -- two of which are defined above the handler and could
not have called it anyway.

**UNDER `ZIndexBehavior.Global`, A PANEL LIFTED ABOVE THE HUD DRAWS OVER ITS
OWN CHILDREN.** ZIndex is not inherited there -- it orders every GuiObject in
the ScreenGui against every other one -- so a page at ZIndex 30 with children
left at the default 1 renders as an empty rectangle with nothing in it. The
game's own HUD is `Sibling`, where a child always draws above its parent and
none of this applies, which is exactly what makes it dangerous: the panel works
in place and fails completely the first time it is parented anywhere else.
Caught on a probe ScreenGui that defaulted to Global. Anything that raises its
own ZIndex should walk its descendants and layer them by DEPTH rather than
trusting the host's setting.

**`IgnoreGuiInset` is on, so y=0 is UNDER the Roblox topbar, not below it.**
Measured at a 58px inset, which is why the vault panel sits at y=72 in the
top-right rather than the 52 that looked right — at 52 its top six pixels
were behind the topbar buttons. The top CENTRE gets away with it (the coin
counter has always sat at y=16 and half under the bar) because the middle of
the topbar is empty; the corners are where the buttons actually are.

**The default player list is off, because the vault panel has that corner.**
One `SetCoreGuiEnabled` call next to the ScreenGui. It is redundant here —
the square has a physical leaderboard and an eight-plot server tells you who
is on it by looking out of the window — but it is a deliberate call, not an
accident, and it is one line to put back.

**Luau allows 200 local registers per function, and `ClientMain` is ONE
chunk.** At 3,100 lines it now sits near that ceiling, so a new section
cannot declare its locals at the top level -- the daily rewards board added
about twenty and the file died with *Out of local registers when trying to
allocate dayLabel: exceeded limit 200*. Note what that costs: not the new
section, the ENTIRE HUD, because the chunk never finishes and nothing gets
built. Wrap a new section in a `local function buildX() ... end` and call
it -- a function body gets its own register file, so the chunk pays one
local instead of twenty.

**The MCP `execute_luau` sandbox caches modules per ModuleScript INSTANCE, and
that cache defeats nested requires too.** Requiring a module after editing it on
disk returns the copy the sandbox loaded earlier. Cloning the ModuleScript and
requiring the clone gets a fresh compile of THAT file -- but any `require` inside
it still resolves to the original instance, and therefore still gets the stale
version. Editing Config and then previewing through PigGear failed exactly that
way. When a preview needs current code, run it in a Play session, where the
scripts were loaded fresh.

**Never fail silently.** A rejection the player cannot see is indistinguishable
from a broken feature, and that is exactly how the bug above survived.

---

## Not yet verified

**The patrol is verified except for the half that needs two players.** Measured
live on the server across three full cycles: the car enters, drives the street
and turns round with its wheels at exactly -0.440 (the tarmac surface) on every
sample; the lane change now completes in about two seconds at the turn; the car
parks level with the thief and the officer deploys; the officer closes from 32
studs to inside the 6.5 catch radius; its shoes track the ground from -0.440 on
the road up to 0.502 on the lawn, matching the player's own feet at 0.50; the
nameplate goes PURSUING then GOT YOU; the thief is stunned to WalkSpeed 0 for
four seconds; and the car drives off and cleans itself up. Bail was measured at
750, 1,500 and 3,000 against loot of 250, 500 and 1,000 -- exactly 3x each time
-- out of `vault`, with `coins` untouched at 51,389,188 throughout.

The arrest scene is verified too, driven by a real catch rather than by firing
its remote: it appears the instant the officer lands, the bail counts 0 to
6,000 against loot of 2,000, and it clears 4.52 seconds later -- `STUN_SECONDS`
plus the half-second fade, exactly as derived. Fourteen consecutive plays threw
nothing.

The run and the jog back to the car are verified too, in a real pursuit: the
officer deploys, chases with its arms and legs swinging, catches at 30.43s for
a bail of 4,500 against loot of 1,500, settles to a standing pose, jogs back
and the car leaves.

What has NOT run: the escape. `bust` puts an officer on a stationary test
character, so the thirty-second timeout and the "You lost the patrol!" branch
have only ever been reasoned about. Nor has
a real robbery ever raised the alarm -- `HeistService.onSteal` fires the hook,
but it needs a second player to fire it for real -- and the dodge-versus-officer
check has never actually refused a catch, since a stationary target never
dodges. Note `commands.bust` fakes ONLY the alarm; everything downstream of it
is the real path.


**THE REBIRTH PAGE IS VERIFIED EXCEPT FOR THE PRESS THAT OPENS IT.** Built
against a live mid-game save and read back row by row: the KEEP column names
the real house by tier, counts skins, effects, decorations, accessories, gear
and rides, and excludes the "none" effect that everybody owns; the LOSE column
lists the real coin and piggy-bank figures and the six trees at their actual
levels in the shop's own order; the UNLOCK strip computes the income step from
`Config.REBIRTH_MULTIPLIER` and names the Bronze skin off the pushed catalogue
rather than off Config, so it can never promise a skin the server would not
hand over. The button renders its icon, label and the star it would take you
to, and hides itself behind the shop panel and the daily board as it always
did.

What has NOT run is `button.Activated` -- the branch that opens the page on a
first rebirth and fires the remote on every one after it. Four lines, and the
same reason as the hot bar's drag: no pointer input can be synthesised here.
Note the page was driven through the module's real `open` and `fill` in a
second instance rather than a mock, so everything downstream of that press is
proven; it is the press itself that is not.

**THE PROMPT CARDS ARE VERIFIED ON SIX OF SEVEN KINDS.** Measured live by
reading the card back off the screen rather than by looking at it: `collect`
(BANK COINS, gold), `steal` (STEAL, red, 6s hold with the bar running 0.19 to
0.80 and the countdown down to 1.2s), `hide` (HIDE, slate, fill 0.25 to 0.76),
`dig` (OPEN IT, orange, fill 0.23 to 0.78), `shop` (SHOP, green, all four
doors) and `recover` (RECOVER, alien green) -- the last driven by starting a
real raid from the admin panel and knocking a drone down with a thrown
plunger, which exercised the held-item draw-then-use path end to end at the
same time. All 32 prompts in the world carry a kind and none is left on the
default style.

`tag` HAS NOT RUN. It only exists on a player who is actively carrying
somebody else's coins, which needs a second player and a real robbery -- the
same wall the heist system as a whole is behind. Its table entry is
exercised by nothing; everything downstream of it is the same renderer the
other six proved.

****THE HELD ITEM IS VERIFIED EXCEPT FOR THE CLICK ITSELF.** Everything either
side of the gesture was measured live through the real remotes: all ten
consumables draw, build, scale to a 1.90-stud span and weld unanchored and
Massless; the character walks at 0.952 to 1.002 of its empty-handed baseline
holding each of them, so nothing is pinned or dragged; body clearance is 0.00
to 0.08 studs, which is the idle arm sway; the equip ring lights the right
tile; swapping straight from one item to another needs no put-away in between;
the third press of one key toggles cleanly; drawing something with no stock is
refused by name; a use for something not in hand is refused with "Hold the
Golden Bone out first."; spending the last one empties the hand in the same
frame; and both vetoes fire with their own wording, with the ride and the bin
each taking a drawn prop out of the hand on the way in.

What has NOT run is the pointer: mouse down in the world, and the touch tap
that has to be told apart from a camera swing. The MCP mouse tool does not
land where it is aimed and `VirtualInputManager` refuses the keyboard, so the
same wall the hot bar drag hit applies here -- and it now covers the number
row as well, since those keys are bound to the CoreGui Backpack at engine
level. The remotes each of those paths fires are all exercised above; it is
the input that reaches them that has never been synthesised, and the touch
12-pixel tap test in particular wants a human thumb on it.

****THE HOT BAR'S DRAG IS THE ONE HALF THAT AUTOMATION CANNOT REACH.** Verified
live: the arrangement applies and survives a full server restart (bone held
position 1 and a shelved gum stayed shelved across a stop and start); the
server sanitiser rebuilt a 401-entry order carrying 400 invented field names
down to one legal entry, stripped a number and an unknown key out of `hidden`,
refused a `coins` write outright and refused `hotbar` set to a string; shelving
hides the slot and raises the restore tile with the right count; one tap
restores; and the eleven slots are named `Slot_<key>` so a probe can address
them. The drop-target maths was checked against the live geometry on three
cases -- to the front, to the far end, into the middle -- and all three landed
where a player would expect, including the far-end case that the first version
got wrong.

What has NOT run is the GESTURE: pointer down, move, release. The MCP mouse
tool does not land where it is aimed (see the gotcha above) and
`VirtualInputManager` refuses with "lacking capability RobloxScript", so
nothing here can press and drag. `HotBar.suppress()` keeping a drag from also
throwing the item is unproven for the same reason -- it is the half that most
wants a human hand on it, because getting it wrong spends a bone every time
somebody rearranges one.

**The house light show is verified on three of the four tiers it touches.**
Measured live rather than eyeballed, because a part that was built but never
animated looks identical in a screenshot to one that is: the Neon Tower builds
39 animated parts, the Marble Palace 20, the Sky Castle 22 and the Midnight
Modern 7, and sampling each effect kind half a second apart gives a real delta
on every one -- colour deltas of 0.06 to 1.09 on the five colour effects, and
3.3 / 3.4 / 22.1 studs of travel on the tower's halo, the palace's crown and
the castle's orbiting shards. The shop cards animate from the same tag with no
second implementation: 88 tagged parts inside the house viewports, all six
effect kinds live. Photographed from the street at the tower, the palace and
the castle, and the two colour bugs it caught (the palace's white blowout, the
uplights buried in their own plinth) are fixed and re-shot.

The MIDNIGHT MODERN has been measured but never photographed -- Studio's
capture kept resolving a different camera than the one the client was holding,
and it is the quietest of the four (one pulsing strip, six chasing coping
segments). Worth a look next time somebody is in there. Nothing else about it
is unproven: it builds, it animates, and it is the same two effects the other
tiers use.

**The Patrol Radio is verified except for the half that needs a rap sheet.**
Measured live through the real remotes rather than a module handle -- the
sandbox's `require` hands back a fresh PoliceService whose `start()` never
ran, so anything read from one there is initial values dressed up as a
measurement. What ran: the item buys and appears in stock; using it pushes the
patrol straight from `quiet` to `warning` with the normal fifteen seconds of
siren; the caller gets a private confirmation and the street gets the
anonymous broadcast; the car builds, cruises and cleans itself up; `due`
counted 333s to 210s in step with the wall clock across the whole thing, so
the scheduled patrol was neither consumed nor delayed; the lockout stamped at
180 on the patrol ending and refused a second radio with the real wait named,
without spending it; and a use while the car was still out was refused the
same way. The shop tile renders its price row alone with no duration, the icon
builds, and the hot bar slot carries R.

What has NOT run is a called patrol actually ARRESTING anybody. A solo session
has no rap sheet, so the cruise ended with nobody to chase and the pursuit was
never entered from this path. Everything downstream of the alarm is the same
code the scheduled patrol already uses and is verified there, but the radio
has never been seen to produce a bust.

The radio's status lamp was moved to the front face after a capture showed the
knob standing in front of it. The new clearances are COMPUTED, not seen --
Studio returned to Play before the model could be re-rendered -- so it wants a
look next time Edit is free. The numbers: lamp y 1.09 to 1.39 against a top
slat ending at 1.05 and a body top at 1.40, z 0.27 to 0.57 against a knob
ending at 0.17 and a front face at 0.40.

**Two halves of the wheelie bins are unproven, and both need a second
player.** Verified solo: ten bins build on the verge facing the road, entry at
a 1.2s hold parks and anchors the hider invisibly at the hatch, climbing out
lands exactly 4.50 studs in the pushed direction on every axis, the one-per-
pursuit cooldown refuses both the same bin and a different one, the occupant
cannot trigger their own OPEN prompt, and dying inside releases the bin in
1.5s. What has NOT run: another player actually holding OPEN to tip somebody
out -- the guard that ignores a self-trigger is verified, the branch that
ejects a DIFFERENT player has only been reasoned about -- and hiding while
CARRYING, which is the rule reversal the whole rework turns on and needs a real
robbery to produce loot.

The heist system has never been tested end to end, because it needs two players:
the chase, lock-vs-lockpick timing, the guard dog catch, friend bonus, revenge
markers and the most-wanted hat are all unproven.

The vault dial's SPIN is in that bucket too. All four tiers are verified
live -- the plate grows 3.10 to 3.90, the spokes go 2 to 5, level 0 destroys
the wheel and hides the plate, and the layers sit at 0.40 / 0.75 / 0.85 studs
out so no two faces are coplanar. But `rattleLock` only fires on a steal
hold, so the dial has never actually been seen turning.

Accessories are verified: rolling (twelve rolls, twelve distinct items, zero
duplicates), the escalating price, auto-wearing into an empty slot, the
wear/remove toggle, the locked silhouettes, and survival across a restart at
schema 8 including which slot each item was in.

**The Golden Bone's CHASE-break is still unproven.** Its guard-duty break is
now verified end to end and measured on the server rather than guessed at
from a nameplate: against a guarded Titan the nap stamps at 18s (30 x 0.6),
the dog sleeps in its kennel with `ready=false` for the whole of it while
guard duty still has five and a half minutes to run, the plate reads
DISTRACTED, and it wakes back to ON GUARD when the nap expires. A cheap
bone still bounces off the treat, and an unguarded nap still works.

But a bone thrown at a dog that is *already chasing someone* needs a real
robbery in progress, so `breaksChase` has still only ever run as the "it
has already seen you" refusal, never as the interrupt.

Verified as of the last session: persistence survives a restart (including
schema reconcile), and rebirth's happy path — power wiped, house and skins kept,
rebirth-locked skins becoming wearable.

`Config.NEW_PLAYER_SHIELD` is **15 minutes**. Two players who join and immediately
try to rob each other will see nothing happen and conclude the feature is broken.

---

## Before launch

**EVERY NOTIFY KIND GETS ITS OWN ICON, which is the entire point of having
one.** They started as ASCII stand-ins typeset into a coloured circle -- "+",
"!", "x", "$" -- which reads as a typographic accident rather than an icon.
Worse, FOUR of the eight shared `"!"`: warn, alarm, chase and police all drew
the same chip, so on the three loudest events in the game the icon carried no
information and the player had to read the words to find out whether they were
being robbed, chased or pulled over. NINE kinds, nine glyphs, and a
duplicate check is one loop over `Config.NOTIFY`.

**`prank` IS THE NINTH, and it exists because none of the other eight could
say what it says.** It reports the only thing in the game that is done TO you
and costs you nothing -- somebody threw a plunger at you for the laugh. Every
existing treatment says the wrong thing about that: `warn` is the refusal
orange and reads as "you did something wrong", and `bad` is a real loss and
plays a cell door slamming. So: a zany face on magenta, silent, short, and
NO flash. The three flashing kinds are the ones a player has to react to, and
there is nothing to do about this one except throw one back -- which is also
why it is the one hit that NAMES the thrower, where the serious hit does not.
An unexplained wobble with nobody attached to it reads as lag.

**The chip is a DARK DISC WITH A TONE RING, not a disc of the tone.** That
inverted the moment the glyphs became real icons: an emoji carries its own
colours and ignores `TextColor3` entirely, so a red siren sat on a red disc
and a gold money bag on a gold one. The card loses nothing by it -- the stripe
down the left edge is what actually carries the colour, and it is the faster
read of the two anyway.

**The chase alert is AMBER, and that is a correction to a rule this file
already stated.** The note under `police` says two identical flashes would
stop meaning two different things; alarm and chase were the identical pair,
both on (226, 72, 64). They are opposite situations -- the alarm is a loss
happening at YOUR house while you are elsewhere, the chase is danger to you
while you are out robbing. Red for the one that costs you coins, amber for the
one that costs you the getaway.

**BANNERS AND CARDS ARE ONE FAMILY, and share a separator and an icon.** The
banners used to join their halves with a double hyphen -- `PURSUIT -- LOSE
THEM IN 12s` -- which renders as exactly that, two hyphens, and reads as a
typo. The separator is now the middot this game already uses on the plot sign
and the ride tiles, so the banners match rather than inventing a third
convention, and each banner carries the same icon `Config.NOTIFY` puts on the
matching card. A patrol should be the same picture whether it arrives as an
alert or as a countdown.

The same sweep went through every message a player can read: thirty-five
service strings had a `--` in them, which is prose punctuation that renders as
two hyphens in a 15px label. They are full stops now, or a colon where the
line is really a label and a value.

**WITH `TextScaled`, "IT FITS" IS GUARANTEED AND MEANS NOTHING.** The existing
note below about `TextBounds` against `AbsoluteSize` has a second half: when
the label is scaled, `TextFits` is true by construction and the failure mode is
SILENT SHRINKAGE instead. Adding an icon pushed the longest patrol line to 277
of 282 usable pixels, so it kept fitting by rendering smaller -- measured at 20
pixels tall against the 23 it gets now that the banner is 340 wide to match the
carry banner beside it. The number to watch is the rendered `TextBounds.Y`, not
whether it fits.

**THE SILENCE BETWEEN CUES IS THE FEATURE, and nothing loops.** A looping
track is the mistake however good the track is: a nine-year-old plays this for
an hour, and a forty-five second loop is the thing they mute the game to
escape. So a cue plays through ONCE, the street goes quiet for 55-110 seconds,
and then a different one starts. Six cues of 90-170 seconds against those gaps
puts the earliest possible repeat about twenty minutes out. That is also why
`Config.MUSIC.TRACKS` holds long production cues and not short loops -- the
length is doing the work, not the arrangement.

Cues are drawn from a SHUFFLED BAG rather than picked at random, so every one
is heard before any is heard twice, and the refill excludes whatever just
played so the seam between bags cannot repeat either. Same shape as the
accessory roll refusing to hand back something you own, and the same reason:
a guaranteed spread is what a player actually wants from something nominally
random.

**MUSIC IS THE ONE THING THE TOGGLE TURNS OFF, never the effects.** Muting
everything would hide the siren, and the patrol only works because it is heard
coming -- fifteen seconds of warning is what makes robbing during one a choice
rather than bad luck. The sharper version of the same argument is why the
score is quiet (0.18) and ducks to 0.22 of that for the patrol and the arrest:
a player who mutes the whole game to escape the music also mutes the siren,
the dog and the ride they paid for. Losing the score is fine. Losing the
soundscape with it is not.

**How fast the volume moves depends on WHY it is moving**, and the three
reasons want three different speeds: a cue fading in or out is musical and
takes two seconds, a duck is reacting to something already making noise and
takes 0.4, and a mute is a button somebody just pressed. At the musical rate
the score was still audible five seconds after the press -- measured -- which
reads as a broken button rather than as a graceful fade.

**`setEnabled` only ever pushes the next cue BACK, never pulls it forward.**
That one `math.max` is what lets the same call serve joining and a button
press: the join path has already scheduled `START_DELAY` (14 seconds of
nothing, because somebody who just loaded in is reading a HUD, not listening
to an overture) and keeps it, while a press made an hour later finds a
deadline in the past and gets the short resume instead. And a cue CUT OFF by a
mute schedules `RESUME_DELAY`, not a full gap -- a gap is what a cue that
finished has earned, and pressing play to get two minutes of nothing is the
same broken-button reading.

**THE MUSIC TOGGLE'S HOME IN THE SHOP HEADER IS A STOPGAP, and it is written
down as one in the source.** A shop is where you spend coins, not where you
configure the game, and that header already carries a tab name, a coin balance
and a close button. It is there because the alternatives today are worse: the
HUD corners are all taken (top-centre is a full five-band column, bottom-left
is three deep), and a ninth tab would spend an entire view on one switch. It
is positioned off the RIGHT edge like the coins beside it so the two move
together -- at the 1040 cap, toggle 680..716, coins 722..982, close 990..1030.
The shop HAS now been reworked -- eight tabs into four, plus a front page --
and this did NOT move with it, which is recorded here rather than quietly left
true-sounding. What the rework changed is that there is somewhere for it to go:
the front page is a real surface with room on it, and the rail has a slot free.
It is still a stopgap and still the wrong place.

**SETTINGS ARE THE ONE THING A CLIENT IS ALLOWED TO WRITE, so the allowlist is
the whole service.** `SettingRequest` is literally a client saying "put this
key and this value in my save", which without a check is an API for stuffing
arbitrary fields into persisted data -- bloating every save until they stop
fitting, and colliding with whatever field a later feature wants. So the key
is matched against a table in `SettingsService`, the value is type-checked,
and anything else is dropped. Verified: a request naming `coins` changed
nothing, and `music = "yes please"` was refused on type.

**A TYPE NAME CANNOT BOUND A TABLE, so the allowlist is SANITISERS now rather
than a key-to-typename map.** `type(value) == "table"` accepts a table of any
shape and any SIZE, which is precisely the "bloat every save in the game until
they stop fitting" attack this service exists to refuse -- and the first
setting with a shape (the hot bar's arrangement) would have walked straight
through it. Each key now maps to a function returning the value to STORE, or
nil to refuse, and the hot bar's rebuilds its answer from known-good parts:
an array of distinct keys that exist in one of the four throwable catalogues.
Measured, a 401-entry order carrying 400 invented field names was stored as
one entry. Derived from the catalogues rather than listed, so an item added to
any of them is arrangeable with nothing to remember here.

Nothing in `settings` may ever affect an outcome -- no speed, no income, no
odds. That is what makes it safe to let a client set at all, and it is the bar
any future setting has to clear. The hot bar clears it with room to spare: it
moves tiles, and a shelved slot is still held, still throwable by its own key,
and still bought and spent by the services that always owned it. A preference is also NOT worth a DataStore
write per press: the autosave loop and the write on leaving both carry it
already, and a player flicking a toggle would otherwise hammer a budgeted API.

**Audio licensing: prefer Pro Sound Effects.** The Creator Store is full of
free-to-take sound effects that are lifted from Minecraft or Undertale — "free"
there means costing no Robux, not cleared for use, and a copyright strike
moderates the asset away and leaves a silent game. The `ProSoundEffects`
creator is a library Roblox licensed wholesale and is safe; the dog audio all
comes from it.

`Config.SOUNDS.SIREN` is deliberately EMPTY. Every sound player here tolerates
an empty SoundId, so the patrol ships silent rather than shipping with a
placeholder nobody remembers to swap -- and a siren is exactly the sound the
Creator Store is worst for, since the free ones are ripped from television. A
strike moderates the asset away and leaves the patrol silent anyway, after
players have already learned to listen for it. Pro Sound Effects has sirens.

The three Creator Store audio IDs in `Config.SOUNDS` are third-party. One asks for
creator credit, and third-party audio can be moderated away without warning. Swap
them for your own uploads.

Roblox prohibits paid random-chance items for under-13 audiences. Everything
purchasable here is a direct purchase; keep it that way.

**The Style Pack's entry-ride grant is UNPROVEN.** Everything either side of it
is measured: with no pass id the warning fires and both stances are unlocked
and wearable; with an id the player does not own, the stance list arrives
locked, `setStance` refuses out loud with "Style Pack unlocks that one", the
pose does not apply, the pill flips to a locked STYLES advert and the shop card
reads its price. What has NOT run is `grantEntryRide` firing for real, because
that needs an actual purchase of an actual pass by somebody who owns no ride.
Both of its guards are verified negative — it does not fire while the id is 0,
and it does not fire for a player who already owns a ride — but the branch that
hands the skateboard over has only ever been reasoned about.
