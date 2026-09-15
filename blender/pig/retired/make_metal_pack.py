# -*- coding: utf-8 -*-
"""Author the SHINY METAL skin pack's maps.

    "/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" \
        --background --python make_metal_pack.py

RETIRED. THIS PACK WAS BUILT, UPLOADED, WORN AND MEASURED AS WORSE THAN NOT
USING IT AT ALL, and the script is kept only so nobody rebuilds it.

Photographed at one camera under shipped lighting with the pack as the only
variable: with it, the gold pig is a flat wash; without it, on stock
`Enum.Material.Metal`, it has real tonal range and a sheen. The stock material
won, and `Config.SURFACE_PACKS` is empty as a result.

THE REASONING BELOW IS THE PART THAT WAS WRONG, so it is left standing rather
than deleted. "Smooth means no detail, so the maps should be uniform" is true
about surfaces and self-defeating in THIS renderer:
`Lighting.EnvironmentSpecularScale` is 0.08 -- pulled back on purpose, because
a bright specular on SmoothPlastic reads as plastic rather than as painted --
so there is almost no environment to reflect, and a perfectly uniform metal has
nothing left to vary. What makes `Material.Metal` read as metal here is the
tonal variation it carries for free, and this pack replaced exactly that with a
flat number.

THE PARAGRAPH THAT USED TO SIT HERE WAS WRONG TWICE AND IS CORRECTED RATHER
THAN DELETED. It read: "Neither obvious lever was the constraint either: part
`Reflectance` at 1.00 barely moved the picture, and `EnvironmentSpecularScale`
at 1.00 barely moved it."

BOTH READINGS WERE TAKEN THROUGH THE PACK. The probe printed its own state as
it aimed -- `colour=(241,164,50), pack=on` -- and a SurfaceAppearance overrides
the material response AND `Reflectance`, so two levers were declared dead while
being measured on a part that was ignoring them. Re-run on a bare pig with
SURFACE_PACKS empty, `EnvironmentSpecularScale` 0.08 -> 1.00 is a large, obvious
change on stock `Material.Metal`: a broad sheen across the flank, rims on the
ears, a deeper gold.

AND THE WRITE-UP WIDENED A MEASUREMENT THAT WAS TAKEN CORRECTLY, which is the
worse of the two. At `Reflectance` 0.50 the note made at the time reads "a real
but modest difference -- a distinct specular streak on the flank now"; that
became "barely moved the picture" one paragraph later. The number was right and
the sentence was not. Same failure this project already records against
`screen_capture` and against the crack's dead marker: the loss happens in the
step from number to prose, not in the measurement.

WHAT SURVIVES, and it is the useful half: the global is still not the lever to
reach for, because 0.22 (the value that shipped before the lighting pass) buys
gold very little while specular is the dial that puts a white plastic sheen
back on every flat-shaded surface in the game. Small gain, whole-world cost.
The fix that shipped is per-skin: a darker base colour plus a `reflectance`
field on the metal rows. See `Config.SKINS.bullion`.

WHAT A PACK IS ACTUALLY FOR, then: whatever a stock `Material` cannot do --
speckle, crazing, glitter, spots, hammering. Patterns with real variation,
which are also the only things that need the UV unwrap. Anything competing
with a stock material has to BEAT it, and this one was measured losing.

--------------------------------------------------------------------------
WHY THESE MAPS ARE UNIFORM, WHICH LOOKS LIKE LAZINESS AND IS THE BRIEF.
"Smooth shiny metal" is a statement about how light behaves, not about
surface detail: metalness says treat the colour as a reflection rather than a
pigment, roughness says how tightly to focus it, and detail is precisely what
a SMOOTH surface does not have. So there is nothing to draw, and every pixel
of these three maps is the same pixel.

That has a consequence worth stating plainly rather than letting it look like
the UVs were wasted: A UNIFORM MAP SAMPLES THE SAME VALUE AT EVERY UV, SO THIS
PACK DOES NOT ACTUALLY NEED THE UNWRAP. The unwrap is for the packs after this
one -- speckle, crazing, hammered, glitter -- which cannot exist without it,
and which would have cost two more mesh uploads to add later.

IT IS ALSO WHY THIS PACK CANNOT SEAM. An island boundary shows when the
pattern either side of it disagrees; with one value everywhere there is
nothing to disagree. So the riskiest thing about an automatic unwrap is not
being spent here.

WHAT MAKES IT A PACK RATHER THAN A SKIN. `AlphaMode.Overlay` composites the
ColorMap over the part's own `Color` using the ColorMap's ALPHA -- so a map
that is transparent everywhere hands the tint entirely to `Color3`. One upload
of these three images is then gold, chrome, copper and rose gold, and any
other metal somebody types a colour for, with no new art at all.

NON-COLOUR DATA, WHICH IS THE ONE TRAP IN WRITING THEM. Metalness and
roughness are NUMBERS that happen to be stored in an image, not pictures.
Blender writes a PNG through the view transform unless it is told otherwise,
so a roughness of 0.30 saved as though it were a photograph comes back as
roughness 0.58 -- and nothing would error, the metal would simply be duller
than it was designed to be. Every map here is written with the colourspace
forced to Non-Color and `save_render` bypassed.
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

import bpy
import os


OUT = paths.skin_dir("metal")

# ---------------------------------------------------------------- the numbers
SIZE = 128          # a uniform map needs no resolution; this is the floor that
                    # survives mip generation and block compression cleanly

METALNESS = 1.000   # fully metal. Anything under 1 is a metal-painted plastic,
                    # which is a different and much duller-looking material.

ROUGHNESS = 0.300   # CHOSEN BY LOOKING, from a four-step ladder rendered on
                    # this pig in gold. 0.10 mirrors the key light as a
                    # hard-edged rectangle on the flank and reads as chrome in
                    # a studio; 0.45 spreads the highlight until the gold goes
                    # chalky and pastel. 0.30 keeps a soft broad highlight AND
                    # saturated colour, which is what cartoon metal is.
                    #
                    # It is a starting point rather than a final answer: Cycles
                    # and Roblox are different renderers and the game adds a
                    # bloom at threshold 1.7 over a 2.4 sun. This is one 128px
                    # image and re-uploading it is the cheapest change in the
                    # whole pipeline.


def solid(name, rgba, colourspace, alpha):
    """A flat image, written as DATA rather than as a picture."""
    img = bpy.data.images.new(name, width=SIZE, height=SIZE, alpha=alpha,
                              float_buffer=False)
    img.generated_color = rgba
    img.colorspace_settings.name = colourspace
    img.alpha_mode = 'CHANNEL_PACKED' if alpha else 'NONE'
    img.filepath_raw = os.path.join(OUT, name)
    img.file_format = 'PNG'
    # save() rather than save_render(): save_render pushes the buffer through
    # the scene's view transform, which is exactly the sRGB round trip these
    # maps must not take.
    img.save()
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    scene = bpy.context.scene
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '8'

    made = []

    # 1. METALNESS -- white, so the whole surface is metal.
    made.append(solid("pig_metal_metalness.png",
                      (METALNESS, METALNESS, METALNESS, 1.0),
                      'Non-Color', alpha=False))

    # 2. ROUGHNESS -- one grey, and the only number in this pack anybody will
    #    want to argue about.
    made.append(solid("pig_metal_roughness.png",
                      (ROUGHNESS, ROUGHNESS, ROUGHNESS, 1.0),
                      'Non-Color', alpha=False))

    # 3. COLOUR -- transparent, so `Color3` is the skin. White underneath
    #    because a viewer that ignores alpha should fall back to something
    #    neutral rather than to black.
    made.append(solid("pig_metal_color.png",
                      (1.0, 1.0, 1.0, 0.0),
                      'sRGB', alpha=True))

    print("")
    print("=== SHINY METAL PACK ===")
    print("metalness %.3f   roughness %.3f   %dx%d" % (METALNESS, ROUGHNESS, SIZE, SIZE))
    for img in made:
        path = img.filepath_raw
        size = os.path.getsize(path) if os.path.exists(path) else -1
        print("  %-28s %6d bytes   colourspace=%s"
              % (os.path.basename(path), size, img.colorspace_settings.name))
    print("")
    print("Upload these three, then the two ids they need go in Config.")


main()
