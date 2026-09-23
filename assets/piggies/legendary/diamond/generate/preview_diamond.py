# -*- coding: utf-8 -*-
"""Render the diamond pack the way the game will composite it.

    blender --background --python assets/piggies/legendary/diamond/generate/preview_diamond.py

`make/make_view_blend.py` puts a sheet straight into Base Color, which is right
for a full-colour coat and wrong here: this pack is an OVERLAY
(`lerp(partColour, mapRGB, mapAlpha)` over the skin's ice blue) with a normal
and a roughness map beside it. So this builds that composite, under the same
game-derived sun, sky and lawn, and renders the usual four angles to
`renders/view_diamond_*.png`.
"""

import os as _os, sys as _sys
_root = _os.path.dirname(_os.path.abspath(__file__))
while not (_os.path.exists(_os.path.join(_root, "paths.py"))
           or _os.path.exists(_os.path.join(_root, "blender", "pig", "paths.py"))):
    _up = _os.path.dirname(_root)
    if _up == _root:
        raise RuntimeError("cannot find blender/pig/paths.py above %s" % __file__)
    _root = _up
if not _os.path.exists(_os.path.join(_root, "paths.py")):
    _root = _os.path.join(_root, "blender", "pig")
if _root not in _sys.path:
    _sys.path.insert(0, _root)

import paths   # noqa: E402
import bpy, os, math
from mathutils import Vector

SKIN = "diamond"
# `Config.SKINS.diamond.body` / `.trim`.
BODY_RGB = (150, 226, 236)
TRIM_RGB = (104, 190, 208)
SUN_ELEV, SUN_AZI = 50.9, -74.8
SUN_RGB, SKY_RGB, GRASS_RGB = (255, 243, 210), (88, 100, 132), (82, 114, 60)


def lin(t):
    def one(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return tuple(one(v) for v in t)


bpy.ops.wm.open_mainfile(filepath=paths.PARTS)
scene = bpy.context.scene
for n in ("NostrilPreview", "Fur_mane", "Fur_crest"):
    o = bpy.data.objects.get(n)
    if o:
        bpy.data.objects.remove(o, do_unlink=True)


def pack_material(group, rgb):
    d = paths.skin_sheets_dir(SKIN)
    m = bpy.data.materials.new("diamond_" + group)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    N, L = nt.nodes.new, nt.links.new

    col = N("ShaderNodeTexImage")
    col.image = bpy.data.images.load(os.path.join(d, "%s_%s_color.png" % (SKIN, group)))
    col.image.alpha_mode = 'CHANNEL_PACKED'
    mix = N("ShaderNodeMix"); mix.data_type = 'RGBA'
    mix.inputs["A"].default_value = lin(rgb) + (1.0,)
    L(col.outputs["Alpha"], mix.inputs["Factor"])
    L(col.outputs["Color"], mix.inputs["B"])
    L(mix.outputs["Result"], bsdf.inputs["Base Color"])

    nrm = N("ShaderNodeTexImage")
    nrm.image = bpy.data.images.load(os.path.join(d, "%s_%s_normal.png" % (SKIN, group)))
    nrm.image.colorspace_settings.name = "Non-Color"
    nmap = N("ShaderNodeNormalMap")
    L(nrm.outputs["Color"], nmap.inputs["Color"])
    L(nmap.outputs["Normal"], bsdf.inputs["Normal"])

    rgh = N("ShaderNodeTexImage")
    rgh.image = bpy.data.images.load(os.path.join(d, "%s_%s_roughness.png" % (SKIN, group)))
    rgh.image.colorspace_settings.name = "Non-Color"
    L(rgh.outputs["Color"], bsdf.inputs["Roughness"])
    return m


body = bpy.data.objects["Body"]
body.data.materials.clear()
body.data.materials.append(pack_material("body", BODY_RGB))
trim_mat = pack_material("trim", TRIM_RGB)
for n in ("Snout", "Ears", "Legs", "Tail"):
    o = bpy.data.objects.get(n)
    if o:
        o.data.materials.clear()
        o.data.materials.append(trim_mat)

eye = bpy.data.objects.get("EyePreview")
if eye:
    em = bpy.data.materials.new("eye")
    em.use_nodes = True
    em.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = lin((38, 30, 34)) + (1.0,)
    eye.data.materials.clear()
    eye.data.materials.append(em)

bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, -1.02))
gm = bpy.data.materials.new("lawn")
gm.use_nodes = True
gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = lin(GRASS_RGB) + (1.0,)
bpy.context.active_object.data.materials.append(gm)

w = bpy.data.worlds.new("sky")
scene.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = lin(SKY_RGB) + (1.0,)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.5
sd = bpy.data.lights.new("sun", type='SUN')
sd.energy = 2.4
sd.color = lin(SUN_RGB)
sun = bpy.data.objects.new("Sun", sd)
scene.collection.objects.link(sun)
el, az = math.radians(SUN_ELEV), math.radians(SUN_AZI)
dvec = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
sun.rotation_euler = (-dvec).to_track_quat('-Z', 'Y').to_euler()

scene.render.engine = 'BLENDER_EEVEE'
scene.view_settings.view_transform = 'Standard'
scene.render.resolution_x = scene.render.resolution_y = 700
cam = bpy.data.objects.new("View", bpy.data.cameras.new("view"))
cam.data.lens = 62
scene.collection.objects.link(cam)
scene.camera = cam

os.makedirs(paths.RENDERS, exist_ok=True)
for name, loc, aim in (("hero", (-3.9, -5.4, 2.0), (0, -0.05, 0.05)),
                       ("side", (-6.2, 0.4, 1.2), (0, 0, 0.1)),
                       ("crown", (-1.2, -3.4, 4.6), (0, -0.10, 0.70)),
                       ("spine", (0.2, 3.6, 4.4), (0, 0.10, 0.70))):
    cam.location = Vector(loc)
    cam.rotation_euler = (Vector(aim) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = os.path.join(paths.RENDERS, "view_diamond_%s.png" % name)
    bpy.ops.render.render(write_still=True)
    print("  rendered", name, flush=True)
