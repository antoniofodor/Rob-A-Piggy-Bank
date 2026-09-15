# -*- coding: utf-8 -*-
"""Export the pig's meshes as the .obj files Roblox gets uploaded.

    blender.exe --background --python export_meshes.py

WHY THIS IS SEPARATE FROM `build_pig.py`. That script GENERATES the pig and
exports on its way past, which is right when the geometry is what changed.
Nothing about the geometry changes here: a re-unwrap moves UVs and not one
vertex. What has to go back out is the same shape carrying a different address
book, and doing that through the generator would rebuild the animal and throw
away the hand work in the file.

THE JOINED `Trim` IS BUILT FROM THE FOUR, NOT LOADED. `Config.PIGGY_MESH` ships
a `Body` and a joined `Trim`; `PIGGY_TRIM_PARTS` can split that trim into
Snout, Ears, Legs and Tail, and every one of those ids is empty today. So the
joined trim is what the game actually stands up -- and after a re-unwrap it has
to be built from the four parts that were unwrapped TOGETHER, or its UVs
describe a packing that no texture was baked against.

EXPORT SETTINGS ARE `build_pig.py`'S, TO THE ARGUMENT. A different forward axis
or a dropped normal here is a pig that imports rotated or faceted, and neither
shows up until it is standing on a lawn. `SCALE` is parsed out of the generator
rather than copied, for the reason `make_parts_blend.py` gives: two copies of a
scale factor is the duplicate this project keeps paying for.

WHAT DOES NOT CHANGE, AND IS WORTH KNOWING BEFORE THE UPLOAD. Geometry is
identical, so every landmark cut against this body still holds -- the twelve
accessory anchors, the vault dial, the coin pile, the hatch -- and
`Config.PIGGY_MESH`'s `offset` and `size` rows stay exactly as they are. The
only thing that moves is the asset `id`.
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
import bpy, os, re, sys


D = os.path.dirname(os.path.abspath(__file__))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


BLEND = arg("--blend", paths.PARTS)
SUFFIX = arg("--suffix", "")          # e.g. "_uv2" to write beside the originals

TRIM_PARTS = ["Snout", "Ears", "Legs", "Tail"]


def build_scale():
    """SCALE, READ OUT OF `build_pig.py` RATHER THAN COPIED. If either name
    ever moves this raises here instead of silently exporting a pig at the
    wrong size -- which is a thing nothing downstream would catch, because a
    wrong `size` against a right `id` does not fail, it SCALES the mesh."""
    src = open(os.path.join(D, "build_pig.py"), encoding="utf-8").read()

    def num(pattern):
        m = re.search(pattern, src, re.M)
        if not m:
            raise RuntimeError("cannot read %r out of build_pig.py" % pattern)
        return float(m.group(1))

    return num(r"^GAME_BODY_R\s*=\s*([0-9.]+)") / num(r"^BODY_RX, BODY_RY, BODY_RZ = ([0-9.]+)")


SCALE = build_scale()
bpy.ops.wm.open_mainfile(filepath=paths.find(BLEND, "blend"))

for n in ("NostrilPreview", "EyePreview", "Fur_mane", "Fur_crest"):
    o = bpy.data.objects.get(n)
    if o:
        bpy.data.objects.remove(o, do_unlink=True)

# A joined trim already in the file is STALE the moment the parts were
# re-unwrapped, so it is dropped and rebuilt rather than trusted.
old = bpy.data.objects.get("Trim")
if old:
    bpy.data.objects.remove(old, do_unlink=True)

parts = [bpy.data.objects[n] for n in TRIM_PARTS if n in bpy.data.objects]
if len(parts) != len(TRIM_PARTS):
    raise RuntimeError("expected %s, found %s"
                       % (TRIM_PARTS, [o.name for o in parts]))

# JOIN A COPY, so the four originals survive for a later re-bake. Joining in
# place would leave the file with no way to bake the trim sheet again.
copies = []
for ob in parts:
    c = ob.copy()
    c.data = ob.data.copy()
    bpy.context.scene.collection.objects.link(c)
    copies.append(c)
bpy.ops.object.select_all(action='DESELECT')
for c in copies:
    c.select_set(True)
bpy.context.view_layer.objects.active = copies[0]
bpy.ops.object.join()
trim = bpy.context.view_layer.objects.active
trim.name = "Trim"

# SUBDIVISION IS STRIPPED, AND IT IS THE ONE THING THAT WOULD SHIP SILENTLY.
# `wm.obj_export` APPLIES MODIFIERS, so a Subdivision left switched on for
# looking at the pig in Blender leaves with it: measured, the body exported at
# 12,532 verts and 25,064 triangles against an authored 3,176 and 6,352 -- four
# times, at viewport level 1, and SIXTEEN times had it exported at its render
# level of 2. In `SIMPLE` mode it does not even change the shape, so the whole
# cost buys nothing: same silhouette, same bounding box, four times the mesh.
#
# Nothing in the upload would have complained. It is the kind of thing that
# turns up later as "the pig is heavy" with no line in any log connecting it to
# a modifier somebody added to preview a smoother animal.
#
# Only SUBSURF is removed. Anything else -- a Smooth by Angle, say -- is
# genuinely part of how the surface is meant to read and must survive.
for _ob in list(bpy.data.objects):
    if _ob.type != 'MESH':
        continue
    for _m in list(_ob.modifiers):
        if _m.type == 'SUBSURF':
            print("  ! removed %s (%s, viewport %d / render %d) from %s"
                  % (_m.name, _m.subdivision_type, _m.levels,
                     _m.render_levels, _ob.name))
            _ob.modifiers.remove(_m)

EXPORTS = [("Body", bpy.data.objects["Body"]), ("Trim", trim)]

print("")
print("=== EXPORT  (scale %.6f, from %s) ===" % (SCALE, BLEND))
for name, ob in EXPORTS:
    uvl = ob.data.uv_layers.active.data
    us = [uvl[i].uv.x for i in range(len(uvl))]
    vs = [uvl[i].uv.y for i in range(len(uvl))]
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    outside = sum(1 for u in us if u < -1e-4 or u > 1.0001)
    outside += sum(1 for v in vs if v < -1e-4 or v > 1.0001)

    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    path = paths.pig("pig_%s%s.obj" % (name.lower(), SUFFIX))
    bpy.ops.wm.obj_export(filepath=path,
                          export_selected_objects=True,
                          forward_axis='NEGATIVE_Z', up_axis='Y',
                          global_scale=SCALE,
                          export_materials=False,
                          export_normals=True,
                          export_uv=True,
                          export_triangulated_mesh=True)
    print("  %-5s %5d verts  %5d tris   u %.4f..%.4f  v %.4f..%.4f   -> %s"
          % (name, len(ob.data.vertices), tris,
             min(us), max(us), min(vs), max(vs), os.path.basename(path)))
    # A UV OUTSIDE THE SQUARE IS THE WHOLE REASON THIS RE-UNWRAP HAPPENED, so
    # it is checked on the way out rather than discovered on a lawn: those
    # faces bake to nothing and then sample wrapped, which is the torn band.
    if outside:
        print("    ! %d UV coordinates outside 0..1 -- a bake will lose them"
              % outside)
    else:
        print("    every UV inside 0..1")

print("")
print("  Geometry is unchanged, so `Config.PIGGY_MESH`'s offset and size rows")
print("  stay as they are. Only the asset id moves.")
