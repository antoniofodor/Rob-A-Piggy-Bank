# -*- coding: utf-8 -*-
"""CLOSED-BACK PASS: `look/check_fade.py`'s own check, on the re-baked sheets.

    python make/closedback_fade.py bee tiger ...      (system python, needs Pillow like check_fade)

`check_fade.main` reads a skin's sheets out of `assets/piggies/<tier>/<skin>/sheets/`;
this pass wrote its body sheets to `renders/closed-back-test/full/<skin>/`,
so the same `measure` is run there with the same pooled palette (new body +
shipped trim, exactly as `main` pools body + trim) and, beside it, on the
SHIPPED body sheet for a like-for-like line -- which since the 2026-09-22
move is the `.open-hatch.png` beside the current one, because the current
`<skin>_body_color.png` IS this pass's re-bake. Nothing here is a second implementation: `_palette`,
`measure`, `FLOOR`, `NEAR`, `ERODE` and `FAIL` are all check_fade's.
"""
import os as _os, sys as _sys
_root = _os.path.dirname(_os.path.abspath(__file__))
while not _os.path.exists(_os.path.join(_root, "paths.py")):
    _up = _os.path.dirname(_root)
    if _up == _root:
        raise RuntimeError("cannot find paths.py above %s" % __file__)
    _root = _up
if _root not in _sys.path:
    _sys.path.insert(0, _root)
_sys.path.insert(0, _os.path.join(_root, "look"))

import paths                      # noqa: E402
import check_fade as cf           # noqa: E402
import numpy as np                # noqa: E402
from PIL import Image             # noqa: E402

FULL = _os.path.join(paths.RENDERS, "closed-back-test", "full")


def load(p):
    return np.asarray(Image.open(p).convert("RGB"), dtype=np.int16).reshape(-1, 1, 3)


skins = [a for a in _sys.argv[1:] if not a.startswith("-")]
print("")
print("  skin              sheet                 colours  off-palette %  IN A FADE %")
bad = []
for skin in skins:
    new_body = _os.path.join(FULL, skin, "%s_body_color.png" % skin)
    old_body = paths.skin_open_hatch_map(skin, "body")
    if not _os.path.exists(old_body):
        old_body = paths.skin_map(skin, "body")
    trim = paths.skin_map(skin, "trim")
    if not _os.path.exists(new_body):
        print("  %-16s  -- no re-baked body sheet --" % skin)
        continue
    for label, body in (("shipped body", old_body), ("RE-BAKED body", new_body)):
        if not _os.path.exists(body):
            print("  %-16s  %-20s  -- missing --" % (skin, label))
            continue
        pool = [load(body)] + ([load(trim)] if _os.path.exists(trim) else [])
        pal = cf._palette(np.concatenate(pool, axis=0))
        off, fade, ncol = cf.measure(body, pal)
        flag = "" if fade <= cf.FAIL else "   <-- FADING"
        if flag and label.startswith("RE"):
            bad.append(skin)
        print("  %-16s  %-20s %7d %13.2f %13.2f%s" % (skin, label, ncol, off, fade, flag))
print("")
print("  %d re-baked sheet(s) fading: %s" % (len(bad), ", ".join(bad)) if bad else "  nothing re-baked fades.")
