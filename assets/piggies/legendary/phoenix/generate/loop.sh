#!/bin/sh
# The whole authoring cycle for one skin, in one command.
#   sh skins/phoenix/loop.sh            build, bake colour, render
#   sh skins/phoenix/loop.sh --alpha    ...and bake and apply the alpha mask
# Run from `blender/pig/`.
set -e
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" --background --python skins/phoenix/make_phoenix_blend.py 2>&1 | grep -Ev "Deprecation|use_nodes|^$" | tail -14
"$B" --background --python make/bake_skin.py -- --skin phoenix 2>&1 | grep -E "wrote|bak" | tail -6
if [ "$1" = "--alpha" ]; then
  "$B" --background --python make/bake_alpha.py -- --skin phoenix 2>&1 | grep -E "island|wrote|ALPHA" | tail -8
  python make/apply_alpha.py --skin phoenix 2>&1 | tail -6
fi
"$B" --background --python make/make_view_blend.py -- --skin phoenix --render 2>&1 | grep -E "rendered" | tail -5
python look/check_fade.py phoenix
