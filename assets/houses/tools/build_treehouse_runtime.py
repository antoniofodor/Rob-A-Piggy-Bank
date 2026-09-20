"""Kept as the name that was here; `build_house_runtime.py` is the real one.

    python assets/houses/tools/build_house_runtime.py treehouse 2

One generator serves every house now -- see that file for why. This stays so an
old note or muscle memory still works.
"""
import runpy
import sys
from pathlib import Path

sys.argv = [sys.argv[0], 'treehouse', '2']
runpy.run_path(str(Path(__file__).resolve().parent / 'build_house_runtime.py'),
               run_name='__main__')
