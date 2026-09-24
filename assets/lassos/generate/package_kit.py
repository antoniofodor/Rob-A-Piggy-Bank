"""Bundle the validated production kit, excluding alternates and logs."""
from pathlib import Path
import zipfile
import json
import hashlib

ROOT = Path(__file__).resolve().parents[1]
validation = json.loads((ROOT/'validation.json').read_text())
for key in ('coil','loop','snapped-end','daze-star'):
    assert validation[key]['fbx_round_trip'] == 'passed'
assert validation['tier_geometry_and_uvs']['identical']
folders = ['coil','tiers','textures','loop','snapped-end','daze-star','generate','rope','preview']
files = [ROOT/'README.md',ROOT/'validation.json']
for folder in folders:
    files += [p for p in (ROOT/folder).rglob('*') if p.is_file()
              and p.suffix not in ('.blend1','.pyc') and '__pycache__' not in p.parts]
archive = ROOT/'lasso-kit.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for path in sorted(files):
        z.write(path,'lasso-kit/'+path.relative_to(ROOT).as_posix())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
receipt = {'archive':archive.name,'files':len(files),'bytes':archive.stat().st_size,
           'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),
           'excluded':['alternates/','build logs','Blender backups','Python caches']}
(ROOT/'package.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2))
