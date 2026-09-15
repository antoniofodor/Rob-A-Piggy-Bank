# -*- coding: utf-8 -*-
"""An EDITABLE pig: every part its own object, nothing stacked on anything.

    blender.exe --background --python make_parts_blend.py
    blender.exe --background --python make_parts_blend.py -- --export

WHAT THIS IS FOR. `build_pig.py` is a GENERATOR and `pig.blend` is its OUTPUT
-- it ends with `save_as_mainfile`, so anything shaped by hand in that file is
destroyed, silently, the next time anybody runs the build. This writes a
SECOND file, `pig_parts.blend`, which no generator ever overwrites. That is the
whole reason it is a separate file rather than a tidy-up of the first one.

WHAT WAS IN THE WAY. The four trim pieces already exist in `pig.blend` and are
already separate objects -- but so is the JOINED `Trim` they were cut from, and
all five are visible in the viewport at once, occupying exactly the same space.
Measured: Trim 6,728 verts sitting under Snout 1,245 + Ears 3,580 + Legs 1,024
+ Tail 879, which is the same 6,728 twice over. Clicking an ear selects
whichever the depth buffer happened to hand you, and half of any edit lands on
a mesh that is about to be thrown away. That is not a scene you can work in.

So this drops the joined Trim, keeps the five real parts, and leaves the eye
and nostril previews as unselectable reference so they cannot be grabbed by
accident while still showing where the face is.

THE VERTEX GROUPS ARE PRUNED TO THE PART'S OWN. `part_from_group` copies the
whole mesh and deletes what is not in the group, so each piece arrives
carrying all four group names with three of them empty. Harmless, and exactly
the sort of leftover that later reads as "which group is this ear actually
in?".

NOTHING IS MOVED. Not the origins, not the transforms, not the scale. Every
offset in `Config.PIGGY_TRIM_PARTS` was measured off these world bounds, so a
tidied origin here is four wrong numbers in the game -- and a wrong `size` on a
MeshPart does not fail, it SCALES the mesh, which this project has already paid
for once on the fur tufts.

--export RE-EXPORTS AND THEN TELLS YOU WHAT MOVED. Editing a part changes its
bounding box, and `Config.PIGGY_TRIM_PARTS` carries that box. A hand-edited ear
exported without updating those numbers is a mesh squeezed into the old box
with nothing erroring, so the export prints the paste block AND diffs it
against what Config currently holds.
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
HERE = _root

import paths   # noqa: E402 -- the one place that knows the layout

import bpy
import bmesh
import os
import re
import sys

from mathutils import Vector


SRC = paths.RAW
DST = paths.PARTS
# WHERE THE PAINTING HAPPENS, AND IT IS DELIBERATELY NOT `DST`. `split()` ends
# in `save_as_mainfile(DST)`, so this script OVERWRITES `pig_parts.blend` every
# time it runs -- exactly the way `build_pig.py` overwrites `pig.blend`, and for
# the same reason. A texture-paint session lives in a copy no generator writes
# to, and the masks are saved as external PNGs besides, so the blend is genuinely
# disposable: re-copy it and re-open the images.
PAINT = paths.pig("pig_paint.blend")

# The five that become MeshParts in the game, in build order.
PARTS = ["Body", "Snout", "Ears", "Legs", "Tail"]
# Kept, but locked: they are where the face is, and they never leave Blender.
REFERENCE = ["EyePreview", "NostrilPreview"]
JOINED = "Trim"


def build_constants():
    """SCALE and LIFT, READ OUT OF `build_pig.py` RATHER THAN COPIED.

    Two copies of a scale factor is the duplicate this project keeps paying
    for -- the road width, the ride-key grammar, `SUNK` read by two halves of
    one shop. Parsing the source is ugly and it cannot drift: the generator
    stays the one place those numbers are decided, and if either name ever
    moves this raises here instead of exporting a pig at the wrong size.
    """
    src = open(os.path.join(HERE, "build_pig.py"), encoding="utf-8").read()

    def num(pattern):
        m = re.search(pattern, src, re.M)
        if not m:
            raise RuntimeError("cannot read %r out of build_pig.py" % pattern)
        return float(m.group(1))

    body_rx = num(r"^BODY_RX, BODY_RY, BODY_RZ = ([0-9.]+)")
    game_body_r = num(r"^GAME_BODY_R\s*=\s*([0-9.]+)")
    game_lawn_y = num(r"^GAME_LAWN_Y\s*=\s*([0-9.-]+)")
    leg_bottom = num(r"^LEG_BOTTOM\s*=\s*([0-9.-]+)")
    scale = game_body_r / body_rx
    return scale, game_lawn_y - leg_bottom * scale


def world_bounds(ob):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for c in ob.bound_box:
        w = ob.matrix_world @ Vector(c)
        for i in range(3):
            lo[i] = min(lo[i], w[i])
            hi[i] = max(hi[i], w[i])
    return lo, hi


def rbx_box(ob, scale, lift):
    """Roblox offset and size for a part, the same way `build_pig.py` prints
    it: Blender is Z-up and Roblox is Y-up, so the axes are swapped and Y is
    negated."""
    lo, hi = world_bounds(ob)
    c = (lo + hi) / 2.0
    off = Vector((c.x * scale, lift + c.z * scale, -c.y * scale))
    size = Vector((hi.x - lo.x, hi.z - lo.z, hi.y - lo.y)) * scale
    return off, size


def prune_groups(ob):
    """Leave a part carrying only the group it actually is."""
    keep = ob.name
    for vg in list(ob.vertex_groups):
        if vg.name != keep:
            ob.vertex_groups.remove(vg)


def split():
    bpy.ops.wm.open_mainfile(filepath=SRC)
    scene = bpy.context.scene

    missing = [n for n in PARTS if n not in bpy.data.objects]
    if missing:
        raise RuntimeError(
            "pig.blend has no %s -- run build_pig.py first, it is what cuts "
            "the trim into pieces" % ", ".join(missing))

    joined = bpy.data.objects.get(JOINED)
    if joined:
        n = len(joined.data.vertices)
        bpy.data.objects.remove(joined, do_unlink=True)
        print("  removed the joined %s (%d verts) -- the five parts below "
              "are the same geometry, unstacked" % (JOINED, n))

    total = 0
    for name in PARTS:
        ob = bpy.data.objects[name]
        ob.hide_render = False
        ob.hide_viewport = False
        ob.hide_set(False)
        ob.hide_select = False
        if name != "Body":
            prune_groups(ob)
        total += len(ob.data.vertices)

    # THE FUR SETS COME IN AS THEIR OWN OBJECTS, and only the fur does.
    #
    # `make_fur_tufts.py` writes a whole blend per set -- `pig_tufts.blend` for
    # the mane, `pig_crest.blend` for the crest -- and each carries its OWN copy
    # of Body, Trim and EyePreview from whenever that set was last built. Those
    # copies are stale the moment the pig is rebuilt, so appending a scene would
    # drag an old pig in beside the new one. Only the `FurTufts` object is
    # taken, and it is renamed for its set: two of them in one file cannot both
    # be called the same thing, and `Fur_mane` says which is which where
    # `FurTufts.001` would not.
    #
    # THEY NEED NO REBUILD WHEN THE TRIM CHANGES. The fur seats on the BODY --
    # a crest between the ears, a mane over the crown and cheeks -- and the tail
    # and muzzle fixes are both on the Trim, so the body these were grown
    # against is the body that is here. Re-run `make_fur_tufts.py` only when the
    # BODY moves, and note it takes its set from an env var:
    #     FUR_SET=crest blender --background --python make_fur_tufts.py
    for setname, src in (("mane", "pig_tufts.blend"), ("crest", "pig_crest.blend")):
        path = paths.pig(src)
        if not os.path.exists(path):
            continue
        before = set(bpy.data.objects)
        bpy.ops.wm.append(filepath=os.path.join(path, "Object", "FurTufts"),
                          directory=os.path.join(path, "Object"),
                          filename="FurTufts")
        for ob in set(bpy.data.objects) - before:
            ob.name = "Fur_" + setname
            ob.hide_render = False
            ob.hide_select = False
            # ONE SET IS WORN AT A TIME, so the second is present but out of the
            # way rather than overlapping the first. A skin names its set in
            # `Config.SKINS.<key>.furSet`; the zebra is the crest, and anything
            # that names none gets the mane.
            ob.hide_set(setname != "mane")
            print("  fur set %-6s appended as %-10s (%d verts)"
                  % (setname, ob.name, len(ob.data.vertices)))

    for name in REFERENCE:
        ob = bpy.data.objects.get(name)
        if ob:
            # SELECTABLE OFF RATHER THAN HIDDEN. The whole point of these is to
            # show where the face is while an ear is being shaped, and a
            # reference you cannot see is not one -- but a reference you can
            # grab by accident is worse than none.
            ob.hide_select = True
            ob.hide_render = True

    # RE-UNWRAPPED ON THE WAY OUT, OR THIS SCRIPT SILENTLY UNDOES THE MOVE OFF
    # THE CYLINDER. `pig.blend` is the generator's output and carries
    # `uv_cylinder`'s wrap -- 43 body faces with UVs past u = 1.0, which
    # `bpy.ops.object.bake` cannot write and the mesh then samples wrapped. The
    # symptom is a torn band down the spine that reads as a rendering fault.
    #
    # So the working file is unwrapped with Smart UV Project every time it is
    # built, and `export_meshes.py` sends THIS geometry out. Rebuilding the
    # parts file without it would leave the blend and the uploaded mesh
    # describing different address books, with nothing to say so.
    import reunwrap
    reunwrap.reunwrap_all()

    # THIS SCRIPT REBUILDS FROM `pig.blend` AND THEREFORE DESTROYS HAND WORK,
    # WHICH STOPPED BEING THEORETICAL THE DAY A SKIN WAS AUTHORED IN HERE.
    #
    # The header above says this file is "a SECOND file which no generator ever
    # overwrites" -- true of `build_pig.py` and never true of THIS script,
    # which is a generator too. Run casually to pick up a geometry change, it
    # replaced a bee's three hand-built materials and a two-slot ear with an
    # empty parts file, and nothing said a word: the pig still built, the parts
    # were all there, and only the materials had gone.
    #
    # So the outgoing file is copied first. It costs half a megabyte and it is
    # the only recovery path, because nothing under `blender/` is in git.
    if os.path.exists(DST):
        import shutil
        bak = DST[:-6] + ".before-rebuild.blend"
        shutil.copy2(DST, bak)
        n = 0
        try:
            n = len(bpy.data.materials)
        except Exception:
            pass
        print("")
        print("  ! %s already existed and has been copied to %s"
              % (os.path.basename(DST), os.path.basename(bak)))
        print("    Anything authored in it -- materials, material slots, hand")
        print("    edits -- is NOT carried across. Rebuild only for geometry.")

    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.wm.save_as_mainfile(filepath=DST)

    # SAID OUT LOUD, BECAUSE THE FAILURE IS SILENT. A rebuild here does not
    # touch `pig_paint.blend` -- which is the point of it -- so a paint file
    # sitting beside a freshly rebuilt parts file is holding the OLD geometry
    # and nothing about either says so.
    if os.path.exists(PAINT):
        print("")
        print("  ! pig_paint.blend exists and was NOT rebuilt. It still holds")
        print("    the geometry it was copied from. If the mesh changed above,")
        print("    re-copy it and re-open your masks -- they are external PNGs,")
        print("    so nothing you painted is lost either way.")

    print("")
    print("=== %s ===" % os.path.basename(DST))
    for name in PARTS:
        ob = bpy.data.objects[name]
        lo, hi = world_bounds(ob)
        print("  %-6s verts %5d   x %6.3f..%6.3f  y %6.3f..%6.3f  z %6.3f..%6.3f"
              % (name, len(ob.data.vertices), lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))
    for name in REFERENCE:
        if name in bpy.data.objects:
            print("  %-6s reference only, locked from selection" % name)
    print("  %d vertices across %d editable parts" % (total, len(PARTS)))
    print("saved", DST)


def export():
    """Send hand-edited parts back out as the .obj files the game loads."""
    scale, lift = build_constants()
    bpy.ops.wm.open_mainfile(filepath=DST)

    print("")
    print("=== EXPORT ===")
    for name in PARTS:
        ob = bpy.data.objects.get(name)
        if not ob:
            print("  ! %s is gone from %s, skipped" % (name, os.path.basename(DST)))
            continue
        bpy.ops.object.select_all(action='DESELECT')
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        path = paths.pig("pig_" + name.lower() + ".obj")
        # IDENTICAL SETTINGS TO `build_pig.py`. A different forward axis or a
        # dropped normal here is a pig that imports rotated or faceted, and
        # neither shows up until it is standing on a lawn.
        bpy.ops.wm.obj_export(filepath=path,
                              export_selected_objects=True,
                              forward_axis='NEGATIVE_Z', up_axis='Y',
                              global_scale=scale,
                              export_materials=False,
                              export_normals=True,
                              export_uv=True,
                              export_triangulated_mesh=True)
        print("  exported %s  (%d verts)" % (path, len(ob.data.vertices)))

    print("")
    print("=== PASTE INTO Config, AND CHECK WHAT MOVED ===")
    cfg = open(os.path.join(HERE, "..", "..", "src", "ReplicatedStorage",
                            "Shared", "Config.luau"), encoding="utf-8").read()
    for name in PARTS:
        ob = bpy.data.objects.get(name)
        if not ob:
            continue
        off, size = rbx_box(ob, scale, lift)
        print("  %-6s offset = Vector3.new(%.4f, %.4f, %.4f)   size = Vector3.new(%.4f, %.4f, %.4f)"
              % (name, off.x, off.y, off.z, size.x, size.y, size.z))
        # The part's own row in Config, so a change is announced rather than
        # left for somebody to notice as a squashed ear.
        m = re.search(r'part = "%s".*?size = Vector3\.new\(([-0-9., ]+)\)'
                      % name, cfg, re.S)
        if not m:
            print("         (no row in Config yet)")
            continue
        was = [float(v) for v in m.group(1).split(",")]
        drift = max(abs(a - b) for a, b in zip(was, [size.x, size.y, size.z]))
        if drift > 0.001:
            print("         *** SIZE MOVED by %.4f -- Config says %s."
                  " Paste the line above or the mesh is scaled into the old box."
                  % (drift, m.group(1).strip()))
        else:
            print("         matches Config")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--export" in argv:
        return export()
    return split()


main()
