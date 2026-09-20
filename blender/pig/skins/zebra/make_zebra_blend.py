# -*- coding: utf-8 -*-
"""Build the Zebra's coat as a node graph, in its own blend file.

    blender.exe --background --python skins/zebra/make_zebra_blend.py
    blender.exe --background --python make/bake_skin.py       -- --skin zebra
    blender.exe --background --python make/make_view_blend.py -- --skin zebra --render

See `WORKFLOW.md` for the method. What follows is only what is particular to
this animal.

THE POLE IS THE MUZZLE, AND THAT DECISION IS NOT MINE. `Config.SKINS.zebra`
already carries it, argued and measured against the shipped geometry, from when
this skin was drawn out of PARTS -- and the argument survives the move to a
bake completely intact, because it is about WHERE THE BANDS GO rather than what
draws them. Quoting the part that matters:

    Every other pattern in this catalogue girdles the SPINE, which is right for
    a bee and was never right for a zebra. Measured on the version this
    replaces: the nearest band sat 54 degrees off the snout, so there was
    nothing on the face at all, and the lowest one stopped 4.6 degrees ABOVE
    the equator -- the whole marking was a cap of bars pulled down over the
    head with clean white flanks underneath it.

So the bands are rings of constant angle about an axis pointing OUT THROUGH THE
SNOUT, and one family then does all three things a zebra's markings do at once:

    near the pole      a ring on the FACE
    at ninety degrees  a near-vertical stripe down the FLANK
    beyond it          a ring closing on the TAIL

That is worth being exact about, because it is the whole difference between
this and the tiger and it is not obvious from the code. A cone at a fixed angle
about a forward-and-down axis is a full ring round the body: at 90 degrees it
is a great circle, tilted by the pole's own lean, running under the belly, up
both flanks and over the back. Which is exactly a zebra's body stripe. The
tiger's rings girdle the nose-tail axis instead and are a completely different
family of curves on the same animal.

**17.7 DEGREES BELOW THE FORWARD HORIZONTAL**, also Config's number and also
kept. Its reason is one this bake does not share -- it was a compromise between
the plot piggy's snout at 24.1 degrees and the carried mini's at 13.4, because
one part-built spec had to draw both -- and it is kept anyway, so the baked
zebra and the part-built one it replaces put their bands in the same places.
Changing it would be a redesign wearing a bug's clothes.

WHAT A ZEBRA IS THAT A TIGER IS NOT, since the two scripts look alike:

  * **The ink and the white are the SAME WIDTH.** `width` is 0.5 of a period
    here against the tiger's 0.40, and that single number is most of what makes
    one read as a zebra and the other as a cat. A tiger is an orange animal
    with dark strokes on it; a zebra is neither black nor white, it is both.
  * **The edges are CLEANER.** Less wobble, less grain. A tiger's stripe is a
    brush stroke and a zebra's is a band.
  * **They still fork**, and that is not decoration either -- a real zebra's
    bands split and rejoin constantly, and it is the same width-goes-negative
    trick the tiger uses, just dialled lower.
  * **The muzzle is BLACK.** The opposite of the tiger's orange nose pad, from
    the same node.
"""
import bpy, os, sys, math

D = os.path.dirname(os.path.abspath(__file__))

# --- find the toolkit, wherever this script has been filed ------------------
_root = D
while not os.path.exists(os.path.join(_root, "paths.py")):
    _up = os.path.dirname(_root)
    if _up == _root:
        raise RuntimeError("cannot find paths.py above %s" % __file__)
    _root = _up
if _root not in sys.path:
    sys.path.insert(0, _root)
# ---------------------------------------------------------------------------

import paths                                    # noqa: E402
import skin_colours                             # noqa: E402
from skin_colours import to_linear              # noqa: E402
from skin_parts import assign, face_slots       # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SRC = arg("--blend", paths.PARTS)
OUT = arg("--out", paths.skin_blend("zebra"))

# --------------------------------------------------------------- the colours
# PARSED OUT OF `Config.luau` RATHER THAN TYPED, which is what `skin_colours`
# is for. The tiger writes its two as literals with a comment saying they came
# from Config; this asks Config. The difference shows up the day somebody
# retunes a skin's white and the preview goes on showing the old one -- which
# has already happened twice in this folder, to the bee and to this very skin.
WHITE, DARK = skin_colours.skin("zebra")

# THE INK IS THE PATTERN'S OWN COLOUR AND NOT THE TRIM'S, and they are two
# different values on purpose: `Config.SKINS.zebra.trim` is (36, 34, 38), the
# snout and legs, while `pattern.colour` is (30, 28, 32), the bands. Six levels
# apart, invisible side by side, and the reason is that a band sits on white
# where the trim sits on nothing -- so the band can afford to be blacker.
INK = (30 / 255., 28 / 255., 32 / 255.)

# --------------------------------------------------------------- the tunables
BANDS = dict(
    # THE POLE, in degrees below the forward horizontal. Config's number; see
    # the header for why it is kept rather than re-solved.
    pole_down=17.7,
    # HOW MANY BANDS, as periods per RADIAN of angle from that pole. The coat
    # runs from where the white muzzle ring ends to the tail, which is about
    # 2.5 radians, so 6.4 is roughly sixteen strokes over the animal.
    #
    # IT WENT 4.6 -> 5.8 -> 9.4 -> 6.4, AND THE TRIP TO 9.4 WAS A WRONG
    # DIAGNOSIS WORTH KEEPING. The bands were reading as hoops, so the count
    # went up on the theory that shorter strokes would break more easily. What
    # came back was a PINSTRIPE: twenty-four thin even lines, further from the
    # reference than the ten had been. The count was never what made them
    # hoops -- `vary` was, and it was not breaking anything (see below).
    freq=5.4,
    # HOW MUCH OF A PERIOD IS INK, before `vary` gets at it. Half was the
    # first answer and it was measured off the WRONG PART of a zebra: the
    # barrel of a real one is near enough equal black and white, but the
    # reference plush is white with dark strokes ON it, and every stroke is
    # thinner than the gap beside it. 0.40 nominal, thinned further wherever
    # the width noise dips, comes out white-dominant like the reference.
    width=0.52,
    # Stripes meet the black muzzle without a blank white collar. The old
    # 27-degree exclusion left a circular gap under the nose. Keep only a
    # half-degree exclusion at the angular singularity, hidden by the nose.
    start=0.0, start_soft=0.5,
    # THE WOBBLE. Deliberately half the tiger's: a zebra band is a BAND, and
    # the thing being avoided here is nine identical bars at identical
    # intervals, which Config's own comment calls a barcode.
    wobble=0.30, wobble_scale=1.5,
    # THE POINTED ENDS, AND THIS IS THE WHOLE DIFFERENCE BETWEEN THIS AND A
    # SET OF HOOPS. It was dialled DOWN from the tiger's on the theory that a
    # zebra's markings are cleaner than a cat's -- true of the edges and false
    # of the shape. Look at the reference: almost no stroke on it goes all the
    # way round anything. They start, swell, and come to a POINT in the middle
    # of a white field.
    #
    # That is exactly what a width that goes NEGATIVE does. Where the noise
    # takes the width below zero the stroke stops being drawn, and because the
    # threshold is compared against a distance-from-a-centre the two ends taper
    # rather than being cut square.
    #
    # **BELOW 2.0 THIS NUMBER CANNOT BREAK A STROKE AT ALL, WHICH IS ARITHMETIC
    # AND WAS ASSERTED WRONGLY IN TWO PLACES BEFORE ANYBODY DID IT.** The width
    # factor is `1 + (Fac - 0.5) * vary` and Blender's noise `Fac` is bounded
    # to 0..1, so the factor bottoms out at `1 - vary/2`: at the tiger's 1.10
    # that is 0.45 and at this skin's first try of 1.30 it is 0.35. Neither
    # reaches zero, so neither ever ENDS a stroke -- they only thin it, and a
    # thinned stroke that still goes all the way round is a hoop. Zero needs
    # `Fac <= 0.5 - 1/vary`, which is unreachable until vary passes 2 and only
    # starts happening in the tails a bit above it. At 3.0 it wants `Fac` under
    # 0.17, which is often enough to end most strokes and rare enough to leave
    # some long ones -- which is the mix the reference has.
    vary=3.00, vary_scale=3.4,
    # A little edge break-up. Lower than the tiger's for the same reason the
    # wobble is.
    grain=0.07, grain_scale=11.0,
)

BELLY = dict(
    # THE BAND COMES TO A POINT UNDER THE BELLY, which is Config's `taper` and
    # its reason: "a band of one width the whole way round is a hoop rather
    # than a marking". Measured in z rather than in angle, because the belly is
    # a fact about which way is DOWN and the pole is tilted.
    hi=-0.58, lo=-0.88, kill=0.92,
    # The legs come back out of it, exactly as the tiger's do -- a zebra's legs
    # are banded all the way to the hoof.
    leg_lo=-0.88, leg_hi=-0.66,
)

# THE NOSE IS BLACK. Everything forward of y -1.24 is the snout disc, and on a
# zebra that is the one part of the face that is solid dark -- the same node
# the tiger uses to put its ORANGE nose pad back, pointed the other way.
NOSE = dict(lo=-1.24, hi=-1.10)

# THE EAR TIPS ARE DARK, which is the marking that says zebra from behind at a
# distance. Only the `Ears` object reaches this high -- the tail tops out at
# 0.74 -- so a plain z rule cannot touch anything else.
EAR = dict(lo=0.96, hi=1.14)

# THE HOOVES ARE SOLID BLACK, which the reference wears on all four feet and
# which no band was ever going to produce -- the foot is small enough that the
# strokes crossing it read as speckle rather than as a hoof. Only the `Legs`
# object reaches below -0.90.
HOOF = dict(lo=-1.00, hi=-0.90)

# THE FACE STROKES RUN THE OTHER WAY, AND THIS IS THE ONE THING THE INHERITED
# DESIGN DID NOT COVER.
#
# Rings about a pole through the muzzle are the right family for the BODY --
# they are the reason the flank stripes stand up and the rump ones fan. They
# are exactly WRONG for the face, and wrong by ninety degrees: a ring near the
# pole is a hoop drawn ROUND the nose, where every reference of a zebra's head
# shows strokes running OUT of it. The two are perpendicular, which is why no
# amount of retuning the ring frequency ever put a face on this animal -- the
# curves were the wrong curves, not the wrong size.
#
# A ring is a line of constant POLAR ANGLE. A radial stroke is a line of
# constant AZIMUTH -- a meridian, running from the nose backward -- so the face
# is the same field with the two angles swapped, and `count` is how many of
# them go round rather than how many fit along.
#
# THEY TAPER FOR FREE, which is the good half. Meridians converge at the pole,
# so a stroke of constant ANGULAR width is physically narrow at the muzzle and
# widens as it runs back over the cheek. That is precisely the shape the
# reference's face strokes have, and it costs nothing to get.
#
# WHERE IT HANDS OVER IS MEASURED IN **y**, NOT IN ANGLE FROM THE POLE, AND
# THAT WAS WRONG FIRST TIME. The obvious switch is "everything within N degrees
# of the muzzle is face", and it does not describe a head. Measured on the real
# surface: the cheek sits at 48 degrees from the pole and the FOREHEAD at 73 --
# further out than the shoulder's 76 is from the flank -- because the pole is
# aimed down the muzzle and the top of the head is a long way round from it. So
# a 62-degree cutoff put radial strokes on the jaw and left the brow wearing
# body rings, which is exactly backwards from the reference.
#
# `y` is the nose-to-tail axis, so "in front of the ears" is one number and it
# puts the seam round the NECK -- which is where a zebra's stripe direction
# actually changes.
#
# It is a SWITCH rather than a blend: mixing two phase fields with different
# topology distorts both in the overlap, because the local stripe spacing goes
# through whatever the difference between them happens to be. The two fields
# meet at an angle along the neck, which is what the animal does.
#
# **`count` IS AN INTEGER AND THAT IS LOAD-BEARING.** An angle measured round a
# circle wraps somewhere, and at the wrap the stroke phase jumps by a whole
# turn -- a hard seam running nose to tail. With a whole number of strokes per
# turn that jump is exactly `count` periods, so `fract` never notices it and
# there is no seam at all. A fractional count puts one down the animal.
FACE = dict(count=20, y_lo=-0.55, y_hi=-0.30)

# THE STROKES GO ROUND THE EYES, AND A ZEBRA GOES ROUND THEM DIFFERENTLY FROM
# A TIGER.
#
# The tiger narrows a stroke to a point as it approaches an eye and stops. That
# is right for a cat, whose face strokes are separate brush marks that each end
# somewhere. A zebra's do not end -- they BEND. Every photograph of one shows
# the bands sweeping round the eye and carrying on past it, which is a
# different thing entirely from a stroke that ran out.
#
# So this does both, and the bending is the half that is the zebra's own:
#
#   `warp`   PUSHES THE PATTERN AWAY FROM THE EYE before the angle round the
#            muzzle is measured. Displacing the sample point outward along the
#            line from the eye drags the meridians outward with it, so a band
#            that would have crossed the eye curves round it instead and closes
#            up again behind. It is a domain warp, and it is why the bands stay
#            continuous rather than being interrupted.
#   `r0`/`r1` then narrow whatever is still too close, so nothing crowds the
#            eyeball itself and the last of it comes to a point rather than
#            being cut off square.
#
# `r0` is measured off the eye rather than chosen: `EyePreview` is 0.210 studs
# across, so an eyeball is 0.105 in radius.
#
# **AND THE EYE IS FOUND BY SIGN RATHER THAN BY MIRRORING |x|.** The tiger
# measures distance on the mirrored point, which is fine when all you want is a
# distance. A WARP has a direction, and on the mirrored point that direction is
# wrong on one side of the animal -- it would push the left of the face away
# from the right eye. Taking the sign of x and building the near eye's position
# from it gets both the distance and the direction right on both sides.
EYES = dict(x=0.318, y=-0.889, z=0.364, r0=0.15, r1=0.40,
            warp=0.26, warp_r=0.46)

# THE INK IS BINARY, AND NOTHING IN THIS GRAPH MAY MAKE IT ANYTHING ELSE.
#
# Every mask here MULTIPLIES the band mask, and the band mask is 0 or 1 -- so a
# mask that is anywhere in between does not draw fewer bands. It draws a band
# at PART STRENGTH, which is ink lerped toward the coat, which is a stripe
# fading out. The muzzle ring, the eye, the head-to-body switch and the belly
# taper are all soft by nature, and every one of them was a place a band could
# come out grey.
#
# The tiger had this and it was chased for three rounds as a WIDTH problem --
# strokes thinning below a texel and the bake averaging them away -- which was
# wrong: zoomed in, the strokes were crisp and bold, and the ones crossing a
# mask edge were crisp, bold and grey. Narrowing each mask by hand is a
# mitigation that leaves the failure available to the next mask anybody adds.
# One threshold at the end makes it impossible.
#
# It costs nothing that was wanted: a mask edge still lands where the smoothstep
# crosses 0.5, it just arrives as an edge rather than as a ramp, and the
# 2048-to-1024 downscale still anti-aliases it. It deliberately does not touch
# the ear pink or anything else that is a real colour choice.
INK_IS_BINARY = True

# NOTHING ON THIS ANIMAL FADES INTO ANYTHING ELSE -- see `INK_IS_BINARY`
# above, which is this rule as it applies to a two-colour skin, and
# `WORKFLOW.md`, "Nothing fades", which is the rule for all of them. The
# threshold on `allink` is the whole of it here: white or ink, never between.
NO_FADING = True


# EVERYTHING DERIVED FROM AN ANGLE IS SOLVED HERE, NOT INSIDE `coat`, and that
# is a bug rather than a preference. `coat` has a local helper called `math`
# -- it builds Math nodes -- which SHADOWS the module, so `math.cos` in there
# resolves to that function and dies with "'function' object has no attribute
# 'cos'". Same family as the `step` shadowing in `Crack.luau` that left the
# crack's dial frozen for the life of the feature: the name resolved to a
# perfectly good local that was the wrong thing.
POLE = (0.0,
        -math.cos(math.radians(BANDS['pole_down'])),
        -math.sin(math.radians(BANDS['pole_down'])))
START_LO = math.radians(BANDS['start'])
START_HI = math.radians(BANDS['start'] + BANDS['start_soft'])

# THE TWO PERPENDICULARS THAT MEASURE THE WAY ROUND THE POLE, so the face can
# have RADIAL strokes rather than rings. See `FACE` below for why it needs
# them; this is only the arithmetic.
#
# `E1` is straight up as seen from the pole -- the component of +Z that is
# perpendicular to the pole, renormalised -- and `E2` is the pole crossed with
# it, which comes out exactly -X. Then the way round is `atan2(dir.E2, dir.E1)`.
#
# **E1 IS UP RATHER THAN SIDEWAYS ON PURPOSE, AND IT IS THE WHOLE REASON THIS
# IS SAFE.** An angle measured round a circle has to wrap somewhere, and the
# wrap is a hard seam in the pattern: the stroke phase jumps by a whole turn
# across one line running from the nose to the tail. Choosing UP as the zero
# puts that line on the BELLY -- the one part of this animal the belly mask
# below paints white anyway -- so the seam is drawn where nothing is drawn. Had
# the obvious sideways basis been kept the seam would run down the middle of
# the right flank, which is the most looked-at surface on the pig.
FACE_E1 = (0.0,
           -math.sin(math.radians(BANDS['pole_down'])),
           math.cos(math.radians(BANDS['pole_down'])))
FACE_E2 = (-1.0, 0.0, 0.0)
# Periods per RADIAN of the way round, so `count` strokes fit in one full turn.
FACE_FREQ = FACE['count'] / (2.0 * math.pi)


def mix_rgb(nt, label=""):
    """A colour mix, whichever node this Blender calls it. See the tiger."""
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
    """The zebra's coat as one material. Built twice, body and trim, and NOT
    shared between them -- `bake_skin.py` repoints each material's image node
    per group, so one material worn by both would come back blank on the first
    sheet baked."""
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
        off = node("ShaderNodeVectorMath", x - 210, y, "offset")
        off.operation = 'ADD'
        off.inputs[1].default_value = offset
        n = node("ShaderNodeTexNoise", x, y, label)
        n.noise_dimensions = '3D'
        n.inputs['Scale'].default_value = scale
        n.inputs['Detail'].default_value = detail
        n.inputs['Roughness'].default_value = 0.55
        link(off.outputs['Vector'], n.inputs['Vector'])
        return off, n

    # ---- where am I, and how far round from the muzzle ----------------
    co = node("ShaderNodeTexCoord", -2200, 0, "the pig's own frame")
    sep = node("ShaderNodeSeparateXYZ", -2000, 240, "x / y nose-tail / z up")
    link(co.outputs['Object'], sep.inputs['Vector'])
    X, Y, Z = sep.outputs['X'], sep.outputs['Y'], sep.outputs['Z']

    # THE ANGLE FROM THE POLE IS THE WHOLE COORDINATE SYSTEM OF THIS SKIN.
    # Normalise the position so every point on the animal is a DIRECTION from
    # its centre, dot that against the pole, and take the arc cosine: 0 dead
    # ahead down the muzzle, pi/2 out on the flank, pi behind at the tail.
    unit = node("ShaderNodeVectorMath", -2000, -40, "direction from centre")
    unit.operation = 'NORMALIZE'
    link(co.outputs['Object'], unit.inputs[0])
    # THE POLE, as a unit vector in the pig's own frame. -Y is the face and
    # +Z is up, so "forward and 17.7 degrees down" is -cos in y and -sin in z.
    dot = node("ShaderNodeVectorMath", -1800, -40, "cos of the angle")
    dot.operation = 'DOT_PRODUCT'
    dot.inputs[1].default_value = POLE
    link(unit.outputs['Vector'], dot.inputs[0])

    theta = math('ARCCOSINE', -1620, -40, "ANGLE FROM THE MUZZLE (radians)")
    link(dot.outputs['Value'], theta.inputs[0])

    # ---- the belly, and the legs coming back out of it ----------------
    belly_a = rng(-1620, 460, "point the band into the belly",
                  BELLY['lo'], BELLY['hi'], 1.0, 0.0)
    link(Z, belly_a.inputs['Value'])
    leg_out = rng(-1620, 250, "but the legs are banded too",
                  BELLY['leg_lo'], BELLY['leg_hi'], 0.0, 1.0)
    link(Z, leg_out.inputs['Value'])
    belly = math('MULTIPLY', -1400, 360, "BELLY MASK")
    link(belly_a.outputs['Result'], belly.inputs[0])
    link(leg_out.outputs['Result'], belly.inputs[1])

    # ---- the phase ----------------------------------------------------
    wob_off, wob = noise(-1620, -300, "WOBBLE noise",
                         BANDS['wobble_scale'], 2.0, (0.0, 0.0, 0.0))
    link(co.outputs['Object'], wob_off.inputs[0])
    wob_c = math('SUBTRACT', -1400, -300, "centre on zero", b=0.5)
    link(wob.outputs['Fac'], wob_c.inputs[0])
    wob_s = math('MULTIPLY', -1220, -300, "wobble amount", b=BANDS['wobble'])
    link(wob_c.outputs[0], wob_s.inputs[0])

    gr_off, gr = noise(-1620, -540, "GRAIN noise",
                       BANDS['grain_scale'], 3.0, (11.0, 4.0, -7.0))
    link(co.outputs['Object'], gr_off.inputs[0])
    gr_c = math('SUBTRACT', -1400, -540, "centre on zero", b=0.5)
    link(gr.outputs['Fac'], gr_c.inputs[0])
    gr_s = math('MULTIPLY', -1220, -540, "grain amount", b=BANDS['grain'])
    link(gr_c.outputs[0], gr_s.inputs[0])

    jitter = math('ADD', -1040, -420, "wobble + grain")
    link(wob_s.outputs[0], jitter.inputs[0])
    link(gr_s.outputs[0], jitter.inputs[1])

    # ---- where the near eye is, and pushing the pattern off it ---------
    # The sign of x picks which eye, so the offset below has the right
    # DIRECTION as well as the right length -- see `EYES`.
    sgn = math('SIGN', -2000, -1520, "which side of the face")
    link(X, sgn.inputs[0])
    ex = math('MULTIPLY', -1840, -1520, "that eye's x", b=EYES['x'])
    link(sgn.outputs[0], ex.inputs[0])
    eye_at = node("ShaderNodeCombineXYZ", -1680, -1520, "the near eye")
    link(ex.outputs[0], eye_at.inputs['X'])
    eye_at.inputs['Y'].default_value = EYES['y']
    eye_at.inputs['Z'].default_value = EYES['z']
    off = node("ShaderNodeVectorMath", -1500, -1520, "offset from it")
    off.operation = 'SUBTRACT'
    link(co.outputs['Object'], off.inputs[0])
    link(eye_at.outputs['Vector'], off.inputs[1])
    off_len = node("ShaderNodeVectorMath", -1320, -1620, "how far")
    off_len.operation = 'LENGTH'
    link(off.outputs['Vector'], off_len.inputs[0])
    off_dir = node("ShaderNodeVectorMath", -1320, -1450, "which way")
    off_dir.operation = 'NORMALIZE'
    link(off.outputs['Vector'], off_dir.inputs[0])

    # HOW HARD TO PUSH: all of `warp` on the eye itself, nothing by `warp_r`.
    push = rng(-1140, -1620, "push, near the eye only",
               0.0, EYES['warp_r'], EYES['warp'], 0.0)
    link(off_len.outputs['Value'], push.inputs['Value'])
    shove = node("ShaderNodeVectorMath", -960, -1450, "the displacement")
    shove.operation = 'SCALE'
    link(off_dir.outputs['Vector'], shove.inputs[0])
    link(push.outputs['Result'], shove.inputs['Scale'])
    warped = node("ShaderNodeVectorMath", -780, -1520, "pushed off the eye")
    warped.operation = 'ADD'
    link(co.outputs['Object'], warped.inputs[0])
    link(shove.outputs['Vector'], warped.inputs[1])
    w_unit = node("ShaderNodeVectorMath", -600, -1520, "as a direction")
    w_unit.operation = 'NORMALIZE'
    link(warped.outputs['Vector'], w_unit.inputs[0])

    # AND WHAT IS LEFT TOO CLOSE IS NARROWED TO A POINT.
    eye_t = rng(-1140, -1780, "come to a point at the eye",
                EYES['r0'], EYES['r1'], 0.0, 1.0)
    link(off_len.outputs['Value'], eye_t.inputs['Value'])

    # ---- the way round the pole, which is what the FACE is drawn in ----
    d1 = node("ShaderNodeVectorMath", -1800, -1150, "up, seen from the pole")
    d1.operation = 'DOT_PRODUCT'
    d1.inputs[1].default_value = FACE_E1
    link(w_unit.outputs['Vector'], d1.inputs[0])
    d2 = node("ShaderNodeVectorMath", -1800, -1330, "and sideways")
    d2.operation = 'DOT_PRODUCT'
    d2.inputs[1].default_value = FACE_E2
    link(w_unit.outputs['Vector'], d2.inputs[0])
    phi = math('ARCTAN2', -1600, -1240, "WAY ROUND THE MUZZLE (radians)")
    link(d2.outputs['Value'], phi.inputs[0])
    link(d1.outputs['Value'], phi.inputs[1])

    # ---- rings on the body, meridians on the face ---------------------
    body_phase = math('MULTIPLY', -1040, -100, "rings: how far round the pole",
                      b=BANDS['freq'])
    link(theta.outputs[0], body_phase.inputs[0])
    face_phase = math('MULTIPLY', -1040, -1240, "meridians: which way round",
                      b=FACE_FREQ)
    link(phi.outputs[0], face_phase.inputs[0])

    # SWITCHED, NOT BLENDED. See `FACE`: two phase fields with different
    # topology cannot be mixed without the local stripe spacing going through
    # whatever the difference between them happens to be, so the crossover is
    # two fields simply meet at an angle. Threshold the region selector
    # BEFORE choosing a phase: interpolating unwrapped phases created the
    # dense pinstripe strip around the ears, despite this switch's intent.
    face_w = rng(-1040, 60, "in front of the ears?",
                 FACE['y_lo'], FACE['y_hi'], 1.0, 0.0)
    link(Y, face_w.inputs['Value'])
    face_region = math('GREATER_THAN', -860, 60, "face or body, never interpolated", b=0.5)
    link(face_w.outputs['Result'], face_region.inputs[0])
    diff = math('SUBTRACT', -860, -1100, "face - body")
    link(face_phase.outputs[0], diff.inputs[0])
    link(body_phase.outputs[0], diff.inputs[1])
    picked = math('MULTIPLY_ADD', -700, -240, "whichever this point is in")
    link(diff.outputs[0], picked.inputs[0])
    link(face_region.outputs[0], picked.inputs[1])
    link(body_phase.outputs[0], picked.inputs[2])

    phase = math('ADD', -860, -140, "BAND PHASE")
    link(picked.outputs[0], phase.inputs[0])
    link(jitter.outputs[0], phase.inputs[1])

    fr = math('FRACT', -680, -140, "one period")
    link(phase.outputs[0], fr.inputs[0])
    ce = math('SUBTRACT', -520, -140, "distance from a band centre", b=0.5)
    link(fr.outputs[0], ce.inputs[0])
    ab = math('ABSOLUTE', -360, -140)
    link(ce.outputs[0], ab.inputs[0])
    band = math('MULTIPLY', -200, -140, "0 on a band, 1 between", b=2.0)
    link(ab.outputs[0], band.inputs[0])

    # ---- how wide this band is here -----------------------------------
    v_off, vary = noise(-1620, -800, "WIDTH noise",
                        BANDS['vary_scale'], 2.0, (-6.0, 13.0, 5.0))
    link(co.outputs['Object'], v_off.inputs[0])
    v_c = math('SUBTRACT', -1400, -800, "centre on zero", b=0.5)
    link(vary.outputs['Fac'], v_c.inputs[0])
    v_s = math('MULTIPLY_ADD', -1220, -800, "1 +- vary", b=BANDS['vary'], c=1.0)
    link(v_c.outputs[0], v_s.inputs[0])
    w_base = math('MULTIPLY', -1040, -800, "nominal width", b=BANDS['width'])
    link(v_s.outputs[0], w_base.inputs[0])
    kill = math('MULTIPLY_ADD', -860, -800, "point it into the belly",
                b=-BELLY['kill'], c=1.0)
    link(belly.outputs[0], kill.inputs[0])
    w_eye = math('MULTIPLY', -860, -640, "narrowed at the eye")
    link(w_base.outputs[0], w_eye.inputs[0])
    link(eye_t.outputs['Result'], w_eye.inputs[1])
    width = math('MULTIPLY', -680, -800, "WIDTH HERE")
    link(w_eye.outputs[0], width.inputs[0])
    link(kill.outputs[0], width.inputs[1])

    # ---- what is NOT banded -------------------------------------------
    # Exclude only the singularity at the pole; no visible muzzle collar.
    face = rng(-680, 240, "pole singularity only",
               START_LO, START_HI, 0.0, 1.0)
    link(theta.outputs[0], face.inputs['Value'])

    # THERE IS NO EYE CLEARANCE, WHICH REVERSES THE ONE PIECE OF `Config`'S
    # DESIGN THIS SKIN DOES NOT KEEP -- see `EYES` for why.
    keep = face

    raw = math('LESS_THAN', -40, -140, "inside a band?")
    link(band.outputs[0], raw.inputs[0])
    link(width.outputs[0], raw.inputs[1])
    ink = math('MULTIPLY', 140, -140, "BAND MASK")
    link(raw.outputs[0], ink.inputs[0])
    link(keep.outputs[0], ink.inputs[1])

    # ---- the solid dark bits: the nose and the ear tips ---------------
    nose = rng(-40, 460, "the nose is black",
               NOSE['lo'], NOSE['hi'], 1.0, 0.0)
    link(Y, nose.inputs['Value'])
    ear = rng(-40, 660, "and so are the ear tips",
              EAR['lo'], EAR['hi'], 0.0, 1.0)
    link(Z, ear.inputs['Value'])
    hoof = rng(-40, 860, "and the hooves",
               HOOF['lo'], HOOF['hi'], 1.0, 0.0)
    link(Z, hoof.inputs['Value'])
    solid = math('MAXIMUM', 140, 560, "any of them")
    link(nose.outputs['Result'], solid.inputs[0])
    link(ear.outputs['Result'], solid.inputs[1])
    solid2 = math('MAXIMUM', 320, 660, "any of them")
    link(solid.outputs[0], solid2.inputs[0])
    link(hoof.outputs['Result'], solid2.inputs[1])
    solid = solid2

    soft = math('MAXIMUM', 320, 200, "every mask, together")
    link(ink.outputs[0], soft.inputs[0])
    link(solid.outputs[0], soft.inputs[1])
    # BINARY -- see `INK_IS_BINARY`. A texel is ink or it is coat, never half,
    # so no mask anywhere above can draw a band at part strength.
    allink = math('GREATER_THAN', 480, 200, "INK, or not. Never half.", b=0.5)
    link(soft.outputs[0], allink.inputs[0])

    # ---- two colours ---------------------------------------------------
    m, f, A, B, o = mix_rgb(nt, "white -> ink")
    m.location = (520, 200)
    A.default_value = to_linear(WHITE) + (1.0,)
    B.default_value = to_linear(INK) + (1.0,)
    link(allink.outputs[0], f)

    bsdf = node("ShaderNodeBsdfPrincipled", 740, 200)
    bsdf.inputs['Roughness'].default_value = 0.88
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.08
    link(o, bsdf.inputs['Base Color'])
    out = node("ShaderNodeOutputMaterial", 1060, 200)
    link(bsdf.outputs['BSDF'], out.inputs['Surface'])
    return mat


def flat(name, rgb):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes["Principled BSDF"]
    b.inputs['Base Color'].default_value = to_linear(rgb) + (1.0,)
    b.inputs['Roughness'].default_value = 0.88
    return mat


bpy.ops.wm.open_mainfile(filepath=paths.find(SRC, "blend"))

body_mat = coat("zebra_body")
trim_mat = coat("zebra_trim")
# THE INNER EAR IS THE ONE WARM THING ON THIS ANIMAL, and it is a real PINK
# rather than the dusty one a real zebra has. Two colours everywhere else means
# a white ear cup on a white head is not an ear at all, and the reference plush
# makes exactly that call -- the pink is the only hue on it and it is what the
# eye lands on after the stripes.
ear_mat = flat("zebra_ear_inner", (247 / 255., 183 / 255., 190 / 255.))

ASSIGN = [("Body", [body_mat]),
          ("Snout", [trim_mat]),
          ("Legs", [trim_mat]),
          ("Tail", [trim_mat]),
          ("Ears", [trim_mat, ear_mat])]

assign(bpy, ASSIGN, "ZEBRA  (from %s)" % os.path.relpath(SRC, paths.HERE))

for _n, _c in face_slots(bpy, [n for n, _ in ASSIGN]):
    if len(_c) > 1:
        print("  %-6s faces per slot %s  <- hand selection, intact" % (_n, _c))

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("")
print("  saved %s" % os.path.relpath(OUT, paths.HERE))
print("  pole %.1f deg below forward, about %d bands, %.0f%% of each in ink"
      % (BANDS['pole_down'], round(BANDS['freq'] * 2.1), BANDS['width'] * 100))
