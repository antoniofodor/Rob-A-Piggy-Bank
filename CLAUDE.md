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
      NeighborhoodService  Road, trees, street furniture (pure scenery)
      PlotService          Plot pool, fences, ownership
      PiggyBank            The piggy model, coin pile, skins, effects
      House                The upgradeable house behind each plot
      Decor                Lawn, driveway and kerbside ornaments
      GuardDog             Patrolling dog, its kennel, and the off-duty nap
      EconomyService       Accrual loop, milestones, banking
      UpgradeService       The two upgrade trees
      HeistService         Stealing, carrying, tagging, delivering
      CosmeticsService     Buying and equipping skins/effects
      ProgressionService   Rebirth
      SocialService        Friend bonus, leaderboard, revenge markers
      AdminService         Owner-only dev console (F2 in game)
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

**Rebirth wipes power but never cosmetics.** Skins, effects and houses are the
permanent progression track that a reset cannot take away.

**Animated skins are driven on the CLIENT.** The server publishes a `SkinKey`
attribute and nothing else; each client computes colours itself in one shared
Heartbeat loop. Animating server-side would replicate a colour write per piggy
per frame — around 700 property updates a second across twelve plots — to say
something every machine could derive from a single string.

**Every rebirth grants a skin.** The roll decides how rare, never whether.
Rebirth already costs a player every upgrade they own; handing back nothing is
the fastest way to stop people doing it. A legendary is reachable on the first
rebirth (~2.7%) rising to ~31%, with a pity floor at 12. Drop-pool skins have no
`cost`, so `isSkinUnlocked` checks `rarity` before the free-if-costless fallback
— without that, every legendary would unlock for everyone immediately.

**The yard is a rectangle; only its FRONT line is load-bearing.** The fence runs
`YARD_DEPTH` back from the plot centre to enclose the house, but the front stays
at `PLOT_SIZE.X/2 + 1.6` because a thief approaches from the street. Lengthening
the yard behind the piggy changes nothing about the steal, the getaway or the
drop-off, which is what makes it cheap.

**A house tier's `width` is its main block, not its footprint.** Wings, gables
and roof slabs all overhang it -- the Manor measured 65 studs against a 51.2
fence interior and its wings stuck straight through the side fence. `House.build`
builds first, then measures its own bounding box and seats itself: back edge a
fixed distance from the fence, centred sideways. Centring matters because the
villa's garage hangs off one side only.

**The road is a fixed width, never derived.** `ROAD_HALF_WIDTH` is pinned so
that widening `STREET_SPACING` lands on the driveway instead of the tarmac.
`Config.streetMetrics()` is the single source; `NeighborhoodService` used to keep
its own copy of that arithmetic and the two drifted.

**The driveway is the visible half of a house upgrade.** The house stands 70
studs behind the piggy, so from the road its driveway surface is what actually
announces the tier -- dirt, gravel, brick, concrete, slate, lit asphalt. It is
built by `PlotService`, not `NeighborhoodService`, because it is per-owner.

**The moat leaves a causeway the width of the driveway, not the gate.** The
driveway is the only ground outside the fence that must stay usable at every
tier, and a wide bridge does not widen the narrow gate behind it, so this costs
the defender nothing. Anything placed elsewhere on the perimeter ends up in the
water the moment its owner buys tier 5 -- the moat takes the whole ring.

**A plot is three different floor heights.** The lawn is the top of the plot
slab (+0.5), the driveway is paving on the world ground (-0.28), and the verge
is bare world ground (-0.5). `Decor.build` takes a height per zone; passing one
number left everything outside the fence hovering a full stud.

**Decorations are placed automatically and never collide.** Buying one drops it
into the next free slot for its zone. There is deliberately no placement mode:
the lawn is the ground an owner defends on, and more prompts there would compete
with the collect and steal prompts that matter. Every ornament is CanCollide and
CanQuery off, so none of it can body-block a defender, a thief, or the dog.

**Houses confer nothing.** The house behind a plot is pure prestige, priced above
the skins so it stays the last thing anyone finishes. The power balance is a closed
system of speed, time and distance; hanging a stat off a status symbol reopens
every one of those decisions.

**Admin access is authorised on the SERVER, never the client.** `AdminService`
checks its allowlist at the top of the one handler, before reading any argument,
and logs every accepted command and every denied attempt. The client panel is
convenience only — the RemoteEvent exists for every player whether or not their
panel was built, so hiding a button protects nothing.

**Fence collision and decoration are separate.** One invisible slab per side carries
all collision; everything visible has `CanCollide` off. Styles can look like
anything without changing the jump maths, which depends only on `tier.top`.

---

## Gotchas that have already bitten

**Surfaces must never be coplanar — at any scale.** Two faces at identical depth
give the renderer nothing to sort by, so it picks per pixel and per camera angle
and they flicker through each other. This has now bitten three times: the road
against the grass, the moat against the grass, and the guard dog's eyes against
its own face. Detail parts want to sit slightly PROUD of the surface they
decorate, never flush with it. See the `LIFT_` constants in `NeighborhoodService`
and the eye offset in `GuardDog`.

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

**`ProximityPrompt.PromptButtonHoldEnded` fires BEFORE `Triggered`**, and it fires
at hold *completion*, not on release — measured at 0.584s and 0.584s on a 0.6s
prompt. Never clear per-hold state in that handler. Doing so made every steal in
the game silently fail for weeks.

**`CFrame.lookAt` aims LookVector, which is `-Z`.** Models authored facing `+Z`
(the dog, the mini piggy) need `* CFrame.Angles(0, math.pi, 0)` after it, or they
travel backwards. The guard dog ran tail-first through every patrol and chase
from the day it was built until this was caught.

**`Model:PivotTo` moves every descendant.** Anything a model walks *to* must live
outside that model. The kennel started life inside the dog's own model and fled
at exactly the dog's speed, so the dog could never reach it.

**Never fail silently.** A rejection the player cannot see is indistinguishable
from a broken feature, and that is exactly how the bug above survived.

---

## Not yet verified

The heist system has never been tested end to end, because it needs two players:
the chase, lock-vs-lockpick timing, the guard dog catch, friend bonus, revenge
markers and the most-wanted hat are all unproven.

Verified as of the last session: persistence survives a restart (including
schema reconcile), and rebirth's happy path — power wiped, house and skins kept,
rebirth-locked skins becoming wearable.

`Config.NEW_PLAYER_SHIELD` is **15 minutes**. Two players who join and immediately
try to rob each other will see nothing happen and conclude the feature is broken.

---

## Before launch

The three Creator Store audio IDs in `Config.SOUNDS` are third-party. One asks for
creator credit, and third-party audio can be moderated away without warning. Swap
them for your own uploads.

Roblox prohibits paid random-chance items for under-13 audiences. Everything
purchasable here is a direct purchase; keep it that way.
