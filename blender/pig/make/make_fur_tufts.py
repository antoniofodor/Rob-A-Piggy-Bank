# -*- coding: utf-8 -*-
"""Build the FUR TUFT mesh -- raised fur, as a separate part.

    "/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" \
        --background --python make_fur_tufts.py

WHY THIS IS ITS OWN MESH AND NOT SCULPTED INTO THE PIG. The body is ONE asset
worn by all 46 skins, so fur cut into it would grow on the Solid Gold pig and
on all 22 neon ones. Roblox has no fur shader, no shell rendering and no
tessellation, so the only route to fur that stands off the surface is geometry
-- and the only route to geometry that belongs to SOME skins is a separate
part, attached the way an accessory already is.

WHY LOBES RATHER THAN ALL-OVER PILE. Uniform fuzz over a twelve-stud animal
needs thousands of strands to read as anything but noise, and at that density
it is a tri budget and a shading mess. A cartoon animal is recognised by a
CREST and a RUFF -- the fur you would draw if you had three strokes -- so the
fur goes where a silhouette is read and nowhere else.

EVERY LOBE IS SEATED BY RAYCAST, NEVER BY ARITHMETIC ON A SPHERE. The body is
a generated mesh with a snout socket, a vault hatch and a coin slot in it, and
this file already records at length what happens when something is placed
against an ELLIPSOID FITTED TO THE BOUNDING BOX rather than against the real
surface: the rump stands 0.55 studs outside that fit, and a cap seated on it
sat half a stud down a shaft. So each lobe casts a ray at the actual mesh and
sits where it hits.

--------------------------------------------------------------------------
THREE SHAPES WERE BUILT AND THE FIRST TWO ARE THE USEFUL PART.

ONE: A TEN-TO-ONE CONE, which is a QUILL. Strands 0.15..0.32 long on a
0.015..0.027 base, standing 1.5 studs off a twelve-stud animal. Reported,
exactly: "this fur is too long, these are big spikes."

TWO: A SHORT BLUNT FRUSTUM, which is a CRUMB. The diagnosis of one was right
-- a cone ends in an apex and an apex reads as a spike at every scale, so no
length fixes it -- and the replacement was a nub about half a stud across,
blunt-topped, dense. Rendered, 724 of them read as breakfast cereal stuck to
the pig: individually visible, individually box-shaped, never a mass.

THE THING BOTH GOT WRONG IS SCALE, AND IT IS THE OPPOSITE OF THE INSTINCT.
Real fur is many small strands, so "short fur" reads as "smaller pieces, more
of them" -- and at a half-stud a piece is far too big to disappear into a
texture and far too small to be a shape. It lands in the valley between the
two, where every piece is a separate object the eye can count. THERE IS A
FLOOR ON A PIECE OF GEOMETRY: it has to be big enough to be a SHAPE.

SO THREE IS WOOL. About 150 squashed domes, 1.2 to 1.9 studs across, packed
close enough to OVERLAP INTO ONE MASS -- the way a sheep, a poodle or every
plush toy ever made is drawn. What carries "fluffy" is the SCALLOPED OUTLINE
the overlap makes, which is a property of the mass rather than of any lobe,
and it is exactly what a field of separate crumbs cannot produce.

IT IS ALSO CHEAPER, WHICH IS NOT A COINCIDENCE. 150 lobes at 40 tris beats
724 nubs at 10: the same tri budget buys shapes that read or pieces that do
not, and the count that reads is the smaller one.

SHADED FULLY SMOOTH, WITH NO ANGLE SPLIT. `shade_smooth_by_angle` leaves a
low-poly lobe's own sides flat -- adjacent faces are 45 degrees apart, which
no honest threshold smooths -- so the wool would read as a heap of gems. Fully
smooth, a forty-triangle lobe reads as a soft ball, which is the whole job.
"""

# --- find the toolkit, wherever this script has been filed ------------------
# Walks up from this file until it finds the folder holding `paths.py`. Depth
# independent on purpose: a script in `make/` and a script in `skins/tiger/`
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

import bpy, bmesh, math, os, random, sys
from mathutils import Vector, Matrix

D = os.path.dirname(os.path.abspath(__file__))
# Blender does not put the script's own directory on the path under --python.
if D not in sys.path:
    sys.path.insert(0, D)
import pig_uv

bpy.ops.wm.open_mainfile(filepath=paths.RAW)

body = bpy.data.objects["Body"]
trim = bpy.data.objects["Trim"]

# STUDS PER BODY UNIT, DERIVED FROM THE BODY RATHER THAN PINNED. `build_pig.py`
# computes its own `SCALE` as the game radius over the modelled radius, so a
# literal 6.0 here would be a second copy of a number that file already owns
# and would go stale the day the pig is resized. `Config.PIGGY_MESH` records
# the body as 12.0000 studs across, so the body's own X extent is the divisor.
GAME_BODY_X = 12.0
_bx = [v.co.x for v in body.data.vertices]
SCALE = GAME_BODY_X / (max(_bx) - min(_bx))
print("export scale: %.5f studs per unit" % SCALE)

SIDES = 5           # FIVE, AND THE FACETS ARE THE POINT NOW. Eight was chosen
                    # to hide that a lobe is a polygon; this pass wants it
                    # seen. Five reads as a deliberate cut shape rather than
                    # as a failed circle, and it is half the triangles.
SEED = 20260908

# THE LOBE'S PROFILE, as (height up the lobe, radius as a share of width).
# The widest ring is deliberately NOT the bottom one: a lobe that is widest at
# its base is a mound growing out of the pig, and one that is widest halfway
# up is a BALL resting in it, which is what wool looks like. The base ring is
# then buried by SINK so no rim ever shows.
# A PETAL, NOT A BALL. The wool profile bulged at 45% and closed at 82%,
# which is a sphere half-sunk in the pig -- right for a mass of overlapping
# wool and wrong for a tuft that is meant to be ONE readable shape. This
# widens fast, holds, then draws to a soft point: a flame, which is what a
# stylised animal's mane is drawn as.
PROFILE = [(0.00, 0.80), (0.30, 1.00), (0.72, 0.52)]

# A SHARD'S PROFILE, AND IT IS THE PETAL'S ARGUMENT RUN BACKWARDS. The lobe
# above is widest a third of the way up because that is what a soft mass
# resting in the pig looks like; broken rock is widest where it LEAVES the
# animal and narrows all the way to a point, because it is a piece that split
# off rather than a thing that grew.
#
# **ONE RING, AND THE SHOULDER IS GONE.** It ran base 1.00 -> shoulder 0.78 at
# a third of the height, which puts a horizontal CREASE across every face --
# and a crease is a silhouette break that reads as a dent. The reference's
# pieces are flat plates with straight edges from base to tip: one unbroken
# run, no waist, nothing for the eye to catch on. Reported as the vertices
# being too dramatic, and this is most of what that was.
#
# It also halves the shard again -- four verts and a ridge is SIX triangles
# against the lobe's twenty-five, and the whole set drops under 500.
# **A FACETED GEM, WHICH IS WHAT THE BUILD GUIDE ACTUALLY DRAWS.** Three
# shapes have been tried here and the first two were both wrong in the same
# direction. A wedge widest at its BASE is a spike; one ring straight to a tip
# is a blade. The reference's crystal is neither: it is widest about a third
# of the way UP and closes to a point at both ends, which is a cut stone
# rather than a splinter -- and it is the same profile the wool lobe uses, for
# the opposite reason. A lobe is round because it is soft. This is round in
# plan and FACETED in elevation, and four sides is what makes those two facts
# compatible.
#
# THE MIDDLE RING EARNS ITS KEEP TWICE. It is what lets the silhouette bulge,
# and it is the only thing a `bend` has to bend AT -- a two-point blade is
# straight by construction whatever displacement is applied to it.
#
# Twenty-two triangles a crystal against the blade's fourteen, and the whole
# crest still lands around four hundred.
SHARD_PROFILE = [(0.00, 0.76), (0.38, 1.00), (0.74, 0.60)]
SHARD_SIDES = 4     # FOUR, NOT FIVE. The lobe took five so a tuft would read
                    # as a deliberate cut shape rather than a failed circle.
                    # A shard wants the opposite reading again: four wide
                    # facets are a fractured crystal, and at five it starts
                    # looking turned on a lathe.
SINK = 0.22         # how far the base ring is pushed under the skin, as a
                    # share of the tuft's height

# ---------------------------------------------------------------- the bands
# A band is a PATH over the body plus how wide and how big the wool on it is.
# Sizes are in body units, where the pig is about 1.0 in radius and 12 studs
# across, so 0.12 is roughly three quarters of a stud.
#
# A PATH, NOT A RECTANGLE, AND THAT IS THE THIRD THING THIS FILE GOT WRONG.
# Lobes scattered uniformly through a lon/lat region came out as ROUND PATCHES
# in the middle of the flank -- a blob stuck on the side of the animal, with
# stray singles around it, because a rectangle filled at random has no line in
# it and its edge is ragged. Fur is drawn as STROKES: a ridge along the spine,
# an arc down the cheek. So each band walks a path and jitters sideways off it
# by a fixed arc, which makes a ridge that is continuous, has two clean edges
# and breaks the outline -- and cannot produce a straggler, because there is
# nowhere off the path for one to land.
#
# THE LATITUDE GOES PAST 90 ON PURPOSE. A spine crest runs from the forehead
# OVER the crown to the rump, and stopping it at the pole would need two bands
# meeting at the one point where longitude means nothing. `direction` folds
# anything above 90 back down the far side, so the crest is one straight line
# from 44 to 136 and the seam does not exist.
# FEWER AND FAR BIGGER, WHICH IS THE WHOLE OF THIS PASS. 152 overlapping wool
# lobes were a coat -- an attempt at real fur, which is a losing race in an
# engine with no fur shader. These are about forty TUFTS: individually
# readable shapes, each one something a person would have drawn on purpose,
# which is how a stylised animal's fur is done and how the rest of this world
# is already built.
#
# THEY ALSO COST A SEVENTH OF THE TRIANGLES. Bigger shapes need fewer of them
# and each is cheaper at five sides, so the mesh drops from 6,080 to under a
# thousand. That is the usual direction here: the version that reads is the
# smaller one.
# ---------------------------------------------------------------- the sets
# ONE FILE, SEVERAL MANES, AND THAT IS THE FUR MESH BECOMING MODULAR.
#
# A mane used to be one mesh every furred skin wore, which is why the tiger
# and the leopard look like the same animal in different paint. The reference
# plush zebra has no ruff and no brisket at all -- it carries a short upright
# BRUSH on the crown and nothing else -- and there is no parameter on a single
# mesh that can express that.
#
# It costs one upload per set and nothing else. A skin already names its fur
# mesh through `Config.FUR_MESH`, so a per-animal mane is an id in a table
# rather than a branch in `PiggyBank` -- the same trade the body's own
# Body/Trim split already makes.
#
# Pick with the FUR_SET environment variable; "mane" is the default and still
# writes `pig_fur_tufts.obj`, so nothing that already points at that file
# moves.
MANE = [
    # the crest from the forehead over the crown to the rump -- the one line a
    # cartoon animal is recognised by, and the only fur that breaks the top
    # outline from every angle
    # THE MANE PARTS AROUND THE CROWN, AND THAT IS AN ACCESSORY RULE RATHER
    # THAN A STYLING ONE. It ran unbroken from lat 46 to 134 and came within
    # 0.54 studs of the HAT anchor at (0, 14.15, 0), reaching y 14.16 -- which
    # is the anchor. That is the Vault Lock's padlock all over again: it was
    # built at (0, 15.2, 0), every hat in the game spawned inside it, and
    # neither could be seen. Nothing this game owns may stand in an anchor a
    # player has rolled for.
    #
    # The rear end was 0.82 studs off the BACK anchor at (0, 11.0, -5.6) for
    # the same reason, which is where a Hero Cape and the Jetpack hang.
    #
    # So the crest is two runs with the crown left bare, and it stops short of
    # the rump. A parted mane is what a stylised animal has anyway -- and the
    # gap is where the hat goes.
    dict(name="crest-fore", count=8, path=[(0, 54), (0, 74)], halfwidth=0.075,
         width=(0.165, 0.225), height=(0.330, 0.470), lean=-0.14),
    # AND THE REAR END WAS STILL 1.39 STUDS OFF THE BACK ANCHOR, WHICH THE
    # SWEEP AT THE BOTTOM OF THIS FILE FOUND AND NOTHING ELSE HAD.
    #
    # The parting above was measured against the HAT and the run was shortened
    # at the same time, on the reasoning that stopping short of the rump dealt
    # with the cape too. It nearly did: 0.82 studs became 1.39, which is better
    # and is still inside a cape's own thickness. A Hero Cape hangs from
    # (0, 11.0, -5.6) and reaches local y -1.77, so a tuft that close is inside
    # the cloth rather than under it.
    #
    # 126 -> 119 costs the crest about two thirds of a stud of length at the
    # back -- invisible next to eight tufts -- and buys the clearance the hat
    # end already has. THE LESSON IS THAT ONE MEASUREMENT DOES NOT COVER THREE
    # ANCHORS: this run was checked against the hat and passed, and nobody
    # asked the other two until the check was written down.
    dict(name="crest-aft", count=8, path=[(0, 108), (0, 119)], halfwidth=0.075,
         width=(0.165, 0.225), height=(0.330, 0.470), lean=-0.14),
    # cheek ruffs, one per side, sweeping back off the jaw
    dict(name="ruff-L", count=7, path=[(-58, 44), (-64, 6), (-54, -20)],
         halfwidth=0.070,
         width=(0.155, 0.210), height=(0.300, 0.420), lean=-0.26),
    dict(name="ruff-R", count=7, path=[(58, 44), (64, 6), (54, -20)],
         halfwidth=0.070,
         width=(0.155, 0.210), height=(0.300, 0.420), lean=-0.26),
    # a brisket tuft across the chest, which reads from the side
    dict(name="chest", count=6, path=[(-28, -32), (28, -32)], halfwidth=0.065,
         width=(0.155, 0.210), height=(0.280, 0.390), lean=-0.40),
]

# A ZEBRA'S TUFT: ONE SHORT BRUSH ON THE FOREHEAD, AND NOTHING ELSE.
#
# What the reference actually shows is a small upright clump between the ears,
# about as tall as an ear and half as wide as the mane's crest. Three things
# make it read as a tuft rather than as a short mane, and all three are the
# opposite of what the full mane wants:
#
#   NARROWER, NOT SHORTER. `halfwidth` 0.048 against 0.075 is what turns a
#   ridge into a clump -- the strands sit close enough to read as one object.
#   Shortening a wide band just gives a stubbly ridge.
#
#   UPRIGHT. The mane leans back at -0.14 because a ridge running the length
#   of an animal is drawn swept. A forelock stands up; at any real lean it
#   lies down on the forehead and reads as a fringe.
#
#   SHORT ENOUGH TO STAY OUT OF THE HAT. The crown at lat 90 is directly under
#   the hat anchor, so the run stops at 76 and stands forward of it. The
#   anchor sweep at the bottom of this file is what checks that rather than
#   the comment -- the full mane had to be PARTED for exactly this reason and
#   a single short band is easier to get wrong, not harder.
CREST = [
    dict(name="forelock", count=7, path=[(0, 58), (0, 76)], halfwidth=0.048,
         width=(0.135, 0.180), height=(0.260, 0.355), lean=-0.05),
]

# STORM STONE: BROKEN ROCK RATHER THAN FUR, AND THE FIRST SET THAT IS NOT
# HAIR AT ALL.
#
# Everything this file already does is the right machinery for it, which is
# why it is a set here rather than a script of its own. A shard has to sit ON
# the real surface (`surface_hit`), lean off its own normal, be buried far
# enough that no rim shows (`SINK`), tile along a STROKE rather than scatter
# through a region, taper at both ends of that stroke, and -- the one that
# actually decides whether this works -- wear the BODY'S OWN UNWRAP so it is
# painted by the same baked coat as the hide under it. That last one is what
# makes the crest read as pieces of this animal instead of props glued to it,
# and it is free here and unavailable anywhere else.
#
# IT IS ONE MESH AND THEREFORE ONE PART. Costed as code-built parts the four
# populations below came to about 65 `WedgePart`s per piggy; as a fur set they
# are a single MeshPart that `applyFur` welds on, at about 670 triangles --
# under the mane's own 900. That correction is the whole reason this file is
# where the crest ended up.
#
# WHAT IS NOT HERE IS THE LIGHTNING, and it cannot be. `applyFur` paints the
# whole ruff with `tier.material`, so a bolt inside this mesh would be Neon
# only if the rock were too. The bolts are separate geometry for that one
# reason, and it is the reason they can glow at all.
#
# THE TWO MOHAWK RUNS KEEP THE MANE'S OWN LATITUDES DELIBERATELY. 54..74 and
# 108..119 are not styling numbers: they are where the crest was cut to clear
# the HAT anchor at (0, 14.15, 0) and the BACK anchor at (0, 11.0, -5.6), and
# the entry above records that the aft run had to come in from 126 to 119
# before the cape was clear. A mohawk is taller than a mane, so it is MORE
# likely to breach them, not less -- reusing the measured range is the cheap
# half and the anchor sweep at the bottom of this file is the half that
# actually checks.
STORMCREST = [
    # THE MOHAWK. Narrower than the mane's crest and half again as tall, which
    # is the whole difference between a ruff and a ridge -- and denser, because
    # broken rock is a mass of pieces where fur is a row of strokes.
    #
    # **IT STARTS AT 60 WHERE THE MANE STARTS AT 54, AND THAT IS THE HEIGHT
    # BEING PAID FOR.** The mane's crest-fore clears the GLASSES anchor at
    # (0, 10.6, 5.9) by 1.57 studs from lat 54; the same path with shards a
    # third taller measured 1.22 and was refused. A run's clearance is a
    # property of the tallest thing standing on it, not of the path -- so
    # inheriting a latitude range does NOT inherit the clearance that range
    # was measured with, which is the trap in reusing the mane's numbers at
    # all. Six degrees back buys 0.85 studs and costs a little forehead.
    # **WIDTH AGAINST HEIGHT IS THE WHOLE READ, AND THE FIRST BUILD HAD IT AT
    # A QUARTER.** Carried over from the mane's own proportions -- 0.145 wide
    # against 0.58 tall -- these came back as BRISTLES: a row of little black
    # spines, which is a hairbrush rather than broken rock, and no amount of
    # count or lean rescues a shape that narrow. Rock splits into CHUNKS, so
    # the reference's shards run about 0.6 as wide as they are tall. Roughly
    # doubled, and the count came down to pay for it -- wider pieces need
    # fewer of them, which is the same trade this file already records for
    # the wool becoming tufts.
    # **BIGGER, DENSER, WIDER AND FANNED -- all four, because the reference
    # differs from the first build on all four and each one alone leaves it
    # reading as bristles.** Measured off the photograph: a crest shard there
    # runs about a quarter to a third of the BODY'S height, the pieces overlap
    # rather than standing clear of each other, the mass spans most of the
    # width of the head, and they radiate instead of sitting parallel.
    # **AND THEN THEY WENT BLADE-LIKE, WHICH IS THE CHISEL AND THE SQUASH
    # MULTIPLYING.** `squash` narrows one axis of the base -- inherited from
    # the wool, where a slight ellipse turned at random is what stops lobes
    # reading as a bag of marbles -- and at 0.74 a base is already three
    # quarters as deep as it is wide. Put a ridge on top of that and the
    # result is a FLAP: a thin wedge that vanishes edge-on and reads as torn
    # paper rather than as rock. Two numbers each fine alone, multiplied
    # without checking the product, which is this project's oldest mistake.
    #
    # A shard wants a nearly square base, so it keeps volume from every angle.
    # The lobes keep their own range untouched.
    # **THE FORE RUN IS SIZE-BOUND, AND THE MEASUREMENTS THAT ESTABLISHED
    # THAT ARE WORTH KEEPING BECAUSE TWO PLAUSIBLE ESCAPES BOTH FAILED.**
    #
    # It is squeezed between the GLASSES anchor in front and the HAT behind.
    # At the reference's shard size: lat 60 breaches the glasses, lat 67
    # breaches the hat, and lat 65 lands on 1.4999 against a floor of 1.50.
    # The window between them is not small, it is CLOSED.
    #
    # Moving it does not work, and neither does PARTING it -- which is the
    # escape that should have worked, because the hat anchor is a point at
    # (0, 14.15, 0) rather than a region, and parting is exactly how the mane
    # cleared it. Measured, two runs at lon +-13 read 1.45. The reason is
    # geometry rather than tuning: LONGITUDE CONVERGES AT THE CROWN. At lat
    # 70 on a six-stud body, thirteen degrees of longitude is 0.4 studs of
    # actual lateral distance, and even thirty degrees is barely one. A
    # parting is cheap on the flank and nearly free of effect near the pole,
    # which is precisely where the hat sits.
    #
    # So the only two levers left are the shard SIZE and the hat itself, and
    # this is the largest size that clears all three anchors. Anything bigger
    # on this run costs hats on this skin -- a real trade, and one for a
    # person rather than for this file. The AFT run is unaffected and carries
    # the tall pieces, which is where the reference peaks anyway.
    # **ONE CONTINUOUS RUN, FOREHEAD TO SPINE, BUILT AS THREE RANKS.**
    #
    # The parting is gone -- it was inherited from the mane, where the gap
    # exists so a hat can come down between two runs, and the reference's
    # crest is plainly unbroken from the forehead over the crown and away
    # down the spine. `direction` folds a latitude past 90 back down the far
    # side, so this is one path rather than two meeting at the pole.
    #
    # THE SHAPE IS THREE ROWS AND NOT A SCATTER: one tall narrow blade on the
    # centre line with a shorter, broader rank supporting it either side.
    # That is what the photograph shows and it is not something a random
    # spread can produce -- scatter gives a mass, and this is meant to be
    # read as a designed thing.
    #
    # AND IT FLOWS. `grow` runs the size from a thin front piece up to the
    # full mass behind it, and `curl` leans each shard further along the
    # stroke than the one in front, so the run stands up at the forehead and
    # rounds over toward the tail. Those two together are the difference
    # between a crest and a comb; every build before this one had a constant
    # lean and a symmetric taper, which is a row of parallel blades however
    # big or small they are made.
    # **FEWER AND FAR BIGGER, WHICH IS THE MANE'S OWN LESSON ARRIVING ON THE
    # CREST.** That file records 152 wool lobes becoming forty tufts, because
    # an attempt at real fur is a losing race and what reads is "individually
    # readable shapes, each one something a person would have drawn on
    # purpose". Nine per rank was still trying to be a mass. The reference is
    # a handful of big pieces -- one blade and its supports -- so it is six.
    dict(name="mohawk", count=9, path=[(0, 30), (0, 78), (0, 122)],
         halfwidth=0.0, shape="shard", splay=0.05, tip=0.30,
         # **CHUNKY, NOT BLADED, AND THE HEIGHT CAME DOWN BY HALF.** The
         # guide's crystals are roughly as wide as they are tall -- cut stone
         # -- where every build before this one made them a third as wide and
         # twice as tall, which is a splinter. Reported as the hair on the
         # back being far too tall, and the fix is BOTH numbers: shortening
         # alone leaves them thin, widening alone leaves them enormous.
         squash=(0.82, 1.00),
         rows=[(0.0, 0.92, 1.00),      # the crown of the arc
               (-1.0, 1.06, 0.72),     # supports, wider and shorter
               (1.0, 1.06, 0.72)],
         rowgap=0.100,
         grow=(0.66, 1.00),
         # **THE CURL IS MOSTLY IN THE ARC NOW, NOT IN THE PIECES.** The
         # guide draws a comma: a dense run of straight-ish crystals whose
         # ARRANGEMENT sweeps up and over and back down. Bending each crystal
         # hard was solving that at the wrong level -- it made nine bent
         # blades rather than one curling mass. So the path runs from the
         # forehead to lat 134, which folds well down the back of the neck,
         # and the per-piece bend is a fraction of what it was: enough that a
         # crystal leans with the flow, not so much that it is a hook.
         curl=(0.04, 0.38),
         # HEIGHT SPLIT THE DIFFERENCE BETWEEN TWO REPORTED FAULTS. At
         # 0.70..1.30 the crest was "way too tall compared to the reference";
         # at 0.34..0.64 the chunky gems sat low enough to read as rubble on
         # the head rather than as a crest standing off it. The guide's arc
         # does both -- individually squat pieces, collectively proud -- and
         # what buys that is height in the middle of those two with the WIDTH
         # kept up, so a piece stays roughly as wide as it is tall.
         width=(0.330, 0.480), height=(0.450, 0.850), lean=-0.02),

    # THE BROW. Small, hard-swept, and sitting ABOVE AND BEHIND the eye rather
    # than around it -- which is what makes a face read as scowling instead of
    # as decorated. The eye's own direction is lon 23, lat 18.5 (solved from
    # `PiggyModel.EYE_DIR`, which is the same point in the other frame), so
    # these start just outboard of it and sweep back toward the ear.
    #
    # NOTHING FORWARD OF THE EYE, ON PURPOSE. A shard in front of it is a
    # shard on the cheek, and the snout is the one part of this animal that
    # has to stay recognisably a pig.
    #
    # IT SITS FURTHER BACK THAN THE EYE'S OWN LONGITUDE FOR A REASON THAT IS
    # NOT THE ANCHOR SWEEP, and the record is worth correcting because this
    # band was moved once on a wrong diagnosis. A glasses breach was read as
    # the brow and it was the MOHAWK; the sweep now names the band, which is
    # what settled it. The brow stayed moved because starting at lon 36 reads
    # better anyway -- a scowl is swept back from the eye rather than sitting
    # on top of it -- but it was not a clearance fix and should not be
    # remembered as one.
    dict(name="brow-R", count=4, path=[(36, 38), (50, 32), (60, 24)],
         halfwidth=0.040, shape="shard",
         width=(0.110, 0.160), height=(0.200, 0.300), lean=-0.42),
    dict(name="brow-L", count=4, path=[(-36, 38), (-50, 32), (-60, 24)],
         halfwidth=0.040, shape="shard",
         width=(0.110, 0.160), height=(0.200, 0.300), lean=-0.42),

    # AROUND THE EARS, not on them. An ear is its own mesh part and this set
    # is seated on the BODY, so these sit at the ear's base and break its
    # outline from behind -- which is where the reference carries them.
    dict(name="ear-R", count=4, path=[(34, 66), (46, 56)], halfwidth=0.045,
         shape="shard",
         width=(0.130, 0.190), height=(0.240, 0.360), lean=-0.20),
    dict(name="ear-L", count=4, path=[(-34, 66), (-46, 56)], halfwidth=0.045,
         shape="shard",
         width=(0.130, 0.190), height=(0.240, 0.360), lean=-0.20),

    # THE FLANK PATCHES, AND THEY ARE THE ONE BAND THAT WANTS THE MANE'S OWN
    # MISTAKE. That file records leaning tufts so hard that "a petal seen
    # edge-on reads as a SCALE rather than as fur -- the pig came out looking
    # like an artichoke". For rock that is the target rather than the failure:
    # pressed nearly flat, a shard is a PLATE lifting off the hide, which is
    # exactly the layer sitting just proud of the stone in the reference.
    # Low and long rather than tall, or they stop being patches and become a
    # second mohawk down the side.
    dict(name="patch-R", count=7, path=[(66, 34), (84, 10), (80, -14)],
         halfwidth=0.075, shape="shard",
         width=(0.190, 0.280), height=(0.130, 0.200), lean=-0.62),
    dict(name="patch-L", count=7, path=[(-66, 34), (-84, 10), (-80, -14)],
         halfwidth=0.075, shape="shard",
         width=(0.190, 0.280), height=(0.130, 0.200), lean=-0.62),

    # THE TAIL, AND IT IS A CLUSTER RATHER THAN A REPLACEMENT. Hiding the
    # pig's own curl is a `PiggyBank` decision -- the same shape as `glowEyes`
    # -- and nothing in a fur set can reach it. So this stands broken rock
    # AROUND the tail for now; once the curl can be hidden, these become the
    # tail and want re-measuring rather than re-tuning.
    # AND IT IS PARTED, WHICH THE ANCHOR SWEEP DECIDED RATHER THAN THE EYE.
    # One run straight up the centre back measured 0.76 studs to the BACK
    # anchor and was refused. Solved: that anchor sits at (0, 11.0, -5.6),
    # which in this file's own frame is lon 180 lat 24 -- the exact middle of
    # a 34..12 run, so the band was not near the cape, it was ON it.
    #
    # Parted either side, the way the mohawk already is for the hat, and for
    # the identical reason. It is also the better picture: rock on both
    # haunches FRAMES the tail rather than replacing it, which is honest while
    # the pig's own curl is still there.
    dict(name="tail-R", count=3, path=[(148, 36), (148, 14)], halfwidth=0.060,
         shape="shard",
         width=(0.200, 0.300), height=(0.320, 0.480), lean=-0.30),
    dict(name="tail-L", count=3, path=[(212, 36), (212, 14)], halfwidth=0.060,
         shape="shard",
         width=(0.200, 0.300), height=(0.320, 0.480), lean=-0.30),
]

SETS = {"mane": MANE, "crest": CREST, "stormcrest": STORMCREST}
SET = os.environ.get("FUR_SET", "mane")
if SET not in SETS:
    raise SystemExit("FUR_SET must be one of %s" % sorted(SETS))
BANDS = SETS[SET]

# ONE BAND AT A TIME, WHICH IS A WORKFLOW FIX RATHER THAN A FEATURE.
#
# A set is nine runs and they overlap on the animal, so a change to any one of
# them is judged against the other eight sitting on top of it -- which is how
# three separate loops on this crest went into arguing about a shape that was
# half-hidden behind its neighbours. `FUR_BANDS=mohawk-fore,mohawk-aft` builds
# only those, so the piece being worked on is the only thing in frame.
#
# It filters rather than reordering, so the RNG draws in the same sequence for
# the bands that survive -- a band looks identical whether it is built alone or
# with the rest, which is the only property that makes this worth having. A
# filter that changed what it was measuring would be worse than no filter.
_only = os.environ.get("FUR_BANDS", "").strip()
if _only:
    _want = {w.strip() for w in _only.split(",") if w.strip()}
    _known = {b["name"] for b in BANDS}
    _miss = _want - _known
    if _miss:
        raise SystemExit("FUR_BANDS: no such band %s -- have %s"
                         % (sorted(_miss), sorted(_known)))
    BANDS = [b for b in BANDS if b["name"] in _want]
    print("bands: only %s" % ", ".join(b["name"] for b in BANDS))
# "mane" keeps the historic filename so nothing already pointing at it moves.
OUT_NAME = "pig_fur_tufts" if SET == "mane" else "pig_fur_%s" % SET
BLEND_NAME = "pig_tufts" if SET == "mane" else "pig_%s" % SET
print("fur set: %s -> %s.obj" % (SET, OUT_NAME))


def surface_hit(direction):
    """Where does the real body sit along this direction?"""
    origin = direction * 4.0
    ok, loc, nor, _ = body.ray_cast(origin, -direction)
    if not ok:
        return None, None
    return loc, nor


def add_lobe(bm, base, normal, width, height, lean, phase, squash,
             bias=None, tip=0.0, face=None, bend=None):
    """One squashed dome of wool, half sunk into the surface."""
    # a frame with +Z along the surface normal
    up = normal.normalized()
    ref = Vector((0, 0, 1)) if abs(up.z) < 0.9 else Vector((1, 0, 0))
    x = up.cross(ref).normalized()
    y = up.cross(x).normalized()

    # LEAN IS A SWEEP, NOT A FLATTENING, AND THE FIRST LOW-POLY PASS GOT THAT
    # WRONG. The wool lobes leaned hard because a coat piles over itself
    # downhill; carried across to tall thin tufts it pressed them ONTO the
    # body, where a petal seen edge-on reads as a SCALE rather than as fur --
    # rendered, the pig came out looking like an artichoke. A tuft needs to
    # stand off the surface to have a silhouette at all, so the lean is now
    # only enough to give the mane a direction.
    axis = (up + Vector((0, 0, lean[1])) + x * lean[0]
            + (bias or Vector((0, 0, 0)))).normalized()
    foot = base - axis * (height * SINK)

    rings = []
    for t, r in PROFILE:
        c = foot + axis * (height * t)
        ring = []
        for i in range(SIDES):
            a = phase + (i / SIDES) * math.tau
            # SQUASHED ON ONE AXIS, PHASE RANDOM PER LOBE. Perfectly round
            # lobes all squared to one frame read as a bag of marbles; a
            # slight ellipse turned at random reads as clumped wool.
            off = x * (math.cos(a) * width * squash) + y * (math.sin(a) * width)
            ring.append(bm.verts.new(c + off * r))
        rings.append(ring)
    apex = bm.verts.new(foot + axis * height)

    tris = 0
    for k in range(len(rings) - 1):
        lo, hi = rings[k], rings[k + 1]
        for i in range(SIDES):
            j = (i + 1) % SIDES
            bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
            tris += 2
    top = rings[-1]
    for i in range(SIDES):
        bm.faces.new((top[i], top[(i + 1) % SIDES], apex))
        tris += 1
    return tris


def add_shard(bm, base, normal, width, height, lean, phase, squash,
              bias=None, tip=0.0, face=None, bend=None):
    """One crystalline spike of broken rock, half sunk into the surface.

    THE SAME SEATING AS `add_lobe` AND A DIFFERENT SHAPE, which is the whole
    reason this is a sibling rather than a parameter: every line about where a
    tuft sits, how it leans and how far it is buried is shared, and everything
    about what it looks like differs. A `PROFILE` switch alone would not have
    got there -- the side count, the tip and the irregularity all move too.

    TWO SOURCES OF IRREGULARITY, AND THEY DO DIFFERENT JOBS. `jit` varies the
    radius PER FACET, so a shard's own cross-section is a lopsided quad rather
    than a square -- which is what stops a field of them reading as a row of
    identical pyramids. The tip is then pushed OFF the axis, so the spike
    leans within itself and its four faces catch the sun at four different
    angles. Neither alone is enough: jitter with a centred tip is a squashed
    pyramid, and a centred cross-section with an offset tip is a leaning one.

    **BOTH WERE FAR TOO STRONG AND THAT IS WHAT "TOO DRAMATIC" MEANT.** At
    0.70..1.26 on the radius and +-0.34 of the width on the tip, no two edges
    of a shard were parallel and no face was flat enough to read as a cut
    plane -- so the pieces came out CRUMPLED, like foil rather than like
    stone. The point of low poly is that each facet is big enough and regular
    enough to be seen as a facet; irregularity past that stops adding variety
    and starts adding noise. Both are about a third of what they were, which
    is enough that no two shards match and little enough that every one still
    has straight edges.

    IT IS FLAT-SHADED LIKE EVERYTHING ELSE HERE, and that matters more for a
    shard than it did for a tuft. The comment at the bottom of this file
    explains why the wool pass reversed itself; broken stone is the case that
    argument was really about. A smooth-shaded shard is a plastic banana.
    """
    up = normal.normalized()

    # **WHICH WAY THE PLATE FACES, AND LEAVING IT TO CHANCE IS WHY HALF OF
    # THEM DISAPPEARED.** `squash` makes the base an ellipse -- broad on one
    # axis, thin on the other -- and that axis used to be derived from an
    # ARBITRARY reference vector, then spun again by a random `phase`. So a
    # shard's broad face pointed wherever the arithmetic happened to land it,
    # and about half of any run presented its EDGE to the viewer, where a
    # flat plate is a hairline. Rendered, the crest read as a mix of proper
    # plates and slivers, which is the shape a torn thing has rather than a
    # grown one.
    #
    # The reference's crest does not do this: every plate shows its face. A
    # crest is a ROW along a stroke, so the plate a row wants is the
    # stegosaurus one -- thin ACROSS the run, broad along it and upward, which
    # is what makes a ridge read from the side at all.
    #
    # So the caller hands in the direction the plate should be thin along --
    # the stroke's own sideways vector -- and the frame is built from it
    # rather than from a stray axis. `phase` still turns the shard where no
    # face is given, which is what every existing lobe caller wants.
    #
    # **AND THE CREST DOES NOT USE IT, WHICH IS A MEASURED NEGATIVE RESULT
    # RATHER THAN AN UNFINISHED FEATURE.** Aiming every plate the same way
    # fixes the side view and breaks every other one: thin across the run
    # means broad from the side and EDGE-ON FROM THE FRONT, so the crest
    # vanished at exactly the three-quarter angle the reference photograph is
    # taken from. Looked at again, that reference does not align its plates at
    # all -- they fan, presenting faces in many directions, which is what lets
    # them read from anywhere. So the real fix for the slivers was never the
    # aiming: it was that the plates were too THIN to survive being seen
    # edge-on, and the answer is moderate thickness with the facing left free.
    #
    # Kept because it is right for anything that genuinely is a row -- a fin,
    # a sail, a stegosaurus back -- and because a later set will want it.
    if face is not None and face.length > 1e-6:
        x = (face - up * face.dot(up))
        x = x.normalized() if x.length > 1e-6 else up.orthogonal().normalized()
        y = up.cross(x).normalized()
        # the ridge runs along the BROAD axis, so the top of a plate is an
        # edge across its width rather than a point in the middle of it
        phase = math.pi / 2
    else:
        ref = Vector((0, 0, 1)) if abs(up.z) < 0.9 else Vector((1, 0, 0))
        x = up.cross(ref).normalized()
        y = up.cross(x).normalized()

    axis = (up + Vector((0, 0, lean[1])) + x * lean[0]
            + (bias or Vector((0, 0, 0)))).normalized()
    foot = base - axis * (height * SINK)

    jit = [rng.uniform(0.90, 1.11) for _ in range(SHARD_SIDES)]

    # **THE BEND, AND IT IS A DIFFERENT THING FROM THE LEAN.** `bias` tilts
    # the axis, so the whole shard points somewhere else and stays straight.
    # This displaces each ring PROGRESSIVELY along a direction, so the base
    # keeps its seating and the tip sweeps away -- a blade of hair rising and
    # curling over, which is what the reference has and what no amount of
    # tilting reproduces.
    #
    # QUADRATIC IN HEIGHT, NOT LINEAR. Linear displacement is a shear: every
    # ring moves in proportion, which straightens back into a lean with extra
    # steps. `t*t` leaves the base almost where it was and throws the tip, so
    # the piece reads as bending under its own weight.
    _bend = bend or Vector((0, 0, 0))

    rings = []
    for t, r in SHARD_PROFILE:
        c = foot + axis * (height * t) + _bend * (height * t * t)
        ring = []
        for i in range(SHARD_SIDES):
            a = phase + (i / SHARD_SIDES) * math.tau
            off = x * (math.cos(a) * width * squash) + y * (math.sin(a) * width)
            ring.append(bm.verts.new(c + off * r * jit[i]))
        rings.append(ring)

    wobble = (x * (rng.uniform(-0.12, 0.12) * width)
              + y * (rng.uniform(-0.12, 0.12) * width))
    crown = foot + axis * height + wobble + _bend * height

    tris = 0
    for k in range(len(rings) - 1):
        lo, hi = rings[k], rings[k + 1]
        for i in range(SHARD_SIDES):
            j = (i + 1) % SHARD_SIDES
            bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
            tris += 2
    top = rings[-1]

    # **A CHISEL RIDGE RATHER THAN A POINT, AND IT IS A DIFFERENT SILHOUETTE
    # RATHER THAN A SOFTER ONE.** Four faces converging on one vertex is a
    # PYRAMID, and a field of pyramids reads as spines however big they are --
    # which is what the first crest came back as. Rock splits along planes, so
    # a broken piece ends in an EDGE: two faces meeting at a line, with the
    # other two running up to its ends. That is the difference between a
    # needle and a slab, and no width or height setting reaches it.
    #
    # The ridge runs along the ring's own `phase`, so it turns with the shard
    # rather than lining every one of them up with a world axis -- which would
    # be a row of chisels all facing the same way, a fret saw.
    if tip > 0.01:
        along = (x * math.cos(phase) + y * math.sin(phase)) * (tip * width)
        a = bm.verts.new(crown + along)
        b = bm.verts.new(crown - along)
        ends = (a, a, b, b)
        for i in range(SHARD_SIDES):
            j = (i + 1) % SHARD_SIDES
            if ends[i] is ends[j]:
                bm.faces.new((top[i], top[j], ends[i]))
                tris += 1
            else:
                bm.faces.new((top[i], top[j], ends[j], ends[i]))
                tris += 2
    else:
        apex = bm.verts.new(crown)
        for i in range(SHARD_SIDES):
            bm.faces.new((top[i], top[(i + 1) % SHARD_SIDES], apex))
            tris += 1
    return tris


SHAPES = {"lobe": add_lobe, "shard": add_shard}

rng = random.Random(SEED)
bm = bmesh.new()
tris = 0
placed = 0
missed = 0


def direction(lon_deg, lat_deg):
    """A unit direction from the body's centre.

    A LATITUDE ABOVE 90 FOLDS OVER THE TOP rather than clamping, so a path may
    be written as one straight run from the forehead to the rump instead of as
    two bands meeting at the pole, where longitude means nothing.
    """
    if lat_deg > 90.0:
        lat_deg, lon_deg = 180.0 - lat_deg, lon_deg + 180.0
    elif lat_deg < -90.0:
        lat_deg, lon_deg = -180.0 - lat_deg, lon_deg + 180.0
    lon, lat = math.radians(lon_deg), math.radians(lat_deg)
    return Vector((math.cos(lat) * math.sin(lon),
                   -math.cos(lat) * math.cos(lon),
                   math.sin(lat))).normalized()


def along(path, t):
    """Walk a list of (lon, lat) waypoints, linearly, t in 0..1."""
    if t <= 0.0:
        return direction(*path[0])
    if t >= 1.0:
        return direction(*path[-1])
    span = 1.0 / (len(path) - 1)
    i = min(int(t / span), len(path) - 2)
    f = (t - i * span) / span
    a, b = path[i], path[i + 1]
    return direction(a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)


rng = random.Random(SEED)
bm = bmesh.new()
tris = 0
placed = 0
missed = 0

# WHICH VERTICES CAME FROM WHICH BAND, SO THE SWEEP CAN NAME ONE.
#
# **THE SWEEP USED TO SAY "TOO CLOSE" AND NOT WHICH BAND, AND THAT COST TWO
# WRONG FIXES IN A ROW.** A set has nine runs in it; a bare distance says one
# of them is on an anchor and leaves the reader to guess, and a guess that
# moves the wrong band still reports the identical number afterwards -- which
# reads as the edit not working rather than as the wrong band having been
# moved. That is the silent-failure shape this project refuses everywhere
# else, in a diagnostic of all places.
#
# Vertex order out of `bmesh` survives `to_mesh`, so a half-open range per
# band is enough to attribute any vertex back to the run that made it.
band_spans = []

for band in BANDS:
    _v0 = len(bm.verts)
    path = band["path"]
    # **ROWS, WHICH IS A DESIGNED CREST RATHER THAN A SCATTERED ONE.**
    #
    # Every band until now spreads its tufts SIDEWAYS AT RANDOM inside
    # `halfwidth`, which is right for fur: a ruff is a mass and the eye should
    # not be able to count it. A crest that is meant to be READ as a shape is
    # the opposite problem -- the reference's mohawk is plainly one tall blade
    # down the middle with a shorter, wider one supporting it on each side,
    # and no amount of scatter produces three deliberate ranks.
    #
    # So a band may carry `rows`: (sideways offset, width scale, height
    # scale). The offsets are in units of `rowgap`, so the ranks stay parallel
    # at any spacing, and the two scales are what let a supporting row be
    # shorter and broader than the one it flanks without a second band.
    #
    # A band with no `rows` is untouched, down to the order of the random
    # draws -- which is what keeps the mane and the zebra's forelock
    # byte-identical.
    _rows = band.get("rows") or [(0.0, 1.0, 1.0)]
    _rowgap = band.get("rowgap", 0.0)
    for _ri, _row in enumerate(_rows):
      for k in range(band["count"]):
        # EVENLY ALONG THE PATH PLUS A NUDGE, never uniformly random along it.
        # Random t clumps and gaps by itself -- and a gap in a ridge of fur is
        # a bald patch rather than a variation.
        t = (k + 0.5) / band["count"]
        t = min(1.0, max(0.0, t + rng.uniform(-0.35, 0.35) / band["count"]))

        d = along(path, t)
        # the path's own tangent, so "sideways" means sideways to the STROKE
        # rather than to some world axis that happens to be handy
        ahead = along(path, min(1.0, t + 0.02))
        behind = along(path, max(0.0, t - 0.02))
        tangent = (ahead - behind)
        tangent = tangent.normalized() if tangent.length > 1e-6 else Vector((1, 0, 0))
        side = d.cross(tangent).normalized()

        # HOW FAR OFF THE STROKE'S OWN LINE THIS ONE SITS, kept rather than
        # thrown away, because the FAN below is a function of it: a shard at
        # the edge of the band leans outward and one on the line stands up.
        # A ROW SITS AT A FIXED OFFSET AND A SCATTERED BAND AT A RANDOM ONE.
        # The jitter stays on a row as well, but tiny -- enough that a rank is
        # not machined, not enough that it stops being a rank.
        if band.get("rows"):
            off = _row[0]
            d = (d + side * (off * _rowgap + rng.uniform(-0.018, 0.018))
                 + tangent * rng.uniform(-0.03, 0.03)).normalized()
        else:
            off = rng.uniform(-1.0, 1.0)
            d = (d + side * (off * band["halfwidth"])
                 + tangent * rng.uniform(-0.03, 0.03)).normalized()

        # **THE CURL, AND IT IS THE ONE THING THAT MAKES A CREST FLOW.**
        # Leaning every shard by the same amount gives a row of parallel
        # blades -- which is what the last four builds were, and why they
        # read as a comb whatever their size. Real hair and real fracture both
        # SWEEP: the piece at the front stands nearly up and each one behind
        # it lies further over, so the run rounds off toward the tail.
        #
        # Along the path's OWN TANGENT rather than a world axis, so the sweep
        # follows the stroke wherever it goes -- over the crown, where "back"
        # stops being any fixed direction, this is the only version that
        # still means what it says.
        # Along the path's OWN TANGENT rather than a world axis, so the sweep
        # follows the stroke wherever it goes -- over the crown, where "back"
        # stops being any fixed direction, this is the only version that still
        # means what it says.
        _c0, _c1 = band.get("curl", (0.0, 0.0))
        _curl = tangent * (_c0 + (_c1 - _c0) * t)

        loc, nor = surface_hit(d)
        if loc is None:
            missed += 1
            continue

        # TAPERED AT BOTH ENDS, or a ridge stops square and reads as a strip of
        # something glued on. The lobes simply get smaller toward the tips.
        # A GENTLER TAPER THAN THE WOOL HAD. With forty tufts instead of a
        # hundred and fifty, a run that shrinks hard at the ends loses its
        # last two or three shapes into nothing rather than ending on one.
        # **HOW BIG THIS ONE IS ALONG THE RUN.** The default tapers BOTH ends,
        # because a ruff that stops square reads as a strip of something glued
        # on. A crest wants the other shape entirely: the reference's front
        # piece is a thin blade and the mass builds behind it, so `grow` lerps
        # a scale from the front of the run to the back and replaces the
        # symmetric taper outright where it is given.
        if band.get("grow"):
            _g0, _g1 = band["grow"]
            taper = _g0 + (_g1 - _g0) * t
        else:
            taper = 0.82 + 0.18 * math.sin(math.pi * t) ** 0.50
        # WHICH PRIMITIVE, PER BAND RATHER THAN PER SET, so a later set can
        # carry both -- a stone animal with a fur ruff is a real thing to want
        # and this is the only line that would otherwise forbid it. Defaults
        # to the lobe, so the mane and the crest are untouched to the byte.
        make = SHAPES[band.get("shape", "lobe")]
        # **THE SPLAY, AND IT IS WHAT SEPARATES A CLUSTER FROM A COMB.** Every
        # shard standing on its own surface normal comes out very nearly
        # parallel to its neighbours, because a body this round barely turns
        # over the width of one band -- so a dense run reads as the teeth of a
        # comb rather than as a mass of broken rock. Real fracture throws
        # pieces APART. Biasing each one along the stroke's own sideways
        # direction, in proportion to how far off the line it landed, opens
        # the run into a fan: the middle stands up and the edges lie outward,
        # which is also what makes the silhouette wider than the band is.
        #
        # Proportional rather than random on purpose. A random lean per shard
        # is noise and reads as damage; a lean that tracks POSITION reads as
        # one thing that burst outward, which is the shape being copied.
        tris += make(bm, loc, nor,
                     rng.uniform(*band["width"]) * taper * _row[1],
                     rng.uniform(*band["height"]) * taper * _row[2],
                     (rng.uniform(-0.22, 0.22), band["lean"]),
                     rng.uniform(0, math.tau),
                     rng.uniform(*band.get("squash", (0.74, 1.0))),
                     side * (off * band.get("splay", 0.0)),
                     band.get("tip", 0.0),
                     side if band.get("plate") else None,
                     _curl)
        placed += 1
    band_spans.append((band["name"], _v0, len(bm.verts)))

me = bpy.data.meshes.new("FurTufts")
bm.to_mesh(me)
bm.free()
tuft = bpy.data.objects.new("FurTufts", me)
bpy.context.scene.collection.objects.link(tuft)

# ------------------------------------------------------- the body's own UVs
# THE LOBES ARE UNWRAPPED ON THE BODY'S CYLINDER, WHICH IS WHAT LETS THEM WEAR
# THE PATTERN. Without this the mesh has no usable UVs at all, so it can only
# ever be a FLAT COLOUR -- and a flat colour lying over a patterned coat is a
# patch whatever colour it is: cream reads as blobs stuck on the animal
# (reported), and the body's own colour reads as a bald spot where the spots
# stop. That was the whole reason the ruff had to come off the leopard.
#
# Given the same mapping the body uses, a lobe samples the SAME map at the
# same place, so the spots and stripes carry straight over the fur and the
# silhouette comes back for free. This is the one fix that closes the gap
# between the engine and the Blender groom: Roblox has no fur shader and no
# shell rendering, so a fuzzy OUTLINE can only ever be geometry.
#
# COPIED FROM `build_pig.uv_cylinder` DELIBERATELY, INCLUDING THE SEAM FIX.
# u is the angle about the standing axis; v is height normalised over the
# UNION of Body and Trim -- not over the tufts, which occupy a different
# range, and not over the body alone, or every lobe would sit at the wrong
# height on the sheet and the pattern would be offset from the animal wearing
# it. The per-FACE seam fix is here for the same reason it is there: a face
# spanning the wrap gets its low corners pushed a whole turn rather than
# smearing the whole texture across the flank.
# PINNED, AND SHARED WITH `build_pig.py` RATHER THAN RE-MEASURED HERE. This
# used to take min/max over Body and Trim -- the same arithmetic the body's own
# unwrap ran -- which agrees today and is two copies of one number. Worse, both
# copies move together when the animal's height moves, so the tufts would stay
# registered with the body while every PATTERN MAP silently slid underneath
# them. `pig_uv` is the one place that range is decided.
pig_uv.check_drift((body, trim), "uv")
_zmin, _span = pig_uv.UV_Z0, pig_uv.UV_SPAN

_uvl = me.uv_layers.new(name="UVMap")
_wrapped = 0
for _p in me.polygons:
    _us = []
    for _li in _p.loop_indices:
        _co = me.vertices[me.loops[_li].vertex_index].co
        _u = (math.atan2(_co.y, _co.x) / (2.0 * math.pi)) + 0.5
        _vv = (_co.z - _zmin) / _span
        _uvl.data[_li].uv = (_u, _vv)
        _us.append((_li, _u, _vv))
    if max(x[1] for x in _us) - min(x[1] for x in _us) > 0.5:
        _wrapped += 1
        for _li, _u, _vv in _us:
            if _u < 0.5:
                _uvl.data[_li].uv = (_u + 1.0, _vv)
print("  uv: cylinder shared with the body, %d faces carried across the wrap"
      % _wrapped)
print("  uv: v range %.3f..%.3f of the sheet"
      % (min(d.uv[1] for d in _uvl.data), max(d.uv[1] for d in _uvl.data)))

# FLAT SHADED, WHICH REVERSES THE WOOL PASS DELIBERATELY. Smooth shading was
# there to stop a ten-triangle lobe reading as a cut gem -- correct when the
# lobes were pretending to be a soft mass. These tufts are not pretending: the
# rest of this world is flat-shaded low poly (the house rebuild stripped every
# textured material for exactly that reason), and a faceted tuft catching the
# sun in three planes is the same vocabulary. Smooth here would make them read
# as plastic bananas.
bpy.ops.object.select_all(action='DESELECT')
tuft.select_set(True)
bpy.context.view_layer.objects.active = tuft
bpy.ops.object.shade_flat()

xs = [v.co.x for v in me.vertices]
ys = [v.co.y for v in me.vertices]
zs = [v.co.z for v in me.vertices]
print("")
print("=== FUR TUFTS ===")
print("  %d tufts placed, %d rays missed the body" % (placed, missed))
print("  %d verts  %d faces  %d tris once triangulated"
      % (len(me.vertices), len(me.polygons), tris))
print("  x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f"
      % (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))

# ------------------------------------------------------- the anchor sweep
# THE TAX GEOMETRY PAYS AND A TEXTURE DOES NOT. A painted stripe behind a
# player's hat is invisible and harmless; a TUFT there is a lump inside a
# thing they rolled for, and this file already records the full mane coming
# within 0.54 studs of the hat anchor before it was parted.
#
# A crown tuft is the shape most likely to break it and the easiest to get
# wrong, because it is one short band with nothing forcing it to stop -- so
# the check runs on every set rather than only on the one that once failed.
_ANCHORS = {"hat": Vector((0, 14.15, 0)),
            "eyes": Vector((0, 10.6, 5.9)),
            "back": Vector((0, 11.0, -5.6))}
_bmid = Vector(((min(v.co.x for v in body.data.vertices)
                 + max(v.co.x for v in body.data.vertices)) * 0.5,
                (min(v.co.y for v in body.data.vertices)
                 + max(v.co.y for v in body.data.vertices)) * 0.5,
                (min(v.co.z for v in body.data.vertices)
                 + max(v.co.z for v in body.data.vertices)) * 0.5))
_body_off = Vector((0.0, 6.62, 0.0835))     # Config.PIGGY_MESH's Body row
_pts = [Vector(((c.co.x - _bmid.x) * SCALE, (c.co.z - _bmid.z) * SCALE,
                -(c.co.y - _bmid.y) * SCALE)) + _body_off for c in me.vertices]
print("")
for _an, _av in _ANCHORS.items():
    _d, _who = min(((p - _av).length, _i) for _i, p in enumerate(_pts))
    _band = next((_nm for _nm, _a, _b in band_spans if _a <= _who < _b), "?")
    print("  clearance to the %-4s anchor: %.2f studs   %-9s  nearest: %s"
          % (_an, _d, "OK" if _d >= 1.5 else "TOO CLOSE", _band))

for ob in bpy.context.scene.objects:
    ob.select_set(False)
tuft.select_set(True)
bpy.context.view_layer.objects.active = tuft
path = paths.pig(OUT_NAME + ".obj")
# EXPORTED IN STUDS, NOT IN BLENDER UNITS, AND THIS WAS WRONG UNTIL IT WAS
# MEASURED AGAINST THE BODY. `build_pig.py` exports with `global_scale=SCALE`
# so `pig_body.obj` comes out with a bounding box of exactly 12.0000 studs --
# the number in `Config.PIGGY_MESH`. This file exported raw, so the tufts came
# out 2.04 across: A SIXTH OF THE SIZE, which would have imported as a pea and
# cost an upload to find out.
#
# Nothing errors either way, and neither file looks wrong on its own. The only
# thing that catches it is measuring the two exports AGAINST EACH OTHER, which
# is worth doing for any new part that has to stand beside the pig.
bpy.ops.wm.obj_export(filepath=path, export_selected_objects=True,
                      export_uv=True, export_normals=True,
                      export_materials=False, forward_axis='NEGATIVE_Z',
                      up_axis='Y', global_scale=SCALE,
                      export_triangulated_mesh=True)
print("  exported", path)

# THE CONFIG BLOCK, PRINTED READY TO PASTE. These two numbers were carried by
# hand once and went stale across three reshapes, which shrank the mesh and
# buried the tufts inside the pig. Measuring them against the BODY's export
# here means the build that changes the mesh is the build that hands over the
# correct values.
_b = paths.pig("pig_body.obj")
if os.path.exists(_b):
    _lo = [1e9] * 3
    _hi = [-1e9] * 3
    for _line in open(_b, encoding="utf-8", errors="ignore"):
        if _line.startswith("v "):
            _q = _line.split()
            for _i in range(3):
                _c = float(_q[_i + 1])
                _lo[_i] = min(_lo[_i], _c)
                _hi[_i] = max(_hi[_i], _c)
    BODY_OFFSET = (0.0000, 6.6200, 0.0835)      # Config.PIGGY_MESH's Body row
    _bm = [(_hi[_i] + _lo[_i]) / 2.0 for _i in range(3)]
    _T = [BODY_OFFSET[_i] - _bm[_i] for _i in range(3)]
    _fx = [v.co.x * SCALE for v in me.vertices]
    _fy = [v.co.y * SCALE for v in me.vertices]
    _fz = [v.co.z * SCALE for v in me.vertices]
    # the exporter turns Blender (x, y, z) into (x, z, -y)
    _ax = (min(_fx), max(_fx))
    _ay = (min(_fz), max(_fz))
    _az = (-max(_fy), -min(_fy))
    _sz = [_ax[1] - _ax[0], _ay[1] - _ay[0], _az[1] - _az[0]]
    _of = [(_ax[0] + _ax[1]) / 2 + _T[0], (_ay[0] + _ay[1]) / 2 + _T[1],
           (_az[0] + _az[1]) / 2 + _T[2]]
    print("")
    print("  --- paste into Config.FUR_MESH ---")
    print("  size   = Vector3.new(%.4f, %.4f, %.4f)," % tuple(_sz))
    print("  offset = Vector3.new(%.4f, %.4f, %.4f)," % tuple(_of))
bpy.ops.wm.save_as_mainfile(filepath=paths.pig(BLEND_NAME + ".blend"))
