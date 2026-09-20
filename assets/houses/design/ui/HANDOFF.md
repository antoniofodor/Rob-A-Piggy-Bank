# B1 / 4b.3 — individual house cards

**Catalogue revision:** the visual states/layout below still apply, but
the demo's nine proposed realistic additions have been superseded. Use
`../fantasy-v2/catalogue.json` and Fable's final registry for new IDs; the
proposed `raven` replacement for seasonal `candy` needs registry alignment.

Status: visual prototype and implementation specification ready for review.
No runtime Luau or economy changes. Fable owns implementation.

Open `catalogue.html`. The external preview toolbar uses fake balances only.
Final gameplay previews must use House models, not the generated concept
posters or the deliberately schematic existing-house SVG placeholders here.

## State priority and copy

Evaluate current → owned → price exceeds capacity → affordable → too dear.
Owned houses stay usable even after rebirth reduces capacity. All rules use
the server payload; the prototype's local ownership Set is just a demo.

| State | Surface | Price pill | Footer | On press |
| --- | --- | --- | --- | --- |
| SHOWN | OWNED tint + SHOWN stamp | Original price or FREE | ✓ LIVING HERE | No request |
| OWNED | OWNED tint + OWNED stamp | Original price or FREE | MOVE IN | HouseRequest(id) |
| AFFORDABLE | BUY tint | Gold price | BUY on gold | HouseRequest(id), wait for server result |
| TOO DEAR | DEAR tint | Gold price | NEED {shortfall} | Existing toast: need N more coins; no purchase request |
| WON'T FIT | PAPER_DEEP, no padlock | Gold price | GROW YOUR PIG | Explain price and current capacity; no purchase request |

Do not claim an unlock level or rebirth count: the brief does not provide
those fields. A grow prompt can route to the existing Upgrades tab if Fable
supplies that navigation callback. No new currency, protected savings or
deposit action is introduced. A house has no BUY NEXT prerequisite.

## Sorting and filtering

Default All, ascending price then stable id. Owned and Affordable are optional
filters. Owned includes SHOWN; Affordable includes only unowned purchases
that fit and can be paid now. Retain the selected filter and scroll position
on ordinary balance updates. Filter selection resets scroll. Never reorder
cards by changing coin balance; this prevents a purchase target moving under
a player's finger. A successful purchase may leave the Affordable filter.

## Card geometry — logical pixels before one UIScale

Root 156 × 182, corner 15–16. Exactly one root rarity UIStroke: 3, Legendary 5.
No root ink stroke. State is communicated by text as well as tint.

| Child | x / y | width / height | Text |
| --- | --- | --- | --- |
| Preview well | 8 / 8 | 140 / 76 | Theme.SLAB |
| Rarity tag in well | 5 / bottom 4 | fit to word / 16 | 9px Theme.FONT_BODY, dark readable ink |
| State stamp in well | right 5 / 4 | fit to SHOWN or OWNED / 14 | 9px Theme.FONT_BODY |
| House name | 8 / 89 | 140 / 34 | 14px Theme.FONT, wrap at most two lines |
| Price pill | 8 / 126 | 140 / 19 | 11px Theme.FONT_BODY, GOLD on SLAB |
| Action line | 8 / 150 | 140 / 24 | 11px Theme.FONT_BODY |

Use one logical UIScale of .78 for short views and compact portrait widths;
effective size 121.68 × 141.96. Avoid a second scale inherited from an already
shrunk parent. Final check is AbsoluteSize and TextBounds in Roblox, not just
the configured Size. Do not use TextScaled or truncation to hide overflow.
The whole card is the touch target; the small visual footer is not a separate
19-pixel-high touch control. Keep a visible keyboard/gamepad focus indicator
on a separate sibling if Roblox stroke limitations prevent reusing the edge.

Grid gap 12 actual pixels, at least 8 actual pixels of clipping clearance
around outer strokes. Columns derive from available width. Header/filter row
stays fixed while cards scroll. Use one vertically scrolling Home section,
not a nested scroll competing with the Home page. The HTML isolates the house
section; total Home-page height with every other shelf still needs Studio QA.

## Colours/fonts

Use Theme.INK, SLAB, PAPER, PAPER_DEEP, SAND, MUTED, GOLD, GOOD and the existing
RARITIES colours. Preserve existing ShopStyle.OWNED / BUY / DEAR tints.
The brief requires Theme tokens but those three current ShopStyle values are
literal RGB; Fable should alias them through Theme as needed without changing
their measured colour. HTML variables snapshot these current values, not a
new runtime palette. Actual game fonts are Theme.FONT (FredokaOne) and
Theme.FONT_BODY (GothamBold). Browser fallback fonts are not pixel-identical.

## Wiring checklist for Fable

- Implement in a module, keeping ClientMain below its local-register limit.
- Consume `id,name,price,rarity,owned,current`, plus coins/capacity.
- Never award ownership or debit currency in a UI callback. Wait for the
  authoritative update; suppress repeated in-flight requests where appropriate.
- Build each model preview once and clean it up when the card is removed.
- Match the final native cards against desktop/546px phone screenshots;
  verify long names, all five states, filter-empty state and stroke clipping.
- Audit contrast in the live tree. The prototype provides readable flat
  fills; avoid gradients under text that reduce those contrast ratios.

See `../review/ui-report.json` for browser checks and screenshots. Those
checks do not substitute for native Studio text bounds or touchscreen QA.

Flat-fill contrast calculations are in `../review/contrast-report.json`.
All eleven checked text/background pairs exceed 4.5:1; the narrowest is
INK on EPIC at 4.65:1. Rarity text uses Theme.INK. Final fonts and live
rendering still need native review. The prototype shell itself is capped
at 1020 x 578, conservatively fitting inside the brief's content budget.
