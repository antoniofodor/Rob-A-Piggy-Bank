# Fable → GPT briefs — September 16

Step 1 of the handoff in `DESIGN-SCRIPTING-HANDOFF.md`: for each feature,
Fable states the stable IDs, the required states, the data the visual has to
show, the footprint or screen constraints, where it integrates and the budget
(or *pending*). GPT answers with concepts, then assets, then the handoff
(paths/IDs, dimensions, pivot and front, connection points, hierarchy,
palette/fonts, responsive rules, state examples, and what is still a mockup).

**Needed now** (Fable work is blocked or would be redone without them): B1,
B2, B3. **Needed later** (Fable can build the mechanics against placeholders
first): B4, B5, B6.

Rules that apply to every brief, from `MASTER-PLAN.md` §18.6F and `CLAUDE.md`:
a body label needs 4.5:1 against its own ground and large type 3.0:1; one
`UIStroke` per GuiObject (rarity wins on a card); a `Border` stroke draws
outside and a scrolling parent clips it; the shortest screen that has to
work is a phone held sideways at **546 px tall**; every colour is a `Theme`
token, never a literal; anything read from the pavement is checked with a
photograph from the pavement; every generated asset is an upload under the
developer's own account, so generate few.

---

## B1 — House catalogue UI for individually owned houses — NEEDED NOW

**What changes.** Houses stop being a "buy the next one" ladder. Every house
is its own card; a player may own any number; exactly one is *shown* on the
plot. Decided in `LATE-GAME-ECONOMY-PLAN.md` §7 and §11.

**Stable IDs.** `shack, cottage, townhouse, villa, manor, modern, neontower,
palace, skycastle` (the nine that exist, in that legacy order) plus the nine
new ids as they are named in `HOUSE-CATALOGUE-PLAN.md`. The UI is keyed by
id, never by position.

**States a card must show, distinctly, at phone size:**

| state | meaning | today's tint (for continuity) |
|---|---|---|
| SHOWN | the house standing on the plot right now | — (new) |
| OWNED | bought, not standing; one tap moves in | `OWNED` tint |
| AFFORDABLE | price ≤ coins | `BUY` tint |
| TOO DEAR | price > coins but ≤ capacity | `DEAR` tint, recessed |
| WON'T FIT | price > capacity — needs more rebirths/levels | new; must read as "grow your pig", not as broken |

Plus the rarity edge (3 px; 5 px legendary) which is the card's one stroke,
and the model preview in a sunk `SLAB` well.

**Data available per card** (from the `houses` payload): `id`, `name`,
`price`, `rarity`, `owned`, `current`, and the player's `coins` and
`capacity` for the affordability states.

**Constraints.** Card is **156 × 182**, `UIScale` 0.78 on a short screen; the
shop content area is **1020 × 578** capped; 18 cards will not fit one screen,
so the section scrolls — a sort or filter (owned first? by price?) is a
design question for GPT to answer. The verb on the card is one of **MOVE IN
/ BUY / grow-your-pig line**; "buy the X first" copy disappears. Show the
price through the existing gold price pill; a house that WON'T FIT should
say what unlocks it in one short line, not print a red number.

**Integration.** `ClientMain` house section (Home tab), payload from
`CosmeticsService`, remote `HouseRequest` carrying an id. Fable wires all of
it; GPT supplies the card states, the section layout at 1040 and at 546,
and the sort/filter decision.

**Budget.** Pending; the Home tab today is 2.38 screens and should not grow
past ~3.

---

## B2 — Trophy-room templates — NEEDED NOW (long lead)

**What it is.** Physical walk-in interiors inside each house in the existing
world. The September 17 update to `HOUSE-TROPHY-ROOMS.md` is authoritative:
three stations (achievement cabinet, records book, Legacy plaque), five
display functions and more display positions in bigger homes. All houses
retain full achievement menu access. Exact capacities are proposed art
targets pending fit checks, not implemented runtime values.

**Themes.** Four templates — cozy (shack/cottage), classic
(townhouse/villa/manor), modern (modern/neontower), royal (palace/castle/
chateau/observatory) — furniture/material families within the walk-in shell,
not separate destination rooms. GPT supplies themed variants.

**Named display points every template must carry, by these exact names**,
because the code mounts to them: `Featured` (one trophy), `Shelf_1..Shelf_N`
(collection), `Wall` (achievement plaques, ordered), `Record` (career
counters: victims, stolen, caught, escapes), `Plaque_Legacy` (Legacy stars,
§11.2), `Door_Exit`. Positions and counts per template are GPT's; names are
Fable's.

**Constraints.** Fit within the actual house/plot. Essential stations stay on
the entrance floor; extra galleries can be upstairs. Visitors inspect the
owner's records but cannot edit. Approaching reveals a prompt; deliberate
input opens the menu. No automatic proximity menus or teleport/safe-zone
behavior. Validate pursuit/loot rules. Follow the house's visual theme,
avoid coplanar surfaces and keep walking routes clear. Interaction/standing
markers and proposed extra wall mounts are in `HOUSE-TROPHY-ROOMS.md`.

**Budget.** Pending — target well under the palace's 186 parts per room since
several may exist at once; state the count in the handoff.

**Integration.** Fable owns `TrophyService` reuse, `Decor` fitting, prompts,
menus, permissions, saved selections and migration. GPT owns furniture,
mounts and approach space. Follow the staged checks and ownership rules in
`HOUSE-TROPHY-ROOMS.md`.

---

## B3 — New house exteriors — RE-BRIEFED September 16, see `HOUSE-TIER-BRIEF.md`

**The full brief is `assets/houses/docs/HOUSE-TIER-BRIEF.md`**: nine fantasy houses with
stable ids (`mushroom, treehouse, slime, candy, crystal, galleon, dragon,
skyisland, goldenpig`) at the prices in `HOUSE-CATALOGUE-PLAN.md`, a
silhouette ladder, FX and trophy-room family per house, and an optional
re-theme direction for the nine existing houses. The three realistic mockups
under `assets/houses/concepts/2026-09-16/` are superseded. What the code
needs from each house, restated:

* **Front-pinned**: a house is seated by its front wall at
  `Config.HOUSE_FRONT_LINE` (28 studs behind the piggy); depth may vary.
* **Fits the yard**: structure width **≤ 60** (the fence interior is 67.2 and
  the palace, the widest today, is 49.0); depth ≤ ~57 (`YARD_DEPTH` 90 less
  the front line and 5 of clearance). Measure by **parts**, not the model's
  bounding box — animated `HouseFX` parts sit at altitude and lie.
* **Height sells**: the top tiers read from the road because they go up;
  the observatory/citadel class should clear the grove behind the plots.
* **Flat colour, no textured materials** (`Brick`, `Slate`, `WoodPlanks`,
  `Metal` etc. all retired); plinth; framed windows; roof courses; ground
  floor lit, upper floors not; zero coplanar pairs.
* **Parts budget** ~200 per house (manor 212, palace 186 are the ceiling).
* **Silhouette ladder**: each new house must be a different *shape* from
  its neighbours in price, not a recolour.

Handoff per house: id, name, `width/depth/storeys`, wall/roof/trim tokens,
drive spec, blurb (one line, the voice of the existing blurbs), and whether
it is a `House.luau` builder or a mesh (`Config.HOUSE_MESH` row).

---

## B4 — Harvest Moon — LATER (mechanics first, against a plain tween)

**What it is.** A third event (`MASTER-PLAN.md` §19.3): two to three minutes
roughly hourly in which other players' ripe tree acorns can be shaken. The
only acorn-theft window.

**Needed from GPT.** (1) A **lighting tween spec** for the window — target
`ClockTime`/ambient/sky values and the ramp — that keeps every pavement tell
legible: the rob badge, the dog's posture, the prompt cards, the pig's fill.
Bounded: no permanent night. (2) An `EVENT_UI` row: tone (must clear 4.5:1
ink or paper per the banner rule), glyph (measured at TextSize 40 against
the 20 px tofu width), wording for warning/live/over. (3) Optional moon or
sky prop, if it reads from the street. (4) The shake prompt card's look on
someone else's tree during the moon.

**Constraints.** The banner is 340 × 44; the chip is 176 × 34; three flashes
a second is the accessibility ceiling on anything that pulses.

---

## B5 — The tree as a progression object — LATER

Five tree levels (§19.4): the oak at `lawnI (-25, 16)` grows fuller/bigger
per level as the pavement tell; ripe acorns visible on branches (exists);
a **wobble** when one is ready; a **fertiliser** icon for the daily ladder
and boost pocket; the acorn chip gains a **"next acorn 43m"** countdown
(chip is 176 × 34, top-right column). Footprint may not exceed the current
8.5-stud oak's slot clearance; state the per-level bounds.

---

## B6 — Legacy reset — LATER

The rebirth explainer page's shape (`Shared/Rebirth.luau`: LOSE / KEEP /
UNLOCK), re-used: LOSE lists houses; KEEP lists trophies, skins, rides, gear;
UNLOCK shows the Legacy star and room plaque. Plus the **Legacy star** on the
plot sign beside the rebirth count, and the `Plaque_Legacy` object for B2.

---

## B7 — The crack panel — LATER, but the first [DESIGN] of Phase 4c

**What it is.** The 430 × 176 minigame panel a robbery happens on: victim
name, `SLICE n / 5`, a horizontal lock dial with a lit target zone and a
sweeping marker, a gauge drawing the PIG with the loss cap as a red line and
the next slice drawn ahead, the take so far, the loot-odds row (Phase 4.2),
and — new, 4c.6 — the room left in the thief's own pig.

**States.** arming / zone lit / hit / miss / clean (fifth landed) / bailed /
allowance exhausted / pig full (room 0). Lock tiers 0–4 change the zone
width today and will change its PATTERN (split zone at tier 3, reversed
marker at tier 4 — 4c.1), so the dial has to have room to say that.

**Constraints.** Same rules as every panel: `Theme` tokens, one stroke, 546
tall phone; the marker moves every frame so nothing on the panel may pulse
above three a second; the dial is the one control a thief taps, so the tap
target is the whole panel and the visual is the dial. Deliver at 1040 and
546.

## B8 — Gadget props — LATER, per gadget

For each of the two chosen first (Smoke Bomb and one of Decoy Piggy / Oil
Slick / Snare): a hand-held model (longest side lands on `GRIP_SPAN` 1.9 when
held; the builder returns it anchored, authored along one stated axis), a
thrown/in-flight look, a landed effect (cloud, running pig, patch, trap) with
its footprint in studs, and a 68 px hot-bar icon. The throw and use
animations are Fable's pipeline (Art 1: built in code, uploaded once).
