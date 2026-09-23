# -*- coding: utf-8 -*-
"""What the pig's own frame actually holds, measured rather than assumed.

    blender --background --python assets/piggies/legendary/phoenix/generate/measure.py

The feather lattice is `C` columns round the y axis and a row density that
varies with y, so the two numbers that decide whether a feather is a sensible
SHAPE are the RADIUS ABOUT THE Y AXIS at each slice (which sets a feather's
width) and the row height in studs (which sets its height). Neither is in
`WORKFLOW.md`'s landmark list, so this prints them.
"""
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
import paths
import bpy, math

bpy.ops.wm.open_mainfile(filepath=paths.PARTS)
print("")
for ob in bpy.data.objects:
    if ob.type != 'MESH':
        continue
    vs = [ob.matrix_world @ v.co for v in ob.data.vertices]
    if not vs:
        continue
    print("  %-16s %5d verts  x %6.3f..%6.3f  y %6.3f..%6.3f  z %6.3f..%6.3f"
          % (ob.name, len(vs),
             min(v.x for v in vs), max(v.x for v in vs),
             min(v.y for v in vs), max(v.y for v in vs),
             min(v.z for v in vs), max(v.z for v in vs)))

print("\n  RADIUS ABOUT THE Y AXIS, over Body+Snout+Ears+Legs+Tail")
names = ("Body", "Snout", "Ears", "Legs", "Tail")
pts = []
for n in names:
    ob = bpy.data.objects.get(n)
    if ob:
        pts += [(ob.matrix_world @ v.co, n) for v in ob.data.vertices]
lo, hi = -1.45, 1.50
STEP = 0.15
y = lo
while y < hi:
    band = [(math.hypot(p.x, p.z), n) for p, n in pts if y <= p.y < y + STEP]
    if band:
        r = sorted(x for x, _ in band)
        who = sorted(set(n for _, n in band))
        print("    y %6.2f..%6.2f  n%6d  r med %5.3f  max %5.3f   %s"
              % (y, y + STEP, len(band), r[len(r) // 2], r[-1],
                 ",".join(who)))
    y += STEP
