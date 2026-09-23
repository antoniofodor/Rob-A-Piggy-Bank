# -*- coding: utf-8 -*-
"""A skin's colours, READ OUT OF `Config.luau` RATHER THAN COPIED.

WHY THIS IS A FILE. Two preview scripts carried their own `rgb(...)` pairs, and
measured against the shipped catalogue two of the eight had drifted: the bee's
body was still (247, 178, 24) against a Config that moved to (236, 160, 12)
after the note beside it decided a lemon was not a honey, and the zebra's trim
was (24, 22, 24) against (36, 34, 38). So the sheet used to JUDGE a pattern was
showing colours the game does not ship -- which is the one thing a colour
preview may not do, and it is invisible, because a slightly wrong yellow looks
exactly like a yellow.

Same shape this project keeps paying for: the road width that drifted between
two files, the ride-key grammar that broke within the hour of being copied,
`SUNK` read by two halves of one shop. `pig_uv.py` exists for this reason one
level down; this is the same argument about the catalogue instead of the sheet.

IT PARSES RATHER THAN IMPORTS, because Luau is not Python and there is nothing
to import. That is ugly and it cannot silently drift: a renamed field raises
here rather than rendering the wrong pig.
"""

import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG = os.path.join(HERE, "..", "..", "src", "ReplicatedStorage", "Shared",
                      "Config.luau")

# THIS PATTERN CONSTRAINS `Config.luau` AND NOTHING IN `Config.luau` KNOWS IT,
# which is worth a warning rather than a comment. Nine skin scripts come
# through here, so a row edited the wrong way stops nine bakes dead.
#
# THE RULE IS "NOTHING BUT WHITESPACE BETWEEN `body` AND `trim`", NOT
# "ADJACENT". `\s*` matches newlines and tabs, so splitting the pair across two
# lines is perfectly safe and somebody wrapping a long row for width has broken
# nothing. What kills it is a FIELD inserted between them -- a `surface`, an
# `aura`, anything with a non-whitespace token in it. Put a new field AFTER
# `trim` and this never notices.
#
# Stated as "adjacent" first, which reads as "same line" and would have sent
# the next person looking for a bug they had not written. Verified against the
# live row both ways before writing it down.
#
# It fails LOUDLY -- `RuntimeError("no body/trim pair under Config.SKINS.<key>")`
# -- which is the good direction, and it is still a failure whose cause is
# nowhere near the person who caused it.
_RGB = re.compile(r"body = Color3\.fromRGB\((\d+), (\d+), (\d+)\),\s*"
                  r"trim = Color3\.fromRGB\((\d+), (\d+), (\d+)\)")


def skin(key):
    """(body, trim) as 0..1 sRGB triples, for the skin named `key`."""
    src = open(CONFIG, encoding="utf-8").read()
    # FROM `Config.SKINS` ONWARD, not from the top of the file. A key at one
    # tab is not unique to the skins table: `Config.SURFACE_PACKS.lion` is a
    # one-line row that sits four thousand lines ABOVE `Config.SKINS.lion`,
    # and searching the whole file found it first and reported "no body/trim
    # pair" against the wrong table.
    start = src.find("\nConfig.SKINS = {")
    i = src.find("\n\t%s = {" % key, start if start >= 0 else 0)
    if i < 0:
        raise RuntimeError("Config.SKINS has no %r" % key)
    m = _RGB.search(src, i, i + 4000)
    if not m:
        raise RuntimeError("no body/trim pair under Config.SKINS.%s" % key)
    v = [int(x) / 255.0 for x in m.groups()]
    return tuple(v[:3]), tuple(v[3:])


def to_linear(c):
    """BLENDER SHADES IN LINEAR AND `Color3` IS sRGB, so a byte value handed
    straight to a shader renders lighter than the engine draws it. Every
    preview here is a claim about a colour, and this is what makes the claim
    true rather than approximately true.

    IT TAKES 0..1 AND IT USED NOT TO SAY SO, WHICH COST A WHOLE BUILD. Handed
    bytes instead -- `(255, 138, 34)` rather than `(1.0, 0.54, 0.13)` -- it
    raises them through the sRGB curve without complaint and hands back values
    in the HUNDREDS OF THOUSANDS. Nothing errors. What renders is a white pig
    with faint ripples in it, which is indistinguishable from a broken shader,
    and it was found by dumping ColorRamp stops rather than by looking.

    Every skin here divides by 255 inline at the call site, so the moment one
    forgets, this is the failure. The check is one line and it names the fix.
    """
    for x in c:
        if not (-0.001 <= x <= 1.001):
            raise ValueError(
                "to_linear wants 0..1 and got %r. Divide by 255 first -- a "
                "byte handed straight in comes back in the hundreds of "
                "thousands and bakes a white pig with no error anywhere."
                % (c,))
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4
                 for x in c)


# ---------------------------------------------------------------- materials
# ONE OVERLAY MATERIAL, BECAUSE TWO PREVIEWS BUILT IT AND ONE OF THEM WAS
# WRONG. `preview_bee.py` and `make_bee_blend.py` each carried a copy, and both
# drove the mix from the image's ALPHA -- correct for a shipped MAP, where the
# art is in alpha and the RGB is one constant, and exactly wrong for a MASK,
# where the art is in RGB and the alpha is 255 everywhere. Rendered from a
# mask, every bee came out solid black: fac = 1 across the whole sheet.
#
# Which channel carries the marking is a property of the FILE, so it is asked
# of the file rather than passed in by a caller who might be wrong about it.


def overlay_material(bpy, name, base_rgb, ink_rgb, image, from_alpha=None):
    """`AlphaMode.Overlay` as a shader: `lerp(partColour, mapRGB, mapAlpha)`.

    THE PREVIEW HAS TO BE THAT EXPRESSION rather than the texture laid on a
    colour. Plugging the map in as a base colour shows the MAP; mixing two flat
    colours by its marking channel shows the SKIN, which is what the engine
    draws and the only thing worth judging.

    Diffuse rather than Principled on purpose: a packed part gets almost no
    specular, so a glossy preview flatters a pattern that will ship flat.
    """
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    dif = nt.nodes.new("ShaderNodeBsdfDiffuse")
    nt.links.new(dif.outputs[0], out.inputs[0])

    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    # NON-COLOUR, BECAUSE THIS IS A FACTOR AND NOT A PICTURE. Read as sRGB the
    # marking channel is gamma-curved before it is used as a blend weight, so
    # every soft band edge lands in the wrong place -- subtly, which is worse.
    tex.image.colorspace_settings.name = "Non-Color"

    mix = nt.nodes.new("ShaderNodeMixRGB")
    mix.inputs[1].default_value = to_linear(base_rgb) + (1.0,)
    mix.inputs[2].default_value = to_linear(ink_rgb) + (1.0,)
    if from_alpha is None:
        # A MAP carries one constant RGB and all its art in alpha; a MASK is
        # greyscale at full opacity. Measured rather than named by the caller.
        px = list(image.pixels[3:4096 * 4:4])
        from_alpha = max(px) - min(px) > 1e-4 if px else True
    nt.links.new(tex.outputs["Alpha" if from_alpha else "Color"], mix.inputs[0])
    nt.links.new(mix.outputs[0], dif.inputs[0])

    # THE IMAGE NODE IS MADE ACTIVE, WHICH IS WHAT LETS TEXTURE PAINT FIND IT.
    # In `MATERIAL` paint mode Blender paints into the ACTIVE image texture node
    # of whatever object is selected -- so setting it here is what makes
    # selecting the body and selecting the trim paint into two different sheets
    # with nothing for a person to remember. Leave it unset and the brush lands
    # in whichever node Blender picks, which is the silent-wrong-canvas failure
    # `IMAGE` mode was chosen to avoid.
    nt.nodes.active = tex
    return mat
