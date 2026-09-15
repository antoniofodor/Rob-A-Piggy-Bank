# -*- coding: utf-8 -*-
# WHAT IS ACROSS THE TOP OF THE HATCH, AND WHERE THE TAIL HAS TO GO.
#
# Asked in the dial's own frame, rebuilt from PiggyBank's constants so this
# cannot test a different axis from the one the hole was cut on. Body and Trim
# are cast SEPARATELY -- "something is blocking it" is two different repairs
# depending on which of them it is.

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

import bpy, math, os
from mathutils import Vector


OUT = os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=paths.RAW)
body = bpy.data.objects["Body"]
trim = bpy.data.objects["Trim"]

SCALE = 6.0
LIFT = 0.5 + 1.02 * SCALE
RX, RY, RZ = 1.00, 1.08, 0.96
WALL = 0.30 / SCALE
VAULT_R = 1.43 / SCALE
GOLD_R = 1.95 / SCALE
DIAL_OUT = 0.823 / SCALE

drop, R = 6.6 - 8.5, 6.0
ring = math.sqrt(R * R - drop * drop)
n_rbx = Vector((0.0, drop, -ring)).normalized()
N = Vector((n_rbx.x, -n_rbx.z, n_rbx.y)).normalized()
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


print("-- WHO IS BLOCKING THE HOLE --")
print("  angle   BODY hit t      TRIM hit t     (t is along the outward normal)")
for deg in (0, 45, 90, 135, 150, 165, 180, 195, 225, 270, 315):
    a = math.radians(deg)
    p = HATCH + U * (0.75 * VAULT_R * math.cos(a)) + V * (0.75 * VAULT_R * math.sin(a))
    row = []
    for ob in (body, trim):
        hit, loc, _n, _i = ob.ray_cast(p + N * 0.60, -N)
        row.append("%+.4f" % (loc - p).dot(N) if hit and (loc - p).dot(N) > -0.20
                   else "  --   ")
    print("   %3d    %s        %s" % (deg, row[0], row[1]))

tailpts = [v.co for v in trim.data.vertices if v.co.y > 0.70 and v.co.z > -0.30]
print("")
print("tail points: %d" % len(tailpts))
inside = [p for p in tailpts if axis_dist(p)[0] < VAULT_R and -0.20 < axis_dist(p)[1] < 0.40]
print("tail points standing inside the hatch bore: %d" % len(inside))

# ---- where does the tail have to move ------------------------------------
# Shifting the tail is (0, dy, dz) on every one of its points, so the whole
# search can be done on the points that already exist rather than by
# rebuilding. Two constraints pull against each other: it has to clear the
# GOLD plate, which is the widest thing the vault ever puts there, and its
# root has to stay buried in a rump that is falling away fast this far back.
print("")
print("-- WHERE THE TAIL CLEARS THE GOLD PLATE (radius %.2f studs) --" % (GOLD_R * SCALE))
print("   dy     dz    plate gap   root depth   in bore")
for dy in (0.0, -0.04, -0.08, -0.12):
    for dz in (0.0, 0.06, 0.12, 0.18, 0.24, 0.30):
        moved = [p + Vector((0.0, dy, dz)) for p in tailpts]
        gaps = [axis_dist(p) for p in moved]
        slab = [g for g, t in gaps if -0.10 < t - DIAL_OUT < 0.45]
        gap = (min(slab) - GOLD_R) * SCALE if slab else 99.0
        bore = sum(1 for g, t in gaps if g < VAULT_R and -0.20 < t < 0.40)
        # How far the deepest root point sits under the skin, in studs -- it
        # has to stay inside the shell or the tail lifts off the rump.
        deep = min(1.0 - math.sqrt((p.x / RX) ** 2 + (p.y / RY) ** 2 + (p.z / RZ) ** 2)
                   for p in moved)
        print("  %+.2f  %+.2f   %+7.2f      %+6.3f       %d"
              % (dy, dz, gap, deep, bore))
