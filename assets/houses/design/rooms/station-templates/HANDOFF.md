# B2 — Three-station furniture studies

September 17, 2026. **Draft, assets available for review. Not integrated or visually checked in Studio.**

This continues `assets/houses/docs/HOUSE-TROPHY-ROOMS.md` against the September 17 walk-in update. It replaces no approved house art. Open `index.html` for measured plans; each family has an importable `.rbxmx`, exact part/mount `.json` and `.svg` plan. Rebuild with `python assets/houses/design/rooms/station-templates/build.py`.

## Delivered geometry

| Study | Proposed clear interior W × D × H | Collection | Achievement panels | Furniture + helper parts |
| --- | --- | --- | --- | --- |
| Cozy / Common | 16 × 12 × 10.5 | 2 | 1 | 18 + 1 |
| Classic / Rare | 18 × 14 × 11 | 4 | 2 | 20 + 1 |
| Modern / Epic | 22 × 16 × 11.5 | 6 | 3 | 24 + 1 |
| Royal / Legendary | 26 × 20 × 13 | 10 | 4 | 26 + 1 |

Each has one featured pedestal, a collection cabinet with achievement frames, one desk/book and a separate Legacy plaque. The book is a blank visual prop; no demo trophies or invented awards are included. These counts exclude house shell, runtime trophies, prompts, labels and any collision proxies. The whole furnished house still needs a total parts/mobile budget.

Finish and capacity are independent. Cozy is the smallest fit study, not a rule restricting every cozy house to two positions. A larger cozy house can use a higher-capacity layout with its timber finish; a Legendary modern house requires ten positions. Curved and raised homes require their own layout adjustment. None of these rectangular envelopes certifies fit inside Gloop or Treehouse.

The silhouettes are intentionally simple furniture blockouts. Detailed wear, carved royal trim, actual trophy art and integrated lighting remain visual work after fit review. The current family distinctions are palette, shelf layout and capacity, not finished sculpted art.

## Coordinates and assembly

- Stud units; X right, Y up, Z from doorway into room. Origin is the **inside entrance floor at doorway centre**. Door_Exit is that physical reference only.
- Front faces negative Z. A display's local **+Z** points toward the viewer, matching the existing trophy display convention. Most mounts have yaw 180 degrees; the right-wall Legacy mount has yaw -90 degrees and faces negative X. JSON includes each yaw.
- Mount positions are bottom-centre of usable display volumes, except interaction/standing helpers. A wall volume extends symmetrically about its Z coordinate and upward from its Y coordinate. JSON `usableSize` is local width, height, depth, not an instruction to distort trophy proportions.
- The invisible `MountRoot` at the origin parents Attachments named exactly `Featured`, `Shelf_1..N`, `Wall`, `Wall_2..N`, `Record`, `Plaque_Legacy`, `Door_Exit`, and the six `Interact_*` / `Stand_*` helpers. No attachment is named `Wall_1`.
- Place using MountRoot's frame, not the furniture bounding-box centre or an assumed automatic Model pivot. Map this entrance frame to the house's own floor height and orientation after front-pinning that house. Do not add 28 studs inside the furniture package.
- All exported Parts are anchored, SmoothPlastic and non-colliding/non-queryable/non-touchable. They supply visual geometry, not collision policy. There is no floor or shell in the export and no script, remote, menu or teleport.
- Every coloured part carries a `ThemeToken` StringValue. Colours are resolved from the checked-out Theme file when building; runtime Theme updates do not automatically recolour imported static parts. Palette tokens and exact geometry are in each JSON.

## Display sizes and reading order

Collection slots reserve 2.8 × 2.8 × 2.8 studs, on 4-stud horizontal pitch. Double rows use 3.4-stud vertical pitch. This follows the current keepsake size rather than the earlier unreadable 0.9-stud miniatures. Featured reserves 4.2 cubed, including its purchased plinth finish. Records reserves 4 × 2.3 × 2.2 above the desk, and Legacy reserves 2.8 × 3.1 × 0.4 on the right wall.

One proposed achievement position reserves 3.4 × 2.5 × 0.4. These are compact selected-achievement panels; **they are not the runtime's entire stat-panel strip**. The brief calls for full earned/progress collection access through menus at every house size; this art does not implement that access. Fable should settle the wall-panel interpretation and `Wall_2..N` support before rollout; a panel must not quietly become a shrunken entire strip.

From the entrance, the cabinet is straight ahead, the hero trophy is left, the open records book is right and Legacy is farther along the right wall. A four-stud doorway leads to the central aisle. Dashed lines in the plans are sampled body-centre routes, not walls or gameplay waypoints. Standing markers are invisible.

Approach reveals the appropriate prompt. Deliberate input opens the menu. Proposed prompt titles: ACHIEVEMENTS, CAREER RECORDS, LEGACY. Owner action copy may say VIEW / ARRANGE; guests receive VIEW with the host identified. Do not put edit controls into a guest's view. Use Theme.FONT / Theme.FONT_BODY and Theme.INK on Theme.PAPER for labels. Verify real SurfaceGui text and native prompt dimensions in Studio; browser system fonts are review-page typography only.

## Integration gaps found in current source

1. `House.luau` still constructs the starter's `Walls` as a single solid Part. Its Config footprint is 18 × 14; this study's 16 × 12 clear envelope leaves nominal one-stud sides, but the existing shell has **no measured usable room**. A hollow wall/door/roof revision and actual floor/headroom checks are necessary. Do not insert this furniture into the solid block and report a walk-in house complete.
2. **Runtime changed during this art task.** At the first read, `TrophyRoom.luau` used a large achievement grid. At the final read it has a simplified MVP: three stat panels plus an optional wanted poster, all placed from `Mount_Wall`, with shelf, featured and records content deliberately retired. The 14.68 × 8.22 grid described in the older checker is historical, not the current implementation. This package follows B2's broader three-station brief and is deferred art, not an instruction to undo the simplified MVP. Align the intended next scope before integration.
3. This package uses the brief's Attachment names. The runtime includes a BasePart reader for `Mount_Wall`; Fable needs to normalize wrappers and support the extra wall positions and three prompt/standing anchors. Do not assume that importing the file wires any behavior.
4. If the broader brief resumes, assign one furniture owner before integration: use the authored desk/cabinet/pedestal with display content only, or adapt generated furniture to the same dimensions. The current MVP does not populate the book, pedestal or collection shelves.

These are handoff observations, not runtime edits. Existing gameplay/economy/source changes in the workspace were preserved.

## Verification and next implementation slice

`checks.json` is regenerated from the exact export data. All four studies pass proposed-room containment, pairwise display-volume separation and sampled route clearance against furniture **and occupied display volumes**. Routes use a conservative axis-aligned 2.4 × 6 × 2.4 body at 0.1-stud intervals. Exported XML is parsed back to check Part and Attachment counts. Supporting furniture may intentionally touch or overlap; a complete coplanar audit is not claimed.

The review page also passes browser checks at 1440 × 1040, 1180 × 546 and 390 × 844: four loaded plans, valid local links, no horizontal page overflow or script errors. Screenshots are `review-desktop.png`, `review-phone.png`, and `review-portrait.png`; machine results are in `browser-checks.json`. These are review-page checks, not game UI checks.

These are offline checks, not a continuous swept-body simulation or actual house/plot fit. Studio import rendering, floor collision, camera orbit, scaled avatars, shelf legibility, 546px mobile prompts, pursuit/loot behavior, owner-versus-visitor access and save overflow are still pending.

First integrate only the compact Common study into a genuinely hollow starter shell, verify all three deliberate-input menus and a real avatar/camera, then compare a larger home. Preserve saved overflow and all earned ownership when switching homes. Do not migrate or retire additional lawn content as a consequence of this art study.

## Remaining briefs

B1 already has a catalogue prototype and handoff at `../../ui/`; recent shop implementation also exists. Its older concept IDs must be reconciled with the current registry before reuse. B3 has Mushroom, Treehouse v2 and Gloop v2 assets; fit validation and remaining approved silhouettes are still open. The documented seasonal candy decision and permanent replacement remain unresolved across the briefs. B4–B8 remain later work; this package does not claim them complete.
