# -*- coding: utf-8 -*-
"""Build the Rainbow Tiger's coat as a node graph, in its own blend file.

    blender.exe --background --python assets/piggies/rainbowtiger/generate/make_rainbowtiger_blend.py
    blender.exe --background --python make/bake_skin.py       -- --skin rainbowtiger
    blender.exe --background --python make/make_view_blend.py -- --skin rainbowtiger --render

A COPY OF `make_tiger_blend.py` WITH ONE THING CHANGED: THE INK IS NOT ONE
COLOUR. Everything about where a stroke goes -- the ring field, the slant, the
wobble, the width noise, the taper, the belly mask, the eye narrowing, the
muzzle cut, the head fan -- is the tiger's and is deliberately untouched. What
this file adds is a HUE PER STRIPE, so the strokes run the spectrum down the
flank while the coat holds still.

`docs/animal-crate-plan.md` calls this the BAKED half of Rainbow Tiger and
schedules it first. The other half -- an alpha pass so that some texels hand
themselves back to the part's own animated `Color3` -- is a SEPARATE script
(`make/bake_alpha.py`) driven by a node labelled `ALPHA_MASK`, and there is
deliberately no such node in this file. A material without one bakes fully
opaque, so this skin is finished as it stands and the animated version is an
addition to it rather than a rewrite of it.

------------------------------------------------------------------ the trick

The stripe field is a PHASE. `to_band` takes `fract(phase)` and inks the texels
near 0.5, so stripe number k occupies phase `k + 0.5 +- width/2` -- which means
**`floor(phase)` is constant across a whole stroke and changes by exactly one
between neighbours.** That integer IS the stripe index, it costs one node, and
it was sitting in the tiger's graph the whole time.

The index picks a stop out of a ColorRamp on `CONSTANT` interpolation, which is
a LOOKUP rather than a mix: its output is one of the authored colours or
nothing at all, so it cannot produce a hue nobody chose. See `NO_FADING` below.

--------------------------------------------------------------- the two seams

**THE BODY DOES NOT WRAP AND THEREFORE HAS NO SEAM.** Its phase is
`y*freq + z*slant`, a plane rather than an angle, so the index just counts up
from the snout to the tail and there is no place where it jumps.

What it has instead is a RESTART: there are about eleven stripe indices across
the body and eight hues, so the wheel closes about one and a half times and a
magenta stroke stands next to a red one where it does.

**AN EARLIER DRAFT OF THIS PARAGRAPH CLAIMED THAT ONLY A WHOLE NUMBER OF
CLOSURES READS AS DELIBERATE, AND THAT WAS A RATIONALISATION.** It was written
while the count was six, where the wheel happens to close about twice, and it
predicted that one-and-a-half would read as the spectrum running out. Looked
at, across counts 6, 8, 10, 12 and 14 at four cameras, it does not: the restart
is a couple of strokes on a curved flank and the eye never sees the whole ring
at once, so how many times the wheel closes turns out not to be a thing anybody
can perceive. What DOES decide the count is which arc each camera sees -- see
`RAINBOW['count']`.

**THE HEAD FAN DOES WRAP, AND THE SEAM IS PARKED ON THE UNDERJAW.** Its phase
is `arctan2(sideways, up) * count/(2*pi)`, so crossing `phi = +-pi` jumps the
index by exactly `HEAD['count']` -- which is invisible only when the number of
hues DIVIDES that count. It does NOT today: twenty meridians against eight hues
jumps four steps, so there is a real seam where the wheel closes.

**IT WAS PARKED RATHER THAN REMOVED, AND THE ALTERNATIVE IS WRITTEN DOWN
BECAUSE IT IS ONE EDIT AWAY.** `phi = +-pi` is the direction straight DOWN from
the muzzle pole -- the underjaw, on a pig that stands on four legs on a lawn --
so it is the one surface no camera in this game ever reaches. Taking
`HEAD['count']` to 16 would divide by eight and remove it outright, at the cost
of four strokes off a face fan the tiger measured at twenty; that trade was not
worth making for a seam nobody can see, and it is here so the next person can
make it in one line if they ever want the fan on something that IS looked at
from below. **Note it has to be re-derived whenever `RAINBOW['count']` moves**,
which is why the build prints the jump rather than a pass/fail.

Neither half of that was assumed. The divisibility is printed at the end of
every build, in hue steps, and says VISIBLE when it is. The LOCATION was
measured rather than reasoned about: walking every vertex of every part inside
the fan's own region and taking the one nearest `phi = +-pi` lands on
**(0.000, -0.764, -0.679)** -- x dead centre, forward of the shoulder and well
below the middle of the animal, which is the throat under the jaw.

That check is also what would catch the seam MOVING. `HEAD_E1` is where "up"
is as far as the fan is concerned, so anything that touches `pole_down` swings
the seam round the head, and it would swing silently.

------------------------------------------------------- what was tried and lost

**A RAINBOW COAT WITH DARK STRIPES.** That is the other product and it belongs
to the animated version: `animal-crate-plan.md` reserves the alpha-hole trick
for it, and a BAKED rainbow coat would spend the idea for a static picture. It
also loses the read -- a coat is a big smooth surface, so a spectrum across it
is an airbrush by another name, and the whole catalogue is flat colour.

**THE FACE FAN HOLDING ONE HUE.** Built first, and it is the loser by a
distance. See `HEAD_HUE`, which has the picture it produced.

**HUES EVENLY SPACED ROUND THE WHEEL AT ONE VALUE.** Tried, and yellow through
cyan came back visibly brighter than red and blue at the same `val` -- the
finding `CLAUDE.md` already records for the UI palette, arriving on a coat. The
fix is the same one: drop the value in the bright band rather than equalise
luminance outright, which turns gold into olive. See `RAINBOW['dip']`, where
the first attempt at that dip is also recorded, because it was centred by
guesswork and took the orange out of the rainbow.

**SIX HUES, WHICH SHIPPED FOR ABOUT AN HOUR FOR A REASON THAT TURNED OUT NOT
TO BE ABOUT THE PICTURE AT ALL.** Everything above six failed
`look/check_fade.py`, and the fault was in the CHECK -- see `RAINBOW['count']`,
which keeps the whole episode because it is the one finding here that is about
the pipeline rather than about this animal.

**FOURTEEN, AND TWELVE.** Both pass now and both are worse, and the reason is
not the one anybody would guess. See `RAINBOW['count']`.

THE COORDINATE FRAME IS THE PIG'S OWN, measured off the mesh:

    x   across          body reaches +-1.000
    y   NOSE to TAIL    snout tip -1.381, body -1.080..1.052, tail tip 1.465
    z   floor to CROWN  legs -1.020, body -0.960..0.960, ear tip 1.309
"""

# --- find the toolkit, wherever this script has been filed ------------------
# Walks up from this file until it finds either `paths.py` or the repo root
# that holds `blender/pig/paths.py`, and puts `blender/pig/` on the path. Depth
# independent on purpose: this generator lives in `assets/piggies/<key>/
# generate/`, three levels under the repo, and the toolkit in `blender/pig/`,
# two levels under it -- a hardcoded `..` is a thing that breaks silently the
# first time anything is refiled (it did, on 2026-09-22, which is why the walk
# accepts both).
import os as _os, sys as _sys
_root = _os.path.dirname(_os.path.abspath(__file__))
while not (_os.path.exists(_os.path.join(_root, "paths.py"))
           or _os.path.exists(_os.path.join(_root, "blender", "pig", "paths.py"))):
    _up = _os.path.dirname(_root)
    if _up == _root:
        raise RuntimeError("cannot find blender/pig/paths.py above %s" % __file__)
    _root = _up
if not _os.path.exists(_os.path.join(_root, "paths.py")):
    _root = _os.path.join(_root, "blender", "pig")
if _root not in _sys.path:
    _sys.path.insert(0, _root)
# ---------------------------------------------------------------------------
D = _root

import paths   # noqa: E402 -- the one place that knows the layout
import bpy, os, sys, math, colorsys

from skin_colours import to_linear   # noqa: E402
from skin_parts import assign, face_slots   # noqa: E402


argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SRC = arg("--blend", paths.PARTS)
OUT = arg("--out", paths.skin_blend("rainbowtiger"))

# --------------------------------------------------------------- the colours
# NOT READ OUT OF `Config.luau`, AND THAT IS A STATEMENT ABOUT THE SKIN RATHER
# THAN A SHORTCUT. `skin_colours.skin()` exists so a preview cannot show a
# colour the game does not ship, and it works because `Config.SKINS.<key>` has
# exactly a `body` and a `trim`. This skin has a coat, an underside, a snout, an
# inner ear and a whole spectrum, which is precisely what a full-colour bake
# buys and precisely what it costs: every one of these is a re-bake rather than
# a line of Luau. There is no `rainbowtiger` row in Config and there must not be
# a second copy of these numbers when there is one.
#
# THE COAT IS PALE AND THE STRIPES ARE SATURATED, WHICH IS THE WHOLE READ.
# A tiger's orange against a warm dark brown is two mid-tones and it works
# because the SHAPES carry it. A spectrum cannot do that: eight hues on an
# orange ground fight the ground and each other, and the two that happen to sit
# near orange disappear. On cream every hue is the loudest thing in its own
# neighbourhood, which is what makes this read as "the rainbow one" from twelve
# studs rather than as "a tiger with odd stripes".
COAT = (243 / 255., 234 / 255., 216 / 255.)     # the flank: warm cream
BELLY = (255 / 255., 253 / 255., 248 / 255.)    # the underside: near-white
# THE SNOUT IS PINK, WHICH IS THE ONE PLACE THIS ANIMAL REMEMBERS IT IS A PIG.
# The tiger paints its snout disc back to ORANGE because the belly tilt would
# otherwise have made it cream and a tiger's nose is the brightest orange on
# it. Here the coat IS cream, so putting cream back on cream is a mask that
# does nothing -- the disc had to become a colour or the node had to come out.
# A pink snout against a cream face is the reading the mesh already has.
SNOUT = (244 / 255., 178 / 255., 172 / 255.)
# The inner ear, the one place a real cat shows skin rather than fur. A shade
# off the snout on purpose: two pinks that are the SAME pink read as a mistake
# in a way that two that are plainly different do not.
EAR_PINK = (247 / 255., 201 / 255., 180 / 255.)

# ------------------------------------------------------------- the tunables
# EVERY NUMBER THAT DECIDES WHAT THE COAT LOOKS LIKE IS IN THESE DICTS.
NO_FADING = True
# NOTHING ON THIS ANIMAL FADES INTO ANYTHING ELSE -- `WORKFLOW.md`, "Nothing
# fades". Every factor reaching a colour mix goes through `hard`, so a soft mask
# anywhere upstream moves an EDGE rather than smearing one.
#
# **AND THE RAINBOW IS A LOOKUP, NOT A MIX, WHICH IS WHY IT CLEARS THE RULE
# WITHOUT NEEDING `hard`.** The obvious way to build a spectrum is a ColorRamp
# on `LINEAR`, and that is an airbrush with extra steps: it would put a colour
# nobody authored between every pair of stops, which is the one thing this art
# direction cannot carry. `CONSTANT` makes the ramp a table of `count` authored
# colours and nothing between them, and the index it is looked up by is an
# INTEGER, so there is no interpolation anywhere in the path. The proof is
# `python look/check_fade.py rainbowtiger`, which reads the baked sheet and
# knows nothing about any of this.

RAINBOW = dict(
    # HOW MANY HUES BEFORE THE SPECTRUM RESTARTS, and this is the dial the
    # whole skin turns on.
    #
    # **IT WAS SIX FOR AN HOUR, FOR A REASON THAT TURNED OUT NOT TO BE ABOUT THE
    # PICTURE AT ALL, AND THAT EPISODE IS THE MOST USEFUL THING IN THIS FILE.**
    # `look/check_fade.py` derives a sheet's palette as every colour holding at
    # least `FLOOR` of it -- which is what lets the check keep no copy of the
    # colour tables, and it was 0.4%, a number chosen when an animal had three
    # colours on it. A rainbow divides one ink budget by `count`: the body sheet
    # is 20% ink and the trim 13%, spread very unevenly, because a hue lands
    # wherever its stripe band happens to cross the geometry. A hue falling on
    # nothing but a sliver of one ear held 0.225%, was therefore not recognised
    # as authored, and its whole region counted OFF-PALETTE, survived the 5x5
    # erosion and was reported as a FADE -- on a skin in which nothing anywhere
    # is interpolated. Measured then, in-a-fade % on body / trim:
    #
    #     count      5     6     7     8     9    10    11    12
    #     body    0.00  0.00  0.00  0.00  0.00  0.25  0.19  1.21
    #     trim    0.00  0.00  0.16  0.13  0.26  0.00  0.28  0.37
    #
    # `STRIPES['phase']` was invented to chase it and does not work; that note
    # has the sweep. The conclusion drawn at the time -- "the number of hues a
    # skin may carry is bounded by its smallest part" -- was WRONG, and wrong in
    # the most expensive direction: it read a MEASURING fault as a fact about
    # the art, and shipped a worse skin to satisfy it.
    #
    # `FLOOR` is 0.001 now, calibrated against known positives (the nine sheets
    # that genuinely faded before the "Nothing fades" pass) and known negatives
    # (every sheet since). It is the loosest value still catching 9 of 9, and
    # every count in the table passes at it. **A DETECTOR'S THRESHOLD IS A
    # MEASUREMENT AND NOT A CONSTANT, AND A SKIN BENDING ITSELF ROUND ONE IS THE
    # TAIL WAGGING THE DOG.**
    #
    # **SO EIGHT IS CHOSEN ON THE PICTURE, AND WHAT DECIDES IT IS NOT SMOOTHNESS
    # -- IT IS HOW MUCH OF THE WHEEL ONE CAMERA CAN SEE.** Re-swept at 6, 8, 10,
    # 12 and 14, photographed at all four cameras and compared side by side. A
    # higher count is a smaller step, so the flank gets smoother -- and every
    # VIEW then shows a narrower ARC of the wheel, because a camera only ever
    # sees part of a barrel:
    #
    #     14   the rump is red / orange / gold / lime and nothing else, and the
    #          face fan is warm the whole way round. A gradient, not a rainbow.
    #     12   the same failure, one notch gentler.
    #     10   the smoothest FLANK of the five -- and the rump has lost its cold
    #          end. This is the one that wins a hero shot.
    #      8   the rump runs red to teal, the face fan carries the whole wheel,
    #          and the flank is still smooth.                        <- ships
    #      6   the widest arc per view and the chunkiest steps: neighbours 60
    #          degrees apart read as unrelated colours rather than as an order.
    #
    # **THE HERO SHOT PICKS THE WRONG ONE, WHICH IS THE WHOLE ARGUMENT FOR
    # `WORKFLOW.md`'s RULE ABOUT THE CROWN AND THE SPINE.** Ten wins a
    # three-quarter view and loses both of the views that file says to judge on,
    # and only a side-by-side at those two cameras shows it.
    count=8,
    # WHERE THE SPECTRUM STARTS, in degrees, at the stripe nearest the nose.
    #
    # **WHAT IT IS REALLY DOING IS DODGING PURE YELLOW, AND WHICH VALUE DODGES
    # IT DEPENDS ENTIRELY ON `count`.** Yellow near 60 degrees is the one hue
    # that cannot work here: bright, it is invisible against a cream coat;
    # dipped far enough to be visible it is #CACA1C, an olive-mustard, which
    # shipped for one render and read as a dirty stripe rather than as a colour.
    # No value of `val` fixes that, because the fault is the HUE -- a gold is
    # about 45 degrees and a slot landing on 60 cannot reach it.
    #
    # At SIX hues the slots are 60 apart, so 0 lands one squarely on yellow and
    # this ran at 345 to slide off it. **AT EIGHT THEY ARE 45 APART AND 0 IS THE
    # BEST VALUE RATHER THAN THE WORST**: the slots fall on 0 / 45 / 90 / 135 /
    # 180 / 225 / 270 / 315, which is a true red AND a real gold at 45, with
    # nothing within thirty degrees of yellow. Photographed against 345 at all
    # four cameras -- that gives a crimson and an orange and no gold at all, and
    # the rump reads cooler for it.
    #
    # **SO THIS IS NOT AN INDEPENDENT DIAL: re-derive it whenever `count`
    # moves**, by asking where the slots land relative to 60.
    hue0=0.0,
    # HOW MANY HUE STEPS EACH STRIPE ADVANCES. 1 is the spectrum in order,
    # which is the brief. Anything else draws the wheel out of order -- tried at
    # 2, and it reads as a fault rather than as a design, because neighbouring
    # strokes then differ by more than the eye reads as "the next one". Note it
    # cannot help the coverage problem under `count` either: a `step` coprime to
    # `count` only PERMUTES which hue sits on which stripe index, so the same
    # starved index starves a different colour.
    step=1,
    # SATURATION AND VALUE, before the dip below. Full saturation is not
    # wanted: at 1.0 the blues and violets go inky and stop reading as blue at
    # twelve studs, which is the same failure a Neon skin has from the other
    # end. 0.86 keeps every hue a hue and still shouts against cream.
    sat=0.86, val=0.94,
    # THE BRIGHT-BAND DIP. Yellow through cyan read considerably brighter than
    # red and blue at the same value -- `CLAUDE.md`'s Theme entry measures the
    # identical thing on the UI palette and takes the green band from 0.90 to
    # 0.82. Full luminance equalisation was rejected there and is rejected here
    # for the same reason: it lands every hue at one luminance, which turns gold
    # into olive and takes the spectrum with it.
    #
    # **AND IT MATTERS MORE ON A PALE COAT THAN ON A DARK ONE, WHICH IS WHY IT
    # IS TWICE THE UI'S.** Against ink, a bright hue is the one that reads and a
    # dark one struggles. Against cream it is the other way round: yellow at
    # full value has almost no contrast with the ground it is drawn on, so
    # dimming the bright band is not only evening the family out, it is the only
    # thing making half the wheel visible at all.
    #
    # A GAUSSIAN RATHER THAN A BAND, because a band has two edges and each one
    # is a place where two neighbouring stripes step in brightness for no
    # reason a player can see.
    #
    # `dip_at` IS WHERE THE WHEEL IS BRIGHTEST AND IT WAS MEASURED, NOT
    # EYEBALLED. Rec.709 luminance of these hues at `sat`/`val`: red 0.30,
    # yellow 0.88, green 0.71, cyan 0.77, blue 0.19, magenta 0.36. So the bright
    # band runs yellow through cyan and its middle is about 130 degrees. The
    # first build centred it on 80 by guesswork and took the ORANGE down with
    # it -- hue 36 came back #C07E1B, which is a brown, and a rainbow missing
    # its orange is the one hue a nine-year-old would name.
    dip=0.34, dip_at=130.0, dip_wide=80.0,
)

STRIPES = dict(
    # HOW MANY. `freq` is stripe periods per stud along the nose-tail axis, and
    # the body spans 2.13 studs of that. The tiger's number, unchanged: it is
    # what leaves enough coat between strokes for the strokes to be strokes.
    #
    # It also sets how many STRIPE INDICES exist -- about eleven across the
    # body, plus the legs and the tail -- so against `RAINBOW['count']` of
    # eight the spectrum runs round about one and a half times from snout to
    # tail. That is the RESTART the header describes, and the header also
    # records that an earlier draft here claimed a whole number of closures was
    # needed and that looking at five counts disproved it.
    freq=3.7,
    # THE LEAN. A stripe is the plane `y*freq + z*slant = k`, so raising this
    # tips the rings: at 1.2 a stripe's top edge sits about a fifth of a period
    # nearer the nose than its bottom edge, which is the backward sweep a real
    # flank has. At 0 they are dead vertical bands and read as a barrel.
    slant=1.2,
    # WHERE THE FIRST STRIPE SITS, in periods. On the tiger this dial does not
    # exist because it would do nothing anybody could see: sliding a set of
    # identical brown strokes a third of a period along the animal is the same
    # picture. **HERE IT MOVES WHICH GEOMETRY WEARS WHICH HUE**, because the
    # hue is `floor` of this same phase -- so it slides the whole spectrum
    # forward and back along the pig, and it decides which hue lands on the
    # ears, which on the legs and which on the tail.
    #
    # It was added to chase the coverage problem under `RAINBOW['count']` --
    # the theory being that a hue starved of surface could be slid onto some --
    # and swept at 0.00 / 0.15 / 0.30 / 0.45 / 0.60 / 0.75 / 0.90 against a
    # `count` of 8. **NOT ONE OFFSET HELPED**: the trim failed at every one,
    # 0.13 at the best and 0.38 at the worst. Sliding the spectrum moves WHICH
    # hue starves and never whether one does, because what starves is a stripe
    # INDEX and the geometry decides that.
    #
    # That sweep is worth keeping even though the problem it was chasing turned
    # out to be a threshold in the checker rather than anything real: the
    # finding it produced -- **a phase offset relabels the histogram and never
    # changes its shape** -- is true regardless of why anybody was looking.
    #
    # Kept at 0.0 rather than deleted because it is a genuine look dial on the
    # tiger's field that the tiger had no use for, and because the next person
    # to think of it should find the measurement rather than repeat it.
    phase=0.0,
    # HOW WIDE THE INK IS, as a fraction of one period, at the SPINE.
    #
    # **BOLDER THAN THE TIGER'S 0.40, AND THAT IS THE ONE PLACE THE COLOUR
    # CHANGES THE SHAPE.** A brown stroke on orange is read as a stroke; a
    # saturated hue on cream is read as a COLOUR, and a colour needs area
    # before the eye will name it. This is what a per-stripe hue costs, and it
    # is only affordable at all because `MAX_FRACTION` stops the top of the
    # range running away with it -- at 0.50 with no ceiling the widest strokes
    # reached 1.05 of a period, which is more ink than a period contains.
    width=0.48,
    # THE WIDEST A STROKE MAY EVER GET, and this tunable is NOT the tiger's --
    # it is the thing that unsticks the trade `WORKFLOW.md` records as stuck.
    #
    # That entry says the width factor is `1 + (Fac - 0.5)*vary`, so a `vary`
    # big enough to END a stroke is also big enough to DOUBLE one -- and
    # `to_band` tops out at 1.0, so a stroke wider than half a period floods
    # its whole neighbourhood with ink. On a tiger that is a slightly fat
    # stripe. Here it was a SOLID RED PATCH ON THE BACK OF AN EAR, photographed
    # from the spine camera, reading exactly like a stain: `width` 0.50 with
    # `vary` 2.20 peaks at 0.50 * 2.10 = 1.05, which is more than a whole
    # period of ink.
    #
    # **THE TWO ENDS OF THAT RANGE WANT DIFFERENT THINGS AND ONE NUMBER CANNOT
    # SERVE BOTH.** Turning `vary` down to stop the flooding takes the stroke
    # breaking with it -- measured, at 1.10 nothing ever ends and the rear is
    # unbroken hoops. A ceiling costs one `MINIMUM` node and separates them:
    # `vary` is now free to be as large as the BREAKING wants, because the top
    # of its range is clipped rather than drawn.
    #
    # The ceiling itself is `MAX_FRACTION`, beside `MIN_FRACTION`, because the
    # head fan needs exactly the same clip in its own units.
    #
    # THE TAPER, which is what makes a stripe a BRUSH STROKE rather than a hoop.
    # A tiger's stripe is widest where it leaves the spine and comes to a point
    # down the flank; a constant-width ring is a barrel band.
    taper=0.65, taper_hi=0.42, taper_lo=-0.40,
    # THE WOBBLE, which is the entire difference between a tiger and a deck
    # chair. A low-frequency noise added to the stripe phase BEFORE it is
    # wrapped, so a stripe BENDS rather than getting a fuzzy edge.
    #
    # **IT ALSO BENDS THE HUE BOUNDARY, FOR FREE, AND THAT IS WORTH KNOWING
    # BEFORE ANYBODY TURNS IT DOWN.** The hue comes off `floor` of the same
    # phase the stripe does, so a stroke that wanders keeps whatever hue it
    # started with the whole way -- there is no second field to get out of step
    # with the first, and no stroke is ever two colours.
    wobble=0.50, wobble_scale=1.7, wobble_detail=2.0,
    # THE SPLIT. A second, faster noise on the WIDTH, so consecutive stripes
    # are not the same thickness and some pinch SHUT -- where the width noise
    # takes the stroke under `MIN_FRACTION` it is cut in half, so one stroke
    # becomes two short ones with a gap.
    #
    # **PAST THE TIGER'S 1.10 ON PURPOSE, AND ONLY SAFE BECAUSE OF
    # `width_max`.** `WORKFLOW.md` measures that 1.10 bottoms out at 0.45 of
    # nominal and therefore never ends anything -- the tiger gets away with it
    # because its taper and its belly mask drive the width to nothing
    # independently, and neither of those does much on the rump, which is why
    # the rear was unbroken hoops. 2.60 wants `Fac` under 0.28 to cut a stroke,
    # which happens often enough to break most rings and rarely enough to leave
    # some long ones.
    #
    # `vary_scale` came DOWN from the tiger's 5.0 in the same pass. At 5.0 the
    # variation is finer than a stroke is long, so a high `vary` nibbles the
    # same stroke four times and the coat reads as BLOTCHY rather than as
    # broken -- photographed at 4.20/5.0 and it looked like mould. At 3.4 a
    # stroke thins over a run and then stops, which is a brush leaving the
    # surface.
    vary=2.60, vary_scale=3.4,
    # A fine break-up on the phase, at the scale of the stripe edge itself.
    grain=0.10, grain_scale=9.0,
)

BELLY_MASK = dict(
    # WHERE THE PALE UNDERSIDE STARTS AND STOPS, in z.
    #
    # **IT DOES TWO JOBS HERE AND ONLY ONE OF THEM IS THE COLOUR.** On the
    # tiger this is a cream belly against an orange flank and you can see it
    # from across the street. Here both colours are pale, so what it mostly
    # does is the SECOND job -- `kill` below, which shortens the strokes on the
    # underside the way a real cat's are shortened. The colour step survives as
    # a whisper and is worth keeping: without it the pig is one flat cream and
    # the silhouette stops having a top and a bottom.
    hi=-0.10, lo=-0.38,
    # THE TILT, which is what stops the pale being a bathtub ring. The boundary
    # is measured on `z + tilt*y`, so at the nose it sits 0.30 higher and at
    # the tail 0.30 lower.
    tilt=0.34,
    # THE LEGS COME BACK OUT OF IT. They hang entirely below the belly line, so
    # a mask that is purely "low is pale" paints four white posts. Suppressing
    # the strokes is the SAME mask, so the toe stripes reappear exactly where
    # the coat colour does.
    leg_lo=-0.86, leg_hi=-0.62,
    # HOW MUCH OF THE STROKE THE UNDERSIDE KILLS. The tiger's number: with
    # `MIN_FRACTION` under it a stroke either crosses onto the pale as a stroke
    # or stops, and there is no third option to look like a scratch.
    kill=0.50,
)

# THE SNOUT DISC. Everything forward of y -1.26 is the snout, which the belly
# tilt would otherwise have painted with the underside colour.
NOSE = dict(lo=-1.26, hi=-1.13)

# THE EYE NARROWS THE STROKES INSTEAD OF CUTTING THEM. A mask on the ink can
# only ever cut, and every stroke cut at the same radius lines up into a drawn
# ring, which is a stencil rather than a marking. Multiplied into the stroke
# WIDTH instead, each one narrows and comes to a POINT before the eye -- in
# full colour the whole way, so nothing is washed out, and the endpoints
# scatter because every stroke starts from its own width.
#
# `r0`/`r1` are measured off the eye rather than chosen: `EyePreview` is 0.210
# studs across, so an eyeball is 0.105 in radius.
EYES = dict(x=0.318, y=-0.889, z=0.364, r0=0.16, r1=0.42)

# THE THINNEST STROKE THAT IS ALLOWED TO EXIST, as a fraction of that
# generator's nominal width. Below it the 2048-to-1024 downscale averages the
# ink into the coat and half a texel of colour comes back as a smear -- so a
# stroke tapers and then STOPS, at a thickness you can still see.
#
# **IT MATTERS MORE HERE THAN ON THE TIGER.** A brown smear on orange is a
# stripe fading out; a smear of one of eight hues on cream is a colour nobody
# authored sitting where a stroke used to be, which is exactly the thing
# `check_fade.py` measures and exactly the thing this art direction refuses.
MIN_FRACTION = 0.42

# AND THE WIDEST, as the same kind of fraction -- see `STRIPES['width']`, which
# is where the whole argument for this is written down. A FRACTION rather than
# an absolute for the reason `MIN_FRACTION` is one: the body measures width in
# phase and the head in arc, so one constant means two different thicknesses,
# and scaled off each one's own nominal it means the same thing to both.
#
# 1.20 is 0.576 of a body period against a nominal of 0.48. Anything at or
# below 1.0 disables `vary`'s upper half entirely and makes every stroke either
# nominal or thinner, which is a duller animal -- looked at, at 1.08, and the
# spine reads as a set of evenly-drawn hoops rather than as brushwork.
#
# **AND IT IS THE DIAL FOR THE ONE BLEMISH LEFT ON THIS SKIN.** A stripe is a
# PLANE, so where the surface runs nearly parallel to it the band spreads out
# across the geometry -- and the back of an ear does exactly that. There is a
# small red patch there in the spine render at every setting; it shrinks with
# this number and does not go away, because the cause is the angle rather than
# the width. 1.25 / 1.20 / 1.08 were all photographed. If it ever has to go,
# the lever is `slant` (a plane tilted further from the ear's own normal cuts
# it in a narrower band) and the cost is that the flank stripes stand up
# straighter, which is the tiger's whole silhouette.
MAX_FRACTION = 1.20

# NO INK FORWARD OF THE EYES. The stripe field is rings about the nose-tail
# axis, so on a snout it is a dark hoop AROUND THE NOSTRILS. `lo` is where the
# ink is fully gone and `hi` is where it is back, so the cheek strokes run
# forward and die on the jaw rather than being cut off square.
FACE = dict(lo=-1.06, hi=-0.97)

# THE HEAD IS A FAN OUT OF THE MUZZLE, NOT MORE RINGS. Rings about the
# nose-tail axis are right for the barrel and on the FACE they are bars across
# it; the reference wears cheek strokes that all point back at the nose. It is
# the zebra's field, borrowed whole: a stripe about a pole through the muzzle
# can be a RING or a MERIDIAN, and the head wants the way ROUND.
HEAD = dict(count=20, y_lo=-0.52, y_hi=-0.41, pole_down=17.7,
            # THE STROKE WIDTH ON THE HEAD, IN STUDS rather than in phase --
            # see `even`. Bolder than the tiger's 0.085 for the same reason
            # `STRIPES['width']` is: a hue needs area before it is a hue.
            arc=0.100,
            # HOW MUCH THE WIDTH IS EVENED OUT ALONG A MERIDIAN. 0 leaves a
            # stroke of constant ANGLE, which thins to a hairline at the
            # muzzle; 1 measures the width in ARC, so it keeps its thickness in
            # studs the whole way.
            even=1.0,
            # WHERE THE CLEAN COAT ROUND THE MUZZLE BEGINS, in degrees from the
            # pole. Evening the widths out fixes the thin end and creates a
            # thick one: below about twenty degrees the strokes need more room
            # than the circle has and they MERGE.
            start=32.0, start_soft=3.0)

# `pole_down` is the zebra's 17.7 degrees, which came from `Config` and is a
# fact about this pig's snout rather than about that animal. `HEAD_E1` is the
# UP direction seen from that pole and `HEAD_E2` is sideways, so `arctan2(E2,
# E1)` is 0 straight up the forehead and +-pi straight down the underjaw --
# which is where the hue wheel's own seam therefore lands. That is not a
# coincidence to be relied on quietly; it is printed at the end of the build.
_a = math.radians(HEAD['pole_down'])
HEAD_POLE = (0.0, -math.cos(_a), -math.sin(_a))
HEAD_E1 = (0.0, -math.sin(_a), math.cos(_a))
HEAD_E2 = (-1.0, 0.0, 0.0)
HEAD_FREQ = HEAD['count'] / (2.0 * math.pi)
# Compared as COSINES so no arc-cosine is needed in the graph. Nearer the nose
# is a BIGGER cosine, which is why these two read back to front.
HEAD_COS_LO = math.cos(math.radians(HEAD['start'] + HEAD['start_soft']))
HEAD_COS_HI = math.cos(math.radians(HEAD['start']))

# WHICH HUE THE FACE FAN WEARS, or `None` to let it carry on round the wheel.
#
# **BOTH WERE BUILT AND LOOKED AT, AND HOLDING ONE HUE LOST BADLY.** The
# reasoning for holding one is good and it is wrong: a face is the smallest and
# busiest surface on the animal, so a whole wheel crammed into it ought to be
# noise, and one colour ought to hold it together while the flank does the
# talking. That was written down before the render came back.
#
# What the render shows is that **THE FAN IS NOT A FACE, IT IS THE WHOLE FRONT
# HALF OF THE PIG.** `HEAD['y_lo']` is -0.52 on a body that starts at -1.08, so
# the fan owns everything forward of about the middle -- the snout, both
# cheeks, the brow, the ears and the front of the shoulder. Held at hue 0, the
# hero and low cameras came back RED AND WHITE from the nose to the shoulder,
# with a thin rainbow visible only over the haunch. That is not a rainbow tiger
# with a tidy face; it is a PEPPERMINT tiger, which is a different skin in
# `docs/animal-crate-plan.md`'s own rare tier, arrived at by accident.
#
# Carrying on round the wheel, the same camera reads as a rainbow immediately,
# because the surface a player looks at first is the surface the spectrum is
# on. The "it deletes the ordering" objection survives and is simply worth less
# than being legible from the front: the flank still runs the wheel in order,
# and the fan is a second reading of it round the snout.
#
# `HEAD_HUE = 0` is still one edit away, and it is the thing to reach for if
# anybody ever wants Peppermint out of this generator.
HEAD_HUE = None


def wheel(spec):
    """The spectrum, as `count` authored sRGB triples.

    GENERATED RATHER THAN TYPED OUT, so "one more hue" is a number and not
    eight new lines of guesswork -- and so the green dip is a rule applied to
    every hue rather than something somebody remembered to do to three of them.
    """
    out = []
    n = spec['count']
    for k in range(n):
        h = (spec['hue0'] + 360.0 * k / n) % 360.0
        # The distance from the bright band, taken the SHORT WAY round the
        # wheel: at `hue0` 300 the first hue is a violet and the last is a
        # magenta, and a straight subtraction would dip the wrong one.
        d = ((h - spec['dip_at'] + 180.0) % 360.0) - 180.0
        w = math.exp(-(d / spec['dip_wide']) ** 2)
        v = spec['val'] * (1.0 - spec['dip'] * w)
        out.append(colorsys.hsv_to_rgb(h / 360.0, spec['sat'], v))
    return out


HUES = wheel(RAINBOW)


# ------------------------------------------------------------------ plumbing
def mix_rgb(nt, label=""):
    """A colour mix, whichever node this Blender calls it.

    `ShaderNodeMixRGB` is legacy and `ShaderNodeMix` carries three sets of
    A/B sockets for float, vector and colour on ONE node -- so a lookup by the
    name 'A' is ambiguous and an index is a magic number that moves between
    versions. Asking for the legacy node first and falling back keeps every
    call site reading as fac/a/b, and fails loudly here rather than wiring the
    wrong socket somewhere in the middle of the graph.
    """
    try:
        n = nt.nodes.new("ShaderNodeMixRGB")
        n.label = label
        return n, n.inputs[0], n.inputs[1], n.inputs[2], n.outputs[0]
    except RuntimeError:
        n = nt.nodes.new("ShaderNodeMix")
        n.data_type = 'RGBA'
        n.label = label
        return n, n.inputs[0], n.inputs[6], n.inputs[7], n.outputs[2]


def coat(name):
    """The Rainbow Tiger's coat as one material. Built twice -- once for the
    body and once for the trim -- and DELIBERATELY NOT SHARED between them.

    `bake_skin.py` walks each object's material slots and points every material
    at the group's bake image, so a material worn by both the body and the trim
    would have its image node repointed by the second bake and the first sheet
    would come back blank. Two datablocks with one graph is the cheap way to
    keep those two bakes independent; the graph is generated, so they cannot
    drift.
    """
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)

    def node(kind, x, y, label=""):
        n = nt.nodes.new(kind)
        n.location = (x, y)
        n.label = label
        return n

    def math(op, x, y, label="", a=None, b=None, c=None):
        n = node("ShaderNodeMath", x, y, label)
        n.operation = op
        for i, v in ((0, a), (1, b), (2, c)):
            if v is not None:
                n.inputs[i].default_value = v
        return n

    def rng(x, y, label, lo, hi, out_lo, out_hi):
        n = node("ShaderNodeMapRange", x, y, label)
        n.interpolation_type = 'SMOOTHSTEP'
        n.clamp = True
        n.inputs['From Min'].default_value = lo
        n.inputs['From Max'].default_value = hi
        n.inputs['To Min'].default_value = out_lo
        n.inputs['To Max'].default_value = out_hi
        return n

    def noise(x, y, label, scale, detail, offset):
        """A noise sampled at an OFFSET position. Two noises at the same place
        with different scales are still correlated -- their large features line
        up -- so the wobble and the width variation would bend and pinch in the
        same places and the coat would read as one repeating motif. Moving each
        one a few studs away decorrelates them for the cost of a vector add."""
        off = node("ShaderNodeVectorMath", x - 210, y, "offset")
        off.operation = 'ADD'
        off.inputs[1].default_value = offset
        n = node("ShaderNodeTexNoise", x, y, label)
        n.noise_dimensions = '3D'
        n.inputs['Scale'].default_value = scale
        n.inputs['Detail'].default_value = detail
        n.inputs['Roughness'].default_value = 0.55
        nt.links.new(off.outputs['Vector'], n.inputs['Vector'])
        return off, n

    link = nt.links.new

    def floor_width(w, nominal, x, y, what):
        """A width, or nothing at all -- see `MIN_FRACTION`. Multiplying by the
        comparison rather than branching keeps it one node and keeps the result
        exactly zero, which is what stops a stroke being drawn at all."""
        big = math('GREATER_THAN', x, y, "%s: wide enough to draw?" % what,
                   b=nominal * MIN_FRACTION)
        link(w.outputs[0], big.inputs[0])
        out = math('MULTIPLY', x + 170, y, "%s: WIDTH OR NOTHING" % what)
        link(w.outputs[0], out.inputs[0])
        link(big.outputs[0], out.inputs[1])
        return out

    def to_band(src, x, y, what):
        """A phase into "how far from the nearest stroke centre", 0 on one and
        1 halfway between."""
        f = math('FRACT', x, y, "%s: one period" % what)
        link(src.outputs[0], f.inputs[0])
        c = math('SUBTRACT', x + 150, y, "from a centre", b=0.5)
        link(f.outputs[0], c.inputs[0])
        ab = math('ABSOLUTE', x + 300, y)
        link(c.outputs[0], ab.inputs[0])
        out = math('MULTIPLY', x + 450, y, "%s: 0 on a stroke" % what, b=2.0)
        link(ab.outputs[0], out.inputs[0])
        return out

    def to_hue(src, x, y, what):
        """A phase into a position in the rainbow ramp -- THE WHOLE SKIN.

        `to_band` inks the texels whose `fract(phase)` is near 0.5, so a stroke
        lives strictly inside one integer period and `floor(phase)` is CONSTANT
        across the whole of it. That integer is the stripe number.

        **THE HALF-STEP IS NOT A ROUNDING FLOURISH, IT IS WHAT KEEPS THE
        LOOKUP OFF THE STOP BOUNDARIES.** A `CONSTANT` ramp hands back the stop
        at or below its input, and `k/count` computed two different ways lands
        either side of the stop at `k/count` depending on the last bit of a
        float. Aiming at `(k + 0.5)/count` -- the MIDDLE of a band -- means no
        arithmetic error small enough to happen can pick the wrong hue.

        `FRACT` is `x - floor(x)` in Blender, so it is a true modulo and works
        on the negative indices the snout end of the body produces.
        """
        idx = math('FLOOR', x, y, "%s: WHICH STRIPE" % what)
        link(src.outputs[0], idx.inputs[0])
        step = math('MULTIPLY_ADD', x + 170, y, "steps, aimed mid-band",
                    b=float(RAINBOW['step']), c=0.5)
        link(idx.outputs[0], step.inputs[0])
        div = math('MULTIPLY', x + 340, y, "into ramp space",
                   b=1.0 / RAINBOW['count'])
        link(step.outputs[0], div.inputs[0])
        out = math('FRACT', x + 510, y, "%s: round the wheel" % what)
        link(div.outputs[0], out.inputs[0])
        return out

    # ---- where am I on the pig ---------------------------------------
    co = node("ShaderNodeTexCoord", -2100, 0, "the pig's own frame")
    sep = node("ShaderNodeSeparateXYZ", -1900, 0, "x across / y nose-tail / z up")
    link(co.outputs['Object'], sep.inputs['Vector'])
    X, Y, Z = sep.outputs['X'], sep.outputs['Y'], sep.outputs['Z']

    # ---- the pale underside ------------------------------------------
    lift = math('MULTIPLY_ADD', -1700, 420, "z + tilt*y", b=BELLY_MASK['tilt'])
    link(Y, lift.inputs[0])
    link(Z, lift.inputs[2])
    belly_a = rng(-1500, 420, "pale below",
                  BELLY_MASK['lo'], BELLY_MASK['hi'], 1.0, 0.0)
    link(lift.outputs[0], belly_a.inputs['Value'])
    leg_out = rng(-1500, 200, "but not the legs",
                  BELLY_MASK['leg_lo'], BELLY_MASK['leg_hi'], 0.0, 1.0)
    link(Z, leg_out.inputs['Value'])
    belly = math('MULTIPLY', -1250, 320, "UNDERSIDE MASK")
    link(belly_a.outputs['Result'], belly.inputs[0])
    link(leg_out.outputs['Result'], belly.inputs[1])

    # ---- the stripe phase --------------------------------------------
    wob_off, wob = noise(-1500, -260, "WOBBLE noise",
                         STRIPES['wobble_scale'], STRIPES['wobble_detail'],
                         (0.0, 0.0, 0.0))
    link(co.outputs['Object'], wob_off.inputs[0])
    wob_c = math('SUBTRACT', -1280, -260, "centre on zero", b=0.5)
    link(wob.outputs['Fac'], wob_c.inputs[0])
    wob_s = math('MULTIPLY', -1100, -260, "wobble amount", b=STRIPES['wobble'])
    link(wob_c.outputs[0], wob_s.inputs[0])

    gr_off, gr = noise(-1500, -520, "GRAIN noise",
                       STRIPES['grain_scale'], 3.0, (11.0, 4.0, -7.0))
    link(co.outputs['Object'], gr_off.inputs[0])
    gr_c = math('SUBTRACT', -1280, -520, "centre on zero", b=0.5)
    link(gr.outputs['Fac'], gr_c.inputs[0])
    gr_s = math('MULTIPLY', -1100, -520, "grain amount", b=STRIPES['grain'])
    link(gr_c.outputs[0], gr_s.inputs[0])

    slant = math('MULTIPLY_ADD', -1500, -60, "z * slant, + where it starts",
                 b=STRIPES['slant'], c=STRIPES['phase'])
    link(Z, slant.inputs[0])
    n1 = math('ADD', -900, -160, "wobble + grain")
    link(wob_s.outputs[0], n1.inputs[0])
    link(gr_s.outputs[0], n1.inputs[1])
    body_phase = math('MULTIPLY_ADD', -720, -20, "BODY: rings about the spine",
                      b=STRIPES['freq'])
    link(Y, body_phase.inputs[0])
    link(slant.outputs[0], body_phase.inputs[2])

    # ---- how near an eye is, which NARROWS a stroke rather than cutting it
    ax = math('ABSOLUTE', -2100, -1700, "mirror onto one eye")
    link(X, ax.inputs[0])
    here = node("ShaderNodeCombineXYZ", -1930, -1700, "this point")
    link(ax.outputs[0], here.inputs['X'])
    link(Y, here.inputs['Y'])
    link(Z, here.inputs['Z'])
    dv = node("ShaderNodeVectorMath", -1760, -1700, "offset from the eye")
    dv.operation = 'SUBTRACT'
    dv.inputs[1].default_value = (EYES['x'], EYES['y'], EYES['z'])
    link(here.outputs['Vector'], dv.inputs[0])
    dl = node("ShaderNodeVectorMath", -1590, -1700, "how far")
    dl.operation = 'LENGTH'
    link(dv.outputs['Vector'], dl.inputs[0])
    eye_t = rng(-1420, -1700, "come to a point at the eye",
                EYES['r0'], EYES['r1'], 0.0, 1.0)
    link(dl.outputs['Value'], eye_t.inputs['Value'])

    # ---- the width the BODY draws with -------------------------------
    v_off, vary = noise(-1500, -800, "WIDTH noise",
                        STRIPES['vary_scale'], 2.0, (-6.0, 13.0, 5.0))
    link(co.outputs['Object'], v_off.inputs[0])
    v_c = math('SUBTRACT', -1280, -800, "centre on zero", b=0.5)
    link(vary.outputs['Fac'], v_c.inputs[0])
    v_s = math('MULTIPLY_ADD', -1100, -800, "1 +- vary",
               b=STRIPES['vary'], c=1.0)
    link(v_c.outputs[0], v_s.inputs[0])
    w_raw = math('MULTIPLY', -960, -800, "nominal width", b=STRIPES['width'])
    link(v_s.outputs[0], w_raw.inputs[0])
    # THE CEILING -- see `STRIPES['width_max']`. It goes here, before the taper
    # and the underside and the eye, because all three of those only ever
    # NARROW: clipping the nominal clips the maximum wherever it occurs, and
    # doing it later would clip a stroke that the taper had already brought
    # under the limit on its own.
    w_base = math('MINIMUM', -820, -800, "never wider than this",
                  b=STRIPES['width'] * MAX_FRACTION)
    link(w_raw.outputs[0], w_base.inputs[0])
    # THE TAPER, which is a fact about z alone and therefore NOT the underside
    # mask. They do two different jobs: the mask says where the pale is, the
    # taper says a stroke is thick at the spine and thin at the bottom of the
    # flank -- which has to happen well ABOVE the mask or every stripe is a
    # full-width hoop right up to the moment it disappears.
    taper = rng(-900, -1030, "thick at the spine",
                STRIPES['taper_lo'], STRIPES['taper_hi'], STRIPES['taper'], 1.0)
    link(Z, taper.inputs['Value'])
    w_tap = math('MULTIPLY', -720, -960, "tapered width")
    link(w_base.outputs[0], w_tap.inputs[0])
    link(taper.outputs['Result'], w_tap.inputs[1])
    kill = math('MULTIPLY_ADD', -720, -800, "thinner over the underside",
                b=-BELLY_MASK['kill'], c=1.0)
    link(belly.outputs[0], kill.inputs[0])
    w_cream = math('MULTIPLY', -540, -800, "narrowed over the underside")
    link(w_tap.outputs[0], w_cream.inputs[0])
    link(kill.outputs[0], w_cream.inputs[1])
    w_eye = math('MULTIPLY', -380, -800, "and narrowed at the eye")
    link(w_cream.outputs[0], w_eye.inputs[0])
    link(eye_t.outputs['Result'], w_eye.inputs[1])
    width = floor_width(w_eye, STRIPES['width'], -220, -800, "body")

    # ---- the BODY's own ink mask --------------------------------------
    b_phase = math('ADD', -540, -20, "body phase + jitter")
    link(body_phase.outputs[0], b_phase.inputs[0])
    link(n1.outputs[0], b_phase.inputs[1])
    b_band = to_band(b_phase, -360, -20, "body")
    body_ink = math('LESS_THAN', 120, -20, "inside a body stripe?")
    link(b_band.outputs[0], body_ink.inputs[0])
    link(width.outputs[0], body_ink.inputs[1])
    # AND ITS HUE, off the SAME phase the stroke came from -- see `to_hue`.
    body_hue = to_hue(b_phase, -360, 200, "body")

    # ---- the HEAD is a SEPARATE GENERATOR, not the body's with a twist --
    unit = node("ShaderNodeVectorMath", -1900, -980, "direction from centre")
    unit.operation = 'NORMALIZE'
    link(co.outputs['Object'], unit.inputs[0])
    d1 = node("ShaderNodeVectorMath", -1700, -900, "up, seen from the pole")
    d1.operation = 'DOT_PRODUCT'
    d1.inputs[1].default_value = HEAD_E1
    link(unit.outputs['Vector'], d1.inputs[0])
    d2 = node("ShaderNodeVectorMath", -1700, -1080, "and sideways")
    d2.operation = 'DOT_PRODUCT'
    d2.inputs[1].default_value = HEAD_E2
    link(unit.outputs['Vector'], d2.inputs[0])
    phi = math('ARCTAN2', -1500, -990, "WAY ROUND THE MUZZLE (radians)")
    link(d2.outputs['Value'], phi.inputs[0])
    link(d1.outputs['Value'], phi.inputs[1])
    f_phase = math('MULTIPLY_ADD', -1300, -990, "head phase + jitter",
                   b=HEAD_FREQ)
    link(phi.outputs[0], f_phase.inputs[0])
    link(n1.outputs[0], f_phase.inputs[2])
    f_band = to_band(f_phase, -1120, -990, "head")

    # HOW FAR ROUND FROM THE MUZZLE, as a cosine. `arccos` is not needed: the
    # two things this is used for -- the sine, and the cutoff -- are both
    # cheaper straight off the dot product.
    dotp = node("ShaderNodeVectorMath", -1700, -1260, "cos of the angle")
    dotp.operation = 'DOT_PRODUCT'
    dotp.inputs[1].default_value = HEAD_POLE
    link(unit.outputs['Vector'], dotp.inputs[0])
    sq = math('MULTIPLY', -1500, -1260, "cos squared")
    link(dotp.outputs['Value'], sq.inputs[0])
    link(dotp.outputs['Value'], sq.inputs[1])
    one = math('SUBTRACT', -1340, -1260, "1 - cos squared", a=1.0)
    link(sq.outputs[0], one.inputs[1])
    sin_t = math('SQRT', -1180, -1260, "sin: how far off the axis")
    link(one.outputs[0], sin_t.inputs[0])

    # A meridian's spacing collapses at the pole, so a stroke of constant
    # ANGULAR width gets physically thinner all the way down the face and ends
    # as a scratch. Measuring the width in ARC instead -- multiplying the
    # distance-from-centre by `sin`, the radius of the circle this point sits
    # on -- gives strokes of an even thickness in studs.
    ev = math('POWER', -1000, -1260, "how much to even them out",
              b=HEAD['even'])
    link(sin_t.outputs[0], ev.inputs[0])
    arc = math('MULTIPLY', -840, -1120, "distance from centre, in ARC")
    link(f_band.outputs[0], arc.inputs[0])
    link(ev.outputs[0], arc.inputs[1])
    f_raw_w = math('MULTIPLY', -900, -1400, "head stroke width",
                   b=HEAD['arc'] * HEAD_FREQ)
    link(v_s.outputs[0], f_raw_w.inputs[0])
    # THE SAME CEILING, IN THE HEAD'S OWN UNITS. It shares `v_s` with the body,
    # so it shares the flooding: twenty meridians at 2.3x nominal merge into a
    # solid cap over the cheek, which is the ear blob one surface along.
    f_nom = math('MINIMUM', -780, -1400, "never wider than this",
                 b=HEAD['arc'] * HEAD_FREQ * MAX_FRACTION)
    link(f_raw_w.outputs[0], f_nom.inputs[0])
    f_eye = math('MULTIPLY', -680, -1470, "narrowed at the eye")
    link(f_nom.outputs[0], f_eye.inputs[0])
    link(eye_t.outputs['Result'], f_eye.inputs[1])
    f_width = floor_width(f_eye, HEAD['arc'] * HEAD_FREQ,
                          -520, -1470, "head")
    f_raw = math('LESS_THAN', -660, -1200, "inside a head stroke?")
    link(arc.outputs[0], f_raw.inputs[0])
    link(f_width.outputs[0], f_raw.inputs[1])

    # AND A HARD RING OF CLEAN COAT ROUND THE MUZZLE. Compared against the
    # COSINE, so a bigger number is NEARER the nose -- which is why the two
    # bounds read back to front, and why handing them to `rng` in the order the
    # ANGLES read inverts the ramp and puts the fan on the jaw.
    f_cut = rng(-660, -1400, "clean round the muzzle",
                HEAD_COS_LO, HEAD_COS_HI, 1.0, 0.0)
    link(dotp.outputs['Value'], f_cut.inputs['Value'])
    head_ink = math('MULTIPLY', -480, -1300, "HEAD INK")
    link(f_raw.outputs[0], head_ink.inputs[0])
    link(f_cut.outputs['Result'], head_ink.inputs[1])

    # ---- pick one, on y, with a narrow switch --------------------------
    head_w = rng(-480, -1550, "in front of the ears?",
                 HEAD['y_lo'], HEAD['y_hi'], 1.0, 0.0)
    link(Y, head_w.inputs['Value'])
    d_ink = math('SUBTRACT', -300, -1300, "head - body")
    link(head_ink.outputs[0], d_ink.inputs[0])
    link(body_ink.outputs[0], d_ink.inputs[1])
    raw = math('MULTIPLY_ADD', 300, -20, "whichever this point is in")
    link(d_ink.outputs[0], raw.inputs[0])
    link(head_w.outputs['Result'], raw.inputs[1])
    link(body_ink.outputs[0], raw.inputs[2])

    # ---- and the same switch picks the HUE, HARDENED -------------------
    # **THE INK SWITCH MAY BE SOFT AND THE HUE SWITCH MAY NOT.** `head_w` is a
    # smoothstep over 0.11 studs at the neck: on the INK that is a mask edge and
    # the threshold at the end of the graph turns it into a line. On a ramp
    # LOOKUP it is something else entirely -- a value halfway between two hue
    # positions is a THIRD hue, drawn as a band round the neck in a colour that
    # belongs to neither the head nor the body. Hardening it first costs one
    # node and makes that impossible.
    hard_head = math('GREATER_THAN', -300, 200, "head or body, never between",
                     b=0.5)
    link(head_w.outputs['Result'], hard_head.inputs[0])
    if HEAD_HUE is None:
        head_hue = to_hue(f_phase, -360, 440, "head")
        head_hue_sock = head_hue.outputs[0]
    else:
        held = node("ShaderNodeValue", -360, 440, "the face holds one hue")
        held.outputs[0].default_value = (HEAD_HUE + 0.5) / RAINBOW['count']
        head_hue_sock = held.outputs[0]
    d_hue = math('SUBTRACT', -120, 320, "head hue - body hue")
    link(head_hue_sock, d_hue.inputs[0])
    link(body_hue.outputs[0], d_hue.inputs[1])
    hue = math('MULTIPLY_ADD', 120, 200, "WHICH HUE THIS TEXEL IS")
    link(d_hue.outputs[0], hue.inputs[0])
    link(hard_head.outputs[0], hue.inputs[1])
    link(body_hue.outputs[0], hue.inputs[2])

    # THE SPECTRUM ITSELF: a table of authored colours, indexed. `CONSTANT`
    # interpolation is what makes it a table rather than a gradient -- see
    # `NO_FADING`. A new ramp arrives with two stops and the first cannot be
    # removed, so the existing pair is reused and the rest appended: building
    # by `new()` alone leaves a stray black stop at 0 that reads as a dark
    # sliver on one stripe and looks like a rendering artefact.
    ramp = node("ShaderNodeValToRGB", 320, 200, "THE SPECTRUM")
    ramp.color_ramp.color_mode = 'RGB'
    ramp.color_ramp.interpolation = 'CONSTANT'
    els = ramp.color_ramp.elements
    while len(els) > len(HUES):
        els.remove(els[-1])
    while len(els) < len(HUES):
        els.new(1.0)
    for i, (e, rgb) in enumerate(zip(els, HUES)):
        e.position = float(i) / len(HUES)
        e.color = to_linear(rgb) + (1.0,)
    link(hue.outputs[0], ramp.inputs['Fac'])

    # ---- what is never inked ------------------------------------------
    face = rng(120, -300, "clean muzzle", FACE['lo'], FACE['hi'], 0.0, 1.0)
    link(Y, face.inputs['Value'])
    keep = face

    soft = math('MULTIPLY', 1020, -20, "every mask, multiplied together")
    link(raw.outputs[0], soft.inputs[0])
    link(keep.outputs[0], soft.inputs[1])

    # ---- AND THEN IT IS MADE BINARY, WHICH IS THE WHOLE FIX -------------
    # **NO MASK IN THIS GRAPH MAY PRODUCE A HALF-DRAWN STROKE.** Every mask
    # multiplies the stroke mask, and the stroke mask is 0 or 1 -- so any mask
    # anywhere between does not draw fewer strokes, it draws a stroke at PART
    # STRENGTH, which is a hue lerped toward the coat. One threshold at the end
    # makes that structurally impossible.
    ink = math('GREATER_THAN', 1200, -20, "INK, or not. Never half.", b=0.5)
    link(soft.outputs[0], ink.inputs[0])

    # ---- the colours --------------------------------------------------
    # EVERY FACTOR THAT REACHES A COLOUR PASSES THROUGH HERE. A `Mix` factor of
    # 0.4 does not draw less of something -- it draws a colour that was never
    # authored, 40% of the way between two that were. See `NO_FADING`.
    def hard(sock, x, y, what):
        n = math('GREATER_THAN', x, y, "%s: one colour or the other" % what,
                 b=0.5)
        link(sock, n.inputs[0])
        return n.outputs[0]

    m1, f1, a1, b1, o1 = mix_rgb(nt, "coat -> pale underside")
    m1.location = (300, 700)
    a1.default_value = to_linear(COAT) + (1.0,)
    b1.default_value = to_linear(BELLY) + (1.0,)
    link(hard(belly.outputs[0], 120, 700, "the pale underside"), f1)

    nose = rng(120, 940, "the snout disc", NOSE['lo'], NOSE['hi'], 1.0, 0.0)
    link(Y, nose.inputs['Value'])
    m2, f2, a2, b2, o2 = mix_rgb(nt, "snout pad")
    m2.location = (500, 700)
    b2.default_value = to_linear(SNOUT) + (1.0,)
    link(hard(nose.outputs['Result'], 300, 940, "the snout pad"), f2)
    link(o1, a2)

    m3, f3, a3, b3, o3 = mix_rgb(nt, "lay this stripe's hue on")
    m3.location = (700, 460)
    link(ink.outputs[0], f3)
    link(o2, a3)
    link(ramp.outputs['Color'], b3)

    bsdf = node("ShaderNodeBsdfPrincipled", 900, 280)
    bsdf.inputs['Roughness'].default_value = 0.88
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.08
    link(o3, bsdf.inputs['Base Color'])
    out = node("ShaderNodeOutputMaterial", 1220, 280)
    link(bsdf.outputs['BSDF'], out.inputs['Surface'])
    return mat


def flat(name, rgb):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes["Principled BSDF"]
    b.inputs['Base Color'].default_value = to_linear(rgb) + (1.0,)
    b.inputs['Roughness'].default_value = 0.88
    return mat


# -------------------------------------------------------------- the driver
bpy.ops.wm.open_mainfile(filepath=paths.find(SRC, "blend"))

body_mat = coat("rainbowtiger_body")
trim_mat = coat("rainbowtiger_trim")
ear_mat = flat("rainbowtiger_ear_inner", EAR_PINK)

# THE EARS KEEP THEIR TWO SLOTS AND THE ORDER THEY ARE IN. Face assignment
# lives on the polygons as a `material_index`, so replacing slot 0 with slot 0
# and slot 1 with slot 1 inherits whatever selection was made by hand -- clear
# the list and append in the wrong order and the inner ear paints the outside
# with nothing to say so.
ASSIGN = [("Body", [body_mat]),
          ("Snout", [trim_mat]),
          ("Legs", [trim_mat]),
          ("Tail", [trim_mat]),
          ("Ears", [trim_mat, ear_mat])]

# SEATED THROUGH `skin_parts.assign`, WHICH IS THE ONE PLACE THAT KNOWS THAT
# `materials.clear()` ALSO RESETS EVERY POLYGON'S SLOT INDEX.
assign(bpy, ASSIGN, "RAINBOW TIGER  (from %s)" % SRC)

for _n, _c in face_slots(bpy, [n for n, _ in ASSIGN]):
    if len(_c) > 1:
        print("  %-6s faces per slot %s  <- hand selection, intact"
              % (_n, _c))

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("")
print("  saved %s -- %s is untouched"
      % (os.path.relpath(OUT, D), os.path.relpath(SRC, D)))
print("  about %d stripes down the flank, %.0f%% of each period in ink"
      % (round(STRIPES['freq'] * 2.13), STRIPES['width'] * 100))
print("  %d hues from %.0f deg, %s%s"
      % (RAINBOW['count'], RAINBOW['hue0'],
         "step %d, " % RAINBOW['step'] if RAINBOW['step'] != 1 else "",
         "face holds hue %d" % HEAD_HUE if HEAD_HUE is not None
         else "face carries on round the wheel"))
for i, c in enumerate(HUES):
    print("    %2d  #%02X%02X%02X   hue %5.0f deg"
          % (i, int(c[0] * 255 + 0.5), int(c[1] * 255 + 0.5),
             int(c[2] * 255 + 0.5),
             (RAINBOW['hue0'] + 360.0 * i / RAINBOW['count']) % 360.0))
# THE HEAD FAN'S WRAP, SAID OUT LOUD ON EVERY BUILD. Its phase jumps by exactly
# `HEAD['count']` across `phi = +-pi`, so the hue jumps by that many steps; only
# a multiple of `RAINBOW['count']` is invisible. It is parked on the underjaw
# either way -- see the header -- but a number nobody re-derives is how this
# project keeps finding out about a seam months later.
_jump = (HEAD['count'] * RAINBOW['step']) % RAINBOW['count']
print("  head fan wraps on the underjaw by %d hue step(s) -- %s"
      % (_jump, "invisible" if _jump == 0 or HEAD_HUE is not None
         else "VISIBLE, and only there"))
