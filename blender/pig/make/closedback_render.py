# -*- coding: utf-8 -*-
"""CLOSED-BACK PROOF: render a pig blend from FIXED cameras, game-lit.

    blender.exe --background --python make/closedback_render.py -- --blend <x.blend> --out <dir> --tag before
        [--body-tex <png>] [--trim-tex <png>]

Same camera set for every call, so a before and an after differ only in the
mesh (and, when given, the sheet). Lighting is `make_view_blend.py`'s --
`WorldService`'s one warm sun, cool blue fill, green lawn -- copied number for
number rather than by requiring that script, which opens a skin's own blend
and writes its own preview file.

With no textures the body is the plain pink `render_pig.py` uses and the trim
its darker split tone, which is what "the plain shared body" looks like.
SUBSURF is stripped, as `export_meshes.py` strips it, so what is rendered is
the faceting the game actually stands up.

Views: `behind` straight up the dial axis at about pavement viewing height,
`rear3q` the rear three-quarter, `hero` the shop's front three-quarter, and
`hatch` a close pass over the rump where a patch would show if there were one.
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

import bpy, os, sys, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


BLEND = arg("--blend", None)
OUT = arg("--out", None)
TAG = arg("--tag", "shot")
BODY_TEX = arg("--body-tex", None)
TRIM_TEX = arg("--trim-tex", None)
RES = int(arg("--res", "900"))
HIDE = [n for n in arg("--hide", "").split(",") if n]      # e.g. --hide Tail, a diagnostic
VIEWS = [n for n in arg("--views", "").split(",") if n]    # e.g. --views hatch,hero; empty = all
if not BLEND or not OUT:
    raise SystemExit("usage: -- --blend <x.blend> --out <dir> --tag <tag>")
os.makedirs(OUT, exist_ok=True)

# --- WorldService's numbers, as make_view_blend.py records them --------------
SUN_ELEV, SUN_AZI = 50.9, -74.8
SUN_RGB, SKY_RGB, GRASS_RGB = (255, 243, 210), (88, 100, 132), (82, 114, 60)
BRIGHTNESS, EXPOSURE, DIFFUSE_SCALE = 2.4, -0.04, 0.50


def srgb(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lin(t):
    return tuple(srgb(v) for v in t)


bpy.ops.wm.open_mainfile(filepath=BLEND)
scene = bpy.context.scene

for n in ("NostrilPreview", "Fur_mane", "Fur_crest", "Trim"):
    o = bpy.data.objects.get(n)
    if o and (n != "Trim" or "Snout" in bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)

body = bpy.data.objects["Body"]
for n in HIDE:
    o = bpy.data.objects.get(n)
    if o:
        bpy.data.objects.remove(o, do_unlink=True)
        print("  hidden (diagnostic): %s" % n)
trims = [bpy.data.objects[n] for n in ("Snout", "Ears", "Legs", "Tail") if n in bpy.data.objects]
for o in [body] + trims:
    o.hide_render = False
    o.hide_set(False)
    for m in list(o.modifiers):
        if m.type == 'SUBSURF':
            o.modifiers.remove(m)


def bsdf_of(m):
    return next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')


def flat(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = bsdf_of(m)
    b.inputs["Base Color"].default_value = lin(rgb) + (1.0,)
    b.inputs["Roughness"].default_value = 0.88
    if "Specular IOR Level" in b.inputs:
        b.inputs["Specular IOR Level"].default_value = 0.08
    return m


def textured(name, path):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = bsdf_of(m)
    b.inputs["Roughness"].default_value = 0.88
    if "Specular IOR Level" in b.inputs:
        b.inputs["Specular IOR Level"].default_value = 0.08
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(path, check_existing=False)
    tex.image.alpha_mode = 'CHANNEL_PACKED'
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    return m


# Assign INTO slots, never clear(): the ear's inner-rim selection is a slot
# index on every polygon and clear() resets them (see skin_parts.py).
def seat(ob, mat):
    if len(ob.data.materials) == 0:
        ob.data.materials.append(mat)
    else:
        for i in range(len(ob.data.materials)):
            ob.data.materials[i] = mat


PINK, PINK_DARK = (245, 170, 196), (226, 124, 156)
seat(body, textured("cb_body", BODY_TEX) if BODY_TEX else flat("cb_body", PINK))
for o in trims:
    seat(o, textured("cb_trim_" + o.name, TRIM_TEX) if TRIM_TEX else flat("cb_trim_" + o.name, PINK_DARK))

eye = bpy.data.objects.get("EyePreview")
if eye:
    eye.hide_render = False
    eye.hide_set(False)
    seat(eye, flat("cb_eye", (38, 30, 34)))

# --- lawn, sky, sun ---------------------------------------------------------
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, -1.02))
ground = bpy.context.active_object
ground.name = "Lawn"
gm = flat("cb_lawn", GRASS_RGB)
bsdf_of(gm).inputs["Roughness"].default_value = 0.95
ground.data.materials.append(gm)

w = bpy.data.worlds.new("cb_sky")
scene.world = w
w.use_nodes = True
bgn = next(n for n in w.node_tree.nodes if n.type == 'BACKGROUND')
bgn.inputs[0].default_value = lin(SKY_RGB) + (1.0,)
bgn.inputs[1].default_value = DIFFUSE_SCALE

sd = bpy.data.lights.new("cb_sun", type='SUN')
sd.energy = BRIGHTNESS
sd.color = lin(SUN_RGB)
sd.angle = math.radians(0.35 * 12.0)
sun = bpy.data.objects.new("Sun", sd)
scene.collection.objects.link(sun)
el, az = math.radians(SUN_ELEV), math.radians(SUN_AZI)
d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
sun.location = d * 20.0
sun.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()

for eng in ('BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT'):
    try:
        scene.render.engine = eng
        break
    except TypeError:
        continue
scene.view_settings.view_transform = 'Standard'
scene.view_settings.exposure = EXPOSURE
scene.render.resolution_x = scene.render.resolution_y = RES
scene.render.image_settings.file_format = 'PNG'

cd = bpy.data.cameras.new("cb_cam")
cd.lens = 62
cam = bpy.data.objects.new("Cam", cd)
scene.collection.objects.link(cam)
scene.camera = cam


def point_at(o, t):
    o.rotation_euler = (Vector(t) - o.location).to_track_quat('-Z', 'Y').to_euler()


# The hatch centre in Blender units, as build_pig.py solves it: (0, 1.079, -0.047).
# The body centre sits 6.62 studs over the lawn; a player's camera on the
# pavement is a couple of studs above that, so `behind` looks slightly DOWN
# the dial axis from about 8.5 studs up and 27 studs back.
SHOTS = (
    ("behind", (0.0, 5.2, 0.55), (0.0, 0.30, 0.0), 62),
    ("rear3q", (3.4, 4.3, 1.35), (0.0, 0.25, 0.0), 62),
    ("hero",   (-3.9, -5.4, 2.0), (0.0, -0.05, 0.05), 62),
    ("hatch",  (1.3, 2.9, 0.65), (0.0, 1.05, -0.05), 62),
)
for name, loc, aim, lens in SHOTS:
    if VIEWS and name not in VIEWS:
        continue
    cd.lens = lens
    cam.location = Vector(loc)
    point_at(cam, aim)
    scene.render.filepath = os.path.join(OUT, "%s_%s.png" % (TAG, name))
    bpy.ops.render.render(write_still=True)
    print("  rendered %s" % scene.render.filepath, flush=True)
print("RENDER DONE")
