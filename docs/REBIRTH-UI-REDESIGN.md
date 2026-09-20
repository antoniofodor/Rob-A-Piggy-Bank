# Rebirth UI redesign guide

Design handoff for GPT visuals / Fable implementation · September 18, 2026

## 1. The intended experience

Make rebirth feel like opening the next chapter of progression. A player should
understand three things before confirming:

1. **What improves permanently?** Show current → next values.
2. **What reward will I receive?** Separate guaranteed benefits from a random crate opening.
3. **What resets, and what stays?** Show the actual trade before committing.

The HUD button **always opens the preview**. Only the explicit confirmation
inside that preview sends the rebirth request. This applies to every rebirth.
Use one clear decision page, without a second generic “Are you sure?” popup.

This document proposes visual/interaction changes. It does not change rewards,
prices, reset rules, scripts, or published assets.

## 2. What the current game actually does

Checked against `Rebirth.luau`, `ProgressionService.luau`, and `Config.luau`.
Executable code takes precedence over older descriptive comments and examples.

| Topic | Current behavior | Design implication |
| --- | --- | --- |
| HUD visibility | Button appears when the server says rebirth is ready | Preserve this initially to avoid adding mobile clutter |
| Button count | Chip displays the **next** rebirth number | Replace ambiguous `12★` with `NEXT 12` |
| Confirmation | `FIRST_TIME_ONLY = true`; later HUD taps invoke the request directly | Remove this bypass; preview every time |
| Requirement | Banked coins ≥ `getRebirthThreshold(currentRebirths)` | Show current bank / requirement; use server readiness |
| Coin reset | All banked coins reset to 0, including any excess over the requirement | Call this a requirement, not a price that leaves change |
| Upgrade reset | Income and capacity go to level 1; configured upgrade trees go to 0 | Show before → reset values for upgrades actually owned |
| Coin benefit | +12 percentage points per rebirth through 10, then +8 | Use current → next bonus or multiplier; never hardcode +12% |
| Upgrade access | Income/capacity ceiling increases by 2 per rebirth, capped at level 60 | Say “Higher upgrade limit,” not “Gain two upgrade levels” |
| Acorn tree | Online growth bonus increases by 3 percentage points per rebirth, capped at +60% | Mark ONLINE ONLY; growth capacity is a separate house gate |
| Free opening | Random eligible OG Piggy or Animal Kingdom Legendary crate | Name the opening; do not promise a particular skin |
| Configured crate odds | Both currently have Rare 65%, Legendary 35% | Show live effective odds from the existing crate system |
| Completed pools | When both eligible legendary collections are complete, grant Acorns instead | Show the fallback amount from `rebirthCrateBonus()`; currently 120 |
| Preserved state | Collections, house/lawn, rides, wearable items, consumables, Acorns, lifetime progress and existing rebirths are not reset by this transaction | Give a concise “You keep” summary |

The same guard dog remains after rebirth. Do not copy the obsolete “lose Guard
Dog levels” example from the old module commentary. Do not revive retired
Bronze / Gold Leaf / Diamond rebirth milestones. The current page's old “trail
effects” wording should not introduce a separate effects category into this redesign.

## 3. HUD button redesign

### Appearance

- Keep the game's plum prestige color, warm cream lettering, gold accent and
  dark cocoa outline. Reuse `Theme` colors and the existing title font.
- Use a compact rounded plaque with a slight asymmetric sweep at the right
  edge. Keep the outline smooth and consistent, including the curved edge.
- Replace the sparkle emoji with **one clean gold rebirth emblem**: two thick
  curved arrows circling a small piggy coin. Large silhouette, minimal detail.
- Let the emblem overlap the left edge slightly, like the shop header icon.
  Avoid a second circle/background around it.
- Main text: **REBIRTH**. Right-hand badge: **NEXT 12** for the screenshot's state.
- Put a short `READY` label beneath the main text only where it stays readable.
  Do not add a second floating banner, persistent glow or looping bounce.
- One brief emphasis when readiness first changes to true; otherwise keep it still.

### Size and placement

Starting dimensions, to verify in Studio:

| Mode | Button size | Label | Notes |
| --- | --- | --- | --- |
| Desktop | 192 × 50 | 19–20 px | Smaller than the current 232 px width |
| Compact | 154 × 44 | 14–16 px | Emblem 25–28 px; NEXT badge about 42 px wide |

Reserve the emblem's overhang inside the HUD layout's total footprint. Use the
existing `HUDLayout` safe regions rather than another independent absolute
position. Check top controls, event timer, vault HUD and phone orientation.
Keep the button available only when ready in the first implementation. An
earlier progression-preview entry can be added later to the upgrade screen if wanted.

### States

| State | Appearance / behavior |
| --- | --- |
| Ready | Plum plaque, gold emblem, NEXT badge; opens the decision page |
| Hover / focus | Slightly brighter face and clear focus outline |
| Pressed | Face moves down 1–2 px; emblem and text move together |
| Preview open | Hide the duplicate HUD button |
| Request pending | Disable the page's confirm action and show “Rebirthing…” |

## 4. Decision page: reward first, trade visible

### Header

Floating plum title tab: **REBIRTH 12**. Smaller line: **A stronger fresh start**.
Use the same gold emblem as the HUD. The red X protrudes from the top-right
corner, matching the shop's modal treatment. Give both overhangs safe margins;
do not clip them with the scrolling content.

### A. “Your next rebirth” benefit cards

Use four compact illustrated cards in a 2 × 2 grid on desktop. The first two
should carry the strongest visual emphasis.

1. **Permanent coin bonus** — coin icon; `+128% → +136%`.
   Helper: “Applies at every income level.”
2. **Higher upgrade limit** — piggy/upgrade-arrow icon; `Lv 42 → Lv 44`.
   Helper: “Earn Faster + Bigger Piggy Bank.”
3. **Free crate opening** — actual catalog crate art.
   Helper: `Rare 65% · Legendary 35%`, with `View possible rewards`.
4. **Online Acorn growth** — tree/Acorn icon; `+33% → +36%`.
   Helper: “While you're playing.”

These values illustrate **11 → 12 rebirths**, consistent with the screenshot's
next-rebirth badge. They are examples, not strings to hardcode.

Call the second card “Higher upgrade limit”: the player must still repurchase
those upgrades after the reset. At the level-60 ceiling, replace its arrow with
“All upgrade levels unlocked.” At the tree-growth cap show “Maximum bonus.”
Do not claim additional benefits once a cap is reached.

Avoid “8% faster than now”: changing 2.28× to 2.36× is eight percentage points
of the base rate, not an 8% increase over current earnings. Also avoid showing
current high-level coins/second → hypothetical high-level coins/second without
explaining that income level resets to 1.

### B. Crate reward inspection

`View possible rewards` expands a detail section inside the same page. It must
not open the shop on top of the rebirth modal or send a purchase/open request.

- If both pools are eligible, show **OG Piggy** and **Animal Kingdom** mini
  cards. Currently each has a 50% chance of being selected; derive this from
  the eligible-pool count instead of fixing it in the UI.
- If only one is eligible, show its exact crate name.
- Show the existing crate contents grid with Owned / Not owned labels and
  its effective odds. Ownership labels are informational; owned items are
  still possible where the crate's normal rules allow duplicates.
- State: **“One free opening. A new skin isn't guaranteed.”** Reuse the existing
  duplicate-spares explanation.
- A player completing a pool before confirming must see the preview update.
- If all eligible legendary pools are complete, replace the entire reward card
  with **120 Acorns**, using the current helper's result. Explain “Legendary
  collections complete.” Do not continue showing an obtainable crate.

Never show a random skin as a guaranteed reward, and do not pre-roll the actual
result simply because the player opened this page.

### C. “What changes”

Keep this summary visible before the confirmation area:

**Resets**

- Piggy coins: `[your current bank] → 0`.
- Earn Faster: `[current level] → 1`.
- Bigger Piggy Bank: `[current level] → 1`.
- Bought defense/offense upgrades: `[number of bought upgrades] reset`.
  Expand `View upgrades` to show each actual item and its reset level.

**You keep**

- Skins, collection items, home/lawn and rides.
- Wearables, consumables and Acorns.
- Achievements, lifetime stats and your existing rebirth progress.

Use small category icons and short lines. Do not make players read their entire
inventory. Do not count upgrades already at their starting level as a loss.
The reset summary cannot be hidden inside an optional “More info” section.

### D. Requirement and fixed footer

Requirement row: **Piggy coins `[bank] / [requirement]`**, with a small progress
bar and explicit `Ready` / `[amount] more needed` text.

Fixed footer, always visible:

> **Your piggy coins and bought upgrades reset. Your collection stays.**
>
> `[ NOT YET ]`                         `[ REBIRTH TO 12 ]`

Use cream for NOT YET and plum with cream text/gold emblem for confirmation.
The footer stays separate from the scroll area. One deliberate click/tap is
enough; do not require a long hold on a frequently repeated action.

## 5. Layout sketch

```text
        [ gold emblem · REBIRTH 12 ]                      [ X ]
   ┌───────────────────────────────────────────────────────────┐
   │ A stronger fresh start                                    │
   │                                                           │
   │ YOUR NEXT REBIRTH                                          │
   │ ┌───────────────────────┐ ┌─────────────────────────────┐ │
   │ │ Permanent coin bonus  │ │ Higher upgrade limit        │ │
   │ │ +128%  →  +136%       │ │ Lv 42  →  Lv 44             │ │
   │ └───────────────────────┘ └─────────────────────────────┘ │
   │ ┌───────────────────────┐ ┌─────────────────────────────┐ │
   │ │ Free crate opening    │ │ Online Acorn growth         │ │
   │ │ View possible rewards │ │ +33%  →  +36%               │ │
   │ └───────────────────────┘ └─────────────────────────────┘ │
   │                                                           │
   │ RESETS                         YOU KEEP                   │
   │ Coins → 0                      Your collection            │
   │ Core levels → 1                Home, rides, items, Acorns  │
   │ Bought upgrades → 0            Achievements and progress  │
   │                                                           │
   │ Piggy coins  [ current / requirement ]              READY │
   ├───────────────────────────────────────────────────────────┤
   │ Coins and bought upgrades reset. Your collection stays.   │
   │ [ NOT YET ]                         [ REBIRTH TO 12 ]     │
   └───────────────────────────────────────────────────────────┘
```

## 6. Mobile behavior

- Size against the usable viewport, including the title/X overhangs; leave at
  least 12 px around the full modal footprint. Start with a 780 px desktop
  width cap, then constrain height to the available safe space.
- Keep header and footer fixed. Use **one vertical scrolling body**, replacing
  the separate keep/lose scrolling columns.
- Narrow portrait: one benefit card per row; preserve current → next values on
  one line. Stack Resets above You keep.
- Landscape phones: use two compact benefit columns when they fit. Reduce
  decorative artwork and spacing before reducing font size.
- Target at least 14 px body text and 44 px touch areas. Confirmation text may
  use two lines if needed; do not shrink the entire modal using one UIScale.
- Reserve room for the footer's reset sentence and both actions. Long names,
  localization and large coin values must wrap inside the body, not push the
  confirmation button outside the screen.
- Modal blocks underlying gameplay inputs. X, NOT YET and back close the page
  before a request; Enter or a held gameplay key must not accidentally confirm.

## 7. Visual assets and motion

### New art to produce after this guide

| Asset | Specification |
| --- | --- |
| Rebirth emblem | Transparent gold circular arrows + piggy coin; readable at 28 px; 512 px source |
| Prestige header tab | Smooth outlined plum silhouette; separate from its live text |
| Higher-limit icon | Simple piggy with two rising blocks/arrow; no tiny numbers |

Reuse the current coin, Acorn/tree and crate artwork from the shop. Reuse the
existing modal X and button system. Do not generate entire cards with text baked
in. Use modest cartoon bevels and large color areas; avoid glitter, ornate trim,
animated backgrounds and tiny details.

Page motion: 120–180 ms fade/settle. Button press: 1–2 px. After the **server
confirms success**, show `Rebirth 12 complete`, then let the existing crate reveal
present the actual result. Sequence it so it does not fight the decision page.
Respect existing reduced-motion/settings behavior. This adds no idle pig effects.

## 8. Fable implementation handoff

### Main touchpoints

- `src/ReplicatedStorage/Shared/Rebirth.luau`: rebuild layout and replace the
  `FIRST_TIME_ONLY` path with always-open-preview behavior.
- `src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau`: keep the
  injected callback connected only to the page's final action; coordinate menus.
- `src/ReplicatedStorage/Shared/HUDLayout.luau`: allocate the revised button footprint.
- `src/ReplicatedStorage/Shared/Theme.luau`: reuse colors, fonts and modal styling.
- `src/ServerScriptService/Services/ProgressionService.luau`: preserve authoritative
  validation/reset/reward behavior. Add a clear result signal only if existing
  state/notifications cannot distinguish pending, rejection and success reliably.

### One preview model, derived from real state

Supply current/next rebirths, banked coins, requirement, readiness, current/next
income factors, current/next core level caps, current/next online tree factors,
actual reset upgrade rows, and crate/fallback details. Read the existing helpers:

- `Config.getRebirthThreshold(r)`
- `Config.rebirthIncomeFactor(r)` / `Config.rebirthBonusPercent(r)`
- `Config.maxLevel(r)`
- `Config.treeRebirthFactor(r, true)`
- `Config.rebirthCratesOpen(owned)` / `Config.rebirthCrateBonus()`
- The existing crate preview's live odds and contents resolver

Do not reimplement economy formulas inside the UI. Refresh the visible preview
when economy, upgrades or ownership change. If coins fall below the threshold
while reading, keep the page open, update the requirement, and disable confirm.
The current `onEconomy` close-on-not-ready behavior needs adjusting for this.

On confirm: disable repeat inputs, keep the reviewed summary visible, request
once, and wait for the authoritative outcome. On rejection, restore the page
with updated values and a short reason. On success, transition to the existing
reward presentation. Reopening the page must never resend a previous request.

### Suggested hierarchy

```text
RebirthModal
  Scrim
  Shell
    FloatingHeader
    CloseButton
    ScrollBody
      BenefitGrid
      CrateDetails (expandable)
      ResetSummary
      ResetUpgradeDetails (expandable)
      KeepSummary
      Requirement
    FixedFooter
      ResetReminder
      NotYetButton
      ConfirmButton
```

## 9. Acceptance checklist

- Clicking the HUD never performs a rebirth, including after the first one.
- Examples 0→1, 9→10, 10→11, 11→12 and 19→20 show the correct benefits.
- At 20→21, level cap stays 60 and online tree bonus stays +60%; income still advances.
- Both eligible crates, one eligible crate, and completed-collection fallback render correctly.
- Legendary crate is visibly a random opening; owned items and duplicate behavior are clear.
- Above-threshold coins are correctly shown resetting entirely, not merely reduced by the requirement.
- Already-base upgrades are not listed as losses; the guard dog is not falsely removed.
- Changing coins/ownership while open updates the preview and confirm eligibility.
- Double-tap, rejected request, menu close/reopen and delayed server response cannot duplicate actions.
- Desktop, 390×844 portrait and 844×390 landscape layouts keep X/footer accessible.
- Long text and all reward-detail expansions scroll without hiding the reset reminder.

## 10. Delivery order

1. Use this guide to agree the layout and copy.
2. GPT produces the emblem/header art and a desktop + mobile visual mockup.
3. Fable implements the preview, data bindings and confirmation state handling.
4. GPT reviews the integrated appearance; Fable checks transaction behavior.

Status: **guide complete; artwork and implementation pending.**
