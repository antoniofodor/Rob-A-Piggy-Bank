# -*- coding: utf-8 -*-
"""CLOSED-BACK PROOF: fill the vault hatch on a COPY of a pig blend.

    blender.exe --background --python make/closedback_fill.py -- --in <copy.blend> --out <closed.blend>

WHAT IT DOES. `build_pig.py` bores the vault hatch through the solidified
shell with a 48-sided cylinder along `dialCFrame`'s own axis, so on the body
the hatch is not a boundary loop at all -- it is 48 WALL faces joining a
68-vertex loop on the outer skin to a 66-vertex loop on the inner skin. This
deletes those wall faces and puts back the OUTER skin the boolean removed.

THE FILL IS THE QUAD-SPHERE'S OWN FACES, NOT A NEW TRIANGULATION. Every skin
vertex outside the rim is an untouched vertex of `build_pig.py`'s quad-sphere
(SIMPLE subdivision 4, spherified, scaled 1.00 / 1.08 / 0.96), so the same
generator is run again here, its vertices are matched to the survivors, the
faces the cutter swallowed whole are recreated, and every face the cutter
CLIPPED is completed with the piece it lost -- the removed corners plus the
rim vertices that landed inside it. The cap therefore carries the identical
facet pattern to the rump around it, and every new vertex is on the analytic
ellipsoid by construction.

Two generic fills were measured and rejected first. A beauty triangulation
refined to the quads' density left triangles whose three vertices all sit on
the rim (area 0.00001, normal 41 degrees off); dissolving those into n-gons
photographed as a hard-edged bright wedge on the rump, and flipping them ran
away. Only the generator's own faces have no such case.

WHAT IT DOES NOT TOUCH. Every existing face keeps its exact UVs, so a sheet
baked against the old layout still fits every old face. The coin slit is a
separate boolean (`build_pig.py` "COIN SLOT") and shares no vertex with the
hatch; it is left alone. The trim parts are not opened at all. The inner
skin's hole is closed with a plain fill: it is inside a closed shell and can
never be seen.

WHERE THE FILL'S UVs GO. New faces need sheet space. The existing layout is
rasterised and the largest empty square found -- with the shipped unwrap it
is a 0.14-wide gap Smart UV Project left at the top of the sheet -- and the
outer cap is planar-projected into it at the body's own texel density. So
the fill does NOT overlap any old island, which keeps a re-bake clean; the
price is that on an un-rebaked sheet that region is unbaked, which is the
whole answer to "do the old sheets survive" and is photographed rather than
argued.

NEVER RUN THIS ON THE MASTER. It is a proof; `--in` should be a copy.
"""
import os as _os, sys as _sys
_root = _os.path.dirname(_os.path.abspath(__file__))
while not _os.path.exists(_os.path.join(_root, "paths.py")):
    _up = _os.path.dirname(_root)
    if _up == _root:
        raise RuntimeError("cannot find paths.py above %s" % __file__)
    _root = _up
if _root not in _sys.path:
    _sys.path.insert(0, _root)

import bpy, bmesh, math, sys, collections
from mathutils import Vector
from mathutils.kdtree import KDTree

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SRC = arg("--in", None)
DST = arg("--out", None)
if not SRC or not DST:
    raise SystemExit("usage: -- --in <copy.blend> --out <closed.blend>")
if _os.path.abspath(SRC) == _os.path.abspath(DST):
    raise SystemExit("refusing to overwrite the input")

# --- the game's own numbers, as build_pig.py states them -------------------
RX, RY, RZ = 1.00, 1.08, 0.96
BODY_SUB = 4
SCALE = 6.0
WALL = 0.30 / SCALE
VAULT_R = 1.43 / SCALE
GAME_LAWN_Y, LEG_BOTTOM = 0.5, -1.02
LIFT = GAME_LAWN_Y - LEG_BOTTOM * SCALE
drop, R = 6.6 - 8.5, 6.0
_ring = math.sqrt(R * R - drop * drop)
_n_rbx = Vector((0.0, drop, -_ring)).normalized()
N = Vector((_n_rbx.x, -_n_rbx.z, _n_rbx.y)).normalized()
O = Vector((0.0, 0.0, (8.5 - LIFT) / SCALE))


def ray_ell(o, d, rx, ry, rz):
    a = (d.x / rx) ** 2 + (d.y / ry) ** 2 + (d.z / rz) ** 2
    b = 2.0 * (o.x * d.x / rx ** 2 + o.y * d.y / ry ** 2 + o.z * d.z / rz ** 2)
    c = (o.x / rx) ** 2 + (o.y / ry) ** 2 + (o.z / rz) ** 2 - 1.0
    return (-b + math.sqrt(max(b * b - 4 * a * c, 0.0))) / (2 * a)


HATCH = O + N * ray_ell(O, N, RX, RY, RZ)
U = N.cross(Vector((1, 0, 0))).normalized()
V = N.cross(U).normalized()


def axis_dist(p):
    d = p - HATCH
    return (d - N * d.dot(N)).length, d.dot(N)


def rho(p, w=0.0):
    return math.sqrt((p.x / (RX - w)) ** 2 + (p.y / (RY - w)) ** 2 + (p.z / (RZ - w)) ** 2)


bpy.ops.wm.open_mainfile(filepath=SRC)
body = bpy.data.objects["Body"]
me = body.data

# ---------------------------------------------------------------- the generator's sphere
# build_pig.quad_sphere + scale_verts, reproduced to the letter (it cannot be
# imported: that file runs the whole build at import).
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.mesh.primitive_cube_add(size=2)
qob = bpy.context.active_object
qm = qob.modifiers.new("sub", 'SUBSURF')
qm.subdivision_type = 'SIMPLE'
qm.levels = qm.render_levels = BODY_SUB
bpy.ops.object.modifier_apply(modifier="sub")
for v in qob.data.vertices:
    x, y, z = v.co
    x2, y2, z2 = x * x, y * y, z * z
    v.co = Vector((
        x * math.sqrt(max(0.0, 1.0 - y2 / 2 - z2 / 2 + y2 * z2 / 3)),
        y * math.sqrt(max(0.0, 1.0 - z2 / 2 - x2 / 2 + z2 * x2 / 3)),
        z * math.sqrt(max(0.0, 1.0 - x2 / 2 - y2 / 2 + x2 * y2 / 3)),
    ))
for v in qob.data.vertices:
    v.co.x *= RX; v.co.y *= RY; v.co.z *= RZ
Q_VERTS = [Vector(v.co) for v in qob.data.vertices]
Q_FACES = [tuple(p.vertices) for p in qob.data.polygons]
bpy.data.objects.remove(qob, do_unlink=True)
print("generator sphere: %d verts, %d quads" % (len(Q_VERTS), len(Q_FACES)))

# ---------------------------------------------------------------- the body
bm = bmesh.new()
bm.from_mesh(me)
bm.verts.ensure_lookup_table(); bm.edges.ensure_lookup_table(); bm.faces.ensure_lookup_table()
uv = bm.loops.layers.uv.active
faces_before, verts_before = len(bm.faces), len(bm.verts)

wall = []
for f in bm.faces:
    c = f.calc_center_median()
    r, t = axis_dist(c)
    if r < VAULT_R + 0.03 and -0.2 < t < 0.1 and abs(f.normal.dot(N)) < 0.5:
        wall.append(f)
assert len(wall) == 48, "expected the 48-sided bore wall, found %d faces" % len(wall)
wallverts = set(v for f in wall for v in f.verts)
n_outer = sum(1 for v in wallverts if rho(v.co) > 1.0 - WALL * 0.5)
n_inner = len(wallverts) - n_outer
print("bore: %d wall faces, outer loop %d verts, inner loop %d verts" % (len(wall), n_outer, n_inner))
wall_us = [l[uv].uv.x for f in wall for l in f.loops]
wall_vs = [l[uv].uv.y for f in wall for l in f.loops]
print("wall UV footprint (orphaned on old sheets): u %.3f..%.3f v %.3f..%.3f"
      % (min(wall_us), max(wall_us), min(wall_vs), max(wall_vs)))
print("sharp (non-smooth) edges touching the bore before: %d"
      % sum(1 for e in bm.edges if (e.verts[0] in wallverts or e.verts[1] in wallverts) and not e.smooth))

# ---------------------------------------------------------------- UV free space
RES = 512
occ = bytearray(RES * RES)


def mark_tri(a, b, c):
    xs = [a.x, b.x, c.x]; ys = [a.y, b.y, c.y]
    x0 = max(0, int(min(xs) * RES) - 1); x1 = min(RES - 1, int(max(xs) * RES) + 1)
    y0 = max(0, int(min(ys) * RES) - 1); y1 = min(RES - 1, int(max(ys) * RES) + 1)
    d = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
    if abs(d) < 1e-12:
        return
    for py in range(y0, y1 + 1):
        yy = (py + 0.5) / RES
        for px in range(x0, x1 + 1):
            xx = (px + 0.5) / RES
            l1 = ((b.y - c.y) * (xx - c.x) + (c.x - b.x) * (yy - c.y)) / d
            l2 = ((c.y - a.y) * (xx - c.x) + (a.x - c.x) * (yy - c.y)) / d
            if l1 >= -0.02 and l2 >= -0.02 and 1 - l1 - l2 >= -0.02:
                occ[py * RES + px] = 1


for f in bm.faces:
    pts = [l[uv].uv.copy() for l in f.loops]
    for i in range(1, len(pts) - 1):
        mark_tri(pts[0], pts[i], pts[i + 1])
DIL = 6      # past the 8-texel bake bleed, inside the 0.02 pack gap
occ2 = bytearray(occ)
for y in range(RES):
    for x in range(RES):
        if occ[y * RES + x]:
            for dy in range(-DIL, DIL + 1):
                yy = y + dy
                if 0 <= yy < RES:
                    row = yy * RES
                    for dx in range(-DIL, DIL + 1):
                        xx = x + dx
                        if 0 <= xx < RES:
                            occ2[row + xx] = 1
best = (0, 0, 0)
dp = [0] * (RES * RES)
for y in range(RES):
    for x in range(RES):
        i = y * RES + x
        if occ2[i] or x < 4 or y < 4 or x >= RES - 4 or y >= RES - 4:
            dp[i] = 0
        else:
            dp[i] = 1 if (x == 0 or y == 0) else 1 + min(dp[i - 1], dp[i - RES], dp[i - RES - 1])
        if dp[i] > best[0]:
            best = (dp[i], x, y)
side = best[0] / RES
cx = (best[1] - best[0] / 2.0 + 0.5) / RES
cy = (best[2] - best[0] / 2.0 + 0.5) / RES
print("UV sheet occupancy %.1f%%; largest empty square %.4f wide centred (%.4f, %.4f)"
      % (100.0 * sum(occ) / (RES * RES), side, cx, cy))


def uvarea(faces):
    a = 0.0
    for f in faces:
        pts = [l[uv].uv for l in f.loops]
        for i in range(1, len(pts) - 1):
            a += abs((pts[i] - pts[0]).cross(pts[i + 1] - pts[0])) / 2
    return a


body_density = uvarea(bm.faces) / sum(f.calc_area() for f in bm.faces)
want_r = math.sqrt(math.pi * VAULT_R ** 2 * 1.03 * body_density / math.pi)
have_r = side / 2.0 - 0.004
fill_r = min(want_r, have_r)
print("body texel density: %.5f sheet per unit^2 -> a full-density cap wants UV radius %.4f; "
      "free square allows %.4f; using %.4f (%.0f%% of body linear density)"
      % (body_density, want_r, have_r, fill_r, 100.0 * fill_r / want_r))

# ---------------------------------------------------------------- delete the wall
bmesh.ops.delete(bm, geom=wall, context='FACES')


def cap_uvs(faces, centre, radius):
    for f in faces:
        for l in f.loops:
            d = l.vert.co - HATCH
            l[uv].uv = (centre[0] + d.dot(U) / VAULT_R * radius, centre[1] + d.dot(V) / VAULT_R * radius)


# ---------------------------------------------------------------- outer cap
# Match the generator's vertices to the body's surviving outer-skin vertices.
kd = KDTree(len(bm.verts))
for v in bm.verts:
    kd.insert(v.co, v.index)
kd.balance()
TOL = 1e-4
q_to_b = {}
removed = set()
for qi, qco in enumerate(Q_VERTS):
    co, idx, dist = kd.find(qco)
    if dist < TOL:
        q_to_b[qi] = bm.verts[idx]
    else:
        removed.add(qi)
near_hatch = {qi for qi in removed if axis_dist(Q_VERTS[qi])[0] < VAULT_R + 0.05}
print("generator verts matched %d, unmatched %d, of which inside the hatch %d (the rest are the coin slit)"
      % (len(q_to_b), len(removed), len(near_hatch)))

rim = [v for v in bm.verts if abs(axis_dist(v.co)[0] - VAULT_R) < 2e-3
       and rho(v.co) > 1.0 - WALL * 0.5 and any(e.is_boundary for e in v.link_edges)]
assert len(rim) == n_outer, "outer rim: found %d boundary verts, expected %d" % (len(rim), n_outer)


def in_face(qf, p, eps=2e-4):
    """Is p on/inside the generator face (a near-planar convex quad)?"""
    pts = [Q_VERTS[i] for i in qf]
    n = (pts[1] - pts[0]).cross(pts[2] - pts[0])
    if n.length < 1e-12:
        return False
    n.normalize()
    pp = p - n * (p - pts[0]).dot(n)
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        if (b - a).cross(pp - a).dot(n) < -eps:
            return False
    return True


# Which generator faces did the cutter touch: any face with a vertex inside
# the hatch, or a rim vertex inside/on it.
touched = {}
for fi, qf in enumerate(Q_FACES):
    if any(axis_dist(Q_VERTS[i])[0] > VAULT_R + 0.3 for i in qf):
        continue
    rem = [i for i in qf if i in near_hatch]
    rimv = [v for v in rim if in_face(qf, v.co)]
    if rem or rimv:
        touched[fi] = (rem, rimv)
whole = [fi for fi, (rem, rimv) in touched.items() if len(rem) == len(Q_FACES[fi])]
partial = [fi for fi in touched if fi not in set(whole)]
print("generator faces swallowed whole: %d, clipped: %d" % (len(whole), len(partial)))
assigned = collections.Counter(v for fi in touched for v in touched[fi][1])
unassigned = [v for v in rim if v not in assigned]
assert not unassigned, "%d rim verts lie in no generator face" % len(unassigned)

newv = {}


def bvert(qi):
    if qi in q_to_b:
        return q_to_b[qi]
    if qi not in newv:
        newv[qi] = bm.verts.new(Q_VERTS[qi])
    return newv[qi]


def ordered_face(verts, normal_hint):
    """A convex polygon's vertices in CCW order about `normal_hint`."""
    c = sum((v.co for v in verts), Vector()) / len(verts)
    n = normal_hint.normalized()
    a = (verts[0].co - c)
    a = (a - n * a.dot(n)).normalized()
    b = n.cross(a)
    return sorted(verts, key=lambda v: math.atan2((v.co - c).dot(b), (v.co - c).dot(a)))


new_faces = []
for fi in whole:
    qf = Q_FACES[fi]
    vs = [bvert(i) for i in qf]
    f = bm.faces.new(vs)
    new_faces.append(f)
for fi in partial:
    rem, rimv = touched[fi]
    qf = Q_FACES[fi]
    pts = [Q_VERTS[i] for i in qf]
    qn = (pts[1] - pts[0]).cross(pts[2] - pts[0])
    if qn.dot(sum(pts, Vector())) < 0:      # outward, whatever the generator's winding
        qn = -qn
    vs = [bvert(i) for i in rem] + list(rimv)
    vs = list({v.index if v.index >= 0 else id(v): v for v in vs}.values())
    if len(vs) < 3:
        continue
    vs = ordered_face(vs, qn)
    try:
        f = bm.faces.new(vs)
    except ValueError as ex:
        print("  ! clipped face %d could not be completed (%s): %d verts" % (fi, ex, len(vs)))
        continue
    new_faces.append(f)
bm.faces.ensure_lookup_table(); bm.verts.ensure_lookup_table()
# Winding is taken from the ellipsoid, not trusted: every new face outward.
for f in new_faces:
    if f.normal.dot(f.calc_center_median()) < 0:
        f.normal_flip()
print("completed: %d faces (sizes %s), %d new verts, all on the generator's ellipsoid"
      % (len(new_faces), dict(collections.Counter(len(f.verts) for f in new_faces)), len(newv)))

# THE RIM ITSELF GOES, AND THAT IS WHAT MAKES THE CAP INVISIBLE. With the
# completions in place every rim vertex sits on exactly two near-coplanar
# faces -- the clipped n-gon and its completion -- so its vertex normal is
# that quad's FLAT normal, while the quad's own corners carry the smoothed
# sphere normal. That is a kink in the normal field all round the rim, and
# it photographed as a zigzag crease on the rump (with the tail hidden, so it
# was not the tail). The open bore never showed it because its rim edges
# were marked sharp and the dark wall sat between the two sides.
#
# Dissolving the 68 rim edges merges each clipped n-gon with its completion
# back into the ORIGINAL quad, and `use_verts` removes the vertices that
# leaves stranded on straight edges. What is left in that region is the
# pre-boolean quad-sphere, vertex for vertex: nothing extra, nothing to kink.
new_set = set(new_faces)
rim_edges = [e for e in bm.edges if e.verts[0] in set(rim) and e.verts[1] in set(rim)
             and any(f in new_set for f in e.link_faces)]
assert len(rim_edges) == n_outer, "expected %d rim edges, found %d" % (n_outer, len(rim_edges))
bmesh.ops.dissolve_edges(bm, edges=rim_edges, use_verts=True, use_face_split=False)
bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()

# The restored region: every generator face the cutter touched, found again
# by its four vertex positions, and checked to be a QUAD on those four.
kd2 = KDTree(len(bm.verts))
for v in bm.verts:
    kd2.insert(v.co, v.index)
kd2.balance()
region_faces = []
for fi in touched:
    want = set()
    for qi in Q_FACES[fi]:
        co, idx, dist = kd2.find(Q_VERTS[qi])
        assert dist < TOL, "restored quad %d: a corner is missing (%.5f off)" % (fi, dist)
        want.add(idx)
    cands = [f for f in bm.verts[next(iter(want))].link_faces if set(v.index for v in f.verts) == want]
    assert len(cands) == 1, "restored quad %d: %d faces on its corners" % (fi, len(cands))
    region_faces.append(cands[0])
new_faces = region_faces
for f in new_faces:
    f.smooth = True
    f.material_index = 0
    for e in f.edges:
        e.smooth = True
# The disc now has to hold the whole restored region, which reaches a quad
# past the old rim; the projection is the same, the radius follows.
region_reach = max(axis_dist(v.co)[0] for f in new_faces for v in f.verts)
region_area = sum(f.calc_area() for f in new_faces)
want_r = math.sqrt(region_area * body_density / math.pi)
fill_r = min(want_r, have_r)
cap_uvs(new_faces, (cx, cy), fill_r * VAULT_R / region_reach)
print("outer cap: %d restored quads (sizes %s) reaching %.3f from the axis, UV disc r %.4f "
      "(%.0f%% of body linear density); rim vertices dissolved: %d"
      % (len(new_faces), dict(collections.Counter(len(f.verts) for f in new_faces)), region_reach,
         fill_r, 100.0 * fill_r / want_r, n_outer))

# ---------------------------------------------------------------- inner cap
inner_edges = [e for e in bm.edges if e.is_boundary
               and all(rho(v.co) <= 1.0 - WALL * 0.5 for v in e.verts)]
assert len(inner_edges) == n_inner, "inner loop: %d boundary edges, expected %d" % (len(inner_edges), n_inner)
ret = bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=False, edges=inner_edges)
inner_faces = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMFace)]
inner_r = min(0.008, max(0.0, have_r - fill_r - 0.006))
inner_c = (cx + fill_r + inner_r + 0.004, cy) if have_r - fill_r > 0.014 else (cx, cy - fill_r - 0.012)
for f in inner_faces:
    f.smooth = True
    f.material_index = 0
    for e in f.edges:
        e.smooth = True
cap_uvs(inner_faces, inner_c, inner_r)
print("inner cap: %d faces (never visible; inside a closed shell)" % len(inner_faces))
print("outer cap UVs: disc r %.4f at (%.4f, %.4f); inner cap r %.4f at (%.4f, %.4f)"
      % (fill_r, cx, cy, inner_r, inner_c[0], inner_c[1]))

# ---------------------------------------------------------------- measurements
bm.normal_update()
outer_faces = new_faces
region_set = set(outer_faces)
new_verts = [v for v in newv.values() if v.is_valid]
dev = max(abs(rho(v.co) - 1.0) for v in new_verts) if new_verts else 0.0
print("outer cap: %d new verts, max ellipsoid deviation %.6f units (%.4f studs)" % (len(new_verts), dev, dev * SCALE))
# every vertex in the region has the quad-sphere's own valence
val = collections.Counter(len(v.link_faces) for f in outer_faces for v in f.verts)
print("vertex valence across the restored region: %s (a quad-sphere is 4 everywhere but the cube's old corners)" % dict(val))


def dihedral(e):
    fs = e.link_faces
    if len(fs) != 2:
        return 0.0
    return math.degrees(math.acos(max(-1.0, min(1.0, fs[0].normal.dot(fs[1].normal)))))


seam = [e for f in outer_faces for e in f.edges if any(x not in region_set for x in e.link_faces)]
rim_d = [dihedral(e) for e in seam]
cap_d = [dihedral(e) for f in outer_faces for e in f.edges]
print("dihedral across the region's seam with the untouched skin: max %.2f deg (mean %.2f); inside: max %.2f deg. "
      "Smooth-by-angle threshold is 40, quad-sphere neighbours step ~5.6."
      % (max(rim_d), sum(rim_d) / len(rim_d), max(cap_d)))
print("sharp edges on that seam after: %d" % sum(1 for e in seam if not e.smooth))
print("boundary edges left on Body: %d (0 = watertight shell again)" % sum(1 for e in bm.edges if e.is_boundary))
print("non-manifold edges on Body: %d" % sum(1 for e in bm.edges if not e.is_manifold))
print("faces %d -> %d, verts %d -> %d" % (faces_before, len(bm.faces), verts_before, len(bm.verts)))
print("UV coords outside 0..1: %d" % sum(1 for f in bm.faces for l in f.loops
                                         if not (-1e-4 <= l[uv].uv.x <= 1.0001 and -1e-4 <= l[uv].uv.y <= 1.0001)))

bm.to_mesh(me)
bm.free()
me.update()

pts = [body.matrix_world @ v.co for v in me.vertices]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
c = (lo + hi) / 2.0
off = Vector((c.x * SCALE, LIFT + c.z * SCALE, -c.y * SCALE))
size = Vector((hi.x - lo.x, hi.z - lo.z, hi.y - lo.y)) * SCALE
print("")
print("=== Config.PIGGY_MESH Body row would become ===")
print("  offset = Vector3.new(%.4f, %.4f, %.4f)   size = Vector3.new(%.4f, %.4f, %.4f)"
      % (off.x, off.y, off.z, size.x, size.y, size.z))
print("  (shipped: offset 0.0000, 6.6200, 0.0835   size 12.0000, 11.5200, 12.7930)")
print("  rearmost point y %.4f (ellipsoid pole %.4f)" % (hi.y, RY))

bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=DST)
print("saved %s" % DST)
