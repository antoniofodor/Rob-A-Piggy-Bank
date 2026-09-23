"""Check the organized import packages without rebuilding artwork or uploading.

The tier pages are still under assets/skins/animal/<tier>/; the packages they list moved to
assets/piggies/<tier>/<key>/package/ on 2026-09-22 and are found through the manifests' `package` fields."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit, unquote
import hashlib, json, ast

REPO=Path(__file__).resolve().parents[3]
ROOT=REPO/'assets/skins/animal'
manifest=json.loads((ROOT/'manifest.json').read_text())
audit=json.loads((ROOT/'relocation-audit.json').read_text())
errors=[];links=0;binaries=0
class Links(HTMLParser):
    def handle_starttag(self,tag,attrs):
        global links
        for name,value in attrs:
            if name not in ('href','src','poster') or not value:continue
            url=urlsplit(value)
            if url.scheme or url.netloc or not url.path:continue
            links+=1
            if not (self.path.parent/unquote(url.path)).resolve().exists():errors.append(f'{self.path.relative_to(REPO)}: {value}')
for p in list(ROOT.rglob('*.html'))+list((REPO/'assets/piggies').glob('*/*/package/**/*.html')):
    parser=Links();parser.path=p;parser.feed(p.read_text(encoding='utf-8'))
for m in manifest['models']:
    folder=REPO/m['package'];key=m['skin']
    for suffix in ('-complete.fbx','-complete.blend'):
        if not (folder/(key+suffix)).is_file():errors.append(key+suffix)
for f in audit['files']:
    p=REPO/f['destination']
    if p.suffix in ('.blend','.fbx','.png','.jpg','.gif','.mp4','.glb'):
        binaries+=1
        if hashlib.sha256(p.read_bytes()).hexdigest()!=f['sha256']:errors.append(str(p)+' content changed during move')
for p in (REPO/'blender/pig/make').glob('*.py'):ast.parse(p.read_text(encoding='utf-8-sig'),filename=str(p))
result={'skinCount':len(manifest['models']),'counts':manifest['counts'],'verifiedUnchangedBinaryFiles':binaries,'localLinksChecked':links,'errors':errors}
(ROOT/'package-checks.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
assert not errors,'Animal package verification failed'
