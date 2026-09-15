# -*- coding: utf-8 -*-
"""Author the METALLIC BAND overlay -- one image, every metal skin.

    python make_band_overlay.py

WHAT THIS IS, AND WHY IT IS ONE FILE RATHER THAN ONE PER SKIN.
`SurfaceAppearance.AlphaMode.Overlay` composites this map over the part's own
`Color3` using THIS MAP'S ALPHA. So the map carries the BANDING and the skin
carries the COLOUR: gold, silver, chrome, copper, rose gold and anything
somebody types a colour for, from a single upload. Authoring a texture per
metal would have been a texture per metal forever.

WHY BANDS AT ALL. Every swatch in the reference palettes is a banded gradient
-- light band, dark band, light band -- and that banding is the whole of what
reads as polished metal. A Roblox part has ONE `Color3`, so it can hold a
gradient across its own curvature and can never band. This is the only way to
put one on it.

WHY IT VARIES WITH HEIGHT AND IS CONSTANT AROUND THE ANIMAL. The physical
story is a horizontally striped environment -- bright sky, dark ground, a
bright horizon -- reflected in a turned cylinder, which is exactly what those
swatches are pictures of. Two things fall out of it for free:

  * THE U SEAM CANNOT SHOW. A cylindrical unwrap smears the faces that cross
    the back of the animal, and normally that is the thing you fix. A pattern
    that does not vary along U has nothing to smear.
  * THE IMAGE CAN BE NARROW. Every row is identical, so the width is only
    there to survive mip generation and block compression.

WHITE FOR HIGHLIGHTS AND BLACK FOR SHADOWS, NEVER A TINTED GOLD. Overlay
LERPS toward the map's own colour, so a gold-tinted map would drag every skin
toward gold and silver would come out brassy -- which would put us straight
back to one texture per metal. White and black move a colour along its own
value axis and leave its hue alone.

THE ALPHA IS DELIBERATELY WELL UNDER 1. At alpha 1 the band IS the map's
colour, so a highlight would be pure white and a shadow pure black, and the
skin underneath would stop existing exactly where the pattern is loudest.
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
W, H = 64, 512          # constant along U, so the width is only mip headroom

# THE SHADOWS CARRY THIS, NOT THE HIGHLIGHTS, AND THAT IS A MEASUREMENT
# RATHER THAN A TASTE CALL. The first build ran highlights to 0.49 alpha and
# was rendered on gold and on silver: silver was right and GOLD CAME OUT
# WASHED OUT AND CHROME-ISH. Overlay lerps toward the map's own RGB, and the
# map has to be neutral or it would tint every metal (a warm map makes silver
# brassy -- the exact thing one shared file exists to avoid). So a white band
# does not brighten a colour, it DESATURATES it, and on a metal, base colour
# is reflectance tint, so desaturating is the move toward chrome.
#
# Black is the half that costs nothing: darkening moves a colour down its own
# value axis and leaves the hue exactly alone. So the bands are mostly SHADOW,
# and the bright half is left to the surface's own specular -- which is real,
# moves with the camera, and is already there.
HI_STRENGTH = 0.34
LO_STRENGTH = 0.62

# AND 0.55 WAS TOO FAR IN THE OTHER DIRECTION -- rendered matte, the way the
# engine actually shades a packed skin, it came out as a pale striped beach
# ball. White desaturates whatever it lands on, so a highlight can be NARROW
# or it can be STRONG and not both. The glints stay narrow and come down to
# 0.34; the darks go UP to 0.62, because black moves a colour down its own
# value axis and costs it no saturation at all. Contrast is a ratio, so a
# deeper floor buys the same "shiny" as a brighter ceiling and keeps the gold.

# AND THE SECOND TUNE WENT THE OTHER WAY, BECAUSE THE SURFACE TURNED OUT TO
# HAVE NO SHINE OF ITS OWN TO LEAVE IT TO. The first retune dropped highlights
# to 0.17 and left the bright half "to the real specular, which is real, moves
# with the camera and is already there". Measured in game, it is not there at
# all: a part wearing a SurfaceAppearance IGNORES `EnvironmentSpecularScale`
# -- 0.08 and 1.00 produce a pixel-identical frame -- and a roughness ladder
# from 0.05 to 1.00 across the whole animal barely moves it either. There is
# no environment to reflect and no dial that reaches it.
#
# So every bit of shine on a packed skin has to be PAINTED HERE, and the
# highlights come back up. What stops that washing the colour out, which is
# what 0.49 did on the first attempt, is that they are NARROW now rather than
# broad: a glint over a few per cent of the height reads as a specular streak,
# where the same alpha spread over a third of the animal reads as chrome.
SHARPNESS = 3.5

# V = 0 is the BOTTOM of the pig and V = 1 the top -- the unwrap normalises
# world Z over the union of both meshes, so these positions are heights on the
# animal rather than positions on a sheet.
#
# Positive is toward white, negative toward black. The shape is a reflected
# room: dark ground under the belly, a bright horizon sheen where the flank
# turns, a dark mid, the main highlight high on the body, and sky at the top.
STOPS = [
    (0.00, -0.85),   # under the belly, deep -- the darks do the contrast now
    (0.14, -0.55),
    (0.22, +0.20),
    (0.26, +1.00),   # narrow glint where the lower flank turns away
    (0.30, +0.20),
    (0.40, -0.70),   # a deep band, so the two glints have something to be
    (0.52, -0.20),   # brighter THAN -- contrast is a ratio, not a level
    (0.60, +0.55),
    (0.66, +1.00),   # the main streak, high on the body
    (0.72, +0.45),
    (0.82, -0.30),
    (0.90, +0.35),
    (1.00, +0.75),   # the top catching the sky
]


def smoothstep(t):
    t = min(1.0, max(0.0, (t - 0.5) * SHARPNESS + 0.5))
    return t * t * (3.0 - 2.0 * t)


def value_at(v):
    if v <= STOPS[0][0]:
        return STOPS[0][1]
    if v >= STOPS[-1][0]:
        return STOPS[-1][1]
    for i in range(len(STOPS) - 1):
        a, b = STOPS[i], STOPS[i + 1]
        if a[0] <= v <= b[0]:
            t = (v - a[0]) / (b[0] - a[0]) if b[0] > a[0] else 0.0
            return a[1] + (b[1] - a[1]) * smoothstep(t)
    return 0.0


def png(path, rows, width, height):
    """Write 8-bit RGBA. Bytes are written EXACTLY as computed.

    Deliberately not routed through an image library or through Blender's own
    save: a ColorMap is read as sRGB, so what is wanted here is for the numbers
    chosen to BE the numbers stored. This file already records a roughness of
    0.30 coming back as 0.58 after one unintended colour-space round trip.
    """
    raw = b"".join(b"\x00" + bytes(r) for r in rows)
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def main():
    os.makedirs(OUT, exist_ok=True)
    rows = []
    # row 0 is the TOP of a PNG, and V = 1 is the top of the pig
    for y in range(H):
        v = 1.0 - (y + 0.5) / H
        val = value_at(v)
        if val >= 0:
            rgb = (255, 255, 255)
            a = int(round(val * HI_STRENGTH * 255))
        else:
            rgb = (0, 0, 0)
            a = int(round(-val * LO_STRENGTH * 255))
        px = bytes((rgb[0], rgb[1], rgb[2], max(0, min(255, a))))
        rows.append(px * W)
    path = os.path.join(OUT, "pig_metal_bands.png")
    png(path, rows, W, H)

    print("")
    print("=== METALLIC BAND OVERLAY ===")
    print("  %s" % path)
    print("  %dx%d RGBA, %d bytes" % (W, H, os.path.getsize(path)))
    print("  highlight alpha peaks at %.2f, shadow alpha at %.2f"
          % (max(s[1] for s in STOPS) * HI_STRENGTH,
             -min(s[1] for s in STOPS) * LO_STRENGTH))
    print("")
    print("  height   value    what it is")
    for v, val in STOPS:
        kind = "white %.2f alpha" % (val * HI_STRENGTH) if val >= 0 \
            else "black %.2f alpha" % (-val * LO_STRENGTH)
        print("   %.2f   %+0.2f    %s" % (v, val, kind))


main()
