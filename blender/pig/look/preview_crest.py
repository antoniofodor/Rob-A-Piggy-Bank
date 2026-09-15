# -*- coding: utf-8 -*-
"""What a FUR SET's SHAPE looks like on a baked coat.

    blender --background --python look/preview_crest.py -- --skin stormstone --set stormcrest

DISTINCT FROM `preview_fur.py`, WHICH ANSWERS A DIFFERENT QUESTION. That file
renders a set at candidate flat COLOURS, because a mane is a flat `Color3` on
36 tufts and the only decision is which colour. A set that wears the body's own
coat has no such decision -- `applyFur` hands the ruff the BODY'S surface pack
and the lobe mesh is unwrapped on the same cylinder, so the pattern carries
straight over it -- and the open question becomes the SHAPE: does the silhouette
read, does it break the outline, does it sit on the animal or on top of it.

So this assigns the body's own material rather than a new one, which is the
closest thing Blender can do to what the engine does. Anything that looks wrong
here is the geometry rather than the paint.

IT APPENDS INTO THE ALREADY-BUILT VIEW SCENE, which is `preview_fur.py`'s call
and is made here for the same reason: a second copy of `make_view_blend.py`'s
sun rig would be the duplicate that decides a shape. Run the ordinary loop
first, then `make_fur_tufts.py` for the set, then this.

THE SET COMES OUT OF ITS OWN BLEND rather than the skin's. `make_fur_tufts.py`
writes `pig/pig_<set>.blend` (and `pig/pig_tufts.blend` for the mane, which
keeps the historic name), holding one object called `FurTufts` in the pig's own
frame -- the same frame the view scene is in, so it needs no seating at all.
That is worth knowing before anybody adds a transform here: if a set ever looks
offset, the fault is upstream in the export rather than in this file.
"""
import os
import sys

_root = os.path.dirname(os.path.abspath(__file__))
while not os.path.exists(os.path.join(_root, "paths.py")):
    _up = os.path.dirname(_root)
    if _up == _root:
        raise RuntimeError("cannot find paths.py above %s" % __file__)
    _root = _up
sys.path.insert(0, _root)
import paths                                        # noqa: E402
import bpy                                          # noqa: E402
from mathutils import Vector                        # noqa: E402

_argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]


def _arg(name, default=None):
    return _argv[_argv.index(name) + 1] if name in _argv else default


SKIN = _arg("--skin", "stormstone")
SET = _arg("--set", "stormcrest")
# **UNTEXTURED, WHICH IS HOW A SHAPE GETS LOOKED AT.** The crest wears the
# body's baked coat, which is the right answer in the game and the wrong one
# on a workbench: this skin's hide is near-black, so every facet of every
# shard was being judged against a map that gave it almost nothing to catch
# the light with -- and a shape that cannot be seen cannot be criticised. A
# flat mid-grey is the reference photograph's own tone and shows the polygons.
FLAT = "--flat" in _argv

bpy.ops.wm.open_mainfile(filepath=paths.skin_view(SKIN))

body = bpy.data.objects.get("Body")
if body is None:
    raise SystemExit("  ! no Body in %s -- run make_view_blend.py first"
                     % paths.skin_view(SKIN))

src = paths.pig("pig_tufts.blend" if SET == "mane" else "pig_%s.blend" % SET)
if not os.path.exists(src):
    raise SystemExit("  ! %s missing -- run FUR_SET=%s make_fur_tufts.py first"
                     % (src, SET))

with bpy.data.libraries.load(src) as (frm, to):
    to.objects = [n for n in frm.objects if n == "FurTufts"]
if not to.objects or to.objects[0] is None:
    raise SystemExit("  ! no FurTufts object in %s" % src)
crest = to.objects[0]
bpy.context.scene.collection.objects.link(crest)
crest.hide_render = False

# THE BODY'S OWN MATERIAL, NOT A COPY OF IT. Sharing the datablock is what
# makes this a test of the shape rather than of a second graph that could
# disagree with the coat about anything -- and it is also literally what the
# engine does, where the ruff is handed the body's `SurfaceAppearance`.
#
# ASSIGNED INTO SLOT 0 RATHER THAN CLEARED, for the reason `preview_fur.py`
# gives: `materials.clear()` also resets every polygon's `material_index`, and
# `skin_parts.py` exists because two skin scripts destroyed a hand-made face
# selection with it. Nothing is at risk here and a reader should not have to
# work that out.
if FLAT:
    mat = bpy.data.materials.new("crest_flat")
    mat.use_nodes = True
    _b = mat.node_tree.nodes["Principled BSDF"]
    _b.inputs["Base Color"].default_value = (0.26, 0.28, 0.32, 1.0)
    _b.inputs["Roughness"].default_value = 0.92
    if "Specular IOR Level" in _b.inputs:
        _b.inputs["Specular IOR Level"].default_value = 0.05
    # AND THE BODY GOES FLAT TOO, or the crest is judged against a patterned
    # hide it is meant to sit on -- which is the same confusion one layer
    # down. A plain body is also what the reference is: one tone, and the
    # geometry doing the work.
    _pale = bpy.data.materials.new("body_flat")
    _pale.use_nodes = True
    _pb = _pale.node_tree.nodes["Principled BSDF"]
    _pb.inputs["Base Color"].default_value = (0.20, 0.22, 0.26, 1.0)
    _pb.inputs["Roughness"].default_value = 0.92
    if body.data.materials:
        body.data.materials[0] = _pale
else:
    mat = body.data.materials[0] if body.data.materials else None
if mat is not None:
    if crest.data.materials:
        crest.data.materials[0] = mat
    else:
        crest.data.materials.append(mat)

tris = sum(len(p.vertices) - 2 for p in crest.data.polygons)
print("  %s: %d verts, %d tris, %s"
      % (SET, len(crest.data.vertices), tris,
         "flat grey -- judging the SHAPE" if FLAT else "wearing the body's coat"))

cam = bpy.data.objects["View"]
scene = bpy.context.scene


def point_at(o, t):
    o.rotation_euler = (Vector(t) - o.location).to_track_quat('-Z',
                                                             'Y').to_euler()


# THE SAME FOUR THE ORDINARY LOOP USES, so this and `view_<skin>_*.png` can be
# laid side by side and the only difference is the crest.
SHOTS = (("hero", (-3.9, -5.4, 2.0), (0, -0.05, 0.05)),
         ("low", (-2.4, -4.6, 0.15), (0, -0.05, 0.35)),
         ("crown", (-2.2, -3.6, 3.4), (0, -0.05, 0.30)),
         ("spine", (0.0, 5.6, 2.6), (0, 0.10, 0.20)))

for shot, loc, aim in SHOTS:
    cam.location = Vector(loc)
    point_at(cam, aim)
    out = paths.render("crest_%s_%s_%s%s.png"
                       % (SKIN, SET, shot, "_flat" if FLAT else ""))
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("  rendered %s" % shot, flush=True)

print("  wrote renders/crest_%s_%s_*%s.png"
      % (SKIN, SET, "_flat" if FLAT else ""))
