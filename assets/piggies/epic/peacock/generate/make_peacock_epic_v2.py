"""Rebuild the approved peacock revision through Blender MCP or Blender Python."""
from pathlib import Path
import os
import runpy

root = Path(__file__).resolve()
while not (root / "blender/pig/paths.py").is_file():
    if root == root.parent:
        raise RuntimeError("Cannot locate the piggy toolkit")
    root = root.parent
os.environ["EPIC_KEY"] = "peacock"
runpy.run_path(str(root / "blender/pig/make/build_epic_v2.py"), run_name="__main__")
