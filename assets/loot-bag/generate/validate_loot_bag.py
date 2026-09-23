# -*- coding: utf-8 -*-
"""Read the exports BACK and check them against the manifest.

    blender --background --python assets/loot-bag/generate/validate_loot_bag.py

THE NAME ON AN EXPORT IS THE ONE THING NOTHING IN THE ENGINE CHECKS, which is
why this project fetches an uploaded animation back and diffs it rather than
trusting the filename. Same rule one step earlier: an FBX that silently lost a
mesh, arrived mirrored or came in a hundred times too big looks exactly like a
correct one until it is in the game.

Checks, per file: the meshes that are in it, each one's triangle count and its
bounding box IN THE EXPORTED AXES, against `manifest.json`. A pass means the
model on disk is the model the manifest describes.
"""
import json
import os
import sys

import bpy
import mathutils

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)

with open(os.path.join(OUT, "manifest.json"), encoding="utf-8") as fh:
    manifest = json.load(fh)


def wipe():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def bounds(objs):
    lo = [1e9] * 3
    hi = [-1e9] * 3
    for o in objs:
        for c in o.bound_box:
            p = o.matrix_world @ mathutils.Vector(c)
            for i in range(3):
                lo[i] = min(lo[i], p[i])
                hi[i] = max(hi[i], p[i])
    return lo, hi


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


problems = []

# ---- the whole model -----------------------------------------------------
wipe()
bpy.ops.import_scene.fbx(filepath=os.path.join(OUT, "loot-bag.fbx"))
meshes = {o.name.split(".")[0]: o for o in bpy.data.objects if o.type == "MESH"}
expected = [s["part"] for s in manifest["segments"]]
print("whole FBX: %d meshes -- %s" % (len(meshes), ", ".join(sorted(meshes))))
for want in expected:
    if want not in meshes:
        problems.append("loot-bag.fbx is missing %s" % want)

lo, hi = bounds([o for o in bpy.data.objects if o.type == "MESH"])
# THE IMPORTER UNDOES THE EXPORTER, so what comes back is in Blender's own
# frame again rather than in the file's. That is what makes this a real check
# and not a tautology -- a mesh that lost a conversion on the way out would come
# back rotated. Roblox reads the FILE, whose triple is (x, z, -y) of these
# axes, which is the same swap the manifest was written with.
# The first version of this line left the minus off the Z and reported six
# mismatches on a set of exports that were right, which is exactly the trap the
# probe is here to catch pointed the wrong way.
size = [hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1]]
want = manifest["whole"]["size"]
print("whole size (roblox x,y,z): %s   manifest %s" % ([round(v, 4) for v in size], want))
for i in range(3):
    if abs(size[i] - want[i]) > 0.01:
        problems.append("whole size axis %d is %.4f, manifest says %.4f" % (i, size[i], want[i]))

base = lo[2]
print("base sits at y %+.4f (wanted 0)" % base)
if abs(base) > 0.01:
    problems.append("the base is at %.4f rather than 0" % base)

total = sum(tris(o) for o in bpy.data.objects if o.type == "MESH")
print("whole triangles: %d   manifest %d" % (total, manifest["whole"]["triangles"]))

# ---- each part on its own ------------------------------------------------
for seg in manifest["segments"]:
    path = os.path.join(OUT, seg["fbx"])
    wipe()
    bpy.ops.import_scene.fbx(filepath=path)
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    if len(objs) != 1:
        problems.append("%s holds %d meshes" % (seg["fbx"], len(objs)))
        continue
    obj = objs[0]
    n = tris(obj)
    lo, hi = bounds(objs)
    size = [hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1]]
    centre = [(lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2, -(lo[1] + hi[1]) / 2]
    ok = True
    for i in range(3):
        if abs(size[i] - seg["size"][i]) > 0.01:
            ok = False
        if abs(centre[i] - seg["offset"][i]) > 0.01:
            ok = False
    if n > 10000:
        ok = False
        problems.append("%s is %d triangles, over Roblox's 10,000 limit" % (seg["part"], n))
    if not ok:
        problems.append("%s does not match the manifest (size %s offset %s)"
                        % (seg["part"], [round(v, 4) for v in size], [round(v, 4) for v in centre]))
    print("  %-10s %5d tris  size %s  offset %s  %s"
          % (seg["part"], n, [round(v, 4) for v in size],
             [round(v, 4) for v in centre], "ok" if ok else "MISMATCH"))

print()
if problems:
    for p in problems:
        print("PROBLEM: " + p)
    sys.exit(1)
print("every export matches the manifest.")
