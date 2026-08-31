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
    BoneModel.luau         Bone geometry, shared by the server and the shop icons
    PigGear.luau           Accessory geometry, shared the same way
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
      BoneService          Thrown bones: the counter to the guard dog
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

**Rebirth wipes power but never cosmetics.** Skins, effects, houses, decorations
and accessories are the permanent progression track that a reset cannot take
away. Rebirth already costs every upgrade a player owns; the collection is the
*reason* to press the button. Take that too and nobody rebirths, which stalls
the economy at exactly the point rebirth exists to unstall.

**ROLLS COST COINS, SO COINS MUST NEVER BE PURCHASABLE WITH ROBUX.** This is the
one line that keeps the accessory roll legal. Roblox prohibits paid
random-chance items for an under-13 audience, and "paid" means reachable with
real money -- shipping a Robux coin pack would turn the roll into a loot box on
the spot, with no code changing here. If a coin pack is ever wanted, the roll
has to move to a currency that can only be earned by playing, BEFORE that pack
ships. Selling a specific accessory outright for Robux is fine; selling the roll
is not.

**An accessory's pivot is its AUTHORED ORIGIN, never its visual centre.** This is
the placement contract, and breaking it broke almost every item at once. A hat
is authored with y=0 at its brim so it can sit ON a head; a shoe with y=0 at the
sole so it can stand on the lawn. Pivoting on the bounding-box centre instead
placed the middle of each shape at the anchor -- which dropped the top hat 1.65
studs and buried its brim two studs inside the skull. The shop icon wants the
other point and computes it for itself in `makeModelIcon`; a model cannot serve
both from one pivot, so it serves the one that has to be right in the world.

**The pig's own geometry is the spec accessories are cut against.** Eyeballs at
x = +/-2.35 and reaching z 5.53; the head's surface at eye height at z 5.62; the
tail a ball standing 1.37 studs proud of the back at y 9.7; the lawn at y 0.5.
Those four numbers decide where glasses, capes and shoes can physically go, and
every clipping bug so far has been one of them ignored -- lenses placed between
the eyes instead of over them, arms run lengthwise through the eyeballs, a cape
hung where the tail already is, wheels authored below the grass. A slot anchor
is the shared attachment point; an item's `offset` in Config is its own nudge
off it, because one anchor cannot suit a cape that hugs the back and a jetpack
that stands off it.

**A roll can only return something you do not already own.** The pool is rebuilt
from the unowned set every time, so duplicates are impossible, every roll is
progress, and the collection always completes. That makes it a guaranteed ladder
wearing the clothes of a gamble -- which is the only honest shape for this
audience. It also means there is no pity timer to tune and no duplicate-currency
to invent: those exist to paper over a problem this design does not have.

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

**Meme ornaments are built as ORIGINALS, never as the named thing.** The silly
half of the lawn shelf — the duck, the swole gnome, the tube man, the loo guy,
the shark in trainers, the drip statue — exists because a fountain says you are
rich and a shark in trainers says you are rich *and* you thought this was
funny, and only the second one gets talked about. But the specific ones a nine
year old asks for by name are property: a fashion house's wordmark, its
interlocking emblem and its monogram canvas are each separately registered, and
the cartoon characters are somebody's copyright. Roblox moderation strips
branded assets and the penalty lands on the **experience**, not the one
ornament — an unshippable game is a steep price for a lawn decoration. What
actually carries the joke is the LAYOUT, and a layout is a genre rather than a
property: a serif wordmark stacked over a roundel, a checked monogram on a tan
holdall, an enormous bath toy. So the statue wears `PIGGY` over a snout
roundel and carries a snout-monogrammed bag, and it is funnier for it.

**A print is drawn, not built.** The statue's shirt graphic and its bag
monogram are SurfaceGuis on invisible panels, because a print is flat and no
arrangement of studs holds a legible word at three studs across. Two things
have already bitten: `Face` must be `Back`, since Front is -Z and every one of
these faces the street on +Z; and the panel has to clear the geometry it sits
on — the bag is centred on z = 0.3 rather than zero, so a symmetric ±1.05
buried the front print inside the bag it was printed on.

**An ornament is seen from the pavement, so its silhouette must work
BROADSIDE.** The shark was authored nose-forward and read as a blue disc with a
horn: a body seen end-on is a circle, three trainers in a row stack into one
white block, and the tail sticks up over the top looking like a fin. Everything
that identifies it lives in the side profile. Anything long gets its long axis
across the viewer — which is also the cheap direction, since a cylinder's own
axis is X.

**`Fabric` is a dark, noisy texture, not a colour.** A bright orange tube man
rendered muddy brown at any distance, and a tan duffel bag rendered near black.
Use it for cloth that is meant to look woven and dark; use `SmoothPlastic` for
anything whose colour is the point.

**A bone buys a window, never the dog.** Bones are the offence tree's answer to
the one defence purchase that had none, and the same line governs both: defence
buys *time*, never immunity — and so does the counter. Four things keep a bone
from deleting the thing it counters, and removing any one of them breaks it:
it costs coins **every time**, so farming a guarded plot is an ongoing expense
that scales with how well guarded it is; a nap is always **shorter than that
breed's own cooldown**, so waiting out a real chase stays the cheaper option;
bigger dogs resist (`boneResist` 1.0 / 0.8 / 0.6); and **only the Golden Bone
interrupts a chase**, so the other two have to be thrown *before* the dog
notices you. That last one is what makes a bone a plan rather than a panic
button.

**A bone throw sends no position.** The client fires `BoneThrow` with a bone key
and nothing else; the server picks the target from its own dog positions. There
is no coordinate to forge and no range check to defeat. It also auto-targets the
nearest eligible dog rather than aiming — most of this audience is on a
touchscreen, where lobbing an object at a moving dog is a fight with the camera,
and "get it near the dog" was never the interesting decision.

**Bones survive rebirth.** Every other offensive purchase is wiped. A bone is
spent the moment it is thrown, so a stockpile is not standing power the way a
maxed tree is — and wiping it would only teach players to burn their stock the
hour before rebirthing, which is a chore, not a decision.

**The top three house tiers sell HEIGHT, because that is the only thing visible
from the road.** A house stands 70 studs behind its own piggy, so up to the
Midnight Modern the driveway has been doing the announcing and the building
itself is a distant shape. The Neon Tower, Marble Palace and Sky Castle go up
rather than out -- 64, 41 and 59 studs against the manor's 35 -- so they clear
the grove behind the plots and read from anywhere on the street, and each
carries emissive detail so they read at night too. Adding a fourth wide house
would have added nothing nobody could see.

**The plot sign carries the boasts, hardest first.** Rebirths, then the house,
then the skin. The house is on there because it is otherwise the least visible
expensive thing anyone owns: past the first few tiers a passer-by cannot tell a
1.4M manor from a 40M palace at that range. The Starter Shack is deliberately
never named -- a sign announcing the free tier reads as a jeer at players who
have not bought anything yet.

**Anything that changes how a plot should LOOK goes through
`CosmeticsService.applyToPlot`.** It is the one function whose job is making the
plot match the data. Buying a house used to call `PlotService.setHouseLevel`
alone, which rebuilt the building while the sign went on announcing the old one
until the player next rejoined.

**A house is bought as a ladder and worn as a shelf.** Two numbers, not one:
`houseLevel` is the highest tier bought and decides what is for sale next,
`houseShown` is the one actually standing. Only the next rung is ever for sale,
but any tier already owned can be moved back into for free, both ways, forever
— so there is no sell-and-rebuy loop to farm. A house is pure taste, the top
tiers cost tens of millions, and forcing someone who liked the Beach Villa to
live in a Neon Tower because they bought one turns a status symbol into a
punishment. Read the pair through `Config.getShownHouseLevel`, never
separately, and note the sign names the house that is STANDING — announcing a
Sky Castle over a villa is a boast about a building that is not there.

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

**A Roblox cylinder's axis is its X axis.** `Size.X` is the LENGTH along that
axis and `Size.Y`/`Size.Z` are the cross-section, so a vertical column is
`Vector3.new(height, d, d)` plus a 90-degree turn about Z -- never
`Vector3.new(d, height, d)`. Written the wrong way round it becomes a disc as
wide as the height was tall, and the turn that was meant to stand it upright
lays that disc flat instead. This has bitten three times now: the decor car's
wheels, the Midnight Modern's pilotis (two black plates hanging in the air
across the front of the house), and it is why `cylinderUp`/`cylinderForward`
exist in PiggyBank.

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

**A long `task.wait` is a state machine that ignores the world.** The guard dog's
patrol pause was one flat `task.wait` of up to six seconds, so nothing that
happened during it was noticed until it expired. Bait a dog just after it
settled into a pause and it stood in the open for the whole nap, then ambled to
its kennel afterwards — and against a short nap it never got there at all, so
the one signal that tells a thief the plot is unguarded never appeared. Chases
and the `dognap` admin command were late for the same reason. It is a polled
loop now. Any wait longer than a frame that sits next to shared state wants to
be a poll.

**`Anchored` set on the client does not replicate.** Setting `root.Anchored =
true` and then a `CFrame` to hold a test character in place leaves the *server*
seeing the character wherever it physically was. A throw-range test built that
way passed at every distance including 70 studs against a 42-stud limit, because
the server never saw the character move. Hold a test character with a per-frame
`CFrame` write instead, and confirm the position server-side before trusting the
result.

**Equipping is a TOGGLE, so a script that fires blind flips things off.** Both
accessories and decorations toggle on a repeated request -- that is deliberate,
since it is the only way to empty a slot without a second control. It means a
test script that "equips" a set it already owns takes the set off instead. Drive
it from the pushed state, not from an assumed starting point. This has now cost
time twice.

**Clipping is measured, not eyeballed.** Every accessory is checked against the
body sphere, the eyeballs, the tail and the lawn line before it is looked at:
whether any part is fully swallowed, whether it enters something it should not,
and for the cape whether consecutive panels still touch. Three separate bugs got
past a screenshot and were caught by numbers, and one "fix" that looked right in
a screenshot had opened gaps between the cape panels. Measure the world-space
extents -- `Size.Y/2` is wrong for the rotated parts half of these are.

**A `CFrame.Angles` sign flips which way a panel leans.** The cape's cloth is
laid along its hang line; with the rotation negated the panels tilted ACROSS
that line instead, swinging each one's lower end forward into the pig. No amount
of moving the cape backwards fixed it, because the geometry was wrong rather
than the position -- which is worth remembering before nudging an offset a
fourth time.

**A HUD overlay near the top of the screen will collide with the shop panel.**
The rebirth button is pinned at y=96 and the panel's header and first row sit
right under it, so it covered the roll button outright. Panel visibility is
watched with `GetPropertyChangedSignal` rather than poked from the three places
that toggle the panel -- two of which are defined above the handler and could
not have called it anyway.

**The MCP `execute_luau` sandbox caches modules per ModuleScript INSTANCE, and
that cache defeats nested requires too.** Requiring a module after editing it on
disk returns the copy the sandbox loaded earlier. Cloning the ModuleScript and
requiring the clone gets a fresh compile of THAT file -- but any `require` inside
it still resolves to the original instance, and therefore still gets the stale
version. Editing Config and then previewing through PigGear failed exactly that
way. When a preview needs current code, run it in a Play session, where the
scripts were loaded fresh.

**Never fail silently.** A rejection the player cannot see is indistinguishable
from a broken feature, and that is exactly how the bug above survived.

---

## Not yet verified

The heist system has never been tested end to end, because it needs two players:
the chase, lock-vs-lockpick timing, the guard dog catch, friend bonus, revenge
markers and the most-wanted hat are all unproven.

Accessories are verified: rolling (twelve rolls, twelve distinct items, zero
duplicates), the escalating price, auto-wearing into an empty slot, the
wear/remove toggle, the locked silhouettes, and survival across a restart at
schema 8 including which slot each item was in.

**The Golden Bone's chase-break is in the same bucket.** Every other bone path is
verified — buy, throw, arc, the trot over, the nap in the kennel, the DISTRACTED
nameplate, the range gate, all four refusal messages, stock accounting including
the refund on a lost race, and persistence across a restart. But a bone thrown at
a dog that is *already chasing someone* needs a real robbery in progress, so
`breaksChase` has only ever run as the "it has already seen you" refusal, never
as the interrupt.

Verified as of the last session: persistence survives a restart (including
schema reconcile), and rebirth's happy path — power wiped, house and skins kept,
rebirth-locked skins becoming wearable.

`Config.NEW_PLAYER_SHIELD` is **15 minutes**. Two players who join and immediately
try to rob each other will see nothing happen and conclude the feature is broken.

---

## Before launch

**Audio licensing: prefer Pro Sound Effects.** The Creator Store is full of
free-to-take sound effects that are lifted from Minecraft or Undertale — "free"
there means costing no Robux, not cleared for use, and a copyright strike
moderates the asset away and leaves a silent game. The `ProSoundEffects`
creator is a library Roblox licensed wholesale and is safe; the dog audio all
comes from it.

The three Creator Store audio IDs in `Config.SOUNDS` are third-party. One asks for
creator credit, and third-party audio can be moderated away without warning. Swap
them for your own uploads.

Roblox prohibits paid random-chance items for under-13 audiences. Everything
purchasable here is a direct purchase; keep it that way.
