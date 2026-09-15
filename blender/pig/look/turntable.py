# -*- coding: utf-8 -*-
# Twelve angles of pig.blend composited into one contact sheet, so the shape
# can be judged all the way round without opening Blender.

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
import numpy as np
from mathutils import Vector


OUT = os.path.dirname(os.path.abspath(__file__))

# RENDERS GO IN `renders/`, NEVER BESIDE THE ASSETS. Every picture this script
# writes is reproducible by running it again, and the folder it used to write
# into holds the .obj files that actually ship -- so a session of previewing
# buried the deliverables under 46 screenshots and 17 MB. `.gitignore` already
# refuses *.png outside `skins/`, so nothing here was ever committed; what it
# could not do is stop them piling up on disk.
RENDERS = paths.RENDERS
os.makedirs(RENDERS, exist_ok=True)

bpy.ops.wm.open_mainfile(filepath=paths.RAW)
scene = bpy.context.scene

TILE = 320
COLS, ROWS = 4, 3
RADIUS = 7.2
ELEV = 16.0          # degrees above the equator
AIM = Vector((0.0, 0.0, 0.02))


def srgb(r, g, b):
    def f(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (f(r), f(g), f(b), 1.0)


def material(name, colour, rough=0.34):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = colour
    b.inputs["Roughness"].default_value = rough
    return m


for name, mat in (("Body", material("body", srgb(245, 170, 196))),
                  ("Trim", material("trim", srgb(226, 124, 156))),
                  ("EyePreview", material("eye", srgb(28, 28, 34), 0.25))):
    ob = bpy.data.objects[name]
    ob.data.materials.clear()
    ob.data.materials.append(mat)

world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = srgb(233, 233, 235)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.85


def point_at(ob, target):
    ob.rotation_euler = (Vector(target) - ob.location).to_track_quat('-Z', 'Y').to_euler()


def area(name, loc, energy, size):
    ld = bpy.data.lights.new(name, type='AREA')
    ld.energy, ld.size = energy, size
    ob = bpy.data.objects.new(name, ld)
    scene.collection.objects.link(ob)
    ob.location = Vector(loc)
    point_at(ob, AIM)


area("key", (-4.5, -5.0, 5.0), 1200, 6.0)
area("fill", (5.5, -3.5, 1.2), 400, 8.0)
area("rim", (1.5, 4.5, 4.5), 500, 5.0)

cam_data = bpy.data.cameras.new("cam")
cam_data.lens = 62
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x = scene.render.resolution_y = TILE
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'Standard'

# Cycles keeps the lights pointing at the pig; only the camera orbits, so the
# lighting is identical in every tile and the tiles are comparable.
frames = []
e = math.radians(ELEV)
for i in range(COLS * ROWS):
    th = math.radians(360.0 * i / (COLS * ROWS))
    cam.location = Vector((RADIUS * math.cos(e) * math.sin(th),
                           -RADIUS * math.cos(e) * math.cos(th),
                           RADIUS * math.sin(e) + AIM.z))
    point_at(cam, AIM)
    path = os.path.join(RENDERS, "_tt_%02d.png" % i)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    frames.append(path)
    print("frame", i)

# ---- composite -------------------------------------------------------------
# Blender image pixels are bottom-up RGBA floats, and so is the canvas, so a
# tile going to grid row r from the TOP starts at (ROWS-1-r) tiles up.
canvas = np.ones((ROWS * TILE, COLS * TILE, 4), dtype=np.float32)
for i, path in enumerate(frames):
    img = bpy.data.images.load(path)
    tile = np.array(img.pixels[:], dtype=np.float32).reshape(TILE, TILE, 4)
    r, c = divmod(i, COLS)
    y = (ROWS - 1 - r) * TILE
    canvas[y:y + TILE, c * TILE:(c + 1) * TILE] = tile
    bpy.data.images.remove(img)

sheet = bpy.data.images.new("sheet", width=COLS * TILE, height=ROWS * TILE, alpha=True)
sheet.pixels = canvas.ravel().tolist()
sheet.filepath_raw = os.path.join(RENDERS, "turntable.png")
sheet.file_format = 'PNG'
sheet.save()
print("saved", sheet.filepath_raw)

for p in frames:
    os.remove(p)
