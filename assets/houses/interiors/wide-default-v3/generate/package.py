"""Build previews, validate the three defaults and bundle their editable sources."""
import json
import math
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET
import zipfile

root = Path(__file__).resolve().parents[1]
repo = root.parents[3]
mapping = json.loads((repo/'default.project.json').read_text())['tree']['ServerStorage']
counts = {'treehouse':628,'cardboard-fort':622,'beehive-cottage':648}
names = {'treehouse':'TreehouseInteriorKit','cardboard-fort':'CardboardFortInteriorKit','beehive-cottage':'BeehiveCottageInteriorKit'}
results={}
for theme, count in counts.items():
    folder=root/theme
    native=folder/(theme+'-interior-kit.rbxmx')
    assert (repo/mapping[names[theme]]['$path']).resolve()==native.resolve()
    spec=json.loads((folder/'geometry.json').read_text())
    report=json.loads((folder/'studio-checks.json').read_text(encoding='utf-8-sig'))
    assert report['passed'] and report['count']==count
    assert spec['roomLength']==40 and spec['clearWidth']==60 and spec['ceilingHeight']==32
    original=json.loads((root/'generate/inputs'/(theme+'.json')).read_text())
    assert spec['templates']['Pedestal']==original['templates']['Pedestal'], 'Gameplay props must remain unchanged'
    for template in spec['templates'].values():
        for part in template['parts']:
            assert all(math.isfinite(v) and v>0 for v in part['size'])
            r=part['rotation']
            for i in range(3):
                for j in range(3):
                    assert abs(sum(r[k*3+i]*r[k*3+j] for k in range(3))-(i==j))<1e-6
    for path in folder.glob('*.rbxmx'):
        ET.parse(path)
    subprocess.run(['rojo','build',str(folder/'preview.project.json'),'-o',str(folder/(theme+'-interior-preview.rbxlx'))],check=True)
    ET.parse(folder/(theme+'-interior-preview.rbxlx'))
    for path in [folder/'preview/hall.png',folder/(theme+'-interior.blend')]+[folder/'exports'/(name+'.fbx') for name in spec['templates']]:
        assert path.stat().st_size>1000,path
    results[theme]={'passed':True,'engineChecks':count,'pedestalsUnchanged':True,'mappedAsDefault':True}
integration=json.loads((root/'integration-checks.json').read_text(encoding='utf-8-sig'))
assert integration['passed'] and integration['count']==20
(root/'package-checks.json').write_text(json.dumps(results,indent=2))
dest=root/'wide-default-interiors-v3.zip'
with zipfile.ZipFile(dest,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for path in sorted(root.rglob('*')):
        if not path.is_file() or path.suffix in ('.zip','.pyc') or '__pycache__' in path.parts or re.search(r'\.blend\d+$',path.name):
            continue
        archive.write(path,path.relative_to(root))
with zipfile.ZipFile(dest) as archive:
    assert archive.testzip() is None
    print(json.dumps({'files':len(archive.namelist()),'bytes':dest.stat().st_size,'engineChecks':sum(counts.values())+20}))
