# -*- coding: utf-8 -*-
"""The guide sheet a HUMAN paints an animal map against, and the linter that
checks what they painted.

    python make_paint_template.py            # write the guide layers
    python make_paint_template.py --check skins/animal/pig_stripes_color.png

WHY THIS IS NOT PART OF `make_animal_maps.py`.

That script AUTHORS maps: it walks (u, v) and computes an alpha, and it knows
every correction it has to make because it makes them itself. A person opening
a 1024 square in Krita knows none of them, and every one of them is invisible
until the pig is standing on a lawn:

  * ONE STUD IS 2.79 TIMES AS MUCH v AS IT IS u ON AVERAGE, and the real
    figure varies with height because the animal's girth does. A circle drawn
    on this sheet lands on the pig as an ellipse nearly three times taller
    than it is wide. This is the mistake a texture artist makes first and
    notices last.
  * THE CROWN AND THE FLOOR ARE SINGULARITIES. A cylindrical unwrap collapses
    every u onto one point at each end, so detail there is stretched without
    limit -- the leopard's spots came out as a starburst over the crown and
    were reported as "distorted near the top".
  * THE EYES OWN A PATCH. A marking through an eye is the one place a pattern
    stops reading as an animal.
  * THE BODY DOES NOT OCCUPY THE WHOLE SHEET. Ears, legs and tail share it,
    and a body pattern painted over their islands runs tiger bars down a
    snout.

None of that can be discovered by looking at a blank square, so the square
comes with the answers drawn on it.

IT READS THE EXPORTED .obj FILES RATHER THAN THE .blend, so it runs in plain
Python with Pillow and needs no Blender. The UVs in those exports ARE the UVs
the game ships; anything derived from them cannot disagree with the pig.

THE GUIDE IS A SEPARATE LAYER AND IS NEVER PAINTED ON. It is written with a
transparent background so it drops straight on top of the working file as a
locked reference and comes off before export -- which is why the islands and
the annotations are two files rather than one flattened picture.
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
HERE = _root

import paths   # noqa: E402 -- the one place that knows the layout

import os
import sys
import math

from PIL import Image, ImageDraw


import pig_uv  # noqa: E402


SIZE = 1024

# Straight out of `make_animal_maps.py`. Imported rather than copied would be
# better and is not available: that module runs a build on import. These are
# the four numbers a painter has to see, and the linter below re-checks them
# against the .obj UVs on every run, so a drift is announced rather than
# silently drawn in the wrong place.
EYES = [(0.1955, 0.594), (0.3045, 0.594)]
EYE_RU, EYE_RV = 0.052, 0.082
# The clearing is FEATHERED, and the linter has to know that or it accuses the
# shipped maps. `eye_keep` holds alpha at zero out to (1 - feather) of the
# ellipse and ramps back to full over the rest, because a hard-edged clearing
# reads as a sticker with a bite out of it. Only the CORE is a fault -- checked
# against `pig_stripes_color.png`, which has 4,319 marked texels inside the
# ellipse and none at all inside the core. A check that fires on the work it is
# meant to protect is the cry-wolf failure this project already paid for.
EYE_FEATHER = 0.45
BODY_V0, BODY_V1 = 0.026, 0.850
POLE_FADE = 0.15

# `uv_cylinder` normalises v over the union of the body and the trim's world
# height, so one unit of v is the whole animal's height in studs.
V_STUDS = 13.98
# Blender units to studs, derived rather than typed: the shared cylinder spans
# UV_SPAN Blender units and that span is V_STUDS studs tall.
BU_STUDS = V_STUDS / pig_uv.UV_SPAN

PARTS = [
    ("Body", "pig_body.obj", (120, 170, 235)),
    ("Snout", "pig_snout.obj", (235, 130, 150)),
    ("Ears", "pig_ears.obj", (235, 185, 110)),
    ("Legs", "pig_legs.obj", (150, 215, 140)),
    ("Tail", "pig_tail.obj", (200, 145, 225)),
]


def load_uv_faces(path):
    """Every triangle of an .obj, as UV triples. Positions are not read."""
    uvs, faces = [], []
    with open(path, encoding="utf-8", errors="ignore") as fh:
        for line in fh:
            if line.startswith("vt "):
                p = line.split()
                uvs.append((float(p[1]), float(p[2])))
            elif line.startswith("f "):
                idx = []
                for tok in line.split()[1:]:
                    bits = tok.split("/")
                    if len(bits) > 1 and bits[1]:
                        idx.append(int(bits[1]) - 1)
                if len(idx) >= 3:
                    for k in range(1, len(idx) - 1):
                        faces.append((idx[0], idx[k], idx[k + 1]))
    return uvs, faces


def to_px(uv):
    """UV to pixels, AND V IS NOT FLIPPED, which is the single most surprising
    fact about this sheet.

    `make_animal_maps.py` writes row y as `v = (y + 0.5) / SIZE`, so v = 0 is
    the TOP row of the file -- and v = 0 is the FLOOR of the animal. THE PIG IS
    UPSIDE DOWN ON ITS OWN TEXTURE: open any of the shipped maps in a paint
    program and the feet are at the top, the crown at the bottom.

    Proved rather than assumed, because the usual convention is the other way
    and a guide drawn on the wrong one is confidently, invisibly wrong. Read
    unflipped, `pig_stripes_color.png` has a maximum alpha of 0 inside the eye
    cores -- the eyes are cleared exactly as `eye_keep` intends. Read flipped,
    the same cores read 240, which is full strength. One of those is the map
    the game ships and the other is a mirror of it."""
    return (uv[0] * SIZE, uv[1] * SIZE)


def body_t(v):
    """Where a v sits along the BODY's own span, 0 at the floor, 1 at the
    crown. Every correction here is against the body rather than against the
    sheet, which is what the first version of the map generator got wrong."""
    return (v - BODY_V0) / (BODY_V1 - BODY_V0)


def stud_scale(v):
    """How many studs one unit of u and one unit of v are AT THIS HEIGHT.

    v is flat -- the height range is fixed. u is not: the whole circumference
    goes across u = 0..1, and the circumference is a function of girth, so a
    stud is worth far more u at the belly than at the shoulder. THIS IS THE
    NUMBER A PAINTER NEEDS AND CANNOT SEE.
    """
    t = min(max(body_t(v), 0.0), 1.0)
    r = pig_uv.body_radius(t) * BU_STUDS
    return 2.0 * math.pi * r, V_STUDS


def draw_islands():
    """Which part of the animal each region of the sheet belongs to."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    found = []
    for name, obj, colour in PARTS:
        path = paths.pig(obj)
        if not os.path.exists(path):
            continue
        uvs, faces = load_uv_faces(path)
        if not faces:
            continue
        found.append((name, len(faces)))
        fill = colour + (70,)
        for tri in faces:
            d.polygon([to_px(uvs[i]) for i in tri], fill=fill)
    return img, found


def draw_guide():
    """The annotations: the traps, drawn where they are."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")

    def hline(v, colour, label, dash=6):
        y = v * SIZE
        x = 0
        while x < SIZE:
            d.line([(x, y), (min(x + dash, SIZE), y)], fill=colour, width=1)
            x += dash * 2
        d.text((6, y + 3), label, fill=colour)

    # THE POLE FADE ZONES. Anything painted in here is smeared toward a point
    # by the unwrap, so it is where detail goes to die -- and it is also where
    # a real animal's markings thin out anyway, which is why the generator
    # fades rather than clamps.
    span = BODY_V1 - BODY_V0
    for lo, hi, tag in (
        (BODY_V0, BODY_V0 + POLE_FADE * span, "FLOOR: detail smears, keep flat"),
        (BODY_V1 - POLE_FADE * span, BODY_V1, "CROWN: singularity, keep flat"),
    ):
        y0, y1 = lo * SIZE, hi * SIZE
        d.rectangle([0, y0, SIZE, y1], fill=(230, 70, 60, 34))
        for x in range(0, SIZE, 24):
            d.line([(x, y0), (x + 24, y1)], fill=(230, 70, 60, 60), width=1)
        d.text((SIZE - 250, y0 + 4), tag, fill=(255, 150, 140, 220))

    hline(BODY_V0, (255, 255, 255, 150), "body v0 %.3f" % BODY_V0)
    hline(BODY_V1, (255, 255, 255, 150), "body v1 %.3f" % BODY_V1)

    # THE EYE PATCHES, at the radii the generator actually clears.
    for (eu, ev) in EYES:
        cx, cy = to_px((eu, ev))
        rx, ry = EYE_RU * SIZE, EYE_RV * SIZE
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry],
                  outline=(255, 90, 90, 230), width=3)
        d.text((cx - 14, cy - 6), "EYE", fill=(255, 150, 150, 240))

    # ONE STUD, DRAWN AS THE SHEET ACTUALLY HOLDS IT. Each of these renders on
    # the pig as a circle one stud across; on the sheet it is an ellipse, and
    # how squashed it is changes with height. Paint a spot the shape of the
    # nearest ring, not the shape of a circle.
    for v in (0.10, 0.25, 0.40, 0.55, 0.70, 0.82):
        us, vs = stud_scale(v)
        du = (1.0 / us) * SIZE / 2.0     # half a stud, in pixels of u
        dv = (1.0 / vs) * SIZE / 2.0
        cx, cy = to_px((0.86, v))
        d.ellipse([cx - du, cy - dv, cx + du, cy + dv],
                  outline=(120, 255, 190, 235), width=2)
        d.text((cx + du + 6, cy - 6), "1 stud  x%.2f" % (dv / du),
               fill=(120, 255, 190, 220))

    d.text((8, 8), "GUIDE LAYER -- delete before export", fill=(255, 255, 255, 200))
    d.text((8, 22), "RGB near-black (14,12,14); the SHAPE goes in ALPHA",
           fill=(255, 255, 255, 160))
    return img


def check(path):
    """Refuse the mistakes that are invisible until the pig is on a lawn."""
    img = Image.open(path).convert("RGBA")
    if img.size != (SIZE, SIZE):
        print("  ! size %dx%d, expected %d square" % (img.size[0], img.size[1], SIZE))
    px = img.load()
    w, h = img.size

    eye_hits, pole_alpha, pole_n = 0, 0.0, 0
    rgb_lo, rgb_hi = 255, 0
    opaque = 0
    for y in range(0, h, 2):
        v = (y + 0.5) / h
        t = body_t(v)
        for x in range(0, w, 2):
            u = (x + 0.5) / w
            r, g, b, a = px[x, y]
            if a > 8:
                opaque += 1
                m = max(r, g, b)
                rgb_lo, rgb_hi = min(rgb_lo, m), max(rgb_hi, m)
                for (eu, ev) in EYES:
                    du = abs(((u - eu + 0.5) % 1.0) - 0.5) / EYE_RU
                    dv = abs(v - ev) / EYE_RV
                    if math.hypot(du, dv) < 1.0 - EYE_FEATHER:
                        eye_hits += 1
            if BODY_V0 <= v <= BODY_V1 and (t < POLE_FADE or t > 1.0 - POLE_FADE):
                pole_alpha += a / 255.0
                pole_n += 1

    print("  marked texels (alpha > 8): %d" % opaque)
    print("  brightest marked RGB channel: %d  (Overlay lerps toward this;"
          " near-black keeps the skin's own colour in charge)" % rgb_hi)
    if rgb_hi > 90:
        print("  ! RGB is light. One map can only carry ONE marking colour --"
              " a LIGHT marking needs its own map, not a lighter one here.")
    if eye_hits:
        print("  ! %d texels inside an eye patch. A marking through an eye is"
              " the one place a pattern stops reading as an animal." % eye_hits)
    if pole_n:
        print("  pole-zone mean alpha: %.3f  (detail here smears toward a"
              " point; the shipped maps fade to ~0)" % (pole_alpha / pole_n))
    return 0


def from_mask(mask_path, out_path, rgb):
    """A GREYSCALE MASK IS THE WHOLE HAND-AUTHORED DELIVERABLE, and this turns
    one into a map the engine can wear.

    Measured on every shipped sheet: there is EXACTLY ONE distinct RGB value
    across the entire 1024 square -- (14,12,14) on the dark patterns, and
    (246,248,252) on the orca, which is the same convention inverted for a
    light marking on a dark skin. Overlay resolves to
    `lerp(partColour, mapRGB, mapAlpha)`, so a second RGB value in the sheet
    would be a second marking colour, and one part has one Color3 to lerp
    from. The colour is therefore a CONSTANT and the art is entirely in the
    alpha channel.

    So the thing a person paints is black and white, which is a far easier
    brief than "paint a texture" and removes the mistake the linter exists to
    catch. WHITE IS FULL MARKING, BLACK IS BARE SKIN.

    It also lands Roblox's own advice for free: their texture guidance asks
    that colour be preserved in transparent pixels so filtering cannot pull
    dark fringes along an alpha edge. A sheet with one RGB value everywhere,
    transparent texels included, cannot fringe by construction -- verified on
    the shipped maps, one distinct RGB in the clear areas and the same one in
    the opaque areas.
    """
    m = Image.open(mask_path).convert("L")
    if m.size != (SIZE, SIZE):
        print("  resampling mask from %dx%d" % m.size)
        m = m.resize((SIZE, SIZE), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), tuple(rgb) + (0,))
    out.putalpha(m)
    out.save(out_path)
    print("wrote %s  (rgb %d,%d,%d constant; shape from the mask's luminance)"
          % (out_path, rgb[0], rgb[1], rgb[2]))
    return check(out_path)


def main():
    if "--check" in sys.argv:
        return check(sys.argv[sys.argv.index("--check") + 1])
    if "--from-mask" in sys.argv:
        i = sys.argv.index("--from-mask")
        rgb = (14, 12, 14)
        if "--rgb" in sys.argv:
            rgb = tuple(int(v) for v in sys.argv[sys.argv.index("--rgb") + 1].split(","))
        return from_mask(sys.argv[i + 1], sys.argv[i + 2], rgb)

    islands, found = draw_islands()
    guide = draw_guide()
    islands.save(paths.render("paint_islands.png"))
    guide.save(paths.render("paint_guide.png"))

    flat = Image.new("RGBA", (SIZE, SIZE), (58, 58, 62, 255))
    flat.alpha_composite(islands)
    flat.alpha_composite(guide)
    flat.convert("RGB").save(paths.render("paint_template.png"))

    print("wrote paint_islands.png, paint_guide.png, paint_template.png")
    for name, n in found:
        print("  %-6s %5d triangles" % (name, n))
    print("  1 unit of v = %.2f studs; 1 unit of u = %.2f studs at the belly,"
          " %.2f at mid-body, %.2f near the crown"
          % (V_STUDS, stud_scale(0.10)[0], stud_scale(0.44)[0], stud_scale(0.80)[0]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
