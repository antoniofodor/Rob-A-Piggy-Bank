# -*- coding: utf-8 -*-
"""Delete the retired `NostrilPreview` inserts from every blend still carrying them.

    blender.exe --background --factory-startup --python strip_nostril_inserts.py

WHAT THESE ARE. Two thin blades -- 16 vertices between them, 0.392 by 0.033 by
0.079, which is 2.35 by 0.20 by 0.48 studs at the export scale -- seated in the
snout's nostril dimples as a dark DETAIL inside the hollow. `make_parts_blend`
already calls them "the retired black inserts" and strips them, and this is
what actually takes them out of the files rather than out of one export.

THE DIMPLES THEMSELVES ARE NOT TOUCHED AND MUST NOT BE. The bowls are sculpted
into the snout by the boolean in `build_pig.py` and are the nostrils; these
blades were a separate object sitting inside them. `check` below re-measures
the muzzle after the strip and refuses to write if the bowls have moved.

NOTHING BUILDS THEM ANY MORE, which is why deleting is enough and there is no
generator to edit: grepped across `blender/`, every mention is a REMOVE, a name
test or a comment. They are legacy objects that outlived the build that made
them, surviving only because they live in binary files no script rewrites.

WHERE THEY STILL REACHED. Not the shipped pig -- `export_meshes.py` drops them
before it writes `Body` and `Trim`, and `make_view_blend` and `make_dragon_kit`
drop them too. The one live leak is `export_whole.py`, which lists them in
`FACE` on purpose so a workbench export shows where the face lands. That
argument is sound for the EYES, which are code-built Parts with no geometry in
the mesh at all, and redundant for the nostrils: the snout carries the bowls,
so the hollow IS the record and the blade inside it adds nothing a modeller
could not already see.
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

import paths   # noqa: E402
import bpy, glob, math, os, sys   # noqa: E402
from mathutils import Vector      # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
DRY = "--dry" in argv

# The muzzle's own lift, so the bowls can be measured along the face's normal
# rather than along a world axis. Read from the generator for the reason
# `export_meshes.py` reads SCALE from it: two copies of a constant is the
# duplicate this project keeps paying for.
_SRC = open(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)),
                          "build_pig.py"), encoding="utf-8").read()
import re   # noqa: E402
SNOUT_LIFT = float(re.search(r"^SNOUT_LIFT\s*=\s*([0-9.]+)", _SRC, re.M).group(1))
NOS_SINK = float(re.search(r"^NOS_SINK\s*=\s*([0-9.]+)", _SRC, re.M).group(1))
_l = math.radians(SNOUT_LIFT)
FWD = Vector((0.0, -math.cos(_l), math.sin(_l)))


def bowl_depth(ob):
    """How deep the snout's dimples still are, along the face's own normal."""
    co = [v.co for v in ob.data.vertices]
    plane = max(c.dot(FWD) for c in co)
    return max(plane - c.dot(FWD) for c in co
               if (plane - c.dot(FWD)) < NOS_SINK * 1.5)


def strip(path):
    bpy.ops.wm.open_mainfile(filepath=path)
    hits = [o for o in bpy.data.objects if o.name.startswith("NostrilPreview")]
    snout = bpy.data.objects.get("Snout")
    before = bowl_depth(snout) if snout else None
    if not hits:
        print("     %-30s (already clean)" % os.path.basename(path))
        return 0
    n = sum(len(o.data.vertices) for o in hits if hasattr(o.data, "vertices"))
    for o in hits:
        bpy.data.objects.remove(o, do_unlink=True)

    # THE BOWLS HAVE TO BE EXACTLY WHERE THEY WERE. Deleting an object cannot
    # move the snout, so this is belt and braces -- and it is the check that
    # would have caught the mistake this script exists to undo.
    if snout is not None:
        after = bowl_depth(bpy.data.objects["Snout"])
        if abs(after - before) > 1e-6:
            raise RuntimeError("the snout moved: bowls %.4f -> %.4f"
                               % (before, after))
        note = "bowls still %.3f deep" % after
    else:
        note = "no Snout in this file"
    if DRY:
        print("DRY  %-30s would drop %d object(s), %d verts -- %s"
              % (os.path.basename(path), len(hits), n, note))
        return len(hits)
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)
    print("STRIP %-29s dropped %d object(s), %d verts -- %s"
          % (os.path.basename(path), len(hits), n, note))
    return len(hits)


targets = sorted(glob.glob(os.path.join(paths.PIG, "*.blend")))
total = 0
for p in targets:
    try:
        total += strip(p)
    except Exception as exc:                       # noqa: BLE001
        print("FAIL  %-29s %s" % (os.path.basename(p), exc))
print("[nostril-inserts] %d object(s) removed across %d blends%s"
      % (total, len(targets), " (dry run)" if DRY else ""))
