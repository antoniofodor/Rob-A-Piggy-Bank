# -*- coding: utf-8 -*-
"""CLOSED-BACK PASS: export Body and joined Trim from a blend into a folder of
your choosing, with `make/export_meshes.py`'s settings to the argument.

    blender.exe --background --python make/closedback_export.py -- --blend <x.blend> --out <dir> [--suffix _closedback]

Exists because `export_meshes.py` can only write into `pig/`, beside the files
that are actually uploaded, and this pass is not allowed to touch those. Same
axes, same scale (parsed out of `build_pig.py` exactly as that script does),
normals, UVs, triangulated, SUBSURF stripped, previews and fur removed, trim
joined from the four parts. Prints the `Config.PIGGY_MESH` rows the way
`make_parts_blend.py --export` prints them, and diffs them against Config.
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

import paths   # noqa: E402
import bpy, os, re, sys   # noqa: E402
from mathutils import Vector   # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


BLEND = arg("--blend", paths.PARTS)
OUT = arg("--out", None)
SUFFIX = arg("--suffix", "_closedback")
if not OUT:
    raise SystemExit("usage: -- --blend <x.blend> --out <dir>")
os.makedirs(OUT, exist_ok=True)
TRIM_PARTS = ["Snout", "Ears", "Legs", "Tail"]


def build_constants():
    src = open(os.path.join(_root, "make", "build_pig.py"), encoding="utf-8").read()

    def num(pattern):
        m = re.search(pattern, src, re.M)
        if not m:
            raise RuntimeError("cannot read %r out of build_pig.py" % pattern)
        return float(m.group(1))

    body_rx = num(r"^BODY_RX, BODY_RY, BODY_RZ = ([0-9.]+)")
    scale = num(r"^GAME_BODY_R\s*=\s*([0-9.]+)") / body_rx
    lift = num(r"^GAME_LAWN_Y\s*=\s*([0-9.-]+)") - num(r"^LEG_BOTTOM\s*=\s*([0-9.-]+)") * scale
    return scale, lift


SCALE, LIFT = build_constants()
bpy.ops.wm.open_mainfile(filepath=paths.find(BLEND, "blend"))

for n in ("NostrilPreview", "EyePreview", "Fur_mane", "Fur_crest"):
    o = bpy.data.objects.get(n)
    if o:
        bpy.data.objects.remove(o, do_unlink=True)
old = bpy.data.objects.get("Trim")
if old:
    bpy.data.objects.remove(old, do_unlink=True)

parts = [bpy.data.objects[n] for n in TRIM_PARTS if n in bpy.data.objects]
if len(parts) != len(TRIM_PARTS):
    raise RuntimeError("expected %s, found %s" % (TRIM_PARTS, [o.name for o in parts]))
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

for _ob in list(bpy.data.objects):
    if _ob.type != 'MESH':
        continue
    for _m in list(_ob.modifiers):
        if _m.type == 'SUBSURF':
            print("  ! removed %s from %s" % (_m.name, _ob.name))
            _ob.modifiers.remove(_m)


def world_bounds(ob):
    pts = [ob.matrix_world @ v.co for v in ob.data.vertices]
    return (Vector([min(p[i] for p in pts) for i in range(3)]),
            Vector([max(p[i] for p in pts) for i in range(3)]))


cfg = open(os.path.join(_root, "..", "..", "src", "ReplicatedStorage", "Shared", "Config.luau"),
           encoding="utf-8").read()
print("")
print("=== EXPORT  (scale %.6f, from %s) ===" % (SCALE, BLEND))
for name, ob in (("Body", bpy.data.objects["Body"]), ("Trim", trim)):
    uvl = ob.data.uv_layers.active.data
    us = [uvl[i].uv.x for i in range(len(uvl))]
    vs = [uvl[i].uv.y for i in range(len(uvl))]
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    outside = sum(1 for u in us if u < -1e-4 or u > 1.0001) + sum(1 for v in vs if v < -1e-4 or v > 1.0001)
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    path = os.path.join(OUT, "pig_%s%s.obj" % (name.lower(), SUFFIX))
    bpy.ops.wm.obj_export(filepath=path, export_selected_objects=True,
                          forward_axis='NEGATIVE_Z', up_axis='Y', global_scale=SCALE,
                          export_materials=False, export_normals=True, export_uv=True,
                          export_triangulated_mesh=True)
    print("  %-5s %5d verts  %5d tris   u %.4f..%.4f  v %.4f..%.4f   -> %s%s"
          % (name, len(ob.data.vertices), tris, min(us), max(us), min(vs), max(vs),
             os.path.basename(path), "   ! %d UVs outside 0..1" % outside if outside else ""))
    lo, hi = world_bounds(ob)
    c = (lo + hi) / 2.0
    off = Vector((c.x * SCALE, LIFT + c.z * SCALE, -c.y * SCALE))
    size = Vector((hi.x - lo.x, hi.z - lo.z, hi.y - lo.y)) * SCALE
    print("  Config.PIGGY_MESH %-5s offset = Vector3.new(%.4f, %.4f, %.4f)   size = Vector3.new(%.4f, %.4f, %.4f)"
          % (name, off.x, off.y, off.z, size.x, size.y, size.z))
    m = re.search(r'part = "%s".*?offset = Vector3\.new\(([-0-9., ]+)\).*?size = Vector3\.new\(([-0-9., ]+)\)'
                  % name, cfg, re.S)
    if m:
        was_off = [float(v) for v in m.group(1).split(",")]
        was_size = [float(v) for v in m.group(2).split(",")]
        d = max(max(abs(a - b) for a, b in zip(was_off, off)), max(abs(a - b) for a, b in zip(was_size, size)))
        print("    Config today: offset (%s)  size (%s)  -> %s"
              % (m.group(1).strip(), m.group(2).strip(),
                 "matches" if d < 0.001 else "MOVED by %.4f -- paste the row above with the new id" % d))
