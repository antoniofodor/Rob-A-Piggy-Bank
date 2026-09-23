"""Build Watermelon from the shared rare-coat builder."""
from pathlib import Path
import runpy,sys
# The toolkit lives in blender/pig/, two levels under the repo root; this stub lives in
# assets/piggies/<key>/generate/, three levels under it. Walk up to the root and step down,
# rather than counting `..`s that break the day anything is refiled.
root=Path(__file__).resolve().parent
while not (root/'paths.py').exists() and not (root/'blender'/'pig'/'paths.py').exists():root=root.parent
if not (root/'paths.py').exists():root=root/'blender'/'pig'
sys.argv=[__file__,'--','--skin','watermelon']
runpy.run_path(str(root/'make/build_rare_coat.py'),run_name='__main__')
