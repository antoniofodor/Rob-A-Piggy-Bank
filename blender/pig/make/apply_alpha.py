# -*- coding: utf-8 -*-
"""Merge a baked alpha mask into a skin's colour sheet.

    python make/apply_alpha.py --skin magma
    python make/apply_alpha.py --skin magma --undo

Run after `bake_skin.py` and `bake_alpha.py`. See `bake_alpha.py`'s header for
what alpha MEANS here -- the short version is that it is the only per-texel
channel a `SurfaceAppearance` gives you, and it decides whether a texel shows
the baked picture or the part's own live `Color3`.

IT IS PLAIN PYTHON AND NOT BLENDER, WHICH IS THE POINT RATHER THAN A
CONVENIENCE. The colour sheet is finished, correct, and has been through
Blender's colour management once already. Loading it back in to add a channel
means a second sRGB round trip on data that is not a picture -- and this
project has the receipt for that mistake: `bake_skin.py`'s own header records
a hand-applied transfer function reporting a true (232, 157, 12) as
(248, 208, 64), which shipped a marking at 18% strength over an entire sheet
and was reported as a rendering artefact.

Pillow puts a channel into a PNG and touches nothing else. Verified below by
comparing the RGB before and after, because "touches nothing else" is exactly
the sort of claim that is worth one assertion.

THE ORDER MATTERS AND IS THE ONE THING TO REMEMBER: `bake_skin.py` writes the
sheet opaque every time it runs, so re-baking colour DISCARDS the alpha and
this has to run again. That is not a wart, it is the fallback -- a skin goes
back to static by re-running the colour bake and stopping.
"""

import argparse
import os
import sys

# --- find the toolkit, wherever this script has been filed ------------------
_root = os.path.dirname(os.path.abspath(__file__))
while not os.path.exists(os.path.join(_root, "paths.py")):
    _up = os.path.dirname(_root)
    if _up == _root:
        raise RuntimeError("cannot find paths.py above %s" % __file__)
    _root = _up
if _root not in sys.path:
    sys.path.insert(0, _root)
# ---------------------------------------------------------------------------

import paths   # noqa: E402

try:
    from PIL import Image
except ImportError:
    raise SystemExit(
        "  ! this one needs Pillow and runs in the SYSTEM python, not\n"
        "    Blender's. `python make/apply_alpha.py`, not `blender --python`.")

GROUPS = ("body", "trim")


def alpha_path(skin, group):
    return paths.skin_alpha(skin, group)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--skin", required=True)
    ap.add_argument("--undo", action="store_true",
                    help="force every texel opaque again, which is the "
                         "fallback without a re-bake")
    a = ap.parse_args()

    print("")
    any_done = False
    for grp in GROUPS:
        cpath = paths.skin_map(a.skin, grp)
        if not os.path.exists(cpath):
            print("  %-5s no colour sheet, skipped" % grp)
            continue
        colour = Image.open(cpath)
        rgb = colour.convert("RGB")

        if a.undo:
            mask = Image.new("L", rgb.size, 255)
            what = "forced opaque"
        else:
            apath = alpha_path(a.skin, grp)
            if not os.path.exists(apath):
                print("  %-5s no alpha bake, skipped -- run bake_alpha.py"
                      % grp)
                continue
            mask = Image.open(apath).convert("L")
            # A MISMATCH IS REFUSED RATHER THAN RESIZED. Two sheets that
            # disagree about their size disagree about their UV layout, which
            # means one of them was baked from a different blend -- and a
            # silently stretched mask would put the transparent texels
            # somewhere plausible and wrong.
            if mask.size != rgb.size:
                raise SystemExit(
                    "  ! %s is %s and %s is %s. Same skin, two bakes, two "
                    "sizes -- one of them is stale."
                    % (os.path.basename(apath), mask.size,
                       os.path.basename(cpath), rgb.size))
            import numpy as np
            what = "%.2f%% transparent" % (
                100.0 * (np.asarray(mask) < 128).mean())

        out = rgb.copy()
        out.putalpha(mask)
        out.save(cpath)

        # THE RGB IS PROVED UNTOUCHED rather than asserted. This is the whole
        # reason the pass is separable and therefore the whole reason the
        # fallback is free, so it is worth one comparison.
        import numpy as np
        back = Image.open(cpath).convert("RGB")
        if not np.array_equal(np.asarray(back), np.asarray(rgb)):
            raise SystemExit("  ! the RGB changed. That must never happen.")

        print("  %-5s %s, colour byte-identical" % (grp, what))
        any_done = True

    if any_done:
        print("\n  Re-running bake_skin.py writes these opaque again, which is"
              "\n  the way back.")


if __name__ == "__main__":
    main()
