# Brief: redesign the progression of *Rob a Piggy Bank* around robbing

*A prompt written to be handed to a design collaborator. Not a plan — a request
for one. Nothing in here is decided except the constraints marked as settled.*

---

You are a senior game designer with deep Roblox live-ops experience, working on a
shipped-but-unlaunched game. I want you to think from first principles and argue
with me. Do not be agreeable; where my brief contains a mistake, say so and price
it.

---

## The game

A shared-economy PvP game for an **under-12 audience**. Eight players to a server,
one plot each on a suburban street with ten plots and four robbable shops.
Sessions run **15-25 minutes**. Every player owns a piggy bank that fills with
coins over time. Other players rob it. Defence (fence, guard dog, vault lock) and
offence (lockpicks, bigger sack, sneakers, speed boots) are competing upgrade
trees. Everything in the world is generated in code; there is no hand-built
geometry, so new systems are cheap to build and new *art* is expensive.

**The pig is the wallet.** There is no bank: income drips into the pig until it is
full, spending draws from it, and a full pig stops earning. All of it is
stealable. A player's plot is released when they log off, so nobody is ever robbed
while away.

There are two currencies today:

- **Coins** — income over time, and the price of everything in the shop.
- **Loot** (`data.loot`) — **1 per completed robbery**, plus 3 for attending an
  event, 2 per raid drone knocked down, and a shared bonus if the street clears
  one. It cannot be bought and cannot be earned by idling. Today it buys very
  little.

---

## The problem, measured

**1. The game ends.** Simulated against the real economy functions with no
robbing, no offline income and no dailies — the floor — a player reaches the level
cap and rebirth 10 in **17 days at 2h/day**, or about 1.4 days of actual play.
After that the catalogue is bought and there is no reason to open the game.

**2. Robbing is not the reason anybody plays.** It is worth 3.4x-4.0x the return
of standing still cold, 6.7x-7.9x on a maxed spree. That is a good number and it
is still *only a faster way to buy the same things*. A player who has bought
everything has no reason to rob anybody.

**3. The endgame is one afternoon.** The most expensive item in the game — an 80M
coin house meant to be the last thing anybody finishes — is **0.90 hours of
optimal robbing** at level 20.

**4. Events are an accessory.** Street events (an alien raid, a rush hour)
contribute **7.5% of hourly income** at endgame: 808K/hour best case against
10.8M/hour of simply standing still. They are a thank-you, not a reason to return.

**5. Houses and yards are pure display.** Nine house tiers up to 80M coins, nine
lawn ornament slots, gardens, dog coats and kennels — and not one of them does
anything in the core loop. They announce wealth and nothing else.

**6. There is nothing to want that is not for sale.** Roughly **122 collectables
across twelve catalogues**: 45 skins, 23 lawn ornaments, 9 house tiers, 9 effects,
6 rides, 6 dog coats, 6 kennels, 4 trophies, 3 dog toys, and garden pieces. Skins
come out of five crates; everything else is a coin price. Nothing is gated behind
*doing* anything except four trophies.

---

## What I want you to design

A progression and retention loop where **robbing other players is the point of the
game**, not the fastest way to farm a shop. Specifically:

- **Robbing must pay in things coins cannot buy.** Content, ranks, records,
  access, items — reasons to rob somebody when you are already rich.
- **The yard and house must earn a job in the core loop.** I have two directions
  in mind and want you to develop both and say how they combine:
  - **Production** — yard objects generate something over time that *only robbing
    can move*, so idle play feeds the active loop instead of competing with it.
  - **Reputation** — the yard publicly displays your record: who you have robbed,
    what you are holding, your standing this season. Readable from the pavement,
    so it drives target selection.
- **Seasons and leaderboards** are wanted, and I need you to be honest about the
  live-ops cost of anything you propose. A season that needs me to author content
  every month is a different product from one that runs itself.
- **Events must be load-bearing**, not a side dish. Today they are 7.5% of income.
  Tell me what they should be structurally, not just how much they should pay.
- **Achievements** are wanted as a real progression track, not a checklist of
  toasts.
- **Use the currency split as a lever.** See the section below: I intend to make
  coins purchasable, which means coins must stop reaching anything random. The
  cleanest version of that is also the thing I most want from this design —
  **the earned-only currency becomes the one that buys the interesting content,
  and robbing is how you get it.** Work out whether that is the spine of the
  whole economy or only a piece of it.

---

## The currency rule, which I am deliberately changing

Roblox regulates **paid random items**: anything random bought with Robux *or with
in-game currency that is purchasable with Robux*. Regulated does not mean banned —
it means disclosed odds, a `PolicyService` gate, and regional lockouts (UK
under-18, Australia, Belgium) where a large share of an under-12 audience meets a
button that refuses to open.

Until now this game stepped **outside** that rule rather than complying with it, by
a single line: *coins are never purchasable with Robux, at any price, ever.* That
kept every crate, spin and drop an ordinary in-game reward for in-game money.

**I want to sell coins.** So the invariant has to move rather than be deleted, and
the new one is:

> **NO RANDOM OUTCOME IN THIS GAME MAY BE REACHABLE WITH COINS.**
> Every random reward is priced in an earned-only currency, or gated behind an
> action, or it does not exist.

Two things in the game today break that and must be solved by your design:

1. **The five crates cost coins.** They are the main random system and the main
   source of skins. They have to be repriced onto something unbuyable. `data.loot`
   already exists and is robbing-and-attendance only — decide whether that is the
   right home, or whether the crate economy wants its own currency, and argue it.
2. **The rebirth skin drop is gated behind banked coins.** The rebirth gate is a
   multiple of your pig's capacity, so once coins are purchasable, money buys a
   *faster route to a random outcome* even though it never buys the outcome
   itself. This is the subtle one. Say whether you think it falls inside the rule,
   and design it out either way if the fix is cheap.

Already safe and worth not breaking: the **shop drop** (one in five completed
robberies), the **event drop reel** (attendance), and **combining** duplicate
items into a higher-tier roll — all gated by doing something rather than by paying.

Two further constraints on this, both settled:

- **Monetisation is named things, never currency that reaches randomness.** A
  Robux purchase may grant a specific item — a pass, a ride, a cosmetic riding
  stance. Selling coins is acceptable only under the invariant above.
- **Do not invent a third currency without a real argument.** This game already
  merged three currencies into one because a nine-year-old cannot hold three. Two
  is the budget; spending the third has to buy something large.

---

## Constraints that may NOT be broken

These are settled. Design around them; do not propose removing them.

1. **Nothing may be aimed at a specific player by another player as a punishment.**
   No calling the police on somebody, no targeted griefing tools. A gadget can be
   thrown; an officer can never be pointed.
2. **Under-12 audience.** No weapons, no violence in the model, no mechanic that
   reads as bullying. Roblox's maturity questionnaire is answered by what is
   literally in the game.
3. **Being robbed while offline is impossible** and must stay impossible: a plot
   is released when its owner leaves.
4. **A defence buys TIME, never immunity.** No purchase may make a player
   un-robbable, or the offence tree dies and the economy stalls at the top.

---

## The rule I am deliberately breaking, and what I need from you

The game's design document states, as a load-bearing rule:

> **A ROBBED PIG WEARS A PLASTER, NOT A LOST HOUSE.** Losing permanent progress
> was proposed as the incentive and rejected: it is the one thing every big game
> on the platform protects, and for this audience it is a crying-then-uninstall
> event a parent sees.

**I want to break it.** I want a thief to be able to take a real, named item off
another player and keep it. That is the strongest possible reason to rob somebody
and I believe the game needs it.

I am not asking you to agree. I am asking you to **make it survivable**:

- What class of thing may permanently change hands, and what may never? (Is the
  line "things you were given" against "things you earned"? "Things that were
  themselves stolen"? "Things with a visible replacement path"?)
- How does a nine-year-old who just lost something feel in the next sixty
  seconds, and what does the game put in front of them?
- What stops the best player on the server accumulating everything and the
  bottom of the ladder never recovering?
- What is the equivalent of `LOSS_CAP` — the existing rule that a victim may lose
  at most 45% of their pig per rolling hour, whoever is robbing them?
- **Does anything bought with Robux ever become stealable?** Answer this
  explicitly. If a paid item can be taken permanently, that is a refund request
  and a parent complaint; if it visibly cannot, paid items become the safe-harbour
  class and that changes what the shop is for.
- Is there a design where the *loss is real and permanent* but the victim always
  has a route back that is themselves robbing somebody? Say so if that is the
  answer, and say plainly if you think it is not.

If, having worked it through, you conclude the rule should stand — say so, and
propose the strongest non-permanent alternative you can build instead. I would
rather be argued out of it with a better design than have you build me the thing
I asked for badly.

---

## What is on the table

**Everything.** Treat this as a clean slate. Rebirth, both upgrade trees, the coin
catalogue, the crate system, the nine house tiers, the 45 skins — all of it can be
retired, repurposed or rebuilt if the progression is better for it. Where you
retire something, say what it was doing and what now does that job.

Two things to know about cost: **code is cheap here** (the entire world is
generated at runtime, systems are data tables, adding a catalogue or a new
mechanic is a day) and **art is expensive** (every mesh is an AI generation
uploaded under the developer's own account, which has already caused one
moderation action — so any design needing forty new models is a design that does
not ship).

---

## What to hand back

**Three genuinely competing directions, then a recommendation.** Not three
variations on one idea — three different answers to "why does a player open this
game on day 40". Make them disagree with each other.

For each direction:

1. **The one-sentence thesis** — what the game is *about*, in the player's words.
2. **The core loop**, minute to minute: what a player does in a 20-minute session
   at day 1, day 7 and day 40, and how those differ.
3. **What the yard and house do**, concretely, in that direction.
4. **What robbing pays** that coins cannot buy, and why a rich player still does
   it.
5. **What is permanently lost by the victim**, exactly, and what protects them.
6. **What the two currencies are for**, and what a player who buys coins actually
   gets — including whether that purchase feels worth making at all once
   randomness is off the coin side.
7. **The retention hook** — the specific reason to come back tomorrow, and the
   reason to come back in six weeks. Name which one is weaker.
8. **What it costs to build** — new systems, new art, new live-ops burden.
9. **The strongest argument against it.** Write this honestly; a direction with no
   stated weakness reads as unexamined.

Then:

- **Pick one**, and say what the other two were better at, so the losing ideas
  are on record rather than forgotten.
- **Sweep every random outcome in your design** against the invariant — for each
  one, name what it costs and prove that price cannot be reached with Robux.
- **Name the numbers that would have to be re-derived**, and the two curves whose
  product needs checking before anything ships. (This project's most repeated
  failure is two tuned numbers multiplied together without anybody checking the
  result — a loss cap against a payout multiplier, an income curve against a cost
  curve, resident supply against server population. Assume your design has one and
  find it.)
- **Give a build order**: what ships first that is worth playing on its own, and
  what each later phase unlocks. I would rather ship one third of a good design
  than all of a mediocre one.

---

## How to work

- **Measure rather than assert.** Where you propose a number, show the arithmetic
  that produced it. Where you cannot, say it is a guess and name what would
  settle it.
- **State costs plainly.** Every design decision here gives something up; say what.
- **Assume the player is nine.** Any mechanic that needs a paragraph of
  explanation is a mechanic that will not be understood. Prefer a thing they can
  SEE — a picture, a posture, an object in the world — over a number they have to
  read.
- Ask me anything you need before you start, but do not stall on it: if a question
  has an obvious sensible answer, make the call, state the assumption, and carry on.
