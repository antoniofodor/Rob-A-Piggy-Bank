# Parallel work plan — the piggy-collection pivot

Written for the four Claude sessions working this tree at once, and for the
person dispatching them. It answers ONE question: who may touch what, right
now, without two correct edits composing into a third bug.

Sequencing lives in `docs/PIGGY-COLLECTION-BUILD-ORDER.md`; reasoning lives in
`docs/PIGGY-COLLECTION-PLAN.md` and `docs/PIGGY-PACKS-PLAN.md`. This file is
ownership and protocol only, and it is disposable — it stops being true the
moment the lanes below close.

Ownership below was collected from the three live sessions on 2026-09-21, not
guessed.

---

## Three findings that reorder everything

### 1. The hard interlock is currently being run backwards

`PIGGY-COLLECTION-BUILD-ORDER.md` Stage 8 says, in as many words:

> The re-tag has to precede Stage 1's economy re-derivation, not follow it.
> Rarity is income now, so moving eight animal coats from common to rare is a
> 4x move on eight objects. Deriving the economy first means deriving it
> against a catalogue that is about to change underneath it.

Measured on disk today: `Config.RARITY_ORDER` is still four tiers, there is no
`mythic` anywhere in `src/`, and `PIGGY_RARITY_INCOME` is
`common 1 / rare 4 / epic 8 / legendary 15` with its own comment calling all
four provisional. **The re-tag has not happened.** Meanwhile §8 — the economy
re-derivation, the single largest piece of work in the plan — is in flight.

**The fix is not to serialise the two.** It is the rule this repo already has a
dozen post-mortems about: DERIVE, DO NOT PIN. §8 must solve against a catalogue
it READS rather than against the numbers standing today, so the re-tag flows
through it instead of invalidating it. `SHOP_BANK_PIG_SECONDS` was pinned and
wrong by 62% on its first audited boot; `RESIDENTS.pigSeconds` was solved
against a take that was then replaced. Same shape, seen in advance for once.

**RESOLVED 2026-09-21, AND THE ANSWER IS BETTER THAN THE REQUEST.** Lane 2
audited its own landed work against this rather than agreeing to it, and the
constants were already derived — `piggyBufferSeconds` reads
`PIGGY_RARITY_INCOME` at call time, `auditRobbery` scans for the top tier
rather than naming legendary, `fullLawn` derives from the slot count,
`collectionRate` takes a list. **The real hole was elsewhere and is exactly
the failure this section is about:** `RARITY_ORDER` and `PIGGY_RARITY_INCOME`
are two views of one ladder and the second is a MAP, so a tier can sit on the
ladder with no row in it — `getPiggyIncomeRate` falls back to 1x and
`piggyBufferSeconds` to the floor, so a brand new tier would earn AND hold
exactly like a common on every pedestal in the game with nothing in any log.
The table's own comment predicted it and nothing enforced it.

`auditEconomy` now walks `RARITY_ORDER` and reports a tier with no income row,
a multiplier that does not beat the one below it, and any skin tagged with a
rarity that is not on the ladder. **So the re-tag is now safe to land in ANY
order relative to §8** — add a tier without pricing it and the boot says so.
The interlock is dissolved as a GUARD rather than as a wait, which is the right
shape and one nobody has to remember.

`tests/luau/piggies.luau` carried its own `{ common, rare, epic, legendary }`
to walk that ladder — a second copy of the ladder inside the one file whose job
is catching the first copy being wrong, and pinned at four it would have
asserted four rungs of a five-rung ladder and reported clean. It walks
`RARITY_ORDER` now, with the missing-row case provoked rather than assumed.

### 2. The parallel-safe gate is red — measured, not reported

Two sessions disagreed about this, so it was run rather than arbitrated. **All
twenty-one suites, 2026-09-21: fifteen pass, SIX fail** — `rebirth`, `handoff`,
`shopdrops`, `robberyui`, `shopui`, and `houses`. A session reporting "every
suite green" has run its own subset; `piggies` at 384 and `ladder` at 123 are
both genuinely green.

**The sixth was invisible because the suite could not be named.** The runner's
`choices` tuple carried `assets/houses` while the file is at
`tests/luau/houses.luau`, so `--suite houses` was rejected by argparse and
`--suite assets/houses` opened a path that does not exist — **unreachable both
ways, so it has never run through this runner.** Fixed here, one word, and it
is worth knowing what it was hiding: `tests/luau/houses.luau` is the house-
ownership matrix `CLAUDE.md` cites as the guard on schema 26's derive-only
rule, and it fails its very first check — `#Config.HOUSE_TIERS == #BRIEF`,
"nineteen rows: eighteen priced and the earned pig" against a live
`HOUSE_TIERS` of eighteen. **A guard that cannot be named is a guard that is
not running**, and this one drifted while nobody could have noticed.

**Run them like this.** `luau` is not on `PATH` and `python3` resolves to the
Microsoft Store stub, which fails with a Store advert that reads exactly like a
test failure — it produced twenty false FAILs here before it was spotted:

```
PY=/c/Users/anton/AppData/Local/Programs/Python/Python310/python.exe
LUAU=/c/Users/anton/AppData/Local/Temp/codex-luau-0.738/luau.exe
"$PY" tests/run-crates.py --luau "$LUAU" --suite <name>
```

**ONE of the five is the pivot's doing. The other four are pre-existing debt,
and that is measured rather than inferred.** An earlier version of this section
claimed four shared one root and were "one job" — that was reasoned from the
shape of the error messages and it was wrong. Extract the committed baseline and
run it:

```
BASE=$(mktemp -d); git archive HEAD src tests | tar -x -C "$BASE"; cd "$BASE"
```

| suite | at HEAD | in the working tree | reading |
| --- | --- | --- | --- |
| `rebirth` | **PASS** | `ChestService:357: attempt to call a nil value` | the only pivot casualty — `handOver` calls `SetService.repaint`, the suite's stub has none |
| `handoff` | FAIL `handoff:3722` | FAIL `handoff:3779` | pre-existing |
| `shopdrops` | FAIL `200 probability samples: home` | same | pre-existing |
| `robberyui` | FAIL `resident has no imaginary prize` | same | pre-existing |
| `shopui` | FAIL `index nil with 'Visible'` | same | pre-existing; bundles no `ChestService` at all, so `handOver` cannot be its cause under any reading |

**So landing the `handOver` work turns ONE suite green, not five**, and a Lane 0
scoped as "fix the five" is scoped to look like it failed. Split it: `rebirth`
goes with the pivot work, and the other four are debt that predates all of it
and wants its own pass and its own reading — nothing about them is evidence of
anything the pivot did.

`rebirth`'s failure has also MOVED during this session (a stale assertion at
`economy tests:129` became a nil call at `ChestService:357`), which is the tree
shifting under two sessions at once and fits `piggies` going 302 → 384 in the
same window. Re-run before quoting a failure; a stale error message here reads
exactly like a fresh one.

**Offline tests are the ONLY gate four sessions can all run at once** — Studio
is a single instance (below). A red baseline means nobody can tell their own
breakage from the inherited kind, which is how a real regression ships. This is
Lane 0 and it comes before the rest.

### 3. `auditRobbery` is firing, deliberately

Robbing returns **0.459x** idling against a floor of 3.00x, because idling was
being measured as one pig while a lawn earns up to 105x that. The game is in a
knowingly-broken economy state. That is Lane 2's job, it is already owned, and
nothing else should try to fix it in passing.

---

## A rule learned today, stated generally so the next room does not relearn it

**AN ENCLOSED ROOM IS NOT A DARK ROOM.** Every part in this repo is
`CastShadow = false` — `CLAUDE.md` records it on 88% of the world — so nothing
here casts a shadow and **no roof blocks the sun**. Any interior, anywhere,
off-map or on, is at full daylight inside: `Lighting.Brightness` 2.4, the
blue-tinted ambient, and the bloom threshold at 1.7 all apply exactly as they do
on the street. Two consequences, both measured on the hallway in one day:

* **A room that reads black is painted dark, not unlit.** The first hallway
  was black because its walls came from a neon house's palette.
* **A room painted pale will white out with NO lights at all**, and adding
  lights on top makes it worse. The rework put fifteen PointLights into pale
  stone under the sun and every surface cleared the bloom bar — the shopfront
  white-out entry in `CLAUDE.md`, indoors.

So an interior is painted FOR SUN, not for lamps: mid-tone flat colours that
survive `Brightness` 2.4, lights only as warmth under a fixture at a fraction
of what feels right, and **the picture as the only instrument** — the number in
the source is not the colour on the screen, and there is no probe for "blown
out". The next person to build a room will reach for lights first; this is why
not to.

---

## Constraints that decide the shape

1. **There is ONE Studio.** `list_roblox_studios` returns a single instance,
   and Rojo does not push while Play is running — so a session holding Play
   blocks every other session's sync, not just its own. Live verification is a
   QUEUE, not a parallel activity.
2. **`Config.luau` is the shared hot file** and all three sessions are in it.
   It is ~14,000 lines, so region ownership works — but only with targeted
   replacements, never a whole-file rewrite. Two sessions have already collided
   there benignly; both edits survived because both were targeted.
3. **Two documentation agents rewriting `docs/GAME.md` is the one collision
   nothing in this toolchain can catch.** Both report success; the loser's work
   vanishes with no error anywhere.
4. **`tests/luau/piggies.luau` and `tests/run-crates.py` have already collided
   twice** between sessions appending to them.
5. **133 files are dirty and nothing has been committed since the pivot
   checkpoint.** Four sessions writing into that is one bad rewrite away from
   losing a verified Stage 1.

---

## Protocol

**Config.luau.** Announce the region, wait for the answer, then edit. Claims
standing as of 2026-09-21:

| region | owner |
| --- | --- |
| `PIGGY_BUFFER_*`, `piggyBufferSeconds`, `PIGGY_RARITY_INCOME`, `getPiggyIncomeRate`, `collectionRate`, `fullLawn`, `robberyRates`, `auditRobbery`, `PIGGY_PEDESTAL.pad`, `PIGGY_NAME`, `piggyCollectPitch` | Lane 2 |
| `PIGGY_HAUL`, `placePiggy`, `PROMPTS.take/snatch/place`, `PROMPT_DENY_OWNER_ATTRIBUTE`, `ICON.PIG/GRAB/PIN`, `RESIDENTS.piggyCount`/`piggyTopRarity` | Lane 3 |
| `POLICE`, `piggyWorth`, `bailPercent` | landed and released |
| `RARITY_ORDER`, `RARITIES`, `RARITY_BANDS`, the `SKINS` catalogue | Lane 1 — **and every one of these is read by Lane 2** |
| `LOSS_CAP` | unclaimed — goes with Lane 4 |
| **THE CAPACITY LADDER — `getCapacity`, `CAPACITY_GROWTH_*`, `getCapacityCost`, `UPGRADE_COST_CEILING`, `fitInPig`, the Bigger Piggy Bank rung, the rebirth gate → `REBIRTH_CASH_GATE` / `rebirthPiggyGate`** | **IN FLIGHT, coordinator's capacity-removal agent, from 20:27 on 2026-09-21.** `Config.getCapacity` is already gone from disk with six callers still standing, so `ladder`, `piggies`, `theft`, `shopdrops`, `shopui` and `rebirth` are RED and are NOT a gate for anybody until this lands. Two peers flagged it as a possible collision inside ten minutes; it is not one. The coordinator posts the suite counts when it lands. |
| `INDOOR`, `INDOOR_ROOM_PLOTS`, `indoorPlots`/`indoorRooms`/`indoorPlotCeiling`/`indoorRoomCeiling`/`indoorPlotsInRoom`/`indoorDoorRebirths`/`auditIndoor`; `HOUSE_DOOR`, `INDOOR_ESTATE`, `crossedDoorway`, `auditHouseDoor` | landed (hallway + door agents), released |
| `HERDS` (inside the table), `herdGround`..`auditHerds`; `HerdService.luau`; `tests/luau/herds.luau` | **HERD LANE 2, in flight from ~21:20** -- five packs of ten, path-respecting wander, server dig state on `Config.HERD_DIG_ATTRIBUTE` (coordinator wrote the contract: `HERDS.dig`, attribute `DigStartedAt`) |
| `Config.GRASSLAND` (inserted immediately BEFORE `Config.HERDS = {`); new `Shared/Grassland.luau`; the call site in `NeighborhoodService`; ONE veto line in `Main`; `tests/luau/grassland.luau` | **GRASSLAND LANE, in flight from ~21:20** -- ponds, flower drifts, rocks, logs in the herd band; ponds veto herd ground |
| `Config.PIGGY_DIG` (inserted AFTER the `PIGGY_WALK` region); `Shared/PiggyWalk.luau` (extended); optional `Shared/PiggyDig.luau`; one start line in `ClientMain`; `tests/luau/walk.luau` | **DIG VISUAL LANE, in flight from ~21:20** -- client dig pose, dirt particles, pooled coin pop, visual only |
| `BASE_WALK_SPEED` and EVERY speed field that reads it or should (`POLICE.carSpeed`, `THROW.speed`, any resident walk, plus the already-derived dog/officer/herd/ride/tiptoe/carry/dodge/climb/burst ratios); `refreshSpeed`/`currentSpeed`; every suite that pins an absolute speed; new `tests/luau/speeds.luau` | **SPEED LANE, in flight from ~01:00** -- designer decision: derive everything as a ratio of the base, then raise the base (placeholder 20). Phase 1 must be byte-identical at 16; Phase 2 reports consequences (robbery audit ratios, patrol legs, getaway, chase, herd cadence, throw drop) and retunes nothing. |
| `PIGGY_MESH` asset id (one field), `PIGGY_MESH_FACE.nostril` (removed, dead) | session 92 — blender clean-up and a `pig_trim` .obj with a byte-identical UV layout; the id changes only if its user uploads |

Never rewrite the file. Never lift an assignment out of a table literal while
somebody else is moving that table — that exact pair of correct fixes composed
into a third bug here once already.

**Before any Play: check Config for forward references.** Eleven have taken the
whole server down, the last one on a table field, and four sessions editing one
file is how the twelfth happens. The scanner described in `CLAUDE.md` is not in
this repo — committing it is Lane 0's second job. Until it exists the substitute
is to press Play once after touching `Config` and read the log for "Ready".

**Driving a HUD control from a harness: CHECK THE `Visible` ANCESTOR CHAIN, not
what is topmost.** Recorded with its own correction, because the first version
was wrong. A session clicked a live upgrade row three times at its exact centre
and nothing fired; the first diagnosis was that touch emulation's full-screen
`TouchControlFrame` was eating the click. The touch frame is real and does eat
clicks — disabling `TouchGui` from the harness is a reusable technique — but it
was NOT the cause: `target.Parent.Visible` read **false** the whole time. The
row was in the tree and off screen, every click landed on nothing, and the tool
reported Success either way. `GetGuiObjectsAtPosition` answers a question about
pixels and says nothing about whether the thing you want is drawn. **Walk
`Visible` from the button up to the ScreenGui before believing a coordinate.**
`CLAUDE.md`'s "the mouse tool lands where it is aimed" holds for the pointer;
this is the caveat on what receives it.

**Three duplicate-name findings in the shop in one day, all unclaimed shop-lane
work:** the two `EarnRow` buy buttons are both named `TextButton`; `PiggyHUD` has
TWO children named `Frame`, so `hud.Frame` resolves to the toggle column while
the views live under the other one and a listing reads as the shop having been
deleted. The "name every instance a probe might address" rule, unfixed on the
most-clicked controls in the game. One pass, one owner.

**The Studio token.** Whoever wants a live pass announces it, holds it, and says
when it is released. Hold it for one verification, not one lane. Everyone else
works offline meanwhile. *Held by Lane 3 as of the first live pass, 2026-09-21 —
this line is a snapshot, so ask rather than trust it.*

**A near-miss worth keeping.** Two sessions independently narrowed the `houses`
failure to the same row and both moved to edit `tests/luau/houses.luau` within
the same few minutes. One was stopped by a tool-permission refusal rather than
by the protocol, and the other's fix — which was the better one, carrying the
manifest evidence — landed intact. **The announce-then-act rule was followed on
Config and skipped on a test file**, because a test felt too small to announce.
It is not: it is a shared file like any other, and the only reason this did not
become the compose-into-a-third-bug failure was luck.

**Tests.** Each lane adds its OWN suite file (`tests/luau/<lane>.luau`) rather
than appending to `piggies.luau`, which is frozen at 380 checks until the lanes
close.

**docs/GAME.md — one owner, and it is Lane 3.** It asked, the other two
deferred. `game-doc` runs ONCE, after its live pass, never concurrently with a
second run.

---

## The lanes

Numbered by priority, not by dependency. Lanes 0–4 can all run today with no
ordering between them beyond the announced Config regions.

### Lane 0 — restore the gate (do this first, it is small)
* ~~**`rebirth`**~~ **DONE, verified independently: 15 of 21 → 16 of 21, and
  `rebirth` passes at 103 checks.** No source fix was needed; the production
  path was correct and the fault was entirely in the suite's `SetService`
  double, which lacked `repaint` AND had drifted in a second, quieter way —
  the real `grant` calls `Config.addPiggy` for a skin (placement IS ownership
  now) while the stub only wrote `cosmetics.owned`.

  The stale ASSERTION mattered as much as the stub: it still asserted a repeat
  skin pays a spare and is called a duplicate, which the piggy-collection
  ruling reversed. It now asserts the new behaviour (rolled, not re-granted but
  pushed, placed as a second copy on the next free pedestal, no spare, not
  called a duplicate) **and, deliberately, that a non-skin duplicate still DOES
  pay a spare** — derived by walking `liveOdds`' live pool rather than
  hardcoding an entry, so nobody later "simplifies" the split away.

  **A live comment-drift found on the way, left for whoever owns the file:**
  `SetService.grant`'s own comment still says a repeat skin "goes to
  `ChestService`'s spare pool instead, which is the WARDROBE model" and calls
  duplicate-counting a gap. `ChestService.handOver` has since stepped around
  `grant` for exactly this case, so the comment now describes the old rule.
  Behaviour is correct; the sentence beside it is not. Same family as the
  `gable()` comment that was wrong for the life of the project. **Unclaimed.**
* **`handoff`, `shopdrops`, `robberyui`, `shopui` are pre-existing debt** —
  red at the committed baseline, before any pivot work existed. They are worth
  fixing and they are NOT a gate on the pivot, so do not let them hold a lane.
  Each wants its own reading; `shopui` bundles no `ChestService` at all.
* **`houses` — RESOLVED, and the catalogue was right.** The single difference
  was `candy`: `assets/houses/mvp-exterior-manifest.json` says
  `permanentModelCount: 18` with `seasonalExcluded: ["candy"]`, and the asset
  folder is `gingerbread-manor-seasonal-v1`. The Gingerbread Manor is SEASONAL
  and excluded on purpose; the suite's BRIEF had been written from the 19-row
  DESIGN catalogue, which includes it. **The schema-26 migration was never at
  risk** — `HOUSE_LEGACY_ORDER` is nine ids and every one still resolves.
  Three stale families are fixed by DERIVING rather than repinning (the brief
  row, the placeholder check that broke when an artist actually landed a model,
  and `earnedHouseProgress`'s pinned total). The suite now fails honestly at
  line ~155 instead of dying on the row count — see open decision 5.
* **Sweep the runner for other unreachable suites** while somebody is in there.
  One name drifted silently; that is rarely the only one.
* **`docs/GAME.md` §12 is missing two service rows** — `SceneryTrees` and
  `TrophyRoom` are real files in `src/ServerScriptService/Services/` and neither
  is a row (`TrophyService` is, and is a different file). Verified by diffing
  the directory against the table rather than by reading. Predates the pivot.
  The honest fix is a derived check — a test that walks the Services directory
  against the table — rather than adding two rows and waiting for the third to
  go missing.
* Commit the Config **forward-reference scanner** as a repo tool.
* Commit a checkpoint of the verified Stage 1 work before the lanes widen.
* Split `tests/luau/piggies.luau` into per-lane suites and freeze it.

Bounded and read-mostly; safe to run as one-shot subagents, all at once.

### Lane 1 — CONTENT: the Moods pack, then the five-tier re-tag
*Blocks nothing; unblocks Lane 2's final numbers. Start it first because it is
authoring — the one lane that parallelises INTERNALLY, one agent per piggy.*

Order inside the lane is fixed and the reason is in the packs plan: the re-tag
may not ship before the animal shelf has commons, because every one of its eight
commons is a baked coat and a coat is a RARE under the new ladder — re-tagging
in place empties a tier `Config.CHESTS.animal` authorises at 52%, and `liveOdds`
silently reprices the crate rather than refusing it.

1. The Moods/faces pack (packs §5c) — restocks the common tier.
2. The five-tier re-tag plus `mythic` (packs §1–3); the four creature models
   move straight into mythic.
3. The cut list (§5a) and the tier nameplate (§4).

**Owns:** `blender/pig/**`, `docs/PIGGY-PACKS-PLAN.md`, `docs/PIGGY-SKIN-MAP.md`,
`ShopSkinCards.luau`, and Config's `RARITY_ORDER`/`SKINS` **by announcement to
Lane 2**.
**Watch:** a floor that EMPTIES a crate is caught loudly; a floor that PROMOTES
one is not caught at all. Walk every `Config.CHESTS` floor after the re-tag, by
hand, and write the audit while you are there.

### Lane 2 — ECONOMY §8: the re-derivation *(in flight)*
*The largest piece in the plan, and arithmetic rather than code.*

**The one change to how it is being done:** derive against the catalogue, not
against today's four tiers. Nothing it lands may need re-solving when Lane 1
re-tags. If a number cannot be derived, it is a designer decision and belongs in
the plan rather than in Config.

**The raid drain floor is FIXED — verified independently, `midnight` 26 → 30
checks and green.** It was the one item in this lane that needed no number from
anybody: a documented invariant that had silently stopped holding.
`drainIncomeMultiple` exists so a pile VISIBLY falls (*"a loss nobody can see is
indistinguishable from a broken feature"*) and it was multiplied by one pig's
`getIncomeRate` — measured on a mixed six-pedestal lawn at level 20, 2,995/s
against the lawn's 65,882/s, so **the floor sat 22.0x too low and the drain had
gone invisible again for exactly the reason that comment was written.** It reads
`Config.collectionRateOf` now, and it is a fix rather than a balance change
because `room = entry.cap - entry.held` still clamps the take: a higher floor
reaches the cap sooner and can never exceed it.

`incomeOf` deliberately SURVIVES for `payIncomeSeconds`, and the test pins BOTH
halves — that the drain reads the collection AND that exactly one caller still
reads a single pig. That is what stops somebody "finishing the job" by swapping
the second one, which is a pacing decision rather than a bug.

**VERIFIED LIVE, and it lands on the constant's own stated intent rather than
merely being bigger.** `Config.RAID`'s comment says *"at 2.5 the pile visibly
falls at about 1.5x income"*. Measured through a real raid:

```
floor BEFORE:  32.94/s x 2.5 =   82/s  against income 725/s  ->  net -642/s
floor AFTER:  724.68/s x 2.5 = 1812/s  against income 725/s  ->  net +1087/s
(1812 - 725) / 725 = 1.50
```

The pile fell 53,789 → 49,486 — exactly 8.0% — and then went flat, which is
`room = cap - held` binding. Fires, takes, bounded: all three seen rather than
argued, and the fix restores the documented figure instead of overshooting it.

**A correction to the description above, made by the session that wrote it.**
"The drain had gone invisible" is loose. `want = max(cap * baseRate, floorRate)`,
so with the floor at 82/s against income of 725/s the FLOOR TERM was inert and
the drain ran on the flat term alone — it still took its cap. What had stopped
holding is the guarantee the floor exists to provide: **that the pile
out-drains income while the beam holds.**

**Two probe traps found here, and both will bite the next person.**

* **TWO THINGS THAT ANSWER TO ONE NAME — and this is the THIRD instance, which
  is when this project writes the rule down rather than the instance.** The
  others: `GuardCatalog[key].label` reads like the species and is the breed's
  GIVEN NAME for six of nine coats, while the species lives on the coat's
  `name`; and a house model carries four parts all called `Finial`, so
  `FindFirstChild` returned the same one four times. **The rule: when two fields
  or two parts could both answer "what is this called", hold the reference the
  builder returned and never look one back up by name.** `Config.RAID` and
  `Config.EVENTS.roster.raid` are the newest pair — `drainIncomeMultiple` is on the first; the roster row carries
  only `weight` and `seconds`. Reading it off the roster returns **nil**, which
  looks exactly like an edit that multiplied by nil and threw — trusting it
  would have meant "fixing" working code.
* **A FLAT PUBLISHED PILE IS THE NORMAL RESTING STATE NOW.** Under the
  collection pivot coins do not rise on their own: income fills BUFFERS and only
  a collect moves it across. `StateUpdate` is change-driven too, so an income
  figure read off it comes back **0** on a static pig. Two sampling passes were
  confounded by this before it was spotted.

Still in scope here: `SocialService.wantedFloor`,
which is still 60s of `getIncomeRate` and so swings the pursuit threshold ~8,000x
across the level range. `DailyService.coinValue` and
`EventService.payIncomeSeconds` are a 22x payout swing and are the designer's
call, not this lane's.

**Owns:** the Config regions above, `EconomyService.luau`, `tests/sim/**`, a new
`tests/luau/economy.luau`.

### Lane 3 — PHASE 2: the haul — **DONE, verified live 2026-09-21**
Take / snatch / place driven through the REAL prompts, clean boot, zero errors:
the carry penalty (16.00 → 12.00), the slot emptying and the prompt flipping to
PLACE, the shield dropping on a snatch, the five-second secure (counts down on
your own lawn, never on the victim's, resets the instant you step off, never
starts on a full lawn), the per-victim cooldown refusing with nothing taken, the
dog catch returning the piggy to its ORIGIN slot, a mid-carry disconnect doing
the same, and the ride refusal. A `piggystate` dev command reported "owned
matches standing" after four takes, two places, two sells, four snatches, two
secures, a dog catch and a disconnect — **nothing minted, nothing lost.**

**The prompt cards have been SEEN**, via the throwaway-clone trick, which
retires the longest-standing unverified item on this board. SELL and TAKE render
together on one plinth at billboard heights 82 and 270 — exactly `82 + 2 x 94`,
the slot arithmetic holding. The three new glyphs were render-measured the way
that table demands: PIG, GRAB and PIN all advance 37.0 against known-good
controls at 37.0 and known tofu boxes at 20.0.

`recordSteal` is WIRED: `SocialService.recordSteal(player, Config.piggyWorth(haul.key))`
fires on a SECURED snatch — at the secure and never at the grab, which is that
function's own rule (loot nabbed out of your hands was never stolen, you were
caught) and the same moment the coin path counts on. A resident counts exactly
as a player does.

**The interim coin caller at `HeistService:4318` deliberately STAYS**, and this
corrects an earlier reading of this file. It is still the live rap-sheet source
for CASH robbery, and cash robbery is still in the game. Deleting it now retires
nothing — it just makes coin robberies stop counting toward Most Wanted, the
weekly board and the patrol's target while they are still happening, which is
the "counting zero for everybody" failure `recordSteal`'s own note warns about,
pointed at the other source. **It goes in the same commit that retires cash
robbery, not before**, and that retirement is nobody's lane yet.

`PromptUI` and `PlotService` are DONE and released from this lane — `PlotService`
took exactly one line inside `setPiggySlots`.

### Lane 4 — `LOSS_CAP`'s piggy clause *(unclaimed — the gap between 2 and 3)*
`PIGGY_HAUL.victimCooldown` bounds one thief against one lawn; **nothing bounds
a street taking turns**, which is precisely the hole `LOSS_CAP` closes for coins.
And it is two curves at once: a cap on what a victim can lose AND the ceiling on
how fast anybody builds a collection by stealing — now the primary acquisition
route. `LOSS_CAP` x `HEIST_PAYOUT` is the canonical version of this failure in
`CLAUDE.md`, found months late. **Measure the product in the same pass as Lane 2,
not after it.** This is why it is its own lane and not a to-do inside either.

### Lane 5 — SUPPLY: re-derive the resident dial
*Built already — Lane 3 seeded resident lawns via `drawLawnPiggy`,
`RESIDENTS.piggyCount` and `piggyTopRarity`. The packs plan calls this the
single biggest dial on solo pacing, so what is left is the NUMBER.*

**The guard is already in, and it is stronger than the downward-only rule this
file first asked for.** `RESIDENTS.piggyTopRarity` is an ABSOLUTE cap the
street's level cannot reach at all — a neighbour's best piggy is that tier on
the first day and on the thousandth — rather than an offset below the street.
The draw filters on `Config.rarityRank(Config.rarityOf(spec)) <= cap` before
anything else and never reads a level, so there is no "rich street seeds
mythics" path to guard against. It ships at `rare`, and the piggies suite
asserts both that the cap names a real tier below legendary and that it is
actually holding something back rather than admitting the whole catalogue.

So this lane is **re-deriving that cap and `piggyCount` against §8**, not adding
a guard. Do it with Lane 2 rather than after it — resident lawns are the whole
solo supply, so their richness and the economy's idle/steal ratio are two curves
that multiply.

### Lane 6 — READOUTS: the lawn has to be readable from the pavement
*Found by the live photo pass, and it is costing an INCENTIVE rather than a
picture.*

Behind a Picket you see the top quarter of a piggy; behind the three climbed
tiers not one pedestal is visible. Raising the plinths is refused by the numbers
— it would put the display at the height where it occludes the plot piggy
itself. The answer this project has already used once is the ROB BADGE
publishing the figure: something on the badge saying what a lawn is carrying,
with the fence still hiding WHICH pieces.

*(The pedestal prompt cards were the other half of this lane and are now DONE —
seen, measured and retired under Lane 3.)*

**Owns:** `RobBadge.luau`, `PromptUI.luau` — note Lane 6b also wants `PromptUI`,
so those two coordinate or merge.

### Lane 6b — THE OWNER-GATED PROMPT RACE — **DONE, verified 18 of 23**

Mailbox and doorstep crate closed in `PlotService` only, copying the pedestal
fix's shape exactly: one `publish*` function per prompt owning BOTH the owner
attribute and `Enabled`, and a `bouncePrompt` that switches off, stamps a
generation, waits a real 0.2s frame, then RECOMPUTES — never remembers. Bounced
only when the plot changes hands, never on every daily push. `PromptUI` and
`PiggyPedestal` untouched.

**THE TILL PREMISE IN THIS LANE WAS STALE, AND THAT IS THE MORE USEFUL
FINDING.** This entry said the till's `CollectPrompt` was a prompt exposed to
the race while the six pedestals were pads. **There is no `CollectPrompt` on
the server at all.** The till's collect is a floor PAD too — `PiggyBank` builds
`CollectPad` under a designer-call comment that names the owner/`Enabled`
ordering problem as *the thing the conversion retired*. All SEVEN placements
collect by one mechanism, pad plus a server guard, and none is reachable by
the race because a Part has no per-client state for `PromptUI` to refuse.
**Deliberate, one mechanism, not drift.** The only stale trace is a comment in
`ClientMain` ~6699 still describing "a third prompt on this body" — reported,
not edited (shared 200-register chunk).

**And the two fixed sites were structurally LESS exposed than the pedestals
ever were.** `PromptUI.ownerRule` refuses only when the attribute is NON-NIL
and not the reader. A plinth publishes `0` for an unowned lawn — refused
everywhere — while the mailbox and crate publish `nil`, which is left alone. So
the measured poison path (client applies `Enabled = true`, reads a stale `0`)
meets `nil` on these two and does not refuse. The fix stands anyway: the plan
asked for it, the ordering rule now lives in one function, and it guards
against any future non-nil "nobody" value. `nil` must stay `nil` —
`MailCall.waiting` compares it against the reader.

Live-only: that a bounce after a change of hands actually re-arms a client
holding a stale refusal (proven on pedestals, reasoned here), and whether these
two can be poisoned at all given nil-vs-0.

*The original brief, kept for the reasoning:*

**"Write the owner before you enable" is necessary and NOT sufficient**, and the
build order records that earlier fix as done. The hole is `PromptUI`'s ONE-TIME
SWEEP: it walks every prompt in the world once at startup and refuses anything
whose owner is not the reader. If that sweep lands between the `Enabled`
replication and the OWNER replication for a given instance, it refuses a prompt
the reader OWNS — and its rules may only ever refuse, so **nothing ever takes it
back.**

Measured live: three of six SELL prompts locally `Enabled = false` on a plot
whose owner attribute read correctly on BOTH sides, server `Enabled = true`. A
player could not sell half their own collection, with no error anywhere.
Bouncing those three across a frame from the server fixed all three, which is
what confirmed the diagnosis rather than a reading of the code.

Fixed on the pedestals by `PiggyPedestal.republish` — switch all four prompts
off, and a fifth of a second later RECOMPUTE them from `refs.key` and the owner
rather than remembering, so a piggy sold or snatched during the beat is answered
correctly, with a generation stamp so a later republish wins. `setHaul` now owns
the owner attribute AND `Enabled` for all four prompts, **so the ordering rule is
a property of one function rather than of the distance between two loops** —
which is the shape any fix here should take.

**Two sites are still exposed, and they are the same shape.** Swept for
`PROMPT_OWNER_ATTRIBUTE`: the MAILBOX (`PlotService:3202`) and the DOORSTEP
CRATE (`PlotService:3266`) each set the owner in a function separate from
wherever `Enabled` is written — the exact distance-between-two-loops the fix
above closes. The till's own `CollectPrompt` is owner-gated too and wants
checking.

**Severity, stated plainly so nobody over-reads it:** the server re-checks the
owner on both (*"the client refuses... which is a courtesy"*, *"THIS is the
check that is authoritative"*), and `PiggyHaulService` re-reads the plot, the
slot and the reach on every trigger regardless of what any client thinks is
enabled. **So this is not an exploit** — it is a player silently locked out of
their OWN control, never a player reaching somebody else's. Size it as the
silent-failure rule, not as a security fix.

**And there is a second question under the till's `CollectPrompt`.** Collect on
a PEDESTAL is a floor PAD now rather than a prompt, and a pad carries no owner
attribute and cannot be refused per client at all — it is guarded purely
server-side in `EconomyService.collectPiggy`. So the till and the six pedestals
answer "who may collect" by two different mechanisms, and only one of them is
exposed to this race. **Whoever takes this lane decides whether that is
deliberate or drift**; it is not obviously either.

### Lane 7 — Stage 2 pedestal guards
Small and almost entirely reuse: the leash, the driveway stop and the chase loop
all exist. One trigger into `GuardDog.chase` on an active pedestal steal, plus a
slower-than-carry-speed profile. **Owns:** `GuardDog.luau` only.

### Lane 8 — Stage 3 roaming herds
Fully independent and now PROMOTED: a herd that hands over the piggy you caught
is a primary supply route rather than a crate dispenser, and it needs Stage 1's
placement path, which now exists. Genuinely new NPC movement — the one piece
here that is not a reskin of something shipped.

### Lane 9 — Job board (§7a)
Retirement shipped ahead of this, so the Crates tab is award-only and the faucet
is thinner than the plan intends. Independent of everything above.

---

## THE NPC PIVOT — measured, and it needs one more answer before anyone builds

Designer direction, 2026-09-21: **resident lawns carry only low-tier piggies**,
and the intent is **zero NPCs on plots, with NPCs only at the shops**.

**There is a conflict inside those two and they cannot both apply to plots.**
The first sets a dial on resident LAWNS; the second deletes resident lawns. A
shop has a VAULT OF COINS, not a lawn of pedestals. So either the first is about
a shop-resident concept that does not exist yet, or the second supersedes it.
That is one question, not two decisions, and it is the thing to settle first.

**Measured through the real `robberyRates`, level 20, houses = 0, shops =
`SHOP_COUNT`:**

| players | today cold / hot | shops only cold / hot |
| --- | --- | --- |
| 1 | 3.63x / 7.25x | **2.75x** / 5.51x |
| 4 | 3.53x / 7.05x | **2.75x** / 5.51x |
| 8 | 3.21x / 6.42x | **2.75x** / 5.51x |

`ROBBERY_ADVANTAGE.min` is 3.00x. **Coin robbing goes under the floor at EVERY
population, not just at eight players** — so this is not a full-server problem,
it is a permanent one.

Three further consequences in that table:

* **The ratio goes FLAT**, because supply stops depending on population at all.
  `auditRobbery`'s population sweep — written after the pre-tills collapse
  specifically to catch supply-as-a-function-of-population — becomes a sweep
  over a constant and **can no longer see anything.**
* **Thieves become lap-bound rather than cooldown-bound**: four targets lap in
  89.0s against a 60s per-victim cooldown, where today's six lap in 133.5s.
* **The piggy half has no number because it has no supply.** 27 stealable
  piggies at one player today, 6 at eight, and **zero** from non-players with
  residents off the plots. Cash robbery is also going, so piggy theft is
  player-versus-player — which means a solo player, or the first two into a
  server, have nothing to steal at all. That is the exact sentence `CLAUDE.md`
  uses about why residents were invented, arriving on the mechanic the whole
  game is being rebuilt around.

**`Config.RESIDENT_FLOOR` is `SHOP_COUNT + max(0, PLOT_COUNT - MAX_PLAYERS)`**,
verified on disk as `SHOP_COUNT + 2` against `PLOTS_PER_ROW 5 / PLOT_COUNT 10 /
MAX_PLAYERS 8`. Zero NPCs on plots takes the floor from six to four — and
`PLOTS_PER_ROW` went 4 → 5 specifically to buy those two. The pivot reverts a
change whose reasoning is on record.

**None of this argues against the direction**, which may well be right if shop
piggies become the PvE route. It says the number that justified six is on
record and the new shape needs its own. **Stage 3 herds stop being optional and
become the thing carrying the floor**, and `auditRobbery`'s denominator has to
become herds plus shops before this ships — which cannot be written yet, because
auditing against a target class with no implementation is a number somebody
invented.

---

## LANDED AND VERIFIED LIVE, 2026-09-21 (late session)

**HERDS ROUND 2 -- FIVE PACKS OF TEN, DIGGING, PONDS (designer asks ~21:15;
three lanes landed and verified live ~21:55).** Sweep 24 of 25 green
(`houses` known), scanner clean, boot clean. Live: 50 `HerdPiggy` models =
200 parts, five packs, 124 dig stamps in the first minutes, five digging at
once; the tracked pack showed the dig pose within cull range (pitch -18 to
+9, 0.25-stud hop, +-6 roll, coin pool used) and NOTHING outside it -- the
first sample was on a pack that had walked past `PIGGY_WALK.far` and read
zero, which is the cull working, not the pose failing. Ponds photographed:
WATER READS AS WATER at 20 studs (bank/bed/surface layers kept), a ring of
rocks at 60; flowers read as dots; the far ponds sit against the valley wall.
So: `HERDS.edgeMargin` 20 -> 45 (band ended at 280, INSIDE the wall's
columns from 270 -- caught by the grassland lane measuring the wall for its
own ponds), and a DENSITY PASS sent back to the grassland lane (budget 900,
3 ponds a side r 10-14, drifts of 6-9 with 0.45-0.6 heads, bushes, more
rocks; its files only). The herd lane's cadence: lifetime ~259 s per pack,
five cap slots -> mean 4.9 loose, a pack enters every ~55 s = ~11 catchable
piggies a minute -- **that is the supply number HERDS-PLAN §3 says the tier
table has to be weighed against, and nobody has weighed it yet.** Members
are born single-file inside the east/west hill and walk out along the kerb
line at |z| 8.5 in an 11-half-width bore, so they cannot touch the headwall
(arithmetic, not a photo -- the tracker aimed at the midpoint of two packs
sharing a reused HerdId and shot empty grass). **TREES LANE in flight
(~21:50): trunk colliders on every tree (CanCollide true, CanQuery false,
canopies stay walkable-under) plus a herd veto, NeighborhoodService.buildTrees
+ one Main line + `Config.TREES` before `Config.GRASSLAND`.** Designer ask:
"real impassable trees so players and the piggies have to walk around them"
-- this reverses the recorded "hills are the only scenery that collides".

**EVERY SPEED IS A RATIO OF `BASE_WALK_SPEED` NOW, AND THE BASE IS 20
(designer decision 2026-09-22 ~01:00; landed and measured live ~01:40).**
Phase 1 converted the ten remaining absolutes (car 34 = 2.125, shopkeeper
via officerSpeed, neighbour chase 11, resident stroll/carry/potter 9/7/3.5,
THROW fallback 60, the van 20, and `HOUSE_DOOR.maxStep` 40 = 2.5 -- the one
the survey missed and the `doors` suite found: it sat EXACTLY on its own
audit line at a base of 20) with the base at 16 and PROVED IDENTITY: 5,904
Config leaves and 64 derived speed/cycle/cruise fields byte-identical, every
suite at identical counts. New `tests/luau/speeds.luau` (124) pins every
ratio and the load-bearing orderings at bases 12, 16 and 20 so a future base
change cannot invert one silently. Phase 2 raised the base: 27 of 28 green.
LIVE: `Humanoid.WalkSpeed` 20.0, 40.0 studs in 2.0 s on open grass, a pack at
8.06 against a derived 8.00; officer 18.125, car 42.5, carry 15, dogs
15..26.25, tiptoe 7..12, max ride 42. (First boot read 16 -- Rojo had not
pushed before Play; and a street run measures the auto-mounted RIDE, not the
walk -- 33 studs/s -- so walking is measured on grass.) CONSEQUENCES,
MEASURED AND NOT RETUNED: robbery cold/hot 3.21x/6.42x -> 3.47x/6.95x, no
new audit warning; patrol cruise 3 legs -> 5 (forced odd), 41.6 -> 55.5 s
against `POLICE.patrol` 45, so a patrol is 14 s LONGER in wall time; getaway
5.0 -> 4.0 s; the officer closes 25% more ground in a chase; herds enter a
pack every 52 s; PiggyWalk 4.0 steps/s; ZAPPER drop over range shrinks 36%
while the plunger/gum (sqrt(range x gravity)) are unchanged, so leads grow --
designer's call whether `THROW.gravity` scales (base/16)^2. Left as
distances/angles on purpose: knockback, sprinkler, bin hop, trampoline,
stance turn rate, throw gravity. Stale prose quoting 16/12/14.5 remains in
CLAUDE.md and several service headers.

**THE OFFICER PATHFINDS NOW, AND THE FOLLOWER IS A MODULE FOR THE NEXT
THREE MOVERS (designer decision ~23:30, landed and verified live ~00:10).**
`Shared/PathFollower.luau` requires nothing, takes a spec table
(`Config.POLICE.path`: agentRadius 2 and agentHeight 6.2 measured off
`PoliceModel.buildOfficer`, replanDistance 4, replanSeconds 0.4,
maxWaypoints 64, waypointReach 1.0, Costs.Water = huge), computes in a task
so the frame loop never yields, follows the last good path while a new one
lands, replans on goal drift / `Blocked` / a truncated path, and FALLS BACK
TO THE STRAIGHT LINE on NoPath or a throw -- counted, one warn per pursuit,
never a freeze. PoliceService's chase and return walks call
`follower:step(at, dt, officerSpeed)` and keep their own Y, stride, pose and
catch test. Ponds carry a `PathfindingModifier` (Label Water, PassThrough
false) on the non-colliding water. Every fence tier's gate clears 2 x
agentRadius (Moat 8 vs 4). Designer's follow-on: "then we can use that same
system for NPCs or guard pets" -- residents, guard dogs and HERD LEADERS are
the intended next callers, each with its own spec; not wired.

LIVE, TWO CHASES THROUGH THE REAL F2 PANEL (`police` then `bust`; a bust
with no patrol out is refused, which cost one attempt): (1) thief behind the
verge trunk at (-141, -19): the officer left the road at (-132, -4), passed
the trunk at a minimum of 4.0 studs from its axis, caught at 6.3, held, and
walked back the same way. (2) thief in the back corner of a fenced plot: the
officer crossed the front fence line at x -167, INSIDE the gate's -169..-151,
cut across the yard to the corner, held, and left through the gate again.
Zero fallback lines. **THE POND MODIFIER IS NOT HONOURED, MEASURED**: a
path across pond P1 with `Costs.Water = math.huge` ran 1.0 stud from the
pond's centre, same as with no costs; a 26 x 6 x 26 NON-colliding box with a
Water modifier changed nothing at +2 / +4 / +8 s; the same box made
CanCollide TRUE routed the path 16.1 studs round. On this pipeline a
`PathfindingModifier` on a script-built non-colliding part does nothing,
however tall; only colliding geometry is an obstacle. Fix sent back: the
pond RIM STONES collide (the trunk colliders' flag set), the modifier and
the cost row come out, and the suite pins the ring gap under 2 x
agentRadius. **A MECHANISM THE DOCS SAY WORKS IS NOT A MECHANISM UNTIL A
PATH HAS BEEN COMPUTED THROUGH IT.** AND THE COLLIDING RIM WAS NOT ENOUGH
EITHER: with all 134 stones CanCollide true, every pond was still crossed
dead centre at +16 s after boot -- a 1.6-stud-proud ball is a STEP to the
navmesh -- while 24 invisible 7.5-stud colliding cylinders on the rim routed
the path 19.1 studs round within 4 s. The verge-trunk lesson one more time:
a barrier has to beat the mover's step, not merely exist. FIXED AND
VERIFIED LIVE (~00:45): one invisible colliding column per rim stone (134),
top = ground + jumpReach + `GRASSLAND.rimJumpMargin` 1.0 = 7.14, the trunk
colliders' own rule; widest column gap 1.13 against an agent 4.0 wide; parts
781 of 900. Fresh boot, all six ponds: paths routed round at 15.9-18.2 from
centre. A pond is impassable to PLAYERS too now -- nobody hops the rocks --
which is consistent with the ask and removes the wade case. The police
lane is closed: `police` 107,647, `pathfollower` 465, `grassland` 3,185. **Measured worst detour (suite, built geometry): 2.83 s
on an alarm pursuit and 3.70 s on a sight pursuit, both a Moat plot's front
corner, against the 30 s chase -- not retuned, recorded.** Not fixed: the
return walk's 5 s cap can now be exceeded from deep in a yard (officer
vanishes mid-walk, pre-existing); the MOAT WATER carries no modifier
(PlotService), so an officer wades a moat on its path.

**TREES LANDED, AND THE FIRST LIVE WALK WENT OVER THE TOP OF ONE (~22:50).**
54 trees, 54 invisible trunk colliders (upright cylinders, CanCollide true,
CanQuery false, radius 0.35 of the trunk box read in the part's own frame,
top at the canopy underside), a herd veto through `addGroundVeto`, one verge
tree slid off the herd corridor, and every spawn, door exit, bin, forecourt
and board measured clear -- `trees` 7,984 checks. Live: the collider
COLLIDES (auto-jump off, the character stops 1.27 studs from the centre; a
dropped probe topples off the disc), but with the client's default
`AutoJumpEnabled` -- touch controls, most of this audience -- the character
hit a verge trunk, rose to y 8.6 and walked off the far side. A verge
collider topping out at 4.9 is INSIDE `Config.jumpReach` (6.14), so it is a
step. The fence entry already says what a barrier has to beat, and the fix
sent back is the fence's own rule: collider top >= ground + jumpReach +
margin, derived, running up into the canopy where a bole-wide column can hit
nothing a player can reach. Grove colliders at 10-13 are already over it.
**FIXED AND RE-WALKED (~23:20): collider top = max(canopy underside,
ground + jumpReach + `TREES.jumpMargin` 1.0) = 7.14 on the verge trees,
unchanged on the grove; the suite's floor check proven to fire at a
negative margin.** With auto-jump ON the character hit the verge trunk at
x -139, jumped three times to a root peak of 6.2 (a root standing on the
7.14 column would read ~10), fell back, slid two studs sideways round the
column and carried on -- min distance from the trunk axis 1.30 -- which is
"walk around it". Beside the trunk under the canopy edge: no jump, straight
through. Lane closed. `trees` 7,986. Sweep 25 of 26.
**A PROBE THAT REPORTS "WALKED THROUGH" NEEDS THE CHARACTER'S Y**: the first
sample read min distance 0.01 and looked like no collision at all; the 0.2 s
samples showed the hop. Also flagged, not fixed: `PoliceService` poses the
officer by CFrame, so it walks through a verge trunk visually (unclaimed).
And one stray latin-1 0xA7 in a Config comment (session 83's patch script,
Python default codepage) took the runner and the scanner down for every
suite; repaired in place, 83 now writes UTF-8 explicitly and made the scanner
decode tolerant.

**GRASSLAND DENSITY PASS, PHOTOGRAPHED (~22:20): READS.** Six ponds (r 12 /
10 / 10 a side), 623 parts of a 900 budget, zero coplanar pairs. From 40
studs on the plot side: a pond with lily pads and reeds in a boulder ring,
a flower drift (green mound with 6-9 nestled 0.5 heads) reading as a patch of
colour, a bush and a fallen log for silhouette, open water BETWEEN the row-1
trunks rather than under them -- the 3.2-stud canopy clearance the lane
could not raise is a plan-view number for leaves 20 studs up and is not
visible. Two asks not met, both for measured reasons and both accepted:
rims cannot clear canopy reach by 8 anywhere inside the safe band (the grove
leaves no such spot), and 2.5x two-part flower clusters did not fit 900
parts -- mound-and-heads puts 4.3x the heads on the ground instead (274 vs
64). Lane closed. If ponds still read rock-heavy from far off the lever is
`stoneRadius` / `stonePitch` in Grassland.luau, not the water.

**THE COLLECT HOP FIRED ONCE AND THEN NOT AGAIN UNTIL THE PLAYER STOPPED
(designer report, ~21:10; fixed and verified live by the coordinator).**
`PiggyIdle` hopped off `Sound.Played` on the pad's `PadCollect`, on the
recorded argument that a server `Play()` replicates and needs no attribute.
It replicates a PROPERTY, and `Played` on a client is the false -> true edge
of `Playing`. The server plays the 4.1s clip on every collect, so a collect
inside the previous clip changed nothing that replicates -- **measured: server
plays at t, t+1, t+6 reached the client as two `Played`s, the middle one
lost.** A player pacing over a pad kept restarting the server's clip and saw
one hop until they stopped for longer than the clip, which read as "only
after 30+ seconds". Fix: `PiggyPedestal.playPadCollect` increments
`PiggyPedestal.COLLECT_ATTRIBUTE` on the pad (a counter, never a flag) and
`PiggyIdle` hops AND restarts the sound locally off that change. Verified:
seven crossings at ~1.7s -> 6 counter changes, 6 plays, 0.82-stud hop each.
`piggies` 455 with the wiring pinned. **A REPLICATED `Play()` IS NOT AN
EVENT; anything reacting to a server-played sound on a client wants a
counter beside it.** Wants a CLAUDE.md post-mortem (designer's file; not
edited here) -- add to the stale-gotchas list.

**THREE MORE LANDINGS, VERIFIED BY THE COORDINATOR IN ONE PLAY SESSION
(~20:50).** Sweep after all three: **23 of 24 suites green** (`houses` on
its known baseline), scanner clean, server boots with no errors.

* **THE HALLWAY, PASS 3.** Vault heights across the half-width now read
  21.3 / 20.7 / 19.9 / 18.1 / 16.3 / 13.7 / 12.4 -- monotonic, one arch,
  photographed with no sky anywhere in the frame. Zero PointLights, one Neon
  part, 445 parts on this save. The stone reads as a mid blue-grey under the
  sun (the blue is the ambient; the authored value is warm-neutral), the
  fixtures read as unlit fixtures, the far wall reads. `interior` 201 with
  the facet-tangent and monotonic-ceiling checks, both proven to fire on the
  old sign. Lane closed.
* **THE CAPACITY CEILING.** Every retired name reads nil live
  (`getCapacity`, `fitInPig`, `pigRoom`, `getCapacityCost`,
  `UPGRADE_COST_CEILING`, `BASE_CAPACITY`, `REBIRTH_CAPACITY_MULTIPLE`);
  `REBIRTH_CASH_GATE[0]` = 2,988,151 and `pigFullAt(0)` agrees;
  `rebirthPiggyGate` returns true (placeholder). The pig came in at 358.5K
  against 73.8K on the previous boot -- **that is the uncapped 8-hour
  offline payout, change 7 in the agent's list, and the designer should see
  that number before deciding whether to keep it.** Full behaviour list is
  in the agent's report (13 items); the two report-only flags stand:
  `LOSS_CAP` and `getStealFraction` are shares of an unbounded pig, and the
  17-day climb / `tests/sim/late-game/` are void. **Seen live in the same
  session: a resident robbed the player and the pig went 358.5K -> 286.8K
  in about a minute.** That is the safety flag with a number on it.
* **THE HERD WADDLE (shape B, no upload).** `Config.HERD_WALK_ATTRIBUTE`
  advances on the server at the pack's own pace (261.8 -> 268.2 studs in
  1 s). With the CAMERA within `PIGGY_WALK.far` (140) the client poses the
  body: bob 0.038 studs, pitch -2.0..+1.1, roll +-5.8, trim riding with it;
  with the camera 4,000 studs away it correctly does nothing. **THE CULL IS
  CAMERA DISTANCE, NOT CHARACTER DISTANCE** -- the first sample was taken
  with the character 6 studs from the pack and the camera still in the hall,
  and read zero. Photographed at 12 studs: a five-strong pack walking, roll
  visible between consecutive frames. Not seen: whether 3.2 steps/s reads as
  a waddle or a shiver from the pavement at 40 studs -- that is the
  designer's eye. Skeletal route (A) is prepared as an FBX with a checklist
  and NOT uploaded. `walk` 466.

**THE FRONT DOOR WORKS, BOTH WAYS, AND IT TOOK TWO LIVE BUGS TO GET THERE —
neither of which 61 offline checks and a full stubbed walkthrough could see.**
Walked a real character at a real cottage door: mask went opaque, arrived at the
hallway's own entrance (4006, 3.2, −2000). Walked back at the end wall: landed
on the house's authored `Mount_Door_Exit` to the stud on Z, standing on the
doorstep, **facing the street** — which is the designer's "exiting spawns you
right back outside your front door", verified.

* **Bug 1 — `Config.crossedDoorway` refused every real crossing.** It opened
  with `type(from) ~= "table"`. In the engine `type(Vector3)` is `"vector"`; in
  `tests/run-crates.py`'s prelude, `Vector3.new` is stubbed as a plain TABLE. A
  guard written against the stub passed everything offline and refused
  everything live. `RegisterKeyframeSequence` exactly: proven in the one
  environment that is not the game. **The runner's stub makes `type()` lie about
  Vector3, CFrame and Color3 alike — any type guard on those in Config is
  untestable offline in the direction that matters.** The cheap mitigation is
  the one `piggyPedestalYaw` took: write pure geometry on components (`toX,
  toZ`) without constructing a Roblox value, so the two environments agree by
  construction. Swept the rest of `src`: this was the only such guard.
* **Bug 2 — the indoors flag was cleared before the character arrived.**
  `goInside` sets `inside[player]` at once but moves the character `maskLead`
  (0.12s) later under the mask, and `stepPlayer`'s self-healing box check runs
  BEFORE the latch test — so for two or three ticks the character was provably
  not in the hallway and the flag was cleared. Arrival then happened with
  `inside = nil`, every later tick tested the LAWN door four thousand studs away,
  and the exit could never fire. The self-heal now yields during the crossing
  latch, which already names the window.

**THE HALLWAY, PHOTOGRAPHED FROM INSIDE: BLACK WITH NEON EDGES.** An enclosed
box off-map gets no outdoor ambient, so only the Neon parts render — purple
floor and ceiling strips, a yellow neon cone at the light — and the walls,
vault and six floor plots are pure black. The dress derived a neon house's
palette into a saturated purple room. It answers the builder's own open
question, badly, and the rework brief (below) leads with it: real interior
lights, a neutral stone base with the house as ACCENT only, quiet trim, and
only the portal allowed to glow.

**THE HERD IS LIVE.** The scheduler put a four-member pack on the street on its
own 30s after boot: measured moving at 6.4 studs/s (`0.4 x BASE_WALK_SPEED`
exactly), holding formation within ~8 studs, in the grass band behind the far
row, each carrying an enabled "Catch Piggy" prompt of the pedestal TAKE kind.
Photographed: four pet-sized piggies — two neon, a gold, a pearl — walking
together against the earth bank. Reads as a herd. Not yet driven: the catch
itself, the tunnel entry/exit on real geometry, and the prompt card in range.

**THE MIDNIGHT HEIST IS RETIRED**, cleanly, across ten files, with the same-word
skins and names deliberately left alone. One finding for the designer: **Rush
Hour was already gone**, so the event roster is now ONE row — every event is an
Alien Invasion every `EVENTS.period` (15 min), the damped picker is inert until a
second row is authored, and it stays because the herd roster reads the same
function. `WorldService.DAY` survives as the boot's own day table.

**THE FORWARD-REFERENCE SCANNER EXISTS** at `tools/check_config_forward_refs.py`
— proven to fire on an injected reference at the exact line the Luau CLI throws
on, proven clean on the real file, and it reads 437-439 load-scope fields (the
door agent's "219" was a first draft that a top-level `for` swallowed; corrected
and cross-checked against grep).

**THE FOUR PRE-EXISTING RED SUITES ARE GREEN**, tests only, no source touched.
Two things found on the way: the home shop's vault drops NOTHING today (its
pool is the retired lawn catalogue, chance forced to 0, honest "ITEM 0%" on the
card) — a design question for whoever owns shop drops, not a test matter; and
tiptoe is now ALLOWED while carrying (`GAME.md:986`), which the `handoff`
suite had been asserting the old way.

**Lane 6b is done** (above), with its premise corrected.

---

**THE PORTAL IS ON THE HOUSE DOOR AND READS AS ONE.** Wired in `doorGate`'s
cache-miss branch so it is built once per house instance and dies with the
model: seated on the LEAF LINE (not the anchor) so the crossing plane sits
inside the glow, height read off the art's door leaf (10.46 on the cottage),
deep amber Neon, non-colliding, tagged and pulsing. Photographed from the
lawn: an amber slab filling the doorway that could only mean "step through";
hot at the centre under the bloom but holding its hue rather than blowing to
white, which is the test. Exit still lands on the doorstep facing the street
against the reworked geometry.

**THE REWORK OVERSHOT: FROM BLACK TO WHITE-OUT, AND THE DIAGNOSIS IS A RULE.**
Structure is right — vault facets, ribs, raised side platforms, six door
labels read live ("Need 1 / 3 / 6 / 8 / 10 / 13 Rebirths"), exactly one Neon
part — but every surface blew to white. **Every part in this repo is
`CastShadow = false`, so a ROOF DOES NOT BLOCK THE SUN**: an "enclosed" room
off-map has full daylight inside it. The morning's hallway was black because
its WALLS were near-black (a neon house's palette), not because it was unlit;
the rework painted them pale, added fifteen PointLights, and everything
cleared the 1.7 bloom bar — the shopfront white-out entry exactly. Sent back
as a colour-and-light pass: lights to near nothing, stone to a mid-tone
grey-blue, the picture as the only instrument.

**Second designer ask, queued to the same agent (same file — a second agent
there is the collision this whole exercise exists to prevent): DOORWAYS BIG
ENOUGH TO SEE THE PIGGIES ALL THE WAY DOWN THE HALL** once rooms are unlocked.
That is a sightline requirement, and it decides the geometry: the piggies
stand on the raised SIDE platforms, so a 10-wide opening on the lane can never
show them — an open doorway has to clear nearly the whole cross-section, a
locked one must still block the full width including over the platforms, and
open leaves must retract rather than swing (17-stud slabs standing along the
platforms would hide the very piggies this is for). A numeric sightline check
goes in the suite, since it cannot be seen offline.

---

## Designer rework brief — the hallway, against a reference image

The reference is a single WIDE vaulted hall, ~3x the current 8-stud lane: pale
grey-blue stone tiles with grout lines, a rounded vault with darker ribs every
~12-16 studs and a hanging light under the ridge, a broad central lane, and the
displayed pets on RAISED side platforms with a floating NAME / +rate / TIER
label over each. At the far end, centred, a doorway whose face reads what it
needs — "Need 2 Rebirths" — so the gate SAYS its cost. Shop stalls line the
walls (Stage 5; leave bays, build nothing). Three asks, sent to the builder:
BIGGER to those proportions; a PORTAL — deep saturated amber Neon, never pale
yellow — filling both the hallway exit and the house door, non-colliding, built
as an exported `buildPortal` helper for `InteriorService` to seat; and exit
landing on the doorstep, which is already true. Contract to preserve:
`entrance`, `origin`, `Door_Exit`, `Mount_Wall`, `footprint()` — and the
101.5-stud estate pitch if the footprint's width grows past ~80.

**REWORK PASS 2, PHOTOGRAPHED LIVE (coordinator, 2026-09-21).** The wide
arches and the sink-into-the-floor leaves WORK: from the entrance eye the hall
reads to the far wall with every pad on both platforms in view, twelve leaves
open on the dev save and none visible. Three findings, sent back to the
builder as a brief:

* **THE VAULT IS A SAWTOOTH, AND THE SKY SHOWS THROUGH IT.** Every facet sits
  at the right point on the arc and tilts the WRONG way:
  `CFrame.Angles(-phi, 0, 0)` in `buildVault` and `buildRib` must be `+phi`
  (rotating about X by `a` puts the width axis at `(z = cos a, y = -sin a)`,
  and the arc tangent at `phi` is `(cos phi, -sin phi)`). Measured across the
  hall with vertical rays: 20.2 at the ridge, 17.5, then a DIP to 12.6 at
  z ±15 and back UP to 16.6 at the wall. 126 of 490 slanted rays from the
  entrance eye leave the building through the wedge gaps between adjacent
  facets. **Neither the builder's checks nor mine could see it from below**:
  a straight-up ray stops on the first top face it meets, and the sightline
  suite traces plot lines that never cross the roof. Found by painting the
  three facet pairs red / green / yellow and photographing -- sky wedges
  between every pair, widest near the camera. The material was cleared first
  (Plastic for SmoothPlastic, live: identical picture), which is the order
  worth keeping: **an enclosed volume gets an oblique-ray sweep from where a
  player stands, not a vertical one from the floor.**
* **The 15 PointLights at 0.3 / 22 read as nothing** -- flat grey floor under
  every fixture. Delete them; the geometry stays.
* **Stone is still pale blue.** The 2.4 sun plus the blue ambients lift and
  cool every flat face. Another ~15% down AND the blue channel pulled in,
  so the authored value is warm-neutral and the ambient adds the blue back.
  `Lighting` is WorldService's and is not the lever.

Also measured on this save: 445 parts, 15 fixtures, 12 door-label guis --
fewer rooms than the builder's 10-room ceiling, as expected.

---

## Decisions MADE, 2026-09-21

**SPEEDS ARE DERIVED FROM `BASE_WALK_SPEED` — LANDED, and verified a true
no-op by two sessions (17 of 22, same five red, `audits` 193).** The five
`DOG_TIERS.speed` values and `POLICE.officerSpeed` are fractions of base
(0.75 / 0.90625 / 1.0625 / 1.1875 / 1.3125, officer 0.90625), each reproducing
its exact shipped value at base 16. The ordering now holds at 18, 20, 24 and 32
by construction, because both sides are pure ratios.

**Why it was needed:** there is ONE live dog (`Config.DOG_LEVEL = 2`, Rex at
14.5) and the officer at 14.5, against a carrying thief at `base * 0.75` = 12.
Raised to base 20 with those pinned, carry becomes **15 — faster than both** and
every chase is unwinnable, with nothing erroring.

**TWO CLAUSES THE INVARIANT NEEDS, so it is not read as covering more than it
does:**

* **It beats an UNBOOSTED carrier only.** `getCarryMultiplier` caps at 1.0, so
  a thief with maxed Speed Boots carries at BASE and outruns a 0.90625 officer
  at any base. That is the documented gadget problem — the exact reason gadgets
  exist — and the ratio move preserves it unchanged rather than fixing or
  worsening it.
* **The Terrier is EXACTLY carry speed at every base**, both being 0.75. That
  is faithful to what shipped and it is a TIE rather than a margin: a Terrier
  can never close on a carrying thief with a head start, only catch one it is
  already beside. Presumably intended for the gentlest catcher in the game, but
  a future coat or carry tweak could invert it with nothing erroring.

**TWO `CLAUDE.md` GOTCHAS ARE STALE, and both cost time today.** Neither is
fixed here — that file is not edited on a peer's or an agent's say-so, and it
carries the two-sessions-one-rewrite hazard. Both are with their owners:

1. **`Config.luau`'s line endings have flipped twice today and the record
   cannot be trusted for it -- MEASURE BEFORE PATCHING.** It was CRLF for
   most of the day (two sessions had a multi-line patch match zero
   occurrences for that reason), and by 20:27 it was LF again after the
   capacity lane's read-modify-write; `file` reports plain LF now, and
   `core.autocrlf=true` means git normalises either way. The gotcha in
   CLAUDE.md naming ClientMain and Config as "the LF files" is right at this
   minute and was wrong an hour ago. Run `file` on it first, every time.
2. **The per-tier `notice` speed threshold is RETIRED and the record still
   describes it as live.** `CLAUDE.md` states the ordering *"TIPTOE at max
   (9.6) < a dog's notice < CARRY_SPEED (12)"* and quotes Scruffy at 11 and Rex
   at 10.2. **There is no `notice` field in `DOG_TIERS` at all.**
   `GuardDog.isAwake`'s comment says what replaced it and why: a speed threshold
   measured off position deltas sat 0.6 studs/sec above a maxed carry-sneak,
   which network jitter could cross on its own. **Sneaking is about NOISE now**
   — a walk, a fumbled slice, a smash — and a tiptoe is never noise, so tiptoe
   has no speed ceiling and raising base cannot break it. This is the `gable()`
   class exactly: a confident sentence in the record describing a system that
   has since been replaced, and it produced a confident wrong warning before
   anybody checked the code.

**FIVE TIERS, AND INCOME IS A RANGE PER TIER RATHER THAN ONE NUMBER.** The
ladder is `common, rare, epic, legendary, mythic`, and each tier carries a BAND
of income rather than a single multiplier, so two skins of the same tier need
not earn the same per second. Some may coincide; the point is that the band is
used. `Config.PIGGY_RARITY_INCOME` is a flat map today
(`common 1 / rare 4 / epic 8 / legendary 15`, no mythic) and becomes a band per
tier.

**Two things fall out of it that want deciding before it is typed:**

1. **ANSWERED: THE BANDS DO NOT OVERLAP.** Every band's floor sits above the
   previous band's ceiling, so the tier remains a true ranking and "the tier IS
   the income" stays literally true — which is what the nameplate's tier colour
   will be telling players. `auditEconomy`'s existing check ("a tier whose
   multiplier does not beat the one below it") becomes a BAND ORDERING check:
   refuse any band whose floor is at or below the previous band's ceiling.
   Cheap, and it makes the guarantee structural rather than remembered.

   The original question, kept for the reasoning: may the bands OVERLAP? If
   rare's top reaches epic's bottom, a top rare
   out-earns a bottom epic and "the tier IS the income" stops being true — which
   is the sentence the whole rarity ladder currently rests on, and what the
   nameplate will be telling players. Non-overlapping bands keep the ladder
   honest and cost some expressive range; overlapping bands are richer and make
   tier a rough signal rather than a promise. **This is the one real decision
   in the change.** Note `auditEconomy` already refuses a tier whose multiplier
   does not beat the one below it — with bands, that check becomes a band
   ORDERING check and has to be rewritten either way.
2. **ANSWERED: DERIVED ONLY, NO PER-SKIN OVERRIDE.**

   **AND THAT MAKES THE DERIVATION LOAD-BEARING RATHER THAN A CONVENIENCE.**
   With no override, whatever spreads a skin across its band is the ONLY thing
   deciding its rate — so if the derivation returns the band's midpoint, or
   anything else uniform, **every skin in a tier earns the same and the bands
   have collapsed back into the single multipliers they replaced.** That is the
   whole reason bands were asked for ("so each skin isn't earning the same
   amount per second"), undone silently by a default. The derivation has to
   genuinely spread: a stable position within the tier — catalogue index, or a
   hash of the key — mapped across the band's floor-to-ceiling. Deterministic,
   so a skin's rate never changes under a player.

   Adding an override later is a one-line fallback if it is ever wanted; it is
   simply not built now.

   The original question, kept for the reasoning: is a skin's rate AUTHORED or
   DERIVED? Authored per skin is full designer
   control and forty-odd rows of work; derived from the key is free and
   arbitrary. **Recommended: an optional per-skin `income`, falling back to the
   band.** It works on day one with no authoring, every skin can be hand-tuned
   later without a migration, and it is the same
   derive-with-an-override shape `Config.rarityOf` already uses (an explicit
   `rarity` wins, otherwise derive).

**ANSWERED: ONE CLOCK PER TIER — everything in a tier fills to the same amount
and ripens together.** `piggyBufferSeconds` keeps taking the tier, not the
skin's rate, so the "whole lawn comes ripe together" property survives the move
to bands. The implementation hazard below still applies to any future change of
that signature.

**AND TWO FEEDBACK DECISIONS RIDE ON IT:**

* **`Config.MILESTONES` becomes `{ 1.0 }`.** The fill-level celebrations at
  0.25 / 0.5 / 0.75 are removed; only FULL keeps a sound. The table is already
  the only source — `checkMilestones` walks it with `ipairs` and re-arms below
  `MILESTONES[1]` — so this is a one-line change that needs no other edit, and
  it matches that constant's own comment: *"100% matters most: income stops at a
  full vault, so that one is functional feedback, not just a flourish."* The
  other three were the flourish.
* **Coins stack VISIBLY inside each piggy, with the overflow animation on
  full.** See the part-count analysis below — the count per mini must NOT be the
  full pig's 32.

**THE NON-OVERLAP REQUIREMENT IS CONCRETE, AND IT IS A CONSEQUENCE OF THE TIER
CLOCK.** One clock per tier means a lawn of one tier ripens SIMULTANEOUSLY, so
"only the full sound" still fires **up to seven times in the same frame**. The
rule that follows: **fire one sound for the LAWN, not one per pedestal.** That
is a real implementation constraint rather than a polish note — seven copies of
one cue in one frame is not a louder cue, it is a distorted one.

**WHAT THE VISIBLE COINS COST — AND THE FIGURE IS PROSPECTIVE, NOT CURRENT.**
An earlier version of this entry counted parts that do not exist. `COIN_COUNT`
appears ONLY in `PiggyBank` (the plot pig and the shop vault). **A pedestal
display is `PiggyModel.build`, which carries no coin geometry at all** — its own
comment says so: *"Solid, like the plot piggy now is. This one carries no pile
at all, so it never had a reason to be anything else."* So there is nothing to
optimise today; the arithmetic below becomes true only once the visible stacks
are built.

**AND BUILDING THEM REVERSES A DOCUMENTED DECISION RATHER THAN ADDING A
FEATURE** — worth spending deliberately rather than discovering. The mini is
deliberately solid. The plot pig's own pile-inside-a-shell history is a long
entry about how hard that illusion was: a true hollow manifold, the fill having
to come down the body so its surface rises past the aperture, and then **the
whole bore retired because `SubtractAsync` breaks the mesh's rendering** — the
hatch is a drawn near-black disc now, and `CLAUDE.md` states the cost plainly:
*"THE HATCH IS NO LONGER A WINDOW ONTO THE PILE."* A mini is a fifth the radius
and a hundredth the volume, so it inherits that problem at a fifth the scale
with far less room to show anything in.

**CONFIRMED BY PHOTOGRAPH, 2026-09-21: THE PILE IS INVISIBLE.** Measured on four
live plots — 32 coins each, every one at `Transparency` 0, inside a body that is
a `MeshPart` at `Transparency` 0. Shot at 26 studs, three-quarter, whole pig in
frame: an opaque pig with **no opening anywhere on it and not one coin
visible.** The part list on a plot pig is `Body x1, Coin x32, CollectPadFace,
CollectPad, DialPlate, Eye x2, Trim` — no rim, no hatch disc, no bore.

**It is a `MeshPart` and not a `UnionOperation` because `SubtractAsync` breaks
this mesh's rendering** — tested three ways in an earlier session (through-bore
alone, blind recess alone, the coin slit alone; all three fail). There is no
hole and there cannot be one by that route.

**THE COST IS SMALL, AND AN EARLIER VERSION OF THIS ENTRY OVERSTATED IT BADLY.**
It said "32 transparency writes per pig per tick on geometry no camera can see".
Wrong: `setFill` is change-guarded and writes only the DELTA — it keeps
`refs.shown` as the last integer coin count and writes only the range between
that and the new target, so a tick that does not cross a coin boundary writes
**zero**. `refs.shown` is written in exactly one place and nothing resets it, so
the guard is monotonic and survives a reskin or a rebuild. **The real figure is
about one write per pig per coin boundary — one per pig per fifteen seconds**,
three orders of magnitude cheaper than claimed.

That matters for how the decision gets made rather than for the decision:
**there is no performance urgency here**, so the geometry answer can be taken on
its merits instead of under time pressure.

Once built, the arithmetic holds: seven placements times ten plots is 70
piggies, at 32 coins each that is **2,240 parts** against grass tufts at ~1,463,
currently the largest single class in the world — half again as much as all the
grass.

**The count per mini must come down, and the rule is already written.**
`PiggyBank`: *"DENSER BY COIN SIZE RATHER THAN BY COUNT... `COIN_COUNT` is not a
density dial: it is the DRIP CADENCE... Bigger discs in a smaller volume buy the
same picture and touch no cadence at all."* A pedestal piggy is `MINI_R` 1.1
against the full pig's ~6 — about a fifth the radius and a hundredth the volume
— so six to eight chunky coins read as filling where 32 tiny ones would not.
That is ~800 street-wide, roughly half the grass, and comfortable.

**Two further levers if it is still heavy:** build the coins CLIENT-SIDE (they
are pure decoration and the server already publishes the buffer figure — the
same pattern as the animated skins, the moat and `HouseFX`, so zero
replication), and give only the OWNER's lawn a full stack, since from the
pavement a pile reads as a blob and the rob badge already carries the figure at
distance.

---

**3. HOW MANY CLOCKS SHOULD A LAWN HAVE? (answered above, kept for the
reasoning)** `Config.piggyBufferSeconds` reads
`PIGGY_RARITY_INCOME` at call time and raises it to an exponent, so it takes a
RARITY today. Under bands it can be fed the tier's nominal or the skin's own
rate, and **this is a design call rather than a mechanical fix** — an earlier
draft of this entry called it the latter and was wrong.

**What does NOT break is the cap.** `cap = rate * duration`, and `rate` is
already per skin under bands, so the coin cap tracks each skin's own earning
either way. What changes is narrower: the DURATION stops tracking the rate.
Measured on a band spanning 6..12 inside one tier (nominal 8):

| multiplier | fed the skin's rate | fed the tier nominal |
| --- | --- | --- |
| 6 | 181.7s | 200.0s |
| 8 | 200.0s | 200.0s |
| 10 | 215.4s | 200.0s |
| 12 | 228.9s | 200.0s |

So feeding the TIER collapses a 26% within-tier duration spread to zero — and
that is the trade, cutting both ways. Fed the tier, every skin in a tier
**ripens together**, which is the "whole lawn comes ripe together" property
preserved within a tier. Fed the skin, duration tracks rate faithfully and
**six pedestals have six ripen times** even at one tier. Both are defensible:
the lap is set by the SHORTEST cap, so nothing is left on the table either way.

**AND THE IMPLEMENTATION HAZARD IS THE PART TO CARRY INTO THE CODE.** Measured:

```
Config.piggyBufferSeconds(8)      -> 100.0s   (should be 200.0s)
Config.piggyBufferSeconds("epic") -> 200.0s
```

A number key misses the string-keyed `PIGGY_RARITY_INCOME`, falls through the
`or 1`, and returns the FLOOR duration for everything — silently, no error, no
warning, every affected buffer halved. **So a signature change from
rarity-string to rate-number may not be done as a swap.** Retire the old name
rather than reusing it, so a missed call site is a nil call instead of a
plausible wrong number — the same reason the flat cap was renamed rather than
retyped when it went per-tier.

**Mythic's band should be chosen against the CAP, not the multiplier**, because
the cap is the product of both and compounds faster than the duration does:

| mythic | holds | caps at (vs a common) |
| --- | --- | --- |
| x15 | 246.6s | x37 |
| x30 | 310.7s | x93 |
| x45 | 355.7s | x160 |

**INDOOR CAPACITY: A REBIRTH BUYS 2-3 PLOTS, NOT A WHOLE ROOM.** This refines
`docs/PIGGY-COLLECTION-PLAN.md` §6, which currently says *"one new room every
rebirth, 6 plots each, straight through to rebirth 20"* = 126 indoor plots.
The designer's call is that a whole room per rebirth is too fast: a rebirth
unlocks **two or three plots**, and the DOOR to more space opens with further
rebirths. §6 needs updating by whoever owns that file — it is not updated here.

**The room cadence should be DERIVED, not a second table.** A room holds 6 and
a rebirth grants 2-3, so a door opens whenever the plots already granted have
filled the room behind it. That keeps one number (plots per rebirth) as the
pacing dial and makes the doors a consequence of it, rather than two tables that
can disagree about when a room is reachable. §6's own boot assertion — that the
plot count per rebirth tier is strictly increasing — survives unchanged and
stays trivially true.

**What it costs, and it happens to fix something:** indoor capacity drops from
126 to roughly **40 at two per rebirth and 60 at three**, through rebirth 20.
§6 argued that 126 plots against a ~44-skin catalogue meant *"the hallway will
fill with duplicates"* and wanted the catalogue roughly tripled to read as a
collection. At 40-60 the catalogue is already close to sufficient, so **this
refinement removes a content dependency rather than adding one** — the packs
schedule out to ~80 stops being a prerequisite for the hallway reading well and
goes back to being a want.

**Unblocked by this:** nothing about the band structure waits on the Moods pack.
The CONTENT re-tag still does (re-tagging animal coats before that shelf has
commons empties a tier a crate authorises at 52%), but the five-tier LADDER and
its bands can land first and independently.

**Capacity ceiling: REMOVED.** Cash resets at every rebirth and rebirth is
required for progress, so the reset bounds hoarding rather than the pig. Three
follow-ons nobody owns: `getRebirthThreshold` loses its basis (the replacement
gate is specific piggies plus a cash amount), `UPGRADE_COST_CEILING` loses its
reason, and the capacity upgrade tree is stranded with nothing to buy.

**Houses: REBIRTH-GATED BANDS.** Each rebirth unlocks more house TIERS, with
MULTIPLE OPTIONS inside each band. Restructures `HOUSE_TIERS` rather than
repricing it. This also retires the resident-house-ladder question below, which
dies with residents leaving the plots — delete the `houses` suite check at
line ~155 rather than deciding it.

**`LOSS_CAP` gets NO piggy clause.** Decided against with the sixty-second-strip
measurement in hand. What still bounds piggy loss is what already exists: a plot
is released when its owner logs off, so nobody is robbed while away, and a
stolen piggy stands in plain sight on the thief's lawn and can be taken back.

**The wanted floor: REMOVED, for now**, explicitly to be reconsidered. **The
cost is recorded here rather than only in the file it came from**, because it is
specific and somebody will need to find it: `CLAUDE.md` says the floor existed
because *"in a quiet server, one player who lifted one small pile would
otherwise be hunted every eight minutes for the rest of the session."* With coin
robbery going PvE-only and piggies becoming the player-facing theft, **the first
player to take ONE piggy becomes the permanent patrol target on a quiet
server.** The arrest clearing the sheet is the only damper left. That may be
fine at the current patrol frequency, and it may be the reason to reconsider
sooner than "later".

**Coin robbery between PLAYERS is going** — robbing piggies and money from the
same person is "too jumbled". The recommended split, and the one the rest of
this file now assumes: **players → piggies, shops → coins. One verb per
target.**

It is cheap, and that is measured rather than hoped. **The discriminators
already exist**: `HeistService.isPlayerTarget` is one line at 218
(`asPlayer(target) ~= nil`), and `plot.shop` already guards five sites in the
same file (2397, 2652, 3065, 3535, 3622). So this is a guard on existing
predicates, not new plumbing, and it is a far narrower retirement than deleting
the coin path wholesale.

It also composes with the police work already landed rather than fighting it:
`bailFraction` is charged against the THIEF'S OWN till and needs no haul figure,
so it is indifferent to which target produced the arrest; and `piggyWorth` plus
the redefined `recordSteal` unit are about what a thief TOOK, so a shop coin
robbery and a player piggy theft feed one rap sheet in one unit with no branch.
That was accidental rather than foresight — it fell out of the haul ceasing to
be a number — and it happens to be exactly what a two-target split wants.

**What it saves, and this is the strongest argument for it:** the crack
minigame. The five-slice dial, the lock tiers, Lockpicks, casing and the smash
all live on VAULTS. Retiring coin robbery wholesale would orphan the
single most-built mechanic in the game; this split keeps it a home and makes
shops a real destination rather than a thin supply floor.

**What it costs:** your own till stops being robbable, so the rob badge should
read the lawn's PIGGIES rather than the pig's coins. A readout change, not a
mechanic — and it lands naturally in Lane 6, which already owes that badge a
lawn-value figure.

**Still to decide alongside it:** whether a shop needs a "worth robbing" RATE of
its own once herds carry the piggy supply, or whether shops are simply the coin
tap. Tuning, not architecture.

**Herds are specced and are the PvE supply** — `docs/HERDS-PLAN.md`. They
answer the "nothing to steal at 3am" objection, which was raised against the NPC
pivot and has been formally withdrawn: supply that does not depend on server
population is the property residents were invented for and the thing four shops
could not provide. The floor still needs re-deriving against herds plus shops.

---

## Open decisions that are the designer's, not a lane's

Recorded here because three sessions are each holding one, and a lane that
guesses at any of them does work that gets thrown away.

**1. `wantedFloor` — how many piggies should it take to be hunted?** It is 60s
of `getIncomeRate`, so in piggy units the pursuit threshold is 0.22 cheap pigs
at level 0 and 1,748 at level 40 — an **8,000x swing**, because the floor rides
the income curve while a pig's worth is a fixed catalogue price. One petty theft
makes a new player hunted; a maxed player is effectively unhuntable. Two
sessions found this independently. Unclaimed, and it needs a number rather than
an owner.

**2. Removing the capacity ceiling entirely**, with rebirth gated on owning
specific piggies plus a cash amount. **This is the largest open item on the
board and it lands squarely on Lane 2's live work.** `getRebirthThreshold` is
literally `getCapacity(maxLevel(rebirths)) * REBIRTH_CAPACITY_MULTIPLE`, so the
proposal deletes its basis; it removes the reason `UPGRADE_COST_CEILING` exists
(the no-deadlock clamp against a bounded wallet); and it strands the capacity
upgrade tree with nothing to buy. Anything Lane 2 derives against capacity
between now and that decision may be derived against an axis that is about to
disappear.

**2b. Three measured balance findings, all needing a number.** Measured on disk
2026-09-21, nothing set. Sequence the third FIRST — it is the only one that is a
stated-rule breach rather than a pacing question, and it BOUNDS the snatch work
rather than depending on it.

* **The solo supply is 27 objects and finite.** Residents seat on unclaimed
  plots, so stealable piggies are resident houses x `piggyCount`: 27 at one
  player, 18 at four, **6 at eight**. A snatched piggy is not replaced, so a solo
  player strips the whole street in about **ten minutes** (27 hops at a 22.2s
  cycle) and it stays barren until a plot frees and reseats. That is the
  pre-tills collapse exactly — supply as a function of how busy the server is,
  the failure `CLAUDE.md` calls the worst this economy has had.
* **A resident lawn out-earns a player's own, 1.71x.** At L20 a resident's three
  rares earn 35,935/s against a player's full lawn of six commons plus till at
  20,962/s. `RESIDENTS`' own rule — *residents richer than the thief are a
  faucet, full stop* — was written about the till pig; the LAWN now breaks the
  same principle one level up. Possibly intended now that stealing is the
  primary route, but it is a product nobody checked.
* **`LOSS_CAP` has no piggy clause, and that is a RULE problem rather than a
  dial.** It is `{fraction 0.45, window 1h}` and it is COINS ONLY. Nothing
  bounds piggy loss. Cooldown-bound, one thief strips a lawn of six in 5.0
  minutes; the cooldown is per thief per victim, so **seven thieves take one
  pedestal each inside a single 60s window and a victim is stripped to zero in
  about a minute.** `CLAUDE.md`'s hardest rule is that losing permanent progress
  for being robbed is rejected outright — *a crying-then-uninstall event a
  parent sees* — and a piggy is permanent progress. The design's answer is that
  it is recoverable by the same verb, which is real; "recoverable in principle"
  against seven thieves is thin, and today there is nothing at all between a
  child and an empty lawn.

The clause itself is small and belongs in Lane 2's pass: `lossAllowance` already
has the shape (per victim, never per thief, rolling window) and piggy loss wants
that same table rather than a second one. It needs a fraction-or-count and a
window, and then it lands with an audit and a provoked test in one session.

**3. The two payout readers still measured in one pig** —
`DailyService.coinValue` and `EventService.payIncomeSeconds` — are a ~22x swing
under the new denominator. Held deliberately as pacing calls.

**5. Do residents climb the LEGACY order or the CATALOGUE order?** The `houses`
suite now fails honestly here, at line ~155. Measured:

```
legacy order : shack cottage townhouse VILLA     manor modern neontower palace skycastle
live ladder  : shack cottage townhouse MUSHROOM  villa treehouse manor slime  modern
```

It diverges at step 3. The suite asserts residents climb the nine
`HOUSE_LEGACY_ORDER` ids; `residentHouseLevel` now climbs the first nine
CATALOGUE rows, which the three fantasy houses were inserted into. Neither side
is obviously right: `HOUSE_LEGACY_ORDER` is documented FROZEN and exists only
for the schema-26 migration, so driving residents off it uses a migration
artefact as a content list — but the suite's comment says *residents climb the
nine BUILT houses*, and that list was a proxy for "the ones with real models",
which is a different set now three more have landed. **The check two lines below
is the one that would actually bite** — *a resident never stands a placeholder
or an earned house* — and it has not been reached yet.

**4. Retiring cash robbery.** Not unclaimed: it is live with a user, and its
prerequisites have already landed — `POLICE.bailMultiple` deleted in favour of
`bailFraction` against the thief's own till, `Config.piggyWorth` standing, and
`recordSteal`'s unit redefined as coins-equivalent value so the transition costs
it no branch. What waits on the decision is only the deletion of
`HeistService:4318`, and that goes in the retirement commit.

---

### Deferred, deliberately

**Stage 4 interiors** is one tightly-coupled cluster with no useful partial
version, and the plan's own rule is that nothing past Stage 1 is worth starting
until the loop has been played and feels right. Lanes 1–5 are what make that
playthrough meaningful. Hold it.

**Stage 6 Robux crates** is gated on a designer decision, not on engineering.

---

## Dispatch order from cold

1. **Lane 0**, as one-shot subagents — the gate and the checkpoint commit.
2. **Lane 1** next and widest; it is authoring, so give it the most hands.
3. **Lanes 2 and 3 continue** where they are; Lane 2 adopts the derive-don't-pin
   rule before it lands another constant.
4. **Lane 4** opens against whichever session frees up first, and measures with
   Lane 2 rather than after it.
5. **Lanes 5–9** as sessions free up.
6. One `game-doc` run at the end, by Lane 3. Not before, and never two.
