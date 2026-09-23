# -*- coding: utf-8 -*-
"""Build STORM WOLF as a node graph, in its own blend file.

    blender.exe --background --python assets/piggies/stormwolf/generate/make_stormwolf_blend.py

Writes `assets/piggies/stormwolf/source/stormwolf.blend`. Then the ordinary loop, plus the
alpha pass that makes it a legendary:

    blender.exe --background --python make/bake_skin.py       -- --skin stormwolf
    blender.exe --background --python make/bake_alpha.py      -- --skin stormwolf
    python make/apply_alpha.py --skin stormwolf
    blender.exe --background --python make/make_view_blend.py -- --skin stormwolf --render

THE PATTERN IS DEFINED IN 3D, NEVER IN UV SPACE -- see `WORKFLOW.md`. The
shader is evaluated at a POSITION on the surface, so Smart UV Project can
rotate every island however it likes and a fork still runs where the geometry
says it runs. The bake resolves it afterwards.

---------------------------------------------------------------------------
A CREATURE PLUS AN ELEMENT, AND THE CREATURE IS THE HALF THAT IS HARD.

`docs/animal-crate-plan.md` says a legendary in this crate has to read as a
BEAST from twelve studs, because the round before it produced beautiful skins
that were not animals. The mesh is a PIG and cannot be anything else, so the
wolf is carried entirely by the MARKINGS, and they are the layer to protect if
any number in this file moves:

    a DARK SADDLE over the crown, the neck and the spine, dropping down the
    shoulder and the haunch on a wobbly line
    PALE THROAT, BELLY AND LEGS underneath it
    a PALE MUZZLE MASK with a NEAR-BLACK NOSE on the end of it
    PALE BROW SPOTS over the eyes, which is the marking a wolf's face is
    actually recognised by
    a DARK TAIL TIP

That two-tone -- dark over, pale under, pale face mask -- is what says WOLF
rather than GREY PIG, and it matters more than the lightning does. A grey coat
with cracks in it is Magma in a different colourway; a saddle, a mask and a
brow are a canid.

THE ELEMENT IS WHAT JUSTIFIES THE REST OF THE TIER. Lightning forks across the
coat: a dark storm rim, a blue-white channel and a white-hot core, three hard
bands off one width, exactly the way Magma bands its cracks. The channel is
handed to the game's `flicker` animator through the alpha pass, so a fork
strobes while the coat holds still.

---------------------------------------------------------------------------
HOW A FORK IS DRAWN, AND WHY IT IS NOT A STRIPE.

A stripe is smooth and continuous. A fork is STRAIGHT SEGMENTS MEETING AT
SHARP ANGLES, AND IT BRANCHES -- and branching is the property that decides
the construction, because only one primitive in this toolkit produces it for
free.

A Voronoi cell wall is the perpendicular bisector of two seeds: a PLANE, so
its trace on a surface is straight-ish, and three walls meet at every cell
vertex, so the net BRANCHES at Y-junctions. That is a fork's own geometry.
`Config`'s Magma uses the same field for cracks; what separates lightning from
crazy paving is not the field, it is HOW MUCH OF IT SURVIVES.

So the whole design is the sparsener, and it is two smooth masks multiplied
into the fork's WIDTH rather than into its ink:

    RIBBON   the neighbourhood of a level set of a slow noise -- a wandering
             band a cell or so wide. Its job is to make what survives LINEAR:
             a patch of net inside a blob is crazy paving, and a patch of net
             inside a band is a chain of segments with stubs hanging off it,
             which is what a bolt looks like.
    PATCH    a second, slower noise cut hard, which breaks each band into
             three or four separate stretches so the ribbon's own closed loops
             never read as a ring round the animal.

**IT IS ON THE WIDTH AND NOT ON THE INK, WHICH IS THE TIGER'S FINDING ARRIVING
ON A THIRD PRIMITIVE.** `CLAUDE.md` records that a hard mask on the ink cuts
every stroke at one radius and draws a visible CIRCLE -- a stencil rather than
a marking -- and that moving it onto the width fixes it, because every stroke
then ends at its own width and the endpoints scatter. Here it buys something
better still: a fork that runs out of ribbon TAPERS TO A POINT, which is
exactly what the tip of a lightning bolt does. Cut on the ink instead and every
fork ends square, as though it had been trimmed.

And `MIN_FRACTION` under the width is what stops the taper becoming a smear:
below a fraction of nominal the fork is not drawn at all, so it narrows and
then STOPS at a thickness the 1024 sheet can still hold.

WHAT WAS TRIED AND LOST: `FORK_MODE = "band"`, still in this file and still
runnable -- `-- --fork-mode band`. The short version is that the level set of
a warped noise cannot branch at any width: wide it is one smooth stripe,
narrow it falls into disconnected puddles, and neither is a fork. See the
comment on `FORK_MODE` for what it actually rendered as.

---------------------------------------------------------------------------
THE COORDINATE FRAME IS THE PIG'S OWN, measured off the mesh rather than
assumed. Every part sits at identity, so object space IS world space and all
five parts share one frame -- which is what lets a fork run off the flank onto
a leg with no seam:

    x   across          body reaches +-1.000
    y   NOSE to TAIL    snout tip -1.381, body -1.080..1.052, tail tip 1.465
    z   floor to CROWN  legs -1.020, body -0.960..0.960, ear tip 1.309

So -Y is the face and +Z is up. Eyes at (+-0.318, -0.889, 0.364).
"""

# --- find the toolkit, wherever this script has been filed ------------------
# Walks up from this file until it finds the folder holding `paths.py`. Depth
# independent on purpose: a script in `make/` and a generator in `assets/piggies/stormwolf/generate/`
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
import bpy, os, sys, math   # noqa: E402

from skin_colours import to_linear   # noqa: E402
from skin_parts import assign, face_slots   # noqa: E402


argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SRC = arg("--blend", paths.PARTS)
OUT = arg("--out", paths.skin_blend("stormwolf"))

# --------------------------------------------------------------- the colours
# NOTHING HERE IS READ OUT OF `Config.luau`, for Magma's reason: there is no
# `stormwolf` row to disagree with yet. When one is written it should take COAT
# and UNDER as `body`/`trim`, and its `anim.palette` should run from a dim
# storm blue to CORE -- see the alpha section below, which is what that palette
# actually paints.
#
# A full-colour sheet invents the rest and cannot express them in Config at
# all: at `AlphaMode.Overlay` and alpha 255 the map replaces the part colour
# outright, so all eight below are a re-bake rather than a line of Luau.

# THE COAT. Stormcloud grey and COOL rather than neutral -- a wolf photographs
# blue-grey in daylight, and the preview lights this animal with a warm sun and
# a blue sky fill, so a neutral grey comes out beige on the lit side.
COAT = (30 / 255., 32 / 255., 48 / 255.)
# THE SADDLE over the crown, the neck and the spine. Dark enough to read as a
# separate marking from twelve studs and not so dark it becomes a silhouette:
# against COAT this is a difference of about 58 in every channel, which is the
# same order as the tiger's ink against its orange.
SADDLE = (15 / 255., 15 / 255., 25 / 255.)
# THE PALE UNDERSIDE -- throat, belly, legs -- AND THE MUZZLE MASK AND THE BROW
# SPOTS, all one colour on purpose. On a real wolf they ARE one colour, it is
# one fewer thing in the palette, and `look/check_fade.py` derives its palette
# from area, so a colour that appears in four places is comfortably above the
# floor wherever it lands.
# AND IT HAD TO COME BACK UP AFTER THE COAT WENT DARK, which is the whole
# reason this is not simply "everything got darker".
#
# The muzzle mask, the brow spots and the throat are what make a PIG read as a
# WOLF -- the agent that built this said so, and the 175px strip agreed: the
# saddle does not survive the downscale and the face does. Taken to (56,60,82)
# with the coat they stopped contrasting with it at all and the animal was one
# black lump with a bolt on it. This sits far enough above the coat's
# (30,32,48) to read as a marking and far enough below the old (180,188,201)
# to still belong on a storm-forged animal.
UNDER = (104 / 255., 112 / 255., 140 / 255.)
# THE NOSE. Near-black, and the single strongest canid signal on the whole
# animal: a pale muzzle with a dark button on the end of it is a dog's face
# before anything else about the coat is read. Deliberately NOT the pink pad
# every other skin in this catalogue paints -- Magma's third build settles that
# argument, and this animal is a wolf rather than a pig wearing a wolf.
NOSE = (28 / 255., 28 / 255., 34 / 255.)

# ---- the storm -----------------------------------------------------------
# THE RIM either side of a fork. A deep thundercloud indigo, and it is doing
# Magma's char job: without it the blue-white sits ON the coat like paint, and
# with it the fork reads as something the coat is torn open by. It is the
# moat's kerb trick from `CLAUDE.md` again -- the eye takes the darkest line
# beside a bright one as depth.
#
# It is not "char" and is not called that: nothing here is burnt. It is the
# cloud darkening round a strike, which is what a storm actually does.
STORM = (8 / 255., 8 / 255., 16 / 255.)

# THE MARBLE, AND IT IS WHY THE DARK IS NOT FLAT. A near-black animal painted in
# one near-black is a silhouette with nothing in it -- the reference this was
# re-cut against is swirled blue-violet THROUGH the black, which is what makes
# it read as storm-forged stone rather than as a grey pig turned down.
#
# In flat regions rather than a gradient, because `WORKFLOW.md` forbids the
# gradient and because a hard-edged swirl is what a cartoon does anyway.
MARBLE = (48 / 255., 40 / 255., 74 / 255.)
# THE CHANNEL. Blue-white, and this is the band handed to the animator -- so
# what is baked here is the RESTING value the preview shows and the value a
# static fallback ships. See the alpha section.
BOLT = (140 / 255., 198 / 255., 255 / 255.)
# THE CORE. Near-white with a blue left in it. Magma's own note warns that a
# white core blows out against black and takes the orange with it; that is a
# fact about a near-black coat, and this one is a mid grey, so the core can be
# the colour lightning actually is. It is a hairline, which is the other half
# of why it is safe.
CORE = (240 / 255., 249 / 255., 255 / 255.)
# THE INNER EAR. Not skin-pink and not wolf-tan: a lit storm blue, because this
# is the one place a second material is honest -- a glimpse INTO the animal,
# which is the argument Magma's ember ear already makes.
EAR_IN = (44 / 255., 58 / 255., 112 / 255.)

# --------------------------------------------------------------- the tunables
# EVERY NUMBER THAT DECIDES WHAT THE COAT LOOKS LIKE IS IN THESE DICTS, so a
# note like "the saddle comes too far down" is a one-line edit and a two-second
# re-run.

# THE SADDLE. Measured on `z + tilt*y - curve*(y - y0)^2`, and the first two
# terms are the tiger's belly trick used the other way up: the tilt is what
# stops the boundary being a bathtub ring round the widest part of a sphere.
#
# **AND A LINEAR TILT CANNOT DRAW A SADDLE, WHICH TOOK TWO BUILDS TO SEE.** A
# wolf's cape is WIDE ACROSS THE SHOULDERS and narrows in BOTH directions --
# up the neck and back over the rump. A tilt is monotonic in `y`, so it can
# only trade one end for the other: at -0.20 the whole head went black, and at
# +0.16 the head came right and the entire rump went dark instead, which from
# behind is a black lump with no rock in it. Both builds are in the record
# because the second one looked like a fix.
#
# `curve` is the term that can do it: a parabola in `y` subtracted from the
# field, so the boundary sits LOWEST at `y0` and lifts away from it either
# way. One node pair, and it is the difference between a cape and a dip-dye.
SADDLE_M = dict(line=0.34, tilt=0.06, curve=0.22, y0=-0.05,
                # THE WOBBLE. A slow noise on the boundary, so the edge of the
                # cape is a torn line rather than a contour. It is on the
                # FIELD rather than on the colour, so the edge stays hard --
                # which is what `WORKFLOW.md` means by a soft mask moving an
                # EDGE rather than smearing one.
                #
                # SLOWER AND SHALLOWER THAN THE FIRST BUILD'S 0.16 AT 1.9. At
                # that amplitude and that scale the wobble is the same size as
                # the saddle it is edging, so it stopped being a torn line and
                # became BLOTCHES -- a cow's markings rather than a wolf's
                # cape, which is exactly what the crown view showed.
                wobble=0.095, wobble_scale=1.65)

# THE PALE UNDERSIDE. Same field, other end, and the tilt is the tiger's sign:
# positive lifts the boundary at the NOSE, so the pale runs up the jaw and the
# throat and sits lower at the haunch. That is the shape a canid's underside
# has, and it is also what puts pale where a viewer standing on a pavement
# looking slightly down will not see much of it -- which is why the muzzle mask
# below is doing most of the work of saying "wolf".
#
# THE LEGS ARE DELIBERATELY NOT TAKEN BACK OUT OF IT. The tiger does that,
# because four cream posts under an orange animal are wrong; a wolf's legs
# genuinely are paler than its back, so the second half of that mask is simply
# absent here.
UNDER_M = dict(line=-0.34, tilt=0.32, wobble=0.13, wobble_scale=2.3)

# THE MUZZLE MASK. Pale over the front and the sides of the snout, cut off
# below a line in `z` so the BRIDGE of the muzzle stays coat grey -- a pale
# snout with a grey stripe down the top of it, which is the marking that turns
# a snout into a canid muzzle.
#
# `hi` is where the mask has faded out entirely, well forward of the eyes at
# y -0.889, for the reason the tiger's `FACE` block gives: a marking that runs
# up to an eye rim reads as a smear.
MUZZLE = dict(lo=-1.34, hi=-1.00, top=0.16, top_tilt=0.34)

# THE NOSE PAD on the end of it.
NOSE_M = dict(lo=-1.31, hi=-1.20)

# THE BROW SPOTS, AS A DIRECTION RATHER THAN AS A POINT, and that is the whole
# reason they land on the animal at all.
#
# A ball centred on a coordinate near a curved surface is a coin toss: the pig
# is an ellipsoid about 1.0 x 1.08 x 0.96, so at y -0.85 the surface is only
# about 0.57 studs off the axis and a spot placed by eye at z 0.62 is OUTSIDE
# it. Measured against `dot(normalize(P), dir)` instead, a spot is an angular
# cap and cannot miss the surface however the body is shaped.
#
# THE HALF-ANGLE IS SET BY THE EYE, AND IT IS THE TIGHTEST CLEARANCE ON THE
# ANIMAL. The eyeball is 0.105 in radius at about 1.01 from the origin, so it
# subtends 6.0 degrees; this direction sits 13.7 degrees off the eye's, so the
# spot plus its soft edge (4.6 + 1.1) clears the rim by 2.0 degrees. Anything
# bigger touches an eye, which `WORKFLOW.md` rule 6 forbids -- and there is no
# room to move the spot CLOSER either, which is the trade: a brow spot right
# above the eye the way a real wolf wears it cannot fit beside a ball that is
# already six degrees across.
#
# IT WAS 7.0 FOR ONE BUILD AND READ AS A SECOND PAIR OF EYES. At that size two
# pale discs on a dark cap are the biggest features on the face, and the actual
# eyes -- small dark beads low on the snout -- lost the competition. Small is
# what makes them read as markings rather than as anatomy.
BROW = dict(dir=(0.31, -0.81, 0.60), half=4.6, soft=1.1)

# DERIVED HERE AND NOT INSIDE `coat`, because `coat` defines a LOCAL called
# `math` -- the node helper -- which shadows the module of the same name for
# the whole of its body. The tiger's `HEAD_COS_*` sit up here for exactly this
# reason. Compared as COSINES so the graph needs no arc-cosine: NEARER the
# brow is a BIGGER cosine, which is why these two read back to front.
_bl = sum(v * v for v in BROW['dir']) ** 0.5
BROW_DIR = tuple(v / _bl for v in BROW['dir'])
BROW_COS_LO = math.cos(math.radians(BROW['half'] + BROW['soft']))
BROW_COS_HI = math.cos(math.radians(BROW['half']))

# THE DARK TAIL TIP. Cheap, and a wolf's tail is the one part of it a child
# will draw. `lo` is past the body's own 1.052, so this only ever paints tail.
TAIL_M = dict(lo=1.02, hi=1.10)

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
    scale=2.6,
    # HOW IRREGULAR THE SEEDS ARE. High, because an even lattice gives walls of
    # near-equal length meeting at near-equal angles, which reads as a honeycomb
    # -- and a bolt's angles are the thing that makes it look violent.
    randomness=0.88,
    # HALF THE FORK WIDTH, in cell units. A fork is `2 * w` across, which at
    # this scale is 0.093 studs -- nearly twice a Magma crack, because there
    # are a tenth as many of them and each one has to carry three bands and
    # still be readable at the 175 pixels twelve studs gives it.
    w=0.088,
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
# net from above; here the SADDLE is the silhouette, and a bolt torn across
# the top of it breaks the one marking carrying the wolf. Measured on a build
# without it: forks on both ear backs read as scribble rather than as
# lightning, because an ear is a narrow tapering shape and a fork on it has no
# room to be a fork.
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

    # ================= THE WOLF =======================================
    # THE HALF THAT HAS TO SURVIVE ANY TUNING OF THE HALF BELOW IT. The crate
    # is called Animal Kingdom and the round before this one failed by making
    # beautiful skins that were not animals.

    # ---- the dark saddle ---------------------------------------------
    s_off, s_wob = snoise(-2600, 1500, "SADDLE EDGE", SADDLE_M['wobble_scale'],
                          (5.0, -3.0, 9.0))
    link(co.outputs['Object'], s_off.inputs[0])
    s_amt = math('MULTIPLY', -2160, 1500, "how torn the edge is",
                 b=SADDLE_M['wobble'])
    link(s_wob.outputs['Result'], s_amt.inputs[0])
    s_lift = math('MULTIPLY_ADD', -2600, 1300, "z + tilt*y",
                  b=SADDLE_M['tilt'])
    link(Y, s_lift.inputs[0])
    link(Z, s_lift.inputs[2])
    # THE PARABOLA THAT MAKES IT A CAPE -- see `SADDLE_M['curve']`. Lowest at
    # `y0`, so the dark comes furthest down over the shoulders and lifts away
    # toward both the crown and the tail.
    s_d = math('SUBTRACT', -2600, 1130, "how far from the shoulder",
               b=SADDLE_M['y0'])
    link(Y, s_d.inputs[0])
    s_sq = math('MULTIPLY', -2440, 1130, "squared")
    link(s_d.outputs[0], s_sq.inputs[0])
    link(s_d.outputs[0], s_sq.inputs[1])
    s_cu = math('MULTIPLY', -2290, 1130, "the cape's own curve",
                b=SADDLE_M['curve'])
    link(s_sq.outputs[0], s_cu.inputs[0])
    s_c = math('SUBTRACT', -2400, 1300, "narrower away from the shoulder")
    link(s_lift.outputs[0], s_c.inputs[0])
    link(s_cu.outputs[0], s_c.inputs[1])
    s_f = math('ADD', -2260, 1300, "+ the torn edge")
    link(s_c.outputs[0], s_f.inputs[0])
    link(s_amt.outputs[0], s_f.inputs[1])
    saddle = math('GREATER_THAN', -2080, 1300, "SADDLE: dark over the back",
                  b=SADDLE_M['line'])
    link(s_f.outputs[0], saddle.inputs[0])

    # ---- the pale underside ------------------------------------------
    u_off, u_wob = snoise(-2600, 1050, "UNDERSIDE EDGE",
                          UNDER_M['wobble_scale'], (-8.0, 12.0, 3.0))
    link(co.outputs['Object'], u_off.inputs[0])
    u_amt = math('MULTIPLY', -2160, 1050, "how torn the edge is",
                 b=UNDER_M['wobble'])
    link(u_wob.outputs['Result'], u_amt.inputs[0])
    u_lift = math('MULTIPLY_ADD', -2600, 860, "z + tilt*y", b=UNDER_M['tilt'])
    link(Y, u_lift.inputs[0])
    link(Z, u_lift.inputs[2])
    u_f = math('ADD', -2400, 860, "+ the torn edge")
    link(u_lift.outputs[0], u_f.inputs[0])
    link(u_amt.outputs[0], u_f.inputs[1])
    under = math('LESS_THAN', -2200, 860, "UNDER: pale throat, belly, legs",
                 b=UNDER_M['line'])
    link(u_f.outputs[0], under.inputs[0])

    # ---- the muzzle mask ---------------------------------------------
    # TWO CONDITIONS AND NOT ONE: forward of a line in `y`, AND below a line in
    # `z`. The second is what leaves the bridge of the muzzle in coat grey,
    # which is the difference between a pale snout and a canid muzzle.
    m_fwd = rng(-2600, 640, "forward of the cheek",
                MUZZLE['lo'], MUZZLE['hi'], 1.0, 0.0)
    link(Y, m_fwd.inputs['Value'])
    m_lift = math('MULTIPLY_ADD', -2600, 440, "z + tilt*y",
                  b=MUZZLE['top_tilt'])
    link(Y, m_lift.inputs[0])
    link(Z, m_lift.inputs[2])
    m_low = math('LESS_THAN', -2400, 440, "below the bridge",
                 b=MUZZLE['top'])
    link(m_lift.outputs[0], m_low.inputs[0])
    muzzle = math('MULTIPLY', -2200, 540, "MUZZLE MASK")
    link(m_fwd.outputs['Result'], muzzle.inputs[0])
    link(m_low.outputs[0], muzzle.inputs[1])

    # ---- the brow spots ----------------------------------------------
    # AN ANGULAR CAP, NOT A BALL -- see `BROW`. Mirrored on |x| so one
    # direction serves both eyes.
    ax = math('ABSOLUTE', -3000, 200, "mirror onto one side")
    link(X, ax.inputs[0])
    here = node("ShaderNodeCombineXYZ", -2840, 200, "this point, mirrored")
    link(ax.outputs[0], here.inputs['X'])
    link(Y, here.inputs['Y'])
    link(Z, here.inputs['Z'])
    hdir = node("ShaderNodeVectorMath", -2680, 200, "direction from centre")
    hdir.operation = 'NORMALIZE'
    link(here.outputs['Vector'], hdir.inputs[0])
    bdot = node("ShaderNodeVectorMath", -2500, 200, "cos to the brow")
    bdot.operation = 'DOT_PRODUCT'
    bdot.inputs[1].default_value = BROW_DIR
    link(hdir.outputs['Vector'], bdot.inputs[0])
    brow = rng(-2300, 200, "BROW SPOT", BROW_COS_LO, BROW_COS_HI, 0.0, 1.0)
    link(bdot.outputs['Value'], brow.inputs['Value'])

    # ---- the nose pad and the tail tip --------------------------------
    nose = rng(-2600, 20, "the nose", NOSE_M['lo'], NOSE_M['hi'], 1.0, 0.0)
    link(Y, nose.inputs['Value'])
    tail = rng(-2600, -140, "the tail tip",
               TAIL_M['lo'], TAIL_M['hi'], 0.0, 1.0)
    link(Y, tail.inputs['Value'])

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
    # ---- the marble, UNDER everything --------------------------------
    # A SLOW NOISE, HARD-THRESHOLDED, and it goes first because it is the
    # GROUND rather than a marking: the saddle, the muzzle mask and every fork
    # are laid over whichever of the two tones happens to be underneath, so the
    # swirl shows through the coat without any of them having to know about it.
    #
    # SLOW ON PURPOSE. At `scale` above about 3 it stops being marble and
    # becomes camouflage -- the features have to be a good fraction of the
    # animal or the eye reads them as a pattern rather than as the material
    # the animal is made of.
    mb_off, mb = snoise(-2600, 1600, "MARBLE", 1.45, (17.0, -5.0, 9.0),
                        detail=2.5)
    link(co.outputs['Object'], mb_off.inputs[0])

    m0, f0, a0, b0, o0 = mix_rgb(nt, "black -> violet marble")
    m0.location = (120, 1500)
    a0.default_value = to_linear(COAT) + (1.0,)
    b0.default_value = to_linear(MARBLE) + (1.0,)
    link(hard(mb.outputs['Result'], -60, 1500, "the marble"), f0)

    m1, f1, a1, b1, o1 = mix_rgb(nt, "coat -> saddle")
    m1.location = (300, 1300)
    b1.default_value = to_linear(SADDLE) + (1.0,)
    link(o0, a1)
    link(hard(saddle.outputs[0], 100, 1300, "the saddle"), f1)

    m2, f2, a2, b2, o2 = mix_rgb(nt, "pale underside")
    m2.location = (500, 1300)
    b2.default_value = to_linear(UNDER) + (1.0,)
    link(hard(under.outputs[0], 100, 1120, "the underside"), f2)
    link(o1, a2)

    m3, f3, a3, b3, o3 = mix_rgb(nt, "dark tail tip")
    m3.location = (700, 1300)
    b3.default_value = to_linear(SADDLE) + (1.0,)
    link(hard(tail.outputs['Result'], 100, 940, "the tail tip"), f3)
    link(o2, a3)

    # THE MUZZLE AND THE BROW ARE ONE MIX, because they are one colour. Two
    # mixes would be two chances for the order to matter and no picture would
    # differ.
    pale = math('MAXIMUM', 100, 760, "muzzle or brow")
    link(muzzle.outputs[0], pale.inputs[0])
    link(brow.outputs['Result'], pale.inputs[1])
    m4, f4, a4, b4, o4 = mix_rgb(nt, "muzzle mask and brow spots")
    m4.location = (900, 1300)
    b4.default_value = to_linear(UNDER) + (1.0,)
    link(hard(pale.outputs[0], 300, 760, "the muzzle and the brow"), f4)
    link(o3, a4)

    m5, f5, a5, b5, o5 = mix_rgb(nt, "the nose")
    m5.location = (1100, 1300)
    b5.default_value = to_linear(NOSE) + (1.0,)
    link(hard(nose.outputs['Result'], 300, 560, "the nose"), f5)
    link(o4, a5)

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

body_mat = coat("stormwolf_body")
trim_mat = coat("stormwolf_trim")
ear_mat = flat("stormwolf_ear_inner", EAR_IN)

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
assign(bpy, ASSIGN, "STORM WOLF  (from %s)" % SRC)

for _n, _c in face_slots(bpy, [n for n, _ in ASSIGN]):
    if len(_c) > 1:
        print("  %-6s faces per slot %s  <- hand selection, intact"
              % (_n, _c))

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("")
print("  saved %s -- %s is untouched"
      % (os.path.relpath(OUT, D), os.path.relpath(SRC, D)))
print("  forks from the %s field: about %d cells across the body,"
      % (FORK_MODE, round(FORK['scale'] * 2.0)))
print("  channel %.3f studs wide, core %.3f, rim out to %.3f"
      % (FORK['w'] * 2.0 / FORK['scale'],
         FORK['w'] * 2.0 * BANDS['core'] / FORK['scale'],
         FORK['w'] * 2.0 * BANDS['rim'] / FORK['scale']))
