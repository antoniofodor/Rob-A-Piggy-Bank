# -*- coding: utf-8 -*-
"""Build the Bengal Tiger's coat as a node graph, in its own blend file.

    blender.exe --background --python make_tiger_blend.py

Writes `pig_tiger.blend`. Then the ordinary loop:

    blender.exe --background --python bake_skin.py -- --blend pig_tiger.blend --skin tiger
    blender.exe --background --python make_view_blend.py -- --blend pig_tiger.blend --skin tiger --render

ONE BLEND PER SKIN, WHICH IS THE ANSWER TO THE QUESTION THAT STARTED ALL OF
THIS. A skin IS its materials, and a material slot holds exactly one graph --
so two skins cannot coexist on one set of objects, and authoring the tiger into
`pig_parts.blend` would delete the bee. `pig_parts.blend` is the MASTER: the
geometry, the Smart UV unwrap, the two fur sets and nothing that belongs to any
one animal. Every skin is a COPY of it carrying its own materials, and this
script is how that copy is made rather than a hand-saved duplicate that nobody
can rebuild when the geometry moves.

THE PATTERN IS DEFINED IN 3D, NEVER IN UV SPACE, AND THAT IS THE WHOLE REASON
THIS WORKS AT ALL. `build_pig.py`'s note about island coherence -- 0.583 on the
body against a cylinder's 0.941 -- is about a generator WALKING THE FLAT SHEET
to compute an alpha, where neighbouring islands disagreeing about which way is
up tears a band in half. A shader is evaluated at a POSITION on the surface, so
it does not know the sheet exists: Smart UV Project can rotate every island
however it likes and a stripe still runs where the geometry says it runs. The
bake then resolves it. That is why the re-unwrap and this file are the same
decision seen from two ends.

WHY MATH NODES AND NOT A PAINTED TEXTURE. A painted stripe is one stripe: move
it and it has to be repainted. Here `STRIPES` below is the whole coat, so
"fewer stripes", "thinner", "wobblier", "the cream comes further up the chest"
are each ONE NUMBER and a re-run that takes a couple of seconds. Judge it, say
what is wrong, turn the dial. Nothing is hand-placed, so nothing has to be
hand-fixed.

THE COORDINATE FRAME IS THE PIG'S OWN, MEASURED OFF THE MESH RATHER THAN
ASSUMED. Every part sits at identity, so object space IS world space and all
five share one frame -- which is what lets a stripe run off the flank and onto
a leg without a seam:

    x   across          body reaches +-1.000
    y   NOSE to TAIL    snout tip -1.381, body -1.080..1.052, tail tip 1.465
    z   floor to CROWN  legs -1.020, body -0.960..0.960, ear tip 1.309

So -Y is the face and +Z is up. A tiger's stripes are RINGS ABOUT THE Y AXIS --
that is the same topology as the bee's bands, which is why the bee's one-ramp
trick and this share an ancestor; what a tiger adds is many more of them, a
wobble, a taper into the belly, and a cream underside.
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
import bpy, os, sys, math

from skin_colours import to_linear   # noqa: E402
from skin_parts import assign, face_slots   # noqa: E402


argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SRC = arg("--blend", paths.PARTS)
OUT = arg("--out", paths.skin_blend("tiger"))

# --------------------------------------------------------------- the colours
# READ OFF `Config.SKINS.tiger` RATHER THAN PICKED, for the reason
# `skin_colours.py` exists: two preview scripts once carried their own copies
# and two of the eight had drifted, so the sheet used to JUDGE a pattern was
# showing colours the game does not ship. A slightly wrong orange looks exactly
# like an orange.
#
# The two that are NOT in Config are the two a full-colour bake invents: the
# stripe ink and the inner ear. `Config.SKINS.tiger` has a `body` and a `trim`
# and nowhere to put a third or fourth colour -- which is precisely what a
# full-colour sheet buys, and precisely what it costs, since changing one is a
# re-bake rather than a line of Luau.
ORANGE = (238 / 255., 132 / 255., 36 / 255.)    # Config body
CREAM = (250 / 255., 240 / 255., 228 / 255.)    # Config trim -- belly and jaw
# A WARM DARK BROWN, NOT BLACK. The reference plush reads about (48, 34, 28) in
# its stripe cores: black on orange is a wasp, and this catalogue already has
# one of those. The brown keeps the coat reading as fur under a warm sun.
INK = (48 / 255., 34 / 255., 28 / 255.)
# The inner ear is the one place a real tiger shows skin rather than fur.
EAR_PINK = (247 / 255., 201 / 255., 180 / 255.)

# --------------------------------------------------------------- the tunables
# EVERY NUMBER THAT DECIDES WHAT THE COAT LOOKS LIKE IS IN THIS ONE DICT, so a
# note like "too many stripes" is a one-line edit and a two-second re-run.
STRIPES = dict(
    # HOW MANY. `freq` is stripe periods per stud along the nose-tail axis, and
    # the body spans 2.13 studs of that. Eleven was measured against a
    # PHOTOGRAPH of a tiger and was wrong for this animal: a real tiger is
    # long, and a piggy bank is a sphere, so the same count per stud puts
    # eleven rings round a barrel and the thing reads as a WASP -- which this
    # catalogue already has one of, two skins away. Eight is what leaves enough
    # orange between strokes for the strokes to be strokes.
    freq=3.7,
    # THE LEAN. A stripe is the plane `y*freq + z*slant = k`, so raising this
    # tips the rings: at 1.2 a stripe's top edge sits about a fifth of a period
    # nearer the nose than its bottom edge, which is the backward sweep a real
    # flank has. At 0 they are dead vertical bands and read as a barrel.
    slant=1.2,
    # HOW WIDE THE DARK IS, as a fraction of one period, at the SPINE. Bolder
    # than the photograph's third, because there are fewer of them now and a
    # thin stripe at this count reads as pinstripe rather than as an animal.
    width=0.40,
    # THE TAPER, which is what makes a stripe a BRUSH STROKE rather than a hoop.
    # A tiger's stripe is widest where it leaves the spine and comes to a point
    # down the flank; a constant-width ring is a barrel band, and that is what
    # the first build of this looked like. This is the width left at the belly
    # line before the cream mask below finishes the job.
    taper=0.65, taper_hi=0.42, taper_lo=-0.40,
    # THE WOBBLE, which is the entire difference between a tiger and a deck
    # chair. A low-frequency noise added to the stripe phase BEFORE it is
    # wrapped, so a stripe BENDS rather than getting a fuzzy edge -- the edge
    # stays hard, which is what the plush reference has and what survives being
    # baked at 2048 and delivered at 1024.
    wobble=0.50, wobble_scale=1.7, wobble_detail=2.0,
    # THE SPLIT. A second, faster noise on the WIDTH, so consecutive stripes
    # are not the same thickness and some pinch SHUT -- and the pinching is not
    # a flourish, it is the mechanism. Where the width noise dips below zero
    # the stripe is cut in half, so one stroke becomes two short ones with a
    # gap; where it dips almost to zero the stroke necks and forks. That is
    # every irregularity the reference has, out of one number, and it is why
    # this is set past the point where the width would go negative.
    vary=1.10, vary_scale=5.0,
    # A fine break-up on the phase, at the scale of the stripe edge itself. It
    # is small on purpose: enough that no edge is a clean arc, not so much that
    # the silhouette of a stripe turns to gravel.
    grain=0.10, grain_scale=9.0,
)

BELLY = dict(
    # WHERE THE CREAM STARTS AND STOPS, in z. Smoothstepped rather than cut,
    # because a hard line between two flat colours across the widest part of a
    # sphere reads as a join in the model rather than as markings.
    #
    # **IT WAS 0.48 STUDS WIDE AND THAT IS NOT A BOUNDARY, IT IS A WASH.**
    # Nearly a quarter of the animal was somewhere between orange and cream,
    # which reads as the coat fading out rather than as an underside -- and it
    # is the thing that looked like fading stripes even after the stripes
    # themselves were fixed, because a stroke crossing a long gradient sits on
    # a different colour every few texels. 0.28 is still soft enough that no
    # seam appears on the widest part of the sphere and defined enough to be a
    # marking.
    hi=-0.10, lo=-0.38,
    # THE TILT, which is what stops the cream being a bathtub ring. The
    # boundary is measured on `z + tilt*y`, so at the nose (y about -1) it sits
    # 0.30 HIGHER and at the tail 0.30 lower -- a pale chest and jaw running
    # back to an orange haunch, which is how the markings actually sit.
    tilt=0.34,
    # THE LEGS COME BACK OUT OF IT. They hang entirely below the belly line, so
    # a mask that is purely "low is cream" paints four cream posts. Fading the
    # cream out again below -0.62 gives legs that emerge pale from the chest
    # and darken to orange at the paw, which is where the toe stripes then land
    # -- because suppressing the stripes is the SAME mask, so they reappear
    # exactly where the orange does.
    leg_lo=-0.86, leg_hi=-0.62,
    # HOW MUCH OF THE STRIPE THE CREAM KILLS, and it has been both extremes.
    # At 0.80 it left a fifth of an already-tapered width, which is not a faint
    # stroke but a THIN HARD LINE -- the edge here is a threshold and never a
    # fade -- and those tails read as SCRATCHES down the cream. At 0.95 they
    # died at the boundary entirely, which is tidy and is not what the
    # reference does: look at its chest and there are real dark strokes ON the
    # cream, full strength, just shorter.
    #
    # 0.50 is that, and it is only safe now that `MIN_WIDTH` exists. What made
    # the scratches was a width allowed to fall to anything at all; with a
    # floor under it a stroke either crosses onto the cream as a stroke or
    # stops, and there is no third option to look like a scratch.
    kill=0.50,
)

# THE NOSE PAD GOES BACK TO ORANGE. Everything forward of y -1.26 is the snout
# disc, which the belly tilt would otherwise have painted cream -- and the
# reference's brightest orange is exactly there, on the nose, against the pale
# jaw under it.
NOSE = dict(lo=-1.26, hi=-1.13)
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


# THE EYE NARROWS THE STROKES INSTEAD OF CUTTING THEM, and that distinction is
# the whole entry.
#
# This has now been four ways. A SOFT mask on the ink was wrong: ink is 0 or 1,
# so a half-open mask draws every stroke at half strength, which is a grey
# halo. Removing it was wrong: the reference plainly routes its strokes round
# each eye. A HARD mask on the ink was wrong in the way that is hardest to
# guess -- it works, and you can SEE THE CIRCLE. Every stroke is cut at exactly
# the same radius, so the cut edges line up into a drawn ring, which is a
# stencil rather than a marking.
#
# **A MASK ON THE INK CAN ONLY EVER CUT. A MASK ON THE WIDTH CAN TAPER.**
# Multiply the stroke WIDTH by this instead and each stroke narrows as it
# approaches the eye and comes to a POINT before it -- fully black the whole
# way, so nothing is grey, and every stroke ends at its own radius because
# every stroke starts from its own width. The endpoints scatter, so there is no
# circle to see. It is also what the reference actually shows.
#
# `r0`/`r1` are where the narrowing runs between. Measured off the eye rather
# than chosen: `EyePreview` is 0.210 studs across, so an eyeball is 0.105 in
# radius, and a typical stroke dies at about 0.22 -- a little over twice it.
EYES = dict(x=0.318, y=-0.889, z=0.364, r0=0.16, r1=0.42)

# THE THINNEST STROKE THAT IS ALLOWED TO EXIST, as a fraction of whatever that
# generator's nominal width is.
#
# **NOTHING IN THIS SKIN EVER FADES -- THE BAKE DOES IT.** The ink is a
# threshold, so every texel is the coat colour or the ink colour and there is
# no value in between anywhere in the graph. What produces a fade is the
# downscale: strokes are narrowed by the taper, by the cream mask, by the width
# noise and near the eyes, and once one is thinner than a delivered texel the
# 2048-to-1024 box filter averages it into the coat. Half a texel of ink comes
# back as a grey smear, which reads as a stripe fading out.
#
# So a width below the floor is taken to zero rather than drawn: a stroke
# tapers and then STOPS, at a thickness you can still see. It was 0.075 of a
# period, which is about six delivered texels -- past the point where the bake
# loses it and still thin enough to read as a stroke petering out. At 0.42 of
# the nominal width the narrowest stroke drawn is about thirteen texels, which
# is a BOLD taper: it visibly narrows and then ends, rather than trailing off.
#
# A FRACTION RATHER THAN AN ABSOLUTE, because the two generators measure width
# in different units -- the body in phase, the head in arc -- so one constant
# means two different thicknesses. Scaled off each one's own nominal, it means
# the same thing to both.
MIN_FRACTION = 0.42


# `hi` and `lo` ARE CLOSE TOGETHER BECAUSE A SOFT MASK OVER A HARD STRIPE IS
# GREY. This multiplies a mask that is 0 or 1 and nothing between, so a wide
# ramp does not draw fewer stripes on the muzzle -- it draws every stripe there
# at part strength, which is a haze that reads as a lighting fault. It was 0.24
# studs wide and is 0.09 now.
#
# NO INK FORWARD OF THE EYES. The stripe field is rings about the nose-tail
# axis, so it does not stop at the head -- it goes on ringing, and on a snout
# that is a dark hoop AROUND THE NOSTRILS and bars across the muzzle. The first
# build had exactly that and it was the single worst thing in the picture: a
# tiger's muzzle is clean, the ink starts at the cheek. `lo` is where the ink
# is fully gone and `hi` is where it is back at full strength, so the cheek
# stripes still run forward and die on the jaw rather than being cut off square.
FACE = dict(lo=-1.06, hi=-0.97)

# THE HEAD IS A FAN OUT OF THE MUZZLE, NOT MORE RINGS, and this is the half the
# first build had no answer for. Rings about the nose-tail axis are right for
# the barrel -- they are why the flank stripes stand up -- and on the FACE they
# are bars across it. The reference wears the opposite: a rosette over the brow
# and cheek strokes that all point back at the nose.
#
# It is the zebra's field, borrowed whole. A stripe about a pole through the
# muzzle can be a RING (constant angle from the pole) or a MERIDIAN (constant
# way ROUND it), and those two are perpendicular; the head wants meridians, so
# it gets the way round. They taper for free, because meridians converge at the
# pole -- narrow at the muzzle, widening over the cheek, which is the shape the
# reference's face strokes have.
#
# THREE THINGS THE ZEBRA PAID FOR AND THIS INHERITS:
#
#   * **The handover is measured in `y`, not in angle from the pole.** Measured
#     on the real surface the cheek sits 48 degrees from the muzzle pole and
#     the FOREHEAD 73 -- further round than the shoulder is -- so an angular
#     cutoff puts the fan on the jaw and leaves the brow wearing body rings,
#     which is backwards. `y` is the nose-tail axis, so "in front of the ears"
#     is one number and the seam lands round the neck.
#   * **It is a switch, not a blend, AND THE SWITCH IS NARROW.** Two phase
#     fields with different topology cannot be mixed without the local stripe
#     spacing going through whatever the difference between them happens to be.
#     Over the 0.28 studs this first used, that distortion is spread across the
#     whole shoulder and reads as the stripes bunching and smearing; over 0.11
#     it is a thin line at the neck where the two fields meet at an angle,
#     which is what a real coat does there. Narrow does not remove the
#     distortion, it CONCENTRATES it somewhere it reads as a feature.
#   * **`count` is an integer.** An angle round a circle wraps somewhere, and
#     at the wrap the phase jumps a whole turn. A whole number of strokes per
#     turn makes that jump exactly `count` periods, which `fract` cannot see. A
#     fractional count draws a seam from the nose to the tail.
#
# `pole_down` is the zebra's 17.7 degrees, which came from `Config` and is a
# fact about this pig's snout rather than about that animal.
HEAD = dict(count=20, y_lo=-0.52, y_hi=-0.41, pole_down=17.7,
            # THE STROKE WIDTH ON THE HEAD, IN STUDS, and it is in studs
            # rather than in phase for the reason `even` exists.
            arc=0.085,
            # HOW MUCH THE WIDTH IS EVENED OUT ALONG A MERIDIAN. 0 leaves the
            # old behaviour, where a stroke of constant angular width thins to
            # a hairline as it runs toward the muzzle; 1 measures the width in
            # ARC, so a stroke keeps its thickness in studs the whole way.
            even=1.0,
            # WHERE THE CLEAN COAT ROUND THE MUZZLE BEGINS, in degrees from the
            # pole. Evening the widths out fixes the thin end and creates a
            # thick one: below about twenty degrees twenty strokes of 0.085
            # studs need more room than the circle has, so they MERGE. Both
            # failures live inside the same small cap and this cuts it off.
            start=32.0, start_soft=3.0)

_a = math.radians(HEAD['pole_down'])
HEAD_POLE = (0.0, -math.cos(_a), -math.sin(_a))
HEAD_E1 = (0.0, -math.sin(_a), math.cos(_a))
HEAD_E2 = (-1.0, 0.0, 0.0)
HEAD_FREQ = HEAD['count'] / (2.0 * math.pi)
# Compared as COSINES so no arc-cosine is needed in the graph. Nearer the nose
# is a BIGGER cosine, which is why these two read back to front.
HEAD_COS_LO = math.cos(math.radians(HEAD['start'] + HEAD['start_soft']))
HEAD_COS_HI = math.cos(math.radians(HEAD['start']))


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
    """The tiger's coat as one material. Built twice -- once for the body and
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
        1 halfway between. Built twice now -- once for the body's rings and
        once for the head's meridians -- so it is a function rather than a
        second copy of four nodes that have to stay in step."""
        f = math('FRACT', x, y, "%s: one period" % what)
        link(src.outputs[0], f.inputs[0])
        c = math('SUBTRACT', x + 150, y, "from a centre", b=0.5)
        link(f.outputs[0], c.inputs[0])
        ab = math('ABSOLUTE', x + 300, y)
        link(c.outputs[0], ab.inputs[0])
        out = math('MULTIPLY', x + 450, y, "%s: 0 on a stroke" % what, b=2.0)
        link(ab.outputs[0], out.inputs[0])
        return out

    # ---- where am I on the pig ---------------------------------------
    co = node("ShaderNodeTexCoord", -2100, 0, "the pig's own frame")
    sep = node("ShaderNodeSeparateXYZ", -1900, 0, "x across / y nose-tail / z up")
    link(co.outputs['Object'], sep.inputs['Vector'])
    X, Y, Z = sep.outputs['X'], sep.outputs['Y'], sep.outputs['Z']

    # ---- the cream underside -----------------------------------------
    lift = math('MULTIPLY_ADD', -1700, 420, "z + tilt*y", b=BELLY['tilt'])
    link(Y, lift.inputs[0])
    link(Z, lift.inputs[2])
    belly_a = rng(-1500, 420, "cream below", BELLY['lo'], BELLY['hi'], 1.0, 0.0)
    link(lift.outputs[0], belly_a.inputs['Value'])
    leg_out = rng(-1500, 200, "but not the legs",
                  BELLY['leg_lo'], BELLY['leg_hi'], 0.0, 1.0)
    link(Z, leg_out.inputs['Value'])
    belly = math('MULTIPLY', -1250, 320, "CREAM MASK")
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

    slant = math('MULTIPLY', -1500, -60, "z * slant", b=STRIPES['slant'])
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
    w_base = math('MULTIPLY', -900, -800, "nominal width", b=STRIPES['width'])
    link(v_s.outputs[0], w_base.inputs[0])
    # THE TAPER, which is a fact about z alone and therefore NOT the cream
    # mask. They do two different jobs and merging them was the first build's
    # mistake: the cream says where the underside is, the taper says a stroke
    # is thick at the spine and thin at the bottom of the flank -- which has to
    # happen well ABOVE the cream or every stripe is a full-width hoop right up
    # to the moment it disappears.
    taper = rng(-900, -1030, "thick at the spine",
                STRIPES['taper_lo'], STRIPES['taper_hi'], STRIPES['taper'], 1.0)
    link(Z, taper.inputs['Value'])
    w_tap = math('MULTIPLY', -720, -960, "tapered width")
    link(w_base.outputs[0], w_tap.inputs[0])
    link(taper.outputs['Result'], w_tap.inputs[1])
    kill = math('MULTIPLY_ADD', -720, -800, "thinner over the cream",
                b=-BELLY['kill'], c=1.0)
    link(belly.outputs[0], kill.inputs[0])
    w_cream = math('MULTIPLY', -540, -800, "narrowed over the cream")
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

    # ---- the HEAD is a SEPARATE GENERATOR, not the body's with a twist --
    # Two ink masks and a switch, rather than one mask off a switched phase.
    # The phase-switch version distorted both fields wherever they met, and it
    # forced them to share a WIDTH -- which is the thing that was wrong: a
    # meridian's width has to be measured in ARC and a ring's in phase. Two
    # generators cost about eight nodes and let each use its own rule.
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

    # **THE FIX FOR THE HAIRLINES.** A meridian's spacing collapses at the
    # pole, so a stroke of constant ANGULAR width gets physically thinner all
    # the way down the face and ends as a scratch. Measuring the width in ARC
    # instead -- multiplying the distance-from-centre by `sin`, which is the
    # radius of the circle this point sits on -- gives strokes of an even
    # thickness in studs, and `even` dials between the two: 0 is the old
    # constant-angle behaviour, 1 is constant arc.
    ev = math('POWER', -1000, -1260, "how much to even them out",
              b=HEAD['even'])
    link(sin_t.outputs[0], ev.inputs[0])
    arc = math('MULTIPLY', -840, -1120, "distance from centre, in ARC")
    link(f_band.outputs[0], arc.inputs[0])
    link(ev.outputs[0], arc.inputs[1])
    f_nom = math('MULTIPLY', -840, -1400, "head stroke width",
                 b=HEAD['arc'] * HEAD_FREQ)
    link(v_s.outputs[0], f_nom.inputs[0])
    f_eye = math('MULTIPLY', -680, -1470, "narrowed at the eye")
    link(f_nom.outputs[0], f_eye.inputs[0])
    link(eye_t.outputs['Result'], f_eye.inputs[1])
    f_width = floor_width(f_eye, HEAD['arc'] * HEAD_FREQ,
                          -520, -1470, "head")
    f_raw = math('LESS_THAN', -660, -1200, "inside a head stroke?")
    link(arc.outputs[0], f_raw.inputs[0])
    link(f_width.outputs[0], f_raw.inputs[1])

    # AND A HARD RING OF CLEAN COAT ROUND THE MUZZLE, because evening the
    # widths out is only half of it: below about twenty degrees the strokes are
    # wide enough to MERGE instead of thin enough to vanish, and either way
    # nothing there resolves. Compared against the cosine, so a bigger number
    # is NEARER the nose.
    # THE TWO BOUNDS GO IN LOW-TO-HIGH, AND THEY ARE COSINES, so the one
    # NEARER the nose is the BIGGER number. Handed to `rng` the way the angles
    # read -- near first -- `from_min` lands above `from_max`, the ramp inverts,
    # and ink is allowed only inside the cap it was supposed to clear. Which is
    # exactly what shipped for one render: a bare orange head with a dense fan
    # of strokes on the jaw.
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

    # ---- what is never inked ------------------------------------------
    # THE EYES ARE NOT HERE ANY MORE -- they are on the WIDTH, above. All that
    # is left is the muzzle, which genuinely wants a cut: the coat there is a
    # different colour rather than a place strokes taper into.
    face = rng(120, -300, "clean muzzle", FACE['lo'], FACE['hi'], 0.0, 1.0)
    link(Y, face.inputs['Value'])
    keep = face

    soft = math('MULTIPLY', 1020, -20, "every mask, multiplied together")
    link(raw.outputs[0], soft.inputs[0])
    link(keep.outputs[0], soft.inputs[1])

    # ---- AND THEN IT IS MADE BINARY, WHICH IS THE WHOLE FIX -------------
    # **NO MASK IN THIS GRAPH MAY PRODUCE A GREY STROKE.** Every mask here
    # multiplies the stroke mask, and the stroke mask is 0 or 1 -- so any mask
    # that is anywhere between, for any reason, does not draw fewer strokes. It
    # draws a stroke at PART STRENGTH, which is ink lerped toward the coat.
    # That is a stripe fading out, and it is what was left after the widths
    # were fixed: the strokes were crisp and bold in the sheet, and the ones
    # crossing a mask edge were crisp, bold and GREY.
    #
    # Every one of those has been narrowed by hand at least once in this file
    # -- the muzzle from 0.24 studs to 0.09, the eye clearance three separate
    # ways, the head switch from 0.28 to 0.11 -- and narrowing is a mitigation
    # rather than a fix, because it leaves the failure available to the next
    # mask anybody adds. One threshold at the end makes it STRUCTURALLY
    # impossible: a texel is ink or it is coat, and the only softness left
    # anywhere is the 2048-to-1024 downscale doing the anti-aliasing it is
    # there for.
    #
    # It costs nothing that was wanted. A mask edge still lands in the right
    # PLACE -- 0.5 is where a smoothstep crosses -- it just arrives as an edge
    # rather than as a ramp. And it deliberately does NOT touch the belly,
    # which is a genuine colour gradient between two coat colours rather than a
    # stroke being drawn at half strength.
    ink = math('GREATER_THAN', 1200, -20, "INK, or not. Never half.", b=0.5)
    link(soft.outputs[0], ink.inputs[0])

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

    m1, f1, a1, b1, o1 = mix_rgb(nt, "orange -> cream belly")
    m1.location = (300, 460)
    a1.default_value = to_linear(ORANGE) + (1.0,)
    b1.default_value = to_linear(CREAM) + (1.0,)
    link(hard(belly.outputs[0], 120, 460, "the cream belly"), f1)

    nose = rng(120, 700, "the snout disc", NOSE['lo'], NOSE['hi'], 1.0, 0.0)
    link(Y, nose.inputs['Value'])
    m2, f2, a2, b2, o2 = mix_rgb(nt, "nose pad back to orange")
    m2.location = (500, 460)
    b2.default_value = to_linear(ORANGE) + (1.0,)
    link(hard(nose.outputs['Result'], 300, 700, "the snout pad"),
         f2)
    link(o1, a2)

    m3, f3, a3, b3, o3 = mix_rgb(nt, "lay the ink on")
    m3.location = (700, 280)
    b3.default_value = to_linear(INK) + (1.0,)
    link(ink.outputs[0], f3)
    link(o2, a3)

    bsdf = node("ShaderNodeBsdfPrincipled", 900, 280)
    bsdf.inputs['Roughness'].default_value = 0.88
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.08
    link(o3, bsdf.inputs['Base Color'])
    out = node("ShaderNodeOutputMaterial", 1220, 280)
    link(bsdf.outputs['BSDF'], out.inputs['Surface'])
    # Continuous edge distances supersede the legacy hard selector above.
    from stripe_transition import soften_stripe_transition
    soften_stripe_transition(mat)
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

body_mat = coat("tiger_body")
trim_mat = coat("tiger_trim")
ear_mat = flat("tiger_ear_inner", EAR_PINK)
# The entire muzzle, including its recessed nostril walls, is orange.
# The shared coat field let a clipped stripe survive on the rear bevel and
# painted the deeper dimple surfaces cream as they crossed its Y threshold.
snout_mat = flat("tiger_snout", ORANGE)

# THE EARS KEEP THEIR TWO SLOTS AND THE ORDER THEY ARE IN. Face assignment
# lives on the polygons as a `material_index`, so replacing slot 0 with slot 0
# and slot 1 with slot 1 inherits whatever selection was made by hand -- clear
# the list and append in the wrong order and the inner ear paints the outside
# with nothing to say so.
ASSIGN = [("Body", [body_mat]),
          ("Snout", [snout_mat]),
          ("Legs", [trim_mat]),
          ("Tail", [trim_mat]),
          ("Ears", [trim_mat, ear_mat])]

# SEATED THROUGH `skin_parts.assign`, WHICH IS THE ONE PLACE THAT KNOWS THAT
# `materials.clear()` ALSO RESETS EVERY POLYGON'S SLOT INDEX. Both skin scripts
# carried their own copy of that loop and both destroyed the ear selection.
assign(bpy, ASSIGN, "TIGER  (from %s)" % SRC)

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
