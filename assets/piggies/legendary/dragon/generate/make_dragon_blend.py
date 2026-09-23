# -*- coding: utf-8 -*-
"""Build the DRAGON as a node graph, in its own blend file.

    blender.exe --background --python assets/piggies/legendary/dragon/generate/make_dragon_blend.py

Then the ordinary loop, plus the alpha pass:

    blender.exe --background --python make/bake_skin.py   -- --skin dragon
    blender.exe --background --python make/bake_alpha.py  -- --skin dragon
    python make/apply_alpha.py --skin dragon

THE PATTERN IS DEFINED IN 3D, NEVER IN UV SPACE -- see `WORKFLOW.md`.

A LEGENDARY IN THIS CRATE IS A CREATURE PLUS AN ELEMENT, and the creature half
has to win. `docs/animal-crate-plan.md` records the round where that was got
wrong: Magma and Stained Glass are good skins and neither is an ANIMAL, in a
crate called Animal Kingdom. A dragon is the answer to that -- a beast anybody
recognises, whose element is built into what it IS rather than painted on.

WHAT MAKES A SCALE A SCALE AND NOT A PATCH, WHICH IS ONE NUMBER.

This is the giraffe's cell field for the third time -- Magma read it inside out
and Stained Glass drew its lanes last -- and the risk of a third was always
that all three end up rhyming. `docs/animal-crate-plan.md` names the lever that
separates them as the CELL SHAPE, and this is that lever pulled properly:

**THE COORDINATE IS STRETCHED BEFORE THE CELLS ARE MEASURED.** A Voronoi walks
whatever space it is handed, so scaling the input by `(1, 1, 1/squash)` divides
the world along the animal's own nose-tail axis and hands the node a squashed
copy of it. The cells it finds there are round; unsquashed back onto the pig
they are WIDE AND SHORT -- which is what a scale is, and what a giraffe's
patch, a lava plate and a leaded pane are all not.

Neither of the other two touches the input vector at all. One `Vector Math ->
Multiply` is the whole difference between a reptile and crazy paving.

FOUR TONES OF SCALE, PICKED PER CELL, and that is the second thing carrying
it. A giraffe's patches are one brown; a dragon's hide is never one green, and
a flat field of identical scales reads as a golf ball. The per-cell random the
giraffe already computes for its gap variation is read a second time here as a
COLOUR index -- so a scale's tone is a fact about that scale, and two
neighbours can differ without a second pattern anywhere.

THE FIRE IS UNDERNEATH AND IT IS THE ELEMENT. The belly plates are warm gold
rather than green, and the seams between the scales GLOW where the heat is --
brightest under the chest and dying out over the shoulder. That is the same
call Magma makes about putting the fire below, for the same reason: a pig is
looked at from the pavement, so the flank and the underside are what anybody
sees, and heat on the crown is heat nobody will meet.

AND THE GLOWING SEAMS ARE WHAT THE GAME ANIMATES. A node labelled `ALPHA_MASK`
hands them to `ClientMain`'s skin animator -- see `make/bake_alpha.py` -- so a
dragon breathes: the seams cycle while the scales hold. The region is ONE
colour, which is the constraint that matters (`docs/animal-crate-plan.md`, "what
the alpha pass cannot be used for"): every alpha-0 texel gets the same
`Color3`, so a multi-coloured region would collapse to one and lose the rest.

THE COORDINATE FRAME IS THE PIG'S OWN, measured off the mesh:

    x   across          body reaches +-1.000
    y   NOSE to TAIL    snout tip -1.381, body -1.080..1.052, tail tip 1.465
    z   floor to CROWN  legs -1.020, body -0.960..0.960, ear tip 1.309

So -Y is the face and +Z is up.

WHAT THIS FILE DOES NOT DO IS THE SPINE RIDGE. A dragon wants one and the game
can give it one: `Config.FUR_SETS.crest` is a separate mesh welded on at
runtime, and `make/make_fur_tufts.py` already builds a `crest-fore` and a
`crest-aft` running from the forehead over the crown to the rump. Fur takes a
flat `Color3` and no texture at all -- `PiggyBank.applyFur`: "THE MESH IS THE
FLAG. A skin asks for fur by carrying a `fur` colour" -- so there is nothing
here to paint for it. It needs one upload and a Config field, and both are
outside a skin script.
"""

# --- find the toolkit, wherever this script has been filed ------------------
# Walks up from this file until it finds the folder holding `paths.py`. Depth
# independent on purpose: a script in `make/` and a generator in `assets/piggies/legendary/dragon/generate/`
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
OUT = arg("--out", paths.skin_blend("dragon"))

# --------------------------------------------------------------- the colours
# NOT READ OUT OF `Config.luau`, for the reason Magma's are not: there is no
# `dragon` row to disagree with yet. When one is written it should take
# SCALE_MID and BELLY, which are the two a fallback pair would want.

# THE FOUR SCALE TONES, PICKED PER CELL. Green-black rather than green: a
# dragon read from the pavement is a DARK animal with a warm underside, and a
# mid-green pig reads as a frog. The spread between them is deliberately small
# -- these have to say "hide" rather than "harlequin", and the moment two
# neighbouring scales differ enough to be NAMED as different colours the field
# stops being one animal's skin.
SCALE_DARK = (24 / 255., 38 / 255., 32 / 255.)
SCALE_MID = (36 / 255., 54 / 255., 44 / 255.)
SCALE_LIT = (52 / 255., 74 / 255., 58 / 255.)
# The fourth is the one that does the most work per texel: a few scales a shade
# WARM, so the green has something to be green against and the fire underneath
# has somewhere to have touched.
SCALE_WARM = (62 / 255., 62 / 255., 42 / 255.)

# THE SEAM between scales. Near-black and warm, never neutral -- the same call
# Magma's obsidian makes, and for the same reason: a blue-black beside a warm
# glow reads as a bruise.
SEAM = (12 / 255., 16 / 255., 14 / 255.)

# THE BELLY PLATES. Gold rather than pale, because the pale-underside trick
# every real animal in this catalogue uses says "mammal" and a dragon's
# underside is armour. This is the one colour a nine-year-old will name.
BELLY_PLATE = (154 / 255., 116 / 255., 46 / 255.)
BELLY_DARK = (112 / 255., 80 / 255., 30 / 255.)

# THE GLOW IN THE SEAMS, and the one region the game animates. Authored at the
# value the fire sits at when nothing is driving it, because that is what shows
# if a `Config.SKINS.dragon` row is ever written without an `anim` block.
EMBER = (232 / 255., 108 / 255., 26 / 255.)

# THE INNER EAR. Every other skin puts a pig's pink here; a dragon has fire
# inside it, and the ear is the one place that reads as looking INTO the
# animal rather than at it. Same call Magma makes.
EAR_INNER = (206 / 255., 84 / 255., 28 / 255.)

# --------------------------------------------------------------- the tunables
SCALES = dict(
    # HOW MANY. Cells per stud before the squash, so the body's 2.0 studs
    # across carries about `2*scale` rows of them. Finer than any skin here so
    # far -- a scale is small, and this is the number that decides whether the
    # animal reads as reptile or as tortoise.
    scale=4.6,
    # THE SQUASH, AND THE WHOLE IDEA. The input vector is divided by this along
    # the nose-tail axis before the Voronoi walks it, so the cells come back
    # WIDE ACROSS THE ANIMAL and SHORT ALONG IT. At 1.0 this file is the
    # giraffe with different colours; at 2.0 the scales are twice as wide as
    # they are long, which is a fish; 1.55 is a reptile.
    squash=1.55,
    # HOW REGULAR. LOW, which is the opposite of Magma's 0.88 and the point of
    # the contrast: cooling rock fractures unevenly and a reptile's scales are
    # GROWN in rows. Not zero -- a perfect lattice reads as a knitted jumper.
    randomness=0.34,
    # HALF THE SEAM WIDTH, in cell units. Thin: the seam is a line between
    # scales rather than a channel, and past about 0.09 the animal starts
    # reading as chainmail.
    gap=0.055,
    # PER CELL, so two scales sharing a seam can sit at different depths.
    cell_vary=0.016,
    # THE WANDER, kept SMALL for the reason `randomness` is. A seam that
    # wanders is a torn scale.
    wobble=0.014, wobble_scale=3.0,
    # THE RAGGED EDGE. Almost nothing -- a scale has a clean edge, and this is
    # here only to stop the seams reading as vector art.
    grain=0.005, grain_scale=24.0,
    # WHERE THE FOUR TONES FALL on the per-cell random. Three cuts, and they
    # are uneven on purpose: mostly mid, a good number dark, fewer lit, and
    # WARM the rarest of the four so it reads as an accent rather than as a
    # fourth of the animal.
    cut_dark=0.34, cut_lit=0.72, cut_warm=0.90,
)

# THE BELLY. Gold plates below, green scales above, and a hard line between
# them -- `WORKFLOW.md`'s "Nothing fades" forbids the ramp every other skin
# here uses for an underside, and on a dragon the hard line is RIGHT: armour
# plating has an edge where hide does not.
BELLY = dict(
    hi=-0.24, lo=-0.62,
    # THE TILT, so the gold is not a bathtub ring round the widest part of a
    # sphere. Higher at the chin, lower at the haunch.
    tilt=0.34,
    # And the legs come back out of it, or the animal has four gold posts.
    leg_lo=-0.78, leg_hi=-0.58,
    # A few belly plates run DARK, the same way the scales do, so the
    # underside is not one flat sheet of gold.
    cut=0.62,
)

# THE LIP. The one place a reptile's scales genuinely run out, and the one
# addend on `gap` this file keeps. `hi` sits forward of the eyes at y -0.889
# for the giraffe's reason: any further back and the scales are already
# thinning where they meet the eye, which reads as a halo drawn by a different
# mechanism rather than as a muzzle.
MUZZLE = dict(lo=-1.30, hi=-0.98, add=0.085)

# THE EYES. Scales stand off them rather than running to the rim -- a marking
# that touches an eyeball reads as a smear, which is `WORKFLOW.md` rule 6.
# Folded in with MAXIMUM rather than summed: an eye sits close enough to the
# muzzle ramp that adding the two would open a hole neither asked for.
EYE_RING = dict(x=0.318, y=-0.889, z=0.364, r0=0.17, r1=0.40, add=0.14)

# WHERE THE SEAMS GLOW. Measured on the same tilted plane the belly is, so the
# fire and the armour agree about where the underside is rather than being two
# opinions about it.
# AND IT SITS ABOVE THE ARMOUR RATHER THAN OVER IT, which took a
# measurement to get right. The fire is masked by `NOT plate` (see the graph),
# so wherever this band overlaps the plate the two cancel -- and the first two
# values overlapped it almost exactly, leaving the glow alive only in a sliver
# a few hundredths of a stud wide and visible on nothing but the feet.
#
# `lo` therefore sits ABOVE the plate's own `hi` of -0.24: the glow is strong
# from just above the armour line and dies out over the shoulder, so what
# reads is a band of lit hide between gold below and cold green above. Any
# edit to `BELLY.hi` has to move this with it or the fire goes out.
HEAT = dict(hi=0.42, lo=-0.12)

# NOTHING ON THIS ANIMAL FADES INTO ANYTHING ELSE.
#
# Every texel is one of the nine colours above and never a blend of two. It is
# enforced at the graph's output rather than asked of each mask: every factor
# reaching a colour mix goes through `hard`. See `WORKFLOW.md`.
NO_FADING = True

# THE SNOUT. No pad, and the reasoning is Magma's, arrived at there over three
# builds: this animal is not a pig wearing a coat, it is a pig MADE of
# something, and a thing made of one material does not have a nose made of
# another. The nostrils are geometry and read on their own.
NOSE = dict(lo=-1.30, hi=-1.16)

# SMALLER CELLS TOWARD THE NOSE. A real reptile's scales are finest on the
# face, and the giraffe's own note explains why this cannot be an addend on
# `gap`: past a cell's inradius a bigger gap deletes the pattern rather than
# refining it. `scale` is an input socket, so it can be driven by position.
HEAD_FINE = dict(lo=-1.10, hi=-0.34, mul=1.30)

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
    """The hide as one material. Built twice -- once for the body and
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

    # ---- the belly plates, and the heat, on ONE tilted plane ----------
    # TWO MASKS OFF ONE MEASUREMENT, so the armour and the fire cannot
    # disagree about where the underside is. On the giraffe this pair draws a
    # cream belly; here the lower half is GOLD PLATE and the seams between the
    # scales glow over roughly the same ground.
    lift = math('MULTIPLY_ADD', -2200, 900, "z + tilt*y", b=BELLY['tilt'])
    link(Y, lift.inputs[0])
    link(Z, lift.inputs[2])

    belly_a = rng(-2000, 900, "plated below", BELLY['lo'], BELLY['hi'],
                  1.0, 0.0)
    link(lift.outputs[0], belly_a.inputs['Value'])
    leg_out = rng(-2000, 700, "but not the legs",
                  BELLY['leg_lo'], BELLY['leg_hi'], 0.0, 1.0)
    link(Z, leg_out.inputs['Value'])
    belly = math('MULTIPLY', -1780, 820, "PLATE MASK")
    link(belly_a.outputs['Result'], belly.inputs[0])
    link(leg_out.outputs['Result'], belly.inputs[1])

    # THE FIRE REACHES HIGHER THAN THE ARMOUR DOES, deliberately. If the two
    # ended together the gold would have a glowing outline and read as a
    # sticker; letting the heat die out over the shoulder instead means the
    # green scales nearest the belly are the ones lit from below, which is
    # where a fire inside the animal would actually show.
    heat = rng(-2000, 1100, "lit from underneath", HEAT['lo'], HEAT['hi'],
               1.0, 0.0)
    link(lift.outputs[0], heat.inputs['Value'])

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
               SCALES['scale'] * HEAD_FINE['mul'], SCALES['scale'])
    link(Y, fine.inputs['Value'])

    # ---- THE SQUASH, AND IT IS THE WHOLE SKIN -------------------------
    # A Voronoi walks whatever space it is handed. Divide the input along the
    # animal's own nose-tail axis and the node finds ROUND cells in a squashed
    # world -- which, unsquashed back onto the pig, are WIDE ACROSS IT and
    # SHORT ALONG IT. That is a scale.
    #
    # Neither Magma nor Stained Glass touches the input vector at all, and all
    # three of us are the giraffe's cell field. `docs/animal-crate-plan.md`
    # names cell SHAPE as the lever that has to separate them; this is it, and
    # it is one node.
    #
    # IT HAS TO FEED BOTH VORONOI NODES, off the same output, for the giraffe's
    # own reason: the lattice is a function of scale, randomness and the input
    # vector, so the moment the two disagree about any of the three the
    # per-cell random stops belonging to the cell it is colouring.
    squash = node("ShaderNodeVectorMath", -2400, -200, "SQUASH: scales, not blobs")
    squash.operation = 'MULTIPLY'
    squash.inputs[1].default_value = (1.0, 1.0 / SCALES['squash'], 1.0)
    link(co.outputs['Object'], squash.inputs[0])

    edge_v.inputs['Randomness'].default_value = SCALES['randomness']
    link(fine.outputs['Result'], edge_v.inputs['Scale'])
    link(squash.outputs['Vector'], edge_v.inputs['Vector'])
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
    cell_v.inputs['Randomness'].default_value = SCALES['randomness']
    link(fine.outputs['Result'], cell_v.inputs['Scale'])
    link(squash.outputs['Vector'], cell_v.inputs['Vector'])
    cellsep = node("ShaderNodeSeparateXYZ", -2000, -560, "per-cell random")
    link(cell_v.outputs['Color'], cellsep.inputs['Vector'])
    cell = cellsep.outputs['X']

    # ---- how far back this patch stands from its own wall ------------
    # EVERYTHING FROM HERE ADDS TO ONE NUMBER, in cell units. That is the whole
    # architecture: there is no second mask anywhere, so a patch cannot be
    # killed by one rule and drawn by another.
    cellg = rng(-2000, -760, "this cell's own gap", 0.0, 1.0,
                SCALES['gap'] - SCALES['cell_vary'],
                SCALES['gap'] + SCALES['cell_vary'], interp='LINEAR')
    link(cell, cellg.inputs['Value'])

    wb_off, wb = snoise(-2200, -1000, "LANE WANDER",
                        SCALES['wobble_scale'], (11.0, 4.0, -7.0))
    link(co.outputs['Object'], wb_off.inputs[0])
    wb_s = math('MULTIPLY', -1700, -1000, "wander amount",
                b=SCALES['wobble'])
    link(wb.outputs['Result'], wb_s.inputs[0])

    gr_off, gr = snoise(-2200, -1300, "RAGGED EDGE",
                        SCALES['grain_scale'], (-6.0, 13.0, 5.0), detail=3.0)
    link(co.outputs['Object'], gr_off.inputs[0])
    gr_s = math('MULTIPLY', -1700, -1300, "grain amount",
                b=SCALES['grain'])
    link(gr.outputs['Result'], gr_s.inputs[0])

    g1 = math('ADD', -1500, -880, "+ wander")
    link(cellg.outputs['Result'], g1.inputs[0])
    link(wb_s.outputs[0], g1.inputs[1])
    g2 = math('ADD', -1320, -900, "+ grain")
    link(g1.outputs[0], g2.inputs[0])
    link(gr_s.outputs[0], g2.inputs[1])

    # ---- and where the seams open up ---------------------------------
    # ONE ADDEND RATHER THAN THE GIRAFFE'S FOUR, because a reptile is scaled
    # ALL OVER and the giraffe's other three exist to take patches off ground
    # that should be plain. There is no plain ground on a dragon: the belly
    # changes COLOUR rather than losing its pattern, which is what the plate
    # mask does further down.
    #
    # The muzzle keeps its addend because the scales genuinely do run out on
    # the lips, and because `HEAD_FINE` above has already made them finest
    # exactly there -- so without this the snout is the only crazed part of
    # the animal, which is the fault Magma took three builds to find.
    muz = rng(-2200, 480, "seams open on the lip",
              MUZZLE['lo'], MUZZLE['hi'], MUZZLE['add'], 0.0)
    link(Y, muz.inputs['Value'])

    # THE EYES PUSH THE SCALES BACK, mirrored on |x| so one number serves both.
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

    kill = math('MAXIMUM', -1600, 300, "WHERE THE SEAMS OPEN")
    link(muz.outputs['Result'], kill.inputs[0])
    link(eyes.outputs['Result'], kill.inputs[1])

    gap = math('ADD', -1140, -880, "GAP HERE")
    link(g2.outputs[0], gap.inputs[0])
    link(kill.outputs[0], gap.inputs[1])

    # ---- inside a scale? ---------------------------------------------
    # A THRESHOLD AND NOT A RAMP -- the bake runs at 2048 and delivers at 1024,
    # so the downscale is what does the anti-aliasing and a soft edge on top of
    # it is mush. See `WORKFLOW.md`.
    scale_raw = math('GREATER_THAN', -940, -880, "far enough from the seam?")
    link(edge, scale_raw.inputs[0])
    link(gap.outputs[0], scale_raw.inputs[1])

    # ---- which of the four tones THIS scale is ------------------------
    # THREE CUTS ON THE PER-CELL RANDOM, which is the same number the gap
    # variation reads. Worth knowing before either is turned: a WARM scale is
    # systematically one of the deeper-seated ones. Invisible at these amounts
    # and would not be at large ones.
    t_dark = math('LESS_THAN', -1480, -420, "this scale is dark",
                  b=SCALES['cut_dark'])
    link(cell, t_dark.inputs[0])
    t_lit = math('GREATER_THAN', -1480, -560, "or lit",
                 b=SCALES['cut_lit'])
    link(cell, t_lit.inputs[0])
    t_warm = math('GREATER_THAN', -1480, -700, "or warm",
                  b=SCALES['cut_warm'])
    link(cell, t_warm.inputs[0])

    # A DARKER PLATE HERE AND THERE, off the same random, so the gold
    # underside is not one flat sheet.
    p_dark = math('GREATER_THAN', -1480, -280, "a deeper plate",
                  b=BELLY['cut'])
    link(cell, p_dark.inputs[0])

    # ---- the seams that are on fire -----------------------------------
    # THE SEAM IS `NOT scale`, and the glowing seam is that AND the heat. One
    # multiply, and it is the region the game gets to drive.
    seam = math('SUBTRACT', -760, -880, "between the scales", a=1.0)
    link(scale_raw.outputs[0], seam.inputs[1])
    hot_raw = math('MULTIPLY', -580, -1040, "and lit from below")
    link(seam.outputs[0], hot_raw.inputs[0])
    link(heat.outputs['Result'], hot_raw.inputs[1])
    # AND NOT ON THE PLATE ITSELF, WHICH THE FIRST BUILD GOT WRONG AND WHICH
    # IS THE WHOLE READ OF THE UNDERSIDE.
    #
    # Letting the fire run over the gold made the plates and the seams between
    # them BOTH warm, so they cancelled and the entire lower half of the animal
    # came back as one orange mass -- no armour, no seams, no fire, just an
    # orange pig standing in an orange pig. Two things that are meant to be
    # read against each other cannot both be the accent colour.
    #
    # Confined to the GREEN, the same two masks say something instead: the
    # scales just above the armour glow between their seams, and the armour
    # below has hard dark seams like the plate it is. The fire reads as
    # something INSIDE the animal showing through the hide, which is where a
    # dragon's fire is, rather than as a puddle it is standing in.
    not_plate = math('SUBTRACT', -760, -1180, "not on the armour", a=1.0)
    link(belly.outputs[0], not_plate.inputs[1])
    hot_g = math('MULTIPLY', -400, -1180, "fire shows through the HIDE")
    link(hot_raw.outputs[0], hot_g.inputs[0])
    link(not_plate.outputs[0], hot_g.inputs[1])
    hot_raw = hot_g

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

    # NINE COLOURS, LAID FROM THE HIDE OUTWARD. Each factor is a 0/1 mask,
    # so anything mixed BEFORE shows through wherever that mask is 0 -- which
    # is what lets the scale field carry four tones and still be completely
    # replaced by plate on the underside.
    #
    # The order is the physical one: the hide, then which scale this is, then
    # the armour over the belly, then the seams between them, then the fire in
    # the seams. Nothing later is a subset of anything earlier here, so the
    # order is load-bearing rather than convenient -- the plate has to land
    # AFTER the tones or it would be four-toned too, and the seam has to land
    # after the plate or the underside would have no seams in it.
    m1, f1, a1, b1, o1 = mix_rgb(nt, "hide -> a darker scale")
    m1.location = (-300, 900)
    a1.default_value = to_linear(SCALE_MID) + (1.0,)
    b1.default_value = to_linear(SCALE_DARK) + (1.0,)
    link(hard(t_dark.outputs[0], -1300, -420, "the dark scales"), f1)

    m2, f2, a2, b2, o2 = mix_rgb(nt, "and a lit one")
    m2.location = (-120, 900)
    b2.default_value = to_linear(SCALE_LIT) + (1.0,)
    link(hard(t_lit.outputs[0], -1300, -560, "the lit scales"), f2)
    link(o1, a2)

    m3, f3, a3, b3, o3 = mix_rgb(nt, "and the rare warm one")
    m3.location = (60, 900)
    b3.default_value = to_linear(SCALE_WARM) + (1.0,)
    link(hard(t_warm.outputs[0], -1300, -700, "the warm scales"), f3)
    link(o2, a3)

    m4, f4, a4, b4, o4 = mix_rgb(nt, "gold plate underneath")
    m4.location = (240, 700)
    b4.default_value = to_linear(BELLY_PLATE) + (1.0,)
    link(hard(belly.outputs[0], -1300, 820, "the belly plates"), f4)
    link(o3, a4)

    m5, f5, a5, b5, o5 = mix_rgb(nt, "a deeper plate here and there")
    m5.location = (420, 700)
    b5.default_value = to_linear(BELLY_DARK) + (1.0,)
    # BOTH CONDITIONS, hardened separately and multiplied: a deep plate is a
    # plate AND an unlucky cell. Hardening the PRODUCT instead would let two
    # halves at 0.7 make a texel that is neither.
    pd = math('MULTIPLY', -1120, -280, "a deep plate")
    link(hard(belly.outputs[0], -1300, 700, "on the belly"), pd.inputs[0])
    link(hard(p_dark.outputs[0], -1300, -280, "and unlucky"), pd.inputs[1])
    link(hard(pd.outputs[0], -960, -280, "a deeper plate"), f5)
    link(o4, a5)

    m6, f6, a6, b6, o6 = mix_rgb(nt, "cut the seams in")
    m6.location = (600, 500)
    b6.default_value = to_linear(SEAM) + (1.0,)
    link(hard(seam.outputs[0], -580, -880, "the seams"), f6)
    link(o5, a6)

    m7, f7, a7, b7, o7 = mix_rgb(nt, "and light the ones underneath")
    m7.location = (780, 500)
    b7.default_value = to_linear(EMBER) + (1.0,)
    hot = hard(hot_raw.outputs[0], -400, -1040, "the burning seams")
    link(hot, f7)
    link(o6, a7)

    # ---- WHICH TEXELS THE GAME GETS TO DRIVE --------------------------
    # THE BURNING SEAMS, AND NOTHING ELSE. A node labelled `ALPHA_MASK` is
    # what `make/bake_alpha.py` looks for: 1 where the baked picture should
    # win, 0 where the part's own `Color3` should come through -- which
    # `ClientMain`'s animator rewrites every frame. So the fire breathes and
    # the hide holds.
    #
    # ONE COLOUR, WHICH IS THE CONSTRAINT THAT DECIDES THIS. Every alpha-0
    # texel gets the SAME `Color3`, so a region carrying several authored
    # colours collapses to one and loses the rest -- see
    # `docs/animal-crate-plan.md`. The burning seams are EMBER and nothing
    # else, so there is nothing to lose. Handing over the scales would have
    # thrown away all four tones and left a cycling pig.
    alpha_mask = math('SUBTRACT', -220, -1240, "OPAQUE BUT THE BURNING SEAMS",
                      a=1.0)
    alpha_mask.label = "ALPHA_MASK"
    link(hot, alpha_mask.inputs[1])

    bsdf = node("ShaderNodeBsdfPrincipled", 620, 400)
    bsdf.inputs['Roughness'].default_value = 0.88
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.08
    link(o7, bsdf.inputs['Base Color'])
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

body_mat = coat("dragon_body")
trim_mat = coat("dragon_trim")
ear_mat = flat("dragon_ear_inner", EAR_INNER)

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
assign(bpy, ASSIGN, "DRAGON  (from %s)" % SRC)

for _n, _c in face_slots(bpy, [n for n, _ in ASSIGN]):
    if len(_c) > 1:
        print("  %-6s faces per slot %s  <- hand selection, intact"
              % (_n, _c))

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("")
print("  saved %s -- %s is untouched"
      % (os.path.relpath(OUT, D), os.path.relpath(SRC, D)))
print("  about %d scale rows across, squashed %.2f along the body,"
      " seam %.3f of a cell"
      % (round(SCALES['scale'] * 2.0), SCALES['squash'],
         SCALES['gap'] * 2.0))
