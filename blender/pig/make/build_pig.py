# -*- coding: utf-8 -*-
# A cute cartoon piggy bank, built as TWO OBJECTS from the first vertex:
#   Body  -- the plump shell
#   Trim  -- ears, snout, legs, tail
# so the second tone every skin is authored in has something to paint by
# construction, rather than being cut out of a blended shell afterwards.
#
# Blender convention kept from the existing pipeline: +Z up, -Y is the SNOUT,
# +Y is the tail and the vault. The OBJ exporter (forward -Z, up Y) then puts
# the snout on OBJ +Z, which is what Config's half-turn is solved against.

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
OUT = _root

import paths   # noqa: E402 -- the one place that knows the layout

import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

OUT = os.path.dirname(os.path.abspath(__file__))
# BLENDER DOES NOT PUT THE SCRIPT'S OWN DIRECTORY ON THE PATH when it is run
# with `--python`, so a sibling module is not importable without this line.
if OUT not in sys.path:
    sys.path.insert(0, OUT)
import pig_uv


# ============================================================
# PROPORTIONS -- everything cute lives in this block
# ============================================================
BODY_RX, BODY_RY, BODY_RZ = 1.00, 1.08, 0.96   # half width / depth / height
BODY_SUB = 4                                    # quad-sphere subdivisions

SNOUT_R      = 0.48      # face radius -- this is most of the cuteness
SNOUT_BACK_FLARE = 1.20  # the back is WIDER, so it merges instead of butting
SNOUT_DEPTH  = 0.58      # a FLOOR; the real depth is solved below
SNOUT_BURY   = 0.88      # how far inside the skin the back rim has to finish
SNOUT_OUT    = 0.24      # how far its face stands proud of the body
SNOUT_Z      = -0.09     # below the middle of the face
SNOUT_LIFT   = 12.0      # degrees NOSE UP -- verified, not assumed

NOS_RX, NOS_RY, NOS_RZ = 0.115, 0.17, 0.150   # nostril dimple cutter
NOS_DX       = 0.175     # each side of centre
NOS_SINK     = 0.11      # how deep the dimple bites
NOS_Z        = 0.01      # nostril height within the snout's own face
# THE MUZZLE'S FRONT IS DENSIFIED AFTER THE NOSTRILS ARE CUT, and this is the
# fix for something that was blamed on the nostrils twice before it was
# measured.
#
# Reported as "the nose is not all the way smooth -- on the left of each
# nostril a line going up, on the right a line going down". The obvious
# suspect is the nostril RIM, which the boolean does leave at 76 to 79
# degrees; two attempts went into rounding it, and both failed instructively.
# Clamped, the bevel collapsed and the rim came back byte-identical while
# leaving 340 zero-area faces; unclamped, it self-intersected and produced
# actual black cracks. A bevel on a boolean SEAM has sliver triangles either
# side of it and there is no width that is both safe and visible.
#
# THEN THE MUZZLE WAS MEASURED INSTEAD OF ARGUED ABOUT, and the streak is not
# the nostril at all -- it is in renders taken before the rim was ever
# touched. `primitive_cone_add` closes a cone with a single n-gon, and the
# EXACT boolean solver merges coplanar output back into n-gons too, so the
# muzzle's front was TWO faces of 79 and 61 vertices covering 58% of it
# between them. Their corner normals disagree by 20.4 degrees -- pulled round
# by the bevel on the muzzle's rim -- and there is not one interior vertex
# anywhere to correct that, so the renderer interpolates the disagreement
# straight across a surface that is geometrically perfectly flat, along
# whatever triangulation it happens to pick. That is the diagonal.
#
# A FLAT FACE STILL NEEDS VERTICES, WHICH IS THE COUNTER-INTUITIVE PART. There
# is no curvature to capture, so a big n-gon looks like free economy; what the
# vertices are actually for is DILUTING a boundary condition, and without them
# a rim's normals reach the middle of the face undiminished.
MUZZLE_POKES = 2         # rounds of fanning the muzzle's big flat faces

# Broad rounded triangles rather than horns. EAR_TAPER is the whole
# difference: at 0.86 the tip pulls to a spike, at 0.62 it stays a wide
# rounded blade, which is what the reference has.
# THE TIP ANGLE PICKS THE TAPER, rather than the taper being eyeballed and
# the tip landing wherever it lands. The silhouette edges meet at
#     apex = 180 - 2 * atan((EAR_BASE_R - EAR_TIP_R) / EAR_H)
# so asking for a 130-degree tip fixes the side slope at 25 degrees, and once
# the base width and the height are chosen the tip radius is solved, not
# picked. The build prints the apex back so it cannot drift unnoticed.
EAR_BASE_R   = 0.52      # cone base radius -- half the ear's width
EAR_TIP_R    = 0.17      # solved: gives a 129.4-degree tip
EAR_H        = 0.74      # cone depth, base to tip
EAR_T        = 0.44      # full front-to-back thickness after flattening
EAR_BEVEL    = 0.16      # what rounds the tip and the base
EAR_X, EAR_Y, EAR_Z = 0.45, -0.36, 0.94
EAR_OUT      = 23.0      # degrees leaning outward
EAR_BACK     = 0.0       # the BEND below does the leaning now
DISH_INSET   = 0.80      # cutter size vs the ear -- what is left is the rim
DISH_DEPTH   = 0.24      # how deep the scoop bites into a 0.38-thick ear
DISH_Z       = -0.02     # nudged down, so the rim is thicker at the tip
# HOW FINELY THE EAR IS BUILT, AND WHY IT IS NOT THE 40 EVERYTHING ELSE USES.
# The ear is the one piece here that gets SQUASHED after it is made -- a round
# cone flattened to `flat_k` of its depth -- and a squash does not spread its
# cost evenly. On the resulting ellipse the facets bunch up at the blade's
# LEADING AND TRAILING EDGES: measured, the turn between neighbours there is
# the round cone's own step divided by `flat_k`, so 40 sides at 0.42 thickness
# is a 21-degree break running the whole length of both edges of the ear, and
# the bevel at the front face steps 28 degrees at its worst.
#
# Neither is steep enough to be MARKED sharp at `SMOOTH_ANGLE`, which is what
# made this hard to see for what it was: nothing is creased, the surface just
# turns a long way in one face width, and smooth shading over that reads as
# banding rather than as an edge. Sixty-four sides and eight bevel steps take
# the two worst numbers to about 13 and 19 degrees.
EAR_SIDES    = 64        # cone sides, before the flatten bunches them up
EAR_BEV_SEG  = 8         # steps rounding the ear's own rim
DISH_BEV_SEG = 8         # steps rounding the scoop's floor
# AND THE LIP IS ROUNDED AFTER THE CUT, WHICH IS THE ONLY MOMENT IT EXISTS.
# Where the scoop breaks out through the front of the ear the two surfaces
# genuinely cross at 44 to 58 degrees -- measured on nine separate edges up
# the length of the ear -- and that is a fact about the boolean rather than
# about the tessellation, so no amount of extra geometry touches it. It got
# marked sharp and read as a knife line drawn round the inside of the ear.
# A real ear's scoop turns into a FOLD, so the rim is beveled once the cut has
# made it. 0.04 against a rim about 0.10 wide leaves well over half of it flat.
DISH_LIP     = 0.04      # round-over on the scoop's rim, cut into the rim itself
EAR_BEND_FWD = 11.0      # degrees the tip flops forward, base stays square
EAR_CURL_IN  =  7.0      # degrees the tip curls toward the other ear

LEG_R, LEG_H = 0.22, 0.50
LEG_X        = 0.50
LEG_Y_FRONT  = -0.48
LEG_Y_BACK   = 0.54
LEG_BOTTOM   = -1.02     # the ground line

TAIL_MAJOR, TAIL_MINOR = 0.17, 0.090
TAIL_TURNS   = 1.15
TAIL_TRAVEL  = 0.55      # how far the curl winds out from the rump
# TAIL_Y IS WHERE THE CURL STARTS, AND IT HAS TO BE INSIDE THE PIG. The rump
# surface behind the tail sits at y 0.92 to 1.06 depending on height, and the
# curl was starting at 1.02 -- so it hung a tenth of a stud clear of the body
# and read as a spring lying against the rump rather than a tail growing out
# of it. Started inside, the first part of the helix is buried and the tail
# emerges as it winds, which is what attaches it.
# AND IT HAS TO CLEAR THE VAULT DOOR, WHICH IS THE CONSTRAINT THAT ACTUALLY
# SETS IT. The hatch is not ours to move -- `dialCFrame` fixes it in world
# space -- and at the first seat the tail crossed the bore outright: 72 points
# standing inside the opening, and its closest approach to the dial's axis was
# 0.95 studs against a GOLD plate of 1.95, so every one of the four lock tiers
# would have driven a disc straight through the curl. Nothing about that is
# visible until somebody buys a lock.
#
# Solved by sweeping the seat against the tail's own points rather than nudged
# by eye: up 0.16 and forward 0.04 puts the whole curl outside the widest
# plate the vault can ever show, with the root still a comfortable depth
# inside a rump that is falling away fast this far back.
TAIL_Y, TAIL_Z = 0.86, 0.46   # where the curl crosses out of the rump
TAIL_INWARD_TURNS = 0.50      # turns run INTO the body, hiding the root cap
TAIL_STEPS   = 36        # triangle budget: this is the priciest piece
TAIL_TUBE_TAPER   = 0.45  # how much thinner the tube gets toward the tip
TAIL_CURL_TIGHTEN = 0.30  # how much the spiral closes up toward the tip
# THE ROOT FLARES INTO THE RUMP. A spin about +Y sets off along +X, and the
# body's outward normal back there is +Y -- so the tube leaves TANGENTIALLY
# and grazes the shell rather than emerging from it, and a grazing cylinder
# through a sphere cuts a long thin crescent. That is the half-moon at the
# base. Flaring the first rings makes the tail's surface meet the body's at a
# shallow angle instead of a hard one, which is what a fillet is.
TAIL_ROOT_FLARE   = 1.25  # root radius as a multiple of the tube's
TAIL_ROOT_SPAN    = 0.16  # fraction of the curl the flare fades out over

EYE_R        = 0.105
EYE_DIR      = (0.315, -0.88, 0.36)   # direction from the body centre
EYE_PROUD    = 0.60                   # fraction of the ball left showing

# ============================================================
# THE GAME'S OWN NUMBERS -- copied, never re-invented
# ============================================================
# Everything in this block is a fact about `PiggyBank.luau` rather than about
# this pig, and it is here so THE OPENINGS ARE CUT WHERE THE GAME ALREADY
# LOOKS rather than where they happen to look right. A hatch a quarter of a
# stud off the dial's own axis is a lock plate sitting beside its own hole,
# and nothing would error.
GAME_BODY_R  = 6.0       # PiggyBank.BODY_R
GAME_BODY_Y  = 8.5       # PiggyBank.BODY_Y -- the ball's centre
GAME_DIAL_Y  = 6.6       # PiggyBank.DIAL_Y
GAME_VAULT_R = 1.43      # LOCK_TIERS[1].radius 1.55 - VAULT_COVER 0.12
GAME_SLOT_W  = 0.7       # the Slot part's own width  (studs)
GAME_SLOT_L  = 4.2       # the Slot part's own length (studs)
GAME_LAWN_Y  = 0.5       # the plot slab the feet stand on

# ---------------------------------------------------------------- UV RANGE
# THE SHEET'S HEIGHT RANGE LIVES IN `pig_uv.py`, WHICH IS THE ONLY PLACE IT IS
# DECIDED. Three scripts unwrap on this cylinder and a constant copied into
# each of them is the duplicate that drifts -- see that file for why it is
# pinned rather than measured, and what it buys.

# ONE SCALE, AND IT IS DERIVED RATHER THAN FITTED. `BODY_R` is 6 and BODY_RX
# is 1.00, so a scale of 6.0 makes the sphere the whole of PiggyBank is solved
# against -- the dial's frame, the leg reach, and the ball `applyPattern`
# seats every spot and stripe on -- LITERALLY TRUE of this body rather than
# approximately true of a generated blob. The semi-axes come out 6.00 / 6.48 /
# 5.76 studs against that 6, where the shipped body missed it by up to 2.2.
SCALE = GAME_BODY_R / BODY_RX

# Wall thickness of the shell, in studs. It is only ever seen edge-on at the
# two openings, which is exactly what it is for.
WALL = 0.30

# THE SLIT IS SHORTER THAN THE PART IT CAME FROM, AND IT IS FREE TO BE.
# GAME_SLOT_L is the retired `Slot` primitive's own length, which was the
# honest place to START -- but that part is built and then destroyed by
# `swapToMesh`, and nothing in the game reads its size, so it is a reference
# rather than a constraint. Trimmed a quarter off the TAIL end with the front
# edge held, which is what keeps it clear of the curl: the gap from the slit's
# back end to the tail root goes from 0.96 studs to 2.01.
SLOT_FRONT = 0.00  # where the slit begins, just behind the ears
SLOT_TRIM  = 0.75  # fraction of the retired Slot part's length
# HOW FAR THE HATCH CUTTER REACHES, IN AND OUT, AS TWO NUMBERS RATHER THAN A
# DEPTH AND AN OFFSET. Written as a depth it was 0.45 with the cutter's centre
# nudged out -- which put 0.33 of it in the AIR and only 0.12 into the pig,
# the opposite of what the comment beside it claimed, and left the hole with a
# sliver of shell across the top of it.
#
# IT MISSED BY TWO THOUSANDTHS. The hatch sits close to the rear pole, so on
# the upper side of the bore the surface curves round and away much faster
# than a straight cylinder follows it: measured, the outer skin there is 0.072
# below the hatch's own tangent plane and the inner wall is at 0.122, against
# a cutter that stopped at 0.120. The cut ended in a flat annular floor
# instead of breaking through, which is exactly the "thin layer" it looked
# like.
#
# INWARD IS THE CHEAP DIRECTION AND IT IS FREE TO BE GENEROUS: everything past
# the wall is the cavity, and the far side of the pig is nearly two units
# away. Outward only has to clear the skin.
HATCH_IN  = 0.40   # how far past the skin the cutter reaches, into the hollow
HATCH_OUT = 0.15   # how far it stands off the skin before it starts

# ============================================================

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def quad_sphere(name, sub=BODY_SUB):
    """A spherified cube: round, no poles, all quads -- booleans behave.

    SIMPLE subdivision then the analytic cube-to-sphere mapping, NOT
    Catmull-Clark then normalise. Catmull-Clark rounds the cube before the
    snap, so the quads end up much denser near the old corners -- which
    smooth-shades as visible contour bands across the flank. The mapping
    below keeps them near-uniform, and the bands go.
    """
    bpy.ops.mesh.primitive_cube_add(size=2)
    ob = bpy.context.active_object
    ob.name = name
    m = ob.modifiers.new("sub", 'SUBSURF')
    m.subdivision_type = 'SIMPLE'
    m.levels = m.render_levels = sub
    bpy.ops.object.modifier_apply(modifier="sub")
    for v in ob.data.vertices:
        x, y, z = v.co
        x2, y2, z2 = x * x, y * y, z * z
        v.co = Vector((
            x * math.sqrt(max(0.0, 1.0 - y2 / 2 - z2 / 2 + y2 * z2 / 3)),
            y * math.sqrt(max(0.0, 1.0 - z2 / 2 - x2 / 2 + z2 * x2 / 3)),
            z * math.sqrt(max(0.0, 1.0 - x2 / 2 - y2 / 2 + x2 * y2 / 3)),
        ))
    return ob


def scale_verts(ob, sx, sy, sz):
    for v in ob.data.vertices:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z *= sz


def ellipsoid_surface(d, rx, ry, rz):
    """Point where direction d leaves the ellipsoid, and the direction."""
    d = Vector(d).normalized()
    t = 1.0 / math.sqrt((d.x / rx) ** 2 + (d.y / ry) ** 2 + (d.z / rz) ** 2)
    return d * t, d


def apply_all(ob):
    """Bake the object's transform into its mesh.

    IT HAS TO SELECT, NOT ONLY ACTIVATE, and this silently did neither for
    half the pig. `transform_apply` works on the SELECTION; setting only the
    active object leaves it applying to whatever happened to be selected --
    which after a boolean is nothing at all, because the cutter it selected
    has just been deleted. So the snout and the ears kept their rotation in
    their object matrix.

    The exported geometry was right the whole time (the OBJ writer bakes
    matrices, and `join` transforms into the active object's space), so
    nothing anybody looked at was wrong. What WAS wrong is every measurement
    printed off `v.co` afterwards -- the snout's buried-rim check and the
    tail clearance the cape anchor is solved against were both reading local
    coordinates as though they were world ones. A measurement against a model
    of a thing is not a measurement of the thing.
    """
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def bevel_rims(ob, width, segments=6, angle=40.0, clamp=True):
    """Round every edge sharper than `angle`.

    `clamp` IS THE ONE ARGUMENT WORTH EXPLAINING, and it exists because a
    bevel on a BOOLEAN SEAM silently does nothing. Blender's overlap clamp
    limits each bevel to what its neighbouring faces can afford -- sane on
    authored geometry, and fatal along an intersection curve, where a boolean
    leaves sliver triangles a fraction of a stud wide. Measured on the nostril
    rim: asked for 0.022 and then for 0.007, the rim came back BYTE-IDENTICAL
    both times -- same coordinates, same 78-degree angles -- while the
    collapsed bevel left hundreds of zero-area faces behind it.

    So a seam bevel passes `clamp=False` and buys its safety with WIDTH
    instead: a few thousandths cannot self-intersect anything, and it is all a
    rim needs to stop being a drawn line.
    """
    m = ob.modifiers.new("bev", 'BEVEL')
    m.width = width
    m.segments = segments
    m.limit_method = 'ANGLE'
    m.angle_limit = math.radians(angle)
    m.use_clamp_overlap = clamp
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier="bev")


def clean_mesh(ob, dist=2e-4):
    """Weld coincident vertices and drop faces with no area.

    BOOLEANS AND BEVELS BOTH LEAVE DEBRIS, and a zero-area face is the one
    piece of it that cannot be shaded at all: its normal is a cross product of
    two parallel edges, so it is arbitrary, and the smooth-shading pass then
    averages that arbitrary direction into every vertex it touches. Measured
    on the ear after its rim was rounded -- six faces of area 0.0000000 pinched
    at a single point near the tip, reporting dihedral angles of 167 to 180
    degrees against their neighbours, which is a fan of nothing.

    It costs one pass and it is worth running on anything that has been through
    a boolean, which here is both halves of the pig.
    """
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    before = len(bm.faces)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=dist)
    bmesh.ops.dissolve_degenerate(bm, dist=dist, edges=bm.edges[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    gone = before - len(bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return gone


def poke_flat(ob, direction, rounds=2, min_share=0.004):
    """Fan the big flat faces pointing `direction` into triangles.

    `bmesh.ops.poke` puts a new vertex at a face's centre and fans to it, so a
    single 79-sided n-gon becomes 79 triangles WITH an interior vertex that
    carries the face's own normal. Two rounds is enough to stop a rim's tilted
    normals reaching the middle of a face.

    Only faces above `min_share` of the region are touched, so the small
    triangles the boolean already left along the seam are not multiplied for
    nothing. Returns the largest face's share before and after, because "did
    this help" is that number and nothing else.
    """
    def region():
        return [p for p in ob.data.polygons if p.normal.dot(direction) > 0.85]

    faces = region()
    total = sum(p.area for p in faces) or 1.0
    before = max((p.area for p in faces), default=0.0) / total

    for _ in range(rounds):
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bm.faces.ensure_lookup_table()
        tot = sum(f.calc_area() for f in bm.faces
                  if f.normal.dot(direction) > 0.85) or 1.0
        pick = [f for f in bm.faces
                if f.normal.dot(direction) > 0.85 and f.calc_area() / tot > min_share]
        if not pick:
            bm.free()
            break
        # TRIANGULATE BEFORE POKING, AND THIS IS NOT TIDINESS -- IT IS THE
        # DIFFERENCE BETWEEN A MUZZLE AND A WRECK. `poke` fans a face from the
        # average of its own vertices, which is only inside the face if the
        # face is CONVEX. The muzzle front is an n-gon that wraps around both
        # nostrils, so its average lands between them and the fan drew
        # triangles straight across both openings -- the nostrils rendered as
        # shattered polygonal craters. Triangulation handles concavity and
        # holes properly, and every triangle it leaves is convex by
        # definition, so the poke that follows cannot repeat it.
        tris = bmesh.ops.triangulate(bm, faces=pick, ngon_method='BEAUTY')["faces"]
        # Triangulating adds no VERTICES -- it only splits the outline using
        # corners that already exist -- so on its own it changes no normals at
        # all. Something has to put vertices in the MIDDLE, carrying the face's
        # own direction, and that is the entire point of the exercise.
        #
        # SUBDIVIDED EVENLY RATHER THAN FANNED, which was the last thing to get
        # wrong here. `poke` fans a triangle from its centre, so a region built
        # out of pokes is a wheel of spokes -- and spokes are visible: the
        # muzzle came back with the diagonal gone and a set of fine radial
        # streaks round its rim instead, which is the same fault wearing a
        # different pattern. Splitting each triangle into four keeps the
        # tessellation even, so there is no direction for a streak to run
        # along.
        edges = set()
        for f in tris:
            for e in f.edges:
                edges.add(e)
        bmesh.ops.subdivide_edges(bm, edges=list(edges), cuts=1,
                                  use_grid_fill=True)
        bm.to_mesh(ob.data)
        bm.free()
        ob.data.update()

    faces = region()
    total = sum(p.area for p in faces) or 1.0
    after = max((p.area for p in faces), default=0.0) / total
    return before, after


def relax_flat(ob, direction, rounds=30, factor=0.35, subdivide=True,
               forward_of=None):
    """Even out the point spacing on a face without moving the surface.

    THE STREAK ACROSS THE NOSE WAS NEVER A CREASE. Measured on the built
    muzzle, the dihedral angle across its front is 0.00 degrees MEDIAN -- the
    surface is genuinely smooth, and the only edges over 40 degrees are the 196
    that make up the two nostril rims, which are supposed to be sharp. What was
    visible was normal INTERPOLATION: `shade_smooth_by_angle` splits normals at
    those rims, so a long sliver triangle anchored on a rim shades unlike its
    neighbours all the way across the muzzle. Edge-length ratios ran to a
    median of 4.66 and a worst of 317.

    `beautify_fill` WAS TRIED FIRST AND IS NOT THE ANSWER, which is worth
    recording because it is the obvious tool: it flips edges to maximise the
    smallest angle without moving anything, and it took the median from 4.66 to
    4.51 and made the worst case WORSE. No wiring can make good triangles out
    of badly distributed points.

    SO THE POINTS MOVE, AND THEN GO BACK ON THE SURFACE. Sliding them
    tangentially alone was measured and photographed and is worse than the bug:
    the muzzle is domed by 0.19 along its own axis, so a point that moves
    sideways leaves the face, and the render came back with radiating eyelashes
    round both nostrils. Every moved point is re-projected onto a BVH of the
    ORIGINAL surface -- the original, not the half-relaxed one, or the shape
    drifts a little per round. Measured after: max distance from the surface as
    authored, 0.000000.

    The boundary is PINNED: any vertex touching a face outside the region is
    the muzzle's own rim or a nostril rim, and moving one changes the
    silhouette or opens a nostril.

    `subdivide` first, because the last thing left after the relax was a faint
    line between the two nostrils -- a triangle with one end on EACH rim, split
    normals at both, and pinned at both so the relax could not reach it. A
    midpoint in that span is interior, and interior points are what the relax
    moves.
    """
    from mathutils.bvhtree import BVHTree

    def keep(centre):
        return forward_of is None or centre.dot(direction) > -forward_of

    def region_polys():
        return [p for p in ob.data.polygons
                if p.normal.dot(direction) > 0.85 and keep(p.center)]

    snap_v, snap_p, idx = [], [], {}
    for p in region_polys():
        tri = []
        for vi in p.vertices:
            if vi not in idx:
                idx[vi] = len(snap_v)
                snap_v.append(ob.data.vertices[vi].co.copy())
            tri.append(idx[vi])
        for k in range(1, len(tri) - 1):
            snap_p.append((tri[0], tri[k], tri[k + 1]))
    if not snap_p:
        return 0, 0.0, 0.0
    bvh = BVHTree.FromPolygons(snap_v, snap_p, all_triangles=True)

    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    bm.verts.ensure_lookup_table()

    if subdivide:
        pre = [f for f in bm.faces if f.normal.dot(direction) > 0.85
               and keep(f.calc_center_median())]
        pre_edges = set()
        for f in pre:
            for e in f.edges:
                pre_edges.add(e)
        bmesh.ops.subdivide_edges(bm, edges=list(pre_edges), cuts=1,
                                  use_grid_fill=True)
        bm.faces.ensure_lookup_table()
        bm.verts.ensure_lookup_table()

    region = set(f for f in bm.faces if f.normal.dot(direction) > 0.85
                 and keep(f.calc_center_median()))
    rverts = set()
    for f in region:
        for v in f.verts:
            rverts.add(v)
    interior = [v for v in rverts if all(f in region for f in v.link_faces)]

    # cast along the region's own axis, from well outside it
    axis = -direction
    far = max((v.co.dot(axis) for v in rverts), default=0.0) + 3.0

    for _ in range(rounds):
        upd = {}
        for v in interior:
            nb = [e.other_vert(v) for e in v.link_edges]
            if not nb:
                continue
            avg = Vector((0.0, 0.0, 0.0))
            for n in nb:
                avg += n.co
            avg /= len(nb)
            # tangential only: drop the component along the face's own axis,
            # because the re-projection is what owns that one.
            delta = (avg - v.co)
            delta -= axis * delta.dot(axis)
            upd[v.index] = v.co + delta * factor
        for vi, target in upd.items():
            v = bm.verts[vi]
            old = v.co.copy()
            v.co = target
            origin = target - axis * (target.dot(axis) - far)
            hit = bvh.ray_cast(origin, axis)
            if hit[0] is not None:
                v.co = hit[0]
            else:
                v.co = old

    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()

    ratios = []
    for p in region_polys():
        vs = [ob.data.vertices[i].co for i in p.vertices]
        es = [(vs[i] - vs[(i + 1) % len(vs)]).length for i in range(len(vs))]
        if min(es) > 1e-9:
            ratios.append(max(es) / min(es))
    ratios.sort()
    med = ratios[len(ratios) // 2] if ratios else 0.0
    p90 = ratios[int(len(ratios) * 0.9)] if ratios else 0.0
    return len(interior), med, p90


def uv_unwrap(ob, angle=66.0, margin=0.02):
    """Lay the surface out flat so a texture has somewhere to live.

    WITHOUT THIS A TEXTURE CANNOT BE APPLIED AT ALL -- not badly, at all. A
    MeshPart's `TextureID` and every map on a `SurfaceAppearance` are looked
    up through UV coordinates, and this model shipped with none: measured, the
    exported .obj carried zero `vt` lines, so any texture would have had no
    defined position on the mesh.

    SMART PROJECT RATHER THAN A SPHERE OR A CYLINDER, because the body is not
    either of those any more -- it is a shell with two bores through it, and a
    spherical projection pinches every island to nothing at the poles and puts
    a seam down a flank somebody is looking at. Smart Project cuts by angle,
    which is what the openings and the muzzle's rim already are.

    THE TWO CALLS AFTER IT ARE THE ONES THAT MATTER FOR SKINS. `average_islands_
    scale` gives every island the same texels per stud, so a pattern is the
    same SIZE on the snout as on the rump -- without it Smart Project scales
    islands to fit and a metallic brush would be coarse on the body and fine on
    the ears. `pack_islands` then fits them into 0..1 with a margin, so
    neighbouring islands cannot bleed into each other at low mip levels, which
    is what makes a detail overlay fringe when the camera pulls back.
    """
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=margin)
    bpy.ops.uv.select_all(action='SELECT')
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(margin=margin)
    bpy.ops.object.mode_set(mode='OBJECT')


def uv_cylinder(objs, report=True):
    """Wrap every part on ONE cylinder about the standing axis.

    THE UNWRAP DECIDES WHETHER A PATTERN CAN HAVE A DIRECTION, and the one
    that shipped could not. `smart_project` rotates each island to pack
    tightly, which is chosen for how little sheet it wastes rather than for
    whether neighbouring islands agree -- measured on the built pig, the
    direction world +Z maps to in UV space has a coherence of 0.583 on the
    body and 0.282 on the trim, where 1.0 is "every face agrees" and 0.0 is
    random. So a BAND -- which is a line, and the whole of what makes the
    reference palettes read as metal -- would have run a different way on
    every island and broken at every seam. Speckle and crazing would have been
    fine, which is why nobody noticed until a band was wanted.

    A cylinder about Z measures 0.941 and 0.857 instead.

    ONE SHARED HEIGHT RANGE ACROSS EVERY PART, WHICH IS THE HALF THAT IS EASY
    TO GET WRONG. Body and Trim are two MeshParts with a sheet each, so the
    obvious thing is to normalise each one over its own bounds -- and then the
    snout carries a whole gradient of its own and its bands do not line up
    with the body's at the same height, which reads as a badly registered
    decal rather than as a turned metal. V is computed from the UNION of every
    part's world Z, so a band at a given height is at the same place on
    whichever part happens to be there.

    THE U SEAM IS CLOSED, AND IT WAS NOT ALWAYS. This function shipped with a
    note saying the seam was deliberately left alone, because the only pattern
    it had to carry was the metal band overlay, which varies with HEIGHT ONLY
    -- and a pattern with no U variation has nothing to smear. That was true
    and it expired the moment fur, stripes and spots were wanted, every one of
    which varies around the animal.

    Measured before the fix: 96 of the body's 3090 faces straddled the wrap,
    running the full height of it, with a worst U spread of 1.000 -- a smeared
    stripe down one flank on any texture that varies along U. The trim had
    none, which is luck rather than design and not something to rely on.

    THE FIX IS PER FACE AND NEVER PER VERTEX. A vertex ON the seam legitimately
    needs u ~ 0 for the faces one side of it and u ~ 1 for the faces the other
    side, so there is no single value to give it. UVs are stored per LOOP, so
    each face is made continuous with itself: any face spanning more than half
    the sheet has its low corners pushed up by one whole turn, which leaves it
    running 0.98 -> 1.02 rather than 0.98 -> 0.02. Values outside 0..1 are
    exactly what texture REPEAT is for.
    """
    # MEASURED, REPORTED, AND THEN NOT USED. The pinned range is what the
    # unwrap runs on; the measurement exists so that a geometry edit which
    # genuinely changes the animal's height says so out loud instead of
    # re-registering every texture in the pack behind your back.
    pig_uv.check_drift(objs, "uv")
    zmin, span = pig_uv.UV_Z0, pig_uv.UV_SPAN

    for ob in objs:
        me = ob.data
        while me.uv_layers:
            me.uv_layers.remove(me.uv_layers[0])
        uvl = me.uv_layers.new(name="UVMap")
        wrapped = 0
        for p in me.polygons:
            us = []
            for li in p.loop_indices:
                co = ob.matrix_world @ me.vertices[me.loops[li].vertex_index].co
                u = (math.atan2(co.y, co.x) / (2.0 * math.pi)) + 0.5
                v = (co.z - zmin) / span
                uvl.data[li].uv = (u, v)
                us.append((li, u, v))
            if max(x[1] for x in us) - min(x[1] for x in us) > 0.5:
                wrapped += 1
                for li, u, v in us:
                    if u < 0.5:
                        uvl.data[li].uv = (u + 1.0, v)
        if wrapped:
            print("%-6s seam: %d faces carried across the wrap" % (ob.name, wrapped))

    if report:
        for ob in objs:
            me = ob.data
            uvl = me.uv_layers.active
            # V-DENSITY IS THE ONE THAT MATTERS HERE, not area. A band varies
            # along V alone, so what decides whether it looks even is how much
            # V a stud of height buys -- horizontal stretch is invisible to it.
            rates = []
            for p in me.polygons:
                li = list(p.loop_indices)
                if len(li) < 2:
                    continue
                for a, b in zip(li, li[1:] + li[:1]):
                    ca = ob.matrix_world @ me.vertices[me.loops[a].vertex_index].co
                    cb = ob.matrix_world @ me.vertices[me.loops[b].vertex_index].co
                    dz = abs(cb.z - ca.z)
                    dv = abs(uvl.data[b].uv.y - uvl.data[a].uv.y)
                    if dz > 1e-5:
                        rates.append(dv / dz)
            rates.sort()
            if rates:
                med = rates[len(rates) // 2]
                lo = rates[int(len(rates) * 0.05)] / med
                hi = rates[int(len(rates) * 0.95)] / med
                print("%-6s 1 UV layer, cylinder about Z, V density %.2f..%.2f "
                      "of median across the middle 90%% of edges"
                      % (ob.name, lo, hi))


def uv_report(ob):
    """How evenly the unwrap spends its texels, which is the only number that
    says whether a pattern will look the same size everywhere.

    A face's share of the UV sheet should track its share of the real surface.
    Where it does not, the texture is stretched there by the square root of the
    ratio -- so this reports that ratio across the faces that actually carry
    area, ignoring the slivers, whose numbers are noise rather than stretch.
    """
    me = ob.data
    uv = me.uv_layers.active
    if uv is None:
        return None
    tot3 = sum(p.area for p in me.polygons) or 1.0

    def uv_area(p):
        pts = [uv.data[i].uv for i in p.loop_indices]
        a = 0.0
        for i in range(len(pts)):
            x1, y1 = pts[i]
            x2, y2 = pts[(i + 1) % len(pts)]
            a += x1 * y2 - x2 * y1
        return abs(a) * 0.5

    tot2 = sum(uv_area(p) for p in me.polygons) or 1.0
    ratios = []
    for p in me.polygons:
        if p.area < tot3 * 1e-5:
            continue
        u = uv_area(p)
        if u <= 0:
            continue
        ratios.append((u / tot2) / (p.area / tot3))
    ratios.sort()
    if not ratios:
        return None
    mid = ratios[len(ratios) // 2]
    p05 = ratios[int(len(ratios) * 0.05)]
    p95 = ratios[int(len(ratios) * 0.95)]
    return len(me.uv_layers), mid, p05, p95, tot2


def boolean(target, cutter, op='DIFFERENCE'):
    m = target.modifiers.new("bool", 'BOOLEAN')
    m.object = cutter
    m.operation = op
    m.solver = 'EXACT'
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier="bool")
    bpy.data.objects.remove(cutter, do_unlink=True)


# ---------------------------------------------------------------- FRAMES
# Blender -> the game's world, with the feet standing on the lawn.
#
# The OBJ exporter (forward -Z, up Y) sends blender (x, y, z) to (x, z, -y),
# so blender -Y -- the snout -- lands on Roblox +Z, which is the direction
# every landmark in PiggyBank is written in. LIFT is where blender z = 0 ends
# up once the lowest thing on the pig is standing on the slab.
LIFT = GAME_LAWN_Y - LEG_BOTTOM * SCALE


def to_rbx(v):
    return Vector((v[0] * SCALE, LIFT + v[2] * SCALE, -v[1] * SCALE))


def to_rbx_dir(v):
    return Vector((v[0], v[2], -v[1])).normalized()


def to_blend(p):
    return Vector((p[0] / SCALE, -p[2] / SCALE, (p[1] - LIFT) / SCALE))


def to_blend_dir(p):
    return Vector((p[0], -p[2], p[1])).normalized()


def ray_ellipsoid(o, d, rx, ry, rz):
    """How far along unit `d` from `o` the ellipsoid surface is."""
    a = (d.x / rx) ** 2 + (d.y / ry) ** 2 + (d.z / rz) ** 2
    b = 2.0 * (o.x * d.x / rx ** 2 + o.y * d.y / ry ** 2 + o.z * d.z / rz ** 2)
    c = (o.x / rx) ** 2 + (o.y / ry) ** 2 + (o.z / rz) ** 2 - 1.0
    return (-b + math.sqrt(max(b * b - 4 * a * c, 0.0))) / (2 * a)


# ---------------------------------------------------------------- BODY
body = quad_sphere("Body")
scale_verts(body, BODY_RX, BODY_RY, BODY_RZ)

# ---------------------------------------------------------------- SHELL
# HOLLOW FIRST, AND THAT IS WHAT MAKES AN OPENING AN OPENING RATHER THAN A
# DENT. A boolean against a SOLID body cannot put a hole in it: a cutter that
# stops inside leaves a blind recess with a flat floor, and one that goes all
# the way through drills a tunnel out the far side of the animal. Neither is a
# coin slot, and no amount of tuning the cutter turns one into the other.
#
# Given a real wall the same cutter takes a bite out of that WALL instead, so
# what is left is an opening with a visible edge and the pig's own hollow
# behind it -- which is the reading `swapToMesh` already switches
# `DoubleSided` on to get, and the one the vault hatch was built for and lost
# when the run-time bore was retired.
shell = body.modifiers.new("shell", 'SOLIDIFY')
shell.thickness = WALL / SCALE
shell.offset = -1.0          # the ellipsoid stays the OUTER surface
shell.use_even_offset = True
bpy.context.view_layer.objects.active = body
bpy.ops.object.modifier_apply(modifier="shell")

# ---------------------------------------------------------------- VAULT HATCH
# SOLVED FROM `dialCFrame`, NOT PLACED BY EYE. That function builds the whole
# vault on a 6.00 sphere centred at y 8.5 and drops it to DIAL_Y, so the
# dial's AXIS is fixed in world space whatever body is standing there -- and
# the hole has to be where that axis leaves THIS shell.
_drop = GAME_DIAL_Y - GAME_BODY_Y
_ring = math.sqrt(max(GAME_BODY_R ** 2 - _drop ** 2, 0.0))
DIAL_N = to_blend_dir(Vector((0.0, _drop, -_ring)))      # DIAL_YAW is 180 deg
_dial_o = to_blend(Vector((0.0, GAME_BODY_Y, 0.0)))
_t = ray_ellipsoid(_dial_o, DIAL_N, BODY_RX, BODY_RY, BODY_RZ)
HATCH = _dial_o + DIAL_N * _t
# What `MESH_DIAL_OUT` has to become: every piece of the dial is built at 6.00
# from the ball's centre and then pushed along this same axis onto the skin.
DIAL_OUT = _t * SCALE - GAME_BODY_R

bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=GAME_VAULT_R / SCALE,
                                    depth=HATCH_IN + HATCH_OUT)
cut = bpy.context.active_object
cut.rotation_euler = DIAL_N.to_track_quat('Z', 'Y').to_euler()
cut.location = HATCH + DIAL_N * ((HATCH_OUT - HATCH_IN) / 2.0)
apply_all(cut)
boolean(body, cut)

# ---------------------------------------------------------------- COIN SLOT
# The slit is the game's own `Slot` part turned into an actual hole -- the
# same 0.7 by 4.2 studs, so what a coin is posted into is the size the code
# has always claimed. It sits BEHIND the head: the ears are forward at blender
# y -0.36 and the tail root is at +0.90, and this runs 0.00 to 0.70 between
# them, which is the top of the back on a real piggy bank.
bpy.ops.mesh.primitive_cube_add(size=1.0)
cut = bpy.context.active_object
SLOT_LEN = GAME_SLOT_L / SCALE * SLOT_TRIM
scale_verts(cut, GAME_SLOT_W / SCALE, SLOT_LEN, 0.9)
# Reaching from above the crown down into the cavity, so it bites the top wall
# and nothing else -- the belly is another stud and a half below it.
cut.location = Vector((0.0, SLOT_FRONT + SLOT_LEN / 2.0, 0.95))
print("coin slit %.2f studs long, spanning blender y %.3f..%.3f (tail root %.2f)"
      % (SLOT_LEN * SCALE, SLOT_FRONT, SLOT_FRONT + SLOT_LEN, TAIL_Y))
apply_all(cut)
boolean(body, cut)

# ---------------------------------------------------------------- SNOUT
# A TRUNCATED CONE, WIDER AT THE BACK, AND DEEP ENOUGH TO REACH THE BODY ALL
# ROUND ITS RIM. As a flat-backed cylinder the snout FLOATED: the face it sits
# on is curved and the back was a plane, so it met the body near the centre
# and pulled away at the edges -- measured, the back plane at y -0.990 against
# a body surface of -0.936 out at the rim, so the widest part of the muzzle
# never touched the pig at all. That is the notch round it, and no amount of
# angling fixes a gap.
#
# Flaring the back also makes the two surfaces meet at a shallow angle rather
# than a hard one, which is the same fillet argument the tail root needed.
surf, _ = ellipsoid_surface((0.0, -1.0, SNOUT_Z / max(BODY_RZ, 1e-6)),
                            BODY_RX, BODY_RY, BODY_RZ)
# HELD UNDER ITS OWN NAME, BECAUSE `surf` IS REASSIGNED LATER AND THE NOSTRIL
# ANCHOR WAS READING THE WRONG ONE.
#
# The eye-preview loop three hundred lines below writes `surf, n = ...` at
# module scope, once per eye -- so from that point on `surf` is the last EYE's
# surface point rather than the snout's. The block that prints
# `MESH_FACE.nostril` reads `surf.y`, and has been computing the nostril seat
# off the eye ever since the preview was added.
#
# It is the shadowing family this file already records for `legRoll` and the
# cylinder axis, in its quietest form: both values are plausible points on the
# same body, the arithmetic runs, and the only symptom is two dark blocks
# sitting slightly off the dimples they are meant to fill. The delta is
# printed at the anchor so the size of it is on the record rather than
# inferred.
SNOUT_SURF = surf.copy()
# HOW DEEP IS SOLVED, NOT TYPED, AND TYPING IT WAS WRONG BY A THIRD OF A
# STUD. A cone's back is a flat disc and the face it beds into is curved, so
# burying the CENTRE of that disc says nothing about its RIM -- and the rim's
# lowest point is the worst of it, because a nose-up tilt swings the back of
# the muzzle down. Measured on the hand-set 0.58, the bottom of the rim stood
# at ellipsoid parameter 1.14, which is a hard circular lip breaking out under
# the chin: visible in profile, and exactly what a flat-backed cylinder did
# before it.
#
# Solved instead, the depth follows SNOUT_R, the flare and the lift wherever
# any of them goes next. It only ever adds cone INSIDE the pig -- the face
# stays SNOUT_OUT proud by construction -- so the muzzle a player sees is
# unchanged: measured, its radius where it leaves the skin moves 0.520 to
# 0.504, which is three per cent.
def _rim_worst(depth):
    """Worst ellipsoid parameter over the back rim at this depth."""
    rb = SNOUT_R * SNOUT_BACK_FLARE
    c, s_ = math.cos(math.radians(-SNOUT_LIFT)), math.sin(math.radians(-SNOUT_LIFT))
    cy = surf.y - SNOUT_OUT + depth / 2.0
    worst = 0.0
    for i in range(180):
        a = 2.0 * math.pi * i / 180.0
        x, y, z = rb * math.sin(a), depth / 2.0, rb * math.cos(a)
        wy = cy + (c * y - s_ * z)
        wz = SNOUT_Z + (s_ * y + c * z)
        worst = max(worst, math.sqrt((x / BODY_RX) ** 2 + (wy / BODY_RY) ** 2
                                     + (wz / BODY_RZ) ** 2))
    return worst


SOLVED_DEPTH = SNOUT_DEPTH
while SOLVED_DEPTH < 2.0 and _rim_worst(SOLVED_DEPTH) > SNOUT_BURY:
    SOLVED_DEPTH += 0.005
print("snout depth solved %.3f (typed %.2f) -> back rim parameter %.3f"
      % (SOLVED_DEPTH, SNOUT_DEPTH, _rim_worst(SOLVED_DEPTH)))
SNOUT_DEPTH = SOLVED_DEPTH

bpy.ops.mesh.primitive_cone_add(vertices=48,
                                radius1=SNOUT_R * SNOUT_BACK_FLARE,
                                radius2=SNOUT_R, depth=SNOUT_DEPTH)
snout = bpy.context.active_object
snout.name = "Snout"
# built along Z; lay it along Y so the NARROW end faces forward at -Y
for v in snout.data.vertices:
    x, y, z = v.co
    v.co = Vector((x, -z, y))
bevel_rims(snout, width=0.115, segments=5)

# CUT IN THE SNOUT'S OWN FRAME, BEFORE IT IS TILTED. Placed in world space the
# dimples would stay where an untilted face used to be, and at 12 degrees that
# is a visible slide down the muzzle.
for side in (-1, 1):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1.0)
    cut = bpy.context.active_object
    scale_verts(cut, NOS_RX, NOS_RY, NOS_RZ)
    cut.location = Vector((side * NOS_DX,
                           -SNOUT_DEPTH / 2.0 - NOS_RY + NOS_SINK,
                           NOS_Z))
    apply_all(cut)
    boolean(snout, cut)

# DONE HERE, once both dimples are cut and while the muzzle is still square to
# its own axes, so "faces looking down -Y" is exactly the muzzle front and
# nothing else.
_before = len(snout.data.polygons)
_big = poke_flat(snout, direction=Vector((0.0, -1.0, 0.0)), rounds=MUZZLE_POKES)
print("muzzle front: largest face was %.1f%% of it, now %.1f%% (%d faces -> %d)"
      % (_big[0] * 100.0, _big[1] * 100.0, _before, len(snout.data.polygons)))

# A NEGATIVE rotation about X carries the forward vector -Y toward +Z, so a
# positive SNOUT_LIFT is nose UP. Printed back rather than trusted.
snout.location = Vector((0.0, surf.y - SNOUT_OUT + SNOUT_DEPTH / 2.0, SNOUT_Z))
snout.rotation_euler = (math.radians(-SNOUT_LIFT), 0.0, 0.0)
apply_all(snout)
print("snout lift %+.1f deg -> forward (0, %.3f, %+.3f)"
      % (SNOUT_LIFT, -math.cos(math.radians(SNOUT_LIFT)),
         math.sin(math.radians(SNOUT_LIFT))))
# MEASURED ON THE MESH THAT WAS ACTUALLY BUILT, over every vertex behind the
# body's own front pole rather than over a hand-picked slab -- the slab moved
# when the depth did, which is how a check goes quietly out of date.
worst = max(((v.co.x / BODY_RX) ** 2 + (v.co.y / BODY_RY) ** 2
             + (v.co.z / BODY_RZ) ** 2) ** 0.5
            for v in snout.data.vertices if v.co.y > surf.y)
print("snout: worst vertex behind the face is at parameter %.3f (1.0 is the skin)"
      % worst)

# ---------------------------------------------------------------- EARS
# A TRUNCATED CONE, NOT A TAPERED SPHERE. A sphere already pinches to nothing
# at its pole, so tapering one on top of that narrows twice and the ear comes
# out as a horn -- which is exactly what the first two passes rendered. A cone
# holds its width all the way up and the bevel is what rounds the tip, so the
# ear stays a broad blade with a soft point, like the reference.
def bend(ob, axis, degrees, z_base, height, power=1.35):
    """Curl an upright piece, base held still, by an angle that grows with
    height. A rigid rotation angles a straight blade; this leaves the base
    square in the head and curves only the top, which is what a floppy ear
    actually does. `power` above 1 keeps the bottom third nearly straight so
    the curl reads at the tip rather than as a banana."""
    pivot = Vector((0.0, 0.0, z_base))
    for v in ob.data.vertices:
        t = max(0.0, min(1.0, (v.co.z - z_base) / height))
        R = Matrix.Rotation(math.radians(degrees) * (t ** power), 3, axis)
        v.co = R @ (v.co - pivot) + pivot


ears = []
for side in (-1, 1):
    bpy.ops.mesh.primitive_cone_add(vertices=EAR_SIDES, radius1=EAR_BASE_R,
                                    radius2=EAR_TIP_R, depth=EAR_H)
    ear = bpy.context.active_object
    ear.name = "Ear"
    bevel_rims(ear, width=EAR_BEVEL, segments=EAR_BEV_SEG, angle=25.0)
    # Flatten front-to-back into a blade BEFORE bending. The other way round
    # the bend displaces vertices in Y and the flatten then squashes the curl
    # out again -- the forward flop would be scaled down by the same factor
    # that thins the ear.
    flat_k = (EAR_T / 2.0) / EAR_BASE_R
    scale_verts(ear, 1.0, flat_k, 1.0)

    # A DISH SCOOPED OUT OF THE FRONT FACE, leaving a rim all the way round.
    # The cutter is the SAME CONE scaled down, which is what makes the rim
    # even from base to tip: a sphere or an ellipsoid cutter leaves a wide rim
    # at the broad base and pinches to nothing at the point, so the ear would
    # read as dished at the bottom and flat at the top -- the opposite of the
    # reference, where the scoop runs the whole length.
    bpy.ops.mesh.primitive_cone_add(vertices=EAR_SIDES,
                                    radius1=EAR_BASE_R * DISH_INSET,
                                    radius2=EAR_TIP_R * DISH_INSET,
                                    depth=EAR_H * DISH_INSET)
    dish = bpy.context.active_object
    bevel_rims(dish, width=EAR_BEVEL * DISH_INSET, segments=DISH_BEV_SEG,
               angle=25.0)
    scale_verts(dish, 1.0, flat_k, 1.0)
    # Seated so exactly DISH_DEPTH of it overlaps the ear's front face.
    half_y = EAR_BASE_R * DISH_INSET * flat_k
    dish.location = Vector((0.0, -(EAR_T / 2.0) + DISH_DEPTH - half_y, DISH_Z))
    apply_all(dish)
    boolean(ear, dish)

    # THE SCOOP'S RIM ONLY EXISTS ONCE THE CUT HAS BEEN MADE, so this is the
    # one place it can be rounded. The angle limit catches the 44-to-58-degree
    # lip and the ear's own base rim at 106 -- the base is buried in the head
    # and beveling it costs a few faces nobody will ever see, which is the
    # cheaper of the two mistakes available here.
    bevel_rims(ear, width=DISH_LIP, segments=3, angle=30.0)

    # +X about the X axis carries the tip toward -Y, which is the snout, so a
    # positive angle is a forward flop.
    bend(ear, 'X', EAR_BEND_FWD, -EAR_H / 2.0, EAR_H)
    # About Y, a positive angle carries the tip toward +X, so the inward
    # direction is -side.
    bend(ear, 'Y', -side * EAR_CURL_IN, -EAR_H / 2.0, EAR_H)
    ear.location = Vector((side * EAR_X, EAR_Y, EAR_Z))
    ear.rotation_euler = (math.radians(-EAR_BACK), math.radians(side * EAR_OUT), 0.0)
    apply_all(ear)
    ears.append(ear)

print("ear tip apex %.1f degrees"
      % (180.0 - 2.0 * math.degrees(math.atan((EAR_BASE_R - EAR_TIP_R) / EAR_H))))

# ---------------------------------------------------------------- LEGS
legs = []
for sx in (-1, 1):
    for ly in (LEG_Y_FRONT, LEG_Y_BACK):
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=LEG_R, depth=LEG_H)
        leg = bpy.context.active_object
        leg.name = "Leg"
        bevel_rims(leg, width=0.080, segments=3)
        leg.location = Vector((sx * LEG_X, ly, LEG_BOTTOM + LEG_H / 2.0))
        apply_all(leg)
        legs.append(leg)

# ---------------------------------------------------------------- TAIL
# A tapering corkscrew, spun out of a circle profile.
mesh = bpy.data.meshes.new("Tail")
tail = bpy.data.objects.new("Tail", mesh)
scene.collection.objects.link(tail)
bm = bmesh.new()
bmesh.ops.create_circle(bm, cap_ends=False, segments=16, radius=TAIL_MINOR)
for v in bm.verts:
    # THE PROFILE HAS TO BE PERPENDICULAR TO THE SWEEP. create_circle builds
    # in the XY plane; a spin about +Y sets off along +X, so the profile
    # belongs in the YZ plane with its normal on X. Laid in the XZ plane it
    # lies almost ALONG the path rather than across it, and the sweep comes
    # out as a ridged screw thread instead of a tube -- which is exactly what
    # was rendering, and no amount of extra segments was ever going to fix it.
    v.co = Vector((0.0, v.co.x, v.co.y))
    v.co.z += TAIL_MAJOR
root_ring = list(bm.verts)

# THE SWEEP RUNS BACKWARDS INTO THE BODY BEFORE IT RUNS OUT OF IT, and that
# is what removes the half-moon rather than hiding it. A spin about +Y leaves
# along +X, which is TANGENTIAL to the rump, so the tube can only ever graze
# the shell -- and any cap near that crossing shows as a flat disc lying on
# the pig. Measured at the hand-set seat, the root ring stood 0.149 studs
# proud across half its circumference: that disc was the half-moon.
#
# Burying it by dropping the whole tail does work and costs the curl. The
# ring stands in the YZ plane, so it spans a lot of Y and wants about 0.10 of
# depth, which swallowed most of the visible turn.
#
# Starting the sweep at a NEGATIVE angle puts the cap half a turn further
# inside the pig, where nothing can reach it, and what crosses the shell is
# tube surface. The seat is then free to be chosen for how the curl LOOKS.
turns_out = TAIL_TURNS
turns_all = TAIL_INWARD_TURNS + turns_out
per_turn = TAIL_TRAVEL / turns_out
steps = int(round(TAIL_STEPS * turns_all / turns_out))
angle_in = math.radians(360.0 * TAIL_INWARD_TURNS)
angle_all = math.radians(360.0 * turns_all)
angle_out = math.radians(360.0 * turns_out)
travel_all = per_turn * turns_all

back = Matrix.Rotation(-angle_in, 3, 'Y')
for v in bm.verts:
    v.co = back @ v.co - Vector((0.0, per_turn * TAIL_INWARD_TURNS, 0.0))

spun = bmesh.ops.spin(bm, geom=bm.verts[:] + bm.edges[:],
                      cent=Vector((0, 0, 0)), axis=Vector((0, 1, 0)),
                      dvec=Vector((0, travel_all / steps, 0)),
                      angle=angle_all, steps=steps, use_duplicate=False)
# A SWEEP IS OPEN AT BOTH ENDS, so the tip was a cut tube -- a drinking straw
# rather than a tail. `geom_last` is the ring the spin finished on; hold it
# now and cap it AFTER the taper, when its real width is known.
tip_ring = [e for e in spun["geom_last"] if isinstance(e, bmesh.types.BMVert)]

# TAPER PER RING, NOT PER AXIS. Scaling world X and Z and leaving Y alone
# shrinks the tube across but not along, so the cross-section turns elliptical
# -- measured at the tip, 0.054 one way against 0.090 the other. A ball cap
# then has no radius that fits, splits the difference at 0.0755, and reads as
# a bead stuck on the end. Scaling each ring about its OWN centre keeps every
# cross-section circular, so the cap fits exactly.
#
# The two dials are separate on purpose: one thins the TUBE, the other closes
# up the SPIRAL, and a curl wants both but not in the same proportion.
dy = travel_all / steps
centres, params = [], []
for k in range(steps + 1):
    a = -angle_in + angle_all * k / steps
    centres.append(Vector((TAIL_MAJOR * math.sin(a),
                           -per_turn * TAIL_INWARD_TURNS + k * dy,
                           TAIL_MAJOR * math.cos(a))))
    # Measured over the VISIBLE turn only, so the buried lead-in keeps full
    # thickness and the taper still runs a clean 0 to 1 across what shows.
    params.append(max(0.0, min(1.0, a / angle_out)))
for v in bm.verts:
    # Assign by nearest ring centre rather than by vertex order -- the spin's
    # ordering is an implementation detail, and the helix's own turns are
    # 0.40 apart in y against a tube radius of 0.09, so nothing is ambiguous.
    k = min(range(len(centres)), key=lambda i: (v.co - centres[i]).length_squared)
    t = params[k]
    c = centres[k]
    tightened = Vector((c.x * (1.0 - TAIL_CURL_TIGHTEN * t), c.y,
                        c.z * (1.0 - TAIL_CURL_TIGHTEN * t)))
    # Squared falloff so the flare leaves the tube smoothly rather than
    # stepping off it -- a linear one puts a visible kink where it ends.
    flare = 1.0 + (TAIL_ROOT_FLARE - 1.0) * max(0.0, 1.0 - t / TAIL_ROOT_SPAN) ** 2
    v.co = tightened + (v.co - c) * (1.0 - TAIL_TUBE_TAPER * t) * flare

# THE TIP'S OWN EDGES ARE HELD BACK FROM `holes_fill`, AND THAT ONE LINE IS
# THE BUG THIS BLOCK EXISTS TO FIX. It used to be handed `bm.edges[:]` -- every
# edge in the bmesh -- so it capped the ROOT and the TIP alike, and the tip got
# a flat n-gon disc it was never meant to have.
tipset = set(tip_ring)
tip_edges = [e for e in bm.edges if len(e.link_faces) == 1
             and e.verts[0] in tipset and e.verts[1] in tipset]

# Close the root as well. It is buried in the rump today, but the vault hatch
# is cut directly under the tail, so an open end there would be visible down
# the hole the moment the body becomes a shell. That is the reason it stays,
# and it is not decorative.
bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e not in set(tip_edges)],
                     sides=0)

# THE TIP IS SWEPT OUT OF THE TUBE'S OWN RING, NOT CAPPED WITH A SEPARATE
# BALL, AND THE DIFFERENCE IS THE WHOLE POINT.
#
# WHAT WAS HERE BEFORE, because a bug this quiet is worth naming. The tip was
# THREE overlapping things: a hollow swept tube, a flat disc that `holes_fill`
# sealed it with, and a whole `create_uvsphere` dropped on top -- new geometry,
# welded to nothing, with half of itself buried inside the tube. The comment
# that stood here said the ball "meets tangentially, smooth shading carries
# straight across, and there is no lip to hide". That is a true statement about
# two SURFACES and a false one about this MESH, and it is why nobody looked
# again for months. Measured on the shipped tail: a 16-vertex n-gon of area
# 8.22e-03 against a median face of 2.88e-04 beside it -- 28 times its
# neighbours -- with 117.6 degrees across its ring, which SMOOTH_ANGLE then
# marked sharp along with 75 other edges. Reported as a crease round the tip.
# Same family as `gable()`'s comment about which edge of a WedgePart is full
# height, and as `UseJumpPower`: a comment explaining why a bug is not a bug is
# worse than no comment, because it is what stops the next person checking.
#
# Extruding the ring instead means the dome shares the tube's own vertices, so
# it is continuous by construction rather than tangent by arithmetic -- there
# is no seam to smooth, no disc trapped under it and no second shell. The
# profile is a true quarter circle: ring k sits at radius r*cos(t) and stands
# r*sin(t) along the tube's axis, so at t=0 it IS the tube's ring and the join
# cannot step.
centre = sum((v.co for v in tip_ring), Vector()) / len(tip_ring)
radius = sum((v.co - centre).length for v in tip_ring) / len(tip_ring)

# WHICH WAY IS OUT, ASKED OF THE MESH RATHER THAN ASSUMED. The tail is a curl,
# so no world axis is the tube's direction; the ring one step INBOARD gives it
# for nothing, and it stays right if the curl or the taper ever move.
inboard = set()
for v in tip_ring:
    for e in v.link_edges:
        o = e.other_vert(v)
        if o not in tipset:
            inboard.add(o)
axis = (centre - sum((v.co for v in inboard), Vector()) / len(inboard)).normalized()

# Five rings, which is what `create_uvsphere`'s ten v_segments gave a whole
# sphere and therefore what its visible half was already worth.
# EVERY DOME VERTEX IS SOLVED FROM ITS OWN SOURCE ON THE RING, NEVER FROM THE
# RING'S MEAN, and that is not a refinement -- the first version of this folded
# the mesh back on itself. The tip ring is TILTED: it is the end of a tapering
# helix, so its vertices do not share one height along the tube's axis. Placing
# ring 1 at a single height measured from the ring's centre therefore put it
# BEHIND the tip ring's leading vertices, and the first band of quads turned
# inside out -- measured, 13 edges over 60 degrees with a worst of 177.9, on
# faces of ordinary area rather than slivers.
#
# Carrying each vertex's own axial offset `h0` makes t = 0 land exactly where
# the vertex already is, so the join cannot step whatever the ring's tilt.
TIP_DOME_RINGS = 5
cur_edges = tip_edges
prevset = set(tip_ring)
source = {v: v.co.copy() for v in tip_ring}
last_verts = []
for k in range(1, TIP_DOME_RINGS + 1):
    ret = bmesh.ops.extrude_edge_only(bm, edges=cur_edges)
    new_verts = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMVert)]
    newset = set(new_verts)
    cur_edges = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMEdge)
                 and g.verts[0] in newset and g.verts[1] in newset]
    # An extruded vertex shares exactly one edge with the vertex it came from,
    # which is how each ring inherits the ORIGINAL ring vertex it belongs to.
    for v in new_verts:
        for e in v.link_edges:
            o = e.other_vert(v)
            if o in prevset:
                source[v] = source[o]
                break
    t = (math.pi / 2.0) * k / TIP_DOME_RINGS
    for v in new_verts:
        d = source[v] - centre
        h0 = d.dot(axis)
        r_v = d - axis * h0
        rr = r_v.length
        if rr > 1e-9:
            r_v = r_v.normalized() * (rr * math.cos(t))
        v.co = centre + axis * h0 + r_v + axis * (rr * math.sin(t))
    prevset, last_verts = newset, new_verts
# The last ring is at cos(90) = 0, so every vertex in it has collapsed onto the
# tube's own axis; merging them turns a degenerate ring into one clean pole.
# WHERE THE RING ACTUALLY CONVERGED, not where a mean radius says it should
# have. Every source vertex carries its own radius, so a pole solved from the
# ring's MEAN sits slightly off the surface the last band is heading for and
# leaves a small spike.
bmesh.ops.pointmerge(bm, verts=last_verts,
                     merge_co=sum((v.co for v in last_verts), Vector()) / len(last_verts))
bm.normal_update()
print("tail tip capped: radius %.4f at (%.3f, %.3f, %.3f)"
      % (radius, centre.x, centre.y, centre.z))

# WHERE THE TAIL SITS ON Y IS SOLVED, NOT TYPED, and that is the half-moon.
# `holes_fill` caps the root with a flat disc; at the hand-set 0.86 that disc
# stood up to 0.149 studs PROUD of the rump across half its circumference, so
# what read as a bad blend was a flat cap lying on the pig. The ring is large
# and stands in the YZ plane, so it spans a lot of Y and needs real depth --
# depth that changes the moment the flare, the curl radius or TAIL_Z move.
# Solving it means it cannot come back.
# Checked rather than trusted: 1.0 is the skin, so every root-cap vertex has
# to come back well under it.
deepest = max(((v.co.x / BODY_RX) ** 2
               + ((TAIL_Y + v.co.y) / BODY_RY) ** 2
               + ((TAIL_Z + v.co.z) / BODY_RZ) ** 2) ** 0.5
              for v in root_ring)
# THE CAP IT USED TO MEASURE IS GONE -- the tail is trimmed against the wall
# further down, so what this now reports is simply how deep the sweep STARTS,
# which only has to be inside the body for that trim to have something to bite.
print("tail sweep starts at ellipsoid parameter %.3f (1.0 is the skin)" % deepest)

bm.to_mesh(mesh)
bm.free()
tail.location = Vector((0.0, TAIL_Y, TAIL_Z))
apply_all(tail)

# ---------------------------------------------------------------- TAIL TRIM
# THE LEAD-IN IS CUT OFF INSIDE THE WALL, AND CUTTING IT AT THE WALL RATHER
# THAN DELETING IT IS THE WHOLE POINT.
#
# Once the body is a hollow shell you can see into it, and the vault hatch
# looks straight down the rump at the tail root -- so the half turn of helix
# that runs backwards INTO the pig, which nothing could see while the body was
# solid, became a spring hanging in the cavity behind the hatch. Reported as
# exactly that.
#
# It cannot simply be removed. That inward sweep is load-bearing: it exists to
# carry `holes_fill`'s flat root cap half a turn deep, where the shell cannot
# show it. Measured at the hand-set seat before it was added, that cap stood
# 0.149 studs PROUD of the rump across half its circumference -- the half-moon
# at the tail base that took a whole pass to diagnose. Shorten the sweep and
# the cap climbs back to the skin and the half-moon returns.
#
# Cutting instead gets both. The tube is trimmed against an ellipsoid at the
# MIDDLE of the wall, so what is left starts inside the shell's own thickness:
# the cavity sees an unbroken inner wall, the outside sees the same root
# fillet it always had, and the flat cap is gone entirely rather than hidden
# -- there is nothing left to stand proud of anything. The triangles the
# lead-in was costing go with it.
_w = WALL / SCALE
cut_rx, cut_ry, cut_rz = BODY_RX - _w / 2, BODY_RY - _w / 2, BODY_RZ - _w / 2
bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=1.0)
cut = bpy.context.active_object
scale_verts(cut, cut_rx, cut_ry, cut_rz)
apply_all(cut)
boolean(tail, cut)

# NOTHING OF THE TAIL IS LEFT IN THE CAVITY, and that is measured against the
# INNER surface rather than the outer one -- the inner wall is what a viewer
# at the hatch is looking at, and a point can be comfortably under the skin
# and still be hanging in the hollow. This is the check that would have caught
# it before it was ever exported.
_iy = [(v.co.x / (BODY_RX - _w)) ** 2 + (v.co.y / (BODY_RY - _w)) ** 2
       + (v.co.z / (BODY_RZ - _w)) ** 2 for v in tail.data.vertices]
print("tail: %d of %d points still inside the cavity (0 is the whole point)"
      % (sum(1 for p in _iy if p < 1.0), len(_iy)))

# THE TAIL'S OWN POINTS, HELD BEFORE THE JOIN. The cape anchor is solved
# against them below, and after `join` there is no tail object left to ask.
TAIL_PTS = [Vector(v.co) for v in tail.data.vertices]

# ---------------------------------------------------------------- JOIN TRIM
# TAGGED BEFORE IT IS WELDED, WHICH IS THE WHOLE OF HOW THE TRIM CAN BE SPLIT
# AGAIN LATER.
#
# The snout, the ears, the legs and the tail are joined into one `Trim` object
# because everything downstream is written against one: the muzzle relax, the
# degenerate-face clean, the smooth-by-angle pass and the unwrap. They also
# have to come apart again -- a reference bumblebee has a YELLOW SNOUT and
# BLACK EARS, and one MeshPart carries one `Color`, so no arrangement of skin
# fields can paint those differently while they are the same part.
#
# THE ORDER MATTERS AND IS THE REASON THIS IS A VERTEX GROUP RATHER THAN FOUR
# SEPARATE EXPORTS. Splitting BEFORE the processing means four objects each
# getting their own relax, their own clean and their own unwrap -- and the
# unwrap is the one that cannot survive it, because `uv_cylinder` normalises
# height over the union of every part. Splitting AFTER means one pass over one
# mesh and four cuts out of the finished article, so the pieces are guaranteed
# to carry exactly the surface the whole trim carried.
#
# `bpy.ops.object.join()` merges vertex groups BY NAME, so four pieces sharing
# a group name arrive as one group on the other side -- which is what makes
# two ears and four legs single parts without any index bookkeeping.
TRIM_GROUPS = (("Snout", [snout]), ("Ears", ears), ("Legs", legs),
               ("Tail", [tail]))
for _gname, _obs in TRIM_GROUPS:
    for _ob in _obs:
        _vg = _ob.vertex_groups.new(name=_gname)
        _vg.add(list(range(len(_ob.data.vertices))), 1.0, 'REPLACE')

bpy.ops.object.select_all(action='DESELECT')
for ob in [snout] + ears + legs + [tail]:
    ob.select_set(True)
bpy.context.view_layer.objects.active = snout
bpy.ops.object.join()
trim = bpy.context.active_object
trim.name = "Trim"

# ---------------------------------------------------------------- EYES (preview)
# Not exported. The game builds its own Eye parts; these are here so a render
# shows what the finished pig actually looks like.
bpy.ops.object.select_all(action='DESELECT')
eyeobs = []
for side in (-1, 1):
    d = Vector((side * EYE_DIR[0], EYE_DIR[1], EYE_DIR[2]))
    surf, n = ellipsoid_surface(d, BODY_RX, BODY_RY, BODY_RZ)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=EYE_R)
    eye = bpy.context.active_object
    eye.name = "EyePreview"
    eye.location = surf - n * (EYE_R * (1.0 - EYE_PROUD))
    eyeobs.append(eye)
bpy.ops.object.select_all(action='DESELECT')
for e in eyeobs:
    e.select_set(True)
bpy.context.view_layer.objects.active = eyeobs[0]
bpy.ops.object.join()
eyes = bpy.context.active_object
eyes.name = "EyePreview"

# Nostrils are the sculpted snout recesses; separate black preview inserts retired.

# ---------------------------------------------------------------- SHADE + REPORT
# CLEANED BEFORE IT IS SHADED, NOT AFTER, because the shading pass is what
# reads the face normals -- so a degenerate face left in place poisons the
# normals of every vertex around it and no later tidy-up can undo that.
# THE MUZZLE IS EVENED OUT HERE RATHER THAN AT THE POKE, and the difference is
# a picture. Run on the loose snout the relax is undone by everything that
# happens afterwards -- the rim bevel, the tilt, the join -- and the rebuilt
# muzzle came back with a chevron still under the nostrils. Run on the finished
# trim it is the last word on that surface, which is what the standalone test
# that produced the clean render actually did.
#
# THE REGION NEEDS A POSITION TEST NOW, WHICH IT DID NOT BEFORE. On the loose
# snout, "faces looking down -Y" was the muzzle and nothing else; on the joined
# trim it also catches the front of both ears and part of the tail. The muzzle
# is the only part of it forward of y -1.05.
# SUBDIVIDE OFF, AND THIS IS THE ONE THAT WAS MEASURED IN THE ENGINE RATHER
# THAN IN BLENDER. With it on, the muzzle went from 736 faces to 2725 and the
# rebuilt pig came back IN GAME with radial wedges round the rim and both
# nostrils -- worse than the single line the whole exercise started from --
# while an extreme close-up rendered in Blender was clean. It is not a mesh
# fault: measured, zero T-junctions and zero surviving degenerate faces.
# ROBLOX QUANTISES MESH NORMALS, and that error is invisible across coarse
# triangles and shows as facets across 2725 tiny ones (smallest area 2.5e-06
# against a median of 1.2e-04). So the DISTRIBUTION half of this helps and the
# DENSITY half hurts, and they were shipped as one change.
#
# The cost is the faint line between the two nostrils, which the subdivide was
# what removed -- see `relax_flat`. That is a fair trade against wedges over
# the whole muzzle, and it is recorded rather than hidden.
_n, _med, _p90 = relax_flat(trim, direction=Vector((0.0, -1.0, 0.0)),
                            forward_of=-1.05, subdivide=False)
print("muzzle relax: %d interior points moved, edge-length ratio median %.2f, "
      "p90 %.2f (was 4.66 / 20.58)" % (_n, _med, _p90))

for ob in (body, trim):
    print("%-6s cleanup removed %d degenerate faces" % (ob.name, clean_mesh(ob)))

# `shade_smooth` ACTS ON THE SELECTION, NOT ON THE ACTIVE OBJECT, AND THAT IS
# THE SECOND OPERATOR IN THIS FILE TO QUIETLY MEAN SOMETHING ELSE. This block
# used to set `objects.active` and call it -- and at this point in the build
# the only SELECTED object is the eye preview, left over from the join a few
# lines above. So the eyes were smoothed three times over and the pig was
# never smoothed at all. Measured on the shipped blend: Body 0 of 3,090 faces
# smooth, Trim 0 of 3,653, EyePreview 576 of 576 -- exactly the one object
# that happened to be selected, which is the signature of this mistake.
#
# IT IS INVISIBLE IN EVERY NUMBER THIS FILE PRINTS. Vertex counts, triangle
# counts, bounds, the bore ray-walk and the plate clearance are all identical
# either way; the export even carries `export_normals=True` and dutifully
# wrote a normal per FACE. What it produced is a pig with every triangle on
# it, and the only evidence anywhere is a boolean on a polygon.
#
# BY ANGLE RATHER THAN OUTRIGHT, because half the edges here are meant to be
# hard. Both openings are cut through the shell and meet the skin at about a
# right angle, and a hole with a soft rim reads as a smudge rather than as a
# hole -- which is the same thing that made the drawn vault disc a sticker.
# Everything that has to look round turns far more gently than the threshold:
# the quad-sphere steps 5.6 degrees between neighbours, a bevelled rim about
# 18, and the tail's tube 22.5.
SMOOTH_ANGLE = 40.0

for ob in (body, trim, eyes):
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(SMOOTH_ANGLE))

# AND IT IS READ BACK, WHICH IS THE HALF THAT STOPS IT COMING BACK. An
# operator that silently addressed the wrong object cannot be caught by
# looking at the code that called it; it can be caught in one line by asking
# the mesh afterwards whether anything actually happened.
for ob in (body, trim, eyes):
    _sm = sum(1 for p in ob.data.polygons if p.use_smooth)
    assert _sm == len(ob.data.polygons), \
        "%s: %d of %d faces smooth -- shade_smooth addressed the wrong object" \
        % (ob.name, _sm, len(ob.data.polygons))


# ============================================================
# THE MUZZLE'S FLAT FACE SHADES FLAT
# ============================================================
#
# A FACE LYING IN A PLANE HAS THAT PLANE'S NORMAL AT EVERY POINT OF IT, and
# `shade_smooth_by_angle` does not know that. It splits normals at the nostril
# rims -- correctly, they are meant to be sharp -- and the sliver triangles
# anchored ON those rims then carry a corner normal pulled toward the bore
# rather than lying in the muzzle plane. Measured on the shipped snout: the
# rim corners of flat-plane faces ran up to 12.93 degrees off, at x +/-0.077,
# z -0.029 and +0.084, which is the inner edge of each nostril at two fixed
# heights. A constant height is what makes it read as a horizontal streak, and
# that is exactly how it was reported -- "in the space between the nostrils
# there is a slight indentation".
#
# IT IS NOT AN INDENTATION AND NO GEOMETRY MOVES HERE. Ray-cast, the surface
# between the nostrils is a perfect plane: constant face normal across the
# whole span, no dip anywhere. Only the shading was wrong.
#
# WHY THIS RATHER THAN MORE GEOMETRY. `relax_flat` above records that
# subdividing the muzzle removed the same class of artefact in Blender and came
# back WORSE in the engine -- 736 faces to 2725, and Roblox quantises mesh
# normals, which shows as facets across tiny triangles. Setting a normal adds
# no triangles at all, so a constant normal quantises to a constant and that
# trap cannot fire.
#
# THE OUTER BOUNDARY IS LEFT ALONE, and that is the half that keeps the muzzle
# a muzzle. Those corners blend into the bevelled rim; forcing them flat turns
# the face into a hard disc with a ring round it. Only the interior and the
# nostril-rim corners are set -- the rims are already split at SMOOTH_ANGLE, so
# their bore-side normals are untouched and both nostrils stay sharp.
def flatten_planar_shading(ob, direction, forward_of, tol_deg=1.0):
    """Give every corner of the flat region the plane's own normal."""
    me = ob.data
    faces = [p for p in me.polygons
             if p.normal.dot(direction) > 0.85 and p.center.dot(direction) > forward_of]
    if not faces:
        return 0, 0.0
    # The plane itself is MEASURED rather than assumed: the most common face
    # normal by area among the forward-facing muzzle faces.
    buckets = {}
    for p in faces:
        k = tuple(round(c, 3) for c in p.normal)
        buckets[k] = buckets.get(k, 0.0) + p.area
    plane = Vector(max(buckets, key=buckets.get)).normalized()
    tol = math.radians(tol_deg)
    flat = {p.index for p in faces if p.normal.angle(plane) < tol}

    touch = {}
    for p in me.polygons:
        for vi in p.vertices:
            touch.setdefault(vi, set()).add(p.index)
    outer = {vi for vi in touch
             if any(i in flat for i in touch[vi])
             and any(i not in flat for i in touch[vi])}
    adj = {}
    for p in me.polygons:
        for k in p.edge_keys:
            adj.setdefault(k, []).append(p)
    rim = set()
    for k, fs in adj.items():
        if len(fs) == 2 and fs[0].normal.angle(fs[1].normal) > math.radians(SMOOTH_ANGLE):
            rim.update(k)
    outer -= rim

    loop_poly = {}
    for p in me.polygons:
        for li in p.loop_indices:
            loop_poly[li] = p.index
    worst, normals = 0.0, []
    for li, loop in enumerate(me.loops):
        n = me.corner_normals[li].vector.copy()
        if loop_poly[li] in flat and loop.vertex_index not in outer:
            worst = max(worst, math.degrees(n.angle(plane)))
            n = plane
        normals.append(n)
    me.normals_split_custom_set(normals)
    me.update()
    return len(flat), worst


# Forward of the same y the muzzle relax uses, so this cannot reach the ears or
# the tail -- on the joined trim, "faces looking down -Y" is not the muzzle
# alone. Read back below, because a pass that silently addressed nothing is the
# `shade_smooth` mistake one line up.
_muzzle_faces, _muzzle_worst = flatten_planar_shading(
    trim, Vector((0.0, -1.0, 0.0)), forward_of=1.05)
print("muzzle flat-plane shading: %d faces, worst corner normal was %.2f degrees off"
      % (_muzzle_faces, _muzzle_worst))
assert _muzzle_faces > 0, "muzzle flat-plane pass matched no faces"
for ob in (body, trim):
    _sharp = sum(1 for e in ob.data.edges if e.use_edge_sharp)
    print("%-6s all %d faces smooth, %d edges over %.0f degrees kept sharp"
          % (ob.name, len(ob.data.polygons), _sharp, SMOOTH_ANGLE))

# ---------------------------------------------------------------- UVs
# LAST, because everything before this changes the surface a UV would have been
# laid on: the booleans, the bevels, the muzzle densification and the weld all
# add or remove faces, and an unwrap done ahead of any of them would be an
# unwrap of a mesh that no longer exists.
#
# Each part gets its OWN 0..1 sheet, which is not a choice -- a MeshPart owns
# one texture, and the Body and the Trim are two MeshParts. That is also what
# a skin pack wants: the trim is the second tone, so a pack can pattern the
# body and leave the snout and ears plain, or the other way round.
uv_cylinder((body, trim))

# THE OLD REPORT IS KEPT AND STILL RUN, because it answers a question the
# cylinder's own report does not: whether an unwrap happened AT ALL. A mesh
# with no UV layer exports without one and a texture then has nowhere to live,
# which is the state this model shipped in for its whole life before the
# unwrap was added -- and it fails silently at every stage.
for ob in (body, trim):
    _r = uv_report(ob)
    if _r is None:
        print("%-6s UV UNWRAP PRODUCED NOTHING" % ob.name)


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


# BOUNDS COME FROM THE VERTICES, NOT FROM `bound_box`. That cache is not
# refreshed after direct vertex writes, and this build does almost all its
# shaping that way -- it reported the trim as z -1.391..1.418 against a real
# -1.020..1.309, which is a third of a stud of fiction in the numbers Roblox's
# `size` and `offset` get derived from.
def world_bounds(ob):
    pts = [ob.matrix_world @ v.co for v in ob.data.vertices]
    return ([min(p[i] for p in pts) for i in range(3)],
            [max(p[i] for p in pts) for i in range(3)])


print("=== PIG BUILD ===")
for ob in (body, trim):
    _lo, _hi = world_bounds(ob)
    print("%-6s verts %5d  tris %5d   x %6.3f..%6.3f  y %6.3f..%6.3f  z %6.3f..%6.3f"
          % (ob.name, len(ob.data.vertices), tris(ob),
             _lo[0], _hi[0], _lo[1], _hi[1], _lo[2], _hi[2]))

bb = [Vector(v) for o in (body, trim) for v in world_bounds(o)]
lo = Vector((min(p.x for p in bb), min(p.y for p in bb), min(p.z for p in bb)))
hi = Vector((max(p.x for p in bb), max(p.y for p in bb), max(p.z for p in bb)))
print("WHOLE  %.4f w x %.4f deep x %.4f high" % (hi.x - lo.x, hi.y - lo.y, hi.z - lo.z))

# THE FEET LAND ON THE LAWN BECAUSE `LIFT` SAYS SO, and that is asserted
# rather than assumed -- it is derived from LEG_BOTTOM, so anything that
# lowers the belly past the legs would silently bury the pig in its own plot.
assert abs(lo.z - LEG_BOTTOM) < 1e-6, "the legs are no longer the lowest thing"
print("lowest point -> world y %.3f (the lawn is %.1f)"
      % (LIFT + lo.z * SCALE, GAME_LAWN_Y))

# ============================================================
# WHAT THE GAME HAS TO BE TOLD
# ============================================================
# Every number below is measured off the mesh that is about to be exported, in
# the units PiggyBank and Config are written in. Typing any of them by hand is
# how a landmark ends up describing a body that no longer exists -- which this
# project has now done once per pig.
print("")
print("=== PASTE INTO Config.PIGGY_MESH ===")
for ob in (body, trim):
    _lo, _hi = world_bounds(ob)
    c = Vector(((_lo[0] + _hi[0]) / 2, (_lo[1] + _hi[1]) / 2, (_lo[2] + _hi[2]) / 2))
    off = to_rbx(c)
    size = Vector((_hi[0] - _lo[0], _hi[2] - _lo[2], _hi[1] - _lo[1])) * SCALE
    print("  %-5s offset = Vector3.new(%.4f, %.4f, %.4f)   size = Vector3.new(%.4f, %.4f, %.4f)"
          % (ob.name, off.x, off.y, off.z, size.x, size.y, size.z))

print("")
print("=== PASTE INTO PiggyBank ===")
print("  MESH_DIAL_OUT = %.3f" % DIAL_OUT)
print("  MESH_FACE.bodyCentre = Vector3.new(0, %.4f, 0)" % LIFT)

# --- eyes: the same seat the preview balls use, so the render is the truth
_d = Vector((EYE_DIR[0], EYE_DIR[1], EYE_DIR[2])).normalized()
_surf = _d * ray_ellipsoid(Vector((0, 0, 0)), _d, BODY_RX, BODY_RY, BODY_RZ)
_eye = to_rbx(_surf - _d * (EYE_R * (1.0 - EYE_PROUD)))
print("  MESH_FACE.eye = { x = %.3f, y = %.3f, z = %.3f }   (%.2f-stud ball, %.2f sunk)"
      % (abs(_eye.x), _eye.y, _eye.z, EYE_R * 2 * SCALE,
         EYE_R * (1.0 - EYE_PROUD) * SCALE))

# --- nostrils: seated in the dimples the snout already carries, so a dark
#     block sits in a hollow the model has rather than on a curve that has
#     nothing to hold it. The cutter's floor is NOS_SINK behind the face; the
#     block is 0.4 studs deep and hangs just in front of that floor.
_R = Matrix.Rotation(math.radians(-SNOUT_LIFT), 3, 'X')
_snout_at = Vector((0.0, SNOUT_SURF.y - SNOUT_OUT + SNOUT_DEPTH / 2.0, SNOUT_Z))
print("  (nostril seat was computed off `surf`, which the eye loop had"
      " overwritten -- snout %.4f against eye %.4f, a %.4f stud error)"
      % (SNOUT_SURF.y, surf.y, abs(surf.y - SNOUT_SURF.y) * SCALE))
_floor = Vector((NOS_DX, -SNOUT_DEPTH / 2.0 - NOS_RY + NOS_SINK + NOS_RY, NOS_Z))
_nos = to_rbx(_R @ (_floor - Vector((0, (0.4 / SCALE) / 2.0, 0))) + _snout_at)
print("  MESH_FACE.nostril = { x = %.3f, y = %.3f, z = %.3f }"
      % (abs(_nos.x), _nos.y, _nos.z))

# --- plaster: PiggyBank places it by DIRECTION and sinks it 0.06
_d = to_blend_dir(Vector((0.0, 0.62, 0.78)))
_surf = _d * ray_ellipsoid(Vector((0, 0, 0)), _d, BODY_RX, BODY_RY, BODY_RZ)
_pl = to_rbx(_surf - _d * (0.06 / SCALE))
print("  MESH_FACE.plaster = Vector3.new(0, %.3f, %.3f)" % (_pl.y, _pl.z))

print("")
print("=== PASTE INTO Config accessory meshAnchors ===")


def anchor(dir_rbx, proud, label):
    d = to_blend_dir(Vector(dir_rbx))
    p = d * ray_ellipsoid(Vector((0, 0, 0)), d, BODY_RX, BODY_RY, BODY_RZ)
    a = to_rbx(p) + to_rbx_dir(d) * proud
    print("  %-8s Vector3.new(0, %.3f, %.3f)   (%+.2f proud of the skin)"
          % (label + ":", a.y, a.z, proud))
    return a


# The hat goes on the crown BETWEEN the ears rather than dead centre, because
# this pig's ears are 2.16 studs forward of the middle -- and it also keeps
# the brim off the coin slit, which starts where the ears stop.
_ear_dir = to_rbx_dir(Vector((0.0, EAR_Y, 1.0)))
anchor(_ear_dir, -0.35, "hat")
# Glasses ride this pig's OWN eye line rather than the ball's, so the lenses
# land over the eyeballs instead of near where a different pig kept them.
anchor(to_rbx_dir(Vector((0.0, EYE_DIR[1], EYE_DIR[2]))), 0.28, "glasses")

# THE CAPE IS RAISED OFF THE BALL'S OWN ANGLE UNTIL IT CLEARS THE TAIL, which
# is measured rather than nudged. The ball pig hangs it at 24 degrees above
# the horizontal, and on this body that direction leaves the shell in the
# middle of the curl -- the "a cape hung where the tail already is" fault this
# project has recorded once already. Swept upward until the anchor stands a
# clear 0.6 studs off every point of the tail.
_best = None
for _deg in range(24, 61):
    _d = to_blend_dir(Vector((0.0, math.sin(math.radians(_deg)),
                              -math.cos(math.radians(_deg)))))
    _p = _d * ray_ellipsoid(Vector((0, 0, 0)), _d, BODY_RX, BODY_RY, BODY_RZ)
    _gap = min((_p - t).length for t in TAIL_PTS) * SCALE
    if _gap >= 0.6:
        _best = (_deg, _gap, _d)
        break
if _best is None:
    _best = (60, 0.0, _d)
print("  cape angle %d degrees above horizontal, clearing the tail by %.2f studs"
      % (_best[0], _best[1]))
anchor(to_rbx_dir(_best[2]), 0.10, "back")

print("  feet:    (%+.2f, %.1f, %+.2f) and (%+.2f, %.1f, %+.2f), mirrored on x"
      % (LEG_X * SCALE, GAME_LAWN_Y, -LEG_Y_BACK * SCALE,
         LEG_X * SCALE, GAME_LAWN_Y, -LEG_Y_FRONT * SCALE))

# ============================================================
# THE VAULT HAS TO BE CLEAR, AND NOTHING ELSE CAN SAY SO
# ============================================================
# A hole that is ALMOST cut looks exactly like a hole in every count, bound
# and render this file prints: the triangles are there, the bounds do not
# move, and from anything but a camera pointed down the bore it is a circle.
# Both faults this catches shipped past every other check here -- a shell
# sliver left by a cutter two thousandths too short, and a tail crossing the
# opening -- and were found by somebody looking at it in Blender.
#
# So the bore is walked with rays, on both objects separately, because "the
# hole is blocked" is two different repairs depending on which one it is.
print("")
blocked_body, blocked_trim = 0, 0
for _i in range(72):
    _a = 2.0 * math.pi * _i / 72
    for _f in (0.35, 0.60, 0.80, 0.95):
        _r = GAME_VAULT_R / SCALE * _f
        _u = DIAL_N.cross(Vector((1, 0, 0))).normalized()
        _v = DIAL_N.cross(_u).normalized()
        _p = HATCH + _u * (_r * math.cos(_a)) + _v * (_r * math.sin(_a))
        for _ob, _which in ((body, "body"), (trim, "trim")):
            _hit, _loc, _n, _idx = _ob.ray_cast(_p + DIAL_N * 0.60, -DIAL_N)
            if _hit and (_loc - _p).dot(DIAL_N) > -0.20:
                if _which == "body":
                    blocked_body += 1
                else:
                    blocked_trim += 1
print("vault bore: %d body samples blocked, %d trim samples blocked (of 288 each)"
      % (blocked_body, blocked_trim))

# AND THE PLATE HAS TO FIT, which is a different question from the hole being
# open: a disc of DIAL_MAX_R sits ON the skin around that hole, so what
# matters is how close the trim comes to the dial's AXIS over the slab of
# space the whole dial occupies.
_gold = 1.95 / SCALE
_out = DIAL_OUT / SCALE
_near = 9e9
for _v in trim.data.vertices:
    _d = _v.co - HATCH
    _t = _d.dot(DIAL_N)
    _rad = (_d - DIAL_N * _t).length
    if -0.10 < _t - _out < 0.45:
        _near = min(_near, _rad)
print("closest trim to the dial axis %.2f studs, against a gold plate of %.2f -> %s"
      % (_near * SCALE, _gold * SCALE,
         "clear by %.2f" % ((_near - _gold) * SCALE) if _near > _gold
         else "CLIPS by %.2f" % ((_gold - _near) * SCALE)))

# ============================================================
# SPLIT THE TRIM BACK INTO ITS PIECES
# ============================================================
# Cut out of the FINISHED trim rather than built separately, so each piece
# carries the exact surface, normals and UVs the whole trim carries -- see the
# tagging block above for why that ordering is not optional.
#
# WHAT IT BUYS: four colour channels on a skin instead of one. The bumblebee
# needs a yellow snout against black ears, which one part cannot express at
# any number of texture maps -- a MeshPart owns one `Color`.
#
# WHAT IT COSTS: four uploads instead of one, and four MeshParts per pig on a
# street of ten. `pig_trim.obj` IS STILL EXPORTED and the joined `Trim` is
# still what the blend keeps, so the single-part pig remains a working
# configuration -- this is an option in `Config.PIGGY_MESH` rather than a
# migration.
def part_from_group(src, gname):
    """One trim piece as its own object, cut from the joined mesh."""
    me = src.data.copy()
    me.name = "M_" + gname
    ob = bpy.data.objects.new(gname, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.matrix_world = src.matrix_world.copy()
    gi = src.vertex_groups[gname].index
    bm = bmesh.new()
    bm.from_mesh(me)
    dl = bm.verts.layers.deform.active
    # A VERTEX WITH NO DEFORM DATA IS NOT IN THE GROUP, which is the case that
    # has to be handled rather than assumed away: `clean_mesh` can dissolve
    # geometry between the tagging and here, and a vertex the join never gave
    # a group to would otherwise land in every piece.
    doomed = [v for v in bm.verts if dl is None or gi not in v[dl]]
    bmesh.ops.delete(bm, geom=doomed, context='VERTS')
    bm.to_mesh(me)
    bm.free()
    # HIDDEN FROM RENDER, BECAUSE THE JOINED TRIM IS STILL IN THE SCENE. Both
    # exist in the saved blend on purpose -- the whole trim is what every
    # existing preview and probe reads -- and left visible the pieces would
    # render ON TOP of the trim they were cut from, which is invisible in a
    # still and doubles the geometry in every shot. A preview that wants the
    # split flips these on and hides `Trim`.
    ob.hide_render = True
    return ob


TRIM_PARTS = []
for _gname, _ in TRIM_GROUPS:
    _p = part_from_group(trim, _gname)
    TRIM_PARTS.append(_p)
print("")
print("=== TRIM SPLIT ===")
_tot = 0
for _p in TRIM_PARTS:
    _lo, _hi = world_bounds(_p)
    _tot += len(_p.data.vertices)
    print("  %-6s verts %5d  tris %5d   y %6.3f..%6.3f  z %6.3f..%6.3f"
          % (_p.name, len(_p.data.vertices), tris(_p),
             _lo[1], _hi[1], _lo[2], _hi[2]))
# EVERY VERTEX LANDS IN EXACTLY ONE PIECE, ASSERTED RATHER THAN HOPED. A group
# that lost its tag would show up here as a shortfall, and the symptom in the
# game would be a hole in the animal that nobody could trace to this file.
assert _tot == len(trim.data.vertices), (
    "trim split lost or duplicated vertices: %d across the pieces against %d "
    "in the joined trim" % (_tot, len(trim.data.vertices)))
print("  all %d trim vertices accounted for across %d pieces"
      % (_tot, len(TRIM_PARTS)))

print("")
print("=== PASTE INTO Config.PIGGY_MESH (split trim) ===")
for _p in TRIM_PARTS:
    _lo, _hi = world_bounds(_p)
    _c = Vector(((_lo[0] + _hi[0]) / 2, (_lo[1] + _hi[1]) / 2,
                 (_lo[2] + _hi[2]) / 2))
    _off = to_rbx(_c)
    _size = Vector((_hi[0] - _lo[0], _hi[2] - _lo[2], _hi[1] - _lo[1])) * SCALE
    print("  %-6s offset = Vector3.new(%.4f, %.4f, %.4f)   size = Vector3.new(%.4f, %.4f, %.4f)"
          % (_p.name, _off.x, _off.y, _off.z, _size.x, _size.y, _size.z))

# ============================================================
# EXPORT
# ============================================================
# ONE FILE PER PART, AND THAT IS A CORRECTION PAID FOR WITH AN UPLOAD.
#
# This exported both objects into a single .obj on the understanding that
# Roblox's 3D importer splits on OBJECTS and merges MATERIALS. IT DOES NOT.
# Measured: a file carrying `o Body` and `o Trim` and no materials at all came
# back as ONE MeshPart named `default`, sized 12.000 x 13.971 x 17.041 --
# which is the whole animal, both objects fused. The previous body was lost
# the same way from the other direction, with two MATERIALS in one object.
#
# So neither objects nor materials reliably split anything, and the only
# input the importer cannot merge across is a FILE. One object per file is
# deterministic, needs no import setting to be set correctly, and cannot be
# undone by somebody clicking through the dialog.
#
# It costs one upload per part rather than one for the pig, which is the right
# trade: the alternative is discovering the merge again afterwards, which is
# what just happened and cost an upload anyway.
_EXPORTS = [(body, "pig_body"), (trim, "pig_trim")]
_EXPORTS += [(_p, "pig_" + _p.name.lower()) for _p in TRIM_PARTS]
for _ob, _name in _EXPORTS:
    bpy.ops.object.select_all(action='DESELECT')
    _ob.select_set(True)
    bpy.context.view_layer.objects.active = _ob
    _path = paths.pig(_name + ".obj")
    bpy.ops.wm.obj_export(filepath=_path,
                          export_selected_objects=True,
                          forward_axis='NEGATIVE_Z', up_axis='Y',
                          global_scale=SCALE,
                          export_materials=False,
                          export_normals=True,
                          export_uv=True,
                          export_triangulated_mesh=True)
    print("exported", _path)

bpy.ops.wm.save_as_mainfile(filepath=paths.RAW)
print("saved", paths.RAW)
