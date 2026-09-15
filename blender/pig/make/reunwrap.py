# -*- coding: utf-8 -*-
"""Re-unwrap the pig with Smart UV Project, for skins that are BAKED.

    blender.exe --background --python reunwrap.py -- --blend pig_parts.blend --out pig_uv2.blend

WHY, AND WHY IT REVERSES A DECISION THIS PROJECT ALREADY MADE ONCE.

`build_pig.py` unwraps every part on ONE cylinder about the standing axis, and
its own note records exactly why it moved OFF `smart_project`: that packer
rotates each island to fit tightly, so the direction world +Z maps to had a
coherence of **0.583 on the body and 0.282 on the trim** against the cylinder's
0.941 and 0.857 -- and a BAND, which is a line, would have run a different way
on every island.

**THAT ARGUMENT IS ABOUT DRAWING A PATTERN IN UV SPACE, AND IT DOES NOT APPLY
TO BAKING.** A generator that walks the flat sheet computing an alpha needs
islands that agree about direction. A BAKE does not care at all: it resolves
whatever layout it is handed, because the pattern is defined in the WORLD and
the UV map is only the address book. The coherence measurement was used to
block this and it was the wrong measurement for the job.

WHAT THE CYLINDER WAS COSTING, MEASURED ON THE SHIPPED MESH:

  * **43 body faces have UVs running past u = 1.0**, out to 1.500 --
    `uv_cylinder` pushes a wrapping face a whole turn rather than splitting it,
    and REPEAT sampling is what makes that render. `bpy.ops.object.bake` writes
    only inside 0..1, so those faces bake to NOTHING and then sample wrapped,
    pulling content from the far side of the sheet. That is the torn vertical
    band down the spine.
  * **Overlap in wrapped space.** Normal faces reach u = 0.0000 and pushed ones
    start at 1.0000, so under REPEAT they address the same texels. No texture
    can satisfy both.
  * **The poles.** Every column converges to a point at the crown and the
    floor, so texel density collapses there and detail smears. That is the
    mangled crown, and no bake fixes it -- it is the unwrap.

WHAT IT COSTS TO LEAVE. Only three skins in a catalogue of 135 wear a texture
pack -- `leopard`, `tiger` and `bullion`. The first two are regenerable. The
third is the metal band overlay, which is constant-along-u BY DESIGN and cannot
survive arbitrary islands; it needs re-authoring as a bake. `pig_uv.py`'s pinned
range stops meaning anything, and `make_fur_tufts.py` copies that unwrap.

GEOMETRY DOES NOT CHANGE. Only UVs. So every landmark cut against this body --
twelve accessory anchors, the vault dial, the coin pile, the hatch -- is
untouched, and `Config.PIGGY_MESH`'s offsets and sizes stay exactly as they are.
What changes is the mesh's asset id.

THE TWO GROUPS ARE PACKED SEPARATELY, WHICH IS THE ONE THING THAT WOULD GO
WRONG QUIETLY. The body ships as its own MeshPart and the trim as another, so
they get their own textures -- and each therefore needs its own full 0..1
square. Unwrapping the four trim parts one at a time gives each of them the
WHOLE square and they land on top of each other; unwrapping them together in
multi-object edit mode packs them into one square as four island groups, which
is what a single trim sheet needs.
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
import bpy, os, sys, math


D = os.path.dirname(os.path.abspath(__file__))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SRC = arg("--blend", paths.PARTS)
OUT = arg("--out", paths.pig("pig_uv2.blend"))
# ISLAND MARGIN, WHICH IS THE GAP BETWEEN PACKED PIECES. Too tight and bilinear
# filtering samples across from a neighbouring island, which shows as a wrong
# colour bleeding along an edge -- the forum advice is 0.01 to 0.05 and this is
# the middle of it. The bake's own margin then bleeds each island OUTWARD into
# that gap, so the two numbers work together rather than against each other.
MARGIN = float(arg("--margin", "0.02"))
ANGLE = float(arg("--angle", "66"))

BODY = ["Body"]
TRIM = ["Snout", "Ears", "Legs", "Tail"]

def unwrap(names, label, angle=None, margin=None):
    obs = [bpy.data.objects[n] for n in names if n in bpy.data.objects]
    if not obs:
        print("  ! nothing to unwrap for %s" % label)
        return
    bpy.ops.object.select_all(action='DESELECT')
    for ob in obs:
        ob.hide_viewport = False
        ob.hide_set(False)
        ob.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    angle = ANGLE if angle is None else angle
    margin = MARGIN if margin is None else margin
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle),
                             island_margin=margin)
    # AVERAGE THE ISLAND SCALES BEFORE PACKING, or a big island and a small one
    # get the same share of the sheet and the small part ends up with far more
    # texels per stud than the large one. That is the same anisotropy the
    # cylinder had, arriving by a different route.
    bpy.ops.uv.select_all(action='SELECT')
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(margin=margin)
    bpy.ops.object.mode_set(mode='OBJECT')

    lo = hi = None
    tot = 0
    for ob in obs:
        uvl = ob.data.uv_layers.active.data
        for i in range(len(uvl)):
            u, v = uvl[i].uv
            lo = (u, v) if lo is None else (min(lo[0], u), min(lo[1], v))
            hi = (u, v) if hi is None else (max(hi[0], u), max(hi[1], v))
        tot += len(ob.data.polygons)
    print("  %-5s %-28s u %.4f..%.4f  v %.4f..%.4f  %d faces"
          % (label, ", ".join(o.name for o in obs), lo[0], hi[0], lo[1], hi[1], tot))
    if hi[0] > 1.0001 or hi[1] > 1.0001 or lo[0] < -0.0001 or lo[1] < -0.0001:
        print("    ! UVs still leave the 0..1 square -- a bake would lose them")
    else:
        print("    every UV inside 0..1, so nothing bakes off the edge")


def reunwrap_all(angle=None, margin=None):
    """Both groups, packed separately -- the whole point of the exercise."""
    print("")
    print("=== SMART UV PROJECT  (angle %g, margin %g) ==="
          % (ANGLE if angle is None else angle, MARGIN if margin is None else margin))
    unwrap(BODY, "body", angle, margin)
    unwrap(TRIM, "trim", angle, margin)


if __name__ == "__main__":
    bpy.ops.wm.open_mainfile(filepath=paths.find(SRC, "blend"))
    reunwrap_all()
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
    print("saved %s -- nothing else was touched" % OUT)
