"""Record inspected local deliverables and their hashes, without uploading anything."""
from pathlib import Path
import hashlib
import json
import re
import shutil

HOME = Path(__file__).resolve().parents[1]
ROOT = HOME.parents[3]
report = json.loads((HOME/'package/muddy-asset-report.json').read_text())
geometry = json.loads((HOME/'generate/geometry-check.json').read_text())
assert geometry['geometryAndUVPreserved']
assert report['fbxRoundTripMaxBoundsError'] < .001
assert all(p['uvPreservedBeforeTriangulation'] and p['sourceNonManifoldEdges'] == 0 for p in report['parts'])
for view in ('hero','front','crown','spine'):
    shutil.copy2(HOME/f'package/muddy-{view}.png',HOME/f'preview/muddy-{view}.png')
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
maps = {}
for group in ('body','trim'):
    path = HOME/f'sheets/muddy_{group}_color.png'
    assert sha(path) == sha(HOME/'package'/path.name)
    maps[group] = {'file':path.relative_to(HOME).as_posix(),'sha256':sha(path),'size':[1024,1024],'uploadedAssetId':None}
config = (ROOT/'src/ReplicatedStorage/Shared/Config.luau').read_text(encoding='utf-8')
start = config.index('\n\tmuddy = {',config.index('\nConfig.SKINS = {'))
row = config[start:config.index('\n\t},',start)+4]
surface = re.search(r'surface\s*=\s*"([^"]+)"',row)
manifest = {
    'key':'muddy','name':'Muddy Piggy','tier':'common','path':HOME.relative_to(ROOT).as_posix()+'/',
    'status':'Approved concept implemented as a local textured asset; Roblox upload and runtime installation pending',
    'config':{'status':'in Config.SKINS; currently using the original code-built spots','skinsRow':{'surface':surface.group(1) if surface else None,'pattern':'pattern =' in row,'chest':'og','rarity':'common'}},
    'templates':{},'idSources':{},'maps':maps,
    'generator':'generate/make_muddy_blend.py','concept':'preview/muddy-concept-v1.png',
    'source':'source/muddy.blend','derivedPackage':{'path':'package/','blend':'muddy-complete.blend','fbx':'muddy-complete.fbx','report':'muddy-asset-report.json'},
    'geometry':geometry,'validation':{'fbxRoundTripMaxBoundsError':report['fbxRoundTripMaxBoundsError'],'triangles':report['triangles'],'textureCopiesMatch':True},
    'files':{room:sorted(p.relative_to(HOME/room).as_posix() for p in (HOME/room).rglob('*') if p.is_file() and p.suffix not in ('.blend1','.pyc')) for room in ('source','generate','sheets','preview','package')}
}
(HOME/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('Muddy validated: unchanged geometry/UVs; closed meshes; FBX round trip; two matching maps.')
