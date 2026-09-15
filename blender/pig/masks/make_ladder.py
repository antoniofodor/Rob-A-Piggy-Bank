# -*- coding: utf-8 -*-
"""One stepped grey ladder, so a MAP VALUE can be measured instead of guessed.

The pig's UV V runs 0 at the bottom to 1 at the top and is shared across both
meshes, so an image that steps along V dresses the animal in eight different
values at once. Photograph it, read off the band that looks right, and the
value is known rather than chosen.

IT SERVES TWO EXPERIMENTS FROM ONE UPLOAD, which is the whole reason the range
is 0.05 to 1.00 rather than a tight sweep. Used as a ROUGHNESS map it runs
mirror to matte; used as a METALNESS map it runs painted plastic to solid
metal. Both are plain greyscale ramps and Roblox reads them the same way, so
one file answers "how shiny" and "how metal" in two passes and costs one
upload under the developer's own account.

WHY A LADDER AT ALL. `SurfaceAppearance` has no scalar properties -- every
value it takes is an IMAGE -- so trying a roughness of 0.15 normally means
authoring, uploading and moderating a whole asset to find out it was wrong.
A ladder collapses eight of those into one.

NOT FOR SHIPPING. This is an instrument. The final map is a flat image at
whichever value wins.
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

import paths   # noqa: E402 -- the one place that knows the layout
import struct, zlib, os


OUT = paths.skin_dir("metal")
W, H = 64, 512
# top of the pig -> bottom. Spaced closer at the shiny end, because that is
# where the eye can tell two values apart.
STEPS = [1.00, 0.75, 0.55, 0.40, 0.28, 0.18, 0.10, 0.05]


def png(path, rows, width, height):
    raw = b"".join(b"\x00" + bytes(r) for r in rows)
    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


rows = []
band = H // len(STEPS)
for y in range(H):
    v = STEPS[min(len(STEPS) - 1, y // band)]
    g = int(round(v * 255))
    rows.append(bytes((g, g, g)) * W)
path = os.path.join(OUT, "pig_value_ladder.png")
png(path, rows, W, H)

print("=== VALUE LADDER ===")
print("  %s   %dx%d   %d bytes" % (path, W, H, os.path.getsize(path)))
print("")
print("  band  height on the pig      value   as ROUGHNESS      as METALNESS")
for i, v in enumerate(STEPS):
    lo = 1.0 - (i + 1) / len(STEPS)
    hi = 1.0 - i / len(STEPS)
    r = "mirror" if v <= 0.10 else ("shiny" if v <= 0.28 else ("satin" if v <= 0.55 else "matte"))
    m = "solid metal" if v >= 0.75 else ("part metal" if v >= 0.40 else "mostly plastic")
    print("   %d    V %.3f..%.3f  %s   %.2f    %-8s          %s"
          % (i + 1, lo, hi, "(top)" if i == 0 else ("(bottom)" if i == len(STEPS) - 1 else "     "), v, r, m))
