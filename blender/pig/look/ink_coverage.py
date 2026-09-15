# -*- coding: utf-8 -*-
"""How much of a baked sheet is marking, as a number.

    blender.exe --background --python look/ink_coverage.py -- --skin cow
    blender.exe --background --python look/ink_coverage.py -- --skin cow giraffe

WHY THIS EXISTS. Every skin in this pipeline ends in a threshold, and the dial
in front of that threshold -- the tiger's `width`, the giraffe's `gap`, the
cow's `level` -- decides what fraction of the animal is marked. That fraction
is the one property of a coat that a picture is genuinely bad at: two renders
five points apart can look nothing alike, and two that look alike can be ten
apart, because what the eye actually reads is how CONNECTED the marking is
rather than how much of it there is.

It was written mid-way through the cow, where "there is too much black" and
"the black is all in one lump" turned out to be different complaints wanting
different dials -- and the only way to tell them apart was to measure one of
them and look at the other. The cow's tunables record what that separated.

WHAT IT COUNTS, AND WHY IT IS NOT SIMPLY 'DARK TEXELS'. A baked sheet is mostly
not the animal. Smart UV Project leaves the corners of the square empty, the
image starts life black, and `bake_skin.py` fills 8 texels of margin round each
island and no further -- so about a third of a body sheet was never written by
anything and is pure black. Counting that as marking reports a giraffe as
two-thirds brown.

    unwritten   luminance 0        never touched by a bake
    marking     the dark cluster   whatever the skin's ink is
    coat        the light cluster  the body colour

so the answer is the marking as a fraction of what was WRITTEN, and the two
clusters have to be separated by something better than a guess.

A GUESSED THRESHOLD GOT IT WRONG BY A FACTOR OF SIXTY, WHICH IS THE REASON THIS
FILE PRINTS A HISTOGRAM ON DEMAND. The first version reasoned that the cow's
ink is (34, 32, 38), that Blender linearises an sRGB image on load, and that
the ink would therefore land near 0.016 -- so it classified below 0.10 as ink
and reported 0.41% against a render that was plainly a third black. Asking the
file what was actually in it showed the ink sitting in a clean spike at 0.10 to
0.20, nowhere near the predicted 0.016. The arithmetic about the transfer
function was a reasonable guess and the sheet did not agree with it.

**A HISTOGRAM IS CHEAPER THAN A THEORY ABOUT A COLOUR SPACE.** `--hist` prints
one; the default classification is drawn against what it shows, and the two
clusters are far enough apart that nothing hangs on where between them the line
falls.
"""

# --- find the toolkit, wherever this script has been filed ------------------
# Walks up from this file until it finds the folder holding `paths.py`. Depth
# independent on purpose: a script in `look/` is one level down and a script in
# `skins/cow/` is two, and a hardcoded `..` is a thing that breaks silently the
# first time anything is refiled.
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

import paths   # noqa: E402 -- the one place that knows the layout
import bpy, os, sys   # noqa: E402
import numpy as np   # noqa: E402


argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
HIST = "--hist" in argv
SKINS = [a for a in argv if not a.startswith("--")]
if "--skin" in SKINS:
    SKINS.remove("--skin")
if not SKINS:
    raise SystemExit("usage: -- --skin <name> [<name> ...] [--hist]")

# WHERE THE LINE BETWEEN THE TWO CLUSTERS FALLS. Anything above `WRITTEN` was
# painted by a bake; anything below `SPLIT` is the marking. Both sit in the wide
# empty gap the histogram shows, so neither is a tuned number -- see the header.
WRITTEN = 0.005
SPLIT = 0.50

EDGES = [0.0, 0.001, 0.005, 0.02, 0.05, 0.10, 0.20, 0.40, 0.60, 0.80, 1.01]


def sheet(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    lum = buf.reshape(-1, 4)[:, :3].mean(axis=1)
    bpy.data.images.remove(img)
    return lum, w, h


print("")
for key in SKINS:
    print("=== %s ===" % key)
    for group in ("body", "trim"):
        path = paths.skin_map(key, group)
        if not os.path.exists(path):
            print("  %-5s no sheet -- run bake_skin.py first" % group)
            continue
        lum, w, h = sheet(path)
        written = lum > WRITTEN
        ink = written & (lum < SPLIT)
        n = int(written.sum())
        print("  %-5s %dx%d   %5.2f%% of the sheet written,"
              " %5.2f%% of that is marking"
              % (group, w, h, 100.0 * n / lum.size,
                 100.0 * ink.sum() / max(n, 1)))
        if HIST:
            hist, _ = np.histogram(lum, bins=EDGES)
            for i, c in enumerate(hist):
                print("        %5.3f..%5.3f  %8d  %5.2f%%"
                      % (EDGES[i], EDGES[i + 1], c, 100.0 * c / lum.size))
print("")
print("  MARKING AS A FRACTION OF WHAT WAS WRITTEN, never of the sheet: a")
print("  Smart UV square is about a third empty and the empty part is black.")
