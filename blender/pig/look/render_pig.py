# -*- coding: utf-8 -*-
# Studio renders of pig.blend, so the shape can be judged before anything is
# uploaded. Renders the same camera in one-tone (matching the reference) and
# two-tone (showing the split working).

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

import bpy, math, os, sys
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


def srgb(r, g, b):
    def f(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (f(r), f(g), f(b), 1.0)


PINK = srgb(245, 170, 196)
TRIM_MATCH = PINK                    # one-tone, like the reference
TRIM_SPLIT = srgb(226, 124, 156)     # two-tone, to show the split
EYE = srgb(28, 28, 34)


def material(name, colour, rough=0.34):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = colour
    bsdf.inputs["Roughness"].default_value = rough
    return m


mat_body = material("body", PINK)
mat_trim = material("trim", TRIM_MATCH)
mat_eye = material("eye", EYE, rough=0.25)

for name, mat in (("Body", mat_body), ("Trim", mat_trim), ("EyePreview", mat_eye)):
    ob = bpy.data.objects[name]
    ob.data.materials.clear()
    ob.data.materials.append(mat)

# ---------------------------------------------------------------- world
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs[0].default_value = srgb(233, 233, 235)
bg.inputs[1].default_value = 0.85


def point_at(ob, target):
    d = Vector(target) - ob.location
    ob.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()


def area(name, loc, energy, size, target=(0, 0, 0.05)):
    ld = bpy.data.lights.new(name, type='AREA')
    ld.energy = energy
    ld.size = size
    ob = bpy.data.objects.new(name, ld)
    scene.collection.objects.link(ob)
    ob.location = Vector(loc)
    point_at(ob, target)
    return ob


area("key", (-4.5, -5.0, 5.0), 1200, 6.0)
area("fill", (5.5, -3.5, 1.2), 400, 8.0)
area("rim", (1.5, 4.5, 4.5), 500, 5.0)

# ---------------------------------------------------------------- camera
cam_data = bpy.data.cameras.new("cam")
cam_data.lens = 62
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 64
scene.cycles.use_denoising = True
scene.render.resolution_x = 520
scene.render.resolution_y = 520
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'Standard'

AIM = (0.0, 0.0, 0.02)

VIEWS = {
    "quarter": (-4.4, -6.2, 2.3),
    "front":   (0.0, -7.6, 0.55),
    "side":    (-7.4, 0.0, 0.9),
    "back":    (2.6, 6.8, 2.2),
    # framed like the reference crop: head filling the frame, slightly above
    "head":    (-1.5, -4.3, 1.15),
    # close on the rump, to judge the curl and its tip
    "tail":    (1.9, 3.9, 1.7),
    # dead side-on, close on the head: the only view that reads a snout angle
    "profile": (-4.6, -0.55, 0.55),
    # Looking down the spine at the coin slot, and at the chin from below --
    # the two things the cuts and the snout's back rim can only be judged in.
    "top":     (-0.9, 1.6, 6.8),
    "chin":    (-2.4, -4.6, -2.4),
    # Straight down the vault hatch's own axis, into the hollow -- the only
    # view that can say whether anything is hanging about in there.
    "hatch":   (0.0, 2.98, -0.68),
}
# a view may aim somewhere other than the body centre
AIMS = {"head": Vector((0.0, -0.15, 0.42)),
        "tail": Vector((0.05, 1.05, 0.40)),
        "profile": Vector((0.0, -0.55, 0.02))}


def shoot(view, tag):
    cam.location = Vector(VIEWS[view])
    point_at(cam, AIMS.get(view, AIM))
    scene.render.filepath = os.path.join(RENDERS, "%s_%s.png" % (view, tag))
    bpy.ops.render.render(write_still=True)
    print("rendered", scene.render.filepath)


# one-tone first, matching the reference
shoot("quarter", "onetone")

# then the split
mat_trim.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = TRIM_SPLIT
for v in ("top", "quarter", "back", "head", "profile"):
    shoot(v, "split")
