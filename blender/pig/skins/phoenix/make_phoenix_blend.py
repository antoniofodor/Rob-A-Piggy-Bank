# -*- coding: utf-8 -*-
"""Build PHOENIX as a node graph, in its own blend file.

    blender.exe --background --python skins/phoenix/make_phoenix_blend.py
    blender.exe --background --python make/bake_skin.py       -- --skin phoenix
    blender.exe --background --python make/bake_alpha.py      -- --skin phoenix
    python make/apply_alpha.py --skin phoenix
    blender.exe --background --python make/make_view_blend.py -- --skin phoenix --render

A LEGENDARY IN THE ANIMAL CRATE IS A CREATURE PLUS AN ELEMENT -- see
`docs/animal-crate-plan.md`. The creature here is a BIRD and the element is
FIRE, and the whole weight of the first half sits on one primitive nobody in
this pipeline had built: a field of overlapping rounded SCALLOPS. Stripes,
bands, cells and spots each already have a generator; feathers had none.

THE SCALLOP IS AN OVERLAP ORDERING, NOT A SHAPE, AND THAT IS THE FINDING.
Both of the obvious routes were tried and both draw the wrong object:

  * **`to_band`, the tiger's primitive.** It turns a phase into "how far from
    the nearest stroke centre", which is a distance to a LINE. Warping that
    line with a periodic term does give a wavy band, and a wavy band is not a
    scallop -- every feather shares one continuous boundary with the row
    behind it, so nothing overlaps anything and what comes back is corrugated
    iron. It also cannot stagger, because the row index that decides the
    stagger is itself computed from the warped phase, which is circular.
  * **`rosette.py`'s Voronoi.** Nearest-centre on a staggered lattice is
    exactly a hexagonal tiling: the boundary between two cells is the
    perpendicular bisector, which is STRAIGHT. Discs of overlapping radius do
    not help, because nearest-centre resolves every overlap back into that
    same straight bisector. Voronoi draws honeycomb, and honeycomb is another
    skin in the same plan.

**WHAT MAKES A SCALLOP IS THAT ONE FEATHER IS DRAWN ON TOP OF ANOTHER.** The
boundary you see is not shared -- it is the arc of the NEARER feather, drawn
over the one behind it, and the piece of the far one that survives is a
crescent. So the primitive is an ORDERED lattice of ellipses:

    rows      r = floor(V),  V a function of y     head to tail
    columns   staggered half a step on odd rows    round the body
    ellipse   d = |(du/ru, dv/rv)| about each lattice point, on where d < 1
    order     the SMALLER row wins -- head over tail, the way real
              contour feathers lie, and the way roof tiles shed water

and the only thing a shader has to answer is WHICH feather covers this point.

**THAT COSTS ONE DISTANCE FIELD RATHER THAN FOUR, WHICH WAS DERIVED RATHER
THAN HOPED FOR.** The naive version tests both candidate rows and takes the
smaller index that covers. Working the arithmetic through at `ru = 0.62` and
`rv = 0.75`, a point in the strip `V` in `[r, r+1)` that is NOT inside row r's
ellipse is always inside row r+1's -- the worst case is `d = 0.897` against
the 1.0 it has to beat, at the column centre, with margin everywhere else. And
row r-1 can never reach into the strip at all, since its own `dv` term alone
is at least `1/0.75 = 1.33`. So:

    inside the strip, the visible feather is r if d < 1, and r+1 otherwise

is not an approximation, it is the whole answer, and one `d` decides the
colour, the rim, the shadow and the row index together. That is magma's
architecture arriving on a new field: one number, three thresholds against
multiples of it, and no second mask anywhere that could disagree with the
first.

**THE THREE THRESHOLDS ARE THE PLUMAGE.** `d` is measured against a local
radius that two noises make ragged:

    d < rad - tip       the feather's own body, in its band colour
    d < rad             its TRAILING EDGE, one hot colour -- the animated bit
    d < rad + shadow    the SHADOW it throws on the feather behind it
    otherwise           that next feather's body

The shadow is the piece that makes it read as overlapping rather than as
tiling, and it is magma's char rim in a different coat: a band drawn OUTSIDE
the boundary, on the thing behind, because a crescent with no shadow along its
top edge is a shape rather than a layer.

**THE COLOUR RUNS IN FLAT BANDS AND IS INDEXED OFF THE ROW, NEVER OFF THE
POSITION.** `WORKFLOW.md`'s "Nothing fades" forbids a gradient outright, and a
gradient is also the wrong picture: a cartoon phoenix is a few flat plumage
colours, gold at the breast through orange to a deep crimson tail. Indexing
`floor` of the row into a `CONSTANT` ColorRamp -- the rainbow tiger's trick --
makes each FEATHER one flat colour, so a band boundary runs along a row of
feather edges instead of cutting through the middle of one.

THE COORDINATE FRAME IS THE PIG'S OWN, measured off the mesh rather than
assumed. Every part sits at identity, so object space IS world space and all
five parts share one frame -- which is what lets a feather row run off the
flank onto a leg with no seam:

    x   across          body reaches +-1.000
    y   NOSE to TAIL    snout tip -1.381, body -1.080..1.052, tail tip 1.465
    z   floor to CROWN  legs -1.020, body -0.960..0.960, ear tip 1.309

So -Y is the face and +Z is up. Columns are the angle about the Y axis
measured from +Z, which puts the wrap at the BELLY where nobody looks -- and
`cols` is an INTEGER for the tiger's reason, because the angle jumps a whole
turn at the wrap and only a whole number of columns makes that jump invisible
to `FRACT`.

THE RADIUS PROFILE IS WHY THE COLUMN COUNT IS FIXED AND THE ROW DENSITY IS
NOT. Measured off the mesh with `skins/phoenix/measure.py`, the radius about
the Y axis runs 0.28 at the muzzle, 0.45 at the brow, 1.00 at the barrel and
0.55 at the tail. A fixed column count therefore NARROWS a feather wherever
the animal is thin, for free and correctly -- small dense plumage on the head,
broad feathers on the flank -- which is half of what a phoenix wants. The
other half is `rows_a`, whose CUBIC keeps a feather about as tall as it is
wide at both ends of an animal that is thin at both ends; and where the
radius runs out altogether, `POLES` opens the arcs into rings rather than
letting twenty columns crowd into a point.

**THE ANIMATED REGION IS THE FEATHER TIPS, AND IT IS ONE COLOUR BY
CONSTRUCTION.** `AlphaMode.Overlay` hands every alpha-0 texel the SAME
`Color3`, so a multi-colour region does not animate, it collapses -- see the
`ALPHA_MASK` node for the whole argument. The five bands and their five
shadows are what this skin IS and stay baked; `TIP` appears on every feather
and nowhere else, so handing it over costs nothing and lights the trailing
edge of every feather on the bird together. `skins/phoenix/preview_anim.py`
renders that cycle without publishing anything.

Two more scripts live beside this one. `measure.py` prints the radius profile
the lattice is fitted against; `strip.py` lays the four renders out at about
what a piggy subtends across a street, because a skin is read from the
pavement and judged in a 700-pixel render and those are different questions.
"""

# --- find the toolkit, wherever this script has been filed ------------------
# Walks up from this file until it finds the folder holding `paths.py`. Depth
# independent on purpose: a script in `make/` and a script in `skins/phoenix/`
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
D = _root

import paths   # noqa: E402 -- the one place that knows the layout
import bpy, os, sys, math

from skin_colours import to_linear   # noqa: E402
from skin_parts import assign, face_slots   # noqa: E402


argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SRC = arg("--blend", paths.PARTS)
OUT = arg("--out", paths.skin_blend("phoenix"))

# --------------------------------------------------------------- the colours
def _c(r, g, b):
    """0..255, the way a person reads a colour off a picker, into the 0..1
    tuple `to_linear` actually wants.

    **THE TOOLKIT'S CONVERTER TAKES 0..1 AND DOES NOT SAY SO, AND HANDING IT
    0..255 FAILS SILENTLY AND SPECTACULARLY.** Every other skin here writes
    `(238 / 255., 132 / 255., 36 / 255.)` inline, so the division is invisible
    and easy to leave out -- which is what happened on the first build of this
    file. `to_linear` raised its argument through the sRGB transfer function
    without complaint and handed back ramp stops in the HUNDREDS OF THOUSANDS,
    every one of them far out of gamut. Nothing errored, the bake ran, and what
    came back was a WHITE PIG with faint ripples on it, which reads exactly
    like a broken shader rather than like a units mistake.

    It was found by dumping the ColorRamp stops rather than by looking at the
    picture, because a white pig looks the same however it got that way. One
    function, one division, thirteen call sites that cannot each forget it.
    """
    return (r / 255.0, g / 255.0, b / 255.0)


# NOTHING HERE IS READ OUT OF `Config.luau`. `skin_colours.skin()` exists so a
# generator and the game cannot disagree about a `body`/`trim` pair, and there
# is no `phoenix` row to disagree with yet. When one is written it should take
# BANDS[0] and BANDS[-1], which are the two a two-colour fallback would want.
#
# A full-colour sheet invents the rest and cannot express them in Config at
# all: at `AlphaMode.Overlay` and alpha 255 the map replaces the part colour
# outright, so every colour below is a re-bake rather than a line of Luau.

# THE FIVE PLUMAGE BANDS, head to tail. Warm the whole way and never through
# brown: each step is a step round the hue wheel and DOWN in value at the same
# time, so the bird darkens toward the tail whichever way the light happens to
# be falling on it -- which is what keeps the ladder legible from the pavement
# rather than only in a hero shot.
BANDS = [
    _c(255, 198, 62),     # 0  breast, head and snout -- gold
    _c(247, 150, 30),     # 1  the shoulder
    _c(233, 96, 26),      # 2  the barrel -- orange
    _c(198, 52, 34),      # 3  the haunch
    _c(142, 24, 48),      # 4  rump and tail -- deep crimson
]
# THE SHADOW EACH BAND THROWS, and it is a SECOND TABLE rather than one shared
# dark. A single maroon under every feather is the obvious build and it reads
# as SOOT on the gold half of the bird: the breast is the brightest thing on
# the animal, and a near-black arc under each feather there says the plumage is
# dirty rather than that it is layered. Shading each band with its own darker
# tone keeps the shadow inside the same hue family, so what it says is DEPTH.
#
# Each is its band pushed down in value and up in saturation -- never toward
# grey, which is what would make a warm coat look wet.
BAND_SHADOW = [
    _c(202, 130, 28),
    _c(186, 96, 20),
    _c(162, 56, 18),
    _c(128, 28, 26),
    _c(84, 14, 36),
]
# THE TRAILING EDGE OF EVERY FEATHER, AND THE ONE REGION HANDED TO THE GAME.
# See `ALPHA_MASK` below. It is a hot pale gold rather than white for the
# reason `CLAUDE.md` records four separate times about pale Neon on a
# twelve-stud sphere: white blows out and takes its neighbours with it, and a
# colour with a hue left in it still reads as light.
TIP = _c(255, 234, 152)
# THE MUZZLE CAP. A phoenix is a bird and the front of the snout is the closest
# thing it has to a BEAK, so it gets brass rather than the pink pad every
# mammal in this catalogue wears. It is also load-bearing rather than
# decorative: columns are an angle about the Y axis, so on the frontmost cap of
# the snout -- measured, the radius about that axis falls to about 0.13 there
# -- they converge into a pinwheel of hairline wedges. The pad covers exactly
# the ground where the coordinate system gives up.
BEAK = _c(212, 132, 28)
# THE INNER EAR, which on this animal is the one place you see INTO it. Pitched
# hotter than any band, so it reads as a glimpse of the fire rather than as
# more plumage.
EAR_INNER = _c(250, 138, 62)

# --------------------------------------------------------------- the tunables
# EVERY NUMBER THAT DECIDES WHAT THE PLUMAGE LOOKS LIKE IS IN THIS ONE DICT, so
# a note like "the feathers are too small" is a one-line edit and a two-second
# re-run.
FEATHERS = dict(
    # HOW MANY FEATHERS ROUND THE BODY. **AN INTEGER, AND IT HAS TO BE.** The
    # column coordinate is `atan2(x, z)`, which jumps a whole turn at the
    # belly; a whole number of columns makes that jump exactly `cols` periods,
    # which `FRACT` cannot see. A fractional count draws a seam from the nose
    # to the tail.
    #
    # It also sets a feather's WIDTH everywhere at once, because that width is
    # `2*pi*r/cols` and `r` is a fact about the animal rather than a dial. At
    # 20 that is 0.31 studs on the barrel and 0.14 on the brow.
    cols=20,
    # THE ROW DENSITY, AS A CUBIC -- `V = a*y + b*y*y + c*y*y*y`, whose SLOPE
    # `a + 2*b*y + 3*c*y*y` is rows per stud at that point. `a` is the density
    # at the middle of the animal and the other two bend it.
    #
    # **IT IS A CUBIC BECAUSE THE ANIMAL IS THIN AT BOTH ENDS, AND THE FIRST
    # BUILD SHIPPED A QUADRATIC BECAUSE THE BRIEF SAYS "SMALL AND DENSE AT THE
    # HEAD, LARGER TOWARD THE HAUNCH".** That brief is right about the head and
    # says nothing about the tail, and a monotone ramp reads it as an
    # instruction to keep growing all the way to the tail tip. A quadratic's
    # slope is a straight line, so it can only be dense at ONE end.
    #
    # The radius profile is what refutes it. A fixed column count means a
    # feather's WIDTH is `2*pi*r/cols`, and `r` collapses at the rump exactly
    # as it does at the muzzle -- so a row height that goes on growing back
    # there makes a feather THREE AND A HALF TIMES taller than it is wide.
    # Measured on the shipped quadratic: aspect 0.87 at the barrel and 3.90 at
    # y 1.02. Rendered, that is not plumage, it is a row of gothic arches, and
    # from the spine view it read as a zigzag rather than as scallops.
    #
    # A cubic's slope is a PARABOLA, so it can be dense at the muzzle, open out
    # over the barrel and close up again over the rump -- which is the shape of
    # `1/r`. Measured on the shipped numbers, the aspect runs 1.99 / 0.87 /
    # 1.37 / 1.06 at the brow, the barrel, the haunch and the tail tip, against
    # the quadratic's 2.19 / 0.87 / 2.22 / 3.16. `skins/phoenix/measure.py`
    # prints the radius the fit is against.
    #
    # **IT WAS FITTED TO HOLD THE BARREL WHERE IT ALREADY WAS**, which is the
    # half worth copying. The first cubic aimed for one aspect everywhere and
    # got it -- and it CHANGED the middle of the animal, which was the part
    # nobody had complained about: the barrel went from 0.87 to 1.15, the
    # scallops there went from broad to upright, and the crown view lost the
    # plumage read it had. A repair that moves the thing it was not called
    # about is a regression wearing a fix. The shipped fit pins y=0 at the old
    # 3.80 rows per stud and only lifts the two ends.
    #
    # **THE SLOPE MUST NOT GO THROUGH ZERO ANYWHERE ON THE ANIMAL**, or rows
    # fold back on themselves and the lattice runs backwards. It bottoms out
    # at 3.75 near y 0.20 on the shipped numbers, and the driver at the foot of
    # this file SWEEPS for that rather than trusting it -- which is the one
    # thing to read after turning any of the three.
    rows_a=3.80, rows_b=-0.2428, rows_c=0.4048,
    # THE FEATHER ELLIPSE, in lattice units -- half-width in columns and
    # half-height in rows. Both are over 0.5, which is what makes the discs
    # OVERLAP and therefore what makes this a scallop field rather than a
    # tiling.
    #
    # THE PAIR IS CONSTRAINED RATHER THAN CHOSEN. `rv` sets how far a feather
    # bulges past its own row: at 0.75 the arc runs from 44% of the way down
    # the row at a feather's corners to 75% at its centre, which is a deep and
    # obviously rounded scallop. `ru` decides whether row r+1 can be relied on
    # to cover everything row r does not -- see the header -- and at 0.62 the
    # worst uncovered point measures 0.897 against the 1.0 it has to beat.
    ru=0.62, rv=0.75,
    # THE BRIGHT TRAILING EDGE, in `d` units. **IT HAS A CEILING AND THE
    # CEILING IS ARITHMETIC**: at the TOP corners of a row `d` bottoms out at
    # `0.5/ru = 0.806`, so a tip band reaching below that paints bright wedges
    # at the three-feather junctions as well as along the arc where it belongs.
    # Anything under 0.19 is safe; 0.15 leaves real margin for the noise on
    # `rad`.
    #
    # IT CAME DOWN FROM 0.15 BECAUSE THE BIRD WAS READING AS AN ARTICHOKE. At
    # that width every feather on the animal wore a pale outline of its own,
    # and a field of outlined shapes is a pine cone rather than plumage -- the
    # cusps between feathers in particular got a bright V drawn into them from
    # both sides and became the loudest thing on the rump. Narrow enough to
    # read as light ALONG an edge rather than as a line drawn round a shape.
    tip=0.13,
    # THE SHADOW IT THROWS ON THE FEATHER BEHIND. Drawn OUTSIDE the arc, which
    # is magma's char rim: the thing that says the crescent is UNDER something
    # rather than beside it. It went UP as the tip came down, because what
    # separates one feather from the next then reads as depth rather than as
    # ink.
    shadow=0.20,
    # THE WANDER. One low-frequency noise warping the row coordinate and
    # another warping the column coordinate, so the rows are not perfect rings
    # and the columns are not perfect meridians. A DOMAIN warp rather than a
    # mask: every feather stays a whole feather and the lattice stays
    # consistent, it simply bends.
    wander=0.17, wander_scale=1.4,
    # SOME FEATHERS ARE BIGGER THAN OTHERS. A mid-frequency noise on the
    # radius, at about the scale of a few feathers, so a patch of plumage
    # crowds and the next patch opens out.
    swell=0.070, swell_scale=3.4,
    # AND THE ARC IS NOT A CLEAN CIRCLE. A fast noise at the scale of the edge
    # itself. Small on purpose: enough that no feather is a drawn ellipse, not
    # so much that the silhouette of one turns to gravel.
    ragged=0.045, ragged_scale=11.0,
    # THE FLOOR UNDER `rad`, and it is the same argument as magma's
    # `GAP_FLOOR`. A radius the noise has driven near zero is a feather thinner
    # than a delivered texel, and the 2048-to-1024 downscale averages that into
    # a smear -- which is the fading fault `WORKFLOW.md` forbids, arriving
    # through the back door as a WIDTH rather than as a soft mask.
    rad_floor=0.55,
)

# WHICH BAND A ROW IS IN. The row index is compared against this range and cut
# into `len(BANDS)` equal pieces, so these two numbers decide where on the
# ANIMAL each colour lands.
#
# THEY ARE ROW NUMBERS AND NOT STUDS, WHICH IS THE WHOLE POINT: a band boundary
# then falls between two rows of feathers rather than through the middle of
# one, so every feather is one flat colour by construction.
#
# ANYTHING OUTSIDE THE RANGE TAKES THE END COLOUR, because a ColorRamp clamps
# its own Fac. That is deliberate rather than tolerated: the muzzle runs back
# to row -6.5 and the tail tip out to +4.2, and both should be the end of the
# ladder rather than starting it over. The driver at the bottom of this file
# PRINTS where each boundary lands in y, because the three `rows_` terms and
# this pair all move it and a number in a comment is the thing that goes stale.
BAND_RANGE = dict(lo=-5.32, hi=4.28)

# THE POLES, WHERE THE COLUMN COORDINATE GIVES UP -- AND THE FEATHERS CLOSE
# INTO RINGS THERE RATHER THAN BEING PAINTED OVER.
#
# Columns are an angle about the Y axis, so wherever the surface passes near
# that axis the circumference goes to nothing while the column COUNT does not:
# twenty feathers crowd into a point and what renders is a PINWHEEL of
# hairlines. The body is an ellipsoid, so it has such a place -- its rear pole
# at about y 1.03, sitting on the rump in plain view from behind and from
# above -- and the snout's frontmost disc is another. The first build put a fan
# of fine streaks on both and it read as the texture tearing.
#
# **THE COLUMN COUNT CANNOT BE DROPPED, WHICH IS WHY THIS MOVES THE ELLIPSE
# INSTEAD.** `cols` has to be an integer for the wrap at the belly to be
# invisible to `FRACT`, so there is no continuous way to spend fewer columns
# near a pole.
#
# TWO REPAIRS WERE BUILT BEFORE THIS ONE AND BOTH ARE WORSE, so both are
# recorded:
#
#   1. **A FLAT CAP** -- suppress the tip and the shadow inside a radius and
#      let the band colour stand, which is exactly what the eye patch does.
#      It works and it costs a bald disc: at the radius that actually swallows
#      the spikes it is a plain crimson patch a full stud across on the rump,
#      which reads as the pattern giving up rather than as anything a bird has.
#   2. **THE SAME CAP, GATED TO THE REAR**, because an ungated one flattened
#      the whole front of the muzzle as well -- the snout's frontmost band has
#      a median radius of 0.28, so it is inside any cap big enough to be worth
#      having. That fixed the face and left the bald disc.
#
# WHAT ACTUALLY WORKS IS MEASURING THE FEATHER'S WIDTH IN ARC RATHER THAN IN
# ANGLE, which is the tiger's `even` finding arriving on a different
# primitive. Scaling the ACROSS term by how far this point is from the axis
# makes the ellipse angularly wider wherever the animal is thin -- so the arc
# between two feathers flattens, the cusps open out, and at the pole itself the
# across term reaches zero and the field becomes `d = down/rv` exactly. That is
# a set of CONCENTRIC RINGS, with the tip highlight riding them: tail coverts
# at the rump and a muzzle whose plumage converges on the beak, which is what
# a bird's face actually does.
#
# It is safe rather than merely nice. The lattice is untouched -- rows and
# columns still have the same indices, so nothing tears -- and the coverage
# argument in the header only gets EASIER, because a wider ellipse means a
# smaller `0.5/ru` and that term is the whole of what has to be beaten.
#
# `merge` is the radius below which the arcs start opening out, and the animal
# is what sets it: the barrel measures 0.96 so anything at or under that leaves
# the flank alone, and the number then only decides how hard the two ends are
# pulled. It was 0.55 for one build and left a torn-looking ring at the tail
# base -- arcs half opened, cusps still in them, and the ragged noise working
# on a feather too small to carry it. At 0.95 that ring is clean and the UPPER
# rump flattens with it, which costs the one part of the back that was already
# right. 0.82 is where the tail base closes into a single sweeping arc and the
# rump does not move: the radius there is 0.70 to 0.85, which this barely
# touches.
POLES = dict(merge=0.82)

# AND THAT IS WHY THERE IS NO RADIAL FACE FAN ON THIS ANIMAL, WHICH WAS ASKED
# FOR AND IS THE RIGHT ANSWER FOR A DIFFERENT PATTERN.
#
# The tiger carries one, and its own header says exactly what it is for: rings
# about the nose-tail axis "do not stop at the head -- they go on ringing, and
# on a snout that is a dark hoop AROUND THE NOSTRILS and bars across the
# muzzle." That is a real failure and the fan is a real fix for it.
#
# **IT IS A FAILURE OF STRIPES, NOT OF THE COORDINATE SYSTEM.** A stripe drawn
# on a ring IS the ring, so a ring across a muzzle is a bar. A SCALLOP drawn on
# a ring is a row of small feathers, and a row of small feathers across a
# muzzle is what a bird's face has. Checked by looking rather than by
# reasoning: the low camera shows the muzzle wearing fine plumage converging on
# the beak, with no bar anywhere on it.
#
# The merge above then gives the face the fan's own TOPOLOGY for free -- as the
# radius runs out toward the muzzle the arcs open into rings centred on the
# beak -- so what the fan was wanted for arrives out of a correction that is
# already there for the rump. Building it properly would mean a second lattice
# about a second pole and a switch between them, which is the one thing this
# file has been able to avoid: there is ONE field here, and every mark on the
# animal comes off one distance.

# THE MUZZLE CAP -- see `BEAK`. `lo` is where the pad is at full strength and
# `hi` is where it is gone; the pair straddles the nostrils, which sit at
# y -1.250..-1.201.
NOSE = dict(lo=-1.28, hi=-1.16)

# THE EYES, CLEARED RATHER THAN NARROWED, and this is the one place this skin
# deliberately does the opposite of the tiger.
#
# `CLAUDE.md` records that a hard mask ON THE INK cut every tiger stroke at one
# radius and drew a visible CIRCLE -- a stencil rather than a marking -- and
# that moving it onto the WIDTH fixed it, because every stroke then ends at its
# own radius and the endpoints scatter. That fix does not transfer: a feather
# has no width to taper, and shrinking the ellipse near an eye changes WHICH
# feather covers a point, which tears the lattice.
#
# What it gets instead is the circle, ON PURPOSE. Suppressing only the tip and
# the shadow leaves the band colour standing, so what appears round the eye is
# a small patch of FLAT plumage colour -- and a bare ring of skin round the eye
# is a thing real birds have. It is drawn as a feature rather than tolerated as
# a cut, which is the only honest way to take the mask this primitive allows.
EYES = dict(x=0.318, y=-0.889, z=0.364, r0=0.185, r1=0.245)

# NOTHING ON THIS ANIMAL FADES INTO ANYTHING ELSE.
#
# The theme is CARTOON, so every texel is one of the thirteen colours named
# above and never a blend of two. That is enforced at the graph's output rather
# than asked of each mask: every factor reaching a colour mix goes through
# `hard`, so a soft mask anywhere upstream moves an EDGE rather than smearing
# one.
#
# IT IS THE RULE THAT DECIDED THE COLOUR SCHEME AND NOT ONLY THE GRAPH. The
# obvious way to paint a firebird is a gradient from gold to crimson down the
# body, and that is precisely what is forbidden -- so the gradient is
# QUANTISED into five flat bands indexed off the feather's own row, which is
# what a hand-painted cartoon phoenix does anyway.
NO_FADING = True


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
    """The plumage as one material. Built twice -- once for the body and once
    for the trim -- and DELIBERATELY NOT SHARED between them.

    `bake_skin.py` walks each object's material slots and points every material
    at the group's bake image, so a material worn by both the body and the trim
    would have its image node repointed by the second bake and the first sheet
    would come back blank. Two datablocks with one graph is the cheap way to
    keep those two bakes independent; the graph is generated, so they cannot
    drift.
    """
    F = FEATHERS
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

    def math_node(op, x, y, label="", a=None, b=None, c=None):
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
        excursion rather than an extreme one. Magma's helper, unchanged.

        Blender's noise Factor is bunched hard around 0.5 -- most of its mass
        sits inside 0.35..0.65 -- so the obvious `(fac - 0.5) * amount` needs an
        `amount` of about six before anything reaches the ends, and by then the
        rare tail is enormous.

        SAMPLED AT AN OFFSET POSITION, because two noises at the same place
        with different scales are still correlated -- their large features line
        up -- so the row wander and the ragged edge would happen in the same
        places and the plumage would read as one repeating motif.
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

    def constant_ramp(x, y, label, table, fac_sock):
        """A TABLE OF AUTHORED COLOURS, INDEXED -- never a gradient.

        `CONSTANT` interpolation is the whole of what makes it a table: the
        ramp hands back the stop at or below its Fac and nothing in between, so
        every texel it produces is one of the colours written above. See
        `NO_FADING`.

        A new ramp arrives with two stops and the first cannot be removed, so
        the existing pair is reused and the rest appended: building by `new()`
        alone leaves a stray black stop at 0 that reads as a dark sliver on one
        band and looks like a rendering artefact.
        """
        r = node("ShaderNodeValToRGB", x, y, label)
        r.color_ramp.color_mode = 'RGB'
        r.color_ramp.interpolation = 'CONSTANT'
        els = r.color_ramp.elements
        while len(els) > len(table):
            els.remove(els[-1])
        while len(els) < len(table):
            els.new(1.0)
        for i, (e, rgb) in enumerate(zip(els, table)):
            e.position = float(i) / len(table)
            e.color = to_linear(rgb) + (1.0,)
        link(fac_sock, r.inputs['Fac'])
        return r

    # ---- where am I on the pig ---------------------------------------
    co = node("ShaderNodeTexCoord", -3000, 0, "the pig's own frame")
    sep = node("ShaderNodeSeparateXYZ", -2820, 0,
               "x across / y nose-tail / z up")
    link(co.outputs['Object'], sep.inputs['Vector'])
    X, Y, Z = sep.outputs['X'], sep.outputs['Y'], sep.outputs['Z']

    # ---- the wander, which bends the whole lattice --------------------
    # TWO SAMPLES OF ONE NOISE AT DIFFERENT PLACES, warping the row coordinate
    # and the column coordinate independently. A domain warp rather than a
    # mask: every feather stays a whole feather and the lattice stays
    # consistent, it simply stops being a grid.
    wv_off, wv = snoise(-2620, 900, "ROW WANDER",
                        F['wander_scale'], (0.0, 0.0, 0.0))
    link(co.outputs['Object'], wv_off.inputs[0])
    wv_s = math_node('MULTIPLY', -2180, 900, "row wander amount",
                     b=F['wander'])
    link(wv.outputs['Result'], wv_s.inputs[0])

    wu_off, wu = snoise(-2620, 620, "COLUMN WANDER",
                        F['wander_scale'], (23.0, -9.0, 5.0))
    link(co.outputs['Object'], wu_off.inputs[0])
    wu_s = math_node('MULTIPLY', -2180, 620, "column wander amount",
                     b=F['wander'])
    link(wu.outputs['Result'], wu_s.inputs[0])

    # ---- the ROW coordinate: V = a*y + b*y*y + c*y*y*y ----------------
    # THE CUBIC IS THE DENSITY RAMP AND NOT A CURVE FOR ITS OWN SAKE. What a
    # row coordinate has to deliver is a SLOPE -- rows per stud -- and this is
    # the cheapest field whose slope is a PARABOLA, which is what it takes to
    # be dense at the muzzle, open out over the barrel and close up again over
    # the rump. See `rows_a`.
    y2 = math_node('MULTIPLY', -2620, 300, "y squared")
    link(Y, y2.inputs[0])
    link(Y, y2.inputs[1])
    y3 = math_node('MULTIPLY', -2620, 140, "y cubed")
    link(y2.outputs[0], y3.inputs[0])
    link(Y, y3.inputs[1])
    va = math_node('MULTIPLY', -2440, 420, "rows, at the middle",
                   b=F['rows_a'])
    link(Y, va.inputs[0])
    vb = math_node('MULTIPLY', -2440, 280, "opening out over the barrel",
                   b=F['rows_b'])
    link(y2.outputs[0], vb.inputs[0])
    vc = math_node('MULTIPLY', -2440, 140, "and closing up at both ends",
                   b=F['rows_c'])
    link(y3.outputs[0], vc.inputs[0])
    v0 = math_node('ADD', -2260, 340, "")
    link(va.outputs[0], v0.inputs[0])
    link(vb.outputs[0], v0.inputs[1])
    v1 = math_node('ADD', -2120, 260, "")
    link(v0.outputs[0], v1.inputs[0])
    link(vc.outputs[0], v1.inputs[1])
    V = math_node('ADD', -2000, 300, "ROW COORDINATE")
    link(v1.outputs[0], V.inputs[0])
    link(wv_s.outputs[0], V.inputs[1])

    row = math_node('FLOOR', -1820, 400, "WHICH ROW OF FEATHERS")
    link(V.outputs[0], row.inputs[0])
    down = math_node('FRACT', -1820, 240, "how far down it")
    link(V.outputs[0], down.inputs[0])

    # THE STAGGER, AND IT IS THE DIFFERENCE BETWEEN PLUMAGE AND FISH SCALES.
    # Rows offset half a column alternately, so a feather sits over the JOIN
    # between the two behind it rather than squarely over one of them. Without
    # it the field is a grid, and a grid of rounded cells is scale mail --
    # which is a different animal and a worse one.
    #
    # `FRACT(row/2)` is 0 on even rows and 0.5 on odd ones, and Blender's
    # `FRACT` is `x - floor(x)`, so it is a true modulo and gives the right
    # answer on the negative row numbers the head end produces.
    half = math_node('MULTIPLY', -1640, 480, "half the row number", b=0.5)
    link(row.outputs[0], half.inputs[0])
    stag = math_node('FRACT', -1460, 480,
                     "STAGGER: every other row, half a step")
    link(half.outputs[0], stag.inputs[0])

    # ---- the COLUMN coordinate: the way round the body ----------------
    # MEASURED FROM +Z, so the wrap lands at the BELLY. `atan2` jumps a whole
    # turn somewhere; putting that somewhere under the animal costs nothing,
    # and an integer `cols` makes the jump exactly `cols` periods -- which
    # `FRACT` cannot see, so there is no seam even there.
    phi = math_node('ARCTAN2', -2620, 0, "WAY ROUND THE BODY (radians)")
    link(X, phi.inputs[0])
    link(Z, phi.inputs[1])
    u0 = math_node('MULTIPLY', -2440, 0, "into columns",
                   b=F['cols'] / (2.0 * math.pi))
    link(phi.outputs[0], u0.inputs[0])
    U = math_node('ADD', -2260, 0, "COLUMN COORDINATE")
    link(u0.outputs[0], U.inputs[0])
    link(wu_s.outputs[0], U.inputs[1])

    us = math_node('SUBTRACT', -1820, 0, "this row's own stagger")
    link(U.outputs[0], us.inputs[0])
    link(stag.outputs[0], us.inputs[1])
    uf = math_node('FRACT', -1640, 0, "one column")
    link(us.outputs[0], uf.inputs[0])
    across = math_node('SUBTRACT', -1460, 0,
                       "offset from the nearest feather", b=0.5)
    link(uf.outputs[0], across.inputs[0])

    # ---- how far into a feather this point is -------------------------
    # ONE ELLIPTICAL DISTANCE, AND IT DECIDES EVERYTHING. The colour, the
    # trailing edge, the shadow and which row this texel belongs to all come
    # off this number -- which is the giraffe's and magma's architecture, where
    # having one field and one threshold is what stops a mark being drawn by
    # one rule and erased by another.
    # HOW FAR OFF THE BODY'S OWN AXIS, which is the radius the column
    # coordinate is an angle about -- see `POLES`. It is the one number that
    # says whether twenty columns have any room to be twenty columns.
    flat_pt = node("ShaderNodeCombineXYZ", -1820, 260, "x and z only")
    link(X, flat_pt.inputs['X'])
    link(Z, flat_pt.inputs['Z'])
    axis_r = node("ShaderNodeVectorMath", -1640, 260, "how far off the axis")
    axis_r.operation = 'LENGTH'
    link(flat_pt.outputs['Vector'], axis_r.inputs[0])
    merge = math_node('MINIMUM', -1460, 260,
                      "the arcs open out toward a pole", b=1.0)
    m0 = math_node('MULTIPLY', -1620, 160, "in units of the merge radius",
                   b=1.0 / POLES['merge'])
    link(axis_r.outputs['Value'], m0.inputs[0])
    link(m0.outputs[0], merge.inputs[0])

    ax0 = math_node('MULTIPLY', -1280, 200, "across, in feather widths",
                    b=1.0 / F['ru'])
    link(across.outputs[0], ax0.inputs[0])
    ax = math_node('MULTIPLY', -1280, 90, "...measured in ARC near a pole")
    link(ax0.outputs[0], ax.inputs[0])
    link(merge.outputs[0], ax.inputs[1])
    ax2 = math_node('MULTIPLY', -1100, 90, "")
    link(ax.outputs[0], ax2.inputs[0])
    link(ax.outputs[0], ax2.inputs[1])
    bz = math_node('MULTIPLY', -1280, -80, "down, in feather heights",
                   b=1.0 / F['rv'])
    link(down.outputs[0], bz.inputs[0])
    bz2 = math_node('MULTIPLY', -1100, -80, "")
    link(bz.outputs[0], bz2.inputs[0])
    link(bz.outputs[0], bz2.inputs[1])
    dsq = math_node('ADD', -920, 0, "")
    link(ax2.outputs[0], dsq.inputs[0])
    link(bz2.outputs[0], dsq.inputs[1])
    dist = math_node('SQRT', -760, 0, "HOW FAR INTO THIS FEATHER")
    link(dsq.outputs[0], dist.inputs[0])

    # ---- and how big this feather is, here ----------------------------
    # TWO NOISES ON ONE RADIUS. The slow one makes a patch of plumage crowd
    # while the next opens out; the fast one keeps the arc from being a drawn
    # ellipse. Both move the SAME number, so the tip and the shadow inherit
    # every bit of it without one extra node -- which is why they cannot drift
    # away from the edge they belong to.
    sw_off, sw = snoise(-2620, -400, "SOME FEATHERS ARE BIGGER",
                        F['swell_scale'], (11.0, 4.0, -7.0))
    link(co.outputs['Object'], sw_off.inputs[0])
    sw_s = math_node('MULTIPLY', -2180, -400, "swell amount", b=F['swell'])
    link(sw.outputs['Result'], sw_s.inputs[0])

    rg_off, rg = snoise(-2620, -700, "RAGGED EDGE",
                        F['ragged_scale'], (-6.0, 13.0, 5.0), detail=3.0)
    link(co.outputs['Object'], rg_off.inputs[0])
    rg_s = math_node('MULTIPLY', -2180, -700, "ragged amount", b=F['ragged'])
    link(rg.outputs['Result'], rg_s.inputs[0])

    r1 = math_node('ADD', -1980, -520, "1 + swell", a=1.0)
    link(sw_s.outputs[0], r1.inputs[1])
    r2 = math_node('ADD', -1800, -560, "+ ragged")
    link(r1.outputs[0], r2.inputs[0])
    link(rg_s.outputs[0], r2.inputs[1])
    rad = math_node('MAXIMUM', -1620, -560, "never thinner than a texel",
                    b=F['rad_floor'])
    link(r2.outputs[0], rad.inputs[0])

    tip_in = math_node('SUBTRACT', -1440, -440,
                       "where the bright edge starts", b=F['tip'])
    link(rad.outputs[0], tip_in.inputs[0])
    sh_out = math_node('ADD', -1440, -680, "how far the shadow reaches",
                       b=F['shadow'])
    link(rad.outputs[0], sh_out.inputs[0])

    # ---- the three thresholds -----------------------------------------
    # THRESHOLDS AND NOT RAMPS. The bake runs at 2048 and delivers at 1024, so
    # every delivered texel is the average of four and the downscale is what
    # does the anti-aliasing -- a soft edge in the graph on top of that is
    # mush. See `WORKFLOW.md`.
    inner = math_node('LESS_THAN', -580, 240, "inside the feather's body?")
    link(dist.outputs[0], inner.inputs[0])
    link(tip_in.outputs[0], inner.inputs[1])
    on = math_node('LESS_THAN', -580, 60, "on this feather at all?")
    link(dist.outputs[0], on.inputs[0])
    link(rad.outputs[0], on.inputs[1])
    near = math_node('LESS_THAN', -580, -120, "in the shadow it throws?")
    link(dist.outputs[0], near.inputs[0])
    link(sh_out.outputs[0], near.inputs[1])

    # ---- WHOSE FEATHER IS THIS TEXEL ON --------------------------------
    # THE HEADER'S WHOLE CLAIM, IN TWO NODES. Inside the strip the visible
    # feather is `row` where the ellipse covers and `row + 1` everywhere else,
    # and the coverage argument in the header is what makes that exact rather
    # than approximate. One index then serves the band colour, the shadow
    # colour and the fallback -- so a shadow is drawn in the colours of the
    # feather it lands ON, which is the thing that makes it read as a shadow
    # rather than as an outline.
    rowp = math_node('ADD', -400, 400, "the row behind", b=1.0)
    link(row.outputs[0], rowp.inputs[0])
    which = math_node('SUBTRACT', -220, 400,
                      "WHICH ROW YOU ARE LOOKING AT")
    link(rowp.outputs[0], which.inputs[0])
    link(on.outputs[0], which.inputs[1])

    # ---- which colour band that row is in ------------------------------
    # **AIMED AT THE MIDDLE OF A BAND, WHICH KEEPS THE LOOKUP OFF THE STOP
    # BOUNDARIES.** A `CONSTANT` ramp hands back the stop at or below its
    # input, and `k/count` computed two different ways lands either side of the
    # stop at `k/count` depending on the last bit of a float. Aiming at
    # `(k + 0.5)/count` means no arithmetic error small enough to happen can
    # pick the wrong band. The rainbow tiger paid for this one.
    span = BAND_RANGE['hi'] - BAND_RANGE['lo']
    bsub = math_node('SUBTRACT', -40, 400, "rows above the first band",
                     b=BAND_RANGE['lo'])
    link(which.outputs[0], bsub.inputs[0])
    bmul = math_node('MULTIPLY', 140, 400, "into band numbers",
                     b=len(BANDS) / span)
    link(bsub.outputs[0], bmul.inputs[0])
    bidx = math_node('FLOOR', 320, 400, "WHICH BAND")
    link(bmul.outputs[0], bidx.inputs[0])
    bfac = math_node('MULTIPLY_ADD', 500, 400,
                     "into ramp space, aimed mid-band",
                     b=1.0 / len(BANDS), c=0.5 / len(BANDS))
    link(bidx.outputs[0], bfac.inputs[0])

    band = constant_ramp(700, 560, "THE PLUMAGE BANDS", BANDS,
                         bfac.outputs[0])
    shade = constant_ramp(700, 240, "AND EACH BAND'S OWN SHADOW",
                          BAND_SHADOW, bfac.outputs[0])

    # ---- the eye, and the muzzle cap -----------------------------------
    ax_ = math_node('ABSOLUTE', -3000, -1300, "mirror onto one eye")
    link(X, ax_.inputs[0])
    here = node("ShaderNodeCombineXYZ", -2820, -1300, "this point")
    link(ax_.outputs[0], here.inputs['X'])
    link(Y, here.inputs['Y'])
    link(Z, here.inputs['Z'])
    dv = node("ShaderNodeVectorMath", -2640, -1300, "offset from the eye")
    dv.operation = 'SUBTRACT'
    dv.inputs[1].default_value = (EYES['x'], EYES['y'], EYES['z'])
    link(here.outputs['Vector'], dv.inputs[0])
    dl = node("ShaderNodeVectorMath", -2460, -1300, "how far")
    dl.operation = 'LENGTH'
    link(dv.outputs['Vector'], dl.inputs[0])
    eye_ok = rng(-2280, -1300, "bare skin round the eye",
                 EYES['r0'], EYES['r1'], 0.0, 1.0)
    link(dl.outputs['Value'], eye_ok.inputs['Value'])

    nose = rng(-2280, -1520, "the muzzle cap", NOSE['lo'], NOSE['hi'],
               1.0, 0.0)
    link(Y, nose.inputs['Value'])



    # ---- NOTHING FADES -------------------------------------------------
    # EVERY FACTOR THAT REACHES A COLOUR PASSES THROUGH HERE, AND THAT IS A
    # STRUCTURAL RULE RATHER THAN A TIDY-UP. A `Mix` factor of 0.4 does not
    # draw less of something -- it draws a colour that was never authored, 40%
    # of the way between two that were. On a cartoon coat that reads as an
    # airbrush. See `NO_FADING` and `WORKFLOW.md`.
    def hard(sock, x, y, what):
        n = math_node('GREATER_THAN', x, y,
                      "%s: one colour or the other" % what, b=0.5)
        link(sock, n.inputs[0])
        return n.outputs[0]

    # THE TIP AND THE SHADOW ARE THE TWO THE EYE PATCH SUPPRESSES, and the
    # feather BODY is deliberately not one of them -- see `EYES`. Multiplying
    # a 0/1 mask by a smoothstep and thresholding the product at 0.5 puts the
    # cut exactly where the smoothstep crosses, which is the midpoint of `r0`
    # and `r1`.
    tip_raw = math_node('SUBTRACT', -400, 60,
                        "the trailing edge, and only it")
    link(on.outputs[0], tip_raw.inputs[0])
    link(inner.outputs[0], tip_raw.inputs[1])
    # THE EYE PATCH AND THE POLE CAP ARE ONE PRODUCT, because they are the same
    # instruction -- leave the band colour standing and draw no detail on it --
    # arriving from two different places. Multiplied together rather than
    # maximised, so either one alone is enough to clear a region.
    tip_m = math_node('MULTIPLY', -220, 60, "...but not round the eye")
    link(tip_raw.outputs[0], tip_m.inputs[0])
    link(eye_ok.outputs['Result'], tip_m.inputs[1])
    sh_m = math_node('MULTIPLY', -220, -120, "shadow, but not round the eye")
    link(near.outputs[0], sh_m.inputs[0])
    link(eye_ok.outputs['Result'], sh_m.inputs[1])

    tip_h = hard(tip_m.outputs[0], -40, 60, "the trailing edge")
    sh_h = hard(sh_m.outputs[0], -40, -120, "the shadow")
    in_h = hard(inner.outputs[0], -40, 240, "the feather body")
    nose_h = hard(nose.outputs['Result'], -2100, -1520, "the muzzle cap")

    # ---- WHICH TEXELS THE GAME GETS TO DRIVE ---------------------------
    # THE TRAILING EDGES, AND NOTHING ELSE. A node labelled `ALPHA_MASK` is the
    # one thing `make/bake_alpha.py` looks for: 1 where the baked picture
    # should win, 0 where the part's own `Color3` should come through -- and
    # `ClientMain`'s skin animator rewrites that colour every Heartbeat. It is
    # the only per-texel switch a `SurfaceAppearance` has, because
    # `AlphaMode.Overlay` computes `lerp(part.Color, map.RGB, map.Alpha)` and
    # there is no emissive channel and no "animate" flag anywhere in the
    # format.
    #
    # **THE REGION HANDED OVER HAS TO BE ONE COLOUR ALREADY, AND THAT IS WHAT
    # CHOSE IT.** Every alpha-0 texel gets the SAME `Color3`, because there is
    # one `Color` property per MeshPart -- so handing over a multi-colour
    # region does not animate its colours, it DELETES all but one of them.
    # `docs/animal-crate-plan.md` records what that costs: Rainbow Tiger's
    # stripes handed to the animator come back as a white pig with one
    # shimmering stripe set.
    #
    # The five plumage bands are therefore untouchable -- they ARE the skin --
    # and so are their five shadows. `TIP` is the one colour on this animal
    # that appears on every feather and nowhere else, so handing it over costs
    # nothing and buys the whole trait: the trailing edge of every feather on
    # the bird lights together, ember to white-hot, while the plumage under it
    # holds. That is a firebird catching light rather than a pig changing
    # colour, and the difference is that the bands stay put.
    #
    # THE MUZZLE CAP IS TAKEN BACK OUT because it is painted OVER the tip in
    # the chain below -- so those texels show brass, and an alpha of 0 under
    # brass would hand a beak to the animator with nothing on screen to say why
    # it was flickering.
    not_nose = math_node('SUBTRACT', -1920, -1520, "everywhere but the cap",
                         a=1.0)
    link(nose_h, not_nose.inputs[1])
    anim = math_node('MULTIPLY', -1740, -1440, "the animated region")
    link(tip_h, anim.inputs[0])
    link(not_nose.outputs[0], anim.inputs[1])
    alpha_mask = math_node('SUBTRACT', -1560, -1440,
                           "OPAQUE EVERYWHERE BUT THE TRAILING EDGES", a=1.0)
    alpha_mask.label = "ALPHA_MASK"
    link(anim.outputs[0], alpha_mask.inputs[1])

    # ---- the colours, laid from the back of the bird forward -----------
    # FOUR MIXES, NESTED. Each region is a SUBSET of the one before it -- the
    # shadow contains the feather, the feather contains its body -- so laying
    # them in order costs nothing and no mask has to know about another. It is
    # magma's plate-char-crack-core chain on a different field.
    #
    # The base is the band colour of whichever row this texel belongs to, which
    # for a point outside the near feather is the one BEHIND it. So the first
    # mix already draws the crescent correctly, and everything after it is the
    # near feather being laid on top.
    m1, f1, a1, b1, o1 = mix_rgb(nt, "the shadow one feather throws")
    m1.location = (960, 300)
    link(band.outputs['Color'], a1)
    link(shade.outputs['Color'], b1)
    link(sh_h, f1)

    m2, f2, a2, b2, o2 = mix_rgb(nt, "the trailing edge, lit")
    m2.location = (1140, 300)
    b2.default_value = to_linear(TIP) + (1.0,)
    link(o1, a2)
    link(tip_h, f2)

    m3, f3, a3, b3, o3 = mix_rgb(nt, "and the feather's own body")
    m3.location = (1320, 300)
    link(o2, a3)
    link(band.outputs['Color'], b3)
    link(in_h, f3)

    m4, f4, a4, b4, o4 = mix_rgb(nt, "the muzzle cap, over everything")
    m4.location = (1500, 300)
    b4.default_value = to_linear(BEAK) + (1.0,)
    link(o3, a4)
    link(nose_h, f4)

    bsdf = node("ShaderNodeBsdfPrincipled", 1700, 300)
    bsdf.inputs['Roughness'].default_value = 0.88
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.08
    link(o4, bsdf.inputs['Base Color'])
    out = node("ShaderNodeOutputMaterial", 2000, 300)
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

body_mat = coat("phoenix_body")
trim_mat = coat("phoenix_trim")
ear_mat = flat("phoenix_ear_inner", EAR_INNER)

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
assign(bpy, ASSIGN, "PHOENIX  (from %s)" % SRC)

for _n, _c in face_slots(bpy, [n for n, _ in ASSIGN]):
    if len(_c) > 1:
        print("  %-6s faces per slot %s  <- hand selection, intact"
              % (_n, _c))

bpy.ops.wm.save_as_mainfile(filepath=OUT)


def _rows(y):
    return (FEATHERS['rows_a'] * y + FEATHERS['rows_b'] * y * y
            + FEATHERS['rows_c'] * y * y * y)


def _slope(y):
    return (FEATHERS['rows_a'] + 2 * FEATHERS['rows_b'] * y
            + 3 * FEATHERS['rows_c'] * y * y)


print("")
print("  saved %s -- %s is untouched"
      % (os.path.relpath(OUT, D), os.path.relpath(SRC, D)))
print("  %d feathers round the body, %.1f rows nose to tail"
      % (FEATHERS['cols'], _rows(1.465) - _rows(-1.381)))
print("  rows per stud: %.2f at the muzzle, %.2f at the barrel, %.2f at the tail"
      % (_slope(-1.381), _slope(0.0), _slope(1.465)))
# THE SLOPE MAY NOT GO THROUGH ZERO -- see `rows_a`. Swept rather than solved,
# because the check has to survive somebody adding a fourth term.
_lo = min((_slope(-1.4 + 0.02 * _k), -1.4 + 0.02 * _k) for _k in range(146))
print("  slowest row density %.2f per stud, at y %+.2f%s"
      % (_lo[0], _lo[1], "" if _lo[0] > 0 else "   <-- ROWS FOLD BACK"))
# WHERE EACH BAND LANDS ON THE ANIMAL, solved back through the row coordinate.
# PRINTED RATHER THAN COMMENTED, because the three `rows_` terms and
# `BAND_RANGE` all move it and a number in a comment is what goes stale.
_span = BAND_RANGE['hi'] - BAND_RANGE['lo']
for _i in range(1, len(BANDS)):
    _v = BAND_RANGE['lo'] + _span * _i / float(len(BANDS))
    # SOLVED BY SWEEPING rather than by a formula, because the row coordinate
    # is a cubic now and a closed form for one is three cases and a sign trap.
    _y = min((abs(_rows(-1.4 + 0.002 * _k) - _v), -1.4 + 0.002 * _k)
             for _k in range(1451))[1]
    print("  band %d -> %d at row %+5.2f, which is y %+5.2f"
          % (_i - 1, _i, _v, _y))
