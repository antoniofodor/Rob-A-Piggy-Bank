# -*- coding: utf-8 -*-
"""What the FEATHER TIPS look like once the engine is animating them.

    python assets/piggies/phoenix/generate/preview_anim.py

THE ORDINARY LOOP CANNOT SHOW THIS, WHICH WOULD OTHERWISE MEAN THE ONLY WAY TO
LOOK AT A LEGENDARY IS TO PUBLISH IT. `make_view_blend.py` renders RGB and
knows nothing about alpha, so the animated half of the skin is invisible in
every render it makes -- and an upload publishes under the developer's own
account and is moderated, which `CLAUDE.md` records the real cost of. So the
composite is done by hand instead: `lerp(part.Color, map.RGB, map.Alpha)` is
four lines of Pillow, and rendering it at several points round a cycle is a
real 3D preview of what the engine will draw.

`ClientMain.skinColourAt` is the reference for the arithmetic. This previews
the `flicker` kind, which is what a firebird wants and what this skin should
be wired with:

    a = sin(clock*speed + seed*5)
    b = sin(clock*speed*2.7 + seed*11)
    t = clamp((a + b)/2 * 0.5 + 0.5, 0, 1)
    colour = palette[1]:Lerp(palette[2], t*t)

`t*t` is the half worth knowing before picking a palette: it BIASES THE CYCLE
TOWARD palette[1], so the first colour is where the tips spend most of their
time and the second is a peak they only touch. That is exactly right for
embers and it means palette[1] has to be a colour the coat looks good in ALL
DAY, not a trough to be got through.

Destructive in between on purpose, and it puts the real sheets back: the
preview reads `paths.skin_map`, so the only way to show it something else is
to BE something else for a moment. The restore is a copy rather than a re-bake
so nothing can come back subtly different.
"""
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..")))
import paths                                        # noqa: E402
from PIL import Image                               # noqa: E402

B = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
HERE = paths.HERE
SKIN = "phoenix"

# THE PALETTE THIS SKIN SHOULD SHIP WITH. Deep ember to white-hot, in the
# order `flicker` reads them -- see the header on `t*t`.
EMBER = (255, 138, 34)
HOT = (255, 246, 216)
# WHERE ROUND THE CYCLE TO LOOK. `t*t` in the engine, so these are the SQUARED
# values a real cycle actually spends its time at rather than an even sweep:
# the trough, two ordinary moments and the peak.
STOPS = (0.00, 0.18, 0.55, 1.00)

# WHICH VIEWS. The hero for the shape and the crown and spine for the read,
# which is `WORKFLOW.md`'s rule about where a skin is actually judged.
SHOTS = ("hero", "crown", "low")


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


orig = {g: paths.skin_map(SKIN, g) for g in ("body", "trim")}
keep = {g: p + ".keep" for g, p in orig.items()}
for g, p in orig.items():
    if not os.path.exists(p):
        raise SystemExit("  ! no %s sheet. Bake first." % g)
    shutil.copy(p, keep[g])

frames = []
try:
    for t in STOPS:
        c = lerp(EMBER, HOT, t)
        tint = Image.new("RGB", (1024, 1024), c)
        for grp in ("body", "trim"):
            im = Image.open(keep[grp]).convert("RGBA")
            a = im.getchannel("A")
            Image.composite(im.convert("RGB"), tint, a).save(orig[grp])
        subprocess.run([B, "--background", "--python",
                        os.path.join(HERE, "make", "make_view_blend.py"),
                        "--", "--skin", SKIN, "--render"],
                       cwd=HERE, stdout=subprocess.DEVNULL)
        row = []
        for name in SHOTS:
            src = paths.render("view_%s_%s.png" % (SKIN, name))
            dst = paths.render("anim_%s_%s_t%02d.png" % (SKIN, name,
                                                         int(t * 100)))
            shutil.copy(src, dst)
            row.append(dst)
        frames.append((c, row))
        print("  t %.2f  tip %s rendered" % (t, c), flush=True)
finally:
    for g, p in orig.items():
        shutil.copy(keep[g], p)
        os.remove(keep[g])
    print("  real sheets restored")

# ONE CONTACT SHEET, because the point of this is the DIFFERENCE between the
# stops and four separate files make that a memory test.
W = 260
sheet = Image.new("RGB", (W * len(SHOTS), W * len(frames)), (24, 24, 24))
for r, (_c, row) in enumerate(frames):
    for k, f in enumerate(row):
        sheet.paste(Image.open(f).resize((W, W), Image.LANCZOS), (k * W, r * W))
out = paths.render("%s_tip_cycle.png" % SKIN)
sheet.save(out)
print("  wrote %s -- rows are the cycle, columns are the view"
      % os.path.relpath(out, HERE))
