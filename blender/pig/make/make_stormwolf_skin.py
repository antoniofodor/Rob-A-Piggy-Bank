# -*- coding: utf-8 -*-
"""The Storm Wolf's own skin blend: its mesh, its own unwrap, Storm Stone's coat.

    blender --background --python make/make_stormwolf_skin.py
    blender --background --python make/make_stormwolf_skin.py -- --margin 0.008

Writes `skins/stormwolf/stormwolf.blend`, which `bake_skin.py --skin stormwolf`
then turns into `stormwolf_body_color.png` with no further arguments.

WHY THIS EXISTS: THE SHARED CYLINDER SMEARS THIS ANIMAL, AND IT IS MEASURED.
`pig_uv`'s cylinder is one projection about the standing axis, which fits the
shipped pig almost perfectly -- that animal is close to a body of revolution.
Texel density across it varies by a factor of 1.2 on the Body and 1.3 on the
Snout, which is even enough that nobody has ever had to think about it.

The Storm Wolf is not that shape. It has forty crystals standing out radially,
a deep valley down the crest and a long flat snout, and a cylinder projection
smears every one of them. Measured on the same instrument: **texel density
varies by a factor of 5.7**, p5 0.32 against p95 1.80. So some of the animal
wears five and a half times more pattern than the rest, which is exactly what
"the texture looks stretched out" is a description of.

SMART PROJECT IS SAFE HERE AND IS NOT SAFE THERE, WHICH IS WORTH BEING EXACT
ABOUT. `build_pig.uv_cylinder` refuses `smart_project` at length, and it is
right: that unwrap rotates each island to pack tightly, so the direction world
+Z maps to varies island by island -- coherence 0.583 on the body -- and a
BAND, which is a line, would run a different way on every island and break at
every seam.

That argument is about a texture whose CONTENT has a direction in UV space. It
does not apply to a BAKE. `stormstone_body` reads `TexCoord.Object` -- a real
three-dimensional field in the animal's own frame -- so every texel is resolved
from where it sits in SPACE rather than from where it sits on the sheet. The
unwrap only has to be bijective, evenly dense and margined; which way an island
happens to be turned is invisible to it.

AND THE PLATES COME OUT THE SAME PHYSICAL SIZE AS THE PIG'S, for the same
reason. An `Object`-space field does not know or care which mesh it is being
sampled through, so a Storm Wolf plate and a Storm Stone plate are the same
stone rather than two textures that merely look alike.
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

import paths                                              # noqa: E402
import bpy, math                                          # noqa: E402

argv = _sys.argv[_sys.argv.index("--") + 1:] if "--" in _sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SRC = paths.pig("pig_stormwolf_20k.blend")
DONOR = paths.skin_blend("stormstone")
MATERIAL = arg("--material", "stormstone_body")

# **THE MARGIN IS SOLVED AGAINST THE BAKE, NOT CHOSEN.** `bake_skin.py` bakes at
# SUPER = 2048 with `bake.margin = 8` texels, and bilinear filtering reaches
# outside an island -- so islands packed closer than that bleed into each other
# and the finished animal wears its own neighbouring plates along every seam.
# 8/2048 is 0.0039; 0.006 clears it with room, at the cost of a little sheet.
ISLAND_MARGIN = float(arg("--margin", "0.006"))
ANGLE_LIMIT = float(arg("--angle", "66"))

# What counts as evenly enough spread. The shipped pig measures 1.2 to 1.3, and
# anything under about 2 is invisible on a crazed stone pattern; the cylinder's
# 5.7 plainly is not. Reported and REFUSED rather than printed and ignored.
MAX_DENSITY_SPREAD = float(arg("--max-spread", "2.5"))


def density_spread(ob):
    """p95/p5 of sqrt(uv area / world area) per face -- how unevenly the sheet
    is spent. The number `uv_cylinder` reports as a V-density band, taken over
    both axes because a smart unwrap can stretch either."""
    me = ob.data
    uvl = me.uv_layers.active
    M = ob.matrix_world
    dens = []
    for p in me.polygons:
        li = list(p.loop_indices)
        if len(li) < 3:
            continue
        a = M @ me.vertices[me.loops[li[0]].vertex_index].co
        b = M @ me.vertices[me.loops[li[1]].vertex_index].co
        c = M @ me.vertices[me.loops[li[2]].vertex_index].co
        ua, ub, uc = (uvl.data[li[0]].uv, uvl.data[li[1]].uv, uvl.data[li[2]].uv)
        a3 = (b - a).cross(c - a).length / 2
        a2 = abs((ub[0] - ua[0]) * (uc[1] - ua[1])
                 - (uc[0] - ua[0]) * (ub[1] - ua[1])) / 2
        if a3 > 1e-9 and a2 > 1e-12:
            dens.append(math.sqrt(a2 / a3))
    dens.sort()
    n = len(dens)
    if n == 0:
        return 0.0, 0.0, 0.0
    lo = dens[int(n * 0.05)]
    hi = dens[int(n * 0.95)]
    med = dens[n // 2]
    return hi / max(lo, 1e-9), lo / med, hi / med


bpy.ops.wm.open_mainfile(filepath=SRC)
ob = bpy.data.objects.get("StormWolf")
if ob is None:
    raise SystemExit("  ! no StormWolf in %s -- run make_stormwolf.py first" % SRC)

before, blo, bhi = density_spread(ob)
print("  before: cylinder unwrap, density spread x%.1f (%.2f..%.2f of median)"
      % (before, blo, bhi))

# --- the coat ---------------------------------------------------------------
#
# APPENDED FROM `stormstone.blend` RATHER THAN REBUILT. `make_stormstone_blend.py`
# is 996 lines of node graph and running a second copy of it here would be the
# near-identical duplicate that drifts -- and worse than usual, because the two
# would diverge in COLOUR and nobody would be able to say which pig was right.
with bpy.data.libraries.load(paths.find(DONOR, "blend")) as (frm, to):
    if MATERIAL not in frm.materials:
        raise SystemExit("  ! %s has no material %r -- it has %s"
                         % (DONOR, MATERIAL, list(frm.materials)))
    to.materials = [MATERIAL]
mat = to.materials[0]
if mat is None:
    raise SystemExit("  ! %r failed to append from %s" % (MATERIAL, DONOR))
ob.data.materials.clear()
ob.data.materials.append(mat)
print("  coat: appended %r from %s" % (mat.name, _os.path.basename(DONOR)))

# --- its own unwrap ---------------------------------------------------------
bpy.ops.object.select_all(action='DESELECT')
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(ANGLE_LIMIT),
                         island_margin=ISLAND_MARGIN)
bpy.ops.object.mode_set(mode='OBJECT')

after, alo, ahi = density_spread(ob)
print("  after:  smart project, density spread x%.1f (%.2f..%.2f of median)"
      % (after, alo, ahi))
if after > MAX_DENSITY_SPREAD:
    raise SystemExit("  ! spread x%.1f is still over x%.1f -- the unwrap did "
                     "not take. Try a lower --angle." % (after, MAX_DENSITY_SPREAD))
print("  improvement: x%.1f -> x%.1f" % (before, after))

# --- what `bake_skin.py` expects to find ------------------------------------
#
# It walks `GROUPS`, which names `Body` and then the four trim parts, so the one
# object has to BE the body. The trim group finds nothing and bakes an empty
# sheet, which is correct: this animal is one MeshPart and has no second tone to
# carry -- the crystals, the snout and the ear insides are all painted into the
# one map by a field that knows where they are in space.
ob.name = "Body"

out = _os.path.join(paths.skin_dir("stormwolf"), "stormwolf.blend")
bpy.ops.wm.save_as_mainfile(filepath=out)
print("  wrote %s" % _os.path.relpath(out, _root))
print("  next: blender --background --python make/bake_skin.py -- --skin stormwolf")
