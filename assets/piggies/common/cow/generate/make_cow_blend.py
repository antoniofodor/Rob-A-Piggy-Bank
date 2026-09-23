# -*- coding: utf-8 -*-
"""Build the Dairy Cow's coat as a node graph, in its own blend file.

    blender.exe --background --python assets/piggies/common/cow/generate/make_cow_blend.py

Writes `assets/piggies/common/cow/source/cow.blend`. Then the ordinary loop:

    blender.exe --background --python make/bake_skin.py       -- --skin cow
    blender.exe --background --python make/make_view_blend.py -- --skin cow --render

THE PATTERN IS DEFINED IN 3D, NEVER IN UV SPACE -- see `WORKFLOW.md`. The
shader is evaluated at a POSITION on the surface, so Smart UV Project can
rotate every island however it likes and a blotch still lands where the
geometry says it lands. The bake resolves it afterwards.

A COW IS A LEVEL SET, AND THAT IS A THIRD PRIMITIVE RATHER THAN A THIRD SET OF
NUMBERS. It is worth naming all three, because which one an animal wants is the
only decision in a skin script that cannot be fixed by turning a dial:

    tiger       a WAVE.  One global phase expression -- rings about the
                nose-tail axis -- so every stripe is a slice of one field.
    leopard     a CELL FIELD.  Each rosette is an object with a centre.
    giraffe     the SAME cell field read from the other side: each patch is a
                cell shrunk back inside its own wall.
    cow         a LEVEL SET.  One smooth noise, one threshold, and the blotch
                is simply everywhere the field happens to fall below it.

WHY A CELL FIELD CANNOT DRAW A COW, WHICH IS THE WHOLE REASON THIS FILE IS NOT
THE GIRAFFE WITH DIFFERENT NUMBERS. A Voronoi blob is ONE PER CELL, so however
much the sizes are varied the blobs stay EVENLY SPACED -- and even spacing is
the single loudest tell that a pattern was generated. A Holstein is the
opposite of evenly spaced: its blotches run together across the back into one
long connected mass, leave whole white regions with nothing in them at all, and
drop isolated islands off their own coastlines. A level set does all three for
free, because it never had a notion of "one blob" to begin with -- what it has
is a region, and a region may be connected here and absent there.

`Config.SKINS.cow`'S OWN COMMENT ALREADY KNEW THIS from the other end. It says a
cow is "blotches rather than dots" with "heavy size jitter", and that the
giraffe wants LOW jitter because "a giraffe reads as a tiling". Those are two
statements about the same axis, and this file is what happens when the second
one is taken seriously enough to change the primitive rather than the dials.

THE COORDINATE FRAME IS THE PIG'S OWN, measured off the mesh rather than
assumed. Every part sits at identity, so object space IS world space and all
five parts share one frame -- which is what lets a blotch run off the flank onto
a leg with no seam:

    x   across          body reaches +-1.000
    y   NOSE to TAIL    snout tip -1.381, body -1.080..1.052, tail tip 1.465
    z   floor to CROWN  legs -1.020, body -0.960..0.960, ear tip 1.309

So -Y is the face and +Z is up.

AND THE FIELD IS 3D, SO THE TWO FLANKS DISAGREE, WHICH IS FREE AND IS THE POINT.
Nothing here is mirrored on |x| at all, so the left side of
the pig carries different blotches from the right -- exactly as a real cow does,
and exactly what a hand-painted mask would have had to be drawn twice to get.
"""

# --- find the toolkit, wherever this script has been filed ------------------
# Walks up from this file until it finds the folder holding `paths.py`. Depth
# independent on purpose: a script in `make/` and a generator in `assets/piggies/common/cow/generate/` are
# two and three levels down, and a hardcoded `..` is a thing that breaks
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
OUT = arg("--out", paths.skin_blend("cow"))

# --------------------------------------------------------------- the colours
# READ OFF `Config.SKINS.cow` rather than copied, for the reason
# `skin_colours.py` exists: two preview scripts once carried their own pairs
# and two of the eight had drifted, so the sheet used to JUDGE a pattern was
# showing colours the game does not ship. A slightly wrong white looks exactly
# like a white.
WHITE, MUZZLE_PINK = skin("cow")

# AND THIS IS THE FIRST SKIN WHERE `trim` IS USED FOR WHAT CONFIG SAYS IT IS
# FOR, WHICH IS WORTH SAYING BECAUSE THE OTHER TWO ARE NOT. The leopard takes
# its `trim` as a rosette centre and the giraffe takes its as the patch colour,
# both repurposings, both declared. `Config.SKINS.cow`'s own comment says the
# trim "stays PINK rather than going black with the blotches. It paints the
# snout, and a cow's muzzle is the one part of it that is pink" -- so here the
# field already names the muzzle, and the muzzle is what it paints.

# THE BLOTCH IS HARDCODED, AND THAT IS A DECISION RATHER THAN AN OVERSIGHT.
# It is `Config.SKINS.cow.pattern.colour`, which `skin_colours.skin()` cannot
# read -- it parses the `body`/`trim` pair and nothing else. The tempting fix is
# a second parser in the toolkit; the reason not to is that THE FIELD DOES NOT
# SURVIVE THIS SKIN SHIPPING. `WORKFLOW.md`'s own upload steps end with
# `surface = "<pack>"` on the skin "and delete its `pattern` block" -- so a
# toolkit function reading `pattern.colour` would be a dependency on a value
# scheduled for deletion, which is a worse drift than a literal with a comment
# on it. Same call the tiger and the leopard make for their own inks.
INK = (34 / 255., 32 / 255., 38 / 255.)     # Config pattern.colour, today

# The one place a pig shows skin rather than fur and Config has nothing to say
# about it. The catalogue standard, shared with the tiger, leopard and giraffe:
# an inner ear is a fact about the PIG rather than about which animal it is
# wearing, so it does not change per skin.
EAR_PINK = (247 / 255., 201 / 255., 180 / 255.)

# --------------------------------------------------------------- the tunables
# EVERY NUMBER THAT DECIDES WHAT THE COAT LOOKS LIKE IS IN THESE DICTS, so a
# note like "too much black" is a one-line edit and a two-second re-run.
#
# EVERY NUMBER BELOW EXCEPT `scale` AND `seed` IS IN FIELD UNITS -- the units of
# Blender's noise `Fac`, which runs 0..1 and is bunched hard around 0.5. That
# bunching is the ruler for every threshold here, and it was MEASURED off two
# real bakes rather than estimated: `look/ink_coverage.py` counted 26.3% ink at
# `level` 0.442 and 37.2% at 0.474, which fits a standard deviation of about
# 0.085. So a shift of 0.085 is a big move, 0.01 is a nudge, and `level` 0.5
# would be an even black-and-white split.
#
# AND THE FIRST THING THAT MEASUREMENT SETTLED IS THAT `level` IS THE WRONG DIAL
# FOR ALMOST EVERYTHING. Two builds that looked nothing alike -- one a solid
# black cap over the whole back, the other a scatter of dalmatian spots -- were
# 31% ink and 26% ink. FIVE POINTS APART. What actually changed between them was
# `scale`, and what `scale` moves is not how much black there is, it is whether
# the black is CONNECTED: at 1.45 the field's largest feature is wider than the
# pig, so one region swallows the topline, and at 1.90 the same area breaks into
# separate blobs. Reach for `scale` when the picture is wrong and for `level`
# only when the AMOUNT is wrong, or the fix will be a coincidence.
BLOTCH = dict(
    # WHICH ARRANGEMENT. A displacement applied to every noise in the graph, so
    # changing it rerolls the WHOLE pattern at identical statistics -- same
    # blotch size, same coverage, same coastline, different picture.
    #
    # IT IS THE ONLY DIAL HERE THAT IS NOT A PROPERTY OF THE ANIMAL, AND IT HAD
    # TO BE ADDED RATHER THAN BEING THERE FROM THE START. A level set draws one
    # particular arrangement, and the texture ships ONCE -- so every cow in the
    # game is this exact pig, and "the back happens to be one solid black mass"
    # is not a statistic to be tuned away, it is a fact about which sample was
    # drawn. Without a seed the only way to move it is to change `scale` or
    # `level`, which fixes the back by making every blotch on the animal a
    # different size. Two problems, one dial, and the first build had it.
    #
    # `Config.SKINS.cow.pattern.seed` IS 11 AND THIS IS NOT 11, WHICH IS WORTH
    # A LINE BECAUSE THE OBVIOUS THING IS TO MATCH IT. That seed feeds a
    # completely different generator -- the code-built scatter of round spots --
    # so the number names an arrangement in a system this file does not use, and
    # carrying it across would be a coincidence dressed as a reference.
    #
    # WHAT THIS SEED IS ACTUALLY CHOSEN ON IS THE EYES, and it is the dial that
    # carries them because there is no clearance -- see the long note beside
    # `NOSE`. A blotch is within 1.009:1 of the colour of the game's eye part, so
    # an eye inside one is not a smear, it is GONE. That is not something to
    # tune away and it is not something to carve a hole for; it is something to
    # ARRANGE around, and `seed` is the only dial that moves the arrangement
    # without moving every blotch size on the animal at the same time.
    #
    # MEASURED RATHER THAN EYEBALLED, because "does the eye read" is a question a
    # hero shot answers badly -- one eye is always facing away. A probe walked a
    # ring of points round each eye anchor, projected them onto the body, took
    # each one's UV and read the BAKED SHEET there, over twelve seeds:
    #
    #     both eyes on coat   2, 7, 13, 17, 41
    #     one swallowed       3, 19, 37, 47
    #     both compromised    5, 29, 31
    #
    # so SEVEN OF TWELVE ARRANGEMENTS EAT AN EYE, which is the number that says
    # this had to be chosen rather than left to chance. Of the five survivors, 7
    # runs 42% ink and reads heavy and 17 runs 29% and reads sparse; 13 is 34%,
    # and of the two in band it separates its blotches better than 2 does. The
    # blotches still run right up to both eyes -- which is the point, and is what
    # a clearance would have thrown away.
    seed=13,
    # HOW BIG. Blotches per stud, so the body's 2.0 studs across carries about
    # `2*scale` of them -- and this is LOW on purpose, because the difference
    # between a cow and camouflage is entirely the size of the blob. Camouflage
    # is many mid-sized patches; a Holstein is a handful of enormous ones.
    scale=1.62,
    # HOW FRACTAL THE FIELD IS. Left low deliberately: a high detail gives a
    # coastline that is noisy at every scale, which reads as GRAVEL round the
    # edge of a blotch. The big lobes come from `edge` below instead, which is
    # one frequency rather than all of them.
    detail=1.0, roughness=0.42,
    # THE THRESHOLD, and therefore how much of the pig is black. At 0.500 it
    # would be half; at 0.478 it is nearer a third, which leaves white the
    # dominant colour -- and white dominant is what makes the black read as
    # MARKINGS rather than as a dark animal with white bits.
    level=0.470,
    # THE COASTLINE. A faster noise ADDED TO THE FIELD before it is
    # thresholded, so the boundary bulges into lobes and throws out peninsulas
    # and the occasional island. Adding it to the field rather than to the
    # threshold matters: it perturbs the SHAPE, and an island is a place where
    # the perturbation alone crossed the line.
    #
    # `edge_scale` HAS TO SIT WELL CLEAR OF `scale` OR IT STOPS BEING A
    # COASTLINE AND BECOMES A SECOND OCTAVE. At 3.6 against a base of 1.9 it is
    # only 1.9x the base frequency at 40% of its amplitude, which is very nearly
    # the definition of another octave of fBm -- and the result was measured:
    # the blotches pinched into a stringy LABYRINTH of connected filaments,
    # which is what thresholding a rougher field near its median always gives.
    # At 4.6 against 1.62 it is 2.8x, high enough to chew the boundary and too
    # high to redraw the blob. This is the same trap `detail` sets one line
    # above, arriving from outside the noise node instead of inside it.
    edge=0.028, edge_scale=4.6,
    # THE RAGGED EDGE, at the scale of the boundary itself. Small on purpose --
    # enough that no edge is a clean arc, not so much that a blotch turns to
    # gravel. This is the tiger's `grain` and the giraffe's, doing the same job
    # on a third primitive.
    grain=0.007, grain_scale=14.0,
)

# WHERE THE BLACK GOES, AND ALL OF IT IS ONE SUBTRACTION FROM `level`. Same
# architecture as the giraffe's single `gap`: there is no second mask anywhere,
# so a blotch cannot be killed by one rule and drawn by another.
#
# The underside. A Holstein is white under the belly whatever it is doing
# above, and it is the single biggest thing stopping an all-over print reading
# as upholstery.
BELLY_CLEAR = 0.130
# The feet. White socks are as much a part of the animal as the blotches are.
SOCKS = dict(lo=-1.00, hi=-0.78, sub=0.105)
# The muzzle, which has to be clear for a reason beyond the animal: the snout
# disc is PINK, so a blotch laid over it would be black on pink and the pad
# would stop reading as a snout at all.
MUZZLE = dict(lo=-1.22, hi=-0.92, sub=0.115)
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

# AND THE ONE ADDEND THAT GOES THE OTHER WAY. A cow is more heavily marked
# along its topline than down its sides, which is what stops the coverage
# reading as even -- and evenness is the thing this whole primitive was chosen
# to avoid.
TOPLINE = dict(lo=0.05, hi=0.88, add=0.012)

BELLY = dict(
    # WHERE THE WHITE UNDERSIDE STARTS AND STOPS, in z. Smoothstepped rather
    # than cut, because a hard line across the widest part of a sphere reads as
    # a join in the model rather than as markings.
    hi=-0.22, lo=-0.62,
    # THE TILT, which is what stops it being a bathtub ring. The boundary is
    # measured on `z + tilt*y`, so at the nose it sits higher and at the tail
    # lower -- a white chest and jaw running back to a marked haunch, which is
    # how the markings actually sit.
    tilt=0.30,
    # THE LEGS COME BACK OUT OF IT. They hang entirely below the belly line, so
    # a rule that is purely "low is clear" leaves four blank white posts -- and
    # a Holstein's upper leg usually carries the bottom of a body blotch. Fading
    # the clearance out again below `leg_hi` puts that blotch back, and `SOCKS`
    # above then takes it off the foot again.
    leg_lo=-0.78, leg_hi=-0.58,
)

# THE SNOUT DISC IS PINK, AND HERE THAT IS THE ANIMAL RATHER THAN A CONCESSION
# TO THE OBJECT. The leopard's and the giraffe's snouts are pink because a
# piggy bank's is, and both say so; a cow's muzzle really is pink, which is why
# `Config.SKINS.cow` puts that colour in `trim` in the first place. `lo` is
# where the pad is at full strength and `hi` is where it has faded out.
NOSE = dict(lo=-1.30, hi=-1.15)

# THE EYES ARE NOT CLEARED, AND THE SEED IS WHAT CARRIES THEM INSTEAD.
#
# The tiger and the leopard both cut a disc of coat away round each eye, and
# `WORKFLOW.md` rule 6 says to. The giraffe dropped it, because a broad flat
# patch containing an eye reads as an eye ON a patch while the ring it left
# behind read as a defect. The cow drops it too -- and the reason it took a
# different fix is worth the paragraph, because the measurement here says the
# opposite of what the giraffe's did.
#
# The game's eye is a code-built part painted near-black, (38, 30, 34), standing
# proud of the body at (+-0.318, -0.889, 0.364) -- read off `EyePreview` rather
# than guessed. Measured as a WCAG contrast ratio against what each skin would
# paint under it:
#
#     giraffe patch (168, 120, 62)  vs the eye   4.198 : 1   reads
#     tiger ink     ( 48,  34, 28)  vs the eye   1.062 : 1   invisible
#     cow blotch    ( 34,  32, 38)  vs the eye   1.009 : 1   invisible
#
# 1.009 is as close to identical as two different triples get, so an eye inside
# a blotch is not a smear -- it is GONE, and the pig loses an eye. That is a
# real constraint and it does not go away by ignoring it.
#
# WHAT IT DOES NOT JUSTIFY IS A CLEARANCE, WHICH WAS BUILT FIRST AND IS WORSE
# THAN THE PROBLEM. A disc at 0.26..0.40 was tried, and on the arrangement that
# was current at the time a blotch happened to wrap right round the near eye --
# so the clearance punched a WHITE DONUT out of the middle of it. That reads as
# a printing fault rather than as markings, and it is the same halo the giraffe
# threw its clearance away over, arriving on a shape that makes it louder.
#
# THE HONEST DIAL IS `seed`. A clearance says "there is never black here", which
# is a claim about the animal that is not true; a seed says "this cow's blotches
# fall like THIS", which is the only thing a level set was ever going to let
# anybody choose. So the pattern runs wherever it runs, and the arrangement is
# picked so that it runs AROUND the eyes rather than over them -- verified by
# looking, not by arithmetic, because whether an eye reads is a question about a
# picture. See `seed` above for what was rejected and why.
#
# IF A LATER SEED EVER SWALLOWS AN EYE, THE FIX IS ANOTHER SEED. It is not a
# clearance, and it is not darkening the eye part -- that is `make_view_blend`'s
# preview colour standing in for the game's own `NEAR_BLACK`, and a skin does
# not get to move it.


# ------------------------------------------------------------------ plumbing
def seed_offset(n):
    """A fixed displacement per seed number.

    Blender's noise has no seed input -- what it has is a position, and the
    field is stationary, so MOVING THE SAMPLE POINT IS THE SEED. The three
    components are deliberately unrelated to each other and large compared with
    the pig (which is about two studs), so one step of `n` lands in an entirely
    different part of the field rather than a neighbouring one.
    """
    import math
    return (math.sin(n * 12.9898) * 43.7,
            math.sin(n * 78.2330) * 51.3,
            math.sin(n * 39.4250) * 47.1)


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
    """The cow's coat as one material. Built twice -- once for the body and
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

    def raw_noise(x, y, label, scale, detail, offset, roughness=0.55):
        """The noise `Fac` itself, 0..1, sampled at an OFFSET position.

        THE BASE FIELD WANTS THE RAW VALUE AND THE PERTURBATIONS WANT THE
        CENTRED ONE, which is why there are two helpers here rather than one.
        `level` is a threshold on this field, so it has to be expressed in the
        same 0..1 units the field is in -- centre and stretch it and `level`
        stops meaning anything a person can reason about.
        """
        off = node("ShaderNodeVectorMath", x - 220, y, "offset")
        off.operation = 'ADD'
        off.inputs[1].default_value = offset
        n = node("ShaderNodeTexNoise", x, y, label)
        n.noise_dimensions = '3D'
        n.inputs['Scale'].default_value = scale
        n.inputs['Detail'].default_value = detail
        n.inputs['Roughness'].default_value = roughness
        link(off.outputs['Vector'], n.inputs['Vector'])
        return off, n

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
        up -- so the coastline and the ragged edge would bulge in the same
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

    # ---- the belly, which does ONE job here rather than two ----------
    # ON THE TIGER, THE LEOPARD AND THE GIRAFFE THIS MASK DOES TWO THINGS:
    # it recolours the underside cream AND it suppresses the markings there.
    # A cow's coat is ALREADY the colour its underside should be, so there is
    # no second colour to mix and this mask only suppresses. That is why the
    # graph below ends in two colour mixes where the giraffe's needs three.
    lift = math('MULTIPLY_ADD', -2200, 900, "z + tilt*y", b=BELLY['tilt'])
    link(Y, lift.inputs[0])
    link(Z, lift.inputs[2])
    belly_a = rng(-2000, 900, "clear below", BELLY['lo'], BELLY['hi'], 1.0, 0.0)
    link(lift.outputs[0], belly_a.inputs['Value'])
    leg_out = rng(-2000, 700, "but not the legs",
                  BELLY['leg_lo'], BELLY['leg_hi'], 0.0, 1.0)
    link(Z, leg_out.inputs['Value'])
    belly = math('MULTIPLY', -1780, 820, "UNDERSIDE MASK")
    link(belly_a.outputs['Result'], belly.inputs[0])
    link(leg_out.outputs['Result'], belly.inputs[1])

    # ---- the field ---------------------------------------------------
    # ONE SMOOTH NOISE IS THE WHOLE BLOTCH. Everything added to it below
    # perturbs the SHAPE of the boundary rather than moving the boundary, which
    # is the difference between a lobed coastline and a wobbly circle.
    # THE SEED SHIFTS ALL THREE TOGETHER and the per-noise offsets stay on top
    # of it, because those two do different jobs: the seed picks which sample of
    # the field this animal is, and the offsets keep the three fields from
    # lining their large features up with each other.
    sd = seed_offset(BLOTCH['seed'])

    def at(o):
        return (sd[0] + o[0], sd[1] + o[1], sd[2] + o[2])

    b_off, base = raw_noise(-2200, -200, "THE FIELD",
                            BLOTCH['scale'], BLOTCH['detail'], at((0.0, 0.0, 0.0)),
                            roughness=BLOTCH['roughness'])
    link(co.outputs['Object'], b_off.inputs[0])

    e_off, edge = snoise(-2200, -560, "COASTLINE",
                         BLOTCH['edge_scale'], at((11.0, 4.0, -7.0)))
    link(co.outputs['Object'], e_off.inputs[0])
    e_s = math('MULTIPLY', -1700, -560, "coastline amount", b=BLOTCH['edge'])
    link(edge.outputs['Result'], e_s.inputs[0])

    g_off, grain = snoise(-2200, -880, "RAGGED EDGE",
                          BLOTCH['grain_scale'], at((-6.0, 13.0, 5.0)), detail=3.0)
    link(co.outputs['Object'], g_off.inputs[0])
    g_s = math('MULTIPLY', -1700, -880, "grain amount", b=BLOTCH['grain'])
    link(grain.outputs['Result'], g_s.inputs[0])

    f1 = math('ADD', -1480, -300, "+ coastline")
    link(base.outputs['Fac'], f1.inputs[0])
    link(e_s.outputs[0], f1.inputs[1])
    field = math('ADD', -1300, -360, "FIELD HERE")
    link(f1.outputs[0], field.inputs[0])
    link(g_s.outputs[0], field.inputs[1])

    # ---- the threshold, and everything that moves it -----------------
    top = rng(-2200, 620, "more along the topline",
              TOPLINE['lo'], TOPLINE['hi'], 0.0, TOPLINE['add'])
    link(Z, top.inputs['Value'])
    muz = rng(-2200, 440, "clear toward the nose",
              MUZZLE['lo'], MUZZLE['hi'], MUZZLE['sub'], 0.0)
    link(Y, muz.inputs['Value'])
    sox = rng(-2200, 260, "clear toward the foot",
              SOCKS['lo'], SOCKS['hi'], SOCKS['sub'], 0.0)
    link(Z, sox.inputs['Value'])
    und = math('MULTIPLY', -2000, 120, "and under the belly", b=BELLY_CLEAR)
    link(belly.outputs[0], und.inputs[0])

    # MAXIMUM AND NOT A SUM, because these overlap: the chin is muzzle AND
    # underside, and adding them there would clear a region twice as hard as
    # either rule asked for -- which on a threshold is not "whiter", it is a
    # bald patch with a visible edge where the two masks happen to stop.
    k1 = math('MAXIMUM', -1780, 380, "")
    link(muz.outputs['Result'], k1.inputs[0])
    link(sox.outputs['Result'], k1.inputs[1])
    clear = math('MAXIMUM', -1600, 280, "WHERE THE BLACK GOES")
    link(k1.outputs[0], clear.inputs[0])
    link(und.outputs[0], clear.inputs[1])

    lvl0 = math('ADD', -1400, 560, "level + topline", b=BLOTCH['level'])
    link(top.outputs['Result'], lvl0.inputs[0])
    level = math('SUBTRACT', -1200, 420, "LEVEL HERE")
    link(lvl0.outputs[0], level.inputs[0])
    link(clear.outputs[0], level.inputs[1])

    # ---- black or white ----------------------------------------------
    # A THRESHOLD AND NOT A RAMP. The bake runs at 2048 and delivers at 1024,
    # so every delivered texel is the average of four and the downscale is what
    # does the anti-aliasing -- a soft edge in the graph on top of that is
    # mush. See `WORKFLOW.md`.
    blotch_raw = math('LESS_THAN', -1000, -360, "below the level?")
    link(field.outputs[0], blotch_raw.inputs[0])
    link(level.outputs[0], blotch_raw.inputs[1])

    # ---- the nose pad is cleared, and the eyes deliberately are not ---
    # THE EYE CLEARANCE THE TIGER AND THE LEOPARD BOTH CARRY IS ABSENT HERE ON
    # PURPOSE -- the argument is up beside `NOSE`, and the dial that replaces it
    # is `seed`. `X` is therefore unused past the coordinate split, and nothing
    # in this file is mirrored on |x| any more: the two flanks are two different
    # samples of one 3D field, which is what a real cow is.
    nose_pad = rng(-2200, 1100, "the snout disc",
                   NOSE['lo'], NOSE['hi'], 1.0, 0.0)
    link(Y, nose_pad.inputs['Value'])
    keep = math('SUBTRACT', -1480, 1100, "no blotch on the pad", a=1.0)
    link(nose_pad.outputs['Result'], keep.inputs[1])

    blotch = math('MULTIPLY', -800, -360, "BLOTCH MASK")
    link(blotch_raw.outputs[0], blotch.inputs[0])
    link(keep.outputs[0], blotch.inputs[1])

    # ---- the two colours ---------------------------------------------
    # TWO MIXES, WHERE THE GIRAFFE NEEDS THREE AND THE LEOPARD FOUR. A cow's
    # coat and a cow's underside are the same white, so there is no third tone
    # to lay in -- which is worth noticing rather than merely being true, since
    # it is the same fact that let the belly mask above do only one job.
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

    m1, f1c, a1, b1, o1 = mix_rgb(nt, "white -> the muzzle pad")
    m1.location = (-400, 900)
    a1.default_value = to_linear(WHITE) + (1.0,)
    b1.default_value = to_linear(MUZZLE_PINK) + (1.0,)
    link(hard(nose_pad.outputs['Result'], -700, 1100,
              "the muzzle pad"), f1c)

    m2, f2, a2, b2, o2 = mix_rgb(nt, "lay the blotches on")
    m2.location = (-100, 700)
    b2.default_value = to_linear(INK) + (1.0,)
    link(hard(blotch.outputs[0], -400, 700, "the blotches"), f2)
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

body_mat = coat("cow_body")
trim_mat = coat("cow_trim")
ear_mat = flat("cow_ear_inner", EAR_PINK)

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
assign(bpy, ASSIGN, "COW  (from %s)" % SRC)

for _n, _c in face_slots(bpy, [n for n, _ in ASSIGN]):
    if len(_c) > 1:
        print("  %-6s faces per slot %s  <- hand selection, intact"
              % (_n, _c))

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("")
print("  saved %s -- %s is untouched"
      % (os.path.relpath(OUT, D), os.path.relpath(SRC, D)))
print("  seed %d, about %.1f blotches across the body, level %.3f"
      " (%+.3f topline, -%.3f belly)"
      % (BLOTCH['seed'], BLOTCH['scale'] * 2.0, BLOTCH['level'],
         TOPLINE['add'], BELLY_CLEAR))
