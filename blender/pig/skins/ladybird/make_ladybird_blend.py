# -*- coding: utf-8 -*-
"""Build the Ladybird's shell as a node graph, in its own blend file.

    blender.exe --background --python skins/ladybird/make_ladybird_blend.py

Writes `skins/ladybird/ladybird.blend`. Then the ordinary loop:

    blender.exe --background --python make/bake_skin.py       -- --skin ladybird
    blender.exe --background --python make/make_view_blend.py -- --skin ladybird --render

THE PATTERN IS DEFINED IN 3D, NEVER IN UV SPACE -- see `WORKFLOW.md`. The
shader is evaluated at a POSITION on the surface, so Smart UV Project can
rotate every island however it likes and a spot still lands where the geometry
says it lands. The bake resolves it afterwards.

A LADYBIRD IS A CELL FIELD PLUS THREE HARD REGIONS, AND THE FIRST HALF OF THAT
IS THE COW'S OWN ARGUMENT READ BACKWARDS. `make_cow_blend.py` rejects a Voronoi
field in as many words -- "a Voronoi blob is ONE PER CELL, so however much the
sizes are varied the blobs stay EVENLY SPACED, and even spacing is the single
loudest tell that a pattern was generated". Every word of that is true, and it
is exactly why the field is right here: A LADYBIRD'S SPOTS REALLY ARE EVENLY
SPACED. A real seven-spot places them symmetrically at fixed positions, and the
plush reference is a regular scatter of discs with no blotch, no coastline and
nothing running together. The property that disqualified the primitive for a
Holstein is the property that qualifies it for a beetle.

    tiger       a WAVE.  One global phase expression -- rings about the
                nose-tail axis -- so every stripe is a slice of one field.
    leopard     a CELL FIELD.  Each rosette is an object with a centre.
    giraffe     the SAME cell field read from the other side: each patch is a
                cell shrunk back inside its own wall.
    cow         a LEVEL SET.  One smooth noise, one threshold, and the blotch
                is wherever the field happens to fall below it.
    ladybird    a CELL FIELD DRAWING SOLID DISCS, plus three hard regions that
                are not markings at all: a pronotum, a seam and an underside.

AND THE SECOND HALF IS WHAT MAKES IT NOT THE LEOPARD WITH DIFFERENT NUMBERS.
`rosette.py` says outright that it is the spotted CAT and must not become a
general skin builder, and its spec is cat anatomy end to end -- a cream belly,
freckles, a dorsal stripe, a solidity ramp that closes a ring into a disc. A
ladybird wants none of them. Its black is not a marking, it is the ANIMAL: the
head and pronotum at the front, the seam between the two wing cases, and the
underside. Those are three hard-edged REGIONS, and a region is not a thing that
field has any way to say. What this file does borrow is the tangent-plane
distance, and it borrows it deliberately -- see the block that does it.

WHAT SAYS LADYBIRD RATHER THAN RED DALMATIAN, which is the only question this
skin actually has to answer. Red with black dots IS a dalmatian in a different
colourway, and `Config.SKINS.dalmatian` sits three rows below this one. Three
things separate them and none of them is the dots:

  * THE SEAM. One straight black line down the spine, from the pronotum to the
    haunch, splitting the shell into two wing cases. It is the cheapest,
    loudest beetle signal there is, and no mammal in this catalogue has one. It
    also lands on the groove the generator already sculpts down the pig's spine
    for the coin slot, so the thing the ANIMAL is named after and the thing the
    OBJECT is named after turn out to be the same line.
  * THE BLACK HEAD. A beetle's head and pronotum are a hard-edged black shield,
    not a marking that fades out. That is the "black nose" this was asked for,
    arriving as anatomy rather than as a recolour of one part.
  * ROUND DOTS, EVENLY SPREAD. A dalmatian is a scatter of ragged small ones;
    these are discs of one family at one spacing, and the shipped
    `Config.SKINS.ladybird.pattern`'s own comment already says so -- "a
    ladybird's spots are the one real animal marking that genuinely IS a
    scatter of discs". `SPOTS` below is measured against the reference plush
    rather than against that spec, and lands slightly smaller; see its `r`.

THE COORDINATE FRAME IS THE PIG'S OWN, measured off the mesh rather than
assumed. Every part sits at identity, so object space IS world space and all
five parts share one frame -- which is what lets the seam run off the body onto
the tail with no join:

    x   across          body reaches +-1.000
    y   NOSE to TAIL    snout tip -1.381, body -1.080..1.052, tail tip 1.465
    z   floor to CROWN  legs -1.020, body -0.960..0.960, ear tip 1.309

So -Y is the face and +Z is up. The two landmarks that actually decide numbers
below were read off `pig_parts.blend` rather than taken from the header above
it: `EyePreview` spans x +-0.423, y -0.994..-0.784, z 0.259..0.469, so an eye
is a disc of radius 0.105 centred on (+-0.318, -0.889, 0.364); and
`NostrilPreview` sits on the snout at y -1.225, which is inside the black head
and is the one thing this skin knowingly costs -- see `HEAD`.
"""

# --- find the toolkit, wherever this script has been filed ------------------
# Walks up from this file until it finds the folder holding `paths.py`. Depth
# independent on purpose: a script in `make/` and a script in `skins/ladybird/`
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
import bpy, os, sys

from skin_colours import skin, to_linear   # noqa: E402
from skin_parts import assign, face_slots   # noqa: E402


argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SRC = arg("--blend", paths.PARTS)
OUT = arg("--out", paths.skin_blend("ladybird"))

# --------------------------------------------------------------- the colours
# READ OFF `Config.SKINS.ladybird` rather than copied, for the reason
# `skin_colours.py` exists: two preview scripts once carried their own pairs
# and two of the eight had drifted, so the sheet used to JUDGE a pattern was
# showing colours the game does not ship. A slightly wrong red looks exactly
# like a red.
RED, BLACK = skin("ladybird")

# ONE BLACK, NOT TWO, AND WHICH ONE IS THE COW'S ARGUMENT MADE AGAIN.
# `Config.SKINS.ladybird` carries a second near-black in `pattern.colour` --
# (24, 22, 26) against `trim`'s (30, 28, 32), six units apart and
# indistinguishable on a lawn -- and the tempting thing is to use one for the
# dots and one for the regions, because that is what each field is named for.
# Two reasons not to. On a real ladybird the spots and the pronotum ARE the
# same black, so a split here would be a distinction the animal does not have.
# And `pattern` IS SCHEDULED FOR DELETION: `WORKFLOW.md`'s upload steps end
# with "`surface = "<pack>"` on the skin, and delete its `pattern` block", so
# depending on a value inside it is a dependency on something that will not be
# there -- a worse drift than a literal with a comment on it. `trim` survives
# the upload and `skin_colours` reads it, so it cannot drift at all.

# THE CHEEK PATCH, AND IT IS THE ONE COLOUR NOTHING IN CONFIG COULD HAVE HELD.
# See `CHEEK` below for why it exists at all. `Config.SKINS` has a `body` and a
# `trim` and nowhere to put a third, which is precisely what a full-colour
# sheet buys -- and precisely why changing this is a re-bake rather than a line
# of Luau.
CHEEK_WHITE = (248 / 255., 244 / 255., 238 / 255.)

# The one place a pig shows skin rather than fur, and Config has nothing to say
# about it. The catalogue standard, shared with the cow, tiger, leopard and
# giraffe: an inner ear is a fact about the PIG rather than about which animal
# it is wearing, so it does not change per skin.
EAR_PINK = (247 / 255., 201 / 255., 180 / 255.)

# --------------------------------------------------------------- the tunables
# EVERY NUMBER THAT DECIDES WHAT THE SHELL LOOKS LIKE IS IN THESE DICTS, so a
# note like "too much black at the front" is a one-line edit and a two-second
# re-run.
SPOTS = dict(
    # HOW MANY. Cells per stud, so the body's 2.0 studs across carries about
    # `2*scale` of them and the whole shell carries roughly `area * scale^2` --
    # about 64 at this setting, of which `drop` removes a tenth and the black
    # regions swallow more, landing near the sixty the reference plush carries.
    #
    # AND DENSITY IS FREE, WHICH IS NOT OBVIOUS AND IS WORTH KNOWING BEFORE
    # ANYBODY TRADES IT AWAY. What decides whether a disc gets cut is `r`
    # measured in CELLS, and `r / scale` is what decides how big a spot is in
    # STUDS -- so asking for more spots at the same stud size raises `scale`
    # and lowers `r / scale` in the same breath, and `r` in cells does not
    # move. Going from forty spots to sixty cost nothing at all in `max_r`.
    # It is only asking for BIGGER spots, or for more of them at the same size,
    # that spends the clipping budget.
    scale=2.60,
    # HOW EVENLY THEY SIT, AND ON THIS ANIMAL IT IS NOT A TASTE DIAL AT ALL --
    # IT IS ONE HALF OF THE ONLY EQUATION IN THIS FILE. See `max_r`.
    #
    # It is also the opposite call from the leopard's 0.78 for the opposite
    # reason. That coat wants consistent spacing so a large radius is safe
    # without rosettes colliding into a web; this one wants it so a disc is
    # never CUT, which is a different failure and a much less forgiving one.
    randomness=0.24,
    # THE DISC'S RADIUS, in cell units -- a cell is about 1 across and its
    # neighbour's centre about 0.5 away, so 0.5 is where two discs touch.
    #
    # THIS IS SMALLER THAN THE SPOT IT REPLACES, AND BOTH REASONS POINT THE
    # SAME WAY. `Config`'s part-built ladybird uses `size = 0.11`, a fraction
    # of the body RADIUS and therefore 0.11 studs, and the first build of this
    # sheet was solved to land exactly on it: 0.27 / 2.40 = 0.1125. Measured
    # against the reference plush, that is too big -- its spots run 8 to 9 per
    # cent of the body's width where 0.11 studs on a 2.0-stud body is 11. And
    # the field has a hard ceiling of its own (`max_r`) which 0.27 was well
    # past. 0.20 / 2.40 is 0.083 studs, which is the reference and is inside
    # the ceiling, so nothing was traded to satisfy either.
    r=0.185,
    # AND THE CAP, WHICH IS ABOUT A FAILURE THIS FILE HAD TO DERIVE TWICE
    # BEFORE IT GOT IT RIGHT.
    #
    # A DISC IS DRAWN AS "NEARER TO THIS CELL'S CENTRE THAN `r`", and the
    # centre it is measured from is the NEAREST one -- so the disc is silently
    # cut at the perpendicular bisector the moment a neighbouring centre is
    # closer to the shading point than this one is. A clipped RING still reads
    # as a marking, which is why `rosette.py` accepts it and a leopard is full
    # of arcs. A clipped DISC is a POLYGON: two or three straight chords
    # meeting at points, on an animal whose entire identity is round dots. It
    # was reported as a rendering fault, which is exactly what it looks like.
    #
    # THE FIRST DERIVATION WAS `max_r <= (1 - randomness) / 2` AND IT IS
    # WRONG. Blender jitters a centre by up to `randomness` inside its cell, so
    # two adjacent centres can close to `1 - randomness` and half of that is
    # the room each has -- which is a correct statement about the LATTICE and
    # not about this graph. The wedge survived being built to satisfy it, which
    # is what said the model was wrong rather than the number.
    #
    # WHAT IT MISSES IS THE DEPTH, AND THE DEPTH IS THE WHOLE POINT OF THE
    # TANGENT-PLANE BLOCK BELOW. That projection throws away how far under the
    # skin a cell centre sits, deliberately, so that a deep cell still draws a
    # FULL-SIZE marking instead of a shrunken one or nothing at all. But the
    # engine decides which centre is nearest in 3D, WITH the depth. So a centre
    # at depth `d` draws a disc whose points are `r` away tangentially and
    # `sqrt(r^2 + d^2)` away in the space the comparison actually happens in --
    # and it loses the comparison, and gets cut, long before `r` alone says it
    # should:
    #
    #     clean  <=>  sqrt(r^2 + d^2)  <=  (1 - randomness) / 2
    #
    # `d` runs to about half a cell, so THERE IS NO SETTING THAT IS CLEAN FOR
    # EVERY CELL. What there is is a trade, and both dials pull the same way:
    # smaller discs relative to a cell, and a tidier lattice. At `r` 0.158 and
    # `randomness` 0.32 a disc is clean down to a depth of 0.30 of a cell,
    # which is most of them.
    #
    # AND THE COUNT IS WHAT PAYS FOR IT, WHICH IS WHY `scale` MOVED WITH THIS.
    # `r / scale` is the spot's size in studs and has to stay where the
    # reference put it, so making a disc smaller RELATIVE TO ITS CELL means
    # making the cells bigger -- fewer, larger cells carrying the same-sized
    # spots. `drop` then has almost nothing left to do, which is correct for
    # this animal: a real ladybird has a spot in every place a spot goes.
    max_r=0.235,
    # HOW MUCH ONE DISC DIFFERS FROM THE NEXT. A random number attached to the
    # CELL (`Voronoi -> Color`), so two touching spots can be different sizes --
    # the only variation here that does not vary smoothly across the surface,
    # and therefore the only one that can stop a lattice showing.
    #
    # SIZED SO THE CAP CATCHES ONLY THE TAIL. The two variations multiply, so
    # the raw radius runs 0.117..0.302 against a ceiling of 0.275 -- about a
    # tenth of the spots are clamped. Push either variation much higher and the
    # clamp stops being a safety net and becomes the shape of the
    # distribution: a crowd of discs all at exactly maximum size, which is a
    # different way of looking generated.
    cell_vary=0.24,
    # AND PER PLACE, which is a different thing: a slow noise, so a whole
    # region of the shell can run large. Small, because a beetle's spots are
    # far more uniform than a cat's.
    size_vary=0.12, size_scale=1.40,
    # AND SOME CELLS DRAW NOTHING AT ALL. Without it every cell owns a disc and
    # the coverage is perfectly regular, which is the one way this primitive
    # gives itself away. A second, INDEPENDENT channel of the same per-cell
    # random, so dropout and size cannot correlate -- see where they are read.
    drop=0.10,
)

# THE PRONOTUM, WHICH IS A HARD CUT AND NOT A RAMP. `WORKFLOW.md` rule 4: the
# bake runs at 2048 and delivers at 1024, so every delivered texel is the
# average of four and the downscale is what does the anti-aliasing. A soft edge
# in the graph on top of that is mush -- and a beetle's head shield has the
# hardest edge on the animal, so softening it would be wrong twice over.
#
# `y` ALONE WOULD BE A FLAT DISC, so `bow` tilts the cutting plane back over
# the crown: positive means the black reaches FURTHER TOWARD THE TAIL the
# higher up it goes, which is what a pronotum does seen from the side.
#
# WHERE THE BOUNDARY GOES IS DECIDED BY THE EYES AND NOT BY THE ANIMAL, and
# that is worth being exact about, because getting it wrong deletes a face. The
# game's eye is a code-built part painted near-black, (38, 30, 34), and
# measured as a WCAG contrast ratio against this skin:
#
#     eye on the red   (214, 44, 44)    3.29 : 1   reads
#     eye on the black ( 30, 28, 32)    1.11 : 1   invisible
#
# 1.11 is as close to identical as two different triples get -- the same
# finding `make_cow_blend.py` records at 1.009 for its blotch. So the boundary
# may not LAND on an eye: it has to be clear in front of them or well behind
# them, and there is no third option, because a line through an eye is a line
# through the one part of a face nobody will forgive.
#
# IT GOES BEHIND THEM, AND THE EYES SIT IN THE BLACK, WHICH IS WHAT A REAL
# LADYBIRD'S HEAD DOES. A black head that stops short of the eyes is not a
# head, it is a nose -- and a beetle's eyes are black anyway, set in a black
# head, so this is the animal rather than a concession to it.
#
# AND THE CONTRAST ARGUMENT ABOVE DOES NOT APPLY THE WAY IT LOOKS LIKE IT
# DOES, WHICH IS THE FINDING WORTH KEEPING. 1.11 : 1 is a measurement of two
# FLAT COLOURS, and it is exactly right for a painted marking -- which is what
# the cow's blotch is. An eye is not painted. It is a convex part standing
# proud of the body, so it carries its own shading and its own highlight, and
# it reads against black the way a black button reads on a black coat. The
# first build of this skin proved it by accident: the NOSTRILS sat inside the
# black head at y -1.225 and this comment predicted they would vanish, and
# they did not -- they read perfectly well as two dark holes, because they are
# geometry rather than paint. `CHEEK` below is the same question asked about
# the eyes, and it is answered the same way.
#
# Measured with the shipped numbers: the eye's rearmost point (y -0.784,
# z 0.364) cuts at -0.806 against a boundary of -0.66, so every eye sits 0.15
# studs inside the black.
#
# `bow` IS SMALL FOR A REASON THAT IS NOT ABOUT THE HEAD AT ALL: THE EARS.
# They start at y -0.554 and rise to z 1.309, so a plane that leans back over
# the crown reaches them long before it reaches anything else. At the first
# build's 0.26 it swallowed both -- a black-eared pig with a red rump, which
# read as a hood rather than as a beetle. At 0.06 the ear's own base cuts at
# -0.581 against a boundary of -0.66 and stays red with 0.079 studs to spare.
# ANYTHING THAT MOVES `y` BACK OR `bow` UP HAS TO BE CHECKED AGAINST THE EAR
# BASE, not against the face.
HEAD = dict(y=-0.66, bow=0.06)

# THE CHEEK PATCH: BUILT, RENDERED, AND TURNED OFF. `r = 0` draws nothing, and
# the graph is kept because the reasoning either way is worth having in one
# place rather than being rediscovered.
#
# WHAT IT WAS FOR, AND IT WAS NOT AN INVENTION. A seven-spot ladybird has two
# pale patches on its black head, one either side, sitting exactly where a
# face's eyes would be -- so the mark a real ladybird carries happened to be
# the mark that makes an eye readable on a black head, 13.9 : 1 against the
# eye part where the black underneath measures 1.11. Two arguments landing on
# one shape is usually the sign of a good idea.
#
# WHY IT IS OFF ANYWAY. Rendered, two white rings on a black face do not read
# as a beetle's head, they read as CARTOON EYES -- the whites of them -- and
# the animal stops being an insect and becomes a character. And the problem
# they were solving turned out not to exist: see `HEAD` above, where the
# nostrils sitting on the same black measured the same 1.11 and read
# perfectly, because an eye is convex geometry with its own highlight rather
# than a painted mark. A REAL LADYBIRD'S EYES ARE BLACK IN A BLACK HEAD, and
# so are this pig's.
#
# WHAT IT COSTS IF IT COMES BACK. It is painted LAST, over everything, which
# is what would make it the only eye clearance this skin needs -- the cow and
# the leopard each carry a ramp suppressing their marking near an eye, and a
# disc on top does that job and the head's job at once whatever is underneath.
# 0.20 against an eye of radius 0.105 leaves a ring a tenth of a stud wide;
# under about 0.13 the ring closes up. Measured on |x|, so one patch serves
# both eyes -- the only mirrored thing in the file, since everything else is a
# 3D field and the two flanks genuinely differ.
CHEEK = dict(x=0.318, y=-0.889, z=0.364, r=0.0)

# THE ELYTRA SEAM. One straight line down the spine where the two wing cases
# meet, and it is the loudest thing on this animal that is not a dot.
#
# STRAIGHT, DELIBERATELY, WHERE EVERY OTHER MARKING IN THIS CATALOGUE WOBBLES.
# The tiger, the leopard, the giraffe and the cow all carry a noise on their
# boundary, because a coat that does not is a print. A beetle is the opposite
# case: its shell is a moulded object and the seam is the join between two
# halves of it, so the one crisp line is exactly what says this is not fur.
#
# `w` is the HALF-width in studs, so the line is 0.09 across here -- which is
# 0.54 studs on the twelve-stud pig the game actually builds, since the whole
# animal is 2.0 studs across in this frame and twelve out there.
#
# `z` keeps it on the UPPER surface only. Below that the underside is already
# black, and a line running down the chest would be a seam a beetle has not
# got.
#
# AND IT TAPERS TO NOTHING AT THE HAUNCH rather than stopping. A line cut
# square at its end reads as a line that ran out of texture.
#
# IT MUST BE GONE BEFORE THE TAIL, AND THAT IS A HARD CONSTRAINT RATHER THAN A
# taste one. The tail is a separate part spanning y 0.731..1.465 and x
# -0.259..0.240 -- so it straddles the centre line, and every part shares one
# frame, which is the thing that makes a marking run off the body onto a limb
# with no seam. Run this to the end of the BODY (y 1.052) and it does exactly
# that: the line climbs the tail and splits it down its length, which reads as
# a crack in the one piece of the pig that is supposed to be a single curl.
# Measured on the first build, where `fade_hi` was 1.02 and the line reached
# 0.29 studs past the tail root.
#
# So `fade_hi` is 0.62, which is 0.111 studs clear of the tail, and `fade_lo`
# is where it starts closing. That leaves the seam running the whole visible
# back and stopping at the haunch -- which is where a beetle's elytra stop
# anyway, since what is behind them is not shell.
SEAM = dict(w=0.045, z=-0.10, fade_lo=0.44, fade_hi=0.68)
# NOTHING ON THIS ANIMAL FADES INTO ANYTHING ELSE.
#
# The theme is CARTOON, so every texel is one of the colours named above and
# never a blend of two. That is enforced at the graph's output rather than
# asked of each mask: every factor reaching a colour mix goes through `hard`,
# so a soft mask anywhere upstream moves an EDGE rather than smearing one.
#
# It is not a preference about this skin, it is the rule for all of them --
# `WORKFLOW.md`, "Nothing fades". Softness that survives is softness on a
# WIDTH, which tapers a stroke to a point in full ink and is a different thing.
NO_FADING = True


# THE UNDERSIDE, WHICH IS BLACK ON A REAL LADYBIRD AND IS ALSO WHAT KEEPS THE
# LEGS HONEST. `Config.SKINS.ladybird.trim` is already near-black, so the
# catalogue has been saying "black feet" since the day it was priced; this is
# that same statement made by geometry instead of by a part colour.
#
# SOLVED SO EVERY LEG IS ENTIRELY INSIDE IT rather than eyeballed. The legs top
# out at z -0.520 and span y -0.700..0.760, so the binding case is the hindmost
# leg at the top of its travel: -0.520 + 0.10 * 0.760 = -0.444, which clears
# -0.42 by 0.024. Raise `tilt` or lower `z` and the top of a back leg comes out
# red -- which reads as a bug rather than as a decision, because three legs
# would agree with each other and one would not.
#
# `tilt` keeps it off being a perfect ring round the widest part of a sphere,
# which `make_cow_blend.py` records as reading like a join in the model. It
# runs the black higher at the nose, where the head is black anyway, and lower
# at the tail. The spots straddling the line are what actually break it up.
BELLY = dict(z=-0.42, tilt=-0.08)


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


def shell(name):
    """The ladybird's shell as one material. Built twice -- once for the body
    and once for the trim -- and DELIBERATELY NOT SHARED between them.

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
        up. Only one noise is used here, so nothing can correlate with anything
        yet; the offset is kept so that the next one added cannot.
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
    co = node("ShaderNodeTexCoord", -2800, 0, "the pig's own frame")
    sep = node("ShaderNodeSeparateXYZ", -2600, 0,
               "x across / y nose-tail / z up")
    link(co.outputs['Object'], sep.inputs['Vector'])
    X, Y, Z = sep.outputs['X'], sep.outputs['Y'], sep.outputs['Z']
    ax = math('ABSOLUTE', -2400, 180, "mirror onto one side")
    link(X, ax.inputs[0])

    # ---- the pronotum: a tilted plane through the head ----------------
    # `MULTIPLY_ADD` is `Value * Multiplier + Addend`, so this is `y - bow*z`.
    # Black in FRONT of the boundary; the tilt is what carries the black
    # further back the higher up the animal it goes.
    head_cut = math('MULTIPLY_ADD', -2400, 1000, "y - bow*z",
                    b=-HEAD['bow'])
    link(Z, head_cut.inputs[0])
    link(Y, head_cut.inputs[2])
    head = math('LESS_THAN', -2200, 1000, "THE HEAD AND PRONOTUM",
                b=HEAD['y'])
    link(head_cut.outputs[0], head.inputs[0])

    # ---- the underside ------------------------------------------------
    belly_cut = math('MULTIPLY_ADD', -2400, 800, "z + tilt*y",
                     b=BELLY['tilt'])
    link(Y, belly_cut.inputs[0])
    link(Z, belly_cut.inputs[2])
    belly = math('LESS_THAN', -2200, 800, "THE UNDERSIDE AND THE LEGS",
                 b=BELLY['z'])
    link(belly_cut.outputs[0], belly.inputs[0])

    # ---- the seam between the wing cases ------------------------------
    taper = rng(-2400, 600, "close it at the haunch",
                SEAM['fade_lo'], SEAM['fade_hi'], 1.0, 0.0)
    link(Y, taper.inputs['Value'])
    half = math('MULTIPLY', -2200, 600, "half-width here", b=SEAM['w'])
    link(taper.outputs['Result'], half.inputs[0])
    narrow = math('LESS_THAN', -2000, 620, "on the centre line")
    link(ax.outputs[0], narrow.inputs[0])
    link(half.outputs[0], narrow.inputs[1])
    on_top = math('GREATER_THAN', -2200, 440, "upper surface only",
                  b=SEAM['z'])
    link(Z, on_top.inputs[0])
    seam = math('MULTIPLY', -1800, 520, "THE ELYTRA SEAM")
    link(narrow.outputs[0], seam.inputs[0])
    link(on_top.outputs[0], seam.inputs[1])

    # THE THREE REGIONS ARE ONE MASK, AND IT IS A MAXIMUM RATHER THAN A SUM.
    # They overlap -- the seam runs into the pronotum, and the pronotum meets
    # the underside at the chin -- and adding overlapping masks gives a value
    # above 1, which on a colour mix is not "blacker", it is out of range.
    r1 = math('MAXIMUM', -1600, 900, "")
    link(head.outputs[0], r1.inputs[0])
    link(belly.outputs[0], r1.inputs[1])
    solid = math('MAXIMUM', -1420, 800, "THE BLACK OF THE ANIMAL")
    link(r1.outputs[0], solid.inputs[0])
    link(seam.outputs[0], solid.inputs[1])

    # ---- the spots ----------------------------------------------------
    vor = node("ShaderNodeTexVoronoi", -2400, -300, "one cell per spot")
    if hasattr(vor, "voronoi_dimensions"):
        vor.voronoi_dimensions = '3D'
    vor.feature = 'F1'
    vor.distance = 'EUCLIDEAN'
    vor.inputs['Scale'].default_value = SPOTS['scale']
    vor.inputs['Randomness'].default_value = SPOTS['randomness']
    link(co.outputs['Object'], vor.inputs['Vector'])

    # THE DISTANCE IS MEASURED IN THE SURFACE'S OWN TANGENT PLANE, NOT IN 3D,
    # AND THIS BLOCK IS LIFTED FROM `rosette.py` ON PURPOSE.
    #
    # `Distance` is the straight-line distance to the cell centre, and the
    # centre is a point in a 3D LATTICE while the pig is a SHELL through it. So
    # a centre sitting a little way under the surface draws a disc of radius
    # `sqrt(r^2 - depth^2)` -- smaller than asked for -- and one sitting deeper
    # than `r` draws NOTHING AT ALL. Measured on the leopard's first four
    # builds that is a fifth to a third of the coat simply absent, and it does
    # not present as small spots somebody could tune bigger: a deep cell owns
    # its whole footprint on the surface, so what it leaves is a BLANK PATCH
    # the size of a spot. Turning `scale` up makes more, smaller blanks.
    #
    # WHY IT IS COPIED RATHER THAN IMPORTED, SAID OUT LOUD RATHER THAN LEFT TO
    # BE NOTICED. `rosette.py` is the SPOTTED CAT, and its own header says it
    # must not become a general skin builder; its `coat()` takes six dicts of
    # cat anatomy -- a cream belly, freckles, a dorsal stripe, a solidity ramp
    # -- and a beetle wants none of them. Importing it to reach thirty lines
    # would be the tail wagging the dog, and rewriting it to serve both is a
    # change to a SHARED file while another session is authoring skins beside
    # this one, which `WORKFLOW.md` names as the collision nothing here can
    # catch.
    #
    # THE HONEST FIX IS AN EXTRACTION AND IT IS DELIBERATELY NOT MADE HERE:
    # "distance to the nearest cell centre, measured on the surface, in cell
    # units" is a primitive with nothing cat-shaped in it, and the moment a
    # THIRD skin wants it, it should come out of both files and into the
    # toolkit. Two copies is where this project usually writes the note; three
    # is where it has always regretted not acting on it.
    nrm = node("ShaderNodeVectorMath", -2200, -160, "unit surface normal")
    nrm.operation = 'NORMALIZE'
    link(co.outputs['Normal'], nrm.inputs[0])
    off = node("ShaderNodeVectorMath", -2200, -40, "sample -> cell centre")
    off.operation = 'SUBTRACT'
    link(vor.outputs['Position'], off.inputs[0])
    link(co.outputs['Object'], off.inputs[1])
    depth = node("ShaderNodeVectorMath", -2020, -160, "how far under the skin")
    depth.operation = 'DOT_PRODUCT'
    link(off.outputs['Vector'], depth.inputs[0])
    link(nrm.outputs['Vector'], depth.inputs[1])
    along = node("ShaderNodeVectorMath", -1840, -160, "the part to throw away")
    along.operation = 'SCALE'
    link(nrm.outputs['Vector'], along.inputs[0])
    link(depth.outputs['Value'], along.inputs['Scale'])
    tang = node("ShaderNodeVectorMath", -1660, -40, "the part along the skin")
    tang.operation = 'SUBTRACT'
    link(off.outputs['Vector'], tang.inputs[0])
    link(along.outputs['Vector'], tang.inputs[1])
    tlen = node("ShaderNodeVectorMath", -1480, -40, "how far, on the skin")
    tlen.operation = 'LENGTH'
    link(tang.outputs['Vector'], tlen.inputs[0])
    # BACK INTO CELL UNITS, because `Position` is in studs and every radius in
    # a skin file is written against a cell.
    dist = math('MULTIPLY', -1300, -40, "in cell units", b=SPOTS['scale'])
    link(tlen.outputs['Value'], dist.inputs[0])

    # TWO INDEPENDENT PER-CELL RANDOMS. `Voronoi -> Color` is a random colour
    # per cell, so one channel of it is a per-spot seed -- and these are two
    # SEPARATE channels rather than one value used twice, or the biggest spots
    # would also be the ones surviving the dropout and the coverage would read
    # as graded rather than as random.
    cellsep = node("ShaderNodeSeparateXYZ", -2200, -520, "per-cell random")
    link(vor.outputs['Color'], cellsep.inputs['Vector'])
    cell_size, cell_keep = cellsep.outputs['X'], cellsep.outputs['Y']

    # ---- how big this one is ------------------------------------------
    centred = math('MULTIPLY_ADD', -2000, -520, "-1..1", b=2.0, c=-1.0)
    link(cell_size, centred.inputs[0])
    r_cell = math('MULTIPLY_ADD', -1800, -520, "r * (1 + vary*cell)",
                  b=SPOTS['r'] * SPOTS['cell_vary'], c=SPOTS['r'])
    link(centred.outputs[0], r_cell.inputs[0])

    s_off, s_n = snoise(-2200, -840, "size, region by region",
                        SPOTS['size_scale'], (7.0, -3.0, 11.0))
    link(co.outputs['Object'], s_off.inputs[0])
    s_f = math('MULTIPLY_ADD', -1740, -840, "1 + vary*noise",
               b=SPOTS['size_vary'], c=1.0)
    link(s_n.outputs['Result'], s_f.inputs[0])
    r_raw = math('MULTIPLY', -1540, -620, "radius here")
    link(r_cell.outputs[0], r_raw.inputs[0])
    link(s_f.outputs[0], r_raw.inputs[1])
    radius = math('MINIMUM', -1340, -620, "never past a cell wall",
                  b=SPOTS['max_r'])
    link(r_raw.outputs[0], radius.inputs[0])

    spot_raw = math('LESS_THAN', -1100, -300, "inside the disc?")
    link(dist.outputs[0], spot_raw.inputs[0])
    link(radius.outputs[0], spot_raw.inputs[1])
    keep = math('GREATER_THAN', -1800, -320, "this cell draws at all",
                b=SPOTS['drop'])
    link(cell_keep, keep.inputs[0])
    spot = math('MULTIPLY', -900, -300, "THE SPOTS")
    link(spot_raw.outputs[0], spot.inputs[0])
    link(keep.outputs[0], spot.inputs[1])

    # ---- everything black --------------------------------------------
    # MAXIMUM AGAIN, AND IT IS ALSO WHY THE SPOTS NEED NO SUPPRESSION MASK. A
    # spot landing on the pronotum or the underside is simply already black, so
    # there is nothing to hide and no second rule that could disagree with the
    # first about where a spot is. It is also what breaks up the waterline: a
    # spot straddling the belly boundary bulges it, and a straight line with
    # bumps on it stops reading as a line.
    mark = math('MAXIMUM', -700, 200, "BLACK HERE")
    link(solid.outputs[0], mark.inputs[0])
    link(spot.outputs[0], mark.inputs[1])

    # ---- the cheek patches --------------------------------------------
    here = node("ShaderNodeCombineXYZ", -2200, 1300, "this point, mirrored")
    link(ax.outputs[0], here.inputs['X'])
    link(Y, here.inputs['Y'])
    link(Z, here.inputs['Z'])
    dv = node("ShaderNodeVectorMath", -2020, 1300, "offset from the eye")
    dv.operation = 'SUBTRACT'
    dv.inputs[1].default_value = (CHEEK['x'], CHEEK['y'], CHEEK['z'])
    link(here.outputs['Vector'], dv.inputs[0])
    dl = node("ShaderNodeVectorMath", -1840, 1300, "how far")
    dl.operation = 'LENGTH'
    link(dv.outputs['Vector'], dl.inputs[0])
    cheek = math('LESS_THAN', -1660, 1300, "THE CHEEK PATCH", b=CHEEK['r'])
    link(dl.outputs['Value'], cheek.inputs[0])

    # ---- the three colours --------------------------------------------
    # ---- NOTHING FADES ------------------------------------------------
    # EVERY FACTOR THAT REACHES A COLOUR PASSES THROUGH HERE, AND THAT IS A
    # STRUCTURAL RULE RATHER THAN A TIDY-UP. A `Mix` factor of 0.4 does not
    # draw less of something -- it draws a colour that was never authored,
    # 40% of the way between two that were. On a cartoon coat that reads as an
    # airbrush: a nose pad that dissolves into the cheek, a belly line that
    # smears, a marking at half strength. See `NO_FADING` and `WORKFLOW.md`.
    #
    # Softness on a WIDTH is the opposite and is kept everywhere it appears --
    # that is a stroke tapering to a point, which is drawn in full ink the
    # whole way. A mask on the ink can only cut; a mask on the width can taper.
    def hard(sock, x, y, what):
        n = math('GREATER_THAN', x, y, "%s: one colour or the other" % what,
                 b=0.5)
        link(sock, n.inputs[0])
        return n.outputs[0]

    m1, f1, a1, b1, o1 = mix_rgb(nt, "red -> black")
    m1.location = (-400, 400)
    a1.default_value = to_linear(RED) + (1.0,)
    b1.default_value = to_linear(BLACK) + (1.0,)
    link(hard(mark.outputs[0], -560, 400, "the black"), f1)

    # PAINTED LAST, WHICH IS WHAT MAKES IT THE EYE CLEARANCE. See `CHEEK`.
    m2, f2, a2, b2, o2 = mix_rgb(nt, "and the cheek patches on top")
    m2.location = (-100, 700)
    b2.default_value = to_linear(CHEEK_WHITE) + (1.0,)
    link(hard(cheek.outputs[0], -400, 1300, "the cheek patch"), f2)
    link(o1, a2)

    bsdf = node("ShaderNodeBsdfPrincipled", 300, 500)
    bsdf.inputs['Roughness'].default_value = 0.88
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.08
    link(o2, bsdf.inputs['Base Color'])
    out = node("ShaderNodeOutputMaterial", 620, 500)
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

body_mat = shell("ladybird_body")
trim_mat = shell("ladybird_trim")
ear_mat = flat("ladybird_ear_inner", EAR_PINK)

# THE SNOUT WEARS THE COAT RATHER THAN A FLAT BLACK, AND THAT IS A DECISION.
# A ladybird's head IS uniformly black, so a flat material on the snout would
# be simpler and would also be correct -- and it would put the head boundary in
# TWO places, the plane in the graph and the edge of a mesh. Two rules that
# have to agree about where the black stops is exactly the shape this project
# keeps paying for. Running the plane over the snout as well means there is one
# boundary, it is a curve rather than a part edge, and dialling `HEAD['y']`
# forward carries the snout with it -- which is also the fallback the reference
# plush actually shows, a red pig with a pale nose, one number away.
#
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
assign(bpy, ASSIGN, "LADYBIRD  (from %s)" % SRC)

for _n, _c in face_slots(bpy, [n for n, _ in ASSIGN]):
    if len(_c) > 1:
        print("  %-6s faces per slot %s  <- hand selection, intact"
              % (_n, _c))

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("")
print("  saved %s -- %s is untouched"
      % (os.path.relpath(OUT, D), os.path.relpath(SRC, D)))
print("  spots  %.3f studs across, %.2f..%.2f cell units, %.0f%% of cells drawn"
      % (2.0 * SPOTS['r'] / SPOTS['scale'],
         SPOTS['r'] * (1 - SPOTS['cell_vary']) * (1 - SPOTS['size_vary']),
         min(SPOTS['max_r'],
             SPOTS['r'] * (1 + SPOTS['cell_vary']) * (1 + SPOTS['size_vary'])),
         100.0 * (1.0 - SPOTS['drop'])))
print("  black  head to y %+.2f (bow %.2f), seam %.3f wide, underside z %+.2f"
      % (HEAD['y'], HEAD['bow'], 2 * SEAM['w'], BELLY['z']))
