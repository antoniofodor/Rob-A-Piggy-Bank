# -*- coding: utf-8 -*-
"""The Storm Wolf HIDE: Meshy's shape, wearing the pack's own skin system.

    blender --background --python make/make_stormwolf.py
    blender --background --python make/make_stormwolf.py -- --tris 20000
    blender --background --python make/make_stormwolf.py -- --meshy-uv

Writes `pig/pig_stormwolf.obj` and `pig/pig_stormwolf_20k.blend`.

WHY MESHY'S OWN 4K MAP IS THROWN AWAY, WHICH IS THE WHOLE POINT OF THIS FILE.
The texture stage hands back a painted, photographic rock -- crazed, noisy, and
lit from directions that are not this game's. Every other skin in the pack is
FLAT COLOUR under a baked pattern sheet, unwrapped on one shared cylinder, and
a single animal wearing a photograph among forty-six that are not is the
failure this project already recorded for the shops: *"four TEXTURED boxes on a
street where nothing else had a texture left"*, where five of the six textured
materials had been removed from every other building and the shops were the
only noisy objects in frame.

So the hide is unwrapped on `pig_uv`'s cylinder like everything else, and any
sheet in `skins/` fits it. Meshy's map is still in `pig_stormwolf_hi.blend` and
`--meshy-uv` keeps it, because backing this out should cost one flag rather
than a re-import.

SHADED BY ANGLE RATHER THAN FULLY SMOOTH, AND BOTH HALVES ARE WANTED. The ask
is a SMOOTH animal; the crystals are faceted and must stay so, or the crest
turns into a row of soft blobs. `shade_smooth_by_angle` is exactly that split
and it needs no per-face selection: the hide is dense with shallow angles
between neighbours so it smooths, while a crystal facet meets its neighbour far
past any honest threshold and stays crisp. `make_fur_tufts.py` makes the
OPPOSITE call for its lobes and says why -- a low-poly lobe has 45 degrees
between its own sides, so an angle split would leave it a gem. Nothing here is
pretending to be soft except the body, which genuinely is.

THE FRAME IS THE SHIPPED PIG'S, NOT MESHY'S. The animal is scaled so its body
is 2.0 across and SEATED so its lowest point lands on `pig_uv.UV_Z0` -- which
is where the shipped pig's lowest point is. That is what makes v mean the same
thing here as everywhere else, and `check_drift` reports it rather than this
file asserting it.
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
import pig_uv                                             # noqa: E402
import bpy, math                                          # noqa: E402

argv = _sys.argv[_sys.argv.index("--") + 1:] if "--" in _sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


HI = paths.pig("pig_stormwolf_hi.blend")
TRIS = int(arg("--tris", "20000"))
KEEP_MESHY_UV = "--meshy-uv" in argv

# **THE ROBLOX CEILING IS 21,000 TRIANGLES PER MeshPart**, so 20,000 leaves a
# little back rather than sitting on the number. Meshy hands back 1,948,720:
# ninety-three times over, which is a retopo rather than a tuning problem.
TRI_CEILING = 21000

# **BODY ACROSS, IN STUDS.** `Config.PIGGY_MESH` records 12.0 and every export
# in this folder measures its own divisor off that rather than pinning 6.0.
GAME_BODY_X = 12.0

# A COPY OF `build_pig.SMOOTH_ANGLE`, and a deliberate one. That file cannot be
# imported -- it builds the pig at module scope -- and unlike `UV_SPAN` this is
# a per-mesh SHADING choice rather than a shared registration, so the two
# drifting apart makes one animal shade slightly differently rather than
# sliding every pattern map underneath it. If they should ever be one number,
# `pig_uv` is the wrong home for it; a `pig_shading.py` would be the right one.
SMOOTH_ANGLE = 40.0

if not _os.path.exists(HI):
    raise SystemExit("  ! %s missing -- import Meshy's textured OBJ first" % HI)

bpy.ops.wm.open_mainfile(filepath=HI)
ob = bpy.data.objects.get("StormWolf")
if ob is None:
    raise SystemExit("  ! no StormWolf in %s" % HI)

bpy.context.view_layer.objects.active = ob
ob.select_set(True)

# --- orientation ------------------------------------------------------------
# **MESHY'S OBJ ARRIVES up=Y AND THE PIPELINE IS up=Z.** Measured rather than
# assumed on the way in: after this turn the WIDE end of the long axis (the
# snout, 0.640 across) sits at -Y and the narrow crystal tail at +Y, which is
# this project's nose convention. A pig imported the other way up is not
# obviously wrong in a render, which is why it is checked below rather than
# trusted.
ob.rotation_euler = (math.radians(90), 0, 0)
bpy.ops.object.transform_apply(rotation=True)

# --- to budget --------------------------------------------------------------
src = len(ob.data.polygons)
if src > TRIS:
    m = ob.modifiers.new("dec", 'DECIMATE')
    m.ratio = float(TRIS) / src
    bpy.ops.object.modifier_apply(modifier=m.name)
got = len(ob.data.polygons)
if got > TRI_CEILING:
    raise SystemExit("  ! %d tris is over the %d MeshPart ceiling"
                     % (got, TRI_CEILING))
print("  retopo: %d -> %d tris (%.2f%%), %d verts"
      % (src, got, 100.0 * got / src, len(ob.data.vertices)))

# --- the pig's own frame ----------------------------------------------------
k = 2.0 / ob.dimensions.x
ob.scale = (k, k, k)
bpy.ops.object.transform_apply(scale=True)
ob.location = (0.0, 0.0, 0.0)
bpy.context.view_layer.update()

# --- the animal is not centred on its own bounding box ----------------------
#
# **AND THE BOUNDING BOX SAYS IT IS, WHICH IS WHY THIS NEEDED SOLVING RATHER
# THAN READING.** The box centres at x 0.0000 to four decimal places. The
# ANIMAL does not: mirroring the mesh about x 0 and asking every vertex how far
# it is from its reflection gives a median error of 0.1082, where mirroring
# about x -0.115 gives 0.0146. Seven times better, with a clean minimum -- the
# sweep runs 0.0875 / 0.0182 / 0.1082 / 0.2964 across the range, so it is a
# genuine axis rather than noise.
#
# What pulls the box straight is the CRYSTALS: they are organic output and they
# differ left to right, so a spike further out on one side balances the box
# while the body under it sits off to the other. Same family as the Sky Castle
# measuring "16.6 studs too wide" when what was really being measured was its
# FX at altitude, and as the widest lawn ornament that turned out to be a
# height: THE CONVENIENT NUMBER AND THE LOAD-BEARING ONE ARE DIFFERENT NUMBERS.
#
# It matters three times over. Every accessory anchor in this game is on x 0, so
# an off-centre animal wears its hat and its glasses crooked. The bolt
# generator takes radial directions from a centre it assumes is on the axis. And
# a face that is a tenth of a stud off centre is the kind of thing that reads as
# wrong without anybody being able to say why.
#
# SOLVED PER RUN, NEVER PINNED, so a regenerated animal recentres itself.
import mathutils                                          # noqa: E402


def _symmetry_shift(o):
    co = [o.matrix_world @ v.co for v in o.data.vertices]
    kd = mathutils.kdtree.KDTree(len(co))
    for i, c in enumerate(co):
        kd.insert(c, i)
    kd.balance()

    def med_err(sh):
        errs = []
        for c in co[::17]:
            _, _, d = kd.find(mathutils.Vector((2 * sh - c.x, c.y, c.z)))
            errs.append(d)
        errs.sort()
        return errs[len(errs) // 2]

    best, span, step = 0.0, 0.25, 0.01
    for _ in range(3):                       # coarse, then twice refined
        cands = [best + i * step for i in range(-int(span / step),
                                                int(span / step) + 1)]
        best = min(cands, key=med_err)
        span, step = step * 2, step / 5
    return best, med_err(best), med_err(0.0)


_shift, _err, _err0 = _symmetry_shift(ob)
print("  symmetry: plane at x %+.4f (mirror error %.4f, against %.4f at x 0)"
      % (_shift, _err, _err0))
if _err0 <= _err:
    print("  symmetry: already centred, not moving it")
else:
    for _v in ob.data.vertices:
        _v.co.x -= _shift
    print("  symmetry: recentred by %+.4f" % -_shift)
bpy.context.view_layer.update()
bpy.context.view_layer.update()
zs = [(ob.matrix_world @ v.co).z for v in ob.data.vertices]
ob.location.z = pig_uv.UV_Z0 - min(zs)
bpy.context.view_layer.update()

co = [ob.matrix_world @ v.co for v in ob.data.vertices]
ylo, yhi = min(c.y for c in co), max(c.y for c in co)
span = yhi - ylo
lo = [c for c in co if c.y < ylo + span * 0.12]
hi = [c for c in co if c.y > yhi - span * 0.12]
wlo = max(c.x for c in lo) - min(c.x for c in lo)
whi = max(c.x for c in hi) - min(c.x for c in hi)
print("  nose check: -Y end %.3f across, +Y end %.3f across -- %s"
      % (wlo, whi,
         "snout at -Y, correct" if wlo > whi
         else "*** SNOUT AT +Y, THE TURN IS WRONG ***"))
if wlo <= whi:
    raise SystemExit("  ! the animal is back to front")

# --- one shared cylinder ----------------------------------------------------
#
# COPIED FROM `build_pig.uv_cylinder`, INCLUDING THE PER-FACE SEAM FIX, for the
# reason `make_fur_tufts.py` gives where it makes the same copy: that file
# cannot be imported, and the thing that MUST be shared is the height range
# rather than the loop. u is the angle about the standing axis; v is height
# over `pig_uv`'s pinned range, so a marking at a given height lands at the
# same place here as on the body, the snout and the tufts.
#
# THE SEAM FIX IS PER FACE AND NEVER PER VERTEX. A vertex on the wrap needs
# u ~ 0 for the faces one side of it and u ~ 1 for the other, so there is no
# single value to give it; UVs are per LOOP, so each face is made continuous
# with itself and runs 0.98 -> 1.02 rather than 0.98 -> 0.02. Outside 0..1 is
# what texture REPEAT is for.
if KEEP_MESHY_UV:
    print("  uv: KEEPING Meshy's own unwrap (--meshy-uv)")
else:
    pig_uv.check_drift((ob,), "stormwolf")
    zmin, vspan = pig_uv.UV_Z0, pig_uv.UV_SPAN
    me = ob.data
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    uvl = me.uv_layers.new(name="UVMap")
    wrapped = 0
    for p in me.polygons:
        us = []
        for li in p.loop_indices:
            c = ob.matrix_world @ me.vertices[me.loops[li].vertex_index].co
            u = (math.atan2(c.y, c.x) / (2.0 * math.pi)) + 0.5
            v = (c.z - zmin) / vspan
            uvl.data[li].uv = (u, v)
            us.append((li, u, v))
        if max(x[1] for x in us) - min(x[1] for x in us) > 0.5:
            wrapped += 1
            for li, u, v in us:
                if u < 0.5:
                    uvl.data[li].uv = (u + 1.0, v)
    print("  uv: cylinder shared with the body, %d faces carried across the wrap"
          % wrapped)
    print("  uv: v range %.3f..%.3f of the sheet"
          % (min(d.uv[1] for d in uvl.data), max(d.uv[1] for d in uvl.data)))

    # MESHY'S MAP GOES WITH ITS UVs. Leaving the image assigned to a mesh that
    # is no longer unwrapped for it would render a smear, and a smear that
    # nobody put there is worse than no texture at all.
    ob.data.materials.clear()

# --- smooth hide, crisp crystals -------------------------------------------
bpy.ops.object.select_all(action='DESELECT')
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
# `shade_smooth_by_angle` ACTS ON THE SELECTION rather than on the active
# object -- the note `build_pig.py` carries beside its own call, and the reason
# the count is checked afterwards instead of the operator being trusted.
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(SMOOTH_ANGLE))
smooth = sum(1 for p in ob.data.polygons if p.use_smooth)
print("  shading: %d of %d faces smooth at %.0f degrees"
      % (smooth, len(ob.data.polygons), SMOOTH_ANGLE))
if smooth == 0:
    raise SystemExit("  ! nothing smoothed -- shade_smooth hit the wrong object")

# --- out --------------------------------------------------------------------
scale = GAME_BODY_X / ob.dimensions.x
out = paths.pig("pig_stormwolf.obj")
bpy.ops.wm.obj_export(filepath=out,
                      export_selected_objects=True,
                      forward_axis='NEGATIVE_Z', up_axis='Y',
                      global_scale=scale,
                      export_materials=False,
                      export_normals=True,
                      export_uv=True,
                      export_triangulated_mesh=True)

bpy.ops.wm.save_as_mainfile(filepath=paths.pig("pig_stormwolf_20k.blend"))

xs = [v.co.x * scale for v in ob.data.vertices]
ys = [v.co.y * scale for v in ob.data.vertices]
zs = [v.co.z * scale for v in ob.data.vertices]
print("  studs: x %.2f  y %.2f  z %.2f   (scale %.4f)"
      % (max(xs) - min(xs), max(zs) - min(zs), max(ys) - min(ys), scale))
print("  wrote %s" % _os.path.relpath(out, _root))
