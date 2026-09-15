# Session handoff — 2026-09-15

## Resume here

The user paused the session to move to another machine, then requested a
commit and push of the current changes to `main`.

**Finish the current HUD fixes before continuing the master plan.** Latest
request: move the left menu farther left, replace the oversized/ugly
`USE 2x` boost HUD, fix dragging/reordering hotbar items, and redesign the
next-event countdown. The implementation is on disk and synced through
Rojo, but the latest changes still need a live Studio play-test and visual
review. Do not report this HUD pass as fully verified yet.

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
- The last observed Studio state was **Edit**, iPhone 17 Pro landscape,
  connected to Rojo. The place was reopened from Studio's recent experiences
  after it closed during this session.
- This machine used StudioMCP.exe through a temporary Python stdio bridge.
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
- **Tree earning is not implemented.** Crate conversion, legacy-faucet audit
  and the other Phase 1 steps are still pending. Most crates still cost coins;
  the Alien Cache is currently the Acorn-priced crate.
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
7. Only then return to the master plan. Phase 0 remains deferred. Steps
   1.3–1.10 are open; 1.3 depends on the Phase 2 shake system. Respect future
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
