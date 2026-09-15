# -*- coding: utf-8 -*-
"""More angles than `make/make_view_blend.py --render` gives, plus the strip.

    python skins/stormwolf/look_stormwolf.py

WHY IT EXISTS. The four shipped shots are hero, crown, spine and low, and the
SPINE one looks at the rump from behind and above -- which is the SHADED side,
because the game's sun sits at azimuth 74.8 west of south and therefore lights
the front-right of the animal. So a rump rendered there comes back near-black
whatever colour it is, and the first two builds of this skin were retuned on
the strength of that: the saddle looked like it covered the whole rear when a
colour histogram of the baked sheet said the coat was a third of it.

**A SHOT THAT IS DARK IS NOT EVIDENCE THAT A MARKING IS DARK.** These add a
LIT rear quarter, a flat side and a head-on face, which is where the wolf half
of this skin is actually decided.

AND THE STRIP IS THE POINT OF THE WHOLE EXERCISE. A skin is read from about
twelve studs across a lawn, where a 700-pixel render is roughly 175. Anything
that only works at 700 does not work.

It opens the view scene `make_view_blend.py` already wrote rather than
building its own, so the lighting is that file's and cannot drift from it.
"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..")))
import paths   # noqa: E402

B = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
HERE = os.path.dirname(os.path.abspath(__file__))
SKIN = "stormwolf"

INNER = r'''
import bpy, sys
from mathutils import Vector
out = sys.argv[sys.argv.index("--") + 1]
cam = bpy.data.objects["View"]
sc = bpy.context.scene
SHOTS = (("lit",   (3.6, 3.0, 2.4),  (0, 0.30, 0.15)),
         ("side",  (-5.8, 0.1, 1.3), (0, 0.00, 0.10)),
         ("face",  (-0.6, -6.0, 1.3), (0, -0.30, 0.25)),
         ("above", (-1.0, 0.6, 5.6), (0, 0.10, 0.30)))
for name, loc, aim in SHOTS:
    cam.location = Vector(loc)
    cam.rotation_euler = (Vector(aim) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = out % name
    bpy.ops.render.render(write_still=True)
    print("  rendered %s" % name, flush=True)
'''

inner = os.path.join(HERE, "_look_inner.py")
open(inner, "w").write(INNER)
try:
    subprocess.run([B, "--background", paths.skin_view(SKIN),
                    "--python", inner, "--",
                    paths.render("view_%s_%%s.png" % SKIN)],
                   cwd=paths.HERE, stdout=subprocess.DEVNULL)
finally:
    os.remove(inner)

# ---- the twelve-stud strip -------------------------------------------------
from PIL import Image   # noqa: E402

NAMES = ("hero", "low", "face", "side", "lit", "crown", "spine", "above")
tiles = []
for n in NAMES:
    p = paths.render("view_%s_%s.png" % (SKIN, n))
    if os.path.exists(p):
        tiles.append(Image.open(p).convert("RGB").resize((175, 175),
                                                         Image.LANCZOS))
strip = Image.new("RGB", (175 * len(tiles), 175))
for i, t in enumerate(tiles):
    strip.paste(t, (175 * i, 0))
strip.save(paths.render("%s_strip.png" % SKIN))
print("  strip: %d tiles at 175px -- %s"
      % (len(tiles), os.path.basename(paths.render("%s_strip.png" % SKIN))))
