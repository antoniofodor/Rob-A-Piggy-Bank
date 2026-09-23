# Piggy collection — build order

Sequencing only. Every reason behind an item below lives in
`docs/PIGGY-COLLECTION-PLAN.md` — this file exists so "what do we build and in
what order" has one answer instead of being scattered across a chat history.
The door/interior/pursuit mechanism (Stage 4) was worked out in conversation
and is summarised here, but it still wants folding into the plan doc proper
as its own numbered section before this gets much longer — right now the
plan's own §6 still describes the older, connected-Blender-room approach.

---

## Before anything starts

Four open questions gate different stages below. None of them block Stage 1 —
start there regardless of how these land.

1. ~~**Skin-rarity tiers.**~~ **Resolved 2026-09-21 — FIVE tiers, and the
   tier is a production class rather than a label.** Common is a look, rare
   is a described variant, epic is a variant with an EFFECT, legendary adds
   GEOMETRY and effects, and MYTHIC is a whole-model creature — the four
   already built move straight into it. Glitched goes on the same ladder
   later. The whole content track that falls out of it — the re-tag, the cut
   list, the nameplate, the pack schedule to ~80 — is
   `docs/PIGGY-PACKS-PLAN.md`, and Stage 8 below is where it lands.
2. ~~**Interior geometry.**~~ **Resolved 2026-09-20.** Code-generated generic
   rooms for the MVP — no Blender work to get Stage 4 playable. Per-house
   Blender-authored rooms that actually match each house's outside theme
   stay on the table as a later pass, once the MVP loop has proven itself;
   nothing about building the generic version forecloses that.
3. **Rebirth-gate "etc." list.** Plan §11. Gates the scope of Stage 5.
4. **Robux crate direction.** Plan §14 — a direct Robux-to-crate purchase
   (needs the disclosed-odds/`PolicyService` build) or a named-pet direct
   purchase (already this game's pattern, e.g. the Style Pack). Gates Stage 6
   only; nothing else waits on it.

---

## Stage 1 — the core loop

Ownership and duplicate stacking, till/lawn placement, the per-piggy income
buffer and collect prompt, the pedestal snatch, `LOSS_CAP`'s new piggy
clause, and the economy re-derivation against `auditRobbery` and the other
income-denominated audits. Plan §1–5, §8 — this is the plan's own Phase 1+2
vertical slice.

**Nothing past this point is worth starting until this has actually been
played and feels right.** That is the plan's own rule, not a new one.

### Where it stands, 2026-09-21

**BUILT AND VERIFIED LIVE, end to end, on a real plot with real saves.**
Offline: `tests/luau/piggies.luau` (77 checks), `luau-compile` over every
touched file, and `saves`/`audits`/`crates`/`theft`/`ranks`/`residents` still
passing. Live, in a Play session:

* Clean boot, no errors, `auditPiggySlots` silent. 60 pedestals across 10
  residential plots and **0 on the four shops**, all 60 carrying a prompt.
* Every pedestal lands on its authored offset to **0.0000024 studs, on both
  rows** — the far row's half turn comes out identical in plot-local space,
  which is the check that matters and the one a world-space probe gets wrong.
* The rarity ladder is exact at the cap: **3.3K / 13.2K / 49.4K** for
  common / rare / legendary, which is 1 : 4 : 15.
* **The whole lawn comes ripe together**, measured: all three tiers plateaued
  inside the same 5-second window, because the cap is proportional to the
  rate. That is the property that makes one lap of the plot the right action
  rather than six errands on six clocks, and it was a claim in a comment
  until this measured it.
* Placement persists across a full server restart; a rejoin restored all six
  keys and all six buffers at exactly the values they had plateaued at.
* All four collect outcomes driven through the real prompt, with the real
  wording: a **clean** collect (3.3K drained whole, +3,294 in the pig, and
  **silent**, which is what a collect that fits should be), a **clamped** one
  (*"Your piggy bank only had room for 7.9K. The rest is still waiting."* —
  and the rest genuinely stayed in the buffer), the **full refusal** (*"Your
  piggy bank is full. Spend some coins before you collect."*, word for word
  the sell refusal as §4a requires), and the **out-of-range** refusal, which
  is what a press from 19 studs correctly did nothing at.
* The till (slot 0) collects on the same path as the six.
* A resident's plot refuses both its pedestal and its till prompts on the
  client (`enabled=false, owner=0`) while the owner's seven are all live with
  figures.

**Three real bugs the live pass found, none of which any offline test could
have.** All three are fixed, and all three are the same family this project
keeps records on:

1. **The till published no figure at all.** `setPiggyBuffers` walked the
   pedestal ARRAY, which is complete-looking and covers six of seven — the
   till's buffer is a top-level number. Its card had the verb and no amount.
2. **Figures were published only when a buffer MOVED.** Right as an
   optimisation, fatal on its own: a rejoin onto a lawn saved AT ITS CAP
   showed six cards with no numbers, permanently, because nothing ever moved
   again. This is `updatePile` guarded by `coins < capacity` exactly — the
   bug that had residents advertising 2,962 while holding 44,130. A repaint
   republishes now.
3. **`Enabled` replicated before the owner did, and the refusal is
   one-way.** `PromptUI.ownerRule` may only ever turn a prompt OFF, so a
   client that refuses a prompt never takes it back. A plot is built at server
   startup with no owner, so every client disabled all seven locally, and the
   later owner write could not re-enable them. Measured: server `Enabled=true`
   on all seven, client `false` on all seven, owner correct on both sides, and
   `PromptShown` never firing 2.5 studs away. Fixed by writing the owner
   first and enabling second — the order is now load-bearing and commented as
   such at both ends.

**AND IT HAS NOW BEEN LOOKED AT. The object is right and the SIGHTLINE is
not.** Photographed on a live plot at three framings:

* Close up, the two-course plinth reads as built rather than as a cube on
  grass, the piggies sit flush with their feet planted — so the
  `PiggyModel.MINI_CENTRE_Y` seating is correct, no float and no sink — and
  the 1.55x scale is chunky and readable against the till. Six of them around
  the pig reads as a collection. Nothing to change about the object.
* **From the pavement they are all but gone, and the measurements say why.**
  Lawn 0.50, plinth top 1.75, display top **5.20**; a Picket barrier tops out
  at 4.30 and the three CLIMBED tiers at **7.50**. So behind a Picket you see
  the top 0.9 studs — about a quarter of a piggy — and behind Barbed,
  Electric or Moat the whole display sits 2.3 studs BELOW the barrier and not
  one pedestal is visible. Photographed at Electric: fence posts, the oak,
  the basket, the till's glow, and nothing else. The oak at (-25, 16) is a
  second occluder nobody had counted, standing in front of the entire
  x = -25 column from the street.
* **RAISING THE PLINTHS IS THE WRONG FIX AND THE NUMBERS REFUSE IT.** To
  clear 7.50 the plinth would have to go from 1.75 to about 4.55, putting the
  pedestal at 8.0 studs — which is exactly the height `CLAUDE.md` records as
  where things start hiding the plot piggy itself ("at 8.0 it is 28%"). The
  collection would become an occluder of the one readout every thief prices a
  job on.
* **The real cost is an INCENTIVE, not a picture.** A thief cannot case a
  well-defended lawn, so they cannot know it is worth entering — which points
  them at undefended plots, i.e. the poor ones, and inverts risk/reward. This
  project has already solved this exact shape once: the pig's own fill stopped
  reading from the street at high fence tiers and the answer was not taller
  geometry, it was **the rob badge publishing the figure**. The same answer
  fits here — something on the badge saying what a lawn is carrying, with the
  fence still hiding WHICH pieces.

**WHAT IS STILL UNSEEN IS THE PROMPT CARDS.** `PromptShown` never fired in
any of these runs — the character navigated into range before the listener was
connected, which is the harness artefact this project already records ("a test
harness that teleports onto one is testing a prompt that was never shown"),
not evidence the card is missing. The triggers all landed, so the prompts are
live; the cards have not been read. Note they cannot be photographed directly
either: an `AlwaysOnTop` billboard is invisible to `screen_capture`, so it
needs the throwaway-clone trick.

Done:

* The passive drip is retired. Nothing fills `data.coins` on its own clock.
* Seven placements, each with its own buffer capped at
  `rate × Config.PIGGY_BUFFER_SECONDS`: the till (slot 0, `data.tillBuffer`)
  and six lawn pedestals (`data.piggies.slots`).
* `Config.PIGGY_LAWN_SLOTS` — six coordinates, ordered front to back, audited
  at boot by `Config.auditPiggySlots` against the till, the gate walk, the
  kennel, the oak, the basket and the doorstep crate. Every rule provoked in
  the suite rather than trusted.
* `Shared/PiggyPedestal` — plinth, scaled mini piggy, one long-lived collect
  prompt carrying the slot in its connection and the buffer in its card.
* Ownership as a COUNT (`data.piggies.owned`), placement through one door
  (`Config.addPiggy` / `Config.removePiggy`), auto-placement front to back
  for crate grants.
* `PlotService.setPiggySlots` / `.setPiggyBuffers`, routed through
  `CosmeticsService.applyToPlot` and `EconomyService.refreshPlot` so every
  existing repaint site picks the lawn up. Stripped on `release`.
* Owner-only prompts through `PROMPT_OWNER_ATTRIBUTE`, which `PromptUI`
  already applies to every prompt in the world — and the client's own
  `Enabled` write on the till prompt is gone, because it was a second writer.
* `commands.piggy`, `.fillpiggies`, `.clearpiggies`, on the admin panel.

### The lawn is a hard cap on the collection now (2026-09-21)

**Designer ruling: duplicates place individually, and there is no inventory
— a piggy you own is a piggy that is standing somewhere or it has nowhere to
be. So a crate cannot be rolled while every placement is taken.**

Built and verified live:

* `ChestService.whyCannotOpen` is the one predicate, asked by the shop's roll
  AND by the doorstep crate, so the two cannot disagree about whether a crate
  is openable. It covers the currency, the stock and the room on the lawn;
  funds stay in `roll`, because a free crate has to be able to open for
  nothing.
* Refused **before the roll and before the charge**. Measured on a full lawn:
  the refusal fires, **0 acorns leave** (1779 → 1779) and **0 rolls happen** —
  the reel never spins. Freeing a pedestal lets the same crate straight
  through.
* **The day-seven crate is no longer destroyed by a full lawn**, which it
  would have been. `DailyService.openCrate` clears the step and SAVES before
  it rolls — deliberately, so a disconnect cannot hand a crate out twice —
  so a refusal inside `grantFree` would have consumed the claim and paid out
  a warning. The check moved ahead of the clear. Measured: refused, 0 rolls,
  **prompt still enabled afterwards so the box is still standing**, and it
  opened normally (`og->mint`) once there was room.
* The test is "can this pool yield a skin", not "is this a skin crate", so a
  mixed pool like the Alien Cache is held back rather than rolling the one
  outcome it cannot deliver. Measured, that is currently **every one of the
  seven chests** — the accessory and effects crates are retired — but it is
  written as a question because the catalogue has already moved once.

### The sell prompt, and no more piggy duplicates (2026-09-21)

**The soft-lock the gate above created is closed: a pedestal can be sold.**
Second prompt on the same plinth, `X`, card slot 1 beside collect's 0 — the
steal/smash pattern, because collect and sell are the two things you can do
to your own pedestal and deciding which piggy to let go is the whole point of
reading them together.

* **It pays ACORNS, which turned out to be the existing rule rather than a
  choice.** `Config.sellValue` already sends skins to `SKIN_SELL_ACORNS` and
  everything else to coins. So letting a piggy go buys the roll that replaces
  it, and the transaction never touches the coin economy the audits are
  calibrated against. Verified live: common 3, rare 10, legendary 30, and
  *"Sold Solid Gold. +30 acorns."* took 1764 → 1794.
* **The 1.8s hold is the only guard, and it had to be.** `SetService`'s own
  sell path refuses the copy IN USE — written for "a stray thumb and the
  legendary they spent three weeks getting", where taking it off first was
  one tap. Under six slots EVERY copy is in use, because placement is
  ownership, so that guard would refuse every sale or none. A long hold is
  the instrument this game already uses for a press with consequences
  (`SMASH.hold` is 1.3s explicitly so a smash cannot be started by a brushed
  prompt); this is dearer than a smash, so it is longer, and it is the
  longest hold in the game. Verified: a 0.5s press did **not** sell.
  Deliberately not a confirmation dialogue — this is a tidying action taken
  whenever a crate is wanted, and a modal every time is the confirmation
  everybody dismisses reflexively.
* Slot 0 is not sellable. The till always wears something (§3 falls back to
  Classic), so selling off it would leave the one placement that may never be
  empty empty. Changing what the till displays is a different verb.
* The buffer goes with it and is not paid out — the same rule a snatched
  piggy follows. The collect prompt is on the same plinth, which is why both
  cards are visible at once.
* `ICON.ACORN` is new and **there is no acorn in Unicode** — the HUD's own
  acorn is drawn geometry, so there was nothing to borrow. U+1F330 CHESTNUT,
  render-measured the way that table demands with both controls: 37.0 against
  37.0 for a known-good emoji and 20.0 for a known tofu box.

**And piggy duplicate logic is gone.** `ChestService.handOver` is one function
where the roll and the combine each had their own copy of the grant/spare
split — writing the piggy rule into both is exactly the drift this project
keeps recording. A repeat skin is placed on the next free pedestal, makes no
spare, and the reveal does not call it a duplicate or offer its sell value.
Every other kind keeps the old behaviour deliberately: a duplicate ride or
decoration out of the Alien Cache IS a spare, because those are wardrobe items
with nowhere to stand a second copy.

Verified live: six opens onto an empty lawn all landed, front to back, and
`neonmint` came up **twice** — the repeat reported `dup=false` and stood as
its own copy on slot 6 beside slot 5. The seventh open and a combine were both
refused on the same gate with **nothing spent**.

**Two more bugs this found, both the same shape as the three above.**

1. **A crate grant never repainted the lawn.** `pushers.skin` was
   `CosmeticsService.push`, which sends state to the client and not geometry
   to the plot. Measured: a crate rolled `skin:sunset` into free slot 6 and
   that pedestal stayed bare with the save perfectly correct — the crate read
   as having handed over nothing. The pusher calls `applyToPlot` now.
2. **The repeat-piggy branch told nobody at all**, because it steps around
   `SetService.grant` by design and `grant` is what normally pushes.
   `SetService.repaint` fires a kind's registered pusher without granting,
   through the registry rather than a require — this file may not reach
   CosmeticsService.

**AND A DEAD CONTROL WENT WITH IT.** The combine row was visible whenever a
chest *could* be combined into, regardless of whether the player held any
spares. Fine while every crate rained spares; now six of the seven are skins
only, so on those it would sit permanently visible and permanently 0/5 —
the control that does nothing when pressed. It is gated on actually holding
one. Deliberately NOT hidden on skins-only crates, which was the tempting
version and throws away a real path: `sparesAt` pools by TIER across kinds, so
a spare ride out of the Alien Cache can still combine into an OG crate.

**What this does to `Config.COMBINE` is worth watching rather than acting on.**
Skins were its only real fuel, so the ladder is now near-dead in practice.
Selling is what replaced it, and the exchange rate is not obviously right:
five commons is 15 acorns, which is exactly one more common crate, where a
combine used to give a RARE roll. That is a pacing question for the same pass
that owes §8 its economy re-derivation, not a bug.

### Carrying a piggy: take, snatch, place and the five seconds (2026-09-21)

**The placement verb and the pedestal snatch both landed, which is open items
3 and 4 and is the half of §3 the pedestals were built without.** Until this,
the only way a piggy ever reached a slot was a crate placing it front to back,
so the two routes §3 calls the point of the collection — *"a piggy you went
and got... is placed by hand into any free slot"* — could not happen at all.

**THREE VERBS, AND EXACTLY ONE OF THEM COSTS ANYBODY ANYTHING.** TAKE lifts
one of your own off your own plinth; SNATCH lifts somebody else's off theirs;
PLACE puts one you are holding down on an empty slot of yours. The holds are a
ladder of consequence rather than of difficulty — 0.4s for your own, 1.5s for
somebody else's (dearer than a smash's 1.3, cheaper than a sale's 1.8), 0.4s to
put one down.

**AND THE FOURTH THING, WHICH IS WHAT THE WHOLE FEATURE TURNS ON: A SNATCHED
PIGGY IS SECURED BY STANDING WITH IT.** On your own ground, with somewhere to
put it, for `Config.PIGGY_HAUL.secureSeconds`. Not by pressing anything — and
the `place` prompt refuses a stolen piggy by name, because a prompt is
instantaneous and a thief who could press one on arrival would never be
catchable on their own lawn. The dwell is the only moment in the getaway where
a defender who is BEHIND the thief can still win.

**FIVE SECONDS IS MEASURED AGAINST THE CHASER'S BODY RATHER THAN THE
THIEF'S**, and the first version of that check got it wrong in the way this
project keeps recording: it compared the dwell against CARRY speed and failed
at 60 studs against a 64-stud lawn. The person the five seconds exist for is
the VICTIM, and a victim carries nothing. At `BASE_WALK_SPEED` the dwell alone
is 80 studs, which is exactly `PLOT_SPACING` — a whole plot's walk — and it is
slack on top of a chase the victim is already winning, because a loaded thief
crosses that same ground at `CARRY_SPEED_MULTIPLIER` of the speed the person
after them does.

**IT IS ITS OWN SERVICE RATHER THAN A `HeistService.Carry`, AND THE
MEASUREMENT IS WHAT SETTLED IT.** A `Carry` is about coins: an amount, a
victim's balance, `LOSS_CAP`, `HEIST_PAYOUT`, the spree, revenge, the keep
share, the return bounty, the delivery rings and the bail an arrest charges
against it. Folding a piggy in would have meant a `kind` branch inside
`deliver`, `nab`, `confiscate`, `dropAction`, `carryOptions` and
`pushCarryState` — six functions each learning about a thing none of them is
about. Against that, a piggy haul has to behave like a coin haul in exactly
FIVE places, every one about the WEIGHT of a getaway rather than about money:
the carry speed, the ride refusal, the disguise breaking, the dog hearing a
loaded thief, and being catchable. `HeistService.haulingAnything` is the one
line that covers all five, and `registerPiggyHaul` is the seam — three
questions, registered by `Main`, because `PiggyHaulService` requires
`HeistService` and asking back would be a cycle.

**WHAT REACHES IT AND WHAT DOES NOT.** `nab` is the seam every catcher in the
game already comes through, so a guard dog, a shopkeeper and a bystander all
stop a piggy thief without one of them being the exception somebody forgot;
`confiscate` is the patrol's, and without it an arrest would hold a thief
still, charge them nothing and leave the piggy under their arm. A GADGET
deliberately does not take one: gadgets buy a tag, never the catch.

**A SNATCHED PIGGY ALWAYS GOES HOME TO ITS ORIGIN SLOT.** A nab, a dog, an
arrest, a death and a disconnect are five ways to stop being a thief and one
way for a piggy to be deleted from the game, so they share one function.
Landing on whatever slot happened to be free first would reshuffle a victim's
lawn every time somebody failed to rob them — a cost the victim pays for
winning.

**RESIDENTS KEEP PIGGIES NOW, AND THAT IS THE SUPPLY RATHER THAN THE
SCENERY.** `RESIDENTS.piggyCount` is three of six, drawn from a shuffled bag
against the same catalogue and the same two exclusions the neighbour's own pig
takes, and **capped** at `RESIDENTS.piggyTopRarity` rather than scaled with the
street — the residents' level offset is downward-only because *"residents
richer than the thief are a faucet, full stop"*, and a lawn that seeded the top
tier because the street happened to be rich is that faucet one level up. A
snatched resident piggy is **not replaced**, so a server's neighbour stock is
finite and visibly runs down as the street is picked over. Half-full rather
than full so a picked-over lawn reads as picked over. **Both numbers are
provisional and want the §8 pass.**

**AND THE RAP SHEET IS WIRED AT LAST.** `SocialService.recordSteal` has been
waiting for this since Most Wanted was re-pointed at the value of piggies
stolen; it fires on the SECURE and never on the grab, which is that function's
own rule — loot nabbed out of your hands was never stolen, you were caught.
`Config.piggyWorth` is the unit, so the board and the sell prompt cannot drift.
**The interim coin caller in `HeistService.deliver` is deliberately still
there**: cash robbery is still in the game, and deleting it now would not
retire anything, it would just stop coin robberies counting toward the poster,
the weekly board and the patrol's target while they are still happening. It
goes in the same commit that retires cash robbery.

#### Verified live, end to end, every verb through the real prompts

Clean boot, zero errors across the whole session. take → carrying, walk 16.00
to 12.00, slot emptied, prompt flips to PLACE. place onto a DIFFERENT plinth →
moved, walk back to 16.00. snatch → slot emptied, `haul="stolen"`, the
first-session shield dropped to 0. The dwell → counts 4.9 to 0.2 on my own
lawn and lands at 5.2s on the NEAREST free plinth, does not run at all on the
victim's lawn, resets the instant you step off (and waiting the full window
off-lawn secures nothing), and a FULL lawn never starts it. The per-victim
cooldown → *"Wait 26s before taking from here again."* with nothing taken. A
guard dog → caught at 4.8s with the piggy back on its origin slot. A
disconnect mid-carry → home on its origin slot. A ride → `Ride_skateboard` at
24.00 empty-handed against `nil` at 12.00 carrying, from the same spot.

**AND THE BOOKS BALANCE, WHICH IS THE ONE THING NOTHING ON SCREEN CAN SAY.**
Placement IS ownership, so `piggies.owned` and what is standing are two
descriptions of one fact, and a drift between them is invisible from every
angle — a crate refusing to open over a visibly free plinth, or a piggy
earning from a pedestal nobody owns. `commands.piggystate` is the readout
(Piggies group on the F2 panel) and it exists because the MCP sandbox cannot
read a live save: requiring `DataService` there hands back a fresh module with
empty state, so the only way to see a real collection is to make the GAME say
it. After four takes, two places, two sells, four snatches, two secures, a dog
catch and a disconnect it reported **owned matches standing**.

#### The prompt cards have now been looked at

The build order has recorded these as unseen since the pedestals shipped, and
they are not unseen any more. Four captures through the throwaway-clone trick,
because an `AlwaysOnTop` billboard is composited after `screen_capture` takes
its frame — a fix to the CAMERA and never to the feature.

* SELL (card slot 0) and TAKE (slot 1) render together on one plinth with
  clean separation: billboard heights 82 and 270, which is `82 + 2 × 94`
  exactly.
* SNATCH is a cream card with a red ring chip, the raised-hand glyph, SNATCH
  in red and the piggy's name under it.
* **All three new glyphs were render-measured the way `Config`'s own note
  demands**: PIG, GRAB and PIN each advance **37.0** at TextSize 40 in
  GothamBold, against two known-good emoji at 37.0 and two known tofu boxes at
  20.0.

#### A prompt bug this found, and it is a CLASS rather than one prompt

**"Write the owner before you enable" is necessary and NOT sufficient**, and
this file records that fix as done. The hole is `PromptUI`'s ONE-TIME SWEEP:
it walks every prompt in the world once at startup and refuses anything whose
owner is not the reader. If that sweep lands between the `Enabled`
replication and the OWNER replication for a given instance, it refuses a
prompt the reader owns — and its rules may only ever refuse, so nothing ever
takes it back.

**Measured: three of six SELL prompts locally `Enabled = false` on a plot
whose owner attribute read correctly on BOTH sides, with the server reading
true.** A player could not sell half their own collection, with no error
anywhere. Bouncing those three across a frame from the server fixed all three,
which is what confirmed the diagnosis rather than a reading of the code.

`PiggyPedestal.republish` is the fix: switch all four prompts off, and a fifth
of a second later recompute them from `refs.key` and the owner. **A real frame
has to pass** — Roblox replicates the value a property HAS at the end of a
frame, so an off-and-on inside one frame is no change at all and the client
hears nothing. It **recomputes rather than remembers**, so a piggy sold,
snatched or placed during the beat is answered correctly, and a generation
stamp makes a later republish win rather than whichever timer lands last.
`PlotService.setPiggySlots` fires it only when the plot CHANGES HANDS, because
a repaint runs on every purchase, collect, rebirth and join and bouncing there
would blink every card on the lawn several times a minute.

`PiggyPedestal.setHaul` now owns the owner attribute AND `Enabled` for all
four prompts on a plinth, so the ordering rule is a property of one function
rather than of the distance between two loops — which is the sort of thing
that stays true until somebody inserts something between them.

**ANY OTHER OWNER-GATED PROMPT IS EXPOSED TO THE SAME RACE.** The mailbox and
the doorstep crate were the two not touched here, and they are closed now, in
the pedestal's own shape (Lane 6b): each fact is recorded on the plot
(`mailWaiting`/`mailOwnerId`, `crateKey`/`crateOwnerId`), ONE function per
prompt writes the owner attribute and then `Enabled` (`publishMail`,
`publishCrate`), and `setMailOwner`/`setCrateOwner` bounce the prompt across a
real frame through a shared `bouncePrompt` only when the owner CHANGED -- never
on `DailyService.push`, which runs constantly. Offline-verified only: the race
is timing, so the bounce actually re-arming a poisoned client is a live check.

**Worth knowing before anybody "tidies" the two to match the plinths: an
unowned mailbox or crate publishes NIL, and a plinth publishes 0.** `PromptUI`
refuses 0 on every screen and leaves nil alone, so the mailbox and the crate
were always structurally less exposed than the pedestals -- a batch that
applies `Enabled = true` before the owner attribute meets nil rather than a
stale 0 -- and `MailCall.waiting` compares the attribute against the reader, so
nil must stay nil. The fix is applied anyway because "the owner before
`Enabled`" belongs in one function rather than in the distance between two.

**AND THE TILL IS NOT A THIRD SITE.** Lane 6b's note that the till's
`CollectPrompt` "is owner-gated too and wants checking" predates the
conversion: the till's collect is a floor PAD (`PiggyBank` builds the seventh
`CollectPad`, guarded in `EconomyService.collectPiggy` with the six), and no
`CollectPrompt` exists on the server any more. One mechanism for all seven,
none of it reachable by the race -- not drift. The one stale trace is a comment
in `ClientMain` (near `bindPlot`) still describing a third prompt on the pig's
body.

#### Three prompts per plinth rather than two, and the saving was the wrong one

Take and Place can never both apply — a plinth is occupied or it is not — and
both are the OWNER'S, so one prompt could carry them with `dress` swapping its
kind. It cost more than it saved, twice over. **A card is built on
`PromptShown` and never rebuilt**, so a kind that changes under a card already
on screen leaves it saying the old word — at exactly the commonest moment
there is, a player standing at the plinth they have just cleared. And **a
single prompt enabled in both states never transitions**, so it can never
re-arm the client rule above.

What keeps one key safe is that the two owner rules are exact complements —
`PROMPT_OWNER_ATTRIBUTE` refuses take, place and sell everywhere but the
owner's screen, and the new `PROMPT_DENY_OWNER_ATTRIBUTE` refuses snatch on
the owner's screen and nobody else's — and that the plinth's own occupancy
separates take from place on the server. Measured on a live client: exactly
one haul prompt enabled per pedestal, 6 take on my own lawn and 27 snatch
across nine neighbours.

#### Still not done

* **`LOSS_CAP`'s piggy clause**, above. The snatch is now a primary
  acquisition route and nothing bounds a street taking turns.
* **The pedestal guard** (plan §12, Stage 2). A snatch wakes nothing beyond
  the dog watcher's ordinary footstep rule, so a well-defended lawn defends
  its pedestals exactly as well as it defends its grass and no better.
* **A second player.** Every snatch verified here was against a RESIDENT. The
  branches that need a real victim — the alarm toast naming the thief, the
  shield refusal, a bystander pressing the nab prompt on a carrier — have been
  driven only from the code's side.
* **Indoor rooms.** `roomFor` is the one predicate interiors change: a house
  becomes a second room with its own free-shelf test, and the dwell, the
  countdown, the interruption and the landing are all untouched.

Not done, in the order it matters:

1. ~~**A way to free a pedestal.**~~ **Done — the sell prompt, above.**
2. ~~**Duplicates place individually.**~~ **Done — `handOver`, above.** What
   is left of it: `data.spares` may still hold `skin:` entries from before
   this changed, and nothing prunes them. They are unreachable rather than
   harmful — the inventory only draws what a catalogue still lists and skins
   can no longer gain spares — but a reconcile prune would be honest.
3. ~~**The placement verb.**~~ **Done — see below.**
4. ~~**The pedestal snatch**~~ **Done — see below.** **`LOSS_CAP`'s piggy
   clause (plan §8) is NOT**, and it has to land with the §8 pass rather
   than beside the snatch: it is a cap on what a victim may lose AND, from
   the other end, the ceiling on how fast anybody builds a collection by
   stealing — two curves that multiply, which is the failure shape this repo
   records more than any other. `Config.PIGGY_HAUL.victimCooldown` bounds one
   THIEF against one lawn and bounds a street taking turns not at all.
5. ~~**What residents display** (plan §9.4).~~ **Mostly done — see below.**
   Every neighbour keeps `RESIDENTS.piggyCount` piggies, drawn against the
   same catalogue and exclusions as everything else and capped at
   `RESIDENTS.piggyTopRarity`. **Both numbers are provisional** and are the
   single biggest dial on solo pacing, so they want re-deriving in the same
   pass as item 6 rather than after it.
6. **The economy re-derivation** (plan §8) — still the single largest piece
   of work in the plan, and still untouched. `EconomyService.collectionRate`
   exists as the one honest input to it.
7. **`Config.PIGGY_RARITY_INCOME` grew an `epic` rung** because exactly one
   skin (the Martian) carries that tier and would otherwise have silently
   earned the common floor. Provisional like the other three.

### The centre pig is the target, and it is the bank (designer decision, 2026-09-22)

**Coins are robbed from the CENTRE PIG and from the shop vaults, and never
from the pedestals.** For an hour on the 22nd the plan here read the other
way -- rob the six little pedestal piggies and leave the bank alone -- and the
designer reversed it before a line of it reached a service: *"i don't want
the pedestal crack; the piggy in the center of the lawn can have the lock on
the back of it, just without the hole."* So:

* the centre pig holds everything a player owns (it has no capacity), it is
  cracked and smashed exactly as it is today, and it keeps its Vault Lock on
  its back -- drawn over a CLOSED hatch, since the Blender pass fills the
  hole; the lock is a dial on a solid rump rather than a door over a hole;
* the centre pig cannot be SNATCHED as an object; a thief carries a BAG of
  coins home from it (item 4 below), and a snatched pedestal piggy comes home
  as itself;
* the centre pig has no collect pad and no buffer: its own income drips
  straight into the balance (item 3);
* the pedestals are only ever taken, placed, snatched and sold. No crack, no
  smash, no lock on a plinth, no rob badge over one;
* `LOSS_CAP` stays, unchanged, because a crack of the bank is a fraction of
  somebody's whole wealth times `HEIST_PAYOUT` and that is precisely what it
  bounds.

**Measured, against the live Config, once the idle side was a whole lawn.**
The audit used to compare robbing against ONE pig of income; a player idles
on the till plus six placed piggies now, seven times the base rate on a lawn
of commons, and at `pigSeconds` 200 and `HEIST_PAYOUT` 4 that read 0.99x on a
full server -- standing still was the better play again. Two levers, one
already decided (`HEIST_PAYOUT` 4, from the designer's *"robbing needs to pay
substantially more than your current income from pigs"*), so
`RESIDENTS.pigSeconds` moved, 200 -> 660:

    street          cold      five stars
    one player      3.70x     7.41x
    full server     3.28x     6.55x        (two houses and four shops left)

Flat across every level and rebirth (the rate cancels), above the 3.0x floor
at every population, under the 10x ceiling at five stars. What it costs is
stated rather than hidden: robbing a resident pays a fixed multiple of BASE
income, so a thief whose own lawn is legendaries idles far more than any
resident can pay (`robberyFigures().coldTopLawn` is 0.07x). That is the
design -- the rich thief's target is a rich PLAYER, whose bank scales with
their wealth and whose loss is bounded by `LOSS_CAP` -- and it is printed on
the boot line rather than audited.

**Stars replace the spree, and they pay as well as cost.** `Config.SPREE`
already did half of this (each delivery +25% payout and a lower patrol floor,
decaying after 45s). `Config.WANTED_STARS` is that ladder made longer, visible
and consequential, and the spree is folded into it rather than kept beside it
(two ladders doing one job is the two-tables mistake):

* a delivery earns a star, to a cap of five; each star adds 20% to the payout
  multiplier, so five stars DOUBLE a delivery;
* each star lowers the patrol floor by 15%; from three stars the patrol comes
  for you on every pass, and at five it is called early;
* stars fade one per two minutes of quiet, and an arrest wipes them all with
  the bail;
* bail stays a share of the bank (`POLICE.bailFraction`), so the worst
  outcome is an afternoon of income and never a house or a skin.

The wanted chip draws the five stars as pips; the `WantedState` payload
carries `stars`/`starsMax` where it carried `spree`/`spreeMax`. Shipped and
verified offline (`tests/luau/piggies.luau`, `settlement`, `theft`).

**Loot is a bag, and a snatched piggy is a piggy.** A thief carrying a
miniature of the victim's centre pig was the right picture while the pig was
what you took; a thief carries the COINS now, so they come home in a money bag
sized to the mini so `CarryPose.HOLD` and the hug pose are reused unchanged.
A snatched pedestal piggy comes home as itself.

**What retires:** the till's collect pad and slot-0 buffer (`tillBuffer`);
`Config.SPREE` (into `WANTED_STARS`, done); the pig's open hatch (the Blender
fill; the lock dial stays and sits over the closed back). Nothing about the
crack, the smash, the rob badge, the cooldown or `LOSS_CAP` moves.

**Build order, and the measurement came first:**

1. DONE: `auditRobbery` idles on `collectionRate` of a lawn of commons;
   `HEIST_PAYOUT` 4 and `RESIDENTS.pigSeconds` 660 solved against it (table
   above); `robberyFigures` prints the corners on the boot line.
2. DONE: `WANTED_STARS` replacing `SPREE` in SocialService, HeistService
   (`deliver`), PoliceService (`clearStars`) and `Shared/Wanted`; the wanted
   floor denominated in `collectionRateOf`. OPEN inside it: PoliceService's
   pursuit selection does not yet pick a >=3-star player when nobody clears
   the floor, and the five-star early call is wired but unproven live.
3. DONE: the bank drips. `EconomyService`'s tick adds the till skin's rate
   straight to `coins`; `tillBuffer` is folded into `coins` once by
   `DataService.reconcile` and dropped; the till's collect pad, its face,
   figure, sound and stamp are gone from `PiggyBank` and `PlotService`;
   `collectPiggy` refuses slot 0. Measured live: Plot1's pile rising at the
   till's own rate with no pad on the lawn and no error in the log.
4. DONE: the bag. `HeistService.attachLoot` builds the Bigger Sack card's
   own model (`UpgradePreview.build("sack", thiefSackLevel)`) as the carry:
   renamed `StolenPiggy` so `CarryPose` holds it in two hands, sack part
   renamed `Body` and made PrimaryPart so the weld, the gold trail, the
   amount label and the nab prompt seat on it unchanged, every part
   unanchored, massless and welded to the sack. The snatch keeps the mini.
   Driven live through the new console command `smash` (Heist group): the
   bag seated at exactly `CarryPose.HOLD`, labelled "Old Man Hamm's coins
   234", the toast promising "worth 936 at home", the delivery banking 936
   and the wanted chip pushing one star. A bigger sack is a visibly bigger
   bag.
5. DONE, PENDING UPLOADS: the Blender pass runs on disk (fill, body export,
   every body sheet re-baked, renders per skin); the designer uploads one
   round and the Body row and the ColorMap ids land in Config together.
   LOCK LEVEL 0 DRAWS THE LEVEL-1 DIAL (designer decision): with the hatch
   filled there is no open hole for "unlocked" to read as, so every pig
   wears iron from its first second and a bought lock changes the metal and
   the spoke count. `PiggyBank.setLockLevel` clamps 0 to tier 1.
6. DONE: the patrol is sent by STARS AND NOTHING ELSE (designer decision,
   same day: "remove that floor from the code now since it's reliant on
   stars"). `POLICE.wantedFloorSeconds`, `WANTED_STARS.floorDropPerStar`,
   `Config.getStarFloorScale` and `SocialService.wantedFloor` are gone;
   `getPursuitTarget` takes the most-starred player at or above
   `huntedFrom`, biggest sheet breaking a tie; the poster's bar is the star
   ladder ("2 STARS TO A PATROL" / "PATROL COMING"); crossing the threshold
   is announced on the delivery that crosses it; the `mostwanted` console
   command grants the stars as well as the sheet so a patrol actually comes.
   Leading the board is a ranking, never a warrant.

7. DONE: the closed-back pass ran on disk (master filled, 19 base body
   sheets re-baked, the three legendaries rebuilt against the closed body
   with backups beside every prior file); the upload round is listed in
   `blender/pig/renders/closed-back-test/UPLOADS.md` (28 uploads). Storm
   Wolf is the designer's by hand.
8. DONE: the bank-till SWAP (`PiggyHaulService.swap`, a SWAP prompt on the
   bank pig, `Config.PROMPTS.swap`, `PIGGY_HAUL.swapHold`); the bank is
   dressed from `piggies.till` now and the bag's skin tap refuses naming
   SWAP. Verified offline; the physical press is the designer's.
9. IN PROGRESS: every piggy's sources live under `assets/piggies/<tier>/<key>/`
   (source/, generate/, sheets/, preview/, manifest.json) resolved by
   `blender/pig/paths.py`; the legendaries and the derived import packages
   are being folded in. Old locations stay until the designer deletes them.

Every step is verified offline in `tests/luau/theft.luau` and
`tests/luau/piggies.luau` and then driven live through the real prompts.

## Stage 2 — pedestal guards

The trigger call into the existing `GuardDog.chase` on an active pedestal
steal, and the new slower-than-carry-speed profile for that role (plan §12).
Depends only on Stage 1 existing — fast, since most of the mechanism
(the leash, the driveway stop, the chase loop itself) is reuse of something
already built and already working for the till.

## Stage 3 — roaming herds

Independent of everything else here (plan §15). Its only real dependency is
the crate/chest system, which already ships today — nothing about ownership,
placement or the pedestal snatch has to exist first. **Can be built any time,
including in parallel with Stage 1**, if there's bandwidth for it — it is the
one piece of this whole plan that genuinely doesn't care what order it lands
in relative to the rest.

## Stage 4 — interiors

One tightly coupled cluster; build it as a single piece rather than in
sequence:

- The door-crossing primitive (one function, any Model with a root — a
  player's character or the officer's rig; dogs are excluded by design, see
  plan §12/the pedestal-guard scope).
- The dark-doorway trick and the brief opaque-screen mask, reusing the
  scrim/tween shape already built for the arrest scene.
- The server-authoritative CFrame teleport, both directions, reusing the
  same trick the arrest release already does when it puts a thief back at
  their own gate.
- `PoliceService` learning to route a pursuing officer through a door when
  its target crosses one — genuinely new logic, no existing precedent to
  lean on for this one piece specifically.
- The detached per-plot interior room itself: one fixed-size, code-generated
  hallway for the MVP (a Shared builder in the `House.luau`/`Decor.luau`
  style), not per-house Blender art and not a wall-shelf room. Piggies stand
  on floor plots along the hallway, closer to the lawn's own placement grid
  than to `TrophyRoom`'s mount system; doors along the hallway gate more
  plots by rebirth tier, not by house tier (plan §6, rewritten 2026-09-20).
  The achievement wall keeps its own separate `Wall` mount, unaffected (plan
  §8's own flagged exception). Bespoke, theme-matched Blender interiors are a
  later pass on top of this, not a blocker for it.

The door is useless with nowhere to walk into, and the room is useless with
no way in — there's no useful partial version of this stage.

## Stage 5 — what interiors unlock

Rebirth-gated gadgets (plan §11 — Spring Boots, Grapple Gun, Jetpack) and the
in-base shop door (plan §13). Both need Stage 4 first: a mobility gadget has
nothing to reach until indoor shelves exist, and an in-base shop needs a base
to be in.

## Stage 6 — monetization

The Robux crate decision (plan §14), whichever direction gets picked.
Doesn't block or get blocked by anything above — slot it in whenever it's
decided, including before Stage 4 if the answer comes first.

## Stage 7 — retirement

**MOSTLY DONE 2026-09-21, AND DELIBERATELY OUT OF ORDER.** Acorns, the tree,
the basket, the shake, the season track and the crate purchase are all gone;
skins-as-wardrobe is the only item on this list still standing.

The sequencing note below was right and was overtaken by a decision rather
than ignored: **crates are earned or bought with Robux and never with in-game
currency** (designer), which left acorns with nothing to buy. Retiring them
ahead of the job board means the Crates tab is award-only for now — day seven
of the daily ladder, a rebirth, events — which is thinner than §7a intends.

The original reasoning, kept because it still governs what is left: retire
what the collection replaces only once the replacement has actually shipped
and proven itself — the same discipline the trophy-room migration already
follows (*"migrate lawn trophies only after interior displays work... never
disturb what somebody earned"*).

## Stage 8 — the content track (runs in parallel, with one hard interlock)

`docs/PIGGY-PACKS-PLAN.md`: the four-tier re-tag, the nine-row cut list, the
face system that turns the common tier into moods, the tier nameplate, and
the pack schedule out to ~80 piggies. Like Stage 3, most of it does not care
what order it lands in — it is authoring rather than engineering, and it can
start today.

**TWO THINGS INTERLOCK WITH THE STAGES ABOVE AND BOTH RUN THE SAME WAY.**

* **The re-tag has to precede Stage 1's economy re-derivation, not follow
  it.** Rarity is income now, so moving eight animal coats from common to
  rare is a 4x move on eight objects. Deriving the economy first means
  deriving it against a catalogue that is about to change underneath it.
* **The re-tag may not ship before the animal shelf has commons.** Every one
  of its eight commons is a baked coat, and a coat is a rare under the new
  ladder — so re-tagging in place empties a tier `Config.CHESTS.animal`
  authorises at 52%, and `liveOdds` silently reprices the crate rather than
  refusing it. The Moods pack is what restocks that tier, which is why it is
  first in the pack schedule.

### Acquisition moved, 2026-09-21, and it reaches Stage 3

**Piggies are collected by STEALING them and by CATCHING THEM OUT OF HERDS.**
Crates stop being the primary route. Packs plan §10 has the reasoning; the
sequencing consequences are these:

* **Stage 3 stops being the one piece that does not care when it lands.** It
  said so in as many words — *"can be built any time, including in parallel"* —
  on the basis that a herd paid out a crate and crates already shipped. A herd
  that hands over THE PIGGY YOU CAUGHT is a primary supply route, so it moves
  up beside Stage 1 rather than sitting beside it optionally. It also needs the
  ownership and placement path from Stage 1 to grant into, which it did not
  when it paid a crate.
* **Stage 1's open item 5 — what residents display — is promoted.** It was a
  solo-pacing dial. With stealing as a primary route it is THE supply question
  on a quiet server, and sixty empty plinths is an acquisition route with
  nothing on it. Packs plan §10e.
* **`LOSS_CAP`'s piggy clause is now two things at once.** It caps what a
  victim can lose AND how fast a thief can build by stealing — two curves
  multiplied, visible before it ships for once. It wants measuring with the
  §8 economy re-derivation rather than after it.
