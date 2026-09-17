# Late-game economy: reaching a 1B house — plan, not code

Status: proposal for decision, September 16. No Config value has changed.
Every number here is regenerable: `python tests/sim/late-game/dump.py`
prints the live curves out of `Config.luau` through the Luau CLI, and
`candidates.py ladders` / `candidates.py arche` produce every table below.
Where this file disagrees with `MASTER-PLAN.md` §14.2 ("no room above the
catalogue, only beside it"), this file is the later instruction.

Three labels are used throughout. **Measured** is read off the live code or
the simulator running the live formulas. **Assumed** is a modelling input
nobody has telemetry for. **Recommended** is a decision this plan proposes.

---

## 1. Audit of the current economy

### 1.1 The formulas (measured, `Config.luau`)

```
income(L, rb)   = 10 · 1.35^(L-1)                       for L ≤ 20
                = 10 · 1.35^19 · 1.16^(L-20)              for 21 ≤ L ≤ 40
                × (1 + 0.12·rb) × (1 + friendBonus)
capacity(L)     = floor(5000 · 1.40^(L-1))                for L ≤ 20
                = floor(5000 · 1.40^19 · 1.19^(L-20))      for 21 ≤ L ≤ 40
incomeCost(L)   = min(400·1.55^(L-1) [1.26 in band B],  0.55 · capacity(L))
capacityCost(L) = min(600·1.60^(L-1) [1.16 in band B],  0.80 · capacity(L))
maxLevel(rb)    = min(40, 20 + 2·rb)
rebirthGate(rb) = capacity(maxLevel(rb)) × 1
```

Costs are indexed by the level being left. Income drips into the pig and
stops at capacity; only a robbery delivery, a daily or an event may overflow
it (`HeistService.deliver`, `EconomyService`). Offline accrual is capped at 8
hours **and** at capacity. Rebirth wipes coins, both ladders and all seven
upgrade trees; keeps everything cosmetic; grants a Legendary Crate.

### 1.2 The ladder today (measured)

| rb | maxL | capacity at max | income at max /s | fill | rebirth gate |
|---:|---:|---:|---:|---:|---:|
| 0 | 20 | 2.99M | 2,995 | 16.6 min | 2.99M |
| 5 | 30 | 17.02M | 21,137 | 13.4 min | 17.02M |
| 10 | 40 | **96.90M** | 128,211 | 12.6 min | 96.90M |
| 11+ | 40 | 96.90M | +12% per rebirth | falling | 96.90M |

The cost clamp binds from capacity L16 and income L20 onward, so every rung
past there costs a fixed **0.80 / 0.55 of the pig**, and time-per-rung is a
constant number of pig-fills. Below that the shipped curve is untouched.

### 1.3 Pacing problems (measured unless marked)

1. **The ceiling is 96.9M and four of the proposed houses are above it.**
   `auditEconomy` refuses them correctly. This is not tunable: the wallet is
   the pig, and nothing can hold 1B in a 96.9M pig.

2. **Once a house is affordable it costs at most one pig-fill, always.** A
   price can never exceed capacity, so time-to-afford from empty is bounded
   by fill time, which is 12–17 minutes at every level. Measured on the
   current catalogue: every house takes **9.6–14.4 minutes of idle income**
   at the level where it first fits (see §4.2). **The price is never what
   paces a purchase; the ladder is.** Any redesign that wants 1B to feel
   earned has to lengthen the climb to the level where 1B fits, not make 1B
   large relative to income.

3. **The whole catalogue is 18 minutes of endgame income.** 142.0M of houses
   against 128K/s at L40/RB10 is 1,108 s. `MASTER-PLAN.md` §14.3 records this
   as arithmetic rather than a content gap, and it is: the largest price the
   audit admits is one pig, and the endgame earns a pig every 12.6 minutes.

4. **Rebirth is flat past RB10.** `maxLevel` caps at 40, so RB11+ unlocks
   nothing and pays +12% each. The simulator shows a continuous idler
   rebirthing every ~3.5 hours forever; the plan's own reasoning is that
   *unlocked levels are the large half of prestige*, and that half is gone.

5. **Endgame robbing is 3.2× idle cold, 6.4× hot, at every level** — a
   flat ratio by construction (`pigSeconds` cancels the rate out). At
   L40/RB10 that is 1.48B/h cold, so a 1B house is **40 minutes of perfect
   robbing today** and the only thing stopping it is the capacity audit.

6. **Offline is worth exactly one pig for anyone away longer than a fill.**
   With fills at 12–17 min and the cap at capacity, an 8-hour absence and a
   20-minute one return the same pig. A casual player therefore gains
   nothing from income levels between sessions; only capacity levels move
   what they come back to. (Observation; not proposed to change here.)

7. **Time to the Sky Castle by archetype (measured, §5 model):** casual 136
   days, regular 22 days, active solo 8 days, active multiplayer 5 days.
   Pure idle at 2 h/day: 20 days, matching the plan's recorded ~17.

---

## 2. Reaching 1B: alternatives compared, one chosen

Constraint carried through every option: `auditEconomy` keeps refusing any
price above `capacity(ABSOLUTE_MAX_LEVEL)`, and the Sky Castle rule holds —
the dearest house stays a **clear fraction** of the largest pig (today 83%),
never equal to it.

| option | what changes | reaches 1B? | cost | verdict |
|---|---|---|---|---|
| **A. Band C: levels 41–60, +2 per rebirth to RB20** | `ABSOLUTE_MAX_LEVEL` 60, a third growth band `CAPACITY_GROWTH_C = 1.136`, `INCOME_GROWTH_C = 1.10`; nothing below L40 moves | cap(60) = **1.241B**, 1B = 80.6% of the top pig | 10 more rebirths, ~2× today's climb; fill drifts 12.6 → 15.5 min | **chosen** |
| A2. As A, rebirth multiplier tapers to 0.08 past RB10 | one more constant | same | fill 12.6 → 17.6 min; regular player +3 days | held as the lever if endgame income reads too fast |
| B. Steepen band B so L40 ≈ 1.25B | `CAPACITY_GROWTH_B` 1.19 → 1.337, `INCOME_GROWTH_B` 1.16 → 1.24 | yes, at RB10 | **fill balloons to 43 min at L40**, gate/income 0.28 → 0.71 h; 1B arrives on today's 17-day schedule; **changes every existing L21–40 save's capacity and income** | rejected — "multiply by ten" wearing a curve |
| C. Rebirth multiplies capacity too | `capacity × (1 + k·rb)` | yes at some k | unlocks no new rungs (the half of prestige the plan says matters); alters existing players' capacity | rejected |
| D. Staged house payments | coins escrowed per house across sessions | yes at today's cap | **a protected savings pot**: coins leave the robbable pig, which is the pivot's one rule; would also need refund and commitment rules | rejected — see §6.4 for the tradeoff stated plainly |
| E. Overflow-only route (rob your way to 1B) | audit exception for houses | already ~40 min hot at RB10 | not a solo route; a route that needs a full server is not a route a quiet hour has | rejected as primary; stays as the fast path it already is |
| F. 3 levels per rebirth to 60 | RB13 reaches 60 | yes | compresses A by a third | rejected; 2 keeps rebuild cycles the length players already know |

**Why A.** It is the only option under which **every existing save's
capacity, income, costs and rebirth gate are byte-identical below RB11** —
`banded()` is unchanged for L ≤ 40 and `maxLevel(rb)` is unchanged for
rb ≤ 10, so there is no value migration at all. It extends the mechanism the
plan already credits ("every rebirth opens two levels that could not be
bought before") rather than inventing a second one. And it is the only
option where the derivation of the two new constants is forced rather than
chosen: `1.136 = (1.25e9 / 96.9e6)^(1/20)` puts the top pig at ~1.25B so 1B
sits at 80%; `1.10` is what holds the fill time in the 12–16 minute band
against a rebirth multiplier that keeps climbing to 3.4×.

**What A does not do, stated plainly.** It does not make the 1B *price*
meaningful in the sense of "a long save". At RB20/L59, when 1B first fits,
it is 13.8 minutes of idle income — exactly as every house before it. What
it makes meaningful is **reaching RB20/L59**: for a regular player that is
week eight, and the last four houses land at roughly ten-day intervals.

---

## 3. Balancing the four numbers together (recommended)

| constant | today | proposed | why this and not another |
|---|---:|---:|---|
| `ABSOLUTE_MAX_LEVEL` | 40 | **60** | 20 rungs × 1.136 is the smallest growth that clears 1B with Sky-Castle headroom |
| `BAND_TOP_2` (new) | — | **40** | band C starts exactly where band B ends; `banded()` grows a third clause, no seam |
| `CAPACITY_GROWTH_C` (new) | — | **1.136** | derived: `(1.25e9/96,904,045)^(1/20)`; top pig 1.241B |
| `INCOME_GROWTH_C` (new) | — | **1.10** | fill time at max level 12.6 → 15.5 min across RB10–20; the 1.033/level gap between capacity and income is what stops the top accelerating |
| `INCOME_COST_GROWTH_C` / `CAPACITY_COST_GROWTH_C` | — | **1.26 / 1.16** (band B's) | the clamp binds on every band-C rung (cost/pig reads 0.80 and 0.55 at L40–60, measured), so the curve only has to keep outrunning the pig — which 1.16 > 1.136 and 1.26 > 1.136 guarantee |
| `LEVELS_PER_REBIRTH` | 2 | 2 | RB20 lands on 60; keeps each rebuild the length players already know |
| `REBIRTH_MULTIPLIER` | 0.12 | 0.12 (A) — or 0.08 past RB10 (A2) | decision 3 |
| `REBIRTH_CAPACITY_MULTIPLE` | 1 | 1 | gate stays "fill your pig"; gate/income holds at 0.21–0.26 h across RB0–20 (measured) |
| `UPGRADE_COST_CEILING` | 0.55 / 0.80 | unchanged | the no-deadlock guarantee; verified binding through L60 |
| `LOSS_CAP`, `HEIST_PAYOUT`, `REVENGE`, `RESIDENTS.pigSeconds`, `SHOP_VAULT_DISCOUNT` | — | **unchanged** | all fractional or in seconds-of-income; §6 shows the relative stakes are identical by construction |
| `auditEconomy` gate sweep | `for rebirths = 0, 12` (hard-coded) | derived: `0 .. (ABSOLUTE_MAX_LEVEL − BAND_TOP)/LEVELS_PER_REBIRTH + 2` | a pinned 12 would stop auditing exactly the gates this adds |

Nothing here is "×10". The early game (L1–20) is untouched; the mid game
(L21–40) is untouched; the extension is a third band gentler than the second,
and the only reason it reaches 1B is that it is twenty rungs long.

---

## 4. Progression tables (measured on the proposed constants)

### 4.1 Per rebirth, at the reachable ceiling

| rb | maxL | capacity | income /s (at rb) | fill | gate | gate ÷ income | rebuild after rebirth: regular 1 h/day · active 2 h/day |
|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 20 | 2.99M | 2,995 | 16.6 m | 2.99M | 0.28 h | first rebirth at ~2.3 h play (unchanged) |
| 5 | 30 | 17.02M | 21,137 | 13.4 m | 17.02M | 0.22 h | 2 days · 1 day |
| 10 | 40 | 96.90M | 128,211 | 12.6 m | 96.90M | 0.21 h | 3 days · 1 day |
| 11 | 42 | 125.05M | 163,597 | 12.7 m | 125.05M | 0.21 h | 2 days · 1 day |
| 12 | 44 | 161.38M | 208,191 | 12.9 m | 161.38M | 0.22 h | 3 days · 1 day |
| 13 | 46 | 208.26M | 264,300 | 13.1 m | 208.26M | 0.22 h | 3 days · 1 day |
| 14 | 48 | 268.76M | 334,794 | 13.4 m | 268.76M | 0.22 h | 3 days · 1 day |
| 15 | 50 | 346.84M | 423,240 | 13.7 m | 346.84M | 0.23 h | 3 days · 1 day |
| 16 | 52 | 447.59M | 534,068 | 14.0 m | 447.59M | 0.23 h | 3 days · 2 days |
| 17 | 54 | 577.62M | 672,779 | 14.3 m | 577.62M | 0.24 h | 3 days · 1 day |
| 18 | 56 | 745.41M | 846,197 | 14.7 m | 745.41M | 0.24 h | 4 days · 1 day |
| 19 | 58 | 961.95M | 1,062,780 | 15.1 m | 961.95M | 0.25 h | 4 days · 1 day |
| 20 | 60 | **1,241.39M** | 1,333,012 | 15.5 m | 1,241.39M | 0.26 h | 3 days · 2 days |

"Rebuild" is wall-clock between consecutive rebirths from the archetype
simulation (§5); at 1 h/day it is 2–4 hours of play per cycle throughout.

### 4.2 Band C rung by rung (income shown at RB20)

| L | capacity | income /s | income cost | capacity cost | cost ÷ pig |
|---:|---:|---:|---:|---:|---:|
| 40 | 96.90M | 198,144 | 53.30M | 77.52M | 0.55 / 0.80 |
| 44 | 161.38M | 290,102 | 88.76M | 129.11M | clamped |
| 48 | 268.76M | 424,739 | 147.82M | 215.01M | clamped |
| 52 | 447.59M | 621,860 | 246.18M | 358.07M | clamped |
| 56 | 745.41M | 910,465 | 409.98M | 596.33M | clamped |
| 60 | 1,241.39M | 1,333,012 | 682.76M | 993.11M | clamped |

Every band-C rung costs a constant 0.80 (capacity) or 0.55 (income) of the
pig, so a level pair is ~1.35 pig-fills ≈ 18–21 minutes of idling.

### 4.3 The eighteen houses: where each first fits, and what it costs in time

| price | first (rb, L) with capacity ≥ price | capacity there | idle: time to afford from empty | regular pace (f = 0.25 robbing) | perfect hot robbing |
|---:|---|---:|---:|---:|---:|
| 35K | rb0 L7 | 37.6K | 9.6 min | 5.3 min | 1.3 min |
| 120K | rb0 L11 | 144.6K | 9.9 | 5.5 | 1.3 |
| 250K | rb0 L13 | 283.5K | 11.4 | 6.3 | 1.5 |
| 400K | rb0 L15 | 555.6K | 10.0 | 5.5 | 1.3 |
| 750K | rb0 L16 | 777.8K | 13.9 | 7.7 | 1.9 |
| 1.4M | rb0 L18 | 1.52M | 14.2 | 7.9 | 1.9 |
| 2.5M | rb0 L20 | 2.99M | 13.9 | 7.7 | 1.9 |
| 5M | rb2 L23 | 5.04M | 14.4 | 8.0 | 1.9 |
| 8M | rb3 L26 | 8.49M | 13.4 | 7.5 | 1.8 |
| 15M | rb5 L30 | 17.02M | 11.8 | 6.6 | 1.6 |
| 25M | rb7 L33 | 28.68M | 11.0 | 6.1 | 1.5 |
| 40M | rb8 L35 | 40.61M | 12.3 | 6.8 | 1.7 |
| 80M | rb10 L39 | 81.43M | 12.1 | 6.7 | 1.6 |
| 150M | rb12 L44 | 161.38M | 12.0 | 6.7 | 1.6 |
| 300M | rb15 L49 | 305.31M | 13.0 | 7.2 | 1.8 |
| 600M | rb18 L55 | 656.17M | 13.0 | 7.2 | 1.8 |
| **1B** | **rb20 L59** | 1,092.77M | 13.8 | 7.6 | 1.9 |

The rightmost three columns are the whole of §1.3 point 2 in one table: the
time to pay for a house is flat across three orders of magnitude of price.
The ladder is the pacing. Price spacing (1.5–2.7×) sets how many *rungs*
sit between houses, which is why the four new Legendary houses land three
rebirths apart rather than five.

---

## 5. Player models

### 5.1 Assumptions (all unmeasured — telemetry does not exist yet)

| archetype | sessions | robbing share `f` of the perfect-play ceiling | notes |
|---|---|---|---|
| Casual solo | 4 × 20 min per week | 0.10 | the plan's "casual child"; mostly idles and collects |
| Regular solo | 1 h every day | 0.25 | the plan's own "realistic pace is a quarter of the ceiling" |
| Active solo | 2 h every day | 0.50 | the plan's "keen player at two hours a day" |
| Active multiplayer | 2 h every day | 0.50 cold, and **1.0 at a maxed spree for half the session** | an upper bound: perfect hot robbing half the time |
| Pure idle | 2 h every day | 0 | reproduces the plan's recorded pacing as a control |

Common assumptions: offline accrual runs between sessions (capped 8 h and at
capacity, as the code does); no dailies, no friend bonus, no events, no
skin steals; robbing targets are residents and shop vaults whose pigs scale
with the thief's income (as `ResidentService` seeds them); PvP is not the
primary income at any population (`MASTER-PLAN.md` §2 measured the whole
server's theft budget as "half a pig each per hour"), so it is modelled as a
loss risk in §6 rather than as thief income here. Purchase policy is stated
at the top of `tests/sim/late-game/sim.py`.

### 5.2 Results: day the house is first bought (wall-clock days from a fresh save)

| archetype | curve | 5M | 15M | 40M | 80M | 150M | 300M | 600M | **1B** | RB10 | RB20 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Casual solo | today | 25.7 | 60.7 | 102.7 | 135.7 | — | — | — | — | 118.7 | — |
| Casual solo | **A** | 27.7 | 63.7 | 105.7 | 139.7 | 174.7 | 233.7 | 301.7 | **352.7** | 121.7 | 326.7 |
| Regular solo | today | 4.7 | 9.7 | 16.7 | 21.7 | — | — | — | — | 18.7 | — |
| Regular solo | **A** | 4.7 | 10.7 | 16.7 | 21.7 | 27.7 | 36.7 | 46.7 | **54.7** | 19.7 | 50.7 |
| Regular solo | A2 | 4.7 | 10.7 | 16.7 | 21.7 | 27.7 | 37.7 | 48.7 | 57.7 | 19.7 | 53.7 |
| Active solo | today | 1.8 | 3.8 | 5.8 | 7.8 | — | — | — | — | 6.8 | — |
| Active solo | **A** | 1.8 | 3.8 | 6.7 | 7.8 | 9.8 | 13.7 | 16.8 | **19.8** | 6.8 | 18.7 |
| Active multiplayer | today | 0.8 | 1.8 | 3.7 | 4.7 | — | — | — | — | 3.8 | — |
| Active multiplayer | **A** | 0.8 | 1.8 | 3.7 | 4.7 | 5.7 | 6.8 | 8.7 | **10.7** | 3.8 | 9.8 |
| Pure idle 2 h/day | today | 3.8 | 8.8 | 14.8 | 19.7 | — | — | — | — | 17.7 | — |
| Pure idle 2 h/day | **A** | 1.7* | 9.7 | 15.7 | 19.8 | 24.8 | 32.8 | 42.7 | **49.8** | 17.7 | 45.8 |

\* the proposed 5M sits in a different ladder position (house 8 of 18); read
columns by price, not position.

Reading it: **Option A changes nothing anybody experiences before day 20** —
every archetype's first 80M lands on the same day it does today. It then
roughly doubles the journey: a regular player owns the 1B house in **week
eight**, an active solo player in **week three**, and a perfect-robbing
multiplayer player in **eleven days**. A casual player owns the Sky Castle in
month five and the 1B house in month twelve — which is honest, and is what
the plan's own casual archetype predicts for any endgame at all.

The late houses are spaced 8–10 days apart for the regular player and 2–4
days for the active one, which is the "goal always in view" cadence the
house ladder is meant to produce.

---

## 6. Robbery, losses, revenge, residents, shops, overflow

### 6.1 The stakes scale together, and the *relative* stakes are unchanged (measured)

| | RB10 / L40 (today's top) | RB20 / L60 (proposed top) |
|---|---:|---:|
| pig | 96.9M | 1,241M |
| income | 128,211 /s | 1,333,012 /s |
| fill | 12.6 min | 15.5 min |
| `LOSS_CAP` 45%/h, worst case | 43.6M = **5.7 min of income** | 559M = **7.0 min of income** |
| one bare crack (21.9%) | 21.2M — thief banks 42M, revenge 64M | 272M — thief banks 544M, revenge 816M |
| one maxed-sack crack (41.6%) | 40.3M | 516M |
| resident pig (200 s of the thief's income) | 25.6M | 267M |
| shop vault (111 s) | 14.3M | 148M |
| idle / cold robbing / hot robbing per hour | 462M / 1.48B / 2.96B | 4.8B / 15.4B / 30.8B |
| a 1B house in cold robbing at this level | 40.5 min | 3.9 min |

Every loss and every haul is a fraction of the pig or a number of seconds of
income, so the worst hour a victim can have is **seven minutes of their own
income** at the top, against six today. Nothing about being robbed gets more
punishing in the only unit a player feels. Recommended: **no change to
`LOSS_CAP`, `HEIST_PAYOUT`, `REVENGE`, `STEAL_COOLDOWN`, `RESIDENTS.pigSeconds`
or `SHOP_VAULT_DISCOUNT`.**

### 6.2 No new farming loop (measured)

`robberyRates` is a flat ratio because a resident's pig is `pigSeconds ×
the thief's income` and both sides of the quotient carry `getIncomeRate`.
Band C lives inside `getIncomeRate`, so the 3.21× cold / 6.42× hot ratio and
the 0.0000% spread hold at L41–60 by construction. `auditRobbery` must
simply sweep to the new ceiling (it reads `ABSOLUTE_MAX_LEVEL`; verify its
rebirth loop is derived too, see §3 last row). The lap-versus-cooldown check
is geometry and does not move.

The one existing dynamic that band C **widens**: residents are seated at the
*average* income level of the humans present. An RB20/L60 player and a fresh
L5 player on one server average to a level-32 street, whose residents hold
~3.5M pigs against the newcomer's 19K capacity — one clean crack overflows
the newcomer to 180× their capacity. `CLAUDE.md` already records that
"pinning to the best player hands a beginner a target they cannot fail to
profit from" as the reason for average-over-max; the average now spans
twelve times the range it did. **Not changed here; listed as a playtest
metric (§9) and the first candidate for a follow-up** (seat residents by
median, or clamp the street to the *lowest* human + a spread).

### 6.3 Overflow

Delivery may overflow capacity (`HeistService.deliver`: "income stops above
the cap anyway, so an overfull pig is self-limiting"). At the top a revenge
hit on a maxed-sack crack banks 1.55B into a 1.24B pig. That is fine and
wanted — it is the juiciest target on the street — and no absolute cap is
recommended. Two housekeeping notes: `Config.formatCoins` already carries
`B` and `T` suffixes; `CosmeticsService.buyHouse`'s refusal prints a raw
`%d`, which should read through `formatCoins` before any price reaches ten
digits.

### 6.4 The protected-savings tradeoff, stated plainly

Option D (staged payments) would let a 1B house be bought at today's
capacity by parking coins outside the pig. The tradeoff: every coin in
escrow is a coin a thief cannot take, so a rational player would drip
everything into escrow and the street's robbable supply would fall by
whatever share of income is being saved — at 1B against a 96.9M pig that is
most of it. That is "banked coins are permanently safe" re-entering by the
back door, which the pivot removed because it was "the single reason nobody
robbed anybody." It also needs a refund rule, a commitment rule and an
answer to "is escrow stealable," each of which is a new system. **Rejected
with the tradeoff on the table**, as the brief asked.

---

## 7. Houses: sequential ladder or individual ownership? (recommended: individual)

Today the ladder is sequential only because ownership is a numeric
`houseLevel`. Once houses carry stable IDs (§8) the sequence is a rule
somebody has to keep, and the simulation says it buys nothing: **the
sequential and free-choice runs reach 1B on the same day**, because every
house costs one pig-fill once it fits and the ladder — not the catalogue's
2.23B total — is what paces the climb.

Recommended model:

* **Any house may be bought when its price fits the pig.** The capacity
  audit and the bounded wallet are the only gates — "buy the Coastal Villa
  first" is not a sentence the trophy-room design needs.
* **Every owned house stays owned; moving between owned houses is free**,
  exactly as `houseShown` works today.
* **New lower-priced houses are optional purchases for existing owners**,
  never prerequisites — the catalogue plan already states this.
* **Owning all eighteen becomes a trophy-room achievement** rather than a
  side effect of the ladder, which is where "collect them all" belongs.

Cost of the choice: a skip-buyer spends less total coin on houses. The sink
was already bounded (§1.3 point 3), and the interiors plan gives every house
a reason to be lived in, so this is the honest trade.

---

## 8. Migration (schema 26) — preserves balances, upgrades, rebirths, every house, the shown house

### 8.1 What does not migrate at all

`coins`, `incomeLevel`, `capacityLevel`, `rebirths`, `upgrades`: **untouched.**
Under Option A their values mean exactly what they meant — `capacity(L)`
for L ≤ 40 and `maxLevel(rb)` for rb ≤ 10 are unchanged functions. Test:
`for L in 1..40, rb in 0..10: new == old` for capacity, income, both costs
and the gate. One edge: a save already at rb ≥ 11 sees `maxLevel` rise
(new rungs to buy) and its gate rise with it from cap(40) to cap(maxLevel);
that is the feature, and a player mid-save toward the old gate needs a
one-line notice rather than a migration.

### 8.2 Houses: numeric levels → stable IDs

```
Config.HOUSE_TIERS[i].id      -- "shack","cottage","townhouse","villa","manor",
                              -- "modern","neontower","palace","skycastle", + new ids
Config.HOUSE_LEGACY_ORDER     -- { "shack", ..., "skycastle" }: the nine legacy ids
                              -- in OLD numeric order, frozen forever
data.houses = { owned = { [id] = true }, shown = id }
```

Reconcile (runs before the generic fill, like the schema-9 rule it
replaces):

1. if `data.houses == nil` and `type(data.houseLevel) == "number"`:
   `owned = { HOUSE_LEGACY_ORDER[0..houseLevel] }`,
   `shown = HOUSE_LEGACY_ORDER[Config.getShownHouseLevel(data)]` (which keeps
   today's clamp and the schema-9 "missing means newest" rule);
2. delete `houseLevel` / `houseShown` from the save (two meanings never share
   one field; the legacy read lives only in reconcile);
3. idempotent: a save carrying `houses` is untouched; a second run adds no
   house. **Never grants**: `owned` derives only from the old level.
4. a shown id not in `owned`, or unknown to the catalogue, falls back to the
   dearest owned house (the clamp today), never to the shack.

Test matrix: every `houseLevel` 0..8 × every `houseShown` 0..level, plus
`houseShown = nil`, plus `houseShown > houseLevel`, plus a pre-schema-9
save; assert exact `owned` sets and `shown`; run reconcile twice.

### 8.3 Readers to convert (measured by grep)

| file | sites | what changes |
|---|---:|---|
| `CosmeticsService` | 10 | `buyHouse` takes an **id**; `houses` payload keyed by id with `owned`/`current`/`price`; `applyToPlot` reads `shown` |
| `DataService` | 9 | type, defaults, reconcile above |
| `Config` | 8 | `getHouseTier(id)`, `getShownHouse(data)`, retire `getHouseUpgradeCost`/`MAX_HOUSE_LEVEL` |
| `AdminService` | 7 | `house` command takes an id; `unlockall` fills `owned`; `reset` empties it |
| `PlotService` | 1 | sign reads the shown tier's name |
| `ClientMain` (2 render sites) + `Rebirth` | — | house cards keyed by id; "current == true" lookup instead of position index |
| `Remotes.HouseRequest` | — | carries an id string; server validates against the catalogue |
| `tests/luau/growth.luau` | 1 | fixture gains `houses` |

---

## 9. Implementation phases, tests, playtest metrics

**Phase L1 — the ladder** (`Config` only; no UI work — the Lv N/M bar is
already drawn from the pushed ceiling). Add `BAND_TOP_2`, the three band-C
constants, extend `banded()`, set `ABSOLUTE_MAX_LEVEL = 60`, derive the two
audit sweep bounds. *Tests:* identity for L ≤ 40 / rb ≤ 10; `capacity(60) ≥
1.2e9`; fill time at `maxLevel(rb)` within 10–18 min for rb 0..20; clamp
binds on every band-C rung; `auditEconomy`, `auditRobbery` (spread still
0.0000, floor ≥ 3.0, ceiling ≤ 10.0, lap > cooldown) and `auditSkinSteal`
clean; a provoked `ABSOLUTE_MAX_LEVEL = 40` with a 1B house makes
`auditEconomy` fire. *Done when* the Luau suites pass and a boot in Studio
prints no new warning.

**Phase L2 — house IDs and schema 26** — **implemented September 16** (`tests/luau/houses.luau`; the dev save came back showing the Sky Castle). With the nine existing houses only.
The migration in §8, every reader in §8.3, `HouseRequest` by id. *Tests:*
the matrix in §8.2; admin `house`/`unlockall`/`reset`; sign text; payload
shape; a rebirth leaves `houses` intact. *Done when* a schema-25 dev save
with a Sky Castle shown over a Marble Palace comes back owning nine and
showing the castle, twice.

**Phase L3 — individual purchase UI.** Every house is a card with owned /
affordable / too-dear state and a MOVE IN toggle; no "buy the next one"
copy. *Tests:* the client suite renders 18 cards from an 18-entry payload
without the 200-local ceiling moving (module, one statement).

**Phase L4 — the catalogue, in price order as art lands.** The four
new Rare/Epic houses and the 25M Chateau fit today's pig and may land before
L1. The 150M–1B four land after L1; each is one row and the audit admits it
automatically. Names, rarities and models per `HOUSE-CATALOGUE-PLAN.md`.

**Phase L5 — trophy rooms**, per `HOUSE-TROPHY-ROOMS.md`; out of scope here
except that §7 assumes every house has one.

**Simulation as a test.** Commit `tests/sim/late-game/` (dump, econ, sim,
candidates) and add `tests/luau/ladder.luau` asserting the L1 invariants
against the real `Config` through `run-crates.py`. The Python model is
cross-checked against the Luau dump at every level and gate before any
number in it is quoted.

**Playtest metrics (the first numbers telemetry has to produce):**

1. wall-clock to first rebirth (must stay ~2.3 h of play);
2. wall-clock RB10 → RB20 per archetype against §5.2 (regular ~35 days);
3. house purchase distribution — skip rate of mid houses under §7;
4. sessions ending with the pig FULL (spend pressure is working) vs
   sessions where a player sat at a rebirth gate > 3 sessions (a wall);
5. coins lost per victim per hour **in minutes of own income**, target ≤ 7;
6. observed robbing ÷ idling for players who rob, against the 3.2× ceiling;
7. **newcomer overflow events** — first-session deliveries exceeding 5× the
   player's own capacity, the §6.2 risk.

---

## 10. Recommended model in one paragraph, and the decisions needed

**Extend the ladder with a third band — levels 41–60, two per rebirth to
RB20, capacity growth 1.136 and income growth 1.10 — leaving every value
below L40 and every save below RB11 byte-identical.** The top pig becomes
1.241B, the 1B house sits at 80% of it, fill time drifts 12.6 → 15.5 min,
and the robbery stakes stay a flat fraction of the pig so a victim's worst
hour is seven minutes of income. A regular player reaches the 1B house in
week eight, an active one in week three. Houses become individually owned
by stable id, all existing ownership and the shown house preserved by a
derive-only reconcile, and the sequence rule is dropped because it paces
nothing.

**Decisions needed before implementation:**

1. **Sequential or individual houses** — recommended individual (§7). This
   decides whether L3 is a toggle per card or a "next house" button.
2. **Target pace** — accept "regular player: 1B in ~8 weeks, active in ~3"?
   The levers are `CAPACITY_GROWTH_C`/`INCOME_GROWTH_C` (steeper = fewer
   rungs per house, faster) or `LEVELS_PER_REBIRTH`; both re-solve in the
   simulator in seconds.
3. **Rebirth multiplier past RB10** — keep 0.12 (A, fill 15.5 min at top) or
   taper to 0.08 (A2, 17.6 min, +3 days for the regular player). Recommended
   A; A2 is the lever if endgame income reads too fast in play.
4. **Legacy fields** — delete `houseLevel`/`houseShown` at schema 26
   (recommended) or mirror them for one version.
5. **Rebirths past RB20** — today rebirth is unbounded (+12% each, nothing
   unlocked after the ceiling); keep that, or cap at 20 and say so on the
   page?
6. **Ship the five houses that fit today's pig before the ladder change?**
   They need no economy work at all.

---

## 11. After the eighteenth house: the loop that does not end, and a Legacy reset

**Decisions recorded September 16:** houses are individually owned by stable
id; `houseLevel`/`houseShown` are deleted at schema 26; the pace in §5 is
accepted; the rebirth multiplier is **Option A2** (0.12 per rebirth through
RB10 as today, 0.08 per rebirth beyond).

### 11.1 The house catalogue is the mid-game shelf, and the plan already says so

`MASTER-PLAN.md` §14.3: *coins are the mid-game currency; the endgame is
acorns, rank and seasons.* Finishing the catalogue is therefore not the
tycoon wall it looks like, **provided the two things already approved land**:

* **Trophy rooms** (`HOUSE-TROPHY-ROOMS.md`). A house with an inside full of
  achievements is a shelf that never finishes — victims, total stolen,
  thieves caught, season ranks, event medals all keep counting for as long
  as anybody robs anybody. Once the rooms exist, "own all eighteen" becomes
  "which room shows the season-three plaque," not "done."
* **Seasons** (Phase 5). Rank resets on a clock and the boards refill; the
  house is where the record of each season is kept.

Nothing new is needed for the loop itself. The order matters: rooms and
seasons **before** anything in 11.3.

### 11.2 The Legacy reset (optional later phase, recommended shape)

A voluntary "play it through again," built as the rebirth's older sibling
rather than as a wipe:

| | Legacy reset |
|---|---|
| available | only at RB20 with every house owned; never required, never nagged |
| **wipes** | coins, both ladders, all seven upgrade trees, rebirths → 0, **every house except the shack** |
| **keeps** | trophies and achievement counters, skins, rides, gear, garden, ornaments, Acorns, season rank, spares — everything that records what the player *did* rather than what they *bought* |
| adds | `data.legacy += 1`; a Legacy star on the plot sign and a "Legacy I / II / …" plaque in every trophy room |
| explains | the rebirth's own before-the-button page, first time only, listing exactly what goes |

Why not "delete everything": `CLAUDE.md`'s hardest rule is that losing
permanent progress is, for this audience, a crying-then-uninstall event, and
that the collection is *the reason to press the button* — which is why
rebirth keeps cosmetics. A reset that deleted the trophy rooms would delete
the record the rooms exist to keep. The player who wants the whole eight
weeks again gets it, with a boast for having done it; the player who does
not loses nothing by not pressing.

Implementation is small: `ProgressionService.rebirth` already performs most
of the wipe; Legacy is that path with `rebirths = 0`, `houses.owned`
reduced to the shack, `houses.shown = "shack"`, and a counter. **Open
decision:** whether skins and rides survive — recommended yes, for the
rebirth argument above.

### 11.3 Other ways to keep the shelf alive, ranked

1. **Earned seasonal houses** — one exterior per season, earned by rank,
   never priced. Clears the class line (trophy class: earned, unstealable),
   and is the "sideways, never upward" shape §14.2 asks for.
2. **Interior styles and customisation** — the ~90M interiors shelf already
   sized in §14.2. Makes owning eighteen houses *more* to do, not less.
3. **Cosmetic prestige past RB20** — a sign, a border. Garnish; the plan's
   own finding is that flat rebirths past the ceiling are a tax.
4. **A fourth band later** — the arithmetic in this plan re-runs, but each
   use shortens the mid-game relatively; a lever, not a plan.
5. **Not this:** converting overflow coins to Acorns. It is the arrow §14.1
   refuses, and the brief preserves the separation.
