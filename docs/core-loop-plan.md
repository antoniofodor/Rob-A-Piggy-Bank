# Core loop plan — making robbing the game

**Status: WORKING DOCUMENT, September 2026. Not a fourth source of truth.**

CLAUDE.md is WHY (rules and post-mortems), GAME.md is WHAT (the map),
design-doc.html is the original pitch. This file is a scratchpad for a
direction that has not shipped. As each decision below lands in code, its
reasoning moves into CLAUDE.md and its description moves into GAME.md, and
the entry here is deleted. When this file is empty, delete it.

The question that started it: *the core game loop should revolve around
robbing, and it has to be understandable and engaging in the first 30
seconds.*

---

## 1. Diagnosis: what the first 30 seconds actually is

Measured against the live Config at level 0 (`BASE_INCOME` 10,
`BASE_CAPACITY` 5000, `STEAL_FRACTION` 0.08, `HEIST_PAYOUT` 2,
`STEAL_HOLD` 3, getaway 53 studs at carry speed 12):

| t | on screen | available action |
|---|---|---|
| 0s | your pig, 0 coins | none |
| 30s | your pig, 300 coins | none. Cheapest purchase is 400 |

Every neighbour's pig is also at ~300 on a fresh server. A robbery at t=30
takes 8% x 300 = 24, doubled = **48 coins**, for a ~13 second round trip
(80 studs out, 3s hold, 53 studs back). Idle income over the same 13
seconds is 130. **The first robbery available to a new player costs them 82
coins.**

Nobody can rob them either: `NEW_PLAYER_SHIELD` is 10 minutes against
sessions that run 15 to 25.

And there is no onboarding of any kind. Grepped: no tutorial, no objective,
no first-run branch, no `sessions == 1` UI anywhere. Nothing in the game's
first minute mentions robbing.

## 2. The structural finding: robbing is capped at ~7% of income

This contradicts what CLAUDE.md currently asserts about the pivot, and it is
why the loop cannot be fixed by onboarding alone.

`Config.LOSS_CAP` is 25% of a victim's pig per rolling hour, across ALL
thieves. So on an 8 player server:

    total hourly victim loss  = 8 x 0.25 x pig  = 2.0 x pig
    total hourly thief gain   = x HEIST_PAYOUT  = 4.0 x pig
    per player                = / 8 players     = 0.5 x pig per hour

- Level 0: 0.5 x 5,000 = **2,500/hr robbing** vs **36,000/hr idling** (7%)
- Level 20: 2.1M/hr robbing vs 14.5M/hr idling (14%)

Perfect play as a thief, every hour, against permanently full targets, earns
between a fourteenth and a seventh of what standing still earns.

Neither rule is wrong alone. `HEIST_PAYOUT` was raised to 2 to make robbing
"the best earning rate on the street"; `LOSS_CAP` was added to keep a
robbery survivable. They were tuned in the same session and never multiplied
together. The cap binds long before the payout does.

**Why the obvious dials do not fix it.** Parity at level 0 needs
`HEIST_PAYOUT` around 29, or a loss cap around 360%/hour. The first is
absurd; the second makes being robbed devastating, which is the one thing
this design will not do.

## 3. The plan

Ordered by leverage. Items 3.1 and 3.2 are the game; 3.3 to 3.6 are the
onboarding. Doing the onboarding without the first two teaches a new player
to rob and then shows them it was not worth it.

### 3.1 Unclaimed plots get an NPC owner  [SHIPPED, both stages]

**Stage 1 is in and verified live:** `ResidentService` seats a neighbour on
every unclaimed plot — a name on the sign, a pig seeded to 60% of capacity
and accruing on the same curves players use, and fence/dog/lock/house
ladders that scale with the average level of the humans in the server.
`PlotService.onClaim` / `.onRelease` are the registry hooks (a require would
be a cycle, the same call `registerBounceVeto` makes). Measured: seven
residents seated, all accruing, the owned plot correctly skipped.

**Two things came out of running it that were not predicted:**

- **Residents seed at BOOT, when the server is empty and the level is 0.**
  They were seeded against a level-0 capacity and then rescaled to the first
  player's level, leaving 2,872 coins in a pig that now held 19,208 — 15%
  full, so a thief crossing the road found 2% of almost nothing. Fixed by
  topping up to the same share of the new capacity whenever the level RISES,
  and never when it falls (following it down would refill a pig a player had
  just emptied). Measured after: 2,872 -> 12,022.
- **The uncapped supply does the economy flip on its own.** Against a
  resident at level 4, a full crack is 2,631 coins doubled to 5,262 for a
  ~13 second round trip, against a player income of 33/s. That is **roughly
  12x the return of standing still** — achieved without touching
  `HEIST_PAYOUT` or `BASE_INCOME` at all, because `LOSS_CAP` was the binding
  constraint and residents do not have one. 3.2 may need far less than it
  looked like it would.

**Stage 2 is in and verified end to end.** `HeistService` is written against
a `Target = Player | Resident` union rather than against `Player`, with the
differences held at seven accessors (`asPlayer`, `asResident`, `targetName`,
`targetId`, `targetPlot`, `targetCoins`, `targetCapacity`, `targetLockLevel`,
`notifyTarget`) instead of branching at twenty call sites. `typeof(t) ==
"Instance"` is the whole discriminator: a Player is an Instance, a Resident
is a table, so there is no flag to keep in step.

Verified by driving the REAL client prompt path (`InputHoldBegin`, not a
sandbox call, which would have got a fresh module with no live state):

    target Plot2 (Old Man Hamm) vault=12852 prompt.Enabled=true hold=3.0s
    vault 12886 -> 12014   loot label "Old Man Hamm's piggy  1.0K"
    highlight on character: true
    my vault 2154668 -> 2156845 (+2177 = ~1050 doubled, plus own accrual)
    carrying cleared, revenge markers on the street: 0
    robbed resident refilling: 12844 -> 12910

**Three things that had to differ, each at one accessor:** no `LOSS_CAP` (the
uncapped supply is the entire point), no grudge or revenge marker (a marker
over an empty house promises a triple payout nobody can collect), and no
notifications (nothing is reading them). What is deliberately the SAME: the
take, the hold, the carry penalty, the getaway, the dog, the tag, the patrol
and the rap sheet — so robbing a resident still puts you on Most Wanted,
which is what keeps the police loop alive in a one-player server.

**Two real bugs found in PoliceService while doing it**, both of which would
only have fired once an unclaimed plot became robbable: `notify(alarm.victim,
...)` calls `FireClient`, which throws on a plain table, so the first
robbery of an empty house during a patrol would have errored; and
`alarm.victim.Parent` was safe only by accident (a table read returns nil
rather than throwing). Both go through `HeistService.notifyTarget` /
`.isPlayerTarget` now.

**Not yet verified:** that the missing loss cap actually lets a player rob
residents indefinitely — `STEAL_COOLDOWN` is 60s per victim, so proving it
needs a long run across several residents rather than a single robbery.

`attemptSteal` requires a `victim: Player`. A plot with `owner == nil` has
no data and cannot be robbed, so on a 3 player server 5 of 8 frontages are
dead: a street that reads as abandoned AND nothing to rob.

Give unclaimed plots an NPC resident: a pig that accrues, a fence and dog at
a tier that scales to whoever is robbing it, and **no `LOSS_CAP`** — nobody
is being hurt, so nothing needs capping.

What it buys:

- robbing is available in the first 5 seconds regardless of who is online
- an uncapped supply the real-player cap cannot touch, so robbing can become
  the primary income WITHOUT being robbed getting any worse for a child
- the core loop stops depending on server population
- roughly ten items in CLAUDE.md's "Not yet verified" section that all read
  *needs a second player* become testable solo

Constraints: keep NPCs off the Richest Piggies and Most Wanted boards, and
give them no revenge marker. They are a resource, not a rival.

### 3.2 An active thief must out-earn an idler by 3-5x, with an audit  [SHIPPED]

**Residents did this without either dial moving.** Measured against one at
level 4, a full crack returns roughly 12x what idling does, because the
binding constraint was never `HEIST_PAYOUT` or `BASE_INCOME` -- it was
`LOSS_CAP`, and residents do not have one. So neither constant has been
touched and neither should be until there is a reason.

**AND THE AUDIT IS IN.** `Config.auditRobbery`, warned per problem by `Main`
in the same block shape as `auditEconomy` and `auditFences`. Three checks
plus one nobody would have thought to write:

- **a floor** (`ROBBERY_ADVANTAGE.min` 3.0) -- even perfect robbing must beat
  standing still, which is section 2's finding stated as an invariant
- **a ceiling** (`max` 10.0) -- a resident may not be a faucet, which is what
  6.9 caught
- **a spread** (`spread` 0.02) -- the ratio must be CONSTANT across every
  level and rebirth, which is the `pigSeconds` invariant and the only one of
  the three with a provably right answer
- **the lap** -- a thief may not cycle every resident faster than
  `STEAL_COOLDOWN`, or every figure above is optimistic. 148.6s against 60s
  today, and it tightens whenever the street gets shorter or the crack gets
  quicker

The round trip is DERIVED from `PLOT_SPACING`, `STEAL_RANGE`,
`DROPOFF_RADIUS`, `CARRY_SPEED_MULTIPLIER` and the crack's own timings rather
than pinned -- a pinned figure describes the game on the day somebody typed
it, which is exactly how the number below came to be wrong.

**IT CAUGHT A LIVE REGRESSION ON ITS FIRST RUN.** This section recorded 4.92x,
which was solved against the flat 8% take. The crack replaced that with a
five-slice 21.9% one and nobody re-derived the ratio: it is **8.25x**, dead
flat across all 341 level/rebirth pairs (spread 0.0000%). Verified by
provocation as well as by measurement -- putting a resident's pig back on the
capacity curve fires all three checks and reproduces 12.35x.

**THE OPEN QUESTION IT LEAVES, deliberately unaudited:** at 8.25x the 80M Sky
Castle is 0.90 hours of optimal robbing at level 20 against 7.42 idling --
the same complaint 6.9 raised about the old 12.3x, arriving again lower down.
The lever is `pigSeconds` and it is a PACING decision rather than a
correctness one, so the audit does not encode an hours-to-finish threshold:
that number is a design statement in the way a house price is.

**NEITHER DIAL WAS TOUCHED AND THE TWO CANDIDATES ARE KEPT HERE AS THE LEVERS
IF IT EVER REGRESSES**, not as work outstanding: `HEIST_PAYOUT` up (the extra
is minted, and coins are neither tradeable nor purchasable, so it costs a
victim nothing and has no downside except pacing), or `BASE_INCOME` down so
the drip is a floor rather than the main course. Both stay where they are --
the supply side did the whole job, and the audit is now what says so on every
boot.

### 3.3 The shield ends when you commit your first robbery  [SHIPPED]

Replace the 10 minute timer with: *nobody can touch your piggy until you
take somebody else's.* One sentence carrying the rule, the theme and the
trade; the player chooses when it ends; it self-clears with no new save
field. Keep a hard ceiling around 2 minutes so a player who never robs still
enters the game.

Today a first-session player learns "this is an idle game", then gets robbed
on session two and experiences it as a betrayal of what they were taught.

### 3.4 Put the value on the pig, readable from the pavement  [SHIPPED]

`RobBadge` deliberately only ever says NO, on the argument that eight pigs
advertising themselves is wallpaper. That is right for a veteran and wrong
here, for a reason that survives the objection: **the payout is 8% of a
variable pig, so which pig is the entire decision** — and that number is
currently only legible from the steal prompt, which as CLAUDE.md itself says
"only exists once you are ALREADY STANDING ON THE LAWN — past the fence,
past the dog, and well past the point the decision was worth making."

A gold figure over each robbable pig turns the street into a shopping list.

### 3.5 The first robbery pays for the first upgrade  [ALREADY TRUE, measured]

First purchase is 40 seconds of idling away and the first robbery buys
nothing. Price the first rung so one successful robbery clears it, so the
lesson of minute one is *rob, buy, rob more* rather than *wait, buy*.

**Measured, and it needs no change.** The first income rung is 400. A new
player's residents seat at level 1, so a seeded pig holds 0.6 x 5,000 = 3,000
and one ordinary 8% haul banks 3,000 x 0.08 x 2 = **480** -- clears the rung
with a little over. Against the dev save's level-4 residents the same haul is
1,784. So the storyboard's t=20-30 already works and the price does not move.

Worth keeping an eye on when the greed dial lands: a full five-slice crack of
that same new-player pig is 3,000 x 0.219 x 2 = 1,314, which buys the first
THREE rungs at once. That is probably right for a first robbery and it is a
decision rather than an accident.

### 3.6 One first-session objective, retired on first delivery  [SHIPPED]

`Shared/FirstJob.luau`, started from ClientMain in a single statement holding
no local at all (that chunk is at the 200-register ceiling and has lost the
whole HUD to four of them twice). One paper card at top centre reading *"Your
piggy bank is empty. Go and rob a neighbour!"*, plus a gold Highlight on the
nearest robbable pig -- because the instruction is useless to somebody who
does not yet know the houses down the street have piggy banks in them.

No new save field and no new remote: `Config.PLAYER_FIRST_JOB_ATTRIBUTE` is
published on the Player and DERIVED from `data.totalStolen`, which already
means "have you ever got a robbery home". Set in `onPlayerAdded`, written
false in `deliver`, so it retires on the first delivery and never returns --
including on later sessions and after a rebirth.

**Two things running it caught:**

- **`nil` is not "no", and treating it as one would have meant no new player
  ever saw this.** The server writes the attribute from its own PlayerAdded
  and the client module starts from its own script; neither waits for the
  other. On any join where the client wins that race the attribute is simply
  absent, and the first version tore the feature down a frame before it was
  told it was needed -- the exact case it exists for, and one that would
  never reproduce in a test that set the attribute first. Three states now:
  true shows, false retires, nil waits.
- **The band was measured, not trusted.** `IgnoreGuiInset` is on, so offset 0
  is the physical top of the screen and the topbar covers the first 58
  pixels. At the obvious offset 16 with a 60-tall card, **42 of its 60 pixels
  sat inside that band**. The old coin counter got away with exactly that,
  because the middle of the topbar is empty and a number reads half-dimmed;
  the one sentence a new player has to read is not the element to spend it
  on. Now 50..94: 8px under the topbar, 2px clear of the rebirth button.
  Nothing clears both -- 58 would be fully clear and a 44-tall card then runs
  to 102, through a control pinned at 96.

Verified: card visible with the right copy, text fits (395px in 404), the
highlight lands on the nearest robbable pig at 81.9 studs (one PLOT_SPACING),
and setting the attribute false destroys both the card and the highlight.

## 4. Why a robbery feels the same every time

Second question, and the answer reframes the first.

**Every toy in this game fires AFTER the steal completes.** Carry penalty,
dog chase, police, bystander tagging, wheelie bins, the dodge, gadgets, the
raincoat, the ladder on the way out — all of it is getaway. The 3 to 12
seconds where you are actually robbing somebody has no mechanic attached to
it at all.

**And the hold is the one moment where the game switches itself off.** Every
tuned number here is a speed: walk 16, carry 12, dogs 12/14.5/17, officer
14.5, climb 0.35x, the dodge, the bin burst, the rides. This is a game about
movement, and its central action is standing still.

**A robbery also has no partial outcome.** You get the loot home or you are
tagged. There is no "I got half of it out", no "I had to bail early" — and
partial outcomes are what make a repeated action generate stories.

So the shape of the problem: **the game has an excellent chase bolted to a
heist that does not exist.** It does not need more mechanics. It needs half
the ones it already has moved to before the steal instead of after.

### 4.1 / 4.8 The dog watches the approach  [SHIPPED, verified live]

**The model changed, and the new one is better.** 4.8 originally said owner
away = enforcer, owner home = alarm. The counter-proposal was that the dog
SLEEPS when the owner leaves and wakes on noise. Combined, they resolve each
other and fix the flaw that killed the first version:

    OWNER HOME  dog awake, keeps its owner company, barks at an intruder and
                does not chase -- the OWNER is the defence, and the player
                actually sees the pet they paid for
    OWNER AWAY  dog asleep in the kennel; the lawn is quiet until somebody
                makes a noise, and then it is the enforcer because nobody
                else is. A resident's owner is always away.

Exactly one defender in each state, which is the fairness rule from 5.5, and
**the dog's own posture becomes the tell for whether anybody is home** --
trotting after a player means expect a fight, curled up in the kennel means
the house is empty. Free, no UI, readable from the pavement.

**Two things wake it, and both are NOISE rather than presence** -- standing
still on a lawn is never a crime:

- **Footsteps above the breed's `notice`.** Walking (16) wakes any dog; a
  tiptoe (5.6) wakes none but a Titan, whose `notice` of 0 hears anything
  that moves and has to be answered with a bone. That is this project's own
  "cheap counters bounce, the expensive one gets through" ladder arriving at
  the approach.
- **The lock being worked.** A crack rattles what it is cracking, so the hold
  itself wakes the dog -- which is the entire point of 4.1, and
  `PlotService.rattleLock` is already called at exactly that moment.

`Config.DOG_WATCH` is in and compiles (`pollRate` 0.1, `wakeDelay` 1.2,
`alertSeconds` 12, `scareStun` 1.5). **Nothing reads it yet.** `wakeDelay` is
the load-bearing one: the beat between being disturbed and being come for is
what makes a crack a DECISION -- you hear the dog stir and choose whether to
finish or bail -- rather than a coin flip.

**Still to wire:** a watcher (in HeistService, which knows plots, players and
speed -- GuardDog knows none of those and should not learn), a sleep-by-
default mode and an `alert` entry point on GuardDog, and a catch that breaks
the hold and applies `scareStun` when the thief is carrying nothing, since
`tag` returns early with no loot to drop.

### 4.2 The greed dial: hold longer, take more  [SHIPPED as 4.7, the crack]

Rather than a fixed 8%, the fraction climbs while the hold continues and the
player releases when they choose. Every robbery becomes a decision made
under pressure instead of a fixed transaction; it generates the partial
outcomes the loop currently cannot produce ("I bailed at 40% because the dog
woke up"); and it raises thief income without touching `LOSS_CAP`.

Composes directly with 4.1: the longer you stay, the more you take, the more
likely you are caught.

### 4.3 Two ways in: loud and fast, or quiet and slow  [not started]

One choice, two different robberies. Smash = near-instant grab, wakes the
dog immediately, alarms the owner. Crack = long hold, no alarm. Enormous
variance per line of code, and it makes each defence tier matter differently
depending on which the thief picked.

### 4.4 The owner can interrupt a robbery in progress  [not started]

Being robbed is currently passive: a toast, a screen flash, and the option
to chase somebody who already has the money. Tagging exists but only works
on a carrier. Let an owner who reaches their own lawn break a hold in
progress, so being home means something.

### 4.5 Heat across a session  [SHIPPED as the SPREE]

Variance BETWEEN robberies rather than within one. The rap sheet, Most
Wanted and the patrol already exist and are invisible in the moment. Surface
them as a streak: consecutive robberies raise heat, heat raises both payout
and risk. That is the structure that makes a session a run rather than a
sequence of identical transactions.

**IT IS CALLED A SPREE IN CODE, because `heat` was already taken** --
`SocialService.heat` is the RAP SHEET, which only rises and never decays.
Two tables, two names; one field carrying both meanings is the
`busyUntil`/`napUntil` bug.

**SHIPPED.** `Config.SPREE` (window 45s, four steps, +0.25 payout and -0.15
floor per step), the state in `SocialService` beside the rap sheet it must not
be confused with, the multiplier applied in `HeistService.deliver`, the break
on any arrest in `PoliceService`, and four pips on the rap-sheet chip 8.4
built. Verified: x1.00 / 1.25 / 1.50 / 1.75 / 2.00 then capped, decay past the
window, a fresh run after a lapse, and the break on arrest.

**THE PAYOUT HALF WAS PAID FOR BY `pigSeconds`, AND 3.2'S AUDIT IS WHAT
FORCED IT.** A spree multiplies the robbing/idling ratio directly, because a
thief on a run sustains max spree and that is what `robberyRates` measures.
Measured before writing any of it: 8.25x base against a ceiling of 10 left
21% of headroom where a x2 spree needs 100%. `RESIDENTS.pigSeconds` came down
400 -> 200 in the same change, so cold is 4.12x, hot is 8.25x -- exactly what
everybody earned before -- and the dearest house went from 0.90h flat to 1.80
cold / 0.90 hot. **The spree is how you REACH the old rate, not a new one
above it.**

That also closes the pacing question 3.2 left open: 4.12x is inside the 3-5x
this document has aimed at since section 2.

**AND IT IS THE FIRST TIME THE PRODUCT OF TWO CURVES WAS CAUGHT BEFORE
SHIPPING** rather than found months later by somebody happening to measure.
The audit now sweeps BOTH ends -- cold against the floor, hot against the
ceiling -- because measuring one lets the other drift.

**THE RISK HALF IS THE EXISTING PATROL:** a spree scales the wanted floor
down to 0.40, so a fast thief draws a records check on a smaller sheet. No new
hazard, nothing new to teach, and the cost lands on the chip the player is
already watching.

### 4.6 Tiptoe: the approach becomes a speed  [SHIPPED, key + touch + rung]

In and verified. `Config.TIPTOE` + `getTiptoeMultiplier` on the server,
applied as one factor inside `currentSpeed` so it inherits every rule above
it with no new balance code; `TiptoeRequest` / `TiptoeState` remotes; C on
the keyboard, toggled through an attribute on the ScreenGui rather than a
local, because that chunk has no top-level register spare (the `BagOpen`
precedent).

Measured live, and this is the whole guarantee chain:

    base walk        16.00
    tiptoe ON         5.60   (= getTiptoeMultiplier(0) x 16, exactly)
    ordering          5.6 < Scruffy notice 11 < carry 12.0   -> true
    tiptoe OFF       16.00
    sneak to the pig  5.60
    after the grab   12.00   carry speed, sneak dropped, flag false
    asking again     "You cannot creep with a piggy bank in your arms."

**You can sneak IN and you can never sneak the money OUT**, proven rather
than asserted.

**Two refusals are load-bearing, not politeness.** Tiptoe is refused while
CARRYING -- 12 x 0.35 = 4.2 would be under every dog's threshold and the
entire risk half of the trade would evaporate -- and while CLIMBING, because
0.35 x CLIMB_MULTIPLIER 0.35 is 0.12, about two studs a second, or seven
seconds to climb an eight-stud fence. That second one closes half of gap 6.5
for this pair.

**THE TOUCH BUTTON SHIPPED, and it mattered more than it sounded.** Most of
this audience never presses a key, and tiptoe is the ONLY counter to a
watching dog -- so a keyboard-only sneak would have made guarded plots
unrobbable for tablet players, which is "defence buys time, never immunity"
broken by an input gap rather than by a number.

The bottom-left corner was the constraint (gap 6.4): four rows deep against
a 546-tall phone, dodge at x=22 and garage at x=98 sharing the garage row,
and the ride picker fanning sideways from x=174. The SNEAK button takes that
same x=174, which is safe because the two can never usefully coexist -- a
sneak happens on a lawn and a ride is switched off anywhere but the street.

**AND THE RUNG SHIPPED AFTER IT.** `Config.UPGRADES.tiptoe` is Sneakers, the
fourth rung of the offence tree, and `currentSpeed` reads the real level
rather than a hardcoded 0. See 6.8 for what it buys and what it deliberately
does not.

### 4.7 The lockpick minigame — as a greed dial, not a gate  [SHIPPED]

Proposal: cracking a pig is an interactive sequence (shapes to match, taps
in order) that gains steps as the victim's lock tier rises.

**The upside is real:** it replaces dead air with input, it scales naturally
with the defence it is fighting, and it makes a skilled player rob faster,
which is what a skill-based core loop needs.

**The risk is repetition, and it is the whole design question.** A minigame
performed forty times an hour goes rote faster than a hold does — better
than the hold for the first twenty robberies and arguably worse by the two
hundredth, because a pause is neutral and a chore is not. "Complete N taps
to open the lock" is a checklist with an animation on it, which is the same
objection this project already raised against a chest that cannot repeat.

**So the minigame should BE the greed dial (4.2) rather than a gate in front
of it.** Each successful step banks another slice of the pig and the next
step comes faster; the thief releases when they choose; a miss ends the
attempt and they keep what they have already taken.

That turns one mechanic into all of the things the loop is missing at once:

- push-your-luck instead of a checklist, so it never fully goes rote
- **partial outcomes**, which the loop currently cannot produce at all
- failure that is a decision rather than a wall
- lock tier expressed as *how many slices you can realistically get* — a
  Titan lock gives you two where a rickety one gives you six — instead of as
  a longer wait

**Two constraints for this audience.** It has to be GLANCEABLE, not
absorbing: chunky shapes, few of them, placed so peripheral vision still
catches the dog crossing the lawn — the tension is supposed to be between
the minigame and the world, and that only works if you can still see the
world. And it has to be thumb-sized, because most of this audience is on a
tablet.

### 4.8 The dog: role changes  [SUPERSEDED BY 4.1/4.8 ABOVE]

**The conclusion below is out of date in one specific way and kept for the
rest.** It argued the dog must never sleep, because a pet you cannot see is
a purchase you cannot see. The agreed model instead has it sleeping ONLY
while its owner is out, and awake and keeping them company while they are
in -- which satisfies the same requirement from the other end and gives the
thief something to sneak past. Everything else here still stands, in
particular the two details 4.1/4.8 does not repeat: the bark should reach
the owner FLAT and 2D (the trick already used to give a chased player their
pursuer's snarl at the front), and the Guard Duty Treat finally means what
it has always been sold as -- *my dog stays on the piggy even though I am
standing here* -- which is a thing you buy BEFORE going out.

The proposal was owner-home means the dog sleeps, and the flaw spotted with
it is correct and fatal: you would never see the pet you paid for. That is
also a rule this project already holds — *"A buff nobody can see is a trap"*
— and `Config` says it in as many words beside the patrol constants: *"A dog
frozen at a corner reads as scenery; one that paces reads as on duty, which
is most of what the purchase buys."*

**Nothing needs to sleep, because the problem was never that the dog is
awake. It is that two things can hard-stop one thief on one lawn.** So the
branch is not awake/asleep, it is WHAT THE DOG DOES WHEN IT NOTICES YOU:

- **Owner away — the dog is the ENFORCER.** It notices, barks, chases and
  catches. It is the only defence present, so it has teeth.
- **Owner home — the dog is the ALARM.** It notices, barks and marks your
  position, and does not chase or catch. The owner does that.

One behaviour, one branch, and it is thematically exactly right: a dog whose
owner is home defers to the owner, and a dog on its own takes matters into
its own paws. Exactly one thing can end a robbery at any given moment, which
is the fairness requirement from 5.5, and the dog is visibly working in both
states rather than being switched off in one of them.

**AND THE DOG'S POSITION BECOMES THE TELL FOR WHETHER ANYBODY IS HOME.**
This is the part worth building for on its own. When the owner is on the
lawn the dog FOLLOWS THEM — it is a pet and it is pleased to see them. When
they are not, it patrols the piggy. So from the pavement a thief reads:

    dog trotting after a player  ->  owner is home, expect a fight
    dog circling the piggy       ->  nobody home, go

Free, zero UI, perfectly legible at forty studs, using an object that
already exists and already moves — and it publishes the single most
important fact about a target. This game prefers a tell to a fight
everywhere it can (the guard duty collar, the overflowing bin, the published
patrol); this is the biggest one available.

**Two things fall out for free.** The bark should reach the owner FLAT and
2D, the same trick already used to give a chased player their pursuer's
snarl at the front rather than fading behind them. And the Guard Duty Treat
finally means what it has always been sold as — *my dog stays on the piggy
even though I am standing here* — which is a thing you buy BEFORE going out.

---

## 5. The camping problem

Correctly identified as the risk that all of section 4 creates: if the dog
watches the approach AND the owner can break a hold, then an owner who
simply stands on their own lawn is unrobbable, and the loop dies.

**It is already a rule violation, which is worth saying first.** CLAUDE.md:
*"A fence must never be uncrossable. Defence buys TIME, never immunity. An
un-robbable player kills the offence tree and stalls the economy at the
top."* Camping is that failure arriving through a player rather than through
a purchase, so it does not need a new principle — it needs the existing one
enforced against a case it was not written for.

### 5.1 The real fix is the economy flip, and it needs no mechanic at all

Camping is only worth doing because **idling currently earns 7 to 14x what
robbing earns** (section 2). Standing on your own lawn is, right now, the
mathematically optimal way to play this game. That is the whole problem, and
it is not a stealth problem.

Land 3.2 and it inverts: an active thief out-earns an idler 3-5x, so a
player who camps all session is choosing to earn a fifth of what everybody
else earns. **Camping becomes self-punishing and requires no counter-
mechanic.** The right response to a camper is that they are losing.

### 5.2 NPC plots are the release valve

Even in the worst case where every human camps, 3.1 means the street still
has uncapped, always-available targets. The loop can never stall on player
behaviour. Second reason that item is load-bearing.

### 5.3 Locking the front gate is the wrong direction

Proposed as the counter; it makes the problem worse on three counts.

- It contradicts a stated rule: *"The gate is always open at every tier — 24
  studs wide at Rickety and still 8 at the Moat. So the plot is enterable by
  anybody, with no item, at any tier."* What a solid fence stops is the SIDE
  and BACK crossing; the front door is deliberately never closed.
- It does not address camping at all. A camping owner is standing on the
  lawn — they do not need the gate shut, and shutting it costs them a ladder
  to get back into their own garden.
- It is defence stacking on defence, on the one plot that already has an
  owner standing in it.

**The salvageable version is the inverse: let the THIEF jam the gate behind
them.** That is offence, it buys a breath rather than an escape (the wheelie
bin's own rule), and it is the mechanic pointed at the moment the design
actually wants pressure on — the getaway.

Refined:

- **It is a PROMPT ON THE GATE, not a hot bar item.** The number row is full
  at ten and CLAUDE.md already records that the eleventh consumable had to
  take a letter and that there are fewer letters left than it looks. A
  prompt costs no slot, and `Config.PROMPTS` is already the vocabulary for
  giving one its own colour, glyph and verb.
- **The owner is NEVER affected.** Precedent exists and is exact:
  `firePenalty` returns early for the plot's own owner because *"owners
  cross their own defences freely; they paid for them."* A jammed gate that
  could shut a child out of their own garden is the griefing case, and this
  rule kills it outright rather than making it merely unrewarding.
- **What it actually stops is the DOG and any bystander.** Sides and back
  are solid and the gate is the only opening, so jamming it genuinely
  bottles the yard — and trapping a guard dog in the garden it guards is
  legible and funny without a word of explanation.
- **Two to three seconds, and the getaway is what sets that.** The run home
  is 53 studs at carry speed 12, about 4.4 seconds. A five-second jam covers
  essentially the whole getaway and deletes the defence; two to three breaks
  the dog's line without erasing the run. Coins every use, like every other
  counter here.
- **Jammed on the way OUT, behind you.** Jamming on the way in locks the
  thief in with the dog.

### 5.4 A defended plot should be a target that needs setup, never a wall

The counter-play a thief already owns: bones for the dog, a prank or gadget
for the owner, the bin to wait out guard duty, the ladder for a side entry
the owner is not watching. A camping owner should read as *this one needs
preparation*, which is more interesting than an empty lawn — and is exactly
what makes the offence tree worth buying.

The invariant to write down and audit, in the shape `auditEconomy` already
uses: **nothing an owner does, in combination with anything they can buy,
may reduce the maximum possible take to zero.**

### 5.5 Do not let the dog and the owner both stop you  [SHIPPED]

If the owner is home, the dog should stand down, or the owner's interrupt
should cost something (proximity, a cooldown, a real tag at 14 studs). Two
independent hard-stops on one lawn is how a plot becomes a wall without
anybody deciding it should.

**IT WAS AGREED, WRITTEN INTO `Config.DOG_WATCH`'s OWN COMMENT, AND NEVER
BUILT.** For the whole life of the watcher `releaseDog` asked
`GuardDog.isReady` and nothing about who was home, so an owner standing on
their own lawn got a chasing dog AND a tag of their own -- exactly the two
hard-stops this section exists to forbid. Found by reading the comment beside
the code rather than by anything failing, which is the only way that class is
ever found.

**AND IT WAS WORSE THAN MERELY ABSENT.** `shouldBeUp` is `guardDuty or
ownerHome or (heard and stirred)`, and `isWatching` was built on it -- so
`ownerHome` short-circuited the third clause, which IS the `wakeDelay` grace.
An owner-home dog could be let off on the first noisy tick with no beat to
hear it stir, making a defended-and-occupied plot the most dangerous ground
in the game rather than the least.

**THE FIX IS A SPLIT.** `shouldBeUp` stays POSTURE (all three reasons put a
dog on its feet); a new `isAlerted` is READINESS (it heard you, and the beat
has passed); `isWatching` reads readiness only. `releaseDog` then returns
early when `GuardDog.isOwnerHome`, after barking and marking -- so the dog is
the ALARM, and the owner is the defence. The mark is a Highlight in the alarm
tone that expires with `alertSeconds`, and it lives in HeistService rather
than GuardDog because GuardDog knows nothing about players.

Verified: 14 of 14 predicate cases, and `bark` driven on a real built dog
(never chases, rouses rather than barking from a kennel, silent at level 0).
The branch END TO END needs a second player, because the watcher skips a
plot's own owner when looking for an intruder.

---

## 6. Gaps in the plan as it stands

Reviewed after tiptoe, the greed minigame, the dog role split and the gate
jam went in. Ordered by how much damage each does if it is not answered.

### 6.1 The loss cap and the greed bar  [DECIDED: the bar drains the pig]

**Settled: the bar shows the PIG, and drains it.** The earlier proposal --
draw the victim's remaining allowance instead -- was solving a presentation
problem by changing the unit, and the unit was right.

Two things make that safe. **Against a resident there is no allowance at
all**, so the bar simply drains the pig, and that is most robberies in the
game. **Against a real player `LOSS_CAP` still binds**, because it is the
anti-bullying protection and is not negotiable -- so the bar draws the whole
pig with a MARKED LINE where the allowance runs out. A thief reads "this pig
is enormous and I can take this much of it", which is information rather than
a bar that mysteriously refuses to fill.

That also means a recently-robbed player advertises the fact, in the same
place and the same glance as everything else about the target.

### (was) 6.1 The loss cap and the greed bar collide

A full five-slice crack takes 21.9% and `LOSS_CAP` allows 25% per victim per
hour. So the FIRST robbery of somebody fits — and the second one inside that
hour has about 3% of allowance left, so the gauge would fill one slice and
then visibly refuse to move.

That is either the best tell in the design or a mechanic that reads as
broken, and which one depends entirely on presentation. **The gauge has to
draw the victim's REMAINING ALLOWANCE, not the pig.** A thief walking up to
a recently-robbed plot should see a short bar and understand instantly that
somebody got here first — which is information the game currently delivers
as a refusal message after the fact.

Unresolved: does the allowance become visible from the pavement too (3.4),
or only once the panel is open?

### 6.2 When the alarm fires  [DECIDED: on a failed slice, never on a clean robbery]

**Settled, and recorded as `Config.CRACK_ALARM_ON_MISS`.** Land every slice
and the victim is never pinged; miss one and the street hears about it.

It is the answer that makes skill worth having -- alarm on the first slice
and the owner always wins, alarm on completion and the owner can never
defend, only chase. **And it corrected the dog's wake trigger**, which an
earlier draft here had as the lock being RATTLED: if merely working a lock
wakes the dog then every robbery is loud, stealth buys only the approach, and
being good at the minigame is rewarded with nothing. The dog wakes on a MISS
too.

It does not make a clean robbery invisible, which is the objection to check
it against: the thief still carries a labelled miniature of the victim's own
pig and still wears a Highlight visible through walls. A silent crack buys
stealth of the ALARM, never stealth of the getaway.

### (was) 6.2 Nothing decides when the alarm fires

Today the victim learns they have been robbed on COMPLETION, because
`attemptSteal` is atomic. A progressive crack has five moments it could fire
at, and the choice decides whether robbing a present player is possible at
all:

- alarm at slice 1 — the owner gets four slices of warning and always wins
- alarm at completion — the owner can never defend, only chase
- alarm on the LOUD entry only (4.3) — the quiet crack is genuinely quiet

The third is almost certainly right and it is what makes 4.3 load-bearing
rather than flavour, but it has not been decided.

### 6.3 There is no such thing as an absent human victim  [raises 3.1]

A plot is RELEASED when its owner leaves, so every human target is by
definition present and able to fight back. Combine that with 4.8 (owner home
means the owner is the defence) and **every human robbery is a live
contest** — there is no soft target among players, ever.

That is good for drama and bad for a loop that has to run for a nine-year-old
who is not winning contests yet. It means NPC plots (3.1) are not a
population fallback, they are the ONLY source of low-pressure income in the
game. Their priority goes up accordingly.

### 6.4 The input budget is already spent  [RESOLVED for tiptoe, live for the rest]

Tiptoe needs a key AND a touch control, and most of this audience never
presses a key. The map is Q, B, V, R, I, Escape, F2 and the number row; the
bottom-left HUD corner is measured at FOUR rows deep against a 546-tall
phone viewport, with CLAUDE.md stating that *"anything added above 250 is
climbing into the middle of the screen."*

What is left is width, not height — the dodge already shares the garage's
row for exactly this reason. So tiptoe probably shares a row too. Unwritten,
and it is the difference between the mechanic existing on a tablet and not.

Worse: the crack panel wants the same thumb the hot bar wants, at the same
moment.

### 6.5 Multiplicative slows  [HALF CLOSED: tiptoe refuses to stack with a climb; no general rule yet]

Every speed here multiplies into `currentSpeed`, which is what makes tiptoe
cheap to add — and it cuts both ways. Tiptoe 0.35 x climb 0.35 is 0.12, or
about 2 studs a second: an 8-stud ladder would take roughly seven seconds to
climb while sneaking. A snag on top of that approaches zero.

This is precisely the class of failure this project keeps recording. It
needs either a floor on the product, or a rule that tiptoe and the climb are
exclusive, before any of it is written.

### 6.6 Telemetry  [AGREED, DEFERRED by decision — core loop first]

The actual goal is a popular game, and there is no telemetry anywhere in
this repo. Not one of these is currently knowable: time to first robbery,
robberies per session, share of income coming from robbing, what fraction of
players ever rob at all, where session one ends.

Every other item on this list is a guess until that exists, and the economy
invariant in 3.2 is only auditable in theory without it.

### 6.7 Nobody has written the thirty seconds  [CLOSED — written in section 7 and shipped]

The plan had every ingredient and no storyboard. Section 7 is the sequence.

### 6.9 Residents were a faucet  [FIXED: pigSeconds, verified 4.92x at every level]

Measured against the live Config after 3.1 shipped, one thief cycling seven
residents on a ~13 second round trip:

    lvl  1  one haul        480   robbing/hr        132,923   idle/hr     36,000   3.7x
    lvl 10  one haul      9,917   robbing/hr      2,746,324   idle/hr    536,175   5.1x
    lvl 20  one haul    286,862   robbing/hr     79,438,845   idle/hr 10,780,629   7.4x
    lvl 40  one haul  9,302,788   robbing/hr  2,576,156,766   idle/hr 209,799,228  12.3x

**The Sky Castle -- 80M, the most expensive thing in the game and meant to be
the last thing anybody finishes -- is ONE HOUR of this at level 20.**

**It is the same class of mistake as the one it fixed, inverted.** A steal
takes a fraction of CAPACITY, which grows at 1.40 a level, while income grows
at 1.35 and the round trip is a CONSTANT thirteen seconds. So robbing income
rides the capacity curve, idle income rides the income curve, and the ratio
widens forever. Two curves multiplied without anybody checking the product --
exactly what section 2 caught, caught again a level up.

Structurally: seven residents each earn a full player's income, all of it is
reachable by one thief, and `HEIST_PAYOUT` doubles it on the way in.

**THE PROPOSED FIX: A RESIDENT'S PIG HOLDS A FIXED NUMBER OF SECONDS OF ITS
OWN INCOME, NOT A SHARE OF A CAPACITY LADDER.**

Capacity means *how much you can hold before you have to spend* -- it is a
storage limit, and it exists because a full pig stops earning and that is
what drives every purchase in the game. **A resident never spends anything.**
So capacity is not merely the wrong number for one, it is a concept that does
not apply to one, and using it made a resident's worth ride a curve chosen
for a completely different job. That is the whole bug, stated as a category
error rather than as a tuning miss.

Measured, that is exactly what drifts:

    lvl  1  pig =  300 seconds of its own income   ratio  3.69x
    lvl 20  pig =  599 seconds                     ratio  7.37x
    lvl 40  pig =  998 seconds                     ratio 12.28x

Pin the seconds and the ratio is identical at every level, with one linear
dial (`ratio ~= 0.0123 x pigSeconds`):

    pigSeconds=300  ->  3.69x at lvl 1, 20 and 40   (pig 3.0K / 898K / 17.5M)
    pigSeconds=400  ->  4.92x at every level        (pig 4.0K / 1.2M / 23.3M)
    pigSeconds=500  ->  6.15x at every level        (pig 5.0K / 1.5M / 29.1M)

`RESIDENTS.seedFraction` and the capacity lookup are both GONE; `pigSeconds` is the
only number left, and it says in plain words what a resident is worth: *this
house is worth about seven minutes of your own income to rob.*

**A CONSTANT RATIO IS THE POINT, NOT A LOWER ONE.** The catalogue is being
extended toward a 1B endgame, so the absolute figures can be whatever the
prices need. What cannot be tuned around is a ratio that MOVES: at 3.7x early
and 12.3x late, no single set of prices is right for both, and the late game
quietly becomes a different game where anybody who stops robbing stops
progressing at all. Pinning it makes the pacing one decision instead of
forty.

**AND `HEIST_PAYOUT` STAYS AT 2 ON A RESIDENT -- REVERSING WHAT THIS SECTION
SAID AN HOUR AGO.** The earlier argument was that the multiplier exists to
decouple a thief's gain from a victim's pain, and a resident has no pain, so
it should not apply. That reasoning is sound and the conclusion is dangerous:
paying LESS for robbing an empty house than for robbing a real child makes
robbing the child the better play. In a game for under-twelves the incentive
must point at the NPC, so a resident has to pay at least what a player does.
The multiplier stays; `pigSeconds` is the dial.

### 6.8 Smaller, still open

- **Retention past minute one** is untouched. Revenge markers and the daily
  ladder exist; nothing in this plan says why anybody returns tomorrow.
- **Two-player verification.** Everything in sections 4 and 5 needs a second
  player. NPC plots cover perhaps 60% of it and the owner-versus-thief cases
  none.
- **CLOSED: every field in `Config.CRACK` and `Config.TIPTOE` is live, and
  so are the three `notice` fields.** The last inert pair was
  `TIPTOE.perLevel` and `.max`, with `currentSpeed` passing a hardcoded
  level 0; `Config.UPGRADES.tiptoe` (Sneakers, offence rung 4) closed it and
  `currentSpeed` reads `UpgradeService.getLevel(player, "tiptoe")`. What the
  rung buys is SPEED and never STEALTH -- `base` 5.6 is already under
  Scruffy's 11 and Rex's 10.2 and `max` 9.6 is still nothing to a Titan's 0,
  so a level is a 71% faster approach against a finite alert window. Which
  dogs a sneak beats stays the DOG's tier to decide. `max` is 4 because
  `base + 4 x perLevel` lands exactly on `TIPTOE.max`, so retuning the stat
  cannot strand a rung. Verified live: prices 4.2K / 9.2K / 20.3K / 44.7K,
  sneak 5.60 through 9.60, ordering maxed 9.60 < Rex 10.2 < carry 12.0 still
  holds, and it cost nothing outside Config -- no schema bump, no UI code.

---

## 7. The first thirty seconds

**ONE SENTENCE, NOT A TUTORIAL.** The game is called Rob a Piggy Bank and
the instruction is *go and rob a piggy bank*. Anything more than that is a
tutorial for a game whose entire premise fits in six words, and a nine-year-
old closes a tutorial. The only thing the game has to do in the first two
seconds is point.

    t=0    Spawn on your own plot, 17 studs from your own piggy. It is
           EMPTY, and that is the hook rather than a problem -- there is
           nothing here to look at, so there is nothing to stand around for.

    t=0-2  One line, once:
               "Your piggy is empty. Go and take somebody else's."
           and a marker over the nearest worthwhile pig. No panel, no OK
           button, no arrows to dismiss. It retires itself on the first
           delivery and is never shown again.

    t=2-7  Walk. The gate is open, it always is. The target's pig carries a
           gold figure readable from the pavement (3.4), so the first thing
           this game ever teaches is THAT PIGS HAVE NUMBERS ON THEM AND YOU
           CAN GO AND GET ONE.

    t=7-9  Cross the lawn. The dog is circling the piggy, which -- once 4.8
           lands -- is the tell that nobody is home. Nothing is explained
           about that. It is learned by being wrong once, later.

    t=9-14 The crack. The panel opens, the shapes come, the bar fills:
           2%, 4.8%, 8.7%. The player stops whenever they like. THE FIRST
           REAL DECISION IN THE GAME IS A GREED DECISION, made nine seconds
           in, with no explanation needed, because a filling bar and a
           bigger number explain themselves.

    t=14-19 Run home carrying a glowing miniature of their pig with their
           name over it. The game already builds this and it is the single
           most legible thing in it.

    t=19-20 Deliver. The haul lands DOUBLED. A toast says so.

    t=20-30 Buy the first upgrade with the proceeds (3.5).

Thirty seconds, one sentence of instruction, and the player has performed
the entire loop the rest of the game is made of: pick a target, decide how
greedy to be, get home, spend it.

**What this storyboard REQUIRES, which is the real value of writing it:**

- **The first target must already have money in it.** At t=7 on a fresh
  server every pig holds ~300 coins and 2% of that is six. The storyboard
  does not work without seeded pigs or NPC plots (3.1) — this is the second
  thing that makes 3.1 blocking rather than nice.
- **The first haul must clear the first upgrade** or t=20-30 is a lie (3.5).
- **No shield may block the first target.** A "protected for 9 minutes"
  refusal at t=9 ends the session.
- **The alarm question (6.2) is decided here by default:** the first robbery
  a player ever performs cannot be a live contest against a defending owner.
  Either the first target is an NPC, or quiet cracks do not alarm.

---

## 8. Will this actually stay fresh?

Asked directly, and the honest answer is: **these changes fix "a robbery has
no gameplay". They do not fix "every robbery is the same robbery."** Those
are different problems and only the first one is solved above.

Everything in sections 4 and 5 varies the VALUES inside a fixed structure.
The sequence is always: pick a target, cross a lawn, crack a pig, run home.
The numbers change, the tension changes, the opponent changes — the VERBS
never change, and they never change ORDER. That is the definition of a loop
that flattens eventually. It will take much longer to flatten than the
current one, and it will still flatten.

**THE DISTINCTION THAT MATTERS FOR KEEPING IT SIMPLE: variety of SITUATIONS
is free for a player to understand, variety of MECHANICS is expensive.**
A new place to rob is understood on sight. A new button is a thing to teach.
So the way to keep this fresh WITHOUT making it complicated is more places
and reasons to rob, not more things to press. Everything below follows that
rule.

### 8.1 Rob the shops  [REJECTED on theme — kept for the reasoning]

Four shop fronts already stand on the verge, fully built, with doors and
prompts. They are scenery. **Make them robbable.**

A shop heist is a genuinely DIFFERENT kind of robbery rather than the same
one with different numbers: no owner, fixed loot, a till or a safe instead
of a pig, an alarm on a timer, and the POLICE as the response instead of a
dog. Same verbs, completely different situation — which is exactly the
variety this loop needs and the only kind that costs the player nothing to
learn.

It answers three open problems at once:

- **6.3, no absent human victims.** A shop is a target that is always there,
  always fair, and cannot be griefed or made to cry.
- **The risk/reward dial can be cranked hard**, because nobody is hurt. This
  is where the big scores live.
- **It is thematically clean for the audience.** Robbing a shop is a cartoon
  caper; robbing a child is the thing this design keeps having to defend.

The four shops differ already — a boutique, a glasshouse, a workshop, a
strongroom — so they can differ as heists too, at no art cost.

**AND IT WAS REJECTED, ON THE ONE GROUND THE ANALYSIS ABOVE NEVER ASKED
ABOUT: THE GAME IS CALLED ROB A PIGGY.** Every argument above is about
SUPPLY -- a target that is always there, always fair, and cannot be made to
cry -- and residents already answer all three of them. What a shop would
add on top is a second kind of thing to rob in a game named after the first
kind, which spends the clearest premise this design has. The three problems
it was going to solve are solved: 6.3 by residents, the risk/reward crank by
a resident having no `LOSS_CAP`, and the audience argument by robbing an
empty house rather than a child.

So the variety this loop needs has to come from making the piggy robbery
DEEPER rather than from a second target. That is 8.2 (rungs that unlock
verbs), 8.3 (robbing together) and 8.4 (surfacing what already exists) --
and it puts more weight on 8.2 than this section originally gave it, since
it is now the only structural answer left to "every robbery is the same
robbery".

### 8.2 Upgrades that unlock VERBS, not just numbers  [STARTED: casing shipped]

Every rung in all six trees is a multiplier: faster, more, cheaper, slower
for them. **Nothing you buy at rebirth 5 lets you do something you could not
do at minute 10.** A maxed player performs the identical robbery to a new
one, with bigger figures on it. That is the deepest long-term boredom source
in the design and nothing in sections 3 to 6 touches it.

Some rungs should hand over a capability instead:

- Lockpicks top rung: see the crack sequence one step ahead
- Bigger Sack: carry TWO pigs, so you can hit two plots before delivering
- Speed Boots top rung: vault a fence without a ladder
- A casing ability: read a plot's lock tier and remaining allowance from the
  pavement

Each one changes how a robbery is PLANNED rather than how fast it resolves,
and each is one new thing to understand rather than one new thing to press.

**SHIPPED: CASING, on the top rung of Lockpicks.** The rob badge grows a
four-pip ladder showing the victim's Vault Lock tier, so the street stops
being a shopping list ranked purely by size and becomes value-against-
difficulty. `Config.CASING` + `Config.canCase(level)`, the threshold DERIVED
from the Lockpicks rung count rather than pinned, drawn in `RobBadge` off the
`UpgradeState` the client already receives.

**IT SELLS BACK WHAT MOVING THE VAULT DIAL COST.** The dial used to carry its
metal from the street; the hatch move traded that away, and this returns it to
the player who bought the right to have it.

**THE RULE THAT ANSWERS THIS SECTION'S OWN OPEN QUESTION -- "does converting
one break the save of anybody who already owns it" -- IS THAT A VERB IS ADDED
AT A RUNG, NEVER SWAPPED FOR ONE.** Lockpicks still widens the crack window at
every level exactly as before, so a player who maxed it last week simply gains
the verb: no migration, no schema bump, nothing to reconcile. Every future verb
goes in the same way.

**AND ONE CANDIDATE ABOVE IS DEAD, MEASURED AGAINST THE CRACK AS BUILT.**
"See the crack sequence one step ahead" was written before the crack shipped,
and `Config.CRACK` deliberately has NO CLOCK ON A STEP -- a step runs until it
is tapped. So the zone is already visible for as long as anybody likes, and
seeing its position early buys nothing, because the marker sweeps the whole
dial and every position is equally hittable. It would have read as a
capability and done nothing.

**STILL OPEN IN THIS SECTION:** carrying two pigs (a real refactor of
`carrying`, which is single-victim state), and vaulting a fence without a
ladder (which fights both the `jumpReach` tuning and the ladder item that
exists to sell exactly that route).

### 8.3 Rob together  [not started]

`FRIEND_BONUS` is the only cooperative mechanic in the codebase and it is
passive income for other people existing. In a game with eight players whose
only interaction is one-directional theft, the social axis is almost
entirely untapped — and co-op is the cheapest possible source of infinite
variety, because the other player is the variety.

The crack minigame is a natural home: two thieves crack faster, or one
distracts the dog while the other works. Nothing new to teach, and it turns
a solo transaction into a story with somebody else in it.

### 8.4 What is already built and underused  [HALF SHIPPED]

Worth saying plainly, because the temptation is always to add: the events
system (raid, rush hour) already changes the rules of the street
temporarily, which is exactly the disruption a flat loop needs, and it is
almost invisible. Most Wanted and the rap sheet already model a session arc.
**Surfacing what exists is cheaper than building 8.1 to 8.3 and should come
first.**

**THE EVENTS HALF WAS ALREADY DONE WHEN THIS WAS RE-READ.** The standing
countdown chip and the event banner both shipped after this section was
written, so "almost invisible" stopped being true of events and stayed true
of the rap sheet. Measured before touching anything: `SocialService` fired
exactly TWO remotes -- `Notify` and `RevengeMarker` -- and `StateUpdate`
carried not one social field, so a player could not answer *how much have I
taken this session* anywhere on the HUD.

**SHIPPED: THE RAP SHEET IS THE SECOND CHIP IN THE TOP-RIGHT COLUMN.**
`Remotes.WantedState` (per client, because a floor is seconds of the reader's
own income), `SocialService.pushWanted` on the board's own tick plus
immediately on a delivery, and `Shared/Wanted.luau` -- required and started in
one statement holding no local, because ClientMain is still at the 200-register
ceiling.

The chip is hidden until you have stolen something, then reads STOLEN, WANTED
or HUNTED with the RING carrying the escalation: muted, gold once the poster
has your name on it, red once your sheet clears your own floor and a patrol is
genuinely coming. Verified end to end against real server state, not crafted
payloads.

**TWO THINGS THE MEASUREMENT CAUGHT.** "MOST WANTED" (88px) and "PATROL
COMING" (96px) do not fit an 82px caption box, so the captions are three
six-letter words instead; and the event chip's own value box is 44px against
a "888.8K" that measures 55 -- fine for the clock it holds and wrong for
coins, so copying its geometry across would have shrunk every large sheet in
the game.

**STILL OPEN IN THIS SECTION:** the events half needs no work, but nothing yet
surfaces the RAP SHEET'S CONSEQUENCE ladder beyond the chip -- how far from
the floor you are, and what the leader has. Both were deliberately left out of
the payload because a 176x34 chip cannot honestly draw them; if they are
wanted they need their own surface rather than a fourth thing in that chip.

---

## 9. Decided vs open

**SHIPPED AND VERIFIED LIVE:** 3.1 residents (both stages), 3.2's audit, 4.5's
spree, 8.2's casing, 8.4's rap-sheet chip, 5.5's alarm-only dog, 3.3
the shield ending on a first robbery, 3.4 the value on the pig, 3.5 (already
true, no change needed), 3.6 the one-line objective, 4.6 tiptoe including the
touch button and its upgrade rung, 4.1/4.8 the watching dog, 4.2/4.7 the
crack. Section 7's thirty seconds runs end to end.

**THAT IS THE WHOLE OF SECTIONS 3 AND 7.** Everything the plan set out as the
core loop is in and measured. What is left is section 4's remainder, section
5's two-player items, and section 8's freshness problem.

**Reasoning for all of the above has moved into CLAUDE.md** and the
descriptions into GAME.md, which is what this document exists to feed. The
entries are kept here only until the section they belong to is finished.

**DESIGN AGREED, IN `Config`, NOTHING READS IT:** nothing. That category is
empty for the first time -- `Config.CRACK`, `Config.DOG_WATCH`, every
`notice` and every field of `Config.TIPTOE` are all read now.

**REJECTED:** the owner-locked front gate (5.3), kept only inverted as a
thief-side gate jam; and robbing the shops (8.1), because the game is named
after robbing a piggy and residents already supply the PvE target it was
going to be.

**NEXT, IN ORDER (as of the Sneakers rung shipping):**

1. **More of 8.2.** Casing is the first verb and the pattern is now
   established (added at a rung, never swapped for one, threshold derived
   from the rung count). The two remaining candidates are both real work:
   carrying two pigs, and a fence vault. Neither is obviously right -- see
   8.2.
2. **4.3, loud versus quiet entry.** The last unstarted item in section 4,
   and the only one left that adds variance WITHIN a robbery.

**THE PACING DECISION IS SETTLED:** `RESIDENTS.pigSeconds` came down 400 ->
200 when the spree shipped, so a cold thief earns 4.12x and a maxed run earns
8.25x. See 4.5.

Blocked on a second player: 4.4 the owner interrupt, 5.3's thief-side gate
jam, and the end-to-end run of 5.5's alarm-only dog (the guard and both
halves of its mechanism are verified; only the two-player integration is
not). Telemetry (6.6) is agreed and deliberately deferred behind all of
the above.

**Open questions:**

- Does the greed dial replace `STEAL_FRACTION` or scale it?
- Where does heat live -- extend the rap sheet, or a separate session value?
- If robbing becomes the primary income, does the idle drip earn its place at
  all, or does it become purely the offline/AFK floor?
- Does 4.3's "loud" option need its own animation, or is it the same hold
  with a different clock?
- Does the dog's notice threshold care about DISTANCE as well as speed, or is
  a lawn simply a lawn?
- Does the minigame need to differ per lock tier visually, or only in pace?
- Which existing upgrade rungs become verbs (8.2), and does converting one
  break the save of anybody who already owns it?
- Does co-op robbery (8.3) split the haul or pay both in full?
- Should a resident's pig be visible as a different colour or marker, so a
  player can tell a neighbour's house from a real player's before they
  commit to crossing the road?
