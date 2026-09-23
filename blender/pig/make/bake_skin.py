# -*- coding: utf-8 -*-
"""Bake a hand-built Blender skin down to the two sheets the engine wants.

    blender.exe --background --python bake_skin.py -- --blend pig_parts.blend --skin bee

WHAT THIS IS FOR. A skin authored in Blender is a NODE GRAPH plus a set of
material slots, and none of that crosses to Roblox -- the engine reads images.
This walks the object list, bakes what each material actually renders, and
turns the result into the black-and-white masks the rest of the pipeline
already knows how to ship.

IT BAKES COLOUR AND THEN THRESHOLDS, RATHER THAN ASKING FOR A FACTOR. Asking
the author to wire a greyscale output means understanding their graph, and a
graph is theirs to build however they like -- ramps, slots, mixes, all of it.
Baking the rendered COLOUR works whatever is in there, and every skin in this
catalogue is two-tone by construction: `Overlay` is
`lerp(partColour, mapRGB, mapAlpha)`, so a part can only ever show its own
colour or the map's. Two colours in, one threshold out.

TWO SHEETS, NOT ONE, EVEN THOUGH THEY SHARE A UV LAYOUT. The body and the trim
are separate MeshParts in the game with separate `Color3`s, so they need
separate maps -- and because they share the cylinder, baking them into one
image would have the snout's marking overwrite whatever the flank had there.
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
import bpy, os, sys

from png_write import png   # noqa: E402


argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SKIN = arg("--skin", "bee")
# THE BLEND IS DERIVED FROM THE SKIN, which is what a skin owning a folder
# buys. It used to be a second argument, so `--skin tiger --blend pig_bee.blend`
# was a legal command that baked one animal materials into another sheets.
#
# AND IT IS THE CLOSED-BACK SCENE WHEN THE SKIN HAS ONE. `paths.skin_bake_blend`
# prefers `source/<key>_closed.blend` over `source/<key>.blend`, because the
# current body sheet (designer, 2026-09-22) is the one baked with the vault
# hatch filled, and baking the open scene over it would put the black disc
# back on the rump with nothing to say so. `--blend` still overrides.
BLEND = arg("--blend", paths.skin_bake_blend(SKIN))
# THE DELIVERED SIZE, WHICH IS ROBLOX'S CAP. The bake runs at twice this and is
# scaled down, so the extra resolution is spent entirely on ANTI-ALIASING --
# every delivered texel is the average of four. Baked at 1024 directly, a band
# edge is one hard texel and stair-steps visibly along the coin slot, which is
# exactly how it was first reported.
SIZE = int(arg("--size", "1024"))
SUPER = SIZE * 2

# A SKIN THAT OWNS ITS TEXTURES OWNS A FOLDER -- `assets/piggies/<tier>/<skin>/`,
# with the sheets in its `sheets/` room. The retired `skins/animal/` held
# sheets named by marking TYPE -- spots, stripes, patches -- because one of
# those dressed a leopard, a cheetah and a snow leopard between them, and
# filing it under any one animal would have been a lie about what it is. A
# FULL-COLOUR texture is the opposite: it carries its own colours, so it
# belongs to exactly one skin and nothing else can ever wear it.
OUT = paths.skin_sheets_dir(SKIN)
os.makedirs(OUT, exist_ok=True)

# THE BODY IS ONE PART AND EVERYTHING ELSE IS THE TRIM, which is the game's own
# split rather than a choice made here: `Config.PIGGY_MESH` ships a `Body` and a
# joined `Trim`, and `PIGGY_TRIM_PARTS` can cut that trim into these four.
GROUPS = [("body", ["Body"]),
          ("trim", ["Snout", "Ears", "Legs", "Tail"])]

bpy.ops.wm.open_mainfile(filepath=paths.find(BLEND, "blend"))
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 1          # flat colour: one sample is exact
scene.cycles.bake_type = 'DIFFUSE'
scene.render.bake.use_pass_direct = False
scene.render.bake.use_pass_indirect = False
scene.render.bake.use_pass_color = True
scene.render.bake.use_selected_to_active = False
# MARGIN, BECAUSE BILINEAR FILTERING REACHES OUTSIDE AN ISLAND. Without it a
# texel just off the edge of a UV island is unwritten, and the background
# bleeds into the silhouette on the finished model.
scene.render.bake.margin = 8


def bake_group(name, objects):
    """Every material on every object gets an image node pointing at ONE
    image, because Cycles bakes into each material's ACTIVE image texture node
    -- miss a material and its faces come out blank, which reads as the bake
    half-failing rather than as a setup mistake."""
    img = bpy.data.images.new("bake_" + name, SUPER, SUPER, alpha=True)
    seen = set()
    for ob in objects:
        for slot in ob.data.materials:
            if slot is None or slot.name in seen:
                continue
            seen.add(slot.name)
            nt = slot.node_tree
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image = img
            tex.location = (-600, 600)
            nt.nodes.active = tex          # this is what the bake writes into
    # THE UVs ARE CHECKED BEFORE A SINGLE TEXEL IS BAKED, because a bake
    # against UVs that leave the 0..1 square silently loses those faces --
    # `bpy.ops.object.bake` writes only inside the image, and the mesh then
    # samples them WRAPPED, pulling content from the far side of the sheet.
    #
    # That is not hypothetical: the shipped cylindrical unwrap pushed 43 body
    # faces out to u = 1.500, and the result was a torn vertical band down the
    # spine that looked for all the world like a rendering fault. It cost most
    # of a day. The check is two lines and it names the file, because the way
    # this recurs is baking from a blend that still carries the old unwrap.
    for ob in objects:
        uvl = ob.data.uv_layers.active.data
        bad = sum(1 for i in range(len(uvl))
                  if not (-1e-4 <= uvl[i].uv.x <= 1.0001
                          and -1e-4 <= uvl[i].uv.y <= 1.0001))
        if bad:
            print("  ! %s has %d UV coords outside 0..1 -- those faces will"
                  " bake to NOTHING and sample wrapped. Is %s the re-unwrapped"
                  " file?" % (ob.name, bad, BLEND), flush=True)

    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:
        ob.hide_render = False
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    print("  baking %-5s from %s (%d material%s)"
          % (name, ", ".join(o.name for o in objects), len(seen),
             "" if len(seen) == 1 else "s"), flush=True)
    bpy.ops.object.bake(type='DIFFUSE')

    img.scale(SIZE, SIZE)
    # ALPHA 255 EVERYWHERE, WHICH IS WHAT MAKES A FULL-COLOUR MAP WORK UNDER
    # `AlphaMode.Overlay`. The engine computes lerp(partColour, mapRGB,
    # mapAlpha), so at alpha 1 the map REPLACES the part's colour outright --
    # which is the whole point of a full-colour sheet. Leave the bake's own
    # alpha in and every texel outside a UV island is transparent, so the
    # margin stops doing its job at exactly the seams it exists for.
    #
    # `foreach_get` into a numpy buffer rather than a Python loop: this is four
    # million floats and the list version takes longer than the bake did.
    import numpy as np
    buf = np.empty(SIZE * SIZE * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    buf[3::4] = 1.0
    img.pixels.foreach_set(buf)
    return img


# THE COLOUR ANALYSIS DELIBERATELY DOES NOT LIVE HERE. Blender's bundled Python
# has no Pillow, and the first version imported it at module scope and took the
# whole bake down with `ModuleNotFoundError` -- after the bake had already been
# proved to work, which is the worst time to break a script.
#
# It also belongs outside for a better reason: the exact colours have to be
# counted off the SAVED PNG rather than off `img.pixels`. Those are linear
# floats needing a transfer function, and applying it by hand reported a true
# (232, 157, 12) as (248, 208, 64). That is not cosmetic -- the converter
# PROJECTS every texel onto the line between the two colours, so a base that is
# off by a little leaves the whole base a little way along it. Measured: 18% of
# the way, which lands as a marking at 18% strength over the entire sheet. The
# pig came out with muddy yellows and soft ear rims and was reported as a
# RENDERING artefact, because that is exactly what it looks like.


# ---------------------------------------------------------------- the driver
results = {}
for name, wanted in GROUPS:
    obs = [bpy.data.objects[n] for n in wanted if n in bpy.data.objects]
    if not obs:
        print("  ! no objects for %s, skipped" % name)
        continue
    img = bake_group(name, obs)
    img.filepath_raw = paths.skin_map(SKIN, name)
    img.file_format = 'PNG'
    img.save()
    results[name] = img
    print("  wrote %s" % os.path.basename(img.filepath_raw), flush=True)
print("BAKE DONE")
