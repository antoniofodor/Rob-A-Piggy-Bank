# -*- coding: utf-8 -*-
"""CLOSED-BACK PROOF: bake a skin blend's BODY sheet into the test folder.

    blender.exe --background --python make/closedback_bake.py -- --blend <closed.blend> --out <dir> --name glacier

Same bake as `make/bake_skin.py` -- Cycles, one sample, diffuse colour only,
8-texel margin, 2048 supersampled down to 1024, alpha forced to 1 -- with the
one difference that it writes wherever `--out` says rather than over
`assets/piggies/<tier>/<skin>/sheets/<skin>_body_color.png`, which is a shipped file. Body only by
default: the trim was not touched by the fill, so its shipped sheet is still
the right sheet and re-baking it here would only prove that.
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

import bpy, os, sys
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


BLEND = arg("--blend", None)
OUT = arg("--out", None)
NAME = arg("--name", "test")
GROUPS_WANTED = arg("--groups", "body").split(",")
SIZE = int(arg("--size", "1024"))
SUPER = SIZE * 2
if not BLEND or not OUT:
    raise SystemExit("usage: -- --blend <closed.blend> --out <dir> --name <skin>")
os.makedirs(OUT, exist_ok=True)

GROUPS = [("body", ["Body"]), ("trim", ["Snout", "Ears", "Legs", "Tail"])]

bpy.ops.wm.open_mainfile(filepath=BLEND)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 1
scene.cycles.bake_type = 'DIFFUSE'
scene.render.bake.use_pass_direct = False
scene.render.bake.use_pass_indirect = False
scene.render.bake.use_pass_color = True
scene.render.bake.use_selected_to_active = False
scene.render.bake.margin = 8


def bake_group(name, objects):
    img = bpy.data.images.new("bake_" + name, SUPER, SUPER, alpha=True)
    seen = set()
    for ob in objects:
        for slot in ob.data.materials:
            if slot is None or slot.name in seen:
                continue
            seen.add(slot.name)
            nt = slot.node_tree
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image = img
            tex.location = (-600, 600)
            nt.nodes.active = tex
    for ob in objects:
        uvl = ob.data.uv_layers.active.data
        bad = sum(1 for i in range(len(uvl))
                  if not (-1e-4 <= uvl[i].uv.x <= 1.0001 and -1e-4 <= uvl[i].uv.y <= 1.0001))
        if bad:
            print("  ! %s has %d UV coords outside 0..1" % (ob.name, bad), flush=True)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:
        ob.hide_render = False
        ob.hide_set(False)
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    print("  baking %-5s from %s (%d material%s)"
          % (name, ", ".join(o.name for o in objects), len(seen), "" if len(seen) == 1 else "s"), flush=True)
    bpy.ops.object.bake(type='DIFFUSE')
    img.scale(SIZE, SIZE)
    buf = np.empty(SIZE * SIZE * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    buf[3::4] = 1.0
    img.pixels.foreach_set(buf)
    return img


for name, wanted in GROUPS:
    if name not in GROUPS_WANTED:
        continue
    obs = [bpy.data.objects[n] for n in wanted if n in bpy.data.objects]
    img = bake_group(name, obs)
    img.filepath_raw = os.path.join(OUT, "%s_%s_color.png" % (NAME, name))
    img.file_format = 'PNG'
    img.save()
    print("  wrote %s" % img.filepath_raw, flush=True)
print("BAKE DONE")
