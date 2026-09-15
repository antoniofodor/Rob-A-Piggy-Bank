# -*- coding: utf-8 -*-
"""Build the DRAGON KIT -- dorsal blades, ear fins and a tail flame, as one
separate mesh that a skin can wear.

    "/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" \
        --background --python make/make_dragon_kit.py
    ... --python make/make_dragon_kit.py -- --render      # and look at it

Writes `pig/pig_dragon_kit.obj`, `pig/pig_dragon.blend`, and with `--render`
four game-lit shots into `renders/`.

WHY THIS IS A SEPARATE MESH AND NOT SCULPTED INTO THE PIG, which is the first
thing to understand before touching any of it. `Config.PIGGY_MESH` is GLOBAL --
one Body id and one Trim id for the entire catalogue -- so anything cut into
the pig grows on all 46 skins. A dragon's spines on the Solid Gold pig is not a
thing anybody asked for. `Config.FUR_SETS` already solved exactly this for the
mane: a named extra mesh, attached at an offset, worn by the skins that name it
and invisible to the rest. This is that same contract with different geometry
in it, and `make_fur_tufts.py` is its worked example.

WHAT THAT CONSTRAINT COSTS, STATED UP FRONT BECAUSE IT DECIDES THE EAR. The
reference has DRAGON ears -- angular, spiked, webbed -- where the pig has round
ones, and the pig's round ear cannot be removed, because it is 3,580 verts of a
Trim mesh shared with every other skin. So the fin does not REPLACE the ear, it
CLADS it: spikes seated on the ear's own silhouette, radiating outward, so the
combined outline reads as a dragon fin from any angle while the pig ear is
still under there. Painted dark by the skin it disappears into the fin. Trying
to hide the ear instead would need a second Trim upload and a branch in
`PiggyBank` for every skin that does not want it.

EVERY PIECE IS SEATED BY RAYCAST AT THE REAL MESH, NEVER BY ARITHMETIC ON A
FITTED SHAPE. This is `make_fur_tufts.py`'s rule and it is inherited wholesale:
the body is a generated mesh with a snout socket, a vault hatch and a coin slot
in it, and `CLAUDE.md` records at length what happens when something is placed
against an ellipsoid fitted to the bounding box -- the rump stands 0.55 studs
outside that fit, and a cap seated on it sat half a stud down a shaft. The ear
silhouette is MARCHED rather than assumed for the same reason: the ear is a
generated plate and nobody knows its outline but the mesh.

THE THREE ANCHORS ARE THE REAL CONSTRAINT ON A DORSAL RIDGE, and they are why
the blades do not start at the crown the way the reference's do. A hat sits at
game (0, 14.15, 0), which is Blender (0, -0.014, 1.255) -- directly over the
crown and only 1.77 studs above it. `make_fur_tufts.py` had to PART the mane
around that after the full ruff came within 0.54 studs of it, and a blade tall
enough to read is far worse than a tuft. A cape hangs off game (0, 11.0, -5.6),
Blender (0, 0.919, 0.730), which is the tail base -- so the ridge has to stop
before the rump as well. `CLAUDE.md`'s rule is absolute: nothing this game owns
may stand in an anchor a player has rolled for. The sweep at the bottom checks
all three on every build rather than trusting these numbers.

THE COORDINATE FRAME IS `pig.blend`'S, measured off the mesh rather than
assumed -- and note it is NOT the frame the skin scripts use, which work in
`pig_parts.blend`. Here:

    x   across          body +-1.000
    y   NOSE to TAIL    snout tip -1.381, body -1.080..1.052, tail tip 1.465
    z   floor to CROWN  legs -1.020, body -0.960..0.960, ear tip 1.309

So -Y is the face and +Z is up, and one unit is 6.0 studs.
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

import bpy, bmesh, math, os, sys   # noqa: E402
from mathutils import Vector       # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER = "--render" in argv

# WHICH PIECES TO BUILD. `--only ears` builds the ears and nothing else, which
# is the difference between iterating on a piece and iterating on a pig.
#
# WHY THIS EXISTS. Four pieces on one animal means every render is a picture of
# all four, and a change to one is judged against the other three arguing with
# it -- two passes were spent thinking the ears were too big when the thing
# making them look big was the wing behind them. Isolating a group is the same
# instrument as `--parts` (which drops the pig) applied to the kit itself: show
# ONE thing, then decide about it.
#
# The pig is still there under it. A spike is only right relative to the animal
# it is on, so this hides the SIBLINGS, never the body.
GROUPS = ("spikes", "ears", "wings", "flame")
if "--only" in argv:
    _w = argv[argv.index("--only") + 1]
    WANT = set(g.strip() for g in _w.split(",") if g.strip())
    _bad = WANT - set(GROUPS)
    if _bad:
        raise SystemExit("unknown group(s) %s -- pick from %s"
                         % (", ".join(sorted(_bad)), ", ".join(GROUPS)))
else:
    WANT = set(GROUPS)
TAG = "" if WANT == set(GROUPS) else "_" + "-".join(sorted(WANT))

# --------------------------------------------------------------- the tunables
# EVERY NUMBER THAT DECIDES THE SHAPE IS IN THESE DICTS, so "the blades are too
# tall" is a one-line edit and a fifteen-second re-run -- the same loop the skin
# scripts use. Sizes are in BODY UNITS, where the pig is 1.0 in radius and 12
# studs across, so 0.10 is about six tenths of a stud.

BLADES = dict(
    # TWO RUNS WITH THE CROWN LEFT BARE, WHICH IS THE MANE'S OWN ANSWER TO THE
    # SAME PROBLEM AND WAS ARRIVED AT THE SAME WAY -- by running out of back.
    #
    # A hat sits at Blender y -0.014, dead on the crown, and nothing this game
    # owns may stand in an anchor a player has rolled for. Obeying that with a
    # SINGLE run leaves y 0.12..0.62 -- half a unit, three studs -- and nine
    # blades on three studs overlap five to one. Rendered broadside they came
    # out as one continuous stepped SLAB, which is a shield rather than a
    # ridge, and no amount of resizing fixes it: the run is simply too short to
    # hold separated plates.
    #
    # Parting it doubles the usable back and puts spikes BETWEEN THE EARS,
    # which is where the reference has its biggest ones. `make_fur_tufts.py`
    # reached the identical shape for the identical reason and its comment says
    # so: "a parted mane is what a stylised animal has anyway -- and the gap is
    # where the hat goes."
    #
    # Each run is (y start, y end, how many).
    #
    # SPREAD WIDER WHEN THE BASE GREW. At a base of 0.42 on an aft run spaced
    # 0.093 apart the blades overlapped four and a half times over and welded
    # back into the solid slab this file already fixed once -- broadening the
    # base and keeping the spacing is the same mistake as lengthening them was.
    # Base and spacing move TOGETHER or the ridge is a shield.
    runs=((-0.54, -0.36, 2), (0.22, 0.56, 4)),
    # THE BLADE ITSELF. `length` is along the spine, `thick` across it, `height`
    # up the surface normal.
    #
    # NARROW, AND THAT REVERSES THE FIRST TWO PASSES. Those went after "the
    # blades are too small" by growing every dimension, which is the right
    # instinct from `make_fur_tufts.py` -- a piece of geometry has to be big
    # enough to be a SHAPE -- and the wrong diagnosis here. They were never too
    # small; they were too CLOSE, and growing `length` welded them together
    # faster. The reference's spikes are tall, narrow and countable, so height
    # stays and length comes down to about a third of the spacing.
    #
    # AND THEN BACK UP AGAIN, ONCE THEY WERE ACTUALLY SEPARATE. At 0.15 by
    # 0.60 a blade is one part wide to four tall, which broadside is a
    # NEEDLE -- the ridge read as a porcupine. The reference's are nearer one
    # to two. The bases still overlap about twice over and that is WANTED:
    # overlapping bases with separate tips is a connected crest with
    # countable points, which is the thing itself, where separate bases would
    # be a row of individual horns.
    #
    # AND THEN THICK, WHICH IS THE THIRD TIME THIS NUMBER HAS MOVED AND THE
    # FIRST TIME IT WAS THE RIGHT ONE. `length` and `height` are what a blade
    # shows BROADSIDE, and both earlier passes tuned only those -- so the ridge
    # got taller and wider and stayed a row of thin cards, because `thick` is
    # the axis neither the side shot nor the hero shot can see. It is what the
    # crown and spine shots see, and it is what the reference has: chunky
    # wedges with real mass, not plates. 0.14 to 0.30 roughly doubles the
    # cross-section and costs nothing -- the whole kit is still under 200 tris.
    #
    # AND BROADER AGAIN, measured against the reference rather than judged.
    # Its plates are about 3.2 studs tall on a 2.3-stud base; at 0.30 by 0.52
    # these were 2.44 on a 1.19, so the height was three quarters right and the
    # BASE was half. A tall narrow triangle is a horn and a broad one is a
    # plate, and the base is what decides which.
    #
    # BROADER AND SHORTER, judged in isolation rather than on the animal.
    # At 0.30 by 0.70 the base-to-height ratio is 1:2.3, which in profile is
    # a thin curved CLAW -- and four of them in a row read as a set of talons
    # stuck in the back. The reference's are triangular PLATES, nearer 1:1.5,
    # broad enough at the base that the silhouette is a triangle rather than
    # a hook.
    length=0.42, thick=0.320, height=0.62,
    # THE LEAN, in radians, toward the tail. A vertical blade reads as a comb;
    # raked back it reads as an animal that moves forwards.
    # AND LESS RAKE. Combined with the `t**1.5` curve, 0.30 bent the tips
    # over far enough that each spike read as a claw curling backwards. A
    # plate leans; it does not hook.
    lean=0.19,
    # HOW MUCH THE BLADE IGNORES THE SURFACE IT STANDS ON, and this is the fix
    # for the worst thing in the first build. A blade seated along the surface
    # NORMAL is upright over the shoulders and LYING DOWN over the rump, because
    # the back of a sphere turns over -- rendered, the rear half of the ridge
    # read as flat leaves stuck to the pig rather than as plates. A real dorsal
    # fin stands UP whatever the body is doing underneath it, so the normal is
    # blended toward world +Z: 0 follows the body exactly, and about 1 keeps the
    # whole row standing while still letting the front ones splay forward.
    #
    # SEATING IS STILL THE RAYCAST -- only the DIRECTION changes. Where a blade
    # sits is a fact about the mesh and stays measured; which way it points is a
    # fact about dragons.
    upright=1.15,
    # THE PROFILE ALONG EACH RUN, as a multiplier on every dimension. Biggest in
    # the middle and smaller at both ends, so a run has a crest rather than
    # stopping square -- `make_fur_tufts.py` records the same taper for the same
    # reason, and the same warning that too hard a taper loses its end pieces.
    end_scale=0.52,
    # HOW FAR THE BASE IS BURIED, as a share of height, so no rim ever shows
    # where the blade meets the back.
    sink=0.16,
)

EAR_FINS = dict(
    # SHORT BLUNT SPIKES ON THE EAR'S RIM, WHICH REPLACES A WEBBED FAN AND IS
    # THE THIRD SHAPE THIS HAS BEEN. The fan was measured at 2.68 studs of
    # reach on an ear 5.2 studs tall -- half the ear again, radiating in a
    # 96-degree starburst -- and reported as "far too long and sharp". It was.
    #
    # WHAT THE REFERENCE ACTUALLY HAS is a pig ear with a few small angular
    # points along its outer edge: the ear's own silhouette is still the shape,
    # and the spikes are an EDGE TREATMENT on it. That is a different design
    # from a membrane growing out of the ear, and no size of fan is it.
    #
    # So they are short (about a fifth of the ear's height), chisel-ended
    # rather than pointed, and they follow the rim instead of radiating from
    # one root.
    count=4,
    # WHERE ON THE SILHOUETTE, in degrees round the ear from straight up, going
    # outboard. Marched against the real ear rather than assumed.
    angles=(-34.0, -10.0, 14.0, 40.0),
    # `length` runs ALONG the rim, `thick` across the ear, `out` is how far the
    # spike stands off it. All small: this is trim, not an appendage.
    #
    # FLAT IN THE EAR'S OWN PLANE, WHICH IS THE WHOLE OF WHY THE FIRST TRY
    # READ AS HORNS. At 0.17 along the rim by 0.115 across, the cross-section
    # is very nearly ROUND -- so each spike was a little cone standing off the
    # ear, three separate objects glued to it. The reference's points are FLAT:
    # they lie in the plane of the ear and continue its outline, so the ear
    # simply has a jagged edge rather than horns on it.
    #
    # `thick` is matched to the ear PLATE, not chosen. A point thicker than
    # the thing it grows out of is a lump whatever its length is.
    length=0.30, thick=0.058, out=0.25, end_scale=0.70,
    # HOW WIDE THE TIP IS, as a share of the base. Not zero -- see `blunt` in
    # `blade()`. A needle on an ear reads as a thorn stuck on rather than as
    # part of the animal.
    blunt=0.24,
    # HOW FAR BACK THEY RAKE, in radians.
    sweep=0.26,
    # SUNK DEEP, so the bases disappear into the rim. At 0.16 the points sat
    # ON the ear with a visible join at each one and read as four teeth glued
    # to an edge; buried a third of their own length the ear simply becomes
    # jagged, which is what the reference has. `blade()` measures this as a
    # share of the spike's own reach, so it scales with `end_scale`.
    sink=0.38,
)


# THE SMALL WINGS, WHICH WERE MISSING ENTIRELY. The reference carries a folded
# membrane on each upper flank behind the shoulder -- smaller than the ears,
# flaring outboard and back, and they are most of why the silhouette reads as a
# DRAGON rather than as a spiked pig. Same builder as the ear, seated by
# raycasting outward at the real flank.
WINGS = dict(
    # WHERE ON THE BODY, as (y along the nose-tail axis, z height). Behind the
    # ear and above the waist, which is where a wing root belongs and is also
    # the one patch of flank with nothing else on it -- the ridge is above and
    # the legs are below.
    #
    # HIGH ON THE SHOULDER. At z 0.52 the wings read as fins on the waist --
    # the reference carries them up near the top of the flank, just behind
    # the ear, where a wing root actually is. It is also the only band with
    # room: the ridge owns the centreline above and the legs the bottom.
    y=-0.12, z=0.64,
    # HOW BIG. Deliberately smaller than the ear: the reference's wings read as
    # folded rather than spread, and a wing that out-spans the ears turns the
    # animal into a bat.
    # `span` in degrees, as the ear's is. Narrower than the ear: a folded
    # wing is a tighter fan than an open one.
    #
    # THE SCALLOP IS THE WHOLE DIFFERENCE BETWEEN A WING AND A STARBURST,
    # and 0.52 was on the wrong side of it. That dips the web halfway back
    # toward the root between every pair of ribs, which separates them into
    # individual spikes with air between -- rendered in isolation the wings
    # read as a HAND OF DAGGERS. A bat's membrane comes almost all the way
    # out to the finger tips and dips only a little, so the shape is a
    # continuous sheet with a notched trailing edge.
    #
    # Narrower too: a FOLDED wing is a tighter fan than a spread one, and
    # the reference's are held close to the body.
    length=0.74, span=64.0, thick=0.080, ribs=4, scallop=0.80,
    # WHICH WAY IT GROWS, in degrees: up off horizontal, and swept back.
    #
    # LIFT IS NEARLY VERTICAL, AND AT 38 DEGREES IT WAS A SHELF. `webbed_fin`
    # spans `out` and `span`, so with `out` mostly OUTBOARD the membrane lies
    # in a roughly horizontal plane -- rendered, the wings came out as two
    # brackets sticking sideways out of the flank. A wing is a SAIL: mostly up,
    # leaning out, so its face points sideways and its silhouette is the thing
    # you see from the front and the back.
    lift_deg=72.0, rake=0.42,
    sink=0.14,
)

# THE FLAME IS BUILT INTO ITS OWN OBJECT, which is a preview decision that
# turned out to be a shipping one. In the first build it shared the kit's dark
# rock and read as three more spikes on a pig that already had fifteen -- there
# was no way to tell whether the SHAPE was wrong or whether it was simply not
# lit. A flame that is not emissive is a horn.
#
# Keeping it separate also leaves the choice open: one .obj with two material
# slots ships as one upload the way `FUR_SETS` does, and a second object is
# what a future `aura` particle emitter would be anchored to. Merging them
# later is one line; splitting them after the fact is a re-export.
FLAME = dict(
    # A TORCH TOP, NOT A HANDFUL OF LICKS. The first build made five thin
    # tapered spikes fanned out from the tail tip, and thin is exactly wrong:
    # a lit torch reads as ONE ROUNDED MASS of fire with licks coming off the
    # top of it, and the mass is most of the silhouette. So there are more of
    # them, they are much fatter, they are clustered rather than fanned, and
    # they are SHORTER relative to their width -- which together make a body
    # of flame rather than a bundle of sticks.
    count=7,
    # HOW BIG the tallest lick is, how far the cluster spreads at its base, and
    # how much the outer ones fall back. `spread` is small on purpose: the
    # roots want to be nearly on top of each other so the bases merge into one
    # mass, which is the difference between a flame and a fan.
    height=0.56, spread=0.115, falloff=0.34,
    # THE CURL, in radians over the lick's own length. A straight taper is a
    # spike; a curled one is a flame, and this is the whole difference.
    # HOW FAR EACH LICK LEANS OFF THE COMMON UP AXIS.
    # TIGHT. At 0.40 the outer licks leaned far enough off the axis that the
    # cluster opened into a flat fan again, which is the shape this was
    # already fixed out of once.
    splay=0.24,
    # AND THE CURL IS SMALL, WHICH REVERSES AN EARLIER NOTE. It said a
    # straight taper is a spike and a curled one is a flame -- true, and at
    # 0.95 each lick bends about 55 degrees in a direction `frame()` picks
    # ARBITRARILY, so they curled every way including down and the torch
    # splayed. A flame's licks lean the same way; until the curl axis is
    # tied to the flame's own up vector, a small curl is the honest setting.
    curl=0.34,
    # WHICH WAY IT LEANS. Up and slightly back off the tail tip.
    lean=0.34,
    # SEGMENTS up a lick, and how fat it starts. `thick` is nearly half the
    # height now, which is what makes it a tongue rather than a needle.
    segments=3,
    thick=0.240,
)

# HOW CLOSE ANYTHING MAY COME TO AN ACCESSORY ANCHOR, in studs. Lifted from
# `make_fur_tufts.py` rather than re-chosen, because it is the same rule about
# the same three points and two different thresholds would be worse than none.
ANCHOR_MIN = 1.5

# --------------------------------------------------------------- the pig
bpy.ops.wm.open_mainfile(filepath=paths.RAW)

body = bpy.data.objects["Body"]
ears = bpy.data.objects["Ears"]
tail = bpy.data.objects["Tail"]
trim = bpy.data.objects["Trim"]

# STUDS PER BODY UNIT, DERIVED FROM THE BODY RATHER THAN PINNED -- the same
# derivation `make_fur_tufts.py` makes, and for the same reason: a literal 6.0
# is a second copy of a number `build_pig.py` owns and it goes stale the day
# the pig is resized.
GAME_BODY_X = 12.0
_bx = [v.co.x for v in body.data.vertices]
SCALE = GAME_BODY_X / (max(_bx) - min(_bx))

bm = bmesh.new()
fm = bmesh.new()        # the flame, kept apart -- see FLAME above
_active = [None]        # which bmesh the builders are writing into

# WHICH GROUP EACH VERTEX CAME FROM, so the anchor sweep can NAME the offender.
# The first build reported "back anchor 0.48 studs, TOO CLOSE" and nothing
# else, and the three candidates -- the last blade, the tail flame and a rear
# ear spike -- are in completely different places with completely different
# fixes. A check that says a number without saying what produced it sends the
# next person tuning the wrong dial, which is the shape of half the
# post-mortems in `CLAUDE.md`.
GROUP_AT = []          # parallel to bm.verts, filled as each piece is built
_group = [None]


def mark(name, target):
    _group[0] = name
    _active[0] = target


def _sync():
    while len(GROUP_AT) < len(_active[0].verts):
        GROUP_AT.append(_group[0])


def frame(up):
    """An orthonormal frame with +Z along `up`."""
    up = up.normalized()
    ref = Vector((0, 0, 1)) if abs(up.z) < 0.9 else Vector((1, 0, 0))
    x = up.cross(ref).normalized()
    y = up.cross(x).normalized()
    return x, y, up


def blade(base, up, along, length, thick, height, lean, sink, blunt=0.0):
    """One dorsal fin: a LENS-SECTION SPIKE that tapers and curves to a point.

    ROUNDED AND TAPERED RATHER THAN FACETED AND SQUARE, WHICH IS WHAT "LOW
    POLY" ACTUALLY MEANS AND IS NOT WHAT THE FIRST FOUR PASSES BUILT. Those
    made a quad base rising to a ridge -- five faces, right angles at every
    corner, parallel flanks -- and reported as "boxy and blocky", correctly. A
    box with few polygons is not low poly, it is a box: the style is about
    CURVED FORMS described by few polygons, and a rectangular base can never be
    one however few faces it has.

    So the fin is RINGS. Each ring is a flattened hexagon -- long along the
    spine, thin across it, which is a lens seen end-on -- and the rings shrink
    up the height on a CURVE and drift backwards on another, converging to a
    point. Nothing in it is parallel to anything else and there is not a right
    angle in the whole shape.

    THE TAPER IS `(1 - t) ** 0.72` AND THE EXPONENT IS THE WHOLE LOOK. At 1.0
    the fin is a straight-sided cone, which is a party hat; under 1 it is
    CONVEX -- full near the base and drawing in quickly near the tip, which is
    the profile every stylised horn, fin and claw is drawn with.

    THE LEAN IS `t ** 1.5`, NOT `t`. A linear lean is a straight fin leaning
    over, which reads as a plank propped against the pig; raised to a power the
    base leaves the body vertically and the tip sweeps back, which is a curve
    and is what an animal grows.
    """
    B = _active[0]
    up = up.normalized()
    a = along.normalized()
    # square the along axis to the up axis, or a fin on the sloping rump shears
    a = (a - up * a.dot(up)).normalized()
    side = a.cross(up).normalized()
    root = base - up * (height * sink)

    RINGS = (0.00, 0.34, 0.66)
    N = 6
    rings = []
    for t in RINGS:
        k = (1.0 - t) ** 0.72
        c = (root + up * (height * t)
             + a * (height * math.sin(lean) * (t ** 1.5)))
        ring = []
        for j in range(N):
            th = math.tau * j / N
            ring.append(B.verts.new(c
                                    + a * (math.cos(th) * length * 0.5 * k)
                                    + side * (math.sin(th) * thick * 0.5 * k)))
        rings.append(ring)
    ctip = (root + up * height
            + a * (height * math.sin(lean)))
    tris = 0
    for r0, r1 in zip(rings, rings[1:]):
        for j in range(N):
            B.faces.new((r0[j], r0[(j + 1) % N], r1[(j + 1) % N], r1[j]))
            tris += 2
    top = rings[-1]
    if blunt > 0.0:
        # A CHISEL END, WHICH IS WHAT MAKES A SPIKE READ AS A SCALE RATHER THAN
        # AS A THORN. A converging tip is right for a dorsal fin and wrong for
        # the small additions on an ear: those want to look like part of the
        # ear's own edge, and anything that comes to a needle reads as a
        # separate sharp object stuck onto it. Capping the top at `blunt` of
        # the base leaves a flat facet the size of a fingernail.
        cap = []
        for j in range(N):
            th = math.tau * j / N
            cap.append(B.verts.new(ctip
                                   + a * (math.cos(th) * length * 0.5 * blunt)
                                   + side * (math.sin(th) * thick * 0.5 * blunt)))
        for j in range(N):
            B.faces.new((top[j], top[(j + 1) % N], cap[(j + 1) % N], cap[j]))
            tris += 2
        B.faces.new(tuple(cap))
        tris += N - 2
    else:
        # THE TIP IS A SHORT EDGE, NOT A POINT. A single apex vertex pulls six
        # triangles into a cone and the fin ends in a needle; two verts a
        # little apart along the spine leave a soft crease, which is what a
        # real fin's trailing edge is.
        t0 = B.verts.new(ctip - a * length * 0.08)
        t1 = B.verts.new(ctip + a * length * 0.06)
        for j in range(N):
            k = (j + 1) % N
            va = t0 if math.cos(math.tau * j / N) < 0 else t1
            vb = t0 if math.cos(math.tau * k / N) < 0 else t1
            if va is vb:
                B.faces.new((top[j], top[k], va))
                tris += 1
            else:
                B.faces.new((top[j], top[k], vb, va))
                tris += 2
    # the base is capped so the fin is a closed solid even where it stands
    # proud of a curved back
    B.faces.new(tuple(reversed(rings[0])))
    tris += N - 2
    _sync()
    return tris


def blit(src, dst, flip=False):
    """Copy one bmesh into another, optionally mirrored in x.

    BUILT ONCE AND MIRRORED, BECAUSE RUNNING THE PLACEMENT TWICE PRODUCED TWO
    DIFFERENT EARS. The ear fins were built by looping `sx` over -1 and +1 and
    negating every x -- which looks symmetric and is not, because the root is
    found by MARCHING A RAYCAST along the ear's rim and stopping when it falls
    off. Where it falls off depends on the ear's own triangulation, and that is
    not perfectly mirrored, so the two roots landed on slightly different spots
    and every fin grew from a different place. Measured: the two pieces had the
    same vertex count and no two vertices matched under a mirror.

    Reported as "compare the two ears, they do not look the same", which is
    exactly what it was. Building the +x side and reflecting it makes the two
    IDENTICAL BY CONSTRUCTION rather than by a placement that happens to agree
    -- the same argument this project makes everywhere for deriving a value
    rather than keeping a second copy of it.

    THE WINDING IS REVERSED ON THE FLIP. A mirror turns a surface inside out,
    so copying the face loops across unchanged would leave one whole side with
    its normals pointing into the pig.
    """
    # KEYED ON THE VERTEX OBJECT, NOT ON `v.index`, AND THAT IS THE WHOLE BUG
    # THIS FUNCTION ALREADY HAD ONCE. A freshly created BMVert carries index
    # -1 until `index_update()` is called -- `ensure_lookup_table()` builds the
    # internal table and does NOT stamp the indices -- so every vert in a
    # just-built bmesh has the same index, the map collapsed to one entry, and
    # every face came back as the same vertex repeated:
    #
    #     ValueError: faces.new(...): found the same (BMVert) used multiple times
    #
    # 188 of 188 faces dropped, leaving 210 loose vertices where the ears
    # should be -- and the build still printed a face count and exited 0,
    # because the exception was being swallowed. A BMVert is hashable, so
    # keying on it needs no indices to be correct at all.
    vmap = {}
    for v in src.verts:
        co = Vector((-v.co.x, v.co.y, v.co.z)) if flip else v.co.copy()
        vmap[v] = dst.verts.new(co)
    tris = 0
    for f in src.faces:
        vs = [vmap[v] for v in f.verts]
        if flip:
            vs.reverse()
        try:
            dst.faces.new(vs)
            tris += len(vs) - 2
        except Exception as e:          # noqa: BLE001 -- reported, not hidden
            # NOT SWALLOWED. A bare `except ValueError: pass` here hid a bug
            # that dropped every copied face and left 210 loose vertices in the
            # mesh -- the kit built, printed a face count, and had no ears.
            blit.failed += 1
            blit.why = "%s: %s" % (type(e).__name__, e)
    return tris


def webbed_fin(base, out, span, length, width, thick, ribs=3, scallop=0.58,
               sink=0.10, rake=0.30):
    """A bat-wing membrane: a fan of ribs with the web SCALLOPED between them,
    and a LENS cross-section so it is a leaf rather than a slab.

    THE FAN RADIATES -- see the loop below -- and the membrane is THICK AT THE
    ROOT AND THIN AT THE RIM, which is the half that stops it reading as
    cardboard. The first version offset two flat shells by a constant, so every
    edge was a square rim and the fin was a plate with a bevel; a real membrane
    swells where it leaves the body and goes to almost nothing at its edge, and
    that one taper is most of what makes it look grown rather than cut.

    A MIDDLE ARC IS WHAT MAKES IT CURVE. Root and rim alone give a flat cone;
    an arc at 55% of the reach, carrying most of the thickness, lets the
    surface bulge and then fall away -- three rings instead of two, and the
    difference between a wedge and a leaf.
    """
    out = out.normalized()
    span = (span - out * span.dot(out)).normalized()
    nor = out.cross(span).normalized()
    B = _active[0]
    root = base - out * (length * sink)
    n = max(2, ribs)
    half = width * 0.5
    dirs, radii = [], []
    for i in range(2 * n - 1):
        t = i / (2 * n - 2.0)
        ang = (t - 0.5) * 2.0 * half
        d = (out * math.cos(ang) + span * math.sin(ang)).normalized()
        # ASYMMETRIC ALONG THE FAN. A wing is long at its leading edge and
        # short at its trailing one; an even fan is a sunburst. 0.26 was
        # too gentle to read as direction at all.
        r = length * (1.0 if i % 2 == 0 else scallop) * (1.0 - 0.42 * t)
        dirs.append(d)
        radii.append(r)

    def arc(f, w):
        pts = []
        for d, r in zip(dirs, radii):
            c = root + d * (r * f) + Vector((0, 1, 0)) * (r * f * rake)
            pts.append((B.verts.new(c + nor * (thick * 0.5 * w)),
                        B.verts.new(c - nor * (thick * 0.5 * w))))
        return pts

    # THE THICKNESS PROFILE. Full at the root, most of it still there at the
    # middle arc, almost nothing at the rim.
    mid = arc(0.55, 0.74)
    rim = arc(1.00, 0.10)
    rt = B.verts.new(root + nor * (thick * 0.5))
    rb = B.verts.new(root - nor * (thick * 0.5))
    m = len(dirs)
    tris = 0
    for i in range(m - 1):
        B.faces.new((rt, mid[i][0], mid[i + 1][0]))
        B.faces.new((rb, mid[i + 1][1], mid[i][1]))
        B.faces.new((mid[i][0], rim[i][0], rim[i + 1][0], mid[i + 1][0]))
        B.faces.new((mid[i][1], mid[i + 1][1], rim[i + 1][1], rim[i][1]))
        B.faces.new((rim[i][0], rim[i][1], rim[i + 1][1], rim[i + 1][0]))
        tris += 8
    for j, sgn in ((0, 1), (m - 1, -1)):
        tri = ((rt, rb, mid[j][1], mid[j][0]) if sgn > 0
               else (rt, mid[j][0], mid[j][1], rb))
        B.faces.new(tri)
        quad = ((mid[j][0], mid[j][1], rim[j][1], rim[j][0]) if sgn > 0
                else (mid[j][0], rim[j][0], rim[j][1], mid[j][1]))
        B.faces.new(quad)
        tris += 4
    _sync()
    return tris


def spike(base, direction, length, thick, sink, segments=1, curl=0.0,
          twist=0.0):
    """A tapered spike, optionally curled -- the flame lick and the ear spike
    are the same builder with different curl.

    CURLED BY BENDING THE AXIS PER SEGMENT rather than by moving the tip. A
    tip-only bend leaves the base pointing the wrong way and the whole thing
    reads as a bent nail; rotating the direction a little at every ring is what
    makes a curve.
    """
    d = direction.normalized()
    x, y, _ = frame(d)
    pos = base - d * sink
    # FIVE SIDES, NOT THREE. A triangular cross-section is the cheapest
    # possible tube and it reads as a BLADE -- three flat faces meeting at
    # three hard edges, which is exactly the boxiness this pass is removing.
    # Five rounds the lick enough to read as a tongue of flame for two extra
    # triangles a segment.
    _NS = 5
    _ang = [math.tau * _k / _NS for _k in range(_NS)]
    ring = [pos + (x * math.cos(a) + y * math.sin(a)) * (thick * 0.5)
            for a in _ang]
    B = _active[0]
    verts = [B.verts.new(p) for p in ring]
    tris = 0
    step = length / segments
    for s in range(segments):
        t = (s + 1.0) / segments
        # rotate the axis a little each segment -- the curl
        d = (d * math.cos(curl / segments)
             + y * math.sin(curl / segments)).normalized()
        x, y, _ = frame(d)
        pos = pos + d * step
        r = (thick * 0.5) * (1.0 - t) ** 0.85
        if s == segments - 1:
            tip = B.verts.new(pos)
            for i in range(_NS):
                B.faces.new((verts[i], verts[(i + 1) % _NS], tip))
            tris += _NS
        else:
            phase = twist * t
            nxt = [B.verts.new(pos + (x * math.cos(a + phase)
                                       + y * math.sin(a + phase)) * r)
                   for a in _ang]
            for i in range(_NS):
                B.faces.new((verts[i], verts[(i + 1) % _NS],
                             nxt[(i + 1) % _NS], nxt[i]))
            verts = nxt
            tris += 2 * _NS
    _sync()
    return tris


# ------------------------------------------------------------- dorsal blades
# THE ONE RAY YOU MUST NOT FIRE IS THE OBVIOUS ONE: STRAIGHT DOWN THE SPINE.
#
# This started as `body.ray_cast((0, y, 3), (0,0,-1))` -- the middle of the
# back, which is exactly where a dorsal ridge goes. THE PIG HAS A COIN SLOT
# THERE. It is a real hole through a real hollow shell (`CLAUDE.md`: "the
# generated shell turns out to be a TRUE HOLLOW MANIFOLD"), so the ray drops
# through it and hits the INSIDE OF THE BOTTOM at z about -0.9. Measured across
# the run:
#
#     y      x=0.00              x=0.16
#     0.120  z=-0.903 n.z=+0.99  z=+0.940     <- through the slot
#     0.495  z=-0.797 n.z=+0.90  z=+0.838     <- through the slot
#     0.557  z=+0.821            z=+0.807     <- past the slot, correct
#
# So SEVEN OF NINE BLADES WERE BUILT INSIDE THE PIG, standing on the floor of
# its own cavity, invisible from every camera.
#
# WHAT MADE IT COST A CYCLE IS THAT THE GUARD REPORTED SUCCESS. `ray_cast`
# returns a hit, so the "0 rays missed" line printed on every build was true
# and meant nothing -- the ray did hit the mesh, just the wrong surface of it.
# A miss would have been loud; a hit on the far side is silent. That is the
# same shape as `make_fur_tufts.py`'s note about seating against a fitted
# ellipsoid, one step nastier, because here the mesh really was consulted.
#
# It also hid behind a half-success: the two blades past the end of the slot
# seated correctly, so the ridge looked SHORT rather than broken, and the first
# two passes were spent making it bigger.
#
# So the fan straddles the slot and takes the highest hit, and anything below
# the waterline is refused outright rather than trusted.
mark("blades", bm)


# THE FAN, WIDE ENOUGH TO CLEAR THE SLOT AND NARROW ENOUGH THAT THE BACK IS
# STILL FLAT ACROSS IT. Measured, z falls 0.016 between x 0.16 and x 0.24, so
# reading the height off-centre and seating the blade back on the centreline is
# accurate to about a hundredth of a unit -- six hundredths of a stud, against
# a base that is buried sixteen per cent of its own height anyway.
FAN_X = (-0.24, -0.16, 0.16, 0.24)


def top_of_back(y):
    """The real top of the back at `y`, or (None, None).

    REFUSES ANY HIT BELOW THE WATERLINE. That is the whole point: a hit at
    negative z is the inside of the shell seen down the coin slot, and taking
    it is how the ridge ended up buried. Refusing loudly beats seating quietly.
    """
    best = None
    for x in FAN_X:
        ok, loc, nor, _ = body.ray_cast(Vector((x, y, 3.0)), Vector((0, 0, -1)))
        if ok and loc.z > 0.0 and (best is None or loc.z > best[0].z):
            best = (loc.copy(), nor.copy())
    if best is None:
        return None, None
    loc, nor = best
    # back onto the centreline -- the ridge runs down the spine, not beside it
    return (Vector((0.0, loc.y, loc.z)),
            Vector((0.0, nor.y, nor.z)).normalized())


_ridge_lo, _ridge_hi = 1e9, -1e9
tris = 0
placed = {"blade": 0, "ear": 0, "wing": 0, "flame": 0}
missed = 0
_seq = ([(r, i, n) for r in BLADES["runs"]
         for i, n in [(i, r[2]) for i in range(r[2])]]
        if "spikes" in WANT else [])
for (_y0, _y1, _n), i, _cnt in _seq:
    t = i / (_cnt - 1.0) if _cnt > 1 else 0.5
    y = _y0 + (_y1 - _y0) * t
    loc, nor = top_of_back(y)
    if loc is not None:
        _ridge_lo = min(_ridge_lo, loc.z)
        _ridge_hi = max(_ridge_hi, loc.z)
    if loc is None:
        missed += 1
        print("  ! no top-of-back at y %.3f -- blade skipped" % y)
        continue
    # stand up rather than lie along the rump -- see BLADES['upright']
    nor = (nor + Vector((0, 0, 1)) * BLADES["upright"]).normalized()
    # the crest: full size in the middle, `end_scale` at both ends
    k = (BLADES["end_scale"]
         + (1.0 - BLADES["end_scale"]) * math.sin(math.pi * t) ** 0.7)
    _n0 = len(bm.verts)
    tris += blade(loc, nor, Vector((0, 1, 0)),
                  BLADES["length"] * k, BLADES["thick"] * k,
                  BLADES["height"] * k, BLADES["lean"], BLADES["sink"])
    # WHAT THE BLADE ACTUALLY REACHES, printed per blade. A ridge is judged on
    # whether it BREAKS THE SILHOUETTE, which is a question about the tip's
    # height against the ear tip at z 1.309 -- and squinting at a render taken
    # from behind cannot answer it, because from there the row is edge-on.
    _tip = max(v.co.z for v in list(bm.verts)[_n0:])
    print("    blade %d  y %+.3f  base z %.3f  tip z %.3f  %s"
          % (i, y, loc.z, _tip, "clears the ears" if _tip > 1.309 else ""))
    placed["blade"] += 1


# ---------------------------------------------------------------- ear fins
def ear_edge(sx, deg):
    """March outward from the ear's centre until the ear stops, and return the
    last point that was still on it plus the outward direction.

    THE EAR'S OUTLINE IS MEASURED, NOT ASSUMED. It is a generated plate and its
    silhouette is not an ellipse -- this walks 1/200ths of a unit outward and
    tests whether a ray fired through that point still hits the ear, which
    answers the question against the actual mesh. Firing along -Y works because
    the pig's ear is a forward-facing plate; a ray along the march direction
    would skim the surface and hit nothing at all.
    """
    ec = Vector((sx * 0.47, -0.36, 0.86))
    a = math.radians(deg)
    out = Vector((sx * math.sin(a), 0.0, math.cos(a))).normalized()
    hit = None
    r = 0.0
    while r < 0.80:
        p = ec + out * r
        got, loc, _n, _i = ears.ray_cast(Vector((p.x, -3.0, p.z)),
                                         Vector((0, 1, 0)))
        if not got:
            break
        hit = Vector((p.x, loc.y, p.z))
        r += 0.005
    return hit, out


mark("ear fins", bm)
# BOTH SIDES ARE BUILT ONCE AND REFLECTED -- see `blit()`. Everything below
# works on the +x side only and goes into `sm`, which is then copied into the
# kit twice, mirrored the second time. That is what makes the two ears
# identical rather than merely intended to be.
sm = bmesh.new()
_active[0] = sm
_group[0] = "ear fins"

for j, deg in enumerate(EAR_FINS["angles"] if "ears" in WANT else ()):
    edge, out = ear_edge(1.0, deg)
    if edge is None:
        missed += 1
        print("  ! no ear rim at %+.0f deg -- spike skipped" % deg)
        continue
    n = len(EAR_FINS["angles"])
    t = j / (n - 1.0) if n > 1 else 0.5
    k = (EAR_FINS["end_scale"]
         + (1.0 - EAR_FINS["end_scale"]) * math.sin(math.pi * t) ** 0.6)
    # raked toward the tail like the ridge is
    grow = (out + Vector((0, 1, 0)) * math.sin(EAR_FINS["sweep"])).normalized()
    # ALONG THE RIM: square to the outward direction, still in the ear's plane,
    # so the spike's length lies along the edge it is decorating and its
    # thickness crosses the ear. A spike whose length pointed across the ear
    # would be a wing, which is the shape this one is explicitly not.
    rim = Vector((-out.z, 0.0, out.x)).normalized()
    blade(edge, grow, rim,
          EAR_FINS["length"] * k, EAR_FINS["thick"] * k,
          EAR_FINS["out"] * k, 0.0, EAR_FINS["sink"],
          blunt=EAR_FINS["blunt"])
    placed["ear"] += 1

# ------------------------------------------------------------------- wings
_group[0] = "wings"
placed["wing"] = 0
ok, loc, nor, _ = body.ray_cast(Vector((3.0, WINGS["y"], WINGS["z"])),
                                Vector((-1, 0, 0))) if "wings" in WANT \
    else (False, None, None, None)
if "wings" not in WANT:
    pass
elif not ok:
    missed += 1
    print("  ! no flank at y %.2f z %.2f -- wing skipped"
          % (WINGS["y"], WINGS["z"]))
else:
    lift = math.radians(WINGS["lift_deg"])
    grow = (nor.normalized() * math.cos(lift)
            + Vector((0, 0, 1)) * math.sin(lift)).normalized()
    webbed_fin(loc, grow, Vector((0, 1, 0)),
               WINGS["length"], math.radians(WINGS["span"]), WINGS["thick"],
               ribs=WINGS["ribs"], scallop=WINGS["scallop"],
               sink=WINGS["sink"], rake=WINGS["rake"])
    placed["wing"] += 1

# and now both sides, from the one build
_active[0] = bm
mark("ears and wings", bm)
blit.failed, blit.why = 0, ""
_want = len(sm.faces) * 2
tris += blit(sm, bm, flip=False)
tris += blit(sm, bm, flip=True)
if blit.failed:
    print("  ! blit dropped %d of %d faces -- %s"
          % (blit.failed, _want, blit.why))
placed["ear"] *= 2
placed["wing"] *= 2
sm.free()

# ---------------------------------------------------------------- tail flame
# OFF THE TAIL'S OWN TIP, found as the vertex furthest along +Y rather than
# read off a bounding box -- the tail curls, so its tip is not at a corner of
# its own box and seating a flame there would hang it in the air behind the
# pig. Same class as measuring a house by its bounds and getting its FX at
# altitude, which `CLAUDE.md` records twice.
mark("tail flame", fm)
_tv = [v.co for v in tail.data.vertices]
tip = max(_tv, key=lambda c: c.y)
for i in range(FLAME["count"] if "flame" in WANT else 0):
    t = i / (FLAME["count"] - 1.0) if FLAME["count"] > 1 else 0.5
    # the middle lick is the tallest; the outer ones fall back and splay
    k = 1.0 - FLAME["falloff"] * abs(t - 0.5) * 2.0
    a = (t - 0.5) * math.tau
    # THE AXIS IS UP, AND IT WAS POINTING AT THE TAIL. The direction was built
    # as `(sin(a)*0.34, sin(lean)+0.55, cos(a)*0.34)` -- and in this frame the
    # dominant component, 0.88, is on Y, which is NOSE-TO-TAIL. So the whole
    # torch fired horizontally backwards out of the tail tip and rendered as a
    # fan of leaves lying on its side. Z is up here; the flame goes up.
    #
    # It hid because the flame was EMISSIVE in every preview: a blown-out
    # yellow silhouette has no shading to say which way anything faces, and
    # from the side a horizontal fan and an upright one occupy a similar patch
    # of screen. It showed the moment the licks were rendered as plain surfaces.
    up = Vector((0.0, math.sin(FLAME["lean"]),
                 math.cos(FLAME["lean"]))).normalized()
    s1 = Vector((1.0, 0.0, 0.0))
    s2 = up.cross(s1).normalized()
    off = s1 * math.cos(a) + s2 * math.sin(a)
    # THE LICKS CONVERGE RATHER THAN FAN: each leans only `splay` off the
    # common axis, so the cluster closes toward a point instead of opening
    # into a hand -- a torch flame is widest a third of the way up.
    d = (up + off * FLAME["splay"]).normalized()
    root = tip + off * FLAME["spread"] + up * 0.06
    tris += spike(root, d, FLAME["height"] * k, FLAME["thick"] * k, 0.05,
                  segments=FLAME["segments"], curl=FLAME["curl"],
                  twist=0.5)
    placed["flame"] += 1

# ------------------------------------------------------------------ the mesh
# NORMALS RECALCULATED BEFORE ANYTHING LEAVES, because six faces per ear were
# pointing INWARD -- measured at 28 of 34 outward. Every builder here creates
# its faces from loops it works out itself, and a loop wound the wrong way
# round is invisible in Blender's own viewport (which shades both sides) and
# is a black hole in an engine that culls backfaces. This is two lines and it
# makes the whole class impossible rather than fixing today's instance.
for _b in (bm, fm):
    bmesh.ops.recalc_face_normals(_b, faces=_b.faces)

me = bpy.data.meshes.new("DragonKit")
bm.to_mesh(me)
bm.free()
kit = bpy.data.objects.new("DragonKit", me)
bpy.context.scene.collection.objects.link(kit)

fme = bpy.data.meshes.new("DragonFlame")
fm.to_mesh(fme)
fm.free()
flame = bpy.data.objects.new("DragonFlame", fme)
bpy.context.scene.collection.objects.link(flame)

# ------------------------------------------------------- the body's own UVs
# UNWRAPPED ON THE BODY'S CYLINDER, WHICH IS WHAT LETS THE KIT WEAR THE SKIN.
# Lifted from `make_fur_tufts.py`, and its reasoning applies here with more
# force than it did there: the whole point of this skin is GLOWING SEAMS
# BETWEEN SCALES, and a blade that is one flat colour is a blank plate stuck on
# a cracked-lava animal. Given the same mapping the body uses, a blade samples
# the same map at the same place and the seams run straight up it.
sys.path.insert(0, os.path.join(D))
import pig_uv   # noqa: E402
pig_uv.check_drift((body, trim), "uv")
_z0, _span = pig_uv.UV_Z0, pig_uv.UV_SPAN
_wrapped = 0
for _me in (me, fme):
    _uvl = _me.uv_layers.new(name="UVMap")
    for _p in _me.polygons:
        _us = []
        for _li in _p.loop_indices:
            _co = _me.vertices[_me.loops[_li].vertex_index].co
            _u = (math.atan2(_co.y, _co.x) / (2.0 * math.pi)) + 0.5
            _uvl.data[_li].uv = (_u, (_co.z - _z0) / _span)
            _us.append((_li, _u, (_co.z - _z0) / _span))
        if max(x[1] for x in _us) - min(x[1] for x in _us) > 0.5:
            _wrapped += 1
            for _li, _u, _vv in _us:
                if _u < 0.5:
                    _uvl.data[_li].uv = (_u + 1.0, _vv)

# FLAT SHADED, like the tufts and like every building in this world. A faceted
# blade catching the sun in three planes is the vocabulary the house rebuild
# settled on; smooth shading would make these read as plastic.
bpy.ops.object.select_all(action='DESELECT')
for _o in (kit, flame):
    _o.select_set(True)
bpy.context.view_layer.objects.active = kit
# SMOOTHED BY ANGLE, WHICH REVERSES `make_fur_tufts.py` DELIBERATELY AND FOR
# THE REASON ITS OWN WOOL PASS GIVES. That file shades its tufts FLAT, on the
# argument that the rest of this world is flat-shaded low poly and a faceted
# tuft catching the sun in three planes is the same vocabulary. True for a
# tuft, which is a lump; false for these, which are TAPERED CURVED forms whose
# whole shape is the curve. Its earlier wool pass says the other half out loud
# -- "fully smooth, a forty-triangle lobe reads as a soft ball" -- and that is
# the look asked for here.
#
# BY ANGLE RATHER THAN FULLY SMOOTH, so the crease where a fin's two flanks
# meet at its leading edge stays a hard line while the flanks themselves round
# off. Fully smooth would melt the silhouette's own edges and the fins would
# read as inflated rubber.
try:
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(52))
except (AttributeError, RuntimeError, TypeError):
    bpy.ops.object.shade_smooth()

_all = list(me.vertices) + list(fme.vertices)
if not _all:
    raise SystemExit("  nothing to build for %s" % ", ".join(sorted(WANT)))
xs = [v.co.x for v in _all]
ys = [v.co.y for v in _all]
zs = [v.co.z for v in _all]
print("")
print("=== DRAGON KIT ===")
print("  %d blades, %d ear fins, %d wings, %d flame licks"
      "   (%d pieces refused a seat)"
      % (placed["blade"], placed["ear"], placed["wing"], placed["flame"],
         missed))
if placed["blade"]:
    print("  ridge seated z %.3f..%.3f -- all above the waterline, so none of"
          " it is inside the shell" % (_ridge_lo, _ridge_hi))
print("  %d verts  %d faces  %d tris"
      % (len(_all), len(me.polygons) + len(fme.polygons), tris))
print("  x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f"
      % (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
print("  uv: cylinder shared with the body, %d faces across the wrap" % _wrapped)

# ------------------------------------------------------- the anchor sweep
# THE TAX GEOMETRY PAYS AND A TEXTURE DOES NOT. A painted scale behind a hat is
# invisible; a BLADE there is a lump inside something a player rolled for.
_ANCHORS = {"hat": Vector((0, 14.15, 0)),
            "eyes": Vector((0, 10.6, 5.9)),
            "back": Vector((0, 11.0, -5.6))}
_bmid = Vector((0.0,
                (min(v.co.y for v in body.data.vertices)
                 + max(v.co.y for v in body.data.vertices)) * 0.5,
                (min(v.co.z for v in body.data.vertices)
                 + max(v.co.z for v in body.data.vertices)) * 0.5))
_body_off = Vector((0.0, 6.62, 0.0835))     # Config.PIGGY_MESH's Body row
_pts = [Vector(((c.co.x - _bmid.x) * SCALE, (c.co.z - _bmid.z) * SCALE,
                -(c.co.y - _bmid.y) * SCALE)) + _body_off for c in _all]
if not _pts:
    print("  (nothing built -- no anchors to check)")
print("")
_bad = 0
for _an, _av in (_ANCHORS.items() if _pts else ()):
    _i = min(range(len(_pts)), key=lambda k: (_pts[k] - _av).length)
    _d = (_pts[_i] - _av).length
    _ok = _d >= ANCHOR_MIN
    _bad += 0 if _ok else 1
    _who = GROUP_AT[_i] if _i < len(GROUP_AT) else "?"
    print("  clearance to the %-4s anchor: %5.2f studs   %-9s  nearest: %s"
          % (_an, _d, "OK" if _ok else "TOO CLOSE", _who))
if _bad:
    print("  ! %d anchor(s) breached -- a player's accessory will clip this"
          % _bad)

# ---------------------------------------------------------------- the export
for _o in (kit, flame):
    _o.select_set(True)
bpy.context.view_layer.objects.active = kit
path = paths.pig("pig_dragon_kit%s.obj" % TAG)
# EXPORTED IN STUDS, NOT BLENDER UNITS. `make_fur_tufts.py` records what the
# raw export cost: the tufts came out 2.04 studs across instead of 12, a sixth
# of the size, which would have imported as a pea and cost an upload to find
# out. Nothing errors either way.
bpy.ops.wm.obj_export(filepath=path, export_selected_objects=True,
                      export_uv=True, export_normals=True,
                      export_materials=False, forward_axis='NEGATIVE_Z',
                      up_axis='Y', global_scale=SCALE,
                      export_triangulated_mesh=True)
print("  exported %s" % os.path.relpath(path, D))

# THE CONFIG BLOCK, PRINTED READY TO PASTE, measured against the BODY's own
# export so the build that changes the mesh is the build that hands over the
# numbers. Carried by hand once on the fur set and went stale across three
# reshapes.
_b = paths.pig("pig_body.obj")
if os.path.exists(_b) and _all:
    _lo, _hi = [1e9] * 3, [-1e9] * 3
    for _line in open(_b, encoding="utf-8", errors="ignore"):
        if _line.startswith("v "):
            _q = _line.split()
            for _i in range(3):
                _c = float(_q[_i + 1])
                _lo[_i] = min(_lo[_i], _c)
                _hi[_i] = max(_hi[_i], _c)
    _T = [(0.0, 6.6200, 0.0835)[_i] - (_hi[_i] + _lo[_i]) / 2.0 for _i in range(3)]
    _fx = [v.co.x * SCALE for v in _all]
    _fy = [v.co.y * SCALE for v in _all]
    _fz = [v.co.z * SCALE for v in _all]
    _ax, _ay, _az = ((min(_fx), max(_fx)), (min(_fz), max(_fz)),
                     (-max(_fy), -min(_fy)))
    print("")
    print("  --- ready for a Config row, once the shape is signed off ---")
    print("  size   = Vector3.new(%.4f, %.4f, %.4f),"
          % (_ax[1] - _ax[0], _ay[1] - _ay[0], _az[1] - _az[0]))
    print("  offset = Vector3.new(%.4f, %.4f, %.4f),"
          % ((_ax[0] + _ax[1]) / 2 + _T[0], (_ay[0] + _ay[1]) / 2 + _T[1],
             (_az[0] + _az[1]) / 2 + _T[2]))

bpy.ops.wm.save_as_mainfile(filepath=paths.pig("pig_dragon%s.blend" % TAG))
print("  saved %s" % os.path.relpath(paths.pig("pig_dragon%s.blend" % TAG), D))

# ------------------------------------------------------------------ a look
if not RENDER:
    print("")
    print("  pass -- --render to shoot it under game light")
    raise SystemExit(0)

# THE LIGHTING NUMBERS ARE `make_view_blend.py`'S AND ARE COPIED HERE, WHICH IS
# A DUPLICATE AND IS FLAGGED AS ONE. That file reads them out of `WorldService`
# and is the right home for them; it cannot be imported, because it is a script
# that opens a blend and renders on import rather than a module. The honest fix
# is to lift the rig into the toolkit -- not done here, because the toolkit is
# shared with other sessions and this is a look-at-it script rather than
# something that ships. If these two ever disagree, that file is right.
SUN_ELEV, SUN_AZI = 50.9, -74.8
SUN_RGB, SKY_RGB, GRASS_RGB = (255, 243, 210), (88, 100, 132), (82, 114, 60)
BRIGHTNESS, EXPOSURE, DIFFUSE_SCALE = 2.4, -0.04, 0.50


def srgb(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lin(t):
    return tuple(srgb(v) for v in t)


scene = bpy.context.scene

# The joined `Trim` and the four split parts are the SAME surface stacked in
# the same space, and leaving both in flickers. `make_view_blend.py` records
# this; the raycasts above needed the split parts, so they go now rather than
# at the top.
for n in ("NostrilPreview", "Snout", "Ears", "Legs", "Tail"):
    o = bpy.data.objects.get(n)
    if o:
        bpy.data.objects.remove(o, do_unlink=True)


def flat_mat(name, rgb, rough=0.85, emit=None, strength=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = lin(rgb) + (1.0,)
    b.inputs["Roughness"].default_value = rough
    if "Specular IOR Level" in b.inputs:
        b.inputs["Specular IOR Level"].default_value = 0.08
    if emit:
        b.inputs["Emission Color"].default_value = lin(emit) + (1.0,)
        b.inputs["Emission Strength"].default_value = strength
    return m


# A BLOCKING MATERIAL, NOT THE SKIN. Nothing here is baked yet -- this is the
# shape being judged, so the pig gets the basalt the molten skin will sit on
# and the kit gets the same, which is the honest preview of a dark dragon. The
# flame is the one emissive thing, because a flame that is not lit is a horn.
# THE KIT IS TINTED AGAINST THE PIG, WHICH IS A SHAPE CHECK AND NOT THE SKIN.
# The first preview painted both a realistic basalt -- body (46,40,44), kit
# (38,33,37) -- and the dorsal ridge VANISHED from the spine shot. It was there
# the whole time and it was eight points of luminance from the thing behind it.
# `CLAUDE.md` has the rule and the trick: tint the parent a colour nothing else
# uses, because that is what separates "not drawn" from "drawn and invisible
# against its neighbour" in one screenshot. Same family as the shop's white
# window, where four innocent suspects were chased before anybody tinted it.
#
# So the pig stays dark and the kit is a pale warm stone. It still reads as a
# dark dragon and the plates can actually be judged, which is the only thing
# this render is for.
def sheet_mat(name, png, glow=None):
    """The real baked skin, so the geometry is judged in the clothes it will
    wear rather than in blocking grey.

    THE KIT WEARS IT FOR FREE, AND THAT IS THE UV WORK ABOVE PAYING OUT. Every
    blade, fin and lick is unwrapped on the BODY'S OWN CYLINDER, so it samples
    `dragon_body_color.png` at the same place the body does -- the molten seams
    run straight up a blade with nothing to author. Give the kit its own flat
    colour instead and it is a blank plate stuck on a cracked-lava animal,
    which is exactly why `make_fur_tufts.py` had to unwrap the mane this way
    before the leopard could wear one.
    """
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.86
    if "Specular IOR Level" in b.inputs:
        b.inputs["Specular IOR Level"].default_value = 0.08
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(png, check_existing=True)
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    if glow is not None:
        # THE SEAMS ARE EMISSIVE, WHICH IS WHAT THE GAME ANIMATES. The skin's
        # alpha pass is 0 exactly on the burning seams -- `make/bake_alpha.py`
        # writes it for `ClientMain`'s animator -- so INVERTING it gives the
        # mask of what should glow. This is a still of one frame of something
        # that pulses in game; it is here so the geometry can be judged lit.
        a = nt.nodes.new("ShaderNodeTexImage")
        a.image = bpy.data.images.load(glow, check_existing=True)
        a.image.colorspace_settings.name = "Non-Color"
        inv = nt.nodes.new("ShaderNodeInvert")
        nt.links.new(a.outputs["Color"], inv.inputs["Color"])
        mul = nt.nodes.new("ShaderNodeMixRGB")
        mul.blend_type = 'MULTIPLY'
        mul.inputs[0].default_value = 1.0
        # AND IT IS A LOW STRENGTH ON PURPOSE. The first go ran 5.0 and the pig
        # came back a YELLOW BLOWOUT -- the seams are already hot IN THE COLOUR
        # SHEET, which is how `make_view_blend.py` renders every other skin, so
        # emission on top is a second helping of the same thing. `CLAUDE.md`
        # records the identical mistake four times over on Neon parts: a pale
        # emissive on a twelve-stud body is a white hole rather than a glowing
        # pig, and the fix is always a deeper colour at a lower level.
        mul.inputs[2].default_value = (1.0, 0.22, 0.03, 1.0)
        nt.links.new(inv.outputs["Color"], mul.inputs[1])
        nt.links.new(mul.outputs[0], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = 1.15
    return m


# THE REAL SKIN IF IT HAS BEEN BAKED, THE BLOCKING GREY IF NOT. `skins/dragon/`
# already carries a molten scale bake with burning seams, built before this
# kit existed -- so the honest preview is the geometry in that skin, and the
# grey is only the fallback for a tree that has not run the bake.
_dc = paths.skin_map("dragon", "body")
_dt = paths.skin_map("dragon", "trim")
_da = os.path.join(paths.skin_dir("dragon"), "dragon_body_alpha.png")
_ta = os.path.join(paths.skin_dir("dragon"), "dragon_trim_alpha.png")
# GREY BY DEFAULT AND DRESSED ONLY ON REQUEST, WHICH IS THE OPPOSITE OF WHAT
# THIS STARTED AS AND IS THE RIGHT WAY ROUND FOR A GEOMETRY LOOP.
#
# Once the baked dragon skin went on, every shape in the kit was covered in the
# same high-contrast lava crazing as the body -- and a webbed fin under a
# cracked-lava texture is CAMOUFLAGE. A pass spent judging wing shapes through
# it got nowhere, because the thing that reads in that picture is the pattern
# and the thing being judged is the silhouette.
#
# It is the tint rule from `CLAUDE.md` one step along: tinting the kit against
# the body was what made the ridge visible at all, and dressing them BOTH in
# the same busy sheet undoes it. So `--skinned` is there for the "how will it
# look" question and plain grey is the default for "what shape is it".
SKINNED = ("--skinned" in argv
           and os.path.exists(_dc) and os.path.exists(_dt))
print("  preview: %s" % ("the baked dragon skin" if SKINNED
                         else "grey, for judging shape (--skinned to dress it)"))

rock = flat_mat("basalt", (54, 47, 52))
for ob in (body, trim):
    ob.data.materials.clear()
kit.data.materials.clear()
if SKINNED:
    body.data.materials.append(sheet_mat("dragon_body", _dc,
                                         _da if os.path.exists(_da) else None))
    trim.data.materials.append(sheet_mat("dragon_trim", _dt,
                                         _ta if os.path.exists(_ta) else None))
    # the kit shares the BODY sheet -- it is unwrapped on the body's cylinder
    kit.data.materials.append(sheet_mat("dragon_kit", _dc,
                                        _da if os.path.exists(_da) else None))
else:
    body.data.materials.append(rock)
    trim.data.materials.append(rock)
    kit.data.materials.append(flat_mat("dragon_rock", (156, 132, 128)))
# THE ONE EMISSIVE THING. `Config.SKINS.magma` is Neon at glow 2.2 over a
# (150,32,18)..(255,148,44) palette, so this is that palette's hot end -- a
# blocking stand-in for what the molten skin will drive, not a decision about
# it. Without it the licks are dark spikes and their shape cannot be judged.
flame.data.materials.clear()
# EMISSIVE ONLY WHEN DRESSED. In shape mode the flame is a plain surface like
# everything else, because a lit one renders as a FLAT SILHOUETTE -- pure
# yellow, no shading, no facets -- and its geometry cannot be judged at all.
# That is the texture problem again in a third costume: the first time it was
# dark-on-dark, then the lava crazing, now its own glow. Anything that stops
# light describing a surface stops the surface being judgeable.
if SKINNED:
    flame.data.materials.append(flat_mat("dragon_flame", (255, 148, 44),
                                         rough=0.5, emit=(255, 120, 30),
                                         strength=6.0))
else:
    flame.data.materials.append(flat_mat("flame_shape", (176, 150, 132)))

eye = bpy.data.objects.get("EyePreview")
if eye:
    eye.data.materials.clear()
    eye.data.materials.append(flat_mat("eye", (255, 176, 64),
                                       rough=0.4, emit=(255, 150, 40),
                                       strength=4.0))

bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, -1.02))
ground = bpy.context.active_object
ground.data.materials.append(flat_mat("lawn", GRASS_RGB, rough=0.95))

w = bpy.data.worlds.new("sky")
scene.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = lin(SKY_RGB) + (1.0,)
w.node_tree.nodes["Background"].inputs[1].default_value = DIFFUSE_SCALE

sd = bpy.data.lights.new("sun", type='SUN')
sd.energy = BRIGHTNESS
sd.color = lin(SUN_RGB)
sd.angle = math.radians(0.35 * 12.0)
sun = bpy.data.objects.new("Sun", sd)
scene.collection.objects.link(sun)
_el, _az2 = math.radians(SUN_ELEV), math.radians(SUN_AZI)
_d = Vector((math.sin(_az2) * math.cos(_el), -math.cos(_az2) * math.cos(_el),
             math.sin(_el)))
sun.location = _d * 20.0
sun.rotation_euler = (-_d).to_track_quat('-Z', 'Y').to_euler()

scene.render.engine = 'BLENDER_EEVEE'
scene.view_settings.view_transform = 'Standard'
scene.view_settings.exposure = EXPOSURE
scene.render.resolution_x = scene.render.resolution_y = 700

cd = bpy.data.cameras.new("view")
cd.lens = 62
cam = bpy.data.objects.new("View", cd)
scene.collection.objects.link(cam)
scene.camera = cam


def point_at(o, t):
    o.rotation_euler = (Vector(t) - o.location).to_track_quat('-Z', 'Y').to_euler()


# THE SAME FOUR ANGLES THE SKINS ARE JUDGED ON, so this sheet can be laid
# beside a reference or beside another skin's and compared. The grazing ones
# are the point: a dorsal ridge is read from BEHIND and a fin from the side.
SHOTS = (("hero",  (-3.9, -5.4, 2.0),  (0, -0.05, 0.05)),
         ("crown", (-1.2, -3.4, 4.6),  (0, -0.10, 0.70)),
         ("spine", (0.2, 3.6, 4.4),    (0, 0.10, 0.70)),
         ("low",   (-2.4, -4.6, 0.15), (0, -0.05, 0.35)),
         # A FIFTH SHOT THE SKINS DO NOT NEED AND THIS DOES. The four above are
         # tuned for a PATTERN, where the grazing angles are what expose an
         # unwrap; a dorsal ridge is a SILHOUETTE, and the four of them see it
         # end-on, foreshortened, or from above. Two passes were spent making
         # the blades bigger because the only view of them was the spine shot,
         # where nine plates in a row overlap into one strip whatever size they
         # are. Broadside is where a dragon is read.
         ("side",  (-7.2, 0.15, 1.5),  (0, 0.15, 0.55)))
# ------------------------------------------------------- the parts, alone
# A PIECE THIS SIZE CANNOT BE JUDGED ON THE ANIMAL, which took three passes to
# admit. An ear fin is about 0.6 units on a 2-unit pig shot from 7 units away,
# so it is forty pixels of a 700-pixel frame -- and at forty pixels a scalloped
# fan and a flat slab are the same picture. Two passes were spent tuning a
# scallop that was rendering four pixels deep.
#
# `--parts` throws the pig away and frames the kit, which is the only view that
# can answer "is this the shape I think I built". The same argument as the
# tint: it is about being able to SEE the thing before believing anything about
# it.
if "--parts" in argv:
    for _n in ("Body", "Trim", "EyePreview", "Lawn"):
        _o = bpy.data.objects.get(_n)
        if _o:
            bpy.data.objects.remove(_o, do_unlink=True)
    _vs = [v.co for o in (kit, flame) for v in o.data.vertices]
    _c = Vector((sum(v.x for v in _vs) / len(_vs),
                 sum(v.y for v in _vs) / len(_vs),
                 sum(v.z for v in _vs) / len(_vs)))
    _r = max((v - _c).length for v in _vs)
    for _nm, _dir in (("front", Vector((0, -1, 0.15))),
                      ("side", Vector((-1, 0, 0.15))),
                      ("top", Vector((-0.35, -0.35, 1))),
                      ("q34", Vector((-0.8, -0.7, 0.35)))):
        cam.location = _c + _dir.normalized() * (_r * 3.1)
        point_at(cam, _c)
        scene.render.filepath = paths.render("dragonparts_%s.png" % _nm)
        bpy.ops.render.render(write_still=True)
        print("  parts %s" % _nm, flush=True)
    raise SystemExit(0)

# ---------------------------------------------- close-ups on the piece
# FRAMED ON WHAT WAS ACTUALLY BUILT, with the pig left in for scale. A spike
# is only right RELATIVE TO THE ANIMAL, so an isolated render answers "what
# shape is this" and a framed one answers "is it the right size" -- and those
# are the two questions a piece pass has.
if TAG:
    _kv = [v.co for o in (kit, flame) for v in o.data.vertices]
    _c = Vector((sum(v.x for v in _kv) / len(_kv),
                 sum(v.y for v in _kv) / len(_kv),
                 sum(v.z for v in _kv) / len(_kv)))
    _r = max(0.35, max((v - _c).length for v in _kv))
    for _nm, _dir in (("side", Vector((-1, 0, 0.10))),
                      ("front", Vector((-0.25, -1, 0.18))),
                      ("q34", Vector((-0.85, -0.62, 0.42))),
                      ("rear", Vector((0.15, 1, 0.30)))):
        cam.location = _c + _dir.normalized() * (_r * 4.6)
        point_at(cam, _c)
        scene.render.filepath = paths.render("piece%s_%s.png" % (TAG, _nm))
        bpy.ops.render.render(write_still=True)
        print("  piece %s %s" % (TAG.strip("_"), _nm), flush=True)
    raise SystemExit(0)

for name, loc, aim in SHOTS:
    cam.location = Vector(loc)
    point_at(cam, aim)
    scene.render.filepath = paths.render("dragon_%s.png" % name)
    bpy.ops.render.render(write_still=True)
    print("  rendered %s" % name, flush=True)
