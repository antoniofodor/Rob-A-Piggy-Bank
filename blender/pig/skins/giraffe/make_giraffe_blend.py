# -*- coding: utf-8 -*-
"""Build the Giraffe's coat as a node graph, in its own blend file.

    blender.exe --background --python skins/giraffe/make_giraffe_blend.py

Writes `skins/giraffe/giraffe.blend`. Then the ordinary loop:

    blender.exe --background --python make/bake_skin.py       -- --skin giraffe
    blender.exe --background --python make/make_view_blend.py -- --skin giraffe --render

THE PATTERN IS DEFINED IN 3D, NEVER IN UV SPACE -- see `WORKFLOW.md`. The
shader is evaluated at a POSITION on the surface, so Smart UV Project can
rotate every island however it likes and a patch still lands where the geometry
says it lands. The bake resolves it afterwards.

WHAT A GIRAFFE IS, AS A THING TO BUILD, AND WHY IT IS THE LEOPARD'S FIELD READ
FROM THE OTHER SIDE. The leopard's own header says it in as many words: a
rosette radius "past about 0.40 starts getting clipped by the cell wall and the
rosettes fuse into a web -- which is a giraffe, not a leopard." That is the
whole insight, and it is worth stating as the positive version, because it
decides every dial below.

A LEOPARD'S SPOT IS AN OBJECT SCATTERED ON A COAT. A GIRAFFE'S PATCH IS THE
COAT WITH LANES CUT INTO IT. The patches TILE -- they meet at three-way
junctions, they share straight-ish borders, and the pale between them is a
NETWORK of roughly constant width rather than a background. Draw a giraffe as
scattered blobs and what comes back is a cow; `Config.SKINS.giraffe`'s own
comment already knows this and says the size variation that makes the cow look
natural "is exactly wrong here."

So the primitive is not a distance from a CENTRE, it is a distance from the
CELL WALL. `Voronoi -> DISTANCE_TO_EDGE` gives exactly that in one node, and
the entire pattern is

    patch  =  edge > gap

-- every cell shrunk back inside its own boundary by `gap`, which leaves the
lane between two neighbours `2 * gap` wide wherever they touch. Everything else
in this file ADDS TO `gap`, in cell units, and that is the one thing to know
before turning anything:

    a bigger gap    thinner patches and wider lanes, and past the cell's own
                    inradius the patch VANISHES, leaving plain tan
    a smaller gap   fatter patches, and at zero they fuse into one sheet

WHICH IS WHY THE PATCHES DYING OUT IS THE SAME NUMBER AS THE LANES OPENING UP,
rather than a second mechanism. The muzzle, the lower legs and the underside
are each one addend on `gap`, so a patch cannot be half-killed by one mask and
resurrected by another: there is one field and one threshold. Same argument the
leopard makes for collapsing a rosette rather than switching pattern, arriving
on a different primitive.

TWO VORONOI NODES, ONE LATTICE. `DISTANCE_TO_EDGE` outputs a distance and no
Color, and the per-cell random number is the only thing here that does not vary
smoothly across the surface -- which makes it the only thing that can let two
patches sharing a border disagree about their own size, and that disagreement
is the difference between a coat and a tiling. A second Voronoi at the SAME
scale and the SAME randomness walks the same cells, so its `Color` is this
patch's own seed. That is a property of the node rather than a coincidence: the
lattice is a function of scale, randomness and the input vector, and all three
are shared.

THE COORDINATE FRAME IS THE PIG'S OWN, measured off the mesh rather than
assumed. Every part sits at identity, so object space IS world space and all
five parts share one frame -- which is what lets a patch run off the flank onto
a leg with no seam:

    x   across          body reaches +-1.000
    y   NOSE to TAIL    snout tip -1.381, body -1.080..1.052, tail tip 1.465
    z   floor to CROWN  legs -1.020, body -0.960..0.960, ear tip 1.309

So -Y is the face and +Z is up.

THE REFERENCE IS THE PATTERN AND NOTHING ELSE. The photograph this was cut
against is a giraffe-printed piggy bank, and what was taken off it is the patch
field: medium-brown blobs on a pale tan, rounded corners, lanes that wander and
occasionally pinch shut. Not the ossicones, not the neck, not the ears -- this
is a PIG wearing a giraffe's coat exactly as the leopard is one wearing a
leopard's, and geometry is `build_pig.py`'s business rather than a skin's.
"""

# --- find the toolkit, wherever this script has been filed ------------------
# Walks up from this file until it finds the folder holding `paths.py`. Depth
# independent on purpose: a script in `make/` and a script in `skins/giraffe/`
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
OUT = arg("--out", paths.skin_blend("giraffe"))

# --------------------------------------------------------------- the colours
# THE TWO THAT EXIST IN CONFIG ARE READ OFF IT rather than copied, for the
# reason `skin_colours.py` exists: two preview scripts once carried their own
# pairs and two of the eight had drifted, so the sheet used to JUDGE a pattern
# was showing colours the game does not ship. A slightly wrong tan looks
# exactly like a tan.
TAN, PATCH = skin("giraffe")

# `Config.SKINS.giraffe.trim` IS THE PATCH COLOUR HERE, WHICH IS A REPURPOSING
# AND IS SAID SO OUT LOUD -- the same call the leopard makes when it takes its
# own `trim` as the rosette centre. Under the part-built `pattern` block that
# field dressed the snout, ears, legs and tail as a darker brown; a full-colour
# sheet paints those from the same field the body uses, so a giraffe's leg is
# tan with patches on it and that colour has no other home.
#
# It is also the RIGHT colour rather than a leftover, which is worth checking
# rather than assuming. Measured off the reference photograph, its body runs
# about (236, 198, 132) and its patches about (165, 112, 58) -- which is
# Config's `body` and `trim` to within a few points. The `pattern.colour` the
# code-built spots use is (150, 96, 44), darker, and against this tan it reads
# as a cow rather than as a giraffe.

# The three colours a full-colour bake INVENTS, and precisely what it costs:
# `Config.SKINS.giraffe` has a `body` and a `trim` and nowhere to put a third,
# so changing any of these is a re-bake rather than a line of Luau.
#
# The underside. A giraffe is near-white under the belly and down the inside of
# the leg, and it is the single biggest thing stopping an all-over print
# reading as upholstery -- the same job it does on the leopard and the tiger.
CREAM = (248 / 255., 240 / 255., 224 / 255.)
# The two places a pig shows skin rather than fur.
EAR_PINK = (247 / 255., 201 / 255., 180 / 255.)
NOSE_PINK = (232 / 255., 162 / 255., 152 / 255.)

# --------------------------------------------------------------- the tunables
# EVERY NUMBER THAT DECIDES WHAT THE COAT LOOKS LIKE IS IN THESE DICTS, so a
# note like "the lanes are too wide" is a one-line edit and a two-second re-run.
#
# EVERY LENGTH IN HERE IS IN CELL UNITS AND EVERY ONE OF THEM ADDS TO `gap`.
# Blender scales the input by `scale` before measuring, so a cell is about 1
# across whatever the scale is -- which means `scale` changes HOW MANY patches
# there are and does not change how big they are relative to each other. Two
# dials, not one tangled one.
PATCHES = dict(
    # HOW MANY. Cells per stud, so the body's 2.0 studs across carries about
    # `2*scale` of them. The reference reads about five patches across a flank.
    scale=2.4,
    # HOW REGULAR THE LATTICE IS. At 1.0 the cell centres are fully jittered
    # and the cells come out wildly uneven, which is a cow; at 0 they are a
    # perfect lattice, which is a football. `Config.SKINS.giraffe`'s own
    # comment asks for LOW jitter and it is right -- a giraffe reads as a
    # tiling. This is the one dial that decides tiling against scatter.
    randomness=0.68,
    # HALF THE LANE WIDTH, in cell units, and the number everything else adds
    # to. A cell's inradius runs about 0.20..0.40 here, so a patch survives
    # while its own gap stays under that -- and the ones that do not survive
    # are the plain tan gaps a real coat has.
    gap=0.098,
    # PER CELL, which is a different thing from per PLACE: a random number
    # attached to the cell itself (`Voronoi -> Color`), so two patches sharing
    # a border can still disagree about how far back they stand. Without it
    # every lane is the same width and the lattice shows through as wallpaper.
    # ADDITIVE and in cell units, so at 0.050 a cell's gap runs 0.012..0.112 --
    # wide enough that the smallest cells lose their patch outright.
    cell_vary=0.038,
    # THE WANDER. A noise on the gap, so a lane is not a constant width along
    # its own length -- it pinches in one place and opens in another, and where
    # it pinches to nothing two patches MERGE into one bigger irregular one.
    # That merging is what a giraffe's larger patches actually are, and it comes
    # out of one number rather than a second pattern.
    #
    # THE SCALE IS THE HALF THAT MATTERS AND IT IS THE OPPOSITE OF THE OBVIOUS
    # LEVER. The reference has a few notably large patches among ordinary ones,
    # and the instinct is to reach for `cell_vary` -- which does not work, and
    # it is measured rather than reasoned: at 0.058 the big cells got bigger and
    # the small ones FRAGMENTED, because a cell whose own gap lands near its own
    # inradius survives only as a sliver. Rendered, the flank came back as
    # ribbons and Y-shaped scraps rather than blobs.
    #
    # The wander produces size variety the other way round. Slowed from 5.5 to
    # 3.4 the noise's features are wider than a cell, so it pinches a whole
    # RUN of lanes shut at once and two or three neighbours become one big
    # patch -- adding area rather than taking it away, so nothing fragments.
    # Rendered both ways: 5.5 is uniform and tidy, 3.4 has the reference's
    # spread with the small patches still solid.
    wobble=0.038, wobble_scale=3.4,
    # THE RAGGED EDGE. A fast noise at the scale of the border itself, small on
    # purpose: enough that no border is a clean straight line, not so much that
    # a patch turns to gravel. This is the tiger's `grain` doing the same job
    # on a different primitive.
    grain=0.010, grain_scale=17.0,
)

# WHERE THE PATCHES DIE OUT. All three of these ADD to `gap`, which is the
# whole reason there is no second mask anywhere in this file: a patch cannot be
# suppressed by one rule and drawn by another, because there is one threshold.
#
# The muzzle. A giraffe's face carries patches on the cheek and forehead that
# get SMALLER toward the nose and stop on a pale muzzle -- so this is a ramp
# rather than a cut, and the shrinking falls out of it for free.
#
# `hi` HAS TO SIT FORWARD OF THE EYES AT y -0.889, and that is a consequence
# of not clearing them rather than a taste call. It was -0.72, which put the
# eyes a third of the way down the fade -- so the patches were already thin
# where they meet the eye and the face read as pale from the cheek forward,
# which is a halo drawn by a different mechanism. At -0.95 the pattern is at
# full strength across the whole cheek and the plain muzzle is the short
# stretch between there and the pink pad, which is what the reference has.
MUZZLE = dict(lo=-1.22, hi=-0.95, add=0.115)
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

# The lower leg. A giraffe's legs go plain pale at the bottom. `lo` is the paw.
SOCKS = dict(lo=-1.00, hi=-0.80, add=0.035)
# And the underside, which is cream anyway -- this is what stops a patch
# hanging half off the belly line into it.
BELLY_ADD = 0.080

BELLY = dict(
    # WHERE THE CREAM STARTS AND STOPS, in z. Smoothstepped rather than cut,
    # because a hard line between two flat colours across the widest part of a
    # sphere reads as a join in the model rather than as markings.
    hi=-0.30, lo=-0.66,
    # THE TILT, which is what stops the cream being a bathtub ring. The
    # boundary is measured on `z + tilt*y`, so at the nose it sits higher and
    # at the tail lower -- a pale chin and chest running back to a tan haunch,
    # which is how the markings actually sit.
    tilt=0.30,
    # THE LEGS COME BACK OUT OF IT. They hang entirely below the belly line, so
    # a mask that is purely "low is cream" paints four white posts. Fading the
    # cream out again below `leg_hi` gives legs that emerge pale from the chest
    # and go tan at the knee -- and then `SOCKS` above takes the patches off
    # the bottom of them again, which is the right way round for a giraffe.
    leg_lo=-0.76, leg_hi=-0.56,
)

# THE SNOUT DISC IS PINK, WHICH IS THE ONE PLACE THIS DELIBERATELY LEAVES THE
# ANIMAL AND STAYS WITH THE OBJECT -- the same call the leopard makes. A
# giraffe's muzzle is pale grey; a piggy bank's snout is pink, and the
# reference is a giraffe-printed PIG rather than a giraffe. `lo` is where the
# pad is at full strength and `hi` is where it has faded out, so it is a disc
# on the end of the snout and not a band painted across the muzzle.
NOSE = dict(lo=-1.30, hi=-1.16)

# THE EYES ARE NOT CLEARED AND THE PATTERN DOES NOT RUN THROUGH THEM EITHER,
# WHICH SOUNDS LIKE A CONTRADICTION AND IS THE WHOLE POINT OF THIS BLOCK.
#
# Both of the first two answers were wrong, and they were wrong because they
# were the ONLY TWO THINGS THE MASK COULD DO. `patch` is a hard 0/1, so a
# clearance had to be a MULTIPLY -- and multiplying a binary mask by a smooth
# 0..1 disc does not shrink a patch, it FADES it, which mixes tan and brown
# through the middle and reads as a soft halo round each eye. Rendered, that
# halo was the first thing anybody saw on the hero shot, so it came out. What
# replaced it was nothing at all, and then the patches ran straight over the
# eyes -- an eye buried in a broad flat field, which is worse on a toy than on
# an animal, because the eyes are what make it read as a face at all.
#
# THE THIRD ANSWER IS TO MOVE THE BOUNDARY RATHER THAN FADE IT. Everything in
# this file adds to `gap`, and `gap` is compared against a distance -- so an
# addend that PEAKS AT THE EYE and falls off pulls every nearby patch back
# inside its own cell, hard-edged, with no fade anywhere. A patch that was going
# to cover the eye becomes a smaller patch BESIDE it, and its neighbours a
# little further out are barely touched. That is the reference photograph's own
# face: eyes sitting in clear tan with a ring of smaller patches around them,
# rather than a bald disc or a swallowed eye.
#
# IT IS THE ARCHITECTURE PAYING OUT. The header claims that everything adding to
# one `gap` means "a patch cannot be half-killed by one mask and resurrected by
# another"; this is that same property from the other end -- because there is
# one threshold and it is only ever MOVED, there is no way to express a fade,
# and a fade is exactly what was wrong with the first attempt.
#
# What is left of `WORKFLOW.md` rule 6 is the snout pad below, which really is
# cleared: the pad is PINK, so a patch laid over it would be brown on pink and
# the disc would stop reading as a snout at all.

# HOW FAR THE PATCHES STAND OFF AN EYE. `r0` is the radius held fully clear and
# `r1` is where the pattern is back to normal, both in STUDS off the eye's own
# centre; `add` is the push, in cell units, on the same ruler as `gap`.
#
# SIZED AGAINST THE EYE RATHER THAN CHOSEN. Measured off `EyePreview`, each eye
# is a ball of radius 0.105 studs centred at (+-0.318, -0.889, 0.364) -- so `r0`
# at 0.17 leaves a little over half an eyeball's width of clear tan round the
# rim, which is what stops a patch dying into the bevel. `r1` at 0.42 is about
# one cell out at this scale, so exactly the ring of patches immediately around
# the eye is shrunk and nothing beyond it is touched.
#
# `add` AT 0.20 IS SET AGAINST A CELL'S INRADIUS AND NOT BY EYE. A cell here
# runs about 0.20..0.40 of inradius, so `gap` going from 0.098 to 0.298 at the
# centre kills all but the largest cells there, while the half-strength 0.10 at
# the midpoint merely takes a chunk off a patch. Push it much past this and the
# fall-off gets wide enough to read as a clearance again.
EYE_RING = dict(x=0.318, y=-0.889, z=0.364, r0=0.17, r1=0.42, add=0.20)

# AND THE FACE IS FINER THAN THE FLANK, WHICH IS THE OTHER HALF OF MAKING THE
# EYES READ. Standing the patches off is not much use if the ones left are the
# size of the whole cheek -- what the reference has is genuinely SMALLER patches
# forward of the shoulder, so the face carries several of them and the eyes sit
# among them rather than beside one big shape.
#
# THIS IS THE ONE THING IN THE FILE THAT IS NOT AN ADDEND ON `gap`, AND IT COULD
# NOT HAVE BEEN. A bigger gap makes patches smaller AND FEWER -- past a cell's
# own inradius the patch is gone entirely -- so on a face only about two cells
# across it empties the head rather than detailing it. What sets the NUMBER of
# patches is `scale`, and `scale` is an input socket, so it can be driven by
# position: the cells themselves get smaller toward the nose, and the same `gap`
# then leaves more, smaller patches instead of fewer.
#
# WHAT IT COSTS is that a Voronoi with a varying scale has slightly STRETCHED
# cells wherever the gradient is -- there is no distortion-free way to vary cell
# density out of one node. Kept mild (1.38 over three quarters of a stud) and
# checked by looking; much past this and the cheek starts to smear.
HEAD_FINE = dict(lo=-1.10, hi=-0.34, mul=1.38)


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
    """The giraffe's coat as one material. Built twice -- once for the body and
    once for the trim -- and DELIBERATELY NOT SHARED between them.

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
        still run past it, which is what a dial like `wobble` needs in order to
        mean 'the lane pinches shut about this often' rather than 'a number I
        turned until it looked right'.

        SAMPLED AT AN OFFSET POSITION, because two noises at the same place
        with different scales are still correlated -- their large features line
        up -- so the lane wander and the ragged edge would happen in the same
        places and the coat would read as one repeating motif.
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

    # ---- the cream underside -----------------------------------------
    lift = math('MULTIPLY_ADD', -2200, 900, "z + tilt*y", b=BELLY['tilt'])
    link(Y, lift.inputs[0])
    link(Z, lift.inputs[2])
    belly_a = rng(-2000, 900, "cream below", BELLY['lo'], BELLY['hi'], 1.0, 0.0)
    link(lift.outputs[0], belly_a.inputs['Value'])
    leg_out = rng(-2000, 700, "but not the legs",
                  BELLY['leg_lo'], BELLY['leg_hi'], 0.0, 1.0)
    link(Z, leg_out.inputs['Value'])
    belly = math('MULTIPLY', -1780, 820, "CREAM MASK")
    link(belly_a.outputs['Result'], belly.inputs[0])
    link(leg_out.outputs['Result'], belly.inputs[1])

    # ---- the cell field ----------------------------------------------
    # `DISTANCE_TO_EDGE` IS THE WHOLE PATTERN AND IT IS ONE NODE. It returns
    # how far this point is from the nearest wall between two cells, in cell
    # units -- so thresholding it draws every cell shrunk back inside its own
    # boundary, which is what a giraffe's patches are. Built out of F1 and F2
    # instead it would be two nodes and a subtract that mean the same thing;
    # this is the version that says what it is.
    edge_v = node("ShaderNodeTexVoronoi", -2200, -200, "distance to the wall")
    if hasattr(edge_v, "voronoi_dimensions"):
        edge_v.voronoi_dimensions = '3D'
    edge_v.feature = 'DISTANCE_TO_EDGE'
    # SMALLER CELLS TOWARD THE NOSE -- see `HEAD_FINE`. Driven into the Scale
    # SOCKET rather than set as a value, and into BOTH Voronoi nodes off the
    # same output: the lattice is a function of scale, randomness and the input
    # vector, so the moment those two disagree about any of the three the
    # per-cell random number stops belonging to the cell it is colouring.
    fine = rng(-2420, -380, "finer over the face",
               HEAD_FINE['lo'], HEAD_FINE['hi'],
               PATCHES['scale'] * HEAD_FINE['mul'], PATCHES['scale'])
    link(Y, fine.inputs['Value'])

    edge_v.inputs['Randomness'].default_value = PATCHES['randomness']
    link(fine.outputs['Result'], edge_v.inputs['Scale'])
    link(co.outputs['Object'], edge_v.inputs['Vector'])
    edge = edge_v.outputs['Distance']

    # A SECOND VORONOI ON THE SAME LATTICE, for the per-cell random number.
    # `DISTANCE_TO_EDGE` has no `Color` output, and the per-cell seed is the
    # only source of variation here that does NOT vary smoothly across the
    # surface -- which makes it the only one that can let two patches sharing a
    # border disagree about their own size. Same scale and same randomness, so
    # it walks the same cells: the lattice is a function of those two and the
    # input vector, and all three are shared.
    cell_v = node("ShaderNodeTexVoronoi", -2200, -560, "which cell is this")
    if hasattr(cell_v, "voronoi_dimensions"):
        cell_v.voronoi_dimensions = '3D'
    cell_v.feature = 'F1'
    cell_v.distance = 'EUCLIDEAN'
    cell_v.inputs['Randomness'].default_value = PATCHES['randomness']
    link(fine.outputs['Result'], cell_v.inputs['Scale'])
    link(co.outputs['Object'], cell_v.inputs['Vector'])
    cellsep = node("ShaderNodeSeparateXYZ", -2000, -560, "per-cell random")
    link(cell_v.outputs['Color'], cellsep.inputs['Vector'])
    cell = cellsep.outputs['X']

    # ---- how far back this patch stands from its own wall ------------
    # EVERYTHING FROM HERE ADDS TO ONE NUMBER, in cell units. That is the whole
    # architecture: there is no second mask anywhere, so a patch cannot be
    # killed by one rule and drawn by another.
    cellg = rng(-2000, -760, "this cell's own gap", 0.0, 1.0,
                PATCHES['gap'] - PATCHES['cell_vary'],
                PATCHES['gap'] + PATCHES['cell_vary'], interp='LINEAR')
    link(cell, cellg.inputs['Value'])

    wb_off, wb = snoise(-2200, -1000, "LANE WANDER",
                        PATCHES['wobble_scale'], (11.0, 4.0, -7.0))
    link(co.outputs['Object'], wb_off.inputs[0])
    wb_s = math('MULTIPLY', -1700, -1000, "wander amount",
                b=PATCHES['wobble'])
    link(wb.outputs['Result'], wb_s.inputs[0])

    gr_off, gr = snoise(-2200, -1300, "RAGGED EDGE",
                        PATCHES['grain_scale'], (-6.0, 13.0, 5.0), detail=3.0)
    link(co.outputs['Object'], gr_off.inputs[0])
    gr_s = math('MULTIPLY', -1700, -1300, "grain amount",
                b=PATCHES['grain'])
    link(gr.outputs['Result'], gr_s.inputs[0])

    g1 = math('ADD', -1500, -880, "+ wander")
    link(cellg.outputs['Result'], g1.inputs[0])
    link(wb_s.outputs[0], g1.inputs[1])
    g2 = math('ADD', -1320, -900, "+ grain")
    link(g1.outputs[0], g2.inputs[0])
    link(gr_s.outputs[0], g2.inputs[1])

    # ---- and where they die out entirely -----------------------------
    muz = rng(-2200, 480, "wider toward the nose",
              MUZZLE['lo'], MUZZLE['hi'], MUZZLE['add'], 0.0)
    link(Y, muz.inputs['Value'])
    sox = rng(-2200, 300, "wider toward the paw",
              SOCKS['lo'], SOCKS['hi'], SOCKS['add'], 0.0)
    link(Z, sox.inputs['Value'])
    und = math('MULTIPLY', -2000, 120, "and under the belly",
               b=BELLY_ADD)
    link(belly.outputs[0], und.inputs[0])
    # MAXIMUM AND NOT A SUM, because these overlap: the chin is muzzle AND
    # underside, and adding them there would open a hole in the pattern twice
    # as wide as either rule asked for.
    # THE EYES PUSH THE PATCHES BACK. Mirrored on |x| so one number serves
    # both, and folded in with MAXIMUM like everything else here rather than
    # summed -- an eye sits close enough to the muzzle ramp that adding the two
    # would open a hole neither of them asked for.
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
    eyes = rng(-1880, 1300, "stand off the eye",
               EYE_RING['r0'], EYE_RING['r1'], EYE_RING['add'], 0.0)
    link(dl.outputs['Value'], eyes.inputs['Value'])

    k1 = math('MAXIMUM', -1780, 400, "")
    link(muz.outputs['Result'], k1.inputs[0])
    link(sox.outputs['Result'], k1.inputs[1])
    k2 = math('MAXIMUM', -1700, 180, "")
    link(k1.outputs[0], k2.inputs[0])
    link(eyes.outputs['Result'], k2.inputs[1])
    kill = math('MAXIMUM', -1600, 300, "WHERE THE PATCHES GO")
    link(k2.outputs[0], kill.inputs[0])
    link(und.outputs[0], kill.inputs[1])

    gap = math('ADD', -1140, -880, "GAP HERE")
    link(g2.outputs[0], gap.inputs[0])
    link(kill.outputs[0], gap.inputs[1])

    # ---- inside a patch? ---------------------------------------------
    # A THRESHOLD AND NOT A RAMP. The bake runs at 2048 and delivers at 1024,
    # so every delivered texel is the average of four and the downscale is what
    # does the anti-aliasing -- a soft edge in the graph on top of that is
    # mush. See `WORKFLOW.md`.
    patch_raw = math('GREATER_THAN', -940, -880, "far enough from the wall?")
    link(edge, patch_raw.inputs[0])
    link(gap.outputs[0], patch_raw.inputs[1])

    # ---- the nose pad, which is the one thing still CLEARED -----------
    # A MULTIPLY ON THE MASK, unlike the eyes above -- and it is safe here for
    # exactly the reason it was not there: the pad's own pink is laid on top of
    # the patch afterwards, so any fade at its rim is hidden under the pad
    # rather than showing as a half-strength brown ring on bare tan.
    nose_pad = rng(-2200, 1100, "the snout disc",
                   NOSE['lo'], NOSE['hi'], 1.0, 0.0)
    link(Y, nose_pad.inputs['Value'])
    keep = math('SUBTRACT', -1480, 1100, "no patch on the pad", a=1.0)
    link(nose_pad.outputs['Result'], keep.inputs[1])

    patch = math('MULTIPLY', -720, -880, "PATCH MASK")
    link(patch_raw.outputs[0], patch.inputs[0])
    link(keep.outputs[0], patch.inputs[1])

    # ---- the three colours -------------------------------------------
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

    m1, f1, a1, b1, o1 = mix_rgb(nt, "tan -> cream underside")
    m1.location = (-200, 900)
    a1.default_value = to_linear(TAN) + (1.0,)
    b1.default_value = to_linear(CREAM) + (1.0,)
    link(hard(belly.outputs[0], -500, 900, "the cream underside"),
         f1)

    m2, f2, a2, b2, o2 = mix_rgb(nt, "the snout pad")
    m2.location = (0, 900)
    b2.default_value = to_linear(NOSE_PINK) + (1.0,)
    link(hard(nose_pad.outputs['Result'], -500, 1100,
              "the snout pad"), f2)
    link(o1, a2)

    m3, f3, a3, b3, o3 = mix_rgb(nt, "lay the patches on")
    m3.location = (200, 700)
    b3.default_value = to_linear(PATCH) + (1.0,)
    link(hard(patch.outputs[0], -300, 700, "the patches"), f3)
    link(o2, a3)

    bsdf = node("ShaderNodeBsdfPrincipled", 620, 400)
    bsdf.inputs['Roughness'].default_value = 0.88
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.08
    link(o3, bsdf.inputs['Base Color'])
    out = node("ShaderNodeOutputMaterial", 940, 400)
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

body_mat = coat("giraffe_body")
trim_mat = coat("giraffe_trim")
ear_mat = flat("giraffe_ear_inner", EAR_PINK)

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
assign(bpy, ASSIGN, "GIRAFFE  (from %s)" % SRC)

for _n, _c in face_slots(bpy, [n for n, _ in ASSIGN]):
    if len(_c) > 1:
        print("  %-6s faces per slot %s  <- hand selection, intact"
              % (_n, _c))

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("")
print("  saved %s -- %s is untouched"
      % (os.path.relpath(OUT, D), os.path.relpath(SRC, D)))
print("  about %d cells across the body, lane %.2f of a cell wide,"
      " per-cell gap %.3f..%.3f"
      % (round(PATCHES['scale'] * 2.0), PATCHES['gap'] * 2.0,
         PATCHES['gap'] - PATCHES['cell_vary'],
         PATCHES['gap'] + PATCHES['cell_vary']))
