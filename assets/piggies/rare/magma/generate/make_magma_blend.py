# -*- coding: utf-8 -*-
"""Build MAGMA as a node graph, in its own blend file.

    blender.exe --background --python assets/piggies/rare/magma/generate/make_magma_blend.py

Writes `assets/piggies/rare/magma/source/magma.blend`. Then the ordinary loop:

    blender.exe --background --python make/bake_skin.py       -- --skin magma
    blender.exe --background --python make/make_view_blend.py -- --skin magma --render

THE PATTERN IS DEFINED IN 3D, NEVER IN UV SPACE -- see `WORKFLOW.md`. The
shader is evaluated at a POSITION on the surface, so Smart UV Project can
rotate every island however it likes and a crack still runs where the geometry
says it runs. The bake resolves it afterwards.

THIS IS THE GIRAFFE'S FIELD READ INSIDE OUT, AND THAT IS THE WHOLE IDEA.

The giraffe's header works out that a patch is not a distance from a CENTRE,
it is a distance from the CELL WALL -- `Voronoi -> DISTANCE_TO_EDGE` in one
node, thresholded:

    patch  =  edge > gap        every cell shrunk back inside its own boundary

Magma is the other side of that inequality:

    crack  =  edge < gap        the LANE is the thing you see

and once the comparison flips, every dial in the giraffe means its opposite.
`gap` stops being "how far a patch stands back from its wall" and becomes HOW
WIDE A CRACK IS. Everything that used to KILL a patch now FEEDS a crack. The
architecture survives intact: there is still one field and one number, so a
crack cannot be opened by one rule and closed by another.

AND IT IS FOUR HARD BANDS RATHER THAN A GLOW. A cooling crust does not fade
from black to yellow -- and it may not, because `WORKFLOW.md`'s "Nothing
fades" rule forbids it, and because a gradient on a cartoon pig reads as an
airbrush. So the heat is BANDED: the same `edge` compared against three
multiples of one `gap`, which is three more thresholds on a number that
already exists.

    edge < gap * BANDS.core   the white-hot core, down the middle of a crack
    edge < gap                the crack itself, deep orange
    edge < gap * BANDS.char   a CHARRED rim on the rock either side of it
    otherwise                 obsidian plate, or ash

THE CHAR RIM IS THE PIECE THAT MAKES IT READ AS DEPTH, and it is the moat's
kerb trick from `CLAUDE.md` turned inside out. There, a recess is made by
standing something PROUD around the dark, because the eye takes the highest
line as the surface. Here the crack has to read as a CREVICE in a solid plate,
so the plate darkens as it approaches the edge -- which is what a real crust
does, and which no amount of brightening the crack itself achieves. Without it
the orange sits ON the rock like paint.

WHERE THE HEAT IS. Cracks widen toward the BELLY and the PAWS and narrow on
the MUZZLE and around the EYES. That is a decision about reading rather than
about geology: a pig is looked at from the pavement, so the flank and the
lower body are what anybody sees, and putting the fire underneath makes the
animal look like it is standing in it. The crown stays solid black, which is
what gives the silhouette something to be.

THE COORDINATE FRAME IS THE PIG'S OWN, measured off the mesh rather than
assumed. Every part sits at identity, so object space IS world space and all
five parts share one frame -- which is what lets a crack run off the flank
onto a leg with no seam:

    x   across          body reaches +-1.000
    y   NOSE to TAIL    snout tip -1.381, body -1.080..1.052, tail tip 1.465
    z   floor to CROWN  legs -1.020, body -0.960..0.960, ear tip 1.309

So -Y is the face and +Z is up.

THERE IS NO REFERENCE PHOTOGRAPH, WHICH IS NEW HERE AND IS THE POINT. Every
skin before this one was cut against a picture of a real animal. This one is
cut against an idea, so what stands in for the reference is the RULE above --
four bands, fire below, solid crown -- and the check is whether it reads as
molten rock from twelve studs rather than whether it matches a photo. See
`docs/animal-crate-plan.md`.
"""

# --- find the toolkit, wherever this script has been filed ------------------
# Walks up from this file until it finds the folder holding `paths.py`. Depth
# independent on purpose: a script in `make/` and a generator in `assets/piggies/rare/magma/generate/`
# are two and three levels down, and a hardcoded `..` is a thing that breaks
# silently the first time anything is refiled.
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
import bpy, os, sys

from skin_colours import skin, to_linear   # noqa: E402
from skin_parts import assign, face_slots   # noqa: E402


argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SRC = arg("--blend", paths.PARTS)
OUT = arg("--out", paths.skin_blend("magma"))

# --------------------------------------------------------------- the colours
# NOTHING HERE IS READ OUT OF `Config.luau`, and that is a difference from
# every skin before it rather than an oversight. `skin_colours.skin()` exists
# so that a generator and the game cannot disagree about a `body`/`trim` pair,
# and there is no `magma` row to disagree with yet. When one is written it
# should take OBSIDIAN and CRACK, which are the two a two-colour fallback
# would want.
#
# A full-colour sheet invents the rest and cannot express them in Config at
# all: at `AlphaMode.Overlay` and alpha 255 the map replaces the part colour
# outright, so all six below are a re-bake rather than a line of Luau.

# THE PLATE. Near-black and WARM rather than neutral -- cooled basalt is a
# brown-black, and a blue-black next to an orange crack reads as a bruise.
OBSIDIAN = (26 / 255., 22 / 255., 24 / 255.)
# THE SECOND PLATE TONE, chosen PER CELL. Without it the rock between the
# cracks is one flat colour over most of the animal, and a flat black sphere
# has no crust in it -- it reads as a hole in the world. Ash is what a plate
# that has been out of the fire longer looks like.
ASH = (58 / 255., 50 / 255., 52 / 255.)
# THE CHARRED RIM either side of a crack. Darker than either plate: this is the
# rock closest to the heat, and it is what makes a crack read as a crevice
# rather than as a line drawn on top. See the header.
CHAR = (12 / 255., 9 / 255., 10 / 255.)
# THE CRACK. Deep orange rather than red -- red against near-black reads as
# blood, and the thing this has to say is HOT.
CRACK = (226 / 255., 78 / 255., 16 / 255.)
# THE CORE, down the middle of a crack. NOT WHITE: a white core blows out
# against the black and takes the orange with it, which is the finding
# `CLAUDE.md` records four separate times for pale Neon on a twelve-stud
# sphere. This is a hot yellow that still has a hue left in it.
CORE = (255 / 255., 190 / 255., 74 / 255.)
# THE SNOUT PAD AND THE INNER EAR. The two places a pig shows skin rather than
# fur, which on this animal are the two places the fire shows through. Pitched
# between CRACK and CORE so a pad reads as a glowing SURFACE rather than as
# either a crack or a plate.
EMBER = (244 / 255., 132 / 255., 40 / 255.)

# --------------------------------------------------------------- the tunables
# EVERY NUMBER THAT DECIDES WHAT THE CRUST LOOKS LIKE IS IN THESE DICTS, so a
# note like "the cracks are too wide" is a one-line edit and a two-second
# re-run.
#
# EVERY LENGTH IN HERE IS IN CELL UNITS AND EVERY ONE OF THEM MOVES `gap`.
# Blender scales the input by `scale` before measuring, so a cell is about 1
# across whatever the scale is -- which means `scale` changes HOW MANY plates
# there are and does not change how big they are relative to each other.
CRUST = dict(
    # HOW MANY PLATES. Cells per stud, so the body's 2.0 studs across carries
    # about `2*scale` of them. Coarser than the giraffe's 2.4: a plate wants to
    # be a slab rather than a scale, and past about 3.0 the whole animal reads
    # as crazy paving.
    scale=2.0,
    # HOW REGULAR THE LATTICE IS, and the first dial that had to move when the
    # comparison flipped. A giraffe wants to read as a TILING so its cells are
    # near-even at 0.68; cooling rock fractures UNEVENLY, and an even lattice
    # here reads as a honeycomb or a football -- both of which are other skins
    # in `docs/animal-crate-plan.md` and neither of which is this one.
    randomness=0.92,
    # HALF THE CRACK WIDTH, in cell units, and the number everything else
    # moves. A crack is `2 * gap` across where two plates meet. Deliberately
    # narrow: the glow has to be the MINORITY of the surface or the animal
    # stops being made of rock and starts being made of fire.
    gap=0.052,
    # PER CELL, which is a different thing from per PLACE: a random number
    # attached to the cell itself (`Voronoi -> Color`), so two plates sharing a
    # crack can still disagree about how far back they stand. Without it every
    # crack is a constant width and the lattice shows through as wallpaper.
    cell_vary=0.020,
    # THE WANDER. A noise on the gap, so a crack is not a constant width along
    # its own length -- it pinches almost shut in one place and opens into a
    # gash in another. On the giraffe this is what MERGES two patches; here it
    # is what makes one crack look like it is under more pressure than the next,
    # and it is the single biggest thing stopping this reading as a net.
    #
    # THE SCALE IS SLOWER THAN THE GIRAFFE'S 3.4, for the reason it was slowed
    # there: features wider than a cell act on a whole RUN of cracks at once,
    # which gives a hot region and a cool region rather than per-crack noise
    # that averages out to nothing across the animal.
    wobble=0.030, wobble_scale=2.6,
    # THE RAGGED EDGE. A fast noise at the scale of the border itself, and
    # LARGER relative to `gap` than the giraffe's is relative to its own --
    # because a fracture is jagged where a patch of hide is merely irregular,
    # and because at this crack width a clean border reads as a drawn line.
    grain=0.011, grain_scale=19.0,
    # WHICH PLATES ARE ASH RATHER THAN OBSIDIAN, as a cut on the per-cell
    # random, so about a fifth of them. NOT HALF: ash is the exception that
    # says the crust has age in it, and at half the animal reads as two-tone
    # camouflage.
    ash_cut=0.80,
)

# THE THREE HEAT BANDS, AS MULTIPLES OF `gap` RATHER THAN AS WIDTHS. One number
# decides a crack's width and these place everything else against it, so
# widening a crack widens its core and its char rim in proportion and none of
# the three can drift.
#
# It has to be ratios because the heat map below MOVES `gap` from place to
# place: a fixed-width core would swallow a narrow crack whole on the crown
# while being a hairline in a gash on the belly.
#
# `char` above 1.0 puts the rim OUTSIDE the crack, on the plate. `core` below
# 1.0 puts the core INSIDE it.
BANDS = dict(char=1.85, core=0.32)

# WHERE THE HEAT IS. Both of these ADD to `gap`, which is the giraffe's
# architecture kept intact and re-aimed: there is no second mask anywhere, so a
# crack cannot be widened by one rule and narrowed by another.
#
# The underside. `lo` is the belly and `hi` is where the rock is cold again.
BELLY_HEAT = dict(lo=-0.62, hi=-0.16, add=0.052)
# The paws. A pig standing in it.
PAW_HEAT = dict(lo=-1.00, hi=-0.74, add=0.040)

# AND WHERE IT IS NOT. These SUBTRACT, which is the one place this file
# genuinely departs from the giraffe -- there every addend pushed the same way
# and a MAXIMUM was enough. Here two of them push the other way, so the heat
# and the calm are gathered separately and differenced once. A MAXIMUM within
# each half still holds, for the giraffe's own reason: the chin is muzzle AND
# underside, and summing them there would move `gap` twice as far as either
# rule asked for.
#
# The muzzle. A snout is the coolest, most solid part of the animal, and it is
# also the part nearest a viewer standing on the pavement -- so a gash across
# it is the first thing anybody sees and the last thing that should be there.
# `hi` sits forward of the eyes at y -0.889, for the giraffe's reason.
MUZZLE_CALM = dict(lo=-1.30, hi=-0.95, sub=0.026)
# THE EYES, NARROWED RATHER THAN CLEARED, which is the tiger's finding arriving
# on a different primitive. `CLAUDE.md` records that a hard mask ON THE INK cut
# every stroke at one radius and drew a visible CIRCLE -- a stencil rather than
# a marking -- and that moving it onto the WIDTH fixed it, because every stroke
# then ends at its own radius and the endpoints scatter. A crack thinning to
# nothing as it nears an eye is the same trick: there is no ring to see.
EYE_CALM = dict(x=0.318, y=-0.889, z=0.364, r0=0.16, r1=0.40, sub=0.052)

# THE CROWN. The header says the top stays solid and gives the silhouette
# something to be, and the first build did not do it -- the spine was as
# cracked as the belly, so from above the animal was a net with no rock left
# in it. This is the counterweight to `BELLY_HEAT`, and the pair is what
# actually makes the fire read as being UNDERNEATH rather than all over.
#
# IT THINS THE CRACKS RATHER THAN CLOSING THEM. Taken to zero the crown reads
# as a bald patch -- the pattern failing rather than the rock being cold --
# which is the same finding the tiger's muzzle records from the other end.
CROWN_CALM = dict(lo=0.28, hi=0.80, sub=0.024)

# THE CEILING UNDER `gap`, AND IT IS A REAL FAULT RATHER THAN A GUARD.
# `crack = edge < gap` measures distance to the nearest CELL WALL, so a gap
# larger than a cell's own inradius is true across the WHOLE cell -- the plate
# does not crack, it MELTS, and what comes back is an orange disc with a
# yellow middle sitting among the cracks. Rendered on the first build there
# were two of them, one squarely beside the coin slot, and they read as splats
# thrown at the animal rather than as anything geological.
#
# It is the exact mirror of the giraffe's own known limit -- there, a gap past
# the inradius makes a patch VANISH and leaves plain tan, which its header
# calls "the plain tan gaps a real coat has" and welcomes. Inverted, the same
# arithmetic is a blot. Same field, same threshold, opposite consequence: the
# clearest thing this skin has found out about reading a pattern backwards.
#
# Capped rather than tuned away, because the gap that overflows is the SUM of
# the base, the cell variation, the wander and the belly heat -- so avoiding
# it by shrinking any one of those means the other three are what has to be
# watched next time anybody turns one.
GAP_CEIL = 0.088

# THE FLOOR UNDER `gap`. A NEGATIVE gap is a comparison that is false
# everywhere, which is an uncracked plate and is fine. A gap of nearly zero is
# not: it is a hairline narrower than a delivered texel, and the 2048-to-1024
# downscale averages it into a grey smear -- which is the exact fading fault
# `WORKFLOW.md` exists to forbid, arriving through the back door as a WIDTH
# rather than as a soft mask. Clamped to something the sheet can hold.
GAP_FLOOR = 0.012

# NOTHING ON THIS ANIMAL FADES INTO ANYTHING ELSE.
#
# The theme is CARTOON, so every texel is one of the six colours named above
# and never a blend of two. That is enforced at the graph's output rather than
# asked of each mask: every factor reaching a colour mix goes through `hard`,
# so a soft mask anywhere upstream moves an EDGE rather than smearing one.
#
# IT MATTERS MORE HERE THAN ON ANY SKIN SO FAR, because the obvious way to draw
# molten rock is a gradient from black through orange to yellow, and that is
# precisely what is forbidden. The four bands ARE that gradient, quantised --
# which is what every hand-painted cartoon lava in the world does, and it is
# why this reads as a cartoon rather than as a render.
NO_FADING = True

# THERE IS NO SNOUT PAD ON THE BODY, AND GETTING THERE TOOK THREE BUILDS. It is
# the one decision in this file that was reasoned wrong twice and settled by
# looking, so all three are recorded.
#
# Every other skin here paints a disc on the end of the snout -- pink, because
# a piggy bank has a pink nose, and the giraffe and the leopard both say out
# loud that this is the one place they leave the ANIMAL and stay with the
# OBJECT. The first build followed that and made the disc an EMBER, on the
# argument that a pink nose on cooling basalt is a joke the rest of the skin is
# not telling.
#
#   1. EMBER PAD, PAINTED LAST. A clean orange disc, and it read as a plastic
#      nose stuck on a rock. The fault is not the colour: it is that the pad
#      was the only UNIFORM area on a surface that is uniform nowhere else,
#      and a uniform region on a surface like that reads as a different
#      MATERIAL.
#   2. EMBER PAD, PAINTED FIRST, so the cracks run over it. Coherent in
#      principle and worse in practice -- crack, core and ember are three
#      oranges, so the bands lost all contrast against the pad and what was
#      left was the CHAR rims, reading as dark scribble on the one part of the
#      face anybody looks at.
#   3. NO PAD. The snout is the same cracked rock as the rest of the animal.
#
# THE THIRD IS OBVIOUSLY RIGHT AND THE FIRST TWO ARE THE SAME MISTAKE: this
# animal is not a pig wearing a coat, it is a pig MADE OF something, and a
# thing made of one material does not have a nose made of another. The
# nostrils are geometry and read on their own.
#
# EMBER SURVIVES ON THE INNER EAR, where it is not a pad on a surface -- it is
# a glimpse INTO the animal, which is the one place a second colour is
# honest.

# SMALLER CELLS TOWARD THE NOSE, which is the one thing in the giraffe that is
# not an addend on `gap` and could not have been -- its own comment explains
# why, and the reasoning survives the inversion unchanged. What sets the NUMBER
# of plates is `scale`, and `scale` is an input socket, so it can be driven by
# position: the cells get smaller toward the nose, and the same `gap` then
# leaves more, finer cracks instead of the same few running across a face only
# two cells wide.
#
# WHAT IT COSTS is that a Voronoi with a varying scale has slightly STRETCHED
# cells wherever the gradient is. Kept mild and checked by looking.
# AND THE MULTIPLIER IS SMALL, WHICH TOOK THREE GOES AND IS THE OPPOSITE OF
# WHAT THE GIRAFFE WANTS. At 1.45 the cells on the snout are less than half the
# body's, and once the ember pad went UNDER the bands that turned the one part
# of the face anybody looks at into fine CRAZING -- a scribble rather than a
# crack, and busier than anything else on the animal.
#
# A GIRAFFE WANTS MORE, SMALLER PATCHES ON A FACE BECAUSE A PATCH IS A MARK; A
# CRACK IS A STRUCTURAL FAILURE AND THERE IS NO SUCH THING AS A DELICATE ONE.
# Rock breaks at about one size wherever it is. 1.15 leaves the snout a few
# bold cracks over the ember, which is the picture.
HEAD_FINE = dict(lo=-1.10, hi=-0.34, mul=1.15)

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
    """The crust as one material. Built twice -- once for the body and
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

    # ---- where the fire is, which is the giraffe's belly re-aimed -----
    # THE SAME TWO NODES DOING THE OPPOSITE JOB. On the giraffe this pair
    # draws a cream underside and then takes the legs back out of it, because
    # a mask that is purely "low is cream" paints four white posts. Here the
    # legs are wanted -- a pig standing in lava has hot feet -- so the second
    # half is gone and `PAW_HEAT` below adds to them instead.
    #
    # THE TILT IS KEPT AND IT IS DOING MORE WORK THAN IT DID THERE. Measuring
    # the boundary on `z + tilt*y` puts the heat higher at the nose and lower
    # at the tail, so the glow is not a bathtub ring round the widest part of
    # a sphere -- which is the one thing that would say "this is a texture"
    # rather than "this is on fire".
    lift = math('MULTIPLY_ADD', -2200, 900, "z + tilt*y", b=0.30)
    link(Y, lift.inputs[0])
    link(Z, lift.inputs[2])
    belly = rng(-2000, 900, "hotter underneath",
                BELLY_HEAT['lo'], BELLY_HEAT['hi'], BELLY_HEAT['add'], 0.0)
    link(lift.outputs[0], belly.inputs['Value'])

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
               CRUST['scale'] * HEAD_FINE['mul'], CRUST['scale'])
    link(Y, fine.inputs['Value'])

    edge_v.inputs['Randomness'].default_value = CRUST['randomness']
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
    cell_v.inputs['Randomness'].default_value = CRUST['randomness']
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
                CRUST['gap'] - CRUST['cell_vary'],
                CRUST['gap'] + CRUST['cell_vary'], interp='LINEAR')
    link(cell, cellg.inputs['Value'])

    wb_off, wb = snoise(-2200, -1000, "LANE WANDER",
                        CRUST['wobble_scale'], (11.0, 4.0, -7.0))
    link(co.outputs['Object'], wb_off.inputs[0])
    wb_s = math('MULTIPLY', -1700, -1000, "wander amount",
                b=CRUST['wobble'])
    link(wb.outputs['Result'], wb_s.inputs[0])

    gr_off, gr = snoise(-2200, -1300, "RAGGED EDGE",
                        CRUST['grain_scale'], (-6.0, 13.0, 5.0), detail=3.0)
    link(co.outputs['Object'], gr_off.inputs[0])
    gr_s = math('MULTIPLY', -1700, -1300, "grain amount",
                b=CRUST['grain'])
    link(gr.outputs['Result'], gr_s.inputs[0])

    g1 = math('ADD', -1500, -880, "+ wander")
    link(cellg.outputs['Result'], g1.inputs[0])
    link(wb_s.outputs[0], g1.inputs[1])
    g2 = math('ADD', -1320, -900, "+ grain")
    link(g1.outputs[0], g2.inputs[0])
    link(gr_s.outputs[0], g2.inputs[1])

    # ---- and where the crust is thicker or thinner -------------------
    # EVERY ONE OF THESE MOVES THE ONE NUMBER, which is the giraffe's whole
    # architecture and the reason there is no second mask anywhere in this
    # file: a crack cannot be opened by one rule and closed by another,
    # because there is one field and one threshold.
    #
    # WHAT IS NEW IS THAT TWO OF THEM PUSH THE OTHER WAY. The giraffe's
    # addends all widened its lanes, so a MAXIMUM over them was the whole of
    # it. Here the belly and the paws ADD and the muzzle and the eyes
    # SUBTRACT, so the two families are gathered separately and differenced
    # once -- and a MAXIMUM still holds WITHIN each family, for the giraffe's
    # own reason: the chin is muzzle AND underside, and summing them there
    # would move `gap` twice as far as either rule asked for.
    paw = rng(-2200, 300, "hotter at the paw",
              PAW_HEAT['lo'], PAW_HEAT['hi'], PAW_HEAT['add'], 0.0)
    link(Z, paw.inputs['Value'])
    heat = math('MAXIMUM', -1780, 400, "HOW MUCH HOTTER HERE")
    link(belly.outputs['Result'], heat.inputs[0])
    link(paw.outputs['Result'], heat.inputs[1])

    muz = rng(-2200, 480, "solid toward the nose",
              MUZZLE_CALM['lo'], MUZZLE_CALM['hi'], MUZZLE_CALM['sub'], 0.0)
    link(Y, muz.inputs['Value'])

    # THE EYES, ON THE WIDTH RATHER THAN ON THE MASK -- see `EYE_CALM`.
    # Mirrored on |x| so one number serves both.
    ax = math('ABSOLUTE', -2600, 1300, "mirror onto one eye")
    link(X, ax.inputs[0])
    here = node("ShaderNodeCombineXYZ", -2420, 1300, "this point")
    link(ax.outputs[0], here.inputs['X'])
    link(Y, here.inputs['Y'])
    link(Z, here.inputs['Z'])
    dv = node("ShaderNodeVectorMath", -2240, 1300, "offset from the eye")
    dv.operation = 'SUBTRACT'
    dv.inputs[1].default_value = (EYE_CALM['x'], EYE_CALM['y'], EYE_CALM['z'])
    link(here.outputs['Vector'], dv.inputs[0])
    dl = node("ShaderNodeVectorMath", -2060, 1300, "how far")
    dl.operation = 'LENGTH'
    link(dv.outputs['Vector'], dl.inputs[0])
    eyes = rng(-1880, 1300, "close it up at the eye",
               EYE_CALM['r0'], EYE_CALM['r1'], EYE_CALM['sub'], 0.0)
    link(dl.outputs['Value'], eyes.inputs['Value'])

    crown = rng(-2200, 660, "solid over the back",
                CROWN_CALM['lo'], CROWN_CALM['hi'], 0.0, CROWN_CALM['sub'])
    link(Z, crown.inputs['Value'])

    c1 = math('MAXIMUM', -1780, 180, "")
    link(muz.outputs['Result'], c1.inputs[0])
    link(eyes.outputs['Result'], c1.inputs[1])
    calm = math('MAXIMUM', -1700, 60, "HOW MUCH COLDER HERE")
    link(c1.outputs[0], calm.inputs[0])
    link(crown.outputs['Result'], calm.inputs[1])

    kill = math('SUBTRACT', -1600, 300, "HEAT LESS CALM")
    link(heat.outputs[0], kill.inputs[0])
    link(calm.outputs[0], kill.inputs[1])

    gap = math('ADD', -1140, -880, "GAP HERE")
    link(g2.outputs[0], gap.inputs[0])
    link(kill.outputs[0], gap.inputs[1])

    # ---- how wide the crack is HERE, and never narrower than a texel --
    # THE FLOOR IS NOT TIDINESS -- see `GAP_FLOOR`. `MAXIMUM` rather than a
    # clamp because it says which end is being defended.
    gapc = math('MINIMUM', -1000, -760, "never wider than a plate",
                b=GAP_CEIL)
    link(gap.outputs[0], gapc.inputs[0])
    gapf = math('MAXIMUM', -960, -880, "never thinner than a texel",
                b=GAP_FLOOR)
    link(gapc.outputs[0], gapf.inputs[0])

    # ---- the three bands ---------------------------------------------
    # THRESHOLDS AND NOT RAMPS. The bake runs at 2048 and delivers at 1024, so
    # every delivered texel is the average of four and the downscale is what
    # does the anti-aliasing -- a soft edge in the graph on top of that is
    # mush. See `WORKFLOW.md`.
    #
    # THREE COMPARISONS AGAINST ONE NUMBER, which is what makes the heat map
    # free: `gapf` already carries the belly, the paws, the muzzle, the eyes,
    # the per-cell variation, the wander and the grain, so all of that arrives
    # in the char rim and the core without one extra node.
    charw = math('MULTIPLY', -800, -700, "the char rim reaches this far",
                 b=BANDS['char'])
    link(gapf.outputs[0], charw.inputs[0])
    corew = math('MULTIPLY', -800, -1060, "and the core this far",
                 b=BANDS['core'])
    link(gapf.outputs[0], corew.inputs[0])

    char_raw = math('LESS_THAN', -620, -700, "near enough to be charred?")
    link(edge, char_raw.inputs[0])
    link(charw.outputs[0], char_raw.inputs[1])
    crack_raw = math('LESS_THAN', -620, -880, "inside the crack?")
    link(edge, crack_raw.inputs[0])
    link(gapf.outputs[0], crack_raw.inputs[1])
    core_raw = math('LESS_THAN', -620, -1060, "inside its core?")
    link(edge, core_raw.inputs[0])
    link(corew.outputs[0], core_raw.inputs[1])

    # ---- which plates are ash -----------------------------------------
    # A CUT ON THE PER-CELL RANDOM, not a noise. A noise would put ash and
    # obsidian on the SAME plate with a border through the middle of it, which
    # is a plate that is two rocks -- and every one of these is supposed to be
    # a single slab that cracked off in one piece.
    #
    # It reads the same `cell` the gap variation reads, which is deliberate
    # and is worth knowing before either is turned: an ash plate is
    # systematically one of the wider-gapped ones. That correlation is
    # invisible at these amounts and would not be at large ones.
    ashm = math('GREATER_THAN', -1480, -560, "is this plate ash?",
                b=CRUST['ash_cut'])
    link(cell, ashm.inputs[0])

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

    # SIX COLOURS, LAID IN ORDER FROM THE ROCK OUTWARD. Each mix's factor is
    # a 0/1 mask, so anything mixed BEFORE it shows through wherever that mask
    # is 0 and is covered wherever it is 1 -- which is what lets the plate
    # carry two tones and still be completely hidden inside a crack.
    #
    # The order is the physical one: plate, then the char nearest the heat,
    # then the crack, then its core. Each band is a SUBSET of the one before
    # it, so nesting them costs nothing and no mask has to know about another.
    m1, f1, a1, b1, o1 = mix_rgb(nt, "obsidian -> ash, per plate")
    m1.location = (-200, 900)
    a1.default_value = to_linear(OBSIDIAN) + (1.0,)
    b1.default_value = to_linear(ASH) + (1.0,)
    link(hard(ashm.outputs[0], -1300, -560, "the ash plates"), f1)

    # ---- WHICH TEXELS THE GAME GETS TO DRIVE --------------------------
    # THE CORES, AND NOTHING ELSE. A node labelled `ALPHA_MASK` is the one
    # thing `make/bake_alpha.py` looks for: 1 where the baked picture should
    # win, 0 where the part's own `Color3` should come through -- and
    # `ClientMain`'s skin animator rewrites that colour every Heartbeat.
    #
    # So this one node is the whole of how a Blender file says WHICH PARTS
    # ANIMATE. There is no other channel that can: a `SurfaceAppearance`
    # carries colour, normal, metalness and roughness and nothing that means
    # "emit" or "animate", so `AlphaMode.Overlay`'s
    # `lerp(part.Color, map.RGB, map.Alpha)` is the only per-texel switch the
    # format has. `Config.SURFACE_PACKS.bands` already ships on it, using it
    # for tint where this uses it for motion.
    #
    # THE CORE AND NOT THE WHOLE CRACK, which is a real choice rather than a
    # convenience. Handing the crack over as well would animate about three
    # times the area, and the animal would read as a pig changing colour
    # rather than as rock with something moving inside it. The deep orange
    # crack staying PUT is what the core is seen to move against.
    #
    # IT IS BUILT UNCONDITIONALLY AND COSTS NOTHING WHEN UNUSED. The alpha
    # pass is a separate command, so the fallback -- a completely static
    # Magma, exactly as it renders today -- is simply not running it, and the
    # colour sheet is byte-identical either way.
    core_hard = hard(core_raw.outputs[0], -440, -1060, "the core")
    alpha_mask = math('SUBTRACT', -260, -1240,
                      "OPAQUE EVERYWHERE BUT THE CORE", a=1.0)
    alpha_mask.label = "ALPHA_MASK"
    link(core_hard, alpha_mask.inputs[1])

    m2, f2, a2, b2, o2 = mix_rgb(nt, "char the rim")
    m2.location = (0, 700)
    b2.default_value = to_linear(CHAR) + (1.0,)
    link(hard(char_raw.outputs[0], -440, -700, "the charred rim"), f2)
    link(o1, a2)

    m3, f3, a3, b3, o3 = mix_rgb(nt, "open the crack")
    m3.location = (200, 700)
    b3.default_value = to_linear(CRACK) + (1.0,)
    link(hard(crack_raw.outputs[0], -440, -880, "the crack"), f3)
    link(o2, a3)

    m4, f4, a4, b4, o4 = mix_rgb(nt, "and light its core")
    m4.location = (400, 700)
    b4.default_value = to_linear(CORE) + (1.0,)
    link(core_hard, f4)
    link(o3, a4)

    bsdf = node("ShaderNodeBsdfPrincipled", 620, 400)
    bsdf.inputs['Roughness'].default_value = 0.88
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.08
    link(o4, bsdf.inputs['Base Color'])
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

body_mat = coat("magma_body")
trim_mat = coat("magma_trim")
ear_mat = flat("magma_ear_inner", EMBER)

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
assign(bpy, ASSIGN, "MAGMA  (from %s)" % SRC)

for _n, _c in face_slots(bpy, [n for n, _ in ASSIGN]):
    if len(_c) > 1:
        print("  %-6s faces per slot %s  <- hand selection, intact"
              % (_n, _c))

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("")
print("  saved %s -- %s is untouched"
      % (os.path.relpath(OUT, D), os.path.relpath(SRC, D)))
print("  about %d plates across the body, crack %.3f of a cell wide,"
      " char to %.3f, core to %.3f"
      % (round(CRUST['scale'] * 2.0), CRUST['gap'] * 2.0,
         CRUST['gap'] * 2.0 * BANDS['char'],
         CRUST['gap'] * 2.0 * BANDS['core']))
