# -*- coding: utf-8 -*-
# SAVED OUT OF A SESSION SCRATCHPAD, WHICH IS WHERE IT SHOULD NEVER HAVE LIVED.
#
# Every preview render this project has looked at -- the animal pack, the
# bumblebee's per-part trim, the zebra broadside -- was produced by a script in
# a session-local temp directory. The pictures landed in the repo and the thing
# that MAKES them did not, so re-rendering after any change meant writing the
# renderer again from scratch. A tool that only exists inside one conversation
# is a tool the next person does not have.
#
# THE PATH IS DERIVED FROM `__file__` RATHER THAN PINNED. These carried an
# absolute path to blender/pig, which breaks the moment the folder moves --
# and it is moving.
"""Render every animal in the pack, in its real Config colours.

DIFFUSE AND FLAT, because that is what the engine gives a packed part -- the
same simulation that finally matched reality on the metal work. The tufts are
shown only on the skins that actually wear them.
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
import bpy, os, math
from mathutils import Vector

D = os.path.dirname(os.path.abspath(__file__))
import sys
if D not in sys.path:
    sys.path.insert(0, D)
import skin_colours


# RENDERS GO IN `renders/`, NEVER BESIDE THE ASSETS. Every picture this script
# writes is reproducible by running it again, and the folder it used to write
# into holds the .obj files that actually ship -- so a session of previewing
# buried the deliverables under 46 screenshots and 17 MB. `.gitignore` already
# refuses *.png outside `skins/`, so nothing here was ever committed; what it
# could not do is stop them piling up on disk.
RENDERS = paths.RENDERS
os.makedirs(RENDERS, exist_ok=True)

A = paths.skin_dir("animal")
bpy.ops.wm.open_mainfile(filepath=paths.pig("pig_tufts.blend"))
scene = bpy.context.scene
body = bpy.data.objects["Body"]
trim = bpy.data.objects["Trim"]
tufts = bpy.data.objects.get("FurTufts")

# THE MANE IS PER ANIMAL NOW, SO THE PREVIEW HAS TO CARRY MORE THAN ONE.
# `pig_tufts.blend` holds the full mane (crest + ruffs + brisket) and
# `pig_crest.blend` holds the zebra's forelock; appending the second into the
# first is what lets one render answer for both without two scene files that
# can drift apart.
crest = None
_cb = paths.pig("pig_crest.blend")
if os.path.exists(_cb):
    _before = set(bpy.data.objects)
    with bpy.data.libraries.load(_cb) as (src, dst):
        dst.objects = [n for n in src.objects if n == "FurTufts"]
    for _o in set(bpy.data.objects) - _before:
        scene.collection.objects.link(_o)
        _o.name = "FurCrest"
        crest = _o
FURS = {"mane": tufts, "crest": crest}

_cache = {}


def img(name):
    if name not in _cache:
        i = bpy.data.images.load(os.path.join(A, name))
        i.colorspace_settings.name = 'sRGB'
        i.alpha_mode = 'CHANNEL_PACKED'
        _cache[name] = i
    return _cache[name]


def skin(tag, base, mapfile):
    m = bpy.data.materials.new(tag)
    m.use_nodes = True
    t = m.node_tree
    b = t.nodes.get("Principled BSDF")
    b.inputs["Metallic"].default_value = 0.0
    b.inputs["Roughness"].default_value = 0.82
    if mapfile:
        tex = t.nodes.new("ShaderNodeTexImage")
        tex.image = img(mapfile)
        tex.extension = 'REPEAT'
        mix = t.nodes.new("ShaderNodeMixRGB")
        mix.blend_type = 'MIX'
        mix.inputs["Color1"].default_value = base
        t.links.new(tex.outputs["Color"], mix.inputs["Color2"])
        t.links.new(tex.outputs["Alpha"], mix.inputs["Fac"])
        t.links.new(mix.outputs["Color"], b.inputs["Base Color"])
    else:
        b.inputs["Base Color"].default_value = base
    return m


def point_at(o, t):
    o.rotation_euler = (Vector(t) - o.location).to_track_quat('-Z', 'Y').to_euler()


w = bpy.data.worlds.new("w")
scene.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.60, 0.68, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.55
for nm, loc, en, sz in (("key", (-4.0, -5.0, 4.5), 700, 5.0),
                        ("fill", (5.0, -3.0, 1.5), 260, 7.0),
                        ("rim", (1.0, 4.5, 4.0), 320, 5.0)):
    ld = bpy.data.lights.new(nm, type='AREA')
    ld.energy, ld.size = en, sz
    o = bpy.data.objects.new(nm, ld)
    scene.collection.objects.link(o)
    o.location = Vector(loc)
    point_at(o, (0, 0, 0.05))
cd = bpy.data.cameras.new("c")
cd.lens = 62
cam = bpy.data.objects.new("c", cd)
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = Vector((-3.9, -5.4, 2.0))
point_at(cam, (0.0, -0.05, 0.05))
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 44
scene.cycles.use_denoising = True
scene.render.resolution_x = 460
scene.render.resolution_y = 460
scene.view_settings.view_transform = 'Standard'

eye = bpy.data.objects.get("EyePreview")
if eye:
    em = bpy.data.materials.new("eye")
    em.use_nodes = True
    em.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.02, 0.02, 0.03, 1)
    eye.data.materials.clear()
    eye.data.materials.append(em)


def rgb(r, g, b):
    """A byte triple as Blender wants it: LINEAR, and a 4-tuple.

    THIS USED TO SKIP THE CONVERSION AND EVERY PREVIEW IN THE PACK WAS
    RENDERING LIGHTER THAN THE GAME DRAWS IT. A shader's `default_value` is
    read as linear and `Color3.fromRGB` is sRGB, so handing the byte value
    straight over lifts a mid-tone by roughly a fifth -- most on the darks,
    which is exactly where a pattern's contrast is decided. Nothing errored and
    nothing looked broken; the sheet was simply a picture of a paler pig.

    Same family as the generated material multiplying against `Part.Color`, and
    as taking a texture off a surface making it a third brighter: a colour that
    is wrong by a transfer function looks like a colour somebody chose.
    """
    return skin_colours.to_linear((r / 255.0, g / 255.0, b / 255.0)) + (1.0,)


# key, body, trim, map, wears the mane, PATTERN ON THE TRIM TOO
#
# The trim shares the body's cylindrical unwrap on ONE shared V range, so a
# marking at a given height lands in the same place on the snout, the ears and
# the legs as it does on the flank. Reference plush zebras carry their stripes
# straight across the muzzle, and a zebra whose face stops striping at the
# snout reads as a painted pig rather than as a zebra.
# THE TRIM IS NOT STRIPED, AND THAT REVERSES THE ZEBRA'S FIRST PASS.
#
# The unlock is real -- the trim genuinely shares the body's cylinder over one
# V range, so a marking lands at the same height on a leg as on the flank --
# and it does NOT survive contact with the SNOUT. That part sits on the
# cylinder's own axis, where `atan2` is degenerate: a couple of studs of width
# spans most of the U range, so one bar covers the entire muzzle. Rendered
# three ways side by side, the striped trim put a single black smear across
# the face and took half of each ear with it, while the plain dark trim reads
# as a black nose, black hooves and a black tuft -- which is what the plush
# reference has anyway.
#
# THE LESSON IS ABOUT THE UNWRAP RATHER THAN ABOUT THE ZEBRA: a cylindrical
# map is trustworthy on anything that stands OFF the axis (legs, ears, flanks)
# and meaningless on anything that straddles it. Any future "run the pattern
# onto the trim" idea gets checked at the snout first.
# THE COLOURS ARE NOT IN THIS TABLE ANY MORE -- see `skin_colours.py`. Two of
# the eight had drifted from the catalogue by the time anybody measured: the
# bee's body was a lemon against a Config that had twice decided it should be
# a honey, and the zebra's trim was a stop darker than the one that ships. A
# sheet used to JUDGE a pattern was showing pigs nobody can buy, and a slightly
# wrong yellow looks exactly like a yellow.
#
# What stays is what the preview genuinely owns: which map dresses which
# animal, and which fur set it wears.
PACK = [
    ("ladybug",  "ladybird", "pig_dots_big_color.png",     None,    None),
    ("cow",      "cow",      "pig_blotches_color.png",     None,    None),
    ("zebra",    "zebra",    "pig_stripes_bold_color.png", "crest", None),
    ("bee",      "bee",      "pig_bands_color.png",        None,    None),
    ("giraffe",  "giraffe",  "pig_patches_color.png",      None,    None),
    ("orca",     "orca",     "pig_orca_color.png",         None,    None),
    ("tiger",    "tiger",    "pig_stripes_color.png",      "mane",  None),
    ("leopard",  "leopard",  "pig_spots_color.png",        "mane",  None),
]

for key, skinkey, mp, furset, trimmap in PACK:
    _b, _t = skin_colours.skin(skinkey)
    bcol = skin_colours.to_linear(_b) + (1.0,)
    tcol = skin_colours.to_linear(_t) + (1.0,)
    body.data.materials.clear()
    body.data.materials.append(skin("b_" + key, bcol, mp))
    trim.data.materials.clear()
    trim.data.materials.append(skin("t_" + key, tcol, trimmap))
    for _name, _ob in FURS.items():
        if _ob is None:
            continue
        _ob.hide_render = (_name != furset)
        if _name == furset:
            _ob.data.materials.clear()
            # THE ZEBRA'S TUFT TAKES THE TRIM COLOUR, NOT THE BODY'S PATTERN.
            # A striped forelock is seven strands each carrying a fragment of
            # a bar, which is noise at that size; the plush reference has one
            # solid black brush and so does this.
            _ob.data.materials.append(
                skin("f_" + key, tcol, None) if furset == "crest"
                else skin("f_" + key, bcol, mp))
    scene.render.filepath = os.path.join(RENDERS, "pack_%s.png" % key)
    bpy.ops.render.render(write_still=True)
    print("rendered", key)
