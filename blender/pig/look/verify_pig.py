# -*- coding: utf-8 -*-
# Are the two openings actually OPEN?
#
# A boolean can fail into something that looks fine from every angle a
# bounding box or a triangle count can see: a blind dent reads as a hole in a
# plan view and is solid. Walking a ray through the shell says which it is.
# Through a real opening a ray meets NO near wall and lands on the inner face
# of the far side; through a dent it meets the floor of the dent immediately.

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


def crossings(origin, direction, limit=12):
    """Every surface the ray meets, as distances from the origin."""
    d = Vector(direction).normalized()
    out, p = [], Vector(origin)
    travelled = 0.0
    for _ in range(limit):
        hit, loc, nrm, _i = body.ray_cast(p, d)
        if not hit:
            break
        step = (loc - p).length
        travelled += step
        out.append((travelled, nrm.dot(d)))
        p = loc + d * 1e-4
        travelled += 1e-4
    return out


def report(name, origin, direction, expect_wall):
    hits = crossings(origin, direction)
    faces = " ".join("%.4f%s" % (t, "in" if s > 0 else "out") for t, s in hits)
    print("%-12s %d crossings: %s" % (name, len(hits), faces))
    if len(hits) >= 2:
        gap = hits[1][0] - hits[0][0]
        print("             first gap %.4f  (the wall is %.4f)" % (gap, expect_wall))
    return hits


WALL = 0.30 / 6.0
print("wall thickness %.4f blender units (0.30 studs)" % WALL)
print("")

# --- the vault hatch, straight down its own axis ---------------------------
# Rebuilt from the same arithmetic the cut used, so this cannot silently test
# a different axis from the one that was cut.
drop, R = 6.6 - 8.5, 6.0
ring = math.sqrt(R * R - drop * drop)
n_rbx = Vector((0.0, drop, -ring)).normalized()
DIAL_N = Vector((n_rbx.x, -n_rbx.z, n_rbx.y)).normalized()
o = Vector((0.0, -0.0 / 6.0, (8.5 - 6.62) / 6.0))
start = o + DIAL_N * 2.0
print("-- VAULT HATCH (dead centre; should pass straight in) --")
report("centre", start, -DIAL_N, WALL)
print("-- VAULT HATCH (offset 0.30 blender = past the 0.238 rim) --")
side = DIAL_N.cross(Vector((1, 0, 0))).normalized()
report("beside it", start + side * 0.30, -DIAL_N, WALL)
print("")

# --- the coin slot ---------------------------------------------------------
print("-- COIN SLOT (dead centre; should pass straight in) --")
report("centre", Vector((0.0, 0.35, 2.0)), Vector((0, 0, -1)), WALL)
print("-- COIN SLOT (0.12 across = past the 0.058 half-width) --")
report("beside it", Vector((0.12, 0.35, 2.0)), Vector((0, 0, -1)), WALL)
print("")

# --- the tail, which the cape anchor was solved against --------------------
pts = [v.co for v in trim.data.vertices if v.co.y > 0.75 and v.co.z > -0.2]
print("tail-ish trim points: %d, y %.3f..%.3f  z %.3f..%.3f"
      % (len(pts), min(p.y for p in pts), max(p.y for p in pts),
         min(p.z for p in pts), max(p.z for p in pts)))
cape = Vector((0.0, 0.913, 0.408)).normalized()
t = 1.0 / math.sqrt((cape.y / 1.08) ** 2 + (cape.z / 0.96) ** 2)
capept = cape * t
print("cape anchor sits at blender (0, %.3f, %.3f); nearest trim point %.3f studs"
      % (capept.y, capept.z, min((capept - p).length for p in pts) * 6.0))
