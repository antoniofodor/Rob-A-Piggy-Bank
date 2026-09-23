#!/usr/bin/env bash
# CLOSED-BACK PASS, ON DISK ONLY. For every skin named on the command line:
#   assets/piggies/<k>/source/<k>.blend  --copy-->  full/<k>/<k>_open.blend
#                        --fill-->  full/<k>/<k>_closed.blend
#                        --bake-->  full/<k>/<k>_body_color.png   (body only; trim is untouched)
#                        --render-> full/<k>/<k>_hatch.png, <k>_hero.png
# Nothing under assets/piggies/, pig/, src/ or assets/skins/ is written.
# Everything lands in renders/closed-back-test/full/, with a log beside it.
# Per-skin paths are asked of paths.py rather than spelled here, so this
# script survived the 2026-09-22 move with one line changed.
set -u
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
cd "$(dirname "$0")/.." || exit 1
PIG="$(pwd -W)"
FULL="$PIG/renders/closed-back-test/full"
LOG="$FULL/log.txt"
mkdir -p "$FULL"
echo "=== closed-back pass $(date) ===" >> "$LOG"
for k in "$@"; do
  d="$FULL/$k"
  mkdir -p "$d"
  echo "--- $k" | tee -a "$LOG"
  blend="$(python -c "import paths,sys; print(paths.skin_blend(sys.argv[1]))" "$k")"
  trimpng="$(python -c "import paths,sys; print(paths.skin_map(sys.argv[1], 'trim'))" "$k")"
  if [ ! -f "$blend" ]; then
    echo "  ! no $blend -- skipped" | tee -a "$LOG"; continue
  fi
  cp -p "$blend" "$d/${k}_open.blend"
  "$B" --background --python make/closedback_fill.py -- --in "$d/${k}_open.blend" --out "$d/${k}_closed.blend" \
      2>&1 | grep "restored quads\|boundary\|faces 3090\|Error\|Traceback\|AssertionError\|!" | tee -a "$LOG"
  if [ ! -f "$d/${k}_closed.blend" ]; then
    echo "  ! fill FAILED for $k" | tee -a "$LOG"; continue
  fi
  "$B" --background --python make/closedback_bake.py -- --blend "$d/${k}_closed.blend" --out "$d" --name "$k" \
      2>&1 | grep "baking\|wrote\|BAKE DONE\|Error\|Traceback\|!" | tee -a "$LOG"
  if [ ! -f "$d/${k}_body_color.png" ]; then
    echo "  ! bake FAILED for $k" | tee -a "$LOG"; continue
  fi
  trim=""
  if [ -f "$trimpng" ]; then trim="--trim-tex $trimpng"; fi
  "$B" --background --python make/closedback_render.py -- --blend "$d/${k}_closed.blend" --out "$d" --tag "$k" \
      --views hatch,hero --body-tex "$d/${k}_body_color.png" $trim \
      2>&1 | grep "rendered\|Error\|Traceback" | tee -a "$LOG"
done
echo "=== done $(date) ===" | tee -a "$LOG"
