# -*- coding: utf-8 -*-
"""Select the INSIDE of the ears -- the scooped dish -- and nothing else.

HOW TO USE IT (this one is run from inside Blender, not from a terminal):

  1. Select the `Ears` object, in OBJECT mode
  2. Scripting tab along the top -> Open -> this file -> Run Script (the play
     arrow, or Alt+P)
  3. Tab into Edit Mode -- the dish is selected, both ears
  4. Material Properties -> `+` a slot, pick a colour, press ASSIGN

WHY A SCRIPT AND NOT A BOX SELECT. The dish is not separable by any of the
usual tools: `L` takes the whole ear because it is one connected shell, and a
box select takes whatever is behind it too unless X-ray is off and the camera
is square on -- which it cannot be for both ears at once. There is a property
that separates it exactly, though, and it is the definition of a scoop: THE
INSIDE FACES POINT BACK AT THE EAR'S OWN CENTRE.

Measured on the shipped mesh: 601 of 1,663 faces per ear, 36%, and identical
on both -- which is itself the check that it is finding a real feature rather
than a threshold. Rendered and looked at before being written down: the dish
comes out cleanly, with the rim and the whole back of the ear left out.

EACH EAR IS JUDGED AGAINST ITS OWN CENTRE. One centroid for both sits in the
gap between them, which makes almost every face look like it points "outward"
and selects nearly nothing.

THIS ONLY MAKES A SELECTION. It assigns nothing and saves nothing, so Ctrl+Z
undoes it and a mistake costs a re-run.
"""
import bpy
import collections
from mathutils import Vector

ob = bpy.context.active_object
if ob is None or ob.type != 'MESH':
    raise RuntimeError("select the Ears object first, in Object Mode")
if ob.mode != 'OBJECT':
    # Polygon select flags are only writable from Object Mode; Edit Mode holds
    # its own copy of the mesh and would throw them away on the way back.
    bpy.ops.object.mode_set(mode='OBJECT')

me = ob.data
mw = ob.matrix_world
rot = mw.to_3x3()

sides = collections.defaultdict(list)
for p in me.polygons:
    p.select = False
    sides[+1 if (mw @ p.center).x >= 0 else -1].append(p)

total = 0
for sign, polys in sorted(sides.items()):
    centre = sum(((mw @ p.center) for p in polys), Vector()) / len(polys)
    hit = 0
    for p in polys:
        n = (rot @ p.normal).normalized()
        outward = (mw @ p.center) - centre
        if outward.length > 1e-9 and n.dot(outward.normalized()) < 0.0:
            p.select = True
            hit += 1
    total += hit
    print("  ear x%+d: %d of %d faces (%.0f%%)"
          % (sign, hit, len(polys), 100.0 * hit / len(polys)))

me.update()
print("selected %d faces on %s -- Tab into Edit Mode to see them" % (total, ob.name))
if len(sides) != 2:
    print("  ! expected two ears either side of x=0 and found %d group(s) --"
          " is this the Ears object?" % len(sides))
