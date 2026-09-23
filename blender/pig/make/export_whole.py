# -*- coding: utf-8 -*-
"""The WHOLE animal as one .obj -- body, trim, and optionally a fur set.

    blender --background --python make/export_whole.py
    blender --background --python make/export_whole.py -- --fur stormcrest

Writes `pig/pig_whole.obj` (or `pig_whole_<fur>.obj`).

WHY THIS IS NOT `export_meshes.py`. That file writes what the GAME uploads, and
the game wants the pieces apart: `Config.PIGGY_MESH` stands up a Body and a
joined Trim as separate MeshParts precisely so a skin can paint them two
different colours -- the segmentation entry in `CLAUDE.md` records that dropping
it costs all 46 skins their second tone. Merging them is therefore exactly what
must NOT happen on the upload path, and this file is deliberately a dead end:
nothing in the repo reads what it writes.

WHAT IT IS FOR is the workbench. Modelling anything that has to sit ON the pig
-- a crest, a saddle, a piece of armour -- means having the pig in front of you
in one piece, in one program, at the right scale. Two files and a fur set is
three imports and three chances to seat one of them wrong.

EXPORT SETTINGS ARE `export_meshes.py`'S, TO THE ARGUMENT, and the scale is
read from the same place rather than copied -- a different forward axis or a
dropped normal here is a model that imports rotated or faceted, and the whole
point of this file is that what you look at is what the game stands up.

SUBDIVISION IS STRIPPED for the reason that file gives at length: `wm.obj_export`
APPLIES MODIFIERS, so a Subsurf left on to preview a smoother animal leaves
with the export -- measured there at four times the triangles at viewport level
1 and sixteen at render level 2, with nothing in any log to say so.
"""

# --- find the toolkit, wherever this script has been filed ------------------
import os as _os, sys as _sys
_root = _os.path.dirname(_os.path.abspath(__file__))
while not _os.path.exists(_os.path.join(_root, "paths.py")):
    _up = _os.path.dirname(_root)
    if _up == _root:
        raise RuntimeError("cannot find paths.py above %s" % __file__)
    _root = _up
if _root not in _sys.path:
    _sys.path.insert(0, _root)

import paths                                        # noqa: E402
import bpy, os, sys                                 # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


BLEND = arg("--blend", paths.PARTS)
FUR = arg("--fur", "")
PARTS = ["Body", "Snout", "Ears", "Legs", "Tail"]

# **THE EYES AND NOSTRILS ARE PREVIEW OBJECTS AND THEY ARE STILL THE RIGHT
# THING TO EXPORT.** Neither is part of the uploaded mesh: the game builds
# both as code-built Roblox Parts, which is what lets `applySkin` recolour an
# eye and switch it to Neon for a glowing legendary. So they sit in the master
# blend only as a record of WHERE those parts land.
#
# That record is what a workbench needs. Anything modelled to sit near the
# face -- a brow, a mask, a crest coming down the forehead -- has to be judged
# against the eyes being there, and a pig exported without them invites
# exactly the clipping this project has already paid for on the padlock, the
# visor and the cape.
#
# VERIFIED RATHER THAN TRUSTED FOR ITS NAME, and re-verified on every run
# below. A preview object that had quietly drifted from the thing it previews
# would be worse than no preview at all.
# `NostrilPreview` WAS IN THIS LIST AND IS GONE (2026-09-21), which narrows
# the argument above rather than overturning it.
#
# It holds for the EYES exactly as written: they are code-built Roblox Parts,
# there is no eye geometry in the mesh at all, and a pig exported without them
# invites the clipping this project has already paid for on the padlock, the
# visor and the cape. So `EyePreview` stays.
#
# It does not hold for the nostrils, because the snout is not missing them --
# `build_pig.py` cuts the two bowls into it with a boolean, so the HOLLOW is
# the record and a workbench sees exactly where they are without help. The
# blades that used to sit inside those hollows were a dark DETAIL rather than
# a marker: 16 vertices, 0.392 by 0.033 by 0.079, retired long enough ago that
# `make_parts_blend` calls them "the retired black inserts" and strips them,
# and nothing in `blender/` has built one in a very long time.
#
# THIS EXPORT WAS THE ONLY PLACE THEY STILL REACHED. `export_meshes` drops
# them before writing `Body` and `Trim`, and `make_view_blend` and
# `make_dragon_kit` drop them too -- so the shipped pig never carried one and
# this was the last leak. They are out of the blends themselves now; see
# `strip_nostril_inserts.py`.
FACE = ["EyePreview"]
if "--no-face" in argv:
    FACE = []


# **SCALE IS MEASURED OFF THE BODY, AND THE FIRST DRAFT PARSED IT INSTEAD AND
# FELL BACK SILENTLY.** It read `build_pig.py` through `paths.make(...)`, which
# is not a function `paths` has -- so the parse threw, a bare `except` caught
# it, and the fallback ran on every single invocation. It produced the RIGHT
# number, which is exactly why it would have survived: a wrong scale does not
# fail, it silently resizes the animal, and a fallback that is always taken is
# a primary path nobody has ever run.
#
# So there is one path now and it is the measured one. `Config.PIGGY_MESH`
# records the body as 12.0000 studs across, so the modelled body's own X extent
# is the divisor -- which is what `make_fur_tufts.py` does, is exact rather
# than approximate, and cannot go stale against a regenerated pig the way a
# parsed constant can.
GAME_BODY_X = 12.0

bpy.ops.wm.open_mainfile(filepath=paths.find(BLEND, "blend"))

_bx = [v.co.x for v in bpy.data.objects["Body"].data.vertices]
SCALE = GAME_BODY_X / (max(_bx) - min(_bx))

missing = [n for n in PARTS if n not in bpy.data.objects]
if missing:
    raise SystemExit("  ! %s has no %s" % (BLEND, missing))

# A face part that is absent is skipped rather than fatal -- an older master
# may predate them, and a pig with no eyeballs is a smaller problem than a
# build that refuses to run.
FACE = [n for n in FACE if n in bpy.data.objects]

# THE LANDMARK, CHECKED ON EVERY RUN. `CLAUDE.md` records the eyes at
# (+-0.318, -0.889, 0.364) with a 0.105 eyeball radius, and every accessory,
# every skin mask and now the crest is cut against those numbers.
EYE_X, EYE_Y, EYE_Z, EYE_R = 0.318, -0.889, 0.364, 0.105
if "EyePreview" in FACE:
    _e = bpy.data.objects["EyePreview"]
    _p = [_e.matrix_world @ _v.co for _v in _e.data.vertices]
    _cy = (min(q[1] for q in _p) + max(q[1] for q in _p)) / 2
    _cz = (min(q[2] for q in _p) + max(q[2] for q in _p)) / 2
    _cx = (min(q[0] for q in _p) + max(q[0] for q in _p)) / 2
    _half = max(q[0] for q in _p) - _cx
    _drift = max(abs(_cy - EYE_Y), abs(_cz - EYE_Z),
                 abs((_half - EYE_R) - EYE_X))
    print("  eyes: each at (%.3f, %.3f, %.3f) r %.3f -- drift %.4f%s"
          % (_half - EYE_R, _cy, _cz, EYE_R, _drift,
             " from the recorded landmark"
             if _drift < 0.01 else "   <-- MOVED, check CLAUDE.md"))

# THE FUR SET COMES OUT OF ITS OWN BLEND, in the pig's own frame -- see
# `look/preview_crest.py`. It needs no seating, which is worth knowing before
# anybody adds a transform here.
fur_obj = None
if FUR:
    src = paths.pig("pig_tufts.blend" if FUR == "mane" else "pig_%s.blend" % FUR)
    if not os.path.exists(src):
        raise SystemExit("  ! %s missing -- run FUR_SET=%s make_fur_tufts.py"
                         % (src, FUR))
    with bpy.data.libraries.load(src) as (frm, to):
        to.objects = [n for n in frm.objects if n == "FurTufts"]
    if not to.objects or to.objects[0] is None:
        raise SystemExit("  ! no FurTufts in %s" % src)
    fur_obj = to.objects[0]
    bpy.context.scene.collection.objects.link(fur_obj)

for _ob in list(bpy.data.objects):
    if _ob.type != 'MESH':
        continue
    for _m in list(_ob.modifiers):
        if _m.type == 'SUBSURF':
            print("  ! removed %s from %s" % (_m.name, _ob.name))
            _ob.modifiers.remove(_m)

# JOIN COPIES, NEVER THE ORIGINALS. Joining in place would leave the master
# with no separate Body and Trim to bake or re-export from -- and this file is
# run against `pig_parts.blend`, which is the master.
sources = [bpy.data.objects[n] for n in PARTS + FACE]
if fur_obj is not None:
    sources.append(fur_obj)

copies = []
for ob in sources:
    c = ob.copy()
    c.data = ob.data.copy()
    bpy.context.scene.collection.objects.link(c)
    # **`hide_select` IS WHY THE EYES WERE MISSING, AND IT FAILED IN SILENCE
    # AT EVERY SINGLE STEP.** `EyePreview` carries `hide_select = True` in the
    # master -- sensibly, so it cannot be grabbed by accident while somebody is
    # modelling the animal around it. (`NostrilPreview` carried it too and is
    # gone; see `FACE` above.)
    # A copy inherits it, `select_set(True)` then does NOTHING AND RETURNS
    # NOTHING, `join()` reports FINISHED because it joined what it was given,
    # and the export comes out without a face.
    #
    # Nothing errored, and the summary this file prints listed both objects as
    # included, because that line reads the REQUEST rather than the result.
    # What caught it was the vertex count not moving when 548 verts were
    # supposedly added -- the same tell as `bake_alpha` measuring an identical
    # 37.51% across three "fixes": A NUMBER THAT DOES NOT CHANGE WHEN IT
    # SHOULD IS THE EVIDENCE.
    #
    # All four flags are cleared on the COPY, never the original: the master
    # keeps its unselectable previews, which is what they are for.
    c.hide_select = False
    c.hide_viewport = False
    c.hide_render = False
    c.hide_set(False)
    copies.append(c)

bpy.ops.object.select_all(action='DESELECT')
for c in copies:
    c.select_set(True)

# AND THE SELECTION IS CHECKED RATHER THAN ASSUMED. This is the one line that
# turns the failure above from silent into loud, and it costs nothing.
_got = [o for o in bpy.context.selected_objects]
if len(_got) != len(copies):
    raise SystemExit("  ! only %d of %d parts could be selected -- missing %s"
                     % (len(_got), len(copies),
                        sorted({c.name for c in copies}
                               - {o.name for o in _got})))

bpy.context.view_layer.objects.active = copies[0]
_want = sum(len(c.data.vertices) for c in copies)
bpy.ops.object.join()
whole = bpy.context.view_layer.objects.active
whole.name = "Pig"

# THE JOIN IS CHECKED THE SAME WAY, because `join()` returns FINISHED whether
# it took every object or one of them.
if len(whole.data.vertices) != _want:
    raise SystemExit("  ! joined %d verts, expected %d"
                     % (len(whole.data.vertices), _want))

name = "pig_whole%s.obj" % (("_" + FUR) if FUR else "")
path = paths.pig(name)
bpy.ops.object.select_all(action='DESELECT')
whole.select_set(True)
bpy.context.view_layer.objects.active = whole
bpy.ops.wm.obj_export(filepath=path,
                      export_selected_objects=True,
                      forward_axis='NEGATIVE_Z', up_axis='Y',
                      global_scale=SCALE,
                      export_materials=False,
                      export_normals=True,
                      export_uv=True,
                      export_triangulated_mesh=True)

tris = sum(len(p.vertices) - 2 for p in whole.data.polygons)
xs = [v.co.x * SCALE for v in whole.data.vertices]
ys = [v.co.y * SCALE for v in whole.data.vertices]
zs = [v.co.z * SCALE for v in whole.data.vertices]
print("")
print("=== WHOLE PIG  (scale %.6f, from %s) ===" % (SCALE, BLEND))
print("  parts: %s" % ", ".join(PARTS + FACE + ([FUR] if FUR else [])))
print("  %d verts  %d tris" % (len(whole.data.vertices), tris))
# THE EXPORTER TURNS BLENDER (x, y, z) INTO (x, z, -y), so the studs printed
# here are the axes the model actually arrives on rather than Blender's.
print("  studs: x %.2f  y %.2f  z %.2f"
      % (max(xs) - min(xs), max(zs) - min(zs), max(ys) - min(ys)))
print("  wrote %s" % os.path.relpath(path, _root))
