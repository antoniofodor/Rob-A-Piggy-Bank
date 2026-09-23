# -*- coding: utf-8 -*-
"""The Storm Wolf as it would stand on a lawn: Meshy's coat plus lit bolts.

    blender --background --python look/preview_stormwolf.py
    blender --background --python look/preview_stormwolf.py -- --nobolts

THE BOLTS ARE RENDERED AS EMISSION, WHICH IS THE POINT OF THE PICTURE. In the
game they are `Material.Neon` under a `BloomEffect` with a threshold of 1.8, and
this project has shipped four separate near-white Neon parts that rendered as
white holes -- the Martian skin, the palace colonnade, the townhouse windows and
the street lamp. The rule each of those produced is that A NEON PART WANTS A
DEEP COLOUR, because saturation is what survives being rendered flat out and
value is not. So the emission here is driven at a strength high enough to bloom
and a colour deep enough to still be cyan when it does, and the render is the
only thing that can say whether that held.

`BOLT` and `CORE` are `skins/stormstone`'s own, so the picture and the coat
cannot disagree about what colour the lightning is.
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

import paths                                       # noqa: E402
import bpy, math                                   # noqa: E402
from mathutils import Vector                       # noqa: E402

_argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
NOBOLTS = "--nobolts" in _argv


def _arg(name, default):
    return _argv[_argv.index(name) + 1] if name in _argv else default

# The Storm Stone palette, byte for byte -- and `BOLT` is the DEEPENED one.
#
# **THE PALE VALUE IS THE TRAP AND THIS PROJECT HAS FALLEN INTO IT FIVE TIMES**
# -- the Martian skin, the palace colonnade, the townhouse windows, the street
# lamp, and the first cyan bolts, all of which shipped near-white on Neon and
# all of which rendered as holes cut in the world. The rule each produced:
# SATURATION SURVIVES BEING RENDERED FLAT OUT AND VALUE DOES NOT, so a Neon
# part wants a colour a long way from white. (94, 226, 252) is a long way from
# white in hue and a short way in VALUE, which is why it clipped here at
# strength 5 and came back as a white streak. (52, 200, 246) is the value this
# project already deepened it to once, for this exact reason.
BOLT = (52 / 255.0, 200 / 255.0, 246 / 255.0)
CORE = (226 / 255.0, 250 / 255.0, 255 / 255.0)

# **THE MESH COMES OUT OF THE SKIN BLEND, NOT THE BOLT BLEND, AND GETTING THAT
# WRONG RENDERS GARBAGE RATHER THAN AN ERROR.** This animal exists in two files
# with two DIFFERENT unwraps on identical geometry: `pig_stormwolf_20k.blend`
# (and the bolt blend built from it) carries `pig_uv`'s shared cylinder, and
# `skins/stormwolf/stormwolf.blend` carries the smart-project unwrap the coat is
# actually painted through.
#
# Loading the bolt blend and applying the sheet was tried, and it came back as
# an animal covered in white blotches -- which reads as a corrupt texture rather
# than as the wrong mesh, because nothing anywhere says the two are not
# interchangeable. So the hide is loaded from the skin blend and the bolts are
# LINKED IN, each from the file that owns it.
bpy.ops.wm.open_mainfile(filepath=paths.skin_blend("stormwolf"))
ob = bpy.data.objects.get("Body")
if ob is None:
    raise SystemExit("  ! no Body in the stormwolf skin blend")
ob.name = "StormWolf"

_bolts_src = paths.pig("pig_stormwolf_bolts.blend")
if os.path.exists(_bolts_src):
    with bpy.data.libraries.load(_bolts_src) as (_frm, _to):
        _to.objects = [n for n in _frm.objects if n.startswith("Bolts_")]
    for _o in _to.objects:
        if _o is not None:
            bpy.context.scene.collection.objects.link(_o)
else:
    print("  ! %s missing -- rendering the hide alone" % _bolts_src)

# **THE HIDE WEARS A SKIN SHEET, NOT MESHY'S PAINT, AND THE SHADING IS LEFT
# ALONE.** This used to force every face flat, which was a preview choice
# rather than the animal: `make_stormwolf.py` shades by angle so the hide is
# smooth and the crystal facets stay crisp, and stamping `use_smooth = False`
# over the top threw that away and made the whole thing a gem. Whatever the
# build decided is what gets photographed.
#
# The sheet is this animal's OWN bake, and that is the fix for the stretch.
# Wearing `stormstone`'s sheet on `pig_uv`'s shared cylinder registered
# correctly and looked smeared, because a cylinder about the standing axis fits
# the shipped pig (texel density spread x1.2) and does not fit this one (x5.7):
# crystals standing out radially, a valley down the crest and a long flat snout
# all smear under that projection. `make_stormwolf_skin.py` gives the mesh its
# own unwrap -- spread x1.2, the shipped pig's own figure -- and bakes the same
# `stormstone_body` material onto it. The material reads `TexCoord.Object`, a
# real 3D field, so the plates come out the same PHYSICAL size as the pig's
# rather than merely similar.
# **AND THE UNWRAP IS CHECKED, NOT TRUSTED.** The two layouts are told apart by
# a number rather than by a filename: texel density spread is x1.2 on the
# smart-project unwrap and x5.7 on the cylinder, measured on this exact mesh. So
# anything much over 2 means the wrong blend got loaded, and it says so instead
# of photographing a smear.
def _density_spread(o):
    uvl = o.data.uv_layers.active
    M = o.matrix_world
    d = []
    for p in o.data.polygons:
        li = list(p.loop_indices)
        if len(li) < 3:
            continue
        a = M @ o.data.vertices[o.data.loops[li[0]].vertex_index].co
        b = M @ o.data.vertices[o.data.loops[li[1]].vertex_index].co
        c = M @ o.data.vertices[o.data.loops[li[2]].vertex_index].co
        ua, ub, uc = (uvl.data[li[0]].uv, uvl.data[li[1]].uv, uvl.data[li[2]].uv)
        a3 = (b - a).cross(c - a).length / 2
        a2 = abs((ub[0] - ua[0]) * (uc[1] - ua[1])
                 - (uc[0] - ua[0]) * (ub[1] - ua[1])) / 2
        if a3 > 1e-9 and a2 > 1e-12:
            d.append(math.sqrt(a2 / a3))
    d.sort()
    return (d[int(len(d) * 0.95)] / max(d[int(len(d) * 0.05)], 1e-9)) if d else 0


_spread = _density_spread(ob)
print("  unwrap: texel density spread x%.1f" % _spread)
if _spread > 2.5:
    raise SystemExit("  ! spread x%.1f means this is the CYLINDER unwrap -- the "
                     "coat is painted on the smart-project one and will smear"
                     % _spread)

_sheet = paths.skin_map("stormwolf", "body")
if os.path.exists(_sheet):
    hide = bpy.data.materials.new("stormwolf_hide")
    hide.use_nodes = True
    _hb = hide.node_tree.nodes["Principled BSDF"]
    _tex = hide.node_tree.nodes.new("ShaderNodeTexImage")
    _tex.image = bpy.data.images.load(_sheet)
    hide.node_tree.links.new(_tex.outputs["Color"], _hb.inputs["Base Color"])
    _hb.inputs["Roughness"].default_value = 0.82
    if "Specular IOR Level" in _hb.inputs:
        _hb.inputs["Specular IOR Level"].default_value = 0.22
    ob.data.materials.clear()
    ob.data.materials.append(hide)
    print("  hide: wearing %s" % os.path.relpath(_sheet, _root))
else:
    raise SystemExit("  ! %s missing -- run make_stormwolf_skin.py then "
                     "bake_skin.py --skin stormwolf" % _sheet)

# --- the bolts glow ---------------------------------------------------------
mat = bpy.data.materials.new("bolt_neon")
mat.use_nodes = True
nt = mat.node_tree
for n in list(nt.nodes):
    if n.type != 'OUTPUT_MATERIAL':
        nt.nodes.remove(n)
out = [n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'][0]
em = nt.nodes.new("ShaderNodeEmission")
em.inputs[0].default_value = (BOLT[0], BOLT[1], BOLT[2], 1.0)
# **STRENGTH 1.35, ARRIVED AT BY CLIPPING ARITHMETIC RATHER THAN BY TASTE.**
# It was 5 on the reasoning that 9 clips -- true, and 5 clips as well, which
# only a picture could say: every bolt in the first hero shot came back white.
#
# Emission MULTIPLIES the colour, so the brightest channel pins at 1.0 the
# moment strength passes 1/max(channel) -- here 1/0.965, about 1.04 -- and every
# channel that pins is a channel that has stopped carrying hue. At 2.2 both
# green and blue were pinned, leaving R 0.45 / G 1.0 / B 1.0: still cyan by
# ratio, and visibly washed out. At 1.35 only blue touches the ceiling.
#
# THIS IS ALSO THE HONEST PREVIEW OF `Material.Neon`, which renders a colour
# flat out and lets `WorldService`'s BloomEffect spread it afterwards. Driving
# emission harder here does not simulate that bloom -- it simulates thewhite  blowout
# the engine gets when somebody picks a pale Neon colour, which is a different
# bug and one this project has shipped five times.
em.inputs[1].default_value = 1.35
nt.links.new(em.outputs[0], out.inputs[0])

# **WHICH GROUPS ARE LIT THIS FRAME.** The point of dealing the bolts into
# phases is that only SOME are up at any moment, so a preview showing all six
# is a picture of the one state the animal is never in. `--lit p0,p3` picks
# them; the default is a plausible mid-flicker rather than everything.
_lit = _arg("--lit", "p0,p2,p4")
LIT = set(x.strip() for x in _lit.split(",") if x.strip())

nbolts = 0
_groups = sorted(o.name for o in bpy.data.objects if o.name.startswith("Bolts_"))
for o in bpy.data.objects:
    if not o.name.startswith("Bolts_"):
        continue
    tag_g = o.name.split("_")[-1]
    # THE EYES ARE NEVER SWITCHED OFF. They are driven by the same clock and
    # the same phase in game, with a `BoltFloor` so they swing between glowing
    # and blazing rather than between lit and gone -- a piggy whose eyes vanish
    # six times a minute reads as a rendering fault. Here they simply stay on.
    if tag_g == "eyes":
        o.data.materials.clear()
        o.data.materials.append(mat)
        continue
    if NOBOLTS or (LIT and tag_g not in LIT):
        o.hide_render = True
        continue
    o.data.materials.clear()
    o.data.materials.append(mat)
    nbolts += sum(len(p.vertices) - 2 for p in o.data.polygons)
print("  groups: %s   lit: %s" % (",".join(g.split("_")[-1] for g in _groups),
                                  ",".join(sorted(LIT)) if not NOBOLTS else "none"))
print("  bolts: %d tris across %d regions"
      % (nbolts, len([o for o in bpy.data.objects if o.name.startswith("Bolts_")])))

# --- a lawn to stand on, so the glow has something to spill onto -------------
# **THE LAWN SITS ON THE ANIMAL'S OWN FLOOR, NOT ON z 0.** The pig is modelled
# seated at `pig_uv.UV_Z0` -- its lowest point is -1.020, which is where the
# shipped pig's is -- so a ground plane at the origin buries it to the belly.
# The game does its own seating; here the floor is measured off the mesh, for
# the same reason the cameras are.
_floor = min((ob.matrix_world @ v.co).z for v in ob.data.vertices)
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, _floor))
lawn = bpy.context.active_object
lm = bpy.data.materials.new("lawn")
lm.use_nodes = True
lb = lm.node_tree.nodes["Principled BSDF"]
lb.inputs["Base Color"].default_value = (0.20, 0.26, 0.16, 1.0)
lb.inputs["Roughness"].default_value = 0.95
lawn.data.materials.append(lm)

sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x = sc.render.resolution_y = 1000
# **THERE IS NO GLARE PASS, AND THAT IS A MEASURED DEAD END RATHER THAN A
# TODO.** Three attempts, each failing differently and the last two silently:
#
#   * `sc.eevee.use_bloom` does not exist in 5.2. Guarded with `hasattr`, so it
#     bought NOTHING and the render simply had no glow -- which is half of why
#     the bolts were first driven hard enough to turn white.
#   * `sc.node_tree` does not exist either; it throws.
#   * `scene.compositing_node_group` DOES exist and takes a group, and every
#     setting on the Glare node moved from a property to an INPUT SOCKET -- so
#     `gl.threshold = 0.85` and `gl.size = 8` are not attributes any more, and a
#     `try/except` around them left the node on its defaults.
#
# Fixing all of that still did not work, and the A/B is what said so rather
# than another guess: rendered with no compositor the frame means RGB
# [57,57,56]; with a PASSTHROUGH group -- group input wired straight to group
# output, no glare anywhere -- it means [0,0,0]. So attaching any compositing
# group blacks the frame on this build, and the glare was never the fault.
#
# IT COSTS NOTHING, WHICH IS WHY IT STAYS DROPPED. The glow in the GAME is
# `WorldService`'s own `BloomEffect` at a threshold of 1.7, and this file's job
# is to say whether the bolt is the right shape and still CYAN when lit -- both
# of which a plain render answers. Faking the bloom by driving emission harder
# is what produced the white frame in the first place.

w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.19, 0.26, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.7
sc.world = w

sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN'))
sun.data.energy = 2.6
sun.data.color = (1.0, 0.96, 0.90)
sun.rotation_euler = (math.radians(56), 0, math.radians(38))
sc.collection.objects.link(sun)
fill = bpy.data.objects.new("F", bpy.data.lights.new("F", 'SUN'))
fill.data.energy = 0.8
fill.data.color = (0.72, 0.84, 1.0)
fill.rotation_euler = (math.radians(64), 0, math.radians(-135))
sc.collection.objects.link(fill)

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.lens = 55

# **THE CAMERAS ARE MEASURED OFF THE ANIMAL, NOT PINNED, AND THE FIRST SET WAS
# PINNED.** They aimed at a fixed (0, 0, 1.05), which was right while the mesh
# sat with its feet on z 0 -- and `make_stormwolf.py` then SEATED it properly,
# dropping the floor to `pig_uv.UV_Z0` at -1.020 so the shared UV cylinder
# registers. Every camera was suddenly aiming a stud above the pig and shooting
# down onto its own crest, which reads as a squashed animal rather than as a
# misaimed camera. Same family as the bolt regions that were written in
# absolute Z and silently matched nothing.
#
# Offsets are relative to the animal's own centre, so re-seating it, growing it
# or regenerating it carries the whole shot list along.
_c = [ob.matrix_world @ v.co for v in ob.data.vertices]
CX = 0.0
CY = (min(c.y for c in _c) + max(c.y for c in _c)) / 2
CZ = (min(c.z for c in _c) + max(c.z for c in _c)) / 2
print("  aim: centre (%.2f, %.2f, %.2f)" % (CX, CY, CZ))

SHOTS = (("hero",  (-3.5, -3.5, 0.70)),
         ("front", (0.0, -4.7, 0.30)),
         ("side",  (-4.7, 0.0, 0.30)),
         ("rear",  (0.6, 4.6, 0.60)),
         ("low",   (-2.6, -3.4, -0.50)))

tag = "_nobolts" if NOBOLTS else _arg("--tag", "")
# `--only hero` shoots one camera, which is what a flicker sequence wants: the
# question there is what CHANGES between frames, and five angles per frame
# buries it.
_only = _arg("--only", "")
for name, off in [x for x in SHOTS if not _only or x[0] == _only]:
    cam.location = Vector((CX + off[0], CY + off[1], CZ + off[2]))
    cam.rotation_euler = (Vector((CX, CY, CZ)) - cam.location
                          ).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = paths.render("stormwolf_%s%s.png" % (name, tag))
    bpy.ops.render.render(write_still=True)
    print("  rendered %s" % name, flush=True)

print("  wrote renders/stormwolf_*%s.png" % tag)
