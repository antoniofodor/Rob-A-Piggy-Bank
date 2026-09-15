# -*- coding: utf-8 -*-
"""Every part's own bounds, off the master, in the pig's own frame.

    blender.exe --background --python skins/stainedglass/measure.py

Written because the snout pad looked far too big in the first renders and
the obvious explanation -- a badly placed `NOSE` -- was wrong. The snout
MESH runs y -1.381..-0.193, a cone reaching most of the way back into the
body, so nearly all of it is buried; what is visible is about the front
0.3 studs, and the pad was landing correctly on half of that. WORKFLOW.md
quotes the BODY's numbers and not the parts', and the difference is what
made a correct placement look wrong.
"""
import os as _os, sys as _sys
_root = _os.path.dirname(_os.path.abspath(__file__))
while not _os.path.exists(_os.path.join(_root, "paths.py")):
    _root = _os.path.dirname(_root)
if _root not in _sys.path:
    _sys.path.insert(0, _root)
import paths, bpy
bpy.ops.wm.open_mainfile(filepath=paths.PARTS)
for o in bpy.data.objects:
    if o.type != 'MESH':
        continue
    vs = [v.co for v in o.data.vertices]
    if not vs:
        continue
    print("  %-14s x %7.3f..%7.3f  y %7.3f..%7.3f  z %7.3f..%7.3f  (%d v)"
          % (o.name, min(v.x for v in vs), max(v.x for v in vs),
             min(v.y for v in vs), max(v.y for v in vs),
             min(v.z for v in vs), max(v.z for v in vs), len(vs)))
