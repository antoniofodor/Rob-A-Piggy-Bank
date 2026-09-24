# House interiors — the brief for whoever authors them

Every number here is read out of the running game or out of
`assets/houses/tools/build_house_runtime.py`, which is the only thing that turns
a `.blend` into something the game stands on a plot. Nothing in this document is
a preference; each item is either a contract with the rig, a contract with the
generator, or a contract with the code that draws the trophy display.

Read `assets/houses/treehouse-v3/` alongside this. It is the one house that has
been through the whole pipeline and stood on a plot, so where this brief and that
folder disagree, the folder is right.

---

## 1. Scale is a contract with the character, not a look

**One Blender unit is one stud, and the house is authored at final size.** The
generator derives the FBX importer's factor and cancels it, so what you draw at
is what stands. Do not author small and expect a multiplier: for exteriors there
is a display scale in `build_house_runtime.py`, and **for any house with an
interior it is pinned at 1.0 and must stay there** — a scale multiplies rooms and
doorways while the character stays five studs tall.

The rig, measured on a live character rather than read off a model:

| | studs | why it binds |
| --- | ---: | --- |
| character height | ~5.0 | a room has to feel like a room around this |
| collision bottom above the floor | 2.139 | the legs and feet collide with NOTHING; `HipHeight` holds the body up there |
| jump reach (collision bottom) | 6.14 | `COLLISION_FLOAT + BASE_JUMP_HEIGHT` — a step above this cannot be climbed |
| walk speed | 16 studs/s | a 20-stud room is crossed in 1.25s |

**Minimums that follow.** A doorway at least **7** studs of clear opening (the
treehouse's is 8.7); an interior ceiling at least **8**, and the treehouse's
cabin is **10.5**; any step or threshold under **6.1** or it cannot be jumped.
Aim high rather than tight: a corridor sized to the rig reads as a crawlspace,
because the camera sits behind the head.

---

## 2. What you actually deliver

Three things, and only three, reach the game:

1. **The meshes**, split one per material, as `<folder>/<slug>-roblox.fbx`.
2. **`collisionBoxesDraft`** in `geometry-report.json` — the collision model.
3. **`mountsBlender`** and **`mountYawBlender`** in the same file — named points.

Everything else in that folder is art record. The generator reads those three
keys and nothing else, so an interior that exists only as geometry is an
interior the player walks straight through.

### The collision model is boxes, never the meshes

A MeshPart's collision is a convex **hull** unless it is decomposed, and the hull
of a room is a solid block with the doorway filled in — so the one thing wanted
is the one thing the meshes cannot give. Author invisible boxes instead:

```json
{"name": "Cabin side -1", "blenderLocation": [-8.15, 6.6, 19.75],
 "sizeXYZ": [0.7, 12.5, 10.5], "rotationZ": 0}
```

`sizeXYZ` is in Blender units, which are studs, and `rotationZ` is radians
(matching the geometry reports and runtime generator). Mount yaw below uses degrees. The
treehouse ships 47 boxes against 68 meshes: a deck, three cabin walls, two door
jambs, a lintel **with the doorway left open**, 26 stair treads, a landing,
bridge planks and a lookout floor.

**Two names are load-bearing, and both fail silently.**

* **A floor box must have `deck` or `floor` in its name.** The generator reports
  "no floor box named" otherwise and cannot tell you how high the floor is.
* **Side walls must have `side` in the name.** `TrophyRoom.wallSpan` finds the
  wall it is drawing on by matching `Collide_` + anything containing `side` —
  the treehouse's are `Cabin side -1` and the Gloop House's are `SideWall-1`. A
  room whose walls match neither gets a centred rack of whatever width the code
  happened to want, with nothing in any log.

Stairs are per-tread boxes, not a ramp: a ramp is a rotated box and the audit
below skips rotated parts.

### Mounts are points with a facing, and the art owns the facing

```json
"mountsBlender": {"Wall": [0, 12.65, 20.0]},
"mountYawBlender": {"Wall": 180}
```

**`Mount_Wall` is the only mount the game currently reads.** The trophy room was
cut back to an MVP: three stat panels and a wanted poster on one wall.
`Featured`, `Shelf_1`–`Shelf_4`, `Record`, `Plaque_Legacy` and `Door_Exit` are
still emitted by the generator and read by nothing — author them if the room
wants the shape, but nothing will appear on them.

**The yaw is not optional and cannot be derived.** The runtime used to aim each
display at the doorway, which is correct on a back wall and about 43 degrees
wrong on a side wall. 180 faces the display into the room from the rear wall.

---

## 3. The wall the display needs

On the `Wall` mount the game draws three panels, plus a fourth once the owner has
been top of the Most Wanted board. Each is `PANEL.height` **3.4** studs tall
(3.58 including its rim), separated by **0.42**, and its width is
`clamp((span − gaps) / count, 2.6, 5.0)` where `span` is the clear wall less
**0.3** of inset at each end.

So the clear wall between the side-wall colliders wants to be at least:

```
4 panels x 2.6 + 3 x 0.42 + 2 x 0.3  =  12.3 studs
```

Under that the panels clamp to their 2.6 minimum and start to crowd; over about
**22** they hit their 5.0 maximum and the row is centred with wall to spare. The
treehouse's cabin gives 12.5 and reads correctly. Leave **±1.8 studs** clear
above and below the mount's own height, and leave the wall EMPTY: the panels are
drawn on top of it, so authored frames or posters there end up behind them. That
happened once already and it is what got the treehouse's wall art removed.

---

## 4. Surfaces

* **Flat colour, one material per mesh, no textures.** `SmoothPlastic` at
  runtime. Textured materials are what made the old code-built houses read as
  generic, and a baked texture cannot be prompted away later.
* **`Material.Metal` is not a colour, it is a shading model** — the same RGB
  renders gold on one part and olive on the next. If a colour has to *be* a
  colour, keep it flat.
* **Anything that must glow is Neon and must be a DEEP, saturated colour.** Neon
  renders flat out and the scene's BloomEffect takes it from there, so a pale
  tint becomes a white hole. This project has shipped that mistake four times.
* **There is no night.** One sun at `ClockTime` 14.5, permanently. Do not author
  an interior that depends on being dark, and do not rely on lamps: a PointLight
  at this exposure is invisible, which is why every "lit" detail in the game is
  an emissive part rather than a light.
* **No coplanar faces.** Two faces at the same depth flicker per pixel and per
  camera angle. The convention throughout this project: anything standing on
  something sinks about **0.1** into it, and a detail sits slightly proud of the
  surface it decorates rather than flush with it.

---

## 5. Footprint

The plot is the wall the whole catalogue is against. The fence interior is
**67.2** studs across and `HOUSE_FRONT_LINE` leaves **57** of depth, so nothing
may exceed about **62 × 54** including roofs, wings and overhangs — a house is
seated by its FRONT wall and centred sideways, off its own measured bounds.

Height is the free axis and the one the top tiers are sold on: a house stands 70
studs behind its own piggy bank, so from the street its silhouette is most of
what a player can see. The tallest authored house today is 70 studs.

---

## 6. What "done" looks like

The generator is the acceptance test. Run it and read the three lines it prints:

```
python assets/houses/tools/build_house_runtime.py <slug> <revision>
  N meshes at scale S (1 stud per Blender unit)
  footprint W x D, height H, feet on y 0
  N collision boxes; lowest floor F studs up
  N display mounts: ...
```

`0 collision boxes` or `no floor box named` means the interior did not arrive.
`feet on y 0` must hold — the house is seated on the lawn from the authored
**z = 0** plane, not from its lowest part, so roots and sunk stones belong below
zero and the floor does not.

Then, and only then, it wants a person walking through it in Play: the doorway,
the stairs, the head clearance and whether the camera can follow you inside. Two
things in this project have never been caught by any measurement — whether a
room feels like a room, and whether the camera fights the ceiling.

---

## 7. Where interiors are wanted, in order

`treehouse` and `slime` already have one. The others stand as closed decorative
shells — the doors are geometry, not entrances — so any of them is a candidate.
Worth doing in price order, since a player meets the cheap ones first:
`cottage`, `townhouse`, `villa`, `manor`, then the top end where the rooms can
be strange: `crystal`, `portal`, `void`, `goldenpig`.

**Tell the code owner which houses are getting interiors before you start.**
Their display scale has to be pinned to 1.0 first, and three of them
(`modern`, `crystal`, `goldenpig`) are currently scaled up by 31%, 55% and 38%
to make the price ladder read — an interior authored against today's exterior
would be wrong by exactly that factor.

---

## 8. Walk-in package handoff — September 17

New packages for all 18 permanent houses are listed in
[the house index](../assets/houses/README.md), with an
[exterior/entrance/interior gallery](../assets/houses/walk-in.html).
These are bare main-floor interiors; new mesh imports and live walk-throughs
are still pending. Treehouse and Gloop are v3; the others are v2.

The approved exterior multipliers were baked into these sources before their
rooms and doors were measured. They are recorded as `walkIn.bakedExteriorScale`
in each geometry report. `build_house_runtime.py` detects `walkIn` and uses
display scale **1.0**, leaving the existing exterior revision's scale table
intact. Future changes to exterior size must also update the authored interior
and its clearance checks, rather than multiplying the installed template.

The packages provide `Mount_Wall` without visible decorations, dedicated
collision boxes and separate swing-door geometry/pivot data. The preparation
helper and runtime generator apply Fishbowl's transparent dome. Record fresh
mesh IDs from the unscaled import **before** running the preparation helper.
