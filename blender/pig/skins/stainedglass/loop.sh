#!/bin/sh
# The authoring loop for this skin, in one line. Not part of the pipeline --
# it strings together the commands in WORKFLOW.md and the alpha pass from
# `docs/animal-crate-plan.md`. Everything it touches is named after the skin.
#
# THE ORDER IS LOAD-BEARING TWICE OVER.
#
#   * `bake_skin.py` writes the sheet fully opaque every time it runs, so the
#     alpha pass has to come AFTER it or the animated panes are discarded.
#   * `make_view_blend.py` has to come BEFORE it. That script loads the sheet
#     with `bpy.data.images.load` and links its Color output straight into
#     Base Color -- and Blender PREMULTIPLIES a straight-alpha PNG on load, so
#     every texel the alpha pass made transparent renders BLACK. Measured: the
#     baked sheet is byte-identical and still carries (232, 238, 240) under
#     alpha 0, and the preview draws it as holes. That is an artefact of the
#     preview and not a fault in the sheet, and rendering before the merge is
#     the cheapest way not to be fooled by it.
#
# `--rgb` stops before the alpha pass, which is the common case while tuning
# colour and is a bit quicker. `preview_anim.py` is the other half: it shows
# what the ANIMATED panes actually do.
set -e
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
cd "$(dirname "$0")/../.."
"$B" --background --python skins/stainedglass/make_stainedglass_blend.py 2>&1 | grep -E "^  (saved|about)" || true
"$B" --background --python make/bake_skin.py -- --skin stainedglass 2>&1 | grep -E "wrote|! " || true
"$B" --background --python make/make_view_blend.py -- --skin stainedglass --render 2>&1 | grep -E "rendered" || true
python look/check_fade.py stainedglass
if [ "$1" != "--rgb" ]; then
  "$B" --background --python make/bake_alpha.py -- --skin stainedglass 2>&1 | grep -Ei "island|wrote|ALPHA_MASK" || true
  python make/apply_alpha.py --skin stainedglass 2>&1 | grep -E "transparent" || true
fi
