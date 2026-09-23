> **Layout moved, 2026-09-22.** Every skin now lives in
> `assets/piggies/<tier>/<key>/` with four rooms -- `source/`, `generate/`, `sheets/`,
> `preview/` -- and a `manifest.json`; that folder is the source of truth and
> `assets/piggies/README.md` describes it -- including, since later the same
> day, the four legendaries, the shared `metal/` pack and every derived import
> package (`package/`). The toolkit, the master scene and the method below are
> unchanged and still live here; `skins/` holds only the designer's copies to
> clean up. Where this file says `skins/<skin>/...`, read the room named in the
> README.

# Making a skin

This is the method the tiger was made with, and it is the method for every skin
after it. It replaces the older "open one file and paint" note, which was
written when there was one skin and does not survive there being two.

---

## The shape of it

**A skin is a PYTHON SCRIPT, not a .blend file.** The blend is derived
output; the script is the thing that is reviewed and re-run. `blender/.gitignore`
ignores `*.blend` in THIS tree on the correct argument that a scene file is
large and is rebuilt by the script beside it. (`assets/piggies/` commits the
scene anyway, because that folder is the designer's source of truth and a
scene somebody has turned dials in by hand is worth carrying -- but the script
is still the thing that can be diffed and re-run.) Anything authored only
inside a blend and not committed is work with no backup and no diff.

```
blender/pig/
  paths.py  pig_uv.py  skin_colours.py  skin_parts.py  png_write.py
                       the TOOLKIT. Five modules, no side effects, imported
                       by everything. They sit at the root because that is
                       what every script's bootstrap walks up to find.
  make/                the pipeline you actually run
  masks/               the old cylindrical-unwrap toolchain
  look/                looking at the geometry
  retired/             recorded dead ends, kept on purpose
  pig/                 the ANIMAL: its scenes and the meshes that get uploaded
  skins/               empty of skins since 2026-09-22 (copies left for clean-up)
  renders/             pictures. All reproducible, none of them kept.

assets/piggies/<tier>/<key>/  one folder per skin -- see assets/piggies/README.md
  source/              the scene (open and closed-back) and a rare coat's spec
  generate/            make_<key>_blend.py, and every number in it
  sheets/              what gets uploaded, with the open-hatch sheet kept beside it
  preview/             the game-lit view scene, the renders, the shop card
  manifest.json        Config row, SurfacePacks templates, the live ids, their sources
```

**`paths.py` is the only file that knows any of that.** Every location in
every script goes through it, so the next reorganisation is a diff in one
file rather than a hunt through sixty `os.path.join` calls. That is the same
argument `pig_uv.py` and `skin_colours.py` already make one level down, and
this project has paid for getting it wrong often enough to write it down.

**A skin owns a folder and everything in it is named after the skin:**

```
assets/piggies/common/tiger/generate/make_tiger_blend.py   the pattern, and every number in it
assets/piggies/common/tiger/source/tiger.blend             open this to look and turn nodes by hand
assets/piggies/common/tiger/source/tiger_closed.blend      the same scene with the hatch filled
assets/piggies/common/tiger/sheets/tiger_body_color.png    the two sheets that get uploaded
assets/piggies/common/tiger/sheets/tiger_trim_color.png
assets/piggies/common/tiger/preview/tiger_view.blend       the game-lit preview, rewritten each render
```

which is why `bake_skin.py` takes `--skin` and nothing else now. It used to
take `--blend` as well, so `--skin tiger --blend pig_bee.blend` was a legal
command that baked one animal's materials into another animal's sheets.

**Every script starts with the same bootstrap** that walks up from its own
location until it finds `paths.py` -- or, for a generator living outside this
tree in `assets/piggies/<tier>/<key>/generate/`, the repo root holding
`blender/pig/paths.py`, which it then puts on the path. Depth independent on
purpose: a script in `make/` is one level down and a generator is three under
a different top-level folder, and a hardcoded `..` is the thing that breaks
silently the first time anything moves. (It did, on the day of the move; the
walk accepts both spellings so a copy left in `skins/` still runs too.)

---

## The loop

    blender --background --python assets/piggies/common/tiger/generate/make_tiger_blend.py
    blender --background --python blender/pig/make/bake_skin.py       -- --skin tiger
    blender --background --python blender/pig/make/make_view_blend.py -- --skin tiger --render

(from the repo root; every path is resolved by `paths.py`, so the cwd does not
matter). About six seconds end to end. Then look at `renders/view_tiger_*.png`, decide
what is wrong, change **one number** at the top of the skin script, and run it
again. That cycle is the whole point of the method: nothing is hand-placed, so
nothing has to be hand-fixed.

**Judge it on the crown and the spine, not the hero shot.** A three-quarter
view is exactly the angle that hides an unwrap problem. It earned its keep on
the Rainbow Tiger, where ten hues won the hero shot and lost both of these --
and it would have shipped off the three-quarter view.

**BUT A DARK SHOT IS NOT EVIDENCE OF A DARK MARKING, AND THE SPINE VIEW IS
WHERE THAT BITES.** The game's sun sits west of south and lights the animal's
FRONT-RIGHT; the spine camera looks at the rump from behind. So a rump renders
near-black whatever colour is painted on it, and a marking read off that shot
is being judged in shadow. Two builds of the Storm Wolf were retuned against
it before a histogram of the baked sheet said the saddle was 26% of the body
island against the coat's 33% -- a perfectly healthy marking, twice adjusted
for a fault that was the lighting.

Same family as *a capture is evidence of presence and never of absence*. The
cheap instrument is a **unique-colour histogram of the SHEET**, which has no
lighting in it at all: `look/check_fade.py` already prints the palette, and
counting texels per authored colour is a few lines on top of it.

---

## Two skins at once

**The authoring loop above is safe to run in parallel.** Everything it touches
is named after the skin -- the script, the scene, both sheets, the preview
scene and every render -- so two of them never write the same path. They are
separate Blender processes, so the only thing they share is the CPU, and a
Cycles bake at 2048 will use all of it: expect them to take longer each rather
than to interfere.

**Three things are shared, and all three are WRITES to something every skin
reads.**

1. **`pig/pig_parts.blend`, the master.** Every skin script reads it, which is
   fine any number of times at once. `make/make_parts_blend.py` REBUILDS it --
   so running that while anything else is mid-bake hands the bake a
   half-written file. It also destroys hand work. One at a time, with nothing
   else running.
2. **`Config.luau`.** Every skin needs a `SURFACE_PACKS` row and a `surface =`
   line, and two sessions editing that file is the one collision nothing in
   this toolchain can catch -- see `CLAUDE.md`, which records two correct fixes
   composing into a third bug. **One owner, announced, at a time.**
3. **The toolkit at the root.** Two agents each improving `paths.py` or
   `skin_parts.py` is the same failure one level down.

**And the uploads are not parallel work at all.** Every one publishes under
your own account and is moderated; `CLAUDE.md` records the session where that
cost the account, not the experience. Bake and preview as wide as you like;
upload deliberately, one skin at a time, having looked at it.

---

## Writing a new skin

Copy `make_tiger_blend.py` and change the middle of it. The parts that are not
about tigers, and that every skin wants:

**1. One dict of tunables at the top.** `STRIPES`, `BELLY`, `NOSE`, `EYES` on
the tiger. Every number that decides what the coat looks like goes in there
with a comment saying what it does, so a note like "too many stripes" is a
one-line edit rather than a hunt through a node graph.

**1b. `to_linear` TAKES 0..1 AND THE FAILURE IF YOU FORGET IS TOTAL AND
SILENT.** Every skin here writes its colours as bytes and divides by 255 at the
call site. Hand `to_linear` the bytes instead and it raises them through the
sRGB curve without complaint, returning values in the HUNDREDS OF THOUSANDS --
and what bakes is a WHITE PIG WITH FAINT RIPPLES IN IT, which is
indistinguishable from a broken shader. It cost a whole build on the Phoenix
and was found by dumping ColorRamp stops rather than by looking.

There is a guard in `skin_colours.to_linear` now that names the fix, and all
fourteen existing skins were rebuilt to prove it does not fire on them. It is
still worth knowing, because the guard tells you WHAT went wrong and this tells
you what it looked like.

**2. The pattern is defined in 3D. Never in UV space.** This is the rule the
whole pipeline rests on. Feed the graph `Texture Coordinate → Object` and work
in the pig's own frame; the shader is evaluated at a POSITION on the surface,
so it does not know the texture sheet exists. Smart UV Project can rotate every
island however it likes and a stripe still runs where the geometry says it
runs. The bake resolves it afterwards.

> The old note in `build_pig.py` measuring island coherence — 0.583 on the body
> against a cylinder's 0.941 — is about a generator **walking the flat sheet**
> to compute an alpha, where neighbouring islands disagreeing about which way
> is up tears a band in half. It does not apply to a shader, and using it to
> block this was the wrong measurement for the job.

**3. Two materials minimum, and the body's may not be the trim's.**
`bake_skin.py` walks each object's slots and points every material at the
group's bake image, so a material worn by BOTH groups gets its image node
repointed by the second bake and the first sheet comes back blank. Build the
same graph twice into two datablocks. It is generated, so they cannot drift.

**4. Hard edges, not ramps — and see "Nothing fades" below, which is the
same rule stated as something a graph can be made to guarantee.** Compare a
value against a threshold (`Math → Less Than`) rather than fading with a
ColorRamp. The bake runs at 2048 and delivers at 1024, so every delivered texel
is the average of four and the downscale is what does the anti-aliasing. A soft
edge in the graph plus a soft edge from the downscale is mush.

**5. Vary the WIDTH, and know where the breaking point actually is.** This is
the trick that makes procedural stripes stop looking procedural: where a width
noise dips below zero the stroke ENDS, and because the threshold is a
distance-from-a-centre the two ends taper rather than being cut square. So one
number turns a set of hoops into a set of brush strokes.

**THE NUMBER HAS A THRESHOLD AND THIS FILE ASSERTED THE WRONG SIDE OF IT.** The
width factor is `1 + (Fac - 0.5) * vary` and Blender's noise `Fac` is bounded to
0..1, so the factor bottoms out at `1 - vary/2`. The tiger's 1.10 bottoms out at
**0.45** and the zebra's first try of 1.30 at **0.35** — neither reaches zero, so
neither ever ends a stroke. Both only THIN it, and a thinned stroke that still
goes all the way round is a hoop.

Zero needs `Fac <= 0.5 - 1/vary`, which is unreachable below `vary = 2` and only
starts happening in the tails a little above it. The zebra runs at 3.0, which
wants `Fac` under 0.17 — often enough to end most strokes, rare enough to leave
some long ones. The tiger reads as broken anyway because its taper and belly
mask drive the width to nothing independently; that is a different mechanism
wearing the same clothes, and it is why the false claim survived.

**And raising the stripe COUNT is not a substitute.** Tried, on the zebra: 10
bands read as hoops, so the count went to 24 on the theory that shorter strokes
would break more easily. What came back was a pinstripe — further from the
reference than the hoops had been. The count was never what made them hoops.

**5b. A MASK ON THE WIDTH CAN SELECT AS WELL AS TAPER, which is how you get a
FEW of something rather than fifty.** The rule above -- a mask on the ink can
only cut, a mask on the width can taper -- has a second half nobody had used.
Multiply two SMOOTH masks into a stroke's width and what survives is sparse:
the Storm Wolf turns a Voronoi cell-net, which is a dense branching web, into
three or four lightning bolts, with free tapered tips wherever a bolt runs out
of mask and no ink mask anywhere in it. `MIN_FRACTION` then stops a bolt before
it thins into a sub-texel smear.

Reach for it whenever a generator gives you the right SHAPE and far too much of
it. Turning the count down instead usually changes the shape too.

**5c. `vary` FLOODS THE TOP OF ITS RANGE AS WELL AS FAILING TO REACH ZERO AT
THE BOTTOM.** The entry above is about a width factor that cannot reach zero
below `vary = 2`. The same number at the other end takes a stroke PAST a full
period -- `to_band` tops out at 1.0, so a stroke wider than its own period
floods, and on the Rainbow Tiger that was a solid red patch on the back of an
ear (width 0.50 x vary 2.20 peaks at 1.05). One `MINIMUM` against the nominal
width separates the two ends and lets `vary` be as large as the breaking wants.

**6. Clear the eyes.** They are code-built parts standing proud of the body at
`(±0.318, -0.889, 0.364)` — a marking running up to their rim reads as a smear.

---

## Nothing fades

**THE THEME IS CARTOON, SO EVERY TEXEL IS ONE OF THE COLOURS THE SKIN
AUTHORED AND NEVER A BLEND OF TWO.** A `Mix` factor of 0.4 does not draw less
of something. It draws a colour nobody chose, four tenths of the way between
two that were chosen — and a region of those reads as an AIRBRUSH, which is the
one thing this art direction cannot carry. It is not subtle when it is wrong;
it is the difference between a toy and a photograph.

**EVERY FACTOR THAT REACHES A COLOUR PASSES THROUGH ONE THRESHOLD, AND THAT IS
THE WHOLE RULE.** Each generator defines

```python
    def hard(sock, x, y, what):
        n = math('GREATER_THAN', x, y, "%s: one colour or the other" % what,
                 b=0.5)
        link(sock, n.inputs[0])
        return n.outputs[0]
```

and **no `Mix` node's factor is wired from anything else.** Every skin declares
`NO_FADING = True` beside its tunables saying so, which is also how the whole
set is audited in one line:

    grep -c "^NO_FADING = True" assets/piggies/*/*/generate/make_*_blend.py rosette.py

**IT IS ENFORCED AT THE OUTPUT RATHER THAN ASKED OF EACH MASK, and that
distinction is the reason it holds.** Half the masks in these files are soft by
nature — a muzzle ring is an angle through a smoothstep, a belly is a tilted
plane through one, a nose pad is a `MapRange` over `y`. Narrowing each of them
by hand is a mitigation: it leaves the failure available to the next mask
anybody adds, and this project has already paid for that twice on the tiger and
once on the zebra. A threshold at the factor makes it STRUCTURALLY impossible —
a soft mask upstream moves an EDGE rather than smearing one, because 0.5 is
where a smoothstep crosses and that is where the edge lands.

**IT COSTS NOTHING THAT WAS WANTED, AND THAT WAS MEASURED RATHER THAN
ASSERTED.** The bee, the ladybird and the zebra were already binary end to end,
so `hard` on their factors is provably a no-op — all six of their sheets came
back **byte-identical** after it was added. What changed is only what was
genuinely fading.

**SOFTNESS ON A WIDTH SURVIVES, AND IT IS A DIFFERENT THING.** A mask
multiplied into a stroke's WIDTH tapers it to a point, in full ink the whole
way; a mask multiplied into the INK can only cut. That is the tiger's eye
treatment and the ladybird's elytra seam, and both are correct. **A mask on the
ink can only cut; a mask on the width can taper.**

### What it was hiding

Every animal here had a soft nose pad — a `MapRange` over `y` about 0.14 studs
wide, wired straight into the mix that lays the pink on — so the snout
dissolved into the cheek instead of being a pad with an edge. The tiger and the
giraffe had the same thing on the belly and the snow leopard on its dorsal
shade. Measured on the baked sheets, off-palette texels that survive a 5x5
erosion (an anti-aliased edge does not; a gradient does):

```
                  in a FADE %
  skin    sheet   before  after
  cow     trim      1.64   0.00
  giraffe body      3.16   0.00
  giraffe trim      2.65   0.00
  leopard body      6.10   0.00
  leopard trim      5.09   0.00
  snowlep body      2.31   0.00
  snowlep trim      1.06   0.00
  tiger   body      7.23   0.00
  tiger   trim      3.58   0.00
  bee / ladybird / zebra    0.00   0.00   (already right)
```

**THE LADYBIRD IS THE ONE THAT WAS ALWAYS RIGHT, and it is worth knowing why:**
every mask in it is a `LESS_THAN` or a `GREATER_THAN` already, and its one
`MapRange` drives the seam's WIDTH rather than a colour. It is the reference for
what a skin in this catalogue is supposed to look like from the inside.

**THE CHECK IS THE BAKED SHEET, NOT THE SCRIPT**, and it is
`look/check_fade.py`:

    python look/check_fade.py            # every skin that has been baked
    python look/check_fade.py tiger      # or just one

`hard` at every factor is the guarantee; this is the proof, and it has to be
able to catch a fade that arrived some other way. It needs no list of what a
skin's colours are — the palette is derived from the map itself as every colour
holding at least 0.4% of the sheet, and anything surviving a 5x5 erosion off
that palette is a fade wherever it came from.

**DERIVING THE PALETTE RATHER THAN WRITING IT OUT IS THE HALF THAT MATTERS.**
The zebra pass measured this with a hand-written list of colours that omitted
the pink inner ear, so the pink counted as one enormous fade and the number came
back nearly ten times too high — reported before it was caught. A check carrying
its own copy of the colour tables is a second thing that can disagree with them.

**PROVOKED RATHER THAN TRUSTED.** Run against the maps as they were before this
pass, the same function flags nine of ten sheets and lets the tenth through —
the cow's body, which never had a fade on it.

---

## The pig's own frame

Measured off the mesh, not assumed. Every part sits at identity, so object
space is world space and **all five parts share one frame** — which is what
lets a marking run off the flank onto a leg with no seam.

```
 x   across         body reaches ±1.000
 y   NOSE to TAIL   snout tip -1.381,  body -1.080..1.052,  tail tip 1.465
 z   floor to CROWN legs -1.020,       body -0.960..0.960,  ear tip 1.309
```

So **-Y is the face and +Z is up**. Other landmarks worth having: eyes at
`(±0.318, -0.889, 0.364)`, the ears span `z 0.447..1.309`, the legs
`z -1.020..-0.520`, the tail `y 0.731..1.465`.

---

## `math` IS SHADOWED INSIDE EVERY `coat()`

Every generator defines a local `math()` helper for building Math nodes, which
means **Python's `math` module is unavailable for that entire function body** --
`math.cos` reads as `'function' object has no attribute 'cos'`, at run time,
naming a line that looks fine.

Precompute anything trigonometric at MODULE scope and refer to the constant.
The tiger already does this (`HEAD_COS_LO`, `HEAD_COS_HI`, `HEAD_POLE`) and it
reads as an optimisation rather than as the workaround it is. Two skins have
rediscovered it since; it is written here so a third does not.

Same family as the `step` shadowing in `Crack.luau`, and as every `Connect(name)`
that resolves to the nearest binding rather than the intended one.

---

## The two rules that have already cost real work

**`materials.clear()` ALSO RESETS EVERY POLYGON'S SLOT INDEX.** It does not
only empty the slot list. The ear's 313 faces, picked out by hand in edit mode
to be the rim, came back with all 3,326 on slot 0 and the second material
seated on nothing — silently, in two scripts at once. On the bee the rims went
black to yellow; on the tiger the inner ear went pink to whatever the coat was
doing there, which is a plausible-looking dark ear and got read as "the pink
zone is small" rather than "the pink zone is gone".

Seat materials through **`skin_parts.assign`**, which assigns into slots
(`materials[i] = m`) and never clears. It prints the faces-per-slot count on
every rebuild, so a lost selection says so instead of looking fine.

**A FACE SELECTION IS THE ONE THING NO SCRIPT CAN REGENERATE.** The graphs are
generated, the bake is derived, the blend is disposable, the textures are
output. A selection somebody made by eye is none of those, and it does not look
like data: it is an integer on every polygon, invisible in the outliner and
absent from every diff. Same class as the hand-painted masks under `skins/`,
which `.gitignore` goes out of its way to keep.

**`make/make_parts_blend.py` REBUILDS THE MASTER AND THROWS AWAY HAND WORK** —
materials, slots, selections. It backs up to `pig_parts.before-rebuild.blend`
first and it says so. Only run it when the GEOMETRY has changed, and re-run
every `make_<skin>_blend.py` afterwards.

---

## Verifying a rebuild

The check that means something is **baking it and diffing the maps**, not
reading the script. `assets/piggies/common/bee/source/bee.blend` was written as a transcription of a
hand-built graph and its body map matched byte for byte while its trim map did
not — 23,174 texels different, every one ink in the original and yellow in the
rebuild. That is what exposed the `clear()` bug, and no amount of reading the
node dump would have: the node dumps were identical.

    md5sum assets/piggies/<tier>/<skin>/sheets/*.png

before and after. If a skin script claims to reproduce something, prove it.

---

## Getting it into the game

The mesh is uploaded **once, not per skin**. `Config.PIGGY_MESH` is global —
one Body id and one Trim id for the whole catalogue — so `export_meshes.py` and
its two `.obj` uploads happened for the re-unwrap and do not happen again.
Every skin after that is **two texture uploads and some Config**:

1. Upload `assets/piggies/<tier>/<skin>/sheets/<skin>_body_color.png` and
   `<skin>_trim_color.png`. Then record the ids in the skin's `manifest.json`
   beside the sha256 of the sheet each became.
2. A `.model.json` each in `src/ReplicatedStorage/Shared/SurfacePacks/`, with
   `AlphaMode: "Overlay"` and the ColorMap id. Leave NormalMap empty unless the
   skin actually wants one.
3. One row in `Config.SURFACE_PACKS` naming both templates.
4. `surface = "<pack>"` on the skin, and delete its `pattern` block.

**Every upload publishes under your own account and is moderated.** Get it
right in the preview, then upload once. See the moderation entry in
`CLAUDE.md` — the blast radius there is the account, not the experience.

### What a full-colour sheet costs

`Config.SKINS.<skin>.body` and `.trim` **stop doing anything**: at alpha 255,
`Overlay` computes `lerp(partColour, mapRGB, 1)`, which is `mapRGB`. So a
colour tweak becomes a re-bake and a re-upload rather than a line of Luau. What
it buys is that what you see is exactly what ships, with no mask, no marking
colour and no lerp to reason about — and more than two colours, which
`Overlay` cannot express at all.

The alternative is still there and still right for some skins: a **mask** in
`skins/animal/` carries a shape in alpha and ONE constant RGB, so one `spots`
sheet dresses a leopard, a cheetah and a snow leopard and a new colourway is a
line of Config with no upload. Pick per skin; `skins/README.md` has the folder
rules.

---

## What every file in here is for

Audited file by file. Nothing below is unreferenced; if something looks like a
candidate for deletion, the reason it survived is in this table.

### The current method

| file | |
|---|---|
| `paths.py` | **the layout.** Every path in every script comes from here |
| `png_write.py` | a PNG writer with no dependencies. Extracted out of `make_animal_maps.py`, which three scripts were importing a 42 KB generator to borrow one function from -- and which used to run its own `main()` on import, so borrowing it regenerated nine maps and looked like a fifteen-minute hang |
| `pig_uv.py`, `skin_colours.py`, `skin_parts.py` | the rest of the toolkit |
| `make/build_pig.py` | generates the animal -> `pig.blend`. The source of the geometry. |
| `make/make_parts_blend.py` | `pig.blend` -> `pig_parts.blend`, the master. **Destroys hand work**, backs up first. |
| `make/reunwrap.py` | Smart UV Project, called by the above |
| `make/select_inner_ear.py` | **regenerates the ear face selection.** Run inside Blender after a master rebuild, or the inner ear is gone |
| `skin_parts.py` (toolkit) | seats materials without wiping face selections |
| `skin_colours.py` (toolkit) | reads a skin's colours out of `Config.luau` so they cannot drift |
| `assets/piggies/<tier>/<skin>/generate/make_<skin>_blend.py` | the skins themselves (moved out of `skins/` on 2026-09-22; `paths.py` knows) |
| `make/bake_skin.py` | bake -> the two sheets |
| `make/make_view_blend.py` | game-lit preview |
| `look/check_fade.py` | **does any sheet fade?** The check behind "Nothing fades". Derives a skin's palette from its OWN maps, so it keeps no second copy of the colour tables -- pooled across the body and trim sheets, because a colour common on one and rare on the other otherwise misses the floor on the rare one and its own solid texels get reported as a fade |
| `rosette.py` (toolkit) | the shared spotted-cat graph. `leopard` and `snowleopard` are each a dict of numbers handed to this, which is why they are 300 lines and the others are 600 |
| `make/export_meshes.py` | `pig_body.obj` / `pig_trim.obj`. Run once, for a re-unwrap |
| `make/make_fur_tufts.py` | the fur sets -> `pig_tufts.blend`, `pig_crest.blend` and their .obj |

### Uploaded, or waiting to be

`pig_body.obj` and `pig_trim.obj` are `Config.PIGGY_MESH`. `pig_fur_tufts.obj`
is `FUR_SETS.mane`, live. **`pig_fur_crest.obj` has never been uploaded** --
`FUR_SETS.crest.id` is still `""` and its comment says the import is pending.

### The old cylindrical-unwrap toolchain

These all assume `pig_uv.py`'s pinned cylinder, which the Smart UV re-unwrap
retired. They are kept because they are the ONLY tooling for the three skins
that still wear a mask pack -- and those three are exactly the three that need
re-authoring, so this whole group lives or dies with that job.

| file | |
|---|---|
| `pig_uv.py` | the pinned cylinder range. Imported by five scripts |
| `make_animal_maps.py` | writes the mask sheets. Also the PNG writer `bake_skin.py` imports |
| `make_paint_template.py` | the paint guide, and the linter `skins/README.md` points at |
| `make_paint_blend.py` | sets up brush painting |
| `make_band_overlay.py` | the metal band overlay -- `bullion`'s ColorMap |
| `bake_pattern.py` | bakes a world-defined pattern onto the UV sheet. Superseded by the tiger's method, kept for the two measured bugs in its header |
| `pig_snout.obj`, `pig_ears.obj`, `pig_legs.obj`, `pig_tail.obj` | **inputs to `make_paint_template.py`**, which is the only reason they are here. Every `Config.PIGGY_TRIM_PARTS` id is empty, so none of them is uploaded, and all four carry the old unwrap |

### Recorded dead ends, kept on purpose

Each of these says in its own header why it did not work. They are kept so
nobody spends the afternoon again -- the same argument `CLAUDE.md` makes for
keeping a rejected idea written down rather than deleted.

* `make_metal_pack.py` -- the pack measured WORSE than stock `Material.Metal`
* `make_quick_fur.py` -- Blender hair is curves; there is no mesh to export
* `make_animal_shapes.py` -- modelled markings against painted ones

### Looking at the geometry

`verify_pig.py` (are the openings actually open -- walks a ray, because a blind
dent reads as a hole to a bounding box), `check_vault.py` (what is across the
hatch), `render_pig.py` and `turntable.py` (shape previews), `preview_pack.py`
(every animal in the pack in its real Config colours -- the only previewer that
covers the MASK packs, which `make_view_blend.py` does not).

### Cleaned out

Removed as regenerable output or settled one-offs: `*.blend1` (Blender's
rolling backups, which `.gitignore` calls "never wanted"), `__pycache__/`,
`pig_view.blend` and `pig_paint.blend` (rewritten on every run of the script
that makes them), the three `paint_*.png` guide layers, `preview_animal.py` and
`preview_parts.py` (one-off comparisons whose questions are settled and whose
subjects are now covered by `make_view_blend.py`), and 28 superseded previews
from `renders/`. 13 MB.

Then everything was filed: the pig's scenes and mesh exports into `pig/`,
each skin's scene and script into its own folder under `skins/`, and the tools
into `make/`, `masks/`, `look/` and `retired/`. The five toolkit modules stayed
at the root because that is what the bootstrap looks for. On 2026-09-22 the
skins moved again, out of this tree into `assets/piggies/<tier>/<key>/` -- the
designer's source of truth -- and `paths.py` was the one-file diff that claim
promised.

**`renders/` holds only what is current**: the bee and the tiger under game
light, plus the tiger contact sheet. Everything in there is one command away
from being remade, which is why `.gitignore` refuses the whole folder.

---

## Where things stand

Eight skins, all baked from 3D against the current unwrap, **none of them
uploaded** and no `Config.luau` row written for any of them. Every one declares
`NO_FADING = True` and every one measures 0.00% in a fade.

| skin | script | state |
|---|---|---|
| `bee` | `assets/piggies/common/bee/generate/make_bee_blend.py` | shipped. A transcription of the hand-built graph, **verified byte-identical** to the shipped maps. Two flat colours, so there is no mask in it for anything to be enforced on. |
| `ladybird` | `assets/piggies/common/ladybird/generate/make_ladybird_blend.py` | baked. **The one that was always right** — every mask in it is a threshold already and its one `MapRange` drives a WIDTH. The reference for what a skin should look like from the inside. |
| `zebra` | `assets/piggies/common/zebra/generate/make_zebra_blend.py` | baked and approved. Bands about a pole through the MUZZLE; the eye is a domain warp, so bands bend round it and close up behind rather than ending at it. |
| `tiger` | `assets/piggies/common/tiger/generate/make_tiger_blend.py` | baked and approved. Rings on the body, a radial fan on the face, and the eye narrows a stroke to a point rather than cutting it. Config still says `surface = "animal_stripes"`. |
| `cow` | `assets/piggies/common/cow/generate/make_cow_blend.py` | baked. Two colours, and no eye clearance at all — the dial that replaces one is `seed`. |
| `giraffe` | `assets/piggies/common/giraffe/generate/make_giraffe_blend.py` | baked. |
| `leopard` | `assets/piggies/common/leopard/generate/make_leopard_blend.py` | baked, **re-cut from 3D**. The line that used to stand here saying it was against the old cylindrical unwrap is out of date. |
| `snowleopard` | `assets/piggies/common/snowleopard/generate/make_snowleopard_blend.py` | baked. The only skin with a dorsal shade — one more ground colour under the markings, and hard-edged like everything else. |

`leopard` and `snowleopard` are both `rosette.py` with a different dict, which
is why one edit in that file fixed two skins here.

Still to do: `bullion` is the metal band overlay, which is constant-along-u by
design and cannot survive arbitrary islands — it needs re-authoring as a bake.

Known and unfixed on the tiger: no forehead rosette (it has transverse bands
instead), and from directly behind the rings close into concentric circles
round the tail.
