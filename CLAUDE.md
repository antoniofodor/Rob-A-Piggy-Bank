# Rob a Piggy Bank

A Roblox shared-economy PvP game for an under-12 audience. Eight players to a
server, one plot each, on a street wide enough to carry shops and boards on its
verge. Players own a plot with a piggy bank that fills with coins over time; other players can steal from the
*uncollected* portion. Defence and offence are competing upgrade trees.

**Four documents, four jobs.** This file is WHY: the rules, the
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
* [`docs/MASTER-PLAN.md`](docs/MASTER-PLAN.md) is WHEN and WHAT-NEXT: the
  design as decided, the execution plan phase by phase, and the record
  carried out of every earlier working document -- what shipped, what is
  still open, what was rejected and why, and the measurements behind the
  constants. It replaced `ROADMAP.md`, `core-loop-plan.md`, `nab-plan.md`,
  `yard-plan.md`, `shop-vaults-plan.md`, `endless-plan.md` and
  `economy-design.md` on 2026-09-15, and where any of those is named below
  the pointer now means this file. It is also where a rejected idea stays
  rejected, so that the day somebody proposes a coin pack or a 2x-income
  pass again, the arithmetic that refused it is one file away.

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

**THE ROBBING PIVOT (September 2026): THE PIG IS THE WALLET, AND THE THIEF'S
REWARD IS NOT THE VICTIM'S LOSS.** The rule that stood here for the life of
the project read *"Only uncollected coins are stealable. Banked coins are
permanently safe."* It was right about what it protected and it was also the
single reason nobody robbed anybody. Measured against the live Config at level
20: a victim's pig completely full is 3.0M, a steal took 5% of it, 150K, which
is FIFTY SECONDS of the thief's own income -- against a 53-stud getaway at 12
with a Titan at 17 and bail at three times the haul. And that was the best
case: a rational victim banked constantly, so the typical stealable pile was a
few seconds of income. Every system added since the pitch made the RISK half
of a robbery bigger and nothing ever touched the REWARD half. The economy paid
a nine-year-old to sit on the pig, and that is a structural fact about the two
numbers below, not a tuning slip.

**ONE BALANCE, ALL OF IT IN THE PIG, ALL OF IT STEALABLE.** `data.vault` is
retired into `data.coins` (schema 17) and there is no bank action: income
drips in until the pig is full, spending draws from it, and a full pig stops
earning until you spend some -- which is the "spend it or lose it" loop that
drives every upgrade purchase for free. It is less dangerous than it sounds
because a plot is RELEASED when its owner leaves, so nobody is ever at risk
while offline. What replaces "banked is safe" as the survivability rule is
`Config.LOSS_CAP`: a victim can lose at most 45% of their pig in a
rolling hour, WHOEVER is robbing them, tracked per victim and never per
thief. Anything SPENT is still permanently safe, for the same reason it always
was -- it is no longer in the pig.

**IT WAS A QUARTER, AND IT WENT UP BECAUSE IT WAS SILENTLY GUTTING AN UPGRADE
RUNG.** A clean five-slice crack scales with Bigger Sack, running 21.9 / 26.8
/ 31.7 / 36.7 / 41.6 per cent of the pig across that tree's five levels -- so
against a 25% cap every rung above the FIRST was partly refunded to the
victim, and a maxed sack lost 40% of what it asked for. A child could buy four
levels of "Take more coins per grab" and three of them did nothing to a real
person, with nothing erroring and nothing in any log. Same family as the
Tiptoe rung that sat on disk describing an upgrade that did not exist: a thing
bought with coins that is quietly not paid.

45% clears the top of that ladder by 3.4 points, so **the ceiling is the
SACK'S RUNG COUNT rather than a number somebody typed** -- the derivation
`TIPTOE.max` and `Config.CASING` already use. A fifth sack level has to
re-solve this or it binds again.

**WHAT IT STILL BUYS IS EXACTLY WHAT IT WAS WRITTEN FOR, WHICH IS WHY IT WENT
UP RATHER THAN AWAY.** `STEAL_COOLDOWN` is per THIEF per victim, so seven
players can rob one child seven times inside a minute: measured, uncapped that
leaves them **2.3% of their pig** at a maxed sack and 17.7% at a bare one. And
it bounds the AUTOMATED path, which is the sharper of the two now that
residents rob players -- `residentTake` goes through the same `lossAllowance`,
so without it a row of neighbours strips a pig 20% at a time on a loop with
nobody deciding to do it. Since the pivot merged `vault` into `coins` there is
no safe pool behind this: **it is the only bound left on what a real person
can lose**, which is the argument against ever deleting it outright.

**AND IT COST THE ASYMMETRY THE ENTRY BELOW IS BUILT ON, STATED PLAINLY.**
Bigger Sack used to pay 41.6% on a resident and a capped 25% on a child, so
the incentive pointed at the empty house BY ARITHMETIC. At 45% both pay in
full, and `RESIDENTS.stealCooldown` is 60 -- the same as a player's -- so
neither the take nor the cadence separates them any more. What still points a
thief at a resident is RISK: no alarm, no police, no revenge marker, no
grudge, no notification. That is a real pull and a weaker one, and if robbing
children ever starts reading as the better play, this is the number that did
it.

**THE THIEF BANKS A MULTIPLE OF WHAT THE VICTIM LOST, AND THE EXTRA IS
MINTED.** `Config.HEIST_PAYOUT` is 2: stolen coins count double once they are
home. This is the actual lever, and it is worth being exact about why. While
the thief's gain and the victim's loss were the same number, every point of
incentive was a point of pain, so the reward could never be raised without
making the game a bullying simulator. Decoupled, robbing becomes the best
earning rate on the street while being robbed stays a few minutes of income.
Bail, the rap sheet and `totalStolen` are all still measured against what the
VICTIM lost, never the doubled figure, or a most-wanted arrest would charge
somebody for coins that were never in anybody's pig.

**AND THAT CLAIM WAS FALSE THE DAY IT WAS WRITTEN, BECAUSE `LOSS_CAP`
MULTIPLIES AGAINST IT.** "Robbing is the best earning rate on the street" was
never measured; measured, it is the WORST. `Config.LOSS_CAP` allows a victim
to lose a share of their pig per rolling hour across ALL thieves, so on an
eight-player server the entire hourly theft budget is `8 x fraction x pig` of
victim losses, doubled by the payout and split eight ways -- **half a pig
each, per hour, however well anybody plays.** (The figures below were measured
at a `fraction` of 0.25; it is 0.45 now, which scales the PvP half of this by
1.8 and changes none of the conclusion, because the fix was never this dial --
see RESIDENTS below.)

    level 0    2,500/hr robbing   vs   36,000/hr idling     (7%)
    level 20   2.1M/hr robbing    vs   14.5M/hr idling      (14%)

Neither rule is wrong alone. `HEIST_PAYOUT` was raised to make robbing
worthwhile; `LOSS_CAP` was added the same session to keep a robbery
survivable. Nobody multiplied them together, and the cap binds long before
the payout does. **The game was named after an activity that is
mathematically a rounding error, and standing on your own lawn was the
optimal way to play it.**

Neither dial fixes it either: parity at level 0 wants `HEIST_PAYOUT` around
29, or a cap around 360% an hour, and the second makes being robbed
devastating -- the one thing this design will not do.

**SO THE SUPPLY SIDE MOVED INSTEAD OF THE RATE. RESIDENTS ARE THE FIX.**
Every plot nobody lives on now has a neighbour on it with a pig that fills,
and a resident has **no loss cap at all** -- the cap exists so a real child
cannot be emptied by seven people taking turns, and there is nobody behind a
resident to protect. Measured against one at level 4: a full crack is 2,631
coins doubled to 5,262 for a thirteen-second round trip against an income of
33/s, which is **about twelve times the return of standing still** -- with
`HEIST_PAYOUT` and `BASE_INCOME` untouched.

That is the shape of the fix worth remembering: the binding constraint was a
PROTECTION, and protections must not be loosened to make a game pay. Add a
source the protection does not apply to.

**LOOT IS THE SECOND CURRENCY AND ROBBING IS ITS ONLY SOURCE.** Medals, tokens
and the daily token pips were three currencies doing one job badly, and a
nine-year-old cannot hold three. `data.medals` and `data.tokens` are merged
one-for-one into `data.loot`; `Config.LOOT.delivery` pays one per delivery,
events pay the old medal shape when they return, and the daily ladder pays
NO loot at all -- loot is the currency you go out and earn. It buys the
accessory roll and the set items. The old rule that a roll's currency must be
unreachable with money still holds: nothing here can be bought.

**REVENGE PAYS TRIPLE, AND THE WINDOW IS THE MARKER.** `Config.REVENGE` is one
table: robbing somebody who robbed you inside `window` pays `payout` times and
`loot` extra, and the marker over their plot lasts exactly that long, so the
picture and the rule cannot disagree. It is a WITHIN-SESSION mechanic and only
ever was one: the grudge is held in memory, keyed on the Player, and dropped
when they leave. Nothing about it reaches a later session, and nothing should
-- a plot is released when its owner logs off, so there is no such thing as
being robbed while you are away to come back and answer.

**THE SHIELD IS NINETY SECONDS, AND THE LONG ONE IS FOR THE FIRST SESSION
ONLY.** Fifteen minutes per join, on a game whose sessions run fifteen to
twenty-five minutes, meant that about half of any server could not be robbed
at any moment -- which read exactly like robbing being broken. `JOIN_SHIELD`
covers a rejoin; `NEW_PLAYER_SHIELD` applies when `data.sessions == 1` and
never again.

**AND THEN THE FIRST-SESSION SHIELD STOPPED BEING A TIMER AT ALL: IT ENDS
WHEN YOU COMMIT YOUR FIRST ROBBERY.** *Nobody can touch your piggy until you
take somebody else's* is one sentence carrying the rule, the theme and the
trade; the player chooses when it ends; and it self-clears with no new save
field. `HeistService.dropShield` fires on the GRAB rather than the delivery,
because the grab is the moment you decided to be a thief.

`NEW_PLAYER_SHIELD` is 120 seconds now and is only the CEILING for a player
who never robs anybody. The argument that took the rejoin shield down from
fifteen minutes applies harder to session one: at ten minutes against a
fifteen-to-twenty-five minute session, a new player spent essentially all of
their first session unable to be robbed. They learned this was an idle game,
because for them it was one -- and then met the actual game on session two as
though it were a betrayal of what they had been taught.

**AND THE FIFTEEN-SECOND STUDIO OVERRIDE IS GONE, REMOVED BY ITS OWN REASON
CEASING TO BE TRUE.** It existed because a solo playtest would otherwise
"spend its first minutes unable to rob anything" -- correct while the only
robbable thing on the street was another player. Residents have no shield, so
a playtest can rob from its first second regardless, and the override was
left doing one thing only: guaranteeing that the shield behaviour anybody
ever exercised in Studio was not the shield behaviour that ships. Same family
as every "works in Studio, refused live" entry in this file, pointed the
other way.

**AND THE FIRST RUNG THAT HANDS OVER A VERB RATHER THAN A NUMBER IS
CASING.** Every rung in all seven trees was a multiplier -- faster, more,
cheaper, slower for them -- so NOTHING BOUGHT AT REBIRTH FIVE LET A PLAYER DO
ANYTHING THEY COULD NOT DO AT MINUTE TEN. A maxed player performed the
identical robbery to a new one with bigger figures on it. The crack fixed *a
robbery has no gameplay* and the spree fixed *a session has no shape*;
neither touched *the verbs never change*, which is the deepest boredom source
this design has.

A maxed Lockpicks now reads any lock from the pavement: the rob badge grows a
four-pip ladder showing the victim's Vault Lock tier. That changes which pig
you WALK TO rather than how fast the crack resolves, and it is one more thing
to UNDERSTAND rather than one more thing to press -- the test this file set
itself when it decided what could be added at this stage.

**IT SELLS BACK EXACTLY WHAT MOVING THE VAULT DIAL COST.** The dial used to
carry its metal from the street, and the hatch entry above says in as many
words what that move gave up: *"a thief walks up from the STREET and sees the
face, so the metal tier no longer carries from out there."* Casing is that
reading restored, to the one player who has bought the right to have it --
which is a better home for it than the geometry was, because now it is
EARNED.

**A VERB IS ADDED AT A RUNG, NEVER SWAPPED FOR ONE, and that is the whole
answer to "does converting a rung break the save of anybody who already owns
it".** Nothing Lockpicks already does changed -- every level still widens the
crack window by `CRACK.pickWindowBonus` -- so a player who maxed it last week
simply gains this. No migration, no schema bump, nothing to reconcile. **ANY
FUTURE VERB GOES IN THE SAME WAY**, and the moment one REPLACES a number is
the moment this becomes a save problem.

**THE THRESHOLD IS DERIVED FROM THE RUNG COUNT, NOT PINNED.** `Config.CASING`
names the upgrade and `canCase` compares against that upgrade's own `max`, so
a Lockpicks tree that grows or shrinks moves the verb with it rather than
stranding it above the ceiling or handing it out early. Same argument as the
Sneakers rung count being solved out of `TIPTOE.max`.

**AND THE PLAN'S OTHER CANDIDATE FOR THIS RUNG DOES NOT WORK, WHICH IS WORTH
RECORDING BECAUSE IT SOUNDS LIKE IT SHOULD.** The proposal was *"Lockpicks
top rung: see the crack sequence one step ahead"*, written before the crack
shipped in its final shape. `Config.CRACK`'s own comment settles it: **THERE
IS DELIBERATELY NO CLOCK ON A STEP** -- a step runs until it is tapped, and
the pressure is meant to come from the dog crossing the lawn rather than from
reaction time. So the zone is already visible for as long as anybody likes
once it arms, and seeing its POSITION early buys nothing: the marker sweeps
the whole dial, so every position is equally hittable. A look-ahead would
have been a rung that reads as a capability and measurably does nothing.

**THE LADDER IS PIPS AND CARRIES NO NAMES, which avoided a second table.**
The tiers have colours in `PiggyBank` and names nowhere, so writing "Iron /
Bronze / Steel / Gold" into the badge would have been a second description of
one ladder living in a different file from the first -- the near-identical
copy this file records for the mini piggy, `Decor.buildOne` and `RideSound`.
Pips need no names, and they are the vocabulary this game already speaks in
three other places.

**IT IS DRAWN IN `STOP`, NOT GOLD, AND ONLY ON A PIG YOU COULD ACTUALLY
ROB.** Gold is already the figure directly above it and means money; a lock
is the one thing on that badge which is bad news for the reader. And a tier
over a plot that is shielded, on cooldown or empty answers a question nobody
asked -- the refusal is the answer there, and this file's rule is that a
reason to stay away always beats a number -- so it rides the same branch the
value does. Verified: a maxed lock on an emptied pig reads EMPTY with no
ladder and the badge shrinks back to its 40.

**THE LOCK LEVEL WENT THROUGH A CONFIG CONSTANT ON THE WAY OUT, AND THERE
WERE FOUR SITES RATHER THAN THE TWO IT LOOKED LIKE.** `"LockLevel"` was a raw
string in `PlotService` (the writer), in `HeistService.plotLockLevel`, and
TWICE in `ClientMain` -- the steal prompt's own label and the
`GetAttributeChangedSignal` that repaints it. Converting only the writer and
the new reader would have left it HALF converted, which is worse than not
starting: renaming the constant would then break three call sites that fail
SILENTLY, because a missing attribute reads nil and falls back to 0. All four
go through `Config.PLOT_LOCK_ATTRIBUTE` now.

Verified by driving it rather than by reading: the steal prompt's label
tracks the attribute through the constant -- "Unlocked Piggy" at 0 and "Vault
Lock Lv1/3/4" above it -- which also proves the changed-signal conversion,
since a wrong name there would sit permanently on the level-0 wording and
never error.

**GREP FOR THE STRING, NOT FOR THE READER YOU KNOW ABOUT.** The two extra
sites were found by grepping the raw literal after the change, not before,
which is a habit worth keeping: an attribute is an interface with no compiler
behind it.

Verified live end to end: `canCase` false at 0-3 and true at 4, the shop
card's blurb flipping to "You can read any lock from the pavement" at max and
back to "Crack piggies faster" below it, and the ladder filling 0/4, 1/4,
2/4, 3/4, 4/4 across five plots with the badge growing 40 to 52.

**A ROBBED PIG WEARS A PLASTER, NOT A LOST HOUSE.** Losing permanent progress
was proposed as the incentive and rejected: it is the one thing every big game
on the platform protects, and for this audience it is a crying-then-uninstall
event a parent sees. What was right about it -- a robbery should leave a
visible mark -- is `PiggyBank.setRobbed`: a plaster on the forehead for
`ROBBED_MARK_SECONDS`, published on the plot, costing the victim nothing.

**THE REBIRTH GATE IS ONE CAPACITY NOW, NOT TWO.** With the pig as the only
wallet, income alone can never carry a player past capacity, so "fill it twice
over" was unreachable without robbing. "Fill your piggy bank" is reachable by
idling and FASTER by robbing, which is the right way round for the one
decision this economy most needs players to make.

**WHAT THIS COSTS, STATED PLAINLY.** A balance bounded by capacity means the
tens-of-millions houses and the 4.5M rides are reached by rebirthing for
capacity and by robbing, never by idling. That is the intent. If the top of
the catalogue turns out merely SLOW, the levers are `HEIST_PAYOUT` and
`DROPOFF_RADIUS`, not the prices.

**AND WHEN THAT WAS FINALLY MEASURED IT WAS NOT SLOW, IT WAS A DEADLOCK.** The
paragraph above used to end by admitting the 8.9-week model had not been
re-run against a bounded wallet. Re-run, it does not describe a longer
journey; it describes a game that stops. Every cost curve in this file is
written as "cost outruns value, so each level takes longer than the last",
which is the right shape for a ladder and was right here for the life of the
project. With an unbounded bank a price above your rate is a WAIT. With the
pig as the wallet it is a WALL, because the money cannot be HELD at one time
however long anybody waits.

Measured: capacity cost grew 1.60 against a capacity growing 1.40, so the
price gained 14% on the pig every level and passed it at LEVEL 17 of 20 --
level 17 holds 1.09M and level 18 cost 1.11M. Twenty of the forty rungs were
unbuyable, the income tree followed at 31, the rebirth gate (2.99M, one full
pig at the CEILING) was unreachable by a player whose pig had stopped at
1.09M, and the Sky Castle at 100M was above the largest pig this game can
ever produce (96.9M at level 40). An idler could neither finish the game nor
leave it, and every one of those failures reads as a buy button that never
lights rather than as something expensive.

**SO A RUNG IS CLAMPED TO A SHARE OF THE PIG THAT HAS TO PAY FOR IT.**
`Config.UPGRADE_COST_CEILING` is 0.55 of capacity for income and 0.80 for
capacity, and the cost functions `math.min` against it. The clamp rather than
retuned growth constants IS the decision: constants could have been chosen to
push the crossing past level 40, that would have worked, and it would have
been a coincidence -- the next price edit or rebirth ceiling puts the wall
back with nothing to say so. A `math.min` against the pig cannot regress.

**TWO FRACTIONS, NOT ONE, and capacity gets the looser of them for a
structural reason rather than a taste one.** One shared ceiling would price
both trees identically at every clamped level and delete the "which rung is
cheaper right now" decision the base costs exist to create; the pair keeps the
ratio those base costs already have (400/600 = 0.688). Capacity's clamp is
separately the NO-DEADLOCK GUARANTEE: the pig can always buy its own next
size, so a player who has poured everything into income can always grow their
way out. The income clamp is measured against capacity AT THE INCOME LEVEL,
which is deliberately conservative -- it means the pig has to be roughly as
big as the income is high. That coupling is real, and it is intrinsic to a
bounded wallet rather than something the clamp introduced; all the clamp does
is stop it being fatal.

**WHAT IT COSTS: THE TOP OF THE LADDER GOT CHEAPER, AND THE BOTTOM DID NOT
MOVE AT ALL.** The clamp first bites at capacity level 16 and income level 20,
so every price a player meets in their first hours is the shipped curve
untouched -- verified, first rebirth still 2.3 hours of play, against the
2h11m this file already recorded. Above the bite the price is pinned to a
constant share of capacity, so it grows on the CAPACITY curve instead of the
cost curve and a late rung is 30-50% cheaper than the number nobody could pay.
Time per upgrade stops rising and becomes CONSTANT -- a fixed number of
pig-fills, about 13 minutes of idling each.

**AND THE WHOLE CLIMB IS NOW 17 DAYS AT 2h/DAY OF PURE IDLING, WHICH IS
FASTER THAN THIS FILE'S OLD TARGET AND IS RECORDED RATHER THAN FIXED.**
Simulated against the real Config functions with no robbing, no offline, no
dailies and no friends -- the floor -- rebirth 10 and level 40 land at 1.4
days of play, with rebirths falling every three to four hours. The old 8.9
weeks is not the comparison it looks like: it was modelled on an unbounded
bank AND on an upgrade tree that could not actually be completed, so it
described a journey nobody could take. If 17 days is too quick the lever is
`REBIRTH_MULTIPLIER` or the ceiling fractions, and it is now a lever that can
be pulled without reintroducing a wall.

**THE LADDER GREW A THIRD BAND TO REACH A BILLION, AND NOTHING BELOW LEVEL
40 MOVED TO MAKE ROOM FOR IT.** The catalogue was asked to run to a 1B house
against a largest pig of 96,904,045. The obvious lever -- steepen band B so
level 40 holds 1.25B -- was measured and refused: it balloons the fill time
at the ceiling to 43 minutes against 12.6, compresses the whole 1B climb into
today's seventeen days, and rewrites the capacity and income of every
existing level-21-40 save. So `Config.BAND_TOP_2` is 40 and band C runs 41-60
at `CAPACITY_GROWTH_C` 1.136 and `INCOME_GROWTH_C` 1.10, two levels per
rebirth to rebirth 20, and `banded()` gained a third clause rather than a
branch -- level 41 is exactly level 40 times one band-C multiplier. **Every
value for level <= 40 and rebirth <= 10 is byte-identical to the day
before**, which is asserted by `tests/luau/ladder.luau` against the numbers
dumped from the live file, and is the whole reason there is no value
migration.

**BOTH GROWTH NUMBERS ARE DERIVED.** 1.136 is `(1.25e9 / 96,904,045)^(1/20)`:
twenty rungs that land the top pig at 1,241,390,843, so a 1B house sits at
80% of it -- the same headroom the Sky Castle keeps at 83%. 1.10 is what
holds the fill time at every reachable ceiling inside 10-18 minutes against a
rebirth multiplier that keeps climbing; the 1.033-per-level gap between
capacity and income growth is what stops the top of the game accelerating.
The band-C cost growths are band B's, because the affordability clamp binds
on every rung from 40 to 60 (cost/pig reads 0.80 and 0.55 throughout,
asserted), so the curve only has to keep outrunning the pig.

**AND THE REBIRTH MULTIPLIER TAPERS PAST TEN, WHICH IS THE ONE PLACE THIS
COULD HAVE PRINTED A LIE.** Linear at 0.12 to rebirth 20 the top reaches
3.4x; `REBIRTH_MULTIPLIER_TAPER` holds 0.12 through rebirth 10 and 0.08
beyond, landing at 3.0x and a 17.6-minute fill at level 60 -- the designer's
choice, three days slower for a regular player. Rebirths 0-10 are untouched.
Three sites multiplied the constant by hand -- `getIncomeRate`, the rebirth
page's income tile and the rebirth toast -- and all three would have promised
+12% at rebirth 11 while the server paid +8%. They read
`Config.rebirthIncomeFactor` and `rebirthBonusPercent` now.

**AND THE HOUSES BECAME A SHELF KEYED BY ID, WHICH TOOK THE LADDER OUT OF
THE SAVE AS WELL AS OUT OF THE SHOP.** `houseLevel` and `houseShown` were
two 0-based indices into `HOUSE_TIERS`, so ownership was "every row below
the top one" and the catalogue's ORDER was load-bearing: inserting a house
mid-table would have handed every existing save a different building.
Schema 26 gives every row a stable `id`, stores `data.houses = { owned =
{ [id] = true }, shown = id }`, and reads the two old numbers exactly once
in `DataService.reconcile` against `Config.HOUSE_LEGACY_ORDER` -- the nine
ids in the order the ladder counted them, FROZEN -- before deleting them.
**Derive-only:** `owned` is the rungs the old level said were bought and
never one more; the matrix in `tests/luau/houses.luau` runs every level and
shown pair twice and asserts the exact set.

**`id` IS OWNERSHIP AND `style` IS THE BUILDER, AND THEY ARE TWO FIELDS SO A
HOUSE CAN BE RE-THEMED WITHOUT ANYBODY LOSING IT.** The tier brief in
`docs/HOUSE-TIER-BRIEF.md` re-draws the existing nine as fantasy houses one
at a time; a re-theme changes what a row builds and must not change what a
save owns.

**THE SEAM THE GREP MISSED WAS THE ONE THAT HAD ALREADY BEEN RENAMED.**
Every reader of `houseLevel`, `houseShown`, `getShownHouseLevel` and
`MAX_HOUSE_LEVEL` was found by grepping the literals -- and `applyToPlot`
went on calling `Config.getHouseTier(shown)` with a `shown` that the line
above had just turned from a number into a tier, throwing on the first
join. Nothing named in the grep list was on that line. **A CONVERSION IS
FINISHED WHEN THE SERVER BOOTS, NOT WHEN THE GREP IS EMPTY**, which is why
the 4b.1 entry above recording "not done: a Studio Play" was the wrong
place to stop.

**THE TWO AUDITS CARRIED PINNED SWEEP BOUNDS, 10 AND 12, AND BOTH WOULD HAVE
GONE QUIET AT EXACTLY THE GATES THIS ADDED.** `auditEconomy` swept rebirth
gates to 12 and `auditRobbery` to 10 -- right for a ceiling of 40, and the
day the ceiling moved they would have audited a fifth of the new ladder and
reported clean. `Config.rebirthsToMax()` derives the bound from the ceiling
and the levels per rebirth. Same family as the audit that hardcoded
`PLOT_COUNT - 1` residents and could not see the full-server collapse.

**WHAT IT COSTS, MEASURED (`tests/sim/late-game/`):** a regular player at an
hour a day owns the 1B house on day 57.7 against the Sky Castle on 21.7; an
active player at two hours on day 20.8; nothing anybody experiences before
day 20 moves. A house still costs one pig-fill once it fits -- 9.6 to 14.4
minutes of idle income at every price from 35K to 1B -- because the wallet is
bounded, so **the ladder is the pacing and the price never is.** Anything
that wants a house to feel earned has to lengthen the climb to where it
fits, not make the number larger.

**A PRICE ABOVE THE LARGEST POSSIBLE PIG IS NOT PACING, IT IS AN IMPOSSIBLE
PURCHASE, and `Config.auditEconomy` says so at startup.** The two trees hold
by construction; the CATALOGUES do not and should not -- a house price is a
design statement rather than a derived number -- so they get an audit instead.
It walks both ladders, all nine catalogues and every rebirth gate against
`getCapacity(ABSOLUTE_MAX_LEVEL)`, and `Main` warns per problem. It warns in
Studio as well as live, unlike the animation warning it sits beside: that one
is about an asset that only fails once published, this one is about a number,
and the moment to hear about a number is while you are typing it. The Sky
Castle came down from 100M to 80M on the strength of it -- 83% of the largest
pig in the game, still the last thing anybody finishes.

Note this is a DIFFERENT question from the `HEIST_PAYOUT` rule above, which is
about something being slow. Robbing overflows the cap and was the only route
past any of these walls -- and a route that needs a populated server is not a
route a solo player or a quiet hour has.

**AND WHETHER ROBBING IS WORTH DOING IS AUDITED AT STARTUP NOW, WHICH IS THE
ONE NUMBER IN THIS GAME NOTHING WAS CHECKING.** Every entry above is a
post-mortem on the same failure: `LOSS_CAP` times `HEIST_PAYOUT`, capacity
times income, a resident's pig times a capacity ladder -- two curves
multiplied without anybody checking the product, found months later by
somebody happening to measure. `Config.auditRobbery` is that measurement run
on every boot.

**IT CAUGHT A LIVE REGRESSION ON ITS FIRST RUN, which is the argument for it.**
`RESIDENTS.pigSeconds` was solved for a ratio of 4.92x against the flat 8%
take. The crack then replaced that take with a five-slice 21.9% one -- a good
change, made for its own good reasons -- and the ratio nobody re-derived is
**8.25x**. Nothing errored, nothing looked wrong, and the number the entire
economy is balanced on had moved by 68% with no line in any log.

**THE BAND IS THREE CHECKS AND THE SHARP ONE IS THE SPREAD.** A floor
(`min` 3.0) says even perfect robbing must beat standing still, which is
section 2's original finding stated as an invariant. A ceiling (`max` 10.0)
says a resident may not be a faucet, which is what `pigSeconds` was
introduced to stop. But the one that has a provably right answer is
`spread`: the ratio must be CONSTANT across every level and rebirth, because
a ratio that MOVES means no single set of prices is right for both ends of
the game. Measured live at **8.2495x to 8.2495x across all 341 level and
rebirth pairs -- a spread of 0.0000%**, which is `pigSeconds` cancelling the
income rate out of the quotient exactly as it was designed to.

Provoked rather than trusted: putting a resident's pig back on the capacity
curve -- the exact bug `pigSeconds` replaced -- fires all three at once and
reproduces the historical figure, **12.35x at level 20 against 2.71x at
rebirth 10, a spread of 355%**.

**IT MEASURES THE RESIDENT CYCLE AND DELIBERATELY NOT THE PLAYER ONE.**
Robbing a real child is capped by `LOSS_CAP` on purpose and always will be;
auditing that would warn forever about a DECISION rather than about a
mistake, which is the cry-wolf failure this file already records for the
clipping checks. Residents are the uncapped supply and therefore the primary
income by design, so they are what the invariant is about.

**AND THE ROUND TRIP IS DERIVED, WHICH IS WHAT KEEPS IT HONEST AS THINGS
MOVE.** `Config.robberyCycleSeconds` builds the 53-stud run out of
`PLOT_SPACING`, `STEAL_RANGE` and `DROPOFF_RADIUS`, walks it out at
`BASE_WALK_SPEED` and home under `CARRY_SPEED_MULTIPLIER`, and adds the
crack's own `openHold` and one `sweepSeconds` per slice -- 21.23 seconds. A
pinned number would have described the game as it was on the day somebody
typed it, which is precisely how the 4.92x came to be wrong.

**IT IS AN UPPER BOUND ON OPTIMAL PLAY, NOT AN EXPECTED RATE, and that
asymmetry is what makes the two ends mean different things.** No dog, no
missed slice, no tag, no patrol, and never a walk past one resident to reach
a richer one. So falling under the floor means even PERFECT robbing loses to
standing still, which is damning; going over the ceiling means only that the
best case is too good.

**A FOURTH CHECK IS THE ONE NOBODY WOULD HAVE THOUGHT TO WRITE: A THIEF MAY
NOT LAP THE STREET FASTER THAN `STEAL_COOLDOWN`.** The cooldown is per
victim, so a thief working seven residents in turn is held up by whichever of
the lap and the cooldown is slower, and every figure above holds only while
it is the lap. It is 148.6s against 60s today, so it does not bind -- and it
tightens whenever the street gets SHORTER or the crack gets QUICKER, which is
exactly the kind of thing a sensible local retune breaks silently.

**WHAT IS NOT AUDITED, STATED PLAINLY: HOW LONG THE CATALOGUE TAKES.** At
8.25x the dearest house in the game, the 80M Sky Castle meant to be the last
thing anybody finishes, is **0.90 hours of optimal robbing** at level 20
against 7.42 hours of idling. That is the same complaint the `pigSeconds`
entry raises about the old 12.3x (*"ONE HOUR of this at level 20"*), arriving
again at a lower ratio, and it is a real question rather than a bug -- the
lever is `pigSeconds`, and moving it is a pacing decision rather than a
correctness one. The audit deliberately does not encode a hours-to-finish
threshold, because that number is a design statement in the way a house price
is, and this file already argues those get measured rather than clamped.

**AND THE SUPPLY WAS A FUNCTION OF HOW BUSY THE SERVER WAS, WHICH IS THE
WORST BUG THIS ECONOMY HAS HAD AND THE HARDEST TO SEE.** `ResidentService`
evicts on claim and seats on release, so the number of robbable NPC houses is
exactly `PLOT_COUNT - players online`. `MaxPlayers` was equal to
`PLOT_COUNT` -- deliberately, under the rule below -- so **A FULL SERVER HAD
NO RESIDENTS AT ALL**, and every figure the robbery audit prints is measured
against residents.

Measured at level 20, before this changed:

    players  residents  robbing vs idling
       1-5       7-3        4.12x    the audited figure
        6         2         2.92x
        7         1         1.46x
        8         0         0.14x    capped PvP only

So the game broke `ROBBERY_ADVANTAGE.min` of 3.0 at seven and eight players
and fell all the way back to section 2's original finding -- standing on your
own lawn is the optimal way to play a game about robbing -- **exactly as a
server filled up, which is to say exactly when the game was doing well.**

**THE AUDIT COULD NOT SEE IT, AND THAT IS THE LESSON RATHER THAN THE NUMBER.**
`auditRobbery` swept 341 level and rebirth pairs and hardcoded
`PLOT_COUNT - 1` residents -- one point on the axis that actually broke. An
audit is only worth the question it asks, which this file already records
about `auditFences` being clean through the entire period every tier was
jumpable. Same shape as every other post-mortem here: two curves multiplied
without anybody checking the product, resident supply times server population,
one level up from `LOSS_CAP` x `HEIST_PAYOUT`.

**AND THE FIRST FIX WAS THE WRONG LEVER, WHICH IS WORTH KEEPING BECAUSE THE
DIAGNOSIS ABOVE IS RIGHT AND ONLY THE ANSWER WAS WRONG.** For one session
`MaxPlayers` was 6 against 8 plots, on the reasoning that the gap between the
two IS the supply floor. That works, it is measurable, and it pays for a
robbable street by REMOVING PLAYERS -- which is the one thing this design
least wants to spend. The eight-plot map exists so that eight children share a
street; this file's own entry on cutting the map to eight records the lobby
argument for it in as many words, and then the next entry traded it away for
something that was available far more cheaply.

**AND PvP CANNOT BE THE ANSWER AT ANY CAP, WHICH IS THE MEASUREMENT THAT
SETTLES WHICH DIRECTION TO GO.** `LOSS_CAP` lets a victim lose a quarter of
their pig an hour across ALL thieves, so the whole server's theft budget is
fixed however many people are standing on it -- adding a player adds a victim
AND a competitor in the same breath. Measured at level 20 with every victim
permanently full, which is the best case that can exist:

    players   one thief's share vs idling   a SOLE thief on the server
       2                0.07x                        0.14x
       4                0.10x                        0.42x
       6                0.12x                        0.69x
       8                0.12x                        0.97x

Read the last cell carefully. A player who is the ONLY thief on a full server,
robbing seven permanently-full neighbours perfectly, still earns LESS THAN
STANDING STILL. So the supply has to be non-player at every population, and no
cap fixes it. That is arithmetic rather than a preference.

**SO THE SUPPLY MOVED OFF THE PLOT GRID ENTIRELY: `Config.SHOP_BANKS`.** The
four shops already standing on the verge each carry a TILL -- a piggy bank on
its own paving apron, robbed exactly as a house is. Both numbers went back to
what they were: the cap stopped being the lever and `RESIDENTS.stealCooldown`
is 60 again, because measured, THREE permanent non-player targets saturate a
thief at the original 60-second cooldown and there are four.

**AND FOUR TILLS WERE THE LAP, NOT THE SUPPLY, WHICH IS THE HALF THIS ENTRY
GOT WRONG.** *Three targets saturate a thief* is a statement about how fast
the same pig may be robbed twice, and it says nothing about how much is in
them. On a full server those four were the ENTIRE non-player supply of this
economy, so eight thieves shared four pigs and drained them -- recorded in
`docs/MASTER-PLAN.md` Part III D4 as the first number to look at in a real
playtest. `PLOTS_PER_ROW` went to 5 against a `MAX_PLAYERS` of 8, which puts
two permanent resident houses behind the tills at every population. See the
five-a-side entry below.

**IT WAS STILL A PIGGY BANK, AND IT IS NOT ANY MORE. THE NOUN WAS SPENT, ON
PURPOSE, ONCE.** This entry used to read: *"the plan rejected a shop target
once, on the grounds that a game called Rob a Piggy should not grow a second
kind of thing to rob. That objection is about the NOUN and it survives
intact: what stands on the forecourt is the same twelve-stud pig with the
same vault hatch, the same crack, the same coin pile and the same rob badge.
A shopkeeper keeps their takings in a piggy bank. Nothing new was invented to
rob."*

Every sentence of that was true and the picture it bought was wrong. A shop
with its own piggy bank parked on a paving apron outside it reads as a GAME
OBJECT ON A PAVEMENT rather than as a place, and four of them read as it four
times. The tills were furniture with a target bolted to the front.

**SO THERE ARE TWO KINDS OF THING TO ROB NOW: A PIGGY BANK ON A LAWN AND A
VAULT IN A SHOP.** What is bought is that the four units stop being scenery
and become somewhere you go IN. What is spent is the one-noun rule, and it
may not be spent a third time without an argument at least this long -- the
next thing that wants to be robbable has to be one of those two or make the
case for a third.

**WHAT SURVIVES THE TRADE IS THE PLOT, WHICH IS WHY IT COST SO LITTLE.**
`plot.shop` is still the whole implementation and `PlotService.assign` still
skips anything carrying one. THIS CHANGE MOVED GEOMETRY, NOT A TARGET TYPE --
see the entry below on `PiggyBank.buildVault`, which is the sentence made
literal.

**A SHOP IS A PLOT NOBODY CAN MOVE INTO, AND THAT IS THE WHOLE
IMPLEMENTATION** -- still true after the pig on its forecourt became a vault
on its back wall, which is most of why that move was affordable. `Plot`
gained a `shop` field and `PlotService.assign` skips
anything carrying one -- so `ResidentService` seats a neighbour on it at boot
and is NEVER ASKED TO EVICT, which is exactly the property the floor is made
of. Everything a robbery touches is keyed off a plot: the steal prompt, the
rob badge, the published pile, the lock attribute, the per-victim cooldown id,
casing, the crack, the coin drain, the drop-off and the rap sheet. All of it
came for nothing.

The alternative was a third kind in `HeistService`'s `Target`, which is nine
accessors with a plot-shaped hole under every one of them. **WHEN A NEW THING
HAS TO BEHAVE LIKE AN EXISTING THING IN TWENTY PLACES, MAKE IT ONE.**

**AND THE TROPHIES MADE THAT CALL A SECOND TIME, FOR A THIRD OF THE
PRICE.** `Config.TROPHIES` is four LAWN ORNAMENTS carrying a `trophy` key
and no `cost`, so ownership, the auto-slot, the put-away toggle, the
rebuild on a plot, the shop card, the rarity border and the reconcile
prune are `data.decor` doing exactly what it already did. Earning one is
`decor.owned[key] = true`. The alternative was a parallel
`data.trophies.placed` with a slot grid of its own -- nine accessors with a
decor-shaped hole under every one.

**IT ALSO BOUGHT THE SCARCITY RULE FOR NOTHING.** `docs/MASTER-PLAN.md` asks
for exactly nine trophy slots and says why -- *choosing what to display is
what makes the shelf mean anything, and that argument does not survive
adding slots to fit more things*. There ARE nine lawn slots, so a trophy
and an ornament compete by construction rather than by a rule anybody has
to keep. A grid of its own would have deleted that on the first commit.

**AND `Config.isEarnedElsewhere` TOOK ITS THIRD SOURCE IN ONE LINE, WHICH
IS THAT FUNCTION BEING PAID FOR.** Its own header says the next source
should be one line here rather than ten sites; `spec.trophy ~= nil` is it.
Both halves of what it answers apply unchanged: a Victim Shelf falling out
of a crate would hand over a record of robberies nobody committed, and
`(nil or 0) <= 0` would have made all four free -- the hole that once
unlocked the Tractor Beam for a whole server.

**WHAT DID NOT COME FREE IS THE SHAPE THE ORNAMENTS NEVER NEEDED: STATE.**
Eighteen ornaments are a function of nothing and four are a function of
what their owner has done, so `Decor.build` grew one optional argument and
`PlotService` holds it on the PLOT rather than passing it -- `setDecor` has
five callers across four services, and a fifth positional argument would be
five chances to leave it out, with a missing one reading as nil: an EMPTY
case, silently, on a lawn nobody would think to check. That is `signWord`'s
decision made a second time and for the same reason.

**WHAT A SHOP LEAVES OUT IS AS MUCH THE POINT AS WHAT IT KEEPS.** No fence, no
dog, no house, no garden: `applyLevel` has a `plot.shop` branch that ladders
only the Vault Lock. So a shop is the FAST, CHEAP, LOUD target -- nothing to
get past, a smaller pig, and an alarm that brings the patrol rather than a
defender -- and a house stays the slow, rich, quiet one. That is variety
INSIDE the loop, which is the one thing the plan's own section 8 admits
nothing else was solving.

The lock is kept because it is the one defence that is honest on a shop
counter, and because CASING reads it: a maxed Lockpicks reads any lock from
the pavement, and a row of shops all reading zero would make that rung worth
less than it is. It is the same dial on a vault door now rather than on a
pig's flank -- one ladder read twice, not two ladders.

**AND THE SHOPKEEPER IS WHAT `releaseDog` DOES ON A PLOT WITH NO DOG, WHICH
IS THE WHOLE INTEGRATION.** A shop has ONE defence where a house has four, and
`docs/MASTER-PLAN.md` records that a resident who watches a robbery and
does nothing is worse than one who is not there. The cheap shape is not a new
system: `releaseDog` already returns early when `GuardDog.isReady` is false,
and every shop's dog is tier 0, so a single branch above that early return
covers all three of its callers at once.

**THE THIRD CALLER EXCLUDES ITSELF, AND THAT IS LOAD-BEARING RATHER THAN
LUCKY.** `watchLawns` only reaches `releaseDog` behind `GuardDog.isWatching`,
which tests `level > 0` — so the FOOTSTEP path can never fire on a shop.
Walking into a shop must not start a chase, because walking in is how you
reach the vault, and that is guaranteed by the tier rather than by a check
anybody has to remember. What is left is the fumbled slice and the smash.

**WHICH IS ALSO WHAT KEEPS `auditRobbery` HONEST, and it is the half to
protect if any of these numbers move.** That audit is an UPPER BOUND on
optimal play — no dog, no missed slice, no tag, no patrol — so it is
STRUCTURALLY INCAPABLE OF SEEING A DEFENDER. A shopkeeper who reacted to a
clean crack would reprice the four targets carrying the supply floor at a full
server, with no audited number moving and nothing in any log: the exact shape
of every post-mortem in this file, arriving where the audit cannot look.
Reacting only to the loud paths means the audit is blind to this CORRECTLY.
**AN AUDIT THAT MODELS BEST-CASE PLAY CANNOT BE THE THING THAT CATCHES A
DEFENCE**, and anything added to the defence side has to be checked against
that gap by hand.

**A DOG'S CATCH RADIUS IS SIZED AGAINST A LAWN AND A SHOP ROOM IS TWELVE STUDS
ACROSS.** The first build took the Terrier's 7 on the reasoning that a
shopkeeper should be the gentlest catcher in the game. Measured live, the
shopkeeper stands **6.83 studs** from the only spot a thief can reach the
smash prompt from — inside it — so the catch fired on the first tick of the
chase, the figure never took a step (peak distance from the counter 0.00
across a seventeen-second sample), and robbing a shop became an unavoidable
instant arrest. It is 4.5 now. **A RADIUS THAT COVERS MOST OF THE ROOM MAKES
THE ROOM THE CATCH**, and a number carried across from an object that lives on
a 64-stud lawn is a number measured against different ground.

**AND IT NEEDED THE DOG'S OWN BEAT, WHICH GATES THE CATCH AND NOT ONLY THE
WALK.** `DOG_WATCH.wakeDelay` exists so that a crack is a DECISION — you hear
it stir and choose whether to finish or bail — rather than a coin flip you
find out the result of. A shopkeeper without one is strictly worse than a dog:
instant, unavoidable, and with no tell to read. Gating only the WALK is not
enough in a room this size, because somebody already inside the radius is
taken on the first tick without moving.

**`byDog` WAS DOING DOUBLE DUTY AS BEHAVIOUR AND AS WORDING, AND THE COMMENT
BESIDE IT SAID SO.** It reads: *"`byDog` is a genuine asymmetry, not a
convenient flag for reusing an ending"* — written when somebody nearly printed
dog wording on a player's nab. The shopkeeper reused the path anyway and told
the thief **"A guard dog got you!"** while standing in front of them in an
apron. In this game that is worse than a cosmetic slip: the dog's POSTURE is
the tell a thief reads from the pavement before committing, so a message
naming a dog that is not there is the tell lying. `nab` and `scare` take a
`catcher` string now; `byDog` keeps the behaviour it genuinely owns — the
self-nab guard, the range waiver, and the dog-only credit block.

**`goHome` IS A SETTLE, NOT A WALK, AND A SHOPKEEPER NEEDED ITS OWN STATE TO
GET BACK.** It sets `state = "home"` and clears the route, which is right for
a neighbour who has just arrived on their own lawn and leaves a shopkeeper
standing wherever they caught somebody — measured at 4.11 studs out on the
shop floor, permanently. It cannot be fixed by giving them a route in the
`home` state either, because that branch RETURNS before the route walker is
reached: the early-out is what makes a resident at home cost nothing, and its
own comment says so. `returnToCounter` walks in a state of its own and settles
on arrival, putting the facing back explicitly — the walker points a resident
along their direction of travel, so otherwise they arrive behind the counter
facing the wall they came from.

**A SEAT IS CAPTURED AT `seat` AND NEVER RECOMPUTED**, for the reason the
kennel's toys are held in kennel-local space: a position derived again later
is a position that can be derived differently, and the one thing a shopkeeper
must be able to do is stand exactly where they started.

---

**A SHOP DROP THAT PAID NOTHING WAS A ONE-IN-FIVE REWARD WITH A SILENT DEAD
OUTCOME, AND IT LANDED ON THE PLAYER WHO HAD ROBBED THE MOST.** `rollShopDrop`
builds its pool from items the thief does NOT own — correctly, because that
makes every drop progress and is the rule the accessory roll already keeps.
What nobody had looked at is what happens when the pool is empty: `total` came
out zero and the function returned in silence, on a completed crack, with
nothing on screen to say why. The collection being finished is exactly when a
reward should feel best.

**A DUPLICATE PAYS ITS SELL VALUE IN COINS, AND DELIBERATELY NOT A SPARE
COPY.** The chests do hand over spares and this does not, which is the
interesting half: a spare is fuel for `Config.COMBINE`, so a shop drop that
produced one would be a spare faucet OUTSIDE the chest system — a thief could
farm combines by robbing shops, which is the same arrow this file already
refuses to let run backwards when it stops coin chests reaching the alien set.
Coins settle it, because coins are the one thing that cannot be turned back
into a roll. The spare pool is weighted the same way the real one is, so what
a finished tab pays tracks what it would have given.

---

**THE TIER-0 DOG IS BUILT AND HIDDEN RATHER THAN SKIPPED.** `plot.dog` is read
in seven places across four services and a nil there is a crash rather than a
missing feature. A level-0 dog is already inert -- `isReady` and `isWatching`
both test `level > 0`, and `Config.getDogTier(0)` returns nil so the watcher
skips it -- but it is NOT invisible: tier 0 hides the dog's own fourteen parts
and leaves the KENNEL standing, which is correct on a lawn (an empty kennel is
what the upgrade is sold against) and is a dog kennel behind a shop counter
out here. Both models are hidden once at build. Safe to do once, because the
only thing that repaints a dog is `applyTier` behind `setDogLevel`, and a shop
never calls it.

**`SHOP_BANK_PIG_SECONDS` WAS PINNED AND WAS WRONG BY 62%, AND THE AUDIT
CAUGHT IT ON THE FIRST BOOT.** (It is `Config.shopVaultPigSeconds` now and the
figures below are the till's; the vault's are in the 4.3 entry.) It was set to 110 against a house's 200, on the
reasoning that the run home is about half a house's so the pig should be about
half. **A CYCLE IS NOT A RUN.** Measured: the run is 33.6 studs against 53,
but the CYCLE is 18.4s against 21.2s, because `CRACK.openHold` plus five
sweeps of the dial is most of a robbery and does not care how far anybody
walked. So a pig priced off the run made a till pay 5.80 coins per pig-second
against a house's 9.42 -- a target strictly worse than the one beside it,
which nobody would ever choose. It is `Config.shopBankPigSeconds()` now,
derived from the two cycles, so the same mistake cannot be made again.

**AND THE RISK PREMIUM A TILL DESERVES IS LARGER THAN THIS ECONOMY CAN AFFORD
TO GIVE IT, which is a real constraint rather than a rounding.** A till has no
dog and a carry home of 3.13 seconds against a house's 4.42, so a thief is
exposed for about 71% as long and it should pay about that share. It cannot:
at a full server the tills are the ENTIRE supply, so their rate IS the
economy's floor, and `ROBBERY_ADVANTAGE.min` of 3.0x bottoms out at a discount
of about 0.73. Measured across the band -- 1.00 gives 4.12x, 0.85 gives 3.51x,
0.75 gives 3.09x, 0.70 gives 2.89x and fails. `SHOP_BANK_DISCOUNT` is 0.85,
the midpoint of what risk asks for and what the model allows, landing with 17%
of headroom over the floor rather than sitting on it.

**THE SKEW CHECK IS DIRECTIONAL, BECAUSE THE DESIGN IS.** A till is MEANT to
pay less, so a symmetric "the two classes must match" check would fire on the
design working correctly -- the cry-wolf failure this file already records for
the clipping checks. `auditRobbery` refuses a till that pays MORE than a house
(which makes every house on the street pointless) and one that pays under 60%
(which makes the supply floor fictional, since nobody would walk to one).

**THE RESULT IS FLAT WHERE IT USED TO FALL OFF A CLIFF.** Measured at level 20
across every population, cold and with a maxed spree:

    players   houses + tills    cold     hot        was, before tills
       1          7 + 4        3.92x    7.84x           4.12x
       4          4 + 4        3.84x    7.68x           4.12x
       6          2 + 4        3.73x    7.46x           2.92x
       7          1 + 4        3.64x    7.29x           1.46x
       8          0 + 4        3.51x    7.01x           0.14x

**AND THE THING TO REMEMBER IS THE SHAPE OF THE FIX RATHER THAN THE NUMBERS.**
The binding constraint was a PROTECTION -- `LOSS_CAP` -- and protections must
not be loosened to make a game pay. This file already records that lesson once,
from the day residents were invented: *add a source the protection does not
apply to.* Tills are that same move made a second time, at the one population
where residents run out.

**AND `Players.MaxPlayers` STILL DOES NOT LIVE IN THIS REPO, so `Main` warns
when the place disagrees with Config.** It is read-only from a script, and the
live place is still configured for **60** -- the bug this file already records
under `MaxPlayers`, never actually fixed in the place file. It costs
turned-away players and nothing else now, which is the direction that failure
should point: the tills are what stop a misconfigured cap costing the economy
as well. Fix it in File -> Game Settings -> World -> Max Player Count.

**THE VERGE IS FULL, AND FINDING THAT OUT COST THREE PLACEMENTS.** RETIRED
WITH THE TILL -- the target is inside the building now and nothing of this
game's stands on the verge any more, so the trees that gave up their places
came back. It is kept because the SURVEY is the reusable half: this is what
the band between the kerb and the fences actually holds, and the next thing
that wants to stand out there meets the same list.

The obvious spot for a till is directly in front of its shop, and there is no
room there at all. Surveyed on the built street by sweeping every offset a twelve-stud
pig could take, and the answer is the same in every gap:

    dead centre          the lamp post, at |z| 9.8
    +-8 to +-14 across   each style's OWN frontage -- the boutique's scallop
                         awning and hanging sign, the garden centre's pots,
                         shrubs and trestles, the workshop's quarter pipe,
                         the strongroom's bars
    +-16 across          clear of all of it, and only the two street trees
    |z| under 14         the carriageway

So there is exactly one band, and something standing in it. `buildStreetTrees`
already vetoes its own trees near a driveway and near a shop, so the till
joined that veto and took one of the two trees' places -- which leaves a gap
with a tree on one side and a piggy bank on the other, and reads better than
the pair did.

**THE OFFSET IS SIGNED BY THE SIDE, AND A SINGLE WORLD OFFSET DOES NOT WORK.**
Retired with the till, and kept for the rule rather than the number: anything
placed relative to a SHOP is measured from the shop, because the two rows face
each other and a world offset is right on one of them and wrong on the other.
The four frontages are not alike: the workshop carries a quarter pipe out onto
its forecourt, and one world-x offset put the near row's till clear of it and
drove the far row's straight through it. Measured, the clear band is the same
one on every shop WHEN IT IS MEASURED FROM THE SHOP -- so it is
`gapX + side * SHOP_BANK_ACROSS`, and the tree veto had to learn which row it
was answering for (`clear(x, side)`, with the side loop moved outside).

**AN APRON SMALLER THAN THE PIG STANDING ON IT MADE THE TILL VERY NEARLY
UN-ROBBABLE, AND THE STEAL PROMPT WAS PERFECT THE WHOLE TIME.** The apron is
gone; this stays because the general rule underneath it is load-bearing and
was needed again the day the target moved indoors. The apron
shipped at 11 studs under a pig 11.9 across. Every property on that prompt was
byte-identical to a working house's -- enabled, range 11, the right kind, the
right hold, the take quoted correctly -- and it never fired.

**A PROMPT MEASURES TO THE PART'S CENTRE, SO HOW CLOSE A THIEF CAN GET IS
DECIDED BY WHERE THEY CAN STAND.** The pig's body centre sits at y 7.32. On a
lawn a thief stands on the plot slab at y 0.5 and walks right up: measured
against a resident house, **9.3 studs**, comfortably inside `STEAL_RANGE` of
11. With no room on the apron they were pushed onto the world ground a stud
lower AND further out, and measured **exactly 11.0** -- on the boundary. The
apron is 18 by 14 now, sized to be STOOD ON, and the same walk measures 8.5.

That is a general trap rather than a one-off: **anything whose reach is
measured from a CENTRE is really a question about the floor around it**, and a
prompt that is correct in every property and unreachable is indistinguishable
from a broken feature -- the failure this file refuses above all others.

**PROVOKED AND THEN DRIVEN END TO END.** A real robbery on a real till, driven
through the live prompt and the real remotes rather than a module handle: the
half-second hold opened a panel titled PIGGY OUTFITTERS' PIGGY reading SLICE
1 / 5, three taps ran the slices 1 to 3 with the till's published pile draining
5,643 to 5,417 as they landed, a miss ended it with *"2 of 5 slices. 316 coins,
worth 632 at home. Run!"*, the thief carried a `StolenPiggy` home, and the
delivery paid *"Delivered 316 stolen coins, worth 632 to you. +1 loot."* --
the doubled payout and the loot currency, on a target that did not exist an
hour earlier, with not one line of `HeistService` changed.

**AND A POSSESSIVE BUG CAME OUT WITH IT.** The crack panel built its title as
`"%s's piggy"`, so a name already ending in S read THE SNUFFLES'S PIGGY -- a
long-standing wart that nobody had noticed because it is merely clumsy on a
family name, and which the tills made loud at PIGGY OUTFITTERS'S PIGGY. Fixed
in the possessive rather than in the names, because the names were right.

**`yardContaining` HAD TO LEARN ABOUT TILLS, AND THAT WAS A FIX RATHER THAN A
TIDY-UP.** That rectangle is 64 by 122 studs, sized to a plot's fence -- so a
till on a 16-stud pad on the verge would have claimed a yard reaching across
the pavement and out into the carriageway, and the first plot in the list to
match wins. It is the ride gate's veto and the fence penalty's owner test, so
rides would have switched themselves off across a third of the street. Skipping
is also the honest answer: a yard is the ground inside a fence, a till has no
fence, and the verge it stands on is street -- which `Config.isOnStreet`
already says and this must not contradict.

**THE OTHER FOUR SWEEPS OVER `plots` WERE FINE, AND CHECKING THEM IS THE
HABIT.** Ladder placement is guarded by `fenceLevel > 0` and a till is 0;
`getOwnerOf` returns a nil owner; the two `HeistService` sweeps guard on a nil
dog tier. Widening a type finds every place that quietly assumed the narrow
one -- this file already records that for `Target = Player | Resident` -- so
the first thing to do after adding a kind of plot is to grep every iteration
over the list.

**THE VAULT IS THE PIGGY BANK'S OWN `Refs`, AND THAT IS THE WHOLE OF WHY A
SECOND KIND OF TARGET COST ALMOST NOTHING.** `plot.piggy` is read in fourteen
places across three services -- the fill, the dial, the rattle, the plaster,
the coin drop, the milestone, the alarm, the raid drone's anchor, the crack
panel's camera and the steal prompt -- and not one of them changed.
`Shared/VaultModel` builds a carcass, a mouth, a stack of `Config.COIN_COUNT`
bars and a door with a dial seat on it; `PiggyBank.buildVault` wraps those in
exactly the fields those fourteen readers want, and every behaviour above runs
UNMODIFIED on different parts.

The alternative was a second module with the same ten function names and a
`bankOf(plot)` dispatch at every call site, which is nine accessors with a
piggy-shaped hole under each one -- the exact trade the tills already refused
when they became plots rather than a third kind of `HeistService.Target`.
**WHEN A NEW THING HAS TO BEHAVE LIKE AN EXISTING THING IN FOURTEEN PLACES,
MAKE IT ONE.** Third time this file has recorded that call and the cheapest of
the three.

**WHAT IT COSTS IS ONE FLAG, `Refs.vault`, READ BY EXACTLY THREE FUNCTIONS.**
A skin, an accessory and an effect are the only three things a piggy does that
a strongroom cannot, and `applySkin` running on one would paint the carcass
pink and index a snout it has not got. Everything else -- and it is
everything -- is shape-agnostic already.

**THE LOCK LADDER IS SHARED RATHER THAN COPIED, WHICH IS WHAT KEEPS CASING
HONEST.** `setLockLevel` rebuilds a wheel around whatever `lock.PrimaryPart`
is, reading the metal and the spoke count out of one `LOCK_TIERS`, so a shop
vault and a piggy bank say their tier in the same vocabulary and a maxed
Lockpicks reading a lock from the pavement means the same thing at both. Two
ladders wearing one set of colours is the failure this file already records
for the rarity bands.

**AND THE DOOR STANDS OPEN, WHICH IS A READOUT DECISION RATHER THAN A
PICTURE ONE.** A shut vault is a better picture of a vault and a worse readout
of one: the bars ARE the coin pile, they drain visibly while a thief works --
measured, 32 down to 26 across one clean run as the published pile fell 823 to
729 -- and a closed door would have thrown that away. It is 95 degrees rather
than 55 because a leaf covers `cos(angle)` of the opening it is hinged beside,
and at 55 a door stands across most of the thing it is meant to be showing.

---

**THE ROOM IS THE RANGE, AND NEITHER A DISTANCE NOR A LINE OF SIGHT COULD DO
IT.** "Robbed by going inside" is the whole feature and it is not free:

* **A distance cannot express it.** A ProximityPrompt measures to the part's
  CENTRE, and a vault standing on a back wall 0.8 studs thick is TWO STUDS
  from the grass behind the building. There is no activation distance that
  admits a twelve-stud room and excludes the strip right behind its own rear
  wall -- measured at 5.4 studs from outside against 4.9 from the spot a thief
  actually stands.
* **`RequiresLineOfSight` is worse than useless here.** The check runs from
  the CAMERA, and a third-person camera sits about twelve studs behind a
  player who has just stepped inside -- so it would refuse the one player
  standing exactly where they are meant to be.

So `Config.shopRoomHolds` is a rectangle in the unit's own frame, checked when
an attempt opens and POLLED for as long as it runs -- the same shape as the
crack's own range binding, which already ends an attempt when somebody walks
away. Verified both ways through a real prompt hold: from behind the wall,
*"That vault is inside the shop. Go in."* and no crack; from inside, a clean
five-slice run.

**IT MATTERS BECAUSE THE OUTSIDE IS CHEAPER, NOT BECAUSE IT IS UNTIDY.** The
back of a shop faces the HOUSES, so a thief robbing one through the wall has a
shorter run home than the one the entire economy is priced against.

---

**A PROXIMITYPROMPT IS SHOWN AGAINST THE CAMERA AS WELL AS THE CHARACTER, AND
THAT IS WHAT MAKES A PROBE LIE ABOUT ONE.** This file already records that a
prompt is shown on ENTERING range, and that a harness which teleports onto one
is testing a prompt that was never shown. There is a second half.

Measured, three shops from identical relative positions: two of them showed
the prompt and one did not, at **the same 5.06 studs from the same part with
byte-identical properties on both**. The only thing that differed was where
the CAMERA was -- 17.6 studs from the vault on the two that worked and 2.4 on
the one that did not, because the probe had left the character facing the
wrong way and the camera had swung round in front of them.

**SO A NEGATIVE FROM A PROMPT IS ONLY EVIDENCE IF THE CAMERA WAS WHERE A
PLAYER'S WOULD BE.** Read `workspace.CurrentCamera` distance alongside the
character's before believing that a prompt is broken -- the cost of not doing
it here was an afternoon spent looking for a fault in code that was working.

**AND `ProximityPromptService`'S OWN EVENTS ARE THE TIEBREAK.** Connecting
`PromptButtonHoldBegan` and `PromptTriggered` at the SERVICE level on the
server says whether the engine raised anything at all, which separates "the
client never showed it" from "the server refused it" in one reading. That is
the probe that ended this.

---

**TWO PROMPTS ON THE SAME KEY DO NOT BOTH WORK, AND THE SHOP DOOR REACHED
NINE STUDS INTO ITS OWN SHOP.** Every prompt in this game was `E` and
`OnePerButton`, so only one was live at a time. (The SMASH prompt is the one
exception now and it proves the rule rather than breaking it: it had to be
given a key of its OWN, `G`, precisely because two prompts on one key do not
both work -- and it is the only prompt in the game deliberately live
alongside its neighbour. See the smash entry.) The door's SHOP prompt was 12
studs -- fine while the only reason to be near a door was to open the panel,
and a collision the moment the target moved to the back wall of the room
behind it. Measured at the spot a thief stands to crack the vault: the steal
prompt at 4.3 studs and the door's at 9.9, both live, one of them silently
winning.

It is 8 now, which still covers the whole forecourt out to the kerb and stops
just inside the room. **THE FIX IS THE SAME ONE THE COLLECT PROMPT ALREADY
TOOK** -- it was 16 studs on a twelve-stud pig and reached a third of the way
across the plot. **ANY NEW PROMPT GETS ITS RANGE MEASURED AGAINST WHAT ELSE IS
IN REACH, not against how far away it should feel.**

---

**THE CLIENT FINDS A PLOT'S MONEY BY NAME, AND THAT SHIPPED BROKEN FOR EXACTLY
ONE PLAY SESSION.** The server never had this problem: `plot.piggy` is one
field. The client has no plot record at all -- it is handed a Model out of
`workspace.Plots` and goes looking -- and it was looking for a child called
`PiggyBank` in THREE places: the steal prompt's binding, the rob badge and the
skin animator.

A shop's money is a `ShopVault`. So `bindPlot` waited ten seconds for a child
that was never coming and returned: **the steal prompt on all four shop vaults
stayed `Enabled = false` forever**, which is four robbable targets nobody could
press, with nothing anywhere to say so. Found by pressing one, not by reading
anything.

`Config.waitForPlotBank` is the one place that knows both names, and the part
inside is `Body` on both so no caller has to know a second one. The skin
animator is deliberately NOT a caller: it wants the pig specifically, because
a vault has no skin to cycle. Same lesson as `"LockLevel"` from the other end
-- **A NAME IS AN INTERFACE WITH NO COMPILER BEHIND IT**, and the way to find
the readers is to grep the literal.

---

**RE-DERIVING THE RUN HOME REVERSED THE PLAN THAT ASKED FOR IT, WHICH IS THE
ARGUMENT FOR DERIVING RATHER THAN ADJUSTING.** `docs/MASTER-PLAN.md`
says the run "grows by the shop's depth" when the target moves from the
forecourt to the back wall. It shrinks. A shop's back faces the HOUSES and a
drop-off is a thief's own plot behind the fence line, so going inside moves
the target 12.4 studs CLOSER to every drop-off on the street: measured, the
carry falls from 33.6 studs to 23.0 and the cycle from 18.97s to 16.85s.

Both halves of `shopVaultRunStuds` moved and they did not cancel. A till stood
16 studs off the gap centre, which leaned it toward one plot column and put it
24 studs from it; a vault sits on the unit's own centre line less `vaultX`,
which is 36.3. Net, 50.0 studs of straight line against the till's 60.6.

**A PINNED NUMBER WOULD HAVE SHIPPED THE PLAN'S OWN MISTAKE**, because the
plan was written by somebody reasoning about a building rather than measuring
one, and the audit would have passed either way.

**AND THE RISK PREMIUM THIS FILE SAID THE ECONOMY COULD NOT AFFORD IS
AFFORDABLE NOW, BOUGHT BY SOMETHING ELSE ENTIRELY.** The entry above records
that `SHOP_BANK_DISCOUNT` wanted to be about 0.71 on risk and could not go
below 0.73 because at a full server the tills were the whole supply. That
constraint was loosened by `PLOTS_PER_ROW` going 4 -> 5, which put TWO
permanent resident houses behind the four shops at every population -- so the
houses carry the floor and the shops are free to be worth less. Measured at
eight players, cold: 0.85 gives 3.74x, 0.70 gives 3.37x, 0.65 gives 3.24x and
0.60 gives 3.11x against a floor of 3.0. `Config.SHOP_VAULT_DISCOUNT` is 0.70,
landing at 3.37x with 12% of headroom, and the whole population sweep now runs
3.80x down to 3.37x cold and 7.60x down to 6.73x hot.

**IT IS LITERALLY THE COINS-PER-SECOND RATIO, WHICH IS WORTH KNOWING BEFORE
ANYBODY MOVES IT.** `shopVaultPigSeconds` is a house's scaled by the ratio of
the two cycles TIMES this, and a target's coins per second is
`pigSeconds / cycle` -- so the cycles cancel and a shop pays exactly this
fraction of what a house pays, at every level and every rebirth.

---

**A PLINTH IS A RING, NOT A RAFT, AND IT ONLY MATTERED THE DAY THE BUILDING
ACQUIRED AN INSIDE.** `ShopFront`'s base course was one solid slab across the
whole footprint, 0.3 to 1.6 -- invisible and correct for as long as nobody
stood in it. The interior floor's top is a plot slab above the pavement, so a
solid plinth stood **six tenths of a stud PROUD of the floor across the entire
room**, and the shopkeeper behind the counter was buried to the shin in it.

Nothing about the outside changed: the only faces of a plinth anybody ever
sees are its outer ones. What it cost is three extra parts and a rule -- the
four bars BUTT rather than cross at the corners, which is what keeps a frame
made of four pieces from being four coplanar pairs.

**THE SAME CLASS IS WORTH WATCHING FOR: A SOLID THAT IS FINE UNTIL SOMETHING
STANDS INSIDE IT.** Every building in this game is non-colliding scenery, so
its internal volume has never been anywhere. The moment one of them is a room,
every slab that fills it becomes furniture.

---

**AND A CROSS-MODEL COPLANAR AUDIT IS A DIFFERENT AUDIT.** The unit and the
plot inside it are two Models, and a per-model sweep cannot see a pair that
spans them -- which is exactly where the interior floor and the forecourt
live, both resting on the same ground. Swept together: **zero pairs across
175 parts**, with the only four in the plot belonging to the shopkeeper's own
drip-statue geometry, which every resident in the game has carried since it
was built.

**A ROTATED PART IS SKIPPED BY THAT AUDIT, AND THE OPEN VAULT DOOR IS
ROTATED.** So it found nothing when the door was standing 0.57 studs through
the display case's backboard -- a per-part sweep in the unit's own frame is
what found that, and it is the check to run for anything authored on an angle.

---

**THE BARS FILLED THE OPENING EDGE TO EDGE, AND ONLY A PICTURE SAID SO.**
Thirty-two bars in a 4 x 8 grid is the right count -- it is `Config.COIN_COUNT`
so `setFill` needs no branch -- and at 0.95 wide on a 1.10 pitch the gaps were
0.15 across and 0.04 down. Every number was correct and the render was A SOLID
WALL OF GOLD with a black band above it: the LEVEL still readable, the BARS
not. At 0.80 by 0.32 the dark shows between them and it is a stack of bars in
a hole, which is what the object is.

Same family as `Material.Metal` rendering gold as olive one section down:
nothing errors, nothing measures wrong, and the thing being built is not the
thing being seen.

---

**AND THE ELEVENTH FORWARD REFERENCE WAS A `Config` FIELD AGAIN, WHICH TOOK
THE WHOLE SERVER DOWN AGAIN.** `Config.SHOP_UNIT.floorY` is derived from
`Config.PLOT_SIZE.Y` because a shop's interior floor IS a plot slab, and the
table was written four hundred lines above `PLOT_SIZE`. `nil.Y`, during module
load, twice -- once from `Main` and once from `ClientMain` -- no plots, no
services, no HUD and no "Ready" in the log.

This is the second time on a table field and the fix is what the `LAWN_LIFT`
entry already prescribes: **derive it where its source exists.** The whole
table moved down beside `PLOT_SIZE` rather than the one field being lifted out
of it, because a field assigned outside a literal is a field Luau does not
infer into the table's type -- so a strict-mode reader gets an error on the one
value that is derived. A pointer comment stays where the table belongs.

**AND THERE IS A CHECKER FOR IT NOW.** A peer session wrote a scanner that
walks `Config` for top-level reads of a `Config.X` defined later, following
each statement across its own brackets and skipping function bodies by
construction -- a body cannot run during module load, which is why the many
legitimate `PLOT_SIZE` readers further down are correctly silent. It reports
clean on the file as it stands and it was proved to FIRE by reintroducing the
defect in a throwaway copy. Eleven instances is enough that this should be run
before pressing Play, not after.

---

**TWO SESSIONS EDITED ONE `Config` FIELD IN THE SAME MINUTE, AND THE COLLISION
WAS SILENT IN A NEW WAY.** This file already records that two documentation
agents rewriting `docs/GAME.md` is the one collision nothing in this toolchain
can catch, and says the SOURCE files are safer because each session writes a
targeted replacement rather than a whole-file rewrite. That is true and it is
not enough.

Both sessions hit the same load-time crash within a minute of each other and
both fixed it CORRECTLY, in incompatible ways: one lifted the assignment out
of the literal and put it beside `PLOT_SIZE`, the other moved the whole table
below `PLOT_SIZE`. Applied in sequence, the second move carried the first's
comment along and dropped its assignment -- so the file ended up with a
paragraph explaining where the assignment lived and no assignment anywhere,
and `ShopFront` read `nil` for the floor height. **TWO CORRECT FIXES TO ONE
BUG COMPOSE INTO A THIRD BUG**, and neither session's edit was a rewrite.

What actually resolved it was ASKING: two messages, one timeline, one owner
per file from then on. The rule is the one already written down and it applies
to source as well as to docs -- announce, wait for the answer, then act -- and
the addition is that a shared file needs an owner even when both writers are
right.

**A PLOT WITH NOBODY ON IT HAS A NEIGHBOUR ON IT, AND THAT IS THE SUPPLY
SIDE OF THE WHOLE LOOP.** `attemptSteal` required a `victim: Player` and
`release` strips an abandoned plot to a bare slab with an empty pig -- so on
a three-player server five of eight houses were dead frontages: a street that
reads as abandoned AND nothing to rob. Whether the core action of this game
was available at all depended on how many other children happened to be
online.

`ResidentService` seats one on every free plot: a name on the sign, a pig
seeded to `RESIDENTS.pigSeconds` of its own income, and defences from the
AVERAGE income level of the humans in the server -- the average rather than
the maximum, because pinning to the best player hands a beginner a target
they cannot fail to profit from and hands the best player a row of pigs
richer than any real person's. It uses `Config.getIncomeRate` and
`getCapacity` directly, so a resident is a PEER rather than a second economy
that can drift from the real one.

**AND NOT ONE OF THEM WAS ACTUALLY STANDING THERE, BECAUSE A PCALL DID ITS
JOB.** `ResidentModel.build` takes `(plotIndex, name, at, groundY, parent)`
and the call site passed four arguments -- so the CFrame slid into `name`, the
ground height into `at`, and every resident on the street threw *attempt to
index number with 'Position'*. Eight warnings a boot, and the whole
neighbourhood stood empty.

**THE GUARD IS WHY NOBODY NOTICED, AND THE GUARD IS STILL RIGHT.** The comment
beside it says a neighbour who fails to build must never be a plot that cannot
be robbed, because the figure carries no behaviour -- so the pcall caught it,
the economy went on working perfectly, and **the failure looked exactly like
the plot simply being vacant, which is what it looked like before residents
existed at all.** That is the shape to watch for: a feature whose broken state
is indistinguishable from its own before-picture, behind a guard that is
correct. A warning nobody reads is not a report, which this file already
records about `RegisterKeyframeSequence` taking every animation in the game
down while every reader dutifully pcalled and warned.

**IT ALSO COST THE TELL THE PLAN LEANS ON.** *A dog trotting after a player
means somebody is home* only reads if there is somebody there to trot after,
and the whole point of a resident is that the street stops looking abandoned.

**IT IS A RESOURCE, NEVER A RIVAL, AND EVERY DIFFERENCE FALLS OUT OF THAT.**
No loss cap, no grudge, no revenge marker, no notifications, no place on the
Richest Piggies or Most Wanted boards. What is deliberately IDENTICAL is
everything a thief can feel: the take, the hold, the carry penalty, the
getaway, the dog, the tag, the patrol and the rap sheet -- so robbing an
empty house still puts you on Most Wanted, which is what finally makes the
police loop work in a one-player server.

**AND IT UNBLOCKED THE TESTING WALL THIS FILE HAS BEEN WRITING ABOUT FOR
MONTHS.** Roughly ten entries under "Not yet verified" read *needs a second
player*. Most of them no longer do.

**AND EVERY RESIDENT WEARS A PIGGY SKIN, WHICH WAS A SUPPLY DECISION RATHER
THAN A COSMETIC ONE.** Every unclaimed pig was `Config.DEFAULT_SKIN` -- the
one `PlotService` builds with and the one `release` puts back. That was
invisible for as long as nothing read a victim's skin, and it stopped being
invisible the moment the Victim Shelf collected them: a trophy filled by
robbing would have had exactly ONE entry a solo player could ever reach,
which makes it a two-player feature on a game whose entire resident system
was built to stop those.

**A SHUFFLED BAG PER SERVER, NOT A HASH OF THE PLOT INDEX**, and the
difference is what the collection can reach. Indexing the catalogue by plot
pins one skin per house forever, so an account could only ever collect the
ten this street happens to carry -- a collection of forty-six with a hard
ceiling of ten, in every session, for the life of the save. A bag drawn per
server gives a different ten each time and guarantees no two neighbours
share one, which is the property the music cues take from the same pattern.

What it costs is that a house's pig changes colour between sessions while
its NAME does not. That is the honest reading anyway: `seat` runs whenever a
plot frees up, so a neighbour genuinely is a new occupant, and the one thing
a plot keeps across owners is its address.

**A SKIN CONFERS NOTHING, which is what makes it safe on scenery.** It is
colour and material on a body; the lock tier, the dog, the fence, the pile
and the rob badge are every single thing a thief prices a job on, and not
one of them lives there. It clears the yard rule (now in `docs/MASTER-PLAN.md`) -- a cosmetic
may never imply a tier that has not been bought -- because a skin cannot
reach `scale`, `shape` or any ladder. Earned-elsewhere skins are excluded
through the one predicate that answers that in ten places: a pass skin on a
neighbour's lawn would advertise a paid exclusive on scenery.

It also pays for itself on the street. A row of identical pink pigs was the
last place this neighbourhood read as a showroom rather than as houses with
people in them -- the same complaint that put every resident on its own rung
of the level ladder instead of all on the street's.

**THE STREET IS A LADDER NOW, NOT A ROW OF IDENTICAL HOUSES.** Every
resident was seated at exactly `currentLevel()`, so eight pigs of the same
size stood behind the same fence with the same dog and the same lock. That is
"every robbery is the same robbery" one level up from the verbs: not only did
a robbery PLAY the same, there was nothing to choose between the targets.
Each resident now carries a stable offset BELOW the street level, so the row
runs from a cheap easy house to a rich defended one -- and casing plus the
rob badge are what make both halves of that readable from the pavement.

**DOWNWARD ONLY, AND THE AUDIT IS WHAT DECIDED IT.** A resident's pig is
`pigSeconds` of its OWN income, and a thief robs the richest house they can
reach -- so a resident one level ABOVE the thief is worth `INCOME_GROWTH`
more. Measured against `auditRobbery`'s own ceiling before a line was
written: at parity a maxed spree returns 8.25x against a ceiling of 10, which
is x1.212 of headroom, and one level up is **x1.35 in band A**. A single
upward step reads 11.14x at every level below 20 and 15.03x at +2.
**RESIDENTS RICHER THAN THE THIEF ARE A FAUCET, FULL STOP** -- so the
peer-level house is the CEILING of the street rather than a rung in the
middle of it.

That is the same conclusion `currentLevel` reached when it chose the average
over the maximum, arriving from a completely different direction, and it is
the second time in two sessions the audit has refused a design at the
whiteboard rather than after it shipped.

**TWO GUARANTEES, AND BOTH WERE MEASURED INTO EXISTENCE.**
`RESIDENTS.easyCount` pins two houses to the bottom of the spread, so a
player with base stats always has somewhere to go rather than meeting a
randomly hard street -- "defence buys time, never immunity" broken by a dice
roll instead of by a purchase. And ONE house is pinned to the top, because
the first build drew the rest purely at random and **a third of streets had
no peer-level house at all**: the odds of never rolling zero across five
draws are `(spread/(spread+1))^5`. The best-paying, best-defended plot -- the
one the whole risk/reward decision is measured against, and the one the audit
describes -- was simply absent, with nothing on screen able to say so.
Verified over 3,000 simulated streets: zero under the easy floor, zero
without a top.

**THE FLOOR IS COUNTED AGAINST WHAT IS STANDING, NOT DEALT FROM A BAG.**
Residents are seated ONE AT A TIME as plots free up, so there is no moment at
which "how many are there" has an answer -- which rules out the shuffled-bag
pattern the music cues use. Counting the houses already out cannot drift out
of step with the street it is describing.

**THE SPREAD IS SIZED AGAINST THE LADDERS IT HAS TO MOVE.** Defences step
every 5 to 7 levels (`fencePerLevels` 5, `lockPerLevels` 6, `dogPerLevels`
7), so the first value -- 4 -- could not reliably move any of them: measured,
a street at level 20 seated every single house with the same dog tier and all
the variety was carried by the house and the garden. At 6 the bottom of the
street is a fence and a lock tier below the top, and the cheapest pig is 17%
of the dearest, which is a difference a thief can act on.

**AN OFFSET IS ROLLED ONCE AND KEPT.** Re-rolling on the tick would reshuffle
the whole street every time anybody levelled up, and a house that changes its
fence, its dog and its building for no reason a player can see is worse than
a street with no variety at all. Each resident tracks the street FROM ITS OWN
RUNG, so the row rises together and keeps its shape.

**AND THE GARDEN SCALES OFF THE LEVEL, NOT THE OFFSET, WHICH THE FIRST BUILD
GOT WRONG IN A WAY WORTH RECORDING.** Deriving the ornament count from the
raw offset made gardens vary while the street was still at level 0 and every
house was genuinely identical -- measured live at 0, 12, 14 and 57 ornaments
standing on four houses with the same bare fence, the same absent dog and the
same 1,481 coins. **A FULL GARDEN ON A LEVEL-0 PLOT ADVERTISES WEALTH THAT IS
NOT THERE, WHICH IS WORSE THAN NO VARIETY: IT IS VARIETY THAT LIES.** On the
same `perLevels` shape as the four ladders beside it, it lands at zero on a
new street with all of them -- the clean bare plot the thirty-second
storyboard is written against -- and fills in as the street climbs.

**A RESIDENT'S PIG IS MEASURED IN SECONDS OF ITS OWN INCOME, NEVER IN
CAPACITY, AND THAT WAS A CATEGORY ERROR RATHER THAN A TUNING MISS.** Capacity
means *how much you can hold before you have to spend* -- a storage limit
that exists because a full pig stops earning, which is what drives every
purchase a player makes. A RESIDENT NEVER SPENDS ANYTHING, so capacity is not
the wrong number for one, it is a concept that does not apply, and borrowing
it made a resident's worth ride a curve chosen for a different job.

Measured, capacity grows 1.40 a level against income's 1.35, so a resident's
pig drifted from 300 seconds of its own income at level 1 to 998 at level 40
-- and robbing went from 3.7x the return of idling to **12.3x**. The same
mistake as `LOSS_CAP` x `HEIST_PAYOUT` one level down: two curves multiplied
without anybody checking the product. `RESIDENTS.pigSeconds` pins it, and the
ratio is now 4.92x at level 1, 20 and 40 alike.

**A CONSTANT RATIO IS THE POINT, NOT A LOWER ONE.** Prices can be set for
whatever robbing is worth; what cannot be tuned around is a ratio that MOVES,
because then no single set of prices is right for both ends of the game.

**AND `HEIST_PAYOUT` STAYS AT 2 ON A RESIDENT, WHICH REVERSES THE OBVIOUS
ARGUMENT.** The multiplier exists so a thief's gain stops being a victim's
pain, and a resident has no pain -- so by that reasoning it should not apply.
The reasoning is sound and the conclusion is dangerous: paying LESS for
robbing an empty house than for robbing a real child makes robbing the child
the better play. For this audience the incentive has to point at the NPC.

**AND THE PUBLISHED NUMBER IS THE INTERFACE, WHICH COST A REAL BUG.**
`updatePile` was called only inside the accrual branch, guarded by
`coins < capacity` -- and a level rise tops a resident up to EXACTLY full, so
on the one tick that mattered the guard was false and the plot attribute kept
what it was seeded with at boot. Measured: residents publishing 2,962 while
the street was level 9 and their real pigs held 44,130. Everything a thief
can see reads that attribute -- the coin pile on the lawn, the value on the
rob badge, the take quoted by the steal prompt -- so the world and the server
disagreed by fifteen times, silently, with the server being right. **Anything
that changes a pig has to republish it in the same breath.**

**THE TARGET ABSTRACTION IS NINE ACCESSORS, NOT TWENTY BRANCHES.**
`HeistService` is written against `Target = Player | Resident`, and
`typeof(t) == "Instance"` is the entire discriminator -- a Player is an
Instance and a Resident is a table, so there is no flag to keep in step.
Every asymmetry lives at the one accessor that owns it. Branching at the call
sites instead would have put "is this a person" in twenty places, and the
twenty-first would have been added without it.

**IT ALSO FOUND TWO LIVE BUGS IN `PoliceService` THAT NOTHING ELSE COULD
HAVE.** `notify(alarm.victim, ...)` calls `FireClient`, which throws on a
plain table -- so the first robbery of an empty house during a patrol would
have errored outright; and `alarm.victim.Parent` was safe only by accident,
because indexing a table returns nil rather than throwing. Both go through
`HeistService.notifyTarget` and `.isPlayerTarget` now. **A type that widens
finds every place that quietly assumed the narrow one.**

**A RESIDENT IS TOPPED UP WHEN THE STREET LEVELS UP, AND THAT WAS MEASURED
RATHER THAN ANTICIPATED.** They are seated at BOOT, when the server is empty
and the derived level is therefore 0, so they seed against a level-0
capacity. The first player then arrives, the level jumps to theirs, and
capacity grows while the coins do not: measured at 2,872 coins sitting in a
pig that now held 19,208, which is 15% full. A thief crossing the road to
that finds two per cent of almost nothing. Topped up to the same share of the
NEW capacity whenever the level RISES -- and never when it falls, because
following it down would refill a pig a player had just emptied, which is a
thief watching their own robbery undone and a coin faucet keyed to the door.

**A STEAL WAS A TRANSACTION, AND IT IS A DECISION NOW. `Config.CRACK` IS THE
GREED DIAL.** One fixed hold took one fixed `STEAL_FRACTION` of a pig, and a
player performed it identically forty times an hour. That is the whole of why
robbing felt the same every time, and it is a structural fact about the shape
of the action rather than a tuning miss: there was nothing in it to decide.
Worse, THE HOLD IS THE ONE MOMENT IN THIS GAME WHERE THE GAME SWITCHES ITSELF
OFF -- every tuned number in this design is a SPEED, and the central action of
the game it is named after was standing still.

A crack is a sequence of slices. Each one landed banks a bigger share than the
last (2.0, 2.8, 3.9, 5.5 and 7.7 per cent) and narrows the target for the
next. The thief walks away whenever they like and keeps what they have; a miss
ends the attempt and they STILL keep what they have. So it is push-your-luck,
and it is the first thing in this design that can produce a PARTIAL OUTCOME --
*"I bailed at three because the dog turned round"* -- which is what makes a
repeated action generate stories instead of receipts.

**THE SLICES GROW, WHICH IS THE ENTIRE REASON TO STAY.** A flat slice makes
the last step worth exactly what the first was, so there is no temptation and
no decision, and the mechanic collapses back into a hold with extra taps.
Growing, the step you are deciding about is always the most valuable one you
have been offered.

**FIVE STEPS, AND THE ARITHMETIC PICKED IT.** A clean run takes 21.9% against
a `LOSS_CAP` that was 25% at the time: a greedy thief could empty a
victim's whole hourly allowance in one attempt and no further. **THAT
REASONING IS GONE AND THE NUMBER STAYED** -- the cap is 45% now (see above),
so a sixth step would fit rather than being clamped to nothing. Five survives
on its own merits: the slices grow 1.4x, so a sixth is worth 10.8% of a pig by
itself, which is the "one rung worth more than everything under it" shape this
file rejected when Bigger Sack was scaled. The step count is a PACING decision
now rather than a consequence of the cap. It also calibrates against what the game already did --
the old flat 8% take lands between step two (4.8%) and step three (8.7%), so
today's robbery is the MIDDLE of the new range rather than its floor.

**A SLICE IS A SHARE OF THE PIG AS IT WAS WHEN THE ATTEMPT OPENED, AND THE
FIRST BUILD HAD IT OTHERWISE.** Measured on a live resident: a clean
five-slice run took 8.9K where the arithmetic above says 9.7K, because each
slice was a fraction of a pig several slices lighter -- so the documented
21.9% was really 20.2%, and it drifted differently again on a pig that was
accruing income while the thief worked. Two curves multiplied without anybody
checking the product, which is the same shape as `LOSS_CAP` x `HEIST_PAYOUT`
one level up. Pinning to the opening balance also makes the GAUGE honest,
which matters more than the arithmetic: a slice is then a fixed width on the
bar, so the next one can be drawn before it is taken. It is still clamped
against the live balance, because however the share is computed a pig cannot
pay out coins it no longer holds.

**COINS LEAVE THE PIG PER SLICE, NOT AT THE END.** Banking a promise and
settling up afterwards lets two thieves cracking one pig both be promised the
same coins -- the exact double-spend the old code's *"taken from the pig
immediately"* guard existed to prevent -- and it leaves the pile on the lawn
frozen through the whole robbery. Taken per slice, the coin pile visibly
DRAINS while a thief works: the greed bar drawn in the world rather than only
on their screen. Verified live, 44,129 down to 37,282 across one run.

**THE ALARM FIRES ON A FUMBLE AND NEVER ON A CLEAN ROBBERY, and that choice
decides whether robbing a present player is possible at all.** A crack has
five moments it could fire at. On the first slice the owner always wins; on
completion they can never defend, only chase. On a MISS is the third answer
and the one that makes skill worth having: land every slice and the victim
finds out from their balance, the plaster and the delivery line; fumble one
and you bring the whole street down on yourself. It is also what wakes the
dog, so the crack and the approach are one decision seen from two ends.

It does not make a clean robbery invisible, which is the objection to check it
against. The thief still hauls a labelled miniature of the victim's own pig,
still wears a Highlight visible through walls, and the pile on that lawn just
shrank. **What a silent crack buys is that nobody was TOLD** -- stealth of the
alarm, never stealth of the getaway.

**THE SERVER OWNS THE CLOCK AND `CrackTap` CARRIES NO ARGUMENTS.** The sweep
is deterministic from a `startedAt` stamped in `workspace:GetServerTimeNow`,
so both ends read one clock; the client renders it and reports a tap making no
claim at all. Same decision as `BoneThrow` and `placeLadder`: the click means
"now", never "now, and here is the outcome".

**WHAT THAT BUYS IS FAIRNESS, NOT SECURITY, and it is worth being exact
because it looks like an anti-cheat.** The best possible outcome of a
perfectly forged client is landing every slice -- which is also what a good
player gets, and what the five-step ceiling is already tuned against. There is
no jackpot here to protect. What server timing actually stops is the opposite
failure: a client deciding its OWN hits would make a robbery worth whatever
somebody's ping happened to be. `Config.CRACK.tapGrace` is the other half of
that, widening the zone by a tenth of a second at BOTH edges, because a tap
judged on the far end of a 90ms link would otherwise lose the trailing edge of
every zone somebody cut fine.

**THE LOCK AND THE LOCKPICKS ARE STILL ONE AXIS AND IT IS NO LONGER A
DURATION.** `Config.STEAL_HOLD` and `getStealHold` are retired outright: the
Vault Lock narrows the target zone and Lockpicks widen it, which is a thing a
player can SEE rather than a number they have to be told. That is also what
finally makes the vault dial legible -- a ProximityPrompt animates its ring
over whatever duration it is given, so three seconds and nine looked
identical, and the whole tree read as decorative. Verified live at lock level
1: zone widths 0.692, 0.561, 0.454, 0.368 and 0.298 of the dial, exactly
`getCrackWindow`.

**A DIFFICULTY GATE MAY ONLY BE CHARGED FOR ONCE.** The prompt hold survives
at a flat `Config.CRACK.openHold` of half a second, and it is a doorknob
rather than a gate -- if it still scaled with the Vault Lock the defender
would be paid twice for one upgrade. It is still validated server-side,
because a `ProximityPrompt`'s `HoldDuration` is writable by the client that
sees it, and an attempt now drops your shield and wakes a dog.

**BIGGER SACK SCALES THE SLICES, AND IT PAYS OUT ON A RESIDENT WHILE BEING
CAPPED AGAINST A CHILD.** The rung used to scale the one flat take and would
have gone inert with nothing erroring. Two candidates were rejected: more
STEPS puts the sixth slice at 10.8% of a pig, so one rung would be worth more
than the whole base run; a wider WINDOW is the Lockpicks rung, which already
owns that axis. Scaling every slice, a maxed sack asks for 41.6% of a pig and
`LOSS_CAP` refused everything past a quarter -- while a resident has no cap
and pays in full. **The incentive points at the empty house, which is the
direction this design needs it to point**, and it fell out of the arithmetic
rather than being arranged.

**AND THAT LAST SENTENCE IS NO LONGER TRUE, BECAUSE THE CAP MOVED TO 45% TO
STOP IT GUTTING THIS VERY RUNG.** The two readings of one number were in
direct conflict: capped at a quarter, three of Bigger Sack's four levels did
nothing to a player, and the thing that made the incentive point at residents
was the same thing making a bought upgrade not pay. Raising the cap fixed the
rung and spent the asymmetry -- both targets pay 41.6% now. What still points
a thief at an empty house is RISK rather than arithmetic, and that is written
up in full under `LOSS_CAP` above.

**THE ALLOWANCE RUNNING OUT IS SAID, NEVER CLAMPED.** A slice silently worth
nothing is the minigame reading as broken. It ends the attempt out loud, names
the victim, and the thief keeps everything they landed -- the same rule the
sell refusal follows, where a payout that does not fit is refused rather than
quietly shrunk.

**A CRACK IS A PLACE AS WELL AS A MOMENT.** The panel is opened by a prompt
and closed by a tap, and neither notices somebody walking away, dying, or
being carried off by a patrol car. The binding to the lawn is polled, against
`STEAL_RANGE` with slack, so an attempt survives shuffling on the spot and
ends the moment somebody actually leaves.

**A DOG CATCHING AN EMPTY-HANDED THIEF IS A NEW ENDING, and without it the
dog would have run somebody down and then done nothing.** `HeistService.tag`
returns early with no loot, which was always correct while a chase could only
start after a completed steal. A crack can now let the dog off at somebody who
has banked nothing at all, so the catch asks CARRYING at the moment it lands
rather than at the release -- the thief may have banked three more slices and
be running for the gate by then. Empty-handed they are SEEN OFF:
`Config.DOG_WATCH.scareStun` holds them still briefly and the attempt breaks.
Being robbed has to stay survivable; so does failing to rob, and taking coins
a nine-year-old never had would be a debt for trying.

**THE PANEL DRAWS THE PIG AND NOT THE ALLOWANCE, which was the first version
and was wrong.** Drawing `LOSS_CAP`'s remaining allowance as the whole gauge
makes it mean "how much of what I am permitted", which is a rule a
nine-year-old has never been told and cannot see. Drawing the PIG makes the
gauge a picture of the object in front of them, with the cap as a RED LINE
across it. A resident's line sits at zero and the bar can empty completely --
the difference between an empty house and a real child, drawn rather than
explained.

**THE NEXT SLICE IS DRAWN ON THE GAUGE, and that is the greed dial rather than
a flourish.** Each slice is 1.4x the last and a fixed width on the bar, so the
segment visibly GROWS every time somebody decides to stay -- verified at
0.020, 0.028 and 0.039 of the bar across the first three. It is the only place
"the step you are deciding about is always the biggest one you have been
offered" is a picture instead of a number.

**AND THERE ARE TWO WAYS INTO A PIG NOW, WHICH IS WHAT THE CRACK COULD NOT BE
ON ITS OWN.** The crack made a single robbery a decision and left every
robbery the same KIND of decision: five slices, a lock fighting you, and the
only choice being when to stop. `Config.SMASH` is the other way in -- one
1.3-second hold on its own key, a fixed take, and the alarm, the victim and
the dog all at the moment it lands.

**WHAT IT IS ACTUALLY FOR IS MAKING THE TWO DEFENCE RUNGS ANSWER DIFFERENT
ATTACKS, and that is the half to protect if any of these numbers move.** A
Vault Lock narrows the crack's windows and does NOTHING to a smash, because
there is no lock being picked. A dog is nearly irrelevant to a clean crack --
the alarm only fires on a fumble -- and is the ENTIRE cost of a smash. So a
well-locked pig with no dog is soft to a smash, a well-guarded pig with no
lock is soft to a crack, and a thief reads both from the pavement, because the
dial says one and the kennel says the other. Two rungs that used to mean "more
defence" now mean different things, and neither is bought without choosing
which robbery you are defending against.

**THE TAKE IS THE CRACK'S OWN LADDER RATHER THAN A NUMBER OF ITS OWN.**
`getSmashFraction` is exactly `getCrackFraction(SMASH.steps)`, so it inherits
`baseSlice`, `stepGrowth` and the Bigger Sack scaling in one expression --
4.80% of a pig at a bare sack, 9.12% at a maxed one, a constant 0.219 of a
clean crack at every level. A second constant would have been a second
description of what a robbery is worth, which this file has already paid for
twice: `RESIDENTS.pigSeconds` solved against a take that was then replaced,
and `SHOP_BANK_PIG_SECONDS` pinned and wrong by 62% on its first audited boot.
**Scaling with the sack is not optional** -- a smash that ignored it would be a
rung bought with coins that quietly does nothing for anybody who prefers the
loud way in, which is the Tiptoe rung and the `LOSS_CAP`-refunded sack levels
arriving a third time.

**A SMASH MUST PAY STRICTLY LESS PER SECOND THAN A CLEAN CRACK, AND THAT IS
WHAT SET THE STEP COUNT.** `auditRobbery`'s whole model is
`robberyCycleSeconds(maxSteps)` and it calls the result an UPPER BOUND on what
a thief can earn -- so a faster way in that paid better per second would make
that sentence false with nothing in the audit changing and nothing in any log.
Measured live: a house is 21.23s against 9.53s and the smash pays 49% of the
rate; a shop is 16.85s against 5.15s and it pays 72%. Three slices was the
tempting answer, because 8.7% is almost exactly the flat 8% take this game
shipped with for its whole life -- and it comes out at 92% of a clean crack's
rate for 45% of the exposure, so nobody would ever crack anything again.

**AND THE OTHER REASON GIVEN FOR TWO SLICES WAS FALSE, WHICH WAS CAUGHT BY
MEASURING A COMMENT WRITTEN AN HOUR EARLIER.** It said a three-slice smash
would push a six-target lap to about 55s against a 60-second `STEAL_COOLDOWN`
and break the audit's fourth check. **A LAP IS CYCLE TIME TIMES TARGETS AND
CONTAINS NO STEP COUNT AT ALL** -- 57.2s at two slices and 57.2s at three, so
the step count could never have moved it. It was reasoned from the shape of
the concern rather than from the expression, it named a real check, and it was
wrong: `gable()` and the kennel rotation, one more time, in a comment written
by somebody who had just finished reading about both.

What the lap actually says is better news and is worth keeping. At 57.2s
against 60s a smash-only thief is COOLDOWN-BOUND -- they arrive back at the
first pig three seconds early and wait -- so the real figure is 47% rather
than 49%, and the mechanic self-limits through a number that was already there
for other reasons. **THE SHOP COLUMN IS THE THIN END**: a shop's run home is
short so its cycle is mostly the hold, and a shop has no dog and nobody home,
so the alarm costs a thief less there than anywhere else. Four shops lap in
20.6s against the same 60, which is what makes 72% a best case nobody can
sustain. If shop smashing ever reads as the only thing worth doing, the lever
is `SMASH.hold` rather than `steps` -- lengthening the hold moves the cycle
without touching the take, so it costs the house nothing.

**THE SMASH HOLD IS LONGER THAN THE CRACK'S OPEN HOLD, WHICH IS THE OPPOSITE
OF WHAT "NEAR-INSTANT" SOUNDS LIKE.** `CRACK.openHold` is half a second and
opens a lock that can be walked away from having taken nothing. A smash is the
whole robbery on one press: it drops your shield, empties a share of somebody's
pig, wakes their dog and names you to them. It may never be startable by a
brushed prompt, which is the same argument that gave the open hold its half
second, applied to something that protects a great deal more. It is derived at
half a sweep of the dial, so the sentence a player ends up feeling is A SMASH
TAKES LESS TIME THAN ONE SLICE OF A CRACK.

**IT DELIBERATELY DOES NOT ROLL A SHOP DROP.** `SHOP_VAULT_DROP` is one in
five COMPLETED CRACKS and a smash is not one. Measured, a smash cycle on a
shop is about 5.2 seconds against 16.9 for a full crack, so the same twenty
per cent would pay out three times an hour as often for a fifth of the coins
-- the cheapest drop farm in the game. Cracking a shop keeps a reason to exist
beyond the money.

---

**TWO PROMPTS ON ONE PART THAT ARE NOT EXCLUSIVE, WHICH SPENT A GUARANTEE
`PromptUI` WAS BUILT ON.** This file already records that prompts share a part
in two places -- collect/steal on a piggy's Body, hide/dig on a bin's Hatch --
that the game guarantees they are exclusive, and that "there is no offsetting
logic and there should not need to be". Steal and smash are the first pair
that must BOTH be visible, because a choice you cannot see is not a choice.

**A SLOT AND NOT A STUD OFFSET, AND THE DIFFERENCE IS A MEASUREMENT.** A card
is a `BillboardGui` sized in OFFSET pixels, so it is a fixed size on screen at
every distance, while `StudsOffset` is a world displacement that projects to
FEWER pixels the further off you stand: the shipped 1.6 studs is about 152px
at 5 studs and about 69px at `STEAL_RANGE`, against a card 82px tall. So a
stud offset separates the cards when you are on top of the pig and OVERLAPS
them at exactly the range a thief decides from. `Config.PROMPT_SLOT_ATTRIBUTE`
grows the billboard by the slot and pins the card to its bottom edge instead,
which is a constant pixel gap at every range -- measured at 94px separation
and a 12px gap at 4, 7 and 10 studs -- and slot 0 lands on the identical pixel
the card has always used, which is what made it safe to add to ten existing
prompts at once.

**A LATER WRITE BEAT THE EARLIER ONE, AND THE EARLIER ONE READ LIKE THE BUG.**
The card's arrival pop set `Size` to a SCALE height three hundred lines below
where the slot set an offset one -- correct for as long as a card filled its
billboard, and silently undoing the slot the moment one did not, so both cards
grew back to the full box and landed on top of each other. Measured on a live
client, `card.Size` read `{1,0},{1,0}` while the source plainly said
`{1,0},{0,82}` and the AnchorPoint beside it was the NEW value: that
disagreement is what said the fault was a second write rather than a stale
module. **WHEN A PROPERTY IS SET IN TWO PLACES THE SECOND ONE WINS, SO GREP
THE PROPERTY RATHER THAN THE LINE YOU CHANGED.**

**`TextTruncate` HIDES AN OVERFLOW RATHER THAN REPORTING IT, WHICH IS THE
`TextScaled` TRAP WEARING THE OTHER FACE.** This file already records that
with `TextScaled` on, "it fits" is guaranteed and means nothing, and the
failure is silent SHRINKAGE. With `TextTruncate.AtEnd` the failure is silent
CLIPPING, and it is worse in one respect: the label reads back the full string
from every property probe while the card shows "Loud . sets the...". Only a
photograph said so. Measured after: 141px of text in a 108px box. **THE TEST
IS `TextBounds.X` AGAINST `AbsoluteSize.X`, NEVER THE STRING.**

**AND THE PHOTOGRAPH NEEDED THE WORKAROUND THIS FILE ALREADY RECORDS**, which
is worth noting because it is the reason that bug survived being verified: an
`AlwaysOnTop` billboard is drawn in a pass `screen_capture` is taken before,
so EVERY PROMPT CARD IN THIS GAME IS INVISIBLE TO EVERY SCREENSHOT EVER TAKEN
OF IT. A throwaway clone with the flag off, shot and destroyed, is the way in
-- never the shipped flag.

**ONE HOLD RECORD COULD NOT SAY WHICH PROMPT IT BELONGED TO.** `holdStarted`
was `{plot, at}` keyed per thief, which was sufficient while a pig carried one
entry prompt. With two on different keys and both live, a 1.3-second smash
hold would have satisfied a half-second steal check -- a real robbery started
by the wrong press. It carries the prompt now, and both entry points go
through one `wireEntry` rather than two copies of a guard that has already
cost this project weeks once.

---

**A `ProximityPrompt` IS SHOWN ON ENTERING RANGE, AND A TEST HARNESS THAT
TELEPORTS ONTO ONE IS TESTING A PROMPT THAT WAS NEVER SHOWN.** This file
already records the rule for flipping `Enabled`; the same thing bites a probe
that drops a character on top of a piggy and presses. Measured across a
session: `InputHoldBegin` on a prompt at 7.7 studs, enabled on the client, was
a complete no-op -- no `PromptShown`, no `PromptButtonHoldBegan` on the
server, nothing in any log -- while the identical call had worked minutes
earlier. Position OUT of range, then move in, and confirm `PromptShown`
actually fired before believing a negative result.

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

**AND TIPTOE IS THE FIRST THING TO GO THE OTHER WAY DOWN THAT LADDER, WITH A
CEILING THAT IS STRUCTURAL RATHER THAN IMPOSED.** Speed Boots had to be
capped at 1.0 BY HAND to respect `BASE_WALK_SPEED`; a tiptoe cannot violate
it at any level, because the whole point of the stat is that it is below
walking pace. It is one more factor inside `currentSpeed`, so it inherits
every rule above it with no new balance code -- the same call `Config.DODGE`,
the bin's exit burst and `CLIMB_MULTIPLIER` each already record.

**THE DOG WILL READ SPEED, NOT A STEALTH FLAG, AND THAT IS THE LOAD-BEARING
HALF.** A boolean the dog has to check is a second piece of state that can
disagree with how fast somebody is actually moving; a threshold on speed
cannot. Everything else then falls out for free, including the one that
matters:

    TIPTOE at max (9.6)  <  a dog's `notice`  <  CARRY_SPEED (12 to 16)

**So you can sneak IN and you can never sneak the money OUT** -- the toll
lands on the getaway, where every other cost in this game already lands.

**TWO REFUSALS ENFORCE THAT ORDERING RATHER THAN DESCRIBING IT.** Tiptoe is
refused while CARRYING, because 12 x 0.35 is 4.2 and comfortably under every
threshold -- a thief would creep home past the dog with the pig in their arms
and the entire risk half of the trade would evaporate. And refused while
CLIMBING, because 0.35 x `CLIMB_MULTIPLIER` 0.35 is 0.12, about two studs a
second, or seven seconds to climb an eight-stud fence. That second one is the
multiplicative-slow trap this file keeps recording, caught before it shipped
rather than after.

**AND IT NEEDED A TOUCH CONTROL, NOT JUST A KEY, OR IT WOULD HAVE BROKEN A
RULE BY OMISSION.** Tiptoe is the only counter to a watching dog, and most of
this audience never presses a key -- so a keyboard-only sneak would mean a
guarded plot is unrobbable on a tablet, which is "defence buys time, never
immunity" broken by an input gap rather than by a number. The SNEAK button
takes x=174 on the dodge and garage row, which is the garage picker's own fan
origin: safe because the two can never usefully coexist, since a sneak
happens on a lawn and a ride is switched off anywhere but the street.

**AND THE TIPTOE RUNG IS LIVE, WHICH CLOSED A HOLE THE WATCHING DOG HAD
OPENED.** `TIPTOE.perLevel` and `.max` sat on disk describing an upgrade that
did not exist, and `currentSpeed` passed a hardcoded level 0 -- so every
player on the street tiptoed at `base` and nothing about a sneak varied
between them. `Config.UPGRADES.tiptoe` is Sneakers, the fourth rung of the
offence tree.

**WHAT IT BUYS IS SPEED, NEVER STEALTH, and getting that backwards is the
easy mistake.** The first write-up of this said the rung was how you sneak
past a Shepherd; Config's own comment said otherwise and Config was right.
`base` is 5.6, already under Scruffy's `notice` of 11 AND Rex's 10.2, and
`max` is 9.6, still nothing to a Titan's 0. So a level buys CROSSING THE SAME
LAWN IN LESS TIME -- 5.6 to 9.6, a 71% faster approach -- and never a lower
chance of being heard. WHICH dogs a sneak beats is the DOG's tier to decide,
which is why `notice` lives over there and the rung cannot touch it.

**THE RUNG COUNT IS DERIVED FROM THE STAT RATHER THAN CHOSEN.** `max` is 4
because `TIPTOE.base + 4 x perLevel` lands exactly on `TIPTOE.max` -- verified
live at 0.35 + 4 x 0.0625 = 0.60. Picking a count instead would let a later
retune of the stat silently strand a rung the player can buy and not feel, or
leave headroom nothing can reach.

**IT COST NOTHING ANYWHERE ELSE, which is the whole argument for the tables
being data.** `UpgradeService` walks `Config.UPGRADES` with `pairs`,
`ensureRow` builds a shop card from `info.tree` and `info.order`, and
`DataService.reconcile` descends one level into `upgrades` -- its own comment
already anticipated this exact case, *"adding a seventh upgrade later must
fill in just that key on every existing save"*. So no schema bump, no UI code,
no save migration. Verified live: the card renders at LayoutOrder 4, an
existing save reconciled the key in, and the sneak measured 5.60 / 6.60 / 7.60
across two purchases with base walk untouched at 16.00.

**AND THE ORDERING THE WHOLE DESIGN RESTS ON STILL HOLDS AT MAX**, which is
the one thing a rung on this stat could have broken: maxed sneak 9.60 < Rex
10.2 < carry 12.0. Measured on a resident's lawn, 14 seconds of pacing at 9.21
studs a second left the dog asleep. Anything that raises `TIPTOE.max` has to
re-check that line against the LOWEST `notice` in `DOG_TIERS` above zero.

**A FENCE CHARGES ONCE PER CROSSING, AND `Touched` IS NOT AN ENTRY EVENT.**
This shipped as a freeze: a player who touched an electric fence could not
move for a long time, and the "Snagged" toast arrived about ten times. Both
were the same bug and it is the sharpest example in this file of a handler
that is correct once and catastrophic repeated.

`Touched` re-fires on every re-contact, and it fires PER CHARACTER PART.
Measured on a live rig standing in an electric fence's ClimbZone: fourteen
parts reporting on the first contact frame, and 18 fires over four seconds
while resting. Every one of them called `applySlow`, which re-stamped
`stunUntil = now + 2.5`. **THE STUN RENEWED ITSELF FASTER THAN IT COULD
EXPIRE.**

**AND THE STUN IS WHAT KEPT THEM IN THE ZONE, so it fed itself.** The
ClimbZone sits ON TOP of the barrier, so a climber who gets shocked is
standing in the volume that shocked them -- and a stun is WalkSpeed 0 AND
JumpHeight 0, so they can neither walk out of it nor hop off. Measured still
inside it after four seconds. Nothing about the loop could end from the
inside.

Note "take the worst" made it worse rather than causing it: `until_` is
`math.max`ed against the existing snag, which is right and is recorded above
as a fix -- but with a repeating source it means each fire also pushes the
END of the slow further out.

**THE COOLDOWN HAS TO OUTLAST THE PENALTY IT GUARDS, or it is not one.** A
cooldown shorter than `duration` just lets the second charge land as the first
expires, which is the same freeze at a slower rate. It is
`penalty.duration + FENCE_PENALTY_GRACE`, derived from the penalty rather than
pinned, so a tier that gets a longer snag gets a longer immunity with nothing
to remember. Verified re-arming on schedule: charges at 0.6s, 4.7s and 8.7s
across five entries, with the two entries inside the window refused.

**KEYED PER PLOT AND PER SOURCE, NEVER PER PLAYER.** Per player alone would
let a thief cross a second neighbour's fence for free inside the window, and
the alley between two yards is 16 studs -- crossable in one. Per source keeps
the moat and the wire above it apart, so wading the water cannot buy a free
run at the fence behind it.

**A SHOCK THROWS YOU OFF, AND THAT IS THE HALF THAT MAKES THE COOLDOWN
HONEST.** Debouncing alone leaves the player standing on top of the fence for
the whole stun, waiting out a timer, which is the same picture as the bug with
a shorter clock. Only tiers that STUN throw -- `stun > 0` is the test rather
than a per-tier flag, because a rickety fence is meant to be climbable and
merely slow.

**IT REJECTS YOU TO THE SIDE YOU CAME FROM, AND MAY NEVER CARRY YOU ACROSS.**
Always pushing outward is a defence against somebody climbing IN and a free
getaway for somebody climbing OUT, on the tier that costs the most to buy.
Rejecting to the near side can be neither: the most it hands anybody is a few
studs deeper into ground they were already on, against 2.5 seconds of being
unable to move. The side is read from the ROOT's offset from the fence plane
in plot-local space -- verified over 80 contact samples, correct sign from
both sides, and end to end at 4.90 and 5.02 studs each back the way it came.

**`PlatformStand` IS THE WHOLE TRICK, AND WITHOUT IT THE KNOCKBACK DOES
NOTHING.** A plain velocity write buys **0.20 studs**: the shock has just set
WalkSpeed to 0, and the humanoid spends every frame damping horizontal motion
toward `MoveDirection * WalkSpeed`. **VERTICAL IS THE ONE AXIS IT DOES NOT
FIGHT** -- which is exactly why the trampoline is vertical-only and works, and
why copying its shape here silently produced a shove that went nowhere.
Measured across four candidate strengths, all four horizontal, all four dead.
Under PlatformStand the identical push lands 5.66 studs and the character
recovers to `Running` on its own. Anything in this game that wants to move a
character SIDEWAYS against their own humanoid needs it.

It is also the right picture rather than only the working one: the character
goes limp for the flight, which is what being zapped off a fence looks like.
The limp window covers the flight and no longer -- the stun goes on holding
them still afterwards, so extending it buys nothing.

**THE CLIENT APPLIES IT, THE SERVER DECIDES IT** -- the same split as the
trampoline and for the same measured reason: a server-side write to a player's
`AssemblyLinearVelocity` is discarded. It carries a DIRECTION where the
trampoline carries nothing, which is safe for the one reason that matters:
the server computed it. The client is being told which way it was thrown, not
asked. The client still flattens and re-normalises what arrives, so a
direction with a vertical component in it cannot quietly trade knockback for
launch height.

**A FENCE IS A TILED PANEL MESH NOW, AND IT IS THE FIRST UPGRADE IN THIS
PROJECT THAT COST FEWER PARTS THAN WHAT IT REPLACED.** `decorPicket` laid a
picket AND a rotated tip every 2.6 studs, which over a plot's whole perimeter
is about 276 parts -- so a street where all eight own one is over two thousand,
as much as the entire rest of the world. One panel every ~7 studs replaces
that. Measured on a 44-stud run: **38 primitive parts against 6 panels**, and
on a real plot **57 parts against roughly 276**, of which 47 are panels and
the other ten are the barriers and climb zones that were always there.

That is the property to preserve. A later tier that wants a mesh PER POST
throws the whole saving away and puts the fence back to being the most
expensive object on the street.

**IT IS SAFE ONLY BECAUSE COLLISION AND DECORATION WERE ALREADY SEPARATE.**
The entry below has said for the life of the project that one invisible slab
carries all the collision and everything visible is `CanCollide` off, so
"styles can look like anything without changing the jump maths". This is the
first change to actually cash that in: `buildFence` builds a `Barrier`, a
`ClimbZone` and ONE call to a decorator, and the mesh replaces the decorator
and nothing else. Verified after: barrier top unchanged at 4.30, five barriers
still carrying their `AlongX`/`Span` attributes for the ladder, zero panels
breaking the no-collide/no-query rule, `isHoppableFence` and `isClimbedFence`
unchanged, and `auditFences` clean.

**THE PANEL STANDS TO `decorTop` AND THE BARRIER STILL STANDS TO `top`, AND
CONFUSING THOSE TWO IS HOW A VISUAL CHANGE BECOMES A BALANCE CHANGE.** They
are 5.6 and 4.8 on the picket. Measured live: panels reach y 5.10 and the
barrier 4.30, which is exactly those two numbers above `FENCE_BASE_Y`.

**SCALED UNIFORMLY OFF ITS HEIGHT, THEN STRETCHED ONLY ALONG THE RUN.** The
panel is sized from `decorTop / authoredHeight`, which fixes how many fit; the
leftover is taken up by stretching the LENGTH so the run tiles exactly. A
panel is a flat thing seen side-on, so a stretch along the run is invisible
where a stretched height would read immediately.

**MOAT ALIASES ELECTRIC IN `Config.fenceMesh` RATHER THAN CARRYING ITS OWN
ROW**, because it already does in the code: `decorMoat` is one line calling
`decorElectric` -- the wall is identical and the water is the upgrade, built
once for the whole ring. Two rows would be the near-identical duplicate that
drifts the first time either is touched.

**ALL FIVE TIERS ARE MESHED NOW, AND EVERY ONE IS CHEAPER THAN THE PRIMITIVES
IT REPLACED.** Measured on a real plot, cycling the tiers through the admin
console:

    Rickety    82 parts   72 panels        Barbed    40   30 panels
    Picket     57         47 panels        Electric  44   34 panels
    Moat       74         34 panels + 30 primitive water parts

The ten non-panel parts on every tier are the five barriers and five climb
zones that were always there. Moat carries thirty more because its WATER is
still primitive and still built for the whole ring rather than per side --
which is correct, and is the reason `decorMoat` is one line calling
`decorElectric`.

A squat panel tiles more often than a long one, so the count runs inversely to
the mesh's aspect: 4.8 studs a panel on Rickety against 12.0 on Barbed. All
four are far under the ~276 the primitive picket built.

Verified on the same pass: zero panels breaking the no-collide/no-query rule
on any tier, five intact barriers each still carrying `AlongX`/`Span`, barrier
top 7.50 on the 8.0 tiers, `auditFences` and `auditEconomy` both clean, and
every tier's hoppable/climbed classification unchanged.

**AND THE GENERATOR ANSWERS ADJECTIVES OF CONDITION, NOT OF AGE.** The first
rickety panel was asked for an "old broken wooden fence, posts leaning at
slight angles, one plank missing" and came back as CREAM POSTS WITH PALE BLUE
RAILS, perfectly upright and perfectly tidy -- a smart modern rail fence, and
the exact opposite of the brief. It would have made the tier's own blurb
("Leaning posts and missing planks") a lie on screen. "Derelict", "rotten",
"splintered", "shabby" and an explicit "dark brown" got it; "old", "weathered"
and "broken" did not. **A COLOUR IT IS NOT TOLD IS A COLOUR IT WILL INVENT**,
which is worth one extra sentence in every prompt.

**AND THE TIERS GO ONE AT A TIME.** A style with no row falls back to its
primitive decorator, silently and per style, so `picket` can be meshed while
the other four are not. Verified both ways in one session: a picket plot built
47 panels and an electric plot built its primitive `Post`/`Wire`/`Live` parts
with nothing in the log.

**TESTING IT NEEDED THE ADMIN CONSOLE, BECAUSE A DEV SAVE IS NOT AT THE TIER
YOU WANT.** Two `UpgradeRequest` purchases moved a save that was already on
Electric further UP rather than landing on Picket, and the sandbox cannot
reach a live plot to call `buildFence` directly -- requiring PlotService there
hands back a fresh module whose `start()` never ran, which this file already
records for PoliceService. `AdminRequest("upgrade", nil, "fences", 2)` is the
way in, and it is worth knowing before spending a purchase on the wrong tier.

**A fence must never be uncrossable.** Defence buys *time*, never immunity. An
un-robbable player kills the offence tree and stalls the economy at the top.

**THE RULE IS UNCHANGED AND THE MECHANISM IS NOT: A TIER YOU CANNOT HOP IS A
TIER YOU BRING A LADDER TO.** This entry used to end *"every tier from Barbed
Wire up stays at a jumpable 6.0 studs and escalates the hazard instead"* — a
constraint that was self-imposed, because it assumed the only way over a fence
is a jump. Height is a tunable again and the top three tiers stopped being the
same fence with different paint on it.

**AND THE WAY OVER IS CARRIED IN, NOT BUILT IN.** For one session every fence
segment carried a permanent climbing TRELLIS. Three things were wrong with it
and only the first was visible: it stood on tiers you can step over, so the
cheapest fence in the game had a climbing frame bolted to it; it made a fence
a SLOWER FLOOR rather than a wall, because the way across was always there and
always free; and it left nothing for an item to sell, since the problem a
ladder would solve was already solved on every plot forever. A fence is solid
now and `Config.LADDER` is what crosses it.

**WHICH DOES NOT MAKE A PLOT UNCROSSABLE, and that is the rule this brushes
against rather than breaks.** The gate is always open at every tier: 24 studs
wide at Rickety and still 8 at the Moat. So the plot is enterable by anybody,
with no item, at any tier. What a solid fence actually stops is the SIDE and
BACK crossing, which is the alley shortcut between two neighbours, and what
the ladder buys is a route that is not the front door.

**A FENCE IS A STUD TALLER FROM THE STREET THAN FROM THE LAWN, AND ALL THREE
TOP TIERS SHIPPED IN THE BAND WHERE THAT MATTERS.** The fence stands on the
world ground and the yard it encloses is the plot slab, one stud up. So the
same barrier is `top` from the street and `top - LAWN_LIFT` from the lawn, and
a tier between the two is hoppable in exactly ONE DIRECTION.

Measured live: barrier top at world 5.50, lawn at 0.50, street at -0.50, feet
apex 5.59. Getting IN was refused by 0.41 studs and getting OUT cleared by
0.59. **THE TOLL LANDED ON THE APPROACH AND THE GETAWAY WAS FREE**, which is
backwards from every other cost in this game, and it read as "I can still jump
the tier 3 fence" rather than as an asymmetry. It would also have shipped the
ladder inert: nobody buys a way over a wall they can step over.

6.0 -> 7.0 gives the climb the same 0.41 margin from the LAWN that it used to
have from the street. Verified after: feet reach 6.10 from the lawn and 5.11
from the street against a barrier at 6.50, blocked both ways.

**THE FIX IS A RULE AND AN AUDIT, NOT A NUMBER.** `Config.isHoppableFence` and
`isClimbedFence` are the only two places the question is asked, and
`Config.auditFences` refuses the band outright at startup, in Studio as well as
live. Same argument as `auditEconomy`: the failure is a number, nothing errors,
nothing looks wrong, and the moment to hear about a number is while you are
typing it.

**HEIGHT IS VERY NEARLY SPENT AS A LEVER, which is why the three climbed tiers
share a number rather than laddering upward.** Measured from a viewer on the
pavement, over the front fence, to the piggy: at a barrier top of 6.0 about 56%
of the pig reads, at 7.0 it is 42%, at 8.0 it is 28%. Worth knowing that the
COIN PILE was already lost at 6.0 -- the sightline clips the pig at y 7.75 and
the pile sits at its feet -- so what carries how full a piggy is now is the
steal prompt's own figure and the badge above it. A tier above these escalates
what the crossing COSTS, never how tall it is.

**AN R15 CHARACTER'S LEGS AND FEET COLLIDE WITH NOTHING, AND EVERY FENCE IN
THIS GAME HAD BEEN TUNED AGAINST THE FEET.** This is the real fault under the
one above, and it survived the fix for it.

Measured on a live rig standing on a lawn at y 0.50, the only parts carrying
`CanCollide` are `HumanoidRootPart`, `LowerTorso` and `UpperTorso`:

      lowest VISUAL point     0.006 above the lawn
      lowest COLLIDING point  2.139 above the lawn

`HipHeight` (2.225) holds the assembly up there and the legs hang off it as
decoration. So a fence is never cleared by the feet, which pass straight
through it. **THE NUMBER A FENCE HAS TO BEAT IS `Config.jumpReach`**, which is
`COLLISION_FLOAT + BASE_JUMP_HEIGHT`, and it is over two studs higher than
anybody had been designing against.

At the old 5.5 jump the collision bottom reached 0.5 + 2.139 + 5.5 = **8.14**
against a barrier top of 6.50, clearing by 1.64. So all five tiers were
jumpable, which is exactly what was reported, and the dead-band fix above had
made no difference to it at all.

**A PROBE THAT MEASURES THE WRONG BODY AGREES WITH THE GEOMETRY AND DISAGREES
WITH THE GAME.** The check that passed this took the lowest VISUAL part, got a
5.59 apex, compared it against 6.50 and reported the jump blocked, twice, in
two directions. It was right about the feet and the feet are not what
collides. Same family as measuring a house by its bounding box and getting its
FX at altitude, and as the "widest lawn ornament" that was really a height:
the convenient number and the load-bearing one are different numbers.

**SO THE JUMP CAME DOWN AND THE FENCES WENT UP, and the split was chosen off
the sightline.** Keeping the 5.5 jump would have needed `top` at 8.8 to beat
the reach, which leaves about a quarter of the piggy visible from the pavement
and reads as a prison wall. `BASE_JUMP_HEIGHT` is 4.0 and the climbed tiers
are 8.0: reach 6.14, so they are refused by 0.86 from the lawn and 1.86 from
the street, while Picket at 4.8 is still hopped from both sides with 1.34 to
spare. Roblox's own default is 7.2, and nothing in this game is platforming,
so the jump is spent almost entirely on fences anyway.

**AND `Config.auditFences` NOW ASKS `jumpReach` RATHER THAN THE JUMP**, which
is the half that stops this returning. The audit existed and was CLEAN through
the entire period every tier was jumpable, because it was comparing the same
wrong number the tiers were tuned against. An audit is only worth what its
question is worth.

**AND THE JUMP CAME DOWN RATHER THAN THE FENCES GOING UP, which is the cheaper
lever by a distance.** To put a tier out of hopping range while keeping the old
7.2, every tier above it has to start at 7.3 — and measured against a viewer on
the pavement, a fence over about **8 studs** starts hiding the piggy bank
itself, which is the thing a thief is deciding on. `BASE_JUMP_HEIGHT` is 5.5
now, which puts the SAME tiers out of range at the heights already built and
leaves the whole 6-to-8 band free for tiers that do not exist yet. Measured
live: apex 5.59, so Rickety (3.6) and Picket (4.8) are hopped FROM BOTH SIDES
and Barbed, Electric and Moat (7.0) are climbed from both.

**`UseJumpPower` WAS TRUE, SO `BASE_JUMP_HEIGHT` HAD NEVER DONE ANYTHING, AND
IT HID BEHIND A COINCIDENCE.** A Humanoid exposes two jump controls and obeys
exactly one: with `UseJumpPower` true — the rig default — `JumpPower` governs
and `JumpHeight` is stored and ignored. `refreshSpeed` has been writing
`JumpHeight` since the day it was written and not one of those writes changed a
jump. Measured: JumpHeight 5.50, JumpPower 50, apex **7.27 studs**.

It was invisible because the default happened to match. JumpPower 50 is about a
7.27-stud apex and the constant said 7.2, so the number every fence tier was
tuned against was right by accident while the code meant to set it did nothing.

**THE HALF THAT WAS ALREADY BROKEN IS THE STUN.** The line's own comment reads
*"WalkSpeed 0 alone still lets a stunned thief hop the fence they just got
shocked by"* — and that is exactly what shipped, because the `JumpHeight = 0`
underneath it was inert. An electric fence has never stopped anybody jumping.
`refreshSpeed` sets `UseJumpPower = false` now, so both halves work.

**GRAVITY CANNOT MOVE A JUMP, AND IT IS THE OBVIOUS THING TO REACH FOR.** With
`UseJumpPower` false, Roblox derives the launch velocity from `JumpHeight` AND
gravity together, so the apex is pinned to the constant whatever gravity is.
Measured on a live rig: gravity 196.2 gives an apex of 5.59, gravity 300 gives
5.61, and gravity 120 gives 5.72. All that changes is how fast you come down.

Worth writing down because it is a plausible fix that does nothing to the
thing it is aimed at while quietly re-tuning everything else in the game that
moves through the air: the trampoline's 10.1 studs, the wheelie bin's exit
hop, the fence knockback's measured 5.66, and every fall. `JumpHeight` is the
only lever on a jump.

**THE GENERAL SHAPE IS THE `RenderFidelity` ONE, one notch quieter.** That was
an API that threw; this is an API that ACCEPTS THE WRITE, STORES IT, AND
IGNORES IT. Nothing errors, nothing warns, and the property reads back exactly
what you set. Anything with a paired "which of these two do I obey" flag needs
the flag checked before the value is believed.

**THE MECHANISM IS A TRUSS AND THE PICTURE IS A LADDER, and they have to be
two different parts.** A `TrussPart` is climbed natively by Roblox, so the
climb costs no new key, no prompt and no movement code, and it inherits every
speed rule the game already has through `currentSpeed`. Its cross-section is
locked to 2x2 studs whatever is asked for: measured, `(40, 6.5, 2)` hands back
`(40, 2, 2)`, a beam lying on its side, silently. So the truss is INVISIBLE
inside the ladder's own geometry -- measured rather than assumed, since the
whole feature rests on it: a truss at Transparency 1 still enters the Climbing
state and still carried a test character the full 8 studs.

Exactly the split the fence itself already uses, where all the collision is one
invisible slab and everything visible is decoration with `CanCollide` off.

**THE LADDER HAS A FACE ON EACH SIDE OF THE FENCE, AND THAT IS A MEASUREMENT.**
A climber's root settles **2.2 to 2.6 studs** from the truss centre, hugging its
outer face, and no amount of thinning the picture changes where the engine puts
them. So a single flat panel on the fence plane leaves the climber floating two
studs off the thing they are visibly climbing. Rails at the truss's own faces,
one set each side, joined over the top -- which is the honest object anyway,
since a ladder you put over a fence to get up AND down is two ladders joined at
the top, and it is the only shape that explains how one placement serves both
ways over.

**THE PLACEMENT IS THE INFORMATION NOW.** This file prefers a tell to a fight,
and a permanent lattice said only "a fence can be climbed here, forever". A
ladder somebody has just stood up says who is coming over, where, and that they
have about twenty seconds left to do it.

**THE CLICK SENDS NO POSITION, WHICH IS THE LOAD-BEARING HALF OF LETTING IT GO
ANYWHERE.** "Anywhere along the fence" is the whole appeal of the item and a
coordinate on the wire is the obvious way to build it -- and then there is one
to forge and a range check to defeat, which is the exact trade `BoneThrow` and
`GadgetThrow` already refuse. `PlotService.placeLadder` takes the PLAYER and
reads their own character position: you choose the spot by STANDING THERE, the
server projects that onto the nearest fence segment, and the click still means
"use it" rather than "use it there". Verified: stood at plot-local (-30, -40)
against a side fence at x -33.6 and the ladder landed at (-33.6, -40).

**A SEGMENT'S OWN ENDS ARE THE CLAMP, so a ladder cannot be wedged into the
corner where two barriers meet and come out climbable from neither side.**
Verified in all three corners at a 2.0 margin, each time snapping to the
NEAREST segment rather than the one being aimed at -- standing 2.0 from the
back fence and 3.6 from the side correctly chose the back.

**ONE LADDER PER PLAYER, AND PLACING A SECOND RETIRES THE FIRST.** Same shape
as one bin per pursuit, and it is what stops a rich player laddering a whole
perimeter. Verified: two placements 30 studs apart left exactly one standing,
at the second spot.

**IT BUYS THE CLIMB AND NEVER THE HAZARD.** The ClimbZone still sits above the
barrier, so an electric fence zaps a laddered climber exactly as it zaps
anybody else. Defence buys time; so does the counter.

**AND THE REASON CODE COMES BACK, NOT THE SENTENCE.** PlotService knows whether
a ladder can stand; StealthService knows how to say so. Same split
`CosmeticsService.awardTokens` draws with its optional `why`, and it is what
keeps every refusal named rather than a consumable spent on silence.

**A CLIMB IS A MULTIPLIER ON `currentSpeed`, never a speed of its own** — the
same decision the dodge and the bin's exit burst already record. Roblox climbs
a truss at a fixed fraction of WalkSpeed and tracks it live, measured at
**0.699** across three speeds (16 -> 11.18, 8 -> 5.59, 4 -> 2.83). So a factor
added to `currentSpeed` inherits every rule above it with no new balance code:
a stun returns 0 and freezes a climber where they are, carrying scales the
climb off 12 rather than 16, and a snag slows the climb it was earned on.

Without a multiplier a free player crosses a 6-stud fence in 0.54 seconds,
which is not a defence, it is a formality. At `CLIMB_MULTIPLIER` 0.35 it is
1.53s free and 2.04s carrying — and **the gap between those two is the point**:
the climb out is always dearer than the climb in, so the toll lands on the
getaway, where every other cost in this game already lands. Verified end to
end, `Config.climbSeconds(6.0, 16)` predicting 1.53s against a measured 1.53s.

**THE CLIMBER PASSES THROUGH THE `ClimbZone`, AND THAT IS AS FAR AS THE
MEASUREMENT GOES.** Measured on a live climb: the zone spans y 5.50 to 10.50 on
a 6.0 tier and the climber's root reached 7.83, squarely inside it, so the
volume is entered. That was the half that could have gone wrong when the
crossing stopped being a jump. What has NOT been seen is the penalty firing,
because `firePenalty` returns early for the plot's own owner (*"owners cross
their own defences freely; they paid for them"*) and a solo session has nobody
else's fence to climb. The Touched path is not owner dependent and is the same
one a jumper has always taken; only the handler's first line differs. Same wall
as the rest of the heist system: it needs a second player.

**A SPEED THAT IS ONLY PUSHED ON AN EVENT NEEDS PUSHING WHEN THE CHARACTER
ARRIVES.** `refreshSpeed` is event-driven, so entering and leaving a climb both
have to call it or the multiplier lands on whatever unrelated event happens
next — usually the thief already being over the fence. `Humanoid.StateChanged`
is the hook, on both edges. And it runs once on spawn as well, which is what
finally applies the jump: connected only inside `CharacterAdded`, it never
fired for the character a player already has, which is every player in Play
Solo and the first into any server. Same trap the wheelie bin recorded.

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
A DEAD OUTCOME.** It lands as a SPARE COPY in the same reveal, carrying what it
is worth sold, so an open always visibly pays out -- and a spare has two exits,
the combine or the sale. What the old rule protected was that a nine-year-old
never opens something and gets nothing; that is still true. What it no longer
protects is that they never open something twice, which was never the part that
mattered.

**A SKIN IS ONE OF THREE TIERS AND EVERYTHING ELSE IN THE SHOP IS STILL ONE
OF FOUR, AND THE REASON IS A CONTENT BUDGET RATHER THAN A DESIGN TASTE.**

Four tiers is four pools that all have to be deep enough to be a pool. The
stock entry below says why in as many words -- a tier crate is only worth
opening if the tier behind it is more than a coin flip -- so a four-rung
ladder across two collections is a launch that cannot happen until roughly
twice as many skins exist. THE LADDER WAS SETTING THE ART SCHEDULE, which is
the wrong way round: a rarity ladder is meant to describe the catalogue, not
decide how big it has to be before anybody can play.

**AND THE TIERS DESCRIBE WHAT A SKIN IS NOW, NOT WHAT IT COST.** Common is
paint. Rare is paint with a twist and something that glows. Legendary adds
GEOMETRY -- fur, a pattern standing proud of the body, parts that are not the
pig -- plus an animation and a glow. That is a brief somebody can build
against, which "epic" never was: nobody could say what made a skin epic
rather than rare except the number beside it.

**WHICH REVERSES `rarityOf`'S OWN RULE FOR SKINS AND NOTHING ELSE, AND IT
COST NO CODE AT ALL.** The entry further down reads *"A tier is DERIVED,
never hand-tagged"*, and every word of its reasoning holds for a house or an
ornament: those are priced, the price IS the rarity, and hand-tagging sixty
of them means re-tagging them every time a price moves. A skin is no longer
priced -- it is crate-only, so its `cost` survives ONLY as a rarity input and
a sell cap -- so the price was deriving a tier from a number nobody could
pay. All 44 skins carry an explicit `rarity` now, which `rarityOf` already
preferred over the derivation: branch one was written for the drop-pool skins
and simply took over.

**TWO COLLECTIONS, NOT THREE, AND NEON NIGHTS WAS A SHELF SPLIT ON PALETTE.**
`og` (28) and `animal` (8). Classics and Neon Nights were never different
KINDS of thing -- both are the street's own pigs rather than a costume of
something else -- so the split asked "do you want a glowing one", which is
not a question a nine-year-old walks in with. Animal survives as a shelf
because "I want my pig to be a tiger" is one. Five skins went entirely:
Circuit Board, and the four animals with no artwork behind them (Woolly
Sheep, Dalmatian, Cheetah, Orca) -- flat paint pretending to be a coat.

**THE ONE THING THAT BROKE WAS A `floor` NAMING A TIER NOTHING CARRIES ANY
MORE, AND IT FAILED IN THE DANGEROUS DIRECTION.** The Legendary Crate floors
at a tier and `chestPool` admits anything at or above it BY RANK -- and a
legendary outranks an epic. So a floor of `"epic"` against a catalogue with
no epics did not empty that crate, it left LEGENDARY as the only stocked
tier, and `liveOdds` renormalised it to 100%. Six million coins bought a
GUARANTEED top-tier skin: the manufacture-rather-than-get failure the combine
ladder is tuned against, arriving through the front door.

**A FLOOR THAT EMPTIES A CRATE IS CAUGHT LOUDLY. A FLOOR THAT PROMOTES ONE IS
NOT.** `chestPool` refuses an empty pool and `ChestService` says so out loud;
nothing anywhere checks for a pool that got BETTER. Only the arithmetic said
so. Anything that removes a tier has to be walked against every `floor` in
`Config.CHESTS`, and the audit worth writing is "no chest may authorise odds
for a tier it cannot stock" -- run by hand this time, and it should not be.

**AND THE COMBINE LADDER HAD TO BE RE-SOLVED, WHICH THE ENTRY BELOW ASKED FOR
IN ADVANCE.** It says the property to preserve is the RATIO between the two
routes rather than the numbers. Rolling a legendary is 25 opens at 4%;
combining has always been quicker and is meant to be -- measured on the
shipped four-tier ladder it is 10.5 opens, so 2.4x. Dropping a tier moves the
rung below legendary from 12% to 44%, so the last hop gets dramatically
cheaper. Measured across the same odds:

    need 3    4.9 opens    5.1x cheaper than rolling   -- a shortcut
    need 4    7.0 opens    3.6x
    need 5    9.2 opens    2.7x   <- shipped, and back on the old ratio
    need 6   11.4 opens    2.2x

So `COMBINE.need` is 5, derived rather than picked. **A TIER COUNT AND A
COMBINE RATIO ARE TWO CURVES THAT MULTIPLY**, which is the most-repeated
post-mortem in this file arriving somewhere new -- and the second time it has
been caught at the whiteboard rather than months later.

**THE PRICE LADDER DID NOT MOVE AT ALL, WHICH IS THE MEASUREMENT THAT SAYS
THIS WAS SAFE.** The tier crates are solved on COINS PER LEGENDARY and that
table reproduces exactly: themed 500K at 4% is 12.5M and 25.0 opens, Rare
Crate 1.5M at 10% is 15.0M and 10.0, Legendary Crate 6.0M at 35% is 17.1M and
2.9. Folding `epic`'s 12 points into `rare` (32 + 12 = 44) and leaving
legendary at 4 is what holds it -- legendary is the only number in that table
the whole ladder is priced against, so it is the one that may not be touched
without repricing every crate at once.

**RETIRING A SKIN ORPHANS THREE THINGS IN EVERY SAVE AND ONLY ONE OF THEM
MATTERS.** `cosmetics.owned` and the `skin:` half of `spares` simply go
unread, because every surface that draws a wardrobe walks the CATALOGUE
rather than the save. `cosmetics.skin` is the one that bites: `getSkin` falls
back to the default on an unknown key -- correct, and the reason nothing
throws -- so a player wearing a retired skin comes back as Classic Pink while
their save still says otherwise, with the bag showing nothing equipped and no
error anywhere. `DataService.reconcile` prunes both wardrobe tables and the
spares against their catalogues now, the same call the coats, the ornaments
and the garden already make.

**AND `Crates.luau` WAS KEEPING ITS OWN COPY OF THE LADDER, WHICH IS EXACTLY
WHAT `Config.RARITY_ORDER` WAS EXTRACTED TO STOP.** It carried a literal
`{ "common", "rare", "epic", "legendary" }` and built one combine chip per
entry, so every crate in the game grew an EPIC row that could never fill --
a control that does nothing when pressed, which that file's own comment calls
worse than an absent one, two hundred lines above the code that did it. The
chips are derived from the chest's own stocked pool now, so a skin crate
shows two, a tier crate shows one, and the Alien Cache correctly still shows
rare and epic. **THE SECOND COPY OF A GRAMMAR IS ALWAYS THE ONE THAT GOES
STALE**, and this one went stale within the hour of the tier count changing.

**WHAT IS DELIBERATELY LEFT AT FOUR TIERS.** `Config.RARITIES`,
`RARITY_ORDER` and `RARITY_BANDS` are untouched: houses, decorations, rides,
dog coats, kennels, toys and trophies are all PRICED, they all sit in those
bands today, and re-tiering them would move borders on about sixty items to
solve a problem only the skins had. The Martian stays Epic for the same
reason -- it is an alien-set skin in a mixed-kind chest whose odds run
rare/epic/legendary across a decoration, an effect, a skin and a ride.

**AND THE ANIMAL SHELF'S TWO LEGENDARIES DO NOT MEET THE BRIEF ABOVE, WHICH
IS RECORDED RATHER THAN PAPERED OVER.** A legendary is meant to carry
geometry, an animation and a glow; the Bengal Tiger and the Snow Leopard
carry a coat and a pattern. They hold the top of that shelf because a crate
with no top end is a crate nobody opens twice -- the same argument that keeps
effects out of a chest entirely. The four Blender creatures waiting on an
upload (dragon, phoenix, rainbowtiger, stormwolf) are what that tier is
actually for, and the shelf is honest again the day they land.

**THREE OF A TIER, NOT TWO, AND THE ARITHMETIC DECIDED IT.** The proposal was
two commons for a 97% shot at a rare. Two compounds to about EIGHT commons for
a legendary -- roughly eleven chests -- which makes the top tier something a
player manufactures rather than something they get, and drains the one moment
the chest exists to produce. At three it is twenty-seven, and the two routes to
a legendary cost about the same: 25 opens rolling for one directly, 25 opens
gathering three epics and combining. **That balance is the property to
preserve**, not the specific numbers -- if combining ever gets much cheaper than
rolling, nobody rolls for the top tier and a chest becomes a common dispenser.

**THAT REASONING IS INTACT AND THE NUMBER IS NOT, because it was solved
against four tiers.** Skins are three now, the rung below legendary went from
12% to 44%, and `need` had to absorb it -- it is 5, re-derived from the same
odds in the tier entry above.

**AND THE SKIP CHANCE IS SIZED TO BE SEEN.** 97% is an exchange rate rather than
a gamble: all of its tension sits in a 3% window most players never meet once.
At 15% across two tiers, a child who combines ten times has probably jumped one
and will tell somebody about it. That is the whole reason the mechanic is there.

**TWO CURRENCIES, AND THE ARROW ONLY POINTS ONE WAY.** Coins buy the standing
catalogue -- `og` and `animal` today, which were `classics`, `animal` and
`neon` until the collections pass folded Neon Nights into the first. Tokens buy EVENT chests, and no amount of coins reaches one: you were on
the street when the saucer came or you were not. **Spares combine only into
COIN chests**, which is the rule that keeps that true in the other direction --
a rich player could otherwise grind coin chests and combine their way into the
alien set without ever attending an event. Duplicates from an event chest are
still real spares, sellable and combinable like any other, which is a small
thank-you for turning up; the arrow just does not run back.

**A DUPLICATE IS A SPARE COPY OF THE ITEM NOW, NOT A SHARD OF ITS TIER
(schema 18), and this replaces a rule this file stated as load-bearing.** It
read: *"shards are global per tier, not per chest, and that is what answers
the question a chest system otherwise cannot -- what does a chest give you
once you own everything in it?"* That answer is still the right one and the
abstraction it was carried in was not. A shard of "epic" is a token with a
number beside it; a second Bubblegum is a thing a nine-year-old can look at
and decide about.

**WHAT KEEPS THE OLD ANSWER IS THAT COMBINING STILL POOLS BY TIER.** Three
spares of ANY commons make one rare roll, so a spare out of a finished
collection is still fuel for one barely started and no open is ever wasted --
`Config.COMBINE` did not move. Per-ITEM combining was the version to avoid: it
needs three of one thing, which strands most duplicates and puts back the dead
outcome the whole design exists to remove.

**AND WHAT MAKES THE PER-ITEM SHAPE WORTH IT IS SELLING.** A spare that can
never be combined is still worth coins, so the "never a dead outcome" rule
survives the move -- and the player gets a decision the shard version could
not offer: take the coins now, or hold it for a combine. The word SHARD leaves
the player's vocabulary entirely; there is no second noun to teach, because
the thing being combined is the skins they can see.

**A TIER LADDER ALONE IS A MONEY PRINTER, AND IT WAS MEASURED RATHER THAN
GUESSED.** The obvious rule is a value per tier off the drop weights that
already exist -- 100/42/15/4 inverts to a ready-made 1 : 2.4 : 6.7 : 25 -- and
it covers the whole catalogue, which matters because seventeen skins and all
twelve accessories carry no `cost` at all and a fraction-of-price rule could
never have priced them. But RARITY IS DERIVED FROM PRICE for anything that
has one, and the bands are wide: Bubblegum is a common at 8,000 coins, so a
flat common value of 40,000 means buying it in the shop and selling it
straight back returns FIVE TIMES the money, forever, with no chest anywhere in
it. The tier says what something is worth in general; the price says what THIS
one is worth, and where they disagree the price has to win or the shop pays
players to shop.

So `Config.sellValue` is the tier value capped at `SELL.priceFraction` of the
item's own cost. Measured live: Bubblegum 8,000 -> sells 2,000, Lava 200,000 ->
50,000 (the cap biting on a rare worth 95,238), Pearl 1.2M -> 266,666 (the tier
winning, since the cap would allow 300,000), Hyperdrive 14M -> 1,000,000.
Across all four coin chests an open that lands a duplicate returns 21% to 35%
of what the chest cost: always a real loss, never nothing.

**THE DRESS-UP CRATE IS THE ONE TO WATCH at 35%, and the reason is structural
rather than a tuning slip** -- no accessory carries a coin price, so nothing
caps, and it is the cheapest chest at 350,000. Price an accessory and it comes
down on its own.

**A FREE THING MAY NEVER BE SOLD, and `Config.isSellable` is the same
three-source test `isSkinUnlocked` already makes, from the other end.** "No
cost" does not mean free -- a drop-pool skin, an accessory and a set item are
all unpriced because they are not bought with coins at all. What IS free is
the costless-and-untagged class, the "none" effect everybody owns from their
first second, and selling one of those for a tier value is a coin faucet with
no source: the exact `(nil or 0) <= 0` hole that once unlocked the Tractor
Beam for the whole server. Nothing free is in a chest today, so this guards a
door nobody can currently reach -- written anyway because the failure is
silent, and tagging a costless skin into a chest would mint coins with nothing
in the log to say so.

**YOU MAY SELL YOUR LAST COPY, AND THE GUARD IS THE ACCIDENT RATHER THAN THE
EXPLOIT.** There is no sell-and-rebuy loop to close, because the cap above
makes selling always a loss -- so the objection to a last-copy sale was never
the arithmetic. It is a nine-year-old with a stray thumb and the legendary
they spent three weeks getting. So the copy IN USE cannot be sold:
`SetService.inUse` asks the five equip sites, taking it off first is one tap,
and that kills exactly the accidental case with no lock flag anybody has to be
taught. `SetService.revoke` is then the exact inverse of `grant` -- it pushes
the item's own service AND the set panel, which are two different questions,
and saves on the spot.

**A SALE THAT WOULD OVERFLOW THE PIG IS REFUSED, NEVER CLAMPED, AND NEVER
PARTIALLY FILLED.** The pig is the wallet and it is BOUNDED, so a payout that
does not fit has two possible endings and only one is honest. Clamping quietly
destroys coins the player has just earned, which from their side is
indistinguishable from theft -- they pressed sell, the item went, and the money
did not arrive. It is the silent-failure rule wearing a button. Selling four
spares and being handed two is the same clamp one level up, so the order is
whole or nothing.

It is also the "spend it or lose it" loop this economy already runs on,
arriving from a new direction: a full pig stops earning until you spend some,
and now it stops selling too. Two refusals, because a full pig and a nearly
full one want different sentences -- measured live: *"Your piggy bank is full.
Spend some coins before you sell."* and *"That is worth 1.0M and your piggy
bank only has room for 88.2K. Spend some coins first."* The spare is not
consumed either time.

**THE SCHEMA CHANGE WAS DONE BEFORE THE UI, AND THAT TIMING IS THE WHOLE
REASON IT COST NOTHING.** `shards` is per tier and `spares` is per item, and
nothing maps between them -- a tier counter cannot say which item it came
from. With no chest UI anywhere, the only shards that had ever existed came
out of the admin console, so reconcile DROPS the field and nobody loses
anything. The same change after the tab ships needs a real payout, and a
payout that runs on every join is a money printer: a far worse bug than the
one being fixed. Anything else still carrying a placeholder shape wants moving
on the same argument, while it is still free.

**SPARES ARE KEYED `kind:key`, REUSING THE GRAMMAR `splitEntry` ALREADY
OWNS.** Measured: 92 keys across the five catalogues and zero collisions
today. That is exactly the sort of fact that stops being true without anything
erroring -- the day a `martian` skin meets a `martian` accessory, two spare
counts merge and the save is wrong with nothing in the log. The same lesson
`RideSound` learned by keeping a second copy of the ride-key grammar and
breaking within the hour.

**AN AUTO-PICKED COMBINE CONSUMES THE CHEAPEST SPARES FIRST.** Every spare at
a tier combines identically, so the choice cannot affect the roll -- which
means the only thing it CAN affect is what is left behind, and the honest
default is to leave the valuable ones. The client may still name its own
three; `validatePick` rebuilds that list from known-good parts as a multiset,
so three of one key needs three of them and anything else refuses the WHOLE
combine rather than dropping an entry and quietly consuming two. Note the
values are computed into a map before the sort rather than inside the
comparator: `table.sort` throws on an inconsistent order function, and one
that recomputes per comparison is one edit away from being one.

**ONE COIN FORMATTER, IN CONFIG, because there were two and a third was about
to be written.** `EconomyService.format` and ClientMain's own `format` were
byte-identical ladders over the same suffixes, and the sell refusal needed one
on a service that can require neither. Config requires nothing and both ends
already read it, so it is the only home where another copy is not the cheaper
option. Both callers now delegate, and ClientMain still spends exactly one
local on it.

**A SKIN IS CRATE-ONLY NOW, WHICH DELIBERATELY REVERSES "NOTHING IS EVER
LOCKED BEHIND LUCK".** That rule is written twice in this file -- once under
the accessory roll, once under the alien set -- and it reads *"every set item
carries a medal price, so a drop only ever saves you time... bad luck still
only ever costs time"*. It was the right rule for a spinner sitting beside a
shop, and it is being traded away ON PURPOSE for the crate economy: the buy
button comes off skins entirely, and opening, combining and selling are the
only routes to one.

It was decided with the cost stated rather than as a side effect, and the
cost is exactly this: a nine-year-old who wants the Pearl skin can no longer
save up for it. They can roll for it, or gather three epics and combine.
That is the trade, and if it turns out to be the wrong one the lever is a
buy button in the pool browser -- the prices never left `Config`, for the
two reasons below.

**THE PRICES STAY WHATEVER HAPPENS TO THE BUY BUTTON, and that is not
sentiment, it is two load-bearing derivations.** `Config.rarityOf` reads a
skin's `cost` to decide its TIER, and `Config.sellValue` caps a payout at
`SELL.priceFraction` of that same `cost`. Strip the prices and every skin
falls to `common`, the crate ladder collapses to one tier, and the sell cap
comes off -- which is precisely the money printer measured last session,
where a flat common value of 40,000 paid five times Bubblegum's own shop
price forever. A price here is a rarity and a ceiling first and a purchase
third.

**WHAT IT DOES NOT CHANGE IS THE LEGAL POSITION, and that is worth being
exact about because it looks like it should.** Coins are still not
purchasable with Robux, so a crate is still an ordinary in-game reward for
in-game money rather than a regulated paid random item -- no odds
disclosure, no `PolicyService` gate, no regional lockouts. What it DOES do is
make that rule carry more weight than it did: break it now and it is not
merely the chests that become loot boxes, it is the entire skin catalogue
becoming luck-gated behind purchasable currency. The "can only ever be broken
once" entry above now guards a bigger surface.

**EFFECTS ARE THE EXCEPTION AND IT IS ARITHMETIC, NOT A HALF-FINISHED
JOB.** There is no effects chest and one cannot be built yet: measured, the
five buyable effects are Sparkles 15K, Embers 40K, Frost 90K, Storm 220K and
Inferno 600K, and against `RARITY_BANDS` (rare at 100K, epic at 1M,
legendary at 10M) that is THREE COMMONS AND TWO RARES. No epic, no
legendary, no top end -- and the top end is the entire reason a crate is
opened. What this concluded -- that effects keep their buy button until
somebody authors effects at 1M and 10M -- WAS TRUE AND IS NOT: the button
went with the Piggy tab, and the entry below records what that cost. The
arithmetic is untouched and is still the reason there is no chest, and the
note in `Config.CHESTS` saying more effects would not fix it is still right:
it is the PRICE SPREAD that is missing rather than the count.

**THE PIGGY TAB IS GONE, AND EFFECTS ARE UNOBTAINABLE UNTIL A CRATE EXISTS
FOR THEM. THAT WAS DECIDED WITH THE COST ON THE TABLE, NOT MISSED.**

That tab held exactly two sections. PIGGY SKINS had already stopped being a
shop -- 41 of the 46 carried a `chest` tag and the card read FROM CRATES
rather than a price -- so a shelf of them was a catalogue you could look at
and not buy from, which the Crates tab and the bag between them already do
better. EFFECTS went with it, and there is no effects chest to catch them.

**AN EMPTY TAB IS NOT AN OPTION**, which is why the tab went rather than
being left holding one section: a rail slot that opens a blank page reads as
a shop that failed to load. Six front-page shelves became four; the grid is
centred down the page rather than resized, because six cards in a nine-cell
grid leave the empty third at the BOTTOM, which is exactly where a row that
failed to render would be.

**AND IT TOOK THE LOOT-PRICED ROUTE TO TWO ALIEN SET ITEMS WITH IT, WHICH IS
THE HALF THAT WAS NOT OBVIOUS.** `LootBuy` was only ever reachable from a
skin card or an effect card -- `cosmeticInfo` answered for those two kinds
and no others -- so the Martian and the Tractor Beam are Alien Cache drops
now and nothing else, while the Crashed Drone and the Hoverdisc keep their
loot prices on the Home and Rides tabs. That is *"nothing is ever locked
behind luck"* half-broken on one set: two items guaranteed, two gambled. The
server half is untouched, so putting a price back is one call site rather
than a feature.

**THE SHOP DOOR THAT OPENED THAT TAB WOULD HAVE BECOME A DEAD DOOR**, and
the loud warning this file already records for `BY_TAB` is what caught it --
`Config.SHOPS` keys a unit's style, fascia and window display off `tab`, so
PIGGY OUTFITTERS is `piggy` over there and has to stay `piggy`. What moved is
where its door LANDS: the Crates tab, because it sold skins and skins come
out of crates. **A TAB IS AN INTERFACE WITH FOUR THINGS POINTING AT IT** --
the rail, the front page, the section jump and a building on the street --
and only one of them says so in code you would think to grep.

**MEASURED BEFORE ANY OF IT WAS TOUCHED, which is what caught the effects
problem.** Walking the three catalogues against their `chest` tags: skins 41
of 46 tagged, and the five that are not were never coin purchases anyway --
`classic` is free, `bronze`/`goldleaf`/`diamond` are rebirth drops carrying
`unlockRebirths`, and `martian` is an alien set item priced in loot. (THOSE
FIGURES ARE THE ONES THIS MEASUREMENT WAS TAKEN AT. It is 36 of 44 across two
shelves now -- see the three-tier entry above -- and the METHOD is what this
entry is for rather than the count.)
Accessories 12 of 14, the two missing being the alien pair. Effects **0 of
7**. Pulling the buy button off skins costs nothing; pulling it off effects
would have made them unobtainable, and nothing would have errored.

**THE INVENTORY IS THE OTHER HALF OF THE CRATES TAB, AND THE SPLIT IS BY
VERB.** `Crates` is how you GET a cosmetic; `Shared/Inventory.luau` is what
you HAVE. They were one surface for the life of the project, which worked
while a card answered ONE question -- do you own this, and if not what does
it cost. Schema 18 gave every item a spare count and two exits that are not
purchases, and a tile carrying a price, an equip toggle, a spare count AND a
sell button is four verbs on 156 pixels.

**SO THE INVENTORY NEVER SHOWS A PRICE, and that is the property to
preserve.** The moment it does it is the shop again and the reason for two
tabs has gone.

**AND IT ONLY EVER SHOWS THINGS YOU OWN.** A locked tile in an inventory is
a shop card wearing a padlock -- this file already argues that the shop is
where something you do not own is supposed to be advertised, for ride
stances and for Most Wanted gear. An empty section names the way to get one
instead, which matters because on a new save all five are empty at once.

**`ChestState.spares` IS A RECORD PER ITEM, NOT A COUNT, and assuming
otherwise threw on the first push.** It carries `{kind, key, name, count,
tier, value, inUse}` -- so the coin value and the in-use test are the
SERVER'S, computed by the same code that will charge and refuse. Re-deriving
either on the client is two implementations of one number and one of them is
money. Note an item with NO spare has no entry at all, which is exactly the
state a last-copy sale runs in, so nothing may assume a record exists.

**THE SPARE CHIP SHOWS TOTAL COPIES, NOT SPARES.** One spare is `x2`,
because "I have two of these" is what a nine-year-old reads off it; a chip
saying `x1` beside an item they hold two of is the kind of off-by-one nobody
reports -- they just stop trusting the number.

**THE LAST-COPY GUARD IS ABOUT THE COPY IN USE, NEVER ABOUT THE LAST ONE.**
Verified live on the one case that isolates it: a ride can never have a
spare, so equipping the BMX flipped its sell control to a greyed WEARING and
unequipping restored SELL 22.5K. A worn skin WITH spares still sells,
correctly -- `cow` read `x4 / WEARING / SELL 8.8K`, because what is refused
is selling the copy off your own back, not owning a worn thing.

**SELLING REACHES RIDES AND DECORATIONS, AND THAT IS AN UNINTENDED REACH
RATHER THAN A DECISION.** `Config.isSellable` admits anything with a
`cost > 0`, so a 90,000-coin BMX shows SELL 22.5K -- a 75% loss on a
purchase that can never produce a spare, because rides are in no crate. The
cap means there is no exploit, and the wearing guard catches the likeliest
accident. It is recorded rather than fixed because the rule the player was
given is "you may sell your last copy", and quietly exempting the expensive
half of the catalogue would be a different rule. If it should be narrowed,
the honest test is whether the thing can appear in a chest at all.

**IT IS NOT A SHOP TAB, AND IT WAS ONE FOR ABOUT AN HOUR.** That was wrong
twice over and the second reason is the one worth keeping. A shop tab is a
place you go to SPEND; the inventory is where you go to look at what you
already have. Putting it behind the SHOP button says the opposite of what
the whole Crates/Inventory split was for -- and the split is the entire
argument for building it at all.

It was ALSO the ninth tab, which overflowed the rail by about 26 pixels:
eight tabs measure 692 in a 772 window and "Inventory" wants about 98 more.
Not the old bug -- the rail scrolls, so nothing was EATEN -- but the gentler
version this file already calls the nastier one, where the thing exists, works,
is one scroll away, and a nine-year-old never learns it is there. THE
GEOMETRY WAS THE SYMPTOM AND THE VERB WAS THE CAUSE: moving it out of the
shop fixed both at once, and the rail is back to eight at a rightmost edge of
885 against 961.

**IT IS ITS OWN HUD BUTTON, BESIDE SHOP, AND THAT CORNER WAS THE ONLY ONE
WITH ROOM.** Bottom-right went from 210x172 to 210x50 when EARN moved into
the Upgrades tab, and the frame is `AutomaticSize.Y` anchored to the corner
-- so a second row grows it UPWARD and the shop button does not move, which
matters because it is the control players already know the position of. The
bag takes `LayoutOrder` 0 so SHOP keeps the actual corner. Every other corner
is full: top-centre is a five-band column, top-right is the piggy bank panel,
top-left is the toast stack, and bottom-left is four rows deep.

**TWO FULL-SCREEN PANELS MAY NEVER BE OPEN AT ONCE, and that is not tidiness
-- it is a trap with no way out.** They are the same size in the same place,
so the loser sits invisible underneath with its close button unreachable: a
player would be looking at the shop with no way to know the bag was still
open behind it. Enforced BOTH ways and verified both ways with real pointer
clicks: opening the shop closed the bag, and clicking the bag while the shop
was open closed the shop.

**THE SHOP SIDE IS WATCHED, NEVER POKED.** The shop opens from a button, a
close X, the B key, and a shop DOOR on the street, and three of those are
defined above this block and could not call into it. Same call `Rebirth` and
the hot bar already make on that panel, and for the same reason.

**A PANEL THIS SIZE INHERITS FOUR DUTIES, and finding them was most of the
work.** `panel.Visible` is read in four places -- the hot bar's `shouldShow`
(a row of throwables a player cannot throw while reading a panel),
`heldUI.use`, `Rebirth.canShow` (the rebirth button is pinned exactly where
this panel's header sits), and the two property watchers. Anything
full-screen added later has to answer the same four, and the way to find them
is to grep for the existing panel rather than to reason about it.

**THE FLAG IS AN ATTRIBUTE ON THE ScreenGui, `BagOpen`, AND THAT IS THE
REGISTER BUDGET AGAIN.** All three of those functions are defined further
down the chunk than the panel is built, and `ClientMain` has no top-level
register spare for a boolean. An attribute costs none, is readable from
anywhere, and cannot go stale the way a second copy of the state would.

**I OPENS IT, Escape CLOSES IT, and the map was checked before the key was
taken:** Q dodge/trick, B shop, V garage, R radio, I the bag, Escape close,
F2 admin, 1-0 the hot bar. The BUTTON is the primary route -- most of this
audience is on a touchscreen and will never press a key at all.

**AND THE WHOLE TAB COST `ClientMain` ZERO TOP-LEVEL LOCALS.** The require
sits INSIDE the `do` block that owns `iconFor` and `format`, holding no local
at all -- the module keeps its own state, so three remote connections are the
entire interface. Ninth time this chunk's ceiling has shaped a decision, and
it is now cheaper to design for than to hit.

**A `Config` FIELD CAN FORWARD-REFERENCE JUST LIKE A `local`, AND IT TAKES
THE WHOLE GAME DOWN INSTEAD OF ONE FEATURE.** `Config.LAWN_LIFT =
Config.PLOT_SIZE.Y` was written beside the fence-hop reasoning at line 2262;
`Config.PLOT_SIZE` is not defined until line 3214. So it was `nil.Y`, which
throws while Config is still LOADING -- and Config is required by every
service and every client, so the server never started and no HUD was ever
built. Measured: *"attempt to index nil with 'Y'"* twice, once from `Main`
and once from `ClientMain`, and nothing else in the log.

This is the ninth forward reference recorded here and the first on a table
field. The difference that matters: a `local` read as a nil global limps on
until something calls it, so the failure lands somewhere plausible. A field
read during module load cannot limp -- it is total, immediate, and names a
line that looks fine. THE FIX IS TO DERIVE IT WHERE ITS SOURCE EXISTS: the
assignment moved down beside `PLOT_SIZE` and the REASONING stayed up with
the fences, because those are two different questions. Every reader was
already inside a function body, which is why they were fine where they were.

**IT WAS ALSO UNCOMMITTED WORK THAT HAD NEVER BEEN RUN.** `LAWN_LIFT` is not
in `HEAD`. Nothing in the pipeline could have caught it -- `rojo build`
packages Luau and never compiles it, and the file is only executed when a
server actually starts. The check that costs nothing is to press Play once
after touching `Config`, because a load-time throw in that file is never
subtle and never local.

**THE CRATES TAB IS THE BUTTON, AND FOUR HUNDRED LINES WERE WAITING BEHIND
IT.** `ChestService` had been complete and wired since it was written -- open,
roll, grant, combine, sell, four remotes, five chests -- and `ClientMain` had
not one reference to any of it. Nothing was broken; there was no button.
`Shared/Crates.luau` is it, and everything below is what building it cost.

**A CRATE'S CARD IS THE THREE BEST THINGS IN IT, NOT A PICTURE OF A CRATE.**
The instinct is a box icon per chest in the chest's own colour, and this file
already records exactly where that ends twice over: the four shops on the
street were "four identical boxes" with a different accent, and the shop's own
cards were "nineteen identical grey squares" until they rendered the real
item. A crate is a CONTAINER, so its card shows the contents, built by the
same builders the rest of the shop uses.

**BEST TIER FIRST, WHICH IS ADVERTISING AND IS ALSO HONEST.** A crate is
opened for the thing at the top of it, so leading with three commons describes
the likely outcome and sells nothing. Nothing about it claims they are likely
-- the odds bar directly under it is drawn to scale and says the opposite.

**THE ODDS ARE DRAWN, AND NOTHING REQUIRES THEM TO BE THERE.** Coins are not
purchasable, so no chest here is a regulated random item and there is no
disclosure obligation at all. It is the same argument the drop reel already
makes: being outside the regulation is not a reason to stop, it is the reason
it costs nothing to comply with the spirit of it. A stacked bar is also the
version a nine-year-old reads without reading -- THE GOLD SLIVER BEING THIN IS
THE INFORMATION -- and the percentage is printed inside a segment only at 16%
or wider, because "4%" typeset across a twelve-pixel sliver makes the bar
harder to read rather than easier.

**AND THEY ARE THE SERVER'S OWN NUMBERS.** `ChestState` carries what
`liveOdds` actually rolled with, renormalised over the tiers that have stock.
Computing them here from `Config.CHESTS[key].odds` would print a player
numbers the server did not use, which is the one way a drawn probability is
worse than none.

**ONE REEL SERVES THE EVENT DROP AND THE CHEST, and three optional fields are
the whole of what that took.** The two are genuinely different underneath -- an
event drop rolls a flat unowned pool where duplicates are impossible, a chest
rolls a TIER first and can repeat -- and identical on screen: a strip of real
items decelerating under a fixed pointer. `title`, `subtitle` and `note` each
fall back to what the event drop already printed, so that caller is untouched.
The fallback matters rather than being politeness: "N items left, X% each" is
TRUE of a flat pool and false of tiered odds, so a caller inheriting it would
print an honest-looking lie. `note` is the genuinely new beat -- the line a
chest needs and an event drop never does, "you already had this, here is what
it is worth" -- and it fades in WITH the prize, because printing it earlier
tells the player the answer before the reel has given it to them.

**THE 200-LOCAL CEILING, EIGHTH TIME, AND IT TOOK THE WHOLE HUD AGAIN.** Four
new top-level locals -- the `Crates` require, `TextService`, and a constant and
a helper for the tab width -- put the chunk at 201, and it died allocating
`buildNotifications` two thousand lines from anything that had changed. Three
of the four folded INTO `makeTab`, whose body has its own register file, and
the require stayed where it belongs beside RaidFX and SpinWheel. THE RULE IS
UNCHANGED AND IS WORTH RESTATING AS A HABIT RATHER THAN A FIX: anything that
can live inside a function body costs this chunk nothing, so put it there
first and only promote it when something else genuinely needs it.

**A TAB IS AS WIDE AS ITS OWN WORD NOW, AND THE EIGHTH TAB IS WHY.** Every tab
was a flat 102. Seven fit the 772-pixel rail and eight do not: measured, the
canvas ran to 880 with the Crates tab at x 964 against a rail ending at 962.
This is NOT the old bug -- that was a rail which did not scroll at all and ATE
two tabs silently. This is the gentler version and arguably the nastier one:
the tab exists, it works, it is one scroll away, and a nine-year-old never
learns it is there. A flat width was also spending the same 102 on "Worn" as
on "Everything", which measure 30 and 62 pixels at the shipped 13px
FredokaOne. Sized to their own labels all eight come to 692 including padding,
inside the rail with 80 to spare and room for a ninth. Note `selectTab`
re-sizes on every selection and had the 102 hardcoded a second time -- a
constant there would have undone the measurement the moment anybody pressed
anything.

**THE FRONT PAGE'S GRID WAS ALREADY 3x3 AND HAD BEEN HOLDING A CELL.** The
cell is `1/3` by `1/3`, so nine, and eight were used. The ninth card therefore
cost no height, no scroll and no arithmetic. It had to be built for the reason
the Defend / Rob card did -- a front page that is a map of the shop cannot
leave out a tab -- and crates are the worse omission of the two, because a
crate is the only thing in this shop that nothing else in the game mentions.
It goes through `SHOP.at.crates` rather than a literal index: the trees card
can hardcode 2 because Upgrades has been second since there were four tabs,
and this is the newest tab in the rail.

**`Config.chestEntry` EXISTS BECAUSE THE POOL GRAMMAR ACQUIRED A THIRD
READER.** `ChestService.splitEntry` owned "kind:key for a set chest, a bare key
otherwise" and was the only thing that needed it. The crates UI needs it to
turn a pool into a strip of previews and the admin console needs it to seat a
spare. Config is the right home for the same reason `chestPool` is: it
requires nothing, both ends read it, and the emitter and the reader of a
format belong together. It takes the chest KEY rather than the chest table,
because a chest table does not carry its own key and every caller had one.

**THE CRATES HUE IS A MEASUREMENT.** Plotted, the nine category hues sit at 6,
26, 44, 92, 148, 182, 210, 272 and 338 degrees, so the two real gaps are
indigo near 250 and magenta near 305. Indigo is wrong twice: it needs its
saturation dropped to 0.54 before ink type clears 4.5, so it cannot be a
member of this family at all, and even then it lands 16 to 24 degrees off
`effects`. Magenta at 305 keeps the family's 0.72, sits 33 degrees from BOTH
neighbours, and carries ink at 5.63 -- better than either of them manages.

**AND THE ONE THING I GOT WRONG THIS SESSION I GOT WRONG BY LOOKING.** The
screenshot appeared to show the third preview well on every card wearing a
brighter border than the first two, which would have meant the best-tier-first
sort was broken. Measured instead -- every well's stroke against the tier the
pool actually sorts to -- all five cards were correct, `classics` reading
legendary/legendary/legendary. The rendering difference was how much of each
well its model happened to fill. This file spends a lot of words on cases where
only a screenshot can be believed (CSG holes) and it is worth the counterweight:
where a number exists, the number wins.

**A TEST HARNESS THAT SETS UP THE STATE IT IS MEASURING WILL LIE TO YOU.**
`commands.spares` grants the base copy before adding spares -- deliberately,
because a spare is an EXTRA copy and handing one out without the base copy
puts the save in a state the real code cannot produce. The read-back helper in
the probe called that same command with an amount of zero, so every read
SILENTLY RE-GRANTED the item that had just been sold, and a last-copy sale
appeared to succeed twice in a row. It looked exactly like `revoke` not
working. What caught it was the server log printing *"Spares: +0 across the
coin chests, 1 items granted"* between the two sales -- the granted count, not
the spare count. Re-run without the helper, the second sale was refused
silently, which is correct. Read state through a channel that does not also
WRITE it.

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

**THE PIGGY IS OPAQUE NOW, AND THE VAULT HATCH IS HOW YOU READ IT. THAT
REVERSES THE ONE REASON EVERY SKIN CARRIED A `transparency`.** All 46 skins
sat at 0.22 to 0.42 for a single purpose: the coin pile lives INSIDE the pig
and had to show through it. Photographed side by side at the same fill, that
was a bad trade in both directions -- the coins read as dark smears rather
than as gold, the snout stopped reading as part of the face, and a neon house
on the far side of the street showed straight through the pig. The signal the
transparency existed to carry was barely arriving.

**WHAT PAID FOR IT IS THAT THE PIG STOPPED BEING SOLID.** The vault hatch and
the coin slit are genuine bores now rather than dark discs with a lip round
them, and **THE GENERATED SHELL TURNS OUT TO BE A TRUE HOLLOW MANIFOLD** --
which was the thing worth measuring rather than assuming. Roblox culls
backfaces, so the expectation was that a through-cut in an opaque body would
read as a WINDOW: you look in the hatch and see the world out the far side. It
does not. The shell has an inner surface with its normals pointing into the
cavity, so through the hatch you see the pig's own inner wall, correctly lit,
with the pile at the bottom of it. **NO LINER WAS NEEDED, AND ONE WOULD NOT
HAVE WORKED ANYWAY** -- a convex part placed inside a cavity shows its NEAR
face, so it plugs the hole rather than lining it, and there is no arrangement
of primitives that lines a concave interior.

**SO THE PILE HAD TO COME DOWN THE PIG.** It sat ABOVE the body's centre, on
the old and correct argument that the snout hid the lower third from a viewer
at the front. Seen through a hatch centred at `DIAL_Y` that put it in the TOP
of the aperture, hanging in mid-air like coins suspended in a jar. It fills
from the belly now, so the surface rises PAST the opening as the pig fills,
and the level is the readout.

**DENSER BY COIN SIZE, NEVER BY COIN COUNT, AND THAT IS THE ONE COUPLING HERE
THAT IS NOT FREE.** Thirty-two discs in an eight-stud volume read as a scatter
rather than as money, and the obvious fix is more of them. `Config.COIN_COUNT`
is not a density dial: it is the DRIP CADENCE, tuned so a coin lands about
every fifteen seconds at every level, with its own comment calling that a
heartbeat and `playCoinDrop`'s comment warning that anything louder becomes
nagging. Doubling the count to fill the hatch would have doubled the chime
rate as an invisible side effect -- two curves multiplied without anybody
checking the product, the shape this file keeps recording. Bigger discs in a
smaller volume buy the identical picture and touch no cadence at all.

**WHAT THE HATCH CAN AND CANNOT SAY, MEASURED.** The volume spans y 3.65 to
11.35 against an aperture of roughly 4.6 to 8.6, so the level reads from about
4% full to about 71% and reads as PACKED above that. The top of the range is
carried by `glow` instead, which stopped being a glow THROUGH the shell and
became light spilling OUT of the hatch and the slit -- the better of the two
signals, and free.

**WHAT THIS COSTS, STATED PLAINLY: THE FILL IS NO LONGER READABLE FROM THE
FRONT.** *The coin pile on the lawn has always shown how full a piggy is* is
written twice in this file, and the drain during a crack is described here as
"the greed bar drawn in the world rather than only on their screen". That
picture now needs a thief to walk round the back. It is affordable because the
two things built since -- the rob badge printing the figure in gold over every
piggy, and the steal prompt quoting the take -- are both more precise than a
translucent body ever was, and both read from the pavement. If it turns out to
matter, the lever is the hatch's own `radius`, not the transparency.

**AND THE NEON SKINS GOT BRIGHTER, WHICH WAS THE RISK WORTH CHECKING.**
Transparency was quietly dimming twenty-two Neon bodies by up to 0.42, and
this file's own rule is that a pale Neon on a twelve-stud sphere is a white
hole rather than a glowing pig. Measured the whole bucket by luminance and
photographed the worst -- Supernova at 0.900, well clear of the next at 0.774
-- opaque and under the shipped BloomEffect: it glows, it bleeds onto the
grass, and the silhouette, legs and ears all still read. No blowout. Anything
added to that bucket brighter than Supernova is the one to re-shoot.

**`SubtractAsync` BREAKS A MESHPART'S RENDERING, AND THAT RETIRES THE REAL
BORE THIS FILE ARGUES FOR TWICE.** Reported as *"the pig is not rendering at
certain angles, it disappears and the coins inside are only showing"*, which
is a literal description: from a camera directly behind a piggy at about
twenty studs the body was NOT DRAWN AT ALL -- ears, tail, coin pile and the
houses across the street, straight through where the animal should be.

**EVERY INNOCENT SUSPECT WAS CLEARED BEFORE THE GUILTY ONE WAS FOUND, and
the order is the useful part.** At the failing camera the body reads
`Transparency` 0 and `LocalTransparencyModifier` 0; painting it PURE RED
draws nothing, which is what rules out "it is there and I am misreading the
picture"; `RenderFidelity` changes nothing as a property write OR as the
`SubtractAsync` argument; `DoubleSided` changes nothing; the character is 98
studs away, so no occlusion or Invisicam pass is involved; and `Size`,
`MeshSize` and `PivotOffset` all agree, so it is not the bounding-volume
mismatch that would have been the tidy explanation.

**WHAT SETTLED IT IS THE UNCUT MESH.** A raw `CreateMeshPartAsync` body --
same id, same `Size`, same fidelity, seated at the identical CFrame -- renders
perfectly from that camera. Then one cutter at a time: the through-bore alone
fails, a BLIND recess that never breaks the shell wall fails, and the coin
slit alone -- a 0.55 by 3.00 box, the smallest cut in the file -- fails too.
**So it is not the size of the opening and it is not the shell being opened.
ANY SUBTRACT ON THIS MESH BREAKS IT.**

That leaves nothing to tune, so the openings are DRAWN again: a near-black
disc for the vault hatch, and the coin slot as a bar sunk into the groove the
generator already sculpted down the spine. Both parts were still being built
and then destroyed by `swapToMesh`, so the change is a word: the rim is still
destroyed (twelve FLAT segments can only lie true on a sphere, and the
surface swings 0.72 studs around their own ring), and the disc is kept and
pushed out by the 0.174 the mesh's back stands proud of the 6.00 sphere the
dial is solved on.

**WHAT IT COSTS, STATED PLAINLY: THE HATCH IS NO LONGER A WINDOW ONTO THE
PILE.** The entry above this one spends several paragraphs on the bore being
a true hole through a true hollow manifold, on the pile coming down the pig
so its surface rises past the aperture, and on the fill reading from about 4%
to about 71% through the opening. All of that was correct and none of it
survives, because it was bought with a mesh that does not draw. A piggy bank
that is on screen beats a piggy bank you can see inside.

**THE FAILURE SHAPE IS THE `RenderFidelity` FAMILY WITH THE ENVIRONMENTS
SWAPPED.** Those entries are about an API that throws from a real Script and
passes in a sandbox. This one never throws anywhere: `SubtractAsync` returns
a MeshPart, reports the right `Size`, the right `MeshSize` and the right
fidelity, and is broken. Nothing in any log, nothing in any probe, and every
geometric measurement agrees with the version that works. **ONLY A PICTURE
COULD SAY SO** -- which is the rule this file already writes for CSG holes,
arriving on the object the CSG was cut into.

**AND THE PICTURE NEEDED THE CAMERA, WHICH THIS FILE SAYS CANNOT BE AIMED IN
PLAY. IT CAN.** The entry under `screen_capture` has now been wrong in three
directions and this is the correction: the tool's own `camera_position` and
`look_at_position` arguments are ignored during Play, and that is all that is
true. `workspace.CurrentCamera` on the CLIENT datamodel takes a
`CameraType.Scriptable` and a CFrame perfectly well -- **provided the write is
HELD on `RenderStepped`**, because the camera module overwrites a one-shot
write on the next frame, which is what the "writes do not stick" note was
really describing. Fifteen aimed shots this session, every one framing what
was asked for, and the bug above is not findable any other way.

---

**THE VAULT OPENING IS DERIVED FROM THE SMALLEST DOOR, NOT THE LARGEST, AND
IT WAS SIZED AGAINST EXACTLY ONE OF FOUR TIERS.** Reported as *"locks are not
covering the pig hole all the way"*, and the arithmetic says so without
looking: the opening was `DIAL_MAX_R` at 1.95 against plates laddering 1.55 /
1.68 / 1.82 / 1.95, so the iron door left FOUR TENTHS OF A STUD of bare black
showing all the way round it and only the gold one fitted its own frame.

The comment defending it -- *"clears the largest tier's plate by 0.15, so a
gold-locked piggy is a door sitting IN a hole rather than a disc covering
one"* -- is a true sentence about the top of a ladder, written as though the
ladder had one rung. Same family as the Bigger Sack rungs silently refunded
by `LOSS_CAP`: a number solved at one end of a range and left to be wrong at
the other, with nothing erroring.

`VAULT_R` is `LOCK_TIERS[1].radius - VAULT_COVER` now, so every tier overlaps
by at least 0.12 by construction. What that buys back is better than what it
cost: the plates still ladder, so the FLANGE grows with the tier -- iron is a
bare lid in its frame and gold is a heavy door with a wide rim, which is one
more thing the metal says from the street.

**AND THE LADDER HAD TO MOVE UP THE FILE TO SAY IT.** `LOCK_TIERS` sat four
hundred lines BELOW `buildLock`, which is fine while nothing above reads it
and a nil global the moment something does. Tenth instance.

---

**THE GENERATED BODY HAS A HOLE IN THE TOP OF ITS BACK, AND IT IS A
SEGMENTATION SCAR.** Reported as *"an extra little hole in the top in back"*:
an octagon about a stud across, on the centre line, that you can see the coin
pile through. Proved to be the ASSET rather than the cut by standing a raw
uncut body beside a built one and photographing both -- the uncut mesh has it
too, which is also what first pointed at the subtract being innocent of THIS
one and guilty of the other.

`Config.PIGGY_MESH` asks for `segmentation: "explicit"`, which hands back the
body, ears, snout and tail as separate MeshParts -- so the body is left with a
socket wherever a piece came off. The ears and the snout are seated back over
theirs. The TAIL is not: it is authored at y 9.70 and its socket is at 11.45.

**SEATING THE TAIL IN THE SOCKET WAS TRIED AND IS WORSE.** It is a flat hook
0.47 thick against an opening 1.05 across, so it plugs the middle and leaves
gold showing all round it -- photographed, and it reads as a tail growing out
of a wound. The socket wants a cap and the tail wants to stay where it looks
like a tail.

**A BIG BALL SUNK DEEP BEATS A SMALL ONE SET SHALLOW, because what shows is
the SEAM.** Both land their crown 0.03 proud at the centre; across the
socket's 0.525 rim a 0.78 ball drops 0.16 below the skin and a 1.50 one drops
0.06. Bigger is flatter, and it is buried far enough inside the shell
everywhere else that it cannot break out -- the body curves in about 0.19 over
that span and the cap sits a stud and a half under it.

**AND THE POSITION WAS FOUND BY PHOTOGRAPHING A MARKER, which is the cheap
technique for anything a query cannot see.** Estimated off one capture by
photogrammetry, then a bright ball placed at the estimate and re-shot: it
landed dead centre. There is no geometric query in this engine that can find
a hole in a mesh -- rays hit the collision hull and bounds do not move -- so
the marker IS the measurement.

**AND THE ENTRY ABOVE IS HALF RIGHT, WHICH IS WHY THE HOLE WAS STILL THERE.
A MARKER IN A HOLE PROVES WHERE, NEVER HOW DEEP.** Reported again, as *"remove
that hole and fill it in, it should not be there"* -- and looked at, it was
still plainly a hole with something sitting at the bottom of it.

The marker test is sound and it answers ONE of the two questions. A hole FRAMES
whatever is behind it at ANY depth, so a ball that appears dead centre in the
opening has proved its position across the surface and has said nothing at all
about how far down it is. Confirmed the same way this time, from the other end:
a cap painted bright red filled the octagon edge to edge with no spill -- at a
depth that was half a stud wrong.

**THE DEPTH CAME FROM AN ELLIPSOID FITTED TO THE BOUNDING BOX, AND A PIG'S
RUMP IS FULLER THAN ITS OWN BOUNDING ELLIPSOID.** That is the actual fault.
The socket was seated against `Body.Size`, which is a box, and the paragraph
above computing crowns "0.03 proud" and rims "0.06 below the skin" is
arithmetic against a surface the animal is not on. **MEASURED: the real skin
stands 0.55 studs OUTSIDE the fit at the socket**, so the cap sat half a stud
down a shaft and the shaft is what everybody was looking at.

**MEASURED WITH A COLOUR-CODED LADDER OF MARKERS ALONG THE NORMAL,
PHOTOGRAPHED EDGE-ON.** Six neon balls at known depths, just outside the
hole's own rim so the skin has something to hide them in: at 0.85 studs across
the back, 0.35 was buried and 0.45 stood clear; at 1.05 across, 0.35 was only
just breaking out. Two points fit the offset AND the curvature. That is the
generalisation of the single-marker trick and it costs one extra capture:
**one marker finds a position, a LADDER of them finds a surface.**

**IT ALSO SAID THE RUMP IS THREE TIMES MORE CURVED THAN THE BOX CLAIMS** --
local radius about 1.67 against the 5.6 the bounding ellipsoid gives -- which
was the second thing the old seating had wrong and is not a detail. A cap
FLATTER than the skin it fills never dives back in, so it washes a lobe across
the rump; one SHARPER than the skin dives back a hair past the rim and reads
as a knob with a shadow under it. Photographed across the range: 1.4 is the
knob, 3.0 and up is the lobe, 2.0 fills the opening and fades out just past
it. The radius is a consequence of the curvature, not a taste call.

**AND THE NORMAL IS ASKED OF THE BODY NOW RATHER THAN PINNED.** It was a
hardcoded vector solved against one particular mesh. Reading the part's own
`Size` means a regenerated body carries the cap with it -- and the failure
shapes are usefully different, which is the argument for splitting them: a
wrong `lift` is a visible hole and somebody reports it, where a stale normal
is a cap sliding off the side of the animal.

**WHAT IS NOT FIXED, STATED PLAINLY: THE OCTAGON IS IN THE ASSET, AND THE
RESIDUAL IS SHADING RATHER THAN SHAPE.** The socket is a genuine through-hole
-- proved by standing a neon ball inside the body and watching it show through
-- so a cap can fill it and can never un-cut it.

**THE GEOMETRY WAS TAKEN AS FAR AS IT GOES AND IT DID NOT CLOSE THE GAP**,
which is what makes this a conclusion rather than a shrug. BOTH principal radii
of the real rump were measured with marker ladders -- 1.67 across the back and
2.03 along it -- and a cap built as an ellipsoid matching both, seated flush to
about 0.02 studs everywhere across the opening, photographs INDISTINGUISHABLE
from the plain 2.00 sphere. Moving the cap through a 0.3-stud range changes
nothing either. So the patch is visible for a reason no seating can reach: the
generated body is FACETED -- this file already records that the visible
polygons on the pig are the mesh's own -- and a Part is analytically smooth, so
the fill is a smooth surface sitting in a faceted one and shades differently
whatever shape it is given.

The cap stays the plain sphere, because the ellipsoid buys nothing and costs a
`SpecialMesh`. What is left where the hole was is a soft rounded swelling at
the base of the tail rather than an opening.

**THE TWO WAYS OUT, AND BOTH COST SOMETHING REAL.** Seating the TAIL on its own
socket hides the seam the way the ears and the snout hide theirs -- tried, and
it works, at the price of the tail riding two studs higher on the rump than the
shipped pig. Regenerating the body removes the socket outright, and the trap
there is not the upload: the socket exists BECAUSE `Config.PIGGY_MESH` asks for
`segmentation: "explicit"`, which is what returns the ears, snout and tail as
separate parts and therefore what gives this pig its TRIM COLOUR at all. Drop
segmentation and the body is one MeshPart with one `Color`, so all 46 skins
lose the second tone they are authored in -- the same argument that kept the
dogs code-built rather than meshed. **A SEAM IS A CHEAPER THING TO CARRY THAN A
ONE-COLOUR PIG.**

---

**THE VAULT HATCH HAD BEEN A BLACK STICKER SINCE THE DAY THE BORE WAS RETIRED,
AND `buildLock`'S OWN COMMENT PREDICTED IT IN ADVANCE.** Reported as *"the hole
under the tail -- remove that black marking you put there"*, and from the
pavement that is exactly what it was: a flat black disc painted on the pig's
backside, unshaded, with no lip and no depth.

The comment beside the disc has said since it was written that *"a recess is
made by standing something PROUD around the dark, never by sinking the dark --
the eye takes the highest line as the surface. SET FLUSH INSTEAD, IT IS A BLACK
STICKER."* The mesh swap destroys the rim -- correctly, because twelve flat
segments cannot lie true on a body whose surface swings 0.72 studs around their
own ring -- and destroying the rim sets the disc flush BY DEFINITION. So the
disc's own documentation described the bug, one function away, for the whole
period it shipped.

**THE RIM AND THE DISC WERE NEVER TWO DECISIONS, and treating them as two is
what produced this.** The entry that retired the bore says the change from the
version before it was "exactly one word" -- keeping the disc and dropping the
rim. That one word is the bug: the disc is only an opening WHILE the rim is
standing proud of it. **WHEN AN ILLUSION IS MADE OF TWO PARTS AND ONE OF THEM
IS DELETED, WHAT IS LEFT IS NOT A REDUCED VERSION OF IT -- IT IS A DIFFERENT
OBJECT.**

**AND THE FIRST FIX WAS TO DELETE THE OTHER HALF TOO, WHICH WAS WRONG AND WAS
CORRECTED WITHIN THE HOUR.** The disc came off, the mesh piggy was left with no
drawn opening at all, and this entry said so -- arguing that an absent opening
is honest once it has stopped being a hole. The answer to that was that the
black MARKING was the complaint and the HOLE was wanted, which are two
different objects and only sound like one. Deleting both is the bore entry's
own mistake made a second time from the other end: reaching for the surviving
half instead of asking why the deleted half had been deleted.

**AND WHEN THAT WAS FINALLY ASKED, THE RIM'S RETIREMENT RESTED ON THE SAME BAD
MEASUREMENT AS THE CAP ABOVE IT.** The comment justifying it read: twelve flat
segments "can only lie true on a SPHERE -- measured around their own ring on
this body, the surface swings 0.72 studs from one side to the other, so a third
were buried and the rest stood off the pig." Re-measured with a marker ladder
along the dial's own normal, the mesh's skin sits **0.174 studs** out from the
6.00 sphere the dial is solved on -- exactly what `MESH_DIAL_OUT` already
pushes every other piece of the dial by. The ring was being pushed by nothing
because it was being destroyed. Push it with the rest and it lies true:
photographed at two studs and at twelve, a continuous pink lip all the way
round a dark opening, no segment buried and none standing off.

So nothing on the dial is destroyed on the mesh body any more, and the fix is
the deletion of a deletion. `MESH_DIAL_OUT` was right all along, which is worth
noting beside two numbers in the same area that were not.

**THE LESSON IS THE SHAPE OF THE EVIDENCE RATHER THAN THE PIG.** Three separate
things on this one body -- the cap's depth, the rim's ring, the disc's
flatness -- were each retired or mis-seated on a number taken against a MODEL of
the body rather than the body. Every one was plausible, none errored, and each
produced a comment confidently explaining a decision that was wrong. **A
MEASUREMENT AGAINST A MODEL OF A THING IS NOT A MEASUREMENT OF THE THING**, and
on a generated mesh the only instrument that touches the real surface is a
marker photographed against it.

Verified from standing height on the lawn twelve studs back -- where somebody
who has walked round to the vault actually is: unlocked reads as an open hatch
with a lip, and a bought lock still seats over it at the CHEAPEST tier, which
is the one that had to carry it, because the opening was always smaller than
the smallest plate (`VAULT_R` is derived from `LOCK_TIERS[1]`). Clean boot,
14 of 14 piggies carrying twelve rim segments and a disc, seated identically in
body space.

---

**AND A PROBE READ WORLD AXES ON A ROW THAT CARRIES A HALF TURN, FOR THE THIRD
TIME IN THIS FILE.** The check that the caps were seated correctly measured the
offset from each body in WORLD coordinates and reported seven of fourteen
piggies wrong by 5.4 studs -- the far row, whose plot CFrame is turned through
180 degrees, so the socket that is at world -Z on one row is at +Z on the
other. The code was right and the probe was wrong, which is the same way round
as the kennel-clearance probe and the tube man. Re-run as
`body.CFrame:PointToObjectSpace(cap.Position)` it reads identical on all
fourteen to 0.0005 studs. **ASK A PART FOR THE ANSWER IN ITS OWN FRAME; a
world-space offset is only meaningful on the half of the street that happens
to be pointing the way you assumed.**

---

**A PROMPT THAT MEASURES THE WRONG BODY GIVES A CONFIDENT WRONG ANSWER, AND I
WROTE TWO IN ONE SESSION.** Worth recording because both looked like results.
A kennel-clearance probe summed each part's `Size.X/2` along plot X on a
model that now carries a quarter turn, so it measured the width of parts
whose width had become their depth. And a "where does the dog rest" probe
read the Torso's position on a LEVEL 0 dog, which has never been laid out and
is still sitting wherever `build` left it. **Measure a turned model per part
through its own CFrame, and derive a rest position from the frame it is
solved in rather than from an instance that may never have been moved there.**

---

**THE KENNEL'S DOORWAY FACED THE FRONT FENCE, AND THE COMMENT ABOVE IT SAID
IT DID NOT.** Reported as *"the dog keeps wandering outside the fence,
doghouse too close to edge of fence"*, and both halves are true for the same
reason. `GuardDog.build` is handed a CFrame precisely so the arrangement can
be turned -- its own comment says *"the whole arrangement has to be turned to
face into the plot"* -- and the call site passed no rotation at all. So
kennel-local +Z, the doorway, pointed at plot +Z, the street, and
`REST_OFFSET` put the dog 5.5 studs further that way, 7.15 at a Mastiff's
scale.

Measured: the rest spot landed at plot z 24.15 against a front fence at
`PLOT_FRONT_LINE` 25.6, so **a dog 9.9 studs long stood bodily through its
owner's fence WITHOUT MOVING**, and `DOG_PATROL_RADIUS` of 8 then took it to
z 32 -- six studs out on the pavement. Third instance of a comment asserting
a rule the code does not keep.

A quarter turn points the doorway across the lawn instead, and the rest spot
goes with it: (17.85, 16) at Mastiff scale, 9.60 studs off the front fence
against 1.45. **It reads better as well as measuring better** -- the dog now
lies BROADSIDE to the street, which is the one angle a dog's silhouette works
from and the rule every lawn ornament here already follows.

**AND THE REAL FIX IS THE CLAMP, NOT THE MOVE.** Moving the kennel makes
today's numbers safe; it does nothing about the next radius, the next
`REST_OFFSET` or the next toy somebody sites in kennel-local space.
`clampToYard` holds every patrol destination inside the FENCE rectangle --
the same one `PlotService.yardContaining` tests, so "where a dog may walk"
and "whose yard is this" cannot disagree -- inset by the dog's own half-length
scaled by the breed, because **the thing that has to stay inside is the animal
rather than the point it is aiming at**. Measured: an unclamped wander reached
z 24.00 with a 4.95-stud animal on it; clamped it stops at 20.65.

It goes at the ONE function that returns a destination rather than at the call
site, which is what makes it cover the toy visits and the walk to the bed for
free.

---

**THE MOST WANTED POSTER PRINTED OFF THE BOTTOM OF ITS OWN PAPER.** Reported
as the sign cutting off the words, and measured on the live board it is
exactly that: the sheet runs to canvas y 530 and the bounty line ran 492 to
546, so sixteen pixels of the loudest row on the board were printed on bare
timber with the canvas itself ending four pixels later. The card was
over-full as well -- 430 pixels of content in a frame declared 400 tall.

**NOTHING CLIPPED IT, WHICH IS WHY IT SURVIVED.** `Theme.card` sets no
`ClipsDescendants`, so the row simply drew outside everything it belonged to
and only the board's own edge stopped it. A layout that OVERFLOWS silently is
the same class as the tab rail that ate two tabs: no error, no warning, and
the fault only visible from the one angle anybody looks from.

The four blocks are solved against one budget now -- sheet height, less the
title band and a foot, is the card; the three text rows and their gaps take a
fixed share and the photograph takes what is left -- rather than stacked down
the page with each position typed in. Change a row and change the photograph
to match, or it walks off the paper again. Measured after: every row on the
paper, bounty ending at 518 with twelve pixels to spare.

**AND THE ROWS ARE INSET TEN A SIDE, WHICH IS A FIX RATHER THAN TIDINESS.**
With a real suspect on the board, "EATYOURBEANSBOYS" rendered 320 wide in a
330-wide box -- fitting, and touching both edges, which is the state this file
already records as `TextFits` reporting true while the glyphs sit exactly on
the frame.

---

**AND THE PIG'S OWN COIN LAMP WAS ERASING THE PIG.** The second half of "it
disappears": with the subtract fixed the body draws, and at the top of the
fill range it drew as a featureless white blob -- no eyes, no snout, no legs,
no hatch. Photographed at the same camera with one property toggled: lamp on,
white; lamp off, pink with clean shading and a crisp black hatch.

**IT IS A LIGHT INSIDE A SOLID, WHICH IS THE WHOLE PROBLEM.** `Shadows` is
false, so the shell does not block it and the pig is lit from within at
point-blank range -- the old 3.00 at range 18 also visibly washed out a
separate object 24 studs away. Turning `Shadows` on is not the escape it
looks like: it was the right answer while the hatch and the slit were real
bores for light to spill out of, and there are no bores any more.

**SOLVED AT THE SHELL RATHER THAN PICKED.** A PointLight falls off roughly as
`1 - d/range` and the body's surface is about 6 studs from its own centre, so
what the pig's own skin takes is `brightness * (1 - 6/range)`: 2.00 on the old
numbers, against a `BloomEffect` threshold of 1.1 on a body whose colour
already measures 0.73 luminance in a 2.4 sun. At 0.55 over a range of 14 it
is 0.31, which reads as warmth in the pink rather than as an exposure fault.

What it costs is the long-range tell -- a full piggy no longer lights the lawn
from across the street. The rob badge's own figure carries that now, more
precisely than a glow ever did. If it is wanted back the lever is the RANGE
and not the brightness: range reaches further without adding anything to what
the shell itself receives.

**AN A/B ACROSS TWO OBJECTS IS NOT AN A/B.** The first attempt at this put
one pig at each edge of a wide frame with different lamp settings, and the
DIMMER one looked worse -- because at FOV 70 the two sat 51 degrees off axis
in opposite directions and were catching completely different specular. Two
pigs measured byte-identical apart from the lamp and photographed as opposites.
Toggle ONE property on ONE object at ONE camera, or the picture is about
something else.

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

**DAY SEVEN IS A FREE CRATE, AND IT IS THE ONLY RUNG THAT PAYS SOMETHING
PLAYING CANNOT.** `Config.DAILY_CYCLE`'s own comment has said *"when crates
ship this becomes a KEY, and the Golden Bone moves to day six"* since it was
written. Crates shipped and nobody went back for it. Every other rung on that
ladder -- coins denominated in your own income, a boost, a couple of bones --
hands over something a player would have earned anyway by turning up and
playing for a few minutes, so **the ladder was giving nobody a reason to
return that the game did not already give them.** A crate open lands on the
PERMANENT COSMETIC TRACK, which is the one thing an hour of idling cannot buy.

`classics` rather than the dearest crate: it is the entry chest, the one a new
player recognises, and at 500,000 coins it is still a real prize on day seven
of somebody's first week. The pool is unowned-aware through `liveOdds`, so a
player who has finished it gets a spare worth selling rather than nothing.

**ONE ROLL WITH A `charge` FLAG, AND THE FREE PATH IS NOT REACHABLE FROM A
REMOTE.** A free open and a bought one differ by exactly one `if` -- the tier
roll, the pick, the duplicate test, the grant, both pushes and the reveal are
identical, and a second copy of that is the near-identical duplicate this file
keeps recording. So `roll(player, chest, charge)` is a LOCAL, with
`ChestService.open` and `.grantFree` as the two thin entry points: `ChestOpen`
forwards a chest key and nothing else, so a client cannot reach `charge =
false` however many extra arguments it fires. Same shape as every other "the
click sends no position" decision here.

**THE CLAIM IS BANKED BEFORE THE CRATE IS OPENED.** `grantFree` grants an
item, writes spares, pushes two balances and fires the reveal; running it
before the claim is saved would let a disconnect in the middle hand over a
chest the player can claim again tomorrow. Verified live through the real
path: *"Day 7: a free Piggy Classics! Opening it now."*, then a rare
`skin:candyswirl` reveal -- and coins measured 124,996 before and 125,622
after, which is income accruing during the test rather than the 500,000 a
paid open would have taken.

**AND IT NEEDED A DEV TRIGGER, OR THE ONLY WAY TO EXERCISE IT WAS TO PLAY FOR
A WEEK.** `commands.daily` winds `lastDay` back and sets the streak, then
claims through the REAL path so the rung, the payout, the streak arithmetic
and the save all run exactly as they would on a Sunday. This file's own rule:
a server command is not a dev tool until it is on the panel, so it is on the
panel.

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

**A THIEF HOLDS THE PIG NOW, AND `CarryPose` IS THE FIRST PARTIAL-BODY
ANIMATION IN THIS GAME.** `attachLoot` has welded a miniature of the victim's
own piggy to the thief's root since it was written, two studs off their chest
-- the right idea, and it is what makes a chase legible from across the
street. What was never built is the THIEF: the character went on playing the
ordinary run cycle with their arms swinging at their sides, so the pig FLOATED
in front of somebody who was visibly not holding it.

Same shape as the tiptoe and the standing event countdown, for the third time:
the mechanism was built, tuned and argued about at length, and nothing ever
DREW it. Nothing errors, which is exactly why it survives.

**IT IS UPPER BODY ONLY, BECAUSE THE LEGS ARE STILL RUNNING HOME.** An
animation drives only the joints it actually contains, so this one holds the
torso, the head and both arms and NOT the legs -- the run keeps them,
underneath, with nothing disabled and nothing to fight. Measured across a run:
`LeftUpperLeg` swinging -12.5 to +53.1 degrees while `LeftUpperArm` sat at
exactly (+16.0, -30.0, -45.0) on every single sample. Both halves at once,
which is the whole trick.

**`Pose.Weight = 0` IS HOW A POSE BECOMES A PATH RATHER THAN AN OVERRIDE, AND
NOTHING SAYS SO.** A Pose is found by walking the hierarchy, so reaching an arm
means naming `HumanoidRootPart` and `LowerTorso` on the way -- and a named pose
at the default weight of 1 OVERRIDES whatever the run was doing with that
joint. Measured: with them at 1 the pelvis froze solid, `LowerTorso` reading
(0.0, 0.0, 0.0) at y -0.79 on every sample, so the legs swung underneath a body
with no bob and no sway in it. At `Weight = 0` the identical samples read -4.1
to -11.0 degrees over y -0.699 to -0.993 -- the run's own pelvis back --
while the arms stayed pinned. **THE TWO QUESTIONS ARE SEPARABLE AND THE ANSWER
IS A PROPERTY RATHER THAN A COMPROMISE.** Anything else in this project that
wants to animate half a character wants this, and it is the only way to get it.

**AND A HUG ONLY READS IF THE ELBOWS ARE OUTSIDE THE SILHOUETTE OF WHAT IS
BEING HUGGED.** This is the finding worth keeping, because the anatomically
correct pose is the one that fails. The mini piggy is 2.2 studs across against
a torso 1.30 wide, so from the front it OCCLUDES THE ENTIRE UPPER BODY: the
first pose brought the arms in around it -- hands measured onto its flanks,
everything where it should be -- and photographed as a pig stuck to somebody's
chest with no arms visible anywhere on the character. It looked WORSE than the
floating pig it replaced, because at least that one had arms beside it.

So the shoulder ABDUCTS to put the forearm at x +-1.29, clear of the pig's 1.10
radius, and then rotates in to bring the hand back to +-1.22 onto the flank.
Elbows outside it, hands on it. Nothing about that is what a person actually
does with a heavy box, and it is what reads.

**THE HANDS CANNOT WRAP FURTHER, AND THAT IS ARITHMETIC RATHER THAN A TUNING
FLOOR.** A hand on the FAR side of a pig this size held against the chest sits
about 2.15 studs from its own shoulder, against a fully extended reach of about
2.08 -- and the pig cannot come closer, because it is already touching the
chest. There is no pose. Gripping the flanks is not a compromise on a hug, it
is what carrying something this size looks like, and knowing the number stops
the next person spending an afternoon looking for the pose that does it.

**WHERE THE PIG SITS IS DERIVED FROM THE HANDS, WHICH IS `RidePose`'S OWN RULE
ARRIVING ON A SECOND OBJECT.** MOVE THE MACHINE TO THE HAND, NEVER THE HAND TO
THE MACHINE. `CarryPose.HOLD` is exported and `HeistService` reads it, so the
placement and the pose are one measurement rather than two opinions -- and the
old `(0, 0.3, -2.1)`, which is correct for a pig nobody is holding, is
comfortably out of reach of the pose that now holds it.

**AND THE ONE NUMBER THAT WENT IN AS AN INFERENCE WAS WRONG BY A FACTOR OF
TWENTY.** Letting the pelvis move means the arms ride it and the pig does not,
so the hands must slide against a load that is holding still. The write-up said
"about a third of a stud", reasoned from how far the shoulder's own orientation
swings over a stride -- a real measurement, of something else. Sampled properly
-- the palm's position IN THE PIG'S OWN FRAME, because a distance from its
centre would report a hand sweeping round the sphere as perfectly still -- it
is 0.037 across, 0.033 up and 0.014 forward. The grip is effectively rigid and
the entire worry was misplaced. Caught before it shipped only because the
comment was checked against a probe rather than reread.

**A `do ... end` BLOCK DOES NOT BUY BACK A REGISTER; ONLY A FUNCTION BODY
DOES.** The watcher went into `ClientMain` first, scoped in a `do` block
precisely to respect the 200-local ceiling -- and the HUD died with *Out of
local registers when trying to allocate carriers*. The whole HUD, as ever,
because the chunk never compiles. A block's locals still come out of the
enclosing FUNCTION's register file, so scoping five of them changed nothing at
the peak; this file's existing advice -- put it in a function body -- is right
and the `do` block is not a cheaper version of it. It is
`require(...).start()`, one statement holding no local, which is the call
`RobBadge` already makes.

**AND FOR A WHILE THE ROBBERY COULD NOT BE DRIVEN THROUGH ITS OWN PROMPT AT
ALL, FOR A REASON THIS FILE HALF RECORDS ALREADY.** `RenderStepped` does not
fire in a Studio session whose viewport is not drawing -- measured here at
**0 times in a full second** while Heartbeat held a clean 60. The consequence
is bigger than the gadget preview that first found it: THE CAMERA MODULE RUNS
ON RenderStepped, so the camera stops following the character, and a
`ProximityPrompt` is shown against the CAMERA as well as the character -- so
`PromptShown` never fires, `InputHoldBegin` is a no-op, and NO PROMPT IN THE
GAME CAN BE EXERCISED. Measured: a character walked to 8.1 studs off a piggy
while the camera sat 68 studs away and nothing was ever shown.

**SO CHECK `RenderStepped` BEFORE CONCLUDING A PROMPT IS BROKEN.** One counter
over one second separates "this prompt is faulty" from "this session is not
rendering", and the two are indistinguishable from every other angle. It is
also the argument for the carry watcher living on Heartbeat: it went on
working perfectly through all of it, and a Heartbeat camera hold is the
fallback that still gets a capture.

**AND WHEN RENDERING CAME BACK, THE CAMERA STAYED BROKEN IN A SECOND WAY THAT
LOOKS IDENTICAL.** Rendering returned at 60/s and one real robbery went
through the real prompt first time -- walked into range, `PromptShown` and
`Triggered` both firing, the pig seating at exactly `CarryPose.HOLD`. Every
attempt after that failed, and it was not the renderer: **THE PLAYER CAMERA
HAD STUCK AT 2.3 STUDS FROM THE CHARACTER**, which is effectively first
person. Six plots in a row reported `PromptShown=false` and looked exactly
like six broken prompts.

**IT DOES NOT RECOVER FROM THE OBVIOUS WRITES.** Setting `CameraType` back to
`Custom`, reassigning `CameraSubject`, and forcing `CameraMinZoomDistance` to
14 were all applied together and it sat at 2.3 through every one. Almost
certainly self-inflicted -- a held Scriptable camera leaves the PlayerModule
somewhere it will not climb out of -- which makes it a hazard for anything in
this project that aims a camera for a capture, and this file records several.

**THE MEASUREMENT TO TAKE IS THE CAMERA-TO-CHARACTER DISTANCE, ALONGSIDE THE
PROMPT RESULT.** 12.8 studs worked and 2.3 never did, on the same prompts, on
the same plots, minutes apart. This file already says a negative from a prompt
is only evidence if the camera was where a player's would be; what is new is
that the camera can get stuck there PERSISTENTLY rather than transiently, so
"it worked a minute ago" is not the reassurance it sounds like.

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

**AND THAT ENTIRE ARGUMENT IS TRUE IN STUDIO AND FALSE ON THE SITE.**
`RegisterKeyframeSequence` IS STUDIO-ONLY: live, the call is refused, and
every reader pcalls it and degrades. So the dodge roll and every rider pose
were dead on the published game while passing every test in here -- the worst
shape a bug can have, because the environment that proves it works is the one
environment that is not the game. The sequences still get BUILT in code, which
keeps the authoring story; each one now also has to be UPLOADED ONCE and its
id put in `Config.ANIMATIONS`. `animdump` builds them all into
ReplicatedStorage for publishing.

**THE UPLOAD LIST WAS DERIVED FROM THE CATALOGUE AND HAD TO BE DERIVED FROM
THE RUNTIME, and the gap between those two shipped a live bug.**
`Config.animationKeys` walked `Config.RIDES` and emitted a style plus its
trick -- which is the set the CATALOGUE describes. What `RidePose.apply` is
handed is the PUBLISHED style, and that carries the stance: `scrambler@onehand`.
So the moment stances shipped there were EIGHT keys the runtime asks for that
nothing in the pipeline knew existed, and all three ends failed silently in the
same direction -- the startup warning could not name them, `animdump` never
built them, so none was ever uploaded.

Measured: ten base and trick animations uploaded and working, eight stance
animations with no id at all. Live, every player who picked a STYLE lost their
pose; every player who did not was fine. That is exactly the report -- "some
vehicles animate, the e-bike style is not there".

**A KEY LIST BELONGS TO WHOEVER OWNS THE KEY GRAMMAR.** `RidePose` writes the
`@` (`RidePose.key`), reads it (`splitStance`) and owns the `#` -- so
`RidePose.animationKeys()` is the list, and `Config.animationKeys(rideKeys)`
takes it as an argument rather than deriving a second copy. Config requires
nothing and must go on requiring nothing, which is the whole reason it cannot
just ask. The parameter is deliberately NOT optional: a bare call is how this
under-reported for a release, and it warns loudly now instead.

**A MISSING STANCE FALLS BACK TO THE POSE IT IS A VARIANT OF, NEVER TO
NOTHING.** `specFor` has always degraded an unknown stance to the base pose;
the ID lookup did not, and that asymmetry is what made this so much worse than
it needed to be. With no track at all the rider gets the RIG'S REST POSE, which
on a bike stands them bolt upright a foot behind their own handlebars -- so a
missing upload did not read as "my style is missing", it read as the ride being
broken. Falling back, the worst it can do is look like the ordinary pose. Note
a trick falls back to `<style>#trick` and not to the plain pose, and the
warning names the key it actually landed on: a message that says otherwise
sends the next person to the wrong row of `Config.ANIMATIONS`.

Verified by stubbing the provider to throw in a cloned module -- the exact live
condition -- and reading back what loaded: `scrambler@onehand` and
`scrambler@onehand#trick` resolved to the uploaded `scrambler` and
`scrambler#trick` ids, where the old code started zero tracks.

**ALL EIGHT ARE UPLOADED NOW, AND THE PAIRING WAS CHECKED RATHER THAN
TRUSTED.** Eight near-identically named assets published by hand is exactly
where two ids get swapped, and a swap does not error -- it is a subtly wrong
pose on one ride, which is the hardest class of bug in this file to notice.
Each id was fetched back with `KeyframeSequenceProvider:GetKeyframeSequenceAsync`
and its poses diffed against the sequence this repo builds for that key, then
against all eight candidates: every asset's BEST match was its own key, at
0.02-0.03 degrees of float round-tripping. With registration stubbed to throw,
all 18 keys now resolve to their own uploaded id and the startup warning prints
nothing. THAT IS THE TEST FOR ANY FUTURE UPLOAD -- fetch it back and diff it,
because the name on the asset is the one thing nothing in the engine checks.

****THE PAGE THAT EXPLAINS A REBIRTH COMES BEFORE IT, NEVER AFTER.** "Here is
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

**EIGHT PLAYERS, FIVE A SIDE, AND THE GAP BETWEEN THOSE TWO NUMBERS IS THE
SUPPLY FLOOR.** `PLOTS_PER_ROW` is 5 against a `MAX_PLAYERS` of 8, so TWO
resident houses can never be moved into, at any population, on top of the four
shop tills. The entry below records how it got to four a side; this is why it
went back up by one.

**IT IS BOUGHT WITH PLOTS RATHER THAN PAID FOR WITH PLAYERS, AND THAT IS THE
WHOLE DIFFERENCE FROM THE VERSION THIS FILE REJECTED.** A gap between the cap
and the plot count is the only thing that stops resident houses evaporating as
a server fills. It was opened once by taking `MAX_PLAYERS` down to 6, and
refused -- not because the gap was wrong but because it was paid for with two
children. Opened from the other end it costs one column and nobody is turned
away.

**`Config.MAX_PLAYERS` IS A PLAIN `8` NOW, NEVER `Config.PLOT_COUNT`.** Derived
from the plot count, the gap closes itself the next time anybody adds a column
-- silently, taking the floor with it. The direction still holds and is still
audited: `Main` kicks anybody it cannot seat, so it may never go ABOVE
`PLOT_COUNT`.

**IT COST NOTHING ANYWHERE ELSE, BECAUSE THE DERIVATION WAS ALREADY WRITTEN
FOR IT.** `Config.RESIDENT_FLOOR` is `SHOP_BANK_COUNT + math.max(0, PLOT_COUNT
- MAX_PLAYERS)` and `auditRobbery` sweeps population off the same pair -- that
second term had been sitting at zero waiting for this rather than needing to be
invented. Two constants, no other edit. Measured on the boot: 10 house plots
and 4 tills built, 13 residents seated, 16-stud alleys intact, zero plot
overlaps, and all three audits clean.

    players   houses + tills    cold     hot         was
       1          9 + 4        3.95x    7.91x       3.92x
       6          4 + 4        3.84x    7.68x       3.73x
       8          2 + 4        3.73x    7.46x       3.51x

Headroom over `ROBBERY_ADVANTAGE.min` went 17% to 24%, and the fall across the
whole population range went 10.5% to 5.6%. The floor laps in 110.4s against a
60-second `stealCooldown`, so the cooldown still does not bind.

**AND IT PUT THE CORNER-TO-CORNER WALK PAST THE NUMBER THAT CAUSED THE CUT,
WHICH IS THE COST AND IS RECORDED RATHER THAN EXPLAINED AWAY.** It is 351 studs
and 21.9 seconds, against the 336 studs and 21.0 seconds the entry below gives
as the reason the twelve-plot map was cut. Two things make it a different
decision rather than the same mistake, and neither is a measurement of how it
feels:

* **Every walk anybody actually makes is unchanged**, because `PLOT_SPACING`
  did not move. Next door is 80 studs and 5.0s, across the street 144 and 9.0s,
  and the getaway is still 53 studs and 4.4s -- so the robbery loop is
  untouched. Corner to corner is a diagonal nobody crosses: a thief robs the
  nearest worthwhile pig, and the rob badge is what makes that a local
  decision.
* **Rides did not exist when that cut was made.** The walk is the one thing a
  ride is sold against, so a longer street makes the largest coin sink in the
  game worth MORE, not less: end to end is 20.0s on foot, 14.8s on the 25,000
  skateboard and 9.5s on the 4.5M scrambler.

**WHAT IS NOT VERIFIED IS WHETHER IT READS AS LONG.** That is a look-at-it
question and `screen_capture` returned a stranded-camera sky view rather than
the street. If the street ever does read as long, the lever is `PLOT_SPACING`
-- and it is an expensive one, because it sets the getaway.

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
the log to say so.

**AND THIS ENTRY USED TO SAY `PLOTS_PER_ROW` HAS TO BE EVEN, WHICH IS NO
LONGER TRUE AND MATTERS BECAUSE SOMETHING WANTS TO USE THE ODD NUMBERS.** The
reason given was that an even count "gives the slot grid a true middle to
leave empty" -- correct while there WAS a middle to leave empty, and the very
next entry below records that gap being deleted when the town square moved
onto the verge. `Config.plotColumnX` centres on `(PLOTS_PER_ROW - 1) / 2`,
which handles an odd count by construction: five columns simply put one at
x 0. So the ladder is 8, 10, 12 rather than 8, 12.

That is worth a paragraph rather than a deletion because the gap between
those two is a whole decision. `PLOT_COUNT` above `MAX_PLAYERS` is the only
way to stop resident houses evaporating as a server fills -- see
`docs/MASTER-PLAN.md` -- and at 5 a side that costs ONE extra column
instead of two. A stale constraint had been doubling the price of a fix
nobody had priced. Same shape as every other entry here: a claim nobody
re-derived, believed because the thing it described never errored.

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

**AND THEN THEY WERE FOUR TEXTURED BOXES ON A STREET WHERE NOTHING ELSE HAD
A TEXTURE LEFT.** The entry above is about the four units being one shape; it
was the right diagnosis and it fixed the SILHOUETTES. What it never touched
is the vocabulary underneath, and the house pass then moved the ground under
it: every building on this street became flat-shaded low poly, and the shops
did not.

Measured before anything was changed, the four units were built out of
`Brick`, `Slate`, `Concrete`, `WoodPlanks`, `DiamondPlate` and `Grass` --
**five of the six textured materials the house rebuild had removed from every
other building in the game.** Photographed from the pavement with the rebuilt
cottages sixty studs behind them, the shops were the only noisy objects in
frame: speckled grey side walls, roofs that were bare sloping slabs where
every house behind had courses and a ridge, and glazing that was one flat
rectangle where every house had a frame, a sill and a mullion cross. They
also carried **123 coplanar pairs between them**, against zero on the nine
rebuilt tiers.

**SO THE TOOLKIT MOVED OUT OF `House.luau` RATHER THAN BEING COPIED, AND THAT
IS THE LOAD-BEARING DECISION HERE.** `tiledRoof`, `framedWindow`,
`windowBand`, `quoins`, `column`, `steps`, `parapet`, `capRoof` and
`pediment` were private locals in `House.luau`, which was right for as long
as houses were the only things built that way. `Shared/LowPoly.luau` is those
nine functions plus the structural palette, taking their parent as the first
argument; `House.luau` keeps nine one-line wrappers passing its own build
folder, so **not one of the nine tier builders changed**. A second copy would
have been the duplicate this file keeps recording -- and worse than usual,
because the whole POINT is that a shop and a house look like they came from
the same world.

**VERIFIED NEUTRAL RATHER THAN ASSUMED NEUTRAL: 1,032 parts across the nine
tiers after the extraction, against the 1,032 recorded before it, with the
manor at 212, the palace at 186 and 88 FX parts -- every figure identical.**

**AND THE EXTRACTION BROKE FIVE TIERS ANYWAY, IN THE ONE STATE THAT DOES NOT
SHOW UP AT LOAD.** `framedWindow`'s unlit branch reads `GLASS`, which lives
at House's module scope and did not travel with it -- so the moment the
function moved to a file where that name did not exist it painted nil. Nothing
errored on load, nothing errored on the four tiers that light every window
they have, and the townhouse, villa, manor, palace and castle all threw
"Color3 expected, got nil" -- because reaching the branch needs a tier with an
UPPER FLOOR. **A CONSTANT AN EXTRACTED FUNCTION READS IS PART OF THE
FUNCTION**, and the way to find the ones you missed is to build every caller,
not to read the diff.

---

**WHAT A SHOPFRONT IS, AND IT IS NOT A WALL WITH A HOLE IN IT.** The four
things the house pass measured against reference art all applied unchanged --
flat colour, a plinth where the building meets the ground, a hard line at
every corner, courses on the roof. The fifth is a shop's own: **piers, a
stall riser, glazing, a transom, a fascia -- five bands, in that order.** The
band heights are constants at the top of the file rather than numbers each
style invents, which is why the door head, the window head and the fascia
finally line up with each other.

**THE QUOINS SKIP THE FRONT, WHICH IS WHY `LowPoly.quoins` GREW A FLAG.** Run
round all four corners they land in the middle of the glazing -- masonry
growing through a window. A shop gets them on the back pair and PIERS at the
front. The houses pass nothing and keep all four.

**THE FOOTPRINT DID NOT GROW, WHICH WAS A CONSTRAINT RATHER THAN A RESULT.**
The verge band is solved rather than chosen and a till stands on the forecourt
at shop-local (-16, +16) -- measured, not assumed, because the model's
`WorldPivot` carries no rotation and a probe reading "shop-local" off it is
really reading world axes. Everything on the paving stays inside
`WIDTH + FORECOURT_OVERHANG`. Measured after: 21.4 across against a 47-stud
clear band, 5.7 studs off the fence behind, ten studs of pavement in front.

---

**THE NAME CAME OFF THE FASCIA, AND THE FASCIA WAS NEVER THE RIGHT SURFACE
FOR IT.** Reported as barely readable, and three things were wrong at once and
none of them was the font. IT FACED ONE WAY -- a fascia is flat against the
frontage and a player walks ALONG the street, which is the exact fault the
projecting bracket sign was added to fix and which the fascia never stopped
having. IT WAS CREAM ON THE ACCENT, thin in full sun under a BloomEffect. And
IT SHRANK WITH DISTANCE, like anything painted on a surface, on a building
that is read from thirty studs away.

A `BillboardGui` plaque over the roof fixes all three by construction. It is
**not `AlwaysOnTop`** -- a name that punches through the building it belongs
to reads as a HUD element, and this file already argues the physicality of the
street boards at length -- and it is **distance-capped at 260**, because eight
of these legible from anywhere on a 350-stud street is a wall of text over the
world. Rounded in SCALE and not in pixels: a billboard's pixel size falls with
distance, so an offset corner radius is a nick up close and a lozenge from
across the street.

**A SERVER FILE THAT BUILDS A GuiObject TAKES `Theme`.** That is the scope
rule the verge boards got wrong -- "the UI files" is not the same set as "the
files that build UI" -- and it is why eighteen hardcoded colours sat on the
leaderboard for months.

---

**ONE WHITE BLOWOUT, FOUR WRONG DIAGNOSES, AND THE LESSON IS THE SEQUENCE.**
The display window rendered as a featureless white sheet with the item inside
it invisible. In order:

* **The pane.** Dropped to 0.86 transparent with reflectance 0. No change.
* **The trim.** `CREAM` measured a relative luminance of **0.973** on
  forty-five parts of every unit, above every trim colour the nine house tiers
  carry, and genuinely was blooming. Fixed -- and the window was still white.
* **The neon strip.** A saturated Neon bar directly under the glazing throws a
  halo far wider than itself. Moved onto the transom band. Still white.
* **The display.** Probed by walking the model and testing the aperture point
  by hand -- spatial queries are useless in here, because every part is
  `CanQuery` false -- the only thing in the opening was the display's own
  body, a 3.7-stud sphere filling most of a 5.25-wide window with the shop's
  empty interior behind it. Given a backboard and scaled down. Still white.

**IT WAS SETTLED BY TINTING, NOT BY REASONING.** Glass green, frame blue,
awning orange, and re-shoot: every piece was there and correctly placed. The
frame, the mullion cross, the sill and the pale interior were simply ALL
NEAR-WHITE, and near-white on near-white in full sun is one sheet whatever the
geometry is doing. `LowPoly.framedWindow` never has this problem because the
tier it serves hands it a DARK trim -- the cottage's is (120, 84, 58). The
shop handed its window the same near-white it used for the piers.

**SO THE FRONTAGE IS TWO COLOUR FAMILIES: light MASONRY and dark JOINERY.**
Piers, quoins, cornice and fascia rails are light; window frame, mullions,
door surround and transom are dark. That is what a real shopfront is, it is
what makes glazing read as a hole rather than as a panel, and it costs one
colour. **TINT THE PARENT A COLOUR NOTHING ELSE USES** is what separated
"not drawn" from "drawn and invisible against its neighbour" -- this file
already records that trick for the shop cards, and it is the only thing that
ended a chase through four innocent suspects.

**AND THE WALLS ARE A PALE TINT OF EACH SHOP'S OWN ACCENT.** The first
palette pass made all four the same white, so the four silhouettes were doing
all the work and the four PALETTES were doing none. Lerped 0.70 toward white
the boutique is pale pink, the garden centre pale green, the workshop pale
amber and the strongroom pale blue -- readable from further away than any of
the geometry is.

**AN OPENING NEEDS SOMETHING BEHIND IT, and the garden centre needed the same
fix with no display to hang it on.** Its "open front" read as a pale panel
because nothing behind it was darker than the wall. A planted inner wall gives
it a depth to read against.

---

**THE Z-FIGHTING WENT 123 -> 0 IN FOUR PASSES, AND THE AUDIT'S OWN RULE HAD TO
BE FIXED FIRST.** The first sweep counted any shared face plane, which flags
every honest BUTT JOINT in the building -- two faces pointing at each other,
both buried, never a fight. **SAME-FACING IS THE TEST**: lo==lo or hi==hi,
with more than 0.02 of overlap on the other two axes. On the corrected rule
the rebuild started at 51 and converged to 0 over 433 parts.

The families were the same ones the houses had: a detail sized to land flush
on what it stands on, and a frontage laid out on the PANE widths when a sill
oversails its own glass by a stud each side. Two shop-specific ones worth
keeping: **a border whose uprights exactly span its rails' outer faces** (the
uprights have to CAP them, not meet them), and **a roller shutter authored
behind the glass it shuts** -- outside is where a real one hangs and is also
what stops its bottom face landing 0.005 from the pane.

**AND ONE PAIR CAME BACK AFTER IT WAS CLEAN**, when the shutter housing was
resized to match the bay it covers and grew into the bracket sign. The housing
could not shrink -- it is sized off glazing that sits to one side of the
frontage -- so the SIGN moved outboard onto the pier, which is where a bracket
sign is bolted anyway. **RE-RUN THE AUDIT AFTER EVERY GEOMETRY CHANGE, not
after the last one.**

---

**WHAT WAS VERIFIED.** Four units build; zero coplanar pairs over 433 parts;
zero textured materials in the shops' own geometry (the twenty that remain are
inside the DISPLAY models -- a real BMX and a real Golden Bone from their own
builders, which must stay as they render in a player's hand); nothing
collides, answers a query or casts a shadow; all four doors tagged with the
right tab and carrying a working `shop` prompt; all four banners present and
enabled; displays on three and correctly absent on the garden centre; and the
**FX counts unchanged at 2 / 2 / 10 / 2**, with all sixteen tagged parts
measured moving across a 2.6-second sample at a smallest delta of 0.467.

**THE BULBS LOOKED DEAD IN EVERY STILL AND WERE FINE**, which is this file's
own chase rule arriving on a new object: one bright band travels the run, so
at any instant most of the nine sit at `Dim` and a photograph reports them
unlit. Sample across a cycle.

**WHAT IT COSTS: 433 PARTS ACROSS THE FOUR, against 205 before.** Measured on
a live street that is 6,746 BaseParts, the shops are **6.4% of the world** and
tufts are still 27%. Performance was never the reason to cut anything here and
is not the reason now, but the number is on record.

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
File -> Game Settings -> World -> Max Player Count. **KEEP IT AT
`Config.MAX_PLAYERS`, WHICH IS 8 AND MAY NEVER BE ABOVE `Config.PLOT_COUNT`
(10).** Those are two different numbers ON PURPOSE now and the gap is the
resident supply floor -- see the five-a-side entry above. It spent one session
below the plot count for the same reason and by the WRONG LEVER, cutting the
cap rather than adding plots; what changed is which end the gap is opened
from, not that there is one.
`Main` warns when the place and Config disagree. This is the same class as the `GearPreview` folder: state
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

**THE GARDEN IS THREE COSMETICS THAT SPEND NO SLOT, AND THAT IS THE WHOLE
ARCHITECTURE RATHER THAN A DETAIL OF IT.** There are nine lawn slots against
twenty-odd ornaments, and this file already argues that the scarcity IS the
feature -- choosing what to display is what makes the shelf mean anything. A
border of plants added as ORNAMENTS would have cost a slot per plant, so a
player who wanted a garden would have had to clear their trophy shelf to get
one, which is the opposite of what a garden is for. `Config.BORDER_PLANTS`,
`GARDEN_PATHS` and `WINDOW_BOXES` are EQUIPPED rather than PLACED -- one of
each per plot, hung on geometry the plot already has -- so the nine slots are
untouched by construction rather than by anybody remembering. Same shape as
`DOG_COATS` and `DOG_KENNELS`, which are a wardrobe over an animal that
exists; these are a wardrobe over a fence, a gate walk and a house.

**HOW TALL A BORDER MAY STAND IS DERIVED, AND THE DERIVATION IS EXACT RATHER
THAN APPROXIMATE.** the old roadmap stated the cap in prose -- *anything
above roughly the fence's own `decorTop` starts hiding the piggy from the
pavement* -- and "roughly" is the wrong way to ship a number, for the reason
`SHOP_BANK_PIG_SECONDS` was wrong by 62% and the vault opening was sized
against one of four lock tiers. `Config.borderHeight` clamps a plant to the
STANDING tier's `decorTop` less `LAWN_LIFT`, and the proof is geometric: a
plant on the fence line of height H occludes precisely what a fence of height H
occludes -- same ground, same distance from the viewer, same distance from the
pig. **A CLAMPED BORDER HIDES NOTHING THE FENCE DOES NOT ALREADY HIDE**, at
every tier, from every camera on the pavement, with nothing to re-measure when
a tier moves.

**THE BORDER CANNOT SIMPLY MOVE INWARD TO GET MORE ROOM, WHICH IS THE
TEMPTING FIX AND THE ONE THAT QUIETLY BREAKS THAT PROOF.** The clearance
between the widest ornament and the fence is 1.75 studs and a rose bush is a
four-stud ball, so something has to give -- and it cannot be the POSITION. A
nearer occluder of the same height hides MORE of the animal, because the
sightline over its top lands higher up the pig. So the plant gives way
instead: `BORDER_BAND` caps a plant's depth ACROSS its run, and the two round
styles are stretched spheres rather than balls.

**WHAT IT COSTS, STATED PLAINLY: YOUR FENCE TIER NOW SETS HOW TALL YOUR GARDEN
MAY BE.** 3.2 studs at Rickety, 7.9 at Barbed and above. That is a real
coupling between a defence purchase and a cosmetic one and it is the honest
direction -- the tall garden goes to the player who has already paid to hide
their own pig. A cosmetic that could out-reach the fence would be a cosmetic
implying a tier, which is the rule `docs/MASTER-PLAN.md` re-reads every phase.

**AND THE BUG THAT MATTERED WAS INVISIBLE TO EVERY PROBE AND TOOK A
PHOTOGRAPH.** `borderHeight` indexed `FENCE_TIERS[level + 1]` where
`buildFence` indexes `[level]` -- the table is 1-based and level 0 means NO
fence -- so the garden clamped against the tier ABOVE the one standing. **Every
check passed, because every check compared the border against `borderHeight`'s
own answer and they agreed with each other perfectly.** Only a shot from the
pavement showed it: a Sunflower border at y 8.64 over a picket fence topping
out at 5.10, three and a half studs of garden over the thing it is bounded by.

That is this file's own rule arriving on a new object -- **A MEASUREMENT
AGAINST A MODEL OF A THING IS NOT A MEASUREMENT OF THE THING**, written for
the pig's cap, its rim and its disc, and earned again here. It also sits
directly beside the entry about six always-on-top systems whose pixels nobody
ever looked at: **a probe answers "is it there and does it say the right
thing", a picture answers "can it be seen", and reaching for the convenient
one twice is how a feature whose entire purpose is being read from the
pavement goes unread from the pavement.**

**THE FIX EXPOSED A SECOND ONE UNDERNEATH IT, AND IT IS AN ASYMMETRY ALREADY
ON RECORD.** The fence is built from `FENCE_BASE_Y`, the world ground; a
border is planted on the LAWN, a stud higher. So a plant clamped to the raw
`decorTop` starts a stud up and finishes a stud proud -- measured at 4.45 and
5.68 against fences topping out at 3.20 and 4.60. **A FENCE IS A STUD TALLER
FROM THE STREET THAN FROM THE LAWN** is already written here, from the day
three tiers turned out to be hoppable in one direction only; it bites here
from the other side, because the lawn is the high ground and anything standing
on it gets a stud for free. With the `LAWN_LIFT` term the cap lands on
3.20 / 4.60 / 7.90 against measured visible fence tops of 3.20 / 4.60 / 7.90.

**A PLANT IS AUTHORED ALONG +X AND THE RUN TURNS IT, WHICH THE FIRST BUILD DID
NOT DO.** A hedge's box is sized to overlap its neighbour so the run reads as
one hedge, and with no rotation that length is always on X -- correct on the
two FRONT wings, which run along X, and lying broadside across the fence on
the two SIDES, which do not. Measured at |x| 34.21 against a fence line of
33.60: a hedge bought for a lawn standing out over the alley. Solved in
`buildBorder` rather than in each style, so a plant added later is correct on
every run by construction.

**A RUN ENDS ON THE FENCE CORNER, SO THE END PLANT OVERHANGS IT BY ITS OWN
HALF-LENGTH.** Both axes read exactly 0.61 past their line, which is a hedge
box's half-length -- the same number twice being what said it was the
geometry rather than the placement. Each run is pulled in at both ends by the
plant's own reach, derived per style because the styles do not agree about
what their footprint IS: a hedge's is a function of SPACING, a rose bush's of
the clamped HEIGHT, a lavender spike's of neither. One constant would have
been right for one of them and silently wrong for the other two.

**`cone` IS FIVE PARTS, WHICH IS THE RIGHT TRADE FOR A GNOME'S HAT AND THE
WRONG ONE FOR SOMETHING THAT REPEATS FORTY-EIGHT TIMES.** A Lavender border
came to 288 parts against a Box Hedge's 60, for a shape nobody stands close
enough to count the facets of. Rebuilt as a stem and one stretched sphere it
is 96. It was ALSO overshooting its cap, because `cone` takes its CFrame as
the BASE and puts a tip ball on top -- so a head placed at a fraction of `up`
reached past `up`. **ANYTHING SEATED BY A FRACTION OF A CLAMP OVERSHOOTS AT
THE SHORT END OF THE CLAMP**: the sunflower's face is a fixed 1.5 across, so
at a rickety fence it cleared its cap by 0.25 and at a moat it did not. It is
seated so its TOP lands on `up` rather than its centre at a fraction of it.

**A NAME COLLISION RENDERS ONE EXTRA CARD AND NOTHING ELSE.** The shop drew 12
cards where the three catalogues hold 11, because "Red Brick" was already a
DOG KENNEL and both would have stood on the same tab a few sections apart --
one a paving choice, one a kennel paint job, with nothing but the header above
them to tell a nine-year-old which was which. There is no error and no
warning; the count is the only symptom. Swept every catalogue for duplicate
display names afterwards and two more survive, both older and both CROSS-TAB:
**"Midnight" is a kennel AND a skin, and "Solid Gold" is a kennel AND a
skin.** Left alone rather than renamed in passing -- one of them was being
edited by another session that hour -- and recorded here so the next person
finds them deliberately rather than by counting cards.

**THE TOPIARY TAKES THE SKIN'S COLOUR AND NOT ITS MATERIAL, WHICH IS THE WHOLE
DIFFERENCE BETWEEN A TOPIARY AND A STATUE.** `Enum.Material.Grass` is what says
PLANT; the colour is what says whose plant. Take both and a Solid Gold topiary
is a gold pig standing on a lawn -- a perfectly good ornament, and not the one
that was bought. It also does not take `reflectance`, which the three metal
skins carry: a shiny hedge is a contradiction, and the flatness is the tell
that this is a plant rather than a second pig. **THE RULE FOR THE NEXT FIELD
IS THAT ANYTHING DESCRIBING A SKIN'S SURFACE BELONGS ON THE ANIMAL AND NOT ON
THE SHRUBBERY**, rather than wiring each one up as it lands. An animated skin
is SAMPLED at its palette's first colour and deliberately not driven: a
topiary that pulsed would be a second light show on a lawn that already has
the pig doing it, and the two out of phase read as a fault rather than as a
set.

**THE WINDOW BOXES ARE A POST-PASS OVER A BUILT HOUSE, NOT AN ARGUMENT
THREADED THROUGH NINE TIER BUILDERS.** `LowPoly.framedWindow` names its ledge
`Sill` and every window in the game goes through it, so hanging a box is a
walk over the model after it is parented -- the same call `bindTrampolinesIn`
makes for a mat. Threaded instead it would have been one optional argument
through `House.build`, nine builders and `windowBand`: nine chances to leave it
out, with a missing one reading as nil, which is the silent EMPTY case
`signWord` and `setDecor` both refuse. **GROUND FLOOR ONLY IS AN ARGUMENT
ALREADY WON**: `framedWindow`'s own comment records that a lit window is right
on the cottage's two and wrong on the manor's eleven, and the boxes inherit
that rule and its reasoning for nothing. The rank is derived from the sills
that are actually there -- the lowest one sets it -- rather than from a height
anybody typed, which would be wrong on nine tiers of different heights.

**THE TWO REBUILD SEAMS ARE WHERE THIS WOULD HAVE ROTTED.** A border is
rebuilt at the end of `buildFence`, because its clamp AND its gate gap both
come off the tier -- a fence upgrade that did not put it back would leave last
tier's planting standing across this tier's gate. Window boxes are rebuilt at
the end of `setHouseLevel`, because they hang off `Sill` parts inside the model
that function destroys. Neither is left to the next `applyToPlot`: a house
tier and a fence tier can each be bought without anything else about the plot
changing. What is equipped is sticky on the PLOT for the reason `trophies` is
-- both of those functions have callers that know nothing about a garden.

**AND `Decor.build` TOOK A SIXTH ARGUMENT WHILE `setDecor` DELIBERATELY DID
NOT.** That function has five callers across four services and this file
records the decision not to grow its signature, because a missed positional
argument reads as nil and lands as a silent EMPTY on a lawn nobody would think
to check. `Decor.build` has exactly ONE caller, so the same argument does not
apply to it: the plot holds the skin and `setDecor` passes it on. **THE RULE
IS ABOUT THE NUMBER OF CALLERS, NOT ABOUT THE NUMBER OF ARGUMENTS**, and
reading it as the latter is how a codebase ends up with a registry for
something two functions needed to say to each other.

---

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


**THE LAWN IS FLAT COLOUR AND THE TREES ARE GENERATED MESHES, AND THE FIRST
THING THAT DECIDES IS WHICH OF THOSE TWO A THING IS.** The piggy was replaced
with `generate_mesh` and the obvious next move was to point the same tool at
everything else. **GRASS IS NOT A MESH PROBLEM.**

The lawn was a generated MATERIAL for one session and is a flat `SmoothPlastic`
now, for two independent reasons that both landed the same day: twelve
candidates were generated and not one of them read as CARTOON rather than as a
good photograph of a lawn, and the generation itself got the account moderated
(next entry). The reasoning below about surfaces against meshes is unchanged
and is the part worth keeping. The pig is one
object twelve studs across; the ground is a single 780x560 Part and the lawns
are slabs, so there is no geometry out there to replace -- only a surface.
Studio's `generate_material` is the counterpart to its mesh generator for
exactly that job, and reaching for the wrong one of the two is how a world
pass turns into weeks of modelling something that wanted a texture.

**AND `generate_material` GOT THE ACCOUNT MODERATED, WHICH IS THE MOST
EXPENSIVE THING IN THIS FILE AND HAS TO BE READ BEFORE ANY OF THE REST OF
IT.** Twelve variants were generated across one session to compare, and the
account was actioned for SEXUAL CONTENT on an asset named *Generated
RoughnessMap*.

**EVERY GENERATION IS AN UPLOAD TO YOUR OWN ACCOUNT, AND IT IS FOUR OF THEM
PER VARIANT.** One `generate_material` call returns FOUR variants, each
carrying a colour, normal, metalness and roughness map -- so one call is
SIXTEEN uploaded images, and three calls was forty-eight. They are published
under your name, they are moderated exactly like anything else you upload, and
you never see one of them. A roughness map is a greyscale surface-detail
image with nothing depicted in it at all, and that is what got flagged, so
this is a classifier false positive on abstract noise rather than anything
anybody chose.

**THE BLAST RADIUS IS THE ACCOUNT, NOT THE EXPERIENCE, WHICH IS WORSE THAN
EVERY OTHER MODERATION ENTRY IN THIS FILE.** The meme ornaments, the patrol
car and the arrest screen are all built as originals because "moderation
strips branded assets and the penalty lands on the EXPERIENCE". This one
does not land on the experience. It lands on the person, and it stops them
opening Studio.

**SO: GENERATE FEW, AND LOOK AT WHAT YOU ARE UPLOADING.** Comparing a dozen
candidates costs nothing in tokens and forty-eight uploads in risk. Generate
one or two, and treat every one as a publication under the developer's own
name -- because that is exactly what it is.

**AND THE FAILURE PRESENTS AS A BROKEN STUDIO LOGIN, WHICH COST AN HOUR OF
WRONG DIAGNOSIS.** The action landed MID-SESSION. What it looked like from
inside was `MeshContentProvider ... could not fetch`, `Failed to load sound
... HTTP 403`, `DataStoreService: AccessForbidden`, `Player:IsInGroup failed
because HTTP 403` and `GetProductInfo failed because HTTP 403` -- while some
meshes went on loading perfectly, because those were already in the local
cache. That reads exactly like an expired session, and the advice given at the
time was to restart Studio and switch on API services, which was wrong.
**ANYTHING THAT SUDDENLY 403s ACROSS SEVERAL UNRELATED SERVICES AT ONCE IS AN
ACCOUNT QUESTION BEFORE IT IS A STUDIO QUESTION.**

**THE GENERATED MESHES ARE A SMALLER SURFACE AND ARE NOT CLEARED BY THIS.**
A mesh generation uploads a mesh and one texture rather than four maps, and
the tree, the tuft and the piggy came through this untouched. That is a
smaller number, not a different rule: they are uploads under the same account
and they are moderated the same way.

**AND THE REPO NO LONGER POINTS AT ANY OF IT.** `src/MaterialService/` and its
branch in `default.project.json` are gone, because a repo referencing a
moderated asset is a liability and the ground had already moved to flat -- see
below. Nothing was lost: the flat ground is the look that was chosen anyway.

**A MATERIALVARIANT CANNOT BE BUILT AT RUN TIME, AND THAT IS THE THIRD ENTRY
IN THE `RenderFidelity` FAMILY.** The first build put the four map ids in
Config and had `WorldService` assemble the variant at startup -- the same
shape as `Config.PIGGY_MESH` and `Config.ANIMATIONS`, ids in a table with an
empty id falling back to what shipped. It was verified through the MCP sandbox
and passed. Live, from a real Script, it throws:

    The current thread cannot write 'BaseMaterial' (lacking capability Plugin)

The sandbox and the command bar both run WITH plugin capability, so the one
environment that proved it worked is the one environment that is not the game.
That is exactly `RenderFidelity`, and exactly `RegisterKeyframeSequence`, and
this is now the third time. **ANYTHING CAPABILITY-GATED HAS TO BE EXERCISED
FROM A REAL SCRIPT BEFORE IT IS BELIEVED** -- and the cheap way to do that is
to press Play once and read the server log, which is what caught this.

**SO ROJO OWNS THE MATERIAL, AT `src/MaterialService/PiggyLawn.model.json`.**
Rojo 7 serialises a `MaterialVariant` from a `.model.json` perfectly -- base
material, all four maps, studs per tile -- so the asset stays in source
control and a fresh empty place plus this repo still gives the identical
world, WITHOUT a runtime write that can never succeed. It also keeps it out of
`MaterialService.AssistantMaterials`, which is where the generator leaves its
output: in the PLACE FILE, where Rojo does not reach and nothing reconciles it.
That is the `GearPreview` trap, and the generator walks into it every time.

Note `default.project.json` IS NOT HOT RELOADED. Adding the MaterialService
branch needs `rojo serve` restarting; a running serve will go on syncing the
old tree with nothing to say so.

**THE MAPS LIVE IN THE MODEL FILE AND ONLY THE NAME LIVES IN `Config`.** Two
copies of four asset ids is the near-identical duplicate this file keeps
recording. The name is the entire interface, and **A DANGLING NAME IS SAFE**:
a `MaterialVariant` property naming something MaterialService does not hold
falls back to the part's own BaseMaterial, so a deleted model file renders the
stock grass this game shipped with rather than an error. Measured live before
the variant was seated -- ground reporting `variant="PiggyLawn"` against an
empty MaterialService, rendering as ordinary grass, nothing in the log.

**IT IS OPT-IN PER PART, NEVER A `MaterialService` OVERRIDE.** Writing
`MaterialService.Grass` repaints every Grass part in the game in one go, and
`Material.Grass` is on fourteen things across six files -- the topiary pig on
somebody's lawn, the shop hedge, a house tier's flower bed. A lawn texture
tiled every ten studs across a one-stud prop is a smear. The ground, both plot
grass parts and the hills name the variant; nothing else does.

**A GENERATED MATERIAL MULTIPLIES AGAINST `Part.Color`, WHICH KILLED HALF THE
CANDIDATES BEFORE THEY WERE LOOKED AT PROPERLY.** The generator returned four;
two carry a deep saturated colour map, and against the shipped `LAWN` tint
those came out bottle-green mud. The pig's texture lesson arriving on a
surface. Anything replacing these maps gets looked at ON the shipped lawn
colour, never on white.

**TAKING A TEXTURE OFF A SURFACE MAKES IT ABOUT A THIRD BRIGHTER, AND EVERY
GROUND COLOUR IN THIS GAME HAD TO COME DOWN THE DAY THE LAWN WENT FLAT.** A
material MULTIPLIES `Part.Color`. That is written above as the reason a
generated texture could only ever darken the lawn -- and the same sentence run
backwards is the half nobody thought about: for the whole life of the project
these colours had been rendering at roughly two thirds of what the source
said, and NOBODY HAD EVER SEEN THEM AT THEIR LITERAL VALUE. Flat, they were
seen for the first time, and `GRASS` at (118, 158, 88) came out an acid pastel
that shouted over the trees, the hills and the piggy. Reported, correctly, as
the grass being far too bright.

So `GRASS`, `GRASS_DARK` and `LAWN` came down about 30%, which is what the
texture had been doing for free. **THE PAIR OF DECISIONS IS ONE DECISION**:
anything that ever puts a texture back on this ground has to put those numbers
back UP by roughly the same amount or the street goes dark, and the comments
at both ends say so.

**THE HILLS WERE DELIBERATELY NOT MOVED WITH THEM, WHICH LEAVES THEM
NUMERICALLY LIGHTER THAN THE GROUND THEY STAND ON** -- the reverse of how they
started. That was looked at rather than reasoned about: a hill is a
half-buried SPHERE and a lawn is a flat plane, so the two catch the 14:30 sun
completely differently, and on screen the hills still read as the deeper,
further thing. Matching the numbers would have made them read wrong. It is the
same lesson as the tube man and the transposed bounding boxes from the other
end -- the convenient number and the one that governs what you see are
different numbers, and here the convenient one is the RGB triple.

**AND THE TUFT TINTS CAME DOWN WITH IT**, because they are near-white
multiplies over the tuft's own painted map rather than flat colours: on a
darker lawn the old pair popped hard enough to read as straw.

**AND THE MATERIAL IS ONLY HALF OF A LAWN. THE OTHER HALF IS GEOMETRY.** A
painted ground is still a plane, and from standing height a plane reads as a
plane however well it is painted -- which is the honest limit of the entry
above and was visible the moment it shipped. What sells a stylised lawn is
SILHOUETTE: blades breaking the line where the ground meets everything
standing on it. `Shared/GrassTuft.luau` plants clumps of generated grass on
the plot lawns and along the verge, and the two halves are one job rather
than two options -- neither is worth much alone.

**`Shared` FOR THE CACHE, WHICH IS A DIFFERENT REASON FROM THE ONE HOUSE AND
DECOR ARE THERE FOR.** Those live in Shared because the SHOP renders them.
Nothing renders grass in a shop and none of this is client-side. It is shared
because two services plant it -- PlotService on the lawns, NeighborhoodService
on the verge -- and `CreateMeshPartAsync` yields, so a second copy would mean
a second web call for one asset and, worse, two places that could disagree
about how tall a tuft is.

**HEIGHT AND DENSITY ARE TWO DIFFERENT QUESTIONS AND THE FILE KEEPS THEM
APART.** `minScale`/`maxScale` decide whether the lawn is still a lawn:
the clump is authored 2.60 studs tall, which against a five-stud rig is
waist-deep meadow and a different game -- one where a thief wades across a
yard. At 0.28 to 0.52 a tuft stands 0.73 to 1.35 studs, ankle to mid-shin.
`perStuds` decides whether it reads as grass or as weeds. Turning the wrong
one of those two is how a tuning pass ends in a meadow, and the shipped
numbers are 819 tufts against a world of 2,428 BaseParts.

**A SCATTER TAKES THE PART, NOT A RECTANGLE, AND THAT IS THE FAR ROW
HANDLED FOR NOTHING.** `buildPlot` authors everything around `origin` and
turns the whole model with a single `PivotTo` at the end, so tufts planted
before that turn are carried by it -- and `scatterOn` reads the surface's own
CFrame rather than being handed plot-local numbers a caller would have to
remember to flip. Same argument as measuring a building by its parts: the
part knows its own frame, and the convenient number is the one that is wrong
on half the street.

**AND THE DRAW HAPPENS BEFORE THE VETO, WHICH IS THE ONLY REASON THE LAYOUT
IS STABLE.** `scatterRect` pulls its position, scale, yaw and tint from the
sequence whether or not the spot survives `accept`. Drawing inside the branch
instead makes every tuft after a rejected one shift, so moving one driveway
reshuffles the whole street's grass -- a deterministic scatter that is not
actually deterministic, which is the worst of both.

**THE VERGE BAND IS DERIVED FROM WHAT IS ALREADY STANDING ON IT.** It starts
outboard of the lamp posts and wheelie bins on the 1.8-stud verge line and
stops short of `boardZ` and the shops behind it, so it is the one strip out
there that nothing else occupies -- and the strip a player spends the whole
walk looking at. Driveways are vetoed because a drive CROSSES that band rather
than running beside it: it is laid from the kerb to the fence line, so every
plot column punches a hole through the strip. Measured live at zero tufts
standing on a driveway slab.

**A LAWN NEEDS NO VETO AT ALL, AND THAT IS DERIVED RATHER THAN ASSUMED.**
`buildDriveway` works in PLOT-LOCAL z from `driveNear` 25.6 outward, against
a slab that ends at `PLOT_SIZE.Z / 2` -- so the whole drive is in FRONT of the
lawn and never on it. The moat is the other candidate and takes the fence
RING, outboard of the 64-wide grass with the stone trim between them; that
half is reasoning and not a measurement, and it is listed under "Not yet
verified" rather than asserted here.

**EVERY TUFT IS CanCollide, CanQuery AND CastShadow FALSE**, which is the rule
the whole of `NeighborhoodService` and every lawn ornament already follow and
which matters more here than anywhere because there are eight hundred of them.
A tuft that collided would body-block a chase on the exact ground a chase
happens on; one that answered a raycast would eat a query meant for a piggy.
Verified live at zero of 819 breaking any of the four.

**THE TREE KEEPS ITS BAKED TEXTURE, WHICH DELIBERATELY REVERSES THE PIGGY'S
RULE.** Everything written about stripping `TextureID` off the piggy is
correct and none of it applies here, and the obvious move -- copy the pig --
is wrong. The pig is stripped because FORTY-SIX SKINS multiply a colour onto
it, so a painted mesh is muddy on forty-five of them and the three animated
skins drive that muddy multiply every frame. A tree has no skin system: its
colour is a constant. So the baked shading between the leaf clumps is free
depth, and it is the only thing making the canopy read as clumps at all.
Built both ways side by side and photographed before deciding; the stripped
and flat-tinted version is visibly the worse tree.

**AND `CreateMeshPartAsync` DOES NOT CARRY THE TEXTURE, WHICH SHIPPED THE
WORSE TREE ANYWAY FOR ONE BUILD.** It takes a MESH id and nothing else, so the
part comes back untextured however the asset was authored. Nothing errored,
nothing warned, and the only symptom was that the trees looked flat -- the
quietest failure shape there is. A generated mesh and its painted map are two
separate uploads and anything cloning one has to ask for both. Measured after
the fix: 52 of 52 parts textured.

**`MeshPart.TextureID` IS WRITABLE FROM A SCRIPT; `MeshPart.MeshId` IS NOT.**
Worth writing down as a pair, because they sit next to each other and this
file already records `MeshId` throwing *lacking capability NotAccessible*. The
neighbouring property is fine, so the mesh comes from
`InsertService:CreateMeshPartAsync` and the map is assigned afterwards.

**`RenderFidelity` IS `Automatic` ON A TREE AND `Precise` ON THE PIGGY, AND
THAT IS THE POINT RATHER THAN AN INCONSISTENCY.** The pig is `Precise` because
it is read from the pavement and is the one object a robbery is about, so
shedding triangles with distance would show. A tree is backdrop and there are
twenty-six of them, and shedding triangles with distance is exactly what you
want from twenty-six backdrop objects.

**AND THE PIGGY WAS NOT ACTUALLY `Precise`, FOR THE WHOLE LIFE OF THE MESH
PIG, BECAUSE THE ONE PART THAT MATTERED IS A CSG RESULT.** The trim meshes
come from `InsertService:CreateMeshPartAsync`, which takes render fidelity as
an ARGUMENT -- so `Ear`, `Snout` and `Tail` really were Precise. The BODY is
the output of `SubtractAsync`, and the code set its fidelity with a PROPERTY
WRITE afterwards, inside a pcall, because this file's own entry below says
that write is capability-gated. Live, the pcall swallowed the throw exactly as
designed and the body shipped at `Automatic`. Measured: body `Automatic`,
trim `Precise`, on the same model, with nothing in the log.

**THE FIX IS THAT `SubtractAsync` TAKES BOTH FIDELITIES AS PARAMETERS, AND
THAT IS THE FIRST ESCAPE HATCH THIS FILE HAS FOUND FROM THE CAPABILITY
FAMILY.** `body:SubtractAsync(cutters, collisionFidelity, renderFidelity)` is
not a property write, so nothing is gated and the result is born Precise --
verified from a real Script on a live server, reading back `Precise` where the
pcall version read `Automatic`. **ANYWHERE A GATED PROPERTY HAS A CONSTRUCTOR
ARGUMENT THAT SETS THE SAME THING, THE ARGUMENT IS THE ROUTE.** The three
entries in this file about capability gates -- `RenderFidelity`,
`RegisterKeyframeSequence`, `MaterialVariant` -- were all written as "this
cannot be done from a Script". For this one, it can; it just cannot be done as
an assignment.

**AND IT WAS NOT THE FACETING ANYBODY WAS COMPLAINING ABOUT, WHICH IS WHY THE
A/B MATTERED.** `Automatic` sheds triangles with DISTANCE, so at conversation
range the two are pixel-identical -- photographed both ways from the same
camera to be sure. The visible polygons on the pig are the GENERATED MESH'S
OWN, proven by standing the uncut body mesh next to the CSG one and finding
the same shattered specular highlight on both. So the fidelity fix is real and
is about the view from the pavement; it is not a smoothing pass.

**A LOWER POLY COUNT IS THE WRONG DIRECTION FOR "MAKE IT BUBBLY", and it is
the intuitive ask.** Faceting IS low poly. What reads as bubbly is a DENSE
mesh with smooth normals, and the only lever on that is regenerating the body
-- which costs an upload under the developer's own account (see the moderation
entry, the most expensive thing in this file) and re-derives the landmark
contract that twelve accessories, the vault dial, the coin pile and both bores
are all cut against. The cheap mitigation is material: the artefact is a
SPECULAR one, so it is loudest on the Metal, Glass and Foil skins and
disappears entirely on the twenty-two Neon ones, which are unlit and read by
silhouette alone.

**A CANOPY CLEARANCE IS THE DIAGONAL, NOT THE DEPTH, BECAUSE EVERY TREE
CARRIES A YAW.** Trees are turned on their own axis for variety -- free, and
the whole difference between a grove and twenty-six copies of one tree -- so a
canopy twelve studs wide by ten and a half deep presents its CORNER at
forty-five degrees, which is eight studs rather than five. Measuring the depth
alone gives a clearance that is right for the trees facing the street and
wrong for the ones that are not: the same asymmetry as the tube man that broke
the side fence on the four left-hand lawn slots and not the four right-hand
ones, and no screenshot catches either.

**AND THE RULE IS A CLAMP NOW RATHER THAN AN ARITHMETIC COINCIDENCE.**
*Nothing here may sit inside the fence -- a canopy over a plot still hides a
piggy* held because the grove depths were chosen against a ten-stud ball. The
meshed canopy is half as wide again, so `buildTrees` jitters the depth and
then `math.max`es it against the canopy's own reach. Same argument as
`Config.auditFences` and `auditEconomy`: the failure is a number, nothing
errors, nothing looks wrong from a plan view, and a canopy standing over
somebody's piggy should not be something the next edit to `scales` can bring
back. Verified live at a worst clearance of **7.54 studs past a fence line
measured off the real Yard parts** rather than off the constant.

The front grove row moved 14 -> 22 studs behind the fence to pay for the
bigger canopy, which is tuning rather than the guarantee: at 14 roughly half
the row would have piled up against the clamp on one line, which reads as a
hedge. Measured after, the nearest trunk sits at |z| 180.4 against a clamp
floor of about 175, so the clamp never actually bites and the row keeps its
full jitter.

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

**AND THE FOUR BALLS BECAME ONE PROLATE SPHEROID, BECAUSE A BEAD CHAIN READS
AS RINGS AND CANNOT BE TUNED OUT OF IT.** The entry below is the reasoning
that produced the chain and it is kept, because the diagnosis was right and
the construction was not. Reported, exactly: *"you can see the rings used to
build it instead of it being smooth"* -- and it showed on every resident on
the street, since `ResidentModel` is this same geometry.

**THE CAUSE IS A NORMAL BREAK, NOT A GAP.** Consecutive spheres in that chain
meet at a **33-degree** discontinuity in surface normal. Each ball is
separately smooth-shaded, so where one emerges from the last there is a hard
lighting seam -- and the eye reads a shading discontinuity far more strongly
than the **2%** groove in the geometry that causes it. Chasing the groove
would have been chasing the wrong number.

**MORE BEADS MAKES IT WORSE, AND THE ARITHMETIC SAYS THE OPPOSITE.** Eleven
balls on the identical cone halve every individual break -- 33 degrees down to
about 11 -- and the render is unambiguously worse: a repeating fine crease
reads as CORDUROY, where three coarse ones read as three rings. Photographed
against four and against the replacement, side by side, because the
calculation predicted "smoother" and the picture did not agree. **A REPEATING
SEAM IS A TEXTURE. Making each instance smaller multiplies it.**

**`SpecialMesh` WITH `MeshType.Sphere` TAKES A NON-UNIFORM `Scale`, WHICH IS
THE ONE THING A BALL PART WILL NOT DO.** This file already records that three
balls sized (6,6,6), (12,6,6) and (6,12,6) render pixel-identical, and that a
`UnionOperation` is the usual escape from it -- that is what the training-hood
capsule is squashed with. A SpecialMesh is the far cheaper escape for a shape
that is only a stretched sphere: ONE part, no CSG, no server-only template to
prewarm and clone past the client, and no seam anywhere on it because there is
only one surface. A prolate spheroid is also the only single primitive in this
engine that genuinely TAPERS.

**A CAPSULE WAS THE RUNNER-UP AND IS WORTH KNOWING ABOUT.** A cylinder and a
ball at the SAME diameter are tangent, so there is no rim at all -- the same
dimension-match rule the drip statue's own holdall already turns on. It
renders perfectly smooth and it is blunt: a rounded tube, no taper. Right
answer for a snout, wrong one for a nose.

**IT IS SEATED TO REPRODUCE THE OLD PLACEMENT RATHER THAN RE-COMPOSED.**
Centred on the chain's own start point with a half-length of 0.45 along the
same axis, which puts the tip **0.293** proud of the skull against the chain's
0.289. The profile changed and the prominence did not, which is the second
time that sentence has been true of this nose.

**AND MEASURING THE EYE CLEARANCE CORRECTLY REVERSED THE ANSWER, WHICH IS THE
PART WORTH KEEPING.** Sampling the WHOLE eyeball says the new nose intrudes
**0.012** into the white, against the chain's +0.038 of clearance -- which
reads as a regression and is not one. An eyeball is set INTO the skull, only
**23%** of its sphere is outside it, and every intruding sample is in the
buried 77%. Against the VISIBLE surface the nose clears by **+0.266**, seven
times what the four balls managed. Same correction this file already records
for the turtle's ear, where testing the convenient point put it 0.067 inside a
hair ball it is nowhere near: **TEST THE SURFACE THAT CAN BE SEEN, NOT THE
SURFACE THAT IS EASY TO ENUMERATE.** Nearly narrowed a nose to fix a clip
nobody could ever see.

**A `ViewportFrame` DOES RENDER A `SpecialMesh`, AND THAT WAS CHECKED RATHER
THAN ASSUMED.** This file's rule is that a viewport draws BaseParts and
nothing else -- no particles, no beams, no lights -- so a mesh modifier on a
part was a real risk for the shop card that renders this ornament. Two
viewports side by side, a plain Ball against the same part carrying the
stretched sphere: sphere on the left, egg on the right. It renders.

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

**A PARTICLE'S COLOUR IS A FUNCTION OF HOW BIG IT IS ON SCREEN, AND A
SIX-COLOUR PALETTE CAN RENDER AS ONE WHITE.** The rebirth fireworks burst in
six colours. Photographed from **213 studs** -- a viewer on the road, which
is where the whole feature is aimed -- every burst came out the same white
cloud. Photographed from 60 studs the identical bursts read pink, green,
violet and amber.

The palette was innocent. A 2.6-stud particle at 213 studs is a few pixels,
and what survives that is the TEXTURE'S BRIGHT CORE rather than the tint
over it -- `LightEmission` at 1 blends fully additive on top, so every
channel clips. `burstSize` 2.6 to 4.5 and `LightEmission` 1 to 0.25, and the
same shot reads orange and ice-blue as separate colours. **The two are one
decision**: a small particle needs the core, a big one does not.

It is the Martian skin's lesson on a different object, and it has the same
shape as the CSG-hole rule: nothing errored, no probe could see it, and only
a picture taken AT THE DISTANCE THE THING IS READ FROM could say so. A
screenshot from arm's length would have passed it.

**AND A FLASH RATE IS THE GAP LESS ITS JITTER, NOT THE GAP.** The same
fireworks shipped at `gap 0.45, jitter 0.15` under a comment reading "2.2 a
second, comfortably under" the three-flash ceiling. 2.2 is the MEAN. The
fastest draw is 0.30s, which is 3.3 a second and OVER the ceiling, about one
launch in six. Two numbers multiplied without anybody checking the product,
which is the most-repeated post-mortem in this file, this time in my own
comment justifying the number.

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

**THE STANDING COUNTDOWN IS THE ONLY THING ON THIS HUD THAT GIVES A PLAYER A
REASON TO STILL BE HERE IN TEN MINUTES.** Everything else reports what has
already happened or is happening now -- a toast, a banner, an alarm. This is
the one element that is about the future, and its whole job is that somebody
decides to stay.

**IT NEEDED NO NEW SERVER STATE, WHICH IS WORTH SAYING BECAUSE IT LOOKS LIKE
IT SHOULD.** `EventService` already models the quiet stretch as a PHASE with
its own deadline -- `setPhase("quiet", "", period - warning)` -- and already
pushes seconds left, plus seconds total since the banner wanted it. The whole
countdown was arriving at every client and being dropped on the floor, because
the render branch opened with `if phase ~= "quiet"`. The feature was a display
that had never been written, not a mechanism that was missing.

**THE ROLL WAS ALREADY RANDOM TOO.** `pick()` runs at the moment the quiet
stretch ends, weighted with the last pick damped rather than excluded, so "a
random event starts after the countdown" is a description of what already
happens rather than a thing to build.

**TOP-RIGHT UNDER THE PIGGY BANK PANEL, and that is a decision about what KIND
of thing it is rather than about free space.** The top-centre column is
alerts; this is not an alert, it is a standing readout of the state of the
world, which is exactly what the panel above it is. They belong together, and
the chip is right-aligned to the panel's own edge -- verified aligned to the
pixel with an 8px gap. It is also the only band left: measured on the live
HUD, the panel ends at y 88 and the next occupied pixel in that corner is the
shop button at y 665.

**PAPER, NOT A COLOUR, FOR FOURTEEN OF EVERY FIFTEEN MINUTES.** A saturated
ground here would read as an alarm, and this thing is furniture almost all of
the time. It earns colour in the last minute and not before: the badge RING
goes gold and the caption changes to GET READY, while the card stays paper --
because a chip that turns into a coloured block IS an alarm, and the banner
twenty seconds later is the alarm.

**A CHIP THAT SAYS THE SAME THING FOR FOURTEEN MINUTES IS WALLPAPER, AND
WALLPAPER IS WHAT A PLAYER STOPS SEEING.** `Config.EVENT_SOON` is the window
where it changes state, and it has to be comfortably longer than
`EVENTS.warning`: at 20 against a 20-second warning the chip would flip to its
loud state and vanish in the same frame, which is a flicker rather than a cue.
A minute is also about how long it takes to bank a full pig and get somewhere
useful, which is the entire reason for telling anybody.

**AN HOURGLASS, NOT AN EVENT'S OWN GLYPH, BECAUSE WHICH EVENT IS NOT KNOWN
YET** -- the roster is rolled when the quiet ends. A chip naming it early
would trade the surprise for a number nobody asked for. Measured before use
like every other glyph here: 37.0 at TextSize 40 against a tofu box's 20.0.

**IT IS GATED ON THE QUIET BEING A REAL ONE, NOT ON THE PHASE NAME, and that
is two live bugs rather than defensive tidiness.** A client that has not had
its first push yet holds total 0 and would render "0:00" as though an event
were overdue. And the scheduler stamps a two-second `setPhase("quiet", "", 2)`
on the way out of an event before the loop sets the real fifteen minutes, so
for up to a frame the honest reading of the pushed state is "next event in
2s". Testing the SPAN against the warning window rules out both with one
comparison -- verified live by pushing that exact seam payload and watching
the chip stay hidden.

**"GET READY" AND NOT "STARTING SOON", and the measurement picked it.** The
first ran 86px against an 80px caption box and would have clipped. The one
that fits also happens to be the better copy: it says what to DO, where the
timer beside it is already saying when.

Verified live: a fresh boot counting 14:29 down to 14:26, the muted ring on an
ordinary quiet, the gold ring and GET READY inside the last minute, and the
chip hidden for both the two-second seam and the whole warning phase while the
banner carried the news instead.

**AN EVENT GETS ITS OWN BANNER, AND SHARING THE PATROL'S WAS FLATTENING THE
ONE DISTINCTION THAT ROW EXISTS TO DRAW.** They were one frame with a branch
in it, so the street's headline and its routine traffic stop were the same
object in the same place with a different word in it. A patrol is the
heartbeat; an event is the thing a session gets built around.

**IT IS A SECOND FRAME AT THE SAME ANCHOR, NOT A RESTYLE**, which is the call
the dodge and trick buttons already make: two things that can never both be
live share a SLOT rather than a widget. The entry above is what guarantees
that -- the patrol waits out any event -- so exactly one is ever visible, and
each branch hides the other as belt and braces.

Sharing and branching is worse twice over. The patrol's row is measured and
verified (340 wide because the icon pushed its longest line to 277 of 282
usable pixels) and every future event feature would have to keep re-clearing
it. Split, the patrol's frame was not touched at all -- verified after, both
its phases still rendering at y 200..238 with the event banner hidden.

**44 TALL AGAINST 38, WHICH IS THE WHOLE COST.** It ends at y 244 rather than
238: measured against the shortest thing that has to work, a phone held
sideways at 546, that is 44.7% down against 43.6%. Anything that wants more
height here is spending the one axis this column has none of.

**THE BADGE IS A DARK DISC WITH A TONE RING**, for the third time in this
project -- the notify chips learned it, the prompt cards followed, and it is
the same fact each time: an emoji carries its own colours and ignores
`TextColor3`, so a saucer on a cyan disc is a cyan smudge. The ring is where
the tone goes, and the ring is what pulses.

**THE COUNTDOWN IS A BAR AND A NUMBER, because they answer different
questions.** "42s" is a thing you READ and a draining bar is a thing you SEE,
and this is read by somebody who is running -- the same argument the upgrade
pips make against "Lv 3/4". Both are kept: the bar for the glance, the number
for when it matters that it is nine seconds and not ninety.

**A BAR NEEDS THE PHASE'S TOTAL, SO THE SERVER SENDS ONE.** Inferring it from
the first `secondsLeft` a client happens to see is wrong for exactly the
player who most needs it right: somebody joining halfway through a raid would
watch the bar start full and drain from the wrong place. `phaseSpan` is
stamped in `setPhase` beside `phaseEnds`, so the two cannot disagree.

**THE FILL IS INK ON A FAINT GROOVE, AND THE FIRST VERSION MEASURED THE WRONG
PAIR.** A paper fill was chosen against the banner's own tone -- 1.71 (rush)
and 1.84 (raid), which looks like a catastrophe and is not the question. What
has to read is FILL against TRACK, and paper managed 3.32 and 3.56 there: a
bar you can see is there and cannot judge. Ink on a 0.75-transparent groove
reads 5.53 and 5.16 against the track and 8.74 and 8.16 against the banner.
It is also the language the theme already speaks -- a groove one step under
the ground is exactly what an unbought upgrade pip is.

**`Config.EVENT_UI` IS THE VOCABULARY, and the client used to carry it as a
branch.** Same shape as `Config.NOTIFY` and `Config.PROMPTS`: tone, glyph and
wording per event, so a third event is a row here rather than four `if raid
then ... else ...` in ClientMain -- which is the shape that broke the
anti-repeat rule at a two-event roster and would break again the same way.

**IT ALSO CLOSED A DRIFT NOBODY HAD NOTICED.** `roster[key].name` has always
said "ALIEN INVASION" and the HUD hardcoded "INVASION INCOMING", so the one
place a player learns an event's name disagreed with the one place it is
defined. The banner reads the roster now -- defensively, because the guard is
on `EVENT_UI` and a row added to one table and not the other would index a nil
inside the HUD's own Heartbeat and take the whole loop down.

**AN EVENT WITH NO ROW DRAWS NOTHING AND FALLS THROUGH TO THE PATROL**, rather
than rendering as an unnamed grey bar. That is the louder failure and the far
easier one to notice, which is the same reason `addTrail` warns on a ride with
no `accent` instead of picking a colour.

**THE GLYPHS MOVED OUT OF ClientMain'S OWN `GLYPH` TABLE, because two copies
of one character in two files is the near-identical duplicate this file keeps
recording.** Both were rendered and measured first, the way the `ICON` table
demands -- at TextSize 40 in GothamBold a real emoji advances 37.0 and a tofu
box advances 20.0, and both came back at 37.0. The bolt carries VS16 because
it is BMP and therefore HAS a monochrome text form: the same fault that made
the notify warning triangle render 4px narrower than everything beside it, and
a per-platform font decision rather than a promise.

**THE WARNING PULSES AT 1.67Hz, ground and ring together**, which is inside
the three-flashes-a-second ceiling `HouseFX` holds the whole game to. Ink on
both tones measures 8.74 and 8.16 lit, 5.21 and 4.86 at the bottom of the
pulse, so the label clears the body floor at every point in the cycle rather
than only at the top of it.

Verified live end to end on both events: the raid warning counting 20 to 0
with the bar draining 0.95 to 0.00, the flip to DRONES ON THE STREET resetting
it to 1.00, the same for RUSH HOUR into STEALS ARE DOUBLE, the badge ring
sweeping 0.00 to 0.55, the label never once shrunk by `TextScaled` (261 of 282
at its longest), and the patrol banner hidden for every frame of both.

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

**THE STREET'S LADDER OUTLIVES THE SERVER NOW, AND RANK IS THE ONLY THING
THIS GAME IS ALLOWED TO LET DECAY.**

This design has removed every form of LOSS on purpose and should keep it that
way. A plot is released when its owner logs off, so nobody is ever robbed
while away; a robbery never costs progress; rebirth keeps every cosmetic;
offline accrual runs eight hours and never decays. All four are deliberate,
all four are right for an audience of nine-year-olds, and none is negotiable.

What went with them, and was never a decision anybody made, is COMPARISON.
There was not one `OrderedDataStore` in the project -- both boards read
`Players:GetPlayers()`, so **every ranking in the game evaporated when the
server did.** Nothing anybody did on Tuesday existed on Wednesday, to them or
to anybody else, and there was no reason in the game to come back tomorrow
that was not simply more of today.

**BEING OVERTAKEN COSTS A PLAYER NOTHING THEY HAD**, which is the whole
point: no coins, no upgrade, no skin, nothing they can be made to cry about --
and it is the entire feeling of *I should get back on*. That is loss aversion
with no loss in it, and it is the only version of it this game may have.

**WEEKLY RATHER THAN LIFETIME, WHICH IS THE ARGUMENT BELOW WON A SECOND
TIME.** Most Wanted used to rank `data.totalStolen` and was unwinnable --
whoever had played longest wore it forever. A lifetime ladder here would make
exactly that mistake at a larger scale. A week is long enough that a good
session still shows on Thursday and short enough that somebody starting today
can win it. `Config.weekIndex()` is a UTC day index divided by seven, for the
reason `daily.lastDay` is a day index: no clock, timezone or region can get
between the save and the answer.

**THE WEEK IS PART OF THE DATASTORE KEY, WHICH IS WHAT MAKES THE RESET FREE.**
There is nothing to clear on Sunday night and no job to schedule -- the new
week reads an empty page, and the old one stays intact behind it. `data.week`
rolls over lazily, when it is next read or written, the same argument the
spree's expiry makes for having no loop.

**IT TOOK OVER THE LANDSCAPE BOARD, BECAUSE THAT BOARD WAS CELEBRATING THE
WRONG BEHAVIOUR.** RICHEST PIGGIES ranked live `data.coins`, so the biggest
name on the street was whoever had sat on their own lawn longest -- in a game
whose entire economy was rewritten to make that the worst way to play. **A
BOARD IS AN INSTRUCTION ABOUT WHAT IS WORTH DOING**, and that one was pointing
at idling. It is TOP THIEVES THIS WEEK now.

The pair still splits the way it always did, which is what keeps the two from
disagreeing: the portrait poster is ONE PERSON and RIGHT NOW -- who the patrol
is coming for, this session, which must stay in-server because it drives the
patrol -- and the landscape list is the LADDER. Two questions, two boards.
Only the list's question got better.

**WHAT IT COSTS: THERE IS NO LONGER A PUBLIC "LOOK HOW RICH I AM" SIGNAL.**
The plot sign still carries rebirths, the house and the skin, which is where
this file already says the boasting lives, and a full pig is still visible in
the coin pile. If it turns out to be missed, the answer is a third board
rather than putting idling back on the podium.

**WRITTEN ON A SLOWER CLOCK THAN THE BOARD REFRESHES.** The refresh loop runs
every five seconds; a `SetAsync` per player on that tick is 72 writes a minute
at six players against a budget of 60 plus 10 each, so it would be over the
quota on its own. Publishing runs on `WEEKLY_HEIST.refresh` instead, plus once
on `PlayerRemoving` -- the last robbery of a session is the one most worth
having on the board and is exactly the one a tick-only publish would miss. The
sorted page is cached for the same interval, because a board forty studs away
cannot perceive a tick of lag and the read budget is smaller than the write
one.

**A SORTED PAGE HANDS BACK USER IDS AND NOTHING ELSE**, so names come from
`GetNameFromUserIdAsync` and are cached per id -- a web call per row per
refresh would be eight of them every forty-five seconds for something that
cannot change. A failed lookup falls back to `player <id>`: a row with a
number on it is far better than no board.

**MOST WANTED IS A SESSION CONTEST, NOT A LIFETIME ONE, AND THAT IS WHAT
MAKES IT A CONTEST AT ALL.** It used to read `data.totalStolen`, the persisted
lifetime figure, which made it unwinnable: whoever had played longest wore the
label permanently and nothing a new player could do in an evening would ever
take it off them. So the one status in this game that cannot be bought was also
the one nobody could earn. `SocialService` keeps a per-session RAP SHEET
instead, counted on DELIVERY rather than on the grab -- loot tagged out of your
hands or confiscated by the patrol was never stolen, you were caught, which is
the same line `data.totalStolen` already draws.

**ROBBERIES IN A ROW ARE WORTH MORE AND COST MORE, AND THAT IS THE ONLY
THING IN THIS GAME THAT VARIES BETWEEN ROBBERIES RATHER THAN WITHIN ONE.**
The crack made a single robbery a decision and did nothing about the shape of
a SESSION: forty cracks in an hour were forty independent transactions, and a
run of five meant exactly what five separate ones meant. `Config.SPREE`
counts consecutive deliveries, decays when you stop, and is spent by being
caught.

**IT IS NOT THE RAP SHEET, AND THE TWO ARE TWO TABLES ON PURPOSE.**
`SocialService.heat` is the rap sheet: every coin taken this session, only
ever rising, and what the Most Wanted board ranks on. `spree` is momentum. One
field carrying both is the `busyUntil`/`napUntil` bug this file already
records at length -- two readers disagreeing about one number in opposite
directions, and a 30,000-coin item silently buying nothing.

**THE PAYOUT IS PAID FOR BY `pigSeconds`, AND THE AUDIT IS WHAT FORCED
THAT.** A spree multiplying the payout multiplies the robbing-versus-idling
ratio directly, because a thief on a run sustains max spree and that is
exactly what `robberyRates` measures. Measured before writing a line of it:
the base was 8.25x against a `ROBBERY_ADVANTAGE.max` of 10, so **there were
21% of headroom and a x2 spree needed 100%.** `RESIDENTS.pigSeconds` came
down 400 to 200 in the same change.

**SO THE TOP OF THE ECONOMY DID NOT MOVE AND THE BOTTOM DID.** Cold is 4.12x
and a maxed spree is 8.25x, which is what EVERYBODY earned before -- the
spree is HOW YOU REACH the old rate rather than a new number above it. What
got slower is robbing listlessly, which is the behaviour that should be
slower, and 4.12x lands inside the 3-5x this design has aimed at since the
loop was first measured. The dearest house went from 0.90 hours flat to 1.80
cold and 0.90 hot.

**THIS IS THE FIRST TIME THE PRODUCT OF TWO CURVES WAS CAUGHT BEFORE IT
SHIPPED RATHER THAN MONTHS AFTER.** `LOSS_CAP` x `HEIST_PAYOUT`, capacity x
income, a resident's pig x a capacity ladder -- every one of those is a
post-mortem in this file, found by somebody happening to measure. The audit
built one session earlier refused this one at design time. **THAT IS WHAT AN
AUDIT IS WORTH, AND IT IS WORTH MORE THAN THE BUG IT FIRST FOUND.**

**AND THE AUDIT NOW MEASURES BOTH ENDS, because a single sweep would miss
one.** COLD is what the FLOOR is about -- nobody should be punished for
playing at their own pace -- and HOT is what the CEILING is about, because
that is the best this game can be played and therefore what decides whether a
resident is a faucet. Measuring only one lets the other drift silently, which
is precisely what a spree multiplying an unmeasured payout would have done.
Verified flat at both ends: 4.1247 to 4.1247 cold and 8.2495 to 8.2495 hot,
across all 341 level and rebirth pairs.

**THE RISK HALF IS THE PATROL, NOT A NEW HAZARD.** A spree scales
`wantedFloor` down -- 1.00 to 0.40 across four steps -- so a thief working
fast draws a records check on a smaller rap sheet than the same thief taking
their time. That reuses the one system in this game that already hunts
people, teaches nothing new, and lands the cost on the chip the player is
already watching: the ring turns red sooner on a run. **VARIETY OF SITUATIONS
IS FREE AND VARIETY OF MECHANICS IS EXPENSIVE**, which is the rule this
design set itself when it decided what could go in section 8.

**THE MULTIPLIER IS READ BEFORE THE BUMP, AND THAT ORDER IS WHAT MAKES
"CONSECUTIVE" MEAN ANYTHING.** The delivery that STARTS a run pays 1.00 and
the one after it pays more. Bumping first would pay a bonus for the first
robbery of a session, and there would be no streak in it at all. Verified in
order: x1.00, x1.25, x1.50, x1.75, x2.00, then capped.

**IT EXPIRES LAZILY AND HAS NO LOOP.** Nothing in the game has to happen at
the moment a run lapses, so the honest implementation is to check the clock
when somebody asks -- which also means a player who logs off mid-run leaves
no timer behind to fire at a Player who has gone. `recordSteal` reads through
the same accessor, so a run that lapsed during a long walk home is expired
rather than silently continued.

**ANY ARREST BREAKS IT, WHICH IS A DIFFERENT QUESTION FROM THE RECORD.**
`clearHeat` wipes the rap sheet and fires only on a MOST-WANTED arrest,
because an ordinary bust deliberately leaves a record intact -- that is what
the thief was caught for. A spree is momentum, and being put in a car plainly
ends momentum, so `breakSpree` fires on both. It is also the whole reason the
risk half points at the patrol: what a spree buys has to be worth losing.

**THE PIPS ARE THE RUN AND THE RING IS THE STREET, which are two facts and
therefore two signals.** Four steps with three filled is a thing you SEE, and
this file already argues exactly that for upgrade rungs -- along with where it
stops holding, since at forty rungs a pip is 4.4 pixels and becomes noise.
Four is comfortably the pip end. The chip grew 12 pixels to hold them rather
than squeezing a fifth thing into a first row whose caption-to-amount gap
measures 20 pixels; it keeps the same x and width as the event chip above it,
which is what actually makes that corner read as a column. Verified live: 0
through 4 pips filling at 34px each, ring muted to gold to red, and the two
chips sharing x 606 and width 176 with an exact 8px gap.

**WHAT IS NOT VERIFIED IS A REAL DELIVERY.** The state machine, the ladder,
the decay, the break and the whole audit are measured; `deliver`'s two lines
that read the multiplier and name the run in the toast have been checked by
reading rather than by robbing somebody. The order is confirmed -- multiplier
at 2120, `recordSteal` at 2132, the toast at 2156 -- and the rest of that
function is untouched.

**AND THE WHOLE ARC WAS INVISIBLE WHILE IT WAS HAPPENING, WHICH IS WHY THE
RAP SHEET IS A CHIP NOW.** Take more, lead the board, draw a patrol: that is
a session with a SHAPE, and every part of it was built, tuned and argued
about here at length. The only places any of it ever surfaced were a poster
standing somewhere out on the street and a handful of toasts gone in six
seconds. A player could not answer *how much have I taken this session* at
all.

**SAME FAULT AS THE STANDING EVENT COUNTDOWN, ONE STEP FURTHER ALONG.** That
one was a display nobody had written rather than a mechanism nobody had built
-- `EventService` was already pushing the whole countdown and the render
branch was dropping it. Here the mechanism, the numbers and the tuning were
all present and there was no channel and no chip: `SocialService` fired
exactly two remotes, `Notify` and `RevengeMarker`, and `StateUpdate` carried
not one social field. **THE CHEAPEST THING IN THIS DESIGN IS ALMOST ALWAYS
DRAWING SOMETHING THAT ALREADY EXISTS.**

**IT IS THE SECOND CHIP IN THE TOP-RIGHT COLUMN, AND THAT IS A CLAIM ABOUT
WHAT KIND OF THING IT IS.** The top-centre column is ALERTS -- things that
just happened. This corner is STANDING READOUTS: the piggy bank panel says
what you have, the event chip says what the street is about to do, and this
says what you have done and whether it has consequences yet. Verified flush
with its neighbour, same x and same width, an exact 8px gap -- the event chip
ends at absolute y 130 and this starts at 138.

**THREE SIX-LETTER CAPTIONS, AND THE MEASUREMENT PICKED THEM.** The obvious
wording does not fit: at TextSize 12 in GothamBold "MOST WANTED" measures 88
and "PATROL COMING" measures 96 against a caption box of 82, so both would
have been silently shrunk or clipped -- the failure this file already records
as *"with `TextScaled`, it fits is guaranteed and means nothing"*. STOLEN,
WANTED and HUNTED measure 44, 52 and 49, so the chip never jitters as it
changes state.

**AND THE MEASUREMENT CAUGHT A SECOND THING NOBODY WAS LOOKING FOR: THE EVENT
CHIP'S OWN VALUE BOX IS TOO NARROW FOR COINS.** It is 44 wide, which is
plenty for the clock it holds ("14:29"), and at TextSize 17 "888.8K" is 55
and "999.9M" is 54. Copying its geometry across would have quietly shrunk
every large rap sheet in the game. The wanted chip's value box is 56.
**GEOMETRY THAT IS VERIFIED FOR ONE PAYLOAD IS NOT VERIFIED FOR ANOTHER.**

**THE RING CARRIES THE ESCALATION AND THE WORD DOES NOT**, which is the event
chip's own trick: muted while you are one thief among several, GOLD once the
poster on the street has your name on it, RED once your sheet clears your own
floor and the next patrol is genuinely coming. Three states, one property, no
flashing -- this is a standing readout and the toast announcing each
transition is already the loud half.

**NOTHING STOLEN MEANS NO CHIP, WHICH DELIBERATELY REVERSES THE ROB BADGE'S
RULE.** That badge had to learn to say YES as well as no, because an absence
is something a new player cannot read and WHICH PIG is the whole decision.
This is the opposite case: no decision rides on it, and a chip reading
"STOLEN 0" forever is wallpaper, which is what a player stops seeing. **ITS
APPEARING IS THE SIGNAL**, at the exact moment somebody becomes a thief.

**THREE FIELDS, AND NOTHING THE CHIP CANNOT HONESTLY DRAW.** The obvious
payload also carries the pursuit floor, the leader's name and the leader's
sheet, and none of the three has a reader: a floor is only ever asked about
the LEADER, so a bar toward one for anybody else would promise a consequence
that cannot happen, and a 176x34 chip holding a badge, a caption and a figure
has nowhere to put a second player's name. A field nobody reads is a field
nobody notices going wrong.

**PER CLIENT RATHER THAN BROADCAST**, the same call `StealCooldown` makes:
two of the three fields are about the RECIPIENT, and a floor is seconds of
the reader's own income, so two thieves standing together genuinely have
different ones.

**PUSHED ON THE BOARD'S OWN TICK, PLUS IMMEDIATELY ON A DELIVERY.** The tick
because the FLOOR moves with income and rebirths and nothing about buying an
upgrade would otherwise tell this service to look again -- eight FireClients
every `LEADERBOARD_REFRESH` is cheaper than a hook on every income change and
cannot go stale unnoticed. The delivery because that is the moment the number
changes, and a readout that waited five seconds would read as broken. It
fires AFTER `refreshMostWanted`, so the chip and the poster can never
disagree about who is wanted -- the same ordering the two board refreshes
already keep between themselves.

Verified end to end against REAL server state rather than crafted payloads:
the admin `mostwanted` command wrote a genuine sheet through the real
service, and within one refresh the chip read HUNTED / 1.7K with a red ring,
then hid again when the sheet was cleared. The push loop was watched with
nothing else running and fired at 1.56s, 6.58s and 11.59s -- 5.01s apart,
exactly `LEADERBOARD_REFRESH`.

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
which is now Q dodge/trick, B shop, V garage, R radio, I bag,
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
maxed player earning 2,994/s has to clear 179,677 to be worth a car, while a new
player at 10/s needs 600. The floor exists for one specific failure -- in a quiet
server, one player who lifted one small pile would otherwise be hunted every
eight minutes for the rest of the session.

**AND IT GATES THE PATROL, NEVER THE POSTER, WHICH IT USED TO DO BOTH OF.** As
a filter on who could LEAD the board it was answering a question it cannot
answer, and the board sat empty in exactly the servers that had a biggest
thief. THE TWO NUMBERS ARE MEASURED AGAINST DIFFERENT PEOPLE: the floor scales
with the THIEF's income and rebirths, while loot scales with the VICTIM's
vault. So a maxed thief robbing a poorer neighbour never clears their own floor
however many plots they empty -- the one status in this game that cannot be
bought was hidden from precisely the player who had earned it hardest.

Measured against the live curves, both players on the same level and the
victim's vault completely FULL, which is the best case a steal ever has: one
delivery is **0.4 to 0.8 of the thief's own floor**, so the poster wanted two or
three perfect robberies before it would name anybody, and 2.6 at rebirth 10 --
because prestige raises income and therefore the floor, while capacity does not
follow. Against a victim who banks, which is every victim, it is many more. It
read as broken because for most of a session it was.

**SO THE BOARD RANKS ON THE SHEET ALONE AND THE FLOOR IS ASKED ABOUT THE
WINNER.** Whoever has stolen the most is on the poster and wears the hat, full
stop; the floor then decides whether the patrol spends a records check on them.
That is the question it was always written for -- it is about the leader rather
than about who leads. `SocialService.getMostWanted` is the board and
`getPursuitTarget` is the pursuit: TWO QUESTIONS, TWO FUNCTIONS, the same split
`PassService` draws between `unlocked` and `owns`, and mixing them up here
either empties the poster or sends an officer after a child who lifted one
small pile.

**WHICH MAKES THE ALERT TWO LINES, because the board can now name somebody the
patrol is not coming for.** Promising a visit that never arrives is the same
fault as a patrol arriving with no warning, from the other end -- so a
below-floor leader is told *"Take more and the patrol will come"* and only an
above-floor one gets *"The next patrol comes for you."* The second is announced
on the TRANSITION as well as on taking the board, because the common shape is
reaching the top of the poster well before reaching the floor; without that it
would never be announced at all. Verified live at a sheet of 1,000 against a
floor of 16,286: poster named, hat worn, patrol ran a full cruise and deployed
NOBODY -- then over the floor, same player, officer out in 19 seconds.

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
every plot is within one and a half `PLOT_SPACING` of one pair. See the layout
section. The reasoning above is kept because it is the thing to re-derive if
the street ever gets long enough to want a second pair again.

**AND IT HAS BEEN RE-DERIVED ONCE, WHEN `PLOTS_PER_ROW` WENT 4 -> 5.** The end
column moved from one and a half spacings out to two, so the worst plot is
**168 studs** from the nearer board, against 128 before. Both boards carry
`MaxDistance = 0`, which for a `SurfaceGui` means no limit, and the failure
this entry was written about was measured at roughly 380 studs -- so there is
better than a factor of two in hand and a second pair is still not wanted.
**The number to re-derive is the worst plot-to-nearer-board distance, not the
street's length**, because the boards sit at its centre: another column adds
80 studs to the row and only 40 to this.

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

**THE GUARD DOG WATCHES THE APPROACH NOW, AND THAT REVERSES THE RULE THIS
ENTRY USED TO STATE.** It read: *"`GuardDog.chase` only fires from
`HeistService.attemptSteal`, AFTER a completed steal, so walking up to
somebody's piggy and holding their lock for up to twelve seconds carries no
dog risk at all. Every bit of pressure in this game is on the run home."* That
was true, it was the reason the Disguise Kit was sold as a WAITING tool, and
it is what made TIPTOE ship as a slower walk that nothing in the game could
notice -- a mechanic paying a bill that had not arrived.

A dog is now ASLEEP BY DEFAULT and woken by NOISE. Two noises, and both are
noise rather than presence, because standing still on a lawn is never a crime:

  * FOOTSTEPS above the breed's own `notice`. Walking (16) wakes any dog; a
    tiptoe (5.6, or 9.6 fully upgraded) wakes none but a Titan, whose `notice`
    of 0 means it hears anything that moves at all and has to be answered with
    a bone instead. Cheap counters bounce and the expensive one gets through,
    arriving at the approach.
  * A FAILED SLICE OF THE CRACK -- not the crack STARTING, which is the
    difference that makes the whole thing work. If merely working a lock woke
    the dog then every robbery would be loud, stealth would buy only the
    approach, and being good at the minigame would be rewarded with nothing.

**THE OWNER'S PRESENCE IS THE OTHER HALF, AND THE DOG'S POSTURE IS THEREFORE
THE TELL.** Owner IN: the dog patrols, and a thief should expect a fight.
Owner OUT: it sleeps in its kennel and the lawn is quiet until somebody makes
a noise -- and then it is the enforcer, because nobody else is. A resident's
owner is always away, which is what makes every unclaimed plot a dog's own
plot to defend. *A dog trotting about means somebody is home; a dog curled up
means the house is empty* -- free, no UI, readable from the pavement, using an
object that already exists and already moves.

**GUARD DUTY OVERRIDES BOTH, or the treat would sell the opposite of what it
does.** This file's own argument for the Guard Duty Treat is that it exists to
get people OUT of the house, because a player sitting on their own pig is the
worst outcome this design has. A dog that fell asleep the moment its owner
left would make the item worthless at exactly the moment it was bought for.

**IT READS SPEED MEASURED, NEVER `WalkSpeed` READ, and that distinction is the
whole feature.** `WalkSpeed` is what a character is ALLOWED to do, so a player
standing perfectly still reads 16 and would wake every dog on the street for
doing nothing. The watcher differences positions between ticks and asks how
far somebody actually went -- flat, because a fall is not a footstep and the
drop off a fence would otherwise be the loudest thing on the lawn.

**AND SPEED RATHER THAN A STEALTH FLAG, which is the half that keeps it
honest.** A boolean the dog has to check is a second piece of state that can
disagree with how fast somebody is moving; a threshold cannot. Everything else
then falls out for free: a thief snagged on an electric fence is quiet because
they are slow, and a thief CARRYING is always loud, because carry speed is
above every tier's threshold by construction. So you can sneak IN and you can
never sneak the money OUT.

Verified live on one lawn with one dog inside a single session: **22 seconds
of tiptoeing at 5.88 studs a second left Scruffy asleep in its kennel with no
chase at all; letting go of the sneak on that same lawn and walking at 15.97
brought it out in 2.0 seconds.** Against a `notice` of 11.

**IT DOES NOT POUNCE, and `wakeDelay` is what makes a crack a decision.** The
beat between being disturbed and being come for is what lets a thief hear the
dog stir and choose whether to finish or bail, rather than discovering the
outcome of a coin flip. The stir is stamped only on a FRESH disturbance and
never re-stamped by later ones -- otherwise continuous noise would postpone
the dog indefinitely, which is precisely backwards. What continued noise DOES
buy is a longer alert.

**THE WATCHER LIVES IN `HeistService` AND NOT IN `GuardDog`, and that is a
dependency decision rather than a filing one.** Deciding whether a dog should
react needs to know where every player is, which plot they are standing in,
how fast they are moving and who owns the ground. `GuardDog` knows none of
those, should not learn them, and would need PlotService and Players to do it;
HeistService already has all four. GuardDog keeps what a dog IS -- asleep or
up, alerted or quiet, and how good its ears are (`GuardDog.noticeSpeed`).

**TWO REASONS TO BE IN THE KENNEL SHARE ONE PICTURE, deliberately.** A dog
sleeping off a chase and a dog sleeping because nobody is home look identical
from the pavement, and they should: what a thief needs to read is *this plot
is unguarded right now*, not why.

**AND THE OWNER-HOME HALF OF ALL THAT WAS WRITTEN DOWN AND NEVER BUILT.**
`Config.DOG_WATCH`'s own comment has said, in as many words, since the
watcher was designed: *"OWNER HOME -- the dog is AWAKE and keeps its owner
company. It barks at an intruder and marks them, and does not chase: the
owner is the defence, and two things that can both hard-stop one thief on one
lawn is how a plot becomes a wall."*

There was no such branch anywhere. `releaseDog` asked `GuardDog.isReady` and
nothing else, so a present owner got a chasing dog AND a tag of their own --
the two independent hard-stops that sentence exists to prevent, on the one
plot that already has somebody standing in it. **SECOND INSTANCE OF "A RULE
THIS FILE ASSERTS IS NOT A RULE THE CODE KEEPS"**, after the number row that
claimed three times over to decline an unheld item and did not. Both were
found by reading the comment beside the code rather than by anything failing,
which is the only way this class is ever found.

**AND THE SECOND DEFECT WAS THE OPPOSITE OF THE FIRST: OWNER-HOME WAS NOT
MERELY FAILING TO BE GENTLER, IT WAS THE MOST DANGEROUS LAWN IN THE GAME.**
`shouldBeUp` is `onGuardDuty(dog) or dog.ownerHome or (heard and stirred)`,
and `isWatching` was built on it -- so `ownerHome` SHORT-CIRCUITED the third
clause, which IS the `wakeDelay` grace. A dog whose owner was home, or one on
guard duty, was "watching" before any noise at all and could be let off on
the first noisy tick with no beat to hear it stir. The beat is what this file
calls load-bearing -- *"the beat between being disturbed and being come for is
what makes a crack a DECISION rather than a coin flip"* -- and it was being
skipped on exactly the two plots with the most reason to be dangerous.

**THE FIX IS A SPLIT, AND THE TWO HALVES ARE GENUINELY DIFFERENT QUESTIONS.**
`shouldBeUp` is POSTURE: what a dog looks like from the pavement, and it
keeps all three reasons, because being paid for, being pleased to see you and
having heard something all put a dog on its feet. `isAlerted` is READINESS:
it heard you, and `wakeDelay` has passed. `isWatching` reads the second only,
so a dog may be UP for any of three reasons and LET OFF for exactly one.
Verified across fourteen cases including the two that were the bug, and
including the one that had to NOT regress -- guard duty still suppresses a
chase cooldown, while a bone nap still cannot be suppressed by it.

**THE MARK IS IN `HeistService` AND NOT IN `GuardDog`, AND THAT LINE IS THE
FILE'S OWN.** GuardDog owns the states it puts a DOG into and knows nothing
about players; a Highlight on somebody's character is a fact about a PLAYER.
So GuardDog gained `bark` -- the noise, pulled out from under `chase`, which
had owned it for as long as noticing somebody and going after them were the
same event -- and HeistService gained `markIntruder`.

**A BARK ALONE WOULD HAVE SWAPPED ONE FAILURE FOR ITS OPPOSITE.** An owner
looking the other way hears a dog and finds nothing, so a plot goes from a
wall to free. The mark is the same Highlight a carrying thief already wears,
in the alarm tone, expiring with `alertSeconds` -- and the THIEF can see it
too, deliberately, because this game prefers a tell to a fight: being marked
is information to act on rather than a punishment you cannot see. It is
refreshed rather than stacked, and the expiry checks a stamp, or an early
bark's timer would strip a mark a later bark had just renewed.

**SAME BARK FOR BOTH, WHICH IS A DECISION RATHER THAN A SAVING.** Giving the
alarm-only case its own noise would teach the street to tell "somebody is
home" from "nobody is" BY EAR, from safety, and stop anybody crossing a
guarded lawn. The tell for that is meant to be the dog's POSTURE, read from
the pavement before you commit.

**A RESIDENT'S OWNER IS NEVER HOME, so none of this touches the supply
side** -- every unclaimed plot still has an enforcer on it, which is what
makes robbing work on a quiet server. That is also why the branch is safe to
add without re-tuning anything: it is unreachable on the plots the economy
actually runs on.

**WHAT IS VERIFIED AND WHAT IS NOT.** The predicates are exact, on real
functions over the real field shape: 14 of 14 cases, including owner-home and
guard-duty-with-no-noise now correctly refusing. `bark` was driven on a dog
built by `GuardDog.build` at a real tier -- it never sets `chasing`, it
rouses a sleeping dog rather than barking from inside a kennel, and it is a
silent no-op at level 0. What has NOT run is the branch END TO END, because
the watcher skips the plot's own owner when looking for an intruder
(`player ~= owner`), so reaching it needs a SECOND PLAYER on a first player's
lawn. Same wall as the rest of the heist system.

**AND A THING FOUND WHILE TRYING TO TEST IT, RECORDED BECAUSE IT LOOKS LIKE A
BUG AND MAY BE ONE.** On a freshly rebirthed street every resident dog is
LEVEL 0 -- measured, all fourteen parts invisible and the nameplate unset --
because a resident's defences derive from the AVERAGE INCOME LEVEL of the
humans present, and a player who has just rebirthed is level 0. So the entire
watching-dog mechanic is inert for exactly as long as it takes them to climb
back. That is defensible (a beginner should not meet a Mastiff) and it also
hands a rebirthing veteran a street of undefended pigs, which is the half
nobody chose.

**THE WATCH LOOP IS PCALLED AS A WHOLE.** It touches every plot and every
player ten times a second, and a dog is a cosmetic-grade feature next to the
heist loop running underneath it. Same argument as the pcall around
`Decor.prewarm`: a lawn ornament may never stop the server starting, and a
watchdog may never stop the game being played.

**WHAT THIS COSTS, STATED PLAINLY: A LAWN IS NOW DANGEROUS GROUND TO ANYBODY
WHO IS NOT ITS OWNER.** Crossing a neighbour's yard at walking pace wakes
their dog and can cost 1.5 seconds of being seen off, whether or not you meant
to rob anybody. That is intended -- it is what the alley shortcut between two
yards should cost, it is what makes tiptoe worth buying, and the street is
sixteen studs away. If it ever reads as too harsh the lever is `notice` rather
than the watcher: nothing about the mechanism assumes a particular threshold.

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
back in. Loitering is not a mechanical problem here -- `STEAL_COOLDOWN`
already makes camping a plot pointless -- so the
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
standing next to them.

**AND THE PRANK IS GONE, WHICH REVERSES THE SENTENCE THAT USED TO CLOSE THIS
ENTRY.** It read: *"A prank cannot start, help or finish a robbery, because
the effect that matters in a chase still requires the target to be holding
somebody's coins."* That was offered as the safety property. It is also a
complete description of why NOBODY COULD HELP ANYBODY ROB ANYTHING.

Every mechanic in this game is adversarial except `FRIEND_BONUS`, which is a
passive multiplier you never DO anything for -- this file says so in as many
words under the alien raid. The obvious cooperative play, the one a pair of
nine-year-olds invent for themselves, is YOU HOLD THEM AND I TAKE THE COINS.
Measured against the code, it was impossible: a defender standing on their
own lawn while a friend cracked their pig could be hit and could not be
AFFECTED. 0.9 seconds, a stun capped to 0.3, and the raincoat not even
consulted. Three numbers refused the only co-op this design has.

**SO THE EFFECT OPENED TOO, AND THE COOLDOWN CARRIES THE WHOLE PROTECTION
NOW.** `Config.GADGET_GUARD` is what is left of `GADGET_FUN`: no duration cap,
no stun cap, just a rest afterwards. That is the right instrument and always
was, for the reason already written above -- it is keyed to the PERSON BEING
HIT rather than to the thrower, so the bound on what an entire server can do
to one child is the same bound as one player on their own, however many are
throwing.

**THE REST IS DERIVED FROM THE PENALTY IT GUARDS, which is the fence
penalty's own rule arriving somewhere else.** `Config.gadgetRest` is
`duration * 4`, floored at 4 seconds, so what is bounded is the DUTY CYCLE
rather than a number somebody typed: a target can be held for at most a
quarter of any stretch of time, and a longer gadget earns a longer rest with
nothing to remember. Measured live -- plunger 2.0s of effect buying 8.0s of
quiet, gum 2.2 buying 8.8, zapper 1.2 buying 4.8.

**THE RAINCOAT MOVED ABOVE THE CARRYING BRANCH, AND THE ITEM'S OWN SHOP COPY
IS WHAT SETTLED IT.** The ward check used to sit INSIDE `carrying`,
deliberately, on the argument that "letting a 1,500-coin joke burn one would
turn the cheapest item in the game into a way of stripping the defence off
somebody who was not even robbing anybody yet." The joke is not a joke any
more, so that reasoning expired with it -- but the tempting fix, letting a
coat block without being spent, would have made the Raincoat's own `detail`
("Stays on until something bounces") into a lie on a card a player has
already read. It blocks everywhere and is spent everywhere. One check now
serves both branches instead of two that can drift.

**VERIFIED AT SAMPLE TIMES WHERE THE TWO RULES ACTUALLY DISAGREE, and the
first pass was not.** Reading a plunger at 0.35s and 2.35s proves nothing: a
0.9-second prank and a 2.0-second hit are both "slowed" at the first and both
"recovered" at the second. Sampled at 1.40s instead -- WalkSpeed **11.20**,
where the old rule reads 16.00 -- and the zapper at 0.45s reads **0.00**,
where a stun capped to 0.3 reads 9.60. Also measured: a plunger bouncing off
a coat on a non-carrier and consuming it (WalkSpeed held at 16.00, `warded`
false afterwards), a zapper going THROUGH the same coat, and a second gadget
inside the rest window refused rather than landing.

**WHAT IS NOT VERIFIED IS THE THING IT WAS BUILT FOR.** Two players, one
cracking and one holding the owner off, has never happened -- same wall as
the rest of the heist system. Everything either side of it is measured.

**A GADGET IS AIMED NOW AND A BONE IS NOT, AND THE THING THAT MADE THAT
CHEAP IS THAT THE FLIGHT WAS DECORATIVE.** `GadgetService.arc` took a
position PROVIDER and re-read it every frame, lerping to wherever the target
had got to -- so a thrown gadget could not miss, at any range, against
anybody. The flight was an animation played over a decision the server had
already made. Two separate things were therefore missing from a throw: WHO
you hit (chosen by proximity) and WHETHER you hit (always).

**BONES KEPT BOTH, DELIBERATELY, AND THAT IS NOT UNFINISHED WORK.** The whole
"cheap counters bounce, the expensive one gets through" balance assumes a
bone LANDS -- `boneResist` is what makes a tier hard, not somebody's thumb --
and a dog is a small fast thing crossing a lawn at up to 17. Making that a
test of aim would re-price every dog tier by accident, and it would land
hardest on the half of this audience holding a tablet. Nothing in
`BoneService` changed.

**IT WAS A FIXED-POINT LOB FOR ONE SESSION, AND THAT VERSION IS THE MORE
USEFUL HALF OF THIS ENTRY.** The first aimed build threw along the FLAT
facing to a point exactly `spec.range` away, on a fixed parabola. It was
chosen so the remote could go on carrying nothing but a key -- the server
read the character's own `LookVector`, which it already had -- and so that no
player would ever have to judge a distance, which on a touchscreen is a fight
with the camera this file refuses to pick everywhere else.

Both of those were real and it was still wrong, for a reason no measurement
would have found: **every throw travelled the same distance whatever it was
aimed at.** Hitting somebody three studs away meant lobbing a plunger over
their head, and the whole thing read as tossing a bomb at a marked spot
rather than as throwing something AT somebody. A mechanic can be correct in
every property and be the wrong object.

**SO IT IS A BALLISTIC PROJECTILE.** It launches along the full aim, pitch
included, at `THROW.speed`, and `THROW.gravity` pulls it down for as long as
it is in the air. Three skills instead of two: point at them, lead them, and
**aim high for anything far away**.

**THE DROPOFF IS THE FEATURE AND THE TWO CONSTANTS ARE SOLVED FOR IT.** Drop
over a level throw is `gravity/2 * (distance/speed)^2`, so at 60 and 64,
measured live against `hitRadius` 4.5:

    10 studs   0.89 of drop   flat -- point straight at them
    18 studs   2.88           flat -- the zapper is a point-and-shoot weapon
    22 studs   4.30           the last distance that needs no thought
    26 studs   6.01           the gum's far end wants a little elevation
    34 studs  10.28           the plunger's far end wants real compensation

So a gadget is point-and-shoot at conversation range and a judged lob at the
end of its reach, with the change arriving GRADUALLY rather than at a line
somebody drew. That is what `hitRadius` actually buys: it is the distance at
which the drop stops mattering. Verified in flight -- a level throw travelled
25 studs and hit the ground 5.5 below the hand; the same throw at 20 degrees
of elevation reached **32.9**.

**GRAVITY IS OURS AND NOT `workspace.Gravity`, WHICH IS 196.2 AND WOULD MAKE
THIS UNTHROWABLE** -- a mortar rather than a plunger, 34 studs of drop over
34 studs of range. Two more reasons beyond feel: the client's preview has to
trace the identical curve and a shared constant is the only way two
implementations cannot disagree, and `workspace.Gravity` is a global somebody
may retune for JUMPING, which would silently re-aim every gadget in the game.

**AND THE REMOTE CARRIES A DIRECTION NOW, WHICH REVERSES A RULE THIS FILE
STATES REPEATEDLY.** `BoneThrow`, `GadgetThrow`, `placeLadder` and `CrackTap`
all send no position, and the reason is always the same: a coordinate on the
wire is one to forge and a range check to defeat. The lob version kept that
by reading the body's facing. **A ROBLOX CHARACTER CANNOT LOOK UP OR DOWN**,
so the moment the throw acquired a drop there was nothing on the server to
read a pitched aim from, and no arrangement of client-side rotation fixes it.

What the rule protected SURVIVES, and it is worth being exact rather than
waving at it. A direction is not a position: the server still owns the origin
(its own copy of the root), the speed, the gravity, the horizontal range cap,
the hit radius and every step of the simulation, and
`Config.throwClampDirection` is the single gate every aim passes through --
verified refusing nil, a non-Vector3, a zero, a NaN and a straight-up vector,
and clamping 85 degrees to 75. Forging a direction lets a client aim wherever
it likes, which is the FEATURE. At best it buys a perfect lead-and-drop every
time, which is **the same argument this file already accepted for the crack**:
the best outcome of a perfectly forged client is what a good player gets, on
an item that costs coins per throw and only slows somebody down. There is no
jackpot here to protect.

A malformed direction is not an error -- it falls back to the body's own
facing, which is a legal flat throw. Same call `RidePose` makes for an unknown
stance: degrade to the thing it is a variant of, never to nothing.

**FOUR THINGS END A FLIGHT AND THE RANGE ONE IS MEASURED HORIZONTALLY.** A
target passed within `hitRadius`; the WORLD, so a fence stops it and lobbing
one over is a real thing to do; `spec.range` measured on the FLAT, so
elevation buys airtime and never REACH -- measured any other way, aiming up
would quietly be a range upgrade on the one stat this tree is balanced with;
and a hard time cap. Tested every step rather than at the end, or a gadget
passes clean through somebody standing halfway along its path, and the order
inside a step is the old search's -- carrier, then drone, then anybody -- so a
thief in the path is still picked over a bystander beside them.

**A MISS COSTS, AND SAYING SO IS A DELETED REFUSAL RATHER THAN A NEW RULE.**
A throw used to search for a target BEFORE spending anything and refuse with
"Nobody close enough to throw that at." That was right while the server chose
the target. It is the wrong shape for an aimed throw: there is no such thing
as an invalid throw now, only one that did not connect, and a miss that
refunded would be a mechanic with nothing at stake in it. What is still
refunded is "there was nobody home" -- they left, died, got into a bin, or are
resting off somebody else's gadget -- which is a different thing from missing.

**THE PREVIEW IS THE FEATURE, NOT DECORATION, AND IT MATTERS MORE FOR A LOB
THAN IT DID FOR A FLAT THROW.** "Aim above them for distance" is not
something anybody works out from a toast that says MISSED. `Shared/ThrowAim`
traces the path through `Config.throwPointAt` -- the same function the server
flies the real thing along -- and draws it as sixteen beads with a ring where
it stops. Measured against real throws at five pitches, the ring and the
gadget's actual impact agree to **0.15 to 0.63 studs** on a range-capped
throw and about two on a ground hit.

**THE RANGE CAP IS INTERPOLATED BACK RATHER THAN REPORTED WHERE IT WAS
NOTICED**, and skipping that was worth 3.6 studs of lie in the one place the
preview is most read. A coarse trace step notices the cap a step LATE;
horizontal speed is constant, so horizontal distance is linear in t and a
lerp back to the boundary is exact rather than an approximation.

**`RenderStepped` DOES NOT FIRE WHEN NOTHING IS BEING RENDERED, AND THAT COST
MOST OF AN AFTERNOON.** The preview was connected there -- correctly, on the
argument that a CFrame written before the frame is drawn lands in the same
frame the camera moved. In a Studio session whose viewport was not drawing,
**Heartbeat ticked at 60 and a RenderStepped probe never fired once**: no
error, no warning, an empty workspace, and a feature that had worked an hour
earlier. It is the `RegisterKeyframeSequence` family from a new direction --
behaviour that depends on the ENVIRONMENT rather than on the code, so the
thing that proves it works is not the thing that runs it. It is Heartbeat
now; the frame of lag buys nothing here, because `AutoRotate` is off and
nothing else is writing that rotation.

**AND THE PARTS ARE BUILT IN `start` RATHER THAN ON THE FIRST STEP**, which is
seventeen invisible parts for a player who never holds a gadget and is worth
it twice over: it takes the allocation out of the hot loop, and it makes the
module OBSERVABLE. The folder existing means `start` ran -- so "not drawing"
can be told apart from "never switched on", which is exactly the distinction
that was unavailable while the only evidence either way was an empty
workspace. The step's own error is warned ONCE rather than sixty times a
second, for the reason this file already gives: a warning nobody can read is
not a report.

**AND THE ONE `lookAt` IN IT DOES NOT GET THE HALF TURN.** This file records
four bugs from `CFrame.lookAt` aiming LookVector at models authored facing
+Z. A CHARACTER IS THE EXCEPTION -- its front really is its LookVector,
measured, `FaceFrontAttachment` at head-local z -0.594 -- so adding the
correction would have aimed the body out of the back of its own head. Fifth
instance of the same line, pointing the other way.

Verified live end to end through the real remotes: the clamp refusing every
malformed payload, a level throw dropping 5.5 studs over 25 and the same
throw at elevation reaching 32.9, the preview capping at exactly the
plunger's 34, `AutoRotate` false while held and restored on put-away, the
projectile stopping on the world, stock spent on a miss, *"Your Plunger
missed."*, and the thrower -- whose own arc starts at their feet -- never hit
by it. Clean boot, no errors.

**WHAT IS NOT VERIFIED IS A HIT ON A PERSON**, because that needs a second
player standing in front of one. Same wall as the rest of the heist system.

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

**THE NUMBER ROW CLAIMED TO DO NOTHING FOR AN ITEM YOU DO NOT HOLD AND DID
TWO THINGS INSTEAD.** This file states that rule twice -- once beside the
shared-key argument for Q, once as "the client declines to ask rather than
firing something it knows is wrong" -- and the comment at the call site in
`ClientMain` stated it a third time. Nothing implemented it. Pressing the
number of an empty slot NAMED the item over the bar and asked the server to
draw one, which refused by name: two messages about something you do not
have, from a tile that is not even on screen, and the loudest way in the game
to discover you had run out.

**THE FIX IS IN `HotBar.itemForKey` AND EXPLICITLY NOT IN `keyOrder`.**
Filtering unheld items out of the ORDER is the tempting one-line version and
it reintroduces the bug this file already records: only SHELVING closes the
row up, because a stock running out is not the player's doing, so that slot
keeps its number and the number goes unused. Renumber on stock and the key
that threw a 1,500-coin plunger a moment ago throws a 22,000-coin zapper. So
the arrangement still contains the item, `keyFor` still hands its key to the
shop card advertising it, and only the PRESS declines -- `itemForKey` returns
nil, which the caller already treats as "not yours to press".

Note it tests `held` rather than `button.Visible`. They agree today, but
visibility is a fact about the screen and this is a question about stock --
and `shouldShow` hides the whole bar while the shop is open, which must not
be allowed to silently change what a key means.

Verified by driving the real module: with a Golden Bone in stock key 3 means
`golden` and its tile is visible; with the stock at zero the same key means
nil and the tile is hidden while `keyFor` goes on reporting 3; buying one
back restores it; and no other key changed what it meant in any of those
states.

**THE GENERAL SHAPE IS THE LESSON: A RULE THIS FILE ASSERTS IS NOT A RULE THE
CODE KEEPS.** Three separate places said this behaviour was true, which is
exactly what stopped anybody checking. Anything stated here as "the client
does not ask" is worth actually pressing once.

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

**AND IT TURNED UP A THIRD TIME, ON THE OTHER AXIS.** The inventory's tab
rail was sized 44 to hold a 40-tall selected tab -- correct for the BUTTON
and four pixels short of the button plus its border. Measured: the tab sat
flush on the rail's bottom edge at y 153.5 and its stroke wanted 156.5, so
three pixels were cut off along the exact line where the item grid begins,
and it read as the CARDS clipping the TABS rather than as a rail too short
for its own contents.

Two things worth carrying forward. **SIZE A CLIPPING BOX AGAINST THE TALLEST
STATE, NOT THE RESTING ONE** -- an unselected tab is 34 and fits, so the bug
only appears once somebody presses something. And **THE CLIP IS AT THE
FRAME'S BOUNDS, NOT INSIDE ITS PADDING**, which is what makes padding the
right instrument here: it moves the content inward while the clip stays put.

The first fix left ONE PIXEL under the bottom stroke and measured as
passing. That is the same class of number as a label reporting `TextFits`
true while touching its own frame edge, so it went to three -- verified
across all five tabs in BOTH heights, ten cases, every one clearing top and
bottom.

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

**EARN, DEFEND, ROB -- AND THE FIRST OF THOSE WAS ON A DIFFERENT SCREEN.** Earn
Faster and Bigger Piggy Bank lived on the HUD, bottom right, while the six
trees they compete with lived behind a shop tab. So the choice this whole
economy is built on -- every coin into income is a coin not into a fence -- was
split across two surfaces that were never visible at once, and only one side of
it was ever priced in front of you. The tab's own comment already claimed the
opposite: *"Both trees are shown side by side, always... that layout is the
message."* It was two thirds true.

**THE BAND GOES ACROSS THE TOP, NOT IN A THIRD COLUMN.** Three columns puts a
1/3-width card against a 122-wide price chip, which leaves 162 pixels for
"Bigger Piggy Bank" at 18px and truncates it. Full width also says the right
thing about the relationship: EARN is not a third tree, it is what both trees
are paid for.

**ONE CARD BUILDER FOR ALL EIGHT ROWS.** A tree row and an EARN row are the
same object -- name, explanation, level readout, price you press -- differing
only in parent, edge colour, width and what pressing it fires, so
`makeUpgradeCard` takes those four and `ensureRow` is a thin wrapper. A second
near-identical builder is the copy that drifts, which this file already records
for the mini piggy, `Decor.buildOne` and `RideSound`.

**A FORTY-RUNG LADDER IS NOT A LADDER.** Pips are right for a tree because four
rungs with three filled is a thing you SEE. Income and capacity run to
`Config.maxLevel` -- 20, and 40 once rebirths open the ceiling -- and measured
on the card this actually renders on, 40 pips share 337 pixels: **4.4 pixels
each carrying a 2px outline**, which is noise rather than a readout. Those two
rows get a continuous bar with `Lv N / M` printed on it, because at that
resolution the bar alone cannot tell 31 from 33 and the level is the thing
being decided on.

**AND THE KIND IS PASSED IN RATHER THAN DERIVED FROM `max`, which is the point
rather than laziness.** A threshold would flip these two rows from pips to a
bar partway through the game, at whatever rebirth pushed the ceiling past it --
so a player would watch a control they already knew change shape for no reason
they could see. The caller knows which it wants; `max` only knows a number that
grows.

**THE TREE COLUMNS SCROLL NOW, AND THE BAND IS WHY.** EARN costs them 158
pixels. Three rows of 96 plus gaps is 318, against a column window of 354 on a
desktop and 164 on a phone held sideways -- so the trees fitted by 36 pixels
before the band and would have overflowed by 154 after it. A UIListLayout does
not clip and does not error, it keeps drawing past the edge, which is exactly
how the tab rail once ate Rides and Collection whole. Verified both ways:
desktop `canvas 354 = window 354, scrolls=false`; at a 470-tall panel,
`window 164, content 318, scrolls=true`.

**THE EARN ROWS PAINT FROM `StateUpdate`, NOT `UpgradeState`, and the ceiling is
why that matters.** Income and capacity have always been pushed with the coins
they are priced against; moving the control did not move the data. `maxIncome`
and `maxCapacity` grow with every rebirth, so the bar's own LENGTH is state
rather than a constant -- which is the half a naive port would have hardcoded.

**AND THE HUD CORNER WENT FROM 210x172 TO 210x50.** Bottom right is the SHOP
button and nothing else.

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

**ONE RARITY LADDER FOR THE WHOLE SHOP -- EXCEPT SKINS, WHICH ARE THREE
TIERS NOW; SEE THE CONTENT-BUDGET ENTRY ABOVE. Everything below is unchanged
for the priced catalogues, which is all of them but one.**

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
sources in a fixed order.** (SKINS ARE THE EXCEPTION AND ARE ALL HAND-TAGGED
NOW -- they stopped being priced, so there was no price left to derive from.
The rule below still governs every catalogue that IS bought with coins.) An explicit `rarity` wins — the ten drop-pool
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
I opens the bag, Escape closes the panel, F2 the admin console, and the
number row is the hotbar. **G IS THE SMASH PROMPT NOW** -- see the smash
entry, where E opens a lock, F works the dial and G breaks the pig, which is
three adjacent keys for the three things you can do to one. Before that it was
free, and it was free because it threw the cheapest bone held, which was a second route
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

**THE DOGS WERE REBUILT IN CODE AND NOT AS A MESH, AND THE REASON IS THE
PIG'S OWN LESSON RATHER THAN A PREFERENCE.** A dog is organic and curved,
which is exactly the case this project sends to `generate_mesh` -- the pig,
the trees and the fence panels all went that way. It is still the wrong call
here, for one reason that outranks the shape: **`applyTier` REPAINTS THE
WHOLE ANIMAL PER BREED.** Four tone slots -- fur, furDark, collar, eye -- are
rewritten for each of three tiers, and a generated mesh gets ONE `Color`
unless it is segmented, while its baked texture cannot be prompted away and
would be muddy on at least two of the three. That is the same argument that
stripped `TextureID` off the piggy, one level worse: the pig multiplies 46
skins onto ONE shape, and the dog would multiply three palettes onto a mesh
authored in one of them. Three separate uploads is three moderation events on
the developer's own account, which this file already records as the most
expensive mistake in it.

**ONE PART LIST, THREE BREEDS, AND `scale` COULD NEVER HAVE DONE IT.** The
tiers differed by colour and by a uniform 0.8 / 1.0 / 1.3 -- so the Terrier,
the Shepherd and the Mastiff were the same animal at three sizes, which is
the "every robbery is the same robbery" complaint arriving in geometry.
`Config.DOG_TIERS.shape` is four numbers per breed, applied by `group` rather
than by part name so new geometry costs nothing:

    leg       how tall it stands
    girth     how heavy it is, ACROSS and THROUGH -- never along
    head      how much of the dog is head
    earDroop  degrees of hang

**`girth` DELIBERATELY DOES NOT TOUCH Z, and that is not fussiness.** Scaling
all three axes makes a stocky breed LONGER, which is the opposite of stocky:
a Mastiff at girth 1.2 came out as a Shepherd that had been photocopied
bigger. Width and depth only.

**LONGER LEGS ARE TWO CHANGES, NOT ONE.** Everything above the legs has to
rise by the same amount or the dog stands with its belly in the grass. `lift`
is derived from where a leg actually ends (`LEG_TOP`), so a breed's `leg`
factor moves the stance and the pivot together. Verified across a real
six-second patrol on the shortest-legged and the longest-legged breeds: the
lowest point of the animal reads **-0.000** on every frame.

**AND THAT IS WHY `TORSO_Y` EXISTS.** The literal 1.9 was in THREE places --
`home` at build, `home` again in `layout`, and the PivotTo in `rouse` -- which
cost nothing for as long as every breed was one dog scaled, and would have
been wrong in two of the three the moment one breed's legs changed. It is one
constant and one `restCFrame` now. Same trap as `YARD_DEPTH`: a derived
constant that stops being derived breaks silently rather than erroring.

**THE EAR IS HINGED AT ITS ROOT, WHICH IS WHY `earDroop` IS FREE.** An ear
turned about its own centre swings half of itself into the skull -- precisely
what a hanging breed must not do. The stored offset is the ear's BASE and the
half-length is added back after the turn, so 0 degrees is a pricked terrier
and 112 is a mastiff whose ears hang beside its jaw. At a hundred studs that
one rotation is the difference between "big dog" and "Mastiff", and it is the
only one of the four numbers that changes the SILHOUETTE rather than the
proportions.

**THE HEAD GROUP SCALES ABOUT THE HEAD'S OWN CENTRE, NOT IN PLACE.** Grown in
place, the eyes and the brow stay where they were while the skull swells
around them -- measured on the Mastiff at head 1.24, where both eyes ended up
entirely inside the face. The same eye that has a note in this file about
sitting 0.08 proud of a flat face, disappearing for a completely different
reason twenty lines later.

**A CLEARANCE IS SPENT TWICE ON A MODEL THAT SCALES, AND THAT IS THE NEW HALF
OF THE COPLANAR RULE.** The houses are built at scale 1 and 0.02 of clearance
is plenty. A dog is multiplied by `girth` AND by `scale`, so a gap authored at
0.025 lands at **0.015 on Scruffy** and z-fights -- which is how a model that
audited clean at Rex's 1.0 came back with nine coplanar pairs at 0.8 and one
more at 1.3. Every clearance here is sized so the WORST combination (girth
0.94 times scale 0.8) still clears. **AUDIT A SCALING MODEL AT EVERY SCALE IT
SHIPS AT**, because the middle one is the one that passes.

**THE KENNEL IS A LITTLE HOUSE AND IT IS BUILT LIKE ONE NOW.** It was the last
thing in the game wearing `WoodPlanks` and `Slate` -- the exact two textured
materials the house pass removed everywhere else -- on the object that sits on
the lawn a thief walks across. Base course, framed doorway, ridge over the
roof panels, an eave each side and a food bowl: the house vocabulary at a
twelfth the size.

**AND IT HAD THE CASTLE-FINIAL BUG SITTING IN IT THE WHOLE TIME.** The sleep
puff was parented to `kennelModel:FindFirstChild("Roof")` against a kennel
with TWO parts called Roof, so it had always hung off the LEFT panel rather
than the ridge. Nobody would ever have reported it -- a wisp of smoke slightly
off-centre is not a bug anybody files. Both it and the nameplate's Head are
held by reference from the build loop now.

**AND THE PUFF HAS SINCE MOVED OFF THE KENNEL ENTIRELY, ONTO THE DOG'S OWN
HEAD.** The entry above fixed WHICH roof part it hung from and left the
premise alone: the comment beside it claimed the puff emitted from the roof
"so it stays put and stays visible even though the dog is tucked inside". The
dog is not tucked inside. `sleepCFrame` settles it at the DOORWAY, in plain
sight, and always has -- so the puff was labelling the building rather than
the animal, and had been for the life of the feature.

Harmless until the Dog Bed, which lets a dog sleep eight studs away: the puff
would then have hung over an EMPTY KENNEL, which is the one reading a thief
must never get. It says a plot is occupied when it is not. It is on an
Attachment on the Head now, so it rides `layout`'s per-breed resize and
follows the dog wherever it sleeps. **A TELL BELONGS ON THE THING IT IS
ABOUT**, and the way to find the ones that are not is to read the comment
beside them rather than the code.

**THE KENNEL IS A SECOND WARDROBE, AND IT REPAINTS THE HOUSE AND NEVER THE
ROOF.** `Config.DOG_KENNELS` is six skins over `wood` and `trim` -- the floor,
the three walls, the base course, the door posts, the lintel, the ridge, the
eaves and the food bowl. The roof is deliberately not in that set, because
`applyTier` paints it from the COAT's collar and it is therefore the one
surface on the model saying whose dog lives here.

So the two catalogues own two channels of one object: **the kennel says what
the house is made of and the coat says who lives in it.** Buy both and they
read as a set -- which is what `docs/MASTER-PLAN.md` wanted from rolling them in
one crate pool -- and it costs nothing to keep true, because neither can reach
the other's field. Verified live: with `royal` up and `glacier` worn, the wall
is `royal.wood` to the byte, the lintel is `royal.trim`, and the roof is
`glacier.collar` and matches NEITHER kennel colour. Toggling the skin off puts
the plain wood and trim back and does not touch the roof.

**THE NAME BOARD TAKES `wood` RATHER THAN `trim` OR `roof`, WHICH IS WHY THE
PAINTED NAME SURVIVES A SKIN.** Its label colour is a literal cream in
`GuardDog` rather than a tone, so the board and the writing on it can never be
skinned into the same colour.

**COINS RATHER THAN A CRATE ROLL, WHICH IS A DELIBERATE DEVIATION FROM THE
PLAN.** `docs/MASTER-PLAN.md` proposes rolling coats and kennels in one crate
pool. The coats shipped priced in coins, so a crate-only kennel would put one
half of a matched pair behind luck and the other behind a price. `rarityOf`
derives a tier from `cost`, so a priced catalogue borders itself and cannot
drift when a price moves -- and the first kennel added that is NOT bought with
coins needs an explicit `rarity` or it silently falls through to `common`.

**AND `auditEconomy` WAS NOT WALKING EITHER OF THEM, WHICH IS THE GAP RATHER
THAN THE NUMBERS.** The coats had been priced for a session against a
catalogue list that names nine tables and did not name theirs. Nothing was
wrong -- 12M is well under the largest possible pig -- and nothing would have
said so if it were. `DOG_COATS`, `DOG_KENNELS` and `DOG_TOYS` are in that
table now, and **the test for membership is whether an entry carries a `cost`,
not whether the thing feels like a shop.**

**`unlockall` HAD THE SAME SHAPE OF HOLE AND IT IS WORSE, BECAUSE IT IS THE
TOOL YOU LOOK FOR THE HOLE WITH.** It has returned "Every skin, effect, house,
accessory and ride unlocked" since it was written, and three catalogues landed
after it. A dev opening the shop found a dog coat locked and had no reason to
suspect the COMMAND rather than the feature. It covers all three now.

**DOG TOYS DO NOT ADD A BEHAVIOUR, THEY REPLACE A DESTINATION.** The dog
already walked to a random point inside `DOG_PATROL_RADIUS` every few seconds
and already settled at its kennel door. `Config.DOG_TOYS` is three objects --
a ball, a water bowl and a bed -- and all a toy does is become where one of
those two walks GO. That is the whole reason it is cheap, and it is why
`patrolTarget` exists as a function rather than four lines inside the loop:
every destination now returns through one point.

**TWO THINGS KEEP A TOY FROM CHANGING AN OUTCOME, AND BOTH ARE STRUCTURAL
RATHER THAN PROMISED.**

* **Every destination is CLAMPED to the yard.** `clampToYard` insets the
  fence rectangle by the dog's own half-length scaled by breed, so no toy
  offset anybody types later can station a guard dog through a fence.
* **A TOY IS SILENT.** The bark is the "a dog has seen me" signal a thief
  reads from the pavement, and this game has exactly one of those on purpose.
  A ball that squeaked would be a bought object making that noise for no
  reason at all, which is worse than noise: it would train players to ignore
  the real one. The ball bounces and says nothing.

**AND `settle` IS THE DESTINATION THAT DOES NOT GO THROUGH `patrolTarget`,
WHICH IS EXACTLY WHERE THAT GUARANTEE HAD A HOLE.** Lying down is a walk the
dog makes more deliberately than any patrol step, and it was the one place the
clamp did not reach. `sleepCFrame` clamps its own result now -- **not**
`settle`, which would have been worse than not clamping at all: the dog would
have walked to the clamped point and then lain down at the unclamped one,
which is the two-copies-of-one-position bug that function exists to avoid.

**THE BED MOVES WHERE A DOG SLEEPS, AND IT SURVIVES THE TELL RULE BECAUSE THE
TELL WAS NEVER THE KENNEL.** What a thief has to read is *this plot is
unguarded right now*, and that is carried by the sleeping POSTURE, the puff
and OFF DUTY on the nameplate -- all three of which follow the dog. Measured
live: with the bed out the dog walks 8.93 studs from its kennel and lies at
the bed spot to 0.00 studs, torso dropping from a standing 2.20 to 1.88; with
the bed put away it sleeps at the doorway to 0.00 studs at 1.49. The 0.39
between those two is `BED_TOP`, the cushion's own thickness, derived from the
bed's geometry rather than typed.

**A ROBLOX CYLINDER IS SOLID, SO A "RIM" LAID ON TOP OF A BOWL IS A LID.** The
water bowl copied the kennel's own food bowl, where a wider disc sitting above
the body is exactly right because that bowl is empty scenery. Measured, the
rim spanned y 0.500 to 0.820 against water at 0.690 to 0.790 and therefore
CONTAINED it: a 25,000-coin Water Bowl with no water in it, and nothing would
have errored. There is no annulus primitive to reach for. The lip is a wide
shallow disc LOW on the body now and the water is the highest thing on the
object -- the moat's kerb rule from the other end, where the eye takes the
highest line as the surface.

**A TOY'S COLOURS LIVE IN `Config` AND ITS SHAPES LIVE IN `GuardDog`, BECAUSE
THE SHOP CANNOT REQUIRE A SERVER SERVICE.** A card draws a two-tone swatch
from `body` and `trim`, the same pair a skin and a coat send. Colours in the
geometry and colours again in the payload would be the near-identical second
copy this file keeps recording -- and the failure shape is known and specific,
because an item with no swatch renders as a blank cream tile, which is what
eleven effects did before they got a gradient.

**AN AUTHORED TRANSPARENCY HAS TO BE STASHED, NOT READ BACK.** Putting a toy
away writes `Transparency = 1` over whatever it was, so the bowl's translucent
water would have come back opaque the first time it was taken out again. It is
an attribute on the part, which lives and dies with the thing it describes --
the same call the ride footsteps make with their stashed volume.

**A KENNEL-LOCAL OFFSET CANNOT BE LEFT BEHIND BY A KENNEL THAT MOVES, ONLY
MADE WRONG -- AND THAT WAS WORTH EVERYTHING IT COST.** The toys were solved
against a kennel at plot (26, 17) with no rotation. The kennel then moved to
(25, 16) with a quarter turn, in a separate change for a separate reason, and
because the offsets are kennel-local they travelled with it and landed
measurably in the wrong place: all three behind the building, with the BED
sitting on decor slot `lawnH` where an ornament would have stood inside it.
Nothing errored, because every part involved is `CanCollide` false.

**A PLOT-LOCAL OFFSET WOULD HAVE BEEN THE WORSE FAILURE**: it would have gone
on pointing at the old corner with the kennel nowhere near it, which is a bug
nobody would think to look for. Local means a MEASUREMENT to redo; global
means a relationship silently severed.

**MEASURE THE KENNEL, NOT ITS WALLS.** The re-fit put the bed 0.42 studs from
the kennel because it was solved against the wall line. Measured live the
kennel spans plot x 20.25..29.75 -- its roof panels are pitched at 28 degrees
and reach a stud further out on each side than anything holding them up. Same
family as measuring a house by its bounding box and getting its FX at
altitude: the convenient number and the load-bearing one are different
numbers.

**AND THE BED IS DELIBERATELY OFF THE REST SPOT.** The dog rests at plot
(17.85, 16) and the bed starts at z 17.05, so settling down is a four-stud
walk. A bed the dog is already standing in makes the one toy that changes
behaviour look like it changes nothing.

**THE MCP SANDBOX BOUNDARY IS A PROBLEM FOR MUTATION AND FOR LIVE STATE, AND
TRANSPARENT FOR PURE CONSTANTS AND FOR ANYTHING CONTENT-ADDRESSED.** That is
the usable form of a rule this file has previously stated as a flat warning
about requiring modules there, and the two halves were arrived at from
opposite directions in one session.

The known half is that requiring a SERVICE hands back a fresh module whose
`start()` never ran. The part that is not obvious is that it applies to a pure
DATA module too: deleting `Config.DOG_TOYS.ball` from a sandbox script left
the live `dogstate` command still listing `ball`, because the sandbox and the
running services hold two different tables. **YOU CANNOT RETIRE A CATALOGUE
ROW AT RUNTIME TO TEST A RETIREMENT.**

**AND THE FAILURE SHAPE IS THE WORST ONE A TEST HARNESS HAS**: the guard under
test reports as not firing when the guard was never reached, so the harness
ACCUSES THE THING IT IS TESTING. A cycle went into concluding a retired-key
fallback was broken when it was fine. Same family as `commands.spares`
re-granting the item a probe had just sold, and as the `table.concat` probe
that reprinted a stale toast: **read state through a channel that does not
also write it, and never let a harness set up the state it is measuring.**

**WHAT CROSSES THE BOUNDARY SAFELY IS WORTH KNOWING, because the blanket
version of this rule stops people using the sandbox at all.** Two cases,
both measured:

* **A pure constant.** Reading `Config.SNEAK_ATTRIBUTE` through a sandbox
  require to check a live attribute is safe: there are two tables, and the
  value is the same string literal in both, so a `true` coming back proves
  the server wrote that same name. The distinction is READ against WRITE, and
  it is the whole difference.
* **Anything content-addressed.** `RegisterKeyframeSequence` returns a hash of
  the sequence, so a sandbox copy of a module and the real one converge on the
  IDENTICAL animation id by construction rather than by luck -- two module
  instances, two registration caches, one animation. That is a property to
  rely on rather than a coincidence to be nervous about.

The way to test a retirement is the boring one: delete the row ON DISK,
restart Play, and let a save that still names it meet a catalogue that does
not. Verified that way -- a save holding `kennel = "midnight"` against a
Config with no `midnight` row rendered the plain wooden kennel, threw nothing,
and dropped to five cards in the shop.

**AND THE TENTH LUAU FORWARD REFERENCE TOOK THE WHOLE SERVER DOWN, IN
`PlotService` THIS TIME.** `KENNEL_X`, `KENNEL_Z` and `KENNEL_YAW` were
declared beside `FENCE_BASE_Y`, about 280 lines BELOW the `buildPlot` that
reads them -- so to that function they were nil globals. `CFrame.Angles(0,
nil, 0)` threw *Argument 2 missing or nil* inside `buildPlot`, which took
`PlotService.start` and then the whole of `Main`: ten plots, every service
after them, and no "Ready" in the log at all. The message names a line that
looks fine and nothing points at the declaration. **When something reads nil
and the error names nothing useful, check declaration order first** -- and the
lesson that keeps repeating is that hoisting a constant to sit beside a
RELATED one is not the same as hoisting it above its READER.

**A DOG IS A TAPER, NOT A BOX.** One slab for the body and one cube for the
head, at the same width and the same height with nothing between them, is why
the Mastiff -- whose fur and furDark are both nearly black -- read as a single
shapeless mass with two glowing eyes on it. Chest, barrel and haunch at three
different widths, a raised neck, a muzzle that projects past the skull with a
nose on the end, a brow ridge, and paws wider than the legs above them. That
is 24 parts against 14, and the brow is the one carrying the most weight: it
is the only thing on a flat-shaded face that casts a line over the eyes.

**AND THE FIRST BUILD OF IT WAS TOO BIG, WHICH ONLY A PICTURE SHOWED.**
Measured at 7.8 studs nose to tail at scale 1, the Mastiff came out **10.9
long -- nearly as long as the piggy bank and visibly longer than the kennel it
is supposed to sleep in**. Every number in the audit was green. Pulled in to
9.9 against a kennel 9.5 deep. A big dog should be big; it should not be
furniture.

**THE TAIL NEEDED A KINK, AND TWO SEGMENTS DO NOT AUTOMATICALLY MAKE ONE.**
Authored at 32 and 58 degrees they are close enough to collinear that they
render as ONE straight plank sticking out of the back at forty-five degrees --
two studs of it on the Mastiff. Nearly level, then sharply up, is what reads
as a tail.

**WHAT WAS VERIFIED, AND THE ONE THING THAT COULD ONLY BE CAUGHT IN MOTION.**
All three breeds build and repaint; zero coplanar pairs at every scale; zero
textured materials; nothing collides or answers a query; the guard-duty tell
survives a tier change mid-duty; level 0 hides the animal and its kennel; and
a real patrol runs with the feet on the ground and the SNOUT LEADING on every
frame. That last one is the check that matters, because `facing` exists
entirely to undo `CFrame.lookAt` aiming a model's -Z, and a dog that walks
backwards is invisible in any still.

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

**THE WHOLE GAME WAS RENDERING ON THE LEGACY VOXEL LIGHTING PIPELINE WITH A
`Retro` TONEMAPPER, AND NEITHER OF THOSE WAS A DECISION ANYBODY MADE.** Asked
to make the street brighter and more colourful, the first thing to find was
that most of what was wrong had nothing to do with any number in
`WorldService`: two settings that live in the PLACE FILE, that no script in
this repo touches, were deciding how every colour in the game landed.

**`Lighting.Technology` IS `RobloxScript`-GATED, WHICH IS THE STRONGEST MEMBER
OF THE CAPABILITY FAMILY THIS FILE ALREADY RECORDS THREE TIMES.**
`RenderFidelity`, `RegisterKeyframeSequence` and `MaterialVariant` are all
"works in the MCP sandbox and the command bar, refused from a real Script",
because those two run with PLUGIN capability. This one is a level above:
measured, the sandbox cannot even READ it --

    The current thread cannot read 'Technology' (lacking capability RobloxScript)

-- and it cannot write it either. So a plugin cannot set it, **which means
ROJO CANNOT SET IT**: the Rojo plugin applies `$properties` by assignment from
Lua, so a `Technology` row in `default.project.json` is silently ignored on a
live sync. It IS honoured by `rojo build`, which writes the file format
directly, so the row is correct and load-bearing for a fresh place and does
nothing at all for an existing one.

**SO IT IS THE `MaxPlayers` SHAPE EXACTLY, AND IT IS WORSE IN ONE RESPECT.**
That entry says the cap "is not code" and has to be changed by hand in Game
Settings, with `Main` warning when the place and Config disagree. Here there
can be no warning, because the property cannot be READ from a script either --
so there is nothing to compare and nothing to print. The only evidence
available from inside the game is a picture.

    Lighting -> Technology -> ShadowMap        (by hand, in the Properties panel)

**AND THE PARAGRAPH THAT USED TO SIT HERE SAID "NO SHADOW AT ALL", WHICH WAS
FALSE, AND IT WAS FALSE IN EXACTLY THE WAY THIS FILE ALREADY HAS A RULE
ABOUT.** The isolation test was a 16-stud cube on a bare 200-stud slab, one sun
at 51 degrees, `GlobalShadows` true, nothing else in the world -- and it was
photographed and read as showing nothing. On that reading the whole Voxel
diagnosis was built, and a shadow-casting experiment was written off.

Re-shot with the caster over the ROAD instead -- a flat, uniform, mid-dark
surface, with the camera placed at the spot the arithmetic said the shadow
would land -- **the shadow is plainly there.** It is very soft and very low
contrast, which is why it did not survive being looked for on a green slab in
a wide frame, and which is the actual finding: shadows in this game RENDER and
are nearly invisible.

**"I COULD NOT SEE IT" IS NOT "IT IS NOT THERE", AND THE ENTRY DIRECTLY ABOVE
THIS ONE SAYS SO IN CAPITALS.** *A CAPTURE IS EVIDENCE OF PRESENCE AND NEVER OF
ABSENCE* was written one session earlier about always-on-top billboards, and
then broken immediately on a different subject. The general form is worth
stating once more because it clearly does not stick: **to photograph an
absence, you have to compute where the thing would be and point the camera
there.** A wide shot that happens not to contain it proves nothing, and it
looks exactly like proof.

**WHY THE SHADOWS ARE FAINT IS A SEPARATE QUESTION AND IS PARTLY BY DESIGN.**
`OutdoorAmbient` fills shadowed faces nearly to the brightness of lit ones, so
there is little for a shadow to darken; the two ambients are now pushed toward
BLUE so a shaded face differs from a lit one in TEMPERATURE rather than only in
level, which is what the warm-sun/cool-shadow pairing below is for. The other
half is `CastShadow`, discussed at the end of this entry.

**WHAT IS ACTUALLY KNOWN ABOUT THE TECHNOLOGY, STATED AS MEASUREMENT RATHER
THAN AS DIAGNOSIS.** The property cannot be read or written from a script or
from the sandbox, so nothing in this repo can report what it is. `Lighting`
carries `RBX_LightingTechnologyUnifiedMigration` and
`RBX_LightingCompatibilityMigrated`, both true, which is Roblox having migrated
the place to unified lighting -- and on a migrated place the `Technology`
dropdown may be ABSENT from the Properties panel entirely, because there is
only one pipeline left to choose. So "it is Voxel and needs switching" is a
HYPOTHESIS that the evidence does not settle, and the honest statement is
narrower: the row in `default.project.json` is right for a fresh `rojo build`,
it demonstrably did not change anything on a live sync, and nobody can read
back which pipeline is running.

**AND THE TONEMAPPER WAS `Retro`, IN A `ColorGradingEffect` NOTHING IN `src/`
HAD CREATED.** A new place ships one in `Lighting`, and its preset decides how
every colour in the game resolves: `Retro` is the pre-2023 pipeline, which
clips highlights hard and desaturates as it clips them. On a street made of
pink pigs and green lawns that loses precisely the wrong end -- photographed at
one camera, the far hills washed to near-white and a full piggy rendered as a
white blob with a pink rim. `Default` rolls the highlights off instead: same
camera, the pig stays pink and the distance keeps its colour.

**THAT IS THE `GearPreview` TRAP WEARING A NEW HAT, AND IT IS THE MOST
EXPENSIVE INSTANCE OF IT SO FAR.** The rule already written here is that
anything staged in the DataModel and owned by no script is debris nobody
reconciles -- and it has previously cost a stray NPC and a floating gear panel.
This one was setting the LOOK OF THE ENTIRE GAME from a place file, so "a fresh
empty place plus this repo gives the identical world" was false of the
rendering while being true of every part in it. `WorldService` creates the
effect if it is missing and sets the preset explicitly now, which is what makes
that sentence true again. `Technology` is the half that still cannot be brought
into source control, and that is why it is written down rather than fixed.

**HAZE WAS EATING THE SATURATION IT WAS THERE TO ADD DEPTH WITH.** `Haze` 1.2
over `Density` 0.32 in a near-white atmosphere colour lerps everything past
about a hundred studs toward white -- so the far half of a 350-stud street,
which is most of what a player looks at while walking it, arrived bleached.
Atmosphere is kept, because it is what puts air between the street and the
hills; it is turned down until it separates distance without washing it, and
its colour moved off white onto the sky's own blue so that what it adds reads
as sky rather than as fog.

**AND THE BLOOM THRESHOLD WAS LOW ENOUGH THAT ORDINARY PALE SURFACES BLOOMED.**
At 1.1 the sunlit face of a cream wall cleared the bar, so the shopfronts, the
road markings and a full piggy all glowed -- which is a wash over the picture
rather than a glow on the things built to glow. **THE THRESHOLD WENT UP RATHER
THAN THE INTENSITY DOWN**, which is the whole difference between a bloom and a
blowout: lowering intensity dims the real emissives too, where raising the
threshold simply stops admitting things that were never emissive. At 1.7 the
set that reaches it is the set this project actually authored for it -- the
Neon house effects, the shop glazing, the neon skins and the piggy's coin lamp.

Note the four files that reason about `Lighting.Brightness = 2.4` against that
threshold. The exposure is the lever for "the image is too hot", NOT the
brightness: `ExposureCompensation` acts on the final picture, where `Brightness`
changes the sun's level relative to Neon and would silently re-tune every
emissive surface in the game.

**THE STREET LAMP WAS THE FOURTH NEAR-WHITE NEON THIS PROJECT HAS SHIPPED.**
`LampHead` was `(255, 240, 190)` on `Material.Neon` -- cream, chosen as "warm
lamplight", rendering as a white hole with a halo round it, and the two nearest
ones were the brightest objects in a frame that contained the sky. The Martian
skin, the palace's first lit colonnade and the townhouse window rank are the
other three, and the rule has not changed: **A NEON PART WANTS A DEEP COLOUR,
BECAUSE SATURATION IS WHAT SURVIVES THE BLOOM AND VALUE IS NOT.** A colour a
long way from white still has a hue left after it is rendered flat out; a pale
one has nothing left to be. It is a deep amber now and reads as a bulb.

**AND `CastShadow` IS SET `false` ON 88% OF THE WORLD, BUNDLED INTO A LINE WITH
TWO PROPERTIES THAT HAVE NOTHING TO DO WITH IT.** Measured: 5,634 of 6,383
parts, including the piggy's own body, every house wall and roof, and every
tree. Nearly every builder in the repo writes
`CanCollide, CanQuery, CastShadow = false, false, false` as one statement, and
`PiggyModel`'s comment beside it justifies the trio in one breath -- *"may never
body-block, never be raycast and never throw a shadow"*.

**THE FIRST TWO OF THOSE ARE GAMEPLAY RULES AND THE THIRD IS NOT.** A shadow
cannot body-block a thief and cannot eat a raycast meant for a piggy; it is a
pure render-cost decision that inherited a gameplay justification by sitting on
the same line. That is worth separating before anybody acts on it, because the
cost is real -- 5,634 casters on a game aimed at nine-year-olds with tablets is
not a free change, and the honest version is a pass that turns it on for the
things that define a silhouette and leaves the 1,463 grass tufts alone.

**IT IS DELIBERATELY NOT DONE HERE, AND THE REASON IS THAT THE TEST FOR IT WAS
NOT GOOD ENOUGH.** It was tried live -- 2,066 parts over 2.5 studs flipped on --
and the picture barely moved, which read as "shadows are not worth it". That
conclusion does not follow. Shadows in this world are faint for a reason that
has nothing to do with how many things cast them: `OutdoorAmbient` fills the
shaded faces almost to the level of the lit ones, so turning on two thousand
casters adds two thousand shadows that each have almost nothing to darken.

**THE TWO VARIABLES WERE MOVED IN THE SAME BREATH, WHICH IS WHY NEITHER WAS
MEASURED.** The honest experiment is one at a time: drop `OutdoorAmbient` far
enough that the shadows that ALREADY EXIST become clearly visible, and only
then ask whether more casters are worth their cost. Done the other way round,
a real improvement and a wasted one look identical -- and the wasted one is
5,634 parts of render cost on a game aimed at nine-year-olds with tablets.

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

This is what makes `screen_capture` usable on generated geometry in EDIT,
where the models do not otherwise exist.

**`screen_capture` CAN AIM DURING PLAY, AND IT CANNOT SEE AN ALWAYS-ON-TOP
BILLBOARD. THIS ENTRY HAS NOW BEEN WRONG IN FOUR DIRECTIONS.** It first said
the tool was edit-time only, untested and false. It was corrected to *"works
perfectly well during Play, with or without an explicit camera"*, also false.
It was corrected again to *"in Play the camera cannot be aimed"* -- and that
one is the interesting failure, because THE MEASUREMENT UNDER IT WAS RIGHT.

**THE ARGUMENTS ARE IGNORED; THE CAMERA IS AIMABLE ANYWAY. THE MEASUREMENT
STOOD AND THE INFERENCE ON TOP OF IT DID NOT.** Both halves of the old note
are real and still true: `camera_position` and `look_at_position` genuinely do
nothing during Play, and a write to `workspace.CurrentCamera` genuinely does
revert with `CameraType` flipping back. What was added without being derived
is the word CANNOT. A one-shot write reverts because the camera module
rewrites it every frame -- so re-assert it every frame and it holds:

    cam.CameraType = Enum.CameraType.Scriptable
    RunService.RenderStepped:Connect(function()
        cam.CameraType = Enum.CameraType.Scriptable
        cam.CFrame = CFrame.lookAt(pos, look)
    end)

then capture with NO camera arguments at all. Verified across a run of aimed
shots at chosen positions and fields of view, by two people independently. So
Play is photographable, and the clone trick is a convenience for EDIT rather
than the only way to see anything. Hand the camera back to `Custom`
afterwards, or the next capture looks stuck for a reason nobody will guess.

**AND IT DID NOT REPRODUCE IN THE 4.1 SESSION, WHICH IS RECORDED RATHER
THAN ARGUED WITH.** Everything above was followed exactly -- one held write,
one camera, no arguments -- and the camera provably MOVED (read back at the
position asked for) while `screen_capture` returned a frame PIXEL-IDENTICAL
to the previous one, from a viewpoint neither the character nor the script
had put it at. The tool also started Play of its own accord more than once,
and once timed out mid-call. Two things follow and only one of them is a
claim about the tool:

  * **A CAPTURE THAT MATCHES THE LAST ONE PIXEL FOR PIXEL IS NOT EVIDENCE
    OF ANYTHING.** Compare consecutive frames before reading a picture at
    all -- a cached frame and a correctly-aimed one are the same JPEG to
    everybody except the person who moved the camera.

  * **EDIT STILL AIMS PERFECTLY**, so the way past this is the clone trick
    the ride previews already use: stage the real module in Edit, shoot it,
    and destroy both clones. The rebirth fireworks and the delivery van were
    both looked at that way -- fireworks against a 64-stud ruler the height
    of the Neon Tower, the van beside a real patrol car at the real road
    height. What CANNOT be staged that way is anything needing a built plot,
    because Edit's workspace is Camera and Terrain and this whole world is
    built at run time -- which is why the doorstep crate is measured
    everywhere and looked at nowhere.

So this entry has now been wrong or incomplete in FOUR directions, and the
honest summary is that the tool's behaviour in Play is not stable across
sessions. Budget for that: do the looking in Edit where it can be relied on,
and treat a Play capture as a bonus rather than as the plan.

**THE MEASUREMENT IS NOT THE CONCLUSION**, and that is a DIFFERENT failure
from the ones recorded nearby. The inside-out gable comment and the
`UseJumpPower` flag were claims nobody ever checked. This is the opposite: a
measurement taken correctly, reported correctly, and then quietly widened by
one word when it was written up. It happened twice more in the session that
wrote this entry -- an ankle sign inferred from a table of genuinely verified
numbers, and "BillboardGuis made in the sandbox do not render" inferred from
an empty picture. Both were wrong, and both read as the measurement rather
than as something added on top of it.

**AND THE ALWAYS-ON-TOP PASS IS NOT COMPOSITED INTO THE IMAGE.** A
`BillboardGui` with `AlwaysOnTop = true` draws over the 3D scene in a separate
pass and the capture is taken before it, so SIX SYSTEMS ARE INVISIBLE TO EVERY
SCREENSHOT THIS PROJECT HAS EVER TAKEN while being perfectly fine on screen:
`PromptUI` -- which is EVERY prompt card in the game -- plus `RobberMark`,
`HeistService`'s carried-loot label, `PoliceModel`'s plate, `SocialService`'s
label and `ClientMain`'s revenge marker.

Proved by a SWAP rather than by a demonstration, and the swap is the part
worth copying. Two rigs in Edit, identical but for that one property, camera
aimed square at both: the `true` one is absent, the `false` one renders. Then
swap the property BETWEEN the two rigs and change nothing else -- the picture
inverts. That controls out position, colour, size, adornee and camera aim in
one move, and both anchor parts render in both frames, so the sandbox
provably builds things that draw. A single frame could have been luck; an
inversion cannot.

**THE FAILURE SHAPE IS THE DANGEROUS PART, AND IT NOW HAS TWO CAUSES: AN
UNAIMED CAPTURE AND AN UNCOMPOSITED ONE ARE INDISTINGUISHABLE FROM A THING
THAT IS NOT THERE.** A billboard that draws perfectly and a billboard that
draws nothing come back as the same picture. **A CAPTURE IS EVIDENCE OF
PRESENCE AND NEVER OF ABSENCE.** Two separate sessions concluded "this GUI
does not render" from exactly that, on a GUI a probe had already found built,
adorned and bobbing -- and one of them invented a second false finding
("BillboardGuis created from the MCP sandbox do not render") from the same
root, which the swap above disproves outright.

**AND THE HALF THAT OUTRANKS THE TOOL NOTE: NOT ONE PIXEL OF THAT CLASS HAS
EVER BEEN CHECKED BY ANYBODY.** Searched: every verification of an
always-on-top billboard in this file is PROPERTY-READING. The prompt cards are
recorded as verified *"by reading the card back off the screen rather than by
looking at it"*; the steal prompt's amount was checked by *"printing both
boxes' own edges rather than by looking at the card"*; the probe note beside
them is three more. Six systems, including every prompt card a nine-year-old
ever presses, and the pixels were never once looked at.

**A PROPERTY READ PROVES A THING WAS BUILT AND SAYS NOTHING ABOUT WHETHER IT
WAS SEEN.** Those are normally the same question; for anything drawn in an
overlay pass, or read from a distance, they are not.

**THE GUARD DOG'S DUTY VEST IS THE SHARPEST CASE AND IT IS NOT ABOUT
`AlwaysOnTop` AT ALL**, which is why the rule is stated one level up from the
tool. That vest exists for exactly one reason: so a thief standing on the
PAVEMENT can read it and decide not to come in. It is verified end to end --
`Transparency` and `Material` byte-checked, the collar confirmed never neon,
the plate confirmed reading ON GUARD, all fourteen dogs swept, and it survives
a coat change and a kennel re-skin mid-duty. Every one of those is a probe
standing next to the dog. The nameplate and the kennel board carry
`MaxDistance` 90, and **no property read can tell you a label was legible at
90 studs.** A feature whose entire purpose is being read from the pavement has
never been read from the pavement.

**SO SPEND THE TWO INSTRUMENTS ON THE RIGHT QUESTIONS.** A probe answers *is
it there, adorned, enabled, and saying the right words* -- exactly, and this
file is full of cases where only a number could settle it. A picture answers
*can it be seen*, and nothing else can. Reaching for the convenient one twice
is how six systems went unlooked-at for months.

**TO PHOTOGRAPH AN ALWAYS-ON-TOP ONE, BUILD A THROWAWAY COPY WITH THE FLAG
OFF.** Shoot that, destroy it, and leave the shipped flag alone. It is
load-bearing wherever it appears -- `RobberMark` replaced a Highlight
precisely so a thief cannot hide, and the whole risk half of the trade is that
the run home is visible -- so turning it off for a clean screenshot trades a
mechanic for a tool artefact. **THAT IS A FIX TO THE CAMERA, NEVER TO THE
FEATURE.**

**DESTROY BOTH CLONES IN THE SAME SCRIPT.** A clone left in
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

**EVERY GABLED ROOF IN THIS GAME WAS INSIDE OUT, FOR THE LIFE OF THE PROJECT,
AND A COMMENT IS WHAT PUT IT THERE.** `gable()` carried the line *"A WedgePart
is full height at its -Z edge and slopes to nothing at +Z"* and the code
faithfully followed it. **IT IS FULL HEIGHT AT +Z.** So both halves of every
gable rose toward the EAVES and met in a valley over the middle of the
building.

Measured on an untouched Stone Manor before anything was changed -- z offset
-9 to +9 across the ridge line: **23.69, 22.08, 20.46, 18.85, 17.77, 19.38,
21.00**. Lowest in the middle. Settled with a bare test wedge rather than by
argument: local z -4 gives a top at -3.20 and z +4 gives +3.20, so the
full-height edge is +Z.

It reached SIX ROOFS ACROSS FOUR TIERS -- cottage, townhouse, villa (x2) and
manor (x2). Nothing caught it because a roof here is one flat colour seen from
seventy studs away, where a valley and a ridge differ only by which way a
single shading gradient runs, and because NOTHING IN THE GAME READS A ROOF, so
there was no behaviour to fail. The fix is one swapped condition in `gable`.

**THE LESSON IS THE ONE THIS FILE KEEPS LEARNING FROM THE OTHER END: A COMMENT
IS NOT A MEASUREMENT.** It sits beside "a rule this file asserts is not a rule
the code keeps" and the `UseJumpPower` entry -- an assertion nobody re-derived,
believed for years because the thing it described never errored. It also cost a
second bug immediately: the new tiled roof COPIED that comment, so its courses
were laid on the correct plane while the wedge beneath them rose the other way
and stood straight through them, and twelve verifiably built, verifiably proud,
verifiably alternating tiles rendered as one flat slab. Two hours went into
"why are my tiles buried" before anybody measured the thing they were sitting
on.

**THE HOUSES ARE BEING REBUILT LOW-POLY, OPT-IN PER STYLE, AND NOTHING IS
DELETED TO DO IT.** `Config.HOUSE_REBUILD` is a set of style names; a style in
it stands its rebuilt builder and every other tier stands exactly the builder
it always had. Same shape as `Config.HOUSE_MESH` beside it and as the fence
rows: an empty table is the catalogue as it ships, so a rebuild can be looked
at on a real plot next to the originals and backed out by deleting a word.

**AND THE ROUTE WAS A GENERATED MESH AND IS NOT, WHICH REVERSES THE INSTINCT
THIS PROJECT HAS FOLLOWED SINCE THE PIG.** The pig, the trees and the fence
panels all went to meshes because they are ORGANIC OR CURVED -- shapes
primitives genuinely cannot make. A low-poly cartoon house is the opposite
case: the style IS flat polygons with hard edges and flat blocks of colour,
which is the native vocabulary Roblox hands you for free. Both were built and
photographed side by side on one lawn before deciding. The generated one is
warmer and better at painted detail; it is also PAINTERLY rather than
flat-shaded (the baked texture cannot be prompted away, which this project
already records), its windows read as dark rectangles from the pavement, and
it costs an upload under the developer's own account.

**WHAT ACTUALLY MAKES A HOUSE READ AS "OLD ROBLOX", measured against reference
art rather than guessed.** TEXTURED MATERIALS -- the originals use `Brick`,
`Slate`, `WoodPlanks` and `CorrodedMetal` where every low-poly reference is
flat colour, and `SmoothPlastic` throughout is the single biggest move and is
free. NO TILE COURSES -- a roof drawn as two bare wedges is a ramp. UNFRAMED
OPENINGS -- a flat rectangle of glass is a sticker; a frame, a sill and a
mullion cross make it a window. And NOTHING WHERE THE BUILDING MEETS THE
GROUND -- a plinth is what stops a house looking like a box resting on grass.

**AND `Material.Metal` IS THE SAME MISTAKE ONE SURFACE ALONG, WHICH THE
TROPHIES PAID FOR.** Metal is not a texture and does not appear in the list
above, so it slips past that rule -- and it SHADES a colour by the
environment rather than rendering it. Photographed side by side, the same
(226, 186, 86) came out bright gold on a plinth in `SmoothPlastic` and
OLIVE on a stack of bars two studs away that were supposed to be the same
metal. Nothing errored and the two colours were byte-identical.

**A COLOUR THAT HAS TO BE A PARTICULAR COLOUR IS FLAT.** Metal is right
where the thing being shown IS the shading -- a safe body reading as a
slightly different grey is what a safe is, and there is nothing for it to
disagree with. It is wrong wherever a second object in the same scene is
wearing the same colour flat, because then the material is quietly
asserting they are different materials.

**A ROOF COURSE IS LIFTED ALONG THE SLOPE NORMAL AND EACH ONE STANDS PROUD OF
THE ONE BELOW, and both halves of that were got wrong in turn.** Lifting in
world Y is not perpendicular to a slope -- at a 38-degree pitch a 0.28 lift in
Y is 0.20 along the normal against a tile half-thickness of 0.225, so every
course sat just inside the roof. And lifting every course by the SAME amount
is geometrically fine and visually nothing: parallel slabs at one offset are
COPLANAR, so they merge into a single flat plane and the overlaps cannot be
seen. The lift has to CLIMB toward the ridge, which is what leaves the lip that
reads as tiles.

**AND THE COPLANAR RULE IS AUDITED ON A HOUSE NOW RATHER THAN REMEMBERED.**
"Surfaces must never be coplanar" is already written in this file three times
over -- the road against the grass, the moat against the grass, the dog's eyes
against its own face -- and the first rebuilt cottage broke it EIGHTEEN times:
corner posts sized 0.7 square and centred at `w/2 - 0.35` put their outer faces
in the wall's own side plane, and in Z as well; rails sized exactly `w` wide
landed their end caps in it; and every window's mullions shared all four face
planes with the glass they crossed AND both Z planes with each other, right
across the middle of the brightest surface on the building. Reported as the
wood frame flickering, which is exactly what it was.

The audit is worth more than the fix: walk the AXIS-ALIGNED parts, and for
every pair look for a face plane they share, pointing the same way, with real
overlap on the other two axes. The rebuilt cottage is at ZERO. **THE EIGHT
ORIGINAL TIERS ARE AT 32 BETWEEN THEM, WITH THE NEON TOWER ALONE AT 13** --
so this flickering is not something the rebuild introduced, it is throughout
the houses this game already ships, and rebuilding a tier clears it as a side
effect.

**A NEON WINDOW WANTS A DEEP COLOUR, WHICH IS THE MARTIAN SKIN'S LESSON
ARRIVING ON A BUILDING.** Neon renders a colour flat out and the BloomEffect
takes it from there, so the pale (255, 206, 122) chosen as "warm lamplight"
rendered as flat white panes with no hue left in them. A saturated amber still
reads as lit and is still amber at full brightness.

**AND `size` DOES NOT DRIVE A GENERATION'S PROPORTIONS, IT ONLY BOUNDS THEM.**
A cottage asked for at 26 x 20 x 20 came back 10.3 x 20.0 x 12.3 -- a tall
narrow house fitted INSIDE the box at its own aspect. Wide and low has to be
said in WORDS. Worth knowing before a row of tiers is generated against the
silhouette ladder the catalogue is built on, where the cottage being low and
wide is the whole reason the townhouse above it reads as a different building.
Related: `segmentation: "explicit"` hands back SEPARATE MeshParts, which is the
only way to get multi-colour flat shading out of the generator without relying
on its painted texture.

**ALL NINE TIERS ARE REBUILT NOW, AND THE SWITCH IS STILL THE SWITCH.**
`Config.HOUSE_REBUILD` carries all nine style names; the nine ORIGINAL
builders are untouched in `House.luau` and are what a removed line falls back
to. The one thing to know before removing one is that the originals carry the
coplanar flicker this whole pass started from -- thirty-two pairs across the
eight of them, the Neon Tower alone at thirteen -- so backing a tier out
restores that with it.

**THE REBUILD IS A SHARED TOOLKIT AND ONLY THEN NINE BUILDERS, which is what
kept it from being nine copies of the same mistake.** `tiledRoof`,
`framedWindow`, `windowBand`, `quoins`, `column`, `steps`, `parapet`,
`capRoof` and `pediment` are the whole vocabulary; a tier is mostly a
composition of them. That is why the z-fighting could be fixed at ten sites
rather than at a hundred and forty.

**`pediment` EXISTS BECAUSE `gable` CANNOT MAKE ONE, AND THEY LOOK LIKE THE
SAME OBJECT.** A roof slopes across DEPTH and is as wide as the building; a
pediment slopes across WIDTH and is a hand thick. The turn is a quarter about
Y -- which puts a WedgePart's full-height +Z edge onto world X -- and the two
halves take opposite signs so both tall edges land at the centre. And
`capRoof` exists because `tiledRoof` is fifteen parts, which is right for a
building and absurd for a dormer four studs across.

**THE FIRST BUILD OF THE EIGHT HAD 142 COPLANAR PAIRS AND ROUGHLY A HUNDRED OF
THEM WERE ONE MISTAKE.** A detail sized to land its foot EXACTLY on the thing
it stands on shares that thing's bottom plane over the whole overlap: pilasters
and corner posts on the plinth, door frames on the plinth, doors in their own
frames, wings and gatehouses against the keep, spandrels and columns against a
tower core. It reads as obviously correct arithmetic and it is a strobing seam
along the bottom of every one of them.

**SO THE RULE IS A CONVENTION RATHER THAN A LIST OF FIXES: ANYTHING STANDING
ON SOMETHING SINKS ABOUT 0.1 INTO IT.** Steps start 0.1 BELOW the ground and
stop 0.1 below whatever they land on, for the same reason at both ends. It
costs nothing, it is invisible, and it makes the whole class impossible rather
than fixing instances of it.

**THE OTHER FAMILY WAS A WINDOW BEING WIDER THAN ITS GLASS, AND IT IS SOLVED
IN `windowBand` RATHER THAN AT THE CALL SITES.** A sill oversails by 0.9 each
side and a pair of shutters adds 1.45 more, so a band spaced on the pane
overlaps its sills long before it overlaps its panes -- measured, five windows
over a 26-stud manor rank put every frame through its neighbour, on both upper
floors, which is a merged ledge as well as a coplanar pair. The `count`
argument is a CEILING now and the band fits what it can. A caller counting
studs is a caller who is wrong the next time a sill grows.

**A LIT WINDOW IS RIGHT AT TWO AND WRONG AT ELEVEN, AND THAT IS THE THIRD TIME
NEON HAS BEEN OVER-USED IN THIS PROJECT.** The cottage's two warm panes are
what the design was approved on. The same treatment on a three-storey
townhouse and a three-rank manor came back as rows of white-hot holes with the
wall colour bleached between them -- the Martian skin and the palace's first
lit colonnade arriving a third time, on a building. **THE GROUND FLOOR IS LIT
AND NOTHING ABOVE IT IS.** One sentence; symmetric, so it cannot fight the
manor's and the palace's whole composition; and it leaves the warmth exactly
where somebody standing on the lawn is looking. Everything above reads in pale
glass, and the building goes back to reading by its WALLS. Measured after: 1,
2, 3, 2, 5, 1, 1, 5 and 6 lit panes across the nine, against eleven or more on
three of them before.

**THE FOUR ANIMATED TIERS KEEP THEIR EXACT FX COUNTS, and that was a
constraint rather than a coincidence.** Modern 7, tower 39, palace 20, castle
22 -- the same numbers this file already records as verified. Effects were
MOVED where the new geometry demanded it (the tower's risers had to come
outboard of thicker corner columns, or they were buried in them) and never
added or dropped, so nothing in the light show needs re-verifying.

**AN FX TEST THAT BUILDS ITS OWN HOUSE MEASURES REGISTRATION, NOT ANIMATION,
AND IT REPORTS A CONFIDENT ZERO.** `HouseFX.start` scans by tag for ten
seconds after startup and then relies on `GetInstanceAddedSignal` -- which
never fires for these, because `House.build` tags parts inside a DETACHED model
and parents it at the end, the trap this file already records for the shop
doors. So four houses built in a live session read `dColour=0.000` on every
part, which looks exactly like a broken animator. Sample the parts that are
ALREADY TAGGED on the client instead: 99 of 104 moving, all six effect kinds,
with the five still ones sitting at the dim end of a chase.

**WHAT IT COSTS: 1,032 PARTS ACROSS THE NINE TIERS, AND HOUSES ARE 14% OF THE
WORLD.** Measured on a live street: 4,768 BaseParts with 670 of them houses.
Tufts are still the largest class in this game by a distance. This file's own
note stands -- performance was never the reason to cut anything here -- but the
manor at 212 and the palace at 186 are the two to watch, and both spend most
of their budget on quoins and window ranks.

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

**TWO AGENTS EDITING ONE FILE IS THE ONE COLLISION NOTHING IN THIS TOOLCHAIN
CAN CATCH, AND IT IS SILENT IN BOTH DIRECTIONS.** Several sessions work this
tree at once, and every other way they collide is recoverable by looking: a
crash names a line, a stale probe reports an implausible number, a half-boot
leaves the log short. Two documentation agents rewriting `docs/GAME.md`
together is different in kind. **BOTH REPORT SUCCESS**, each having written a
coherent document; the loser's work vanishes inside the winner's rewrite; the
file is under no lock, neither agent can see the other, and there is no error
and no conflict marker anywhere. The only evidence is a section that used to
exist and does not.

Caught as a near-miss rather than a loss, and only because the two sessions
happened to be talking: one announced it was taking the file and started in
the same breath, while the other's agent was already inside it. Killed before
it wrote, verified by checking the file rather than by trusting the kill --
heading count intact, mtime unchanged, none of its subject matter present.

**ANNOUNCING A CLAIM IS NOT HOLDING ONE. ASK, WAIT FOR THE ANSWER, THEN ACT.**
That ordering costs a message and it is the only thing standing between this
project and a silently half-rewritten document. It applies hardest to the
three files that are single sources of truth -- `CLAUDE.md`, `docs/GAME.md`
and `Config.luau` -- because those are the ones every workstream wants to
touch and the ones where a lost edit is least visible.

Note the SOURCE files are safer than the docs for a reason worth stating: two
sessions editing `GuardDog.luau` in different regions merge fine on disk,
because each writes a targeted replacement rather than a rewrite. It is the
whole-file rewrite that eats the other edit, and a documentation agent is the
thing in this toolchain most likely to perform one.

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

**A LOCAL CAN SHADOW THE FUNCTION YOU MEANT TO `Connect`, AND THE CRACK'S
DIAL HAD BEEN DEAD SINCE THE DAY IT SHIPPED BECAUSE OF ONE.** This is the
forward-reference family from the other end -- there the name resolves to a
nil GLOBAL, here it resolves to a perfectly good LOCAL that is the wrong
thing.

`Crack.luau` has a module-level `local function step()` which moves the
marker, and its `CrackState` handler opened with
`local step = (payload and payload.step) or 0` for the slice number. Twelve
lines later: `heartbeat = RunService.RenderStepped:Connect(step)`. Lua takes
the nearest binding, so the connect was handed a NUMBER and threw *Attempt
to connect failed: Passed value is not a function*, once per push.

**SO THE MARKER NEVER SWEPT, ON EVERY CRACK, FOR EVERY PLAYER.** The panel
opened, the gauge drew, the next-slice segment grew, the zone armed in the
right place -- and the one moving part sat at 0.

**IT WAS BLIND, NOT DEAD, AND THE FIRST WRITE-UP OF THIS SAID DEAD.** That
correction is the more useful half of the entry. `HeistService.crackTap`
computes `markerAt` from `crack.stepStart` and `GetServerTimeNow` and
compares it against the zone itself -- the server's marker sweeps whatever
the client is drawing, so taps landed at exactly the window's own width and
the minigame was WINNABLE BY LUCK the whole time. What was missing is the
only thing a player could aim with.

**THE EVIDENCE WAS ALREADY IN THIS FILE AND I WROTE PAST IT.** The crack's
own verification entry records a live robbery landing slices one to three
and a miss ending it -- which cannot happen against a dial nobody can hit,
and which reads instead as exactly what blind tapping at a 0.692-wide first
window produces. Same failure as the `screen_capture` entry: a measurement
taken correctly (the marker reads 0.000 and never moves) quietly widened by
one word on the way into prose ("unwinnable").

**WHAT IT ACTUALLY COST IS THE MECHANIC RATHER THAN THE ROBBERY.**
`Config.CRACK` is a greed dial whose whole design is that the pressure
comes from the dog crossing the lawn rather than from reaction time, and
the five windows narrow 0.692 / 0.561 / 0.454 / 0.368 / 0.298 so that
staying in gets harder. Blind, that ladder is a run of coin flips at those
odds: about 1.9% of clean five-slice runs against a competent player's
near-certainty. So the numbers this file records as tuned have never been
played the way they were tuned, and the first person to feel the narrow end
is looking at it for the first time rather than at a regression.

**IT SURVIVED BECAUSE THE ERROR LOOKED ENVIRONMENTAL AND THE FEATURE LOOKED
PRESENT.** This file already records that `RenderStepped` does not fire in a
Studio session whose viewport is not drawing -- true, and exactly what a
frozen marker looks like, so a probe reading `Marker.Position.X.Scale` as
0.000 gets waved through as a known tool artefact. It is not: this one fires
in every session on every machine, and the message names a LINE rather than
the shadowing.

**THE HABIT IS TO READ THE ARGUMENT OF EVERY `Connect`, NOT THE LINE IT IS
ON.** A handler passed by NAME is the one place in Lua where the wrong
binding is silent at compile time and merely refused at run time -- and
refused with a message that says nothing about which name it resolved. Any
`Connect(someName)` wants a look at what `someName` is bound to in the
innermost scope, not the outermost.

Found by driving a real robbery to verify something else entirely, which is
this file's own argument for end-to-end tests over probes: every property
read on that panel was correct.

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

**A CFRAME STORES ITS POSITION AS FLOAT32, SO CONVERGING ON A COORDINATE BY
EXACT COMPARISON NEVER TERMINATES.** The delivery van's drive loop clamped
its last step -- `math.min(speed * dt, endX - x)` -- so the van would stop
exactly at the end of the street rather than sail past it. That is the
obvious way to write it and it hangs: write 263.3 into a CFrame and read
back **263.29998779**, which is LESS than the double it is compared against.
So `x >= endX` stays false, the clamped step is a hundred-thousandth of a
stud, the write rounds to the same float32 again, and the loop runs forever.

Measured: a van parked motionless at the tunnel mouth, never destroyed, with
a scheduled loop behind it blocked for the rest of the server's life because
its guard reads the same field. **Nothing errored and nothing was in any
log** -- the failure looks exactly like a vehicle that decided to stop.

`PoliceService.driveTo` is immune ONLY because it stops within a stud of its
target (`math.abs(dx) < 1.0`) rather than on it, which is worth knowing
before anybody tightens that number. Either leave a tolerance, or -- as the
van does -- do not aim at the point at all and let it overshoot by a frame.
Anything else in this project that eases toward a coordinate wants the same
check: the ride stance's yaw, the lane change, the officer's approach.

**AND A LOOP OWNS THE THING IT WAS HANDED, NEVER THE SHARED FIELD NAMING
IT.** The same van drove the module-level `van` rather than the model it had
just built, on the reasonable-sounding argument that a van destroyed out
from under the loop should stop it. What it actually buys is that a SECOND
run silently steals the first one's loop -- both loops driving one model,
the other orphaned in the road with nothing left holding a reference to
clean it up. Same family as `busyUntil` carrying two clocks and `SUNK` being
read by two halves of the shop: one piece of shared state, two writers,
disagreeing in a direction nobody checked.

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

**AND IT CAUGHT THE RESIDENTS TOO, AS A PAIR OF SIGN ERRORS THAT CANCELLED IN
THE ONE STATE ANYBODY LOOKS AT.** The neighbours walked backwards up the
street. There were TWO wrongs, not one: `resident.facing` was seeded from
`plot.cframe.LookVector`, which is the plot's -Z and therefore points at the
HOUSE (plot-local +Z is the street, which is the whole reason an unrotated
plot CFrame seats them correctly), and the pose was driven through a bare
`CFrame.lookAt`, which put the figure's authored +Z at `-facing`.

**AT HOME THE TWO CANCELLED EXACTLY.** Standing, `facing` was backwards AND
the lookAt flipped it, so the neighbour faced the pavement and the build, the
nametag and every screenshot of a resident on their lawn were correct. The
moment one walked, `facing` became the true direction of travel, only ONE
error was left, and they moonwalked. **A BUG THAT IS ONLY WRONG WHILE
SOMETHING IS MOVING IS INVISIBLE IN THE STATE YOU CHECK IT IN** -- the same
shape as the wheelie lean being verified at its two endpoints and wrong all
the way between them.

**A PLACEMENT AUTHORED AGAINST A BUG INHERITS THE BUG, so fixing one thing
broke two more until they were fixed with it.** The loot was held at
`CFrame.new(0, 0.3, -2.1)` with a half turn on it, and both halves were
compensating: -2.1 was "in front of the chest" only while the front was -Z,
and the turn existed to stop the pig staring the other way. Straightening the
body made the mini a rucksack. Anything positioned relative to a thing that
was facing the wrong way has to be re-derived rather than kept.

**THE FIX IS ONE FUNCTION, WHICH IS THE POINT.** `facingCF(at, facing)` is
the only place either turn is written, so the fourth instance of this cannot
become a fifth at a third call site. Verified live rather than by looking --
the figure's front dotted against its own direction of travel, sampled every
frame: **1.000 mean and 1.000 worst across 2,041 samples and 300 studs**,
where the bug reads -1. A screenshot of a walking figure cannot tell you this
and the dot product can.

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

**THERE WERE FIVE PALETTES, AND THE FIFTH WAS THE ONE THE SWEEP COULD NOT
SEE.** The entry below counts four -- ClientMain, ShopStyle, Rebirth and
AdminPanel -- and every one of them is a CLIENT file. The physical boards are
built by `SocialService`, on the SERVER, so they were in neither the repaint
nor the contrast audit that followed it: eighteen hardcoded colours, including
two near-blacks at hue 264 and 272, which are VIOLETS against a palette whose
every neutral sits between 21 and 39. Nothing looked broken. They simply were
not from this game, and the only reason nobody noticed is that they are the
one interface you read from forty studs away.

**THE SCOPE RULE THAT MISSED THEM IS THE LESSON: "the UI files" IS NOT THE
SAME SET AS "the files that build UI."** Anything that constructs a GuiObject
is in the palette's scope wherever it runs. `Theme` requires nothing, so a
server service may take it -- what a server service may NOT do is reach for
anything animated or per-viewer, which belongs on the client for the reason
the moat and the animated skins already record.

**THEY WENT TO PAPER, WHICH IS THE THEME'S OWN ARGUMENT ARRIVING AT THE ONE
PLACE THAT HAD NEVER HEARD IT.** *Cream reads as a label stuck on the world;
navy reads as a window cut into it* -- and these are literally labels stuck on
the world, a printed sheet nailed to a wooden board. The dark backdrop filled
the panel edge to edge, which reads as a SCREEN set into the timber. The sheet
is now inset far enough to leave the wood showing all round, which is what
says it was pinned there.

**THE INSET IS 16px ON ONE AND 20px ON THE OTHER, WHICH IS THE SAME 0.8
STUDS.** This file already records that the two boards do not share a pixel
scale -- 20 per stud on the leaderboard against 25 on the poster -- and that
copying a pixel height across renders it visibly smaller on one of them. A
border is the same trap in the other axis. Choose it in studs, multiply up.

**GOLD ON ONE, RED ON THE OTHER, AND THAT PAIR IS THE WHOLE DIFFERENCE AT
FORTY STUDS.** Both headings used to be the same gold, so the only thing
separating the two boards from down the street was portrait against landscape.
RICHEST PIGGIES is money and stays gold; MOST WANTED is the board that says
somebody is coming for you and takes the alarm red, which is also its own
bounty's colour. Both in the darkened `_INK` forms -- raw gold on paper
measures 1.42:1, a heading you can see is there and cannot read.

**THE PHOTO WELL STAYS DARK AND ITS FRAME WENT FROM GOLD TO INK.** A well is a
hole and holds a photograph, so it keeps `SLAB_DEEP` while everything round it
went light -- the same call the shop's icon wells make. The gold frame round it
was correct on a dark board and is the wrong half of the contrast on a light
one; a printed photo has a dark border, and that line is also what stops the
dark well bleeding into the cream.

**AND THE AUDIT THAT PASSED THEM FIRST TIME WAS READING THE WRONG GROUND.** A
probe that takes `BackgroundColor3` sees neither the row stripe's TRANSPARENCY
nor the sheet's gloss GRADIENT, and this file has already been caught by the
gradient half once. Composited properly -- stripe over sheet, gradient
evaluated at each label's own vertical position -- the leaderboard's gold
AMOUNT column, the one number that board exists to show, measured **3.49**
against 3.98 on the alternate rows: passing, and visibly different every other
line. The stripe only has to separate rows, so it was lightened until that
column reads 3.83/4.25. Worst pair across both boards is now 3.83 over 23
labels.

**WHAT IS NOT VERIFIED IS HOW THEY LOOK.** Every number above is measured and
none of it was seen. The reason recorded here was that `screen_capture` is
edit-time only -- WHICH IS NOT TRUE, and was assumed rather than tried. It
captures the running viewport in Play, and accepts a camera position there
too, so anything in this file excused as unseeable because it is built at run
time is in fact one call away from a picture. The boards specifically are
still unseen; they are simply no longer unseeABLE. Same bucket as the Midnight Modern.

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
numerals fought the hue they were printed on. It went paper with the coin as
the only gold object on it, and the PIGGY BANK panel went the same way with a
drawn snout: pink and gold go on OBJECTS, never under them.

**AND THEN THERE WAS ONE READOUT, BECAUSE THE PIVOT LEFT THE TWO PRINTING THE
SAME NUMBER.** The sentence that used to close this entry -- *"gold is what
you have banked; pink is what the pig is still holding"* -- was the whole
justification for having a badge AND a panel: two balances, two readouts,
each in its own colour. `data.vault` merged into `data.coins`, and from that
moment the top-centre badge and the top-right bar were the same figure twice.
That is worse than redundant for a nine-year-old: two numbers side by side
assert that they are different things, and a player who goes looking for the
difference finds none.

So the badge merged INTO the panel and kept its shape -- icon, then figure,
read left to right, with the snout standing where the coin pip stood. The
panel's title row is the balance now; the bar's own label stopped repeating
it and names the CAPACITY instead (`of 3.0M`), or says `FULL` and what to do
about it, which is the one state of that bar that asks for an action.
Measured live: 30px figure against the badge's 30, nothing shrinking at
`999.9M` (84 of 140) or on the full line (208 of 276).

The colour rule survives the merge intact, and is in fact what made it cheap:
the card is paper, the gold is the BAR FILL, and the pink is the track behind
it. Gold in a pink pig, one object each.

**AND THE BAR SAYS HOW LONG UNTIL THE PIG IS FULL, WHICH IS PRESSURE THIS
GAME ALREADY BUILT AND NEVER SAID OUT LOUD.** A pig fills in 8 minutes at
level 0, 16.6 at level 20 and 27.7 at level 40 -- roughly ONE SESSION at every
level -- and a full pig STOPS EARNING. That is the clock the whole "spend it
or lose it" loop runs on, it is the one deadline in the game that is not a
timer somebody else set, and until now the only way to learn it existed was to
hit it. Delivery is also the only thing allowed to overflow capacity, so the
sentence the pair of them makes is *idle and you cap out; rob and you can go
past it, and then you are the best target on the street.*

**DERIVED IN THE RENDERER, NOT PUSHED.** `coins`, `capacity` and `rate` are
all already in that payload, so a fourth field would be a second way to say
something the first three already say -- and one of the two could go stale.

**SHOWN ONLY FROM HALFWAY UP.** "Full in 14m" on an empty pig is a number
nobody can act on, and the label is better spent naming the ceiling; it also
keeps the string short exactly when the balance is longest. Measured on a
detached clone with `TextScaled` off, which is the rule this file sets for
anything a Heartbeat rewrites: the longest new string is 140px of a 276px box,
shorter than the FULL line already living there at 175.

**THE HUD MAY ONLY EVER SHOW A BALANCE ONCE.** That is the rule this is
recorded for. There is one balance in this game; a second element printing it
-- however well drawn -- is a second claim about what a player has, and the
next one added will be a second claim that can also be STALE, since these are
painted from separate pushes.

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

**A STEAL PROMPT NOW SAYS WHAT IT IS WORTH, and until now the one number
that decides the whole action was the only thing not on screen.** The card
named the lock and timed the hold, so a thief knew exactly how long they were
committing to and nothing about what for -- and two neighbouring piles look
much the same from the gate. "Is that one worth the run home" is the decision
this entire game is built around.

**IT IS THE SERVER'S OWN ARITHMETIC, NOT A SECOND MODEL OF IT.** The plot
publishes its uncollected pile as `Config.PLOT_VAULT_ATTRIBUTE` from inside
`PlotService.updatePile` -- the one function the accrual tick, a steal, a
collect and `release` all already go through -- and the client multiplies it
by `Config.getStealFraction` and the live event multiplier, which is exactly
what `attemptSteal` does. Verified equal to the server's figure on a seeded
250,000 pile: 12,500 shown, 12,500 computed.

Presentation only, exactly like the steal HOLD one line above it in
`refreshStealPrompts`. The server re-derives the real amount on the trigger and
never reads a word of this.

**IT REVEALS NOTHING THAT WAS NOT ALREADY PUBLIC.** The coin pile on the lawn
has always shown how full a piggy is -- that is what it is for -- so this makes
an existing signal precise rather than adding a new one. It is the VAULT and
never banked coins, which are not stealable and are nobody's business.

**PRINTED WITH A "~" BECAUSE IT IS ALWAYS AN UNDER-ESTIMATE.** The pile fills
while the hold runs, so the real take is a second or two of accrual larger than
the quoted one. That is the right way round for a number a nine-year-old is
deciding on, and the tilde is what stops it reading as a promise.

**"EMPTY" IS A REFUSAL MOVED FORWARD.** `whyCannotSteal` rejects an empty piggy
outright, so the prompt used to sell a hold of up to twelve seconds that was
always going to end in a rejection toast. Same for carrying: you cannot rob
anybody while holding loot, and the card now says `Holding 87.5K . run home`
instead of looking completely available and finding out afterwards. **A PROMPT
THAT OFFERS AN ACTION THE SERVER WILL REFUSE IS THE SILENT-FAILURE RULE WEARING
A BUTTON.**

**THE CARD READ `ObjectText` ONCE AT BUILD, AND THAT WAS A LATENT BUG UNDER
EVERY PROMPT IN THE GAME.** It is built on `PromptShown` and never looked at
the prompt again, so anything a service wrote while a player was already
standing there never appeared. Caught here because the carrying line was being
written correctly and the card went on showing the lock -- but nothing about it
was specific to stealing. Both the amount and the detail are watched now.

**THE AMOUNT SITS ON THE DETAIL ROW, NOT THE VERB ROW, AND THE MEASUREMENT
CHOSE THAT.** The verb row carries "STEAL" at 60px and the key pill at 46px in
a 176px budget, so a late-game "~999.9M" at 56px left the verb two pixels to
truncate into. The detail row carries a 94px lock line in the same space. The
detail gives up width while an amount is shown and takes it back when it is
not, which is what lets the carrying line use the whole row -- measured at
160px of 172.

**AND IT IS PLAIN GOLD TYPE RATHER THAN A PILL, because the key chip on the row
above is already a gold pill** and a second one beside it reads as two controls
rather than as a price. `Theme.GOLD_INK` and not `Theme.GOLD`: raw gold on the
paper card measures **1.42:1**, a label you can see is there and cannot read.
The darkened form measures 4.87.

**THE FIRST BOXES OVERLAPPED BY 20 PIXELS AND NOTHING SHOWED IT.** Right-aligned
text does not draw outside its own frame, so an 84-wide amount sitting across
the detail's last 20px was invisible -- and would have started clipping the
first time either string grew. Caught by printing both boxes' own edges rather
than by looking at the card. Now 64 wide, D66..164 against A176..240.

**THE MECHANISM IS GENERIC ON PURPOSE.** `Config.PROMPT_AMOUNT_ATTRIBUTE` takes
an ALREADY-FORMATTED STRING -- the caller owns the wording, the same split
`CosmeticsService.awardTokens` makes with its optional `why` -- because PromptUI
is Shared and has no formatter in it. Handing it a number would mean a second
copy of one. Any prompt about money can carry one; today only the steal does.

**THE HOLD SHOWS HOW LONG IT IS, which is the HUD half of the vault-lock
problem.** A default prompt draws the same filling circle whether the hold is
three seconds or nine -- the reason that whole tree was once invisible to the
thief standing in front of it. The dial answers it from the street; over
`Config.PROMPT_COUNTDOWN_OVER` seconds the card answers it at arm's length
with a real countdown, so a thief knows they are committing to twelve seconds
BEFORE they commit. Verified on a 6s hold: bar 0.19 -> 0.80 linear, countdown
running down to 1.2s.

**AND A BADGE OVER THE PIGGY ANSWERS IT FROM THE PAVEMENT, WHICH IS THE ONE
PLACE THE PROMPT CANNOT REACH.** Everything above is the prompt learning to
say things up front, and it runs into a wall: a ProximityPrompt only exists
once you are ALREADY STANDING ON THE LAWN -- past the fence, past the dog, and
well past the point the decision was worth making. Every remaining reason a
piggy was off limits lived in the refusal, so the way to find out somebody had
been robbed a minute ago was to walk up their drive and hold their lock.

`Shared/RobBadge.luau` hangs a card over each piggy naming the reason, in the
same ORDER `whyCannotSteal` asks its questions -- shield, then cooldown, then
empty -- which is the only thing keeping the badge and the refusal from ever
contradicting each other. Reorder one and reorder both.

**IT USED TO ONLY EVER SAY NO, AND THAT RULE HAS BEEN DELIBERATELY
REVERSED.** It read: *there is no ROB ME state, because eight piggies all
advertising themselves is wallpaper rather than information -- the useful
signal is the exception, so a badge means stay away and no badge means go.*

That is right for somebody who already knows this street and wrong for the
game, for a reason that survives the objection: **A STEAL TAKES A FRACTION OF
A PIG, SO WHICH PIG IS THE ENTIRE DECISION.** "No badge" says a plot is
available and says nothing about whether it is worth crossing the road for --
which was the one question this whole feature exists to answer from the
pavement. A new player cannot read an absence at all; they have not been
taught what a missing badge means.

So a robbable pig carries its own figure in gold and the street reads as a
shopping list. The refusals are unchanged and still win: a reason to stay
away always beats a number. It shows what is IN the pig and never what you
would take -- the take needs the thief's own Bigger Sack level and the live
event multiplier, and re-deriving those in the badge would be a second
implementation of a number the steal prompt already computes.

**AND IT HAS TO BE PER VIEWER, WHICH IS WHAT DECIDED THE WHOLE SHAPE.** The
per-victim cooldown is per THIEF, so two players standing at the same piggy
genuinely disagree about whether it can be robbed and THERE IS NO SHARED ANSWER
A SERVER COULD PAINT ON A SIGN. Each client is told its own cooldowns by
`StealCooldown` -- fired to one thief on a completed grab, which is the only
thing that starts one -- and derives the rest from attributes it already has.
Same shape as the animated skins and the moat: the server publishes a fact and
every machine works out the picture itself.

**THE SHIELD RIDES AN ATTRIBUTE ON THE PLAYER, NOT ON THE PLOT.** It is a fact
about the player, a Player instance already replicates to everybody, and
putting it on the plot would have meant answering "which plot" at join -- which
is a race, because the shield starts when HeistService sees the player and the
plot is seated separately. It is written in `workspace:GetServerTimeNow`
seconds and never `os.clock`, because a client reads it and os.clock is a
process uptime that means nothing across the wire. `openSeason` zeroes the
published copy as well as the private one, or every badge in the server goes on
saying NEW HERE through the whole test.

**A MODULE, AND THE 200-LOCAL CEILING IS NOT A STYLE NOTE.** Written inline it
wanted three top-level locals in `ClientMain`, and that chunk had none left:
the HUD died with *Out of local registers when trying to allocate
buildBustScene* -- an innocent variable two thousand lines from the change, and
the ENTIRE HUD rather than the badge, because the chunk never compiles and
nothing gets built. Measured, this is the second time in one session. It is
required and started in ONE STATEMENT holding no local at all, and it needs
nothing from `bindPlot` -- it finds its own plots, since it is a function of
plot attributes, the Player list and one remote.

Verified live on a borrowed plot: vault 0 renders EMPTY, vault 5,000 hides the
badge outright, a pushed cooldown counts 54 -> 48 in WARN_INK and then clears
itself, `openSeason` takes the published shield to 0, and the badge sits at
+11 from the body -- above the 14.15 hat anchor, so it clears the tallest hat
in the shop rather than growing out of somebody's top hat.

**`STEAL_MAX_PER_VICTIM` IS RETIRED, AND THE COOLDOWN DOES THAT JOB ALONE.** It
was a lifetime cap of 3 on how many times one thief could ever rob one victim
in a session, sitting on top of the 60-second cooldown. Two things were wrong
with it. **It is the only limit in this game a player could permanently
EXHAUST** -- in an eight-player server that is 21 robberies and then the whole
offence tree has nothing left to point at, which is the "every session is
identical" fault session events exist to fix, arriving from the other
direction. And **it could not be read from outside**: a cooldown counts down
and a cap just says no, forever, with the refusal the only place it was ever
mentioned -- so it was exactly the kind of rule the badge above cannot show.

What it was protecting is anti-camping, and the cooldown always did that part:
a thief standing on one lawn earns nothing for 60 seconds and the getaway is 53
studs each way. Note the retirement took the comment in `Config` that justified
the SPRINKLER by naming both caps, and the one in `openSeason` that listed
three restrictions -- copy outlives the thing it describes, and the admin
console's own "cooldown/limit pair(s)" line was the third.

**`PromptButtonHoldEnded` IS NOT "CANCELLED".** It fires at hold COMPLETION as
well as on release -- this file has it measured at 0.584s on a 0.6s prompt,
firing before `Triggered` -- so PromptUI only ever uses it to stop the fill.
Anything that treated it as an abort would be the same bug that made every
steal in the game silently fail for weeks.

**IT IS A NAB NOW, NOT A TAG, AND THE WORD WAS DOING FOUR JOBS.** Inside this
project alone `tag` already meant a `CollectionService` tag, the character
`Nametag`, and the plot sign -- and `HeistService.nab` is also what the guard
dog calls, so one word covered a player pressing a prompt and a dog catching
somebody. It also named the TOUCH rather than the OUTCOME, which is backwards
from every other prompt here: `BANK COINS`, `OPEN IT`, `RECOVER`, `STEAL`.

**THE WORDS THAT WERE REFUSED ARE WORTH KEEPING, because each is already
spoken for**: `snag` is the fence penalty toast, `catch` is
`DOG_TIERS.catchRadius`, `bust`/`BUSTED` is the arrest scene's stamp, and
`collar` is the guard-duty tell. `tackle` and `takedown` are refused for the
audience on the same rule that gives the officer no baton -- Roblox's maturity
questionnaire is answered by what is literally in the model, and a verb
describing violence is that decision made in text.

**"NAB" AND NOT "TAG THIEF", because the prompt only ever exists on a thief
who is carrying.** The old verb was telling the reader something the prompt's
own existence already told them, and three letters drop into the card measured
for `STEAL` and `HIDE` with nothing to re-fit.

**THE RENAME IS AN INTERFACE CHANGE IN FOUR PLACES WITH NO COMPILER BEHIND
ANY OF THEM**, which is the `"LockLevel"` lesson from the other end: the
prompt's `Name`, its `ActionText`, the `PROMPT_KIND_ATTRIBUTE` string the
client renders the card from, and `Config.PROMPTS`' own key. Miss one and it
fails silently -- a missing kind reads nil and falls through to the default
prompt style. **GREP THE RAW STRING AFTERWARDS RATHER THAN BEFORE**, and grep
for the player-facing strings separately: four of them (`"Tag Thief!"` twice,
`"Go tag them."`, `"Tag them before they get home."`), plus a shop blurb in
`ClientMain` and the guard dog's own catalogue line, were nowhere near the
code being renamed.

**AND MOST OF THE WORD "tagged" IN THIS REPO IS `CollectionService` AND MUST
NOT BE TOUCHED.** A blanket replace hits `GetTagged`, `HouseFX`, the moat, the
trampoline mat and the raid drones. The rename went in as identifiers and
player-facing strings first, with prose swept by patterns narrow enough to
miss every tagging call -- and `Config.TAG_HOLD`/`TAG_DISTANCE` became
`Config.NAB.hold`/`.distance`, a TABLE rather than two constants, because
`docs/MASTER-PLAN.md` grows `tickRate` and `bounty` into it next.

Verified live: clean boot, `HeistService.nab` present and `.tag` gone,
`PROMPTS.tag` gone, zero prompts left on the retired kind, and a real
`NabPrompt` built on a genuinely carrying resident reading
`action="Nab Thief!" hold=0.40 range=14 kind="nab"` and resolving to card verb
`"NAB"`. What is NOT verified is a nab actually recovering coins, for the
usual reason: it needs a second player, and `require` in the MCP sandbox hands
back a fresh `ResidentService` whose `start()` never ran, so the live service
cannot be driven from there either.

**A PROMPT WELDED TO THE PERSON IT IS ABOUT IS OFFERED TO THAT PERSON, AND
THE TAG PROMPT SHIPPED THAT WAY FOR THE WHOLE LIFE OF THE PROJECT.**
`attachLoot` welds the stolen piggy to the THIEF's own root and parents the
tag prompt to it -- correctly, because the prompt exists so that everybody
ELSE can reach it, and a thief must be taggable by any bystander. The side
effect nobody had looked at is that the one player who must never press it
stands permanently at distance zero, well inside `TAG_DISTANCE`, with
`RequiresLineOfSight` off. So a carrying thief spent every getaway with
"Tag Thief!" over their own name, and pressing it worked.

**IT WAS NOT AN EXPLOIT, AND SAYING SO PRECISELY IS WHAT SIZED THE FIX.** A
self-tag returns the coins to the VICTIM and stuns the thief, so it profits
nobody and there is no economy hole to close -- the first instinct was to
write it up as a way to escape a chase, and that is simply wrong: dropping
the loot and being stunned is worse than being caught. What it actually cost
is a nine-year-old with a stray thumb losing an entire robbery to a button
the game should never have drawn, which is the same argument the last-copy
sell guard already makes. It also produced NONSENSE IN BOTH DIRECTIONS,
which is how it was noticed: `tagger ~= victim` is true when the tagger is
the thief, so the same player got "Tagged by yourself! You dropped the loot"
AND "Nice tag! You saved Grandpa Grunt's coins" in the same second, while the
victim was told somebody had tagged themselves.

**THE GUARD IS AN IDENTITY TEST AND IT IS THE FIRST LINE OF `tag`, ABOVE THE
CARRY LOOKUP.** Every other guard in that function is about the chase -- is
there loot, is the thief dodging, is the tagger close enough. This one is
about WHO IS ASKING, which is a different question and has to be answered
before any of them. The dog path passes a Resident TABLE as the tagger, so
`tagger == thief` is false by construction there and the catch is untouched
-- verified after the fix, dog catch at t4.5 with the loot gone and the thief
stunned.

**AND THE CLIENT STOPS OFFERING IT, because a silent server refusal is the
worse half of this bug rather than the fix for it.** A button on your own
chest that does nothing when held is exactly the failure this file refuses
above all others. `PromptUI` disables every ProximityPrompt inside the LOCAL
player's own character -- a client `Enabled` write affects only that
machine's view, which is the only per-player prompt Roblox offers -- and the
server refuses regardless, so this is the client declining to ask for a known
no, the same split the number keys and the dodge-while-riding suppression
already make. It walks the character AND connects `DescendantAdded`, because
the loot arrives mid-robbery a slice at a time, long after the character
exists.

**THE RULE IS GENERAL ON PURPOSE: A PROMPT ON YOUR OWN BODY IS NEVER FOR
YOU.** Exactly one prompt in this game lives on a character and it is this
one. Writing the narrow version -- "skip prompts whose kind is tag" -- would
put heist knowledge inside a renderer and leave the next self-prompt to be
found the same way this one was. Verified live: `TagPrompt Enabled=false` on
the thief's own client while carrying, a forged `tag(plr, plr)` refused with
the loot kept and WalkSpeed still 12, and the dog's catch unaffected.

**TWO PROMPTS SHARE A PART IN TWO PLACES, AND THE GAME USED TO GUARANTEE THEY
WERE EXCLUSIVE.** collect/steal sit on a piggy's Body and hide/dig on a bin's
Hatch, so a naive renderer would stack two cards on identical pixels. It did
not happen: measured live, exactly one card at a piggy, because `collect` is
enabled only for the owner and `dig` only when somebody is inside. The rule
this entry ended with was that anything adding a third prompt to a shared part
had to keep that property, since there was no offsetting logic and there
should not need to be.

**THE SMASH SPENT THAT DELIBERATELY, AND IT IS THE ONLY THING THAT MAY.**
Steal and smash are the two ways into one pig and they have to be READ
TOGETHER, because a choice you cannot see is not a choice -- so both are live
at once, on one Body, for the same player. `Config.PROMPT_SLOT_ATTRIBUTE` is
the offsetting logic that used not to exist, and the smash entry above carries
the measurement that decided its shape. **Anything else that wants two cards
on one part now has a mechanism to use rather than a rule to keep, and still
has to justify why its pair is not exclusive.**

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
what a screenshot looks like.** The stack was coin counter 16..78, toast 88,
rebirth 96..148, carry banner 140..192, patrol banner 200..238. The coin
counter has since merged into the piggy bank panel, and that band was free
until the first-session objective card took 50..94 of it -- squeezed between
a topbar covering the first 58 pixels and a rebirth button pinned at 96, with
no arrangement clearing both. The rebirth button was deliberately left at 96
rather than moved up into the gap,
because shuffling a control players already know the position of, to close a
gap nothing is drawn in, costs more than the gap does. The patrol
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

**THE ROBBING PIVOT IS VERIFIED AT EVERY END THAT ONE PLAYER CAN REACH, AND
THE ROBBERY ITSELF IS NOT.** Measured live after the change: the server boots
clean with no collect prompts and a steal prompt on all eight piggies; a
schema-16 save with coins 1000, vault 250, medals 7 and tokens 5 reconciles to
coins 1250 and loot 12, and reconciling it again changes nothing; the dev save
joined with its old banked total and stealable pile merged into one balance;
a dev loot grant moved the roll note from 1332 to 1382 through
`SetService.award` and its registered pusher; a dev coin change with NO push
behind it was repainted on the lawn and the HUD by the economy tick inside two
seconds; open season dropped the shield without error; and the plaster's two
strips sit on the forehead clear of both eyeballs.

What has NOT run is the thing the pivot is about: a real steal against a real
second player, so the doubled payout, the loss cap clamping a fourth grab, the
revenge multiplier paying out and the grudge clearing, the loot landing on a
delivery, and the plaster appearing on a robbed pig have all only been
reasoned about. Same wall as the rest of the heist system. The first
two-player session should watch those five things before anything else.

**THE GRASS IS VERIFIED AND THE ESTIMATE HELD.** `perStuds` 45 on the flat
ground measures **1,463 tufts in a world of 3,112 BaseParts**, against a
prediction of about 1,450 in 3,050 made from the 80-density measurement of 819
in 2,428. It reads as grass rather than as weeds. Tufts are the largest single
class of part in this game by a distance -- 47% of everything in the world --
so that is the number to watch if the density is ever raised again.

Also confirmed on the same build: 46 mesh canopies, and the piggy back on its
24 MeshParts rather than the primitives fallback.

**THE CRACK IS VERIFIED ON EVERY PATH ONE PLAYER CAN REACH.** Driven through
the real prompt and the real remotes rather than a module handle: a half-second
hold opens the panel on a resident's pig, which renders the neighbour's name,
SLICE 1 / 5, a full gauge, no cap line (a resident has no allowance to draw)
and a first slice of 882 against a pig of 44,129, which is 2.00%. Five slices
landed clean, the zones narrowing 0.692 / 0.561 / 0.454 / 0.368 / 0.298 of the
dial exactly as `getCrackWindow` predicts at lock level 1, the slice figures
growing 882 / 1.2K / 1.7K / 2.2K / 3.0K, the next-slice segment on the gauge
growing 0.020 / 0.028 / 0.039, the label over the carried piggy keeping up, and
the pile on the lawn draining 44,129 to 37,282. A deliberate MISS after two
slices kept the 2.1K, printed *"2 of 5 slices. 2.1K coins, worth 4.2K at
home"*, then *"The lock snapped back!"*, sounded the plot alarm and let the dog
off -- which caught the carrying thief, tagged them, and returned the coins to
the pig. Server boots clean and fourteen probes threw nothing.

**AND THE EMPTY-HANDED CATCH HAS NOW RUN, reached through the watcher rather
than through a fumbled slice.** It was recorded here as unverified for exactly
as long as the only route to it was a prompt, and Studio's
`ProximityPromptService` had stopped showing ANY prompt part way through that
session -- `PromptShown` never fired again for any piggy on any plot, at any
distance, with `Enabled` true on the client, and it did not come back across
two restarts of Play. The watching dog opened a second door to the same
branch: walk onto a resident's lawn empty-handed and stand still. Measured, a
chase at t3.7 then the catch at 7.2 studs against a `catchRadius` of 7.0,
`WalkSpeed` 0.00 for `Config.DOG_WATCH.scareStun`, the toast *"Old Man Hamm's
dog saw you off!"*, and a clean recovery to 16.

**A FEATURE CAN BE THE TEST HARNESS FOR THE ONE BEFORE IT**, which is worth
recording as a habit: the branch that could not be reached through the front
door was reachable through the next thing built on top of it, and neither was
written with that in mind.

Still unrun, for the usual reason: the cap line on the gauge and the alarm
reaching a victim both need a second player, since a resident has neither. And
a TITAN hearing a tiptoe -- `notice` 0 against a sneak of 5.6 -- is derived
rather than measured, because every resident on a fresh street is a Scruffy
and the only tier-3 dog in reach belongs to the tester, who is its owner.

**A TIER-5 MOAT HAS NEVER BEEN MEASURED AGAINST THE LAWN GRASS.** The tufts
take no veto on a plot because the driveway is in front of the lawn and the
moat is outboard of it -- the first half is measured at zero tufts on tarmac
across every plot, the second is derivation. Forcing a moat needs
`PlotService.buildFence(plot, 5)` against a REAL plot table, and the MCP
sandbox cannot supply one: requiring a service there hands back a fresh module
whose `start()` never ran, which this file already records for PoliceService.
It wants either a dev command on the admin panel or one player buying the
fifth fence tier. If grass ever does appear in the water, the fix is an
`accept` on the two `scatterOn` calls, not a new rule.

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

**THREE JUMP HARNESSES IN A ROW LIED, IN THREE DIFFERENT DIRECTIONS, AND THE
LESSON IS THAT EMULATING AN INPUT IS NOT THE SAME AS MEASURING A CAPABILITY.**
Trying to answer "can a player jump this fence" by driving a character:

  * **`Humanoid.Jump = true` LATCHES.** It stays true until the humanoid
    lands and then fires again, so setting it once and walking away is a HELD
    key rather than a press. It produced 6.6 to 7.9 studs of "one jump" rise
    on a 4.0 jump, and crossings that no single jump could make.
  * **Clearing it a frame later cancels it.** `Jump = true` then `Jump =
    false` on the next frame read 0.00 to 0.18 studs of rise, which looks
    exactly like a fence that blocked the jump.
  * **`ChangeState(Jumping)` grants a free jump IN MID-AIR.** Called on a
    loop it is a flying test: 13.1 studs of rise on a 4.0 jump, crossing
    everything.

Every one of those returns a confident number. What works is measuring the
CAPABILITY on open ground away from any wall: settle until there is a real
floor and the velocity is near zero, jump once, and read the peak of the
COLLISION hull. That gives a stable `JumpHeight + 0.1` every time and is what
the fence arithmetic is built on.

**WHAT IS STILL OPEN IS WHETHER HOLDING JUMP AGAINST A WALL CLIMBS IT.** One
run suggested a character re-jumping on every contact can stack height against
a fence. It came from a harness that was also granting free air-jumps, so it
is not evidence, and no fence height would fix it if it were true. It wants a
human holding the spacebar against a tier 5 fence, which is the one test
nothing in this toolchain can perform.

**THE CLIMB IS VERIFIED END TO END NOW, INCLUDING THE HALF THIS SECTION SAID
COULD NOT BE.** It used to read *"what has not been seen is a player getting
over the top and down the far side... the mantle is the one part of this that
wants a human on the keyboard"*. Two attempts had moved the character zero
studs in six seconds, which was a stuck harness rather than a stuck mechanic.
Driven properly -- `Humanoid:Move` bound ABOVE the control module at
`RenderPriority.Character + 1`, which is the trap the dodge dash already
records and exactly what had stalled it -- the whole crossing reads:

    t 0.0  localX -38.00  Running   ws 16.00   outside, in the alley
    t 0.8  localX -35.84  Climbing  ws  5.60   on the ladder, 16 x 0.35
    t 1.6  localX -35.84  Climbing  ws  5.60   y 8.70, above the 6.50 barrier
    t 2.3  localX -32.32  Running   ws 16.00   over the top, INSIDE the yard

Also verified: placement projected onto the nearest segment and clamped off
its ends in all three corners, refusals for a hoppable tier and for standing
nowhere near a fence, one-per-player retiring the previous ladder, the fade
starting at 17.6s and the ladder gone by 20.1, and a fence rebuilt underneath
one taking it with it and releasing the registry.

WHAT IS STILL UNVERIFIED IS THE CLIMB WHILE CARRYING, which is the case the
whole design is tuned around: the climb out has to be dearer than the climb
in. It needs loot, so it needs a second player. The multiplier itself is not
in doubt -- it is a factor on `currentSpeed`, which the carry penalty already
scales -- but the FEEL of a 2.4-second climb with a dog coming has never been
had by anybody.

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

`Config.NEW_PLAYER_SHIELD` was **15 minutes** when that warning was written
and is **120 seconds** now, ending outright on the player's first robbery.
Two players who join and immediately try to rob each other are refused for
at most two minutes, and only until whichever of them steals first.

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
