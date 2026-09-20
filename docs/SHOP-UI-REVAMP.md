# Shop UI revamp proposal

September 17, 2026. Requested by the user after the current shop inventory
review. This is a proposed design, not an approved implementation or a change
to purchase availability, prices, combat rules or live UI.

## 1. Recommended access model

Keep the entire everyday catalogue available from the menu. Each physical
storefront opens a focused view of the same catalogue with its own shopkeeper,
signage and relevant 3D displays. Do not maintain a second purchase UI or
different prices for the same item depending on the entry point.

Reasons: repeat purchases should be quick, particularly on mobile; players
should be able to browse their next house while earning; and normal supplies
should not require repeated trips across the map. Storefronts already serve
as robbery destinations and can teach players about their specialities.

Possible later destination-only content: an event vendor or optional cosmetic
interaction. Show where to obtain it in the catalogue. This is an option for
future discussion, not new content required for this redesign. Do not move
existing basic equipment, defence or upgrades behind storefront-only access.

Storefront landing views:

| Storefront | Focused landing content |
| --- | --- |
| Piggy Outfitters | Style & Crates: skin crates, catch cosmetics, relevant offers |
| Home & Garden | Homes, garden/decor, companion and kennel shortcuts |
| Wheels & Kit | Rides and robbery supplies |
| Lock & Key | Defensive upgrades and home-defence supplies |

Keep a clear All Categories control in each view. The storefront name is
context; it does not change the underlying catalogue or player ownership.
Respect current server purchase/equip/use restrictions. Opening the UI never
pauses robbery/pursuit or grants safety. Fable should audit remote restocking
during combat before implementation; no new restriction is approved here.

## 2. Catalogue organisation

Replace the crowded scrolling top rail with a category landing screen and
six destinations. On wide screens show a labelled sidebar. On phones the
category landing screen provides six large icon tiles, followed by a simple
category title and Back control. Never hide categories offscreen in a rail
without a visible way to discover them.

| Destination | Contents |
| --- | --- |
| Upgrades | Income, capacity, locks, fences, lockpicks, sack, speed boots, Sneak |
| Home & Garden | Houses, yard decorations, border plants, paths, window boxes, trophy-base finishes |
| Companions | Guard appearances, guard naming, kennels, follower pets |
| Rides | Five rides, ride details and applicable Style Pack offer |
| Supplies | Bones/steaks, plunger/gum/zapper, guard treat, sprinkler, patrol radio, ladder, raincoat |
| Style & Crates | Crates, catch cosmetics and relevant cosmetic pack offers |

The landing screen replaces Everything's duplicated mini-catalogues with
clear category entries and a small optional resume/relevant-upgrade area.
Within large destinations, use labelled section shortcuts (e.g. Houses,
Yard, Garden, Display Bases) without multiple nested navigation levels.
Search and filters should preserve their state when returning from details.

### Shop, Bag and house displays

- Shop: discover/buy/open items, compare upgrades and preview future goals.
- Bag: owned skins, equipment and cosmetics; equip/manage/combine/sell where
  supported. Keep existing valid actions discoverable through shortcuts.
- Achievement cabinet/records/Legacy: full earned progress and display choices,
  per `HOUSE-TROPHY-ROOMS.md`. Remove the ten earned trophy progress cards and
  earned Face Mask from sale grids, with an Achievements shortcut/requirement
  link so their discovery is not lost. Ownership and award rules stay intact.
- The purchased Best Yard Trophy remains a decoration. Its name does not make
  it one of the ten earned achievement trophies.
- The Golden Piggy stays visible at the end of the house catalogue as an
  earned collection goal with progress, never a coin purchase.
- Do not restore retired piggy aura or accessory shop categories. Existing
  catch effects are a distinct category; they trigger on catching somebody.

## 3. Shared browsing and purchase layout

Use large static cartoon category icons, legible type, warm neutral surfaces,
clear outlines and restrained category colour. Match the existing game's
visual language. Avoid looping icon animations and decorative motion that
competes with prices or actions. Rarity has a word/icon as well as colour.

Card essentials: real item preview, name, price/currency or earned requirement,
and ownership state. Put descriptions and technical stats in the detail view.
The grid card opens details; it should not spend currency on an accidental tap.
Details contain one explicit primary purchase/equip action, without a second
routine confirmation dialog. Respect required platform purchase prompts.

On desktop, show details alongside the grid. On compact screens, use a focused
detail page/sheet with a persistent price/action area and obvious Back control.
Return to the same scroll position. Keep selection independent of ownership.

Show contextual actions: Buy, Owned, Move In, Equipped, Place, Earned or a
specific unlock requirement. Supply cards show stock and support repeat buying
after the first deliberate selection; quantity controls depend on existing
server limits. Disable pending actions and handle rejected/stale purchases.

Keep Coins and Acorns clearly distinguished. Show both on the landing screen;
emphasize the relevant balance in each destination. Use Robux only on applicable
offer cards/details. Do not advertise unset pass IDs as purchasable products.

## 4. Special layouts

- Houses: large exterior preview, price/tier, owned/current state, interior
  preview and factual display-capacity information once runtime confirms it.
  Show art placeholders honestly. Do not claim proposed capacities are live.
- Upgrades: current benefit versus next benefit, cost and progression limit;
  readable tier previews instead of a wall of tiny levels.
- Companions: clear Guard / Pet distinction and real model previews. Kennel
  previews show what is bought; guard naming remains an ownership action.
- Rides: real preview, speed/use restrictions and applicable style choices.
- Supplies: clear purpose, effect/duration, price and current quantity.
- Crates: contents previews, actual server-provided odds before opening,
  Acorn price and collection progress. Preserve combine and time-limited
  buyback discovery. Keep result presentation skippable/compact as appropriate.
- Premium offers: limited dedicated area or relevant category placement; do
  not scatter duplicate offer cards across every destination.

## 5. Responsive requirements

Design the phone layout first, including the existing 546px landscape-height
constraint and safe areas. Also check narrow portrait and tablet layouts.
Use adaptive columns rather than shrinking the whole desktop panel. Aim for
48px touch targets; avoid small close controls and horizontal price clipping.

Shop is an intentional browsing panel. Hide overlapping nonessential HUD
behind it while retaining an obvious close action. Fable must decide how
movement/input focus behaves and test it during pursuit; no game pause is implied.
Support touch, mouse/keyboard and controller focus. Test long item names,
large coin values, insufficient funds, locked, owned, pending, empty-search
and unavailable-offer states. Use shared Theme tokens and existing contrast
and stroke rules from `BRIEFS-FOR-GPT.md`.

## 6. Work split and delivery sequence

1. Review this proposed access/category model. Exact navigation and any
   storefront exclusives remain design decisions, not approved runtime changes.
2. GPT: create desktop/mobile mockups for category landing, Home catalogue,
   item details and Supplies. Include earned/locked/owned states.
3. Fable: finalize data/action contracts, existing restrictions and navigation
   state. Keep server authority and all ownership/currency checks.
4. GPT: deliver the visual components, icon assets, spacing, responsive rules
   and state specifications. Fable wires purchase/equip/preview behaviour.
5. Migrate shared shell and one category first, then remaining categories and
   storefront entry points. Preserve existing actions throughout rollout.
6. Validate on real phone/tablet/desktop and with owner/visitor data, controller
   input, rapid repeat purchases, insufficient currency and concurrent state changes.

## Catalogue issues discovered during inventory review

- Gingerbread Manor remains configured despite the user's seasonal-only
  direction. Resolve its visibility/replacement with Fable without silently
  deleting existing ownership or changing the Golden Piggy completion target.
- House art completion and catalogue presence are different; mark placeholders.
- Some code comments describe retired tabs/items. Use active UI construction
  and server catalogue payloads as the implementation source of truth.
- Pass IDs are currently unset in Config; verify any deployment overrides
  before showing live Robux purchase actions.

## Implementation checkpoint — September 17

The user approved the low-poly mockups in `assets/shop-ui/revamp-v2/` and
requested implementation. The first integrated version now includes:

- Six-category shell, category landing, desktop sidebar and compact Back navigation.
- Upgrade comparison screen with real Config-derived stats and existing actions.
- Complete crate collection browser with owned/not-owned filters, actual live
  drop odds, collection progress and the existing Acorn purchase action.
- Separate Companion catalogue; Style & Crates keeps both crate and outfit routes.
- Static new model previews, flat surfaces and adaptive catalogue columns.
- Existing combine, buyback, reveal, bag and storefront routing retained.

The Home, Rides and Supplies catalogues retain their existing item-card actions
inside the new shell. Expanded individual-item detail sheets, house interior
previews and expanded item information remain future work; no proposed house display capacities or new storefront restrictions were
introduced. Existing server prices and ownership validation remain authoritative.

Validation: Luau compilation and Rojo build pass; 97 isolated shop UI checks,
73 crate economy checks and 70 buyback checks pass. The new test suite exercises
navigation, repeated/insufficient-funds actions, actual upgrade stats, ownership
filters, live odds and control bounds at desktop, portrait and short landscape
sizes. Real Studio rendering, controller navigation and touch testing remain
pending; the harness does not emulate engine text or grid layout.

## Reference-matching revision — September 17

The user rejected the first implementation's appearance and supplied the
approved landing image again. The subsequent instruction explicitly removes
the search bar; do not restore one from the old mockup or proposal.

- Landing uses all available width for six large illustrated cards; the sidebar
  appears only inside categories on sufficiently large screens.
- Gold SHOP sign with a pink basket, green masthead, cream currency badges,
  larger red close control, cream card captions and coloured arrow discs.
- Category colours now follow the supplied image: yellow, green, blue, coral,
  violet, teal. ShopScenes builds static low-poly category illustrations locally
  (lock and sack, garden house, dog and duck, scooter, plunger and gum, crate and pig).
  These are category illustrations, not previews of specific purchased houses or skins.
- Bag and Achievements footer shortcuts. Achievements reads existing CosmeticState
  trophy requirements, progress and earned flags; it adds no rewards or server logic.
- Panel uses 94% × 92% of the viewport, subtracts 40 px of height and shifts down
  20 px to clear Roblox's menu controls, with a 1480 × 920 cap. Narrow layouts use
  two columns, stacked currency badges and compact footer labels.
- Native art requires no image uploads; prices and balances remain live values.

138 headless UI checks, Luau compilation and Rojo build pass. Live Studio review
covered desktop and iPhone 6 Plus landscape (736 × 414), category navigation,
swiping to the final category row, Bag routing and real achievement progress.
The review led to tighter category framing, neutral preview lighting, touch-active
scroll areas and shop layering above the mobile joystick/jump buttons. These fixes
were verified in a fresh phone play test. The existing Bag itself still has mobile
CoreGui overlap and is outside this visual revision. Portrait was inspected but
is not enabled in the game's settings. Real-device, controller and multiplayer
checks remain pending.
