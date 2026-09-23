# -*- coding: utf-8 -*-
# DOES ANY SKIN FADE?
#
# The theme is cartoon, so every texel on a delivered sheet should be one of
# the colours that skin authored -- see `WORKFLOW.md`, "Nothing fades". This
# is the check for it, and it deliberately runs on the BAKED SHEET rather than
# on the script: `hard` at every colour factor is the guarantee, and this is
# the proof, so it has to be able to catch a fade that arrived some other way.
#
# A texel that is not one of the skin's colours is one of two things. An
# ANTI-ALIASED EDGE, which the 2048-to-1024 downscale exists to produce and
# which is a texel or two wide -- wanted, and not a fade. Or a GRADIENT, which
# is broad. Eroding the off-palette mask separates them: an edge does not
# survive a 5x5 erosion and a gradient does.
#
# NOTHING HERE IS TOLD WHAT A SKIN IS MADE OF. The palette is derived from the
# map -- every colour holding at least `FLOOR` of the sheet -- which is what
# makes it a check rather than a second copy of the colour tables that could
# disagree with them. It is also what caught the measurement error the zebra
# pass made: a palette written out by hand omitted the pink inner ear, so the
# pink counted as one enormous fade and the number came back nearly ten times
# too high.

# --- find the toolkit, wherever this script has been filed ------------------
import os as _os, sys as _sys
_root = _os.path.dirname(_os.path.abspath(__file__))
while not _os.path.exists(_os.path.join(_root, "paths.py")):
    _up = _os.path.dirname(_root)
    if _up == _root:
        raise RuntimeError("cannot find paths.py above %s" % __file__)
    _root = _up
if _root not in _sys.path:
    _sys.path.insert(0, _root)

import paths

import numpy as np
from PIL import Image

# A COLOUR HOLDING THIS MUCH OF A SHEET IS AN AUTHORED ONE, AND THE NUMBER IS
# CALIBRATED RATHER THAN CHOSEN -- which it was not, at first, and it cost two
# skins real quality before either of them was looked at.
#
# THE FLOOR IS A CEILING ON HOW MANY COLOURS A SKIN MAY HAVE. A hue that lands
# only on a sliver of ear falls under it, is therefore not in the derived
# palette, and its whole region is reported as a fade -- a false alarm
# indistinguishable from a real one. Two sessions hit it independently on the
# same afternoon: a rainbow tiger was held to SIX hues when ten was the better
# picture, and a stained glass pane measured 0.398% against a floor of 0.400
# and was reported as a 0.30% fade with nothing wrong with the sheet.
#
# CALIBRATED AGAINST KNOWN POSITIVES AND KNOWN NEGATIVES, which is the only
# honest way to set a detector's threshold. The positives are the nine sheets
# that genuinely faded before the "Nothing fades" pass; the negatives are every
# sheet since, plus both new skins.
#
#     floor     real fades caught      false alarms
#     0.0040        9 of 9                  0
#     0.0010        9 of 9                  0        <- here
#     0.0005        8 of 9                  0
#     0.0002        4 of 9                  0
#
# 0.001 is the loosest value that still catches every real fade, and it is four
# times the colour headroom. Below it the detector starts missing the thing it
# is for. A colour worth having is now worth about a tenth of a per cent of a
# sheet -- roughly a thousand texels at 1024.
FLOOR = 0.001
NEAR = 22         # sRGB city-block distance that still counts as that colour
ERODE = 2         # off-palette this far in every direction is a fade, not an edge
FAIL = 0.05       # per cent of a sheet allowed to be in a fade


# THE `colours` COLUMN COUNTS WHAT SURVIVES THE FLOOR, NOT WHAT THE SKIN
# AUTHORED, and the two are not close. The ladybird authors TWO -- red and
# black -- and reports six: the other four are anti-aliased edge tones and bake
# margin holding over a tenth of a per cent. That is benign and it is exactly
# what the number means, but it reads like a fault to anybody who knows the
# skin, so: `IN A FADE` is the column that matters and `colours` is context.
# **AND THE PALETTE IS POOLED ACROSS A SKIN'S TWO SHEETS, WHICH IS A FIX FOR A
# FALSE `FADING` VERDICT RATHER THAN A TIDY-UP.** Derived per sheet, a colour
# that is common on one and RARE on the other falls under the floor on the
# rare one -- and then its own SOLID texels are counted off-palette, survive
# the erosion because they are a solid region rather than an edge, and are
# reported as a fade.
#
# Measured on Storm Stone, which is the skin that found it: the trim sheet was
# flagged at 0.13% and 1,086 of the 1,371 flagged texels were EXACTLY three
# authored colours -- the bolt, its core and the rim round it. That skin's
# lightning covers the body and barely reaches an ear or a leg, so three real
# colours cleared the floor on one sheet and missed it on the other. Nothing
# faded anywhere.
#
# POOLING IS CORRECT BY CONSTRUCTION rather than a threshold that happens to
# work: `bake_skin.py` bakes both sheets from ONE material graph, so the two
# share an authored palette and a colour's evidence is the whole skin rather
# than whichever half it happened to land on.
#
# IT CANNOT MASK A REAL FADE, and that is worth stating because a bigger
# palette sounds like a looser test. A fade is a RAMP between two authored
# colours, so its intermediate tones are in neither sheet's palette and are
# still caught. What pooling removes is exactly one thing: a colour being
# absent from the palette of a sheet it is genuinely painted on.
#
# It is also MONOTONE -- adding colours can only shrink the off-palette set --
# so no skin that read clean can start failing. Verified rather than reasoned:
# all 14 skins re-measured after the change, every `IN A FADE` unmoved.
def _palette(a):
    flat = a.reshape(-1, 3).astype(np.int32)
    key = (flat[:, 0] << 16) | (flat[:, 1] << 8) | flat[:, 2]
    vals, counts = np.unique(key, return_counts=True)
    keep = vals[counts >= FLOOR * len(flat)]
    return np.stack([(keep >> 16) & 255, (keep >> 8) & 255, keep & 255],
                    1).astype(np.int16)


def measure(png, pal=None):
    """(off-palette %, in-a-fade %, how many colours) for one baked sheet.

    `pal` is the skin's pooled palette -- see `_palette`. Left out, the sheet
    supplies its own, which is the old behaviour and is what a caller holding
    a single loose sheet wants.
    """
    a = np.asarray(Image.open(png).convert("RGB"), dtype=np.int16)
    if pal is None:
        pal = _palette(a)
    d = np.abs(a[:, :, None, :].astype(np.int32) - pal[None, None, :, :]).sum(3)
    off = d.min(2) > NEAR
    m = off.copy()
    for dy in range(-ERODE, ERODE + 1):
        for dx in range(-ERODE, ERODE + 1):
            m &= np.roll(np.roll(off, dy, 0), dx, 1)
    n = float(off.size)
    return 100.0 * off.sum() / n, 100.0 * m.sum() / n, len(pal)


def main(skins):
    print("")
    print("  skin         sheet    colours   off-palette %   IN A FADE %")
    bad = []
    for skin in skins:
        # THE PALETTE IS BUILT FROM BOTH SHEETS BEFORE EITHER IS MEASURED --
        # see `_palette`. A skin with only one sheet baked simply pools that
        # one, which is the old behaviour exactly.
        sheets = [(grp, paths.skin_map(skin, grp)) for grp in ("body", "trim")]
        have = [p for _g, p in sheets if _os.path.exists(p)]
        pal = None
        if have:
            pal = _palette(np.concatenate(
                [np.asarray(Image.open(p).convert("RGB"),
                            dtype=np.int16).reshape(-1, 1, 3)
                 for p in have], axis=0))
        for grp, png in sheets:
            if not _os.path.exists(png):
                print("  %-12s %-6s   -- not baked --" % (skin, grp))
                continue
            off, fade, ncol = measure(png, pal)
            flag = "" if fade <= FAIL else "   <-- FADING"
            if flag:
                bad.append("%s %s" % (skin, grp))
            print("  %-12s %-6s %7d %13.2f %13.2f%s"
                  % (skin, grp, ncol, off, fade, flag))
    print("")
    if bad:
        print("  %d sheet(s) fading: %s" % (len(bad), ", ".join(bad)))
        return 1
    print("  nothing fades.")
    return 0


if __name__ == "__main__":
    args = [a for a in _sys.argv[1:] if not a.startswith("-")]
    if not args:
        args = paths.skin_keys(need_body_sheet=True)
    _sys.exit(main(args))
