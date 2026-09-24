# Roaming herds — the PvE supply

Designer spec, 2026-09-21, captured verbatim in intent. This supersedes
`docs/PIGGY-COLLECTION-PLAN.md` §15 where the two differ, and §15's reasoning
is carried forward where it still holds.

**Herds are now load-bearing rather than optional.** With residents coming off
the plots and player coin robbery retiring, this is THE route by which a solo
player — or the first two into a server — acquires anything at all. §15 was
written when a herd paid out a crate and could land whenever; it now carries
the supply floor. Nothing about the NPC pivot should ship before this does.

---

## 1. The shape, as specified

> **SUPERSEDED IN ONE BULLET, 2026-09-23: A PACK IS DROPPED FROM THE SKY AND NO
> LONGER WALKS IN THROUGH THE TUNNEL.** The designer's simulation fiction made
> the street an enclosure and a batch of piggies something RELEASED into it from
> above, so `HerdService` falls a pack onto a landing point that has passed the
> band and ground vetoes and enables each member's prompt on the frame it lands.
> The whole tunnel walk — `route`, the kerb legs, the single-file formation,
> `Config.herdRoute` and the bore-clearance audit — is retired or unreferenced,
> and `HERDS.size` is 1 against a `maxLoose` of 20 rather than five packs of ten.
> `CLAUDE.md` carries the reasoning and the drop-curve measurement. **Everything
> else below still holds**: the roam, the pack-shaped dig, the pick-up-and-carry
> capture, the deferred lasso, and §3's numbers are what the economy audit is
> weighed against.

* Herds **stampede in through the tunnel** — the same geometry the patrol car
  already enters and exits by. *(Retired — see the note above.)*
* They run out into the **grasslands around the players' plots**, and walk
  around **as a pack** for a while.
* **Multiple herds are loose at once.**
* Players **capture one and bring it home.**
* When a herd **exits, a new one enters**, with an **RNG chance over tiers**
  for what spawns.

**For the first build: a piggy is simply picked up and carried home.** No cost,
no minigame. Whether capture should cost coins, or require a LASSO — with
better lassos needed to rope higher tiers — is explicitly deferred, not
rejected. Build the pick-up version, play it, then decide.

---

## 2. What changed from collection plan §15, and what survives

**CHANGED — where they roam.** §15 says herds "roam the street". The spec says
the grasslands around the plots. That is different ground and it matters:
the street is where rides are enabled, where the patrol drives, and where
`Config.isOnStreet` governs. The grassland band behind and between the plots is
none of those. Whoever builds this should check what already governs that
ground before assuming it is free.

**CHANGED — what a catch pays.** §15 paid a CRATE. Packs plan §10 already moved
this: a catch hands over **the piggy you caught**, which is what makes it a
supply route rather than a reward shape.

**SURVIVES — the cadence machinery.** A timed roll, weighted rather than
uniform, with the damped-repeat picker already built for raid/rush-hour, and a
hard cap on how many are loose at once. The spec's "multiple herds at once" and
"when one exits a new one enters" map onto that directly. **Do not write a new
scheduler**; the anti-repeat trap is already recorded — at a small roster,
excluding the last pick makes the picker strictly ALTERNATE and the weights do
nothing.

**SURVIVES, AND IS THE EXPENSIVE PART — catching is a genuinely new verb.**
Every other pickup in this game is a stationary target: a till, a pedestal, a
bin. A herd member moves on its own, and a pack that walks together is flocking
rather than one wanderer. This is the one piece with no existing code to lean
on.

**SURVIVES, AND IT IS THE CHEAPEST DECISION IN THE PLAN — pet-sized.** A herd
piggy is skin-only: no accessory slots, no vault hatch, no dial. Every
scale-dependent measurement this game has shipped — the accessory anchors,
`DIAL_MAX_R`, the vault opening sized against the smallest lock tier — was
solved against one pig radius, and re-deriving all of it at a new scale is a
class of work this project has whole sections of scar tissue about. Keep it
skin-only and that math never reopens.

**SURVIVES — contested the same way everything else on this street is.** First
player to reach a given pig gets it.

---

## 3. What it has to answer that §15 never had to

§15 was a fourth way to earn a crate. This is the floor. So:

1. **THE TIER TABLE BINDS BEFORE THE SPAWN RATE, and this reverses what this
   section first said.** It led with "the spawn rate IS the economy". Measured,
   that is true and it is the *less* sharp of the two:

   * **The lawn caps the product, so none of this is runaway.** Seven
     placements times the top multiplier is 105x base — 314,435/s at L20 — and
     no spawn rate can exceed it. **The spawn rate sets TIME-TO-CEILING, not
     the ceiling**, which is a far more tractable thing to choose: at 2
     catches/hour a full lawn is 210 minutes and all-seven-at-top is 420; at 20
     it is 21 and 42; at 40 it is 10.5 and 21.
   * **There is no diminishing-returns cushion, and one was expected.** The
     guess was that once the lawn is full, catch 8+ can only upgrade the worst
     slot and is therefore worth much less. Measured, filling a hole is +15x
     base and upgrading is +14x — a **seven per cent** reduction, not a
     collapse, because the ladder is 1-to-15 wide so promoting a common to a
     legendary is very nearly as good as filling an empty slot. **Nothing
     brakes catching on its own.**
   * **So the top of the tier table dominates everything.** One top-tier catch
     with 25 minutes of session left is worth **67.4M** as an annuity
     (44,919/s for 1,500s). Sustained PERFECT coin robbery over the same 25
     minutes is 14.4M. **A single legendary catch is worth about 4.7x a whole
     session of flawless robbery.** The spawn rate scales that linearly; the
     tier table's top end multiplies it.

   **Sequence the tier cap in §3.3 BEFORE the spawn rate**, not alongside it.

2. **`auditRobbery` NEEDS A DIFFERENT QUANTITY, NOT A DIFFERENT DIVISOR** —
   and this is the correction most worth reading, because the line it replaces
   described a denominator swap. `robberyRates` returns coins per HOUR for a
   HAUL. **A caught piggy is not a haul; it is a permanent RATE INCREASE**, so
   what it is worth depends on how much session is left to run — the identical
   catch is 13.5M at five minutes remaining and 67.4M at twenty-five. No
   coins-per-hour figure can express that. Whoever re-points this needs an
   annuity over expected session length, or a rate-increase-per-hour — and
   re-pointing the denominator alone would produce a **confident wrong number**,
   which is precisely the failure this audit exists to prevent.

   It still cannot be re-pointed until herds exist, because auditing against a
   target class with no implementation is an invented number.
3. **The RNG tier table must not be a mythic faucet.** The resident rule —
   *richer than the thief is a faucet, full stop* — applies here with more force,
   because a herd MINTS a piggy where a snatch only moves one. An absolute tier
   cap, not an offset, is the shape that already worked for resident lawns.
4. **Minting versus circulation.** Stealing moves a piggy; a herd creates one,
   permanently, and there is no sink. That is survivable — the bound is on how
   many EARN, not how many you own — but it should be understood rather than
   assumed, and it is the reason the spawn rate cannot simply be raised when the
   street feels empty.

---

## 4. Build order inside the lane

The pick-up version has no useful partial below this line:

1. Spawn and despawn through the tunnel mouths, on the existing scheduler shape.
2. Pack movement in the grassland band — the new code.
3. The pick-up verb, granting through Stage 1's existing placement path
   (`Config.addPiggy` / the auto-placement front to back), which already exists
   and is verified.
4. The RNG tier table, with its cap.

Deferred by the spec and listed so nobody builds them early: a coin cost to
capture, and the lasso ladder.
