# Rob a Piggy Bank

A Roblox shared-economy PvP game for an under-12 audience. Players own a plot with a
piggy bank that fills with coins over time; other players can steal from the
*uncollected* portion. Defence and offence are competing upgrade trees.

The full design rationale, balance targets and build phases are in
[`docs/design-doc.html`](docs/design-doc.html) — open it in a browser.

---

## Getting set up

The game is **generated entirely in code**. There is no hand-built geometry: the
ground, the street, the houses, all twelve plots, the piggies and the dogs are
constructed at server start. A fresh empty place plus this repo gives you the
identical world, which means the `.rbxl` is disposable and this repo is the project.

1. Install [Rojo](https://rojo.space) 7.7+
2. `rojo serve default.project.json`
3. In Studio: **Plugins → Rojo → Connect**
4. Press Play

`rojo build default.project.json -o RobAPiggyBank.rbxlx` produces a complete place
file if you need to open one without syncing.

---

## Layout

```
src/
  ReplicatedStorage/Shared/
    Config.luau            Every tunable number in the game
    Remotes.luau           Every client/server channel, declared in one table
  ServerScriptService/
    Main.server.luau       Entry point: starts services, owns player lifecycle
    Services/
      DataService          Session-locked DataStore persistence
      WorldService         Ground and lighting
      NeighborhoodService  Road, houses, trees, street furniture (pure scenery)
      PlotService          Plot pool, fences, ownership
      PiggyBank            The piggy model, coin pile, skins, effects
      GuardDog             Patrolling dog that chases thieves
      EconomyService       Accrual loop, milestones, banking
      UpgradeService       The two upgrade trees
      HeistService         Stealing, carrying, tagging, delivering
      CosmeticsService     Buying and equipping skins/effects
      ProgressionService   Rebirth
      SocialService        Friend bonus, leaderboard, revenge markers
  StarterPlayer/StarterPlayerScripts/
    ClientMain.client.luau HUD and shop panel
```

---

## Rules that are load-bearing

Breaking any of these silently breaks the game rather than erroring.

**The server owns all state.** The client renders whatever the last `StateUpdate`
said and never computes a balance. If client and server disagree, the server is
right by construction.

**Only uncollected coins are stealable.** Banked coins are permanently safe. A
robbery costs the victim a few minutes of idle income and never costs progress.
This is what keeps the game from being a bullying simulator, and it is why the
caps in `Config` are hard limits rather than discouragements.

**`STEAL_RANGE + DROPOFF_RADIUS` must stay well under `PLOT_SPACING`.** At 11 + 16
against 64 the shortest possible getaway is 37 studs, about 3 seconds. If that sum
approaches the spacing, a thief can stand in their own drop-off zone and rob a
neighbour without ever running — and the run is the entire risk half of the trade.

**Speed is the currency.** `BASE_WALK_SPEED = 16` is the number every other system
is calibrated against: the carry penalty (×0.75), Speed Boots (capped at ×1.0, so
they never exceed base), dog speeds (12 / 14.5 / 17), fence snags (×0.80 → ×0.30)
and the electric stun (0). Anything that makes a player faster than 16 invalidates
several systems at once.

**A fence must never be uncrossable.** Defence buys *time*, never immunity. An
un-robbable player kills the offence tree and stalls the economy at the top. Every
tier from Barbed Wire up stays at a jumpable 6.0 studs and escalates the hazard
instead — `BASE_JUMP_HEIGHT` is 7.2.

**Rebirth wipes power but never cosmetics.** Skins and effects are the permanent
progression track that a reset cannot take away.

**Fence collision and decoration are separate.** One invisible slab per side carries
all collision; everything visible has `CanCollide` off. Styles can look like
anything without changing the jump maths, which depends only on `tier.top`.

---

## Gotchas that have already bitten

**Flat surfaces must never be coplanar.** A part whose top face sits exactly at
ground height z-fights — the renderer has no way to sort two surfaces at the same
depth, so it picks per pixel and the grass flickers through. See the `LIFT_`
constants in `NeighborhoodService`.

**Luau forward references.** A `local` declared *after* a function that reads it
silently becomes a nil global. This has caused three bugs so far. Declare shared
state above its readers.

**`SurfaceGui` culls by distance from the character, not the camera.** A screenshot
with the camera moved but the character left behind will show a blank board even
when it works in game. The physical leaderboard needs a one-time client-side
`Enabled` off/on nudge after replication — that is a workaround, not a fix.

**Roblox `NormalId`: Front is `-Z`, Back is `+Z`.** Plot signs sit on the `+Z` edge
and need `Back`.

**Studio forks scripts when you press Play.** Save, wait a beat for Rojo to push,
*then* Play — otherwise you test stale code and chase a bug you already fixed.

---

## Not yet verified

The heist system has never been tested end to end, because it needs two players:
the chase, lock-vs-lockpick timing, the guard dog catch, friend bonus, revenge
markers and the most-wanted hat are all unproven. Rebirth's happy path is likewise
untested — only its guards are.

`Config.NEW_PLAYER_SHIELD` is **15 minutes**. Two players who join and immediately
try to rob each other will see nothing happen and conclude the feature is broken.

---

## Before launch

The three Creator Store audio IDs in `Config.SOUNDS` are third-party. One asks for
creator credit, and third-party audio can be moderated away without warning. Swap
them for your own uploads.

Roblox prohibits paid random-chance items for under-13 audiences. Everything
purchasable here is a direct purchase; keep it that way.
