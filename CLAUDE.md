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

**Nothing the game owns may stand in an accessory anchor.** The four anchors
are the player's, permanently: whatever they roll has to be able to sit there.
The Vault Lock's padlock was built at (0, 15.2, 0), which IS the hat anchor at
14.15 plus a stud, so every hat in the game spawned inside it and neither could
be seen. It was not a tuning problem and no offset would have fixed it. The
lock is a vault dial on the front flank now -- the only patch of the body that
is both empty and turned towards someone walking in from the street, since the
top is the hat, the front is the snout and the eyes, the back is the cape and
the tail, and the underside is the four legs. Its clearances are measured in
`DIAL_MAX_R`: grow the plate past 1.95 and its top edge reaches the eyeballs.

**A defence upgrade has to be visible from outside the fence, and legible at
the piggy.** A ProximityPrompt draws the same filling circle whether the hold
is three seconds or nine, so without a body on it the whole Vault Lock tree was
invisible to both sides -- the defender could not see what they had bought and
the thief could not see what they were up against. The dial ramps two things
because they land at different distances: the metal (iron, bronze, steel, gold)
carries from the street, where a thief decides whether to come in at all, and
the spoke count (2 to 5) only resolves up close, where they are deciding
whether to commit to the hold. Neither needs counting -- a 2-spoke wheel is a
bar handle and a 5-spoke one is a bank vault.

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

**Anything positioned relative to the yard must measure from `YARD_DEPTH`, not
from the plot slab.** They were the same number until the fence was lengthened
to enclose the house, and everything anchored to the old edge went silently
wrong rather than erroring. The grove behind the plots was placed at
`rowZ + halfPlot` (24) instead of `rowZ + YARD_DEPTH` (70), which dropped the
first row of trees 46 studs inside the fence — full-grown trees standing on
people's lawns among their houses. When a derived constant stops being derived,
grep for everything that assumed it.

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

**Slots are scarcer than items, and the ring is full at seven.** Twelve lawn
items against seven slots is deliberate: the lawn is a shelf you curate, not a
checklist you complete, and choosing what stays in the shed IS the decoration.
Seven is also the physical limit — the lawn is 48 studs across with a piggy in
the middle, the widest ornament measures 12.5 across the gnome's fists, and the
ring positions are 15 to 19 studs apart, which is exactly what the two widest
items standing side by side need. An eighth squeezed between two of them puts
an ornament through its neighbour, and the obvious front-centre spot at
(0, 19) is the walk from the gate to the piggy. Before adding a slot, measure
the two widest footprints against the closest pair.

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

**Every decoration slot faces the road, and none of them carries a yaw.**
Plot-local +Z is the street on both rows — the far row's half-turn is already
in its plot CFrame — and every builder authors its ornament facing +Z, so an
unrotated slot points the one good angle at the one place anybody stands. The
slots used to scatter by 20/90/155/200 degrees to read as a garden arranged by
hand rather than a showroom, which works on a plan view and nowhere else: the
two back slots were turned past 90, so the trophy showed its blank back, the
drip statue faced its own house, and the shark went nose-on again — the exact
bug its builder was rewritten to fix. Variety nobody is standing where they
could see is not variety. `Decor.build` still reads `slot.yaw`, so a slot that
genuinely wants an angle can carry one; nothing does.

**`Fabric` is a dark, noisy texture, not a colour.** A bright orange tube man
rendered muddy brown at any distance, and a tan duffel bag rendered near black.
Use it for cloth that is meant to look woven and dark; use `SmoothPlastic` for
anything whose colour is the point.

**Nothing here can be DUG, so sunkenness is always an illusion.** The world
ground is one solid Part and a Part cannot cut a hole in another Part. Setting
the moat's water surface 0.16 below ground level did not make a trench — it
made the moat vanish, because the grass is still there above it. Every layer of
the channel sits *proud* of the ground and the depth comes from the kerbs: two
stone banks standing 0.5 above the grass with the water surface 0.19 below
their top edge, because the eye takes the highest line as ground level. Then an
opaque dark bed under half a stud of translucent blue, or the water tints the
grass beneath it and the moat comes out pond-green. This applies to anything
else that ever wants to look excavated.

**The moat's kerbs belong to the RING, not to the bands.** The water is cut
into five bands that overlap at the corners, so a kerb built per band ran
straight across its neighbour's channel and the moat came out with stone bars
lying across it like cattle grids. There is an outer edge and an inner edge;
the kerb is two closed rectangles laid on those, and it does not care how the
water was divided up.

**The moat is animated on the CLIENT, like the skins.** The server builds the
channel once and publishes each band's span as an attribute; every machine
works the surface bob and the travelling ripples out for itself. Driving it
server-side would replicate a CFrame and a Transparency write per band per
frame — twenty-five parts for one moat, before anyone buys a second. The parts
are found by CollectionService tag rather than collected once at startup,
because a moat is built when someone buys the fifth fence and torn down when
they rebirth.

**The dodge is a MULTIPLIER on `currentSpeed`, never a teleport.** That single
choice is what makes it safe. `currentSpeed` is the one function that owns every
speed in the game, so adding one more factor there means the dodge inherits all
of them with no new balance code: stunned returns 0 before the dodge is reached
(a zapper cannot be rolled out of), carrying scales it off 12 rather than 16, a
snag makes it proportionally slower, and riding refuses it outright. An impulse
or a CFrame nudge would have been a second, parallel way to move that none of
those numbers knew about. The DISTANCE is deliberately tiny -- about 4.5 studs,
a tenth off a 37-stud getaway. **The immunity is the point:** half a second where
you cannot be tagged, caught or hit, against a `TAG_HOLD` of 0.4s, so a defender
who eats a dodge starts their hold again. A dodge buys a moment, never an
escape, and it is free for everyone because it is a control rather than a power.

**ClientMain is near Luau's 200-local-register ceiling.** It hit it, and the
error names an innocent variable far from the cause ("Out of local registers
when trying to allocate dayLabel"). Every HUD feature added this session was
keeping four top-level locals for its state; they are now one table each
(`gadgetUI.tiles`, `stealthUI.held`). Group any new feature the same way rather
than adding four more -- and note the budget is being spent by more than one
person at a time.

**The guard dog does not watch an approach.** `GuardDog.chase` only fires from
`HeistService.attemptSteal`, AFTER a completed steal, so walking up to somebody's
piggy and holding their lock for up to twelve seconds carries no dog risk at
all. Every bit of pressure in this game is on the run home. Any "be sneakier"
feature has to be designed against that fact or it solves a problem that does
not exist -- which is why the Disguise Kit is sold as a WAITING tool and why
spring shoes were dropped (fences are already jumpable at 6.0 against a 7.2
jump, and the toll is the ClimbZone snag, which spans y 5.5 to 10.5 and catches
you on the way up whatever your apex).

**The disguise hides the wait, never the getaway.** Standing still IS the
disguise -- drift past `drift` studs and it drops -- so it is self-limiting by
construction and needs no timer worth tuning. It breaks the instant loot is
picked up, without exception, because the run home is the risk half of the
whole trade and must stay visible. It deliberately survives the LOCK HOLD,
which is the joke. It also blocks rides: `StealthService` hides the character by
walking its descendants ONCE at conceal time, so a board mounted afterwards is
not on the list and would be a floating motorbike parked inside an ornament.

**Cheap counters bounce, the expensive one gets through -- on BOTH sides.** The
Guard Duty Treat refuses the two cheap bones and admits the Golden Bone; the
Raincoat sheds the plunger and the gum and admits the Zapper. Same shape twice,
on purpose: each raises the PRICE of beating someone rather than making them
unbeatable, and each keeps the top item of the other tree meaningful. Neither
touches speed, which stays capped at 16.

**The Guard Duty Treat exists to get people out of the house.** The economy
needs players robbing each other, and what stopped them was anxiety about their
own vault: there was no "lock up before you go out" action anywhere, so the only
way to protect a full piggy was to sit on it, and a player sitting still is the
worst outcome this design has. The treat does NOT grant immunity -- a Golden
Bone still gets through, the same line the chase-break draws. A prepared
defender makes robbing them cost 30,000 instead of 2,500 rather than closing the
door, which matters because an alert Titan runs at 17 against a thief carrying
at 16 and "cannot be bribed" would simply mean "cannot be robbed". Guard duty
also suppresses the dog's cooldown, so it is checked through `onCooldown` in one
place rather than at the six sites that used to compare against `busyUntil` --
miss one and the dog naps through the thing its owner just paid to prevent.

**A buff nobody can see is a trap, so guard duty is loud.** Neon collar, ON
GUARD on the nameplate, and the refusal names the rule. The counter to a buff
should be information rather than a fight: a thief reads it from the pavement
and walks to one of the other eleven plots, instead of burning a 30,000-coin
Golden Bone to find out. Anything that repaints the dog has to restore the tell
-- `applyTier` repaints every piece from the tier, and `rouse` rewrites the
nameplate, so both check guard duty first.

**The sprinkler is a joke and must stay one.** No damage, no stun, no slow: it
nudges trespassers toward the gate and soaks them, and they can walk straight
back in. Loitering is not a mechanical problem here -- `STEAL_COOLDOWN` and
`STEAL_MAX_PER_VICTIM` already make camping a plot pointless -- so the
irritation is social and the answer is too. Anything with teeth would be a
fourth defence stacking on the fence, the dog and the locks, and it would bite
during a steal attempt, since a thief cracking a lock is stood still on that
very lawn. It never touches the owner, and `HomeUse` carries no target
argument at all: the server acts on the caller's own plot or on nothing.

**A gadget buys a tag, never the catch.** Gadgets are to maxed Speed Boots
what bones are to the guard dog: the counter to a top-of-tree purchase that
had none. `getCarryMultiplier` caps at 1.0, so a thief with boots maxed carries
at 16 -- the SAME speed as the person chasing them -- and tagging becomes
impossible unless you are already on top of them. Four things keep the fix from
becoming the disease, and removing any one breaks it: they only work on
somebody **carrying loot**, so there is no way to point one at a player who is
not currently robbing someone; they **cost coins every throw**; **tagging still
recovers the loot**, so a gadget is setup and never the terminal action; and
**range falls as power rises**, so the decisive one cannot reach a thief who
already got clear. The first is not a balance rule, it is a shipping
requirement -- without it this is a harassment toy handed to under-twelves.

**Nobody rides while loot is in transit, not just the two players involved.**
Blocking only the victim left any BYSTANDER free to stay on a scrambler at 33.6
and run down a thief doing 12, and `HeistService.tag` lets anyone tag. That is
not a chase, it is an execution. Server-wide is also the version that reads as
a rule rather than a restriction: when the alarm goes, the whole street is on
foot. A carry lasts seconds, so the cost is small and the drama is free.

**The hotbar carries throwables, never rides.** Bones and gadgets share it
because they are the same gesture -- hold a stock, pick one, throw it -- and
two bars for one verb costs twice the phone screen to teach a distinction the
game does not make. Rides are excluded on purpose: mounting is automatic and a
ride cannot be used during a chase, so a slot for one would be inert at exactly
the moment the bar matters. Keys are FIXED per item, never renumbered to fill
gaps, or the key that threw a 1.5K plunger a moment ago throws a 22K zapper
once a stock runs out.

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

**A ride is for the street, and is switched OFF everywhere else.** Rides run
straight into "speed is the currency": the scrambler doubles `BASE_WALK_SPEED`,
which is the number the carry penalty, the three dog speeds, every fence snag
and the 37-stud getaway are all calibrated against. So the whole design is the
conditions that disable it -- carrying loot, being robbed, snagged on a fence,
or not standing on the street. Drop any one and a specific system dies: a thief
rides away from a three-second getaway, or a defender at 33.6 catches every
thief who ever tried at 12. What is left is the walk between plots, which was
the one part of this game that was pure holding W. Like a house, a ride confers
nothing else.

**"On the street" is narrower than "not in a yard", and the gate tests both.**
`Config.isOnStreet` is the positive rule and the one players are told: the
corridor between the two rows of front fences, plus the arrival plaza. It rules
out the woodland behind the plots and the twelve-stud alleys between
neighbouring yards -- public ground, but not a street, and not somewhere anyone
should be crossing at 33 studs a second. `PlotService.yardContaining` (the
FENCE rectangle, not the plot slab) is then a veto on top. The two cannot
disagree with the plots where they are, but one of them is balance-critical and
the other is tidiness, so the yard test runs first and fails safe. Because
`isOnStreet` needs to know where the street ends, the plaza and road extents
now live in `Config.streetMetrics()` -- which is memoised, since the ride gate
asks it ten times a second per player.

**Mounting is automatic, and `HipHeight` is what does it.** No button, no
prompt -- you leave your gate and you are on it, which also means a thief
learns the getaway is on foot by watching the board vanish rather than by
reading a message. Every ride is authored with y=0 AT THE GROUND, so seating
one at the character's feet buries the rider's shins in their own deck. The
model goes on the floor and `Humanoid.HipHeight` is raised by the ride's
`stand` height to lift the rider onto it. Set HipHeight FIRST and compute the
placement from the new value: the weld locks in whatever offset exists at that
instant, and the character has not physically risen yet. Restore the
REMEMBERED base value on dismount, never by subtracting -- a respawn in
between hands you a fresh humanoid at the rig default, and subtracting from
that leaves a player permanently a stud taller than everyone else.

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
lays that disc flat instead. This has bitten five times now: the decor car's
wheels, the Midnight Modern's pilotis (two black plates hanging in the air
across the front of the house), the most-wanted hat -- which stood a neon
rod out of the top of the wearer's skull rather than laying a brim on it,
and is a floating label now -- the piggy's own padlock, whose shackle was
Vector3.new(1.5, 1.5, 0.55) and so was a rod aimed at the camera instead of
a U over the body, which is why nobody could tell what it was -- and it is
why `cylinderUp`/`cylinderForward` exist in PiggyBank.

**Luau forward references.** A `local` declared *after* a function that reads it
silently becomes a nil global. This has caused three bugs so far. Declare shared
state above its readers.

**`SurfaceGui` culls by distance from the character, not the camera.** A screenshot
with the camera moved but the character left behind will show a blank board even
when it works in game. The physical leaderboard needs a one-time client-side
`Enabled` off/on nudge after replication — that is a workaround, not a fix.

**Roblox `NormalId`: Front is `-Z`, Back is `+Z`.** Plot signs sit on the `+Z` edge
and need `Back`.

**Never write `TextWrapped` next to `TextScaled`.** Setting `TextWrapped = false`
*after* `TextScaled = true` silently turns `TextScaled` back OFF and drops the
label to the default `TextSize` of 8 — measured on the plot sign, where both
rows rendered as a faint smudge. `TextScaled` implies wrapping. The way to stop
text overflowing is to give the row enough height for the lines it will wrap
into, not to disable wrapping: a wrapped line in a too-short row falls off the
bottom and gets clipped, which is how a maxed-out player's sign came to read
"12* · Neon Tower ·" with the skin missing. `TextBounds` against `AbsoluteSize`
is the check; `TextFits` alone can report true while the last line sits exactly
on the frame edge.

**The sign's ARM is what reaches over the lawn, not the board.** Clearance
between the plot sign and the decor slots has to be measured against every sign
part, because the piece that comes closest to the grass is the cross-arm
hanging back over it. Eyeballing it off the signboard put the first placement
4.9 studs clear when the widest ornament needs 6.4.

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

The vault dial's SPIN is in that bucket too. All four tiers are verified
live -- the plate grows 3.10 to 3.90, the spokes go 2 to 5, level 0 destroys
the wheel and hides the plate, and the layers sit at 0.40 / 0.75 / 0.85 studs
out so no two faces are coplanar. But `rattleLock` only fires on a steal
hold, so the dial has never actually been seen turning.

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
