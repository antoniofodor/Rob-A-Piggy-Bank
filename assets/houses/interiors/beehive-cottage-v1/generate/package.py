"""Validate the deliverables and bundle the self-contained Beehive kit."""
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET
import zipfile

root = Path(__file__).resolve().parents[1]
stem = "beehive-cottage-interior"
report = json.loads((root/"studio-checks.json").read_text(encoding="utf-8-sig"))
assert report["passed"] and report["count"] == 116
assert json.loads((root/"geometry-checks.json").read_text())["passed"]
for name in (stem+"-kit.rbxmx", stem+"-review.rbxmx", stem+"-preview.rbxlx"):
    ET.parse(root/name)
for name in (stem+".blend", "exports/RoomShell.fbx", "exports/Pedestal.fbx",
             "exports/RebirthGate.fbx", "exports/AchievementVestibule.fbx",
             "preview/hall.png", "preview/achievement-alcove.png",
             "preview/layout-cutaway.png", "preview/pedestal.png"):
    assert (root/name).stat().st_size > 1000, name
files = [file for file in root.rglob("*") if file.is_file()
         and file.suffix not in (".zip", ".pyc")
         and not re.search(r"\.blend\d+$", file.name)
         and "__pycache__" not in file.parts]
output = root/(stem+"-v1.zip")
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for file in files:
        archive.write(file, Path(stem+"-v1")/file.relative_to(root))
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
print(json.dumps({"package": str(output), "files": len(files),
                  "bytes": output.stat().st_size, "studioChecks": report["count"]}, indent=2))
