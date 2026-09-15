# -*- coding: utf-8 -*-
"""What a FUR SET looks like on a coat, at a few candidate colours.

    python look/preview_fur.py --skin stormwolf
    python look/preview_fur.py --skin stormwolf --colours 18,20,32 44,58,112

WRITTEN FOR THE PHOENIX AND PROMOTED HERE UNCHANGED IN SUBSTANCE, because it
answers a question every skin carrying `furSet` will ask and nothing else in
the loop can: `make_view_blend.py` DELETES the fur before it renders, which is
right -- a skin is judged on its coat -- and leaves the one decision a fur skin
has to make invisible.

A skin asks for fur by carrying a `fur` COLOUR -- `PiggyBank.applyFur`: "THE
MESH IS THE FLAG" -- and that colour is a flat `Color3` on 36 tufts, so there
is nothing to texture and the only decision is which colour. That decision is
about how the ruff sits against the coat UNDER it, which is a thing to look at
rather than to reason about, and the ordinary preview cannot show it:
`make_view_blend.py` deletes `Fur_mane` outright, correctly, because a skin is
judged on the coat.

IT APPENDS THE MANE INTO THE ALREADY-BUILT VIEW SCENE rather than rebuilding
one. A second copy of `make_view_blend.py`'s sun rig would be the
near-identical duplicate this project keeps recording -- and it would be the
duplicate that decides a colour, so the two could disagree about the light the
colour was chosen under. Run the ordinary loop first; this reads its output.
"""
import os
import sys

# THE DEPTH-INDEPENDENT BOOTSTRAP, because this file has already moved once --
# `skins/phoenix/` was two levels down and `look/` is one, and a hardcoded `..`
# is the thing that breaks silently the first time anything is refiled.
_root = os.path.dirname(os.path.abspath(__file__))
while not os.path.exists(os.path.join(_root, "paths.py")):
    _up = os.path.dirname(_root)
    if _up == _root:
        raise RuntimeError("cannot find paths.py above %s" % __file__)
    _root = _up
sys.path.insert(0, _root)
import paths                                        # noqa: E402
import bpy                                          # noqa: E402
import math                                         # noqa: E402
from mathutils import Vector                        # noqa: E402

# EVERYTHING AFTER BLENDER'S OWN `--`, which is the convention every script in
# `make/` uses. Run under `blender --background --python`, `sys.argv` carries
# Blender's arguments too, and reading `sys.argv[1:]` picks up `--background`.
_argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]


def _arg(name, default=None):
    return _argv[_argv.index(name) + 1] if name in _argv else default


def _args(name):
    """Every value after `name` until the next flag.

    `--colours 16,16,26 44,58,112` arrives as SEPARATE argv entries, because a
    shell splits on spaces before this ever sees it -- so a single-value `_arg`
    reads the first triple and silently drops the rest, which renders one
    candidate and looks like the loop is broken.
    """
    if name not in _argv:
        return []
    out = []
    for v in _argv[_argv.index(name) + 1:]:
        if v.startswith("--"):
            break
        out.append(v)
    return out


SKIN = _arg("--skin", "phoenix")

# THE CANDIDATES. A ruff sits on the crown, the cheeks and the brisket --
# measured, `Fur_mane` spans y -1.071..0.568 -- so what it has to read against
# is whatever the coat is doing over the FRONT HALF of the animal, never the
# rump. That is the whole reason this is a picture rather than a colour picker.
#
# The defaults are the phoenix's, which is where this was written. Pass
# `--colours` as space-separated `r,g,b` triples for anything else.
_c = _args("--colours")
if _c:
    CANDIDATES = [("c%d" % i, tuple(int(v) for v in t.split(",")))
                  for i, t in enumerate(_c)]
else:
    CANDIDATES = [
        ("gold", (255, 198, 62)),
        ("ember", (255, 138, 34)),
        ("flame", (238, 88, 26)),
        ("crimson", (176, 34, 44)),
    ]


def srgb(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


bpy.ops.wm.open_mainfile(filepath=paths.skin_view(SKIN))

# THE MANE COMES OUT OF THE SKIN'S OWN BLEND, which is the same file the view
# was built from -- so the geometry is the one this coat was baked against
# rather than whatever `pig_parts.blend` happens to hold today.
src = paths.skin_blend(SKIN)
with bpy.data.libraries.load(src) as (frm, to):
    to.objects = [n for n in frm.objects if n == "Fur_mane"]
mane = to.objects[0]
if mane is None:
    raise SystemExit("  ! no Fur_mane in %s" % src)
bpy.context.scene.collection.objects.link(mane)
mane.hide_render = False

mat = bpy.data.materials.new("mane")
mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Roughness"].default_value = 0.92
if "Specular IOR Level" in bsdf.inputs:
    bsdf.inputs["Specular IOR Level"].default_value = 0.05
# ASSIGNED INTO SLOT 0 RATHER THAN CLEARED, which costs nothing here and keeps
# the one idiom this project bans out of every file in it: `materials.clear()`
# also resets every polygon's `material_index`, and `skin_parts.py` exists
# because two skin scripts destroyed a hand-made face selection with it. The
# mane has no such selection and this scene is never saved, so nothing is at
# risk -- but a reader should not have to work that out to know it is safe.
if mane.data.materials:
    mane.data.materials[0] = mat
else:
    mane.data.materials.append(mat)

cam = bpy.data.objects["View"]
scene = bpy.context.scene


def point_at(o, t):
    o.rotation_euler = (Vector(t) - o.location).to_track_quat('-Z',
                                                              'Y').to_euler()


SHOTS = (("hero", (-3.9, -5.4, 2.0), (0, -0.05, 0.05)),
         ("low", (-2.4, -4.6, 0.15), (0, -0.05, 0.35)))

made = []
for name, rgb in CANDIDATES:
    bsdf.inputs["Base Color"].default_value = tuple(srgb(v) for v in rgb) + (1.0,)
    row = []
    for shot, loc, aim in SHOTS:
        cam.location = Vector(loc)
        point_at(cam, aim)
        out = paths.render("fur_%s_%s_%s.png" % (SKIN, name, shot))
        scene.render.filepath = out
        bpy.ops.render.render(write_still=True)
        row.append(out)
    made.append((name, row))
    print("  %-8s %s rendered" % (name, rgb), flush=True)

print("  wrote renders/fur_%s_*.png -- one pair per candidate" % SKIN)
print("  a contact sheet is four lines of Pillow over these")
