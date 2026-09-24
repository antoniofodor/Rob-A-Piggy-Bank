"""Validate the delivered comparison and create its portable archive."""
import json
import math
import re
import zipfile
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
spec = json.loads((root/'geometry.json').read_text())
tests = json.loads((root/'studio-checks.json').read_text(encoding='utf-8-sig'))
assert tests['passed'] and tests['count'] == 96
checks = []
def check(ok, message):
    assert ok, message
    checks.append(message)
for name, template in spec['templates'].items():
    for part in template['parts']:
        check(all(x > 0 and math.isfinite(x) for x in part['size']), name+' positive finite sizes')
        r = part['rotation']
        columns = [[r[i*3+j] for i in range(3)] for j in range(3)]
        for i in range(3):
            for j in range(3):
                assert abs(sum(a*b for a,b in zip(columns[i],columns[j]))-(1 if i==j else 0)) < 1e-6
check(spec['templates']['RoomShell']['mounts']['Exit']['position'] == [0,0,-38], '38-stud repeat')
ped = spec['templates']['Pedestal']
check(ped['mounts']['Piggy']['position'][1] == 1.69, 'Piggy mounting height retained')
plate = next(p for p in ped['parts'] if p['name']=='CollectionPlate')
check(plate['size'] == [2.8,.34,1.05], 'Removable button size retained')
check(15.5-abs(plate['position'][2])-plate['size'][2]/2 >= 10, 'At least 20 studs clear between buttons')
check(len([k for k in spec['templates']['RoomShell']['mounts'] if k.startswith('Slot_')]) == 6, 'Six slots')
for path in root.glob('*.rbxm*'):
    ET.parse(path)
for path in root.glob('*.rbxlx'):
    ET.parse(path)
for name in ['hall.png','original-hall.png','achievement-alcove.png','layout-cutaway.png','pedestal.png']:
    assert (root/'preview'/name).stat().st_size > 1000
assert (root/'treehouse-interior.blend').stat().st_size > 1000
assert len(list((root/'exports').glob('*.fbx'))) == 4
(root/'geometry-checks.json').write_text(json.dumps({'passed':True,'partChecks':len(checks),'notes':checks[-5:], 'studioVisual':'Temporary client scene inspected with a six-stud block avatar; scene cleaned up afterward.'},indent=2))
dest = root/'treehouse-spacious-comparison-v2.zip'
with zipfile.ZipFile(dest,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for path in sorted(root.rglob('*')):
        if not path.is_file() or path.suffix in ('.zip','.pyc') or '__pycache__' in path.parts or re.search(r'\.blend\d+$',path.name):
            continue
        archive.write(path,path.relative_to(root))
with zipfile.ZipFile(dest) as archive:
    assert archive.testzip() is None
    print(json.dumps({'archive':str(dest),'files':len(archive.namelist()),'bytes':dest.stat().st_size,'studioChecks':tests['count']}))
