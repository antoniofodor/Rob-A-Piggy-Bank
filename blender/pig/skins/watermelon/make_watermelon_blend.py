"""Build Watermelon from the shared rare-coat builder."""
from pathlib import Path
import runpy,sys
root=Path(__file__).resolve().parents[2]
sys.argv=[__file__,'--','--skin','watermelon']
runpy.run_path(str(root/'make/build_rare_coat.py'),run_name='__main__')
