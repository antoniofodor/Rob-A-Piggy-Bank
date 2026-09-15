# -*- coding: utf-8 -*-
"""What the CLEAR GLASS looks like once the engine is animating it.
See `docs/animal-crate-plan.md`: the ordinary preview renders RGB and knows
nothing about alpha, so the animated half of a legendary is invisible in the
normal loop -- which would mean the only way to look at it is to publish it.

    python skins/stainedglass/preview_anim.py

Composites `lerp(part.Color, map.RGB, map.Alpha)` by hand at four points round
a `rainbow` cycle -- `ClientMain.skinColourAt` is `Color3.fromHSV(h, 0.72, 1)`
-- writes each into the skin's own sheets, renders, and PUTS THE REAL SHEETS
BACK. Destructive in between on purpose: `make_view_blend.py` reads
`paths.skin_map`, so the only way to show it something else is to be something
else for a moment. The restore is a copy rather than a re-bake so nothing can
come back subtly different.
"""
import os, sys, shutil, subprocess, colorsys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))
import paths
from PIL import Image

B = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
HERE = paths.HERE
HUES = (0.02, 0.30, 0.55, 0.78)

orig = {g: paths.skin_map("stainedglass", g) for g in ("body", "trim")}
keep = {g: p + ".keep" for g, p in orig.items()}
for g, p in orig.items():
    shutil.copy(p, keep[g])
try:
    for h in HUES:
        r, g_, b = colorsys.hsv_to_rgb(h, 0.72, 1.0)
        tint = Image.new("RGB", (1024, 1024),
                         (int(r * 255), int(g_ * 255), int(b * 255)))
        for grp in ("body", "trim"):
            im = Image.open(keep[grp]).convert("RGBA")
            a = im.getchannel("A")
            out = Image.composite(im.convert("RGB"), tint, a)
            out.convert("RGB").save(orig[grp])
        subprocess.run([B, "--background", "--python",
                        os.path.join(HERE, "make", "make_view_blend.py"),
                        "--", "--skin", "stainedglass", "--render"],
                       cwd=HERE, stdout=subprocess.DEVNULL)
        for name in ("hero", "low"):
            src = paths.render("view_stainedglass_%s.png" % name)
            dst = paths.render("anim_stainedglass_%s_h%02d.png"
                               % (name, int(h * 100)))
            shutil.copy(src, dst)
        print("  hue %.2f rendered" % h)
finally:
    for g, p in orig.items():
        shutil.copy(keep[g], p)
        os.remove(keep[g])
    print("  real sheets restored")
