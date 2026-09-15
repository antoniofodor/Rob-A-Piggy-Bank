# -*- coding: utf-8 -*-
"""Build STAINED GLASS as a node graph, in its own blend file.

    blender.exe --background --python skins/stainedglass/make_stainedglass_blend.py

Writes `skins/stainedglass/stainedglass.blend`. Then the ordinary loop:

    blender.exe --background --python make/bake_skin.py       -- --skin stainedglass
    blender.exe --background --python make/make_view_blend.py -- --skin stainedglass --render

THE PATTERN IS DEFINED IN 3D, NEVER IN UV SPACE -- see `WORKFLOW.md`. The
shader is evaluated at a POSITION on the surface, so Smart UV Project can
rotate every island however it likes and a pane still lands where the geometry
says it lands. The bake resolves it afterwards.

`Material.Glass` IS NOT AVAILABLE TO THIS SKIN AND THE WHOLE OF THE GLASS HAS
TO BE PAINTED. `docs/animal-crate-plan.md` reserves one lever per legendary and
gives this one "the only skin made of glass" -- and a skin carrying a baked
sheet cannot have it. `Config.skinSurface` REFUSES to hand a surface pack to
any skin whose material is Neon or Glass and returns nil, because a part
wearing a `SurfaceAppearance` ignores its own `Material` while going on
REPORTING it: the pairing fails silently in both directions, which is the
`UseJumpPower` family exactly. The note beside it records Glass being found by
trying to convert the Snow Leopard, whose whole identity is a glass body, and
getting grey plastic with `material = Enum.Material.Glass` still sitting in its
row.

So it is EITHER a full-colour coat OR Glass, never both, and the coat is
obviously the half worth keeping -- Glass buys a sheen and the coat buys the
leading, the jewels and the whole picture. What that costs is that everything
glassy has to be DRAWN: the pale cut of every colour (`HIGHLIGHT`) instead of
a specular, and the leading's contrast instead of a refraction.

WHAT REPLACES THE MATERIAL AS THE TIER'S OWN LEVER IS THE ALPHA PASS.
`docs/animal-crate-plan.md` has since dropped "one reserved lever per
legendary" for a ladder where common and rare are PAINT, epic GLOWS and
legendary glows AND MOVES -- and the mechanism is `ALPHA_MASK` at the end of
this graph. The clear glass is handed to `ClientMain`'s skin animator and
every coloured piece is painted, so the light through the window changes and
the window does not. That is the same idea as `Material.Glass` from the other
end, and unlike the material it is available to a coat. Nothing here is wired
into the game and this file makes no claim about a material or an `anim`.

WHY IT IS THE GIRAFFE'S FIELD READ FROM THE OTHER SIDE. The giraffe draws flat
cells separated by lanes -- which is structurally a leaded window already, and
the whole job is the READ rather than the field:

    a giraffe   the LANES are the background showing through, and the cells
                are objects scattered on it -- so the lanes wander, pinch shut
                and let two patches merge, because that is what a coat does
    a window    the LEADING is an OBJECT, a came of drawn metal that a person
                cut and soldered, so it is CONSTANT WIDTH and CONTINUOUS, and
                the panes are what is left between it

So three things invert and nothing else does:

1. THE LEAD IS DRAWN LAST, OVER EVERYTHING. On the giraffe the base colour
   shows wherever a patch failed to survive. Here the leading is a positive
   object laid on top -- which is what makes it survive the snout pad, and
   what makes two neighbouring panes that happen to draw the SAME colour still
   read as two panes with a line between them.
2. THE LANES STOP WANDERING. `cell_vary` and `wobble` are near zero. Where the
   giraffe wants a lane to pinch shut so two patches merge, a window wants
   every came the same width along its whole length -- a lane that closes is a
   soldering fault, not a bigger pane.
3. EVERY CELL TAKES ITS OWN COLOUR out of a six-entry palette at two
   densities, indexed off two channels of the per-cell random the giraffe
   already computes and spends on size. ONE FLAT AUTHORED COLOUR PER PANE,
   which is what keeps this inside the no-fading rule -- see `NO_FADING`.

MAGMA IS THE SAME GENERATOR WITH THE OPPOSITE READ -- dark plates, glowing
cracks -- and is being built beside this one. The plan says in as many words
that if the two end up looking like relatives, the lever to separate them is
the CELL SHAPE: a giraffe's cells are irregular and a leaded window's want to
be closer to even. `randomness` is that lever and it is pushed DOWN here.

THE COORDINATE FRAME IS THE PIG'S OWN, measured off the mesh rather than
assumed. Every part sits at identity, so object space IS world space and all
five parts share one frame -- which is what lets a came run off the flank onto
a leg with no seam:

    x   across          body reaches +-1.000
    y   NOSE to TAIL    snout tip -1.381, body -1.080..1.052, tail tip 1.465
    z   floor to CROWN  legs -1.020, body -0.960..0.960, ear tip 1.309

So -Y is the face and +Z is up.

AN OBJECT MADE OF GLASS, NOT AN ANIMAL MADE OF GLASS -- and that was tried
both ways rather than decided. See `ANATOMY` below.
"""

# --- find the toolkit, wherever this script has been filed ------------------
# Walks up from this file until it finds the folder holding `paths.py`. Depth
# independent on purpose: a script in `make/` and a script in
# `skins/stainedglass/` are two and three levels down, and a hardcoded `..` is
# a thing that breaks silently the first time anything is refiled.
import os as _os, sys as _sys
_root = _os.path.dirname(_os.path.abspath(__file__))
while not _os.path.exists(_os.path.join(_root, "paths.py")):
    _up = _os.path.dirname(_root)
    if _up == _root:
        raise RuntimeError("cannot find paths.py above %s" % __file__)
    _root = _up
if _root not in _sys.path:
    _sys.path.insert(0, _root)
# ---------------------------------------------------------------------------
D = _root

import paths   # noqa: E402 -- the one place that knows the layout
import bpy, os, sys

from skin_colours import to_linear   # noqa: E402
from skin_parts import assign, face_slots   # noqa: E402


argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SRC = arg("--blend", paths.PARTS)
OUT = arg("--out", paths.skin_blend("stainedglass"))

# --------------------------------------------------------------- the colours
# NOT READ OUT OF `Config.luau`, AND THAT IS A FACT ABOUT THE CATALOGUE RATHER
# THAN A SHORTCUT. `skin_colours.skin()` exists so a preview cannot show a
# colour the game does not ship -- it parses `Config.SKINS.<key>.body/.trim`.
# There is no `stainedglass` row: nothing here is wired into the game yet, and
# `Config.luau` is owned by one session at a time (`WORKFLOW.md`, "Two skins at
# once"). So the palette is authored HERE, and the day this gets a Config row
# it gets a `body`/`trim` pair that stops doing anything anyway -- a
# full-colour sheet at alpha 255 is `lerp(partColour, mapRGB, 1)`, which is
# `mapRGB`. See `WORKFLOW.md`, "What a full-colour sheet costs".
#
# THE PANES ARE BRIGHTER THAN REAL GLASS, ON PURPOSE, AND THAT IS THE ONE
# COLOUR DECISION WORTH ARGUING ABOUT. A real window is read TRANSMITTED --
# the light is behind it, so a deep ruby that measures almost black in the hand
# blazes on a wall. A piggy bank is read REFLECTED, in `WorldService`'s 14:30
# sun, with nothing behind it at all, so every one of these is authored a
# couple of stops up from its own name. The leading has nowhere left to go, so
# the whole of the CONTRAST that says "window" has to be spent on the panes: a
# ruby authored at a real transmitted value sits at a relative luminance of
# about 0.03, against a came at 0.012, and the line between them is nothing.
#
# AND THE WHOLE COAT SITS WELL UNDER THE BLOOM THRESHOLD, WHICH IS MEASURED
# AND MATTERS TO THE TIER. `docs/animal-crate-plan.md` proposes that an epic
# glows by "baking a colour bright enough to clear 1.8", and this coat cannot:
# rendered under `make_view_blend.py`'s copy of the game's own sun rig, the
# brightest pixel on the entire animal reads 218 of 255, so NOTHING CLIPS and
# nothing comes within a factor of two of the threshold. That is with the
# palest glass here at luminance 0.85 and full sun on it. A baked colour is
# a REFLECTANCE and the sun is the only light in this scene, so short of an
# emissive material -- which is Neon, which a coat may not have -- there is
# no route to bloom from paint. Whatever makes this a legendary, it is not
# that.
JEWELS = [
    (198 / 255.,  38 / 255.,  56 / 255.),   # ruby
    ( 58 / 255., 118 / 255., 226 / 255.),   # sapphire
    ( 32 / 255., 152 / 255.,  98 / 255.),   # emerald
    (242 / 255., 172 / 255.,  44 / 255.),   # amber
    (164 / 255.,  88 / 255., 210 / 255.),   # amethyst
    (232 / 255., 238 / 255., 240 / 255.),   # opal -- see below
]

# THE OPAL IS THE SIXTH AND IT IS NOT A JEWEL, WHICH IS THE POINT. The brief
# names five stones and five is what went in first; rendered, the pig came back
# reading as a BEACH BALL rather than as glass, and the reason is a measurement
# rather than a feeling. Relative luminance of the five: ruby 0.137, sapphire
# 0.193, amethyst 0.195, emerald 0.236, amber 0.486. FOUR OF THE FIVE SIT
# INSIDE A THIRTY-POINT BAND, so from the pavement the coat is one tone with
# the hue changing, and one tone with the hue changing is a printed ball. A
# real leaded window is never that -- it has clear and opal glass in it, and
# the pale pieces are what give the dark ones somewhere to be dark AGAINST.
#
# At 0.846 it is the only thing here more than twice the luminance of anything
# else, and adding it was the single largest improvement in the whole build.
# One entry in six, so it is a scatter rather than a field, and it costs the
# palette nothing else: it does not touch the leading, and it is the only glass
# that still reads on the shaded side of the animal.
#
# IT IS ALSO WHAT THE ENGINE ANIMATES -- see `ALPHA_MASK` at the end of the
# graph. The clear glass is the piece a real window lets the light through, so
# it is the piece handed to the skin animator.

# THE LEADING. Near-black with a COOL cast rather than a neutral one, because
# came is lead and lead is blue-grey -- and because every jewel above except
# the sapphire is warm, so a warm lead would sit inside the palette's own hue
# range and read as a sixth colour rather than as a line.
#
# NOT PURE BLACK, so that the came still has somewhere to go under the game's
# blue `OutdoorAmbient` fill. A texel at (0, 0, 0) is a texel that renders the
# same on the lit side and the shaded side, which reads as an absence -- a hole
# in the pig -- rather than as metal between panes. At a luminance of 0.012 it
# is still eleven times darker than the darkest glass here, so nothing is
# spent on the contrast that carries the whole picture.
LEAD = (26 / 255., 28 / 255., 34 / 255.)

# The two places a pig shows skin rather than glass, and the one deliberate
# survival of the ANIMAL in an object made of glass. `Config.SKINS.giraffe`'s
# own comment makes this call and the leopard makes it too: the reference is a
# piggy BANK, and a snout that is not pink stops the thing reading as a pig.
# Here it is a rose glass rather than a skin pink -- saturated enough to sit in
# the jewel palette instead of beside it.
ROSE = (232 / 255., 108 / 255., 132 / 255.)
EAR_PINK = (236 / 255., 132 / 255., 156 / 255.)

# --------------------------------------------------------------- the tunables
# EVERY NUMBER THAT DECIDES WHAT THE WINDOW LOOKS LIKE IS IN THESE DICTS, so a
# note like "the leading is too heavy" is a one-line edit and a two-second
# re-run.
#
# EVERY LENGTH IN HERE IS IN CELL UNITS AND EVERY ONE OF THEM ADDS TO `gap`.
# Blender scales the input by `scale` before measuring, so a cell is about 1
# across whatever the scale is -- which means `scale` changes HOW MANY panes
# there are and does not change how wide the leading is relative to them. Two
# dials, not one tangled one.
PANES = dict(
    # HOW MANY. Cells per stud, so the body's 2.0 studs across carries about
    # `2*scale` of them.
    #
    # A WINDOW WANTS MORE PIECES THAN A COAT. The giraffe runs 2.4, about five
    # patches across a flank, and a coat is meant to read as a few large
    # markings; a window has to read as MANY pieces or the leading is four
    # separate strokes rather than a network.
    #
    # RENDERED AT 3.6, 4.2 AND 5.0, JUDGED AT THE DISTANCE THE STREET SEES IT
    # rather than zoomed in, because that is the question. 3.6 is bold and
    # clear and is the closest of the three to a coat. 5.0 is busy: at whole-pig
    # size the panes stop being individually readable and the coat starts
    # reading as speckle, which is the failure that makes a mosaic look like
    # noise. 4.2 keeps both -- individual panes at conversation range, a
    # continuous lead network from the pavement.
    scale=4.2,
    # HOW REGULAR THE LATTICE IS, AND THE ONE DIAL THAT SEPARATES THIS FROM
    # MAGMA. At 1.0 the cell centres are fully jittered and the cells come out
    # wildly uneven, which is an animal's coat; at 0 they are a perfect
    # lattice, which is a football. A leaded window is neither: it is CUT
    # glass.
    #
    # RENDERED AT 0.22, 0.42 AND 0.62. At 0.22 the panes come out almost
    # rectangular and the whole thing reads as brickwork -- crisp, and made by
    # a machine. At 0.62 the cells start disagreeing about size enough that it
    # drifts back toward the giraffe, which is the one thing this must not do,
    # because Magma is that same field and the CELL SHAPE is the only lever
    # separating the two. 0.42 is hand-cut: irregular the way a glazier's
    # cutting is irregular rather than the way a leopard's spots are, and a
    # long way below the giraffe's own 0.68.
    randomness=0.42,
    # HALF THE CAME WIDTH, in cell units, and the number everything else adds
    # to. The lane between two neighbouring panes is `2 * gap` wherever they
    # touch, so 0.052 is a came about 10% of a pane across -- which is roughly
    # what real came is, and it survives the downscale to 1024.
    #
    # RENDERED AT 0.046, 0.058 AND 0.070 SIDE BY SIDE. At 0.070 the came is
    # heavy enough that the panes read as tiles set in dark grout and the
    # colour is the minority; at 0.046 it is lively and starts to look thin
    # from the pavement. Measured on the baked sheet, this lands the leading
    # at about a QUARTER of the animal's own surface, which is well over a
    # real window's ten per cent and is the right cheat -- a came that is
    # honestly scaled disappears at the distance a piggy bank is looked at.
    gap=0.052,
    # PER CELL, and NEARLY OFF -- which is the giraffe's dial turned down
    # rather than deleted, and the difference is the whole point. On a coat
    # this is what stops the lattice reading as wallpaper: two patches sharing
    # a border disagree about how far back they stand, so the lane between them
    # is not the same width as the next one. A window is wallpaper. Every came
    # in it was cut to one width by one person, and a came that is visibly
    # fatter on one side of a pane than the other is a fault.
    #
    # NOT ZERO, because at zero the field is perfectly self-similar and the
    # panes start reading as a repeating motif rather than as cut pieces. 0.006
    # is under a tenth of `gap` -- invisible as a width and enough to break the
    # repeat.
    cell_vary=0.006,
    # THE WANDER, and the second thing turned nearly off. On the giraffe this
    # is the mechanism that makes big patches: slow noise pinches a whole run
    # of lanes shut at once and three neighbours become one. That is exactly
    # the "soldering fault" this skin must not have, so it is small enough to
    # give the came a hand-drawn waver and nowhere near enough to close one.
    #
    # `wobble` at 0.010 against a `gap` of 0.052 is a +-19% waver on the came
    # width. Measured the other way: closing a lane needs the addend to reach
    # -0.052, which this cannot do at any point in its range.
    wobble=0.010, wobble_scale=4.6,
    # THE CUT EDGE. Fast noise at the scale of the border itself. This is the
    # one place a window wants LESS than an animal and gets it for a different
    # reason: a giraffe's border is ragged because hair is ragged, and a
    # glazier's cut is ragged because a score-and-snap is never dead straight.
    # Both want a small number; this one is smaller because the feature is a
    # nick in a cut line rather than a fringe.
    grain=0.004, grain_scale=22.0,
)

# NOT EVERY PANE IS THE SAME DENSITY OF GLASS, AND THIS IS WHAT `Material.Glass`
# WOULD HAVE DONE AND CANNOT. See the header: a baked coat and Glass are
# mutually exclusive, so the one thing a material was going to contribute --
# the sense that this is a translucent substance rather than paint -- has to be
# drawn. What is drawn is the thing a real leaded window has and a printed ball
# does not: PIECES OF THE SAME COLOUR CUT FROM DIFFERENT GLASS. A pale ruby
# next to a deep one says the material has a thickness; six flat colours in a
# grid says it was printed.
#
# SO IT IS A SECOND ROLL OF THE SAME DICE, NOT A SECOND PATTERN.
# `Voronoi -> Color` is three independent random numbers per cell; the ladder
# below spends X on WHICH glass and this spends Y on HOW DENSE, so a pane is
# one of twelve authored colours and is still exactly ONE FLAT COLOUR. That
# last part is the whole reason this shape was chosen over the two below.
#
# `pale` IS THE CUT ON THAT SECOND RANDOM, so 0.74 makes about a quarter of the
# panes the lighter cut. AT 0.55 IT WAS HALF AND THE PIG WENT PASTEL -- rendered
# with `lift` at 0.42 as well, and the two multiplied: half the panes a long way
# toward white is not a window with some pale glass in it, it is a window with
# no colour left. A quarter at 0.28 reads as variety without costing saturation.
#
# ---------------------------------------------------------------------------
# TWO WAYS OF PAINTING A SPECULAR HIGHLIGHT WERE TRIED FIRST AND BOTH ARE OUT.
# They are recorded rather than deleted because the first is a general trap and
# the second is a real technique that simply loses to this one.
#
# A STREAK ALONG THE TOP EDGE OF EVERY PANE -- the cartoon glass convention, a
# shape with a pale band across one corner. The mechanism looks free:
# `Voronoi -> Position` is the pane's own feature point, so
# `dot(thisPoint - Position, up) > at` is "the upper part of this pane" in one
# dot product.
#
#   RENDERED, IT IS NOT A BAND ON A PANE, IT IS THE TOP HALF OF THE PIG. The
#   cells are a 3D lattice through a SHELL, so a surface point on the animal's
#   back is above its own cell centre and one on the belly is below it, and
#   that systematic term swamps the within-pane term completely. What came back
#   was a pig whose upper half was uniformly pale and whose lower half was
#   uniformly saturated, with no band anywhere. AN OFFSET FROM A 3D CELL CENTRE
#   IS NOT A COORDINATE ON A SURFACE. Doing it properly means projecting the
#   surface normal out of both vectors first -- and that degenerates exactly
#   where the normal IS the highlight direction, over the crown of the back,
#   where the tangential up-vector goes to zero and its direction is undefined.
#
# A BEVEL -- a pale rim of constant width hugging the inside of the came all
# the way round, which is `edge < gap + bevel` and needs no direction at all.
# This one WORKS: it is the right shape, it is rotationally symmetric so it
# cannot be wrong on the far row of plots, and real came does catch light along
# its whole length. Rendered against no highlight at all and against a wide
# version, at 0.030 and 0.048 of a cell:
#
#   IT SPENDS THE LEAD TO BUY THE HIGHLIGHT. A pale band inside a black line
#   is a pale band ON a black line at 1024 delivered texels, so the came stops
#   reading as a hard black network and starts reading as a grey one with a
#   halo. Side by side the no-highlight version is bolder, cleaner and more
#   legible from the distance this is actually seen at, and the bevel version
#   is the one that looks blurred. The lead is the single loudest thing this
#   skin has and nothing may be taken out of it.
#
#   AND IT NEARLY FAILED THE FADE CHECK FOR A REASON WORTH KNOWING. At 0.016 a
#   cell the rim is thin enough that its twelve colours each hold under
#   `check_fade.py`'s 0.4%-of-sheet floor, so they are counted OFF-PALETTE, and
#   because a rim is flat rather than an anti-aliased edge it survives the 5x5
#   erosion and is reported as a FADE. Nothing was wrong with the sheet.
HIGHLIGHT = dict(pale=0.74,
                 # HOW MUCH PALER, toward white. Applied IN PYTHON, at build
                 # time, so what reaches the graph is a second list of
                 # AUTHORED constants and there is no mix factor anywhere
                 # between a glass and its lighter cut. A `Mix` at 0.28 would
                 # be the exact thing `NO_FADING` refuses -- and it would look
                 # identical here, which is why it is worth saying out loud
                 # rather than assuming the next person will see it.
                 lift=0.28)


def lighter(c):
    """A glass and its own highlight, computed once at build time."""
    k = HIGHLIGHT['lift']
    return tuple(v + (1.0 - v) * k for v in c)

# NOTHING ON THIS SKIN FADES INTO ANYTHING ELSE.
#
# The theme is CARTOON, so every texel is one of the colours named above and
# never a blend of two. That is enforced at the graph's output rather than
# asked of each mask: every factor reaching a colour mix goes through `hard`,
# so a soft mask anywhere upstream moves an EDGE rather than smearing one.
#
# IT IS THE PALETTE SELECTION THAT MADE THIS WORTH RESTATING. Picking one of
# twelve colours off a per-cell random is the first thing in this catalogue
# that is not "one colour or the other", and the obvious construction -- a
# ColorRamp with six stops on the cell random -- fails the rule outright: a
# ramp INTERPOLATES, so every pane would be a blend of two glasses and the ones
# near a stop boundary would each be a colour nobody authored. What is here
# instead is a ladder of hard comparisons feeding a ladder of mixes, so a pane
# is one entry of `JEWELS` or its own lighter cut, and there is no arithmetic
# anywhere in the graph that can produce a thirteenth colour.
NO_FADING = True

# ANATOMY: AN ANIMAL MADE OF GLASS, OR A GLASS OBJECT SHAPED LIKE A PIG. IT IS
# A SWITCH BECAUSE IT WAS RENDERED BOTH WAYS RATHER THAN DECIDED.
#
# The giraffe carries `MUZZLE`, `SOCKS` and a `BELLY_ADD`, each an addend on
# `gap` that opens the lanes out toward the nose, the paws and the underside
# until the patches die and the base tan shows. Inherited here unchanged they
# are the whole difference between the two readings, so they are kept, wired
# and switched OFF rather than deleted -- flip `on` and look.
#
# THEY ARE OFF, AND THE REASON IS NOT TASTE, IT IS WHAT "NO PANE" MEANS HERE.
# On the giraffe the thing underneath a patch is TAN, so a muzzle with its
# patches killed is a PALE muzzle, which is the marking the reference has.
# Under this skin the thing underneath a pane is LEADING, because the lead is
# drawn last and over everything. The identical three masks therefore do not
# give a pale muzzle, pale socks and a pale belly -- they give a BLACK SNOUT,
# four BLACK FEET and a BLACK UNDERSIDE.
#
# RENDERED, THAT IS WORSE THAN IT SOUNDS AND THE FAILURE IS SPECIFIC. What
# lands on the face is a BLACK BAND ACROSS THE BRIDGE OF THE MUZZLE, wide as
# the head and shading into a black front to the snout, with the rose pad
# reduced to a few panes below it; the belly and the tops of all four legs go
# the same way. From the low camera it reads as a pig wearing a mask, and the
# eye takes near-black as the OBJECT'S OWN COLOUR with the glass as something
# applied to it. The animal stops being made of glass and becomes a dark pig
# with glass on it, which is exactly backwards.
#
# AND IT IS MEASURABLE RATHER THAN ONLY VISIBLE. Baked both ways and counting
# the leading colour, the lead goes from 24.7% of the body's own surface to
# 29.3%, and on the TRIM -- which is the snout and all four legs, so where all
# three masks land -- from 25.5% to 35.3%. A third of the black on that sheet
# is not came between panes at all: it is a region with no window in it.
#
# So the only anatomy that survives is the two things that are about the OBJECT
# rather than about a coat: the snout pad and the eyes, both below. A leaded
# window has no cheeks, no belly and no socks.
ANATOMY = dict(
    on=False,
    # THE GIRAFFE'S OWN NUMBERS, unchanged, because the point of the switch is
    # to see that skin's treatment on this one rather than a version of it
    # tuned until it stopped hurting.
    muzzle_lo=-1.22, muzzle_hi=-0.95, muzzle_add=0.115,
    socks_lo=-1.00, socks_hi=-0.80, socks_add=0.035,
    belly_hi=-0.30, belly_lo=-0.66, belly_tilt=0.30,
    belly_leg_lo=-0.76, belly_leg_hi=-0.56, belly_add=0.080,
)

# THE SNOUT PAD, and the one place this deliberately leaves the window and
# stays with the piggy bank -- the same call the giraffe and the leopard both
# make. `lo` is where the pad is at full strength and `hi` is where it has
# ended, in y, so it is a disc on the end of the snout rather than a band
# painted across the muzzle.
#
# IT IS GLAZED RATHER THAN PAINTED, WHICH IS THE HALF THAT MATTERS. The pad
# replaces the PANE COLOUR and is then overdrawn by the leading like everything
# else, so what lands is a cluster of rose panes with came between them -- a
# little rose window on the end of the snout -- instead of a flat pink sticker
# with the glass stopping dead at its rim. That is one line of ordering (lead
# last) and it is the difference between the two readings.
NOSE = dict(lo=-1.33, hi=-1.21)

# THE EYES GET A LEAD SURROUND, WHICH IS `WORKFLOW.md` RULE 6 ANSWERED IN THIS
# SKIN'S OWN VOCABULARY RATHER THAN COPIED FROM THE GIRAFFE'S.
#
# The rule says clear the eyes: they are code-built parts standing proud of the
# body at (+-0.318, -0.889, 0.364), and a marking running up to their rim reads
# as a smear. The giraffe's answer is to PUSH THE BOUNDARY -- an addend on
# `gap` that peaks at the eye, so nearby patches pull back inside their own
# cells rather than fading out. That mechanism is inherited here unchanged and
# it means something different and better: fatter came around the eye is a LEAD
# COLLAR, which is exactly what a glazier does with a feature in a window.
#
# `r0` is the radius held fully clear and `r1` is where the leading is back to
# normal, both in STUDS off the eye's own centre; `add` is the push, in cell
# units, on the same ruler as `gap`.
#
# SIZED AGAINST THE EYE RATHER THAN CHOSEN. Each eye is a ball of radius 0.105
# studs, so `r0` at 0.15 leaves about half an eyeball's width of solid came
# round the rim. `r1` at 0.32 is a little over one cell out at this scale, so
# only the ring of panes immediately around the eye is pulled back.
#
# `add` AT 0.13 IS SET AGAINST A CELL'S INRADIUS AND NOT BY EYE. A cell here
# runs about 0.14..0.30 of inradius, so `gap` going from 0.052 to 0.182 at the
# centre kills all but the largest panes there and leaves solid lead, while the
# half-strength 0.065 at the midpoint merely thickens a came.
EYE_RING = dict(x=0.318, y=-0.889, z=0.364, r0=0.15, r1=0.32, add=0.13)


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
    """The window as one material. Built twice -- once for the body and once
    for the trim -- and DELIBERATELY NOT SHARED between them.

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
    link = nt.links.new

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

    def rng(x, y, label, lo, hi, out_lo, out_hi,
            interp='SMOOTHSTEP', clamp=True):
        n = node("ShaderNodeMapRange", x, y, label)
        n.interpolation_type = interp
        n.clamp = clamp
        n.inputs['From Min'].default_value = lo
        n.inputs['From Max'].default_value = hi
        n.inputs['To Min'].default_value = out_lo
        n.inputs['To Max'].default_value = out_hi
        return n

    def snoise(x, y, label, scale, offset, detail=2.0, spread=0.15):
        """A noise CENTRED ON ZERO and stretched so that +-1 is an ordinary
        excursion rather than an extreme one.

        Blender's noise Factor is bunched hard around 0.5 -- most of its mass
        sits inside 0.35..0.65 -- so the obvious `(fac - 0.5) * amount` needs an
        `amount` of about six before anything reaches the ends, and by then the
        rare tail is enormous. Stretching a narrow window to -1..1 with the
        clamp OFF gives a value whose typical range is about +-1 and whose tails
        still run past it.

        SAMPLED AT AN OFFSET POSITION, because two noises at the same place
        with different scales are still correlated -- their large features line
        up -- so the came's waver and its cut edge would happen in the same
        places and the whole window would read as one repeating motif.
        """
        off = node("ShaderNodeVectorMath", x - 220, y, "offset")
        off.operation = 'ADD'
        off.inputs[1].default_value = offset
        n = node("ShaderNodeTexNoise", x, y, label)
        n.noise_dimensions = '3D'
        n.inputs['Scale'].default_value = scale
        n.inputs['Detail'].default_value = detail
        n.inputs['Roughness'].default_value = 0.55
        link(off.outputs['Vector'], n.inputs['Vector'])
        s = rng(x + 200, y, "centre and stretch",
                0.5 - spread, 0.5 + spread, -1.0, 1.0,
                interp='LINEAR', clamp=False)
        link(n.outputs['Fac'], s.inputs['Value'])
        return off, s

    # ---- where am I on the pig ---------------------------------------
    co = node("ShaderNodeTexCoord", -2600, 0, "the pig's own frame")
    sep = node("ShaderNodeSeparateXYZ", -2400, 0, "x across / y nose-tail / z up")
    link(co.outputs['Object'], sep.inputs['Vector'])
    X, Y, Z = sep.outputs['X'], sep.outputs['Y'], sep.outputs['Z']

    # ---- the cell field ----------------------------------------------
    # `DISTANCE_TO_EDGE` IS THE WHOLE PATTERN AND IT IS ONE NODE. It returns
    # how far this point is from the nearest wall between two cells, in cell
    # units -- so thresholding it draws every cell shrunk back inside its own
    # boundary, and what is left between them is the came.
    #
    # THE SCALE IS A CONSTANT HERE, WHICH IS ONE FEWER NODE THAN THE GIRAFFE
    # HAS AND IS THE SAME DECISION AS DROPPING THE MUZZLE. That skin drives
    # `Scale` off `y` so the cells get finer toward the nose, because a
    # giraffe's face genuinely carries smaller patches than its flank. A window
    # has no face. Varying the scale also costs something real -- a Voronoi
    # with a varying scale has STRETCHED cells wherever the gradient is -- and
    # a stretched pane in a leaded window reads as a mistake where a stretched
    # patch on an animal reads as an animal.
    edge_v = node("ShaderNodeTexVoronoi", -2200, -200, "distance to the came")
    if hasattr(edge_v, "voronoi_dimensions"):
        edge_v.voronoi_dimensions = '3D'
    edge_v.feature = 'DISTANCE_TO_EDGE'
    edge_v.inputs['Scale'].default_value = PANES['scale']
    edge_v.inputs['Randomness'].default_value = PANES['randomness']
    link(co.outputs['Object'], edge_v.inputs['Vector'])
    edge = edge_v.outputs['Distance']

    # A SECOND VORONOI ON THE SAME LATTICE, for the per-cell random number.
    # `DISTANCE_TO_EDGE` has no `Color` output, and the per-cell seed is the
    # only source of variation here that does NOT vary smoothly across the
    # surface -- which makes it the only thing that can give a whole PANE one
    # colour. Same scale and same randomness, so it walks the same cells: the
    # lattice is a function of those two and the input vector, and all three
    # are shared. The moment they disagree about any of the three, the colour
    # stops belonging to the pane it is filling and the seams show as ghosts.
    cell_v = node("ShaderNodeTexVoronoi", -2200, -560, "which pane is this")
    if hasattr(cell_v, "voronoi_dimensions"):
        cell_v.voronoi_dimensions = '3D'
    cell_v.feature = 'F1'
    cell_v.distance = 'EUCLIDEAN'
    cell_v.inputs['Scale'].default_value = PANES['scale']
    cell_v.inputs['Randomness'].default_value = PANES['randomness']
    link(co.outputs['Object'], cell_v.inputs['Vector'])
    cellsep = node("ShaderNodeSeparateXYZ", -2000, -560, "per-pane random")
    link(cell_v.outputs['Color'], cellsep.inputs['Vector'])
    # ONE CHANNEL, NOT THE COLOUR. Voronoi's `Color` is three independent
    # random numbers per cell; taking X gives one uniform 0..1 per pane, which
    # is what a palette index wants. Using the colour itself would hand every
    # pane a random RGB -- a confetti pig, and a different colour for every
    # single cell, which is the opposite of a six-entry palette.
    cell = cellsep.outputs['X']
    # AND Y IS A SECOND, INDEPENDENT ROLL FOR THE SAME PANE. See `HIGHLIGHT`.
    cell_y = cellsep.outputs['Y']

    # ---- how wide the came is here -----------------------------------
    # EVERYTHING FROM HERE ADDS TO ONE NUMBER, in cell units. That is the whole
    # architecture inherited from the giraffe: there is no second mask
    # anywhere, so a pane cannot be killed by one rule and drawn by another.
    cellg = rng(-2000, -760, "this pane's own came", 0.0, 1.0,
                PANES['gap'] - PANES['cell_vary'],
                PANES['gap'] + PANES['cell_vary'], interp='LINEAR')
    link(cell, cellg.inputs['Value'])

    wb_off, wb = snoise(-2200, -1000, "CAME WAVER",
                        PANES['wobble_scale'], (11.0, 4.0, -7.0))
    link(co.outputs['Object'], wb_off.inputs[0])
    wb_s = math('MULTIPLY', -1700, -1000, "waver amount",
                b=PANES['wobble'])
    link(wb.outputs['Result'], wb_s.inputs[0])

    gr_off, gr = snoise(-2200, -1300, "CUT EDGE",
                        PANES['grain_scale'], (-6.0, 13.0, 5.0), detail=3.0)
    link(co.outputs['Object'], gr_off.inputs[0])
    gr_s = math('MULTIPLY', -1700, -1300, "cut amount",
                b=PANES['grain'])
    link(gr.outputs['Result'], gr_s.inputs[0])

    g1 = math('ADD', -1500, -880, "+ waver")
    link(cellg.outputs['Result'], g1.inputs[0])
    link(wb_s.outputs[0], g1.inputs[1])
    g2 = math('ADD', -1320, -900, "+ cut")
    link(g1.outputs[0], g2.inputs[0])
    link(gr_s.outputs[0], g2.inputs[1])

    # ---- the lead collar round each eye ------------------------------
    # Mirrored on |x| so one number serves both eyes.
    ax = math('ABSOLUTE', -2600, 1300, "mirror onto one eye")
    link(X, ax.inputs[0])
    here = node("ShaderNodeCombineXYZ", -2420, 1300, "this point")
    link(ax.outputs[0], here.inputs['X'])
    link(Y, here.inputs['Y'])
    link(Z, here.inputs['Z'])
    dv = node("ShaderNodeVectorMath", -2240, 1300, "offset from the eye")
    dv.operation = 'SUBTRACT'
    dv.inputs[1].default_value = (EYE_RING['x'], EYE_RING['y'], EYE_RING['z'])
    link(here.outputs['Vector'], dv.inputs[0])
    dl = node("ShaderNodeVectorMath", -2060, 1300, "how far")
    dl.operation = 'LENGTH'
    link(dv.outputs['Vector'], dl.inputs[0])
    eyes = rng(-1880, 1300, "lead collar",
               EYE_RING['r0'], EYE_RING['r1'], EYE_RING['add'], 0.0)
    link(dl.outputs['Value'], eyes.inputs['Value'])

    # ---- the giraffe's anatomy, off by default -----------------------
    # See `ANATOMY`. FOLDED IN WITH MAXIMUM AND NOT SUMMED, which is the
    # giraffe's own call and matters more here: the chin is muzzle AND
    # underside, and adding the two there would open a hole in the window twice
    # as wide as either rule asked for.
    kill = eyes.outputs['Result']
    if ANATOMY['on']:
        muz = rng(-2200, 480, "wider toward the nose", ANATOMY['muzzle_lo'],
                  ANATOMY['muzzle_hi'], ANATOMY['muzzle_add'], 0.0)
        link(Y, muz.inputs['Value'])
        sox = rng(-2200, 300, "wider toward the paw", ANATOMY['socks_lo'],
                  ANATOMY['socks_hi'], ANATOMY['socks_add'], 0.0)
        link(Z, sox.inputs['Value'])
        lift = math('MULTIPLY_ADD', -2400, 900, "z + tilt*y",
                    b=ANATOMY['belly_tilt'])
        link(Y, lift.inputs[0])
        link(Z, lift.inputs[2])
        bel = rng(-2200, 900, "under the belly",
                  ANATOMY['belly_lo'], ANATOMY['belly_hi'], 1.0, 0.0)
        link(lift.outputs[0], bel.inputs['Value'])
        legs = rng(-2200, 700, "but not the legs", ANATOMY['belly_leg_lo'],
                   ANATOMY['belly_leg_hi'], 0.0, 1.0)
        link(Z, legs.inputs['Value'])
        bl = math('MULTIPLY', -1980, 820, "belly mask")
        link(bel.outputs['Result'], bl.inputs[0])
        link(legs.outputs['Result'], bl.inputs[1])
        und = math('MULTIPLY', -1800, 820, "and under the belly",
                   b=ANATOMY['belly_add'])
        link(bl.outputs[0], und.inputs[0])
        k1 = math('MAXIMUM', -1700, 400, "")
        link(muz.outputs['Result'], k1.inputs[0])
        link(sox.outputs['Result'], k1.inputs[1])
        k2 = math('MAXIMUM', -1560, 250, "")
        link(k1.outputs[0], k2.inputs[0])
        link(und.outputs[0], k2.inputs[1])
        k3 = math('MAXIMUM', -1420, 400, "WHERE THE WINDOW STOPS")
        link(k2.outputs[0], k3.inputs[0])
        link(kill, k3.inputs[1])
        kill = k3.outputs[0]

    gap = math('ADD', -1140, -880, "CAME HERE")
    link(g2.outputs[0], gap.inputs[0])
    link(kill, gap.inputs[1])

    # ---- inside a pane? ----------------------------------------------
    # A THRESHOLD AND NOT A RAMP. The bake runs at 2048 and delivers at 1024,
    # so every delivered texel is the average of four and the downscale is what
    # does the anti-aliasing -- a soft edge in the graph on top of that is
    # mush. See `WORKFLOW.md`.
    pane = math('GREATER_THAN', -940, -880, "far enough from the came?")
    link(edge, pane.inputs[0])
    link(gap.outputs[0], pane.inputs[1])

    # ---- the snout pad -----------------------------------------------
    pad = rng(-2200, 1100, "the snout disc", NOSE['lo'], NOSE['hi'], 1.0, 0.0)
    link(Y, pad.inputs['Value'])

    # ---- NOTHING FADES ------------------------------------------------
    # EVERY FACTOR THAT REACHES A COLOUR PASSES THROUGH HERE, AND THAT IS A
    # STRUCTURAL RULE RATHER THAN A TIDY-UP. A `Mix` factor of 0.4 does not
    # draw less of something -- it draws a colour that was never authored,
    # 40% of the way between two that were. On a cartoon skin that reads as an
    # airbrush. See `NO_FADING` above and `WORKFLOW.md`.
    def hard(sock, x, y, what):
        n = math('GREATER_THAN', x, y, "%s: one colour or the other" % what,
                 b=0.5)
        link(sock, n.inputs[0])
        return n.outputs[0]

    def above(sock, t, x, y, what):
        """Is this pane's random above `t`? A hard 0/1.

        `hard` thresholds at 0.5 and the palette needs four cuts at 0.2, 0.4,
        0.6 and 0.8, so the comparison is made here and then passed through
        `hard` anyway. THAT SECOND NODE IS A PROVABLE NO-OP -- its input is
        already exactly 0.0 or 1.0 -- and it is wired in on purpose: the rule
        in `WORKFLOW.md` is that NO mix factor is fed from anything but `hard`,
        and a rule with an exception in it is a rule the next skin will read as
        optional. It costs four nodes in a graph of ninety.
        """
        n = math('GREATER_THAN', x, y, what, b=t)
        link(sock, n.inputs[0])
        return hard(n.outputs[0], x + 160, y, what)

    # ---- six glasses off one random ----------------------------------
    # A LADDER OF COMPARISONS, NOT A RAMP, AND THE DIFFERENCE IS THE WHOLE
    # NO-FADING RULE. The obvious node for "pick one of six by a number" is a
    # ColorRamp with six stops and CONSTANT interpolation, which would in fact
    # be hard-edged -- and it is refused anyway, for two reasons that are worth
    # writing down because it is genuinely the tidier construction:
    #
    #   * A ColorRamp's interpolation is a property on a node rather than a
    #     structure in the graph, so the guarantee lives in one enum somebody
    #     can flip. `hard` at every factor is checkable by reading the links.
    #   * `look/check_fade.py` derives its palette from the baked sheet, and a
    #     ramp left on the default LINEAR would come back as six broad
    #     gradients that the erosion cannot tell from a fade. That is a failure
    #     the ladder cannot express at all.
    #
    # The cell random is uniform on 0..1, so `n-1` evenly spaced cuts give `n`
    # equally likely glasses. Equal weights on purpose: a window with one
    # dominant colour and five accents is a different design, and the one thing
    # this skin has to do from the pavement is read as MANY colours.
    # THE LADDER IS GENERIC OVER `len(JEWELS)`, so adding or removing a glass
    # is a line in the list above and nothing here -- which is how the opal
    # went in and out twice while it was being decided.
    #
    # AND IT IS BUILT TWICE OFF ONE SET OF FACTORS, WHICH IS WHAT MAKES THE
    # PAINTED HIGHLIGHT COST ALMOST NOTHING. The shine is a SECOND COLOUR for
    # every glass rather than a lightening of the first (see `HIGHLIGHT`), so
    # there are two chains -- the glass and its own highlight -- selected
    # between at the very end by one mask. The `above(...)` outputs are shared,
    # so the two chains cannot land on different glasses: they are the same
    # comparison read twice, not two comparisons that agree today.
    n_j = len(JEWELS)
    dark = light = None
    for i in range(1, n_j):
        t = float(i) / n_j
        pick = above(cell, t, -700, 200 - 170 * i, "pane >%.3f" % t)
        for tag, pal, prev, dy in (("glass", JEWELS, dark, 0),
                                   ("shine", [lighter(c) for c in JEWELS],
                                    light, -1300)):
            m, f, a, b, o = mix_rgb(nt, "-> %s %d" % (tag, i))
            m.location = (-300 + 220 * i, 200 - 170 * i + dy)
            if prev is None:
                a.default_value = to_linear(pal[0]) + (1.0,)
            else:
                link(prev, a)
            b.default_value = to_linear(pal[i]) + (1.0,)
            link(pick, f)
            if tag == "glass":
                dark = o
            else:
                light = o

    # ---- the snout is rose glass -------------------------------------
    # LAID ON THE PANE COLOUR AND NOT ON TOP OF THE LEAD, which is the ordering
    # that turns a pink sticker into a little rose window. The came is drawn
    # after this, so it runs straight across the pad exactly as it runs across
    # the flank -- and the shine runs over it too, which is why the pad is
    # applied to BOTH chains rather than after they are joined.
    padf = hard(pad.outputs['Result'], 260, 700, "the snout pad")
    m_pad, f_pad, a_pad, b_pad, o_pad = mix_rgb(nt, "rose glass on the snout")
    m_pad.location = (500, 500)
    b_pad.default_value = to_linear(ROSE) + (1.0,)
    link(padf, f_pad)
    link(dark, a_pad)
    # THE SNOUT IS THE ONE GLASS WITH NO SECOND DENSITY, and it is worth a
    # paragraph because the reason is half taste and half a measurement.
    #
    # The taste half: the pad is a FEATURE rather than a field, and a snout
    # made of two shades of rose reads as a snout somebody could not decide
    # about. Every other glass on the animal varies; this one is one colour and
    # a lead network, which is what makes it a little rose window.
    #
    # The measured half: `look/check_fade.py` derives its palette from the
    # sheet as every colour holding at least 0.4% of it, and the pale rose
    # measured **0.398%** on the trim sheet -- two thousandths of a per cent
    # under the floor. Below it, a perfectly flat authored colour is counted
    # off-palette, and because it IS flat it survives the 5x5 erosion and is
    # reported as a FADE. The trim sheet failed at 0.30% on exactly this and
    # nothing was wrong with it.
    #
    # THAT IS A LIMIT OF THE CHECK RATHER THAN A FAULT IN THE SKIN, and it is
    # the thing to know before adding a twelfth colour to anything: a check
    # that derives its own palette cannot tell a RARE authored flat colour from
    # a gradient, so a colour worth having has to be worth at least half a per
    # cent of a sheet. Dropping this one takes the rose to about 1.5%.
    m_padl, f_padl, a_padl, b_padl, o_padl = mix_rgb(nt, "the snout, again")
    m_padl.location = (500, -800)
    b_padl.default_value = to_linear(ROSE) + (1.0,)
    link(padf, f_padl)
    link(light, a_padl)

    # ---- some panes are a lighter glass than others -------------------
    # A SECOND PER-PANE RANDOM, off the SAME Voronoi. `Color` is three
    # independent random numbers per cell and the ladder above spends the X
    # channel on WHICH glass; Y is free and decides HOW DENSE that glass is.
    # So a pane is one of twelve authored colours -- six glasses at two
    # densities -- and it is still exactly ONE flat colour, which is what a
    # highlight painted INSIDE a pane could never be.
    tone = above(cell_y, HIGHLIGHT['pale'], -1300, 1700, "a paler cut?")
    m_sh, f_sh, a_sh, b_sh, o_sh = mix_rgb(nt, "THE SHINE")
    m_sh.location = (760, 400)
    link(o_pad, a_sh)
    link(o_padl, b_sh)
    link(tone, f_sh)

    # ---- and the came, over everything -------------------------------
    # THE LEAD IS DRAWN LAST, WHICH IS THE ONE STRUCTURAL INVERSION OF THE
    # GIRAFFE AND IS WHAT MAKES THIS A WINDOW. On that skin the lanes are the
    # BACKGROUND, so a patch that fails leaves tan and two neighbouring patches
    # of the same colour are indistinguishable from one bigger patch. Here the
    # came is a POSITIVE OBJECT: two adjacent panes that both roll ruby still
    # read as two panes, because there is a black line between them that was
    # painted after both.
    #
    # `pane` is 1 inside a pane and 0 on the came, so the factor is its
    # complement -- one SUBTRACT rather than an inverted threshold, because a
    # `LESS_THAN` here would have to duplicate the `gap` comparison and two
    # copies of one number is the thing this project keeps paying for.
    inv = math('SUBTRACT', 700, 100, "on the came?", a=1.0)
    link(pane.outputs[0], inv.inputs[1])
    m_lead, f_lead, a_lead, b_lead, o_lead = mix_rgb(nt, "LEADING")
    m_lead.location = (900, 400)
    b_lead.default_value = to_linear(LEAD) + (1.0,)
    link(hard(inv.outputs[0], 700, 300, "the leading"), f_lead)
    link(o_sh, a_lead)

    # ---- which texels the engine gets to animate ----------------------
    # `ALPHA_MASK` IS THE PIPELINE'S OWN CONTRACT AND IT IS OPT-IN BY LABEL.
    # `make/bake_alpha.py` looks for a node with this label, bakes its first
    # output, and `make/apply_alpha.py` merges the result into the sheet's
    # ALPHA. 1 means OPAQUE -- the baked picture wins and the texel is static;
    # 0 hands the texel to the part's own `Color`, which `ClientMain`'s skin
    # animator rewrites every Heartbeat. It is the only per-texel switch a
    # `SurfaceAppearance` has, because it carries no emissive channel and no
    # animate flag.
    #
    # THE CLEAR GLASS MOVES AND THE JEWELS HOLD, which is the one arrangement
    # that is about this skin rather than about the mechanism. A real window's
    # coloured pieces are their colour; it is the CLEAR and opal glass that
    # takes on whatever light is behind it and changes through the day. So the
    # opal -- one of the six, both densities of it -- is handed to the animator
    # and everything else is painted. About an eighth of the coat.
    #
    # THE LEAD IS NEVER TRANSPARENT, AND THAT IS THE HALF THAT MUST NOT MOVE.
    # It is the one thing carrying the object's identity from the pavement: a
    # came network that changed colour with the light would stop reading as
    # metal and the whole thing would read as a lava lamp. `pane` is 0 on the
    # came, and it is a factor here, so the came is opaque by construction
    # rather than by a rule anybody keeps.
    #
    # WHAT THIS COSTS THE CONFIG ROW, STATED HERE BECAUSE NOTHING ELSE WILL SAY
    # IT. Under `AlphaMode.Overlay` a transparent texel shows `part.Color`, so
    # `Config.SKINS.stainedglass.body` -- which a full-colour sheet otherwise
    # renders inert -- IS what the clear panes show when no `anim` is set. It
    # wants to be a pale opal near (232, 238, 240), which is the value baked
    # into those same panes, so the un-animated fallback is the picture in the
    # renders rather than a pig with a dozen randomly-coloured holes in it.
    #
    # AND THE SNOUT IS EXCLUDED, because the pad OVERRIDES the pane colour and
    # the alpha mask does not know that -- an opal-indexed pane that happens to
    # land on the snout is painted rose and would still have been handed to the
    # animator, so the pig would get one flickering nostril. One multiply.
    opal = above(cell, float(len(JEWELS) - 1) / len(JEWELS), 700, -1700,
                 "clear glass?")
    notpad = math('SUBTRACT', 700, -1900, "not the snout", a=1.0)
    link(padf, notpad.inputs[1])
    liv1 = math('MULTIPLY', 900, -1700, "clear glass in a pane")
    link(pane.outputs[0], liv1.inputs[0])
    link(opal, liv1.inputs[1])
    liv2 = math('MULTIPLY', 1060, -1800, "and not on the snout")
    link(liv1.outputs[0], liv2.inputs[0])
    link(notpad.outputs[0], liv2.inputs[1])
    amask = math('SUBTRACT', 1220, -1700, "", a=1.0)
    link(liv2.outputs[0], amask.inputs[1])
    # THE LABEL IS THE INTERFACE AND NOTHING CHECKS THE SPELLING. A typo here
    # does not error: `bake_alpha.py` finds no mask, bakes fully opaque, says
    # so, and the skin ships static with nothing wrong anywhere. Same family as
    # `"LockLevel"` in `Config.luau` -- a name with no compiler behind it.
    amask.label = "ALPHA_MASK"

    bsdf = node("ShaderNodeBsdfPrincipled", 1200, 400)
    bsdf.inputs['Roughness'].default_value = 0.88
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.08
    link(o_lead, bsdf.inputs['Base Color'])
    out = node("ShaderNodeOutputMaterial", 1520, 400)
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

body_mat = coat("stainedglass_body")
trim_mat = coat("stainedglass_trim")
ear_mat = flat("stainedglass_ear_inner", EAR_PINK)

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
assign(bpy, ASSIGN, "STAINED GLASS  (from %s)" % SRC)

for _n, _c in face_slots(bpy, [n for n, _ in ASSIGN]):
    if len(_c) > 1:
        print("  %-6s faces per slot %s  <- hand selection, intact"
              % (_n, _c))

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("")
print("  saved %s -- %s is untouched"
      % (os.path.relpath(OUT, D), os.path.relpath(SRC, D)))
print("  about %d panes across the body, came %.3f of a pane wide,"
      " %d jewels + lead + rose"
      % (round(PANES['scale'] * 2.0), PANES['gap'] * 2.0, len(JEWELS)))
