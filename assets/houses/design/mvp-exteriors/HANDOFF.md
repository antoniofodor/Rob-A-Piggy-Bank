# MVP house catalogue and exterior continuation

September 17, 2026. **User direction: interiors are deferred beyond MVP.** No interior work, runtime scripts, prices, ownership or migrations were changed. The earlier B2 studies remain separate historical drafts.

## Delivered

- `crystal-spire-concept.png` and `beached-galleon-concept.png`: new exterior concept sheets with large three-quarter and smaller frontal views, created with the built-in image_gen tool. Exact prompts are in `prompts.json`. These need design selection before model production.
- `house-specs.json`: stable IDs, existing costs/rarities, proposed bounds, front/pivot convention, named palette proposals, drive, blurb, FX and proposed budgets. No measured geometry or uploaded asset IDs are claimed.
- `catalogue.html`: standalone interactive B1 prototype with 19 current registry rows, the five purchase/ownership states and an earned goal state. Card opens details; Buy / Move In is an explicit action in details. No search bar. All / Owned / Affordable filters; ascending price with earned goal last. `index.html` is the review entry point.
- `catalogue.json`: read-only snapshot of literal Config rows with source hash. `build.py` regenerates it and the prototype without executing Luau or modifying source.

## Exterior scope

Crystal Spire is proposed at 24 W × 24 D × 45 H. The jagged central shard dominates; three separately authored accent pieces pulse slowly. Galleon is proposed at 42 W × 24 D × 50 H, with the broadside entrance facing the road. Its hull body is intended to occupy about 20 depth, with the fixed gangplank projection included in the 24-depth target. Both include all trim/FX/approach geometry in their proposed envelopes; actual vertex and maximum-motion bounds must be checked after modelling.

The origin is the ground point at structural front-wall centre, facing -Z. Front-pin that wall with the game's placement logic; report frontward path projection separately. Do not position using a bounding box inflated by elevated FX. No interior floor count or access behavior is being added.

Crystal's concept contains more small rubble than needed; simplify this in production. Galleon's generated surface grain, cloth shading and ornamental rail detail must become economical flat-colour geometry. Use SmoothPlastic surfaces, separated single-colour mesh groups, no texture uploads. Do not import the concept images as house textures. Palette names in `house-specs.json` are proposed Theme entries, not already installed constants.

The proposed geometry budgets (80 / 120 BaseParts; 20K / 30K triangles) are art targets, not measured results or approved engine budgets. Prefer fewer merged static material groups where shape permits; keep FX separate. Existing pulse periods from fantasy-v3 remain: Crystal 9 seconds with three phases; Galleon lantern 7 seconds. Optional sail sway is 11 seconds at ±2 degrees; mast, hull and gangplank stay fixed. An MVP can retain only the lantern pulse. Never strobe.

Final review still needs measured plot/lawn clearance, coplanar checks, Studio material/bloom/viewport framing and a pavement photograph around the 70-stud reading distance. Small catalogue silhouettes must remain recognizable. Interiors are outside this work.

## B1 changes and implementation contract

The old `ui/catalogue.html` is preserved; it still contains retired realistic IDs. This new version reads the current registry instead of recreating that list. Nineteen rows comprise the free starter, seventeen priced houses and Golden Piggy. Never use list position as identity.

Current source uses `cost` rather than the original brief's `price`; Fable should map the actual payload field. Evaluate current → owned → earned goal → cost above capacity → affordable → too dear. Owned homes remain usable when capacity falls below their old price. For earned homes, do not let a missing/zero `cost` turn the card into FREE / BUY. Production collection progress comes from `earnedHave` / `earnedNeed`, and sale availability from `forSale`; this standalone simulation counts a local Set only.

The entire 156 × 182 card is the selection target. It has one rarity edge (3 px; 5 Legendary), a sunk 140 × 76 preview, two-line name, gold price pill and action wording. At short height, one .78 scale yields 121.68 × 141.96 cards; there is no nested scale. Prototype rarity colours use Theme tokens; state grounds use GOOD / GOLD / SAND_DEEP / PAPER_DEEP with explicit state text. A production pass may preserve the current theme's owned/buy tints.

The full page caps at 1040 width. The required 546-tall view uses compact header, 44px filter targets and a scrolling catalogue. A modal detail sheet has a scrolling body and a persistent 48px action. Browser modal focus/Escape behavior is for review; native Roblox needs its own focus/gamepad implementation. Native labels use Theme.FONT / Theme.FONT_BODY; browser fonts are approximations.

Selection never purchases or equips. Buy and Move In must fire `HouseRequest(id)` only from the deliberate detail action, then render the authoritative response. Do not optimistically debit the actual client balance. Disable while pending; on rejection preserve selection and show the server reason. The local demo has no network/pending timeout simulation.

Filter changes reset scroll; ordinary balance/ownership refreshes retain it. Stable price order avoids targets moving as coins accrue. A purchased item leaves Affordable; closing details returns focus to its card if visible, or the active filter otherwise. The earned goal is last and excluded from Affordable. No fabricated unlock level/rebirth count is printed: capacity-blocked details state cost and capacity and say Grow your pig.

Card illustrations are deliberately schematic code-native symbols, not final model previews. Treehouse and Gloop details show actual existing Blender renders; other available details show concept sheets, clearly labelled. Production must use the actual House model. The Void gets a light SAND_DEEP preview well to keep its dark silhouette visible.

## Unresolved registry/art mismatch

`candy` is still in current Config at 8M, although prior user direction reserves Gingerbread for seasonal content. This prototype reflects that current registry and flags the mismatch in the review-only note; it neither generates a permanent Candy model nor invents a replacement ID. Any change to this row or the seventeen-house completion requirement belongs to the gameplay owner and a user decision. The two new concept sheets do not depend on resolving it.

## Validation

Run `python assets/houses/design/mvp-exteriors/build.py`, then `node assets/houses/design/mvp-exteriors/review.cjs` for browser review. The review covers current IDs, earned behavior, explicit-action purchases, owned priority after capacity drops, empty Affordable, stable order, scrolling, local links/images, responsive layout and text bounds. Results and screenshots live beside this handoff. These checks concern the standalone prototype only; they do not validate Roblox gameplay, full Home & Garden scrolling or real phone touch behavior.

Next: select these exterior directions, then build the chosen exterior geometry. Fable can use the B1 handoff to update the native house catalogue within the existing shop. No interior implementation is a prerequisite for either step.
