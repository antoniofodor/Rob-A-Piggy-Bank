# -*- coding: utf-8 -*-
"""Install Meshy's painted sheet as the Storm Wolf's coat, and export the mesh
that actually matches it.

    blender --background --python make/install_stormwolf_texture.py

Reads `skins/stormwolf/source/*.png`, writes `skins/stormwolf/stormwolf_body_color.png`
and `pig/pig_stormwolf.obj`.

WHY THE GEOMETRY IS IGNORED. Meshy was handed `pig_stormwolf_textured.glb` --
our own 20k retopo -- and RE-PAINTED it rather than re-generating. Measured
against `skins/stormwolf/stormwolf.blend`: 9,992 verts and 20,000 tris both
sides, loop order identical on all 60,000, vertex positions matching to
0.000000 once its uniform scale is undone, and UVs matching to 0.000000.

So the returned mesh is our mesh. The only new thing in that download is the
IMAGE, and taking the geometry back would mean re-doing the seating, the
symmetry recentre and the smoothing to arrive where we already are.

**AND THAT IS WHY THE EXPORTED .obj HAD TO MOVE.** `make_stormwolf.py` writes
`pig_stormwolf.obj` out of `pig_stormwolf_20k.blend`, which carries `pig_uv`'s
SHARED CYLINDER unwrap -- right when the plan was to wear a sheet from
`skins/`, and wrong now. This coat is painted on the SMART-PROJECT unwrap in
the skin blend, and the two are not interchangeable: pairing this map with the
cylinder mesh renders a smear, and nothing about either file says so. The mesh
that gets uploaded has to be the one the texture was painted through, so it
comes out of the skin blend from here on.

THE CYLINDER MESH IS NOT DELETED and is still what `make_stormwolf_bolts.py`
reads, because the bolts are placed off GEOMETRY -- crystal tips and a
normalised bounding box -- and could not care less which unwrap is on it.
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
import bpy                                                # noqa: E402

argv = _sys.argv[_sys.argv.index("--") + 1:] if "--" in _sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SKIN = paths.skin_dir("stormwolf")
SOURCE = _os.path.join(SKIN, "source")
SHEET = _os.path.join(SKIN, "stormwolf_body_color.png")
BLEND = _os.path.join(SKIN, "stormwolf.blend")

# ROBLOX'S CAP, the same number `bake_skin.py` delivers at and for the same
# reason: anything larger is downscaled on upload anyway, so the choice is
# whether the downsample is ours or theirs. Ours is reproducible.
SIZE = int(arg("--size", "1024"))
GAME_BODY_X = 12.0

if not _os.path.isdir(SOURCE):
    raise SystemExit("  ! no %s -- put Meshy's download there" % SOURCE)
pngs = sorted(f for f in _os.listdir(SOURCE) if f.lower().endswith(".png"))
if not pngs:
    raise SystemExit("  ! no .png in %s" % SOURCE)
if len(pngs) > 1:
    raise SystemExit("  ! %d .png files in %s -- name the one to use with "
                     "--png: %s" % (len(pngs), SOURCE, pngs))
SRC_PNG = _os.path.join(SOURCE, arg("--png", pngs[0]))

bpy.ops.wm.open_mainfile(filepath=BLEND)
ob = bpy.data.objects.get("Body")
if ob is None:
    raise SystemExit("  ! no Body in %s -- run make_stormwolf_skin.py" % BLEND)
if not ob.data.uv_layers:
    raise SystemExit("  ! %s has no UV layer" % BLEND)

# --- the sheet --------------------------------------------------------------
img = bpy.data.images.load(SRC_PNG)
w0, h0 = img.size
print("  source: %s  %dx%d" % (_os.path.basename(SRC_PNG), w0, h0))

# **SAMPLED BEFORE AND AFTER, BECAUSE A RESIZE IS A COLOUR OPERATION.** Blender
# carries an image's colour space with it, and a scale-then-save that picks up a
# view transform on the way out comes back visibly lighter -- which would look
# like Meshy having painted a paler animal rather than like this script having
# altered it. Comparing the same relative texel each side is the cheap check;
# `save()` rather than `save_render()` is what keeps it honest, because the
# latter applies the scene's view transform.
img.colorspace_settings.name = 'sRGB'


def probe(im, label):
    ww, hh = im.size
    px = im.pixels[:]
    out = []
    for fx, fy in ((0.25, 0.25), (0.5, 0.5), (0.75, 0.62)):
        x, y = int(ww * fx), int(hh * fy)
        o = (y * ww + x) * im.channels
        out.append(tuple(round(px[o + c], 4) for c in range(3)))
    print("  %-7s %dx%d  texels %s" % (label, ww, hh, out))
    return out


before = probe(img, "before")
if (w0, h0) != (SIZE, SIZE):
    img.scale(SIZE, SIZE)
after = probe(img, "after")

drift = max(abs(a - b) for pa, pb in zip(before, after) for a, b in zip(pa, pb))
print("  colour drift across the resize: %.4f" % drift)
if drift > 0.12:
    raise SystemExit("  ! the resize moved the colours by %.3f -- that is a "
                     "colour-space problem, not a resample" % drift)

img.filepath_raw = SHEET
img.file_format = 'PNG'
img.save()
print("  wrote %s (%.1f KB)"
      % (_os.path.relpath(SHEET, _root), _os.path.getsize(SHEET) / 1024.0))

# --- the mesh that matches it ----------------------------------------------
bpy.ops.object.select_all(action='DESELECT')
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
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
tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
xs = [v.co.x * scale for v in ob.data.vertices]
ys = [v.co.y * scale for v in ob.data.vertices]
zs = [v.co.z * scale for v in ob.data.vertices]
print("  mesh:   %d tris, smart-project UVs (the ones this sheet is painted on)"
      % tris)
print("  studs:  x %.2f  y %.2f  z %.2f   (scale %.4f)"
      % (max(xs) - min(xs), max(zs) - min(zs), max(ys) - min(ys), scale))
print("  wrote %s" % _os.path.relpath(out, _root))
