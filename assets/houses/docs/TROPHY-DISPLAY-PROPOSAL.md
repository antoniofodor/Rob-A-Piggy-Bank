# Trophy displays: making the room worth walking into

Proposal, September 17 2026. Follows `assets/houses/docs/HOUSE-TROPHY-ROOMS.md`, which
approved the three-station direction and fixed the mount names. That plan says
WHERE things go; this one says WHAT they are, and answers the two complaints
from the first walk-in build: the shelf items are too small to identify, and
what does read is text on cards.

Nothing here changes prices, gates, acorn rules or earning logic.

---

## 1. What is actually wrong, measured

### 1a. The shelf mounts are one stud apart

The treehouse's four `Mount_Shelf_*` sit at x −7.44 and −6.44, y 16.53 and
18.73 — a **2 x 2 grid on a 1.0-stud horizontal pitch**. `TrophyRoom.FIT.shelf`
is 0.9 because that is all the room there is between them.

The cabin they are in is **15.6 studs wide, 12.5 deep and 10.5 tall**. So the
entire collection display occupies a 1 x 2.2 stud patch of a 164-square-stud
wall. The constraint is art, not code.

### 1b. Every trophy is authored at lawn scale, and the lawn is gone

Trophies were garden monuments. Measured from their builders:

| trophy | authored size (studs) | scale at `FIT.shelf` 0.9 |
| --- | --- | ---: |
| `haulvault` | 7.0 wide safe | 0.13 |
| `medalboard` | 7.4 wide board on posts | 0.12 |
| `oldhand` | 6.4 wide board on posts | 0.14 |
| `wantedposter` | 6.4 wide board on posts | 0.14 |
| `sirenpost` | 7.6 tall lamp post | 0.12 |
| `hotstreak` | ~7.5 tall brazier | 0.12 |
| `seasoncup` | ~8.2 tall at grade 10 | 0.11 |
| `cleansheet` | ~5.8 tall dial | 0.16 |
| `goodharvest` | ~5.8 tall barrel | 0.16 |
| `victimshelf` | display case, ~7 wide | 0.13 |

**Everything renders at between a sixth and a ninth of the size it was drawn
at.** A shelf trophy is 0.9 studs on its longest side — smaller than the head
of the avatar looking at it. Its individual features are a tenth of a stud: a
flame tier, a dial ring, a rank star and a rosette are all authored around
0.8–0.9 and land at 0.10.

`TrophyService.check` no longer claims a lawn slot, so **no trophy is ever
displayed at the size it was built for.** The scale-to-fit is compensating for
a constraint that no longer exists.

### 1c. Four of the ten are signage, and signage does not shrink

`medalboard`, `oldhand`, `wantedposter` and (nearly) `victimshelf` are **boards
on posts** — 5.6 to 7.4 studs wide, meant to be read from a lawn. At 1/7 scale
the rosettes, stars and posters pinned to them disappear and only the
silhouette survives: a small rectangle on a stick.

That is the literal answer to "they are just cards with words on them". Three
of the four things on that shelf are notice boards.

### 1d. What is left in the room is text

- The `Wall` mount draws **progress plaques**: 2.6 x 1.5 parts whose entire
  content is a `SurfaceGui` label.
- The `Record` mount draws a 3.4 x 2.3 **text board**.
- Every trophy's plinth carries an engraved `SurfaceGui` plate, which at 1/7
  scale is 0.06 studs tall and unreadable — so the plinth is 1.16 of a 5–8 stud
  object, eating a sixth of a keepsake to carry text nobody can read.

From the doorway the room is a text board, a grid of text plaques, and four
specks.

### 1e. And the bag still files them under "Lawn"

`Inventory.SECTIONS` has a `decor` section titled **Lawn** whose "worn" state
is `placed`. Trophies are decor rows, so they appear there as owned and
never-placed, forever, in a tab named after the place they were just removed
from.

---

## 2. Proposal A — the objects

### A1. Author at display size; retire scale-to-fit

`Decor.buildOne` grows one optional `scale` argument — `"monument"` (today's
geometry, for the map and any future outdoor use) and `"keepsake"`. `TrophyRoom`
asks for `keepsake` and does no `ScaleTo` at all. `seat` keeps its pivot work,
which is what lands a model on a mount.

One builder with a size argument, not a second set of builders: a
near-identical copy is the thing that drifts the first time either is touched.

### A2. A keepsake has no plinth

The shelf **is** the plinth. Dropping it returns the sixth of the object it was
eating and removes the unreadable engraving in the same move.

The bought plinth finish (`Config.TROPHY_PLINTHS`) must not lose its purchase,
so it moves to where it can be seen: **the Featured mount keeps its plinth**,
at hero size, with the engraving legible. That is a better home for it than a
shelf was — the finish is now on the one object in the room a visitor looks at.

### A3. Objects go on shelves; boards go on the wall

This is the reorganisation that fixes both complaints at once, and it uses
geometry that already exists.

| goes on `Shelf_*` (object) | goes on `Wall` (board) |
| --- | --- |
| `seasoncup` — the cup | `medalboard` — rosettes |
| `haulvault` — the safe | `oldhand` — rank stars |
| `hotstreak` — the brazier | `wantedposter` — posters |
| `goodharvest` — the barrel | `victimshelf` — the skin case |
| `cleansheet` — the dial | |
| `sirenpost` — the lamp post | |

The boards are already wall-shaped. Hung flat, minus their posts and plinth,
each is a 5.6-wide board on a 15.6-wide wall — **authored size, no scaling at
all** — and their pinned detail reads because it was drawn to. The skin case
joins them because it is a case, not an ornament.

Six objects against four shelf mounts in a rare-tier house is correct: the
owner chooses. Scarcity is the feature, the same argument the nine lawn slots
were built on.

### A4. Silhouette rules for keepsake size

1. **One dominant shape.** A keepsake is recognised by outline at three studs
   and across a twelve-stud room. Anything that needs two shapes read together
   belongs on the wall.
2. **Grade is a count, and a count needs 0.25 studs per unit.** The
   count-per-grade pattern already in these builders is right and it has a
   floor: at keepsake size a flame tier is 0.30 studs and reads; at 0.9-stud
   size it was 0.10 and did not. Any trophy whose grade needs more than about
   ten repeats has to switch to a different signal.
3. **No text is ever the identifying feature.** A number may confirm what a
   shape already said; it may never be the only thing saying it. Text belongs
   in the menu and on the Record board.
4. **Contrast against the shelf it stands on.** The treehouse's shelving is
   dark wood; gold, steel and neon read, dark brown does not.

### A5. Per-trophy keepsake notes

| trophy | keepsake | grade signal |
| --- | --- | --- |
| `seasoncup` | the cup, handles and all | gems across the bowl |
| `haulvault` | the safe, door ajar, bars showing | bars in the opening |
| `hotstreak` | brazier on a short stem | flame tiers climbing |
| `goodharvest` | barrel with acorns heaped over the rim | rings of acorns |
| `cleansheet` | the dial, face to the room | rings stacked forward |
| `sirenpost` | a short post — **not** a scaled 7.6-stud one | lamps up the post |

`sirenpost` is the one that needs re-proportioning rather than re-sizing: a
tall thin post shrunk to fit a shelf is a wire. Author it as a stubby bollard
lamp at keepsake size.

---

## 3. Proposal B — the room

### B1. Treehouse shelf pitch: 1.0 to 3.5 studs

Four mounts at a 3.5-stud pitch span 10.5 studs of a 15.6-wide wall, leaving
2.5 either side. Two rows at 3.5 vertical pitch fit inside 10.5 studs of
height. `FIT.shelf` goes 0.9 to **2.8** — three times the linear size, thirty
times the volume — and the approved rare-tier target of four collection
positions is unchanged.

This is a change to `assets/houses/tools/build_treehouse_runtime.py`, which derives
the mounts, so it is reproducible rather than hand-edited.

### B2. Featured gets the headroom it already has

`Mount_Featured` sits at y 20.94 under a 25.0 ceiling: **4.06 studs of
clearance** against a `FIT.featured` of 3.0. Take it to 3.6 and give it its own
pedestal, separate from the shelving, so the hero object reads as the hero.

### B3. The wall becomes a rack, and an empty position is a socket

With the board trophies moving onto it, the wall stops being a text grid. The
unearned ones then need a picture too, and the honest one is **an empty frame or
socket** — visibly the shape of the thing that will fill it, with nothing in it.

That is the rarity-border lesson: colour is never the only signal. Earned
against unearned should differ in **geometry** — a filled board against an empty
frame — not in a word printed on a plaque. A short label under each socket names
the achievement; the requirement and the count live in the menu.

### B4. Keep one `Wall` mount

`TrophyRoom.fillWall` already derives a grid from a single mount, bounded by the
room's own side walls. The `Wall_2..Wall_N` extension floated in
`HOUSE-TROPHY-ROOMS.md` would double up against that. If art needs control over
how many positions a rack carries, put a `Positions` attribute on the one mount
rather than N names — and keep `Wall` as its name, never renamed to `Wall_1`.

---

## 4. Proposal C — the menus

### C1. They are tabs of the bag, not a new panel

`Shared/Inventory.luau` is already "what you HAVE": a tab rail, a card grid,
never a price, mutually exclusive with the shop, and layered at `Theme.MENU_Z`.
Its **Skins** tab is already a collection log that draws the gaps. An
achievement log is that shape exactly.

Two new sections:

- **Trophies** — one card per `Config.TROPHIES` row, owned and unowned. The
  card renders the trophy's own model in a `ViewportFrame` (the shop's
  `makeModelIcon` already does this), with its name, its grade, and its
  progress: `7 of 10 skins`. An owned card carries a **DISPLAY / ON SHOW**
  toggle and a **FEATURE** action.
- **Records** — the career counters, and any number that does not deserve
  furniture. The Record board in the house stays as the physical tell; this is
  where the full list lives.

And the `decor` section stops listing trophy rows, so nothing is filed under
Lawn any more.

### C2. A prompt opens the bag at a tab

Exact precedent: a shop door on the street opens the shop panel at the tab its
unit sells. The cabinet opens the bag at **Trophies**; the desk opens it at
**Records**.

### C3. Two prompts, not three — which fixes a measured collision

Every prompt in this game is `E` with `OnePerButton`, so only one is ever live.
Measured from gloop-house-v2's own markers, the three interaction anchors sit **8.35,
8.90 and 13.97 studs** apart, and standing on `Stand_Legacy` puts its own anchor
**7.56** away and `Interact_Achievements` **8.5** away — indistinguishable, so
one of the two would silently win.

`Interact_Legacy` is the problem: it is at y 7.7 on a wall with its standing
marker on the floor 7.2 studs below, so the distance is almost entirely
vertical, and a prompt measures to the part's centre. It can never have a tight
range from a floor.

There is also **no Legacy system**: no config, no counter, and `TrophyRoom`
leaves `Plaque_Legacy` deliberately empty. So ship no Legacy prompt. Keep the
mount and the plaque; a control that does nothing when pressed reads as broken.

That leaves Achievements and Records, 13.97 studs apart, safe at any range up to
about 6.

### C4. The display choice is an ordered list, and holds no mount names

Two new fields, both pruned against `Config.TROPHIES`:

- `trophies.display` — an **ordered array** of trophy keys.
- `trophies.featured` — one key. `TrophyRoom.pickFeatured` stays as the default
  this overrides, so there is no state to be missing.

Ordered, not a map keyed by mount, and that is the load-bearing detail. A house
fills `Shelf_1..N` from the front of the list, so a smaller house shows the
first N and **the overflow choices survive by construction** — which is what
`HOUSE-TROPHY-ROOMS.md` asks for, without the save ever naming a mount or a
tier. Moving house cannot strand a selection, and art can renumber shelves
freely.

`DataService.reconcile` already descends into `trophies`, so this is a field
add and not a schema bump — the precedent is the Sneakers rung.

---

## 5. Order of work

1. **Art, treehouse generator:** shelf pitch to 3.5, Featured pedestal,
   `Interact_*`/`Stand_*` markers added (the treehouse has none; gloop-house-v2 has
   all six). Re-run the generator.
2. **Code, `Decor`:** the `keepsake` size, plinth suppressed at that size,
   plinth kept on Featured.
3. **Code, `TrophyRoom`:** objects to shelves, boards to the wall, sockets for
   unearned, no `ScaleTo`.
4. **Code, `Inventory`:** Trophies and Records tabs; trophies out of the Lawn
   section.
5. **Code:** two prompts routing to those tabs; `trophies.display` and
   `.featured` with their prune.
6. **Look at it.** From the doorway, from the shelf, and on a phone. Every
   measurement above is geometry; whether a keepsake reads is a picture.

## 6. What this does not decide

- The other seventeen houses have no interior. Convex-hull mesh collision cannot
  make a room, which is why the treehouse carries 47 authored collision boxes,
  and every code-built tier is `CanCollide` false by design. That is a per-house
  authoring job and it is not scoped here.
- Legacy is deferred, so one of the five staples has no data behind it.
- Capacity per house stays what `HOUSE-TROPHY-ROOMS.md` says it is: the
  template's own `Shelf_N` count, an art target, never a Config ladder keyed to
  rarity — rarity is derived from price, so a re-pricing would otherwise move a
  gameplay number.

---

## 7. What shipped, September 17

Verified in Play on the dev save (5 of 10 trophies earned), clean boot with only
the three pre-existing warnings.

**Done and photographed.** The achievement wall. Three earned board trophies
hang on it at 3.2 studs — the medal rosettes, the wanted posters and the skin
case — and every unearned achievement is an empty socket in a dim mount beside
them, with its name and requirement on a small strip underneath. Earned mounts
are bright and empty ones are dim, so the wall is scanned rather than read. The
rack is inset 0.25 from both corners and clears the side walls by 0.46.

Two tone choices each took a photograph to settle, and both are the same
lesson: this room is interior shade with a cool cast, so every colour lands
well under its own RGB. `SLAB_DEEP` and then `MUTED` both read as **black
rectangles** on a light board; the socket is a shaded sand now.

**Done and measured, not yet photographed** — `screen_capture` went to
returning stale frames part way through the session, which this project already
records as unreliable in Play. Shelf trophies are **2.80 studs** against the
0.9 they were (`Shelved_sirenpost` measured 1.63 x 2.80 x 0.87), the shelf
mounts are **4.0 apart across and 3.5 up** against 1.0 and 2.2, and the hero
trophy stands at 4.20 on its own pedestal, keeping its bought plinth,
engraving and uplights. A 2.8-stud keepsake on the side wall sits flush to the
wall face with no overhang.

**Done.** The **Trophies tab** in the bag: all ten, five reading ON SHOW and
five reading their progress (2 / 10, 10 / 100, 1 / 3, 0 / 1, 0 / 6), and the
Lawn tab is down to its eight real ornaments. The rail's sixth tab measures 126
of a 569-stud total and fits.

### The one thing that is blocked, and it needs a decision

**A template's visible geometry is UPLOADED MESHES.** Moving furniture in
`build_treehouse_v2.py` changes the `.blend` and the `.fbx` on disk and
**nothing in the game**: only the mounts and the collision boxes travel, because
those come from the geometry report. Measured, the mounts moved to the left wall
and the bookcase they were authored against did not, so the first build hung a
trophy in mid-air against a bare wall.

Nor can the code detect what the art already provides: the interior is merged
one mesh per material, so `Interior_WoodLight` is ONE part whose bounding box
spans the room and contains every mount by construction.

So display furniture has one owner and it is `TrophyRoom.standFor` — the boards,
the brackets and the hero pedestal are drawn from the mount names, and the
Blender source no longer authors any. That unblocks the treehouse and is the
better rule anyway: **any future template gets usable furniture from its mount
names alone**, which is the other seventeen houses' whole problem.

**What is still wrong in the treehouse, and only a re-import fixes it:** the OLD
rear-wall bookcase is still standing in the uploaded mesh, in front of two wall
cells, and the three old drawn frames are behind the rack. Re-importing
`assets/houses/treehouse-v2/treehouse-roblox.fbx` clears both — 68 mesh
uploads on the developer's own account, and `studio-import.json` re-recorded
afterwards. The exterior bounds are byte-identical (55.77 x 54.64 x 39.90), so
nothing else about the house moves.

### Still to do

- The **Records tab** (the career counters in a menu, beside the physical board).
- The **two prompts** — cabinet to Trophies, desk to Records — and no Legacy
  prompt, since there is no Legacy system.
- `trophies.display` and `trophies.featured`, so the owner picks what is shown
  instead of the room deriving it.

---

## 8. The door, and a coupling worth writing down

### The door leaf is gone, and laying it flat was tried first

The leaf swung to about 102 degrees, which stood it **five studs into the
room** three studs left of the doorway — a wooden slab across the left half of
the cabin, hiding the wall the shelves now run along, and intersecting the
bench.

Laying it flat against the wall it is hinged on is what a fully-opened door
does, and **there is nowhere to put it.** A 5-stud leaf spans from either jamb
(x ±2.9) to the side wall's inner face (x ±7.8), and the front wall's two
windows sit at x −6.925…−4.675 and 4.675…6.925 — dead centre of that span. A
flat door covers a window whichever way it swings. Outward is refused by the
constraint the original comment already recorded: the leaf would stand on the
porch across the top of the stair.

So the opening keeps its two jamb timbers, its crown beam and its lintel
collider, and reads as a framed opening. **It was a free deletion: the leaf
carried no collider**, so it never blocked walking, only sight.

**An openable door is a different job.** The leaf would have to leave
`merge_static` as its own mesh for the runtime to pivot it, and it would want a
prompt — against a room whose whole purpose is that a visitor walks in and
reads the collection, which the brief states as requiring no menu. Nothing here
blocks it later; it would give this opening a leaf again, hinged rather than
posed.

### And `Plaque_Legacy` was hanging inside a window

The right wall's two windows span y 3.8…6.2 and 8.8…11.2; the mount was at
y 4.5. Latent today, because Legacy is deferred and that mount draws nothing —
which is exactly the sort of thing that ships the day it does. It is at y 7.5
now, in the gap between them.

### REMOVING SEVEN DOOR PLANKS MOVED THE HOUSE

`build_treehouse_v2.py` drew every random choice in the file from one
`random.Random(31)`: the deck boards, the shingles, the stair treads, the
bridge planks, **the canopy jitter**, the stepping stones and the interior
floor, in that order. So deleting the door re-dealt every draw after it, the
canopy jittered differently, and the house's own bounds moved **0.43 studs
wider and 0.37 taller** — measured, 55.770 × 54.644 × 39.901 before and
55.345 × 54.654 × 40.275 after.

That is the expensive kind of coupling here, because **the exterior is 68
uploaded meshes**: an interior tweak that perturbs the canopy turns a free
change into a manual re-import. It also breaks the runtime generator's own
guard — `import_scale` derives studs-per-unit from the recorded import's bounds
against the authored ones, and a 1% disagreement per axis trips its
"not uniformly scaled" check. Which is the right behaviour: a template cannot
be faithfully rebuilt from a recorded import of *different* geometry.

`srng(section)` gives each consumer its own stream (`random.Random` takes a
string seed and is deterministic), so the canopy cannot hear the door. **Any
future interior-only edit now leaves the exterior byte-identical**, which is
the property that makes interior work cheap.

This belongs in `CLAUDE.md` when the docs catch up: it is the same family as
`LOSS_CAP` × `HEIST_PAYOUT` — two things sharing one piece of state, with
nobody checking what the second one did to the first.
