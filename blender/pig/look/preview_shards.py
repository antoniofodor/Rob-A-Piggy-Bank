# -*- coding: utf-8 -*-
"""The SHARD CREST on a baked coat, so the whole animal can be judged at once.

    blender --background --python look/preview_shards.py -- --skin stormstone

WHY THIS EXISTS. Storm Stone is the first skin in this catalogue whose look
does not live only in the sheet: the broken rock standing off its back and the
Neon bolts among them are GEOMETRY, built at runtime by
`PiggyModel.applyPattern`'s `shards` kind. So the ordinary loop renders half an
animal -- a coat with no crest -- and Studio renders the other half, a crest on
an untextured pig, because the sheets are not uploaded and a `SurfaceAppearance`
needs an asset id. Neither picture is the thing being designed.

This puts them in one frame. It APPENDS INTO THE ALREADY-BUILT VIEW SCENE
rather than rebuilding one, which is `preview_fur.py`'s call and is made here
for the same reason: a second copy of `make_view_blend.py`'s sun rig would be
the near-identical duplicate this project keeps recording, and it would be the
duplicate that decides a shape. Run the ordinary loop first; this reads its
output.

**IT IS A PORT OF `buildShards`, AND A PORT IS A SECOND IMPLEMENTATION, WHICH
THIS PROJECT NORMALLY REFUSES.** Worth saying plainly rather than leaving to be
discovered. The rule that is bent is real -- `RideSound` kept a second copy of
the ride-key grammar and broke inside the hour -- and there is no way round it
here: the placement is Luau running in Roblox, and nothing in Blender can call
it. What makes it affordable is that this file DECIDES NOTHING. It renders a
picture to look at; the shipped geometry comes from `PiggyModel` and always
will. If the two ever disagree, `PiggyModel` is right by construction and this
is the file to fix.

The two things that MUST track it are the placement and the seating, and both
are copied statement for statement below. The tunables are copied too and are
listed in one dict, so a `Config.SKINS` row and this preview can be diffed by
eye.

**THE DICE ARE DIFFERENT AND THE DESIGN IS THE SAME.** Roblox's `Random` and
Python's are different streams, so shard N here is not shard N in game. What is
faithful is everything that decides the LOOK: how many, how big, how they vary,
where they may and may not sit, which are lit, and how deeply each is seated.
Judge the crest, never an individual spike.

THE FRAME IS THE ONE THING THAT IS NOT A COPY, because the two spaces disagree:

    Roblox      +X across   +Y up      +Z nose
    Blender     +X across   +Z up      -Y nose

so a Roblox vector `(rx, ry, rz)` is `(rx, -rz, ry)` here. Every position is
solved in ROBLOX space -- statement for statement with `buildShards` -- and
mapped once, per VERTEX, at the end. Mapping the rotation matrix instead is the
same arithmetic with two more places to get a sign wrong, and this project has
paid for a wrong sign on an axis five times.

THE SPHERE IS MEASURED OFF THE BODY RATHER THAN PINNED. `PiggyBank` passes
`BODY_R = 6` against a Blender body reaching +-1.000 across, so the pattern
sphere is radius 1.0 here and every size in the spec is a fraction of it either
way. Measuring it anyway costs one bounding box and means a regenerated body
carries this with it -- the rule the vault cap's normal already records, where
a pinned vector was solved against one particular mesh.
"""
import os
import sys

# THE DEPTH-INDEPENDENT BOOTSTRAP -- see `preview_fur.py`. A hardcoded `..` is
# the thing that breaks silently the first time anything is refiled.
_root = os.path.dirname(os.path.abspath(__file__))
while not os.path.exists(os.path.join(_root, "paths.py")):
    _up = os.path.dirname(_root)
    if _up == _root:
        raise RuntimeError("cannot find paths.py above %s" % __file__)
    _root = _up
sys.path.insert(0, _root)
import paths                                        # noqa: E402
import bpy                                          # noqa: E402
import math                                         # noqa: E402
import random                                       # noqa: E402
from mathutils import Vector                        # noqa: E402

_argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]


def _arg(name, default=None):
    return _argv[_argv.index(name) + 1] if name in _argv else default


SKIN = _arg("--skin", "stormstone")

# ---------------------------------------------------------------- the spec
# THE CANDIDATE `pattern` BLOCK FOR THE `Config.SKINS` ROW, which does not
# exist yet -- so at the moment this file is where these numbers LIVE rather
# than a copy of somewhere they already are. The moment a row is written this
# becomes a duplicate and has to be kept in step by hand; there is no way to
# read a Luau table from Blender, and that is the same standing cost
# `skin_colours.py` pays from the other direction by PARSING `Config.luau`.
#
# Listed in one dict so the two can be diffed by eye, and every key is read by
# `buildShards` under exactly this name.
SPEC = dict(
    count=34, size=0.30, vary=0.40,
    thick=0.55, depth=1.05, rake=20.0, twist=28.0,
    lo=0.25, hi=0.97, parting=0.26,
    faceStop=0.45, faceHigh=0.55,
    # A LIT DRAW IS A ZIGZAG CHAIN AND NOT A SPIKE -- `boltChain` in
    # `PiggyModel`. `glowEvery` still says how often the spiral produces one;
    # everything else about its shape is a `bolt*` key.
    glowEvery=4,
    boltSegs=5, boltLen=0.88, boltKink=36.0, boltWide=0.115,
    # NOT A FLAT RIBBON, WHICH THE FIRST ZIGZAG WAS. At 0.35 a segment is a
    # sheet of paper, and a sheet of paper seen edge-on is a hairline -- so a
    # bolt whose plane happened to face away from the camera nearly vanished,
    # and half of them did. Reading a bolt must not depend on which way its
    # plane was rolled, so it is thick enough to have a side.
    boltThin=0.55, boltTaper=0.80, boltRake=14.0,
    seed=21,
)
# THE STONE IS THE PLATE COLOUR AND NOT A DARKER ONE, which the first build got
# wrong. Near-black shards on a near-black hide have no facets in them -- what
# came back was a fan of flat black PADDLES, because the only thing separating
# a shard from the coat was its silhouette. At the mid plate tone the facets
# catch the sun and read as the same rock the animal is made of, which is what
# a shard is: a piece of the hide standing up.
STONE = (52, 58, 70)
# DEEPER THAN IT LOOKS IT SHOULD BE, AND THAT IS THE NEON LESSON ARRIVING IN
# BLENDER. Driven at an emission strength high enough to read against a hide
# this dark, (94, 226, 252) clipped every channel and came back WHITE -- the
# bolts stopped being cyan at all, which is the same failure `CLAUDE.md`
# records four times for Neon parts: what survives being rendered bright is
# SATURATION, and a colour near white has nothing left to be. Deepened, and the
# burn brought down to meet it.
BOLT = (52, 200, 246)
# HOW HARD THE BOLTS BURN. Roblox `Neon` renders a colour flat out and the
# BloomEffect takes it from there; Blender has no such material, so an Emission
# strength stands in for it. It is a LOOK-ALIKE and not a measurement -- what
# the game actually does with a Neon part is recorded in `CLAUDE.md`, and the
# one number known for certain is that a pale colour blows out and a saturated
# one survives, which is why BOLT is saturated in both places.
BURN = float(_arg("--burn", "5.0"))

# `PiggyModel`'s own constants, and they have to stay in step with it.
LIFT = 0.02
CROWN_LIMIT = 0.72
GOLDEN_ANGLE = 2.39996323


def srgb(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def clamp(v, lo, hi):
    return lo if v < lo else (hi if v > hi else v)


# ------------------------------------------------------------- the scene
bpy.ops.wm.open_mainfile(filepath=paths.skin_view(SKIN))

body = bpy.data.objects.get("Body")
if body is None:
    raise SystemExit("  ! no Body in %s -- run make_view_blend.py first"
                     % paths.skin_view(SKIN))

# THE SPHERE, MEASURED. Corners of the world bounding box; the half-X-extent is
# the radius the game's `BODY_R` corresponds to, and the centre is where the
# pattern is seated from.
pts = [body.matrix_world @ Vector(c) for c in body.bound_box]
lo_c = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi_c = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
CENTRE = (lo_c + hi_c) / 2.0
R = (hi_c.x - lo_c.x) / 2.0
print("  body sphere: centre (%.3f, %.3f, %.3f) radius %.3f"
      % (CENTRE.x, CENTRE.y, CENTRE.z, R))


def to_blender(v):
    """A Roblox (x across, y up, z nose) vector, in this scene's frame."""
    return Vector((v[0], -v[2], v[1]))


def norm(v):
    m = math.sqrt(sum(c * c for c in v))
    return (v[0] / m, v[1] / m, v[2] / m)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1],
            a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def euler_xyz(rx, ry, rz):
    """`CFrame.Angles(x, y, z)`, which Roblox composes as Rx * Ry * Rz."""
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)
    rxm = ((1, 0, 0), (0, cx, -sx), (0, sx, cx))
    rym = ((cy, 0, sy), (0, 1, 0), (-sy, 0, cy))
    rzm = ((cz, -sz, 0), (sz, cz, 0), (0, 0, 1))
    return matmul(matmul(rxm, rym), rzm)


def axis_angle(k, v, ang):
    """Rodrigues: `CFrame.fromAxisAngle(k, ang):VectorToWorldSpace(v)`."""
    c, si = math.cos(ang), math.sin(ang)
    kv = cross(k, v)
    kd = dot(k, v)
    return tuple(v[i] * c + kv[i] * si + k[i] * kd * (1 - c) for i in range(3))


def matmul(a, b):
    return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3))
                       for j in range(3)) for i in range(3))


def apply(m, v):
    return tuple(sum(m[i][k] * v[k] for k in range(3)) for i in range(3))


# ------------------------------------------------------- port of buildShards
rng = random.Random(SPEC["seed"])


def uni():
    """`Random:NextNumber(-1, 1)`."""
    return rng.uniform(-1.0, 1.0)


count = SPEC["count"]
height = clamp(SPEC["size"], 0.06, 0.45) * R
vary = clamp(SPEC["vary"], 0.0, 0.8)
thick = clamp(SPEC["thick"], 0.08, 1.0) * height
depth = clamp(SPEC["depth"], 0.20, 2.0) * height
rake = math.radians(clamp(SPEC["rake"], -60, 60))
twist = math.radians(clamp(SPEC["twist"], 0, 80))
lo = clamp(SPEC["lo"], -0.9, 0.9)
hi = clamp(SPEC["hi"], lo + 0.05, 1.0)
parting = clamp(SPEC["parting"], 0.0, 0.8)
faceStop = clamp(SPEC["faceStop"], -1, 1)
faceHigh = clamp(SPEC["faceHigh"], -1, 1)
glowEvery = max(0, int(SPEC["glowEvery"]))

stone_v, stone_f, bolt_v, bolt_f = [], [], [], []


def box(verts, faces, centre, xl, yl, zl, sx, sy, sz):
    """A block, given its own three axes -- the eight corners, mapped once."""
    o = len(verts)
    for ax in (-1, 1):
        for ay in (-1, 1):
            for az in (-1, 1):
                p = tuple(centre[i] + xl[i] * ax * sx / 2 + yl[i] * ay * sy / 2
                          + zl[i] * az * sz / 2 for i in range(3))
                verts.append(to_blender(p) + CENTRE)
    # corner index is (ax, ay, az) in that nesting order
    f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1),
         (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    faces.extend([tuple(o + i for i in q) for q in f])


def bolt_chain(nn):
    """`boltChain` in `PiggyModel`, statement for statement."""
    segs = int(clamp(SPEC["boltSegs"], 2, 8))
    total = clamp(SPEC["boltLen"], 0.10, 1.20) * R
    kink = math.radians(clamp(SPEC["boltKink"], 0, 80))
    wide = clamp(SPEC["boltWide"], 0.01, 0.40) * R
    thin = clamp(SPEC["boltThin"], 0.05, 1.0)
    taper = clamp(SPEC["boltTaper"], 0.30, 1.0)
    rake = math.radians(clamp(SPEC["boltRake"], -60, 60))

    tail = (0.0, 0.0, -1.0)
    along = tuple(tail[i] - nn[i] * dot(nn, tail) for i in range(3))
    if math.sqrt(dot(along, along)) < 1e-3:
        up = (0.0, 1.0, 0.0)
        along = tuple(up[i] - nn[i] * dot(nn, up) for i in range(3))
    along = norm(along)
    d0 = norm(tuple(nn[i] * math.cos(rake) + along[i] * math.sin(rake)
                    for i in range(3)))

    axis = cross(along, nn)
    if math.sqrt(dot(axis, axis)) < 1e-3:
        axis = (1.0, 0.0, 0.0)
    axis = norm(axis_angle(d0, norm(axis), uni() * math.pi))

    at = tuple(nn[i] * (R - wide) for i in range(3))
    length = (total / segs if taper >= 0.999
              else total * (1 - taper) / (1 - taper ** segs))
    w = wide
    for i in range(1, segs + 1):
        sign = 1.0 if i % 2 == 1 else -1.0
        d = norm(axis_angle(axis, d0, kink * sign))
        yl = d
        zl = axis
        xl = cross(yl, zl)
        mid = tuple(at[j] + d[j] * (length / 2) for j in range(3))
        box(bolt_v, bolt_f, mid, xl, yl, zl, w, length, w * thin)
        at = tuple(at[j] + d[j] * length for j in range(3))
        length *= taper
        w *= taper


placed, attempt = 0, 0
while placed < count and attempt < count * 10:
    attempt += 1
    t = (attempt - 0.5) / count
    y = clamp(hi - (t % 1.0) * (hi - lo) + uni() * 0.06, lo, hi)
    ringF = math.sqrt(max(1.0 - y * y, 0.0))
    theta = attempt * GOLDEN_ANGLE + uni() * 0.30
    d = (ringF * math.cos(theta), y, ringF * math.sin(theta))
    if math.sqrt(dot(d, d)) <= 1e-4:
        continue
    n = norm(d)
    in_face = n[2] > faceStop and n[1] < faceHigh
    in_parting = n[1] > CROWN_LIMIT and abs(n[0]) < parting
    if in_face or in_parting:
        continue

    placed += 1
    if glowEvery > 0 and placed % glowEvery == 0:
        bolt_chain(n)
        continue
    h = height * (1 + uni() * vary)
    dd = depth * (1 + uni() * vary * 0.6)
    w = thick * (1 + uni() * vary * 0.6)

    tail = (0.0, 0.0, -1.0)
    along = tuple(tail[i] - n[i] * dot(n, tail) for i in range(3))
    if math.sqrt(dot(along, along)) < 1e-3:
        up = (0.0, 1.0, 0.0)
        along = tuple(up[i] - n[i] * dot(n, up) for i in range(3))
    zl = norm(along)
    yl = n
    xl = cross(yl, zl)

    lean = rake * (1 + uni() * 0.35)
    spin = uni() * twist
    # `CFrame.fromMatrix(0, xl, yl)` -- columns are the local axes.
    base_m = ((xl[0], yl[0], zl[0]),
              (xl[1], yl[1], zl[1]),
              (xl[2], yl[2], zl[2]))
    rot = matmul(base_m, euler_xyz(lean, spin, 0.0))
    up_v = (rot[0][1], rot[1][1], rot[2][1])          # rot.UpVector

    half_diag = math.sqrt(w * w + dd * dd) / 2.0
    sink = (half_diag * half_diag / (2.0 * R)
            + abs(math.sin(lean)) * dd / 2.0
            + LIFT * R)
    pos = tuple(n[i] * (R - sink) + up_v[i] * (h / 2.0) for i in range(3))

    # A WEDGE'S SOLID, RAYCAST RATHER THAN ASSUMED (`CLAUDE.md`): full height
    # at +Z, falling to nothing at -Z, extruded along X. Six vertices.
    hx, hy, hz = w / 2.0, h / 2.0, dd / 2.0
    local = ((-hx, -hy, -hz), (-hx, -hy, hz), (-hx, hy, hz),
             (hx, -hy, -hz), (hx, -hy, hz), (hx, hy, hz))
    verts, faces = stone_v, stone_f
    o = len(verts)
    for lv in local:
        wv = tuple(pos[i] + apply(rot, lv)[i] for i in range(3))
        verts.append(to_blender(wv) + CENTRE)
    faces.extend([(o + 0, o + 1, o + 2), (o + 3, o + 5, o + 4),
                  (o + 0, o + 3, o + 4, o + 1), (o + 1, o + 4, o + 5, o + 2),
                  (o + 0, o + 2, o + 5, o + 3)])

print("  placed %d marks in %d draws -- %d shards, %d bolts of %d segments"
      % (placed, attempt, len(stone_v) // 6,
         len(bolt_v) // (8 * int(SPEC["boltSegs"])), SPEC["boltSegs"]))


def make(name, verts, faces, rgb, emit):
    if not verts:
        return
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    col = tuple(srgb(v) for v in rgb) + (1.0,)
    bsdf.inputs["Base Color"].default_value = col
    bsdf.inputs["Roughness"].default_value = 0.90
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.05
    if emit:
        # STANDING IN FOR `Material.Neon` -- see `BURN`. Emission on the same
        # BSDF rather than a second shader, so the shard still takes a little
        # of the scene's own light and does not read as a cut-out.
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = col
            bsdf.inputs["Emission Strength"].default_value = BURN
    ob.data.materials.append(mat)
    return ob


make("Shards", stone_v, stone_f, STONE, False)
make("Bolts", bolt_v, bolt_f, BOLT, True)

# ------------------------------------------------------------- the shots
cam = bpy.data.objects["View"]
scene = bpy.context.scene


def point_at(o, t):
    o.rotation_euler = (Vector(t) - o.location).to_track_quat('-Z',
                                                             'Y').to_euler()


# THE SAME FOUR THE ORDINARY LOOP USES, so this render and `view_<skin>_*.png`
# can be laid side by side and the only difference is the crest.
SHOTS = (("hero", (-3.9, -5.4, 2.0), (0, -0.05, 0.05)),
         ("low", (-2.4, -4.6, 0.15), (0, -0.05, 0.35)),
         ("crown", (-2.2, -3.6, 3.4), (0, -0.05, 0.30)),
         ("spine", (0.0, 5.6, 2.6), (0, 0.10, 0.20)))

for shot, loc, aim in SHOTS:
    cam.location = Vector(loc)
    point_at(cam, aim)
    out = paths.render("shards_%s_%s.png" % (SKIN, shot))
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("  rendered %s" % shot, flush=True)

print("  wrote renders/shards_%s_*.png -- coat and crest in one frame" % SKIN)
