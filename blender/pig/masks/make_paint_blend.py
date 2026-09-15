# -*- coding: utf-8 -*-
"""Set `pig_paint.blend` up so it opens ready to PAINT a skin's marking masks.

    blender.exe --background --python make_paint_blend.py
    blender.exe --background --python make_paint_blend.py -- --mask spots --skin leopard
    blender.exe --background --python make_paint_blend.py -- --blank both

...then open `pig_paint.blend` and paint. TWO canvases are wired: the BODY's
pattern and the TRIM's, which is how an inner ear gets a different colour from
an outer one.

WHY A SCRIPT RATHER THAN A LIST OF INSTRUCTIONS. Setting a pig up for texture
paint by hand is a dozen clicks across four editors -- two materials, an image
texture node each pointed at the right PNG, the colour spaces, the paint mode,
the seam bleed -- and every one is a chance to end up painting into an image
nothing is reading, which looks exactly like a brush that does not work. None
of it is a decision. It is setup, so it is a script.

WHAT YOU SEE IS THE SKIN, NOT THE MASK. Both materials wear the expression the
engine does -- `AlphaMode.Overlay` is `lerp(partColour, mapRGB, mapAlpha)` --
so a white stroke lands as a black band on a yellow pig, live in the viewport.
Painting the greyscale sheets directly would mean judging a bumblebee by
looking at a black-and-white smear.

TWO SHEETS, BECAUSE A TRIM PART WEARS ONE FLAT COLOUR AND AN EAR NEEDS TWO.
`Config.SKINS.bee.parts` can say the snout is yellow while the ears are black,
and it cannot say the FRONT of an ear is yellow and its back is black -- a
MeshPart has one `Color3`. What can say that is a map. The trim shares the
body's UV cylinder (`pig_uv.py` is what pins it), so a trim sheet is the same
1024 square in the same layout and the inner ear is simply a region of it.

THE TRIM SHEET IS A SECOND UPLOAD AND A SECOND TEMPLATE. `SURFACE_PACKS` rows
carry `trimTemplate`, and both shipped animal packs point theirs at
`animal.model.json`, whose ColorMap is empty -- which is why the trim wears no
pattern today. Painting one of these means a new `.model.json` beside it with
the trim map as its ColorMap.
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


import skin_colours                # noqa: E402
from png_write import INK, png   # noqa: E402


argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


MASK = arg("--mask", "bands")
SKIN = arg("--skin", "bee")
BLANK = arg("--blank", "")
SRC = paths.RAW
OUT = paths.pig("pig_paint.blend")
MASKS = os.path.join(paths.skin_dir("animal"), "masks")
TRIM_MASK = arg("--trim", "trim_" + SKIN)

BODY_RGB, TRIM_RGB = skin_colours.skin(SKIN)
INK_RGB = tuple(c / 255.0 for c in INK)

# THE TRIM SHEET'S CONSTANT RGB DEFAULTS TO THE BODY COLOUR, because what it is
# nearly always asked to do is put the animal's own colour on the inside of an
# ear or across a muzzle -- the bee's yellow face against black ears is exactly
# that. `--trim-rgb 236,120,150` for a pink one.
_tr = arg("--trim-rgb", "")
TRIM_INK = tuple(int(v) / 255.0 for v in _tr.split(",")) if _tr else BODY_RGB

SIZE = 1024
BODY_PATH = os.path.join(MASKS, MASK + ".png")
TRIM_PATH = os.path.join(MASKS, TRIM_MASK + ".png")


def png_black(path, size=SIZE):
    """A blank sheet: black everywhere, which is NO MARKING.

    Written with the project's own PNG writer rather than Pillow, because this
    runs inside Blender and Pillow is not part of that bundle.
    """
    row = bytes((0, 0, 0, 255)) * size
    png(path, [row] * size, size, size, True)


if not os.path.exists(BODY_PATH):
    raise RuntimeError("no mask at %s -- masks/ holds one per marking TYPE"
                       % BODY_PATH)
if not os.path.exists(TRIM_PATH):
    png_black(TRIM_PATH)
    print("  created a blank %s" % os.path.relpath(TRIM_PATH, D))

# ---------------------------------------------------------------- --blank
# ERASING IS A BACKUP AND THEN A FILL, NEVER A FILL. A mask has no generator
# behind it -- that is the whole reason `.gitignore` un-ignores this folder --
# so a blank written straight over one is the only unrecoverable thing in this
# pipeline. The copy costs a megabyte and removes the class.
if BLANK:
    import shutil
    targets = {"body": [BODY_PATH], "trim": [TRIM_PATH],
               "both": [BODY_PATH, TRIM_PATH]}.get(BLANK)
    if targets is None:
        raise RuntimeError("--blank takes body, trim or both (got %r)" % BLANK)
    for t in targets:
        if os.path.exists(t):
            bak = t[:-4] + ".before-blank.png"
            shutil.copy2(t, bak)
            print("  backed up %s -> %s"
                  % (os.path.relpath(t, D), os.path.basename(bak)))
        png_black(t)
        print("  blanked %s" % os.path.relpath(t, D))

bpy.ops.wm.open_mainfile(filepath=SRC)
scene = bpy.context.scene

# THE SPLIT PARTS GO. `pig.blend` carries the joined `Trim` AND the same
# geometry cut into Snout/Ears/Legs/Tail, in the same space -- so an untouched
# viewport is two coincident surfaces flickering through each other, and a
# brush stroke lands on whichever the depth buffer handed you. That is not a
# scene anybody can paint in. `Config.PIGGY_TRIM_PARTS` has an empty id on all
# four anyway, so the joined trim is what ships today.
for n in ("Snout", "Ears", "Legs", "Tail"):
    o = bpy.data.objects.get(n)
    if o:
        bpy.data.objects.remove(o, do_unlink=True)

body = bpy.data.objects["Body"]
trim = bpy.data.objects["Trim"]

body_img = bpy.data.images.load(BODY_PATH, check_existing=False)
trim_img = bpy.data.images.load(TRIM_PATH, check_existing=False)

body.data.materials.clear()
body.data.materials.append(
    skin_colours.overlay_material(bpy, "bodyskin", BODY_RGB, INK_RGB, body_img))
trim.data.materials.clear()
trim.data.materials.append(
    skin_colours.overlay_material(bpy, "trimskin", TRIM_RGB, TRIM_INK, trim_img))

# THE EYE AND NOSTRIL PREVIEWS STAY AND STAY UNSELECTABLE. They are where the
# face is, which is what a person needs while deciding where a band starts --
# and a reference you can grab by accident is worse than none. The shipped
# bands map already puts 477 texels of marking inside an eye patch, which is
# the kind of thing you only avoid if you can see the eyes while you work.
for n in ("EyePreview", "NostrilPreview"):
    o = bpy.data.objects.get(n)
    if o:
        o.hide_select = True
        o.hide_render = True

w = bpy.data.worlds.new("w")
scene.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.60, 0.68, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.8

# EEVEE, BECAUSE THIS FILE IS ORBITED RATHER THAN RENDERED. Cycles re-renders
# on every mouse move, which makes painting unusable.
scene.render.engine = 'BLENDER_EEVEE'
scene.view_settings.view_transform = 'Standard'

# ---------------------------------------------------------------- the brush
# `MATERIAL` MODE RATHER THAN `IMAGE`, AND THE SECOND SHEET IS WHY. `IMAGE`
# mode paints into ONE named canvas whatever is selected -- so selecting the
# trim and painting would write those strokes into the BODY's sheet, at the
# trim's UV coordinates, silently. In `MATERIAL` mode the canvas follows the
# object's own active image texture node, which `overlay_material` sets, so
# clicking an ear paints the ear's sheet with nothing to remember.
ts = scene.tool_settings.image_paint
ts.mode = 'MATERIAL'
# SEAM BLEED, BECAUSE THE PIG IS A CYLINDER WITH A CUT DOWN IT. A stroke that
# crosses that seam stops dead at the island edge without this, leaving a
# hairline of bare skin down the animal that is invisible while painting and
# obvious on the finished model.
ts.seam_bleed = 4
ts.use_normal_falloff = True

# X-SYMMETRY ON, BECAUSE AN ANIMAL IS SYMMETRICAL AND A HAND IS NOT. Both ears
# and both flanks take one stroke; painting them one at a time guarantees they
# disagree, which reads as a mistake rather than as character.
if hasattr(ts, "use_symmetry_x"):
    ts.use_symmetry_x = True

# THE BRUSH COLOUR CANNOT BE SET FROM HERE, AND IT IS THE ONE THING LEFT TO DO
# BY HAND. Blender creates the paint brush when a person ENTERS Texture Paint
# in the UI, so in `--background` there is nothing to set: `ts.brush` reads
# None and this is a best-effort that normally does nothing. Verified by
# reopening the saved file rather than assumed.
#
# It matters because white is the MARKING and Blender's default brush is dark,
# so a first stroke on a mostly-black sheet erases something that is not there
# and reads as a brush that does not work.
_br = ts.brush or bpy.data.brushes.get("TexDraw")
if _br:
    _br.color = (1.0, 1.0, 1.0)
    _br.secondary_color = (0.0, 0.0, 0.0)
    _br.strength = 1.0
    _br.blend = 'MIX'
    ts.brush = _br
else:
    print("  note: no brush datablock in a background session -- set the brush"
          " colour to WHITE by hand on first entering Texture Paint")

bpy.context.view_layer.objects.active = body
body.select_set(True)
trim.select_set(True)

for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type != 'VIEW_3D':
            continue
        for space in area.spaces:
            if space.type == 'VIEW_3D':
                space.shading.type = 'MATERIAL'

bpy.ops.wm.save_as_mainfile(filepath=OUT)

print("")
print("=== %s ===" % os.path.basename(OUT))
print("  skin   %s   body %s  trim %s"
      % (SKIN, tuple(round(v * 255) for v in BODY_RGB),
         tuple(round(v * 255) for v in TRIM_RGB)))
print("  Body paints %-22s white lerps toward %s"
      % (os.path.basename(BODY_PATH), tuple(round(v * 255) for v in INK_RGB)))
print("  Trim paints %-22s white lerps toward %s"
      % (os.path.basename(TRIM_PATH), tuple(round(v * 255) for v in TRIM_INK)))
print("")
print("  Click the BODY to paint the body sheet; click the TRIM (ears, snout,")
print("  legs, tail) to paint its own -- the canvas follows the selection.")
print("  WHITE adds marking, BLACK removes it. Alt+S saves the image;")
print("  saving the .blend does NOT.")
