# -*- coding: utf-8 -*-
"""Build the Leopard's coat, in its own blend file.

    blender.exe --background --python make_leopard_blend.py

Writes `skins/leopard/leopard.blend`. Then the ordinary loop:

    blender.exe --background --python make/bake_skin.py       -- --skin leopard
    blender.exe --background --python make/make_view_blend.py -- --skin leopard --render

THIS FILE IS NUMBERS AND NOTHING ELSE NOW, AND THAT IS THE SECOND SPOTTED CAT
PAYING FOR ITSELF. The graph it used to carry -- the Voronoi cell field, the
tangent-plane distance, the collapse of a ring into a solid spot, the width
cap, the freckles -- is `rosette.py` at the toolkit root, because the snow
leopard wants every line of it and two copies of three hundred and fifty lines
is the near-identical duplicate `CLAUDE.md` records over and over.

THE EXTRACTION WAS PROVED RATHER THAN READ. `WORKFLOW.md`'s own rule: bake it
and diff the maps, because the bee's node dumps were identical while its trim
map differed by 23,174 texels. Both sheets came back byte-identical by md5.

WHAT A LEOPARD IS, AS A THING TO BUILD, AND WHY IT IS NOT THE TIGER WITH
DIFFERENT NUMBERS. A tiger's stripe is a GLOBAL field -- rings about the
nose-tail axis -- so one phase expression covers the whole animal and every
stripe is a slice of the same wave. A rosette is LOCAL: each one is an object
with a centre, a radius and a broken edge, and there are dozens of them
scattered over a sphere with no lattice anybody should be able to see. That is
a Voronoi cell field, one rosette per cell, and every dial below is about what
happens INSIDE a cell rather than about a wave. `rosette.py`'s header is the
rest of that argument.

A ROSETTE IS A BROKEN RING WITH A FILL IN IT, WHICH IS THREE COLOURS AND NOT
TWO. The petals are near-black brown, the centre is a mid brown, and the coat
is tawny -- and it is the CENTRE that says leopard rather than dalmatian. Drop
it and the same graph draws a cheetah, which is a real skin this catalogue may
want later and is one number away (`fill_over` below).

THE FLANK GETS ROSETTES AND THE HEAD, LEGS AND BELLY GET SOLID SPOTS, which is
what a real leopard does and is also the one thing that stops the coat reading
as wallpaper. It is ONE mask -- `solidity` -- and it works by collapsing the
ring radius to zero: `abs(d - 0) < w` is `d < w`, a disc.

THE COORDINATE FRAME IS THE PIG'S OWN, measured off the mesh rather than
assumed. Every part sits at identity, so object space IS world space and all
five parts share one frame -- which is what lets a rosette run off the flank
onto a leg with no seam:

    x   across          body reaches +-1.000
    y   NOSE to TAIL    snout tip -1.381, body -1.080..1.052, tail tip 1.465
    z   floor to CROWN  legs -1.020, body -0.960..0.960, ear tip 1.309

So -Y is the face and +Z is up.
"""

# --- find the toolkit, wherever this script has been filed ------------------
# Walks up from this file until it finds the folder holding `paths.py`. Depth
# independent on purpose: a script in `make/` and a script in `skins/leopard/`
# are two and three levels down, and a hardcoded `..` is a thing that breaks
# silently the first time anything is refiled.
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

import paths     # noqa: E402 -- the one place that knows the layout
import rosette   # noqa: E402 -- the spotted cat, shared with the snow leopard
import bpy, sys  # noqa: E402


argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SRC = arg("--blend", paths.PARTS)
OUT = arg("--out", paths.skin_blend("leopard"))

# --------------------------------------------------------------- the colours
# THE TWO THAT EXIST IN CONFIG ARE READ OFF IT rather than picked, for the
# reason `skin_colours.py` exists: a sheet used to JUDGE a pattern showing
# colours the game does not ship is invisible, because a slightly wrong tan
# looks exactly like a tan.
#
# The rest are what a full-colour bake BUYS and what it costs. `Config.SKINS`
# has a `body` and a `trim` and nowhere to put a fourth or fifth, which is
# precisely the point of a full-colour sheet -- and precisely why changing one
# of these is a re-bake rather than a line of Luau.
TAWNY = (232 / 255., 186 / 255., 110 / 255.)    # Config body
# CONFIG'S `trim` IS THE ROSETTE CENTRE, WHICH IS A REPURPOSING AND IS SAID SO
# OUT LOUD. Under the mask pack it dressed the snout, ears, legs and tail as a
# darker brown; a full-colour sheet paints those from the same field the body
# uses, so a leopard's leg is tawny with spots on it and that colour has no
# other home. It happens to be exactly the mid brown a rosette centre wants.
FILL = (128 / 255., 86 / 255., 44 / 255.)       # Config trim
# A WARM DARK BROWN, NOT BLACK, for the same reason the tiger's ink is: black
# on tan is a dalmatian's contrast, and the brown keeps the coat reading as fur
# under a warm sun.
INK = (52 / 255., 38 / 255., 26 / 255.)
# The underside. A leopard is white underneath and it is the single biggest
# thing stopping an all-over print reading as upholstery.
CREAM = (250 / 255., 243 / 255., 230 / 255.)
# The two places a pig shows skin rather than fur.
EAR_PINK = (247 / 255., 201 / 255., 180 / 255.)
# NOTHING ON THIS ANIMAL FADES INTO ANYTHING ELSE, and it is `rosette.py` that
# enforces it rather than this file: every factor reaching a colour mix in the
# shared graph passes through one threshold, so a texel is one of the colours
# named below and never a blend of two. `WORKFLOW.md`, "Nothing fades".
#
# It is declared here anyway so that the audit line in `WORKFLOW.md` covers
# every skin rather than every skin that happens to own its own graph.
NO_FADING = True

NOSE_PINK = (232 / 255., 162 / 255., 152 / 255.)

# --------------------------------------------------------------- the tunables
# EVERY NUMBER THAT DECIDES WHAT THE COAT LOOKS LIKE IS IN THESE DICTS, so a
# note like "too many spots" is a one-line edit and a two-second re-run.
SPOTS = dict(
    # HOW MANY. Cells per stud, so the body's 2.0 studs across carries about
    # `2*scale` of them. Every radius below is in CELL units, so this dial
    # moves the count WITHOUT moving how big a rosette is relative to its
    # neighbours -- which is what makes it safe to turn on its own.
    scale=4.6,
    # HOW EVENLY THEY SIT, and it is a DENSITY dial rather than a tidiness one.
    # At `randomness` 1.0 a cell centre can land anywhere in its cell, so two
    # neighbours are sometimes 0.2 apart and sometimes 1.6 -- which caps how
    # big `r` can be before the close pairs collide into a web. Pulling it in
    # makes the spacing consistent, so the same `r` is safe at a larger value
    # and the coat can be DENSE. What normally argues against that is a visible
    # lattice, and there is none here: `size_vary`, `cell_vary`, `wobble` and
    # `vary` are four independent things making one rosette differ from its
    # neighbour, and the depth dropout below removes whole cells at random.
    randomness=0.78,
    # THE RING'S RADIUS, in cell units. Half a cell is the wall, so the outer
    # edge (`r + max_w*r`) wants to land near 0.5 for a coat where rosettes
    # nearly touch, and well under it for a sparse one.
    #
    # AND IT IS ALSO THE COVERAGE DIAL, WHICH IS NOT OBVIOUS AND IS THE ANSWER
    # TO "TOO SPARSE". The field is 3D and the pig is a shell through it, so a
    # cell only draws anything if its centre happens to lie within `r` of the
    # surface -- about `2r` of them do, and the rest are simply MISSING. At
    # 0.30 that is a third of the coat absent and reads as a spotty cow; at
    # 0.40 it is about a fifth, which is the natural-looking unevenness a real
    # coat has. Raising the COUNT does not fix sparsity, because the dropout is
    # a fraction rather than a number.
    r=0.34,
    # HOW THICK A PETAL IS, in cell units, before the variation below.
    w=0.100,
    # HOW MUCH THE RADIUS VARIES FROM PLACE TO PLACE, as a fraction. A slow
    # noise, so neighbouring rosettes differ in size and a whole region of the
    # flank can run large -- which is what a real coat does. CLAMPED, for the
    # reason under `max_w` below.
    size_vary=0.15, size_scale=1.6,
    # AND PER CELL, which is a different thing from per PLACE: this one is a
    # random number attached to the cell itself (`Voronoi -> Color`), so two
    # rosettes touching each other can still be different sizes. Without it the
    # size noise makes neighbours agree and the lattice starts to show.
    cell_vary=0.30,
    # THE RADIAL WOBBLE, which is what makes a rosette a hand-drawn thing
    # rather than a compass circle. A faster noise added to the radius, so the
    # ring bulges out on one side and in on the other. Relative to the radius,
    # so a small rosette wobbles proportionally. Clamped, same reason.
    wobble=0.30, wobble_scale=6.0,
    # THE BREAK-UP, AND IT IS THE MECHANISM RATHER THAN A FLOURISH. This is the
    # tiger's "vary the width until it goes negative" applied to a ring instead
    # of a stroke: where the width noise dips below zero the ring is CUT, so a
    # continuous annulus becomes three or four separate petals with tawny
    # between them. That is what a rosette actually is, and it is one number.
    #
    # WHERE ZERO IS DEPENDS ON HOW THE NOISE WAS PREPARED, and `WORKFLOW.md`
    # has just been corrected about that on the tiger's side: the tiger writes
    # `1 + (Fac - 0.5)*vary` against a `Fac` bounded to 0..1, so it bottoms out
    # at `1 - vary/2` and needs `vary` past 2 before a stroke ever ends. THAT
    # ARITHMETIC DOES NOT APPLY HERE. `snoise` below stretches a narrow window
    # of `Fac` to -1..1 with the clamp OFF, so its output runs to about +-3.3
    # with a standard deviation near 0.73 -- and `1 + vary*s` therefore crosses
    # zero at `vary` around 1.0 rather than 2.0. Read the helper, not the other
    # skin, before moving this.
    vary=1.75, vary_scale=9.0,
    # AND THE SAME UNBOUNDEDNESS AT THE OTHER END IS WHY THIS EXISTS. A width
    # that can reach three times nominal does not draw a thick ring, it draws a
    # DISC: the band `|d - r| < w` swallows its own hole the moment `w` reaches
    # `r`, and the first build of this had exactly that -- a flank of solid
    # brown splatters with a real rosette here and there, which read as MUD
    # rather than as markings.
    #
    # So the width is capped at a fraction of THIS rosette's own radius, which
    # makes an open ring a geometric guarantee rather than a tuning result. It
    # is the only cap in the file, and it is the right place for it: a radius
    # is what a rosette IS and is clamped everywhere, while the width is
    # deliberately allowed to run past zero and needs holding at one end only.
    max_w=0.38,
    # HOW FAR THE CENTRE FILL REACHES INTO THE PETAL BAND, in units of the
    # petal half-width. Positive tucks the fill UNDER the petals so no tawny
    # ring shows between the two; at -1.0 the fill stops at the petals' inner
    # edge and at about -1.6 it is gone entirely, which is a cheetah.
    fill_over=0.75,
    # A SOLID SPOT'S SIZE, as a multiple of the petal half-width. A collapsed
    # rosette draws a disc of radius `w`, which on its own is far smaller than
    # a real leopard's face and leg spots -- and smaller again now that `w` has
    # come down to keep the rings open.
    solid_gain=1.70,
    # AND SOME CELLS ARE SOLID WHEREVER THEY ARE. Every real coat has isolated
    # dots between the rosettes; without this the flank is a tidy field of one
    # motif. Cells whose own random number falls under `solid_lo` are fully
    # solid, and it fades to a rosette by `solid_hi`.
    solid_lo=0.16, solid_hi=0.30,
)

# A SECOND, FINER FIELD FOR THE FACE AND THE LEGS, AND IT IS THE ONE PLACE
# THIS FILE ADMITS A SECOND PATTERN. Everything else here is one Voronoi with
# a mask on it, deliberately -- see `solidity`. Freckles cannot be: a leopard's
# cheek carries a dozen small dots across the width of one flank rosette, and
# ONE cell field cannot be dense on the head and coarse on the flank at the
# same time, because `scale` is global. Shrinking the flank field's spots on
# the head was tried first and is what the render showed: the front third of
# the animal went BLANK, because there are only one or two cells across a
# cheek and making their dots smaller removed the last of them.
#
# It is solid dots and nothing else -- no ring, no centre, no wobble -- which
# is both what a leopard's face actually has and what keeps this cheap.
FRECKLES = dict(
    # A MULTIPLE OF THE ROSETTE SCALE rather than a number of its own, so
    # moving `SPOTS['scale']` carries the face with it. Getting that wrong is
    # how a coat ends up re-tuned everywhere except the one part nobody
    # re-renders.
    scale_mul=3.1,
    # The dot, in ITS OWN cell units -- which are 3.1 times smaller than the
    # rosette field's.
    r=0.34,
    # AND NOT EVERY CELL GETS ONE, which is the whole difference between
    # freckles and polka dots. Cells whose own random number falls under `lo`
    # draw a full dot and it fades to nothing by `hi`, so the spacing is
    # irregular and some patches of cheek stay clear.
    lo=0.40, hi=0.66,
)

# WHERE THE ROSETTES CLOSE UP INTO SOLID SPOTS. All three of these feed ONE
# `solidity` mask, and the mask collapses the ring rather than switching to a
# second pattern -- so a spot cannot be in two places at once.
HEAD = dict(lo=-1.10, hi=-0.78)     # 1 at the muzzle, 0 by the cheek
LEGS = dict(lo=-0.90, hi=-0.55)     # 1 at the paw, 0 at the belly line
# HOW SOLID THE UNDERSIDE IS. Not 1.0: the chest keeps half-open rosettes,
# which is what a real leopard has and what stops the boundary reading as a
# line where one pattern stops and another starts.
BELLY_SOLID = 0.85
# AND HOW MUCH SMALLER THE HEAD'S SPOTS ARE. A leopard's face is freckled
# rather than spotted; one Voronoi field cannot make them denser without making
# the flank's denser too, so what it can do is make them smaller.
HEAD_SHRINK = 0.30

BELLY = dict(
    # WHERE THE CREAM STARTS AND STOPS, in z. Smoothstepped rather than cut,
    # because a hard line between two flat colours across the widest part of a
    # sphere reads as a join in the model rather than as markings.
    #
    # LOWER THAN THE TIGER'S, AND THE TILT IS WHY RATHER THAN TASTE. The
    # boundary is `z + tilt*y` against these, so the height it lands at on the
    # FACE is `hi + tilt` -- at the tiger's 0.02 and 0.34 that is z 0.36, which
    # is the eye line. On a tiger that is right: the pale jaw runs up to the
    # cheek. Copied here it painted the whole muzzle and lower face white and
    # the pig read as wearing a bib.
    hi=-0.22, lo=-0.62,
    # THE TILT, which is what stops the cream being a bathtub ring. At the nose
    # the boundary sits `tilt` higher and at the tail `tilt` lower -- a pale
    # chin and chest running back to a tawny haunch, which is how the markings
    # actually sit.
    tilt=0.30,
    # THE LEGS COME BACK OUT OF IT. They hang entirely below the belly line, so
    # a mask that is purely "low is cream" paints four white posts. Fading the
    # cream out again below `leg_hi` gives legs that emerge pale from the chest
    # and darken to tawny at the paw.
    leg_lo=-0.80, leg_hi=-0.56,
)

# THE SNOUT DISC IS PINK, WHICH IS THE ONE PLACE THIS DELIBERATELY LEAVES THE
# ANIMAL AND STAYS WITH THE OBJECT. A leopard's muzzle is white with a dark
# nose; a piggy bank's snout is pink, and the reference this was cut against is
# a leopard-print PIG rather than a leopard. `lo` is where the pad is at full
# strength and `hi` is where it has faded out, so it is a disc on the end of
# the snout and not a painted band across the muzzle.
NOSE = dict(lo=-1.30, hi=-1.16)

# THE EYES ARE NOT CLEARED, WHICH REVERSES THE TIGER'S RULE AND `WORKFLOW.md`'S
# ITEM 6 FOR THIS SKIN ONLY. Both say to keep markings off the eyes, and the
# reason they give is exact: the eyes are code-built parts standing proud of
# the body at (+-0.318, -0.889, 0.364), so a marking running up to their rim
# reads as a SMEAR. That is a fact about a STRIPE -- a long stroke arriving at
# a black dome has nowhere to end, so it ends on the dome and the two merge.
#
# A SPOT DOES NOT SMEAR, BECAUSE IT ALREADY HAS AN END. A leopard's face is
# freckled right up to the eye and that is what the reference photograph shows.
# What the clearance actually drew here was a bare tawny HALO round each eye --
# a soft disc of nothing on the one part of the animal anybody looks at --
# because it was a smoothstepped fade rather than a hard edge, so it did not
# read as "no spot here", it read as the pattern being rubbed out.
#
# The nose pad below keeps its clearance, and the difference is worth stating:
# that one is not a hole in the pattern, it is a different COLOUR with its own
# boundary, so there is nothing for a spot to fade into.


# -------------------------------------------------------------- the driver
# ONE DICT, BECAUSE THE ENGINE TAKES ONE. Naming the pieces here rather than
# in `rosette.py` is what keeps a skin file readable as a skin: everything a
# person would want to change is above this line, and nothing below it is a
# decision about a leopard.
rosette.build(bpy, paths, "leopard", dict(
    coat=TAWNY, pale=CREAM, fill=FILL, ink=INK,
    ear=EAR_PINK, snout=NOSE_PINK,
    # NO `dorsal`. A leopard is one tawny from spine to flank; the snow
    # leopard is not, and that is the only structural difference between the
    # two skins. `rosette.py` builds no node at all when this is absent, which
    # is what let the extraction leave this skin's bake byte-identical.
    spots=SPOTS, freckles=FRECKLES,
    belly=BELLY, head=HEAD, legs=LEGS, nose=NOSE,
    belly_solid=BELLY_SOLID, head_shrink=HEAD_SHRINK,
), SRC, OUT)
