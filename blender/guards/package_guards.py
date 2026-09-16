"""Package verified native models, interchange files, previews and authoring tools."""
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
import hashlib
import json

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/guards'
validation=json.loads((OUT/'validation.json').read_text())
active={p.parent.name for p in OUT.glob('*/*-report.json')}
assert active and {r['creature'] for r in validation}==active
assert len(validation)==len(active) and all(r['passed'] for r in validation)
for r in validation:
    key=r['creature'];folder=OUT/key
    for name in [key+'.blend',key+'.fbx',key+'.glb',key+'-report.json',key+'-idle.png',key+'-chase.png']+[key+'_'+c+'.fbx' for c in ('Idle','Chase','Attack')]:
        assert (folder/name).is_file(),name
for group in ('dogs','wild','elite'):
    for ext in ('.png','.blend'):assert (OUT/(group+'-lineup'+ext)).is_file()
files=sorted(p for folder in (OUT,ROOT/'blender/guards') for p in folder.rglob('*')
             if p.is_file() and p.suffix in {'.blend','.glb','.fbx','.png','.json','.md','.py'}
             and '__pycache__' not in p.parts and 'edited-exports' not in p.parts)
archive=OUT/'guard-creatures-blender-pack.zip'
with ZipFile(archive,'w',ZIP_DEFLATED) as z:
    manifest=[]
    for p in files:
        rel=p.relative_to(ROOT).as_posix();data=p.read_bytes()
        z.writestr(rel,data);manifest.append(hashlib.sha256(data).hexdigest()+'  '+rel)
    z.writestr('MANIFEST.sha256','\n'.join(manifest)+'\n')
with ZipFile(archive) as z:
    assert z.testzip() is None
    assert sum(n.endswith('.fbx') for n in z.namelist())==4*len(active)
    assert sum(n.endswith('.blend') for n in z.namelist())==len(active)+3
    assert sum(n.endswith('.glb') for n in z.namelist())==len(active)
print('GUARD_PACK_VERIFIED',len(files)+1,'files',round(archive.stat().st_size/1048576,1),'MB',str(archive))
