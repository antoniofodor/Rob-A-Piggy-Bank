# Session handoff — 2026-09-16

## Working agreement — GPT visuals, Fable scripting/planning

User explicitly assigned GPT physical/visual design, UI and buttons, and
Fable scripting and planning. See `docs/DESIGN-SCRIPTING-HANDOFF.md` for the
ownership/handoff workflow. GPT should deliver assets/specs and visual QA;
Fable owns runtime Luau, UI wiring, economy, migrations and functional tests.
Do not silently resume GPT gameplay scripting under the older master-plan
execution requests. Fable's new `docs/LATE-GAME-ECONOMY-PLAN.md` §11 records
the latest choices (individual houses, schema 26 stable IDs, accepted pace,
Option A2 beyond RB10). Its earlier unresolved recommendations are historical.

## Checkpoint — September 16, committed and pushed

**State:** 4b.1 (level-60 ladder, A2 taper), 4b.2 (houses by stable id,
schema 26), 1.11 (pig-crack acorn) and 2.6 (storage is a bank, acorn theft
only under a moon event) are implemented. All 23 isolated suites pass
(`python tests/run-crates.py --luau <luau> --suite <name>`, including the
new `ladder` and `houses`); Rojo builds.

**Designer direction for the next step:** the house exterior renders will be
generated later. Do not wait on them. **Add the revision-2 catalogue to the
game now with empty placeholder models** — the eighteen ids, names, prices
and rarities from `docs/HOUSE-TIER-BRIEF.md` §1 (the three re-themes rename
`villa`, `modern`, `palace` in place; `goldenpig` is earned, not priced), each
standing as a plain, clearly-temporary block sized to its brief height, so
buying, moving in, the catalogue cards and the sign all work end to end.
Then move on to the house INSIDES (trophy rooms, `HOUSE-TROPHY-ROOMS.md`,
brief B2 — GPT's blockouts are in `assets/design/phase-4b/rooms/`).

**Still open for the designer:** the three re-themes (owners wake up in the
new house); Golden Piggy as the earned completion house; player robbery
cooldown 60 s → 180 s (4c.5); order of 4c.6 (delivery capped at the pig).

**Known design flag (from 2.6):** the re-derived acorn faucet is 1.0/hour
solo — a common crate every 5 hours — slower than §19.5 estimated. Levers:
the tree ladder (2.7) and the crate prices.

**Not verified live:** a two-player session (Phase 0.2) is still owed; the
house purchase path is proven at service level, not through the remote.

## Phase 5 implemented: the reputation yard and season one (September 17, latest)

User asked for all of Phase 5. Committed and pushed together with every
earlier uncommitted step below (tree ladder, 4c.6 caps, house catalogue,
Midnight Heist).

- **5.1 The sign.** `PlotService` narrows the rank row and adds a
  `SeasonChip` (`setSeasonChip`, text/colour from `Config.seasonChipText` /
  `seasonChipColour`) and a `Nemesis` line (`setNemesis`). The ledger is
  `data.nemesis = { index, rows }`, twenty rows (`Config.NEMESIS_ROWS`),
  written by `SeasonService.recordNemesis` on every player-victim delivery and
  reset with the season. Rank stars were already on the sign (4c).
- **5.2 Trophies.** Six new `TROPHIES` rows with `Decor` builders: Hot Streak
  (`bestSpree`, `ladder = "above"`), Old Hand (rap-sheet rank), Clean Sheet
  (clean five-slice deliveries), Season Cup (best tier ever), Wanted Poster
  (sessions on the Most Wanted poster), Good Harvest (own-tree acorns
  banked). New counters `trophies.clean/wanted/harvested`;
  `TrophyService.recordClean/recordWanted/recordHarvest/recheck`.
  **Van Job skipped: there is no Cash Van yet.**
- **5.3 The season.** `SeasonService` (new). `Config.SEASON.first = 592`
  (launch week 2026-09-17 is 591's rest week, so **Season 1 opens
  2026-09-24 UTC**). Rank is acorns BANKED this season (own-tree basket
  deposit and the pig-crack acorn), counted only in the four live weeks.
  Tiers 10/20/40/75/150/210/280/370/480/620, re-solved on
  `tests/sim/acorns/model.py x3 season` (the plan's 3..700 predates the x3
  crates and the overnight fill). Rewards go through `SetService.grant`
  (new kinds finish/plinth/kennel/coat), are recorded in `season.granted`
  so they land once, and an already-owned reward is said, not converted.
  Tier 9 is the sign's STAR words, tier 10 the season finish
  (`SEASON.finishes[1] = "midnightstar"`; a season with no row warns and
  skips). Lazy rollover keeps `season.best`. `Config.auditSeason` at boot.
- **5.4 Finishes.** `Config.FINISHES` (Bright Eyes, Polished, Lantern Glow,
  Gilded, Midnight Star): reflectance, neon eyes and the aura light, lamps
  capped at 0.6 by the audit. `cosmetics.finish/ownedFinishes`, pruned in
  reconcile. `PiggyBank.applyFinish` runs after the skin and effect;
  `CosmeticsService.equipFinish` (toggle, owned only); a **Finishes** tab in
  the inventory. **No particles**, per the standing no-piggy-effects rule.
- **5.5 Boards.** Top Defenders (`WEEKLY_DEFEND`, `data.defend`, counted on a
  nab win, a dog catch for the owner and an owner's hot recovery) and the
  season board (`SEASON_BOARD`, two 100-row pages, cached a minute). The one
  street board turns pages every `BOARD_PAGE_SECONDS` (thieves, defenders,
  season) and publishes `BoardPage`; on the season page each client hides it
  and draws `Shared/SeasonBoard` from its own `SeasonState`: three rows
  above and four below the reader, or the top seven plus a "you" row.
- **Admin:** Season group (shift a week, reset, +50, +300, status);
  `seasonshift`, `seasonearn`, `seasonstate` commands.
- **Checks:** new `season` suite (82 checks: clock and launch dates, tiers,
  grants once, already-owned, rollover and best, rest week, pre-season,
  window, nemesis cap, audit provocations, trophy grades and counters,
  finish prune, set kinds, defend counter, the board footer). Four heist
  suites gained SeasonService/Trophy/recordDefend stubs. All 26 suites pass;
  every script compiles; Rojo builds; `git diff --check` clean.
- **Not verified live (no Studio session):** the sign's new geometry
  (chip/nemesis/boasts overlap), the local season page over the board, the
  finishes on a real pig, the six trophy models, DataStore publish/fetch,
  and every multiplayer path (nemesis, defends).

## Midnight Heist, acorn theft off, crates x3 (September 16)

Designer decisions, all implemented; uncommitted (no commit yet by request).

- **Crates x3 (19.5):** `og`/`animal` 5->15, `alien` 6->18, `rarecrate`
  15->45, `legendarycrate` 40->120. Buy-back (3x per step) and the
  rebirth-crate bonus derive from them. `crates`, `buyback`, `rebirth`,
  `audits` tests now read prices from Config or were updated.
- **Midnight Heist replaces Rush Hour and the Harvest Moon.**
  `roster.midnight` (180 s, weight 2); `EVENT_UI.midnight` (U+1F319, the
  periwinkle); `Config.MIDNIGHT` (stealMultiplier 2, acornMultiplier 2);
  `Config.MIDNIGHT_LIGHT` + `WorldService.setNight` (renamed from setMoon).
  `EventService.runMidnight` sets both multipliers before the push;
  `getAcornMultiplier`; `HeistService.endCrack` stamps
  `carry.acornMultiplier` on a clean crack so a delivery after dawn is still
  doubled. Solo gets no acorn bonus (residents mint none), by decision.
  `Config.RUSH` and `runRush` are gone; admin panel has MIDNIGHT HEIST now.
- **Acorn theft disabled:** no row carries `acornTheft`; `auditAcorns`
  `theft.disabled` refuses one; `midnight.acorns` caps the night at 2x. The
  shake refusal now reads "Only its owner can shake this tree." Theft code
  remains, closed — revisit after play-testing.
- **Model** (`tests/sim/acorns/model.py [x3|old]`): per day — casual 5–12,
  regular 13–24, active solo 20–28, active multiplayer 22–30. Regular: ~1–1.6
  common crates a visit, a legendary every 5–9 days.
- **Measured event shares:** raid 40.9% (every ~37 min), night 59.1%.
- **Admin:** Tree group (`tree`, `ripe`) from earlier in this step.
- **Checks:** `moon` suite renamed `midnight` (31); `theft` 171 (+4 night
  acorn checks); all 25 suites pass; compile and Rojo build clean.
- **Not verified live:** the night's look, the crescent glyph's width, a
  doubled acorn delivery in a two-player session.

## 6.4 implemented: the Harvest Moon (September 16)

User asked for the next step; 6.4 was the remaining plan step needing
neither GPT art nor a live play session. Uncommitted, on top of everything
below; no commit yet by request.

- **Event:** `Config.EVENTS.roster.moon` = HARVEST MOON, 150 s, weight 1,
  `acornTheft = true`; `EVENT_UI.moon` (U+1F315, tone 192/182/255 after the
  first pick measured 4.46:1 at the warning pulse low). The banner, warning,
  countdown chip and patrol suppression are the generic event path.
- **Theft:** nothing new — 2.6's `EventService.isAcornTheftOpen`,
  `ShakeService.open` gate and the client prompt gate on
  `EventState.acornTheft` light up while `running == "moon"`. Ripe acorns
  only, basket x5 player / x1 resident, storage safe, normal getaway. A round
  already started may finish after the moon sets.
- **Light:** `Config.HARVEST_MOON` dusk; `WorldService.setMoon(on)` tweens
  (3 s) and on the way back sets `WorldService.DAY` exactly (ClockTime 14.5,
  Brightness 2.4, both ambients, sun tint). `restoreDay` also runs if the moon
  errors. The boot lighting now reads the same `DAY` table.
- **Audit:** `auditAcorns` requires exactly one theft row, 60–240 s, weight
  > 0, with a banner row.
- **Admin:** "HARVEST MOON now" button.
- **Measured shares** (40,000 slots): moon 27.9% (~1 an hour), raid 27.5%
  (down from ~41%, about one every 55 min), rush 44.7%.
- **Checks:** new `moon` suite (29); `audits` stub gained WorldService. All
  25 suites pass; 105 scripts compile; Rojo builds.
- **Not verified live:** the dusk's look and readability, the moon glyph's
  width, another tree's prompt appearing and disappearing with the banner in
  a real session, and a shaken neighbour's acorns delivered home.

## 2.7 implemented: the tree ladder (September 16)

Uncommitted, on top of the 4c.6 and house-catalogue work below.

- **Config:** `TREE_LEVELS` (0–4: 1.0/1.25/1.5/2.0/2.5 per hour; prices 25K,
  100K, 1M, 12M, each under the cheapest house of the rarity that opens it —
  first pass, re-solve with 19.5), `TREE_HOUSE_GATE` (best OWNED house: Common
  lv1/cap 8, Rare lv2/12, Epic lv3/16, Legendary lv4/24),
  `TREE_REBIRTH_BONUS` (+3% per rebirth, online only, max +60%). Helpers
  `bestHouseRarity`, `treeGate`, `treeLevelOf`, `treeCap`,
  `treeGrowthPerHour`, `nextTreeLevel`, `treeGateRarityFor`.
- `Config.growAcorns(data, now, online)` reads rate and cap off the save:
  offline path passes `false`, live tick `true`, shake settles with the
  owner's online state. Residents grow exactly as before.
- **Save:** `data.tree = { level = 0 }` via the generic fill (no schema bump);
  reconcile clamps the level and re-clamps ripe stock to the house cap after
  houses resolve. Level survives rebirth.
- **TreeService** (new): owner-only **Grow Tree** prompt on the oak (J,
  slot 1, kind `grow`, built in `PlotService.buildPlot`), plus `TreeRequest`.
  Refusals (gated, fully grown, won't fit, too few coins) name the reason and
  never charge; a purchase settles growth at the old rate, charges, redraws
  and saves. `CosmeticsService.onHouseBought` refreshes the offer. Main
  starts it and calls `TreeService.apply` on join; `PlotService.release`
  resets the oak and the prompt owner.
- **Placeholder look:** height-only stretch to 1.2x at level 4
  (`AcornTree.setGrowth`). Sideways growth was dropped: the trunk mesh's
  bounding box already reaches the storage crate at level 0. The ripe-acorn
  display scales its height by `PLOT_TREE_GROWTH_ATTRIBUTE`.
- **Audits:** `auditAcorns` checks the ladder, gate and bonus;
  `auditEconomy` prices the rungs. Boot line reports the top tree rate
  (4.0/h vs the 1.0/h base).
- **Checks:** new `tree` suite, 93 checks (simulated day per level, online-only
  bonus, house caps incl. 19.4a's "20 after eight hours", partial-hour carry
  across a purchase, purchase path and refusals, saves, provocations,
  level-4 clearances). All 24 suites pass; 104 scripts compile; Rojo builds.
- **Not done / not verified:** no Studio session (prompt card, J key, the
  stretched oak and the 🌳 glyph's width are unseen); the "next acorn" HUD
  chip and fertiliser; crate-price re-solve (19.5); an admin command to set
  tree level for testing.

**Follow-up, same day — the next-acorn clock over the tree** (designer
asked for it above the tree rather than on the HUD):
- `Shared/TreeClock` (client, owner-only, started in `ClientMain` with no
  new local): a paper card just above the canopy — chestnut glyph, `3/12`,
  `next 42m` / `0:42`, or `FULL` in good ink. Rises with the canopy.
- Server publishes `Config.PLOT_TREE_NEXT_ATTRIBUTE` (server time of the
  next acorn, nil when full) and `PLOT_TREE_CAP_ATTRIBUTE` via
  `PlotService.publishTree` / `updateTreeClock`; `Config.nextAcornIn`
  shares `growAcorns`' cursor and rate. Published from the economy push,
  a shake (`ShakeService.publish`), `TreeService.refresh` (join, purchase,
  house purchase); cleared on release.
- `tree` suite 106 (+13); `growth` and `shake` stubs gained `publishTree`.
  All 24 suites pass; 105 scripts compile; Rojo builds.
- **Not verified:** the card in Studio (position above the canopy, the
  chestnut glyph's width, `24/24` fitting its 62px box).

**Next:** Studio verification of the three uncommitted steps, then the
designer's call on the remaining order (19.5 re-solve, Harvest Moon 6.4,
the 4c robbery rework).

## 4c.6 implemented: nothing puts more in a pig than it holds (September 16)

User direction: skip the trophy rooms (4b.5) for now, do 4c.6 before 2.7, and
leave the three re-themed houses on their old models until the new models are
swapped in. Uncommitted.

- `Config.pigRoom` / `Config.fitInPig(coins, capacity, amount) -> banked, spilled`.
- **Capped (all minted coins):** `HeistService.deliver` (original, revenge
  and kept-haul half share), the return bounty, the shop-drop duplicate
  resale, `DailyService` coin rungs (including the Golden Bone day), and
  `EventService.payIncomeSeconds` (raid bounty). Each names the spill.
- **Coins coming back are capped too** (designer correction): `giveBack`
  (every coin return: nab, dog, patrol, voluntary return),
  `ResidentService.refund` and the drone recovery bank only the room and
  name the spill. The loss ledger is still credited in full.
- The victim is still charged in full; `totalStolen`, rap sheet, weekly board,
  robbery count and pig-crack acorn are unchanged. `HeistDelivered` carries
  `spilled`; `LootHaul` shows "PIGGY FULL: X SPILLED".
- Crack and smash toasts go through `homeWorthPhrase` (payout x spree x room),
  so the preview matches the banked figure.
- **Badge and prompt cards** (designer correction) show `Config.homeTake`:
  what the reader can carry home from a clean crack (smash card: a smash),
  capped at their own room. A full reader pig reads **PIG FULL** on the badge
  and **FULL** on the cards. `RobBadge` now listens to `StateUpdate` and the
  sack level; `ClientMain` keeps the reader's coins/capacity on `stealInfo`
  (no new top-level locals) and refreshes the cards on every push.
- **Design flag:** daily coin rungs (5–30 min of income) can mostly spill on
  a full pig. Lever if it feels harsh: hold the coins until there is room.
- **Checks:** `theft` 167 (+14), `badges` 26 (+9), `shopdrops` 104 (+2);
  `handoff` and `shopdrops` fixtures now carry `capacityLevel`; all 23 suites
  pass; 103 scripts compile; Rojo builds.
  GAME.md §4 and CLAUDE.md updated.
- **Not verified live:** no Studio session; a real delivery into a full pig,
  the card's spill line, and the badge/prompt `PIG FULL` / `FULL` text (width
  unmeasured on screen) are unseen.

**Next:** 2.7 (tree ladder and rebirth growth bonus), unless the designer
reorders. 4b.5 trophy rooms are deferred.

## Revision-2 house catalogue landed with placeholders (September 16, later)

The designer direction above is **done**; uncommitted. All nineteen rows from
`docs/HOUSE-TIER-BRIEF.md` §1 are in `Config.HOUSE_TIERS` in price order
(18 priced, shack to the 1B Void, plus the earned Golden Piggy).

- **New houses** (`mushroom`, `treehouse`, `slime`, `candy`, `crystal`,
  `galleon`, `portal`, `thundercloud`, `void`, `goldenpig`) carry
  `placeholder = true` and a brief `height`. `House.build` stands
  `buildPlaceholder` for them: plinth, block in the row's wall colour, roof
  cap, door, and a yellow-and-black construction band. Measured in a stubbed
  sweep: 29–71 parts each, zero coplanar pairs, footprints up to 51.2 x 37.2,
  heights equal to the brief. A style with no builder and no flag also gets
  the block now (it used to borrow the shack).
- **Re-themes** renamed in place (Fairy Lantern Cottage, Fishbowl House, Ice
  Palace) with new blurbs. **They keep standing their old models** so no
  paying owner wakes up in a block; switching `style` when the new builder
  lands is the one-word change. The Sky Castle blurb no longer says "the last
  thing anyone buys".
- **Golden Piggy:** no `cost`, `earned = "houses"`, explicit legendary.
  `isEarnedElsewhere` reads `earned`. `buyHouse` refuses it by name with the
  progress count (never charges); `CosmeticsService.grantEarnedHouses` grants
  it on the last priced purchase without moving the player out of what they
  just bought; it can then be moved into for free. The payload marks it
  `earned` with `earnedHave/earnedNeed`, and its card reads `EARNED n/18`.
  `Config.earnedHouseProgress` counts priced houses (shack included).
- **Residents** climb only built houses via `Config.residentHouseLevel`, so
  every neighbour stands exactly the house it did before.
- **Audit** now refuses a priced earned house, a priced row with no number, a
  placeholder over the 60x57 limit, and a catalogue out of price order.
- **Checks:** `houses` suite 1,239 (was 1,025); all 23 suites pass; all 103
  scripts compile; Rojo builds; `git diff --check` clean. The old test pinning
  the nine at positions 0–8 now asserts their relative order instead.
- **Not verified live:** no Studio session was available, so the blocks on a
  real plot, the shop card render, the sign and a purchase through the remote
  are unseen. The Void's near-black block against the card's near-black icon
  well is the first thing to look at (brief §2 trap 2).

**Next:** the house INSIDES — 4b.5 trophy rooms (`HOUSE-TROPHY-ROOMS.md`, brief
B2; GPT's blockouts in `assets/design/phase-4b/rooms/`). Each new house's real
builder can land any time under its `style`, then drop `placeholder`.

## Fable handoff — economy and acorn re-centring (September 16)

Planning only; no runtime Config, service or client code changed. Three
documents carry it:

- `docs/LATE-GAME-ECONOMY-PLAN.md` — audit of the live formulas (regenerable
  via `tests/sim/late-game/`), the chosen late-game ladder (band C to L60 /
  RB20, top pig 1.241B, rebirth multiplier 0.12 to RB10 then 0.08),
  archetype pacing (regular player: 1B house ~week 8), individual house
  ownership by stable id, schema-26 migration that deletes
  `houseLevel`/`houseShown`, and §11 (trophy rooms + seasons as the loop
  after the catalogue; a voluntary Legacy reset).
- `docs/MASTER-PLAN.md` §19 — the acorn loop re-centred on the pig: coin
  pack dropped; one acorn minted per clean five-slice crack on a player's
  pig; banked acorns never stealable; acorn theft only inside a new
  **Harvest Moon** event (bounded lighting tween, no day/night cycle); a
  coin-priced tree ladder and rebirth online-growth bonus. Banners on §3-6,
  13, 14.2, 15, 16 and Phases 2/3/6; six new Part III C rejections. New
  execution steps 1.11, 2.6, 2.7, 6.4 and **Phase 4b** (ladder, house ids,
  catalogue UI, rooms, Legacy).
- `docs/BRIEFS-FOR-GPT.md` — step-1 briefs. **GPT needed now:** B1 house
  catalogue UI, B2 trophy-room templates (named mount points), B3 exterior
  constraints. **Later:** B4 Harvest Moon look, B5 tree levels, B6 Legacy.
- `docs/HOUSE-TIER-BRIEF.md` — the full eighteen-house tier list for GPT:
  nine new **fantasy** houses (toadstool, treehouse, slime, gingerbread,
  crystal spire, beached galleon, dragon's roost, sky islands, golden piggy)
  with stable ids, silhouettes, FX, room families and the yard constraints;
  the nine existing houses keep id/price with an optional later re-theme.
  Supersedes the realistic concepts in `HOUSE-CATALOGUE-PLAN.md`.

Fable can start 4b.1 (ladder, Config only), 4b.2 (house ids + migration),
1.11 (pig-crack acorn) and 2.6 (retire raids) with no visual dependency; 4b.3
waits on B1. Open decision for the user: do skins and rides survive a Legacy
reset (recommended yes).

## Fable — Phase 4b.1 implemented: the late-game ladder (September 16)

Config only, plus two readers. `ABSOLUTE_MAX_LEVEL` 40 → 60 with a third
growth band (`BAND_TOP_2` 40, `CAPACITY_GROWTH_C` 1.136, `INCOME_GROWTH_C`
1.10, band-B cost growth); `maxLevel` unchanged in form, so rebirth 20 opens
level 60; rebirth multiplier tapers to 0.08 past rebirth 10
(`REBIRTH_MULTIPLIER_TAPER`, read through `Config.rebirthIncomeFactor` /
`rebirthBonusPercent` — `Rebirth.luau` and `ProgressionService` converted);
both audits derive their rebirth sweep from `Config.rebirthsToMax()`.

- **Every value for L ≤ 40 / RB ≤ 10 is unchanged** — pinned by the new
  `tests/luau/ladder.luau` (121 checks; `--suite ladder`). Top pig is
  1,241,390,843; a 1B house is 80.6% of it and passes `auditEconomy`.
- All 21 existing suites pass unchanged; `rojo build` passes; `Config.luau`
  executes fully under the Luau CLI (so no load-time throw).
- `tests/sim/late-game/dump.py` now prints the tapered factor to RB22.
- `CLAUDE.md` gained the band-C entry (derivations, the taper, the pinned
  audit bounds); `docs/GAME.md` §4 says three bands and cites the taper.
- **Not done:** a Studio Play to watch the boot log. Studio was left to
  whoever holds the active Rojo session per `DESIGN-SCRIPTING-HANDOFF.md`.
- Uncommitted. Next Fable step: 4b.2 (house ids + schema 26).

## Fable — Phase 4b.2 implemented: houses by stable id, schema 26 (September 16)

`Config.HOUSE_TIERS` rows carry `id` (shack, cottage, townhouse, villa,
manor, modern, neontower, palace, skycastle); `style` stays the builder key.
`data.houses = { owned = { [id] = true }, shown = id }` replaces
`houseLevel`/`houseShown`, which `DataService.reconcile` reads once against
the frozen `Config.HOUSE_LEGACY_ORDER` (derive-only, never grants) and
deletes. Houses are a shelf: `CosmeticsService.buyHouse(player, id)` sells
any unowned house whose price fits the pig (a "grow your pig" refusal above
capacity, a coins refusal below), and moves into any owned one free. No
"buy the X first" copy survives. Readers converted: Config (helpers
`getHouseById`, `houseLevelOf`, `getShownHouse`, `legacyShownHouseLevel`;
retired `getHouseUpgradeCost`, `MAX_HOUSE_LEVEL`, `getShownHouseLevel`),
DataService, CosmeticsService (payload entries carry `id`; `houseShown` is
an id; `houseLevel` gone), AdminService (`house` takes an id or a legacy
number; `unlockall`, `reset`), EconomyService and ProgressionService sign
lines, ClientMain's three house sites (cards keyed by `info.id`),
`growth.luau` fixture. `auditEconomy` refuses a missing/duplicate id and a
legacy id not in the catalogue. `SCHEMA_VERSION` 26.

- `tests/luau/houses.luau` (`--suite houses`, 1,025 checks): the §8.2
  matrix twice, prune/fallback, never-grants, and `buyHouse` through the
  real service (outright purchase, free move-in, refusals never charge, a
  numeric key is refused, rebirth keeps every house).
- All 23 suites pass. Studio Play: clean boot, the schema-25 dev save
  (level 8 / shown 8) came back owning nine and showing the Sky Castle on
  the sign; one leftover reader (`applyToPlot`'s sign line) was caught by
  that boot, not by grep, and fixed.
- **Not verified live:** a purchase through the real `CosmeticRequest`
  remote — the MCP sandbox cannot fire capability-gated remotes; covered by
  the service-level test instead.
- `docs/GAME.md` §9 and §13 updated (game-doc agent). Uncommitted.
- Next: 1.11 (pig-crack acorn) and 2.6 (retire raids).

## Fable — Step 1.11 implemented: the pig-crack acorn (September 16)

`Config.ACORNS.payout.crack = 1` / `crackRevenge = 2`, read only through
`Config.crackAcorns(clean, victimIsPlayer, revenge)`. `HeistService.endCrack`
stamps `carry.clean` on "done"; `deliver` mints the acorns for the ORIGINAL
grabber on a player victim (residents and shops pay none, a nabbed carry
pays none, a partial crack pays none), pushes the plot's acorn count, names
it in the delivery toast and in the `HeistDelivered` payload (`acorns`);
`LootHaul` shows "+1 ACORN" on the summary card. `auditAcorns` gained
`acorn.crack` (whole, ≥1, revenge ≥ plain) and `acorn.crackGate` (the three
zero cases), and its legacy-faucet wording changed.

- `tests/luau/theft.luau` +10 checks, `audits.luau` +5 provocations; all
  affected suites pass.
- Not re-derived yet: the acorn rate model printed at boot
  (`Config.acornRates`) still describes the tree-and-raid faucet; 2.6 and
  19.5 re-solve it.

## Fable — Step 2.6 implemented: storage raids retired (September 16)

Storage is a bank: `ShakeService.open` refuses "storage" for everyone by
name; another occupant's tree is refused ("Only the Harvest Moon…") unless
the new `theftOpen` hook is true, wired to `EventService.isAcornTheftOpen()`
(true only while a roster row with `acornTheft = true` runs — none exists
until 6.4, so theft is closed). `EventState` carries `acornTheft`; the client
shake prompt on anybody else's tree is disabled unless it is set. Removed:
the crate's raid prompt (J is free), `ACORNS.share/lossCap/lossWindow`,
`resident.raidSeconds`, resident `raidReadyAt`, the raid-ready plot
attribute, the `acornRaid` prompt kind and the loss ledger.
`Config.acornRates` re-derived (own tree + pig-crack ceiling);
`ACORN_AUDIT` is `activeHours/minPopulationRatio/maxCrackRatio`;
`auditAcorns` gained `retiredRaid`, `crackCeiling` and dropped the loss-cap,
passive and 3x active floors. Boot print changed.

- `tests/luau/shake.luau` rewritten (raids inverted to named refusals, moon
  simulated); `shakeui`, `residents`, `audits` updated;
  `tests/studio/resident-acorns.luau` deleted (tested the retired
  countdown). All 23 suites pass.
- Studio Play: clean boot; zero raid prompts; own tree offered, nine
  resident trees withheld; the new model line printed.
- **Design flag:** the re-derived faucet is 1.0 acorn/hour solo (a common
  crate every 5 h) and 3.0 full-server — slower than §19.5's estimate. See
  the note added under MASTER-PLAN §19.5; the levers are 2.7 and crate prices.
- `docs/GAME.md` update running via the game-doc agent. Uncommitted.

## Fable — Phase 4c added: the robbery rework, and two rules verified (September 16)

`MASTER-PLAN.md` Phase 4c: harder crack (measure first — the dial was frozen
for the life of the feature), the panel redesign (B7), catching as beats
(dog lunge, officer corner-cut, owner shove, resident shout), new gadgets
(B8; candidates rule-checked, movement items refused). 4c.5 verifies the
same-victim cooldown (60 s per thief per victim, plus the 45%/h loss cap;
friend ping-pong is ~14x worse for the board than robbing residents) with an
offered decision to raise the player cooldown to 180 s. 4c.6 records that
**delivery is NOT capped at capacity today** — `deliver` overflows on purpose
— and plans the reversal: bank `min(amount * payout, room)`, spill said out
loud, every "worth at home" preview capped, one rule for dailies/events too.
Briefs B7 and B8 appended to `docs/BRIEFS-FOR-GPT.md`. No code changed.

## Fable — house catalogue revision 2 and houses-gate-trees (September 16)

Planning only. `docs/HOUSE-TIER-BRIEF.md` is now revision 2: dragon → Portal
House (300M), sky islands → Thundercloud Fortress (600M, storm grey-blue),
golden piggy → **The Void (1B), the one black house**; Golden Piggy becomes
an earned, unpriced completion house; re-themes Suburban Villa → Fairy
Lantern Cottage, Midnight Modern → Fishbowl House, Marble Palace → Ice
Palace (same ids, prices, owners — **pending designer confirmation**). New
rules: a house never contains a creature; exactly one black house.
`MASTER-PLAN.md` §19.4a: houses **gate and hold, never generate** — one tree
per plot; tree levels unlocked by best-owned house rarity (C 1 / R 2 / E 3 /
L 4); tree cap by house rarity (8/12/16/24), rate by tree level; reads the
best house OWNED, not shown. Added to the 19.5 re-derivation list. GPT: use
revision 2 for the exterior concepts.

## Current task — higher-tier house exterior concepts

Latest: user approved the shared themed trophy-room idea and requested a
house-count/price plan extending to 1B. `docs/HOUSE-CATALOGUE-PLAN.md` proposes
18 houses (nine existing prices preserved, nine additions). Assumes 1B is
the highest single purchase; proposed total is 2,228,455,000 coins. Four
houses exceed the current 96,904,045 capacity, so capacity progression or
staged payments must be decided before adding those prices. No pricing,
rarity, income, capacity or ownership changes were made to runtime Config.

Follow-up direction: user likes enterable showcase rooms and wants earned
achievements/trophies inside houses instead of in the yard. Proposed shared
room system and theme mappings are in `docs/HOUSE-TROPHY-ROOMS.md`; existing
TrophyService progress can be reused. No interior runtime changes yet.

User deferred fence expansion and requested exterior catalogue mockups;
interiors are a separate future proposal. Built-in image generation produced
three sheets (each front and three-quarter views): Emerald Chateau, Sunset
Sky Villa and Royal Observatory. Files, notes and exact prompts are saved in
`assets/houses/concepts/2026-09-16/`. These are proposals only: no house models,
prices or progression changes were implemented. MASTER-PLAN priority updated.
Existing houses use saved numeric levels, so future expansion must preserve
ownership instead of inserting/reordering the ladder without migration.

## Current direction — standalone piggy effects retired (September 16)

**The user explicitly rejected restoring the effects shop:** effects on a
piggy should only be coin-deposit feedback and Legendary skin visuals.
This supersedes the old Phase 4.3 / Art 11 brief. Do not ask to restore the
shelf again. Aurora, Starfall and the attempted shop UI have been removed.

- Retired direct coin/Acorn purchases, equip requests (except clearing None),
  event/pass grants and shop robbery drops for standalone piggy effects.
- Piggy Outfitters now drops skins only; overall 10% chance stays unchanged.
- The renderer disables the separate aura/light without touching coin or
  Legendary skin emitters. Non-Legendary skins cannot opt into skin auras.
- Legacy ownership and particle definitions remain for save compatibility.
  No player balance/ownership migration or deletion was performed.
- MASTER-PLAN Phase 4.3 now starts with yard/fence styles, then interiors;
  the proposed effects design file was removed. Those next shelves still
  need their design brief. Phase 0 and previous live gameplay checks remain
  deferred. Changes are uncommitted.
- Validation: 1,479 isolated checks pass across 21 suites (224 audit checks).
  All production scripts compile; final Rojo build and diff check pass.
  Native phone Play verified the effects tab/shortcut are absent, no Aura
  emitter is enabled, and Drip/Burst/SkinAura instances remain. No new runtime
  errors; existing unset-pass/MaxPlayers warnings persist. Studio returned
  to Edit. This does not close the pending multiplayer gameplay checks.

## Resume here — Robbery odds and discovery reel (September 16)

The user requested visible robbery loot odds and a dramatic item reel, then
approved **a compact non-blocking reveal on discovery** and **making Volt
Scrambler Legendary** so the shop can actually award a Legendary ride.

- `CrackState.loot` now contains the authoritative bonus-item odds. Shops
  show the overall clean-crack item chance and conditional rarity chances;
  locked Wheels & Kit shows 0% and rank 2 / 100 completed robberies. Eligible
  player skins show 100%; owned/protected/capped/in-transit skins show 0%
  with a reason. Resident piggies explicitly show 0%, coins only.
- `Config.shopLootOdds` builds the same eligible weighted pool used for the
  actual roll, displayed rarity odds and discovery reel. Unowned items are
  preferred; a completed collection uses the existing coin resale fallback.
  Event/pass-exclusive items stay excluded. The overall shop rates are unchanged.
- Fresh ride collection, conditional on a 3% drop: Common 76.63%, Rare 16.09%,
  Epic 5.75%, Legendary 1.53%. These change with ownership. Volt Scrambler now
  has explicit Legendary rarity; Hoverdisc stays event-exclusive.
- `RobberyLoot` draws a 2.5-second compact reel with real item model previews,
  server-selected winner, rarity colour/pulse, and carried/owned/resale status.
  No full-screen shade, input-blocking frame or client-side award. It queues
  discoveries and cleans up cards/models/listeners. Rotation updates the layout.
- Player skin preview and actual theft share eligibility logic, preserving
  recovery priorities, insurance and cap rules. Tests cover those conditions.
- **1,396 isolated checks across 21 suites pass.** Native phone fixtures
  verified readable odds text, exact Legendary winner, non-active reveal
  frame, fitting labels and automatic cleanup. Images are in
  `assets/robbery-ui/`. The fixture sends cosmetic packets only and changes
  no balances, stock or owned items. Its temporary runtime script was removed.
  This is component validation, not the still-pending multiplayer gameplay gate.
- All 103 production scripts compile and match Studio after fixture removal;
  the final Rojo build and whitespace checks pass. Studio remains in Edit
  with Rojo connected. No place was published.

The earlier rank/drop implementation and remaining plan work are below.

## Windows Phase 4.2 update (September 16)

The user explicitly approved implementing Phase 4.1 while keeping the older
multiplayer/mobile checks pending, then requested the next step, Phase 4.2.
Phase 0 is still deferred. The previous checkpoint below is historical.

- **4.1 implemented:** ranks 0–4 at 0/25/100/400/1,600 lifetime robberies.
  `Config.getRapSheetRank` derives rank from the existing saved counter.
  Residential signs show earned stars in a separate row; rank zero is labelled.
  CosmeticsService loads the rank on join; successful coin/Acorn getaways
  refresh it immediately; release clears it. No additional saved counter.
  Names/boasts retain their former dimensions; the board extends downward.
- **4.2 implemented:** shop drop chances are piggy 10%, home 8%, gear 3%,
  defend 20%. Gear requires rank 2 before rolling, including resale fallback.
  Missing data/unknown shops refuse. `auditSkinSteal` compares against the
  largest configured shop chance and rejects invalid probabilities.
- Tests exercise 99→100 for coin, Acorn and skin-only getaways and exact
  star counts. The real shop-drop function gives rank 1 no rides in 200
  attempts, six eligible rides in 200 evenly spaced draws, and 317/10,000
  (3.17%) in a seeded random run. Carry, duplicate resale, consumables and
  audit checks use isolated data, never the user's saved balances.
- The test runner now reads UTF-8 explicitly for Windows compatibility.
  This machine's official Luau 0.738 tools are temporarily installed at
  `%TEMP%/codex-luau-0.738/`; the helper is not a repository dependency.
- Studio/Rojo reconnect verified all 102 sources against the Mac checkpoint.
  Phase 4.1 boots successfully; its live rank-zero sign has fitting owner,
  rank and boast text. Final visual review was stopped by the user with Escape.
- Live phone hotbar checks passed reorder in both directions and cancel by
  dropping outside the bar, with unchanged item stock. Original order was
  restored. This is not a full touch/multiplayer/persistence review.
- **4.2 verification:** all 45 new shop-drop checks, 133 theft checks and
  185 audit checks pass. Both changed runtime scripts compile; Rojo builds
  and `git diff --check` passes. Studio Config/HeistService source hashes
  match disk; a fresh Play reaches Ready with no new feature errors.
  Existing unset-pass, MaxPlayers and stale mane-size warnings remain.
  Studio is left in Edit, connected through Rojo. No place was published.

**Next:** Phase 4.3 starts with the effects coin shelf and has a design gate;
read MASTER-PLAN §14, §18.2 and Art 11 before building new assets. Keep the
Phase 3.3 multiplayer exits, 3.4 badge/recovery visual checks, remaining Acorn
drag/getaway review, full mobile HUD review and rank-sign visual review open.
Do not claim those gates passed. Phase 4.4 is still blocked on its prerequisites.

This work is local and uncommitted. At the start of 4.2 the working tree also
contained deletions under `assets/dogs/` from outside this task; they were not
changed or restored as part of these rank/drop steps.

## Earlier September 16 checkpoint

This checkpoint is intended for `main` on
`https://github.com/antoniofodor/Rob-A-Piggy-Bank`. The user requested that all
current project changes be committed and pushed before moving machines.
Use `git log -1 --oneline` to identify the checkpoint after pulling.

### Start on the other machine

1. Pull `main` (or clone the repository) and open this project folder.
2. Install/use **Rojo 7.7**, Python 3 and the official Luau CLI. Blender is only
   needed for asset authoring; runtime assets already reference uploaded Roblox
   mesh/texture IDs and the committed guard templates.
3. Run `rojo serve default.project.json --port 34872` at the project root.
4. Open **Rob A Piggy Bank**, place ID **135433647855162**, in Roblox Studio.
   Connect the Rojo plugin to `localhost:34872` in **Edit mode**, allowing its
   script-modification permission. Connecting from Play's Client causes
   `Http requests can only be executed by game server`.
5. Enable Studio MCP and confirm the tool connection identifies that place.
   The repo's `.mcp.json` is a Windows launcher; configure Studio's MCP for the
   destination OS. The previous Mac's `/tmp/piggy_studio_mcp.py`, `/tmp/piggy-rojo`
   and `/tmp/piggy-luau` helpers are **temporary and not part of this checkout**.
6. Verify Rojo source sync, then start Play and check startup output. The last
   Phase 3.4 sync attempt found Studio with **no place open**, so that feature's
   live sync/startup/layout verification has not been completed.

### Current implementation and approved decisions

- Master plan foundation through **1.10**, separate tree/ground/storage Acorn
  loop through **2.5**, and carry handoff/keep/return code through **3.3** are
  implemented. Detailed validation limits are recorded in the entries below.
- **3.4 is implemented on disk:** cream street badges distinguish NEW HERE,
  SHIELD, ROBBED, EMPTY and CAPPED; no Acorn counts on the street badge.
  Owners see **RECOVER SKIN**, others see HOT SKIN. The private recovery task
  shows the actual stolen skin thumbnail and timer; select it for details.
- Acorn theft cooldown appears **only on nearby tree/crate prompts**, with an
  hourglass and **Steal ready in m:ss**. Player cooldowns are private and shared
  across both sources; resident rest remains shared. Own harvesting is exempt.
- Recovery remains tied to the last taker of that owner's particular skin,
  independent of the robber's outfit or later thefts from other players.
  Multiple owners retain separate claims and timers against the same robber.
- The approved exploratory mockup is archived at
  `docs/design/rob-badge-mockup.html`. It is the conversation HTML fragment;
  it uses host-provided Lucide/Tweak helpers. It is a design reference, not a
  Studio screenshot. The nearby cooldown cue was approved after that mockup.
- Imported guards are integrated; see `assets/guards/README.md` and the guard
  entry below. Phoenix art/generator/validation/effect companion work is also
  included; see `assets/phoenix/README.md`. **Phoenix runtime skin integration,
  real imported-asset placement and published animation ID remain pending.**
- Generated `.glb`/`.fbx` exports and Blender outputs covered by existing
  `.gitignore` rules are regenerated with the committed scripts. Asset folders
  document their rebuild/import steps; no dependency on those ignored exports
  is needed to run the currently integrated guard/tree/crate gameplay.

### Next work, in order

1. Verify 3.4 in Studio: four badge states from pavement distance, own/bystander
   skin tags, task thumbnail and expand/collapse on phone/desktop, countdown
   expiry, and tree/crate cooldown visibility only at interaction range.
2. Finish the **3.3 two-player pursuit, return and keep** test, including both
   clients' toasts, carried poses, transferred skins and recovery targets.
3. Complete the outstanding live Acorn drag/catch/getaway and full mobile HUD
   review. Earlier native component bounds tests are not full gameplay passes.
4. Continue **Phase 4.1 (robbery ranks and plot-sign stars)** after those gates,
   unless the user explicitly chooses to advance earlier. Follow
   `docs/MASTER-PLAN.md`; do not restart completed implementation steps.

### Last verified checks

- **1,267 isolated checks across eighteen suites**, **102 Luau scripts compile**,
  Rojo build succeeds, and `git diff --check` is clean.
- Example targeted command:
  `python3 tests/run-crates.py --luau /path/to/luau --suite badges`.
  The runner's `--help` lists all suites; the default runs only `crates`.
- Build: `rojo build default.project.json -o RobAPiggyBank.rbxlx` (ignored output).
- No live player balances/saves were changed by these checks. No Roblox live
  place publication was performed. Studio visual checks are still pending.

## Imported guard integration — 2026-09-16

- Replaced primitive guard geometry with the eight imported mesh creatures;
  preserved gameplay anchors, kennel/toys, coat/name cosmetics, bait, sleep,
  cooldowns and paid guard-duty vest.
- Five defaults: Terrier, Shepherd, Mastiff, Dire Wolf, Cerberus. Gorilla and
  Raptor are tier-4 wardrobe skins (250k each); Triceratops tier 5 (500k).
  Tier 4/5 upgrades follow existing 5k × 2.6^level pricing; new stats in Config.
- `GuardVisual` repairs Root-attached facial/foot meshes from authored report
  bone assignments. `GuardAnimator` runs local Motor6D motions and red eyes
  from authoritative `GuardState`; all three Cerberus jaws are independent.
- Mesh IDs, sizes and original mesh extents recorded in `assets/guards/studio-imports.json`.
  `blender/guards/build_runtime_assets.py` generates the catalog and eight
  ServerStorage RBXMX templates, mapped in the Rojo project.
- Source imports archived in Studio ServerStorage.GuardImportArchive.
  No hellhound/silverback in the active catalog. No live-place publication.
- Studio regression fixture: `tests/studio/guards.luau`. All eight rigs passed
  part/bone/coat/upgrade/duty/reset/catch/bait/sleep tests. The 54 save and
  90 rebirth checks also passed. Temporary test scripts/fixtures removed;
  Studio left in Edit mode. Client sampling verified six
  red Cerberus eyes and independent moving jaws. Viewport capture timed out;
  direct screen capture returned desktop wallpaper, so no screenshot QA pass.

## Earlier reconnect notes — September 15

**Mac reconnect update — 2026-09-15:** `main` is current and the Rojo 7.7
checkpoint builds. Studio MCP connects to the correct place, and Rojo's Edit
session connects to `localhost:34872`. All 89 project scripts matched disk;
a temporary module also confirmed live file syncing and was removed. Allow
Rojo's script-modification permission when prompted. Connect Rojo in **Edit**
mode: connecting from Play's Client produces `Http requests can only be
executed by game server`.

The iPhone 17 Pro landscape HUD loaded (750×361 safe-area viewport), but this
Mac's MCP viewport captures timed out. Direct Edit-mode regression snippets
also hit Studio's script-capability restrictions when requiring/cloning game
modules. These are incomplete checks, not a verified HUD pass. Pointer drags,
boost-state visuals, desktop/Android review and persistence remain pending.

The user paused the session to move to another machine, then requested a
commit and push of the current changes to `main`.

**The user has resumed the master plan despite the pending HUD review.** Prior
HUD request: move the left menu farther left, replace the oversized/ugly
`USE 2x` boost HUD, fix dragging/reordering hotbar items, and redesign the
next-event countdown. The implementation is on disk and synced through
Rojo, but the latest changes still need a live Studio play-test and visual
review. Do not report this HUD pass as fully verified yet.

## Latest development — Phase 3.4 badges/recovery/Acorn cues (September 16)

- User approved the cream-card mockup, then removed the Acorn street row.
  Tree/ground/crate contents remain visible on the props. RECOVER SKIN replaces
  YOUR SKIN for the rightful owner; other viewers see HOT SKIN.
- RobBadge now distinguishes NEW HERE from SHIELD and follows server refusal
  order through ROBBED, EMPTY and CAPPED. Rush worth and unlocked casing pips
  remain. Server publishes public cap/hot deadlines without claimant identities
  or skin keys. Income/refunds/reacquisition/expiry clear applicable states.
- FirstJob retains existing private authoritative recovery objectives, now as a
  compact task with the actual claimed skin's model and countdown. Tapping
  expands details. CHASE/HOME cover transported copies; claim priority and
  independent stacked deadlines stay unchanged. Buy-back still opens Crates.
- Nearby tree/crate prompts show an hourglass and Steal ready in m:ss. Private
  player-target deadlines share both sources; resident rest remains shared.
  Own harvesting is unaffected. Late subscriptions receive only their own
  snapshot; no client timer is accepted. Expiry restores ready prompts locally.
- **1,267 isolated checks pass in eighteen suites; all 102 source scripts
  compile, Rojo builds, and whitespace checks pass.** Checks include cooldown
  privacy/source switches/expiry, changing plot owners, exact-key thumbnails,
  thumbnail reuse/cleanup, stacked tags and live cap income/refund transitions.
- Rojo is serving this project on localhost:34872. Studio MCP initially found
  the place in Edit, then reported **Place is not open** during source checks.
  User has been asked to reopen it. Live source-sync, native layout/input and
  the 3.4 pavement screenshot remain pending; do not call the visual gate passed.
  The earlier 3.3 live two-player pursuit/return/keep gate also remains pending.

## Latest development — Phase 3.3 keep/return settlement (September 16)

- Implemented both drop-offs using the existing empty `DeliverRequest`.
  Server checks living holder/claimant, actual 3D position, current destination
  occupant and no active crack/collection. Acorns drop at crates; coins use the
  existing pig/plot radius. Returning your own intercepted haul is a return.
- Original claimant payouts remain unchanged. Other keepers receive half the
  RAW coins/Acorns rounded down, plus all carried items, with no revenge/spree/
  rebirth multiplier. This resolves conflicting plan wording in favor of its
  explicit 0.5x anti-farming example. Keeping counts one completed getaway.
- Returns restore all raw currency/items; Acorn receipts restore storage or
  ground as appropriate. One 25% bounty, floored, goes to the return deliverer
  in the returned currency. Own harvests and claimant undos mint no bounty.
  Returns do not count robberies or mint a coin reward for returning Acorns.
- The final keeper receives the skin and becomes its recovery/revenge target.
  Intercepted recoveries preserve the original recovery owner's claim against
  the final keeper. An interceptor gets no insured spare; the original owner
  can still recover that exact insured copy. Unrelated claims remain intact.
- Both destinations, owner names and reward amounts now appear on a carry card
  via `CarryDelivery` / `LootHaul`. KEEP/RETURN uses the existing tap/F request.
  Item-only carries work. The old carry banner is replaced to avoid overlapping
  the card; crack/collection panels hide the card and action while active.
- **1,219 isolated checks pass** across seventeen suites, including 76 new
  settlement and 15 presentation checks. Four old identity checks were retired
  because non-claimant delivery is now supported. **102 scripts compile**, Rojo
  builds, and Studio Play reaches Ready without feature errors.
- Native client fixtures cloned the real card/button and confirmed unclipped
  labels, in-bounds controls and an 8px gap at 1399×793, 750×361, 480×320 and
  320×568. These are component layout checks, not a complete mobile HUD review.
  Fixtures changed no player balances/saves. Existing pass-ID/MaxPlayers/mane
  warnings remain; concurrent guard work is separate.
- **Still required for the plan's 3.3 completion gate:** a live two-player
  pursuit, return and keep session, checking both players' toasts and carried
  poses. Isolated player/physics doubles are not that multiplayer verification.
  After that, 3.4 is the badge-row design/art step.

## Latest development — Phase 3.2 completed-tug handoff (September 16)

- Completed player tugs now move the same loot model, prompt and carry record
  to the winning nabber. `claimant` and victim remain fixed; `holder` changes.
  Coins, whole Acorns, source receipts and staged skins remain intact.
- Ticks advance time/contribution only: no per-tick refund, amount reduction or
  minted bounty. The first tick waits its interval; a clean tug takes one second
  regardless of crowd, currency or a haul-only carry. Opening closes the current
  crack/collection round. Highest eligible contribution wins; ties use join order.
- The old holder is empty-handed and loses the carry slow without a stun. The
  winner gets carry speed, loses shield/sneak, and gets three seconds of rest.
  Victim markers, prompt owner text and both HUDs follow the transfer. The prompt
  binds to the record's current holder, allowing the original claimant to nab it
  back after rest. Only successful handoffs award catch credit/effects.
- Transfer rechecks live nearby characters, empty hands and the exact root weld.
  Missing/dead/departed/busy winners or broken attachments preserve old escrow.
  Per-tug/carry tokens prevent old coroutines from touching replacement attempts.
  Confiscation/delivery invalidates a tug; those endings do not award catches.
- Dog and patrol paths retain full refunds and haul return; dog stun is unchanged.
  Acorn collection cannot append to a non-claimant's transferred basket.
- **1,132 isolated checks pass** in fifteen suites, including **78 new handoff
  checks** executing the actual private transfer, public nab, prompt callback,
  timed coroutine, cancellation and confiscation paths with player/physics doubles.
  **101 source scripts compile**, Rojo builds, and whitespace checks pass.
- Fresh Studio Play reaches Ready with no handoff/startup errors. HeistService
  and Config exactly match the running server sources after Rojo sync. Existing
  pass-ID and MaxPlayers warnings remain. Live two-player welding/pose and pursuit testing
  is still pending; isolated physics doubles are not a multiplayer visual pass.
- **Next: 3.3**, victim-return and alternate-holder keep payouts/drop-off choices.
  Current non-claimants carry and can be re-nabbed, but do not cash out until that
  step. Original-claimant delivery is unchanged; unusable home delivery prompts
  are suppressed for non-claimants in the meantime.

## Latest development — Imported storage crate + Phase 3.1 (September 16)

- Integrated the user's imported `Workspace.AcornStorageCrate`: four mesh
  parts, shared atlas, measured bottom-centre offsets, 3.6 × 1.9 × 2.8 XYZ.
  All residential plots now clone cached templates. The existing `Storage`
  floor remains an invisible interaction/fill anchor; mesh-load failure keeps
  the complete wooden fallback. The woven transport basket is unchanged.
- Archived the Studio IDs/measurements and a portable assembly under
  `assets/crate/AcornStorageCrate.json` / `.rbxmx`; Blender source remains there.
- **3.1 implemented:** `Carry.claimant` records the original grabber and
  `Carry.holder` records the player whose character carries the loot. One
  constructor initializes both after successful crack, smash or Acorn catch
  attachment. Additional slices/catches retain the existing identity.
- Both delivery entry points validate holder and claimant. Original-holder
  coin, skin and Acorn payouts remain unchanged. Missing/mismatched identities
  cannot settle and leave escrow intact. Phase 3.3 will add non-claimant
  settlement; Phase 3.2 transfer is not implemented yet.
- **1,054 isolated checks pass** across all fourteen suites; **98 source
  scripts compile** and Rojo builds. Tests cover both crate orientations,
  mesh cache/failure cleanup, retained floor anchor and refused-delivery escrow.
- Fresh Studio Play verified ten crates / forty imported parts, correct atlas,
  anchors and non-colliding visuals. The real-client display fixture passed
  0/3/8/24/200/0 stored counts, independent tree/ground contents and cleanup.
  No feature boot errors; existing pass-ID, MaxPlayers and stale mane warnings
  remain. Fixtures only change local display objects, never player balances.
- All 101 current sources match Studio Edit after the final sync (additional
  scripts arrived from concurrent work after compilation). Studio left in Edit.
  Live pointer collection, carried-pose review and end-to-end getaway remain
  pending; structural/display checks do not replace those play-tests.
- **Next: 3.2**, completed tug transfers the intact carry to the winning nabber
  while retaining claimant; then 3.3 adds the victim-return/alternate-holder exits.

## Latest development — Phase 2.5 resident Acorn supply (September 16)

- Implemented `ResidentAcorns` and real ResidentService seat/tick/evict wiring.
  Each residential plot gets four starting Acorns total: two ripe, two stored.
  The seed happens once per plot per server lifetime; shops have no Acorn stock.
  `resident.acornStock` is separate from resident carried coin `.loot`.
- Same one/hour tree growth and eight-ripe cap as players. Stored balance does
  not stop growth. A crop starting on an empty tree waits fifteen minutes;
  a resident at home then banks ripe stock. Ground leftovers and live collection
  leases postpone harvest. This conserves stock and introduces no new NPC
  harvest/carry animation. Coin production/raids stay unchanged.
- Valid resident Acorn openings start a shared 15-minute deadline across all
  thieves and both sources. Invalid/empty openings consume nothing. Prompt
  counters show RESTING m:ss and restore ripe/stored counts at expiry.
  Player-target Acorn cooldown remains 60 seconds per thief/victim.
- Claiming a property freezes resident production/harvesting. Releasing it
  restores the same stock and partial growth hour, never a new seed or a
  hidden growing tree. Raid/ground expiry remains real-time. Old in-flight
  receipts refund retained stock without crediting the new player occupant.
- Corrected the new-growth economy model, which previously counted some
  player crops as both own harvest and theft. Full capture at parity gives
  10 solo / 5.25 full per player-hour; own-harvest-only capture gives 1.25 at
  eight players. These are fresh-production scenarios, not observed earnings
  or an all-income ceiling. Initial seeds and re-raids of existing storage
  are excluded. No growth rate, payout multiplier or crate price was changed.
- **1,004 isolated checks pass**, including 36 resident stock/service checks,
  eight new shared-cooldown/refund checks and native-prompt behavior covered
  by both isolated and real-client fixtures. **97 scripts compile**, Rojo
  builds, and all source scripts match Studio Edit. Fresh Play boots cleanly
  for this feature; existing pass-ID and max-player warnings remain.
- Real client verified all nine resident houses at 2 ripe + 2 stored, using
  imported Acorn visuals and enabled H/J prompts; all four shops excluded.
  Local countdown fixture verified RESTING → counts and no cooldown leakage
  to a new player occupant. Fixture removed; no player balance/save edited.
- Natural 15-minute/one-hour timing is covered with deterministic clocks,
  including a 24-hour conservation run and actual ResidentService integration.
  Live player drag/catch/getaway and carry-pose review (2.4) remain pending.
- Updated master-plan §§3–5, §17, Phase 2.5 and `docs/GAME.md` to match.
  Final generated storage-crate art was integrated in the later 3.1 entry above.
- Next implementation: **3.1**, separate a haul's original claimant from its
  current holder, before the Phase 3.2 completed-tug transfer.

## Latest development — Tree → carry basket → storage crate (September 16)

This designer-approved correction supersedes the older 2.2/2.3 behavior below.

- Trees now grow into saved `treeAcorns` (one/hour, eight ripe maximum),
  independently of stored `loot`. Existing Acorn balances remain banked and
  are never copied into the tree. Offline/partial-hour growth is retained.
- H/Y at a tree opens a five-second collection round. One ripe Acorn is
  sufficient. Shaking moves ripe stock onto the ground; drag the offered
  Acorns into the carry basket. All icons stay available through the timer.
  Missed ground stock lasts 60 seconds and can be collected again. Tree and
  ground counts/timestamp persist; reconnecting cannot replay a harvest.
- Owners harvest without an alarm, theft cooldown or loss cap, and can retry
  leftovers with their own harvest basket. Own deposits pay one-for-one;
  they never count robberies, create grudges or consume revenge.
- J/X at another property's storage crate opens the same timed drag round.
  Quarter-share storage raids offer at least one if stock exists, bounded by
  four net losses per victim per rolling hour. Tree theft uses loose supply,
  independently of that storage budget. Both theft sources share the 60-second
  thief/victim cooldown and existing owner/dog/interruption protections.
  J avoids the hotbar's existing R binding.
- Imported woven baskets are exclusively transport. Residential properties
  have an open wooden `AcornStorage` blockout, 3.6 wide × 2.8 deep × 1.9 tall,
  at the old basket location. Carry delivery is at one's own crate. Storage
  labels always show the exact balance, including zero and 200; no PACKED.
  Imported Acorns are visible in tree, on ground, in storage and in carry.
- Source-tagged receipts preserve refunds: storage returns release matching
  loss receipts; tree returns go to loose ground with a fresh collection
  window, never directly into the wallet. Death/departure settlement still
  occurs before saving. Concurrent reservations and catch replay checks apply
  to both sources. Final tree/storage visual parts do not affect physics.
- **937 isolated checks pass**, all **96 source scripts compile**, Rojo builds
  and all 96 sources match Studio Edit. Fresh Play boots without Acorn errors.
  Real-client display fixtures passed exact 0/3/8/24/200/0 storage labels,
  eight stored plus eight ripe, shake-to-ground, catch/expiry and cleanup.
  Only local display fixtures were changed; no player balance was edited for
  tests. Final Play confirms ten crates, own harvesting enabled, own storage
  raiding disabled, nine other raid prompts on J, and a 440×284 collection
  panel. Existing pass IDs/player-cap warnings remain.
- **Live pointer collection, carried pose and end-to-end deposit still need
  play-testing.** The panel is a close-up representation of loose ground or
  crate contents; world Acorns are synchronized decorative models.
- Final crate art is pending import. Prompt and asset contract:
  `assets/crate/BLENDER-PROMPT.md`. Master plan sections 4–5 and Phase 2 plus
  `docs/GAME.md` describe the revised behavior.
- Next: Phase 2.4 live carry/gesture review, then 2.5 resident supply. Resident
  seeding/harvesting/regrowth/cadence remain unimplemented. Previous supply
  audit numbers are explicitly marked as needing tuning for separate stock.

## Latest development — Phase 2.3 shake and imported Acorn

- Implemented `HeistService.shake` / `ShakeService` and `Shared/Shake`.
  Residential trunks offer a half-second SHAKE hold on **H** (gamepad Y);
  client hides your own prompt and prompts while carrying/shaking. Shops
  receive none. Opening sounds the alarm, alerts the owner, drops the
  thief's shield/sneak and invokes the existing dog response.
- Four-second panel uses Theme's existing Acorn glyph, 56px drag targets,
  a 160×50 basket target, countdown, confirmed caught count and RUN. Mouse
  and touch each own their gesture; unrelated touches cannot finish it.
  Controller A catches a selected Acorn. The canopy shivers on all clients.
- Server schedules each Acorn, accepts only its unique attempt/index in its
  lifetime and rechecks range, life, stun/bin/ride state, owner interruption
  and plot occupant on every catch. Takes a floored quarter, at most four
  per victim in an actual rolling hour. Concurrent reservations share that
  budget. Repeat shakes wait 60 seconds; refusals name the reason.
- Added the carry settlement needed by 2.3/2.3a: catches debit one raw Acorn
  into a carried basket; only delivery at your own basket applies x1 for a
  resident or x5 + rebirth difference for a player, doubled for revenge.
  Coin/spree/friend/event bonuses do not multiply Acorns. Delivery counts one
  robbery, creates a player grudge, and keeps coin totals/weekly stats separate.
- Basket carries use existing slow/dodge/bin/jam/nab/patrol paths. Tug recovery
  returns whole Acorns without a coin bounty; dog/patrol/death and either
  participant's departure refund raw receipts. `DataService.onBeforeRelease`
  settles basket escrow before the final save. Receipts prevent duplicate
  refunds or an old return clearing newer losses from the rolling cap.
- User imported `Workspace.acorn` during this task. Wired its Nut/Cap/Stem
  mesh IDs and texture into `Config.ACORN_MESH`, with Studio-measured offsets
  and bounds (0.594×0.827×0.594). `AcornModel` prewarms a replicated template
  for basket fill, growth drops and carried contents. The original uploaded
  assembly is archived in `assets/acorn/acorn.json` and `acorn.rbxmx`; the
  original source GLB is still unavailable. 2D panel/HUD glyph is retained.
- **894 isolated checks pass**, including 36 shake authority, 36 basket
  settlement and 36 mouse/touch/controller/layout checks. All **95 scripts**
  compile, Rojo builds, and all 95 match Studio in Edit. Fresh Play boots with
  no shake/Acorn runtime errors. Existing pass IDs/max-player warnings remain;
  this boot also reported an unrelated stale mane mesh dimension warning.
- Running client verified ten shake prompts, own prompt disabled, and a
  440×284 panel / 56px targets / 160×50 basket inside a 750×361 test viewport.
  Imported fill fixture passed 0/3/8/20/0 counts, white tint, exactly three
  MeshParts per Acorn, no collision/query/touch and cleanup/re-entry.
- **Live drag/catch/delivery and visual review remain pending.** MCP refused
  a synthetic `ShakeState:FireClient` because of script capabilities; no
  bypass attempted. The mouse test therefore had no panel to operate on.
  Native computer-use capture also failed to initialize on this Mac. Isolated
  gesture tests are not a live phone pass. Temporary fixture vanished on
  restarting Play; no player balance/save was edited for testing.
- Next: **2.4 carry presentation/engine review** (core safe settlement is
  already in place); **2.5 resident basket seeding/regrowth and 15-minute
  cadence remain unimplemented**. Residents currently have no seeded Acorns;
  their existing `.loot` continues to mean stolen coins, never Acorns. Full
  shake economy audit figures remain modeled until resident supply lands.

## Latest development — Phase 2.2 growth and basket fill

- User approved the 2.1 oak/basket appearance. Implemented hourly Acorn growth
  in the existing server economy loop and offline-income path. Eight hours
  fills an empty wallet to eight; balances above eight are preserved.
- Saved `acornsGrownAt` retains partial hours through autosave/rejoin. Legacy
  saves use `lastSave` within the eight-hour allowance. Invalid/future cursors
  reset safely; time spent full is discarded. Income, friend and daily boosts
  do not multiply growth. The pig being full does not stop Acorn growth.
- `PLOT_ACORNS_ATTRIBUTE` publishes the wallet on the residential plot. The
  client draws up to eight Acorns inside the basket and PACKED above eight.
  HUD/crate/shop affordability follows the exact balance through StateUpdate;
  other services' balance changes repaint within one economy tick. Ownership
  changes clear the display; delayed/streamed/replaced plots are handled.
- `AcornGrown` is a server-only cosmetic cue for a falling Acorn on live growth.
  Offline catch-up draws the final pile silently. Client parts are anchored,
  non-colliding/non-queryable/non-touching, with bounded, cleaned-up flights.
- **Art limitation:** the plan's `assets/acorn/acorn.glb` is missing in this
  checkout; no named standalone Acorn was found in Studio. The fill uses small
  two-tone modeled Acorns from `AcornFill` until the intended mesh is supplied.
  Full/empty readability and the drop's appearance still need visual review.
- **784 isolated checks** pass, including 40 growth, 43 client-fill lifecycle,
  and 49 save checks. All 92 source scripts compile and Rojo builds. All 92
  match Studio through Rojo in Edit. Restarted Play boots without new errors.
- The actual running client passed temporary-fixture checks at 0/3/8/20/0:
  exact capped fill, PACKED only above eight, no physics/query/touch effects,
  and removal/re-entry cleanup. Fixture destroyed; no player balance/save
  was edited. Live growth/drop timing is covered by the isolated economy and
  renderer tests; the hourly production clock was not accelerated.
- Next: **2.3**, the shake interaction and its Art 4 panel design. Resident
  basket seeding/regrowth stays in 2.5; resident carried coin `.loot` is not
  used as an Acorn wallet. Shaking/carrying are not implemented yet.

## Latest development — Phase 2.1 basket integration

- Finished the residential tree/basket placement foundation. `AcornBasket`
  loads the imported hollow bowl and handles once, then clones the assembly
  at plot-local (-20, 16), beside the oak at (-25, 16). It follows both plot
  orientations and stays on the lawn across ownership changes. Shops get
  neither a tree nor a basket.
- Mesh/texture references are in `Config.ACORN_BASKET_MESH`, with measured
  offsets and original dimensions. Both parts are anchored, non-colliding,
  non-queryable and non-touching. `plot.acornBasket` keeps body/handle refs
  for the later fill and carry work. No saved balance or earnings changed.
- Studio Edit checks loaded the real uploaded assets and measured both rows:
  0.625 studs clear of the oak wood bounding box, 8.35 from the front fence
  and 12.33 from the side fence; bottom at lawn height. Temporary fixtures
  were removed. The prior `lawnI` migration still shelves owned decorations.
- **689 isolated checks** pass, including 89 oak/basket checks. All 91 source
  scripts compile and Rojo builds; all 91 match Studio in Edit mode through
  Rojo. Full in-game visual review remains pending.
- Next: **2.2**, online/offline growth and the Acorn fill display (up to eight,
  then PACKED). The basket is currently empty scenery; filling, prompts,
  shaking and carrying are not implemented. Art 7's full/empty readability
  check remains tied to that display.

## Latest integration — imported compact oak

- The designer imported `assets/tree/blender/oak.glb` into Studio. Recorded
  its uploaded mesh/texture references in `Config.ACORN_OAK_MESH`; all
  residential plots now build this 8.5-stud oak, including resident yards.
  Shops remain tree-free. Street `TREE_MESH` is unchanged.
- Used Studio's measured offsets: the importer reverses X/Z relative to the
  GLB report. The builder keeps the white texture tint and the ground pivot.
  A 1.3 × 3.4 × 1.3 invisible trunk collider prevents the branch mesh's wide
  bounding box from blocking empty lawn. Visual meshes do not collide/query.
- Studio Edit checks loaded both uploaded meshes through InsertService,
  verified dimensions, grounded both plot orientations and tested raycasts
  against the trunk/open branch space. Side/front fence-line clearances are
  4.37/6.54 studs. Temporary check geometry was removed; no player save used.
- All **655 isolated checks** pass, including 55 oak checks. All 90 source
  scripts compile and Rojo builds. All 90 scripts match Studio in Edit mode
  through Rojo. A full in-game visual/collision walk-through remains pending.
- Basket placement is now implemented above. Fill display/growth continue
  in 2.2. The old generated oak source stays available as a fallback.

## Latest asset work — compact Blender oak

- The designer installed Blender and asked for a smaller oak based on
  `assets/tree/tree-oak-render-v2.png`. Built an editable candidate with
  separate `Trunk` and `Canopy` meshes in `assets/tree/blender/oak.blend` and
  a textured `oak.glb` export. Source: `blender/tree/build_oak.py`.
- Size: 8.5 studs wide, about 9.25 tall and 4.68 deep. Trunk: 2,400 triangles;
  canopy: 6,400; one 256px base-colour texture. No acorns or basket are baked
  into the tree. The character comparison uses a 5.5-stud block scale guide.
- This is a Blender draft modeled against the approved reference, not an
  automatic image-to-3D reconstruction. The designer subsequently imported
  it; runtime integration and numeric checks are recorded above. The previous
  generated oak remains a fallback. In-game visual review remains pending.
- The installed Blender's bundled NumPy fails against this macOS version;
  a static GLB exporter avoids it. `blender/tree/validate_glb.py` independently
  checks the exported binary and texture. Multi-view and scale previews live
  beside the model. Phase 2 is still incomplete.

## Latest development — Phase 1.10

- Added saved, typed `data.robberies`, defaulting to zero for new and older
  saves without changing schema 25. Existing stolen-coin totals are preserved;
  no historical robbery count is invented. Reconciliation normalizes invalid
  counts to finite nonnegative whole numbers.
- Heist delivery records one lifetime robbery for a nonempty getaway against
  any player, resident or shop. Partial coin hauls and skin-only recoveries
  count; failed getaways, empty carries and repeated delivery requests do not.
  The count is recorded before reward callbacks can save. It survives rebirth
  and uses the existing autosave/final-release path.
- `claims` defaults/reconciliation were already completed in 1.7. The delivery
  increment from 4.1 lands now so progress accumulates before rank UI ships;
  rank thresholds and plot-sign stars remain Phase 4 work.
- Validation: **600 isolated checks** pass (including 37 new DataService
  lifecycle checks, 118 theft checks and 90 rebirth checks). Copying DataStore
  doubles exercise real load/save/release/rejoin and session-lock behavior;
  no live player saves were used. All 89 source scripts compile and Rojo
  builds `/tmp/piggy-step110.rbxlx`.
- Studio was in Play mode during final verification; Edit-mode source sync
  for these changes and live DataStore persistence are not yet verified.
  Stop Play, allow Rojo to sync in Edit, then start a fresh play session.
- Next: Phase 2, starting with 2.1's tree/basket design and implementation.
  Phase 0 remains deferred; 1.3 still depends on the Phase 2 shake system.

## Latest development — Phase 1.9

- Added `Config.auditAcorns` and `Config.auditRandomOutcomes`, warned at boot
  without stopping startup. Main also prints the explicitly labelled tree
  model; tree growth/shakes remain unimplemented Phase 2 work.
- The random-outcome sweep checks crate currencies/prices, authored coin-price
  plus crate tags, actual pool membership (including mixed event sets), pass
  exclusions, guaranteed skin theft, retired rebirth gates, rebirth crate
  existence and the future coin-pack id. `COIN_PACK.productId = 0` reserves
  the later integration point without selling anything.
- **Designer correction preserved:** rebirth still rolls a normal free
  Legendary Crate. A live coin-pack id now warns that it would fund that
  random reward. The approved 40-Acorn full-collection rebirth bonus stays.
- Removed event attendance/per-drone/clear/full-set Acorn payouts and their
  `Config.LOOT` table. Raids keep their coin bounty (including the clear
  bonus) and one free unowned set drop; a full set gets feedback and no
  duplicate/currency fallback. Rush Hour keeps boosted coin steals and has
  no separate attendance payout. No saved balance is migrated or removed.
- Moved 24 crate skins' historical coin-price fields to `sellBasis`, preserving
  their explicit rarities and every sale amount. Unowned crate skins still
  reject direct coin requests; missing `cost` never makes them free.
- Added the planned growth/share/loss constants early so the audit can model
  Phase 2. Its explicit assumptions are one full daily harvest, one passive
  raid/day and two active hours at parity without revenge. Solo/full-server
  rates are **10 / 5.625 Acorns per thief-hour**, with active/passive ratios
  **4.67x / 3.21x**. Full-server common/legendary waits are **53.33 min / 7.11 h**.
  These recompute the plan's rounded estimates; they are not live earning
  rates or a complete launch economy. The current routine tree source is
  still missing; existing balances and the approved rebirth bonus remain.
- Validation: **550 isolated checks** pass, including 167 audit/event checks.
  Every one of the 27 new audit rules was deliberately provoked and restored;
  tests exercise real raid settlement, full-set drops, Rush Hour, stale coin
  purchase requests, boot warning/error handling and unchanged resale values.
  Run `python3 tests/run-crates.py --suite audits --luau /path/to/luau`.
  All 89 source scripts compile, Rojo builds, and all 89 match Studio in Edit
  mode. No live player save was used. Live boot/event/persistence verification
  and Phase 2 earning-rate playtests remain pending.
- Step 1.10 is now implemented above (`claims` landed in 1.7).
  Phase 0 remains deferred and 1.3 still needs Phase 2.

## Latest development — Phase 1.8

- `FirstJob` now shares one card between onboarding and skin recovery. False
  `NeedsFirstJob` retires only onboarding; veterans can still see new losses.
- The private `RecoveryObjective` snapshot comes from HeistService's actual
  haul, timed claims, ownership and seasonal buy-back claims. The client
  subscribes after connecting its listener, retries until its first snapshot,
  and the server polls at 0.25s but sends only changed state. No client claim,
  price or deadline is trusted. Subscription requests are throttled.
- A fresh theft shows **GET IT BACK**, the robber's name and **Nab them now**,
  pointing to the fleeing character. After delivery, it points to the robber's
  pig with the real ten-minute countdown. Its wall-clock deadline is recorded
  alongside the existing monotonic expiry; coin revenge never extends it.
- A carried recovery says **GET IT HOME**, pointing home, including after its
  deadline. When recovery ends, the card becomes **BUY IT BACK — N ACORNS**
  only with a valid unowned seasonal claim. Tapping opens Crates and scrolls
  to that skin; it does not spend Acorns. Expiry flips locally without needing
  a new packet. Buying/recovering/returning the skin clears the objective.
- Stacks prioritize getting a carried skin home, an active chase, then the
  earliest recovery deadline before paid claims, with `+N more` shown. Latest
  takers replace only the same owner's skin target. Insured spares can be
  recovered but never acquire a paid fallback. Missing/disconnected robbers
  fall back to a valid buy-back rather than an unreachable recovery target.
- Card geometry clears the bank/Acorn column on desktop and landscape phones;
  text is bounded/truncated. Shop/bag overlays hide the card and marker.
- Validation: **383 isolated checks** (73 crates, 89 rebirth, 106 theft,
  70 buy-back, 45 objective). Run the new client checks with
  `python3 tests/run-crates.py --suite objective --luau /path/to/luau`.
  Actual theft transitions, private subscription/poll behavior, startup/load
  races, stale clicks, stacked timers, local expiry, navigation and viewport
  bounds are covered. All 89 source files compile and Rojo builds; all 89
  scripts match Studio in Edit mode through Rojo. Engine rendering, live
  multiplayer latency/input and persistence remain unverified;
  no live player saves were used.
- Step 1.9 is now implemented above. Phase 0 remains deferred, 1.3 needs
  Phase 2; step 1.10 is now implemented above.

## Latest development — Phase 1.7

- Losing an owned, stealable skin now saves `claims[key] = seasonIndex`.
  Losing only an insured spare creates no buy-back claim. Claims survive
  rejoining and last through the current five-week season (four active weeks
  plus one rest week, using the existing UTC week epoch).
- Crates shows an exact-skin BUY BACK card beside its source crate, only for
  a current claim whose skin is unowned. Prices are source crate cost times
  `3^rank`: **15 / 45 / 135 Acorns** for common / rare / legendary. The skin
  ladder has three steps; global `epic` does not inflate the legendary price.
- `SkinBuyback` accepts only the skin key. The server checks the claim, season,
  ownership and Acorn balance, then directly calls `SetService.grant`. Its
  save includes the charge and ownership together. No roll/spare is awarded;
  the robber keeps their copy. Repeated requests cannot charge an owned skin.
- Claims stay eligible for the rest of the season, hidden while owned.
  Cosmetic ownership updates refresh crate cards. Requests enforce expiry
  immediately; idle cards expire locally and a server rollover pass clears
  and saves online claims. Reconcile clears offline/invalid claims on load.
- The `claims` default/type/reconcile portion of 1.10 landed before its UI.
  The `robberies` counter remains pending. Only the Phase 5 season clock has
  landed early; ranks/rewards/season UI are still pending.
- Validation: **298 isolated checks** pass (73 crates, 89 rebirth, 69 theft,
  67 buy-back). `python3 tests/run-crates.py --suite buyback --luau /path/to/luau`
  exercises real Config/reconcile/ChestService/SetService and Crates state
  with engine and persistence doubles. It covers price tiers, rejoin, remote
  forgery, reentrant requests, direct grants, rollover and card expiry.
  All 89 source files compile and Rojo builds; all 89 scripts match Studio
  in Edit mode through Rojo. No live player save was used; live purchase,
  input/rendering and DataStore verification remain pending.
- Step 1.8 is now implemented above. Phase 0 remains deferred, 1.3 needs
  Phase 2; step 1.10 is now implemented above.

## Latest development — Phase 1.6

- Clean player cracks now always take an eligible skin; `revengeChance` is
  retired. Ordinary duplicate, protected-skin, spare and hourly-cap rules stay.
- **Designer clarification:** recovery claims stack by original owner, robber
  and skin. Robbing somebody else or changing outfits never erases an earlier
  victim's claim. Only the latest taker of that owner's same skin is valid.
- Each claim lasts `Config.REVENGE.window` from delivery. Coin revenge is
  separate: spending/refreshing it does not consume/extend the skin timer.
- A clean crack recovers one available skin (oldest deadline first) from the
  robber's owned collection, ignoring their outfit, skin-loss cap and spare
  insurance. It still needs to reach home; getting caught returns the copy
  and allows a retry inside the original window. An originally stolen spare
  is restored as that spare, with no ordinary duplicate-spare payout.
- Skin transfers are staged on the carry before any save can yield. Returning
  a carry drains its haul once and only refunds the matching loss window.
- Tests: 67 isolated checks in `tests/luau/theft.luau`, run with
  `python3 tests/run-crates.py --suite theft --luau /path/to/luau`.
  Full HeistService logic runs with service doubles and physical carry cleanup
  stubbed. Multiple victims, timers, latest taker, changed outfits, failed
  getaways, insurance and coin settlement are covered. Live multiplayer input
  and visuals remain unverified; no player saves were used. The 89 rebirth
  and 73 crate checks also pass (229 total). Luau compilation and Rojo build
  pass; Config and HeistService match Studio in Edit mode through Rojo.
- Step 1.7 is now implemented above. Phase 0 remains deferred and 1.3 needs
  Phase 2; step 1.10 is now implemented above.

## Latest development — Phase 1.5–1.5b

- **Designer correction:** rebirth opens a standard free Legendary Crate;
  do not implement next-unowned-in-order rewards. Normal 65% rare / 35%
  legendary odds and duplicate spares apply. Existing equipped skin stays on.
- Full eligible legendary collection still receives 40 Acorns instead.
- Bronze/Gold Leaf/Diamond now belong to `og`, retain explicit rarities and
  can be stolen. Their old rebirth-count ownership gates are removed.
- Schema 25 migrates earned ownership once using historical thresholds 1/3/6.
  Rejoining does not grant duplicates or restore a later sold/stolen skin.
  The retired pity field is removed; coins, Acorns and spares are untouched.
- The rebirth page shows a crate or completion Acorns. Old random-drop/pity
  helpers and unlock announcements are removed; the economy audit catches
  retired ownership gates anywhere in Config.
- Validation: 89 isolated checks in `tests/luau/rebirth.luau`, run with
  `python3 tests/run-crates.py --suite rebirth --luau /path/to/luau`.
  These use real services/reconciliation with engine and persistence doubles;
  no live player data is used. The 73 crate checks also pass, along with Luau
  compilation and Rojo build. All nine modified scripts match Studio through
  Rojo, in Edit mode. Live rebirth/reveal review remains pending.
- Step 1.6 is now implemented above. Phase 0 remains
  deferred. Step 1.3 still depends on Phase 2; 1.10 is now implemented above
  using the existing schema 25 from the ownership migration.

## Latest development — Phase 1.4

- User requested continuing the master plan; step 1.3 depends on Phase 2,
  so step 1.4 is the next independent implementation.
- All crates now charge existing `data.loot` Acorns: Originals/Animal 5,
  Rare 15, Legendary 40, Alien unchanged at 6. No balance migration.
- Server refuses coin/missing/unknown crate currencies before rolling.
  The card and refusal show the shortfall and tree-shaking hint; tree earning
  remains unimplemented, so this is not ready to publish as a complete economy.
- Regular crates retain combining via `Config.canCombineChest` and the
  server's `canCombine` card flag. Event-set crates remain excluded.
- `auditEconomy` catches a non-Acorn crate, separately from coin capacity.
- `python3 tests/run-crates.py --luau /tmp/piggy-luau/luau` runs isolated
  full-service tests without player data. Roblox constructors are stubbed;
  rendering, replication and persistence are outside that harness.
- Validation: 73 isolated crate checks pass; Luau compilation and Rojo build
  pass. Live card properties show correct prices and combine flags on desktop,
  iPhone 17 Pro (750×361) and Galaxy A06 (705×338). Phone title truncation was
  fixed with bounded text sizing; the equivalent live properties and a
  temporary shortfall-label fixture fit on both phones. This is property-level
  validation, not screenshot review; no crate purchases used the live save.
- Studio output showed no crate runtime errors. Existing warnings remain:
  three pass IDs are unset and the place allows 60 players versus Config's 8.
- Step 1.5 and its skin-ownership migration are now implemented above.
  Phase 0 is still deferred; HUD visual/input checks remain open separately.

## Project and workflow

- Game: **Rob A Piggy Bank**; an under-12 cartoon robbery game. Cream panels,
  cocoa outlines, gold coins, pink piggies, static detailed menu icons.
- Read `docs/MASTER-PLAN.md` for sequencing and `docs/GAME.md` for the
  implementation map. **Phase 0 is deferred by the user's instruction.**
- Rojo project: `default.project.json`; local server was on port **34872**.
  Start/connect Rojo on the new machine; do not depend on this host's process.
- Build: `rojo build default.project.json -o <temporary-path>.rbxlx`.
- Place ID **135433647855162**; universe ID **10764556948**.
- `ClientMain.client.luau` is near Luau's 200-local ceiling. Put new UI builders
  in shared modules and avoid adding top-level locals to the client.
- No Roblox publish was performed. Git push is separate from publishing.
- The last observed Studio state was **Edit**, default desktop viewport,
  connected to Rojo. The place was reopened from Studio's recent experiences
  after it closed during this session.
- This Mac used StudioMCP through a temporary Python stdio bridge.
  That bridge and the local Studio ID are machine-specific and not committed.
  Discover/connect the Studio tools available on the new machine.

## Completed earlier: mobile HUD overhaul

- `PiggyPanel.luau`: dynamic vault fill, balance/capacity/income, compact
  phone layout (252×64), larger desktop layout (420×128).
- `MenuIcons.luau`: static, transparent cartoon Options, Stuff and Shop icons.
- `ActionButtons.luau`: static illustrated Dodge, Ride and Sneak controls.
- `HUDLayout.luau`: left menu column; right-thumb actions above jump; ride
  extras positioned separately. All of these came from the user's requests.
- `HotBar.luau`: transparent 3D item previews, stock badges, selection marker,
  overflow paging with up to five mobile items and 44px paging controls.
- `Rebirth.luau`: earlier responsive positioning changes are intentional.
- Prior phone previews are in `assets/mobile-hud`, `assets/menu-icons`, and
  `assets/piggy-hud`. They predate the current follow-up fixes.

## Completed earlier: master-plan 1.1–1.2

- User approved **nut-brown Acorn, green cap, cocoa outline**, matching the
  detailed cartoon menu icons. Do not ask for approval again.
- `Theme.acorn` draws the static glyph in code; `Theme.acornPrice` decorates
  prices and removes its padding/icon when a label changes to owned/equipped.
- `Config.ROLL_CURRENCY` names Acorn/Acorns. **Persisted `data.loot` stays
  unchanged**, preserving existing balances without a migration.
- `PiggyPanel:setAcorns` receives `SetState`; the compact Acorn counter sits
  under the vault's left side, beside the event timer.
- Player-facing currency wording, shop prices, crate price, admin labels and
  carried-goods messages were updated. Internal `loot` names remain where
  they represent saved currency, carried models, remotes or notification types.
- Piggy delivery no longer calls `SetService.award`, includes a currency
  reward in its payload, or names Acorns in receipts. Coin/item settlement,
  revenge coin multiplier and spree coin multiplier remain intact.
- Retired `Config.LOOT.delivery` and `Config.REVENGE.loot`.
- `Config.acornMultiplier(thiefRebirths, victimRebirths, revenge)` is prepared
  for Phase 2: **nil** victim means resident ×1; player starts at ×5, plus
  the positive rebirth gap, then ×2 for revenge. No production caller yet.
- **Tree earning is not implemented.** Crate conversion is now done (1.4);
  the legacy-faucet audit and the other Phase 1 steps are still pending.
- Verified: Rojo build; seven multiplier cases and twelve isolated delivery
  cases in `tests/studio/acorns.luau`; phone HUD/crate visuals; balance
  hydration and spacing; no client errors. Preview images: `assets/acorn-ui`.

## Current HUD follow-up: implemented, needs live review

### Left menu

`HUDLayout.bindMenu` moves x=14 to **x=4 inside the device safe area**.
Check the visible result; the user may want more movement than ten pixels.
Keep the icons reachable and clear of cutouts and the joystick.

### Boost / Use widget

New `HUDWidgets.luau` builds a **60×44** transparent boost control: outlined
cream/gold 2x token, small BOOST caption and stock badge. An active boost
widens to **96×44** with its countdown. Fixed font sizes replace the old
`TextScaled` text. It sits beside the top left-menu icon and follows its size.

ClientMain's existing stock/deadline and `BoostUse` handler are retained;
`HUDWidgets.renderBoost` only renders them. Old competing boost layout code
was removed from `HUDLayout.bindRideExtras`.

### Event countdown

`HUDWidgets.event/renderEvent` replace the old standing countdown builder:
cream outlined ticket, code-drawn green stopwatch, two-line caption/time,
thin progress strip. Authored at 176×40; PiggyPanel's existing compact scale
makes it 132×30. The last-minute state turns the clock/progress gold and says
GET READY. Existing server durations, event gating, active event banner and
police banner logic are retained.

### Hotbar drag fixes

- `InputObject.Position` and GUI `AbsolutePosition` share the same coordinate
  system. Removed the erroneous additional `GetGuiInset()` offset. The ghost
  is positioned using pointer minus the ScreenGui's absolute origin.
- Only the initiating touch can move/end its drag. Mouse movement and release
  are handled separately; joystick touches cannot hijack an item drag.
- The row stays still while aiming. A gold outline previews the nearest
  destination, and the reorder commits **once on release**.
- `HotBarDrag.luau` supplies pure input ownership, target selection and bounds
  helpers. Page-end insertion uses the full arrangement's successor so an
  item does not jump to the final inventory page.
- Releasing outside the row cancels. Shelving requires the explicit compact
  **STORE IN BAG** target; it preserves stock. Previously nearly the whole
  screen above the bar counted as shelving.
- The drag ghost uses the actual slot size. Drag release suppresses accidental
  activation for 0.25 seconds; a fresh intentional press clears suppression.
- Focus loss and viewport resize cancel an active drag.
- **Ladder added to `HotBar.ITEMS`**: its omission caused its saved placement
  to be discarded on the server echo. Appended after raincoat to preserve
  existing item/key order. Server settings allowlist already includes ladder.
- The runtime Remotes dependency is now required only when saving preferences,
  allowing isolated Edit-mode module checks to load without waiting forever.

### Checks actually completed for the follow-up

- Final Rojo checkpoint build passed after the ladder/deferred-Remotes edits;
  `git diff --check` passed too.
- Final `HUDWidgets`, `HUDLayout`, `HotBarDrag`, and `HotBar` module clones
  all loaded successfully in Studio Edit mode.
- `tests/studio/hotbar-drag.luau` passed: left/right neighbour moves, page
  boundaries, empty-stock gaps, no-op drops, touch ownership, mouse input,
  bounds with a negative safe-area origin, and ladder in the save list.
- **Not yet tested:** actual pointer/touch drags, save echo/rejoin persistence,
  boost ready/active/empty visuals, final countdown layout, and runtime errors
  after these UI replacements. The current preview PNGs show the earlier HUD.

## Next actions

1. Pull `main`, start Rojo and connect Studio on the new machine. Preserve any
   local work there before pulling.
2. Build and run a phone play-test. Check the new left menu, boost and event
   widget against the Acorn counter, vault, movement controls and hotbar.
3. Drag items both ways on the same page; verify the final order and key
   labels after the settings echo. Test first/last positions, later pages,
   ladder movement, cancel outside the row, explicit shelving and restoration.
4. Verify a drag does not equip/use/spend an item, and a normal tap still
   selects it. Test a simultaneous movement-stick touch if tooling permits.
   Rejoin to check saved order; restore any test preference changes afterwards.
5. Check boost states using isolated client fixtures if needed. Avoid spending
   the user's saved boost stock solely for a visual check.
6. Check desktop and a smaller Android viewport too, collect current previews,
   and inspect the client error log. Update `docs/GAME.md` with this follow-up
   once the final behavior has been reviewed (it still describes some old
   boost/drag behavior).
7. Continue the master plan alongside the pending HUD review, as requested.
   Phase 0 remains deferred. Step 3.3 is implemented; verify the two-player exits, then design Phase 3.4.
   Step 1.3 depends on the Phase 2 shake system. Respect future
   design gates without reopening the already-approved Acorn icon decision.

## Test execution notes

The scripts in `tests/studio` are Luau snippets for Studio MCP `execute_luau`
in the **Edit** DataModel, after Rojo sync. They do not run automatically from
`default.project.json`. Acorn delivery tests extract the real settlement
function and run it with service doubles; they do not touch player saves.
Avoid testing economy changes by editing the real account's DataService data.

Two initial Edit-mode checks waited for the runtime Remotes folder. A temporary
empty folder released those checks and was removed; subsequent module checks
and drag tests passed. No temporary test module/folder was intentionally kept.

## Repository state at pause

The commit should include the task's source modules, docs, regression snippets
and preview PNGs from this session and the earlier HUD/Acorn work. It is a
checkpoint of work in progress, not a claim that the latest UI pass is done.
The original user-owned `notepad.txt` was already untracked when this work
started. It contains game-design notes and is included unchanged in the
requested checkpoint so it is available on the other machine. Treat these as
notes, not as replacements for the user's instructions or the master plan.
