# -*- coding: utf-8 -*-
"""Bake a skin's ALPHA mask -- which texels hand themselves back to the game.

    blender.exe --background --python make/bake_alpha.py -- --skin magma
    python make/apply_alpha.py --skin magma

WHAT THIS IS FOR, AND IT IS THE ONLY LEVER THERE IS.

A `SurfaceAppearance` has a ColorMap, a NormalMap, a MetalnessMap and a
RoughnessMap. There is no emissive channel and no "animate this" flag, so
NOTHING IN A TEXTURE CAN SAY "THIS TEXEL BEHAVES DIFFERENTLY" -- except one
thing. `AlphaMode.Overlay` composites the map over the part's own `Color3`:

    final = lerp(part.Color, map.RGB, map.Alpha)

so ALPHA is the per-texel switch that decides who wins. At 255 the baked
picture wins and the texel is static. At 0 the PART'S OWN `Color` wins -- and
`ClientMain`'s skin animator rewrites `body.Color` every Heartbeat.

**SO ALPHA IS HOW A BLENDER FILE TELLS ROBLOX WHICH TEXELS ANIMATE.** Paint it
opaque where you want the bake and transparent where you want the animation,
and the two live on one sheet.

THIS IS NOT A NEW TRICK, IT IS AN OLD ONE POINTED SOMEWHERE ELSE.
`Config.SURFACE_PACKS.bands` already ships on exactly this: one metal band
image whose alpha hands the tint back to the skin, so gold, silver, chrome and
copper come out of a single upload. That one uses it for COLOUR; this uses it
for MOTION. Same mechanism, and the fact that it is already shipping is most
of the reason to trust it.

A MATERIAL SAYS WHAT IT WANTS BY LABELLING A NODE `ALPHA_MASK`, whose first
output is 1 where the map should be OPAQUE and 0 where the part colour should
come through. A material with no such node bakes fully opaque, so a skin that
has never heard of this is unaffected -- which is what lets this be added to a
pipeline with eight finished skins in it and change none of them.

IT IS A SEPARATE PASS AND SEPARATE FILE FROM `bake_skin.py` ON PURPOSE, and
the reason is worth keeping.

  * **THE RGB SHEET IS BYTE-IDENTICAL EITHER WAY.** This never touches colour.
    So the fallback is not a saved copy of anything -- it is simply not
    running this, and a skin that turns out to look worse animated goes back
    by deleting one file. Nothing to keep in step and nothing to restore.
  * The colour bake is the SOURCE OF THE PICTURE and has eight skins depending
    on it. Alpha is optional, new, and wanted by two of them.

WHAT IT DOES NOT DO IS MAKE ANYTHING GLOW. Alpha buys an animated COLOUR, not
emission -- there is no emissive channel to write. What glows is whatever the
`BloomEffect` picks up, which `WorldService` runs at `Threshold = 1.8` and
which operates on the final image after lighting, per pixel, caring nothing
for materials. So a texel handed to an animated colour that swings above that
threshold glows WHILE it is bright, which is a better thing than a constant
glow and is the whole trait the legendary tier is built on. Whether a lit
texture can clear 1.8 at all is UNMEASURED -- see `docs/animal-crate-plan.md`.
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
import bpy, os, sys   # noqa: E402


argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SKIN = arg("--skin", "magma")
BLEND = arg("--blend", paths.skin_blend(SKIN))
# THE SAME TWO NUMBERS `bake_skin.py` USES, and they have to stay the same two:
# the alpha channel is composited onto that sheet texel for texel, so a
# mismatch is not a stretched mask, it is a refusal in `apply_alpha.py`.
SIZE = int(arg("--size", "1024"))
SUPER = SIZE * 2

LABEL = "ALPHA_MASK"

# THE GAME'S OWN SPLIT, not a choice made here -- `Config.PIGGY_MESH` ships a
# `Body` and a joined `Trim`.
GROUPS = [("body", ["Body"]),
          ("trim", ["Snout", "Ears", "Legs", "Tail"])]


def alpha_path(skin, group):
    """Beside the colour sheet and named for it. Deliberately NOT `paths.py`'s
    business yet: this is one pass on trial, and a layout function is a
    promise that something is permanent."""
    return os.path.join(paths.skin_dir(skin),
                        "%s_%s_alpha.png" % (skin, group))


bpy.ops.wm.open_mainfile(filepath=paths.find(BLEND, "blend"))
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 1
# EMIT RATHER THAN DIFFUSE, which is what makes this exact. A diffuse bake
# returns a colour that has been through a shading model; an emission bake
# returns the number that was fed in. The mask is a 0/1 decision and has to
# arrive as one.
scene.cycles.bake_type = 'EMIT'
scene.render.bake.use_selected_to_active = False
scene.render.bake.margin = 8
# NEVER CLEAR. Every bake target here is pre-filled WHITE so that the area
# outside the UV islands means "opaque" rather than "hand this texel to the
# part colour" -- and a clearing bake would throw that away a line before it
# is used. See `bake_group`.
scene.render.bake.use_clear = False


def rewire(mat, force_white):
    """Point this material's output at its ALPHA_MASK -- or at pure white --
    and say whether it had a mask. Destructive to the in-memory material and
    that is fine: this script never saves the blend, so the file on disk is
    untouched and the graph is rebuilt from the skin script anyway."""
    nt = mat.node_tree
    mask = None
    for n in nt.nodes:
        if n.label == LABEL:
            mask = n
            break

    emit = nt.nodes.new("ShaderNodeEmission")
    emit.location = (400, -900)
    emit.inputs['Strength'].default_value = 1.0
    if mask is not None and not force_white:
        # A FLOAT INTO A COLOUR SOCKET IS GREY, which is what a mask wants and
        # is why there is no CombineXYZ here.
        nt.links.new(mask.outputs[0], emit.inputs['Color'])
    else:
        # NO MASK MEANS FULLY OPAQUE, so every skin authored before this
        # existed bakes an alpha of 255 and is unchanged by the pass. A
        # default of 0 would have handed those skins entirely to their part
        # colour and erased eight coats, silently, on one command.
        emit.inputs['Color'].default_value = (1.0, 1.0, 1.0, 1.0)

    out = None
    for n in nt.nodes:
        if n.type == 'OUTPUT_MATERIAL':
            out = n
            break
    if out is None:
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        out.location = (700, -900)
    for lnk in list(out.inputs['Surface'].links):
        nt.links.remove(lnk)
    nt.links.new(emit.outputs['Emission'], out.inputs['Surface'])
    return mask is not None


def bake_pass(name, objects, force_white):
    """One EMIT bake over these objects, returned as a SIZExSIZE float array
    of the red channel."""
    img = bpy.data.images.new("alpha_%s_%d" % (name, force_white),
                              SUPER, SUPER, alpha=True)
    img.colorspace_settings.name = 'Non-Color'
    seen, withmask = set(), 0
    for ob in objects:
        for slot in ob.data.materials:
            if slot is None or slot.name in seen:
                continue
            seen.add(slot.name)
            if rewire(slot, force_white):
                withmask += 1
            nt = slot.node_tree
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image = img
            tex.location = (-600, 600)
            nt.nodes.active = tex

    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:
        ob.hide_render = False
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.bake(type='EMIT')
    img.scale(SIZE, SIZE)

    import numpy as np
    buf = np.empty(SIZE * SIZE * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    out = buf[0::4].copy()
    bpy.data.images.remove(img)
    return out, withmask, len(seen)


def bake_group(name, objects):
    """THE BACKGROUND IS FOUND BY BAKING IT, WHICH IS THE THIRD ATTEMPT AND
    THE ONLY ONE THAT WORKS.

    A bake writes nothing outside a UV island, and zero in THIS map does not
    mean "blank" -- it means "hand this texel to the part's own colour". So an
    unwritten background is TRANSPARENT, and every seam on the animal would
    sample it through the bilinear filter and flash the part colour along the
    edge. It has to be forced opaque, and the whole difficulty is knowing
    which texels those are.

    Two ways of asking Blender failed, and both failed SILENTLY:

      1. Detect them afterwards as "alpha below 0.5". Finds nothing --
         `images.new` hands back an image that is already (0, 0, 0, 1), so the
         test is false everywhere. Measured, 32% of the body sheet stayed
         black: the entire area outside the islands.
      2. Pre-fill the buffer white, either through `generated_color` or
         through `pixels.foreach_set`, with `use_clear` off and then passed
         explicitly to the operator. Measured 37.51% transparent on all three
         variants -- the SAME NUMBER to two decimals, which is what said the
         pre-fill was being discarded rather than mis-measured.

    So the coverage is BAKED instead. A second pass with every material
    emitting pure white marks every texel the bake can reach, background
    included at zero -- and `where(coverage, mask, opaque)` cannot be wrong
    about a texel the first pass never touched, because the second pass did
    not touch it either.

    IDENTICAL NUMBERS ACROSS THREE ATTEMPTS ARE THE EVIDENCE, and that is the
    reusable half: a fix that changes nothing at all is a fix that never ran.
    """
    import numpy as np
    msk, withmask, nmat = bake_pass(name, objects, False)
    cov, _, _ = bake_pass(name, objects, True)

    inside = cov > 0.5
    final = np.where(inside, msk, 1.0).astype(np.float32)

    print("  baking %-5s alpha from %s (%d material%s, %d carrying %s)"
          % (name, ", ".join(o.name for o in objects), nmat,
             "" if nmat == 1 else "s", withmask, LABEL), flush=True)
    print("      %.1f%% of the sheet is island; of THAT,"
          " %.2f%% transparent, %.2f%% opaque, %.2f%% between"
          % (100.0 * inside.mean(),
             100.0 * (final[inside] < 0.02).mean(),
             100.0 * (final[inside] > 0.98).mean(),
             100.0 * ((final[inside] >= 0.02)
                      & (final[inside] <= 0.98)).mean()), flush=True)

    img = bpy.data.images.new("alpha_" + name, SIZE, SIZE, alpha=True)
    img.colorspace_settings.name = 'Non-Color'
    buf = np.empty(SIZE * SIZE * 4, dtype=np.float32)
    buf[0::4] = final
    buf[1::4] = final
    buf[2::4] = final
    buf[3::4] = 1.0
    img.pixels.foreach_set(buf)
    return img


# ---------------------------------------------------------------- the driver
for name, wanted in GROUPS:
    obs = [bpy.data.objects[n] for n in wanted if n in bpy.data.objects]
    if not obs:
        print("  ! no objects for %s, skipped" % name)
        continue
    img = bake_group(name, obs)
    img.filepath_raw = alpha_path(SKIN, name)
    img.file_format = 'PNG'
    img.save()
    print("  wrote %s" % os.path.basename(img.filepath_raw), flush=True)
print("ALPHA BAKE DONE -- now run: python make/apply_alpha.py --skin %s"
      % SKIN)
