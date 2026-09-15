# -*- coding: utf-8 -*-
"""A pig lit the way the GAME lights it, to look at before anything is uploaded.

    blender.exe --background --python make_view_blend.py -- --skin bee
    blender.exe --background --python make_view_blend.py -- --skin bee --render

...then open `pig_view.blend` and orbit it.

WHY THIS EXISTS. There is no way to preview a texture in Studio without
uploading it -- a Roblox texture is addressed by asset id, and getting an id IS
the upload, which publishes under the developer's own account and is moderated.
So the last check before that has to happen in Blender, and it is only worth
anything if Blender is lighting the pig the way the engine will.

The default Blender studio rig is three soft area lights and a grey void. The
game is ONE warm sun at half past two, a cool blue sky fill, almost no specular
and a green lawn underneath. Those two disagree most about exactly the thing a
skin is judged on: how much contrast there is between a marking and the colour
under it.

EVERY NUMBER HERE IS READ OUT OF `WorldService`, not chosen:

    Brightness            2.4        the sun's own strength
    ExposureCompensation  -0.04
    ClockTime             14.5       -> a sun 50.9 degrees up, 74.8 west of south
    GeographicLatitude    12
    ColorShift_Top        255,243,210  warm sun
    OutdoorAmbient        88,100,132   cool sky fill -- this is what fills the
                                       shaded side, and it is BLUE on purpose
    EnvironmentDiffuseScale   0.50
    EnvironmentSpecularScale  0.08     reflections at eight per cent
    ShadowSoftness        0.35

WHAT IT STILL CANNOT TELL YOU. Roblox's tonemapping and its `BloomEffect` are
not reproduced -- bloom matters only for Neon skins, and this pack is
SmoothPlastic. Nor is the mesh's own `RenderFidelity`. Treat this as "are the
colours and the contrast right", which is the question that actually decides a
skin, and not as a pixel-exact preview.
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
import bpy, os, sys, math
from mathutils import Vector



argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SKIN = arg("--skin", "bee")
# WHICH SCENE THE PIG COMES OUT OF. `pig.blend` carries the shipped
# cylindrical unwrap; a re-unwrapped copy carries its own, and a texture
# baked against one is meaningless on the other -- so the blend and the
# skin folder have to be named together or the preview is a picture of a
# mismatch.
BLEND = arg("--blend", paths.skin_blend(SKIN))
OUT = paths.skin_view(SKIN)
SKINDIR = paths.skin_dir(SKIN)

# --- the game's own numbers -------------------------------------------------
SUN_ELEV = 50.9          # derived from ClockTime 14.5 at latitude 12
SUN_AZI = -74.8          # degrees from south, negative is west
SUN_RGB = (255, 243, 210)
SKY_RGB = (88, 100, 132)
GRASS_RGB = (82, 114, 60)
BRIGHTNESS = 2.4
EXPOSURE = -0.04
DIFFUSE_SCALE = 0.50


def srgb(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lin(t):
    return tuple(srgb(v) for v in t)


bpy.ops.wm.open_mainfile(filepath=paths.find(BLEND, "blend"))
scene = bpy.context.scene

# The joined `Trim` is what ships -- `Config.PIGGY_TRIM_PARTS` has an empty id
# on all four split parts -- and leaving both in the file stacks two coincident
# surfaces that flicker through each other.
# THE TRIM IS EITHER ONE JOINED MESH OR THE FOUR IT IS CUT INTO, and which one
# a file holds depends on where it came from: `pig.blend` has both stacked in
# the same space, `pig_parts.blend` has only the four. Both are the same
# surface with the same UVs, so either renders the same picture -- what must
# not happen is BOTH, which is two coincident surfaces flickering through each
# other and reads as the pig being broken.
for n in ("NostrilPreview", "Fur_mane", "Fur_crest"):
    o = bpy.data.objects.get(n)
    if o:
        bpy.data.objects.remove(o, do_unlink=True)

body = bpy.data.objects["Body"]
SPLIT = [bpy.data.objects[n] for n in ("Snout", "Ears", "Legs", "Tail")
         if n in bpy.data.objects]
joined = bpy.data.objects.get("Trim")
if joined and SPLIT:
    for o in SPLIT:
        bpy.data.objects.remove(o, do_unlink=True)
    SPLIT = []
trims = [joined] if joined else SPLIT
for o in [body] + trims:
    o.hide_render = False

# `Eye` and `Nostril` are code-built parts in the game, painted NEAR_BLACK once
# at build. They are not in the mesh and not in any texture, so the preview has
# to add them back or it is a picture of a pig with no eyes.
eye = bpy.data.objects.get("EyePreview")
if eye:
    eye.hide_render = False
    em = bpy.data.materials.new("eye")
    em.use_nodes = True
    em.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = \
        lin((38, 30, 34)) + (1.0,)
    em.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
    eye.data.materials.clear()
    eye.data.materials.append(em)


def textured(name, path):
    """A FULL-COLOUR map goes straight into Base Color, which is exactly what
    `AlphaMode.Overlay` does at alpha 1: `lerp(partColour, mapRGB, 1)` is
    `mapRGB`. Roughness high and specular low, because the game runs
    `EnvironmentSpecularScale` at 0.08 -- a glossy preview flatters a skin that
    will ship almost matte."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.88
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.08
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(path, check_existing=False)
    # CHANNEL PACKED, OR EVERY ANIMATED TEXEL PREVIEWS BLACK.
    #
    # After `make/apply_alpha.py` a sheet carries an alpha channel whose zeros
    # mean "the game supplies this colour", and the RGB underneath them is
    # still the authored colour. Blender loads a straight-alpha PNG as
    # PREMULTIPLIED by default and multiplies that RGB by the alpha -- so
    # every texel handed to the animator renders as pure black, and the
    # preview shows holes in a sheet that is byte-perfect.
    #
    # Reported from a session that lost a cycle to it: the sheet still carried
    # (232, 238, 240) under alpha 0 and the render showed a hole. CHANNEL_PACKED
    # tells Blender the alpha is DATA rather than coverage, which is exactly
    # what it is here -- it is a per-texel switch, not a transparency.
    tex.image.alpha_mode = 'CHANNEL_PACKED'
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.nodes.active = tex
    return m


missing = []
_bp = paths.skin_map(SKIN, "body")
_tp = paths.skin_map(SKIN, "trim")
for path in (_bp, _tp):
    if not os.path.exists(path):
        missing.append(os.path.relpath(path, D))
if not missing:
    body.data.materials.clear()
    body.data.materials.append(textured(SKIN + "_body", _bp))
    for ob in trims:
        ob.data.materials.clear()
        ob.data.materials.append(textured(SKIN + "_trim_" + ob.name, _tp))
if missing:
    raise RuntimeError("no texture at %s -- run bake_skin.py first"
                       % ", ".join(missing))

# --- the lawn ---------------------------------------------------------------
# A SKIN IS NEVER SEEN AGAINST GREY. It stands on `WorldService`'s own grass,
# and a yellow judged against a void reads differently from one judged against
# green -- which is the whole reason this file exists rather than a turntable.
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, -1.02))
ground = bpy.context.active_object
ground.name = "Lawn"
gm = bpy.data.materials.new("lawn")
gm.use_nodes = True
gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = \
    lin(GRASS_RGB) + (1.0,)
gm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
ground.data.materials.append(gm)

# --- sky and sun ------------------------------------------------------------
w = bpy.data.worlds.new("sky")
scene.world = w
w.use_nodes = True
# OutdoorAmbient IS the fill in this game, and it is blue: a shaded face
# differs from a lit one in TEMPERATURE as much as in level, which is what
# stops flat-shaded geometry looking evenly filled.
w.node_tree.nodes["Background"].inputs[0].default_value = lin(SKY_RGB) + (1.0,)
w.node_tree.nodes["Background"].inputs[1].default_value = DIFFUSE_SCALE

sd = bpy.data.lights.new("sun", type='SUN')
sd.energy = BRIGHTNESS
sd.color = lin(SUN_RGB)
sd.angle = math.radians(0.35 * 12.0)      # ShadowSoftness 0.35, softened
sun = bpy.data.objects.new("Sun", sd)
scene.collection.objects.link(sun)
el = math.radians(SUN_ELEV)
az = math.radians(SUN_AZI)
d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
sun.location = d * 20.0
sun.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()

scene.render.engine = 'BLENDER_EEVEE'
scene.view_settings.view_transform = 'Standard'
scene.view_settings.exposure = EXPOSURE
scene.render.resolution_x = scene.render.resolution_y = 700

cd = bpy.data.cameras.new("view")
cd.lens = 62
cam = bpy.data.objects.new("View", cd)
scene.collection.objects.link(cam)
scene.camera = cam


def point_at(o, t):
    o.rotation_euler = (Vector(t) - o.location).to_track_quat('-Z', 'Y').to_euler()


cam.location = Vector((-3.9, -5.4, 2.0))
point_at(cam, (0, -0.05, 0.05))

for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type != 'VIEW_3D':
            continue
        for space in area.spaces:
            if space.type == 'VIEW_3D':
                space.shading.type = 'MATERIAL'

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("")
print("=== %s ===" % os.path.relpath(OUT, paths.HERE))
print("  skin %s, textures out of %s" % (SKIN, os.path.relpath(SKINDIR, D)))
print("  sun %.1f deg up, warm %s; sky fill cool %s; lawn %s"
      % (SUN_ELEV, SUN_RGB, SKY_RGB, GRASS_RGB))
print("  open it and orbit. Numpad 0 for the framed camera.")

if "--render" in argv:
    # THE GRAZING ANGLES ARE THE POINT. Anything wrong with a cylindrical
    # unwrap shows at the CROWN and along the SPINE, where the texel density
    # goes uneven -- and a three-quarter hero shot is exactly the view that
    # hides it. These are the angles a preview should be judged on.
    SHOTS = (("hero",   (-3.9, -5.4, 2.0),  (0, -0.05, 0.05)),
             ("crown",  (-1.2, -3.4, 4.6),  (0, -0.10, 0.70)),
             ("spine",  (0.2, 3.6, 4.4),    (0, 0.10, 0.70)),
             ("low",    (-2.4, -4.6, 0.15), (0, -0.05, 0.35)))
    outdir = paths.RENDERS
    os.makedirs(outdir, exist_ok=True)
    for name, loc, aim in SHOTS:
        cam.location = Vector(loc)
        point_at(cam, aim)
        scene.render.filepath = os.path.join(outdir, "view_%s_%s.png" % (SKIN, name))
        bpy.ops.render.render(write_still=True)
        print("  rendered %s" % name, flush=True)
