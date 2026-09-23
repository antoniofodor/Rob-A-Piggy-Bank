# -*- coding: utf-8 -*-
"""What the FORKS look like once the engine is flickering them.

    python assets/piggies/stormwolf/generate/preview_anim.py

`docs/animal-crate-plan.md`: the ordinary preview renders RGB and knows
nothing about alpha, so the animated half of a legendary is invisible in the
normal loop -- which would mean the only way to look at it is to publish it,
and every publish is an upload under the developer's own account. This
composites `lerp(part.Color, map.RGB, map.Alpha)` by hand at four points round
a `flicker` cycle, writes each into the skin's own sheets, renders, and PUTS
THE REAL SHEETS BACK.

WHAT `flicker` ACTUALLY DOES, read out of `ClientMain.skinColourAt` rather
than assumed:

    a = sin(clock * speed + seed * 5)
    b = sin(clock * speed * 2.7 + seed * 11)
    t = clamp((a + b) / 2 * 0.5 + 0.5, 0, 1)
    colour = palette[1]:Lerp(palette[2], t * t)

So the colour is always somewhere on the segment palette[1] -> palette[2], and
`t * t` BIASES IT LOW: it sits near palette[1] most of the time and spikes to
palette[2]. That is lightning rather than a pulse, which is why this is the
`anim` kind Storm Wolf wants, and it is why the samples below are spaced on
the SQUARED parameter rather than evenly -- 0.00, 0.16, 0.49, 1.00 is what an
even spread of `t` actually looks like on screen.

AND THE TRIM IS A DIFFERENT COLOUR FROM THE BODY, which no other preview in
this folder has had to model. The animator writes `body.Color = colour` and
`p.Color = colour:Lerp(skin.trim, 0.55)` on every trim part, so a fork running
off the flank onto a leg flickers a little more muted there. Simulated here,
because a preview that showed both the same would be a picture of something
the engine does not draw.
"""
import colorsys   # noqa: F401 -- kept for parity with the other previews
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..")))
import paths   # noqa: E402
from PIL import Image   # noqa: E402

B = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
SKIN = "stormwolf"

# THE PALETTE THIS IS A PICTURE OF, and it is a PROPOSAL rather than a
# reading: there is no `Config.SKINS.stormwolf` row yet, so nothing here can
# be parsed the way `skin_colours.py` parses a body/trim pair. When that row is
# written it should carry exactly these two, in this order.
#
# palette[1] is the fork AT REST -- a dim charged blue, dark enough that a
# resting bolt reads as a scar in the coat rather than as a light left on.
# palette[2] is the STRIKE, and it is the skin's own CORE colour, so the flash
# takes the channel up to the same white-hot the baked hairline down its middle
# already is: for one frame the whole fork is one colour and there is no core
# to see, which is what a strike looks like.
P1 = (46, 70, 120)
P2 = (240, 249, 255)
# `Config.SKINS.stormwolf.trim` will be UNDER. The animator lerps 55% toward
# it on every trim part.
TRIM = (180, 188, 201)
BLEND = 0.55

# EVEN IN `t`, WHICH IS UNEVEN IN WHAT YOU SEE -- see the header.
SAMPLES = (0.00, 0.16, 0.49, 1.00)
VIEWS = ("hero", "low")


def lerp(a, b, u):
    return tuple(int(round(x + (y - x) * u)) for x, y in zip(a, b))


orig = {g: paths.skin_map(SKIN, g) for g in ("body", "trim")}
keep = {g: p + ".keep" for g, p in orig.items()}
for g, p in orig.items():
    shutil.copy(p, keep[g])
try:
    for u in SAMPLES:
        body_c = lerp(P1, P2, u)
        trim_c = lerp(body_c, TRIM, BLEND)
        for grp, tint in (("body", body_c), ("trim", trim_c)):
            im = Image.open(keep[grp]).convert("RGBA")
            a = im.getchannel("A")
            flat = Image.new("RGB", im.size, tint)
            Image.composite(im.convert("RGB"), flat, a).save(orig[grp])
        subprocess.run([B, "--background", "--python",
                        os.path.join(paths.HERE, "make", "make_view_blend.py"),
                        "--", "--skin", SKIN, "--render"],
                       cwd=paths.HERE, stdout=subprocess.DEVNULL)
        for name in VIEWS:
            shutil.copy(paths.render("view_%s_%s.png" % (SKIN, name)),
                        paths.render("anim_%s_%s_u%03d.png"
                                     % (SKIN, name, int(u * 100))))
        print("  t*t = %.2f -> body %s, trim %s" % (u, body_c, trim_c))
finally:
    for g, p in orig.items():
        shutil.copy(keep[g], p)
        os.remove(keep[g])
    print("  real sheets restored")

# ---- one strip per view, so a cycle can be read left to right --------------
for name in VIEWS:
    tiles = [Image.open(paths.render("anim_%s_%s_u%03d.png"
                                     % (SKIN, name, int(u * 100))))
             .convert("RGB").resize((350, 350), Image.LANCZOS)
             for u in SAMPLES]
    strip = Image.new("RGB", (350 * len(tiles), 350))
    for i, t in enumerate(tiles):
        strip.paste(t, (350 * i, 0))
    strip.save(paths.render("anim_%s_%s_cycle.png" % (SKIN, name)))
    print("  wrote anim_%s_%s_cycle.png" % (SKIN, name))
