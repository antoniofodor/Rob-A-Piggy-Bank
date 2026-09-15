# -*- coding: utf-8 -*-
"""Build STORM STONE as a node graph, in its own blend file.

    blender.exe --background --python skins/stormstone/make_stormstone_blend.py

Writes `skins/stormstone/stormstone.blend`. Then the ordinary loop, plus the
alpha pass:

    blender.exe --background --python make/bake_skin.py  -- --skin stormstone
    blender.exe --background --python make/bake_alpha.py -- --skin stormstone
    python make/apply_alpha.py --skin stormstone

THE PATTERN IS DEFINED IN 3D, NEVER IN UV SPACE -- see `WORKFLOW.md`.

THIS IS THE STORM WOLF'S FORK MACHINERY ON MAGMA'S PLATES, AND ALMOST NONE OF
IT IS NEW. That is the point rather than an economy. Two things in this
toolkit were already built, argued about at length and measured:

  * a VORONOI NET is the only primitive here with BRANCHING in it, which is
    what makes it the only thing that can draw lightning -- Storm Wolf's own
    header records the A/B where a warped-noise contour lost, and lost because
    a contour of a scalar field has no junctions in it at any width.
  * a VORONOI CELL FIELD thresholded on distance-to-edge is a field of PLATES
    with seams between them, which is Magma's crust and the Giraffe's patches.

The animal that wants both is a creature made of STONE with lightning running
in the cracks, and it is what the reference photograph actually shows. So the
storm half below is Storm Wolf's, unchanged and deliberately untouched, and
the half above it is new.

WHAT CHANGED FROM THE WOLF, STATED PLAINLY, because a reader who knows that
file will otherwise go looking for the differences. The saddle, the pale
underside, the muzzle mask, the brow spots and the tail tip are all GONE --
they are the markings of a mammal with fur, and this animal has none. In their
place is one plate lattice carrying four tones. Everything from
`# ===== THE STORM` down is byte-identical to the wolf.

FOUR TONES PICKED PER PLATE, WHICH IS THE DRAGON'S TRICK AND THE WHOLE READ OF
THE HIDE. A field of one grey is a boulder. What says BROKEN STONE is that
neighbouring facets disagree slightly about their own colour, the way a real
fracture face does -- so the per-cell random that already varies the seam width
is read a second time as a COLOUR index. A plate's tone is then a fact about
that plate, and two neighbours differ without a second pattern anywhere.

THE FOURTH TONE IS ORE, AND IT IS THE ONE THAT IS NOT PURELY PER-CELL. A warm
brown-olive, and it is masked to the LOWER body as well as to a slice of the
random -- so the ore reads as something the animal has been standing in rather
than as a fourth colour sprinkled evenly over it. The reference has exactly
this: grey over the back and shoulders, warm brown low on the flank and round
the feet.

THE SNOUT IS PINK AND THAT REVERSES WHAT MAGMA AND DRAGON BOTH DECIDED. Both
of those files carry the same paragraph -- "this animal is not a pig wearing a
coat, it is a pig MADE of something, and a thing made of one material does not
have a nose made of another" -- and both are right about themselves. The
reference disagrees, and it is worth being exact about why rather than simply
following it: a rock creature with a rock nose reads as a ROCK, and the whole
value of this catalogue is that the thing under the costume is a PIGGY BANK.
The snout is the cheapest possible place to say so and the one a nine-year-old
reads first. It is a flat material on the Snout's own slot rather than a mask
in the trim coat, so it costs no nodes and no lightning can wander onto it.

WHAT THIS FILE DOES NOT DO IS THE SHARDS. The broken rock standing off the
back and crowning the head is GEOMETRY, and it is built in code rather than
here: `PiggyModel.applyPattern`'s `shards` kind, which is a pattern spec on the
`Config.SKINS` row. That is deliberate and not a split of convenience -- a
pattern part carries its OWN material, so the bolts arcing off the silhouette
can be Neon and actually reach the BloomEffect, where nothing baked into a
sheet ever can: a `SurfaceAppearance` has no emissive channel at all, and
`Config.skinSurface` refuses Neon alongside a surface pack. So the light on
this animal comes off its outline and the coat carries the pattern. Neither
half reads without the other.

THE COORDINATE FRAME IS THE PIG'S OWN, measured off the mesh:

    x   across          body reaches +-1.000
    y   NOSE to TAIL    snout tip -1.381, body -1.080..1.052, tail tip 1.465
    z   floor to CROWN  legs -1.020, body -0.960..0.960, ear tip 1.309

So -Y is the face and +Z is up.
"""

# --- find the toolkit, wherever this script has been filed ------------------
# Walks up from this file until it finds the folder holding `paths.py`. Depth
# independent on purpose: a script in `make/` and a script in `skins/stormstone/`
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
import bpy, os, sys, math   # noqa: E402

from skin_colours import to_linear   # noqa: E402
from skin_parts import assign, face_slots   # noqa: E402


argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SRC = arg("--blend", paths.PARTS)
OUT = arg("--out", paths.skin_blend("stormstone"))

# --------------------------------------------------------------- the colours
# NOT READ OUT OF `Config.luau`, for the reason Magma's and Dragon's are not:
# there is no `stormstone` row to disagree with yet. When one is written it
# should take PLATE_MID as `body` and PLATE_DARK as `trim`, which are the two a
# fallback pair wants -- an unpacked pig then still reads as grey stone rather
# than as a mid-tone blob.

# ---- the hide ------------------------------------------------------------
# FOUR PLATE TONES, PICKED PER CELL -- see the header.
#
# **THE FIRST BUILD WAS A FOOTBALL, AND THE SPREAD WAS HALF OF WHY.** These
# went in at (58,64,80) / (92,100,116) / (142,150,164) on the reasoning that
# fracture faces catch different light and therefore want a WIDER spread than a
# dragon's four greens. Rendered, the three tones read as three separate
# MATERIALS rather than as one rock lit unevenly, and with a near-black seam
# round each of them the animal came back as a mosaic -- panels stitched
# together, which is a ball rather than a boulder.
#
# The rule the render settled: a plate's tone says WHICH WAY THIS FACET IS
# TURNED, so the spread has to stay inside what one material can plausibly do
# under one sun. Narrowed and pulled down about a third, which also puts the
# animal where the reference actually sits -- near-black with grey facets,
# rather than mid-grey with pale ones.
#
# **AND THEN DOWN AGAIN, BY ANOTHER THIRD, ON THE REFERENCE.** The values above
# were already a third under the first build and the animal was still lighter
# than the thing being copied. Worth separating the two reasons, because they
# are not the same edit: the first drop was about the SPREAD between the tones
# reading as three materials, and this one is about the LEVEL -- a storm
# creature is a dark object with bright things on it, and every stud of grey in
# the hide is contrast the lightning does not get to have. The bolts are the
# only light on this animal and they are competing with whatever the coat is
# doing.
PLATE_DARK = (26 / 255., 30 / 255., 39 / 255.)
PLATE_MID = (44 / 255., 49 / 255., 60 / 255.)
PLATE_LIT = (74 / 255., 81 / 255., 94 / 255.)

# THE ORE, AND IT IS THE ONLY WARM THING ON THE ANIMAL BAR THE SNOUT. Kept
# desaturated and dark: at any real saturation it stops reading as mineral in
# the rock and starts reading as RUST, which is a different material and a
# different creature. It came down with the greys for the same reason -- at
# the first build's value it read as MUD splashed up the legs.
PLATE_ORE = (56 / 255., 50 / 255., 39 / 255.)

# THE SEAM between plates. Near-black and faintly BLUE, which is the opposite
# call Magma makes and is right for the opposite reason: Magma's obsidian is
# warm so that it does not read as a bruise beside an orange glow, and a cyan
# discharge beside a warm black reads as dirt. The cold seam is what makes the
# bolt look electrical rather than molten.
#
# **AND IT IS NOT NEAR-BLACK, WHICH IS THE OTHER HALF OF THE FOOTBALL.** At
# (14,16,22) against a mid-grey plate the seams were the highest-contrast thing
# on the animal, so the eye read the NET rather than the stone: the pattern
# becomes a set of OUTLINES with fill inside them, which is how a football is
# drawn. A real seam is a shadowed gap a couple of shades under the plate
# beside it, never an inked line round it.
SEAM = (16 / 255., 18 / 255., 23 / 255.)

# ---- the storm -----------------------------------------------------------
# THE RIM either side of a fork, and it is what stops the lightning reading as
# something lying ON the stone. Darker than the darkest plate, so wherever a
# bolt runs it has visibly BURNT the rock it came out of.
STORM = (9 / 255., 10 / 255., 18 / 255.)

# THE CHANNEL. A saturated cyan and not a pale one, which is this project's
# most-repeated colour lesson arriving on a texture instead of on a Neon part:
# what survives being rendered bright is SATURATION, and a colour near white
# has nothing left to be. The shards' own Neon takes this same hue, so the
# baked bolt and the glowing one agree.
BOLT = (94 / 255., 226 / 255., 252 / 255.)

# THE CORE, a white-hot hairline down the middle of the channel. The one place
# near-white is right, because it is a few texels wide and is READ AGAINST the
# channel rather than on its own.
CORE = (226 / 255., 250 / 255., 255 / 255.)

# THE INNER EAR. Every ordinary skin puts a pig's pink here. This one puts the
# storm inside the animal, the same call Magma and Dragon both make -- the ear
# is the one place that reads as looking INTO a creature rather than at it.
EAR_IN = (26 / 255., 74 / 255., 112 / 255.)

# THE SNOUT, and see the header for why a rock creature has a pink one. A
# dusty, desaturated pink rather than the catalogue's usual bubblegum: it has
# to sit on an animal made of slate without looking stuck on.
SNOUT = (222 / 255., 152 / 255., 150 / 255.)

# --------------------------------------------------------------- the tunables
PLATE = dict(
    # HOW MANY. Cells per stud before the squash, so the body's 2.0 studs
    # across carries about `2*scale` of them. Coarser than Magma's crust and
    # far coarser than Dragon's scales: these are FACETS of a broken thing, and
    # the moment there are enough of them to read as a texture the animal is
    # wearing crazy paving instead of being made of rock.
    scale=5.2,
    # HOW IRREGULAR THE SEEDS ARE. HIGH, and it is the single most important
    # number here. An even lattice gives walls of near-equal length meeting at
    # near-equal angles, which is a honeycomb -- and a honeycomb is the one
    # thing broken stone is not. Dragon sits at 0.34 for exactly the opposite
    # reason: scales are GROWN in rows and rock is not.
    randomness=0.94,
    # HALF THE SEAM WIDTH, in cell units, so a seam is `2 * gap` across.
    #
    # **THE FIRST BUILD SHIPPED 0.048 AND IT IS THE SINGLE NUMBER THAT MADE
    # THE ANIMAL A FOOTBALL.** Nearly a tenth of a cell of gap, in near-black,
    # around every plate: what that draws is a NET with fill in the holes, and
    # no amount of tone work on the plates rescues it while the outline is the
    # loudest thing in frame. Halved, and the seam COLOUR lifted to match --
    # those two are one decision, and turning either one alone puts it back.
    gap=0.026,
    # PER CELL rather than per PLACE, so two plates sharing a seam can disagree
    # about how deeply they are seated. Without it every seam is the same
    # weight and the lattice shows through as a pattern.
    cell_vary=0.009,
    # THE RAGGED EDGE, at the scale of the seam's own border. Small -- this is
    # the difference between a drawn line and a fracture, and past about 0.02
    # it eats the narrow seams entirely.
    grain=0.006, grain_scale=19.0,
    # THE SQUASH, and it is MILD here where Dragon's is the whole skin. The
    # input is divided along the nose-tail axis before the lattice is measured,
    # so the plates come back a little wider across the animal than they are
    # long -- which is what strata do. At Dragon's 1.55 these stop being facets
    # and become scales, which is a different creature.
    squash=1.20,
    # WHERE THE FOUR TONES FALL on the per-cell random. Uneven on purpose:
    # mostly dark, a good number mid, fewer lit, and ORE rarest -- so the light
    # facets read as catching the sun rather than as half the animal.
    cut_mid=0.40, cut_lit=0.76, cut_ore=0.90,
    # AND ORE IS ALSO MASKED LOW, which is the one tone that is not purely a
    # fact about its own cell. Measured on the same tilted plane every
    # underside in this project uses, so the warm rock is lower at the haunch
    # than at the chin rather than being a bathtub ring round the widest part
    # of a sphere.
    ore_line=-0.18, ore_tilt=0.28,
)

# --------------------------------------------------------------- the storm
# WHICH FIELD DRAWS A FORK. "net" is a Voronoi cell net; "band" is the level
# set of a warped noise. Both feed the SAME `edge` downstream -- distance from
# a fork's centreline -- so the two are a true A/B with only the field changed.
#
# **"band" LOST, AND IT LOST FOR A DIFFERENT REASON THAN THE ONE PREDICTED,
# WHICH IS THE HALF WORTH KEEPING.** The argument against it, written before it
# was built, was that a level set is smooth and unbranched and would therefore
# read as a GLOWING RACING STRIPE down the flank. Built and rendered, it is not
# a stripe at all: at a width narrow enough to be lightning, the contour of a
# detail-3 noise on a body this curved BREAKS UP, and what comes back is a
# scatter of disconnected puddles and dashes -- water spilt on the animal, or
# mould. Both the smooth-stripe failure and the puddle failure are the same
# fact seen from two ends: A CONTOUR OF A SCALAR FIELD HAS NO JUNCTIONS IN IT.
# Widen it and the puddles merge into a stripe; narrow it and the stripe falls
# into puddles; at no setting does it fork, because there is nothing in the
# field to fork AT.
#
# Branching is not a decoration on lightning, it IS lightning, and the only
# primitive in this toolkit that has any is the Voronoi net. That is the whole
# result of the comparison, and it is why the sparsening masks had to be built
# on top of a net rather than the net being replaced by something tidier.
#
# The measurement was worth taking rather than reasoning about: the prediction
# named the right winner for the wrong reason, and a written-down reason that
# is wrong is how the next person picks the loser for a skin it would suit.
# Overridable from the command line so the A/B is one command rather than an
# edit -- `-- --fork-mode band`, which is how the paragraph above was measured
# rather than asserted.
FORK_MODE = arg("--fork-mode", "net")

FORK = dict(
    # HOW COARSE THE NET IS. Cells per stud, so the body's 2.0 studs across
    # carries about `2*scale` of them. COARSE on purpose: a fine net is Magma,
    # and what makes a fork read is long straight runs between rare junctions.
    scale=3.2,
    # HOW IRREGULAR THE SEEDS ARE. High, because an even lattice gives walls of
    # near-equal length meeting at near-equal angles, which reads as a honeycomb
    # -- and a bolt's angles are the thing that makes it look violent.
    randomness=0.88,
    # HALF THE FORK WIDTH, in cell units. A fork is `2 * w` across, which at
    # this scale is 0.093 studs -- nearly twice a Magma crack, because there
    # are a tenth as many of them and each one has to carry three bands and
    # still be readable at the 175 pixels twelve studs gives it.
    w=0.110,
    # PER CELL rather than per PLACE: a random number attached to the cell
    # itself, so two runs of the same net disagree about how fat they are.
    # Without it every fork is the same weight and the lattice shows through.
    cell_vary=0.018,
    # THE ZIGZAG, AND IT IS A DOMAIN WARP RATHER THAN A WIDTH NOISE.
    #
    # A Voronoi wall is a PLANE, which is straight in flat space and a CIRCLE
    # where it cuts a sphere -- so on a body this round the raw net draws
    # smooth arcs, which is the one thing a fork may not be. Displacing the
    # position before the lattice is measured bends the walls themselves into
    # a jointed polyline; a noise on the WIDTH would only have made their edges
    # ragged, leaving a fuzzy arc.
    #
    # The scale is a little finer than a cell, so a wall picks up two or three
    # kinks along its own length rather than being bodily moved.
    warp=0.115, warp_scale=5.2,
    # THE RAGGED EDGE, at the scale of the fork's own border. Small: this is
    # the difference between a drawn line and a discharge, and past about
    # 0.03 it eats the core.
    grain=0.010, grain_scale=13.0,
    # THE RIBBON -- see the header. The neighbourhood of a level set of a SLOW
    # noise, which is what makes the surviving net linear rather than blobby.
    # `cut` is the half-width in the noise's own units and `soft` is how far
    # past it the fork tapers to nothing.
    #
    # **BIGGER RIBBONS AND BIGGER PATCHES ARE NOT THE SAME AS FEWER, LONGER
    # FORKS, WHICH IS THE ONE THING THIS PAIR LOOKS LIKE IT SHOULD BUY.**
    # Tried at ribbon 0.48 / cut 0.26 with patch 0.62 / cut 0.22, aiming for
    # three long bolts instead of six short ones: what came back was an animal
    # with NOTHING on either flank and every fork piled onto the crown and the
    # ears, because a slower patch noise does not spread its stretches out, it
    # makes each one bigger and leaves larger gaps between them. The flank is
    # the half of a pig anybody looks at, so an empty flank is the worst
    # outcome available. The lever for fork LENGTH is the ribbon; the lever for
    # how EVENLY they are spread is the patch, and it wants to be fast.
    # THE CUTS WENT UP AND CAME STRAIGHT BACK DOWN, and the failure is worth
    # recording because it is the SAME shape the losing fork construction had.
    # Widening these to get "more lightning" does not lengthen the forks, it
    # fattens the masks until what survives is BLOBS -- disconnected puddles
    # and dashes, which is exactly what the warped-noise band did and exactly
    # why it lost. Rendered at 0.52 / 0.34 the animal came back spattered
    # rather than struck.
    #
    # MORE LIGHTNING IS `scale`, NOT THESE. A finer lattice gives more walls
    # for the same ribbon to select from, so the forks stay linear and there
    # are simply more of them.
    ribbon_scale=0.62, ribbon_cut=0.38, ribbon_soft=0.50,
    # THE PATCH. A second, slower noise which breaks each ribbon into separate
    # stretches. Without it the ribbon's level sets are CLOSED LOOPS on a
    # closed surface, and a broken ring round the animal is still a ring.
    patch_scale=0.85, patch_cut=0.22, patch_soft=0.60,
)

# THE THREE BANDS, AS MULTIPLES OF THE WIDTH RATHER THAN AS WIDTHS -- Magma's
# architecture, and the reason it is right here too: the width already carries
# the ribbon, the patch, the per-cell variation, the grain, the eye clearance
# and the muzzle clearance, so all six arrive in the rim and the core without
# one extra node, and none of the three can drift.
#
# `rim` above 1.0 puts the dark OUTSIDE the channel, on the coat. `core` below
# 1.0 puts the white-hot INSIDE it.
BANDS = dict(rim=2.00, core=0.42)

# NO FORKS ON THE MUZZLE. A snout is what a viewer standing on the pavement
# sees first, and a bolt across it is the first thing they see and the last
# thing that should be there -- the muzzle mask is carrying the wolf and a fork
# through it costs more than it buys.
# AND IT IS NEARLY GONE, WHICH REVERSES THE FIRST BUILD'S OWN ARGUMENT.
#
# That build cleared the whole muzzle, on the reasoning below: a snout is what
# a viewer sees first and a bolt across it costs more than it buys. The
# reference this was re-cut against does exactly the opposite -- a fork runs
# down through the eye socket and across the muzzle, and it is the single most
# dramatic thing in the picture. The clearance now covers only the tip, where a
# bolt would land on the nose pad itself and read as damage.
# The clearance covers the PAD and just behind it, not the whole muzzle. A
# fork over the bridge and the brow is the reference; a fork across the
# NOSTRILS reads as damage to the animal rather than as power in it, and it
# was doing exactly that at -1.24.
MUZZLE_CALM = dict(lo=-1.36, hi=-1.13)
# THE EYES, NARROWED RATHER THAN CLEARED -- `WORKFLOW.md` rule 6, done the
# tiger's way. A fork thinning to a point as it nears an eye leaves no ring to
# see, where a hard cut at one radius draws a stencil.
# THE EYE CLEARANCE IS DOWN TO THE EYEBALL'S OWN RIM, for the same reason.
# `EyePreview` is 0.210 across, so an eyeball is 0.105 in radius -- 0.12 to 0.20
# lets a fork run right up to the socket and stop, which is where the reference
# puts it. The taper is on the WIDTH, so a fork ends at its own radius and the
# endpoints scatter rather than tracing a circle -- the tiger's finding, kept.
EYE_CALM = dict(x=0.318, y=-0.889, z=0.364, r0=0.12, r1=0.20)
# AND NOTHING ON THE CROWN, THE SPINE OR THE EARS -- which is Magma's
# `CROWN_CALM` arriving for a completely different reason and landing on the
# same number. There it keeps the silhouette solid so a black animal is not a
# net from above; here it is INHERITED from Storm Wolf, and the reason given
# there -- protecting the saddle -- does not apply, because this animal has no
# saddle. It is kept for the second reason that entry records, which is a
# measurement rather than a marking: forks on both ear backs read as scribble
# rather than as lightning, because an ear is a narrow tapering shape and a
# fork on it has no room to be a fork. That is a fact about the GEOMETRY, and
# it is the same geometry here.
#
# IT ALSO LEAVES THE CROWN FOR THE SHARDS, which is new and worth stating: the
# broken rock and the Neon bolts standing off the top of this animal are
# GEOMETRY rather than texture, so the crown is already the busiest part of the
# silhouette. A baked fork up there would be competing with them at the one
# place they are densest.
#
# It TAPERS rather than cutting, like everything else on this width, so a fork
# running up the shoulder thins out over the spine instead of stopping in a
# line along it.
CROWN_CALM = dict(lo=0.44, hi=0.68)

# THE CEILING UNDER THE WIDTH, AND IT IS A REAL FAULT RATHER THAN A GUARD.
# `edge < w` measures distance to the nearest cell wall, so a width larger than
# a cell's own inradius is true across the WHOLE cell -- the net does not
# thicken, a plate FLOODS, and what comes back is a blue-white blob with a
# white middle. Magma hit exactly this and its header records two of them
# landing beside the coin slot. Capped rather than tuned away, because the
# width that overflows is the SUM of the base, the per-cell variation and the
# grain.
W_CEIL = 0.185

# THE THINNEST FORK THAT IS ALLOWED TO EXIST, as a fraction of nominal -- the
# tiger's `MIN_FRACTION`, and it is what turns a taper into an ENDING.
#
# Nothing in this skin fades; the BAKE would. Every mask above narrows a fork
# rather than dimming it, and once one is thinner than a delivered texel the
# 2048-to-1024 box filter averages it into the coat and half a texel of
# blue-white comes back as a grey smear. Below the floor the fork is not drawn
# at all, so it narrows to a visible point and then stops.
MIN_FRACTION = 0.40

# NOTHING ON THIS ANIMAL FADES INTO ANYTHING ELSE.
#
# The theme is CARTOON, so every texel is one of the eight colours named above
# and never a blend of two. That is enforced at the graph's output rather than
# asked of each mask: every factor reaching a colour mix goes through `hard`,
# so a soft mask anywhere upstream moves an EDGE rather than smearing one.
#
# IT IS THE RULE THAT SHAPED THIS SKIN MORE THAN ANY OTHER, because the obvious
# way to draw lightning is a glow -- a bright core bleeding out through blue
# into the coat -- and that is precisely what is forbidden. The three bands ARE
# that glow, quantised, which is what every hand-drawn cartoon bolt in the
# world does and is why this reads as a cartoon rather than as a render.
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
    """The wolf as one material. Built twice -- once for the body and once for
    the trim -- and DELIBERATELY NOT SHARED between them.

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
        excursion rather than an extreme one. Magma's helper, and the reasoning
        is its: Blender's noise Factor is bunched hard around 0.5, so the
        obvious `(fac - 0.5) * amount` needs an amount of about six before
        anything reaches the ends and by then the rare tail is enormous.

        SAMPLED AT AN OFFSET POSITION, because two noises at the same place
        with different scales are still correlated -- their large features line
        up -- so the ribbon and the patch would break in the same places and
        the whole coat would read as one repeating motif.
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

    def floor_width(w, nominal, x, y, what):
        """A width, or nothing at all -- see `MIN_FRACTION`. Multiplying by the
        comparison rather than branching keeps it one node and keeps the result
        exactly zero, which is what stops a fork being drawn at all."""
        big = math('GREATER_THAN', x, y, "%s: wide enough to draw?" % what,
                   b=nominal * MIN_FRACTION)
        link(w.outputs[0], big.inputs[0])
        out = math('MULTIPLY', x + 170, y, "%s: WIDTH OR NOTHING" % what)
        link(w.outputs[0], out.inputs[0])
        link(big.outputs[0], out.inputs[1])
        return out

    # ---- where am I on the pig ---------------------------------------
    co = node("ShaderNodeTexCoord", -3000, 0, "the pig's own frame")
    sep = node("ShaderNodeSeparateXYZ", -2800, 0, "x across / y nose-tail / z up")
    link(co.outputs['Object'], sep.inputs['Vector'])
    X, Y, Z = sep.outputs['X'], sep.outputs['Y'], sep.outputs['Z']

    # ================= THE STONE ======================================
    # THE HALF THAT HAS TO SURVIVE ANY TUNING OF THE HALF BELOW IT. The crate
    # is called Animal Kingdom, and the round before this one failed by making
    # beautiful skins that were not animals. A lightning effect on a grey pig
    # is that failure again; a creature made of stone is not.

    # ---- the mirrored point ------------------------------------------
    # BUILT HERE BECAUSE THE STORM READS IT. The fork's eye clearance measures
    # a distance from ONE eye and mirrors the position onto one side so that
    # one direction serves both -- so this node has to exist whatever the coat
    # above it is doing. It is the only thing the storm block below borrows
    # from this one, and it is the reason this section cannot simply be
    # deleted for a plain-coloured variant.
    ax = math('ABSOLUTE', -3000, 200, "mirror onto one side")
    link(X, ax.inputs[0])
    here = node("ShaderNodeCombineXYZ", -2840, 200, "this point, mirrored")
    link(ax.outputs[0], here.inputs['X'])
    link(Y, here.inputs['Y'])
    link(Z, here.inputs['Z'])

    # ---- the plate lattice -------------------------------------------
    # THE SQUASH FEEDS BOTH VORONOI NODES OFF ONE OUTPUT, which is the
    # Dragon's own warning and the reason it is worth repeating: a lattice is a
    # function of scale, randomness and the input vector, so the moment those
    # two nodes disagree about any of the three, the per-cell random stops
    # belonging to the cell it is colouring -- and what comes back is plates
    # whose tone changes halfway across them, with nothing erroring.
    squash = node("ShaderNodeVectorMath", -2600, 1500, "SQUASH: strata, not pebbles")
    squash.operation = 'MULTIPLY'
    squash.inputs[1].default_value = (1.0, 1.0 / PLATE['squash'], 1.0)
    link(co.outputs['Object'], squash.inputs[0])

    # DISTANCE_TO_EDGE rather than F2 minus F1. It answers "how far am I from
    # the nearest wall" in cell units directly, so thresholding it draws every
    # plate shrunk back inside its own boundary -- which is what a seam is.
    edge_v = node("ShaderNodeTexVoronoi", -2400, 1500, "distance to the wall")
    if hasattr(edge_v, "voronoi_dimensions"):
        edge_v.voronoi_dimensions = '3D'
    edge_v.feature = 'DISTANCE_TO_EDGE'
    edge_v.inputs['Scale'].default_value = PLATE['scale']
    edge_v.inputs['Randomness'].default_value = PLATE['randomness']
    link(squash.outputs['Vector'], edge_v.inputs['Vector'])
    edge = edge_v.outputs['Distance']

    # A SECOND VORONOI ON THE SAME LATTICE, for the per-plate random number.
    # `DISTANCE_TO_EDGE` has no `Color` output, and the per-cell seed is the
    # only source of variation here that does NOT vary smoothly across the
    # surface -- which makes it the only one that can let two plates sharing a
    # border disagree about their own colour.
    cell_v = node("ShaderNodeTexVoronoi", -2400, 1200, "which plate is this")
    if hasattr(cell_v, "voronoi_dimensions"):
        cell_v.voronoi_dimensions = '3D'
    cell_v.feature = 'F1'
    cell_v.distance = 'EUCLIDEAN'
    cell_v.inputs['Scale'].default_value = PLATE['scale']
    cell_v.inputs['Randomness'].default_value = PLATE['randomness']
    link(squash.outputs['Vector'], cell_v.inputs['Vector'])
    cellsep = node("ShaderNodeSeparateXYZ", -2200, 1200, "per-plate random")
    link(cell_v.outputs['Color'], cellsep.inputs['Vector'])
    cell = cellsep.outputs['X']

    # ---- how wide this plate's own seam is ---------------------------
    # EVERYTHING FROM HERE ADDS TO ONE NUMBER, in cell units -- Magma's
    # architecture and the Giraffe's before it. There is no second mask, so a
    # plate cannot be drawn by one rule and killed by another.
    cellg = rng(-2000, 1200, "this plate's own seam", 0.0, 1.0,
                PLATE['gap'] - PLATE['cell_vary'],
                PLATE['gap'] + PLATE['cell_vary'], interp='LINEAR')
    link(cell, cellg.inputs['Value'])

    sg_off, sg = snoise(-2600, 950, "SEAM GRAIN", PLATE['grain_scale'],
                        (3.0, 11.0, -7.0))
    link(co.outputs['Object'], sg_off.inputs[0])
    sg_amt = math('MULTIPLY', -2160, 950, "how ragged the seam is",
                  b=PLATE['grain'])
    link(sg.outputs['Result'], sg_amt.inputs[0])

    gap = math('ADD', -1860, 1080, "the seam, all of it")
    link(cellg.outputs['Result'], gap.inputs[0])
    link(sg_amt.outputs[0], gap.inputs[1])

    plate_raw = math('GREATER_THAN', -1680, 1080, "on a plate, not in a seam")
    link(edge, plate_raw.inputs[0])
    link(gap.outputs[0], plate_raw.inputs[1])
    seam_raw = math('SUBTRACT', -1500, 1080, "SEAM: between the plates", a=1.0)
    link(plate_raw.outputs[0], seam_raw.inputs[1])

    # ---- which of the four tones this plate is ------------------------
    # THREE CUTS ON THE PER-CELL RANDOM, the same number `cellg` above reads.
    # Worth knowing before either is turned: a LIT plate is systematically one
    # of the more deeply seated ones. Invisible at these amounts and would not
    # be at large ones -- the Dragon records the same coupling.
    t_mid = math('GREATER_THAN', -2000, 900, "this plate is mid",
                 b=PLATE['cut_mid'])
    link(cell, t_mid.inputs[0])
    t_lit = math('GREATER_THAN', -2000, 760, "or lit", b=PLATE['cut_lit'])
    link(cell, t_lit.inputs[0])
    t_ore = math('GREATER_THAN', -2000, 620, "or ore", b=PLATE['cut_ore'])
    link(cell, t_ore.inputs[0])

    # AND ORE IS THE ONE TONE THAT IS NOT PURELY PER-CELL. Masked to the lower
    # body as well, so the warm rock reads as something the animal has been
    # standing in. On the tilted plane every underside in this project uses.
    o_lift = math('MULTIPLY_ADD', -2000, 460, "z + tilt*y",
                  b=PLATE['ore_tilt'])
    link(Y, o_lift.inputs[0])
    link(Z, o_lift.inputs[2])
    o_low = math('LESS_THAN', -1840, 460, "below the shoulder",
                 b=PLATE['ore_line'])
    link(o_lift.outputs[0], o_low.inputs[0])
    ore_raw = math('MULTIPLY', -1680, 540, "ORE: warm plates, low down")
    link(t_ore.outputs[0], ore_raw.inputs[0])
    link(o_low.outputs[0], ore_raw.inputs[1])

    # ================= THE STORM ======================================

    # ---- the zigzag: a domain warp on the position --------------------
    # See `FORK['warp']`. This displaces the point BEFORE the lattice is
    # measured, so the walls themselves become jointed polylines.
    w_off = node("ShaderNodeVectorMath", -2900, -700, "offset")
    w_off.operation = 'ADD'
    w_off.inputs[1].default_value = (17.0, -5.0, 23.0)
    link(co.outputs['Object'], w_off.inputs[0])
    w_n = node("ShaderNodeTexNoise", -2720, -700, "WARP noise")
    w_n.noise_dimensions = '3D'
    w_n.inputs['Scale'].default_value = FORK['warp_scale']
    w_n.inputs['Detail'].default_value = 2.0
    w_n.inputs['Roughness'].default_value = 0.55
    link(w_off.outputs['Vector'], w_n.inputs['Vector'])
    # THE `Color` OUTPUT IS A THREE-CHANNEL NOISE, which is the only vector
    # noise this node offers and is exactly what a domain warp wants. `Fac`
    # would displace all three axes by the same amount, which is a slide rather
    # than a warp.
    w_c = node("ShaderNodeVectorMath", -2520, -700, "centre on zero")
    w_c.operation = 'SUBTRACT'
    w_c.inputs[1].default_value = (0.5, 0.5, 0.5)
    link(w_n.outputs['Color'], w_c.inputs[0])
    w_s = node("ShaderNodeVectorMath", -2340, -700, "how far to bend it")
    w_s.operation = 'MULTIPLY'
    w_s.inputs[1].default_value = (FORK['warp'],) * 3
    link(w_c.outputs['Vector'], w_s.inputs[0])
    w_p = node("ShaderNodeVectorMath", -2160, -560, "the bent position")
    w_p.operation = 'ADD'
    link(co.outputs['Object'], w_p.inputs[0])
    link(w_s.outputs['Vector'], w_p.inputs[1])
    warped = w_p.outputs['Vector']

    # ---- the field a fork is drawn from -------------------------------
    if FORK_MODE == "net":
        # `DISTANCE_TO_EDGE` IS THE WHOLE PATTERN AND IT IS ONE NODE. It
        # returns how far this point is from the nearest wall between two
        # cells, in cell units -- and a wall is a plane bisector, so the net it
        # draws is straight segments meeting three at a time. That branching is
        # the reason this primitive and not another.
        edge_v = node("ShaderNodeTexVoronoi", -1960, -560, "distance to a wall")
        if hasattr(edge_v, "voronoi_dimensions"):
            edge_v.voronoi_dimensions = '3D'
        edge_v.feature = 'DISTANCE_TO_EDGE'
        edge_v.inputs['Randomness'].default_value = FORK['randomness']
        edge_v.inputs['Scale'].default_value = FORK['scale']
        link(warped, edge_v.inputs['Vector'])
        edge = edge_v.outputs['Distance']

        # A SECOND VORONOI ON THE SAME LATTICE, for the per-cell random number.
        # `DISTANCE_TO_EDGE` has no `Color` output, and the per-cell seed is the
        # only source of variation here that does NOT vary smoothly across the
        # surface -- which makes it the only one that can let two runs of the
        # net disagree about their own weight. Same scale, same randomness and
        # the same WARPED vector, so it walks the same cells: the lattice is a
        # function of those three, and the moment they disagree the random
        # number stops belonging to the cell it is colouring.
        cell_v = node("ShaderNodeTexVoronoi", -1960, -900, "which cell is this")
        if hasattr(cell_v, "voronoi_dimensions"):
            cell_v.voronoi_dimensions = '3D'
        cell_v.feature = 'F1'
        cell_v.distance = 'EUCLIDEAN'
        cell_v.inputs['Randomness'].default_value = FORK['randomness']
        cell_v.inputs['Scale'].default_value = FORK['scale']
        link(warped, cell_v.inputs['Vector'])
        cellsep = node("ShaderNodeSeparateXYZ", -1760, -900, "per-cell random")
        link(cell_v.outputs['Color'], cellsep.inputs['Vector'])
        base = rng(-1560, -900, "this run's own weight", 0.0, 1.0,
                   FORK['w'] - FORK['cell_vary'],
                   FORK['w'] + FORK['cell_vary'], interp='LINEAR')
        link(cellsep.outputs['X'], base.inputs['Value'])
        base_out = base.outputs['Result']
    else:
        # THE LOSER, KEPT -- see `FORK_MODE`. The level set of the warped
        # noise: `edge` is how far this point is from where that noise crosses
        # zero, which is a smooth unbranched ribbon.
        b_off, b_n = snoise(-2200, -560, "BAND field", FORK['scale'] * 0.75,
                            (3.0, 7.0, -11.0), detail=3.0)
        link(warped, b_off.inputs[0])
        b_a = math('ABSOLUTE', -1760, -560, "distance from the centreline")
        link(b_n.outputs['Result'], b_a.inputs[0])
        edge = b_a.outputs[0]
        base = math('ADD', -1560, -900, "this run's own weight",
                    b=0.0, a=FORK['w'] * 2.4)
        base_out = base.outputs[0]

    # ---- the ragged edge ----------------------------------------------
    g_off, g_n = snoise(-2200, -1250, "RAGGED EDGE", FORK['grain_scale'],
                        (-6.0, 13.0, 5.0), detail=3.0)
    link(co.outputs['Object'], g_off.inputs[0])
    g_s = math('MULTIPLY', -1760, -1250, "grain amount", b=FORK['grain'])
    link(g_n.outputs['Result'], g_s.inputs[0])
    w_raw = math('ADD', -1380, -900, "width + grain")
    link(base_out, w_raw.inputs[0])
    link(g_s.outputs[0], w_raw.inputs[1])

    # ---- WHERE A FORK IS ALLOWED TO BE, which is the whole design -----
    # BOTH OF THESE MULTIPLY THE WIDTH AND NEITHER TOUCHES THE INK. That is
    # what makes a fork TAPER TO A POINT where it runs out rather than being
    # cut square -- see the header, and `CLAUDE.md` on the tiger's eye.
    r_off, r_n = snoise(-2600, -1600, "RIBBON field", FORK['ribbon_scale'],
                        (0.0, 0.0, 0.0), detail=2.0)
    link(co.outputs['Object'], r_off.inputs[0])
    r_a = math('ABSOLUTE', -2160, -1600, "distance from its level set")
    link(r_n.outputs['Result'], r_a.inputs[0])
    ribbon = rng(-1980, -1600, "RIBBON: a band a cell wide",
                 FORK['ribbon_cut'], FORK['ribbon_cut'] + FORK['ribbon_soft'],
                 1.0, 0.0)
    link(r_a.outputs[0], ribbon.inputs['Value'])

    p_off, p_n = snoise(-2600, -1900, "PATCH field", FORK['patch_scale'],
                        (21.0, -9.0, 4.0), detail=2.0)
    link(co.outputs['Object'], p_off.inputs[0])
    patch = rng(-2160, -1900, "PATCH: only a few stretches of it",
                FORK['patch_cut'], FORK['patch_cut'] + FORK['patch_soft'],
                0.0, 1.0)
    link(p_n.outputs['Result'], patch.inputs['Value'])

    where = math('MULTIPLY', -1780, -1750, "WHERE A FORK IS")
    link(ribbon.outputs['Result'], where.inputs[0])
    link(patch.outputs['Result'], where.inputs[1])

    # ---- and where it may not be --------------------------------------
    muz_calm = rng(-2600, -2150, "nothing across the muzzle",
                   MUZZLE_CALM['lo'], MUZZLE_CALM['hi'], 0.0, 1.0)
    link(Y, muz_calm.inputs['Value'])
    dv = node("ShaderNodeVectorMath", -2600, -2350, "offset from the eye")
    dv.operation = 'SUBTRACT'
    dv.inputs[1].default_value = (EYE_CALM['x'], EYE_CALM['y'], EYE_CALM['z'])
    link(here.outputs['Vector'], dv.inputs[0])
    dl = node("ShaderNodeVectorMath", -2420, -2350, "how far")
    dl.operation = 'LENGTH'
    link(dv.outputs['Vector'], dl.inputs[0])
    eye_calm = rng(-2240, -2350, "come to a point at the eye",
                   EYE_CALM['r0'], EYE_CALM['r1'], 0.0, 1.0)
    link(dl.outputs['Value'], eye_calm.inputs['Value'])
    crown_calm = rng(-2600, -2550, "nothing over the spine or the ears",
                     CROWN_CALM['lo'], CROWN_CALM['hi'], 1.0, 0.0)
    link(Z, crown_calm.inputs['Value'])
    calm0 = math('MULTIPLY', -2000, -2250, "clear of the face")
    link(muz_calm.outputs['Result'], calm0.inputs[0])
    link(eye_calm.outputs['Result'], calm0.inputs[1])
    calm = math('MULTIPLY', -1840, -2350, "and of the crown")
    link(calm0.outputs[0], calm.inputs[0])
    link(crown_calm.outputs['Result'], calm.inputs[1])

    # ---- one width, and everything is in it ---------------------------
    w1 = math('MULTIPLY', -1180, -1000, "narrowed to the ribbon")
    link(w_raw.outputs[0], w1.inputs[0])
    link(where.outputs[0], w1.inputs[1])
    w2 = math('MULTIPLY', -1000, -1000, "and clear of the face")
    link(w1.outputs[0], w2.inputs[0])
    link(calm.outputs[0], w2.inputs[1])
    w3 = floor_width(w2, FORK['w'], -820, -1000, "fork")
    width = math('MINIMUM', -480, -1000, "never wider than a cell",
                 b=W_CEIL)
    link(w3.outputs[0], width.inputs[0])

    # ---- the three bands ----------------------------------------------
    # THRESHOLDS AND NOT RAMPS. The bake runs at 2048 and delivers at 1024, so
    # every delivered texel is the average of four and the downscale is what
    # does the anti-aliasing -- a soft edge in the graph on top of that is
    # mush. See `WORKFLOW.md`.
    rimw = math('MULTIPLY', -300, -820, "the rim reaches this far",
                b=BANDS['rim'])
    link(width.outputs[0], rimw.inputs[0])
    corew = math('MULTIPLY', -300, -1180, "and the core this far",
                 b=BANDS['core'])
    link(width.outputs[0], corew.inputs[0])

    rim_raw = math('LESS_THAN', -120, -820, "near enough to darken?")
    link(edge, rim_raw.inputs[0])
    link(rimw.outputs[0], rim_raw.inputs[1])
    bolt_raw = math('LESS_THAN', -120, -1000, "inside the channel?")
    link(edge, bolt_raw.inputs[0])
    link(width.outputs[0], bolt_raw.inputs[1])
    core_raw = math('LESS_THAN', -120, -1180, "inside its core?")
    link(edge, core_raw.inputs[0])
    link(corew.outputs[0], core_raw.inputs[1])

    # ---- the colours --------------------------------------------------
    # ---- NOTHING FADES ------------------------------------------------
    # EVERY FACTOR THAT REACHES A COLOUR PASSES THROUGH HERE, AND THAT IS A
    # STRUCTURAL RULE RATHER THAN A TIDY-UP. A `Mix` factor of 0.4 does not
    # draw less of something -- it draws a colour that was never authored,
    # 40% of the way between two that were. On a cartoon coat that reads as an
    # airbrush. See `NO_FADING` and `WORKFLOW.md`.
    #
    # Softness on a WIDTH is the opposite and is kept everywhere it appears --
    # that is a fork tapering to a point, which is drawn in full ink the whole
    # way. A mask on the ink can only cut; a mask on the width can taper.
    def hard(sock, x, y, what):
        n = math('GREATER_THAN', x, y, "%s: one colour or the other" % what,
                 b=0.5)
        link(sock, n.inputs[0])
        return n.outputs[0]

    # LAID IN ORDER, COAT OUTWARD. Each mix's factor is a 0/1 mask, so anything
    # mixed BEFORE it shows through wherever that mask is 0 and is covered
    # wherever it is 1. The order is the one a painter would use: the ground,
    # the big markings, the face, then the storm over all of it.
    # ---- the plates, laid dark to light ------------------------------
    # THE DARKEST TONE IS THE GROUND AND THE OTHERS ARE LAID OVER IT, so a
    # plate that is none of the three special cases is simply never written to
    # -- which is what makes the order below cost nothing. Each mask is a
    # SUBSET of nothing else, so unlike Magma's nested bands these are genuine
    # alternatives and the LAST one written wins wherever two overlap. Ore is
    # last on purpose: it is the rarest and the one that should not be
    # over-painted by a lit facet sharing its cell.
    m0, f0, a0, b0, o0 = mix_rgb(nt, "dark plate -> mid plate")
    m0.location = (120, 1500)
    a0.default_value = to_linear(PLATE_DARK) + (1.0,)
    b0.default_value = to_linear(PLATE_MID) + (1.0,)
    link(hard(t_mid.outputs[0], -60, 1500, "the mid plates"), f0)

    m1, f1, a1, b1, o1 = mix_rgb(nt, "and the lit ones")
    m1.location = (300, 1300)
    b1.default_value = to_linear(PLATE_LIT) + (1.0,)
    link(o0, a1)
    link(hard(t_lit.outputs[0], 100, 1300, "the lit plates"), f1)

    m2, f2, a2, b2, o2 = mix_rgb(nt, "ore, low on the flank")
    m2.location = (500, 1300)
    b2.default_value = to_linear(PLATE_ORE) + (1.0,)
    link(o1, a2)
    link(hard(ore_raw.outputs[0], 100, 1120, "the ore"), f2)

    # THE SEAM GOES ON LAST OF THE STONE AND FIRST OF NOTHING ELSE. It is the
    # gap BETWEEN the plates, so it has to be able to cover any of the three
    # tones -- and the storm below then cuts through both the plates and the
    # seams alike, which is what makes a fork read as tearing the hide open
    # rather than as running along its joints.
    m3, f3, a3, b3, o3 = mix_rgb(nt, "the seam between them")
    m3.location = (700, 1300)
    b3.default_value = to_linear(SEAM) + (1.0,)
    link(o2, a3)
    link(hard(seam_raw.outputs[0], 100, 940, "the seams"), f3)

    # THE STORM BELOW EXPECTS `o5`, WHICH IS THE WOLF'S OWN NUMBERING AND IS
    # KEPT DELIBERATELY. That block is byte-identical to Storm Wolf's and the
    # whole value of that is being able to diff the two files and see nothing;
    # renaming the socket it reads to save two characters would spend it.
    o5 = o3

    # ---- WHICH TEXELS THE GAME GETS TO DRIVE --------------------------
    # THE CHANNEL, AND NOT THE CORE OR THE RIM. A node labelled `ALPHA_MASK`
    # is the one thing `make/bake_alpha.py` looks for: 1 where the baked
    # picture should win, 0 where the part's own `Color3` should come through
    # -- and `ClientMain`'s skin animator rewrites that colour every Heartbeat.
    #
    # **THE REGION HANDED OVER MUST ALREADY BE ONE COLOUR**, which is the rule
    # `docs/animal-crate-plan.md` records the hard way: there is one `Color`
    # property per MeshPart, so a region containing several authored colours
    # collapses into one cycling colour and the rest are simply lost. The three
    # storm bands are three colours, so only ONE of them can go.
    #
    # THE CHANNEL IS THE RIGHT ONE OF THE THREE, and the reason is what
    # `skinColourAt`'s `flicker` actually does: it lerps `palette[1]` toward
    # `palette[2]` on `t*t`, which is biased LOW -- so it sits dim most of the
    # time and spikes bright, which is lightning rather than a pulse. Hand it
    # the CORE instead and the dim end draws a dark seam down the middle of a
    # bright fork, which reads as a fault. Hand it the channel and the core
    # stays a white-hot hairline the fork can still be seen by while the body
    # of it goes dark and flares. The rim never moves, so the fork is always
    # cut into the coat rather than lying on it.
    #
    # NOTE THE TRIM PARTS GET A DIFFERENT COLOUR FROM THE BODY -- the animator
    # writes `colour:Lerp(skin.trim, 0.55)` on trim -- so a fork running off
    # the flank onto a leg flickers a little more muted there. That is a fact
    # about the engine rather than about this file, and it is worth knowing
    # before anybody reports the legs as wrong.
    #
    # IT IS BUILT UNCONDITIONALLY AND COSTS NOTHING WHEN UNUSED. The alpha pass
    # is a separate command, so the fallback -- a completely static Storm Wolf,
    # exactly as it renders in the ordinary loop -- is simply not running it,
    # and the colour sheet is byte-identical either way.
    rim_hard = hard(rim_raw.outputs[0], 60, -820, "the rim")
    bolt_hard = hard(bolt_raw.outputs[0], 60, -1000, "the channel")
    core_hard = hard(core_raw.outputs[0], 60, -1180, "the core")
    not_core = math('SUBTRACT', 240, -1360, "everything but the core", a=1.0)
    link(core_hard, not_core.inputs[1])
    body_only = math('MULTIPLY', 420, -1360, "the channel, core excluded")
    link(bolt_hard, body_only.inputs[0])
    link(not_core.outputs[0], body_only.inputs[1])
    alpha_mask = math('SUBTRACT', 600, -1360,
                      "OPAQUE EVERYWHERE BUT THE CHANNEL", a=1.0)
    alpha_mask.label = "ALPHA_MASK"
    link(body_only.outputs[0], alpha_mask.inputs[1])

    m6, f6, a6, b6, o6 = mix_rgb(nt, "the cloud darkens round it")
    m6.location = (1300, 1300)
    b6.default_value = to_linear(STORM) + (1.0,)
    link(rim_hard, f6)
    link(o5, a6)

    m7, f7, a7, b7, o7 = mix_rgb(nt, "open the channel")
    m7.location = (1500, 1300)
    b7.default_value = to_linear(BOLT) + (1.0,)
    link(bolt_hard, f7)
    link(o6, a7)

    m8, f8, a8, b8, o8 = mix_rgb(nt, "and light its core")
    m8.location = (1700, 1300)
    b8.default_value = to_linear(CORE) + (1.0,)
    link(core_hard, f8)
    link(o7, a8)

    bsdf = node("ShaderNodeBsdfPrincipled", 1920, 1000)
    bsdf.inputs['Roughness'].default_value = 0.88
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.08
    link(o8, bsdf.inputs['Base Color'])
    out = node("ShaderNodeOutputMaterial", 2240, 1000)
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

body_mat = coat("stormstone_body")
trim_mat = coat("stormstone_trim")
ear_mat = flat("stormstone_ear_inner", EAR_IN)
# THE SNOUT IS ITS OWN FLAT MATERIAL rather than a mask inside the trim
# coat -- see the header. It costs no nodes, it cannot be wandered onto
# by a fork, and it is one line to remove if the pink turns out to be
# wrong. The Snout is a mesh part with its own slot, so this is the same
# move the inner ear already makes.
snout_mat = flat("stormstone_snout", SNOUT)

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
# `materials.clear()` ALSO RESETS EVERY POLYGON'S SLOT INDEX.
assign(bpy, ASSIGN, "STORM STONE  (from %s)" % SRC)

for _n, _c in face_slots(bpy, [n for n, _ in ASSIGN]):
    if len(_c) > 1:
        print("  %-6s faces per slot %s  <- hand selection, intact"
              % (_n, _c))

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("")
print("  saved %s -- %s is untouched"
      % (os.path.relpath(OUT, D), os.path.relpath(SRC, D)))
print("  about %d plates across the body, seam %.3f of a cell wide"
      % (round(PLATE['scale'] * 2.0), PLATE['gap'] * 2.0))
print("  forks from the %s field: about %d cells across the body,"
      % (FORK_MODE, round(FORK['scale'] * 2.0)))
print("  channel %.3f studs wide, core %.3f, rim out to %.3f"
      % (FORK['w'] * 2.0 / FORK['scale'],
         FORK['w'] * 2.0 * BANDS['core'] / FORK['scale'],
         FORK['w'] * 2.0 * BANDS['rim'] / FORK['scale']))
