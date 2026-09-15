# -*- coding: utf-8 -*-
"""Build the Snow Leopard's coat, in its own blend file.

    blender.exe --background --python make_snowleopard_blend.py

Writes `skins/snowleopard/snowleopard.blend`. Then the ordinary loop:

    blender.exe --background --python make/bake_skin.py       -- --skin snowleopard
    blender.exe --background --python make/make_view_blend.py -- --skin snowleopard --render

THE SECOND ANIMAL ON `rosette.py`, AND THE REASON THAT FILE EXISTS. The graph
is the leopard's exactly -- the Voronoi cell field, the tangent-plane distance,
the collapse of a ring into a solid spot, the width cap, the freckles -- so
this file is numbers and nothing else. Read `rosette.py`'s header for what a
rosette IS; everything below is what makes this one a snow leopard rather than
a leopard.

FOUR THINGS SEPARATE THE TWO, AND ONLY ONE OF THEM IS STRUCTURAL.

  * THE PALETTE IS COOL AND PALE. A leopard is tawny with near-black petals; a
    snow leopard is smoke over white with charcoal ones, and the contrast is
    LOWER at every step. That matters more than it sounds: the whole animal
    lives in the top third of the value range, so the same pattern that reads
    as bold on tawny reads as washed out here unless the ink is genuinely dark.
  * THE ROSETTES ARE BIGGER AND FEWER. A leopard's flank carries about nine
    cells across; this carries six, with thicker rings. That is `scale` and
    `w`, and it is the single thing that most says which cat this is.
  * THEY ARE LESS BROKEN. A leopard's rosette is three or four separate petals
    with coat showing between them; a snow leopard's is a thick, nearly closed
    ring with one or two gaps in it. That is `vary`, turned DOWN.
  * AND THE COAT IS NOT ONE COLOUR, WHICH IS THE STRUCTURAL ONE. `dorsal`
    below is the only field `rosette.py` builds for this skin and not for the
    leopard. A leopard is tawny from spine to flank and can afford to be; a
    pale animal with a flat ground has no FORM -- the markings float on a
    sheet, and the pig reads as a white toy with dirt on it. Smoke over the
    back grading to white underneath is what puts the body back.

WHAT THIS COSTS IN `Config`, AND IT IS NOT MINE TO SPEND -- FLAGGED HERE FOR
WHOEVER MAKES THE EDIT. `Config.SKINS.snowleopard` is the one animal in the
bucket carrying `material = Enum.Material.Glass`, and the comment beside it
says the marks stay PLASTIC on a glass body because "glass at 0.28 would make
the rosettes a suggestion rather than a pattern". That override lives inside
the `pattern` block -- and converting a skin to a `surface` pack DELETES the
pattern block, which takes the override with it and makes the whole pig glass,
rosettes included. So this skin cannot be converted the way the tiger and the
leopard are without deciding that question first: either it stops being glass,
or the surface pack needs a material story the other two did not.

THE COORDINATE FRAME IS THE PIG'S OWN, measured off the mesh rather than
assumed. Every part sits at identity, so object space IS world space and all
five parts share one frame:

    x   across          body reaches +-1.000
    y   NOSE to TAIL    snout tip -1.381, body -1.080..1.052, tail tip 1.465
    z   floor to CROWN  legs -1.020, body -0.960..0.960, ear tip 1.309

So -Y is the face and +Z is up.
"""

# --- find the toolkit, wherever this script has been filed ------------------
# Walks up from this file until it finds the folder holding `paths.py`. Depth
# independent on purpose: a script in `make/` and a script in
# `skins/snowleopard/` are two and three levels down, and a hardcoded `..` is a
# thing that breaks silently the first time anything is refiled.
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
import rosette   # noqa: E402 -- the spotted cat, shared with the leopard
import bpy, sys  # noqa: E402


argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SRC = arg("--blend", paths.PARTS)
OUT = arg("--out", paths.skin_blend("snowleopard"))

# --------------------------------------------------------------- the colours
# THE THREE THAT EXIST IN CONFIG ARE READ OFF IT rather than picked, for the
# reason `skin_colours.py` exists: a sheet used to JUDGE a pattern showing
# colours the game does not ship is invisible, because a slightly wrong grey
# looks exactly like a grey. This skin has three rather than the leopard's two,
# because its `pattern` block names a marking colour and the leopard's did not.
COAT = (228 / 255., 234 / 255., 244 / 255.)     # Config body -- the flank
# CONFIG'S `trim` IS THE ROSETTE CENTRE, the same repurposing the leopard makes
# and for the same reason: a full-colour sheet paints the snout, ears, legs and
# tail from the coat field, so the trim colour has no other home -- and a mid
# blue-grey is exactly what a snow leopard's rosette centre is.
FILL = (150 / 255., 164 / 255., 184 / 255.)     # Config trim
# AND THE INK IS CONFIG'S OWN `pattern.colour`, which is the one thing the
# part-built version of this skin already got right. A charcoal with BLUE in
# it: a neutral black on a cool coat reads as a hole rather than as fur, and
# this catalogue's tiger already records the warm equivalent of that argument.
INK = (52 / 255., 58 / 255., 72 / 255.)         # Config pattern.colour
# THE UNDERSIDE, and it is near-white rather than the cream a leopard gets --
# a warm cream under a cool coat reads as grubby.
WHITE = (250 / 255., 251 / 255., 253 / 255.)
# THE SMOKE OVER THE BACK. Not in Config and it could not be: it is the fourth
# colour a full-colour sheet buys.
#
# IT DIFFERS FROM THE COAT IN TEMPERATURE RATHER THAN IN VALUE, AND THAT WAS
# MEASURED INTO EXISTENCE AFTER THREE ATTEMPTS AT A DARKER GREY DID NOTHING.
# The obvious version is COAT lerped toward FILL -- a cooler, darker grey over
# the back, which is what a snow leopard looks like in a photograph. Built at
# 40%, then 52%, then a full 62%, it measured 20% and then 27% of the body
# sheet and was INVISIBLE in all four renders at every one of them.
#
# The reason is the lighting, and it is worth stating as a rule because it will
# catch the next pale skin too. Sampling the render down the flank, the SHADED
# underside came back at v115..147 against the LIT back at v153..156 -- so the
# belly, which carries the palest albedo on the animal, renders DARKER than the
# back, which carries the darkest. A pig is round and the sun is overhead: any
# tone that varies with HEIGHT is competing with a lighting gradient that runs
# the same way and is stronger. On the tiger and the leopard it wins anyway,
# because tawny-to-cream is a big step AND a saturation step. Here the whole
# coat lives in the top fifth of the value range and there is no step big
# enough to spend.
#
# A HUE CHANGE SURVIVES WHAT A VALUE CHANGE CANNOT, because shading scales all
# three channels together and cannot turn a warm surface cool. So the back is a
# warm buff-grey against a cool blue-white flank, and the animal finally has a
# top and a bottom. It is also the more honest colour: a snow leopard's back is
# yellowish-grey rather than blue, and the blue in the photographs is the sky
# on the snow.
#
# IT IS PULLED BACK FROM THE FIRST WARM VALUE, which was (206, 199, 180) and
# read KHAKI -- on the shaded side, against the game's blue `OutdoorAmbient`
# fill, the animal came out half tan and half slate and stopped looking like
# snow. This is about as warm as it can go and still read as a white cat.
SMOKE = (214 / 255., 209 / 255., 194 / 255.)
# The two places a pig shows skin rather than fur. Cooler than the leopard's,
# because a warm pink on a blue-white coat is the only thing on the animal that
# would not belong to the palette.
EAR_PINK = (238 / 255., 202 / 255., 204 / 255.)
# NOTHING ON THIS ANIMAL FADES INTO ANYTHING ELSE, and it is `rosette.py` that
# enforces it rather than this file: every factor reaching a colour mix in the
# shared graph passes through one threshold, so a texel is one of the colours
# named below and never a blend of two. `WORKFLOW.md`, "Nothing fades".
#
# It is declared here anyway so that the audit line in `WORKFLOW.md` covers
# every skin rather than every skin that happens to own its own graph.
NO_FADING = True

NOSE_PINK = (226 / 255., 176 / 255., 178 / 255.)

# --------------------------------------------------------------- the tunables
# EVERY NUMBER THAT DECIDES WHAT THE COAT LOOKS LIKE IS IN THESE DICTS, so a
# note like "too many spots" is a one-line edit and a two-second re-run.
SPOTS = dict(
    # HOW MANY. Cells per stud, so the body's 2.0 studs across carries about
    # `2*scale` of them. Every radius below is in CELL units, so this dial
    # moves the count WITHOUT moving how big a rosette is relative to its
    # neighbours.
    #
    # SIX ACROSS AGAINST THE LEOPARD'S NINE, and that ratio is the point rather
    # than the number. A snow leopard's rosettes are the biggest of any cat
    # relative to its body; a leopard's are small and crowded. Get this wrong
    # in either direction and no amount of colour makes the right animal.
    scale=2.9,
    # HOW EVENLY THEY SIT. See the leopard for the full argument -- it is a
    # DENSITY dial, because a low value stops close pairs colliding and so lets
    # `r` be larger.
    randomness=0.80,
    # THE RING'S RADIUS, in cell units, and also the COVERAGE dial: the field
    # is 3D and the pig is a shell through it, so this decides what fraction of
    # cells draw anything at all. `rosette.py` has the measurement.
    r=0.36,
    # HOW THICK A PETAL IS, in cell units. Bolder than the leopard's 0.100 --
    # a snow leopard's rings are heavy, and on a pale coat a thin one
    # disappears at any distance.
    w=0.120,
    # HOW MUCH THE RADIUS VARIES FROM PLACE TO PLACE, as a fraction. Clamped.
    # `size_scale` is the leopard's scaled by the same factor `scale` moved,
    # so a run of large rosettes covers the same SHARE of the animal rather
    # than the same number of studs.
    size_vary=0.15, size_scale=1.0,
    # AND PER CELL, which is a different thing from per PLACE: a random number
    # attached to the cell itself, so two rosettes touching each other can
    # still be different sizes.
    cell_vary=0.34,
    # THE RADIAL WOBBLE. Also rescaled with `scale`, for the same reason.
    wobble=0.26, wobble_scale=3.8,
    # THE BREAK-UP, and it is TURNED DOWN from the leopard's 1.75. This is the
    # dial that most decides which cat you are looking at: a leopard's rosette
    # is three or four separate petals with coat showing between them, and a
    # snow leopard's is a thick ring with one or two gaps in it. Past about 1.6
    # this stops being a snow leopard.
    #
    # Zero is around 1.0 here, NOT the 2.0 `WORKFLOW.md` gives for the tiger --
    # `rosette.py`'s `snoise` stretches the noise, so the arithmetic is
    # different. Read the helper, not the other skin.
    vary=1.30, vary_scale=5.7,
    # THE CEILING ON THE WIDTH, as a fraction of this rosette's own radius. It
    # is what makes an open ring geometric rather than a tuning result.
    max_w=0.40,
    # HOW FAR THE CENTRE FILL REACHES INTO THE PETAL BAND, in units of the
    # petal half-width. Positive tucks the fill UNDER the petals so no coat
    # colour shows between the two.
    fill_over=0.70,
    # A SOLID SPOT'S SIZE, as a multiple of the petal half-width.
    solid_gain=1.70,
    # AND SOME CELLS ARE SOLID WHEREVER THEY ARE. FEWER than the leopard's,
    # which ran 0.16..0.30: a leopard's flank is peppered with isolated dots
    # between the rosettes and a snow leopard's is not -- it is rosettes nearly
    # all the way, with the solid spots kept for the head and the legs.
    solid_lo=0.10, solid_hi=0.22,
)

# A SECOND, FINER FIELD FOR THE FACE AND THE LEGS. `rosette.py` says why it
# cannot be the same Voronoi: one field cannot be dense on the head and coarse
# on the flank, because `scale` is global.
FRECKLES = dict(
    # A MULTIPLE OF THE ROSETTE SCALE, so moving `SPOTS['scale']` carries the
    # face with it -- AND IT IS A BIGGER MULTIPLE THAN THE LEOPARD'S 3.1, which
    # is the one place that parameterisation deliberately does not hold. A snow
    # leopard's flank rosettes are half again the size of a leopard's while its
    # FACE dots are about the same, so the ratio between the two fields is
    # genuinely different between the two animals. 2.9 x 4.8 lands at 13.9,
    # against the leopard's 4.6 x 3.1 = 14.3 -- near enough the same absolute
    # freckle, which is the honest answer.
    scale_mul=4.8,
    # The dot, in ITS OWN cell units.
    r=0.34,
    # AND NOT EVERY CELL GETS ONE, which is the whole difference between
    # freckles and polka dots.
    lo=0.40, hi=0.66,
)

# WHERE THE ROSETTES CLOSE UP INTO SOLID SPOTS. All three of these feed ONE
# `solidity` mask, and the mask collapses the ring rather than switching to a
# second pattern -- so a spot cannot be in two places at once.
HEAD = dict(lo=-1.10, hi=-0.78)     # 1 at the muzzle, 0 by the cheek
LEGS = dict(lo=-0.90, hi=-0.55)     # 1 at the paw, 0 at the belly line
# HOW SOLID THE UNDERSIDE IS. Not 1.0: the chest keeps half-open rosettes,
# which is what stops the boundary reading as a line where one pattern stops
# and another starts.
BELLY_SOLID = 0.85
# AND HOW MUCH SMALLER THE HEAD'S SPOTS ARE.
HEAD_SHRINK = 0.30

BELLY = dict(
    # WHERE THE WHITE STARTS AND STOPS, in z. Smoothstepped rather than cut,
    # because a hard line between two flat colours across the widest part of a
    # sphere reads as a join in the model rather than as markings.
    #
    # HIGHER THAN THE LEOPARD'S, because there is more of it on this animal --
    # a snow leopard is white from the chin to the belly and it is most of what
    # makes the smoke above it read as smoke.
    hi=-0.16, lo=-0.58,
    # THE TILT, which is what stops the white being a bathtub ring. The
    # boundary is measured on `z + tilt*y`, so at the nose it sits `tilt`
    # higher and at the tail `tilt` lower -- a pale chin and chest running back
    # to a smoky haunch.
    tilt=0.30,
    # THE LEGS COME BACK OUT OF IT, or a mask that is purely "low is white"
    # paints four white posts.
    leg_lo=-0.80, leg_hi=-0.56,
)

# THE SMOKE OVER THE BACK -- the one field this skin has and the leopard does
# not. Measured on `z + tilt*y` exactly as the belly is, so the two boundaries
# are parallel and the animal reads as one gradient from spine to belly rather
# than as two unrelated bands.
#
# THE TILT IS POSITIVE AND SMALLER THAN THE BELLY'S, which is what keeps the
# FACE out of it: at the nose the boundary sits `tilt` higher, so the smoke
# only reaches the very crown of the head, and the muzzle stays pale. A snow
# leopard's face is white with black dots on it, and smoke across the muzzle
# was the first thing that made this read as a grey cat rather than a white
# one.
# AND IT COVERS THE FLANK RATHER THAN THE SPINE, WHICH IS A LIGHTING FINDING
# AND NOT A TASTE ONE. It ran -0.20..0.45 first -- smoke on the top of the
# animal, which is where a snow leopard's smoke is -- and it was measured at
# 20% of the body sheet and INVISIBLE in all four renders. The reason is that
# the top of a pig is also the surface most square to the sun: a darker albedo
# there is cancelled almost exactly by the brighter light landing on it, so the
# one place the band was strongest is the one place it could not be seen.
#
# Dropped to the mid-flank it lands on surfaces at a grazing angle to the sun,
# where albedo is what the eye reads, and the ladder finally shows. THE GENERAL
# SHAPE IS WORTH KEEPING: a tone that varies with HEIGHT on a round animal is
# competing with the lighting gradient, and the two cancel on top and reinforce
# on the side.
DORSAL = dict(colour=SMOKE, lo=-0.62, hi=0.10, tilt=0.15)

# THE SNOUT DISC IS PINK, the one place this leaves the animal and stays with
# the object. A snow leopard's nose is dark; a piggy bank's snout is pink, and
# this catalogue's leopard already made that call. `lo` is where the pad is at
# full strength and `hi` is where it has faded out, so it is a disc on the end
# of the snout and not a band across the muzzle.
NOSE = dict(lo=-1.30, hi=-1.16)

# THE EYES ARE NOT CLEARED. `rosette.py` carries that argument in full: the
# tiger's rule is about a STRIPE arriving at a black dome with nowhere to end,
# and a spot already has an end, so the clearance only ever drew a bare halo.


# -------------------------------------------------------------- the driver
# ONE DICT, BECAUSE THE ENGINE TAKES ONE. Everything a person would want to
# change is above this line, and nothing below it is a decision about a snow
# leopard.
rosette.build(bpy, paths, "snowleopard", dict(
    coat=COAT, pale=WHITE, fill=FILL, ink=INK,
    ear=EAR_PINK, snout=NOSE_PINK,
    dorsal=DORSAL,
    spots=SPOTS, freckles=FRECKLES,
    belly=BELLY, head=HEAD, legs=LEGS, nose=NOSE,
    belly_solid=BELLY_SOLID, head_shrink=HEAD_SHRINK,
), SRC, OUT)
